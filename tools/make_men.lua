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

-- the colours of office Dan, the donor for a man in a long-sleeve button-down (donor = "office_dan")
local base_dan = {
  shirt = {"#3C55C0", "#2C3F96"}, hair = {"#4A3222", "#6B4B34", "#3A2A1E"},
  pants = {"#8A6A42", "#6F5434", "#5A4328"}, shoes = {"#3A3A44", "#2A2A33"},
  skin = {"#F3B488", "#D88A62", "#B8663F"}, mouth = "#8A4A2E", undershirt = "#EDEDED", buttons = "#DDE3F5",
}

-- Entry fields: skin / hair {base, highlight, brow} / shirt {main, shade} / pants {main, far, shade} / shoes {near, far},
-- belt, stubble (a colour, or false for no shadow), lips; options: tufts, squint {lid, cheek}, grin, burn (colour),
-- goatee (colour), clerical (the collar tab), cross (the wood colour), lanyard (a conference-teal strap and badge),
-- glasses (Dan's frames), cap {main, shade} (a ball cap over the hair with a brim on the facing side), sleeves {main, shade}
-- (the arms in another colour than the shirt), patch (a small logo badge on the chest), donor = "office_dan" (long sleeves).
local CHARS = {
  expo_priest = {   -- Priest Michael (LabRat Nerds forum, MPriest): clerical black, an Australian face
    skin = {"#E6A47A", "#CC8058", "#A8603E"}, hair = {"#A07A4A", "#C49A62", "#7C5834"},
    shirt = {"#30303A", "#22222B"}, pants = {"#2A2A33", "#20202A", "#17171E"}, shoes = {"#3A3A44", "#2A2A33"},
    belt = "#15151B", stubble = "#D08C64", lips = "#8A4A2E",
    tufts = true, squint = {lid = "#9A583A"}, grin = true, burn = "#DC7458", goatee = "#7A5230",
    clerical = true, cross = "#B07A3E",
  },
  expo_grizzle = {   -- GrizzleAdmin (LabRat Nerds forum admin since 2008): the grumpy old-timer, grey tufts, a squint, a grey goatee, faded red flannel
    skin = {"#EDC4A4", "#D2A07E", "#B07E5E"}, hair = {"#B9B9C2", "#DADAE2", "#8E8E98"},
    shirt = {"#8A2E34", "#64202A"}, pants = {"#6A6350", "#544E3E", "#403B2E"}, shoes = {"#5A4632", "#42331F"},
    belt = "#3A2A1A", stubble = false, lips = "#9A5A48",
    tufts = true, squint = {lid = "#B58868"}, goatee = "#9A9AA4",
  },
  expo_pip = {   -- HELPPLZ_Pip (the newbie who posts everything in capitals): bright green tee, wild hair, a big open mouth
    skin = {"#F6C8A4", "#DE9E7A", "#BC7C58"}, hair = {"#2A2A34", "#44444F", "#1A1A22"},
    shirt = {"#4ED03E", "#37A02C"}, pants = {"#3A5A9A", "#2A4478", "#1E3258"}, shoes = {"#E8E8EE", "#B8B8C4"},
    belt = "#2A2A34", stubble = false, lips = "#B05A4A",
    tufts = true, grin = true,
  },
  expo_ray = {   -- RTFM_Ray (LabRat Nerds forum, the "read the manual" regular): black-framed glasses, an orange tee with a logo badge, khaki cargo trousers
    skin = {"#E8B48C", "#C98E66", "#A86C46"}, hair = {"#5A3A22", "#7A5230", "#3E2616"},
    shirt = {"#E0802A", "#B26018"}, pants = {"#8A7A5A", "#6E6044", "#544934"}, shoes = {"#3A3A44", "#2A2A33"},
    belt = "#3A2A1A", stubble = "#D69A72", lips = "#8A4A2E", glasses = true, patch = true,
  },
  office_adam = {   -- the senior tech and mentor: a shaved head, glasses, a light-blue polo, khakis
    skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#F3B488", "#F3B488", "#6B4B34"},
    shirt = {"#7FA6D8", "#5E86BC"}, pants = {"#B9A67E", "#948360", "#6E6046"}, shoes = {"#6A5240", "#4F3E30"},
    belt = "#3A2A1A", stubble = "#D69A72", lips = "#8A4A2E", glasses = true, bald = true,
  },
  office_john = {   -- sales: an olive ball cap, a goatee, a red fleece with grey sleeves, grey cargo pants
    skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#4A3222", "#6B4B34", "#3A2A1E"},
    shirt = {"#B8342E", "#8A2420"}, pants = {"#6A6F78", "#50545C", "#3A3D44"}, shoes = {"#3A3A44", "#2A2A33"},
    belt = "#2A2A33", stubble = "#D69A72", lips = "#8A4A2E", goatee = "#2E2018", cap = {"#6E7A4A", "#55603A"},
    sleeves = {"#7A7F88", "#5E626A"},
  },
  office_michael = {   -- a tech: a bright blue long-sleeve button-down with a logo badge, black trousers and shoes
    donor = "office_dan",
    skin = {"#7A4A30", "#623A24", "#4A2A18"}, hair = {"#1E1A1A", "#2E2828", "#1A1414"},
    shirt = {"#4A86D8", "#3566B0"}, pants = {"#24252C", "#1B1C22", "#131419"}, shoes = {"#1E1E24", "#14141A"},
    lips = "#5A2E22", buttons = "#CFE0F6", patch = true,
  },
  office_trent = {   -- Trent Dagmar of ByteBrothers, the rival recruiter: slate button-down, slicked dark hair, grey trousers, sharp black shoes
    donor = "office_dan",
    skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#241C18", "#3A2E28", "#1A1410"},
    shirt = {"#3E4A5E", "#2C3646"}, pants = {"#4A4E58", "#383C46", "#2A2D36"}, shoes = {"#1E1E24", "#14141A"},
    lips = "#8A4A2E", buttons = "#C8D0DC",
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
  local donor = c.donor or "site_alan"
  local base = donor == "office_dan" and base_dan or base
  local spr = Sprite{fromFile = SP(R, donor .. "_right")}
  local map = {}
  for i = 1, 3 do
    map[hex(base.hair[i])] = hex(c.hair[i]); map[hex(base.pants[i])] = hex(c.pants[i]); map[hex(base.skin[i])] = hex(c.skin[i])
  end
  map[hex(base.shirt[1])] = hex(c.shirt[1]); map[hex(base.shirt[2])] = hex(c.shirt[2])
  map[hex(base.shoes[1])] = hex(c.shoes[1]); map[hex(base.shoes[2])] = hex(c.shoes[2])
  map[hex(base.mouth)] = hex(c.lips)
  if base.belt then map[hex(base.belt)] = hex(c.belt) end
  if base.undershirt then map[hex(base.undershirt)] = hex(c.shirt[1]) end   -- a closed collar: no white tee showing
  if base.buttons and c.buttons then map[hex(base.buttons)] = hex(c.buttons) end
  local sl = layer(spr, "Stubble")
  if sl then
    if c.stubble then map[hex(base.stubble)] = hex(c.stubble) else spr:deleteLayer(sl) end
  end
  if donor == "office_dan" and not c.glasses then spr:deleteLayer(layer(spr, "Glasses")) end
  recolor(spr, map)
  local face = layer(spr, "Face"):cel(1).image
  local hair = layer(spr, "Hair"):cel(1).image
  local col = layer(spr, "Collar"):cel(1).image

  -- bald: no hair layer at all; the head outline underneath (the Body layer) is the whole skull
  if c.bald then
    hair:clear()
    local body = layer(spr, "Body"):cel(1).image   -- round the two top corners of the skull
    for y = 0, H - 1 do
      local x0, x1
      for x = 0, W - 1 do if app.pixelColor.rgbaA(body:getPixel(x, y)) > 0 then x0 = x0 or x; x1 = x end end
      if x0 then body:putPixel(x0, y, 0); body:putPixel(x1, y, 0); break end
    end
  end

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

  -- a ball cap: the top of the hair layer becomes the crown, and a brim sticks out over the brow on the facing side
  if c.cap then
    local hi, sh, k = hex(c.cap[1]), hex(c.cap[2]), hex(OUT)
    for y = 1, 9 do for x = 0, W - 1 do
      local p = hair:getPixel(x, y)
      if app.pixelColor.rgbaA(p) > 0 and p ~= k then put(hair, x, y, (y <= 2 or y >= 8) and sh or hi) end
    end end
    for y = 9, 10 do for x = 22, 33 do put(hair, x, y, y == 9 and sh or hi) end end   -- the brim
    for x = 22, 34 do put(hair, x, 11, k) end
    put(hair, 34, 9, k); put(hair, 34, 10, k); put(hair, 22, 10, k)
  end

  -- sleeves in their own colour (a fleece with grey sleeves)
  if c.sleeves then
    for _, ln in ipairs({"Near Arm", "Back Arm"}) do
      local im = layer(spr, ln):cel(1).image
      for y = 0, im.height - 1 do for x = 0, im.width - 1 do
        local p = im:getPixel(x, y)
        if p == hex(c.shirt[1]) then im:putPixel(x, y, hex(c.sleeves[1])) elseif p == hex(c.shirt[2]) then im:putPixel(x, y, hex(c.sleeves[2])) end
      end end
    end
  end

  -- a small logo badge on the chest (white card, a green and blue mark)
  if c.patch then
    for y = 29, 31 do for x = 24, 27 do put(col, x, y, hex("#F2F2EA")) end end
    put(col, 24, 30, hex("#3E9E4E")); put(col, 25, 30, hex("#3E9E4E")); put(col, 26, 30, hex("#2E6EB8")); put(col, 27, 30, hex("#2E6EB8"))
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

  if c.glasses and donor ~= "office_dan" then
    local dan = Sprite{fromFile = SP(R, "office_dan_right")}
    local gnew = spr:newLayer(); gnew.name = "Glasses"
    spr:newCel(gnew, 1, layer(dan, "Glasses"):cel(1).image:clone(), Point(0, 0))
    dan:close()
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
