# Build notes: tech campaign batch (X10 pacing, X6 owner help, R36 direct texts)

Branch `worktree-agent-ad9b6bfb7a776f2ad`, Nov 2026. Three roadmap rows of section 2, tech campaign only.

## X10 tech pacing (`scripts/msp.gd`, `story.gd`, `mutators.gd`, `onsite.gd`, `pause_menu.gd`; tests `tech_pacing.gd`, dev tool `bot_pace.gd`)

### What was built
- **Every client ticket counts toward the day's cap.** `Msp.created_today` counts each ticket `create_problem` makes in the tech campaign (any source); `_random_ticket` refuses when `max(spawned_today, created_today) >= day_cap()`. A story or event ticket now takes the place of a random one instead of landing on top of the twelve. `DAY_CAPS` and `OPEN_CAPS` are unchanged. **Easy and normal only** (`Msp.shared_cap()`): on hard the story tickets stay on top of the random ones, see "Hard tier" below.
- **Held tickets.** `Msp.problem_or_hold(client, prob, source, force)` and `Msp.return_or_hold(item)` create the ticket at once when the open queue is under `open_cap()` and nothing is waiting in front of it; otherwise the request goes to `Msp.held` (plain data: `{kind: "problem" / "return", day, ...}`, saved in `Msp.to_dict`). `_tick_held` (from `_process`) lets the first one in when the queue has room, `HOLD_GAP` (12 game seconds) apart, never after `World.DAY_END`. One that waited overnight comes in from `HOLD_MORNING` (9:30) the next day whatever the queue looks like, so nothing is lost and the order is kept. `Msp.queue_full()` is the test the timed spawns already used. `Msp.held_total` counts holds per run (the probe prints it).
- **Who uses it** (not time-critical): the Adobe story ticket (`Story.fire` "adobe"), workarounds that came back (`Story._spawn_followups`), the recall batch of the mutators (`Mutators._batch`), a missed onsite finding (`Onsite._missed_follow_up`), and the R36 "call the desk" ticket. The timed onsite job call (`Onsite._process`) waits while the queue is full and, if the day never had room, comes on the next visit day (`Onsite._carry`; not saved).
- **Who does not** (time-critical or already in progress): ransomware, the desktop install (it starts the project), Playbook jobs, John's complaint (`Sales`), a finding you log yourself at a site, on-call and pager tickets. `Story.DAYS` and the other tables were not reordered (`growth.gd` indexes positions).
- **TICKET PACE** (pause menu row, tech campaign only, under DAY LENGTH; Enter or Left / Right): RELAXED / NORMAL / BUSY = `Msp.pace_setting` 0 / 1 / 2. It scales the day cap (`PACE_DAY` 0.75 / 1 / 1.25, never under 1), the gap between timed tickets (`PACE_GAP` 1.3 / 1 / 0.8) and the open cap (`PACE_OPEN` -1 / 0 / +1, never under 2). It takes effect at once and is kept in the settings file (`[pace] tech` in `Difficulty.settings_path`; `Msp.load_pace` / `save_pace` / `cycle_pace` / `set_pace` / `pace_label`). NORMAL keeps the caps and the gap of before.

### Public functions
`Msp.tech_paced()`, `shared_cap()`, `queue_full()`, `problem_or_hold()`, `return_or_hold()`, `day_cap()`, `open_cap()`, `pace_label()`, `set_pace(i)`, `cycle_pace(step)`, `load_pace()`, `save_pace()`.

### Measured (normal tier, `tests/bot_pace.gd`, ts=20)
Columns: tickets opened that day / highest open count / SLAs missed. Careful bot days 17-20 are the conference trip.

**Before** (commit 12a9c48), careful bot, busiest day and total:

| seed | d9 | d10 | d11 | d12 | d13 | d14 | d15 | d16 | busiest | total | rep |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 12 | 13 | 10 | 9 | 12 | 12 | 11 | 8 | 13 | 141 | 100 |
| 2 | 13 | 15 | 11 | 10 | 13 | 13 | 12 | 11 | 15 | 154 | 100 |
| 3 | - | - | - | - | - | - | - | - | 14 | 148 | 100 |

(seed 3 was recorded as totals only.) Lazy bot before: seed 1 rep 58, 50 SLAs missed, open 6-9 on days 9-20 (9 on day 10, 8 on day 14); seed 2 fired on day 17 (rep 0, 66 missed, open up to 9); seed 3 rep 71, 43 missed.

**After**, careful bot at NORMAL (tickets / max open / missed):

| day | seed 1 | seed 2 | seed 3 |
|---|---|---|---|
| 1 | 2/1/0 | 1/1/0 | 2/1/0 |
| 2 | 3/1/0 | 3/3/0 | 3/1/0 |
| 3 | 5/2/0 | 5/2/0 | 5/2/0 |
| 4 | 7/3/1 | 6/3/0 | 7/3/0 |
| 5 | 7/1/0 | 7/2/0 | 7/2/0 |
| 6 | 9/1/0 | 8/2/0 | 8/2/0 |
| 7 | 9/3/0 | 9/2/0 | 9/2/0 |
| 8 | 9/2/0 | 10/2/0 | 10/3/0 |
| 9 | 11/2/0 | 11/4/0 | 11/2/0 |
| 10 | 12/4/0 | 12/5/0 | 12/4/0 |
| 11 | 11/2/0 | 12/2/0 | 12/2/0 |
| 12 | 10/2/0 | 12/3/0 | 11/3/0 |
| 13 | 11/1/0 | 13/2/0 | 13/2/0 |
| 14 | 12/4/0 | 12/3/0 | 12/2/0 |
| 15 | 11/1/0 | 12/2/0 | 12/2/0 |
| 16 | 7/1/0 | 12/3/0 | 10/3/0 |
| 17 | 0/1/0 | 0/1/0 | 0/1/0 |
| 18 | 3/2/0 | 3/2/0 | 2/2/0 |
| 19 | 1/1/0 | 1/1/0 | 1/1/0 |
| 20 | 0/0/0 | 0/0/0 | 0/0/0 |
| total | 140 | 149 | 147 |
| busiest | 12 | 13 | 13 |

All three end at rep 100 with the lead offer. The 13 on day 13 is twelve tickets plus one time-critical job that came after the cap was reached. The careful bot never reaches the open cap, so nothing was held for it (held 0).

**After**, lazy bot at NORMAL: seed 1 rep 68 (45 missed, 4 held), seed 2 rep 74 (23 missed, 6 held; no longer fired), seed 3 rep 69 (46 missed, 1 held). Its open count on days 9-20 is 6-7, with 9 on day 10 and 8 once on day 16. What still comes in over the cap is by design: the Playbook jobs (day 10's rack is three tickets at 10:00), the ransomware, and a phone call that was already ringing when the queue filled. The lazy bot still misses SLAs because it works first come first served with long idle gaps; the pacing does not rescue it, it only stops the queue from growing past the cap by more than the story's own jobs.

**The setting**, seed 1: RELAXED careful 105 tickets, busiest day 10, rep 100; RELAXED lazy 75 tickets, 5 missed, rep 91; BUSY careful 169 tickets, busiest day 15, rep 100.

### Hard tier (why it is exempt from the shared cap)
With the shared cap on every tier, `tests/bot_run.gd -- tech hard careful` (ts=20) gave seed 11 rep 25 and 58 in two runs against 84, 75 and 77 at the commit before. On hard the careful bot closes about 12 a day and misses 5-10, so reputation hangs on every close: one to three fewer tickets a day cost it a point or two each day, it reached day 16 under the conference trip's REPUTATION 55 goal, stayed in the office for days 17-20 and sank. With hard exempt the same cell gave 77 (seed 11) and 79 (seed 12). The holding of story tickets and the TICKET PACE setting still apply on hard.

`tools/balance_baseline.py` (24 cells, tech at ts=120) reports one drift after this batch, in both runs I made: `tech hard careful seed 11` (rep 27, then 16; baseline 70, tolerance 20). That cell is bimodal and was already so before this batch: four seeds at ts=120, two rounds each, gave seed 11 rep 16 and 59 at the commit before and 3 and 63 now (seeds 12-14: 51 / 65 / 67 before, 44 / 61 / 72 now, the same in both rounds). The run either makes the conference trip or it does not. The other 23 cells are inside the tolerance. The baseline file was not touched.
### Tests
- `tests/tech_pacing.gd` (about 70 s): the pace setting and its file, the pause menu row and panel size, the shared day cap, hold / order / release / overnight / resume point, no holding in the service campaign, then a careful bot plays seed 1 at normal: no day above 13 tickets, every scripted `Story.DAYS` event of every day fired (`Story._fired` against `events_on(day)`), the Adobe / install / ransomware tickets all appeared, nothing left held.
- `tests/bot_pace.gd` is a dev tool (skipped by `run_tests.py` through the `bot_*` pattern): `-- strategy=careful seed=1 pace=1`.
- `tests/pause.gd` and `tests/cozy.gd` were adjusted for the extra row (pause walks to the last row instead of pressing Down four times).

## X6 owner help: onsite visits and the walk to the front desk (`scripts/owners.gd`, `world.gd`, `onsite.gd`; test `owner_visit.gd`)
- **A visit going badly** (`Owners.visit_rescue(client, ticket_id)`, called from `Onsite._after(false)`, once a visit): the fix you tried at the site failed, an owner rings the client: mood +`VISIT_MOOD` (3) and +`ONSITE_BONUS` (60 s) on the job's own clock. Garrison first, Alan if he cannot. Log reason `visit`.
- **Away on a visit** (`Owners.visit_cover()`, called from `Onsite._go_home`): back at the office, the most urgent open client ticket that the drive aged to `ONSITE_RISK` (45%) of its clock or less gets +60 s ("watched the queue while you were onsite"). Alan first. Log reason `onsite`.
- Both use `Owners.visit_allowed()`: the tech campaign, day 3 on, the per-owner uses of the day, the cooldown, the tier (hard: none), an owner who is in the building and free (`is_free`). It does not need `Msp.enabled`, which is off at a site. Free as before: no reputation, no opinion, counted in `stepped` (the day report row OWNERS STEPPED IN) and the `owner_help` career counter. Lines are in `Owners.VISIT_LINES`.
- **The walk to the front desk** (`World.send_owner_front(who)`): for the triggers `sla`, `backlog` and `complaint` the owner now walks to Jen's desk (her seat in `cubicle_two`, 34 px to its left, clamped to the room), takes the call there with the headset (`cover` leg ending in the NPC step `answer`) and walks back to work. With no route or no world (tests), the old headset call at the owner's own desk is the fallback. `phones` still walks to the ringing phone; `onsite` and `visit` have no walk (you are not there to see it).

## R36 clients who know your name, tech part (`scripts/msp.gd`, `campaign.gd`, `day_report.gd`, `strings.gd`; test `favours.gd`)
- **The ask** (`Msp._maybe_favour`, from `_note_by_name_close`): after a clean close (in time, not a rework) a client at mood `FAVOUR_MOOD` (78) or more texts your cell for one more thing, off the books, with chance `FAVOUR_CHANCE` (0.22, stream `msp.favour`). From day 4, at most one a day, each client at most every 4 days, never at a site or at the conference. It is a text on the phone plus a card from "<contact> (text)" (`Msp.ask_favour(client, k)`).
- **The three answers** (`Msp.favour_answer`):
  - DO IT NOW (`fav_now`): no ticket, no score, no closed count; client mood +4, +3 people XP, energy -2, every open unfinished ticket loses `FAVOUR_SECS` (40 s). Counted: `Msp.favours_today` (day report row UNBILLED FAVOURS, PEOPLE group) and `Story.flags.favours` (the run).
  - ASK THEM TO CALL THE DESK (`fav_desk`): mood -2, the job becomes a real P4 ticket through `problem_or_hold` (so it also respects X10), Morgan +1 opinion. `Msp.desk_sends_today`.
  - IGNORE IT UNTIL MORNING (`fav_ignore`): mood -3, and the next morning they call the desk themselves: a P3 ticket through `Story.queue_followup`.
- **Morgan's 1:1** (`Msp._tick_favour_talk`, `favour_talk`, `favour_talk_answer`): after `FAVOUR_TALK` (3) unbilled favours, the next day from 10:00 a card from the manager. I WILL SEND THEM TO THE DESK (`fav_log`): +1 reputation; afterwards each one sent to the desk is +1 reputation and each further favour -1 with a text from her. THEY ASKED. I HELPED. (`fav_fine`): -1 reputation. CAN YOU TALK TO THEM? (`fav_shield`): a policy mail to the clients, every client who ever asked -1 mood, no asks for `FAVOUR_QUIET_DAYS` (5). She asks once per run. State in `Story.flags`: `favours`, `favour_talk` ("" / due / asked / the answer id), `favour_talk_day`, `favour_quiet` (saved with the campaign).
- Text is patchable: `Msp.FAVOURS` and `Msp.FAVOUR_TEXT` are registered in `Strings.ROOTS` and in `story/strings.txt` (first draft wording).
- Bots (`tests/bot_lib.gd`): the careful bot sends them to the desk, the lazy one ignores them.

## Decisions made
- X10: a held ticket that waited overnight is let in at 9:30 regardless of the cap. "Never lost" wins over "never above the cap"; without it a player who sits at the cap all day would never see the Adobe job.
- X10: the cap is shared instead of raising or lowering `DAY_CAPS`. Days 1-9 therefore lose a random ticket whenever a story ticket arrives first (day 1 can still show 2: the cap only stops random ones).
- X10: the pace row is in the in-game pause menu only (tech campaign), not on the title's SETTINGS page, to keep the shared file's diff small. It is a global setting, not saved per campaign.
- X10: the ransomware, the install and the Playbook jobs are time-critical story beats and are never held.
- X6: "going badly" = a failed fix attempt at the site (a wrong choice or a zero-star printer fight), once a visit. Leaving with the job undone still costs the 6 mood: the owner helps while you are still trying, not when you walk out.
- X6: the front desk is Jen's desk. There is no client visitor in the tech campaign, so "the visitor" has nothing to walk to.
- R36: the ask is tied to a clean close ("while I have you") instead of a timer, so it never arrives in a lull or during a visit.
- R36: Morgan's talk is a card the morning after the third favour, not a new 1:1 system; the tech campaign has no 1:1 screen and her other talks (growth plan, reviews) are cards too.

## Not done / left
- No screenshot or on-screen check of the owner walking into `cubicle_two` (logic and plan legs are tested; the walk itself reuses the `cover` leg the phone help already uses).
- The onsite job carry (`Onsite._carry`) and the per-client favour gaps (`Msp.favour_day`) are not in the end-of-day save (same as `named_day` of the first R36 version).
- Art wanted: none. A small phone-shaped icon on the favour card would be nice.
