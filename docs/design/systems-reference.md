# MSPSim systems and content reference

Generated file: do not edit by hand. It is written from the game's own data tables by `godot/tests/make_systems_reference.gd`, so every number here
is read from the code at the time of generation. Regenerate after content changes with one command, from the repository root:

```
"C:\Program Files\Godot\Godot.exe" --headless --path godot -s res://tests/make_systems_reference.gd
```

`python tools/check_systems_reference.py` regenerates to a temporary file and lists which sections changed against this one.
The test `tests/systems_reference.gd` warns (never fails) when the committed copy has drifted.

This is the "tables of everything" companion to the design document: it quantifies the game (modes, people, tickets, cards, outings, medals,
rooms, controls) the way the original Grand Theft Auto design document listed every object with its attributes. The game is set in 2013-14.
Where a rule is not stored in a table, the section either quotes the script text (marked "text scan") or says "not data driven" and names the file.

## Contents

- 1. Modes and structure
- 2. The cast
- 3. Tickets and fixes
- 4. Cards and story
- 5. Outings and mini-games
- 6. Progression
- 7. Rooms and scenes
- 8. Controls and settings
- 9. Technical facts

## 1. Modes and structure

### 1.1 The four campaigns

One row per campaign mode (Free Play is a separate flag, see below). `day_len` is seconds per in-game day at normal day length. Source: `scripts/campaign.gd MODE_DEFS`. Rows: 4.

| mode | label | selectable | unit | days | day_len s | review | review pages | crew pace | year 2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tech | TECH CAMPAIGN | true | DAY | 20 | 600.0 | yearly | 2 | 1.0 | true |
| owner | OWNER CAMPAIGN | true | WEEK | 20 | 240.0 | board | 3 | 0.6 | true |
| service | SERVICE CAMPAIGN | true | DAY | 20 | 360.0 | service | 2 | 0.62 | true |
| sales | SALES CAMPAIGN | true | WEEK | 20 | 240.0 | sales | 2 | 0.55 | true |

### 1.2 Machinery gates per mode

Which systems each mode runs: the crew works the queue, the books (cash, P&L), the weekly decision cards, the lite books of the sales mode. Source: `scripts/campaign.gd MODE_DEFS`. Rows: 4.

| mode | crew | books | cards | books lite | HUD | report | shift | scars | fired text |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tech | false | false | false | false | day_rep | day | true | true | REPUTATION GONE. YOU ARE FIRED. |
| owner | true | true | true | false | week_cash | pnl | false | false | YOUR NAME IS MUD. THE COMPANY CLOSES. |
| service | true | false | true | false | day_rep | day | false | false | MORGAN HAS LOST CONFIDENCE. THE DESK GOES TO SOMEONE ELSE. |
| sales | true | true | true | true | week_quota | pnl | false | false | GARRISON LETS YOU GO. THE PIPELINE STAYS. |

Free Play: `Campaign.FREE` = `free` (no days, no ending; the toolbox, mutators and outings are open). Total days in a year: `Campaign.TOTAL_DAYS` = 20.

### 1.3 Years 1 to 3

Year 1 is the base campaign. Year 2 (New Game Plus) and Year 3 add beats on given days or weeks and their own endings. `beats` lists beat id = day or week. Source: `scripts/yeartwo.gd DEFAULT_YEAR2 / DEFAULT_YEAR3`. Rows: 4.

| mode | days in year | Y2 beats | Y2 beat id = day | Y3 beats | Y3 beat id = day | Y2 endings | Y3 endings |
| --- | --- | --- | --- | --- | --- | --- | --- |
| tech | 20 | 2 | courted=6, desk=11 | 3 | newhire=3, mentor=11, fork=18 | 2 | 3 |
| owner | 20 | 2 | merger=10, franchise=15 | 3 | summit=6, staff=12, handover=17 | 2 | 3 |
| service | 20 | 1 | headhunt=8 | 3 | deputy=4, terry=10, table=16 | 0 | 3 |
| sales | 20 | 2 | poach=9, director=14 | 3 | wes=5, split=11, chair=16 | 0 | 3 |

Year chapters: `Yeartwo.YEAR` = 2, `Yeartwo.LAST_YEAR` = 3 (no year 4). Year 2 SLA multiplier 0.85, Year 3 SLA multiplier 0.76.

### 1.4 Year 2 changes

What the second year changes on top of the carried-over run. Source: `scripts/yeartwo.gd DEFAULT_YEAR2`. Rows: 4.

| key | value |
| --- | --- |
| tickets | weights=spooler=1.7, av=1.7, password=1.3, server=1.6, p1_promote=0.12, text=MORE PRINTER AND SECUR... |
| clients | client=Paws and Claws Veterinary, Lindqvist and Moss Architects, Iron Mule Demolition, max=10, text... |
| mutators | counts=easy=2, 3, normal=4, 5, hard=5, 6, text=ONE TIER MORE MUTATORS. |
| shuffle | max_shift=2, text=THE YEAR'S BIG JOBS MOVE AROUND BY A DAY OR TWO., tech=min_day=3, books=rdp, ceof... |

### 1.5 Year 1 endings and what each needs (text scan)

Offered at the end of the first year. The need column is the `if` line in front of the offer, quoted from the source; `otherwise` and `always` mean no gate. Not stored as data. Source: `scripts/review.gd make_offers, owner.gd _base_offers, service.gd review_offers, sales_campaign.gd offers`. Rows: 16.

| mode | ending id | gate (source line) | where |
| --- | --- | --- | --- |
| tech | lead | if Campaign.rep >= (55 if Growth.graduated else 60) and Social.average() >= 0.0 | text scan: review.gd make_offers() |
| tech | internal | if Campaign.rep >= 45 | text scan: review.gd make_offers() |
| tech | stay | always | text scan: review.gd make_offers() |
| owner | sell | always | text scan: owner.gd _base_offers() |
| owner | expand | if cash >= 10000 and Campaign.rep >= 55 and Sales.active.size() >= 6 | text scan: owner.gd _base_offers() |
| owner | stay | always | text scan: owner.gd _base_offers() |
| service | ops | if ta >= 55 and tg >= 55 and Campaign.rep >= 60 | text scan: service.gd review_offers() |
| service | alan | if ta >= 55 and ta >= tg and Campaign.rep >= 60 | text scan: service.gd review_offers() |
| service | garrison | if tg >= 55 and tg >= ta and Campaign.rep >= 60 | text scan: service.gd review_offers() |
| service | leave | if Campaign.rep >= 45 | text scan: service.gd review_offers() |
| service | stay | always | text scan: service.gd review_offers() |
| sales | leave | always | text scan: sales_campaign.gd offers() |
| sales | let_go | if pip_failed() | text scan: sales_campaign.gd offers() |
| sales | director | otherwise and if director_ok() | text scan: sales_campaign.gd offers() |
| sales | stay | otherwise | text scan: sales_campaign.gd offers() |
| sales | rollup | otherwise and if SalesBeats.rollup_ok() | text scan: sales_campaign.gd offers() |

### 1.6 Year 2 and Year 3 endings

Year 3 thresholds come from the `needs` table (rep = reputation, clients, trust). Year 2 gates are in `_offer_ok` (not data driven). Source: `scripts/yeartwo.gd DEFAULT_YEAR2 / DEFAULT_YEAR3`. Rows: 16.

| year | mode | ending id | needs |
| --- | --- | --- | --- |
| Y2 | tech | head | see Yeartwo._offer_ok (not data driven: scripts/yeartwo.gd) |
| Y2 | tech | clientbuy | see Yeartwo._offer_ok (not data driven: scripts/yeartwo.gd) |
| Y2 | owner | merger | see Yeartwo._offer_ok (not data driven: scripts/yeartwo.gd) |
| Y2 | owner | franchise | see Yeartwo._offer_ok (not data driven: scripts/yeartwo.gd) |
| Y3 | tech | y3_chair | rep=60 |
| Y3 | tech | y3_senior | rep=55 |
| Y3 | tech | y3_farewell | rep=50 |
| Y3 | owner | y3_summit | rep=55, clients=6 |
| Y3 | owner | y3_staff | rep=55 |
| Y3 | owner | y3_morgan | rep=55 |
| Y3 | service | y3_coo | rep=60 |
| Y3 | service | y3_partner | rep=60, trust=50 |
| Y3 | service | y3_across | rep=50 |
| Y3 | sales | y3_director | rep=55 |
| Y3 | sales | y3_wes | rep=50 |
| Y3 | sales | y3_stake | rep=60 |

Other ways a run ends: fired at zero reputation (`ending_fired` in 1.2); owner-mode partner endings (buyout, sellout, left) from `scripts/owner.gd _ending_text` (not data driven).

### 1.7 Difficulty tiers

Three tiers (easy is the cozy tier). The line shown under the tier picker for each campaign. Source: `scripts/difficulty.gd TIER_NOTES`. Rows: 12.

| mode | tier | tier note |
| --- | --- | --- |
| tech | easy | COZY TECH: NOBODY GETS FIRED, THE USERS ARE PATIENT AND THE COFFEE IS ALWAYS HOT. |
| tech | normal | TECH AS ISSUED. THE PRINTER STILL HATES YOU AND THE USERS STILL CLICK EVERYTHING. |
| tech | hard | TECH ON FIRE. SHORT CLOCKS, LOUD USERS AND SOMEBODY ALWAYS HAS A DEADLINE. |
| service | easy | COZY DESK: A LOVELY CREW, GENTLE CLOCKS AND OWNERS WHO ONLY SIGH QUIETLY. |
| service | normal | THE DESK AS IT IS. TWO OWNERS, TWO OPINIONS, ONE DAN. |
| service | hard | THE OWNERS DISAGREE LOUDER AND THE CREW GETS STUCK AT THE WORST TIMES. |
| sales | easy | COZY SALES: FRIENDLY LEADS, A GENTLE QUOTA AND THE BELL RINGS A LOT. |
| sales | normal | THE USUAL PIPELINE. EVERYONE LOVES YOU UNTIL THEY SEE THE PRICE. |
| sales | hard | A THIN PIPELINE, CLIENTS WHO HAGGLE AND BYTEBROTHERS CIRCLING. |
| owner | easy | COZY OWNER: A KIND BANK, A KIND STAFF AND PAYROLL ALWAYS CLEARS. |
| owner | normal | RUNNING THE SHOP. EVERY DOLLAR HAS AN OPINION. |
| owner | hard | THIN MARGINS, TOUCHY CLIENTS AND A RIVAL ALWAYS ONE STEP AHEAD. |

Day length option (x on the mode's `day_len`): 0.5, 1.0, 1.5. Mastery ramp: `RAMP_PLAYS` = 10 good plays to full mastery, easy blends 0.35 of the way, hard goes at most 0.25 beyond its own value.

### 1.8 Difficulty table (every key)

Every `Difficulty.TABLE` dial, grouped by area (the part of the key before the dot). `mastery` marks the keys that tighten with the per-game mastery ramp. Source: `scripts/difficulty.gd TABLE`. Rows: 68.

| area | key | easy | normal | hard | mastery |
| --- | --- | --- | --- | --- | --- |
| bowl | bowl.aim_speed | 1.1 | 1.5 | 2.0 | yes |
| bowl | bowl.oil | 0.85 | 1.0 | 1.15 | yes |
| bowl | bowl.opp_skill | -0.08 | 0.0 | 0.08 | yes |
| bowl | bowl.power_speed | 0.9 | 1.2 | 1.6 | yes |
| bowl | bowl.spin_noise | 0.7 | 1.0 | 1.4 | yes |
| chair | chair.crash | 0.7 | 1.0 | 1.5 | yes |
| chair | chair.par | 1.2 | 1.0 | 0.9 | yes |
| chair | chair.skill | -0.08 | 0.0 | 0.08 | yes |
| chair | chair.slick | 0.8 | 1.0 | 1.3 | yes |
| chair | chair.stamina | 0.9 | 1.0 | 1.1 | yes |
| corn | corn.aim_speed | 1.0 | 1.3 | 1.7 | yes |
| corn | corn.assist | 1 | 0 | 0 |  |
| corn | corn.opp_skill | -0.08 | 0.0 | 0.06 | yes |
| corn | corn.power_speed | 0.8 | 1.1 | 1.5 | yes |
| corn | corn.to | 11 | 15 | 21 |  |
| crew | crew.pace | 1.1 | 1.0 | 0.9 |  |
| crew | crew.sla | 1.15 | 1.0 | 0.85 |  |
| darts | darts.drift | 46.0 | 58.0 | 70.0 | yes |
| darts | darts.noise | 6.0 | 7.0 | 8.0 |  |
| darts | darts.opp_skill | -0.08 | 0.0 | 0.06 | yes |
| darts | darts.speed | 1.5 | 1.9 | 2.4 | yes |
| dinner | dinner.expect | 0.0 | 0.0 | 0.4 | yes |
| dinner | dinner.fits | 3.0 | 2.0 | 1.0 | yes |
| dinner | dinner.hints | 1.0 | 1.0 | 0.5 | yes |
| dinner | dinner.reveal | 3 | 3 | 2 |  |
| escape | escape.dial | 1 | 1 | 0 |  |
| escape | escape.digits | 3 | 3 | 4 |  |
| escape | escape.hint_penalty | 5.0 | 0.0 | 0.0 |  |
| escape | escape.time | 150.0 | 120.0 | 105.0 | yes |
| escape | escape.wrong_penalty | 5.0 | 10.0 | 15.0 | yes |
| grill | grill.cook_rate | 0.85 | 1.0 | 1.25 | yes |
| grill | grill.dogs | 0.3 | 0.35 | 0.4 |  |
| grill | grill.flare | 0.5 | 1.0 | 1.5 |  |
| grill | grill.tickets | 5 | 6 | 6 |  |
| grill | grill.time | 85 | 75 | 68 | yes |
| grill | grill.window | 1.3 | 1.0 | 0.8 | yes |
| karaoke | karaoke.gap | 0.95 | 0.75 | 0.55 | yes |
| karaoke | karaoke.good | 0.36 | 0.3 | 0.24 | yes |
| karaoke | karaoke.grace | 0 | 0 | 2 |  |
| karaoke | karaoke.grace_drain | 6.0 | 6.0 | 3.0 |  |
| karaoke | karaoke.perfect | 0.16 | 0.12 | 0.09 | yes |
| nerf | nerf.gap | 1.35 | 1.0 | 0.7 |  |
| owner | owner.cost | 0.95 | 1.0 | 1.03 |  |
| owner | owner.gain | 1.2 | 1.0 | 0.5 |  |
| owner | owner.loss | 0.75 | 1.0 | 1.8 |  |
| paint | paint.acc | 1.1 | 1.0 | 0.9 |  |
| paint | paint.skill | 0.8 | 1.0 | 1.25 | yes |
| printer | printer.chain | 3 | 3 | 5 |  |
| printer | printer.questions | 1 | 2 | 3 |  |
| printer | printer.speed | 0.8 | 1.0 | 1.25 | yes |
| printer | printer.zone | 1.3 | 1.0 | 0.95 | yes |
| rep | rep.gain | 1.2 | 1.0 | 0.8 |  |
| rep | rep.loss | 0.75 | 1.0 | 1.3 |  |
| sales | sales.flow | 0.65 | 0.5 | 0.3 |  |
| sales | sales.keep | 0.0 | 0.0 | 0.65 |  |
| sales | sales.lead | 5 | 0 | -5 |  |
| service | service.trust | 0.7 | 1.0 | 1.6 |  |
| tech | tech.alt_ret | 0.8 | 1.0 | 1.3 |  |
| tech | tech.clean | 0.0 | 1.0 | 0.0 |  |
| tech | tech.drain | 0.9 | 1.0 | 2.0 |  |
| tech | tech.gain | 1.25 | 1.0 | 0.4 |  |
| tech | tech.heavy_fail | 0.0 | 0.0 | 0.25 |  |
| tech | tech.heavy_slow | 1.0 | 1.0 | 1.3 |  |
| tech | tech.loss | 0.75 | 1.0 | 2.2 |  |
| tech | tech.onsite_mood | 3.0 | 2.0 | 1.0 |  |
| tech | tech.pace | 1.25 | 1.0 | 0.45 |  |
| tech | tech.pair | 0.0 | 0.0 | 0.7 |  |
| tech | tech.sla | 1.3 | 1.0 | 0.4 |  |

### 1.9 Cozy tier dials

What the easy (cozy) tier changes outside the mini-games. Source: `scripts/difficulty.gd COZY`. Rows: 10.

| key | value |
| --- | --- |
| rep_floor | 15 |
| bailout | 2000 |
| sla_window | 1.6 |
| sla_mood | -2 |
| reopen_mood | -1 |
| ransom_rep | -5 |
| drain | 0.5 |
| poach | 0.5 |
| first_ticket | 20.0 |
| page_chance | 0.25 |

### 1.10 Tier perks outside the table

Per-tier numbers kept in other scripts: character build points, sales quota multiplier, rival bid multiplier, mutator count range. Source: `scripts/build.gd BUDGET, sales_campaign.gd TIER_QUOTA, deals.gd TIER_RIVAL, mutators.gd COUNT_BY_TIER`. Rows: 3.

| tier | build points | quota x | rival bid x | mutators (min, max) |
| --- | --- | --- | --- | --- |
| easy | 15 | 0.8 | 0.8 | 0, 1 |
| normal | 12 | 1.0 | 1.0 | 2, 3 |
| hard | 9 | 1.2 | 1.2 | 4, 5 |

## 2. The cast

### 2.1 Named people

Everyone who has a desk in the office, with the scene they start in, their seat and their title. Source: `scripts/world.gd CAST / CREW_CAST / STAFF_CAST, social.gd ROLES, roles.gd JOBS`. Rows: 13.

| name | group | character file | role | title | job (in the role map) | home scene | seat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Alan | main cast | office_alan |  | CO-OWNER | tech owner | office_one | Seat1 |
| Garrison | main cast | casual_garrison |  | CO-OWNER | sales owner | office_two | Seat1 |
| Dan | main cast | office_dan |  | SERVICE MANAGER | network | main_floor | Seat3 |
| John | main cast | office_john | sales | ACCOUNT MANAGER | accounts | cubicle_area | Seat1 |
| Maya | main cast | office_maya |  | TIER 1 | tier1 | main_floor | Seat2 |
| Morgan | main cast | office_morgan | manager | MANAGER | manager | cubicle_area | Seat2 |
| Sam | crew (owner / service) | office_intern | crew |  |  | main_floor | Seat1 |
| Terry | crew (owner / service) | office_adult | crew |  |  | conference | Seat6 |
| Jen | staff (family of the office) | office_jen | frontdesk | OFFICE MANAGER |  | cubicle_two | Seat1 |
| Michael | staff (family of the office) | office_michael | tech | TECH |  | cubicle_two | Seat2 |
| Christy | staff (family of the office) | office_christy | finance | CONTROLLER |  | cubicle_two | Seat3 |
| Adam | staff (family of the office) | office_adam | senior |  |  | cubicle_two | Seat4 |
| Quinn | staff (family of the office) | office_quinn | newhire |  |  | conference | Seat6 |

Counts: 6 main cast + 2 crew + 5 staff = 13 people with a seat.

### 2.2 The crew

The service-desk crew in the owner, service and sales campaigns: area levels (0 to 3), base speed, weekly wage, tier lane. Source: `scripts/crew.gd ROSTER / WAGES / START_LANE`. Rows: 3.

| name | tier | speed | powershell | networking | servers | security | people | wage $/week | lane |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Maya | TIER 1 | 1.0 | 1.0 | 2.0 | 2.0 | 1.0 | 3.0 | 700 | L2 |
| Sam | TIER 1 | 0.7 | 0.0 | 1.0 | 1.0 | 1.0 | 2.0 | 450 | L1 |
| Terry | TIER 1 | 0.9 | 1.0 | 1.0 | 2.0 | 2.0 | 1.0 | 550 | L2 |

### 2.3 Clients

The client companies (tickets, onsite visits and sales). `site type` and `drive` exist only for clients with an onsite job site. Source: `scripts/msp.gd CLIENTS, onsite.gd SITES / DRIVE_MINUTES`. Rows: 11.

| index | name | short | contact | site type | site skin | drive min |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Acme Dental Group | ACME | Dr. Patel | dental | a | 20 |
| 1 | Brightside Realty | BRSD | Karen Whitfield | realty | a | 35 |
| 2 | Gnarly Gnomes Landscaping | GNGN | Bob Gnarly |  |  |  |
| 3 | Hoot and Holler Law | HHLW | Atty. Spence | law | a | 25 |
| 4 | Soggy Bottom Brewing | SGBB | Lucy Malt |  |  |  |
| 5 | Piedmont Pediatrics | PEDI | Dr. Okafor |  |  |  |
| 6 | Rusty Anchor Marine Supply | RSTY | Gil Anchor |  |  |  |
| 7 | Zen Garden Yoga | ZENY | Mina Park |  |  |  |
| 8 | Paws and Claws Veterinary | PAWS | Dr. Brandt | vet | a | 50 |
| 9 | Lindqvist and Moss Architects | LMAR | Erik Lindqvist | arch | a | 30 |
| 10 | Iron Mule Demolition | IMUL | Tony Marsh | trailer | a | 70 |

### 2.4 People at client sites

How many people stand in each type of client site (variants a and b, rooms, people placed). Source: `scripts/onsite.gd CAST_AT`. Rows: 6.

| site type | variants | rooms | people placed |
| --- | --- | --- | --- |
| dental | 2 | 6 | 8 |
| vet | 2 | 6 | 8 |
| law | 2 | 4 | 6 |
| arch | 2 | 4 | 6 |
| realty | 2 | 4 | 6 |
| trailer | 2 | 4 | 5 |

### 2.5 People at the trade expo

The expo crowd per scene, by role. Source: `scripts/conference.gd CROWD`. Rows: 8.

| scene | people | roles |
| --- | --- | --- |
| resort_lobby | 6 | checkin=1, att=2, forum=3 |
| resort_hall | 5 | att=2, forum=3 |
| ballroom | 3 | att=3 |
| breakout_a | 5 | speaker=1, att=2, audience=2 |
| breakout_b | 5 | speaker=1, att=2, audience=2 |
| breakout_c | 5 | speaker=1, att=2, audience=2 |
| breakout_d | 5 | speaker=1, att=2, audience=2 |
| vendor_hall | 7 | vendor=3, att=2, forum=2 |

### 2.6 Forum characters at the expo

The forum people met at the expo, each with a choice card. Source: `scripts/conference.gd FORUM`. Rows: 8.

| id | speaker | options |
| --- | --- | --- |
| priest | MPriest (Priest Michael, forum mod, Australia) | 4 |
| grizzle | GrizzleAdmin (the forum admin since 2008) | 4 |
| pip | HELPPLZ_Pip (forum newbie) | 4 |
| ray | RTFM_Ray (forum regular) | 4 |
| rita | RegexRita (forum regular) | 4 |
| tony | TapeTony (forum regular) | 4 |
| walt | WSUS_Walt (forum regular) | 4 |
| dot | DNS_Dot (forum regular) | 4 |

### 2.7 Outing guests and visitors

Who joins a team outing and how likely they come; the client guest pool for dinners follows. Source: `scripts/outings.gd DEFAULT_GUESTS`. Rows: 6.

| name | code | comes (chance) |
| --- | --- | --- |
| Alan | AL | 0.9 |
| Garrison | GA | 0.9 |
| Dan | DA | 0.8 |
| John | VI | 0.65 |
| Maya | MA | 0.7 |
| Morgan | MO | 0.25 |

Dinner guest pool (clients and owners who can sit at the table): 8 people (`Outings.GUEST_POOL`).

### 2.8 Character files

Sprite files per folder (a person is a left and a right file). Counted from the file system. Source: `sprites/<group>/*.aseprite (file system)`. Rows: 4.

| folder | stills | animations | people (stills / 2) |
| --- | --- | --- | --- |
| staff | 38 | 38 | 19 |
| clients | 44 | 44 | 22 |
| expo | 48 | 48 | 24 |
| custom | 20 | 20 | 10 |

Total character stills: 150.

## 3. Tickets and fixes

### 3.1 Base ticket problem types

The everyday problems a client can call in. `fix` is the correct fix; `pri` 1 is the most urgent. Source: `scripts/msp.gd DEFAULT_PROBLEMS / DEFAULT_RANSOM / DEFAULT_ADOBE`. Rows: 8.

| problem | fix | priority | special |
| --- | --- | --- | --- |
| Printer will not print | spooler | 3 | no |
| Locked out of my PC | password | 2 | no |
| Computer is very slow | clear_temp | 3 | no |
| Computer frozen on a blue screen | reboot | 2 | no |
| Pop-ups everywhere | av | 2 | no |
| Server not responding - nobody can work | reboot | 1 | no |
| Files encrypted - ransom note on the server | restore | 1 | ransomware (server) |
| Adobe Reader will not print | adobe | 4 | special: Adobe |

### 3.2 New-desktop install items

The checklist of the desktop replacement job (`key` items are the ones that must not be missed; `hidden` ones show only on some difficulty or ask paths). Source: `scripts/msp.gd INSTALL_ITEMS`. Rows: 8.

| id | item | key item | seconds | hidden for |
| --- | --- | --- | --- | --- |
| docs | MY DOCUMENTS (OFFICE 2003 FILES) | true | 3.0 |  |
| mail | OUTLOOK 2003 PROFILE + PST | true | 3.0 |  |
| desktop | DESKTOP FILES | false | 1.5 |  |
| printers | PRINTERS | false | 1.0 |  |
| bookmarks | BROWSER BOOKMARKS | false | 1.0 |  |
| xray | XRAY SOFTWARE + XP DRIVERS | true | 2.5 | both |
| drives | MAPPED DRIVES | false | 1.0 | deep |
| sticky | STICKY NOTES | false | 0.5 | ask |

### 3.3 Fixes

Every fix button in the ticket tool. `area` is the crew skill area that does it, `XP area` where the player gains skill, `crew level` the area level a crew member needs, `alt` the other accepted fix, `heavy` fixes that need an onsite visit. Source: `scripts/msp.gd FIXES / ALT_FIXES / HEAVY_ONSITE, crew.gd FIX_AREA / FIX_NEED, skills.gd FIX_XP`. Rows: 13.

| fix id | button | crew area | XP area | crew level gate | alt fix | heavy onsite |
| --- | --- | --- | --- | --- | --- | --- |
| spooler | RESTART PRINT SPOOLER | networking | networking | 1 | reboot |  |
| password | RESET PASSWORD | security | security | 1 |  |  |
| clear_temp | CLEAR TEMP FILES | powershell | servers | 1 |  |  |
| reboot | REBOOT | servers | servers | 1 |  |  |
| av | RUN AV SCAN | security | security | 2 |  |  |
| restore | RESTORE BACKUP | security | security | 2 |  |  |
| adobe | REPAIR ADOBE READER | servers | servers | 1 |  |  |
| shadow | SHADOW COPIES |  |  |  |  |  |
| pay | PAY THE RANSOM |  |  |  |  |  |
| save | ASK USER TO SAVE |  |  |  |  |  |
| vendor | VENDOR VERSIONS |  |  |  |  |  |
| rebuild | ISOLATE+REBUILD |  |  |  |  |  |
| insurer | CALL INSURER |  |  |  |  |  |

### 3.4 Fix time and fail chance by skill level

Seconds a fix takes and the chance it fails, by the player's PowerShell level. `XP needed` is the experience to reach that level. Source: `scripts/skills.gd FIX_SECS / FAIL / XP_AT`. Rows: 6.

| level | fix seconds | fail chance | XP needed |
| --- | --- | --- | --- |
| 0 | 6.0 | 0.25 | 0 |
| 1 | 5.0 | 0.18 | 15 |
| 2 | 4.0 | 0.1 | 40 |
| 3 | 3.0 | 0.04 | 80 |
| 4 | 2.0 | 0.0 | 130 |
| 5 | 1.5 | 0.0 | 200 |

### 3.5 Alternative fixes

Cheaper or riskier ways to handle a problem. `mult` scales the time, `ret` is the chance the problem returns. Source: `scripts/msp.gd ALT_DEFS`. Rows: 18.

| id | label | for fix | kind | time x | xp | return chance |
| --- | --- | --- | --- | --- | --- | --- |
| clear_queue | CLEAR PRINT QUEUE | spooler | quick | 0.4 | 2 | 0.45 |
| reinstall_printer | REINSTALL PRINTER | spooler | heavy | 3.0 | 3 |  |
| copier_route | PRINT TO COPIER | spooler | clever | 0.5 | 6 |  |
| temp_pass | GIVE TEMP PASSWORD | password | quick | 0.4 | 1 | 0.5 |
| new_profile | REBUILD PROFILE | password | heavy | 4.0 | 3 |  |
| unlock_ps | UNLOCK-ADACCOUNT | password | clever | 0.5 | 6 |  |
| recycle | EMPTY RECYCLE BIN | clear_temp | quick | 0.4 | 2 | 0.6 |
| disk_script | CLEANUP SCRIPT | clear_temp | clever | 0.5 | 6 |  |
| browser_reset | RESET BROWSER | av | quick | 0.4 | 1 | 0.5 |
| spyhunt | SPYHUNT LOG SCAN | av | clever | 0.6 | 7 |  |
| reimage | REIMAGE PC | clear_temp, av, reboot | heavy | 7.0 | 3 |  |
| last_good | LAST KNOWN GOOD | reboot | quick | 0.6 | 2 | 0.35 |
| safemode | SAFE MODE DRIVER | reboot | clever | 0.7 | 7 |  |
| restart_services | RESTART SERVICES | reboot | quick | 0.5 | 2 | 0.4 |
| snapshot | ROLL BACK SNAPSHOT | reboot | heavy | 5.0 | 3 |  |
| event_log | FIND HUNG SERVICE | reboot | clever | 0.6 | 8 |  |
| print_browser | PRINT FROM BROWSER | adobe | quick | 0.3 | 1 | 0.6 |
| reader_reinstall | REINSTALL READER | adobe | heavy | 3.0 | 3 |  |

### 3.6 Ransomware exits

The ways a ransomware ticket can end. `cost x` multiplies the base ransom for the vendor, rebuild and insurer routes. Source: `scripts/msp.gd RANSOM_LABELS / RANSOM_MULT / FIXES`. Rows: 7.

| exit | ending label | cost x | button |
| --- | --- | --- | --- |
| saved | SAVED BY BACKUP |  |  |
| lost | NO BACKUP! |  |  |
| paid | PAID THE RANSOM |  |  |
| partial | PARTIAL RECOVERY |  |  |
| vendor | VENDOR RESTORED IT | 1.5 | VENDOR VERSIONS |
| rebuilt | REBUILT, FILES LOST |  |  |
| insured | INSURER GOT THEM BACK |  |  |

### 3.7 SLA clocks

Seconds a ticket may wait by priority (before the year multipliers and tier scale). Source: `scripts/msp.gd SLA_SECS`. Rows: 4.

| priority | seconds |
| --- | --- |
| 1 | 120.0 |
| 2 | 200.0 |
| 3 | 300.0 |
| 4 | 480.0 |

### 3.8 Tickets per day (tech campaign)

How many tickets can arrive on each day and the cap on the open queue (`OPEN_CAPS` ends at day 9 and holds after). Source: `scripts/msp.gd DAY_CAPS / OPEN_CAPS`. Rows: 20.

| day | ticket cap | open queue cap |
| --- | --- | --- |
| 1 | 1 | 3 |
| 2 | 3 | 3 |
| 3 | 5 | 3 |
| 4 | 6 | 3 |
| 5 | 7 | 3 |
| 6 | 8 | 4 |
| 7 | 9 | 4 |
| 8 | 10 | 5 |
| 9 | 11 | 5 |
| 10 | 12 | 5 |
| 11 | 12 | 5 |
| 12 | 12 | 5 |
| 13 | 12 | 5 |
| 14 | 12 | 5 |
| 15 | 12 | 5 |
| 16 | 12 | 5 |
| 17 | 12 | 5 |
| 18 | 12 | 5 |
| 19 | 12 | 5 |
| 20 | 12 | 5 |

### 3.9 Ticket pace option

The TICKET PACE setting (tech campaign) multiplies the day cap, the gap between timed tickets and the open cap. Source: `scripts/msp.gd PACE_*`. Rows: 3.

| pace | day cap x | gap x | open cap + |
| --- | --- | --- | --- |
| RELAXED | 0.75 | 1.3 | -1 |
| NORMAL | 1.0 | 1.0 | 0 |
| BUSY | 1.25 | 0.8 | 1 |

### 3.10 Onsite jobs

Visits to a client site. `options` is how many ways to attempt it (each with a skill, hours, XP and success chance). Source: `scripts/onsite.gd DEFAULT_JOBS + DEFAULT_MORE_JOBS`. Rows: 11.

| job id | object | priority | options | option success chances |
| --- | --- | --- | --- | --- |
| switch | cabinet | 1 | 3 | 1.0, 0.35, 0.0 |
| server | server | 1 | 3 | 0.9, 0.0, 1.0 |
| printer | printer | 3 | 4 | 0.9, 0.4, 0.0, 1.0 |
| pc | pc | 2 | 3 | 0.85, 1.0, 0.0 |
| upgrade | cabinet | 4 | 3 | 1.0, 0.65, 0.0 |
| exam | exam | 2 | 3 | 0.5, 0.95, 0.0 |
| xray | xray | 2 | 3 | 0.8, 0.7, 0.0 |
| vip | vip | 2 | 3 | 0.95, 0.3, 0.0 |
| phones | cabinet | 2 | 3 | 0.9, 0.4, 0.0 |
| wifi | cabinet | 3 | 3 | 0.75, 0.95, 0.0 |
| mailbox | pc | 3 | 3 | 0.9, 0.35, 0.6 |

Onsite site events: 6 (`Onsite.DEFAULT_EVENTS`); site findings: 7; site meetings: 2.

### 3.11 Playbook jobs

The multi-step incident jobs (rack recovery, mail migration, and so on): a client, the steps, the choices in them and the follow-on tickets. Source: `scripts/playbook.gd DEFAULT_BOOKS / DEFAULT_PROBLEMS`. Rows: 8.

| job id | title | client | specials | steps | choices | follow-on tickets |
| --- | --- | --- | --- | --- | --- | --- |
| rack | RACK RECOVERY | 2 | rack | 5 | 15 | 3 |
| migration | SERVER MIGRATION | 1 | migration | 5 | 12 | 1 |
| email24 | EMAIL OUTAGE | 4 | email24 | 5 | 13 | 1 |
| rdp | REMOTE ACCESS BREAK-IN | 1 | rdp | 5 | 15 | 1 |
| ceofraud | WIRE REQUEST FROM THE BOSS | 3 | ceofraud | 5 | 15 | 1 |
| no2fa | THE CLIENT WHO SAID NO | 4 | no2fa | 3 | 9 | 1 |
| bus | THE ONLY PERSON WHO KNOWS | 0 | bus | 3 | 10 | 1 |
| netinstall | NETWORK INSTALL | 3 | netinstall | 6 | 16 | 1 |

### 3.12 Printer models and bag choices

The printer mini-game: each model has its own phases, and the repair bag choice that fits it. Source: `scripts/printer_game.gd MODELS / BAG_FOR / BAGS`. Rows: 6.

| model | label | phases | tray choices | right bag | bag name |
| --- | --- | --- | --- | --- | --- |
| laser | LASER | jam, tray, toner, shake, test | 4 | fuser | A FUSER KIT |
| inkjet | INKJET | jam, toner, test | 4 | air | COMPRESSED AIR |
| plotter | PLOTTER | jam, tray, toner, shake, test | 4 | paper | A REAM OF PAPER |
| mfp | MULTIFUNCTION | jam, tray, toner, test | 4 | cable | A NETWORK CABLE |
| receipt | RECEIPT | jam, tray, test | 4 | paper | A REAM OF PAPER |
| dot | DOT MATRIX | jam, tray, toner, test | 4 | air | COMPRESSED AIR |

Mutator extra problems and Year 2 mutators are in section 6. Playbook jobs: 8. Base problem types: 6 plus ransomware, Adobe and the desktop replacement.

## 4. Cards and story

### 4.1 Decks and counts

Every deck of cards or beats. `schedule` is how the deck is placed. The total adds the counts; decks that share a card format are separate rows. Source: `see the source column`. Rows: 29.

| deck | what it is | count | schedule | source |
| --- | --- | --- | --- | --- |
| Owner cards | weekly decision cards of the owner campaign | 53 | 19 week slots, 72 placements | owner.gd DEFAULT_CARDS |
| Owner ops leads | client leads the owner can chase | 10 |  | owner_ops.gd DEFAULT_LEADS |
| Owner cast cards | Jen and Michael decision cards | 6 | 6 weeks | owner_cast.gd DEFAULT_CARDS |
| Partner beats | partner meetings (owner) | 4 | weeks 5, 9, 13, 17 | partner.gd BEATS |
| Vignettes | story scenes of the tech campaign | 33 | 20 days, 53 placements | story.gd DEFAULT_VIGNETTES |
| Postmortems | end-of-ticket story reviews | 4 |  | story.gd DEFAULT_POSTMORTEMS |
| Random events | the shared event deck (tech, owner or both) | 41 |  | events.gd DEFAULT_DECK |
| Seasonal cards | holiday, tax and end-of-support cards | 8 | 4 seasons | seasons.gd DEFAULT_CARDS |
| Seasonal events | potluck, tax basket and so on | 4 |  | seasons.gd DEFAULT_EVENTS |
| Temptation cards | shortcuts that grow into skeletons | 8 |  | temptation.gd BILLS (one bill per card) |
| Good habits | habits you can adopt (the Standard) | 14 |  | habits.gd DEFAULT_HABITS |
| Habit cards | offer, lapse, revenge and similar cards | 5 |  | habits.gd DEFAULT_CARDS |
| Rival habits | what the rival firms do wrong | 17 | 3 rivals | rival.gd DEFAULT_HABITS |
| Rival cards | rival-firm decision cards | 32 | 4 weeks | rival_cards.gd DEFAULT_CARDS |
| Service huddle memos | memos of Alan and Garrison | 30 |  | service.gd DEFAULT_MEMOS |
| Service beats | story beats of the service campaign | 7 | 15 days | service.gd DEFAULT_BEATS |
| Service incidents | incident cards | 6 |  | service.gd DEFAULT_INCIDENTS |
| Service arc cards | annual arc (Heartbleed wave, resets, promotion) | 13 |  | service_arc.gd DEFAULT_ARC |
| Service 1:1 deck: Maya | one-to-one conversations with this person | 10 |  | service.gd DEFAULT_ONE_ON_ONES |
| Service 1:1 deck: Tech | one-to-one conversations with this person | 28 |  | service.gd DEFAULT_ONE_ON_ONES |
| Service 1:1 deck: John | one-to-one conversations with this person | 10 |  | service.gd DEFAULT_ONE_ON_ONES |
| Sales beats | story beats of the sales campaign | 31 | 16 scheduled weeks | sales_campaign.gd DEFAULT_BEAT_TEXT |
| Year 2 beats | second-year beats, all modes | 7 |  | yeartwo.gd DEFAULT_YEAR2 |
| Year 3 beats | third-year beats, all modes | 12 |  | yeartwo.gd DEFAULT_YEAR3 |
| Expo forum cards | forum people at the trade expo | 8 |  | conference.gd FORUM |
| Expo vendors | vendor booth cards | 5 |  | conference.gd + trip_variety.gd |
| Expo chats | hallway chat cards | 9 |  | conference.gd + trip_variety.gd |
| Nerd forum boards | boards of the in-game forum | 18 |  | nerds.gd DEFAULT_BOARDS |
| Nerd forum threads | threads of the in-game forum | 81 |  | nerds.gd DEFAULT_THREADS |

Total cards and beats counted above: 514. The owner campaign's live deck (`Owner.CARDS`) merges the owner, cast and rival cards at start-up: 91 cards in all, so those rows overlap with it.

### 4.2 Year 2 text blocks

Parts of the Year 2 narrative text (intro, beats per mode, offers, habit cards, ending texts). Source: `scripts/yeartwo.gd DEFAULT_TEXT`. Rows: 5.

| block | entries |
| --- | --- |
| intro | 2 |
| beats | 4 |
| offers | 4 |
| habits | 3 |
| endings | 4 |

### 4.3 Seasons

Calendar seasons that change the decor and unlock their cards (month index from November). Source: `scripts/seasons.gd SEASONS`. Rows: 4.

| id | name | from month | to month | year | dressing |
| --- | --- | --- | --- | --- | --- |
| holidays | THE HOLIDAYS | 3 | 4 | 0 | lights |
| tax | TAX SEASON | 6 | 10 | 0 | boxes |
| xp | XP END OF SUPPORT | 9 | 10 | 1 | countdown |
| school | BACK TO SCHOOL | 17 | 18 | 0 | drive |

## 5. Outings and mini-games

### 5.1 Outing games

The games a team outing can offer, with the cost in dollars of one outing. Source: `scripts/outings.gd GAMES`. Rows: 9.

| id | label | cost $ | keys line |
| --- | --- | --- | --- |
| bowling | BOWLING | 120 | SPACE = STOP AIM / POWER  ESC = LEAVE |
| karaoke | KARAOKE | 180 | {ARROW KEYS:move} = HIT NOTES  ESC = LEAVE |
| escape | ESCAPE ROOM | 240 | ARROWS  ENTER = TRY  H = HINT  ESC = LEAVE |
| dinner | DINNER | 300 | UP / DOWN  ENTER = TALK  ESC = LEAVE |
| chair | CHAIR RACE | 120 | ARROWS = LANE  Z X = PUSH  ESC = LEAVE |
| cornhole | CORNHOLE | 100 | E = STOP AIM / POWER  ESC = LEAVE |
| grill | COOKOUT | 150 | E = FLIP  SPACE = SERVE  SHIFT = COOL  ESC = LEAVE |
| paintball | PAINTBALL | 200 | L R RUN  UP DN LANE  Z FIRE  SHIFT DUCK  ESC LEAVE |
| darts | DARTS | 0 | E = THROW  ESC = LEAVE |

### 5.2 Outing venues

The scene each outing game plays in. Source: `scripts/outings.gd ROOMS`. Rows: 9.

| game | scene |
| --- | --- |
| bowling | bowling_alley |
| karaoke | karaoke_bar |
| escape | escape_room |
| dinner | restaurant |
| chair | warehouse |
| paintball | paintball_field |
| cornhole | warehouse |
| grill | warehouse |
| darts | warehouse |

### 5.3 When outings happen

The scheduled days or weeks for outings, lunches, meetings and the expo trip. Source: `scripts/outings.gd, meeting.gd, conference.gd`. Rows: 8.

| what | days or values |
| --- | --- |
| tech campaign outing days | 5, 10, 15 |
| tech campaign lunch days | 3, 7, 12, 17 |
| owner campaign lunch weeks | 2, 7, 12, 17 |
| owner campaign outing weeks | 4, 9, 14, 19 |
| chair race events on the card | straight, gauntlet, fight |
| meeting days (tech) | 6, 11, 16 |
| expo trip clocks | 10.0, 13.0, 15.0 |
| expo trip reputation gain by effort 0..4 | 0, 0, 1, 2, 3 |

### 5.4 Karaoke songs

Every song: length in notes, gap between notes, scroll speed, how many wins unlock it. Source: `scripts/outings.gd DEFAULT_SONGS`. Rows: 4.

| id | title | artist | genre | notes | gap s | speed | unlock at | pattern |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| wobble | WOBBLE WOBBLE POP | DJ BEANBAG | 2013 POP | 24 | 0.75 | 45.0 | 0 | mix |
| dirt | DIRT ROAD FRIDAY | THE CREEKBED TWINS | COUNTRY SINGALONG | 20 | 0.95 | 45.0 | 0 | sweep |
| neon | NEON GYM CLASS | THE SYNTH SCOUTS | 80S CLASSIC | 26 | 0.7 | 48.0 | 0 | sync |
| rap | FAST RAP HOT MESS | MC SPREADSHEET | FAST RAP | 32 | 0.62 | 55.0 | 3 | burst |

### 5.5 Escape room themes

Four rooms. `clue lines` is how many sentence templates the room can say. Source: `scripts/outings.gd DEFAULT_ESCAPE_THEMES / THEME_ORDER`. Rows: 4.

| theme | title | short | clue lines |
| --- | --- | --- | --- |
| study | THE OLD STUDY | OLD STUDY | 10 |
| server | THE SERVER ROOM | SERVER ROOM | 10 |
| detective | THE DETECTIVE'S OFFICE | DETECTIVE | 10 |
| lab | THE 1990S COMPUTER LAB | COMPUTER LAB | 10 |

### 5.6 Escape recipes

How a code digit is built from a clue, per clue zone. Themes x zones x recipes give the puzzle variety. Source: `scripts/outings.gd RECIPES`. Rows: 4.

| zone | recipes | recipe ids |
| --- | --- | --- |
| board | 3 | sum, product, missing |
| clock | 2 | hour, double |
| plaque | 3 | number, roman, letter |
| shelf | 2 | spine, ribbons |

Escape variety: 4 themes x 4 clue zones, 10 recipes in total; the code has 3, 3, 4 digits (easy / normal / hard).

### 5.7 Dinner budgets

The three dinner budgets. Source: `scripts/outings.gd BUDGETS`. Rows: 3.

| id | label | cost $ | mood |
| --- | --- | --- | --- |
| cheap | CHEAP: PIZZA AND TAP WATER | 150 | -1 |
| normal | NORMAL: THE USUAL GRILL ORDER | 300 | 0 |
| fancy | FANCY: STEAKS AND A TOAST | 520 | 1 |

Dinner: 13 dishes, 20 table topics (3 protected), 6 diets (Alan, Garrison, Dan, John, Maya, Morgan), 3 guest topics.

### 5.8 Nerf war modes

The dart-gun game modes and the win line of each. Source: `scripts/nerf_modes.gd MODES`. Rows: 4.

| id | label | win condition |
| --- | --- | --- |
| cup | CAPTURE THE CUP | 3 |
| elim | ELIMINATION | 0 |
| team | TEAM WAR | 0 |
| hide | HIDE AND SEEK LITE | 0 |

### 5.9 Nerf arenas

Where the nerf war is played, and its clock, lives and cups. Source: `scripts/nerf_modes.gd ARENAS`. Rows: 3.

| scene | label | seconds | gap | lives | cups |
| --- | --- | --- | --- | --- | --- |
| main_floor | THE OFFICE | 50.0 | 1.0 | 3 | 0.25, 0.5, 0.78 |
| cubicle_area | THE CUBICLE AREA | 45.0 | 0.9 | 3 | 0.2, 0.45, 0.8 |
| conference | THE CONFERENCE ROOM | 40.0 | 1.2 | 2 | 0.15, 0.5, 0.85 |

### 5.10 Chair race courses

The chair race (warehouse): the straight and the gauntlet. The chair fight is its own mode. Source: `scripts/chair_race.gd COURSES`. Rows: 2.

| id | label | length | checkpoints | par |
| --- | --- | --- | --- | --- |
| straight | THE STRAIGHT | 912.0 | 0.25, 0.5, 0.75 | 1.0 |
| gauntlet | THE GAUNTLET | 684.0 | 0.34, 0.67 | 0.76 |

### 5.11 Chair racers

Skill (0 to 1) and driving style of each racer. Source: `scripts/chair_race.gd RACERS`. Rows: 5.

| racer | skill | style |
| --- | --- | --- |
| Alan | 0.46 | careful |
| Garrison | 0.56 | reckless |
| Dan | 0.5 | steady |
| Maya | 0.5 | sprinter |
| John | 0.52 | showboat |

### 5.12 Bowling opponents

Skill and temperament of each bowler (added to by the opp_skill dial). Source: `scripts/outings.gd BOWLERS`. Rows: 6.

| name | skill | noise | streak | turkey | gutter |
| --- | --- | --- | --- | --- | --- |
| Alan | 0.62 | 0.15 | 0.0 | 0.0 | 0.0 |
| Garrison | 0.55 | 0.2 | 0.14 | 0.0 | 0.0 |
| Dan | 0.48 | 0.4 | 0.0 | 0.1 | 0.06 |
| John | 0.5 | 0.24 | 0.0 | 0.0 | 0.05 |
| Maya | 0.6 | 0.1 | 0.0 | 0.0 | 0.0 |
| Morgan | 0.66 | 0.12 | 0.0 | 0.0 | 0.0 |

### 5.13 Cornhole and darts opponents

Temperament presets of the opponents (accuracy, streaks, show-off). Source: `scripts/cornhole_game.gd, darts_game.gd TEMPERS`. Rows: 10.

| game | temper | values |
| --- | --- | --- |
| cornhole | Alan | skill=0.62, precise=0.6, streak=0.0, wild=0.0, show=0.0 |
| cornhole | Garrison | skill=0.52, precise=1.0, streak=0.12, wild=0.0, show=0.0 |
| cornhole | Dan | skill=0.45, precise=1.0, streak=0.0, wild=0.14, show=0.0 |
| cornhole | Maya | skill=0.58, precise=0.9, streak=0.0, wild=0.0, show=0.0 |
| cornhole | John | skill=0.5, precise=1.0, streak=0.0, wild=0.0, show=0.12 |
| darts | Alan | skill=0.6, streak=0.0, wild=0.0, show=0.0 |
| darts | Garrison | skill=0.5, streak=0.12, wild=0.0, show=0.0 |
| darts | Dan | skill=0.44, streak=0.0, wild=0.14, show=0.0 |
| darts | Maya | skill=0.56, streak=0.0, wild=0.0, show=0.0 |
| darts | John | skill=0.48, streak=0.0, wild=0.0, show=0.12 |

### 5.14 Paintball styles

The playing styles of the paintball teammates and opponents. Day, night and co-op variants share them. Source: `scripts/paintball_game.gd STYLES`. Rows: 5.

| style | values |
| --- | --- |
| Alan | skill=0.5, role=defend, careful=true, win=ALAN: A CLEAN, WELL DOCUMENTED VICTORY., lose=ALAN: NOBOD... |
| Garrison | skill=0.6, role=attack, careful=false, win=GARRISON: I TOLD YOU. I TOLD EVERYONE., lose=GARRISON: T... |
| Dan | skill=0.55, role=defend, careful=true, win=DAN: WE HAD A PLAN. WE HAD A SPREADSHEET., lose=DAN: THE... |
| Maya | skill=0.6, role=attack, careful=false, win=MAYA: EASY. NOW I NEED A GRANOLA BAR., lose=MAYA: I WAS ... |
| John | skill=0.5, role=defend, careful=true, win=JOHN: WE DID IT. DOES THIS COUNT AS A TEAM BUILDING?, los... |

### 5.15 Expo trip rounds

The three rounds of the trade expo trip and their sessions (more sessions come from the trip variety pool). Source: `scripts/conference.gd DEFAULT_ROUNDS`. Rows: 3.

| round | sessions |
| --- | --- |
| ROUND 1: TUESDAY MORNING | 4 |
| ROUND 2: TUESDAY AFTERNOON | 4 |
| ROUND 3: WEDNESDAY MORNING | 4 |

Extra expo sessions: 3 (`trip_variety.gd MORE_SESSIONS`). Grill game: not data driven, see `scripts/grill_game.gd` (customer notes: 7). Printer game: see 3.12.

### 5.16 Mastery ramps

Per-game mastery (0 to 1) grows with good plays and tightens the listed dials; the `Difficulty.TABLE` values are in 1.8. Source: `scripts/difficulty.gd MASTERY_GAMES / MASTERY_KEYS`. Rows: 10.

| dial prefix | game key | ramped dials | dials |
| --- | --- | --- | --- |
| karaoke | karaoke | 3 | karaoke.gap, karaoke.perfect, karaoke.good |
| bowl | bowling | 5 | bowl.opp_skill, bowl.aim_speed, bowl.power_speed, bowl.oil, bowl.spin_noise |
| escape | escape | 2 | escape.time, escape.wrong_penalty |
| dinner | dinner | 3 | dinner.expect, dinner.fits, dinner.hints |
| printer | printer | 2 | printer.speed, printer.zone |
| grill | grill | 3 | grill.cook_rate, grill.window, grill.time |
| chair | chair | 5 | chair.crash, chair.stamina, chair.slick, chair.par, chair.skill |
| paint | paintball | 1 | paint.skill |
| corn | cornhole | 3 | corn.opp_skill, corn.aim_speed, corn.power_speed |
| darts | darts | 3 | darts.drift, darts.speed, darts.opp_skill |

### 5.17 Career stats recorded

Every counter the career screen records. Source: `scripts/career.gd COUNTERS`. Rows: 76.

| group | label | key | format |
| --- | --- | --- | --- |
| DESK | TICKETS CLOSED | tickets | n |
|  |   PASSWORDS | tk.password | n |
|  |   PRINTERS | tk.spooler | n |
|  |   CLEAN-UPS | tk.clear_temp | n |
|  |   REBOOTS | tk.reboot | n |
|  |   VIRUSES | tk.av | n |
|  |   RESTORES | tk.restore | n |
|  |   OTHER | tk_other | n |
|  | TECH DAYS WORKED | days.tech | n |
|  | OWNER WEEKS RUN | days.owner | n |
|  | YEARS FINISHED | endings | n |
|  | ALL-HANDS ATTENDED | meetings | n |
|  | DECISION CARDS SEEN | cards_seen | n |
|  | MUTATOR WEEKS | mut_days | n |
|  | STARTS FINISHED | starts_done | n |
|  | DAILY SEEDS PLAYED | daily_seeds | n |
| OUTINGS | OUTINGS PLAYED | outings | n |
|  | BOWLING BEST | stars.bowling | stars |
|  | KARAOKE BEST | stars.karaoke | stars |
|  | ESCAPE ROOM BEST | stars.escape | stars |
|  | DINNER BEST | stars.dinner | stars |
|  | CORNHOLE BEST | stars.cornhole | stars |
|  | BAGS IN THE HOLE | bags_in_hole | n |
|  | COOKOUT BEST | stars.grill | stars |
|  | CHAIR RACE BEST | stars.chair | stars |
|  | CHAIR RACES WON | chair_wins | n |
|  | CHAIR FIGHT BEST | stars.chairfight | stars |
|  | CHAIR FIGHTS WON | chairfight_wins | n |
|  | CHAIRS PUSHED | chair_shoves | n |
|  | PAINTBALL BEST | stars.paintball | stars |
|  | FLAGS CARRIED HOME | flag_caps | n |
|  | DARTS BEST | stars.darts | stars |
|  | BULLSEYES | bulls | n |
|  | BURGERS SERVED | burgers_served | n |
|  | HOT DOGS SERVED | dogs_served | n |
|  | LUNCH BREAKS | lunches | n |
|  | STRIKES | bowl_strikes | n |
|  | GUTTER BALLS | bowl_gutters | n |
|  | HOOK STRIKES | bowl_hook_strikes | n |
|  | LEAGUE TITLES | league_titles | n |
|  | ALLEYS BOWLED | alleys | n |
|  | PERFECT NOTES | kara_perfects | n |
|  | FASTEST ESCAPE | escape_best | secs |
|  | BEST DINNER SCORE | dinner_best | n |
| PRINTER | PRINTER WINS | printer_wins | n |
|  |   LASER | pr.laser | n |
|  |   INKJET | pr.inkjet | n |
|  |   PLOTTER | pr.plotter | n |
|  |   COPIER | pr.mfp | n |
|  |   RECEIPT | pr.receipt | n |
|  |   DOT MATRIX | pr.dot | n |
|  | BEST NO-PRAYER RUN | pr_streak | n |
| NERF AND OFFICE | NERF HITS | nerf_hits | n |
|  | DARTS DUCKED | nerf_dodges | n |
|  | CUPS CAPTURED | nerf_cups | n |
|  | ELIMINATION WINS | nerf_elim_wins | n |
|  | ARENAS FOUGHT IN | nerf_arenas | n |
|  | NERF WARS | nerf_wars | n |
|  | LONGEST HIT | nerf_longest | px |
|  | ANIMALS PETTED | pets | n |
|  | COMPLAINTS HEARD | vic_calls | n |
|  | CONFERENCES | trips | n |
|  | SESSIONS SEEN | sessions_seen | n |
|  | ONSITE JOBS FIXED | onsite_fixed | n |
|  | TRAFFIC JAMS | road_events | n |
| SALES | DEALS WON | deals_won | n |
|  | CLAWBACKS | clawbacks | n |
|  | RENEWALS WON | renewals | n |
|  | UPSELLS SOLD | upsells | n |
|  | DUCK CHATS | duck_squeaks | n |
|  | OWNER HELP | owner_help | n |
| SERVICE DESK | TICKETS DISPATCHED | dispatched | n |
| HABITS | HABITS ADOPTED | habits_adopted | n |
|  | SKELETONS PAID | skeletons_paid | n |
|  | TAKEOVERS | takeovers | n |
|  | CLEAN SHEETS | clean_sheets | n |

## 6. Progression

### 6.1 Career medals

Every medal: its id, title, description and the counter rule that earns it. Source: `scripts/career.gd DEFAULT_MEDALS`. Rows: 72.

| id | title | what earns it | rule (counter op value) |
| --- | --- | --- | --- |
| ticket_machine | TICKET MACHINE | CLOSE 50 TICKETS | tickets >= 50 |
| help_desk_hero | HELP DESK HERO | CLOSE 250 TICKETS | tickets >= 250 |
| sticky_savior | STICKY NOTES SAVIOR | CLOSE 10 PASSWORD TICKETS | tk.password >= 10 |
| printer_whisperer | PRINTER WHISPERER | WIN WITH EVERY PRINTER MODEL | printer_models >= 6 |
| never_restarted | NEVER RESTARTED | 5 PRINTER WINS, NO PRAYERS | pr_streak >= 5 |
| toner_wrangler | TONER WRANGLER | WIN 20 PRINTER GAMES | printer_wins >= 20 |
| meeting_survivor | MEETING SURVIVOR | ATTEND 5 ALL-HANDS | meetings >= 5 |
| duck_whisperer | DUCK WHISPERER | TALK TO THE DUCK 50 TIMES | duck_squeaks >= 50 |
| people_person | PEOPLE PERSON | PLAY 3 TEAM OUTINGS | outings >= 3 |
| full_house | FULL HOUSE | 3 STARS IN ALL FOUR GAMES | stars3 >= 4 |
| gutter_guru | GUTTER GURU | ROLL 10 GUTTER BALLS | bowl_gutters >= 10 |
| strike_zone | STRIKE ZONE | ROLL 10 STRIKES | bowl_strikes >= 10 |
| crowd_pleaser | CROWD PLEASER | HIT 20 PERFECT KARAOKE NOTES | kara_perfects >= 20 |
| vault_cracker | VAULT CRACKER | OPEN THE VAULT IN 50 SECONDS | escape_best <= 50 |
| dinner_diplomat | DINNER DIPLOMAT | SCORE 24 AT THE TEAM DINNER | dinner_best >= 24 |
| friday_warrior | FRIDAY WARRIOR | SURVIVE 5 NERF WARS | nerf_wars >= 5 |
| dead_eye | DEAD EYE | HIT COWORKERS 30 TIMES | nerf_hits >= 30 |
| long_shot | LONG SHOT | HIT SOMEONE FROM 150 PX AWAY | nerf_longest >= 150 |
| limbo_legend | LIMBO LEGEND | DUCK 25 DARTS | nerf_dodges >= 25 |
| cat_person | CAT PERSON | PET 10 OFFICE ANIMALS | pets >= 10 |
| on_hold | ON HOLD, PLEASE | HEAR OUT 5 CLIENT COMPLAINTS | vic_calls >= 5 |
| year_one | YEAR ONE | FINISH A CAMPAIGN YEAR | endings >= 1 |
| regular | REGULAR | PLAY 20 DAYS OR WEEKS | days_total >= 20 |
| corner_office | CORNER OFFICE | RUN 10 OWNER WEEKS | days.owner >= 10 |
| hook_shot | HOOK SHOT | 5 STRIKES WITH A HOOK | bowl_hook_strikes >= 5 |
| league_champion | LEAGUE CHAMPION | WIN A LEAGUE SEASON | league_titles >= 1 |
| alley_cat | ALLEY CAT | BOWL AT ALL THREE ALLEYS | alleys >= 3 |
| cup_captured | CUP CAPTURED | CAPTURE THE CUP 5 TIMES | nerf_cups >= 5 |
| last_standing | LAST ONE STANDING | WIN 3 ELIMINATION WARS | nerf_elim_wins >= 3 |
| ghost | GHOST | HIDE FOR A WHOLE ROUND | nerf_hide_wins >= 1 |
| arena_regular | ARENA REGULAR | FIGHT IN ALL 3 ARENAS | nerf_arenas >= 3 |
| conference_goer | CONFERENCE GOER | ATTEND THE CONFERENCE | trips >= 1 |
| raffle_luck | RAFFLE LUCK | WIN THE CONFERENCE RAFFLE | raffle_wins >= 1 |
| session_hopper | SESSION HOPPER | SEE 6 DIFFERENT SESSIONS | sessions_seen >= 6 |
| road_warrior | ROAD WARRIOR | SURVIVE 5 TRAFFIC JAMS | road_events >= 5 |
| field_tech | FIELD TECH | FIX 10 ONSITE JOBS | onsite_fixed >= 10 |
| all_sites | JACK OF ALL SITES | FIX JOBS AT 4 SITE TYPES | site_types >= 4 |
| bag_man | BAG MAN | 10 BAGS IN THE HOLE | bags_in_hole >= 10 |
| grill_sergeant | GRILL SERGEANT | A COOKOUT, NOTHING BURNT | grill_clean >= 1 |
| old_tree | OLD TREE | FIND THE TREE IN THE WAREHOUSE | old_tree >= 1 |
| lunch_bunch | LUNCH BUNCH | TAKE 5 LUNCH BREAKS | lunches >= 5 |
| dog_days | DOG DAYS | SERVE 20 HOT DOGS | dogs_served >= 20 |
| warehouse_all_star | WAREHOUSE ALL-STAR | 3 STARS IN EACH WAREHOUSE GAME | wh_stars3 >= 3 |
| habit_forming | HABIT FORMING | ADOPT 5 GOOD HABITS | habits_adopted >= 5 |
| spring_cleaning | SPRING CLEANING | PAY OFF 3 SKELETONS | skeletons_paid >= 3 |
| cleanup_crew | CLEAN UP CREW | FINISH 3 TAKEOVERS | takeovers >= 3 |
| clean_sheet | CLEAN SHEET | END A YEAR WITH CLEAN BOOKS | clean_sheets >= 1 |
| bullseye | BULLSEYE | HIT THE BULL AT DARTS | bulls >= 1 |
| year_two | SECOND YEAR | FINISH A YEAR 2 RUN | year2_done >= 1 |
| line_legend | LINE TAMER | TAME THE LINE PRINTER | pr.line >= 1 |
| svc_ops | OPS MANAGER | BECOME OPS MANAGER | svc_end.ops >= 1 |
| svc_hand | RIGHT HAND | BACK ALAN OR GARRISON | svc_end_lead >= 1 |
| svc_summit | SUMMIT DIRECTOR | TAKE SUMMIT'S ROLL-UP | svc_end.rollup_yes >= 1 |
| clean_lap | CLEAN LAP | A CHAIR RACE, NOTHING HIT | chair_clean >= 1 |
| speed_demon | SPEED DEMON | WIN 3 CHAIR RACES | chair_wins >= 3 |
| track_rat | TRACK RAT | FINISH BOTH CHAIR COURSES | chair_courses >= 2 |
| bumper_king | BUMPER KING | WIN 3 CHAIR FIGHTS | chairfight_wins >= 3 |
| pushy | PUSHY | PUSH 10 COWORKER CHAIRS | chair_shoves >= 10 |
| flag_runner | FLAG RUNNER | CARRY 5 FLAGS HOME | flag_caps >= 5 |
| year_three | THIRD YEAR | FINISH A YEAR 3 RUN | year3_done >= 1 |
| y3_chair | DAN'S CHAIR | YEAR 3: TAKE DAN'S CHAIR | end.y3_chair >= 1 |
| y3_senior | SENIOR ENGINEER | YEAR 3: STAY TECHNICAL | end.y3_senior >= 1 |
| y3_farewell | GOOD TERMS | YEAR 3: LEAVE IT TIDY | end.y3_farewell >= 1 |
| y3_summit | SOLD TO SUMMIT | YEAR 3: SELL TO SUMMIT | end.y3_summit >= 1 |
| y3_staff | STAFF OWNED | YEAR 3: SELL TO THE STAFF | end.y3_staff >= 1 |
| y3_morgan | TUESDAYS OFF | YEAR 3: GIVE MORGAN THE KEYS | end.y3_morgan >= 1 |
| y3_coo | BACK OF HOUSE | YEAR 3: RUN OPERATIONS | end.y3_coo >= 1 |
| y3_partner | THIRD SIGNATURE | YEAR 3: BECOME A PARTNER | end.y3_partner >= 1 |
| y3_across | ACROSS TOWN | YEAR 3: TAKE TERRY'S OFFER | end.y3_across >= 1 |
| y3_director | THE BIG CHAIR | YEAR 3: TAKE GARRISON'S CHAIR | end.y3_director >= 1 |
| y3_wes | CALL ME BOSS | YEAR 3: GIVE WES THE CHAIR | end.y3_wes >= 1 |
| y3_stake | A PERCENTAGE | YEAR 3: TAKE THE SHARE | end.y3_stake >= 1 |

### 6.2 Medal unlocks

Cosmetic and option unlocks (wallpapers, desk items and so on) and the medal that grants each. Source: `scripts/career.gd DEFAULT_UNLOCKS`. Rows: 41.

| id | kind | title | needs medal | value |
| --- | --- | --- | --- | --- |
| wall_standard | wallpaper | STANDARD BLUE |  | 2d6ca8 |
| wall_sunset | wallpaper | SUNSET ORANGE | ticket_machine | b8683a |
| wall_graphite | wallpaper | GRAPHITE | help_desk_hero | 454b58 |
| wall_mint | wallpaper | MINT | printer_whisperer | 3a9a84 |
| wall_plum | wallpaper | PLUM | friday_warrior | 6a4690 |
| ring_classic | ringtone | RING RING |  |  |
| ring_dial | ringtone | OLD DIAL TONE | never_restarted |  |
| ring_chime | ringtone | WIND CHIME | people_person |  |
| ring_marimba | ringtone | MARIMBA | crowd_pleaser |  |
| ring_quack | ringtone | QUACK QUACK | duck_whisperer |  |
| duck_classic | duck | RUBBER DUCK |  |  |
| duck_gold | duck | GOLD RUBBER DUCK | duck_whisperer |  |
| duck_pirate | duck | PIRATE RUBBER DUCK | limbo_legend |  |
| toy_none | desk_toy | NO DESK TOY |  |  |
| toy_stress_ball | desk_toy | STRESS BALL | meeting_survivor |  |
| toy_pendulum | desk_toy | DESK PENDULUM | full_house |  |
| glasses_thin | glasses | THIN |  | thin |
| glasses_thick | glasses | THICK |  | thick |
| glasses_round | glasses | ROUND |  | round |
| glasses_aviator | glasses | AVIATOR |  | aviator |
| beard_stubble | beard | STUBBLE |  | stubble |
| beard_goatee | beard | GOATEE |  | goatee |
| beard_full | beard | FULL BEARD |  | full |
| beard_moustache | beard | MOUSTACHE |  | moustache |
| hat_beanie | hat | BEANIE |  | beanie |
| hat_cap | hat | BALL CAP |  | cap |
| hat_hardhat | hat | HARD HAT | bag_man | hardhat |
| hat_santa | hat | SANTA HAT | old_tree | santa |
| hat_bucket | hat | BUCKET HAT |  | bucket |
| hat_party | hat | PARTY HAT | people_person | party |
| shirt_polo | shirt | POLO |  | polo |
| shirt_tee | shirt | TEE |  | tee |
| shirt_button | shirt | BUTTON-DOWN |  | button |
| shirt_sweater | shirt | SWEATER |  | sweater |
| bottom_trousers | bottom | TROUSERS |  | trousers |
| bottom_jeans | bottom | JEANS |  | jeans |
| bottom_shorts | bottom | SHORTS |  | shorts |
| bottom_skirt | bottom | SKIRT |  | skirt |
| shoes_dress | shoes | DRESS SHOES |  | dress |
| shoes_sneakers | shoes | SNEAKERS |  | sneakers |
| shoes_boots | shoes | WORK BOOTS | field_tech | boots |

### 6.3 Mutators

Temporary world changes (a bad week) that Free Play and Year 2 can switch on. Source: `scripts/mutators.gd DEFAULT_MUTATORS`. Rows: 14.

| id | name | campaigns | duration | ticket weight | extra chance | extra problems |
| --- | --- | --- | --- | --- | --- | --- |
| heartbleed | HEARTBLEED WEEK | both | 2, 1 | password=2.0 | 0.3 | 2 |
| xp_eol | XP END OF LIFE | both | 2, 1 |  |  | 0 |
| flu_season | FLU SEASON | both | 2, 2 |  |  | 0 |
| printer_apocalypse | PRINTER APOCALYPSE | both | 2, 1 | spooler=3.0 |  | 0 |
| tax_season | TAX SEASON | both | 2, 2 |  |  | 0 |
| slow_payers | SLOW PAYERS | owner | 1, 2 |  |  | 0 |
| hardware_recall | HARDWARE RECALL | both | 1, 1 | reboot=1.5 |  | 0 |
| hurricane_drill | HURRICANE DRILL | both | 1, 1 |  |  | 0 |
| new_psa | THE NEW PSA | both | 1, 1 |  | 0.25 | 2 |
| heat_wave | HEAT WAVE | both | 2, 1 | reboot=1.5 |  | 0 |
| cold_snap | COLD SNAP | both | 2, 1 |  |  | 0 |
| good_quarter | GOOD QUARTER | owner | 1, 2 |  |  | 0 |
| price_war | PRICE WAR | owner | 1, 2 |  |  | 0 |
| summer_lull | SUMMER LULL | owner | 1, 2 |  |  | 0 |

### 6.4 Starts

Run starts (how a new year opens). Source: `scripts/mutators.gd DEFAULT_STARTS`. Rows: 5.

| id | name | short | campaigns |
| --- | --- | --- | --- |
| standard | STANDARD | STANDARD | both |
| messy | INHERIT A MESSY MSP | MESSY MSP | both |
| only_tech | THE ONLY TECH | ONLY TECH | tech |
| rival | A RIVAL WANTS YOUR CLIENT | RIVAL | both |
| family | FAMILY BUSINESS | FAMILY BIZ | owner |

### 6.5 Build paths and stats

The point-buy character build: which campaigns have one and the stats it spends points on (level 0 to 5; cumulative cost 0, 1, 2, 4, 7, 11). Source: `scripts/build.gd PATHS / COST`. Rows: 4.

| campaign | selectable | stats |
| --- | --- | --- |
| tech | true | powershell, networking, servers, security, people |
| owner | true | technical, finance, sales, culture, clients |
| service | true | dispatch, process, people, escalation, relations |
| sales | true | pitch, discovery, negotiation, relationships, honesty |

### 6.6 Build presets

Ready-made builds: the order the points are spent in (`steps`) and the quirks they carry. Source: `scripts/build.gd DEFAULT_PRESETS`. Rows: 18.

| path | id | name | steps | quirks | text |
| --- | --- | --- | --- | --- | --- |
| tech | generalist | GENERALIST | 15 |  | A BIT OF EVERYTHING. NO BAD DAYS, NO BIG WINS. |
| tech | scripter | SCRIPTER | 12 |  | FIXES RUN FASTER AND SCRIPTS WORK ON DAY ONE. NOBODY LIKES YOU YET. |
| tech | network | NETWORK NERD | 12 |  | THE CLOSET IS YOUR HAPPY PLACE. PRINTERS AND OUTAGES FEAR YOU. |
| tech | people | PEOPLE PERSON | 12 |  | CLIENTS WAIT LONGER AND THE TEAM LIKES YOU. THE SERVERS NOT SO MUCH. |
| owner_alan | architect | ARCHITECT | 10 |  | A CLEAN STACK AND QUIET SERVERS. THE BOOKS ARE ALMOST AS TIDY. |
| owner_alan | cutter | COST CUTTER | 9 |  | EVERY DOLLAR HAS A JOB. CLIENTS ACCEPT FEE RISES AND THE BANK STARTS FATTER. |
| owner_alan | hirer | HIRER | 10 |  | YOU PICK GOOD PEOPLE. CLIENTS LIKE THEM AND THE CREW STAYS. |
| owner_garrison | brand | BRAND BUILDER | 10 |  | MARKETING WORKS HARD FOR YOU AND JOHN CLOSES MORE. |
| owner_garrison | people_first | PEOPLE FIRST | 10 |  | A HAPPY CREW AND A TRUSTING PARTNER. THE NUMBERS FOLLOW, MAYBE. |
| owner_garrison | closer | CLOSER | 10 |  | REVIEWS GO WELL, FEES GO UP, NEW CLIENTS START HAPPY. |
| service | label_maker | LABEL MAKER | 8 |  | EVERYTHING HAS A RUNBOOK AND A LABEL. |
| service | coach | COACH | 8 |  | ONE ON ONES THAT WORK. THE BOARD LOOKS A LITTLE MESSY. |
| service | firefighter | FIREFIGHTER | 8 |  | YOU SEE THE FIRE BEFORE IT STARTS. |
| service | diplomat | DIPLOMAT | 7 |  | CLIENTS CALL YOU FIRST. YOUR CREW KNOWS WHY. |
| sales | hunter | HUNTER | 8 |  | NEW LEADS EVERY WEEK. RENEWALS ARE SOMEBODY ELSE'S PROBLEM. |
| sales | farmer | FARMER | 8 |  | RENEWALS AND REFERRALS. NOBODY EVER LEAVES. |
| sales | consultant | CONSULTANT | 8 |  | YOU FIND THE REAL PROBLEM AND QUOTE THE REAL FIX. |
| sales | smooth | SMOOTH TALKER | 7 |  | YOU CLOSE ANYTHING. KEEP THE PROMISES YOU MAKE. |

### 6.7 Shop items

Desk upgrades you can buy; `fx` are the gameplay effects and `loud` ones annoy coworkers. Source: `scripts/shop.gd CATALOG`. Rows: 12.

| id | name | price $ | slot | effect | loud |
| --- | --- | --- | --- | --- | --- |
| kb_blue | CLICKY BLUE KEYBOARD | 90 | keyboard | fix_secs=0.95 | true |
| kb_brown | BROWN SWITCH KEYBOARD | 100 | keyboard | fix_secs=0.97 | false |
| kb_red | RED SWITCH KEYBOARD | 110 | keyboard | fix_secs=0.96 | false |
| mouse | VERTICAL MOUSE | 45 | mouse | drain=0.95 | false |
| riser | STANDING DESK RISER | 180 | riser | drain=0.9 | false |
| cushion | LUMBAR CUSHION | 60 | chair | rest=3 | false |
| headset | WIRELESS HEADSET | 110 | headset | people_xp=1 | false |
| plant | DESK PLANT | 20 | plant | rest=1 | false |
| rgb | RGB DESK STRIP | 70 | light |  | false |
| speakers | DESK SPEAKERS | 55 | speakers |  | false |
| toy | NEWTON'S CRADLE | 30 | toy |  | false |
| poster | WALL POSTER | 20 | poster |  | false |

### 6.8 Office decor unlocks

Items that appear in the office when a score reaches a threshold. Source: `scripts/office_decor.gd ITEMS`. Rows: 7.

| id | name | unlock rule |
| --- | --- | --- |
| plant | A TALL PLANT | REPUTATION >= 55 |
| rug | A RUG BY THE DOOR | CASH >= 400 |
| certificate | A FRAMED CERTIFICATE | REPUTATION >= 65 |
| trophy | A TROPHY SHELF | MEDALS >= 3 |
| fish | A FISH TANK | REPUTATION >= 75 |
| neon | A NEON SIGN | CASH >= 1500 |
| trophies | MORE TROPHIES | MEDALS >= 8 |

Relationship levels: `Social.mood()` is a text scan of the value range -100 to 100: FRIEND at 60 and above, FRIENDLY at 25, NEUTRAL above -15, COLD above -45, HOSTILE below (not data driven: scripts/social.gd).

### 6.9 Skill levels

Experience needed for levels 1 to 5 in each of the 5 skill areas (POWERSHELL, NETWORKING, SERVERS, SECURITY, CUSTOMER). Source: `scripts/skills.gd XP_AT / NAMES`. Rows: 5.

| level | XP needed |
| --- | --- |
| 1 | 15 |
| 2 | 40 |
| 3 | 80 |
| 4 | 130 |
| 5 | 200 |

### 6.10 Owner projects

Client projects the owner can sell (priced, with the hours and weeks they take). Source: `scripts/projects.gd DEFAULT_TYPES`. Rows: 7.

| id | label | price $ | hours | weeks |
| --- | --- | --- | --- | --- |
| desktops | DESKTOP REFRESH (XP REPLACEMENT) | 1800, 3600 | 18 | 2 |
| network | NETWORK UPGRADE (SWITCHES AND WI-FI) | 2800, 3800 | 26 | 3 |
| server | SERVER REPLACEMENT | 6500, 8500 | 44 | 4 |
| voip | PHONE SYSTEM UPGRADE (HOSTED VOIP) | 2200, 3200 | 20 | 3 |
| email_move | EMAIL MIGRATION (HOSTED MAIL) | 1500, 2400 | 22 | 2 |
| backup_dr | BACKUP AND RECOVERY SETUP | 1200, 1600 | 12 | 2 |
| security | SECURITY CLEANUP | 900, 1300 | 14 | 2 |

### 6.11 Deal extras

Add-ons to a managed service contract (monthly fee, cost, points). Source: `scripts/deals.gd EXTRAS`. Rows: 3.

| id | label | fee | cost | points |
| --- | --- | --- | --- | --- |
| backup | MANAGED BACKUP | 110 | 35 | 0.3 |
| patching | MANAGED UPDATES AND AV | 80 | 25 | 0.2 |
| security | MANAGED SECURITY | 95 | 40 | 0.4 |

### 6.12 Sales quotas

The three quota choices of the sales campaign. Source: `scripts/sales_campaign.gd QUOTAS`. Rows: 3.

| id | label | target |
| --- | --- | --- |
| safe | SAFE: $6,500 NEW MRR BY JUNE 30 | 6500 |
| standard | STANDARD: $9,000 NEW MRR BY JUNE 30 | 9000 |
| stretch | STRETCH: $12,000 NEW MRR BY JUNE 30 | 12000 |

### 6.13 Sales prospect types

Kinds of prospect the pipeline draws, with the number of company names and pain points of each. Source: `scripts/sales_campaign.gd TYPES`. Rows: 6.

| id | label | names | pains |
| --- | --- | --- | --- |
| dental | DENTAL | 4 | 4 |
| law | LAW | 4 | 4 |
| vet | VET | 4 | 4 |
| arch | ARCHITECT | 4 | 4 |
| realty | REALTY | 4 | 4 |
| trailer | DEMOLITION | 4 | 4 |

## 7. Rooms and scenes

### 7.1 Every scene

Each scene: width in pixels, left edge, seats, spawn points, usable objects, and the doors to other scenes. Source: `scripts/world_data.gd SCENES`. Rows: 65.

| scene | width | x0 | seats | spawns | uses | doors to |
| --- | --- | --- | --- | --- | --- | --- |
| ballroom | 320 | 24 | 4 | 2 | 0 | resort_lobby |
| bathroom_1 | 128 | 120 | 0 | 2 | 3 | kitchenette |
| bathroom_2 | 128 | 120 | 0 | 2 | 3 | kitchenette |
| bowling_alley | 320 | 24 | 2 | 2 | 1 | main_floor |
| breakout_a | 240 | 64 | 6 | 2 | 0 | resort_hall |
| breakout_b | 240 | 64 | 6 | 2 | 0 | resort_hall |
| breakout_c | 240 | 64 | 6 | 2 | 0 | resort_hall |
| breakout_d | 240 | 64 | 6 | 2 | 0 | resort_hall |
| conference | 320 | 24 | 6 | 3 | 1 | main_floor, cubicle_two |
| cubicle_area | 320 | 24 | 2 | 3 | 5 | main_floor, cubicle_two |
| cubicle_two | 368 | 0 | 4 | 3 | 1 | cubicle_area, conference |
| escape_room | 320 | 24 | 0 | 2 | 9 | main_floor |
| karaoke_bar | 320 | 24 | 6 | 2 | 1 | main_floor |
| kitchenette | 304 | 32 | 0 | 5 | 3 | bathroom_1, bathroom_2, warehouse, main_floor |
| main_floor | 368 | 0 | 3 | 7 | 3 | office_one, office_two, kitchenette, cubicle_area |
| network_closet | 144 | 112 | 0 | 2 | 2 | warehouse |
| office_one | 176 | 96 | 2 | 2 | 1 | main_floor |
| office_two | 176 | 96 | 3 | 2 | 1 | main_floor |
| paintball_field | 700 | -166 | 0 | 2 | 0 | main_floor |
| resort_hall | 320 | 24 | 0 | 6 | 0 | resort_lobby, breakout_a, breakout_b, breakout_c, breakout_d |
| resort_lobby | 320 | 24 | 2 | 5 | 0 | ballroom, resort_hall, vendor_hall |
| restaurant | 320 | 24 | 8 | 2 | 1 | main_floor |
| site_arch_a | 320 | 24 | 0 | 4 | 4 | site_arch_closet_a, site_arch_office_a |
| site_arch_b | 320 | 24 | 0 | 4 | 4 | site_arch_closet_b, site_arch_office_b |
| site_arch_closet_a | 176 | 96 | 0 | 2 | 2 | site_arch_a |
| site_arch_closet_b | 176 | 96 | 0 | 2 | 2 | site_arch_b |
| site_arch_office_a | 240 | 64 | 0 | 2 | 1 | site_arch_a |
| site_arch_office_b | 240 | 64 | 0 | 2 | 1 | site_arch_b |
| site_dental_a | 320 | 24 | 0 | 6 | 3 | site_dental_closet_a, site_dental_office_a, site_dental_exam_a, site_dental_exam_a |
| site_dental_b | 320 | 24 | 0 | 6 | 3 | site_dental_closet_b, site_dental_office_b, site_dental_exam_b, site_dental_exam_b |
| site_dental_closet_a | 176 | 96 | 0 | 2 | 2 | site_dental_a |
| site_dental_closet_b | 176 | 96 | 0 | 2 | 2 | site_dental_b |
| site_dental_exam_a | 240 | 64 | 0 | 2 | 2 | site_dental_a |
| site_dental_exam_b | 240 | 64 | 0 | 2 | 2 | site_dental_b |
| site_dental_office_a | 240 | 64 | 0 | 2 | 1 | site_dental_a |
| site_dental_office_b | 240 | 64 | 0 | 2 | 1 | site_dental_b |
| site_law_a | 320 | 24 | 0 | 4 | 3 | site_law_closet_a, site_law_office_a |
| site_law_b | 320 | 24 | 0 | 4 | 3 | site_law_closet_b, site_law_office_b |
| site_law_closet_a | 176 | 96 | 0 | 2 | 2 | site_law_a |
| site_law_closet_b | 176 | 96 | 0 | 2 | 2 | site_law_b |
| site_law_office_a | 240 | 64 | 0 | 2 | 1 | site_law_a |
| site_law_office_b | 240 | 64 | 0 | 2 | 1 | site_law_b |
| site_realty_a | 320 | 24 | 0 | 4 | 5 | site_realty_closet_a, site_realty_office_a |
| site_realty_b | 320 | 24 | 0 | 4 | 5 | site_realty_closet_b, site_realty_office_b |
| site_realty_closet_a | 176 | 96 | 0 | 2 | 2 | site_realty_a |
| site_realty_closet_b | 176 | 96 | 0 | 2 | 2 | site_realty_b |
| site_realty_office_a | 240 | 64 | 0 | 2 | 1 | site_realty_a |
| site_realty_office_b | 240 | 64 | 0 | 2 | 1 | site_realty_b |
| site_trailer_a | 320 | 24 | 0 | 4 | 4 | site_trailer_closet_a, site_trailer_office_a |
| site_trailer_b | 320 | 24 | 0 | 4 | 4 | site_trailer_closet_b, site_trailer_office_b |
| site_trailer_closet_a | 176 | 96 | 0 | 2 | 2 | site_trailer_a |
| site_trailer_closet_b | 176 | 96 | 0 | 2 | 2 | site_trailer_b |
| site_trailer_office_a | 240 | 64 | 0 | 2 | 1 | site_trailer_a |
| site_trailer_office_b | 240 | 64 | 0 | 2 | 1 | site_trailer_b |
| site_vet_a | 320 | 24 | 0 | 6 | 4 | site_vet_closet_a, site_vet_office_a, site_vet_exam_a, site_vet_exam_a |
| site_vet_b | 320 | 24 | 0 | 6 | 4 | site_vet_closet_b, site_vet_office_b, site_vet_exam_b, site_vet_exam_b |
| site_vet_closet_a | 176 | 96 | 0 | 2 | 2 | site_vet_a |
| site_vet_closet_b | 176 | 96 | 0 | 2 | 2 | site_vet_b |
| site_vet_exam_a | 240 | 64 | 0 | 2 | 3 | site_vet_a |
| site_vet_exam_b | 240 | 64 | 0 | 2 | 3 | site_vet_b |
| site_vet_office_a | 240 | 64 | 0 | 2 | 3 | site_vet_a |
| site_vet_office_b | 240 | 64 | 0 | 2 | 3 | site_vet_b |
| vendor_hall | 320 | 24 | 0 | 3 | 3 | resort_lobby |
| warehouse | 1480 | -556 | 0 | 5 | 13 | kitchenette, network_closet, warehouse_lot, kitchenette |
| warehouse_lot | 780 | -206 | 0 | 2 | 0 | warehouse, warehouse |

Scenes: 65. Seats in total: 66. Scene width runs from 128 to 1480 pixels.

### 7.2 Client sites

The sites you can visit (client index, type, look) and the objects you can use in each site type. Source: `scripts/onsite.gd SITES / OBJECTS`. Rows: 6.

| client | type | skin | objects |
| --- | --- | --- | --- |
| Acme Dental Group | dental | a | pc, exam, xray, cabinet, server, vip |
| Brightside Realty | realty | a | pc, printer, cabinet, server, vip |
| Hoot and Holler Law | law | a | pc, printer, cabinet, server, vip |
| Paws and Claws Veterinary | vet | a | pc, exam, cabinet, server, vip |
| Lindqvist and Moss Architects | arch | a | pc, printer, cabinet, server, vip |
| Iron Mule Demolition | trailer | a | pc, printer, cabinet, server, vip |

### 7.3 Outing floor spots

Standing spots for the crew in each outing room. Source: `scripts/outings.gd SPOTS`. Rows: 9.

| outing | spots |
| --- | --- |
| bowling | 6 |
| karaoke | 6 |
| escape | 6 |
| dinner | 6 |
| chair | 6 |
| cornhole | 6 |
| grill | 6 |
| paintball | 6 |
| darts | 6 |

## 8. Controls and settings

### 8.1 Input actions

Every input action with its keyboard keys and pad buttons or axes (the remappable ones can be changed on the controls screen). Source: `scripts/controls.gd ACTIONS`. Rows: 41.

| action | keyboard | pad |
| --- | --- | --- |
| move_left | A, Left | D-left, LeftX- |
| move_right | D, Right | D-right, LeftX+ |
| jump | Space, W, Up | A, D-up |
| run | Shift | B |
| interact | E | X |
| hurt | H |  |
| die | K |  |
| revive | R |  |
| wave | Q | Y |
| drink | F | LB |
| dance | X | RightY- |
| follow | C | RightY+ |
| duck | S, Down | D-down, LeftY+ |
| aim | Z | RT+ |
| push_a | Z | A |
| push_b | X | B |
| pick_next | Tab | RB |
| pick_prev |  | LB |
| page_prev | Q, PageUp | LB |
| page_next | E, PageDown | RB |
| hold_pose | Tab | Y |
| pose_prev | Comma |  |
| pose_next | Period |  |
| outfit | Y | L3 |
| career | J |  |
| offer_war | V | Y |
| give_item | G | RightX- |
| phone | P | Back |
| character_next |  | R3 |
| mute | M | RightX+ |
| pause | Pause | Start |
| nudge | N | Y |
| outing | O |  |
| mutator | QuoteLeft |  |
| preset | P | Y |
| pray | P | Y |
| shake_left | A | LB |
| shake_right | D | RB |
| hot_next |  | Y |
| hot_go |  | X |
| roll |  | LT+ |

Remappable on keyboard: 14 actions (move_left, move_right, jump, run, interact, wave, drink, duck, dance, follow, phone, aim, outfit, c...). Remappable on pad: 7 (jump, run, interact, wave, drink, phone, pick_next).

### 8.2 Settings and pause menu rows (text scan)

The row labels of the pause menu and the SETTINGS screen, read from `_labels()`. Which rows appear depends on the mode (the day length, ticket pace and outfit rows show only in some modes). Source: `scripts/pause_menu.gd _labels()`. Rows: 13.

| row | source function |
| --- | --- |
| SOUND | pause_menu.gd _labels() |
| UNFOCUSED | pause_menu.gd _labels() |
| DISPLAY | pause_menu.gd _labels() |
| BACK | pause_menu.gd _labels() |
| CONTROLS | pause_menu.gd _labels() |
| SHAPE | pause_menu.gd _labels() |
| DAY LENGTH | pause_menu.gd _labels() |
| CAREER | pause_menu.gd _labels() |
| RESUME | pause_menu.gd _labels() |
| TICKET PACE | pause_menu.gd _labels() |
| OUTFIT | pause_menu.gd _labels() |
| FREE PLAY MENU | pause_menu.gd _labels() |
| QUIT TO TITLE | pause_menu.gd _labels() |

### 8.3 What the settings file saves (text scan)

Every `section.key` written to the settings file by the scripts that use it (`user://mspsim_settings.cfg`). Source: `scripts/{game,difficulty,look,msp,sfx,controls}.gd set_value calls`. Rows: 10.

| section.key | written by |
| --- | --- |
| audio.music_volume | sfx.gd |
| audio.muted | sfx.gd |
| audio.volume | sfx.gd |
| difficulty.tier | difficulty.gd |
| display.focus_pause | game.gd |
| display.format | game.gd |
| display.fullscreen | game.gd |
| look.acc | look.gd |
| look.custom | look.gd |
| pace.tech | msp.gd |

## 9. Technical facts

### 9.1 Screen formats

The window shapes (the SHAPE setting): logical size, integer scale, resulting window, camera zoom, whether the camera follows. Source: `scripts/game.gd FORMATS / ORDER`. Rows: 5.

| format | logical size | scale | window px | zoom | camera follows |
| --- | --- | --- | --- | --- | --- |
| wide | 368 x 128 | 4 | 1472 x 512 | 1.0 | false |
| h | 320 x 180 | 4 | 1280 x 720 | 1.0 | true |
| deck | 320 x 200 | 4 | 1280 x 800 | 1.0 | true |
| v | 180 x 320 | 3 | 540 x 960 | 1.0 | true |
| vclose | 180 x 320 | 3 | 540 x 960 | 2.0 | true |

### 9.2 Export presets

The platforms the project exports to (read from the export presets file). Source: `godot/export_presets.cfg`. Rows: 4.

| preset | platform |
| --- | --- |
| Android | Android |
| iOS | iOS |
| Linux (Steam Deck) | Linux |
| Windows Desktop | Windows Desktop |

### 9.3 Code size

Counted from the file system when generated (this table changes whenever code is added). Source: `godot/scripts, godot/tests, godot/scenes, tools (file system)`. Rows: 5.

| what | files | lines |
| --- | --- | --- |
| game scripts (godot/scripts/*.gd) | 129 | 90657 |
| tests (godot/tests/*.gd, one test each) | 395 | 70241 |
| scenes (godot/scenes/*.tscn) | 68 |  |
| autoloads | 51 |  |
| tools (tools/*.py and *.lua) | 40 |  |

### 9.4 Game art (Godot PNGs)

Image files per asset folder, directly inside it and in its sub-folders. Source: `godot/assets/<folder>/*.png (file system)`. Rows: 6.

| folder | PNGs | PNGs in sub-folders |
| --- | --- | --- |
| accessories | 38 | 0 |
| characters | 150 | 0 |
| clothes | 58 | 0 |
| props | 238 | 0 |
| sets | 69 | 0 |
| ui | 39 | 0 |

### 9.5 Character sheet frames

Frames per character sheet (idle, walk, run, jump, seated life poses, toss, couch and so on, all tagged). Source: `scripts/look.gd, head_gear.gd, clothes_gear.gd`. Rows: 3.

| sheet | frames | source |
| --- | --- | --- |
| animation frames per character | 135 | scripts/look.gd FRAMES |
| head gear frames | 135 | scripts/head_gear.gd FRAMES |
| clothes gear frames | 135 | scripts/clothes_gear.gd FRAMES |

Test files: 395. Story files: 4. The shared `Strings` autoload holds the patchable player-facing text.
