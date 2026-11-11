# Balance notes (Q6): bots, tiers and the alt-fix economy

How the numbers were checked and what they came out as. Re-run after any change to a tier table, the ticket pace, the SLA windows or the campaign
reputation maths. Counts are small (3-5 seeds a cell, the machine was shared), so read them as "which side of the line", not as percentages.

**The current numbers are in the last section, "Nov 2026: the balance pass without a human".** The sections before it are
kept as history: they were measured before the same seed gave the same game.

## The tools
| File | What it does |
|---|---|
| `godot/tests/bot_lib.gd` | The shared bot driver. `play(mode, tier, strategy, seed)` plays one campaign to the end in compressed time and returns `{rep, score, ending, cls, fired, info}`. `cls` is `good` / `mid` / `bad` (good = the top ending: tech team lead, sales director, service ops manager / side-with-an-owner, owner rep 60+ with the goal met; bad = fired or reputation under 45). |
| `godot/tests/bot_run.gd` | The slow harness, one or more cells per process: `-- tech easy,normal,hard careful,lazy,chaotic seeds=4 ts=60`. Words are modes (tech owner sales service), tiers, strategies (careful lazy chaotic, plus the tech-only `proper` and `shortcut`); prints a `BOT` line per run and a `CELL` summary per mode x tier x strategy. Run one tier or strategy per process and in the background: a tech run is about 40 s, a service run 20 s, sales 6 s, owner (ts=4) 2-3 minutes. Owner needs `ts=4` or less (at ts=8 even careful play goes bankrupt in week 17: the weekly cards and the team simulation are tuned for the real clock). |
| `godot/tests/bot_novelty.gd` | The novelty timeline (about 1 minute): `-- strategy=careful seed=1 ts=20`. Plays the tech campaign and prints when each kind of thing first shows up (card speakers, story tickets, texts, mail) in play minutes (a tech day is 10 minutes), the new / cards / tickets / texts per day, and the longest stretch with nothing new. Use it to find lulls and to see how fast systems arrive; it measures arrival, not whether it is fun. |
| `godot/tests/tiers_balance.gd` | The smoke test (about 5 minutes): sales, tech and service with a careful and a lazy bot on each tier; asserts careful easy >= normal >= hard (rep and good endings), careful > lazy on every tier, and that the new dials read normal outside a campaign. Owner is left to `bot_run.gd`. |
| `owner_balance.gd`, `sales_balance.gd`, `service_balance.gd` | The older per-mode harnesses (natural time, one strategy per process). The bots were ported from them; they still work. |

Strategies: **careful** (tech: studies a lesson a day, reruns the backups, works tickets by priority and SLA, uses clever fixes, runs the playbooks and the install project by the best choice, takes protected time; owner = `smart`; sales = `careful`; service = `careful`), **lazy** (tech: no study, no backups, first come first served, long gaps between tickets, first card option; owner = `cheap`; sales = `lazy`; service = `lazy`), **chaotic** (tech: random ticket order, half the fixes wrong, most closes unfixed, random cards; owner = `greedy`; sales = `pushy`; service = `chaotic`). `proper` is careful without clever fixes and `shortcut` always takes the quick workaround; they exist for the alt-fix check.
The tech bot spends 28 s of overhead on every ticket (reading, switching windows, closing) so it is slower than a perfect player.

## What the tiers change (`Difficulty.TABLE`, read through `Difficulty.cf()` / `cm()` only while a campaign runs)
| Key | Easy | Normal | Hard | Where |
|---|---|---|---|---|
| `tech.pace` (random-ticket interval x, tech campaign) | 1.25 | 1.0 | 0.45 | `Msp._process` |
| `tech.sla` (SLA window x, tech) | 1.3 | 1.0 | 0.4 | `Mutators.sla` |
| `tech.gain` / `tech.loss` (day report reputation move x, tech) | 1.25 / 0.75 | 1 / 1 | 0.4 / 2.2 | `Campaign._tier_rep` |
| `crew.pace`, `crew.sla` (owner, sales, service) | 1.1, 1.15 | 1, 1 | 0.8, 0.85 | same places |
| `rep.gain` / `rep.loss` (owner, sales, service) | 1.2 / 0.75 | 1 / 1 | 0.8 / 1.3 | `Campaign._tier_rep` |
| `tech.drain` (energy drain x, tech) | 0.9 | 1.0 | 2.0 | `Shift._process` |
| `tech.pair` (chance a second ticket lands when a P1/P2 is open at a spawn, tech) | 0 | 0 | 0.7 | `Msp._process` |
| `tech.alt_ret` (x the chance a quick workaround comes back) | 0.8 | 1.0 | 1.3 | `Msp._alt_fix` |
| `owner.cost` (weekly overhead x) | 0.95 | 1.0 | 1.03 | `Owner.weekly_estimate` |
| `sales.lead` (added to a new lead's quality; the quota x0.8 / 1.0 / 1.2 and rival price x already existed) | +5 | 0 | -5 | `SalesCampaign` lead roll |
| `service.trust` (x on the trust an owner loses) | 0.7 | 1.0 | 1.6 | `Service.add_trust` |

Normal is unchanged (`tests/difficulty.gd` lists every key at its normal value; outside a campaign `cf()` returns the normal number whatever the tier). Free Play and the old tests are unaffected.

## Results (reputation 0-100; good / mid / bad endings out of n)
Final table of the last runs of each cell. See "Open" for the cells with fewer seeds.

| Mode | Strategy | Easy | Normal | Hard |
|---|---|---|---|---|
| Tech (n=4; hard n=8) | careful | 4 good, rep 100 | 4 good, rep 100 | 4 good 2 mid 2 fired of 8, rep 44 avg (was 4 of 4 good, rep 88) |
| | lazy | 2 good 1 mid 1 bad, rep 57 | 4 bad (fired or near), rep 3 | 4 bad, fired |
| | chaotic | 3 bad, fired | 4 bad, fired | 4 bad, fired |
| Owner (n=2-3, hard n=5, ts=4) | careful | 2 good, rep 93 | 2 good, rep 86 | 4 good 1 mid of 5, rep 72 (58-83) |
| | lazy | 1 good 1 mid, rep 62 | 1 mid 1 bad (fired week 9), rep 28 | fired week 16 |
| | chaotic | 2 mid, rep 58 (rich, moody) | 1 mid 1 bad, rep 39 (rich but unloved) | 1 fired week 12, 1 bad rep 11 |
| Sales (n=4) | careful | 4 good, rep 100 | 3 good 1 mid, rep 90 | 2 good 2 bad, rep 76 |
| | lazy | 4 bad (let go), rep 35, nobody fired | 4 bad, rep 24 | 4 bad, rep 5 |
| | chaotic | 4 bad, fired | 4 bad, fired | 4 bad, fired |
| Service (n=3) | careful | 3 good, rep 100 | 3 good, rep 96 | 3 good, rep 74 |
| | lazy | 2 good 1 bad, rep 61 | 2 mid 1 bad, rep 45 | 3 bad, rep 25 |
| | chaotic | 1 good 2 mid, rep 57 | 4 bad, rep 11 (n=4) | 4 bad, fired (n=4, earlier tier values) |

Against the targets: normal careful reaches a good ending in 11 of 12 seeds (one sales mid); normal lazy ends mid or bad everywhere (tech and sales all bad); chaotic fails everywhere except the owner greed run, which makes money and loses the name (mid/bad). Easy careful is 100% good and easy lazy survives (one tech seed and one service seed still reached a good ending, one service seed was a bad one). Hard careful wins in tech (4 of 4, rep 88), service (3 of 3, rep 74), about half of sales (2 of 4) and the one owner seed after softening; hard lazy fails in all four modes. The smoke test (`tiers_balance.gd`, seeds 11-12) passes: rep easy >= normal >= hard for careful in sales, tech and service, careful > lazy on every tier.

## Alt fixes (item 4): are the quick workarounds worth it?
`shortcut` = the quick workaround whenever one exists, `proper` = the real fix, `careful` = proper plus the clever fix when its skill is unlocked. Normal tier, 3 seeds, tech campaign:

| Strategy | Quick fixes | Returns (came back) | SLA misses | Score | Reputation |
|---|---|---|---|---|---|
| careful (clever where unlocked) | 0 | 0 | 0-1 | 1811 | 100 |
| proper | 0 | 0 | 0-1 | 1699 | 100 |
| shortcut | 224 | 104-120 (about 50%) | 10-18 | 1522 | 95-100 |

Before the change below the shortcut bot scored MORE than the careful one (2420 against 1722): every returned workaround came back as a fresh ticket worth +10 points and +2 reputation when closed, so overusing the quick fix farmed both. Now a returned ticket is rework: `Msp.spawn_return` flags it `repeat`, drops the client's mood by `RETURN_MOOD` (3) and closing it earns `REPEAT_POINTS` (2) and does not count as a closed ticket for the day's reputation. Result: the quick fix stays the fastest (0.3-0.6x the time, `mult`) so it is still tempting when the queue is long, but used on everything it costs about 10-15% of the score, a dozen SLA misses and a few points of reputation. The `ret` chances (35-60%) and `mult` values in `Msp.ALT_DEFS` were left alone: with the rework rule they are in a good place. On hard the return chance is x1.3 (`tech.alt_ret`).

## Tech hard pressure (Q6b)
Tech hard was too easy (careful bot: team lead offer on every seed, rep 88) because shrinking gains only lowers the top. Added two tech-only dials, both normal-neutral: `tech.drain` (energy drains 2x on hard, so fixes slow and fail more late in a day) and `tech.pair` (0.7: when a random ticket spawns and a P1 or P2 is already open, a second ticket lands at once; uses its own `msp.pair` stream and only draws on hard, so normal seeds are unchanged). Also `tech.sla` 0.5 -> 0.4 and `tech.loss` 1.8 -> 2.2. Careful bot at hard, ts=60, seeds 1-8:

| Setting | Good (team lead) | Mid | Fired / bad | Rep |
|---|---|---|---|---|
| before (pace 0.45, sla 0.5, loss 1.8) | 4 of 4 | 0 | 0 | 88 |
| pair 0.35, drain 1.5 | 5 of 6 | 0 | 0 | 71-91 |
| pair 0.7, drain 2, sla 0.45, loss 1.8 | 6 of 6 | 0 | 0 | 63-83 |
| loss 2.4, gain 0.35, sla 0.4 | 2 of 6 | 0 | 4 | cliff: fired by day 8 |
| loss 2.0, gain 0.4, sla 0.4 | 7 of 8 | 0 | 1 | 27-77 |
| **final: loss 2.2** | **4 of 8** | 2 | 2 fired | 0-75 |

The outcome is bimodal: a bad opening week (rep under 30) snowballs because every missed SLA costs 2.2x. Lazy and chaotic were already failing at hard and only get worse. `tiers_balance.gd` now asserts tech careful hard rep < normal rep.

## Open
- Tech hard: the careful bot (28 s overhead per ticket) is a bit slower than a good human, so a human should land at or above the bot's half. If hard feels brutal, lower `tech.loss` toward 2.0 (7 of 8 good).
- Owner hard (5 seeds, careful): `owner.cost` 1.03 and pace 0.9 give 4 good (rep 72-83) and 1 mid (rep 58, goal missed). That matches "most seeds, not all", so no retune. Value per seed varies a lot ($69k-$462k): judge owner by reputation.
- Owner lazy and greedy runs on normal were 2 seeds each; owner chaotic easy/hard (2 seeds each) and service chaotic easy (3 seeds) are now run (table above).
- The tech lazy bot is a calibration, not a measurement: its idle gap (55 s) decides whether normal lazy drifts (gap 25-40 s gave good endings in half the seeds, 55 s gives fired or rep under 15). Change `TECH_IDLE` in `bot_lib.gd` and the normal-lazy cell moves a lot; the careful bot's 28 s overhead matters the same way.
- Time compression: the tech bot runs at ts=60 (one frame is one game second); at ts=30 the numbers were the same within noise. Owner at ts=8 is not valid (see above).
- The machine was shared: a full matrix (4 modes x 3 tiers x 3 strategies x 4 seeds, about 2 hours of CPU) took many hours of wall time. Run cells as separate processes.

## Recent additions check (Q6c: P5, P6, R12)
Checked with the bots after P5 (Rodent Nation cards, projects `voip` and `email_move`), P6 (heavy fixes in person, new ransomware exits) and R12 (chair race). `tiers_balance.gd` passes (failures=0, seeds 11-12): careful rep easy >= normal >= hard for sales, tech and service, careful > lazy on every tier (tech 100/100/31 vs 36/0/0, service 100/100/89 vs 69/51/35).

**Owner, careful bot, ts=4** (the `smart` policy now declines the vendor lock-ins: `rn_invite` = send the tech, the three booths = take the brochure; `OW_POLICIES` in `bot_lib.gd`; the older bot took pick 0 everywhere, i.e. went and signed every booth):

| Run | Easy | Normal | Hard |
|---|---|---|---|
| old bot, seeds 1-3 | 3 good, rep 100 | 2 good 1 fired (week 10, bankrupt), rep 56 | 2 good 1 fired (week 19), rep 57 |
| old bot, seeds 4-8 | | 5 good, rep 94 | 4 good 1 fired (week 15), rep 69 |
| new bot, seeds 4-8 | | 5 good, rep 87 | 4 good 1 fired (week 14), rep 70 |

Ordering holds (easy 100 > normal 80-94 > hard 57-70 by rep; good endings 3/3, 7/8, 6/8 with the old bot). The seeds 1-3 normal row is below hard only by noise (one bankruptcy in n=3). Owner hard now goes bankrupt in 1 seed in 4-5 (earlier notes: none in 5); I could not tell whether that is P5/P6 or variance, and it was not retuned (see Q6d below, which did). The Rodent Nation deals (`rn_rmm` +$25/week, `rn_psa` -5% speed, `rn_hw` John -3%) did not show up as a trap or a free win in these runs. On paper the pricing clinic (+3% on every fee, about $170 a week with 7 clients) pays back the $450 trip in three weeks, so GO YOURSELF beats STAY HOME in cash; left as is because the trip is a once-a-game choice and the alternatives (burnout -10, rep +1) are real.

**Projects** (profit = price - hardware - hours x 15 s x `COST_PER_SEC` 2.9, i.e. $43.50 an hour, at the middle price): desktops $243 (9%, $14 an hour), security $271, network $684, server $1,836, backup_dr $528, **voip $480 (18%, $24 an hour)**, **email_move $798 (41%, $36 an hour)**. Neither new project dominates or is useless, so no change (email_move is the best margin of the small jobs because it carries almost no hardware; if the pool feels too generous, drop its price range to 1,400-2,200).

**R12 chair race**: `Outings._finish` gives the chair race the same rewards as every other outing (everyone +1 + stars mood, owner burnout 5 + 3 x stars, tech energy 4 + 2 x stars, 3 stars = rep +1); there is no chair-only reward, so it cannot dominate.

**P6 (a) heavy fixes** (`tech.heavy_fail` 0 / 0 / 0.25, `tech.heavy_slow` 1 / 1 / 1.3, `tech.onsite_mood` 3 / 2 / 1): normal is neutral by construction (`tests/difficulty.gd`). They only apply to the remote reimage and profile rebuild at a client with a site, so they make hard slightly harder and the tech hard cell was not re-measured beyond the smoke test above (careful hard rep 31 vs 100 normal).

### Ransomware exits: expected value (Q6c)
A "lost" ending costs, in the owner campaign, the `ransom_lost` card: settle $2,500, rep -3 (fighting it is $3,000 and rep -5.5 on average, so settling is the baseline). In the tech campaign `_ransom_lost` is score -30, rep -15, scar 15.

| Exit | Owner: cash EV, rep EV | Owner: files back | Tech: score EV, rep EV | Time (x a fix) | Notes |
|---|---|---|---|---|---|
| Pay ($500, 70%) | -$1,250, -1.6 | 70% all | -12.5, -5.9 | 1.0 | fast, gambler's option |
| Shadow copies (free, 40%) | -$1,500, -2.6 | 40% most | -8 on win, free try if it fails | 1.0 | a free roll in tech, worst single shot in owner but the only one when cash is under $150 |
| Vendor versions (`VENDOR_ODDS` 0.5) | -$1,400, -1.5 ($150 owner, free in tech) | 50% all | -1 on win, free try if it fails | 1.5 | the best free roll |
| Insurer (`INSURER_ODDS` 0.65, policy `INSURED_SHARE` 0.5) | -$1,125, -1.7 ($250) | 65% all | -4, -1 on win; mood -2 if denied | 1.0 | only where there is a policy |
| Isolate and rebuild | **-$1,000, -3.0**, client mood -8 (was -$300, -2) | 0% (recent files lost) | -10, -4, mood -8 | 4.0 | certain, the safe floor |
| Accept the loss | -$2,500, -3.0 | 0% | -30, -15 | 0 | |

Finding: in the owner campaign the rebuild was strictly dominant (certain -$300 and rep -2 against expected -$1,100 to -$1,500 for every gamble, and its only drawback, the lost files, is the same drawback a failed gamble ends in). Raised to **$1,000 and rep -3** in `Owner.CARDS.ransom_options` (and the generator, and `story/strings.txt`): now the rebuild is the cheapest certain outcome, about level with paying in cash, worse in reputation, and nothing beats everything else (insurer is best on paper but needs a policy and is a gamble; pay keeps the files; shadow is free). `tests/p6.gd` asserts the rebuild's expected cash cost stays at least half of paying's, and that it costs $1,000. In the tech campaign the best sequence is vendor, then insurer (if any), then shadow, then rebuild: expected score about -3.4 with a policy and -5.1 without, against -12.5 for paying straight away. That is the "try the free things first" advice the in-game forum already gives, paid for in time (1.5x for the vendor, 4x for the rebuild on a P1 whose window is 120 s on normal), so it is not free; left unchanged. Paying is dominated on score and rep by the rebuild but is 4x faster and keeps the files 70% of the time, so it is still a real choice. Open: the odds (70 / 40 / 50 / 65%) and the 50% policy share are guesses, see `docs/realism-review.md`.

## Owner hard bankruptcies (Q6d)
Careful owner bot (`smart`), hard tier, ts=4, 24 seeds (1-24) per row, `BOT_TRACE=1` prints every card, the pick and the cash, and a weekly `est` line.

| Build | Fired (bankrupt) | Good | Mid | Rep avg |
|---|---|---|---|---|
| before P6 (7f45ca3), seeds 1-24 | 1 (seed 18) | 21 | 2 | 72 |
| P6 merge, P5 merge (8 seeds each, odd seeds) | 0 and 0 | 6 / 6 (P5 also 1 bad, rep 29, not fired) | 2 / 1 | 68 / 72 |
| HEAD with the old bot | **6** (seeds 9, 16, 18, 19, 21, 24) | 16 | 2 | 56 |
| HEAD + bot skips the draw when the bank is thin | 3 (2, 13, 16) | 19 | 2 | 65 |
| **HEAD + that + no Rodent Nation trip under $3,000** | **1 (seed 17)** | **21** | 1 | 71 |

Also, same bot, ts=4, seeds 1-16: easy 1 fired of 16, rep 90 (14 good, 1 mid); normal 1 fired of 16, rep 79 (13 good, 2 mid); hard 1 of 24, rep 71. Ordering by rep holds (easy > normal > hard); one bankruptcy per tier is the bot's floor, it is not a hard-only effect.

**Cause.** The economy is thin by design and the bot lives on it: at the start 5 clients bring $4,000 a week against $2,700 payroll and $660 to $840 of overhead; the bot then buys the backup service, the peer group and the platform in week 1 ($1,700), sets STANDARD marketing ($400 a week) and a NORMAL draw ($600 a week) in week 3, and says yes to every $250-$800 card after that (billing audit, stack, ByteBrothers plan, handovers, firewalls, price hike). From week 3 the weekly cash flow is about -$500 to -$1,000 until the client count reaches 7 or 8, and break-even is about 6.5 clients (payroll $3,500-4,100, overhead $1,300-1,700 by week 14). A run that stalls at 4 to 6 clients (a fee raise that makes a client walk, a ByteBrothers poach, a slow-payers week that parks $3,800 in A/R in week 7) goes negative and never gets back. Nothing in P5/P6 touches that arithmetic (the project hardware is paid at completion, the ransom exit costs are not on the bot's path since it picks pay $500, the Rodent Nation trip is a one-off $300), so the old "none in 5" was luck at the tail; the P5/P6 builds show 0 fired in 16 seeds and HEAD 6 in 24, but runs are not bit-for-bit repeatable under load (the same seed gave different games), so I treat the fall of the margin as small and real (the mean cash at week 7 is $1,200 lower, $3,800 lower at week 20) rather than a single regression. The new content did cost a little: the trip, two lower-margin projects (voip $24 an hour, email $36) and the card pool changing the random stream.

**Fix (bot policy only, no game number changed).** Two flaws in `OW_POLICIES` handling in `bot_lib.gd`: (1) the dynamic draw warning ("We drew $600 this week and the bank is down to ...") took pick 0 = cut the draw to SMALL; a careful owner with the bank under $2,000 SKIPS the draw (option 1, also +2 trust with both owners), worth $300 to $600 a week; (2) `rn_invite` took pick 1 (send the tech, $300) whatever the bank held; under $3,000 it now stays home. Tried and dropped: STANDARD marketing becomes LIGHT under $6,000 (fewer clients, 2 of 4 seeds worse) and a generic "keep $1,500 in the bank" rule that takes the first free option (it declined the $600 breach response for a free option that cost $3,500). `Difficulty.TABLE` untouched (`owner.cost` 1.03 on hard is worth about $40 a week, which does not move the tail).

Result: hard bankrupt 1 of 24 (target at most 1 of 16), good ending 21 of 24 (88%, the earlier 4 of 5 for hard), mid 1, bad 2 (seed 4: rep 7 with $7,658 in the bank). Good endings are above the "about half" asked for: hard here is hard on reputation (71 against 79 and 90) more than on survival, and I did not raise the pressure further because the tier tables for sales, tech and service are tuned on the same reputation dials. If hard owner should be harder, raise `rep.loss`, not the costs: the costs are what bankrupt the bot.

## Co-op bot (R34 phase 5, Nov 2026)
`bot_run.gd tech normal careful coop seeds=1 ts=40` plays the tech campaign with two careful bots (player 2 works the same queue through `Players.run_as`, ticket pace x1.5, own skills). Seed 1 alone: 139 tickets closed, 0 missed, rep 100, PowerShell 5. The pair: 159 closed (about 14% more for 1.5x the arrivals), 0 missed, rep 100, player 2 ends with 625 XP and PowerShell 5, so both people level fully. One seed on one tier says only that the pair is not starved or buried; the 1.5 dial and the 25% share still want a few more seeds and a play-test with two people before they count as tuned.

## Nov 2026: the balance pass without a human (Q6, R1, P6, T2, X7, X9, C7, R10, P5 / R38)

Everything below was measured on the merged code of Nov 2026 with the bots of `tests/bot_lib.gd`, one Godot process at a time.
Seeds 1 to 5 unless a row says otherwise; tech at ts=60, service at ts=40, sales at ts=20, owner at ts=4. The older sections
above are history: their numbers were taken with a bot whose speed depended on the time scale and on a game that did not repeat
a seed (see "The same seed, another game"). How it was built: `docs/dev/notes-balance.md`.

### The same seed, another game (Q6)
`tech hard careful seed 11` gave 12 to 73 from run to run, and the shortcut owner of seed 2 gave $24k, $44k, $77k, $137k,
$330k, $342k and one bankruptcy on the same code. Four causes, all fixed:

| Cause | Kind | Fix |
|---|---|---|
| The office's first meeting timer was drawn at boot, before the run had its seed, and never again | game | `World.new_run()` draws it from the run seed at every new game |
| A cast member's body of the day before stayed in the scene and, when its old routine ran out, replaced its person's new plan | game | a leaving body no longer calls `World.leg_done` / `leg_exit`; `begin_next_day` frees the bodies |
| Every change of step of the tech bot cost a whole frame (1.3 game seconds at ts=20, 8 at ts=120) | bot | the frame's time is shared between the steps |
| A run inherited the scene, the open card, the stopped clock and the career of the run before it in the same process | bot | every run starts from a clean slate on a freshly loaded floor |

Same seed, same code, now: tech hard careful seed 11 is 85 / 77 / 79 at ts 20 / 60 / 120 (it was 82 / 73 / 53), the same in
two processes; the shortcut owner of seed 2 is $300,256 in two processes; `tests/determinism.gd` plays a tech seed and a
sales seed twice in one process and compares the rows.

**Still open, owner campaign only:** a command line repeats exactly (the same `bot_run` call gives the same rows in two
processes), but one owner seed can give two results depending on which seeds ran before it in the same process. Seed 3,
careful, normal: $831,705 alone or after seed 2, $872,920 after seeds 1 and 2. The trace (`bot_det.gd ... before=1,2`)
shows the runs parting on day 1 at an office worker's routine, so something in the physical office survives a new game
(not the cards, the career, the clock or the campaign state: those are reset). Tech, sales and service cells were
checked against their Year 2 chains and do not show it. The owner tables below are therefore "as the cell ran"; the
year 1 column of the owner Year 2 table was played in another order and differs from the tier table for that reason.

### Tiers: every campaign x tier x strategy, 5 seeds
good / mid / bad are the ending classes of `bot_lib.gd` (good = the top ending). "let go" in sales is the quota ending, not
a firing by reputation.

| Campaign | Strategy | Easy | Normal | Hard |
|---|---|---|---|---|
| Tech | careful | 5 good, rep 100 | 5 good, rep 100 (100 from day 13-14) | 5 good, rep 80 (67 76 76 83 97) |
| | mixed | 5 good, rep 100 | 5 good, rep 75 (77 68 78 75 77) | 5 fired |
| | lazy | 5 good, rep 100 (cozy: nobody is fired, misses are free) | 5 fired (day 17-18) | 5 fired |
| Sales | careful | 5 good, rep 100 | 3 good 2 mid, rep 93 (73-100) | 3 good 1 mid 1 let go, rep 76 (57-87) |
| | lazy | 5 let go, rep 28, nobody fired | 5 let go, rep 20 | 4 fired, 1 let go, rep 1 |
| Service | careful | 5 good, rep 100 | 5 good, rep 97 (92-100) | 5 good, rep 88 (81-96) |
| | mixed | 5 good, rep 100 | 5 good, rep 93 (87-97) | 5 good, rep 79 (77-82) |
| | lazy | 2 good 2 mid 1 bad, rep 61 | 3 mid 2 bad, rep 47 | 5 bad, rep 26, nobody fired |
| Owner | careful | 5 good, rep 100, value $869k | 4 good 1 bad, rep 85 (97 97 100 32 100), value $728k, nobody fired | 3 good 1 mid 1 bad, rep 67 (74 27 87 49 97), value $544k, nobody fired |
| | lazy | 3 good 2 mid, rep 93, value $305k, nobody fired | 4 mid 1 fired (week 15), rep 53, value $305k | 5 bad, 1 fired (week 9), rep 19, value $138k |

Read against the targets:
- **A careful bot finishes hard without being fired and clearly below normal** in all four campaigns: tech 80 against 100,
  sales 76 against 93, service 88 against 97, owner 67 against 85. `Difficulty.TABLE` hard values were **not changed**.
  Sales hard is the tightest: one seed in five misses both quotas and is let go (the quota is x1.2 there).
- **Owner hard, the careful bot went bankrupt in week 15 on one seed in five** until its answer to the scammed-client card
  was fixed (bot, not game): `bec_loss` option 1 credits the client 40% of the loss, $2,200 here, and the card names no
  price. With $1,033 in the bank that was the end. A careful owner under $5,000 lets the lawyer answer ($600) or asks the
  insurer; the seed now ends at reputation 27, alive. The card itself is worth a second look: it is the only expensive
  option in the owner campaign without a price on its label.
- **Owner normal, careful, seed 4 ends at reputation 32 with $387k and 11 clients**: the desk drowns (the weekly report
  is negative from week 2 on) while the books are fine. The careful owner bot does not manage capacity; a player who
  reads the queue card would.
- **Lazy fails everywhere except on cozy easy**, where the tech lazy bot reaches 100: nobody is fired there and misses
  cost nothing, by design (R16).

### Tech reputation curves and mixed play (T2)
`mixed` = careful on even days, lazy on odd ones (slow, first come first served, no study, no backups, but honest fixes).
Before this pass it ended at **88 to 97** with the team lead offer: the day report added `2 x closed - 3 x missed - ...`
capped at +1 to +4, so on a busy day the closes always outweighed the misses and a half-hearted day still earned the cap.

Changed (tech campaign, normal tier only): from reputation 58 on a day with more loose ends (SLAs missed, reopens, plain
tickets left in the queue) than one for every six closes adds nothing to the reputation; from 62 on it costs 4 for every
loose end too many, at most 10. The report says why. Iterations, mixed bot, seeds 1-5:

| Rule | Mixed ends | Careful |
|---|---|---|
| before | 95 91 89 95 96 (mean 93) | 100 |
| a sloppy day adds nothing (58+), costs 1 (72+) | 95 91 89 95 96 | 100 |
| costs 4 from 66 | 86 73 69 84 82 (79) | 96 (two seeds lost points to a ticket that could never be closed, see below) |
| costs 6 from 62, loose ends without the multi-day jobs | 82 83 78 82 79 (81) | 100 |
| costs 3 a loose end too many, at most 10 | 76 76 77 77 77 (77) | 100 |
| **final: 4 a loose end too many, at most 10, also when the plain formula was already negative** | **77 68 78 75 77 (75)** | **100** |

Mixed play now stands at 56 to 70 on day 16 (inside the band on every seed) and ends at 68 to 78 because the
conference trip of days 17 to 20 adds 8 to 10 points to anybody who made it. Two seeds of five end inside 55-75, three end
at 77-78. I stopped there: every further point has to come out of a single bad day's cost, and at 4 a loose end a really
bad day already costs the full 10. `tests/t2.gd` has its own, harsher mixed player (odd days: P3s closed unfixed, P1s left
to run out); it ends inside the band on all five seeds:

| `t2.gd -- curve seeds=5` (seeds 4242-4246) | good | careless | mixed |
|---|---|---|---|
| normal | 99 100 100 100 100 | fired on day 6 (all five) | **74 67 68 74 74** |
| hard | 95 97 97 98 96 | fired | 24 0 0 46 20 |

(`t2.gd` now pins the run seed; before, "seed 4242" was a new ticket stream on every run. Its assert is 55-75, was 55-86.)
The careful bot reaches 100 on day 13 or 14 on every seed; the eight by-name thank-yous of R36 (+1 each, never scaled)
are what moved it up from the "98 on day 20" the curve was designed for.

Found on the way: **a ticket that could never be closed.** When the ransomware (or a forced story job) took over a server
that already had a ticket, that ticket's machine no longer had its problem and no fix worked on it: a P1 "server not
responding" stayed open and breached for the last twelve days of a careful run. `Msp.supersede()` now marks such a ticket
done; it only wants closing.

### Stats and presets (X7)
The tech bot now plays the stats: it runs the PowerShell scripts from level 2, takes the clever fixes a skill unlocks and
skips the daily backup check once BACKUP WATCH does it. `tests/stat_effects.gd`, hard tier, seed 11, the first 8 days,
flat build against one stat at 4:

| Build | Rep | Score | Closed | SLAs missed | Client mood | Clever fixes | Fixed by script |
|---|---|---|---|---|---|---|---|
| flat (no points spent) | 74 | 329 | 53 | 21 | 81 | 23 | 13 |
| POWERSHELL 4 | 75 | 448 | 55 | 12 | 98 | 24 | 17 |
| NETWORKING 4 | 74 | 329 | 53 | 21 | 82 | 28 | 13 |
| SERVERS 4 | 76 | 340 | 53 | 20 | 85 | 35 | 8 |
| SECURITY 4 | 76 | 481 | 55 | 9 | 97 | 25 | 18 |
| CUSTOMER 4 | 77 | 416 | 54 | 14 | 93 | 23 | 14 |
| preset GENERALIST | 75 | 448 | 55 | 12 | 94 | 30 | 21 |
| preset SCRIPTER | 75 | 448 | 55 | 12 | 97 | 26 | 16 |
| preset NETWORK NERD | 76 | 329 | 53 | 21 | 85 | 30 | 12 |
| preset PEOPLE PERSON | 76 | 350 | 54 | 20 | 88 | 29 | 8 |

Every stat changes the outcome; POWERSHELL, SECURITY and CUSTOMER most (fewer missed clocks). SERVERS is a small step and
NETWORKING is the weakest: five more clever fixes and one point of client mood in eight days, nothing else. The four presets give three or four different outcomes on hard. On normal they still all
end at reputation 100: a careful bot never comes under pressure there, and the fix itself takes 1.5 to 6 seconds against
28 seconds of handling, so a stat that speeds up fixes is worth little once the lessons are done (a lesson a day takes
POWERSHELL to 5 by day 5 whatever the build). Presets matter in the first week and on hard.

### Heavy fixes, quick fixes and the ransomware exits (P6)
Do the bots use them? The careful and mixed bots keep the backups green, so their ransomware day is a plain restore (29 of
29 runs). The lazy bot never checks a backup: restore fails, then shadow copies (3 of 10 recovered most), then it pays
(7 of 10, all seven got the key). The vendor, the insurer and the rebuild are only reached by a player who lost the backup
and does not want to pay; `tests/ransom_exits.gd` plays them on 150 seeded runs per policy with the real ticket:

| Policy (after the restore failed) | Score | Reputation | Time (x one fix) | Files back | Most files | All lost |
|---|---|---|---|---|---|---|
| careful (vendor, insurer, shadow, rebuild) | -3.9 | -1.2 | 3.8 | 70% | 10% | 0% |
| free first, then pay (vendor, insurer, shadow, pay) | -5.2 | -2.0 | 3.2 | 81% | 10% | 9% |
| shadow, then pay | -10.8 | -4.8 | 2.6 | 37% | 45% | 18% |
| shadow, then rebuild | -9.1 | -3.6 | 4.2 | 0% | 45% | 0% |
| pay at once | -11.5 | -5.4 | 2.0 | 74% | 0% | 26% |
| rebuild at once | -10.0 | -4.0 | 5.0 | 0% | 0% | 0% |
| give up (close the ticket) | -30.0 | -15.0 | 1.0 | 0% | 0% | 100% |

Trying the free things first is the best policy and the slowest; paying at once is the fastest and loses everything one
time in four; the rebuild never loses the case and never returns the files; giving up is three times worse than anything
else. No exit is both the best and the fastest, so the odds (vendor 50%, insurer 65% where there is a policy, shadow 40%,
pay 70%) were left alone.

Quick and heavy fixes on everything, tech, 3 seeds:

| Strategy | Normal: score, rep | Hard: score, rep |
|---|---|---|
| proper (the real fix, scripts) | 1422, 100 | 1088, 72 (69-75) |
| careful (proper + clever) | 1437, 100 | 1226, 80 |
| shortcut (quick workaround whenever there is one) | 1132, 100: 143 quick fixes, 73 came back | not run |
| heavy (the heavy fix whenever there is one) | 1283, 100: 122 heavy fixes, 1,100 s of fixing against 320 s | 334, rep 17, one seed fired |

The quick fix costs a fifth of the score, the heavy fix a tenth on normal. On hard the heavy fix on everything is ruinous
(3 to 7 times the fix time under clocks that are 0.4 as long), which is the point of `tech.heavy_slow`: there it is the
exception for the machine that will not stay fixed, not a way of working. No number changed.

### Year 2 and Year 3 (R10)
Year 2 from a real year 1 (the same bot plays year 1, the campaign is finished properly, Year 2 starts on its record):

| Campaign | Tier | Year 1 | Year 2 |
|---|---|---|---|
| Tech | normal (3 seeds) | 3 good, rep 100, score 1436 | 3 good, rep 100, score 1599 |
| | hard | 3 good, rep 73 (67 76 76) | 3 good, rep 66 (69 61 69) |
| Sales | normal | 3 good 2 mid, rep 93 | 2 good 3 mid, rep 88 (70-100) |
| | hard | 3 good 1 mid 1 let go, rep 76 | 1 good 1 mid 3 let go, rep 57 (31-71), nobody fired |
| Service | normal | 5 good, rep 97 | 5 good, rep 95 (80-100) |
| | hard | 5 good, rep 88 | 5 good, rep 82 (75-95) |
| Owner | normal (3 seeds) | 3 good, rep 98, value $793k | 1 good 2 mid, rep 95 (91 98 95), value $819k, start bank $5,000 richer |
| | hard (3 seeds) | rep 62, 27 and one bankrupt in week 14 (no Year 2 for that one; in the tier table's order the same seeds gave 74, 27, 87) | 1 good 1 mid, rep 78 and 50, value $589k and $695k |

Year 2 is harder than year 1 in every cell that is not already at the ceiling, and nobody is fired. Tech normal stays at
100 in both years (the careful bot has room to spare on normal; the 15% tighter clocks do not reach it). Sales hard Year 2
is the hardest cell of the game for a careful bot: three of five miss the quotas.

Year 3 (`tests/bot_year3.gd`, START YEAR 3 from a made-up decent record, careful bot, 3 seeds; normal was measured by the
Year 3 branch): nobody fired in any cell.

| Campaign | Easy | Hard |
|---|---|---|
| Tech | rep 100 | rep 35 |
| Sales | rep 96 | rep 62 |
| Service | rep 100 | rep 50 |
| Owner | rep 100 | rep 63 |

Tech hard Year 3 ends at 35 without the lead offer: alive, but that is as far as hard should go.

### The owner's 20 weeks as a trace (X9), shortcuts and takeover (P5, R38)
`tests/bot_trace.gd -- owner normal careful seeds=3 ts=4` prints every week: the bank, reputation, partner trust, company
value, clients and each card with the answer. Seed 1:

| Week | Bank | Rep | Trust | Value | Clients | Decisions |
|---|---|---|---|---|---|---|
| 1 | $7,360 | 54 | 55 | $50,323 | 5 | 1 |
| 2 | $5,945 | 58 | 56 | $40,327 | 5 | 3 |
| 3 | $4,926 | 60 | 60 | $19,853 | 5 | 6 |
| 4 | $4,407 | 64 | 64 | $17,592 | 5 | 6 |
| 5 | $2,600 | 66 | 63 | $0 | 5 | 9 |
| 6 | $3,710 | 67 | 65 | $0 | 5 | 6 |
| 7 | $1,443 | 65 | 64 | $0 | 5 | 7 |
| 8 | $-295 | 67 | 63 | $0 | 5 | 7 |
| 9 | $-930 | 73 | 66 | $0 | 5 | 6 |
| 10 | $-464 | 74 | 67 | $0 | 5 | 9 |
| 11 | $758 | 75 | 67 | $0 | 6 | 8 |
| 12 | $3,175 | 73 | 68 | $0 | 6 | 7 |
| 13 | $2,240 | 77 | 64 | $41,389 | 6 | 8 |
| 14 | $2,860 | 80 | 59 | $152,545 | 7 | 5 |
| 15 | $1,327 | 84 | 59 | $203,766 | 7 | 10 |
| 16 | $2,787 | 87 | 53 | $289,774 | 7 | 5 |
| 17 | $2,967 | 91 | 49 | $330,231 | 7 | 11 |
| 18 | $4,615 | 93 | 52 | $250,571 | 7 | 6 |
| 19 | $6,798 | 94 | 52 | $592,398 | 11 | 4 |
| 20 | $7,893 | 97 | 53 | $792,870 | 11 | 2 |

Checked on three seeds (60 weeks):
- **Dead weeks: none.** Every week has at least one decision (week 1 has only the welcome card, week 20 two); 6.3 decisions and 4.8 notices a week on average, 11 in the busiest week.
- **Repeats.** The inbound lead card comes every week from week 10 on once marketing is on STANDARD (9 times in seed 1, 5
  in seed 3): it is one decision asked nine times, and the only card of the campaign that reads as a repeat. The marketing
  budget card comes three times (weeks 3, 9, 14), the "you now know something about Big Cheese" card once per habit learned.
- **Runaway numbers.** Cash stays between -$930 and $14k. The **company value is $0 from week 5 to week 12** (the estimate
  is a multiple of a profit that is negative while the owner invests) and then goes from $41k in week 13 to $793k in week
  20; the largest single step is week 19 (from $251k to $592k, +136%), when the Big Cheese clients come over and the count
  goes from 7 to 11 in one card. Nothing overflows and the 3x-a-week check of the tool does not trip, but the last two
  weeks decide two thirds of the final number. Left as it is: it is the story's payoff; worth knowing when reading values.
- Trust moves between 49 and 68 and never pins.

**Shortcut against careful** (one combined run, `bot_run.gd -- owner normal careful,shortcut,lazy,takeover seeds=5 ts=4`,
its CHECK line): `CHECK owner normal: shortcut value 196876 vs careful 727977 (27%), shortcut fired 1 of 5`. The shortcut
owner (careful's answers with every temptation taken) ends at $29k (fired), $300k, $459k, $31k and $165k against $793k,
$756k, $873k, $387k and $832k. The one firing (seed 1, week 15) is not the bills alone: its bank is under water from
week 8 on (about $1,500 a week below the careful owner's), in week 14 the RMM vendor is breached, the safe answer ($600)
is greyed out at $214, the bot waits for the vendor's statement and loses the 35% roll (-$3,500).

**Takeover.** The `takeover` owner (lets the week 7 client go with an exit chat, takes them back in week 11 with the
takeover assessment, assesses before signing in week 19) gets the visit on seeds 2 and 4 of five: one visit, six findings,
six Playbook jobs each, ending at reputation 94 with $1,086k and $401k. On the other three seeds the client that comes back
has no office of its own, so there is nothing to walk (only six clients have a site). The policy costs nothing against
careful (rep 97, value $803k against 85 and $728k).

### Card pacing (C7)
`tests/bot_trace.gd`, careful bot, normal tier. A decision is a card with two or more answers; a card with one answer (the
reply to a choice, a notice) is counted apart.

| Campaign | Decisions per day | Busiest / quietest day | Notices per day | Days without a decision | Longest stretch without one (working hours) |
|---|---|---|---|---|---|
| Service, careful (5 seeds, 100 days) | 7.6 | 13 / 3 | 6.7 | 0 | 7.6 |
| Service, lazy (3 seeds) | 4.8 | 8 / 2 | 4.3 | 3 (day 20 of each run) | 7.6 |
| Tech, careful (3 seeds) | 2.9 | 9 / 0 | 1.7 | 3 of 60 | 11.5 |
| Owner, careful (weeks, 3 seeds) | 6.3 | 11 / 1 | 4.8 | 0 | 8.0 |
| Sales, careful (5 seeds) | 11.7 | 22 / 4 | 9.7 | 0 | 8.0 |

Service (the row C7 asks about): no day without a decision, never fewer than three, about as many replies and notices as
decisions. Two thirds of the careful manager's decisions come at 8:00 (the huddle, the cards of the night, and the 1:1s and
runbook lessons he starts himself); from 9:00 on about two and a half a day arrive, spread evenly to 16:00, and the longest
stretch without a card is one working day. That is thin for cards but it is when the dispatch board is the work, so no
card was added. What a player will notice is the **1:1 deck**: MAYA, JOHN and the tier 1 crew have four cards each
(`Service.ONE_ON_ONES`), dealt in order. The careful bot holds two 1:1s a day and sees every tier 1 card four times with
the same person ("Sam says: I got stuck on a printer", four times in twenty days); a player who talks to somebody every
other day sees each card twice. That is a content gap, not a number: four more cards for the tier 1 deck would halve it.
Nothing else repeats beyond the daily huddle and the Friday numbers (by design) and the hiring round's three cards.
Fixed on the way: the careful bot failed every runbook lesson (it took the first answer), 25 failed recordings a run,
which had buried the real cards in notices; it answers with the safe first step now and the documentation ends at 100%
where it stood at 83%.

Sales: the busiest campaign for cards (a handover asks one card per promise, 30 to 40 of those a run, and every visit opens
with the owner's welcome); no quiet day.

Tech: a quiet day without any card happens three times in sixty days (the tickets are the decisions there), and the
favour texts and by-name asks of R36 keep the count at about three a day. The owner campaign is covered above.
