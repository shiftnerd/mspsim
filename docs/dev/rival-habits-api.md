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
- Hooked by the habits agent (R38 P2): `Habits.ransom_mult()` in the `ransom_end` fx, `Habits.restore_fail()` in `_ransom`, `Habits.breach_mult()` in
  `_vendor_breach`, `Habits.creep()` in `Projects`; see the `Habits` section below for the rest.

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
- BUILT (R38 P2, habits agent): `adopt` charges the morale cost (back after two weeks), `redo_cost(id)`, `touch_if(id)` (a real event only counts
  while ADOPTED or STALE), `action(id) -> {label, enabled}` and `act(id) -> String` (the tab button: adopt, re-adopt or do it now; H1 needs a working
  backup), `progress(id)`, `mapped_count()`, `apply_adopt(id)` (fx `habit_adopt`, a card pays and starts it). `Habits.CARDS` (`habit_offer`,
  `habit_lapsed`, `habit_clocks`, `habit_revenge`, `habit_ports`) and `Habits.TEXT` are patchable tables (ROOTS `Habits: HABITS TEXT CARDS`); the cards
  are shown as copies in `Owner._dynamic` (key `<card>_<id>`), so they are NOT in `Owner.CARDS`.
- Touch rules (real events, each one line in its system, all no-ops while the habit is not working): H1 `act` (restore test: $150, 3 h, needs a client
  with a working backup), H2 `qbr(client)` in `Owner._qbr` (mood +2, 1 h; STALE +1), H3 `project()` in `Projects._quoted`, H4 `refusal(choice)` when the
  waiver is chosen (`risk_choice`), H5 `loss(client)` in `Owner.drop_client`, H6 `departure(who)` on a quit (a LAPSED/STALE H6 may bring the revenge
  card), H7/H8/H9/H10/H11/H12/H13/H14 by `act`. H8 also starts `rdp_safe` and, once stale, re-opens it (3% a week per client). H11 maps one client per `act`
  (6 h). Week 19: the clocks card (H9). One pitch every 2 weeks from week 3 (`OFFER_ORDER`), declined by default (NOT NOW is option 0).
- Effect queries and where they are read: `ransom_mult()` (`apply` with `ransom_end`: cash back), `restore_fail()` (`_ransom`), `breach_mult()`
  (`_vendor_breach`), `creep(base)` (`Projects.week`), `change_odds()` (`Projects.change_order_odds`), `refusal_save()` (`_client_breach`),
  `new_client(c)` (H10 mood +6, in the `sign` fx), `onsite_mult(client)` (`Onsite._chose`, `_event_answer`), `walk_mult()` (`Onsite.inspect`),
  `drifting(client)` (CLIENTS chip), `assess_win_adj()` (H10 -3 points: NOT read yet, for the sales agent), `site_share()`.
- Balance (`tests/owner_balance.gd`, `SEED=n ... -- smart|honest`; `honest` is smart's answers plus one `Habits.act` a week; runs are NOT bit-for-bit
  repeatable even with a seed, smart seed 1 gave $467k, $475k and $398k): smart seeds 1-3 end at cash $14k/$25k/$28k, value $476k/$552k/$649k (before
  the habits: $13k/$24k/$4k, $467k/$329k/$543k), Standard 0. honest ends at cash $7k/$15k/$17k, value $324k/$277k/$635k, Standard 100: the habits cost
  a few thousand dollars and owner hours and buy fewer incidents; the difference is inside the run to run noise.
- Not done: H9 night job failure rate (card only), H3 failed cutover costs half, H13 blame halving in `bec_loss` (it is in `bec_mult` only), the
  default password walk-around finding (H14 gives a small breach cut only), a TESTED date on the RMM backups tab, the `rival_cards` sales hooks.

### `HabitsView` (`habits_view.gd`)
- `tabs()`, `live()` (also true from week 3 of the owner campaign so the tab can be found), `paint(c, area, tab)`, `act(c, parts)` (clicks `hab:sel:Hn` and
  `hab:do:Hn`; computer.gd forwards `hab`), `books_rows()` (STANDARD row, ", ENVELOPE" while H7 works), `chip(client)` ("SLIPPING" for the CLIENTS tab).
  HABITS: two columns of 7 rows from 300 px wide, one below; the selected row shows what it earns (a one line summary from `TEXT.short_Hn` on a short
  screen), its progress line and the ADOPT / RE-ADOPT / DO IT NOW button. Checked at 368x128, 320x180 and 180x320 (`tests/habits_shots.gd`).

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
