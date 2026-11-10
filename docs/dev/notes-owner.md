# Build notes: owner / sales / service business systems (agent `owner`, Nov 2026)

Rows: R38 (rival habits and good habits), R38 P3 / P4 open items, X11 (second cast in the owner campaign), R36 (owner and service
part), P5 owner leftovers (code only). No new art, no sound. Text is a first draft.

## 1. R38 audit: what of P1, P2, P5 was really built

Checked against `docs/scope-bad-habits.md` by reading the code and running the tests of each phase (all green before any change):
`rival`, `rival_arc`, `rival_touches`, `habits`, `habits_effects`, `habits_tables`, `habits_text`, `temptation`, `takeover`,
`sales_rival`, `sales_temptation`, `sales_shop`.

| Phase | State found | Evidence |
|---|---|---|
| P1 rival beats | built | `Rival.ARC` weeks 3-20, 20 `rival_*` cards, the four-option decision, the evidence channels (`intel`, `relabel`, `on_winback`, `defect_exit`), the vendor audit and the insurer questionnaire; `tests/rival_arc.gd` |
| P2 the 14 habits and their view | built | `Habits.HABITS` H1-H14, freshness, Standard, the HABITS tab (`habits_view.gd`), the pitch cards; `tests/habits*.gd` |
| P5 sales displacement | built | `sales_rival.gd`: incumbent, ASSESS, PRESENTED AS, lies and dated bills, nine beats; `tests/sales_rival.gd`, `sales_temptation.gd` |

So the roadmap's "next" for P1, P2 and P5 was stale: they are complete first versions. What was still missing, and what was done:

- **Built now:** H13 halves the blame of the wire fraud answer (`Habits.blame_mult()`, read in `Incident.owner_fx` "blame": rep, mood and the
  chance the client leaves are all x0.5 with the written go-ahead on file). An honest ASSESS list in the sales campaign now goes on the
  rival's rap sheet (`Rival.set_rap(incumbent, habit, SEEN)` in `SalesRival.assess_pick`).
- **Still not built** (small, listed in `rival-habits-api.md` as "not done"): H9's overnight job failure rate (it is a card only), H3 "a
  failed cutover costs half", the default password walk-around finding for H14, a TESTED date on the RMM backups tab, a consumer for
  the Hollis favour flag. `Habits.assess_win_adj()` stays unread on purpose: the sales code has its own `WIN_HONEST` (-3 points).

## 2. R38 P3 / P4 open items

### The skipped restore test is a real ransom (`temptation.gd`, `habits.gd`, `owner.gd`, test `tests/restore_skip.gd`)

- While the `temp_restore` entry is in Christy's folder, `Habits.restore_fail()` returns `Habits.SKIP_FAIL` (1.0): a restore fails for
  sure. `Habits.skipped_test()` is the query.
- **The bill.** `Temptation.bill` hands `temp_restore` to `Temptation.ransom_bill(owner, sk)`: an infection at one served client (the
  law firm when it is a client, else one drawn from the `skeleton` stream) through `Owner.ransom_at(client)`. The restore fails, so the
  player gets the six-option `ransom_options` card instead of the old flat $800. The client loses `BILLS.temp_restore.mood` (8).
  `Temptation.ransom_hit` takes the entry out of the folder (it counts as a paid skeleton) and queues Alan's lesson card
  `temp_restore_after` for the next morning (RUN A RESTORE TEST ON EVERY CLIENT NOW starts H1; CALL IT BAD LUCK costs conscience).
- **A ransom that comes while the entry is open** (the week 9 one if cards were moved, or any later `_ransom()`) fails the same way and is
  the bill: no second bill later.
- **A real test afterwards clears it.** `Habits.touch("H1")` calls `late_test()`: the entry leaves the folder with a toast and no bill.
  Starting H1 on paper (`start`) is not a test.
- Giving the files up on this ransom costs the usual reputation, but brings no lawsuit card on top (`Owner._ransom_skip`).
- **Cozy** keeps the flat, halved bill (no ransom). No client or no free server: the flat bill as before.
- Owner plumbing: `_ransom(client := Story.RANSOM_CLIENT) -> bool`, `_ransom_untested`, `_ransom_story` (the old body, unchanged), `_ransom_card(id)`
  (a copy of `ransom_options` / `ransom_lost` with the client's name, the mood target and the reason put right when the client is not
  the law firm or the backup looked fine), `_ransom_client`, `_ransom_forced`. `Story.flags.ransom` is only written for the law firm.
- Fixed on the way: ACCEPT THE LOSS on a ransom whose backup was "working" but would not restore (stale H1, an inherited freezer bag)
  used to run the real restore, which succeeded. It now records the loss.

### The sales intro-rate temptation (`sales_rival.gd`, text `SalesCampaign.BEAT_TEXT.intro`, test `tests/sales_intro.gd`)

Week 12 (`SalesRival.WEEKS[12] = "intro"`), the sales twin of the owner's vendor switch, from the other side of the table. The best
quoted lead (else the best open one) would sign today for a cheap first quarter:

| Option (id) | Effect |
|---|---|
| INTRO RATE, THE STEP ON PAGE ONE (`pageone`, first) | honest: win +3 points (`INTRO_PTS`), conscience +1 |
| INTRO RATE, PRICE IN THE SMALL PRINT (`smallprint`) | a quoted deal closes now at the full fee; `mark_lie(..., "intro")`: conscience -2, a dated bill |
| HOLD THE LIST PRICE (`hold`) | one selling hour, win +2 points (`HOLD_PTS`) |

`BILLS.intro`: 3-5 weeks later the intro rate ends: client mood -10, churn +10, reputation -1, the commission clawed back x2.0. A lead
that is not quoted yet gets +8 points (`INTRO_FAST`) instead of the instant close. COME CLEAN and Summit's diligence count it like the
other sales entries. `tests/sales_balance.gd`: the `shady` strategy takes `smallprint`; the other bots take the first (honest) option.

## 3. X11: the second cast in the owner campaign

### Jen's and Michael's cards (`scripts/owner_cast.gd`, test `tests/second_cast.gd`)

`OwnerCast.CARDS` / `DAYS` (static tables, patchable as `OwnerCast.CARDS`), merged into `Owner.CARDS` in `Owner._ready()` and into the weeks
in `Owner.events_on()`, the same way as `RivalCards`. Owner campaign only.

| Card | Week, time | Options (effects) |
|---|---|---|
| `jen_phones` | 4, 15.5 | overflow rings the techs (mood +2 all, speed -0.03) / a part-time second voice ($110 a week, mood +3, rep +1) / voicemail (mood -2) |
| `jen_intake` | 9, 12.0 | three questions on every call (speed +0.05, mood -1) / and she books the visits ($200, speed +0.08, 1 h) / straight through (mood +1, speed -0.03) |
| `jen_wall` | 14, 13.5 | be the wall (burnout -6, mood -1) / keep taking the calls (burnout +5, mood +2, 2 h) / a direct line to Jen ($60, burnout -3, mood +1) |
| `michael_catch` | 6, 14.2 | keep catching (speed +0.05, burnout +5) / cap the hand-offs (speed -0.02, burnout -3, team +1) / make it his job (payroll +$100, speed +0.07) |
| `michael_teach` | 12, 14.8 | Friday hour ($150, speed +0.06, mood -1, team +1) / write it down (2 h, touches H11, speed +0.02) / no time (team -1) |
| `michael_offer` | 17, 13.0 | match it (payroll +$150, burnout -2) / the no-hire clause (mood -2, rep -1, team -1) / lend him out one day ($180 a week in, speed -0.04) |

Most options carry `trust {Alan, Garrison}` (the other owner's opinion, +1 / -1), so the cards show the TRUST UP / DOWN chips.

### Old saves with the old names (`scripts/save_migrate.gd`, one line in `Campaign.continue_game`)

`SaveMigrate.names(cfg)` runs right after a save (or a resume point) is read: every dictionary key, array entry and string value that is
exactly an old name is mapped (the old account manager -> John, the old bookkeeper -> Christy, their speaker labels and `office_*`
character ids), in place, in every section. Sentences that mention the old names (old messages) are left alone. The old names are
written split in the code so a rename script cannot touch them. Tested for the owner, sales and service saves (`tests/second_cast.gd`).

## 4. R36, owner and service part (`scripts/byname.gd`, test `tests/byname.gd`)

### Service campaign (state `Service.flags.bn`, saved)

- Every ticket a tech closes at a client counts for him there (`ByName.on_done`, called from `Service._finish`).
- From `ASK_MIN` 3 closes the client knows his name (`favourite(client)`: the most closes). A new ordinary ticket from that client, mood
  `ASK_MOOD` 60+, at most every `ASK_GAP` 2 days, asks for him with `ASK_CHANCE` 0.3 (stream `service.byname`): `t.asked_tech`, a ticket
  note, a toast (`ByName.on_ticket`, connected to `Msp.ticket_added` in `Service._ready`).
- **Lopsided crew.** `Service.route_for` asks `ByName.route(t)` first: the asked tech takes it even over the usual two-ticket limit, up
  to `ASK_LOAD` 4 on his desk, so he overloads while the others idle. You can move it by hand.
- He closes it: client mood +2, his morale +1. Somebody else closes it: client mood -2.
- **A tech who quits** (`Service.release_all` -> `ByName.on_quit`): every client where he had `FOLLOW_MIN` 4 closes and nobody had more
  loses `FOLLOW_MOOD` 8 mood (4 on cozy), his open requests become ordinary tickets, and Jen tells you who called for him.
- **Capacity tab** (`dispatch.gd`): each tech row shows `ASK n` (open requests) or `FAN n` (clients that know him); the bottom note
  names the clients of the selected tech ("ACME AND BRSD ASK FOR MAYA BY NAME", narrow: "FANS: ACME BRSD"). In `layout_audit.gd`.

### Owner campaign (state `Owner.flags.bn`, saved)

The owner's crew is abstract (no per-ticket assignment), so a client simply has a favourite among the two employees.

- `ByName.owner_week(owner)` (from `Owner.settle`, owner campaign): from week 3, with `OWNER_CHANCE` 0.4 a week one happy client (mood
  65+) starts asking for a tech, 70% of the time the tech who already has the most (stream `owner.byname`, three draws every week).
- The weekly report gets a row ASKED FOR BY NAME ("DAN 3, MAYA 1").
- **Lopsided:** at `LOPSIDED` 3 favourites on one tech Morgan raises it (once: after LET THEM or PAIR she does not ask again; after
  ROTATE at most every 6 weeks): LET THEM (those clients +3 mood,
  burnout +5, speed -0.03, then +1 burnout a week while it lasts) / ROTATE (2 h, those clients -3 mood, all but one favourite cleared,
  speed +0.02) / PAIR THE TECHS ($300: those clients are "shared" and will not follow him out).
- **Losing the tech is a real risk.** The poaching card (`_key_poach`) now ends with "3 clients ask for Dan by name." When a tech has
  left (`lost_techs` went up), each client that asked for him and was never shared wants to follow with `FOLLOW_CHANCE` 0.6: the first
  brings the non-solicit card (the letter $400: 60% they stay at mood -8, else they leave and rep -1; a visit, 3 h: 60% stay at +3;
  let them go), further ones only sulk (-6). Cozy: a small mood dip, nobody leaves.

## 5. P5 owner leftovers

- **`Projects.TYPES` is patchable:** `const DEFAULT_TYPES` + `var TYPES`, `Strings.ROOTS.Projects = ["TYPES"]` (labels and blurbs).
  `tests/projects_types.gd` patches a line and checks the game uses it (also for `OwnerCast.CARDS`).
- **Bot balance run for the newer owner content** (`tests/bot_lib.gd`, `tests/bot_run.gd`): the owner bot has a fourth strategy,
  `shortcut` (careful's answers with every temptation taken and the flat price matched). `careful` now answers the temptations
  honestly (before, every bot took option 0, which is the shortcut) and has picks for Jen's and Michael's cards and the two by-name
  cards. The BOT line reports folder, conscience, habits, takeovers, cast cards seen, by-name favourites and followers.
  `bot_run.gd -- owner normal careful,shortcut seeds=3 ts=4` prints a CHECK line and FAILS when the shortcut owner's mean value is
  not under 80% of the careful one's (`SHORTCUT_MAX`) or when he is fired every time. Numbers: see below.

## Balance numbers

See the end of this file ("Bot runs as measured").

## Decisions made

- P1 / P2 / P5 were found built; the work went into the listed gaps instead of rebuilding them.
- The skipped restore is certain to fail (1.0), not 15%: the row asks for a restore that "really fails", and a certain consequence
  teaches better than a roll. The 15% stays for a habit that was started and went stale.
- The ransom is the bill (no cash on top); cozy keeps the flat halved bill; a later real test clears the entry for free.
- The sales intro rate is a week 12 beat; the honest answer is the first option so the stock bots do not start lying.
- Jen's and Michael's cards live in their own file (`owner_cast.gd`), not in `owner.gd`, to keep that file and its merges small.
  Nobody leaves the office in any of them (Michael is lent out, not lost), because he still sits in the cubicle row.
- Old saves are migrated when they are read (one pass over the whole file), not per system.
- By-name in the owner campaign uses favourites per client, because that campaign has no per-ticket assignment. A tech named in the
  poaching card is the one who leaves for the by-name rules (the roster elsewhere still drops the last employee, as before).
- The service campaign has no client churn, so a follower costs mood there, not the client.
- `Projects.SERVICES` was left a constant (the row names `TYPES` only).

## Art I would want (none was drawn)

- A phone or headset prop on Jen's desk for the phones card, a whiteboard with the week on it (the visit board).
- A small "asked for" star on a Dispatch ticket chip.

## After merging

- Run `story_export.gd -- --sync --doc` once (this branch added `OwnerCast.CARDS`, `Projects.TYPES`, `RivalCards.CARDS.temp_restore_after`
  and `SalesCampaign.BEAT_TEXT.intro` to `story/strings.txt` and `STORY.md`; other branches will touch the same files).
- `docs/balance-notes.md` owner rows for `careful` are older than the bot's honest temptation answers.

## Bot runs as measured

`Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_run.gd -- owner normal careful,shortcut seeds=3 ts=4` (final code;
runs are not bit-for-bit repeatable, judge by the shape):

| Strategy | Seed 1 | Seed 2 | Seed 3 | Mean value | Fired |
|---|---|---|---|---|---|
| careful (honest answers) | $479k, rep 54, cash $4.6k | $613k, rep 87, cash $8.6k | $895k, rep 96, cash $16.8k | $662k | 0 of 3 |
| shortcut (every temptation taken) | $210k, rep 87, cash $8.0k | $146k, rep 88, cash $4.3k | $399k, rep 84, cash $8.1k | $252k | 0 of 3 |

The shortcut owner ends at 38% of the careful one's value, with a folder entry still open, conscience -10 to -11, 8-9 clients
against 11, and is not fired. All six of Jen's and Michael's cards were seen in every run, 5 to 8 clients had a favourite tech by
week 20, no takeover visit happened in these seeds (the arc client did not come back). The careful cell was measured one code step
before the shortcut cell (between them only the shortcut bot's draw and trip answers changed, which the careful bot already had).

What went wrong on the way, and the fixes:
- The first runs had the shortcut owner fired 2 of 3 times in week 15 with the bank at about -$4k (bankruptcy is -$3,000). Cause: the
  new `shortcut` bot did not share the careful bot's two prudent answers (skip the draw when the bank is thin, stay home from the trip
  under $3,000), so it paid full draws into the week the seat audit lands. With those two answers shared, nobody is fired.
- One traced run lost $6,000 to the lawsuit card after the skipped-test ransom (a broke owner can only try the shadow copies, then
  cannot settle, so FIGHT IT is forced). The skipped-test ransom now brings no lawsuit on top (`Owner._ransom_skip`): the lost files,
  the reputation and the hurt client are the bill.
- The lopsided-crew card came back every six weeks and its default answer stacked burnout and lost speed. After LET THEM or PAIR,
  Morgan does not raise it again; only ROTATE leaves the question open.
- A copy of the ransom card read "Hoot and Holler Law Law's" (the name was substituted twice). Fixed and tested.

Earlier in the work (code before the R36 and X11 parts), `owner_balance.gd` at natural time: shortcuts $190k / $111k against smart
$793k / $922k (seeds 1 and 2), nobody fired.

Baseline cells after the by-name and intro-rate work (against `docs/dev/balance_baseline.json`): service normal careful seed 11 rep 91
score 84 (baseline 100 / 91), service normal lazy seed 11 rep 51 score 62 (51 / 62), sales normal careful seeds 11 and 12 rep 75 / 90
score 148 / 135 (the same as the baseline). All inside the tool's tolerance (rep within 20, score within 35%).
