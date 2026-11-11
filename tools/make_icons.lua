-- UI glyphs: the pad button atlas (R14, godot/scripts/pad_glyphs.gd) and the touch overlay's stick and buttons
-- (godot/scripts/touch_overlay.gd). Sources office/pieces/ui_*.aseprite, PNGs godot/assets/ui/.
-- Run in a checkout:  ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_icons.lua")   (Aseprite.exe -b --script x.lua)
local PR = dofile((ROOT or "D:/creative/pixelproject/") .. "tools/piece_rows.lua")
local ASE, PNG = "office/pieces/", "godot/assets/ui/"

-- ---- pad glyphs: 12 cells of 11 x 7 (the 3x5 pixel font plus a row above and below), left-aligned in the cell ----
-- order and widths must match pad_glyphs.gd (NAMES, WIDTHS)
do
  local CELL, H = 11, 7
  local disc = {".ccccc.", "ccccccc", "ccccccc", "ccccccc", "ccccccc", "ccccccc", ".ccccc."}
  local bumper = {".ccccccccc.", "ccccccccccc", "ccccccccccc", "ccccccccccc", "ccccccccccc", "ccccccccccc", "ccccccccccc"}
  local trigger = {"...cccccccc", ".cccccccccc", "ccccccccccc", "ccccccccccc", "ccccccccccc", "ccccccccccc", ".ccccccccc."}
  local ring = {".kkkkk.", "kcccccK", "kcdddck", "kcdddck", "kcdddck", "kcccccK", ".kkkkk."}
  local plus = {"..kkk..", "..kck..", "kkkckkk", "kcccccK", "kkkckkk", "..kck..", "..kkk.."}
  local play = {"#..", "##.", "###", "##.", "#.."}
  local back = {"..#", ".##", "###", ".##", "..#"}
  local glyphs = {
    {disc, "#3CA84A", PR.text("A", "#"), "#FFFFFF"}, {disc, "#D8423C", PR.text("B", "#"), "#FFFFFF"},
    {disc, "#3C7BD8", PR.text("X", "#"), "#FFFFFF"}, {disc, "#E8B820", PR.text("Y", "#"), "#17121F"},
    {bumper, "#C8CCD8", PR.text("LB", "#"), "#17121F"}, {bumper, "#C8CCD8", PR.text("RB", "#"), "#17121F"},
    {trigger, "#5A606C", PR.text("LT", "#"), "#FFFFFF"}, {trigger, "#5A606C", PR.text("RT", "#"), "#FFFFFF"},
    {disc, "#4A4A55", play, "#FFFFFF"}, {disc, "#4A4A55", back, "#FFFFFF"},
    {ring, "#C8CCD8", nil, nil}, {plus, "#C8CCD8", nil, nil},
  }
  -- R42: the Deck's View and Menu, the right stick with a direction, L3 / R3, and the D-pad's single directions (cells 13 to 24).
  -- A mark is 5 rows placed at row 2; `full` marks are a whole 7 row cell. Order and widths: pad_glyphs.gd NAMES / WIDTHS.
  PR.FONT["3"] = {"###", "..#", "###", "..#", "###"}
  local rs = {".kkkkk.", "kcccccK", "kcccccK", "kcccccK", "kcccccK", "kcccccK", ".kkkkk."}
  local pill = {".ccccccccc.", "ccccccccccc", "ccccccccccc", "ccccccccccc", "ccccccccccc", "ccccccccccc", ".ccccccccc."}
  local function dpad(mark_rows) local o = {} for y = 1, 7 do o[y] = mark_rows[y] or "......." end return o end
  local ltxt, rtxt = PR.text("L3", "#"), PR.text("R3", "#")
  local extra = {
    {disc, "#4A4A55", {"###..", "#.#..", "#####", "..#.#", "..###"}, "#FFFFFF", 1},       -- VIEW: two overlapping windows
    {disc, "#4A4A55", {"#####", ".....", "#####", ".....", "#####"}, "#FFFFFF", 1},       -- MENU: three lines
    {rs, "#C8CCD8", {"..#..", ".###.", "#.#.#", "..#..", "..#.."}, "#17121F", 1},          -- RS UP
    {rs, "#C8CCD8", {"..#..", "..#..", "#.#.#", ".###.", "..#.."}, "#17121F", 1},          -- RS DOWN
    {rs, "#C8CCD8", {"..#..", ".#...", "#####", ".#...", "..#.."}, "#17121F", 1},          -- RS LEFT
    {rs, "#C8CCD8", {"..#..", "...#.", "#####", "...#.", "..#.."}, "#17121F", 1},          -- RS RIGHT
    {pill, "#C8CCD8", ltxt, "#17121F", 2},                                                  -- L3 (the stick pressed in)
    {pill, "#C8CCD8", rtxt, "#17121F", 2},                                                  -- R3
    {plus, "#C8CCD8", dpad({[2] = "...a...", [3] = "...a..."}), "#D8423C", 0, true},                      -- D-pad UP: the up arm is red
    {plus, "#C8CCD8", dpad({[5] = "...a...", [6] = "...a..."}), "#D8423C", 0, true},     -- DOWN
    {plus, "#C8CCD8", dpad({[4] = ".aa...."}), "#D8423C", 0, true},                       -- LEFT
    {plus, "#C8CCD8", dpad({[4] = "....aa."}), "#D8423C", 0, true},                       -- RIGHT
  }
  for _, e in ipairs(extra) do glyphs[#glyphs + 1] = e end
  local faces, marks, pal_f, pal_m = {}, {}, {k = "#17121F", K = "#17121F", d = "#5A606C"}, {}
  for y = 1, H do faces[y] = ""; marks[y] = "" end
  for i, g in ipairs(glyphs) do
    local fc, mc = string.char(48 + i), string.char(64 + i)   -- 1.. for the faces, A.. for the marks
    pal_f[fc] = g[2]
    if g[4] then pal_m[mc] = g[4] end
    for y = 1, H do
      local row = g[1][y]:gsub("c", fc)
      faces[y] = faces[y] .. row .. string.rep(".", CELL - #row)
      local m = ""
      if g[3] and g[6] then m = g[3][y]:gsub("a", mc)
      elseif g[3] and y >= 2 and y <= 6 then m = string.rep(".", g[5] or 2) .. g[3][y - 1]:gsub("#", mc) end
      marks[y] = marks[y] .. m .. string.rep(".", CELL - #m)
    end
  end
  PR.build{name = "ui_pad_glyphs", ase = ASE, png = nil, pad = 0, layers = {
    {name = "Faces", pal = pal_f, rows = faces},
    {name = "Marks", pal = pal_m, rows = marks},
  }}
end

-- ---- the touch overlay: opaque white-and-ink pieces, the script draws them half transparent and tints a pressed one ----
local function disc_rows(d, ring)   -- a filled circle of diameter d; `ring` px of ink at the rim, 'c' inside
  local rows, r = {}, d / 2
  for y = 0, d - 1 do
    local s = ""
    for x = 0, d - 1 do
      local dist = math.sqrt((x + 0.5 - r) ^ 2 + (y + 0.5 - r) ^ 2)
      s = s .. ((dist > r) and "." or ((dist > r - ring) and "k" or "c"))
    end
    rows[#rows + 1] = s
  end
  return rows
end

local function pill_rows(w, h)
  local rows = {}
  for y = 1, h do
    local cut = (y == 1 or y == h) and 3 or ((y == 2 or y == h - 1) and 1 or 0)
    local edge = (y == 1 or y == h)
    local s = string.rep(".", cut)
    local inner = w - 2 * cut
    s = s .. (edge and string.rep("k", inner) or ("k" .. ((y == 2 or y == h - 1) and "k" or "c") .. string.rep("c", inner - 4) .. ((y == 2 or y == h - 1) and "k" or "c") .. "k"))
    rows[#rows + 1] = s .. string.rep(".", cut)
  end
  return rows
end

local TOUCH = {k = "#17121F", c = "#FFFFFF", g = "#C8CCD8"}
do  -- the stick's base: a ring with four small arrows
  local rows = disc_rows(46, 2)
  local function set(x, y, ch) rows[y + 1] = rows[y + 1]:sub(1, x) .. ch .. rows[y + 1]:sub(x + 2) end
  for i = 0, 2 do                       -- arrows: 5-wide triangles pointing out, 4 px from the rim
    for j = -i, i do
      set(23 + j, 5 + i, "g"); set(22 + j, 5 + i, "g")
      set(23 + j, 40 - i, "g"); set(22 + j, 40 - i, "g")
      set(5 + i, 23 + j, "g"); set(5 + i, 22 + j, "g")
      set(40 - i, 23 + j, "g"); set(40 - i, 22 + j, "g")
    end
  end
  PR.build{name = "ui_touch_stick", ase = ASE, png = nil, pad = 0, layers = {{name = "Base", pal = TOUCH, rows = rows}}}
end
do  -- the knob: a disc with a lighter cap
  local rows = disc_rows(19, 1)
  local cap = disc_rows(11, 0)
  for y = 1, 11 do cap[y] = cap[y]:gsub("c", "g") end
  PR.build{name = "ui_touch_knob", ase = ASE, png = nil, pad = 0, layers = {
    {name = "Knob", pal = TOUCH, rows = rows},
    {name = "Cap", x = 4, y = 4, pal = TOUCH, rows = cap},
  }}
end
PR.build{name = "ui_touch_round", ase = ASE, png = nil, pad = 0, layers = {{name = "Button", pal = TOUCH, rows = disc_rows(24, 1)}}}
PR.build{name = "ui_touch_pill", ase = ASE, png = nil, pad = 0, layers = {{name = "Button", pal = TOUCH, rows = pill_rows(26, 19)}}}

-- the PNG names drop the ui_ prefix (they sit in assets/ui/)
for _, n in ipairs({"pad_glyphs", "touch_stick", "touch_knob", "touch_round", "touch_pill"}) do
  local s = Sprite{fromFile = PR.ROOT .. ASE .. "ui_" .. n .. ".aseprite"}
  s:saveCopyAs(PR.ROOT .. PNG .. n .. ".png")
  s:close()
end
