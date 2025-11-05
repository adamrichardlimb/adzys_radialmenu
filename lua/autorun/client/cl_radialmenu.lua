-- lua/autorun/client/cl_radialmenu.lua

-- If 3dicon.lua used to contain your AutoIcon implementation,
-- remove that old code from it. Keep this include only if it still contains helpers.
include("drawarc.lua")

_G.CreateRadialMenu = _G.CreateRadialMenu or function()
    local radialMenu = {}
    radialMenu.Items = {}
    radialMenu.Active = false
    radialMenu.Selected = nil

    _G.RadialMenu_ActiveInstance = _G.RadialMenu_ActiveInstance or nil

    print("[Adzy's Radial Menu - Loaded...]")

    local function DrawAutoIcon(mat, x, y, w, h, col)
        col = col or Vector(1, 1, 1)

        cam.Start2D()
            render.SetMaterial(mat)
            mat:SetVector("$color2", col)
            render.OverrideBlend(
                true,
                BLEND_ONE_MINUS_DST_COLOR, BLEND_ONE, BLENDFUNC_ADD,
                BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD
            )
            render.OverrideDepthEnable(true, false)
            render.DrawScreenQuadEx(x, y, w, h)
            render.OverrideDepthEnable(false, false)
            render.OverrideBlend(false)
        cam.End2D()
    end

    function radialMenu:Open(items, key)
        if _G.RadialMenu_ActiveInstance and _G.RadialMenu_ActiveInstance ~= self then return end
        if self.Active then return end

        self.Items = items or {}
        self.Active = true
        _G.RadialMenu_ActiveInstance = self
        gui.EnableScreenClicker(true)

        -- Pre-load icons
        for _, item in ipairs(self.Items) do
            if item.model then
                -- Use stand-alone autoicon addon
                if autoicon and autoicon.Get then
                    item._mat = autoicon.Get(item.model)
                else
                    print("[RadialMenu] autoicon library missing, skipping autoicon for", item.model)
                    item._mat = nil
                end

            elseif item.icon then
                item._mat = Material(item.icon, "smooth")

            elseif item.avatar then
                if not item._avatarPanel then
                    item._avatarPanel = vgui.Create("AvatarImage")
                    item._avatarPanel:SetSize(64, 64)
                    item._avatarPanel:SetSteamID(item.avatar, 64)
                    item._avatarPanel:SetPaintedManually(true)
                end
            end
        end

        local frame = vgui.Create("DFrame")
        frame:SetSize(ScrW(), ScrH())
        frame:SetTitle("")
        frame:SetDraggable(false)
        frame:ShowCloseButton(false)
        frame:SetBackgroundBlur(true)
        frame:SetAlpha(0)
        frame:AlphaTo(255, 0.15)
        frame.Paint = function() end

        frame.OnRemove = function()
            self.Active = false
            gui.EnableScreenClicker(false)
            if _G.RadialMenu_ActiveInstance == self then
                _G.RadialMenu_ActiveInstance = nil
            end
        end

        frame.Think = function()
            if not input.IsKeyDown(key) then
                frame:Remove()
                if self.Selected and self.Selected.onSelect and not self.Selected.isDisabled then
                    self.Selected.onSelect()
                end
            end
        end

        frame.PaintOver = function(_, w, h)
            local cx, cy = w / 2, h / 2
            local mouseX, mouseY = gui.MouseX(), gui.MouseY()
            local dx, dy = mouseX - cx, mouseY - cy
            local angle = math.deg(math.atan2(-dy, dx))
            if angle < 0 then angle = angle + 360 end

            local innerRadius = ScrH() * 0.1875
            local outerRadius = innerRadius * 2
            local segAngle = 360 / #self.Items
            local spacer   = (#self.Items > 1) and 4 or 0
            self.Selected = nil

            for i, item in ipairs(self.Items) do
                local startAngle = ((i - 1) * segAngle) + spacer / 2
                local endAngle   = (i * segAngle) - spacer / 2
                local isHover = angle >= startAngle and angle < endAngle and (math.sqrt(dx^2 + dy^2) > innerRadius)

                render.ClearStencil()
                render.SetStencilEnable(true)

                render.SetStencilTestMask(255)
                render.SetStencilWriteMask(255)
                render.SetStencilReferenceValue(1)

                render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
                render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
                render.SetStencilPassOperation(STENCILOPERATION_KEEP)
                render.SetStencilZFailOperation(STENCILOPERATION_KEEP)

                draw.NoTexture()
                draw.Arc(cx, cy,
                    outerRadius+5,
                    outerRadius+10-innerRadius,
                    startAngle-spacer/4,
                    endAngle+spacer/4,
                    1,
                    color_white
                )

                render.SetStencilReferenceValue(0)
                render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
                render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)

                draw.Arc(cx, cy,
                    outerRadius,
                    outerRadius - innerRadius,
                    startAngle,
                    endAngle,
                    1,
                    color_white
                )

                render.SetStencilReferenceValue(1)
                render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
                render.SetStencilFailOperation(STENCILOPERATION_KEEP)

                local hoverColor = item.isDisabled and Color(200, 200, 200, 100) or Color(255, 255, 255, 220)

                surface.SetDrawColor(0, 0, 255, 200)
                draw.NoTexture()
                draw.Arc(cx, cy,
                    outerRadius+5,
                    outerRadius+10-innerRadius,
                    startAngle-spacer/4,
                    endAngle+spacer/4,
                    1,
                    isHover and hoverColor or Color(0,0,0,220)
                )

                render.SetStencilEnable(false)

                surface.SetDrawColor(0, 0, 0, 200)
                draw.NoTexture()
                draw.Arc(cx, cy,
                    outerRadius,
                    outerRadius - innerRadius,
                    startAngle,
                    endAngle,
                    1,
                    Color(0,0,0,200)
                )

                if isHover then
                    self.Selected = item
                end
            end

            for i, item in ipairs(self.Items) do
                local startAngle = ((i - 1) * segAngle) + spacer / 2
                local endAngle   = (i * segAngle) - spacer / 2
                local midAngle = math.rad((startAngle + endAngle) / 2)
                local textRadius = (innerRadius + outerRadius) / 2

                if item._mat then
                    local size = item.model and 192 or 96
                    local x = cx + math.cos(midAngle) * textRadius - size / 2
                    local y = cy + -math.sin(midAngle) * textRadius - size / 2
                    DrawAutoIcon(item._mat, x, y, size, size, item.col or Vector(1, 1, 1))

                elseif item._avatarPanel then
                    local size = 96
                    local x = cx + math.cos(midAngle) * textRadius - size / 2
                    local y = cy + -math.sin(midAngle) * textRadius - size / 2

                    render.PushFilterMin(TEXFILTER.ANISOTROPIC)
                    render.PushFilterMag(TEXFILTER.ANISOTROPIC)

                    item._avatarPanel:SetPos(x, y)
                    item._avatarPanel:SetSize(size, size)
                    item._avatarPanel:PaintManual()

                    render.PopFilterMag()
                    render.PopFilterMin()
                end
            end

            if self.Selected then
                local item = self.Selected
                local label = item.label
                if item.isDisabled then
                    if item.disabledText then label = item.label .. " " .. item.disabledText
                    else label = item.label .. " " .. "[DISABLED]"
                    end
                end
                DrawBox(label, self.Selected.description, item.isDisabled)
            end
        end
    end

    return radialMenu
end
