-- Builds the MSPSim logo, the "PRESS START" prompt and the title screen poster in Aseprite.
--   office/logo/mspsim_logo.aseprite      large logo  (letters x4)
--   office/logo/mspsim_logo_s.aseprite    small logo  (letters x3, fits a 180 px wide portrait frame)
--   office/logo/press_start.aseprite      the prompt, frame 1 = visible, frame 2 = blank (blink)
--   office/logo/title_screen.aseprite     320x180 poster: office, the cast, logo, prompt
-- It also exports flat PNGs for Godot into godot/assets/ui/ (the one place PNGs are expected).
-- Run:  dofile("D:/creative/pixelproject/tools/logo.lua")   (via run_lua_script)
local ROOT = "D:/creative/pixelproject/"
local OUTDIR = ROOT .. "office/logo/"
local UIDIR = ROOT .. "godot/assets/ui/"
app.fs.makeAllDirectories(OUTDIR)
app.fs.makeAllDirectories(UIDIR)

local function hex(h)
  h = h:gsub("#", "")
  return app.pixelColor.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end
local C = {
  out = hex("#17121F"), cream = hex("#F4F2EA"),
  blue = hex("#4F7FD0"), blueHi = hex("#7FA6D8"), blueSh = hex("#3A62A8"), blueExt = hex("#27428A"),
  lime = hex("#8FC43A"), limeHi = hex("#B8E06A"), limeSh = hex("#6E9A2A"), limeExt = hex("#4F7420"),
  steel = hex("#EDEFF4"), steelSh = hex("#B8BCC4"), dark = hex("#2A2A33"), rib = hex("#2A2A33"),
  ribHi = hex("#4A4D55"), ribSh = hex("#1C1C24"), red = hex("#D23C3C"),
}

-- ---- pixel fonts ------------------------------------------------------------------------------------
local FONT5 = {
  M = {"X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X"},
  S = {".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."},
  P = {"XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."},
  I = {"XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"},
}
local FONT3 = {
  M = {"X.X", "XXX", "XXX", "X.X", "X.X"}, S = {"XXX", "X..", "XXX", "..X", "XXX"},
  P = {"XXX", "X.X", "XXX", "X..", "X.."}, I = {"XXX", ".X.", ".X.", ".X.", "XXX"},
  U = {"X.X", "X.X", "X.X", "X.X", "XXX"}, L = {"X..", "X..", "X..", "X..", "XXX"},
  A = {"XXX", "X.X", "XXX", "X.X", "X.X"}, T = {"XXX", ".X.", ".X.", ".X.", ".X."},
  O = {"XXX", "X.X", "X.X", "X.X", "XXX"}, R = {"XXX", "X.X", "XXX", "XX.", "X.X"},
  E = {"XXX", "X..", "XXX", "X..", "XXX"},
}

-- ---- tiny image helpers --------------------------------------------------------------------------------
local function new(w, h) return Image(w, h, ColorMode.RGB) end
local function px(img, x, y, c)
  if x >= 0 and y >= 0 and x < img.width and y < img.height then img:putPixel(x, y, c) end
end
local function rect(img, x, y, w, h, c)
  for j = y, y + h - 1 do for i = x, x + w - 1 do px(img, i, j, c) end end
end
local function solid(img, x, y)
  return x >= 0 and y >= 0 and x < img.width and y < img.height and app.pixelColor.rgbaA(img:getPixel(x, y)) > 0
end
local function stamp(img, rows, x, y, s, c)
  for r = 1, #rows do
    for k = 1, #rows[r] do
      if rows[r]:sub(k, k) == "X" then rect(img, x + (k - 1) * s, y + (r - 1) * s, s, s, c) end
    end
  end
end
local function text3(img, str, x, y, s, c)          -- 3x5 font, 1 px (x s) between letters, space = one blank glyph
  local pitch = 4 * s
  for i = 1, #str do
    local g = FONT3[str:sub(i, i)]
    if g then stamp(img, g, x + (i - 1) * pitch, y, s, c) end
  end
end
local function text3Width(str, s) return #str * 4 * s - s end

-- ---- the headset icon (22 x 20) -----------------------------------------------------------------------
local function headset()
  local im = new(22, 20)
  for y = 0, 11 do
    for x = 0, 21 do
      local d = math.sqrt((x - 10.5) ^ 2 + (y - 11.5) ^ 2)
      if d <= 10.4 and d >= 7.4 then px(im, x, y, d > 8.9 and C.steel or C.steelSh) end
    end
  end
  for _, ex in ipairs({0, 17}) do                    -- earpieces
    rect(im, ex, 10, 5, 8, C.blue)
    rect(im, ex, 10, 1, 8, C.blueHi); rect(im, ex, 17, 5, 1, C.blueSh); rect(im, ex + 4, 10, 1, 8, C.blueSh)
  end
  for i, p in ipairs({{19, 18}, {18, 19}, {17, 19}, {16, 19}, {15, 19}, {14, 19}}) do px(im, p[1], p[2], C.dark) end
  rect(im, 11, 18, 4, 2, C.dark)                      -- microphone
  px(im, 12, 18, C.red)
  return im
end

-- ---- the logo -------------------------------------------------------------------------------------------------
local function buildLogo(S, name)
  local E = (S >= 4) and 3 or 2                       -- depth of the 3D extrusion
  local pad = 2
  local iconW, iconH, iconGap = 22, 20, 6
  local gw, gh = 5 * S, 7 * S
  local groupW = 3 * gw + 2 * S
  local groupGap = 3 * S
  local lettersW = groupW + groupGap + groupW
  local ribbonW, ribbonH = 114, 13
  local lx0 = pad + iconW + iconGap
  local ly = pad + 1
  local w = lx0 + lettersW + E + pad
  local h = ly + gh + E + 3 + ribbonH + pad
  local faceA, faceB = new(w, h), new(w, h)
  for i, ch in ipairs({"M", "S", "P"}) do stamp(faceA, FONT5[ch], lx0 + (i - 1) * (gw + S), ly, S, C.blue) end
  for i, ch in ipairs({"S", "I", "M"}) do stamp(faceB, FONT5[ch], lx0 + groupW + groupGap + (i - 1) * (gw + S), ly, S, C.lime) end
  -- extrusion: both faces copied down and to the right
  local ext = new(w, h)
  for d = E, 1, -1 do
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        if solid(faceA, x, y) then px(ext, x + d, y + d, C.blueExt) end
        if solid(faceB, x, y) then px(ext, x + d, y + d, C.limeExt) end
      end
    end
  end
  -- bevel: a light edge on top/left of every stroke and a darker one on the bottom/right
  local bevel = new(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      for _, f in ipairs({{faceA, C.blueHi, C.blueSh}, {faceB, C.limeHi, C.limeSh}}) do
        if solid(f[1], x, y) then
          if not solid(f[1], x, y - 1) or not solid(f[1], x - 1, y) then px(bevel, x, y, f[2])
          elseif not solid(f[1], x, y + 1) or not solid(f[1], x + 1, y) then px(bevel, x, y, f[3]) end
        end
      end
    end
  end
  local icon = new(w, h)
  icon:drawImage(headset(), Point(pad, ly + (gh - iconH) // 2))
  -- tagline ribbon
  local ribbon, tag = new(w, h), new(w, h)
  local rx, ry = (w - ribbonW) // 2, ly + gh + E + 3
  rect(ribbon, rx, ry, ribbonW, ribbonH, C.rib)
  rect(ribbon, rx, ry, ribbonW, 1, C.ribHi); rect(ribbon, rx, ry + ribbonH - 1, ribbonW, 1, C.ribSh)
  local line = "MSP SIMULATOR"
  text3(tag, line, rx + (ribbonW - text3Width(line, 2)) // 2, ry + 2, 2, C.cream)
  -- outline around the whole silhouette (1 px, 4-neighbour like the characters)
  local union = new(w, h)
  for _, im in ipairs({ext, faceA, faceB, icon, ribbon}) do union:drawImage(im, Point(0, 0)) end
  local outline = new(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if not solid(union, x, y) and (solid(union, x - 1, y) or solid(union, x + 1, y) or solid(union, x, y - 1) or solid(union, x, y + 1)) then
        px(outline, x, y, C.out)
      end
    end
  end
  local spr = Sprite(w, h, ColorMode.RGB)
  local order = {{"Outline", outline}, {"Extrusion", ext}, {"Face MSP", faceA}, {"Face SIM", faceB}, {"Bevel", bevel},
                 {"Headset", icon}, {"Ribbon", ribbon}, {"Tagline", tag}}
  for i, l in ipairs(order) do
    local layer = (i == 1) and spr.layers[1] or spr:newLayer()
    layer.name = l[1]
    spr:newCel(layer, 1, l[2], Point(0, 0))
  end
  spr:saveAs(OUTDIR .. name .. ".aseprite")
  spr:saveCopyAs(UIDIR .. name .. ".png")
  local flat = new(w, h)
  for _, l in ipairs(order) do flat:drawImage(l[2], Point(0, 0)) end
  spr:close()
  print(name, w .. "x" .. h)
  return flat
end

local logoL = buildLogo(4, "mspsim_logo")
local logoS = buildLogo(3, "mspsim_logo_s")

-- ---- "PRESS START" prompt (frame 1 visible, frame 2 blank for blinking) ----------------------------------------
local function buildPrompt()
  local str = "PRESS START"
  local s = 2
  local w, h = text3Width(str, s) + 4, 5 * s + 4
  local shadow, face = new(w, h), new(w, h)
  text3(shadow, str, 3, 3, s, C.out)
  text3(face, str, 2, 2, s, C.cream)
  local spr = Sprite(w, h, ColorMode.RGB)
  spr.layers[1].name = "Shadow"
  spr:newCel(spr.layers[1], 1, shadow, Point(0, 0))
  local l2 = spr:newLayer()
  l2.name = "Text"
  spr:newCel(l2, 1, face, Point(0, 0))
  spr:newFrame()
  spr:newCel(spr.layers[1], 2, new(w, h), Point(0, 0))
  spr:newCel(l2, 2, new(w, h), Point(0, 0))
  spr:saveAs(OUTDIR .. "press_start.aseprite")
  local flat = new(w, h)
  flat:drawImage(shadow, Point(0, 0)); flat:drawImage(face, Point(0, 0))
  local one = Sprite(w, h, ColorMode.RGB)
  one:newCel(one.layers[1], 1, flat, Point(0, 0))
  one:saveCopyAs(UIDIR .. "press_start.png")
  one:close(); spr:close()
  return flat
end
local prompt = buildPrompt()

-- ---- the poster: the real office, the cast, the logo ---------------------------------------------------------------
local function flatFrame(path)
  local s = Sprite{fromFile = path}
  local im = new(s.width, s.height)
  im:drawSprite(s, 1)
  s:close()
  return im
end
local function build_poster()
  local W, H = 320, 180
  local bg = Image{fromFile = ROOT .. "godot/assets/sets/main_floor.png"}
  local spr = Sprite(W, H, ColorMode.RGB)
  local back = new(W, H)
  back:drawImage(bg, Point(-24, -60))                         -- ceiling, wall and carpet from the real main floor set
  spr:newCel(spr.layers[1], 1, back, Point(0, 0))
  spr.layers[1].name = "Office"
  local cast = new(W, H)
  local people = {{"casual_garrison_left", 118}, {"office_alan_right", 158}, {"office_dan_left", 246}, {"office_adult_right", 286}}
  for _, p in ipairs(people) do
    cast:drawImage(flatFrame(dofile(ROOT .. "tools/sprite_path.lua")(ROOT, p[1] .. "_anim")), Point(p[2] - 32, 158 - 79))
  end
  local lc = spr:newLayer(); lc.name = "Cast"
  spr:newCel(lc, 1, cast, Point(0, 0))
  local logo = new(W, H)
  logo:drawImage(logoL, Point((W - logoL.width) // 2, 14))
  local ll = spr:newLayer(); ll.name = "Logo"
  spr:newCel(ll, 1, logo, Point(0, 0))
  local pr = new(W, H)
  pr:drawImage(prompt, Point((W - prompt.width) // 2, 163))
  local lp = spr:newLayer(); lp.name = "Prompt"
  spr:newCel(lp, 1, pr, Point(0, 0))
  spr:newFrame()                                              -- frame 2: the prompt is off (blink)
  spr:newCel(spr.layers[1], 2, back, Point(0, 0))
  spr:newCel(lc, 2, cast, Point(0, 0))
  spr:newCel(ll, 2, logo, Point(0, 0))
  spr.frames[1].duration = 0.7
  spr.frames[2].duration = 0.4
  spr:saveAs(OUTDIR .. "title_screen.aseprite")
  spr:close()
end
build_poster()
print("logo done")
