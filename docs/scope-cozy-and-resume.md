# Scope: cozy mode and mid-day autosave (roadmap R16 items 1 to 3)

**STATUS: built.** Cozy mode shipped as the Easy tier (`Difficulty.cozy_on()`, not the separate toggle recommended below) with the day-length option; the mid-day resume point is built through step 4. What is still open (a separate cozy toggle, resume step 5 extras) is in `docs/ROADMAP.md` R16. System notes: CLAUDE.md "Mid-day resume point" and "Cozy Easy and the day length option".

Two read-only scoping passes (Nov 2026), from docs and targeted code reads, not play-tested. Line numbers are as of commit 6e1e07f and will drift.

## A. Cozy mode

**Recommendation: a separate COZY toggle next to LEVEL on character select**, not folded into Easy and not a fourth tier. A boolean `Difficulty.cozy`, saved in the `difficulty` section, the settings file and the meta file, read through `Difficulty.cozy_on()` (gated on `Campaign.active`, like `cf()`). Reasons: Easy stays a plain numbers tier (tests pin its values), cozy composes with any tier, and runs are easy to tag in Career and for daily seeds. It is an assist, not a difficulty: update the comment at `difficulty.gd:13` (energy is never a difficulty input) to say so.

| System | Where | Today | Cozy |
|---|---|---|---|
| Fired (tech, service) | `campaign.gd` `_end_day`, ~533-581 | rep <= 0 = fired, Review skipped, save deleted | rep floor 15 and a PROBATION line; `fired` never true |
| Fired (sales quota) | `sales_campaign.gd` ~1458 | "YOU ARE OUT" | coaching line |
| Fired (service trust) | `service.gd` ~1628 | low trust = -rep | skipped |
| Bankruptcy (owner, sales) | `owner.gd` ~3612, `sales_campaign.gd` ~1488 | cash < -3000 ends the run | bailout card (Marge or Dana, +$2k, once per run); flag it so valuation does not count it |
| SLA breach | `msp.gd` ~1541 | -5 score, mood -8, scar on P1, boss text | mood -2, no scar, soft text; window x1.6 |
| Reopens | `msp.gd` ~788 | score -3, mood -6, angry mail, social hit | mood -1, no social hit, friendly mail |
| Pay and reputation losses | `campaign.gd` ~455-471 | -25 per miss, -10 per reopen, rep -3 / -2 / -1 | zero |
| Energy | `shift.gd` ~130-144, `skills.gd` ~171 | slower and failing fixes | no slowdown, no fail chance; drain x0.5 (flavour) |
| Commute and lateness | `shift.gd` ~261-340, ~423 | traffic, late tickets, boss text, -1 rep | no traffic, no late penalties |
| Pager | `shift.gd` ~178, ~244 | ignoring costs rep -2, mood -6 | opt-in, no penalty |
| Poaching, burnout quits, crew quits | `owner.gd` ~3020, ~2120; `crew.gd`; `service.gd` | quits and losses | risk halved or zero |
| Ransomware loss | `msp.gd`, Story day 9 | -15 rep, scar | about -5, no scar |

Conflicts to settle:
- The energy rule above.
- Medals and Career: suggest cozy runs earn medals but are tagged `cozy=true`, and reputation / value / ending medals count only on non-cozy runs.
- Daily seed: show COZY beside the seed, and cozy must not draw from streams that change the ticket draws.
- `bot_lib` / `bot_run` track `fired` per tier: add a cozy column and assert it is never fired.
- The "barely survived" ending and the `Review` gate need cozy-safe text.
- Owner valuation: flag `bailout_used` and subtract it.
- Sales quota verdict: soften the wording only.

**Day length option** (300 / 600 / 900 s): `World.day_len` is set per mode at `campaign.gd` ~255 / 321 from `MODE_DEFS` (tech 600, owner 240, service 360, sales 240) and reset at ~384. The clock, energy drain, crew and onsite trips scale with it, but ticket spawns and SLA clocks run in real seconds, so a 900 s day would give 1.5x the tickets: multiply `Msp.pace` and the SLA by `day_len / default`. Persist the scale in the difficulty section (`continue_game` resets `day_len` from `MODE_DEFS`) and apply it at `begin_next_day`.

Steps:
1. Flag, toggle, save/load, charselect chip, Career tag (S).
2. Firing floor, bailout card, ending text in four modes (M).
3. Soften report math, SLA and reopens, positive-framed report rows (M).
4. Energy, commute, pager in `shift.gd` / `skills.gd` (S).
5. Day-length option with ticket and SLA scaling (M).

Tests: cozy save round trip and an old save loads with cozy off; `tests/cozy.gd` (each mode, rep forced to 0, never fired); shift tests; owner bailout; ticket counts per game hour stable across 300 / 600 / 900; a bot run with a cozy column; report screenshots.

## B. Mid-day autosave and mobile resume

**Recommendation: a coarse resume point at safe moments, not a full snapshot** (a full snapshot would need cast legs, Playbook jobs and Cards callables serialised: large and brittle).

Today `Campaign.save()` runs only from `report_continue` (end of day), and `Continue` restarts that morning. No handler exists for `NOTIFICATION_APPLICATION_PAUSED`, `WM_WINDOW_FOCUS_OUT` or `WM_GO_BACK_REQUEST` (only `career.gd` handles `WM_CLOSE_REQUEST`). The pause menu (R13, `pause_menu.gd`) exists now; the scoping agent missed it.

- **Saved:** World clock and day, lights, a trimmed cast state (scene, held, sips, lunched; re-plan the legs), Msp tickets / emails / texts / endpoints / backups and counters (needs new `to_dict`), Story `_fired`, `overtime`, `ot_hours` (not saved today), Events, Shift, Net cable ends, Difficulty stream positions (already saved, which keeps tickets identical after a reload), Mutators, the player's room, held item and seated flag, plus every section the end-of-day save writes.
- **Lost on resume:** cast mid-walk positions, RMM jobs in progress, open UI and cards, mini-games, onsite visits, nerf darts and wars, conversations, the exact x position (you resume seated).
- **Safe-moment gate** `Campaign.can_snapshot()`: campaign active, no card or UI open, no outing or onsite visit, no overtime or Playbook job, not the conference trip day, not on the title.
- **Triggers:** every in-game hour, opening the pause menu, app pause, window focus-out, close request; the Android back button opens the pause menu. Write synchronously. At an unsafe moment keep the last good snapshot.
- **Files:** a separate `<prefix><mode>_resume.cfg` (never touches the end-of-day save), a version and day header, write to a temp file then rename, keep a `.bak`, and fall back to the day-start Continue if it is corrupt, the wrong version or the wrong day. Delete it at end of day, game end and new game. The title menu shows "CONTINUE TECH - DAY 7 14:00". The resume path of `continue_game` must skip `Msp.reset()`, `Story.reset()` and `World.begin_next_day`, and must not run the day-begin hooks (Mutators, Events, Yeartwo, Story) twice.

Steps:
1. Shared section writers, `Msp.to_dict/from_dict`, Story fired state, atomic write (S/M).
2. Gate, snapshot writer, resume with the cast re-seated (M).
3. Hourly trigger, cleanup, title entry (S).
4. Lifecycle handlers wired to the pause menu (M).
5. Optional extras: Playbook jobs, onsite state, cables (M/L).

Tests: run a day to 12:00, snapshot, resume, and compare clock / tickets / emails / score / rep / stream states; story events do not refire; truncated and wrong-day files fall back; the gate refuses with a card open; end of day removes the file. Risks: events firing twice, an in-progress ticket pointing at a deleted one, Android killing the app before the write finishes.

## Decisions needed
1. Cozy as a separate toggle (recommended) or the Easy tier itself?
2. Do cozy runs earn medals and Year 2, with reputation / value / ending medals only on normal runs?
3. Resume point (recommended) or a full snapshot?
4. Which day lengths to offer (300 / 600 / 900)?
