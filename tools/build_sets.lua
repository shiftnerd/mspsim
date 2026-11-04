-- Builds the four sets twice:
--   normal  -> office/<set>.aseprite  (everything drawn, plus a CharacterTest layer for scale)
--   export  -> godot/assets/sets/<set>.png (background only), godot/assets/props/<piece>.png,
--              godot/assets/sets/<set>_props.json (y-sorted prop placements for Godot)
-- Run with run_lua_script. Needs tools/lib.lua next to this file.
local TOOLS = "D:/creative/pixelproject/tools/"
local L = dofile(TOOLS .. "lib.lua")
local P = L.P
local GODOT = "D:/creative/pixelproject/godot/assets/"

-- the rubber duck that sits on the player's desk (it squeaks when you press E on it)
function P.rubberDuck()
  return L.piece(15, 12, function(R)
    local OUT, Y, SH, OR = "#17121F", "#F2C94C", "#D8A82C", "#F2862E"
    local rects = {{5, 1, 6, 5}, {2, 6, 11, 5}, {12, 5, 2, 2}, {3, 3, 3, 2}}
    for _, r in ipairs(rects) do R(r[1] - 1, r[2] - 1, r[3] + 2, r[4] + 2, OUT) end
    R(5, 1, 6, 5, Y); R(2, 6, 11, 5, Y); R(12, 5, 2, 2, Y)
    R(2, 10, 11, 1, SH); R(6, 7, 5, 2, SH)                  -- the belly shade and a wing
    R(3, 3, 3, 2, OR); R(3, 4, 3, 1, "#C8681E")             -- the beak
    R(7, 3, 1, 1, OUT)                                      -- the eye
  end)
end

local builders = {}

-- ===== MAIN FLOOR 368x128 =====
builders.main_floor = {W = 368, H = 128, fn = function(s)
  local W = 368
  L.wall(s.layer("Wall"), W, "#8FC43A", "#79A82F"); L.carpet(s.layer("Floor"), W)
  L.hallway(s.layer("Hallway"))   -- recessed green hallway with the glass front door at the far end
  local brown = P.slabDoor("#7A4A2B", "#62391F", "#8F5A38", "lever")
  s.put("Doors", brown, 164, 18); s.put("Doors", brown, 212, 18)
  s.put("TV", P.tv(), 262, 26)
  -- open desk: sitter at the desk's left end facing right, keyboard then monitor in front of them
  s.putS("OpenDeskChair", P.chair(), 64, 66, 95, "chair_office")
  s.putS("OpenDesk", P.desk(74), 66, 83, 108, "desk_cubicle_74")
  P.dualTop(s, "OpenDeskProps", 66, true)   -- two monitors, keyboard, mouse, phone (R25)
  s.putS("OpenDeskProps", P.rubberDuck(), 110, 53, 108.6, "rubber_duck")   -- sits on top of the right-hand monitor
  -- cubicles
  local shell, cal, note = P.cubicleShell(), P.calendar(), P.sticky()
  for _, cx in ipairs({198, 282}) do
    s.put("CubicleShell", shell, cx, 52)
    s.put("CubiclePropsBack", cal, cx + 8, 60); s.put("CubiclePropsBack", note, cx + 60, 64)
    s.putS("CubicleChairs", P.chair(), cx + 1, 66, 95, "chair_office")
    s.putS("CubicleDesks", P.desk(74), cx + 3, 83, 108, "desk_cubicle_74")
    P.dualTop(s, "CubicleProps", cx + 3, true)
  end
  if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 140, 56) end
end}

-- ===== OFFICE INTERIOR 176x128 (door on the left) =====
-- ===== OFFICE 1 176x128: the tidy one (bookshelf, green armchair, framed pictures, clock) =====
builders.office_one = {W = 176, H = 128, fn = function(s)
  L.wall(s.layer("Wall"), 176, "#CFE8C0", "#B2CDA3"); L.carpet(s.layer("Floor"), 176)
  s.put("Doors", P.slabDoor("#7A4A2B", "#62391F", "#8F5A38", "lever"), 4, 18)
  s.put("Bookshelf", P.bookshelf(), 144, 26); s.put("Plant", P.plant(), 152, 8)
  s.put("Frames", P.frame(14, 18), 76, 30)
  s.put("Frames", P.frame(14, 18, "#E8B070", "#7A4A8A"), 96, 30)
  s.put("Frames", P.clock(), 118, 26)
  s.putS("Armchair", P.slipperSide(), 40, 68, 99, "chair_slipper_green_side")   -- side view: you can sit in it
  s.putS("Chair", P.chair(), 66, 66, 95, "chair_office")
  s.putS("Desk", P.desk(74), 68, 83, 108, "desk_cubicle_74")
  P.dualTop(s, "Props", 68, true)
  if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 118, 56) end
end}

-- ===== OFFICE 2 176x128: the lived-in one (tan walls, couch, filing cabinet, whiteboard, plant) =====
builders.office_two = {W = 176, H = 128, fn = function(s)
  L.wall(s.layer("Wall"), 176, "#E4D8B8", "#CBBE9C"); L.carpet(s.layer("Floor"), 176)
  s.put("Doors", P.slabDoor("#7A4A2B", "#62391F", "#8F5A38", "lever"), 4, 18)
  s.put("Wall", P.whiteboard(), 84, 24)
  s.put("Frames", P.clock(), 140, 24)
  s.put("Frames", P.frame(14, 18, "#9AD0C3", "#3E8E3A"), 50, 28)
  s.putS("Couch", P.couch(), 42, 69, 99, "couch")
  s.putS("Chair", P.chair(), 91, 66, 95, "chair_office")
  s.putS("Desk", P.desk(74), 88, 83, 108, "desk_cubicle_74")
  P.dualTop(s, "Props", 88, true)
  s.putS("Cabinet", P.filingCabinet(), 162, 78, 108, "filing_cabinet")
  s.putS("FloorPlant", P.floorPlant(), 20, 80, 108, "plant_floor")
  if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
end}

-- ===== CONFERENCE 320x128: a long table, six chairs on the back side, room for the whole company =====
builders.conference = {W = 320, H = 128, fn = function(s)
  local W = 320
  L.wall(s.layer("Wall"), W, "#BFE0B0", "#A5C896"); L.carpet(s.layer("Floor"), W)
  s.put("Door", P.slabDoor("#7A4A2B", "#62391F", "#8F5A38", "lever"), 282, 18)
  s.put("Screen", P.wallScreen(), 127, 22)
  s.put("Wall", P.whiteboard(), 34, 28)
  s.put("Frames", P.clock(), 226, 28)
  s.put("Frames", P.frame(14, 18, "#E8B070", "#7A4A8A"), 252, 24)
  for _, x in ipairs({56, 88, 120, 152, 184, 216}) do
    s.putS("ChairsBack", P.chair("#4A4D55", "#6A6E78", "#35373E"), x, 58, 88, "chair_conference")
  end
  s.putS("Table", P.confTableWide(220), 40, 78, 108, "conference_table_wide")
  for _, x in ipairs({72, 120, 168, 216}) do
    s.putS("ChairsFront", P.chair("#4A4D55", "#6A6E78", "#35373E"), x, 86, 112, "chair_conference")
  end
  s.putS("PlantL", P.floorPlant(), 10, 80, 108, "plant_floor")
  s.putS("PlantR", P.floorPlant(), 262, 80, 108, "plant_floor")
end}

-- ===== KITCHENETTE 304x128 (R24: widened from 176 so the heavy steel door to the warehouse fits on the right) =====
builders.kitchenette = {W = 304, H = 128, fn = function(s)
  local W = 304
  L.wall(s.layer("Wall"), W, "#8FC43A", "#79A82F"); L.tiles(s.layer("Floor"), W)
  local bath = P.slabDoor("#DDB680", "#C79F68", "#EBCB9A", "black")
  s.put("Doors", bath, 4, 18); s.put("Doors", bath, 136, 18)
  s.put("Plate", P.bathPlate("BATH 1"), 4, 9); s.put("Plate", P.bathPlate("BATH 2"), 136, 9)   -- the occupied lights are fx `occupied_N`
  s.put("Fridge", P.fridge(), 46, 30); s.put("UpperCabinets", P.upperCabinets(), 78, 36)
  s.put("Counter", P.lowerCabinets(), 76, 76)
  s.put("CounterProps", P.coffee(), 82, 60); s.put("CounterProps", P.sink(), 109, 66)
  -- the way to the warehouse: a heavy grey steel door (set x 206..246, centre 226), its plate and a small notice
  s.put("Doors", P.steelDoor(40, 72, "#7B828F", "#646B77", "#97A0AD"), 206, 18)
  s.put("Plate", P.doorPlate("WAREHSE", "#4A4F5A"), 210, 9)
  s.put("Plate", P.smallSign("STAFF ONLY"), 252, 34)
end}

-- ===== CUBICLE AREA 288x128 (cubicles 3 and 4 + copier corner) =====
builders.cubicle_area = {W = 320, H = 128, fn = function(s)
  local W = 320
  L.wall(s.layer("Wall"), W, "#8FC43A", "#79A82F"); L.carpet(s.layer("Floor"), W)
  local shell, cal, note = P.cubicleShell(), P.calendar(), P.sticky()
  for _, cx in ipairs({20, 104}) do
    s.put("CubicleShell", shell, cx, 52)
    s.put("CubiclePropsBack", cal, cx + 56, 60); s.put("CubiclePropsBack", note, cx + 10, 64)
    s.putS("CubicleChairs", P.chair(), cx + 1, 66, 95, "chair_office")
    s.putS("CubicleDesks", P.desk(74), cx + 3, 83, 108, "desk_cubicle_74")
    P.dualTop(s, "CubicleProps", cx + 3, true)
  end
  s.put("Whiteboard", P.whiteboard(), 222, 30)
  s.putS("Copier", P.copier(), 200, 82, 108, "copier")
  s.putS("Cooler", P.cooler(), 238, 78, 108, "cooler")
  s.putS("Plant", P.floorPlant(), 262, 78, 108, "plant_floor")
  -- R24: the closet door that stood here (set x 282..316) moved into the warehouse; a filing cabinet and a framed notice fill the wall
  s.putS("Cabinet", P.filingCabinet(), 292, 78, 108, "filing_cabinet")
  s.put("Frames", P.frame(14, 18, "#E8B070", "#7A4A8A"), 292, 34)
  s.put("Wall plates", P.nerfRack(), 190, 34)
  if not s.exportMode then s.put("CharacterTest", L.char("office_adult_right"), 150, 56) end
end}

-- ===== NETWORK CLOSET 144x128: a door, an outlet, the ISP jack and one rack =====
builders.network_closet = {W = 144, H = 128, fn = function(s)
  L.wall(s.layer("Wall"), 144, "#9AA1AB", "#828994"); L.tiles(s.layer("Floor"), 144)
  s.put("Doors", P.steelDoor(34, 72, "#2F5FA8", "#234A85", "#4F82C8"), 4, 18)   -- R24: the blue steel door; it leads out to the warehouse
  s.put("Wall plates", P.wallOutlet(), L.CLOSET.outlet[1], L.CLOSET.outlet[2])
  s.put("Wall plates", P.ispJack(), L.CLOSET.jack[1], L.CLOSET.jack[2])
  s.put("Rack", P.networkRack(), L.CLOSET.rack[1], L.CLOSET.rack[2])
end}

dofile(TOOLS .. "bathroom_sets.lua")(L, builders)  -- the two restrooms behind the kitchenette doors (bathroom_1, bathroom_2)
dofile(TOOLS .. "outing_sets.lua")(L, builders)   -- bowling alley, karaoke bar, escape room
dofile(TOOLS .. "venue_sets.lua")(L, builders)    -- Rodent Nation: resort lobby, hall, ballroom, four breakout rooms (SALON A-D), vendor hall
dofile(TOOLS .. "warehouse_set.lua")(L, builders)  -- the warehouse (1480 px wide: staging and e-waste storage, chair race phase 1)
dofile(TOOLS .. "client_sets.lua")(L, builders)   -- client sites: site_<type>_<skin> (dental, law, vet, arch, realty, trailer x a, b)
local exported = {}
local T, B = L.CEIL_H, L.FLOOR_EXT
local seeds = {main_floor = 3, office_one = 7, office_two = 8, conference = 11, kitchenette = 5, bathroom_1 = 13, bathroom_2 = 14, cubicle_area = 9,
  network_closet = 15, bowling_alley = 21, karaoke_bar = 22, escape_room = 23, restaurant = 24,
  resort_lobby = 31, resort_hall = 32, ballroom = 33, breakout_a = 34, breakout_b = 36, breakout_c = 37, breakout_d = 38, vendor_hall = 35, warehouse = 41}
for name, b in pairs(builders) do
  if ONLY and not ONLY[name] then goto continue end
  L.YOFF = T                                  -- builders keep their old 0..128 coordinates; the canvas grows around them
  local totalW = math.max(b.W, L.MIN_W)
  L.XOFF = (totalW - b.W) // 2                -- narrow rooms get an off-stage margin on both sides
  local H = T + b.H + B
  local function finish(set)
    L.ceiling(set.layer("Ceiling"), totalW, T, seeds[name] or 1)
    L.margins(set, b.W)
    if b.post then b.post(set) end
  end
  -- normal: full set for design/preview
  local s = L.newset(totalW, H)
  b.fn(s)
  finish(s)
  s.save(name .. ".aseprite")
  s.s:close()
  -- export: background only + prop manifest (prop x/y stay relative to the old art; Godot offsets the background)
  local e = L.newset(totalW, H)
  e.exportMode = true
  b.fn(e)
  finish(e)
  e.s:saveCopyAs(GODOT .. "sets/" .. name .. ".png")
  local lines = {}
  for _, p in ipairs(e.props) do
    if not exported[p.piece] then
      L.exportPng(p.img, GODOT .. "props/" .. p.piece .. ".png")
      exported[p.piece] = true
    end
    lines[#lines + 1] = string.format('{"piece":"%s","x":%d,"y":%d,"sort":%s}', p.piece, p.x, p.y, tostring(p.sort))
  end
  local f = io.open(GODOT .. "sets/" .. name .. "_props.json", "w")
  f:write("[\n" .. table.concat(lines, ",\n") .. "\n]\n")
  f:close()
  e.s:close()
  print(name .. ": " .. #e.props .. " props, canvas " .. totalW .. "x" .. H .. ", margin " .. L.XOFF)
  ::continue::
end
if not ONLY or ONLY.warehouse then   -- R21c: the parking lot seen through the dock doorway (a prop under office/pieces, drawn behind the Background in Godot)
  L.exportPng(P.warehouseLot(), GODOT .. "props/warehouse_lot.png")
  L.savePiece(P.warehouseLot(), "warehouse_lot")
end
L.exportPng(P.deskPhoneHandset(), GODOT .. "props/desk_phone_handset.png")
L.writeRackLayout(GODOT .. "props/network_rack_layout.json")
L.YOFF = 0
L.XOFF = 0
