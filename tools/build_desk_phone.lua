-- Builds office/pieces/desk_phone.aseprite (layers: Cord, Body, Handset) from lib.lua's P.deskPhoneParts.
-- Run: dofile("D:/creative/pixelproject/tools/build_desk_phone.lua")
local TOOLS = "D:/creative/pixelproject/tools/"
local L = dofile(TOOLS .. "lib.lua")
local parts = L.P.deskPhoneParts()
local spr = Sprite(parts.body.width, parts.body.height, ColorMode.RGB)
local names = {{"Cord", parts.cord}, {"Body", parts.body}, {"Handset", parts.handset}}
for i, n in ipairs(names) do
  local layer = (i == 1) and spr.layers[1] or spr:newLayer()
  layer.name = n[1]
  spr:newCel(layer, 1, n[2], Point(0, 0))
end
spr:saveAs(L.BASE .. "pieces/desk_phone.aseprite")
print("saved", spr.width, spr.height)
