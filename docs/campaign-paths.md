# Two new campaign paths: Service Manager (Garrison) and Sales / Account Manager (Vic)

Design only, nothing built. Read-only pass over CLAUDE.md, IDEAS.md (items 24-25, 40-52), GAME_BIBLE.md, msp-research.md,
replayability-ideas.md and `campaign, owner, sales, onsite, msp, world, story, playbook, social, cards, day_report, review,
title, charselect, shift, growth, projects` (`.gd`). Effort: S under a day, M 1-3 days, L a week or more.
Parody names only; 2013-14 only (no AI, no Slack/Teams, no 2015+ tools); never punish family or health.

Two facts that shape everything:
- `Difficulty`, `Events` and `Mutators` (replayability-ideas) are **specified but not in `godot/scripts/` yet**. Both campaigns must
  read seeds/tiers through a thin `Difficulty.get()/rng()` call that falls back to `randf()` until it lands (section 8).
- The owner campaign already contains a **crew autopilot**: `Owner.team_speed()` + `_work_queue()` (WORK 180/140/100/72 tech-seconds by
  priority, 7% premature closes) works the real `Msp` queue with no per-person assignment. Both new campaigns need it, but it is gated
  by `Owner.active()` (`Campaign.mode == "owner"`), which 40+ call sites use. Splitting that gate is the real shared work (P0b).

---------------------------------------------------------------------------------------------------------------------------------

## 1. Shared prerequisite: playing as a cast member

### 1.1 How it works today
| Mode | Cast member offered? | What happens to the NPC copy |
|---|---|---|
| Free Play | all seven (`Player.CHARACTERS`) | `npc.gd _process`: `character == PLAYER.current_character` sets `_hidden` (invisible, `monitoring` off). The NPC **keeps living**: legs, seat, meetings, lights, phone. 1-7 keys switch live (that is why a ghost is used). |
| Tech / Owner | only non-cast: teen, adult, site Alan (`charselect.choices`) | n/a. Owner campaign removes Maya with `World.apply_roster()` (`chars.erase("Maya")`), restored in tech/Free Play. |

The ghost is fine for filming and wrong for a campaign: it still occupies its `Seat` (`seat.occupied`, so likely blocks your own
desk; verify), takes meetings and lunch seats, counts in `Social.average()`, Lync presence and `Outings` rosters, and `Owner.team_speed`
would still count Garrison as a tech. **Recommendation: reuse the Maya pattern, not the ghost.**

### 1.2 Minimal robust design: `Campaign.player_as`
1. `Campaign.player_as: String` ("" default; "Garrison" for `service`, "Vic" for `sales`), saved in the `campaign` section
   (`player_as`; old saves default "" so tech/owner are unchanged). Set by the character-select result, never by tests unless they ask.
2. **`World.CAST` stays a const reference table.** Only `World.chars` changes: `apply_roster()` builds a `gone` list
   (`Maya` in owner mode, plus `player_as` in any campaign), frees those nodes, erases them; everyone else is (re)created with `_make_char`.
   Keeping `CAST` intact avoids breaking `CAST.keys().find(n)` (lunch seat index), `Social.DESK_OWNER`, `npc.DESKS`, Expo/Outings tables.
3. **Your desk** = `CAST[player_as].home/seat` (`World.player_desk()`). New runs start seated there: `Game.go(home, "start")` plus a
   `Game.vars.start_seated` flag handled in `stage.gd`. Garrison: `office_two` Seat1 (a door, a couch, a whiteboard: a manager's office).
   Vic: `cubicle_area` Seat1. The desk phone (owned by the seat to its left), the desk-outage internal ticket (desk 7 / desk 4) and the
   monitor/PC are already generic, so they become yours with no change.
4. **Who covers their duties**: tickets are one shared queue, so nobody "loses" tickets. What is lost is *roles*, handled in data:
   `Talk` specialty tips (Garrison = security, Vic = people/clients) move to Dan/Alan/Maya via a `Talk.SPECIALTY` fallback;
   meeting/lunch seats stay empty (6 conference seats, so fine); Vic's visits, complaint delivery and the sales bell become *your* verbs.
5. **How coworkers address you**: add a `role` tag per campaign (`manager`, `sales`) read by `Talk` and `Lync`: reports bring you
   problems ("Maya: stuck on a profile, can you look?"), they call you "boss" or "Garrison"/"Vic" by name instead of the neutral tech voice.
6. **Their own agenda** is dropped, never simulated off-screen. Their *opinion of you* row disappears (`Social.people()` below).
7. `charselect`: the new modes offer exactly one character (`choices()` returns `["casual_garrison"]` / `["sales_vic"]`, the carousel
   shows one name and blurb, the phone step stays). Optional later: let tech/owner pick a cast member too (the same switch).

### 1.3 Every file/function to touch
| File | Function / data | Change |
|---|---|---|
| `campaign.gd` | `MODES`, `new_game`, `continue_game`, `save`, `_begin_day`, `_make_report`, `_end_day`, `_ending`, `report_continue`, `quit_to_title` | add `service`/`sales`, `player_as`, per-mode day length (service 360 s, sales 240 s), report builders, `Review.start()` for both; reset `player_as` on quit |
| `world.gd` | `apply_roster`, `begin_next_day`, `_make_char`, `send_vic_to_player`, `_visit_plan`, `_finish_leg` (bell), `_watch_outage` list | generalise roster; add `player_desk()`; `send_to_player(name, kind)` replaces the Vic-only call; Vic visit/bell legs only when `chars.has("Vic")` |
| `social.gd` | `PEOPLE` (const, 8+ readers), `average`, `change_all`, `reset`, `from_dict` | `people()` function (drops `player_as`; also fixes owner mode still counting Maya at 0); readers: `lync.gd` 97/164/293, `computer.gd` 2210, `outings.gd` 753/840/1143, `owner.gd` 3014, `review.gd` 293 |
| `charselect.gd` | `choices`, `setup`, `_draw_chars` note line, `PEOPLE` blurbs | per-mode single choice; "YOU RUN THE DESK" blurb; no cast note |
| `title.gd` | `_open_menu`, `_open_select`, `_start`, labels | two menu entries (+ CONTINUE SERVICE - DAY n), mode map, `Campaign.new_game` |
| `stage.gd` / `player.gd` | start spawn | start seated; HUD mode string in `hud.gd` (`DAY n/20 CONF r`, `WEEK n/20 QUOTA q%`) |
| `lync.gd` | `contacts`, `_boss` (returns Marge/Morgan), message deck, presence | Morgan is the boss in both; role-based message decks |
| `talk.gd` | per-person voices (28 refs to names), `_state_tip`, specialty | manager and sales decks; fallback specialty; no card for the missing person |
| `outings.gd` | `DINERS`, `BOWL_SKILL`, `SEATS`, `totals`, names list at 1407, `PLAYER_SEAT` | `roster()` (also replayability item 5): cast minus `player_as`, plus Maya/Vic |
| `meeting.gd`, `conference.gd` | all-hands, `_boss` | manager gives the speech (owner-style card); Rodent Nation stays tech-only (sales variant is a later option) |
| `story.gd` | `_process` gate `mode == "tech"` | per-mode `DAYS` tables (`Story.DAYS`, `Service.DAYS`, `Sales2.DAYS`), same event kinds |
| `sales.gd` | `visit_done`, `_process` complaint loop, `vic_skill`, `deliver` | skip NPC-Vic automation when `player_as == "Vic"`; complaints become cards to you |
| `owner.gd` | `active()`, `_process`, `_work_queue`, `begin_day`, `settle` | split into `crew_active()` (autopilot), `books_active()`, `cards_active()` (P0b) |
| `msp.gd` | `send_text("Dispatch", ...)`, `day_cap`, `create_problem` | "Dispatch" is you in the service campaign; tickets get optional `assignee`, `tier` fields (service) |
| `day_report.gd`, `review.gd` | `_groups`, `make_offers`, `EPILOGUES` | `report.rows` already supports custom books (owner); add rows + offers per mode |
| tests | `charselect`, `campaign`, `maya`, `social`, `community`, `outings`, `meeting`, `strings` | update; new `playeras.gd` (section 9) |

Effort **P0 = M** (2-3 days), mostly the `Social.people()` / `Outings.roster()` sweeps and the save/continue paths.

---------------------------------------------------------------------------------------------------------------------------------

## 2. Campaign A: SERVICE MANAGER (play Garrison, "Dispatch")

### 2.1 Fantasy and pitch
You are the one who made the queue stop being a fire. **Pitch: run the service desk, not the company: keep four techs and eight clients inside their SLAs
without burning anyone out, while Morgan asks why it costs so much.** Backstory: it is the "BECOME TEAM LEAD" ending of the tech review (Morgan "wants you to run
the service desk"); Garrison is the security-minded tech who got the job. Fixed 20 working days, **day = 6 min** (`day_len` 360), 4 "months" of 5 days
(Friday = weekly review with Morgan). Period: April-June 2014, the XP wave, RDP, CryptoLocker, Heartbleed.

### 2.2 Core loop (typical day, ~6 real minutes)
| Time | What you do | Existing / new |
|---|---|---|
| 9:00 | **Huddle**: a card with the day's focus (SLA / projects / training / onboarding) and who is out. Morning mail from Morgan with a metric to move. | Cards + `Story` mail; new focus modifiers |
| 9:10-16:00 | **Dispatch**: tickets land in the queue; assign to a tech lane, set priority, escalate, or TAKE IT yourself (full hands-on RMM flow with Garrison's skills: SECURITY 3, others 1-2). | **new Dispatch board** + PSA/RMM as-is |
| continuous | **Interrupts**: Lynk pings ("Maya: stuck, can you look?"), a client phone call (answer = it becomes a ticket, as today), Morgan walks in, a tech sighs and heads for the kitchenette. | Lynk, `Msp.phone_call`, NPC `news` leg, Talk |
| walk the floor | E on a tech: **1:1 card** (CHECK IN / COACH / PRAISE / REASSIGN / ASK FOR A RUNBOOK). Moves morale, opinion, skill growth. | Talk (new manager deck), Social |
| afternoon | **Manager hours** (budget 8/day, like owner hours): write a runbook for the top repeat ticket, interview a candidate, run an onboarding step, prepare Friday's numbers. | new Runbooks tab, Cards, Playbook |
| 17:00 | Report: scorecard grade S-D and Morgan's confidence. Friday: review card in the conference room. | `DayReport` rows |

Minute to minute the player is mostly in the Dispatch board and walking to people, with RMM/PSA available whenever they want to be a tech again
(the thing the game already does well). **Tension**: you cannot do everything; every minute hands-on is a minute the board sits unassigned.

### 2.3 Verbs and UI
Reused: **PSA** (ticket detail, SLA clock), **RMM** (hands-on fixes; Garrison's skill profile), **Lynk** (escalations, Morgan), **phone** (texts from techs and clients; the
"Dispatch" sender becomes you), **Boardroom** shell reskinned as **SCORECARD** (BOOKS->SCORECARD, TEAM, CLIENTS tabs keep their code; STACK->DESK DESIGN), **Cards**, **Talk**,
**Growth** (coaching Maya/Dan toward Tier 2 with you as the helper), **Onsite** (assign a tech to a site job; the NPC leaves by the front door, `_visit_plan`).
New (all in `Computer`, drawn in code with `PixelFont`, tab bar like the RMM):

| New piece | Purpose | Verbs |
|---|---|---|
| **ConnectWhy Dispatch** (PSA tab) | assign, reorder, escalate | Up/Down ticket, Left/Right lane, Enter assign, E escalate, T take it, A auto-assign policy |
| **Capacity** (tab) | utilisation and retention at a glance | read-only bars; click a tech to open the 1:1 |
| **ConnectWhy Knowledge** (tab) | runbooks, "knowledge hotspots" (IDEAS 52) | pick a ticket type, spend manager hours, status DRAFT/LIVE/STALE |
| **Scorecard** (Boardroom reskin) | FRT, FCR, SLA, backlog age, utilisation, retention, client mood, cost per ticket | read-only; trends as 5-bar sparklines |
| 1:1 card deck | talk to reports | via `Talk`, a new `manager` deck |

Dispatch board against the 368x128 viewport (the computer UI keeps a 20% faded strip, so ~368x100 is usable; each char is 4 px, ~92 columns):
```
BOARD  CAPACITY  KNOWLEDGE  SCORE            SLA 92%  FRT 4M  FCR 61%  BACKLOG 5   10:42    <- 9 px bar
QUEUE (5)                    |ALAN  T2  ###- |DAN   T1  ##-- |MAYA  T1  #--- |SAM   T1  ----    <- lane head: load bar
>P1 10433 ACME SPOOLER  1:12 |[P2 10431 RDP ]|[P3 10430    ]|[P3 10428    ]|(free)             <- slot 1 (chip 60x14)
 P2 10435 HOOT RDP      3:20 |[   ####-----]|[ ###------ ]|[ #--------  ]|                    <- progress under chip
 P3 10436 GNARLY SLOW   7:05 |               |               |               |
 P3 10437 BRIGHT PRINT  8:40 |ESC>ME ESC>MGR |T:ASK  FIT 80% | NEW  FIT 40%  |                    <- selected ticket's fit per lane
 P4 10438 ZEN WIFI     11:30 |  ASSIGN(ENTER) ESCALATE(E) TAKE IT(T) AUTO(A) COACH(C)           <- hint bar, KEY = ACTION style
```
Fit % = skill match x load x mood; it is shown *before* you commit, and it is the main readable lever. Narrow `v` format (180 px): queue and lanes stack
(queue on top, lane cards below as a swipe row), 1 column like mail/RMM do today. Capacity tab is 4 rows x (name, tier, load bar, morale face, burnout, tenure).

### 2.4 Metrics, win/fail, endings
- **Daily scorecard** (grade S-D; replaces tickets/paycheck): SLA met % (35), FCR (20), first response time (15), backlog age (10), utilisation in the 70-85% band (10), team morale (10).
- **Morgan's confidence** (0-100, reuses `Campaign.rep`, start 55): +/- from the scorecard, cost per ticket versus Morgan's cap, client mood (`Sales.average`), retention. **0 = fired.** Also fail: two quits in a week with no hire.
- **Tech health** per person: skill, morale, burnout, tenure, quit risk (Owner `_burnout_week`, `_staff_week`, TRAITS reused). **Retention** is a scored stat, not a side effect.
- **Endings (day 20 review with Morgan, `Review` with `Service.offers()`)**: PROMOTED TO OPERATIONS MANAGER (confidence 70+, retention intact, maturity >= 3: a raise and the "Dispatch" job moves to a hire);
  **THE ROLL-UP** (a bigger MSP buys Pixel IT Partners; you run its integrated service desk; needs a clean scorecard and no open ransomware loss; IDEAS 45);
  TAKE THE JOB AT A CLIENT / A BIGGER MSP (always offered at 45+); STAY ON PROBATION (below 45). Records `[service] ending` in `meta.cfg`.

### 2.5 Story beats (20 days; engines named)
| Day | Beat | Engine | Decision / what changes |
|---|---|---|---|
| 1 | **The handover**: Morgan gives you the keys; baseline scorecard; the pile is a mess, only 2-3 tickets spawn (as `DAY_CAPS`) | `Story` mail + `Cards` | pick your first priority |
| 3 | **Desk design**: tiered, swarm or pods; with or without a dedicated dispatcher | `Cards` (`STACK`-style options with `fx`) | sets assignment rules (Tier 1/2/3 limits, who may pull) |
| 4 | **Windows XP deadline** wave: five desktop jobs at once; the install playbook, run as a team | `Playbook` (`install`) + `Projects` quotes | assign the install to whom; capacity drag (`Projects.drag`) |
| 6 | **Hiring**: three candidates (skill vs fit), a 15-minute interview card per candidate | `Cards`, `Owner.make_candidates` + new fit axis (IDEAS 42) | Sam joins; ringer vs good-fit |
| 7 | **RDP exposed at Brightside**: your specialty; you can run it or delegate and coach | `Playbook` `rdp` | hands-on (Garrison SECURITY) vs growth |
| 8 | **Seniors on password resets**: Alan's utilisation view turns red, he hints he is bored (IDEAS 47) | `Cards` + Capacity tab | tier the desk, write a runbook, or lose a senior |
| 9 | **CryptoLocker at Hoot and Holler**: incident commander; assign roles | `Playbook` `ransom` (+ backup flag from earlier checks) | who restores, who talks to the client |
| 11 | **Onboarding without the client's runbook**: Iron Mule Demolition, signed by Vic with promises (IDEAS 40) | `Playbook` (new `onboard`) + handover card | discovery checklist vs rush; Vic's over-promise surfaces |
| 13 | **24x7 email outage night** | `Playbook` `email24`, `Story.overtime` | roster the night, who goes home (burnout, overtime budget) |
| 14 | **After-hours and pager policy** | `Cards` (`oncall_policy`, `after_hours` re-voiced) | rotate / stipend / you carry it |
| 16 | **Operationalizing No**: Vic brings a bad-fit prospect and a scope-creep client | `Cards` (IDEAS 43), `Projects` change order | say no, charge, or absorb |
| 18 | **Grow a Tier 2**: Maya or Dan graduates with you as coach | `Growth` (owner-style plan) | pick learner and skill, protect 30 minutes |
| 19 | **Roll-up rumour**: a bigger MSP (parody "Summit Managed Holdings") audits your desk | `Story` mail + `Cards` | prep the numbers; what you promise Morgan |
| 20 | **Review with Morgan** | `Review` | choose an ending |
Quiet days use `Story.VIGNETTES`-style cards re-voiced for a manager (Dan's missing label, Maya's granola bar, Alan's donuts) and the event deck.

### 2.6 Cast behaviour and NPC AI
| Who | Role | Behaviour needed |
|---|---|---|
| Morgan Reyes | your boss (owner/GM, see risks) | walks in for 1:1s (`send_to_player` + `notify:` step), stands at the whiteboard Fridays (`Expo._boss` style role), texts/Lynks budget pressure |
| Alan | Tier 2 senior | quiet frustration when stuck on routine tickets, warns about backups, may quit |
| Dan | Tier 1 / network | fast on network tickets; overloads without complaining (hidden burnout the Capacity tab reveals) |
| Maya | Tier 1 junior | asks for help more, growth candidate; granola bar jokes |
| Sam (and a 2nd hire) | new Tier 1 | joins via `World.chars` (new `CAST`-like entry created at runtime: needs a desk and a seat, **the main structural NPC task**) |
| Vic | peer, sales | keeps selling (existing NPC automation), over-promises; you can push back; the antagonist/ally |
| Clients | via phone/Lynk/PSA | mood from `Sales.satisfaction`; their contacts email escalations naming you |
**NPC AI needed**: (1) a `Crew` model per tech `{tier, skills, speed, morale, burnout, tenure, quit_risk, load}` with an `assignee` on tickets and per-ticket progress
(replaces the anonymous `_work_queue` for this mode; the owner mode keeps the anonymous version); (2) a "stuck" state: the NPC node gets a `?` bubble, a Lynk message and
a timer; unanswered stuck tickets bounce or reopen; (3) sulk/overload visuals (kitchenette trips, sighing, `talk` anim at a coworker) driven by morale; (4) quits: the NPC
walks out (`exit:FrontDoor` leg) and is removed from `chars`; (5) the Capacity view reads the same model, so one data source feeds NPC acting and UI.

### 2.7 What is reused / what changes
Reused as-is: ticket/RMM/PSA/backup/ALT_FIXES systems, `Playbook.BOOKS` (rdp, ransom, rack, migration, email24, netinstall, ceofraud, no2fa, bus), `Onsite` jobs/events/findings and
sites, `Projects` quotes/services, `Owner.TRAITS/NAMES/make_candidates`, burnout, poaching/winback logic (from the client side), `Growth`, `Talk`, `Lync`, `Outings`, `Review` shell, `Cards`.
Must change: `Owner.active()` split (P0b); `Msp` tickets get `assignee`/`tier`; `Social.people()`; per-mode `Story` tables; day report rows; hiring adds a **fit** axis; a hire needs
a runtime NPC (desk + seat; desks 1 and 5 on the main floor are free, there are 8 patch-panel ports); `Shift` (energy, commute, pager) stays tech-only.

### 2.8 Risks and open questions
- The Dispatch board is the whole game: if assigning feels like busywork it fails. Prototype it **before** any story (L, section 7). Keep it keyboard-first, never more than 4 lanes.
- Only 3 NPC techs exist at the start (Alan, Dan, Maya): a "board" with three lanes is thin. Mitigation: Sam on day 6, a second hire day 13, and hands-on TAKE IT as a fourth lane (you).
- Lore: Morgan is "manager" in the tech campaign (Story.MANAGER, review). Decide: Morgan = owner and GM, or a regional owner; patch the strings once.
- Metric vocabulary must stay period (first-call resolution, utilisation, SLA: fine; avoid "swarming" jargon in text, say "everyone pulls from the queue").

---------------------------------------------------------------------------------------------------------------------------------

## 3. Campaign B: SALES / ACCOUNT MANAGER (play Vic, "Quota")

### 3.1 Fantasy and pitch
You are the guy with the bell. **Pitch: sell Pixel IT Partners a book of business big enough to hit quota by June 30, then keep it signed, without promising the techs something they cannot deliver.**
Comedy engine: Vic's over-promising is a *choice* now, and Garrison, Alan and Dan are the ones who call it out. Fixed 20 **weeks** (`day_len` 240, like the owner campaign), April-August 2014; quarter ends at week 12 (Q2) and week 20.

### 3.2 Core loop (a week, ~4 real minutes; the clock hours are your selling slots)
| Slot | What you do | Existing / new |
|---|---|---|
| Monday 9:00 | **Pipeline review** card: this week's leads, deals needing action, the quota gauge | Cards + CRM |
| each hour | choose a slot action: **PROSPECT** (call/email a lead), **VISIT** (drive to a site: discovery, pitch, check-in, QBR), **QUOTE** (build a proposal), **HANDOVER** (meet delivery), **NETWORK** (chamber lunch at the restaurant), **ADMIN** (renewals, CRM) | new CRM; `Onsite.start_visit`, front-door "Where to?" menu with real drive times and traffic |
| on site | walk the office, talk to the owner (pitch/QBR meeting cards), inspect equipment (findings -> "SELL IT AS A PROJECT") | `Onsite` as-is, extended meetings |
| any time | Lynk/phone: a client calls the account manager about a late ticket; Garrison says the onboarding is slipping; Morgan wants a forecast | Sales complaint flow reversed, Lynk, Talk |
| Friday 16:00 | **Commission statement** and one decision card (discount request to Morgan, renewal, a hot lead) | `DayReport` rows |
Drives and walk-arounds are the visual strength of the game; this campaign finally makes the van the main verb. Closing a deal: you **can ring the bell** yourself (a scripted `use:salesbell`
for the player, the dart gag stays for everyone else).

### 3.3 Verbs and UI
Reused: **Onsite** visits (`start_visit(client, "pitch"|"qbr")`, b-skin prospect offices, walk-around findings), **Projects** quote cards (4 methods) and `SERVICES` (backup/patching upsells),
**Owner** pay plans (`VIC_PLANS`) and `on_deal`, `_handover_card`, `_qbr`, `ar` collections, ByteBrothers poach/winback logic from the other side, **Lynk** (Morgan, Garrison), **phone** texts,
**Outings** (dinner with a prospect at the table, replayability D5), **Expo** (a vendor-hall sales variant: reseller rebates, later).
New, all in `Computer`:

| New piece | Purpose | Verbs |
|---|---|---|
| **SalesHound CRM** (desktop app; parody name is a placeholder) | the pipeline: LEAD > MEETING > PROPOSAL > NEGOTIATE > WON > 90 DAYS | arrows to move, Enter opens a deal, C call, V visit, Q quote, F follow up |
| **Quote builder** (CRM screen) | price, services, SLA promised, contract term, hardware, discount | toggles with live gauges (below) |
| **Handover** (Cards sequence + conference room scene) | tell delivery what you promised | pick what to disclose; Garrison reacts |
| **Commission** (CRM tab) | quota attainment, earned, at risk (clawbacks) | read-only |
Pipeline in 368x128 (5 columns of ~72 px, cards 70x13: name, weekly fee, win %):
```
PIPELINE  QUOTE  COMMISSION  RENEWALS      QUOTA Q2 61%  MRR $8.4K  PIPE $21K        Wk 7   <- 9 px bar
LEAD (4)        |MEETING (3)    |PROPOSAL (2)   |NEGOTIATE (1)  |WON 90D (3)
>PIEDMONT PED   |LINDQVIST&MOSS |IRON MULE      |HOOT LAW +SEC  |ACME      OK  82
 $900/WK  20%   | $1.2K  35%    | $700   55%    | $1.6K  70%    |BRIGHTSIDE ! 61
 ZEN YOGA ...   |PAWS&CLAWS     |ROUND TREE DEN |               |RUSTY ANCH  !! 44
-----------------------------------------------------------------------------------------
DEAL: PIEDMONT PEDIATRICS  12 USERS  PAIN: HIPAA, XP  RIVAL: BYTEBROTHERS    C CALL  V VISIT  Q QUOTE
```
Quote builder gauges: **WIN CHANCE** (price vs their budget, rival, pain, rapport), **MARGIN** (Morgan's floor; below it needs approval), **PROMISE vs CAPACITY** (the SLA tier you offer versus what
the crew can really do this month; red = over-promise, bigger win chance now and a delivery gap later). Keys: Up/Down line, Left/Right value, Enter send, Esc back.

### 3.4 Metrics, win/fail, endings
- **Quota** (quarterly, MRR-based; tier-scaled): Q2 by week 12, Q3 stub by week 20. **Commission** from the chosen plan (`VIC_PLANS` salary / balanced / commission-heavy), with **clawback** if a client leaves inside 90 days.
- **Book quality**: average client mood of your signed clients, 90-day churn, references; "gap" = promised minus delivered (hidden per deal, shown after the first complaint, then in the CRM).
- **Pipeline health**: weighted value, win rate, average discount, days to close. **Morgan's trust** (0-100, `Campaign.rep`): **0 = fired**; also a **PIP** after two missed quarters in a row.
- **Endings (week 20)**: SALES DIRECTOR / EQUITY OFFER (quota met and churn low), **TAKE YOUR BOOK TO BYTEBROTHERS** (non-compete tension, clients follow only if the relationship is strong),
  THE ROLL-UP (the buyer wants your pipeline; earn-out tied to retention), STAY. Owner-campaign-style quality factor (mood/rep) multiplies any payout so a cash grab is not optimal.

### 3.5 Story beats (20 weeks; engines named)
| Wk | Beat | Engine | Decision |
|---|---|---|---|
| 1 | **Territory and comp plan** (Morgan hands you a quota) | `Cards` (`VIC_PLANS`) | salary vs commission-heavy (risk/reward) |
| 2 | **Chamber of commerce lunch**: new leads | `Outings` restaurant, `Cards` | how much you promise a stranger |
| 3 | **Discovery visit** at Paws and Claws (pet the dog, find a failing drive) | `Onsite` visit + `FINDINGS` | log a ticket vs sell it as a project |
| 4 | **XP deadline wave**: six prospects want desktops | `Projects.make_quote` + quote builder | price vs margin vs delivery weeks |
| 5 | **First signing** and the handover with Garrison | `Cards` handover + conference scene | disclose or gloss; Garrison's opinion |
| 6 | **ByteBrothers undercuts** your Lindqvist and Moss bid | `Cards` (poach logic reversed) | match price, sell value, walk |
| 7 | **The promise comes due**: a client you gave a 1-hour SLA hits a P1 | `Sales.deliver` flow reversed + `Cards` | own it, blame the techs, ask Garrison |
| 8 | **QBR at your best client**, upsell backup service | `Onsite` `qbr` + `Projects.SERVICES` | fee increase vs mood |
| 9 | **CryptoLocker hits Hoot and Holler**: they call you first | `Story` callback on the ransom flag | comfort, renew early, or distance |
| 10 | **Quarter crunch**: a deal slips; Morgan hints at an end-of-quarter discount | `Cards` | sandbag, pull in with a bad discount, or miss |
| 12 | **Q2 close and bonus**; first quota verdict | `DayReport` rows + `Cards` | accelerators, PIP warning if missed |
| 13 | **Renewals and price rise** with 60 days' notice | `Cards` (price-increase campaign, research #4) | who to raise, who to protect |
| 14 | **HIPAA omnibus fear** (effective Sept 2013): a medical prospect wants compliance | `Projects` (security) + `Cards` | sell a package you can deliver |
| 16 | **A client leaves for cause** because of your promise; clawback | `Owner.drop_client` style + `Cards` | repair, replace, resign yourself |
| 18 | **Rival offer**: ByteBrothers recruits you | `Cards` | counter, bluff, leave |
| 19 | **Roll-up due diligence** asks about contract terms and churn | `Story` mail + `Cards` | disclose gaps or shade them |
| 20 | **Review with Morgan** | `Review` | choose an ending |
Event deck candidates: a prospect asks for a "free" assessment, a referral from a happy client, a trade-show invitation, a demo that fails, a client's card is declined, vendor rebate offer, Heartbleed upsell window.

### 3.6 Cast behaviour and NPC AI
| Who | Role | Behaviour needed |
|---|---|---|
| Morgan | owner, approves discounts, sets quota | appears on Fridays/approval cards; his trust is the fail meter |
| Garrison | delivery manager (gatekeeper) | reacts to handovers: pushes back, walks to your desk (`send_to_player`) when onboarding slips |
| Alan, Dan, Maya | delivery | grumble in Talk/Lynk when promises are unrealistic ("you sold WHAT?"); their mood feeds first-90-days client mood |
| Marge | bookkeeper | commission statements, collections |
| Prospects/owners | per deal | b-skin site NPCs already exist (`CAST_AT`, `OWNER_B`); at your office they appear as visitors (`Expo.CROWD` role pattern, **new**: a client-visit scene in the conference room) |
| ByteBrothers rep | rival | new recoloured character (`make_fem.lua`-style pipeline) seen at prospect sites; a `rival_present` flag lowers win chance |
**NPC AI needed**: light. (1) Prospect objects with traits (size, vertical, budget, urgency, objection, incumbent, rapport) drawn from a seeded stream, not NPC nodes; (2) the **delivery autopilot**
(owner crew queue) must react to deal promises: SLA tiers change ticket priorities for that client and `Sales.satisfaction`; (3) NPC Vic and `Sales.visit_done` are switched off, replaced by
player actions; (4) Garrison/others use the existing `news` walk-to-player leg; (5) the 90-day churn clock runs weekly per signed client.

### 3.7 What is reused / what changes
Reused: `Sales` (clients, satisfaction, `sign_client`, `sell_install`), `Msp.CLIENTS` plus the 3 prospect sites, `Onsite` visits/meetings/findings/PETS/drive times, `Projects` quotes,
`Owner` pay plans/handover/QBR/collections/poach/winback/marketing leads (as background systems), `Growth` (`vic_penalty` becomes the owner's hours view), Outings dinner with a client.
Must change: `Owner` gates (P0b: crew+books run in the background, owner cards off, `DAYS` replaced); a `Deal` model and prospect table (12-15 parody businesses, only 3 have sites: add b-skin
reuse or a generic "office walk-in" scene); the pipeline weeks; quota/commission/clawback; a `Promise` struct on deals feeding service outcomes; new `Onsite.KINDS` (`discovery`, `renewal`, `checkin`) with
meeting cards in `Onsite.DEFAULT_MEETINGS`; the bell ring for the player.

### 3.8 Risks and open questions
- Cards-heavy loops can feel like a menu; the van, walk-arounds and phone interruptions must carry the fun. Keep every week to 3-5 decisions.
- Prospect variety: only 3 of 11 clients have a site; sustained play needs 8+ visitable prospects. Cheapest answer: **prospects can reuse the six site types with fresh names/skins (`SITES` already has a/b)**; art cost L if a new type is wanted.
- Balance: the owner campaign proved cash-grab strategies can beat careful ones on valuation; the quality multiplier (mood/rep) from `Owner.quality()` must apply to your payout too.
- The company is on autopilot in the background; its numbers must not contradict the owner campaign's economics (reuse, do not fork).

---------------------------------------------------------------------------------------------------------------------------------

## 4. How both plug into Difficulty, seeds, events and mutators
| Hook (replayability-ideas) | Service | Sales |
|---|---|---|
| `Difficulty.tier` / `level()` | ticket volume, SLA clocks (`sla_mult` 1.25/1.0/0.8), quit odds, budget cap | quota size, lead flow, rival aggression, discount tolerance |
| `Difficulty.rng(stream)` | `"dispatch"` (fit rolls, stuck), `"hire"`, `"events"` | `"pipeline"` (prospect draw, objections), `"deals"`, `"events"` |
| Event deck (`Events.DECK`, tags `service` / `sales`) | printer storm, a tech's family day, vendor delay | referral, failed demo, declined card, trade-show invite |
| Mutators | XP end of life, Heartbleed week (Garrison's security surge), flu season (two techs out), printer apocalypse | XP end of life (desktop quotes), tax season (accountants), slow payers (commission lag), hardware recall |
| Starting conditions | inherit a messy desk (patch debt, undocumented clients), the only senior left, a rival wants your best tech | an incumbent book of three weak clients, greenfield territory, the year after a lost whale |
| Daily seed / year 2 | same pipeline/queue per day; year 2 keeps skills and book | same |
| `Strings` | story tables as `DEFAULT_X` + `make_patchable` in `make_godot.py`; new roots `Service`, `Pipeline` | same |

---------------------------------------------------------------------------------------------------------------------------------

## 5. Shared modelling decisions
- **One crew model, two uses.** `Crew` (new autoload, extracted from `Owner`): roster, per-tech stats, `work(seconds)`; modes `autopilot` (anonymous, today's owner behaviour) and `assigned` (service).
- **Mode registry.** `Campaign.MODES = {tech, owner, service, sales}` with a per-mode config dict `{day_len, total, story_table, report, review, hud}` replacing the scattered `mode == "owner"` tests (about 20 sites: `campaign.gd`, `story.gd`, `owner.gd`, `msp.gd`, `lync.gd`, `review.gd`, `hud.gd`, `outings.gd`).
- **Reputation reused as the boss's trust** (`Campaign.rep`): no new fail meter plumbing; report, HUD and fired path already work.
- **Save**: new sections `service` / `pipeline` / `crew`, all with defaults (`from_dict` uses `data.get`). One save per mode (`mspsim_service.cfg`, `mspsim_sales.cfg`).

---------------------------------------------------------------------------------------------------------------------------------

## 6. Which existing data tables serve each campaign unchanged
| Table | Service | Sales |
|---|---|---|
| `Msp.CLIENTS`, `PROBLEMS`, `ALT_DEFS`, `INSTALL_ITEMS` | yes | yes (as delivery side) |
| `Playbook.BOOKS` (9 jobs) | yes, with assignment choices added | callbacks only (client reaction) |
| `Onsite.SITES/JOBS/EVENTS/FINDINGS/CAST_AT` | assign techs to jobs | yes, with `DEFAULT_MEETINGS` extended |
| `Projects.TYPES/SERVICES` | scheduling drag | yes (quotes) |
| `Owner.STACK/TRAITS/NAMES/VIC_PLANS/GOALS` | stack, candidates | pay plans, handover |
| `Story.VIGNETTES`, `Talk`, `Lync.MESSAGES` | re-voiced | re-voiced |
| `Review.QUOTES/EPILOGUES` | new endings | new endings |
New tables: `Service.DAYS/DESIGNS/RUNBOOKS/FOCUS`, `Crew.TIERS`, `Pipeline.PROSPECTS/OBJECTIONS/STAGES`, `Quote.OPTIONS`, `Talk.MANAGER/SALES`, `Events.DECK` rows.

---------------------------------------------------------------------------------------------------------------------------------

## 7. Phased delivery plan
| Phase | Scope | Effort | Playable result |
|---|---|---|---|
| **P0** | Player-as-cast-member (section 1): `Campaign.player_as`, `apply_roster`, `Social.people()`, `Outings.roster()`, charselect/title entries, seated start, save/continue. Garrison and Vic desks, intro text, two stub days each. | **M** | Start either campaign, sit at your desk, play 2 days of the old loop with the cast minus you |
| **P0b** | Split `Owner.active()` into `crew_active/books_active/cards_active`; per-mode config registry; HUD/report/review plumbing for the two modes | **M** | Team works the queue in the background in both modes |
| **S1** | **Sales slice**: 20-week skeleton (`Sales2.DAYS`), weekly report (MRR, quota, commission), leads as Cards, visits via the front door and `Onsite`, quote via an extended `Projects.make_quote`, player rings the bell | **M** | First playable Sales campaign (cards + van), no CRM yet |
| **S2** | SalesHound CRM app, deals with promises, quote builder gauges, handover scene, 90-day churn and clawback | **L** | The real Sales loop |
| **S3** | Story beats 1-20, rival, renewals/price rise, Morgan approvals, endings, `Review` offers | **M** | Full Sales run |
| **V1** | **Service slice**: Garrison seated in `office_two`, Huddle card, scorecard report (SLA, FRT, FCR, backlog), crew autopilot, hands-on tickets, 1:1 Talk deck | **M** | First playable Service campaign (no board) |
| **V2** | `Crew` model + **Dispatch board** + Capacity tab, NPC stuck/overload/quit acting | **L** | The real Service loop (prototype board before V3) |
| **V3** | Knowledge/runbooks, desk design cards, hiring with fit, onboarding playbook, retention events | **L** | Systems depth |
| **V4** | Story beats 1-20, endings (ops manager, roll-up), manager decks | **M** | Full Service run |
| **B0** | Point-buy build screen (section 11): tech build first (needs only `Skills`), then service/sales stats with their campaigns | **M** (+ **S** per path) | Third step on character select, saved build |
| **E** | Difficulty/seeds, event deck rows, 4 mutators and 3 starting conditions per mode, balance harnesses, strings sync | **M** each campaign | Replay value |
Rough total: Sales about 4 weeks after P0/P0b, Service about 5-6 weeks. Each slice is shippable and cut-safe.

## 8. Tests (repo style: `SceneTree` scripts in `godot/tests/`, `_check(ok, what)`, `user://test_` saves, run one at a time)
| Test | Covers |
|---|---|
| `playeras.gd` | `choices()` per mode; `new_game("service")` removes Garrison from `World.chars` and `Social.people()`; player seated at `office_two` Seat1; lunch/meeting/all-hands run without errors; save/continue keeps `player_as`; owner mode still drops Maya; Free Play still ghosts |
| `charselect.gd` (update), `campaign.gd` (update), `maya.gd`, `social.gd`, `community.gd`, `outings.gd`, `meeting.gd` (updates for rosters) | regressions |
| `crew.gd` | assignment progress, fit math, stuck state, quit removal, autopilot parity with the old `_work_queue` |
| `dispatch.gd` + `dispatch_shots.gd` | board key flow (assign, escalate, take it), wide/h/v screenshots (renderer needed) |
| `service.gd` | scorecard maths, confidence/fail, 20-day auto-run through `Review`, each ending |
| `crm.gd`, `quote.gd`, `handover.gd`, `sales_campaign.gd` (+ `_shots`) | stage moves, win odds, gauges, promise gap, commission and clawback, quota verdicts, 20-week auto-run |
| `service_balance.gd`, `sales_balance.gd` | dev tools in the `owner_balance.gd` style (strategies smart/cheap/greedy, ≥3 runs each); check the cash-grab does not win |
| `seeds.gd` (shared) | same seed, same pipeline/queue; different seeds differ |
| `strings.gd` (update) | new tables export/sync; `tests/story_export.gd --check` clean (period and parody-name warnings) |
Also `gdlint` / `gdformat --check`; `godot/gdlintrc` already allows 2500-line files.

## 9. Recommendation: build Sales (Vic) first, then Service (Garrison)
1. **Lower risk, higher reuse.** Sales is mostly Cards, Projects quotes and the Onsite van: systems that already work and are the game's most charming parts. Service needs a new
   core UI (the Dispatch board) and a new simulation (assigned crew) before there is anything to play.
2. **P0 and P0b are shared.** Sales proves player-as and the Owner gate split on the simpler campaign; the crew autopilot it needs is the exact base that V2 extends.
3. **Faster first slice.** S1 (M) after P0/P0b gives a playable campaign; Service's first slice has no board, so it is the weaker demo.
4. **Sales makes Service better.** The handover, over-promised Iron Mule onboarding (beat 11) and Vic's bad-fit prospect (beat 16) become real systems the manager campaign can consume.
5. Counter-argument: Service is the more distinctive pitch (the "operator" role). If the goal is a flagship, start V2's board as a throwaway prototype in parallel and decide on feel.

## 10. Open questions for the owner
1. Morgan: owner (as briefed) or a manager with a hidden owner? One-line string patch if owner.
2. Day lengths: Service 6 min/day and Sales 4 min/week; acceptable for 20 runs of 2 h and 80 min?
3. Sam and a second hire need a runtime NPC with a desk: accept a fixed list (Sam: main floor Seat1-free, desk 1) or random?
4. CRM / PSA tab parody names (SalesHound, ConnectWhy Dispatch, ConnectWhy Knowledge) are placeholders.
5. Do tech/owner campaigns also get the cast picker (same switch) or stay non-cast?
6. Does the Sales campaign need a new "office walk-in" scene for prospects without sites, or may prospects reuse the six site types with new names?

---------------------------------------------------------------------------------------------------------------------------------

## 11. Point-buy stats at character select

### 11.1 Stats: what exists, what is new
| Path | Existing stats a build can set | New per-path stats |
|---|---|---|
| Tech | `Skills`: POWERSHELL (`ps_level`, from the Academy), NETWORKING, SERVERS, SECURITY, CUSTOMER (key `people` in code), levels 0-5 from XP at 15/40/80/130/200 (`XP_AT`); `Shift.energy` start (80); `Social.rel` start values; `Growth.gaps()` is derived from levels | none: the five skills are the build |
| Service (Garrison) | the same five skills (Garrison biased to SECURITY); `Social` with the techs; burnout model | **DISPATCH** (fit accuracy, auto-assign quality), **PROCESS** (runbook and onboarding speed), **PEOPLE** (1:1 gains, retention), **ESCALATION JUDGEMENT** (spotting stuck tickets and wrong tiers), **CLIENT RELATIONS** (calming, SLA pace) |
| Sales (Vic) | `Sales.vic_skill` inputs (rep, mood, `Owner.vic_extra`), `Owner.VIC_PLANS` | **PITCH**, **DISCOVERY** (finds pain, findings odds), **NEGOTIATION** (price held), **RELATIONSHIPS** (renewals, referrals, 90-day mood), plus a **HONESTY** slider (the over-promise lever) |
| Owner | `START_CASH`, owner hours pool (`Growth`: 40 minus 12 admin), `burnout`, Vic's plan | **FINANCE**, **SALES**, **OPERATIONS**, **PEOPLE** (hours, hiring and QBR odds) |
Every stat is a 0-5 level read through one function, `Build.level(stat)`, so campaign code never reads raw points.

### 11.2 Point-buy model
- **Budget** 12 points at Normal; Easy 15, Hard 9 (from `Difficulty.tier`; the run seed never changes the budget, it only seeds preset flavour text). The seed ("RUN 4F2A9C") is shown on the screen and saved with the build: same seed + same build = identical run.
- **Cost curve (cumulative)**: L1 1, L2 2, L3 4, L4 7, L5 11. **Max 4 at creation** (5 is earned in play so the XP arc survives), min 0, at most one stat at 4.
- **Quirks**: up to 2 negatives give +2 points each (CAFFEINE DEPENDENT: energy starts 65; SLOW STARTER: +20% XP needed; OVER-PROMISER for sales: better odds, bigger promise gap); one positive costs 2. Never family or health as a penalty (replayability rule).
- **Presets** (one key, then tweak, or CUSTOM): GENERALIST (2/2/2/2/2), SCRIPTER (PowerShell 3, Servers 2, Customer 0-1), NETWORK NERD (Networking 3, Security 2), PEOPLE PERSON (Customer 3, one other 2).
  Re-themed per path: SERVICE = PROCESS WONK / COACH / FIREFIGHTER / DIPLOMAT; SALES = HUNTER / FARMER / CONSULTANT / SMOOTH TALKER.
- **Guards**: no stat above 4 and no all-4s (budget); five-skill total >= 4 (no empty build). **Day-3 safety**: the Adobe ticket and the day-4 install are passable at all-zero skills (easy fixes, `DAY_CAPS` 1/3/5), so a tutorial never needs a skill; a warning line shows CUSTOMER 0 plus SECURITY 0 together (the day 9 and 14 callbacks lean on them).

### 11.3 UI: a third step of `charselect.gd` (character -> phone -> build)
Reuses the `step` machine ("char" | "phone", add "build"), keyboard-first, 3x5 `PixelFont`, same panel/GOLD/DIM styling, footer `UP DOWN STAT  LEFT RIGHT LEVEL  P PRESET  ENTER GO`.
```
YOUR BUILD            POINTS LEFT 3        RUN 4F2A9C      <- wide 368x128, header in GOLD
POWERSHELL  ##---  L2     NETWORKING  #----  L1             <- 2 columns x 3 rows, 10 px per row, 4x4 pips
SERVERS     ###--  L3     SECURITY    -----  L0
CUSTOMER    #----  L1     QUIRK  CAFFEINE DEPENDENT (+2)
PRESET: SCRIPTER  > FIXES RUN FASTER. NOBODY LIKES YOU YET.   <- one effect line (wraps to 2)
```
`h` (320x180): same columns with a 3-line effect box. `v` (180x320): single column, 12 px rows, preset chips in a row of four (P cycles), 3-4 line effect text. Mouse: click a pip or a preset chip
(`_rects` gets `pip` and `preset` kinds). Summary line becomes "TECH - ADULT - IFONE 5 - SCRIPTER". Esc steps back; Continue skips the screen (the build comes from the save).

### 11.4 Where the build feeds the game
| Consumer | How |
|---|---|
| `Skills.reset()` / `from_dict` | starting XP = `XP_AT[level-1]` so the bar starts at 0% of the next level; PowerShell stat sets `ps_level` (Academy still teaches 4-5); `FIX_SECS`/`FAIL` perks apply at once |
| Level perks | backup watch (SECURITY 3), patch-panel hints (NETWORKING 2), open docs (CUSTOMER 2), `sla_pace` (CUSTOMER 3-5) are live on day 1 if bought, which is the price of the points |
| `Growth.gaps()` | the day-6 gap list names *your* weakest skill; specialists get a harder first plan |
| `Talk` / `Lync` / review | tone lines read the top stat; PEOPLE PERSON starts +10 with the team in `Social`; the review quotes the build |
| `Shift` | quirks set the start energy |
| Service board | DISPATCH clears fit % noise (low level shows +/-15% fuzz), PROCESS shortens runbooks, ESCALATION JUDGEMENT flags stuck tickets earlier |
| Sales quote builder | PITCH/DISCOVERY/NEGOTIATION move win odds and findings chance; RELATIONSHIPS the 90-day mood slope; HONESTY drives clawback risk |
| Owner | start cash and hours-pool offsets only; QBR maths untouched |

### 11.5 Saves
`campaign.build = {preset, stats, quirks, spent, tier, seed}`. `Build.from_dict({})` returns the **flat default build** (all skills 0, no quirks = today's behaviour), so old saves and every test that calls `Campaign.new_game` directly run unchanged.

### 11.6 Per path and Free Play
| Path | Points | Notes |
|---|---|---|
| Tech | 12 over the five skills | skills keep growing by XP in play |
| Service | 12 over five service stats | cast bias table `Build.BIAS["Garrison"]` (SECURITY floor 2) keeps him himself |
| Sales | 12 over four stats + HONESTY slider | Vic floor: PITCH 2 |
| Owner | 12 over four owner stats | optional, no build today |
| Free Play | **no build screen** (sandbox keeps today's levels; an optional MAX preset for filming) | |

### 11.7 Effort and tests
| Piece | Effort |
|---|---|
| `Build` data, costs, guards, saves | S |
| `charselect.gd` build step (3 formats, mouse, presets) | M |
| Wire into `Skills`, `Shift`, `Growth` (tech) | S |
| Service / Sales / Owner stat tables and readers | S each, inside their campaign phases |
Tests: `build.gd` (costs, budget per tier, guards reject bad builds, presets valid, default equals old behaviour, old-save default), `charselect.gd` update (third step in every mode but Free Play, summary line),
`build_playthrough.gd` (an all-zero build passes days 1-4 without the Academy; a level-4 custom build has its perks on day 1), `charselect_shots.gd` in wide/h/v, a tier x seed determinism case in `seeds.gd`.
Risks: a third step on already-tight narrow formats; perks live from day 1 need balance runs per preset (`owner_balance`-style); the `difficulty` branch must merge first, otherwise tier reads fall back to Normal.
