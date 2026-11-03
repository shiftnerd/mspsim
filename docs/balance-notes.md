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
| `tech.sla` (SLA window x, tech) | 1.3 | 1.0 | 0.5 | `Mutators.sla` |
| `tech.gain` / `tech.loss` (day report reputation move x, tech) | 1.25 / 0.75 | 1 / 1 | 0.4 / 1.8 | `Campaign._tier_rep` |
| `crew.pace`, `crew.sla` (owner, sales, service) | 1.1, 1.15 | 1, 1 | 0.8, 0.85 | same places |
| `rep.gain` / `rep.loss` (owner, sales, service) | 1.2 / 0.75 | 1 / 1 | 0.8 / 1.3 | `Campaign._tier_rep` |
| `tech.alt_ret` (x the chance a quick workaround comes back) | 0.8 | 1.0 | 1.3 | `Msp._alt_fix` |
| `owner.cost` (weekly overhead x) | 0.95 | 1.0 | 1.03 | `Owner.weekly_estimate` |
| `sales.lead` (added to a new lead's quality; the quota x0.8 / 1.0 / 1.2 and rival price x already existed) | +5 | 0 | -5 | `SalesCampaign` lead roll |
| `service.trust` (x on the trust an owner loses) | 0.7 | 1.0 | 1.6 | `Service.add_trust` |

Normal is unchanged (`tests/difficulty.gd` lists every key at its normal value; outside a campaign `cf()` returns the normal number whatever the tier). Free Play and the old tests are unaffected.

## Results (reputation 0-100; good / mid / bad endings out of n)
Final table of the last runs of each cell. See "Open" for the cells with fewer seeds.

| Mode | Strategy | Easy | Normal | Hard |
|---|---|---|---|---|
| Tech (n=4) | careful | 4 good, rep 100 | 4 good, rep 100 | 4 good, rep 88 |
| | lazy | 2 good 1 mid 1 bad, rep 57 | 4 bad (fired or near), rep 3 | 4 bad, fired |
| | chaotic | 3 bad, fired | 4 bad, fired | 4 bad, fired |
| Owner (n=2-3, ts=4) | careful | 2 good, rep 93 | 2 good, rep 86 | 1 good (rep 78) |
| | lazy | 1 good 1 mid, rep 62 | 1 mid 1 bad (fired week 9), rep 28 | fired week 16 |
| | chaotic | - | 1 mid 1 bad, rep 39 (rich but unloved) | - |
| Sales (n=4) | careful | 4 good, rep 100 | 3 good 1 mid, rep 90 | 2 good 2 bad, rep 76 |
| | lazy | 4 bad (let go), rep 35, nobody fired | 4 bad, rep 24 | 4 bad, rep 5 |
| | chaotic | 4 bad, fired | 4 bad, fired | 4 bad, fired |
| Service (n=3) | careful | 3 good, rep 100 | 3 good, rep 96 | 3 good, rep 74 |
| | lazy | 2 good 1 bad, rep 61 | 2 mid 1 bad, rep 45 | 3 bad, rep 25 |
| | chaotic | - | 4 bad, rep 11 (n=4) | 4 bad, fired (n=4, earlier tier values) |

Against the targets: normal careful reaches a good ending in 11 of 12 seeds (one sales mid); normal lazy ends mid or bad everywhere (tech and sales all bad); chaotic fails everywhere except the owner greed run, which makes money and loses the name (mid/bad). Easy careful is 100% good and easy lazy survives (one tech seed and one service seed still reached a good ending, one service seed was a bad one). Hard careful wins in tech (4 of 4, rep 88), service (3 of 3, rep 74), about half of sales (2 of 4) and the one owner seed after softening; hard lazy fails in all four modes. The smoke test (`tiers_balance.gd`, seeds 11-12) passes: rep easy >= normal >= hard for careful in sales, tech and service, careful > lazy on every tier.

## Alt fixes (item 4): are the quick workarounds worth it?
`shortcut` = the quick workaround whenever one exists, `proper` = the real fix, `careful` = proper plus the clever fix when its skill is unlocked. Normal tier, 3 seeds, tech campaign:

| Strategy | Quick fixes | Returns (came back) | SLA misses | Score | Reputation |
|---|---|---|---|---|---|
| careful (clever where unlocked) | 0 | 0 | 0-1 | 1811 | 100 |
| proper | 0 | 0 | 0-1 | 1699 | 100 |
| shortcut | 224 | 104-120 (about 50%) | 10-18 | 1522 | 95-100 |

Before the change below the shortcut bot scored MORE than the careful one (2420 against 1722): every returned workaround came back as a fresh ticket worth +10 points and +2 reputation when closed, so overusing the quick fix farmed both. Now a returned ticket is rework: `Msp.spawn_return` flags it `repeat`, drops the client's mood by `RETURN_MOOD` (3) and closing it earns `REPEAT_POINTS` (2) and does not count as a closed ticket for the day's reputation. Result: the quick fix stays the fastest (0.3-0.6x the time, `mult`) so it is still tempting when the queue is long, but used on everything it costs about 10-15% of the score, a dozen SLA misses and a few points of reputation. The `ret` chances (35-60%) and `mult` values in `Msp.ALT_DEFS` were left alone: with the rework rule they are in a good place. On hard the return chance is x1.3 (`tech.alt_ret`).

## Open
- Tech hard is still easy for the careful bot (reputation 88, every seed a team lead offer): the bot is steady and never tired, and the reputation climb has a daily cap, so shrinking gains and SLA windows only lowers the top. To make hard a coin flip for a good human, add a tech-only pressure (two big incidents on the same day, energy drain) rather than more rep multipliers.
- Owner hard: with `owner.cost` 1.06 and ticket pace 0.8 both careful seeds went bankrupt (weeks 14 and 16); the dials were softened to 1.03 and 0.9 and one seed since reached rep 78 (value $204k). Needs 5+ seeds. Owner at easy gives a lower value than normal in one seed pair ($301k against $443k and $178k): the noise between seeds is larger than the tier effect on value, judge owner by reputation.
- Owner lazy and greedy runs on normal were 2 seeds each; owner chaotic on easy and hard and service chaotic on easy were not run.
- The tech lazy bot is a calibration, not a measurement: its idle gap (55 s) decides whether normal lazy drifts (gap 25-40 s gave good endings in half the seeds, 55 s gives fired or rep under 15). Change `TECH_IDLE` in `bot_lib.gd` and the normal-lazy cell moves a lot; the careful bot's 28 s overhead matters the same way.
- Time compression: the tech bot runs at ts=60 (one frame is one game second); at ts=30 the numbers were the same within noise. Owner at ts=8 is not valid (see above).
- The machine was shared: a full matrix (4 modes x 3 tiers x 3 strategies x 4 seeds, about 2 hours of CPU) took many hours of wall time. Run cells as separate processes.
