# Build notes: the remaining code-side items (agent `rest`, Nov 2026)

Rows R42, X13, Q6, C7, R6, R9 and the R34 leftover. Generator and real files edited together with `tools/port_edit.py`.

## 1. R42 glyphs: the last letters

- `PixelFont.draw` hands any line with a `(` to `PadGlyphs` (sentence mode) while a pad is active, so every screen that draws with
  the plain font shows `(A)`, `(RB)` ... as glyphs with no per-screen change (`PixelFont._pad_line`; `glyph_lines` counts them).
  `PadGlyphs.draw(sentence)` draws a bracket-free line as plain text.
- Explicit routes too: the Computer's `_text` / `_tw` (mail and chat bodies, every app), `UiStyle.caption_bar` (talk and outing
  captions), the printer game's `_txt`, the day report's `_t`, the review's rows.
- `tests/pad_prompts.gd` gained `_more_phase()`: every mail of the inbox, a ticket, an RMM endpoint and session, a lesson, the
  IRC lists, a Lync chat, the PCs of every client-site type (5 views each), onsite texts, the other printer models phase by phase,
  every event and seasonal card, every mutator briefing, a day report note, and every outing again with player 2 joined (co-op
  hint lines). A drawn text that still spells a button in brackets fails ("button as letters"); the run also demands that
  screens naming a button exist and that the font produced glyphs. Result: 3672 screens, 0 offending lines, 0 buttons as letters.
- It found two co-op hint lines 3 px too wide for the tall format (`NARROW_KEYS` got short forms) and a tray label
  (`CARBON FORMS` cut to 8 chars, in `ALLOW`).

## 2. X13 the seated use press

- `Player.seat_target()` decides the seated press and `Player.seat_hint()` is what the HUD line shows: the desk phone during its
  first `FRESH_RINGS` (2) rings of `RING_GAP` (3.5 s) -> `E ANSWER THE PHONE`; else somebody with news -> `E JOHN HAS NEWS`; else
  the Computer -> `E COMPUTER`; a phone that has rung longer only when nothing else can be pressed. `Fx.rung` counts the ring.
  The press and the line read the same function, so they cannot disagree. On a pad the line draws the pad's button.
- Test `tests/desk_use.gd` (both orders: press in the first rings and press after two rings, the edge itself, John with a fresh and
  an old ring, pad glyph, no line standing or with a screen open). Manual updated (`02-controls.md`, `06-after-work.md`).

## 3. Q6 owner hard

See the table at the end of this file (filled in after the runs). `Difficulty.TABLE` got `owner.gain` / `owner.loss`; easy and
normal are the `rep.*` values to the digit, so those tiers' bot lines are unchanged; `Campaign._tier_rep` reads them for the owner
mode only. `tests/owner_hard.gd`.

## 4. C7 tech 1:1 cards

- 14 new first-draft cards (28 in the shared tech deck, text in `Service.DEFAULT_ONE_ON_ONES.Tech`, patchable; `strings.txt` synced).
  Effect sizes follow the old ones (best +4..6 morale, curt -3..-5). `tests/oto_decks.gd`: 28 cards, and the 20-day careful run has
  0 check-ins among its 27 tech 1:1s (12 were asked for; 14 written so a lucky run still has margin).

## 5. R6 the dinner guest

- `Outings._guest_sync()` (every room frame and on close): with `dinner_guest()` set, the person is an NPC (role `guest`, no talk zone,
  not in `World.chars`) seated in the second booth's outer seat `Seat4`, where the place setting stands. The crew member who had it
  moves to the free stool `Seat8` (the party is the same size: nobody stays home, so no who-comes-along change was needed). The face
  is the owner of that client's site (`Onsite.CAST_AT ... office`), a prospect gets a `client_*` face from `GUEST_POOL` by name hash.
  Seated poses and the seat life (`sit`, `sitlook`, `sitnod`) come from the NPC. The guest leaves with the dinner.
- Test `tests/dinner_guest.gd` (no guest = nothing changes, guest seated and moves, Dan at the bar, party unchanged, guest gone
  next dinner, prospect faces, every pool and site sheet exists).

## 6. R9 mutator icons

- `Mutators.icon(id)` (cached: an unheld texture is freed before the frame draws). The Free Play toolbox MUTATOR row draws the chosen
  mutator's icon after the label (12 px in the 9 px row: overhangs, text untouched); the morning briefing card draws it on the right
  end of the title bar (`Cards.art_next = "mut_<id>"`, `Cards.icon_tex()`). `tests/mut_icons.gd` (all 14 ids x 4 formats: on screen,
  covers no text, row still 9 px); `layout_audit.gd` has `briefing card with icon` and `toolbox mutator row`.

## 7. X13 test hygiene

- `Phone._init` and `Controls._init` redirect `save_path` / `binds_path` to `user://test_<pid>_phone.cfg` / `_controls.cfg` in a headless or
  `MSPSIM_TEST=1` run (a path a test already chose is kept), like Difficulty and Campaign. `tests/test_paths.gd` checks both.
- `tools/user_dir_check.py` (not in the default suite): snapshots the real `user://` player files (names, sizes, mtimes) before and
  after ten varied tests (phone, controls, remap, pause, title, campaign, sound, career, creator) and again runs them with
  `APPDATA` pointed at an empty folder, where every file written must be named `test_*`. Result: real directory unchanged (1437
  files, no new, no gone, no mtime change); fresh directory: only `test_*` files.

## 8. R34 co-op pace and share

See the table below.

## Decisions made

- The seated press: no settings row; the rule from the assignment, and the hint line is the proof it is what happens.
- Dinner guest: the booth's displaced crew member sits at the bar rather than a fifth booth seat (the booth has none to spare).
- Hard owner: its own dial pair rather than touching `rep.*` (sales and service hard stay as measured).

## Tables

### Q6: owner hard (`bot_run.gd -- owner hard careful,lazy seeds=5 ts=4`)
Change: `owner.gain` hard 0.5 and `owner.loss` hard 1.8 (new keys; before the owner used `rep.gain` 0.8 / `rep.loss` 1.3). `owner.cost` stays 1.03.
Easy and normal columns of the new keys equal the `rep.*` ones, so those tiers are unchanged: owner normal careful seeds 1-2 after the
change end at 98 / $857,056 and 98 / $691,030, byte-identical to the X13 table (`notes-x13-owner.md`).

| | Seed 1 | Seed 2 | Seed 3 | Seed 4 | Seed 5 | Cell |
|---|---|---|---|---|---|---|
| Careful, before (X13) | 89 / $723k | 96 / $822k | 93 / $634k | 87 / $785k | 83 / $220k | 3 good 2 mid, rep 89.6, $637k |
| Careful, after | 79 / $645k | 85 / $730k | 81 / $555k | 77 / $701k | 75 / $200k | 3 good 2 mid, rep 79.4, $566k (75 % of normal's $759k), nobody fired or bankrupt |
| Lazy, after | 42 / $29k | fired wk 10 | fired wk 15 | fired wk 15 | 63 / $331k | 1 good 4 bad, rep 21, fired 3 of 5 |

Careful rep 79.4 (target 70-80), value 75 % of normal (target 70-80 %). `balance_baseline.json` has no owner cells (the smoke test
does not play the owner), so it was not rewritten.

### R34 co-op pace (`bot_run.gd -- tech normal careful [coop] seeds=5 ts=20`)
| | Rep per seed | Cell rep | Tickets closed | SLA missed | Score |
|---|---|---|---|---|---|
| Solo | 97 97 98 95 95 | 96.4 | 171 165 171 166 170 (mean 169) | 1 0 0 0 1 (0.4) | 1789 |
| With player 2 (pace 1.5, 25 % share) | 97 96 98 98 97 | 97.2 | 183 180 182 185 181 (mean 182) | 0 0 0 0 0 | 1929 |

Two bots close 8 % more tickets, miss none, and end one point higher. That is not clearly easier or harder (the day cap bounds the
extra arrivals), so **1.5 and the 25 % share are unchanged**.
