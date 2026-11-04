# Scope: character creator level 3 (roadmap R15)

**Status: steps (a), (b) (overlay pipeline, glasses (4), facial hair (4)), (b-UI) (the EXTRAS and WORK create pages), (c) (six hats, the hat hair rule, the unlock kinds, the old tree), (d) (nametag, conference lanyard, three watches) and (e) (the mirror preview, the Free Play outfit swap, NPC copies and presets with accessories) are BUILT (Nov 2026; see CLAUDE.md, Character creator level 3 steps b to e). Step (f), real clothes, is open.** Read-only scoping pass (Nov 2026) from the code, nothing was run. Items marked (inference) are unverified. Levels 1 (colours) and 2 (ten prebaked hairstyles, each a complete character) are done.

## Recommendation: a hybrid, head-only overlay sheets (approach C)
Hair stays prebaked. Accessories (glasses, facial hair, hats, and later a nametag, lanyard and watch) are small overlay sheets drawn by a sibling `Sprite2D` that does NOT play its own animation: each frame it reads the body sprite's current `animation` and `frame`, adds a `START` offset and looks up a per-frame table, exactly like `held_item.gd` already does for the held cup and headset. It cannot drift (no second timeline), so backwards `sitdown`, one-shots, `pause()` and `_switch_character` are not a problem.

**Why the prebake stops scaling:** a prebaked character costs about 140 KB shipped (about 45 KB per facing for the sheet plus the `.tres`). Ten hairstyles times 5 glasses times 5 beards times 7 hats is 1,750 characters, about 245 MB, plus very long anim builds. **Why not runtime composition:** the 123-frame sheet is 7872x80, about 2.5 MB of GPU memory per look, it hitches on first use, and it needs runtime image access, which is the risky part in exported and web builds.

**How placement works:** `E.render` already returns a full 64x80 image per layer per frame, and head layers go through `headBlit` (head offset, tilt, death rotation, hurt flash). Add `Hat` to the head set. A new `tools/make_head_sheets.lua` loads the intern still with each accessory as its own layer, renders the 123 poses, crops a 32x32 cell centred on the Face layer's box (so it tracks the head in every frame, including death), and writes one shared per-frame origin table per facing. Hand-to-face poses paste the `Arm Top` pixels into the cell so a hand under a hat still shows.

**Engine catch:** the death-frame shift is measured from the union of all layer boxes, so a tall hat would shift the overlay differently from the body. Accessory layers need a "rotated but not measured" flag (the same idea as `GHOST` for bald hair). Small engine change.

**Size:** glasses (4 styles), facial hair (4), hats (6), nametag, lanyard, watch: about 72 files and an estimated 60 to 150 KB of PNG in total, about 0.5 MB of VRAM per sheet in use.

**Hats versus hair:** a mask rule, not hat-specific hair: while a hat is on, tall styles use a fallback (`Look.HAT_HAIR`: spiky and curly become short, bun becomes ponytail; long, bob and ponytail hang below the brim and stay). Zero extra files; the UI shows the substitution. Hats replace the hair crown rather than sit above it (the still has almost no headroom).

**Not head-rigid:** nametag and lanyard sit on the torso (sheared by `lean`, covered by the near arm), so their cells are baked with the arm's alpha subtracted; the watch follows the wrist (the `hands.json` hand column) in a tiny cell. Checked frame by frame (inference).

## Clothes
- **Overlay handles:** shoes (the engine already splits them per leg) and shirt styles that cover more than the polo (a long-sleeve button-down; Dan's arm layers are already redrawn that way).
- **Needs real work:** anything that shows skin (tee, short sleeves, tank, shorts): the body sheet has the polo and long trousers baked in. Each shirt style needs far sleeve, torso and near sleeve layers for all frames, plus a bare-skin base character. Large (optional, last).
- **Cheaper stopgap, shader only (no new files):** shirt patterns (stripes, plaid) from a sprite-local coordinate with a lighter second tone, a hoodie colour as a second shirt tone, and "shorts" by recolouring trouser pixels below a hem row to skin tones (the legs only rotate a little; check crouch and death). This delivers "feels like mine" long before layered clothes.

## The create screen (15+ options)
- Three pages (wide 368x128 fits only one more row today): LOOK (name, style, skin, hair colour, beard colour), CLOTHES (shirt, pants, shoes, pattern), EXTRAS (glasses, beard, hat, badge, watch), with tab chips and a shoulder button or Q / E to switch (inference); Left / Right still change values via `Controls.nav`.
- A bottom row: RANDOM, PRESETS (3 slots, save and load), DONE.
- A mirror-style preview that cycles idle, walk, wave, sit, type and the new seated gestures; the overlay works there because it only polls the frame. A hold-pose key is needed.
- Pad name entry: a modal A to Z grid (arrows, confirm, delete); today a pad can only pick suggested names.

## Presets, unlocks, Free Play swap
- The campaign keeps `campaign/look`; presets are global in `user://mspsim_settings.cfg` under a new `[looks]` section; the look dict gains `acc: {glasses, beard, hat, badge, watch, pattern}` (old saves: none).
- Unlocks: `Career.UNLOCKS` entries are `{id, kind, title, medal, value}`; add kinds hat, glasses and beard (value = the accessory id), patchable in `story/strings.txt`; `Look.sanitize` demotes a locked accessory to none. Starter sets are free; the hard hat could come from a warehouse medal and the Santa hat from the old Christmas tree.
- Free Play outfit swap: a key (or a pause-menu row) opens the create step as an overlay and applies the look live. `npc.gd` already has a `custom_look` dict that nothing sets yet: wire the accessories through it so NPC copies of the player's look match. **Built (step e):** the key is Y and the pause row OUTFIT (Free Play only; `Toolbox.open_outfit`, a `CharSelect` in overlay mode, live on the player, Esc restores); `Look.copy_look` feeds `custom_look` and a Free Play TWIN (pause row) shows the copy; presets keep `acc`; the preview cycles 14 poses with TAB to hold.

## Steps (cheapest feel-good first)
1. No art: presets (3 slots), RANDOM, the page layout, shader patterns and shorts, the pad name grid (S/M).
2. The overlay pipeline: the "not measured" flag, `Hat` in the head set, `make_head_sheets.lua`, the origin tables, the `HeadGear` node; ship glasses (4) and beards (4) (M).
3. Hats (6) with the `HAT_HAIR` rule and the new `UNLOCKS` kinds (M).
4. Nametag, lanyard and watch (S/M).
5. The mirror preview, the Free Play swap, the NPC copy hookup (M).
6. Optional: real shirt styles and shorts via a bare-skin base (L).

## Tests and risks
- Tests: a golden check (overlay composited on the body equals a one-off prebaked reference for 123 frames, both facings); sync (index and position per animation including backwards `sitdown`, `pause()` and a character switch); the hurt flash on frames 25 and 28 with overlay colours; every accessory pixel fits its 32x32 cell including death; save and restore, old saves, unlock demotion; layout audit per page at wide, h and v.
- Risks: the death union shift (above); hats drawn over a hand if `Arm Top` is not baked in; an animation missing from `START` hides the overlay; a one-frame lag from process order (use `frame_changed` if visible); accessory colours must be added to `Look.KEEPS` and the shader mapping so the hurt flash does not recolour them.

## Decisions (owner, Nov 2026)

1. **Approach:** head-only overlay sheets (C), with the no-art stopgap (presets, RANDOM, pages, shader patterns, hoodie colour, shorts, pad name grid) first.
2. **First-release accessories (proposed list, accepted as a starting point):** GLASSES (4): thin rectangular (Dan's), thick black rectangular, round wire, aviator sunglasses. FACIAL HAIR (4): stubble, goatee, full beard, moustache. HATS (6): knit beanie, ball cap, hard hat (a warehouse medal unlock), Santa hat (unlocked from the old Christmas tree), bucket hat, party hat (an outing unlock). EXTRAS: a nametag, a conference-teal lanyard, a watch.
3. **Clothes:** REAL clothes are wanted (step 6 is in, not optional): shirts (polo, tee, button-down, sweater), bottoms (trousers, jeans, shorts, skirt), shoes (sneakers, boots, dress shoes), on a bare-skin base character, after the overlay accessories ship.
4. **Order:** (a) no-art stopgap and the page layout; (b) the overlay pipeline with glasses and facial hair (BUILT); (c) hats with the hair fallback rule and the unlock kinds; (d) nametag, lanyard, watch; (e) mirror preview, Free Play swap, NPC copies; (f) real clothes.
