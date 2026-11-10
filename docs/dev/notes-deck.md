# Build notes: Steam Deck readiness (agent `deck`, roadmap R42, Nov 2026)

Builds on the controls batch (`docs/dev/notes-controls.md`). The player-facing summary and the Deck Verified
checklist are in `docs/steam-deck.md`; this file is what was built, where, and how to test it. No Deck, no pad and no
Steamworks account were available: everything is proven with headless or windowed tests on a Windows desktop.

## 1. Pad-only gaps closed

### Bindings (`Controls.ACTIONS`)

- **The right stick is the gesture stick**: up `dance`, down `follow`, left `give_item`, right `mute` (axis bindings,
  pressed past half way). `dance` and `follow` are polled by the player as before; `mute` got a pad branch in
  `Sfx._unhandled_input`.
- **`Controls.matches(event, action)` is direction-aware for stick events** now: `InputEvent.is_action()` is true for
  both ends of an axis, so a stick event only "is" the action of the side it is pushed to (`is_action_pressed`).
- **`Controls.label(action)`**: right-stick actions print `RS UP` / `RS DOWN` / `RS LEFT` / `RS RIGHT`.
  **`Controls.help_value`** (the pause menu's key list) shows the pad's button for a row that has one while
  `pad_active` (`HELP_ACTIONS` gained `MUTE SOUND`; `START A WAR, GIVE` prints `(Y), RS LEFT`).
- **`outfit`** (L3) worked for player 2 only; `Toolbox._unhandled_input` takes the pad button for player 1 too.

### The first player's pad in the room (`Player._pad_input`)

Pick, aim, war and give were in the keyboard-only half of `Player._unhandled_input` (the manual said so: "the player
does not listen to them yet"). Slot 0's pad now does: **RT** aims and fires (`Nerf.charge_start` / `charge_release`),
**RB / LB** move the pick arrow (LB only while no drink is in the hand: LB also sips), **Y** with the blaster offers a
war, **RS left** gives the blaster away.

### A press belongs to one thing (`Player._ui_hold`)

A pad's A is jump **and** confirm, X is use **and** the Computer's hotkey press, the D-pad walks **and** steps a
menu. The player polls actions, so the A that answered a card also stood you up from your chair (found by the
walkthrough: the seat was lost and the Computer would not open). Now the body takes no input while a team card is
open and for two physics frames after a card, a screen (`Game.ui_open`) or a pause. The keyboard had the same leak
with the arrow keys (Up is jump); it is gone for both.

### Every Computer and phone button (`Controls.focus_step`, `Computer._pad_reach`, `Phone._pad_reach`)

Single player had no cursor on a pad. Now:

- **RB / LB** step the cursor through the screen's click regions (`_hits`) in reading order: `Controls.focus_step(hits,
  at, step)` returns the centre of the next region (regions with id `none` only block clicks and are skipped).
- **A** presses the region under the cursor while `pad_focus` is true (set by RB / LB or the right stick); a D-pad or
  left stick move clears it, so A is the list's Enter again. After a press that changes the app, `pad_focus` drops.
- **The right stick** moves the Computer's cursor freely (150 px / s, `Computer._stick`).
- On opening with a pad the Computer shows a 4 s note (`(RB) (LB) STEP THROUGH THE BUTTONS  (A) PRESS`), the phone
  `(RB) NEXT BUTTON`.
- Only the full-window instances and slot 0's pane (`pane_slot <= 0`); player 2's pane keeps the `panes.gd` cursor.
- The letter hotkeys (CRM, Dispatch, Knowledge) stay on the Y / X strip.

### Mini-games

- **Escape room, page game**: the hint key `H` has a pad twin, the `nudge` action (Y; the N key too). The footer
  shows `(Y) = HINT` (`Outings._hint_map`).
- **Chair race, cookout, paintball**: B is a game button there (push, cool side, duck), so nothing left the game on
  a pad. The pad's **BACK** button leaves in those three (`Outings._event_key`), and the hint line prints `(BACK) =
  LEAVE` instead of `(B)`. The cookout and paintball hint lines do not mention leaving at all (keyboard neither).
- **Karaoke**: a pad never let go of a hold note (`_kara_release` only saw key releases). A released D-pad button or
  the stick back in the middle releases it now.

### Still not on the pad

Putting a keyboard key on an action (remap page), a typed word as the seed (wheels exist), `pose_prev` / `pose_next`
in the creator (Y holds the pose), the debug keys, and `career` (J) which is a pause menu row.

## 2. Tests

| Test | What it proves |
|---|---|
| `tests/pad_only.gd` (15 s) | Pad events only, through `Input.parse_input_event`: title, NEW, the creator (a row, RB / LB pages, the letter grid, DONE), phone, tier, options, build, the tech campaign's first morning: walk to the desk with the stick, X sits, Dan's card by D-pad and A, X opens the Computer, the ticket is taken, fixed in a remote session and closed (every button by RB + A), the right stick cursor, the phone (BACK, unlock, apps, camera), the pause menu (DAY LENGTH, TICKET PACE), quit to title, CONTINUE with the settings and the closed ticket intact. |
| `tests/pad_only_games.gd` (42 s) | From the title into Free Play by pad, then each game from START, FREE PLAY MENU, TOOLBOX: bowling (a ball rolled, left), karaoke (notes hit on the D-pad, left), the escape room (nudge, a clue, the code dialled: **finished**), dinner (**finished**), the printer (a jam pulled, a prayer, given up), a nerf war (**run to the end**), the chair race (**finished**), the gauntlet and the chair fight (left with BACK), paintball (run, lane, fire, duck, left with BACK), cornhole (a bag thrown, left), the cookout (left with BACK), darts (**finished**). Then the blaster rack in the cubicles: X takes one, RT fires, Y offers a war, A starts it, RS left gives the blaster away. `-- --only=bowling,rack` runs a part. |
| `tests/pad_reach.gd` (20 s) | The gestures, the blaster on pad 1, labels and the key list, the escape hint twin, the karaoke release, a card's A not moving the body, and **RB reaches every click region** of every Computer app (tech, owner, sales, service; sub-views: an open mail, a ticket, the close question, the RMM tree / machine / session / tabs, a lesson, a Lynk conversation, forum and IRC views, the start menu) and every phone screen on both skins: 68 screens, about 500 regions. |
| `tests/deck_display.gd` | `Game.fit` on 1280 x 800, `pick_format`, `start_display` (screen, argument, saved choice), the 5 px glyph floor, focus loss / app pause in a room, over the Computer, on the title, the switch, the suspend gap. |
| `tests/layout_audit.gd` | `deck` is in its format list; a block for the SETTINGS rows (keyboard and pad footer). |
| `tests/frame_time.gd` | The measurement of section 6 (not in the default run: its header says "renderer"). |
| `tests/title_menu.gd` | Updated for the seventh settings row. |

How the pad is driven: `InputEventJoypadButton` / `InputEventJoypadMotion` through `Input.parse_input_event` reach
every handler used here headless (`_input`, `_unhandled_input` and polled actions). The tests read game state to
decide what to press (which region is under the cursor, where the seat is, the escape room's code) but never call a
handler or send a key or mouse event. Cards ignore input for 0.45 s of real time: `_answer_cards` waits it out.

## 3. The 16:10 format (`Game`)

- `FORMATS.deck` = 320 x 200, zoom 1, `cam_y` 50, scale 4, `follow` true; in `ORDER` after `h`.
- `fit(screen, name)` -> `{scale, size, bars, fill}`; `pick_format(screen)` (16:10 within 0.02 -> `deck`, else
  `wide`); `on_deck(screen)` (env `SteamDeck=1` or exactly 1280 x 800 -> full screen); `dev_run()` (a `-s` script,
  `--write-movie`, `--resolution`, headless or `MSPSIM_TEST=1`: the screen is not asked, so no existing test
  changes with the monitor it runs on); `start_display(screen, forced)` (deferred from `_ready`); `load_display()` /
  `save_display()` (`display/format`, `display/focus_pause` in `Difficulty.settings_path`); `auto_format`.
- `cycle_format()` saves the choice (outside test runs), so SHAPE / F9 override the screen from then on.
- `set_format` only resizes a windowed window (a full-screen one keeps its size).

## 4. Focus and suspend (`Game`)

`focus_pause` (setting, default on), `focus_force` (tests), `focus_lost`, `focus_out()`, `focus_in()`,
`gap_check(now_ms)`, `GAP_MS` 3000, `set_focus_pause(on)`. See `docs/steam-deck.md` section 8. Pause menu:
settings rows are BACK, CONTROLS, SHAPE, SOUND, DAY LENGTH, **UNFOCUSED: PAUSE / RUN**, CAREER (panel 112 px).
`PauseMenu` also snapshots again on QUIT TO TITLE, so the resume point carries a DAY LENGTH or TICKET PACE changed in
that same visit to the menu (found by the walkthrough: it was lost before).

**For anybody who drives a real window from a script or a tool** (the Godot MCP's `run_project`, a recording): a
normal run now pauses when its window is not the focused one, and starts in `deck` on a 16:10 monitor. Set the
environment variable `MSPSIM_TEST=1` (it makes `Game.dev_run()` true: no focus pause, no screen pick, the test
settings file), or switch UNFOCUSED to RUN. `-s` scripts, `--write-movie`, `--resolution` and headless runs are
already exempt.

## 5. Export

`godot/export_presets.cfg`: `Linux (Steam Deck)` filled in, `Windows Desktop` added (Proton fallback). Export
templates are not installed on this PC; the export command stops with "No export template found". Nothing downloaded.

## 6. Frame time

`tests/frame_time.gd`, numbers and reading in `docs/steam-deck.md` section 7. One code change came out of it:
`Computer.DASH_REDRAW` (the metrics board repaints 30 times a second instead of every frame). The real cost centre is
`PixelFont.draw` (one `draw_rect` per lit pixel); not changed here.

Two things to know when measuring: `Performance.TIME_PROCESS` is the **slowest** process step of the last second (not
the last frame), and a headless run sleeps 6.9 ms between frames, so only a windowed run with vsync off gives real
frame times.

## Decisions made

1. **Right stick flicks, not a radial menu**, for dance / follow / give / mute: four free directions, no new screen,
   and the co-op copy of the action table gets them for free. Mute stays reachable in SETTINGS too.
2. **A focus cycle (RB / LB) plus a free cursor (right stick)** rather than per-app focus code: it reaches every
   button by construction, including ones added later, and `tests/pad_reach.gd` checks exactly that.
3. **BACK leaves** the three games where B is a game button, instead of moving their B.
4. **The body ignores input while a card is up** for keyboard and pad alike (not pad only): one rule, and the
   keyboard's Up-arrow jump behind a card was the same bug.
5. **A new format, not letterboxed `h`**: `deck` cost one table row because every screen lays out from the viewport
   size, and it uses the whole panel.
6. **Auto-pick only outside test runs**, and `wide` stays the default on anything that is not 16:10 (a 16:9
   desktop is unchanged; a docked Deck on a 16:9 screen starts in `wide` and is one SHAPE press from `h`).
7. **Focus loss opens the real pause menu** in a room (so the resume point is written and you come back to PAUSED),
   and only holds the tree where there is no player. It does not resume by itself.
8. **A frame gap of 3 s is a suspend.** Checked on `process_frame`, the only place that runs before the frame's
   `_process` calls. A window dragged for 3 s on Windows would also pause; that seemed fine.
9. The switch for the old behaviour is on the **title's SETTINGS** page only (the in-game menu is full in `wide`).
10. Tests may read state to choose a button, never to change it.

## Left open

- Sprite glyphs (another agent), key names inside tutorial sentences, card labels and mini-game captions.
- The cookout and paintball hint lines do not say how to leave (BACK on a pad, Esc on a keyboard).
- A docked Deck on a 16:9 monitor should probably start in `h`.
- `PixelFont.draw` speed-up if the Computer stutters on hardware.
- Everything in `docs/steam-deck.md` section 9.

## Art I would want

None was needed. Pad glyph sprites are the other agent's.
