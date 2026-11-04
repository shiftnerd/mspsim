-- Shared drawing library for the office stage art (10 px = 1 ft, outline #17121F, light from top-left)
local L = {}
local OUT = "#17121F"
L.BASE = "D:/creative/pixelproject/office/"

local function C(h)
  return Color{r=tonumber(h:sub(2,3),16), g=tonumber(h:sub(4,5),16), b=tonumber(h:sub(6,7),16), a=255}
end
L.C = C

L.YOFF = 0
L.XOFF = 0       -- sideways margin for rooms narrower than the 16:9 frame (set by build_sets.lua)
L.MIN_W = 320    -- widest frame we render (16:9 at 320x180)
L.CEIL_H = 100   -- ceiling band above the old art
L.FLOOR_EXT = 92 -- extra floor below the old art (100 + 128 + 92 = 320)

function L.fill(im, x, y, w, h, col)
  local c = C(col)
  for j = y, y + h - 1 do
    for i = x, x + w - 1 do
      if i >= 0 and i < im.width and j >= 0 and j < im.height then im:putPixel(i, j, c) end
    end
  end
end

-- a piece is drawn in content coords (0,0 = top-left); it gets a 1px padding and a 1px 4-neighbour outline
function L.piece(w, h, fn)
  local im = Image(w + 2, h + 2, ColorMode.RGB)
  local function R(x, y, ww, hh, col) L.fill(im, x + 1, y + 1, ww, hh, col) end
  local function PX(x, y, col) L.fill(im, x + 1, y + 1, 1, 1, col) end
  fn(R, PX)
  local o = Image(im)
  local oc = C(OUT)
  local function a(x, y)
    if x < 0 or y < 0 or x >= im.width or y >= im.height then return 0 end
    return app.pixelColor.rgbaA(im:getPixel(x, y))
  end
  for y = 0, im.height - 1 do
    for x = 0, im.width - 1 do
      if a(x, y) == 0 and (a(x-1, y) > 0 or a(x+1, y) > 0 or a(x, y-1) > 0 or a(x, y+1) > 0) then
        o:putPixel(x, y, oc)
      end
    end
  end
  return o
end

-- filled box with highlight on top/left and shade on bottom/right
function L.box(R, x, y, w, h, base, hi, sh)
  R(x, y, w, h, base)
  R(x + w - 1, y, 1, h, sh)
  R(x, y + h - 1, w, 1, sh)
end

function L.savePiece(img, name)
  local s = Sprite(img.width, img.height, ColorMode.RGB)
  local l = s.layers[1]
  l.name = name
  local c = l:cel(1) or s:newCel(l, 1)
  c.image:drawImage(img, Point(0, 0))
  s:saveAs(L.BASE .. "pieces/" .. name .. ".aseprite")
  s:close()
end

-- Multi-angle piece: one frame per angle (tags "front", "side", ...). Each angle is a list of
-- {layerName, image}; frames are bottom-centre aligned on the largest canvas. "side" faces right
-- (mirror it for left). Layer names are shared across angles (a missing layer just has no cel).
function L.saveAngles(name, angles)
  local W, H = 0, 0
  local order, seen = {}, {}
  for _, a in ipairs(angles) do
    for _, ly in ipairs(a.layers) do
      if ly[2].width > W then W = ly[2].width end
      if ly[2].height > H then H = ly[2].height end
      if not seen[ly[1]] then seen[ly[1]] = true; order[#order + 1] = ly[1] end
    end
  end
  local spr = Sprite(W, H, ColorMode.RGB)
  local layerObj = {}
  for i, n in ipairs(order) do
    local l = (i == 1) and spr.layers[1] or spr:newLayer()
    l.name = n
    layerObj[n] = l
  end
  for fi, a in ipairs(angles) do
    if fi > 1 then spr:newFrame() end
    for _, ly in ipairs(a.layers) do
      local img = ly[2]
      local ox = math.floor((W - img.width) / 2)
      spr:newCel(layerObj[ly[1]], fi, img, Point(ox, H - img.height))
    end
    local tag = spr:newTag(fi, fi)
    tag.name = a.tag
  end
  spr:saveAs(L.BASE .. "pieces/" .. name .. ".aseprite")
  spr:close()
end

function L.exportPng(img, path)
  local s = Sprite(img.width, img.height, ColorMode.RGB)
  local l = s.layers[1]
  local c = l:cel(1) or s:newCel(l, 1)
  c.image:drawImage(img, Point(0, 0))
  s:saveCopyAs(path)
  s:close()
end

-- a stage set: named layers (bottom to top in creation order), full-canvas cels
function L.newset(W, H)
  local self = {W = W, H = H, imgs = {}, first = false}
  self.s = Sprite(W, H, ColorMode.RGB)
  function self.layer(name)
    if not self.imgs[name] then
      local l
      if not self.first then l = self.s.layers[1]; self.first = true else l = self.s:newLayer() end
      l.name = name
      local c = l:cel(1) or self.s:newCel(l, 1)
      self.imgs[name] = c.image
    end
    return self.imgs[name]
  end
  -- place a piece so its content top-left lands on (x, y)
  function self.put(name, img, x, y) self.layer(name):drawImage(img, Point(x - 1 + L.XOFF, y - 1 + L.YOFF)) end
  -- y-sorted prop: drawn into the set as usual, but in export mode only recorded (Godot draws it as a sprite)
  self.props = {}
  self.exportMode = false
  function self.putS(name, img, x, y, sortY, piece)
    if not self.exportMode then self.put(name, img, x, y) end
    self.props[#self.props + 1] = {piece = piece, img = img, x = x - 1, y = y - 1, sort = sortY}
  end
  function self.save(name) self.s:saveAs(L.BASE .. name) end
  return self
end

-- backgrounds -------------------------------------------------------------
local function hash(a, b, c)
  local h = a * 73856093 + b * 19349663 + c * 83492791
  h = (h ~ (h >> 15)) * 2246822519 % 4294967296
  h = (h ~ (h >> 13)) * 3266489917 % 4294967296
  return (h ~ (h >> 16)) % 1000003
end

function L.wall(im, W, base, shade)
  local y = L.YOFF
  L.fill(im, 0, y, im.width, 90, base)
  L.fill(im, 0, y + 84, im.width, 6, OUT)
end

-- blue low-pile commercial carpet (2 ft carpet tiles), running to the bottom of the canvas
function L.carpet(im, W, x0)
  W = im.width
  local y0 = 90 + L.YOFF
  local H = im.height
  L.fill(im, 0, y0, W, H - y0, "#3E5E8E")
  for y = y0, H - 1 do
    for x = 0, W - 1 do
      local h = hash(x, y, 17)
      if h % 11 == 0 then L.fill(im, x, y, 1, 1, "#47689A")
      elseif h % 13 == 0 then L.fill(im, x, y, 1, 1, "#375580") end
    end
  end
  for x = 0, W - 1, 20 do L.fill(im, x, y0, 1, H - y0, "#34517B") end
  for y = y0 + 12, H - 1, 20 do L.fill(im, 0, y, W, 1, "#34517B") end
  L.fill(im, 0, y0, W, 2, "#2D4770")
end

function L.tiles(im, W)
  W = im.width
  local y0 = 90 + L.YOFF
  local H = im.height
  L.fill(im, 0, y0, W, H - y0, "#C8C4B8")
  for x = 0, W - 1 do if x % 32 == 0 then L.fill(im, x, y0 + 2, 2, H - y0 - 2, "#B3AFA2") end end
  for y = y0 + 20, H - 1, 20 do L.fill(im, 0, y, W, 2, "#B3AFA2") end
  L.fill(im, 0, y0, W, 2, "#9A968A")
end

-- old drop ceiling: stained, yellowed 2x2 ft acoustic tiles, a T-bar grid and 2x4 ft fluorescent troffers.
-- Drawn in the band y = 0 .. T of the canvas (the wall starts at T).
function L.ceiling(im, W, T, seed)
  local TS = 20
  local cols, rows = math.ceil(W / TS), math.floor(T / TS)
  local bases = {"#D9D5C0", "#D3CFB9", "#DDD9C6", "#D0CBB3"}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      local x, y = c * TS, r * TS
      local h = hash(c, r, seed)
      L.fill(im, x, y, TS, TS, bases[h % 4 + 1])
      for k = 0, 6 do                                                    -- pinholes
        L.fill(im, x + 1 + hash(c * 7 + k, r, seed + 1) % (TS - 2), y + 1 + hash(c, r * 5 + k, seed + 2) % (TS - 2), 1, 1, "#BEB99F")
      end
      if h % 6 == 0 then                                                 -- water stain
        local cx, cy = x + 5 + h % 9, y + 5 + (h // 9) % 9
        local rad = 5 + h % 4
        for dy = -7, 7 do
          for dx = -7, 7 do
            local d2 = dx * dx + dy * dy
            local lim = rad * rad + (hash(dx + 9, dy + 9, h) % 7) - 3
            local px, py = cx + dx, cy + dy
            if d2 <= lim and px > x and px < x + TS and py > y and py < y + TS then
              L.fill(im, px, py, 1, 1, (d2 > lim - 14) and "#B7A26C" or "#D3C596")
            end
          end
        end
      end
      if h % 17 == 3 then L.fill(im, x + 2 + h % 10, y + TS - 4, 6, 2, "#C4B896") end   -- sag / drip mark
    end
  end
  for c = 0, cols do                                                     -- T-bar grid
    L.fill(im, c * TS, 0, 2, rows * TS, "#EDEBDA"); L.fill(im, c * TS + 2, 0, 1, rows * TS, "#B3AF98")
  end
  for r = 0, rows do
    L.fill(im, 0, r * TS, W, 2, "#EDEBDA"); L.fill(im, 0, r * TS + 2, W, 1, "#B3AF98")
  end
  -- fluorescent troffers: 4 ft x 2 ft, in rows 1 and 3, one tube dying per ceiling
  local n = 0
  for r = 1, rows - 2, 2 do
    for c = (r == 1) and 1 or 3, cols - 2, 4 do
      n = n + 1
      local x, y = c * TS + 2, r * TS + 2
      local dying = (n % 5 == 2)
      L.fill(im, x, y, 2 * TS - 2, TS - 2, "#8D8D86")
      L.fill(im, x + 2, y + 2, 2 * TS - 6, TS - 6, dying and "#D9D5B0" or "#F7F4DA")
      L.fill(im, x + 3, y + 5, 2 * TS - 8, 2, dying and "#C9C49E" or "#FFFFFF")
      L.fill(im, x + 3, y + 10, 2 * TS - 8, 2, "#FFFFFF")
      if dying then L.fill(im, x + 3, y + 5, 12, 2, "#9C987E") end
    end
  end
  for _, rc in ipairs({{3, 0}, {5, 4}}) do                              -- sprinkler heads
    local sx, sy = (rc[1] % cols) * TS + 10, rc[2] * TS + 10
    L.fill(im, sx - 1, sy - 1, 3, 3, "#B58A3C"); L.fill(im, sx, sy, 1, 1, "#E6C26A")
  end
  L.fill(im, 0, T - 4, W, 3, "#C9C6B0"); L.fill(im, 0, T - 1, W, 1, OUT)   -- wall angle where the ceiling meets the wall
end

-- Rooms narrower than the widest frame get a margin on each side: the wall, ceiling and floor simply continue,
-- darkened, with a dark cutaway edge at the real room boundary ("off stage").
function L.margins(set, Wroom)
  local xo = L.XOFF
  if xo <= 0 then return end
  local im = set.layer("Margins")
  local W = set.W
  local H = set.H
  local src = Image(W, H, ColorMode.RGB)
  src:drawSprite(set.s, 1)
  local function shade(x0, x1)
    for y = 0, H - 1 do
      for x = x0, x1 - 1 do
        local px = src:getPixel(x, y)
        local r, g, b = app.pixelColor.rgbaR(px), app.pixelColor.rgbaG(px), app.pixelColor.rgbaB(px)
        im:putPixel(x, y, app.pixelColor.rgba(math.floor(r * 0.55), math.floor(g * 0.55), math.floor(b * 0.6), 255))
      end
    end
  end
  shade(0, xo)
  shade(xo + Wroom, W)
  L.fill(im, xo - 3, 0, 3, H, OUT)
  L.fill(im, xo + Wroom, 0, 3, H, OUT)
end

-- pieces ------------------------------------------------------------------
local P = {}
L.P = P

function P.desk(wd)
  return L.piece(wd, 25, function(R)
    L.box(R, 0, 0, wd, 3, "#C9955A", "#E0B47A", "#A57445")
    R(2, 3, wd - 4, 5, "#A57445")
    R(2, 8, 4, 17, "#8A5E36"); R(wd - 6, 8, 4, 17, "#8A5E36")
    R(6, 8, wd - 12, 15, "#946A3D")   -- modesty panel: hides the sitter's legs
    R(6, 21, wd - 12, 2, "#7E5630")
  end)
end

function P.monitor()
  return L.piece(24, 21, function(R)
    L.box(R, 0, 0, 24, 16, "#2A2A33", "#4A4A56", "#1C1C24")
    R(2, 2, 20, 12, "#DDE8F0"); R(2, 2, 20, 3, "#7FA6D8")
    R(4, 7, 12, 2, "#9FB4C8")
    R(10, 16, 4, 3, "#2A2A33"); R(7, 19, 10, 2, "#2A2A33")
  end)
end

function P.keyboard()
  return L.piece(16, 3, function(R)
    R(0, 0, 16, 3, "#3A3A44")
  end)
end

-- 2012-style VoIP desk phone (charcoal, handset on the left cradle, green LCD, coiled cord).
-- Three parts so the handset can lift off later: cord (bottom), body, handset (top). 18x16.
local PH = {base = "#5A5D69", hi = "#7C808D", sh = "#3E4049", hs = "#464955", hshi = "#8E92A0",
            lcd = "#A9C3A4", lcdInk = "#5B7A5E", key = "#25262C", keyHi = "#B3B6C2", soft = "#9A9DA9"}

function P.deskPhoneParts()
  -- 12 x 11 px (a screen is 24 wide): the keys are single pixels now
  local cord = L.piece(12, 11, function(R)
    R(1, 9, 1, 2, PH.sh); R(0, 10, 1, 1, PH.sh)
  end)
  local body = L.piece(12, 11, function(R)
    L.box(R, 2, 0, 10, 9, PH.base, PH.hi, PH.sh)
    R(2, 0, 10, 1, PH.hi)
    R(4, 1, 5, 3, PH.lcd)                       -- LCD
    R(5, 2, 3, 1, PH.lcdInk)
    R(3, 1, 1, 1, PH.soft); R(3, 3, 1, 1, PH.soft); R(9, 1, 1, 1, PH.soft); R(9, 3, 1, 1, PH.soft)  -- line keys
    R(3, 6, 1, 1, PH.key); R(3, 7, 1, 1, PH.keyHi)   -- nav
    for _, y in ipairs({5, 7}) do for _, x in ipairs({5, 7, 9}) do R(x, y, 1, 1, PH.keyHi) end end   -- keypad
    R(10, 7, 1, 1, "#D23C3C")                   -- message LED
  end)
  local handset = L.piece(12, 11, function(R)
    R(0, 0, 3, 2, PH.hs); R(0, 0, 3, 1, PH.hshi)        -- earpiece
    R(1, 2, 2, 5, PH.hs); R(1, 2, 1, 5, PH.hshi)         -- grip
    R(0, 7, 3, 2, PH.hs); R(0, 8, 3, 1, PH.sh)           -- mouthpiece
  end)
  return {cord = cord, body = body, handset = handset}
end

function P.deskPhone()
  local parts = P.deskPhoneParts()
  local im = Image(parts.body.width, parts.body.height, ColorMode.RGB)
  for _, k in ipairs({"cord", "body", "handset"}) do im:drawImage(parts[k], Point(0, 0)) end
  return im
end

-- ===== SIDE VIEWS (facing right; the front views above are "front") ==========================
-- desk seen from the side: the end panel, `depth` px deep (2.5 ft = 25 px)
function P.deskSide(depth)
  depth = depth or 25
  return L.piece(depth, 25, function(R)
    L.box(R, 0, 0, depth, 3, "#C9955A", "#E0B47A", "#A57445")
    R(1, 3, depth - 2, 20, "#A57445")
    R(1, 3, depth - 2, 1, "#8A5E36")
    R(1, 3, 1, 20, "#946A3D")
    R(depth - 2, 3, 1, 20, "#8A5E36")
    R(1, 22, depth - 2, 3, "#8A5E36")                      -- end-panel foot
  end)
end

function P.monitorSide()
  return L.piece(12, 21, function(R)
    L.box(R, 4, 0, 5, 16, "#2A2A33", "#4A4A56", "#1C1C24")  -- thin panel
    R(8, 2, 1, 12, "#DDE8F0")                                -- lit screen edge (faces right)
    R(3, 5, 2, 8, "#1C1C24")                                 -- bulge at the back
    R(5, 16, 3, 3, "#2A2A33")                                -- neck
    R(1, 19, 10, 2, "#2A2A33")                               -- foot
  end)
end

function P.keyboardSide()
  return L.piece(10, 3, function(R)
    R(0, 0, 3, 1, "#3A3A44"); R(0, 1, 6, 1, "#3A3A44"); R(0, 2, 10, 1, "#3A3A44")
    R(0, 2, 10, 1, "#2A2A33")
  end)
end

function P.chairSide(base, hi, sh)
  base = base or "#2A2A33"; hi = hi or "#4A4A56"; sh = sh or "#1C1C24"
  return L.piece(18, 33, function(R)
    L.box(R, 0, 0, 3, 15, base, hi, sh)                      -- backrest (faces right, so it is at the back/left)
    L.box(R, 0, 15, 18, 4, base, hi, sh)                     -- seat
    R(8, 19, 2, 10, sh)                                      -- gas post
    R(1, 29, 16, 2, base)                                    -- star base
    R(0, 31, 3, 2, sh); R(15, 31, 3, 2, sh); R(7, 31, 3, 2, sh)
  end)
end

function P.bookshelfSide(depth)
  depth = depth or 12
  return L.piece(depth, 64, function(R)
    L.box(R, 0, 0, depth, 64, "#6E4A2A", "#8A5E36", "#4E3320")
    R(2, 2, depth - 4, 60, "#7E5632")                        -- side panel inset
    for row = 0, 3 do R(2, 2 + row * 15 + 13, depth - 4, 1, "#4E3320") end  -- shelf lines show through
    R(1, 61, depth - 2, 2, "#4E3320")                        -- toe kick
  end)
end

-- desk phone from its right side: slim wedge, handset lying along the top (the handset is on the phone's left,
-- so from here only its ends show above the body), cord dropping off the back
function P.deskPhoneSideParts()
  local cord = L.piece(10, 9, function(R)
    R(0, 5, 1, 1, "#3E4049"); R(0, 7, 1, 1, "#3E4049"); R(1, 6, 1, 1, "#3E4049")
  end)
  local body = L.piece(10, 9, function(R)
    R(1, 2, 8, 5, "#5A5D69")                                  -- body (tall at the back, sloping to the front)
    R(5, 2, 4, 2, "#5A5D69")
    R(1, 2, 2, 1, "#7C808D"); R(3, 3, 2, 1, "#7C808D"); R(5, 4, 2, 1, "#7C808D"); R(7, 5, 2, 1, "#7C808D")
    R(1, 6, 8, 1, "#3E4049"); R(8, 4, 1, 3, "#3E4049")
    R(7, 6, 1, 1, "#D23C3C")
    R(2, 7, 6, 1, "#3E4049")                                  -- feet
  end)
  local handset = L.piece(10, 9, function(R)
    R(0, 0, 3, 2, "#464955"); R(0, 0, 3, 1, "#8E92A0")
    R(7, 0, 3, 2, "#464955"); R(7, 0, 3, 1, "#8E92A0")
    R(3, 1, 4, 1, "#464955")
  end)
  return {cord = cord, body = body, handset = handset}
end

-- desk phone without the handset (cord + body), and the handset alone, for the interactive phone
function P.deskPhoneBase()
  local parts = P.deskPhoneParts()
  local im = Image(parts.body.width, parts.body.height, ColorMode.RGB)
  for _, k in ipairs({"cord", "body"}) do im:drawImage(parts[k], Point(0, 0)) end
  return im
end

function P.deskPhoneHandset() return P.deskPhoneParts().handset end

function P.chair(base, hi, sh)
  base = base or "#2A2A33"; hi = hi or "#4A4A56"; sh = sh or "#1C1C24"
  return L.piece(18, 33, function(R)
    L.box(R, 3, 0, 12, 14, base, hi, sh)
    L.box(R, 0, 15, 18, 4, base, hi, sh)
    R(8, 19, 2, 10, sh)
    R(1, 29, 16, 2, base)
    R(0, 31, 3, 2, sh); R(15, 31, 3, 2, sh); R(7, 31, 3, 2, sh)
  end)
end

-- green geometric slipper chair (from the reference photo)
function P.slipper()
  return L.piece(22, 26, function(R, PX)
    local function pat(x0, y0, w, h, shadeCols)
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local gx = (x + x0 + (math.floor((y + y0) / 6) % 2) * 3) % 6
          local green = (gx < 4) and ((y + y0) % 6 < 4)
          local col
          if green then col = "#3E8E3A" else col = "#F4F2EA" end
          PX(x0 + x, y0 + y, col)
        end
      end
    end
    pat(2, 0, 18, 13, 2)      -- back
    pat(0, 13, 22, 7, 2)      -- seat
    R(0, 20, 22, 2, "#D8D6CC") -- skirt
    R(3, 22, 3, 4, "#2A1C14"); R(16, 22, 3, 4, "#1C120C")
  end)
end

function P.bookshelf()
  return L.piece(28, 64, function(R)
    L.box(R, 0, 0, 28, 64, "#6E4A2A", "#8A5E36", "#4E3320")
    R(2, 2, 24, 60, "#3E2A18")
    local cols = {{"#B8292F", "#D8484E"}, {"#3C55C0", "#5F78DC"}, {"#E8E2D4", "#FFFFFF"}, {"#4F9C8E", "#72BFB0"},
                  {"#C9955A", "#E0B47A"}, {"#7A4A8A", "#9A6AAA"}, {"#E0B040", "#F5CF66"}}
    local k = 0
    for row = 0, 3 do
      local top = 2 + row * 15
      R(2, top + 13, 24, 2, "#8A5E36")
      local x = 3
      while x < 24 do
        local w = 3 + ((x + row) % 2)
        local h = 8 + ((x + row * 5) % 3) * 2
        local c = cols[(k % #cols) + 1]; k = k + 1
        if x + w > 25 then w = 25 - x end
        R(x, top + 13 - h, w, h, c[1])
        x = x + w
      end
    end
  end)
end

function P.plant()
  return L.piece(12, 18, function(R, PX)
    R(5, 3, 2, 10, "#2C6B2A"); R(2, 6, 3, 5, "#3E8E3A"); R(7, 6, 3, 5, "#3E8E3A")
    R(4, 0, 4, 5, "#5FB04E"); R(1, 4, 2, 3, "#5FB04E"); R(9, 4, 2, 3, "#2C6B2A")
    L.box(R, 2, 12, 8, 6, "#B8663F", "#D88A62", "#8A4A2C")
  end)
end

function P.glassDoor(w, h)
  w = w or 34; h = h or 72
  local k = h / 72
  local function Y(v) return math.floor(v * k + 0.5) end
  return L.piece(w, h, function(R)
    L.box(R, 0, 0, w, h, "#B8BCC4", "#D6D9DF", "#9498A2")
    R(3, 3, w - 6, h - 6, "#A9D0E6")
    R(3, Y(34), w - 6, math.max(2, Y(4)), "#B8BCC4")
    R(3, h - Y(10), w - 6, Y(7), "#B8BCC4")
    R(w - 8, Y(14), 3, Y(18), "#6A6F7A")
  end)
end

function P.slabDoor(base, shade, hi, knob)
  return L.piece(34, 72, function(R)
    R(0, 0, 34, 72, "#1E1E22")
    R(2, 2, 30, 70, base); R(29, 2, 3, 70, shade)
    if knob == "black" then
      R(5, 34, 4, 4, "#1E1E22"); R(5, 34, 1, 1, base); R(8, 34, 1, 1, base); R(5, 37, 1, 1, base); R(8, 37, 1, 1, base)
    else
      R(5, 34, 5, 2, "#C8CCD8"); R(5, 34, 5, 1, "#EDEFF4"); R(4, 32, 3, 6, "#8E939E")
    end
  end)
end

-- a heavy steel door (R24): a steel frame, a flat leaf with two pressed panels, three hinge knuckles on the left, a lever, a
-- deadbolt, a door closer on top and a kick plate. opts.reader draws a badge reader and keypad on the frame at the right (the
-- piece is then w wide with the leaf narrower); opts.frame is the frame colour.
function P.steelDoor(w, h, base, shade, hi, opts)
  opts = opts or {}
  return L.piece(w, h, function(R)
    local rw = opts.reader and 9 or 0
    local lw = w - 6 - rw                                   -- the leaf
    R(0, 0, w, h, "#1E1E22")
    R(1, 1, w - 2, h - 1, opts.frame or shade)
    R(3, 3, lw, h - 3, base); R(3, 3, 1, h - 3, hi); R(3 + lw - 2, 3, 2, h - 3, shade)
    R(6, 9, lw - 10, h // 3 - 2, shade); R(7, 10, lw - 12, h // 3 - 4, base); R(7, 10, lw - 12, 1, hi)
    local ly = 9 + h // 3 + 3
    R(6, ly, lw - 10, h - ly - 14, shade); R(7, ly + 1, lw - 12, h - ly - 16, base); R(7, ly + 1, lw - 12, 1, hi)
    R(3, h - 10, lw, 9, shade); R(3, h - 10, lw, 1, hi)     -- the kick plate and its rivets
    for i = 0, 3 do R(5 + i * ((lw - 8) // 3), h - 6, 1, 1, hi) end
    R(3, 3, lw, 4, "#2A2A33"); R(5, 4, lw - 10, 1, "#4A4A58"); R(lw - 8, 7, 7, 1, "#2A2A33")   -- the door closer
    for _, y in ipairs({12, h // 2 - 4, h - 26}) do R(1, y, 3, 6, "#2A2A33"); R(1, y, 1, 6, "#4A4A58") end   -- hinges
    local hx, hy = lw - 7, h // 2 + 2
    R(hx, hy, 9, 3, "#C8CCD8"); R(hx, hy, 9, 1, "#EDEFF4"); R(hx + 6, hy - 3, 3, 8, "#8E939E")   -- lever on its rose
    R(hx + 4, hy - 10, 4, 4, "#2A2A33"); R(hx + 5, hy - 9, 2, 1, "#8E939E")                     -- the deadbolt
    if opts.reader then
      local rx = w - rw - 1
      R(rx, 20, 8, 17, "#2A2D36"); R(rx, 20, 8, 1, "#4A4F5A")
      R(rx + 2, 22, 4, 2, "#4EC46A"); R(rx + 2, 22, 4, 1, "#9EF0B0")                           -- the green light
      for r = 0, 2 do for c = 0, 2 do R(rx + 1 + c * 2, 26 + r * 2, 1, 1, "#B8BCC4") end end    -- the keypad
      R(rx + 1, 33, 6, 2, "#14566E")                                                           -- the card slot
    end
  end)
end

-- 3x5 pixel font (the game UI font) for door plates and small signs
local DOORFONT = {
  A = {"XXX","X.X","XXX","X.X","X.X"}, C = {".XX","X..","X..","X..",".XX"}, E = {"XXX","X..","XX.","X..","XXX"},
  F = {"XXX","X..","XX.","X..","X.."}, I = {"XXX",".X.",".X.",".X.","XXX"},
  H = {"X.X","X.X","XXX","X.X","X.X"}, K = {"X.X","X.X","XX.","X.X","X.X"}, L = {"X..","X..","X..","X..","XXX"},
  N = {"XXX","X.X","X.X","X.X","X.X"}, O = {".X.","X.X","X.X","X.X",".X."}, R = {"XX.","X.X","XX.","X.X","X.X"},
  S = {".XX","X..",".X.","..X","XX."}, T = {"XXX",".X.",".X.",".X.",".X."}, W = {"X.X","X.X","XXX","XXX","X.X"},
  Y = {"X.X","X.X",".X.",".X.",".X."}, [" "] = {"...","...","...","...","..."},
}
function L.doorText(R, str, x, y, col)
  for i = 1, #str do
    local rows = DOORFONT[str:sub(i, i)] or DOORFONT[" "]
    for r = 1, 5 do for c = 1, 3 do
      if rows[r]:sub(c, c) == "X" then R(x + (i - 1) * 4 + (c - 1), y + r - 1, 1, 1, col) end
    end end
  end
end

-- a door plate over a steel door: dark border, a coloured field, white letters (8 characters or fewer)
function P.doorPlate(text, field)
  local w = #text * 4 - 1 + 4
  return L.piece(w, 8, function(R)
    R(0, 0, w, 8, "#2A2D36"); R(1, 1, w - 2, 6, field or "#14566E")
    L.doorText(R, text, 3, 1, "#FFFFFF")
  end)
end

-- a small notice: white card, a red band on top, dark letters
function P.smallSign(text)
  local w = #text * 4 - 1 + 4
  return L.piece(w, 11, function(R)
    R(0, 0, w, 11, "#F4F2EA"); R(0, 0, w, 3, "#C23B2E"); R(0, 10, w, 1, "#CFCBBE"); R(w - 1, 3, 1, 8, "#CFCBBE")
    L.doorText(R, text, 2, 4, "#17121F")
  end)
end

function P.tv()
  return L.piece(36, 22, function(R)
    L.box(R, 0, 0, 36, 22, "#2A2A33", "#4A4A56", "#1C1C24")
    R(2, 2, 32, 17, "#EEF3F6"); R(2, 2, 32, 4, "#7FA6D8")
    R(2, 10, 32, 2, "#C9D3DA"); R(2, 15, 32, 2, "#C9D3DA")
  end)
end

function P.cubicleShell()
  return L.piece(80, 56, function(R)
    L.box(R, 0, 0, 80, 56, "#8D99A8", "#A8B3C0", "#6F7C8C")
    R(0, 0, 80, 3, "#D8D5C4")
    R(0, 0, 3, 56, "#6F7C8C"); R(77, 0, 3, 56, "#6F7C8C"); R(0, 0, 3, 3, "#D8D5C4"); R(77, 0, 3, 3, "#D8D5C4")
  end)
end

function P.calendar()
  return L.piece(12, 10, function(R)
    R(0, 0, 12, 10, "#F4F2EA"); R(0, 0, 12, 2, "#4F7FD0")
    for r = 0, 2 do for c = 0, 3 do R(1 + c * 3, 3 + r * 2, 2, 1, "#4F7FD0") end end
  end)
end

function P.sticky()
  return L.piece(5, 5, function(R) R(0, 0, 5, 5, "#F7E36B"); R(0, 4, 5, 1, "#D8C14A") end)
end

function P.confTable()
  return L.piece(120, 30, function(R)
    L.box(R, 0, 0, 120, 5, "#C9955A", "#E0B47A", "#A57445")
    R(2, 5, 116, 3, "#A57445")
    R(12, 8, 6, 22, "#8A5E36"); R(102, 8, 6, 22, "#8A5E36")
  end)
end

function P.wallScreen()
  return L.piece(66, 32, function(R)
    L.box(R, 0, 0, 66, 32, "#2A2A33", "#4A4A56", "#1C1C24")
    R(2, 2, 62, 28, "#DDE8F0")
    R(8, 7, 26, 4, "#7FA6D8"); R(8, 15, 40, 2, "#9FB4C8"); R(8, 20, 34, 2, "#9FB4C8")
    R(46, 6, 12, 9, "#4F9C8E")
  end)
end

function P.fridge()
  return L.piece(26, 60, function(R)
    L.box(R, 0, 0, 26, 60, "#B8BCC4", "#D6D9DF", "#9498A2")
    R(0, 21, 26, 2, "#6A6F7A")
    R(20, 6, 3, 12, "#6A6F7A")
    R(20, 27, 3, 14, "#6A6F7A")
  end)
end

local function cabDoor(R, x, y, w, h, knobY, knobX)
  R(x, y, w, h, "#F0F0EC")
  R(x + w - 1, y, 1, h, "#D8D8D2"); R(x, y + h - 1, w, 1, "#D8D8D2")
  R(knobX, knobY, 3, 3, "#17121F")
end

function P.upperCabinets()
  return L.piece(52, 22, function(R)
    R(0, 0, 52, 22, "#17121F")
    cabDoor(R, 1, 1, 24, 20, 14, 19)
    cabDoor(R, 27, 1, 24, 20, 14, 30)
  end)
end

function P.lowerCabinets()
  return L.piece(56, 16, function(R)
    L.box(R, 0, 0, 56, 3, "#B5A58C", "#CDBB9E", "#8F8068")
    R(2, 3, 52, 11, "#17121F")
    cabDoor(R, 3, 4, 24, 9, 5, 21)
    cabDoor(R, 29, 4, 24, 9, 5, 32)
    R(2, 14, 52, 2, "#9A9A9A")
  end)
end

function P.sink()
  return L.piece(16, 10, function(R)
    L.box(R, 0, 6, 16, 4, "#B8BCC4", "#D6D9DF", "#9498A2")
    R(2, 7, 12, 2, "#8E939E")
    R(7, 0, 3, 7, "#8E939E"); R(7, 0, 6, 3, "#8E939E")
  end)
end

function P.coffee()
  return L.piece(20, 16, function(R)
    R(0, 14, 19, 2, "#2A2A33")
    L.box(R, 1, 0, 12, 14, "#2E3138", "#4A4F5A", "#1C1E24")
    R(1, 0, 12, 4, "#4A4F5A"); R(4, 1, 6, 2, "#1C1E24")
    R(3, 6, 2, 2, "#E04040")
    R(7, 7, 6, 7, "#1C1E24")
    R(8, 10, 4, 4, "#F2F2EA"); R(12, 11, 1, 3, "#F2F2EA")
    L.box(R, 15, 2, 4, 12, "#8AB4D8", "#B5D4EC", "#5E86A8")
  end)
end

function P.toilet()
  return L.piece(16, 24, function(R)
    L.box(R, 2, 0, 12, 10, "#F0F0F0", "#FFFFFF", "#D8D8D2")
    R(10, 2, 3, 2, "#8E939E")
    L.box(R, 0, 10, 16, 8, "#F0F0F0", "#FFFFFF", "#D8D8D2")
    R(3, 18, 10, 6, "#E4E4DE")
  end)
end

function P.bathSink()
  return L.piece(16, 26, function(R)
    R(7, 0, 2, 4, "#8E939E"); R(7, 0, 6, 2, "#8E939E")
    L.box(R, 0, 4, 16, 6, "#F0F0F0", "#FFFFFF", "#D8D8D2")
    R(5, 10, 6, 16, "#E4E4DE")
  end)
end

function P.mirror()
  return L.piece(18, 22, function(R)
    R(0, 0, 18, 22, "#B8BCC4")
    R(2, 2, 14, 18, "#CFE6F2")
    R(3, 3, 3, 8, "#EAF6FB")
  end)
end

function P.copier()
  return L.piece(28, 26, function(R)
    L.box(R, 0, 0, 28, 7, "#8E939E", "#B8BCC4", "#6A6F7A")
    L.box(R, 0, 7, 28, 19, "#C8CCD8", "#E4E6EE", "#9498A2")
    R(3, 10, 9, 5, "#2A2A33"); R(4, 11, 3, 1, "#4F9C8E"); R(5, 13, 5, 1, "#9FB4C8")
    R(16, 11, 9, 3, "#F4F2EA")
    R(3, 19, 22, 2, "#9498A2")
  end)
end

function P.cooler()
  return L.piece(12, 30, function(R)
    L.box(R, 2, 0, 8, 10, "#8AB4D8", "#B5D4EC", "#5E86A8")
    L.box(R, 0, 10, 12, 20, "#F0F0EC", "#FFFFFF", "#D8D8D2")
    R(3, 14, 2, 2, "#4F7FD0"); R(7, 14, 2, 2, "#E04040")
    R(3, 19, 6, 3, "#9498A2")
  end)
end

function P.floorPlant()
  return L.piece(14, 30, function(R)
    R(6, 4, 2, 18, "#2C6B2A"); R(2, 8, 4, 8, "#3E8E3A"); R(8, 6, 4, 10, "#3E8E3A")
    R(4, 0, 6, 8, "#5FB04E"); R(0, 12, 3, 6, "#5FB04E"); R(11, 12, 3, 6, "#2C6B2A")
    L.box(R, 2, 20, 10, 10, "#B8663F", "#D88A62", "#8A4A2C")
  end)
end

function P.whiteboard()
  return L.piece(40, 24, function(R)
    R(0, 0, 40, 24, "#B8BCC4")
    R(2, 2, 36, 20, "#F4F2EA")
    R(5, 6, 16, 2, "#4F7FD0"); R(5, 11, 22, 2, "#4F7FD0"); R(5, 16, 12, 2, "#E04040")
    R(26, 5, 8, 6, "#3E8E3A")
    R(4, 22, 8, 2, "#8E939E")
  end)
end

-- ===== office dressing: filing cabinet, couch, picture frame, wall clock ====================================
function P.filingCabinet()
  return L.piece(14, 32, function(R)
    L.box(R, 0, 0, 14, 32, "#8E939E", "#B8BCC4", "#6A6F7A")
    for i = 0, 2 do
      R(1, 1 + i * 10, 12, 9, "#A3A8B3"); R(1, 9 + i * 10, 12, 1, "#6A6F7A")
      R(5, 4 + i * 10, 4, 1, "#4A4F5A"); R(6, 2 + i * 10, 2, 1, "#F4F2EA")
    end
  end)
end

function P.couch()
  return L.piece(40, 31, function(R)
    L.box(R, 0, 0, 40, 12, "#3F7F86", "#5C9EA6", "#2C5C62")
    L.box(R, 0, 8, 6, 19, "#356C72", "#4C8C94", "#26535A")
    L.box(R, 34, 8, 6, 19, "#356C72", "#4C8C94", "#26535A")
    L.box(R, 6, 12, 14, 8, "#4C8C94", "#6AAEB6", "#356C72")
    L.box(R, 20, 12, 14, 8, "#4C8C94", "#6AAEB6", "#356C72")
    R(6, 20, 28, 7, "#356C72"); R(6, 26, 28, 1, "#26535A")
    R(2, 27, 3, 4, "#2A1C14"); R(35, 27, 3, 4, "#2A1C14")
  end)
end

function P.frame(w, h, sky, hill)
  w = w or 14; h = h or 18; sky = sky or "#7FA6D8"; hill = hill or "#4F9C8E"
  return L.piece(w, h, function(R)
    L.box(R, 0, 0, w, h, "#5A3A22", "#7A5232", "#3E2814")
    R(2, 2, w - 4, h - 4, "#EFE8D4")
    R(3, 3, w - 6, h - 6, sky)
    R(3, h - 7, w - 6, 4, hill)
    R(w - 7, 4, 3, 3, "#F7E36B")
  end)
end

function P.clock()
  return L.piece(10, 10, function(R)
    L.box(R, 0, 0, 10, 10, "#F4F2EA", "#FFFFFF", "#CFCBBE")
    R(4, 2, 1, 4, "#17121F"); R(4, 5, 3, 1, "#17121F"); R(4, 5, 1, 1, "#D23C3C")
  end)
end

-- a receding hallway seen through an opening in the wall (one-point perspective), glass door at the far end
function L.hallway(im)
  local XO, YO = L.XOFF, L.YOFF
  local function F(x, y, w, h, col) L.fill(im, x + XO, y + YO, w, h, col) end
  local function line(x0, y0, x1, y1, col)
    local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
    local sx, sy = (x0 < x1) and 1 or -1, (y0 < y1) and 1 or -1
    local err = dx - dy
    while true do
      F(x0, y0, 1, 1, col)
      if x0 == x1 and y0 == y1 then break end
      local e2 = 2 * err
      if e2 > -dy then err = err - dy; x0 = x0 + sx end
      if e2 < dx then err = err + dx; y0 = y0 + sy end
    end
  end
  local ox0, ox1, oy0, oy1 = 6, 76, 4, 90          -- the opening in the main wall
  local bx0, bx1, by0, by1 = 22, 60, 22, 70        -- the far wall
  local TRIM, LINE = "#1E1E22", "#17121F"
  F(ox0 - 3, oy0 - 3, ox1 - ox0 + 6, 3, TRIM)
  F(ox0 - 3, oy0 - 3, 3, oy1 - oy0 + 3, TRIM)
  F(ox1, oy0 - 3, 3, oy1 - oy0 + 3, TRIM)
  F(bx0, by0, bx1 - bx0, by1 - by0, "#86B835")     -- far wall (green hallway)
  for y = oy0, by0 - 1 do                          -- ceiling
    local t = (y - oy0) / (by0 - oy0)
    local xl, xr = math.floor(ox0 + (bx0 - ox0) * t + 0.5), math.floor(ox1 + (bx1 - ox1) * t + 0.5)
    F(xl, y, xr - xl, 1, "#B2AE98")
  end
  for y = by1, oy1 - 1 do                          -- floor
    local t = (y - by1) / (oy1 - by1)
    local xl, xr = math.floor(bx0 + (ox0 - bx0) * t + 0.5), math.floor(bx1 + (ox1 - bx1) * t + 0.5)
    F(xl, y, xr - xl, 1, (y % 4 < 2) and "#2F4A78" or "#2B4470")
  end
  for x = ox0, bx0 - 1 do                          -- left side wall
    local t = (x - ox0) / (bx0 - ox0)
    local yt, yb = math.floor(oy0 + (by0 - oy0) * t + 0.5), math.floor(oy1 + (by1 - oy1) * t + 0.5)
    F(x, yt, 1, yb - yt, "#628F27")
  end
  for x = bx1, ox1 - 1 do                          -- right side wall
    local t = (ox1 - 1 - x) / (ox1 - bx1)
    local yt, yb = math.floor(oy0 + (by0 - oy0) * t + 0.5), math.floor(oy1 + (by1 - oy1) * t + 0.5)
    F(x, yt, 1, yb - yt, "#74A32D")
  end
  line(ox0, oy0, bx0, by0, LINE); line(ox1 - 1, oy0, bx1 - 1, by0, LINE)
  line(ox0, oy1 - 1, bx0, by1 - 1, LINE); line(ox1 - 1, oy1 - 1, bx1 - 1, by1 - 1, LINE)
  F(bx0, by0, bx1 - bx0, 1, LINE); F(bx0, by1 - 1, bx1 - bx0, 1, LINE)
  F(bx0, by0, 1, by1 - by0, LINE); F(bx1 - 1, by0, 1, by1 - by0, LINE)
  F(37, 23, 10, 3, "#D23C3C"); F(38, 24, 2, 1, "#FFFFFF"); F(41, 24, 2, 1, "#FFFFFF"); F(44, 24, 2, 1, "#FFFFFF")
  im:drawImage(P.glassDoor(26, 40), Point(28 - 1 + XO, 70 - 40 - 1 + YO))
end

-- ===== the network closet: one rack, a wall outlet and the ISP jack ==================================
-- Everything here is in content pixels. L.rackLayout() is the single source of truth for where the plug points,
-- LEDs and fixed cable ends are: P.networkRack() draws from it and L.writeRackLayout() exports it as JSON for Godot.
L.CLOSET = {rack = {56, 2}, outlet = {44, 68}, jack = {134, 56}}   -- set coordinates (top-left of each piece)

function L.rackLayout()
  local lay = {w = 70, h = 88, ports = {}, far = {}, leds = {}, devices = {}}
  local function port(id, kind, x, y) lay.ports[#lay.ports + 1] = {id = id, kind = kind, x = x, y = y} end
  lay.devices.patch = {6, 3, 58, 8}
  lay.devices.switch = {6, 12, 58, 14}
  lay.devices.router = {6, 27, 58, 11}
  lay.devices.nas = {6, 39, 58, 14}
  lay.devices.pdu = {6, 54, 58, 8}
  lay.devices.ups = {6, 63, 58, 22}
  lay.leds.sw_link, lay.leds.sw_act = {}, {}
  for i = 1, 8 do lay.far["p" .. i] = {8 + 7 * (i - 1) + 2, 7} end                       -- patch panel ports (fixed cable ends)
  for j = 1, 12 do
    local x = 9 + 4 * (j - 1)
    port("sw" .. j, "net", x + 1, 20)
    lay.leds.sw_link[j] = {x, 15}
    lay.leds.sw_act[j] = {x + 2, 15}
  end
  port("wan", "wan", 11, 33)
  lay.far.up = {22, 33}                                                                  -- router LAN1
  lay.leds.rt = {pwr = {9, 29}, wan = {13, 29}, lan = {20, 29}, net = {24, 29}}
  lay.leds.nas_bay = {}
  for b = 1, 4 do lay.leds.nas_bay[b] = {8 + 11 * (b - 1) + 8, 50} end
  lay.far.nas = {56, 51}                                                                 -- NAS network port
  port("nas_btn", "button", 57, 45)
  lay.leds.nas_pwr = {57, 41}
  for k = 1, 6 do
    port("pdu" .. k, "outlet", 8 + 8 * (k - 1) + 3, 58)
  end
  lay.leds.pdu = {57, 57}
  for k = 1, 3 do port("ups" .. k, "outlet", 36 + 8 * (k - 1) + 3, 70) end
  port("ups_btn", "button", 60, 77)
  lay.leds.ups_pwr = {60, 72}
  lay.leds.ups_lcd = {8, 66, 22, 12}
  lay.far.sw_pwr = {60, 19}
  lay.far.rt_pwr = {61, 32}
  lay.far.nas_pwr = {61, 50}
  lay.far.pdu_in = {61, 58}
  lay.far.ups_in = {57, 81}
  local rx, ry = L.CLOSET.rack[1], L.CLOSET.rack[2]
  local ox, oy = L.CLOSET.outlet[1] - rx, L.CLOSET.outlet[2] - ry
  local jx, jy = L.CLOSET.jack[1] - rx, L.CLOSET.jack[2] - ry
  port("wall", "wall", ox + 3, oy + 6)                                                   -- the lower socket of the wall outlet
  lay.far.wan = {jx + 3, jy + 4}                                                         -- the ISP jack in the wall
  lay.rack = L.CLOSET.rack
  return lay
end

function P.networkRack()
  local lay = L.rackLayout()
  return L.piece(lay.w, lay.h, function(R, PX)
    R(0, 0, 70, 88, "#3A3F4A"); R(0, 0, 1, 88, "#5A6070"); R(69, 0, 1, 88, "#23262D")
    R(5, 1, 60, 86, "#14161C")
    for y = 5, 85, 8 do PX(2, y, "#14161C"); PX(67, y, "#14161C") end         -- rack screws
    local function plate(d, col, hi)
      local x, y, w, h = d[1], d[2], d[3], d[4]
      R(x, y, w, h, col); R(x, y, w, 1, hi); R(x, y + h - 1, w, 1, "#0E1015")
    end
    local dev = lay.devices
    -- patch panel: 8 numbered jacks
    plate(dev.patch, "#2B2F38", "#4A505C")
    for i = 1, 8 do local x = 8 + 7 * (i - 1); R(x, 5, 4, 4, "#0E1015"); R(x, 5, 4, 1, "#7A8090") end
    -- switch: 12 ports with a link and an activity LED over each
    plate(dev.switch, "#4A505C", "#6A7080")
    for j = 1, 12 do
      local x = 9 + 4 * (j - 1)
      PX(x, 15, "#23262D"); PX(x + 2, 15, "#23262D")
      R(x, 18, 3, 4, "#0E1015"); R(x, 18, 3, 1, "#9AA0AE")
    end
    R(59, 18, 3, 3, "#0E1015"); R(8, 23, 20, 1, "#2B2F38")                    -- power inlet and a label strip
    -- router: WAN, three LAN ports, LEDs, a vent
    plate(dev.router, "#3A5E8C", "#5F86B8")
    for _, x in ipairs({9, 20, 26, 32}) do R(x, 31, 4, 4, "#0E1015"); R(x, 31, 4, 1, "#9AA0AE") end
    R(9, 29, 1, 1, "#23262D"); R(13, 29, 1, 1, "#23262D"); R(20, 29, 1, 1, "#23262D"); R(24, 29, 1, 1, "#23262D")
    for x = 40, 56, 3 do R(x, 29, 1, 6, "#2A456B") end
    R(60, 31, 3, 3, "#0E1015")
    -- NAS: four drive bays, a power button and a network jack
    plate(dev.nas, "#2F333B", "#4A505C")
    for b = 1, 4 do
      local x = 8 + 11 * (b - 1)
      R(x, 41, 10, 9, "#1A1D23"); R(x, 41, 10, 1, "#555B69"); R(x + 2, 44, 6, 1, "#2B2F38"); R(x + 2, 46, 6, 1, "#2B2F38")
      PX(x + 8, 50, "#23262D")
    end
    R(55, 43, 4, 4, "#23262D"); R(56, 44, 2, 2, "#5A6070"); PX(57, 41, "#23262D")
    R(54, 49, 4, 3, "#0E1015"); R(60, 48, 3, 3, "#0E1015")
    -- PDU: six outlets
    plate(dev.pdu, "#23262D", "#3A3F4A")
    for k = 1, 6 do
      local x = 8 + 8 * (k - 1)
      R(x, 56, 6, 4, "#0E1015"); R(x, 56, 6, 1, "#555B69"); PX(x + 2, 58, "#3A3F4A"); PX(x + 4, 58, "#3A3F4A")
    end
    PX(57, 57, "#23262D"); R(60, 56, 3, 3, "#0E1015")
    -- UPS: LCD, three outlets, a power button
    plate(dev.ups, "#33363F", "#555B69")
    R(8, 66, 22, 12, "#0E1015"); R(9, 67, 20, 10, "#2A3A2E")
    for k = 1, 3 do
      local x = 36 + 8 * (k - 1)
      R(x, 68, 6, 4, "#0E1015"); R(x, 68, 6, 1, "#555B69"); PX(x + 2, 70, "#3A3F4A"); PX(x + 4, 70, "#3A3F4A")
    end
    R(58, 75, 5, 5, "#23262D"); R(59, 76, 3, 3, "#5A6070"); PX(60, 72, "#23262D"); R(56, 80, 3, 3, "#0E1015")
    R(36, 78, 18, 1, "#23262D"); R(36, 80, 14, 1, "#23262D")                 -- vents
  end)
end

function P.wallOutlet()
  return L.piece(6, 9, function(R)
    R(0, 0, 6, 9, "#EFEBDD"); R(0, 0, 6, 1, "#FFFFFF"); R(5, 0, 1, 9, "#C9C4B2")
    R(1, 1, 4, 3, "#2B2F38"); R(1, 5, 4, 3, "#2B2F38")
    R(2, 2, 1, 1, "#9AA0AE"); R(3, 2, 1, 1, "#9AA0AE"); R(2, 6, 1, 1, "#9AA0AE"); R(3, 6, 1, 1, "#9AA0AE")
  end)
end

function P.ispJack()
  return L.piece(6, 8, function(R)
    R(0, 0, 6, 8, "#EFEBDD"); R(0, 0, 6, 1, "#FFFFFF"); R(5, 0, 1, 8, "#C9C4B2")
    R(1, 2, 4, 4, "#2B2F38"); R(2, 3, 2, 2, "#0E1015"); R(1, 6, 4, 1, "#D23C3C")
  end)
end

-- tiny JSON writer (numbers, strings, arrays, objects) so Godot can read the layout
local function toJson(v, indent)
  indent = indent or ""
  local t = type(v)
  if t == "number" then
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.2f", v)
  elseif t == "string" then return '"' .. v .. '"'
  elseif t == "boolean" then return tostring(v)
  elseif t == "table" then
    if #v > 0 or next(v) == nil then
      local parts = {}
      for _, x in ipairs(v) do parts[#parts + 1] = toJson(x, indent) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = indent .. " " .. '"' .. k .. '": ' .. toJson(v[k], indent .. " ") end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
  end
  return "null"
end

function L.writeRackLayout(path)
  local f = io.open(path, "w")
  f:write(toJson(L.rackLayout()) .. "\n")
  f:close()
end

-- side views for the remaining pieces live in side_views.lua
dofile("D:/creative/pixelproject/tools/side_views.lua")(L, P)

-- flattened character: returns an Image (no padding)
function L.char(name)
  local cs = Sprite{fromFile = dofile("D:/creative/pixelproject/tools/sprite_path.lua")("D:/creative/pixelproject/", name)}
  local img = Image(cs.width, cs.height, ColorMode.RGB)
  img:drawSprite(cs, 1)
  cs:close()
  return img
end

return L
