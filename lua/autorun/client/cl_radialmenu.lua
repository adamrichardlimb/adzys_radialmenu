include("3dicon.lua")
include("drawarc.lua")

-- lua/autorun/client/cl_radialmenu.lua
local radialMenu = {}
radialMenu.Items = {}
radialMenu.Active = false
radialMenu.Selected = nil

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

function radialMenu.Open(items)
  if radialMenu.Active then return end
  radialMenu.Items = items or {}
  radialMenu.Active = true
  gui.EnableScreenClicker(true)

  -- create a cached material for each model
  for _, item in ipairs(radialMenu.Items) do
      if item.model then
          item._mat = autoicon.Get(item.model)
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
      local isHover = angle >= startAngle and angle < endAngle and (math.sqrt(dx^2 + dy^2) > innerRadius)

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

      surface.SetDrawColor(0, 0, 255, 200)
      draw.NoTexture()
      draw.Arc(cx, cy,
          outerRadius+5,
          outerRadius+10-innerRadius,
          startAngle-spacer/4,
          endAngle+spacer/4,
          1,
          isHover and Color(255, 255, 255, 220) or Color(0,0,0,220)
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

      if isHover then
        radialMenu.Selected = item
        PrintTable(item)
      end
    end

    -- 4️⃣ Draw icons and labels (above everything)
    for i, item in ipairs(radialMenu.Items) do
        local startAngle = ((i - 1) * segAngle) + spacer / 2
        local endAngle   = (i * segAngle) - spacer / 2

        -- 3D model icon (centre of segment)
        if item._mat then
            local midAngle = math.rad((startAngle + endAngle) / 2)
            local textRadius = (innerRadius + outerRadius) / 2
            local size = 192
            local x = cx + math.cos(midAngle) * textRadius - size / 2
            local y = cy + -math.sin(midAngle) * textRadius - size / 2

            DrawAutoIcon(item._mat, x, y, size, size, Vector(1, 1, 1))
        end
    end

    if radialMenu.Selected then
      local item = radialMenu.Selected
      if item then
          local title = item.label or ""
          local desc  = item.description or ""

          -- if there is no text, don't draw anything
          if title ~= "" or desc ~= "" then
              local maxW = 260
              local maxH = 180
              local pad  = 8

              -- FONTS
              local titleFont = "DermaDefaultBold"
              local bodyFont  = "DermaDefault"

              -- --- measure + wrap --- --
              surface.SetFont(titleFont)
              local tw, th = surface.GetTextSize(title)

              local descLines = {}
              local descHeight = 0

              if desc ~= "" then
                  -- wrap description
                  local function wrapText(text, font, maxW)
                      surface.SetFont(font)
                      local words = string.Explode(" ", text)
                      local lines = {""}
                      for _, w in ipairs(words) do
                          local test = (lines[#lines] == "" and w) or (lines[#lines] .. " " .. w)
                          local lw = surface.GetTextSize(test)
                          if lw > maxW then
                              table.insert(lines, w)
                          else
                              lines[#lines] = test
                          end
                      end
                      return lines
                  end

                  descLines = wrapText(desc, bodyFont, maxW - pad * 2)

                  surface.SetFont(bodyFont)
                  local lineH = select(2, surface.GetTextSize("Ay"))
                  descHeight = math.min(#descLines * lineH, maxH - th - pad * 3)
              end

              -- compute total box size based on content
              local contentW = tw
              surface.SetFont(bodyFont)
              for _, line in ipairs(descLines) do
                  local w = surface.GetTextSize(line)
                  if w > contentW then contentW = w end
              end

              local boxW = math.min(maxW, contentW + pad * 2)
              local boxH = th + descHeight + pad * 3

              -- cursor offset
              local mx, my = gui.MouseX(), gui.MouseY()
              local x = mx + 20
              local y = my + 20

              -- clamp to screen
              if x + boxW > ScrW() then x = ScrW() - boxW - 5 end
              if y + boxH > ScrH() then y = ScrH() - boxH - 5 end

              -- draw box
              draw.RoundedBox(4, x, y, boxW, boxH, Color(0,0,0,225))

              -- draw title
              draw.SimpleText(title, titleFont, x + pad, y + pad, color_white)

              -- draw wrapped description
              local cursorY = y + pad + th + 2
              surface.SetFont(bodyFont)

              for _, line in ipairs(descLines) do
                  draw.SimpleText(line, bodyFont, x + pad, cursorY, Color(220,220,220))
                  cursorY = cursorY + select(2, surface.GetTextSize(line))
                  if cursorY > y + boxH - pad then break end
              end
          end
      end
    end
  end
end

-- Bind to a key (example)
hook.Add( "Tick", "KeyDown_Test", function()
  if input.IsKeyDown(KEY_R) then
          radialMenu.Open({
            { label = "Crowbar", description = "Lorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsumLorem ipsum", model = "models/weapons/w_crowbar.mdl", onSelect = function() RunConsoleCommand("kill") end },
            { model = "models/weapons/w_pist_deagle.mdl", onSelect = function() RunConsoleCommand("give", "weapon_deagle") end },
            { label = "Rifle",   model = "models/weapons/w_snip_scout.mdl", onSelect = function() RunConsoleCommand("give", "weapon_scout") end },
            { label = "Knife",   model = "models/weapons/w_knife_t.mdl", onSelect = function() RunConsoleCommand("give", "weapon_knife") end },
            { label = "C4",      model = "models/weapons/w_c4_planted.mdl", onSelect = function() RunConsoleCommand("give", "weapon_c4") end },
            { label = "SMG",     model = "models/weapons/w_smg1.mdl", onSelect = function() RunConsoleCommand("give", "weapon_smg1") end },
        })
    end
end)
