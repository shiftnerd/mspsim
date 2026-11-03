-- Client sites: the offices a tech visits onsite (and Vic / the owner visits for check-ins and pitches).
-- Loaded by build_sets.lua:  dofile(TOOLS .. "client_sets.lua")(L, builders)
-- Six site types (dental, law, vet, architect, realty, trailers), each built twice from the same layout with a SKIN
-- (colours + the name on the sign): `a` and `b`, so a prospect can look like a different business from the client.
-- Set names: site_<type>_<skin id>, for example site_vet_a, site_vet_b.
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
    ["&"] = {".X.","X.X",".XX","X.X",".XX"}, ["$"] = {".XX","XX.",".X.",".XX","XX."}, ["/"] = {"..X","..X",".X.","X..","X.."},
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


  function P.doorPlate(text)
    local w = math.max(34, textW(text, 1) + 4)       -- a long word widens the plate
    return L.piece(w, 8, function(R)
      R(0, 0, w, 8, "#2A2D36"); R(1, 1, w - 2, 6, "#14566E"); centred(R, text, w // 2, 1, 1, "#FFFFFF")
    end)
  end
  local function plateAt(s, text, x)              -- a plate centred on the 34 px wide door at x
    s.put("Plate", P.doorPlate(text), x - (math.max(34, textW(text, 1) + 4) - 34) // 2, 9)
  end

  -- the plates say what is behind each door, per business (the first is the way out to the van)
  local PLATES = {
    dental  = {"ENTRY", "DENTIST", "SERVER"},
    law     = {"LOBBY", "PARTNER", "SERVER"},
    vet     = {"LOBBY", "DOCTOR", "SERVER"},
    arch    = {"ENTRY", "PRINCIPAL", "SERVER"},
    realty  = {"ENTRY", "BROKER", "SERVER"},
    trailer = {"OFFICE", "FOREMAN", "SERVER"},
  }
  local EXAM_PLATES = {dental = {"CHAIR 1", "CHAIR 2"}, vet = {"EXAM 1", "EXAM 2"}}

  -- the entry door is on the left (spawn from_van), the door to the IT closet on the right
  local function doorsMain(s, S, kind)
    local pl = PLATES[kind]
    s.put("Doors", P.slabDoor("#6A4A2E", "#523626", "#8A6A44", "lever"), 4, 18)
    plateAt(s, pl[1], 4)
    s.put("Doors", P.slabDoor("#7B828F", "#646B77", "#97A0AD", "lever"), 284, 18)
    plateAt(s, pl[3], 284)
    s.put("Doors", P.slabDoor("#5A3A22", "#3E281A", "#7A5030", "lever"), 44, 18)
    plateAt(s, pl[2], 44)
  end

  -- ---------------------------------------------------------------- skins: same layout, other colours and name
  local SKINS = {
    dental = {
      a = {id = "a", name = "ACME DENTAL GROUP", short = "ACME DENTAL", wall = "#CFE8EE", trim = "#B4D4DC", accent = "#2E9AB8", floor = "#D8D4C8", floor2 = "#C4BFB0", logo = "#2E9AB8"},
      b = {id = "b", name = "BRIGHT SMILES DENTAL", short = "BRIGHT SMILES", wall = "#F2E6EE", trim = "#E0CCDA", accent = "#B8508A", floor = "#E4DDD0", floor2 = "#CFC7B8", logo = "#B8508A"},
    },
    law = {
      a = {id = "a", name = "HOOT AND HOLLER LAW", short = "HOOT & HOLLER", wall = "#6A4A38", trim = "#523626", accent = "#C8A04A", floor = "#3A2A3E", floor2 = "#2E2032", logo = "#C8A04A"},
      b = {id = "b", name = "SPENCE AND ROE LLP", short = "SPENCE & ROE", wall = "#3E4A5E", trim = "#2E384A", accent = "#D8D0B0", floor = "#4A3A30", floor2 = "#3C2E26", logo = "#D8D0B0"},
    },
    vet = {
      a = {id = "a", name = "PAWS AND CLAWS VETERINARY", short = "PAWS AND CLAWS", wall = "#CDE6C8", trim = "#B2D0AC", accent = "#3E8E4A", floor = "#D8D2BC", floor2 = "#C4BEA6", logo = "#3E8E4A"},
      b = {id = "b", name = "HAPPY TAILS VET", wall = "#F6E2C0", trim = "#E4CA9E", accent = "#E07A2E", floor = "#CFE0E6", floor2 = "#B8CCD4", logo = "#E07A2E"},
    },
    arch = {
      a = {id = "a", name = "LINDQVIST AND MOSS ARCHITECTS", short = "LINDQVIST & MOSS", wall = "#E8E6E0", trim = "#D2CFC6", accent = "#2A2D36", floor = "#8A8F98", floor2 = "#767B84", logo = "#2A2D36"},
      b = {id = "b", name = "NORTHLIGHT DESIGN", wall = "#DCE4D4", trim = "#C4D0B8", accent = "#B8503E", floor = "#A89478", floor2 = "#94805F", logo = "#B8503E"},
    },
    realty = {
      a = {id = "a", name = "BRIGHTSIDE REALTY", wall = "#F4ECD2", trim = "#E4D8B0", accent = "#E0A030", floor = "#B88A5A", floor2 = "#A67848", logo = "#E0A030"},
      b = {id = "b", name = "KEYSTONE HOMES", wall = "#DCE6F2", trim = "#C2D2E6", accent = "#2E5AA8", floor = "#8E6A48", floor2 = "#7A5838", logo = "#2E5AA8"},
    },
    trailer = {
      a = {id = "a", name = "IRON MULE DEMOLITION", short = "IRON MULE DEMO", wall = "#B8A27A", trim = "#9C8760", accent = "#E0A030", floor = "#7A7468", floor2 = "#68625A", logo = "#E0A030"},
      b = {id = "b", name = "BLACKROCK WRECKING", wall = "#A8B0A0", trim = "#8E9686", accent = "#D2452E", floor = "#6E6A62", floor2 = "#5C5852", logo = "#D2452E"},
    },
  }

  -- ---------------------------------------------------------------- backgrounds
  local function wallAndFloor(s, S, kind, W)
    local wall = s.layer("Wall")
    F(wall, 0, 0, W, 84, S.wall)
    F(wall, 0, 0, W, 3, S.accent)
    if kind ~= "trailer" then
      F(wall, 0, 50, W, 2, S.accent); F(wall, 0, 52, W, 32, S.trim)
      for x = 0, W - 1, 22 do F(wall, x + 2, 56, 18, 22, S.wall); F(wall, x + 2, 56, 18, 1, "#FFFFFF") end
    else
      for x = 0, W - 1, 8 do F(wall, x, 3, 1, 81, S.trim) end                       -- prefab panel seams
      F(wall, 0, 60, W, 24, S.trim); F(wall, 0, 60, W, 2, S.accent)
    end
    F(wall, 0, 84, W, 6, OUT)
    local floor = s.layer("Floor")
    local y0 = 90 + L.YOFF
    L.fill(floor, 0, y0, floor.width, floor.height - y0, S.floor)
    for y = y0, floor.height - 1 do for x = 0, floor.width - 1 do
      if kind == "tile" or kind == "vet" then
        if (x % 24 == 0) or ((y - y0) % 24 == 0) then L.fill(floor, x, y, 1, 1, S.floor2) end
      elseif hash(x, y, 5) % 19 == 0 then L.fill(floor, x, y, 1, 1, S.floor2) end
    end end
    L.fill(floor, 0, y0, floor.width, 2, S.floor2)
  end

  -- ---------------------------------------------------------------- shared pieces (skin aware)
  function P.siteSign(S, w)
    w = math.max(w, textW(S.name, 1) + 8)
    return L.piece(w, 14, function(R)
      R(0, 0, w, 14, OUT); R(1, 1, w - 2, 12, S.accent); R(1, 1, w - 2, 1, "#FFFFFF")
      centred(R, S.name, w // 2, 4, 1, "#FFFFFF")
    end)
  end

  function P.recepDesk(S, w, glass, label)
    return L.piece(w, 36, function(R)
      L.box(R, 0, 0, w, 5, "#F2EFE6", "#FFFFFF", "#C9C3B2")
      R(0, 5, w, 31, S.accent); R(0, 5, w, 2, "#FFFFFF"); R(0, 33, w, 3, S.trim)
      R(4, 11, w - 8, 18, S.trim)
      centred(R, label or (S.short or S.name):sub(1, 14), w // 2, 17, 1, "#FFFFFF")
      if glass then R(0, -22, w, 22, "#BFE4F0"); R(1, -21, w - 2, 20, "#E4F6FC"); R(0, -22, w, 2, "#8E939E"); R(w // 2, -21, 2, 20, "#8E939E") end
      L.box(R, w - 22, -7, 12, 7, "#2E3138", "#4A4F5A", "#1C1E24")
      R(6, -4, 7, 4, "#F2F2EA")
    end)
  end

  function P.waitChairs(S)
    return L.piece(60, 26, function(R)
      for i = 0, 2 do
        local x = i * 20
        R(x, 0, 18, 14, S.accent); R(x + 1, 1, 16, 12, S.trim); R(x + 2, 2, 14, 5, "#FFFFFF")
        R(x, 14, 18, 6, S.accent); R(x + 2, 20, 2, 6, "#6A6F7A"); R(x + 14, 20, 2, 6, "#6A6F7A")
      end
    end)
  end

  function P.wallCabinet(S)                    -- the network cabinet on the wall: switch, patch panel, a router with LEDs
    return L.piece(28, 40, function(R)
      R(0, 0, 28, 40, "#4A4F5A"); R(1, 1, 26, 38, "#2A2D36")
      R(3, 4, 22, 6, "#8E939E"); for i = 0, 7 do R(4 + i * 2 + (i // 2), 6, 1, 2, "#17121F") end
      R(3, 13, 22, 8, "#14566E"); for i = 0, 5 do R(5 + i * 3, 15, 2, 2, ({"#4CFF7A", "#F2C94C", "#4CFF7A"})[i % 3 + 1]) end
      R(3, 24, 22, 6, "#3A3F4A"); R(5, 26, 4, 2, "#E04E4E"); R(11, 26, 2, 2, "#4CFF7A"); R(15, 26, 2, 2, "#4CFF7A")
      R(3, 33, 22, 4, "#3A3F4A")
    end)
  end

  function P.serverTower()
    return L.piece(18, 32, function(R)
      L.box(R, 0, 0, 18, 32, "#3A3F4A", "#5A606C", "#22252E")
      R(3, 4, 12, 3, "#17121F"); R(3, 9, 12, 3, "#17121F"); R(4, 5, 3, 1, "#4CFF7A"); R(4, 10, 3, 1, "#F2C94C")
      R(3, 26, 4, 3, "#E04E4E")
    end)
  end

  function P.printerBox()
    return L.piece(26, 22, function(R)
      L.box(R, 0, 6, 26, 16, "#C9CDD6", "#E4E8F0", "#8E939E")
      R(3, 0, 20, 6, "#F2F2EA"); R(5, 2, 16, 1, "#C9C3B2")
      R(3, 11, 20, 3, "#2E3138"); R(19, 16, 3, 2, "#4CFF7A")
    end)
  end

  function P.drawerStack(S)
    return L.piece(22, 28, function(R)
      L.box(R, 0, 0, 22, 28, S.trim, "#FFFFFF", S.accent)
      for i = 0, 2 do R(2, 3 + i * 8, 18, 6, S.wall); R(9, 5 + i * 8, 4, 2, "#8E939E") end
    end)
  end

  -- ---------------------------------------------------------------- dental
  function P.dentalChair(S)
    return L.piece(64, 46, function(R)
      R(30, 2, 3, 22, "#8E939E"); R(18, 0, 22, 4, "#F2F2EA"); R(12, 0, 8, 6, "#FFF6B0")                    -- the lamp
      R(0, 26, 34, 8, S.accent); R(0, 26, 34, 2, "#FFFFFF")                                                 -- seat
      R(28, 18, 10, 18, S.accent); R(29, 19, 6, 6, "#FFFFFF")                                               -- backrest and headrest
      R(32, 36, 4, 8, "#6A6F7A"); R(20, 42, 24, 4, "#4A4F5A")
      R(46, 22, 16, 3, "#8E939E"); R(58, 25, 2, 12, "#8E939E"); R(52, 18, 10, 5, "#F2F2EA"); R(54, 19, 2, 3, "#C9CDD6")   -- the tray
    end)
  end

  function P.fishTank()
    return L.piece(44, 30, function(R)
      R(0, 0, 44, 30, "#6A6F7A"); R(2, 2, 40, 24, "#4FB8D8")
      for x = 3, 40, 3 do R(x, 22, 2, 3 + hash(x, 1, 1) % 2, "#2E7A3A") end
      R(5, 25, 34, 2, "#D8C898")
      R(10, 10, 5, 3, "#F2A02E"); R(9, 11, 1, 1, "#F2A02E"); R(28, 14, 5, 3, "#E04E4E"); R(33, 15, 1, 1, "#E04E4E")
      R(4, 3, 36, 1, "#9AE8F0")
    end)
  end

  builders_dental = function(S)
    return {W = 320, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "tile", 320)
      doorsMain(s, S, "dental")
      s.put("Sign", P.siteSign(S, 70), 90 - (math.max(70, textW(S.name, 1) + 8) - 70) // 2, 10)
      s.put("Door", P.slabDoor(S.accent, S.trim, "#FFFFFF", "lever"), 208, 18); plateAt(s, EXAM_PLATES.dental[1], 208)
      s.put("Door", P.slabDoor(S.accent, S.trim, "#FFFFFF", "lever"), 246, 18); plateAt(s, EXAM_PLATES.dental[2], 246)
      s.putS("Fish", P.fishTank(), 84, 52, 100, "fish_tank")
      s.putS("Reception", P.recepDesk(S, 80, true), 128, 72, 108, "recep_desk_dental_" .. S.id)
      s.putS("RecepPC", P.monitor(), 156, 56, 96, "monitor")
      s.putS("Plant", P.floorPlant(), 94, 78, 108, "plant_floor")
      s.putS("Waiting", P.waitChairs(S), 44, 84, 106, "wait_chairs_" .. S.id)
      s.put("Poster", P.toothPoster(S), 176, 24)
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
    end}
  end

  -- ---------------------------------------------------------------- law
  function P.lawBooks(S)
    return L.piece(46, 64, function(R)
      L.box(R, 0, 0, 46, 64, "#3A2616", "#5A3A22", "#241508")
      for row = 0, 3 do
        local y = 3 + row * 15
        R(2, y + 12, 42, 2, "#241508")
        local x = 3
        while x < 42 do
          local w = 2 + hash(x, row, 7) % 3
          local col = ({"#7A1E2A", "#1E3A6A", "#2E5A3A", "#6A4A2E", "#8A6A24"})[hash(x, row, 9) % 5 + 1]
          R(x, y + 1 + hash(x, row, 3) % 3, w, 11 - hash(x, row, 3) % 3, col)
          x = x + w + 1
        end
      end
    end)
  end

  function P.leatherChair()
    return L.piece(30, 28, function(R)
      R(2, 0, 26, 18, "#5A2A1E"); R(4, 2, 22, 12, "#7A3A28"); R(0, 10, 6, 14, "#5A2A1E"); R(24, 10, 6, 14, "#5A2A1E")
      R(4, 14, 22, 8, "#7A3A28"); R(5, 22, 3, 6, "#2A1B0E"); R(22, 22, 3, 6, "#2A1B0E")
      for x = 6, 22, 4 do R(x, 6, 1, 1, "#A8583C") end
    end)
  end

  function P.diploma(S)
    return L.piece(18, 22, function(R)
      R(0, 0, 18, 22, "#3A2616"); R(1, 1, 16, 20, "#F4EBD0"); R(3, 4, 12, 1, "#8A8A8A"); R(3, 7, 12, 1, "#8A8A8A"); R(3, 10, 8, 1, "#8A8A8A")
      disc(R, 13, 17, 2, S.accent)
    end)
  end

  function P.scalesStatue()
    return L.piece(14, 20, function(R)
      R(6, 4, 2, 12, "#C8A04A"); R(1, 4, 12, 1, "#C8A04A"); R(0, 5, 4, 2, "#C8A04A"); R(10, 5, 4, 2, "#C8A04A"); R(3, 16, 8, 3, "#8A6A24")
    end)
  end

  builders_law = function(S)
    return {W = 320, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "carpet", 320)
      doorsMain(s, S, "law")
      s.put("Sign", P.siteSign(S, 96), 92 - (math.max(96, textW(S.name, 1) + 8) - 96) // 2, 8)
      s.put("Frame", P.diploma(S), 196, 24); s.put("Frame", P.diploma(S), 220, 24); s.put("Frame", P.diploma(S), 244, 24)
      s.putS("Books", P.lawBooks(S), 88, 24, 100, "law_books")
      s.putS("Books2", P.lawBooks(S), 136, 24, 100, "law_books")
      s.putS("Reception", P.recepDesk(S, 90, false), 186, 72, 108, "recep_desk_law_" .. S.id)
      s.putS("RecepPC", P.monitor(), 232, 56, 96, "monitor")
      s.putS("Printer", P.printerBox(), 150, 82, 108, "printer_box")
      s.putS("Plant", P.floorPlant(), 94, 80, 108, "plant_floor")
      s.putS("Scales", P.scalesStatue(), 246, 58, 100, "scales_statue")
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
    end}
  end

  -- ---------------------------------------------------------------- vet
  function P.dog(S, variant)
    local body, shade, patch = "#B8864A", "#8A5A2E", "#F2E6C8"
    if variant == "golden" then body, shade, patch = "#E0B060", "#B8863C", "#F4DCA0" end
    if variant == "beagle" then body, shade, patch = "#F2EFE6", "#8A5A2E", "#C98A50" end
    return L.piece(24, 18, function(R)
      R(2, 6, 14, 8, body); R(14, 2, 8, 8, body); R(20, 4, 3, 3, shade); R(15, 0, 3, 5, shade)
      R(16, 4, 1, 1, OUT); R(22, 6, 1, 1, OUT); R(3, 14, 3, 4, shade); R(12, 14, 3, 4, shade)
      R(0, 6, 3, 2, body); R(1, 4, 2, 3, body)
      R(8, 8, 6, 3, patch)
      if variant == "beagle" then R(3, 6, 5, 5, "#8A5A2E"); R(14, 2, 4, 4, "#8A5A2E") end
    end)
  end

  function P.cat(S, variant)
    local body, shade = "#8A8F9A", "#6A6F7A"
    if variant == "orange" then body, shade = "#E0883E", "#B8662A" end
    if variant == "black" then body, shade = "#3A3A44", "#22222A" end
    return L.piece(16, 15, function(R)
      R(2, 6, 11, 8, body); R(10, 3, 6, 6, body); R(10, 1, 2, 3, body); R(14, 1, 2, 3, body)
      R(12, 5, 1, 1, OUT); R(15, 5, 1, 1, OUT); R(13, 7, 2, 1, "#E8A0A8")
      R(0, 8, 3, 2, body); R(0, 6, 2, 3, body); R(3, 14, 3, 1, shade); R(9, 14, 3, 1, shade)
      R(4, 7, 1, 5, shade); R(7, 7, 1, 5, shade)
      if variant == "black" then R(12, 5, 1, 1, "#F2C94C"); R(15, 5, 1, 1, "#F2C94C") end
    end)
  end

  function P.toothPoster(S)
    return L.piece(20, 26, function(R)
      R(0, 0, 20, 26, "#F4F2EA"); R(1, 1, 18, 24, S.accent)
      R(5, 5, 10, 9, "#FFFFFF"); R(4, 7, 12, 5, "#FFFFFF"); R(6, 14, 3, 5, "#FFFFFF"); R(11, 14, 3, 5, "#FFFFFF")
      R(8, 8, 1, 3, "#C9CDD6"); R(11, 8, 1, 3, "#C9CDD6"); R(4, 21, 12, 2, "#F4F2EA")
    end)
  end

  function P.lightBox()
    return L.piece(28, 20, function(R)
      R(0, 0, 28, 20, "#3A3F4A"); R(2, 2, 24, 16, "#F2F8FF"); R(6, 5, 6, 10, "#BFD0E4"); R(14, 5, 8, 8, "#BFD0E4")
      R(8, 7, 2, 6, "#6A7A8A"); R(16, 7, 4, 4, "#6A7A8A")
    end)
  end

  function P.vetScale()
    return L.piece(26, 12, function(R)
      R(0, 6, 26, 6, "#C9CDD6"); R(0, 6, 26, 1, "#F2F4F8"); R(2, 12, 22, 0, OUT); R(6, 0, 14, 6, "#2E3138"); R(8, 1, 10, 3, "#6A7A8A")
      R(10, 2, 6, 1, "#4CFF7A")
    end)
  end

  function P.firstAid()
    return L.piece(20, 20, function(R)
      R(0, 0, 20, 20, "#17121F"); R(1, 1, 18, 18, "#F4F2EA"); R(8, 4, 4, 12, "#2E9A4A"); R(4, 8, 12, 4, "#2E9A4A")
    end)
  end

  function P.kennels(S)
    return L.piece(64, 44, function(R)
      L.box(R, 0, 0, 64, 44, "#8E939E", "#C9CDD6", "#6A6F7A")
      for i = 0, 1 do for j = 0, 1 do
        local x, y = 2 + i * 31, 2 + j * 21
        R(x, y, 29, 19, "#2A2D36")
        for k = 0, 6 do R(x + 2 + k * 4, y + 1, 1, 17, "#B8BCC4") end
        if (i + j) % 2 == 0 then R(x + 8, y + 9, 10, 8, "#B8864A"); R(x + 15, y + 6, 6, 6, "#B8864A"); R(x + 15, y + 5, 2, 3, "#8A5A2E") else R(x + 9, y + 11, 10, 6, "#8A8F9A"); R(x + 8, y + 8, 5, 5, "#8A8F9A"); R(x + 8, y + 7, 2, 2, "#8A8F9A") end
      end end
    end)
  end

  function P.examTable(S)
    return L.piece(54, 34, function(R)
      L.box(R, 0, 0, 54, 6, "#C9CDD6", "#F2F4F8", "#8E939E")
      R(22, 6, 10, 22, "#8E939E"); R(10, 28, 34, 5, "#6A6F7A")
      R(38, -8, 12, 8, "#2E3138"); R(39, -7, 10, 5, "#6A7A8A")            -- the scale display
    end)
  end

  function P.petPoster(S)
    return L.piece(20, 26, function(R)
      R(0, 0, 20, 26, "#F4F2EA"); R(1, 1, 18, 24, S.accent)
      disc(R, 10, 10, 5, "#F4F2EA"); disc(R, 5, 6, 2, "#F4F2EA"); disc(R, 15, 6, 2, "#F4F2EA"); disc(R, 6, 15, 2, "#F4F2EA"); disc(R, 14, 15, 2, "#F4F2EA")
      R(4, 21, 12, 2, "#F4F2EA")
    end)
  end

  builders_vet = function(S)
    return {W = 320, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "vet", 320)
      doorsMain(s, S, "vet")
      s.put("Sign", P.siteSign(S, 84), 94 - (math.max(84, textW(S.name, 1) + 8) - 84) // 2, 10)
      s.put("Door", P.slabDoor(S.accent, S.trim, "#FFFFFF", "lever"), 208, 18); plateAt(s, EXAM_PLATES.vet[1], 208)
      s.put("Door", P.slabDoor(S.accent, S.trim, "#FFFFFF", "lever"), 246, 18); plateAt(s, EXAM_PLATES.vet[2], 246)
      s.put("Poster", P.petPoster(S), 180, 24)
      s.putS("Reception", P.recepDesk(S, 90, false), 88, 72, 108, "recep_desk_vet_" .. S.id)
      s.putS("RecepPC", P.monitor(), 132, 56, 96, "monitor")
      s.putS("Dog", P.dog(S, "golden"), 184, 94, 112, "dog_golden")
      s.putS("Scale", P.vetScale(), 130, 94, 111, "vet_scale")
      s.putS("Cat", P.cat(S, "gray"), 106, 58, 109, "cat_gray")
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
    end}
  end

  -- ---------------------------------------------------------------- architect
  function P.draftTable(S)
    return L.piece(58, 38, function(R)
      R(2, 14, 54, 3, "#8E939E")                                                                     -- the tilted board
      R(0, 6, 58, 8, "#F4F2EA"); R(2, 8, 54, 1, "#3E6EB8"); R(4, 10, 20, 1, "#3E6EB8"); R(30, 10, 22, 1, "#3E6EB8")
      R(6, 17, 3, 20, "#6A6F7A"); R(49, 17, 3, 20, "#6A6F7A"); R(4, 34, 50, 3, "#4A4F5A")
      R(42, -6, 2, 12, "#2A2D36"); R(36, -8, 10, 3, "#2A2D36"); R(34, -6, 5, 3, "#FFF6B0")          -- the lamp
    end)
  end

  function P.plotter(S)
    return L.piece(48, 36, function(R)
      L.box(R, 0, 8, 48, 24, "#C9CDD6", "#E4E8F0", "#8E939E")
      R(4, 0, 40, 8, "#F4F2EA"); R(6, 2, 36, 1, "#3E6EB8"); R(6, 5, 20, 1, "#3E6EB8")                 -- paper coming out
      R(4, 14, 32, 4, "#2E3138"); R(38, 14, 6, 6, "#4CFF7A"); R(5, 32, 4, 4, "#6A6F7A"); R(39, 32, 4, 4, "#6A6F7A")
      R(10, 20, 24, 1, "#8E939E")
    end)
  end

  function P.archModel(S)
    return L.piece(40, 36, function(R)
      R(0, 28, 40, 8, "#8A6A44"); R(2, 28, 36, 2, "#B89868")
      R(5, 12, 12, 16, "#F2F0E8"); R(21, 4, 12, 24, "#F2F0E8"); R(5, 8, 12, 4, S.accent); R(21, 0, 12, 4, S.accent)
      for y = 14, 26, 4 do R(7, y, 2, 2, "#8AB4D8"); R(12, y, 2, 2, "#8AB4D8") end
      for y = 6, 24, 4 do R(23, y, 2, 2, "#8AB4D8"); R(28, y, 2, 2, "#8AB4D8") end
      disc(R, 36, 24, 3, "#3E9A4A"); disc(R, 2, 24, 3, "#3E9A4A")
    end)
  end

  function P.blueprintRack()
    return L.piece(32, 46, function(R)
      L.box(R, 0, 0, 32, 46, "#5A3A22", "#7A5030", "#3E281A")
      for row = 0, 2 do for col = 0, 2 do
        local x, y = 2 + col * 10, 3 + row * 14
        R(x, y, 8, 12, "#2A1B0E"); R(x + 1, y + 3, 6, 7, "#3E6EB8"); R(x + 2, y + 5, 4, 1, "#BFE0F8")
      end end
    end)
  end

  function P.bigWindowArch()
    return L.piece(70, 52, function(R)
      R(0, 0, 70, 52, "#E8E4D4"); R(3, 3, 64, 46, "#9AC8E8")
      for y = 3, 48 do R(3, y, 64, 1, (y < 28) and "#9AC8E8" or "#C8E0F0") end
      R(10, 28, 8, 20, "#6A7A8A"); R(20, 20, 10, 28, "#7A8A9A"); R(34, 32, 12, 16, "#6A7A8A"); R(50, 14, 9, 34, "#7A8A9A")
      R(34, 3, 2, 46, "#E8E4D4"); R(3, 26, 64, 2, "#E8E4D4")
    end)
  end

  builders_arch = function(S)
    return {W = 320, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "carpet", 320)
      doorsMain(s, S, "arch")
      s.put("Sign", P.siteSign(S, 90), 82, 8)
      s.put("Window", P.bigWindowArch(), 214, 8)
      s.putS("Rack", P.blueprintRack(), 88, 48, 104, "blueprint_rack")
      s.putS("Draft1", P.draftTable(S), 122, 62, 108, "draft_table")
      s.putS("Chair1", P.chair(), 132, 62, 96, "chair_office")
      s.putS("Plotter", P.plotter(S), 186, 72, 108, "plotter")
      s.putS("Reception", P.recepDesk(S, 52, false, S.id == "a" and "LINDQVIST" or "NORTHLIGHT"), 234, 77, 108.5, "recep_desk_arch_" .. S.id)   -- the front desk (was a plain desk)
      s.putS("Mon", P.monitor(), 246, 62, 96, "monitor")
      s.putS("Chair2", P.chair(), 234, 66, 95, "chair_office")
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
    end}
  end

  -- ---------------------------------------------------------------- realty
  function P.listingBoard(S)
    return L.piece(96, 46, function(R)
      R(0, 0, 96, 46, OUT); R(1, 1, 94, 44, S.accent); R(1, 1, 94, 1, "#FFFFFF")
      centred(R, "NEW LISTINGS", 48, 3, 1, "#FFFFFF")
      for i = 0, 3 do
        local x = 4 + i * 23
        R(x, 11, 20, 21, "#F4F2EA")
        R(x + 1, 12, 18, 12, ({"#9AC8E8", "#E8D8A8", "#B8D8B0", "#E8B8A0"})[i + 1])
        R(x + 5, 16, 10, 8, ({"#E8E0D0", "#C86A4A", "#F2F0E8", "#6A7A9A"})[i + 1]); R(x + 3, 14, 14, 3, "#6A4A38")
        centred(R, ({"$199K", "$249K", "$325K", "$410K"})[i + 1], x + 10, 26, 1, OUT)
      end
      R(4, 35, 88, 6, "#F4F2EA"); centred(R, "OPEN HOUSE SUN 1-4", 48, 36, 1, S.accent)
    end)
  end

  function P.soldSign(S)
    return L.piece(30, 36, function(R)
      R(14, 14, 2, 22, "#6A4A2E"); R(0, 0, 30, 18, "#F4F2EA"); R(1, 1, 28, 16, S.accent)
      centred(R, "SOLD", 15, 6, 1, "#FFFFFF")
      R(0, 18, 30, 6, "#D2452E"); R(0, 18, 30, 1, "#F4F2EA"); centred(R, "SALE", 15, 19, 1, "#FFFFFF")
    end)
  end

  function P.coffeeBar(S)                      -- a 30 px coffee counter: machine, pot, mugs, a tip jar
    return L.piece(30, 40, function(R)
      L.box(R, 0, 14, 30, 5, "#C9955A", "#E0B47A", "#A57445")
      R(0, 19, 30, 21, S.trim); R(2, 21, 26, 17, S.wall)
      R(2, 2, 12, 12, "#2E3138"); R(3, 3, 10, 5, "#6A6F7A"); R(5, 10, 6, 4, "#F2F2EA"); R(3, 9, 1, 1, "#E04E4E")
      R(17, 7, 4, 7, "#F2F2EA"); R(22, 8, 4, 6, "#E04E4E"); R(17, 5, 3, 2, "#8E939E")
    end)
  end

  function P.signInSheet(S)                    -- the visitor sign-in clipboard on the wall, with a card over it
    return L.piece(30, 28, function(R)
      R(0, 0, 30, 8, OUT); R(1, 1, 28, 6, S.accent); centred(R, "SIGN IN", 15, 2, 1, "#FFFFFF")
      R(8, 9, 14, 19, OUT); R(9, 10, 12, 17, "#8A6A44")
      R(11, 12, 8, 14, "#F4F2EA"); R(12, 8, 6, 3, "#8E939E")
      for y = 14, 24, 3 do R(12, y, 6, 1, "#9AA0AC") end
      R(12, 24, 3, 1, "#2E5AA8")                -- the last signature
      R(22, 18, 1, 9, "#C9955A")                -- the pen on its string
    end)
  end

  function P.soldPlaque(S)                     -- the SOLD sign, hung on the wall
    return L.piece(30, 22, function(R)
      R(0, 0, 30, 22, OUT); R(1, 1, 28, 12, S.accent); centred(R, "SOLD", 15, 4, 1, "#FFFFFF")
      R(1, 13, 28, 8, "#D2452E"); R(1, 13, 28, 1, "#F4F2EA"); centred(R, "SALE", 15, 15, 1, "#FFFFFF")
    end)
  end

  builders_realty = function(S)
    return {W = 320, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "carpet", 320)
      doorsMain(s, S, "realty")
      s.put("Sign", P.siteSign(S, 100), 80, 8)
      s.put("Board", P.listingBoard(S), 186, 14)
      s.put("Sold", P.soldPlaque(S), 80, 30)                                        -- the yard sign moved up to the wall
      s.put("SignIn", P.signInSheet(S), 114, 30)
      s.putS("CoffeeBar", P.coffeeBar(S), 82, 62, 102, "coffee_bar_" .. S.id)
      for i, x in ipairs({112, 186}) do
        s.putS("Chair" .. i, P.chair(), x + 1, 66, 95, "chair_office")
        s.putS("Desk" .. i, P.desk(74), x + 3, 83, 108, "desk_cubicle_74")
        s.putS("Mon" .. i, P.monitor(), x + 29, 62, 96, "monitor")
        s.putS("Kb" .. i, P.keyboard(), x + 27, 80, 108.5, "keyboard")
      end
      s.putS("Printer", P.printerBox(), 258, 80, 106, "printer_box")
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
    end}
  end

  -- ---------------------------------------------------------------- the demolition company: two office trailers
  function P.trailerWindow(S)
    return L.piece(44, 32, function(R)
      R(0, 0, 44, 32, "#6A6F7A"); R(2, 2, 40, 28, "#9AC8E8")
      for y = 2, 29 do R(2, y, 40, 1, (y < 18) and "#9AC8E8" or "#C8B898") end
      R(8, 14, 20, 10, S.accent); R(26, 8, 3, 14, S.accent); R(26, 8, 14, 3, S.accent); R(36, 8, 3, 8, S.accent)   -- an excavator out there
      R(6, 24, 26, 4, "#2A2D36"); disc(R, 10, 26, 2, "#17121F"); disc(R, 28, 26, 2, "#17121F")
      R(20, 2, 2, 28, "#6A6F7A")
    end)
  end

  function P.hardHats(S)
    return L.piece(36, 24, function(R)
      R(0, 0, 36, 24, "#6A4A2E"); R(1, 1, 34, 22, "#8A6A44")
      for i = 0, 2 do
        local x = 3 + i * 11
        R(x, 8, 9, 6, ({S.accent, "#F2F2EA", "#2E5AA8"})[i + 1]); R(x - 1, 13, 11, 2, ({S.accent, "#F2F2EA", "#2E5AA8"})[i + 1]); R(x + 4, 5, 1, 3, "#17121F")
      end
    end)
  end

  function P.siteMap(S)
    return L.piece(46, 32, function(R)
      R(0, 0, 46, 32, "#17121F"); R(1, 1, 44, 30, "#F4F2EA")
      R(4, 4, 18, 12, "#C8B898"); R(24, 6, 16, 10, "#B8D8B0"); R(6, 19, 34, 8, "#D8D8D8")
      for _, p in ipairs({{8, 7}, {30, 9}, {20, 22}, {38, 22}}) do R(p[1], p[2], 3, 3, "#D2452E") end
      R(10, 18, 30, 1, S.accent)
    end)
  end

  function P.safetySign()
    return L.piece(22, 22, function(R)
      R(0, 0, 22, 22, "#17121F"); R(1, 1, 20, 20, "#F2C94C"); R(2, 2, 18, 18, "#17121F"); R(3, 3, 16, 16, "#F2C94C")
      R(10, 6, 2, 7, "#17121F"); R(10, 14, 2, 2, "#17121F")
    end)
  end

  function P.spaceHeater()
    return L.piece(20, 24, function(R)
      L.box(R, 0, 0, 20, 24, "#C9CDD6", "#E4E8F0", "#8E939E")
      for y = 4, 16, 3 do R(3, y, 14, 1, "#E07A2E") end
      R(8, 19, 4, 3, "#E04E4E")
    end)
  end

  function P.trailerDivider(S)               -- the end wall between the two trailers, with a doorway
    return L.piece(14, 76, function(R)
      R(0, 0, 14, 76, S.trim); R(0, 0, 2, 76, S.accent); R(12, 0, 2, 76, S.accent)
      R(3, 12, 8, 64, "#17121F"); R(4, 13, 6, 63, S.wall)
    end)
  end

  builders_trailer = function(S)
    return {W = 320, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "trailer", 320)
      doorsMain(s, S, "trailer")
      s.put("Sign", P.siteSign(S, 90), 92 - (math.max(90, textW(S.name, 1) + 8) - 90) // 2, 5)
      s.put("Window", P.trailerWindow(S), 124, 23)
      s.put("Hats", P.hardHats(S), 84, 40)
      s.put("Map", P.siteMap(S), 176, 23)
      s.put("Safety", P.safetySign(), 230, 24)
      s.put("FirstAid", P.firstAid(), 256, 24)
      s.putS("Cooler", P.cooler(), 266, 78, 108, "cooler")
      s.putS("Chair1", P.chair("#6A4A2E", "#8A6A44", "#4A3220"), 96, 66, 95, "chair_office_brown")
      s.putS("Desk1", P.desk(74), 98, 83, 108, "desk_cubicle_74")
      s.putS("Mon1", P.monitor(), 124, 62, 96, "monitor")
      s.putS("Kb1", P.keyboard(), 122, 80, 108.5, "keyboard")
      s.putS("Phone1", P.deskPhoneBase(), 155, 72, 108.3, "desk_phone")
      s.putS("Files", P.filingCabinet(), 188, 78, 108, "filing_cabinet")
      s.putS("Printer", P.printerBox(), 214, 80, 106, "printer_box")
      s.putS("Heater", P.spaceHeater(), 254, 82, 108, "space_heater")
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
    end}
  end


  -- ---------------------------------------------------------------- exam rooms (dental and vet) and the IT closet
  function P.examChairVet(S)
    return L.piece(70, 36, function(R)
      L.box(R, 0, 0, 70, 7, "#C9CDD6", "#F2F4F8", "#8E939E")
      R(26, 7, 12, 22, "#8E939E"); R(12, 29, 40, 6, "#6A6F7A")
      R(50, -6, 18, 6, "#2E3138"); R(52, -5, 14, 3, "#6A7A8A")
    end)
  end

  function P.sinkCounter(S)
    return L.piece(60, 36, function(R)
      L.box(R, 0, 0, 60, 5, "#F2EFE6", "#FFFFFF", "#C9C3B2")
      R(0, 5, 60, 31, S.trim); R(2, 7, 56, 27, S.wall); R(28, 5, 2, 29, S.trim)
      R(8, -7, 10, 7, "#8E939E"); R(11, -9, 4, 2, "#8E939E")
      R(36, -8, 18, 8, "#2E3138"); R(37, -7, 16, 5, "#6A7A8A")
    end)
  end

  function P.xrayUnit(S)
    return L.piece(34, 44, function(R)
      R(14, 0, 4, 18, "#8E939E"); R(4, 16, 26, 8, "#F2F2EA"); R(4, 16, 26, 2, S.accent); R(20, 24, 10, 8, "#C9CDD6")
      R(2, 34, 30, 8, "#C9CDD6"); R(6, 36, 6, 4, "#4CFF7A")
    end)
  end

  function P.siteRack(S)
    return L.piece(66, 84, function(R)
      R(0, 0, 66, 84, "#22252E"); R(2, 2, 62, 80, "#14161C")
      R(5, 5, 56, 8, "#8E939E"); for i = 0, 15 do R(7 + i * 3, 8, 2, 3, "#17121F") end                    -- patch panel
      R(5, 16, 56, 10, "#14566E"); for i = 0, 11 do R(8 + i * 4, 19, 2, 2, ({"#4CFF7A", "#F2C94C", "#4CFF7A"})[i % 3 + 1]) end   -- switch
      R(5, 29, 56, 10, "#3A3F4A"); R(8, 32, 5, 3, "#E04E4E"); R(16, 32, 3, 3, "#4CFF7A"); R(22, 32, 3, 3, "#4CFF7A"); R(30, 32, 20, 3, "#8E939E")  -- the router
      R(5, 42, 56, 14, "#2A2D36"); R(8, 45, 28, 2, "#8E939E"); R(8, 50, 28, 2, "#8E939E"); R(46, 46, 10, 6, "#4CFF7A")                             -- a NAS
      R(5, 59, 56, 18, "#3A3F4A"); R(8, 62, 22, 12, "#14161C"); R(36, 64, 18, 4, "#F2C94C"); R(36, 70, 18, 4, "#4CFF7A")                          -- the UPS
    end)
  end


  function P.execDesk(S)
    return L.piece(86, 38, function(R)
      L.box(R, 0, 0, 86, 6, "#6A4A2E", "#8A6A44", "#4A3220")
      R(2, 6, 82, 32, "#5A3A22"); R(4, 8, 36, 28, "#4A3220"); R(44, 8, 38, 28, "#4A3220")
      for i = 0, 2 do R(10, 12 + i * 8, 24, 5, "#6A4A2E"); R(20, 14 + i * 8, 4, 1, "#C8A04A") end
      R(52, 14, 22, 4, "#6A4A2E"); R(60, 15, 4, 1, "#C8A04A")
      R(62, -6, 14, 5, "#C8A04A"); R(64, -9, 10, 3, "#E8D060")                                         -- a nameplate
    end)
  end

  function P.trophyShelf(S)
    return L.piece(60, 44, function(R)
      L.box(R, 0, 0, 60, 44, "#5A3A22", "#7A5030", "#3E281A")
      R(2, 20, 56, 2, "#3E281A"); R(2, 21, 56, 1, "#8A6A44")
      for i = 0, 2 do R(6 + i * 18, 8, 8, 12, S.accent); R(8 + i * 18, 4, 4, 4, "#E8D060") end        -- cups
      R(8, 28, 12, 12, "#F4F2EA"); R(9, 29, 10, 10, S.accent)                                          -- a framed photo
      R(26, 28, 12, 12, "#F4F2EA"); R(27, 29, 10, 10, "#9AC8E8"); R(44, 30, 10, 10, "#8A6A44")
    end)
  end

  function P.officeSofa(S)
    return L.piece(56, 30, function(R)
      R(0, 4, 56, 14, S.accent); R(2, 6, 52, 8, S.trim); R(0, 12, 8, 14, S.accent); R(48, 12, 8, 14, S.accent)
      R(8, 14, 40, 10, S.trim); R(4, 26, 4, 4, "#2A1B0E"); R(48, 26, 4, 4, "#2A1B0E")
    end)
  end

  builders_office = function(kind, S)
    return {W = 240, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "carpet", 240)
      s.put("Doors", P.slabDoor("#5A3A22", "#3E281A", "#7A5030", "lever"), 4, 18); s.put("Plate", P.doorPlate("OFFICE"), 4, 9)
      -- the door takes x 4-38; the trailer office hangs one diploma and the hard-hat board on the free wall before the window
      if kind == "trailer" then s.put("Frame", P.diploma(S), 42, 24)
      else s.put("Frame", P.diploma(S), 56, 24); s.put("Frame", P.diploma(S), 80, 24) end
      s.put("Trophy", P.trophyShelf(S), 160, 34)
      if kind == "trailer" then s.put("Window", P.trailerWindow(S), 110, 22) else s.put("Window", P.bigWindowArch(), 96, 8) end
      s.putS("Sofa", P.officeSofa(S), 176, 80, 108, "office_sofa_" .. S.id)
      s.putS("Chair", P.chair("#5A2A1E", "#7A3A28", "#3E1A10"), 80, 66, 95, "chair_exec")
      s.putS("Desk", P.execDesk(S), 70, 76, 108, "exec_desk_" .. S.id)
      s.putS("Mon", P.monitor(), 96, 54, 96, "monitor")
      s.putS("Plant", P.floorPlant(), 26, 80, 108, "plant_floor")
      if kind == "vet" then
        s.putS("Dog", P.dog(S), 150, 94, 112, "dog_tan")
        s.putS("Cat", P.cat(S, "black"), 200, 64, 109, "cat_black")
      end
      if kind == "trailer" then s.putS("Hats", P.hardHats(S), 64, 40, 100, "hard_hats_wall") end
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 120, 56) end
    end}
  end

  builders_exam = function(kind, S)
    return {W = 240, H = 128, fn = function(s)
      s.layer("Ceiling")
      wallAndFloor(s, S, "tile", 240)
      s.put("Doors", P.slabDoor(S.accent, S.trim, "#FFFFFF", "lever"), 4, 18); s.put("Plate", P.doorPlate("OFFICE"), 4, 9)
      if kind == "dental" then s.put("Poster", P.toothPoster(S), 160, 26); s.put("Frame", P.lightBox(), 126, 30)
      else s.put("Poster", P.petPoster(S), 160, 26) end
      s.put("Clock", P.clock(), 96, 24)
      s.put("Sink", P.sinkCounter(S), 176, 50)
      s.putS("Counter", P.sinkCounter(S), 50, 72, 108, "sink_counter_" .. S.id)
      if kind == "dental" then
        s.put("Frame", P.frame(14, 18, "#9AD0E4", "#3E8E3A"), 86, 28)
        s.putS("Chair", P.dentalChair(S), 122, 56, 104, "dental_chair_" .. S.id)
        s.putS("Xray", P.xrayUnit(S), 200, 44, 104, "xray_unit")
      else
        s.putS("Table", P.examChairVet(S), 124, 72, 108, "exam_table_vet")
        s.putS("Dog", P.dog(S, "beagle"), 204, 94, 112, "dog_beagle")
        s.putS("Cat", P.cat(S, "orange"), 160, 56, 109, "cat_orange")
      end
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 90, 56) end
    end}
  end

  builders_closet = function(S)
    return {W = 176, H = 128, fn = function(s)
      s.layer("Ceiling")
      local wall = s.layer("Wall")
      F(wall, 0, 0, 176, 84, "#9AA1AB"); F(wall, 0, 0, 176, 3, S.accent); F(wall, 0, 84, 176, 6, OUT)
      for x = 0, 175, 16 do F(wall, x, 3, 1, 81, "#8A919B") end
      local floor = s.layer("Floor")
      local y0 = 90 + L.YOFF
      L.fill(floor, 0, y0, floor.width, floor.height - y0, "#C8C4B8")
      for x = 0, floor.width - 1, 32 do L.fill(floor, x, y0, 1, floor.height - y0, "#B3AFA2") end
      L.fill(floor, 0, y0, floor.width, 2, "#9A968A")
      s.put("Doors", P.slabDoor("#7B828F", "#646B77", "#97A0AD", "lever"), 4, 18); s.put("Plate", P.doorPlate("OFFICE"), 4, 9)
      s.put("Wall", P.whiteboard(), 128, 14)
      s.putS("Rack", P.siteRack(S), 56, 4, 104, "site_rack_" .. S.id)
      s.putS("Server", P.serverTower(), 126, 80, 108, "server_tower")
      s.putS("Boxes", P.drawerStack(S), 152, 76, 108, "drawer_stack_" .. S.id)
      if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 90, 56) end
    end}
  end

  -- ---------------------------------------------------------------- register every type x skin
  local made = {dental = builders_dental, law = builders_law, vet = builders_vet, arch = builders_arch,
                realty = builders_realty, trailer = builders_trailer}
  local tints = {dental = {1.0, 1.0, 1.0}, law = {1.0, 0.92, 0.85}, vet = {1.0, 1.0, 1.0}, arch = {1.0, 1.0, 1.05},
                 realty = {1.05, 1.0, 0.9}, trailer = {0.95, 0.9, 0.8}}
  for kind, make in pairs(made) do
    for sid, S in pairs(SKINS[kind]) do
      local b = make(S)
      b.post = function(set)
        local im = set.layer("Ceiling")
        local t = tints[kind]
        for y = 0, im.height - 1 do for x = 0, im.width - 1 do
          local px = im:getPixel(x, y)
          local a = app.pixelColor.rgbaA(px)
          if a > 0 then
            im:putPixel(x, y, app.pixelColor.rgba(math.min(255, math.floor(app.pixelColor.rgbaR(px) * t[1])),
              math.min(255, math.floor(app.pixelColor.rgbaG(px) * t[2])), math.min(255, math.floor(app.pixelColor.rgbaB(px) * t[3])), a))
          end
        end end
      end
      builders["site_" .. kind .. "_" .. sid] = b
    end
  end
  for _, kind in ipairs({"dental", "law", "vet", "arch", "realty", "trailer"}) do
    for sid, S in pairs(SKINS[kind]) do
      builders["site_" .. kind .. "_closet_" .. sid] = builders_closet(S)
      builders["site_" .. kind .. "_office_" .. sid] = builders_office(kind, S)
      if kind == "dental" or kind == "vet" then builders["site_" .. kind .. "_exam_" .. sid] = builders_exam(kind, S) end
    end
  end
end
