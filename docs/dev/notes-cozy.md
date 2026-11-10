# Build notes: cozy Easy, the resume point, the goal chip, collections, seasons (roadmap R16 and R8)

Batch of Nov 2026 (agent `cozy`). Everything here is a tested first version. Player-facing wording is a first draft.

## 1. Resume point step 5 (`Campaign.snapshot`, `scripts/resume.gd`, test `tests/resume5.gd`)

- **Every campaign has a mid-day / mid-week point now** (tech, owner, service, sales). `Campaign.can_snapshot()` asks
  `is_selectable(mode)` instead of `mode == "tech"`. The title's CONTINUE row of a slot already showed
  `CONTINUE - WEEK 3  14:00` for any mode; `Title._start` handles `owner_resume`, `service_resume`, `sales_resume`.
- **A Playbook job in progress** no longer blocks the snapshot (the gate still refuses overtime, so the email24 night waits).
- **An onsite visit**: standing at the client site with nothing open is a safe moment (`_something_open` refuses only
  the drive, `Onsite.busy and not Onsite.active`). The hourly trigger does not run on site (the office clock is frozen there);
  the pause menu, app pause, focus-out and close do.
- **How**: `Resume.DEEP` lists singletons saved whole: `Playbook, Onsite, Owner, Partner, Service, ServiceArc, SalesCampaign,
  Crew, Projects`. `Resume.deep_dict()` takes every script variable that is plain data (`Resume.plain()`: no objects,
  callables or signals anywhere inside) and whose name is not all capitals (the patchable tables); `apply_deep()` sets them
  back after the normal `from_dict` loads, so the transient fields those do not carry (the week's work per client, queues
  of cards waiting for tomorrow, the visit's ticket, job, findings) come back exactly. A new variable in one of those
  singletons is saved without any edit, as long as it is plain data. Section `deep/state` of the resume file.
- **Resumed on site**: `apply_deep` freezes the office again (`Msp.enabled = false`, `World.time_scale = 0`) and sets
  `Onsite._prev_msp = true`, `_prev_scale = 1.0`, so the drive home starts it. The run opens in the site room (the player
  section already held the room).
- **Position**: the player section has `x`; `Resume.apply_player` hands it over in `Game.vars["resume_x"]` and
  `Stage._seat_player` puts a standing player there (a seated one gets the chair as before).
- `Resume.VERSION` is 2: a version 1 file is refused and Continue falls back to the morning (`tests/resume.gd` reads the
  constant now).
- **Still lost on resume**: cast mid-walk positions and conversations, RMM jobs in progress, open cards and screens,
  mini-games, nerf wars, the drive to or from a site, an outing.

## 2. The cozy design review

### Today's goal chip and next-up list (`scripts/goals.gd`, drawn by `hud.gd`; test `tests/goal_chip.gd`, layout audit blocks `hud goal chip tech / owner`)
- `Goals.goal()`: one line per mode. Tech: the Playbook job, a visit, the first ticket on day 1, `CLEAR THE QUEUE: n OPEN`,
  or `QUEUE CLEAR. STUDY OR SAY HI`. Service: the board. Sales: the quarter's quota. Owner: your peer goal's title, or
  getting the cash above zero. A micro-session supplies its own line. Free Play: nothing.
- `Goals.next_up(limit)`: `[{at, text}]`, soonest first: lunch (day modes), the season's calendar event, the all-hands, closing
  time (`THE BOOKS CLOSE` in the books modes), then `AFTER WORK: A TEAM OUTING`, `TONIGHT: ON CALL`, then tomorrow (the
  conference trip, a season starting). Only the schedule: never a surprise mail or card.
- `Goals.draw(canvas, left_lines)`: wide and h: right-aligned under the clock, on a soft dark plate, at most 38 characters,
  two next-up rows on the 128 px screen (`SHORT_NEXT`, so it stays above the wall TV) and three otherwise; v (width under 260):
  stacked under the HUD's left lines. Not drawn while a phone banner slides; only the goal line while a screen is open.

### Collection page (`scripts/collection.gd`, pages of `career_screen.gd`; test `tests/collection.gd`)
- The career screen has `CAREER - COLLECTION` pages after the medals, and **C** jumps to them (footer `C = COLLECTION`).
  Rows: THE CAST (met, best level), KARAOKE SONGS, ESCAPE CLUES (the ten recipes), PRINTERS BEATEN (six models and the line
  printer), MEDALS (the count), THE OFFICE (this run's decor, or the rule that unlocks it).
- Career keys: `met.<name>` / `cast_met` (`Social.note_chat`, a level-up), `rel.<name>` (best level), `song.<id>` /
  `songs_sung` and `recipe.<id>` / `recipes_seen` (`Career.note_outing` reads `Outings.g.song` and `Outings.g.clues`),
  `pr.<model>` (already there).

### Cast relationship levels (`Collection.LEVELS`)
- `Social.value(who)` read as a level: 0 NEW FACE, 1 COWORKER (10), 2 LUNCH BUDDY (25), 3 FRIEND (45), 4 WORK FAMILY (70).
  `Social.change` calls `Collection.note_change`: the first time a run reaches a level, a toast with the person's line, the
  career keeps the best level, and at levels 3 and 4 a coffee on your desk (`COFFEE` = +3 energy, only where the tech
  campaign's Shift runs). Reached levels: `Story.flags["rel_lv"]` (saved), so a level is announced once a run.
- Shown on the collection page (best level ever, this run included). Not on the phone contacts (another agent's file).

### Office growth (`scripts/office_decor.gd`; test `tests/office_growth.gd`)
- `OfficeDecor.ITEMS`: plant (reputation 55), rug (cash 400), certificate (reputation 65), trophy shelf (3 medals), fish tank
  (reputation 75), neon sign (cash 1500), more trophies (8 medals). Cash = `Campaign.cash` (tech, service) or a tenth of what
  the books gained since the start (owner, sales: `(Owner.cash - START_CASH) / 10`).
- `OfficeDecor.check()` unlocks what the numbers allow and toasts `NEW IN THE OFFICE: ...`; the list is
  `Story.flags["decor"]` (saved with the campaign and the resume point; it stays when the reputation dips).
- `OfficeDecor.dress(stage)` (called by `Stage._ready`) adds the node at the bottom of the main floor's `Fx` layer (so the
  lights-out tint covers it); it checks again every 2 s. Everything is drawn with rectangles and `PixelFont`. Free Play: none.

### Micro-sessions (`scripts/micro.gd`, title home row QUICK PLAY; test `tests/micro.gd`, layout audit `title quick play`)
- `QUICK PLAY` > `ONE OUTING` / `ONE TICKET SHIFT`, both on Free Play with the saved look, no character select, nothing saved.
- One outing: `Micro.begin("outing")` sets `Toolbox.game_i` and `Toolbox.queued`, so the Free Play toolbox launches it
  (`Toolbox.after_start`); the games take turns (`OUTINGS`, career counter `micro_outings`).
- One ticket shift: five tickets from the `micro` stream; the goal chip counts them; at five a toast with the time, career
  `micro_shifts` and `micro_best` (fastest, seconds). `Hud._process` calls `Micro.tick()`.

### Seasonal calendar events: see section 4.

## 3. Quit risks, measured (`tests/quit_risks.gd`, the `MEASURE` lines; Easy tier, seed 5 unless noted)

| Risk | Before | After | What changed |
|---|---|---|---|
| Idle start of day 1 | first card 52.5 s, first ticket 93 s (75 s timer + the phone call) | first card 15 s, first ticket 38 s (20 s + the call); the goal chip says `OPEN THE COMPUTER AT YOUR DESK` from second 0 | `Difficulty.COZY.first_ticket` 20 (`Msp.new_day`), `Story._at`: on cozy day 1 the welcome mail and Dan's offer come at 8:36 and 8:42 |
| C reads as failure | a day with nothing closed: C; a score of -6: D (red), no words | both C, with the line `C IS A STEADY DAY. ...` under the report | `Campaign._cozy_close`: grade floor C and `COZY_TEXT.grade_c` in the report's notes (all four modes) |
| Day 2 commute | late 0 min, 0 tickets waiting, reputation 0 for all three choices; leaving early cost 6 energy | the same, and leaving early costs 0 energy | already safe (`Shift.commute`); only the energy cost of the early start is gone on Easy |
| Week 2 on-call | 3.33 pager cards in the on-call week on average, worst 5 (12 seeds) | 0.83 on average, worst 1 | `COZY.page_chance` 0.25 and one page a week at most (`Shift._cozy_paged`) |
| No visible office change | nothing | office growth (above) | |

Normal tier, measured in the same run and unchanged: first ticket 93 s, grades C / D, sleeping in 76 min late with 3 tickets
waiting, 3.42 pager cards a week.

## 4. Seasons (R8) and the seasonal calendar events (R16) (`scripts/seasons.gd`; test `tests/seasons.gd`)

- **The calendar**: a run is a year in 20 units, November 2013 to October 2014 (Year 2: a year later). Unit u is month
  `(u - 1) * 12 / 20`: 1-2 NOV, 3-4 DEC, 5 JAN, 6-7 FEB, 8-9 MAR, 10 APR, 11-12 MAY, 13-14 JUN, 15 JUL, 16-17 AUG, 18-19 SEP,
  20 OCT. `Seasons.month(unit)`, `date_text()`.
- **Seasons** (`SEASONS`): holidays (units 3-4), tax (6-10), xp (9-10, the first year only: April 2014), school (17-18).
  `Seasons.tags(unit, year)`, `current()`, `in_season(card_id, unit, year)`.
- **Tags on the decks**: `Events.pool` skips a tagged card or vignette out of season. `Seasons.TAGS` tags existing ones (the
  old `tax_season` card, days 3-9, now only shows from day 6); `Seasons.CARDS` holds eight seasonal cards (two per season, the
  shape of deck cards, validated by `Events.violations`), which join the pool in season. The draw is the same seeded `events`
  stream. `Events.card_of(id)` finds a card in either table.
- **Calendar events** (`Seasons.EVENTS`, `EVENT_AT`): one per season at a fixed unit and time: the holiday potluck (unit 4,
  12:12), a thank-you basket (unit 8, 11:00), the day XP support ends (unit 10, 11:00), the school supply drive (unit 18,
  11:30). `Seasons.tick()` (from `Events._process`) shows it at a calm moment, marks it in `Story.flags["season_seen"]`
  (saved) and drops it after 15:30. The next-up list announces it, and a season starting tomorrow.
- **Dressing** (`Seasons.dressing()`, drawn by `OfficeDecor`): holiday lights along the ceiling, tax boxes by the door, an
  `XP APR8` poster, a supply drive box in the entrance.
- Patchable text: `Seasons.CARDS` and `Seasons.EVENTS` are registered in `strings.gd` (static script root, like `Habits`).

## Decisions made

- The calendar starts in November 2013 so the existing story fits (the XP warning mail of day 4, the tax card "in April").
- The resume point saves the mode singletons generically (every plain-data variable) instead of a hand-written list per mode.
- Driving to or from a site is not a safe moment; being at the site is.
- The goal chip never lists surprise events (story mails, deck cards), only the schedule.
- Relationship levels are announced by a toast, not a phone text (tests and the text list stay untouched); the perk is a coffee.
- Decor cash rule in the books modes is a tenth of the books' gain, so one table of thresholds serves every mode.
- Micro-sessions skip the character select and use the saved look; the outing rotates instead of asking.
- Cozy grade floor is C in every mode; the report keeps the letter and adds a line (no new art, no report layout change).
- On Easy the first ticket of day 1 comes after 20 s; Normal and Hard keep 75 s.
- Collection pages live inside the career screen (C jumps there) instead of a separate screen.

## Not done / wanted

- Art wanted: real sprites for the decor (plant, fish tank, trophies, neon sign, rug) and the seasonal dressing; card art (R8).
- The phone contacts do not show the relationship level.
- A Free Play toggle for the decor (film mode) is not there.
- After merging: run `story_export.gd -- --sync --doc` again (this branch synced `strings.txt` for `Seasons` and `grade_c`;
  the sync also wrote the `Expo.FORUM` 3 and 4 strings that were in the code but not yet in the file).
- An owner / sales card can send you on a client visit; a resume point written there opens at the client's office with the
  office frozen, like a tech visit (`tests/resume5.gd` drives home before it lets the week end).

## Balance check (bots)

- `tests/bot_run.gd -- tech hard careful seeds=4 first=11` on this branch: reputation 67, 73, 60, 71, all good endings
  (the baseline cell for seed 11 is 70).
- `tools/balance_baseline.py` (the `tiers_balance` smoke run, tech at time scale 120) was run twice while other agents were
  using the machine: `tech hard careful seed 11` came out at reputation 12 and then 34 (baseline 70), and
  `tech normal lazy seed 11` at 37 once (baseline 4); the other 21 to 23 cells were inside the tolerance. The two runs of the
  same code disagree with each other by more than the tolerance, so this is the harness's known run-to-run spread, not a
  measured effect of this batch. Worth one quiet rerun after the merge.

## Tests

`resume5`, `quit_risks`, `seasons`, `goal_chip`, `collection`, `office_growth`, `micro` (new); blocks in `layout_audit`
(`title quick play`, `hud goal chip tech`, `hud goal chip owner`; the collection pages are covered by the career page
loop); `resume` and `events` adjusted (the version constant, `Events.card_of`). `tests/cozy_shots.gd` writes screenshots
(needs a renderer).
