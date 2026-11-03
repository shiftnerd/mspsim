-- The three team-outing rooms: bowling alley, karaoke bar, escape room (320 px wide, dark, neon).
-- Loaded by build_sets.lua:  local reg = dofile(TOOLS .. "outing_sets.lua"); reg(L, builders)
-- Each builder has the usual shape {W, H, fn}; `post` darkens the ceiling afterwards.
return function(L, builders)
  local P = L.P
  local OUT = "#17121F"

  -- ---------------------------------------------------------------- helpers
  local function F(im, x, y, w, h, col) L.fill(im, x + L.XOFF, y + L.YOFF, w, h, col) end   -- set coordinates
  local function disc(R, cx, cy, r, col)
    for y = -r, r do for x = -r, r do
      if x * x + y * y <= r * r + r * 0.6 then R(cx + x, cy + y, 1, 1, col) end
    end end
  end
  local function hash(a, b, c)
    local h = a * 73856093 + b * 19349663 + c * 83492791
    h = (h ~ (h >> 15)) * 2246822519 % 4294967296
    h = (h ~ (h >> 13)) * 3266489917 % 4294967296
    return (h ~ (h >> 16)) % 1000003
  end

  -- 3x5 pixel font (the same one the game UI uses), upper case
  local G = {
    A = {"XXX","X.X","XXX","X.X","X.X"}, B = {"XX.","X.X","XX.","X.X","XX."}, C = {".XX","X..","X..","X..",".XX"},
    D = {"XX.","X.X","X.X","X.X","XX."}, E = {"XXX","X..","XX.","X..","XXX"}, F = {"XXX","X..","XX.","X..","X.."},
    G = {".XX","X..","X.X","X.X",".XX"}, H = {"X.X","X.X","XXX","X.X","X.X"}, I = {"XXX",".X.",".X.",".X.","XXX"},
    K = {"X.X","X.X","XX.","X.X","X.X"}, L = {"X..","X..","X..","X..","XXX"}, M = {"X.X","XXX","XXX","X.X","X.X"},
    N = {"XXX","X.X","X.X","X.X","X.X"}, O = {".X.","X.X","X.X","X.X",".X."}, P = {"XX.","X.X","XX.","X..","X.."},
    R = {"XX.","X.X","XX.","X.X","X.X"}, S = {".XX","X..",".X.","..X","XX."}, T = {"XXX",".X.",".X.",".X.",".X."},
    U = {"X.X","X.X","X.X","X.X","XXX"}, W = {"X.X","X.X","XXX","XXX","X.X"}, X = {"X.X","X.X",".X.","X.X","X.X"},
    Y = {"X.X","X.X",".X.",".X.",".X."}, Z = {"XXX","..X",".X.","X..","XXX"},
    ["0"] = {"XXX","X.X","X.X","X.X","XXX"}, ["1"] = {".X.","XX.",".X.",".X.","XXX"}, ["2"] = {"XX.","..X",".X.","X..","XXX"},
    ["3"] = {"XX.","..X",".X.","..X","XX."}, ["4"] = {"X.X","X.X","XXX","..X","..X"}, ["5"] = {"XXX","X..","XX.","..X","XX."},
    ["6"] = {".XX","X..","XXX","X.X","XXX"}, ["7"] = {"XXX","..X",".X.",".X.",".X."}, ["8"] = {"XXX","X.X","XXX","X.X","XXX"},
    ["9"] = {"XXX","X.X","XXX","..X","XX."}, [":"] = {"...",".X.","...",".X.","..."}, ["!"] = {".X.",".X.",".X.","...",".X."},
    ["$"] = {".XX","XX.",".X.",".XX","XX."}, [" "] = {"...","...","...","...","..."},
  }
  local function textW(str, sc) return #str * 4 * sc - sc end
  local function drawText(R, str, x, y, sc, col)
    for i = 1, #str do
      local rows = G[str:sub(i, i)] or G[" "]
      for r = 1, 5 do for c = 1, 3 do
        if rows[r]:sub(c, c) == "X" then R(x + (i - 1) * 4 * sc + (c - 1) * sc, y + (r - 1) * sc, sc, sc, col) end
      end end
    end
  end
  local function neonText(str, sc, col, plate)
    local w, h = textW(str, sc) + 6, 5 * sc + 6
    return L.piece(w, h, function(R)
      if plate then R(0, 0, w, h, plate); R(1, 1, w - 2, 1, "#3A3A4A") end
      drawText(R, str, 3, 3, sc, col)
    end)
  end

  local function darkCeiling(set, mul, tint)
    local im = set.layer("Ceiling")
    for y = 0, im.height - 1 do for x = 0, im.width - 1 do
      local px = im:getPixel(x, y)
      local a = app.pixelColor.rgbaA(px)
      if a > 0 then
        local r = math.floor(app.pixelColor.rgbaR(px) * mul * tint[1])
        local g = math.floor(app.pixelColor.rgbaG(px) * mul * tint[2])
        local b = math.floor(app.pixelColor.rgbaB(px) * mul * tint[3])
        im:putPixel(x, y, app.pixelColor.rgba(math.min(255, r), math.min(255, g), math.min(255, b), a))
      end
    end end
  end

  -- ================================================================ NERF RACK (cubicle area)
  function P.nerfRack()
    return L.piece(26, 22, function(R)
      R(0, 0, 26, 22, "#5A3A22"); R(1, 1, 24, 20, "#B89862")
      for x = 3, 22, 5 do for y = 3, 18, 5 do R(x, y, 1, 1, "#7A5A32") end end
      -- two blasters hanging on pegs
      R(3, 4, 11, 4, "#17121F"); R(4, 5, 9, 2, "#FF8A1F"); R(10, 5, 3, 2, "#2B79F0"); R(5, 8, 2, 3, "#17121F")
      R(8, 12, 12, 4, "#17121F"); R(9, 13, 10, 2, "#2B79F0"); R(15, 13, 4, 2, "#FF8A1F"); R(10, 16, 2, 3, "#17121F")
      R(17, 4, 6, 6, "#17121F"); R(18, 5, 4, 4, "#FFD23C"); drawText(R, "Z", 19, 5, 1, "#17121F")
    end)
  end

  -- ================================================================ CONFERENCE (bigger: room for the whole company)
  function P.confTableWide(w)
    return L.piece(w, 30, function(R)
      L.box(R, 0, 0, w, 5, "#C9955A", "#E0B47A", "#A57445")
      R(2, 5, w - 4, 3, "#A57445")
      for _, x in ipairs({14, math.floor(w / 2) - 3, w - 20}) do R(x, 8, 6, 22, "#8A5E36") end
      -- things on the table: notepads, mugs, a carafe, a laptop
      for i = 0, 5 do
        local x = 14 + i * math.floor((w - 40) / 5)
        R(x, -2, 7, 2, "#F4F2EA"); R(x + 8, -3, 3, 3, ({"#E04E4E", "#4F7FD0", "#F2C94C"})[i % 3 + 1])
      end
      R(math.floor(w / 2) - 5, -6, 4, 6, "#8AB4D8"); R(math.floor(w / 2) - 6, -7, 6, 1, "#5E86A8")
      L.box(R, math.floor(w / 2) + 12, -5, 12, 5, "#2E3138", "#4A4F5A", "#1C1E24")
    end)
  end

  -- ================================================================ BOWLING ALLEY
  function P.shoeShelf()
    return L.piece(66, 38, function(R)
      R(0, 0, 66, 38, "#3A2E4A")
      local cols = {"#E04E4E", "#4E8FE0", "#F2C94C", "#5FBF6A", "#E07AD0", "#F2F2EA"}
      for row = 0, 2 do for col = 0, 5 do
        local x, y = 2 + col * 10, 2 + row * 12
        R(x, y, 9, 11, "#241B33")
        local c = cols[(row * 3 + col) % #cols + 1]
        R(x + 1, y + 5, 7, 4, c); R(x + 1, y + 8, 7, 2, "#17121F"); R(x + 1, y + 4, 3, 2, c)
      end end
    end)
  end

  function P.shoeCounter()
    return L.piece(76, 32, function(R)
      L.box(R, 0, 0, 76, 5, "#D9B88A", "#EBD0A8", "#B8976B")
      R(0, 5, 76, 27, "#6B2E5A"); R(0, 5, 76, 2, "#E04ECB")
      R(0, 29, 76, 3, "#E04ECB")
      for i = 0, 3 do R(4 + i * 18, 10, 14, 15, "#55234A"); R(5 + i * 18, 11, 12, 13, "#7A3A68") end
      L.box(R, 6, -6, 14, 6, "#8E939E", "#B8BCC4", "#6A6F7A"); R(9, -4, 8, 2, "#7FE0A0")   -- till
      R(46, -4, 10, 4, "#E04E4E"); R(47, -3, 8, 1, "#F2F2EA")                              -- shoe on the counter
    end)
  end

  function P.ballRack()
    return L.piece(54, 28, function(R)
      R(0, 12, 54, 3, "#5A3A22"); R(0, 26, 54, 3, "#5A3A22"); R(0, 0, 3, 29, "#5A3A22"); R(51, 0, 3, 29, "#5A3A22")
      local cols = {"#E07AD0", "#4E8FE0", "#5FBF6A", "#8E5AE0", "#F29A3C", "#2A2A33", "#E04E4E"}
      for row = 0, 1 do for i = 0, 5 do
        local cx, cy = 8 + i * 8, 7 + row * 14
        disc(R, cx, cy, 3, cols[(i + row * 3) % #cols + 1])
        R(cx - 1, cy - 2, 1, 1, "#FFFFFF")
      end end
    end)
  end

  function P.scoreScreen()
    return L.piece(64, 18, function(R)
      L.box(R, 0, 0, 64, 18, "#17171F", "#2A2A33", "#0C0C12")
      R(2, 2, 60, 14, "#0A1A12")
    end)
  end

  function P.benchSeat()
    return L.piece(44, 27, function(R)
      L.box(R, 0, 0, 44, 11, "#C73B4A", "#E0606E", "#962A36")
      L.box(R, 0, 14, 44, 7, "#C73B4A", "#E0606E", "#962A36")
      R(2, 21, 3, 6, "#3A3A4A"); R(39, 21, 3, 6, "#3A3A4A")
      R(0, 11, 44, 3, "#962A36")
    end)
  end

  function P.scoreTable()
    return L.piece(58, 30, function(R)
      L.box(R, 0, 6, 58, 5, "#D9B88A", "#EBD0A8", "#B8976B")
      R(3, 11, 3, 19, "#6A6F7A"); R(52, 11, 3, 19, "#6A6F7A")
      -- a little monitor and score sheets
      L.box(R, 10, -8, 22, 14, "#2E3138", "#4A4F5A", "#1C1E24")
      R(12, -6, 18, 9, "#0F1F18")
      for i = 0, 4 do R(13 + i * 3, -4, 2, 1, "#5FE08A"); R(13 + i * 3, -1, 2, 1, "#5FE08A") end
      R(14, 6, 6, 1, "#4A4F5A")
      R(38, 4, 14, 2, "#F4F2EA"); R(40, 3, 10, 1, "#E04E4E")
    end)
  end

  function P.ballReturn()
    return L.piece(44, 24, function(R)
      L.box(R, 0, 8, 44, 16, "#8E939E", "#B8BCC4", "#6A6F7A")
      R(4, 0, 36, 10, "#C73B4A"); R(8, 1, 28, 2, "#E0606E")
      R(2, 10, 40, 8, "#4A4F5A")
      disc(R, 22, 13, 4, "#4E8FE0"); R(21, 11, 1, 1, "#FFFFFF")
      R(0, 22, 44, 2, "#2A2A33")
    end)
  end

  function P.arcade()
    return L.piece(24, 46, function(R)
      L.box(R, 0, 0, 24, 46, "#3A4EA8", "#5C72D0", "#26357A")
      R(3, 3, 18, 6, "#E04ECB"); drawText(R, "GO", 7, 4, 1, "#FFFFFF")
      R(3, 11, 18, 14, "#101018"); R(5, 13, 14, 10, "#2A7A4A")
      R(7, 16, 3, 3, "#F2F2EA"); R(13, 18, 3, 3, "#F2C94C")
      R(3, 27, 18, 6, "#26357A"); R(6, 28, 2, 2, "#E04E4E"); R(10, 28, 2, 2, "#F2C94C"); R(15, 28, 2, 2, "#5FBF6A")
      R(0, 40, 24, 6, "#1C2656")
    end)
  end

  function P.sodaMachine()
    return L.piece(26, 48, function(R)
      L.box(R, 0, 0, 26, 48, "#C0392B", "#E05A4A", "#8E2A20")
      R(3, 4, 20, 22, "#101018")
      local cols = {"#E04E4E", "#4E8FE0", "#F2C94C", "#5FBF6A"}
      for i = 0, 3 do for j = 0, 2 do R(5 + i * 5, 6 + j * 6, 4, 5, cols[(i + j) % 4 + 1]) end end
      R(4, 30, 18, 3, "#8E2A20"); R(8, 38, 10, 7, "#101018")
    end)
  end

  local function bowlBackground(set)
    local wall, floor, rec = set.layer("Wall"), set.layer("Floor"), set.layer("Lanes")
    F(wall, 0, 0, 320, 84, "#2B2F5E")
    for x = 0, 319, 16 do F(wall, x, 0, 1, 84, "#262A55") end
    F(wall, 0, 84, 320, 6, OUT)
    F(wall, 0, 76, 320, 2, "#E04ECB"); F(wall, 0, 71, 320, 2, "#3EE0E0")        -- neon trim
    -- carpet: loud 90s bowling-alley pattern
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, "#1E2050")
    local cs = {"#E04ECB", "#3EE0E0", "#F2C94C", "#7A5AE0"}
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      local h = hash(x // 6, y // 6, 31)
      if h % 5 == 0 and hash(x, y, 4) % 3 == 0 then L.fill(floor, x, y, 1, 1, cs[h % 4 + 1])
      elseif hash(x, y, 9) % 41 == 0 then L.fill(floor, x, y, 1, 1, "#2B2E6A") end
    end end
    L.fill(floor, 0, y0, floor.width, 2, "#14163C")
    -- the lane recess: two lanes running away to the pin decks
    F(rec, 100, 8, 204, 76, "#101024")
    local lanes = {{near = 152, far = 160, wn = 52, wf = 22}, {near = 252, far = 244, wn = 52, wf = 22}}
    for _, ln in ipairs(lanes) do
      for y = 28, 83 do
        local t = (y - 28) / 55
        local w = ln.wf + (ln.wn - ln.wf) * t
        local cx = ln.far + (ln.near - ln.far) * t
        local x0 = math.floor(cx - w / 2)
        F(rec, x0, y, math.floor(w), 1, "#D9B26B")
        for b = 1, 6 do
          local bx = x0 + math.floor(w * b / 7)
          F(rec, bx, y, 1, 1, "#C79F58")
        end
        F(rec, x0 - 3, y, 3, 1, "#3A3A4A"); F(rec, x0 + math.floor(w), y, 3, 1, "#3A3A4A")          -- gutters
        F(rec, x0 - 1, y, 1, 1, "#22222E"); F(rec, x0 + math.floor(w), y, 1, 1, "#22222E")
        if y % 4 == 0 then F(rec, x0, y, math.floor(w), 1, "#E0BE7C") end
      end
      -- the foul line and the arrows
      local tw = ln.wf + (ln.wn - ln.wf) * ((78 - 28) / 55)
      F(rec, math.floor(ln.near + (ln.far - ln.near) * 0.09 - tw / 2), 78, math.floor(tw), 1, "#17121F")
      for i = -2, 2 do
        local ty = 58 - math.abs(i) * 2
        local t = (ty - 28) / 55
        local w = ln.wf + (ln.wn - ln.wf) * t
        local cx = ln.far + (ln.near - ln.far) * t
        F(rec, math.floor(cx + i * w / 6) - 1, ty, 2, 3, "#6B4A2E")
      end
    end
    F(rec, 198, 28, 8, 56, "#2A2A38"); F(rec, 199, 28, 6, 56, "#3A3A4A")          -- ball-return track between the lanes
    -- the pinsetter masking unit
    F(rec, 100, 4, 204, 22, "#7A1E2A"); F(rec, 100, 4, 204, 3, "#B8333F"); F(rec, 100, 22, 204, 4, "#17121F")
    for x = 106, 296, 24 do
      F(rec, x, 9, 14, 10, "#F2C94C"); F(rec, x + 2, 11, 10, 6, "#7A1E2A")
      F(rec, x + 5, 12, 4, 4, "#F4F2EA")
    end
    F(rec, 98, 4, 2, 80, OUT); F(rec, 304, 4, 2, 80, OUT)
  end

  builders.bowling_alley = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.35, {0.8, 0.85, 1.4}) end, fn = function(s)
    bowlBackground(s)
    -- shoe rental on the left wall
    s.put("ShoeShelf", P.shoeShelf(), 14, 20)
    s.put("Signs", neonText("SHOES", 2, "#F2C94C", "#1A1226"), 22, 6)
    s.put("Signs", neonText("BOWL", 3, "#E04ECB", "#1A1226"), 176, 6)
    s.put("Screen", P.scoreScreen(), 106, 6)
    s.putS("Counter", P.shoeCounter(), 10, 74, 108, "shoe_counter")
    s.putS("Rack", P.ballRack(), 100, 56, 96, "ball_rack")
    s.putS("Return1", P.ballReturn(), 178, 66, 108, "ball_return")
    s.putS("BenchA", P.benchSeat(), 232, 74, 99, "bench_seat")
    s.putS("TableA", P.scoreTable(), 228, 80, 108, "score_table")
    s.putS("Arcade", P.arcade(), 292, 62, 108, "arcade")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 120, 56) end
  end}

  -- ================================================================ KARAOKE BAR
  function P.bottleShelf()
    return L.piece(84, 34, function(R)
      R(0, 0, 84, 34, "#2A1B3D")
      R(0, 15, 84, 2, "#6A4A9A"); R(0, 31, 84, 3, "#6A4A9A")
      local cols = {"#E8A33C", "#5FBF6A", "#E04E4E", "#4E8FE0", "#F2F2EA", "#9A6A3A"}
      for row = 0, 1 do for i = 0, 9 do
        local x, y = 3 + i * 8, 2 + row * 16
        local h = 9 + hash(i, row, 3) % 4
        R(x, y + 14 - h, 5, h, cols[(i + row * 2) % #cols + 1])
        R(x + 1, y + 14 - h - 3, 3, 3, cols[(i + row * 2) % #cols + 1])
        R(x + 1, y + 15 - h, 1, h - 2, "#FFFFFF")
      end end
      R(0, 14, 84, 1, "#E8A33C"); R(0, 30, 84, 1, "#E8A33C")      -- backlight strips
    end)
  end

  function P.barCounter()
    return L.piece(92, 26, function(R)
      L.box(R, 0, 0, 92, 5, "#8A5A32", "#B07A44", "#5A3A22")
      R(0, 5, 92, 21, "#4A2A6B"); R(0, 5, 92, 2, "#E04ECB"); R(0, 23, 92, 3, "#2A1B3D")
      for i = 0, 4 do R(4 + i * 18, 10, 14, 11, "#3A2056"); R(5 + i * 18, 11, 12, 9, "#5A3680") end
      R(8, -3, 4, 3, "#F2F2EA"); R(60, -4, 3, 4, "#E8A33C")        -- a glass and a bottle
    end)
  end

  function P.stool()
    return L.piece(12, 26, function(R)
      L.box(R, 0, 0, 12, 5, "#C73B4A", "#E0606E", "#962A36")
      R(5, 5, 2, 17, "#8E939E"); R(1, 22, 10, 2, "#6A6F7A"); R(2, 13, 8, 1, "#6A6F7A")
    end)
  end

  function P.roundTable()
    return L.piece(42, 30, function(R)
      L.box(R, 0, 0, 42, 6, "#5A3A22", "#8A5A32", "#3E281A")
      R(2, 6, 38, 2, "#3E281A")
      R(19, 8, 4, 18, "#2A1B3D"); R(10, 26, 22, 4, "#2A1B3D")
      R(5, -3, 5, 3, "#F4F2EA"); R(14, -2, 3, 2, "#E04E4E")           -- a drink and a song book
      R(26, -4, 10, 4, "#E04ECB"); R(27, -3, 8, 1, "#FFD0F4")
    end)
  end

  function P.speaker()
    return L.piece(18, 44, function(R)
      L.box(R, 0, 0, 18, 44, "#2A2A33", "#4A4A56", "#1C1C24")
      disc(R, 9, 12, 5, "#101018"); disc(R, 9, 12, 2, "#4A4A56")
      disc(R, 9, 30, 6, "#101018"); disc(R, 9, 30, 3, "#4A4A56"); R(8, 29, 1, 1, "#8A8A96")
      R(2, 40, 14, 2, "#E04ECB")
    end)
  end

  function P.micStand()
    return L.piece(10, 40, function(R)
      R(4, 8, 2, 28, "#8E939E"); R(0, 36, 10, 3, "#4A4F5A"); R(2, 35, 6, 1, "#6A6F7A")
      R(2, 0, 6, 8, "#2A2A33"); R(3, 1, 4, 3, "#8E939E"); R(3, 6, 4, 1, "#E04ECB")
    end)
  end

  function P.discoBall()
    return L.piece(22, 34, function(R)
      R(10, 0, 2, 12, "#8E939E")
      disc(R, 11, 22, 10, "#B8BCC4")
      for y = 12, 32 do for x = 1, 21 do
        local dx, dy = x - 11, y - 22
        if dx * dx + dy * dy <= 100 and (x + y) % 4 < 2 then R(x, y, 1, 1, "#E4E8F0") end
        if dx * dx + dy * dy <= 100 and (x * 3 + y) % 7 == 0 then R(x, y, 1, 1, "#7A8AA8") end
      end end
      R(7, 16, 3, 3, "#FFFFFF")
    end)
  end

  function P.songBinder()
    return L.piece(12, 8, function(R) R(0, 0, 12, 8, "#E04ECB"); R(1, 1, 10, 2, "#FFD0F4"); R(0, 7, 12, 1, "#962A9A") end)
  end

  local function karaokeBackground(set)
    local wall, floor, st = set.layer("Wall"), set.layer("Floor"), set.layer("Stage")
    F(wall, 0, 0, 320, 84, "#3B2457")
    for x = 0, 319, 8 do F(wall, x, 0, 4, 84, "#432A62") end
    F(wall, 0, 84, 320, 6, OUT)
    F(wall, 0, 70, 320, 2, "#3EE0E0"); F(wall, 0, 74, 320, 1, "#E04ECB")
    -- floor: dark carpet with a few glitter dots
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, "#241538")
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      local h = hash(x, y, 77)
      if h % 37 == 0 then L.fill(floor, x, y, 1, 1, "#3A2456")
      elseif h % 211 == 0 then L.fill(floor, x, y, 1, 1, "#E04ECB") end
    end end
    L.fill(floor, 0, y0, floor.width, 2, "#160D26")
    -- the stage alcove on the right
    F(st, 188, 16, 126, 68, "#14102A")
    for i = 0, 40 do F(st, 192 + hash(i, 1, 5) % 118, 20 + hash(i, 2, 5) % 44, 1, 1, (i % 3 == 0) and "#F2F2EA" or "#7A8AE0") end
    F(st, 188, 70, 126, 14, "#5A3A22")                                   -- the stage boards
    for x = 188, 312, 10 do F(st, x, 70, 1, 14, "#4A2E1A") end
    F(st, 188, 70, 126, 2, "#8A5A32")
    for x = 192, 308, 8 do F(st, x, 83, 2, 2, "#F2C94C") end              -- footlights
    -- curtains
    for side = 0, 1 do
      local x0 = side == 0 and 188 or 300
      for y = 16, 70 do
        for x = 0, 13 do
          local fold = ((x + y // 6) % 4 < 2) and "#A31F36" or "#7A1228"
          F(st, x0 + x, y, 1, 1, fold)
        end
      end
    end
    F(st, 188, 12, 126, 5, "#7A1228"); F(st, 188, 16, 126, 1, "#E8A33C")
    -- the big lyrics screen (the fx draws on it)
    F(st, 206, 26, 92, 38, "#0C0C14"); F(st, 208, 28, 88, 34, "#161A44")
    F(st, 206, 26, 92, 2, "#4A4A56"); F(st, 206, 62, 92, 2, "#4A4A56")
    F(st, 206, 26, 2, 38, "#4A4A56"); F(st, 296, 26, 2, 38, "#4A4A56")
  end

  builders.karaoke_bar = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.3, {1.1, 0.8, 1.4}) end, fn = function(s)
    s.layer("Ceiling")        -- created first so the disco ball (a later layer) hangs in front of it
    karaokeBackground(s)
    s.put("Disco", P.discoBall(), 134, -26)
    s.put("Signs", neonText("KARAOKE", 2, "#3EE0E0", "#1A1226"), 12, 4)
    s.put("Shelf", P.bottleShelf(), 12, 28)
    s.putS("Bar", P.barCounter(), 8, 70, 108, "bar_counter")
    for _, x in ipairs({22, 44, 66}) do s.putS("Stools", P.stool(), x, 78, 99, "bar_stool") end
    -- two tables with seats behind them (like the conference room)
    for _, tx in ipairs({112, 164}) do
      s.putS("Chairs" .. tx, P.chair("#6A3A8A", "#8A5AAA", "#4A2A66"), tx + 3, 58, 88, "chair_karaoke")
      s.putS("Table" .. tx, P.roundTable(), tx, 78, 108, "round_table")
    end
    s.putS("SpeakerL", P.speaker(), 178, 66, 108, "speaker")
    s.putS("SpeakerR", P.speaker(), 298, 66, 108, "speaker")
    s.putS("Mic", P.micStand(), 246, 84, 112, "mic_stand")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 130, 56) end
  end}

  -- ================================================================ ESCAPE ROOM
  function P.vaultDoor()
    return L.piece(50, 66, function(R)
      L.box(R, 0, 0, 50, 66, "#6A6F7A", "#8E939E", "#4A4F5A")
      R(4, 4, 42, 58, "#4A4F5A"); R(6, 6, 38, 54, "#7A7F8A")
      disc(R, 25, 32, 14, "#5A5F6A"); disc(R, 25, 32, 11, "#8E939E"); disc(R, 25, 32, 3, "#3A3F4A")
      for i = 0, 7 do
        local a = i * math.pi / 4
        R(25 + math.floor(math.cos(a) * 8) - 1, 32 + math.floor(math.sin(a) * 8) - 1, 2, 2, "#3A3F4A")
      end
      for _, y in ipairs({10, 52}) do R(8, y, 4, 4, "#3A3F4A"); R(38, y, 4, 4, "#3A3F4A") end
      R(0, 60, 50, 6, "#3A3F4A")
    end)
  end

  function P.keypad()
    return L.piece(22, 30, function(R)
      L.box(R, 0, 0, 22, 30, "#2E3138", "#4A4F5A", "#1C1E24")
      R(2, 2, 18, 8, "#0A140E")
      for i = 0, 2 do R(4 + i * 5, 4, 3, 5, "#123A22") end
      for r = 0, 3 do for c = 0, 2 do R(3 + c * 6, 13 + r * 4, 5, 3, "#8E939E") end end
      R(18, 12, 2, 2, "#E04E4E")
    end)
  end

  function P.ledTimer()
    return L.piece(46, 18, function(R)
      L.box(R, 0, 0, 46, 18, "#17171F", "#2A2A33", "#0C0C12")
      R(2, 2, 42, 14, "#1A0508")
      R(18, 7, 2, 2, "#C0392B"); R(18, 11, 2, 2, "#C0392B")
    end)
  end

  function P.grandfatherClock()
    return L.piece(18, 52, function(R)
      L.box(R, 0, 0, 18, 52, "#6B4A2E", "#8A6240", "#4A3220")
      R(2, 2, 14, 14, "#F2E6C8"); disc(R, 9, 9, 5, "#F2E6C8")
      R(9, 5, 1, 5, "#17121F"); R(9, 9, 4, 1, "#17121F")
      R(3, 19, 12, 24, "#3A2616"); R(8, 21, 2, 18, "#C99A3C"); disc(R, 9, 36, 3, "#E8C45A")
      R(0, 48, 18, 4, "#4A3220")
    end)
  end

  function P.safeBox()
    return L.piece(26, 26, function(R)
      L.box(R, 0, 0, 26, 26, "#3E4350", "#5A6070", "#2A2E38")
      R(3, 3, 20, 20, "#4A5060"); disc(R, 13, 13, 6, "#2A2E38"); disc(R, 13, 13, 4, "#8E939E")
      R(13, 9, 1, 4, "#17121F"); R(21, 11, 2, 6, "#C99A3C")
      R(2, 23, 4, 3, "#17121F"); R(20, 23, 4, 3, "#17121F")
    end)
  end

  function P.trunk()
    return L.piece(30, 18, function(R)
      L.box(R, 0, 4, 30, 14, "#6B4A2E", "#8A6240", "#4A3220")
      R(0, 0, 30, 6, "#5A3A22"); R(0, 0, 30, 2, "#8A6240")
      R(0, 4, 30, 2, "#C99A3C"); R(13, 6, 4, 5, "#E8C45A"); R(14, 8, 2, 2, "#17121F")
      R(2, 4, 2, 14, "#C99A3C"); R(26, 4, 2, 14, "#C99A3C")
    end)
  end

  function P.deskLamp()
    return L.piece(12, 16, function(R)
      R(2, 14, 8, 2, "#2A2A33"); R(5, 6, 2, 8, "#6A6F7A"); R(2, 0, 8, 6, "#2E7A4A"); R(3, 1, 3, 2, "#5FBF8A")
    end)
  end

  function P.chalkboard()
    return L.piece(50, 30, function(R)
      R(0, 0, 50, 30, "#6B4A2E"); R(2, 2, 46, 26, "#1E3A2E")
      R(6, 22, 14, 1, "#2E4A3E"); R(30, 24, 10, 1, "#2E4A3E"); R(10, 6, 2, 1, "#2E4A3E")
      R(2, 27, 46, 1, "#4A3220"); R(8, 26, 6, 1, "#F2F2EA")
    end)
  end

  function P.bigClock()
    return L.piece(18, 18, function(R)
      L.box(R, 0, 0, 18, 18, "#C99A3C", "#E8C45A", "#8E6A22")
      R(2, 2, 14, 14, "#F4F2EA")
      for _, p in ipairs({{8, 2}, {8, 14}, {2, 8}, {14, 8}}) do R(p[1], p[2], 2, 2, "#17121F") end
    end)
  end

  function P.redLight()
    return L.piece(12, 10, function(R)
      R(0, 6, 12, 4, "#3A3F4A"); R(2, 1, 8, 6, "#C0392B"); R(3, 2, 3, 2, "#FF8A7A")
    end)
  end

  function P.globe()
    return L.piece(16, 26, function(R)
      R(7, 14, 2, 8, "#6B4A2E"); R(2, 22, 12, 3, "#6B4A2E")
      disc(R, 8, 8, 7, "#3E7AA8"); R(4, 4, 4, 3, "#5FBF6A"); R(9, 9, 4, 4, "#5FBF6A"); R(5, 10, 2, 2, "#E8C45A")
    end)
  end

  function P.paintingDark()
    return L.piece(26, 32, function(R)
      R(0, 0, 26, 32, "#C99A3C"); R(2, 2, 22, 28, "#2A3A2E")
      disc(R, 13, 12, 6, "#B8A68A"); R(7, 18, 12, 12, "#4A2A2E")
      R(10, 11, 2, 2, "#17121F"); R(15, 11, 2, 2, "#17121F")      -- watching eyes
    end)
  end

  local function escapeBackground(set)
    local wall, floor = set.layer("Wall"), set.layer("Floor")
    F(wall, 0, 0, 320, 84, "#27453B")
    for x = 0, 319, 14 do F(wall, x, 0, 1, 52, "#22402F") end
    F(wall, 0, 50, 320, 3, "#C99A3C")                                        -- picture rail
    F(wall, 0, 53, 320, 31, "#6B4A2E")                                       -- wainscot
    for x = 0, 319, 26 do F(wall, x + 2, 56, 22, 24, "#5A3A22"); F(wall, x + 3, 57, 20, 22, "#7A5636") end
    F(wall, 0, 84, 320, 6, OUT)
    -- dark hardwood boards
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, "#4A3322")
    for y = y0 + 6, floor.height - 1, 10 do L.fill(floor, 0, y, floor.width, 1, "#3A281A") end
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      local h = hash(x, y, 55)
      if h % 53 == 0 then L.fill(floor, x, y, 1, 1, "#5A4130") end
      if ((y - y0) // 10 + x // 40) % 2 == 0 and x % 40 == 0 then L.fill(floor, x, y, 1, 1, "#3A281A") end
    end end
    L.fill(floor, 0, y0, floor.width, 2, "#2A1C12")
    -- an old rug
    for y = 0, 22 do
      local half = math.floor(70 * math.sqrt(math.max(0, 1 - ((y - 11) / 12) ^ 2)))
      L.fill(floor, 160 - half, y0 + 12 + y, half * 2, 1, (y % 6 < 3) and "#7A2A2E" or "#8E3A3A")
    end
    F(set.layer("Floor"), 96, 102, 128, 1, "#C99A3C")
  end

  builders.escape_room = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.3, {0.8, 1.2, 0.9}) end, fn = function(s)
    escapeBackground(s)
    s.put("Frames", P.paintingDark(), 112, 10)
    s.put("Frames", P.chalkboard(), 192, 14)
    s.put("Timer", P.ledTimer(), 140, 4)
    s.put("Frames", P.bigClock(), 54, 20)
    s.putS("Bookshelf", P.bookshelf(), 14, 26, 108, "bookshelf")
    s.putS("Clock", P.grandfatherClock(), 80, 56, 108, "grandfather_clock")
    s.putS("Desk", P.desk(74), 118, 83, 108, "desk_cubicle_74")
    s.putS("DeskProps", P.deskLamp(), 124, 68, 108.2, "desk_lamp")
    s.putS("Globe", P.globe(), 186, 78, 108, "globe")
    s.putS("Safe", P.safeBox(), 214, 82, 108, "safe_box")
    s.putS("Trunk", P.trunk(), 40, 90, 112, "trunk")
    s.putS("Vault", P.vaultDoor(), 262, 20, 108, "vault_door")
    s.put("Keypad", P.keypad(), 244, 40)
    s.put("Lights", P.redLight(), 226, 4)
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
  end}

  -- ================================================================ RESTAURANT (a 2014 neighbourhood grill)
  function P.boothBack()
    return L.piece(46, 38, function(R)
      R(0, 0, 46, 38, "#8E1F26")
      R(0, 0, 46, 4, "#4A2E1C"); R(0, 0, 46, 1, "#6B4228")
      R(0, 32, 46, 6, "#7A1A20"); R(0, 32, 46, 1, "#B3303A")
      for x = 0, 45, 11 do R(x, 4, 1, 28, "#6E161C") end
      for y = 10, 28, 9 do for x = 5, 40, 11 do R(x, y, 2, 2, "#4A0F14"); R(x, y, 1, 1, "#B3303A") end end
    end)
  end

  function P.woodTable()
    return L.piece(52, 28, function(R)
      L.box(R, 0, 0, 52, 6, "#8A5A32", "#B07A44", "#5A3A22")
      R(2, 6, 48, 2, "#5A3A22")
      R(24, 8, 4, 16, "#3A281A"); R(12, 24, 28, 4, "#3A281A")
      R(4, -4, 3, 4, "#C0392B"); R(5, -6, 1, 2, "#F2F2EA")
      R(10, -3, 4, 3, "#F2F2EA"); R(11, -3, 2, 1, "#8E939E")
      R(19, -3, 2, 3, "#F2F2EA"); R(22, -3, 2, 3, "#F2F2EA")
      R(30, -7, 7, 7, "#B3262C"); R(31, -6, 5, 3, "#F2C94C"); R(32, -2, 3, 1, "#F2F2EA")
      R(40, -2, 5, 2, "#E8E8E0"); R(41, -3, 3, 1, "#C99A3C")
    end)
  end

  function P.pendant()
    return L.piece(16, 40, function(R)
      R(7, 0, 2, 26, "#2A2A33")
      R(2, 26, 12, 3, "#E05A4A"); R(0, 29, 16, 6, "#C0392B"); R(0, 29, 16, 1, "#E8806A")
      R(1, 35, 14, 2, "#FFE08A"); R(3, 37, 10, 1, "#FFF0B8")
    end)
  end

  function P.liquorShelf()
    return L.piece(112, 38, function(R)
      R(0, 0, 112, 38, "#3A281A")
      R(2, 2, 108, 34, "#5C6E78"); R(2, 2, 108, 2, "#7A8E9A")
      for x = 6, 100, 22 do R(x, 6, 2, 26, "#7A8E9A") end
      R(0, 14, 112, 2, "#6B4228"); R(0, 26, 112, 2, "#6B4228"); R(0, 35, 112, 3, "#6B4228")
      local cols = {"#E8A33C", "#5FBF6A", "#E04E4E", "#4E8FE0", "#F2F2EA", "#9A6A3A", "#8E5AE0"}
      for row = 0, 1 do for i = 0, 11 do
        local x, y = 4 + i * 9, 3 + row * 12
        local h = 8 + hash(i, row, 8) % 3
        R(x, y + 11 - h, 4, h, cols[(i * 3 + row) % #cols + 1]); R(x + 1, y + 11 - h - 3, 2, 3, cols[(i * 3 + row) % #cols + 1])
        R(x + 1, y + 12 - h, 1, h - 2, "#FFFFFF")
      end end
      R(2, 33, 108, 2, "#E8A33C")
    end)
  end

  function P.sportsTv()
    return L.piece(46, 28, function(R)
      L.box(R, 0, 0, 46, 28, "#17171F", "#2A2A33", "#0C0C12")
      R(2, 2, 42, 22, "#1F5A2A")
      R(2, 24, 42, 2, "#2A2A33"); R(20, 25, 6, 1, "#4A4A56")
    end)
  end

  function P.restBar()
    return L.piece(130, 30, function(R)
      L.box(R, 0, 0, 130, 6, "#6B4228", "#8A5A32", "#4A2E1C")
      R(0, 6, 130, 2, "#C99A3C")
      R(0, 8, 130, 20, "#2E4A36"); R(0, 8, 130, 1, "#1E3426")
      for i = 0, 5 do R(3 + i * 21, 11, 17, 14, "#3A5A44"); R(4 + i * 21, 12, 15, 12, "#456A50") end
      R(0, 26, 130, 2, "#C99A3C"); R(0, 28, 130, 2, "#2A1B14")
      local taps = {"#E04E4E", "#F2C94C", "#4E8FE0", "#5FBF6A"}
      for i = 0, 3 do R(14 + i * 14, -8, 3, 8, "#8E939E"); R(13 + i * 14, -11, 5, 4, taps[i + 1]) end
    end)
  end

  function P.stoolRest()
    return L.piece(12, 26, function(R)
      L.box(R, 0, 0, 12, 5, "#7A1A20", "#B3303A", "#4A0F14")
      R(5, 5, 2, 17, "#2A2A33"); R(1, 22, 10, 2, "#2A2A33"); R(2, 13, 8, 1, "#C99A3C")
    end)
  end

  function P.hostStand()
    return L.piece(26, 38, function(R)
      L.box(R, 2, 8, 22, 30, "#5A3A22", "#8A5A32", "#3A281A")
      R(0, 4, 26, 6, "#6B4228"); R(0, 4, 26, 1, "#8A5A32")
      R(4, 0, 8, 5, "#F4F2EA"); R(14, 1, 7, 4, "#B3262C")
      R(5, 16, 16, 14, "#4A2E1C"); drawText(R, "HI", 8, 20, 2, "#C99A3C")
    end)
  end

  function P.specialsBoard()
    return L.piece(52, 34, function(R)
      R(0, 0, 52, 34, "#6B4228"); R(2, 2, 48, 30, "#1E2B22")
      drawText(R, "2 FOR", 7, 5, 2, "#F4F2EA")
      drawText(R, "$20", 12, 18, 2, "#E8806A")
      R(5, 15, 42, 1, "#F4F2EA"); R(5, 29, 42, 1, "#F4F2EA")
    end)
  end

  function P.jersey(body, trim)
    return L.piece(22, 28, function(R)
      R(0, 0, 22, 28, "#6B4228"); R(2, 2, 18, 24, "#2A1B14")
      R(5, 4, 12, 20, body); R(2, 5, 4, 7, body); R(16, 5, 4, 7, body)
      R(8, 4, 6, 3, "#2A1B14"); R(5, 4, 12, 1, trim); R(8, 12, 6, 6, trim)
      R(9, 13, 4, 4, body)
    end)
  end

  function P.tinSign()
    return L.piece(24, 16, function(R)
      R(0, 0, 24, 16, "#F2F2EA"); R(1, 1, 22, 14, "#B3262C")
      drawText(R, "COLD", 4, 2, 1, "#F2F2EA"); drawText(R, "BEER", 4, 9, 1, "#F2C94C")
    end)
  end

  local function restaurantBackground(set)
    local wall, floor = set.layer("Wall"), set.layer("Floor")
    F(wall, 0, 0, 320, 84, "#C9A66B")
    for x = 0, 319, 10 do F(wall, x, 0, 2, 50, "#BF9C60") end
    F(wall, 0, 46, 320, 3, "#2E6B3A"); F(wall, 0, 49, 320, 2, "#B3262C"); F(wall, 0, 51, 320, 2, "#E0C890")
    F(wall, 0, 53, 320, 31, "#4A2E1C")
    for x = 0, 319, 28 do F(wall, x + 2, 56, 24, 24, "#3A2214"); F(wall, x + 3, 57, 22, 22, "#5C3A24") end
    F(wall, 0, 84, 320, 6, OUT)
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, "#5B3A24")
    for y = y0 + 6, floor.height - 1, 12 do L.fill(floor, 0, y, floor.width, 1, "#4A2E1C") end
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      local h = hash(x, y, 91)
      local plank = ((y - y0) // 12 + (x // 60)) % 2
      if h % 47 == 0 then L.fill(floor, x, y, 1, 1, "#6B4630") end
      if x % 60 == 0 and plank == 0 then L.fill(floor, x, y, 1, 1, "#4A2E1C") end
    end end
    L.fill(floor, 0, y0, floor.width, 2, "#33200F")
  end

  builders.restaurant = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.55, {1.25, 0.95, 0.7}) end, fn = function(s)
    s.layer("Ceiling")
    restaurantBackground(s)
    s.put("Memorabilia", P.jersey("#B3262C", "#F2F2EA"), 22, 18)
    s.put("Memorabilia", P.jersey("#2E5AA8", "#F2C94C"), 100, 18)
    s.put("Memorabilia", P.tinSign(), 50, 24)
    s.put("Memorabilia", P.frame(14, 18, "#E8B070", "#7A4A8A"), 74, 22)
    s.put("Memorabilia", P.frame(14, 18), 130, 30)
    s.put("Memorabilia", P.tinSign(), 124, 6)
    s.put("Memorabilia", P.specialsBoard(), 150, 26)
    s.put("Signs", neonText("BAR", 3, "#E04E4E", "#1A1226"), 162, 2)
    s.put("Shelf", P.liquorShelf(), 200, 28)
    s.put("TVs", P.sportsTv(), 206, 0); s.put("TVs", P.sportsTv(), 262, 0)
    for _, bx in ipairs({12, 84}) do
      s.putS("BoothBack" .. bx, P.boothBack(), bx, 50, 88, "booth_back")
      s.putS("Table" .. bx, P.woodTable(), bx - 2, 78, 108, "wood_table")
      s.put("Pendants", P.pendant(), bx + 16, -24)
    end
    s.putS("Host", P.hostStand(), 154, 76, 108, "host_stand")
    s.putS("Plant", P.floorPlant(), 134, 80, 108, "plant_floor")
    s.putS("Bar", P.restBar(), 190, 76, 108, "rest_bar")
    for _, sx in ipairs({206, 234, 262, 290}) do s.putS("Stools", P.stoolRest(), sx, 78, 99, "stool_rest") end
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 120, 56) end
  end}
end
