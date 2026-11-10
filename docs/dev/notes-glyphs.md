# Build notes: glyphs everywhere (agent `glyphs`, roadmap R42 item 1, Nov 2026)

Valve's Deck Verified checklist and Microsoft's handheld guidance both ask that on-screen prompts match the active
input and that no keyboard or mouse glyph shows while a controller is in use. Builds on `notes-controls.md` (R34 hint
routing) and `notes-deck.md` (pad-only play). No pad and no Deck were available: everything here is proven headless.

## 1. The scanner: `tests/pad_prompts.gd`

- `extends "res://tests/layout_audit.gd"` and shares its walker. `layout_audit.gd` got three hooks for that and
  nothing else changed in it: `force_pad` (-1 as the walker says, 0 / 1 set `Controls.pad_active` in every `_begin()`),
  `_texts(tag, recs)` (called by `_end()` with what one screen drew) and `_walk(formats)` (the loop that was inside `_run()`).
- It walks the layout audit's screens **plus `_extra_phase()`**: the tutorial lines and Dan's ride-along as the HUD
  prints them, a coworker's talk card, the pause menu with its three key pages and the remap page, the Computer's
  PROFILE / NERDS (forum, IRC) / METRICS / shop, the phone's keypad and contacts, the printer game step by step, the
  year-end review, and every outing as a page (intro, the room's intro text, play) and in its room (caption and hint
  bar). About 220 screens per format, in `wide`, `h`, `deck` and `v`.
- Three passes:
  1. **keyboard** (`force_pad = 0`): every line of `tests/pad_prompts_keyboard.txt` (174 keyboard prompt lines) must
     still be drawn exactly as it was. The scripts as they were before the fixes draw all of them except the six new
     cookout and paintball hint lines of section 4 (checked by running the finished test on the old `godot/scripts`).
     `-- --golden` rewrites the file after a deliberate change.
  2. **pad** (`force_pad = 1`): every drawn text is scanned. Text that leaves the viewport fails here too, so the pad's
     wider tokens are measured in every format.
  3. **live** (`_live()`): on a talk card, the pause menu and an outing page, a pad button, a key and a mouse move
     switch the prompts with no other redraw (the events are ones no screen answers: the pad's guide button, Ctrl,
     a mouse move).
  Before those, `_tokens()` checks `Controls.keys` / `hint` / `world_hint` on a table of strings, with a remapped key
  and a remapped button.
- **What counts as a prompt** (`_compile()`), on text in capitals: a key by name (`ENTER ESC SPACE TAB SHIFT CTRL
  BACKSPACE WASD ARROWS ARROW KEYS PGUP PGDN F1-F12 CLICK MOUSE`), `ANY / MOVE / BOTH / ALL KEYS`, `A KEY`, a letter
  standing alone (`E = NEXT LINE`, `N ASKS A FRIEND`, `Z X`; A and I are words and have their own rows: `A = `, `A / D`,
  `A OR D`, `PRESS A`), a letter in brackets, digit keys (`1 / 2 / 3 = ANSWER`), and a text of one letter (`J`) unless
  the screen is in `SINGLE_OK` (grids and grades). The pad's own tokens are cut out first (`PAD_TOKENS`).
- **Story text is read differently**: a line with a small letter in it (mail, chats, card text) talks about disk space,
  night shifts and users who click, so there only `press P`, `(P)`, `the Enter key` count (`PROSE`).
- **`ALLOW`** (21 rows, each with its reason): content that looks like a key in capitals (`A/R`, `SALON D`, `DISK SPACE`,
  `TICKET SHIFT`, `THE DIAL CLICKS`, `(2 H)`, `ENTER THE CODE` as a verb, the dinner legend's `(N)`, ...). `MUST_FLAG` and
  `MUST_PASS` are the scanner's own self-test.
- `-- --list` prints every offending line with the screen it was first seen on; `-- --only=extra` skips the layout
  audit's screens.
- **In the default suite**: headless, about 30 s (three walks). Its header does not say "renderer" and it saves no PNG,
  so `run_tests.py` picks it up.

### Count before any fix

- **114 offending lines** with the final scanner on the scripts as they were (measured by checking the old
  `godot/scripts` out under the finished test). A line is a drawn line, so a sentence that wraps differently in two
  formats counts twice. By place: outings 44 (intro pages, captions, the karaoke and co-op hint lines), escape room
  intros 15, the pause menu's key list and remap page 20, the tutorial lines 10, the chair race 5, the printer 6, the
  Computer's apps 7, and one each on a talk card, the day report, the title, the career screen, a conference session.
- The first version of the scanner (commit `352464a`, before the room intros, the one-letter rule and the story-text
  rule) counted **77**. Now: **0**.

## 2. Key tokens (`Controls.keys`)

`Controls.hint(text, map)` already rewrote whole key words of a hint line. A sentence needs to say which word is a key,
so `hint()` was extended with tokens in braces rather than a second mechanism:

| Token | Keyboard | Pad |
|---|---|---|
| `{E}` | `E` (the remapped key if `interact` was moved) | `(X)` (the remapped button) |
| `{ENTER}` `{ESC}` `{SPACE}` `{SHIFT}` `{Z}` `{X}` `{ARROWS}` `{TAB}` | the word (or the menu alias key) | `(A)` `(B)` `(A)` `(B)` `(A)` `(B)` `STICK` `(RB)` (`HINT_PAD`) |
| `{ESC:pause}` | `ESC` | `(START)`: the label of the action, menu role or `move` after the colon |
| `{PRESS A OR D\|PUSH THE STICK}` | the text before the bar | the text after it |
| `{FOCUS (F)\|}` style | `FOCUS (F)` | nothing (the letter keys of the Computer's apps are on the pad's hotkey strip) |

- A bare `{LETTER}` looks in the screen's `map`, then `TOKEN_ACTIONS` (E interact, P phone, Q wave, F drink, N nudge,
  C follow, M mute, V offer_war, G give_item), then the menu words of `hint()`.
- Braces that are none of these stay as they are: the story's own `{me}`, `{c}`, `{closed}` (lower case), `{0}`.
  The action after a colon is matched in any case, because a card label is upper-cased as a whole (`Cards.ask`).
- `keys(text, map := {})` resolves only the tokens. `hint()` resolves them in the same pass as its words, and a token's
  answer is not read again as words. With the default keys on a keyboard both return the text with the braces
  removed, so the keyboard's output is what it was.
- **Where they are resolved (the text layer, at draw time)**: `PixelFont.draw` (anything that reaches the font),
  `PixelFont.keys(text)` (static, finds the autoload by path), `UiStyle.wrap_text` and every script's own `_wrap`
  (build_panel, cards, charselect, computer, conference, day_report, phone, printer_game, review) before the lines are
  cut, `_clip` of the computer and the phone, `Goals._fit` and the HUD's banner body before a text is cut short (a cut
  token would show its braces).
- New in `Controls`: `keys`, `_token`, `pad_label(action)` (what a pad has for an action or role, `""` for none;
  `label()` uses it), `label("move")` (`ARROWS` / `STICK`), `HELP_PAD` (the key list's rows that read differently on a
  pad, written with tokens), `TOKEN_ACTIONS`, `set_pad_active(pad)`, signal `device_changed(pad)`, `MOUSE_FLIP` (24 px).
- **Patchable text**: `story/strings.txt` carries the same tokens (45 lines changed by the same replacements, then
  `--sync --doc`; `--check` reports no problems). `story/README.md` has a paragraph for editors. The checker's
  "changed placeholders" rule protects them like `%s`.

## 3. What was routed

- **Sentences with tokens**: every outing's page blurb, room intro and caption (`PRESS {E} TO STEP UP`, the escape
  themes' `({E})` and `{N} ASKS A FRIEND`, the cookout's `{ARROWS} PICK A PATTY, {E} FLIPS IT ...`, the chair race's
  `{Z} AND {X} IN TURN`, paintball's `{Z} FIRES` / `HOLD {SHIFT} TO DUCK`, dinner's `(UP / DOWN, {ENTER})`), the
  grill's flare-up message, the printer's help lines for all eight models (`{SPACE} WHEN THE MARKER ...`,
  `{P:pray}: PRAY TO ...`, `{A D A D A D|(LB) (RB) (LB) (RB)}`, the test page's `{1 / 2 / 3|UP DOWN (A)}`), the
  tutorial lines (`hints.gd`), `LEAVE ({ESC})` on talk cards, the nerf toast, the Quick Play toasts
  (`{ESC:pause} FOR THE MENU`), Morgan's first mail (`({P})`), Dispatch's first text (`Press {P}`), the on-site arrival
  line (`press {E} on it`), the forum's reply line.
- **Hint lines that were drawn raw**: the conference session (`E = NEXT LINE`), the HUD's blaster lines
  (`RELEASE Z TO FIRE`, `Z FIRE ... G AWAY`; narrower on a pad in the tall format), the title's `SOUND ON  M`, the
  toolbox's `SHIFT F10` note, the karaoke line (`{ARROW KEYS:move} = HIT NOTES`), the co-op chair lines.
- **The Computer's letter keys**: on a pad the letters are on the hotkey strip (Y steps, X presses), so `FOCUS (F)`,
  `1:1 (O)`, `HIRE (H)`, the dispatch board's `A=AUTO  C=CAPACITY` and the CRM's `C CALL  V VISIT ...` line drop the
  letters while a pad is active. `WRITE A DRAFT (ENTER)` becomes `(A)`.
- **The pause menu**: the key list has a pad text for every row (`HELP_PAD`: `STICK`, `HOLD (B)`, `(RB), (LB)`,
  `(START)`, `(LT) + STICK (SEATED)`, `TAP (RT)`, `PAUSE MENU` for the career screen ...). The remap page says REMAP
  BUTTONS / PRESS A BUTTON / PUT ALL BUTTONS BACK on a pad and shows only what the pad has for each row (a glyph, `RS
  UP`, or `-`). **Y opens the remap page from the key list on a pad** (it was the R key only, so a pad could not reach
  it); the footer says so.
- **The career screen**: Y opens the collection on a pad (it was the C key only); the footer says so.
- **The chair race strip**: the two key caps `Z` `X` are the A and B glyphs on a pad, the one to press bright.
- **Outing intro page in a room**: RB looks at the room and comes back (`TAB = LOOK` was shown as `(RB)` on a pad but
  only the Tab key did it).
- `UiStyle.hint_bar` draws through `PadGlyphs` now, like `footer`, so the room hint bars show sprites.

## 4. The cookout and paintball say how to leave

- Page footers and room hint bars: `E = FLIP  SPACE = SERVE  SHIFT = COOL  ESC = LEAVE`,
  `ARROWS = PICK  E = FLIP  SPACE = SERVE  ESC = LEAVE`, `L R RUN  UP DN LANE  Z FIRE  SHIFT DUCK  ESC LEAVE`.
  On a pad ESC is the BACK button there (B is a game button: `Outings._hint_map`, as before).
- Those are too long for the 180 px format, so `Outings.hint()` swaps them for `NARROW_KEYS` when the viewport is
  under 260 px wide: `E FLIP  SPACE SERVE  SHIFT COOL  ESC OUT`, `ARROWS PICK  E FLIP  SPACE SERVE  ESC OUT`,
  `ARROWS MOVE  Z FIRE  SHIFT DUCK  ESC OUT`.

## 5. The switch is live

- `Controls._note_device` is connected to the root window's `window_input` signal. Before, it ran from
  `Controls._input`, which comes **after** every screen's `_input` (input goes to the last nodes first, and Controls is
  the first autoload) and not at all while the tree is paused: a card, an outing page or the pause menu swallowed the
  press and the prompts never changed under them. `tests/pad_prompts.gd` step 3 failed on all three before this.
- A pad button or a stick pushed past half way makes the pad active; a key press or a mouse button hands it back; so
  does **mouse travel of 24 px in one movement** (a pause of 0.4 s starts the count again, so a bumped desk or a
  trackpad's drift does not flip the hints).
- `set_pad_active()` emits `device_changed` and calls `queue_redraw` on every node of the tree, so a screen that only
  repaints on its own input shows the other set at once.
- With the touch overlay up, mouse events are ignored for this (a touch arrives as a mouse event too, and the
  overlay's buttons carry pad letters).
- `PixelFont.audit` stamps each record with `Engine.get_process_frames()` instead of `get_frames_drawn()`, which stays
  0 without a renderer: the audit's "only the newest redraw of a canvas counts" rule now works headless too (the
  layout audit's overlap warnings went from 222 to 6; its failures stay 0).

## Decisions made

1. **Tokens in braces inside `hint()`**, not a second mechanism, and not a table of whole pad sentences: one string per
   line, the keyboard's text unchanged, a remap followed. The bar form (`{keyboard|pad}`) is for the few sentences
   whose pad wording differs in more than the key.
2. **Text form `(A)` inside sentences, sprites in hint lines.** A caption or a card label is wrapped by character
   count; a sprite in the middle of a wrapped line would need every wrap helper to measure glyphs.
3. **LEFT RIGHT UP DOWN stay words on a pad** (the stick and the D-pad have directions; `HINT_PAD` already kept them).
   `ARROWS` and `ARROW KEYS` do become `STICK`. The scanner does not flag the direction words.
4. **The Computer's letter keys are hidden on a pad** rather than relabelled: the hotkey strip already offers them.
5. **A lone X is not flagged** (the close box of every Computer window), and a text of one letter is a prompt except
   on the grid and grade screens in `SINGLE_OK`.
6. **Mouse movement needs 24 px in one go** to take the prompts back; a click does it at once.
7. The keyboard golden holds **prompt lines only** (not whole screens), so another agent's content change does not
   break it; a changed or removed keyboard prompt does.
8. `tests/pad_reach.gd`, `coop_chair_duel.gd` and `escape_themes.gd` were updated: the key list's pad rows are worded
   now (`CAREER SCREEN` says `PAUSE MENU`, not `J (FREE PLAY)`), and two tests read a string that now carries a token.

## Not done / limits

- **Screens the scanner does not open** were checked by a search of every string literal in `godot/scripts` with the
  same patterns, not by drawing them: the nested views of the Computer's apps (a ticket, an RMM session, a lesson, the
  client-site apps, IRC's lists), client-site screens, the printer's other seven models, event cards. A prompt built
  from pieces at run time in one of those could have been missed.
- The glyph atlas is the Xbox set. No Deck-specific art (View / Menu, trackpads, back grips), no PlayStation or
  Switch layouts: that is art, and this batch had none.
- The HUD's `world_hint` still rewrites the bare letters E P Q F Z in any toast on a pad, as before (a toast that
  says "PLAN F" would be changed). New text should use tokens.
- Co-op: the second player's hint lines were not walked by the scanner.
- Nothing was seen on a real pad or a Deck.

## Tests

- New: `pad_prompts` (default suite, about 30 s headless; `tests/pad_prompts_keyboard.txt` is its golden file).
- Updated: `layout_audit` (hooks only), `pad_reach`, `coop_chair_duel`, `escape_themes`.
- Run and green after the change: `pad_prompts`, `layout_audit`, `click_harness`, `controls`, `controls_pad`,
  `pad_glyphs`, `pad_only`, `pad_only_games`, `pad_reach`, `raw_keys`, `remap`, `title_menu`, `tap_targets`,
  `deck_display`, `strings`, `canon_text`, the outing, printer, co-op, talk, dispatch, knowledge, crm, career and
  conference tests (list in the hand-over report).

## Art I would want

Deck glyphs for View and Menu (the atlas has BACK and START in the Xbox look), a right-stick glyph with a direction
(`RS UP` is text), and a mouse glyph if the keyboard side should ever show `CLICK` as a picture.
