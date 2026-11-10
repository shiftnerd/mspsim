# Build notes: the leftovers of the six-branch batch (agent `leftovers`, Nov 2026)

Small open items of the rows R38, R41, R12, R16, R4, X10, R34, R26 and X12, each closed with a headless test. No art, no sound,
no anim rebuild. Player-facing wording is a first draft.

## 1. R38 small leftovers (test `tests/r38_leftovers.gd`)

| Item | What was built | Code |
|---|---|---|
| H9 overnight job failure rate | A backup fails overnight 8 % of the time; with H9 fresh 6 % (stale: 7 %). | `Habits.night_mult()` (`NIGHT_CUT` 0.25), read in `Incident.backup_fail_chance()` |
| H3 failed cutover costs half | The migration card's two overrun rows carry `"overrun": 1200` / `600` (what was eaten). With H3 fresh half of it comes back (a toast says so) and the habit is touched. | `Habits.overrun_back(eaten)` (`OVERRUN_CUT` 0.5), `Owner.apply` key `overrun`, `Owner.CARDS.migration` |
| H14 default-password finding | Owner campaign: the first time you inspect the printer at a client whose passwords were not changed, you find the factory passwords (the usual finding card: LOG A TICKET, SELL IT AS A PROJECT, NOTE). Once per client; never at a site H14 has done. | `Habits.default_pw(client)`, `Habits.pw_finding(client)`, `Onsite.inspect` (`Owner.flags.pw_seen`) |
| TESTED date on the RMM BACKUPS tab | A restore test (H1) stamps `Msp.backups[client].tested`; the row reads `OK - LAST GOOD: TODAY - TESTED WK 9` (compact rows drop LAST GOOD: `OK - TESTED WK 9`). Saved with the campaign. | `Computer.backup_status(status, b, compact)` (static), `Habits._perform` |
| Hollis favour consumer | Sales week 14 (`SalesRival.WEEKS[14] = "favour"`): if you sent Ms. Cedar back to Hollis in week 11, he rings and passes on Tidewater Title (a warm lead, quality `FAVOUR_QUALITY` 72, no incumbent). A full pipeline: no lead, +1 conscience. Pays once. | `SalesRival.beat_favour()`, text `SalesCampaign.BEAT_TEXT.favour` |

Measured in the test: 4000 nights on one stream, 262 failures with H9 against 343 without.

## 2. R41 paintball: overtime (`paintball_game.gd`; tests `paintball.gd`, `paintball_tuning.gd`)

**The rule.** Level when the 150 s are up: `overtime` starts (`OVERTIME` 45 s, `params.overtime` overrides, 0 = off). Sudden death:
a unit tagged in overtime is out for the rest of the match (`down = OUT`, `is_out(i)`); the next flag carried home wins; a team
with nobody left standing loses (`standing(team)`, `_end(by_wipe)`); still level after 45 s is a draw (1 star). A unit that was
already waiting to come back when overtime began still comes back. An overtime win is a plain win (2 stars).
`time_left()` is the seconds left of the match or of the overtime. HUD: the clock turns amber and counts the overtime down,
`OT` / `OUT` in the state slot, cue lines `OVERTIME! NOBODY COMES BACK. NEXT FLAG WINS.` and `YOU ARE OUT. IT IS UP TO THE OTHERS.`
The track no longer draws a respawn countdown over somebody who is out for good.

`tests/paintball.gd`: "time up level is a draw" was changed on purpose to "time up level is overtime", plus: a tag in overtime
is for good, the next flag wins, the last team standing wins (2 stars), 45 s level is a draw, `overtime: 0` is the old rule.

**Tuning.** The overtime alone (rivals' aim unchanged, `RIVAL_EDGE` 2.3) turned most draws into the player's wins:

| tier | win | draw | loss |
|---|---|---|---|
| easy | 89 % | 0 % | 11 % |
| normal | 77 % | 3 % | 20 % |
| hard | 51 % | 1 % | 48 % |
| normal, co-op | 87 % | 1 % | 12 % |

Sweep of the rivals' edge with overtime on (normal, 100 seeds): 2.6 -> 64 / 1 / 35, 2.9 -> 52 / 2 / 46, 3.2 -> 46 / 5 / 49.
**`RIVAL_EDGE` 2.3 -> 2.75.** Nothing else changed (`COOP_EDGE` stays 1.4: co-op loses 16 %, well over the 5 % floor).

**After** (`tests/paintball_tuning.gd -- --full --seeds=100`, 100 seeded matches a row, all bands hold):

| tier | win | draw | loss | length | captures | your captures | your tags |
|---|---|---|---|---|---|---|---|
| easy | 79 % | 3 % | 18 % | 149 s | 2.3 | 1.30 | 21.4 |
| normal | 55 % | 3 % | 42 % | 151 s | 2.4 | 1.15 | 20.0 |
| hard | 38 % | 1 % | 61 % | 152 s | 2.0 | 0.75 | 18.6 |
| easy (night) | 84 % | 0 % | 16 % | 139 s | 2.9 | 1.67 | 18.1 |
| normal (night) | 54 % | 2 % | 44 % | 152 s | 2.9 | 1.33 | 18.2 |
| hard (night) | 38 % | 2 % | 60 % | 148 s | 2.8 | 1.01 | 16.1 |
| normal, co-op (two bots) | 82 % | 2 % | 16 % | 154 s | 0.9 | 0.36 | 18.8 |

Normal is inside the target (45-65 % wins, draws under 12 %). The test's draw band is now 12 % on every row (was 45 %).
Co-op: two pilots win more often than one (82 %) and lose 16 %; a flag still gets home only about once a match, the overtime
settles the rest. The `SWEEP` rows of the tuning test are now the four edges 2.6 / 2.9 / 3.2 / 3.6.

## 3. R12 chairs

**Toolbox rows** (`toolbox.gd`; test `tests/toolbox.gd`): CHAIR RACE has an `EVENT` row (`chair_i`: PICK ON CARD / THE STRAIGHT /
THE GAUNTLET / CHAIR FIGHT -> `opts.event`), PAINTBALL a `MATCH` row (`night_i`: CARD'S DRAW / DAY / NIGHT -> `opts.night`). A
fixed pick cannot be changed on the card (that was already the rule of `opts.event` / `opts.night`).

**Co-op chair fight: a duel** (`chair_fight.gd`, `outings.gd`, `chair_track.gd`; test `tests/coop_chair_duel.gd`).
With player 2 in, the chair fight is player 1's chair against player 2's (`Outings._chair_duel()`, `params.duel` -> `ChairFight.duel`):
nobody drives chair 1, both chairs pay the tier's stamina, the whole crew watches, player 2's puppet sits in its own chair
(`P2_COLOR`) with player 2's look. Keys: player 1 as before; player 2's pad A and B are the two legs (`_event_key_p2`), stick /
D-pad turn and change lane; `_chair_press` sends every key to the chair of whoever pressed (`push_of` / `spin_of` / `lane_of`).
The HUD strip shows a stamina bar each; the cue reads `P1 2  P2 1  FIRST TO 3`. The two races stay the tandem.
Result: 1 star whoever wins (`stars()`), the line names the winner, and the Career does not count it as a won fight
(`_chair_career`: `duel: true, won: false`). 24 driven duels (the crew's driver in both chairs) all end, neither end of the strip
is favoured.

## 4. R16 relationship levels on the phone contacts (`phone_calls.gd`, `phone.gd`; test `tests/phone_levels.gd`, layout audit block `phone contacts levels`)

`Calls.level(contact)` (0-4, -1 for clients, the pizza place, no campaign), `Calls.level_text` ("LV 2 LUNCH BUDDY"),
`Calls.row_sub(contact, selected)`. A cast member's row has four pips at the right of its second line; the selected row's
second line is the level's name instead of the role. Adam and Michael (their own numbers) count as cast.

## 5. R4 themed friend hints (`outings.gd`; test `tests/escape_friend_hints.gd`)

`Outings.friend_say(text)` puts the room's nouns into the friend's line: each themed room has `words` (ordered find -> replace
pairs: PLAQUE -> ASSET TAG, CHALKBOARD -> RACK BOARD, PAINTING -> NETWORK MAP ...) and `tips` (the two shelf recipe tips:
binders and cable ties, case files and red strings, manuals and mouse cords; `recipe_tip(key)`). The study has neither and
keeps `FRIEND_HINTS` word for word. Because the words are applied to whatever `FRIEND_HINTS` holds, an edited hint is themed too.
The test asks every friend x zone x theme and fails when a themed hint still says chalkboard, painting, plaque or bookshelf.

## 6. X10 first-day choice (`story.gd`; test `tests/first_day.gd`)

After Dan's intro card (kept) and his answer, Garrison has you say hello to the room (`Story.VIGNETTES.hello`, asked by
`_vignette_after("mentor_intro")`, so the two cards never interleave, also on cozy Easy where every day 1 event is due at once):

| Answer (id) | Opinions | Next morning |
|---|---|---|
| I FIX THINGS. SOMETIMES ON PURPOSE. (`joke`) | Garrison +2, Alan -1 | a text from Garrison |
| I READ THE RUNBOOKS LAST NIGHT. (`keen`) | Alan +2, Garrison -1 | a text from Alan |
| HI. WHERE IS THE QUEUE? (`quiet`) | Dan +1, Maya +1 | a text from Maya |

The pick is the saved flag `Story.flags.hello`; the text is the option's `echo`, sent by the day 2 event `hello_echo` (appended
to the END of day 2's list: `story/strings.txt` addresses a day's events by index). Once a run, day 1 only, not in a second
year. The card does not touch the first ticket's timer (`Msp._spawn_t`, asserted).

## 7. R34 personal card routing (`msp.gd`; test `tests/coop_favour.gd`)

The batch did add one personal event: **the unbilled favour text** (R36). The client texts whoever closed their ticket, and
DO IT NOW costs that player's energy and pays that player's people XP. Before, the card was a team card and the answer always
landed on player 1. Now `Msp.ask_favour(client, k, slot := -1)` takes the closer (`Players.active_slot` by default), opens the
card with that slot (co-op: in that player's pane, holding only them) and applies the answer inside `Players.run_as(slot, ...)`.
Alone nothing changes.

Looked at and left as they are, with the reason:
- Morgan's 1:1 about the favours: about the run's count (`Story.flags.favours`), a team card.
- By-name requests and thank-you texts: a mark on a ticket, a toast and a text, no card; the reputation is shared.
- Relationship level toasts (`Collection.note_change`): `Social` is one shared set of opinions and a toast is on everybody's
  screen; the coffee at levels 3 and 4 goes to the player who was acting when the level was reached (`Shift.add_energy`
  inside `run_as`). Nothing to route.
- The first-day hello (section 6): opinions are shared, a team card.

## 8. R26 the coffee-cup reach (`seat_life.gd`, `npc.gd`; tests `tests/sitcup.gd`, `tests/gestures.gd`)

New seated gesture `sitcup`, NPCs only: while typing with a cup on the desk the near hand slides over to the cup, takes it along
and puts it back, no sip. No new frames and no anim rebuild: it plays `sitmouse_<facing>`; from frame `Npc.CUP_REACH_FRAME` (1)
the cup leaves the desk for the hand (`held_item.gd` already has the hand positions of the sitmouse frames) and it stands on
the desk again at the end or when the gesture is cancelled. `SeatLife.BASE.sitcup` 1.5 (Alan 3.0), weight 0 unless typing with
a cup in reach. `tests/gestures.gd` allowed "only the sip and head gestures" with a drink; it now allows the cup reach too.
The player has no `sitcup` (the player sips with F). The real head turn is skipped (needs art).

## 9. X12 housekeeping

**The takeover visit through its real trigger** (test `tests/takeover_trigger.gd`). The scripted run plays the rival arc the way the
owner campaign does (week 6 settles, the week 7 notice, the client leaves, week 10 settles, the week 11 card, SEND DAN FOR A
TAKEOVER ASSESSMENT) and found that **the real trigger never started a visit**: `Owner.apply` ran `visit` before the `rival` ops
of the same fx, so the client was not back yet and `Takeover.target()` found nobody. That is why no takeover visit came up in any
bot seed. Fixed: `visit` is applied after `rival`. A returning client without an office (only six clients have a site in `Onsite.SITES`; of the
starting five, two have none) gets no visit and now inherits nothing (`Takeover.visit` returns before `begin`), because the findings only show on a walk-around.
The test then reads the whole visit: the notice and the takeover card, the meeting and its answers, the six finding cards (all
six come up on one walk-around), the quick patch lines, and every step and choice of the six Playbook jobs. "Reads" = not empty,
only characters the pixel font has, no placeholder left in, and the card fits the wide, 16:9 and tall screens (the arithmetic
of `Cards._paint`).

**Jen's walk** (test `tests/jen_walk.gd`): the route main floor -> cubicle area (`ToCubicleTwo`) -> cubicle two and back, every
door inside its room and landing on a spawn of the next; off screen the World walks her through the three rooms to a seated
work leg at Seat1; on screen, in the real scenes, she walks to each door, leaves, appears at the next room's spawn and sits
down at Seat1.

## Decisions made

- **Overtime = sudden death with no respawns**, not "next tag wins" (a coin flip two seconds in) and not "next flag only" (a
  flag comes home about once a minute, so half the level matches would still end level). A wipe ends it at once.
- **The rivals' aim pays for the overtime** (`RIVAL_EDGE` 2.75): the scripted player wins about seven overtimes in ten, so the
  normal tier went to 77 % wins before the change. The captures to win, the clock and co-op's `COOP_EDGE` are untouched.
- **A co-op duel is a friendly**: 1 star and no Career win, so BUMPER KING and CHAIR FIGHT BEST still mean beating the crew.
- **Phone levels are pips plus the name on the selected row**; the role stays visible on every other row.
- **Friend hints are themed by word replacement**, not by 90 new lines: one table of nouns per room, and the owner's edits of
  `FRIEND_HINTS` are themed for free. A few hints have no furniture in them (Morgan's "THERE IS MATH ON THE BOARD") and read the
  same in every room.
- **The hello is Garrison's card** and each answer moves exactly two people by at most 2; the quiet answer has no downside and
  the smallest upside. It hangs off Dan's answer instead of being a timed event.
- **The favour is the only card routed to a player.** Morgan's talk about it stays a team card.
- **The cup reach reuses `sitmouse`** (the arm that slides forward on the desk) with the cup as the held item.
- **H14's finding is certain, once per client**, instead of one more entry in the random pool: it does not shift the seeded
  walk-around draws of old seeds, and it is a nudge towards the habit rather than a recurring nag.
- **H3 gives money back** (`overrun_back`) instead of changing the card's numbers, so the card text ("You ate $1,200") and the
  roll table stay as they were for a player without the habit.
- **No takeover for a client without an office** rather than a risk meter nobody can ever look at.

## Left open / wanted

- A takeover assessment for the clients without a site (the six findings as a written report, or a stand-in office).
- Player 2's stamina bar in the duel is a half-width bar; a fight HUD drawn for two would be nicer.
- The paintball overtime has no art of its own (it is a line of text and an amber clock).
- `docs/dev/balance_baseline.json` was not regenerated (not allowed in this batch): paintball's `RIVAL_EDGE` and the takeover
  visit change what an owner bot can run into.
- Art wanted: none drawn. A cup-reach pose of its own (the hand closing on the cup) would read better than the mouse slide.

## Owner bot check (`tests/bot_run.gd -- owner normal <strategy> seeds=2 ts=4`, one process at a time)

Run because section 9 changes when a takeover visit can start. No campaign balance number was changed.

| Code | careful seed 1 | careful seed 2 | shortcut seed 1 | shortcut seed 2 |
|---|---|---|---|---|
| main before this batch (`db68104`) | not run | not run | FIRED week 16, $49k | $352k, rep 90 |
| this branch | $1,003k, rep 91 | $579k, rep 68 | FIRED week 15, $29k | $0, rep 65; a second run of the same seed: $65k, rep 84 |

- Every run ended, nobody hung on a visit, and `bot_run`'s CHECK line passed (shortcut far below careful, not fired every time).
- `takeovers 0` in every row, before and after: the bots' answers in weeks 7 and 11 never lead to the takeover card's first
  answer, so the bot seeds still do not exercise the visit. `tests/takeover_trigger.gd` is the proof that it starts.
- The shortcut owner of seed 1 is already fired on main (the owner notes measured 0 of 3 fired before the six branches were
  merged). Seed 2 moved a lot between two runs of the same code ($0 and $65k), so two seeds say little: the balance run with
  more seeds should look at the shortcut cell again.

## Tests

| Test | What it proves |
|---|---|
| `r38_leftovers.gd` | H9, H3, H14, the TESTED date (and its save), the Hollis favour |
| `paintball.gd` | the overtime rules (changed on purpose from "time up level is a draw") |
| `paintball_tuning.gd` | the tuning bands, draws under 12 % on every row |
| `toolbox.gd` | the EVENT and MATCH rows |
| `coop_chair_duel.gd` | the duel's rules, both players' keys, the duel in the warehouse |
| `phone_levels.gd`, `layout_audit.gd` | levels on the contacts |
| `escape_friend_hints.gd` | every friend x zone x theme |
| `first_day.gd` | the hello card, opinions, the echo, the save, the first ticket's timer |
| `coop_favour.gd` | the favour card in the closer's pane, applied to the closer |
| `sitcup.gd`, `gestures.gd` | the cup reach |
| `takeover_trigger.gd` | the real trigger, the whole text of the visit, the client without an office |
| `jen_walk.gd` | Jen's route, off screen and on screen |
