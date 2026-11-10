# Build notes: balance by bot (rows Q6, R1, P6, T2, X7, X9, C7, R10, P5 / R38 leftovers)

Branch `worktree-agent-a52dd6dc9c482ce26`, Nov 2026. Every row that asked for a hand-played pass is closed here with bot runs and
scripted checks. The tables are in `docs/balance-notes.md` (section "Nov 2026: the balance pass"); this file says what was built,
what was changed in the game, and how to run it again.

## 1. The same seed gave different games (Q6)

`tech hard careful seed 11` swung between reputation 12 and 73 from run to run. Four separate causes, found with a per-frame
state trace (`tests/bot_det.gd`: run it twice and diff the logs; the first differing line names the frame and the value).

| # | Cause | Where | Fix |
|---|---|---|---|
| 1 | **A boot-time random value survived into the seeded run.** `World._ready` drew the timer of the first office meeting from `Difficulty.rng("world.meeting")` while the run seed was still the random one of the boot; `Campaign.new_game` never drew it again. The meeting came at a different moment in every process, its `shuffle()` moved the global generator, and everything after it (cards, calls, who is at a desk) differed. On hard, where one ticket moves the reputation, that was the 12-to-73 swing. | game (`world.gd`) | `World.new_run()` (called by `Campaign.new_game` right after `Difficulty.new_run()`) draws the timer again from the run's seed and clears the chat pairs. |
| 2 | **The bot's speed depended on the time scale.** Every change of step in the tech bot (busy, fix, pick the next ticket) cost a whole frame: about four frames a ticket, 1.3 game seconds at ts=20 but 8 at ts=120 against a 28 s handling time. The same seed was a harder game the faster it ran: 82 / 73 / 53 at ts 20 / 60 / 120. | bot (`bot_lib.gd`) | `_tech_tick` hands the unused part of a frame to the next step (`_tech_step` returns it). Now 85 / 77 / 79. |
| 3 | **A run depended on what ran before it in the same process.** The first run of a process played day 1 with no scene loaded (nobody in the office had a body), a later run inherited the floor, the open card and the stopped clock of the run before; a caller that came from a timer started half a frame late. | bot (`bot_lib.gd`) | `play()` starts every run from a clean slate (`_clean_slate`: waiting cards answered and dropped, Playbook reset, clock running), on a freshly loaded `main_floor` scene, at the same point of a frame. |

| 4 | **Bodies of the day before kept talking.** `World.begin_next_day` (every new day and every new game) set `_leaving` on each cast member's body and forgot it, but the body stayed in the scene and went on with its old routine. When that ran out it called `World.leg_done` for its person, and the new plan of that person was thrown away. In a bot run the bodies came from before the seed (boot-time routines), so the moment was different in every process: the shortcut owner of seed 2 ended at $24k, $44k, $77k, $137k, $330k and $342k (and fired once) on the same code. In the real game the scene is replaced a moment after a day starts, so the window is a few frames, but it is the same bug. | game (`npc.gd`, `world.gd`) | A leaving body no longer calls `World.leg_done` or `World.leg_exit`, and `begin_next_day` frees the bodies it lets go of. |

After 1 to 4 every campaign repeats exactly: the same seed gives the same BOT line in two processes and twice in one process
(`tests/determinism.gd` for tech and sales; the owner shortcut cell of seed 2, played as the second run of a process, gave
$300,256 in both of two processes after the fix).

`tests/t2.gd` had the same flaw in small: it seeded the global generator but not the run, so "seed 4242" was a new ticket
stream every time. It pins the run seed now.

## 2. Bots (`godot/tests/bot_lib.gd`)

New or changed, all in the shared driver:
- **`mixed`** (tech, service): careful on even days, lazy on odd ones.
- **Scripts** (X7): from POWERSHELL 2 the careful and proper bots run `Msp.rmm_bulk` (SCRIPT: THIS CLIENT, level 4: ALL CLIENTS)
  as soon as two open tickets want the same fix. `use_scripts = false` gives the bot of before.
- **Backup watch** (X7): without SECURITY 3 the careful bot pays 20 s for the daily backup check, with it 5 s per failed job.
- **Ransom exits** (P6): `RANSOM_PLANS` (careful: restore, vendor, insurer, shadow, rebuild; lazy: restore, shadow, pay; chaotic:
  pay). Before, every bot tried the restore and one free shadow-copy roll and then left the ticket. `ransom_order` overrides it.
- **`heavy`** (tech): the proper bot that takes the heavy fix wherever one exists (with the hard tier's fail and slow dials).
- **`takeover`** (owner, R38): the smart owner who lets the week 7 client go with an exit chat, takes them back in week 11
  with a takeover assessment and walks the site (`ow_takeover_walk`: the meeting, every object, a Playbook job per finding).
- **Year 2 chain** (R10): `play_year2(mode, tier, strat, seed)` plays year 1, finishes it through `Campaign.finish_campaign`
  (so the real meta record exists) and plays Year 2 on it. `bot_run.gd ... year2` prints a `Y1` line and the Year 2 `BOT` line.
  (The `year` field that main added starts Year 2 or 3 from a made-up record; both work.)
- **Service lessons** (C7): the careful manager answers a runbook lesson's check with the safe first step (it used to take
  the first option, failed 25 times a run and never trained anybody).
- **Owner, a thin bank** (Q6): when a client was scammed (`bec_loss`) the careful owner credits 40% of the loss only with
  $5,000 in the bank (`OW_CREDIT_CASH`); under that the lawyer answers ($600) or the insurer is asked. The 40% is $2,000
  and more and the card names no price: it bankrupted the careful owner in week 15 on hard.
- **A clean career per run**: `Career.reset_all()` and `Outings.known = {}` in `_clean_slate` (not inside a Year 2 chain).
  The career outlives a campaign on purpose; in a bot cell the fifth seed played with the medals and mastery of the four before.
- **Card log**: every card a bot answers is in `row.cards` (`{day, clock, who, text, pick, n}`), the owner run also returns
  `row.weeks` (cash, reputation, partner trust, value, clients, cards per week).
- `stop_day` (tech: stop after a day), `frame_hook` (a per-frame callback), `tech_stats` (work seconds, failed fixes, heavy,
  scripted, the ransom exits tried).

Tools: `bot_run.gd` (words `mixed`, `heavy`, `takeover`, `year2`), `bot_trace.gd` (the per-day trace and its FLAG lines),
`bot_det.gd` (the per-frame trace; `twice`, `before=`, `stop=`, `chars`, `every=`).

## 3. Game changes

| Change | Before | After | Why |
|---|---|---|---|
| `World.new_run()` | the meeting timer kept its boot-time value | drawn from the run seed at every new game | section 1 |
| `Campaign` clean-day rule (tech campaign, normal tier; `CLEAN_REP` 58, `CLEAN_PER` 6, `SLOPPY_REP` 62, `SLOPPY_PER` 3, `SLOPPY_MAX` 10; `Difficulty` key `tech.clean` 0 / 1 / 0) | the day report added `2 x closed - 3 x missed - 2 x reopened - open`, capped: on a busy day the closes always outweighed the misses, so a half-hearted day still earned the cap | from reputation 58 a day with more loose ends (SLAs missed, reopens, plain tickets left in the queue) than one per six closes adds nothing; from 62 it costs 3 a loose end too many, at most 10. The report says so (`SLOPPY_NOTE`, `SLOPPY_NOTE_LOSS`) | T2: mixed play ended at 88 to 97 |
| `Msp.loose_open()` | (new) | the open tickets that count as loose ends: not the install project, not network, onsite or story jobs, not tickets already counted as missed | T2 |
| Leaving bodies (`npc.gd`, `World.begin_next_day`) | a body the World had let go of stayed in the scene, ran its old routine to the end and then replaced its person's new plan (`World.leg_done`), or took the person out of the building (`leg_exit`) | a leaving body calls neither, and `begin_next_day` frees the bodies it lets go of | section 1, cause 4 |
| `Msp.supersede(endpoint)` | when the ransomware (or a forced story job) took over a server that already had a ticket, that ticket could never be fixed again: its machine no longer had its problem. A P1 "server not responding" sat open and breached for the rest of the campaign | the displaced ticket counts as done and only wants closing | found by the bot (seed 5: 12 days with the same open P1) |

`Difficulty.TABLE` hard values: **none changed** (see the hard cells in `docs/balance-notes.md`).
The easy and hard tiers do not have the clean-day rule: cozy easy ignores misses anyway, and on hard the short clocks make
misses routine (`tech.loss` 2.2 prices them there).

## 4. Tests

| Test | What it proves |
|---|---|
| `tests/determinism.gd` (about 1 minute) | tech hard careful seed 11, days 1 to 4, twice in one process with the office running in between: same row; another seed: another row; a whole sales campaign twice: same row |
| `tests/npc_leaving.gd` | a new day frees the bodies of the day before; a leaving body that finishes its routine or reaches its exit step does not touch its person's plan |
| `tests/seeds.gd` (extended) | tier x seed: on easy, normal and hard a pinned seed starts the same tech run twice (fleet, mutator plan, first tickets, meeting timer), another seed another one; the fleet of a seed is the same on every tier; `World.new_run` draws the timer from the seed |
| `tests/clean_day.gd` | the clean-day arithmetic, the report at reputation 54 / 58 / 72 / 90, clean and quiet days, hard / easy / service untouched, the note in the report, `Msp.loose_open`, the displaced server ticket |
| `tests/stat_effects.gd` (about 2 minutes) | X7: each of the five tech stats at 4 changes the first 8 days on hard against the flat build; the four presets give at least three different outcomes |
| `tests/ransom_exits.gd` (about 1 minute) | P6: seven exit policies on 150 seeded runs each; the asserts listed in the file |
| `tests/t2.gd` | mixed play ends at 55 to 75 (was 55 to 86); `-- curve seeds=5 tier=hard` prints the curves per seed |
| `tests/tiers_balance.gd` | + tech normal mixed lands between careful and lazy; on easy a tie of careful and lazy is allowed |
| `tests/layout_audit.gd` | + every page of the year-end Review for tech, owner, sales and service in wide, h and v; the day report with the sloppy-day note |
| `tests/difficulty.gd` | the new key `tech.clean` at its normal value |

## 5. Decisions made
- **Mixed = careful on even days, lazy on odd days.** The lazy half still does honest work (slow, first come first served, no
  study, no backups). `tests/t2.gd` keeps its own harsher "mixed" (odd days: P3s closed unfixed, P1s left to run out).
- **The clean-day rule is on at normal only.** Applying it on hard froze the careful bot at 58 (it misses four clocks a day
  there by design).
- **The sloppy day's cost grows with the mess** (3 a loose end over the allowance, at most 10) instead of a flat number: one
  slip on a busy day costs nothing, a day of leftovers costs a lot.
- **A displaced ticket is marked done, not deleted**: the player still closes it and reads the note.
- **Tech tables at ts=60, the smoke test at ts=120.** With the time-exact bot the two agree within a few points.
- **Year 2 from a real year 1** (same bot, same tier), not from a made-up record, so the carry-over is the one a player gets.
