-- Renders the character creator's accessory OVERLAY sheets (roadmap R15 level 3 steps b, c, d): for every accessory layer of
-- office/accessories.aseprite (glasses_thin ... beard_full, hat_beanie ..., lanyard_conference, badge_name, watch_silver ...), on the
-- intern, every pose of tools/poses.lua through the animation engine, cropped to a fixed cell that follows the part of the body the
-- accessory belongs to in every pose (tilt, hurt, death, dance, the seated gestures). Output, in godot/assets/accessories/:
--   <slot>_<id>_<facing>.png    one cell per pose, wide x 32 tall (16 for the wrist), one per accessory per facing (left = mirror of right)
--   <kind>_origin_<facing>.json one [x, y] per pose pairs: the cell's top left in canvas coords of the 64x80 body frame, one table per KIND
-- of accessory, shared by all of that kind (head_origin_*.json is the step b file):
--   head   glasses, beard   a 32 cell centred on the Face layer's box
--   hat    hats             a 40 cell (a lying head carries a hat far from the face centre), HAT_UP px higher than the head cell
--   torso  lanyard, badge   a 32 cell centred on the Shirt layer's box; everything drawn above the shirt in the prebaked order (the
--                           near arm, the Watch, the Face and Hair of a head lying on the chest, the Arm Top layer) is CUT OUT of
--                           the cell, so a swinging arm covers the lanyard like it covers the shirt
--   wrist  watches          a 16 cell centred on the watch itself; it rides on the near arm of the right-facing sheet and on the far
--                           arm of the left one (the intern's own watch is on the viewer's left in both files)
-- The accessory layers are added with E.addLayer(..., true): positioned like the head / shirt / arm they belong to but NOT measured
-- for the death frames' union shift, so a tall hat cannot move the body and the cell moves with it exactly as the body does. Where
-- the near arm is drawn on the Arm Top layer (a hand to the face, a scratch) its pixels are pasted into a head / hat cell wherever
-- they cover an accessory pixel, so the hand stays on top of the glasses and the hat.
--   ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_head_sheets.lua")        (Aseprite.exe -b --script x.lua)
-- REF = {"glasses_round", "beard_full", "hat_cap"}: also build one-off reference characters for the golden test
-- (tests/accessories.gd): the intern sheet WITH that accessory as an ordinary layer (head: above Hair, measured for the death shift
-- like any layer; hat, torso, wrist: unmeasured as in the overlay, a torso piece under the near arm, a wrist piece on its arm):
-- godot/tests/golden/ref_<name>_<facing>.png, one frame per pose of 64x80.
local R = ROOT or "D:/creative/pixelproject/"
local T = R .. "tools/"
local OUT = R .. "godot/assets/accessories/"
local GOLD = R .. "godot/tests/golden/"
local SP = dofile(T .. "sprite_path.lua")
local E = dofile(T .. "anim.lua")
local poses = dofile(T .. "poses.lua")
local CW, CH = 64, 80
local KIND = {glasses = "head", beard = "head", hat = "hat", badge = "torso", lanyard = "torso", watch = "wrist"}
local CELLSZ = {head = 32, hat = 48, torso = 32, wrist = 16}
local HAT_UP = 5
-- R15: the hat layers of office/accessories.aseprite live on a canvas with PX extra columns on both sides and PY extra rows on top
-- of the intern's 40x64 (tools/make_accessories.lua), so a hat can be 8+ px taller than the head. Every other layer is cropped back.
-- TOP extra rows above the 64x80 body frame are rendered (E.setTop) so a tall hat in the jump is not clipped at row 0; origins are
-- written in body-frame coordinates (minus TOP).
local PX, PY = 8, 12
local TOP = 14
E.setTop(TOP)
local KINDS = {"head", "hat", "torso", "wrist"}
local function A(v) return app.pixelColor.rgbaA(v) end

local function mirror(im)
  local out = Image(im.width, im.height, ColorMode.RGB)
  for y = 0, im.height - 1 do for x = 0, im.width - 1 do out:putPixel(im.width - 1 - x, y, im:getPixel(x, y)) end end
  return out
end

-- the left-facing watch: the far arm is 3 px wide (x9..11) where the near arm is 4 (x10..13): keep the right art's columns 11..13
local function wristLeft(im)
  local out = Image(im.width, im.height, ColorMode.RGB)
  for y = 0, im.height - 1 do for x = 11, 13 do out:putPixel(x - 2, y, im:getPixel(x, y)) end end
  return out
end

-- the accessory layers of the source file, in file order: {name, slot, kind, image (right facing, 40x64)}
local function loadAccessories()
  local spr = Sprite{fromFile = R .. "office/accessories.aseprite"}
  local list = {}
  for _, l in ipairs(spr.layers) do
    if l.name:match("^%a+_%a+$") and l:cel(1) then
      local im = Image(spr.width, spr.height, ColorMode.RGB)
      im:drawImage(l:cel(1).image, l:cel(1).position)
      local slot = l.name:match("^(%a+)_")
      assert(KIND[slot], "unknown accessory slot " .. slot)
      if slot ~= "hat" then
        local c = Image(spr.width - 2 * PX, spr.height - PY, ColorMode.RGB)
        c:drawImage(im, Point(-PX, -PY))
        im = c
      end
      list[#list + 1] = {name = l.name, slot = slot, kind = KIND[slot], img = im}
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

local function sideImage(a, side)
  if side == "right" then return a.img end
  if a.kind == "wrist" then return wristLeft(a.img) end
  return mirror(a.img)
end

for _, side in ipairs({"right", "left"}) do
  local f = side == "right" and 1 or -1
  local arm = side == "right" and "N" or "F"
  local an = E.load(SP(R, "office_intern_" .. side))
  local nBody = #an.layers
  local faceIdx, shirtIdx, nearIdx
  local above = {}   -- the layers drawn above a torso piece in the prebaked order (they cover it): Near Arm, Watch, Face, Hair
  for i, L in ipairs(an.layers) do
    if L.name == "Face" then faceIdx = i end
    if L.name == "Shirt" then shirtIdx = i end
    if L.name == "Near Arm" then nearIdx = i end
    if L.name == "Near Arm" or L.name == "Watch" or L.name == "Face" or L.name == "Hair" then above[#above + 1] = i end
  end
  assert(faceIdx and shirtIdx and nearIdx, "no Face / Shirt / Near Arm layer")
  local accIdx = {}
  for _, a in ipairs(acc) do
    E.addLayer(an, a.name, sideImage(a, side), true, {kind = a.kind == "hat" and "head" or a.kind, arm = arm, pad = a.kind == "hat" and {PX, PY} or nil})
    accIdx[a.name] = #an.layers
  end
  local topIdx = nBody + #acc + 1      -- E.render appends the Arm Top layer after every layer
  local sheets = {}
  for _, a in ipairs(acc) do sheets[a.name] = Image(CELLSZ[a.kind] * #poses, CELLSZ[a.kind], ColorMode.RGB) end
  local origins = {head = {}, hat = {}, torso = {}, wrist = {}}
  local used = {}
  for _, a in ipairs(acc) do used[a.kind] = true end
  local worst = 0
  for fi, pose in ipairs(poses) do
    local out = E.render(an, pose, f)
    local top = out[topIdx]
    -- the cell origin of every kind of accessory in this pose
    local fx0, fy0, fx1, fy1 = bbox(out[faceIdx])
    assert(fx1 >= 0, "empty face layer in pose " .. fi)
    local hx = math.floor((fx0 + fx1 + 1) / 2) - CELLSZ.head // 2
    local hy = math.floor((fy0 + fy1 + 1) / 2) - CELLSZ.head // 2
    local fcx = math.floor((fx0 + fx1 + 1) / 2)
    local fcy = math.floor((fy0 + fy1 + 1) / 2)
    local ORI = {head = {hx, hy}, hat = {fcx - CELLSZ.hat // 2, fcy - CELLSZ.hat // 2 - HAT_UP}}
    local sx0, sy0, sx1, sy1 = bbox(out[shirtIdx])
    assert(sx1 >= 0, "empty shirt layer in pose " .. fi)
    ORI.torso = {math.floor((sx0 + sx1 + 1) / 2) - CELLSZ.torso // 2, math.floor((sy0 + sy1 + 1) / 2) - CELLSZ.torso // 2}
    local wx0, wy0, wx1, wy1 = 1e9, 1e9, -1, -1
    for _, a in ipairs(acc) do
      if a.kind == "wrist" then
        local x0, y0, x1, y1 = bbox(out[accIdx[a.name]])
        if x1 >= 0 then
          wx0 = math.min(wx0, x0); wy0 = math.min(wy0, y0); wx1 = math.max(wx1, x1); wy1 = math.max(wy1, y1)
        end
      end
    end
    if wx1 >= 0 then
      ORI.wrist = {math.floor((wx0 + wx1 + 1) / 2) - CELLSZ.wrist // 2, math.floor((wy0 + wy1 + 1) / 2) - CELLSZ.wrist // 2}
    else
      ORI.wrist = {0, 0}
    end
    for _, k in ipairs(KINDS) do origins[k][fi] = {ORI[k][1], ORI[k][2] - TOP} end
    for _, a in ipairs(acc) do
      local C = CELLSZ[a.kind]
      local ox, oy = ORI[a.kind][1], ORI[a.kind][2]
      local src = out[accIdx[a.name]]
      -- every accessory pixel must land inside the cell
      local ax0, ay0, ax1, ay1 = bbox(src)
      if ax1 >= 0 then
        local o = math.max(ox - ax0, ax1 - (ox + C - 1), oy - ay0, ay1 - (oy + C - 1))
        if o > worst then worst = o end
        if o > 0 and WHERE then print("OUT", side, a.name, "pose", fi, poses[fi].name or "", "by", o, "box", ax0, ay0, ax1, ay1, "cell", ox, oy) end
      end
      local cell = Image(C, C, ColorMode.RGB)
      cell:drawImage(src, Point(-ox, -oy))
      for y = 0, C - 1 do for x = 0, C - 1 do
        if A(cell:getPixel(x, y)) > 0 then
          local cx, cy = x + ox, y + oy
          if cx >= 0 and cx < CW and cy >= 0 and cy < CH + TOP then
            if a.kind == "torso" then
              -- the near arm (and a hand raised on the Arm Top layer) is in front of the lanyard: cut it out
              local covered = A(top:getPixel(cx, cy)) > 0
              for _, li in ipairs(above) do
                if A(out[li]:getPixel(cx, cy)) > 0 then covered = true end
              end
              if covered then cell:putPixel(x, y, 0) end
            elseif a.kind ~= "wrist" then
              local t = top:getPixel(cx, cy)
              if A(t) > 0 then cell:putPixel(x, y, t) end
            end
          end
        end
      end end
      sheets[a.name]:drawImage(cell, Point((fi - 1) * C, 0))
    end
  end
  assert(worst <= 0, "an accessory pixel leaves its cell by " .. worst)
  for _, a in ipairs(acc) do
    local p = OUT .. a.name .. "_" .. side .. ".png"
    sheets[a.name]:saveAs(p)
    report[#report + 1] = string.format("%-26s %6d bytes", a.name .. "_" .. side .. ".png", app.fs.fileSize(p))
  end
  for _, k in ipairs(KINDS) do
    if used[k] then
      local parts = {}
      for i, o in ipairs(origins[k]) do parts[i] = string.format("[%d,%d]", o[1], o[2]) end
      local jf = io.open(OUT .. k .. "_origin_" .. side .. ".json", "wb")
      jf:write("[" .. table.concat(parts, ",") .. "]\n")
      jf:close()
    end
  end
  print(side, #poses, "cells")

  -- one-off reference characters (the head accessories are real, measured layers; the others are drawn as in the overlay)
  for _, a in ipairs(acc) do
    if refSet[a.name] then
      local ref = E.load(SP(R, "office_intern_" .. side))
      local opts = {kind = a.kind == "hat" and "head" or a.kind, arm = arm, reftop = true, pad = a.kind == "hat" and {PX, PY} or nil}
      if a.kind == "torso" then opts.before = "Near Arm" end
      E.addLayer(ref, a.name, sideImage(a, side), a.kind ~= "head", opts)
      local nref = #ref.layers
      local sheet = Image(CW * #poses, CH, ColorMode.RGB)
      for fi, pose in ipairs(poses) do
        local out = E.render(ref, pose, f)
        local frame = Image(CW, CH + TOP, ColorMode.RGB)
        for i = 1, nref + 1 do
          if i > nref or ref.layers[i].vis then frame:drawImage(out[i], Point(0, 0)) end
        end
        sheet:drawImage(frame, Point((fi - 1) * CW, -TOP))
      end
      local p = GOLD .. "ref_" .. a.name .. "_" .. side .. ".png"
      sheet:saveAs(p)
      report[#report + 1] = string.format("%-26s %6d bytes", "ref_" .. a.name .. "_" .. side .. ".png", app.fs.fileSize(p))
    end
  end
end
for _, l in ipairs(report) do print(l) end
