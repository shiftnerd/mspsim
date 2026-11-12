# Build notes: the docs-drift pass (2026-11-12)

Source: `docs/design/gap-audit.md` (I-8, I-9, I-12, section 3 rows D1 to D15). Docs only: no code or game string was changed.
Every claim below was checked against `godot/scripts` (the file is named in the "how verified" column).

## Changes by file

| File | What was wrong | What is right now | How verified |
|---|---|---|---|
| `docs/GAME_BIBLE.md` section 5 | Outings named on days 5 and 15 only; no lunch breaks, no day 17 trip; review gates missing; no Year 2 / Year 3 | Outings on days 5, 10, 15; lunch days 3, 7, 12, 17; trip on day 17; review gates (lead 55 / 60, internal 45, fired at 0, Easy never fires); new subsection "After the first year" with the Year 2 and Year 3 beats and endings per campaign | `Outings.TECH_DAYS`, `LUNCH_TECH`, `Conference.TRIP_DAY`, `Review.make_offers` (via `docs/design/systems-reference.md` 1.5), `Yeartwo` `beats`, `offers`, `TEXT3` labels, `YEAR3.sla` |
| `docs/GAME_BIBLE.md` section 1 | "Career and Year 2" only | Career, Year 2 and Year 3 for all four campaigns | `Yeartwo.available` (all selectable modes with `year2`), `LAST_YEAR` 3 |
| `docs/GAME_BIBLE.md` section 8 | "Team outings: bowling, karaoke, escape room, dinner" on Fridays | Nine team games (the real `Outings.GAMES`), eleven mini-games in the toolbox, days and weeks | `Outings.GAMES` (9), `Toolbox.GAMES` (11) |
| `docs/GAME_BIBLE.md` section 3 | Christy "owner mode" only | also seated in the tech campaign | `World.STAFF_CAST` (audit I-9) |
| `docs/GAME_BIBLE.md` section 11 | Listed built things as not built (Rodent Nation sessions and owner trip, nerf war event) | Lists what was built since, and what is really still open (tech vendor-breach night, pricing models, revenue mix, second-office phase) | ROADMAP R23, R38; `IDEAS.md` "Still open" lines |
| `docs/manual/03-game-modes.md` | "Finish a Tech or Owner campaign" for Year 2; "six doors"; no Quick Play; Year 3 only "same submenu" | All four campaigns open Year 2; Year 3 per campaign; Quick Play section and glance row | `Yeartwo.available`, `Title.sub_items` (START YEAR 2 / 3), `Title` QUICK PLAY rows |
| `docs/manual/01-getting-started.md` | SETTINGS described without DISPLAY and UNFOCUSED; submenu without START YEAR 3; pause table without CAREER and FREE PLAY MENU; shape list without `deck` | All added; says the game starts full screen, `Alt+Enter`, and that DISPLAY and UNFOCUSED live in the title SETTINGS, not the in-run pause menu | `PauseMenu._labels` (settings_mode vs in-run rows), `Game.fullscreen` default true, `Game.ORDER` |
| `docs/manual/02-controls.md` | F9 cycle without `deck`; no Alt+Enter / F11 in the key tables | Added | `Game.ORDER`, `Controls.take_display_key` (Alt+Enter; F11 in a release build only) |
| `docs/manual/04-the-office.md` | "wider shapes fit the whole room, portrait follow" | Only `wide` fits the room; the others follow the camera | `Game.FORMATS` (camera follows: wide false, h / deck / v / vclose true; systems reference 9.1) |
| `docs/manual/05-your-computer-and-phone.md` | HUD `YEAR 2` only | `YEAR 2` / `YEAR 3` | `Hud` uses `Yeartwo.label()` |
| `docs/manual/06-after-work.md` | Subtitle "Seven ways ... and one quick game" while its table lists eight | "Eight ways ... and one quick game (darts)" (darts is the ninth outing game and has its own section; it costs nothing and is not an outing) | table rows, `Outings.GAMES` |
| `docs/manual/08-tips-and-troubleshooting.md` | `F9` list without `deck`; "Tech or Owner" for Year 2; toolbox GAME row without DARTS; no full screen or unfocused answers | Fixed and two FAQ entries added | `Toolbox.GAMES`, `Game.ORDER`, `Game.focus_pause` |
| `docs/manual/README.md`, `09-credits-and-legal.md` | "private" | "in progress"; the issue tracker note says the project page is public and to put nothing private in an issue | repo is public (`tests.yml`, owner decision 2026-11-12) |
| `docs/campaign-paths.md` 4.6 | Service endings "IN-HOUSE IT AT A CLIENT / A BIGGER MSP" and "STAY ON PROBATION" | Real labels: OPERATIONS MANAGER, SIDE WITH ALAN: TECHNICAL DIRECTOR, SIDE WITH GARRISON: GROWTH MANAGER, ACCEPT / DECLINE SUMMIT'S ROLL-UP, LEAVE FOR AN IN-HOUSE IT JOB, STAY ON PROBATION, with the gates. (STAY ON PROBATION does exist: the audit listed it as missing but `Service.REVIEW.endings.stay` has it.) | `Service.review_offers`, `Service.DEFAULT_REVIEW.endings`, `ServiceArc.extra_offers` |
| `docs/campaign-paths.md` 5.4 | "SALES DIRECTOR / EQUITY OFFER" | BECOME SALES DIRECTOR, STAY ON AS ACCOUNT MANAGER, JOIN THE ROLL-UP (SUMMIT), TAKE YOUR BOOK TO BYTEBROTHERS, CLEAN OUT YOUR DESK (not on Easy: `year_saves()`); the equity idea is the Year 3 ending `y3_stake` | `SalesCampaign.offers`, `director_ok`, `year_saves`, `SalesBeats.bb_open`, `rollup_ok`, `Yeartwo` offers |
| `docs/campaign-paths.md` 14 | Seven "Still open" questions | Marked answered by default (ROADMAP H7: the game runs on the defaults as built), one bracket each | ROADMAP H7 |
| `docs/BACKLOG.md` | "Nothing is running. Next up: X2"; open decision list stale | New "Where things stand (2026-11-12)" pointer to the roadmap; decisions list updated (tier is its own step; section 14 answered; legal and price wait on the owner). Historical sections untouched | ROADMAP rows R1, H7 |
| `docs/ROADMAP.md` | R42 listed glyphs as built and as open item (1); the C3 week 12 new-hire sentence twice; "repo (private)"; Year 2 sales / service row said "no extra endings yet" | R42 reworded (glyphs built, the open list renumbered 1 to 4); duplicate removed; repo public; Year 3 endings referenced; new Decisions (pillars and non-goals, likenesses and repo as is, text size and handhelds, audio on hold); rows D1 to D15 added (D3 done 2026-11-12, D5 and D6 done by this pass, D11 parked); a note that older rows say "Done" | `tests/pad_prompts.gd`; `SalesCampaign.year_saves`; owner decisions given in the task |
| `README.md` | Cover box "PRIVATE BETA" and an unqualified "RATED E FOR EVERYONE"; "1 OR 2 PLAYERS"; "A second player can join"; CLAUDE.md "the long technical notes"; no design or dev docs listed | "IN PROGRESS"; the rating line says it is a joke box; "1 PLAYER (CO-OP: EARLY)" (co-op is behind `Players.coop`, off by default, `-- --coop`); English only; table rows for `docs/design/README.md` and `docs/dev/`; Game Modes row lists Quick Play and Year 3. Counts (nine team games, 72 medals, five shapes, four campaigns, three years, 3 slots) match `docs/design/systems-reference.md` | `Players.coop`, `Outings.GAMES`, `Career.DEFAULT_MEDALS` (72 per the reference), `Game.ORDER`, `Campaign.SLOTS` |
| `CLAUDE.md` | No index of `docs/dev/notes-*.md` or `docs/design/`; "all 56 people"; no rule lines for public repo, CI, key prompts | All added; stays well under 30 KB (about 23 KB) | `ls docs/dev`, `ls sprites/*` (78 right-facing files: 19 + 22 + 27 + 10), `Controls.hint`, `tests/pad_prompts.gd` |
| `IDEAS.md` | Many lines still say Vic and Marge | One canon line at the top of the section (Vic is John, Marge is Christy); the old lines are history | ROADMAP Decisions |

## Decisions made

- The manual says the pause menu has no DISPLAY / UNFOCUSED row (true: they are in the title SETTINGS only). Not changed in code.
- Where a manual page called darts "never an outing", I kept it: the code lists darts in `Outings.GAMES` at cost 0 for the toolbox, but the warehouse board is its own casual game.
- The text-size option (TEXT) does not exist on `main`: no manual or Deck doc claims it; the roadmap lists it as open (R42 item 3, D9).
- ROADMAP rows that are "Done" were left in section 2 (moving 16 rows would be a large rewrite of a table others also edit); a note at the top of section 2 says how to read them.

## Could not verify

- That every ROADMAP "Done" row is truly done (read, not re-tested).
- The manual's chapters 4, 5, 6 and 7 were checked only for Year 2 / 3, settings, formats, full screen and game counts, not line by line for every key.
- The number of medals (72) and unlocks is quoted from the systems reference, not recounted.
- The audit's statement that Year 2 calendar is NOV 2014 to OCT 2015 was read from `Seasons.date_text` (`FIRST_YEAR` 2013, `LAST_SHIFT` 1): Year 1 reads NOV 2013 to OCT 2014.

## Code that looks wrong or inconsistent (for the coordinator, not fixed)

- `docs/design/gap-audit.md` I-8 claims `STAY ON PROBATION` does not exist; it does (`Service.DEFAULT_REVIEW.endings.stay`). The audit text is wrong, not the code.
- Era: the game says it is set in 2013-14, but Year 2 and Year 3 read NOV 2014 to OCT 2015 on the calendar (`Seasons.LAST_SHIFT`). The no-AI / no-Teams rule holds, but the Bible's "2013 into spring 2014" is only the first year.
- `Pause` in-run does not offer DISPLAY or UNFOCUSED; a player who starts a run full screen can only go to a window with `Alt+Enter` or by returning to the title SETTINGS. Probably fine, but the manual now says so.
