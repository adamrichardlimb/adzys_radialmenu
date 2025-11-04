function DrawBox(title, desc, disabled)
  title = title or ""
  desc = desc or ""

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
      
      if (descHeight == 0) then
        padScaling = 1.5
      else
        padScaling = 2
      end
      local boxH = th + descHeight + pad * padScaling

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
      draw.SimpleText(title, titleFont, x + pad, y + pad, disabled and Color(220, 0, 0, 255) or color_white)

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
