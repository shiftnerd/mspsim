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

  -- NIGHT (roadmap R41): the same street painted for the night match (builders.paintball_field_night, pieces pbn_*). Every colour of the
  -- day art goes through NM, a hand-picked ramp per material (wood, sand, rock, stone, hay, cactus, metal), and the light is painted
  -- into a "Light" layer (alpha): lanterns, the lit windows and the pools they throw. Anything missing from NM falls back to a cool multiply.
  local NM = {
    ["#D8A468"] = "#5C5A80", ["#B8844E"] = "#454264", ["#B87A44"] = "#454264", ["#A97A48"] = "#403E5E", ["#B88652"] = "#4A4768",
    ["#C89A62"] = "#54527A", ["#9A6A3A"] = "#383656", ["#8A5E32"] = "#2E2C4A", ["#8A5A32"] = "#2E2C4A", ["#7A4A2B"] = "#292744",
    ["#7A5A2B"] = "#292744", ["#6A4524"] = "#252340", ["#4A2E1C"] = "#1C1A30",
    ["#D8B27A"] = "#2F3A62", ["#CFA66E"] = "#2A3558", ["#E0BC86"] = "#3A4672", ["#B58A56"] = "#232D4E", ["#A87C4A"] = "#1E2744",
    ["#BE9158"] = "#262F52", ["#8A6A42"] = "#1A2240",
    ["#E8A66A"] = "#4E5A8A", ["#D48E56"] = "#38426E", ["#C47A48"] = "#2F3860", ["#B8683C"] = "#272F54", ["#A8603A"] = "#232A4C",
    ["#E0B07C"] = "#3C4878",
    ["#B8A07C"] = "#4A4E70", ["#8A7656"] = "#363A58",
    ["#D8B858"] = "#6A6A7A", ["#EED680"] = "#8484A0", ["#A88838"] = "#4A4A60",
    ["#8A8F9A"] = "#505670", ["#4A4D55"] = "#30334A", ["#C8CCD8"] = "#6A7090",
    ["#5A8CB8"] = "#2A4A8A", ["#8EC0E0"] = "#6A9AD0",
    ["#4F8F4F"] = "#25503F", ["#7AB878"] = "#3C7A60", ["#2F5F35"] = "#183A32", ["#F2E8B0"] = "#8A9AA0",
    ["#F2E8C8"] = "#8C90A8", ["#8A2E22"] = "#5A2438",
    ["#D8483A"] = "#A83A34", ["#3A68D8"] = "#3058B0", ["#22418A"] = "#1C3470",
    ["#B4846A"] = "#2C3460", ["#98705A"] = "#242B52", ["#C09878"] = "#323A68", ["#A87E60"] = "#2A3258", ["#D4B090"] = "#3A4474",
    ["#6E9A8A"] = "#2A4650", ["#9ABEAE"] = "#3E6068", ["#4E7A6C"] = "#1E3440", ["#C8483A"] = "#5A2A3C",
  }
  local function hx(c) return tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) end
  local function K(c)
    if NM[c] then return NM[c] end
    if c == OUT or c == "#F2C94C" or c == "#2A2A33" or c == "#17121F" then return c end
    local r, g, b = hx(c)
    return string.format("#%02X%02X%02X", math.floor(r * 0.3 + 8), math.floor(g * 0.34 + 10), math.floor(b * 0.55 + 28))
  end
  local function withNight(on, f)
    local old = L.fill
    if on then L.fill = function(im, x, y, w, h, c) old(im, x, y, w, h, K(c)) end end
    local ok, e = pcall(f)
    L.fill = old
    if not ok then error(e) end
  end
  local function putA(im, x, y, c, a)
    if x < 0 or y < 0 or x >= im.width or y >= im.height then return end
    local r, g, b = hx(c)
    im:putPixel(x, y, Color{r = r, g = g, b = b, a = math.floor(math.min(a * 1.4, 0.5) * 255)})
  end
  -- a banded glow: rings from the outside in, each with its own alpha (builder coordinates)
  local function glow(im, cx, cy, rx, ry, c, alphas)
    for k, a in ipairs(alphas) do
      local sc = 1.0 - (k - 1) / #alphas * 0.62
      local ax, ay = rx * sc, ry * sc
      for y = math.floor(cy - ay), math.ceil(cy + ay) do
        for x = math.floor(cx - ax), math.ceil(cx + ax) do
          local dx, dy = (x - cx) / ax, (y - cy) / ay
          if dx * dx + dy * dy <= 1.0 then putA(im, x + L.XOFF, y + L.YOFF, c, a) end
        end
      end
    end
  end
  local function line(im, x0, y0, x1, y1, c)
    local n = math.max(math.abs(x1 - x0), math.abs(y1 - y0))
    for i = 0, n do
      L.fill(im, math.floor(x0 + (x1 - x0) * i / math.max(n, 1) + 0.5) + L.XOFF, math.floor(y0 + (y1 - y0) * i / math.max(n, 1) + 0.5) + L.YOFF, 1, 1, c)
    end
  end

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

  -- the night's light (alpha, top layer): halos round every lit window and lantern, a fan of light from each open doorway and pools on the boardwalk
  local function fan(im, cx, y0, y1, w0, w1, c, a)
    for y = y0, y1 do
      local w = w0 + (w1 - w0) * (y - y0) / (y1 - y0)
      for x = math.floor(cx - w / 2), math.ceil(cx + w / 2) do putA(im, x + L.XOFF, y + L.YOFF, c, a) end
    end
  end
  local function NIGHT_LIGHT(lt, jx, lamps)
    local WARM = "#F2C94C"
    for _, wx in ipairs({20, 44, 108, 132}) do glow(lt, wx + 8, 46, 17, 17, WARM, {0.05, 0.08, 0.12}) end
    for _, wx in ipairs({184, 238}) do glow(lt, wx + 9, 54, 16, 13, WARM, {0.05, 0.08, 0.12}) end
    glow(lt, jx + 124, 57, 18, 16, WARM, {0.04, 0.07, 0.1})
    glow(lt, 224, 66, 14, 22, WARM, {0.05, 0.08})
    glow(lt, 84, 70, 22, 26, WARM, {0.05, 0.08})
    fan(lt, 84, 88, 104, 40, 72, WARM, 0.08); fan(lt, 84, 88, 98, 30, 52, WARM, 0.06)
    fan(lt, 224, 88, 100, 22, 46, WARM, 0.07)
    for _, lp in ipairs(lamps) do
      glow(lt, lp[1], lp[2] + 3, 15, 13, WARM, {0.05, 0.09, 0.15})
      glow(lt, lp[1], 91, 22, 4, WARM, {0.07, 0.1})
    end
    glow(lt, 456, 93, 34, 6, WARM, {0.05, 0.08, 0.11})   -- the post lamp's pool on the street
  end

  -- ------------------------------------------------------------------ the set
  local function field(s, night)
    local pn = night and "pbn_" or "pb_"
    local sky = night and s.layer("Sky") or nil
    local mesa, tow, gr, ln = s.layer("Mesas"), s.layer("Town"), s.layer("Ground"), s.layer("Lines")
    local function G(im, x, y, w, h, c) F(im, x, y, w, h, c) end
    if night then   -- the night sky: banded gradient with a checker dither between bands, stars, a moon, a few dark clouds
      local bands = {"#080C26", "#0B1030", "#0F163A", "#141D46", "#1A2552", "#212E60", "#2A396E", "#33447C", "#3E508A", "#4A5C96"}
      local nb = #bands
      for y = -100, 90 do
        local f = (y + 100) / 190 * (nb - 1)
        local i = math.floor(f)
        for x = 0, W - 1 do
          local k = i + 1
          if f - i > 0.5 and ((x + y) % 2 == 0) then k = k + 1 elseif f - i > 0.25 and f - i <= 0.5 and (x % 2 == 0 and y % 2 == 0) then k = k + 1 end
          G(sky, x, y, 1, 1, bands[math.min(k, nb)])
        end
      end
      for i = 0, 130 do
        local sx, sy = hash(i, 1, 501) % W, -98 + hash(i, 2, 501) % 150
        local br = hash(i, 3, 501) % 4
        G(sky, sx, sy, 1, 1, br == 0 and "#F4F0D8" or (br == 1 and "#B8C4F0" or "#7A88C8"))
        if br == 0 and i % 3 == 0 then G(sky, sx - 1, sy, 3, 1, "#8A96D0"); G(sky, sx, sy - 1, 1, 3, "#8A96D0"); G(sky, sx, sy, 1, 1, "#FFFFFF") end
      end
      for _, cl in ipairs({{60, -30, 52}, {250, -60, 40}, {330, -20, 60}, {560, -48, 48}, {640, -12, 36}}) do   -- long thin dark clouds
        G(sky, cl[1], cl[2], cl[3], 2, "#1E2A58"); G(sky, cl[1] + 6, cl[2] + 2, cl[3] - 14, 2, "#192450"); G(sky, cl[1] + 14, cl[2] - 1, cl[3] // 2, 1, "#2C3A70")
      end
      local mx, my, mr = 452, -34, 9      -- the moon, a crescent: a lit disc with a darker bite from the upper right
      for y = -mr, mr do for x = -mr, mr do
        local d = x * x + y * y
        if d <= mr * mr then
          local bite = (x - 4) * (x - 4) + (y + 3) * (y + 3) <= 7 * 7
          if not bite then G(sky, mx + x, my + y, 1, 1, (x + y < -2) and "#FFFCE8" or ((d > 56) and "#D8D4B8" or "#F4F0D8")) end
        end
      end end
    end
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
    G(tow, x0 + 112, 46, 24, 22, OUT); G(tow, x0 + 113, 47, 22, 20, night and "#C8962E" or "#2A2A33")   -- the barred window
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
    -- R41 dressing. Everything here stands on the boardwalk line (y 88) or behind it, never in the lanes (y 104..132), and the cover pieces
    -- are brown and warm: the new buildings are green-grey, white and blue-grey so nothing in the background can be taken for a barricade.
    local HZ1, HZ2, HZ3, HZ4 = "#B4846A", "#98705A", "#C09878", "#A87E60"
    -- far layer: a church with a steeple, a bank with columns, painted hazy (no outline) on the rocks
    G(mesa, 270, 62, 34, 27, HZ1); G(mesa, 270, 62, 34, 1, HZ3)
    for i = 0, 8 do G(mesa, 268 + i * 2, 62 - i, 38 - i * 4, 1, i % 2 == 0 and HZ1 or HZ3) end
    G(mesa, 283, 38, 8, 24, HZ1); G(mesa, 284, 38, 1, 24, HZ3)
    for i = 0, 5 do G(mesa, 283 + (i < 3 and i or 5 - i), 32 + 5 - i, 8 - 2 * (i < 3 and i or 5 - i), 1, HZ2) end
    G(mesa, 286, 22, 2, 12, HZ2); G(mesa, 283, 26, 8, 1, HZ2)
    G(mesa, 285, 44, 4, 7, HZ2); G(mesa, 274, 70, 4, 9, HZ2); G(mesa, 296, 70, 4, 9, HZ2)
    G(mesa, 384, 58, 58, 31, HZ3); G(mesa, 380, 55, 66, 4, HZ4); G(mesa, 392, 48, 42, 7, HZ4)
    for i = 0, 4 do G(mesa, 389 + i * 12, 60, 4, 29, HZ1) end
    G(mesa, 384, 85, 58, 4, HZ2); G(mesa, 408, 66, 10, 19, HZ2)
    -- the windmill: a lattice tower, a hub, four blades and a tail vane
    do
      local ml = "#4A4D55"
      line(tow, 462, 88, 472, 36, ml); line(tow, 490, 88, 480, 36, ml); line(tow, 466, 66, 486, 66, ml); line(tow, 464, 78, 488, 78, ml)
      line(tow, 466, 66, 488, 78, ml); line(tow, 486, 66, 464, 78, ml)
      G(tow, 470, 33, 12, 4, "#8A8F9A"); G(tow, 475, 28, 3, 8, "#8A8F9A"); G(tow, 471, 36, 10, 1, ml)
      line(tow, 476, 31, 476 + 17, 31 - 9, "#C8CCD8"); line(tow, 476, 31, 476 - 17, 31 + 9, "#C8CCD8")
      line(tow, 476, 31, 476 + 9, 31 + 17, "#C8CCD8"); line(tow, 476, 31, 476 - 9, 31 - 17, "#C8CCD8")
      line(tow, 476, 31, 476 + 17, 31 - 8, "#8A8F9A"); line(tow, 476, 31, 476 - 17, 31 + 8, "#8A8F9A")
      G(tow, 482, 32, 12, 3, "#4A4D55"); G(tow, 490, 28, 6, 6, "#C8483A")
    end
    -- the general store: green clapboard, a striped awning, a sign, two windows and a door, wanted posters beside it
    board(tow, 178, 46, 90, 42, "#6E9A8A", "#4E7A6C")
    G(tow, 176, 40, 94, 6, OUT); G(tow, 177, 41, 92, 4, "#4E7A6C"); G(tow, 177, 41, 92, 1, "#9ABEAE")
    G(tow, 196, 32, 54, 9, OUT); G(tow, 197, 33, 52, 8, "#9ABEAE"); G(tow, 197, 33, 52, 1, "#F2E8C8")
    font.T = {"XXX", ".X.", ".X.", ".X.", ".X."}; font.R = {"XXX", "X.X", "XXX", "XX.", "X.X"}; font.E = {"XXX", "X..", "XXX", "X..", "XXX"}
    word(tow, "STORE", 204, 35, 2, "#2A2A33")
    for i = 0, 13 do G(tow, 176 + i * 7, 62, 7, 4, (i % 2 == 0) and "#C8483A" or "#F2E8C8") end    -- the awning
    G(tow, 176, 66, 98, 1, OUT)
    G(tow, 178, 66, 2, 21, "#6A4524"); G(tow, 266, 66, 2, 21, "#6A4524")                         -- awning posts
    for _, wx in ipairs({184, 238}) do G(tow, wx, 48, 18, 13, OUT); G(tow, wx + 1, 49, 16, 11, "#F2C94C"); G(tow, wx + 8, 49, 1, 11, OUT); G(tow, wx + 1, 54, 16, 1, OUT) end
    G(tow, 214, 50, 20, 37, OUT); G(tow, 215, 51, 18, 36, "#4E7A6C"); G(tow, 218, 54, 12, 14, "#F2C94C"); G(tow, 218, 61, 12, 1, OUT); G(tow, 223, 54, 1, 14, OUT)
    G(tow, 228, 72, 2, 2, "#F2C94C")
    for _, px in ipairs({204, 244}) do      -- wanted posters
      G(tow, px - 1, 71, 12, 14, OUT); G(tow, px, 72, 10, 12, "#F2E8C8"); G(tow, px + 3, 74, 4, 4, "#8A6A42"); G(tow, px + 2, 79, 6, 1, "#4A4D55"); G(tow, px + 2, 81, 5, 1, "#4A4D55")
    end
    G(tow, 176, 86, 98, 6, "#6A4524"); G(tow, 176, 86, 98, 1, "#8A5A32")                         -- the store's porch boards
    -- a crate on the store porch; barrels by the jail and at the saloon's corner (all behind the lanes)
    G(tow, 256, 77, 12, 9, OUT); G(tow, 257, 78, 10, 7, "#B8844E"); G(tow, 257, 78, 10, 1, "#D8A468"); G(tow, 262, 78, 1, 7, "#8A5E32")
    for _, bx in ipairs({532, 164}) do G(tow, bx, 76, 11, 11, OUT); G(tow, bx + 1, 77, 9, 9, "#8A5A32"); G(tow, bx + 1, 79, 9, 1, "#4A4D55"); G(tow, bx + 1, 83, 9, 1, "#4A4D55"); G(tow, bx + 2, 77, 2, 9, "#A97A48") end
    -- hitching posts: two posts and a rail, on the street edge of the boardwalk
    for _, hx0 in ipairs({178, 396, 520}) do
      G(tow, hx0, 84, 3, 9, OUT); G(tow, hx0 + 1, 85, 1, 8, "#6A4524"); G(tow, hx0 + 19, 84, 3, 9, OUT); G(tow, hx0 + 20, 85, 1, 8, "#6A4524")
      G(tow, hx0, 86, 22, 3, OUT); G(tow, hx0 + 1, 87, 20, 1, "#A97A48")
    end
    -- lanterns (dark and cold by day, lit at night): saloon doorway, store awning, jail door, a post lamp by the windmill
    local lampPts = {{62, 58}, {106, 58}, {208, 68}, {246, 68}, {x0 + 8, 54}, {x0 + 50, 54}, {456, 60}}
    for _, lp in ipairs(lampPts) do
      G(tow, lp[1], lp[2] - 4, 1, 4, OUT); G(tow, lp[1] - 2, lp[2], 5, 1, OUT)
      G(tow, lp[1] - 2, lp[2] + 1, 5, 6, OUT); G(tow, lp[1] - 1, lp[2] + 1, 3, 5, night and "#F2C94C" or "#C8B88A"); G(tow, lp[1], lp[2] + 2, 1, 3, night and "#FFF2B0" or "#E8DCB0")
    end
    G(tow, 455, 66, 3, 22, OUT); G(tow, 456, 66, 1, 22, "#4A4D55")
    -- ground: packed sand all the way to the bottom of the canvas, with wheel ruts and pebbles
    local H = gr.height
    local y0 = 90 + L.YOFF
    for y = y0, H - 1 do
      for x = 0, W - 1 do
        local h = hash(x, y, 410)
        local c = "#D8B27A"
        if h % 7 == 0 then c = "#CFA66E" elseif h % 11 == 0 then c = "#E0BC86" elseif h % 31 == 0 then c = "#B58A56" end
        if y - y0 > 22 and hash(x // 9, y // 5, 411) % 5 == 0 then c = "#CFA66E" end
        gr:putPixel(x, y, L.C(night and K(c) or c))
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
    s.putS("Props", P.pbCrates(), 165, 92, 119, pn .. "crates")
    s.putS("Props", P.pbBarrels(), 250, 90, 119, pn .. "barrels")
    s.putS("Props", P.pbHay(), 335, 98, 119, pn .. "hay")
    s.putS("Props", P.pbTrough(), 418, 98, 119, pn .. "trough")
    s.putS("Props", P.pbWagon(), 499, 88, 119, pn .. "wagon")
    s.putS("Props", P.pbCactus(), 215, 78, 111, pn .. "cactus")
    s.putS("Props", P.pbCactus(), 300, 78, 111, pn .. "cactus")
    s.putS("Props", P.pbCactus(), 560, 78, 111, pn .. "cactus")
    if night then
      NIGHT_LIGHT(s.layer("Light"), x0, lampPts)
    elseif not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 120, 56) end
  end
  builders.paintball_field = {W = W, H = 128, outdoor = true, fn = function(s) field(s, false) end}
  builders.paintball_field_night = {W = W, H = 128, outdoor = true, fn = function(s) withNight(true, function() field(s, true) end) end}
end
