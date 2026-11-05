# R38 rival habits and good habits: the P0 scaffold API

Design: `docs/scope-bad-habits.md` (read it first). This page is the contract between the scaffold (P0, built) and the agents that fill it in
parallel. Every public signature below is FINAL: change a body, not a signature. All of it is the owner campaign; nothing here changes the
game while no habit is adopted, no skeleton is open and no rap sheet entry exists (the existing balance is untouched).

Decisions taken for the open questions of the doc: conscience is words only (band + Marge's folder count, never a number); consequences never
hard-fail a campaign beyond the existing rules; Big Cheese stays funny (fraud with a laugh, nobody endangered); Plumb Line is kept but is the
first thing cut; vendor reports can pay a rebate; Year 2 carries the Standard at 60% (a note only, NOT built); no freezer-bag prop art (text and
fx toasts only). Text: the 3x5 pixel font charset, 2013-14, no AI, "two-factor login". Ideas only from the blog series, no names or lines.

## Files and who owns them

| File | What | Owner (agent) |
|---|---|---|
| `scripts/rival.gd` | rap sheet, arc table, channels | rival: beats |
| `scripts/rival_cards.gd` | `CARDS` / `DAYS` data (rival_* beat cards, bill_* cards) | rival: beats (rival_*), temptation (temp_*, bill_*), habits (habit_*) |
| `scripts/habits.gd`, `scripts/habits_view.gd` | 14 habits, freshness, Standard, queries, the two Boardroom tabs | habits |
| `scripts/temptation.gd` | skeletons, conscience, bills, come clean, due diligence | temptation |
| `scripts/takeover.gd` (+ `onsite.gd`, `playbook.gd`) | inherit meter, visit kind, six jobs | takeover |
| sales campaign (`sales_campaign.gd`, `deals.gd`, `quote_builder.gd`, `crm.gd`, `sales_beats.gd`) | P5, uses `Rival.assessment`, `Habits.fresh("H2")`, `Temptation` | sales |
| `owner.gd`, `computer.gd`, `strings.gd`, `incident.gd` | scaffold hooks, already done | nobody: only add a one-line hook if a query below is missing |

Rules: edit a `.gd` and the identical text in `tools/make_godot.py` in the same commit (never run the generator in the tree; use
`python -I tools/check_generator.py --keep --scratch <abs dir>` and copy over only what you changed). The five new modules are plain
`RefCounted` static helpers preloaded as `const` in the files that use them (`Owner` has `Rival`, `Habits`, `Temptation`, `Takeover`,
`RivalCards`); there are no new autoloads. New static helper files need a `write("scripts/x.gd", ...)` block in `make_godot.py`.

## Saved state (Owner)

| Name | Type | Meaning |
|---|---|---|
| `Owner.habits` | Dictionary | `{"H1": {start, last, uses}}`; a habit missing from it is NONE |
| `Owner.consc` | int | conscience, 0 clean, negative below; never shown as a number |
| `Owner.skel` | Array | open skeletons `{id, due, class, size}`; `due` 99 = no date |
| `Owner.inherit` | Dictionary | client index -> inherited risk 0-100 |
| `Owner.flags["rap_<rival>_<habit>"]` | int 0-3 | rap level (only goes up) |
| `Owner.flags["arc_queue"]` | Array of card ids | beats waiting for the next morning |
| `Owner.flags["arc_<card id>"]` | week | a beat already shown |
| `Owner.flags["consc_week"]` | week | last week the conscience rose (cap +1 a week) |
| `Owner.flags["lapsed_<Hn>"]` | week | the lapse note was given |

All of it is in `Owner.to_dict()` / `from_dict()` / `reset()`; an old save loads with defaults. JSON turns ints into floats: always `int(...)`.

## Owner hooks (already in place)

- `Owner._ready()` merges `RivalCards.CARDS` into `Owner.CARDS` by reference. `Owner.events_on()` merges `RivalCards.DAYS` into `Owner.DAYS`.
- `Owner.begin_day()`: `Rival.morning(self)` right after `Incident.morning()` (shows one queued beat card).
- `Owner.settle()` (owner campaign only), in this order after `Incident.week()`: `Rival.arc_week(self, Campaign.day)`, `Habits.week(self)`,
  `Temptation.week(self)`. Report rows: `STANDARD` (once any habit is started), `FOLDER` (while a skeleton is open), `RAP SHEET` (one per rival
  with something known).
- `Owner.practices()` adds `Habits.practice_count()` (cap 3). `Owner.multiple()`: `Habits.maturity_bonus(oml())` replaces the old oml>=4 bonus
  (0.25 as before; 0.5 at Standard 70+; never stacks) and `- Temptation.diligence()` (from week 16). Note: the doc says the old bonus was 0.5,
  the code has always had 0.25.
- `Owner.poach_gaps()` adds "no restore proof" when `Habits.gap_restore()`; `poach_risk()` adds `Habits.poach_adjust(client)`;
  `_rdp_week()` multiplies by `Habits.rdp_mult(weak)`; `Incident.miss_share()` multiplies by `Habits.bec_mult()`.
- Not hooked yet (the habits agent adds a one-line call at the site, with the same neutral default): `Habits.ransom_mult()` in the ransom bill,
  `Habits.restore_fail()` in `_ransom`, `Habits.breach_mult()` in `_vendor_breach`, `Habits.creep()` in `Projects`.

## fx keys (read by `Owner.apply`)

| Key | Value | Forwards to |
|---|---|---|
| `rap` | `[rival, habit, level]` or a list of those | `Rival.apply_rap` |
| `habit` | habit id (touch; starts it if never started) | `Habits.apply_touch` |
| `habit_start` | habit id or list of ids (free start, no charge) | `Habits.apply_start` |
| `consc` | int (a rise is capped at +1 a week, a fall is not) | `Temptation.change_consc` |
| `skel` | `[id, weeks]` or a list of those (`weeks` < 0 draws from `Difficulty.rng("skeleton")`) | `Temptation.apply_skel` |
| `visit` | `"takeover"` (a no-op until `Takeover.ENABLED`) | `Takeover.visit(self, kind)` |
| `lead` | int, extra inbound leads | `Owner._leads` |
| `weekly`, `owner_hours` | already existed (`weekly_extra`, `Growth.owner_used`) | unchanged |

## Public API

### `Rival` (`rival.gd`)
`LEVELS`, `UNKNOWN/RUMOUR/SEEN/PROVEN` (0-3), `HABITS` (R01-R17: name, text, twin), `RIVALS` (bytebrothers, bigcheese, plumbline: name, owner,
habits, blurb), `ARC` (week -> card id). `HABITS` and `RIVALS` are `static var` copies of `DEFAULT_*`, patchable from `strings.txt`.
- `key(rival, habit) -> String` ; `rap(rival, habit) -> int` ; `set_rap(rival, habit, level) -> bool` (true if it went up)
- `count(rival, level) -> int` ; `known(rival) -> bool` ; `line(rival) -> String` ; `lines() -> Array` ; `best(habit) -> int`
- `apply_rap(fx: Array)` ; `arc_week(owner, week)` (queues the beat of week+1 if its card exists) ; `morning(owner)`
- TODO(rival agent): `intel(rival) -> String`, `defect_exit(rival, client)`, `assessment(rival) -> Array` (sales P5), the per-beat conditions in
  `arc_week`, the cards `rival_flat rival_wall rival_defect rival_notebook rival_takeover rival_2fa rival_vendor_audit rival_exposed rival_blitz
  rival_badday` (ids already in `ARC`), the forum/Vic/winback channels (hooks into `Nerds`, `_winback_card`, `_poach_card`, `Owner.on_deal`).

### `Habits` (`habits.gd`)
States `NONE ADOPTED STALE LAPSED`; `HABITS` (H1-H14: name, cost{cash,hours,morale}, every, weight, earns, shown; patchable), `BANDS`.
- `all()`, `entry(id)`, `any()`, `age(id)` (-1 if NONE), `state(id)`, `fresh(id)`, `factor(id)` (1.0 / 0.5 / 0.0), `cost(id)` (full, half when
  STALE or LAPSED, 0 when fresh)
- `start(id) -> bool` (free), `adopt(id) -> bool` (pays `cost`), `touch(id) -> bool` (free, resets freshness), `apply_start(ids)`, `apply_touch(id)`
- `standard() -> int` (0-100), `band(score := -1)` (BARE <35, PATCHY 35, SOLID 60, SHOWCASE 80), `standard_text()`, `practice_count()`,
  `maturity_bonus(oml)`, `week(owner)`
- Queries other systems call (all neutral while the habit is not adopted): `gap_restore()`, `poach_adjust(client)`, `bec_mult()`,
  `rdp_mult(weak)`, `restore_fail()`, `ransom_mult()`, `breach_mult()`, `creep(base)`
- TODO(habits agent): morale cost in `adopt`, the lapse nudge card, all real effects from doc section 4 (H2 scorecard at `_qbr`, H3 creep in
  `Projects`, H4/H5/H6/H12/H13 hooks, H9 week 19 card, H10/H11/H14 with the sales and onsite agents), the cards `habit_*` in `RivalCards`.

### `HabitsView` (`habits_view.gd`)
- `tabs() -> Array` (`[["habits","HABITS"],["rivals","RIVALS"]]`, empty until `live()`), `live() -> bool`, `paint(c, area, tab)`. The Computer
  only registers the tabs and calls `paint`. Read-only; add detail, never new Computer code.

### `Temptation` (`temptation.gd`)
`BILLS` (temp_seats, temp_reboot, temp_quest, temp_review, temp_launder, temp_price, temp_2fa, temp_restore: class, lo, hi, size, rep, mood, text),
`BANDS`, `NO_DATE` (99).
- `consc() -> int`, `change_consc(n, force := false)`, `band() -> String` (CLEAN BOOKS / A FEW LOOSE ENDS / SKELETONS / A CLOSET FULL)
- `folder_count() -> int`, `find(id) -> int`, `add_skeleton(id, weeks := -1) -> bool`, `apply_skel(fx)`, `bill_size(sk)` (cozy halves),
  `clean_cost(id) -> int` (40% of the bill, at least $50), `come_clean(id) -> bool` (+1 conscience), `bill(owner, sk)`, `week(owner)`
- `diligence() -> float` (0.5 per open skeleton, max 1.5, from week 16), `diligence_line()`, `folder_text()`
- TODO(temptation agent): the eight `temp_*` cards and their `bill_*` cards, per-class bill extras, the COME CLEAN card from the second
  skeleton, triggers for the dateless insurer bill, tuning with the `shortcuts` bot.

### `Takeover` (`takeover.gd`)
`ENABLED` (false), `KIND` ("takeover"), `PER_FINDING` (15), `FINDINGS_TAKEOVER` (empty, six entries to come), `JOBS` (T1-T6: name, rap, twin).
- `inherit(client) -> int`, `set_inherit(client, v)`, `begin(client, open_findings := 6)`, `fixed(client, job := "") -> int`, `open_clients()`,
  `risk_mult(client) -> float`, `visit(owner, kind)`, `on_inspect(client, obj)`
- TODO(takeover agent): `Onsite` visit kind "takeover" (meeting row, `FINDINGS_TAKEOVER`, grade), six Playbook books, flip `ENABLED`, wire `risk_mult`
  into the weekly incident chances, call `Rival.set_rap` for the evidence of each job.

### `RivalCards` (`rival_cards.gd`)
`CARDS` and `DAYS` (`static var` copies of `DEFAULT_CARDS` / `DEFAULT_DAYS`, empty now), `merged_days(base)`. Add cards to `DEFAULT_CARDS` in the
shape of `Owner.CARDS` and they appear in `Owner.CARDS` and as `[RivalCards.CARDS.<id>...]` in `story/strings.txt` (run
`story_export.gd -- --sync` after adding). Beat cards in `Rival.ARC` need no `DAYS` entry.

## Strings

`Strings.ROOTS` has `Rival: [HABITS, RIVALS]`, `Habits: [HABITS]`, `RivalCards: [CARDS]`. These roots are scripts, not autoloads, so
`Strings.SCRIPTS` maps the root name to the script path and the tables are `static var` copies. Tables you add to those scripts follow the
same pattern: `const DEFAULT_X := {...}` + `static var X: Dictionary = DEFAULT_X.duplicate(true)` and a ROOTS entry.

## Tests

`tests/rival.gd`, `tests/habits.gd`, `tests/temptation.gd` (green with the scaffold). Add `tests/takeover.gd`, `tests/sales_rival.gd`,
`tests/habits_text.gd` (charset, 2013-14 words, the series' names as a banned list seeded by the user) as the doc's section 9 says.

## P6 light touches and guards (light-touches agent)

Files: `scripts/rival_touches.gd` (`RivalTouches`, a static helper, owner: this agent), `tests/habits_text.gd`, `tests/rival_touches.gd`,
`story/banned_names.txt`. Shared files got one-line edits only (nerds, talk, lync, knowledge, career, yeartwo, strings, habits, temptation, takeover).

- **Rap gating.** A forum thread (`Nerds.THREADS`) or IRC exchange (`Nerds.AMBIENT`) with `"needs": "rap:<rival>:<habit>"` shows once
  `Rival.rap(rival, habit)` is RUMOUR or better; `rap:<rival>:<habit>:2` asks for SEEN, `:3` for PROVEN. `RivalTouches.needs_ok(needs)` is the
  one test; `Nerds.thread_visible` and `Nerds._eligible` call it. Ten threads and four exchanges exist (habits R01, R02, R04, R05, R06, R11).
  They are never daily questions. Other agents may add more with the same needs string.
- **Talk and Lynk.** `state_key()` is `""`, `rival`, `bare`, `solid`, `showcase`, `loose` or `closet` (conscience first, then the Standard band,
  then the rival). `TALK[who][key]` is read by `Talk.owner_idea` (60%), `LYNK[who][key]` by `Lync.incoming` (20% of messages in the owner
  campaign, never the same person and key within 4 weeks) and `LYNK.Marge` is added to Marge's HOW ARE WE DOING reply. Words only, no numbers.
- **Tech and service.** `freezer_tip(who, mode, roll)` (Alan, Dan, tech campaign, 25%) is a `Talk.tip` fallback. `runbook_note(id)` adds one line
  to the Knowledge footer for the restore and antivirus runbooks (the green dashboard note).
- **Career.** Counters `habits_adopted` (first start of each habit), `skeletons_paid` (come clean or a bill that arrives), `takeovers`
  (`Takeover.begin`) and `clean_sheets` (`RivalTouches.note_year_end`, called from `Yeartwo.record` for the books campaigns when no skeleton is
  open, the conscience is CLEAN BOOKS and a habit exists). Medals HABIT FORMING (5), SPRING CLEANING (3), CLEAN UP CREW (3), CLEAN SHEET (1).
- **Year 2.** `Yeartwo.record` saves `standard` in the meta record. `Yeartwo.begin_run` (books campaigns) calls `RivalTouches.year2_begin(prev)`:
  habits are started (free, fresh) heaviest first until about 60% of the old Standard is back, listed in `carried.habits`, and
  `RivalTouches.rival_year(2)` renames `Rival.RIVALS.bigcheese` to HARD RIND IT (the id and every rap key stay the same). `Yeartwo.reset()` puts the
  name back and `Yeartwo.from_dict` re-applies it for a saved Year 2 run. The text is `Yeartwo.TEXT.habits` (carry, rival_note, rival).
- **Text guard.** `tests/habits_text.gd` scans every constant of the scripts in its `REGISTRY` plus any script under `scripts/` that has `R38` in
  its first 15 lines, the rap: threads and exchanges, sales `BEAT_TEXT` keys containing rival / incumbent / flat, `Yeartwo.TEXT.habits`, the R38
  career entries, and the `Rival. RivalCards. RivalTouches. Habits. Temptation. Takeover.` keys of `story/strings.txt`. Rules: 3x5 charset (the
  `{token}` placeholders are removed first, no double quotes), no AI / MFA / Teams / Slack / Windows 10 / Windows 11 and similar, and no name from
  `story/banned_names.txt` (one per line, # comments; the user seeds it with the series' character names, it ships empty). A new table needs no
  change to the test: carry `R38` in the script header or add the path to `REGISTRY`.
- After merging all R38 branches run `story_export.gd -- --sync` once (the strings.txt hunks of the branches will collide).
