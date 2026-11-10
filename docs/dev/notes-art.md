# Art batch: decor sprites, pad glyphs, creator art pass, two forum regulars, mini-game art

Build notes for the art branch (Nov 2026). Every sprite here has a layered `.aseprite` source and a PNG under
`godot/assets/`; the code keeps the old code-drawn version as the fallback when a texture is missing.

## The piece tool (`tools/piece_rows.lua`)

Small pieces are rows of characters, like `tools/make_shop_props.py`, but the result is a layered `.aseprite`:
`PR.build{name, ase = "office/pieces/", png = "godot/assets/props/" or nil, pad, layers = {{name, x, y, rows, pal, outline}}}`.
Each layer is a full-canvas cel; a layer gets the 1 px `#17121F` outline (4 neighbours) unless `outline = false`;
`pad = 0` makes a piece with no margin (floor paint, atlases). `PR.text("APR8", "r")` returns 3x5 letter rows.
Run a maker in a checkout with `ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_decor.lua")` and
`Aseprite.exe -b --script x.lua`, then `Godot --headless --path godot --import`.

| maker | sources | PNGs |
|---|---|---|
| `tools/make_decor.lua` | `office/pieces/decor_*.aseprite`, `season_*.aseprite` | `assets/props/decor_*.png`, `season_*.png` |
| `tools/make_icons.lua` | `office/pieces/ui_*.aseprite` | `assets/ui/pad_glyphs.png`, `touch_*.png` |
| `tools/make_game_art.lua` | `office/pieces/game_*.aseprite` | `assets/props/chair_*.png`, `dinner_plate_*.png`, `desk_headset.png`, `assets/ui/star_asked.png` |

## R16: office growth decor and the seasonal dressing (`scripts/office_decor.gd`)

`OfficeDecor.SPRITES` lists the 15 sprites and their sizes, `OfficeDecor.art(id)` loads one (null when missing),
`_put(id, at)` draws it. Placements (top-left, room coordinates of the main floor):

| item | sprite | at |
|---|---|---|
| rug | `decor_rug` 40x9 | 12, 100 |
| plant | `decor_plant` 17x39 | 147, 53 (the gap between desk 1 and the first office door) |
| certificate | `decor_certificate` 15x12 | 97, 20 |
| fish tank | `decor_fish_tank` 20x15, `decor_fish` 4x3 | 131, 31; the fish swims x 134..144, flips, bobs |
| trophy shelf | `decor_shelf` 34x6, `decor_trophy_a/b/c` | 304, 46; trophies at 308 / 318 / 326, y 36 |
| neon | `decor_neon_on` / `_off` 37x11 | 164, 9 (was y 6: the holiday lights hang above it now) |
| lights | `season_lights` 96x21 (a 96 px tile, three blink phases of 7 rows) | x 82..360, y 2 |
| tax boxes | `season_tax_boxes` 14x22 | 150, 87 (in front of the plant: the seasons are drawn after the decor) |
| XP poster | `season_xp_poster` 19x17 | 131, 13 |
| drive box | `season_drive_box` 13x14 | 44, 74 |

Test: `tests/office_growth.gd` (the sprites load at their sizes, a missing one is null).

## R14 / R37: pad glyphs, the touch overlay, the phone's CAMERA icon

- `scripts/pad_glyphs.gd` (`PadGlyphs`, static): `draw(canvas, text, pos, color, scale)` and `width(text, scale)` are
  the `PixelFont` ones until a pad is in use (`Controls.pad_active`, or `PadGlyphs.force = 1` in a test); then the
  tokens `(A) (B) (X) (Y) (LB) (RB) (LT) (RT) (START) (BACK) (L3) (R3) (UP) (DOWN) (LEFT) (RIGHT)` and the whole word
  `STICK` become glyphs from the atlas (12 cells of 11x7: the font's 5 rows plus one above and below; a glyph is drawn
  one row above the text line). `glyph(canvas, name, pos)` draws one; `NAMES`, `WIDTHS`, `TOKENS`.
- Used by: the HUD hint (`hud.gd _draw_hint`), every panel footer (`UiStyle.footer`), the pause menu's key list (on a
  pad the rows with an action show the pad's button) and its remap list (the pad button is its glyph, right of the key).
- **Not converted** (plain text still, they show "(A)" as letters): hint lines a screen draws itself with
  `PixelFont.draw` / `UiStyle.text` instead of `UiStyle.footer` (not surveyed one by one: Grep for
  `Controls.hint(` and `Controls.label(` to find them). Swap the call for `PadGlyphs.draw` where wanted; widths
  differ, so a centred or right-aligned line needs `PadGlyphs.width`.
- Touch overlay (`touch_overlay.gd`): the stick base (46x46), the knob (19x19), a round face for A and B / X (24x24)
  and a pill for MENU / NEXT / ROLL (26x19). The PNGs are opaque white and ink (the art lint forbids soft alpha); the
  script draws them see-through (`SOFT`) and tints a pressed one (`PRESSED`). The hit rectangles are unchanged.
- The phone's icons are all drawn in code at the phone's scale, so the CAMERA icon stays code-drawn like them and
  got a lens glint and a flash (no sprite: a sprite would not follow `_sc` and would not match the others).
- Test: `tests/pad_glyphs.gd`.

## R15: the creator's weakest art

- Clothes (`tools/make_clothes.lua`, `office/clothes.aseprite`): the skirt is an A-line skirt to above the knee
  (rows 36 to 50, 17 to 21 px wide, three pleats, a hem) instead of a mini skirt hidden by the shirt hem; rows 47 to 50
  lie right under the hip pivot, so the two halves follow their legs by a pixel at most (checked by eye in the walk,
  run and seated frames of the golden reference). Jeans: a stitched waistband, the second front pocket, creases.
  Long sleeves (button-down, sweater): elbow creases on the near sleeve, a lit fold on the far one.
- Accessories (`tools/make_accessories.lua`, `office/accessories.aseprite`): watches have a strap, a case and a dark
  dial with one lit pixel; the Santa hat has a 4x3 pom with its own outline; the bucket hat's brim is lit on top and
  stitched below. **Limit found**: a hat may not go left of x 10 above row 4 or wider than x 7..32 at the brim: the
  40 px hat cell is tight on the left-facing sheet (`make_head_sheets.lua` asserts it, `tests/accessories.gd` wants
  a free border). Taller hats (a real party cone, a lamp on the hard hat) need a bigger hat cell or `HAT_UP`, which
  means new origin tables and all hat sheets: not done.
- Rebuilt: the six changed clothes pieces and the five changed accessories (the tools rebuild every sheet, the
  unchanged ones come out byte-identical), and the golden references `ref_hat_santa`, `ref_watch_sport` and the three
  outfits. To redraw a piece again: delete its layer from the `.aseprite`, run the maker, then the sheet tool with
  the `REF` list of CLAUDE.md.
- Not touched: the cap, beanie, hard hat and party hat, the lanyard and the HELLO sticker.
- Tests: `accessories`, `clothes`, `creator`, `brows`, `outfit` pass.

## R28: two more forum regulars

- **TapeTony** (`expo_tony`, `tools/make_men.lua`): the backup old-hand who still rotates tapes. Navy cap, grey
  goatee, tan work shirt, dark jeans. Stands in the breakout corridor (`resort_hall`, x 178, between the doors of
  rooms B and C). Card `Expo.FORUM` id `tony`: rotation (+4 servers), last restore (+3 security), quote him (+3
  karma), the tape in his pocket (+1 social).
- **DNS_Dot** (`expo_dot`, `tools/make_fem.lua`): "it is always DNS", labels everything. Auburn curls, glasses, a
  mustard cardigan. Stands in the vendor hall (x 115). Card id `dot`: why DNS (+4 networking), the label maker (+3
  customer), mark her answer solved (+3 karma), a label for your badge (+1 social).
- Both are in `Nerds.POSTERS` (REGULAR) with one post each at the end of an open thread, in `EXTRA_CHARACTERS`, with
  `characters/expo_*.tres`; `godot/story/strings.txt` and `STORY.md` were synced (the new strings are appended, no
  key moved, so no section was deleted).
- Test: `tests/forum_people.gd` (frames, placement off the doors and the other people, the cards, the posts).

## Mini-game art

- Chair games (`chair_track.gd`): `floor_paint(id)`; the fight has a ring painted on the floor (`_ring()`: a hazard
  bracket at each end of the strip, a dashed line along both edges, a spot in the middle), a course that ends before
  the painted line gets a checkered finish line sprite (the code-drawn one is the fallback).
- Dispatch (`dispatch.gd`): `asked_for(t)` and `star()`; a ticket a client asked a tech for (`asked_tech`, not
  closed) has a small gold star in the chip's top right corner (left of the `?` of a stuck ticket).
- `scripts/set_dressing.gd` (`SetDressing.dress(stage)`, called by the stage after `OfficeDecor.dress`): four plates
  on the restaurant's two booth tables while a dinner is past its ordering round (`plates_on()`), and a headset on
  its stand on Jen's desk in `cubicle_two` when the cast has a Jen. The sprites are children of the table / desk.
- Test: `tests/game_art.gd`.

## Decisions made

- Sources of small pieces go in `office/pieces/` (where the other single props are), with the prefixes `decor_`,
  `season_`, `ui_`, `game_`; UI PNGs go in `assets/ui/` without the `ui_` prefix.
- The plant moved from behind desk 1 (where the phone covered it) to the gap before the first door, and the tax
  boxes stand in front of it; the neon sign moved down 3 px so the holiday lights clear it.
- The phone CAMERA icon stays code-drawn (see above).
- The skirt crosses the hip row (see above) instead of staying a torso-only piece.
- Floor paint has no outline and a few worn pixels; it is drawn under the chairs like the code version was.

## Left open

- Themed escape room props (safe, trunk, globe for the server room, detective's office and computer lab): not drawn.
- Pad glyphs in the screens that draw their own hint lines (list above).
- Taller hats (needs a bigger hat cell), a text on the HELLO sticker, a night version of the western set, a pushing
  pose, a guest sprite at the dinner booth.
