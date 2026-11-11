# Build notes: X13, the owner and sales findings of the bot runs

Branch `worktree-agent-a48c31fc1f375ac38`, Nov 2026. Row X13 of `docs/ROADMAP.md`, the owner and sales half (the tech half and the
service 1:1 cards are another agent's). Every fix has a test and was measured with the bots of `tests/bot_lib.gd` on seeds 1 to 5
before and after, one Godot process at a time, owner at ts=4, sales at ts=20. "Before" is commit `24ab53b` (a copy of `godot/`
taken before the first edit), "after" is this branch. The tables are also in `docs/balance-notes.md` (section "Nov 2026: X13").

## 1. What was wrong, and what was done

| # | Finding | Cause | Fix | Test |
|---|---|---|---|---|
| 1 | The scammed-client card's 40% credit cost $2,000 and more, with no price and no `need` | `bec_loss` option 0 took `Incident.credit_amount()` inside `Incident.owner_fx`; the label and `show_card` knew nothing of it. The lawyer ($600) could lose half the loss on top, the insurer the whole credit, also unnamed | Every owner option now has a cost (`OwnerOps.cost`: the least and the most it can take) and the card shows it (`OwnerOps.label`). The credit names its price; a bank that cannot pay it pays it as a **dated bill** over 8 weeks (never greyed); the lawyer's and the insurer's worst case are on the label and are billed the same way when the bank is short | `x13_owner.gd`, `card_costs.gd`, `bec.gd` |
| 1b | The same defect elsewhere | Scan of every card (`card_costs.gd`, 404 owner options, 81 can take money; 154 service options; the sales beats) | Gambles for money say `(RISK $n)` (11 options, added by `OwnerOps.label`, no text edited); the lawsuit after lost files can be settled in parts; the sales refund card's half month and the brokered discovery name dollars; service had none | `card_costs.gd` |
| 2 | The shortcut owner was fired on seed 1: with $214 the safe vendor-breach answer ($600) was greyed and the gamble lost | A card whose only cash-free answer is a gamble, or does lasting damage | The vendor breach, the audit and the lawsuit each have an answer no bank balance can grey out, with a real cost that is not cash (a tired crew, reputation, a dated bill). The scan fails on any card that leaves only gambles for money, and on any card whose harmless answers all cost money while the open ones can lose a client, a tech or 3 reputation: that found the rack that fell off the wall (the broke owner's only answer lost the client three times in ten) and the crew's tool complaint (four in ten somebody quits); both have a cash-free answer now | `card_costs.gd`, `x13_owner.gd` |
| 3 | Careful owner, normal, seed 4: reputation 32 with healthy books | A game gap first, then a bot gap. The week's reputation change is the desk's (closes against missed clocks and tickets left open) and the owner's weekly report showed only money: nothing said why the name was falling | A **SERVICE DESK** row on the weekly report (`DESK OVER CAPACITY` in red when the loose ends outweigh the closes) and, after two such weeks in a row, a card from Morgan with the numbers and three ways out (hire, train, stop taking clients); at most twice a run. The careful bot looks at candidates when she says so and picks the best one instead of the first | `x13_owner.gd`, `layout_audit.gd` |
| 4 | Sales hard: a careful bot let go on 1 seed of 5 in year 1, 3 of 5 in Year 2 | No single input dial: with the quota at x1.1, the lead quality at normal, the lead flow at normal or the rival at normal the weak seed still misses both quarters. It is the review rule (two misses, however close) meeting the x1.2 quota | New hard-only dial `sales.keep` 0.65: two missed quarters end the job only when the two quarters together came in under 65% of the year's quota. Quota, lead quality, lead flow and rival strength on hard are unchanged; easy and normal are unchanged | `sales_hard.gd`, `difficulty.gd` |
| 5 | The inbound-lead card came up to 9 times with the same text | One hard-coded text | Ten lead stories (`OwnerOps.LEADS`, in `story/strings.txt`): another client situation, size, starting mood, odds and catch each; every story at most once in a run, the plain one first; when they run out John takes the meeting and texts the result | `x13_owner.gd` |
| 6 | Company value $0 in weeks 5 to 12 | The value is a multiple of the last four weeks' EBITDA plus cash; while the owner invests (a hire in week 3, marketing, the backup service) that average is negative and the bank is near zero, so `maxi(0, ...)` cut it to nothing | A floor: the contracts alone are worth 25% of a year's recurring revenue (cut by the same reputation and age discounts). The report says `(CONTRACTS)` instead of the multiple while the floor holds | `x13_owner.gd` |
| 7 | One owner seed, two results (seed 3: $831,705 alone, $872,920 after seeds 1 and 2) | `World._total` (the office's running time) was never reset. `World.try_chat` stores `_total - 60 + 3` and compares `_total - stored` with the cooldown: with a `_total` thousands of seconds larger the same three seconds rounded to another frame, two people stopped to chat one frame apart (day 1, 11:36, Morgan and Christy), the chat drew from the global generator, and from week 13 the wire fraud rolls (global generator too) went another way | `World.new_run()` resets `_total`, rebuilds the cast rows in CAST order (an absence put people at the end of `World.chars`, a row kept a pending sales bell) and the outage timers; the wire fraud, the port scan, the revenge login and the inherited-mess rolls draw from the seeded stream `owner.luck` | `determinism.gd` |

## 2. The numbers, before and after (seeds 1 to 5)

@@NUMBERS@@

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
| `tests/card_costs.gd` (`-- list` prints every option that can take money) | the scan: owner static tables and 23 run-time builders through `OwnerOps.cost` / `label`, the directly asked owner cards option by option, the Service / ServiceArc tables, the sales beats. Fails on a cost without dollars on the label, a sure cost that is not greyed without the money (and is not a dated bill), an unnamed worst case, and a card that leaves only gambles for money |
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
