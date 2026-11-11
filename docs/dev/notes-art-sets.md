# Art sets: paintball night street, bigger western street, escape room theme sets (R41, R4)

Builders: `tools/paintball_set.lua`, `tools/outing_sets.lua` (loaded by `tools/build_sets.lua`). Rebuild with a small script
`ROOT = "<checkout>/"; ONLY = {paintball_field = true, paintball_field_night = true}; dofile(ROOT .. "tools/build_sets.lua")`
(or `ONLY = {escape_room_server = true, escape_room_detective = true, escape_room_lab = true}`) in `Aseprite.exe -b --script`, then
`Godot --headless --path godot --import`. Building rewrites `godot/assets/props/network_rack_layout.json` and the `*_props.json`
line endings (CRLF to LF): `git checkout` them, and delete the `escape_room_<theme>_props.json` and `paintball_field_night_props.json`
the builder also writes (nothing reads them: the scenes are not regenerated for the new sets).

## Paintball night street

- `paintball_field_night` (`office/paintball_field_night.aseprite`, `godot/assets/sets/paintball_field_night.png`, same 700x320 canvas and
  geometry as the day set) and the six cover pieces as `pbn_*` (`godot/assets/props/pbn_*.png`, same sizes as `pb_*`).
- The day builder is now `field(s, night)`. In night mode `L.fill` is wrapped (`withNight`) so every day colour goes through the table `NM`
  (a hand-picked ramp per material: wood, sand, rock, stone, hay, cactus, metal, water; unknown colours fall back to a cool multiply).
  Layers: `Sky` (banded gradient with dither, stars, thin clouds, a crescent moon at set x 452), the same Mesas / Town / Ground / Lines, and
  `Light` (alpha): halos round every lit window and lantern, fans of light from the saloon and store doors, pools on the street.
- Godot: `PaintballTrack._swap_night_art(scene)` (called in `setup` when `game.night`) swaps the `Background` texture and every `pb_*` sprite in
  `Actors` for its `pbn_*` twin and sets `_night_art`. With `_night_art` the code-drawn wash, stars, moon and windows (`_draw_night`) are skipped;
  the muzzle flashes, the actors' night tint and the paintball glow stay. If the night texture is missing nothing is swapped and the old wash
  is the fallback.
- Test: `tests/paintball_night.gd` (textures exist and have the day sizes, a day match keeps the day art, a night match swaps the background and
  all 8 props). `paintball`, `paintball_room`, `paintball_tuning` unchanged and green (the art is cosmetic).

## A bigger western street (day and night)

Added to the shared builder, so both sets have it, all on the boardwalk line (builder y 88) or behind it, never in the lanes (y 104..132), and
none of it is a prop (no new y-sorting, no new collision): a general store (green clapboard, striped awning, STORE sign, lit windows, door,
wanted posters), a church with a steeple and a bank with columns painted hazy and outline-free on the far rocks, a windmill, three hitching
posts, barrels (jail, saloon corner), a crate on the store porch, a post lamp, and lanterns by the saloon, store and jail doors (dark by day,
lit at night). The cover pieces stay warm brown; the new buildings are green-grey, white and blue-grey so nothing reads as a barricade.
Water tower, saloon and jail are unchanged.

## Escape room theme sets

- `escape_room_server`, `escape_room_detective`, `escape_room_lab` (`office/escape_room_<theme>.aseprite`, `godot/assets/sets/escape_room_<theme>.png`,
  320x320 like the study). Same layout: painting (112, 10) 26x32, board (192, 14) 50x30, wall clock (54, 20), timer, keypad, red light, and the
  prop positions of the vault, desk, lamp, clock; the safe, trunk and globe are NOT painted in (still the study's props, themed sprites are another
  worker's job). Server: a row of racks with LEDs, cable tray, wall AC unit, raised floor with perforated tiles, hazard stripe, a network-map poster
  and a monitoring screen for the board. Detective: pinstripe wall, blinds window with light bars on the floor, coat stand with a fedora and trench coat,
  an old photo and a cork case board with red string. Lab: block wall, a long desk with a row of beige CRT PCs and towers, a dot-matrix printer
  on a stand, posters, a whiteboard, grey-blue carpet, a brighter ceiling.
- The bookshelf prop is replaced per theme by `esc_<theme>_shelf.png` (30x66: a rack, filing cabinets, a metal shelf of cases and manuals).
- Godot: `Outings._theme_art(scene)` (called from `_theme_look`, every frame, idempotent) swaps `Background` and `Actors/bookshelf_0`; a painted
  `Background` is not tinted again, `Fx` keeps the theme tint. A missing texture leaves the tint on both as before. `tests/escape_themes.gd` now
  checks the painted background (detective), the shelf, the effects tint and the sizes of all three sets (the old tint assertion stays as the
  fallback branch).
- Left: the grandfather clock prop (the clock clue) and the desk are still the study's in every theme.

## Not done

- Item 4 (breakout rooms): all four SALON rooms already have a projector screen (blank art, the `session_screen` fx writes the session on it) and
  rows of chairs facing it; SALON A has a lectern. B, C and D have no podium: a prop sorted at 119 would hide the presenter standing at y 118 and
  D is deliberately clear in front of the speaker, so I left them.
- Not seen in a game screenshot: the night match with real puppets was screenshotted windowed (day and night); the escape themes server and lab
  were screenshotted in the real room, the detective one only in Aseprite and the test.
