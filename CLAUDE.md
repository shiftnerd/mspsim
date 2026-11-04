# Pixel character project

Cartoon pixel-art characters in Aseprite (via the aseprite MCP). Characters are
caricatured, not exact copies of people.


# Project and art

## Deliverables
- **Deliver `.aseprite` files by default.** Do not export PNGs or GIFs unless asked.
  Viewing previews through `view_sprite` for my own checking is fine; do not save
  preview PNGs into this folder (use `output_filename` only when asked).
- Primary outfit going forward is the **office** version (blue polo). The
  SkillsUSA version (white polo, medal, ribbon, nametag, logo) is secondary.
- Keep every item on its own layer so it can be toggled or recolored.

## Style
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
  intern"** (the intern character in the blue office polo), so files are
  `office_intern_right.aseprite` and `office_intern_left.aseprite`.
- `office_intern_right.aseprite` is the source of truth. `office_intern_left.aseprite`
  is derived from it. Edit the right file first, then regenerate the left.
- `archive/teenme.png` is the original reference photo.
- `archive/` holds earlier, superseded attempts (`intern_blocky*`, `intern_cartoon*`,
  the SkillsUSA layered version) and old preview PNGs. Do not edit these. Keep only
  the current character files in `sprites/`.
- **`sprites/` holds every character file** (stills `<name>_<facing>.aseprite` and animations `<name>_<facing>_anim.aseprite`), grouped in subfolders: `sprites/staff/` (the cast and the player people: `office_*`, `site_*`, `casual_*`, `sales_*`), `sprites/clients/` (`client_*`), `sprites/expo/` (`expo_*`) and `sprites/custom/` (`custom_intern_*`, the character creator hairstyles). The Lua tools find a file through `tools/sprite_path.lua` (`SP(root, "office_intern_right_anim")` returns the full path from the name prefix), so a new character needs no path edits: `client_`, `expo_` and `custom_` names go to their folder and anything else to `staff/`. Sets, pieces and the logo stay under `office/`; Godot PNGs under `godot/assets/`. Anywhere older notes say a character file is 'in the project root', read `sprites/<group>/`.

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

## Characters
Each character is a pair of files (`_right` is the source, `_left` is derived).
New characters start as a copy of an existing one, then change only what differs.

- **office intern** (`office_intern_*`): the intern (the original character, drawn from a teenage photo of the author). Blue polo, long auburn side-swept
  hair, no beard, brown shoes. Reference photo: `archive/teenme.png`.
- **office adult** (`office_adult_*`): adult me. Copied from office intern, with:
  - maroon polo (`#8C2B40`, shade `#6A1E31`) with gray placket (`#9AA0A8`) and dark
    maroon buttons (`#4A1020`)
  - short, receding hair (`#74492A`, highlight `#B07A44`), about 5 rows above the
    forehead on the front side
  - beard on its own `Beard` layer (`#A8743F`), lighter than the hair so they read
    as separate shapes: sideburn gap around the ear, jaw, and chin, with the mouth
    area left clear
  - gray shoes (near `#8A8F9A`, far `#6A6F7A`)
  - pants kept navy and body build kept the same as the intern (the photo shows
    jeans and a stockier build; change only if asked)
  - Reference photo: `archive/me_now.jpg`.
  - `Beard` layer sits above `Hair` in the stack (top layer).

- **office Dan** (`office_dan_*`): Dan. Copied from office intern, with:
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
- **site Alan** (`site_alan_*`): Alan in his work-site outfit. Copied
  from office intern (short-sleeve
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
  Frame timings are set per frame. Seated = body raised 6 px over level thighs, knee bent, shin down to the floor row (see Seating geometry), forearms forward to the desk.
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
- **Seated life poses (R26, frames 86-123, appended so no old number moved; non-looping, every character x both facings)**:
  `sitstretch` 86-90 (far arm up and forward, near arm swung back, lean -3), `sitscratch` 91-96 (near hand to the hair, scratching),
  `sitlook` 97-101 (head lifts, turns away over the shoulder, a blink), `sityawn` 102-106 (near hand to the mouth, head back, eyes shut
  = the `hurt` face variant), `sitslump` 107-110 (shoulders drop, head sags, a sigh), `sitmouse` 111-114 (the near arm slides the mouse),
  `sitphone` 115-119 (looks at a phone in the near hand: `held_item.gd` draws item `phone` there), `sitnod` 120-123 (head nods, for
  meetings). `sit` (38-39) is now a visible breath (900 / 700 ms, shoulders settle a pixel, head sags a pixel more, near hand slides).
  Engine: a pose with `armTop = true` draws the near arm on an extra top layer `Arm Top` (above Face / Hair / Vest), so a hand can come
  to the face (Alan's vest and every face layer otherwise hide a raised near arm); every anim file now has that 14th layer.
  **`toss` 124-129 (R29, appended)**: an underhand throw, the near arm swings back (aN -62), through and up (aN 104), non-looping, 6 frames 140 / 200 / 70 / 120 / 220 / 140 ms; cornhole throws (you and the crew) and the grill flip use it instead of `reach` (`Outings._pose`, `start_emote("toss", 0.9)`). The sheets and hands json are 129 rows now; `HeldItem.START.toss` is 123, `HeadGear.FRAMES` / `Look.FRAMES` are 129, the head sheets (`tools/make_head_sheets.lua` with `REF = {"glasses_aviator", "beard_full"}` rewrites the golden refs) and every anim file were rebuilt with `build_anims.lua` (no `ONLY`).
  The hands json has 129 rows (123 before R29). `tools/build_anims.lua` with no `ONLY` now rebuilds EVERY character it finds in `sprites/<group>/`
  (staff, clients, expo, custom; the drawn custom hairstyles get the `GHOST = office_intern` automatically), so a new character is
  picked up without edits. Build in a worktree: a small script `ROOT = "<checkout>/"; dofile(ROOT .. "tools/build_anims.lua")` run with
  `Aseprite.exe -b --script x.lua` (batch mode, about 6 minutes for all 56 people).
- To change a pose, edit `tools/poses.lua` and rebuild all 12 files. Positive angles swing toward the
  facing side. Leg angles have to keep the feet a few px apart (the near leg starts on the back side).


# Rules that apply to every Godot task
- **Never run `tools/make_godot.py` in the real tree** (the committed scripts carry hand edits ported back into it). Use `python -I tools/check_generator.py --keep --scratch DIR` and copy over only the files you meant to change. Hand-edit a `.gd` and the same text in `make_godot.py` in the same commit.
- Godot 4.7.2: `C:\Program Files\Godot\Godot.exe`. Headless test: `Godot.exe --headless --fixed-fps 60 --path godot -s res://tests/<name>.gd`; all tests: `python tools/run_tests.py -j 4`. After new art run `Godot.exe --headless --path godot --import`. Lint from `godot/`: `gdlint scripts tests`.
- Tests must use their own save paths (`user://test_%d_...` with the process id).

# Where the rest lives

Everything below used to be in this file. It is now in `docs/dev/` (verbatim, read the file for the area you are touching, use Grep on `docs/dev` to find a topic). Sections inside are in the order they were built.

- `docs/dev/godot-basics.md`: Godot project, sprites in Godot, props, NPCs, seating, rooms, dancing
- `docs/dev/systems.md`: cast, workday, lights, title screen, network closet, computer/MSP, phone
- `docs/dev/campaigns-1.md`: Campaigns + Free Play / Film Mode (`scripts/campaign.gd` ... Nerf guns (`Nerf` autoload, `dart.gd`, the rack in the c
- `docs/dev/campaigns-2.md`: Reviewable story: the game bible and the editable text f ... Play-through fixes (days 1-5 of the tech campaign; test 
- `docs/dev/campaigns-3.md`: Tech playthrough fixes, days 5-20 (roadmap T2; test `tes ... Year 2 / New Game Plus (R10b; `scripts/yeartwo.gd` autol
- `docs/dev/campaigns-4.md`: Service manager campaign (Dan): the crew as people and t ... Cornhole and the cookout (roadmap R21 a and b; `cornhole
- `docs/dev/campaigns-5.md`: Hot dogs and the lunch break (roadmap R29; `grill_game.g ... Darts and the warehouse's odds and ends (roadmap R38; `d
- `docs/dev/tools-tests.md`: layout audit, bot balance, test runner, generator check, P6
- `docs/dev/audio-creator.md`: audio, character creator (levels 1-3), resume, pause menu, cozy Easy, METRICS

Other docs: `docs/GAME_BIBLE.md`, `docs/ROADMAP.md`, `docs/BACKLOG.md`, `docs/manual/`, `godot/story/README.md`.

**Keeping this file small:** CLAUDE.md is for rules that apply to every task (art, deliverables, tool gotchas, generator rule). Notes about a finished feature go into the matching `docs/dev/*.md`, never here. Keep this file under about 30 KB.
