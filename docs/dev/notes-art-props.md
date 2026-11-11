# Art props batch (agent `art-props`, Nov 2026): themed escape props, pad glyphs, dinner guest, duel HUD, card art, mutator icons

All pieces are rows of characters in `tools/make_game_art.lua` (appended: the escape, dinner, card and mutator blocks) and
`tools/make_icons.lua` (the glyph atlas cells 13-24 and the duel HUD), on `tools/piece_rows.lua`. Sources in
`office/pieces/` (`escape_*`, `game_dinner_*`, `ui_card_*`, `ui_mut_*`, `ui_duel_*`, `ui_pad_glyphs`), PNGs under
`godot/assets/props/` and `godot/assets/ui/`. Rebuild: `ROOT = "<checkout>/"; dofile(ROOT .. "tools/make_game_art.lua")` (and
`make_icons.lua`) with `Aseprite.exe -b --script x.lua`; the existing PNGs come out byte-identical. `python tools/art_lint.py`: 0 problems.

## 1. R4 themed escape props (`escape_<theme>_<slot>`, `SetDressing.escape_art / escape_swap`)

- Slots keep the study's content sizes so the swap is texture only: safe 28x28, trunk 32x20, globe 18x28 (with the outline).
  server: locked rack cabinet (padlock on the hasp), crate of drives, tower UPS. detective: filing cabinet with a lock, steamer
  trunk, brass desk globe. lab: beige tower with a key lock, box of floppies, CRT on a cart.
- `SetDressing.dress` now also runs in `escape_room` (a `SetDressing` node with `escape_stage` set); `refresh()` (every 0.5 s and at
  start) sets the textures of `Actors/globe_4`, `safe_box_5`, `trunk_6` from `Outings.theme_id()` while `Outings.game == "escape"`
  (else the study's). A missing texture falls back to the study's.
- Test: `tests/escape_themes.gd` (nine textures at the study sizes, the unknown theme falls back, the real room shows the detective's
  three pieces and the scripted solver still gets out).

## 2. R42 pad glyphs

- Atlas is 24 cells of 11x7 now (264x7). Cells 1-12 are byte-identical. New names (`PadGlyphs.NAMES`): `VIEW MENU RS_UP RS_DOWN RS_LEFT
  RS_RIGHT L3 R3 UP DOWN LEFT RIGHT` (the last four are the D-pad with the one arm red). Tokens: `(VIEW) (MENU) (L3) (R3) (UP) (DOWN) (LEFT)
  (RIGHT)` and the words `RS UP / RS DOWN / RS LEFT / RS RIGHT` (what `Controls.pad_label` returns for the right stick). `(L3)` and `(R3)`
  used to draw the left-stick glyph and the four directions the D-pad plus: they have their own cells now.
- Deck: `PadGlyphs.deck()` (the `SteamDeck=1` environment variable Steam sets, or a joypad named "steam deck"; `deck_force` for tests).
  On a Deck `(BACK)` / `(START)` draw the View / Menu glyphs and `Controls.button_name` says VIEW / MENU (so `Controls.label` and the pause
  menu's remap rows follow). Nothing was seen on a Deck.
- Sentences: `PadGlyphs.draw/width(text, scale, sentence := true)` converts only the bracketed buttons and `RS ...` (a bare `STICK` stays a
  word: prose has USB sticks). The sentence line is cut as text first and the glyph is always narrower than its text token, so no wrap
  helper changed. Used by card bodies and card option labels (`cards.gd`) and the phone banner body (`hud.gd`). The tutorial lines and
  every toast already went through `PadGlyphs.draw` (`_draw_hint`).
- **Left as text**: story text drawn by other screens that call `PixelFont.draw` directly (the Computer's mail and chat bodies, the
  conference talk caption, the printer help lines, the day report and review pages) still show `(A)` as letters; swap the call for
  `PadGlyphs.draw(..., 1, true)` where wanted. A bare `STICK` in a sentence stays a word everywhere.
- Tests: `tests/pad_glyphs.gd` (24 cells, new tokens, whole-word RS UP, sentence mode, the Deck swap), `pad_prompts`, `layout_audit`.

## 3. Dinner guest

- `dinner_setting` 16x7 (fork, plate, knife, glass), `dinner_tent` 7x6 (name tent), `dinner_briefcase` 12x10, and a fourth plate
  `dinner_plate_d` (spinach dip; the second table's second plate, so the four plates have four faces).
- While `Outings.game == "dinner"` and `Outings.dinner_guest()` is not empty (`guest_client`, a sales dinner lead, the toolbox `guest`
  option and the tech campaign's client all fill it) `SetDressing` shows the setting and the tent at the end of the second booth's table
  (the two plates there step aside, x 3 and 16), and a briefcase on the floor beside the booth (x 91, y-sorted as an actor).
- **Not done: a guest NPC.** The cast machinery (`World.chars`, a character row, seats) needs a `client_*` person added to the world for
  one evening; the table pieces tell who is there. Seats 1-4 are taken by the crew and the player, so a seated guest also needs a
  fifth booth seat. The place setting is the marker.
- Test: `tests/game_art.gd` (sizes; no guest = hidden; a guest = shown and the plates move; the guest goes home).

## 4. Co-op chair duel HUD

- `ui_duel_frame` 23x9 (the round timer's well), `ui_duel_tag_p1/p2` 9x7, `ui_duel_pip_p1/p2/off` 5x6. `Outings._hud_fight` draws them
  only for `fight.duel` (the solo fight keeps its rectangles); `_duel_art(id)` is the loader (null = the rectangles).
- The pad's duel hint line was too wide for the 180 px format (the new `chair duel hud strip` screen found it): `NARROW_KEYS` has a short
  form now.
- `layout_audit.gd`: `chair duel intro` and `chair duel hud strip` (every format, the pad pass too).

## 5. R8 event card art

- Ten 34x26 pictures `ui_card_*`: the seasons `holidays tax xp school` and six kinds of deck card. The deck has no `kind` field, so the six
  kinds are the commonest themes by card count: `printer` (toner_late, toner_mixup, home_printer, copier_lease, projector_cart), `phone`
  (5), `food` (5), `power` (heat_wave, cold_snap, power_blip, leaky_ceiling), `security` (5), `backup` (3): `Events.ART_KINDS`.
  Seasonal cards (`Seasons.CARD_SEASON`, and `tax_season` by `TAGS`) get their season's picture. `Events.art_for(id)`.
- `Cards.art_next` is set by the caller just before `Cards.ask` (events.gd `show_draw`, seasons.gd `show_event`), carried through the
  queue as a sixth element, and `Cards.art` is the open card's. `_paint` draws the picture top right when the panel is at least 200 px wide
  (`ART_MIN_W`) and the panel with the narrower text still fits the screen height; otherwise the plain card. The tall format (172 px) goes
  without. A story vignette card has no picture.
- Test: `tests/game_art.gd`; `layout_audit.gd` has `card with picture tax / printer` in every format.

## 6. R9 mutator icons

- Fourteen 12x12 icons `ui_mut_<id>` for every id of `Mutators.MUTATORS`. Drawn on the character select's options page next to the MUT row
  (`Yeartwo.mut_icon()`, dimmed for BAN) where the row pitch is 13 px or more; the compact 11 px layout has no room and goes without.
  **Not wired: the Free Play toolbox's MUTATOR row** (its rows are 8-9 px high) and the morning briefing card; the files are there.

## Decisions made

- Themed props keep the study's sizes; the study is the fallback; the theme is read live so a toolbox change or a draw shows at once.
- Glyph tokens: the Deck swap happens in `parts()` and `Controls.button_name`, not in the atlas (one View cell, no separate Deck set).
- Sentences convert brackets only; a bare STICK is never a glyph there.
- The card picture is skipped, never squeezed, where the card is narrow or the screen short.

## Tests run

`escape_themes escape_herrings game_art pad_glyphs pad_prompts layout_audit pad_reach controls controls_pad remap coop_chair_duel events
seasons canon_text strings click_harness`.
