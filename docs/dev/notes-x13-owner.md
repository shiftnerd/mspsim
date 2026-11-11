# Build notes: X13, the owner and sales findings of the bot runs

Branch `worktree-agent-a48c31fc1f375ac38`, Nov 2026. Row X13 of `docs/ROADMAP.md`, the owner and sales half (the tech half and the
service 1:1 cards are another agent's). Every fix has a test and was measured with the bots of `tests/bot_lib.gd` on seeds 1 to 5
before and after, one Godot process at a time, owner at ts=4, sales at ts=20. "Before" is commit `24ab53b` (a copy of `godot/`
taken before the first edit), "after" is this branch. The tables are also in `docs/balance-notes.md` (section "Nov 2026: X13").

## 1. What was wrong, and what was done

| # | Finding | Cause | Fix | Test |
|---|---|---|---|---|
| 1 | The scammed-client card's 40% credit cost $2,000 and more, with no price and no `need` | `bec_loss` option 0 took `Incident.credit_amount()` inside `Incident.owner_fx`; the label and `show_card` knew nothing of it. The lawyer ($600) could lose half the loss on top, the insurer the whole credit, also unnamed | Every owner option now has a cost (`OwnerOps.cost`: the least and the most it can take) and the card shows it (`OwnerOps.label`). The credit names its price; a bank that cannot pay it pays it as a **dated bill** over 8 weeks (never greyed); the lawyer's and the insurer's worst case are on the label and are billed the same way when the bank is short | `x13_owner.gd`, `card_costs.gd`, `bec.gd` |
| 1b | The same defect elsewhere | Scan of every card (`card_costs.gd`: 406 owner options, 81 can take money; 220 service options; the sales beats) | Gambles for money say `(RISK $n)` (added by `OwnerOps.label`, no text edited); the lawsuit after lost files can be settled in parts; the sales refund card's half month and the brokered discovery name dollars; service had none | `card_costs.gd` |
| 2 | The shortcut owner was fired on seed 1: with $214 the safe vendor-breach answer ($600) was greyed and the gamble lost | A card whose only cash-free answer is a gamble, or does lasting damage | The vendor breach, the audit and the lawsuit each have an answer no bank balance can grey out, with a real cost that is not cash (a tired crew, reputation, a dated bill). The scan fails on any card that leaves only gambles for money, and on any card whose harmless answers all cost money while the open ones can lose a client, a tech or 3 reputation: that found the rack that fell off the wall (the broke owner's only answer lost the client three times in ten) and the crew's tool complaint (four in ten somebody quits); both have a cash-free answer now | `card_costs.gd`, `x13_owner.gd` |
| 3 | Careful owner, normal, seed 4: reputation 32 with healthy books | A game gap first, then a bot gap. The week's reputation change is the desk's (closes against missed clocks and tickets left open) and the owner's weekly report showed only money: nothing said why the name was falling | A **SERVICE DESK** row on the weekly report (`DESK OVER CAPACITY` in red when the loose ends outweigh the closes) and, after two such weeks in a row, a card from Morgan with the numbers and three ways out (hire, train, stop taking clients); at most twice a run. The careful bot looks at candidates when she says so and picks the best one instead of the first | `x13_owner.gd`, `layout_audit.gd` |
| 4 | Sales hard: a careful bot let go on 1 seed of 5 in year 1, 3 of 5 in Year 2 | No single input dial: with the quota at x1.1, the lead quality at normal, the lead flow at normal or the rival at normal the weak seed still misses both quarters. It is the review rule (two misses, however close) meeting the x1.2 quota | New hard-only dial `sales.keep` 0.65: two missed quarters end the job only when the two quarters together came in under 65% of the year's quota. Quota, lead quality, lead flow and rival strength on hard are unchanged; easy and normal are unchanged | `sales_hard.gd`, `difficulty.gd` |
| 5 | The inbound-lead card came up to 9 times with the same text | One hard-coded text | Ten lead stories (`OwnerOps.LEADS`, in `story/strings.txt`): another client situation, size, starting mood, odds and catch each; every story at most once in a run, the plain one first; when they run out John takes the meeting and texts the result | `x13_owner.gd` |
| 6 | Company value $0 in weeks 5 to 12 | The value is a multiple of the last four weeks' EBITDA plus cash; while the owner invests (a hire in week 3, marketing, the backup service) that average is negative and the bank is near zero, so `maxi(0, ...)` cut it to nothing | A floor: the contracts alone are worth 25% of a year's recurring revenue (cut by the same reputation and age discounts). The report says `(CONTRACTS)` instead of the multiple while the floor holds | `x13_owner.gd` |
| 7 | One owner seed, two results (seed 3: $831,705 alone, $872,920 after seeds 1 and 2) | `World._total` (the office's running time) was never reset. `World.try_chat` stores `_total - 60 + 3` and compares `_total - stored` with the cooldown: with a `_total` thousands of seconds larger the same three seconds rounded to another frame, two people stopped to chat one frame apart (day 1, 11:36, Morgan and Christy), the chat drew from the global generator, and from week 13 the wire fraud rolls (global generator too) went another way | `World.new_run()` resets `_total`, rebuilds the cast rows in CAST order (an absence put people at the end of `World.chars`, a row kept a pending sales bell) and the outage timers; the wire fraud, the port scan, the revenge login and the inherited-mess rolls draw from the seeded stream `owner.luck` | `determinism.gd` |

## 2. The numbers, before and after (seeds 1 to 5)

"After" was measured on this branch with `main` merged in (the x13-tech and art merges of Nov 11); the sales cells were also
measured before that merge and gave the same lines.

### Owner, normal (one process: `bot_run.gd -- owner normal careful,shortcut seeds=5 ts=4`)
| | Seed 1 | Seed 2 | Seed 3 | Seed 4 | Seed 5 | Cell |
|---|---|---|---|---|---|---|
| Careful, before: reputation / value | 97 / $793k | 97 / $756k | 100 / $873k | **32** / $387k | 100 / $832k | 4 good 1 bad, rep 85.2, $728k, nobody fired |
| Careful, after | 98 / $857k | 98 / $691k | 100 / $698k | **96** / $850k | 100 / $701k | 5 good, rep 98.4, $759k, nobody fired |
| Shortcut, before | **fired week 15** / $29k | 81 / $300k | 100 / $459k | 23 / $31k | 97 / $165k | fired 1 of 5, $197k, 27% of careful |
| Shortcut, after | 94 / $198k | 89 / $151k | 99 / $424k | 80 / $78k | 88 / $56k | fired 0 of 5, $182k, 24% of careful |

- Target of X13.3 (careful above reputation 60 on all five seeds): met, lowest 96.
- Target of X13.2 (shortcut clearly worse, not removed by a greyed option): met, `CHECK owner normal: shortcut value 181503 vs
  careful 759440 (24%), shortcut fired 0 of 5`. Shortcut seed 5 ends with the bank at -$2,536 and $3,500 still on a dated bill.
- **What the capacity card is worth, said plainly.** The same cell with Morgan's card switched off (`DESK_WARNINGS` 0, same bot)
  ends at 98 / 97 / 100 / 100 / 100, value $758k: on this build no seed drowns without it either. The reputation-32 run of
  before does not come back in either variant; the seeded streams moved (the determinism fix draws the cast's first work legs
  again) and the bot now reads candidates and the books. So the five seeds do not prove that the card rescues a run. What is
  proven is that the game now says it: the row is on every weekly report, and the card comes after two weeks over capacity
  (`x13_owner.gd`); in the traces it is shown on seed 4 in week 5 (answered with the training course) and twice in the runs
  of seeds 1 to 3 (weeks 8 and 13, answered with a hire).
- The first version of the capacity rule (hire whenever Morgan asks) bankrupted careful seed 4 in week 15 (two hires for five
  clients, then net-60 terms accepted with the bank at -$1,523). The bot's final rule reads payroll share and the bank first.

### Owner, hard, careful (`bot_run.gd -- owner hard careful seeds=5 ts=4`)
| | Seed 1 | Seed 2 | Seed 3 | Seed 4 | Seed 5 | Cell |
|---|---|---|---|---|---|---|
| Before | 74 / $687k | **27** / $260k | 87 / $778k | 49 / $218k | 97 / $776k | 3 good 1 mid 1 bad, rep 66.8, $544k |
| After | 89 / $723k | 96 / $822k | 93 / $634k | 87 / $785k | 83 / $220k | 3 good 2 mid, rep 89.6, $637k, nobody fired |

Hard is still below normal (89.6 against 98.4, $637k against $759k) but the gap is smaller than it was: the careful bot's
weak seeds on hard were the ones where the desk drowned or the bank was thin. Seed 5 ends at -$178 in the bank.

### The company value week by week (seed 1, normal, careful; `bot_trace.gd`)
| Week | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Before ($k) | 50 | 40 | 20 | 18 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 41 | 153 | 204 | 290 | 330 | 251 | 592 | 793 |
| After ($k) | 50 | 40 | 24* | 26* | 27* | 29* | 28* | 37* | 42* | 45* | 47* | 116 | 255 | 398 | 537 | 614 | 498 | 558 | 706 | 857 |

`*` = the contracts' floor (the report says `(CONTRACTS)`). Weeks that read $0: 8 before, 0 after, on all 15 owner runs of the
after cells. **The end of the run:** every careful run ends "on earnings" (the BOT line says so), so the floor is not in any
final value: its effect on the end result is 0%. (The final values differ from before for the other reasons in this file.)
A shortcut run that ends with negative earnings ends on the floor (seed 5: $56k).

**The late jump is not an artefact.** Seed 2 goes from $76k (week 18, on contracts) to $428k and $691k; seed 1 takes 35% of
its final value in the last two weeks, seed 2 89%. In week 19 Big Cheese's clients come over (7 to 11 clients in one card) at
nearly full margin, because the fixed costs are already paid; the value is a multiple of the last four weeks' EBITDA, so the
new clients count for a quarter in week 19 and a half in week 20, and the multiple steps up when margin and payroll share
cross their marks. The arithmetic already dampens it; what is left is the story's payoff. Not smoothed. `bot_trace.gd` flags
it as `runaway` on seed 2 (more than x3 in a week) and exits 1 for that: it is a reading aid, not a failure of the game.

### Cards (`bot_trace.gd -- owner normal careful seeds=3 ts=4`)
| | Before | After |
|---|---|---|
| Most repeated decision | 9 x the inbound lead (seed 1), 5 x (seed 3), 3 x (seed 2) | 3 x the marketing budget (weeks 3, 9, 14, by design) |
| Cards shown more than three times with the same text | the inbound lead | none |
| Decisions a week | 6.3 | 6.6 |

Other cards at three: "You now know something about Big Cheese" (once per habit learned), one client's late invoice, one
client's profit review. None is over three, so none was changed.

### Determinism
| | Before | After |
|---|---|---|
| Seed 3 alone | $831,705 | $698,128 |
| Seed 3 as the third run of a process (after seeds 1 and 2) | $872,920 | $698,128 |
| `determinism.gd`, owner part | fails (the office differs at frame 1800 of day 1 after seeds 1 and 2; with forced leftovers at frame 900; the cast is not in CAST order) | passes |

### Sales (`bot_run.gd -- sales easy,normal,hard careful,lazy seeds=5 ts=20`, and `... sales hard careful year2`)
| Cell | Before | After |
|---|---|---|
| Easy careful / lazy | 5 good, rep 99.6 / 5 let go, rep 27.8 | the same lines |
| Normal careful / lazy | 3 good 2 mid, rep 92.8 / 5 let go, rep 19.8 | the same lines |
| Hard careful, year 1 (Q2 / Q3 per seed) | 100/104, 130/84, **78/63 let go**, 121/100, 136/115 | the same quarters, nobody let go (seed 3 stays: 71% of the year) |
| Hard careful, Year 2 | 103/89, 82/111, **76/69 let go**, **91/91 let go**, **98/53 let go** | the same quarters, nobody let go (73%, 91%, 78% of the year) |
| Hard lazy | 4 fired, 1 let go | the same lines |

Which dial: each one alone at a milder value, others at hard (five seeds, year 1 / Year 2 let go):

| Changed alone | Seed 3, year 1 | Let go year 1 | Let go Year 2 |
|---|---|---|---|
| nothing (quota x1.2, lead quality -5, third-lead chance 0.3, rival x1.2) | 78 / 63 | 1 | 3 |
| quota x1.1 | 85 / 69 | 1 | 1 |
| lead quality 0 (the normal value) | 82 / 83 | 1 | 1 |
| third-lead chance 0.5 (the normal value) | 91 / 79 | 2 (seed 1 falls to 95 / 89) | 1 |
| rival x1.0 (the normal value) | 78 / 63 | 1 | 3 |
| `sales.keep` 0.65, nothing else | 78 / 63, kept | 0 | 0 |

Twenty more hard seeds (6 to 25) with the new rule: nobody let go; two of them (97/91 and 78/89) would have been under the
old one. The weakest careful year of the 25 seeds is seed 3 (71% of the year); the best lazy year is 42%.

### The scan (`card_costs.gd -- list`)
406 owner options read, 81 can take money; 220 Service / ServiceArc options, three spend money and all three name dollars.
Found and fixed: the scammed client's three answers; the lawsuit (`ransom_lost`) and the vendor breach, the audit, the fallen
rack and the tool complaint (no harmless answer without money); gambles for money that did not name their stake (they read
`(RISK $n)` now); the sales refund card's half month and the brokered discovery.

### The baseline
`tests/tiers_balance.gd` was run twice on the merged branch: the same 25 BOT lines both times, `failures=0` both times, and
`tools/balance_baseline.py` reported 0 drift against the stored baseline (inside its 20-point / 35% tolerance). The baseline was
then rewritten from that run (`--update --log`). 18 values moved: the tech scores (seed 11: easy 1271 to 1601, normal 1501 to
1851, hard 1154 to 1482, mixed 1292 to 1516 with reputation 77 to 60) and the service cells (normal careful 100 to 90, hard
careful 95 to 89, hard lazy 43 to 35) come with the x13-tech merge (the conference trip, days 18 to 20, the longer 1:1 decks)
and with the cast's first work legs being drawn again at every new game (this branch). The twelve sales cells are unchanged.

## 3. What was built

### `godot/scripts/owner_ops.gd` (new, static helper; in the generator after `owner_cast.gd`)
State is in `Owner.flags` (saved with the campaign): `bills`, `leads_seen`, `desk_over`, `desk_last`, `desk_warned`, `desk_warn_week`.

| Function | What it does |
|---|---|
| `cost(opt) -> [least, most]` | what picking an option can take out of the bank at once: `fx.cash`, a quote that costs more than it pays, a stack fee, every outcome of a `roll`, and `Incident.option_cost` for the scammed client's answers |
| `need(opt, price)` | the option's `need`, or its price when the option has `"pay": true` (a price only known when the card opens) |
| `label(opt, price, later := false)` | the label as shown: `{pay}` / `{risk}` are the two figures; a sure cost the words do not name is added as `($600)`, the worst case of a gamble as `(RISK $3,500)`; `later` takes `label_later` |
| `add_bill(what, amount, weeks := 8)`, `pay_or_bill(what, amount)`, `pay_bills()`, `bills()`, `bills_left()`, `bills_row(paid)` | dated bills: equal parts at each week's close (`Owner.settle`), a `DATED BILLS` row on the report, subtracted from `Owner.valuation()`; never part of EBITDA |
| `later_fx(opt)` | an fx option with `"later": true` that the bank cannot pay: its cash becomes a dated bill, the rest of the fx applies (`Owner._picked`) |
| `LEADS`, `next_story()`, `lead_catch(kind, lead)`, `lead_card(lead, vic_odds)` | the inbound lead stories (`fee`, `mood`, `odds`, `catch`: discount / rush / slow / big, `won`) |
| `desk_over(closed, missed, reopened, open)`, `desk_week(report)`, `desk_card()` | the desk row and Morgan's card (`DESK_WARNINGS` 2, `DESK_GAP` 4 weeks) |

Option keys new in owner cards: `pay` (need = the price), `later` (a dated bill instead of a greyed option), `label_later`, `bill`
(the bill's name, default SETTLEMENT), `{pay}` and `{risk}` in a label.

### Other game changes
| Where | Change |
|---|---|
| `owner.gd` `show_card`, `_picked`, `settle`, `valuation`, `value_text`, `_inbound_lead`, `_desk_morning`, `pay_or_bill`, `_book_value`, `_value_on_book`, `VALUE_FLOOR` 0.25 | as above. `_vendor_breach` and `_audit` insert their new answer at index 1 (a bot whose first answer is greyed takes the next open one) |
| `owner.gd` cards `bec_loss`, `ransom_lost` | `{pay}` / `{risk}` labels, `pay`, `later`, `label_later` |
| `incident.gd` | `option_cost(kind)`; credit, settlement and deductible go through `Owner.pay_or_bill`; all draws from `Difficulty.rng("owner.luck")` |
| `habits.gd`, `takeover.gd` | the port scan, the revenge login and the inherited-mess break-in draw from `owner.luck` |
| `world.gd` `new_run` | resets `_total`, the cast rows (CAST order) and the outage timers |
| `campaign.gd` `_end_day` | owner campaign: `OwnerOps.desk_week(r)` adds the desk row |
| `sales_campaign.gd` | `pip_failed()` reads `year_saves()`; `year_share()`; the warning card, the PERFORMANCE WARNING row, the closing verdict and the review page say so on hard. Labels: `BROKER A SCOPED 15% (2 H, $300)`, `HALF A MONTH BACK (-$%d), A RESET` |
| `difficulty.gd` | `"sales.keep": [0.0, 0.0, 0.65]` |
| `strings.gd` | root `OwnerOps` (`LEADS`) |
| `story/strings.txt` | synced: the new lead stories, the `label_later` strings, the changed labels |

### Bots and tools (`godot/tests/`)
- `bot_lib.gd`: the careful owner credits the scammed client (the option is never greyed now; the thin-bank rule of the last pass
  is gone). On Morgan's desk card he reads the books first: a hire with at least $1,500 in the bank (`OW_HIRE_CASH`), a week
  not worse than -$600 EBITDA (`OW_HIRE_EBITDA`) and payroll at no more than 75% of revenue (`OW_HIRE_W2`, the W-2 RATIO row),
  else the training course, else he stops taking clients. Under water he also looks at the bank before he commits it: no
  net-60 terms for the two biggest invoices under $2,000 (`OW_SQUEEZE_CASH`: 2% off for paying on time instead), LIGHT
  marketing while the bank is below zero. (Without these the first version of the capacity rule hired a second tech for five
  clients on seed 4 and went bankrupt in week 15: capacity and cash have to be read together.) He picks the best
  candidate (`_ow_best_hire`: most skill, a wizard a little ahead, a flight risk well behind) where the bot took the first in
  line. `stop_day` works for owner runs; `row.weeks` also has `mult`, `ebitda`, `open`, `staff`, `book`; the BOT line says
  whether the final value is on contracts, how many weeks read $0, open bills and hires. The greedy policy's rack answer moved
  from index 2 to 3 (`bot_lib.gd`, `owner_balance.gd`): the new cash-free answer sits before THEIR WALL.
- `bot_trace.gd`: the DAY line shows the multiple or `(contracts)`, open tickets and hires.

## 4. Tests
| Test | What it proves |
|---|---|
| `tests/x13_owner.gd` | the scammed client's prices and the dated bill (pay at once, pay over 8 weeks, the report row, the value, the week 15 of the bot's bankruptcy ends alive); the lawsuit settled in parts; the label rules; the desk row and Morgan's card (two weeks, numbers, hiring, the gap, at most twice, through the real week close); ten lead stories each once, the plain one first, size and catch reach the signed client, the stories are in the strings workflow; the value floor and its text |
| `tests/card_costs.gd` (`-- list` prints every option that can take money) | the scan: owner static tables and the run-time builders through `OwnerOps.cost` / `label`, the directly asked owner cards option by option, the Service / ServiceArc tables, the sales beats. Fails on a cost without dollars on the label, a sure cost that is not greyed without the money (and is not a dated bill), an unnamed worst case, and a card that leaves only gambles for money |
| `tests/determinism.gd` (extended, about 2.5 minutes) | owner seed 3, weeks 1 to 3: the office at three moments of day 1 and the books week by week are the same alone, after seeds 1 and 2, and after the leftovers are forced; seed 2 before and after seed 3; a new game puts the cast in CAST order. On the old code it fails on the office after seeds 1 and 2, on the forced leftovers and on the order |
| `tests/sales_hard.gd` (about 2 minutes) | hard, seeds 1 to 5: careful not let go in year 1, at most one in Year 2, lazy fails on all five, hard still below normal; the rule itself on hard, normal and easy |
| `tests/layout_audit.gd` | + the owner report with the DATED BILLS and DESK OVER CAPACITY rows, + the scammed-client card with its long labels (wide, h, v) |
| `tests/bec.gd`, `owner2.gd`, `x9.gd`, `difficulty.gd`, `sales_beats.gd` | adjusted to the new answers (four answers on the vendor breach and the audit), the new dial, the label length rule |

## 5. Decisions made
- **A cost the words do not name is added by code, not by editing every card.** The label text stays the owner's to edit; the
  figure comes from the option's own effects, so it cannot drift from what the option does.
- **A gamble says what is at stake** (`RISK $3,500`). It changes how eleven options read. A hidden stake was the defect.
- **Dated bills instead of a fifth answer.** The honest answer of the scammed-client card and of the lawsuit stays one option:
  pay now, or in eight weekly parts when the bank cannot. No interest: the cost is that the bill counts against the company
  value and against eight weeks of cash.
- **The always-open answers cost something that is not cash**: the vendor breach by hand costs burnout 8, mood 3 and a point of
  team feeling (and earns 1 reputation instead of 2); more time on the audit costs 1 reputation and burnout 6; going to the
  fallen rack yourself costs six of your hours and burnout 2 (client mood +6 against +10 and 2 reputation for $300); promising
  the tool switch for next quarter costs burnout 4 and a point of team feeling.
- **A card where every answer can hurt is not a trap.** The rival's poach cards can lose the client whatever you answer, with
  or without money; the scan only fails a card whose harmless answers are all behind a price.
- **X13.3 is a game gap first.** The reputation line had no cause on the owner's report. The fix is the row and the card; the
  HUD's goal chip was left alone (the report and Morgan cover it).
- **Morgan's desk card comes at most twice** (the repeat rule of X13.5 applied to my own card); the report row is there every week.
- **Sales hard: the review threshold, not the inputs.** Easing quota, lead quality or flow enough to carry the weakest seed would
  have made hard the normal tier with another name. The texture of hard (fewer, colder leads, a stronger rival, a x1.2 quota)
  is unchanged; what changed is that a careful year that came close is not thrown out. 65% sits between the worst careful year
  of 25 seeds (71%) and the best lazy one (42%).
- **The careful sales bot was not made smarter** (it never takes the crunch discount and always picks the standard quota), so that
  easy and normal read exactly as before.
- **The value floor is 25% of a year's recurring revenue**, with the same reputation and age discounts as the earnings value. It
  does not touch a company whose earnings value is higher, so the end of a healthy run is unchanged.
- **The late jump of the value is not an artefact** (see the numbers): it is the week 19 clients at nearly full margin, averaged
  over four weeks. Left as it is.
- **`World.new_run` rebuilds the cast rows.** It draws the first work leg of everybody from the run's seed again, so every seeded
  run changed a little (the baseline was rewritten).

## 6. Left open, and for the coordinator
- `story/strings.txt` was synced here (sections `Owner > CARDS`, `SalesCampaign > BEAT_TEXT`, new `OwnerOps > LEADS`); sync again
  after the merge if another branch touched the same sections.
- `docs/dev/balance_baseline.json` and `docs/balance-notes.md` were updated here (the ban was lifted for both).
- Art wanted: none. Sound: none.
- The hard owner cell still has a low seed (see the table): reputation, not money, and nobody is fired.
- The first lines of this file's tables are bot numbers; a human pass over the new card texts (ten lead stories, Morgan's two
  desk cards, the two new answers) is still worth it: they are first drafts.
