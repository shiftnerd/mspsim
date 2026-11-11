# Small art batch (agent `art-small`, Nov 2026): themed escape clock and desk, breakout podiums, card portraits, restaurant and warehouse props

All pieces are rows of characters in `tools/make_game_art.lua` (appended: three blocks at the end), sources in `office/pieces/`
(`escape_*`, `venue_*`), PNGs in `godot/assets/props/`. Rebuild: `ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_game_art.lua")` with
`Aseprite.exe -b --script x.lua`; existing PNGs come out byte-identical.

## 1. R4: the escape room's clock and desk by theme
- Slots `clock` (png 20x54) and `desk` (76x27) in `SetDressing.ESCAPE_SLOTS`, the study's pieces are `grandfather_clock` and `desk_cubicle_74`
  (`ESCAPE_PLAIN`). Same nodes (`grandfather_clock_1`, `desk_cubicle_74_2`), same positions and offsets: nothing moved, the clue spots are Fx
  nodes and did not change.
- server: rack-mounted NTP display (green digits, NTP label unit, patch panel, UPS) on short feet; steel console desk with rack drawers and lights.
  detective: round brass clock over a pendulum window over a filing drawer; heavy pedestal desk. lab: school clock on a pole with a time-card box;
  long beige laminate desk.
- What stands on a themed desk is a separate sprite `escape_<theme>_deskitem` (server: KVM monitor and keyboard; detective: typewriter and a paper stack;
  lab: CRT on a beige case, keyboard, mouse). `SetDressing._escape_deskitem` adds it as `Dressing_deskitem` on the desk node at x 24 (the study's lamp
  sits at x 6 to 20 and stays), its bottom on the desk top (`y = -23 - texture height`). The study has none (hidden).
- Test: `tests/escape_themes.gd` (sizes, own textures, the study keeps its own, the real detective room shows the pendulum clock, the pedestal desk and the
  typewriter, positions unchanged, the scripted solver still gets out).

## 2. R23: podiums in SALON B, C and D
- `venue_podium_b` (light wood), `_c` (burgundy), `_d` (grey steel), 14x28, side-on, facing the audience (left), gooseneck mic.
- Placed BESIDE the speaker on his back side (the speakers face left): scene x 240 / 250 / 252 (speakers at 214 / 192 / 204), sort line 119, through the
  props JSON (`assets/sets/breakout_{b,c,d}_props.json`, set x 176 / 186 / 188, y 92) and the generated scene (`check_generator --keep` scratch copy of
  `breakout_*.tscn`, copied over). Re-running `tools/venue_sets.lua` rewrites those three JSON files and would drop the podium: add the three
  lines back (or put a podium builder there).
- Test: `tests/conference.gd` (`_check_audience`: a podium at sort 119, 14x28, right of the speaker, no seat within 18 px). `side_chairs`, `seats` green.

## 3. R10: card portraits
- Cards had no face: the speaker bar is 9 px high and holds only the name. The head does not fit in it, so the portrait is a column left of the text
  instead (30 px: a 1 px frame round the 26x22 head). `scripts/card_portrait.gd`: `CardPortrait.head(speaker)` returns an `AtlasTexture` of the head
  (frame 0 of the right-facing sheet, rect 16,19,26,22), `character_for(speaker)` maps a speaker line to a character (`Quinn`, `Ross Calder`,
  `Terry Vance`, `Trent Dagmar`, `Ms. Pell`/`Greg Pell` by name, the rest from `World.CAST / CREW_CAST / STAFF_CAST` by name, case-insensitive,
  text after " (" ignored).
- `cards.gd` `_paint`: drawn when the card has no spot picture (`art_tex == null`) and is wide (`pw >= ART_MIN_W`, so not the tall format); the text
  wraps 7 characters narrower and the body is at least 25 px high; if the card then does not fit the screen it goes back to the plain card (same rule
  as the picture). Every card whose speaker is a cast member now shows a face (Morgan, Christy, Alan ...), not only the Year 3 beats.
- Tests: `tests/card_portrait.gd`, `tests/layout_audit.gd` (block "card face", five speakers in every format; 0 failures).

## 4. Restaurant sign, menu board, warehouse trophy shelf
- `venue_sign_open` / `venue_sign_closed` (27x13) hang at scene (24, 4) of the restaurant, OPEN while `Outings.game == "dinner"`, else CLOSED;
  `venue_menu_board` (22x28) hangs on the wall in the gap between the two booths at (84, 50). `SetDressing.dress` now also dresses `restaurant`
  signs and the `warehouse`; `refresh()` flips the signs.
- `venue_trophy_shelf` (30x9) on the warehouse wall above the chair rack (set 132, 44) with four trophy sprites (7x11) standing on it:
  `clean` (CLEAN LAP, gold cup), `speed` (SPEED DEMON, red cup with a bolt), `track` (TRACK RAT, silver cup), `bumper` (BUMPER KING, crown); each shows
  once `Career.has_medal(id)` is true (`clean_lap`, `speed_demon`, `track_rat`, `bumper_king`). The plank is always there.
- Test: `tests/venue_props.gd`.

## Decisions made
- The podium variants differ by palette only (one shape).
- The menu board is a wall piece, not a floor stand, because the floor between the booths is where diners sit.
- Not seen composed in a real play session: the restaurant sign and menu board, the trophy shelf and the three podiums were seen in windowed
  screenshots of the scenes at 1x (a campaign run was not played); the clock and desk were seen in the lab room.
