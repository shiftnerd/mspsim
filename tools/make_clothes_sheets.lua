-- Renders the character creator's CLOTHES overlay sheets (roadmap R15 level 3 step f) and the golden test's reference characters.
-- Input: office/clothes.aseprite (tools/make_clothes.lua; right-facing pieces, the left sheets use the mirror), the bare base character
-- sprites/custom/custom_bare_<facing>.aseprite and the Hair layer of every hairstyle's own still. Every piece goes through the real
-- animation engine (tools/anim.lua, all 129 poses of tools/poses.lua, both facings) as an unmeasured layer (E.addLayer, acc = true), so
-- it moves exactly like the body part it belongs to and the death frames shift the body as they do for the intern.
-- Output, in godot/assets/clothes/, full 64x80 frames, 129 wide (the same cells and indices as the body sheet; no origin tables):
--   shirt_<id>_far_<facing>.png    the far sleeve   (rides on the far arm)
--   shirt_<id>_torso_<facing>.png  the shirt body, collar included
--   shirt_<id>_near_<facing>.png   the near sleeve  (rides on the near arm)
--   belt_belt_<facing>.png         the belt, over the shirt hem
--   bottom_<id>_<facing>.png       trousers / jeans / shorts / skirt (the Pants layer: hips and both legs)
--   shoes_<id>_<facing>.png        shoes, boots, sneakers
--   hair_<style>_<facing>.png      the hairstyle (the Hair layer of that style's own still)
-- CUT-OUTS. The pieces are drawn above or below ONE flat body sprite (the bare base), so a piece is cut where the baked order puts
-- body layers above it: the far sleeve is cut by Body, Near Arm, Watch, Face and the Arm Top layer; the shirt and the belt by Near Arm,
-- Watch, Face and Arm Top; the near sleeve by Watch (and Face when the arm is not on the Arm Top layer); the hair by Arm Top (a hand to the
-- head stays in front of it). Trousers and shoes go behind the body and need no cut. This is exact because every sleeve lies inside the bare
-- arm it covers and the draw order far sleeve < shirt < belt < near sleeve < hair is the baked one.
-- REF = {{name = "tee_jeans_sneakers_long", shirt = "tee", bottom = "jeans", shoes = "sneakers", hair = "long"}, ...} also writes the
-- reference characters godot/tests/golden/ref_<name>_<facing>.png: the bare base with the outfit's pieces as ordinary layers at their baked
-- positions (129 frames of 64x80); tests/clothes.gd checks that the overlay sprites composited on the bare sheet give the same pixels.
--   ROOT = "<checkout>/"; REF = {...}; dofile(ROOT .. "tools/make_clothes_sheets.lua")        (Aseprite.exe -b --script x.lua)
local R = ROOT or "D:/creative/pixelproject/"
local T = R .. "tools/"
local OUT = R .. "godot/assets/clothes/"
local GOLD = R .. "godot/tests/golden/"
local SP = dofile(T .. "sprite_path.lua")
local E = dofile(T .. "anim.lua")
local poses = dofile(T .. "poses.lua")
local CW, CH = 64, 80
local STYLES = {"side", "short", "receding", "curly", "long", "bob", "ponytail", "bun", "bald", "spiky"}
local function A(v) return app.pixelColor.rgbaA(v) end

local function mirror(im)
  local out = Image(im.width, im.height, ColorMode.RGB)
  for y = 0, im.height - 1 do for x = 0, im.width - 1 do out:putPixel(im.width - 1 - x, y, im:getPixel(x, y)) end end
  return out
end
local function layerImage(spr, l)
  local im = Image(spr.width, spr.height, ColorMode.RGB)
  if l:cel(1) then im:drawImage(l:cel(1).image, l:cel(1).position) end
  return im
end
local function hasPixels(im)
  for y = 0, im.height - 1 do for x = 0, im.width - 1 do if A(im:getPixel(x, y)) > 0 then return true end end end
  return false
end

-- the pieces of the source file: {name, slot, id, part, img (right facing)}
local pieces = {}
do
  local spr = Sprite{fromFile = R .. "office/clothes.aseprite"}
  for _, l in ipairs(spr.layers) do
    local slot, id, part = l.name:match("^(%a+)_(%a+)_?(%a*)$")
    if slot and l:cel(1) then
      pieces[#pieces + 1] = {name = l.name, slot = slot, id = id, part = part, img = layerImage(spr, l)}
    end
  end
  spr:close()
end
local byName = {}
for _, p in ipairs(pieces) do byName[p.name] = p end

local function hairOf(style, side)
  local still = style == "side" and "office_intern" or ("custom_intern_" .. style)
  local spr = Sprite{fromFile = SP(R, still .. "_" .. side)}
  local img
  for _, l in ipairs(spr.layers) do if l.name == "Hair" then img = layerImage(spr, l) end end
  spr:close()
  return img
end

-- how a piece is added to the engine: kind, options
local function addOpts(p, arm)
  if p.slot == "shirt" and p.part == "far" then return {kind = "wrist", arm = "F"} end
  if p.slot == "shirt" and p.part == "near" then return {kind = "wrist", arm = "N"} end
  if p.slot == "shirt" or p.slot == "belt" then return {kind = "torso"} end
  if p.slot == "bottom" then return {kind = "leg", leg = "pants"} end
  if p.slot == "shoes" then return {kind = "leg", leg = "shoes"} end
  error("unknown piece " .. p.name)
end

local function names(an)
  local idx = {}
  for i, L in ipairs(an.layers) do idx[L.name] = i end
  return idx
end

local function cover(out, mask, set)
  -- remove from `mask` (an Image copy) every pixel opaque in any of the images in `set`
  for _, S in ipairs(set) do
    for y = 0, CH - 1 do for x = 0, CW - 1 do
      if A(S:getPixel(x, y)) > 0 then mask:putPixel(x, y, 0) end
    end end
  end
end

local report = {}
for _, side in ipairs({"right", "left"}) do
  local f = side == "right" and 1 or -1
  local an = E.load(SP(R, "custom_bare_" .. side))
  local an2 = E.load(SP(R, "custom_bare_" .. side))   -- the same base without its Watch: what is on the Arm Top layer that is not the watch
  an2.by["Watch"].S = Image(an2.w, an2.h, ColorMode.RGB)
  local nBase = #an.layers
  local base = names(an)
  local items = {}   -- {name, idx, kind}
  for _, p in ipairs(pieces) do
    local img = side == "right" and p.img or mirror(p.img)
    E.addLayer(an, p.name, img, true, addOpts(p))
    items[#items + 1] = {name = p.name, slot = p.slot, part = p.part, idx = #an.layers}
  end
  for _, st in ipairs(STYLES) do
    if st ~= "bald" then
      E.addLayer(an, "hair_" .. st, hairOf(st, side), true, {kind = "head"})
      items[#items + 1] = {name = "hair_" .. st, slot = "hair", part = "", idx = #an.layers}
    end
  end
  local topIdx = #an.layers + 1
  local sheets = {}
  for _, it in ipairs(items) do sheets[it.name] = Image(CW * #poses, CH, ColorMode.RGB) end
  for fi, pose in ipairs(poses) do
    local out = E.render(an, pose, f)
    local out2 = E.render(an2, pose, f)
    local top = out[topIdx]
    local top2 = out2[#an2.layers + 1]
    -- what the Watch put on the Arm Top layer (the arm alone is top2)
    local watchTop = Image(CW, CH, ColorMode.RGB)
    for y = 0, CH - 1 do for x = 0, CW - 1 do
      local v = top:getPixel(x, y)
      if A(v) > 0 and (A(top2:getPixel(x, y)) == 0 or top2:getPixel(x, y) ~= v) then watchTop:putPixel(x, y, v) end
    end end
    local body, nearArm, watch, face = out[base["Body"]], out[base["Near Arm"]], out[base["Watch"]], out[base["Face"]]
    for _, it in ipairs(items) do
      local cell = Image(out[it.idx])
      if it.slot == "shirt" and it.part == "far" then cover(out, cell, {body, nearArm, watch, face, top})
      elseif (it.slot == "shirt" and it.part ~= "near") or it.slot == "belt" then cover(out, cell, {nearArm, watch, face, top})
      elseif it.slot == "hair" then cover(out, cell, {top}) end
      if it.slot == "shirt" and it.part == "near" then
        local set = {watch, watchTop}
        if not pose.armTop then set[#set + 1] = face end
        cover(out, cell, set)
      end
      sheets[it.name]:drawImage(cell, Point((fi - 1) * CW, 0))
    end
  end
  for _, it in ipairs(items) do
    local fname = it.name
    if it.slot == "shirt" then fname = "shirt_" .. it.name:match("^shirt_(%a+)_") .. "_" .. it.part end
    local p = OUT .. fname .. "_" .. side .. ".png"
    sheets[it.name]:saveAs(p)
    report[#report + 1] = string.format("%-34s %7d bytes", fname .. "_" .. side .. ".png", app.fs.fileSize(p))
  end
  print(side, #poses, "frames")

  -- the golden test's reference characters
  for _, o in ipairs(REF or {}) do
    local ref = E.load(SP(R, "custom_bare_" .. side))
    local function put(name, before, opts, img)
      opts = opts or {}
      opts.before = before
      E.addLayer(ref, name, side == "right" and img or mirror(img), true, opts)
    end
    local function piece(n) return assert(byName[n], "no piece " .. n).img end
    put("r_shoes", "Pants", {kind = "leg", leg = "shoes"}, piece("shoes_" .. o.shoes))
    put("r_pants", "Back Arm", {kind = "leg", leg = "pants"}, piece("bottom_" .. o.bottom))
    put("r_far", "Body", {kind = "wrist", arm = "F"}, piece("shirt_" .. o.shirt .. "_far"))
    put("r_torso", "Near Arm", {kind = "torso"}, piece("shirt_" .. o.shirt .. "_torso"))
    if o.bottom == "trousers" or o.bottom == "jeans" then put("r_belt", "Near Arm", {kind = "torso"}, piece("belt_belt")) end
    put("r_near", "Watch", {kind = "wrist", arm = "N", reftop = true}, piece("shirt_" .. o.shirt .. "_near"))
    if o.hair ~= "bald" then E.addLayer(ref, "r_hair", hairOf(o.hair, side), true, {kind = "head"}) end
    local nref = #ref.layers
    local sheet = Image(CW * #poses, CH, ColorMode.RGB)
    for fi, pose in ipairs(poses) do
      local out = E.render(ref, pose, f)
      local frame = Image(CW, CH, ColorMode.RGB)
      for i = 1, nref + 1 do
        if i > nref or ref.layers[i].vis then frame:drawImage(out[i], Point(0, 0)) end
      end
      sheet:drawImage(frame, Point((fi - 1) * CW, 0))
    end
    local p = GOLD .. "ref_" .. o.name .. "_" .. side .. ".png"
    sheet:saveAs(p)
    report[#report + 1] = string.format("%-34s %7d bytes", "ref_" .. o.name .. "_" .. side .. ".png", app.fs.fileSize(p))
  end
end
local total = 0
for _, l in ipairs(report) do print(l) end
