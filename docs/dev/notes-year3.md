# Build notes: Year 3, the last chapter (roadmap R10)

Branch `worktree-agent-abfcafae8daf8ea6e`. Scripts: `scripts/yeartwo.gd` (the machinery and all the text), small edits in
`campaign.gd`, `title.gd`, `charselect.gd`, `review.gd`, `career.gd`, `seasons.gd`, `hud.gd`, `day_report.gd`, `service.gd`,
`sales_campaign.gd`, `strings.gd`. Tests: `tests/yearthree.gd` (default suite), `tests/bot_year3.gd` (dev run),
`tests/bot_lib.gd` (a `year` field), `tests/layout_audit.gd` (the title submenu with the new row).

## What was built

- **One year index, no second copy.** `Campaign.year` was already a number; `Yeartwo` now treats it as one. `YEAR := 2`,
  `LAST_YEAR := 3`. Every table a Year 2 run reads is read through `Yeartwo.year_cfg(key)` (numbers) and
  `Yeartwo.year_txt(key)` (text): in Year 3 they return the `YEAR3` / `TEXT3` row when Year 3 has its own and the Year 2
  row otherwise. Year 3 has its own `sla`, `beats`, `endings`, `needs`, `left`, and its own `intro`, `beats`, `offers`,
  `endings` text. Everything else (ticket weights, the 12 percent P1 promotion, the three newer clients, ten client slots,
  one tier more mutators, the story shuffle, the owner's renamed rival and the carried habits) is Year 2's, unchanged.
- **Unlock.** `Yeartwo.record` (called by `Campaign.finish_campaign`) now also writes `top_year` (the highest year finished
  in that mode) and, for a year 2 or 3 run, a snapshot of that run under `y2` / `y3` (ending, rep, skills, value, cash,
  trust, shop, standard, and the beat answers as `flags`). `available(mode, 3)` is true once `top_year >= 2`. The plain keys
  still follow the LAST finished run, exactly as before, so Year 2 keeps unlocking and carrying the way it did.
  `record_for(mode, year)` is what a new run follows: the last run for Year 2, the `y2` snapshot for Year 3 (so a first
  year replayed after Year 2 neither locks Year 3 nor becomes what it carries from). An old meta file whose last run was a
  Year 2 (`year = 2`, no `top_year`, no `y2`) opens Year 3 and is carried from as it stands.
- **Title.** `Title.sub_items(mode)` adds `START YEAR 3 - <carry summary>` (id `<mode>_y3`) under START YEAR 2. It opens the
  same character select: `Charselect.setup(mode, year2, year := 2)`, `Yeartwo.begin_select(mode, year2, year := 2)`,
  `Yeartwo.pending_year`. `Campaign.new_game` asks `Yeartwo.take_year(mode)` (1, 2 or 3). The MUT chip and the two extra build
  points work as in Year 2. Save tags, the HUD line, the day report title and the select summary say `YEAR 3`
  (`Yeartwo.label(year)`, `Yeartwo.tag_of(year)`).
- **Carry-over.** The same `CARRY` rules, applied to the Year 2 run's record.
- **Harder.** `YEAR3.sla.mult` (see Tuning) instead of Year 2's 0.85. Nothing else was added to the difficulty: the row asks
  for one more notch on the clocks.
- **The closing arc.** Three beat cards per campaign (`YEAR3.beats`, text in `TEXT3.beats`), through the same
  `Yeartwo.begin_day` -> `Cards.ask` path as Year 2's beats. A beat row may have a `lynk` line (`{from, text}`) that is pushed
  to Lynk just before its card. Answers are kept in `Story.flags["y3"]` (`Yeartwo.flag`, saved with the campaign; Year 2
  keeps using `y2`). `Yeartwo.last_flag(key)` reads an answer of the Year 2 run from the record (not used by a rule yet).
- **Endings.** `Yeartwo.extra_offers` slots the Year 3 endings above STAY in the tech review, the owner board review and
  now also the sales and the service review (`Review.make_offers` wraps both; with no rows in Year 2 this changes nothing
  there). `SalesCampaign.epilogue` and `Service.review_lines` fall back to `Yeartwo.ending_text` for an ending they do not
  know. A review without a STAY row (sales: let go, or notice already given to ByteBrothers) gets no Year 3 ending.
- **Career.** Medal THIRD YEAR (`year_three`, counter `year3_done`, counted for every finished Year 3 run) and one medal per
  ending (same id as the ending, counter `end.<id>`, not on a cozy / Easy run, like the service ending medals). They are
  rows of `Career.MEDALS`, so the career screen and the collection page show them without further code. Counter
  `year3_runs` counts started runs (`year2_runs` / `year2_done` still count Year 2 only).
- **Calendar.** `Seasons.date_text` stops moving at Year 2's calendar (`LAST_SHIFT := 1`): Year 3 reads NOV 2014 to
  OCT 2015 like Year 2. The "first year only" XP season stays out of Year 3 the same way it stays out of Year 2
  (`Seasons.tags(unit, year)`), the yearly seasons (holidays, tax, school) run as usual.

## The arcs (first draft text, all patchable under `Yeartwo > TEXT3` in `story/strings.txt`)

| Campaign | Beats (day / week) | Endings and what opens them |
|---|---|---|
| Tech | `newhire` 3 (Morgan: Quinn, the new hire, sits next to you), `mentor` 11 (Quinn rebooted a PC without asking), `fork` 18 (Dan moves to projects: what do you want?) | `y3_chair` TAKE DAN'S CHAIR (fork chair, mentored Quinn at either beat, team mood >= 0, rep 60); `y3_senior` STAY TECHNICAL (fork tech, rep 55); `y3_farewell` LEAVE ON GOOD TERMS (fork go, team mood >= 0, rep 50) |
| Owner | `summit` 6 (Ross Calder of Summit Managed Holdings wants to see the books), `staff` 12 (Christy: the staff would like to be asked first), `handover` 17 (Morgan: give me the day-to-day for a month) | `y3_summit` SELL TO SUMMIT (books or listen, 6 clients, cash >= 0, rep 55); `y3_staff` SELL TO THE STAFF (yes, cash >= 0, rep 55); `y3_morgan` KEEP IT, MORGAN RUNS IT (trial, cash >= 0, rep 55) |
| Service (Dan) | `deputy` 4 (Morgan: train somebody to run the board), `terry` 10 (Terry Vance calls about you this time), `table` 16 (Alan and Garrison: operations or a stake?) | `y3_coo` RUN OPERATIONS (table ops, confidence 60); `y3_partner` BECOME A PARTNER (table partner, both owners' trust >= 50, confidence 60); `y3_across` TAKE THE JOB ACROSS TOWN (terry hear, deputy trained or written down, confidence 50) |
| Sales (John) | `wes` 5 (Wes lost two quotes: ride along?), `split` 11 (Garrison: split the territory with Wes), `chair` 16 (Garrison is done carrying a bag) | `y3_director` TAKE GARRISON'S CHAIR (chair, the line was not the cold side, you did not take Wes's call, trust 55); `y3_wes` LET WES TAKE THE CHAIR (wes, and you coached him, trust 50); `y3_stake` TAKE A SHARE OF THE SALES SIDE (stake, trust 60) |

What Year 2 had promised and where it is paid: Tony Marsh's and Walt Reiner's offers were Year 2 endings already and are not
re-opened. Morgan's "run the desk for a week" (tech, Year 2) becomes Dan's chair. Terry Vance, who asked Dan for names in
Year 2, calls about Dan. Garrison's Year 2 card "Wes reports to you now" becomes the chair itself, with Wes as the other
candidate. Summit Managed Holdings (the roll-up of the sales and service stories, auditor Ross Calder) is the buyer in the
owner's exit. Year 1 and Year 2 endings are untouched and stay on offer in Year 3 where their own rules allow.

## Decisions made

- **Year 3 follows the Year 2 run, whatever its ending.** A Year 2 that ended with you leaving (in-house job, buyout, sold
  company, ByteBrothers...) does not block Year 3, the same way Year 1's leaving endings never blocked Year 2. The Year 3
  intro card adds one dry line for those endings (`TEXT3.intro.back`, the list is `YEAR3.left`).
- **Year 3 replaces Year 2's beats, it does not repeat them.** Year 2's four extra endings (head, clientbuy, merger,
  franchise) need Year 2's beats and are therefore not on offer in Year 3.
- **Only the clock is tighter.** Ticket mix, P1 share, clients and mutator tier stay at Year 2's level.
- **The calendar.** Year 2 was already written as "a year later" (`APR 2015`, tested by `tests/seasons.gd`), so that stays;
  Year 3 does not move further. `date_text` is not shown anywhere in the game yet. Seasonal cards and the dressing only
  depend on the unit of the year. No later technology appears in any Year 3 text (`tests/canon_text.gd`).
- **No Year 4**, and Year 3 can be replayed (the row stays).
- **Ending medals are not earned on Easy**, following the service ending medals; THIRD YEAR is.
- **The new hire (Quinn) is text only.** No sprite, no desk: she exists on cards and in Lynk lines.
- **Service confidence does not carry over** (existing Year 2 behaviour, left alone): `Service.begin_run` sets Morgan's
  confidence to its own start value after the carry-over, so the `REP nn` in the service row's summary is not what the run
  starts with.

## Public functions (`Yeartwo`)

`year_cfg(key)`, `year_txt(key)`, `label(year := -1)`, `tag_of(year)`, `available(mode, year := 2)`,
`record_for(mode, year := 2)`, `carry_summary(mode, year := 2)`, `begin_select(mode, year2, year := 2)`, `take_year(mode)`
(`take_pending(mode)` is kept and returns `take_year(mode) >= 2`), `beat_row(id)`, `flag(key)` / `set_flag(key, value)`
(the bucket of the running year), `last_flag(key)`, `need(ending, key, fallback := 0)`, `is_year3_ending(id)`,
`is_year2_ending(id)` (true for both years' endings: "an ending Yeartwo owns"). Saved state is unchanged (`VERSION` 1, the
same keys), so an old Year 2 save loads and plays as before.

## Tuning

| What | Value | Where |
|---|---|---|
| Year 3 SLA clock | x0.76 (Year 2: x0.85, Year 1: x1.0) | `YEAR3.sla.mult` |
| Ending thresholds (reputation / confidence / Garrison's trust) | chair 60, senior 55, farewell 50; summit 55 (and 6 clients), staff 55, morgan 55; coo 60, partner 60 (and both owners' trust 50), across 50; director 55, wes 50, stake 60 | `YEAR3.needs` |
| Beat days | tech 3 / 11 / 18, owner 6 / 12 / 17, service 4 / 10 / 16, sales 5 / 11 / 16 | `YEAR3.beats` |
| Everything else | Year 2's numbers, untouched | `YEAR2`, `CARRY` |

No Year 1 or Year 2 number was changed.

### Bot runs (`tests/bot_year3.gd`, normal tier, careful strategy, one Godot process at a time)

Each run starts as START YEAR 3 from the record `bot_lib._seed_year` writes (a finished Year 2 with reputation 70, every
skill at level 3, a company worth $150,000, partner trust 60). Tech, sales and service at the default ts=20, owner at ts=4.

| Campaign | Seeds | Fired | End reputation | Notes |
|---|---|---|---|---|
| Tech | 1, 2 | 0 of 2 | 100, 100 | 149 / 150 tickets closed, 1 / 0 missed. All three beats fired; review offered lead, internal, `y3_chair`, stay. The careful tech bot reaches the reputation cap by day 14, so the tighter clock does not show in this number (no Year 1 or Year 2 comparison was run for tech). |
| Owner (ts=4) | 1, 2 | 0 of 2 | 75, 82 | cash $28,816 / $34,203, value $755,851 / $684,410, client mood 97 / 95. Review offered sell, expand, `y3_summit`, `y3_staff`, `y3_morgan`, stay. |
| Service | 1 to 5 | 0 of 5 | confidence 63, 68, 60, 48, 64 (mean 60.6) | SLA 76 to 77 percent, audit 70 to 77. `y3_coo` and `y3_across` offered in 4 of 5 (seed 4 ended at 48, under both thresholds). The same bot in Year 2 (seeds 1, 2): confidence 77 and 56, SLA 85 and 78 percent. In Year 1 it ends at 98 to 100. Service is the campaign where the clock bites; it is the reason the factor is 0.76 and not lower. |
| Sales | 1, 2, 3 | 0 of 3 | Garrison's trust 89, 90, 63 | quota 128 / 99, 147 / 147, 113 / 100 percent. No Year 3 ending offered: the careful sales bot answers `take` at Wes's ride-along (it is in its preference list), which rules out `y3_director`. That is the rule working, not a dead end: `tests/yearthree.gd` reaches all three sales endings. |

A careful bot is never fired in Year 3 at normal in any campaign (12 runs). Hard and Easy were not run.

## Tests

- `tests/yearthree.gd` (default suite, about 10 s, 170 checks): the tables are complete for all four campaigns; a Year 2
  run reads the Year 2 tables, its clock is still x0.85, its beat and review are unchanged and the saved `yeartwo` section
  has the same keys and version; finishing Year 2 writes `top_year` and the `y2` snapshot and opens Year 3 for that
  campaign only; a first year replayed later keeps Year 3 open and Year 3 still carries from the Year 2 run; an old meta
  file opens Year 3; the title submenu row, its carry summary, the (YEAR 3) save tag and the character select for Year 3;
  then for each campaign and each of its three endings: start Year 3 from a finished Year 2 record, the intro card, the
  x0.76 clock with the rest of Year 2's difficulty still on, `begin_day` for days 2 to 20 opens a card on the three beat
  days only (Lynk line first where there is one), the answers land in `Story.flags.y3`, the review does not offer the
  ending at reputation 30 and offers exactly that one Year 3 ending above STAY in good standing, the epilogue reads, the
  finish is recorded (`ending`, `year` 3, `top_year` 3, `y3`) and the ending's medal plus THIRD YEAR are earned; no Year 3
  ending without a STAY row, without an answer, and no ending medal on Easy; save in the middle of Year 3 and Continue;
  an old Year 2 save (no new keys) loads as Year 2 with its clock, shuffle, flags and offers; a save without a year loads
  as Year 1; the calendar (dates stop at Year 2's, no XP season, XP cards out).
- `tests/bot_year3.gd` (dev run, not in the suite; the numbers above):
  `Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_year3.gd -- <mode> normal careful seeds=3 [ts=4] [year=3]`.
  Exits 1 when a careful run is fired or times out, did not start in the asked year, or a beat never fired.
  `tests/bot_lib.gd` got `var year` and `_seed_year(mode)` (also called from `sv_run`, which switches the save prefix);
  with `year = 1` (the default) nothing changes for the other harnesses.
- `tests/layout_audit.gd`: the fullest tech submenu now has the START YEAR 3 row as well.
- `tests/yeartwo.gd` is unchanged and passes.

## Left / wanted

- Art: a sprite and a desk for Quinn, a card portrait for Ross Calder and Terry Vance.
- `Yeartwo.last_flag` is there so a Year 3 rule or line can depend on a Year 2 answer; no rule uses it yet.
- The Year 3 text is a first draft for the owner to edit.
