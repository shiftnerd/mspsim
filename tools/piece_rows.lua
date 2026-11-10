-- Small pieces drawn as rows of characters (like tools/make_shop_props.py, but the source is a layered .aseprite).
-- Used by tools/make_decor.lua, make_icons.lua and friends:
--   local PR = dofile(ROOT .. "tools/piece_rows.lua")
--   PR.build{name = "decor_plant", ase = "office/pieces/", png = "godot/assets/props/", layers = {
--     {name = "Pot", x = 2, y = 27, rows = {...}, pal = {p = "#B8663F"}},            -- outlined (1 px #17121F, sides only)
--     {name = "Text", x = 3, y = 1, rows = {...}, pal = {...}, outline = false}}}    -- a detail: no outline of its own
-- Layer coordinates are content coordinates: the canvas gets a 1 px margin for the outline (pad = 0 turns that off).
-- '.' is transparent. Every layer is a full-canvas cel on its own layer, bottom to top. `png = nil` writes no PNG.
local M = {}
M.ROOT = ROOT or "D:/creative/pixelproject/"
M.INK = "#17121F"

local function C(h)
  return Color{r = tonumber(h:sub(2, 3), 16), g = tonumber(h:sub(4, 5), 16), b = tonumber(h:sub(6, 7), 16), a = 255}
end

local function outlined(im)
  local o = Image(im)
  local oc = C(M.INK)
  local function a(x, y)
    if x < 0 or y < 0 or x >= im.width or y >= im.height then return 0 end
    return app.pixelColor.rgbaA(im:getPixel(x, y))
  end
  for y = 0, im.height - 1 do
    for x = 0, im.width - 1 do
      if a(x, y) == 0 and (a(x - 1, y) > 0 or a(x + 1, y) > 0 or a(x, y - 1) > 0 or a(x, y + 1) > 0) then
        o:putPixel(x, y, oc)
      end
    end
  end
  return o
end

-- 3x5 letters for signs and posters drawn into a piece: M.text("APR8", "r") returns rows using the character `ch`
M.FONT = {
  A = {"###", "#.#", "###", "#.#", "#.#"}, B = {"##.", "#.#", "##.", "#.#", "##."}, E = {"###", "#..", "##.", "#..", "###"},
  I = {"###", ".#.", ".#.", ".#.", "###"}, L = {"#..", "#..", "#..", "#..", "###"}, P = {"###", "#.#", "###", "#..", "#.."},
  R = {"##.", "#.#", "##.", "#.#", "#.#"}, S = {"###", "#..", "###", "..#", "###"}, T = {"###", ".#.", ".#.", ".#.", ".#."},
  X = {"#.#", "#.#", ".#.", "#.#", "#.#"}, Y = {"#.#", "#.#", ".#.", ".#.", ".#."}, K = {"#.#", "#.#", "##.", "#.#", "#.#"},
  ["8"] = {"###", "#.#", "###", "#.#", "###"}, [" "] = {"..", "..", "..", "..", ".."},
}

function M.text(str, ch)
  local rows = {"", "", "", "", ""}
  for i = 1, #str do
    local g = M.FONT[str:sub(i, i)]
    for r = 1, 5 do
      rows[r] = rows[r] .. (i > 1 and "." or "") .. g[r]:gsub("#", ch)
    end
  end
  return rows
end

function M.build(spec)
  local pad = spec.pad or 1
  local w, h = spec.w or 0, spec.h or 0
  for _, l in ipairs(spec.layers) do
    for r, row in ipairs(l.rows) do
      assert(#row == #l.rows[1], spec.name .. "/" .. l.name .. " row " .. r .. " is " .. #row .. " wide, not " .. #l.rows[1])
    end
    if not spec.w then w = math.max(w, (l.x or 0) + #l.rows[1]) end
    if not spec.h then h = math.max(h, (l.y or 0) + #l.rows) end
  end
  local spr = Sprite(w + pad * 2, h + pad * 2, ColorMode.RGB)
  for i, l in ipairs(spec.layers) do
    local im = Image(spr.width, spr.height, ColorMode.RGB)
    for r, row in ipairs(l.rows) do
      for c = 1, #row do
        local ch = row:sub(c, c)
        if ch ~= "." then
          local col = l.pal[ch]
          assert(col, spec.name .. "/" .. l.name .. ": no colour for '" .. ch .. "'")
          im:putPixel((l.x or 0) + pad + c - 1, (l.y or 0) + pad + r - 1, C(col))
        end
      end
    end
    if l.outline == true or (l.outline == nil and pad > 0) then im = outlined(im) end
    local layer = (i == 1) and spr.layers[1] or spr:newLayer()
    layer.name = l.name
    spr:newCel(layer, 1, im, Point(0, 0))
  end
  spr:saveAs(M.ROOT .. spec.ase .. spec.name .. ".aseprite")
  if spec.png then spr:saveCopyAs(M.ROOT .. spec.png .. spec.name .. ".png") end
  print(spec.name, spr.width, spr.height)
  spr:close()
end

return M
