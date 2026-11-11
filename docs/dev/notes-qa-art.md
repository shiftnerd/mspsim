# Visual QA of the Nov 2026 art and room content (slug `qa-art`)

Everything below was judged from real rendered screenshots (windowed Godot, not headless), at 1x and in enlarged crops.

## How to look again

- `godot/tests/qa_art_shots.gd` (a shots script, not a test): groups `breakout`, `escape`, `paintball`, `people`, `decor`, `hats`, `ui`
  and `sleeves` (every walk and run frame of the long sleeves).
  `MSPSIM_TEST=1 QA_SET=escape,paintball QA_OUT=C:/somewhere/ Godot.exe --path godot --fixed-fps 60 -s res://tests/qa_art_shots.gd -- --format=h`
  writes `<group>_<name>_<format>.png` into `QA_OUT` (default `user://qa_art/`; never a folder in the project). Run one group list per
  process and `ui` or `hats` not after each other in a different order than the default (both leave through the title scene).
- A story card that opens by itself is drained before a shot (`_shot(name, keep_card)`), `*_bare` shots hide every `CanvasLayer`.
- Formats shot: `h` and `deck` for every group, `wide` and `v` for escape, paintball, decor and ui.

## Findings (H blocks play, M visible defect, L polish)

| # | scene | what was wrong | sev | state |
|---|---|---|---|---|
| 1 | Event cards (R8), co-op chair duel HUD, mutator icon on the options page | The pictures drew as **plain white boxes**: `Cards._art_tex()`, `Outings._duel_art()` and `Yeartwo.mut_icon()` called `load()` inside the paint and kept no reference, so the texture was freed before the frame was rendered (invisible to a headless test). | M | FIXED: each keeps its textures in a dictionary (`_art_cache`, `_duel_tex`, `_mut_tex`). After: the 34x26 card picture, the clock frame / P1 P2 tags / pips and the 12x12 icon show in h, deck, wide and v (the icon where the row pitch allows, as designed). |
| 2 | Every in-room outing (escape room, dinner, paintball, ...) | The four office staff (`World.STAFF_CAST`: Jen and the others) came along to every outing: `start_outing` treated anyone not in `CAST` as a service tech and stood them in a row at Dan's spot, in front of the escape room's desk and safe, the dinner guest's place setting and briefcase, and on the red paintball base. | M | FIXED: `World.start_outing` leaves `STAFF_CAST` outside (they come back with `end_outing` like everyone). After: the rooms show their props; `roster`, `outings`, `playeras`, `dinner_sim`, `coop_outing_bodies` pass. |
| 3 | Paintball day and night | Name tags (`YOU`, `A`, `G`) were drawn at feet - 50, across the eyes of every player. | M | FIXED: `TAG_UP` 68 (above the hair), 14 lower when ducking as before. |
| 4 | Paintball day and night | Whoever did not get a marker stood in the middle lane on the red base and its flag. | M | FIXED: `PaintballTrack._sync` moves every NPC of the room up to `PORCH_Y` 90 (the boardwalk, behind all three lanes). With 2 the street is now only the six players; the flag (9x7 cloth on a 26 px pole) and the base outline are visible, the flag is small next to people (L, not changed). |
| 5 | Breakout C (Tina), vendor hall (DNS_Dot) and four client staff | The `curly` hair of `tools/make_fem.lua` was two rows of single alternating pixels 27 px wide: on silver or auburn hair it read as a black and white checkerboard sticking 6 px out past the face. | M | FIXED: scalloped curls (2 to 3 px bumps with 1 px outline notches) over the cap, 3 px of volume at the back and front. Rebuilt with `ONLY`: `expo_tina`, `expo_dot`, `client_denthyg_b`, `client_vettech_b`, `client_agent_b`, `client_designer_a` (stills, left files, anim files, sheets). Compared with the old sheets: only rows 18 to 22 of the head differ, nothing below the head; the hands json are unchanged. |
| 6 | Escape room: server room, detective's office, computer lab | The clue on the board (`34582961 MISSING?`) was written in pale ink over busy painted boards: close to unreadable on the cork board and the whiteboard, poor on the monitoring screen. | M | FIXED (data): `ESCAPE_THEMES.<theme>.ink` server `f2fff4`, detective `2a1c14`, lab `1e2a44`. After: readable in all three; the painted lines still run behind the text (a clean patch on each board would need the three sets rebuilt: L, not done). |
| 7 | `tools/venue_sets.lua` (breakout B and D) | The builder had the new back-row chairs but was never run; run with `ONLY`, it wrote the same nine props as the committed JSON in a **different order** (the scenes name chairs by index). The background PNGs came out identical. | L | FIXED: the builder's chair order is the JSON's; rebuilt output equals the committed `breakout_b_props.json` / `breakout_d_props.json` (line endings aside), `office/breakout_b.aseprite` and `_d` are the rebuilt sources. |
| 8 | Escape room, server room and computer lab | The study's wooden grandfather clock and wooden desk stand among the racks and the beige PCs: the clock is the worst (a pendulum clock on a raised floor), the desk reads as borrowed furniture. Detective's office: both fit. | M | NOT FIXED here (another worker is drawing the themed clock and desk). The themed shelf, safe, trunk and globe pieces sit on the floor line and match their rooms' palettes in all four themes. |
| 9 | Long-sleeve outfits (button-down, sweater) | The dark wrist band over the near cuff is the intern's own `Watch` layer baked into `custom_bare`: `make_clothes_sheets.lua` cuts the near sleeve where the Watch covers it, on purpose. It shows in every frame where the near wrist is visible (idle, walk 1-2 and 7-8, run), also when the WATCH row says none. | L | NOT FIXED (by design, not a render bug). To remove it: leave `watch` / `watchTop` out of the near-sleeve cover set for the long-sleeved shirts (line ~139) and draw `r_near` above `Watch` in the reference builder, rebuild the clothes sheets and the three golden refs; a chosen watch accessory still draws over the sleeve. |
| 10 | Escape room HUD (h, deck, wide) | A medal toast (`MEDAL EARNED: ...`) is drawn over the room's hint caption when a medal lands as the next game starts. | L | NOT FIXED (HUD, the other QA agent's area). |
| 11 | Dinner in h | The HUD strip covers the lower half of the guest's briefcase on the floor (fully visible in deck and v). | L | not changed |
| 12 | Creator: lanyard and HELLO sticker together | The sticker sits on the lanyard's badge, so the badge is hidden when both are worn. | L | not changed |
| 13 | Main floor decor at full growth | The fish tank touches the lamp shade, and the XP countdown poster hangs directly on top of the tank (1 px apart). Crowded, still readable. | L | not changed |
| 14 | Breakout B and D, back row | The right back-row sitter is in the open (no front-row chair before him), so his legs cross the catering table / lab table edge. Reads as sitting behind it. | L | not changed |
| 15 | Resort lobby, vendor hall | The crowd stands shoulder to shoulder at 12 to 14 px spacing (Walt between Ray and Grizzle, Dot at the WebWoot booth). | L | not changed |
| 16 | Night paintball | The cover pieces are dark navy on a navy street: readable by their outline and the trough's water line, the hay bale is the weakest. The tinted actors and the lit windows read well. | L | not changed (taste) |
| 17 | Duel HUD | The P1 / P2 tags are empty coloured frames (no letter inside): they read as legend swatches. | L | not changed |

## Looked at and found fine

- Breakout rooms A to D: everyone sits on a chair, the back row shows heads and shoulders above the front row (y-sort correct), the
  speaker is in full view at the front, the player takes a free chair, nothing floats.
- Escape room, four themes, with the crew and alone, with and without the HUD: props on the floor line, the vault, keypad, timer, wall
  clock and the `?` plaque visible in every theme.
- Western street: cover (crates, barrels, hay, trough, wagon: warm brown, outlined, in the lanes) is distinct from the dressing (store,
  church, windmill, posts: behind the boardwalk line); cacti are props between the two.
- Quinn seated at the conference table and walking the floor (the buns read), Ross Calder, Terry Vance, WSUS_Walt, TapeTony.
- Decor: rug, plant, certificate, tank, shelf with one and three trophies, neon; holiday lights, tax boxes, XP poster, drive box.
- Restaurant with a guest: place setting at the end of the second table, the plates, the briefcase. Warehouse: the fight ring (brackets,
  dashes, centre spot), the gauntlet's checkered finish sprite, the straight course's finish. Jen's headset on its stand. The Dispatch star.
- Hats: all six on side-swept, long and bald hair, both facings, idle / walk / sit / type / last death frame; the party hat and the hard
  hat left-facing (the lamp and the bill point the facing way, the cone is centred); on the floor and in the creator's mirror. Lanyard,
  sticker, the three watches.
- Phone camera app (finder), pad glyphs in the HUD hint, in a card body and option, and the duel's key lights.

## Fixes by file

- `scripts/cards.gd`, `scripts/outings.gd`, `scripts/yeartwo.gd`: texture caches (1); `outings.gd`: three ink colours (6).
- `scripts/paintball_track.gd`: `PORCH_Y`, `TAG_UP` (3, 4). `scripts/world.gd`: staff stay out of outings (2).
- `tools/make_fem.lua` `STYLES.curly` (5), `tools/venue_sets.lua` chair order (7). All script edits went through `tools/port_edit.py`.

## Decisions made

- The office staff do not attend outings (the code comment on `STAFF_CAST` already says the games never see them).
- Watchers at paintball stand on the boardwalk at one y, not in the street.
- The board readability is fixed with ink colours, not by repainting the three sets.
- The wrist band is reported, not removed (it is the intern's watch and a deliberate cut-out).
