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
- DONE (rival agent): `intel`, `defect_exit`, `assessment`, `relabel`, `on_winback`, `apply_fx`, `show`, the beat conditions and all `rival_*` cards (see the Rival arc section). Not done: the forum threads and ambient lines in `Nerds` (RUMOUR channel), left to a later pass.

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

## Rival arc (built by the rival agent: `rival.gd`, `rival_*` cards of `rival_cards.gd`, `tests/rival_arc.gd`)

- Beats: `Rival.ARC` now also has `20: rival_end` (Rex sells the book). `arc_week` queues next week's beat; `morning` shows ONE queued entry. An entry is
  a card id or `"id|arg"` (`rival_decide|R06`, `rival_knew|R03`, `rival_counter`). Beat cards are shown as a COPY in `Owner._dynamic["rv_<id>"]`:
  `{rc}` = the client of the arc (`flags.rival_client`, Delia's office), `{rh}`/`{rl}` = the habit name/text of a decision; options a gate removes are
  left out (`SHOW THE SHEET` needs a PROVEN item and `Habits.standard() >= 60`; `REPORT IT TO THE VENDOR` needs PROVEN and a `VENDOR_HABITS` habit).
- Client beats are dropped quietly when they do not apply (`_ready`): `rival_defect` (a Big Cheese poach already took a client, or fewer than 2 clients),
  `rival_notebook` / `rival_takeover` (the arc client is not gone). `ON_SHOW` gives the evidence of a beat by showing it (2fa SEEN, vendor letter and
  exposed reviews PROVEN); `DECIDES` chains the four option decision (`rival_decide`) the same morning.
- New fx key `rival {ops}` -> `Rival.apply_fx(owner, ops)` (one hook in `Owner.apply`, after `lead`): `defect`, `tag n`, `exit`, `return`, `scope`, `mood n`,
  `discount [mult, weeks]`, `sign n`, `ignore habit`, `decide win|warn|vendor|ignore`.
- Evidence channels: `Rival.intel(rival)` (Vic, weeks 3 6 9 12 14, RUMOUR only, uses `Difficulty.rng("rival")`), `Rival.defect_exit` (R11 SEEN), `Rival.relabel`
  (hook in `Owner._poach_card`: from week 6 half of the price and gap poaches are Big Cheese; uses ONE draw of the `rival` stream and no global roll; a relabelled
  card names Big Cheese, every drop is tagged and an option ASK WHO THEIR NEW IT PERSON IS is added), `Rival.on_winback` (hook in `Owner._winback_card`:
  a tagged leaver gets `flags["takeover_pending_<client>"] = week`, and `gone[client].rival == "bigcheese"`), `Rival.assessment(rival)` (3 to 5 habit ids, known ones first).
- For the takeover agent: `rival_takeover` (week 11) rejoins the client (`Owner.apply({"rejoin"})`, patch debt 4) and sets `takeover_pending_<client>` and
  `flags.rival_returned`; its first option carries `fx visit "takeover"`, which `Owner.apply` runs AFTER the rejoin, so `Takeover.visit` finds the client via
  `flags.rival_client` (use `Rival.arc_client()`), not via `Owner.gone`. The week 19 card also calls `visit takeover` (three signed clients).
- Flags written: `rival_client`, `rival_def_<c>`, `bc_<c>`, `rival_returned`, `rival_dh`, `rival_decided_<habit>`, `rival_knew_<habit>` / `knewdone_<habit>`,
  `rival_retaliate` (week of a vendor report), `arc_<id>`. A flag `takeover_pending_<c>` is the hand-off to the takeover agent.
- Cards set but do not own: `habit_start` H2 H4 H10 H12 (the habits agent may rename), `skel temp_price` (the temptation agent owns `temp_price`).

## Strings

`Strings.ROOTS` has `Rival: [HABITS, RIVALS]`, `Habits: [HABITS]`, `RivalCards: [CARDS]`. These roots are scripts, not autoloads, so
`Strings.SCRIPTS` maps the root name to the script path and the tables are `static var` copies. Tables you add to those scripts follow the
same pattern: `const DEFAULT_X := {...}` + `static var X: Dictionary = DEFAULT_X.duplicate(true)` and a ROOTS entry.

## Tests

`tests/rival.gd`, `tests/habits.gd`, `tests/temptation.gd` (green with the scaffold). Add `tests/takeover.gd`, `tests/sales_rival.gd`,
`tests/habits_text.gd` (charset, 2013-14 words, the series' names as a banned list seeded by the user) as the doc's section 9 says.

## Sales campaign hooks (P5, built: `scripts/sales_rival.gd`, `tests/sales_rival.gd`, `tests/sales_rival_shots.gd`)

A static helper (`SalesCampaign.SalesRival`, preloaded const in `sales_campaign.gd`; Deals, Retention, Handover and the CRM reach it through `SalesCampaign.SalesRival`). State lives on the lead and book dictionaries and in `SalesCampaign.flags` (saved with the campaign); conscience is `Owner.consc` through `Temptation` (words only), habits are `Owner.habits` (Owner resets on every new game, so nothing leaks between campaigns).

- **Incumbent.** `make_lead` draws `SalesRival.incumbent_for(r.randf())` as its seventh draw from `Difficulty.rng("leads")` (always drawn). Fields on a lead: `incumbent` (none / bytebrothers / bigcheese / plumbline / inhouse; odds .30 / .25 / .20 / .10 / .15) and `inc_seen`. `call_lead` runs `on_call` (85%, a seeded `rng_for("incumbent", id*100+day)`), `_go` (a visit) runs `on_visit` (100%). The CRM summary prints `RIVAL: ...` (hidden until revealed).
- **ASSESS.** CRM button and key A, `SalesRival.assess(id)`: needs stage MEETING, one selling hour, reveals the incumbent, takes `Rival.assessment(incumbent)` (3-5 habit ids; implemented in `rival.gd`, in-house, none and Plumb Line use a generic small-office list) and asks HONEST LIST or IT LOOKS FINE. Honest: `assessed = "honest"`, touches H10, each finding is a FIX promise (+0.2 gap) in `Deals.promise_list`, win -3 points, the handover starts the client 6 mood higher with churn -8. Cheap: `assessed = "cheap"`, `lie`, conscience -2, win +3 points, promise gap +0.5. A lead with `story == "assess_bc"` (week 7) leads with R02, R04, R12.
- **Quote form.** `quote.present` is `itemized` / `flat` / `tiers` (`Deals.norm` keeps it, default itemized; `QuoteBuilder` row PRESENTED AS, `l.present_pref` sets the opening value). Win points: itemized -4 against a flat rival (ByteBrothers, Big Cheese) unless H2 is fresh; flat +3, margin -8 points, promise gap +0.5 (a `PRICING` promise); tiers +2 with H2 fresh, -2 as a guess without. `Deals.gauges` returns `rival` (`rival_price`: Big Cheese 85% of list flat, ByteBrothers 80%, Plumb Line 115%) and adds the Vic / Alan block lines (`form_blocks`). The gauge row RIVAL PRICE is hidden until the incumbent is known.
- **Lies.** shortcuts call `SalesRival.mark_lie(l, why)` (flag `lie`, conscience -2): the cheap assessment, matching the flat price (`sales_flat`), taking the laundered lead, badmouthing Rex back, undercutting Hollis. `close_deal` stamps the book entry (`SalesRival.stamp`: `lie`, `honest`, `incumbent`, `takeover`); `Handover.finish` applies `mood_adjust` / `churn_adjust` (lie +8, honest -8). `flags.lies` counts them; `review_lines` page 0 has a LIES line (`lies_line()`), `director_ok()` needs `conscience_ok()` (`Temptation.consc() > -3`).
- **Takeover.** Winning a Big Cheese client sets `deal.takeover`; with no ASSESS done two `INHERITED` promises (gap 0.3 each) show up in the handover, whose intro names Big Cheese. `capacity()` loses 0.2 per takeover deal for six weeks (`takeover_load`).
- **Beats** (`SalesRival.WEEKS`, called from `SalesCampaign._beat_cards` after `SalesBeats.week`, text in `BEAT_TEXT` keys `incumbent rex flat assess laundered plumb rumour audit scorecard`): w2 incumbent reveal, w3 Rex at the Chamber lunch (flag `rex`), w5 `sales_flat` (flags `flat`, `value_page`, lead `present_pref` / `pts`), w7 ASSESS on a Big Cheese client (Marlowe Family Dental), w9 `sales_laundered`, w11 Plumb Line mirror beat with Hollis Grady (flag `hollis_favour`), w13 rumour (lead `rumour {week, mod}`, -3 paper / +6 badmouth / -5 ignore, gone after 4 weeks, `counter_wk` card two weeks after a badmouth), w15 vendor-audit surge (three Big Cheese leads), w17 scorecard (`entry.scorecard` +0.06 renew chance, half without a value page or H2).
- Not done / for later: the rap sheet (`Owner.flags rap_*`) is not written by sales findings (they live on the lead); the Hollis favour is a flag only (no Mastermind consumer yet); strings.txt was synced with `story_export.gd -- --sync`, re-run it after merging the other agents' text.

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

## Takeover / inherited messes (P4, built: `scripts/takeover.gd`, hunks in `onsite.gd`, `playbook.gd`, `owner.gd`, `incident.gd`, `tests/takeover.gd`)

`Takeover.ENABLED` is true. No new art: text, cards and toasts only. All the new text lives in `takeover.gd` (so `tests/habits_text.gd` guards it).

- **Hand-off.** `fx visit "takeover"` -> `Takeover.visit` -> `target()`: the active client with the oldest `takeover_pending_<c>` flag and no visit yet, else `Rival.arc_client()` if active and not visited, else nothing. It erases the pending flag, creates the state `Owner.flags["tk_<c>"] = {found, acted, done}` (job ids), calls `begin(c, 6)` (inherit 90, R12 SEEN, career counter) and `Onsite.start_visit(c, "takeover")` (no site: a toast only).
- **Onsite.** Five small hunks: `_meeting_row` returns `Takeover.MEETING` (list of logins -> T2, how the backups work -> T1, a fresh start -> mood +4), `inspect` hands every object to `Takeover.on_inspect` (no dice: the object's preferred job, else the next hidden one), `_meeting_answer` -> `Takeover.meeting_answer`, `_go_home` -> `Takeover.finish_visit` (found x2 + acted, graded with `Playbook.grade_for`: start mood S+10 A+6 B+2 C-3 D-8 and a follow-up ticket for C/D; the toast reads "WHAT BIG CHEESE LEFT BEHIND: n ITEMS FOUND, m STILL OPEN").
- **A finding card** (`FINDINGS_TAKEOVER`, six, `T1`..`T6`, same shape as `Onsite.FINDINGS` plus `hours`, `drop`, `quick`, `service`): TAKE THE JOB (starts the Playbook book at that client; disabled while another job runs), PATCH IT NOW (owner hours, inherit -8, job stays open), SELL IT AS A PROJECT (`Projects.offer_project`, or the patching service for T4), MAKE A NOTE. Seeing a finding sets the rap SEEN (`Rival.set_rap("bigcheese", JOBS[id].rap, SEEN)`).
- **Playbook.** Six books `tk_backup tk_creds tk_firewall tk_dashboard tk_defaults tk_keys` (3-4 steps each; data in `Takeover.BOOKS` / `PROBLEMS`, installed into `Playbook.BOOKS` / `PROBLEMS` in a new `Playbook._ready`, so they are not in strings.txt). `Playbook.start(id, source, client := -1)` sets the book's client. `Playbook._outcome` hands `tk_*` to `Takeover.outcome`: a good job calls `fixed()` (inherit -15, job done), sets the rap PROVEN, touches the twin habit (`Habits.touch_if`); a bad one (flags in `OUTCOMES.<book>.bad`) adds risk (25 for the freezer bag, else 10) and leaves the rap at SEEN. Follow-up tickets per sloppy flag.
- **Risk.** `risk_mult(c) = 1 + inherit/200`; `worst_mult()` over served clients. Read by: `Incident.attempt_chance` (per client), `Owner._rdp_week` (chance x worst, victim may become the worst client via `Takeover.victim`, which draws nothing when nothing is inherited), `Owner._vendor_breach` (hit x worst), `Owner._ransom` (an open T1 gives `restore_fail` 0.6). With no inherited mess every one of these is exactly neutral.
- **Not done.** No prop art for the freezer bag; the "share a sanitized version in a forum thread" ask (conscience +1 / mood -6) is not built; the tech-campaign vignette for T1 is P6 work; outages and the Story-day ransom only use the T1 restore hook (no new per-client ransom roll).
