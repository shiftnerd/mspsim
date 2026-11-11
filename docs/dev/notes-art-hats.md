# R15 second pass: the bigger hat cell and the redrawn hats (slug `art-hats`)

## What changed

- **Hat cell 40 -> 48 px** (`HeadGear.CELLS.hat`, `tests/accessories.gd`, `tools/make_head_sheets.lua` `CELLSZ.hat`, `HAT_UP` 3 -> 5).
  `hat_origin_<facing>.json` was rewritten (still 135 `[x, y]` pairs). The head, torso and wrist cells and tables are byte-identical.
- **The source canvas grew.** `office/accessories.aseprite` is now 56x76: the intern's 40x64 plus 8 columns on both sides and 12 rows on
  top (`PX, PY` in `make_accessories.lua` and `make_head_sheets.lua`). `make_accessories.lua` migrates an old 40x64 file by itself
  (`spr:crop(-PX, -PY, ...)`) and its `put()` adds the margin, so every coordinate in the maker stays in the intern's own coordinates
  (a hat row may use a negative y, down to -8). The sheet maker crops the margin off every layer but the hats.
- **`tools/anim.lua` (shared, small, backwards compatible)**: `E.addLayer(..., {pad = {px, py}})` rotates / shifts a head layer whose
  image has a margin (the pivot moves with it), and `E.setTop(n)` renders n extra rows above the 64x80 frame so a tall hat in the jump is
  not clipped at row 0. The anim files are built with n = 0 (unchanged). The sheet maker uses `TOP = 14` and writes the origins in
  body-frame coordinates (minus TOP).
- **Proof that no hat moved**: before redrawing anything, the six old hat sheets with the old origin tables and the new sheets with the
  new tables were composited on a 64x80 frame with a margin for all 135 frames and both facings and compared pixel by pixel: 0 pixels
  differ in 12 sheets x 135 frames (and no pixel was newly visible above the canvas). The golden references (`ref_*`) came out byte
  identical too.

## Redrawn art (all `office/accessories.aseprite`, rebuilt by `tools/make_accessories.lua`; delete a layer and rerun to redraw it)

A hat is now `sil` (rows `{y, x0, x1}`, ink outline on every edge pixel), a `paint(x, y)` rule and optional `over` pixels. Only the
GC colours (look.gd KEEPS): any other colour would be matched to a recolourable source.

| piece | now |
|---|---|
| party hat | 17 rows tall (y -7..9): a striped cone (3-column diagonal stripes pink / cyan), a yellow base band, a 6x4 yellow pom |
| hard hat | dome to y -5 with a lit left, a ridge (3 columns), a rim, a bill at the front (to x 35) and a 7x4 lamp (silver case, white lens) |
| cap | crown to y -4, a panel seam, a button, a lighter front panel with a white logo patch, a bill that curves down at the front (to x 37, y 12) |
| beanie | dome with knit ribs, a folded cuff (fold line, rib columns, dark hem), a 6x5 white pom with grey flecks (top y -8) |
| Santa hat | a cone that rises and flops back, a white pom on the tip (top y -8), a fur band, a shaded side |
| bucket hat | rounded crown to y -3, stitch row, darker band, two eyelets, a drooping brim 30 px wide with a stitched top and a shaded underside |
| lanyard | 2 px strap meeting at a silver clip, a 9x7 badge: teal header, photo block (cyan, a head and shoulders), two text lines |
| HELLO sticker | 9x7, outlined, red header with white letter dots, a handwritten name line |

Seen as composites (right and left facing) on the side-swept intern, long, bob, bald and ponytail hair, in idle, walk, the jump, the hurt
flash, the last death frame, sit and a sit gesture. `tests/accessories.gd` has a new line per hat: its top is N rows above the hair
(party, Santa, beanie 8, hard hat 5, cap 4, bucket 3).

## Reviewed by eye, not changed

- The regenerated jeans (walk 4-11, run 14 and 16, crop of the hips): the stitched waistband and the thigh creases do not break at the
  hip row; no change.
- The button-down long sleeves (walk 4-11, run 12-17, type 39-41, toss 123-128): the elbow creases stay on the elbow, no flicker was
  found. Noticed and not investigated: in the golden outfit references a dark wrist band (the colour of the intern's `Watch` layer)
  shows over the cuff of the near sleeve in some walk / run frames. The clothes pieces were not changed in this pass, so their
  references were not regenerated.

## Tests

`accessories`, `clothes`, `creator`, `brows`, `outfit`, `layout_audit`, `charselect`, `canon_text`, `strings`; `python tools/art_lint.py
--all` (508 files, 0 problems).
