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
local SP = dofile(R .. "tools/sprite_path.lua")  -- character files live in sprites/<group>/
local BASE_HEX, HI_HEX = "9a5124", "c47a38"

-- style -> the donor character and its two hair colours (base, highlight)
local STYLES = {
  short = {src = "site_alan", base = "3e2c20", hi = "5a4232"},
  receding = {src = "office_adult", base = "74492a", hi = "b07a44"},
  curly = {src = "casual_garrison", base = "2a1c14", hi = "47301f"},
  -- drawn styles (R15 level 2 step 2). `ext`: rows from make_fem.lua (x, y = top left; B hair, C highlight, T tie = outline
  -- colour) added over Alan's short cap with a new 1 px outline. `spans`: a whole Hair layer drawn here (y -> {x0, x1} list,
  -- `hl` the highlight spans), outlined automatically. `empty`: no Hair layer pixels (the Body layer is the skull).
  -- The left file of a drawn style is the mirror of the right one.
  long = {src = "site_alan", base = "3e2c20", hi = "5a4232", x = 8, y = 13, ext = {
    "..BBB.", ".BBBBB", ".BBBBB", ".BCBBB", ".BBBBB", ".BBBBB", ".BBCBB", ".BBBBB", ".BBBBB", ".BCBBB", ".BBBBB", ".BBBBB",
    ".BBBBB", ".BBCBB", ".BBBBB", ".BBBB.", "..BBB.", "..BB..",
  }},
  bob = {src = "site_alan", base = "3e2c20", hi = "5a4232", x = 8, y = 13, ext = {
    "..BBB.", ".BBBBB", ".BBBBB", ".BCBBB", ".BBBBB", ".BBBBB", ".BBCBB", ".BBBBB", "..BBB.",
  }},
  ponytail = {src = "site_alan", base = "3e2c20", hi = "5a4232", x = 3, y = 5, ext = {
    "......BB.", ".....BBBB", "....TBBBB", "...BBBBB.", "...BBCBB.", "..BBBBB..", "..BBBB...", "..BBCB...", "..BBB....", "...BB....",
    "...BB....", "...B.....",
  }},
  bun = {src = "site_alan", base = "3e2c20", hi = "5a4232", x = 9, y = 0, ext = {
    "..BBBB..", ".BBCBBB.", ".BBBBBB.", "..BBBB..", "...TT...",
  }},
  bald = {empty = true},
  spiky = {
    spans = {
      [1] = {{15, 15}, {19, 19}, {23, 23}},
      [2] = {{11, 12}, {15, 16}, {19, 20}, {23, 24}, {27, 28}},
      [3] = {{11, 13}, {15, 17}, {19, 21}, {23, 25}, {27, 29}},
      [4] = {{11, 28}}, [5] = {{10, 29}}, [6] = {{10, 29}}, [7] = {{10, 29}},
      [8] = {{10, 26}}, [9] = {{10, 19}}, [10] = {{10, 14}}, [11] = {{10, 13}}, [12] = {{10, 12}},
    },
    hl = {[5] = {{15, 18}}, [3] = {{20, 20}}},
  },
}
local OUTLINE_HEX = "17121f"
local W = 40

local function mirror(im)
  local out = Image(im.width, im.height, ColorMode.RGB)
  for y = 0, im.height - 1 do for x = 0, im.width - 1 do out:putPixel(im.width - 1 - x, y, im:getPixel(x, y)) end end
  return out
end

-- 1 px outline on the four sides of every listed cell, only onto empty pixels
local function outlineCells(im, cells)
  local o = app.pixelColor.rgba(tonumber("17", 16), tonumber("12", 16), tonumber("1f", 16), 255)
  for _, p in ipairs(cells) do
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
      local nx, ny = p[1] + d[1], p[2] + d[2]
      if nx >= 0 and nx < im.width and ny >= 0 and ny < im.height and app.pixelColor.rgbaA(im:getPixel(nx, ny)) == 0 then
        im:putPixel(nx, ny, o)
      end
    end
  end
end

local function rgb(h)
  return app.pixelColor.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end

local function hairLayer(spr)
  for _, l in ipairs(spr.layers) do if l.name == "Hair" then return l end end
  error("no Hair layer")
end

-- the right facing Hair layer of a drawn style (full 40x64 image)
local function drawnRight(c)
  local full = Image(W, 64, ColorMode.RGB)
  if c.empty then return full end
  local base, hi = rgb(BASE_HEX), rgb(HI_HEX)
  local cells = {}
  if c.spans then
    for y, list in pairs(c.spans) do for _, s in ipairs(list) do for x = s[1], s[2] do
      full:putPixel(x, y, base); cells[#cells + 1] = {x, y}
    end end end
    for y, list in pairs(c.hl) do for _, s in ipairs(list) do for x = s[1], s[2] do full:putPixel(x, y, hi) end end end
  else
    local donor = Sprite{fromFile = SP(R, c.src .. "_right")}
    local dl = hairLayer(donor)
    full:drawImage(dl:cel(1).image, dl:cel(1).position)
    local b0, h0 = rgb(c.base), rgb(c.hi)
    for y = 0, full.height - 1 do for x = 0, full.width - 1 do
      local p = full:getPixel(x, y)
      if p == b0 then full:putPixel(x, y, base) elseif p == h0 then full:putPixel(x, y, hi) end
    end end
    donor:close()
    for r, row in ipairs(c.ext) do for col = 1, #row do
      local ch = row:sub(col, col)
      if ch ~= "." then
        local x, y = c.x + col - 1, c.y + r - 1
        full:putPixel(x, y, ch == "B" and base or (ch == "C" and hi or rgb(OUTLINE_HEX)))
        cells[#cells + 1] = {x, y}
      end
    end end
  end
  outlineCells(full, cells)
  return full
end

local function build(style, c)
  if c.empty or c.spans or c.ext then
    local right = drawnRight(c)
    for _, side in ipairs({"right", "left"}) do
      local full = side == "right" and right or mirror(right)
      local spr = Sprite{fromFile = SP(R, "office_teen_" .. side)}
      local l = hairLayer(spr)
      spr:deleteCel(l:cel(1))
      spr:newCel(l, 1, full, Point(0, 0))
      spr:saveAs(SP(R, "custom_teen_" .. style .. "_" .. side))
      spr:close()
    end
    print("built", style)
    return
  end
  for _, side in ipairs({"right", "left"}) do
    local donor = Sprite{fromFile = SP(R, c.src .. "_" .. side)}
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
    local spr = Sprite{fromFile = SP(R, "office_teen_" .. side)}
    local l = hairLayer(spr)
    spr:deleteCel(l:cel(1))
    spr:newCel(l, 1, full, Point(0, 0))
    spr:saveAs(SP(R, "custom_teen_" .. style .. "_" .. side))
    spr:close()
  end
  print("built", style)
end

for style, c in pairs(STYLES) do
  if not ONLY or ONLY[style] then build(style, c) end
end
