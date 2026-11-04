-- Renders the character creator's head OVERLAY sheets (roadmap R15 level 3 step b): for every accessory layer of
-- office/accessories.aseprite (glasses_thin ... beard_full), on the intern's head, all 123 poses of tools/poses.lua through the
-- animation engine, cropped to a fixed 32x32 cell centred on the Face layer's box (so the cell tracks the head in every pose: tilt,
-- hurt, death, dance, the seated gestures). Output, in godot/assets/accessories/:
--   <slot>_<id>_<facing>.png   123 cells wide x 32 tall, one per accessory per facing (the left head is the mirror of the right)
--   head_origin_<facing>.json  123 [x, y] pairs: the cell's top left in canvas coords of the 64x80 body frame (shared by all accessories)
-- The accessory layers are added with E.addLayer(..., true): rotated and shifted like the head but NOT measured for the death frames'
-- union shift, so the cell moves with the head exactly as the body does (a tall hat could not shift it). Where the near arm is drawn on
-- the Arm Top layer (a hand to the face, a scratch) its pixels are pasted into the cell wherever they cover an accessory pixel, so the
-- hand stays on top of the glasses.
--   ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_head_sheets.lua")        (Aseprite.exe -b --script x.lua)
-- REF = {"glasses_round", "beard_full"}: also build one-off reference characters for the golden test (tests/accessories.gd): the
-- intern sheet WITH that accessory as an ordinary layer above Hair (below Arm Top, measured for the death shift like any layer):
-- godot/tests/golden/ref_<name>_<facing>.png, 123 frames of 64x80.
local R = ROOT or "D:/creative/pixelproject/"
local T = R .. "tools/"
local OUT = R .. "godot/assets/accessories/"
local GOLD = R .. "godot/tests/golden/"
local SP = dofile(T .. "sprite_path.lua")
local E = dofile(T .. "anim.lua")
local poses = dofile(T .. "poses.lua")
local CELL = 32
local CW, CH = 64, 80
local function A(v) return app.pixelColor.rgbaA(v) end

local function mirror(im)
  local out = Image(im.width, im.height, ColorMode.RGB)
  for y = 0, im.height - 1 do for x = 0, im.width - 1 do out:putPixel(im.width - 1 - x, y, im:getPixel(x, y)) end end
  return out
end

-- the accessory layers of the source file, in file order: {name, image (right facing, 40x64)}
local function loadAccessories()
  local spr = Sprite{fromFile = R .. "office/accessories.aseprite"}
  local list = {}
  for _, l in ipairs(spr.layers) do
    if l.name:match("^%a+_%a+$") and l:cel(1) then
      local im = Image(spr.width, spr.height, ColorMode.RGB)
      im:drawImage(l:cel(1).image, l:cel(1).position)
      list[#list + 1] = {name = l.name, img = im}
    end
  end
  spr:close()
  return list
end

local function bbox(M)
  local x0, y0, x1, y1 = 1e9, 1e9, -1, -1
  for y = 0, M.height - 1 do for x = 0, M.width - 1 do
    if A(M:getPixel(x, y)) > 0 then
      if x < x0 then x0 = x end; if x > x1 then x1 = x end
      if y < y0 then y0 = y end; if y > y1 then y1 = y end
    end
  end end
  return x0, y0, x1, y1
end

local acc = loadAccessories()
local refSet = {}
for _, n in ipairs(REF or {}) do refSet[n] = true end
local report = {}

for _, side in ipairs({"right", "left"}) do
  local f = side == "right" and 1 or -1
  local an = E.load(SP(R, "office_intern_" .. side))
  local nBody = #an.layers
  local faceIdx
  for i, L in ipairs(an.layers) do if L.name == "Face" then faceIdx = i end end
  assert(faceIdx, "no Face layer")
  local accIdx = {}
  for _, a in ipairs(acc) do
    local im = side == "right" and a.img or mirror(a.img)
    E.addLayer(an, a.name, im, true)
    accIdx[a.name] = #an.layers
  end
  local topIdx = nBody + #acc + 1      -- E.render appends the Arm Top layer after every layer
  local sheets = {}
  for _, a in ipairs(acc) do sheets[a.name] = Image(CELL * #poses, CELL, ColorMode.RGB) end
  local origins = {}
  local worst = 0
  for fi, pose in ipairs(poses) do
    local out = E.render(an, pose, f)
    local x0, y0, x1, y1 = bbox(out[faceIdx])
    assert(x1 >= 0, "empty face layer in pose " .. fi)
    local ox = math.floor((x0 + x1 + 1) / 2) - CELL // 2
    local oy = math.floor((y0 + y1 + 1) / 2) - CELL // 2
    origins[fi] = {ox, oy}
    local top = out[topIdx]
    for _, a in ipairs(acc) do
      local src = out[accIdx[a.name]]
      -- every accessory pixel must land inside the cell
      local ax0, ay0, ax1, ay1 = bbox(src)
      if ax1 >= 0 then
        local o = math.max(ox - ax0, ax1 - (ox + CELL - 1), oy - ay0, ay1 - (oy + CELL - 1))
        if o > worst then worst = o end
      end
      local cell = Image(CELL, CELL, ColorMode.RGB)
      cell:drawImage(src, Point(-ox, -oy))
      for y = 0, CELL - 1 do for x = 0, CELL - 1 do
        if A(cell:getPixel(x, y)) > 0 then
          local cx, cy = x + ox, y + oy
          if cx >= 0 and cx < CW and cy >= 0 and cy < CH then
            local t = top:getPixel(cx, cy)
            if A(t) > 0 then cell:putPixel(x, y, t) end
          end
        end
      end end
      sheets[a.name]:drawImage(cell, Point((fi - 1) * CELL, 0))
    end
  end
  assert(worst <= 0, "an accessory pixel leaves its cell by " .. worst)
  for _, a in ipairs(acc) do
    local p = OUT .. a.name .. "_" .. side .. ".png"
    sheets[a.name]:saveAs(p)
    report[#report + 1] = string.format("%-26s %6d bytes", a.name .. "_" .. side .. ".png", app.fs.fileSize(p))
  end
  local parts = {}
  for i, o in ipairs(origins) do parts[i] = string.format("[%d,%d]", o[1], o[2]) end
  local jf = io.open(OUT .. "head_origin_" .. side .. ".json", "wb")
  jf:write("[" .. table.concat(parts, ",") .. "]\n")
  jf:close()
  print(side, #poses, "cells")

  -- one-off reference characters (the accessory is a real, measured layer)
  for _, a in ipairs(acc) do
    if refSet[a.name] then
      local ref = E.load(SP(R, "office_intern_" .. side))
      E.addLayer(ref, a.name, side == "right" and a.img or mirror(a.img), false)
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
      local p = GOLD .. "ref_" .. a.name .. "_" .. side .. ".png"
      sheet:saveAs(p)
      report[#report + 1] = string.format("%-26s %6d bytes", "ref_" .. a.name .. "_" .. side .. ".png", app.fs.fileSize(p))
    end
  end
end
for _, l in ipairs(report) do print(l) end
