# QA notes: menus, HUD and screens in a real window (agent `qa-ui`, Nov 2026)

Two days of agent work had changed most menus, HUD pieces and screens with only headless tests behind them. This pass
ran the game in a real window on a 2560 x 1440 Windows 11 desktop (OpenGL Compatibility, RTX 3070), looked at the
pictures and fixed what was wrong. Screenshots were kept outside the repo.

## Method

- **Item 1 (display)**: a normal start (`Godot --path godot`, no `MSPSIM_TEST`, no `-s`), driven through the
  `godot-runtime` MCP in *attach* mode (the launch is ours, so the game is not a dev run). Real key events
  (`simulate_input`), window state read with `run_script`, and the **real screen** grabbed with GDI
  (`CopyFromScreen`, the game's client area only) so scale, blur and bars are measured in monitor pixels: a script
  checks that every logical pixel is one uniform N x N block and reports the bar colour. Focus was moved for real
  (`SetForegroundWindow` to the taskbar and back). The settings file was backed up first and restored afterwards
  (all `mspsim_*` files compared equal to the backup at the end).
- **Items 2 to 4**: `tests/layout_audit.gd -- --shots` in a window with `MSPSIM_TEST=1`; the 749 pictures were packed
  into contact sheets (four formats of one screen at 2x) and read. Screens the audit did not have got a block in it.
- **Item 5**: `tests/readme_shots.gd` (new), see below.
- A GDI grab of an **exclusive** full-screen window is stale (it shows the last composed frame): give the focus away
  and back before grabbing. The game itself is fine; the viewport image (`take_screenshot`) is always current.
- The desktop is shared: another agent's game window took the focus now and then. A lone `Alt` (what `SendKeys('%')`
  sends) reaches the game; use a key nothing listens to (F15) for the foreground trick.

## Findings

Severity: H = blocks or breaks a screen, M = visible defect, L = polish. Formats: wide 368 x 128, h 320 x 180,
deck 320 x 200, v 180 x 320.

| # | Screen | Format | What was wrong | Sev | State |
|---|---|---|---|---|---|
| 1 | Full screen | all | `MODE_FULLSCREEN` on Windows is a 2560 x 1442 window: the picture sat 2 px low under a black line and lost its last 2 screen rows | M | FIXED: `Game.FULL_MODE` = exclusive full screen (2560 x 1440, offset 0, measured) |
| 2 | Window after SHAPE / F9 | all | the window kept its old top left corner when the shape changed (h to v grew downwards; on a 1080p screen v ran off the bottom), and its size ignored the screen (wide x4 is 1472 px: wider than a 1366 px laptop) | M | FIXED: `Game.place_window()` centres in the screen's free area at `window_scale()` (the largest whole scale up to the format's own that fits). Dev runs keep the plain size |
| 3 | Alt+Enter, F11 | all | Alt+Enter was a plain Enter (it pressed the menu row under the cursor: on CONTINUE it would load a save); F11 did nothing (a debug build uses it for room jumps) | M | FIXED: Alt+Enter flips DISPLAY anywhere and is swallowed (`Game._window_input`); F11 does the same in a release build only |
| 4 | SETTINGS (title) | wide | eight rows in a 114 px panel: CAREER sat under the footer line | M | FIXED: rows shrink to 11 px when the panel is short (`PauseMenu._row_rect`) |
| 5 | Owner week report | wide, h, deck | no handling of a long list: with the optional rows (OWNER DRAW, WIRE FRAUD RISK, STANDARD, FOLDER, SWITCHING COSTS, RAP SHEET, ASKED FOR BY NAME, PEER GOAL) the panel was taller than the screen and NEXT DAY was off it | H | FIXED: the last rows go under the grade box, then the list gets pages (button `MORE 1/2`) |
| 6 | Owner week report, SWITCHING COSTS | all | the value is a 110 character sentence, drawn right-aligned on one line: it ran out of the panel on the left (off the screen in v) | H | FIXED: a value wider than the row wraps (`DayReport._row`) |
| 7 | Phone banner | all | a banner caught half way in by a screen that opens (Computer, card) froze there, on top of that screen, for as long as it stayed open | M | FIXED: it goes back to the front of the queue and plays again afterwards, without a second buzz |
| 8 | Phone banner | v | the 150 px card left the ends of the status lines and the clock sticking out at its sides | L | FIXED: the card spans the screen below 220 px |
| 9 | Goal chip + touch overlay | all | the touch MENU button covered the chip's text (NEXT list in wide / h / deck, the end of the GOAL line in v) | M | FIXED: the chip keeps 29 px clear of the right edge while the touch overlay is on |
| 10 | HUD status lines, clock | h, deck, v | white text with a 1 px shadow over the ceiling's lamps did not read | M | FIXED: the same soft dark plate as the goal chip behind the status lines and the clock |
| 11 | Title, SOUND ON / OFF label | all | grey text on the beige ceiling tiles | L | FIXED: dark plate, lighter text |
| 12 | Layout audit, `--only=floor` | all | 40 failures. Not windowed against headless (both gave the same 40): against the full run. Without the title phase the run is a first run: the day-10 dated card (XP end of support) and the day-one card open over the HUD ("nothing was drawn"), and a text banner slides in while the Computer screens are audited (text above the top edge) | M | FIXED in the test: cards cleared after the day is set, `_end` waits for a banner to be fully in; plus finding 7. Windowed and headless, whole and `--only=floor`: 0 failures |
| 13 | Layout audit, "title submenu" | all | the block pressed row 0, which is NEW (or CONTINUE) since the home menu: the tech submenu with START YEAR 2 / 3 was not what got audited | L | FIXED: `_show_sub("tech", 0)`; new block "title home continue" |
| 14 | Layout audit, "phone contacts levels" | all | the phone stayed locked: the lock screen was audited, not the contacts with their pips | L | FIXED |
| 15 | Touch overlay + hint bar | wide, h, v | the stick and the X button sit over the ends of the yellow hint bar at the bottom (the text still reads through them) | L | not fixed: needs a decision where the hint goes on a touch screen |
| 16 | Touch overlay + phone | v | the ROLL button covers PHOTO SAVED in the camera app | L | not fixed |
| 17 | Career, last collection page | h, v | one orphan row (MORE TROPHIES) alone on its own page | L | not fixed |
| 18 | Career footer | v | `ESC BACK` ends 2 px before the `<` button | L | not fixed (fits) |
| 19 | Title | h | PRESS START is drawn across the legs of the cast | L | not fixed |
| 20 | Escape room (seen in the other agent's window) | h | a MEDAL EARNED toast drew over the two hint lines at the bottom | L | not fixed, not reproduced here: reported for the rooms pass |
| 21 | `tests/phone_ui.gd` | - | `FAIL urgent tickets text you` (fails on `main` too, not in the default suite) | L | not fixed, not this pass's |

Looked at and fine (all four formats unless noted): the home menu with CONTINUE (six rows) and without; QUICK PLAY;
SETTINGS (eight rows) after fix 4; the tier step, the run options (LEVEL / START / SEED / TOOLS) and the creator; the
goal chip with its next-up list on a busy day; a four-option card with prices and a greyed `[NEED $600]` line; the phone
banner; the hint line with pad glyph sprites (wide); the pause menu in tech (TICKET PACE), in Free Play (FREE PLAY
MENU, seven rows) and the quit question with `SAVED AS OF 11:00 TODAY`; the day reports (sloppy note with the UNBILLED
FAVOURS row in the data, trip note, ending); the owner report with every row; the career totals, the 72 medals (10 a page in wide, 18 in h) and the
collection pages; the tech submenu with START YEAR 2 and START YEAR 3; the contacts with pips; Dispatch CAPACITY with
the FAN mark; the title's toolbox rows and the seed wheels; the last page of the tech review (wide, v).

Display behaviour as measured after the fixes: a normal start is full screen in `h` at x8 (2560 x 1440, every block
uniform, no bars); `wide` x6 = 2208 x 768 centred on black; `deck` x7 = 2240 x 1400; `v` x4 = 720 x 1280; DISPLAY:
WINDOW gives a centred window (h 1280 x 720, deck 1280 x 800, v 540 x 960, wide 1472 x 512) and the choice, the shape and
UNFOCUSED survive a restart; focus loss opens the pause menu in a room and holds the tree on the title; UNFOCUSED: RUN
keeps it running; an exclusive full-screen window keeps its mode and size across a focus loss.

## Prompts seen that still show a key on a pad (reported, not converted)

- SETTINGS footer with a pad active: `NEXT MORNING  LEFT RIGHT = CHANGE` (audit shot "title settings pad").
- Career and collection footers: `ARROWS  C = COLLECTION  ESC`, `ARROWS  ENTER = DETAILS  ESC BACK`.
- Dispatch buttons `FOCUS (F)`, `1:1 (O)`; CRM footer `C CALL  V VISIT  Q QUOTE  A ASSESS`.
- Day report hint `ENTER OR CLICK` (the code agent has this one).

## What was built

- `game.gd`: `FULL_MODE`, `window_scale(name, room)`, `place_window()`, `_window_input(event)`; `set_fullscreen`,
  `start_display` and `set_format` use them.
- `day_report.gd`: `_row` wraps values; `_fit` (rows under the grade box, `_spill`); pages (`_pages`, `_page`,
  `next_page()`, the button reads `MORE n/m`). `finish()` is unchanged: a bot that calls it skips the pages.
- `pause_menu.gd`: `_row_rect` row height from the panel.
- `phone.gd`: `step_banner` requeues a blocked banner (`again` = no second buzz).
- `hud.gd`, `goals.gd`, `title.gd`: plates, the banner width, the chip's `keep`.
- `tests/layout_audit.gd`: blocks `title home continue`, `hud phone banner`, `hud hint keys` / `pad`, `pause tech`,
  `pause quit saved as of`, `pause free play`, `day report owner_full` (+ its pages); fixes 12 to 14. 749 screens.
- `tests/deck_display.gd`: Alt+Enter, `FULL_MODE`, `window_scale`.
- `tests/readme_shots.gd` (new, renderer): the README / manual pictures, see its header.

## Decisions made

1. **Exclusive full screen** everywhere rather than compensating for the 2 px: it is the mode with the screen's exact
   size on Windows, and Linux / the Deck do not care.
2. **A window never exceeds the screen**: smaller whole scale instead of a window that hangs off it.
3. **Alt+Enter is global, F11 only in release builds** (debug builds keep the F11 room jumps).
4. **Pages before a scroll bar** for the long owner report: Enter already means "next".
5. **HUD plates** use the goal chip's colour (`Goals.BACK`), so the top of the screen reads as one family.
6. The hint bar under the touch controls was left: moving it is a design question (finding 15).

## README

`README.md` got a WHAT IS IN THE BOX table, the fifth shape (`deck`), the full-screen start and DISPLAY, the gamepad
column brought up to date, and four more pictures (owner Boardroom, sales CRM, paintball on the western street, the kitchenette). Regenerated in
`docs/manual/img/` by `readme_shots.gd`: title, title-home, title-menu, cubicles, conference, warehouse, kitchenette,
bowling, psa, rmm, creator, plus the new boardroom, crm and paintball. Left as they were: `desktop.png` and `hud.png`
(hand-marked), charselect, creator-presets, mail, pause, pause-controls, phone.

## After the merge with main

Windowed whole audit: 813 screens, 0 failures (card faces from the portrait work read fine in all four formats). The required tests, gdlint and the generator check are green; no bridge autoload is left in project.godot and the real settings and save files match the backup.
