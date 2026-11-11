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
-- R15 (bigger hat cell): the file's canvas is the intern's 40x64 plus PX columns on both sides and PY rows on top, so a hat can stand
-- 8+ px above the head. All coordinates in this script stay in the INTERN's coordinates (y may be negative for a tall hat); put()
-- adds the margin. tools/make_head_sheets.lua crops the margin off every layer but the hats.
local PX, PY = 8, 12

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

-- R15 (bigger hat cell): a hat is `sil` (the silhouette: rowsOf({y, x0, x1}, ...), y may be negative = above the intern's canvas, up
-- to y -8) plus a paint rule and `over` pixels ({x, y, colour}, applied last). Only the GC colours: look.gd KEEPS lists them, any
-- other colour would be matched to a recolourable source. The head is x 9..30 (outline included), its crown starts at y 1 (hair) or
-- y 4 (bald), the brows are on y 11: a hat ends at y 9 or 10 so the brows and eyes stay clear.
local function rowsOf(list)
  local t = {}
  for _, r in ipairs(list) do t[r[1]] = {r[2], r[3]} end
  return t
end

local HATS = {
  -- a knitted beanie: a dome with ribs, a folded cuff, a white pom
  hat_beanie = {
    sil = rowsOf({
      {-8, 19, 20}, {-7, 17, 22}, {-6, 17, 22}, {-5, 17, 22}, {-4, 18, 21},
      {-3, 15, 24}, {-2, 13, 26}, {-1, 11, 28}, {0, 10, 29}, {1, 9, 30}, {2, 9, 30}, {3, 9, 30}, {4, 9, 30},
      {5, 8, 31}, {6, 8, 31}, {7, 8, 31}, {8, 8, 31}, {9, 8, 31}}),
    paint = function(x, y)
      if y <= -4 then return (x + y) % 2 == 0 and "W" or "F" end                -- the pom: white with grey flecks
      if y == 5 then return "g" end                                              -- the fold line
      if y >= 6 then                                                             -- the cuff: ribs
        if y == 9 then return "g" end
        return x % 2 == 0 and "G" or "L"
      end
      if (x - 9) % 4 == 0 then return "g" end                                    -- the knit ribs of the dome
      if y <= 1 and x <= 17 then return "L" end                                  -- lit from the top left
      return "G"
    end,
  },
  -- a ball cap: six panels with a seam and a button, a front panel, a bill that curves down at the front
  hat_cap = {
    sil = rowsOf({
      {-4, 17, 22}, {-3, 14, 25}, {-2, 12, 27}, {-1, 11, 28}, {0, 10, 29},
      {1, 9, 30}, {2, 9, 30}, {3, 9, 30}, {4, 9, 30}, {5, 9, 30}, {6, 9, 30}, {7, 9, 30}, {8, 9, 31},
      {9, 9, 34}, {10, 24, 36}, {11, 30, 37}, {12, 34, 37}}),
    paint = function(x, y)
      if y >= 9 and x >= 24 then return (y == 9 or (y == 10 and x <= 30)) and "N" or "n" end   -- the bill: lit top, dark underside
      if y >= 9 then return "n" end
      if x >= 20 and y >= -1 then return "N" end                                  -- the front panel (lighter than the crown)
      return "n"
    end,
    over = function()
      local o = {}
      for y = -3, 8 do o[#o + 1] = {y <= 2 and 19 or (y <= 5 and 20 or 21), y, "K"} end   -- the seam between the panels
      o[#o + 1] = {19, -3, "S"}; o[#o + 1] = {20, -3, "S"}                         -- the button on top
      for x = 22, 26 do o[#o + 1] = {x, 3, "W"}; o[#o + 1] = {x, 4, "W"} end       -- a logo patch on the front panel
      o[#o + 1] = {24, 3, "S"}; o[#o + 1] = {24, 4, "S"}
      return o
    end,
  },
  -- a hard hat: a dome, a ridge along the top, a rim, a short bill at the front and a lamp
  hat_hardhat = {
    sil = rowsOf({
      {-5, 16, 23}, {-4, 14, 25}, {-3, 12, 27}, {-2, 11, 28}, {-1, 10, 29}, {0, 9, 30},
      {1, 9, 30}, {2, 9, 30}, {3, 9, 30}, {4, 9, 30}, {5, 9, 30}, {6, 9, 30},
      {7, 8, 31}, {8, 7, 33}, {9, 8, 35}}),
    paint = function(x, y)
      if y >= 7 then return y == 8 and "Y" or "y" end                             -- the rim: lit, then shaded
      if x >= 20 and x <= 22 then return x == 20 and "H" or (x == 21 and "Y" or "y") end   -- the ridge
      if y <= 2 and x <= 17 and x + y <= 17 then return "H" end                    -- lit from the top left
      if x >= 27 then return "y" end
      return "Y"
    end,
    over = function()
      local o = {}
      local lamp = {"KKKKKKK", "KSSWWSK", "KSSWWSK", "KKKKKKK"}                    -- the lamp on the front of the dome
      for r, row in ipairs(lamp) do
        for c = 1, #row do o[#o + 1] = {23 + c - 1, 1 + r - 1, row:sub(c, c)} end
      end
      return o
    end,
  },
  -- a Santa hat (R15 art pass 2): a red cone that rises and flops back over the head, a white pom on the tip, a fur band
  hat_santa = {
    sil = rowsOf({
      {-8, 9, 12}, {-7, 8, 13}, {-6, 8, 16}, {-5, 8, 18}, {-4, 9, 20}, {-3, 10, 21}, {-2, 10, 23}, {-1, 9, 24},
      {0, 9, 25}, {1, 9, 26}, {2, 9, 27}, {3, 9, 28}, {4, 9, 29}, {5, 9, 30}, {6, 9, 30}, {7, 9, 30},
      {8, 8, 31}, {9, 8, 31}, {10, 9, 30}}),
    paint = function(x, y)
      if y <= -4 and x <= 13 then return (x + y) % 3 == 0 and "F" or "W" end       -- the pom
      if y >= 8 then return y == 10 and "F" or "W" end                             -- the fur band
      if x >= 27 or (y <= -2 and x - y >= 24) then return "r" end                  -- the shaded side
      return "R"
    end,
  },
  -- a bucket hat (R15 art pass 2): a rounded crown with a stitched seam and a darker band, eyelets, a brim that droops all round
  hat_bucket = {
    sil = rowsOf({
      {-3, 15, 24}, {-2, 12, 27}, {-1, 11, 28}, {0, 10, 29}, {1, 10, 29}, {2, 10, 29}, {3, 10, 29}, {4, 10, 29}, {5, 10, 29},
      {6, 8, 31}, {7, 6, 33}, {8, 5, 34}, {9, 6, 33}}),
    paint = function(x, y)
      if y == 5 then return "q" end                                                -- the band
      if y == 3 then return x % 2 == 0 and "q" or "Q" end                          -- stitches
      if y == 6 then return "Q" end                                                -- the brim, lit on top
      if y == 7 then return x % 2 == 0 and "Q" or "q" end                          -- stitched brim
      if y >= 8 then return "q" end                                                -- the shaded underside
      return "Q"
    end,
    over = function() return {{12, 2, "K"}, {27, 2, "K"}} end,                      -- the eyelets
  },
  -- a party hat: a tall striped cone with a pom (a 4-wide tip under a 6-wide ball)
  hat_party = {
    sil = rowsOf({
      {-7, 18, 21}, {-6, 17, 22}, {-5, 17, 22}, {-4, 18, 21},
      {-3, 18, 21}, {-2, 18, 21}, {-1, 17, 22}, {0, 17, 22}, {1, 16, 23}, {2, 16, 23}, {3, 15, 24}, {4, 15, 24},
      {5, 14, 25}, {6, 14, 25}, {7, 13, 26}, {8, 13, 26}, {9, 12, 27}}),
    paint = function(x, y)
      if y <= -4 then return (x + y) % 3 == 0 and "H" or "Y" end                  -- the pom
      if y == 9 then return "Y" end                                               -- the base band
      return (((x - y) // 3) % 2 == 0) and "P" or "C"                             -- diagonal stripes
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
  if spec.over then
    for _, o in ipairs(spec.over()) do out[#out + 1] = o end   -- drawn after the silhouette: a later pixel wins
  end
  return out
end

local GEAR = {
  -- R15 art pass 2: a two-pixel strap that meets in a silver clip, a 9x7 badge with a teal header, a photo block (a head and
  -- shoulders) and two text lines
  lanyard_conference = {x0 = 17, rows = {
    [23] = "TT.......TT",
    [24] = "tTT.....TTt",
    [25] = ".tTT...TTt.",
    [26] = "..tTT.TTt..",
    [27] = "...tTTTt...",
    [28] = ".KKKKSKKKK.",
    [29] = ".KTTTTTTTK.",
    [30] = ".KWCCCWSSK.",
    [31] = ".KWCQCWWWK.",
    [32] = ".KWQQQWSSK.",
    [33] = ".KWWWWWWWK.",
    [34] = ".KKKKKKKKK.",
  }},
  -- R15 art pass 2: a HELLO nametag you can read as one: outlined, a red header with white letter dots, a handwritten name
  badge_name = {x0 = 20, rows = {
    [28] = "KKKKKKKKK",
    [29] = "KRWRWRWRK",
    [30] = "KRRRRRRRK",
    [31] = "KWWWWWWWK",
    [32] = "KWKKKKKWK",
    [33] = "KWWWWWWWK",
    [34] = "KKKKKKKKK",
  }},
  -- R15 art pass: a strap, a case and a dial instead of a flat band (the dark dial with one lit pixel is what reads at 4 x 3)
  watch_silver = {x0 = 10, rows = {[37] = "FSSF", [38] = "SKWS", [39] = "FSSF"}},
  watch_gold = {x0 = 10, rows = {[37] = "yYYy", [38] = "YKHY", [39] = "yYYy"}},
  watch_sport = {x0 = 10, rows = {[37] = "rRRr", [38] = "RKCR", [39] = "rRRr"}},
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

-- migrate an old 40x64 file: grow the canvas, the cels move with it
if spr.width == 40 then
  spr:crop(-PX, -PY, 40 + 2 * PX, 64 + PY)
  print("canvas grown to", spr.width, spr.height)
end
local function put(im, x, y, c) im:putPixel(x + PX, y + PY, c) end

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
      if ch ~= "." then put(im, X0 + c - 1, y, rgb(COLORS[ch])) end
    end
  end
  addLayer(name, im)
end
for _, name in ipairs(ORDER2) do
  local im = Image(spr.width, spr.height, ColorMode.RGB)
  if HATS[name] then
    for _, p in ipairs(hatPixels(HATS[name])) do put(im, p[1], p[2], rgb(GC[p[3]])) end
  else
    local g = GEAR[name]
    for y, row in pairs(g.rows) do
      for c = 1, #row do
        local ch = row:sub(c, c)
        if ch ~= "." then put(im, g.x0 + c - 1, y, rgb(GC[ch])) end
      end
    end
  end
  addLayer(name, im)
end
spr:saveAs(OUTF)
spr:close()
