# Balance notes (Q6): bots, tiers and the alt-fix economy

How the numbers were checked and what they came out as. Re-run after any change to a tier table, the ticket pace, the SLA windows or the campaign
reputation maths. Counts are small (3-5 seeds a cell, the machine was shared), so read them as "which side of the line", not as percentages.

## The tools
| File | What it does |
|---|---|
| `godot/tests/bot_lib.gd` | The shared bot driver. `play(mode, tier, strategy, seed)` plays one campaign to the end in compressed time and returns `{rep, score, ending, cls, fired, info}`. `cls` is `good` / `mid` / `bad` (good = the top ending: tech team lead, sales director, service ops manager / side-with-an-owner, owner rep 60+ with the goal met; bad = fired or reputation under 45). |
| `godot/tests/bot_run.gd` | The slow harness, one or more cells per process: `-- tech easy,normal,hard careful,lazy,chaotic seeds=4 ts=60`. Words are modes (tech owner sales service), tiers, strategies (careful lazy chaotic, plus the tech-only `proper` and `shortcut`); prints a `BOT` line per run and a `CELL` summary per mode x tier x strategy. Run one tier or strategy per process and in the background: a tech run is about 40 s, a service run 20 s, sales 6 s, owner (ts=4) 2-3 minutes. Owner needs `ts=4` or less (at ts=8 even careful play goes bankrupt in week 17: the weekly cards and the team simulation are tuned for the real clock). |
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

Ordering holds (easy 100 > normal 80-94 > hard 57-70 by rep; good endings 3/3, 7/8, 6/8 with the old bot). The seeds 1-3 normal row is below hard only by noise (one bankruptcy in n=3). Owner hard now goes bankrupt in 1 seed in 4-5 (earlier notes: none in 5); I could not tell whether that is P5/P6 or variance, and it was not retuned (see Q6d below, which did). The Rodent Nation deals (`rn_rmm` +$25/week, `rn_psa` -5% speed, `rn_hw` Vic -3%) did not show up as a trap or a free win in these runs. On paper the pricing clinic (+3% on every fee, about $170 a week with 7 clients) pays back the $450 trip in three weeks, so GO YOURSELF beats STAY HOME in cash; left as is because the trip is a once-a-game choice and the alternatives (burnout -10, rep +1) are real.

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
