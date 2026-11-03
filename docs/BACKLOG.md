# MSPSim backlog

Where open bugs and gaps are tracked. The ordered plan for everything is `docs/ROADMAP.md`. Feature ideas (not yet committed to) live in `IDEAS.md`; the replayability write-up with code hooks is `docs/replayability-ideas.md`.
Status is as of the commit that last touched this file; move items to `CLAUDE.md` once they ship.

## In progress
- **Owner playthrough bug fixes, round 1** (worktree `ownerfix`): clock freeze while a card or outing is open, week-20 settle, valuation history, Vic's install ticket, prospect card, phone texts and keyboard, naming. Items 7-9 (balance, smaller, UX) are queued in `docs/ROADMAP.md` (X1).
- **Canon text pass** (Alan and Garrison as owners), **play-as-cast-member** and the **new campaign paths**: designed in `docs/campaign-paths.md`, not started. Build order: player-as-cast-member, owner as Alan or Garrison, tech-campaign owner changes, Sales (Vic), Service (Dan).
- **Replayability roadmap items 2-10** (`IDEAS.md`): item 1 (difficulty and seeds) is built and merged.
- Merged and done: polish round 2, tech playtest bug fixes, difficulty and seeds, day report / brand names, ticket alternatives, outing UI, site polish, character select.

## Owner playthrough findings (weeks 1-20, live play)
High
1. Outing and decision cards open behind the weekly report and the next week is lost: `day_report.gd:41` draws on layer 70, above `cards.gd:27` (65); Enter on the report picks an option blind; a dinner left open across the report ends the next week immediately (week 10 skipped). Fix: freeze the clock while any card or outing is open, show the report only when none is open.
2. Week 20 settles repeatedly: `campaign.gd:311` clears `_awaiting` before `Review.start()`, so `_end_day` fires again at 17:00 (about +$4,400 cash and -3 reputation each repeat, about 18 duplicate reports).
Medium
3. Valuation history wrong in project-payout weeks: `owner.gd:2745` snapshots profit before `Projects.week()` (line 2792) pays out, then `take_week_income()` subtracts the full payout (week 7 profit 774 but ebitda -4419); the board-review multiple reads value $0 in weeks 5-8 and 11.
4. Vic's sold install is a dead ticket: `sales.gd:147-162` creates a project ticket that `owner.gd:1240` skips, so nobody works it, it breaches its SLA and counts toward burnout; `Msp.project_busy()` then blocks further install sales.
5. The "prospect" card (`owner.gd:271-293`) is hard-coded to Piedmont Pediatrics, signs a random client, and OFFER THE DISCOUNT never applies the promised 20%.
6. Phone TEXTS list is blank on 368x128 (`phone.gd:713-732` lists oldest first and breaks when the first does not fit); the phone home screen has no keyboard selection (mouse only).
Balance
7. Early game is tight (about +$660 a week, W-2 67% vs a 55% target, hiring in week 3 drops EBITDA to about -$265, reputation 50 to 41 over weeks 1-5) and then far too easy after week 12 (weekly EBITDA $2.5k then $10k, cash $53k+, value over $1M by week 17); maturity 4 reached by week 7 from clicking through cards.
8. Vic complains about the same clients almost every week; Dana's Monday advice repeated the same card three times; "take the meeting yourself" (60%) is always worse than "let Vic close it" (95%); the billing leak lowers reported revenue but not collected cash (`owner.gd:2686` vs `:2754`).
UX and text
9. HUD text draws over the card speaker bar and desktop icon labels (the tech-branch fix hides the HUD while a card is open: check the desktop labels); every client shows REVIEW DUE in week 1; Esc in the Computer needs a second press; cards do not freeze the clock mid-day; the outing invitation does not state costs until the game pick; at client sites the owner's desk PC steals E from the owner NPC.
10. The pitch lead says Lindqvist and Moss but the site sign and speaker read NORTHLIGHT DESIGN; owner character select offers "ALAN - ON SITE" (`site_alan`) though Alan is on the team (the filter at `charselect.gd:86` matches only `office_alan`; with the new canon the owner campaign should instead offer Alan or Garrison as the owner).
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
- **Decided**: the service manager is played as **Dan**; the owner campaign as **Alan or Garrison** (owners take a weekly draw from the bank balance); Morgan is a real cast member; in the tech campaign owners are busy but jump in as a last resort (phones, clients) at no reputation cost. The canon text pass is undecided (parked). See `docs/ROADMAP.md`.
- **Era mentions**: decided. The two game names are parodied (Sugar Smash, Floppy Bat). Apple, Windows, Exchange and PowerShell stay as era context, and so does the old PC's "OUTLOOK 2003 PROFILE + PST" file name.
- **Playing as a cast member in a campaign**: now wanted. Two new campaign paths need it: service manager (as Garrison) and sales (as Vic), see `IDEAS.md` "New campaign paths" and `docs/campaign-paths.md` (design in progress). Character select offers only teen, adult and site Alan in campaigns until this lands.
- **Dialogue Manager addon**: research said skip for now (revisit only for long branching NPC conversations; a half-day spike would confirm its condition syntax). Alternative: conditional lines in the existing `Talk` tables.
- **Gitot** (in-editor git panel): optional; the repo is set up and the CLI / GitHub Desktop work fine.

## Known gaps
- **Canon pass for Alan and Garrison as owners**: GAME_BIBLE roles are updated, but story and dialogue text still cast them as techs: `Talk` greetings / small talk / tips (specialities servers and security), vignettes ("Alan returns with donuts"), Lynk messages, the review quotes, `World.CAST` roles, the all-hands (owners attend), who texts on SLA breaches ("Dispatch" / "Boss"), the Boardroom / owner-campaign copy (Marge reads you the numbers, but who is the owner?). Needs a read-through and a small code pass. Decided: in the tech campaign they are busy owners who jump in as a last resort (phones, clients), so the 'help' lifeline and tips need new owner-style wording and a last-resort trigger.
- No audio at all (music, UI sounds, ring tones).
- Thin replay value: no year 2 (see roadmap items 9-10).
- Maya is not in the outing mini-games' logic yet (she has a standing spot only): roadmap item 5.
- Heavy ticket fixes never require an onsite visit; ransomware has no new alternative fixes; clever fixes are locked in Free Play because skill levels exist only in campaigns.
- Alt-fix balance (return chances, time multipliers) is covered by unit tests only, not by a playthrough.
- Site art: the coffee bar, sign-in sheet and arch reception are art only until the `polish` branch lands.
- Owner campaign: Maya as the first hire, an owner-campaign Rodent Nation, sitting in conference sessions, more onsite jobs and projects (see `CLAUDE.md` "still open" lines).
- Many ideas for both campaigns are listed in `IDEAS.md`.

## Housekeeping
- `tools/make_godot.py` was edited by hand in lockstep with the generated scripts in several rounds and never re-run. Run it once in a scratch copy and diff against `godot/` to confirm it reproduces the checked-in output, then fix whatever differs.
- Opening the project in Godot rewrites about 270 tracked `.import` files (a Godot version difference). Decide whether to commit them once, or add them to `.gitignore` / `.gitattributes`.
- Git reports "LF will be replaced by CRLF" on every touch: add a `.gitattributes` (`* text=auto eol=lf`) so line endings stay stable.
- Worktrees: the Claude Code hooks in `D:/Creative/.claude/` create `D:/Creative/pixelproject-wt/<name>` on branch `wt/<name>`; they go live after opening `/hooks` once. Agents' worktrees are kept after a subagent finishes: remove them with `git worktree remove`.
- Tests that use `user://test_*` saves share files: run one at a time (giving each test its own save prefix is in `IDEAS.md`).
