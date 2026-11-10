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
