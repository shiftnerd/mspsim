# MSPSim roadmap

The one ordered list of what is built and what is still open. Detail lives elsewhere: bugs and gaps in `docs/BACKLOG.md`, the long idea lists in `IDEAS.md`, the replayability write-up in `docs/replayability-ideas.md`, the new-campaign design in `docs/campaign-paths.md`, system documentation in `CLAUDE.md` (each done row names its section).
Row ids (R, X, C, T, Q, P, H) are stable: never renumber them. Effort: S under a day, M 1-3 days, L a week or more.

## Decisions so far (user)
- Alan and Garrison are the two owners of Pixel IT Partners (Alan technical, Garrison sales and culture). Morgan Reyes is the manager and **a real cast member**. Marge bookkeeper, Vic account manager.
- Owner campaign is played as **Alan or Garrison**; the other is the co-owner NPC. Owners take a **weekly draw from the bank balance**.
- Service manager campaign is played as **Dan**. Sales campaign is played as **Vic**.
- In the tech campaign the owners are busy and jump in **as a last resort** (phones, clients); stepping in **costs no reputation**.
- Difficulty tiers and seeded randomness are wanted; point-buy stats at character select are wanted. **Easy is the cozy tier** (never fired, nothing punishes you).
- Parody names for products whose UI we imitate (Sugar Smash, Floppy Bat, iFone, Nexxus, Lynk, Googol); Apple, Windows, Exchange and PowerShell stay as era context. The game is set in 2013-14.
- Tests use their own save copy (a per-process `user://test_<pid>_...` prefix).
- Dialogue Manager addon: skip for now. Gitot: optional.
- The canon text pass (Alan and Garrison recast as owners in dialogue, tips, Lynk, vignettes, review, outings) is done; see CLAUDE.md "Canon: the owners".

## 1. Done
Detail for each is in the CLAUDE.md section named in brackets.

**Core game**: tech and owner campaigns end to end; Free Play; the outing rooms and their mini-games; client sites and onsite visits; the printer game; nerf war; character select; the day report; parody brand names; extra valid fixes for every ticket type; the repo on GitHub (private) with worktree hooks; research on Dialogue Manager and Gitot; the replayability and new-campaign design documents.

**Tech and owner balance and fixes**
- T2 tech campaign fixes and balance (reputation curve with daily cap and scars, review jobs, ransomware with no backup, forced playbook tickets, overtime) ["Tech playthrough fixes, days 5-20"].
- X1 owner round 2, X9 owner round 3 (card queue, valuation, risky change orders, peer goal, trust arrows) ["Owner round 2", "Owner round 3"].
- X2 and X3 player as a cast member, Morgan Reyes in the cast. X4 and X5 owner campaign as Alan or Garrison with a partner model and weekly draw. X6 owners as last-resort help in the tech campaign. X7 point-buy build at character select. X8 mode registry `Campaign.MODE_DEFS`.
- Q1 live tech playthrough, Q2 hand-played 20 owner weeks as Garrison, Q3 screenshot and audit sweep, Q4 real clicks in tests (`Game.click_at`), Q5 the Free Play ghost removed, Q8 worktree hooks tested.

**Campaigns**
- C1 to C3 sales campaign as Vic (skeleton, deep loop, story/voices/point-buy/balance). C4 to C7 service manager campaign as Dan (slice 1, crew and Dispatch, runbooks/desk design/hiring/retention, the 20-day arc and endings).

**Replayability**
- R1 difficulty and seeds (typed seed, daily seed, saved stream positions). R2 printer variety. R3 karaoke songs. R4 escape-room recipes. R5 who comes along. R6 dinner variety. R7 career screen and medals. R8 event deck and vignette deck. R9 mutators and starting conditions. R10 Year 2 / New Game+, daily seed and the Free Play toolbox. R11 bowling, nerf, trip and onsite variety. R30 mastery ramp and moving sweet spots.

**Features and polish**
- R12 rolling chairs and the chair race. R13 pause menu. R17 title menu with campaign submenus. R19 three save slots per mode. R20 PIXEL IT METRICS dashboard (computer app and wall TV). R22 two bathrooms with occupancy locks. R25 dual monitors on every desk. R26 seated characters come alive (gestures). R27 LabRat Nerds forum overhaul. R28 Priest Michael and the forum regulars. R32 LabRat Nerds IRC chat and friendship.
- R18 the warehouse and the side-scrolling chair race. R21 cornhole, the cookout and the overhead door with the parking lot. R23 Rodent Nation venue fixes (four breakout rooms, speaker, no `client_*` crowd). R24 map rework (warehouse from the kitchenette, closet from the warehouse). R29 toss pose, lunch break and hot dogs.
- R15 character creator: colours, ten hairstyles, glasses/beards/hats, nametag/lanyard/watch, mirror preview, Free Play outfit swap and NPC copies, real clothes. R16 cozy Easy, the day-length option and the mid-day resume point (steps 1 to 4). P4 audio (synthesised sounds and music). P6 heavy fixes in person, more ransomware exits, clever fixes in Free Play.
- R30 mastery ramp and moving sweet spots (good plays tighten each game's skill checks; zones move per roll or patty) ["Mastery ramp and moving sweet spots"]. R31 and R33 side-view chairs, seated pose with raised hips and bent knees, taller tables, side-on lounge seats ["Seating geometry"]. R32 LabRat Nerds IRC social chat, friendship and a living channel. R34 couch co-op: scoped and risk-tested (`docs/scope-coop.md`, `docs/coop-risk-findings.md`) and phase 1 built behind `Players.coop` (off by default). R35 calmer character select (creator first, ready-made people as START presets). R37 phone dialer, lock screen and notification banner, and the dashboard escalation trend arrow.
- H1 `tools/check_generator.py`, H2 keep `.import` files committed, H3 `.gitattributes`, H4 per-test save prefixes and `tools/run_tests.py -j N`, H6 gdlint clean.

## 2. Open
What is really still open, by row id. Nothing here is scheduled; pick as the campaigns above land.

| # | What is open | Size |
|---|---|---|
| T2 | A live pass for the HUD and Review layout in all three formats; curves were measured on one seed; mixed play ends near 76 (target 55-75) | S-M |
| X6 | Owner help for onsite visits; a walk to the front desk for non-phone triggers; owner help counted by Career | S |
| X7 | No balance run per build preset; a Free Play MAX preset has no menu entry (`Build.max_build()`); tier x seed coverage in `seeds.gd` | S |
| X9 | A live screenshot check of the trust chips and the review crew lines; a manual 20-week replay | S |
| C3 | The new-hire story for Vic's own deals; a sales-director second year; ByteBrothers as a rival walking the office; spoken lines for the beats in Lynk; a lead-flow difficulty knob; commission scaled to the weekly fee | M |
| C7 | Owners walking to Dan and a 1:1 from the Capacity tab; a design line on the Dispatch SCORE tab; Morgan and the Summit auditor as walking characters; Career medals for the service endings; a hand-played pass for card pacing; tiers other than normal for the arc | M |
| R1 | `Owner` / `Shift` / `Projects` randomness is still global; hard-tier numbers checked by play; a separate tier step instead of the chip | S |
| R2 | The boss line printer (P4) and the parts bag (P6) | S-M |
| R3 | Karaoke hold notes (K2), duets (K5), set lists (K6), pager interrupt (K8) | M |
| R4 | Random clue spots (E6), more red herrings (E3), hint-time penalty on easy (E4), themed rooms (E5) | M |
| R5 | Vic's client in the owner campaign; karaoke and escape intros that name the party | S |
| R6 | Dietary quirks and an ordering round (D4), a client at the table (D5), table events (D7), post-dinner talks (D8), an ASK HOW THEY ARE topic and `as of outing n` marks (D2), the boss picking up the tab in the tech campaign | M |
| R7 | Art for the data-only unlocks (duck, desk toys), a real ringtone sound, a medal detail view, a Free Play hotkey for the career screen (today: phone Settings), a mastery row on the career screen | S |
| R8 | Seasonal tags beyond the day windows, a Career counter of cards seen, art for the cards | S |
| R9 | A `cash_mult` hook, a Free Play menu entry (only the backtick key chooser exists), owner-only mutators beyond slow payers, mutator art and sound | S |
| R10 | Year 2 plug-in rows for service and sales, a Year 3, a Year 2 medal, a new printer boss, balance by hand play | M |
| R11 | Choosing the alley by card, a league standings screen, neon sign text per alley, cup art, nerf team modes, a road event with a choice, new jobs for the architect and realty sites | M |
| R12 | Standing-and-pushing someone else's chair, a spin-around chair fight, a second course, medals (`IDEAS.md` "Team outings") | M |
| R14 | **Portability readiness** (user, Nov 2026: not porting yet, but do not paint the project into a corner). Done: the `Controls` autoload registers every action with keys and gamepad bindings; the menu-style screens use `Controls.pressed/nav/step/confirm/back`; the F-key room jumps are development builds only. Open, in order: (1b) the remaining raw keys (letter hotkeys in computer/crm/quote builder/dispatch/knowledge, outings' N and O keys, printer A/D/1-3/P, charselect X/T/M/B, toolbox seed typing, the 1-7 character switch); (2) check the feel of steering the chair race by pad; (3) a Roll button for seated chairs and a next-target button; (4) a touch overlay; (5) a text-size and tap-target pass for the `v` format (rows are 9-12 px, a thumb needs 19-24); (6) a seed picker instead of typing; (7) Android/iOS export presets and an aspect note; (8) Switch needs a licensed third-party port and a gamepad-only path | M |
| R15 | Brows following the hair colour; the weakest art (the 4 to 7 px hats, the 4x3 watch, the mini skirt, the jeans detail, the flat long sleeves). Scope notes: `docs/scope-character-creator-level2.md`, `docs/scope-character-creator-level3.md` | S |
| R16 | Cozy Easy is the Easy tier (`Difficulty.cozy_on()`); a separate cozy toggle apart from the tier is open. Resume point step 5: Playbook jobs, onsite state, owner / service / sales modes (`docs/scope-cozy-and-resume.md`). From the cozy design review, not built: office growth (decor unlocked by reputation, medals and cash), a today's-goal chip and next-up list on the HUD, a collection page (cast, songs, clue recipes, printers, medals), micro-session entries on the title menu, seasonal calendar events, cast relationship levels. Quit risks to check: the 75 s idle start on day 1, a C grade reading as failure on Easy, the day 2 commute penalty, week 2 piling on-call, no visible office change as a reward | M-L |
| R17 | No carry-over summary line on START YEAR 2 | S |
| R19 | No per-slot DELETE row | S |
| R21 | The warehouse fan blades do not turn | S |
| R23 | Sitting down in a conference session is still a card, not a seat | S |
| R26 | A real head turn (the art is side-on), couch gestures (arm over the back), a coffee-cup reach while typing | M |
| R28 | More forum characters (add a `CHARS` entry, an `Expo.FORUM` entry and a crowd row) | S each |
| R34 | **Couch co-op, phases 2 to 8**: the shared camera and tether, group door transitions, split-screen takeovers, Free Play co-op with a second look, campaign co-op, two-player outings; see `docs/scope-coop.md` | XL |
| R36 | **Clients who know your name**: direct texts to your cell and by-name ticket requests (ideas in `IDEAS.md`); needs a design pass first | M-L |
| R37 | **Later bundle**: owner campaign wire fraud and a post-incident review, cable tracing and a labelled patch panel (check the git log: may be built); a phone camera app | M each |
| R30 | Ramping dinner (it has no continuous numbers) | S |
| Q3 | The live-window part of the visual check | S |
| Q6 | More seeds per balance cell, owner hard, tech hard still wins with a careful bot (results in `docs/balance-notes.md`) | M |
| Q7 | **Realism review by a real MSP owner** of card text and numbers (W-2 target 55%, EBITDA peer margin 15%, valuation multiples, late-fee and leakage figures, turnover statistics) before any player-facing release. External: packet ready in [realism-review.md](realism-review.md), needs a human reviewer | S |
| P5 | Owner campaign leftovers: walking the owner trip in the venue, sitting in conference sessions, patchable `Projects.TYPES`, a balance run for the new content | S-M |
| P6 | Tuning of the heavy fixes and ransomware exits by bot playthrough (Q6) | S |
| H5 | Open `/hooks` once so the worktree hooks in `D:/Creative/.claude/` go live; clean up subagent worktrees (they are kept after an agent finishes) | S |
| H7 | Answer the open questions in `docs/campaign-paths.md` section 14 (crew size, day lengths, hires, parody names, Growth helper, walk-in scene). The game runs on the defaults as built | S |

## 3. Parked (decision or dependency needed)
| # | Item | Waiting on |
|---|---|---|
| P2 | Dialogue Manager addon (only for long branching NPC conversations) | a need; a half-day spike would confirm syntax first |
| P3 | Gitot in-editor git panel | optional |
| P4 | Real recorded or composed audio assets: replace the body of `Sfx.stream(id)` / `Sfx.music_stream(id)` with `load("res://assets/audio/<id>.ogg")`; callers do not change. Footsteps are defined but not hooked; no ambience or per-room music; no volume sliders (settings file only) | assets |

## 4. Ideas not scheduled (`IDEAS.md`)
Highlights: a yearly review in a real conference-room scene; more quiet-day story beats; phone dialer, banner, lock screen and camera; cable tracing and a spare laptop in the closet; owner-campaign collections calls, hardware refresh and warranty, security-stack upsells, contracts and insurance, a second-office phase; client onboarding as a project; time tracking; a reputation breakdown screen; seasonal events; an in-game glossary; a nightly balance harness; settings and credits and an animated logo.
MSP-research items still unbuilt (see `IDEAS.md` "From the MSP research"): revenue mix and managed security as a line, post-incident reviews, pricing models and more stack categories as owner decisions, the peer-group overhaul (assembled groups, quarterly meetings, hot seat, micro board, go-giver favours), and the training / operator items from the Dean and Empath notes that the service campaign does not cover (certification programs, operationalizing no, outsourced desk).
