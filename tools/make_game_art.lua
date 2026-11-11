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
