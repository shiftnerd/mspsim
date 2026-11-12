# Gap audit: our docs and our game against the design document checklist

Audited 2026-11-12 on commit `2d16945` (branch `worktree-agent-a7abb105ec7120843`, merged up to `main`). Checklist: `docs/design/checklist.md`
(60 items, sections A to H). Rule used: an item is COVERED only if a file and a section were read and answer it; THIN means
something exists but a named part is absent; MISSING means nothing found (searched with Grep over `README.md`, `IDEAS.md`,
`CLAUDE.md`, `docs/*.md`, `docs/dev/*.md`, `docs/manual/*.md`, `godot/story/README.md`).

Tally: **15 COVERED, 36 THIN, 9 MISSING.** (Counted from the table below with a script.)

Marks: this audit states facts read from code. Anything "verified by reading, not run" is flagged. Nothing was played by a human.

## 1. The 60 items

| # | Item | Status | Where our docs cover it | What is absent |
|---|---|---|---|---|
| 1 | One or two sentence game and why fun | COVERED | `docs/GAME_BIBLE.md` section 1 "The pitch" (opening paragraph and "Why it should be fun") | Runs to three paragraphs; a true two sentence logline for the store page does not exist yet |
| 2 | Title that signals gameplay and style | THIN | `docs/dev/systems.md` "Logo + title screen" (the name and tagline); README cover box ("MSP Simulator") | "MSP" is jargon the likely buyer does not know; nothing says "pixel", "office" or "comedy"; no note on why the name was kept or the alternatives |
| 3 | Genre, fresh or tired | THIN | Bible section 1: "Papers, Please crossed with Overcooked" | No genre label (office sim? management? life sim?) and no argument about whether the niche is fresh |
| 4 | Audience, age rating, what the rating constrains | THIN | README cover box and `docs/manual/README.md` print "RATED E FOR EVERYONE" (a parody box, not a rating); `docs/replayability-ideas.md` section 6 "Things to avoid" (no punishment for family or health, no real brands) | No audience statement (who, what motivates them); no real rating (ESRB / PEGI / IARC) and no list of what it would constrain (violence is nerf darts and paintball; language; the 2013-14 jokes) |
| 5 | Market gap and comparables | THIN | Bible section 1 (two comparables in one sentence); `docs/msp-research.md` (domain research, not market) | No comparison table (Overcooked, Papers Please, Software Inc., Job Simulator, Two Point, Big Ambitions, Hardspace), no "what is different" per comparable, no named gap |
| 6 | The one defining mechanism | THIN | Implied by Bible section 1 "Several ways to play, one office"; `docs/replayability-ideas.md` section 1 "One dial, many consumers" (replay only) | Never stated. Candidates: "one office, four jobs, the same events seen from different chairs"; "decisions today come back as tickets tomorrow" (Bible sections 4, 6) |
| 7 | Familiar elements that lower the risk | MISSING | none (Bible section 1 names two games, not the familiar mechanics: tickets and queues, quota, grading, cards, mini-game nights) | The whole item |
| 8 | Role, point of view, fantasy, emotions | COVERED | Bible section 9 "What the player should feel"; `docs/campaign-paths.md` 3.1, 4.1, 5.1 (fantasy and pitch of owner, service, sales) | Point of view (side-on 2D, one screen) is not in the Bible; it is in `docs/dev/godot-basics.md` "Output formats + follow camera" |
| 9 | Pillars and what the game is NOT | MISSING | partial lists only: `docs/ROADMAP.md` "Decisions so far" (no Switch, Deck target, easy is cozy); `docs/replayability-ideas.md` section 6 (no leaderboards, no telemetry, no real brands) | Pillars are written nowhere. Non-goals are scattered in three places. Proposed text is in section 5 below (decision D-1) |
| 10 | Modes / levels and what unlocks each | COVERED | `docs/manual/03-game-modes.md` "At a glance", "Year 2", "Year 3"; manual 01 "The submenu and your slots"; code `Yeartwo.available` (a finished run of the mode) | Manual 03 says Year 2 needs a Tech or Owner run; the code allows all four modes (`Campaign.MODE_DEFS[*].year2 = true`). Corrected in section 2 |
| 11 | Objective and win condition of every mode | THIN | Tech: Bible sections 4 and 5; Owner: Bible section 7; Service and Sales: `docs/campaign-paths.md` 4.6, 5.4 (partly out of date, see issue I-12); Free Play: manual 03 | No single table; the player-facing manual says "does not tell you what happens". Table written in section 2, issue I-1 |
| 12 | Failure states and what follows | THIN | Bible section 4 step 5 ("At zero you are fired"); manual 01 "Cozy mode" | Bankruptcy, the service trust fail, the sales two-miss rule, and what follows each (the slot is deleted) are in no doc. See I-1, I-2, I-3 |
| 13 | Core loop at minute / session / game scale | THIN | Bible section 4 (ticket loop, day report, reputation) for tech; `campaign-paths.md` 3.3, 4.2, 5.2 for the others | Three scales never named; owner / service / sales loops live in a scope doc from before they were built |
| 14 | First 60 seconds and first 10 minutes | THIN | Bible section 5 day 1 row ("Welcome mail. Only one random ticket"); manual 01 "Switching it on", "Choosing your person"; code `Hints.DEFAULT_DAY1`, `Story.DEFAULT_DAYS[1]` | No document walks it. Step-by-step from the code is in I-4 |
| 15 | Worked example of a session | THIN | `docs/balance-notes.md` "The owner's 20 weeks as a trace (X9)" (a bot trace); Bible section 5 (one line per day) | No turn-by-turn example for any mode (what the screen shows, what the player picks, what the result is) |
| 16 | Goals, scoring, rewards, what is "enough" | THIN | Bible section 4 (grade S to D, reputation); `Career.DEFAULT_MEDALS` (72) in code; manual 03 "Career"; `Goals.goal()` (goal chip) | Grade formula (tech) not documented outside code and `campaign-paths.md` 4.6 (service weights); "enough to progress" (reputation 45 / 55 / 60 thresholds for the review offers) only in `Review.make_offers` |
| 17 | Difficulty tiers, what each changes, how tuned | COVERED | `docs/balance-notes.md` "What the tiers change" and "Tiers: every campaign x tier x strategy"; manual 01 "Difficulty"; `Difficulty.TIER_NOTES` | Only 12 of the 68 `Difficulty.TABLE` keys are listed in the table (the rest are per-game skill dials). See I-6 |
| 18 | Replay hook and content volume | THIN | `docs/replayability-ideas.md` (status: built); README "What is in the box" | No one-page volume count (cards, jobs, songs, medals). Fact sheet in section 5 |
| 19 | Session length and stopping points | THIN | manual 01 "The pause menu" (day length 5 / 10 / 15 minutes) and "Saving your game" | No total run length anywhere. Table in I-5 |
| 20 | List of systems, internal vs player-touched | THIN | `docs/dev/systems.md`, `docs/dev/godot-basics.md` (build history order), `CLAUDE.md` index | No systems map; the split "simulation / player facing" is not stated |
| 21 | Every object / NPC type with attributes | THIN | Bible section 3 (cast table, 11 clients); `docs/scope-labrat-nerds.md` (forum regulars); code `Msp.DEFAULT_PROBLEMS`, `Msp.FIXES` | Cast table lacks 8 people the code has (I-9); no ticket-type table (6 problems, 13 fixes), no printer model table (7), no client table with attributes |
| 22 | How NPCs behave, communicate, escalate | THIN | `docs/dev/godot-basics.md` "Characters interacting"; `docs/campaign-paths.md` 4.5 "Who answers to whom"; `docs/scope-bad-habits.md` (rival escalation); manual 04 | Ticket escalation (SLA, priority, owner last-resort help) is in `campaign-paths.md` section 6 only |
| 23 | Economy: earned, spent, sinks, limits | THIN | Bible section 7 (owner money); `docs/scope-shop.md` (tech shop); `docs/balance-notes.md` (owner results); `docs/realism-review.md` section 1 (the books) | No sources-and-sinks table across modes (tech pay and the NERDTHINK shop; owner cash and weekly draw; sales commission and clawback; service has no money) |
| 24 | Rules as short testable statements | THIN | 393 test scripts (`godot/tests/`) are the real rule list; Bible sections 4 and 6 state a few | No rules document; the tests assert rules but are not readable as design |
| 25 | Movement, physics, timing with numbers | THIN | manual 02 (keys); `Difficulty.TABLE` mini-game timings; `World.SPEED` 32, day 9:00 to 17:00 (code) | No numbers in docs for walking speed, jump, run, SLA windows by priority |
| 26 | Damage, consequence, recovery, how shown | THIN | Bible section 6 ("consequences return next morning"); `docs/balance-notes.md` "Tech reputation curves (T2)"; manual 05 (day report) | Reputation rules (`CLEAN_REP` 58, `SLOPPY_REP` 62, `TOP_REP` 90, scars, daily cap) are only in `campaign.gd` comments and balance notes |
| 27 | Randomness: where, seeded, bounded | COVERED | `Difficulty` header comment; manual 01 "The seed and the daily seed"; `docs/replayability-ideas.md` section 1; `docs/balance-notes.md` "The same seed, another game" (`tests/determinism.gd`) | Caveat: 65 named seeded streams but 66 bare `randf()` / `randi()` / `shuffle()` call sites remain (counted, section 5); `replayability-ideas.md` section 0 still says all randomness is global (history) |
| 28 | Every tunable number and where it lives | THIN | `docs/balance-notes.md` table; `Mutators.SCHEMA` header; `docs/dev/balance_baseline.json` | See I-6: 68 TABLE keys + 10 COZY + 14 mutator hooks, but 1,584 `const` lines and no index |
| 29 | Controls per device and feel | COVERED | manual 02 (keyboard, seated, Tab selection, gamepad, touch, Deck); README "Controls at a glance"; `docs/steam-deck.md` section 4 "Pad map"; `docs/dev/notes-controls.md` | "How it should feel" (input latency, coyote time, run vs walk) not written |
| 30 | Camera, view, HUD, popups, menus, map | COVERED | manual 05 "The HUD"; manual 04 "The map"; `docs/dev/godot-basics.md` "Output formats + follow camera"; README "Formats and the F9 key" (5 shapes) | none material |
| 31 | Front end: intro, menus, options, pause | COVERED | manual 01 "The title screen", "The pause menu"; `docs/dev/systems.md` "Title screen home menu (R40)"; `docs/dev/audio-creator.md` "Pause menu" | Manual 01 lists SETTINGS as "key lists, shape, sound, day length" but the code has DISPLAY and UNFOCUSED rows too (README has them) |
| 32 | Accessibility | THIN | `docs/steam-deck.md` section 1 (text size by arithmetic, no typing needed); `docs/dev/audio-creator.md` "no mechanic depends on sound"; cozy Easy (manual 01); remapping (manual 02) | No text-size option (ROADMAP R42 item 4 open; no `TEXT` row in the pause menu at this commit), no colour-blind or contrast pass, no reduced flash / screen shake review, no hold-vs-toggle, no accessibility statement. A 3x5 upper case font is the text size floor |
| 33 | Localisation and text volume | THIN | `godot/story/README.md` (strings.txt workflow); 136 patchable sections, 6,666 keys, 146,629 words (counted, section 5) | No localisation plan. `PixelFont.GLYPHS` is A-Z, 0-9 and 30 punctuation marks only: no accents, no non-Latin script. Text length per language not budgeted |
| 34 | Settings and what is saved | COVERED | manual 01 "Saving your game"; manual 08 "Where are my saves, on disk?"; `docs/dev/audio-creator.md` (settings file) | The settings file's full key list (format, fullscreen, focus, tier, day scale, ticket pace, volume, look) is not in one place |
| 35 | Setting, period, does story matter to play | COVERED | Bible section 2 "Tone and setting"; `docs/realism-review.md` section 5 "Period checks"; `ROADMAP.md` Decisions (2013-14) | none material |
| 36 | Tone, characters, voice | COVERED | Bible sections 2 and 3; `godot/story/README.md`; `docs/realism-review.md` section 6 | Cast table incomplete (I-9); no per-character voice sheet beyond one line each |
| 37 | Visual style, reference art, pixel and palette rules | COVERED | `CLAUDE.md` "Style", "Palette", "Layers", "Orientation"; `docs/dev/notes-art*.md` (8 files); `archive/` references | Rooms, UI and props have no style sheet (only characters have palette rules) |
| 38 | Audio style and plan | THIN | `docs/dev/audio-creator.md` "Audio (P4)" (synthesised sounds, lo-fi loop, rules); `ROADMAP.md` P4 parked | No audio direction (music style per room, ambience, footsteps are "defined but not hooked"), no plan for real assets, no volume sliders |
| 39 | Platforms, minimum hardware, engine, tools | THIN | README "What you need"; `ROADMAP.md` Decisions (PC first, Deck and handhelds, no Switch); `docs/steam-deck.md`; 4 export presets (Android, iOS, Linux Steam Deck, Windows) | Minimum and recommended hardware not stated (README says "a toaster"); Windows build not recorded as exported; `project.godot` features say 4.4 while the docs say 4.7.2 |
| 40 | Performance and memory budgets, fallback | THIN | `docs/steam-deck.md` section 7 "Frame time" (16.6 ms budget, measured per screen on a desktop) | No memory budget; the one over-budget screen (the metrics dashboard, 8 ms here) has no fallback decision; Deck numbers are estimates |
| 41 | Saving, persistence, old-save compatibility | THIN | `godot/scripts/save_migrate.gd`; `docs/replayability-ideas.md` section 6 ("version every new save section"); manual 01 | No save-format document, no list of section versions, no policy for how many releases an old save must load |
| 42 | Multiplayer / co-op and what is out of scope | COVERED | `docs/scope-coop.md` (sections 1 to 16), `docs/coop-risk-findings.md`, `ROADMAP.md` R34 and Decisions; online out: `replayability-ideas.md` section 6 | Out-of-scope list is spread over three files |
| 43 | Content and tooling pipeline | COVERED | `CLAUDE.md` (Aseprite pipeline, `tools/anim.lua`), `docs/dev/tools-tests.md` (`port_edit.py`, `check_generator.py`), `godot/story/README.md` (strings export) | none material |
| 44 | Build, test, release automation | THIN | `.github/workflows/tests.yml` (suite, lint, generator check, Linux export started 300 frames); `tools/run_tests.py`; `docs/dev/tools-tests.md` | No release process: no version number scheme, no release build or upload script, Windows export not in CI, no changelog |
| 45 | Store and platform requirements | THIN | `docs/steam-deck.md` sections 2, 9 and "The two published checklists, against the game" | No Steam store requirements list (capsule art sizes, trailer, rating questionnaire, tax / bank), no Steamworks setup, no Steam Input config, no achievements mapping (72 medals could be achievements) |
| 46 | Team, roles, owners of areas | MISSING | README Credits ("Ben and a very patient robot"); `docs/BACKLOG.md` "Housekeeping" (worktrees) | No roles table; the multi-agent workflow (coordinator, agents, rules) is not documented in the repo (it lives in session instructions) |
| 47 | Milestones with deliverables and dates | MISSING | `ROADMAP.md` (rows with S / M / L sizes, no dates) | Whole item. History facts: 573 commits from 2026-11-02 to 2026-11-12 (git log) |
| 48 | Schedule with test and balance time | MISSING | `docs/balance-notes.md` shows balance work done, not scheduled | Whole item |
| 49 | Budget and what happens if cut | MISSING | none | Whole item (money, but also agent / compute budget) |
| 50 | Cut list | THIN | `ROADMAP.md` section 3 "Parked", section 4 "Ideas not scheduled" | Not ranked as "what goes first"; no rule for cutting |
| 51 | Risk register with mitigation and test | THIN | `docs/scope-coop.md` 5.5, `docs/coop-risk-findings.md`, `campaign-paths.md` 4.8 / 5.6, `docs/scope-bad-habits.md` | Feature risks only. No project risks (no human playtests, repo public, likeness rights, Steam review, art volume, one-developer bus factor) |
| 52 | Test plan: automated, bots, playtest questions, what each milestone proves | THIN | `docs/dev/tools-tests.md`; `docs/balance-notes.md`; 299 default tests, 16 bot / balance harnesses; Bible section 10 "Review questions" | No playtest plan or questions; `BACKLOG.md` "Not covered by the playtest: days 6-20"; ROADMAP Q3 "a human playthrough is still the real test" and Q7 realism review open |
| 53 | Success measures | MISSING | none (the in-game METRICS app is player-facing) | Whole item (wishlists, reviews, completion rate, session length) |
| 54 | Marketing, store page, launch plan | MISSING | none (README says "private and in progress, not for sale") | Whole item |
| 55 | Business model and price | MISSING | none (`docs/scope-shop.md` is the in-game shop) | Whole item |
| 56 | Post-launch: patches, expansions, modding, sunset | THIN | `godot/story/README.md` (anyone can edit strings: a de facto text mod surface); Year 2 and 3 (no Year 4, `Yeartwo.LAST_YEAR = 3`); `IDEAS.md` | No patch cadence, no DLC / expansion stance, no mod support statement (what is moddable), no end-of-support statement |
| 57 | Legal and rights | THIN | manual 09 "Notices" (parody statement); `docs/realism-review.md` section 6 "Parody names"; `godot/story/banned_names.txt` and `tests/canon_text.gd` (enforced) | Not covered: likenesses of real people (CLAUDE.md "Characters" lists reference photos of real people for at least six characters, kept in `archive/`), real people's names as characters, licences of Aseprite / Godot / the 3x5 font origin, the repo is public (`tests.yml` header) while `ROADMAP.md` still says "private", trademark search for "MSPSim" and "Pixel IT Partners" |
| 58 | Decided vs proposed, marked | COVERED | `ROADMAP.md` "Decisions so far (user)"; `campaign-paths.md` section 14 "Decided by the user / Still open"; `replayability-ideas.md` "STATUS: built" | Not applied to every doc (BACKLOG "In progress" is stale; scope docs keep their pre-build tense) |
| 59 | Open items in view, with owner | THIN | `ROADMAP.md` section 2 "Open" | 16 of the 38 rows in "Open" say "Nothing open" (done rows kept); no owner or due column; `BACKLOG.md` "Needs a decision" is stale (the tier step and the section 14 questions are long answered) |
| 60 | Revision history, cross-references | THIN | Docs cross-reference well (`CLAUDE.md` "Where the rest lives", `ROADMAP.md` header); git history | No version or date header on `GAME_BIBLE.md`, README or the manual (only `steam-deck.md` is dated); no change log |

## 2. Issues in the GAME, not the docs

Verified in code unless marked. Each has an id used in section 3.

**I-1. Win and failure conditions are not stated in one place, and none is visible to the player.**
The player sees: the tier note under the difficulty picker (`Difficulty.TIER_NOTES`, mood only), the daily goal chip
(`Goals.goal()`, "CLOSE YOUR FIRST TICKET"), and REP on the HUD. The manual says it "does not tell you what happens". From code
(`Campaign.MODE_DEFS`, `Review`, `Owner.offers`, `Service.review_offers`, `SalesCampaign.offers`, `Yeartwo.DEFAULT_YEAR3`):

| Mode | Length | Success | Fail (normal / hard) | Year 1 endings |
|---|---|---|---|---|
| Tech | 20 days | reach day 20 with reputation 45+ for in-house or 55-60+ for team lead (`Review.make_offers`) | reputation 0 = fired (text "REPUTATION GONE. YOU ARE FIRED.") | lead, internal (best client), stay ("on notice" under 45); Year 2 adds head, clientbuy; Year 3 adds y3_chair, y3_senior, y3_farewell |
| Owner | 20 weeks | board review with a valuation | cash below -$3,000 (`Owner.BANKRUPT`) sets reputation 0 = "THE COMPANY IS BANKRUPT"; reputation 0 = "YOUR NAME IS MUD. THE COMPANY CLOSES" | sell, expand (cash 10k, rep 55, 6 clients), stay (or left / buyout / sellout with a partner rift); Year 2 merger, franchise; Year 3 y3_summit, y3_staff, y3_morgan |
| Service | 20 days | Morgan's confidence (rep) and both owners' trust | reputation 0 or both owners' trust under 20 (`Service.FAIL_TRUST`, not on Easy) | ops, alan, garrison, leave, stay; Year 3 y3_coo, y3_partner, y3_across |
| Sales | 20 weeks | quarterly quota (2 quarters), Garrison's trust | reputation 0 or bankrupt; two missed quarters = only offer is "CLEAN OUT YOUR DESK" (`SalesCampaign.pip_failed`) | director, stay, rollup, leave, let_go; Year 3 y3_director, y3_wes, y3_stake |
| Free Play | open | none | none | none |

**I-2. "Fired" deletes the save slot and gives nothing back.** `Campaign.report_continue(final)` with `_fired_out` skips the
review, removes the slot file (`DirAccess.remove_absolute(save_path(mode))`) and goes to the title. There is no retry from the
last day, and `Yeartwo.record` (the Year 2 unlock) only runs from `finish_campaign`, so a fired run unlocks nothing. Only Career
counters and medals survive. Normal and Hard only: on Easy rep floors at 15.

**I-3. Easy does not fully "never punish" (verified by reading, not run).** Cozy Easy (`Campaign._cozy_close`) floors reputation at 15,
turns bankruptcy into one $2,000 bailout (a second shortfall gets a gentle note and no consequence) and softens SLA, reopen and ransomware
numbers (`Difficulty.COZY`). `Service` skips the trust fail on Easy. But `SalesCampaign.pip_failed()` has no `cozy_on()` check, so two missed quarters
on Easy still end at the week 20 review with the single offer "CLEAN OUT YOUR DESK" (`tests/sales_campaign.gd:485` and
`tests/sales_hard.gd:77` only test normal and hard). Also, tech Easy at rep under 45 gets "ON NOTICE: PROVE YOURSELF NEXT YEAR", which is soft but is the only
Easy review text that reads as a penalty. The ROADMAP decision is "Easy is the cozy tier (never fired, nothing punishes you)".

**I-4. The first 60 seconds of a new tech campaign (from code).**
1. Title: press Enter, home menu (CONTINUE only with saves, NEW, FREE PLAY, QUICK PLAY, SETTINGS, QUIT) -> NEW -> TECH CAMPAIGN (`Title`, id `tech_new`). With saves, a submenu offers slots first.
2. `CharSelect.flow()` for tech: `create` (the creator opens straight in: START < MY LOOK >, pages LOOK / CLOTHES / SHOES / EXTRAS / WORK, the name is a letter grid) -> `phone` (IFONE 5 or NEXXUS 5) -> `tier` ("HOW HARD?", with the one-line note for tech) -> `options` ("SET UP THE RUN": LEVEL, START condition, SEED, TOOLS, MUT) -> `build` (point-buy skills and quirks). Five pages before the first frame of play.
3. `Campaign.new_game("tech")` resets 26 systems, takes the seed, and begins day 1 at 9:00 on the main floor (not seated: only cast-member modes start seated).
4. Real seconds on Normal (a 600 s day is 8 game hours, so 1 game minute = 1.25 s): 0 s the clock starts; 4 s hint "ARROWS OR A/D MOVE, HOLD SHIFT TO RUN, SPACE JUMPS" (`Hints.DEFAULT_DAY1`, one hint every 22 s: E uses things at 24 s, sit at a desk and open the computer 46 s, phone 68 s, tickets 90 s); 7.5 s Morgan's mail "Your first day" (9:10); 15 s Dan's mentor card (9:20) followed by the first-day "hello" card (three answers that set a small flag and a text next morning); 75 s the first ticket arrives (`Msp._spawn_t`, 20 s on Easy); the goal chip reads "OPEN THE COMPUTER AT YOUR DESK" until a ticket exists, then "CLOSE YOUR FIRST TICKET".
5. Day 1 has one random ticket (Bible section 5), so the first 10 minutes are: learn the keys, open the RMM, fix, close in the PSA, day report with a grade.
Gaps: no screen tells a new player what "winning" is, nothing explains the REP number on the HUD, and five setup pages come before play (ROADMAP R35 and the manual's "COMING SOON" note say this screen is being simplified).

**I-5. Real session lengths (clock time only, computed from `Campaign.MODE_DEFS.day_len` x `Difficulty.DAY_SCALES` 0.5 / 1 / 1.5).**

| Mode (normal day) | 20 days at DAY LENGTH short | normal | long | One day (short / normal / long) |
|---|---|---|---|---|
| Tech (600 s) | 100 min | 200 min | 300 min | 5 / 10 / 15 min |
| Owner (240 s) | 40 min | 80 min | 120 min | 2 / 4 / 6 min |
| Service (360 s) | 60 min | 120 min | 180 min | 3 / 6 / 9 min |
| Sales (240 s) | 40 min | 80 min | 120 min | 2 / 4 / 6 min |

Add the day report, cards (the clock stops while a card is open), outings (tech days 5, 10, 15; owner weeks 4, 9, 14, 19; each a few minutes) and the conference trip (day 17): a Normal tech run is realistically 4 to 5 hours, in 20 stopping points. The manual mentions only the tech day length (5 / 10 / 15 minutes) and never the total. The save is at every day end and a mid-day resume point is kept on pause or close, so stopping is safe at any time; the "natural" stop is the day report.
Year 2 and Year 3 reuse the same day lengths (the clocks that tighten are SLA windows, `Yeartwo`: SLA x0.76 in Year 3).

**I-6. Tunable numbers: where they live and what is scattered.**
- `Difficulty.TABLE`: 68 keys in 17 families (tech 11, grill 6, karaoke 5, bowl 5, escape 5, chair 5, corn 5, dinner 4, printer 4, darts 4, owner 3, sales 3, paint 2, crew 2, rep 2, nerf 1, service 1), each `[easy, normal, hard]`. `docs/balance-notes.md` lists 12 of them. `Difficulty.COZY` has 10 more; `MASTERY_KEYS` (29) tighten with play.
- `Mutators.SCHEMA`: 14 hook keys with validated ranges; 14 mutators and 5 starting conditions are data (`DEFAULT_MUTATORS`, `DEFAULT_STARTS`).
- 143 `DEFAULT_*` tables in scripts are patchable from `godot/story/strings.txt` (136 sections), so text and many numbers (medals, mutators, card options) can change without code.
- Not data, scattered as `const`: 1,584 `const` lines across 129 scripts, including the whole reputation curve (`Campaign.START_REP` 50, `CLEAN_REP` 58, `SLOPPY_REP` 62, `TOP_REP` 90 ...), `Owner.BANKRUPT` -3000, `Sales.MAX_CLIENTS` 8, meeting days, outing days, trip day, ticket pace by day (`Msp.pace` formula in `Campaign._begin_day`), wire fraud 3.5 percent in `Incident`.
- No live tuning panel exists (the Free Play toolbox picks games, seeds and mutators, not numbers). Bots (`tests/bot_lib.gd`, `balance_baseline.json`, 25 cells) are the only measurement tool.

**I-7. Pillars and non-goals are not written** (checklist 9). Proposed text is in section 5, D-1.

**I-8. Docs out of date against the code** (each verified):
- Manual 03 "Year 2": "Finish a Tech or Owner campaign" - the code allows all four modes (`MODE_DEFS year2 = true`; ROADMAP R10 says sales and service are open).
- Count of games: README "Nine team games" (9 `Outings.GAMES`: bowling, karaoke, escape, dinner, chair, cornhole, grill, paintball, darts); manual 06 subtitle "Seven ways to spend an evening ... and one quick game" while its own table lists eight; `docs/steam-deck.md` "all 11 mini-games" (those 9 plus the printer and the nerf war = `Toolbox.GAMES`).
- Manual 01 pause menu table omits CAREER and FREE PLAY MENU (Free Play) and SETTINGS omits DISPLAY and UNFOCUSED.
- Bible section 5: outings are named on days 5 and 15 only, the code has three (`Outings.TECH_DAYS` 5, 10, 15) plus lunch breaks (days 3, 7, 12, 17).
- Bible section 11 "Not built yet" lists sitting in the Rodent Nation sessions and walking the owner trip in the venue: both built (ROADMAP R23).
- Bible has no Year 3 and no Year 2 / 3 endings (12 Year 3 endings, 4 Year 2).
- `docs/campaign-paths.md` 4.6 and 5.4 name endings the code does not have (service "IN-HOUSE IT AT A CLIENT", "STAY ON PROBATION"; sales "EQUITY OFFER"); section 14's seven open questions were settled by building (ROADMAP H7 asks the owner to confirm).
- `docs/BACKLOG.md` "In progress" ("Next up: X2") and "Needs a decision" (tier step, Dialogue Manager) are stale.
- `docs/ROADMAP.md`: R42 row says glyphs "built" and also lists glyphs as open item (1); the C3 sentence about the week 12 new-hire beat appears twice; Decisions say the repo is private, `tests.yml` says public; "Done" rows kept in "Open" (16 of 38).
- README "FOR TINKERERS" calls `CLAUDE.md` "the long technical notes" (it is now short; the notes are in `docs/dev/`, not listed). CLAUDE.md says "56 people" for the animation build; `sprites/` holds 75 right-facing characters (staff 19, clients 22, expo 24, custom 10).
- README cover "RATED E FOR EVERYONE" is a joke box and reads like a claim; "PRIVATE BETA, not for sale" conflicts with a Steam plan.
- A `TEXT` size setting is not in this commit (`PauseMenu._labels`); the owner mentions one: the manual and Deck docs need a pass when it merges.

**I-9. Canon contradictions (checked).** Canon in the code and ROADMAP agrees on: Alan and Garrison owners; Morgan Reyes manager; Christy controller; John Marlowe account manager; Maya tier 1; 2013-14. No contradiction on those. Remaining wobbles: `sales_vic_*` sprites and `Talk.VIC_*`, `Lync.VIC_*` tables keep the old name internally (fine, but the exported strings keys say VIC); the Bible cast table omits Jen, Michael, Christy-in-tech, Adam, Quinn, Sam, Terry, Wes, Ross Calder, Ms. Pell, Trent Dagmar (World.CAST has 6, CREW_CAST 2, STAFF_CAST 5); the Bible says Christy appears in owner mode, the code seats her in the tech campaign too (`World.STAFF_CAST`).

**I-10. Randomness is mostly seeded but not fully.** 65 named streams via `Difficulty.rng`, `tests/determinism.gd` proves the same seed gives the same game in all four campaigns; 66 bare random calls remain (outings 12, nerds 9, world 8, lync 8, talk 7 ...). They are cosmetic (chat, NPC walks) by test, but the docs promise "the same seed gives the same dice".

**I-12. Real-people likenesses and a public repo (legal, not a design bug).** `CLAUDE.md` "Characters" says several characters are drawn from photos of real people
(a teenage photo of the author, a staff headshot, Alan, Garrison) and keeps those photos in `archive/`. `tests.yml` says the repository is public.
This needs the owner's decision before a store page (D-5).

**I-13. No human has played days 6 to 20 of the tech campaign.** `BACKLOG.md` "Not covered by the playtest: days 6-20"; Q1 and Q2 were hand play of day 1-5 (tech) and 20 owner weeks; every later check is a bot. Balance numbers rest on the bot's overhead assumption (`balance-notes.md` "Open": the careful bot is slower than a good human).

**I-14. Difficulty is invisible on the title and character select beyond one mood line.** `Difficulty.TIER_NOTES` says what a tier "feels like" but not what it changes (fired or not, ticket volume). The manual says "tighter windows" for Hard.

## 3. Proposed roadmap rows (do not edit ROADMAP.md; for the coordinator)

| # | What is open | Size |
|---|---|---|
| D1 | Write `docs/design/pillars.md` (3 to 5 pillars, non-goals) and link it from README and the Bible. Needs owner decision D-1 | S |
| D2 | A "How to win" screen: one in-game page per campaign (objective, failure, endings) reachable from the character select tier step and the pause menu, text in `strings.txt` (I-1 table is the content) | M |
| D3 | Fix Easy in the sales campaign: no "CLEAN OUT YOUR DESK" ending under `Difficulty.cozy_on()` (probation line and the normal offers instead); add an Easy case to `tests/sales_hard.gd` or `tiers_balance.gd` (I-3) | S |
| D4 | Decide and implement what "fired" leaves behind: keep the last day's save as RETRY FROM DAY n on Normal, or say so on the fired report; and say what unlocks Year 2 (I-2) | S |
| D5 | Update the manual and README for I-8: Year 2 for all modes, the game counts (9 outing games, 11 mini-games), pause and settings rows, SETTINGS DISPLAY and UNFOCUSED, a total run length table (I-5), README Tinkerers table (docs/dev, docs/design) | S |
| D6 | Refresh stale design docs: GAME_BIBLE sections 5, 11 and cast table plus a Year 2 and 3 section; campaign-paths 4.6 and 5.4 endings; BACKLOG In progress and Needs a decision; ROADMAP R42 contradiction, duplicate C3 sentence, move "Nothing open" rows to Done | S |
| D7 | Tuning index: generate `docs/design/tuning.md` from `Difficulty.TABLE`, `COZY`, `Mutators.SCHEMA` and the main `Campaign` / `Owner` constants (script in `tools/`, so it cannot go stale) | M |
| D8 | Seed the 66 bare random call sites that touch game outcomes, or document which are cosmetic (I-10) | S |
| D9 | Accessibility pass: text-size option (R42 item 4), contrast and colour check of the five formats, reduce-flash review, a written accessibility statement (checklist 32) | M |
| D10 | Localisation decision: either state "English only" or plan: extend `PixelFont` beyond A-Z (accents), text-length budget, export of `strings.txt` per language (checklist 33) | M |
| D11 | Legal pass (needs a lawyer or at least owner decision D-5): likeness consent for the real-person characters, move reference photos out of the public repo, name search for "MSPSim", tool and font licences list | M |
| D12 | Human playtest plan: a 10-question sheet per campaign, five testers, days 6-20 of tech first (I-13); Q7 realism reviewer in the same round | M |
| D13 | Production documents: milestones with dates, cut list ranked, risk register (project level), success measures, store page copy, release checklist and version scheme (checklist 44, 47-50, 53-55) | L |
| D14 | Save-format document with section versions and the old-save policy (checklist 41); put the list of settings-file keys beside it | S |
| D15 | Steam store requirements checklist and achievements mapping of the 72 medals (checklist 45) | S |

## 4. Decisions we need from the owner

Each with our recommended answer.

| # | Question | Recommended answer |
|---|---|---|
| D-1 | Pillars (settle arguments) | 1. **The office is the toy**: every system should be poked, not just used. 2. **Decisions come back**: a choice today is a ticket, a card or a joke tomorrow. 3. **Funny, not punishing**: pressure is comic, Easy never punishes, failure is explained. 4. **2013-14, exactly**: period and parody names are the style. 5. **Playable on a pad, in short sittings**: every screen works with a pad, every day is a stopping point. Non-goals: no online, no telemetry, no real brands or songs, no AI / Slack / Windows 10 era, no combat game (nerf and paintball are party games), no Switch for now |
| D-2 | Age rating and audience | Target an everyday adult-and-teen "E10+ / PEGI 7" level (cartoon dart and paintball play, workplace banter); audience: people who work in or near IT, and fans of cozy management and Overcooked-style party games. Run the IARC questionnaire on the store page. Remove "RATED E" from the README cover or mark it as the parody box it is |
| D-3 | Price and business model | A single paid PC release at about $9.99 to $14.99, no DLC at launch; keep Year 2 and 3 in the base game. Reassess after the first review round. No free-to-play, no ads |
| D-4 | Platforms for launch | Windows and Steam Deck (Linux build, in CI) first; macOS and Linux desktop only if the Deck build runs; mobile and Switch stay parked |
| D-5 | Likenesses and the public repo | Make the repo private again (or remove `archive/` photos from it) before any store page; get written consent from each real person, or re-caricature past recognition and rename |
| D-6 | Playtest before launch? | Yes, at least days 6 to 20 of tech by two humans and one owner week; the bots cannot judge fun. Add the Q7 realism reviewer in the same window |
| D-7 | Localisation | English only at launch; say so on the store page; keep `strings.txt` as the text source in case |
| D-8 | Launch scope | Freeze content; spend the next period on playtest findings, accessibility (D9), the how-to-win screen (D2) and the store page. Cut list order proposed: more forum characters, mutator sound, second-office phase, new mini-games |
| D-9 | Name: keep "MSPSim"? | Keep as the working title; add a plain subtitle on the store page ("an office sim about IT support in 2013"); do a name search |
| D-10 | Settle campaign-paths section 14 (ROADMAP H7) | Accept the built defaults (crew size, day lengths, parody names) and close the row |

## 5. Facts to carry into the new documents

All counted on commit `2d16945`. "How" says how to recount.

| Fact | Value | How counted |
|---|---|---|
| Campaigns | 4 (tech 20 days, owner 20 weeks, service 20 days, sales 20 weeks) + Free Play / Film Mode + Quick Play (2 micro modes: one outing, one ticket shift) + Career | `Campaign.MODE_DEFS` (4 rows, all `selectable`), `Micro.OUTINGS` |
| Years | 3 (Year 2 and 3 for all four modes; no Year 4) | `Yeartwo.YEAR` 2, `LAST_YEAR` 3 |
| Tiers | 3 (EASY = cozy, NORMAL, HARD) | `Difficulty.TIERS` |
| Run length (normal, clock time) | tech 200 min, owner 80, service 120, sales 80 (x0.5 / x1.5 with DAY LENGTH) | section 2 I-5 |
| Day clock | 9:00 to 17:00 | `World.DAY_START`, `DAY_END` |
| Save slots | 3 per campaign | `Campaign.SLOTS` |
| Mini-games | 11 (bowling, karaoke, escape room, dinner, printer, nerf war, chair race, paintball, cornhole, cookout, darts) | `Toolbox.GAMES`; 9 are outings (`Outings.GAMES` keys) |
| Outing schedule | tech days 5, 10, 15; owner weeks 4, 9, 14, 19; lunch breaks tech 3, 7, 12, 17, owner 2, 7, 12, 17; conference trip tech day 17 | `Outings.TECH_DAYS`, `OWNER_WEEKS`, `LUNCH_TECH`, `LUNCH_OWNER`, `Expo.TRIP_DAY` |
| Karaoke songs / escape themes / printer models | 4 / 4 (study, server, detective, lab) / 7 (laser, inkjet, plotter, mfp, receipt, dot, line) | `Outings.DEFAULT_SONGS` ids, `DEFAULT_ESCAPE_THEMES` keys, `PrinterGame.MODELS` keys |
| Chair race events | 3 (straight, gauntlet, fight) | `Outings.CHAIR_EVENTS` |
| Cast (people on the team) | 6 core (Alan, Garrison, Dan, John, Maya, Morgan) + 2 crew (Sam, Terry) + 5 staff (Jen, Michael, Christy, Adam, Quinn) | `World.CAST`, `CREW_CAST`, `STAFF_CAST` |
| People with sprites | 75 right-facing files: staff 19, clients 22, expo 24, custom 10 (each has left, still and animation files) | `ls sprites/<group> \| grep -c _right.aseprite` |
| Clients | 11 (8 signed at once) | `Msp.CLIENTS` entries, `Sales.MAX_CLIENTS` |
| Client site types | 6 (dental, law, vet, architect, realty, trailer yard) in two looks | `scenes/site_*` (40 scenes) |
| Scenes | 68 .tscn: 40 client-site rooms, 28 others (about 25 rooms + title, player, npc) | `ls godot/scenes` |
| Ticket problem types / fixes | 6 base problems (printer, lockout, slow, blue screen, pop-ups, server down), 13 fix ids | `Msp.DEFAULT_PROBLEMS`, `Msp.FIXES` |
| Playbooks (big jobs) | 8 in `Playbook.DEFAULT_BOOKS` (rack, migration, email24, rdp, ceofraud, no2fa, bus, netinstall); the `strings.txt` section lists 14 ids (the rest are takeover books, not individually checked) | `DEFAULT_BOOKS` keys; strings.txt `Playbook > BOOKS` |
| Card decks (distinct entries in strings.txt) | Owner.CARDS 53, Events.DECK 41, Story.VIGNETTES 33, RivalCards 32, Nerds.THREADS 81, Nerds.AMBIENT 36, Service.RUNBOOKS 12, Service.BEATS 7, OwnerOps.LEADS 10, Habits 14, Mutators 14, Seasons.CARDS 8, OwnerCast 6, Postmortems 4 | `[Section.Table.<id>...]` keys of `godot/story/strings.txt`, unique third segment |
| Medals / unlocks | 72 / 41 | `Career.DEFAULT_MEDALS`, `DEFAULT_UNLOCKS` `"id"` count |
| Mutators / starting conditions | 14 / 5 (standard, messy, only_tech, rival, family) | `Mutators.DEFAULT_MUTATORS`, `DEFAULT_STARTS` |
| Habits / rival habits | 14 good habits, 17 rival habit entries | strings.txt `Habits.HABITS`, `Rival.HABITS` |
| Creator | 10 hairstyles; 2 phones (iFone 5, Nexxus 5) | `Look.HAIR_STYLES`, `CharSelect.PHONES` |
| Formats | 5 (wide 368x128, h 320x180, deck 320x200, v 180x320, vclose) | `Game.ORDER` |
| Platforms | export presets: Windows Desktop, Linux (Steam Deck), Android, iOS (stub ids); PC and Deck are the targets; no Switch | `godot/export_presets.cfg`, ROADMAP Decisions |
| Engine | Godot 4.7.2 (GL Compatibility); `project.godot` features string says 4.4 | `project.godot`, README |
| Scripts | 129 `.gd` files, 90,657 lines in `godot/scripts`; generator `tools/make_godot.py` 83,978 lines | `cat godot/scripts/*.gd \| wc -l` |
| Tests | 393 test scripts (69,180 lines); 299 in the default suite; 122 `*_shots.gd`; 16 `bot_*` / balance scripts | `ls godot/tests`, `python tools/run_tests.py --list [--all]` |
| Story text | 136 patchable sections, 6,666 keys, 26,939 lines, 146,629 words in `godot/story/strings.txt`; 143 `DEFAULT_*` tables in scripts | `grep -c "^# =====" strings.txt`; keys = lines matching `^\[[A-Za-z]`; `wc -w` |
| Font | `PixelFont` 3x5 upper case: 26 letters, 10 digits, 30 marks | `PixelFont.GLYPHS` |
| Seeds | 6 hex characters; daily seed; 65 named streams | `Difficulty.SEED_MASK`, `rng("...")` names counted with grep |
| Difficulty dials | 68 `TABLE` keys, 10 `COZY` keys, 29 `MASTERY_KEYS`, 14 mutator hook keys | `difficulty.gd`, `mutators.gd` |
| Documents | `docs/*.md` 19 (incl. the two design files), `docs/dev/*.md` 32, `docs/manual/*.md` 10 (9 chapters + README; `img/` has 22 files), README, IDEAS, CLAUDE.md, `godot/story/README.md`; about 10,300 lines in all of these | `wc -l` over the named files |
| History | 573 commits, 2026-11-02 to 2026-11-12, one author | `git log` |
| Ending sets | Year 1: tech 3, owner 3 to 6, service 5, sales 5; Year 2: tech 2, owner 2; Year 3: 3 per campaign (12) | `Review.make_offers`, `Owner.offers`, `Service.review_offers`, `SalesCampaign.offers`, `Yeartwo.DEFAULT_YEAR2 / YEAR3` |
| Canon | Alan and Garrison owners; Morgan Reyes manager; Christy controller; John Marlowe account manager; Dan service tech / manager (service campaign); Maya tier 1; Pixel IT Partners; set in 2013 to spring 2014 (XP ends 8 April 2014) | Bible sections 2 and 3, ROADMAP Decisions |

## 6. Top ten findings (for the coordinator)

1. Pillars and non-goals do not exist (items 9, 7).
2. No document or screen states win and fail per mode; I-1 table is the first (items 11, 12).
3. "Fired" deletes the slot and unlocks nothing (I-2).
4. Easy is not fully cozy in sales: two missed quarters still end at "CLEAN OUT YOUR DESK" (I-3).
5. No audience, rating, price, store, marketing, success or business documents (items 4, 45, 53 to 55).
6. Production documents missing: team, milestones, schedule, budget, cut list order, project risk register (items 46 to 51).
7. Real-people likenesses plus a public repo are unaddressed (item 57, I-12).
8. No human has played days 6 to 20 of tech; balance rests on bots (I-13).
9. Docs drift: manual Year 2 sentence, game counts (seven / nine / eleven), Bible sections 5 and 11, campaign-paths endings, stale BACKLOG, ROADMAP R42 (I-8).
10. Accessibility and localisation are thin: no text-size option, 3x5 A-Z-only font (items 32, 33).
