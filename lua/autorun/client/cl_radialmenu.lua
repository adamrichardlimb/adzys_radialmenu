-- lua/autorun/client/cl_radialmenu.lua
local radialMenu = {}
radialMenu.Items = {}
radialMenu.Active = false
radialMenu.Selected = nil

print("[Adzy's Radial Menu - Loaded...]")

-- Example usage:
-- radialMenu.Open({
--     { label = "Pistol", icon = "icon16/gun.png", onSelect = function() RunConsoleCommand("give", "weapon_pistol") end },
--     { label = "SMG", icon = "icon16/bullet_black.png", onSelect = function() RunConsoleCommand("give", "weapon_smg1") end },
--     { label = "Grenade", icon = "icon16/bomb.png", onSelect = function() RunConsoleCommand("give", "weapon_frag") end },
-- })

function radialMenu.Open(items)
    if radialMenu.Active then return end
    radialMenu.Items = items or {}
    radialMenu.Active = true
    gui.EnableScreenClicker(true)

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
        radialMenu.Active = false
        gui.EnableScreenClicker(false)
    end

    frame.Think = function()
        if not input.IsKeyDown(KEY_R) then
            frame:Remove()
            if radialMenu.Selected and radialMenu.Selected.onSelect then
                radialMenu.Selected.onSelect()
            end
        end
    end

    frame.PaintOver = function(_, w, h)
        local cx, cy = w / 2, h / 2
        local mouseX, mouseY = gui.MouseX(), gui.MouseY()
        local dx, dy = mouseX - cx, mouseY - cy
        local angle = math.deg(math.atan2(dy, dx))
        if angle < 0 then angle = angle + 360 end
        local innerRadius = ScrH() * 0.1875
        local outerRadius = innerRadius * 2

        local segAngle = 360 / #radialMenu.Items
        -- We need a tasteful gap between items
        local segMargin = segAngle/20
        radialMenu.Selected = nil

        for i, item in ipairs(radialMenu.Items) do
            local startAngle = ((i - 1) * segAngle)
            local endAngle = (i * segAngle)
            local isHover = angle >= startAngle and angle < endAngle and (math.sqrt(dx^2 + dy^2) > innerRadius)

            draw.NoTexture()
            surface.SetDrawColor(isHover and Color(80, 180, 255, 160) or Color(40, 40, 40, 180))
            draw.RingSegment(cx, cy, innerRadius, outerRadius, startAngle, endAngle, 4)

            local midAngle = math.rad((startAngle + endAngle) / 2)
            local textRadius = (innerRadius + outerRadius) / 2
            local textX = cx + math.cos(midAngle) * (textRadius + 10)
            local textY = cy + math.sin(midAngle) * (textRadius + 10)

            if item.icon then
                surface.SetMaterial(Material(item.icon))
                surface.SetDrawColor(255, 255, 255)
                surface.DrawTexturedRect(textX - 8, textY - 8, 16, 16)
            end

            draw.SimpleText(item.label, "DermaDefaultBold", textX, textY + 14, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            if isHover then
                radialMenu.Selected = item
            end
        end
    end
end

-- Utility: draw a filled arc
function draw.RingSegment(cx, cy, innerRadius, outerRadius, startAng, endAng, step)
    local triangles = {}
    if endAng < startAng then endAng = endAng + 360 end
    local step = step or 2

    for deg = startAng, endAng - step, step do
        local rad1 = math.rad(deg)
        local rad2 = math.rad(deg + step)

        local inner1 = { x = cx + math.cos(rad1) * innerRadius, y = cy + math.sin(rad1) * innerRadius }
        local inner2 = { x = cx + math.cos(rad2) * innerRadius, y = cy + math.sin(rad2) * innerRadius }
        local outer1 = { x = cx + math.cos(rad1) * outerRadius, y = cy + math.sin(rad1) * outerRadius }
        local outer2 = { x = cx + math.cos(rad2) * outerRadius, y = cy + math.sin(rad2) * outerRadius }

        table.insert(triangles, { outer1, outer2, inner1 })
        table.insert(triangles, { inner1, outer2, inner2 })
    end

    for _, tri in ipairs(triangles) do
        surface.DrawPoly(tri)
    end
end


-- Bind to a key (example)
hook.Add( "Tick", "KeyDown_Test", function()
  if input.IsKeyDown(KEY_R) then
          radialMenu.Open({
              { label = "Pistol", icon = "icon16/gun.png", onSelect = function() RunConsoleCommand("give", "weapon_pistol") end },
              { label = "SMG", icon = "icon16/bullet_black.png", onSelect = function() RunConsoleCommand("give", "weapon_smg1") end },
           })
    end
end)

