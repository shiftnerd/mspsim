-- The WAREHOUSE LOT (R21c follow-up): the walkable parking lot outside the dock. 780 px wide, side-on like every other set.
-- Loaded by build_sets.lua: dofile(TOOLS .. "lot_set.lua")(L, builders). Builder coordinates are the old 0..128 band (floor line
-- y 118); the canvas adds 100 px on top and 92 below. The SKY IS A TRANSPARENT HOLE in the art (everything above the tree line):
-- godot/scripts/outside.gd (node Backdrop, mode "lot") draws the gradient, sun and clouds behind the Background and follows the
-- game clock. Left to right: the dock wall with the open doorway (x 0..120, the way back in), the concrete apron, a dumpster, a
-- sedan, a hatchback, the light pole, the company's plain white van, a chain-link fence along the back with trees behind it.
-- No brands, no modern cars (2013-14). Y-sorted pieces: lot_dumpster, lot_sedan, lot_hatch, lot_pole, lot_van.
return function(L, builders)
  local P = L.P
  local W = 780
  local function F(im, x, y, w, h, c) L.fill(im, x + L.XOFF, y + L.YOFF, w, h, c) end
  local function hash(a, b, c)
    local h = a * 73856093 + b * 19349663 + c * 83492791
    h = (h ~ (h >> 15)) * 2246822519 % 4294967296
    h = (h ~ (h >> 13)) * 3266489917 % 4294967296
    return (h ~ (h >> 16)) % 1000003
  end
  local function disc(R, cx, cy, r, c)
    for y = -r, r do for x = -r, r do
      if x * x + y * y <= r * r + r * 0.6 then R(cx + x, cy + y, 1, 1, c) end
    end end
  end
  local function wheel(R, cx, by, r)
    disc(R, cx, by - r, r, "#17121F"); disc(R, cx, by - r, r - 2, "#2A2A33"); disc(R, cx, by - r, math.max(2, r - 5), "#8A8F9A")
    R(cx, by - r, 1, 1, "#2A2A33")
  end

  function P.lotDumpster()
    return L.piece(62, 36, function(R)
      R(2, 10, 58, 22, "#2F6B4A"); R(2, 10, 58, 1, "#4A8A62"); R(2, 29, 58, 3, "#1F4A33")
      for x = 9, 53, 11 do R(x, 11, 2, 18, "#245A3C"); R(x, 11, 1, 18, "#3A7A55") end
      R(0, 3, 62, 8, "#33473B"); R(0, 3, 62, 1, "#55705F"); R(0, 10, 62, 1, "#1F2E26")
      R(4, 5, 54, 2, "#2A3C32"); R(30, 0, 28, 4, "#33473B")                          -- the lid, propped open at the back
      R(8, 14, 10, 1, "#7A4A2B"); R(40, 20, 8, 1, "#7A4A2B"); R(22, 24, 12, 1, "#7A4A2B")   -- rust streaks
      R(24, 16, 14, 8, "#E8E8E2"); R(24, 16, 14, 1, "#F6F6F0"); R(26, 19, 10, 1, "#C23B2E"); R(26, 21, 8, 1, "#8A8F9A")   -- a plain sticker
      R(3, 32, 6, 4, "#17121F"); R(53, 32, 6, 4, "#17121F")                              -- casters
    end)
  end

  function P.lotSedan()
    return L.piece(124, 42, function(R)
      local body, hi, sh, gl = "#7A8FA6", "#9CB0C4", "#566B82", "#A8CCE0"
      for r = 0, 13 do R(36 - r, r, 48 + 2 * r, 1, r == 0 and hi or body) end
      for r = 2, 12 do R(41 - r, r, 38 + 2 * r, 1, gl) end
      R(60, 2, 2, 11, body)                                                           -- the B pillar
      R(0, 14, 124, 17, body); R(0, 14, 124, 1, hi); R(0, 26, 124, 5, sh); R(0, 24, 124, 1, hi)
      R(0, 28, 6, 3, "#59596A"); R(118, 28, 6, 3, "#59596A")
      R(0, 16, 3, 5, "#C23B2E"); R(121, 16, 3, 4, "#F2E080"); R(116, 21, 6, 1, "#C8CCD0")
      R(60, 14, 1, 12, sh); R(34, 14, 1, 12, sh); R(88, 14, 1, 12, sh)
      R(50, 17, 6, 1, hi); R(70, 17, 6, 1, hi); R(94, 16, 8, 2, sh)
      wheel(R, 27, 41, 8); wheel(R, 97, 41, 8)
    end)
  end

  function P.lotHatch()
    return L.piece(108, 40, function(R)
      local body, hi, sh, gl = "#B8402F", "#D8604A", "#8A2E22", "#A8CCE0"
      for r = 0, 13 do R(28 - math.floor(r * 0.6), r, 54 + r + math.floor(r * 0.8), 1, r == 0 and hi or body) end
      for r = 2, 12 do R(33 - math.floor(r * 0.6), r, 44 + r + math.floor(r * 0.8) - 2, 1, gl) end
      R(52, 2, 2, 11, body)
      R(0, 14, 108, 16, body); R(0, 14, 108, 1, hi); R(0, 25, 108, 5, sh); R(0, 23, 108, 1, hi)
      R(0, 27, 6, 3, "#59596A"); R(102, 27, 6, 3, "#59596A")
      R(0, 16, 3, 5, "#C23B2E"); R(105, 16, 3, 4, "#F2E080")
      R(52, 14, 1, 11, sh); R(30, 14, 1, 11, sh); R(78, 14, 1, 11, sh)
      R(42, 17, 6, 1, hi); R(62, 17, 6, 1, hi)
      wheel(R, 22, 39, 8); wheel(R, 86, 39, 8)
    end)
  end

  -- the company's plain white service van: no lettering, a blue stripe, a ladder rack on the roof
  function P.lotVan()
    return L.piece(152, 62, function(R)
      local body, hi, sh = "#E8E8E2", "#F6F6F0", "#B8BAB6"
      R(0, 8, 126, 40, body); R(0, 8, 126, 1, hi); R(0, 44, 152, 4, sh)
      for x = 126, 150 do
        local top = 12 + math.floor((x - 126) * 14 / 24)
        R(x, top, 1, 48 - top, body)
        if x < 144 and x > 128 then R(x, top + 2, 1, 12 - math.floor((x - 128) / 4), "#8FB5CC") end
      end
      R(127, 12, 12, 1, hi)
      R(128, 12, 2, 24, body)
      R(0, 30, 150, 2, "#2F6FB8"); R(0, 33, 150, 1, "#1F4F88")
      R(0, 10, 2, 22, sh); R(40, 8, 1, 36, sh); R(84, 8, 1, 36, sh); R(112, 10, 1, 34, sh)   -- doors and the sliding door seam
      R(76, 22, 4, 2, "#8A8F9A"); R(120, 22, 4, 2, "#8A8F9A")
      R(0, 14, 4, 4, "#C23B2E"); R(150, 36, 2, 4, "#F2E080"); R(0, 44, 6, 4, "#59596A"); R(146, 44, 6, 4, "#59596A")
      R(6, 2, 100, 1, "#8A8F9A"); R(6, 6, 100, 1, "#6A737A")                           -- the ladder rack
      for x = 6, 106, 12 do R(x, 2, 1, 6, "#6A737A") end
      for x = 10, 100, 9 do R(x, 3, 1, 3, "#8A8F9A") end
      R(14, 36, 20, 3, "#D8D8D0"); R(60, 38, 14, 1, "#D0D0C8")                         -- road dirt
      wheel(R, 32, 61, 10); wheel(R, 118, 61, 10)
    end)
  end

  function P.lotPole()
    return L.piece(18, 94, function(R)
      R(14, 8, 3, 84, "#6A737A"); R(14, 8, 1, 84, "#8A9399")
      R(1, 5, 16, 3, "#6A737A"); R(1, 5, 16, 1, "#8A9399")
      R(0, 7, 9, 3, "#F2E8B0"); R(0, 7, 9, 1, "#FFF8D0"); R(2, 10, 6, 1, "#4A4D55")   -- the lamp head
      R(10, 84, 10, 8, "#8C8D88"); R(10, 84, 10, 1, "#A5A6A0"); R(11, 88, 8, 1, "#6A6B66")   -- the concrete base
      R(14, 60, 3, 3, "#2A2A33")
    end)
  end

  -- ------------------------------------------------------------------ the set
  builders.warehouse_lot = {W = W, H = 128, outdoor = true, fn = function(s)
    local tr, fe, bu, gr, ln = s.layer("Trees"), s.layer("Fence"), s.layer("Building"), s.layer("Ground"), s.layer("Lines")
    -- trees behind the fence: discs on a dark base, a few tall ones; the sky above stays transparent
    local greens = {"#2F5230", "#3E6B3A", "#4F7F45"}
    local function R(im) return function(x, y, w, h, c) F(im, x, y, w, h, c) end end
    local RT = R(tr)
    for i = 0, 62 do
      local cx = 150 + i * 11 + (hash(i, 1, 301) % 7) - 3
      local r = 8 + hash(i, 2, 302) % 6
      if i % 11 == 4 then r = r + 7 end
      local cy = 50 - (r - 8)
      disc(RT, cx, cy, r, greens[2])
      for y = -r, r do for x = -r, r do
        if x * x + y * y <= r * r + r * 0.6 then
          local g = (y < -r // 3 and x < 0) and 3 or ((y > r // 4) and 1 or 2)
          if hash(cx + x, cy + y, 303) % 9 == 0 then g = math.max(1, g - 1) end
          F(tr, cx + x, cy + y, 1, 1, greens[g])
        end
      end end
    end
    F(tr, 150, 52, W - 150, 8, "#2F5230")                                          -- the shadowed base of the tree line
    F(tr, 150, 58, W - 150, 32, "#3F6038")                                          -- the grass strip behind the fence
    for x = 150, W - 1 do if hash(x, 1, 309) % 3 == 0 then F(tr, x, 62 + hash(x, 2, 310) % 26, 1, 1, "#4F7545") end end
    -- the chain-link fence: posts every 40 px, a top rail, a see-through diamond mesh, a bottom rail
    for y = 60, 88 do for x = 170, W - 1 do if (x + y) % 2 == 0 then F(fe, x, y, 1, 1, "#9AA3A8") end end end
    F(fe, 170, 58, W - 170, 2, "#B4BCC0"); F(fe, 170, 60, W - 170, 1, "#6A737A"); F(fe, 170, 88, W - 170, 2, "#6A737A")
    for x = 176, W - 1, 40 do F(fe, x, 55, 3, 36, "#6A737A"); F(fe, x, 55, 1, 36, "#8A9399"); F(fe, x - 1, 54, 5, 2, "#8A9399") end
    -- a warning sign on the fence (plain: no company name)
    F(fe, 236, 66, 20, 14, "#F2F2EA"); F(fe, 236, 66, 20, 2, "#C23B2E"); F(fe, 238, 71, 16, 1, "#4A4D55"); F(fe, 238, 74, 12, 1, "#4A4D55"); F(fe, 238, 77, 14, 1, "#4A4D55")
    -- the dock wall: corrugated steel up top, white block below, a dirty foundation; the doorway is x 0..120
    for x = 0, 169 do
      local m = x % 4
      F(bu, x, -20, 1, 45, m == 0 and "#B4BCC0" or (m == 2 and "#8E979C" or "#A5AEB3"))
    end
    F(bu, 0, -22, 172, 2, "#6F787E"); F(bu, 0, -23, 172, 1, "#A8B0B4"); F(bu, 0, -20, 172, 1, "#4A525A")   -- the roof cap
    F(bu, 0, 25, 170, 2, "#6F787E"); F(bu, 0, 27, 170, 1, "#4A525A")
    F(bu, 0, 28, 170, 56, "#E9E6DC")
    for x = 0, 169, 8 do F(bu, x, 28, 1, 56, "#DDDACF") end
    for i = 0, 40 do F(bu, 126 + hash(i, 1, 311) % 40, 28 + hash(i, 2, 311) % 40, 1, 4 + hash(i, 3, 311) % 12, "#D8D4C6") end
    F(bu, 0, 74, 170, 10, "#DAD6C8"); F(bu, 0, 82, 170, 8, "#8E8B80"); F(bu, 0, 82, 170, 1, "#A8A598"); F(bu, 0, 86, 170, 4, "#3A3836")
    F(bu, 166, -22, 6, 112, "#4A525A"); F(bu, 167, -22, 1, 112, "#6A737A")         -- the corner column
    -- the doorway: a dark warehouse inside (a lit back wall, racking, a pallet), the housing box above and the tracks
    F(bu, 0, 12, 120, 76, "#4B4C52")
    F(bu, 0, 12, 120, 3, "#2A2B30")
    F(bu, 0, 15, 120, 52, "#5A5B62")
    for x = 0, 119, 6 do F(bu, x, 15, 1, 52, "#54555C") end
    F(bu, 0, 67, 120, 21, "#7E7F7A"); F(bu, 0, 67, 120, 2, "#5A5B57")               -- the far floor
    F(bu, 70, 26, 4, 61, "#2F5FA8"); F(bu, 108, 26, 4, 61, "#2F5FA8")               -- blue uprights of a rack
    for _, y in ipairs({34, 52, 70}) do F(bu, 70, y, 42, 3, "#E0902E") end
    F(bu, 74, 18, 14, 16, "#C9A06A"); F(bu, 90, 38, 16, 14, "#B88E58"); F(bu, 76, 56, 12, 14, "#C9A06A"); F(bu, 94, 20, 10, 12, "#B88E58")
    F(bu, 8, 62, 22, 18, "#C9A06A"); F(bu, 8, 78, 22, 3, "#9A7E56"); F(bu, 12, 62, 1, 18, "#A98050")   -- a pallet of boxes
    F(bu, 36, 76, 30, 6, "#8C8D88")
    F(bu, 0, 4, 132, 8, "#7A838B"); F(bu, 0, 4, 132, 1, "#A8B0B4"); F(bu, 0, 11, 132, 1, "#4A525A")   -- the housing box
    F(bu, 120, 12, 3, 78, "#4A525A"); F(bu, 123, 12, 3, 78, "#6A737A")             -- the right track and frame
    -- the dock light and a plain notice beside the door
    F(bu, 138, 30, 4, 6, "#4A4D55"); F(bu, 140, 32, 12, 2, "#8A8F9A"); F(bu, 149, 32, 3, 12, "#8A8F9A"); F(bu, 146, 42, 8, 6, "#F2C94C"); F(bu, 147, 47, 6, 2, "#FFF3C0")
    F(bu, 134, 56, 24, 14, "#F2F2EA"); F(bu, 134, 56, 24, 2, "#2F6FB8"); F(bu, 137, 61, 18, 1, "#4A4D55"); F(bu, 137, 64, 14, 1, "#4A4D55")
    F(bu, 130, 0, 3, 90, "#8E979C"); F(bu, 131, 0, 1, 90, "#A5AEB3")                -- a downspout
    -- ground: the concrete apron (x 0..156) and asphalt everywhere else, down to the bottom of the canvas
    local H = gr.height
    local y0 = 90 + L.YOFF
    local apron = 156
    for y = y0, H - 1 do
      for x = 0, W - 1 do
        local edge = apron + 2 * ((y // 6) % 3) + (hash(y // 3, 1, 320) % 3)
        local h = hash(x, y, 321)
        local c
        if x < edge then
          c = (hash(x // 6, y // 4, 322) % 6 == 0) and "#868782" or "#8C8D88"
          if h % 9 == 0 then c = "#979893" elseif h % 11 == 0 then c = "#7E7F7A" end
        else
          c = "#4A4D55"
          if h % 23 == 0 then c = "#43464E" elseif h % 23 == 1 then c = "#575A63" end
        end
        gr:putPixel(x, y, L.C(c))
      end
    end
    F(gr, 0, 90, W, 2, "#34363D"); F(gr, 0, 92, W, 2, "#3C3F47")                    -- the dark strip under the fence line
    F(gr, 0, 90, 154, 2, "#5A5B57"); F(gr, 0, 92, 154, 3, "#76776F")                -- the shadow under the dock wall
    for k = 0, 4 do F(gr, 30 + k * 36, 96, 1, 130, "#5C5D58"); F(gr, 31 + k * 36, 96, 1, 130, "#9A9B96") end   -- slab joints on the apron
    -- asphalt cracks and patches
    for k = 0, 14 do
      local cx, cy = 190 + k * 41 + hash(k, 1, 330) % 20, 112 + hash(k, 2, 330) % 70
      for i = 0, 6 + hash(k, 3, 330) % 12 do F(gr, cx + i, cy + (i // 3) * ((k % 2 == 0) and 1 or -1), 1, 1, "#3A3D44") end
    end
    F(gr, 508, 140, 40, 14, "#3F4249"); F(gr, 509, 141, 38, 12, "#44474E")
    -- the lines: a yellow hazard band across the dock threshold, a no-parking stripe, the white stall lines between the cars
    for x = 0, 125 do if (x // 6) % 2 == 0 then F(ln, x, 92, 6, 3, "#E8C838") end end
    F(ln, 0, 95, 126, 1, "#B89A28")
    for _, x in ipairs({272, 426, 560, 758}) do
      for y = 94, 114 do if hash(x, y, 340) % 7 ~= 0 then F(ln, x - (y - 94) // 3, y, 2, 1, "#D8D8D0") end end
    end
    F(ln, 176, 100, 1, 1, "#D8D8D0")
    local function lineText(str, x, y, sc, c)   -- big painted letters from the 3x5 grid
      local G = {
        D = {"XX.", "X.X", "X.X", "X.X", "XX."}, O = {"XXX", "X.X", "X.X", "X.X", "XXX"}, C = {"XXX", "X..", "X..", "X..", "XXX"},
        K = {"X.X", "X.X", "XX.", "X.X", "X.X"}, N = {"XXX", "X.X", "X.X", "X.X", "X.X"}, L = {"X..", "X..", "X..", "X..", "XXX"},
        A = {"XXX", "X.X", "XXX", "X.X", "X.X"}, I = {"XXX", ".X.", ".X.", ".X.", "XXX"}, G = {"XXX", "X..", "X.X", "X.X", "XXX"},
        [" "] = {"...", "...", "...", "...", "..."},
      }
      for i = 1, #str do
        local rows = G[str:sub(i, i)] or G[" "]
        for r = 1, 5 do for cc = 1, 3 do
          if rows[r]:sub(cc, cc) == "X" and hash(i * 5 + cc, r, 341) % 17 ~= 0 then F(ln, x + (i - 1) * 4 * sc + (cc - 1) * sc, y + (r - 1) * sc, sc, sc, c) end
        end end
      end
    end
    lineText("DOCK", 22, 138, 4, "#E8C838")                                         -- painted on the apron
    -- contact shadows and oil stains under the cars
    local function shadow(x, w) F(ln, x, 100, w, 8, "#2E3037"); F(ln, x + 2, 108, w - 4, 3, "#383A41") end
    shadow(296, 120); shadow(446, 104); shadow(594, 150); shadow(184, 62)
    F(ln, 330, 110, 12, 3, "#2A2B30"); F(ln, 620, 111, 14, 3, "#2A2B30"); F(ln, 470, 109, 8, 2, "#2A2B30")
    -- y-sorted props: the sort line is the base of the object (a car stands behind the player's walking line, y 118)
    s.putS("Props", P.lotDumpster(), 186, 72, 107, "lot_dumpster")
    s.putS("Props", P.lotPole(), 262, 16, 108, "lot_pole")
    s.putS("Props", P.lotSedan(), 290, 66, 107, "lot_sedan")
    s.putS("Props", P.lotHatch(), 440, 68, 107, "lot_hatch")
    s.putS("Props", P.lotPole(), 566, 16, 108, "lot_pole")
    s.putS("Props", P.lotVan(), 592, 46, 107, "lot_van")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 220, 56) end
  end}
end
