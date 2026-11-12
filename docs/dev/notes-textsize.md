# Build notes: TEXT size and CONTRAST (agent `textsize`, roadmap R42 item 4, Nov 2026)

Valve's Steam Deck checklist and Microsoft's handheld guidance both ask for "user-configurable text size and contrast
where possible" and a larger option for bitmap fonts (`docs/steam-deck.md`). The game's font is a 5 px bitmap and every
screen lays out from the viewport size, so the answer is not to scale the font: it is to give the screens fewer logical
pixels per physical pixel. This file says what was built, why this route, and what it cost.

## 1. What the player gets

SETTINGS (the title's page and, through the same `PauseMenu`, the pause menu in a room) has two new rows right after SHAPE:

| Row | Values | Effect |
|---|---|---|
| `TEXT: NORMAL / LARGE` | `Game.text_large` | the picture is drawn in a smaller logical size at a higher whole scale: letters, people and rooms are 1.14 to 1.33 times bigger on the screen |
| `CONTRAST: NORMAL / HIGH` | `Game.high_contrast` | dim text is pushed away from the middle grey (grey on a dark plate lighter, grey on a light panel darker), HUD plates go solid, panel borders get a second line |

Both apply at once, are saved in the settings file (`[display] text_large`, `high_contrast`) and read back by
`Game.load_display()`, work with Left / Right / Enter on a keyboard and the D-pad / A on a pad (the footer says
`LEFT RIGHT = CHANGE` through `Controls.hint`, so a pad shows its glyphs). The default is NORMAL everywhere: nothing
calls `set_text_large`, not even on a Steam Deck or a 1920 x 1080 screen (`tests/text_size.gd` asserts it).

## 2. Design: LARGE is a smaller logical picture (decision)

Options weighed:

1. **Scale the font** (`PixelFont.draw(..., scale 2)` for everything): every layout in the game assumes 4 px per letter;
   hundreds of call sites. Rejected.
2. **A second font**: no art budget in this batch and the same layout problem. Rejected.
3. **Fewer logical pixels per physical pixel** (built): a `LARGE` row per format in `Game.LARGE`; `Game.info(name)` returns
   the format row for the text size in force (size and scale replaced); `Game.set_format`, `fit`, `window_scale`,
   `place_window` and the five scripts that read `FORMATS[format]` (stage camera, chair / paintball tracks, outings room
   camera, title, character select, toolbox) go through it. Everything else already lays out from the viewport size, so
   most screens needed nothing, and the integer-scaling rule is unchanged.

| Format | NORMAL | LARGE | what a screen gets (glyph px: NORMAL -> LARGE) |
|---|---|---|---|
| `deck` | 320 x 200 (x4) | 256 x 160 (x5) | 1280 x 800: 20 -> 25 px, fills the panel exactly |
| `h` | 320 x 180 (x4) | 256 x 144 (x7) | 1920 x 1080: 30 -> 35 px (87 % of the screen, bars 64 x 36); 1280 x 720: 20 -> 25 px exact |
| `wide` | 368 x 128 (x4), fixed room view | 320 x 112 (x5), the camera follows | 1920 x 1080: 25 -> 30 px |
| `v` / `vclose` | 180 x 320 (x3) | 144 x 256 (x4) | a 1080 px wide phone: 30 -> 35 px |

Sizes were chosen by running the layout audit: `h` at 240 x 135 (x8 on 1080p, a perfect fill) broke the character creator
(135 px is too short for it) and `wide` at 296 x 104 broke a dozen screens, so both were relaxed to the next size that
passes without a per-screen exception. `deck` 256 x 160 is the exact 1/5 of 1280 x 800.

Trade-offs, honestly:

- LARGE shows less of the world: 20 % fewer logical pixels each way. The room camera follows the player in every format
  (`wide` LARGE turns `follow` on; its NORMAL picture is the whole room, a LARGE one cannot be). The co-op split
  screen and the mini-game cameras read the format row through `Game.info`, so they follow.
- Sprites are bigger too (they are drawn in the same logical pixels). That is the point of the route, and also why it
  is not "text only": there is no text-only option without touching every layout.
- Wider text wraps (cards, hints) and a few lists scroll; none of it changes a rule or a number.
- `h` LARGE on 1080p leaves 13 % bars; `240 x 135` would fill but is too short for two screens (listed above).

### What had to change for LARGE (every other screen passed untouched)

| Screen | Change |
|---|---|
| UiStyle hint bar and panel footers (all outing, toolbox and menu footers) | a hint wider than the panel breaks at its spaces and grows upward (`UiStyle.fit_lines`, `hint_bar`, `footer`; the caption bar sits above a taller hint bar through `hint_extra`) |
| Character select, creator, outfit overlay, seed page | compact rows below 150 px (`SHORT_H`, was 130), tab chips pack closer, preset buttons shrink, key lines wrap (`_keys_line`), side notes (`READY-MADE`, `3 LOCKED`) drop to a count or nothing when they do not fit |
| Build step panel | below 300 px the right column moves in (`col_w` 122, `rx` 134), a chip drops its label if the value is long |
| Title menu | the short layout (logo at the top, prompt at the side) starts at 300 px wide instead of 340 |
| Pause menu / SETTINGS | ten rows now: rows never get thinner than 8 px and the list scrolls (`_vis`, `_first_row`, marker triangles) |
| Toolbox rows | the list scrolls on a short picture (the escape room has 11 rows) |
| Day report | last-resort `_tight` mode closes the gaps between blocks |
| Card | a very short screen puts the card at the top edge and closes the gaps between answers |
| Year review | an offer's label wraps onto two lines |
| Computer: PowerShell Academy, boardroom clients | lesson rows pack, a column with no room is left off instead of clipped to `P..` |
| Outings (narrow panel) | dinner stacks the table under the answers and shortens its heading; paintball, darts and grill lines wrap (`_tl`, `_tb`) |

One screen does not fit, and falls back: the **printer mini-game on `v` LARGE**. It lays out a fixed 176 px panel with
hard-coded columns (tray, toner, test lists, intro text), so 144 px wide breaks about 40 texts. `Game.FALLBACK =
{"printer": ["v"]}`: `PrinterGame` calls `Game.large_hold("printer")` when it opens and `large_release` when it closes, and
while it is open `Game.info()` answers with the NORMAL row (the picture re-frames to 180 x 320 for that screen only).
`tests/text_size.gd` names the table and checks the hold / release. Every other screen, in all four shapes, passes the
layout audit at LARGE. (A first version also held the outing games on `v` and the creator on `wide`; both were fixed by
layout instead, and only the printer remained.)

## 3. HIGH contrast (`scripts/text_size.gd`)

- `TextSize.color(c)`: with HIGH on, text with luminance >= 0.55 goes 65 % to white, text <= 0.40 goes 60 % to ink, mid
  tones stay. One line in `PixelFont.draw` (`color = TextSize.color(color)`), nothing else in the font.
  Chosen over remapping `UiStyle.MUTED` / `SOFT` because those are `const`s used in 120 places and many screens carry
  their own greys; the luminance rule needs no knowledge of the plate behind. Trade-off: a mid-tone text (gold, red status
  text) is not changed; a light text on a light plate (rare) would get worse.
- `TextSize.plate(alpha)`: HUD strips, boxes, the hint bar and the caption bar (`UiStyle.strip`, `box`, `hint_bar`,
  `caption_bar`) are at least 97 % opaque, so the room never shows through letters.
- `TextSize.edge(canvas, rect)`: `UiStyle.panel` adds an ink line outside and a white line inside the border.
- Not done: a per-text dark plate behind the HUD chips drawn straight over the world (hud.gd draws its own plates; they
  stay as they are), and any change to sprites.

## 4. Tests

| Test | What it proves |
|---|---|
| `tests/text_size.gd` (headless, 9 s) | the LARGE table (every format, scale never smaller, the Deck's 25 px glyph at x5 on 1280 x 800, 1080p, 720p), nothing switches LARGE on by itself (a 1280 x 800 and a 1920 x 1080 start), the setting applies at once to the window's content size in every shape, is saved, read back and survives SHAPE, both rows exist in SETTINGS and in the pause menu (campaign and Free Play) and toggle with keyboard and pad, every row is drawn inside the panel at LARGE in all four shapes (scrolling), contrast colours and plates, hint wrapping |
| `tests/layout_audit.gd` (renderer) | `FORMATS` gained `wide+L`, `h+L`, `deck+L`, `v+L` and `deck+LC` (LARGE with HIGH CONTRAST): every screen of the walk, 1905 screen passes over all nine, 0 off-screen texts. `-- --formats=deck+L` picks passes. The SETTINGS block visits the TEXT row and the last row |
| `tests/pad_prompts.gd` (renderer) | walks the same list (it extends the audit), so the pad and keyboard prompt scans cover LARGE and HIGH CONTRAST too |
| `tests/tap_targets.gd`, `deck_display`, `title_menu`, `cozy`, `outfit` | existing tests; the last three were updated for the two new rows |

Windowed check: see section 6.

## 5. Public functions

- `Game.info(name, large := text_large)` -> the format row; `Game.logical_size()`; `Game.set_text_large(on)`,
  `Game.set_high_contrast(on)`; signal `Game.text_changed`; `Game.LARGE`.
- `TextSize.color / plate / edge / apply`, `UiStyle.fit_lines`, `UiStyle.hint_extra`.
- `PauseMenu._vis()`, `_first_row()` (scrolling), `_text_label()`, `_contrast_label()`; row ids `text`, `contrast`.

## 6. Windowed check

Run as a real (non-headless) window with `MSPSIM_TEST=1` through `tests/layout_audit.gd -- --shots --settle=40` (the
audit walks the real screens, then waits out the fade-ins and saves the rendered viewport; the PNGs were upscaled x4 with
nearest-neighbour and looked at with the Read tool, saved OUTSIDE the repo in the scratchpad folder `textsize_shots`):
title menu, tech HUD (goal chip), a long card, the Computer desktop and mail, the pause menu, SETTINGS on the TEXT row,
the creator and the day report, at `deck+L` (256 x 160) and `wide+LC` (320 x 112, with HIGH CONTRAST). What the first look
found and what was fixed: the first screenshots were taken mid fade-in (the audit only waited 4 frames), so it got a
`--settle=N` argument; the 320 x 112 title menu ran off the bottom (the short title layout now starts at 300 px); the
day report with an ending ran 2 px past the bottom (`_tight`). The final shots show nothing cut, no overlap on the
pause menu rows, the HIGH CONTRAST border ring and plates on the pause menu, and the day report whole in both shapes.

## Decisions made

1. LARGE is a format property, not a font property (section 2).
2. Default stays NORMAL on every screen, including 16:10 and 1080p: no auto-switch.
3. `h` LARGE is 256 x 144, not 240 x 135 (the creator does not fit in 135 px).
4. `wide` LARGE is 320 x 112 and follows the player.
5. Contrast is a luminance push in the font hook plus solid plates, not a new palette.
6. Two rows (TEXT, CONTRAST) rather than one three-state row: they are independent, and a pad toggles each with one press.

## Left open / art I would want

- Hardware: whether 25 px glyphs are comfortable on the 7 inch panel is still a question for a real Deck.
- `perf` agent: `PixelFont.draw` now calls `TextSize.color` first; a draw cache must key on `TextSize.high`.
- No art needed.
