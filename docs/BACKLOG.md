# MSPSim backlog

Where open work is tracked. Feature ideas (not yet committed to) live in `IDEAS.md`; the replayability write-up with code hooks is `docs/replayability-ideas.md`.
Status is as of the commit that last touched this file; move items to `CLAUDE.md` once they ship.

## In progress (agents working in git worktrees, branch names in brackets)
- **Difficulty and seeds** [`difficulty`]: `Difficulty` autoload, easy/normal/hard on the title menu, run seed, saved settings, tiers wired into the existing mini-games. Roadmap item 1 of `docs/replayability-ideas.md`.
- **Polish round 2** [`polish`]: look at the rebuilt dental / law / vet / trailer main offices, architect reception chair covering the desk label, interact zones for the realty coffee bar / sign-in sheet / arch reception, dinner topic list overlapping Vic at h format, printer pages at h, onsite staff stealing E from doors and equipment.
- **Tech playtest bugs** [`bugfix`]: the 13 findings from the live tech-campaign playthrough (below).
- **Owner campaign live playthrough** (main build): findings will be added here when it reports.
- **Campaign paths design** (`docs/campaign-paths.md`): service manager (Garrison) and sales (Vic) campaigns plus the play-as-a-cast-member prerequisite; read-only design agent.

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
- **Era mentions**: decided. The two game names are parodied (Sugar Smash, Floppy Bat). Apple, Windows, Exchange and PowerShell stay as era context, and so does the old PC's "OUTLOOK 2003 PROFILE + PST" file name.
- **Playing as a cast member in a campaign**: now wanted. Two new campaign paths need it: service manager (as Garrison) and sales (as Vic), see `IDEAS.md` "New campaign paths" and `docs/campaign-paths.md` (design in progress). Character select offers only teen, adult and site Alan in campaigns until this lands.
- **Dialogue Manager addon**: research said skip for now (revisit only for long branching NPC conversations; a half-day spike would confirm its condition syntax). Alternative: conditional lines in the existing `Talk` tables.
- **Gitot** (in-editor git panel): optional; the repo is set up and the CLI / GitHub Desktop work fine.

## Known gaps
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
