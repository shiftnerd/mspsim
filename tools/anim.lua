-- Pose engine for the 40x64 layered characters. Output canvas 64x80, feet on row 79.
local E = {}
local OX, OY, CW, CH = 12, 18, 64, 80
local GROUND = 61 + OY            -- canvas row of the shoe outline when planted
-- E.setTop(n): n extra rows ABOVE the canvas (the body is drawn n rows lower, the output is 64 x (80 + n)); only the accessory sheet
-- maker uses it, so a tall hat in the jump is not clipped at row 0. The anim files are built with n = 0.
local TOP = 0
local OUTLINE = {23, 18, 31}
local SKIN = {243, 180, 136}

local function A(v) return app.pixelColor.rgbaA(v) end
local function R(v) return app.pixelColor.rgbaR(v) end
local function G(v) return app.pixelColor.rgbaG(v) end
local function B(v) return app.pixelColor.rgbaB(v) end
local function rgba(r, g, b) return app.pixelColor.rgba(r, g, b, 255) end
local function round(x) return math.floor(x + 0.5) end
local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

local function isOutline(v) return R(v) == OUTLINE[1] and G(v) == OUTLINE[2] and B(v) == OUTLINE[3] end

local function mask(S, fn)
  local M = Image(S.width, S.height, ColorMode.RGB)
  for y = 0, S.height - 1 do
    for x = 0, S.width - 1 do
      local v = S:getPixel(x, y)
      if A(v) > 0 and fn(x, y) then M:putPixel(x, y, v) end
    end
  end
  return M
end

local function bbox(M)
  local x0, y0, x1, y1 = 1e9, 1e9, -1, -1
  for y = 0, M.height - 1 do
    for x = 0, M.width - 1 do
      if A(M:getPixel(x, y)) > 0 then
        if x < x0 then x0 = x end; if x > x1 then x1 = x end
        if y < y0 then y0 = y end; if y > y1 then y1 = y end
      end
    end
  end
  if x1 < 0 then return nil end
  return x0, y0, x1, y1
end

-- shift rows: dxFn(y) per source row, dy constant
local function blitShift(O, M, dxFn, dy)
  for y = 0, M.height - 1 do
    local dx = dxFn(y)
    for x = 0, M.width - 1 do
      local v = M:getPixel(x, y)
      if A(v) > 0 then
        local X, Y = x + OX + dx, y + OY + dy
        if X >= 0 and X < CW and Y >= 0 and Y < CH then O:putPixel(X, Y, v) end
      end
    end
  end
end

-- rotate M about source-space pivot (px,py) by deg (positive swings a hanging limb toward +x), then offset
local function blitRot(O, M, px, py, deg, dx, dy)
  local x0, y0, x1, y1 = bbox(M)
  if not x0 then return end
  if deg == 0 then
    blitShift(O, M, function() return dx end, dy)
    return
  end
  local rad = math.rad(deg)
  local c, s = math.cos(rad), math.sin(rad)
  local rmax = 0
  for _, p in ipairs({{x0, y0}, {x1 + 1, y0}, {x0, y1 + 1}, {x1 + 1, y1 + 1}}) do
    local d = math.sqrt((p[1] - px) ^ 2 + (p[2] - py) ^ 2)
    if d > rmax then rmax = d end
  end
  rmax = math.ceil(rmax) + 2
  local cx, cy = round(OX + dx + px), round(OY + dy + py)
  for Y = cy - rmax, cy + rmax do
    for X = cx - rmax, cx + rmax do
      if X >= 0 and X < CW and Y >= 0 and Y < CH then
        local u = X + 0.5 - OX - dx - px
        local v = Y + 0.5 - OY - dy - py
        local sx = math.floor(px + u * c - v * s)
        local sy = math.floor(py + u * s + v * c)
        if sx >= 0 and sx < M.width and sy >= 0 and sy < M.height then
          local val = M:getPixel(sx, sy)
          if A(val) > 0 then O:putPixel(X, Y, val) end
        end
      end
    end
  end
end

-- two-segment limb: the upper part rotates about (px,py); the lower part (rows >= ey) rotates about the joint
-- (ex,ey) by ang+rel and follows the joint. rel == 0 keeps the limb rigid (no seam).
local function limbRot(O, M, px, py, ex, ey, ang, rel, dx, dy)
  if rel == 0 then blitRot(O, M, px, py, ang, dx, dy); return end
  local up = mask(M, function(x, y) return y <= ey end)       -- 2 rows overlap at the joint so no seam opens
  local lo = mask(M, function(x, y) return y >= ey - 1 end)
  blitRot(O, up, px, py, ang, dx, dy)
  local rad = math.rad(ang)
  local c, s = math.cos(rad), math.sin(rad)
  local e0x, e0y = ex - px, ey - py
  local e1x, e1y = e0x * c + e0y * s, -e0x * s + e0y * c
  blitRot(O, lo, ex, ey, ang + rel, dx + (e1x - e0x), dy + (e1y - e0y))
end

-- squash a leg part: rows 47..50 move down c, rows 51..51+c-1 removed
local function compressLeg(M, c)
  if c <= 0 then return M end
  local N = Image(M.width, M.height, ColorMode.RGB)
  for y = 0, M.height - 1 do
    local ty
    if y >= 47 and y < 51 then ty = y + c
    elseif y >= 51 and y < 51 + c then ty = nil
    else ty = y end
    if ty and ty < M.height then
      for x = 0, M.width - 1 do
        local v = M:getPixel(x, y)
        if A(v) > 0 then N:putPixel(x, ty, v) end
      end
    end
  end
  return N
end

-- seated shin: rows past `at` move down n (the pants repeat row `at` n more times, so the calf grows; the shoes just drop)
local function stretchShin(M, n, at, dup)
  if not n or n <= 0 then return M end
  local N = Image(M.width, M.height + n, ColorMode.RGB)
  for y = 0, M.height - 1 do
    for x = 0, M.width - 1 do
      local v = M:getPixel(x, y)
      if A(v) > 0 then
        if y <= at then
          N:putPixel(x, y, v)
          if dup and y == at then for k = 1, n do N:putPixel(x, y + k, v) end end
        else
          N:putPixel(x, y + n, v)
        end
      end
    end
  end
  return N
end

local function faceVariant(S, kind)
  if kind == nil or kind == "normal" then return S end
  local F = Image(S)
  local wx0, wy0, wx1, wy1 = 1e9, 1e9, -1, -1
  for y = 0, F.height - 1 do for x = 0, F.width - 1 do
    local v = F:getPixel(x, y)
    if A(v) > 0 and R(v) == 255 and G(v) == 255 and B(v) == 255 then
      if x < wx0 then wx0 = x end; if x > wx1 then wx1 = x end
      if y < wy0 then wy0 = y end
      if y > wy1 then wy1 = y end
    end
  end end
  if wx1 < 0 then return S end
  local ly = wy0 + 2
  for y = wy0, wy1 do for x = wx0, wx1 do
    local v = F:getPixel(x, y)
    if A(v) > 0 and (R(v) == 255 or (R(v) == 58 and G(v) == 36)) then
      if y == ly then F:putPixel(x, y, rgba(58, 36, 24)) else F:putPixel(x, y, rgba(SKIN[1], SKIN[2], SKIN[3])) end
    end
  end end
  if kind == "hurt" then
    local mx0, my0, mx1 = 1e9, 1e9, -1
    for y = wy1 + 3, F.height - 1 do for x = 0, F.width - 1 do
      local v = F:getPixel(x, y)
      if A(v) > 0 and R(v) == 138 and G(v) == 74 and B(v) == 46 then
        if x < mx0 then mx0 = x end; if x > mx1 then mx1 = x end; if y < my0 then my0 = y end
      end
    end end
    if mx1 >= 0 then
      for y = my0, my0 + 2 do for x = mx0, mx1 do F:putPixel(x, y, rgba(58, 36, 24)) end end
      for x = mx0 + 1, mx1 - 1 do F:putPixel(x, my0 + 2, rgba(138, 74, 46)) end
    end
  end
  return F
end

local function flash(O, amt)
  for y = 0, O.height - 1 do for x = 0, O.width - 1 do
    local v = O:getPixel(x, y)
    if A(v) > 0 and not isOutline(v) then
      O:putPixel(x, y, rgba(R(v) + round((255 - R(v)) * amt), G(v) + round((255 - G(v)) * amt), B(v) + round((255 - B(v)) * amt)))
    end
  end end
end

-- analysis -----------------------------------------------------------------
function E.load(path)
  local spr = Sprite{fromFile = path}
  local an = {w = spr.width, h = spr.height, layers = {}, by = {}}
  for _, l in ipairs(spr.layers) do
    local S = Image(spr.width, spr.height, ColorMode.RGB)
    local c = l:cel(1)
    if c then S:drawImage(c.image, c.position) end
    local rec = {name = l.name, vis = l.isVisible, S = S}
    an.layers[#an.layers + 1] = rec; an.by[l.name] = rec
  end
  spr:close()
  local P = an.by["Pants"].S
  -- leg gap column
  local gap
  for x = 14, 26 do
    local ok = true
    for y = 50, 55 do
      if not (A(P:getPixel(x, y)) == 0 and A(P:getPixel(x - 1, y)) > 0 and A(P:getPixel(x + 1, y)) > 0) then ok = false end
    end
    if ok then gap = x; break end
  end
  assert(gap, "no leg gap found")
  an.gap = gap
  -- which half is the near (lighter) leg
  local function lum(x0, x1)
    local sum, n = 0, 0
    for y = 47, 57 do for x = x0, x1 do
      local v = P:getPixel(x, y)
      if A(v) > 0 and not isOutline(v) and R(v) > 40 then sum = sum + R(v) + G(v) + B(v); n = n + 1 end
    end end
    return n > 0 and sum / n or 0
  end
  an.leftNear = lum(0, gap - 1) >= lum(gap + 1, 39)
  -- shoe shared outline column
  local Sh = an.by["Shoes"].S
  local b
  for d = 0, 4 do
    for _, x in ipairs({gap + d, gap - d}) do
      local v = Sh:getPixel(x, 59)
      if not b and A(v) > 0 and isOutline(v) and A(Sh:getPixel(x - 1, 59)) > 0 and A(Sh:getPixel(x + 1, 59)) > 0 then b = x end
    end
  end
  assert(b, "no shoe boundary")
  an.sb = b
  -- pivots
  local function cxOf(M, y0, y1, x0, x1)
    local mn, mx = 1e9, -1
    for y = y0, y1 do for x = x0, x1 do if A(M:getPixel(x, y)) > 0 then if x < mn then mn = x end; if x > mx then mx = x end end end end
    return (mn + mx + 1) / 2
  end
  an.legL = cxOf(P, 49, 56, 0, gap - 1)
  an.legR = cxOf(P, 49, 56, gap + 1, 39)
  an.armN = cxOf(an.by["Near Arm"].S, 24, 27, 0, 39)
  an.armF = cxOf(an.by["Back Arm"].S, 24, 27, 0, 39)
  an.footX = (an.legL + an.legR) / 2
  an.headCx = cxOf(an.by["Body"].S, 12, 18, 0, 39)
  -- watch rides on whichever arm it overlaps
  an.watchOn = "N"
  if an.by["Watch"] then
    local wx0, _, wx1 = bbox(an.by["Watch"].S)
    if wx0 then
      local wc = (wx0 + wx1) / 2
      if math.abs(wc - an.armF) < math.abs(wc - an.armN) then an.watchOn = "F" end
    end
  end
  return an
end

function E.setTop(n)
  TOP = n
  OY = 18 + n
  CH = 80 + n
  GROUND = 61 + OY
end

-- an accessory layer (glasses, facial hair, hats ...) drawn only in the overlay sheets (tools/make_head_sheets.lua): it is
-- rotated and shifted like the head (headBlit) but NOT measured for the death frames' union shift, so a tall hat cannot move
-- the body. Add it after the character's own layers (the same idea as an.ghost, which is measured but not drawn).
-- Always a head layer (headBlit). acc = false only means it IS measured, like Glasses or Hair: the one-off reference characters of
-- the golden test are built that way (an accessory as a real layer of a prebaked character).
function E.addLayer(an, name, S, acc, opts)
  opts = opts or {}
  -- opts.kind: "head" (default: rotated like the head), "torso" (shifted like the shirt: lanyard, name sticker) or "wrist"
  -- (rides on an arm like the watch does: opts.arm "N" near arm or "F" far arm; opts.reftop draws it on the Arm Top layer when the arm is
  -- there, as the intern's own Watch layer is, for the golden reference characters only); opts.before = the name of a layer to go under;
  -- "leg" (a pair of trousers or shoes of its own, opts.leg "pants" or "shoes": rendered like the Pants / Shoes layers but from this
  -- image, per leg with the knee and crouch; the character creator's real clothes, tools/make_clothes_sheets.lua)
  local kind = opts.kind or "head"
  local rec = {name = name, vis = true, S = S, pad = opts.pad, head = kind == "head", acc = acc and true or nil, arm = kind == "wrist" and opts.arm or nil, reftop = opts.reftop,
    leg = kind == "leg" and opts.leg or nil}
  local at = #an.layers + 1
  if opts.before then
    for i, L in ipairs(an.layers) do if L.name == opts.before then at = i; break end end
  end
  table.insert(an.layers, at, rec)
  an.by[name] = rec
  return rec
end

-- rendering ----------------------------------------------------------------
local HEAD = {Face = true, Hair = true, Beard = true, Stubble = true, Glasses = true}

local function legParts(an, f, pose, Pover, Sover)
  -- returns list of {layerName, mask, pivotX, role} for both legs (Pover / Sover: a clothes piece's own pants or shoes image)
  local nearIsLeft = an.leftNear
  local parts = {}
  local c = pose.crouch or 0
  local Pn = Pover or an.by["Pants"].S
  local Sn = Sover or an.by["Shoes"].S
  local gap, sb = an.gap, an.sb
  local function add(role, left)
    local cx = left and an.legL or an.legR
    local pm = mask(Pn, function(x, y) return y >= 47 and (left and x < gap or (not left) and x > gap) end)
    pm = compressLeg(pm, c)
    local sm = mask(Sn, function(x, y) return left and x <= sb or (not left) and x >= sb end)
    if pose.shin and pose.shin > 0 then
      pm = stretchShin(pm, pose.shin, 55, true)
      sm = stretchShin(sm, pose.shin, 55, false)
    end
    parts[#parts + 1] = {role = role, cx = cx, pants = pm, shoes = sm}
  end
  if nearIsLeft then add("F", false); add("N", true) else add("F", true); add("N", false) end
  return parts
end

function E.render(an, pose, f)
  local lean0 = (pose.lean or 0) * f
  local lean = lean0 + (pose.leanAdd or 0) * f     -- seated: the sitter leans toward the desk; the keepN / keepF hand target ignores it
  local rootDx = round((pose.rx or 0) * f)
  -- pose.lift (the seated poses): the whole body above the legs moves up this many px relative to the feet (the hips sit on the seat,
  -- the legs bend under them); the shin / floor fields place the legs, the ground is measured with the un-stretched legs
  local lift = pose.lift or 0
  local bobDy = (pose.bob or 0) + (pose.crouch or 0) - lift
  local legs = legParts(an, f, pose)
  local legsG = legs
  if pose.shin then legsG = legParts(an, f, {crouch = pose.crouch}) end
  local function drawLegOf(P, O, M, p, dy0)
    local g = p.role == "N" and {P.lN or 0, P.lNl or 0, P.lNr or 0} or {P.lF or 0, P.lFl or 0, P.lFr or 0}
    limbRot(O, M, p.cx, 47, p.cx, P.kn or 54, g[1] * f, g[3] * f, rootDx + round(((P.legDx or 0) + ((p.role == "N" and P.lNx or p.role == "F" and P.lFx) or 0)) * f), dy0 - g[2] + (P.legDy or 0))
  end
  local adj = {N = 0, F = 0}   -- pose.floor: per-leg lift/drop that puts each sole on the ground row (set below)
  local function drawLeg(O, M, p, dy0) drawLegOf(pose, O, M, p, dy0 + adj[p.role]) end
  -- auto ground: render shoes only and measure the lowest row. pose.legRef (a table of leg fields) is the leg setup the ground
  -- is measured with: the seated poses bend the knee (legDy / kn) but keep the body exactly where the old straight-shin sit put it
  local rootDy = pose.ry or 0
  if pose.ground ~= false then
    local T = Image(CW, CH, ColorMode.RGB)
    for _, p in ipairs(legsG) do drawLegOf(pose.legRef or pose, T, p.shoes, p, 0) end
    local _, _, _, y1 = bbox(T)
    if y1 then rootDy = rootDy + (GROUND - y1) end
  end
  -- pose.floor (the seated poses): the body stays where legRef put it, then each leg is moved up or down so ITS shoe sole is on the
  -- ground row, whatever the knee height / thigh angle (a bent knee with the foot flat on the floor)
  if pose.floor then
    for _, p in ipairs(legs) do
      local T = Image(CW, CH, ColorMode.RGB)
      drawLegOf(pose, T, p.shoes, p, rootDy)
      local _, _, _, y1 = bbox(T)
      if y1 then adj[p.role] = GROUND - y1 end
    end
  end
  local out = {}
  local function torsoDx(y) return round(lean * clamp((38 - y) / 14, 0, 1)) + rootDx end
  local headDx = round(lean) + round((pose.hx or 0) * f) + rootDx
  local headDy = bobDy + (pose.hy or 0) + rootDy
  local torsoDy = bobDy + rootDy
  local armDx = rootDx + round(lean * 0.9)
  local armDx0 = rootDx + round(lean0 * 0.9)
  local armLen = pose.armLen or 0     -- seated: the forearm is this many rows longer (a bent arm has to reach the desk from a raised shoulder)
  local function armS(S, dup) return armLen > 0 and stretchShin(S, armLen, 35, dup) or S end
  -- pad = {px, py}: the image has px extra columns on the left and py extra rows on top (a tall hat); the head's pivot moves with it
  local function headBlit(O, M, pad)
    local hr = (pose.hrot or 0) * f
    local px, py = pad and pad[1] or 0, pad and pad[2] or 0
    if hr == 0 then
      blitShift(O, M, function() return headDx - px end, headDy - py)
    else
      blitRot(O, M, an.headCx + px, 22 + py, hr, headDx - px, headDy - py)
    end
  end
  -- where an arm's hand grips (canvas coords, float): the near hand attaches held items (and the hands json); `ang` / `rel` are the
  -- signed angles (already times the facing)
  local function rot(a, b, deg)
    local r = math.rad(deg)
    return a * math.cos(r) + b * math.sin(r), -a * math.sin(r) + b * math.cos(r)
  end
  local ay1Cache = {}
  local function tipOf(near, ang, rel, tdy, adx)
    local ax = near and an.armN or an.armF
    local ay1 = ay1Cache[near]
    if ay1 == nil then
      local _, _, _, y1 = bbox(armS(an.by[near and "Near Arm" or "Back Arm"].S, true))
      ay1 = y1 or false
      ay1Cache[near] = ay1
    end
    local hx0, hy0 = ax, (ay1 or 41) - 2
    local hx, hy
    if rel == 0 then
      local a, b = rot(hx0 - ax, hy0 - 25, ang)
      hx, hy = ax + a, 25 + b
    else
      local ex, ey = rot(0, 9, ang)
      local a, b = rot(hx0 - ax, hy0 - 34, ang + rel)
      hx, hy = ax + ex + a, 25 + ey + b
    end
    return hx + OX + adx, hy + OY + tdy
  end
  -- pose.keepN / pose.keepF (the seated poses): the body is `lift` px higher than it used to be, but the hand stays where the
  -- un-lifted pose put it (on the keys, the mouse, the desk): the two arm angles are re-solved so the hand tip lands on the same pixel
  if lift ~= 0 and (pose.keepN or pose.keepF) then
    local np = {}
    for k, v in pairs(pose) do np[k] = v end
    for _, near in ipairs({true, false}) do
      if (near and pose.keepN) or ((not near) and pose.keepF) then
        local kA, kR = near and "aN" or "aF", near and "aNr" or "aFr"
        local a0, r0 = (pose[kA] or 0), (pose[kR] or 0)
        local tx, ty = tipOf(near, a0 * f, r0 * f, torsoDy + lift, armDx0)
        local best, ba, br = 1e18, a0, r0
        -- the search is the same for every pose / character with these numbers: cache it
        local _, _, _, cy1 = bbox(an.by[near and "Near Arm" or "Back Arm"].S)
        local ckey = table.concat({near and 1 or 0, a0, r0, f, near and an.armN or an.armF, cy1 or -1, torsoDy, lift, armDx, armDx0, armLen}, ",")
        E.ik = E.ik or {}
        local hit = E.ik[ckey]
        if hit then np[kA], np[kR] = hit[1], hit[2] else
        local function try(a, r)
          local x, y = tipOf(near, a * f, r * f, torsoDy, armDx)
          local c = (x - tx) ^ 2 + (y - ty) ^ 2 + 0.0004 * ((a - a0) ^ 2 + (r - r0) ^ 2)
          if c < best then best, ba, br = c, a, r end
        end
        for a = a0 - 45, a0 + 60, 3 do for r = r0 - 60, r0 + 60, 3 do try(a, r) end end
        local ca, cr = ba, br
        for a = ca - 3, ca + 3 do for r = cr - 3, cr + 3 do try(a, r) end end
        np[kA], np[kR] = ba, br
        E.ik[ckey] = {ba, br}
        end
      end
    end
    pose = np
  end
  local hand
  do
    local hx, hy = tipOf(true, (pose.aN or 0) * f, (pose.aNr or 0) * f, torsoDy, armDx)
    hand = {round(hx), round(hy)}
  end
  -- pose.armTop: the near arm is drawn on the extra top layer "Arm Top" (above Face / Hair / Vest), so a hand can come up
  -- to the face or head instead of disappearing behind it
  local top = Image(CW, CH, ColorMode.RGB)
  for _, L in ipairs(an.layers) do
    local O = Image(CW, CH, ColorMode.RGB)
    local S = L.S
    local n = L.name
    if n == "Face" then S = faceVariant(S, pose.face) end
    if L.leg then
      local lp = L.leg == "pants" and legParts(an, f, pose, S, nil) or legParts(an, f, pose, nil, S)
      for _, p in ipairs(lp) do drawLeg(O, L.leg == "pants" and p.pants or p.shoes, p, rootDy) end
      if L.leg == "pants" then blitShift(O, mask(S, function(x, y) return y <= 46 end), torsoDx, torsoDy) end
    elseif n == "Shoes" then
      for _, p in ipairs(legs) do drawLeg(O, p.shoes, p, rootDy) end
    elseif n == "Pants" then
      for _, p in ipairs(legs) do drawLeg(O, p.pants, p, rootDy) end
      blitShift(O, mask(S, function(x, y) return y <= 46 end), torsoDx, torsoDy)
    elseif n == "Near Arm" or (n == "Watch" and an.watchOn == "N") then
      limbRot(pose.armTop and top or O, armS(S, n ~= "Watch"), an.armN, 25, an.armN, 34, (pose.aN or 0) * f, (pose.aNr or 0) * f, armDx, torsoDy)
    elseif n == "Back Arm" or (n == "Watch" and an.watchOn == "F") then
      limbRot(O, armS(S, n ~= "Watch"), an.armF, 25, an.armF, 34, (pose.aF or 0) * f, (pose.aFr or 0) * f, armDx, torsoDy)
    elseif n == "Body" then
      headBlit(O, mask(S, function(x, y) return y <= 22 end))
      blitShift(O, mask(S, function(x, y) return y >= 23 end), torsoDx, torsoDy)
    elseif L.arm then   -- a wrist accessory (watch): follows the near ("N") or far ("F") arm like the Watch layer does
      local near = L.arm == "N"
      limbRot((near and L.reftop and pose.armTop) and top or O, armS(S, false), near and an.armN or an.armF, 25, near and an.armN or an.armF, 34, (near and (pose.aN or 0) or (pose.aF or 0)) * f,
        (near and (pose.aNr or 0) or (pose.aFr or 0)) * f, armDx, torsoDy)   -- (was `near and pose.aN or pose.aF`: a near arm with no aN took aF)
    elseif HEAD[n] or L.head then
      headBlit(O, S, L.pad)
    else
      blitShift(O, S, torsoDx, torsoDy)   -- shirt, belt, collar, vest, extras
    end
    out[#out + 1] = O
  end
  out[#out + 1] = top
  -- whole-body rotation (death)
  if pose.rotBody then
    local deg = pose.rotBody * f
    local rad = math.rad(deg)
    local c, s = math.cos(rad), math.sin(rad)
    local pxC = an.footX + OX + rootDx
    local pyC = 61.5 + OY + rootDy
    local BX, BY, BW, BH = 64, 24, CW * 3, CH + 60   -- big working canvas so nothing is clipped
    local rot = {}
    local x0, y0, x1, y1 = 1e9, 1e9, -1, -1
    -- an.ghost (a Hair image of another character) is rotated and measured but never drawn: a style with less hair than the
    -- reference (bald) then lands where the reference does, because the shift below is taken from the union of the boxes
    local nOut = #out
    local srcs = {}
    for i, O in ipairs(out) do srcs[i] = O end
    if an.ghost then
      local G = Image(CW, CH, ColorMode.RGB)
      headBlit(G, an.ghost)
      srcs[#srcs + 1] = G
    end
    for i, O in ipairs(srcs) do
      local isAcc = an.layers[i] and an.layers[i].acc
      local N = Image(BW, BH, ColorMode.RGB)
      for Y2 = 0, BH - 1 do for X2 = 0, BW - 1 do
        local X, Y = X2 - BX, Y2 - BY
        local u, v = X + 0.5 - pxC, Y + 0.5 - pyC
        local sx = math.floor(pxC + u * c - v * s)
        local sy = math.floor(pyC + u * s + v * c)
        if sx >= 0 and sx < CW and sy >= 0 and sy < CH then
          local val = O:getPixel(sx, sy)
          if A(val) > 0 then N:putPixel(X2, Y2, val) end
        end
      end end
      rot[i] = N
      local a, b, cc, d = bbox(N)
      if a and not isAcc then
        if a < x0 then x0 = a end; if cc > x1 then x1 = cc end
        if b < y0 then y0 = b end; if d > y1 then y1 = d end
      end
    end
    x0, x1, y0, y1 = x0 - BX, x1 - BX, y0 - BY, y1 - BY
    local sx, sy = 0, 0
    if f > 0 then
      if x0 < 1 then sx = 1 - x0 end
      if x1 + sx > CW - 2 then sx = (CW - 2) - x1 end
    else
      if x1 > CW - 2 then sx = (CW - 2) - x1 end
      if x0 + sx < 1 then sx = 1 - x0 end
    end
    if pose.rotBody >= 60 or y1 > CH - 1 then sy = (CH - 1) - y1 end
    sy = sy + (pose.ry2 or 0)
    out = {}
    for i, N in ipairs(rot) do
      if i <= nOut then
        local M = Image(CW, CH, ColorMode.RGB)
        M:drawImage(N, Point(sx - BX, sy - BY))
        out[i] = M
      end
    end
  end
  if pose.flash then for _, O in ipairs(out) do flash(O, pose.flash) end end
  local ear = {round(an.headCx + OX + headDx - 6.5 * f), 13 + OY + headDy}
  return out, hand, ear
end

-- build the animation file --------------------------------------------------
function E.build(inPath, outPath, poses, tags, ghostPath)
  local an = E.load(inPath)
  if ghostPath then an.ghost = E.load(ghostPath).by["Hair"].S end
  local f = 1
  if inPath:find("_left") then f = -1 end
  local spr = Sprite(CW, CH, ColorMode.RGB)
  -- layers, bottom to top
  local layerObjs = {}
  local hands = {}
  for i, L in ipairs(an.layers) do
    local l
    if i == 1 then l = spr.layers[1] else l = spr:newLayer() end
    l.name = L.name
    l.isVisible = L.vis
    layerObjs[i] = l
  end
  local topLayer = spr:newLayer()
  topLayer.name = "Arm Top"
  layerObjs[#layerObjs + 1] = topLayer
  for fi, pose in ipairs(poses) do
    if fi > 1 then spr:newFrame() end
    local imgs, hand, ear = E.render(an, pose, f)
    hands[fi] = {(hand or {32, 50})[1], (hand or {32, 50})[2], (ear or {32, 31})[1], (ear or {32, 31})[2]}
    for i, l in ipairs(layerObjs) do
      spr:newCel(l, fi, imgs[i], Point(0, 0))
    end
    spr.frames[fi].duration = (pose.dur or 100) / 1000
  end
  for _, t in ipairs(tags) do
    local tag = spr:newTag(t[2], t[3])
    tag.name = t[1]
  end
  spr:saveAs(outPath)
  spr:close()
  return hands
end

return E
