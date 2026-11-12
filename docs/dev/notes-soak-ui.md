# Build notes: UI input fuzzer (agent `soak-ui`, Nov 2026)

## What was built

- `tests/fuzz_lib.gd`: the engine (a RefCounted). `Lib.new(tree)`, `fuzz_screen(name, seed, frames)`, `sequence_campaign(mode, seed, frames)`.
  It opens one screen (`open_screen`, names in `TITLE_SCREENS` / `FLOOR_SCREENS`), sends `frames` frames of a seeded random event
  stream, then runs `recover()` and collects every engine error through a `Logger` (`OS.add_logger`, so SCRIPT ERROR and ERROR:
  come with file, line and function).
- `tests/fuzz_ui.gd`: the long harness (not in the default suite: `run_tests.py` SKIP).
  `Godot --headless --fixed-fps 60 --path godot -s res://tests/fuzz_ui.gd -- --seconds=6 --seed=1 [--screens=title:home,floor:computer:*] [--rounds=N] [--sequences] [--chaos] [--coop] [--log=FILE] [--list]`.
  `--log=FILE` appends every line as it happens (stdout is buffered when redirected). Exit code 1 when a bug was found.
  A run with a window (no `--headless`) also audits text against the viewport (`PixelFont.audit`) and picks a random format per screen.
- `tests/fuzz_ui_smoke.gd`: nine screens, 1.5 s each, in the default suite.
- `tests/fuzz_regress.gd`: replays the seeds of the bugs below.

## The event stream

Per frame 0-3 events from: keys (every `Controls.ACTIONS` key, arrows, Enter, Esc, letters, digits, keypad, F-keys, random codes; 10 %
with shift / ctrl / alt / meta; echo repeats), held keys (released 2-40 frames later), pad buttons and axes of pad 0 and pad 1 (pad 1
events are also sent straight to every autoload's `_input` / `_unhandled_input`, because a second pad's events never reach those
headless), mouse moves, clicks (left, right, middle), double clicks and wheel at random logical points (a few outside the viewport),
focus out and in (`NOTIFICATION_APPLICATION_FOCUS_*` with `Game.focus_force`), format cycle (SHAPE / F9), Alt+Enter on the window,
key then pad then mouse device switches, the touch overlay on and off, rapid open / close of Esc / P / Pause / J / Y / E / Enter, co-op
join and leave (`--coop`), and (`--chaos`) things that arrive by themselves in a real game: a card, a phone banner, the day report,
an outing, the Computer, a day change. The title's QUIT row is never clicked or left selected (it would end the run).

## The checks after a burst (`recover()`)

1. Esc up to 10 times (pad B when the screen is still open) must leave nothing open (`modal()`: Cards, DayReport, Review, Computer,
   Phone, Outings, Toolbox, PrinterGame, PauseMenu, an Expo session, the outfit screen, `Game.ui_open`; on the title: the settings
   pages, character select, career, the menu). If not, Enter / A / Esc up to 6 more rounds (a card and the report want an answer).
   Still open = `softlock`.
2. The tree is not paused, `Game.focus_lost` is false, `Engine.time_scale` is 1, `Game.busy` clears (`stuck_pause`, `stuck_focus`,
   `time_scale`, `stuck_busy`).
3. A new input has an effect: Esc opens and closes the pause menu on a quiet floor, Enter opens the title menu (`dead_input`).
4. No engine error during the burst (`error`), orphan node growth below 60 per burst (`orphans`), no text outside the viewport
   (`offscreen`, windowed runs only).

## Bug log

Seeds replay the same event stream (`--screens=NAME --seed=N --seconds=3`); wall-clock effects (a card ignores input for 0.45 s)
can move a result between runs, so each fix also has a reduced regression in `tests/fuzz_regress.gd`.

| # | Screen / seed | What happened | Status |
|---|---|---|---|
| 1 | `floor:free`, seed 1 (SCRIPT ERROR) | `charselect.gd:1228 Out of bounds get index '3'` in `_click` "sw": the swatch hit list belongs to the last drawn page; the page turned before the next draw and the old row index ran past the new page's rows. | FIXED: the click is ignored when the row is not on the page (regress 1) |
| 2 | `title:sub:tech` seed 2, `title:settings` seed 2 (SCRIPT ERROR) | `title.gd:686 _on_select_done: Cannot call method 'queue_free' on a null value`: GO answered twice in a frame (a double click, Enter twice) after the select was freed. | FIXED: `_on_select_done` returns when no select is open (regress 2) |
| 3 | `floor:boardroom:clients`, `floor:computer:shop`, `floor:knowledge` seed 2 (dead input) | A pause from losing focus sits over an open phone / computer; QUIT TO TITLE then left the phone open over the title, and it ate the title's Enter (`Game.ui_open` stayed true). | FIXED: `Game.go_title` closes the Computer and Phone and clears `ui_open` (regress 4) |
| 4 | card with a greyed-out row (found by the recovery, seed 1) | A mouse hover selected a greyed-out option; Enter then did nothing and a card could look stuck. A stale hit rect could also carry an index past the options. | FIXED: hover skips disabled rows and bad indexes (regress 3) |
| 5 | `floor:computer:nerds`, seed 100 (3 SCRIPT ERRORs) | `forum_view.gd:229 / 277 / 316`: a key in the NERDS forum before its first paint built the rows with the Computer's text helpers while `c` was still null; Enter on a row with no action indexed `parts[1]` of a one-element array; PgUp / PgDn indexed `_rows[sel]` with no rows. | FIXED: no rows without a Computer, `act` ignores short actions, bounds check (regress 5) |
| 6 | `floor:knowledge`, `title:flow:sales`, `floor:computer:shop`, seed 601 | A card open or queued when the run was left for the title came up over the title screen (Enter did nothing: the card had the keys). | FIXED: new `Cards.clear_all()`, called by `Game.go_title` (regress 6) |
| 7 | sequence `campaign:tech`, seed 1100 | Esc / pad B on the Free Play menu card did nothing: its way out is a CLOSE row and `Cards._pick_leave` only knew `leave` and `__none`. | FIXED: `close` is a leave id too (regress 7) |

Seen once, not reproduced (timing dependent): `title:flow:service` seed 601 in a 2-round pass, charselect still open on step `char`
after 17 back presses with the touch overlay on (the same seed alone passes).

Harness bugs the first runs showed (not game bugs, fixed in the harness): the recovery pressed Enter on charselect pages (moved
forward again), pressed Esc on a quiet floor (opens the pause menu), looked at Cards before the pause menu that sat above it,
needed a real 0.47 s wait for a card that opened during the recovery, started `nerf` through `Outings.start` (not an Outings
game), gave the printer a callback with no argument, treated a campaign resumed in another room as a failed CONTINUE, let chaos
open cards on the title, called the day report while an outing was open (the clock stands still there), sent a Down and an
Enter in one frame at the title's QUIT row (`get_tree().quit()` ended the process, so the title menu gets one event a frame now),
and read the phone banner sliding in as off-screen text. The order the recovery looks at screens follows who gets the keys first
(autoload order, last first): pause menu, toolbox and outfit overlay, printer game, then cards, report, review, Computer, Phone,
outings. A talk (Expo session) is sat through with Enter once its line has been up 0.35 s of game time.

Things that looked like soft-locks and are by design: Free Play chains outings (a result page answered with Enter starts the
next), the year-end Review has no Esc (Enter pages through it), Esc on a quiet floor opens the pause menu.

Design notes the fuzzer turned up, left alone: a card that opens over the outfit overlay or the toolbox cannot be answered with the
keyboard until Esc closes those (they take every key first; a click works).

## Runs (headless, `--fixed-fps 60`; seconds are game seconds, 60 frames each)

| Run | Screens | Events sent | Bugs left |
|---|---|---|---|
| first passes while the harness was shaken out (seeds 1, 2, 100, 600, 700, 200-500, 800-1200) | about 1 300 bursts | about 650 000 | all triaged above |
| clean batch 1 (seeds 1300-1800: title x28, floors x65, sequences, chaos floors x65, co-op floors x65, everything x186) | 410 | about 220 000 | 0 |
| clean batch 2 after merging `main` (TEXT size and CONTRAST events in the stream; seeds 2100-2600) | 410 | about 218 000 | 1 harness case (chaos day report over an outing, fixed in the harness) |
| windowed pass (renderer, a random format per screen, text audited; seed 3000) | 93 | 21 975 | 0 (two phone-banner slide-in lines, filtered) |

Replay a line: `Godot --headless --fixed-fps 60 --path godot -s res://tests/fuzz_ui.gd -- --screens=NAME --seed=N --seconds=S [--chaos] [--coop]`
(`--rounds=2` uses seed and seed + 1). `FUZZ_VERBOSE=1` in the environment prints one line per recovery round with the open state.

## Not covered

- The "quit to title -> continue" sequence ran for the four campaigns at 40 s of game time each (`--sequences`); a real 2 minute
  run per mode (`--sequences --seconds=30`) was not done. Year 2 / Year 3 rows are fuzzed as `title:year2`; the Review pages and
  endings as `floor:review:*` and `floor:report:ending`.
- Orphan growth is checked per burst (60 nodes); a slow leak over hundreds of screens is not measured.
- Player 2's pad is driven through direct handler calls (a second pad's events never reach an autoload's `_input` headless).

