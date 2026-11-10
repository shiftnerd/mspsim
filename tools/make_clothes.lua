-- The character creator's REAL CLOTHES, source art (roadmap R15 level 3 step f). Two outputs:
--   1. the BARE-SKIN BASE character: sprites/custom/custom_bare_{right,left}.aseprite, a copy of the intern still with the shirt, belt, collar,
--      trousers, shoes AND hair layers hidden (they stay in the file: the animation engine still measures them, so the death frames land
--      exactly where the intern's do) and the polo sleeves on both arms recoloured to skin. tools/build_anims.lua turns it into the sheets
--      like any other character (ONLY = {"custom_bare"}), the generator lists custom_bare in EXTRA_CHARACTERS.
--   2. office/clothes.aseprite: one hidden layer per piece, named <slot>_<id>_<part>, on the 40x64 canvas, RIGHT-facing, flat colours of
--      Look.SOURCES / Look.KEEPS (so the palette shader recolours them), every sleeve piece INSIDE the silhouette of the bare arm it covers:
--        shirt_<id>_far / _torso / _near   far sleeve, shirt body (collar included), near sleeve   polo tee button sweater
--        bottom_<id>                       the Pants layer (torso part rows <= 46, legs below)       trousers jeans shorts skirt
--        belt_<id>                         the belt, drawn over the shirt hem                        belt (trousers and jeans)
--        shoes_<id>                        the Shoes layer                                           dress (= the intern's) sneakers boots
--      The left-facing sheets are the mirror of this art (x -> 39 - x). `tools/make_clothes_sheets.lua` renders the overlay sheets.
-- Like make_accessories.lua it OPENS an existing office/clothes.aseprite and adds only the missing layers, so a hand-edited file is safe
-- (delete a layer to redraw it). Run:  ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_clothes.lua")   (Aseprite.exe -b --script x.lua)
local R = ROOT or "D:/creative/pixelproject/"
local SP = dofile(R .. "tools/sprite_path.lua")
local W, H = 40, 64
local function rgba(hex)
  return app.pixelColor.rgba(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), 255)
end
local LEG = {
  ["#"] = "17121f", s = "f3b488", d = "d88a62", D = "b8663f",
  B = "4f7fd0", b = "3a62a8", w = "bbd0f5",
  P = "3a3f66", p = "2f3354", q = "272b48",
  H = "5a3522", h = "4a2c1c", c = "c8ccd8", e = "ffffff",
}
local function A(v) return app.pixelColor.rgbaA(v) end

-- put rows of text: '.' leaves the pixel, '_' erases it, anything else is a LEG colour
local function rows(img, x0, y0, list)
  for j, line in ipairs(list) do
    for i = 1, #line do
      local ch = line:sub(i, i)
      local x, y = x0 + i - 1, y0 + j - 1
      if ch == "_" then img:putPixel(x, y, 0)
      elseif ch ~= "." then img:putPixel(x, y, rgba(assert(LEG[ch], "unknown colour " .. ch))) end
    end
  end
end
local function fill(img, x0, y0, x1, y1, ch)
  for y = y0, y1 do for x = x0, x1 do img:putPixel(x, y, rgba(LEG[ch])) end end
end
local function clone(im) local c = Image(im.width, im.height, ColorMode.RGB); c:drawImage(im, Point(0, 0)); return c end
local function band(im, y0, y1)   -- only the rows y0..y1 of an image
  local c = Image(W, H, ColorMode.RGB)
  for y = y0, y1 do for x = 0, W - 1 do c:putPixel(x, y, im:getPixel(x, y)) end end
  return c
end

-- the intern's layers (right facing)
local src = Sprite{fromFile = SP(R, "office_intern_right")}
local L = {}
for _, l in ipairs(src.layers) do
  local im = Image(W, H, ColorMode.RGB)
  if l:cel(1) then im:drawImage(l:cel(1).image, l:cel(1).position) end
  L[l.name] = im
end
src:close()

local pieces = {}   -- name -> image, in drawing order
local order = {}
local function add(name, im) pieces[name] = im; order[#order + 1] = name end

-- ---- shirts ----------------------------------------------------------------------------------------------------------------
local polo_torso = clone(L["Shirt"]); polo_torso:drawImage(L["Collar"], Point(0, 0))
add("shirt_polo_far", band(L["Back Arm"], 23, 28))
add("shirt_polo_torso", polo_torso)
add("shirt_polo_near", band(L["Near Arm"], 23, 28))

-- tee: crew neck with a rib, a darker hem; the sleeves are the polo's with a shaded hem row
local tee = clone(L["Shirt"])
rows(tee, 17, 23, {"b____b"})
rows(tee, 18, 24, {"bbbb"})
rows(tee, 13, 38, {"bbbbbbbbbbbbbbb"})
add("shirt_tee_far", band(L["Back Arm"], 23, 28))
add("shirt_tee_torso", tee)
local tee_near = band(L["Near Arm"], 23, 28)
rows(tee_near, 9, 28, {"bbbbbb"})
add("shirt_tee_near", tee_near)

-- button-down: collar points, a placket with buttons, a chest pocket, long sleeves with a light cuff
local bd = clone(L["Shirt"])
rows(bd, 17, 23, {"wbssssbw"})
rows(bd, 18, 24, {"wbssbw"})
rows(bd, 19, 25, {"wbbw"})
for y = 26, 38 do bd:putPixel(21, y, rgba(LEG.b)) end
for _, y in ipairs({27, 30, 33, 36}) do bd:putPixel(21, y, rgba(LEG.w)) end
rows(bd, 14, 28, {"bbbb", "b..b", "b..b", "bbbb"})
add("shirt_button_torso", bd)
-- long sleeves (R15 art pass): not a flat tube. A crease at the elbow (row 34, where the arm bends) and a shorter one above it on
-- the near sleeve, a lit fold on the far one (it is the shade colour all the way down), then the three cuff rows
local function longNear(cuff, rib)
  local im = band(L["Near Arm"], 23, 28)
  for y = 29, 37 do rows(im, 10, y, {"BBBb"}) end
  rows(im, 10, 31, {"BBbb"}); rows(im, 10, 34, {"bbBb"}); rows(im, 10, 35, {"BbBb"})
  rows(im, 10, 38, {cuff[1]}); rows(im, 10, 39, {cuff[2]}); rows(im, 10, 40, {cuff[3]})
  return im
end
local function longFar(cuff)
  local im = band(L["Back Arm"], 23, 28)
  for y = 29, 37 do rows(im, 28, y, {"bbb"}) end
  rows(im, 28, 33, {"Bbb"}); rows(im, 28, 34, {"BBb"})
  rows(im, 28, 38, {cuff[1]}); rows(im, 28, 39, {cuff[2]}); rows(im, 28, 40, {cuff[3]})
  return im
end
add("shirt_button_far", longFar({"bbb", "www", "bbb"}))
add("shirt_button_near", longNear({"bbbb", "wwwb", "bbbb"}))

-- sweater: ribbed crew neck, vertical knit ribs, ribbed hem and cuffs, long sleeves
local sw = clone(L["Shirt"])
for y = 24, 36 do for _, x in ipairs({15, 18, 21, 24}) do sw:putPixel(x, y, rgba(LEG.b)) end end
for y = 37, 38 do for x = 13, 27 do sw:putPixel(x, y, rgba((x % 2 == 0) and LEG.b or LEG.B)) end end
rows(sw, 16, 23, {"bb____bb"})
rows(sw, 17, 24, {"bbbbbb"})
add("shirt_sweater_far", longFar({"bbb", "BbB", "bbb"}))
add("shirt_sweater_torso", sw)
add("shirt_sweater_near", longNear({"bbbb", "BbBb", "bbbb"}))

-- ---- bottoms -----------------------------------------------------------------------------------------------------------------
add("bottom_trousers", clone(L["Pants"]))
add("belt_belt", clone(L["Belt"]))

-- jeans: the trousers with pocket stitching, a fly stitch and a turn-up
local jeans = clone(L["Pants"])
rows(jeans, 13, 40, {"q....", ".q...", "..qqq"})
rows(jeans, 21, 40, {"q", "q", "q", "q"})
rows(jeans, 13, 55, {"pppppp"}); rows(jeans, 22, 55, {"qqqqqq"})
-- R15 art pass: a stitched waistband, the second front pocket, creases behind the knee and at the thigh
rows(jeans, 13, 38, {"ppppppppppppp"})
rows(jeans, 23, 40, {"..p", ".p.", "p.."})
rows(jeans, 14, 47, {"pp"}); rows(jeans, 16, 51, {"ppp"}); rows(jeans, 13, 52, {"pp"})
rows(jeans, 24, 51, {"qq"})
add("bottom_jeans", jeans)

-- skin legs for shorts and skirt: the trousers' silhouette below the hip in skin tones (near leg left of the gap, far leg right)
local function skinLegs(img, from)
  for y = from, 57 do
    for x = 12, 28 do
      local v = img:getPixel(x, y)
      if A(v) > 0 then
        local r = app.pixelColor.rgbaR(v)
        if v == rgba(LEG.P) then img:putPixel(x, y, rgba((x >= 18) and LEG.d or LEG.s))
        elseif v == rgba(LEG.p) then img:putPixel(x, y, rgba(LEG.d))
        elseif v == rgba(LEG.q) then img:putPixel(x, y, rgba(LEG.D)) end
      end
    end
  end
end
local shorts = clone(L["Pants"])
skinLegs(shorts, 51)
rows(shorts, 13, 50, {"pppppp"}); rows(shorts, 22, 50, {"qqqqqq"})
add("bottom_shorts", shorts)

-- skirt (R15 art pass: it was a mini skirt hidden by the shirt hem and the hands): an A-line skirt to above the knee, rows 36 to 50,
-- flaring from 17 to 21 px, three pleats, a stitched hem. Rows 47 to 50 lie on the thighs right under the hip pivot, so each half
-- follows its leg by a pixel at most and the skirt stays whole in a walk; seated it lies along the thighs
local skirt = clone(L["Pants"])
skinLegs(skirt, 47)
for y = 36, 50 do for x = 0, W - 1 do skirt:putPixel(x, y, 0) end end
rows(skirt, 13, 36, {"###############"})
for y = 37, 41 do rows(skirt, 12, y, {"#PPPPPPPPPPPPPqq#"}) end
for y = 42, 44 do rows(skirt, 11, y, {"#PPPPPPPPPPPPPPPqq#"}) end
for y = 45, 49 do rows(skirt, 10, y, {"#PPPPPPPPPPPPPPPPPqq#"}) end
rows(skirt, 10, 50, {string.rep("#", 21)})
rows(skirt, 13, 38, {"ppppppppppppp"})                              -- the waistband
for y = 40, 48 do rows(skirt, 16, y, {"p"}); rows(skirt, 20, y, {"p"}); rows(skirt, 24, y, {"p"}) end
rows(skirt, 11, 49, {"ppppppppppppppppp"})                          -- the hem
add("bottom_skirt", skirt)

-- ---- shoes -------------------------------------------------------------------------------------------------------------------
add("shoes_dress", clone(L["Shoes"]))
-- sneakers: white toe cap and laces, a white sole (the near shoe is the left one, both toes point right)
local sn = clone(L["Shoes"])
rows(sn, 12, 58, {"HHHHHHHHH"}); rows(sn, 22, 58, {"hhhhhhhhh"})
rows(sn, 12, 59, {"HHHHHHHHH"}); rows(sn, 22, 59, {"hhhhhhhhh"})
rows(sn, 12, 60, {"ccccccccc"}); rows(sn, 22, 60, {"ccccccccc"})
rows(sn, 16, 58, {"e.e.eee"}); rows(sn, 26, 58, {"e.e.eee"})
rows(sn, 19, 59, {"ee"}); rows(sn, 29, 59, {"ee"})
add("shoes_sneakers", sn)
-- boots: a shaft up the shin with a darker cuff, a heavy dark sole
local bt = clone(L["Shoes"])
for _, leg in ipairs({{12, 19, "H"}, {21, 28, "h"}}) do
  local x0, x1, ch = leg[1], leg[2], leg[3]
  rows(bt, x0, 52, {"#" .. string.rep("h", x1 - x0 - 1) .. "#"})
  for y = 53, 56 do rows(bt, x0, y, {"#" .. string.rep(ch, x1 - x0 - 1) .. "#"}) end
end
rows(bt, 12, 60, {"hhhhhhhhh"}); rows(bt, 22, 60, {"hhhhhhhhh"})
rows(bt, 16, 58, {"c.c"}); rows(bt, 26, 58, {"c.c"})
add("shoes_boots", bt)

-- ---- the file --------------------------------------------------------------------------------------------------------------------
local path = R .. "office/clothes.aseprite"
local spr
local have = {}
if app.fs.isFile(path) then
  spr = Sprite{fromFile = path}
  for _, l in ipairs(spr.layers) do have[l.name] = true end
else
  spr = Sprite(W, H, ColorMode.RGB)
  spr.layers[1].name = "_reference"
  spr.layers[1].isVisible = false
end
local added = {}
for _, name in ipairs(order) do
  if not have[name] then
    local l = spr:newLayer()
    l.name = name
    l.isVisible = false
    spr:newCel(l, 1, pieces[name], Point(0, 0))
    added[#added + 1] = name
  end
end
spr:saveAs(path)
spr:close()
print("clothes.aseprite, added " .. #added .. " layers: " .. table.concat(added, " "))

-- ---- the bare base character --------------------------------------------------------------------------------------------------
for _, side in ipairs({"right", "left"}) do
  local out = SP(R, "custom_bare_" .. side)
  local s = Sprite{fromFile = SP(R, "office_intern_" .. side)}
  for _, l in ipairs(s.layers) do
    local nm = l.name
    if nm == "Shirt" or nm == "Belt" or nm == "Collar" or nm == "Pants" or nm == "Shoes" or nm == "Hair" then
      l.isVisible = false          -- kept: the engine measures them (the death frames' shift) but the sheets do not draw them
    elseif nm == "Back Arm" or nm == "Near Arm" then
      local c = l:cel(1)
      local img = Image(c.image)
      local to = (nm == "Back Arm") and LEG.d or LEG.s
      for y = 0, img.height - 1 do for x = 0, img.width - 1 do
        local v = img:getPixel(x, y)
        if A(v) > 0 and (v == rgba(LEG.B) or v == rgba(LEG.b)) then img:putPixel(x, y, rgba(to)) end
      end end
      c.image = img
    end
  end
  s:saveAs(out)
  s:close()
  print("wrote " .. out)
end
