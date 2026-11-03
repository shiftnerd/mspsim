# MSPSim backlog

Where open bugs and gaps are tracked. The ordered plan for everything is `docs/ROADMAP.md`. Feature ideas (not yet committed to) live in `IDEAS.md`; the replayability write-up with code hooks is `docs/replayability-ideas.md`.
Status is as of the commit that last touched this file; move items to `CLAUDE.md` once they ship.

## In progress
- Nothing is running. Next up in `docs/ROADMAP.md`: X2 (play as a cast member) and the owner campaign as Alan or Garrison.
- Merged and done: owner playthrough fixes 1-6 and the pitch name mismatch, the canon text pass (Alan and Garrison as owners), polish round 2, tech playtest bug fixes, difficulty and seeds, day report and brand names, ticket alternatives, outing UI, site polish, character select.

## Owner playthrough findings (weeks 1-20, live play)
High
~~1. Outing and decision cards open behind the weekly report and the next week is lost: `day_report.gd:41` draws on layer 70, above `cards.gd:27` (65); Enter on the report picks an option blind; a dinner left open across the report ends the next week immediately (week 10 skipped). Fix: freeze the clock while any card or outing is open, show the report only when none is open.~~ FIXED
~~2. Week 20 settles repeatedly: `campaign.gd:311` clears `_awaiting` before `Review.start()`, so `_end_day` fires again at 17:00 (about +$4,400 cash and -3 reputation each repeat, about 18 duplicate reports).~~ FIXED
Medium
~~3. Valuation history wrong in project-payout weeks: `owner.gd:2745` snapshots profit before `Projects.week()` (line 2792) pays out, then `take_week_income()` subtracts the full payout (week 7 profit 774 but ebitda -4419); the board-review multiple reads value $0 in weeks 5-8 and 11.~~ FIXED
~~4. Vic's sold install is a dead ticket: `sales.gd:147-162` creates a project ticket that `owner.gd:1240` skips, so nobody works it, it breaches its SLA and counts toward burnout; `Msp.project_busy()` then blocks further install sales.~~ FIXED
~~5. The "prospect" card (`owner.gd:271-293`) is hard-coded to Piedmont Pediatrics, signs a random client, and OFFER THE DISCOUNT never applies the promised 20%.~~ FIXED
~~6. Phone TEXTS list is blank on 368x128 (`phone.gd:713-732` lists oldest first and breaks when the first does not fit); the phone home screen has no keyboard selection (mouse only).~~ FIXED
Balance
~~7. Early game is tight (about +$660 a week, W-2 67% vs a 55% target, hiring in week 3 drops EBITDA to about -$265, reputation 50 to 41 over weeks 1-5) and then far too easy after week 12 (weekly EBITDA $2.5k then $10k, cash $53k+, value over $1M by week 17); maturity 4 reached by week 7 from clicking through cards.~~ FIXED in X1 (see CLAUDE.md "Owner round 2")
~~8. Vic complains about the same clients almost every week; Dana's Monday advice repeated the same card three times; "take the meeting yourself" (60%) is always worse than "let Vic close it" (95%); the billing leak lowers reported revenue but not collected cash (`owner.gd:2686` vs `:2754`).~~ FIXED
UX and text
~~9. HUD text draws over the card speaker bar and desktop icon labels (the tech-branch fix hides the HUD while a card is open: check the desktop labels); every client shows REVIEW DUE in week 1; Esc in the Computer needs a second press; cards do not freeze the clock mid-day; the outing invitation does not state costs until the game pick; at client sites the owner's desk PC steals E from the owner NPC.~~ FIXED (desktop labels checked: the HUD hides while Cards is open; cards freeze the clock since round 1)
10. (Name mismatch FIXED: the pitch site uses the lead's client name.) The pitch lead said Lindqvist and Moss but the site sign and speaker read NORTHLIGHT DESIGN; owner character select offers "ALAN - ON SITE" (`site_alan`) though Alan is on the team (the filter at `charselect.gd:86` matches only `office_alan`; with the new canon the owner campaign should instead offer Alan or Garrison as the owner).
Not found: anachronisms, script errors, bankruptcy (cash stayed above $4,000). Worked: character select, Boardroom tabs, weekly report, stack / peer / mentor cards, projects, business review and prospect pitch at client sites, QBR price rises, profit reviews, competitor cards, the Tier 2 growth plan.

## Tech playtest findings (days 1-5; all assigned to the `bugfix` branch)
1. Complaints and calls about tickets that are already closed (`sales.gd` complaint text / deliver only check the ticket exists).
2. PSA CLOSE has no guard: closing an unfixed ticket reopens it and costs -1 coworker opinion each time (one run lost -29).
3. The HUD (`DAY n/20 REP`) bleeds through every card header.
4. Closing the computer mid-RMM-job silently cancels the job (`computer.gd`).
5. Day-3 onsite P1 (120 s SLA) can never be met with a 40-minute drive; the drive warning counts the wrong number of at-risk tickets.
6. Vic's mail says Rusty Anchor's tickets start "tomorrow" but one arrives on day 3.
7. RMM client list shows a green dot for a machine with an active AV alert.
8. The Heartbleed vignette was scheduled for 10:30 but appeared around 12:40.
9. The onsite event text about crawling under a desk shows during a printer job.
10. Text nits: "1 DAYS AGO", truncated Outlookish subject, PowerShell result still says "QUESTION 3 OF 3", mail never marked read (the HUD reached MAIL 61).
11. Mail list needs Down before Enter works.
12. Commute card choices on days 2-3 give no outcome feedback.
13. RMM fix-fail rate looked high (9 of 28 at a configured 18-25%): verify the rolls.
Not covered by the playtest: days 6-20, the overtime-night card flow, the review, the conference trip, mouse clicks in a hidden window.

## Needs a decision from you
Decisions already made are in `docs/ROADMAP.md`. Still open:
- Answer the open questions in `docs/campaign-paths.md` section 14 (owner crew size, day lengths, hire names, placeholder parody names, tech-campaign Growth helper, a walk-in scene for sales prospects, Morgan's desk and routine).
- Whether the difficulty tier should be its own step on character select rather than the chip.
- Dialogue Manager (skip for now), Gitot (optional): parked in the roadmap.

## Known gaps
All tracked as items in `docs/ROADMAP.md`: audio, year 2, Maya in the outing logic, heavy fixes and onsite, ransomware alternatives, owner campaign leftovers, balance by playthrough. Details of the old reviewer findings and playthrough results are above and in `CLAUDE.md`.

## Housekeeping
- `tools/make_godot.py` was edited by hand in lockstep with the generated scripts in several rounds and never re-run. Run it once in a scratch copy and diff against `godot/` to confirm it reproduces the checked-in output, then fix whatever differs.
- Opening the project in Godot rewrites about 270 tracked `.import` files (a Godot version difference). Decide whether to commit them once, or add them to `.gitignore` / `.gitattributes`.
- Git reports "LF will be replaced by CRLF" on every touch: add a `.gitattributes` (`* text=auto eol=lf`) so line endings stay stable.
- Worktrees: the Claude Code hooks in `D:/Creative/.claude/` create `D:/Creative/pixelproject-wt/<name>` on branch `wt/<name>`; they go live after opening `/hooks` once. Agents' worktrees are kept after a subagent finishes: remove them with `git worktree remove`.
- Tests that use `user://test_*` saves share files: run one at a time (giving each test its own save prefix is in `IDEAS.md`).

## Visual QA sweep (Q3 + Q4, branch q3)
Method: every `*_shots.gd` test at wide, h and v (screenshots viewed for the newer screens), then all 37 shots tests again with `LAYOUT_AUDIT=1` (Game prints `OFFSCREEN` / `OVERLAP` lines from `PixelFont.audit`), plus the new `tests/layout_audit.gd` (163 screens: title, charselect, build, career, toolbox, cards, day reports, computer and phone apps, boardroom, CRM, quote builder, Dispatch, Knowledge, hiring cards; fails on any text rect outside the viewport).
Fixed (both the .gd and `make_godot.py`):
- Card options were cut off with no ellipsis at narrow widths (owner trust chips, handover "RENEGOTIATE: TELL THEM THE REAL TERM"): they wrap onto more rows now (`cards.gd`).
- Character select at 368x128: the two-line Sales / Service blurb overlapped the summary line (keeps the whole sentences that fit one line); the Year 2 hint was 339 px wide at 320x180 and ran off both edges; the portrait hint dropped "PICK" / "BACK" (three lines now).
- Title menu at 368x128 with saves for all campaigns: CAREER drew below the screen (two columns when the rows cannot fit).
- Day report at 368x128: the owner and service reports with every row pushed ENTER OR CLICK / NEXT DAY off the bottom (6 px rows when 7 do not fit).
- PROFILE at 368x128: the last lines (NEXT PERK) drew below the window (lines that do not fit are dropped, least important last).
- Dispatch CAPACITY at 368x128 with six techs: the totals line hid behind the FOCUS bar (7 px rows).
- Boardroom BOOKS at 180x320: GOAL and ON BOARD ended in ".." (values wrap under themselves).
- CRM record key hint ended in "D DROP.." / "U U.." (whole items only); backup header (180 wide), Nerds forum hint and the escape-room "U/D CHANGE" hint ran off the narrow screen.
Remaining / not done:
- The audit only sees PixelFont text inside a CanvasLayer; text clipped by a panel but still inside the viewport, bars, icons and sprites are not checked, and world-space fx text (lyrics, TV, keypad) is skipped on purpose. OVERLAP is only printed (the check is rough: it ignores shadow copies and identical positions).
- PROFILE at 368x128 now drops the lowest lines when the Rodent Nation KPI list is long; a second page would be nicer.
- `tests/campaign_shots.gd` at h / v logs `stage.gd:125` "global_position on Nil" errors (the test leaves title mode with no player); looked into in "Live-window QA (Nov 2026)" below (fixed).
- Not shot live in a real window: Q3's hard-tier mini-game feel and the 12 site offices were not covered by this sweep (done in "Live-window QA (Nov 2026)").

## Live-window QA (Nov 2026)
Method: the game run in a real window (godot-runtime MCP, Free Play, tier HARD, formats wide / h / v via `Game.set_format`), real key events for the mini-games, `Game.go("site_*")` for every site scene. No script errors reached stderr in the whole session.
Findings (severity: H = blocks play, M = visible defect, L = polish):
1. M, FIXED: Nerf war HUD line at 180x320 (v) ran off the screen and collided with the clock: "DARTS 3  Z FIRE (HOLD = FAR)  G AWAY  WAR 18  LIVES 2" is ~230 px; the "LIVES" (the elimination mode's only on-screen counter) was cut off. Repro: Free Play, `Nerf.start_war("elim")` with the blaster held, `-- --format=v`. Fix: below 260 px width the war status (`WAR n  LIVES n`) is its own line (`hud.gd`, `make_godot.py`).
2. L, FIXED: the `stage.gd:125` errors are real but harmless: `Stage._process` ran with `_player` / `_cam` still null for a frame when `Game.title_mode` went false while the title's own stage was still showing (the title's `_start` and `campaign_shots.gd` both do this; the title stage frees the Player). Repro: `godot --path godot --fixed-fps 60 -s res://tests/campaign_shots.gd -- --format=h`. Fix: `_process` returns when `_player == null or _cam == null`. After the fix the shot test logs no errors.
3. M, FIXED (the board now hangs at x 64 next to one diploma at x 42, the second diploma is gone in the trailer office; set rebuilt with ONLY, props JSON and scenes updated, checked in a screenshot). Was: (needed a regenerated background PNG, `tools/client_sets.lua` line 693): the hard-hat board of the Iron Mule trailer office (`site_trailer_office_a/b`, `Hats` at x 24) overlaps the right half of the OFFICE door. Repro: Free Play, `Game.go("site_trailer_office_a", "start")`. Fix: move the board to free wall (right of the window, x about 200) and rebuild the set.
4. L, OPEN: the six closet scenes (`site_*_closet_a/b`) are the same rack, board and cabinet; only the stripe colour differs, so 12 closets look like one room. Low priority polish.
5. L, OPEN: in the site lobbies and offices the client staff stand in front of the reception desk / owner's desk and cover the desk plate ("& HOLLER", "NORTHLIGHT") and the exec chair. Their spawn x could move 12 px left or right of the plate; not blocking.
6. L, OPEN: karaoke HARD charts have simultaneous two-arrow notes (10 of 44 in FAST RAP HOT MESS) with a 0.20 s good window and 0.34 s between notes, and the room mood drains 6 per miss from 50, so doing nothing ends the song in about 3 s. Playable for a skilled player, but there is no warning that a double needs both keys; the intro text could say so. Not changed (balance call).
7. L, OPEN: karaoke lane panel at 180x320 sits over the left singer (partly hides them). Readable, not blocking.
8. L, OPEN: printer repair on HARD: the green zone is 0.12 of the track and the marker moves 1.0 to 2.5 track widths per second (x1.5 when it speeds up), so a clean pull has a 50-120 ms window; the yellow band (hold, try again) forgives a lot. Feels tight, finishable (5 pulls). Not changed.
9. OK, no change needed: chair race finishes live (a bot sending real Z / X and arrow key events at 0.34 s gaps finished a HARD race in 27.5 s, 2 stars, 6th of 6: it tires at that pace, a slower steady rhythm is the intended play); HUD, hint bar and result page read at wide, v and the chair panel at h. Bowling (5 frames, 0 stuck states), karaoke (all four songs generate, wobble 0.55 s gaps, rap 0.34 s), escape room with 4 digits (clues, timer, hint bar), dinner (topic menu, rounds), printer game, nerf elimination: no stuck states and no errors. Text on every intro / result page fits at wide, h and v.
10. OK: all 12 site lobbies (`site_dental/law/vet/arch/realty/trailer_a/b`) and sampled offices (dental a, law a, vet b, trailer a, arch a, realty b), closets (dental a, arch a, law b, trailer a): signs readable, no NPCs in walls, no floating props except finding 3. Not looked at: the exam rooms and the other closets / offices (same templates as the sampled ones).
11. OK: title menu, character select (character, phone, point-buy) at wide, h and v, the day report and a three-option card at wide, h and v all fit and read.
Not done: no hand-played karaoke runs (hit rate by a human unknown); no HUD check of the nerf cup / hide modes; `check_generator` / lint / full suite results are in the commit message.

## Q4: why clicks missed in a hidden / headless window (FIXED)
Cause: the UI scripts read `get_viewport().get_mouse_position()` inside `_input`. For a synthetic `Input.parse_input_event` that is the real OS cursor (or stale), not the click, and `parse_input_event` also expects window pixels (the 4x window), not logical pixels; headless has a 64x64 window with a 1x transform. Fix: the 19 `_input` handlers (cards, computer, phone, day report, review, title, charselect, career screen, toolbox) use `event.position`; `Game.click_at(ui_point)` / `hover_at` send the event through `Input.parse_input_event` with the window's content-scale transform. `tests/click_harness.gd` clicks the title menu, a card option and a Computer app button (works headless and in a real window at wide / h / v). Note: Cards and the day report ignore clicks for 0.45 s of real time, so wait on `Time.get_ticks_msec()`, not frames, under `--fixed-fps`.
