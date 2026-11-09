-- The PAINTBALL FIELD: a dusty western main street, 700 px wide, side-on like every other set. Loaded by build_sets.lua:
-- dofile(TOOLS .. "paintball_set.lua")(L, builders). Builder coordinates are the old 0..128 band (floor line y 118). The sky is a
-- TRANSPARENT HOLE in the art (godot/scripts/outside.gd, node Backdrop, draws it behind the Background). The field is
-- the street between x 30 and x 670 (game x 0..640 = set x 30..670): the SALOON end on the left (your team's flag stands at set
-- x 64), the JAIL end on the right (the other team's flag at set x 636). The five barricades are y-sorted pieces at set x
-- 180, 265, 350, 435, 520 (paintball_game.gd BARRICADES + 30): a crate stack, barrels, a hay bale, a water trough, a wagon.
-- Y-sorted pieces: pb_crates, pb_barrels, pb_hay, pb_trough, pb_wagon, pb_cactus.
return function(L, builders)
  local P = L.P
  local W = 700
  local function F(im, x, y, w, h, c) L.fill(im, x + L.XOFF, y + L.YOFF, w, h, c) end
  local function hash(a, b, c)
    local h = a * 73856093 + b * 19349663 + c * 83492791
    h = (h ~ (h >> 15)) * 2246822519 % 4294967296
    h = (h ~ (h >> 13)) * 3266489917 % 4294967296
    return (h ~ (h >> 16)) % 1000003
  end
  local OUT = "#17121F"

  -- a stack of wooden crates: two on the ground, one on top
  function P.pbCrates()
    return L.piece(30, 26, function(R)
      local function crate(x, y, w, h)
        R(x, y, w, h, OUT); R(x + 1, y + 1, w - 2, h - 2, "#B8844E")
        R(x + 1, y + 1, w - 2, 1, "#D8A468"); R(x + 1, y + h - 2, w - 2, 1, "#8A5E32")
        R(x + 1, y + 1, 2, h - 2, "#8A5E32"); R(x + w - 3, y + 1, 2, h - 2, "#8A5E32")
        for i = 0, h - 3 do R(x + 3 + (i % (w - 6)), y + 1 + i, 1, 1, "#8A5E32") end   -- the diagonal brace
      end
      crate(0, 12, 15, 14); crate(15, 12, 15, 14); crate(7, 0, 15, 12)
    end)
  end

  -- two barrels side by side with a third on top
  function P.pbBarrels()
    return L.piece(30, 28, function(R)
      local function barrel(x, y)
        R(x + 1, y, 11, 14, OUT); R(x, y + 2, 13, 10, OUT)
        R(x + 1, y + 1, 11, 12, "#8A5A32"); R(x + 2, y + 1, 3, 12, "#A97A48")
        R(x + 1, y + 3, 11, 1, "#4A4D55"); R(x + 1, y + 9, 11, 1, "#4A4D55")
        R(x + 9, y + 1, 2, 12, "#6A4524")
      end
      barrel(2, 14); barrel(16, 14); barrel(9, 3)
    end)
  end

  -- a round hay bale on its side, strapped, with straw sticking out
  function P.pbHay()
    return L.piece(30, 20, function(R)
      R(2, 2, 26, 18, OUT); R(0, 5, 30, 12, OUT)
      R(3, 3, 24, 16, "#D8B858"); R(1, 6, 28, 10, "#D8B858")
      R(3, 3, 24, 2, "#EED680"); R(4, 17, 22, 2, "#A88838")
      for i = 0, 11 do R(5 + (i * 7) % 20, 5 + (i * 5) % 11, 4, 1, "#A88838") end
      R(9, 3, 2, 16, "#7A5A2B"); R(19, 3, 2, 16, "#7A5A2B")
      R(24, 1, 1, 3, "#D8B858"); R(6, 2, 1, 2, "#EED680"); R(28, 9, 3, 1, "#D8B858")
    end)
  end

  -- a long wooden water trough on two trestles
  function P.pbTrough()
    return L.piece(34, 20, function(R)
      R(0, 6, 34, 8, OUT); R(1, 7, 32, 6, "#8A5A32"); R(1, 7, 32, 1, "#A97A48")
      R(2, 8, 30, 2, "#5A8CB8"); R(2, 8, 30, 1, "#8EC0E0")    -- the water
      R(3, 13, 3, 7, OUT); R(4, 14, 1, 6, "#6A4524"); R(28, 13, 3, 7, OUT); R(29, 14, 1, 6, "#6A4524")
      R(10, 7, 1, 7, "#6A4524"); R(23, 7, 1, 7, "#6A4524")
    end)
  end

  -- a farm wagon seen from the side: a tall box, two big spoked wheels
  function P.pbWagon()
    return L.piece(42, 30, function(R)
      R(2, 6, 38, 14, OUT); R(3, 7, 36, 12, "#9A6A3A"); R(3, 7, 36, 2, "#B88652"); R(3, 15, 36, 3, "#6A4524")
      for x = 7, 35, 7 do R(x, 8, 1, 10, "#6A4524") end
      R(0, 3, 4, 3, OUT); R(1, 3, 2, 2, "#B88652"); R(38, 3, 4, 3, OUT)    -- the corner posts
      for _, cx in ipairs({10, 32}) do
        for y = -8, 8 do for x = -8, 8 do
          local d = x * x + y * y
          if d <= 81 then R(cx + x, 20 + y, 1, 1, (d >= 49) and OUT or (d >= 36 and "#7A4A2B" or "#C89A62")) end
        end end
        R(cx, 14, 1, 12, OUT); R(cx - 6, 20, 12, 1, OUT)
        R(cx - 1, 19, 3, 3, OUT)
      end
    end)
  end

  -- a tall saguaro cactus with two arms
  function P.pbCactus()
    return L.piece(22, 40, function(R)
      local g, h, s = "#4F8F4F", "#7AB878", "#2F5F35"
      R(8, 0, 6, 40, OUT); R(9, 1, 4, 38, g); R(9, 1, 1, 38, h); R(12, 1, 1, 38, s)
      R(1, 12, 8, 4, OUT); R(2, 13, 6, 2, g); R(1, 6, 4, 10, OUT); R(2, 7, 2, 8, g); R(2, 7, 1, 8, h)
      R(13, 18, 8, 4, OUT); R(14, 19, 6, 2, g); R(17, 10, 4, 12, OUT); R(18, 11, 2, 10, g); R(18, 11, 1, 10, h)
      for y = 3, 36, 5 do R(8, y, 1, 1, "#F2E8B0"); R(14, y + 2, 1, 1, "#F2E8B0") end
    end)
  end

  -- ------------------------------------------------------------------ the set
  builders.paintball_field = {W = W, H = 128, outdoor = true, fn = function(s)
    local mesa, tow, gr, ln = s.layer("Mesas"), s.layer("Town"), s.layer("Ground"), s.layer("Lines")
    local function G(im, x, y, w, h, c) F(im, x, y, w, h, c) end
    -- far mesas and hills against the transparent sky: jagged orange rock with a lit top edge
    local top = {}
    for x = 0, W - 1 do
      local m1 = 0.5 + 0.5 * math.sin(x * 0.011 + 1.3)
      local m2 = 0.5 + 0.5 * math.sin(x * 0.037 + 0.4)
      local flat = math.floor(m1 * 26) - (hash(x // 5, 1, 401) % 3)
      if m1 > 0.62 then flat = 24 + math.floor(m2 * 3) end   -- a flat-topped mesa
      top[x] = 62 - math.max(flat, 4)
    end
    for x = 0, W - 1 do
      local t = top[x]
      for y = t, 89 do
        local c = (y < t + 2) and "#E8A66A" or ((y - t) % 7 < 2 and "#C47A48" or "#D48E56")
        if hash(x, y, 402) % 13 == 0 then c = "#B8683C" end
        G(mesa, x, y, 1, 1, c)
      end
      G(mesa, x, 74, 1, 3, "#A8603A")
    end
    -- a pale haze at the foot of the rocks
    G(mesa, 0, 77, W, 13, "#E0B07C")
    -- the saloon, left end: a false front over a two-storey wooden box, a balcony, swinging doors
    local function board(im, x, y, w, h, c, sh)
      G(im, x, y, w, h, c)
      for i = 0, w - 1, 6 do G(im, x + i, y, 1, h, sh) end
      G(im, x, y, w, 1, "#D8A468")
    end
    board(tow, 8, 30, 150, 58, "#B87A44", "#8A5A32")                     -- the saloon front
    G(tow, 4, 22, 158, 8, OUT); G(tow, 5, 23, 156, 6, "#8A5A32"); G(tow, 5, 23, 156, 1, "#B8844E")   -- cornice
    board(tow, 28, 8, 110, 16, "#B87A44", "#8A5A32")                      -- the false front rises above
    G(tow, 24, 4, 118, 5, OUT); G(tow, 25, 5, 116, 3, "#8A5A32")
    G(tow, 40, 11, 86, 10, "#F2E8C8"); G(tow, 40, 11, 86, 1, "#17121F"); G(tow, 40, 20, 86, 1, "#17121F")   -- the sign board
    local font = {S = {"XXX", "X..", "XXX", "..X", "XXX"}, A = {"XXX", "X.X", "XXX", "X.X", "X.X"}, L = {"X..", "X..", "X..", "X..", "XXX"},
      O = {"XXX", "X.X", "X.X", "X.X", "XXX"}, N = {"XXX", "X.X", "X.X", "X.X", "X.X"}, J = {"..X", "..X", "..X", "X.X", "XXX"},
      I = {"XXX", ".X.", ".X.", ".X.", "XXX"}, [" "] = {"...", "...", "...", "...", "..."}}
    local function word(im, str, x, y, sc, c)
      for i = 1, #str do
        local rows = font[str:sub(i, i)] or font[" "]
        for r = 1, 5 do for cc = 1, 3 do
          if rows[r]:sub(cc, cc) == "X" then G(im, x + (i - 1) * 4 * sc + (cc - 1) * sc, y + (r - 1) * sc, sc, sc, c) end
        end end
      end
    end
    word(tow, "SALOON", 47, 13, 2, "#8A2E22")
    for _, wx in ipairs({20, 44, 108, 132}) do      -- windows with shutters
      G(tow, wx, 36, 16, 20, OUT); G(tow, wx + 1, 37, 14, 18, "#F2C94C"); G(tow, wx + 7, 37, 1, 18, OUT); G(tow, wx + 1, 45, 14, 1, OUT)
      G(tow, wx - 4, 36, 4, 20, "#6A4524"); G(tow, wx + 16, 36, 4, 20, "#6A4524")
    end
    G(tow, 6, 62, 154, 3, OUT); G(tow, 6, 62, 154, 1, "#B8844E")          -- the balcony rail
    for x = 8, 158, 10 do G(tow, x, 56, 2, 6, "#6A4524") end
    G(tow, 66, 52, 36, 36, OUT); G(tow, 67, 53, 34, 35, "#4A2E1C")        -- the doorway
    G(tow, 68, 60, 16, 28, "#A97A48"); G(tow, 84, 60, 16, 28, "#A97A48") -- the swinging doors (slatted)
    for y = 62, 86, 4 do G(tow, 68, y, 16, 1, "#6A4524"); G(tow, 84, y, 16, 1, "#6A4524") end
    G(tow, 8, 86, 150, 6, "#6A4524"); G(tow, 8, 86, 150, 1, "#8A5A32")    -- the porch boards
    -- the jail / sheriff's office, right end: stone below, a wooden roof edge, barred window, a notice
    local x0 = 548
    G(tow, x0, 34, 152, 54, OUT); G(tow, x0 + 1, 35, 150, 52, "#B8A07C")
    for y = 36, 86, 6 do G(tow, x0 + 1, y, 150, 1, "#8A7656") end
    for r = 0, 8 do for x = (r % 2) * 5, 149, 10 do G(tow, x0 + 1 + x, 36 + r * 6, 1, 6, "#8A7656") end end
    G(tow, x0 - 4, 26, 160, 8, OUT); G(tow, x0 - 3, 27, 158, 6, "#6A4524"); G(tow, x0 - 3, 27, 158, 1, "#8A5A32")
    G(tow, x0 + 20, 8, 112, 18, OUT); G(tow, x0 + 21, 9, 110, 16, "#B87A44"); G(tow, x0 + 21, 9, 110, 1, "#D8A468")   -- the sign board
    word(tow, "JAIL", x0 + 46, 12, 2, "#2A2A33")
    G(tow, x0 + 112, 46, 24, 22, OUT); G(tow, x0 + 113, 47, 22, 20, "#2A2A33")   -- the barred window
    for x = 114, 133, 5 do G(tow, x0 + x, 47, 2, 20, "#8A8F9A") end
    G(tow, x0 + 12, 50, 36, 38, OUT); G(tow, x0 + 13, 51, 34, 37, "#6A4524")     -- the door
    for x = 18, 44, 8 do G(tow, x0 + x, 51, 1, 37, "#4A2E1C") end
    G(tow, x0 + 40, 70, 3, 3, "#F2C94C")
    G(tow, x0 + 60, 54, 18, 14, "#F2E8C8"); G(tow, x0 + 60, 54, 18, 1, OUT)       -- a wanted poster
    G(tow, x0 + 62, 58, 14, 1, "#4A4D55"); G(tow, x0 + 62, 61, 10, 1, "#4A4D55"); G(tow, x0 + 62, 64, 12, 1, "#4A4D55")
    G(tow, x0, 86, 152, 6, "#6A4524"); G(tow, x0, 86, 152, 1, "#8A5A32")
    -- a lone water tower and a hitching rail in the middle distance
    G(tow, 330, 40, 4, 40, "#4A2E1C"); G(tow, 358, 40, 4, 40, "#4A2E1C"); G(tow, 334, 60, 24, 1, "#4A2E1C")
    G(tow, 324, 22, 44, 20, OUT); G(tow, 325, 23, 42, 18, "#A97A48")
    for x = 330, 366, 7 do G(tow, x, 23, 1, 18, "#6A4524") end
    G(tow, 322, 20, 48, 3, "#8A5A32"); G(tow, 344, 14, 4, 6, "#4A2E1C")
    -- ground: packed sand all the way to the bottom of the canvas, with wheel ruts and pebbles
    local H = gr.height
    local y0 = 90 + L.YOFF
    for y = y0, H - 1 do
      for x = 0, W - 1 do
        local h = hash(x, y, 410)
        local c = "#D8B27A"
        if h % 7 == 0 then c = "#CFA66E" elseif h % 11 == 0 then c = "#E0BC86" elseif h % 31 == 0 then c = "#B58A56" end
        if y - y0 > 22 and hash(x // 9, y // 5, 411) % 5 == 0 then c = "#CFA66E" end
        gr:putPixel(x, y, L.C(c))
      end
    end
    G(gr, 0, 90, W, 2, "#A87C4A"); G(gr, 0, 92, W, 1, "#BE9158")             -- the edge of the boardwalk shadow
    for _, ry in ipairs({104, 109}) do                                       -- wheel ruts down the street
      for x = 30, W - 30 do if hash(x, ry, 412) % 4 ~= 0 then G(gr, x, ry, 1, 1, "#B58A56") end end
    end
    for k = 0, 40 do G(gr, 20 + hash(k, 1, 413) % (W - 40), 96 + hash(k, 2, 413) % 26, 2, 1, "#8A6A42") end    -- pebbles
    -- the two bases: a roped square of sand in each team's colour, where the flag stands (set x 64 and 636)
    local function base(cx, col, dark)
      G(ln, cx - 22, 100, 44, 1, col); G(ln, cx - 22, 125, 44, 1, col)
      G(ln, cx - 22, 100, 1, 26, col); G(ln, cx + 21, 100, 1, 26, col)
      for i = 0, 5 do G(ln, cx - 22 + i * 8, 100, 2, 1, dark); G(ln, cx - 22 + i * 8, 125, 2, 1, dark) end
    end
    base(64, "#D8483A", "#8A2E22")
    base(636, "#3A68D8", "#22418A")
    -- the barricades, y-sorted (their sort line is their base on the floor); a few decorative cacti and a tumbleweed
    s.putS("Props", P.pbCrates(), 165, 92, 119, "pb_crates")
    s.putS("Props", P.pbBarrels(), 250, 90, 119, "pb_barrels")
    s.putS("Props", P.pbHay(), 335, 98, 119, "pb_hay")
    s.putS("Props", P.pbTrough(), 418, 98, 119, "pb_trough")
    s.putS("Props", P.pbWagon(), 499, 88, 119, "pb_wagon")
    s.putS("Props", P.pbCactus(), 215, 78, 111, "pb_cactus")
    s.putS("Props", P.pbCactus(), 300, 78, 111, "pb_cactus")
    s.putS("Props", P.pbCactus(), 560, 78, 111, "pb_cactus")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 120, 56) end
  end}
end
