-- Rebuilds every character's *_anim.aseprite from the stills + tools/poses.lua, exports the Godot sprite sheets
-- (godot/assets/characters/<name>_<facing>.png) and the near-hand positions (<name>_<facing>_hands.json).
-- Run:  dofile("D:/creative/pixelproject/tools/build_anims.lua")   (via run_lua_script)
local T = "D:/creative/pixelproject/tools/"
local R = "D:/creative/pixelproject/"
local OUT = R .. "godot/assets/characters/"
local E = dofile(T .. "anim.lua")
local poses, tags = dofile(T .. "poses.lua")
-- set the global ONLY = {"name"} before dofile to rebuild just one character
local names = ONLY or {"office_teen", "office_adult", "office_dan", "office_alan", "site_alan", "casual_garrison", "sales_vic"}
for _, n in ipairs(names) do
  for _, side in ipairs({"right", "left"}) do
    local inP = R .. n .. "_" .. side .. ".aseprite"
    local outP = R .. n .. "_" .. side .. "_anim.aseprite"
    local hands = E.build(inP, outP, poses, tags)
    local spr = Sprite{fromFile = outP}
    local W, H = spr.width, spr.height
    local sheet = Image(W * #spr.frames, H, ColorMode.RGB)
    for i = 1, #spr.frames do
      local im = Image(W, H, ColorMode.RGB)
      im:drawSprite(spr, i)
      sheet:drawImage(im, Point((i - 1) * W, 0))
    end
    sheet:saveAs(OUT .. n .. "_" .. side .. ".png")
    local parts = {}
    for i, h in ipairs(hands) do parts[i] = string.format("[%d,%d,%d,%d]", h[1], h[2], h[3], h[4]) end
    local f = io.open(OUT .. n .. "_" .. side .. "_hands.json", "w")
    f:write("[" .. table.concat(parts, ",") .. "]\n")
    f:close()
    print(n, side, #spr.frames)
    spr:close()
  end
end
