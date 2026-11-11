-- Builds the female characters from the shared 40x64 body (site_alan_right.aseprite): new hair, clothes (blouse,
-- blazer, cardigan, skirt, tights), lips and skin tones. The left-facing file is a mirror of the right one.
-- Run:  dofile("D:/creative/pixelproject/tools/make_fem.lua")  via run_lua_script.
-- Set the global ONLY = {"office_maya"} before dofile to build a subset.
local R = ROOT or "D:/creative/pixelproject/"  -- set the global ROOT = "<checkout>/" to work in a worktree
local SP = dofile(R .. "tools/sprite_path.lua")  -- character files live in sprites/<group>/
local OUT = "#17121F"
local W, H = 40, 64

local function hex(h)
  local r, g, b = h:match("#(%x%x)(%x%x)(%x%x)")
  return app.pixelColor.rgba(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), 255)
end

local base = {
  shirt = {"#4E535B", "#383C43", "#A8AEB8"}, hair = {"#3E2C20", "#5A4232", "#6B3416"},
  pants = {"#3F5E8E", "#2F4A73", "#243A5C"}, shoes = {"#6E7A68", "#55604F"},
  skin = {"#F3B488", "#D88A62", "#B8663F"}, mouth = "#8A4A2E",
}

local CHARS = {
  office_maya = {   -- the new Tier 1 tech: friendly, ponytail, lilac polo, jeans
    skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#6A3A22", "#9A5A32", "#4A2812"}, style = "ponytail",
    shirt = {"#8E6FC0", "#6E52A0", "#E8E0F4"}, pants = {"#3F5E8E", "#2F4A73", "#243A5C"}, bottom = "trousers",
    shoes = {"#E8E4DC", "#C4C0B6"}, lips = "#C0505A",
  },
  office_morgan = {  -- the manager: sleek bob, charcoal blazer over a white blouse, trousers
    skin = {"#E8A87C", "#C98458", "#A8643C"}, hair = {"#2A1C14", "#47301F", "#2A1C14"}, style = "bob",
    shirt = {"#3A3F4A", "#2A2D36", "#F2F2EA"}, pants = {"#2E323C", "#22262E", "#181B22"}, bottom = "trousers",
    shoes = {"#2A2A33", "#1C1C24"}, lips = "#A8404A", blouse = "#F2F2EA",
  },
  office_jen = {   -- the office manager: shoulder-length strawberry-blonde hair, glasses, a coral and pink striped sweater, dark jeans
    skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#C98A5A", "#E0AA7C", "#A8683F"}, style = "bob",
    shirt = {"#E0806A", "#BC5E4C", "#7A3A30"}, pants = {"#34456A", "#26334F", "#1C253A"}, bottom = "trousers",
    shoes = {"#6A4A38", "#523626"}, lips = "#C0505A", glasses = true, stripes = "#E9A9B4",
  },
  office_pell = {   -- the Summit auditor (Ms. Pell): a tight bun, glasses, a navy blazer over a white blouse, grey trousers
    skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#5A5A62", "#7E7E88", "#3E3E46"}, style = "bun",
    shirt = {"#2E3E6A", "#202C4E", "#F2F2EA"}, pants = {"#5A5E68", "#444852", "#30333C"}, bottom = "trousers",
    shoes = {"#2A2A33", "#1C1C24"}, lips = "#A8404A", blouse = "#F2F2EA", glasses = true,
  },
  office_christy = {   -- finance and controller: shoulder-length blonde hair, a red top, a leopard print scarf, black trousers
    skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#C8A064", "#E0BE84", "#A07A44"}, style = "long",
    shirt = {"#D03A32", "#A82A24", "#6A1814"}, pants = {"#26262E", "#1C1C24", "#14141A"}, bottom = "trousers",
    shoes = {"#2A2A33", "#1C1C24"}, lips = "#B8303A", scarf = {"#C8A068", "#4A2E1A"},
  },
  client_karen = {   -- Brightside Realty: long blonde hair, red blazer, grey skirt
    skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#D8B060", "#EBD088", "#B8904A"}, style = "long",
    shirt = {"#B8333F", "#8A2430", "#F2E6E6"}, pants = {"#6A6F7A", "#4A4F5A", "#34383F"}, bottom = "skirt",
    tights = {"#F6C9A4", "#E0A27C"}, shoes = {"#8A1E2A", "#6A141E"}, lips = "#D2452E", blouse = "#F2E6E6",
  },
  client_mina = {    -- Zen Garden Yoga: black hair in a bun, soft grey top, dark leggings
    skin = {"#E8A87C", "#C98458", "#A8643C"}, hair = {"#1A1410", "#33261C", "#1A1410"}, style = "bun",
    shirt = {"#9AA0A8", "#7A8088", "#E4E8EC"}, pants = {"#2E323C", "#22262E", "#181B22"}, bottom = "leggings",
    shoes = {"#E8E4DC", "#C4C0B6"}, lips = "#B8505A",
  },
  client_brandt = {  -- Paws and Claws: the vet, brown ponytail, green scrub top
    skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#7A4A2A", "#A8703C", "#5A3418"}, style = "ponytail",
    shirt = {"#3E8E6E", "#2C6A52", "#C8E8D8"}, pants = {"#3E8E6E", "#2C6A52", "#1E4A38"}, bottom = "trousers",
    shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#C0505A",
  },
  client_hygienist = {  -- the dental office: teal scrubs, hair up in a bun
    skin = {"#C98A5E", "#A8683F", "#8A4E2C"}, hair = {"#2A1C14", "#47301F", "#2A1C14"}, style = "bun",
    shirt = {"#2E9AB8", "#1E7A94", "#BFE8F2"}, pants = {"#2E9AB8", "#1E7A94", "#14566A"}, bottom = "trousers",
    shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#B8505A",
  },
  client_paralegal = {  -- the law office: long dark hair, cream blouse, grey skirt, glasses
    skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#2A1C14", "#47301F", "#2A1C14"}, style = "long",
    shirt = {"#EDE3C8", "#CBBE9C", "#B8943A"}, pants = {"#5A606C", "#42474F", "#2E3238"}, bottom = "skirt",
    tights = {"#2E323C", "#22262E"}, shoes = {"#2A2A33", "#1C1C24"}, lips = "#A8404A", glasses = true,
  },
  office_quinn = {   -- Quinn, the Year 3 new hire: twin buns, a magenta tee, khakis, red sneakers
    skin = {"#C98E66", "#A86C46", "#8A5636"}, hair = {"#241A1C", "#463438", "#1A1214"}, style = "twin",
    shirt = {"#D0508A", "#A83A6C", "#F6D0E2"}, pants = {"#B8A078", "#9A845E", "#7A6644"}, bottom = "trousers",
    shoes = {"#C03A3A", "#9A2C2C"}, lips = "#B8505A",
  },
  expo_dee = {       -- WebWoot Security: red bob, purple polo, black trousers
    skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#B8503E", "#D8704A", "#8A3A28"}, style = "bob",
    shirt = {"#7A4AB0", "#5A3488", "#E8E0F4"}, pants = {"#2E323C", "#22262E", "#181B22"}, bottom = "trousers",
    shoes = {"#2A2A33", "#1C1C24"}, lips = "#C0405A",
  },
  expo_priya = {     -- gnawer: long black hair, grey cardigan, jeans
    skin = {"#B07A52", "#8E5C38", "#6E4326"}, hair = {"#1A1410", "#33261C", "#1A1410"}, style = "long",
    shirt = {"#8A8F9A", "#6A6F7A", "#E0E4EA"}, pants = {"#3F5E8E", "#2F4A73", "#243A5C"}, bottom = "trousers",
    shoes = {"#5A3522", "#4A2C1C"}, lips = "#A8404A",
  },
  expo_tina = {      -- old_hand: short silver hair, dark teal blazer, trousers
    skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#B8BCC4", "#D8DCE4", "#8A8F9A"}, style = "curly",
    shirt = {"#1F5E6E", "#154452", "#E8F0F2"}, pants = {"#2E323C", "#22262E", "#181B22"}, bottom = "trousers",
    shoes = {"#3A3A44", "#2A2A33"}, lips = "#B8505A", blouse = "#E8F0F2",
  },

  expo_rita = {      -- RegexRita (LabRat Nerds forum, patterns for everything): a teal ponytail, a black band tee, jeans, white sneakers
    skin = {"#C98E66", "#A86C46", "#8A5636"}, hair = {"#2FA39A", "#56C8BC", "#1F7A72"}, style = "ponytail",
    shirt = {"#2A2A33", "#1C1C24", "#E8E8EE"}, pants = {"#3F5E8E", "#2F4A73", "#243A5C"}, bottom = "trousers",
    shoes = {"#E8E8EE", "#B8B8C4"}, lips = "#A8404A",
  },

  expo_dot = {       -- DNS_Dot (LabRat Nerds forum, "it is always DNS", labels everything): auburn curls, glasses, a mustard cardigan over a white blouse, charcoal trousers
    skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#8A3A22", "#B85A32", "#5A2412"}, style = "curly",
    shirt = {"#E0B030", "#B88A1C", "#F2F2EA"}, pants = {"#3A3F4A", "#2A2D36", "#1C1E24"}, bottom = "trousers",
    shoes = {"#3A3A44", "#2A2A33"}, lips = "#B8505A", glasses = true, blouse = "#F2F2EA",
  },

  expo_regdesk = {   -- the check-in desk: blonde-brown bun, navy blazer over a white blouse, trousers, conference-teal lanyard and badge
    skin = {"#E8A87C", "#C98458", "#A8643C"}, hair = {"#B88A52", "#D8AC6E", "#8A6234"}, style = "bun",
    shirt = {"#2E3A58", "#222C44", "#F2F2EA"}, pants = {"#2E323C", "#22262E", "#181B22"}, bottom = "trousers",
    shoes = {"#2A2A33", "#1C1C24"}, lips = "#B8404A", blouse = "#F2F2EA", lanyard = "#1FB6B0",
  },

  -- ---- more clients' staff: medical and vet offices have mostly women; the b skins (competitors) are different people
  client_dentrec_a = {  skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#6A3A22", "#9A5A32", "#4A2812"}, style = "ponytail",
    shirt = {"#D88AA8", "#B86888", "#F8E0EA"}, pants = {"#3E4A6A", "#2E3A58", "#1E2A44"}, bottom = "trousers", shoes = {"#E8E4DC", "#C4C0B6"}, lips = "#C0405A" },
  client_dentasst = {   skin = {"#C98A5E", "#A8683F", "#8A4E2C"}, hair = {"#1A1410", "#33261C", "#1A1410"}, style = "bun",
    shirt = {"#A890D8", "#8870B8", "#E8E0F8"}, pants = {"#A890D8", "#8870B8", "#6A5498"}, bottom = "trousers", shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#B8505A" },
  client_dentrec_b = {  skin = {"#E8A87C", "#C98458", "#A8643C"}, hair = {"#2A1C14", "#47301F", "#2A1C14"}, style = "long",
    shirt = {"#6EC8A8", "#4EA888", "#E0F8EE"}, pants = {"#6EC8A8", "#4EA888", "#2E8868"}, bottom = "trousers", shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#C0505A" },
  client_denthyg_b = {  skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#5A3418", "#8A5A32", "#3A2010"}, style = "curly",
    shirt = {"#F0A888", "#D08868", "#FCE8DC"}, pants = {"#F0A888", "#D08868", "#B06848"}, bottom = "trousers", shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#C0505A" },
  client_dentdoc_b = {  skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#B8503E", "#D8704A", "#8A3A28"}, style = "bob",
    shirt = {"#F2F2EA", "#C9C9C0", "#9AC8E8"}, pants = {"#3A3F4A", "#2A2D36", "#1C1E24"}, bottom = "trousers", shoes = {"#2A2A33", "#1C1C24"}, lips = "#B8404A", blouse = "#9AC8E8" },
  client_vetrec_a = {   skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#2A1C14", "#47301F", "#2A1C14"}, style = "bob",
    shirt = {"#7EBE7A", "#5E9E5A", "#E4F4E0"}, pants = {"#4A4F5A", "#3A3F4A", "#2A2E38"}, bottom = "trousers", shoes = {"#5A3522", "#4A2C1C"}, lips = "#C0505A" },
  client_vettech_a = {  skin = {"#B07A52", "#8E5C38", "#6E4326"}, hair = {"#1A1410", "#33261C", "#1A1410"}, style = "ponytail",
    shirt = {"#2E4A8A", "#1E3470", "#C8D4F0"}, pants = {"#2E4A8A", "#1E3470", "#14245A"}, bottom = "trousers", shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#A8404A" },
  client_vetrec_b = {   skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#D8B060", "#EBD088", "#B8904A"}, style = "long",
    shirt = {"#E8883E", "#C86A2A", "#FCE4CC"}, pants = {"#3E4A6A", "#2E3A58", "#1E2A44"}, bottom = "trousers", shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#D2452E" },
  client_vettech_b = {  skin = {"#E8A87C", "#C98458", "#A8643C"}, hair = {"#7A4A2A", "#A8703C", "#5A3418"}, style = "curly",
    shirt = {"#3EA8A8", "#2E8888", "#C8F0F0"}, pants = {"#3EA8A8", "#2E8888", "#1E6868"}, bottom = "trousers", shoes = {"#F2F2EA", "#C9C9C0"}, lips = "#B8505A" },
  client_vetdoc_b = {   skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#B8BCC4", "#D8DCE4", "#8A8F9A"}, style = "bob",
    shirt = {"#F2F2EA", "#C9C9C0", "#E8883E"}, pants = {"#3A3F4A", "#2A2D36", "#1C1E24"}, bottom = "trousers", shoes = {"#3A3A44", "#2A2A33"}, lips = "#B8505A", blouse = "#E8883E", glasses = true },
  client_paralegal_b = {skin = {"#E8A87C", "#C98458", "#A8643C"}, hair = {"#D8B060", "#EBD088", "#B8904A"}, style = "bun",
    shirt = {"#9AB8E0", "#7A98C0", "#E8F0FA"}, pants = {"#3E4A5E", "#2E384A", "#1E2634"}, bottom = "skirt", tights = {"#E8A87C", "#C98458"}, shoes = {"#2E323C", "#22262E"}, lips = "#A8404A" },
  client_agent_a = {    skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#6A3A22", "#9A5A32", "#4A2812"}, style = "long",
    shirt = {"#E0A030", "#C08820", "#FCEBC8"}, pants = {"#3E4A6A", "#2E3A58", "#1E2A44"}, bottom = "skirt", tights = {"#F3B488", "#D88A62"}, shoes = {"#6A4A38", "#523626"}, lips = "#D2452E" },
  client_agent_b = {    skin = {"#B07A52", "#8E5C38", "#6E4326"}, hair = {"#1A1410", "#33261C", "#1A1410"}, style = "curly",
    shirt = {"#2E5AA8", "#1E4488", "#D0DCF4"}, pants = {"#2E5AA8", "#1E4488", "#143068"}, bottom = "trousers", shoes = {"#2A2A33", "#1C1C24"}, lips = "#A8404A", blouse = "#D0DCF4" },
  client_designer_b = { skin = {"#F6C9A4", "#E0A27C", "#C47E58"}, hair = {"#2A1C14", "#47301F", "#2A1C14"}, style = "ponytail",
    shirt = {"#B8503E", "#8A3A28", "#F4D8CC"}, pants = {"#3A3F4A", "#2A2D36", "#1C1E24"}, bottom = "trousers", shoes = {"#E8E4DC", "#C4C0B6"}, lips = "#B8404A", glasses = true },

  client_designer_a = { skin = {"#F3B488", "#D88A62", "#B8663F"}, hair = {"#8A4A2A", "#B8703C", "#6A3418"}, style = "curly",
    shirt = {"#5E9A5A", "#3E7A3E", "#D8F0D4"}, pants = {"#3A3F4A", "#2A2D36", "#1C1E24"}, bottom = "trousers", shoes = {"#6A4A38", "#523626"}, lips = "#B8505A" },
  client_attorney_b = { skin = {"#E8A87C", "#C98458", "#A8643C"}, hair = {"#8A8F9A", "#B0B4BE", "#6A6F7A"}, style = "bob",
    shirt = {"#3E4A5E", "#2E384A", "#EDE3C8"}, pants = {"#3E4A5E", "#2E384A", "#1E2634"}, bottom = "skirt", tights = {"#2E323C", "#22262E"}, shoes = {"#2A2A33", "#1C1C24"}, lips = "#A8404A", blouse = "#EDE3C8" },
  client_foreman_a = {  skin = {"#B07A52", "#8E5C38", "#6E4326"}, hair = {"#1A1410", "#33261C", "#1A1410"}, style = "ponytail",
    shirt = {"#E0A030", "#B87E20", "#FCEBC8"}, pants = {"#6A6F7A", "#4A4F5A", "#34383F"}, bottom = "trousers", shoes = {"#5A3522", "#4A2C1C"}, lips = "#A8404A" },
}

-- hair extensions drawn on the Hair layer, over the existing short cap. rows of B (hair) C (highlight) T (tie), x0/y0 = top left
local STYLES = {
  long = {x = 8, y = 13, rows = {
    "..BBB.", ".BBBBB", ".BBBBB", ".BCBBB", ".BBBBB", ".BBBBB", ".BBCBB", ".BBBBB", ".BBBBB", ".BCBBB", ".BBBBB", ".BBBBB",
    ".BBBBB", ".BBCBB", ".BBBBB", ".BBBB.", "..BBB.", "..BB..",
  }},
  bob = {x = 8, y = 13, rows = {
    "..BBB.", ".BBBBB", ".BBBBB", ".BCBBB", ".BBBBB", ".BBBBB", ".BBCBB", ".BBBBB", "..BBB.",
  }},
  ponytail = {x = 3, y = 5, rows = {
    "......BB.", ".....BBBB", "....TBBBB", "...BBBBB.", "...BBCBB.", "..BBBBB..", "..BBBB...", "..BBCB...", "..BBB....", "...BB....",
    "...BB....", "...B.....",
  }},
  twin = {x = 9, y = 1, rows = {
    ".BBB..............BBB.", "BBCBB............BBCBB", "BBBBB............BBBBB", ".BBB..............BBB.",
  }},
  bun = {x = 9, y = 0, rows = {
    "..BBBB..", ".BBCBBB.", ".BBBBBB.", "..BBBB..", "...TT...",
  }},
  curly = {x = 7, y = 1, rows = {
    -- curls as scallops over the cap (cap columns 5..18): 2-3 px bumps with a 1 px notch the outline fills. The old rows were a
    -- 27 px checkerboard of single pixels, which reads as noise on light hair and stuck out 6 px past the face.
    "....BB.BCB.BBB.BCB.BB......", ".BCBB..............BBB.....", "B...........................",
    "BB..........................", "BB..........................", ".BB.........................",
  }},
}

local function put(im, x, y, c)
  if x >= 0 and x < W and y >= 0 and y < H then im:putPixel(x, y, c) end
end
local function get(im, x, y)
  if x < 0 or x >= W or y < 0 or y >= H then return 0 end
  return im:getPixel(x, y)
end

-- 1 px outline on the sides (no diagonals) around everything `mark` says is new
local function outlineNew(im, cells)
  for _, p in ipairs(cells) do
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
      local nx, ny = p[1] + d[1], p[2] + d[2]
      if app.pixelColor.rgbaA(get(im, nx, ny)) == 0 then put(im, nx, ny, hex(OUT)) end
    end
  end
end

local function recolor(spr, map)
  for _, l in ipairs(spr.layers) do
    local cel = l:cel(1)
    if cel then
      local im = cel.image
      for y = 0, im.height - 1 do for x = 0, im.width - 1 do
        local p = im:getPixel(x, y)
        if app.pixelColor.rgbaA(p) > 0 then
          local key = app.pixelColor.rgba(app.pixelColor.rgbaR(p), app.pixelColor.rgbaG(p), app.pixelColor.rgbaB(p), 255)
          local n = map[key]
          if n then im:putPixel(x, y, n) end
        end
      end end
    end
  end
end

local function layer(spr, name)
  for _, l in ipairs(spr.layers) do if l.name == name then return l end end
end

local function build(name, c)
  local spr = Sprite{fromFile = SP(R, "site_alan_right")}
  local map = {}
  for i = 1, 3 do
    map[hex(base.shirt[i])] = hex(c.shirt[i]); map[hex(base.hair[i])] = hex(c.hair[i]); map[hex(base.pants[i])] = hex(c.pants[i])
    map[hex(base.skin[i])] = hex(c.skin[i])
  end
  map[hex(base.shoes[1])] = hex(c.shoes[1]); map[hex(base.shoes[2])] = hex(c.shoes[2])
  map[hex(base.mouth)] = hex(c.lips)
  map[hex("#6B3416")] = hex(c.hair[3])                      -- brows follow the hair
  spr:deleteLayer(layer(spr, "Stubble"))
  recolor(spr, map)

  -- hair
  local hl = layer(spr, "Hair")
  local him = hl:cel(1).image
  local st = STYLES[c.style]
  local cells = {}
  for r, row in ipairs(st.rows) do
    for col = 1, #row do
      local ch = row:sub(col, col)
      if ch ~= "." then
        local x, y = st.x + col - 1, st.y + r - 1
        local col_ = ch == "B" and hex(c.hair[1]) or (ch == "C" and hex(c.hair[2]) or hex(c.shirt[1]))
        put(him, x, y, col_)
        cells[#cells + 1] = {x, y}
      end
    end
  end
  outlineNew(him, cells)

  -- the lower half: skirt / leggings / trousers
  local pl = layer(spr, "Pants")
  local pim = pl:cel(1).image
  local belt = layer(spr, "Belt")
  if c.bottom == "skirt" then
    local ccells = {}
    for y = 38, 48 do
      local d = (y - 38) // 4
      for x = 14 - d, 31 + d do
        local shade = (x < 16 - d) or (x > 29 + d) or y >= 47
        put(pim, x, y, shade and hex(c.pants[2]) or hex(c.pants[1]))
        ccells[#ccells + 1] = {x, y}
      end
    end
    for x = 12, 33 do put(pim, x, 48, hex(c.pants[3])) end
    outlineNew(pim, ccells)
    -- bare legs / tights below the hem: recolour what was trouser leg
    local legmap = {}
    for i = 1, 3 do legmap[hex(c.pants[i])] = false end
    for y = 49, 60 do for x = 12, 34 do
      local p = pim:getPixel(x, y)
      if app.pixelColor.rgbaA(p) > 0 and p ~= hex(OUT) then
        put(pim, x, y, (x < 22) and hex(c.tights[1]) or hex(c.tights[2]))
      end
    end end
    belt:cel(1).image:clear()
  elseif c.bottom == "leggings" then
    -- fitted dark leggings: the trouser legs, one step narrower at the hem, with a lighter top
    for y = 39, 45 do for x = 14, 31 do
      local p = pim:getPixel(x, y)
      if app.pixelColor.rgbaA(p) > 0 and p ~= hex(OUT) then put(pim, x, y, hex(c.pants[1])) end
    end end
  end

  -- a blouse under the blazer / cardigan: the collar shows the blouse colour
  if c.blouse then
    local col = layer(spr, "Collar"):cel(1).image
    for y = 22, 30 do for x = 14, 32 do
      local p = col:getPixel(x, y)
      if app.pixelColor.rgbaA(p) > 0 and p ~= hex(OUT) and p ~= hex(c.skin[1]) and p ~= hex(c.skin[2]) then put(col, x, y, hex(c.blouse)) end
    end end
  end

  -- a conference lanyard: two straps from the neck to the chest and a white name badge with a coloured stripe
  if c.lanyard then
    local col = layer(spr, "Collar"):cel(1).image
    local strap, strap2 = hex(c.lanyard), hex("#0F8A86")
    local pts = {{17, 24, 1}, {18, 25, 1}, {18, 26, 1}, {19, 27, 1}, {19, 28, 1}, {20, 29, 1}, {20, 30, 1},
                 {25, 24, 2}, {24, 25, 2}, {24, 26, 2}, {23, 27, 2}, {23, 28, 2}, {22, 29, 2}, {22, 30, 2}}
    for _, p in ipairs(pts) do put(col, p[1], p[2], p[3] == 1 and strap or strap2) end
    put(col, 21, 30, strap); put(col, 21, 29, strap)
    for y = 31, 36 do for x = 18, 24 do put(col, x, y, hex(OUT)) end end          -- badge outline
    for y = 32, 35 do for x = 19, 23 do put(col, x, y, hex("#F6F6EE")) end end
    for x = 19, 23 do put(col, x, 32, strap) end                                   -- the stripe
    put(col, 19, 34, hex("#5A606C")); put(col, 20, 34, hex("#5A606C")); put(col, 21, 34, hex("#5A606C"))
    put(col, 19, 35, hex("#9AA0AE")); put(col, 20, 35, hex("#9AA0AE"))
  end

  -- stripes: a 1 px lighter line every third row across the sweater and its sleeves
  if c.stripes then
    local sc = hex(c.stripes)
    for _, ln in ipairs({"Shirt", "Near Arm", "Back Arm"}) do
      local im = layer(spr, ln):cel(1).image
      for y = 26, 36, 3 do for x = 0, W - 1 do
        local p = im:getPixel(x, y)
        if app.pixelColor.rgbaA(p) > 0 and p == hex(c.shirt[1]) then im:putPixel(x, y, sc) end
      end end
    end
  end

  -- a leopard print scarf: a band around the neck and a short tail down the chest, tan with dark spots
  if c.scarf then
    local col = layer(spr, "Collar"):cel(1).image
    local base_c, spot = hex(c.scarf[1]), hex(c.scarf[2])
    for y = 24, 26 do for x = 15, 26 do put(col, x, y, base_c) end end
    for _, p in ipairs({{16, 24}, {19, 25}, {22, 24}, {25, 25}, {17, 26}, {21, 26}, {24, 26}}) do put(col, p[1], p[2], spot) end
    for y = 27, 31 do for x = 21, 24 do put(col, x, y, base_c) end end
    for _, p in ipairs({{22, 27}, {24, 28}, {21, 29}, {23, 30}, {22, 31}}) do put(col, p[1], p[2], spot) end
    for x = 21, 24 do put(col, x, 32, hex(OUT)) end
  end

  -- glasses (copied from Dan's file: same canvas)
  if c.glasses then
    local dan = Sprite{fromFile = SP(R, "office_dan_right")}
    local gl = layer(dan, "Glasses")
    local gnew = spr:newLayer(); gnew.name = "Glasses"
    spr:newCel(gnew, 1, gl:cel(1).image:clone(), Point(0, 0))
    dan:close()
  end
  spr:saveAs(SP(R, name .. "_right"))

  -- the left-facing file is the mirror: flip every cel, move it to the mirrored position
  local left = Sprite{fromFile = SP(R, name .. "_right")}
  for _, l in ipairs(left.layers) do
    local cel = l:cel(1)
    if cel then
      local im = cel.image
      local copy = im:clone()
      for y = 0, im.height - 1 do for x = 0, im.width - 1 do im:putPixel(im.width - 1 - x, y, copy:getPixel(x, y)) end end
      local oldx = cel.position.x
      cel.position = Point(W - oldx - im.width, cel.position.y)
    end
  end
  left:saveAs(SP(R, name .. "_left"))
  left:close()
  spr:close()
  print("built", name)
end

for name, c in pairs(CHARS) do
  if not ONLY or ONLY[name] then build(name, c) end
end
