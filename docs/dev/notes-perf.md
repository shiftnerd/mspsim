# Perf notes (slug `perf`): text cache and the metrics board

## What was built
- **Text cache in `PixelFont.draw`** (`godot/scripts/pixelfont.gd`, interface documented in the comment at the top of the
  file). Each distinct (resolved text, integer scale) is built once into a white RGBA `ImageTexture` from the font's own glyph
  data and drawn with one `draw_texture(tex, pos, color)` (colour = modulate, so the shadow copy and every colour share it).
  Before: one `draw_rect` per lit glyph pixel (700 to 7000 per screen). After: one `draw_texture` per string (7 to 57).
  - Key = text after `keys()` and the `_pad_line` route, so pad / keyboard switches need no invalidation (PadGlyphs sprites stay inline).
  - Two-generation bounded cache (`CACHE_ENTRIES` 1500, `CACHE_BYTES` 3 MB per generation, so at most about 3000 entries /
    6 MB); eviction only between frames. Each canvas item keeps a reference to the textures of its latest redraw (meta `_pf`), so
    an item that is not redrawn for a long time never loses its text when the cache rotates.
  - Snapping: the project has 2D pixel snap on and the old rects snapped round-half-down per corner after the canvas offset; the
    texture position is snapped the same way (`ceil(p + origin - 0.5) - origin`), so half-pixel positions (centred text) and a
    fractional camera draw the same pixels. A canvas under any scale / rotation falls back to the old path.
  - `PixelFont.cache_on`: env `PIXELFONT_NOCACHE=1` forces the old path; headless runs are off by default (nothing is drawn),
    `PIXELFONT_CACHE=1` turns it on there.
  - Counters `PixelFont.stat_rect / stat_tex / stat_hit / stat_miss` (reset by assigning 0), `cache_entries()`, `cache_bytes()`,
    `clear_cache()`, `texture(text, scale)`.
  - A text size setting only has to pass its integer `scale`; it is part of the key. A non-integer scale would need a new path.
- **Metrics board digits** (`godot/scripts/dashboard.gd`, `digit()`): the geometry of a 14-segment cell is cached per
  (char, w, h) and offset by the cell position (whole-pixel positions only, else the old code runs), and the diagonal segments
  use `draw_primitive` (a quad) instead of `draw_colored_polygon` (triangulated on every call). `Dashboard.fast_digits = false`
  runs the original code. The paint of the board went from about 2.0 ms to 0.77 ms (script time, 100 repaints in a probe).

## Tests
- `tests/text_cache.gd` (renderer needed; headless it prints SKIP for the picture part and still runs the memory part): old
  path vs new path to images, pixel equality for every glyph, scales 1 to 3, shadows, half-pixel positions, wrapped / centred /
  right-aligned / clipped lines (with and without `clip_contents`), tokens (`{E}`), pad on / off, the font's own pad route, a
  fractional and an integer camera offset, a scaled canvas (fallback), device switches with a warm cache; 64 metrics boards
  (4 modes, 4 sizes, 2 times, cozy on / off) with `fast_digits` on / off. Memory: a synthetic 20-day text stream (clock, money,
  counters, ticket lines; 288000 strings) peaks at 2958 entries / 3.4 MB (limit 3064 / 6.07 MB asserted). A real bot day draws
  nothing headless, so the stream is synthetic.
- `layout_audit`, `pad_prompts`, `click_harness` also pass with `PIXELFONT_CACHE=1` headless (the audit records are made before
  the cache, so they are identical by construction); `pad_glyphs`, `game_art`, `canon_text`, `strings`, `dash` pass.
- `tests/perf_screens.gd` (renderer): walks the layout audit's floor-phase pages in the deck format and forces a full repaint
  (`queue_redraw` on every visible item) per sample; prints per page the font's draw_rect / draw_texture count per repaint and the
  median frame time. `PIXELFONT_NOCACHE=1` for the "before". `tests/frame_time.gd` now prints the text commands a frame.

## Numbers (this PC, Ryzen 9 5950X + RTX 3070, deck format, `tests/frame_time.gd`, three interleaved runs, average frame ms)
| Scene | before | after | text commands a frame before -> after |
|---|---|---|---|
| Bowling | 1.63-1.68 | 1.35-1.43 | 507 -> 4 |
| Paintball | 2.08-2.33 | 1.68-1.97 | 714 -> 12 |
| Chair race | 1.85-2.18 | 1.70-1.92 | 536 -> 15 |
| Dashboard | 6.32-6.45 | 3.48-3.85 | 1824 -> 37 |
| Service board | 2.44-2.65 | 1.84-2.17 | 1088 -> 15 |
| RMM | 2.68-3.15 | 1.83-2.04 | 1533 -> 14 |
Title, main floor and tech day are within noise (no text). The 60 Hz frame of the dashboard fell from 8.4-8.7 to 4.7-5.4 ms.

## Decisions made / not done
- Target "dashboard under 3 ms" is NOT met: 3.5 ms average, p95 4.5-5.1 ms. What is left is about 1.9 ms of GL submission for its
  ~210 draw calls every frame (a static item is resubmitted each frame) and the rest of the Computer's paint.
- GPU draw calls went UP a little with the cache (dashboard 208 -> 217-275, service board 28 -> 55): every string is its own
  texture, so the renderer cannot batch them the way it batched the rects. A shared atlas would fix that; not done (eviction in an atlas is a
  larger change). CPU time still fell.
- `UiStyle` helpers were not instrumented (the text-size work edits the same file); the font counts every text command.
- Other hot spots: the profiler MCP was not used; timers on the dashboard showed the digit paint as the one big non-text cost
  (fixed above). Main floor, paintball, chair race are at 1.4 to 2 ms with nothing text-shaped left.
