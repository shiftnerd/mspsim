# Build notes: controls, portability, character select, mutators, phone camera (agent `controls`, Nov 2026)

Rows: R14 portability (1b, 3, 4, 5, 6, 7), R34 hint leftover, R1 tier step, R9 mutators, R37 phone camera.
Steam Deck is the pad target (owner decision during this batch): everything converted here is reachable with a pad alone.

## R14 (1b) no raw keys outside `controls.gd`

- **Rule, enforced by `tests/raw_keys.gd`**: no script but `scripts/controls.gd` may contain `KEY_*`, `is_key_pressed`,
  `.keycode`, `.physical_keycode` or `.unicode`. Allow list: `outings.gd` only, because it uses `KEY_*` constants as the
  vocabulary of its game logic (`Outings._event_key` turns keys, pad buttons and stick pushes into them); its two raw
  letter reads (`KEY_N`, `KEY_O`) are gone and the test fails if they come back.
- **New `Controls` helpers** (keys by name, text entry, modifiers):
  `word(event_or_code)` ("a".."z", "0".."9", "kp0".."kp9", "f1".."f12", or `WORDS`: tab left right up down enter esc
  backspace space pgup pgdn `[` `]` `` ` `` shift), `digit(event, keypad := false)`, `fkey(event)`, `typed(event)`
  (the character for text entry), `shift(event)`, `ctrl(event)`, `alt(event)`, `shift_held()`, `physical(event)`
  (what a remap stores), `tap(action)` (press an action from code: a menu row or the touch overlay).
- **New actions** (`Controls.ACTIONS`, key / pad): `nudge` N / Y (escape room), `outing` O / - (pad: Free Play menu),
  `mutator` backtick / - (pad: Free Play menu), `preset` P / Y (character select build step), `pray` P / Y,
  `shake_left` A / LB, `shake_right` D / RB (printer), `hot_next` - / Y, `hot_go` - / X (computer hotkey strip),
  `roll` - / left trigger. `character_next` (R3) now works for player 1 outside co-op too (the 1-7 keys' pad twin).
- **Converted, keyboard unchanged**: computer (dispatch, knowledge, nerds page keys, crm), `crm.gd` / `quote_builder.gd`
  (`key(cp, name: String)` now takes a key name), cards 1-4, character select (X T M B, P, F9, Q / E, name typing),
  printer (A / D, 1-3, P), player (1-7, Shift), mutators (backtick), outings (O, N), phone keypad, toolbox, world F10,
  stage F-keys, title / career F9, pause menu (remap capture, arrows). One keyboard gain on purpose: the dispatch
  board's `O` (1:1) key was advertised but never mapped in `computer.gd`; it works now.
- **Computer letter hotkeys on a pad**: `Computer.hot_keys()` asks the open app (`Crm.hot_keys()`,
  `Dispatch.hot_keys()`, `Knowledge.hot_keys()`) for `[key name, label]`; pad **Y** steps (`hot_i`), **X** presses
  (`hot_press(name)`), and `hot_text()` is drawn above the taskbar while `Controls.pad_active`.
- **Printer test page**: Up / Down mark an answer (`ans_sel`), confirm gives it; confirm alone still does nothing, so
  keyboard play is as before.
- **Pause menu**: takes the left stick now (it only took keys and pad buttons), and in Free Play has a
  **FREE PLAY MENU** row (`Toolbox.open_free_menu()`, a card: MUTATOR: x (steps and re-opens), TOOLBOX, TEAM OUTING,
  NEXT PERSON, CLOSE). Panel height 76 + 36 = 112 px, still inside the 128 px `wide` format.

## R14 (3) Roll and next target

- `roll` action (left trigger): `Player` rolls the seated chair when `run` (Shift / B, as before) **or** `roll` is held
  with a direction. Next target was already `pick_next` (Tab / RB). The touch overlay has ROLL and NEXT buttons.
  Input binding only; the chair push itself belongs to another agent.

## R14 (6) seed picker (`Toolbox`, seed page)

- Six hex wheels instead of a text field. `seed_buf` is always six hex digits (starts on the seed in force),
  `seed_col` the wheel in focus, `seed_focus` 0 wheels / 1 RANDOM / 2 TODAY / 3 OK.
  Up / Down turn (`seed_turn(step)`), Left / Right pick a wheel and walk on to the buttons, Tab / RB (`pick_next`) and
  Shift+Tab / LB step the focus, confirm applies or presses, back closes. Mouse: top / bottom half of a wheel, the
  buttons. Keyboard extras kept: typing 0-9 A-F (`type_char`), Backspace steps back, Ctrl+V pastes a code or a word
  (`Difficulty.parse_seed`, so a word still becomes a seed). `is_typing()` is always false now.
- Lost on purpose: typing an arbitrary word as the seed (paste still does it).

## R14 (5) tap targets in `v`

- `tests/tap_targets.gd` (`-- --measure` prints every target): title menu and submenu, a card, the phone (home, mail,
  tickets, texts, phone, keypad, settings, camera, both skins) and the day report in `v`: every target >= 19 px high,
  no two overlapping (a 2 px lap is tolerated: the home icons' label rows did that before).
- Measured before: title rows 9 px, card answers 10 px, phone nav bar / top back / settings rows 18 px, the iOS home
  button 9 px, day report button below 19 in some layouts.
- Changes: title row pitch up to 20 px when the format is taller than wide (text centred in the row);
  card answers at least 19 px high in a tall format; `Phone._region(id, r, up := false)` grows a target under
  `TAP_H` (19) to it on the big phone (`_sc` 2), downwards or upwards; the iOS home button's target is 25 x 19;
  the day report button's hit rect grows to 19+ (drawing unchanged). `wide` and `h` are unchanged.

## R14 (4) touch overlay (`scripts/touch_overlay.gd`)

- Made only when `Controls.touch_on()` (`DisplayServer.is_touchscreen_available()`, or `Controls.touch_override`
  1 / 0 for tests; -1 = ask), by `Controls.touch_refresh()`; `Controls.touch` is the node or null. It is kept as the
  LAST child of the root so it sees a touch before any screen, and it swallows the emulated mouse events of a touch
  that lands on one of its controls.
- It sends pad events for device 0 (so every pad path works by touch): stick = left stick axes (sent when an axis
  changes side), `A` = pad A, second button = pad X while walking / pad B while a screen is open (`in_menu()`),
  MENU = Start, NEXT = RB, ROLL (seated only) = left trigger. `buttons()` returns the rects, `stick_center()` /
  `STICK_R` the stick, `control_at(pos)` the control under a point.
- First version: no opacity option, no left-handed layout, no drag-to-move stick origin, not hidden during cutscenes.

## R14 (7) export presets

- `godot/export_presets.cfg` has stubs for Android, iOS and Linux (Steam Deck). The generator check ignores the
  file (it is not generated and not diffed). Package ids, signing and SDK paths are placeholders.
- **Aspect note**: the project uses `stretch/mode = viewport` with `scale_mode = integer`. Formats: `wide` 368 x 128,
  `h` 320 x 180 (16:9), `v` / `vclose` 180 x 320 (9:16).
  Steam Deck 1280 x 800: `h` x4 = 1280 x 720 with 40 px bars top and bottom (the right default there); `wide` x3 =
  1104 x 384, small. Phones in portrait: `v` (1080 x 1920 = x6). Phones in landscape: `h`.
  A port should pick the format from the screen (today it is the saved setting, F9, or the pause menu's SHAPE row).

## R14 skipped

- (2) chair-race pad feel and (8) Switch: need hardware (Switch is dropped in favour of Steam Deck). Not done.

## R34 hints follow the binding

- `Controls.pad_active` (the last press came from a pad; a key or mouse press clears it), `Controls.label(action)`
  (an action or a menu role: the key's name, the extra menu key if one is set, or `(A)` / `(LT)` / `STICK` on a pad),
  `Controls.hint(text, map := {})` (rewrites the key words of a hint line: ENTER ESC UP DOWN LEFT RIGHT Z X SHIFT
  follow the menu roles; on a pad ENTER / SPACE -> `(A)`, ESC -> `(B)`, ARROWS -> STICK, TAB -> `(RB)`; `map` adds a
  screen's own letters as word -> action) and `Controls.world_hint(text)` (walking prompts: E P Q F SPACE SHIFT TAB Z).
  With default keys on a keyboard the text is returned unchanged.
- Routed: the HUD hint (`Hud._draw_hint`), every `UiStyle.footer` / `hint_bar` caller (outings mini-games and pages,
  printer, pause menu and its key list, toolbox, career screen), character select hint lines (`_keys_line`) and its
  `< ESC` chip, the day report, the TV dashboard, the forum footer, the dispatch info line, the computer's hotkey strip.
- Not routed: hints that are part of a card label (`talk.gd` "LEAVE (ESC)"), the tutorial texts in `hints.gd` (the HUD
  routes them through `world_hint`, which covers E / P / TAB words but not every sentence), `Controls.HELP` pages
  (they already use `help_value`).

## R1 the tier step

- `CharSelect.flow()` has a `"tier"` step in a campaign, between the phone (tech) or the character and `"options"`:
  three chips EASY / NORMAL / HARD, NEXT, and the campaign's line from `Difficulty.TIER_NOTES` under them.
  Any direction steps the tier (`pick_tier(index)`), confirm goes on, back goes back; clicks: `tier_pick`, `tier_go`.
- Free Play has no tier step (no notes there); it keeps the LEVEL row.

## R9 mutators

- `cash_mult` hook (`SCHEMA` 0.7 .. 1.3) and `Mutators.cash(amount)`: scales money coming in, never costs. Used by the
  owner's week (`Owner.settle`: the collected fees), the sales week (`SalesCampaign` revenue) and the tech's pay
  (`Campaign`). Neutral (x1) with no mutator.
- Three owner-only mutators with `"year2": true`: `good_quarter` (cash x1.15), `price_war` (cash x0.9, price
  pressure 0.06, a text), `summer_lull` (leads x0.4, invoices a week late). `Mutators.plan_ids(mode)` leaves `year2`
  rows out of the draw unless `Yeartwo.active()`; `ids_for(mode)` still lists them (the Year 2 pick / ban chooser).
- Free Play menu entry: the pause menu's FREE PLAY MENU card (above). The backtick key is the `mutator` action.
- Strings: the `Mutators > MUTATORS` section of `story/strings.txt` was regenerated (`--sync --doc`).

## R37 phone camera (`Phone`)

- `HOME_APPS` gains `"camera"` (index 5, an icon at the right end of the dock on both skins). `cam_view` finder /
  roll / photo, `cam_sel`, `photos` (newest first, `MAX_PHOTOS` 6, saved in `Phone.to_dict()["photos"]`, cleared by
  `reset()`; an old save loads with an empty roll).
- `camera_subject()`: in `network_closet` the patch panel (`tags`: jack -> {text, n, state} from `Net.label`), in a
  client site's closet the rack (flavour: an asset tag), else the nearest coworker or the room. `take_photo()`,
  `panel_photo()`, `panel_line(desk)`.
- **The real use**: `Phone._paint_ticket` puts `panel_line(desk)` on top of a network ("no link") ticket's text:
  `PHOTO: PORT 3 IS TAGGED 3 DAN (PRINTED)` or `(TAPE)`, with `, OLD PHOTO` when the photo is from another day (the
  tags are re-rolled daily). Printed = one of Dan's, always right; tape may have drifted.
- Photos are drawn from their data (`_paint_shot`), not captured from the screen: no renderer needed, saves cleanly.

## Decisions made

1. Letter hotkeys on a pad are a Y / X cycle strip rather than one action per letter (too many letters per app).
2. Outing (O), mutator (backtick), toolbox (Shift+F10) and the 1-7 switch share one pad route: Start, FREE PLAY MENU.
   No free pad button was left for them.
3. The seed picker is hex digit wheels (the seed is 24 bits = six hex digits); word seeds only by paste.
4. The tier step is for campaigns only, and the options page's LEVEL row stays editable as well as showing the choice.
5. The new owner mutators are Year 2 only, so first-year owner runs (and the balance baseline) are dealt as before.
6. The touch overlay's buttons carry pad letters (A, X / B) so they match the hint lines.
7. The camera draws its photos from data instead of grabbing the viewport (headless tests, small saves).
8. Tap targets grow only in the tall format (and on the big phone); `wide` and `h` layouts are untouched.

## Pad-only play on a 1280 x 800 screen: what I found that still blocks or is awkward (for R42)

- **No pad binding at all**: `dance` (X key), `follow` (C), `mute` (M), `give_item` (G), `pose_prev` / `pose_next`
  (`,` `.` in the creator), the debug keys. The Free Play menu could take dance / follow / mute as rows.
- **Shared buttons**: Y is wave, offer war, nudge, preset, pray, hold pose and hot_next depending on the screen; LB is
  drink, pick_prev, page_prev and shake_left. They do not clash on one screen today, but Y in the escape room both
  nudges and waves.
- **Escape room page mode**: `H` (hint) is still a key name inside `Outings._escape_press` with no pad twin (the room
  mode has `nudge`).
- **Computer**: apps are driven by Up / Down / Enter plus on-screen buttons. Single player has no stick cursor
  (the co-op panes do), so buttons with no key (PSA / RMM buttons, the taskbar, Lynk contacts on a narrow screen)
  are not checked here for pad reach; dispatch drag and drop has keys (Enter picks up / drops).
- **Remap page**: a pad can remap its own buttons; putting a KEY on an action needs a keyboard.
- **Format**: the default `wide` (368 x 128) scales x3 to 1104 x 384 on a Deck; `h` fills it. Nothing picks `h`
  automatically.
- **Hints**: card labels with a key in them and some tutorial sentences still name keys.
- `tests/layout_audit.gd`: in the `h` pass the title phase's scene is gone before the character select opens (a
  save from the earlier pass is continued), so the select pages are audited in `wide` and `v` only. It warns instead
  of crashing now; the cause predates this batch (the R40 home menu).

## Tests

`raw_keys`, `controls_pad`, `tap_targets`, `mutators_r9`, `phone_camera` (new); `toolbox`, `charselect`, `creator`,
`outfit`, `layout_audit` and the shot tests `build_shots`, `charselect_shots` (updated for the tier step, the wheels,
the pause row, the camera and the touch overlay).

## Art I would want

A camera icon and a shutter button for the phone, a proper virtual stick and round touch buttons, pad glyph sprites
for the hint lines (they are `(A)` text today).
