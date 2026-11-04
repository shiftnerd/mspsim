-- Draws the character creator's head accessories (roadmap R15 level 3 step b) as layers on the intern's head and saves
-- office/accessories.aseprite: 4 glasses and 4 facial hair styles, right-facing, on the intern still's 40x64 canvas (the intern's own
-- layers sit below as a reference and are NOT read by the sheet maker). From then on the .aseprite is the source: edit the layers
-- by hand if you like; tools/make_head_sheets.lua reads the layers named <slot>_<id> (glasses_thin, beard_full ...), mirrors them
-- for the left-facing head and renders the overlay sheets. This script only bootstraps the file (and holds the first drawing).
--   ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_accessories.lua")      (Aseprite.exe -b --script x.lua)
-- Geometry of the intern's head (right-facing, canvas x / y): eye whites near x19..23, far x25..28, y12..15 (pupils x22,23 and
-- x27,28), brows y11 (x21..23, x25..28), the flat cheek outline x29, mouth y19 x23..26, nose patch (28,16) (27..28,17), the jaw
-- outline y22, skin on rows 16..21 from x13..16 to x26..28, the ear at x16 (y14..16). The hair covers y<=10 above the eyes.
-- Colours are the Look.SOURCES / KEEPS source colours: the frame (role "frame") 1e1e26, the lens (kept) 2f3d44, a glint ffffff,
-- the beard (role "beard", base + shade) 7d5a3a / 55402c, stubble (role "stubble") e0a07a. No outline is added: every piece sits inside
-- the head outline (that keeps the death-frame boxes equal), the frames are drawn in the dark frame colour.
local R = ROOT or "D:/creative/pixelproject/"
local COLORS = {F = "1e1e26", L = "2f3d44", W = "ffffff", B = "7d5a3a", S = "55402c", T = "e0a07a"}
local X0 = 12  -- the first column of every row is canvas x = 12

local function pad(rows)  -- glasses rows are written from x = 14
  local out = {}
  for y, s in pairs(rows) do out[y] = ".." .. s end
  return out
end

local ART = {
  glasses_thin = pad({
    [10] = "....FFFFFFFFFFF.",
    [11] = "....F.....F.....",
    [12] = ".FFFF.....F.....",
    [13] = "....F.....F.....",
    [14] = "....F.....F.....",
    [15] = "....F.....F.....",
    [16] = "....FFFFFFFFFFF.",
  }),
  glasses_thick = pad({
    [9]  = "....FFFFFFFFFFF.",
    [10] = "....FFFFFFFFFFF.",
    [11] = "...FF.....F.....",
    [12] = "FFFFF.....F.....",
    [13] = "...FF.....F.....",
    [14] = "...FF.....F.....",
    [15] = "...FF.....F.....",
    [16] = "...FFFFFFFFFFFF.",
    [17] = "...FFFFFFFFFFFF.",
  }),
  glasses_round = pad({
    [10] = "......FFF...FF..",
    [11] = ".....F..........",   -- the brows (y11, x21..) close the rings at the top right: nothing covers them
    [12] = ".FFFF.....F.....",
    [13] = "....F.....F.....",
    [14] = "....F.....F.....",
    [15] = ".....F...F.F..F.",
    [16] = "......FFF...FF..",
  }),
  glasses_aviator = pad({
    [10] = "....FFFFFFFFFFF.",
    [11] = "....FLLLLLFLLLL.",
    [12] = ".FFFFWLLLLFLLLL.",
    [13] = "....FLLLLLFLLLL.",
    [14] = "....FLLLLLFLLLL.",
    [15] = ".....FLLLF.FLLF.",
    [16] = "......FFF...FF..",
  }),
  beard_stubble = {
    [16] = ".....TT...........",
    [17] = "...TTTTTTTTTTTT...",
    [18] = "...TTTTTTTTTTTTTT.",
    [19] = "..TTTTTTTTT....TT.",
    [20] = ".TTTTTTTTTTTTTTT..",
    [21] = ".TTTTTTTTTTTTTT...",
  },
  beard_goatee = {
    [18] = "..........BBBBBBB.",
    [19] = "..........B....BB.",
    [20] = ".......BBBBBBBB...",
    [21] = "........SSSSSS....",
  },
  beard_full = {
    [16] = ".....BB...........",
    [17] = "...BBBBB..........",
    [18] = "...BBBBBBB.BBBBBB.",
    [19] = "..BBBBBBBBB....BB.",
    [20] = ".BBBBBBBBBBBBBBB..",
    [21] = ".SSSSSSSSSSSSSS...",
  },
  beard_moustache = {
    [17] = "...........BBBB...",
    [18] = ".........BBBBBBBB.",
    [19] = ".........BB....BB.",
  },
}
local ORDER = {"glasses_thin", "glasses_thick", "glasses_round", "glasses_aviator", "beard_stubble", "beard_goatee", "beard_full", "beard_moustache"}

local function rgb(h)
  return app.pixelColor.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end

local spr = Sprite{fromFile = R .. "sprites/staff/office_intern_right.aseprite"}
for _, l in ipairs(spr.layers) do l.isVisible = true end
for _, name in ipairs(ORDER) do
  local im = Image(spr.width, spr.height, ColorMode.RGB)
  local n = 0
  for y, row in pairs(ART[name]) do
    assert(#row == 18, name .. " row " .. y .. " has " .. #row .. " columns")
    for c = 1, #row do
      local ch = row:sub(c, c)
      if ch ~= "." then
        im:putPixel(X0 + c - 1, y, rgb(COLORS[ch]))
        n = n + 1
      end
    end
  end
  local l = spr:newLayer()
  l.name = name
  l.isVisible = false      -- all hidden: switch one on to see it on the intern's head
  spr:newCel(l, 1, im, Point(0, 0))
  print(name, n, "pixels")
end
spr:saveAs(R .. "office/accessories.aseprite")
spr:close()
