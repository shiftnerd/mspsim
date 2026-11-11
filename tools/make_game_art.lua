-- Small art for the mini-games: floor paint for the chair games (chair_track.gd), the "asked for" star of a Dispatch
-- ticket chip (dispatch.gd), a dinner plate (the restaurant table) and Jen's headset on its stand.
-- Sources office/pieces/game_*.aseprite, PNGs godot/assets/props/ (and assets/ui/ for the star).
-- Run in a checkout:  ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_game_art.lua")   (Aseprite.exe -b --script x.lua)
-- Floor paint has no outline (it is paint on concrete, worn in places); objects have the usual 1 px #17121F outline.
local PR = dofile((ROOT or "D:/creative/pixelproject/") .. "tools/piece_rows.lua")
local ASE = "office/pieces/"
local PAINT = {r = "#B8483A", w = "#D8DCE0", y = "#D8B030", k = "#2A2A33"}
local function setc(rows, x, y, ch) rows[y + 1] = rows[y + 1]:sub(1, x) .. ch .. rows[y + 1]:sub(x + 2) end
local function export(name, png)
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "game_" .. name .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. png .. name .. ".png")
  s:close()
end

-- ---- the painted finish line (10 x 24): a yellow line each side, four columns of 2 px checkers, worn at a few spots ----
do
  local rows = {}
  for y = 0, 23 do
    local s = "y"
    for x = 0, 7 do s = s .. ((((x // 2) + (y // 2)) % 2 == 0) and "k" or "w") end
    rows[#rows + 1] = s .. "y"
  end
  for _, p in ipairs({{3, 2}, {4, 2}, {0, 7}, {6, 9}, {7, 9}, {7, 10}, {2, 15}, {9, 16}, {9, 17}, {5, 21}, {1, 22}}) do setc(rows, p[1], p[2], ".") end
  PR.build{name = "game_chair_finish", ase = ASE, pad = 0, layers = {{name = "Paint", pal = PAINT, rows = rows}}}
  export("chair_finish", "godot/assets/props/")
end

-- ---- the fight ring: an end bracket (12 x 28, the right end is its mirror), a dashed edge tile (12 x 2), a centre spot (30 x 12) ----
do
  local rows = {}
  for y = 0, 27 do
    local stripe = ((y // 4) % 2 == 0) and "rrr" or "www"
    rows[#rows + 1] = ((y < 2 or y > 25) and "rrrrrrrrrrrr" or (stripe .. "........."))
  end
  for _, p in ipairs({{1, 6}, {2, 6}, {9, 0}, {10, 0}, {0, 14}, {2, 19}, {6, 27}, {7, 27}}) do setc(rows, p[1], p[2], ".") end
  PR.build{name = "game_chair_ring_end", ase = ASE, pad = 0, layers = {{name = "Paint", pal = PAINT, rows = rows}}}
  export("chair_ring_end", "godot/assets/props/")
  PR.build{name = "game_chair_ring_line", ase = ASE, pad = 0, layers = {{name = "Paint", pal = PAINT, rows = {"rrrrrrrr....", "rrrrrrr....."}}}}
  export("chair_ring_line", "godot/assets/props/")
  local spot = {}
  local W, H = 30, 12
  for y = 0, H - 1 do
    local s = ""
    for x = 0, W - 1 do
      local dx, dy = (x + 0.5 - W / 2) / (W / 2), (y + 0.5 - H / 2) / (H / 2)
      local d = dx * dx + dy * dy
      local dx2, dy2 = (x + 0.5 - W / 2) / (W / 2 - 1.6), (y + 0.5 - H / 2) / (H / 2 - 1.2)
      s = s .. ((d <= 1.0 and dx2 * dx2 + dy2 * dy2 > 1.0) and "w" or ".")
    end
    spot[#spot + 1] = s
  end
  for x = 13, 16 do setc(spot, x, 5, "w"); setc(spot, x, 6, "w") end     -- the centre mark
  for _, p in ipairs({{4, 2}, {5, 2}, {24, 9}, {25, 9}, {1, 6}}) do setc(spot, p[1], p[2], ".") end
  PR.build{name = "game_chair_ring_spot", ase = ASE, pad = 0, layers = {{name = "Paint", pal = PAINT, rows = spot}}}
  export("chair_ring_spot", "godot/assets/props/")
end

-- ---- the "asked for by name" star of a Dispatch ticket chip (5 x 5, the pixel font's height, no outline) ----
PR.build{name = "game_star_asked", ase = ASE, pad = 0, layers = {{name = "Star", pal = {Y = "#E8A010", h = "#F5D442"}, rows = {
  "..h..",
  "hhYYY",
  ".hYY.",
  ".YYY.",
  "Y...Y",
}}}}
export("star_asked", "godot/assets/ui/")

-- ---- a dinner plate, side on (11 x 5): a white plate with a rim shade, food on it; three foods as three pieces ----
for _, v in ipairs({{"a", "#C8743A", "#8A4A2E", "#5EB04A"}, {"b", "#E8C860", "#C8A038", "#D8483A"}, {"c", "#D8D0B0", "#B8AE8A", "#5EB04A"}}) do
  PR.build{name = "game_dinner_plate_" .. v[1], ase = ASE, layers = {
    {name = "Plate", x = 0, y = 2, pal = {w = "#F4F2EA", s = "#C8CCD8"}, rows = {"wwwwwwwww", ".sssssss."}},
    {name = "Food", x = 1, y = 0, pal = {f = v[2], d = v[3], g = v[4]}, rows = {".fff.gg", "ffffdgg"}},
  }}
  export("dinner_plate_" .. v[1], "godot/assets/props/")
end

-- ---- Jen's headset on its desk stand (9 x 13): a band, two ear cups, a boom mic, a weighted stand ----
PR.build{name = "game_desk_headset", ase = ASE, layers = {
  {name = "Stand", x = 2, y = 4, pal = {g = "#8A8F9A", s = "#5A606C"}, rows = {
    ".g.",
    ".g.",
    ".g.",
    ".g.",
    ".g.",
    "ggs",
  }},
  {name = "Headset", x = 0, y = 0, pal = {b = "#2A2A33", c = "#4A4A55", p = "#4F7FD0", m = "#C8CCD8"}, rows = {
    ".bbbbb.",
    "bc...cb",
    "pp...pp",
    "pp...pp",
    "b......",
    "bm.....",
  }},
}}
export("desk_headset", "godot/assets/props/")

-- ====================================================================================================================
-- R4: themed escape room props. Each theme replaces the study's safe (26x26), trunk (30x18) and globe (16x26) with a
-- piece of the same size (content size, 1 px outline on top, so the PNGs are 28x28, 32x20 and 18x28 like the originals):
--   server    a locked rack cabinet, a crate of drives, a tower UPS
--   detective a filing cabinet with a lock, a steamer trunk, a brass desk globe
--   lab       a beige tower with a key lock, a box of floppies, a CRT on a cart
-- Sources office/pieces/escape_<theme>_<slot>.aseprite (layers Body + Detail), PNGs godot/assets/props/. SetDressing swaps them in.
-- ====================================================================================================================
local function G(w, h)
  local g = {w = w, h = h}
  for y = 1, h do g[y] = {} for x = 1, w do g[y][x] = "." end end
  return g
end
local function F(g, x, y, w, h, c)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do
      if xx >= 0 and yy >= 0 and xx < g.w and yy < g.h then g[yy + 1][xx + 1] = c end
    end
  end
end
local function DISC(g, cx, cy, r, c)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      if (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2 <= r * r then g[y + 1][x + 1] = c end
    end
  end
end
local function ROWS(g)
  local out = {}
  for y = 1, g.h do out[y] = table.concat(g[y]) end
  return out
end
-- a lit top / left edge and a shaded bottom / right edge on a filled box
local function BOX(g, x, y, w, h, base, lit, shade)
  F(g, x, y, w, h, base)
  F(g, x, y, w, 1, lit); F(g, x, y, 1, h, lit)
  F(g, x, y + h - 1, w, 1, shade); F(g, x + w - 1, y, 1, h, shade)
end
local function esc(theme, slot, w, h, pal, body)
  local b, d = G(w, h), G(w, h)
  body(b, d)
  PR.build{name = "escape_" .. theme .. "_" .. slot, ase = ASE, layers = {
    {name = "Body", pal = pal, rows = ROWS(b)},
    {name = "Detail", pal = pal, rows = ROWS(d), outline = false}}}
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "escape_" .. theme .. "_" .. slot .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. "godot/assets/props/escape_" .. theme .. "_" .. slot .. ".png")
  s:close()
end

local STEEL = {B = "#3E4350", L = "#5A6070", D = "#2A2E38", M = "#4A5060", s = "#8E939E", g = "#5FBF6A", r = "#D8483A",
  y = "#C99A3C", Y = "#E8C45A", k = "#17121F", w = "#F4F2EA", c = "#8A8F9A", o = "#6B4A2E", p = "#8A6240", n = "#4A3220", a = "#14241C"}

-- ---- server room ----
-- a locked rack cabinet: mesh door with vent slits, three LEDs, a brass padlock through the hasp
esc("server", "safe", 26, 26, STEEL, function(b, d)
  BOX(b, 0, 0, 26, 24, "B", "L", "D")
  F(b, 2, 2, 22, 20, "M"); F(b, 2, 21, 22, 1, "D")
  F(b, 2, 24, 4, 2, "k"); F(b, 20, 24, 4, 2, "k")
  for _, y in ipairs({4, 7, 10}) do F(d, 4, y, 14, 1, "D"); F(d, 4, y + 1, 14, 1, "L") end
  F(d, 20, 4, 2, 2, "g"); F(d, 20, 7, 2, 2, "g"); F(d, 20, 10, 2, 2, "r")
  F(d, 10, 12, 1, 3, "c"); F(d, 15, 12, 1, 3, "c"); F(d, 10, 12, 6, 1, "c")
  F(d, 9, 15, 8, 5, "y"); F(d, 9, 15, 8, 1, "Y"); F(d, 12, 17, 2, 2, "k")
  F(d, 19, 15, 4, 4, "w")
end)
-- a crate of dead drives: six drives stand in an open wooden crate, labels turned out
esc("server", "trunk", 30, 18, STEEL, function(b, d)
  for i, x in ipairs({1, 6, 11, 16, 21, 26}) do
    local top = ({1, 0, 2, 0, 1, 2})[i]
    F(b, x, top, 4, 9, "c")
    F(d, x, top, 4, 1, "s")
    F(d, x + 1, top + 3, 2, 2, "w")
    F(d, x + 1, top + 6, 2, 1, ({"r", "g", "r", "y", "g", "r"})[i])
  end
  BOX(b, 0, 7, 30, 11, "p", "p", "n")
  F(d, 0, 7, 30, 1, "n")
  F(d, 1, 10, 28, 1, "n"); F(d, 1, 14, 28, 1, "n")
  F(d, 2, 7, 2, 11, "o"); F(d, 26, 7, 2, 11, "o")
  F(d, 12, 11, 6, 3, "w"); F(d, 13, 12, 4, 1, "r")
end)
-- a tower UPS: a small display with battery bars, two outlets, a vent grille, the cable on the floor
esc("server", "globe", 16, 26, STEEL, function(b, d)
  BOX(b, 0, 0, 16, 24, "B", "L", "D")
  F(b, 7, 24, 2, 2, "D")
  F(d, 2, 2, 12, 6, "a")
  F(d, 3, 3, 2, 4, "g"); F(d, 6, 3, 2, 4, "g"); F(d, 9, 3, 2, 4, "g"); F(d, 12, 3, 1, 4, "r")
  F(d, 3, 10, 4, 3, "k"); F(d, 9, 10, 4, 3, "k"); F(d, 4, 11, 1, 1, "s"); F(d, 10, 11, 1, 1, "s")
  F(d, 3, 14, 10, 1, "Y")
  for _, y in ipairs({17, 19, 21}) do F(d, 3, y, 10, 1, "D") end
end)

-- ---- detective's office ----
local DET = {B = "#5E7060", L = "#7C8E7C", D = "#44544A", k = "#17121F", w = "#F4F2EA", s = "#C8CCD8", y = "#C99A3C", Y = "#E8C45A",
  r = "#C8402F", a = "#3A4A5A", b = "#5A6C80", n = "#2E3A48", t = "#6F8FA0", u = "#B89B6A", v = "#8A6A42", o = "#4A3220", p = "#6B4A2E"}
-- a filing cabinet with a lock: three drawers with label plates and handles, the lock on the top drawer
esc("detective", "safe", 26, 26, DET, function(b, d)
  BOX(b, 0, 0, 26, 24, "B", "L", "D")
  F(b, 2, 24, 4, 2, "k"); F(b, 20, 24, 4, 2, "k")
  for _, y in ipairs({1, 9, 17}) do
    F(b, 2, y, 22, 7, "B"); F(b, 2, y, 22, 1, "L"); F(b, 2, y + 6, 22, 1, "D")
    F(d, 9, y + 1, 8, 3, "w"); F(d, 10, y + 2, 6, 1, "D")
    F(d, 10, y + 5, 6, 1, "s")
  end
  F(d, 19, 3, 4, 4, "y"); F(d, 19, 3, 4, 1, "Y"); F(d, 20, 4, 1, 2, "k")
  F(d, 3, 10, 3, 2, "r")
end)
-- a steamer trunk: dark blue slats, brass bands and corners, a brass lock, two travel stickers
esc("detective", "trunk", 30, 18, DET, function(b, d)
  F(b, 1, 0, 28, 6, "a"); F(b, 0, 1, 30, 5, "a")
  F(b, 0, 6, 30, 12, "a")
  F(b, 1, 0, 28, 1, "b"); F(b, 0, 1, 1, 17, "b")
  F(b, 0, 17, 30, 1, "n"); F(b, 29, 1, 1, 17, "n")
  for x = 5, 25, 5 do F(d, x, 8, 1, 9, "n") end
  F(d, 0, 6, 30, 2, "y"); F(d, 0, 6, 30, 1, "Y")
  F(d, 2, 0, 2, 18, "y"); F(d, 26, 0, 2, 18, "y")
  F(d, 13, 6, 4, 5, "Y"); F(d, 14, 8, 2, 2, "k")
  F(d, 6, 9, 5, 4, "r"); F(d, 8, 10, 1, 2, "w")
  F(d, 19, 10, 5, 4, "w"); F(d, 21, 11, 1, 2, "b")
end)
-- a brass desk globe: muted blue seas, tan land, a brass meridian, a red pin, a dark wood foot
esc("detective", "globe", 16, 26, DET, function(b, d)
  DISC(b, 8, 8, 7.8, "t")
  F(b, 7, 16, 2, 5, "y")
  F(b, 5, 21, 6, 1, "p"); F(b, 3, 22, 10, 3, "p")
  F(d, 4, 4, 4, 3, "u"); F(d, 9, 8, 4, 4, "u"); F(d, 5, 10, 2, 2, "u")
  F(d, 11, 1, 1, 14, "Y")
  F(d, 6, 5, 1, 2, "r")
  F(d, 3, 22, 10, 1, "v")
end)

-- ---- 1990s computer lab ----
local LAB = {B = "#D8CDB0", L = "#EDE6D0", D = "#B3A888", k = "#17121F", s = "#8E939E", g = "#5FBF6A", y = "#E8C45A", r = "#D8483A",
  m = "#8A8068", w = "#F4F2EA", c = "#C99A5C", C = "#DDB878", a = "#A07A48", f = "#2A2A33", e = "#6A6F7A", E = "#8A8F9A", z = "#4F7FD0",
  G = "#0F2A1E", P = "#5FE08A", q = "#2E5A44"}
-- a beige tower: a 5.25 inch bay, a 3.5 inch floppy drive, a turbo display and LEDs, a key lock with the key in it
esc("lab", "safe", 26, 26, LAB, function(b, d)
  BOX(b, 0, 0, 26, 24, "B", "L", "D")
  F(b, 2, 24, 4, 2, "k"); F(b, 20, 24, 4, 2, "k")
  F(d, 3, 2, 20, 5, "D"); F(d, 5, 4, 16, 1, "k")
  F(d, 3, 8, 12, 4, "D"); F(d, 4, 10, 9, 1, "k"); F(d, 16, 9, 5, 2, "m")
  F(d, 15, 14, 8, 4, "k"); F(d, 16, 15, 2, 2, "r"); F(d, 19, 15, 2, 2, "r")
  F(d, 3, 14, 2, 2, "g"); F(d, 6, 14, 2, 2, "y")
  DISC(d, 7.5, 21, 2.6, "s"); F(d, 7, 20, 1, 3, "k")
  F(d, 10, 21, 7, 1, "y"); F(d, 16, 19, 3, 4, "y"); F(d, 17, 20, 1, 2, "k")
end)
-- a box of floppy disks: black disks with silver shutters and coloured labels standing in a cardboard box
esc("lab", "trunk", 30, 18, LAB, function(b, d)
  local cols = {"r", "z", "y", "g", "w", "r"}
  for i = 0, 5 do
    local x = 1 + i * 5
    local top = ({1, 0, 2, 0, 1, 0})[i + 1]
    F(b, x, top, 4, 9, "f")
    F(d, x + 1, top, 2, 2, "s")
    F(d, x, top + 4, 4, 3, cols[i + 1])
  end
  BOX(b, 0, 7, 30, 11, "c", "C", "a")
  F(d, 0, 7, 30, 1, "a")
  F(d, 6, 10, 18, 5, "w"); F(d, 8, 11, 8, 1, "f"); F(d, 8, 13, 12, 1, "e"); F(d, 20, 11, 2, 1, "r")
  F(d, 1, 12, 3, 1, "a"); F(d, 26, 12, 3, 1, "a")
end)
-- a CRT monitor on a grey cart: green phosphor with a prompt, a power LED, a cart with a shelf
esc("lab", "globe", 16, 26, LAB, function(b, d)
  BOX(b, 0, 0, 16, 19, "B", "L", "D")
  F(b, 1, 20, 14, 2, "E"); F(b, 1, 21, 2, 5, "e"); F(b, 13, 21, 2, 5, "e"); F(b, 3, 24, 10, 1, "e")
  F(d, 2, 2, 12, 11, "G")
  F(d, 3, 4, 1, 1, "P"); F(d, 4, 5, 1, 1, "P"); F(d, 3, 6, 1, 1, "P"); F(d, 6, 6, 3, 1, "P")
  F(d, 3, 9, 6, 1, "q"); F(d, 11, 2, 2, 1, "q")
  F(d, 11, 15, 2, 2, "g"); F(d, 3, 15, 2, 1, "D"); F(d, 6, 15, 2, 1, "D")
end)

-- ====================================================================================================================
-- Dinner guest (a client or a prospect at the table): a place setting, a name tent and a briefcase leaning on the booth.
-- Sources office/pieces/game_dinner_*.aseprite, PNGs godot/assets/props/dinner_*.png (set_dressing.gd draws them while Outings.dinner_guest()
-- is not empty). Also a fourth plate (spinach dip) so the four shared plates of the ordering round have four faces.
-- ====================================================================================================================
-- a place setting, side on (14 x 5): fork, a plate, a knife, a glass of water
PR.build{name = "game_dinner_setting", ase = ASE, layers = {
  {name = "Cutlery", x = 0, y = 1, pal = {s = "#C8CCD8", d = "#8E939E"}, rows = {
    "s", "s", "s", "d",
  }},
  {name = "Plate", x = 2, y = 3, pal = {w = "#F4F2EA", s = "#C8CCD8"}, rows = {"wwwwwww", ".sssss."}},
  {name = "Knife", x = 10, y = 1, pal = {s = "#C8CCD8", d = "#8E939E"}, rows = {"s", "s", "s", "d"}},
  {name = "Glass", x = 12, y = 0, pal = {g = "#BFE0F0", b = "#6FA8D0"}, rows = {"gg", "gg", "bb", "bb", "bb"}},
}}
export("dinner_setting", "godot/assets/props/")

-- a name tent (5 x 4): a folded white card with a pen scribble and a blue edge
PR.build{name = "game_dinner_tent", ase = ASE, layers = {
  {name = "Card", x = 0, y = 0, pal = {w = "#F4F2EA", s = "#C8CCD8", n = "#4F7FD0", d = "#3A62A8"}, rows = {
    ".www.",
    "wnndw",
    "wwwww",
    "sssss",
  }},
}}
export("dinner_tent", "godot/assets/props/")

-- a briefcase standing on the floor (10 x 8): brown leather, a handle, a brass clasp
PR.build{name = "game_dinner_briefcase", ase = ASE, layers = {
  {name = "Handle", x = 3, y = 0, pal = {h = "#4A3220"}, rows = {"hhhh", "h..h"}},
  {name = "Case", x = 0, y = 2, pal = {b = "#8A5A36", l = "#B07A4A", d = "#5A3A22", y = "#E8C45A"}, rows = {
    "lllllllllb",
    "bbbbbbbbbb",
    "bbbbyybbbb",
    "bbbbyybbbb",
    "bbbbbbbbbb",
    "dddddddddd",
  }},
}}
export("dinner_briefcase", "godot/assets/props/")

-- the fourth plate: a spinach dip with chips, the same size as the other three (11 x 6)
PR.build{name = "game_dinner_plate_d", ase = ASE, layers = {
  {name = "Plate", x = 0, y = 2, pal = {w = "#F4F2EA", s = "#C8CCD8"}, rows = {"wwwwwwwww", ".sssssss."}},
  {name = "Food", x = 1, y = 0, pal = {f = "#6A9A4A", d = "#4A7A34", c = "#E8C860"}, rows = {".ffff.c", "ffdfffc"}},
}}
export("dinner_plate_d", "godot/assets/props/")

-- ====================================================================================================================
-- R8: event card spot illustrations, 32 x 24 content (34 x 26 with the outline), one per season and one per common card theme.
-- Sources office/pieces/ui_card_<id>.aseprite, PNGs godot/assets/ui/card_<id>.png (cards.gd draws one at the top right of a card
-- when it has the width and height for it). Seasons: holidays, tax, xp, school. Themes (the six most common kinds of deck card:
-- printer 5, phone 5, food 5, power / climate 4, security 5, backup / storage 3): printer, phone, food, power, security, backup.
-- ====================================================================================================================
local CARDPAL = {k = "#17121F", w = "#F4F2EA", W = "#C8CCD8", g = "#8A8F9A", G = "#5A606C", r = "#D8483A", R = "#A8322A",
  y = "#E8C45A", o = "#E89A3C", b = "#4F7FD0", B = "#3A62A8", n = "#2E4A6B", t = "#3E9A4E", T = "#2A7A3A", u = "#8A5A36",
  U = "#B07A4A", s = "#BFE0F0", c = "#D9D4B8", N = "#20233A", e = "#CFD8E3", m = "#E3D3C0", f = "#F0E0B8", x = "#3A4A66",
  d = "#D6E0D0", S = "#6FA8D0", C = "#D8CDB0", P = "#5FE08A", h = "#1E3A2A"}
local function card(id, body)
  local g = G(32, 24)
  body(g)
  PR.build{name = "ui_card_" .. id, ase = ASE, layers = {{name = "Art", pal = CARDPAL, rows = ROWS(g)}}}
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "ui_card_" .. id .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. "godot/assets/ui/card_" .. id .. ".png")
  s:close()
end
-- poke a small ASCII sprite (palette keys, '.' is skipped) at x, y
local function S_(g, x, y, rows)
  for r, row in ipairs(rows) do
    for c = 1, #row do
      local ch = row:sub(c, c)
      if ch ~= "." then F(g, x + c - 1, y + r - 1, 1, 1, ch) end
    end
  end
end

card("holidays", function(g)           -- a lit tree, a gift, snow
  F(g, 0, 0, 32, 24, "n")
  for _, p in ipairs({{3, 3}, {9, 6}, {27, 4}, {22, 9}, {17, 2}, {29, 12}, {5, 12}, {24, 14}}) do F(g, p[1], p[2], 1, 1, "w") end
  F(g, 0, 20, 32, 4, "w")
  local tiers = {{3, 13, 13}, {4, 12, 14}, {5, 11, 15}, {6, 10, 16}, {7, 11, 15}, {8, 10, 16}, {9, 9, 17}, {10, 8, 18}, {11, 7, 19},
    {12, 9, 17}, {13, 8, 18}, {14, 7, 19}, {15, 6, 20}, {16, 5, 21}, {17, 4, 22}}
  for _, t in ipairs(tiers) do F(g, t[2], t[1], t[3] - t[2] + 1, 1, "t"); F(g, t[3] - 1, t[1], 2, 1, "T") end
  F(g, 12, 18, 3, 3, "u")
  F(g, 13, 1, 1, 2, "y"); F(g, 12, 2, 3, 1, "y")
  for i, p in ipairs({{12, 7}, {14, 9}, {10, 11}, {16, 13}, {9, 15}, {13, 16}, {19, 14}, {7, 17}, {18, 17}}) do F(g, p[1], p[2], 1, 1, (i % 2 == 0) and "y" or "r") end
  F(g, 24, 16, 6, 5, "r"); F(g, 26, 16, 2, 5, "w"); F(g, 24, 18, 6, 1, "w"); F(g, 25, 15, 4, 1, "w")
end)

card("tax", function(g)                -- a tax form with a stamp, a calculator
  F(g, 0, 0, 32, 24, "c")
  F(g, 3, 3, 13, 18, "w"); F(g, 3, 3, 13, 1, "W"); F(g, 5, 4, 5, 1, "b")
  for _, y in ipairs({6, 9, 12, 15}) do F(g, 5, y, 9, 1, "g") end
  F(g, 9, 17, 5, 3, "r")
  F(g, 19, 5, 10, 16, "G"); F(g, 20, 6, 8, 3, "P")
  for _, y in ipairs({11, 14, 17}) do for _, x in ipairs({20, 23, 26}) do F(g, x, y, 2, 2, "W") end end
  F(g, 26, 17, 2, 2, "r")
end)

card("xp", function(g)                 -- an old monitor with a warning, and a calendar page with a red cross
  F(g, 0, 0, 32, 24, "n")
  F(g, 2, 4, 16, 14, "C"); F(g, 4, 6, 12, 10, "b")
  S_(g, 8, 8, {"..y..", ".yky.", ".yky.", "yyyyy", "yykyy"})
  F(g, 7, 19, 6, 1, "C"); F(g, 5, 20, 10, 2, "C")
  F(g, 20, 4, 10, 16, "w"); F(g, 20, 4, 10, 4, "r"); F(g, 22, 3, 1, 2, "k"); F(g, 27, 3, 1, 2, "k")
  local eight = PR.text("8", "k")
  for r = 1, 5 do for c = 1, 3 do if eight[r]:sub(c, c) == "k" then F(g, 23 + c, 10 + r, 1, 1, "k") end end end
  F(g, 21, 17, 8, 1, "r")
end)

card("school", function(g)             -- a school bus on a green verge under a sun
  F(g, 0, 0, 32, 24, "S"); F(g, 0, 18, 32, 6, "t")
  DISC(g, 27, 5, 3, "y")
  F(g, 3, 8, 26, 9, "y"); F(g, 3, 8, 26, 1, "o"); F(g, 3, 15, 26, 1, "k")
  for _, x in ipairs({5, 10, 15, 20}) do F(g, x, 10, 4, 3, "s") end
  F(g, 25, 10, 3, 4, "s")
  DISC(g, 9, 17.5, 2.6, "k"); DISC(g, 23, 17.5, 2.6, "k"); F(g, 9, 17, 1, 1, "W"); F(g, 23, 17, 1, 1, "W")
end)

card("printer", function(g)            -- a printer with a jam
  F(g, 0, 0, 32, 24, "e")
  F(g, 8, 2, 12, 5, "w"); F(g, 10, 3, 8, 1, "g"); F(g, 10, 5, 8, 1, "g")
  F(g, 3, 9, 22, 10, "W"); F(g, 3, 18, 22, 1, "g"); F(g, 5, 6, 18, 3, "g")
  F(g, 5, 12, 4, 2, "G"); F(g, 21, 12, 2, 1, "t")
  F(g, 7, 16, 14, 7, "w"); F(g, 9, 18, 10, 1, "g"); F(g, 9, 20, 7, 1, "g"); F(g, 7, 22, 14, 1, "r")
  F(g, 26, 8, 3, 3, "r"); F(g, 27, 11, 1, 2, "r"); F(g, 27, 14, 1, 1, "r")
end)

card("phone", function(g)              -- a handset off the cradle, ringing
  F(g, 0, 0, 32, 24, "m")
  F(g, 3, 15, 26, 7, "G"); F(g, 3, 15, 26, 1, "g")
  for _, x in ipairs({11, 15, 19}) do F(g, x, 17, 2, 1, "W"); F(g, x, 19, 2, 1, "W") end
  F(g, 6, 10, 20, 3, "k"); F(g, 4, 9, 4, 6, "k"); F(g, 24, 9, 4, 6, "k"); F(g, 9, 10, 14, 1, "G")
  F(g, 8, 4, 2, 1, "y"); F(g, 13, 3, 3, 1, "y"); F(g, 19, 3, 3, 1, "y"); F(g, 23, 4, 2, 1, "y")
  F(g, 10, 5, 1, 1, "y"); F(g, 21, 5, 1, 1, "y")
end)

card("food", function(g)               -- a pizza on its box
  F(g, 0, 0, 32, 24, "f")
  F(g, 3, 17, 26, 5, "U"); F(g, 3, 17, 26, 1, "u")
  DISC(g, 16, 11, 9, "U"); DISC(g, 16, 11, 7.4, "y")
  for _, p in ipairs({{13, 8}, {18, 9}, {15, 13}, {19, 14}, {11, 12}, {21, 11}}) do F(g, p[1], p[2], 2, 2, "r") end
  F(g, 12, 6, 1, 1, "t")
end)

card("power", function(g)              -- a plug, an outlet, a spark between them
  F(g, 0, 0, 32, 24, "N")
  F(g, 0, 12, 2, 2, "G"); F(g, 2, 9, 8, 8, "W"); F(g, 2, 16, 8, 1, "g")
  F(g, 10, 10, 4, 2, "g"); F(g, 10, 14, 4, 2, "g")
  F(g, 22, 5, 9, 14, "e"); F(g, 24, 9, 1, 3, "k"); F(g, 27, 9, 1, 3, "k"); F(g, 25, 14, 3, 2, "k")
  S_(g, 15, 4, {"..yyy", ".yyy.", "yyyyy", "..yy.", ".yy..", "yy..."})
end)

card("security", function(g)           -- an envelope on a hook
  F(g, 0, 0, 32, 24, "x")
  F(g, 4, 8, 16, 11, "w")
  for i = 0, 7 do F(g, 4 + i, 8 + i, 1, 1, "W"); F(g, 19 - i, 8 + i, 1, 1, "W") end
  DISC(g, 12, 15, 2.2, "r")
  F(g, 25, 2, 1, 12, "g"); F(g, 24, 14, 1, 1, "g"); F(g, 23, 14, 1, 1, "g"); F(g, 22, 13, 1, 1, "g"); F(g, 22, 12, 1, 1, "g"); F(g, 23, 12, 1, 1, "g")
  F(g, 24, 2, 3, 1, "g")
end)

card("backup", function(g)             -- an external drive, a cable and a USB stick
  F(g, 0, 0, 32, 24, "d")
  F(g, 3, 9, 16, 11, "G"); F(g, 3, 9, 16, 2, "g"); F(g, 15, 16, 2, 1, "P"); F(g, 5, 14, 8, 3, "W")
  F(g, 19, 15, 3, 1, "k")
  F(g, 22, 13, 3, 3, "W"); F(g, 25, 12, 5, 5, "B"); F(g, 27, 13, 1, 1, "W")
end)

-- ====================================================================================================================
-- R9: mutator icons, 12 x 12 (10 x 10 content and the outline), one per mutator of Mutators.MUTATORS. Sources
-- office/pieces/ui_mut_<id>.aseprite, PNGs godot/assets/ui/mut_<id>.png (the mutator chooser and the Free Play toolbox draw them).
-- ====================================================================================================================
local function mut(id, body)
  local g = G(10, 10)
  body(g)
  PR.build{name = "ui_mut_" .. id, ase = ASE, layers = {{name = "Icon", pal = CARDPAL, rows = ROWS(g)}}}
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "ui_mut_" .. id .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. "godot/assets/ui/mut_" .. id .. ".png")
  s:close()
end

mut("heartbleed", function(g)        -- a bleeding heart
  S_(g, 0, 0, {".rrr..rrr.", "rrrrrrrrrr", "rrrrrrrrrr", ".rrrrrrrr.", "..rrrrrr..", "...rrrr...", "....rr...."})
  F(g, 2, 1, 1, 1, "w")
  F(g, 4, 8, 2, 2, "R")
end)
mut("xp_eol", function(g)            -- a calendar page with a cross
  F(g, 1, 0, 8, 10, "w"); F(g, 1, 0, 8, 2, "r")
  for _, p in ipairs({{3, 4}, {6, 4}, {4, 5}, {5, 5}, {4, 6}, {5, 6}, {3, 7}, {6, 7}}) do F(g, p[1], p[2], 1, 1, "k") end
end)
mut("flu_season", function(g)        -- a thermometer
  F(g, 4, 0, 2, 7, "w"); F(g, 4, 3, 2, 4, "r"); DISC(g, 5, 7.5, 2.5, "r"); F(g, 7, 1, 2, 1, "g"); F(g, 7, 3, 2, 1, "g")
end)
mut("printer_apocalypse", function(g)  -- a jammed printer
  F(g, 2, 0, 6, 3, "w"); F(g, 0, 3, 10, 4, "W"); F(g, 0, 6, 10, 1, "g"); F(g, 2, 7, 6, 3, "w"); F(g, 2, 9, 6, 1, "r"); F(g, 8, 4, 1, 1, "r")
end)
mut("tax_season", function(g)        -- a coin with a percent sign
  DISC(g, 5, 5, 4.8, "y")
  S_(g, 3, 3, {"kk..k", "kk.k.", "..k..", ".k.kk", "k..kk"})
end)
mut("slow_payers", function(g)       -- an hourglass
  S_(g, 1, 0, {"WWWWWWWW", ".yyyyyy.", "..yyyy..", "...yy...", "...yy...", "..s..s..", ".s.yy.s.", ".syyyys.", "WWWWWWWW"})
end)
mut("hardware_recall", function(g)   -- a box with a red recall badge
  F(g, 0, 3, 9, 7, "U"); F(g, 0, 3, 9, 1, "u"); F(g, 3, 3, 2, 7, "y"); F(g, 7, 0, 3, 3, "r"); F(g, 8, 1, 1, 1, "w")
end)
mut("hurricane_drill", function(g)   -- a storm swirl
  DISC(g, 5, 5, 4.8, "g"); DISC(g, 5, 5, 3.2, "G"); DISC(g, 5, 5, 1.4, "w")
  F(g, 5, 0, 3, 1, "w"); F(g, 0, 5, 1, 3, "w"); F(g, 2, 9, 3, 1, "w"); F(g, 9, 2, 1, 3, "w")
end)
mut("new_psa", function(g)           -- a monitor with a new-window star
  F(g, 0, 1, 10, 7, "W"); F(g, 1, 2, 8, 5, "b"); F(g, 4, 8, 2, 1, "W"); F(g, 2, 9, 6, 1, "W")
  F(g, 6, 3, 2, 2, "y"); F(g, 3, 5, 2, 1, "w")
end)
mut("heat_wave", function(g)         -- a sun with rays
  DISC(g, 5, 5, 3.2, "y")
  for _, p in ipairs({{4, 0}, {5, 0}, {4, 9}, {5, 9}, {0, 4}, {0, 5}, {9, 4}, {9, 5}, {1, 1}, {8, 1}, {1, 8}, {8, 8}}) do F(g, p[1], p[2], 1, 1, "o") end
end)
mut("cold_snap", function(g)         -- a snowflake
  F(g, 4, 0, 2, 10, "s"); F(g, 0, 4, 10, 2, "s")
  for _, p in ipairs({{1, 1}, {2, 2}, {7, 2}, {8, 1}, {1, 8}, {2, 7}, {7, 7}, {8, 8}}) do F(g, p[1], p[2], 1, 1, "w") end
end)
mut("good_quarter", function(g)      -- bars going up
  F(g, 1, 6, 2, 3, "t"); F(g, 4, 4, 2, 5, "t"); F(g, 7, 1, 2, 8, "t"); F(g, 0, 9, 10, 1, "G")
end)
mut("price_war", function(g)         -- a price tag with an arrow down
  F(g, 1, 1, 8, 8, "r"); F(g, 2, 2, 1, 1, "w"); F(g, 5, 3, 1, 3, "w"); F(g, 4, 6, 3, 1, "w"); F(g, 5, 7, 1, 1, "w")
end)
mut("summer_lull", function(g)       -- a beach umbrella
  for y = 0, 4 do for x = 0, 9 do if (x + 0.5 - 5) ^ 2 + (y + 0.5 - 5) ^ 2 <= 25 then g[y + 1][x + 1] = ((x // 2) % 2 == 0) and "r" or "w" end end end
  F(g, 5, 5, 1, 4, "u"); F(g, 0, 9, 10, 1, "y")
end)

-- ====================================================================================================================
-- R4 (rest): the escape room's grandfather clock (20 x 54 png) and the desk (76 x 27 png) in each theme, at the study's size
-- and on the same floor line, plus the things that stand on the desk (escape_<theme>_deskitem, a separate sprite SetDressing
-- hangs on the desk so the png keeps the study's size; the study's lamp stays where it is):
--   server    a rack-mounted NTP time display; a steel console desk with a KVM monitor and keyboard
--   detective a pendulum clock over a filing drawer; a heavy wood pedestal desk with a typewriter and a paper stack
--   lab       a school clock on a pole over a time-card box; a long beige lab desk with a CRT on a PC case, keyboard, mouse
-- ====================================================================================================================
local ES2 = {B = "#3E4350", L = "#5A6070", D = "#2A2E38", M = "#4A5060", s = "#8E939E", g = "#5FBF6A", r = "#D8483A",
  y = "#C99A3C", Y = "#E8C45A", k = "#17121F", w = "#F4F2EA", c = "#8A8F9A", o = "#6B4A2E", p = "#8A6240", n = "#4A3220",
  a = "#14241C", G = "#6F7A6A", H = "#8E9A88", J = "#4F5A4B", e = "#D8CFB4", E = "#EAE3CC", q = "#B0A688", Q = "#8E8668",
  b = "#3A3F4A", u = "#3A62A8", m = "#C9955A", t = "#2A2A33", v = "#7FB0D8", V = "#4F7FD0"}
local GLY = {["0"] = {"###", "#.#", "#.#", "#.#", "###"}, ["1"] = {".#.", "##.", ".#.", ".#.", "###"},
  ["4"] = {"#.#", "#.#", "###", "..#", "..#"}, ["5"] = {"###", "#..", "###", "..#", "###"},
  N = {"###", "#.#", "#.#", "#.#", "#.#"}, T = {"###", ".#.", ".#.", ".#.", ".#."}, P = {"###", "#.#", "###", "#..", "#.."}}
local function GL(g, x, y, ch, c)
  for r = 1, 5 do for k = 1, 3 do if GLY[ch][r]:sub(k, k) == "#" then F(g, x + k - 1, y + r - 1, 1, 1, c) end end end
end
local function HLINE(g, x0, y0, x1, y1, c)   -- a 1 px line (Bresenham)
  local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
  local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    F(g, x0, y0, 1, 1, c)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
  end
end

-- ---- clocks (content 18 x 52) ----
-- server: a rack on short feet; a display unit (hours over minutes, green digits), an NTP label unit, a patch panel, a UPS
esc("server", "clock", 18, 52, ES2, function(b, d)
  BOX(b, 0, 0, 18, 50, "B", "L", "D")
  F(b, 2, 2, 14, 46, "D")
  BOX(b, 2, 3, 14, 18, "M", "L", "D")
  F(d, 4, 5, 10, 14, "a")
  GL(d, 5, 6, "1", "g"); GL(d, 9, 6, "0", "g")
  F(d, 8, 12, 2, 1, "g")
  GL(d, 5, 13, "4", "g"); GL(d, 9, 13, "5", "g")
  BOX(b, 2, 22, 14, 8, "M", "L", "D")
  GL(d, 4, 24, "N", "w"); GL(d, 8, 24, "T", "w"); GL(d, 12, 24, "P", "w")
  BOX(b, 2, 31, 14, 7, "M", "L", "D")
  for i = 0, 5 do F(d, 4 + i * 2, 33, 1, 2, "k") end
  BOX(b, 2, 39, 14, 9, "M", "L", "D")
  F(d, 4, 41, 6, 5, "D"); F(d, 12, 41, 2, 2, "g"); F(d, 12, 44, 2, 2, "r")
  F(b, 0, 50, 4, 2, "k"); F(b, 14, 50, 4, 2, "k")
end)
-- detective: a brass-rimmed round clock in a wood case, a glass window with a brass pendulum, a gray filing drawer for a base
esc("detective", "clock", 18, 52, ES2, function(b, d)
  BOX(b, 0, 0, 18, 20, "o", "p", "n")
  DISC(d, 9, 10, 7.4, "Y"); DISC(d, 9, 10, 6, "w")
  F(d, 8, 4, 2, 1, "k"); F(d, 8, 15, 2, 1, "k"); F(d, 3, 9, 1, 2, "k"); F(d, 14, 9, 1, 2, "k")
  F(d, 8, 5, 1, 5, "k"); F(d, 8, 9, 4, 1, "k")
  BOX(b, 1, 20, 16, 16, "n", "o", "a")
  F(d, 3, 22, 12, 12, "a")
  F(d, 8, 22, 1, 8, "Y"); DISC(d, 8.5, 31, 2.4, "Y"); F(d, 7, 30, 1, 1, "w")
  BOX(b, 0, 36, 18, 14, "G", "H", "J")
  F(d, 1, 42, 16, 1, "J")
  F(d, 6, 38, 6, 2, "w"); F(d, 6, 45, 6, 2, "w")
  F(d, 7, 40, 4, 1, "Y"); F(d, 7, 47, 4, 1, "Y")
  F(b, 0, 50, 4, 2, "k"); F(b, 14, 50, 4, 2, "k")
end)
-- lab: a school clock (grey bezel, white face, red second hand) on a pole with a time-card box and a wheeled base
esc("lab", "clock", 18, 52, ES2, function(b, d)
  DISC(b, 9, 9, 9, "b"); DISC(d, 9, 9, 7.2, "w")
  F(d, 8, 3, 2, 1, "k"); F(d, 8, 15, 2, 1, "k"); F(d, 2, 8, 1, 2, "k"); F(d, 15, 8, 1, 2, "k")
  F(d, 8, 5, 1, 4, "k"); F(d, 8, 9, 4, 1, "k"); HLINE(d, 9, 9, 6, 13, "r")
  F(b, 8, 18, 2, 30, "c"); F(d, 8, 18, 1, 30, "s")
  BOX(b, 4, 26, 10, 12, "e", "E", "q")
  F(d, 6, 29, 6, 1, "k"); F(d, 6, 32, 6, 4, "w"); F(d, 7, 33, 4, 1, "u")
  F(b, 3, 47, 12, 2, "B"); F(b, 1, 49, 4, 2, "k"); F(b, 13, 49, 4, 2, "k"); F(b, 7, 49, 4, 2, "k")
end)

-- ---- desks (content 74 x 25): a top slab (rows 0-3) over a front, legs to row 24 ----
local function DESKBODY(b, d, top, lit, shade, front, panel, leg)
  F(b, 0, 0, 74, 4, top); F(b, 0, 0, 74, 1, lit); F(b, 0, 3, 74, 1, shade)
  F(b, 1, 4, 72, 19, front)
  F(b, 3, 6, 68, 16, panel)
  F(b, 1, 4, 3, 21, leg); F(b, 70, 4, 3, 21, leg)
  F(d, 1, 4, 72, 1, shade)
end
-- server: a steel console desk with rack drawers, a status panel in the middle, caster feet and a few lights
esc("server", "desk", 74, 25, ES2, function(b, d)
  DESKBODY(b, d, "B", "L", "D", "M", "D", "B")
  F(b, 3, 22, 68, 1, "L")
  F(b, 1, 23, 3, 2, "k"); F(b, 70, 23, 3, 2, "k")
  for i = 0, 2 do F(d, 6, 8 + i * 5, 17, 3, "M"); F(d, 6, 8 + i * 5, 17, 1, "L"); F(d, 8, 10 + i * 5, 8, 1, "D"); F(d, 20, 9 + i * 5, 2, 1, "c") end
  F(d, 27, 8, 20, 12, "a"); F(d, 28, 9, 18, 1, "J")
  for i = 0, 3 do F(d, 29 + i * 4, 12, 2, 1, "g"); F(d, 29 + i * 4, 15, 2, 1, (i == 1) and "r" or "g") end
  for i = 0, 2 do F(d, 51, 8 + i * 5, 17, 3, "M"); F(d, 51, 8 + i * 5, 17, 1, "L"); F(d, 53, 10 + i * 5, 8, 1, "D"); F(d, 65, 9 + i * 5, 2, 1, (i == 2) and "r" or "g") end
end)
-- detective: a heavy wood pedestal desk: three drawers with brass pulls on each side, a dark kneehole, a brass edge
esc("detective", "desk", 74, 25, ES2, function(b, d)
  DESKBODY(b, d, "o", "p", "n", "o", "n", "o")
  F(b, 1, 23, 3, 2, "n"); F(b, 70, 23, 3, 2, "n")
  F(d, 1, 1, 72, 1, "m")
  F(d, 25, 6, 24, 16, "a"); F(d, 25, 6, 24, 1, "n")
  for i = 0, 2 do
    F(d, 5, 7 + i * 5, 17, 4, "p"); F(d, 5, 7 + i * 5, 17, 1, "m"); F(d, 12, 9 + i * 5, 3, 1, "Y")
    F(d, 52, 7 + i * 5, 17, 4, "p"); F(d, 52, 7 + i * 5, 17, 1, "m"); F(d, 59, 9 + i * 5, 3, 1, "Y")
  end
end)
-- lab: a long beige laminate desk: a drawer unit on the left, a computer shelf with a floppy slot on the right, a grey kick rail
esc("lab", "desk", 74, 25, ES2, function(b, d)
  DESKBODY(b, d, "e", "E", "q", "e", "q", "c")
  F(b, 1, 23, 3, 2, "B"); F(b, 70, 23, 3, 2, "B")
  F(d, 3, 22, 68, 1, "Q")
  for i = 0, 2 do F(d, 5, 7 + i * 5, 17, 4, "e"); F(d, 5, 7 + i * 5, 17, 1, "E"); F(d, 12, 9 + i * 5, 3, 1, "Q") end
  F(d, 26, 7, 25, 14, "Q"); F(d, 27, 8, 23, 12, "q")
  F(d, 56, 8, 14, 11, "e"); F(d, 56, 8, 14, 1, "E"); F(d, 58, 11, 8, 1, "k"); F(d, 66, 15, 2, 1, "g")
end)

-- ---- what stands on the desk (separate sprites, bottom on the desk top) ----
-- server: a small KVM monitor with a keyboard tray and a coiled cable
esc("server", "deskitem", 40, 15, ES2, function(b, d)
  BOX(b, 17, 0, 18, 11, "B", "L", "D")
  F(d, 19, 2, 14, 7, "a"); F(d, 20, 3, 6, 1, "g"); F(d, 20, 5, 9, 1, "g"); F(d, 20, 7, 4, 1, "g")
  F(b, 24, 11, 4, 1, "D"); F(b, 20, 12, 12, 1, "D")
  BOX(b, 12, 13, 22, 2, "c", "w", "s")
  F(b, 1, 12, 3, 1, "k"); F(b, 3, 13, 5, 1, "k"); F(b, 7, 14, 5, 1, "k"); F(b, 36, 12, 3, 1, "g")
end)
-- detective: a typewriter (platen, paper in it, round keys), a paper stack with a pen
esc("detective", "deskitem", 40, 13, ES2, function(b, d)
  BOX(b, 2, 5, 18, 8, "t", "B", "k")
  F(b, 1, 3, 20, 2, "t"); F(b, 5, 0, 12, 4, "w"); F(d, 7, 1, 8, 1, "c"); F(d, 7, 2, 6, 1, "c")
  for i = 0, 5 do F(d, 4 + i * 3, 8, 2, 1, "w"); F(d, 5 + i * 3, 10, 2, 1, "w") end
  F(b, 24, 8, 12, 5, "w"); F(d, 24, 8, 12, 1, "E"); F(d, 24, 10, 12, 1, "c"); F(d, 24, 12, 12, 1, "c")
  F(d, 26, 6, 8, 1, "r"); F(d, 33, 7, 5, 1, "n")
end)
-- lab: a CRT on a beige desktop case, a keyboard and a mouse
esc("lab", "deskitem", 40, 18, ES2, function(b, d)
  BOX(b, 2, 0, 16, 11, "e", "E", "q")
  F(d, 4, 2, 12, 7, "a"); F(d, 5, 3, 4, 1, "g"); F(d, 5, 5, 7, 1, "g")
  BOX(b, 0, 11, 20, 5, "e", "E", "q")
  F(d, 3, 13, 9, 1, "Q"); F(d, 15, 13, 1, 1, "g")
  BOX(b, 22, 14, 14, 3, "e", "E", "q"); F(d, 24, 15, 10, 1, "Q")
  F(b, 37, 15, 3, 2, "e")
end)

-- ====================================================================================================================
-- R23: a narrow side-on lectern (12 x 26 content, png 14 x 28) for the breakout rooms SALON B, C and D, drawn facing the audience
-- (left): a gooseneck mic, a reading slope that falls toward the room, a body with a name plate, a plinth. It stands BESIDE the
-- speaker (the room's props JSON puts it on sort line 119 a few px right of him), never in front of him.
--   b  light wood (the sunroom)   c  burgundy (the velvet lounge)   d  grey steel (the lab)
-- Sources office/pieces/venue_podium_<room>.aseprite, PNGs godot/assets/props/.
-- ====================================================================================================================
for _, v in ipairs({{"b", "#B08050", "#D0A070", "#7A5030"}, {"c", "#5A2A38", "#7A3E4E", "#3A1A24"}, {"d", "#6A6F7A", "#8E939E", "#4A4F5A"}}) do
  local pal = {o = v[2], p = v[3], n = v[4], k = "#2A2A33", s = "#8E939E", Y = "#F2C94C"}
  local b, d = G(12, 26), G(12, 26)
  F(d, 6, 0, 4, 1, "k"); F(d, 6, 1, 1, 3, "k"); F(d, 9, 1, 1, 5, "k")           -- the gooseneck: a hook over the slope, the head hangs at x 6
  F(d, 5, 3, 3, 2, "s"); F(d, 6, 3, 1, 1, "k")
  for yy = 5, 8 do                                                                   -- the reading slope, lower toward the audience
    local x0 = 7 - 2 * (yy - 5)
    F(b, x0, yy, 12 - x0, 1, (yy == 5) and "p" or "o")
    F(b, 11, yy, 1, 1, "n")
  end
  F(b, 1, 8, 11, 1, "n"); F(b, 1, 8, 2, 1, "o")
  F(b, 3, 9, 9, 13, "o"); F(b, 3, 9, 1, 13, "p"); F(b, 11, 9, 1, 13, "n")        -- the body: lit on the left, shaded on the right
  F(d, 5, 12, 5, 4, "n"); F(d, 6, 13, 3, 2, "Y")                                   -- the name plate
  F(b, 1, 22, 11, 1, "n"); F(b, 0, 23, 12, 3, "n"); F(b, 0, 23, 12, 1, "o")       -- the plinth
  PR.build{name = "venue_podium_" .. v[1], ase = ASE, layers = {
    {name = "Body", pal = pal, rows = ROWS(b)},
    {name = "Detail", pal = pal, rows = ROWS(d), outline = false}}}
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "venue_podium_" .. v[1] .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. "godot/assets/props/venue_podium_" .. v[1] .. ".png")
  s:close()
end

-- ====================================================================================================================
-- Venue odds and ends: the restaurant's hanging OPEN / CLOSED sign (SetDressing shows one of the two while a dinner is on or not) and
-- a chalk menu board between its booths, and the warehouse's wall shelf of chair-game trophies (one trophy sprite per medal earned:
-- CLEAN LAP, SPEED DEMON, TRACK RAT, BUMPER KING). Sources office/pieces/venue_*.aseprite, PNGs godot/assets/props/.
-- ====================================================================================================================
local function VEN(name, w, h, pal, body)
  local b, d = G(w, h), G(w, h)
  body(b, d)
  PR.build{name = "venue_" .. name, ase = ASE, layers = {
    {name = "Body", pal = pal, rows = ROWS(b)},
    {name = "Detail", pal = pal, rows = ROWS(d), outline = false}}}
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "venue_" .. name .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. "godot/assets/props/venue_" .. name .. ".png")
  s:close()
end
GLY.O = {"###", "#.#", "#.#", "#.#", "###"}
GLY.E = {"###", "#..", "##.", "#..", "###"}
GLY.C = {"###", "#..", "#..", "#..", "###"}
GLY.L = {"#..", "#..", "#..", "#..", "###"}
GLY.S = {"###", "#..", "###", "..#", "###"}
GLY.D = {"##.", "#.#", "#.#", "#.#", "##."}
GLY.M = {"#.#", "###", "###", "#.#", "#.#"}
GLY.U = {"#.#", "#.#", "#.#", "#.#", "###"}
local function WORD(g, x, y, str, c)
  for i = 1, #str do GL(g, x + (i - 1) * 4, y, str:sub(i, i), c) end
end
local VP = {k = "#17121F", w = "#F4F2EA", c = "#8A8F9A", s = "#8E939E", d = "#6B4A2E", p = "#8A6240", o = "#6B4A2E", n = "#4A3220",
  m = "#C9955A", r = "#D8483A", R = "#B8483A", G = "#2E8A4A", g = "#5FBF6A", Y = "#E8C45A", y = "#C99A3C", a = "#1F3A2E",
  h = "#C8CCD8", e = "#E8E0C8", q = "#8A2E26"}
-- the sign: a chain over a board, 25 x 11 (the board 25 x 9, the text 3 x 5 letters); OPEN on green, CLOSED on red
VEN("sign_open", 25, 11, VP, function(b, d)
  F(b, 5, 0, 1, 2, "c"); F(b, 19, 0, 1, 2, "c")
  BOX(b, 0, 2, 25, 9, "G", "g", "a")
  WORD(d, 5, 4, "OPEN", "w")
end)
VEN("sign_closed", 25, 11, VP, function(b, d)
  F(b, 5, 0, 1, 2, "c"); F(b, 19, 0, 1, 2, "c")
  BOX(b, 0, 2, 25, 9, "R", "r", "q")
  WORD(d, 1, 4, "CLOSED", "w")
end)
-- the menu board: a wood frame round a chalk board, MENU over four lines of dishes with a price dot each (20 x 26)
VEN("menu_board", 20, 26, VP, function(b, d)
  BOX(b, 0, 0, 20, 26, "p", "m", "n")
  F(b, 2, 2, 16, 22, "a")
  WORD(d, 3, 4, "MENU", "e")
  F(d, 3, 10, 14, 1, "e")
  for i = 0, 3 do
    F(d, 3, 13 + i * 3, 9 - (i % 2) * 2, 1, "w")
    F(d, 14, 13 + i * 3, 3, 1, "Y")
  end
end)
-- the trophy shelf: a plank on two brackets (30 x 9 png); the trophies stand on it as their own sprites (7 x 11 png each)
VEN("trophy_shelf", 28, 7, VP, function(b, d)
  BOX(b, 0, 0, 28, 4, "p", "m", "n")
  F(b, 3, 4, 2, 3, "d"); F(b, 23, 4, 2, 3, "d")
end)
local function trophy(name, rows, pal)
  PR.build{name = "venue_trophy_" .. name, ase = ASE, layers = {{name = "Body", pal = pal, rows = rows}}}
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "venue_trophy_" .. name .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. "godot/assets/props/venue_trophy_" .. name .. ".png")
  s:close()
end
trophy("clean", {"YYYYY", "YwYYy", "YYYYy", ".YYy.", "..Y..", "..y..", ".yyy.", ".ddd.", ".ddd."}, VP)           -- CLEAN LAP: a gold cup
trophy("speed", {"rrrrr", "rrwrr", "rwwrr", ".rwr.", "..r..", "..s..", ".sss.", ".ddd.", ".ddd."}, VP)           -- SPEED DEMON: a red cup with a bolt
trophy("track", {"hhhhh", "hhhhs", "hhhhs", ".hhs.", "..h..", "..g..", ".ggg.", ".ddd.", ".ddd."}, VP)           -- TRACK RAT: a silver cup on a green stem
trophy("bumper", {"Y.Y.Y", "YYYYY", "YrYgY", "YYYYy", ".yyy.", "..y..", ".yyy.", ".ddd.", ".ddd."}, VP)         -- BUMPER KING: a crown
