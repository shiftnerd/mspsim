# Pixel character project

Cartoon pixel-art characters in Aseprite (via the aseprite MCP), inspired by the
look of Code Monkeys. Characters are caricatured, not exact copies of people.

## Deliverables
- **Deliver `.aseprite` files by default.** Do not export PNGs or GIFs unless asked.
  Viewing previews through `view_sprite` for my own checking is fine; do not save
  preview PNGs into this folder (use `output_filename` only when asked).
- Primary outfit going forward is the **office** version (blue polo). The
  SkillsUSA version (white polo, medal, ribbon, nametag, logo) is secondary.
- Keep every item on its own layer so it can be toggled or recolored.

## Style (Code Monkeys inspired)
- Low resolution: canvas **40x64** for a full-body character.
- **Big head** (~18px wide, about a third of body height), chunky blocky body.
- Big eye whites with the pupils pushed to one side (2px wide, dark brown), flat
  brows. Skeptical or deadpan expression.
- Flat colors, almost no shading (one shade color per material, light from top-left).
- **1px dark outline `#17121F`** on every layer via `outline_cel` (sides only, no
  diagonals). Run `outline_cel` once per layer. Running it twice makes a 2px outline.
- **Flat cheek**: the front edge of the face is one straight vertical line. No nose
  bump on the silhouette. The nose is a small darker patch inside the face.

## Orientation (left / right)
- Characters face the **camera, turned to one side** (three-quarter view). Not a
  profile and not a side-on walk.
- Head: both eyes visible, shifted toward the facing side. Near eye 5px wide, far
  eye 4px. Flat front edge, ear on the back side, hair swept back with the fringe
  forward.
- Torso faces the camera: chest visible, V-neck collar and button placket both
  shifted slightly toward the facing side.
- Both arms hang at the sides. Near arm is full width on the back side. Far arm is
  darker, narrower, partly tucked, on the facing side.
- Standing stance, legs side by side with a small gap. Far leg is darker.
- Shoes: toes point toward the facing side (toe extends ~3px past the leg).
- **Left-facing = mirror of right-facing.** Build the right-facing file, then copy
  it (`copy_sprite`, overwrite) and mirror every layer around the canvas center.
  Never hand-draw the left version.
- **Do not use `flip_layer` for the mirror.** Some cels are full-canvas (made with
  `draw_rows`) but others are only as big as their shape (made with
  `draw_rectangle_at`, e.g. Belt and Watch). `flip_layer` flips those inside their
  own box, so they stay put or end up 1px off. Use `run_lua_script` on the copied
  file instead: for each layer, flip the cel image and set
  `cel.position.x = spriteWidth - oldX - celWidth`, then `saveAs`.
- After mirroring, check Belt and Watch (zoom `region` around y30-46).
- **Watch exception:** the watch is on the arm at the **viewer's left in both
  files**, so it is not a pure mirror. Right-facing: on the near (full-width) arm,
  `Watch` cel at x10, y38, 4x2. Left-facing: on the far (darker) arm, `Watch` cel
  at x9, y38, 3x2. After regenerating the left from the right, redraw the left
  `Watch` layer at x9 (`clear_cel`, then `draw_rectangle_at`).
- Mirroring swaps sides of side-specific details (placket, watch). That is expected.

## Layers (bottom to top)
Shoes, Pants, Back Arm, Body, Shirt, Belt, Collar, Near Arm, Watch, Face, Hair.
SkillsUSA-only extras (Ribbon, Medal, Nametag, Shirt Logo) go above Collar and
are hidden in the office version.
- `Body` holds head, neck, ears, and hidden torso skin so removing the shirt works.
- `Collar` holds the V-neck skin, collar flaps, placket and buttons.
- `Face` holds brows, eyes, nose patch, mouth and ear shading.

## Characters
Each character is a pair of files (`_right` is the source, `_left` is derived).
New characters start as a copy of an existing one, then change only what differs.

- **office teen** (`office_teen_*`): teenage me. Blue polo, long auburn side-swept
  hair, no beard, brown shoes. Reference photo: `archive/teenme.png`.
- **office adult** (`office_adult_*`): adult me. Copied from office teen, with:
  - maroon polo (`#8C2B40`, shade `#6A1E31`) with gray placket (`#9AA0A8`) and dark
    maroon buttons (`#4A1020`)
  - short, receding hair (`#74492A`, highlight `#B07A44`), about 5 rows above the
    forehead on the front side
  - beard on its own `Beard` layer (`#A8743F`), lighter than the hair so they read
    as separate shapes: sideburn gap around the ear, jaw, and chin, with the mouth
    area left clear
  - gray shoes (near `#8A8F9A`, far `#6A6F7A`)
  - pants kept navy and body build kept the same as the teen (the photo shows
    jeans and a stockier build; change only if asked)
  - Reference photo: `archive/me_now.jpg`.
  - `Beard` layer sits above `Hair` in the stack (top layer).

- **office Dan** (`office_dan_*`): Dan. Copied from office teen, with:
  - cobalt blue long-sleeve button-down (`#3C55C0`, shade `#2C3F96`), full placket
    with pearl buttons (`#DDE3F5`) down to the belt, collar open to a white
    undershirt (`#EDEDED`). Long sleeves go to the wrist (no short sleeves, no
    watch); the arm layers are redrawn with the sleeve color down to y39, then a
    darker cuff, then the hand.
  - short dark brown hair (`#4A3222`, highlight `#6B4B34`), fuller front hairline
    than the adult (forehead 3 rows)
  - thin dark rectangular glasses (`#1E1E26`) on their own `Glasses` layer (top of
    the stack). Brows move up to y10 (`#3A2A1E`) so they sit above the frames.
  - brown chino pants (`#8A6A42`, far leg `#6F5434`, shade `#5A4328`)
  - black shoes (near `#3A3A44`, far `#2A2A33`)
  - no beard, no watch. Reference photo: `archive/djones-headshot-340x340.jpg`.
  - Watch exception above does not apply (no watch).

- **office Alan** (`office_alan_*`): Alan in his casual office wear (red long-sleeve
  shirt with a vest). Copied from site Alan, with:
  - red long-sleeve button-down (`#B8292F`, shade `#861D23`), arms redrawn like Dan's
    (sleeve color down to y39, darker cuff, then hand). Collar flaps and placket in
    `#861D23`, pearl button `#F2E6E6`
  - sage-green fleece vest on its own `Vest` layer (top of the stack): `#7FA39B`,
    shade `#5E7F78`, zip `#3F5A55`, V neck so the red collar shows above it, hem at
    y36 so the belt stays visible, 1px outline
  - everything else (hair, stubble, jeans, belt, shoes) is the same as site Alan
  - Reference photo: `archive/alan2.png`.
- **site Alan** (`site_alan_*`): Alan in his work-site outfit (this was originally
  named `office_alan_*`; renamed once the casual office outfit was added). Copied
  from office teen (short-sleeve
  polo, so the arm and sleeve layers are unchanged), with:
  - charcoal gray polo (`#4E535B`, shade `#383C43`), gray buttons (`#A8AEB8`)
  - short dark brown hair (`#3E2C20`, highlight `#5A4232`), a bit fuller than Dan:
    hair over the forehead, forehead visible about 2 rows
  - 5 o'clock shadow on its own `Stubble` layer (top of the stack): a subtle
    patch only slightly darker than the skin (`#D69A72`) over jaw, chin and upper
    lip, with the mouth clear. Keep it close to skin tone. A darker color reads as
    a beard.
  - blue jeans (`#3F5E8E`, far leg `#2F4A73`, shade `#243A5C`)
  - brown leather belt (`#5A3A22`) with the usual silver buckle
  - greenish-gray shoes (near `#6E7A68`, far `#55604F`)
  - no watch, no glasses. Reference photo: `archive/alan.png`.

- **casual Garrison** (`casual_garrison_*`): Garrison. Copied from site Alan
  (short-sleeve, stubble layer already there), with:
  - teal plaid short-sleeve button-down (`#4F9C8E`, shade `#3A7A70`). Plaid is
    drawn as 1px lines (`#9AD0C3`) on the Shirt layer: vertical at x16, x20, x24
    and horizontal at y27, y31, y35, plus small lines on the sleeves. Full placket
    with pale buttons (`#E8F2EE`) down to the belt, skin V neck with dark teal
    collar flaps
  - dark curly hair (`#2A1C14`, highlight `#47301F`) with a bumpy top edge made
    from alternating pixels on the top row (not a smooth cap), brows `#2A1C14`
  - goatee on its own `Beard` layer (`#2E2018`): moustache above the mouth and
    chin patch below, mouth line clear. Light stubble (`Stubble` layer, same as
    Alan) on the jaw underneath
  - very dark jeans (`#2B3550`, far leg `#1F2840`, shade `#171E32`), black belt
  - off-white canvas sneakers (near `#CFC8B5`, far `#A9A28F`)
  - no watch, no glasses. Neutral expression like the others (the photo is a big
    smile). Reference photo: `C:\Users\Ben\Pictures\Screenshots\garrison.png`
    (not copied into `archive/` yet).

## Animations (`*_anim.aseprite`)
- Every character x facing has an `<outfit>_<character>_<facing>_anim.aseprite` next to its still. Stills
  stay the source of truth; the anim files are generated, so do not hand-edit them.
- Canvas **64x80**, feet on row 79 (headroom for the jump, width for the death fall). Same layers as the
  still. 42 frames, tagged: `idle` 1-4, `walk` 5-12, `run` 13-18, `jump` 19-22, `land` 23-25,
  `hurt` 26-28, `death` 29-35, `sitdown` 36-37 (play backwards to stand), `sit` 38-39, `type` 40-42.
  Frame timings are set per frame. Seated = thighs 50-55 deg, hips 2px lower (`bob`/`legDy`), forearms forward.
- Generated by `tools/anim.lua` (engine) + `tools/poses.lua` (pose table) via `run_lua_script`:
  `E.build(inPath, outPath, poses, tags)`. It reads the layers (leg gap, shoe boundary, arm pivots, which
  arm the watch is on) from the still, so it works for any character built on this layer structure.
  Left files are generated from the left still (not mirrored from the right anim).
- Parts: head = Body rows 0-22 + Face/Hair/Beard/Stubble/Glasses (can tilt about the neck, `hrot`);
  torso = everything else; arms rotate about the shoulder (row 25) with an elbow at row 34 (`aNr`/`aFr`);
  legs rotate about row 47 with a knee at row 54 (`lNr`/`lFr`); pants split at the gap, shoes at the
  shared outline. Bent limbs are two overlapping segments (rel = 0 keeps the limb rigid).
- Jump poses keep the near arm back and the far arm up: the near arm is on the back side, so raising
  it forward crosses the face and raising it straight up hides it behind the hair.
  Hurt/death use a closed-eye + open-mouth variant of the Face layer and a white flash on frame 1.
- To change a pose, edit `tools/poses.lua` and rebuild all 12 files. Positive angles swing toward the
  facing side. Leg angles have to keep the feet a few px apart (the near leg starts on the back side).

## Godot (`godot/`)
- Godot 4 project, 368x128 viewport shown at 4x (integer scaling, nearest filtering, pixel snap).
  Godot can't read `.aseprite`, so `godot/assets/` holds exported PNGs (the one place PNGs are expected):
  `assets/characters/<name>_<facing>.png` = horizontal sheet of the 35 `_anim` frames (64x80 each),
  `assets/sets/<set>.png` = the set with its `CharacterTest` layer hidden.
- `tools/make_godot.py` regenerates `project.godot`, `characters/*.tres` (SpriteFrames, 8 anims x 2
  facings, per-frame timing from the Aseprite durations), `scenes/*.tscn` and `scripts/*.gd`. Re-export the
  PNGs from Aseprite first when art changes, then rerun it. `crouch` = frame 19, `jump` = frames 20-22
  (picked by vertical speed), the rest follow the tags.
- Controls in the test scenes: A/D or arrows, Shift run, Space jump, E use door / sit / stand, H hurt, K die,
  R revive, 1-6 switch character (any time, even mid-animation: `_switch_character` keeps the running
  animation), F1-F5 switch set. Floor line is y=118; each set is centred in the viewport with walls.
  Doors: Office 1/2 -> office (the office door returns to whichever you used, `Game.vars`), kitchenette
  left/right bath doors -> one shared bathroom set (its door returns to the one you used), main floor left
  edge -> kitchenette, right edge -> cubicle area (cubicles 3/4, copier, cooler, whiteboard), whose right
  edge -> conference (its left edge -> cubicle area, its door -> main floor). The glass front door is locked:
  the arrow turns red and shakes (`locked = true` on a door). Fade between scenes is in the `Game` autoload.
  Tests in `godot/tests/`: smoke, seats, extras (switching character / sit again), doors, edges (every
  edge exit both ways). F-keys: F1 main, F2 office 1, F3 office 2, F4 conference, F5 kitchenette, F6 bathroom, F7 cubicles.
- Depth: `tools/build_sets.lua` (needs `tools/lib.lua`) builds every set twice: the full `.aseprite` and a
  Godot export = background PNG + one PNG per y-sorted prop + `<set>_props.json` placements. Props sort by
  their base y against the player's feet y, so a seated player (feet y 97 / 89) sits between the chair (95 /
  88) and the desk (108). Godot 2D sorts by the node's own y (there is no `y_sort_origin` on sprites), so
  the generator puts each prop's node on its sort line and shifts the art up with `offset`. Check depth by
  zooming real frames (`--write-movie`), not at 1x: it is easy to misread. Edit `build_sets.lua`, run it, then `make_godot.py`. Seats/doors/spawns are listed
  at the top of `make_godot.py` (`SETS`).
- Godot 4.7.2 lives at `C:\Program Files\Godot\Godot.exe` (the path the godot MCP expects). Test headless:
  `Godot.exe --headless --fixed-fps 60 --path godot -s res://tests/smoke.gd` (loads all 6 characters and 4
  sets, simulates walk/run/jump/land/hurt/die/revive, sitting, doors and edge exits, logs state changes).
  `tests/seats.gd` sits the player in all 7 seats, then stands them up (E, or a move key at cubicle 1) and
  checks idle / same scene / on the floor at the chair / collision back on (run it with `--write-movie`
  and zoom the frames to check depth).
  Re-import after new art: `Godot.exe --headless --path godot --import`. To grab frames:
  `--write-movie out.png --quit-after 30` (without `--headless`). Lint: `gdlint scripts tests` and
  `gdformat --check scripts tests` from `godot/` (pip install gdtoolkit; lint misses type errors, so
  also load every scene). Interaction picks the nearest door/seat by x (`player.nearest()`), because
  zones overlap (cubicle 1 sits under the Office 2 door).

## Palette
- Outline `#17121F`
- Skin `#F3B488`, skin shade `#D88A62`, deeper shade `#B8663F`
- Hair `#9A5124`, highlight `#C47A38`, brows `#6B3416`
- Office shirt `#4F7FD0`, shirt shade and collar `#3A62A8`, button `#BBD0F5`
- SkillsUSA shirt `#F4F2EA`, shade `#CFD2E2`
- Pants `#3A3F66`, far leg `#2F3354`, pants shade `#272B48`
- Shoes `#5A3522` (near), `#4A2C1C` (far)
- Belt `#17121F`, buckle `#C8CCD8`, watch `#2A2A33`
- Eye white `#FFFFFF`, pupil `#3A2418`, mouth `#8A4A2E`

## Files
- Naming: `<outfit>_<character>_<facing>.aseprite`. This character is **"office
  teen"** (the teenage-me character in the blue office polo), so files are
  `office_teen_right.aseprite` and `office_teen_left.aseprite`.
- `office_teen_right.aseprite` is the source of truth. `office_teen_left.aseprite`
  is derived from it. Edit the right file first, then regenerate the left.
- `archive/teenme.png` is the original reference photo.
- `archive/` holds earlier, superseded attempts (`teen_blocky*`, `teen_cartoon*`,
  the SkillsUSA layered version) and old preview PNGs. Do not edit these. Keep only
  the current `office_teen_*` files in the project root.

## Tool gotchas (aseprite MCP)
- Layers must exist (`add_layer`) before drawing on them. `create_canvas` makes
  "Layer 1" (rename it with `rename_layer`).
- To redraw a layer, `clear_cel` first, then draw, then `outline_cel` once.
- `draw_rows` needs equal-width rows. Use `#00000000` in the legend to erase.
- Use forward slashes in file paths.

## Process notes
- Check each pass with `view_sprite` (use `region` to zoom on the head).
- Iterate on one thing at a time. The user reviews visually and gives short
  feedback ("cheek looks weird", "arms backwards"). Re-read the reference image
  or screenshot they point to before redoing a pose.

### Ambient motion + interactive props (`scripts/fx.gd`, `interact.gd`)
- `fx.gd` draws procedural effects over the art (art-local coords, 12 fps steps): `monitor` (live screen, scrolls faster while the player sits nearby), `tv` (spreadsheet/bars/news, auto-cycles, static between), `coffee`, `copier`, `cooler`, `sink`, `toilet`. `interact.gd` is an Area2D (E key, joins the nearest-wins rule) that calls `play()` on its `target` fx; arrow hides/shakes while busy.
- Config lives in `tools/make_godot.py`: `PIECE_W` (props that get an fx child + interact zone) and `BGFX` (effects on background art: name, kind, art_x, art_y, interact_x). Monitors get an fx automatically.
- Test: `tests/fx.gd` (use with `--write-movie` for frames).

### Characters interacting (`npc.gd`, `bubble.gd`)
- Animations 43-53: `reach` 43-45 (one-shot, far arm out), `wave` 46-49 (loop), `talk` 50-53 (loop) in `tools/poses.lua`; 53 frames/sheet.
- Player: using a prop plays `reach` (state `use`); Q waves; E on an NPC starts a chat (state `emote`, `start_emote(anim, secs, toward_x, glyph)`) with alternating speech-bubble icons (`dots ! ? heart`).
- NPCs (`scenes/npc.tscn`, Area2D) loop a routine of string steps: `walk:X wait:S say:S talk:S use:prop sit:Seat stand sync:key:n`;
  `start_seat` seats them at spawn. They wave when the player nears, E chats (only while standing). Casts live in `NPCS` in
  `tools/make_godot.py` (walk x in set pixels). `sync` is a barrier so pairs meet and talk together. Seats have `occupied`
  (player can't take an NPC's seat). Tests: `tests/npcs.gd` (use `--write-movie` for frames).
- After re-exporting any PNG (sheets, sets, props) Godot must re-import it or the game keeps showing the old cached
  texture (new sheet frames render blank/invisible). `tools/make_godot.py` now runs `Godot --headless --path godot --import`
  at the end; run that yourself if you export PNGs without regenerating.

### Seating geometry + held items
- Seated poses use `kn = 60` (knee row, default 54) with the thigh horizontal, so hips drop ~19px to chair-seat height
  (sitter ~10px shorter than standing). Chair art is 18x33 (seat top 15px above the wheels); desk chairs sit at y=66,
  seat feet y=101, sitter at the desk's LEFT end (seat = desk_left+12), keyboard seat+12, monitor seat+18.
- Poses 54-66: `hold` (54-55), `walkhold` (56-63), `sip` (64-66): near forearm up. `E.render` also returns the near
  hand position per frame; `tools/build_anims.lua` (run via `dofile`) rebuilds all anim files, sheets and
  `<name>_<facing>_hands.json`. Run it, then `build_sets.lua`, then `make_godot.py`.
- Items: `scripts/held_item.gd` follows the hand of the current sheet frame. Coffee machine -> `coffee`, cooler -> `water`
  (`fx.item`, given when the effect finishes). Player: F sips (3 sips empties it), item persists across rooms
  (`Game.vars held/sips`). NPC steps `sip` and `drop`. Test: `tests/items.gd`.
- Seated with a cup: it stands on the desk (`scripts/desk_cup.gd`, sorted just in front of the desk at y=109, x = seat+48);
  `sitsip` (frames 67-69) brings it to the mouth; standing picks it up. Seated cups last 6 sips, standing ones 3.
  Sip cup tilt is code (`held_item.gd`: 30/112/45 deg, rim ends up pointing down at the lips). NPC steps: `sip` works
  seated or standing; `NPC_ITEMS` in `make_godot.py` gives an NPC a starting cup. Tests: `tests/deskcup.gd`.
  Seats export `cup_dx`/`cup_y` (where a seated cup stands): desks use 48/84, conference seats (non-typing) 14/80 (on the table).
  Conference Dan/Alan start with cups. Test: `tests/confcup.gd`.

### Desk phone (piece only, not placed in any set yet)
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
- The sets still use the `front` frames; side frames are not exported to Godot yet (planned: a per-prop `angle` setting).

### Taller sets: ceiling + floor extension (for 16:9 and 9:16 video)
- Set backgrounds are now **W x 320** (100 ceiling + the old 128 + 92 floor extension). Builders keep their old 0..128
  coordinates: `L.YOFF` (= `L.CEIL_H` 100) is added by `put`, `L.wall/carpet/tiles`. `build_sets.lua` then draws `L.ceiling`.
  Prop JSON y values stay relative to the old art; in Godot the Background sprite sits at y = -`SET_TOP` (100), so every
  Godot coordinate (FLOOR_Y 118, spawns, doors, seats) is unchanged and the 368x128 viewport still shows the same picture.
- Ceiling (`L.ceiling`): old yellowed 2x2 ft acoustic tiles with pinholes and water stains, white T-bar grid, 2x4 ft fluorescent
  troffers (one tube dying per room), sprinkler heads, wall angle strip at the wall line. Seeds per set in `build_sets.lua`.
- Floor: **blue low-pile carpet** (`#3E5E8E`, speckle, 2 ft carpet-tile seams) in main floor, cubicles, offices, conference;
  kitchenette and bathroom keep their tile floor (extended). Carpet/tiles now run to the bottom of the taller canvas.
- Formats: 16:9 = 320x180 (6x -> 1080p), 9:16 = 180x320 (6x -> 1920 tall). `tests/format.gd` renders every set in both with a
  `Camera2D` + `root.content_scale_size` (needs a renderer, not headless) and saves PNGs to `user://`.
- Narrow rooms: any set narrower than `L.MIN_W` (320) is built on a 320-wide canvas. `L.XOFF` = (320 - W) // 2 is added by
  `put`; wall/carpet/tiles/ceiling span the full canvas width; `L.margins` then darkens the two margins (x0.55) and draws a
  3px dark cutaway edge at the real room boundary, so the margins read as "off stage". Margins: bathroom 96, conference 64,
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
- `office_interior` is gone: **Office 1** (`office_one`, pale green walls, bookshelf + plant, green slipper armchair, two framed
  pictures, wall clock, desk 68, seat x80) and **Office 2** (`office_two`, tan walls, teal couch, whiteboard, filing cabinet, floor plant,
  framed picture, clock, desk 64 at x96, seat x108). Each main-floor door goes to its own room and its door returns to the right
  spawn (`from_office1` / `from_office2`), so the old `office_return` variable is unused. F-keys are F1-F7 now.
  New pieces (front + side in `build_angles.lua`): filing_cabinet, couch, picture_frame, wall_clock. Easy next variations: wall colour
  (`L.wall` base), which props, seat position in `SETS`.
- The glass front door is no longer on the wall: `L.hallway` (lib.lua) cuts a trimmed opening in the main wall (x 6-76) and draws a
  one-point-perspective green hallway (darker side walls, old-ceiling plane, dark carpet floor) with a small glass door (26x40) and an
  EXIT sign on the far wall. The locked door's interaction zone is at x=43.

### Fridge (kitchenette)
- `fx.gd` kind `fridge` (background art at set (46,30)): the lower door swings out to the left, the interior lights up (shelves with a
  bottle, milk, jar, three soda cans, lunch bag, yogurt, crisper drawer) and light spills on the floor; one random drink (`soda` can or
  `bottle`) is handed over 1.5 s in (`HAND_AT`, signal `handed`) and leaves the shelf; the door closes at 3.2 s.
- The zone sits to the RIGHT of the fridge (set x78) so you stand beside it and the open door stays visible; `look_x` on the
  interact zone (set x59, from the 6th BGFX field) makes players/NPCs face the fridge when they reach. Alan's kitchenette routine
  now visits the fridge between coffee refills. New held items `soda` and `bottle` (held_item.gd + desk_cup.gd). Test: `tests/fridge.gd`.
- Interact zones can now hand over an item mid-effect (`fx.handed`); other machines still hand over at the end.

### Sittable lounge furniture, wider desks, desk phones (headset)
- Office 1's armchair is now the SIDE view (`chair_slipper_green_side`, 22x32, seat 19 px off the floor like the desk chairs) so the
  sitter faces the same way as the chair; Office 2's couch (40x31) has two seats (one per cushion). Lounge seats are `(x, y, False, True)`
  in `SETS` (4th item = lounge): `stash = false` so a cup stays in the hand, `sit` pose, relaxed arms. Furniture sorts at y 99, the
  sitter at 101. This is the first use of a per-prop angle: pass the side image and a `_side` piece name to `putS`.
- Every desk is now `desk_cubicle_74` wide so a phone fits: monitor at seat+14 (D+26), keyboard D+24, phone D+57..D+69 (12 px wide, put y 72). Seated cups
  stand at seat+35 (`cup_dx` default). Office 2's desk is at x88 (seat x100) with the filing cabinet at x162.
- Fridge: its arrow is now above the fridge (BGFX 7th field = arrow y; x comes from the look target).
- **Desk phone** (`fx.gd` kind `desk_phone`, prop `desk_phone` = cord + body, handset is `desk_phone_handset.png` drawn by the fx):
  it rings now and then (12 s, LCD flashes, LED blinks, handset jitters, ring marks), and E answers it standing, or seated while it
  is ringing (the seat can reach phones within 80 px; E otherwise stands up). Nobody lifts the handset: people use a **wireless
  headset**. `call`/`sitcall` (frames 70-73) are the ear tap; then `held_item.gd` in `mode = "ear"` draws the earpiece + mic boom at the
  per-frame ear position (hands.json now has `[hand x, hand y, ear x, ear y]`). While talking (9 s) you can walk, or keep typing
  seated; bubbles alternate; another tap takes it off. The phone LCD shows a running timer meanwhile. Test: `tests/phone.gd`.
- NPCs answer too: a seated NPC (state `wait`, no hold) whose desk phone (group `phones`, within 70 px of the seat) is ringing taps their ear (`sitcall`,
  0.7 s, routine paused), puts on the headset (`_head_item`), keeps typing while a bubble alternates for 9 s, taps it off and resumes the routine
  (`npc.gd _update_call`). Standing NPCs do not take calls yet. Calls have no speech/audio. Tests: `tests/npcphone.gd`.

### Dancing + phone ownership
- **Dance** (player only, NPCs never dance): `dance` animation = frames 74-85 (85 frames per sheet), a 12-frame loop of two phrases in
  `tools/poses.lua`: point-and-bounce (far arm up, near arm swinging back, knee bobs, head tilts) then a side shuffle with pumping
  forearms and a small hop. **X** starts it from the ground (`state = "dance"`, `Player._start_dance`), a music-note bubble (`note` glyph
  in `bubble.gd`) blinks above the head, and X again / any move / jump / E stops it. Cups and headsets follow the hand/ear as usual.
  Test: `tests/dance.gd`. Tweak the moves in `poses.lua` (`dn{...}` rows) and rebuild with `tools/build_anims.lua`.
- **Phone ownership**: a desk phone belongs to the seat to its LEFT (phone zone 20-70 px right of the seat). Dan used to answer his
  neighbour's phone (it was 32 px away on his left) while his own kept ringing; both the player (`_ringing_phone`) and NPCs now use
  that rule. Test: `tests/npcphone.gd` rings the neighbour (ignored) then Dan's own (answered).

### Persistent cast (`scripts/world.gd` autoload `World`, `scripts/world_data.gd`) + conversation spacing
- Supersedes the per-room NPC lists: `NPCS` / `NPC_ITEMS` in `make_godot.py` and `tests/npcs.gd` are gone. Three characters exist once each
  and live in the whole building: **Alan** (`office_alan`, Office 1 desk), **Garrison** (`casual_garrison`, Office 2 desk), **Dan**
  (`office_dan`, main-floor cubicle 3). Edit `CAST` in `world.gd` to add people (home scene + seat).
- Each has an agenda of *legs* (`{kind, scene, routine, dur, target_x, to_scene/to_spawn}`): work at the desk (seated, sips, phone), coffee
  (kitchenette machine, sometimes the fridge), cooler (copier + water), bathroom (sink), or a meeting in the conference room (every 2-3
  min `World` sends 2-3 people at their desks to Seat1-3; they sit and take turns talking, then go home). Travel legs are routed through
  the real doors/edges by BFS over `world_data.gd` (generated: x0, W, spawns, links with absolute x, seats, uses).
- In the room you are in they are real `npc.tscn` nodes (named `Alan` etc., `cast_name` set) running the current leg's routine; when it
  ends they call `World.leg_done`, or `exit:Name` steps call `World.leg_exit` and the node leaves. Anywhere else `World._process`
  counts the leg's duration down and moves them to the next scene. `World.populate(stage)` (called from `stage.gd`) spawns whoever is
  in the room: seated at the desk if they were already at work, standing at their destination after `SETTLE` seconds, otherwise at the
  door they came through. Held drinks (`held`/`sips`) travel with them; if you are playing as that character the NPC copy is hidden.
- Useful in tests: `World.time_scale`, `World.meeting_gap`, `World.force_activity(name, "coffee"|"cooler"|"bathroom"|"work")`,
  `World.send_to_meeting(name, "Seat1")`. Tests: `tests/world.gd` (fast-forward, coffee arrival, meeting), `tests/chat.gd`.
- Talking: the NPC zone is wider (46 px) so you can start a chat from ~30 px away, and `slide_to` steps the player to `TALK_GAP` (32 px)
  from the NPC, on the side they were on (clamped by the room walls), instead of overlapping.
- Not done yet: characters never talk to each other on their own, no lunch/leave-for-the-day schedule, and the player cannot ask someone to
  follow or join them.

### Cast conversations, the workday, and "follow me" (`world.gd`, `npc.gd`, `hud.gd`)
- **Cast chat**: two cast NPCs that are standing/walking within ~52 px of each other stop, face each other, slide to 32 px apart and talk
  5-8 s with alternating bubbles (`npc.gd _update_cast_chat`, `begin_chat`); `World.try_chat` allows it with `chat_chance` (0.8) and a 60 s
  cooldown per pair. They resume their leg afterwards. Test: `tests/castchat.gd` (Alan and Garrison cross on the main floor).
- **Workday clock** (`World.clock`, 9:00-17:00 over `day_len` = 600 real seconds; `time_scale` speeds up everything off-screen):
  morning agenda as before; at 12:00 each person (once, when their current plan ends) brings a drink and walks to their conference seat
  (Seat = cast order) for a ~56 s lunch with bubbles; meetings only happen outside lunch; at 17:00 `_leave_plan` sends everyone to the main
  floor and out the front door (`main_floor.outside_x`, the NPC fades out; scene `__outside__`). When all are out `_new_day` skips the night:
  clock 8:30, day+1, and each person drifts back in through the `from_outside` spawn at a random moment (fades in) and walks to their desk.
  A tiny 3x5 pixel clock draws top-right (`hud.gd`, hidden under `--write-movie`, **F10** toggles). Tests: `tests/day.gd` (two simulated
  days headless, no room loaded), `tests/lunch.gd` (watch lunch in the conference room), `tests/hud.gd` (screenshot).
- **Follow me**: **C** next to a cast member (nearest *person*, not a chair) toggles `World.set_following`. They trail you ~30 px behind
  (`npc.gd _follow_tick`); when you change rooms `Game.go` calls `World.player_left`, which gives followers a travel leg through the real doors
  to your room and re-spawns them there; follows time out after 120 s or at 17:00, then they resume their agenda via `_plan`. Test:
  `tests/follow.gd`.
- Still to do: people never invite you to things or react to the clock themselves (no "lunch?" lines), no weekends/holidays, and the clock
  has no art in the rooms (the wall clocks are still static).

### Light switches and lights out (`World.lights`, `fx.gd` kind `switch`, `stage.gd` darkness)
- Every room has a wall switch (BGFX entry `Switch`, x per room in `make_godot.py`, plate drawn by `fx.gd _draw_switch`): **E** flips that
  room's lights. Off = a blue-grey TINT (`stage.gd _set_dark`, fades in 0.25 s) applied as `modulate` to the room's `Background`, `Fx` and
  `Actors` nodes, so y-sorting is untouched. Screens (monitors, TV, the open fridge) and speech bubbles join group `emissive` and get the
  inverse modulate, so they keep glowing; arrows/bubbles are `z_index 30`. (An earlier overlay version drew screens over people's faces.) State lives in `World.lights` (a missing room = lit),
  signal `lights_changed(room)`, `World.set_lights / toggle_lights / lights_on / last_one_out`.
- Cast: NPC step `lights:on|off|last` (reach animation); `last` only switches off if nobody else of the cast is still in that room. At
  closing (`clock >= DAY_END`) `_travel(..., closing=true)` and the final front-door leg walk to the switch and use `lights:last`, so the last
  person out of each office turns it off and the last one out of the building turns off the main floor. Off-screen the same rule is applied
  when the leg finishes (`lights_last`). In the morning someone walking into a dark room turns the lights on (animated if you are there:
  `_spawn` prepends `walk:switch, lights:on`; unseen, `_finish_leg` just sets them on). The player counts for nothing here: NPCs switch lights
  off even if you are still in the room (flip it back on).
- Tests: `tests/lights.gd` (switch twice, Alan switches off Office 1 at 17:00; record it), `tests/daylights.gd` (two simulated days).

### Logo + title screen ("MSPSim" / "MSP Simulator")
- Art (Aseprite, `tools/logo.lua`, run with `dofile`): `office/logo/mspsim_logo.aseprite` (183x52; layers Outline, Extrusion, Face MSP, Face SIM,
  Bevel, Headset, Ribbon, Tagline: chunky 5x7 letters at x4 with a 3 px extrusion, MSP in office blue, SIM in lime, a pixel headset icon, a
  "MSP SIMULATOR" ribbon in a 3x5 pixel font), `mspsim_logo_s.aseprite` (145x44, letters x3, fits the 180 px portrait frame),
  `press_start.aseprite` (frame 1 text, frame 2 blank) and `title_screen.aseprite` (320x180 poster: the real main floor, the cast, logo,
  blinking prompt = 2 frames). Palette: letters `#4F7FD0`/`#8FC43A`, outline `#17121F`, ribbon `#2A2A33`.
  Flat PNGs for Godot are exported to `godot/assets/ui/` by the same script.
- Godot: `scenes/title.tscn` + `scripts/title.gd` is the project's main scene (project name is now MSPSim). It shows the real main-floor set
  with the cast standing in it (they wave now and then), the logo (large, or the small one when the frame is under 250 px wide), and a
  blinking PRESS START. **Enter / Space / E / click** starts (`Game.go("main_floor")`); **F9** still cycles formats. The office simulation
  is frozen while you are on the title (`World.time_scale = 0`, clock hidden) and starts when you press start.
  Tests: `tests/title.gd` (Enter starts the game), `tests/titleshots.gd` (screenshots of each format to `user://`).
- **Character select / first-day screen** (`scripts/charselect.gd`, a `Node2D` that `title.gd` adds to its front layer; no scene file): picking TECH CAMPAIGN, NEW OWNER CAMPAIGN or FREE PLAY on the title menu
  opens it instead of starting at once (**Continue skips it** and restores the saved character). A row of the playable people (`Player.CHARACTERS`, the same 7 as the 1-7 keys) with a looping idle preview
  (left half face right, right half face left, the chosen one faces the way you last moved), name and a short 2013-14 blurb (`PEOPLE`); in narrow portrait (`v`, under 250 px wide) it is a carousel with a 2x
  preview, arrows and dots. **Left/Right (A/D)** move, **Enter / E / Space** confirm, **Esc / Backspace** go back (to the title menu), mouse hover selects and click confirms, F9 cycles formats.
  The **tech campaign adds a second step: the phone** (IFONE 5 / NEXXUS 5, same saved preference as the phone's first-open picker via `Phone.set_os`; that picker stays as the fallback when no phone was chosen, e.g. owner / Free Play),
  and a summary line ("TECH CAMPAIGN - ADULT - IFONE 5 - NORMAL") is shown at the bottom and as a toast when the run starts. Up / Down change the difficulty (see "Difficulty and seeds").
  **Cast rule:** in the two campaigns the cast (`World.CAST`: Alan, Garrison, Dan, Vic, Maya) are real NPCs with desks, opinions and agendas, so only people who are NOT cast are offered (teen, adult, site Alan); Free Play offers all 7.
  (Playing as a cast member in a campaign would need their NPC removed from `World.chars` like `apply_roster` does for Maya, plus Social / Lync / Talk / desk-ticket entries for the missing person: not done.)
  The choice sets `Player.current_character`; `Campaign.save` stores it as `campaign/character` and `continue_game` restores it (old saves default to `office_adult`). Launching a scene directly (tests) never shows the screen.
  Tests: `tests/charselect.gd` (choices per mode, move / back / confirm, phone step, summary, Continue skips it, old save default), `tests/charselect_shots.gd` (screenshots, renderer needed, `-- --format=wide|h|v`).
- Ideas left: a settings/credits screen, music, and an animated logo (letters dropping in).

### Rotating title vignettes (`scripts/title.gd`, `Game.title_mode`)
- The title rotates (every 9 s, with a 0.3 s fade) through four scenes behind the logo, each the REAL room scene instanced in title mode
  (`Game.title_mode = true`: `stage.gd` frees the Player and skips the camera / World cast / darkness) with plain looping NPC nodes:
  **lineup** (main floor, the cast standing around, two of them chatting), **phones** (cubicle area, Garrison and Dan seated; the phones
  are rung by timers so they answer with headsets while typing), **kitchen** (Dan at the fridge, Alan at the coffee machine, Garrison
  talking with them) and **conference** (a meeting with drinks on the table). `show_vignette(i)` builds one without the fade (tests).
  Layout follows the output format (wide drops the 4th person, portrait uses the small logo and centres the two desks).
- Test: `tests/titleshots.gd` saves each vignette in several formats to `user://title_<format>_<n>.png`.

### Network closet (`network_closet`, `net.gd`, plug points) + Tab selection
- **Where**: a steel door at the right end of the cubicle area (that room is now 320 wide, door at set x299) opens into `network_closet`
  (144 wide, a small tiled closet: door, a wall outlet, the ISP jack, and ONE rack; spawns `from_cubicles` / `from_closet`, F8 jumps there).
- **Art**: `L.rackLayout()` in `tools/lib.lua` is the single source for the rack (70x88 content px: patch panel with 8 jacks, 12-port switch,
  blue router with WAN + LAN ports, NAS with 4 bays and a power button, 6-outlet PDU, UPS with LCD, 3 outlets and a power button), the plug
  points, LEDs and the fixed cable ends. `P.networkRack()` draws it, `P.wallOutlet()` / `P.ispJack()` are the wall plates and
  `godot/assets/props/network_rack_layout.json` is the same layout for Godot (rewritten by `build_sets.lua`).
- **Model** (`scripts/net.gd`, autoload `Net`): cables `p1`-`p8` (patch panel -> switch, one per desk), `up` (router LAN -> switch), `nas`, `wan`
  (ISP jack -> router WAN) and power `sw_pwr` / `rt_pwr` / `nas_pwr` (device -> PDU), `pdu_in` (PDU -> UPS), `ups_in` (UPS -> wall). Each has a fixed
  end and a movable end (`cables[id].end` = the port it sits in, "" = unplugged). `accepts(cable, port)`: network cables fit switch ports, WAN only the
  WAN port, device power only PDU outlets, the PDU feed only UPS outlets, the UPS cord only the wall. `power()` / `status()` derive what is powered and
  ready; devices need `BOOT` seconds after power returns (switch 3, router 6, NAS 8); the UPS drains in 90 s when unplugged from the wall (display
  shows it) and recharges in 100 s; the UPS / NAS buttons switch them off. `desk_state(n)` = `ok` / `no_internet` (link but router/WAN/uplink down) /
  `no_link` (patch cable out or switch dead).
- **In the room**: `fx.gd` kind `rack` draws live LEDs (link/activity per port, router, NAS drives, PDU, UPS bars + an on-battery blink) and every cable as a
  curve (patch cables blue / teal / orange / purple, uplink yellow, NAS green, WAN red, power grey; unplugged ends dangle; the one you carry is drawn
  to your hand). `port.gd` nodes (group `ports`, 25 of them) are the plug points: **E** pulls the plug out (you carry it: held item `plug_net` /
  `plug_pwr`, only with empty hands) or plugs the carried cable into the selected port; wrong kind of socket / occupied port shakes the arrow. `rack_zone.gd`
  puts all ports in reach while you stand in the closet. A cable cannot leave the closet (`stage.gd` drops it).
- **Consequences** (`desk` = patch panel port, exported on monitor / phone fx and the copier = 8): a desk with no network shows a red X (no link) or a yellow
  warning triangle (no internet) on its monitor, its phone LCD goes grey, it never rings, and the phone / copier will not respond to E.
- **Tab / Shift+Tab** (Player): moves the arrow to the next / previous thing in reach (sorted left to right, top to bottom) without walking, in any room
  (doors, seats, machines, NPCs, the 25 closet ports); the choice sticks until you walk about 10 px away. `nearest()` now breaks ties with the
  distance to your chest so stacked targets pick the middle one by default.
- Tests: `tests/net.gd` (26 checks of the model), `tests/closet.gd` (Tab, pulling and replugging cables, the UPS button, wrong sockets; record with
  `--write-movie`), `tests/outage.gd` (what offline desks look like).
- Ideas left: NPCs noticing outages and calling in tickets, a labelled patch panel / cable tracing, a spare laptop you can plug in, blinking LEDs through
  a pitch-black closet, side view of the rack, and an IT "ticket" objective loop for the MSP Simulator.

### Computer + MSP (`scripts/computer.gd` autoload `Computer`, `msp.gd` autoload `Msp`, `pixelfont.gd`)
- **Brand name rule**: any product whose UI or behaviour we imitate gets a parody name (ConnectWhy PSA, LabRat RMM, Outlookish 2013, Lynk 2013 for Lync, iFone 5 and Nexxus 5 for the phones, a Googol search bar, the vendors in `Expo.VENDORS`). Real names are fine only as 2013-14 era context that is just talked about, never shown as a UI we draw: Windows 7 / 8.1 / XP, Exchange, Office 2003, Heartbleed, CryptoLocker, PowerShell, Floppy Bat, Sugar Smash. Internal ids and save values are unchanged (`Lync` autoload, `app:lync`, phone cfg `ios` / `android`); only display text uses the parody names.
- **Fake names**: PSA = **ConnectWhy PSA** (ConnectWise Manage style board), RMM = **LabRat RMM** (LabTech/Automate style tree), mail =
  **Outlookish 2013**, company = Pixel IT Partners. Clients (Acme Dental, Brightside Realty, Gnarly Gnomes, Hoot and Holler Law, Soggy Bottom
  Brewing) are in `Msp.CLIENTS`; each has 3 PCs + a server as RMM endpoints.
- **Takeover**: E on a monitor (standing, nearest zone, group `computers`) or E while seated (monitor 5-60 px right of the seat; a ringing phone wins)
  calls `Computer.open(desk)`. The office is dimmed and a faded strip stays visible at the top (`Game.UI_STRIP` = 20% of height, min 12 px); the stage camera
  slides (`Game.ui_shift`, `stage.gd _ui_cam_y`, limit_bottom lifted, smoothing off) so the player shows in the strip; `Game.ui_open` freezes the
  player (`Player._physics_process` returns early). Drawn entirely in code at the game's pixel size with the 3x5 `PixelFont`; mouse (custom cursor) or
  Up/Down/Enter/Esc. Narrow formats (v) use single-column mail / RMM. No network at that desk (`Net.desk_state`) = every app shows an offline page.
- **Msp**: `create_ticket(client, problem, source)` picks a healthy endpoint and breaks it (problem = the RMM action that fixes it), emails the contact;
  random ticket every 45-90 s (max 6 open, stops at `World.DAY_END`); answering a desk phone creates one (`Msp.phone_call`); SLA clocks (P1 120 s ...
  P4 480 s, scaled by `World.time_scale`) breach for -5; our own desk outages > 8 s become internal tickets that auto-resolve 3 s after the network is back.
  `rmm_action(endpoint, action)` fixes it; `close_ticket` scores +10 (+4 if late) when fixed, else reopens with an angry email (-3).
  HUD shows `TKT n MAIL m` top-left.
- Tests: `tests/msp.gd` (logic + screenshots of each app to `user://msp_*.png`, needs a renderer for images), `tests/computer.gd` (sit, E, Esc).
- Next: NPCs reporting outages, more ticket types, a day-end score screen, phone calls / a dialer.

### Cell phone (`scripts/phone.gd` autoload `Phone`)
- **P** opens it anywhere (not on the title screen); Esc / P closes. Same takeover + faded strip as the computer (`Game.ui_open`, `Game.ui_shift`).
  First open asks **iFone 5** (slate, iOS-style look: gradient wallpaper, rounded icons, home button, iOS header + back chevron) or **Nexxus 5**
  (matte black, Android 4.4 look: dark status bar, Holo teal headers, on-screen back / home / recents bar); saved in `user://mspsim_phone.cfg`,
  changeable in Settings (the tech campaign's character select screen also asks and sets it, so the picker is only a fallback). Left/Right/Enter also work in the picker. Screen scale doubles in tall formats.
- Apps: Mail (the same `Msp.emails`), Tickets (`Msp.open_tickets()`: view, TAKE, NOTE; CLOSE says to use a computer), Texts (`Msp.texts`),
  Settings. It runs on cellular so it works with the office network down. `Msp.send_text(from, body)` / `unread_texts()` / signal
  `text_received`: P1/P2 tickets text from "Dispatch", SLA breaches from "Boss". HUD adds `TXT n` when unread.
- Tests: `tests/phone_ui.gd` (picker + every app in both skins, screenshots `user://phone_*.png`), `tests/phone_key.gd` (P in a room).
- Ideas left: a dialer / calling clients, replies that do something, a notification buzz + banner on the HUD, lock screen, camera app.

### Campaigns + Free Play / Film Mode (`scripts/campaign.gd` autoload `Campaign`, `day_report.gd` autoload `DayReport`)
- **Title menu** (Enter / Space / E / click on PRESS START opens it; Up/Down, Enter, mouse hover/click, Esc closes): `TECH CAMPAIGN` (or
  `CONTINUE TECH - DAY n` + `NEW TECH CAMPAIGN` when a save exists), `OWNER CAMPAIGN - SOON` (locked), `FREE PLAY - FILM MODE`. Choosing a new run opens the character select screen (see "Logo + title screen"); Continue goes straight in.
- **Free Play / Film Mode** = the old sandbox: `Campaign.new_game("free")` leaves `Campaign.active` false, so no days, reports, scoring or
  random tickets (`Msp.enabled = false`, no spawns, SLA clocks, texts or desk-outage tickets); computer/phone still open and the endless
  day loop runs as before. Use this for filming. Launching any scene directly (tests) behaves the same as before (campaign inactive).
- **Campaigns are fixed and independent**: `TOTAL_DAYS` = 20 days each, one save per mode (`user://mspsim_tech.cfg`, `..._owner.cfg`; `Campaign.save_prefix`
  can be pointed elsewhere). Saved at the end of each day (not at New Game): day, reputation (start 50), cash, history. Continue loads it and starts
  that morning clean (`Msp.reset()`, `World.begin_next_day(day)`: the cast is sent outside and drifts back in, lights reset, clock 8:30).
- **Day report layout** (`day_report.gd`, dark panel): big grade box + SCORE / PAYCHECK / REPUTATION / CASH tiles on the left (on top in narrow formats), the details grouped under TICKETS / PEOPLE / ENERGY on the right (the owner's weekly books are one group), green / amber / red values, ending text, then an ENTER hint and the button. Row values that do not fit drop to their own line; narrow formats try text scale 2 and fall back to 1. Screenshots: `tests/report_shots.gd` (renderer needed, `-- --format=h|v|wide`; worst cases: every row, final day, fired, owner books). The HUD hides while the report is open.
- **Day end**: when `World.clock >= DAY_END` (World no longer skips the night itself while a campaign is active) the sim freezes and `DayReport`
  shows closed / SLA missed / reopened / still open / day score / paycheck / reputation / cash and a grade S-D. Paycheck = 100 + 20 per closed
  - 25 per SLA miss - 10 per reopen (min 0); reputation moves by closed*2 - missed*3 - reopened*2 - open, clamped -10..+8. Reputation 0 = fired
  (final report, save deleted); day 20 shows an ending by reputation (>=70 promoted, >=40 kept your job, else barely survived). NEXT DAY goes to the
  main floor morning. `Msp.pace` shortens the ticket interval by 2.5% per day (min 50%). HUD adds `DAY n/20 REP r`.
- Tests: `tests/campaign.gd` (whole flow, headless), `tests/title.gd` (menu -> Free Play), `tests/campaign_shots.gd` (screenshots of the menu / report).
- Next for the tech campaign: scripted story days (new clients, incidents, unlocks); the Owner campaign (Boardroom app with decision cards, techs working
  the queue as NPCs, cash / MRR / payroll) reuses `Campaign`, `Msp` and `DayReport` with `mode = "owner"`.

### Tech campaign slice 1: skills, PowerShell Academy, backups, story days (`skills.gd`, `story.gd`, computer apps)
- **Skills** (`Skills` autoload; XP only counts in a campaign): POWERSHELL (levels 0-5 from the Academy), NETWORKING, SERVERS, SECURITY, CUSTOMER (levels 1-5 from
  XP at 15/40/80/130/200: fixing earns servers/security XP via `Skills.FIX_XP`, closing tickets earns customer (internal desk tickets: networking), backup
  checks/reruns and the restore earn security). Saved with the campaign. Desktop app **PROFILE** shows skill bars + career stats.
- **PowerShell Academy** (desktop app POWERSHELL): 5 lessons x 3 multiple-choice questions, unlocked in order, 2 of 3 passes and gives a PowerShell level. Study
  happens live (the office keeps running, SLAs tick). Perks by level (`Skills.FIX_SECS` 6/5/4/3/2/1.5 s, `Skills.FAIL` 25/18/10/4/0/0 %): RMM fixes become
  timed jobs with a progress bar and can "not stick"; level 2 unlocks **SCRIPT: THIS CLIENT** (`Msp.rmm_bulk`), level 4 **SCRIPT: ALL CLIENTS**. Outside a
  campaign (free play, tests) fixes stay instant and reliable.
- **Backups** (`Msp.backups`, RMM tab BACKUPS): each client's nightly job can fail silently (8%/day, `Msp.new_day`); you only learn by pressing CHECK (verified
  per day), then RERUN fixes a failed one. Story day 5 breaks Hoot and Holler's silently (`backup_break`), day 7 their email hints at it, **day 9 ransomware**
  (`Msp.RANSOM`, P1 on their server, fix = RESTORE BACKUP, rebooting does nothing): with a good backup +15 score, +5 reputation and a thank-you; without it
  -30 score, -15 reputation, angry email and the boss texts you (`Story.flags.ransom` = saved / lost).
- **Story framework** (`Story.DAYS`: day -> events with `at` clock time and `kind` mail / text / backup_break / ransomware / adobe): events fire once per day when
  `World.clock` passes `at`. Day 1 welcome, day 2 backups chore mail, day 3 PowerShell mail + the easy **"Adobe Reader will not print"** ticket (fix: REPAIR ADOBE
  READER, `Msp.ADOBE`). Still to build, in order: day 4 desktop install + migration (scored), day 10 a client's network rack falls off the wall (same network
  skills, client-site scenario), day 12 server migration, day 13 the 24x7 email server outage with a vendor call running into the night, day 16 a network install,
  day 20 yearly review with the manager (team lead / internal IT job offer / stay at the MSP), then the Owner campaign.
- Tests: `tests/skills.gd` (22 checks), `tests/skills_shots.gd` (screens). `godot/gdlintrc` raises max-file-lines / max-public-methods for the big UI scripts.

### Coworker opinions (`scripts/social.gd` autoload `Social`)
- Campaign only (free play never changes anything). Alan / Garrison / Dan each hold -100..100, saved with the campaign; moods FRIEND (60+), FRIENDLY (25+),
  NEUTRAL, COLD (-15), HOSTILE (-45). **Gains**: chatting (+1, 40 s cooldown per person), every 3rd phone call you answer (+1 to all, a coworker texts thanks),
  closing their desk's outage ticket (+4, desk 6 Alan / 7 Garrison / 3 Dan), the network coming back (+2), every 5th closed ticket (+1 all). **Losses**: cutting
  their desk's network (-2, when the internal ticket opens), reopened tickets (-1 all).
- **Effects**: friendly people greet you with a heart bubble and chat with a heart; cold ones do not wave and refuse "follow me"; hostile ones refuse to chat
  (arrow shakes). Average mood adds +1 / -1 reputation in the day report (`Social.rep_bonus`) and the report has a COWORKERS row (`Social.day_delta`). The PROFILE app
  shows a COWORKERS mood meter. Test: `tests/social.gd`. Planned: the day-20 review quotes them.

### Day 4: desktop install + migration (`Msp.project_*`, RMM PROJECT tab, `Story` kind `install`)
- Story day 4 (10:00) creates "New desktop for Dr. Patel" at Acme Dental + `Msp.start_project`. Eight items live on the old PC (`Msp.INSTALL_ITEMS`; docs, Outlook
  PST and the **xray software** are *key*); 5 are visible, MAPPED DRIVES needs DEEP SCAN, STICKY NOTES needs ASK THE USER, the xray data is found by either.
  RMM PROJECT tab buttons: SCAN OLD PC, DEEP SCAN (8 s), ASK THE USER, BACKUP OLD PC (6 s), SELECT ALL KNOWN (or click items), MIGRATE (timed by item sizes),
  VERIFY (3 s: asking the user reveals everything still missing), HAND OVER. Job times shrink with PowerShell (`fix_secs / 6`) and are instant outside campaigns.
- Score out of 100: key item 20, other 5, backup +10, verified +5, -10 if the SLA was blown; grade S 92 / A 80 / B 65 / C 45. Score `(pts-50)/2.5`, reputation by
  grade (+5 .. -5). Handing over with a key item missing: -8 reputation and -15 score ("lost", the old PC is wiped), or only -3 if you backed it up ("restored").
  Result in `Story.flags.install`; day 5 `install_followup` brings an angry email + boss text when it was lost. Test: `tests/install.gd`.
- Story plan now: day 10 a client's NETWORK RACK FALLS OFF THE WALL (replaces the closet fire: same network skills at a client site), day 12 server migration,
  day 13 the 24x7 email outage + vendor call into the night, day 16 a network install, day 20 yearly review (team lead / internal IT offer / stay), then Owner.

### The rest of the tech story: playbooks, overtime night, yearly review (`playbook.gd`, `review.gd`, `story.gd`)
- **Playbook engine** (`Playbook` autoload, data in `Playbook.BOOKS`): a job is a list of steps, each a situation with choices. A choice has `pts`, `secs` (a timed job
  on the computer, instant outside campaigns), `hours` (the game clock jumps), `flag` (set on the job), optional `req` (`[skill, level]`, shown locked as `[SKILL n]`)
  or `needs` (an earlier flag, e.g. photos). Max points = the best choice of every step; the grade is S 92 / A 80 / B 65 / C 45 (like the install), score `(pct-50)/2.5`,
  reputation by grade; `_outcome()` turns flags into extra rep/score, a client email and **follow-up tickets** that come back the next morning
  (`Story.queue_followup`, spawned at 9:40 by `Story._spawn_followups`). UI = RMM PROJECT tab (`Computer._paint_playbook`, `pb:<choice>` ids). Add a job by adding an entry to
  `BOOKS` + `PROBLEMS` and a Story event `{"kind": "playbook", "book": id}`.
- **Jobs**: day 10 **rack falls off the wall** at Gnarly Gnomes (3 tickets at once: power down / photograph, remount, recable with photos or the cable tester (NETWORKING 2),
  power-on order, verify), day 12 **server migration** at Brightside (check the backups first: if their backup is failing and you skip the check, the cutover is a
  disaster; ROBOCOPY script needs POWERSHELL 3), day 13 **24x7 email outage** at Soggy Bottom Brewing, day 16 **network install** at Hoot and Holler (survey, cable,
  certify, VLANs with POWERSHELL 2, Wi-Fi, document it).
- **Overtime night** (day 13): the job starts at 15:30 and sets `Story.overtime`; `Campaign._process` does not end the day at 17:00 while it is open (hard stop 23:30);
  every choice moves the clock, the cast goes home, and the report pays 30 per overtime hour (OVERTIME row). Vendor call = the step 2 choices (hold music costs hours; asking
  for escalation is better with CUSTOMER 2).
- **Yearly review** (`Review` autoload, after the day-20 report; not shown if you were fired): Morgan's summary of reputation, closed/missed, best skill and how each big job
  went; your coworkers' quotes by mood; then the offers: **BECOME TEAM LEAD** (reputation 60+ and the team's average mood >= 0), **JOIN <best client> AS IN-HOUSE IT** (reputation 45+; the
  client is the one whose job you graded best) and **STAY AN MSP TECH** (always; "on notice" below 45). The choice shows an epilogue, then `Campaign.finish_campaign(ending)`
  records it in `user://mspsim_meta.cfg` (`[tech] ending`), deletes the save and returns to the title. Owner campaign: still locked ("SOON").
- Story days now: 1 welcome, 2 backups chore, 3 PowerShell + Adobe, 4 desktop install, 5 silent backup failure, 7 backup hint, 9 ransomware, 10 rack, 12 migration, 13 email night,
  14 thanks mail, 16 network install, 18 review warning, 20 review day. Tests: `tests/playbook.gd` (paths/locks/follow-ups/overtime), `tests/storyline.gd` (the whole
  campaign played automatically through the review), `tests/playbook_shots.gd` (screens).

### The account manager (Vic) + clients + decision cards (`sales.gd`, `cards.gd`, character `sales_vic`)
- **Vic Marlowe** = 7th character `sales_vic` (`sales_vic_right/left(.aseprite)` + `_anim`, 85 frames, made from Alan's still: navy open jacket + red tie, white shirt, charcoal trousers, black
  shoes, blond-brown slick hair, clean shaven; recolour script lives in the session history, edit the stills and run `ONLY = {"sales_vic"}; dofile("tools/build_anims.lua")`).
  Cast member `Vic` (`World.CAST`, `role = "sales"`, home cubicle_area Seat1, desk 4). He goes out on client visits (`_visit_plan`: leaves through the front door, comes back after
  45-90 s; at lunch he visits a client instead of the conference room). `Social.PEOPLE` has 4 now.
- **Clients**: `Msp.CLIENTS` has 8 (3 new: Piedmont Pediatrics, Rusty Anchor Marine Supply, Zen Garden Yoga); `Sales.active` lists the signed ones (5 at the start); tickets only come from
  active clients and `Msp.pace` is divided by `Sales.workload()` (= active / 5). Each client has a **satisfaction** 0-100 (`Sales.satisfaction`, `adjust`): breach -8, fixed close +5 (+3 late),
  reopen -6, playbook grade S/A/B/C/D = +10/+6/+2/-5/-12. Average mood nudges reputation each day (`Sales.rep_effect`).
- **Selling**: when Vic returns from a visit (`Sales.visit_done`) he may close a deal (chance = `Sales.vic_skill()`: reputation, his mood toward you, owner marketing/pricing): sign a new client
  (`sign_client`, text + mail) or sell a desktop install (`sell_install`: INSTALL ticket + project for a random client). Only in campaigns (not Free Play).
- **Complaints**: a late ticket (breached or < 45 s left) from a client triggers `Sales._process` every 75 game seconds: `World.send_vic_to_player()` routes Vic to wherever you are (a `news` leg
  ends with the NPC step `notify:news`), he talks and `Sales.deliver()` opens a **Cards** decision: PRIORITIZE (ticket P1, mood +6, Vic +1) / IT IS IN THE QUEUE (mood -6, Vic -2) / CALM THEM DOWN
  (+60 s SLA, mood +2). If Vic is out he texts instead (-2 mood).
- **Cards** (`Cards.ask(speaker, text, options, on_pick)`): modal decision dialog (bottom of the screen, top on short screens), Up/Down/Enter, 1-4 or click, queues, options may be disabled with a hint.
  Tests: `tests/sales.gd` (model + the real walk-in), `tests/sales_shots.gd`.

### Owner campaign (`scripts/owner.gd` autoload `Owner`, mode `owner`, save `mspsim_owner.cfg`)
- You run Pixel IT Partners; each campaign day is a **week** (4-minute days, `World.day_len = 240`; ticket arrivals x0.6 so the team can saturate). The tech story does not run (`Story._process` is
  tech-only); the same beats happen to you as **cards** (`Owner.CARDS`, `Owner.DAYS`; options have `need` (cash), `fx` or weighted `roll`, optional `roll_scoped`, `unless`). The team (Alan, Garrison, Dan + hires)
  works the queue by itself (`team_speed()` x training x morale; ticket sizes `WORK` 180/140/100/72 tech-seconds; 7% of closes are premature and reopen).
- **Books**: weekly fee 800/client x pricing x discounts; payroll (techs 650, Vic 750, hires 450) = the **W-2 ratio** (payroll / revenue, target <= 55%); rent 500 + tools 100 + services; **marketing**
  budget; **EBITDA** = revenue - payroll - other costs - marketing (+ one-off job income); EBITDA margin vs the peers' 15%. `Owner.settle()` builds the weekly P&L report rows (REVENUE, PAYROLL (W-2),
  RENT/TOOLS/SERVICES, MARKETING, JOBS AND DEALS, EBITDA, EBITDA MARGIN, W-2 RATIO, CASH, CLIENTS). Cash < -$3,000 = bankrupt (ends the run); reputation 0 also ends it. Premium pricing drifts client
  mood down 4/week, volume pricing up 2; unhappy clients (< 25) may threaten to leave (a next-morning card: discount or let them go).
- **Valuation** (board review, week 20): annualised average EBITDA of the last 4 weeks x a **multiple** (4.0x, +1 if W-2 ratio <= 55%, +1 if margin >= 15%, +0.5 for 6+ clients, +0.5 for reputation 70+) + cash.
  Offers: SELL, OPEN A SECOND OFFICE (cash >= 10k, rep >= 55, 6+ clients), STAY INDEPENDENT. The same `Review` screen, driven by `Owner.review_lines` / `offers`.
- **Marketing**: a weekly budget chosen by cards (weeks 3, 9, 14; none / $150 / $400 / $900). `marketing_bonus()` adds to Vic's close rate and each week has a chance (12% + budget/2500) of an **inbound lead**
  card next morning: take the meeting yourself (60%) or let Vic close it (his odds shown).
- **Peer group** (the "MSP Mastermind", invite on week 2, $500 + $75/week): meetings on weeks 5, 8, 11, 17 with real, usable advice: a group deal on the backup service, a warning that gets the team to check every backup the
  day before the ransomware (week 8 -> 9), "scope projects first" (makes the fixed-price migration quote much safer), year-end benchmarks (EBITDA margin / W-2 / price rise). Shown as PEERS in the Boardroom.
- **Mentor / consultant** (Dana Whitfield, offered on week 6, $400/week, dismissible): shifts 10% of the odds from the worst to the best outcome of every risky card (`Owner.tilted`) and gives a tailored Monday card
  from week 7 (`Owner.advice()`: thin cash, high W-2 ratio, unhappy clients, a backed-up queue, or invest in growth).
- **Boardroom** (computer desktop app, owner only): cash, revenue, payroll + W-2 ratio, other costs, marketing, EBITDA + margin vs peers, client fees/moods, team speed, advisers, company value.
- HUD in owner mode: `WEEK n/20 CASH $x`. Title menu: OWNER CAMPAIGN (+ continue). Tests: `tests/owner.gd` (cards, books, EBITDA/W-2, marketing, peers, mentor, ransomware, a full 20-week auto-run and board review),
  `tests/owner_balance.gd` (dev tool: one strategy per process, natural time, ~2 min: `-- smart|cheap|greedy`; smart (backups, peers, mentor, marketing, hires) wins on reputation and stability, premium pricing + max
  marketing earns more cash but burns clients and reputation), `tests/outside.gd`, `tests/owner_shots.gd`.
- **Test gotcha**: tests that use `user://test_*` saves (campaign, skills, social, sales, owner, storyline...) share files, so run them one at a time (or in separate processes only if they use different saves).
- Ideas left: more peer topics and a mentor "graduation", client QBRs, a second-office phase, cash-flow forecasting, hiring candidates with names/skills, real accounts-receivable (late payers).

### Owner campaign, second pass: the stack, hiring, receivables, business reviews, Vic's pay plan, Boardroom tabs
- **Stack** (`Owner.STACK`, `Owner.stack`, decided by cards on weeks 4 / 5 / 7: PSA, hardware vendor, RMM; switching costs $200-300 to migrate): every option has `cost` (weekly), `speed`, `morale` (% effect on the crew),
  `issues` (ticket-volume multiplier, read by `Msp` via `Owner.issue_mult()`), `sales` (Vic's close rate) and `margin` (hardware resale profit per deal). Cheap PSA (Ticketo Lite -15% speed, -8% morale) and cheap
  RMM make the crew unhappy: weeks 9 and 15 a "grumble" card (switch back / bonus / ignore: a tech may resign), and unhappy crews quit on their own. BudgetByte hardware: +12% sales but +35% tickets and a thin margin;
  DellightCo: -15% tickets, $350 margin, harder to sell; LabRat Gold / OpsForge Pro are faster and happier but dearer. Default stack costs $140/week.
- **Hiring** (`make_candidates`, `_hire_card`): the queue card and Dana's advice open a card with three named candidates (skill 0.5-1.3, wage about 280 + 250 x skill, a trait): POWERSHELL WIZARD (+0.1 speed),
  GREAT WITH CLIENTS (+1 client mood a week), GREEN BUT EAGER (skill +0.04 a week, cheaper), FLIGHT RISK (6%/week quit chance, cheaper), STEADY. Wages count toward payroll and the W-2 ratio. `Owner._staff_week()`.
- **Late payers / accounts receivable** (`Owner.ar`, `SLOW_PAYERS` = Gnarly Gnomes 2 weeks, Rusty Anchor 3, Zen Garden 3; any client with mood < 35 pays a week later): `settle()` invoices every client weekly; on-time
  clients pay into cash at once, slow ones become receivables collected `delay` weeks later (EBITDA is accrual, cash lags). A 3-week payer with an invoice two weeks old triggers a **collections card** next morning
  (firm reminder, payment plan = half now, suspend service = may walk away unpaid, write it off = bad debt against EBITDA). The weekly report ends with `CLIENTS, A/R OWED`; the Boardroom CLIENTS tab shows PAYS SLOW / LATE.
- **Business reviews (QBR)**: weeks 7, 11, 15, 19 (`_qbr()`): picks the client with the lowest mood / highest fee not reviewed in 8 weeks; FULL REVIEW WITH VIC ($250, odds from Vic's skill: mood +12 and a **10% fee increase**
  or mood +6), QUICK CHECK-IN, or just a report.
- **The sales guy's pay plan** (`Owner.VIC_PLANS`, card `vic_plan` week 8, a review card `vic_report` week 10): SALARY ONLY ($750, new clients start at mood 75), BALANCED ($550 + $150 a deal, +0.05 close, start 68),
  COMMISSION-HEAVY ($350 + $300 a deal, +0.12 close, start 58: he over-promises). Each deal (`Owner.on_deal`) pays his commission and banks the hardware margin (2x for a new client's onboarding);
  commission counts in payroll / W-2. Vic's report shows deals and how happy his new clients are; client mood and EBITDA are what the owner judges him on.
- **Boardroom tabs**: BOOKS (cash, revenue, payroll + W-2 ratio, costs, marketing, EBITDA + margin vs peers, A/R, company value, advisers), CLIENTS (fee, mood meter, PAYS SLOW / LATE / REVIEW DUE), TEAM (staff
  with skills / wages / traits, Vic's plan and deals, tool morale), STACK (current choices with their effects). Valuation is now also scaled by `Owner.quality()` (reputation: 40% at worst, full at 90+) and the
  multiple drops for unhappy clients (<50 / <35), a poor name and big receivables, so a cash-grab (premium prices, cheap tools, commission) no longer out-values a well-run company.
- Balance (natural time, `tests/owner_balance.gd -- smart|cheap|greedy`, run strategies in parallel only because the harness uses its own save prefix): smart ~ $37k, 8 clients, mood 99, rep 95, value ~$720k;
  cheap and greedy make cash but end at reputation ~10 and about $500k. `tests/owner.gd` now has ~75 checks (stack, hiring, A/R, QBR, Vic plan, Boardroom tabs, peers, mentor, marketing, a 20-week run).
- `godot/gdlintrc` now allows 2500-line files (the generated UI and owner scripts are big). Ideas left: client QBR as a real conference-room scene with a client NPC, candidate interviews, collections calls, hardware refresh
  cycles / warranty, a reseller rebate program, Vic quotas with a PIP, software the clients buy (security stack upsells).

- Ideas and the MSP research: see `IDEAS.md` (parking lot) and `docs/msp-research.md` (what real MSPs talk about vs what the campaigns cover; Reddit was not reachable, so it uses trade press and the MSP Knowledge Base).

### Owner campaign, third pass: ideas from the MSP research (`docs/msp-research.md`, `IDEAS.md`)
- **Profitability + scope creep**: `Owner.HEAVY` clients (Gnarly Gnomes, Zen Garden Yoga) generate 2x the tickets (`Owner.client_weight`, used by `Sales.pick_client`) until you enforce the scope. `_work_queue` records
  tech-seconds per client; `settle()` turns them into a weekly cost (`COST_PER_SEC` = 2.9 per tech-second) and keeps the last four weekly profits (`profit_hist`, `client_profit`). The Boardroom CLIENTS tab has a PROFIT column.
  Weeks 6 / 10 / 14 / 18: `_profit_review()` finds a client whose profit is under 20% of their fee (needs 2+ weeks of history): RAISE FEE 20% (55% accept, else 10% / they walk), ENFORCE SCOPE, FIRE (rep -1), or keep eating it.
- **Burnout**: `_burnout_week()` (called from `settle`): +4 per open ticket over three, relieved by the after-hours fee (-4), the on-call stipend (-3) and each extra hire (-2); slows the team (`1 - burnout/300`); at 50% Alan warns (hire, or talk
  pay), at 70% a tech may quit. Week 12 card `after_hours`: a $250/hour after-hours fee (8% fewer tickets, clients -3 mood) or a $150/week stipend. Boardroom TEAM tab shows BURNOUT.
- **Vendor breach** (week 14, `_vendor_breach`): the odds of a hit are 0.35 x the RMM's `risk` (LabRat 1.0, SnoutTech Basic 1.5, LabRat Gold 0.8). Notify clients and rotate credentials ($600, safest), wait for the vendor's statement
  (gamble), or switch RMM ($800).
- **The client who said no** (week 6 `_client_no`, week 16 `_client_breach`): a random client refuses two-factor login. Choose a signed waiver, insist (50% they leave), or ignore. Week 16 pays it off: insisted = two-factor login stops the attack (+mood, +1 rep);
  waiver = you help recover ($500) and the paper trail protects you; ignored = they blame you ($1,200-$4,000, rep -2 to -4).
- **Billing leakage**: week 3 `leak_start` silently takes 6% of revenue (`leak`, applied in `weekly_estimate`); the `billing_audit` card ($400, week 5 or the week-11 peer hint) fixes it down to 1%.
- **Sales handover**: a new client queues `_handover_card` for the next morning (full $150 = +8 mood, quick = +2, skip = -6).
- **Peer accountability goal**: weeks 5 / 11 / 17 the group checks your last goal (+2 rep if met, -1 if missed) and asks for the next one (W-2 under 60%, client mood 70%+, receivables under $1,500). Needs the peer group.
- **Maturity level** (`Owner.oml()`, 1 BEGINNING ... 5 INNOVATING, from the Knowledge Base's maturity ladder): counts habits (profit review done, goal checked, handover done, collections handled, backup service, a price change, an
  advisor, an incentive-based pay plan for Vic, faster tools); +0.5 valuation multiple at level 4+. Shown in the BOOKS tab and the board review.
- Balance (natural time, three strategies, ~4 min): smart $32k / rep 88 / value $822k (7.5x); cut-corners $51k cash but rep 22, value $677k; cash-grab rep 16, mood 25, value $479k (4.0x).
- Tests: `tests/owner2.gd` (37 checks). The collections test in `tests/owner.gd` reads cash right after the pick because a queued inbound-lead card can sign a client and change cash.

### 2013-14 realism pass: Windows XP, RDP, CryptoLocker options, a competitor, Lynk, LabRat Nerds
- **Day 4 = Windows XP end of support (April 8, 2014).** The install ticket and Morgan's mail are about XP and Office 2003; the old PC's items are XP-era (Office 2003 files, Outlook 2003 PST, XP drivers for the xray software).
- **RDP open to the internet** (the era's real break-in: most attacks were password guessing). Tech campaign: day 7 playbook `rdp` at Brightside (read the security log, find port 3389 forwarded to the server, audit weak passwords like Summer2013,
  then close the door: VPN, a firewall that auto-blocks repeated failed logins, just changing the port (they find it), or leaving it open; write it up). Flags drive follow-ups ("server hacked again", "our email is blocked as spam").
  Owner campaign: week 7 card `rdp_exposed` (auto-blocking firewalls $600 + $40/wk, VPN $1,200, change the port $100, leave it); until you pick a safe fix `_rdp_week()` rolls a weekly break-in (10% open, 4% weak) costing $2,500 ($1,200 with the backup service), mood -12, rep -3.
- **CryptoLocker, backups give you options.** Tech: on a ransomed machine the RMM session offers RECOVER SHADOW COPIES (40% recovers most files: rep -3, `Story.flags.ransom = "partial"`) and PAY THE RANSOM (70% decrypts, rep -2, "paid"; 30% the key never comes = lost) next to RESTORE BACKUP
  (clean, "saved"). Owner: with a good backup the techs restore quietly; with none, card `ransom_options` (pay $500 / shadow copies / accept the loss) and a loss leads to the lawsuit card. Review lines show PAID THE RANSOM / PARTIAL RECOVERY.
- **Competitor poaching (owner)** (`Owner.poach_risk`, `poach_gaps`, `_poach_week`, `COMPETITOR` = ByteBrothers): per client per week 2% + 12% (mood < 35) or 6% (< 50) + 7% failing backup + 10% / 5% missing updates (patch debt 7+ / 4+) + 3% premium prices, doubled during a competitor campaign (week 18).
  Patch debt (`patch_debt`, 0-10) grows a week at a time and is worked down by spare team capacity (per 60 spare tech-seconds) and by the RMM (`patching`: LabRat 1, SnoutTech 0, LabRat Gold 3 clients a week). A poach attempt next morning is either a **gaps card**
  (their "free IT assessment" lists your failing backups / missing updates / unhappy users: fix the gaps and present a plan $400, match their price -15% for 8 weeks, or let them go) or, **rarer (4%/week, only when you did everything right), a price-only card**
  (show them the value $250, match part of it -10% for 12 weeks, or wish them well). Boardroom CLIENTS tab shows AT RISK and `GAPS BPM` (backups / patches / mood) and who was lost.
- **Winback** (`gone`, `_winback_week`, `_winback_card`): a client lost on price (and happy with you: mood 60+ => 12%/week after 3 weeks, rising 4%/week after week 5, max 35%) often comes back when the cheap service disappoints; one who left for cause rarely does
  (6% at mood 45+). The card lets you welcome them back at the old price (mood +10, rep +1), raise 15% (70% accept, 50% if they left unhappy), raise 15% and put the scope in writing, or turn them down. They return with patch debt 4 (nobody patched them while away).
  A $300 health check (poach card, week 18) reruns every backup and halves every client's patch debt.
- **Lynk 2013** (parody of Microsoft Lync; `Lync` autoload keeps its internal name, desktop app LYNK; HUD `IM n`): presence from the cast simulation (available / in a meeting / away / with a client / offline), coworkers message you (lunch invites, "cover my phones", "how do you fix a print spooler", a thank-you) with quick replies that
  change `Social`; you message them (LUNCH? 85%+ yes for friends, NEED A HAND = a friend fixes your oldest simple ticket but you owe them -1, THANKS!); friends warn you a ticket is about to breach; Morgan (tech) / Marge (owner) answer advice / status. Campaign only.
- **LabRat Nerds** (`Nerds` autoload, desktop app NERDS; a parody of the LabTech Geek forum and IRC): FORUM: 5 threads a day; READ = 2 XP; ANSWER needs the skill level, gives 4 XP and +2 karma (a wrong attempt costs 1 karma). Ranks LURKER / MEMBER / REGULAR / GURU by karma.
  IRC `#labratnerds` = **call a friend**: ASK ABOUT THIS TICKET (which fix; for a ransomed machine without a backup the right answer is shadow copies, not paying) or ASK ABOUT THE JOB (what next in a playbook). Four nicks answer one by one (rodent_rick, gnawer, PS_wizard, old_hand, xX_n00b_Xx, trollbot);
  each is right with `acc x (0.8 + karma/40 x 0.3)`, you see the votes and "n OF 4 AGREE". 45-second cooldown, -1 karma per question, and lurkers (karma < 4) are ignored. Karma is saved with the campaign.
- Tests: `tests/owner3.gd` (XP day, RDP job, ransom options, owner RDP, patching, poaching both kinds, winback), `tests/community.gd` (Lync + Nerds), `tests/community_shots.gd`.

### Hour management, on call and the Tier 1 to Tier 2 growth plan (`shift.gd` autoload `Shift`, `growth.gd` autoload `Growth`)
- **Shift (tech campaign only; `Shift.enabled` is set by the title menu so tests and free play are unaffected)**: an **ENERGY** stat (0-100, starts 80, HUD `NRG n`, PROFILE app, day report `ENERGY` row). It drains about 20 over a full working day
  (`DAY_DRAIN`), sleep gives back 22 each morning (`REST`), and it changes how you work: below 55 RMM fixes take up to 50% longer (`Shift.slow_mult()` in `Skills.fix_secs`), below 45 they fail more (`fail_add()` in `Skills.fail_chance`, up to +18%),
  below 30 a failed fix says "TIRED: TYPED IT WRONG", below 25 at closing your coworkers lose a point of opinion; rested (85+) is 10% faster and 3% safer. Texts warn you at 35 and 20.
- **The commute** (every morning from day 2, `Shift.commute_card`): LEAVE AT 7:30 (energy -6, arrive early; traffic almost never makes you late), AT 8:00 (a gamble: 30% traffic, 15-60 minutes) or SLEEP IN (+5 energy, always at least 20 minutes late). Weeks 2 and 4 add road trouble
  (`WEEK_TRAFFIC`: one lane on Route 9, first snow). **Being late** (`_arrive`): 1-3 tickets already waiting with their SLA clocks aged by `late_min x 1.25`, abandoned calls (`late_min / 12` x -2 client mood), a coworker covers for you (-1 opinion and a Lync message), and 30+ minutes means a text from the boss
  and -1 reputation in the day report. The game clock waits (`World.time_scale = 0`) while the morning cards are open.
- **On call** (`ONCALL_WEEKS` = weeks 2 and 4, days 6-10 and 16-20; Morgan mails on days 5 and 15): on the night before a day that follows an on-call day there is a 60% chance of a PAGER card: GET UP AND FIX IT (energy -10, or -6 with PowerShell 3; 90%+ fixes it, client +4), CHECK THE ALERT FIRST
  (40-75% false alarm depending on NETWORKING, a real one costs -8), or IGNORE IT (55% it was real: client -6, reputation -2, boss text). On-call days pay +$40 on the paycheck.
- **Staying late** (`Shift.can_end_day`, gated in `Campaign._process` after `DAY_END`): with tickets still open you choose GO HOME, STAY 1 HOUR (+$30, -8 energy) or STAY 2 HOURS (+$60, -16 energy); the day stays open until the extra hours pass (the cast has already gone home). The email-night overtime (`Story.overtime`) still wins.
  Day report: ENERGY row (with LATE nm / ON CALL), OVERTIME includes the extra hours, paycheck includes `Shift.pay_extra()`. The review shows an `HOURS:` summary line. Saved with the campaign (`shift` section).
- **Owner side of hours** (cards in `Owner.CARDS`): `oncall_policy` (week 4: rotate with a $100/week pool, one person every week for +$150 which causes quits and burnout, or you carry the pager and lose 8 owner hours) and `flex_hours` (week 10: flexible start times, strict punctuality, or a four-day-week trial that is a 50/50 gamble);
  new fx key `burnout` and burnout relief from `flex_hours` / `four_day`, penalties from `oncall_one` / `strict_hours`.
- **Growth plan (`Growth`)**: the Empath MSP "grow a Tier 1 into a Tier 2" plan. A **gap list** (`gaps()`: low skill levels plus escalations = SLA breaches and reopens, counted by `Growth.note_escalation` from `Msp`), one chosen skill, a helper who catches mistakes, 30 protected minutes a week, stretch tickets, and a measurable result
  (fewer escalations because fixes in the focus skill get safer: `fail_adjust` up to -8%).
  - **Tech**: you are the learner. Day 6 Morgan shows the top three gaps and lets you pick the skill and a helper (their opinion decides how often they catch you); days 7, 12, 17 PROTECTED TIME (TAKE IT = +25% and half an hour of the queue aging; with more than 3 tickets open the full block is disabled and SQUEEZE IT IN gives +8%; SKIP = burnout text);
    days 8, 13, 18 a STRETCH TICKET (TRY IT: success odds from skill level, energy and progress, +30%; a mistake is caught by the helper (+15%) or slips through (client -6, a follow-up ticket); WATCH THE HELPER +10%; ESCALATE counts against you). 100% = Tier 2: skill level +1, reputation +3, helper +3,
    Morgan's mail, and the review's team-lead offer needs reputation 55 instead of 60. PROFILE shows `GROWTH: SKILL n% (HELPER X) ESC n (LAST m)`.
  - **Owner**: you are the only **Tier 3**. About 10% of closed tickets (double for P1/P2) land on you as `owner_used` hours; the pool is 40 - 12 admin - escalations (- 8 if you carry the pager). Under 10 free hours Vic's close rate drops (`vic_penalty`, up to -12%) and marketing works less (`marketing_factor`, down to 50%);
    under 6 Alan warns you. Week 5: choose a learner (Garrison, Dan or a hire) and a skill; each week the protected 30 minutes happens (+18%) unless more than 5 tickets are open (+4% and burnout +3); weeks 8, 12, 16 a stretch assignment (odds 40% + progress/250; caught 60% of failures, else a client sees the mistake).
    At 100% the learner is Tier 2: team speed +5%, escalations fall 25% per Tier 2 tech (max 3), and a raise card ($60/week or a 30% chance they leave). The weekly report has an OWNER HOURS row, Boardroom TEAM shows hours and the plan, and a finished plan counts as a practice for the maturity level.
- Tests: `tests/shift.gd` (commute odds, lateness effects, pager, staying late, drain), `tests/growth.gd` (gap list, plan, protected time, stretch odds, graduation, owner hours, policy cards, schedule). `tests/hours_shots.gd` takes screenshots of the pager card, the morning card and the day report with its ENERGY row (renderer needed, `-- --format=h|v|wide`).

### Team outings: four mini-games (`scripts/outings.gd` autoload `Outings`)
- **When**: tech campaign days 5, 10 and 15 at 16:00 Garrison (the culture owner; Alan in the owner campaign) asks "come out after work?" (YES / NOT TONIGHT; the open tickets freeze and wait, the evening is gone and the day ends afterwards with no stay-late offer: `Shift.skip_stay()`).
  Owner campaign weeks 4, 9, 14 and 19 (it costs money). Free Play / Film Mode: press **O**. `Outings.enabled` is set by the title menu, so older tests are unaffected. Saying no costs 1 opinion with everyone (owner: burnout +2).
  A card then picks the game; the game takes over the screen (`Game.ui_open`, clock frozen) and ends on a RESULT page with 0-3 stars; Esc leaves early (stars -1: -1 opinion with everyone; owner: refund if you leave on the intro page).
- **Bowling** (`$120`): five frames against Alan, Garrison and Dan. SPACE stops a swinging aim marker (green centre is best), SPACE again stops the power bar (best near the green zone); strikes pay a bonus; rank 1 = 3 stars, 2 = 2, otherwise 1.
- **Karaoke** (`$180`): 24 notes fall down four lanes (Left / Up / Down / Right), hit them on the line (perfect within 0.12 s = 2 points, good within 0.3 s = 1, a miss breaks the streak); 75% of the points = 3 stars, 50% = 2, 25% = 1.
- **Escape room** (`$240`): crack a 3-digit code in 120 s and 8 tries; feedback is BULLS (right digit, right place) and COWS (right digit, wrong place). H asks a friend for a hint (as many hints as friends you have, 1-3, using 2+ costs a star); 4 tries or fewer = 3 stars, 6 = 2, solved = 1.
  An owner who gets 2+ stars gets a small permanent team speed bonus (teamwork).
- **Dinner** (`$300`): five rounds; each round pick one of four topics. Alan loves SPORTS and FOOD and dreads WORK DRAMA, Garrison loves MOVIES and WEEKEND PLANS and dreads SPORTS, Dan loves KIDS AND PETS and FOOD and dreads MOVIES (`LOVES` / `HATES`).
  Their faces tell you (a heart, OK or a frown) and `Outings.known` remembers what you learned across outings (saved), so later dinners go better. 24+ of 30 points = 3 stars.
- **Results** (`_finish`): everyone's opinion of you +(1 + stars) (`Social`); tech: energy +(4 + 2 x stars); owner: burnout -(5 + 3 x stars) and `Owner.flags.outings` (two outings count as a maturity practice); 3 stars: reputation +1. Count, best stars per game and the dinner notes are saved with the campaign.
- Tests: `tests/outings.gd` (all four games driven through their public functions, invitations in tech/owner/free play, costs, refunds, saving), `tests/outings_shots.gd` (screenshots, renderer needed, `-- --format=h|v|wide`).

### The outing rooms: bowling alley, karaoke bar, escape room (`tools/outing_sets.lua`)
- Three new 320 px sets (dark, neon): **`bowling_alley`** (a loud 90s carpet, two lanes receding to the pinsetter masking unit, shoe rental counter and cubbies, a ball rack, a ball return between the lanes, a bench and score table you can sit at, an arcade cabinet),
  **`karaoke_bar`** (a stage alcove with curtains and footlights and a big lyrics screen, a bar with a lit bottle shelf and three stools, two round tables with seats, speaker towers, a mic stand and a disco ball hanging in the ceiling band) and
  **`escape_room`** (a dark study: wainscot, grandfather clock, bookshelf, desk with a lamp, safe, trunk, a chalkboard with scribbled clue numbers, a vault door with a keypad, a countdown display and a red alarm light). Pieces are drawn by `outing_sets.lua`
  (`dofile`d from `build_sets.lua`; `ONLY = {bowling_alley = true}` before the dofile rebuilds just some sets; a builder's `post` hook darkens the ceiling). Walk off the left edge to leave for the main floor.
- **Effects** (`fx.gd`, no interaction, `AMBIENT` in `make_godot.py`): flickering neon signs (`neon_bowl`, `neon_shoes`, `neon_karaoke`), the karaoke **lyrics** screen (a title, the current line highlighting word by word with a bouncing ball, the next line below), the disco ball's moving light spots,
  the escape room's **keypad** (shows the digits you are choosing), the red **countdown timer** (shows the game's remaining time) and a pulsing red alarm light and lamp glow. Each room also has a light switch. F-keys in any scene: **F11** bowling alley, **Shift+F11** escape room, **F12** karaoke bar.
- **Outings go there** (`Outings.use_rooms`, set by the title menu): starting bowling, karaoke or the escape room moves the whole cast to the room (`World.start_outing(room, spots)`: Alan, Garrison, Dan and Vic already standing at `Outings.SPOTS`), fades you in, then the game panel opens
  semi-transparent over the room. **TAB** hides the panel so you can look around. Dinner has no room and opens over wherever you are. In a campaign the day ends afterwards (report, then the main floor); in Free Play `World.end_outing()` sends everyone back out and in through the front door and you return to where you started.
- Tests: `tests/rooms.gd` (each room loads with its effects and furniture, a Free Play outing brings the cast, the keypad and timer show the game, going home), `tests/rooms_shots.gd` (screenshots with the cast and a game running, renderer needed).
- **Restaurant** (`restaurant`, a 2014 neighbourhood grill, generic and unbranded): tan striped walls over dark wainscot with green and red trim, two red tufted booths with tables you can sit at, red pendant lamps (glowing), framed team jerseys, tin signs and photos, a chalkboard "2 FOR $20", a host stand, and a long bar with brass rails, tap handles, a lit liquor shelf, red stools you can sit on and two sports TVs (`sports_tv` fx: a field with moving players, a scoreboard strip and a "REPLAY" flash). A flickering neon BAR sign (`neon_bar`). **Dinner** now happens here (`Outings.ROOMS["dinner"]`); **Shift+F12** jumps to it. `tests/rooms.gd` covers it (all four rooms).

### In-room games (`Outings.room_mode()`: the outing was started with `use_rooms`)
- The mini-games are now played **inside the room**; the overlay panel only shows the intro and result pages. The same state machines run (`Outings.g`), but the display and controls are in the scene (HUD strips and a caption bar at the bottom: `_paint_hud`, `caption()`), and keys the game does not use still move you around (`_room_wants`).
- **Bowling**: E steps you up to your lane (the player is placed at `LANE_NEAR`), E stops the aim, E again the power. The ball rolls down the lane and the ten pins (drawn live by `fx` kind `bowl_lane`, no longer baked into the art) fall; strikes make the crew cheer. Your lane is the left one; after your frame
  **Alan, Garrison and Dan bowl on the right lane one at a time** (`_bowl_others`: ball, pins, a bubble and a caption), and the wall screen above the lanes (`bowl_score`) shows everyone's score (and flashes STRIKE!).
- **Karaoke**: you are placed at the mic (`MIC_X`) and sing (`talk`); the note lanes are a strip at the bottom left; every 4th hit in a row makes someone in the room cheer (a heart bubble), 8 in a row and you start dancing (`dance`), a miss drops you back to singing.
- **Escape room**: now a real search. The code is three different digits 1-9 hidden in the room: the **chalkboard** (`clue_board`) shows `p + q = ?` (the first digit), the **wall clock** (`clue_clock`) has stopped at the second digit's hour, a **plaque under the painting** (`clue_painting`) shows the third digit. Press **E** at each (interact zones from `BGFX`; `fx.play()` calls `Outings.interact`);
  **N** asks a friend for a nudge toward the next clue you have not found (3 hints, using 2+ costs a star); **E at the keypad** (`keypad`, by the vault) opens digit entry (the keypad on the wall and the countdown timer show your input and the time left); a wrong code costs 10 seconds; time left decides the stars (70 s+ = 3, 35 s+ = 2).
- **Dinner**: the team is already seated in the booths (`World.start_outing(..., seats)` / `Outings.SEATS`: Alan next to your seat, Garrison and Dan in the next booth, Vic at the bar); **walk to the booth and sit in `PLAYER_SEAT` (E)** to start. Topics are picked from a HUD list; the three diners react with a heart / `!` / dots bubble and a caption.
- **One UI style** (`scripts/ui_style.gd`, `UiStyle`, shared by `Outings` and `PrinterGame`): pages are a bordered panel (`panel_rect` / `panel`) with a blue 9 px header bar, 4 px margins, the 3x5 font at scale 1 and a footer hint line (`footer`); the result star row is `UiStyle.stars` (same size and place on the outing and printer results). In rooms the bottom of the screen is a fixed stack: the control hint bar (`hint_bar`, 9 px), an optional caption bar above it (`caption_bar`, gold edge) and a one-line HUD strip above that (`strip`, 11 px, left-anchored, 164 px wide: bowling FRAME + aim/power bar, karaoke SCORE/STREAK/flash, escape CLUES/HINTS or the CODE digits, dinner ROUND/SCORE). Extra HUD boxes (`box`) sit above the strip: the karaoke note lanes (left) and the dinner topic list (right, 84 px wide so it stays clear of Vic at the bar in the 320x180 h format; checked at wide, h and v, and the printer game and outing pages at h). Nothing is drawn over the clue wall or the bowling lanes.
- **Control hints** (`Outings.hint()`): one `KEY = ACTION  KEY = ACTION` line (two spaces between), the same words as page footer or hint bar: pages `ENTER = START  ESC = SKIP  TAB = LOOK`, `ENTER = CONTINUE`; bowling changes with the stage (`E = STEP UP`, `E = STOP THE AIM`, `E = STOP THE POWER`, `WAIT FOR YOUR TURN`); the printer game has its own per-round line from `PrinterGame._hint()` in the same style. Bowling captions say the same (a second roll in a frame says SECOND ROLL). `Outings.blocks_interact()` makes the player ignore E while bowling runs, so E on the crew's turn no longer opens a chat card. Escape-room clue and keypad zones are 36 px wide (`shape_clue` in `escape_room.tscn`). `tests/outing_ui_shots.gd` (renderer; `OUI_TAG=name`, `-- --format=wide|h|v`) shoots every state.
- Tests: `tests/inroom.gd` (all four games played through the real scenes), `tests/inroom_shots.gd` (screenshots). Without rooms (`use_rooms` off, as in older tests) the games are the overlay versions from the first pass.

### Rebooting and unsaved work (`Msp.rmm_action`, `ALT_FIXES`, RMM action ASK USER TO SAVE)
- Each ticket still has one **proper fix**, but `Msp.ALT_FIXES` lists others that also clear it. The print spooler ticket's proper fix is RESTART PRINT SPOOLER; **REBOOT also works**, only it is not the client's preferred fix: the user is interrupted (client mood -2, the reboot job takes 4 extra seconds) and the fix earns less experience.
- **Unsaved work**: when a problem is created the machine rolls `unsaved` (65%: somebody has documents open). The RMM session has a new **ASK USER TO SAVE** button (shown while a workstation has a problem that is not a dead PC; a 4 second job in campaigns; +2 CUSTOMER XP). `ep.asked` records it.
  Rebooting a machine with unsaved work that you did **not** ask: client mood -6 more, score -3, an angry mail "I LOST MY WORK!", and the result text says so. A PC on a blue screen (reboot is its own fix) has nothing to lose, and a needless reboot (the machine had a different problem) fixes nothing and still costs the work.
- Test: `tests/reboot.gd`.

### Ticket types with more than one valid fix (`Msp.ALT_DEFS`, `alts_for`, `_alt_fix`)
- Every ticket type now has other fixes besides the proper one (the RMM session shows them, tinted, after the proper buttons, only for the machine's own problem: yellow = quick, red = heavy, green = clever; labels are clipped and the rows squeeze when scripts and alts crowd the window). The proper fix stays the best default: full XP (4), never returns, no cost.
  - **Quick workaround** (`kind quick`): about 0.3-0.6x the time, 1-2 XP, and a `ret` chance (35-60%) it **comes back** as a follow-up with the proper fix needed: in the tech campaign via `Story.queue_followup` (1-2 days, `days`), otherwise on a timer (`Msp._later`, 150-300 s). A returned ticket counts as a Growth escalation (`Msp.spawn_return`).
  - **Heavy fix**: 3-7x the time, 3 XP, always works (skips the "did not stick" roll), costs client mood (-1 to -4). `loses` fixes (reimage, rebuild profile) restart the PC: unsaved work you did not ASK USER TO SAVE about costs -6 mood more, -3 score and the "I LOST MY WORK!" mail (not on a blue-screened PC). Server snapshot rollback: mood -3, score -2.
  - **Clever fix**: needs a skill level (`skill`, `lvl`; POWERSHELL uses the Academy level, campaign only), 0.5-0.7x the time, 6-8 XP, sometimes mood +1. CUSTOMER 2 flags restarting fixes that would lose work with a `!` on the button.
  - Table: spooler = CLEAR PRINT QUEUE / REINSTALL PRINTER / PRINT TO COPIER (NETWORKING 2, extends that perk) (plus the old REBOOT); locked out = GIVE TEMP PASSWORD / REBUILD PROFILE / UNLOCK-ADACCOUNT (POWERSHELL 2); slow PC = EMPTY RECYCLE BIN / REIMAGE PC / CLEANUP SCRIPT (POWERSHELL 3); pop-ups = RESET BROWSER / REIMAGE PC / SPYHUNT LOG SCAN (SECURITY 2); blue screen = LAST KNOWN GOOD / REIMAGE PC / SAFE MODE DRIVER (SERVERS 2); server down = RESTART SERVICES / ROLL BACK SNAPSHOT / FIND HUNG SERVICE (SERVERS 3); Adobe = PRINT FROM BROWSER / REINSTALL READER. Ransomware keeps its own options.
  - The PSA text hints at the approaches ("I emptied the recycle bin", "I tried the F8 menu", "restart the services or roll it back to last night") but not at the clever ones. Time is scaled in `Skills.fix_secs_for` by the table's `mult`. Test: `tests/altfix.gd` (every alt fix, the returns, the unsaved-work rule, skill locks); `tests/altfix_shots.gd -- --format=wide|v` screenshots the session.

### Gentle first days (`Msp.DAY_CAPS`, `day_cap()`, `spawned_today`)
- Tech campaign only: random tickets (the timed email spawns, answered phone calls, late-arrival tickets) are capped per day: **day 1 = 1**, day 2 = 3, day 3 = 5, then no cap. The first spawn on day 1 waits 75 seconds so there is time to look around. Story tickets (Adobe, the install, the playbooks) are not counted. Free Play and the owner campaign are never capped. Test: `tests/daycap.gd`.

### QA pass (three read-only reviewers): quality of life, then progression
- **Quality of life**: Cards and the day report ignore a confirm for 0.45 / 0.6 s after they appear and **Space no longer confirms a card** (Enter and 1-4 do; Space is jump). **Day-1 control hints** (`Hints` autoload, drawn by the HUD at the bottom on a timer: movement, E, Tab, the computer, P, the PSA/RMM loop). H (hurt), K (die), R and 1-6 (character switch) only work in Free Play.
  The SLA-breach text says what was lost; the REBOOT button says `(ASK FIRST?)` (or `OPEN DOCS!` / `NOTHING OPEN` with CUSTOMER 2, `USER WARNED` after asking); a tired warning at 55 energy (then 35 and 20); late arrivals leave at least half of each SLA; sleeping in is labelled; staying late pays $50/hour; the review's "COMING SOON" line is gone. Test: `tests/qol.gd`.
- **Skill perks** (`Skills.perk_text`, `fix_secs_for`): SERVERS, SECURITY and NETWORKING each make the fixes that train them 6% faster per level (`FIX_XP`: printer problems now train NETWORKING; a Tier 2 growth graduate is another 25% faster in that skill); SECURITY 3 = **backup watch** (backups show their state without a daily CHECK);
  NETWORKING 2 = outage tickets name the patch panel port; CUSTOMER 2 = you can see whether a user has work open; CUSTOMER 3-5 = SLA clocks tick 5/10/15% slower (`sla_pace`). Level-up texts name the new perk; the PROFILE shows the next special perk. Closing a ticket gives 2 CUSTOMER XP (was 4) so the skills level at a more even pace.
- **Academy**: one PowerShell lesson can be passed per day (`Skills.lesson_day`, "ONE LESSON A DAY") and each costs 3 energy.
- **Earlier choices come back** (`Story` callbacks): day 11 Dr. Patel writes about the desktop install (ok / restored / lost: client mood +6 / +1 / -8), day 14 Atty. Spence about the ransomware (saved = a renewal and +1 reputation, partial, paid, lost = they review their provider), day 20 Morgan brings up your worst job before the review. The review's first page shows all five levels and the outing count.
- **Owner**: the weekly report adds `VALUE (ESTIMATE)` with a path label (`Owner.path_label`: growth / profit / safe pair of hands / just surviving); the Boardroom BOOKS tab shows PATH, RDP exposure and how many clients are at poaching risk (`at_risk_count`). Test: `tests/perks.gd`.
- Reviewer findings **not yet done**: no audio at all, thin replay value (no year 2).

### Talking to people at their desks (`Talk` autoload, `npc.gd`), and NPC reactions
- **E on a coworker in a campaign** (seated at their desk or standing) opens a conversation card (`Talk.start`): **SMALL TALK** (a line in their voice, period-correct: XP end of life, the Target breach, Floppy Bat, Sugar Smash; a coworker who likes you sometimes adds gossip; +1 opinion with a cooldown), **ASK FOR HELP** (reuses Lync's `help`: a friend fixes your oldest simple ticket, others are swamped),
  **ANY TIPS?** (advice from the live game: Alan warns about a failing backup by client name, Dan about a desk with no network, Vic about the unhappiest client, Garrison about SLA misses, else a generic tip; **a friend also teaches you something once a day: +6 XP in their specialty**, Alan servers, Garrison security, Dan networking, Vic customer) and **LEAVE** (Esc picks the option whose id is `leave`: `Cards._pick_leave`).
  Owner campaign: HOW ARE YOU HOLDING UP? (an honest answer from their burnout; asking once a week lowers it by 2) and ANY IDEAS? (from the live books). Cold coworkers are curt, hostile ones will not talk. Free Play keeps the old bubble chat for standing people. Test: `tests/talk.gd`.
- **Network outages** (`npc.gd _update_reactions`, `World._watch_outage`): a seated worker whose desk has no network stops typing (`_rest_anim` returns `sit`) and grumbles with a `!` / `?` bubble every 7-11 s; if any desk stays down for 8 s the first free cast member (Dan first, someone at their desk) walks to the closet to look; if nobody is free it retries until someone is (`plan_for(n, "closet")`, `_closet_leg`) and comes back.
- **Lights off** (`World._on_lights_changed`, `_react_to_dark`, `npc.react_lights`): 2.5 s after you switch a room's lights off, everyone in the room grumbles and one person gets up (if seated), walks to the switch, turns the lights back on and sits down again. Lights switched by NPCs themselves (`World.lights_by_npc`, closing time) are never reacted to. Test: `tests/react.gd`.

### Phone fit pass
- The phone body is wider (aspect 0.68) and starts higher (17% of the screen) so text fits at every format; the Settings note wraps inside the screen, ticket buttons read TAKE / NOTE / DONE, home icon labels shorten (TKTS, SETUP, TEXT) and the dock reads PIXEL IT when narrow, mail shows the sender's name only and wraps long subjects onto two lines. Screenshots: `tests/phone_ui.gd` (`-- --format=h|v|wide`).

### Bigger conference room + the weekly all-hands (`Meeting` autoload)
- The **conference room is now 320 px wide** (`tools/build_sets.lua`, `P.confTableWide` in `outing_sets.lua`): a 220 px table with six chairs on the back side (**six seats**, `Seat1`-`Seat6`, so the team of four still leaves two for you), four chairs in front, a whiteboard, clock, picture, two plants; the door to the main floor is on the right (x 299) and the left edge still leads to the cubicle area; the light switch moved to x 10.
- **All-hands** (campaigns, days 6, 11 and 16 at 14:00): the boss texts everyone to the conference room and the whole cast goes and sits (`World.start_all_hands`, 90 s meeting legs; `send_to_meeting(n, seat, secs)`). At 14:12 if **you are in the conference room** you attend (+1 opinion with everyone, +3 CUSTOMER XP, Morgan briefs you with the live reputation and client happiness and you ask a question: THE CLIENTS (names the unhappiest), TRAINING (+6 XP in your weakest of servers/security/networking), WHAT IS COMING UP (a preview of the next five days' big jobs), or stay quiet).
  If you are not there: reputation -1 and a text (owner: burnout +2). Owner campaign: you give the speech: SHARE THE NUMBERS (burnout -3), THANK THE TEAM (burnout -2, opinions +2), SET A PRIORITY (patch debt -1 everywhere) or KEEP IT SHORT. Attendance counts are saved (`meeting` section). Test: `tests/meeting.gd`.

### Nerf guns (`Nerf` autoload, `dart.gd`, the rack in the cubicle area)
- **Get one**: a pegboard rack on the cubicle area's wall (x 190, between the second cubicle and the whiteboard, clear of the closet door; `nerf_rack` fx item `nerf`): **E** takes a blaster (6 darts, drawn orange in the near hand), E again reloads. **Z fires**, **G** puts it away (Free Play and campaigns; the HUD shows `DARTS n  Z FIRE  G AWAY`, plus the war timer). Darts arc (`GRAVITY`), stick into walls and prop sprites (desks, chairs, monitors: a hit monitor glitches for 1.4 s via `fx.hit()`), or land on the floor where **walking over them picks them up** (they vanish after 45 s).
- **People**: a dart that reaches a cast member hits them (`Nerf.find_victim`): they flinch (hurt animation if standing) and show how they feel (`react_hit`). Opinions move by personality and mood: friends laugh (+2, heart bubble), neutral coworkers +1 (Alan -1: "not at my desk"), cold ones -2. In a campaign a hit also relieves stress (+1 energy, up to 4 a day).
  A happy hit has a 65% chance to start a **nerf war** (45 s): everyone in the room grabs a blaster and fires at you and each other every 2-4.5 s; darts that hit you play a short hurt (the shooter likes you a little more); at the end everyone puts the blasters down, opinions +1 and a toast gives the score.
- Tests: `tests/nerf.gd` (rack, firing, hits, reactions, floor pick-up, the war, sticking, holstering), `tests/nerf_shots.gd` (screenshots). Ideas left: a Friday nerf war event, hiding behind furniture, dart stuck marks that stay, Morgan walking in mid-battle.
- **Long range**: **hold Z** to aim: a dotted arc shows where the dart will land (`aim.gd`), the HUD shows `AIMING n%`, and releasing fires; the longer the hold (1.1 s for full charge) the higher and further the dart goes (`launch_velocity`: forward speed 175 -> 295, lift 14 -> 72), a tap is the quick flat shot. Darts now start at shoulder height (they used to start at desk height and stuck into the desk beside you, which looked like nothing happened) and are bigger with a short trail.
- **Fire-back fix**: a coworker who takes a hit well (friend or neutral; Alan and cold ones do not) now starts the war and fires back within a second; **everybody in the room gets a blaster, including people sitting at their desks** (they shoot from the chair, a little lower), and the NPCs lob when you are far away. Test: `tests/nerf_war.gd` (a real Z press at a seated coworker: the war starts and they fire back).

### Reviewable story: the game bible and the editable text file
- **`docs/GAME_BIBLE.md`**: a hand-written, readable game guide / pitch bible for reviewers (pitch, tone and the 2013-14 rules, cast, core loop, the 20-day tech arc as a table, the big jobs, the owner campaign, things to poke, review questions, what is not built). Keep it up to date when the design changes.
- **`godot/story/STORY.md`**: generated, read-only, line-by-line story in play order (day by day, the big jobs with all choices, the owner weeks, dialogue, tickets, endings), each text ending with its `[key]`.
- **`godot/story/strings.txt`**: every story string (579 of them) from the data tables as plain text under `[key]` lines; editing it changes the game. The `Strings` autoload (`strings.gd`, last in the list) reads it at startup, replaces the text in the live tables, ignores edits that change `%s` / `%d` markers, reports unknown keys, empty text and 2013-14 slips as warnings, and keeps the code's text as the default (`DEFAULT_<NAME>` constants).
  To make that possible the generator turns the story tables into `const DEFAULT_X` plus a mutable `var X = DEFAULT_X.duplicate(true)` (`PATCHABLE` and `make_patchable` in `tools/make_godot.py`; those scripts carry `# gdlint:disable=class-definitions-order,class-variable-name`). Covered: `Story.DAYS`, `Playbook.BOOKS/PROBLEMS`, `Owner.CARDS`, `Msp.PROBLEMS/RANSOM/ADOBE/INSTALL`, `Talk` lines, `Nerds.THREADS/JOKES`, `Lync.MESSAGES`, `Review.QUOTES/EPILOGUES`, `Social.THANKS`, `Shift` texts, `Hints.DAY1`, `Growth.STRETCH`.
  **Still inside the code** (not in the file): job outcome emails and follow-up tickets (`Playbook._outcome`), the day 9/11/14/20 callbacks, all-hands speeches, owner cards built from the numbers, growth-plan prompts. (An attempt to move those out automatically was dropped as too risky; `INLINE = {}` in the generator is the hook.)
- **Tools** (`tests/story_export.gd -- --init|--sync|--doc|--check`, see `godot/story/README.md`): `--sync` after code changes keeps reviewers' edits and adds new strings; `--doc` regenerates `STORY.md`; `--check` lists problems. Test: `tests/strings.gd` (the committed file matches the code, edits apply, bad edits are rejected, sync keeps edits).

### Client profitability, projects and services (`scripts/projects.gd` autoload `Projects`, owner campaign)
- **Hours per client**: `Projects.hours()` turns tech-seconds into hours (15 s = 1 h); a fee includes `fee/66` hours (`included_hours`). `record_week()` (from `Owner.settle`) keeps the last weeks (`hours_hist`); `avg_hours`, `over_hours` show who costs more than they pay. Boardroom CLIENTS has an HOURS column (`+n` over), the profit review card quotes the hours.
- **Profit review answers**: RAISE FEE 20%, ENFORCE THE SCOPE, BILL A CHANGE ORDER (`change_order`: four weeks of over-hours x $95, 60% accept at mood 60+, else 35%, sets `scope_fixed`), OTHER -> `profit_fire` card: FIRE POLITELY (30 days notice), FIRE NOW, KEEP. `fire_client` rolls **bad word of mouth** (unhappy and sudden firings are worst): `wom_weeks` 6, rep -2, a prospect card, Vic closes less (`vic_penalty`). Happy polite exits can bring a referral lead.
- **Services = recurring revenue** (`SERVICES`: backup $110/wk cost $35, patching $80/$25): sold by cards (`_service_card`; backup needs the $600 platform + $100/wk first, flag `backup_service`). They add to `weekly_estimate`, keep backups healthy and cut patch debt.
- **Projects = one-time money** (`TYPES`: desktops, network, server, backup_dr, security): Vic brings a quote card with four methods (fixed price / scope first with a $300 discovery and no creep / time and materials / pass). Fixed jobs creep 30% of the time (change order / hold scope / eat it). Running projects take team capacity (`drag()`, max 35%). Completion banks revenue - hardware (`_complete`), reputation, and backup_dr chains a backup service sale.
- Project income is **left out of the valuation** (`take_week_income()` is subtracted from the history EBITDA); the weekly report has a RECURRING + PROJECTS row; Boardroom has a PROJECTS tab. Saved in the campaign (`projects` section). `practice_scope` counts as a maturity practice.
- Test: `tests/projects.gd`. Boardroom layout not yet screenshot-checked.

### Rodent Nation 2014: the conference trip (`scripts/conference.gd` autoload `Expo`, tech campaign; named Expo because the conference-room scene root is already called Conference)
- A parody of the real RMM vendor's June 2014 user conference (the session list is based on the real agenda). Day 8 Morgan mails the offer; day 12 a KPI progress text; day 16 at 9:12 the verdict mail. KPIs (`Expo.kpis()`, need 3 of 4): reputation 55+, SLA misses under 20% of closes, reopens under 15% of closes, PowerShell level 2 (closed/missed/reopened totals are kept by `Conference` itself via `adjust_report`, saved in the `conference` section).
- **Day 17 is the trip** (`is_trip_day`): the commute card is skipped (`Shift.begin_day`), the office freezes (`Msp.enabled = false`, `World.time_scale = 0`, `Expo` moves `World.clock` itself) and the trip is **walked through the venue** (`tools/venue_sets.lua`, fictional Florida resort conference centre, five sets): `resort_lobby` (atrium, palms, windows onto a pool, check-in desk, banner, couch you can sit on; left door = ballroom, right door = hall), `resort_hall` (corridor with four breakout doors A-D, each with an easel whose text comes from `Expo.sign_lines` through the `session_sign` fx), `ballroom` (keynote stage, big screen "AUTOMATE EVERYTHING", gold chairs, podium, AV desk), `breakout_room` (240 wide: screen, speaker table, rows of chairs) and `vendor_hall` (three booths: free stuff / forum / backup, a rat mascot).
- **Flow** (`_trip_tick` watches which room you walk into): FLY OUT card -> lobby (toast tells you where the keynote is) -> walk into the ballroom = keynote (listen = +3 customer XP, or peek at the queue so the pile at home is smaller) -> `round` stage: the hall door you walk through (`conf_door` var set by the door) picks the session of that round (scripting lab = +1 PowerShell level; patching/monitoring/security/BDR/HIPAA/managed-services/panels give 6-10 XP; round 3 door D is the Why I Stay panel; the **vendor hall has its own EXPO door in the lobby and is open all day**: walk into a booth (`conf_booth`, once each): swag = coworkers like you, forum regulars = +4 karma, backup demo = +6 security XP) -> `raffle` stage: back to the ballroom for the 8% Rock Star Upgrade raffle (energy full, +3 reputation) -> the clock jumps to closing. Clock per round: `CLOCKS` 10:00, 13:00, 15:00. The report for that day is overridden (`adjust_report`: grade A, $150 per diem, +2 or +3 reputation). Day 18 `_home()`: two aged tickets if you did not peek.
- Missed the KPIs: Dan goes, and on day 18 brings back a tip (+6 networking XP). All text is in `TEXT` / `ROUNDS` (editable through `story/strings.txt`, `Strings.ROOTS` has `Conference`).
- Tests: `tests/conference.gd` (drives the whole walked trip through real scene changes), `tests/venue_shots.gd` (screenshots of the five rooms, renderer needed). **Crowd and vendors**: six recoloured background characters (`expo_vendg/vendp/vendo`, `expo_atta/attb/attc`, made from site Alan's stills by a Lua recolour and built with `build_anims.lua`; listed in `EXTRA_CHARACTERS`, never playable) populate the venue (`Expo.CROWD`, spawned by `Expo.populate` from `stage.gd`; `npc.gd` has a `role` export: with a role, E calls `Expo.npc_use`). **Registration** (lobby): E gives your badge; no badge = the usher at the ballroom sends you back. **Vendors** (`Expo.VENDORS`: ShadowPoint Backup, WebWoot Security, SoftSwipe PSA, 2014 parody names) pitch you with four answers (demo +6 XP, hard question +3 XP, SCAN MY BADGE = a raffle entry (+4% win chance) but a follow-up email from them on day 18, or no thanks). **Attendees** (`Expo.CHATS`: five 2014 MSP conversations): learn something (+3/+4 XP), swap business cards (+2 forum karma) or leave; each attendee once per trip. All of it is in the editable story tables. **Ctrl+F12** cycles through the venue rooms (Free Play). Ideas left: sitting in the sessions, hiding your badge from vendors, an owner-campaign version where vendors really sell you tools.

### Ducking (nerf + everyone) (`player.gd`, `npc.gd`, `nerf.gd`)
- **Hold S or Down to duck** (player state `duck`, the crouch frame, no walking while held, not while aiming). A ducking body is `Nerf.DUCK_TOP` (40 px) tall instead of 84, so darts at chest or head height fly over it (`Nerf._hits`; a "DUCKED!" toast, `Nerf.dodges` counts them) while low shots and lobs coming down still hit. Picking up a blaster shows the keys in a toast.
- **Coworkers duck** (`npc._duck_tick`): a standing, non-seated person whose way a dart is flying at (within 80 px, heading toward them, at body height) ducks for 0.9 s with a 60% chance per dart (rolled once per dart per person); shooting at a ducker toasts "MISSED! THEY DUCKED." In a nerf war the crew now dodges your darts about half the time, and you can duck theirs.
- Test: `tests/nerf_duck.gd` (the player's hit box with S held, a coworker as a lower target, and ducking about 12 of 20 darts in an empty hall).

### RMM list scrolling
- The LabRat RMM endpoint tree (`Computer._rmm_list`) now scrolls: mouse wheel or Up / Down (`Computer.scroll_list`, `rmm_scroll` in pixels), with a thin scroll bar on the right edge. Before, only the first rows fit and clients lower in the list (Piedmont Pediatrics and the other late signers) could not be reached. Test: `tests/rmm_scroll.gd` (8 clients open, all 32 machines reachable). Other long lists (PSA tickets, backups) were not changed.

### Onsite visits and client sites (`scripts/onsite.gd` autoload `Onsite`, `tools/client_sets.lua`)
- **Sites (rooms)**: every site is four or five rooms: the **main office** (entry door on the left = leave, OWNER door beside it, SERVER door on the right, and EXAM 1 / EXAM 2 doors for dental and vet), the **IT closet** (the network rack and the server tower, where the cabinet and server jobs happen), an **owner / VIP office** (executive desk, VIP PC, the owner NPC) and **exam rooms** (dental chair + x-ray unit, or a vet exam table + dog; shared between the two exam doors via the `exam_return` var). Scene names: `site_<type>_<skin>` (main), `site_<type>_closet_<skin>`, `site_<type>_office_<skin>`, `site_<type>_exam_<skin>`. **Sites**: six business types, each built twice from one layout with a *skin* (colours + the name on the sign), so a prospect can look like a different business from the client: `site_<type>_<a|b>` for `dental`, `law`, `vet`, `arch`, `realty`, `trailer` (the demolition company: two office trailers). `Onsite.SITES` maps a client index to a type and skin (a = the client; `site_scene(client, prospect)` gives the b skin). Clients: Acme Dental 0, Brightside Realty 1, Hoot and Holler Law 3, and three new prospects in `Msp.CLIENTS`: Paws and Claws Veterinary 8, Lindqvist and Moss Architects 9, Iron Mule Demolition 10 (`Sales.MAX_CLIENTS` is still 8 active, so these start as prospects). To add a skin or a type: add it to `SKINS` / a builder in `client_sets.lua`, rebuild with `build_sets.lua` (set `ONLY` to the `site_*` names), add the site to `SITE_TYPES` / `SITE_OBJECTS` in `make_godot.py`.
- **The tech loop** (tech campaign): `Onsite.create_job(client, id)` creates a ticket whose fix is `onsite_<job>` (the RMM cannot fix it; the session says so). Jobs turn up on days 6, 11, 15 and about half the other days from day 3 (not on the playbook days). The PSA ticket shows **GO ONSITE** in place of the PROGRESS button; a card asks if you want to drive (45 min each way, `DRIVE_HOURS`; `_away()` moves `World.clock`, takes `SLA_PER_HOUR` seconds off every other ticket per hour and some energy; new tickets pause while you are away and the day cannot end, `Campaign` checks `Onsite.busy`).
- **A client PC is not your desktop**: E on a PC (front desk, exam room, owner) opens THEIR computer (`Computer.open_site`, app `site`): their name and colours on the wallpaper, a computer name like ACME-EXAM1 and their user, their practice software (`SITE_APPS`: DentalDesk Pro, PawTrack, CaseLine, DraftBox CAD, ListingHub MLS, DispatchPlus), Outlook with the ticket's request at the top, Computer (shows NO NETWORK when the switch is down) and a TOOLS window with DIAGNOSE AND FIX that starts the job. - **At the site**: E on the equipment (`UseObj*` zones from `SITE_MAIN` and the room tables in `make_godot.py`: the PC, the printer or plotter, the cabinet and server in the closet, the exam room PC and the x-ray sensor, the owner's tablet) starts the job (`Onsite.JOBS`: dead switch, failing RAID drive, grinding printer, dead PC, hub replacement project): choose how to do it (time, a success chance, skill XP). The right fix closes the ticket on the spot; a half fix lets you try again. E on the door leaves (drive back; leaving unfinished costs client mood -6). A staff member stands in each office (`STAFF_AT`, `role site:staff`). **Mishaps** (`Onsite.EVENTS`, once per visit, 55%): the vet clinic's dog pees on the front desk PC and kills it, the dentist's patient wants the x-ray first, the architect's plotter eats a forty-foot roll, the foreman's space heater trips the breaker, and so on. All text is in the editable tables.
- **Client site polish**: the door plates say what is behind each door per business (`PLATES` / `EXAM_PLATES` in `client_sets.lua`: dental ENTRY / DENTIST / SERVER and CHAIR 1 / 2, law LOBBY / PARTNER, vet LOBBY / DOCTOR and EXAM 1 / 2, arch ENTRY / PRINCIPAL, realty ENTRY / BROKER, trailer OFFICE / FOREMAN; plates are 8 characters or fewer, longer words widen the plate). The **site signs carry the full business names** (the a skins use the `Msp.CLIENTS` names, the b skins the `Onsite.SITE_PROSPECT` names that the PC wallpaper shows; `S.name` is the sign, `S.short` the front desk plate; signs widen to fit the text). **Realty** has a coffee bar (`P.coffeeBar`, y-sorted prop `coffee_bar_<skin>`), a sign-in clipboard (`P.signInSheet`) and the SOLD sign hung on the wall; **the architects have a reception desk** (`recep_desk_arch_<skin>`) in place of the cubicle desk, and the arch window moved right so the long sign fits. The scenes `site_arch_*` and `site_realty_*` had never been regenerated for these pieces; they now use `recep_desk_arch_<skin>` (desk label LINDQVIST / NORTHLIGHT, the chair stands behind it) and `coffee_bar_<skin>`. **Interact zones** (`BGFX`, kinds `onsite_coffeebar`, `onsite_signin`, `onsite_recep`; lines in `Onsite.PETS` keys `coffeebar`, `coffeebar_full`, `signin`, `recep`, `Onsite._site_line`): E at the coffee bar toasts a line and gives you a coffee a second later (`player.give`, like the office machine; a held coffee gets the `coffeebar_full` line), the sign-in sheet and the reception desk only toast a 2013-style line (no game effect). The sign-in and reception zones are `low_priority` so they never steal E from the PC. **Plotter text**: `PrinterGame.start(cb, kind)`; `Onsite._printer_kind()` gives `"plotter"` at the architects, which overlays `PLOTTER_TEXT` on `TEXT` (media jam, ink tanks, rolls: `PLOTTER_TRAY`) and asks `PLOTTER_QUESTIONS`; other printers use the defaults. Both tables are patchable in `story/strings.txt`. Rebuild the art with `build_sets.lua` (`ONLY` = the `site_*` names; its paths are hard-coded to the main checkout, so in a worktree run a copy of `tools/` with the paths changed).
- **E priority at sites** (`player.nearest()`): nearest zone by x wins as before (`low_priority` +14, Tab selects), but a site person (`npc.role` starting `site:`) now gets +20, so standing at a door, the printer or the PC gives you the equipment and not a staff small-talk card (Tab still reaches the person; alone with someone E talks). Site people also have a narrower talk zone (30 px, set in `Onsite.populate`, was 46). Test: `tests/prio.gd` (closet equipment, plotter next to staff, PC vs reception desk, door, owner). Trailer sign / window / map and the vet sign were moved apart (no overlap).
- **Ctrl+F11** cycles through all 12 sites in Free Play. Test: `tests/onsite.gd` (the whole visit and every site loads). Ideas left: sales / owner visits (check-ins and prospect pitches) at these sites, prospect-skin visits, more jobs per site type, onsite projects that use the Projects quotes, a dog that really walks around.

### Female characters (`tools/make_fem.lua`)
- Twenty-eight women built (11 first, 14 for client staff, 3 more after the QA pass) on the shared 40x64 body (same layers, so every animation works): `office_maya` (a new Tier 1 tech, ponytail, lilac polo), `office_morgan` (the manager: bob, charcoal blazer), `office_marge` (the bookkeeper: curly grey hair, glasses, mustard cardigan, brown skirt), `client_karen` (Brightside Realty owner), `client_mina` (Zen Garden Yoga), `client_brandt` (the vet), `client_hygienist`, `client_paralegal`, and the conference people `expo_dee` (WebWoot), `expo_priya` (gnawer), `expo_tina` (old_hand).
- `make_fem.lua` copies `site_alan_right`, recolours skin / hair / clothes, draws a hairstyle on the Hair layer (`long`, `bob`, `ponytail`, `bun`, `curly`, with a 1 px outline), changes lips, turns the trousers into a skirt (with tights) or leggings, shows a blouse under blazers / cardigans, copies Dan's glasses layer, and **mirrors the right file into the left file** (flip every cel, `x = W - oldX - width`). Add a woman = add an entry to `CHARS` and run `ONLY = {"name"}; dofile("tools/make_fem.lua")`, then `ONLY = {"name"}; dofile("tools/build_anims.lua")`, add the name to `EXTRA_CHARACTERS` in `make_godot.py`, rerun it.
- Used now: client staff and owners at the sites (`Onsite.STAFF_AT` / `OWNER_AT`), vendors and attendees at Rodent Nation (`Expo.CROWD`), and **Morgan (tech) or Marge (owner) standing at the whiteboard during the all-hands** (`Expo._boss`, role `boss:*`). Not used yet: Maya is not a cast member (the cast in `World.CAST` is Alan, Garrison, Dan, Vic: adding a fifth needs a desk, an agenda, Social / Lync / Talk entries and test updates). Test: `tests/fem.gd`.

### Site people and pets
- **Who works where** (`Onsite.CAST_AT`, per site type, skin and room): medical and vet offices are staffed mostly by women (receptionist, hygienist / vet tech, assistant; vet and dental owners can be women), and the **b skins (competitors / prospects) are different people** from the a skins. Law, architect, realty and the demolition trailers mix. 14 more women were added to `make_fem.lua` for this (`client_dentrec_a/b`, `client_dentasst`, `client_denthyg_b`, `client_dentdoc_b`, `client_vetrec_a/b`, `client_vettech_a/b`, `client_vetdoc_b`, `client_paralegal_b`, `client_agent_a/b`, `client_designer_b`).
- **You can always pet the animals** (`Onsite._pet`, zones `onsite_dog` / `onsite_cat` / `onsite_fish`): a dog in the vet's front office, exam room and owner office, a cat on the counter, the exam table and the sofa (new `P.cat`), and the dental office's fish tank (you can tap the glass). E plays the reach animation with a heart, a line from `Onsite.PETS`, +1 energy (3 a day in a campaign) and +1 client mood for the first pet of a visit. `Onsite.pets` counts and is saved. Tests: `tests/onsite.gd` (the vet has two women, you can pet both animals, a competitor's dental office has different people). `tests/site_shot.gd -- --scene=site_vet_a` takes a screenshot of any room.

### The sales bell (`fx.gd` kind `bell`, main floor wall)
- A brass **sales bell hangs high on the main floor wall** (above the open desk, art 124,36). **Vic rings it when he closes a deal**: `Sales.visit_done()` now returns true on a sale and sets `Sales.last_deal`; `World._finish_leg` then gives Vic a `bell` leg as soon as he is back inside (walk to x 132, `use:salesbell`, reach, ring). Anyone in the office sees it swing and a "DING DING! VIC CLOSED ACME DENTAL GROUP!" toast appears. The **player cannot reach it** (E says TOO HIGH TO REACH, `interact.gd`); a **foam dart rings it** (`Nerf.hit_bell`, a full-ish lob from the right side of the office, the dart bounces off, Vic's opinion +1). The bell draws itself (swing, sparkle lines, DING!) with a code-drawn brass bell. Test: `tests/bell.gd`. `tests/site_shot.gd -- --scene=main_floor` screenshots it ringing.

### The printer mini-game (`scripts/printer_game.gd` autoload `PrinterGame`)
- Onsite, **printers fight back**. A small overlay game in three rounds (`PrinterGame.start(callback)`, the callback gets 0-3 stars): **PAPER JAM** (a marker sweeps a bar, SPACE stops it: green = a clean pull, yellow = it holds, red = it tears and leaves a scrap = a mistake; three spots, faster each time), **TONER** (install the four cartridges in the order the printer asks with Left / Right + SPACE, wrong one = mistake, then shake it with A and D alternately in 5 seconds), **TEST PAGE** (two error messages on the little display from `QUESTIONS`: PC LOAD LETTER, TONER LOW, ERROR 79 SERVICE, PRINTER OFFLINE, PAPER MISMATCH; pick 1 / 2 / 3; hitting the printer for PC LOAD LETTER works 1 time in 20). 0-1 mistakes = 3 stars, 2-3 = 2, 4-5 = 1, more = 0. Esc gives up.
- **Used by** `Onsite`: the printer job's fourth option **OPEN IT UP AND FIGHT IT** (`game: "printer"`): the stars fix the printer (1+ stars close the ticket, servers XP 4 per star, 1.1 hours minus 0.25 per star of onsite time); and **practice**: E on a site's printer with no printer ticket offers the game (a toast with the stars). Texts and questions are patchable (`TEXT`, `QUESTIONS`). Tests: `tests/printer.gd` (perfect run, bad run, giving up, the shake timing out, the onsite job, practice), `tests/printer_shots.gd` (screenshots).

- **PC LOAD LETTER and prayer** (`printer_game.gd`): after the jam the printer's display says **PC LOAD LETTER** (TRAY 2) and you must load the right paper: LETTER, LEGAL, A4, or HIT IT (5% works) with Left / Right + SPACE (a wrong stack is a mistake). **P prays to the sysadmin gods** at any point (3 prayers per run, `faith`): 55% a blessing (`blessed`: the next mistake is forgiven, and the green and yellow zones widen), 25% nothing ("the gods are busy restarting a domain controller"), 12% a mistake is added, 8% the marker speeds up. Prayer lines are in `PRAYERS` (patchable). The test page now has four error questions (PC LOAD LETTER moved to its own round).

### The rubber duck (`rubber_duck` piece, `fx.gd` kind `rubber_duck`)
- A **rubber duck sits on the player's desk** (main floor open desk, between the monitor and the phone, art 115,73, y-sorted prop drawn by `P.rubberDuck()` in `build_sets.lua`). E on it (it is a low-priority interact zone, `interact.gd low_priority`, so it never beats the monitor): the player reaches up and the duck squeaks (hops, "SQUEAK!", 55%), stares blankly ("..." and a toast, 30%) or listens while you explain the problem (a toast about rubber duck debugging, 15%); every 10th press "THE DUCK HAS HEARD ENOUGH FOR TODAY". It does nothing else. Test: `tests/duck.gd`.

### The front door goes to the client sites (`Onsite.offer_door`, `door.gd special = "front"`)
- The main floor's front door (it was locked, it only led to the hallway art) is now **E = "Where to?"**: the van is out front. A card lists the client sites (`Onsite.door_clients()`: in a campaign the clients you serve plus any with an open onsite ticket; in Free Play all six site clients), **the client of the onsite ticket you are working comes first and is labelled with its ticket** (`Onsite.focus_ticket()`: the ticket selected in the PSA if it needs an onsite visit, else the oldest open onsite ticket; its title says "Ticket #12 needs you onsite at ..."). Two sites per page, MORE SITES... / BACK, STAY HERE (Esc). Picking a client with an open onsite ticket goes through the normal dispatch card and the job; a client with nothing to fix is a **free visit** (drive card, then walk around: pet the animals, talk to the owner, use their PC). Free Play trips take no game time and leave `Msp.enabled` / `World.time_scale` as they were (`_prev_msp`, `_prev_scale`). Test: `tests/onsite.gd` (the front door section).
- **Drive times** differ by client (`Onsite.DRIVE_MINUTES`: Acme Dental 20, Hoot and Holler 25, Lindqvist and Moss 30, Brightside 35, Paws and Claws 50, Iron Mule Demolition 70; `DEFAULT_DRIVE` 45): the front door menu shows the minutes and the dispatch cards quote them; the real trip varies with traffic (-15% to +25%, in 5 minute steps, never under 10) and the way back is its own roll (`_trip_minutes`, `_back_min`); the arrival and return toasts say how long it took.
- **Traffic follows the clock** (`Onsite.traffic_factor`): morning rush before 9:30 is x1.35, lunch traffic 11:30-13:30 x1.2, the evening rush from 16:00 x1.45, otherwise clear roads. The front door menu and the dispatch cards show the current estimate (`estimate_minutes`) and the traffic label ("EVENING RUSH HOUR"), the real trip adds -10% to +15% on top, and the way back is rolled at the time you actually leave (leaving a site at 4:30 means a long drive home).

### Maya joins the cast (`World.CAST`, tech campaign and Free Play)
- **Maya** (`office_maya`, the ponytail Tier 1 tech) is the fifth cast member: main floor desk 2 (`Seat2`, next to Dan), `npc.DESKS` / `Social.DESK_OWNER` desk 2, `Social.PEOPLE`, a Lync contact, a Talk voice (greeting, small talk, tips; specialty `people`; `_state_tip` warns about a ticket under 60 seconds from breaching), a Nerf reaction, and a conference seat (`Seat5`, so the team of five leaves one seat for you). She goes to lunch, meetings and the closet like the others (`World._make_char`).
- **Owner campaign:** she is not on your payroll, so `World.apply_roster()` removes her from `World.chars` when an owner campaign starts (`begin_next_day`) and restores her when a tech campaign or Free Play starts. Not done: Maya as the owner's first hire; Maya in the dinner / bowling games (`Outings.DINERS` and `BOWL_SKILL` still list three coworkers). Tests updated for five cast members (`meeting`, `react`, `social`, `community`); new `tests/maya.gd`.

### Sales and owner visits, and the walk-around (`Onsite.start_visit`, `inspect`, `_meeting`)
- **Business reviews at the client's office** (owner campaign): the week 7 / 11 / 15 / 19 review card (`Owner._qbr`) has a fourth option **GO ONSITE FOR THE REVIEW (n MIN)** for clients with a site. You drive out (`Onsite.start_visit(client, "qbr")`), walk to the owner's office (OWNER door) and talk to the owner (E): **walk through the numbers** (mood +6, 40% a 10% fee increase), **ask what keeps them up at night** (mood +10 and they mention a problem: a finding card) or **offer a managed service** (a service proposal card is queued).
- **Prospect pitches** (owner campaign): the inbound lead card now names the prospect it will sign (`Sales.sign_client(wanted)`; it used to sign a random client under the wrong name), prefers prospects that have a site, and has a third option **PITCH THEM AT THEIR OFFICE**. You drive to the **b skin** of their site (the prospect's own office, different people), meet the owner (E): sample report 55%, ask about their pain 80% if you already found a problem while walking around (else 50%), promise the moon 45% (and they start unhappy). A win signs that client.
- **The walk-around** (`Onsite.inspect(obj)`, `FINDINGS`): on any visit, E on equipment that is not the job's (the closet cabinet and server, the printer, the PC through its TOOLS > LOOK AROUND button, the x-ray unit...) may turn up a problem (70% on a review or pitch, 30% during a tech job). The card offers **LOG A TICKET** (a ticket for the team to work: a remote fix like clear_temp / av / spooler, or an onsite job; client mood +2), **SELL IT AS A PROJECT** (owner: a project quote card tomorrow, `Projects.offer_project`) or **MAKE A NOTE FOR LATER** (40% a day it breaks on its own as a P2 with a mood hit: you saw it and said nothing). Each piece of equipment is checked once per visit. Free Play has the cards but creates no tickets. Test: `tests/visits.gd`.

### QA pass (July): fixes from three read-only reviewers (controls and fairness, immersion, progression)
- **Bugs fixed**: STAY AND FINISH really stays (the leave card's `leave` id, the Esc default, is now STAY; leaving before the owner meeting warns you); a clock jump past 14:12 (a trip) no longer costs you the all-hands (`Meeting._process` marks it done); the sales bell zone is low priority (it stole E from the phone); `Cards.pick` no longer clears `Game.ui_open` while the Computer / Phone / PrinterGame / Outings screen is open; toasts wait while a card covers them (`Hints._process`); growth offers do not fire on the trip day and story follow-ups have no end of window; printer game: Esc on the intro backs out free (`stars = -1`), Esc on the result is ignored, the result page ignores input for 0.5 s; ps101 at the conference respects the one-lesson-a-day rule and level cap 3; booths give nothing outside a campaign; closed tickets are not dispatched; `Onsite.reset` clears visit state and `_missed` is saved; onsite server jobs use a server endpoint.
- **Balance**: time away ages other tickets by `SLA_PER_HOUR x day_len / 600` and never below 35% of an SLA (`_away`), dispatch cards say how many open tickets will be close to breaching (`at_risk`); onsite jobs skip days 7, 9, 10, 12, 13, 16, 17, 18, 20, only one open at a time, early (before 11:15) on all-hands / outing days, with a day-3 intro mail from Morgan; failed (`chance 0`) options cost client mood; walk-around: one logged ticket or project per client per day, no tickets or projects at a prospect (only "tell them"), notes break less often (25%, mood -2), project quotes are deduplicated and capped at two; the dart bell gives Vic's opinion once a day, dodge toasts are rate limited.
- **Text and cast**: prospect (b skin) PCs show the prospect's own host name and owner (`OWNER_B`), staff and owner lines vary (`STAFF` lists, `_owner_name`), anachronisms fixed (architect job numbers 13-/14-, Priya's XP line, "700 percent"), Marsh renamed, repeated jokes varied; nine more characters (`expo_attd/atte/attf`, `expo_vendh/vendi/vendj`, `client_designer_a`, `client_attorney_b`, `client_foreman_a`) so the competitor skins have different people and the casting is less stereotyped (`Onsite.CAST_AT`); the vendor hall booths are WEBWOOT, SHADOWPOINT and LABRAT NERDS with their vendors standing at them, the INFO board and mascot no longer collide; the conference trip shows a standing objective line (`Hints.objective`).
- **Finished afterwards**: the front door menu wraps around (MORE SITES... / BACK TO THE FIRST PAGE); the PROFILE app shows the Rodent Nation KPIs and what is still needed (`Expo.passed`, `Expo.kpis`); session XP is 8 (was 10); the team outing invitation is still owed after a trip that gets you home after five (`Outings.invite_due`, the day waits for it); more props in the sites (waiting chairs, tooth poster, x-ray light box, a vet scale, a first aid sign, a water cooler, the law scales statue, the trailer owner's yard window); different animals in each room (a golden retriever in the vet's front office, a beagle in the exam room, a tan dog in the owner's office; a gray cat on the counter, an orange cat on the exam table, a black cat on the sofa).
- **Still open from the reviews**: nothing (the site polish items were finished, see "Client site polish" under Onsite visits).

### Three more tech-campaign stories (`Playbook.BOOKS` ceofraud / no2fa / bus, days 8 / 14 / 19)
- **Day 8: WIRE REQUEST FROM THE BOSS** (`ceofraud`, Hoot and Holler, P1): a paralegal forwards an email that looks like Atty. Spence asking to wire $38,000 from the trust account (2013-14 "CEO fraud"). Five steps: read the headers / call him (the lookalike domain), find the hidden forwarding rule and the overseas login, contain it (remove the rule, reset the password, end all sessions), have the firm call the bank, leave a call-back rule and two-factor login. Wiring it costs reputation -10 and the money; replying to the scammer, deleting the evidence, a half fix or a quiet fix each queue follow-up tickets.
- **Day 14: THE CLIENT WHO SAID NO** (`no2fa`, Soggy Bottom, 13:00): Lucy refuses stronger logins. Show her a leaked password list, get a signed waiver, insist, or let it go; then roll it out phased (needs the showing) or all at once (needs the insist). Ignoring her brings a phishing / spam P1 and a mood hit; showing her and phasing it earns +2 reputation.
- **Day 19: THE ONLY PERSON WHO KNOWS** (`bus`, Acme Dental): the firewall fix needs Alan (the owner who built it), who is out sick. Docs portal / sticky note under his keyboard / call him (CUSTOMER 2) / factory reset it (the internet goes down for 90 minutes, Alan texts you). Documenting it in the vault earns +2 reputation and Alan's opinion +3.
- All three use the playbook engine (`BOOKS`, `PROBLEMS`, `_outcome` flags, `Meeting.BOOKS`, `_callback_worst` names) and live in the editable story tables. Test: `tests/stories3.gd`.
- **Bug found by the owner balance run**: `Sales.visit_done` (the sales bell change) treated `sell_install()`'s ticket id as a client index and crashed on every install sale (a "get index 10472" error from `World._finish_leg`); fixed (`last_deal` is set per branch). The regression suite had never exercised that path; `stories3.gd` does now.
- **Owner balance re-check** (`tests/owner_balance.gd -- smart|cheap|greedy`, `NOPROJ=1` environment variable turns projects and services off for A/B): after projects, services, onsite reviews and the bell, results are noisy but the picture is the same as before: smart ends with reputation 30-100 (typically 85+), value $218k-$815k; cheap ends with reputation 0-71 (usually under 30) and value $343k-$1,037k; greedy reputation 10-33. Valuation alone can let a cash-grab beat the careful strategy on a good run (it did before projects existed: with projects off, cheap reached $839k against smart $488k), so judge by reputation and mood too. Variance between runs is large (a single bad event can halve a run); do three or more runs per strategy before concluding anything. Open idea: weigh the valuation's quality factor more heavily at low reputation.

### Quiet-day vignettes (`Story.VIGNETTES`, event kind `vignette`)
- Seven small 2013-14 moments for the quiet tech days, each a card with 2-3 choices and a result card: day 2 Karen's new iFone 5S, day 5 Heartbleed, day 7 Sugar Smash at Acme's front desk, day 12 a PSA vendor's pizza pitch, day 14 "where is Start" (Windows 8), day 18 Morgan's self-review question, day 19 Alan returns with donuts. Option `fx` keys: `xp [skill, n]`, `mood [client, n]`, `mood_all`, `rep`, `social {name: n}`, `social_all`, `energy`, `hours`. Text is in the editable story tables (`Story.VIGNETTES`). Test: `tests/vignettes.gd`.

### Difficulty and seeds (`scripts/difficulty.gd` autoload `Difficulty`, roadmap item 1 of `docs/replayability-ideas.md`)
- **What it is**: a tier (`easy` / `normal` / `hard`, default normal), a run seed and one seeded random stream per system. `Difficulty.f("karaoke.gap")` (and `i()`) reads a number from `TABLE` (`key: [easy, normal, hard]`, the ONLY place the numbers live; `at(key, tier)` for tests). Normal is exactly the old constants (`tests/difficulty.gd` asserts it). Keys: `karaoke.gap / perfect / good`, `bowl.opp_skill / aim_speed / power_speed`, `escape.time / wrong_penalty`, `dinner.reveal` (faces shown), `printer.speed / zone / questions`, `nerf.gap` (x the coworkers' shot interval). Energy, family and health are never inputs; a harder tier only changes numbers, keeps every perfect run reachable (a test checks notes stay apart, windows nested, 3 escape stars after two slips) and adds no content.
- **Randomness**: `Difficulty.rng("stream")` is one persistent `RandomNumberGenerator` per stream name (`karaoke`, `bowl`, `escape`, `dinner`, `printer`, `nerf`, later `events`), seeded from the run seed; `rng_for(stream, salt)` makes an independent one (a day, a setup); `shuffle(list, stream)` / `pick(list, stream)` replace `Array.shuffle()` / `randi()`. `seed_run(n)` fixes the seed (tests, a future daily seed) and restarts every stream; `new_run()` (called by `Campaign.new_game`) rolls a fresh random 24-bit seed unless `seed_run` pinned one; `seed_text()` is the 6-digit hex shown as "RUN 4F2A9C". The mini-games (`Outings`, `PrinterGame`, `Nerf`) no longer call the global `randf/randi/shuffle`; `Msp`, `Owner`, `World` and `Onsite` still do.
- **Title menu**: the character select screen (every new run, tech / owner / Free Play, both steps) has a `LEVEL < NORMAL >` chip (top right; under the heading in narrow portrait). **Up / Down (W / S)** or a click on an arrow change it; the choice is saved in `user://mspsim_settings.cfg` (`[difficulty] tier`, `Difficulty.settings_path`; the title loads it in `_ready`, scenes launched directly by tests stay on normal). The summary line and the start toast end with the tier ("TECH CAMPAIGN - ADULT - IFONE 5 - NORMAL"; the toast adds "RUN <seed>" when the screen is 300 px wide or more). Continue skips the screen and uses the saved tier.
- **Saves**: campaign saves carry a `difficulty` section (`{version, tier, seed}`); `continue_game` restores both; a save without it loads as normal with a fresh seed (so old saves are unchanged). Only the seed is saved, not the position inside each stream: a continued run restarts its streams from the seed. Free Play is not saved and uses the chosen tier.
- **In the games**: karaoke chart spacing and hit windows are stored in `g.gap / perfect_win / good_win` (`_song_secs()` replaces the three copies of `1.5 + 0.75 * SONG_LEN`; the 45 px/s scroll is unchanged); bowling aim / power speed and an opponent skill offset; escape clock and the in-room wrong-code penalty; dinner hides one face per round on hard (the points still count, but you learn nothing about that person: `g.hidden`, "?" bubble, "??" face); printer marker speed, green / yellow zone width (x `printer.zone`) and 1 / 2 / 3 test-page questions; nerf war shot interval.
- Tests: `tests/difficulty.gd` (streams, table, settings file, same seed = same charts / codes / diners / printer / bowling, each tier in each game, save / load / old save), `tests/difficulty_shots.gd` (renderer, `-- --format=wide|h|v`, `user://difficulty_FORMAT_STEP.png`), plus tier checks in `tests/charselect.gd`. Not done (roadmap items 2-10): printer models and more questions, karaoke song table, escape clue recipes, outing roster, dinner pool, career / medals, event deck, mutators, New Game+ and daily seed, a `level()` that mixes progress and skill (v1 uses the tier alone), a seed field to type a seed.

### Play-through fixes (days 1-5 of the tech campaign; test `tests/bugfix.gd`)
- **Complaints** skip closed tickets (text, delivery and the answer). **PSA CLOSE** on an unfixed ticket asks first (`Computer.close_ask`: CLOSE ANYWAY / KEEP WORKING, Esc cancels; CLOSE now sits at the far end, away from NOTE); reopens cost coworkers at most -3 opinion a day (`Social.MAX_REOPEN_LOSS`).
- **HUD** is hidden while a Card is open. An **RMM fix keeps running when the computer is closed** (playbook / install jobs are dropped; leaving the RMM session shows JOB CANCELLED). The RMM list dot is red for any endpoint with a problem or an open unfixed ticket.
- **Onsite**: `create_job` adds the round trip (2 x drive + 30 min) to the ticket's SLA (the clock is paused on the road); the drive warning's at-risk count skips the ticket you are about to work; mishaps only fire when their `object` fits the job (`Onsite.event_fits`: a PC event never interrupts a printer job).
- **Sales**: a client signed today sends no tickets until tomorrow (`Sales.signed_day`, `takes_tickets`), matching Vic's mail.
- **Commute** ends with a toast (`Shift._arrival_text`: N MIN LATE, K TICKETS WAITING / EARLY / ON TIME). **Mail**: Enter works from the first press, moving the selection (wide layout) or opening marks mail read, the list scrolls and is wider, long text clips with `..`.
- **Timed story events** (vignettes) fire when `World.clock` passes `at` and the clock is running; they can show up late only while the clock is paused or jumped (morning cards, an onsite trip moves the clock 1.5+ hours) or when the Cards queue is busy. This is intended: Heartbleed at 10:30 appears on return from a trip.
- **Fix failure rate**: one roll per finished fix (`Computer._finish_job`): `Skills.FAIL[ps_level]` (25/18/10/4/0/0 %) + `Shift.fail_add()` (up to +18% under 45 energy, -3% rested) + `Growth.fail_adjust`; wrong fixes and retries roll too. No double roll, so 25-45% is normal for a tired level 0-1 tech.

### Tech playthrough fixes, days 5-20 (roadmap T2; test `tests/t2.gd`)
- **Reputation is meaningful**: `Campaign.daily_cap()` (day report adds at most 4, 3 from 50, 2 from 58, 1 from 72) and `gain_scale()` (instant gains such as playbook S/A are x0.6 from 60, x0.4 from 72, x0.25 from 85, min 1) slow the climb. **Scars** (`Campaign.scars`, saved) lower the ceiling `rep_cap() = 100 - scars`: lost ransomware 15, lost install 8 (restored 2), an unworked P1 breach 2, a day with 3+ reopens 2; each A or S day heals 1. Measured by `tests/t2.gd` (seed 4242, 20 days, `-- curve` prints only the curves). Good play: 50 50 52 60 59 58 67 73 76 79 78 81 84 88 89 91 93 94 97 98 (was 100 from day 14); careless (closes without fixing, ignores P1s): fired on day 9 (was the same); mixed (careful on even days only): ends 76 (was 100).
- **Ransomware without a good backup** no longer ends at once: RESTORE says `BACKUP FAILED. TRY SHADOW COPIES OR PAY.`, the machine stays ransomed, shadow copies work once (40%), paying works 70%, and closing the ticket is giving up (`_ransom_lost`). Tickets carry `outcome` (`lost` closes with no points and no `closed_ok`; `paid` / `partial` close for 4). `backup_rerun` refuses while a client has a ransomed machine. Boss text on the day-9 warning mentions shadow copies.
- **Story jobs always get a ticket** (`Msp.create_problem(..., force := true)` from `Playbook.start`: a new PC-0N when every PC is broken, the single server when it is broken) and **close their tickets when they finish** (`Playbook.finish`; the install handover too). Vic reminds you of a sold install for 3 days (`project.since`, `nagged`).
- **Review**: JOBS / CLIENT_OF cover rdp, ceofraud, no2fa, bus (job lines sit two to a row when the panel is wide); `best_client()` skips a client whose data you lost (`burned_clients()`), and the internal epilogue names the desk. **HUD** hides while `Hud.modal_open()` (Review, day report, Cards, printer game, outing panels except an in-room game being played).
- **Overtime**: `Shift.can_end_day` makes no STAY offer when `Story.ot_hours > 0` and it is past closing; the stay card is headed with `Shift.clock_label()`.
- **Text**: trip is one day, trip objective drops the badge line once you have it, day-16 all-hands preview names the trip, spring storm text instead of snow, vendor call no clock time, donuts card branches on `Story.flags.bus_reset / bus_doc`, Atty. Spence, one Morgan sender (`Msp.MORGAN_FROM`, normalised in `_mail`), pager reasons and commute reasons 12 / 10 variants with no immediate repeat (`Shift._fresh`), backup header says BACKUP WATCH when the perk is on. `Cards.ask` takes an optional `valid` callable re-checked when a queued card comes up (Vic's complaint). RMM labels `PAY THE RANSOM` / `SHADOW COPIES`; the report grade box uses its own 4x5 letters (`DayReport.BIG_GRADES`).

### Canon: the owners (text and label pass; `tests/canon.gd`)
- **Alan and Garrison are the two OWNERS of Pixel IT Partners**, not ordinary techs. Alan = the technical owner (servers, backups, the stack, the closet, resolution quality; gruff, patient, a sandwich man; Office 1). Garrison = the sales-and-culture owner (clients, marketing, hiring, morale, outings; excitable, scare stories as a quirk; Office 2). Morgan Reyes is the manager and reports to them; Dan (network tech), Maya (Tier 1), Vic (account manager) and Marge (bookkeeper) are staff.
- **Voice rules**: Alan and Garrison talk about payroll, the books, clients, the van, vendors, hiring and the next outing, in their own voices; never "senior tech", "security guy" or "security tech". Talk tips keep their mechanics (Alan warns about a failing backup by client name, Garrison about SLA misses; specialities servers / security unchanged) with owner framing. In the tech campaign they do not work tickets day to day (the last-resort rule is a separate task, roadmap X6).
- **Where it lives**: `Talk` (greetings, small talk, tips, gossip), `Lync.MESSAGES` (keys `lunch_Alan`, `phones_Alan`, `help_Alan`, `thanks_Alan` and the Garrison ones win over the generic keys for the two owners: a client call-back, the QBR, a vendor renewal, lunch for the team; same options and Social effects as the generic ones), `Social.OWNERS` / `Social.ROLES` / `is_owner()` / `role()` (labels: Lynk chat header shows "(OWNER)", PROFILE heading "OWNERS AND TEAM"), `Review.OWNER_QUOTES` (the owners' yearly-review quotes; patchable), the Story day-1 mail, the Heartbleed and donuts vignettes, the day-19 playbook, the tech all-hands, `Outings._host()` (Garrison invites in the tech campaign, Alan in the owner campaign), card speakers "Alan (Co-owner)" / "Garrison (Co-owner)".
- **Left for later**: the owner campaign structure (the player becomes Alan or Garrison; its 15 "Alan" advisor cards, "techs" wording and the `Skill relative to a senior tech` hire card are only relabelled), the last-resort rule and ASK THE OWNER lifeline, owner `ASK FOR HELP` mechanics (a friend still fixes your oldest simple ticket, only the reply text is owner-flavoured), Social/Lync desk-ticket plumbing (`DESK_OWNER` maps desks 6 / 7 to them).
- Test: `tests/canon.gd` (banned phrases absent from the player-facing tables and `strings.txt`, owners keep greetings / small talk / tips, owner Lynk messages mirror the generic options and effects).

### Owner play-through fixes (items 1-6 and the lead name; test `tests/ownerfix.gd`)
- **Cards and outings freeze the day**: `World.time_scale` reads 0 while a campaign has a `Cards` decision or an `Outings` game open. `Campaign._process` does not end the day while a card is open or an outing is open or being travelled to (`Outings.busy()`); `Cards.ask` queues behind the weekly report (`DayReport.is_open`) and `Cards.flush()` shows the queue after it. A card with no affordable option gets a NOT NOW option (`__none`, Esc picks it, the callback is not called) so it can never trap the week.
- **Week 20 settles once**: `report_continue(final)` keeps `_awaiting` true (the clock is still at closing time).
- **Valuation history**: `Owner.settle()` runs `Projects.week()` (payouts) before adding up the profit, so `history.profit` and `ebitda` (profit minus project money) agree.
- **Vic's sold install** in the owner campaign is a one-off job (`Sales.INSTALL_JOB` $150 plus the hardware margin), not a desk ticket, so it cannot sit unworked or block `Msp.project_busy()`.
- **Week 6 prospect** is a named client who is not signed yet (`Owner._prospect_card`, template `CARDS.prospect` with `%s`); the signed client is that one, and OFFER THE DISCOUNT applies 20% for 6 weeks (`fx.discount_new`).
- **Phone**: TEXTS lists newest first and always shows the newest message (cut to fit); the home screen has keyboard selection (arrows, Enter opens, Esc closes; `Phone.home_sel`).
- **Pitch site names**: the prospect's office (b skin) PC, owner and host prefix use the lead's real client name and contact (the lead card, the PC and the owner agree; `SITE_PROSPECT` / `OWNER_B` are no longer used).
- Not done (kept in `docs/BACKLOG.md`): balance tuning, Vic complaint spread, Dana repeating advice, the 60% meeting upside, billing leak vs cash, REVIEW DUE in week 1, Esc in the Computer, invite cost text, the desk PC stealing E.

### Printer variety (R2: `PrinterGame.MODELS`, `QUESTIONS`, `MODEL_TEXT`, `MODEL_PRAYERS`)
- **Models**: `PrinterGame.start(callback, model := "laser", opts := {})`; `MODELS` has `laser`, `inkjet`, `plotter`, `mfp`, `receipt` and `dot` (dot matrix), each with `phases` (an ordered list from `jam`, `tray`, `toner`, `shake`; `test` always comes last, `_advance()` walks the list), a `tray` list (right one first, `HIT IT` last), cartridge `names` / `colors` (toner, ink tanks, a 2-colour ribbon, none for the receipt printer) and a `look` that `_printer(y)` draws. `MODEL_TEXT[model]` overlays only the keys that differ from `TEXT` (the old `PLOTTER_TEXT` is its `plotter` entry; `tray_screen` / `tray_slot` are the display words). `MODEL_PRAYERS[model]` replaces `PRAYERS` for that model (the laser keeps `PRAYERS`).
- **Questions**: `QUESTIONS` has 34 entries (the old plotter ones merged in), each with `models` (empty = every printer) and `hard` (0-2, the lowest tier it appears on; `_begin_test` draws `Difficulty.i("printer.questions")` = 1 / 2 / 3 from `pool_for(model)` through the printer stream, hard ones only fill the page when the model has too few). Error and options must stay within 36 characters (a test checks it); `error` is now an editable string in `strings.txt`. 2013-14 items: ink alignment after a swap, a 400 MB spooler job, a USB printer shared from a Windows XP PC, a DHCP lease change, the wrong default printer, 20 insufficient memory on a 2 MB laser, the duplex unit, glazed feed rollers, a baud-rate mismatch on a receipt printer, and the trick question (the printer is unplugged).
- **Jam chain (P3)**: `printer.chain` in `Difficulty` is 3 / 3 / 5 pulls; two clean pulls in a row shorten it (not under 3), a tear leaves a scrap and adds a pull (up to 6). **Tired (P5)**: `{"onsite": true}` makes the marker up to 15% faster from `Shift.slow_mult()` (shown as TIRED and on the intro page); never on practice, and it only reads energy. **Pray-free streak (P7)**: a win without a prayer adds one, a prayer or a lost run ends it; `to_dict` / `from_dict` / `reset` are saved in the campaign as `printer`; the result page shows it from 2. **Practice (P8)**: `{"practice": true, "seed": n}` (Onsite passes it for the printer with no ticket) lets the intro page pick the model (Left / Right) and a seed 1-99 (Up / Down); the run then uses its own generator, so the same model and seed repeat the same zones, cartridge order and questions.
- **Onsite** (`_printer_model`): architect = plotter, law = multifunction, vet = inkjet, trailer = dot matrix, dental = receipt or laser, realty = laser or dot matrix (the either-or sites roll once per client and day with `Difficulty.rng_for("printer.model", ...)`); a job option `game: "printer:inkjet"` forces a model.
- Tests: `tests/printer.gd` (every model perfect and failed, pools, seeds, tiers, chain, tired, streak, practice, site models, brand deny-list), `tests/printer_shots.gd -- --format=wide|h|v [--model=x]` (renderer; `user://printer_FORMAT_MODEL_PHASE.png`). Not done: P4 (the line-printer boss) and P6 (the parts bag).

### Owner round 2 (X1; test `tests/x1.gd`)
- **Balance**: `START_CASH` 7,500; a new hire costs 60% of the wage for `HIRE_RAMP_WEEKS` (3) (`Owner.hire_wage`, `hire.age`); a week with profit under -$1,000 (not any loss) costs reputation in `Campaign._end_day`. Costs grow with the company and calendar (`Owner.overhead()`: rent +$50 at weeks 9 and 14, insurance +$80 from week 12, `SEAT_COST` $55 per client past five; `wage_mult()` = +5% raise from week 12). Maturity: `oml()` = 1 + habits x 2 / 5, capped at 1 + week / 4, so level 4 needs about 8 habits and week 12.
- **Smaller**: `Sales.complained_day` (owner campaign: the same client complains to Vic at most every other week); `Owner.advice_topic()` (Dana never repeats a card within `ADVICE_GAP` 3 weeks; generic cards train / lunch / push fill in); the meeting-yourself lead option has `sign_bonus` (+15 mood, +10% fee); `settle()` bills the leak (`fee x (1 - leak)`) and adds managed-service revenue to cash, so cash and EBITDA agree.
- **UX**: `Owner.review_due()` (never before week 6); `Computer.escape()` (Esc steps out of a sub-view, otherwise closes in one press); the outing invitation states `Outings.cost_range()`; `site:owner` NPCs beat the desk PC for E (`player.nearest`).
- Balance (natural time, one run each; before -> after): smart cash $29k -> $37k, rep 100 -> 84, value $329k -> $478k (earlier smart run stuck at $0 value with $515 cash by week 6, now weeks 1-5 cash stays $7k-11k and rep 54-60); cheap $44-61k, rep 11 / 0 -> $31k, rep 70, value $573-601k -> $771k; greedy $40k, rep 34, $801k -> $53k, rep 31, $725k. Order smart > cheap > greedy on reputation holds in the last runs; runs are noisy. `owner_balance.gd` prints weekly lines with `WEEKLY=1` and a STUCK line if a week never ends.

### Player as a cast member, and Morgan Reyes in the cast (X2, X3; tests `tests/playeras.gd`, `tests/morgan.gd`)
- **`Campaign.player_as`** (a `World.CAST` name or ""; saved in the `campaign` section, old saves default ""): derived from the chosen character in `new_game` (`derive_player_as`): tech never plays a cast member, the owner campaign plays Alan or Garrison, Free Play any cast member. `World.roster_gone()` = `player_as` plus Maya in the owner campaign; `World.apply_roster()` frees those nodes and erases them from `World.chars` (CAST stays a const table), and restores everyone else in CAST order. Free Play used to hide the NPC copy (it kept its seat, meetings and Social weight: a ghost); it now uses the same removal, and the 1-7 keys call `Campaign.refresh_free()` so the old character returns to their desk. `npc.gd _hidden` stays only as the fallback for scenes launched directly.
- **Seated start**: `Campaign.start_scene()` / `World.player_desk()` give the cast member's home room; `Game.vars.start_seated` makes `stage._seat_player` call `player.sit_now(seat)` once. `title._start` uses it for new runs and Continue.
- **`Social.people()`** (function; `Social.ALL` is the full list) = everyone except `World.roster_gone()`; Lync, Outings, review lines, the PROFILE app and the opinion maths use it, so you are never your own coworker and Maya no longer counts at 0 in the owner campaign. **`Outings.roster()`** = the current cast minus you; the games use `diners()` / `bowlers()` (the Alan / Garrison / Dan trio minus you; dinner targets scale with the table). Standing spots are indexed by CAST position (a sixth spot per room is Morgan's).
- **`Roles` autoload** (`roles.gd`): `partner()`, `stand_in()`, `who(job)`, `label()`, `speaker()`, `sender()`. `Cards.ask` and `Msp.send_text` remap a speaker or sender that is you ("Alan (Co-owner)" becomes the partner in the owner campaign, otherwise Morgan), so the owner cards keep working without edits.
- **Character select**: tech = non-cast characters; owner = Alan or Garrison with their own blurbs (`OWNER_BLURBS`); Free Play = all seven. Choosing an owner makes the other the partner NPC.
- **Morgan Reyes** (`office_morgan`, role `manager`): desk 5 (cubicle area `Seat2`, `npc.DESKS`, `Social.DESK_OWNER[5]`), works, walks the main floor (`floor` plan, `_floor_leg`), coffee / copier, eats lunch at her desk, never goes to the closet, on visits or into the outing games' data; no conference chair (she hosts the all-hands standing at the whiteboard, `World.HOST_X`, so Seat6 stays free for you; `Expo.populate` no longer spawns the `boss:morgan` role NPC in the tech campaign, Marge still does in the owner campaign). Social row (MANAGER), Lync contact (still the boss in the tech campaign; her four `*_Morgan` messages), Talk deck (greeting, six small talks, tips, state tip, owner idea; specialty people), Nerf reaction. She never fixes tickets (`Lync._lend_a_hand` guard).
- **Left for X4**: `Owner.CARDS` text and "techs" wording, the crew re-base (owner crew is still Alan / Garrison / Dan, base `3 - lost_techs`), partner stance / meetings, the weekly draw, owner edges per owner; Talk's owner-mode lines for the partner; Maya as the first hire; `Growth` / `Meeting` strings that say "Alan" are only remapped by `Roles`. Outings: bowling / dinner data exists only for the trio (R5 adds Maya, Vic, Morgan).



### Event deck and vignette deck (`scripts/events.gd` autoload `Events`, roadmap R8)
- **Events** draws at most ONE small card per quiet day, from `Events.DECK` (patchable, 41 cards keyed by id: `{id, kinds [tech|owner|both], min_day, max_day, weight, cooldown, requires, speaker, text, options[{id, label, text, fx}]}`) plus the 17 drawn vignettes. `Campaign._begin_day` calls `Events.begin_day(day)`; the card is shown when `World.clock` passes a time chosen between 10:00 and 13:30 (`_process`; it waits for open cards, trips, outings and the day report, and is dropped at 15:30).
- **Quiet day** (`quiet_day`): not days 1-2 (owner: week 1), not the last day, not a day with a story vignette or the ransomware, an outing (`Outings.TECH_DAYS` / `OWNER_WEEKS`), the email overtime night, the conference trip, owner weeks with more than three scheduled events; never in Free Play. Draws use `Difficulty.rng("events")` and exactly 5 numbers each, so a seed repeats; `draws` is saved and `from_dict` replays the stream on a continue. Save section `campaign/events` = `{version, draws, last {id: day}, recent [ids]}`; an old save loads empty. `cooldown` (days) is honoured through `last`; `requires` tokens: `client:N`, `cash:N`.
- **Cards** use the vignette resolver unchanged (`Story._vignette_fx`: `xp mood mood_all rep social social_all energy hours`); owner cards add `cash` and `burnout` (routed to `Owner.apply`); in the owner campaign `xp` and `energy` are ignored; `hours` is dropped in the last hour and a half of the day. `{c}` in a card is replaced with a coworker from `Events.roster()` (Dan, Vic, Maya; no Maya in the owner campaign; never the owners or Morgan/Marge).
- **Balance guard** (`violations()`, `fx_problems()`, `validate_all()`; bad cards are never drawn): xp <= 6, mood +-8, mood_all +-4, rep +-1, energy +-6, hours <= 0.75, social +-3, social_all +-2, cash +-300, burnout +-4; 2-3 options, every card has one safe option, no stranger named (Alan/Garrison are the owners; Morgan tech only, Marge owner only).
- **Vignette deck**: `Story.VIGNETTES` holds 24 cards: the seven fixed ones (calendar days) and 17 tagged `min_day` (and optional `max_day`, `weight`) that are drawn once per run on quiet tech days (`Story.fire` kind `vignette`). Both tables are in `story/strings.txt` (`Events.DECK.*`, `Story.VIGNETTES.*`).
- Tests: `tests/events.gd` (schema, guard, deny-list for brands, seeds, cooldown, quiet days, saves, firing and fx), `tests/vignettes.gd`, `tests/strings.gd`. Left: mutators (R9), weekly/seasonal tags beyond the day windows, a Career counter of cards seen, art for the cards.


### Career, medals and nerf scoring (`scripts/career.gd` autoload `Career`, `career_screen.gd`, roadmap R7)
- **Nerf scoring (N1)**: `Nerf` keeps a score card per war: hits, taken, `war_dodged` (darts you ducked), `war_missed` (your darts they ducked), `war_ff` (coworkers hit by coworkers), `war_assists` (a coworker hit someone within 2.5 s of your hit on them), `war_longest` (px from muzzle to victim, darts carry `x0` meta). `war_result()` / `war_titles()`: MOST DUCKED (3+ ducked), SNIPER (a 150 px hit), FRIENDLY FIRE (3+), TEAM PLAYER (2+ assists), UNTOUCHABLE (5+ hits, none taken); shown in the war-over toast (`last_result`). **Fixed**: the hit that starts the war counts (`YOU HIT 1`, not 0).
- **Career autoload** (after `PrinterGame`, before `Strings`): counters saved in `Campaign.save_prefix + "career.cfg"` (`user://mspsim_career.cfg`), outside every campaign slot, so New Game keeps them; a missing or old file loads as zero; saved on a medal and every 3 s when dirty. Hooks (one line each): `Msp.close_ticket` (`note_ticket`: total + `tk.<fix>`), `Outings._finish` (`note_outing`: outings, `stars.<game>` best, karaoke perfects, fastest escape in seconds, dinner best) and `_bowl_resolve` (strikes, gutters), `PrinterGame._record` (wins per model `pr.<model>`, best no-prayer streak), `Onsite._pet`, `Sales.deliver` (`vic_calls`), `Meeting.hold`, `fx` duck, `Review.finish` (`endings`), `Nerf` (hits, longest, dodges, wars), `Campaign.day_started` (`days.<mode>`). Derived: `printer_models`, `stars3`, `days_total`, `tk_other`.
- **MEDALS** (24, patchable `Career.MEDALS`, `Career.UNLOCKS` in `strings.txt`; title and desc are the text, desc 30 chars at most): rules are `[counter, ">=" | "<=", n]` lists that all must hold; `check_medals()` runs on every change and toasts `MEDAL EARNED: <title>`. **UNLOCKS** are cosmetic data read with `Career.unlocked(id)`: wallpapers (value = desktop colour), ringtones, gold / pirate rubber duck and desk toys (the last two are data only, no art yet). Wired: the Computer desktop uses `Career.wallpaper_color()` and shows a `WALLPAPER: <name>` chip (click = next unlocked); phone Settings has a `TONE:` row (click or Left / Right cycles `ringtone_name()`) and a CAREER row.
- **Screen** (`Career.open_screen()` returns the node; Esc / the X button frees it and restores `Game.ui_open`): title menu entry CAREER (last item) and the phone Settings CAREER row (works in Free Play and campaigns). Pages of counter rows, then medal pages (star = earned, grey box = locked with its hint and progress `n/N`), two columns at 290+ px body width, one in portrait; Left / Right / A / D / wheel change page, F9 cycles the format, mouse clicks the `< > X` buttons.
- Tests: `tests/career.gd` (109 checks: hooks from real calls, every medal at threshold -1 and at threshold, toast, save / load outside the slot, old and missing file, unlocks, war score and the starter hit, brand deny-list), `tests/career_shots.gd` (renderer, `-- --format=wide|h|v`: title menu, every page, phone Settings). `tests/charselect.gd` now expects CAREER after FREE PLAY.
