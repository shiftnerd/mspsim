-- RODENT NATION 2014 venue: a (fictional) Florida resort conference centre.
-- Loaded by build_sets.lua:  dofile(TOOLS .. "venue_sets.lua")(L, builders)
-- Sets: resort_lobby (atrium, check-in, ballroom doors), resort_hall (the breakout corridor), ballroom (keynote stage),
--       breakout_room (a session room), vendor_hall (the solutions pavilion). 320 px wide (breakout 240).
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

  function P.speakerTable()
    return L.piece(70, 30, function(R)
      L.box(R, 0, 0, 70, 5, "#F2EFE6", "#FFFFFF", "#C9C3B2")
      R(0, 5, 70, 25, "#14566E"); R(0, 5, 70, 2, "#F2C94C")
      R(8, -8, 12, 8, "#2E3138"); R(9, -7, 10, 5, "#6A7A8A")
      R(30, -6, 4, 6, "#8AB4D8"); R(29, -7, 6, 1, "#5E86A8")
      R(44, -3, 7, 3, "#F2F2EA"); R(54, -3, 6, 3, "#F2F2EA")
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
    s.putS("Couch", P.couch(), 38, 69, 99, "couch")
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
    for _, x in ipairs({68, 108, 148, 188}) do
      s.putS("Seats", P.chair("#B8943A", "#D8B84A", "#8A6A24"), x, 58 + 18, 94, "chair_gold")
    end
    s.put("Doors", P.hallDoor("EXIT"), 292, 18)
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
  end}

  builders.breakout_room = {W = 240, H = 128, post = function(set) darkCeiling(set, 0.8, {1.1, 1.05, 0.95}) end, fn = function(s)
    s.layer("Ceiling")
    resortWall(s, 240, "#E4DCC8", "#D2C8AC", "#14566E")
    resortCarpet(s, "#1F4E5F", "#163A48", "#C8A83C", "#D8704A")
    s.put("Screen", P.bigScreen(84, 44), 120, 10)
    s.put("Banner", P.banner(), 52, 14)
    s.put("Doors", P.hallDoor("EXIT"), 4, 18)
    s.put("Chandelier", P.chandelier(), 40, -26); s.put("Chandelier", P.chandelier(), 150, -26)
    s.putS("Speaker", P.speakerTable(), 124, 66, 100, "speaker_table")
    s.putS("Water", P.waterTable(), 202, 78, 108, "water_table")
    s.putS("RowA", P.rowBacks(150), 50, 74, 94, "row_backs_small")
    for _, x in ipairs({70, 110, 150}) do
      s.putS("Seats", P.chair("#4A4D55", "#6A6E78", "#35373E"), x, 58 + 22, 98, "chair_conference")
    end
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
