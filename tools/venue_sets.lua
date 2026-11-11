-- RODENT NATION 2014 venue: a (fictional) Florida resort conference centre.
-- Loaded by build_sets.lua:  dofile(TOOLS .. "venue_sets.lua")(L, builders)
-- Sets: resort_lobby (atrium, check-in, ballroom doors), resort_hall (the breakout corridor), ballroom (keynote stage),
--       breakout_a to breakout_d (four different session rooms: SALON A to D), vendor_hall (the solutions pavilion). 320 px wide (the breakout rooms 240).
return function(L, builders)
  local P = L.P
  local OUT = "#17121F"

  local function F(im, x, y, w, h, col) L.fill(im, x + L.XOFF, y + L.YOFF, w, h, col) end
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

  -- 3x5 pixel font (as in the game UI)
  local G = {
    A = {"XXX","X.X","XXX","X.X","X.X"}, B = {"XX.","X.X","XX.","X.X","XX."}, C = {".XX","X..","X..","X..",".XX"},
    D = {"XX.","X.X","X.X","X.X","XX."}, E = {"XXX","X..","XX.","X..","XXX"}, F = {"XXX","X..","XX.","X..","X.."},
    G = {".XX","X..","X.X","X.X",".XX"}, H = {"X.X","X.X","XXX","X.X","X.X"}, I = {"XXX",".X.",".X.",".X.","XXX"},
    J = {"..X","..X","..X","X.X",".X."}, K = {"X.X","X.X","XX.","X.X","X.X"}, L = {"X..","X..","X..","X..","XXX"},
    M = {"X.X","XXX","XXX","X.X","X.X"}, N = {"XXX","X.X","X.X","X.X","X.X"}, O = {".X.","X.X","X.X","X.X",".X."},
    P = {"XX.","X.X","XX.","X..","X.."}, Q = {".X.","X.X","X.X","XX.",".XX"}, R = {"XX.","X.X","XX.","X.X","X.X"},
    S = {".XX","X..",".X.","..X","XX."}, T = {"XXX",".X.",".X.",".X.",".X."}, U = {"X.X","X.X","X.X","X.X","XXX"},
    V = {"X.X","X.X","X.X","X.X",".X."}, W = {"X.X","X.X","XXX","XXX","X.X"}, X = {"X.X","X.X",".X.","X.X","X.X"},
    Y = {"X.X","X.X",".X.",".X.",".X."}, Z = {"XXX","..X",".X.","X..","XXX"},
    ["0"] = {"XXX","X.X","X.X","X.X","XXX"}, ["1"] = {".X.","XX.",".X.",".X.","XXX"}, ["2"] = {"XX.","..X",".X.","X..","XXX"},
    ["3"] = {"XX.","..X",".X.","..X","XX."}, ["4"] = {"X.X","X.X","XXX","..X","..X"}, ["5"] = {"XXX","X..","XX.","..X","XX."},
    ["6"] = {".XX","X..","XXX","X.X","XXX"}, ["7"] = {"XXX","..X",".X.",".X.",".X."}, ["8"] = {"XXX","X.X","XXX","X.X","XXX"},
    ["9"] = {"XXX","X.X","XXX","..X","XX."}, ["-"] = {"...","...","XXX","...","..."}, ["."] = {"...","...","...","...",".X."},
    [":"] = {"...",".X.","...",".X.","..."}, ["!"] = {".X.",".X.",".X.","...",".X."}, [" "] = {"...","...","...","...","..."},
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
  local function centred(R, str, cx, y, sc, col) drawText(R, str, cx - math.floor(textW(str, sc) / 2), y, sc, col) end

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

  -- ---------------------------------------------------------------- backgrounds
  -- warm cream wall with a wainscot, crown moulding and a baseboard
  local function resortWall(set, W, base, trim, accent)
    local wall = set.layer("Wall")
    F(wall, 0, 0, W, 84, base)
    for x = 0, W - 1, 24 do F(wall, x, 0, 1, 52, trim) end                      -- soft vertical panel lines
    F(wall, 0, 0, W, 3, accent); F(wall, 0, 3, W, 1, "#F6EFD9")                   -- crown moulding
    F(wall, 0, 50, W, 2, "#F6EFD9"); F(wall, 0, 52, W, 32, trim)                  -- chair rail + wainscot
    for x = 0, W - 1, 20 do F(wall, x + 2, 56, 16, 22, base); F(wall, x + 2, 56, 16, 1, "#F6EFD9") end
    F(wall, 0, 84, W, 6, OUT)
  end

  -- swirl convention-centre carpet: deep teal with a gold/coral lozenge pattern
  local function resortCarpet(set, base, dark, gold, coral)
    local floor = set.layer("Floor")
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, base)
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      local gx, gy = x % 16, (y - y0) % 16
      local d = math.abs(gx - 8) + math.abs(gy - 8)
      if d == 5 then L.fill(floor, x, y, 1, 1, gold)
      elseif d == 2 then L.fill(floor, x, y, 1, 1, coral)
      elseif (gx + gy) % 8 == 0 and d > 9 then L.fill(floor, x, y, 1, 1, dark)
      elseif hash(x, y, 7) % 53 == 0 then L.fill(floor, x, y, 1, 1, dark) end
    end end
    L.fill(floor, 0, y0, floor.width, 2, "#0F2E3A")
  end

  -- ---------------------------------------------------------------- pieces
  function P.palm()
    return L.piece(34, 76, function(R)
      R(11, 64, 12, 12, "#B5603A"); R(10, 63, 14, 3, "#D07A4A"); R(11, 74, 12, 2, "#8A4426"); R(13, 66, 1, 8, "#D07A4A")
      R(12, 62, 10, 3, "#3A2A1C")                                           -- soil
      for i = 0, 9 do                                                       -- a slightly bent trunk
        local x = 16 + math.floor(math.sin(i * 0.5) * 2)
        R(x, 62 - i * 5, 4, 5, i % 2 == 0 and "#8A6A44" or "#6E5234")
      end
      local cx, cy = 18, 14
      local fronds = {{-15, 4}, {-12, -4}, {-6, -8}, {0, -9}, {6, -8}, {12, -4}, {15, 4}, {-8, 9}, {8, 9}}
      for _, f in ipairs(fronds) do
        local steps = 14
        for t = 0, steps do
          local u = t / steps
          local x = cx + math.floor(f[1] * u * 1.05)
          local y = cy + math.floor(f[2] * u + 14 * u * u)
          R(x, y, 2, 1, (t % 3 == 0) and "#2E7A3A" or "#3E9A4A")
          if t > 2 and t < steps - 1 then R(x, y + 1, 1, 1, "#2E7A3A") end
        end
      end
      R(cx - 2, cy - 2, 5, 5, "#2E7A3A"); R(cx - 1, cy + 1, 3, 3, "#8A6A44")   -- crown + coconuts
    end)
  end

  function P.banner()
    return L.piece(30, 64, function(R)
      R(0, 0, 30, 58, "#0F3E50"); R(1, 1, 28, 56, "#14566E"); R(1, 1, 28, 2, "#F2C94C"); R(1, 55, 28, 2, "#F2C94C")
      disc(R, 15, 17, 7, "#8E939E"); disc(R, 8, 10, 3, "#8E939E"); disc(R, 22, 10, 3, "#8E939E")     -- a rat head
      disc(R, 8, 10, 1, "#E8A0A8"); disc(R, 22, 10, 1, "#E8A0A8")
      R(11, 15, 2, 2, OUT); R(17, 15, 2, 2, OUT); R(14, 20, 3, 2, "#E8A0A8")
      centred(R, "RODENT", 15, 30, 1, "#FFFFFF"); centred(R, "NATION", 15, 37, 1, "#FFFFFF")
      centred(R, "2014", 15, 46, 1, "#F2C94C")
      R(2, 58, 26, 3, "#3A3F4A"); R(6, 61, 18, 2, "#2A2D36")
    end)
  end

  function P.regDesk()
    return L.piece(100, 34, function(R)
      L.box(R, 0, 0, 100, 5, "#F2EFE6", "#FFFFFF", "#C9C3B2")
      R(0, 5, 100, 29, "#14566E"); R(0, 5, 100, 2, "#F2C94C"); R(0, 31, 100, 3, "#0F3E50")
      R(6, 11, 88, 16, "#0F3E50")
      centred(R, "RODENT NATION CHECK-IN", 50, 16, 1, "#F2C94C")
      for i = 0, 3 do R(6 + i * 22, -4, 18, 4, "#E8E4D4"); for j = 0, 5 do R(8 + i * 22 + j * 3, -7, 2, 3, ({"#E04E4E", "#4F7FD0", "#F2C94C"})[(i + j) % 3 + 1]) end end
      L.box(R, 82, -6, 11, 6, "#2E3138", "#4A4F5A", "#1C1E24")                   -- a laptop
      R(70, -6, 8, 6, "#F2F2EA"); R(71, -5, 6, 2, "#E04E4E")                      -- a bowl of mints
    end)
  end

  function P.easel(label)
    return L.piece(40, 46, function(R)
      R(3, 42, 3, 4, "#6A4A2E"); R(34, 42, 3, 4, "#6A4A2E"); R(19, 32, 2, 14, "#6A4A2E")
      R(0, 0, 40, 34, "#6A4A2E"); R(1, 1, 38, 32, "#F4F2EA")
      R(1, 1, 38, 6, "#14566E")
      centred(R, label or "NOW", 20, 2, 1, "#FFFFFF")
    end)
  end

  function P.bigWindow(w, h)
    return L.piece(w, h, function(R)
      R(0, 0, w, h, "#E8E4D4")
      R(3, 3, w - 6, h - 6, "#7EC8F0")
      for y = 3, h - 4 do local t = (y - 3) / (h - 6); R(3, y, w - 6, 1, t < 0.5 and "#7EC8F0" or "#B9E4F8") end
      disc(R, w - 16, 14, 6, "#FFF3B0")                                                -- the Florida sun
      -- palm silhouettes and a sliver of pool outside
      for _, px in ipairs({w // 5, w // 2 + 6, w - 22}) do
        R(px, h - 28, 2, 24, "#5A4630")
        for _, f in ipairs({{-8, -2}, {-5, -6}, {0, -7}, {5, -6}, {8, -2}}) do
          for t = 0, 6 do R(px + math.floor(f[1] * t / 6), h - 30 + math.floor(f[2] * t / 6 + t * t / 18), 2, 1, "#2E7A3A") end
        end
      end
      R(3, h - 10, w - 6, 7, "#3EC8D8"); R(3, h - 10, w - 6, 1, "#9AE8F0")             -- pool
      for x = 6, w - 8, 12 do R(x, h - 7, 6, 1, "#9AE8F0") end
      R(3, h - 4, w - 6, 1, "#D8C898")
      for x = 3 + (w - 6) // 3, w - 6, (w - 6) // 3 do R(x, 3, 2, h - 6, "#E8E4D4") end   -- mullions
      R(3, h // 2, w - 6, 2, "#E8E4D4")
    end)
  end

  function P.sconce()
    return L.piece(8, 12, function(R)
      R(2, 0, 4, 2, "#B8943A"); R(1, 2, 6, 7, "#FFF0B8"); R(2, 3, 4, 5, "#FFFADC"); R(2, 9, 4, 2, "#B8943A")
    end)
  end

  function P.ballroomDoors()
    return L.piece(46, 56, function(R)
      R(0, 0, 46, 56, "#E8E4D4"); R(2, 8, 42, 48, "#5A3A22")
      R(3, 9, 19, 47, "#7A5030"); R(24, 9, 19, 47, "#7A5030")
      for _, x in ipairs({6, 27}) do R(x, 13, 13, 18, "#5A3A22"); R(x + 1, 14, 11, 16, "#8A6038"); R(x, 35, 13, 17, "#5A3A22"); R(x + 1, 36, 11, 15, "#8A6038") end
      R(20, 30, 2, 5, "#F2C94C"); R(24, 30, 2, 5, "#F2C94C")
      R(6, 1, 34, 6, "#14566E"); centred(R, "BALLROOM", 23, 2, 1, "#F2C94C")
    end)
  end

  function P.hallDoor(letter)
    return L.piece(26, 52, function(R)
      R(0, 6, 26, 46, "#E8E4D4"); R(2, 8, 22, 44, "#6A4A2E")
      R(3, 9, 20, 43, "#8A6038"); R(5, 12, 16, 16, "#6A4A2E"); R(6, 13, 14, 14, "#9A7048")
      R(5, 32, 16, 17, "#6A4A2E"); R(6, 33, 14, 15, "#9A7048")
      R(20, 30, 2, 3, "#F2C94C")
      R(1, 0, 24, 6, "#14566E"); centred(R, letter, 13, 1, 1, "#FFFFFF")
    end)
  end

  function P.hallWindow()
    return L.piece(46, 44, function(R)
      R(0, 0, 46, 44, "#E8E4D4"); R(3, 3, 40, 38, "#7EC8F0")
      for y = 3, 40 do R(3, y, 40, 1, (y < 22) and "#7EC8F0" or "#B9E4F8") end
      R(3, 30, 40, 8, "#3EC8D8"); R(3, 38, 40, 3, "#D8C898")
      R(22, 3, 2, 38, "#E8E4D4"); R(3, 20, 40, 2, "#E8E4D4")
    end)
  end

  function P.stage(w)
    return L.piece(w, 20, function(R)
      R(0, 0, w, 6, "#4A3A2E"); R(0, 0, w, 2, "#6A5642")
      R(0, 6, w, 14, "#14161C")
      for x = 4, w - 6, 8 do R(x, 7, 1, 12, "#22252E") end                   -- pleated skirt
      R(w // 2 - 16, 8, 32, 6, "#14566E"); centred(R, "RODENT NATION", w // 2, 9, 1, "#F2C94C")
    end)
  end

  function P.bigScreen(w, h)
    return L.piece(w, h, function(R)
      R(0, 0, w, h, "#17121F"); R(2, 2, w - 4, h - 4, "#1E5A8A")
      for y = 2, h - 3 do R(2, y, w - 4, 1, (y - 2) * 2 < h - 4 and "#2A7AB8" or "#1E5A8A") end
      centred(R, "AUTOMATE", w // 2, h // 2 - 10, 2, "#FFFFFF")
      centred(R, "EVERYTHING", w // 2, h // 2 + 2, 2, "#F2C94C")
      centred(R, "RODENT NATION 2014", w // 2, h - 11, 1, "#BFE4F8")
      disc(R, 11, 11, 4, "#8E939E"); disc(R, 7, 6, 2, "#8E939E"); disc(R, 15, 6, 2, "#8E939E")
    end)
  end

  function P.podium()
    return L.piece(18, 32, function(R)
      L.box(R, 0, 0, 18, 6, "#5A3A22", "#7A5030", "#3E281A")
      R(2, 6, 14, 24, "#6A4A2E"); R(3, 7, 12, 22, "#7A5030")
      disc(R, 9, 17, 4, "#8E939E"); R(6, 12, 2, 2, "#8E939E"); R(11, 12, 2, 2, "#8E939E")
      R(8, -8, 2, 8, "#2A2A33"); R(6, -9, 6, 2, "#2A2A33")                       -- microphone
    end)
  end

  function P.chandelier()
    return L.piece(46, 34, function(R)
      R(22, 0, 2, 10, "#B8943A")
      R(6, 10, 34, 3, "#B8943A"); R(2, 13, 42, 2, "#D8B84A")
      for x = 4, 40, 6 do R(x, 15, 2, 8, "#FFF0B8"); R(x, 23, 2, 3, "#F2C94C"); R(x - 1, 8, 4, 2, "#FFFADC") end
      R(14, 26, 18, 2, "#B8943A"); R(20, 28, 6, 5, "#FFF0B8")
    end)
  end

  function P.avDesk()
    return L.piece(54, 32, function(R)
      L.box(R, 0, 0, 54, 4, "#2A2D36", "#454A56", "#1C1E24")
      R(2, 4, 50, 28, "#14566E"); R(2, 4, 50, 2, "#F2C94C"); R(2, 29, 50, 3, "#0F3E50")
      R(6, -8, 18, 8, "#2E3138"); R(7, -7, 16, 5, "#6A7A8A")
      for i = 0, 9 do R(30 + i * 2, -3, 1, 3, ({"#4CFF7A", "#F2C94C", "#E04E4E"})[i % 3 + 1]) end
    end)
  end

  function P.rowBacks(w)                       -- a row of gold ballroom chairs seen from behind
    return L.piece(w, 18, function(R)
      for x = 0, w - 10, 11 do
        R(x, 0, 9, 11, "#8A6A24"); R(x + 1, 1, 7, 9, "#D8B84A"); R(x + 2, 2, 5, 3, "#F2D878")
        R(x + 1, 11, 2, 7, "#8A6A24"); R(x + 6, 11, 2, 7, "#8A6A24")
      end
    end)
  end

  function P.boothVendor(c1, c2, label)
    return L.piece(62, 78, function(R)
      R(0, 0, 62, 58, "#2A2D36")                                                     -- pipe and drape back wall
      R(1, 1, 60, 56, c2)
      for x = 6, 56, 10 do R(x, 1, 1, 56, c1) end                                    -- drape folds
      R(0, 0, 62, 2, "#8E939E")
      R(4, 8, 54, 20, c1); R(5, 9, 52, 18, "#FFFFFF")
      centred(R, label, 31, 15, 1, c2)
      R(0, 56, 62, 22, "#F2F2EA"); R(0, 56, 62, 3, "#C9C3B2")                         -- skirted table
      R(0, 59, 62, 19, c1)
      for x = 4, 58, 6 do R(x, 60, 1, 17, c2) end
      for i = 0, 3 do R(6 + i * 13, 51, 10, 5, ({"#E04E4E", "#F2C94C", "#4F7FD0", "#5FBF6A"})[i + 1]) end   -- swag piles
      R(48, 40, 10, 11, "#F2F2EA"); R(49, 41, 8, 2, c1)                               -- a brochure stand
    end)
  end

  function P.mascot()
    return L.piece(30, 58, function(R)
      R(8, 18, 14, 22, "#8E939E"); R(9, 19, 12, 20, "#B8BCC4")                       -- body
      disc(R, 15, 11, 9, "#8E939E"); disc(R, 15, 11, 7, "#B8BCC4")
      disc(R, 6, 4, 4, "#8E939E"); disc(R, 24, 4, 4, "#8E939E"); disc(R, 6, 4, 2, "#E8A0A8"); disc(R, 24, 4, 2, "#E8A0A8")
      R(10, 9, 3, 3, OUT); R(17, 9, 3, 3, OUT); R(13, 15, 4, 3, "#E8A0A8"); R(12, 17, 6, 1, "#FFFFFF")
      R(8, 40, 6, 14, "#8E939E"); R(16, 40, 6, 14, "#8E939E"); R(6, 52, 9, 5, "#E04E4E"); R(15, 52, 9, 5, "#E04E4E")
      R(2, 20, 6, 4, "#B8BCC4"); R(22, 20, 6, 4, "#B8BCC4")
      R(7, 26, 16, 8, "#14566E"); centred(R, "LAB", 15, 27, 1, "#FFFFFF")
      R(24, 26, 2, 10, "#6A4A2E"); R(23, 22, 6, 5, "#F2C94C")                         -- a foam finger
    end)
  end

  function P.waterTable()
    return L.piece(34, 30, function(R)
      R(0, 6, 34, 24, "#F2EFE6"); R(0, 6, 34, 2, "#C9C3B2")
      R(0, 8, 34, 22, "#14566E")
      R(4, -4, 8, 10, "#8AB4D8"); R(5, -6, 6, 2, "#5E86A8")                          -- a pitcher
      for i = 0, 4 do R(16 + i * 3, 0, 2, 6, "#F2F2EA") end
    end)
  end

  function P.sandwichBoard()                    -- a lobby sign: "BREAKOUTS >"
    return L.piece(26, 38, function(R)
      R(2, 34, 3, 4, "#6A4A2E"); R(21, 34, 3, 4, "#6A4A2E")
      R(0, 0, 26, 34, "#2A2D36"); R(2, 2, 22, 30, "#14566E")
      centred(R, "INFO", 13, 5, 1, "#FFFFFF")
      for i = 0, 2 do R(5, 13 + i * 6, 16, 2, "#F2C94C") end
      R(17, 28, 5, 1, "#FFFFFF")
    end)
  end

  -- ---------------------------------------------------------------- the sets
  builders.resort_lobby = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.95, {1.12, 1.08, 0.95}) end, fn = function(s)
    s.layer("Ceiling")
    resortWall(s, 320, "#EFE4C8", "#E0D2AE", "#B8943A")
    resortCarpet(s, "#1F4E5F", "#163A48", "#C8A83C", "#D8704A")
    s.put("Window", P.bigWindow(96, 58), 108, 18)
    s.put("Window", P.bigWindow(96, 58), 212, 18)
    s.put("Doors", P.ballroomDoors(), 14, 16)
    s.put("Banner", P.banner(), 72, 18)
    s.put("Doors", P.hallDoor("HALL"), 288, 18)
    s.put("Sconce", P.sconce(), 66, 34); s.put("Sconce", P.sconce(), 98, 34)
    s.put("Chandelier", P.chandelier(), 66, -22); s.put("Chandelier", P.chandelier(), 206, -22)
    s.putS("PalmA", P.palm(), 96, 14, 108, "palm")
    s.putS("PalmB", P.palm(), 200, 14, 108, "palm")
    s.put("Doors", P.hallDoor("EXPO"), 250, 18)
    s.putS("Reg", P.regDesk(), 112, 76, 108, "reg_desk")
    -- two lounge seats, side-on like the sitters (seat x - 13), both facing right
    s.putS("CouchA", P.couchSide(), 28, 69, 99, "couch_side")
    s.putS("CouchB", P.couchSide(), 54, 69, 99, "couch_side")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
  end}

  builders.resort_hall = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.95, {1.12, 1.08, 0.95}) end, fn = function(s)
    s.layer("Ceiling")
    resortWall(s, 320, "#E9DFC6", "#D8CBA6", "#14566E")
    resortCarpet(s, "#4A2A3E", "#34202E", "#C8A83C", "#2E8A8E")
    s.put("Doors", P.hallDoor("LOBBY"), 4, 18)
    for i, x in ipairs({36, 106, 176, 246}) do
      s.put("Doors", P.hallDoor(({"A", "B", "C", "D"})[i]), x, 18)
      s.put("Wall", P.easel("NOW"), x + 28, 48)
      s.put("Sconce", P.sconce(), x - 9, 36)
    end
    s.put("Chandelier", P.chandelier(), 90, -22); s.put("Chandelier", P.chandelier(), 230, -22)
    s.putS("Plant", P.floorPlant(), 8, 80, 108, "plant_floor")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
  end}

  builders.ballroom = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.6, {1.1, 1.0, 0.9}) end, fn = function(s)
    s.layer("Ceiling")
    resortWall(s, 320, "#D8D0E4", "#C4BAD6", "#B8943A")
    resortCarpet(s, "#5A2038", "#40162A", "#C8A83C", "#2E8A8E")
    s.put("Curtain", P.stage(200), 60, 62)
    s.put("Screen", P.bigScreen(110, 54), 105, 8)
    s.put("Sconce", P.sconce(), 24, 30); s.put("Sconce", P.sconce(), 288, 30)
    s.put("Banner", P.banner(), 28, 14); s.put("Banner", P.banner(), 262, 14)
    s.putS("Podium", P.podium(), 232, 40, 100, "podium")
    s.put("Chandelier", P.chandelier(), 60, -26); s.put("Chandelier", P.chandelier(), 140, -26); s.put("Chandelier", P.chandelier(), 220, -26)
    s.putS("RowA", P.rowBacks(244), 40, 70, 90, "row_backs")
    s.putS("AV", P.avDesk(), 250, 74, 108, "av_desk")
    for _, x in ipairs({63, 103, 143, 183}) do   -- seat x - 14
      s.putS("Seats", P.chairSide("#B8943A", "#D8B84A", "#8A6A24"), x, 60, 94, "chair_gold_side")
    end
    s.put("Doors", P.hallDoor("EXIT"), 292, 18)
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
  end}

  -- ---------------------------------------------------------------- the four breakout rooms (SALON A to D)
  -- Each hall door A to D has its own room, with its own wall, floor, light, furniture and speaker spot; the screen (or
  -- whiteboard) is blank art and the fx `session_screen` (fx.gd) writes the real session on it. People stand on y 118, so a
  -- prop sorted at 119 hides the speaker from the hips down (the lectern) and one sorted at 100 stands behind (tables, stools).
  local function roomPlate(s, text, x, col, txt)
    s.put("Plate", L.piece(#text * 4 + 5, 9, function(R)
      R(0, 0, #text * 4 + 5, 9, col); R(1, 1, #text * 4 + 3, 1, "#FFFFFF")
      drawText(R, text, 3, 2, 1, txt)
    end), x, 24)
  end

  local function woodFloor(set, base, dark, light)
    local floor = set.layer("Floor")
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, base)
    for row = 0, (floor.height - y0) // 7 do
      local y = y0 + row * 7
      L.fill(floor, 0, y, floor.width, 1, dark)
      local off = (row * 37) % 52
      for x = -off, floor.width, 52 do if x >= 0 then L.fill(floor, x, y, 1, 7, dark) end end
    end
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      local h = hash(x, y, 11)
      if h % 29 == 0 then L.fill(floor, x, y, 3, 1, light) elseif h % 37 == 0 then L.fill(floor, x, y, 2, 1, dark) end
    end end
    L.fill(floor, 0, y0, floor.width, 2, "#2A1B10")
  end

  local function tileCarpet(set, base, dark, light)
    local floor = set.layer("Floor")
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, base)
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      local h = hash(x, y, 19)
      if h % 9 == 0 then L.fill(floor, x, y, 1, 1, light) elseif h % 13 == 0 then L.fill(floor, x, y, 1, 1, dark) end
    end end
    for x = 0, floor.width - 1, 20 do L.fill(floor, x, y0, 1, floor.height - y0, dark) end
    for y = y0 + 8, floor.height - 1, 20 do L.fill(floor, 0, y, floor.width, 1, dark) end
    L.fill(floor, 0, y0, floor.width, 2, "#3A4048")
  end

  -- a plain wall: base colour, an optional stripe pattern, a rail and a wainscot, crown and baseboard
  local function roomWall(set, W, o)
    local wall = set.layer("Wall")
    F(wall, 0, 0, W, 84, o.base)
    if o.stripe then for x = 0, W - 1, 12 do F(wall, x, 4, 6, 46, o.stripe) end end
    F(wall, 0, 0, W, 3, o.crown); F(wall, 0, 3, W, 1, o.crownHi or "#F6EFD9")
    F(wall, 0, 50, W, 2, o.railHi); F(wall, 0, 52, W, 32, o.wains)
    if o.planks then for x = 0, W - 1, 8 do F(wall, x, 52, 1, 32, o.planks) end; F(wall, 0, 52, W, 1, o.planks) end
    if o.panels then
      for x = 0, W - 1, 24 do F(wall, x + 3, 56, 18, 22, o.panels); F(wall, x + 3, 56, 18, 1, o.railHi) end
    end
    F(wall, 0, 84, W, 6, OUT)
  end

  function P.roomScreen(kind, w, h)
    return L.piece(w, h, function(R)
      if kind == "a" then                                              -- a wall projection screen in a dark bezel
        R(0, 0, w, h, "#17121F"); R(2, 2, w - 4, h - 4, "#1E5A8A")
        for y = 2, h - 3 do R(2, y, w - 4, 1, (y - 2) * 2 < h - 4 and "#2A7AB8" or "#1E5A8A") end
        disc(R, w - 7, 7, 3, "#8E939E"); disc(R, w - 10, 4, 1, "#8E939E"); disc(R, w - 4, 4, 1, "#8E939E")
      elseif kind == "b" then                                          -- a white pull-down screen on a black valance
        R(0, 0, w, 5, "#2A2D36"); R(0, 5, w, 1, "#4A4F5A")
        R(1, 6, w - 2, h - 8, "#F4F2EA"); R(1, 6, 2, h - 8, "#E0DCCB"); R(w - 3, 6, 2, h - 8, "#D6D1BE")
        R(0, h - 3, w, 3, "#2A2D36"); R(w // 2 - 1, h - 1, 3, 1, "#B8943A")
      elseif kind == "c" then                                          -- a big gold-framed display
        R(0, 0, w, h, "#B8943A"); R(1, 1, w - 2, 1, "#F2D878"); R(2, 2, w - 4, h - 4, "#0E1118")
        for i = 0, 6 do R(4 + i * 3, 4 + i * 2, 6, 1, "#1A2030") end
      else                                                             -- a whiteboard with a marker tray
        R(0, 0, w, h - 3, "#B8BCC4"); R(2, 2, w - 4, h - 7, "#F4F2EA")
        R(4, 4, 10, 1, "#D8D4C4"); R(6, h - 9, 14, 1, "#D8D4C4")      -- old ghost marks
        R(0, h - 4, w, 4, "#8E939E")
        R(6, h - 6, 5, 2, "#E04040"); R(13, h - 6, 5, 2, "#3A6FD0"); R(20, h - 6, 5, 2, "#2A2A33")
      end
    end)
  end

  function P.lectern()
    return L.piece(22, 38, function(R)
      R(10, 0, 1, 7, "#2A2A33"); R(10, 0, 5, 1, "#2A2A33"); R(14, 0, 2, 3, "#2A2A33"); R(14, 1, 1, 1, "#8E939E")   -- gooseneck mic
      R(0, 8, 22, 5, "#7A5030"); R(0, 8, 22, 1, "#B08050"); R(0, 12, 22, 1, "#3E281A")
      R(3, 13, 16, 21, "#6A4A2E"); R(4, 14, 14, 19, "#8A6038"); R(4, 14, 14, 1, "#9A7048")
      R(8, 18, 6, 7, "#14566E"); R(9, 19, 4, 5, "#F2C94C"); R(10, 21, 2, 2, "#14566E")                           -- the plate
      R(2, 34, 18, 4, "#3E281A")
    end)
  end

  function P.flipChart()
    return L.piece(30, 52, function(R)
      R(3, 40, 2, 12, "#6A6F7A"); R(25, 40, 2, 12, "#6A6F7A"); R(14, 34, 2, 18, "#6A6F7A"); R(1, 50, 6, 2, "#4A4F5A"); R(23, 50, 6, 2, "#4A4F5A")
      R(0, 0, 30, 37, "#8E939E"); R(1, 1, 28, 35, "#F4F2EA"); R(1, 1, 28, 2, "#E04040")
      R(9, 0, 12, 2, "#4A4F5A")
      R(4, 7, 4, 1, "#3A6FD0"); R(10, 7, 14, 1, "#3A6FD0"); R(4, 12, 4, 1, "#3A6FD0"); R(10, 12, 11, 1, "#3A6FD0")
      R(4, 17, 4, 1, "#3A6FD0"); R(10, 17, 16, 1, "#3A6FD0"); R(7, 24, 16, 8, "#E8E4D4"); R(9, 26, 12, 1, "#E04040"); R(9, 29, 8, 1, "#3A6FD0")
    end)
  end

  function P.presenterTable(w, cloth, trim)
    return L.piece(w, 36, function(R)
      R(5, 2, 13, 8, "#2E3138"); R(6, 3, 11, 5, "#6A7A8A"); R(3, 9, 17, 1, "#2E3138")                        -- a laptop
      R(26, 5, 16, 5, "#E4E4E0"); R(28, 3, 8, 2, "#C9C9C0"); R(40, 6, 3, 3, "#17121F")                        -- a projector
      R(w - 18, 3, 4, 7, "#8AB4D8"); R(w - 12, 6, 3, 4, "#F4F2EA"); R(w - 8, 6, 3, 4, "#F4F2EA")               -- a bottle and cups
      L.box(R, 0, 10, w, 4, "#F2EFE6", "#FFFFFF", "#C9C3B2")
      R(1, 14, w - 2, 22, cloth); R(1, 14, w - 2, 2, trim); R(1, 33, w - 2, 3, "#17121F")
      for x = 5, w - 6, 6 do R(x, 17, 1, 15, trim) end
    end)
  end

  function P.coffeeStation()
    return L.piece(40, 42, function(R)
      R(5, 1, 12, 3, "#8E939E"); R(4, 4, 14, 14, "#B8BCC4"); R(5, 5, 3, 12, "#E8ECF0"); R(16, 6, 1, 11, "#8E939E")  -- the urn
      R(17, 11, 4, 2, "#2A2D36"); R(19, 13, 2, 2, "#2A2D36")                                                       -- spigot
      for i = 0, 2 do R(26, 10 - i * 3, 5, 3, "#F4F2EA"); R(26, 10 - i * 3, 5, 1, "#D8D4C4") end                    -- cups
      R(33, 10, 5, 8, "#E8E4D4"); R(34, 11, 3, 3, "#E08A3A")                                                       -- sugar and a tray
      L.box(R, 0, 18, 40, 4, "#F2EFE6", "#FFFFFF", "#C9C3B2")
      R(1, 22, 38, 20, "#2E6A5A"); R(1, 22, 38, 2, "#F2C94C"); R(1, 39, 38, 3, "#17121F")
      R(7, 27, 26, 8, "#1E4A3E"); centred(R, "COFFEE", 20, 29, 1, "#F2C94C")
    end)
  end

  function P.barStool(seat)
    return L.piece(14, 32, function(R)
      R(0, 0, 14, 5, seat); R(0, 0, 14, 1, "#FFFFFF"); R(1, 5, 12, 1, "#17121F")
      R(6, 6, 2, 18, "#8E939E"); R(2, 16, 10, 1, "#6A6F7A")
      R(1, 24, 2, 8, "#6A6F7A"); R(11, 24, 2, 8, "#6A6F7A"); R(5, 28, 4, 4, "#4A4F5A")
    end)
  end

  function P.sideTable()
    return L.piece(18, 34, function(R)
      R(6, 1, 5, 8, "#8AB4D8"); R(7, 0, 3, 1, "#5E86A8"); R(2, 5, 3, 4, "#F4F2EA"); R(13, 6, 3, 3, "#F4F2EA")
      L.box(R, 0, 9, 18, 3, "#3A3F4A", "#5A606C", "#22262E")
      R(8, 12, 2, 18, "#8E939E"); R(3, 30, 12, 3, "#4A4F5A")
    end)
  end

  function P.labTable()
    return L.piece(66, 30, function(R)
      for _, x in ipairs({5, 38}) do
        R(x, 0, 18, 11, "#B8BCC4"); R(x + 1, 1, 16, 9, "#9AA0AE"); R(x + 8, 4, 3, 3, "#E8E4D4"); R(x - 2, 10, 22, 2, "#4A4F5A")
      end
      R(28, 5, 5, 6, "#F4F2EA"); R(29, 6, 3, 1, "#E04040")
      L.box(R, 0, 11, 66, 4, "#D8D4C4", "#F6F2E2", "#A8A494")
      R(3, 15, 3, 15, "#6A6F7A"); R(60, 15, 3, 15, "#6A6F7A"); R(6, 16, 54, 9, "#8E939E"); R(6, 16, 54, 1, "#B8BCC4")
      R(20, 26, 8, 1, "#2A2D36"); R(44, 25, 6, 1, "#2A2D36")                                                       -- cables
    end)
  end

  function P.velvetDrape(w, h)
    return L.piece(w, h, function(R)
      R(0, 0, w, 7, "#B8943A"); R(0, 0, w, 1, "#F2D878"); R(0, 7, w, 3, "#6A1624")
      for x = 0, w - 1 do R(x, 10, 1, h - 10, (x // 3) % 2 == 0 and "#8A2434" or "#6A1624") end
      R(0, h - 3, w, 3, "#4A0E18")
      R(0, 38, w, 3, "#B8943A")                                                                                  -- the tieback
    end)
  end

  function P.wifiSign()
    return L.piece(34, 17, function(R)
      R(0, 0, 34, 17, "#F4F2EA"); R(0, 0, 34, 4, "#2E7A8E"); centred(R, "WIFI", 17, 6, 1, "#17121F")
      centred(R, "RATNET14", 17, 11, 1, "#2E7A8E")
    end)
  end

  -- -------- SALON A: the classic lecture room (cream and teal, lit warm). Lectern on the right, the speaker behind it.
  builders.breakout_a = {W = 240, H = 128, post = function(set) darkCeiling(set, 0.85, {1.1, 1.05, 0.95}) end, fn = function(s)
    s.layer("Ceiling")
    resortWall(s, 240, "#E4DCC8", "#D2C8AC", "#14566E")
    resortCarpet(s, "#1F4E5F", "#163A48", "#C8A83C", "#D8704A")
    roomPlate(s, "SALON A", 34, "#14566E", "#FFFFFF")
    s.put("Doors", P.hallDoor("EXIT"), 4, 18)
    s.put("Screen", P.roomScreen("a", 94, 46), 134, 8)
    s.put("Banner", P.banner(), 92, 14)
    s.put("Sconce", P.sconce(), 66, 34); s.put("Sconce", P.sconce(), 228, 34)
    s.put("Chandelier", P.chandelier(), 40, -26); s.put("Chandelier", P.chandelier(), 150, -26)
    for _, x in ipairs({85, 115, 140}) do
      s.putS("BackRow", P.chairSide("#4A4D55", "#6A6E78", "#35373E"), x, 55, 94, "chair_conference_side")
    end
    for _, x in ipairs({65, 95, 125}) do
      s.putS("Seats", P.chairSide("#4A4D55", "#6A6E78", "#35373E"), x, 64, 98, "chair_conference_side")
    end
    s.putS("Water", P.waterTable(), 36, 78, 108, "water_table")
    s.putS("Flip", P.flipChart(), 160, 50, 101, "flip_chart")
    s.putS("Plant", P.floorPlant(), 222, 74, 101, "plant_floor")
    s.putS("Lectern", P.lectern(), 192, 81, 119, "lectern")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 90, 56) end
  end}

  -- -------- SALON B: the sunroom workshop (sage green walls, wooden floor, a window, a coffee station, a low presenter table).
  builders.breakout_b = {W = 240, H = 128, post = function(set) darkCeiling(set, 1.1, {1.15, 1.1, 0.9}) end, fn = function(s)
    s.layer("Ceiling")
    roomWall(s, 240, {base = "#CFDDBE", stripe = "#C6D6B4", crown = "#5E7A4E", railHi = "#E8D8A8", wains = "#8A5E3A", planks = "#6E4A2C"})
    woodFloor(s, "#9A6A3E", "#7A5230", "#B58452")
    roomPlate(s, "SALON B", 34, "#5E7A4E", "#FFFFFF")
    s.put("Doors", P.hallDoor("EXIT"), 4, 18)
    s.put("Window", P.bigWindow(50, 50), 82, 14)
    s.put("Screen", P.roomScreen("b", 100, 56), 136, 6)
    s.put("Clock", P.clock(), 70, 20)
    for _, x in ipairs({80, 108, 136}) do
      s.putS("BackRow", P.chairSide("#8A5E3A", "#B08050", "#6A4426"), x, 55, 94, "chair_wood_side")
    end
    for _, x in ipairs({57, 85, 113}) do
      s.putS("Seats", P.chairSide("#8A5E3A", "#B08050", "#6A4426"), x, 64, 98, "chair_wood_side")
    end
    s.putS("Coffee", P.coffeeStation(), 22, 62, 100, "coffee_station")
    s.putS("Table", P.presenterTable(60, "#2E6A5A", "#F2C94C"), 148, 65, 100, "presenter_table")
    s.putS("Plant", P.floorPlant(), 222, 74, 101, "plant_floor")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 90, 56) end
  end}

  -- -------- SALON C: the panel room (navy and gold, dim, spotlights on a rug with bar stools and a side table).
  builders.breakout_c = {W = 240, H = 128, post = function(set) darkCeiling(set, 0.45, {0.95, 1.0, 1.25}) end, fn = function(s)
    s.layer("Ceiling")
    roomWall(s, 240, {base = "#2E3A5C", stripe = "#33416A", crown = "#C8A83C", crownHi = "#F2D878", railHi = "#C8A83C", wains = "#1E2640", panels = "#252E4E"})
    resortCarpet(s, "#2A2F4E", "#1E2238", "#C8A83C", "#8A3040")
    -- the rug the panel sits on, and two light beams from the ceiling
    local floor = s.layer("Floor")
    F(floor, 134, 98, 100, 26, "#6A1624"); F(floor, 135, 99, 98, 24, "#8A2434"); F(floor, 138, 102, 92, 18, "#6A1624")
    for x = 140, 226, 6 do F(floor, x, 105, 2, 12, "#C8A83C") end
    local wall = s.layer("Wall")
    for _, bx in ipairs({152, 196}) do
      for y = 4, 83 do
        local half = 4 + (y - 4) * 12 // 80
        F(wall, bx - half, y, half * 2, 1, ((y + bx) % 2 == 0) and "#3A4870" or "#364368")
      end
    end
    roomPlate(s, "SALON C", 34, "#C8A83C", "#1E2640")
    s.put("Doors", P.hallDoor("EXIT"), 4, 18)
    s.put("Drape", P.velvetDrape(18, 78), 76, 6); s.put("Drape", P.velvetDrape(18, 78), 100, 6)
    s.put("Screen", P.roomScreen("c", 96, 44), 128, 10)
    s.put("Sconce", P.sconce(), 70, 30)
    s.put("Chandelier", P.chandelier(), 30, -26)
    for _, x in ipairs({45, 77, 109}) do
      s.putS("BackRow", P.chairSide("#8A2434", "#B03A4C", "#5E1622"), x + 21, 55, 94, "chair_velvet_side")
      s.putS("Seats", P.chairSide("#8A2434", "#B03A4C", "#5E1622"), x, 64, 98, "chair_velvet_side")
    end
    s.putS("StoolA", P.barStool("#3A3F4A"), 146, 70, 100, "stool_panel")
    s.putS("StoolB", P.barStool("#3A3F4A"), 166, 70, 100, "stool_panel")
    s.putS("Side", P.sideTable(), 214, 70, 100, "side_table")
    s.putS("Plant", P.floorPlant(), 224, 70, 99, "plant_floor")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 90, 56) end
  end}

  -- -------- SALON D: the training lab (cool grey walls, grey carpet tile, bright light, lab tables, a whiteboard, nothing in front of the speaker).
  builders.breakout_d = {W = 240, H = 128, post = function(set) darkCeiling(set, 1.12, {0.95, 1.05, 1.18}) end, fn = function(s)
    s.layer("Ceiling")
    roomWall(s, 240, {base = "#DDE4EA", crown = "#2E7A8E", crownHi = "#BFE4F8", railHi = "#FFFFFF", wains = "#BFC9D2", panels = "#CCD5DC"})
    tileCarpet(s, "#6E7680", "#5A626C", "#808892")
    roomPlate(s, "SALON D", 34, "#2E7A8E", "#FFFFFF")
    s.put("Doors", P.hallDoor("EXIT"), 4, 18)
    s.put("Screen", P.roomScreen("d", 104, 46), 128, 12)
    s.put("Wifi", P.wifiSign(), 72, 26)
    s.put("Clock", P.clock(), 112, 18)
    s.putS("Lab1", P.labTable(), 44, 58, 92, "lab_table")
    s.putS("Lab2", P.labTable(), 114, 58, 92, "lab_table")
    for _, x in ipairs({91, 121, 151}) do
      s.putS("BackRow", P.chairSide("#2E5A8E", "#4A7AB0", "#1E3E66"), x, 55, 94, "chair_blue_side")
    end
    for _, x in ipairs({71, 101, 131}) do
      s.putS("Seats", P.chairSide("#2E5A8E", "#4A7AB0", "#1E3E66"), x, 64, 98, "chair_blue_side")
    end
    s.putS("Plant", P.floorPlant(), 6, 74, 101, "plant_floor")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 90, 56) end
  end}

  builders.vendor_hall = {W = 320, H = 128, post = function(set) darkCeiling(set, 0.7, {1.05, 1.05, 1.1}) end, fn = function(s)
    s.layer("Ceiling")
    local wall = s.layer("Wall")
    F(wall, 0, 0, 320, 84, "#C9CDD6")
    for x = 0, 319, 16 do F(wall, x, 0, 1, 84, "#B7BCC8") end
    F(wall, 0, 0, 320, 4, "#2A2D36"); F(wall, 0, 78, 320, 6, "#9AA0AE"); F(wall, 0, 84, 320, 6, OUT)
    local floor = s.layer("Floor")
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, "#4A4F5A")
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      if hash(x, y, 3) % 41 == 0 then L.fill(floor, x, y, 1, 1, "#3A3F4A") end
    end end
    for x = 0, floor.width - 1, 64 do L.fill(floor, x, y0, 1, floor.height - y0, "#5A606C") end
    L.fill(floor, 0, y0, floor.width, 2, "#2A2D36")
    -- a taped aisle down the middle
    L.fill(floor, 0, y0 + 26, floor.width, 1, "#F2C94C")
    s.put("Banner", P.banner(), 4, 8)
    s.putS("BoothSwag", P.boothVendor("#7A4AB0", "#5A3488", "WEBWOOT"), 40, 36, 104, "booth_webwoot")
    s.putS("BoothBackup", P.boothVendor("#5FBF6A", "#2A6A34", "SHADOWPOINT"), 128, 36, 104, "booth_shadowpoint")
    s.putS("BoothForum", P.boothVendor("#4F7FD0", "#1E3A7A", "LABRAT NERDS"), 216, 36, 104, "booth_nerds")
    s.putS("Mascot", P.mascot(), 100, 62, 108, "mascot")
    s.put("Doors", P.hallDoor("EXIT"), 290, 18)
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
  end}
end
