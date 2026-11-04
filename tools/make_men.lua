-- Builds extra MEN from the shared 40x64 body (site_alan_right.aseprite): the same layers, so every animation works.
-- It is the male twin of make_fem.lua: recolour skin / hair / shirt / trousers / shoes, then the optional features of the
-- entry (a goatee on its own Beard layer, messy tufts of hair, a squint with a grin, sunburn, a clerical collar tab, a cross
-- on a cord, a conference lanyard). The left-facing file is the mirror of the right one.
-- Run:  ROOT = "<checkout>/"; ONLY = {"expo_priest"}; dofile(ROOT .. "tools/make_men.lua")  via run_lua_script,
-- then ONLY = {"expo_priest"}; dofile(ROOT .. "tools/build_anims.lua").  To add a man: add an entry to CHARS.
local R = ROOT or "D:/creative/pixelproject/"  -- set the global ROOT = "<checkout>/" to work in a worktree
local SP = dofile(R .. "tools/sprite_path.lua")  -- character files live in sprites/<group>/
local OUT = "#17121F"
local W, H = 40, 64

local function hex(h)
  local r, g, b = h:match("#(%x%x)(%x%x)(%x%x)")
  return app.pixelColor.rgba(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), 255)
end

-- the colours of site Alan, the donor
local base = {
  shirt = {"#4E535B", "#383C43", "#A8AEB8"}, hair = {"#3E2C20", "#5A4232", "#6B3416"},
  pants = {"#3F5E8E", "#2F4A73", "#243A5C"}, shoes = {"#6E7A68", "#55604F"},
  skin = {"#F3B488", "#D88A62", "#B8663F"}, mouth = "#8A4A2E", belt = "#5A3A22", stubble = "#D69A72",
}

-- Entry fields: skin / hair {base, highlight, brow} / shirt {main, shade} / pants {main, far, shade} / shoes {near, far},
-- belt, stubble (a colour, or false for no shadow), lips; options: tufts, squint {lid, cheek}, grin, burn (colour),
-- goatee (colour), clerical (the collar tab), cross (the wood colour), lanyard (a conference-teal strap and badge).
local CHARS = {
  expo_priest = {   -- Priest Michael (LabRat Nerds forum, MPriest): clerical black, an Australian face
    skin = {"#E6A47A", "#CC8058", "#A8603E"}, hair = {"#A07A4A", "#C49A62", "#7C5834"},
    shirt = {"#30303A", "#22222B"}, pants = {"#2A2A33", "#20202A", "#17171E"}, shoes = {"#3A3A44", "#2A2A33"},
    belt = "#15151B", stubble = "#D08C64", lips = "#8A4A2E",
    tufts = true, squint = {lid = "#9A583A"}, grin = true, burn = "#DC7458", goatee = "#7A5230",
    clerical = true, cross = "#B07A3E",
  },
}

local function put(im, x, y, c)
  if x >= 0 and x < W and y >= 0 and y < H then im:putPixel(x, y, c) end
end

local function recolor(spr, map)
  for _, l in ipairs(spr.layers) do
    local cel = l:cel(1)
    if cel then
      local im = cel.image
      for y = 0, im.height - 1 do for x = 0, im.width - 1 do
        local p = im:getPixel(x, y)
        if app.pixelColor.rgbaA(p) > 0 then
          local key = app.pixelColor.rgba(app.pixelColor.rgbaR(p), app.pixelColor.rgbaG(p), app.pixelColor.rgbaB(p), 255)
          local n = map[key]
          if n then im:putPixel(x, y, n) end
        end
      end end
    end
  end
end

local function layer(spr, name)
  for _, l in ipairs(spr.layers) do if l.name == name then return l end end
end

local function newLayer(spr, name)
  local l = spr:newLayer(); l.name = name
  spr:newCel(l, 1, Image(W, H, ColorMode.RGB), Point(0, 0))
  return l:cel(1).image
end

local function build(name, c)
  local spr = Sprite{fromFile = SP(R, "site_alan_right")}
  local map = {}
  for i = 1, 3 do
    map[hex(base.hair[i])] = hex(c.hair[i]); map[hex(base.pants[i])] = hex(c.pants[i]); map[hex(base.skin[i])] = hex(c.skin[i])
  end
  map[hex(base.shirt[1])] = hex(c.shirt[1]); map[hex(base.shirt[2])] = hex(c.shirt[2])
  map[hex(base.shoes[1])] = hex(c.shoes[1]); map[hex(base.shoes[2])] = hex(c.shoes[2])
  map[hex(base.mouth)] = hex(c.lips); map[hex(base.belt)] = hex(c.belt)
  if c.stubble then map[hex(base.stubble)] = hex(c.stubble) else spr:deleteLayer(layer(spr, "Stubble")) end
  recolor(spr, map)
  local face = layer(spr, "Face"):cel(1).image
  local hair = layer(spr, "Hair"):cel(1).image
  local col = layer(spr, "Collar"):cel(1).image

  -- messy hair: short tufts stick up from the top row (an outlined bump, 2 or 3 px wide)
  if c.tufts then
    for _, t in ipairs({{15, 17}, {20, 21}, {23, 24}}) do
      for x = t[1], t[2] do put(hair, x, 1, hex(c.hair[1])); put(hair, x, 0, hex(OUT)) end
    end
    put(hair, 16, 2, hex(c.hair[2])); put(hair, 21, 2, hex(c.hair[2])); put(hair, 24, 3, hex(c.hair[2]))
  end

  -- squint: the eye is 5x4 white; the top row becomes a lid line and the bottom row skin, so two rows of eye are left
  -- (the blink in anim.lua keeps the lid line and wipes the white)
  if c.squint then
    for _, e in ipairs({{19, 23}, {25, 28}}) do
      for x = e[1], e[2] do
        put(face, x, 12, hex(c.squint.lid))
        put(face, x, 15, 0)
      end
    end
  end

  -- cheeky brow: the far brow (nearest the front edge) sits one row higher
  if c.squint then
    for x = 25, 28 do put(face, x, 10, face:getPixel(x, 11)); put(face, x, 11, 0) end
  end

  -- grin: an open smile, a row of teeth between the two mouth corners and a lower lip line
  if c.grin then
    for x = 23, 26 do put(face, x, 19, 0) end
    put(face, 23, 19, hex(c.lips)); put(face, 27, 19, hex(c.lips))
    for x = 24, 26 do put(face, x, 19, hex("#F4F0E4")); put(face, x, 20, hex(c.lips)) end
  end

  -- sunburn: the nose and the cheek under the eye
  if c.burn then
    for _, p in ipairs({{27, 14}, {28, 14}, {27, 15}, {28, 15}, {28, 16}, {21, 16}, {22, 16}, {23, 16}, {22, 17}, {23, 17}}) do
      put(face, p[1], p[2], hex(c.burn))
    end
  end

  -- goatee on its own Beard layer (the technique of casual_garrison): a moustache over the mouth and a chin patch
  if c.goatee then
    local bd = newLayer(spr, "Beard")
    local g = hex(c.goatee)
    for x = 24, 26 do put(bd, x, 18, g) end                       -- moustache
    put(bd, 23, 20, g); put(bd, 27, 20, g)                        -- the lines beside the lower lip
    for x = 23, 27 do put(bd, x, 21, g) end                       -- chin patch, hanging one row below the jaw
    for x = 24, 26 do put(bd, x, 22, g); put(bd, x, 23, hex(OUT)) end
  end

  -- clerical collar: the collar layer is redrawn as a black band with a small white tab at the throat
  if c.clerical then
    col:clear()
    local k, w, skin = hex(c.shirt[2]), hex("#F4F2EA"), hex(c.skin[1])
    put(col, 18, 23, k); put(col, 19, 23, skin); put(col, 22, 23, skin); put(col, 23, 23, k)
    put(col, 20, 22, w); put(col, 21, 22, w); put(col, 20, 23, w); put(col, 21, 23, w)
    put(col, 19, 24, k); put(col, 20, 24, w); put(col, 21, 24, w); put(col, 22, 24, k)
    put(col, 20, 25, k); put(col, 21, 25, k)
  end

  -- a small wooden cross on a cord
  if c.cross then
    local cord, wood = hex("#B89A6A"), hex(c.cross)
    for _, p in ipairs({{18, 25}, {18, 26}, {19, 27}, {19, 28}, {20, 29}, {20, 30}, {24, 25}, {23, 26}, {23, 27}, {22, 28}, {22, 29}, {21, 30}}) do
      put(col, p[1], p[2], cord)
    end
    for y = 31, 34 do put(col, 20, y, wood) end
    for x = 19, 21 do put(col, x, 32, wood) end
    -- the cross hangs on the centre line x 20
  end

  spr:saveAs(SP(R, name .. "_right"))

  -- the left-facing file is the mirror: flip every cel, move it to the mirrored position
  local left = Sprite{fromFile = SP(R, name .. "_right")}
  for _, l in ipairs(left.layers) do
    local cel = l:cel(1)
    if cel then
      local im = cel.image
      local copy = im:clone()
      for y = 0, im.height - 1 do for x = 0, im.width - 1 do im:putPixel(im.width - 1 - x, y, copy:getPixel(x, y)) end end
      local oldx = cel.position.x
      cel.position = Point(W - oldx - im.width, cel.position.y)
    end
  end
  left:saveAs(SP(R, name .. "_left"))
  left:close()
  spr:close()
  print("built", name)
end

local want = {}
for k, v in pairs(ONLY or {}) do want[type(k) == "number" and v or k] = true end   -- ONLY = {"a"} or {a = true}
for name, c in pairs(CHARS) do
  if not ONLY or want[name] then build(name, c) end
end
