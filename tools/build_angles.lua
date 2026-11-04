-- Rebuilds the multi-angle piece files in office/pieces/ (frames tagged front / side, side faces right).
-- Covers every piece in lib.lua (side builders: P.*Side in lib.lua and side_views.lua).
-- Run: dofile("D:/creative/pixelproject/tools/build_angles.lua")
local TOOLS = (ROOT or "D:/creative/pixelproject/") .. "tools/"
local L = dofile(TOOLS .. "lib.lua")
local P = L.P

local function one(img) return {{"Piece", img}} end

local fp, sp = P.deskPhoneParts(), P.deskPhoneSideParts()
L.saveAngles("desk_phone", {
  {tag = "front", layers = {{"Cord", fp.cord}, {"Body", fp.body}, {"Handset", fp.handset}}},
  {tag = "side", layers = {{"Cord", sp.cord}, {"Body", sp.body}, {"Handset", sp.handset}}},
})
L.saveAngles("desk_open_64", {{tag = "front", layers = one(P.desk(64))}, {tag = "side", layers = one(P.deskSide(25))}})
L.saveAngles("desk_cubicle_74", {{tag = "front", layers = one(P.desk(74))}, {tag = "side", layers = one(P.deskSide(25))}})
L.saveAngles("desk_office_68", {{tag = "front", layers = one(P.desk(68))}, {tag = "side", layers = one(P.deskSide(25))}})
L.saveAngles("bookshelf", {{tag = "front", layers = one(P.bookshelf())}, {tag = "side", layers = one(P.bookshelfSide(12))}})
L.saveAngles("monitor", {{tag = "front", layers = one(P.monitor())}, {tag = "side", layers = one(P.monitorSide())}})
L.saveAngles("monitor_a", {{tag = "front", layers = one(P.monitorA())}, {tag = "side", layers = one(P.monitorASide())}})
L.saveAngles("monitor_b", {{tag = "front", layers = one(P.monitorB())}, {tag = "side", layers = one(P.monitorSide())}})
L.saveAngles("mouse", {{tag = "front", layers = one(P.mouse())}, {tag = "side", layers = one(P.mouse())}})
L.saveAngles("keyboard", {{tag = "front", layers = one(P.keyboard())}, {tag = "side", layers = one(P.keyboardSide())}})
L.saveAngles("chair_office", {{tag = "front", layers = one(P.chair())}, {tag = "side", layers = one(P.chairSide())}})

local function two(name, front, side) L.saveAngles(name, {{tag = "front", layers = one(front)}, {tag = "side", layers = one(side)}}) end
local CONF = {"#4A4D55", "#6A6E78", "#35373E"}

-- group A: furniture
two("chair_slipper_green", P.slipper(), P.slipperSide())
two("chair_conference", P.chair(CONF[1], CONF[2], CONF[3]), P.chairSide(CONF[1], CONF[2], CONF[3]))
two("conference_table", P.confTable(), P.confTableSide(36))
two("cubicle_shell", P.cubicleShell(), P.cubicleShellSide(70))

-- group B: appliances and fixtures
two("copier", P.copier(), P.copierSide())
two("cooler", P.cooler(), P.coolerSide())
two("fridge", P.fridge(), P.fridgeSide())
two("coffee_machine", P.coffee(), P.coffeeSide())
two("sink", P.sink(), P.sinkSide())
two("toilet", P.toilet(), P.toiletSide())
two("bath_sink", P.bathSink(), P.bathSinkSide())

-- group C: plants, doors, wall items
two("plant", P.plant(), P.plantSide())
two("plant_floor", P.floorPlant(), P.floorPlantSide())
two("door_glass_front", P.glassDoor(), P.glassDoorSide())
two("door_brown", P.slabDoor("#7A4A2B", "#62391F", "#8F5A38", "lever"), P.slabDoorSide("#7A4A2B", "#62391F", "#8F5A38", "lever"))
two("door_lightwood_bath", P.slabDoor("#DDB680", "#C79F68", "#EBCB9A", "black"), P.slabDoorSide("#DDB680", "#C79F68", "#EBCB9A", "black"))
two("tv", P.tv(), P.tvSide())
two("wall_screen", P.wallScreen(), P.wallScreenSide())
two("calendar", P.calendar(), P.calendarSide())
two("sticky_note", P.sticky(), P.stickySide())
two("mirror", P.mirror(), P.mirrorSide())
two("whiteboard", P.whiteboard(), P.whiteboardSide())
two("cabinets_upper", P.upperCabinets(), P.upperCabinetsSide())
two("cabinets_lower_counter", P.lowerCabinets(), P.lowerCabinetsSide())

-- office dressing
two("filing_cabinet", P.filingCabinet(), P.filingCabinetSide())
two("couch", P.couch(), P.couchSide())
two("picture_frame", P.frame(14, 18), P.frameSide(18))
two("wall_clock", P.clock(), P.clockSide())
print("angles built")
