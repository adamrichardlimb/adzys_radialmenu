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
      local angle = math.deg(math.atan2(-dy, dx))
      if angle < 0 then angle = angle + 360 end

      local innerRadius = ScrH() * 0.1875
      local outerRadius = innerRadius * 2
      local segAngle = 360 / #radialMenu.Items
      local spacer   = (#radialMenu.Items > 1) and 4 or 0
      radialMenu.Selected = nil

      for i, item in ipairs(radialMenu.Items) do
        local startAngle = ((i - 1) * segAngle) + spacer / 2
        local endAngle   = (i * segAngle) - spacer / 2

        -- 1. ENABLE STENCIL FOR THIS SLICE
        render.ClearStencil()
        render.SetStencilEnable(true)

        render.SetStencilTestMask(255)
        render.SetStencilWriteMask(255)
        render.SetStencilReferenceValue(1)

        --
        -- STEP A: write mask = "where we want blue to appear"
        -- mask = expanded outline arc
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
        render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
        render.SetStencilPassOperation(STENCILOPERATION_KEEP)
        render.SetStencilZFailOperation(STENCILOPERATION_KEEP)

        draw.NoTexture()
        -- big outline area goes into stencil as 1
        draw.Arc(cx, cy,
            outerRadius+5,
            outerRadius+10-innerRadius,
            startAngle-spacer/4,
            endAngle+spacer/4,
            1,
            color_white -- colour doesn't matter for mask
        )

        --
        -- STEP B: "punch out" the red fill area from the mask
        -- set stencil ref to 0, and replace where red would be
        --
        render.SetStencilReferenceValue(0)
        render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)

        -- inner red region (the normal wedge)
        draw.Arc(cx, cy,
            outerRadius,
            outerRadius - innerRadius,
            startAngle,
            endAngle,
            1,
            color_white
        )

        --
        -- STEP C: now only draw where stencil == 1
        --
        render.SetStencilReferenceValue(1)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
        render.SetStencilFailOperation(STENCILOPERATION_KEEP)

        surface.SetDrawColor(0, 0, 255, 200) -- blue outline colour actually drawn
        draw.NoTexture()
        draw.Arc(cx, cy,
            outerRadius+5,
            outerRadius+10-innerRadius,
            startAngle-spacer/4,
            endAngle+spacer/4,
            1,
            Color(0,0,0,220)
        )

        render.SetStencilEnable(false)

        --
        -- STEP D: now draw the solid red fill normally over everything
        -- (no stencil, just paint)
        --
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
    end

      -- 4️⃣ Draw icons and labels (above everything)
      for i, item in ipairs(radialMenu.Items) do
          local startAngle = ((i - 1) * segAngle) + spacer / 2
          local endAngle   = (i * segAngle) - spacer / 2
          local midAngle   = math.rad((startAngle + endAngle) / 2)
          local textRadius = (innerRadius + outerRadius) / 2
          local textX = cx + math.cos(midAngle) * (textRadius + 10)
          local textY = cy + math.sin(midAngle) * (textRadius + 10)

          if item.icon then
              surface.SetMaterial(Material(item.icon))
              surface.SetDrawColor(255, 255, 255)
              surface.DrawTexturedRect(textX - 8, textY - 8, 16, 16)
          end
          draw.SimpleText(item.label, "DermaDefaultBold", textX, textY + 14, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
      end
  end
end
-- Bind to a key (example)
hook.Add( "Tick", "KeyDown_Test", function()
  if input.IsKeyDown(KEY_R) then
          radialMenu.Open({
              { label = "Pistol", icon = "icon16/gun.png", onSelect = function() RunConsoleCommand("give", "weapon_pistol") end },
              { label = "SMG", icon = "icon16/bullet_black.png", onSelect = function() RunConsoleCommand("give", "weapon_smg1") end },
               { label = "Pistol", icon = "icon16/gun.png", onSelect = function() RunConsoleCommand("give", "weapon_pistol") end },
              { label = "SMG", icon = "icon16/bullet_black.png", onSelect = function() RunConsoleCommand("give", "weapon_smg1") end },
               { label = "Pistol", icon = "icon16/gun.png", onSelect = function() RunConsoleCommand("give", "weapon_pistol") end },
              { label = "SMG", icon = "icon16/bullet_black.png", onSelect = function() RunConsoleCommand("give", "weapon_smg1") end },
               { label = "Pistol", icon = "icon16/gun.png", onSelect = function() RunConsoleCommand("give", "weapon_pistol") end },
              { label = "SMG", icon = "icon16/bullet_black.png", onSelect = function() RunConsoleCommand("give", "weapon_smg1") end },
           })
    end
end)
