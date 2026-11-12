# MSPSim: game design document

<!-- gdd_ checklist: every item of docs/design/checklist.md is answered here; the index table is in section 13. -->

## 0. Document control

**Status: DECIDED (as a document). Contents carry their own marks.**

| | |
|---|---|
| Document | MSPSim game design document, the single source of truth for what the game IS |
| Version | 1.0 |
| Date | 2026-11-12 |
| Written against | the code on `main` after the content merges of 2026-11-12 (about 588 commits); numbers come from `docs/design/systems-reference.md` (generated from the code) or are counted in `docs/design/gap-audit.md` section 5 |
| Owner | Ben (the owner; every DECIDED mark below is his decision) |
| Method | Written to the checklist in `docs/design/checklist.md`, which was built from the original GTA design document ("Race'n'Chase", 1995), the Diablo pitch (1994) and a one-page concept template. What we took from them: rules as short testable statements, specific numbers, object lists with attributes, a win and a failure condition for every mode, open items kept in view, a mark for what is agreed. |

### Status legend

Each section has a status line under its title, and single items carry the same marks.

| Mark | Meaning |
|---|---|
| **DECIDED** | The owner decided it, or it is built, tested and not in dispute. Change it only by a new decision, and record the change in the revision history. |
| **PROPOSED** | A recommendation from the audit (`gap-audit.md` section 4) that the owner has not yet answered. Treat it as the working assumption, not as agreed. |
| **OPEN** | Not decided, or not verified. Each OPEN item is listed in section 12 with an owner. |

### How to read the rules

Section 11 holds numbered rules ("R-12: On Easy nobody is fired."). Each names the test that proves it, or says `untested`, or says `bot only` when only a balance run covers it. Every test named was opened and its assertion read on 2026-11-12. Test files live in `godot/tests/`.

### Companion documents

This document says what the game is. It links out for lists, so the lists cannot go stale here.

| Need | Read |
|---|---|
| Every table, count and number, generated from the code | `docs/design/systems-reference.md` (regenerate with `tests/make_systems_reference.gd`; `tools/check_systems_reference.py` lists drift) |
| The flavour: the cast, the 20-day tech story, the playbooks, the voice | `docs/GAME_BIBLE.md` (kept as the flavour companion; see its header note for the stale parts) |
| What was thin in our documents, and the audit's issue list | `docs/design/gap-audit.md` |
| The checklist this document answers | `docs/design/checklist.md` |
| Scope, project risks, the test plan, milestones | `docs/design/scope-risks-tests.md` (written separately; not duplicated here) |
| Player-facing instructions, spoiler free | `docs/manual/README.md` |
| Campaign design history and decided answers | `docs/campaign-paths.md` |
| Balance measurements and the bot tables | `docs/balance-notes.md` |
| Replay design: difficulty, seeds, mutators, Year 2 | `docs/replayability-ideas.md` |
| Handheld readiness and frame times | `docs/steam-deck.md` |
| Co-op design | `docs/scope-coop.md`, `docs/coop-risk-findings.md` |
| Roadmap rows and the decisions list | `docs/ROADMAP.md` |
| How the code was built, by area | `docs/dev/*.md` (`CLAUDE.md` is the index) |
| The editable story text | `godot/story/README.md`, `godot/story/strings.txt` |

### Revision history

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-11-12 | First full document. Pillars and non-goals recorded as decided; likenesses, audio, Switch and handheld decisions recorded; audit proposals D-2, D-3, D-4, D-6 to D-9 recorded as PROPOSED. |

---

## 1. Concept

**Status: DECIDED, except the title, the audience, the comparables and the defining-mechanism wording, which are PROPOSED.**

### 1.1 The game in two sentences (checklist 1)

MSPSim is a cartoon pixel-art office sim in which you work at a small IT support company in 2013-14: tickets to close, clients to keep, owners to please, and a building full of people and things you are allowed to poke. The same office is played four ways (tech, owner, service manager, sales), and a choice you make today comes back as a ticket, a card or a joke tomorrow.

Why it is fun, in one paragraph: the work is a small real puzzle with real consequences (the backup you did not check is the ransomware you cannot undo on day 9), the people are specific and funny, the pressure is comic and never cruel, and the office will let you do something silly at any moment (a nerf war, a pulled network cable, a game of darts in the warehouse).

### 1.2 Title (checklist 2) - PROPOSED

The working title is **MSPSim**; the cover box in the README says "MSP Simulator". "MSP" (managed service provider) is jargon the likely buyer does not know, and the name says nothing about pixels, offices or comedy. Recommendation (audit D-9): keep the working title, add a plain subtitle on any store page ("an office sim about IT support in 2013"), and run a name search before anything is printed. The tagline in the game is "The year is 2014. The coffee machine has opinions."

### 1.3 Genre (checklist 3) - PROPOSED

An **office management sim with a life-sim sandbox around it**: a ticket-queue job simulation, four careers on it, and a set of party mini-games. The management-sim niche is crowded with big-budget tycoons, but small, joke-led, period-specific desk-job games are few; the freshness is the setting and the way four jobs share one world, not a new genre. The audit asks that this be argued with players; nobody outside the project has done so yet (OPEN, section 12).

### 1.4 Audience and rating (checklist 4) - PROPOSED (audit D-2)

- **Audience:** people who work in or near IT (the jokes are correct), and fans of cozy management games and Overcooked-style party games. Teens and up are welcome; the game has no adult theme.
- **Rating target:** an everyday E10+ / PEGI 7 level. Content that a rating questionnaire will ask about: cartoon dart and paintball play and a foam nerf war (the only "violence"), workplace banter, mild jargon-heavy language. There is no gambling, no drugs, no blood, and the real-world harms in the story (CryptoLocker, wire fraud) are played as business problems.
- **What the rating constrains:** no punishment of players for family or health, no real brands (see non-goals), no sexual content, no slurs in cast text. `tests/canon_text.gd` already scans every string literal for era words and real vendor names.
- **Today:** no rating exists. The README cover shows a joke box "RATED E FOR EVERYONE"; it reads like a claim and should be marked as the parody it is or removed (audit D-2).

### 1.5 Comparables and the gap (checklist 5) - PROPOSED

These comparisons are ours, drawn from what each game is known for, not from market research (OPEN: a real comparison with sales data and reviews).

| Game | What it shares with us | What is different here |
|---|---|---|
| Papers, Please | A desk job made of small rule-bound decisions with consequences | We are warm and funny, a failure is explained, and Easy never fires you |
| Overcooked | Time pressure, short rounds, couch co-op, party chaos | Our chaos is an office day plus an evening out, not a kitchen; co-op is optional and shares one office |
| Software Inc. and Two Point Hospital | Running a small organisation with systems and jokes | The owner mode is one of four; we also let you be the tech, the service manager and the salesperson |
| Job Simulator | A parody of a desk job you can poke | Ours has a real, readable ticket system underneath and a 20-day arc |
| Big Ambitions | A career-and-business ladder | Our ladder is four careers in one fixed company, with endings, not an open economy |

**The gap we fill:** a period-specific (2013-14), joke-led IT-support job sim that is accurate enough for the people who did the job and kind enough for people who did not.

### 1.6 The defining mechanism (checklist 6) - PROPOSED

**One office, four jobs, the same events seen from different chairs, and every decision comes back.** The ransomware of day 9 is the owner's week 9 card, the service manager's Heartbleed wave and the salesperson's angry client. The backup you ignore on day 5 is the thing you wish you had checked on day 9. This is what carries replay (play another chair, another tier, another seed) and what carries expansion (Year 2 and Year 3 reuse the same office with tighter clocks and new beats).

### 1.7 Familiar elements (checklist 7)

What a player already knows, which lowers the risk of a new genre:

- a **ticket queue** with priorities and clocks (SLA), a fix menu and a close button;
- a **quota** and a pipeline (sales), a **P&L** and a valuation (owner), **trust meters** (service);
- a **grade** at the end of the day (S to D) and a **review** at the end of the year;
- **cards**: a short text, two or three answers, a consequence;
- **party game nights** (bowling, karaoke, cornhole, darts) that every player already understands;
- **medals** and a career page.

### 1.8 Role, point of view, fantasy and emotions (checklist 8)

- **Role and fantasy:** you are the person who keeps other people's computers alive. Tech: the new hire who earns trust. Owner: the person who has to make payroll. Service manager (Dan): the person who decides who fixes what. Sales (John): the one with the bell and the quota, whose promises the team has to keep.
- **Point of view:** a side-on 2D view of one room at a time, with a follow camera in the wider formats (section 7.2). Seen from outside, not first person.
- **Emotions wanted** (from the Bible): pressure that is funny, not punishing; growth you can feel (fixes get faster, options unlock, coworkers trust you); consequences that arrive on day 9 for what you did on day 5; a workplace with people in it who react.

### 1.9 Pillars and non-goals (checklist 9) - DECIDED (owner, 2026-11-12)

Use the pillars to settle arguments: when two good ideas conflict, the one that serves more pillars wins.

1. **The office is the toy.** Every system should be poked, not just used. If a thing in the building cannot be poked, it is set dressing and needs a reason to be there.
2. **Decisions come back.** A choice today is a ticket, a card or a joke tomorrow. A system that has no memory does not belong.
3. **Funny, not punishing.** Pressure is comic. Easy never punishes. A failure is explained and the player can always see what they could have done.
4. **2013-14, exactly.** The period and the parody names are the style. No anachronism, no real brands.
5. **Playable on a pad, in short sittings.** Every screen works with a controller and every day is a stopping point.

**Non-goals** (what the game is NOT):

- no online play, no leaderboards, no telemetry;
- no real brands, no real songs (every product and song is a parody; `tests/canon_text.gd`);
- nothing from after 2014: no AI, no Slack or Teams, no Windows 10 or 11, no "MFA" (we say two-factor login);
- no combat game: the nerf war and paintball are party games with no health, no death and no campaign consequence;
- no Switch port (dropped 2026-11-10; the pad work stands for PC and handhelds);
- no free-to-play, no ads, no microtransactions (PROPOSED, audit D-3).

**Open items, section 1.** Real comparables and a genre argument (Ben, audit D2/D13 "store page"); rating questionnaire (Ben, audit D-2); name search (Ben, audit D-9).

---

## 2. The first minute, the first ten minutes and a worked day

**Status: DECIDED (describes the code as built). The gaps named at the end are OPEN.**

### 2.1 The first 60 seconds (checklist 14)

For a new tech campaign on Normal, from the code (`Campaign.new_game`, `Hints.DEFAULT_DAY1`, `Msp._spawn_t`):

1. **Title.** Press Enter; the home menu opens (CONTINUE only if a save exists, NEW, FREE PLAY, QUICK PLAY, SETTINGS, QUIT). NEW, then TECH CAMPAIGN. (With saves, a submenu offers the slots first.)
2. **Setup, five pages** (`CharSelect.flow`): the character creator (LOOK, CLOTHES, SHOES, EXTRAS, WORK; the name is a letter grid), the phone (iFone 5 or Nexxus 5), the tier ("HOW HARD?" with a one-line mood note), the run options (level, starting condition, seed, tools, mutators) and the point-buy build. This is long; a calmer select is on the roadmap (R35 built the creator-first order; the audit lists the rest as OPEN).
3. **Day 1 starts at 9:00 on the main floor.** The clock runs; one game minute is 1.25 real seconds on a 10-minute day.
4. **Real seconds from the start:** 4 s, hint "ARROWS OR A/D MOVE, HOLD SHIFT TO RUN, SPACE JUMPS" (one hint every 22 s after that: E uses things, sit at a desk and open the computer, the phone, tickets). 7.5 s, Morgan's mail "Your first day". 15 s, Dan's mentor card, then a first-day "hello" card with three answers; the pick sets a flag and a text arrives the next morning. 75 s, the first ticket arrives (20 s on Easy).
5. The **goal chip** reads "OPEN THE COMPUTER AT YOUR DESK" until a ticket exists, then "CLOSE YOUR FIRST TICKET".

### 2.2 The first ten minutes

Day 1 has exactly one random ticket (R-17). The ten minutes are: learn the keys, walk to your desk, open the Computer, find the machine in the RMM, pick a fix, close the ticket in the PSA, read the day report with its grade. That is one whole loop at the smallest size, and the day report is the first stopping point.

### 2.3 A worked day, turn by turn (checklist 15): tech, day 9, Normal

This is the story day where the choices of day 5 pay off. It is a description of what the code does, not a recording of a human play.

| Clock | What the screen shows | What the player picks | What follows |
|---|---|---|---|
| 9:00 | The main floor. The goal chip says "FINISH THE JOB: ..." only once a job is open. Morgan's mail lists the day. | Walk to the desk, open the Computer. | The queue (up to 11 tickets can arrive today, 6 open at once). |
| 9:40 | A P3 spooler ticket, SLA 300 s (before the tier scale). | Ask the user to save first, then restart the spooler (the proper fix), or reboot the PC (quicker, interrupts the user). | Proper: ticket fixed, mood up. Reboot without asking: the user loses work, an angry email returns next morning. |
| 10:30 | The CryptoLocker playbook opens at the law firm (the job planted on day 5). | Restore from the backup if it exists, or shop for options (shadow copies, pay, pray). | A backup you verified makes you a hero (a short job, a few points); none means a long, expensive path and reputation lost. |
| 12:00 | Lunch. On a lunch day (tech days 3, 7, 12, 17) the cast can invite you out; day 9 has none. | Eat at your desk or walk to the kitchenette and talk to people. | Opinions move; friends cover for you and warn you before an SLA breaks. |
| 15:00 | An onsite ticket: a dead switch at a client. | Drive out (the front door menu shows drive times that follow the clock) and fix it at the client's own computer. | A mishap can happen (the vet's dog). |
| 17:00 | The day report: tickets closed, SLAs missed, reopened, client mood, pay, reputation change, a grade. Cards are paused while it is open. | Continue. | Reputation changes by at most +4 (R-23), the save is written (R-33), day 10 starts at 9:00. |

### 2.4 What a new player is not told (OPEN)

No screen tells a new player what winning is, and nothing explains the REP number on the HUD (gap audit I-1, I-4). A "how to win" page per campaign is proposed (audit D2) and its content is the table in section 3. Until it exists the manual says only that it "does not tell you what happens".

**Open items, section 2.** How-to-win page per campaign (Ben; audit D2); simplify the five setup pages (R35 follow-up); a first-session human playtest (Ben; audit D12).

---

## 3. Modes and structure

**Status: DECIDED (as built). Item-level corrections are noted.**

### 3.1 How the game is divided (checklist 10)

Four **campaigns**, each 20 days or weeks long, played as one named person and saved in 3 slots; **Free Play / Film Mode** (an open sandbox, no saves, no scoring); **Quick Play** (two micro modes: one outing, or one ticket shift of five tickets against your best time); **Career** (medals and lifetime counters across every run); **Year 2 and Year 3** (a harder pass of any finished campaign, no Year 4); and optional **two-player local co-op**.

**Unlocks.** Everything is open from the first start; nothing is locked behind a medal except cosmetics (wallpapers, ringtones, clothes; 41 unlocks, `systems-reference.md` 6.2). Year 2 opens for a campaign once a run of it has finished (`Yeartwo.available`); Year 3 opens after a finished Year 2 run. The manual says Year 2 needs a Tech or Owner run; the code allows all four modes (`Campaign.MODE_DEFS[*].year2 = true`), and the manual is stale on this point.

### 3.2 The mode table (checklist 11, 12)

"Fail" means the run ends with no review. "Success" means the run reaches the review alive; a good ending also needs the thresholds shown. Numbers: `systems-reference.md` 1.1 to 1.6 and `gap-audit.md` I-1.

| Mode | You are | Objective | Win (the review's best offers) | Fail (Normal / Hard) | What follows a fail | Length at DAY LENGTH short / normal / long | Year 1 endings |
|---|---|---|---|---|---|---|---|
| **Tech** | A service desk tech | Close tickets, keep clients and coworkers, survive the big jobs | Reach day 20; team lead needs reputation 55 (after the Growth plan) or 60 and a non-negative coworker average; in-house IT at your best client needs 45 | Reputation 0: "REPUTATION GONE. YOU ARE FIRED." | The slot file is deleted, back to the title; counters and medals stay; nothing unlocks (R-78, R-79; see I-2) | 100 / 200 / 300 min | lead, internal, stay (stay is "on notice" below 45) |
| **Owner** (Alan or Garrison) | One of the two owners | Run the company 20 weeks, make payroll, grow, face the rival | Board review with a valuation; expand needs cash 10,000, reputation 55 and 6 clients | Cash below -$3,000 (`Owner.BANKRUPT`) or reputation 0: "YOUR NAME IS MUD. THE COMPANY CLOSES." | As tech | 40 / 80 / 120 min | sell, expand, stay; partner endings (left, buyout, sellout) |
| **Service manager** (Dan) | The person who runs the desk | Keep the crew, the board and both owners' trust in balance | Ops needs both owners' trust 55+ and reputation 60; Alan's or Garrison's offer needs that owner's trust 55+ and reputation 60 | Reputation 0 or both owners' trust under 20 (`Service.FAIL_TRUST`; not on Easy) | As tech | 60 / 120 / 180 min | ops, alan, garrison, leave, stay |
| **Sales** (John) | The account manager | Hit the quarterly quota, deliver what you promised, keep Garrison's trust | The director offer needs the second quarter hit, the first quarter hit (or 90 percent of the total target) and a client mood of 60 or more, and a clean conscience | Reputation 0 or bankruptcy; two missed quarters leave only "CLEAN OUT YOUR DESK" (not on Easy) | As tech | 40 / 80 / 120 min | director, stay, rollup, leave, let_go |
| **Free Play** | Anyone | None | None | None | Nothing | Open | None |
| **Year 2** (any mode) | Your carried-over run | The same with SLA clocks at 0.85, extra clients, one tier more mutators, the calendar shuffled by up to two days | Year 2 endings (tech: head, clientbuy; owner: merger, franchise) | As the mode | As tech | As the mode | 4 Year 2 endings |
| **Year 3** | The same again | Clocks at 0.76, three cards ask how your story ends | Three Year 3 endings per mode (12), each with a medal | As the mode | As tech | As the mode | 12 Year 3 endings |
| **Co-op** | You and a second person | Same as the mode | Same | Same (shared reputation) | Same | As the mode | Same |

Real-time length is clock time only: DAY LENGTH is x0.5 / x1.0 / x1.5 on the mode's day (tech 600 s, owner 240, service 360, sales 240 at normal). Add the day report, cards (the clock stops while a card is open), outings and the conference trip, and a Normal tech run is realistically 4 to 5 hours in 20 stopping points (gap audit I-5; the 4 to 5 hours is an estimate, OPEN until a human plays it).

### 3.3 The endings logic (checklist 11)

- **Year 1** ends with a review in the mode's own style (the tech yearly review, the owner board review, the service review, the sales review). The review lists offers; some are always there (stay), some need thresholds read from the code (`systems-reference.md` 1.5 lists every gate).
- **Year 2** adds beats on given days or weeks and its own endings; **Year 3** asks three cards how the story should end, and what you answer decides which extra choices the final review offers. Each Year 3 ending has a medal.
- The four endings are not a branching story. They are four faces of the same fact: the reputation and the relationships you built.

### 3.4 Fail states are explained, but not yet visible in play (checklist 12) - OPEN

The player sees a one-line mood note under the tier picker and the goal chip; the thresholds above are in no in-game screen. Failure itself is explained by a final report. Two issues are known and recorded:

- **I-2:** "fired" deletes the slot and gives nothing back; there is no retry from the last day. Proposed (audit D4): keep the last day's save as RETRY FROM DAY n on Normal.
- **I-3 (fixed 2026-11-12):** on Easy the sales campaign used to end at "CLEAN OUT YOUR DESK" after two missed quarters. `SalesCampaign.year_saves` now returns true under `Difficulty.cozy_on()`, and `tests/cozy.gd` proves the Easy and Normal cases (R-6, R-7).

**Open items, section 3.** How-to-win screen (audit D2); fired-run retry or explanation (audit D4); a table of unlock rules for Year 2 in the manual (audit D5).

---

## 4. Core loops at three scales

**Status: DECIDED (as built).**

### 4.1 Tech (checklist 13)

| Scale | Loop |
|---|---|
| **A minute** | A ticket arrives (mail, call or alert). Open the RMM, connect to the machine, read the symptom, pick a fix (reboot is quick and risky; the proper fix is slow and safe; skills unlock clever fixes). Close it in the PSA. A wrong close reopens it with an angry mail. |
| **A day** | 9:00 to 17:00. Queue, a coworker to talk to, perhaps a big job (a playbook) or an onsite visit, lunch, a phone call. The day report scores it (S to D); reputation moves by at most 4 (R-23). Consequences of today's choices return as tomorrow's tickets. |
| **The run** | 20 days. The story seeds things early (the backup habit on day 2, a broken backup on day 5) and pays them later (ransomware day 9). The review on day 20 picks your future. |

### 4.2 Owner

| Scale | Loop |
|---|---|
| **A minute** | Open the Boardroom, read a card (a hire, a price, a late payer, a client request), pick an answer; each has a cost and a consequence. |
| **A week** | 240 s of play: cards, the books (EBITDA, the W-2 ratio, cash), client hours and scope, the rival's pressure; a weekly report. A weekly draw is taken from the bank. |
| **The run** | 20 weeks to a board review and a valuation: sell, expand or stay independent. The same incidents as tech (ransomware, the rack, the email night) arrive as decisions. |

### 4.3 Service manager

| Scale | Loop |
|---|---|
| **A minute** | Sort the dispatch board: assign a ticket to Maya, Sam, Terry or yourself, escalate, update a runbook. |
| **A day** | 360 s: the board fills, the crew's capacity and morale move, Alan and Garrison ask for opposite things (siding with one moves both trust meters in opposite directions, R-70). |
| **The run** | 20 days of a story arc (a Heartbleed wave, resets, a promotion) to a review where the trust of the two owners decides the offers. |

### 4.4 Sales

| Scale | Loop |
|---|---|
| **A minute** | Work a lead: discovery call, ASSESS, the quote builder (RIVAL PRICE and PRESENTED AS), a close. |
| **A week** | 8 selling hours a week (R-72). Leads, quotes, deals, handovers. Shortcuts win deals that churn faster and show as LIES in the week 20 verdict. |
| **The run** | Two quarters of quota, rival beats in weeks 2, 3, 5, 7, 9, 11, 13, 15 and 17, then the review. |

### 4.5 Free Play and the party layer

A minute: wander, sit, swap outfits, pick up a dart. A session: any outing or the toolbox (any mini-game with chosen settings, seeds and mutators). There is no run scale; Free Play is the sandbox.

**Open items, section 4.** The owner, service and sales loops live in design notes from before they were built (`campaign-paths.md`); a refresh pass (audit D6) is OPEN.

---

## 5. Progression, rewards, difficulty and replay

**Status: DECIDED (as built); the content-volume figures are generated counts.**

### 5.1 Goals, grades and reputation (checklist 16)

- **Short-term goal:** the goal chip (one sentence, from `Goals.goal()`) and the next-up list ("12:00 LUNCH", "17:00 CLOSING TIME").
- **Day report (tech):** the reputation change is 2 per ticket closed, minus 3 per missed SLA, 2 per reopen and 1 per ticket left open, plus coworker, sales and tiredness effects, clamped to -10 and the daily cap. Pay is $100 plus $20 per ticket closed, minus $25 per miss and $10 per reopen, plus overtime. The grade comes from the day's ticket score (`Msp.score`, the points the fixes earned): S needs 20 points, no misses, none left open and 4 or more closed; A needs 20 points and no misses; B needs 10; C 0 or more; D below. (The S rule is code-read; `campaign.gd` tests an A, R-26.)
- **Reputation (0 to 100, starts at 50):** the one number that decides fired or kept. The tech curve shapes it so a careful run reaches the high 90s only in the last days: the day report adds at most 4 (3 from 50, 2 from 58, 1 from 72; R-23); a scar lowers the ceiling to 85 until A or S days win it back (R-24); from 90 every gain is a fraction (R-25); from 58 a day with too many loose ends adds nothing, from 62 it costs reputation (`Campaign.CLEAN_REP` 58, `SLOPPY_REP` 62).
- **Enough to progress:** there is no gate on advancing a day; reputation above 0 is enough. Reputation 45 / 55 / 60 gate the better review offers (section 3.2).

### 5.2 Career, medals, unlocks (checklist 16)

Medals and counters persist across every run in one profile (`Career`). There are 72 medals (`systems-reference.md` 6.1) and 41 unlocks (6.2): wallpapers, ringtones, clothes and accessories for the creator. The 72 medals could map to platform achievements (audit D15, OPEN).

### 5.3 Shop, decor, mastery

- **Desk shop:** 12 items, $20 to $180 (a clicky keyboard is $90 and 5 percent faster but loud; a riser cuts energy drain 10 percent; R-56). Tech campaign only; Free Play owns everything.
- **Office decor** appears when a score reaches a threshold: a tall plant at reputation 55, a rug at cash 400, a certificate at 65, a trophy shelf at 3 medals, a fish tank at 75, a neon sign at cash 1,500, more trophies at 8 medals (R-58).
- **Mastery ramp:** each mini-game tightens its skill checks with every good play (2 or more stars), up to 10 plays; the first play is always exactly the chosen level and the sweet spots move so a rhythm cannot be memorised (R-40).
- **Point-buy build:** 5 stats per campaign (level 0 to 5; cumulative cost 0, 1, 2, 4, 7, 11) with 18 ready-made presets; points 15 / 12 / 9 by tier, +2 in Year 2 (R-38).

### 5.4 Difficulty: tiers and exactly what they change (checklist 17)

Three tiers: **EASY** (the cozy tier), **NORMAL**, **HARD**. `Difficulty.TABLE` has 68 keys in 17 families, each `[easy, normal, hard]`; the full list is `systems-reference.md` 1.8. The table below is the summary of the parts that change the **campaign**; the mini-game dials (bowling aim speed, escape-room time, and so on) are in the reference.

| What | Easy | Normal | Hard |
|---|---|---|---|
| Tech reputation gain / loss | x1.25 / x0.75 | x1 / x1 | x0.4 / x2.2 |
| Tech SLA window / ticket pace | x1.3 / x1.25 | x1 / x1 | x0.4 / x0.45 |
| Tech energy drain | x0.9 (and COZY x0.5) | x1 | x2 |
| Owner gain / loss / cost | x1.2 / x0.75 / x0.95 | x1 | x0.5 / x1.8 / x1.03 |
| Service trust swing | x0.7 | x1 | x1.6 |
| Sales quota / rival bid | x0.8 / x0.8 | x1 / x1 | x1.2 / x1.2 |
| Mutators dealt in Year 2 | 0 to 1 | 2 to 3 | 4 to 5 |
| Fired / bankrupt | Never (R-5, R-8) | Yes | Yes |
| First ticket arrives (`Difficulty.COZY first_ticket`) | 20 s | 75 s | 75 s (default; not separately checked) |

**Cozy Easy** is the tier where nobody is fired. Exactly what it changes (`Difficulty.COZY`, 10 keys): reputation floors at 15; bankruptcy becomes one $2,000 bailout and a second shortfall has no consequence; SLA windows are x1.6 on top of the tier scale (so Easy is 1.3 x 1.6 of Normal); an SLA miss costs client mood 2 instead of 8 and a reopen 1 instead of 6; the day report has no SLA MISSED or REOPENED rows and nothing is red; open tickets are "carried over"; no pay is lost to a miss; fatigue costs no speed or accuracy; staying late costs no energy; the commute is safe; ignoring the pager is free; nobody quits; the rival's poaching risk is halved; lost ransom files cost about 5 reputation and no scar; the sales and service fail rules do not apply. The tech yearly review below 45 reads "ON NOTICE: PROVE YOURSELF NEXT YEAR", the only soft penalty text left on Easy (I-3). Rules R-5 to R-15 prove all of this.

**How the curve is tuned:** by balance bots, not by human play. Bots play every mode, tier and style (careful, lazy, chaotic) over several seeds and the results are in `docs/balance-notes.md`: normal careful reaches a good ending in 11 of 12 seeds, normal lazy ends mid or bad everywhere, chaotic fails everywhere except an owner greed run. The caveat that matters: the careful tech bot is slower per ticket than a good human, so a human should land at or above the bot's result on Hard. No human has played days 6 to 20 of the tech campaign (gap audit I-13). That is OPEN and is why D-6 recommends a human playtest.

**Invisible difficulty (I-14):** the picker shows one mood line per tier, not what it changes. The table above is the content for a clearer picker (audit D2).

### 5.5 Replay hook and content volume (checklist 18)

Replay comes from: four chairs, three tiers, three years, a six-hex-digit **seed** (and a daily seed), **14 mutators** (a bad week: Heartbleed week, XP end of life, flu season, printer apocalypse, price war ...), **5 starting conditions** (standard, messy MSP, only tech, a rival wants your client, family business), the point-buy build, the character creator and variety inside each mini-game (karaoke songs, escape-room recipes, printer models, chair-race courses).

Content volume (generated; see the reference for the lists):

| Content | Count | Where |
|---|---|---|
| Campaigns / years / tiers | 4 / 3 / 3 | `systems-reference.md` 1 |
| Cast with a desk / clients / people with sprites | 13 / 11 / 75 | 2.1, 2.3, 2.8 |
| Ticket problem types / fixes / onsite jobs / printer models | 6 / 13 / 11 / 7 | 3.1, 3.3, 3.10, 3.12 |
| Playbook jobs (steps, choices) | 8 (5 to 6 steps, 105 choices in all) | 3.11 |
| Cards and beats (decks counted) | 549 | 4.1 |
| Mini-games / outing games | 11 / 9 | 5.1 |
| Karaoke songs / escape themes / chair events | 4 / 4 / 3 | 5.4, 5.5, 5.10 |
| Medals / unlocks | 72 / 41 | 6.1, 6.2 |
| Scenes (rooms, 40 of them client-site rooms) | 68 | 7.1 |
| Patchable text | 136 sections, 6,666 keys, 146,629 words | `godot/story/strings.txt` |

**Hours:** a Normal tech run is 4 to 5 hours (estimate, see 3.2). All four campaigns once each at Normal is about 9 to 11 hours of clock time, before Year 2 and Year 3 (which reuse the same day lengths). OPEN until a human plays it.

### 5.6 Session length and stopping points (checklist 19)

A day is 5, 10 or 15 minutes (tech; 2 to 9 minutes for the other modes). The save is written at every day end (R-33) and a mid-day resume point is written on pause (R-34), so a player can stop at any moment and the natural stop is the day report.

### 5.7 Seeds (checklist 27: see also 6.9)

A seed is six hex characters (`Difficulty.SEED_MASK`); a typed word is hashed; 0 becomes 1 (R-27). The seed drives 65 named random streams (R-28) whose positions are saved (R-29).

**Open items, section 5.** Human hours and difficulty feel (Ben, audit D12); achievements mapping (audit D15); a clearer tier picker (audit D2).

---

## 6. Systems

**Status: DECIDED (as built). Classification below is ours; counts are generated.**

### 6.0 The systems map (checklist 20)

| System | Internal simulation | The player touches it |
|---|---|---|
| Tickets, SLA, RMM, PSA (`Msp`) | Spawning, clocks, breach, reopen, fix chance | The Computer: service board, RMM, mail |
| Playbooks, onsite (`Playbook`, `Onsite`) | Step state, follow-on tickets | Choices in a job; the drive and the visit |
| Reputation and grades (`Campaign`) | The curve, scars, the cap | HUD number, day report |
| Skills, build, growth (`Skills`, `Build`, `Growth`) | XP, levels, perks | Academy, build screen, growth plan |
| Cast, opinions, NPC schedule (`World`, `Social`, `Npc`) | Who is where, what they think | Talk, instant messages, favours |
| Cards (`Cards`, `Events`, `Story`) | The decks and their gating | Pick an answer |
| Owner books, sales pipeline, service crew (`Owner`, `SalesCampaign`, `Service`, `Crew`) | Money, deals, trust, morale | Boardroom, CRM, Dispatch board |
| Rival and habits (`Rival`, `Habits`, `Temptation`, `Takeover`) | A rap sheet that only goes up; the Standard score | Rivals tab, Habits tab, four-option decisions |
| Outings and mini-games (`Outings`, `Toolbox`, `Nerf`) | Opponent skill, scoring | Play them |
| Difficulty, mastery, mutators, seeds (`Difficulty`, `Mutators`) | The dials | The tier, level, seed and MUT chips |
| Career, shop, decor | Counters and unlocks | Career screen, shop, the office |
| Co-op (`Players`) | Slots, shared state | A second pad |
| Story text (`Strings`) | Patchable tables | Reading |

### 6.1 Tickets, RMM and fixes (checklist 21, 25, 26)

Six base problem types (printer, lockout, slow, blue screen, pop-ups, server down), 13 fix ids, alternative "quick" fixes that cost later, and a fix time and fail chance that depend on skill level (`systems-reference.md` 3.1 to 3.5). Base SLA seconds by priority: **P1 120, P2 200, P3 300, P4 480**, then scaled by year (Year 2 x0.85, Year 3 x0.76; R-21), tier and mutators. Tickets per day and the cap on the open queue are in the reference (3.8). Note: the generated table lists the open cap as 5 from day 10 on; the code default is 6 and the test asserts 6 (R-18), so the reference is one off there (reported to the coordinator). The TICKET PACE option multiplies day cap, gap and open cap (RELAXED x0.75, BUSY x1.25).

**Consequence and recovery, and how each is shown:** a missed SLA costs reputation points and client mood, a reopen costs more, an ignored P1 leaves a scar (a lower reputation ceiling) that a good day starts to heal, ransomware without a backup costs 15 reputation and a scar on Normal; the day report shows every count; a toast and a text appear when the thing happens. Recovery: clean days and A or S grades.

### 6.2 Playbooks (checklist 21)

Eight multi-step jobs (rack recovery, server migration, 24x7 email outage, remote access break-in, wire request from the boss, the client who said no, the only person who knows, network install) with 3 to 6 steps and 9 to 16 choices each; the Windows XP replacement, ransomware and the post-incident reviews are scripted chains in the story deck (the Bible has the day-by-day list). A choice can cost seconds, game hours or be locked behind a skill. Good choices score; sloppy ones leave follow-on tickets and emails next morning.

### 6.3 Onsite visits, phones and cards

- **Onsite:** 11 job types; some tickets cannot be fixed remotely; you drive (the front door menu shows drive times that follow the clock), walk the client site (6 types, each in two looks) and use their computer. Printers are a small game (7 models).
- **Phone:** iFone 5 or Nexxus 5 (a build choice): mail, tickets, texts, a PHONE app (calls to clients and coworkers, text only, a cooldown per contact) and a lock screen. A banner and a buzz announce messages.
- **Cards** (549 across decks): a speaker, a text, two or three answers; some set flags that change later odds. The clock stops while a card is open.

### 6.4 The cast and NPC behaviour (checklist 21, 22)

13 people with desks (6 core: Alan, Garrison, Dan, John, Maya, Morgan; 2 crew: Sam, Terry; 5 staff: Jen, Michael, Christy, Adam, Quinn), 11 clients and many more people at client sites, the expo and the forum (75 sprited people, `systems-reference.md` 2). They have a daily schedule, a home scene and seat, an opinion of you (-100 to 100: FRIEND at 60, FRIENDLY at 25, NEUTRAL above -15, COLD above -45, HOSTILE below), and a voice.

How they behave and escalate: coworkers react to your actions (answering their phones, breaking their network, being friendly) and friends cover for you, give tips and warn you before an SLA breaks (Maya, specifically). **Owners jump in as a last resort in the tech campaign, and stepping in costs no reputation** (a ROADMAP decision). Turning off the router sends Dan to the closet; turning off the lights makes someone turn them back on. Clients escalate by priority and clock: a breach drops mood, a repeat drops trust, a bad run lets the rival poach.

### 6.5 The owner money model (checklist 23)

Start cash $7,500 (`Owner.START_CASH`). Income: a weekly fee per client ($800 at standard pricing), projects (7 types, $900 to $8,500; 12 to 44 hours), deal extras (managed backup $110 a month, patching $80, security $95), the hosted email filter ($45 a week each). Outgoings: a tech's weekly wage $650 (60 percent for a new hire's first 3 weeks), rent $500, a seat cost of $55 a week for each client past five, tool costs from the stack you choose, marketing, advice. A weekly draw is taken from the bank. **Sinks and limits:** bankruptcy at -$3,000; at most eight clients are signed at once (`Sales.MAX_CLIENTS`, 10 in Year 2); the W-2 ratio (payroll against revenue, target 0.55) and the peer margin (0.15) are the health checks; the valuation never counts a bailout (R-10). A mutator can scale income, never outgoings (R-43).

### 6.6 Sales pipeline and quotas

Garrison sets the quota at the start (three choices: SAFE $6,500, STANDARD $9,000, STRETCH $12,000 of new monthly recurring revenue by June 30) and a pay plan (commission-heavy, balanced, salary). Easy x0.8 and Hard x1.2 on the quota (R-39). A week has 8 selling hours (R-72); a balanced commission is two weeks of the fee (R-72). Each lead has an incumbent (nobody, ByteBrothers, Big Cheese, Plumb Line or an in-house nephew) that a discovery call reveals; the quote builder shows the rival price. Shortcuts win deals that churn faster and are counted as LIES.

### 6.7 The service crew and trust

The crew is Maya, Sam and Terry, each with morale. Alan's and Garrison's trust meters start at 50 (R-70); siding with one raises the favoured owner's trust and lowers the other's; asking Alan for a favour costs Garrison's goodwill. Fail: both under 20 (not on Easy). **That fail rule has no test** (R-71). The service mode has no money; its currency is trust and morale.

### 6.8 Outings, rival and habits

- **Outings:** nine games an evening can offer (bowling $120, karaoke $180, escape room $240, dinner $300, chair race $120, cornhole $100, cookout $150, paintball $200, darts free). Schedule: evening outings on tech days 5, 10, 15 and owner weeks 4, 9, 14, 19; lunch breaks on tech days 3, 7, 12, 17 and owner weeks 2, 7, 12, 17 (R-50); the conference trip on tech day 17 (R-51), gated by KPIs. A good night out makes friends (R-53). The mini-games are party games with no campaign consequence beyond mood, friendship and a small energy gain.
- **Rival and habits (owner):** Big Cheese is the story rival, with 11 beat cards in weeks 3 to 20. What you learn goes on a rap sheet at four levels (UNKNOWN, RUMOUR, SEEN, PROVEN) that never goes down. 14 good habits make a Standard score (BARE, PATCHY, SOLID, SHOWCASE) that lifts the valuation at 70 or more. Conscience is shown only in words.

### 6.9 Randomness and seeds (checklist 27)

All outcome-bearing randomness goes through named streams (`Difficulty.rng("msp.tickets")` and 64 others), seeded from the run seed, and their positions are saved so a resumed day continues the same dice (R-29). The same seed gives the same game in all four campaigns with the same play (R-30, bot-driven). **Bounded:** the stream draws are bounded by the tables (weights are validated by the mutator validator, R-41). **Caveat (I-10):** 66 bare `randf()` / `randi()` / `shuffle()` call sites remain (outings 12, nerds 9, world 8, lync 8, talk 7 ...); they are cosmetic (chat, walks) by test, but the docs must not promise that every die is seeded.

### 6.10 Economy by mode: sources and sinks (checklist 23)

| Mode | Earned | Spent | Limits |
|---|---|---|---|
| Tech | Pay per day ($100 plus $20 per ticket closed, less $25 per miss and $10 per reopen, plus overtime) | The desk shop ($20 to $180) | Shop is the only sink; reputation, not cash, decides fired |
| Owner | Client fees, projects, extras, the filter | Wages, rent, seats, tools, marketing, outing costs, advice | Bankruptcy -$3,000; one $2,000 bailout on Easy |
| Sales | Commission (a pay plan) | Time (8 selling hours a week) | Quota; two missed quarters |
| Service | Nothing (trust and morale instead) | Hours | Trust under 20 |
| Free Play | Nothing | Nothing | None |

### 6.11 Every tunable number and where it lives (checklist 28)

- `Difficulty.TABLE`: 68 keys; `Difficulty.COZY`: 10; `MASTERY_KEYS`: 29; `DAY_SCALES` 0.5 / 1 / 1.5.
- `Mutators.SCHEMA`: 14 hook keys with validated ranges; 14 mutators and 5 starts are data.
- 143 `DEFAULT_*` tables are patchable from `godot/story/strings.txt` (136 sections): text and many numbers (medals, mutators, card options).
- Not data, scattered `const` lines (1,584 across 129 scripts): the reputation curve (`Campaign.START_REP` 50, `CLEAN_REP` 58, `SLOPPY_REP` 62, `TOP_REP` 90), `Owner.BANKRUPT`, `Sales.MAX_CLIENTS`, meeting, outing and trip days, ticket pace by day (`Msp.DAY_CAPS`, `OPEN_CAPS`), wire fraud 3.5 percent in `Incident`.
- There is no live tuning panel; the Free Play toolbox picks games, seeds and mutators, not numbers. Bots (`tests/bot_lib.gd`, `docs/dev/balance_baseline.json`, 25 cells) are the measurement tool.
- A generated tuning index (`docs/design/tuning.md`) is proposed (audit D7).

### 6.12 Movement and timing (checklist 25)

Walk 40 px/s, run 90 px/s, jump speed 230 with gravity 900 (logical pixels, `Player.WALK_SPEED`, `RUN_SPEED`, `JUMP_SPEED`, `GRAVITY`). The day runs 9:00 to 17:00 (`World.DAY_START`, `DAY_END`). How movement should feel (input latency, coyote time) is not written down (OPEN).

**Open items, section 6.** A tuning index (audit D7, Ben); seed or document the 66 bare random sites (audit D8); the service fail rule has no test (R-71); movement feel (Ben).

---

## 7. Interface and access

**Status: DECIDED (as built). The accessibility gaps are OPEN.**

### 7.1 Controls per device (checklist 29)

41 input actions (`systems-reference.md` 8.1). In short:

| Device | Moves | Acts | Notes |
|---|---|---|---|
| Keyboard | A D or arrows; Shift runs; Space, W or Up jumps; S or Down ducks | E uses and sits; Q waves; F drinks; P phone; Z aims; Esc or Pause pauses | 14 actions are remappable (R-60) |
| Gamepad (XInput style) | Left stick or D-pad; B runs; A jumps | X uses; Y waves; LB or RB step through targets and pages; RT aims; Start pauses; Back opens the phone | 7 actions remappable; right stick dances, follows, gives, mutes |
| Touch | A touch overlay exists | | Not verified on a real touch screen (OPEN) |
| Steam Deck / ROG Ally | As the pad | | Pad-only play is proven by tests (R-62, R-63); no hardware run |

**How it should feel:** not written (OPEN). The one rule that exists is that no screen needs typing: the name is a letter grid and the seed is six wheels.

### 7.2 Camera, view and what is on screen (checklist 30)

A side-on 2D camera. Five window shapes, chosen with SHAPE or F9: **wide** 368x128 (x4, 1472x512), **h** 320x180 (x4, 1280x720, follow), **deck** 320x200 (x4, 1280x800, follow), **v** 180x320 (x3, phone shape), **vclose** (v at zoom 2). A 16:10 screen starts in `deck`; full screen on 16:9 starts in `h` (R-65). On screen: the HUD strip (mode-specific: day and reputation, week and cash, week and quota), the clock, the goal chip, hint lines and toasts; takeover screens for the Computer, the phone, cards and the day report; a map; the pause menu. F10 hides the HUD for filming.

### 7.3 The front end (checklist 31)

Title (the logo over a looping office scene), the home menu, a mode submenu with slots, the character select and creator, the pause menu (RESUME, CONTROLS, SHAPE, DAY LENGTH, TICKET PACE, OUTFIT, SOUND, DISPLAY, UNFOCUSED, CAREER, FREE PLAY MENU, QUIT TO TITLE; some only in some modes) and the SETTINGS screen from the title. The manual's list of SETTINGS rows is one short: it omits DISPLAY and UNFOCUSED (audit I-8).

### 7.4 Accessibility, as it is today (checklist 32)

| Area | State on `main` |
|---|---|
| Text size | The font is 5 logical pixels high (20 physical px at x4, above Valve's 9 px floor). **There is no TEXT SIZE option** on this commit (ROADMAP R42 item 4; a size setting may be in flight and will need a pass over this table). The 3x5 upper case font is the floor. |
| Contrast and colour | **No high-contrast mode and no colour-blind pass.** Not reviewed. |
| Controller | Full pad play (R-62); pad glyphs shown when a pad is in use and never a key name (R-63); remap of 14 keyboard and 7 pad actions (R-60). |
| Text entry | None needed (letter grid, seed wheels). |
| Difficulty assists | Cozy Easy; DAY LENGTH x0.5 to x1.5; TICKET PACE (relaxed to busy); corn.assist on Easy. |
| Sound | No mechanic depends on sound (a rule from the audio notes). No volume sliders beyond SOUND on/off, mute and music volume. |
| Motion and flash | Not reviewed (no reduce-flash or shake setting). |
| Hold vs toggle | No toggle option. |
| Subtitles | Not applicable: there is no voice. |
| Statement | None written. |

The audit proposes an accessibility pass (D9): text size, contrast and colour check across the five formats, reduce-flash review, and a written statement. It is OPEN.

### 7.5 Localisation and text volume (checklist 33) - PROPOSED (audit D-7)

**English only at launch.** The game text is a patchable file (`godot/story/strings.txt`, 6,666 keys, 146,629 words), so a translation is structurally possible, but `PixelFont.GLYPHS` is A to Z, 0 to 9 and 30 marks only: no accents and no non-Latin script. A language plan would need a wider font and a text-length budget. Say "English only" on any store page.

### 7.6 Settings and what is saved (checklist 34)

The settings file (`user://mspsim_settings.cfg`) keeps: audio volume, music volume and mute; the tier; display format, fullscreen and the focus-pause switch; look (accessory and custom); ticket pace; and the remapped keys. Campaign files hold the run (3 slots per mode plus a resume point). Career is one profile for everyone, including co-op (decided).

**Open items, section 7.** Text size, contrast, colour, flash, a statement (Ben, audit D9); touch screen check (needs hardware); remap on a real pad (needs hardware).

---

## 8. Fiction and presentation

**Status: DECIDED.**

### 8.1 Setting and period (checklist 35)

2013 into spring 2014 (Windows XP support ends on 8 April 2014, CryptoLocker is the new scary thing, RDP is open to the internet at half of all small businesses). Pixel IT Partners: a main floor, two offices, a kitchenette, restrooms, a cubicle area, a conference room, a warehouse with a parking lot and a network closet with a rack you can plug and unplug. The story matters to play: every day's beat changes what tickets arrive and what the decisions mean.

### 8.2 Tone, characters and voice (checklist 36)

Warm, dry, a little absurd, never mean. Jargon is used correctly and explained by context. Alan and Garrison are the two owners (Alan technical, gruff and kind; Garrison sales and culture, excitable, a security scare story for everything); Morgan Reyes manages the floor and runs the reviews; Dan is quiet and labels everything; John over-promises; Maya is tier 1; Christy is the controller. Emails and texts are short, human and slightly panicked. The Bible has the cast table (stale on eight people, noted in its header) and the clients.

### 8.3 Visual style (checklist 37)

Low-resolution blocky pixel characters on a 40x64 canvas, a big head (about 18 px, a third of the body), flat colours with one shade per material, light from the top-left, a 1 px dark outline `#17121F` on every layer, three-quarter view facing left or right (the left is a mirror of the right). The palette and layer rules are in `CLAUDE.md`. Rooms are slightly grimy 2010s offices (stained ceiling tiles, blue carpet, a green hallway); outing rooms are dark and neon. Rooms, props and UI have no style sheet of their own (a gap, OPEN). Real brands are parodied (ConnectWhy, LabRat RMM, Outlookish 2013, LabRat Nerds, Floppy Bat, Sugar Smash, iFone, Nexxus, Lynk).

### 8.4 Audio (checklist 38) - DECIDED: ON HOLD

**Audio work is on hold by the owner's decision.** What exists: synthesised sound effects, a lo-fi music loop, three invented radio stations in the warehouse, a mute key (M), and volume and music volume settings (`Sfx`). What is parked: music direction per room, ambience, footsteps (defined, not hooked), real recorded assets, volume sliders. No mechanic depends on sound. Nobody should add sound work until the owner lifts the hold.

**Open items, section 8.** A style sheet for rooms, props and UI; audio direction (after the hold).

---

## 9. Technology and platform

**Status: DECIDED, except launch platforms (PROPOSED, audit D-4) and the hardware claims (OPEN: no Deck was available).**

### 9.1 Platforms, hardware and engine (checklist 39, 45)

- **Engine:** Godot 4.7.2, GL Compatibility renderer. (`project.godot` features still say "4.4": a small fix, OPEN.) 129 scripts, about 91,400 lines; 51 autoloads; 68 scenes; art drawn in Aseprite and exported to Godot PNGs.
- **Targets (decided):** PC first; **Steam Deck and Windows handhelds (ROG Ally) are a target** and nothing may work against them; the repo is public. **No Switch** (dropped 2026-11-10). Mobile and iOS stay parked (export presets are stubs).
- **Launch (PROPOSED, audit D-4):** Windows and Steam Deck (the Linux build, started for 300 frames in CI) first; macOS and Linux desktop only if the Deck build runs.
- **Hardware:** minimum and recommended specs are not written (the README says "a toaster"); OPEN.
- **Store and platform requirements:** the Valve and Microsoft checklists are compared in `docs/steam-deck.md`; the Steam store requirements (capsule sizes, trailer, rating questionnaire, tax and bank details) and Steam Input are OPEN (needs a Steamworks account and a Deck).

### 9.2 Performance (checklist 40)

Measured on a desktop (Ryzen 9 5950X, RTX 3070, 1280x800 `deck` format, `docs/steam-deck.md` section 7): average frame 1.2 to 2.1 ms in rooms and mini-games (the budget at 60 Hz is 16.6 ms); the Computer's RMM 2.7 ms; **the metrics dashboard 6.1 ms average (about 8 ms for a 60 Hz frame), the one heavy screen**. A Deck is roughly twice as slow per core, so the dashboard is expected to land on the line (30 to 60 fps). Not measured on a Deck. **Fallback (not done):** merge each glyph row of `PixelFont.draw` into one rect and cache per glyph (about 40 percent fewer draw commands), or paint the Computer into a cached texture. No memory budget exists (OPEN).

### 9.3 Saving, persistence, old saves (checklist 41)

Three slots per campaign (R-31), a mid-day resume point (R-34), a settings file, one career profile. A save is written at each day end. **Old saves:** an old save loads unchanged (R-32); sections are versioned and migrated (`save_migrate.gd`); a save without a field gets the default (R-36). There is no written save-format document, no list of section versions and no policy for how many releases an old save must load (OPEN, audit D14). Under Proton, saves do not move between a native and a Windows build.

### 9.4 Co-op (checklist 42)

Optional two-player local couch co-op, one shared screen in the same room. **Built and tested:** shared camera, tether and group doors; split-pane Computer and phone per player; joining the tech campaign with per-player skills and energy and a shared reputation; a saved second player (R-67, R-68); the owner campaign; cornhole, bowling, chair, grill, karaoke and escape as two-player games. **Decided:** player 2 is for Free Play and the tech mode and the owner campaign, and a passenger in service and sales. **Out of scope:** online play (ever, per the non-goals), a second profile in Career. **Not done:** play-testing the panes with two humans, rumble on a real pad, tuning the co-op ticket pace and share.

### 9.5 Tooling and pipeline (checklist 43)

- **Art:** Aseprite via an MCP server; layered `.aseprite` files are the source; `tools/anim.lua` builds animation files; Godot PNGs are generated.
- **Generator rule:** `tools/make_godot.py` generates the Godot scripts and scenes. **It is never run in the real tree** because the committed scripts carry hand edits ported back into it. Every change goes to both the real file and the generator through `tools/port_edit.py`; `tools/check_generator.py` fails a mismatch.
- **Text:** `godot/story/strings.txt` is the one editable text file; `tests/story_export.gd` syncs it.
- **Docs:** `docs/design/systems-reference.md` is generated from the code (`tests/make_systems_reference.gd`).

### 9.6 Build, test and release (checklist 44)

CI (`.github/workflows/tests.yml`) runs the suite, `gdlint`, the generator check and a Linux export started for 300 frames, on every push to main, pull requests and nightly. The default suite on this commit is **304 test scripts** (399 files in `godot/tests`, about 71,600 lines; the rest are screenshot tools, balance bots and harnesses run by name). There is **no release process**: no version scheme, no release build script, no Windows export in CI, no changelog (OPEN, audit D13).

**Open items, section 9.** Hardware spec; `project.godot` version string; a Deck run; Steamworks; release process; save-format document (Ben and the coordinator; audit D13, D14, D15).

---

## 10. Production summary

**Status: DECIDED for the facts; PROPOSED for everything forward-looking. The full production plan is in `docs/design/scope-risks-tests.md` and is not duplicated here.**

- **Team (checklist 46):** one owner and designer (Ben) and AI coding and art agents. Work is split by roadmap row, in separate git worktrees, merged by a coordinator; each agent follows a shared rules file. No roles table exists in the repo (OPEN).
- **History (checklist 47, partial):** about 588 commits from 2026-11-02 to 2026-11-12, one author. The roadmap (`docs/ROADMAP.md`) has rows with sizes and no dates.
- **Status:** all four campaigns, Year 2 and Year 3, 11 mini-games, the creator, Free Play, the career, co-op and the Deck readiness work are built. What is open is in section 12.
- **Milestones, schedule with test time, budget, cut list, risk register, success measures, store page and launch plan** (checklist 47 to 56): see `docs/design/scope-risks-tests.md`. The audit's recommended cut order is more forum characters, mutator sound, a second-office phase, new mini-games.

**Business and launch (checklist 54, 55, 56) - PROPOSED.** Price: one paid PC release at about $9.99 to $14.99 with Years 2 and 3 in the base game, no DLC at launch, reassess after the first review round (audit D-3). Post-launch: no patch cadence, no expansion stance and no mod statement are set; the editable `strings.txt` is a de facto text-mod surface. Launch scope (audit D-8): freeze content; spend the next period on playtest findings, accessibility, the how-to-win page and the store page.

**Legal and rights (checklist 57) - DECIDED for now, with a hard stop.**

- **Likenesses.** The cast are **caricatures of real people with their real first names** (the author, Dan, Alan and Garrison among them; `CLAUDE.md` "Characters" lists the references). The owner decided to **keep them as they are for now**. **Revisit before any store page**: consent from each real person, or re-caricature past recognition and rename (audit D-5), and the reference photos in `archive/` should leave the public repository. The repository is public (CI header); the older "private" lines in the ROADMAP are stale.
- **Products** are parodies (ConnectWhy, LabRat RMM, Outlookish 2013); a name list is enforced by `godot/story/banned_names.txt` and `tests/canon_text.gd` (R-75).
- **Tools and assets:** Godot (permissive licence); Aseprite and the origin of the 3x5 font have no licence note in the repo (OPEN). A trademark search for "MSPSim" and "Pixel IT Partners" has not been done (OPEN).

**Open items, section 10.** Everything that says OPEN above; the coordinator owns `scope-risks-tests.md`.

---

## 11. Rules and where they are tested

**Status: DECIDED (each rule is read from a test or the code).**

Convention: `R-n: statement. Test.` A test is named by its file in `godot/tests/`. "default suite" means it runs in `python tools/run_tests.py` on this commit. "bot only" means only a balance run covers it. "untested" means no test asserts it (the code was read instead).

| # | Rule | Where tested |
|---|---|---|
| **Modes and structure** | | |
| R-1 | A new tech campaign starts on day 1 at reputation 50, before 9:00. | `campaign.gd` |
| R-2 | The day-20 report is final ("YEAR COMPLETE") and leads to the yearly review. | `campaign.gd` |
| R-3 | A finished campaign clears its save. | `campaign.gd` |
| R-4 | On Normal, reputation 0 is fired and final. | `campaign.gd`, `cozy.gd` |
| R-5 | On Easy nobody is fired: reputation 0 floors at 15 and a PROBATION line appears in every mode. | `cozy.gd` |
| R-6 | On Easy two missed sales quarters are not the end of the job. | `cozy.gd`, `sales_hard.gd` |
| R-7 | On Normal two missed sales quarters end the job (let_go). | `cozy.gd` |
| R-8 | On Easy bankruptcy pays one $2,000 bailout and a second shortfall has no consequence. | `cozy.gd` |
| R-9 | On Normal bankruptcy ends the run. | `cozy.gd` |
| R-10 | The valuation does not count the bailout; the bailout flag is saved. | `cozy.gd` |
| **Cozy Easy** | | |
| R-11 | The Easy day report has no SLA MISSED or REOPENED rows, open tickets read "carried over", nothing is red, the grade letter stays. | `cozy.gd` |
| R-12 | Easy SLA windows are the tier's 1.3 times the cozy 1.6 of Normal. | `cozy.gd` |
| R-13 | An SLA miss costs client mood 2 on Easy and 8 on Normal; a reopen 1 and 6. | `cozy.gd` |
| R-14 | On Easy no reputation or pay is lost to a miss, a reopen or open tickets, and there is no scar for an unworked P1. | `cozy.gd` |
| R-15 | On Easy fatigue costs no speed or accuracy, staying late costs no energy, the commute is safe, ignoring the pager is free, nobody quits, the rival's poach risk is halved, lost ransom files cost about 5 reputation and no scar. | `cozy.gd` |
| **Tickets, SLA, reputation, grades** | | |
| R-16 | The day pays $100 plus $20 per ticket closed, and a clean day with 3 closed tickets earns +3 reputation (the report's grade is A). | `campaign.gd` |
| R-17 | Day 1 makes exactly one random ticket and not before 60 s. | `daycap.gd` |
| R-18 | Ticket caps: 3 on day 2, 5 on day 3, 6 on day 4, 12 from day 10; the open queue holds 3 on day 1 and 6 on days 10 and 17. | `daycap.gd` |
| R-19 | Free Play and the owner campaign are not ticket-capped (99). | `daycap.gd` |
| R-20 | An onsite ticket gets a longer SLA than its priority's base. | `bugfix.gd` |
| R-21 | Year 2 tickets carry SLA x0.85; Year 3 clocks are tighter than Year 2. | `yeartwo.gd`, `yearthree.gd` |
| R-22 | Closing a ticket counts it by kind in Career. | `career.gd` |
| R-23 | The day report adds at most 4 reputation. | `t2.gd` |
| R-24 | A scar lowers the reputation ceiling to 85 and gains stop at the ceiling. | `t2.gd` |
| R-25 | From reputation 90 a gain is banked as a fraction: eight thank-yous or two S-grade jobs per point; slower again from 95. | `top_curve.gd` |
| R-26 | The grade is S, A, B, C or D from the day's points (S needs 20 points, no misses, none open, 4 or more closed). | `campaign.gd` checks an A; `cozy.gd` checks the letter exists; the S condition is untested |
| **Seeds** | | |
| R-27 | A seed is six hex digits; `#` and `0x` are ignored, zero becomes 1, a word is hashed case-insensitively. | `seeds.gd` |
| R-28 | The same seed gives the same draws in every named stream; another seed gives others. | `seeds.gd` |
| R-29 | Stream positions are saved and resume where they stopped. | `seeds.gd` |
| R-30 | The same seed gives the same tech (four days, hard) and sales game with the same bot; another seed another game; an owner seed does not depend on earlier seeds. | `determinism.gd` (bot-driven, default suite) |
| **Saving** | | |
| R-31 | Three slots per mode: slot 1 keeps the old file name, slots 2 and 3 add `_s2` and `_s3`. | `slots.gd` |
| R-32 | An old save continues unchanged in slot 1. | `slots.gd` |
| R-33 | The next day is saved when a day report is continued. | `campaign.gd` |
| R-34 | A mid-day snapshot restores the clock, every ticket and SLA clock, mails and texts, and the next ticket id; no temp file remains. | `resume.gd` |
| R-35 | Free Play leaves a campaign's resume file alone. | `resume.gd` |
| R-36 | DAY LENGTH applies from the next morning, is saved, and an old save without it loads the normal day. | `cozy.gd` |
| R-37 | DAY LENGTH x1.5 applies to every mode's day. | `cozy.gd` |
| **Difficulty and replay** | | |
| R-38 | Build points are 15 / 12 / 9 by tier, and +2 in Year 2. | `build.gd`, `yeartwo.gd` |
| R-39 | The stretch quota is 12,000; Easy scales it to 9,600 and Hard to 14,400. | `sales_campaign.gd` |
| R-40 | The mastery ramp is 10 plays; only 2- and 3-star plays count, per game; leaving early does not. | `mastery.gd` |
| R-41 | A mutator with an out-of-range weight, an unknown key or hook, a bad kind, an unfit extra problem, five coworkers out or an unwinnable SLA is refused. | `mutators.gd` |
| R-42 | Owner-only mutators never appear in a first year's pool and join the pool in Year 2. | `mutators_r9.gd` |
| R-43 | GOOD QUARTER scales income x1.15 and never outgoings; PRICE WAR x0.9 plus poach pressure. | `mutators_r9.gd` |
| R-44 | Easy is never fired in any mode and strategy; good endings fall from Easy to Normal to Hard for the careful bot. | `tiers_balance.gd` (bot only) |
| **Cards, goals, years** | | |
| R-45 | The first-day card has three answers; the pick is kept as a flag and a text arrives next morning from the person it touches. | `first_day.gd` |
| R-46 | The goal chip reads "OPEN THE COMPUTER AT YOUR DESK" with an empty queue on day 1 and "CLOSE YOUR FIRST TICKET" with a ticket; Free Play shows none. | `goal_chip.gd` |
| R-47 | A finished run puts NEW GAME PLUS (YEAR 2) on the title menu; Year 1 has no SLA change, no build bonus and a client cap of 8. | `yeartwo.gd` |
| R-48 | Owner partner trust carries into Year 2, between 40 and 75. | `yeartwo.gd` |
| **Outings and the trip** | | |
| R-49 | Karaoke is a 24-note song; every note on time is a perfect 3-star set; a wrong arrow does nothing. | `outings.gd` |
| R-50 | Lunch breaks fall on tech days 3, 7, 12, 17 and are never on an evening-outing day; the Easy tier offers lunch on an ordinary day. | `lunch_break.gd` |
| R-51 | The conference trip day is day 17 and no other. | `conference.gd` |
| R-52 | A good record meets all four trip KPIs, and the trip day pays a per diem. | `conference.gd` |
| R-53 | A good night out raises friendship and records the best score. | `outings.gd` |
| **Shop, decor, career** | | |
| R-54 | The shop has 12 items with unique ids; you cannot buy what you cannot afford or already own; a red keyboard replaces a blue one. | `shop.gd` |
| R-55 | A blue keyboard costs $90, cuts fix time 5 percent and is loud; a red one is quiet and 4 percent faster; the mouse and riser stack on drain. | `shop.gd` |
| R-56 | Every decor item has a rule; a new run has a bare office; reputation 56 brings the plant with a toast; the fish tank needs reputation 75. | `office_growth.gd` |
| R-57 | There are at least 20 medals, ids are unique, every unlock points at a real medal, and a medal is earned at exactly its threshold. | `career.gd` |
| R-58 | An earned medal is announced by a toast. | `career.gd` |
| **Controls and access** | | |
| R-59 | The walking actions can be remapped; a clash swaps; one key per action; the map is saved and loaded. | `remap.gd` |
| R-60 | No script outside `controls.gd` reads a raw key. | `raw_keys.gd` |
| R-61 | A pad walks the title menu; D-pad down and a stick push move the cursor. | `pad_only.gd` |
| R-62 | With a pad, RB reaches every click region of every Computer app and phone screen. | `pad_reach.gd` |
| R-63 | With a pad active no scanned screen names a key or the mouse. | `pad_prompts.gd` |
| R-64 | Esc in a room opens the pause menu and the clock stands still. | `pause.gd` |
| R-65 | The `deck` format is 320x200 at x4 = 1280x800; a 16:10 screen starts in `deck`; 16:9, ultrawide and an unknown screen pick `wide`, and full screen on 16:9 starts in `h` with no bars; losing focus opens the pause menu with no time passing. | `deck_display.gd` |
| R-66 | In the `v` format every tap target is at least 19 px and none overlap. | `tap_targets.gd` |
| **Co-op** | | |
| R-67 | Player 2 can join the tech campaign; each player's XP and energy are kept apart. | `coop_campaign.gd` |
| R-68 | A co-op save restores player 2's device, person, skills, energy and look, and leaves player 1's skills alone. | `coop_save.gd` |
| **Owner, service, sales** | | |
| R-69 | A new owner campaign starts with `Owner.START_CASH` ($7,500) and 240 s weeks. | `owner.gd` (its label still says $5,000; the assertion compares the constant) |
| R-70 | Service: the select offers only Dan; the crew is Maya, Sam, Terry; trust starts at 50 each; siding with Alan raises his trust and lowers Garrison's, and the other way round. | `service_campaign.gd` |
| R-71 | Service fails when both owners' trust is under 20 and the tier is not Easy. | untested |
| R-72 | Sales: the select offers only John; Garrison opens with the three quota choices; a week has 8 selling hours; a balanced commission is two weeks of the fee. | `sales_campaign.gd` |
| R-73 | Service always offers STAY (probation) at the review. | `service_campaign.gd` |
| **Text and canon** | | |
| R-74 | The story text file loads without problems and holds more than 400 editable strings. | `strings.gd` |
| R-75 | No era word or real vendor name appears in a player-facing string. | `canon_text.gd` |
| R-76 | The systems reference warns when its committed copy has drifted (never fails). | `systems_reference.gd` |
| **Rules known to be untested** | | |
| R-77 | The open-queue cap in the generated reference matches the code. It does not (reference says 5 from day 10, code and `daycap.gd` say 6). | `daycap.gd` shows the code; the generator is wrong |
| R-78 | A fired run deletes the slot and returns to the title. | untested (the delete is read in `Campaign.report_continue`; `campaign.gd` tests only the clear after a finished run, R-3) |
| R-79 | A fired run unlocks nothing for Year 2 (`Yeartwo.record` runs only from `finish_campaign`). | untested |
| R-80 | A tech Easy review below 45 shows "ON NOTICE: PROVE YOURSELF NEXT YEAR". | untested (text read in `review.gd`) |

Count: 80 entries. 75 name a test, of which 1 is bot only (R-44) and 1 is bot-driven in the default suite (R-30); 4 are untested (R-71, R-78, R-79, R-80) and 1 is partly untested (R-26, the S condition); R-77 records a known fault in the generated reference rather than a rule.

**Open items, section 11.** Add tests for R-71, R-78, R-79; fix the generator for R-77 (coordinator).

---

## 12. Open items and decisions

**Status: this is the only list; every item names an owner or a roadmap row.** "Audit" ids refer to `gap-audit.md` section 3 (proposed rows, not yet in the ROADMAP) and section 4 (decisions).

| # | Item | Mark | Owner | Reference |
|---|---|---|---|---|
| 1 | Age rating and audience; mark or remove "RATED E" on the README | PROPOSED | Ben | audit D-2 |
| 2 | Price and business model: one paid PC release, about $9.99 to $14.99, no DLC, no free-to-play | PROPOSED | Ben | audit D-3 |
| 3 | Launch platforms: Windows and Steam Deck first | PROPOSED | Ben | audit D-4 |
| 4 | A human playtest before launch (days 6 to 20 of tech by two humans, one owner week, a Q7 realism reviewer) | PROPOSED | Ben | audit D-6, D12 |
| 5 | Localisation: English only at launch | PROPOSED | Ben | audit D-7, D10 |
| 6 | Launch scope: freeze content; spend time on playtest findings, accessibility, the how-to-win page, the store page | PROPOSED | Ben | audit D-8 |
| 7 | Name: keep "MSPSim" with a plain subtitle; name search | PROPOSED | Ben | audit D-9 |
| 8 | Close campaign-paths section 14 by accepting the built defaults | PROPOSED | Ben | audit D-10, ROADMAP H7 |
| 9 | Likenesses: consent or re-caricature before any store page; move reference photos out of the public repo | OPEN, owner kept as is for now | Ben | audit D-5, D11 |
| 10 | How-to-win screen per campaign | OPEN | coordinator | audit D2 |
| 11 | What "fired" leaves behind: a retry from the last day, and what unlocks Year 2 | OPEN | Ben | audit D4, I-2 |
| 12 | Accessibility pass: TEXT SIZE option, contrast and colour, reduce flash, hold vs toggle, a written statement | OPEN | coordinator | audit D9, ROADMAP R42 item 4 |
| 13 | A tuning index generated from the code | OPEN | coordinator | audit D7 |
| 14 | Seed or document the 66 bare random call sites | OPEN | coordinator | audit D8, I-10 |
| 15 | Save-format document, section versions and the old-save policy | OPEN | coordinator | audit D14 |
| 16 | Steam store requirements, achievements mapping of the 72 medals | OPEN | Ben | audit D15 |
| 17 | Production documents: milestones with dates, ranked cut list, project risks, success measures, store copy, release checklist and version scheme | OPEN | coordinator | audit D13, `scope-risks-tests.md` |
| 18 | A Deck, an Ally, a physical pad and a touch screen run; Steam Input defaults; the dashboard's frame time | OPEN (needs hardware) | Ben | `steam-deck.md`, R42 |
| 19 | Minimum and recommended hardware; a memory budget | OPEN | Ben | checklist 39, 40 |
| 20 | Audio: on hold by decision; lift the hold before any sound work | DECIDED (on hold) | Ben | ROADMAP P4 |
| 21 | Real comparables and a genre argument with player evidence | OPEN | Ben | 1.3, 1.5 |
| 22 | Movement feel (input latency, coyote time, walk vs run) not written | OPEN | Ben | 6.12 |
| 23 | Tests for R-71, R-78, R-79; the systems-reference open-queue cap (R-77) | OPEN | coordinator | section 11 |
| 24 | Licences of Aseprite and the 3x5 font origin; a trademark search for "MSPSim" and "Pixel IT Partners" | OPEN | Ben | section 10 |
| 25 | `project.godot` features string says 4.4, the engine is 4.7.2 | OPEN | coordinator | audit section 5 |
| 26 | Doom Bible items (monster, weapon and level specifications, technology goals): not yet merged into the checklist | OPEN | Ben | checklist source B |
| 27 | A style sheet for rooms, props and UI | OPEN | Ben | 8.3 |

---

## 13. Checklist index

Every one of the 60 checklist items is answered in the section shown. Items I judge answered only partly are marked "weak" with the reason.

| Checklist # | Section | Note |
|---|---|---|
| 1 | 1.1 | |
| 2 | 1.2 | |
| 3 | 1.3 | weak: no market evidence |
| 4 | 1.4 | |
| 5 | 1.5 | weak: no sales data |
| 6 | 1.6 | |
| 7 | 1.7 | |
| 8 | 1.8 | |
| 9 | 1.9 | |
| 10 | 3.1 | |
| 11 | 3.2, 3.3 | |
| 12 | 3.2, 3.4 | weak: the service fail rule is untested |
| 13 | 4 | |
| 14 | 2.1, 2.2 | |
| 15 | 2.3 | weak: one worked day, tech only; not a recorded human play |
| 16 | 5.1, 5.2 | |
| 17 | 5.4 | |
| 18 | 5.5 | |
| 19 | 3.2, 5.6 | weak: total hours are estimates |
| 20 | 6.0 | |
| 21 | 6.1, 6.2, 6.4 | links out for the lists |
| 22 | 6.4 | weak: escalation is described, not tabled |
| 23 | 6.5, 6.10 | |
| 24 | 11 | |
| 25 | 6.1, 6.12 | weak: only the player's movement numbers |
| 26 | 6.1, 5.4 | |
| 27 | 5.7, 6.9 | |
| 28 | 6.11 | |
| 29 | 7.1 | weak: feel not written |
| 30 | 7.2 | |
| 31 | 7.3 | |
| 32 | 7.4 | weak: today's state is mostly "missing" |
| 33 | 7.5 | |
| 34 | 7.6 | |
| 35 | 8.1 | |
| 36 | 8.2 | |
| 37 | 8.3 | weak: no room or UI style sheet |
| 38 | 8.4 | on hold |
| 39 | 9.1 | weak: no hardware spec |
| 40 | 9.2 | weak: Deck numbers are estimates; no memory budget |
| 41 | 9.3 | weak: no policy |
| 42 | 9.4 | |
| 43 | 9.5 | |
| 44 | 9.6 | weak: no release process |
| 45 | 9.1 | weak: Steam requirements not done |
| 46 | 10 | weak: no roles table |
| 47 | 10 | links to `scope-risks-tests.md` |
| 48 | 10 | links to `scope-risks-tests.md` |
| 49 | 10 | links to `scope-risks-tests.md` |
| 50 | 10 | recommended cut order only |
| 51 | 10 | links to `scope-risks-tests.md` |
| 52 | 10, 11 | links to `scope-risks-tests.md` |
| 53 | 10 | links to `scope-risks-tests.md` |
| 54 | 10 | PROPOSED |
| 55 | 10 | PROPOSED |
| 56 | 10 | weak: no stance beyond editable text |
| 57 | 10 | |
| 58 | 0 (legend), every section's status line | |
| 59 | 12 and each section's "Open items" | |
| 60 | 0 (revision history, companion documents) | |
