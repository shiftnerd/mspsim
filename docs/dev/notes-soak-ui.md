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

Harness bugs the first runs showed (not game bugs, fixed in the harness): the recovery pressed Enter on charselect pages (moved
forward again), pressed Esc on a quiet floor (opens the pause menu), looked at Cards before the pause menu that sat above it,
needed a real 0.47 s wait for a card that opened during the recovery, started `nerf` through `Outings.start` (not an Outings
game), and gave the printer a callback with no argument.

Things that looked like soft-locks and are by design: Free Play chains outings (a result page answered with Enter starts the
next), the year-end Review has no Esc (Enter pages through it), a Card's Esc only picks a `leave` option, Esc on a quiet floor
opens the pause menu.

## Not covered yet

- TEXT SIZE (agent `textsize`) and the text drawing change (agent `perf`) were not on `main` when this was written: merge, rerun
  `tests/fuzz_ui_smoke.gd` and fuzz their screens.
- A windowed run (text against the viewport, random formats) needs a renderer; the long headless passes did not audit text.

