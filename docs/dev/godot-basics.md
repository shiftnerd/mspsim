# Godot basics

(Moved verbatim from CLAUDE.md. Headings below keep their original levels.)


## Godot (`godot/`)
- Godot 4 project, 368x128 viewport shown at 4x (integer scaling, nearest filtering, pixel snap).
  Godot can't read `.aseprite`, so `godot/assets/` holds exported PNGs (the one place PNGs are expected):
  `assets/characters/<name>_<facing>.png` = horizontal sheet of the 129 `_anim` frames (64x80 each),
  `assets/sets/<set>.png` = the set with its `CharacterTest` layer hidden.
- `tools/make_godot.py` regenerates `project.godot`, `characters/*.tres` (SpriteFrames, every animation x 2
  facings, per-frame timing from the Aseprite durations), `scenes/*.tscn` and `scripts/*.gd`. Re-export the
  PNGs from Aseprite first when art changes. **Generator rule: never run `make_godot.py` in the real tree** (the committed scripts carry hand edits ported back into it); wherever a note says to run it, run it in a scratch copy with `python -I tools/check_generator.py --keep --scratch DIR` and copy over only the files you meant to change (see "Test runner and generator check"). `crouch` = frame 19, `jump` = frames 20-22
  (picked by vertical speed), the rest follow the tags.
- Controls: A/D or arrows, Shift run, Space jump, E use door / sit / stand. H hurt, K die, R revive and 1-7 switch character
  (`Player.CHARACTERS`; only outside a campaign; any time, even mid-animation: `_switch_character` keeps the running
  animation). Floor line is y=118; each set is centred in the viewport with walls.
  F9 cycles the output format (all builds); F10 toggles the clock. Debug builds only (`stage.gd`): F1-F8 jump to main floor, Office 1,
  Office 2, conference, kitchenette, bathroom 1 (Shift+F6 bathroom 2), cubicle area, network closet; F11 / F12 (with Shift, Ctrl or Alt)
  jump to the outing rooms, client sites, the venue and the warehouse.
  Doors: main floor doors -> Office 1 / Office 2 (each returns to its own spawn), kitchenette left/right bath doors -> two
  single-occupancy bathrooms (`bathroom_1` / `bathroom_2`; a door is locked while somebody is inside), main floor left
  edge -> kitchenette, right edge -> cubicle area (cubicles 3/4, copier, cooler, whiteboard), whose right
  edge -> conference (its left edge -> cubicle area, its door -> main floor). The glass front door at the end of the hallway
  goes to the client sites (see "The front door goes to the client sites"). A locked door's arrow turns red and shakes
  (`locked = true` on a door). Fade between scenes is in the `Game` autoload.
  Tests in `godot/tests/`: smoke, seats, extras (switching character / sit again), doors, edges (every
  edge exit both ways).
- Depth: `tools/build_sets.lua` (needs `tools/lib.lua`) builds every set twice: the full `.aseprite` and a
  Godot export = background PNG + one PNG per y-sorted prop + `<set>_props.json` placements. Props sort by
  their base y against the player's feet y, so a seated player (feet y 97 / 89) sits between the chair (95 /
  88) and the desk (108). Godot 2D sorts by the node's own y (there is no `y_sort_origin` on sprites), so
  the generator puts each prop's node on its sort line and shifts the art up with `offset`. Check depth by
  zooming real frames (`--write-movie`), not at 1x: it is easy to misread. Edit `build_sets.lua`, run it, then `make_godot.py`. Seats/doors/spawns are listed
  at the top of `make_godot.py` (`SETS`).
- Godot 4.7.2 lives at `C:\Program Files\Godot\Godot.exe` (the path the godot MCP expects). Test headless:
  `Godot.exe --headless --fixed-fps 60 --path godot -s res://tests/smoke.gd` (loads every character and set, simulates walk/run/jump/land/hurt/die/revive, sitting, doors and edge exits, logs state changes).
  `tests/seats.gd` sits the player in the seats, then stands them up (E, or a move key at cubicle 1) and
  checks idle / same scene / on the floor at the chair / collision back on (run it with `--write-movie`
  and zoom the frames to check depth).
  Re-import after new art: `Godot.exe --headless --path godot --import`. To grab frames:
  `--write-movie out.png --quit-after 30` (without `--headless`). Lint: `gdlint scripts tests` and
  `gdformat --check scripts tests` from `godot/` (pip install gdtoolkit; lint misses type errors, so
  also load every scene). Interaction picks the nearest door/seat by x (`player.nearest()`), because
  zones overlap (cubicle 1 sits under the Office 2 door).

### Ambient motion + interactive props (`scripts/fx.gd`, `interact.gd`)
- `fx.gd` draws procedural effects over the art (art-local coords, 12 fps steps): `monitor` (live screen, scrolls faster while the player sits nearby), `tv` (spreadsheet/bars/news, auto-cycles, static between), `coffee`, `copier`, `cooler`, `sink`, `toilet`. `interact.gd` is an Area2D (E key, joins the nearest-wins rule) that calls `play()` on its `target` fx; arrow hides/shakes while busy.
- Config lives in `tools/make_godot.py`: `PIECE_W` (props that get an fx child + interact zone) and `BGFX` (effects on background art: name, kind, art_x, art_y, interact_x). Monitors get an fx automatically.
- Test: `tests/fx.gd` (use with `--write-movie` for frames).

### Characters interacting (`npc.gd`, `bubble.gd`)
- Animations `reach` 43-45 (one-shot, far arm out), `wave` 46-49 (loop), `talk` 50-53 (loop) in `tools/poses.lua`.
- Player: using a prop plays `reach` (state `use`); Q waves; E on an NPC starts a chat (state `emote`, `start_emote(anim, secs, toward_x, glyph)`) with alternating speech-bubble icons (`dots ! ? heart`).
- NPCs (`scenes/npc.tscn`, Area2D) loop a routine of string steps: `walk:X wait:S say:S talk:S use:prop sit:Seat stand sync:key:n`;
  `start_seat` seats them at spawn. They wave when the player nears, E chats (only while standing). The cast and their agendas are in
  `world.gd` (see "Persistent cast"). `sync` is a barrier so pairs meet and talk together. Seats have `occupied`
  (player can't take an NPC's seat). Tests: `tests/world.gd`, `tests/chat.gd`.
- After re-exporting any PNG (sheets, sets, props) Godot must re-import it or the game keeps showing the old cached
  texture (new sheet frames render blank/invisible). `tools/make_godot.py` runs `Godot --headless --path godot --import`
  at the end; run that yourself if you export PNGs without regenerating.

### Seated life (R26: `scripts/seat_life.gd`, `npc.gd` `_update_gesture`, `player.gd` `_gesture_tick`, test `tests/gestures.gd`)
- People in chairs are never frozen: `sit` breathes, and every 5 to 18 s of seated idle time (typing counts) the person plays ONE gesture
  (`sitstretch sitscratch sitlook sityawn sitslump sitmouse sitphone sitnod`, or `sip` = the existing `sitsip`) and goes back to `type` /
  `sit`. `SeatLife` (a `RefCounted`) only decides when and which: a stream from `Difficulty.rng_for("gesture", day * 1009 + name hash)`
  (deterministic per person per day, day 0 outside a campaign), `tick(delta, ready)` counts the gap, `pick(typing, held, cup)` chooses by
  weight (`BASE`, `PERSONALITY`: Alan sips, Garrison stretches and slumps, Dan scratches / fixes his glasses, Vic checks his phone, Maya
  drums the mouse and looks around; clients' staff use `BASE`; `CHARACTER_KEY` maps player character ids to the same personalities).
  `sitmouse` needs a desk (`seat.typing`), `sitnod` only away from desks (meetings, lunch, couches, booths, bench seats), `sip` only with a drink.
- Never: during a call (`_call_stage`), a chat or talk (`_hold`), an outage grumble (`_offline`, `_grumble_t`, `flag_glyph`), a speech bubble,
  `Game.busy`, lights out in the room, a rolled chair (player), `Game.ui_open` (the player's `_physics_process` returns first, so the gap
  does not run). With a drink (`held != ""`) only the head gestures (`sitlook`, `sitnod`) and the sip. In a non-desk seat while somebody
  standing is talking (`_speaker_talking`: a `talk` state or a hold over 2 s) the pick is `pick_listen()`: look at them (55 percent) or nod.
- Gestures are non-looping SpriteFrames animations: `animation_finished` ends them (`_end_gesture`: sip accounting, phone item cleared, back
  to `_rest_anim()`); any `_play` call cancels one (`_cancel_gesture`), `chair_roll._pose` leaves a gesture alone. The player's sip is still
  his own F key (no automatic sips for the player).

### Seating geometry + held items
- **Seated geometry (the body is RAISED over bent legs; `seat()` in `tools/poses.lua`, shared by sit / type / sitsip / sitcall / the R26 gestures and
  the lounge seats)**: the feet stay on row 79. The thigh runs forward and level (`lN` 90, far leg 88), the knee is at the thigh's front end
  (`kn = 55`) and the shin drops straight down (`lNr = -lN`, shoe flat), the calf is stretched by `shin = 4` rows (`stretchShin` in `tools/anim.lua`
  repeats pants row 55 and drops the shoes) so a shin shows under a thigh band that is itself 5 rows thick. Everything above the legs (pelvis, belt,
  torso, head, both arms) is lifted by `lift = 6` px against the feet (`bobDy - lift`), so the pelvis / seat bottom is row 71-72 (it was 77-78: the
  old sit was on the floor), thigh rows 67-71, knee row ~72, shin rows 72-74 and shoe rows 75-79; the head top is row 26 (was 32). `floor = true` puts
  each leg's own sole on row 79 whatever the knee height; `legDy` / `lNx` / `lFx` / `legDx` shape the hips. `legRef` is the OLD leg setup the ground is
  measured with (and `legsG`, the un-stretched legs), so the root row is unchanged and only `lift` moves the body.
  **Arms keep their hands on the desk**: `keepN` / `keepF` (default true in `seat()`) re-solve the arm angles (`aN`/`aNr`, `aF`/`aFr`, a small brute-force
  search in `E.render`) so the hand tip lands on the pixel the un-lifted pose gave it (keys, mouse, cup), `leanAdd = 2` leans the sitter toward the desk
  (ignored by that target) and `armLen = 2` stretches the forearm two rows (a raised shoulder otherwise cannot reach). The poses where the hand goes to
  the head (sitstretch, sitscratch, sityawn, sitphone, sitcall, the sip's middle frame) set `keepN = false` (`keepF = false` too for the stretch): the
  hand is lifted with the head. The hands json therefore moved by 0 to 1 px for typing and by the lift for the gestures. Test `tests/seated_legs.gd`.
  The clothes sheets, the head / accessory sheets (their golden refs hold the legs and the head rows), the head origin tables and every anim were
  rebuilt; `Look.HEMS` did not change (seated frames are 79 = trousers stay).
- **Chair** (`P.chairSide`, art 18x35, PNG 20x37: `L.piece` adds a 1 px outline all round): drawn to read as a real task chair, not a slab. Art row 28
  is the seat top = frame row 72, right under the thighs; the art goes at `feet_y - 35` (desk chairs y 66 for feet y 101, conference and karaoke 54
  for 89, venue 60 / 64). Parts: a 5 px wide backrest (rows 0-24: dark outline, a lighter highlight edge, two body tones, leaning back at the top
  and bulging forward at the lumbar, rising above the shoulder blades), a post into the seat, a 3 row cushion with a LIGHT top edge
  (`lighter(hi, 34)`) and a shadowed underside with the plate, a short chrome gas lift (2 rows, `#B8BEC9` / `#7C8290`), and a flat star base ellipse
  with round casters. The casters stand on the sitter's sole row and hang 1 px below it (they were 3 px under: "the feet look high"; squeezing them
  ABOVE the soles made the first, black-slab chair). Colours stay per room (`P.chairSide(base, hi, sh)`: desk grey, conference grey, karaoke
  purple, gold, wood, velvet, blue, brown, exec). No armrest (hidden behind the sitter). Scene offsets are `y - sort_y` as always (from the
  `*_props.json`); `chair_roll.gd` only uses the width. `tests/side_chairs.gd` checks the 37 px PNG and the soles / seat row.
- **Tables hide the lap**: with the sitters raised the table top has to be at belly height, `feet_y - 18` like the desks (desk top 83 for feet 101).
  `P.confTableWide`, `P.roundTable` (karaoke) and `P.woodTable` (restaurant booths) are 7 px taller (conference 220x37, round 42x37, wood 52x35),
  put at lua y 71 (feet 89), so the legs / base still end at the old floor line. The seated cup rests on them: `cup_y` 74 (was 80) for the conference,
  karaoke and restaurant seats (`CUP_Y` in `make_godot.py`, per scene; ballroom and breakout seats have no table and keep 80). The conference FRONT
  row chairs (facing left, sorted in front of the table, no seat) are pushed in: art y 77, so the backrest starts under the table edge and the base
  is a little nearer the camera than the table legs. Bar counters (top 69 for feet 101), the bowling bench and the lounge / couch seats were already
  fine (the counter is above the waist, the others have no table).
- Older geometry (history): before the lift the seated poses used `kn = 60`, hips about 19 px under the standing hips and the pelvis block on rows 71-78
  (sitting on the floor); chair art was 18x33 (seat top 15 px above the wheels), desk chairs sit at y=66, seat feet y=101, sitter at the desk's LEFT end
  (seat = desk_left+12), keyboard seat+12, monitor seat+18.
- Poses 54-66: `hold` (54-55), `walkhold` (56-63), `sip` (64-66): near forearm up. `E.render` also returns the near
  hand position per frame; `tools/build_anims.lua` (run via `dofile`) rebuilds all anim files, sheets and
  `<name>_<facing>_hands.json`. Run it, then `build_sets.lua`; the scripts and scenes are hand-edited in lockstep with `make_godot.py` (never rerun it in a real tree, `python -I tools/check_generator.py` checks them).
- Items: `scripts/held_item.gd` follows the hand of the current sheet frame. Coffee machine -> `coffee`, cooler -> `water`
  (`fx.item`, given when the effect finishes). Player: F sips (3 sips empties it), item persists across rooms
  (`Game.vars held/sips`). NPC steps `sip` and `drop`. Test: `tests/items.gd`.
- Seated with a cup: it stands on the desk (`scripts/desk_cup.gd`, sorted just in front of the desk at y=109, x = seat+48);
  `sitsip` (frames 67-69) brings it to the mouth; standing picks it up. Seated cups last 6 sips, standing ones 3.
  Sip cup tilt is code (`held_item.gd`: 30/112/45 deg, rim ends up pointing down at the lips). NPC steps: `sip` works
  seated or standing; the cast data (`world_data.gd`) and the room events give an NPC a starting cup. Tests: `tests/deskcup.gd`.
  Seats export `cup_dx`/`cup_y` (where a seated cup stands): desks use 48/84, conference seats (non-typing) 14/80 (on the table).
  Conference Dan/Alan start with cups. Test: `tests/confcup.gd`.

### Desk phone (piece)
- `office/pieces/desk_phone.aseprite` (14x13 incl. outline pad, 12x11 content, about half a monitor's width), layers bottom to top: `Cord`, `Body`, `Handset`.
  2012 VoIP style (Avaya-ish): charcoal body, green LCD, line keys, softkeys, nav cluster, keypad, red LED, coiled cord.
  Handset is its own layer so it can lift off when the phone becomes interactive. Source: `P.deskPhoneParts()` /
  `P.deskPhone()` in `tools/lib.lua`; rebuild with `tools/build_desk_phone.lua`. Palette is the `PH` table in lib.lua.

### Multi-angle pieces (`tools/build_angles.lua`)
- Convention: a piece file in `office/pieces/` has one frame per angle, tagged `front` (direct on, what the sets use) and
  `side` (profile facing RIGHT; mirror for left). Frames are bottom-centre aligned on the largest canvas; layers are shared by
  name (desk phone keeps `Cord` / `Body` / `Handset` in both angles). More angles (`back`, `three-quarter`) = more frames/tags.
- Every piece in `tools/lib.lua` now has a `side` frame: builders are `P.*Side` in `lib.lua` (desk phone, desks, bookshelf, monitor,
  keyboard, chair) and `tools/side_views.lua` (everything else). `tools/build_angles.lua` rebuilds all piece files (new files:
  copier, cooler, toilet, bath_sink, mirror, plant_floor, whiteboard). Wall items are thin edge-on slabs, doors are a slab + knob/handle.
- Chairs are the exception: every chair someone sits in uses the `side` frame (`P.chairSide`: backrest at the back, cushioned seat, gas lift,
  five-star base). **It is 18x35 with a readable cushion, chrome lift and star base** (see "Seated geometry": seat top 7 px above the floor, casters 1 px below the soles, art at `feet_y - 35`; the desk chairs are y 66, conference and karaoke 54, venue 60 / 64; `cup_dx` and the chair roll are unchanged). Left-facing
  seats mirror it with `L.flipH` (pieces `*_side_l`; only the conference FRONT row uses it, the sitters all face right). Pieces are named
  `chair_office_side`, `chair_office_brown_side`, `chair_exec_side`, `chair_conference_side[_l]`, `chair_karaoke_side`, `chair_gold_side`,
  `chair_wood_side`, `chair_velvet_side`, `chair_blue_side` (the old front PNGs are gone except `chair_office.png`, which the chair race
  puppets still draw). Placement rule: chair left edge = seat x - 15 (desk chairs, what `chair_roll.gd` `SEAT_DX` expects) or about seat x - 14
  for the other rooms, so the backrest stands right behind the sitter's back. Test `tests/side_chairs.gd` checks every non-lounge seat in a room
  with chairs has one; screenshots with `tests/seat_chair_shots.gd` (`SC_TAG`, `SC_ONLY` env, `-- --format=wide|h|v`, renderer needed).
  Lounge seats are side-on too: `P.loungeSide(base, hi, sh)` (24x33, side_views.lua; `P.couchSide` is its teal version) is ONE seat per piece, so the two-seat front couches (Office 2, resort lobby) and the bowling bench are now two side-view seats each (pieces `couch_side` teal and `bench_seat_side` red; the front `couch.png` / `bench_seat.png` props are gone). Art at `seat_x - 13`, `seat_y - 32`, seats 26 px apart, all facing right like every seat. Still front-view on purpose: booth backs (a banquette along the wall behind the table), bar stools (a round top is the same from every side), and the Office 1 slipper armchair is already a side view. Client site waiting chairs and the owner-office sofa have no seat nodes (nobody sits there). `tests/side_chairs.gd` checks every lounge seat has a side piece or a stool behind it and no scene uses the front couch / bench.

### Taller sets: ceiling + floor extension (for 16:9 and 9:16 video)
- Set backgrounds are now **W x 320** (100 ceiling + the old 128 + 92 floor extension). Builders keep their old 0..128
  coordinates: `L.YOFF` (= `L.CEIL_H` 100) is added by `put`, `L.wall/carpet/tiles`. `build_sets.lua` then draws `L.ceiling`.
  Prop JSON y values stay relative to the old art; in Godot the Background sprite sits at y = -`SET_TOP` (100), so every
  Godot coordinate (FLOOR_Y 118, spawns, doors, seats) is unchanged and the 368x128 viewport still shows the same picture.
- Ceiling (`L.ceiling`): old yellowed 2x2 ft acoustic tiles with pinholes and water stains, white T-bar grid, 2x4 ft fluorescent
  troffers (one tube dying per room), sprinkler heads, wall angle strip at the wall line. Seeds per set in `build_sets.lua`.
- Floor: **blue low-pile carpet** (`#3E5E8E`, speckle, 2 ft carpet-tile seams) in main floor, cubicles, offices, conference;
  kitchenette and the bathrooms keep their tile floor (extended). Carpet/tiles now run to the bottom of the taller canvas.
- Formats: 16:9 = 320x180 (6x -> 1080p), 9:16 = 180x320 (6x -> 1920 tall). `tests/format.gd` renders every set in both with a
  `Camera2D` + `root.content_scale_size` (needs a renderer, not headless) and saves PNGs to `user://`.
- Narrow rooms: any set narrower than `L.MIN_W` (320) is built on a 320-wide canvas. `L.XOFF` = (320 - W) // 2 is added by
  `put`; wall/carpet/tiles/ceiling span the full canvas width; `L.margins` then darkens the two margins (x0.55) and draws a
  3px dark cutaway edge at the real room boundary, so the margins read as "off stage". Margins: bathrooms 96, conference 64,
  offices/kitchenette 72, cubicles 16 (each side). Godot shifts the Background sprite left by that margin (`MIN_W` in
  `make_godot.py`); room coordinates, props, walls and spawns are unchanged.

### Output formats + follow camera (`Game.format`, `tools/render_video.py`)
- Formats live in `Game.FORMATS` (`scripts/game.gd`): `wide` 368x128 (the original, static camera), `h` 320x180 (16:9, x6 = 1920x1080),
  `v` 180x320 (9:16, x6 = 1080x1920, whole set height: ceiling on top, floor below), `vclose` 180x320 with a 2x camera zoom
  (about 90x160 of the set, characters twice as big). Each has `size`, `zoom`, `cam_y` (world y the camera centres on), a default
  window `scale` and `follow`.
- Choose it with `-- --format=h` after the Godot args (or env `PIXEL_FORMAT`); F9 cycles formats while playing. `stage.gd` runs a
  `Camera2D` that follows the player's x (smoothed), limited to the background art bounds (including the off-stage margins) so it never
  shows nothing. Format `wide` leaves the camera fixed, exactly like before. The fade ColorRect now fills any viewport.
- Video: Godot's movie writer records at the PROJECT viewport size, so use `python tools/render_video.py --format h --seconds 10 --name x`
  (or `--script res://tests/followcam.gd`): it writes a temporary `godot/override.cfg` with the viewport size, records PNGs to
  `renders/<name>/`, upscales by whole numbers with `--upscale 6` (nearest) and encodes an mp4 if ffmpeg is on PATH (it is not on this
  machine: import the PNG sequence into Shotcut or install ffmpeg). Tests: `tests/followcam.gd`, `tests/format.gd`.

### Two offices + the hallway (main floor)
- **Office 1** (`office_one`, pale green walls, bookshelf + plant, green slipper armchair, two framed
  pictures, wall clock, desk 68, seat x80) and **Office 2** (`office_two`, tan walls, teal couch, whiteboard, filing cabinet, floor plant,
  framed picture, clock, desk 64 at x96, seat x108). Each main-floor door goes to its own room and its door returns to the right
  spawn (`from_office1` / `from_office2`).
  New pieces (front + side in `build_angles.lua`): filing_cabinet, couch, picture_frame, wall_clock. Easy next variations: wall colour
  (`L.wall` base), which props, seat position in `SETS`.
- The glass front door is not on the wall: `L.hallway` (lib.lua) cuts a trimmed opening in the main wall (x 6-76) and draws a
  one-point-perspective green hallway (darker side walls, old-ceiling plane, dark carpet floor) with a small glass door (26x40) and an
  EXIT sign on the far wall. The locked door's interaction zone is at x=43.

### Fridge (kitchenette)
- `fx.gd` kind `fridge` (background art at set (46,30)): the lower door swings out to the left, the interior lights up (shelves with a
  bottle, milk, jar, three soda cans, lunch bag, yogurt, crisper drawer) and light spills on the floor; one random drink (`soda` can or
  `bottle`) is handed over 1.5 s in (`HAND_AT`, signal `handed`) and leaves the shelf; the door closes at 3.2 s.
- The zone sits to the RIGHT of the fridge (set x78) so you stand beside it and the open door stays visible; `look_x` on the
  interact zone (set x59, from the 6th BGFX field) makes players/NPCs face the fridge when they reach. Alan's kitchenette routine
  visits the fridge between coffee refills. Held items `soda` and `bottle` (held_item.gd + desk_cup.gd). Test: `tests/fridge.gd`.
- Interact zones can hand over an item mid-effect (`fx.handed`); other machines hand over at the end.

### Sittable lounge furniture, wider desks, desk phones (headset)
- Office 1's armchair is now the SIDE view (`chair_slipper_green_side`, 22x32, seat 19 px off the floor like the desk chairs) so the
  sitter faces the same way as the chair; Office 2 has two teal side-view lounge seats (art x 36 and 62, seats at set x 49 and 75). Lounge seats are `(x, y, False, True)`
  in `SETS` (4th item = lounge): `stash = false` so a cup stays in the hand, `sit` pose, relaxed arms. Furniture sorts at y 99, the
  sitter at 101. This is the first use of a per-prop angle: pass the side image and a `_side` piece name to `putS`.
- Every desk is `desk_cubicle_74` wide so a phone fits (the desk top carries TWO monitors, see "Dual monitors on every desk"). Seated cups
  stand at seat+35 (`cup_dx` default). Office 2's desk is at x88 (seat x100) with the filing cabinet at x162.
- Fridge: its arrow is above the fridge (BGFX 7th field = arrow y; x comes from the look target).
- **Desk phone** (`fx.gd` kind `desk_phone`, prop `desk_phone` = cord + body, handset is `desk_phone_handset.png` drawn by the fx):
  it rings now and then (12 s, LCD flashes, LED blinks, handset jitters, ring marks), and E answers it standing, or seated while it
  is ringing (the seat can reach phones within 80 px; E otherwise stands up). Nobody lifts the handset: people use a **wireless
  headset**. `call`/`sitcall` (frames 70-73) are the ear tap; then `held_item.gd` in `mode = "ear"` draws the earpiece + mic boom at the
  per-frame ear position (hands.json has `[hand x, hand y, ear x, ear y]`). While talking (9 s) you can walk, or keep typing
  seated; bubbles alternate; another tap takes it off. The phone LCD shows a running timer meanwhile. Test: `tests/phone.gd`.
- NPCs answer too: a seated NPC (state `wait`, no hold) whose desk phone (group `phones`, within 70 px of the seat) is ringing taps their ear (`sitcall`,
  0.7 s, routine paused), puts on the headset (`_head_item`), keeps typing while a bubble alternates for 9 s, taps it off and resumes the routine
  (`npc.gd _update_call`). Standing NPCs do not take calls. Tests: `tests/npcphone.gd`.

### Dual monitors on every desk (roadmap R25; `P.dualTop` in `tools/lib.lua`, pieces `monitor_a` / `monitor_b` / `mouse`, `fx.gd` `panel`, test `tests/dualmon.gd`)
- **Layout** (D = the desk's put x, desk still `desk_cubicle_74`, 74 px; seat = D+12): monitor A (older 4:3 19-inch panel, 18x18 content, put D+21 y 65, `monitor_a`), monitor B (slim 16:9 flat panel, 22x17, put D+40 y 66, `monitor_b`; the two share one outline column), keyboard put D+28 y 80 (hands reach it), mouse put D+51 y 81 (`mouse`, 4x2, past the seated cup at seat+35 = D+47), desk phone put D+62 y 72 (flush with the desk's right end; the NPC phone-ownership zone 20-70 px from the seat is unchanged). Seats, `cup_dx`, chair roll and the cubicle shells are untouched. `P.dualTop(s, layer, D, phone)` places all of it; the desk sets (main floor open desk and cubicles, cubicle area, Office 1, Office 2) and the realty / trailer staff desks call it. Art: `P.monitorA/monitorB/mouse`, side frames in `build_angles.lua` (`monitor_a` side = `P.monitorASide`, `monitor_b` side = `P.monitorSide`).
- **Interaction unchanged**: only A has an interact zone (`PIECE_W["monitor_a"] = 20`, group `computers`, so E standing and `Player._seat_computer()` seated still open the SAME `Computer.open(desk)`); B is in `PIECE_W` (it gets an fx child) but `make_godot.py` skips its zone, so it can never steal E. Both are `monitor` fx (`panel = 1` for A, `2` for B via `MON_PANEL`) and share the desk's patch-panel number (`desk_line`), so `Net.desk_state` puts the red X / yellow triangle on BOTH screens, and both scroll faster while a sitter is near. `fx.gd` `_draw_panel` draws the new screens (`PANELS` rects): A = ticket list / mail rows with coloured tags (a bar chart now and then), B = RMM bar chart (a tree of indented lines now and then); the content cycle is offset per panel so the two never show the same frame. The lone `monitor` piece (24x21, `panel` 0) is unchanged.
- **Not changed (one monitor kept)**: client-site reception counters (dental, law, vet), the architects' front desk (`recep_desk_*` + `RecepPC` / `Mon`: a PC on a counter beside the `onsite_pc` zone) and the owner / VIP executive desks (`exec_desk_*`, a different desk art and the `onsite_vip` zone). The conference room has no desk PC; the kitchenette has no monitors.
- Test `tests/dualmon.gd`: every `desk_cubicle_74` has exactly one A and one B, A has the only zone (group `computers`), both share the desk's network state. `tests/dualmon_shots.gd` (renderer) saves screenshots. `tests/nerf.gd` fires its "you can get hit too" dart from 10 px (the phone catches a 20 px dart).

### Dancing + phone ownership
- **Dance** (player only, NPCs never dance): `dance` animation = frames 74-85 (the seated gestures are 86-123, the toss 124-129; 129 frames per sheet), a 12-frame loop of two phrases in
  `tools/poses.lua`: point-and-bounce (far arm up, near arm swinging back, knee bobs, head tilts) then a side shuffle with pumping
  forearms and a small hop. **X** starts it from the ground (`state = "dance"`, `Player._start_dance`), a music-note bubble (`note` glyph
  in `bubble.gd`) blinks above the head, and X again / any move / jump / E stops it. Cups and headsets follow the hand/ear as usual.
  Test: `tests/dance.gd`. Tweak the moves in `poses.lua` (`dn{...}` rows) and rebuild with `tools/build_anims.lua`.
- **Phone ownership**: a desk phone belongs to the seat to its LEFT (phone zone 20-70 px right of the seat); both the player (`_ringing_phone`) and NPCs use
  that rule. Test: `tests/npcphone.gd` rings the neighbour (ignored) then Dan's own (answered).
