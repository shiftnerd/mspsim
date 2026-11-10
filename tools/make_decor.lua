-- The office growth decor (R16, godot/scripts/office_decor.gd) and the seasonal dressing, as small layered pieces:
-- office/pieces/decor_*.aseprite and season_*.aseprite, exported to godot/assets/props/. Placements are in office_decor.gd.
-- Run in a checkout:  ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_decor.lua")   (Aseprite.exe -b --script x.lua),
-- then Godot --import.
local PR = dofile((ROOT or "D:/creative/pixelproject/") .. "tools/piece_rows.lua")
local ASE, PNG = "office/pieces/", "godot/assets/props/"
local function piece(name, layers, extra)
  local spec = {name = name, ase = ASE, png = PNG, layers = layers}
  for k, v in pairs(extra or {}) do spec[k] = v end
  PR.build(spec)
end
local WOOD = {W = "#A8643C", S = "#7A4A2B"}

-- ---- a tall plant (17 x 39): terracotta pot, a thin trunk, big two-tone leaves ----
do
  local trunk = {}
  for i = 1, 20 do trunk[i] = "t" end
  piece("decor_plant", {
    {name = "Pot", x = 4, y = 30, pal = {h = "#D88A62", p = "#B8663F", s = "#8A4A2E"}, rows = {
      "hppppps",
      "hppppps",
      ".hppps.",
      ".hppps.",
      ".hppps.",
      ".hppps.",
      "..pps..",
    }},
    {name = "Trunk", x = 7, y = 10, pal = {t = "#6B4A2E"}, rows = trunk},
    {name = "Leaves", x = 0, y = 0, pal = {G = "#5EB04A", g = "#3E8E3A"}, rows = {
      "......GGG......",
      ".....GGGGg.....",
      "..GGG.GGgg.GGG.",
      ".GGGGg.gg.GGGGg",
      ".GGGgg...GGGggg",
      "..ggg.GGG.gggg.",
      "GGG..GGGGg..GGG",
      "GGGGg.GGgg.GGGG",
      "GGGgg..gg..GGgg",
      ".ggg.GGG.GG.gg.",
      "....GGGGgGGGg..",
      ".GGG.GGggGGgg..",
      "GGGGg.gg..gg...",
      "GGGgg..........",
      ".ggg...........",
    }},
  })
end

-- ---- a rug by the door (40 x 9): maroon, a gold band, a row of diamonds ----
do
  local w = 38
  local mid = ""
  for i = 1, w - 6 do mid = mid .. ((i % 4 == 2) and "g" or "d") end
  piece("decor_rug", {
    {name = "Rug", pal = {m = "#8C2B40", g = "#C8A05A", d = "#6A1E31"}, rows = {
      string.rep("m", w),
      "m" .. string.rep("g", w - 2) .. "m",
      "mg" .. string.rep("d", w - 4) .. "gm",
      "mgd" .. mid .. "dgm",
      "mg" .. string.rep("d", w - 4) .. "gm",
      "m" .. string.rep("g", w - 2) .. "m",
      string.rep("m", w),
    }},
  })
end

-- ---- a framed certificate (15 x 12) ----
piece("decor_certificate", {
  {name = "Frame", pal = {F = "#C8A05A", S = "#9A7A3E", w = "#F4F2EA"}, rows = {
    "FFFFFFFFFFFFF",
    "FwwwwwwwwwwwS",
    "FwwwwwwwwwwwS",
    "FwwwwwwwwwwwS",
    "FwwwwwwwwwwwS",
    "FwwwwwwwwwwwS",
    "FwwwwwwwwwwwS",
    "FwwwwwwwwwwwS",
    "FwwwwwwwwwwwS",
    "FSSSSSSSSSSSS",
  }},
  {name = "Print", x = 2, y = 2, outline = false, pal = {n = "#3A3F66", g = "#9AA0A8", y = "#F5D442", r = "#E0463C"}, rows = {
    ".nnnnnnn.",
    ".........",
    "gggggg...",
    ".......yy",
    "ggggg..yy",
    ".......rr",
  }},
})

-- ---- the trophy shelf (34 x 6) and three trophies (9 x 11 each, they stand on the shelf's top outline) ----
piece("decor_shelf", {
  {name = "Brackets", x = 3, y = 2, pal = WOOD, rows = {
    "SS......................SS",
    "S........................S",
  }},
  {name = "Plank", pal = WOOD, rows = {string.rep("W", 32), string.rep("S", 32)}},
})
piece("decor_trophy_a", {  -- the gold cup
  {name = "Base", x = 1, y = 7, pal = {B = "#5A3A22", b = "#7A4A2B"}, rows = {".bBB.", "bBBBB"}},
  {name = "Cup", pal = {Y = "#F5D442", h = "#FFF0A0", s = "#C8A05A"}, rows = {
    ".YYYYs.",
    "YYhYYsY",
    "Y.YYs.Y",
    ".YhYYs.",
    "..YYs..",
    "...Y...",
    "...s...",
  }},
})
piece("decor_trophy_b", {  -- a tall silver cup
  {name = "Base", x = 1, y = 7, pal = {B = "#2A2A33", b = "#4A4A55"}, rows = {".bBB.", "bBBBB"}},
  {name = "Cup", x = 1, pal = {Y = "#C8CCD8", h = "#FFFFFF", s = "#8A8F9A"}, rows = {
    "YhYYs",
    "YhYYs",
    "YhYYs",
    ".YYs.",
    ".YYs.",
    "..Y..",
    "..s..",
  }},
})
piece("decor_trophy_c", {  -- a star on a stand
  {name = "Base", x = 1, y = 7, pal = {B = "#5A3A22", b = "#7A4A2B"}, rows = {".bBB.", "bBBBB"}},
  {name = "Star", pal = {Y = "#F5D442", h = "#FFF0A0", s = "#C8A05A"}, rows = {
    "...Y...",
    "..YhY..",
    "YYYhYYY",
    ".YYYYs.",
    ".YY.ss.",
    "...s...",
    "...s...",
  }},
})

-- ---- the fish tank on a wall shelf (20 x 15) and its fish (4 x 3, no outline: the script moves it) ----
piece("decor_fish_tank", {
  {name = "Shelf", x = 0, y = 11, pal = WOOD, rows = {"WWWWWWWWWWWWWWWWWW", "..S............S.."}},
  {name = "Tank", x = 1, y = 0, pal = {L = "#2A2A33", h = "#A8E0F5", w = "#6FC3E8", B = "#FFFFFF", g = "#3F7A34", G = "#5EB04A", s = "#D8C690", r = "#9AA0A8"}, rows = {
    "LLLLLLLLLLLLLLLL",
    "hhhhhhhhhhhhhhhh",
    "whwwwwwwwwwwBwww",
    "hwwwwwwwwwwwwwww",
    "wwwwwwwwwwwwwBww",
    "wwwwwwwwwwwwwwww",
    "wwwwwwwwwwwwwgww",
    "wgwwwwwwwwwwwGgw",
    "wGgwwwwwwwwwgGww",
    "sGsssrrsssssgsss",
    "ssssssssssssssss",
  }},
})
piece("decor_fish", {
  {name = "Fish", outline = false, pal = {t = "#D8641E", b = "#FF8A3C", e = "#17121F"}, rows = {
    "t.b.",
    "tbbe",
    "t.b.",
  }},
}, {pad = 0})

-- ---- the neon sign over the first office door (37 x 11), lit and dim ----
for _, v in ipairs({{"on", "#FF6FB5", "#5FE0E8"}, {"off", "#B84A80", "#3A7A80"}}) do
  local rows = {}
  for _ = 1, 9 do rows[#rows + 1] = string.rep("k", 35) end
  piece("decor_neon_" .. v[1], {
    {name = "Board", pal = {k = "#241A2E"}, rows = rows},
    {name = "Tube", x = 3, y = 1, outline = false, pal = {p = v[2]}, rows = PR.text("PIXEL IT", "p")},
    {name = "Underline", x = 3, y = 7, outline = false, pal = {c = v[3]}, rows = {string.rep("c", 29)}},
  })
end

-- ---- holiday lights: a 96 px tile (12 bulbs, the wire sags between the hooks), three blink phases stacked (96 x 21) ----
do
  local sag = {0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 2, 2, 2, 2, 1, 1}  -- wire row per x, 16 px period
  local cols = {"r", "y", "b", "w"}
  local wire, bulbs = {}, {}
  for phase = 0, 2 do
    local wr, br = {}, {}
    for y = 1, 7 do wr[y] = {}; br[y] = {} for x = 1, 96 do wr[y][x] = "."; br[y][x] = "." end end
    for x = 0, 95 do wr[sag[x % 16 + 1] + 1][x + 1] = "k" end
    for i = 0, 11 do
      local x = i * 8 + 3
      local top = sag[x % 16 + 1] + 2      -- 0-based row of the bulb body (one row of outline under the wire)
      local c = ((i + phase) % 3 ~= 0) and cols[i % 4 + 1] or "o"
      br[top + 1][x + 1] = (c == "o") and "o" or "h"; br[top + 1][x + 2] = c
      br[top + 2][x + 1] = c; br[top + 2][x + 2] = c
    end
    for y = 1, 7 do wire[#wire + 1] = table.concat(wr[y]); bulbs[#bulbs + 1] = table.concat(br[y]) end
  end
  piece("season_lights", {
    {name = "Wire", outline = false, pal = {k = "#17121F"}, rows = wire},
    {name = "Bulbs", outline = true, pal = {r = "#E0463C", y = "#F5D442", b = "#5AA0E8", w = "#F4F2EA", o = "#4A4A55", h = "#FFFFFF"}, rows = bulbs},
  }, {pad = 0, w = 96, h = 21})
end

-- ---- tax season: three banker's boxes stacked (14 x 23) ----
do
  local box = {
    "LLLLLLLLLLL",
    "bbbbbbbbbbs",
    "bwwwwbkkkbs",
    "bwggwbbbbbs",
    "bbbbbbbbbbs",
    "bbbbbbbbbbs",
  }
  local pal = {L = "#E0C898", b = "#C8A878", s = "#A88A5C", w = "#F4F2EA", g = "#9AA0A8", k = "#17121F"}
  piece("season_tax_boxes", {
    {name = "Box 1", x = 1, y = 14, pal = pal, rows = box},
    {name = "Box 2", x = 0, y = 7, pal = pal, rows = box},
    {name = "Box 3", x = 1, y = 0, pal = pal, rows = box},
  })
end

-- ---- the XP end of support poster (19 x 17) ----
do
  local paper = {}
  for y = 1, 15 do paper[y] = string.rep(y <= 7 and "b" or "w", 17) end
  piece("season_xp_poster", {
    {name = "Paper", pal = {b = "#3A62A8", w = "#F4F2EA"}, rows = paper},
    {name = "Title", x = 5, y = 1, outline = false, pal = {t = "#FFFFFF"}, rows = PR.text("XP", "t")},
    {name = "Date", x = 1, y = 9, outline = false, pal = {r = "#E0463C"}, rows = PR.text("APR8", "r")},
  })
end

-- ---- back to school: the supply drive box (13 x 14) ----
piece("season_drive_box", {
  {name = "Supplies", x = 0, y = 0, pal = {e = "#FF9AB5", y = "#F5D442", r = "#E0463C", n = "#5AA0E8", N = "#3A62A8"}, rows = {
    ".e..r......",
    ".y..r..nnn.",
    ".y..r..nNn.",
    ".y..r..nnn.",
    ".y..r..nnn.",
    ".y..r..nnn.",
  }},
  {name = "Box", x = 0, y = 5, pal = {L = "#E0C898", b = "#C8A878", s = "#A88A5C", w = "#F4F2EA", g = "#9AA0A8", h = "#E0463C"}, rows = {
    "LLLLLLLLLLL",
    "bbbbbbbbbbs",
    "bwwwwwwwbbs",
    "bwhwgggwbbs",
    "bwwwwwwwbbs",
    "bbbbbbbbbbs",
    "bbbbbbbbbbs",
  }},
})
