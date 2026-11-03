# MSPSim roadmap

The one ordered list of everything planned. Detail lives elsewhere: bugs and gaps in `docs/BACKLOG.md`, the long idea lists in `IDEAS.md`, the replayability write-up in `docs/replayability-ideas.md`, the new-campaign design in `docs/campaign-paths.md`, system documentation in `CLAUDE.md`.
Effort: S under a day, M 1-3 days, L a week or more. Status: DONE, NOW (an agent is on it), NEXT (decided, queued), PLANNED, PARKED (waiting on a decision or a dependency).

## Decisions so far (user)
- Alan and Garrison are the two owners of Pixel IT Partners (Alan technical, Garrison sales and culture). Morgan Reyes is the manager and **a real cast member**. Marge bookkeeper, Vic account manager.
- Owner campaign is played as **Alan or Garrison**; the other is the co-owner NPC. Owners take a **weekly draw from the bank balance**.
- Service manager campaign is played as **Dan**. Sales campaign is played as **Vic**.
- In the tech campaign the owners are busy and jump in **as a last resort** (phones, clients); stepping in **costs no reputation**.
- Difficulty tiers and seeded randomness are wanted; point-buy stats at character select are wanted.
- Parody names for products whose UI we imitate (Sugar Smash, Floppy Bat, iFone, Nexxus, Lynk, Googol); Apple, Windows, Exchange and PowerShell stay as era context.
- Dialogue Manager addon: skip for now. Gitot: optional.
- Decided and done: the **canon text pass** (Alan and Garrison recast as owners in dialogue, tips, Lynk, vignettes, review, outings; see CLAUDE.md "Canon: the owners").

## 1. Done
Tech and owner campaigns playable end to end; Free Play; the outing rooms and four mini-games; client sites and onsite visits; printer game; nerf war; character select; day report redesign; parody brand names; extra valid fixes for every ticket type; one shared outing UI; site polish round 1 and 2; tech playtest bug fixes (13); owner playthrough fixes round 1 (clock freeze while a card or outing is open, week-20 settle, valuation history, Vic's install as a job, named prospect and discount, phone texts and keyboard); the canon text pass (Alan and Garrison as owners); Difficulty autoload with seeded random streams and an easy / normal / hard choice; the repo on GitHub (private) with worktree hooks; research on Dialogue Manager and Gitot; the replayability and new-campaign design documents; a full 20-week owner playthrough; owner round 2 (X1: start cash, hire wage ramp, growing overhead, maturity gated by week, Vic complaint spread, Dana no-repeat, meeting upside, leak/cash consistency, REVIEW DUE, one Esc, invite cost, owner NPC E priority); the canon text pass (P1: Alan and Garrison as owners in Talk, Lynk, vignettes, review quotes, outings invitations and labels; the owner campaign and the last-resort rule are left for X4 / X6); X1 (owner balance, the smaller items and the UX fixes); X2 and X3 (player as a cast member, Morgan Reyes in the cast); R2 (printer variety: six models, 34 questions).

## 2. Now
Running in worktrees: R3 / R4 / R6 (karaoke songs, escape-room recipes, dinner variety), R7 (career screen, medals, nerf scoring), R8 (event deck and vignette deck), Q1 (live tech playthrough, days 6-20). Next: X4 (owner campaign as Alan or Garrison), then X5, X6, X7, X8.

## 3. Next (decided, in order)
| # | Item | Size | Depends on | Source |
|---|---|---|---|---|
| X4 | **Owner campaign as Alan or Garrison** (O1): speaker / text pass on `Owner.CARDS` (the 15 advisor cards from "Alan" and their "techs" wording, the "relative to a senior tech" hire-card line), replace the owner character select that wrongly offers "ALAN - ON SITE" with Alan or Garrison, crew re-base, partner NPC, personal goals, owner edges, **weekly owner draw from the bank balance** | M | X2, X3 | campaign-paths 3 |
| X5 | **Partner model** (O2): stance chips on cards, four partner-meeting beats, buyout / sell-together endings | M | X4 | campaign-paths 3.4 |
| X6 | **Tech campaign owners** (T1): last-resort rule (phones, clients; free, report row only), ASK THE OWNER lifeline (today owners still fix your oldest simple ticket when asked), `DESK_OWNER` / desk-ticket plumbing for desks 6 and 7, owner-style Talk / Lynk lines, Garrison as outing inviter | S-M | X2 | campaign-paths 6 |
| X7 | **Point-buy character build** (B0): third step on character select, budget by difficulty tier, presets, guards, saved build with a flat default for old saves; per-path stat sets | M + S per path | X2, Difficulty | campaign-paths 13 |
| X8 | **Split `Owner.active()` / mode registry** (P0b): crew, books and cards gates separate so autopilot crew can run in other campaigns | M | X4 | campaign-paths 10 |

## 4. Planned: new campaigns
| # | Item | Size | Notes |
|---|---|---|---|
| C1 | **Sales campaign as Vic** slice 1 (S1): 20-week skeleton, weekly report, leads as cards, visits, quote card | M | needs X8 |
| C2 | Sales: SalesHound CRM app, deals with promises, quote builder gauges, handover scene, 90-day churn, clawback (S2) | L | |
| C3 | Sales: beats 1-20, rival, renewals, approvals, endings (S3) | M | |
| C4 | **Service manager campaign as Dan** slice 1 (V1): Dan at his desk, huddle card, scorecard, autopilot crew, hands-on, 1:1 deck, owner memos | M | needs X8 |
| C5 | Service: `Crew` model, Dispatch board, Capacity view, NPC stuck / overload / quit (V2) | L | |
| C6 | Service: runbooks, desk design, hiring for fit, onboarding playbook, retention events (V3) | L | |
| C7 | Service: beats 1-20, owner-conflict memos, endings (V4) | M | |

## 5. Planned: replayability (`docs/replayability-ideas.md`, `IDEAS.md`)
| # | Item | Size | Notes |
|---|---|---|---|
| R1 | Difficulty and seeds | S | DONE (see section 1); still to do: a seed field you can type, saved stream positions, seeded `Msp` / `Owner` / `World` / `Onsite` randomness, hard-tier numbers checked by play, whether the tier deserves its own step instead of the chip on the select screen, drop the unused `ESCAPE_TIME` constant |
| R2 | Printer variety: DONE (6 models, 34 tagged questions, jam chains, tired, per-model prayers and streak, practice seed; see CLAUDE.md "Printer variety"). Left: P4 boss line printer, P6 parts bag | S-M | |
| R3 | Karaoke songs: four invented-title songs, hold and double notes, crowd-mood meter, duets, set lists | M | |
| R4 | Escape room: clue recipes, random clue spots, 4-digit hard code, red herrings, friend hints; later themed rooms | M | |
| R5 | Who comes along: `Outings.roster()`, bowling personalities, dinner tastes; Maya and Vic join in logic | M | pairs with X2 |
| R6 | Dinner: 16+ topics, mood of the day, dietary quirks, a client at the table, owner pays | S-M | |
| R7 | Career screen and medals, cosmetic unlocks, nerf-war scoring | M | |
| R8 | Event deck (40 cards) and vignette deck (24) | M | DONE (`Events` autoload, 41 cards + 17 drawn vignettes, see CLAUDE.md "Event deck and vignette deck"); left: seasonal tags beyond day windows, a Career counter, mutator hooks (R9) |
| R9 | Mutators (Heartbleed week, XP end of life, flu season...) and starting conditions | M | |
| R10 | Year 2 / New Game+, daily seed, Free Play toolbox | L | after R8, R9 |
| R11 | Bowling oil / spin / alleys / league; nerf modes and arenas; conference-trip randomisation; onsite job variance and dispatch roulette | M each | later |

## 5b. Planned: testing and quality
| # | Item | Size |
|---|---|---|
| Q1 | Live playthrough of the **tech campaign days 6-20** (only days 1-5 were played): the day-9 ransomware, overtime night, review, Rodent Nation trip, outings on days 10 and 15 | M |
| Q2 | Hand-play **owner weeks 12-20** (the last playthrough auto-picked them) and re-run after X1 / X4 | M |
| Q3 | A live-window visual check of changes only seen in screenshots or tests: the CLOSE confirmation strip and wider mail list, the new day report, the difficulty chip on character select, the dinner list at h, all 12 site offices, hard-tier feel for each mini-game | S-M |
| Q4 | Fix the test harness gap: mouse clicks map off-screen in a hidden window, so agents drive the UI through `run_script`; find a way to click for real | S-M |
| Q5 | DONE (X2): the ghost kept its seat, meetings and Social weight; Free Play now removes the cast member like a campaign. | S |
| Q6 | Balance by playthrough: alt-fix return chances and time multipliers, difficulty tiers, the early and late owner game (see X1) | M |
| Q7 | **Realism review by a real MSP owner** of card text and the numbers (W-2 target 55%, EBITDA peer margin 15%, valuation multiples, late-fee and leakage figures, turnover statistics) before any player-facing release | S (external) |
| Q8 | Test the worktree hooks through the real Agent tool (`isolation: "worktree"`) once `/hooks` has been opened | S |

## 6. Planned: content and systems from `IDEAS.md`
Not scheduled; pick as the campaigns above land. Highlights: yearly review in a real conference-room scene; more quiet-day story beats (days 6, 8, 11, 14, 17, 19); phone dialer, banner, lock screen, camera; cable tracing and a spare laptop in the closet; coworkers inviting you to things; settings and credits, music and an animated logo; owner-campaign candidate interviews, collections calls, hardware refresh and warranty, security-stack upsells, contracts and insurance, a second-office phase; client onboarding as a project; time tracking; documentation and bus factor; reputation breakdown screen; seasonal events; an in-game glossary; a nightly balance harness; side views of pieces exported to Godot (a per-prop `angle` setting).
MSP-research items still unbuilt (see `IDEAS.md` "From the MSP research"): documentation and bus factor, business email compromise / wire fraud in the owner campaign, revenue mix and managed security as a line, post-incident reviews, service desk design and pricing models as owner decisions, more stack categories, the peer-group overhaul (assembled groups, quarterly meetings, hot seat, micro board, go-giver favours), and the training / hiring / operator items from the Dean and Empath notes (certification programs, onboarding without a runbook, hire for fit, operationalizing no, outsourced desk, shadow versus structured onboarding).

## 7. Parked (decision or dependency needed)
| # | Item | Waiting on |
|---|---|---|
| P2 | Dialogue Manager addon (only for long branching NPC conversations) | a need; a half-day spike would confirm syntax first |
| P3 | Gitot in-editor git panel | optional |
| P4 | Audio: music, UI sounds, ring tones | design and assets |
| P5 | Owner campaign leftovers: Maya as the first hire, an owner Rodent Nation, sitting in conference sessions, more onsite jobs and projects | after X4 |
| P6 | Onsite requirement for heavy ticket fixes, ransomware alternatives, clever fixes in Free Play (alt-fix balance itself is Q6) | a design call |

## 8. Housekeeping
| # | Item | Size |
|---|---|---|
| H1 | Rerun `tools/make_godot.py` in a scratch copy and diff against `godot/`: it has been hand-edited in lockstep for many rounds | S |
| H2 | Decide what to do about the ~270 `.import` files Godot rewrites on open (commit once or ignore) | S |
| H3 | Add `.gitattributes` (`* text=auto eol=lf`) to stop line-ending warnings | S |
| H4 | Give each test its own save prefix so tests can run in parallel | M |
| H5 | Open `/hooks` once so the worktree hooks in `D:/Creative/.claude/` go live; clean up subagent worktrees (they are kept after an agent finishes) | S |
| H6 | gdlint: a `max-returns` error on `Outings.hint` | S |
| H7 | Answer the open questions in `docs/campaign-paths.md` section 14 (crew size, day lengths, hires, parody names, Growth helper, walk-in scene) | decisions |
