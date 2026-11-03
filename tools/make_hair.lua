-- Builds the custom person's hairstyle variants (roadmap R15, character creator level 2): for each style, a copy of the
-- teen's stills (office_teen_right / _left.aseprite) whose Hair layer is another character's Hair layer recoloured to the
-- teen hair colours (base 9a5124, highlight c47a38, outline untouched). Output: custom_teen_<style>_{right,left}.aseprite.
-- The style `side` is the teen's own hair: it needs no file (it is office_teen itself).
-- Then build the animations and sheets like any other character:
--   ONLY = {"custom_teen_short"}; dofile("D:/creative/pixelproject/tools/build_anims.lua")
-- add the names to EXTRA_CHARACTERS in make_godot.py (rerun it) and the style id to Look.HAIR_STYLES.
-- Run:  dofile("D:/creative/pixelproject/tools/make_hair.lua")   (via run_lua_script)
-- Set the global ONLY = {short = true} before dofile to build a subset; ROOT = "..." to work in another checkout.
local R = ROOT or "D:/creative/pixelproject/"
local BASE_HEX, HI_HEX = "9a5124", "c47a38"

-- style -> the donor character and its two hair colours (base, highlight)
local STYLES = {
  short = {src = "site_alan", base = "3e2c20", hi = "5a4232"},
  receding = {src = "office_adult", base = "74492a", hi = "b07a44"},
  curly = {src = "casual_garrison", base = "2a1c14", hi = "47301f"},
}

local function rgb(h)
  return app.pixelColor.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end

local function hairLayer(spr)
  for _, l in ipairs(spr.layers) do if l.name == "Hair" then return l end end
  error("no Hair layer")
end

local function build(style, c)
  for _, side in ipairs({"right", "left"}) do
    local donor = Sprite{fromFile = R .. c.src .. "_" .. side .. ".aseprite"}
    local dl = hairLayer(donor)
    local full = Image(donor.width, donor.height, ColorMode.RGB)
    full:drawImage(dl:cel(1).image, dl:cel(1).position)
    local base, hi = rgb(c.base), rgb(c.hi)
    for y = 0, full.height - 1 do for x = 0, full.width - 1 do
      local p = full:getPixel(x, y)
      if p == base then full:putPixel(x, y, rgb(BASE_HEX))
      elseif p == hi then full:putPixel(x, y, rgb(HI_HEX)) end
    end end
    donor:close()
    local spr = Sprite{fromFile = R .. "office_teen_" .. side .. ".aseprite"}
    local l = hairLayer(spr)
    spr:deleteCel(l:cel(1))
    spr:newCel(l, 1, full, Point(0, 0))
    spr:saveAs(R .. "custom_teen_" .. style .. "_" .. side .. ".aseprite")
    spr:close()
  end
  print("built", style)
end

for style, c in pairs(STYLES) do
  if not ONLY or ONLY[style] then build(style, c) end
end
