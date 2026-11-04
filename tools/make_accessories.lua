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

-- ---- steps (c) and (d): hats (6), the conference lanyard, the HELLO name sticker and watches (3) ------------------------------
-- Hats are a silhouette (rows of x from-to, canvas coords) plus a paint rule; the ink outline goes on every silhouette pixel with
-- an empty 4-neighbour. A hat covers the hair crown (y1..9, x9..30 is the widest hair of the styles that stay under a hat:
-- Look.HAT_HAIR turns spiky, curly and bun into short / ponytail) and may stand 1 px above it (y0) and 2 px beyond it.
-- Torso pieces (lanyard, name sticker) are rows of text from an explicit x; the watches sit on the intern's wrist (x10..13).
-- Colours: K ink 17121f, W ffffff, S c8ccd8 (existing KEEPS) and the new KEEPS of look.gd: Y e8b820, y b88a14, H f6d860 (yellow),
-- R c8283a, r 9a1c2c (red), G 2f6b3a, g 1f4d28, L 4a8a54 (green), N 2c4a7a, n 1f3556 (navy), Q b9a574, q 8c7a52 (khaki),
-- P d0409a (pink), C 40b8d0 (cyan), T 1f9a96, t 16706f (conference teal), F c8c0b0 (fur shade).
local GC = {K = "17121f", W = "ffffff", S = "c8ccd8", F = "c8c0b0", Y = "e8b820", y = "b88a14", H = "f6d860", R = "c8283a",
  r = "9a1c2c", G = "2f6b3a", g = "1f4d28", L = "4a8a54", N = "2c4a7a", n = "1f3556", Q = "b9a574", q = "8c7a52",
  P = "d0409a", C = "40b8d0", T = "1f9a96", t = "16706f"}

local HATS = {
  hat_beanie = {
    sil = {[0] = {15, 24}, {13, 26}, {11, 28}, {10, 29}, {9, 30}, {9, 30}, {9, 30}, {9, 30}, {8, 31}, {8, 31}, {8, 31}},
    paint = function(x, y)
      if y == 7 then return "g" end
      if y >= 8 then return x % 2 == 0 and "G" or "L" end
      if x % 3 == 0 then return "g" end
      if y <= 3 and x <= 18 then return "L" end
      return "G"
    end,
  },
  hat_cap = {
    sil = {[0] = {16, 23}, {13, 26}, {11, 28}, {10, 29}, {9, 30}, {9, 30}, {9, 30}, {9, 30}, {9, 30}, {9, 34}, {29, 34}},
    paint = function(x, y)
      if y >= 9 and x >= 29 then return "n" end
      if (x == 20 or x == 21) and y <= 8 then return "n" end
      if y == 8 then return "n" end
      return "N"
    end,
  },
  hat_hardhat = {
    sil = {[0] = {17, 22}, {13, 26}, {11, 28}, {10, 29}, {9, 30}, {9, 30}, {9, 30}, {9, 30}, {7, 32}, {7, 33}},
    paint = function(x, y)
      if y >= 8 then return y == 9 and "y" or "Y" end
      if x >= 19 and x <= 21 then return "y" end
      if y >= 2 and y <= 4 and x >= 12 and x <= 17 then return "H" end
      if x >= 27 then return "y" end
      return "Y"
    end,
  },
  hat_santa = {
    sil = {[0] = {11, 13}, {10, 22}, {10, 27}, {11, 28}, {10, 29}, {9, 30}, {9, 30}, {9, 30}, {8, 31}, {8, 31}, {8, 31}},
    paint = function(x, y)
      if y >= 8 then return y == 9 and "F" or "W" end
      if x <= 14 and y <= 3 then return (x >= 13 and y >= 2) and "F" or "W" end
      if x >= 26 or y == 7 then return "r" end
      return "R"
    end,
  },
  hat_bucket = {
    sil = {[1] = {15, 24}, {12, 27}, {10, 29}, {9, 30}, {9, 30}, {9, 30}, {9, 30}, {7, 32}, {7, 32}, {8, 31}},
    paint = function(x, y)
      if y >= 8 then return y == 9 and "q" or "Q" end
      if y == 6 or y == 7 then return "q" end
      if y == 3 and x % 2 == 0 then return "q" end
      return "Q"
    end,
  },
  hat_party = {
    sil = {[0] = {19, 20}, {18, 21}, {17, 22}, {16, 23}, {15, 24}, {14, 25}, {13, 26}, {12, 27}, {12, 27}},
    paint = function(x, y)
      if y <= 1 then return y == 0 and "H" or "Y" end
      return (((x - y) // 2) % 2 == 0) and "P" or "C"
    end,
  },
}

local function hatPixels(spec)
  local inS = {}
  local function has(x, y) return inS[y] and inS[y][x] end
  for y, r in pairs(spec.sil) do
    inS[y] = {}
    for x = r[1], r[2] do inS[y][x] = true end
  end
  local out = {}
  for y, r in pairs(spec.sil) do
    for x = r[1], r[2] do
      local edge = not (has(x - 1, y) and has(x + 1, y) and has(x, y - 1) and has(x, y + 1))
      out[#out + 1] = {x, y, edge and "K" or spec.paint(x, y)}
    end
  end
  return out
end

local GEAR = {
  lanyard_conference = {x0 = 17, rows = {
    [23] = "TT.......TT",
    [24] = ".TT.....TT.",
    [25] = "..TT...TT..",
    [26] = "...tT.Tt...",
    [27] = "....SSS....",
    [28] = "..KKKKKKK..",
    [29] = "..KTTTTTK..",
    [30] = "..KTTTTTK..",
    [31] = "..KSSSSWK..",
    [32] = "..KSSWWWK..",
    [33] = "..KWWWWWK..",
    [34] = "..KKKKKKK..",
  }},
  badge_name = {x0 = 23, rows = {[29] = "RRRRR", [30] = "WWWWW", [31] = "WKKKW", [32] = "WWWWW"}},
  watch_silver = {x0 = 10, rows = {[37] = "SSSS", [38] = "SWWS", [39] = "SSSS"}},
  watch_gold = {x0 = 10, rows = {[37] = "yyyy", [38] = "YHHY", [39] = "yyyy"}},
  watch_sport = {x0 = 10, rows = {[37] = "RRRR", [38] = "RWWR", [39] = "rrrr"}},
}
local ORDER2 = {"hat_beanie", "hat_cap", "hat_hardhat", "hat_santa", "hat_bucket", "hat_party", "lanyard_conference", "badge_name",
  "watch_silver", "watch_gold", "watch_sport"}

local function rgb(h)
  return app.pixelColor.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end

-- the file: bootstrapped from the intern's still, or (it exists) opened and only the layers it does not have yet are added, so a
-- hand-edited accessories.aseprite is never overwritten
local OUTF = R .. "office/accessories.aseprite"
local existing = io.open(OUTF, "rb")
local spr
if existing then
  existing:close()
  spr = Sprite{fromFile = OUTF}
else
  spr = Sprite{fromFile = R .. "sprites/staff/office_intern_right.aseprite"}
  for _, l in ipairs(spr.layers) do l.isVisible = true end
end
local have = {}
for _, l in ipairs(spr.layers) do have[l.name] = true end

local function addLayer(name, im)
  if have[name] then print(name, "exists, kept"); return end
  local l = spr:newLayer()
  l.name = name
  l.isVisible = false      -- all hidden: switch one on to see it on the intern
  spr:newCel(l, 1, im, Point(0, 0))
  have[name] = true
  print(name, "added")
end

for _, name in ipairs(ORDER) do
  local im = Image(spr.width, spr.height, ColorMode.RGB)
  for y, row in pairs(ART[name]) do
    assert(#row == 18, name .. " row " .. y .. " has " .. #row .. " columns")
    for c = 1, #row do
      local ch = row:sub(c, c)
      if ch ~= "." then im:putPixel(X0 + c - 1, y, rgb(COLORS[ch])) end
    end
  end
  addLayer(name, im)
end
for _, name in ipairs(ORDER2) do
  local im = Image(spr.width, spr.height, ColorMode.RGB)
  if HATS[name] then
    for _, p in ipairs(hatPixels(HATS[name])) do im:putPixel(p[1], p[2], rgb(GC[p[3]])) end
  else
    local g = GEAR[name]
    for y, row in pairs(g.rows) do
      for c = 1, #row do
        local ch = row:sub(c, c)
        if ch ~= "." then im:putPixel(g.x0 + c - 1, y, rgb(GC[ch])) end
      end
    end
  end
  addLayer(name, im)
end
spr:saveAs(OUTF)
spr:close()
