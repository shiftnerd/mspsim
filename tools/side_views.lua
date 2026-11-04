-- Side views (facing right: the front of the object points to +x, its back is at the left) for every piece that
-- does not already have one in lib.lua. Loaded by lib.lua; attaches P.*Side functions.
return function(L, P)
  -- ===== group A: furniture ====================================================================
  function P.slipperSide()
    return L.piece(22, 32, function(R, PX)
      local function pat(x0, y0, w, h)
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            local gx = (x + x0 + (math.floor((y + y0) / 6) % 2) * 3) % 6
            local green = (gx < 4) and ((y + y0) % 6 < 4)
            PX(x0 + x, y0 + y, green and "#3E8E3A" or "#F4F2EA")
          end
        end
      end
      pat(0, 0, 7, 15)      -- back, reclined at the rear
      pat(0, 13, 22, 7)     -- seat (cushion top 13 px down; legs make the seat 19 px off the floor)
      R(0, 20, 22, 4, "#D8D6CC")
      R(3, 24, 3, 8, "#2A1C14"); R(16, 24, 3, 8, "#1C120C")
    end)
  end

  function P.confTableSide(depth)
    depth = depth or 36
    return L.piece(depth, 30, function(R)
      L.box(R, 0, 0, depth, 5, "#C9955A", "#E0B47A", "#A57445")
      R(2, 5, depth - 4, 3, "#A57445")
      R(3, 8, depth - 6, 22, "#8A5E36")                      -- end leg panel
      R(4, 9, depth - 8, 20, "#946A3D")
    end)
  end

  function P.cubicleShellSide(depth)
    depth = depth or 70
    return L.piece(depth, 56, function(R)
      L.box(R, 0, 0, depth, 56, "#8D99A8", "#A8B3C0", "#6F7C8C")
      R(0, 0, depth, 3, "#D8D5C4")
      R(23, 3, 1, 53, "#6F7C8C"); R(46, 3, 1, 53, "#6F7C8C")  -- panel joints
      R(0, 52, depth, 4, "#6F7C8C")
    end)
  end

  -- ===== group B: appliances and fixtures ======================================================
  function P.copierSide()
    return L.piece(22, 26, function(R)
      L.box(R, 0, 0, 20, 7, "#8E939E", "#B8BCC4", "#6A6F7A")
      L.box(R, 0, 7, 20, 19, "#C8CCD8", "#E4E6EE", "#9498A2")
      R(12, 1, 6, 2, "#2A2A33"); R(13, 1, 2, 1, "#4F9C8E")      -- control panel on the lid
      R(20, 14, 2, 8, "#9498A2")                                 -- paper tray nub at the front
      R(2, 22, 16, 2, "#9498A2")
    end)
  end

  function P.coolerSide()
    return L.piece(14, 30, function(R)
      L.box(R, 2, 0, 8, 10, "#8AB4D8", "#B5D4EC", "#5E86A8")
      L.box(R, 0, 10, 12, 20, "#F0F0EC", "#FFFFFF", "#D8D8D2")
      R(12, 15, 2, 3, "#9498A2")                                 -- tap
      R(10, 22, 4, 2, "#9498A2")                                 -- drip tray
    end)
  end

  function P.fridgeSide()
    return L.piece(28, 60, function(R)
      L.box(R, 0, 0, 26, 60, "#B8BCC4", "#D6D9DF", "#9498A2")
      R(22, 0, 4, 21, "#D6D9DF"); R(22, 23, 4, 37, "#D6D9DF")   -- door thickness at the front
      R(22, 21, 4, 2, "#6A6F7A")
      R(26, 6, 2, 12, "#6A6F7A"); R(26, 27, 2, 14, "#6A6F7A")   -- handles
    end)
  end

  function P.coffeeSide()
    return L.piece(20, 16, function(R)
      R(0, 14, 19, 2, "#2A2A33")
      L.box(R, 1, 0, 9, 14, "#2E3138", "#4A4F5A", "#1C1E24")
      R(1, 0, 9, 4, "#4A4F5A")
      R(3, 6, 2, 2, "#E04040")
      L.box(R, 12, 5, 5, 9, "#8AB4D8", "#B5D4EC", "#5E86A8")   -- carafe
      R(17, 7, 1, 5, "#2A2A33")
    end)
  end

  function P.sinkSide()
    return L.piece(16, 10, function(R)
      L.box(R, 0, 6, 16, 4, "#B8BCC4", "#D6D9DF", "#9498A2")
      R(1, 0, 2, 7, "#8E939E"); R(1, 0, 7, 2, "#8E939E")        -- faucet arcs over from the back
    end)
  end

  function P.toiletSide()
    return L.piece(22, 24, function(R)
      L.box(R, 0, 0, 7, 10, "#F0F0F0", "#FFFFFF", "#D8D8D2")   -- tank
      R(7, 2, 1, 2, "#8E939E")
      L.box(R, 3, 10, 19, 8, "#F0F0F0", "#FFFFFF", "#D8D8D2")  -- bowl
      R(3, 9, 19, 1, "#E4E4DE")
      R(6, 18, 10, 6, "#E4E4DE")                                 -- pedestal
    end)
  end

  function P.bathSinkSide()
    return L.piece(16, 26, function(R)
      R(1, 0, 2, 4, "#8E939E"); R(1, 0, 6, 2, "#8E939E")
      L.box(R, 0, 4, 14, 6, "#F0F0F0", "#FFFFFF", "#D8D8D2")
      R(5, 10, 5, 16, "#E4E4DE")
    end)
  end

  -- ===== group C: plants, doors, wall items ====================================================
  function P.plantSide()
    return L.piece(12, 18, function(R)
      R(5, 3, 2, 10, "#2C6B2A"); R(2, 7, 3, 4, "#2C6B2A"); R(7, 5, 3, 6, "#3E8E3A")
      R(4, 0, 4, 5, "#5FB04E"); R(9, 3, 2, 3, "#5FB04E"); R(1, 5, 2, 3, "#3E8E3A")
      L.box(R, 2, 12, 8, 6, "#B8663F", "#D88A62", "#8A4A2C")
    end)
  end

  function P.floorPlantSide()
    return L.piece(14, 30, function(R)
      R(6, 4, 2, 18, "#2C6B2A"); R(2, 10, 4, 6, "#2C6B2A"); R(8, 8, 4, 8, "#3E8E3A")
      R(4, 0, 6, 8, "#5FB04E"); R(11, 10, 3, 6, "#5FB04E"); R(0, 12, 3, 6, "#3E8E3A")
      L.box(R, 2, 20, 10, 10, "#B8663F", "#D88A62", "#8A4A2C")
    end)
  end

  function P.glassDoorSide()
    return L.piece(8, 72, function(R)
      L.box(R, 0, 0, 4, 72, "#B8BCC4", "#D6D9DF", "#9498A2")
      R(4, 14, 3, 18, "#6A6F7A")                                 -- pull handle
    end)
  end

  function P.slabDoorSide(base, shade, hi, knob)
    return L.piece(6, 72, function(R)
      R(0, 0, 3, 72, base); R(2, 0, 1, 72, shade); R(0, 0, 1, 72, hi)
      R(3, 34, 3, 3, knob == "black" and "#1E1E22" or "#8E939E")
    end)
  end

  function P.tvSide()
    return L.piece(7, 22, function(R)
      R(0, 8, 2, 6, "#1C1C24")                                   -- wall bracket
      L.box(R, 2, 0, 5, 22, "#2A2A33", "#4A4A56", "#1C1C24")
      R(6, 2, 1, 17, "#EEF3F6")                                  -- lit screen edge
    end)
  end

  function P.wallScreenSide()
    return L.piece(7, 32, function(R)
      R(0, 12, 2, 8, "#1C1C24")
      L.box(R, 2, 0, 5, 32, "#2A2A33", "#4A4A56", "#1C1C24")
      R(6, 2, 1, 28, "#DDE8F0")
    end)
  end

  function P.calendarSide()
    return L.piece(2, 10, function(R) R(0, 0, 2, 10, "#F4F2EA"); R(0, 0, 2, 2, "#4F7FD0") end)
  end

  function P.stickySide()
    return L.piece(1, 5, function(R) R(0, 0, 1, 5, "#F7E36B") end)
  end

  function P.mirrorSide()
    return L.piece(3, 22, function(R) R(0, 0, 3, 22, "#B8BCC4"); R(2, 2, 1, 18, "#CFE6F2") end)
  end

  function P.whiteboardSide()
    return L.piece(6, 24, function(R)
      R(0, 0, 2, 24, "#B8BCC4"); R(2, 2, 1, 20, "#F4F2EA")
      R(2, 22, 4, 2, "#8E939E")                                  -- marker tray
    end)
  end

  function P.upperCabinetsSide()
    return L.piece(12, 22, function(R)
      L.box(R, 0, 0, 12, 22, "#F0F0EC", "#FFFFFF", "#D8D8D2")
      R(9, 1, 3, 20, "#F4F4F0"); R(9, 1, 1, 20, "#D8D8D2")       -- door thickness at the front
    end)
  end

  function P.lowerCabinetsSide()
    return L.piece(24, 16, function(R)
      L.box(R, 0, 0, 24, 3, "#B5A58C", "#CDBB9E", "#8F8068")    -- counter overhang
      R(1, 3, 22, 11, "#F0F0EC"); R(22, 3, 1, 11, "#D8D8D2"); R(20, 3, 1, 11, "#D8D8D2")
      R(2, 14, 20, 2, "#9A9A9A")
    end)
  end

  -- ===== office dressing ======================================================================
  function P.filingCabinetSide()
    return L.piece(18, 32, function(R)
      L.box(R, 0, 0, 18, 32, "#8E939E", "#B8BCC4", "#6A6F7A")
      R(14, 1, 3, 30, "#A3A8B3")
      for i = 1, 2 do R(14, i * 10, 3, 1, "#6A6F7A") end
    end)
  end

  -- a lounge seat from the side, facing RIGHT (one person per piece; the two-seat front couch and the bowling bench are now two of these):
  -- a tall padded back at the rear, a 4 row cushion with a lit top edge whose top is art row 25, a skirt and two stub legs. The art is 24x33,
  -- put at `seat_y - 32` and `seat_x - 13`, so the seat top is 7 px above the sitter's soles, right under the thighs (same as the task chair).
  function P.loungeSide(base, hi, sh)
    base = base or "#356C72"; hi = hi or "#4C8C94"; sh = sh or "#26535A"
    local r, g, b = tonumber(hi:sub(2, 3), 16), tonumber(hi:sub(4, 5), 16), tonumber(hi:sub(6, 7), 16)
    local top = string.format("#%02X%02X%02X", math.min(255, r + 30), math.min(255, g + 30), math.min(255, b + 30))
    return L.piece(24, 33, function(R)
      R(0, 3, 6, 22, base); R(1, 2, 4, 1, base); R(2, 1, 2, 1, base)       -- back, rounded at the top
      R(1, 3, 1, 21, hi); R(2, 2, 1, 1, hi)                                -- lit edge
      R(5, 3, 1, 22, sh)                                                   -- the seat side of the back is shaded
      R(0, 25, 24, 4, base); R(1, 25, 21, 1, top); R(1, 26, 22, 1, hi)     -- cushion, lit top
      R(23, 25, 1, 4, sh); R(0, 28, 24, 1, sh)                             -- rounded front, underside
      R(0, 29, 24, 2, sh); R(1, 29, 22, 1, base)                           -- skirt
      R(2, 31, 3, 2, "#2A1C14"); R(19, 31, 3, 2, "#2A1C14")                -- legs
    end)
  end

  function P.couchSide() return P.loungeSide("#3F7F86", "#5C9EA6", "#2C5C62") end

  function P.frameSide(h)
    h = h or 18
    return L.piece(2, h, function(R) R(0, 0, 2, h, "#5A3A22"); R(1, 0, 1, h, "#3E2814") end)
  end

  function P.clockSide()
    return L.piece(3, 10, function(R) R(0, 0, 3, 10, "#F4F2EA"); R(2, 0, 1, 10, "#CFCBBE") end)
  end
end
