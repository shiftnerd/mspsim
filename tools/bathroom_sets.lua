-- The two restrooms behind the kitchenette doors (R22): single-occupancy and unisex, 128 px wide each, and NOT recolours.
-- Loaded by build_sets.lua:  dofile(TOOLS .. "bathroom_sets.lua")(L, builders)
--   bathroom_1 (left door)  : the old one. Cream wall tile with a dark border band, a checkered floor, a cracked mirror, an
--                             almond pedestal sink with a rust stain, a hand-written OUT OF PAPER sign, a wall plunger, an old
--                             paper towel dispenser and a fluorescent bar over the mirror that flickers (fx `flicker_lamp`).
--                             The door is on the left (art x 4), the toilet on the right.
--   bathroom_2 (right door) : the remodel. Grey subway tile over a teal wainscot, a vanity with a cabinet and a bowl sink, a
--                             frameless mirror, a framed TEAMWORK poster, a hand dryer, a plant, an air freshener and a pedal bin.
--                             The door is on the RIGHT (art x 90), the toilet on the left.
-- Both are laid out in the old 0..128 room band (floor line y 90 under the pieces, FLOOR_Y 118 for the feet). The fixtures keep
-- the geometry the `sink` / `toilet` fx expect: water falls at x + 8 from y + 3 to y + 7, the flush handle sits at (10, 2).
-- P.bathPlate(text) is the occupancy plate the kitchenette puts over each bath door (fx `occupied_N` draws a red / green dot in
-- the 2 x 2 socket at content (30, 3)).
return function(L, builders)
  local P = L.P
  local OUT = "#17121F"
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

  -- 3x5 pixel font (the game UI font)
  local G = {
    A = {"XXX","X.X","XXX","X.X","X.X"}, B = {"XX.","X.X","XX.","X.X","XX."}, C = {".XX","X..","X..","X..",".XX"},
    D = {"XX.","X.X","X.X","X.X","XX."}, E = {"XXX","X..","XX.","X..","XXX"}, F = {"XXX","X..","XX.","X..","X.."},
    G = {".XX","X..","X.X","X.X",".XX"}, H = {"X.X","X.X","XXX","X.X","X.X"}, I = {"XXX",".X.",".X.",".X.","XXX"},
    K = {"X.X","X.X","XX.","X.X","X.X"}, L = {"X..","X..","X..","X..","XXX"},
    M = {"X.X","XXX","XXX","X.X","X.X"}, N = {"XXX","X.X","X.X","X.X","X.X"}, O = {".X.","X.X","X.X","X.X",".X."},
    P = {"XX.","X.X","XX.","X..","X.."}, R = {"XX.","X.X","XX.","X.X","X.X"},
    S = {".XX","X..",".X.","..X","XX."}, T = {"XXX",".X.",".X.",".X.",".X."}, U = {"X.X","X.X","X.X","X.X","XXX"},
    W = {"X.X","X.X","XXX","XXX","X.X"},
    ["1"] = {".X.","XX.",".X.",".X.","XXX"}, ["2"] = {"XX.","..X",".X.","X..","XXX"}, [" "] = {"...","...","...","...","..."},
  }
  local function textW(str, sc) return #str * 4 * sc - sc end
  local function drawText(R, str, x, y, sc, c, jitter)
    for i = 1, #str do
      local rows = G[str:sub(i, i)] or G[" "]
      local dy = jitter and (hash(i, #str, 5) % 2) or 0       -- a hand-written line wobbles
      for r = 1, 5 do for k = 1, 3 do
        if rows[r]:sub(k, k) == "X" then R(x + (i - 1) * 4 * sc + (k - 1) * sc, y + dy + (r - 1) * sc, sc, sc, c) end
      end end
    end
  end

  -- the plate over a bath door in the kitchenette: label, plus a dark socket for the occupied light
  function P.bathPlate(text)
    local w = math.max(34, textW(text, 1) + 4)
    return L.piece(w, 8, function(R)
      R(0, 0, w, 8, "#2A2D36"); R(1, 1, w - 2, 6, "#14566E")
      drawText(R, text, 3, 1, 1, "#FFFFFF")
      R(w - 5, 2, 4, 4, "#0B2E3C")
    end)
  end

  -- ---------------------------------------------------------------- bathroom 1: old and shabby
  local function tileWall1(im)
    F(im, 0, 0, 400, 84, "#E5DCBF")
    for y = 0, 83 do
      for x = -L.XOFF, 400 - L.XOFF do
        local tx, ty = x % 8, y % 8
        if tx == 0 or ty == 0 then px(im, x, y, "#C7BD9A")
        elseif tx == 1 and ty == 1 then px(im, x, y, "#F2ECD6")
        elseif hash(x // 8, y // 8, 3) % 9 == 0 and tx == 4 and ty == 4 then px(im, x, y, "#D6CCA8") end
      end
    end
    F(im, 0, 58, 400, 6, "#35504A"); F(im, 0, 58, 400, 1, "#4F7068"); F(im, 0, 63, 400, 1, "#243A36")
    F(im, 0, 57, 400, 1, "#B8AE8A"); F(im, 0, 64, 400, 1, "#B8AE8A")
    -- grime where hands and water go: gradient of dirty tiles along the floor and under the border band
    for x = -L.XOFF, 400 - L.XOFF do
      for y = 76, 83 do if hash(x, y, 9) % (y - 70) == 0 then px(im, x, y, "#BDB28C") end end
    end
    -- the rust stain under the tap and the one from the old pipe behind the toilet
    for dy = 0, 12 do
      local len = 12 - dy
      px(im, 73, 66 + dy, "#B5683A"); px(im, 74, 66 + dy, "#9C5530")
      if dy < 7 then px(im, 72, 66 + dy, "#C98050"); px(im, 75, 66 + dy, "#C98050") end
      if hash(dy, 4, 4) % 3 == 0 then px(im, 74 + (dy % 2), 66 + dy, "#7E4426") end
      if len < 0 then break end
    end
    for dy = 0, 13 do px(im, 104, 44 + dy, "#B5683A"); px(im, 105, 44 + dy, "#9C5530"); if dy % 3 == 0 then px(im, 103, 44 + dy, "#C98050") end end
    for i = 0, 5 do px(im, 100 + i, 57, "#C98050") end
  end

  local function floorChecker(im)
    local y0 = 90
    F(im, 0, y0, 400, 330, "#D8D1B6")
    for y = y0, 330 do
      for x = -L.XOFF, 400 - L.XOFF do
        if ((x // 10) + (y // 10)) % 2 == 0 then px(im, x, y, "#BFB89C") end
        local h = hash(x, y, 21)
        if h % 29 == 0 then px(im, x, y, "#A9A286") end
      end
    end
    F(im, 0, y0, 400, 2, "#8E8870")
  end

  local function mirrorCracked()
    return L.piece(18, 22, function(R, PX)
      R(0, 0, 18, 22, "#8E8A7C"); R(0, 0, 18, 1, "#A8A494")
      R(2, 2, 14, 18, "#B8CDD2"); R(3, 3, 2, 7, "#D4E4E8"); R(2, 17, 14, 3, "#9DB2B8")
      for _, p in ipairs({{11, 2}, {10, 3}, {10, 4}, {9, 5}, {9, 6}, {8, 7}, {7, 8}, {7, 9}, {6, 10}, {7, 11}, {8, 12}, {8, 13}, {9, 14},
                          {9, 15}, {10, 16}, {10, 17}, {11, 18}, {12, 8}, {11, 9}, {10, 10}, {13, 10}, {12, 11}, {6, 14}, {5, 15}}) do
        PX(p[1], p[2], "#5F6F76")
      end
      R(13, 2, 3, 3, "#8E8A7C"); PX(13, 5, "#8E8A7C")                 -- a chipped corner
      R(2, 10, 2, 1, "#D9C9A0"); PX(2, 11, "#B5683A")                 -- old tape and a rust fleck
    end)
  end

  local function pedestal1()
    return L.piece(16, 26, function(R)
      R(7, 0, 2, 4, "#A8A08C"); R(7, 0, 6, 2, "#A8A08C"); R(3, 2, 3, 2, "#B5683A"); R(11, 3, 2, 1, "#B5683A")   -- two taps, one rusty
      L.box(R, 0, 4, 16, 6, "#E8DFC6", "#F6F0DC", "#C9BFA2")
      R(1, 5, 14, 1, "#F6F0DC"); R(7, 7, 3, 2, "#8E8870"); R(4, 8, 2, 1, "#B5683A")
      R(5, 10, 6, 16, "#DDD3B8"); R(5, 10, 1, 16, "#EEE6CE"); R(10, 10, 1, 16, "#C2B898")
      R(3, 24, 10, 2, "#C9BFA2")
    end)
  end

  local function toiletC(base, hi, sh, stain)
    return L.piece(16, 24, function(R)
      L.box(R, 2, 0, 12, 10, base, hi, sh)
      R(10, 2, 3, 2, "#8E939E")
      L.box(R, 0, 10, 16, 8, base, hi, sh)
      R(3, 18, 10, 6, sh)
      if stain then R(4, 12, 2, 5, stain); R(11, 13, 1, 4, stain) end
    end)
  end

  local function towelDispenser()
    return L.piece(12, 17, function(R)
      R(0, 0, 12, 14, "#B7BAB2"); R(0, 0, 12, 1, "#D0D3CB"); R(11, 0, 1, 14, "#8E9189"); R(0, 13, 12, 1, "#8E9189")
      R(3, 3, 6, 4, "#9FA39B"); R(5, 9, 2, 2, "#6A6D66")                 -- window and lock
      R(2, 13, 8, 4, "#EFEEE4"); R(2, 15, 8, 1, "#CFCDBF"); R(3, 16, 2, 1, "#EFEEE4")   -- the towel hanging out
      R(1, 11, 3, 1, "#B5683A")
    end)
  end

  local function handSign()
    return L.piece(27, 15, function(R)
      R(0, 0, 27, 15, "#F2EFE0"); R(26, 1, 1, 14, "#D9D5C0"); R(1, 14, 26, 1, "#D9D5C0")
      drawText(R, "OUT OF", 2, 1, 1, "#2C3E8C", true)
      drawText(R, "PAPER", 4, 7, 1, "#B02A2A", true)
      R(0, 0, 4, 2, "#D8C27A"); R(23, 0, 4, 2, "#D8C27A")                -- masking tape
    end)
  end

  local function plunger()
    return L.piece(8, 26, function(R)
      R(3, 0, 2, 20, "#B98A52"); R(3, 0, 1, 20, "#D4A96E")
      R(0, 18, 8, 4, "#B0312C"); R(1, 22, 6, 2, "#B0312C"); R(0, 18, 8, 1, "#D45650"); R(1, 23, 6, 1, "#7E211E")
    end)
  end

  local function emptyHolder()
    return L.piece(9, 8, function(R)
      R(0, 0, 9, 2, "#9FA39B"); R(0, 0, 2, 8, "#9FA39B")
      R(3, 3, 6, 4, "#C9A878"); R(3, 3, 6, 1, "#E0C79A"); R(5, 4, 2, 2, "#8A6A3E")   -- the empty cardboard tube
    end)
  end

  local function barLight()
    return L.piece(25, 6, function(R)
      R(0, 0, 25, 6, "#6E6E68"); R(0, 5, 25, 1, "#4E4E48")
      R(2, 1, 21, 3, "#B3B09C")
      R(6, 2, 13, 1, "#8A8777"); R(6, 3, 13, 1, "#9B9886")                -- the tube; fx `flicker_lamp` lights it
    end)
  end

  builders.bathroom_1 = {W = 128, H = 128, fn = function(s)
    local W = 128
    L.wall(s.layer("Wall"), W, "#E5DCBF", "#C7BD9A"); tileWall1(s.layer("Wall"))
    L.tiles(s.layer("Floor"), W); floorChecker(s.layer("Floor"))
    s.put("Doors", P.slabDoor("#C9A06C", "#B08652", "#DDB680", "black"), 4, 18)
    s.put("Fixtures", barLight(), 63, 22)
    s.put("Mirror", mirrorCracked(), 66, 32)
    s.put("Sink", pedestal1(), 65, 64)
    s.put("Toilet", toiletC("#E8DFC6", "#F6F0DC", "#C9BFA2", "#B5A98A"), 100, 66)
    s.put("Wall", towelDispenser(), 50, 40)
    s.put("Wall", handSign(), 92, 34)
    s.put("Wall", emptyHolder(), 88, 70)
    s.put("Plunger", plunger(), 118, 64)
  end}

  -- ---------------------------------------------------------------- bathroom 2: the remodel
  local function tileWall2(im)
    F(im, 0, 0, 400, 84, "#C4CED1")
    for y = 0, 45 do                                                         -- grey subway tile, running bond
      for x = -L.XOFF, 400 - L.XOFF do
        local row = y // 6
        local sx = (x + (row % 2) * 8) % 16
        if y % 6 == 0 or sx == 0 then px(im, x, y, "#A7B3B7")
        elseif y % 6 == 1 and sx > 0 then px(im, x, y, "#D6DEE0") end
      end
    end
    F(im, 0, 46, 400, 5, "#1F7C80"); F(im, 0, 46, 400, 1, "#46A9A8"); F(im, 0, 50, 400, 1, "#14575A")   -- the teal accent band
    F(im, 0, 51, 400, 33, "#3A8C93")                                         -- teal wainscot in 10 px squares
    for y = 51, 83 do
      for x = -L.XOFF, 400 - L.XOFF do
        local tx, ty = x % 10, (y - 51) % 10
        if tx == 0 or ty == 0 then px(im, x, y, "#2C6E75")
        elseif tx == 1 and ty == 1 then px(im, x, y, "#59A7AC") end
      end
    end
  end

  local function floorGrey(im)
    local y0 = 90
    F(im, 0, y0, 400, 330, "#7E8C92")
    for y = y0, 330 do
      for x = -L.XOFF, 400 - L.XOFF do
        if x % 24 == 0 or (y - y0) % 24 == 0 then px(im, x, y, "#9BA8AD")
        elseif x % 24 == 1 or (y - y0) % 24 == 1 then px(im, x, y, "#6C797F")
        elseif hash(x, y, 31) % 41 == 0 then px(im, x, y, "#8A989E") end
      end
    end
    F(im, 0, y0, 400, 2, "#5E6B71")
  end

  local function vanity()
    return L.piece(30, 30, function(R, PX)
      R(14, 0, 2, 6, "#C8CCD4"); R(14, 0, 5, 2, "#C8CCD4"); R(14, 0, 1, 6, "#EEF0F4")           -- faucet; the water falls at x 15
      R(8, 5, 14, 6, "#F2F4F6"); R(8, 5, 14, 1, "#FFFFFF"); R(9, 6, 12, 2, "#CBD6DB"); R(8, 10, 14, 1, "#C4CCD0")   -- the vessel bowl
      L.box(R, 0, 11, 30, 3, "#E4E9EB", "#FFFFFF", "#AEB6BA")                                      -- counter top
      R(0, 14, 30, 16, "#2F6E75"); R(29, 14, 1, 16, "#1F5258"); R(0, 29, 30, 1, "#1F5258")        -- cabinet
      R(14, 15, 1, 14, "#1F5258"); R(1, 16, 12, 12, "#3A8C93"); R(16, 16, 13, 12, "#3A8C93")
      R(1, 16, 12, 1, "#59A7AC"); R(16, 16, 13, 1, "#59A7AC")
      R(11, 19, 1, 4, "#D6DADF"); R(17, 19, 1, 4, "#D6DADF")                                      -- the pulls
    end)
  end

  local function mirrorFrameless()
    return L.piece(26, 24, function(R, PX)
      R(0, 0, 26, 24, "#AEBDC3"); R(1, 1, 24, 22, "#D6E8EE")
      for i = 0, 7 do PX(3 + i, 12 - i, "#F4FBFD"); PX(4 + i, 12 - i, "#EAF6FA") end             -- a shine
      for i = 0, 4 do PX(12 + i, 20 - i, "#F4FBFD") end
    end)
  end

  local function poster()
    return L.piece(36, 24, function(R, PX)
      R(0, 0, 36, 24, "#2A2D36"); R(1, 1, 34, 22, "#EEF0F2")
      R(2, 2, 32, 14, "#8FC4E0"); R(2, 12, 32, 4, "#3E6E94")
      R(6, 8, 9, 8, "#2E4B6B"); R(9, 6, 4, 2, "#2E4B6B"); R(11, 5, 1, 1, "#FFFFFF"); R(18, 10, 12, 6, "#35597C")
      R(22, 6, 5, 5, "#F6D860"); R(23, 7, 3, 3, "#FFF0A0")
      drawText(R, "TEAMWORK", 3, 17, 1, "#1F7C80")
    end)
  end

  local function handDryer()
    return L.piece(10, 15, function(R)
      R(0, 0, 10, 11, "#E8EAEC"); R(0, 0, 10, 1, "#FFFFFF"); R(9, 0, 1, 11, "#B9BEC4"); R(0, 10, 10, 1, "#B9BEC4")
      R(2, 2, 4, 1, "#9AA0A6"); R(7, 2, 2, 2, "#2E8B4A")
      R(2, 11, 6, 4, "#8E939E"); R(3, 12, 4, 2, "#4A4F5A")                                         -- the nozzle
    end)
  end

  local function airFreshener()
    return L.piece(6, 10, function(R)
      R(0, 2, 6, 8, "#F2F2EA"); R(5, 2, 1, 8, "#D2D2C8"); R(1, 0, 4, 2, "#3FA36B"); R(1, 5, 4, 3, "#B8E0C8"); R(2, 3, 1, 1, "#E04040")
    end)
  end

  local function bin()
    return L.piece(11, 16, function(R)
      R(0, 0, 11, 3, "#4A4F5A"); R(1, 1, 9, 1, "#6A707C")
      R(1, 3, 9, 12, "#AAB1BA"); R(9, 3, 1, 12, "#868E98"); R(2, 3, 1, 12, "#C8CED6")
      R(3, 15, 5, 1, "#4A4F5A"); R(4, 9, 3, 2, "#868E98")
    end)
  end

  builders.bathroom_2 = {W = 128, H = 128, fn = function(s)
    local W = 128
    L.wall(s.layer("Wall"), W, "#C4CED1", "#A7B3B7"); tileWall2(s.layer("Wall"))
    L.tiles(s.layer("Floor"), W); floorGrey(s.layer("Floor"))
    s.put("Doors", P.slabDoor("#5E8E94", "#4A767C", "#7AAAB0", "lever"), 90, 18)
    s.put("Poster", poster(), 10, 22)
    s.put("Plant", P.floorPlant(), 2, 60)
    s.put("Toilet", toiletC("#F6F7F8", "#FFFFFF", "#D4D8DB", nil), 20, 66)
    s.put("Wall", airFreshener(), 44, 60)
    s.put("Bin", bin(), 40, 74)
    s.put("Mirror", mirrorFrameless(), 53, 28)
    s.put("Sink", vanity(), 52, 60)
    s.put("Wall", handDryer(), 83, 50)
  end}
end
