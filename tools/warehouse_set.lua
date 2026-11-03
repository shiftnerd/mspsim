-- The WAREHOUSE (phase 1 of the side-scrolling chair race): the MSP's staging and e-waste storage room, 2013-14,
-- generic and unbranded. One long room, 1480 px wide (4.6 screens at the h format), built on the usual 320 px tall canvas.
-- Loaded by build_sets.lua: dofile(TOOLS .. "warehouse_set.lua")(L, builders). Builder coordinates are the old 0..128 room
-- band (floor line y 118, the wall base at y 90); the canvas adds the ceiling band on top (post hook = roof and trusses).
-- Zones along x: entry door + time clock + chair rack (the race starts at x 200), break corner (vending), racking aisle with the
-- parts cage, the back storage room, the bench (a PC being imaged), the dart panel, the e-waste corner, the dock (overhead door,
-- grill) and the old Christmas tree in the far corner. The walkway (y 110..128) is clear along the whole length.
return function(L, builders)
  local P = L.P
  local OUT = "#17121F"
  local W = 1480
  local CC = {}
  local function col(h) local c = CC[h]; if not c then c = L.C(h); CC[h] = c end; return c end
  local function F(im, x, y, w, h, c) L.fill(im, x + L.XOFF, y + L.YOFF, w, h, c) end
  local function px(im, x, y, c)
    x = x + L.XOFF; y = y + L.YOFF
    if x >= 0 and y >= 0 and x < im.width and y < im.height then im:putPixel(x, y, col(c)) end
  end
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

  -- 3x5 pixel font (the game UI font) plus the few extra letters this room needs
  local G = {
    A = {"XXX","X.X","XXX","X.X","X.X"}, B = {"XX.","X.X","XX.","X.X","XX."}, C = {".XX","X..","X..","X..",".XX"},
    D = {"XX.","X.X","X.X","X.X","XX."}, E = {"XXX","X..","XX.","X..","XXX"}, F = {"XXX","X..","XX.","X..","X.."},
    G = {".XX","X..","X.X","X.X",".XX"}, H = {"X.X","X.X","XXX","X.X","X.X"}, I = {"XXX",".X.",".X.",".X.","XXX"},
    J = {"..X","..X","..X","X.X","XXX"}, K = {"X.X","X.X","XX.","X.X","X.X"}, L = {"X..","X..","X..","X..","XXX"},
    M = {"X.X","XXX","XXX","X.X","X.X"}, N = {"XXX","X.X","X.X","X.X","X.X"}, O = {".X.","X.X","X.X","X.X",".X."},
    P = {"XX.","X.X","XX.","X..","X.."}, Q = {".X.","X.X","X.X","XX.",".XX"}, R = {"XX.","X.X","XX.","X.X","X.X"},
    S = {".XX","X..",".X.","..X","XX."}, T = {"XXX",".X.",".X.",".X.",".X."}, U = {"X.X","X.X","X.X","X.X","XXX"},
    V = {"X.X","X.X","X.X","X.X",".X."}, W = {"X.X","X.X","XXX","XXX","X.X"}, X = {"X.X","X.X",".X.","X.X","X.X"},
    Y = {"X.X","X.X",".X.",".X.",".X."}, Z = {"XXX","..X",".X.","X..","XXX"},
    ["0"] = {"XXX","X.X","X.X","X.X","XXX"}, ["1"] = {".X.","XX.",".X.",".X.","XXX"}, ["2"] = {"XX.","..X",".X.","X..","XXX"},
    ["3"] = {"XX.","..X",".X.","..X","XX."}, ["4"] = {"X.X","X.X","XXX","..X","..X"}, ["5"] = {"XXX","X..","XX.","..X","XX."},
    ["6"] = {".XX","X..","XXX","X.X","XXX"}, ["7"] = {"XXX","..X",".X.",".X.",".X."}, ["8"] = {"XXX","X.X","XXX","X.X","XXX"},
    ["9"] = {"XXX","X.X","XXX","..X","XX."}, ["-"] = {"...","...","XXX","...","..."}, ["."] = {"...","...","...","...",".X."},
    [">"] = {"X..",".X.","..X",".X.","X.."}, ["!"] = {".X.",".X.",".X.","...",".X."}, [" "] = {"...","...","...","...","..."},
  }
  local function textW(str, sc) return #str * 4 * sc - sc end
  local function drawText(R, str, x, y, sc, c, jitter)
    for i = 1, #str do
      local rows = G[str:sub(i, i)] or G[" "]
      local dy = jitter and (hash(i, #str, 3) % 2) or 0
      for r = 1, 5 do for cc = 1, 3 do
        if rows[r]:sub(cc, cc) == "X" then R(x + (i - 1) * 4 * sc + (cc - 1) * sc, y + dy + (r - 1) * sc, sc, sc, c) end
      end end
    end
  end

  -- ------------------------------------------------------------------ shared drawing bits
  local function cardboard(R, x, y, w, h, tone)
    local base = tone == 2 and "#C9A06A" or (tone == 3 and "#A47845" or "#B88A55")
    local sh = tone == 3 and "#7E5A30" or "#94683A"
    R(x, y, w, h, base); R(x + w - 1, y, 1, h, sh); R(x, y + h - 1, w, 1, sh)
    R(x, y, w, 1, "#D8B882")
    if w >= 8 then R(x + w // 2 - 1, y, 2, math.min(h, 4), "#D8C79A") end
  end
  local function toner(R, x, y, w, h, stripe)
    R(x, y, w, h, "#ECECE6"); R(x + w - 1, y, 1, h, "#C9C9C0"); R(x, y + h - 1, w, 1, "#C9C9C0")
    R(x, y + 2, w, 2, stripe)
  end
  local function crt(R, x, y, w, h)
    R(x, y, w, h, "#CFC6A8"); R(x + w - 1, y, 1, h, "#A89F82"); R(x, y + h - 1, w, 1, "#A89F82"); R(x, y, w, 1, "#E6DEC4")
    R(x + 2, y + 2, w - 5, h - 6, "#2A3338"); R(x + 3, y + 3, 3, 1, "#58696E"); R(x + w - 5, y + h - 3, 2, 1, "#6E9A5A")
  end
  local function pcUnit(R, x, y, w)
    R(x, y, w, 5, "#2A2A33"); R(x, y, w, 1, "#4A4A58"); R(x + w - 1, y, 1, 5, "#1C1C24"); R(x, y + 4, w, 1, "#1C1C24")
    R(x + 2, y + 2, 8, 1, "#0F0F14"); R(x + w - 5, y + 2, 2, 2, "#8A8F9A"); R(x + w - 8, y + 2, 1, 1, "#4EC46A")
  end
  local function pallet(R, x, y, w)
    for i = 0, w - 1, 6 do R(x + i, y, 5, 2, "#B88A55"); R(x + i, y, 5, 1, "#D8B882") end
    R(x, y + 2, 4, 3, "#8A6232"); R(x + w // 2 - 2, y + 2, 4, 3, "#8A6232"); R(x + w - 4, y + 2, 4, 3, "#8A6232")
    R(x, y + 5, w, 1, "#B88A55"); R(x, y + 5, w, 1, "#A47845")
  end
  local function chair(R, ox, by, c, hi)
    R(ox + 2, by - 24, 10, 10, c); R(ox + 2, by - 24, 10, 1, hi); R(ox + 11, by - 24, 1, 10, "#17121F")
    R(ox, by - 13, 14, 3, c); R(ox, by - 13, 14, 1, hi)
    R(ox + 6, by - 10, 2, 6, "#2A2A33"); R(ox + 1, by - 4, 12, 1, "#2A2A33")
    R(ox + 1, by - 3, 2, 2, "#17121F"); R(ox + 11, by - 3, 2, 2, "#17121F")
  end

  -- ------------------------------------------------------------------ pieces
  function P.chairRack()
    return L.piece(116, 54, function(R)
      R(0, 0, 3, 54, "#2F5D9E"); R(113, 0, 3, 54, "#2F5D9E"); R(1, 0, 1, 54, "#4A7CC0")
      R(0, 24, 116, 3, "#E0862A"); R(0, 26, 116, 1, "#B96A18"); R(0, 0, 116, 2, "#E0862A")
      R(0, 51, 116, 3, "#E0862A")
      local cols = {{"#2F3138", "#4A4D55"}, {"#2F3138", "#4A4D55"}, {"#6A6E78", "#8A8F9A"}, {"#2F3138", "#4A4D55"},
                    {"#7A2E3A", "#9C4452"}, {"#3E5E8E", "#5A7EB0"}}
      for i = 0, 5 do
        local c = cols[(i + 2) % 6 + 1]; chair(R, 5 + i * 18, 24, c[1], c[2])
        c = cols[i % 6 + 1]; chair(R, 5 + i * 18, 51, c[1], c[2])
      end
    end)
  end

  function P.vending()
    return L.piece(26, 44, function(R)
      R(0, 0, 26, 44, "#3B6EA8"); R(25, 0, 1, 44, "#2D5683"); R(0, 0, 26, 1, "#5A8CC8")
      R(2, 2, 22, 4, "#1C2A44"); drawText(R, "DRINKS", 3, 2, 1, "#9AD0F0")
      R(2, 8, 15, 24, "#1C2A44")
      local cc = {"#D8453A", "#F2C94C", "#4EC46A", "#E8E8E0", "#D8453A", "#3E7EE0"}
      for r = 0, 3 do for i = 0, 4 do R(3 + i * 3, 10 + r * 6, 2, 4, cc[(i + r) % 6 + 1]) end end
      R(2, 8, 15, 1, "#4A5A7A"); R(19, 9, 5, 8, "#2D5683")
      for r = 0, 2 do R(20, 10 + r * 3, 3, 2, "#C8CCD8") end
      R(19, 20, 5, 6, "#1C1C24"); R(20, 21, 3, 1, "#D8453A")
      R(2, 34, 22, 6, "#17121F"); R(3, 35, 20, 4, "#0F0F14"); R(0, 41, 26, 3, "#2D5683")
    end)
  end

  function P.palletStack()
    return L.piece(38, 26, function(R)
      local ox = {2, 0, 3, 1}
      for i = 0, 3 do pallet(R, ox[i + 1], 2 + i * 6, 34) end
      R(30, 0, 6, 2, "#B88A55")
    end)
  end

  function P.floorFan()
    return L.piece(20, 34, function(R)
      R(5, 31, 10, 3, "#4A4D55"); R(5, 31, 10, 1, "#6A6E78"); R(9, 14, 2, 17, "#7A838B")
      disc(R, 10, 7, 7, "#4A4D55"); disc(R, 10, 7, 6, "#B4BCC0")
      R(4, 7, 13, 1, "#7A838B"); R(10, 1, 1, 13, "#7A838B"); R(6, 3, 9, 1, "#8A9399"); R(6, 11, 9, 1, "#8A9399")
      disc(R, 10, 7, 1, "#2A2A33"); R(6, 3, 3, 3, "#D4DADC")
    end)
  end

  -- pallet racking bay: blue uprights, orange beams, a different load per bay
  function P.rackBay(kind)
    return L.piece(110, 80, function(R)
      R(0, 0, 3, 80, "#2F5D9E"); R(107, 0, 3, 80, "#2F5D9E"); R(1, 0, 1, 80, "#4A7CC0")
      R(0, 77, 4, 3, "#17121F"); R(106, 77, 4, 3, "#17121F")
      if kind == 1 then
        -- top: laptop cases
        for i = 0, 3 do R(8, 20 - i * 5, 44, 4, "#2A2A33"); R(8, 20 - i * 5, 44, 1, "#4A4A58"); R(26, 21 - i * 5, 8, 1, "#59596A"); R(9 + (i % 2) * 28, 21 - i * 5, 3, 2, "#C8CCD8") end
        for i = 0, 2 do R(56, 20 - i * 5, 44, 4, "#2A2A33"); R(56, 20 - i * 5, 44, 1, "#4A4A58"); R(74, 21 - i * 5, 8, 1, "#59596A") end
        -- middle: toner
        for i = 0, 3 do toner(R, 6 + i * 16, 39, 15, 11, ({"#2A2A33", "#2FB4D8", "#D8368A", "#F2C94C"})[i + 1]) end
        for i = 0, 3 do toner(R, 6 + i * 16, 28, 15, 11, ({"#F2C94C", "#2A2A33", "#2FB4D8", "#D8368A"})[i + 1]) end
        cardboard(R, 72, 28, 32, 22, 2); R(80, 36, 16, 6, "#ECECE6"); R(82, 38, 12, 1, "#2A2A33")
        -- bottom: monitor cartons and the CRT stack
        cardboard(R, 6, 54, 26, 23, 2); R(10, 60, 14, 8, "#2A2A33"); R(12, 62, 10, 4, "#4A5A60")
        cardboard(R, 33, 54, 22, 23, 1); R(37, 60, 14, 8, "#2A2A33"); R(39, 62, 10, 4, "#4A5A60")
        crt(R, 58, 66, 22, 11); crt(R, 58, 55, 22, 11); crt(R, 82, 56, 24, 21)
      else
        -- top: mixed brown boxes and a tape-wrapped pile
        cardboard(R, 6, 8, 22, 16, 1); cardboard(R, 30, 12, 18, 12, 2); cardboard(R, 50, 4, 26, 20, 3)
        cardboard(R, 78, 10, 24, 14, 1); R(54, 10, 18, 5, "#ECECE6"); R(56, 12, 14, 1, "#2A2A33")
        -- middle: switch and router boxes, and a shrink-wrapped pallet load
        for r = 0, 1 do for i = 0, 3 do
          local x, y = 6 + i * 15, 29 + r * 11
          R(x, y, 14, 10, "#ECECE6"); R(x + 13, y, 1, 10, "#C9C9C0"); R(x, y + 9, 14, 1, "#C9C9C0")
          R(x + 2, y + 2, 10, 1, "#2F78C8"); R(x + 2, y + 5, 8, 2, "#2A2A33")
          for k = 0, 3 do R(x + 3 + k * 2, y + 5, 1, 1, "#4EC46A") end
        end end
        cardboard(R, 68, 28, 18, 21, 2); cardboard(R, 86, 28, 18, 21, 1)
        for i = 0, 5 do R(70 + i * 5, 31 + i * 3, 10, 1, "#E8EEF0") end
        -- bottom: three reels of blue network cable and a box
        for i = 0, 2 do
          local cx = 14 + i * 24
          disc(R, cx, 66, 11, "#B88A55"); disc(R, cx, 66, 9, "#2F6FD0"); disc(R, cx, 66, 6, "#2458A8"); disc(R, cx, 66, 3, "#6E4C2A")
          R(cx - 7, 60, 4, 1, "#5A9AF0"); R(cx - 3, 57, 5, 1, "#5A9AF0")
        end
        cardboard(R, 86, 55, 20, 22, 3)
      end
      -- beams last so they sit in front of the load
      R(0, 24, 110, 3, "#E0862A"); R(0, 26, 110, 1, "#B96A18")
      R(0, 50, 110, 3, "#E0862A"); R(0, 52, 110, 1, "#B96A18")
      R(0, 77, 110, 1, "#E0862A")
    end)
  end

  -- the parts cage: wire mesh over little shelves of bins, a hasp and a padlock
  function P.partsCage()
    return L.piece(100, 74, function(R)
      R(2, 2, 96, 70, "#3A3F4A")
      for s = 0, 2 do
        R(4, 18 + s * 18, 92, 2, "#7A838B")
        for i = 0, 8 do
          local c = ({"#C23B2E", "#2F78C8", "#E0B040", "#6E9A5A", "#8A8F9A"})[(i + s) % 5 + 1]
          R(6 + i * 10, 8 + s * 18, 8, 10, c); R(6 + i * 10, 8 + s * 18, 8, 1, "#E8E8E0")
        end
      end
      R(6, 62, 22, 9, "#B88A55"); R(32, 58, 18, 13, "#A47845"); R(54, 62, 24, 9, "#2A2A33")
      for x = 3, 97, 3 do R(x, 2, 1, 70, "#8A9399") end
      for y = 4, 72, 3 do R(2, y, 96, 1, "#6A737A") end
      R(0, 0, 100, 3, "#59626A"); R(0, 71, 100, 3, "#59626A"); R(0, 0, 3, 74, "#59626A"); R(97, 0, 3, 74, "#59626A")
      R(66, 3, 3, 69, "#59626A"); R(66, 34, 31, 3, "#59626A")                -- the door
      R(60, 31, 10, 7, "#8A8F9A"); R(72, 36, 6, 5, "#E0B040"); R(73, 33, 4, 3, "#B58A20")   -- hasp and padlock
      R(72, 36, 6, 1, "#F2D880")
      R(4, 4, 24, 8, "#F2C94C"); drawText(R, "PARTS", 6, 5, 1, "#17121F")
    end)
  end

  function P.palletJack()
    return L.piece(40, 18, function(R)
      R(8, 14, 32, 3, "#2A2A33"); R(8, 14, 32, 1, "#4A4A58")
      R(10, 9, 14, 5, "#C23B2E"); R(10, 9, 14, 1, "#E8604E")
      R(3, 0, 3, 10, "#E0B040"); R(2, 0, 7, 2, "#2A2A33"); R(5, 9, 6, 2, "#8A8F9A")
      R(6, 12, 4, 4, "#17121F"); R(34, 13, 4, 4, "#17121F"); R(25, 11, 3, 3, "#8A8F9A")
    end)
  end

  -- the workbench with the bench PC being imaged (the screen is drawn live by fx kind bench_screen at set (953, 78) size 18x12)
  function P.bench()
    return L.piece(100, 38, function(R)
      R(2, 30, 3, 8, "#4A4D55"); R(95, 30, 3, 8, "#4A4D55"); R(2, 33, 96, 2, "#6A6E78")
      R(0, 26, 100, 4, "#A97C45"); R(0, 26, 100, 1, "#C99A5F"); R(0, 29, 100, 1, "#7A5A30")
      R(8, 36, 14, 2, "#B88A55"); R(60, 35, 20, 3, "#2A2A33")
      -- the open tower
      R(8, 4, 20, 22, "#2A2A33"); R(8, 4, 20, 1, "#4A4A58"); R(27, 4, 1, 22, "#1C1C24")
      R(10, 7, 12, 2, "#0F0F14"); R(10, 11, 12, 2, "#0F0F14"); R(24, 6, 2, 2, "#4EC46A"); R(24, 10, 2, 1, "#F2862E")
      R(10, 16, 14, 7, "#4A5A60"); R(12, 18, 4, 3, "#8A8F9A"); R(18, 18, 4, 3, "#2A2A33")
      -- the monitor and keyboard
      R(61, 6, 22, 16, "#2A2A33"); R(61, 6, 22, 1, "#4A4A58"); R(63, 8, 18, 12, "#2F78C8")
      R(70, 22, 4, 3, "#4A4D55"); R(66, 24, 12, 2, "#4A4D55"); R(56, 25, 28, 1, "#D8D8D0")
      R(30, 14, 30, 1, "#17121F"); R(30, 15, 2, 11, "#17121F")      -- the cable
      R(88, 22, 6, 4, "#B88A55"); R(89, 20, 3, 2, "#E0B040"); R(94, 21, 3, 5, "#C23B2E")   -- tray, mug
    end)
  end

  -- plywood panel with a dart board, next to white shelving with grey tubs
  function P.dartPanel()
    return L.piece(62, 66, function(R)
      -- white shelving
      R(0, 0, 2, 66, "#ECEAE0"); R(29, 0, 2, 66, "#ECEAE0"); R(2, 0, 27, 1, "#ECEAE0")
      for i = 0, 3 do R(2, 14 + i * 16, 27, 2, "#ECEAE0"); R(2, 15 + i * 16, 27, 1, "#BDB8A8") end
      local tubs = {{3, 4, 12, 10}, {16, 5, 11, 9}, {3, 20, 24, 10}, {4, 38, 10, 8}, {16, 36, 12, 10}, {3, 52, 12, 10}, {18, 54, 9, 8}}
      for i, t in ipairs(tubs) do
        R(t[1], t[2], t[3], t[4], "#AEB7C0"); R(t[1], t[2], t[3], 2, "#8E96A0"); R(t[1] + t[3] - 1, t[2], 1, t[4], "#8892A0")
        R(t[1] + 2, t[2] + 4, t[3] - 4, 1, "#C9D0D6")
      end
      R(10, 38, 1, 1, "#C23B2E")
      -- plywood panel
      R(33, 0, 29, 66, "#C99A5F"); R(33, 0, 1, 66, "#E0B070"); R(61, 0, 1, 66, "#A87A3F")
      for i = 0, 5 do R(36 + i * 5, 0, 1, 66, "#B58648") end
      R(33, 33, 29, 1, "#A87A3F"); R(40, 12, 2, 2, "#A87A3F"); R(54, 50, 3, 2, "#A87A3F")
      for _, sy in ipairs({3, 63}) do R(35, sy, 1, 1, "#6E4C2A"); R(59, sy, 1, 1, "#6E4C2A") end
      -- the score sheet
      R(36, 5, 12, 9, "#F2F2EA"); R(37, 7, 6, 1, "#C23B2E"); R(37, 9, 8, 1, "#8A8F9A"); R(37, 11, 5, 1, "#8A8F9A"); R(46, 5, 2, 2, "#2F78C8")
      -- the board (centre 47, 33)
      local cx, cy = 47, 33
      for y = -10, 10 do for x = -10, 10 do
        local d = math.sqrt(x * x + y * y)
        local c
        if d <= 10.4 then
          local a = math.floor((math.atan(y, x) + math.pi) / (math.pi / 10)) % 2
          if d < 1.3 then c = "#C23B2E"
          elseif d < 2.8 then c = "#2F8B4E"
          elseif d < 6.2 then c = (a == 0) and "#E8DDB0" or "#2A2A33"
          elseif d < 7.4 then c = (a == 0) and "#C23B2E" or "#2F8B4E"
          elseif d < 8.6 then c = (a == 0) and "#E8DDB0" or "#2A2A33"
          elseif d < 9.4 then c = (a == 0) and "#2F8B4E" or "#C23B2E"
          else c = "#1C1C24" end
          R(cx + x, cy + y, 1, 1, c)
        end
      end end
      -- darts: two in the board (one very nearly a bullseye), one in the wood
      R(cx + 1, cy - 1, 3, 1, "#8A8F9A"); R(cx + 4, cy - 2, 2, 3, "#F2862E")
      R(cx - 4, cy + 3, 3, 1, "#8A8F9A"); R(cx - 6, cy + 2, 2, 3, "#2F78C8")
      R(cx - 12, cy + 8, 3, 1, "#8A8F9A"); R(cx - 14, cy + 7, 2, 3, "#C23B2E")
    end)
  end

  function P.xmasTree()
    return L.piece(34, 54, function(R)
      R(15, 49, 4, 5, "#4A3220"); R(10, 52, 14, 2, "#2A2A33")
      for y = 5, 49 do
        local hw = 2 + math.floor((y - 5) * 0.36)
        local t = (y // 11) % 2
        R(17 - hw, y, hw * 2, 1, t == 0 and "#2E7D32" or "#256B2A")
        R(17 - hw, y, 1, 1, "#4FA05A"); R(16 + hw, y, 1, 1, "#1A4E1E")
        -- dust over the needles
        for k = 0, 3 do
          local dx = hash(y, k, 7) % (hw * 2)
          R(17 - hw + dx, y, 1, 1, "#8FA58A")
        end
      end
      -- the green garland swirling round
      for y = 8, 46, 1 do
        local hw = 2 + math.floor((y - 5) * 0.36)
        local x = 17 + math.floor(math.sin(y * 0.55) * (hw - 1))
        R(x, y, 2, 1, "#43B050")
      end
      -- red and bronze ornaments
      local orn = {{15, 12, 1}, {20, 17, 2}, {11, 21, 1}, {22, 26, 2}, {9, 31, 2}, {17, 29, 1}, {25, 35, 1}, {13, 38, 2}, {7, 42, 1}, {21, 43, 2}, {16, 46, 1}}
      for _, o in ipairs(orn) do
        local c = o[3] == 1 and "#B3262C" or "#B8793A"
        R(o[1], o[2], 2, 2, c); R(o[1], o[2], 1, 1, o[3] == 1 and "#E0605A" or "#E0A860")
      end
      -- bulbs of the forgotten string of lights (dark; fx kind tree_lights lights them), and the dull star on top
      for _, b in ipairs({{17, 10}, {12, 18}, {22, 20}, {9, 28}, {25, 30}, {14, 36}, {20, 38}, {6, 44}, {28, 46}, {17, 48}}) do R(b[1], b[2], 1, 1, "#5A5A50") end
      R(16, 0, 3, 5, "#C9A84A"); R(14, 2, 7, 1, "#C9A84A"); R(16, 2, 1, 2, "#E8D080")
    end)
  end

  function P.bbqGrill()
    return L.piece(32, 36, function(R)
      R(5, 4, 22, 8, "#2A2A33"); R(5, 4, 22, 1, "#59596A"); R(8, 5, 16, 1, "#3F3F4D"); R(8, 1, 16, 3, "#8A8F9A")
      R(5, 12, 22, 9, "#3A3A46"); R(5, 12, 22, 1, "#59596A"); R(26, 12, 1, 9, "#1C1C24")
      for i = 0, 2 do R(9 + i * 6, 15, 4, 2, "#17121F"); R(10 + i * 6, 17, 2, 1, "#C23B2E") end
      R(0, 11, 6, 3, "#8A8F9A"); R(0, 11, 6, 1, "#B4BCC0")
      R(4, 21, 2, 11, "#4A4D55"); R(26, 21, 2, 11, "#4A4D55"); R(6, 26, 20, 2, "#59626A")
      disc(R, 5, 32, 3, "#2A2A33"); disc(R, 27, 32, 3, "#2A2A33"); R(5, 32, 1, 1, "#8A8F9A"); R(27, 32, 1, 1, "#8A8F9A")
      R(11, 28, 8, 7, "#B8C0A8"); R(11, 28, 8, 1, "#D8DEC8"); R(14, 26, 2, 2, "#8A8F9A")
    end)
  end

  -- the overhead (roll-up) door: grey corrugated slats, ready to be opened and closed later (a separate sprite on the doorway)
  function P.overheadDoor()
    return L.piece(120, 80, function(R)
      R(0, 0, 120, 80, "#9AA3A8")
      for y = 0, 79, 4 do R(0, y, 120, 1, "#B4BCC0"); R(0, y + 2, 120, 1, "#7A838B"); R(0, y + 3, 120, 1, "#6A737A") end
      for x = 40, 80, 40 do R(x, 0, 1, 80, "#8A9399") end
      R(0, 76, 120, 4, "#3A3A3E"); R(0, 76, 120, 1, "#59596A"); R(54, 66, 12, 5, "#59626A"); R(58, 68, 4, 2, "#17121F")
      R(118, 0, 2, 80, "#6A737A")
      for _, sx in ipairs({16, 44, 72, 100}) do R(sx, 22, 1, 1, "#6A737A"); R(sx + 1, 53, 1, 1, "#6A737A") end
      R(20, 30, 14, 2, "#8A9399"); R(80, 44, 18, 3, "#8A9399")     -- old dents and scuffs
    end)
  end

  -- the e-waste corner ------------------------------------------------------------------
  function P.ewasteTowers()
    return L.piece(48, 64, function(R)
      for i = 0, 10 do pcUnit(R, 0 + (i % 3 == 1 and 1 or 0), 59 - i * 5, 22) end
      for i = 0, 6 do pcUnit(R, 25 + (i % 2), 59 - i * 5, 22) end
      R(25, 21, 22, 2, "#9AA0A8"); R(25, 21, 22, 1, "#C8CCD8"); R(28, 19, 16, 2, "#4A5A60")        -- a laptop on the small pile
      R(2, 4, 22, 2, "#8A8F9A"); R(2, 4, 22, 1, "#B4BCC0")                                          -- one on the tall pile
      R(22, 8, 1, 14, "#17121F"); R(23, 20, 2, 1, "#17121F")                                        -- a dangling power cord
    end)
  end

  function P.ewasteMixed()
    return L.piece(58, 36, function(R)
      crt(R, 0, 15, 24, 21); crt(R, 4, 4, 20, 11)
      R(26, 22, 9, 14, "#2A2A33"); R(26, 22, 9, 1, "#4A4A58"); disc(R, 30, 30, 2, "#4A4A58")
      R(26, 10, 9, 12, "#2A2A33"); R(26, 10, 9, 1, "#4A4A58"); disc(R, 30, 16, 2, "#4A4A58")
      R(37, 12, 10, 24, "#2A2A33"); R(37, 12, 10, 1, "#4A4A58"); R(46, 12, 1, 24, "#1C1C24")
      R(39, 15, 6, 2, "#0F0F14"); R(39, 19, 6, 2, "#0F0F14"); R(40, 30, 2, 2, "#4EC46A")
      R(48, 20, 9, 16, "#2A2A33"); R(48, 20, 9, 1, "#4A4A58"); R(50, 23, 5, 2, "#0F0F14")
      R(0, 35, 58, 1, "#17121F")
      for i = 0, 5 do R(2 + i * 9, 34, 6, 1, i % 2 == 0 and "#F2862E" or "#2A2A33") end
    end)
  end

  function P.gaylord()
    return L.piece(32, 40, function(R)
      R(0, 12, 32, 28, "#B8935C"); R(0, 12, 32, 1, "#D8B882"); R(31, 12, 1, 28, "#8E6E40"); R(0, 39, 32, 1, "#8E6E40")
      R(0, 18, 32, 1, "#5C6670"); R(0, 32, 32, 1, "#5C6670")
      R(2, 21, 28, 9, "#F2F2EA"); R(2, 21, 28, 1, "#2E8B4A"); R(2, 29, 28, 1, "#2E8B4A"); drawText(R, "RECYCLE", 3, 23, 1, "#2E8B4A")
      R(12, 34, 8, 3, "#8E6E40")
      -- the junk poking out of the top
      R(1, 6, 8, 6, "#2A2A33"); R(2, 4, 6, 2, "#8A8F9A"); R(10, 3, 6, 9, "#C8CCD8"); R(11, 4, 4, 5, "#2A2A33")
      R(18, 7, 12, 5, "#2A2A33"); R(20, 5, 6, 2, "#4A4A58"); R(24, 0, 1, 8, "#F2862E"); R(25, 0, 3, 1, "#F2862E")
      R(5, 0, 1, 6, "#2A2A33"); R(6, 0, 3, 1, "#2A2A33")
    end)
  end

  -- a cardboard box overflowing with orange and black network cables (a parody courier box)
  function P.fedupBox()
    return L.piece(38, 28, function(R)
      R(0, 10, 38, 18, "#B88A55"); R(0, 10, 38, 1, "#D8B882"); R(37, 10, 1, 18, "#94683A"); R(0, 27, 38, 1, "#94683A")
      R(3, 15, 26, 9, "#F2F2EA"); R(3, 15, 26, 1, "#5B2D8E"); R(3, 23, 26, 1, "#F2862E"); drawText(R, "FEDUP", 6, 17, 1, "#5B2D8E")
      R(31, 15, 4, 8, "#D8C79A")
      -- the lid flaps and the cables spilling over the rim
      R(0, 8, 8, 3, "#C9A06A"); R(30, 7, 8, 4, "#C9A06A"); R(2, 6, 5, 2, "#B88A55")
      local loops = {{4, 6, 8, 4}, {10, 3, 10, 6}, {18, 2, 8, 7}, {24, 5, 9, 5}, {8, 0, 7, 5}, {14, 5, 8, 3}}
      for i, l in ipairs(loops) do
        local c = (i % 2 == 0) and "#2A2A33" or "#F2862E"
        R(l[1], l[2], l[3], 1, c); R(l[1], l[2] + l[4], l[3], 1, c); R(l[1], l[2], 1, l[4], c); R(l[1] + l[3] - 1, l[2], 1, l[4], c)
      end
      R(33, 10, 2, 12, "#F2862E"); R(35, 20, 3, 1, "#F2862E"); R(1, 14, 1, 10, "#2A2A33")
    end)
  end

  -- loose items (the chair race's obstacles later; parked against the wall for now) -----------------------
  function P.cone()
    return L.piece(12, 16, function(R)
      R(0, 13, 12, 3, "#2A2A33"); R(0, 13, 12, 1, "#4A4A58")
      R(3, 6, 6, 7, "#F2862E"); R(4, 2, 4, 4, "#F2862E"); R(5, 0, 2, 2, "#F2862E")
      R(3, 8, 6, 2, "#F2F2EA"); R(4, 4, 4, 1, "#F2F2EA"); R(3, 6, 1, 7, "#F8A860"); R(8, 6, 1, 7, "#C8681E")
    end)
  end

  function P.wetSign()
    return L.piece(14, 20, function(R)
      R(2, 0, 10, 2, "#F2C94C"); R(1, 2, 12, 16, "#F2C94C"); R(0, 16, 14, 4, "#F2C94C")
      R(2, 0, 10, 1, "#F8E080"); R(12, 2, 1, 16, "#D8A82C"); R(1, 19, 12, 1, "#D8A82C")
      drawText(R, "WET", 2, 3, 1, "#17121F")
      R(6, 10, 2, 2, "#17121F"); R(5, 12, 4, 2, "#17121F"); R(4, 14, 2, 1, "#17121F"); R(8, 14, 3, 1, "#17121F"); R(9, 12, 2, 1, "#17121F")
    end)
  end

  function P.oilPuddle()
    return L.piece(32, 8, function(R)
      R(4, 0, 24, 8, "#2A2A33"); R(1, 2, 30, 4, "#2A2A33"); R(0, 3, 32, 2, "#2A2A33")
      R(7, 1, 8, 1, "#4A4260"); R(9, 2, 5, 1, "#3F6A7A"); R(20, 4, 6, 1, "#5B4A7A"); R(17, 5, 4, 1, "#3F6A7A")
      R(4, 1, 3, 1, "#59596A"); R(12, 6, 10, 1, "#1C1C24")
    end)
  end

  function P.smallPallet()
    return L.piece(30, 9, function(R) pallet(R, 0, 1, 30) end)
  end

  function P.boxStack()
    return L.piece(24, 28, function(R)
      cardboard(R, 0, 15, 24, 13, 1); cardboard(R, 2, 4, 20, 11, 2); cardboard(R, 6, 0, 14, 4, 3)
      R(0, 22, 24, 1, "#94683A"); R(8, 17, 8, 1, "#ECECE6"); R(5, 8, 5, 3, "#2A2A33")
    end)
  end

  function P.trashCan()
    return L.piece(16, 22, function(R)
      R(2, 3, 12, 15, "#59626A"); R(2, 3, 2, 15, "#7A838B"); R(12, 3, 2, 15, "#464F57")
      R(0, 1, 16, 3, "#6A737A"); R(0, 1, 16, 1, "#8A9399"); R(5, 7, 6, 2, "#2A2A33")
      R(4, 18, 3, 4, "#17121F"); R(10, 18, 3, 4, "#17121F")
      R(4, 0, 4, 2, "#17121F"); R(9, 0, 3, 1, "#2A2A33")
    end)
  end

  -- wall bits -----------------------------------------------------------------------------------------------
  local function banner(text, sc, w, bg, fg, trim)
    return L.piece(w, 17, function(R)
      R(w // 4, 0, 1, 4, "#4A525A"); R(w - w // 4, 0, 1, 4, "#4A525A")
      R(0, 4, w, 13, bg); R(0, 4, w, 1, trim); R(0, 16, w, 1, trim)
      drawText(R, text, (w - textW(text, sc)) // 2, 6 + (sc == 2 and 0 or 2), sc, fg)
      for i = 0, w - 1, 4 do R(i, 4, 2, 1, trim) end
    end)
  end

  function P.partnerBanner()
    return L.piece(60, 22, function(R)
      R(0, 0, 60, 22, "#2F5DA8"); R(0, 0, 60, 1, "#4A7CC8"); R(59, 0, 1, 22, "#234A88"); R(0, 21, 60, 1, "#234A88")
      drawText(R, "SMALL", 2, 3, 1, "#F2F2EA"); drawText(R, "BUSINESS", 2, 9, 1, "#F2F2EA"); drawText(R, "PARTNER", 2, 15, 1, "#F2C94C")
      R(46, 4, 10, 10, "#F2F2EA"); R(48, 6, 6, 6, "#2F5DA8"); R(50, 8, 2, 2, "#F2C94C")
    end)
  end

  function P.timeClock()
    return L.piece(16, 24, function(R)
      R(5, 0, 11, 24, "#8A8F9A"); R(5, 0, 11, 1, "#B4BCC0"); R(15, 0, 1, 24, "#6A6E78")
      disc(R, 10, 6, 4, "#F2F2EA"); R(10, 3, 1, 4, "#17121F"); R(10, 6, 3, 1, "#17121F")
      R(7, 13, 7, 2, "#17121F"); R(8, 17, 5, 4, "#2A2A33"); R(9, 18, 1, 1, "#C23B2E")
      R(0, 2, 4, 16, "#B88A55"); for i = 0, 3 do R(1, 3 + i * 4, 3, 3, "#F2F2EA") end
    end)
  end

  function P.poster(kind)
    return L.piece(14, 18, function(R)
      if kind == 1 then          -- first aid
        R(0, 0, 14, 18, "#2E8B4A"); R(0, 0, 14, 1, "#4EB06A"); R(5, 4, 4, 10, "#F2F2EA"); R(2, 7, 10, 4, "#F2F2EA")
      elseif kind == 2 then      -- caution
        R(0, 0, 14, 18, "#F2C94C"); R(0, 0, 14, 1, "#F8E080"); R(6, 3, 2, 2, "#17121F"); R(5, 5, 4, 3, "#17121F"); R(4, 8, 6, 3, "#17121F")
        R(6, 13, 2, 3, "#17121F")
      else                       -- lift with your legs
        R(0, 0, 14, 18, "#F2F2EA"); R(0, 0, 14, 2, "#C23B2E"); R(5, 4, 3, 3, "#17121F"); R(4, 7, 5, 4, "#2F78C8"); R(3, 11, 3, 5, "#17121F"); R(7, 11, 3, 5, "#17121F")
        R(9, 8, 4, 3, "#B88A55")
      end
    end)
  end

  function P.extinguisher()
    return L.piece(8, 18, function(R)
      R(1, 3, 6, 13, "#C23B2E"); R(1, 3, 2, 13, "#E8604E"); R(2, 0, 4, 3, "#2A2A33"); R(5, 1, 3, 1, "#2A2A33")
      R(2, 8, 4, 4, "#F2F2EA"); R(3, 16, 2, 2, "#17121F")
    end)
  end

  function P.blueCoil()
    return L.piece(12, 14, function(R)
      R(5, 0, 2, 2, "#8A8F9A"); disc(R, 6, 8, 5, "#2F6FD0"); disc(R, 6, 8, 3, "#2458A8"); disc(R, 6, 8, 1, "#17121F")
      R(9, 11, 3, 3, "#2F6FD0")
    end)
  end

  function P.splitAc()
    return L.piece(46, 13, function(R)
      R(0, 0, 46, 11, "#ECEAE0"); R(0, 0, 46, 1, "#FFFFFF"); R(0, 10, 46, 1, "#BDB8A8"); R(45, 0, 1, 11, "#D2CEC0")
      R(2, 6, 42, 3, "#C9C6B8"); for x = 3, 43, 2 do R(x, 7, 1, 1, "#8A8F9A") end
      R(36, 2, 6, 1, "#4EC46A"); R(4, 2, 12, 2, "#D2CEC0")
      R(8, 11, 3, 2, "#C9C6B8")
    end)
  end

  function P.signCard(text, w)
    return L.piece(w, 13, function(R)
      R(0, 0, w, 13, "#C9A06A"); R(0, 0, w, 1, "#D8B882"); R(w - 1, 0, 1, 13, "#94683A"); R(0, 12, w, 1, "#94683A")
      R(3, 0, 5, 2, "#D8C79A"); R(w - 8, 0, 5, 2, "#D8C79A")
      drawText(R, text, (w - textW(text, 1)) // 2, 4, 1, "#17121F", true)
    end)
  end

  function P.dockLight()
    return L.piece(16, 40, function(R)
      R(0, 0, 4, 6, "#4A4D55")                               -- the wall bracket and the swing arm
      R(2, 2, 12, 2, "#8A8F9A"); R(11, 2, 3, 12, "#8A8F9A")
      R(8, 12, 8, 6, "#F2C94C"); R(8, 12, 8, 1, "#F8E080"); R(9, 17, 6, 2, "#FFF3C0")
      R(0, 22, 9, 16, "#2A2A33"); R(0, 22, 9, 1, "#4A4A58"); disc(R, 4, 27, 2, "#4EC46A"); disc(R, 4, 33, 2, "#6A2A2A")
    end)
  end

  function P.cableRun()
    return L.piece(36, 6, function(R)
      R(0, 3, 6, 1, "#F2862E"); R(5, 2, 6, 1, "#F2862E"); R(10, 3, 8, 1, "#F2862E"); R(17, 4, 8, 1, "#F2862E"); R(24, 3, 12, 1, "#F2862E")
      R(2, 4, 8, 1, "#2A2A33"); R(9, 5, 8, 1, "#2A2A33"); R(16, 5, 10, 1, "#2A2A33"); R(25, 4, 8, 1, "#2A2A33")
    end)
  end

  -- ------------------------------------------------------------------ the room
  local function wallLayer(s)
    local wall = s.layer("Wall")
    -- upper band: corrugated steel
    for x = 0, W - 1 do
      local m = x % 4
      F(wall, x, 0, 1, 25, m == 0 and "#B4BCC0" or (m == 2 and "#8E979C" or "#A5AEB3"))
    end
    F(wall, 0, 25, W, 2, "#6F787E"); F(wall, 0, 27, W, 1, "#4A525A")
    -- the white painted wall below, dirty at the bottom and streaked
    F(wall, 0, 28, W, 56, "#E9E6DC")
    for x = 0, W - 1, 6 do F(wall, x, 28, 1, 56, "#E4E1D6") end
    for i = 0, 140 do
      local x, y = hash(i, 1, 41) % W, 28 + hash(i, 2, 41) % 40
      F(wall, x, y, 1, 4 + hash(i, 3, 41) % 16, "#D8D4C6")
    end
    for i = 0, 70 do
      local x, y = hash(i, 4, 43) % W, 60 + hash(i, 5, 43) % 22
      F(wall, x, y, 2 + hash(i, 6, 43) % 5, 1 + hash(i, 7, 43) % 3, "#C9C4B4")
    end
    F(wall, 0, 70, W, 12, "#DAD6C8")
    for x = 0, W - 1, 3 do F(wall, x, 70 + (x // 3) % 3, 1, 12 - (x // 3) % 3, "#D0CCBC") end
    F(wall, 0, 82, W, 4, "#8E8B80"); F(wall, 0, 82, W, 1, "#A8A598"); F(wall, 0, 86, W, 4, "#3A3836")
    -- a water stain or two
    for _, st in ipairs({{214, 30, 26}, {640, 30, 20}, {1010, 30, 34}, {1420, 30, 22}}) do
      for y = 0, st[3] do
        local hw = 3 + (y % 5 == 0 and 1 or 0)
        F(wall, st[1] - hw // 2, st[2] + y, hw, 1, "#CFC8AE")
      end
    end
    -- the dusty window band
    for k = 0, 25 do
      local x = 14 + k * 57
      if not (x > 610 and x < 670) then
        F(wall, x, 4, 41, 17, "#4A525A")
        for p = 0, 2 do
          local px0 = x + 2 + p * 13
          F(wall, px0, 6, 12, 13, "#C4DCE8")
          F(wall, px0, 6, 12, 2, "#D8E8F0")
          for d = 0, 3 do F(wall, px0 + hash(k, p * 4 + d, 51) % 11, 6 + hash(k, p * 4 + d, 52) % 12, 1, 1 + d % 2, "#A9BFC8") end
          F(wall, px0, 16, 12, 3, "#B2C4CA")                                -- dust line on the lower glass
          F(wall, px0 + 2 + (k + p) % 5, 8, 2, 8, "#DDEAF0")                -- glare streak
        end
        F(wall, x, 20, 41, 1, "#6F787E")
      end
    end
    -- steel corner columns
    F(wall, 0, 0, 6, 90, "#4A525A"); F(wall, 1, 0, 1, 90, "#6A737A"); F(wall, 5, 0, 1, 90, "#2A3036")
    F(wall, W - 6, 0, 6, 90, "#4A525A"); F(wall, W - 5, 0, 1, 90, "#6A737A"); F(wall, W - 1, 0, 1, 90, "#2A3036")
  end

  local function storageRoom(s)
    local wall = s.layer("Wall")
    local x0, y0, w, h = 770, 34, 100, 52
    F(wall, x0 - 3, y0 - 3, w + 6, h + 3, "#BDB8A8"); F(wall, x0 - 2, y0 - 2, w + 4, h + 2, "#E9E6DC")
    F(wall, x0, y0, w, h, "#5B5E63")
    for y = 0, h - 1, 3 do F(wall, x0, y0 + y, w, 1, "#55585D") end
    F(wall, x0, y0, w, 6, "#4A4D52")                                   -- a shadow under the lintel
    F(wall, x0, y0 + h - 6, w, 6, "#76776F"); F(wall, x0, y0 + h - 6, w, 1, "#8A8B84")   -- the back room floor
    F(wall, x0, y0, 1, h, "#17121F"); F(wall, x0 + w - 1, y0, 1, h, "#17121F"); F(wall, x0, y0, w, 1, "#17121F")
    -- metal shelving on the left: grey uprights and boxes
    local sx = x0 + 6
    F(wall, sx, y0 + 6, 2, h - 12, "#9AA0A8"); F(wall, sx + 34, y0 + 6, 2, h - 12, "#9AA0A8")
    for i = 0, 3 do F(wall, sx, y0 + 12 + i * 11, 36, 2, "#B4BCC0") end
    local boxes = {{sx + 3, y0 + 4, 9, 8, 1}, {sx + 14, y0 + 6, 8, 6, 2}, {sx + 24, y0 + 3, 9, 9, 3},
                   {sx + 3, y0 + 16, 12, 7, 2}, {sx + 18, y0 + 14, 14, 9, 1}, {sx + 3, y0 + 27, 9, 6, 3}, {sx + 14, y0 + 26, 16, 7, 1}}
    for _, b in ipairs(boxes) do
      F(wall, b[1], b[2], b[3], b[4], b[5] == 1 and "#B88A55" or (b[5] == 2 and "#C9A06A" or "#A47845"))
      F(wall, b[1], b[2] + b[4] - 1, b[3], 1, "#6E4C2A"); F(wall, b[1] + b[3] - 1, b[2], 1, b[4], "#8E6E40")
    end
    F(wall, sx + 3, y0 + 36, 14, 4, "#2A2A33"); F(wall, sx + 19, y0 + 35, 12, 5, "#C23B2E")
    -- the network rack on the right (a four post rack: switches, a patch panel, a UPS)
    local rx = x0 + 60
    F(wall, rx, y0 + 4, 26, 42, "#1C1C24"); F(wall, rx + 1, y0 + 4, 1, 42, "#3A3F4A"); F(wall, rx + 24, y0 + 4, 1, 42, "#3A3F4A")
    for u = 0, 8 do
      local uy = y0 + 6 + u * 4
      local c = (u == 2 or u == 6) and "#4A5A7A" or (u == 8 and "#59596A" or "#3A3F4A")
      F(wall, rx + 3, uy, 20, 3, c)
      if u ~= 8 then
        for k = 0, 8 do F(wall, rx + 5 + k * 2, uy + 1, 1, 1, ((k + u) % 3 == 0) and "#F2862E" or "#4EC46A") end
      end
    end
    F(wall, rx + 3, y0 + 40, 20, 5, "#2A2A33"); F(wall, rx + 15, y0 + 41, 6, 2, "#4EC46A")
    F(wall, x0 + 46, y0 + 8, 3, 3, "#FFF3C0")                            -- a bare bulb in the back room
    F(wall, x0 + 45, y0 + 4, 5, 1, "#8A8F9A")
  end

  local function floorLayer(s)
    local fl = s.layer("Floor")
    local y0 = 90 + L.YOFF
    local H = fl.height
    local base, lo, hi, mo = col("#8C8D88"), col("#7E7F7A"), col("#979893"), col("#868782")
    for y = y0, H - 1 do
      for x = 0, W - 1 do
        local h = hash(x, y, 5)
        local c = base
        if hash(x // 5, y // 3, 9) % 6 == 0 then c = mo end
        if h % 9 == 0 then c = hi elseif h % 11 == 0 then c = lo end
        fl:putPixel(x, y, c)
      end
    end
    -- the shadow where the wall meets the floor
    L.fill(fl, 0, y0, W, 2, "#5A5B57"); L.fill(fl, 0, y0 + 2, W, 3, "#76776F"); L.fill(fl, 0, y0 + 5, W, 3, "#82837E")
    -- expansion joints (long saw cuts) and slab edges
    for k = 0, 11 do
      local x = 40 + k * 130
      L.fill(fl, x, y0 + 6, 1, H - y0 - 6, "#5C5D58"); L.fill(fl, x + 1, y0 + 6, 1, H - y0 - 6, "#9A9B96")
    end
    L.fill(fl, 0, 140 + L.YOFF, W, 1, "#5C5D58"); L.fill(fl, 0, 141 + L.YOFF, W, 1, "#9A9B96")
    for k = 0, 11 do                                                      -- a few hairline cracks
      local cx, cy = 90 + k * 123 + hash(k, 1, 61) % 40, 112 + hash(k, 2, 61) % 24
      for i = 0, 7 + hash(k, 3, 61) % 8 do
        L.fill(fl, cx + i, cy + (i // 3) * ((k % 2 == 0) and 1 or -1), 1, 1, "#62635E")
      end
    end
    -- damp patches and oil
    local function blob(cx, cy, rx, ry, c, c2, seed)
      for y = -ry, ry do for x = -rx, rx do
        local d = (x * x) / (rx * rx) + (y * y) / (ry * ry)
        local j = (hash(x + 50, y + 50, seed) % 100) / 400
        if d + j < 1.0 then
          L.fill(fl, cx + x, cy + y + L.YOFF, 1, 1, (d + j > 0.78) and c2 or c)
        end
      end end
    end
    blob(1310, 124, 34, 7, "#6F716E", "#787A76", 71); blob(1160, 120, 20, 5, "#70726F", "#797B77", 72)
    blob(820, 118, 14, 4, "#707270", "#787A76", 73); blob(300, 128, 18, 4, "#707270", "#787A76", 74)
    blob(640, 124, 10, 3, "#2F3036", "#4A4D55", 75); blob(1050, 126, 9, 3, "#2F3036", "#4A4D55", 76)
    blob(500, 122, 22, 5, "#70726F", "#797B77", 77); blob(930, 130, 16, 4, "#70726F", "#797B77", 78)
    -- the painted aisle line (yellow, worn through in places), 2 ft off the wall racks
    for x = 0, W - 1 do
      if hash(x // 3, 1, 81) % 9 ~= 0 then
        L.fill(fl, x, 111 + L.YOFF, 1, 2, "#E3BD3C"); L.fill(fl, x, 113 + L.YOFF, 1, 1, "#B8942A")
      end
    end
    -- the loading dock hazard band in front of the overhead door
    for x = 1284, 1415 do
      for y = 93, 98 do
        local on = ((x + y) // 4) % 2 == 0
        L.fill(fl, x, y + L.YOFF, 1, 1, on and "#E3BD3C" or "#2A2A33")
      end
    end
    -- START and FINISH lines painted across the walkway (x 200 and x 1100)
    for y = 98, 156 do
      L.fill(fl, 197, y + L.YOFF, 1, 1, "#2E8B4A"); L.fill(fl, 205, y + L.YOFF, 1, 1, "#2E8B4A")
      for x = 198, 204 do
        if hash(x, y, 91) % 14 ~= 0 then L.fill(fl, x, y + L.YOFF, 1, 1, "#ECECE6") end
      end
      for x = 1096, 1107 do
        local on = ((x - 1096) // 4 + (y - 98) // 4) % 2 == 0
        if hash(x, y, 92) % 16 ~= 0 then L.fill(fl, x, y + L.YOFF, 1, 1, on and "#17121F" or "#ECECE6") end
      end
    end
    -- loose cables run across the floor near the e-waste corner and the dock (flat decals)
    local function cable(x, y, len, c, wob)
      for i = 0, len - 1 do
        L.fill(fl, x + i, y + L.YOFF + math.floor(math.sin(i * wob) * 2), 1, 1, c)
      end
    end
    cable(1150, 104, 60, "#F2862E", 0.21); cable(1160, 105, 52, "#2A2A33", 0.19); cable(1230, 103, 40, "#F2862E", 0.3)
    cable(700, 106, 30, "#2A2A33", 0.4); cable(1300, 101, 44, "#2A2A33", 0.25)
  end

  local function roof(set)
    local im = set.layer("Ceiling")
    local Wc = im.width
    L.fill(im, 0, 0, Wc, L.CEIL_H, "#98A1A6")
    for x = 0, Wc - 1 do
      local m = x % 4
      local d1 = m == 0 and "#6A737A" or (m == 2 and "#4F585F" or "#5C656C")
      local d2 = m == 0 and "#939CA1" or (m == 2 and "#7A838B" or "#868F95")
      local d3 = m == 0 and "#B4BCC0" or (m == 2 and "#8E979C" or "#A5AEB3")
      L.fill(im, x, 0, 1, 12, d1); L.fill(im, x, 12, 1, 28, d2); L.fill(im, x, 40, 1, 58, d3)
    end
    L.fill(im, 0, 12, Wc, 1, "#3A4148")
    -- purlins
    L.fill(im, 0, 8, Wc, 2, "#3E454C"); L.fill(im, 0, 26, Wc, 2, "#3E454C"); L.fill(im, 0, 27, Wc, 1, "#6A737A")
    -- steel truss gables: top chords, a bottom chord, a king post, diagonals
    for k = 0, 9 do
      local cx = 60 + 160 * k
      for x = cx - 80, cx do
        local y = 62 - math.floor((x - (cx - 80)) * 46 / 80)
        L.fill(im, x, y, 1, 3, "#3E454C"); L.fill(im, x, y - 1, 1, 1, "#6A737A")
        local x2 = 2 * cx - x
        L.fill(im, x2, y, 1, 3, "#3E454C"); L.fill(im, x2, y - 1, 1, 1, "#5C646C")
      end
      L.fill(im, cx - 80, 62, 161, 3, "#3E454C"); L.fill(im, cx - 80, 62, 161, 1, "#6A737A")
      L.fill(im, cx - 1, 16, 3, 46, "#3E454C"); L.fill(im, cx - 1, 16, 1, 46, "#5C646C")
      for i = 0, 40 do
        local y = 62 - math.floor(i * 23 / 40)
        L.fill(im, cx - i, y, 1, 2, "#4A525A"); L.fill(im, cx + i, y, 1, 2, "#4A525A")
      end
      L.fill(im, cx - 41, 39, 2, 23, "#4A525A"); L.fill(im, cx + 40, 39, 2, 23, "#4A525A")
      L.fill(im, cx - 3, 14, 7, 3, "#2A3036")                          -- the gusset at the ridge
    end
    -- hanging high-bay lights (lamp 6 is the flickering one: it is drawn dead here, fx kind flicker_lamp lights it)
    for k = 0, 8 do
      local cx = 60 + 160 * k
      local dead = (k == 5)
      L.fill(im, cx, 65, 1, 8, OUT)
      for r = 0, 6 do
        local hw = 3 + r
        L.fill(im, cx - hw, 73 + r, hw * 2 + 1, 1, r < 2 and "#D4DADC" or "#B4BCC0")
        L.fill(im, cx + hw - 1, 73 + r, 2, 1, "#7A838B")
      end
      L.fill(im, cx - 9, 80, 19, 1, "#2A2A33")
      L.fill(im, cx - 6, 81, 13, 2, dead and "#5A5A50" or "#FFF3C0")
      if not dead then
        for y = 83, 99 do
          local hw = 7 + math.floor((y - 83) * 0.9)
          for x = cx - hw, cx + hw do
            local m = x % 4
            L.fill(im, x, y, 1, 1, m == 0 and "#C4CCD0" or (m == 2 and "#A4ADB2" or "#B4BCC0"))
          end
        end
      end
    end
    L.fill(im, 0, 98, Wc, 2, "#4A525A")
    L.fill(im, 0, 0, 6, L.CEIL_H, "#4A525A"); L.fill(im, 1, 0, 1, L.CEIL_H, "#6A737A")
    L.fill(im, Wc - 6, 0, 6, L.CEIL_H, "#4A525A"); L.fill(im, Wc - 1, 0, 1, L.CEIL_H, "#2A3036")
  end

  builders.warehouse = {W = W, H = 128, post = roof, fn = function(s)
    wallLayer(s)
    floorLayer(s)
    storageRoom(s)
    -- the dock door frame and the opening (the door itself is a separate sprite: overhead_door)
    local wl = s.layer("Wall")
    F(wl, 1281, 4, 134, 8, "#7A838B"); F(wl, 1281, 4, 134, 1, "#A8B0B4"); F(wl, 1281, 11, 134, 1, "#4A525A")   -- the housing box
    F(wl, 1284, 12, 3, 78, "#4A525A"); F(wl, 1410, 12, 3, 78, "#4A525A")                                         -- the tracks
    F(wl, 1287, 12, 123, 78, "#BFD8E6"); F(wl, 1287, 60, 123, 30, "#9A9F9A"); F(wl, 1287, 58, 123, 2, "#6A6E6A")
    F(wl, 1296, 40, 40, 20, "#7FA0B8"); F(wl, 1350, 30, 30, 30, "#7FA0B8")

    -- wall decor
    local D = "Decor"
    s.put(D, P.timeClock(), 56, 44)
    s.put(D, P.poster(1), 86, 44); s.put(D, P.poster(2), 104, 44); s.put(D, P.poster(3), 122, 44)
    s.put(D, P.splitAc(), 90, 27)
    s.put(D, banner("START", 2, 70, "#2E8B4A", "#F2F2EA", "#F2F2EA"), 165, 28)
    s.put(D, banner("FINISH", 2, 72, "#ECECE6", "#17121F", "#17121F"), 1064, 28)
    s.put(D, P.partnerBanner(), 296, 30)
    s.put(D, P.blueCoil(), 362, 44)
    s.put(D, P.splitAc(), 612, 20)
    s.put(D, P.extinguisher(), 752, 58)
    s.put(D, P.poster(2), 876, 38)
    s.put(D, P.signCard("E-WASTE", 36), 1140, 30)
    s.put(D, P.signCard("RECYCLE", 36), 1182, 34)
    s.put(D, P.poster(1), 1240, 36)
    s.put(D, P.dockLight(), 1417, 30)
    s.put(D, P.cableRun(), 1040, 100)
    s.put("Doors", P.slabDoor("#7B828F", "#646B77", "#97A0AD", "lever"), 4, 18)    -- steel door back to the network closet

    -- pegboard over the bench, a plain one with tool shadows
    local peg = L.piece(88, 26, function(R)
      R(0, 0, 88, 26, "#C9A06A"); for y = 2, 24, 4 do for x = 2, 86, 4 do R(x, y, 1, 1, "#94683A") end end
      R(6, 4, 3, 14, "#8A8F9A"); R(14, 6, 10, 3, "#C23B2E"); R(14, 10, 12, 2, "#8A8F9A"); R(32, 3, 8, 8, "#2F78C8"); R(44, 6, 2, 14, "#E0B040")
      R(52, 4, 14, 3, "#2A2A33"); R(54, 9, 10, 2, "#8A8F9A"); R(72, 5, 10, 10, "#C9C6B8"); R(2, 21, 84, 2, "#8E6E40")
    end)
    s.put(D, peg, 896, 36)

    -- loaded racking, the cage, boxes on the floor
    local RK = "Racking"
    s.put(RK, P.rackBay(1), 378, 28); s.put(RK, P.rackBay(2), 490, 28)
    s.put(RK, P.partsCage(), 606, 34)
    s.put(RK, P.bench(), 890, 70)
    s.put(RK, P.xmasTree(), 1446, 54)
    s.put(RK, P.ewasteTowers(), 1120, 44); s.put(RK, P.ewasteMixed(), 1172, 72)
    s.put(RK, P.gaylord(), 1230, 68); s.put(RK, P.fedupBox(), 1264, 80)
    local pile = L.piece(26, 22, function(R) cardboard(R, 0, 8, 26, 14, 1); cardboard(R, 3, 0, 18, 8, 2); R(9, 12, 8, 1, "#ECECE6") end)
    s.put(RK, pile, 1068, 86); s.put(RK, pile, 1352, 86)

    -- y-sorted props (sprites in Godot): the sort line is the base of the object
    s.putS("Props", P.overheadDoor(), 1287, 12, 92, "overhead_door")
    s.putS("Props", P.chairRack(), 132, 54, 108, "chair_rack")
    s.putS("Props", P.vending(), 266, 64, 108, "vending_machine")
    s.putS("Props", P.palletStack(), 314, 82, 108, "pallet_stack")
    s.putS("Props", P.floorFan(), 354, 74, 108, "floor_fan")
    s.putS("Props", P.palletJack(), 726, 90, 108, "pallet_jack")
    s.putS("Props", P.dartPanel(), 1000, 42, 108, "dart_panel")
    s.putS("Props", P.bbqGrill(), 1310, 72, 109, "bbq_grill")
    -- the loose props the chair race will use as obstacles (parked off the course, against the wall)
    s.putS("Loose", P.cone(), 254, 92, 108, "race_cone")
    s.putS("Loose", P.trashCan(), 294, 86, 108, "race_trash_can")
    s.putS("Loose", P.wetSign(), 710, 88, 108, "race_wet_sign")
    s.putS("Loose", P.smallPallet(), 774, 99, 108, "race_pallet_small")
    s.putS("Loose", P.oilPuddle(), 806, 99, 103, "race_oil_puddle")
    s.putS("Loose", P.boxStack(), 862, 80, 108, "race_box_stack")
    if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 220, 56) end
  end}
end
