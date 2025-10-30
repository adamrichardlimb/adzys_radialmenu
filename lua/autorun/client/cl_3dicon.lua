-- lua/autorun/client/cl_wireframe_material.lua
function createWireframeMaterial(name, modelPath, offsets)
    offsets = offsets or { pos = Vector(50, 0, 0), angle = Angle(0, 0, 0) }

    local rt = GetRenderTarget(name, 512, 512)
    local mat = CreateMaterial(name .. "_mat", "UnlitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$translucent"] = "1"
    })

    local mdl = ClientsideModel(modelPath or "models/props_lab/huladoll.mdl", RENDERGROUP_OPAQUE)
    mdl:SetNoDraw(true)
    local mins, maxs = mdl:GetModelBounds()
    local centre = (mins + maxs) * 0.5
    local radius = maxs:Distance(mins) * 0.75
    --mdl:SetPos(-centre)
    mdl:SetAngles(Angle(0, 90, 0))

    local camDist = radius * 2.4


    render.PushRenderTarget(rt)
        render.Clear(0, 200, 0, 0, true, true)

        cam.Start3D(centre, Angle(0, 0, 0), camDist)
            render.SuppressEngineLighting(true)
            render.SetWriteDepthToDestAlpha(false)

            render.ModelMaterialOverride(Material("models/wireframe"))
            render.Model({
                model = modelPath,
                pos = offsets.pos,
                angle = offsets.angle
            }, mdl)
            render.ModelMaterialOverride(nil)

            render.SetWriteDepthToDestAlpha(true)
            render.SuppressEngineLighting(false)
        cam.End3D()
    render.PopRenderTarget()

    mdl:Remove()

    return mat
end
