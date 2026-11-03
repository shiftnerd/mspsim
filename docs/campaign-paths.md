# New campaign paths: Owner (as Alan or Garrison), Service Manager (as Dan), Sales (as Vic), plus owners in the tech campaign

Design only, nothing built. Revision 2 (canon change). Read-only pass over CLAUDE.md, IDEAS.md (24-25, 40-52), GAME_BIBLE.md, msp-research.md,
replayability-ideas.md and `campaign, owner, sales, onsite, msp, world, story, playbook, social, cards, day_report, review, title, charselect,
shift, growth, projects, talk, lync, skills` (`.gd`). Effort: S under a day, M 1-3 days, L a week or more.
Parody names only; 2013-14 only (no AI, no Slack/Teams); never punish family or health.

## 0. Canon and the facts that shape the design
**Canon (decided):** Pixel IT Partners has two owners. **Alan = technical owner** (servers, stack, security posture, resolution quality; Office 1).
**Garrison = sales-and-culture owner** (marketing, pricing, morale, outings, client relationships, Vic's pipeline; Office 2). **Morgan Reyes** is the
manager and reports to both. **Marge** is the bookkeeper, **Vic** the account manager, **Dan** and **Maya** the techs, plus hires.

| Path | Played as | Reports to | Cast removed from `World.chars` |
|---|---|---|---|
| Tech (exists) | non-cast (intern/adult/site Alan) | Morgan; owners are the distant top | none (owners get a text/role pass, section 6) |
| **Owner (new pick)** | **Alan or Garrison** | Marge/Morgan advise; the other owner is the partner NPC | the chosen owner |
| **Service Manager** | **Dan** | Morgan, ultimately Alan and Garrison | Dan |
| **Sales** | **Vic** | Garrison (quota/pricing), Alan (margin/delivery), Morgan (delivery gate) | Vic |

Facts that shape everything:
- `Difficulty`, `Events`, `Mutators` (replayability-ideas) are specified (the `difficulty` branch) but not in `godot/scripts/` here. Read seeds/tiers through `Difficulty.get()/rng()` with a `randf()` fallback.
- The owner campaign has a **crew autopilot** (`Owner.team_speed()` + `_work_queue()`, tech-seconds WORK 180/140/100/72, 7% premature closes) gated by `Owner.active()` (`mode == "owner"`, 40+ call sites).
  Its base crew is hard-coded `3 - lost_techs` (Alan, Garrison, Dan); with the owners no longer on the payroll as techs, it needs a re-base (Dan, Maya, Sam, plus the partner's part-time hands-on).
- Free Play offers all seven by ghosting the NPC copy (`npc.gd _process`: `_hidden`); the ghost likely still holds its seat and takes meetings (verify). Campaigns need the Maya pattern.
- `Owner.CARDS` has 15 cards spoken by "Alan (Co-owner)", 16 by Vic, 9 by Marge: those speaker strings are the main text pass for the owner chapter.

---------------------------------------------------------------------------------------------------------------------------------

## 1. Shared prerequisite: playing as a cast member
### 1.1 Today
| Mode | Cast offered? | NPC copy |
|---|---|---|
| Free Play | all seven | ghosted (`_hidden`), keeps living: seat, legs, meetings, lights |
| Tech / Owner | non-cast only (`charselect.choices`) | n/a. Owner mode erases Maya in `World.apply_roster()` ("not on your payroll"), restored elsewhere |

### 1.2 Minimal robust design: `Campaign.player_as`
1. `Campaign.player_as` ("" default; "Alan"/"Garrison" for owner, "Dan" service, "Vic" sales), saved in `campaign` (old saves "" = unchanged).
2. **`World.CAST` stays a const reference table.** Only `World.chars` changes: `apply_roster()` builds a `gone` list (`player_as`), frees nodes and erases them; everyone else is (re)created with `_make_char`.
   **Maya stays in owner mode** now (she is an employee under the new canon; the old exclusion goes away). `CAST` keeps `CAST.keys().find(n)` (lunch seat index), `Social.DESK_OWNER`, `npc.DESKS` valid.
3. **Your desk** = `CAST[player_as].home/seat` via `World.player_desk()`: Alan office_one Seat1, Garrison office_two Seat1, Dan main_floor Seat3, Vic cubicle_area Seat1. New runs start seated there (`Game.vars.start_seated`, `stage.gd`).
   Desk phone (seat-left rule) and desk-outage internal ticket (desks 6/7/3/4) are generic and become yours.
4. **Who covers their duties**: tickets are one shared queue, so nobody loses tickets. Roles are data: `Talk.SPECIALTY` fallback for tips; meeting/lunch seats stay empty; a role map `Roles.who("tech lead")` points cards that said
   "Alan (Co-owner)" at the right person (Dan, Morgan or the partner owner).
5. **Address**: a `role` tag per campaign (`owner`, `manager`, `sales`) read by `Talk` and `Lync`: reports bring you problems, the partner owner talks business, Morgan talks operations.
6. **Their agenda** is dropped, never simulated off-screen; their opinion row disappears (`Social.people()`).
7. `charselect`: owner offers Alan and Garrison (two choices, normal carousel); service offers Dan only, sales Vic only (single card); phone step stays; then the build step (section 13).

### 1.3 Files and functions
| File | Change |
|---|---|
| `campaign.gd` | `MODES` + `service`, `sales`; `player_as`; `new_game/continue_game/save`; per-mode day length (owner 240, service 360, sales 240); `_make_report/_end_day/_ending/report_continue`; reset on quit |
| `world.gd` | `apply_roster` (generalised), `player_desk()`, `send_vic_to_player` -> `send_to_player(name, kind)`, Vic visit/bell legs only if present, `CAST` `role` tags |
| `social.gd` | `PEOPLE` const -> `people()` (readers: `lync.gd` 97/164/293, `computer.gd` 2210, `outings.gd` 753/840/1143, `owner.gd` 3014, `review.gd` 293) |
| `charselect.gd`, `title.gd` | `choices(mode)`, cast note line, menu entries (CONTINUE SERVICE - DAY n), mode map, `_start` |
| `stage.gd`, `hud.gd` | seated start; HUD strings per mode |
| `lync.gd`, `talk.gd` | boss lookup (Morgan in all; Marge in owner), role decks, `_state_tip` per role (28 + 15 name refs) |
| `outings.gd` | `DINERS/BOWL_SKILL/SEATS/totals` -> `roster()` (cast minus `player_as`, plus Maya/Vic); invitation speaker (section 6) |
| `story.gd`, `sales.gd`, `owner.gd`, `msp.gd` | per-mode story tables; NPC-Vic automation off when `player_as == "Vic"`; `Owner.active()` split into `crew_active/books_active/cards_active`; "Dispatch" sender |
| `day_report.gd`, `review.gd` | custom rows (already supported) and offers per mode |
| `meeting.gd`, `conference.gd` | all-hands speech for owner mode; `_boss` shows Morgan in every mode |
**P0 = M.** The **owner campaign is the cheapest proof** (section 3): it already exists end to end, the swap is the same one `apply_roster` does for Maya, and the partner is simply the other cast NPC.

---------------------------------------------------------------------------------------------------------------------------------

## 2. (reserved: layout numbers) Computer UI budget
The computer UI keeps a faded strip on top, leaving about 368x100 in `wide`, 320x150 in `h`, 180x260 in `v`; text is the 3x5 font (4 px per char, about 92 columns wide). All new apps are drawn in code in `Computer`, keyboard first, and fall back to one column in `v`.

---------------------------------------------------------------------------------------------------------------------------------

## 3. Campaign O: OWNER, played as Alan or Garrison
### 3.1 Fantasy and pitch
You and your partner built this place. **Pitch: run Pixel IT Partners as one of its two owners: your instincts get you half the answers, your partner's opposite instincts get you the other half, and sometimes you disagree in front of the staff.**
20 weeks as today (`day_len` 240, Owner books, valuation), but the owner is now a person with strengths, blind spots and a partner.

### 3.2 Two owners, two playstyles
| | **Alan (technical owner)** | **Garrison (sales-and-culture owner)** |
|---|---|---|
| Strong at | stack choices, security, hiring techs, projects, closet/rack, resolution quality | marketing, pricing, outings, morale, client relationships, Vic's pipeline |
| Starting bias (`Build.BIAS`) | TECHNICAL floor 2; SALES/CULTURE cap 2 | SALES and CULTURE floor 2; TECHNICAL cap 2 |
| Mechanical edge | premature closes 7% -> 4%; RDP/ransom odds lower (`_rdp_week`, backup health); stack `issues` x0.9; project estimates tighter | `marketing_bonus` +, `new_client_mood` +4, QBR odds +, burnout relief from outings x1.5, poach risk -2% |
| Mechanical gap | marketing works at 70%; price rises and QBR odds -; Vic's morale drifts down | patch debt and backup health decay faster; premature closes 9%; security cards lean on advisers |
| Personal goal (card at week 1) | "the best technical shop": reopens under 8%, zero data loss, maturity 4 | "the shop clients love": 8+ clients, average mood 85, staff turnover 0 |
| Partner (NPC) | Garrison | Alan |
Valuation (`Owner.multiple/quality`) is unchanged; what changes is **which of its inputs you can move cheaply**. The week-20 board review adds a PARTNERSHIP page (your goal, theirs, trust).

### 3.3 Core loop
Same week structure as today (a week = one 4-minute day: the weekly card deck, the Boardroom, the books), plus three owner-specific verbs:
1. **Walk and talk** with the staff in your own voice (Talk owner deck: HOW ARE YOU HOLDING UP? / ANY IDEAS? already exist), and with Morgan, who now brings the weekly "ops memo" instead of Alan's 15 cards.
2. **Partner decisions**: for about a third of cards the partner has an opinion shown as a chip (AGREES / WARNS / OPPOSES) from `Partner.stance(card)`; you can follow, override or compromise (a third option on some cards).
3. **Partner meeting beats** (weeks 4, 9, 14, 19; conference room scene with the partner NPC at the table; Marge brings the numbers).

### 3.4 Partner mechanics (`Partner` model, small)
- **Trust** (0-100, stored in `Social.rel[partner]`, reused): +2 follow their stance, -3 override, -5 broken promise (you agreed at a partner meeting, then did otherwise), +1 per joint outing.
- **Stance table** `Partner.STANCE[owner][card_id] = {weights}`: e.g. Garrison opposes `stack_rmm` Gold (cost), favours `marketing`, `flex_hours`, outings; Alan opposes premium pricing `welcome`, favours `backup`, `rdp_exposed` fixes, hires.
- **Help**: the partner covers when you are thin: owner hours (Growth pool +6/week while trust >= 60), takes the client call you cannot (`QBR` odds), and acts as a mentor equivalent (cheaper than Dana).
- **Conflict**: below trust 30, the partner can block a decision (card disabled with hint "PARTNER HAS TO AGREE") or openly argue at the all-hands (burnout +2, mood -2). Below 15 the week-19 beat offers a **buyout** (end the partnership: pay or be paid).
- **Beats**: week 4 "the first disagreement" (stack/oncall policy), week 9 "ransomware aftermath" (who gets blamed), week 14 "profit versus people" (fee rise vs staff raise), week 19 "sell or stay" (valuation is the agenda).
- **Endings**: existing offers (SELL / OPEN A SECOND OFFICE / STAY INDEPENDENT) plus BUY OUT YOUR PARTNER (trust < 30, cash >= 15k) and SELL TOGETHER (the best multiple needs both signatures).

### 3.5 Marge, Morgan, Vic
- **Marge** keeps the books (9 cards stay), now says "the partners" and shows each owner's **draw** as a line above EBITDA (adjusted EBITDA adds it back).
- **Morgan** runs the desk day to day; he takes most of the 15 "Alan" cards that were operational (queue, hiring, burnout warning); technical cards go to Alan as owner or Dan.
- **Vic** is a direct report of Garrison in canon: Garrison-as-owner gets Vic's weekly pipeline card and the pay-plan card; Alan-as-owner only sees Vic through numbers and the partner's views (a built-in friction).

### 3.6 Code changes (owner campaign)
| Item | Change |
|---|---|
| Anonymous owner -> a person | `Owner.profile = Build + Campaign.player_as`; `Owner.edge(key)` accessors used in `_finish_ticket` (premature close), `vic_extra`, `marketing_bonus`, `new_client_mood`, `_rdp_week`, `_burnout_week`, `poach_risk` |
| Speakers | `Owner.CARDS` 15 "Alan (Co-owner)" -> `{lead}` token resolved by `Roles` (Dan, Morgan or the partner); also `strings.txt` `[key]`s |
| Roster | `apply_roster` drops the chosen owner, keeps Maya (restore the earlier exclusion test in `tests/maya.gd`); base crew = Dan + Maya + Sam + partner hands-on 0.5 (re-tune `team_speed`, `WAGE` payroll excludes owners) |
| Partner | new `partner.gd` autoload (trust, stance table, meeting cards); NPC partner Alan/Garrison already exists; add a `meeting` leg that seats them at the table at beats |
| Books | draw rows in `settle()`, valuation unchanged, review gets the PARTNERSHIP page and new offers |
| Build | owner stats (TECHNICAL, FINANCE, SALES, CULTURE, CLIENTS) feed the edges above (section 13) |
Effort: **O1 M** (player-as for owners, roles/speakers, crew re-base, partner NPC present, owner-specific goals); **O2 M** (Partner model, stance table, 4 meeting beats, endings); **O3 S** (owner build stats). Tests: `owner.gd` updates, `partner.gd`, `owner_as.gd` (both owners, 20 weeks, each ending), balance runs per owner (`owner_balance.gd -- smart|cheap|greedy` x Alan|Garrison).

---------------------------------------------------------------------------------------------------------------------------------

## 4. Campaign A: SERVICE MANAGER, played as Dan ("Dispatch")
### 4.1 Fantasy and pitch
Dan is the quiet network tech who labels every cable and every drawer. Morgan, with the owners' blessing, makes him the person who owns the process.
**Pitch: the man who labelled the patch panel now has to label the people: run the service desk, keep Maya, two hires and eight clients inside their SLAs, and keep two owners who want opposite things both believing in you.**
Arc: a tech becoming the process owner. He is great at things (networking, documentation, calm in an outage) and bad at the soft part (selling the plan, difficult 1:1s, clients who want a person). 20 working days, **day = 6 min** (`day_len` 360), 4 "months" of 5 days (Friday = review with Morgan). April-June 2014.

### 4.2 Core loop (a day, about 6 real minutes)
| Time | What you do | Existing / new |
|---|---|---|
| 9:00 | **Huddle** card: focus (SLA / projects / training / onboarding), who is out, the owners' memo of the day (see 4.5) | Cards, Story mail; new focus modifiers |
| 9:10-16:00 | **Dispatch**: assign tickets to lanes, escalate, or TAKE IT yourself with the full RMM/PSA flow (Dan's skill profile) | **new Dispatch board** + PSA/RMM |
| continuous | interrupts: Lynk pings from Maya/Sam, client calls, Morgan walks in, an owner leans on you | Lynk, `Msp.phone_call`, NPC `news` leg, Talk |
| walk the floor | E on a tech: 1:1 card (CHECK IN / COACH / PRAISE / REASSIGN / ASK FOR A RUNBOOK); Dan's PEOPLE level decides how much it moves | Talk (manager deck), Social |
| afternoon | **Manager hours** (8/day): runbooks, interviews, onboarding steps, Friday numbers | Knowledge tab, Cards, Playbook |
| 17:00 | scorecard grade S-D, Morgan's confidence and **the two owners' trust** | `DayReport` rows |
Tension: every minute hands-on is a minute the board sits unassigned; every decision pleases one owner and worries the other.

### 4.3 Verbs and UI
Reused: PSA, RMM, Lynk, phone (the "Dispatch" sender is you), Boardroom shell reskinned as **SCORECARD** (BOOKS->SCORECARD, TEAM, CLIENTS keep their code; STACK->DESK DESIGN), Cards, Talk, `Growth` (Dan coaches Maya), `Onsite` (send a tech to a site: NPC leaves via `_visit_plan`).

| New piece | Purpose | Verbs |
|---|---|---|
| **ConnectWhy Dispatch** (PSA tab) | assign, reorder, escalate | Up/Down ticket, Left/Right lane, Enter assign, E escalate (to Dan himself, Alan or Garrison), T take it, A auto policy |
| **Capacity** tab | utilisation and retention | bars; click opens the 1:1 |
| **ConnectWhy Knowledge** tab | runbooks, knowledge hotspots (IDEAS 52); Dan's labelling gives him a bonus | pick a ticket type, spend hours, DRAFT/LIVE/STALE |
| **Scorecard** | FRT, FCR, SLA, backlog age, utilisation, retention, client mood, cost per ticket, **owner trust x2** | read-only, 5-bar trends |
```
BOARD  CAPACITY  KNOWLEDGE  SCORE           SLA 92%  FRT 4M  FCR 61%  BACKLOG 5   10:42   <- 9 px bar
QUEUE (5)                    |MAYA  T1  ###- |SAM   T1  ##-- |DAN(YOU) T2  #--- |ALAN T3 ON CALL  <- lane heads + load bars
>P1 10433 ACME SPOOLER  1:12 |[P2 10431 RDP ]|[P3 10430    ]|[P3 10428      ]|(owner: escalate)
 P2 10435 HOOT RDP      3:20 |[   ####-----]|[ ###------ ]|[ #--------    ]|
 P3 10436 GNARLY SLOW   7:05 | FIT 80%        | FIT 40%       | FIT 95%         |OWNER NOTE: "CLIENTS FIRST"
 P4 10438 ZEN WIFI     11:30 |  ASSIGN(ENTER) ESCALATE(E) TAKE IT(T) AUTO(A) COACH(C)
```
Fit % = skill match x load x mood, shown before you commit. `v` format: queue above, lane cards as a single-column list (as mail/RMM do today).

### 4.4 Starting stats and the Dan bias (point-buy tradeoff)
Dan arrives with `Build.BIAS["Dan"]`: **NETWORKING 3 free**, PROCESS 2 free, SERVERS 1; **PEOPLE and CLIENT RELATIONS capped at 2 at creation**, DISPATCH starts 1. The 12 points therefore buy the soft side
(PEOPLE, CLIENT RELATIONS, ESCALATION JUDGEMENT) at the cost of deeper process or dispatch. Quiet-Dan flavour: low PEOPLE makes 1:1 gains smaller and Lynk replies terse; high PROCESS makes runbooks cheap. Presets: LABEL MAKER (default), COACH, FIREFIGHTER, DIPLOMAT.

### 4.5 Who answers to whom (and the engine of conflict)
| Who | Role | Behaviour |
|---|---|---|
| **Morgan** | Dan's manager | weekly 1:1, passes budget and owner memos; confidence meter (reuses `Campaign.rep`, start 55; 0 = fired) |
| **Alan** | technical owner | wants quality, more seniors, the better stack, zero reopens, documented everything (loves Dan's labelling), grumbles at every miss; escalation target for hard tickets |
| **Garrison** | sales-and-culture owner | wants fast onboarding of Vic's deals, happy clients, a happy team, outings, bigger SLAs promised; escalation target for client fires; may promise a client something over your head |
| Maya | Tier 1 direct report | asks for help often, growth candidate |
| Sam + a second hire | new Tier 1 direct reports | need runtime NPCs with desks and seats |
| Vic | account manager, peer | signs deals Dan must deliver; over-promises; pushes Garrison's agenda |
| Marge | bookkeeper | cost per ticket, overtime pay |
Two trust meters reuse `Social.rel["Alan"]` and `["Garrison"]`. Many choices are a **priority memo** card: both owners ask for opposite things ("patch the whole network first" vs "fix Dr. Patel's Wi-Fi before his lunch");
siding shifts trust (+/-) and desk outcomes; pleasing both is possible but costs hours.

### 4.6 Metrics, win/fail, endings
Daily scorecard grade (SLA 35, FCR 20, FRT 15, backlog age 10, utilisation band 10, morale 10); Morgan's confidence moves with it, the cost per ticket against Morgan's cap, client mood and retention; **fail** at confidence 0 or if both owners' trust < 20.
Endings (day 20 with Morgan and both owners, `Review`): **OPERATIONS MANAGER** (both trust >= 60; a raise, the board moves to a hire), **THE OWNERS' RIGHT HAND** (side with Alan: technical director) or **THE GROWTH MANAGER** (side with Garrison: a bigger role, tougher SLAs promised),
**THE ROLL-UP** (a bigger MSP wants the company; the owners split; your due-diligence scorecard decides; IDEAS 45), **IN-HOUSE IT AT A CLIENT / A BIGGER MSP** (45+), **STAY ON PROBATION** (below 45).

### 4.7 Story beats (20 days; engines named)
| Day | Beat | Engine | Decision / conflict |
|---|---|---|---|
| 1 | **The handover**: Morgan, Alan and Garrison announce Dan runs the desk; the pile is a mess | `Story` mail + `Cards`, `DAY_CAPS` | pick a first priority; Alan wants quality, Garrison speed |
| 3 | **Desk design**: tiered, shared pull queue or pods, dispatcher or not | `Cards` (`STACK`-style `fx`) | Alan wants a senior queue; Garrison wants account pods |
| 4 | **Windows XP wave** | `Playbook` install + `Projects` quotes | who installs; capacity drag |
| 6 | **Hiring**: skill vs fit | `Cards`, `Owner.make_candidates` + fit axis (IDEAS 42) | Alan wants the ringer; Garrison wants the fit |
| 7 | **RDP exposed at Brightside** | `Playbook` rdp | hands-on or coach; Alan will ask for the audit |
| 8 | **Seniors on password resets**: Alan himself is covering tier 1 calls | `Cards` + Capacity | tier the desk; owner time is a cost |
| 9 | **CryptoLocker** at Hoot and Holler: incident commander | `Playbook` ransom | who restores, who talks; Garrison calls the client |
| 11 | **Onboarding Iron Mule Demolition**, which Vic and Garrison promised in a day | `Playbook` (new `onboard`) + handover card | rush vs discovery; Garrison vs Alan |
| 13 | **24x7 email outage night** | `Playbook` email24, `Story.overtime` | roster, burnout, an owner offers to stay |
| 14 | **After-hours policy** | `Cards` (`oncall_policy`) | Alan: rota; Garrison: bonus |
| 16 | **Operationalizing No**: a bad-fit prospect and a scope-creep client | `Cards`, `Projects` change order | Garrison wants the sale |
| 18 | **Grow a Tier 2**: Maya graduates with Dan as coach | `Growth` | learner and skill |
| 19 | **Roll-up audit**: a bigger MSP ("Summit Managed Holdings") audits the desk; the owners disagree about selling | `Story` + `Cards` | prep numbers; what you promise each owner |
| 20 | **Review** with Morgan and both owners | `Review` | ending |
### 4.8 NPC AI, reuse, risks
NPC AI: a `Crew` model per tech `{tier, skills, speed, morale, burnout, tenure, quit_risk, load}` and ticket `assignee`; "stuck" state (`?` bubble, Lynk, timer); overload visuals; quits via a front-door leg; owners walk to Dan with a `news` leg (`send_to_player`) to lean on him.
Reused unchanged: ticket/RMM/PSA systems, `Playbook.BOOKS`, `Onsite`, `Projects`, `Owner` candidates/burnout/poach logic, `Growth`, `Talk`, `Lync`, `Outings`. Changes: `Owner.active()` split, `Msp` `assignee/tier`, `Social.people()`, hire NPCs.
Risks: the board must be prototyped before the story; three NPC lanes are thin (Maya, Sam, Dan) so hires land early (days 3-6) and Alan/Garrison appear as escalation lanes; Morgan needs presence (a role NPC like `Expo._boss`, promote to cast later?); jargon stays period.

---------------------------------------------------------------------------------------------------------------------------------

## 5. Campaign B: SALES / ACCOUNT MANAGER, played as Vic ("Quota")
### 5.1 Fantasy and pitch
**Pitch: sell Pixel IT Partners a book of business big enough to hit quota by June 30, then keep it signed, without promising delivery something it cannot do.** Vic reports to **Garrison** (quota, pricing, marketing), **Alan** sets the margin floor and vetoes unsafe promises,
**Morgan** is the delivery gate, **Dan** feels it. 20 **weeks** (`day_len` 240), April-August 2014; Q2 closes week 12.

### 5.2 Core loop (a week, about 4 minutes; clock hours are selling slots)
| Slot | What you do | Existing / new |
|---|---|---|
| Monday | pipeline review card (Garrison's numbers) | Cards + CRM |
| each hour | PROSPECT / VISIT / QUOTE / HANDOVER / NETWORK / ADMIN | CRM; `Onsite.start_visit`, front-door "Where to?" with drive times and traffic |
| on site | walk the office, talk to the owner (pitch/QBR cards), inspect equipment (findings -> "SELL IT AS A PROJECT") | `Onsite` as-is, extended meetings |
| any time | a client calls about a late ticket; Morgan or Dan says onboarding is slipping | Sales complaint flow reversed, Lynk |
| Friday | commission statement and a decision card (discount request to Garrison, renewal, hot lead) | `DayReport` rows |
Closing a deal lets you ring the bell (a scripted `use:salesbell` for the player; the dart gag stays).

### 5.3 Verbs and UI
Reused: `Onsite` visits and sites, `Projects` quotes/services, `Owner` pay plans/handover/QBR/collections/poach logic, Lynk, Outings (a prospect at dinner). New in `Computer`:
**SalesHound CRM** (pipeline: LEAD > MEETING > PROPOSAL > NEGOTIATE > WON > 90 DAYS), **Quote builder** (price, services, SLA promised, term, hardware, discount, with WIN CHANCE / MARGIN / PROMISE-vs-CAPACITY gauges), **Handover** (cards + conference scene with Morgan and Dan), **Commission** tab.
```
PIPELINE  QUOTE  COMMISSION  RENEWALS      QUOTA Q2 61%  MRR $8.4K  PIPE $21K       Wk 7   <- 9 px bar
LEAD (4)        |MEETING (3)    |PROPOSAL (2)   |NEGOTIATE (1)  |WON 90D (3)
>PIEDMONT PED   |LINDQVIST&MOSS |IRON MULE      |HOOT LAW +SEC  |ACME      OK  82
 $900/WK  20%   | $1.2K  35%    | $700   55%    | $1.6K  70%    |BRIGHTSIDE ! 61
DEAL: PIEDMONT PEDIATRICS  12 USERS  PAIN: HIPAA, XP  RIVAL: BYTEBROTHERS   C CALL  V VISIT  Q QUOTE
```
### 5.4 Metrics, win/fail, endings
Quota (quarterly MRR, tier-scaled), commission from `VIC_PLANS` with clawback on churn inside 90 days; book quality (client mood, 90-day churn, hidden promise gap); pipeline health; **Garrison's trust** is the fail meter with **Alan's trust** as the margin check (reuse `Social.rel`, `Campaign.rep` for Morgan); PIP after two missed quarters; fired at 0.
Endings: SALES DIRECTOR / EQUITY OFFER (Garrison backs you; Alan signs off only if churn is low), TAKE YOUR BOOK TO BYTEBROTHERS, THE ROLL-UP (earn-out tied to retention), STAY.
### 5.5 Story beats (20 weeks)
| Wk | Beat | Engine | Decision |
|---|---|---|---|
| 1 | territory and comp plan from Garrison and Morgan | `Cards` `VIC_PLANS` | salary vs commission-heavy |
| 2 | chamber of commerce lunch | `Outings` restaurant | promise to a stranger |
| 3 | discovery visit at Paws and Claws | `Onsite` + `FINDINGS` | log a ticket or sell a project |
| 4 | XP wave: six desktop prospects | `Projects.make_quote` + builder | price vs margin (Alan) vs speed (Garrison) |
| 5 | first signing and handover with Morgan and Dan | handover cards + conference | disclose or gloss |
| 6 | ByteBrothers undercuts a bid | `Cards` (poach reversed) | match, value-sell, walk |
| 7 | a 1-hour SLA promise hits a P1 | `Sales.deliver` reversed | own it, blame, ask Dan |
| 8 | QBR at your best client, backup upsell | `Onsite` qbr + `Projects.SERVICES` | fee rise vs mood |
| 9 | CryptoLocker at Hoot and Holler: they call you first | story callback | comfort, renew early |
| 10 | quarter crunch, deal slips, end-of-quarter discount | `Cards` | sandbag, discount, miss |
| 12 | Q2 close, first verdict | `DayReport` rows | accelerators, PIP warning |
| 13 | renewals and price rise (60 days' notice) | `Cards` | who to raise |
| 14 | HIPAA omnibus fear (Sept 2013 rule) | `Projects` security + `Cards` | sell what you can deliver |
| 16 | a client leaves for cause, clawback | `Owner.drop_client` style | repair or resign |
| 18 | ByteBrothers recruits you | `Cards` | counter, bluff, leave |
| 19 | roll-up due diligence asks about churn | story mail + `Cards` | disclose or shade |
| 20 | review with Morgan, Garrison and Alan | `Review` | ending |
### 5.6 Cast, reuse, risks
NPC AI is light: prospects are data drawn from a seeded stream (12-15 parody businesses; only 3 have sites, so visits reuse the six site types with a/b skins); the delivery autopilot reacts to promises (SLA tier changes ticket priority and mood);
NPC-Vic automation (`visit_done`, complaint loop) is off; Morgan/Dan walk to you with `send_to_player`. A ByteBrothers rep is a new recolour character. Risks: cards-heavy loops need the van to carry fun; balance must apply `Owner.quality()` to your payout;
company numbers must not fork the owner economy.

---------------------------------------------------------------------------------------------------------------------------------

## 6. Tech campaign: the owners as last-resort help
Minimal changes so Alan and Garrison read as busy owners who still answer a phone when it counts. **No change to the 20-day story**; this is roles, text and one rule.

**Roles and dialogue**
| Area | Change |
|---|---|
| `World.CAST` | add `role`: Alan `owner_tech`, Garrison `owner_sales`; `_plan` kinds for owners: more `meeting`/`visit`/`coffee`, less desk time (Garrison visits like Vic) |
| `Talk` | small talk: payroll, clients, culture, the building lease; specialities stay but in owner voice (Alan servers/backups as cost and risk, Garrison security as compliance and client trust). `_state_tip` rewritten: Alan warns about a failing backup by client name *as a business risk*, Garrison about a client who is cooling |
| `Lync` | `MESSAGES`: "cover my phones" is sent by Dan, Maya or Vic only; owners send lunch/culture/thanks; boss lookup unchanged (Morgan) |
| `Outings` | invitation speaker Garrison (culture owner, pays); Alan still attends (bowling/dinner tables unchanged) |
| All-hands | Morgan briefs as before; day 11 one owner speaks (Garrison: culture/outing; Alan: backup service), day 16 the other |
| `Growth` helper | candidates Dan, Maya, Alan (**availability 60%**: he catches fewer mistakes), Garrison off the list |
| **"Ask for help" lifeline** | for Dan and Maya unchanged (friend fixes your oldest simple ticket). For an owner it becomes **ASK THE OWNER**: Alan *approves* (overtime, buying a part, a vendor call; +10% on the next job), Garrison *calls the client* (SLA +60 s, mood +3 once a day). Neither fixes the ticket |
| Reviews | day-20 quotes by mood include the owners as the people who sign the offer; `Review` mentions them as "the owners" |

**Last-resort trigger (new `Owners.check()` ticked by `Msp`/`World`)**: an owner steps in only when ALL hold: day >= 4; no more than 2 uses a day; 3 game minutes since the last; the owner is in the building and not in a meeting; AND one of
(a) 5 or more open tickets and 2 of them under 30 s from breach, (b) a P1/P2 under 20 s with no player action on it for 40 s, (c) a client complaint (`Sales.pending`) that is still unanswered after one cycle, (d) 3 desk phones ringing at once.
Effects: the owner walks to the nearest ringing phone and answers with a headset (existing `_update_call` path) or takes the complaint; the at-risk ticket gets SLA +45 s; the day report shows `OWNER STEPPED IN: n` (reputation -1 each, never a game over; they remember: Social -1 and a friendly line later). Alan takes technical calls, Garrison clients. Never in Free Play, never days 1-3.
**Minimal code**: `World.send_to_player(name, kind)` (shared with the other campaigns), `Owners.check`, a `cover` leg kind, `Msp` SLA extension hook, `DayReport` row. Effort **S-M**.

**Files/strings needing the text pass** (about 120 `"Alan"/"Garrison"` hits over 17 files): `talk.gd` (15), `growth.gd` (14), `outings.gd` (15), `owner.gd` (29, including 15 "Alan (Co-owner)" speakers), `story.gd` (10), `playbook.gd` (7, incl. the day-19 "only person who knows" job: now an owner-knowledge problem), `projects.gd` (5),
`meeting.gd`, `nerf.gd`, `shift.gd`, `lync.gd` messages, `charselect.gd` blurbs (ALAN: "CO-OWNER, TECHNICAL"; GARRISON: "CO-OWNER, SALES AND CULTURE"), `story/strings.txt` and `STORY.md` (regenerate with `tests/story_export.gd --sync --doc`), `docs/GAME_BIBLE.md` cast table, `CLAUDE.md` cast sections.
Tests: `talk.gd`, `community.gd`, `social.gd`, `growth.gd`, `meeting.gd`, `outings.gd`, new `owners.gd` (trigger rule, cooldowns, no day 1-3, Free Play off), `strings.gd`.

---------------------------------------------------------------------------------------------------------------------------------

## 7. Plugging into Difficulty, seeds, events, mutators
| Hook | Owner | Service (Dan) | Sales (Vic) |
|---|---|---|---|
| `Difficulty.tier` | start cash, partner patience, ticket volume | ticket volume, SLA clocks (`sla_mult`), quit odds | quota size, lead flow, rival aggression |
| `rng(stream)` | `"owner"`, `"partner"`, `"events"` | `"dispatch"`, `"hire"`, `"events"` | `"pipeline"`, `"deals"`, `"events"` |
| Event deck tags | cards unchanged + partner events | printer storm, vendor delay | referral, failed demo, trade-show invite |
| Mutators | existing list | XP end of life, flu season, Heartbleed week | XP end of life, tax season, slow payers |
| Starting conditions | messy MSP / family business | messy desk / only senior left | incumbent book / greenfield |
| Seeds | same events and partner stance rolls | same queue | same pipeline |

## 8. Shared modelling decisions
One **Crew** model (extracted from `Owner`): `autopilot` (today) and `assigned` (service). A **mode registry** `Campaign.MODES = {tech, owner, service, sales}` with `{day_len, total, story_table, report, review, hud, player_as}` replaces about 20 `mode == "owner"` tests.
`Campaign.rep` is the manager's trust in service/sales and the company's reputation in owner mode. Saves: `service`, `pipeline`, `crew`, `partner`, `build` sections with defaults; one save per mode.

### 8.1 The mode registry as built (X8): what a new mode must provide
`Campaign.MODE_DEFS` (campaign.gd) has one row per mode: `tech`, `owner`, `service`, `sales`. `Campaign.MODES` (the title / character-select list) must equal the rows with `selectable: true`; service is registered but `selectable: false`, so `new_game` / `continue_game` refuse it, `charselect.choices` offers nobody and `save()` never writes it (sales was flipped by C1 and also reads the extra row keys `settle: "sales"`, `hud: "week_quota"`, `review: "sales"`). Gates: `Campaign.crew_active()` (autopilot crew: `Owner.team_speed`, `_work_queue`, ticket volume, scope creep), `Campaign.books_active()` (cash, P&L, payroll, settle, valuation, Boardroom app, projects, deal income, Vic's commission), `Campaign.cards_active()` (Owner.DAYS / CARDS, `Owner.begin_day`, partner, player-profile edges, new-client mood, complaints). Rows: tech none; owner all; service crew + cards; sales crew + books (`books_lite`) + cards.
Per-mode properties read from the row: `day_len`, `total_days`, `unit` (DAY / WEEK), `hud` (`day_rep` | `week_cash`), `report` (`day` | `pnl`: pnl runs `Owner.settle()`), `review` (`yearly` | `board` | "" for none), `review_heading`, `review_pages`, `pace` (ticket-rate scalar), `shift` (hour management), `scars` (tech reputation ceiling), `maya_in_events`, `ending_fired`, `ending_final`, `label`.
To add a mode: (1) fill the row and flip `selectable` and `MODES` when the slice is playable; (2) provide its content tables (cards / days, story, report rows), a `Campaign.new_game` branch for `player_as` and `charselect.choices`, a title menu entry; (3) if it needs books or the crew without the owner content, call the gate, never `Campaign.mode == ...`; (4) extend `tests/modes.gd` (gate table) and keep tech / owner results identical. Not yet registry-driven (still `mode == "owner"` for content): Events pools, Mutators slots, Outings costs, Talk / Lync voices, Growth owner plan, Conference speeches. Events and Review still assume 20 days.

## 9. Existing tables reused as-is
`Msp.CLIENTS/PROBLEMS/ALT_DEFS`, `Playbook.BOOKS` (9 jobs), `Onsite` sites/jobs/events/findings/CAST_AT, `Projects.TYPES/SERVICES`, `Owner.STACK/TRAITS/NAMES/VIC_PLANS/GOALS`, `Story.VIGNETTES`, `Talk`, `Lync.MESSAGES`, `Review` shell.
New: `Roles`, `Partner.STANCE`, `Service.DAYS/DESIGNS/RUNBOOKS`, `Crew.TIERS`, `Pipeline.PROSPECTS/OBJECTIONS`, `Quote.OPTIONS`, `Owners` (last-resort), `Talk.MANAGER/SALES/OWNER`, `Events.DECK` rows.

---------------------------------------------------------------------------------------------------------------------------------

## 10. Phased delivery plan
| Phase | Scope | Effort | Playable result |
|---|---|---|---|
| **P0** | Player-as-cast-member: `Campaign.player_as`, `apply_roster`, `Social.people()`, `Outings.roster()`, charselect/title entries, seated start, save/continue, `Roles` map | **M** | pick Alan or Garrison, sit at your desk, cast minus you |
| **O1** | Owner as Alan/Garrison: speaker/text pass on `Owner.CARDS`, crew re-base (Maya stays), partner NPC present, personal goals, owner edges | **M** | **first playable new campaign** |
| **O2** | `Partner` model, stance table, 4 meeting beats, buyout/sell-together endings | **M** | owner chapter complete |
| **T1** | Tech campaign owners: roles, dialogue pass, ASK THE OWNER, last-resort rule, report row | **S-M** | tech run with busy owners |
| **P0b** | Split `Owner.active()`, mode registry, HUD/report/review plumbing | **M** | crew + books can run in the background |
| **S1** | Sales slice: 20-week skeleton, weekly report, leads as cards, visits, quote card, player rings the bell | **M** | cards + van |
| **S2** | SalesHound CRM, deals with promises, quote builder gauges, handover scene, 90-day churn, clawback | **L** | real Sales loop |
| **S3** | Sales beats 1-20, rival, renewals, approvals, endings | **M** | full Sales run |
| **V1** | Service slice: Dan seated at main floor Seat3, huddle card, scorecard, autopilot crew, hands-on, 1:1 deck, owner memos | **M** | Service without a board |
| **V2** | `Crew` model + Dispatch board + Capacity, NPC stuck/overload/quit | **L** | real Service loop |
| **V3** | Knowledge/runbooks, desk design, hiring with fit, onboarding playbook, retention events | **L** | depth |
| **V4** | Service beats 1-20, owner-conflict memos, endings | **M** | full Service run |
| **B0** | Point-buy screen (section 13): tech first, then owner stats with O1, service/sales stats with their phases | **M** + **S** per path | third step on character select |
| **E** | Difficulty/seeds, events, mutators, balance harnesses per campaign | **M** each | replay value |
Order of value: P0, O1, T1 can share a week; Sales about 4 weeks after P0b, Service 5-6 weeks.

## 11. Tests (repo style: `SceneTree` scripts in `godot/tests/`, `_check(ok, what)`, `user://test_` saves, one at a time)
| Test | Covers |
|---|---|
| `playeras.gd` | `choices()` per mode; `new_game` removes the chosen cast member from `World.chars` and `Social.people()`; seated at the right desk; lunch/meetings/all-hands without errors; save/continue keeps `player_as`; Free Play still ghosts; Maya present in owner mode |
| `owner_as.gd`, `partner.gd` | both owners across 20 weeks, edges applied, stance chips, trust, buyout, each ending; `owner.gd`/`owner2.gd`/`owner3.gd` updates for the crew re-base |
| `owners.gd` | last-resort rule: triggers, cooldown, day gate, Free Play off, SLA +45 s, report row |
| `crew.gd`, `dispatch.gd` (+ `_shots`), `service.gd` | assignment, fit, stuck/quit, board key flow, scorecard, owner-memo trust, 20-day run through each ending |
| `crm.gd`, `quote.gd`, `handover.gd`, `sales_campaign.gd` (+ `_shots`) | stage moves, odds, gauges, promise gap, commission/clawback, quota verdicts, 20-week run |
| `*_balance.gd` | strategy runs (smart/cheap/greedy x Alan|Garrison; 3+ runs each) |
| `charselect.gd`, `campaign.gd`, `maya.gd`, `social.gd`, `community.gd`, `outings.gd`, `meeting.gd`, `talk.gd`, `strings.gd` | updated for rosters and text |
| `build.gd`, `seeds.gd` | section 13; same seed -> same pipeline/queue/partner rolls |

## 12. Recommendation
**Build order: P0 -> O1 (Owner as Alan/Garrison) -> T1 -> Sales (Vic) -> Service (Dan).**
1. **Owner-as is the cheapest proof of player-as-cast-member.** The campaign, books, tests and balance harness exist; the swap is the one `apply_roster` already does for Maya; the partner is simply the other cast NPC; no new screens. It proves P0, the `Roles`/speaker pass and the point-buy bias in one M.
2. **T1 is small** and fixes the canon in the campaign people already play.
3. **Sales (Vic) stays the best second new campaign**: cards, project quotes and the Onsite van are the most reusable pieces, and the CRM is a bounded new app. It needs P0b, which Service needs too.
4. **Service (Dan) last**: it needs a new core screen and an assigned-crew simulation before there is anything to play; prototype the Dispatch board as a throwaway in parallel with Sales if you want a flagship sooner.
5. The partner/owners canon makes Service and Sales better: owner conflict gives Dan his story engine, and Garrison/Alan as Vic's two bosses give Sales its approvals and tension.

## 13. Point-buy stats at character select
### 13.1 Stats: existing and new
| Path | Existing stats a build can set | New per-path stats |
|---|---|---|
| Tech | `Skills`: POWERSHELL (`ps_level`), NETWORKING, SERVERS, SECURITY, CUSTOMER (`people` in code), levels 0-5 from XP at 15/40/80/130/200 (`XP_AT`); `Shift.energy` start 80; `Social.rel`; `Growth.gaps()` derives from levels | none |
| Owner | `START_CASH`, owner hours pool (40 minus 12 admin), `burnout`, Vic's plan | **TECHNICAL, FINANCE, SALES, CULTURE, CLIENTS**; Alan floors TECHNICAL 2, Garrison floors SALES and CULTURE 2 (section 3.2) |
| Service (Dan) | the five skills (Dan NETWORKING 3 free) | **DISPATCH, PROCESS, PEOPLE, ESCALATION JUDGEMENT, CLIENT RELATIONS** (Dan: PROCESS 2 free; PEOPLE and CLIENT RELATIONS capped at 2 at creation) |
| Sales (Vic) | `Sales.vic_skill` inputs, `Owner.VIC_PLANS` | **PITCH, DISCOVERY, NEGOTIATION, RELATIONSHIPS** + **HONESTY** slider (PITCH floor 2) |
Every stat is a 0-5 level read through `Build.level(stat)`; `Build.BIAS[cast_name]` gives free floors and creation caps that do not spend points, so a cast member stays himself and the budget buys the tradeoff.
### 13.2 Model
- **Budget** 12 at Normal, Easy 15, Hard 9 (from `Difficulty.tier`; the run seed is shown "RUN 4F2A9C" and saved; same seed + same build = same run).
- **Cost (cumulative)** L1 1, L2 2, L3 4, L4 7, L5 11. Max 4 at creation (5 is earned), one stat at 4, min 0 (bias floors excepted).
- **Quirks**: up to 2 negatives give +2 each (CAFFEINE DEPENDENT: energy 65; SLOW STARTER: +20% XP needed; OVER-PROMISER for sales; STUBBORN for owners: partner trust -10); one positive costs 2. No family/health penalties.
- **Presets** (then tweak, or CUSTOM): tech GENERALIST / SCRIPTER / NETWORK NERD / PEOPLE PERSON; service LABEL MAKER / COACH / FIREFIGHTER / DIPLOMAT; sales HUNTER / FARMER / CONSULTANT / SMOOTH TALKER; owner (Alan) ARCHITECT / COST CUTTER / HIRER, (Garrison) BRAND BUILDER / PEOPLE FIRST / CLOSER.
- **Guards**: no stat above 4 at creation, five-skill total >= 4 (tech), the Adobe ticket and day-4 install stay passable at all-zero skills (they are easy and capped by `DAY_CAPS` 1/3/5), warning when CUSTOMER 0 and SECURITY 0 together.
### 13.3 UI: step 3 of `charselect.gd` (character -> phone -> build; owner and service/sales skip the phone step if the Phone choice is not needed)
Reuses the `step` machine, panel/GOLD/DIM styling and `hint` footer `UP DOWN STAT  LEFT RIGHT LEVEL  P PRESET  ENTER GO`; `_rects` gets `pip` and `preset` kinds; mouse clicks pips and chips; Esc steps back.
```
YOUR BUILD            POINTS LEFT 3        RUN 4F2A9C      <- wide 368x128
POWERSHELL  ##---  L2     NETWORKING  #----  L1              (2 columns x 3 rows, 10 px rows, 4x4 pips; bias floors drawn gold)
SERVERS     ###--  L3     SECURITY    -----  L0
CUSTOMER    #----  L1     QUIRK  CAFFEINE DEPENDENT (+2)
PRESET: SCRIPTER  > FIXES RUN FASTER. NOBODY LIKES YOU YET.
```
`h` (320x180): same columns with a 3-line effect box. `v` (180x320): single column, 12 px rows, preset chips on a row of four (P cycles), 3-4 line effect text. Summary line: "SERVICE MANAGER - DAN - IFONE 5 - LABEL MAKER". Continue skips the screen.
### 13.4 Where it feeds the game
`Skills.reset()` starting XP = `XP_AT[level-1]` (PowerShell stat sets `ps_level`); level perks (backup watch, patch-panel hints, open docs, `sla_pace`) live from day 1; `Growth.gaps()` names your weakest skill; `Talk/Lync` tone reads the top stat; PEOPLE starts `Social` +10 with the team;
`Shift` start energy from quirks; owner edges (3.2) and `Partner.trust` start from CULTURE; service board fuzz (DISPATCH), runbook speed (PROCESS), 1:1 gain (PEOPLE); sales odds and clawback risk (PITCH/DISCOVERY/NEGOTIATION/HONESTY). The review quotes the build.
### 13.5 Saves, per path, effort
`campaign.build = {preset, stats, quirks, spent, tier, seed}`; `Build.from_dict({})` = the flat default build (all 0, no quirks = today's behaviour) so old saves and direct `new_game` tests are unchanged. Free Play: no build screen (an optional MAX preset for filming).
Effort: `Build` data/guards/saves **S**; `charselect.gd` build step **M**; wire into `Skills/Shift/Growth` **S**; per-path stat tables and readers **S** each inside their phases. Tests: `build.gd` (costs, budget per tier, guards, presets, bias floors/caps, old-save default), `charselect.gd`, `build_playthrough.gd` (all-zero build passes days 1-4; level-4 build has perks on day 1), `charselect_shots.gd` in three formats, tier x seed in `seeds.gd`.
Risks: a third step on tight narrow formats; perks from day 1 need balance runs per preset; the `difficulty` branch must merge first or tier reads fall back to Normal.

## 14. Decisions and open questions
**Decided by the user**
- **Morgan Reyes is a real cast member** (desk, agenda, Social / Lync / Talk entries), not a role NPC. Consequences to design in P0/O1: where Morgan sits (an office, the conference room, or a main-floor desk), a routine (meetings, floor walks, all-hands host), `World.CAST` / `Social.PEOPLE` / `npc.DESKS` entries, a Lync contact (Morgan is already the boss contact), and `Expo._boss` / the all-hands whiteboard switching to the real NPC. The service campaign benefits (Morgan can show up often).
- **Owners take a weekly draw from the bank balance** in the owner campaign (cash, not EBITDA): a weekly line on the P&L and the cash flow, a personal goal / partner-trust hook (a big draw makes the partner uneasy), tied to the weekly report; the amount is a card or policy choice, not free.
- **An owner stepping in costs no reputation** in the tech campaign: the last-resort help is free (a report row and a short banter line only).
- **Canon text pass** (Alan and Garrison cast as owners in dialogue, tips, Lynk, vignettes): **undecided**, parked in `docs/ROADMAP.md`; the design above assumes it eventually happens.

**Still open**
1. Owner base crew after the re-base: Dan + Maya + Sam + partner 0.5 hands-on. Is that the intended size, or should the owners keep working tickets at full speed in the owner campaign?
2. Day lengths: Service 6 min/day, Sales and Owner 4 min/week; acceptable?
3. Hires (Sam and a second) need runtime NPCs with desks: fixed list or random from `Owner.NAMES`?
4. Placeholder parody names: SalesHound CRM, ConnectWhy Dispatch, ConnectWhy Knowledge, "Summit Managed Holdings".
5. Should the tech campaign's day-6 Growth helper pick still offer Alan at 60% availability, or only Dan and Maya?
6. Does the Sales campaign need an "office walk-in" scene for prospects without sites, or may prospects reuse the six site types?
7. Morgan's desk and daily routine (see Decided).
