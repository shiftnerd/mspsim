# Scope, milestones, risks and tests

The production half of the design documents (checklist items 44 to 57). Written 2026-11-12 on top of `gap-audit.md`
(a dated snapshot) and `systems-reference.md` (generated). **Decided** by the owner on 2026-11-12: pillars and non-goals as
written in gap-audit D-1; the cast stay caricatures of real people with real first names for now (revisit before any store
page); audio is ON HOLD; Switch is dropped; Steam Deck and ROG Ally are targets; the repository is public. **Everything
else here is PROPOSED.** Dates are OPEN; milestones are ordered by prerequisite only. Row ids (R42, Q7, D9 ...) point to
`docs/ROADMAP.md` and gap-audit section 3.

## (a) Status of the build today

Verified 2026-11-12: `gh run list` shows the `tests` workflow green on `main` for commit `2d16945` (jobs `gate`, `suite`, `export`
all success, 14 min 21 s). Earlier runs on 2026-11-11 include several failures and cancellations (causes not reviewed here: OPEN).

| Area | State | Needs hardware or a human |
|---|---|---|
| Four campaigns, Years 1 to 3, Free Play, Quick Play, Career | Built end to end; bots finish every campaign x tier (`docs/balance-notes.md`, roadmap Q6, R10) | Human play of tech days 6 to 20 (BACKLOG, gap-audit I-13) |
| 11 mini-games, 9 outings | Built and tuned by bot | Feel on a real pad |
| Couch co-op (R34) | Phases 1 to 8 built, 3-hour windowed soak passed | Two humans, rumble, pace tuning |
| Steam Deck and handhelds (R42) | Pad-only play, 1280 x 800 `deck` format, glyphs, suspend and focus all proven by tests on a PC (`docs/steam-deck.md`) | A Deck, an Ally, a physical pad, Steam Input, the Valve review |
| Linux export | Builds in CI and the exported game starts for 300 frames headless with no logged errors | Playing it on Linux or a Deck |
| Text and numbers | 549 cards and beats and 146k words are first drafts; realism packet ready (`docs/realism-review.md`) | The owner's edit pass; a real MSP owner (Q7) |
| Audio | Synthesised sounds and a lo-fi loop; ON HOLD (P4) | An owner decision to resume |
| Accessibility | Remapping, cozy Easy, no typing needed; no text-size option, no colour pass | D9 |
| Saves | 3 slots per campaign, mid-day resume, migration (`save_migrate.gd`) | Steam cloud: not built |
| Store, rating, trailer, price | Nothing exists (gap-audit items 45, 54, 55) | Steamworks account, decisions D-2 to D-4 |
| Release process | No version number, no changelog, no Windows export in CI | M4 below |

## (b) Milestones

Each has a deliverable and an exit test. A milestone is done only when its exit test passes. Dates are OPEN.

| # | Milestone | Prerequisites | Deliverable | Exit test |
|---|---|---|---|---|
| M0 | Content freeze | none | No new mini-game, campaign, character or card deck. Only fixes, text edits and the items in M1 to M5 | The roadmap "Open" table has no row of kind "feature"; owner signs the freeze in `ROADMAP.md` |
| M1 | Docs and rules current | M0 | Manual and README match the code (gap-audit I-8, D5); how-to-win page (D2); fired policy (D4); save-format note (D14) | `python tools/check_systems_reference.py` exits 0; D5 checklist ticked; a new player can state the win condition of each mode from the in-game page |
| M2 | Handheld verified candidate | M0 | Text-size option (D9); Windows export in CI; Linux build run by a human on a Linux machine or a Deck; one Ally run | Section (f) Deck table all "Met on hardware" or a written waiver; frame time of the metrics dashboard measured on a Deck at 30 fps or better |
| M3 | Closed playtest | M1, M2 | 5 testers (2 humans for tech days 6 to 20, 1 owner week, 2 co-op), findings logged (section (e)); realism review back (Q7) | All 15 playtest questions answered; zero blocker findings open; every finding triaged |
| M4 | Release candidate build | M3 | Version scheme, changelog, Windows and Linux builds from CI, Godot licence notice, LICENSE decision, rating questionnaire submitted | Clean machine install of both builds plays one day of each campaign; `pad_only` and `canon_text` green on the exact commit |
| M5 | Store page up | M4, D-2, D-5 | Capsule art, screenshots, trailer, short and long description from `pitch.md`, price, tags, achievements, depot, Steam Input default | Steamworks "ready for review" with no warning; the page text passes `canon_text`-style scan for era words and real brands |
| M6 | Release | M5 | Valve build review, then Deck compatibility review request | Store page live; day-one patch path proven on a test branch (a build uploaded, downloaded and run) |

## (c) Cut list, in priority order

If time slips, cut from the top. Items 1 to 4 are the audit's D-8 proposal; the rest come from open roadmap rows.

| Order | Cut | Cost of cutting |
|---|---|---|
| 1 | More forum characters (R28, S each) | Small: 8 regulars already exist |
| 2 | Mutator sound (R9) | None while audio is on hold |
| 3 | Second-office phase and other IDEAS.md items | None: unscheduled |
| 4 | New mini-games | None: 11 exist |
| 5 | Takeover assessment for clients without a site, sales intro-rate temptation (R38 open items) | Small: depth, not coverage |
| 6 | Real head turn and cup reach for seated characters (R26, needs art) | Cosmetic |
| 7 | Co-op polish beyond Free Play and tech (R34 leftovers) | Medium: co-op shrinks to the modes that work |
| 8 | Touch overlay and Android / iOS presets (R14) | None for the PC and handheld targets |
| 9 | Year 3 beats | Medium: loses the long tail; Year 3 is the last chapter and replay value |
| 10 | Steam cloud and achievements | Medium: store expectation, not a blocker |
| Never cut | Pad-only play, the how-to-win page, the playtest, the canon test, the Deck check | These are the pillars (pad, funny not punishing, 2013-14) |

## (d) Risk register

Likelihood and impact are L / M / H, PROPOSED. "Owner row" is the roadmap or audit row that carries the work. Each risk was
checked against the repo on 2026-11-12; the check is in the "How detected" column.

| # | Risk | L | I | Mitigation | How tested or detected | Owner row |
|---|---|---|---|---|---|---|
| 1 | Balance rests on bots; no human has played tech days 6 to 20 | H | H | Human playtest M3; keep bot baselines | `balance_baseline.json` (25 cells), BACKLOG "Not covered by the playtest" | D12, Q3 |
| 2 | Card text is first drafts (549 cards, 146k words) and may be flat, repetitive or off-voice | H | M | Owner edit pass through `story/strings.txt`; playtest question 9 | `tests/strings.gd` checks shape only, not quality | D6 |
| 3 | Numbers in cards are guesses (W-2 55 percent, EBITDA 15 percent, multiples) | H | M | Realism review by a real MSP owner | Packet `docs/realism-review.md` is unanswered | Q7 |
| 4 | Likenesses of real people, real first names, a public repo | M | H | Reference photos stay in the gitignored `archive/` (checked: `git ls-files` finds none); sprites are caricatures; owner keeps the names for now and revisits before a store page | `.gitignore`, `git ls-files`; gap-audit I-12 and D-5 | D11 |
| 5 | Deck Verified is unverified on hardware | H | H | Linux export in CI; hardware check at M2; Windows-under-Proton fallback | CI `export` job (start only), `docs/steam-deck.md` section 9 | R42 |
| 6 | The Linux build was never played, only started headless for 300 frames | M | H | Run it once on a Linux machine; a CI smoke test that walks a title-to-day script on Linux | CI `export` job | R42 |
| 7 | `make_godot.py` is about 84k lines and hand-synced with the scripts | M | M | `port_edit.py`, `check_generator.py` in CI | CI step "Generator check" | H1 |
| 8 | Suite size (304 default tests, 399 files) and flaky tests | M | M | `run_tests.py --retry 1`, flaky reported; two flaky tests were seeded (X12) | CI history: failures on 2026-11-11, cause not reviewed | X12 |
| 9 | One developer (588 commits in 11 days, one author) plus agents; nobody has read all 91k lines of script | H | M | Notes per area in `docs/dev/`; generated references; tests as the spec | `git log`; `docs/design/README.md` | D13 |
| 10 | Audio on hold: a store page with a silent or beeping game | M | M | Owner decision; synthesised sound is present | Roadmap P4, `docs/dev/audio-creator.md` | P4 |
| 11 | Text size and accessibility: 3 x 5 capitals only, no text-size option, no colour-blind pass | M | H | D9; Deck table measures 20 px at x4 | `tests/deck_display.gd` asserts the 5 px floor; no test for contrast | D9, R42 |
| 12 | Old saves break after a content change | M | M | `save_migrate.gd`; the `ablate` soak cell loads about 280 damaged saves | `soak_sim` `ablate` (run for tech only), `tests/resume5.gd` | D14 |
| 13 | Windows and Linux differ: CI found a `printf` rounding of x.x5 (2.2 on Linux, 2.3 on Windows) on 2026-11-12 | M | M | The suite runs on Linux every push; rounding in script must be explicit | Commit `b4e15e4`; CI | H4 |
| 14 | The metrics dashboard costs 8 ms on a Ryzen 9 and may sit on 16 ms on a Deck | M | M | Merge pixel runs in `PixelFont.draw`; cache the glyph rects; or a lower repaint rate | `tests/frame_time.gd` (a measurement, not in the suite) | R42 (3) |
| 15 | Co-op was never tried by two humans | H | M | Playtest with two people at M3; keep co-op to Free Play and tech | `coop_soak.gd` (3 hours, bots) | R34 |
| 16 | Steam cloud is not built, and saves do not move between native Linux and Proton | M | M | Ship one build, choose the Steam Cloud root override | grep finds no Steam code in `godot/scripts` | D15 |
| 17 | Era anachronism creeps into new text | M | M | `canon_text.gd` bans era words and real vendor names in script strings | `tests/canon_text.gd` (default suite) | Q3, canon |
| 18 | The name "MSPSim" is jargon and not searched for trademarks | M | M | Plain subtitle; a name search before M5 | gap-audit D-9; no search done | D11 |
| 19 | "Fired" deletes the slot and unlocks nothing | M | M | Decide RETRY or a clearer report | gap-audit I-2; the sales Easy case was fixed (commit `0990620`) | D4 |
| 20 | No screen says how to win; five setup pages precede play | H | M | How-to-win page, shorter setup (R35) | Playtest questions 1 and 2 | D2 |
| 21 | Sessions are long (a Normal tech run is 4 to 5 hours) and a handheld battery is short | M | M | Mid-day resume, Easy and short DAY LENGTH, day reports as stops | `tests/resume5.gd`; playtest question 14 | D12 |
| 22 | Soak coverage is thin: owner, sales, service, outings, co-op cells were never soaked | M | M | Run the matrix in chunks before M3 | `docs/dev/notes-soak-sim.md` "Not run" | soak-sim |
| 23 | 66 bare random calls break "same seed, same game" outside tested paths | L | L | Seed the ones that touch outcomes, or document | `tests/determinism.gd` covers the four campaigns | D8 |
| 24 | Parody names (LabRat Nerds, Rodent Nation, iFone) too close to real marks | L | M | Banned-name list, owner review of the final list | `story/banned_names.txt`, `canon_text` | D11 |
| 25 | Screenshots and README age faster than the game | M | L | Retake at M5 | Manual images dated by commit | X12 |
| 26 | No LICENSE file in a public repo, and Godot's licence notice is not shipped | M | L | Decide a licence (or all rights reserved on purpose) and add Godot's notice at M4 | `ls` shows no LICENSE | M4 |
| 27 | Art volume: two characters are first drafts (Trent, Pell); art is by script and some is unreviewed | L | L | Art lint in CI; owner look | `tools/art_lint.py --all` in CI | Q3 |

## (e) Test plan

### The layers we have

| Layer | What it is | What it catches | Cost |
|---|---|---|---|
| Headless suite | 304 default tests of 399 files (`python tools/run_tests.py`) | Regressions in rules, saves, pad reach, canon text, layout | CI 14 to 20 min with `-j 4` |
| CI on every push | `.github/workflows/tests.yml`: lint, art lint, generator check, suite with one retry, Linux export started for 300 frames | Breakage on Linux, generator drift, a bad export | Free (repo is public) |
| Bot soaks | `soak_sim.gd`: errors, stalls, node growth, save and reload, resumes, chaos | Crashes and leaks over a whole campaign | 70 to 85 s per tech run |
| Bot balance | `bot_*`, `tiers_balance`, `balance_baseline.json`, 25 cells | Tier ordering, no dead weeks, fired rates | Minutes |
| Determinism | `tests/determinism.gd` | Same seed, same game | Seconds |
| Layout and prompt audits | `layout_audit.gd`, `pad_prompts.gd` (about 220 screens x 4 formats), `click_harness.gd` | Off-screen text, key glyphs on a pad | 10 to 30 s each |
| Screenshot tools | 122 `*_shots.gd` scripts | Visual review by a human or agent | Manual |
| UI fuzzer | Not merged at the time of writing (OPEN) | Random-input crashes | |

Not covered by any layer: whether it is fun, whether the text is funny, whether it reads at 7 inches, two humans in co-op,
a real Deck.

### Playtest questions (15)

1. In the first minute, can the tester say what to do next without help?
2. After the first day, can they state how a campaign is won or lost?
3. Do they understand what REP is and what moves it?
4. Does a first ticket take about the time it should (about 75 s to the first one, then a few minutes to close)?
5. Is there a moment in tech days 6 to 20 where they stop wanting to continue? Which day?
6. Is any day too busy or too empty (queue length, idle minutes)?
7. Is Easy actually cozy: did anything feel like punishment?
8. Is Hard fair after a first Normal run?
9. Which three cards made them laugh, and which three were flat or confusing?
10. Which outing do they want to replay, and which do they skip?
11. Can they play the whole game with a pad only, including the Computer and the phone?
12. Is text readable on a 7 inch screen at arm's length (cards, mail, the dashboard)?
13. In co-op, who is bored when, and do the two panes confuse?
14. How long is a sitting? Where did they stop, and was a stop easy to find?
15. Would they pay the proposed price, and what would they tell a friend it is?

### A 30 minute playtest script

| Minutes | What |
|---|---|
| 0 to 3 | Welcome, consent, no coaching. Say only "play it" and "think out loud". Start screen recording |
| 3 to 8 | New tech campaign on Normal; observer notes the first stuck moment (Q1, Q2) |
| 8 to 20 | Free play of day 1 and the day report; observer silent; prompts only if stuck for 60 s |
| 20 to 25 | An outing of the tester's choice, on a pad if one exists |
| 25 to 30 | The 15 questions, in order, written answers first, then talk |

Tester pool: two people who have worked in IT, two who have not, one who plays cozy games. One owner week for the owner
campaign and two humans for co-op are separate sessions.

### How to record findings

One row per finding in a shared sheet (or `docs/playtests/YYYY-MM-DD.md` once the first session exists): id, tester,
mode, day, what happened, what they expected, severity (blocker, major, minor, polish), screenshot name, the roadmap row it
becomes. A blocker is a crash, a lost save, an unwinnable state, or a screen they cannot leave with a pad. A finding is
closed only by a test or a re-played session.

### Acceptance criteria per milestone

| Milestone | Accept when |
|---|---|
| M1 | The manual says what the code does; systems reference drift is 0 |
| M2 | Section (f) Deck table has no "Not verified"; dashboard at 30 fps or better on a Deck |
| M3 | All 15 questions answered by at least 3 testers; no blocker open; Q5 names no day with more than half the testers quitting |
| M4 | Both builds install on a clean machine and play a day of each campaign; the suite and CI are green on the exact commit |
| M5 | Steamworks shows no store page warning; the page text and screenshots match the build |
| M6 | A test branch update is downloaded and run; the review requests are filed |

## (f) Platform, rating, store and legal checklists

### Steam Deck Verified and Microsoft handheld

The item-by-item table is in `docs/steam-deck.md` (sections 2 and "The two published checklists"): **do not copy it**; read it
there. Summary on 2026-11-12: Input, Display and Seamlessness rows are "Met in tests" on a PC; "Runs on SteamOS" is **Not
verified** (the Linux build starts in CI but was never played); Steam Input default template, glyph review on a Deck,
rumble strength, co-op controller order, real suspend, frame time on the Deck's APU and the Valve review itself
**need hardware or Steamworks**. Microsoft's badge criteria and perf guides (aka.ms/hhcompatguide, aka.ms/hhperfguide) were
not read: OPEN. The Windows handheld flag is not read; defaults do not depend on it.

### Age rating (IARC questionnaire answers, PROPOSED, never submitted)

| Topic | Answer drafted from the game |
|---|---|
| Violence | Cartoon, no blood. Foam dart wars, paintball and a chair shove, all played as party games. No gore, no death of characters |
| Fear | None. Ransomware is a ticket with a joke attached |
| Language | Workplace banter and mild insults, no swearing (to be confirmed by a text scan; OPEN) |
| Sexual content | None |
| Drugs, alcohol, tobacco | Coffee. A bar tab appears in a dinner and bar setting (alcohol reference, minor): answer "yes, references" to be safe |
| Gambling | None; no loot boxes, no real money in the game |
| Online interaction, chat | None. The forum and chat inside the game are scripted |
| Personal data, purchases | None collected; one paid release |
| Expected result | E10+ / PEGI 7 (gap-audit D-2): PROPOSED, decided only by the questionnaire |

### Steamworks tasks

| Task | State |
|---|---|
| Steamworks account, tax and bank | OPEN (owner) |
| App id, depot, Windows and Linux builds | OPEN (M4, M5) |
| Capsule art: header 460 x 215, small 231 x 87, main 616 x 353, vertical 374 x 448, hero 3840 x 1240, library capsule 600 x 900, logo | OPEN (not drawn; check Valve's current sizes before drawing); the pixel logo exists under `office/` |
| Screenshots (at least 5, 1920 x 1080), trailer | OPEN; list in `pitch.md` |
| Steam Input: declare full controller support and ship the Gamepad layout | OPEN (`docs/steam-deck.md` section 5) |
| Cloud saves: the `user://` root plus an override | Not built (risk 16) |
| Achievements: map the 72 Career medals (`Career.DEFAULT_MEDALS`); about 20 meaningful ones, hide the rest; needs the Steam API, which the game does not link | Not built; D15 |
| Store text from `pitch.md`; tags; rating; price; release date | PROPOSED / OPEN |
| Deck compatibility review request | After the build review (M6) |

### Legal checklist

| Item | State |
|---|---|
| Parody names for products (LabRat Nerds, Rodent Nation, iFone, Nexxus, Lynk, Googol, Sugar Smash) | Enforced by `canon_text` and `banned_names.txt`; owner to review the final list (D11) |
| Real people: the cast are caricatures with real first names | DECIDED to keep for now; **revisit before any store page**; consent or rename (D-5) |
| Reference photos of real people | Gitignored in `archive/`, not in the repo (checked); the sprites derived from them are in the repo |
| Public repo and licence | No LICENSE file: OPEN |
| Godot | MIT; the licence text and third-party notices must ship with the build (M4) |
| Fonts | None shipped: `PixelFont` is code-drawn (checked, no .ttf or .otf in `godot/`) |
| Audio | Synthesised in code; no third-party samples (checked, no .ogg or .wav in `godot/`) |
| Art | Our own, drawn in Aseprite (a licensed tool) and by script |
| Reference documents (Race'n'Chase, the Diablo pitch, the concept template, the Doom Bible) | Inspiration only; nothing is copied into the game or shipped |
| Trademark search for "MSPSim" and "Pixel IT Partners" | OPEN |

## (g) Analytics and metrics policy

**No analytics, no telemetry, no online (DECIDED non-goals).** Success measures after release are the store's own numbers
(wishlists, reviews, refunds), read by hand. What is measured offline, by bots and tests, instead:

| Measure | Where |
|---|---|
| Completion and fired rates per campaign x tier x strategy | `balance_baseline.json`, `docs/balance-notes.md` |
| Reputation curves, ticket pace, decisions per day (7.6 a day, never fewer than 3) | `bot_trace.gd`, `tests/oto_decks.gd` |
| Run length in frames and seconds, stalls, node growth, save and resume correctness | `soak_sim.gd` |
| Frame time per screen | `tests/frame_time.gd` |
| Off-screen text and overlaps | `layout_audit.gd`, `PixelFont.audit` |
| Prompts that name a key while a pad is used | `pad_prompts.gd` |
| Determinism | `tests/determinism.gd` |
| Playtest results | Section (e) findings sheet (a human, by hand) |
