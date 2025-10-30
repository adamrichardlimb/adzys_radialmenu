-- autoicon_lib.lua
-- Library: feed a model (or SWEP class/entity), get back an AutoIcons-style Material.
-- Usage: local mat = autoicon.Get("models/weapons/w_pistol.mdl")
--        local mat = autoicon.Get("weapon_ar2") -- SWEP class works too

module("autoicon", package.seeall)

local MODE_HL2WEAPONSELECT = 1
local MODE_HL2KILLICON     = 2

local placeholder_model    = "models/maxofs2d/logo_gmod_b.mdl"
local error_model          = "models/error.mdl"

local cache = {{}, {}} -- cache[mode][cachekey] = Material

local name_prefix = "autoicon_lib" .. tostring(ReloadIndex or "") .. "_"
ReloadIndex = (ReloadIndex or 0) + 1
local unique_name_index = 0

local function unique_name()
    unique_name_index = unique_name_index + 1
    return name_prefix .. tostring(unique_name_index)
end

-- ---------------------------
-- Helpers from original addon
-- ---------------------------
local function get_stored(classname)
    return weapons.GetStored(classname) or (scripted_ents.GetStored(classname) or {}).t
end

local function translate_model(mdl)
    return (mdl or "") == "" and placeholder_model or (util.IsValidModel(mdl) and mdl or error_model)
end

local classname_default_model = {}
hook.Add("NetworkEntityCreated", "AutoIconLibNetworkEntityCreated", function(ent)
    if not classname_default_model[ent:GetClass()] and (ent:GetModel() or "") ~= "" then
        classname_default_model[ent:GetClass()] = ent:GetModel()
    end
end)

local function class_default_model(data)
    return (data.IronSightStruct and data.ViewModel or data.WorldModel) or data.Model or classname_default_model[data.ClassName]
end

local model_angle_override = {
    ["models/weapons/w_toolgun.mdl"] = Angle(0, 0, 0),
    ["models/MaxOfS2D/camera.mdl"]  = Angle(0, 90, 0),
    [placeholder_model] = Angle(0, 90, 0),
    [error_model]       = Angle(0, 90, 0),
}

local function autoicon_params(data)
    local p = {}

    if isstring(data) and not data:EndsWith(".mdl") then
        data = get_stored(data) or placeholder_model
    end

    if isentity(data) then
        local mdl = translate_model(data:GetModel())
        data = (mdl == class_default_model(data)) and get_stored(data:GetClass()) or mdl
    end

    if isstring(data) then
        p.mainmodel   = data
        p.cachekey    = data
        p.force_angle = model_angle_override[data]
    else
        p.mainmodel   = translate_model(class_default_model(data))
        p.cachekey    = data.ClassName
        p.force_angle = data.AutoIconAngle or model_angle_override[p.mainmodel]
        p.welements   = data.WElements
        p.hide_mainmodel = data.ShowWorldModel == false or data.SciFiWorld == "dev/hide" or data.SciFiWorld == "vgui/white"
    end

    p.legit = p.mainmodel ~= placeholder_model and p.mainmodel ~= error_model
    return p
end

-- ---------------------------
-- Materials used by pipeline
-- ---------------------------
local MAT_MODELCOLOR = CreateMaterial(unique_name(), "VertexLitGeneric", { ["$basetexture"] = "lights/white" })
local MAT_TEXTURE    = CreateMaterial(unique_name(), "UnlitGeneric",   { ["$basetexture"] = "lights/white", ["$vertexcolor"] = "1" })
local MAT_DESATURATE = CreateMaterial(unique_name(), "g_colourmodify", {
    ["$fbtexture"] = "lights/white",
    ["$pp_colour_brightness"] = -0.25,
    ["$pp_colour_contrast"]   = 3,
    ["$pp_colour_colour"]     = 0
})

-- quick RT creator
local function make_rt(name_fn, xs, ys, depth, alpha)
    return GetRenderTargetEx(
        name_fn(), xs, ys,
        depth and RT_SIZE_DEFAULT or RT_SIZE_NO_CHANGE,
        depth and MATERIAL_RT_DEPTH_SEPARATE or MATERIAL_RT_DEPTH_NONE,
        12 + 2, 0,
        alpha and IMAGE_FORMAT_RGBA8888 or IMAGE_FORMAT_RGB888
    )
end

-- 2D helper to draw a texture with optional blend func and offset
local function drawtexture(tex, col_or_bf, maybe_bf, ox, oy)
    local col, bf, x, y
    if isfunction(col_or_bf) then
        col, bf, x, y = nil, col_or_bf, maybe_bf, ox
    else
        col, bf, x, y = col_or_bf, maybe_bf, ox, oy
    end

    col = col or Vector(1,1,1)
    x = x or 0
    y = y or 0

    MAT_TEXTURE:SetTexture("$basetexture", tex)
    MAT_TEXTURE:SetVector("$color2", col)

    if bf then
        render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)
        bf()
    else
        render.OverrideBlend(false)
    end

    local m = Matrix()
    m:SetTranslation(Vector(x / tex:Width(), y / tex:Height(), 0))
    MAT_TEXTURE:SetMatrix("$basetexturetransform", m)

    render.SetMaterial(MAT_TEXTURE)
    render.DrawScreenQuad()
    render.OverrideBlend(false)
end

-- main renderer
function GetIcon(p, mode)
    mode = mode or MODE_HL2WEAPONSELECT
    if cache[mode][p.cachekey] then return cache[mode][p.cachekey] end
    if not p.legit then return end

    local mainent = ClientsideModel(p.mainmodel)
    if not IsValid(mainent) then return end

    local extraents = {}
    mainent:SetPos(vector_origin)
    mainent:SetAngles(angle_zero)
    mainent:SetupBones()

    -- optional SCK attachments kept minimal
    if p.welements then
        for _, v in pairs(p.welements) do
            if v.model and (not v.color or v.color.a ~= 0) then
                local e = ClientsideModel(v.model)
                if IsValid(e) then
                    local mat = Matrix()
                    mat:Scale(v.size or Vector(1,1,1))
                    e:EnableMatrix("RenderMultiply", mat)
                    e.lpos = v.pos or vector_origin
                    e.lang = v.angle or angle_zero
                    table.insert(extraents, e)
                end
            end
        end
    end

    local function drawmodel()
        if not p.hide_mainmodel then
            mainent:DrawModel()
        end
        for _, e in ipairs(extraents) do
            local pos, ang = LocalToWorld(e.lpos, e.lang, mainent:GetPos(), mainent:GetAngles())
            e:SetPos(pos)
            e:SetAngles(ang)
            e:SetupBones()
            e:DrawModel()
        end
    end

    local ok, ret = pcall(function()
        -- determine bounds and camera
        local min, max = mainent:GetRenderBounds()
        local center   = (min + max) * 0.5
        local rad      = max:Distance(min) * 0.5

        -- angle
        local ang = p.force_angle or Angle(0, (max.x - min.x >= max.y - min.y) and 0 or 90, 0)
        ang:RotateAroundAxis(Vector(1,0,0), -11)
        if mode == MODE_HL2WEAPONSELECT then
            ang:RotateAroundAxis(Vector(0,0,1), 180)
        end
        mainent:SetAngles(ang)
        mainent:SetupBones()

        -- RT sizes
        local rtx, rty = 512, 512
        if mode == MODE_HL2KILLICON then
            rtx, rty = 256, 256
        end

        -- ortho-like centred camera via FOV + offcentre
        local viewdist = 5 * rad + 1
        local fov      = 30
        local hw, hh   = 0.5, 0.5
        local cx, cy   = 0.5, 0.5

        local function cam_params()
            return {
                x = 0, y = 0, w = ScrW(), h = ScrH(),
                type = "3D",
                origin = mainent:LocalToWorld(center) + Vector(0, -viewdist, 0),
                angles = Vector(0, 90, 0),
                aspect = 1,
                fov = fov,
                offcenter = {
                    left = (cx - hw) * ScrW(),
                    top  = ((1 - cy) - hh) * ScrH(),
                    bottom = ((1 - cy) + hh) * ScrH(),
                    right  = (cx + hw) * ScrW()
                }
            }
        end

        -- MASK
        local maskrt = make_rt(unique_name, rtx, rty)
        render.PushRenderTarget(maskrt)
            render.Clear(0, 0, 0, 0, true, true)
            cam.Start(cam_params())
                render.SuppressEngineLighting(true)
                render.SetColorModulation(1,1,1)
                render.MaterialOverride(MAT_MODELCOLOR)
                drawmodel()
                render.MaterialOverride()
                render.SuppressEngineLighting(false)
            cam.End3D()
        render.PopRenderTarget()

        -- FULLBRIGHT COLOUR (for added edge detail)
        local colorrt = make_rt(unique_name, rtx, rty, true)
        render.PushRenderTarget(colorrt)
            render.Clear(0, 0, 0, 0, true, true)
            cam.Start(cam_params())
                render.SuppressEngineLighting(false)
                render.SetColorModulation(1,1,1)
                drawmodel()
            cam.End3D()
            render.BlurRenderTarget(colorrt, 1 / rtx, 1 / rty, 1)
        render.PopRenderTarget()

        -- NORMALS FAKE via lighting lobes
        local normalrt = make_rt(unique_name, rtx, rty, true)
        render.PushRenderTarget(normalrt)
            render.Clear(0, 0, 0, 0, true, true)
            cam.Start(cam_params())
                render.SetModelLighting(0, 1, 0.5, 0.5)
                render.SetModelLighting(1, 0, 0.5, 0.5)
                render.SetModelLighting(2, 0.5, 1, 0.5)
                render.SetModelLighting(3, 0.5, 0, 0.5)
                render.SetModelLighting(4, 0.5, 0.5, 1)
                render.SetModelLighting(5, 0.5, 0.5, 0)
                render.MaterialOverride(MAT_MODELCOLOR)
                drawmodel()
                render.MaterialOverride()
                render.ResetModelLighting(1,1,1)
            cam.End3D()
            render.BlurRenderTarget(normalrt, 1 / rtx, 1 / rty, 1)
        render.PopRenderTarget()

        -- EDGE DETECTION (colour + normals)
        local coloredgert = make_rt(unique_name, rtx, rty)
        render.PushRenderTarget(coloredgert)
            render.Clear(0, 0, 0, 0, true, true)
            cam.Start2D()
                local function bf_add() render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD) end
                local function bf_sub() render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_REVERSE_SUBTRACT, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD) end

                local d = (mode == MODE_HL2WEAPONSELECT) and 3 or 1
                for x = -1, 1 do
                    for y = -1, 1 do
                        if x ~= 0 or y ~= 0 then
                            drawtexture(normalrt, bf_add)
                            drawtexture(normalrt, bf_sub, x * d, y * d)
                        end
                    end
                end

                if mode == MODE_HL2WEAPONSELECT then
                    local mul = Vector(1,1,1) * 0.7
                    for x = -1, 1 do
                        for y = -1, 1 do
                            if x ~= 0 or y ~= 0 then
                                drawtexture(colorrt, mul, bf_add)
                                drawtexture(colorrt, mul, bf_sub, x * d, y * d)
                            end
                        end
                    end
                end
            cam.End2D()
        render.PopRenderTarget()

        -- DESATURATE EDGES
        local edgert = make_rt(unique_name, rtx, rty)
        local bluredgert
        render.PushRenderTarget(edgert)
            render.Clear(0, 0, 0, 0, true, true)
            cam.Start2D()
                MAT_DESATURATE:SetTexture("$fbtexture", coloredgert)
                render.SetMaterial(MAT_DESATURATE)
                render.DrawScreenQuad()
            cam.End2D()
            if mode == MODE_HL2WEAPONSELECT then
                bluredgert = make_rt(unique_name, rtx, rty)
                render.CopyRenderTargetToTexture(bluredgert)
                render.BlurRenderTarget(bluredgert, 14, 14, 8)
            end
        render.PopRenderTarget()

        -- BLURRED MASK for glow
        local blurmaskrt = make_rt(unique_name, rtx, rty)
        render.PushRenderTarget(blurmaskrt)
            render.Clear(0, 0, 0, 0, true, true)
            cam.Start2D()
                drawtexture(maskrt)
            cam.End2D()
            render.BlurRenderTarget(blurmaskrt, 8, 8, 3)
        render.PopRenderTarget()

        -- FINAL COMPOSE
        local finalrt = make_rt(unique_name, rtx, rty, false, false)

        render.PushRenderTarget(finalrt)
            render.Clear(0, 0, 0, 0, true, true)
            cam.Start2D()
                -- subtle base glow
                drawtexture(maskrt, Vector(1,1,1) * 0.2)
                render.BlurRenderTarget(finalrt, 20, 20, 2)

                if bluredgert then
                    -- brightened blurred edges
                    local function bf_add() render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD) end
                    drawtexture(bluredgert, Vector(1,1,1) * 16, bf_add)
                end

                -- multiply by blurred mask to confine glow
                local function bf_mul()
                    render.OverrideBlend(true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)
                end
                drawtexture(blurmaskrt, Vector(1,1,1) * 128, bf_mul)

                -- halftone-like lines (HL2 selector feel)
                if mode == MODE_HL2WEAPONSELECT then
                    local stp = 10
                    surface.SetDrawColor(0, 0, 0, 180)
                    for y = 0, rty, stp do
                        surface.DrawRect(0, y, rtx, stp - 1)
                    end
                end

                -- add crisp edges over the top
                local function bf_add() render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD) end
                drawtexture(edgert, bf_add)
            cam.End2D()
        render.PopRenderTarget()

        -- Final material from finalrt
        local m = CreateMaterial(unique_name(), "UnlitGeneric", {
            ["$basetexture"] = finalrt:GetName(),
        })
        cache[mode][p.cachekey] = m
        render.SuppressEngineLighting(false)
        render.OverrideBlend(false)
        return m
    end)

    mainent:Remove()
    for _, e in ipairs(extraents) do if IsValid(e) then e:Remove() end end

    if not ok then error(ret) end
    return ret
end

-- Public helper: defaults to HL2 weapon-select look
function Get(class_or_model, mode)
    return GetIcon(autoicon_params(class_or_model), mode or MODE_HL2WEAPONSELECT)
end
