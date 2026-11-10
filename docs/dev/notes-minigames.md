# Build notes: chairs (R12) and paintball (R41), Nov 2026

What this batch added to the rolling chairs / chair race and to paintball, the public functions, the tuning numbers and the tests.
No new art and no new sounds (existing `Sfx` ids only).

## R12 chairs

### Pushing somebody else's chair (`scripts/chair_shove.gd`)

- Standing next to a seated coworker, **hold Shift (run) and press E (interact)**: their rolling chair rolls away from you with them
  in it. Plain E still talks to them. On a pad: hold B, press X. The actions are the existing `run` and `interact` of the player's
  slot (no new input action, no raw key read).
- `ChairShove.try_shove(player) -> bool` (static, called from `player.gd` `_physics_process` before the normal `nearest().use()`):
  finds an occupied seat in the player's `_near` within `REACH` 30 px, the NPC sitting in it (`_sitter`: skips somebody in a
  conversation or on a call (`_hold > 0`), hidden, or an expo `role`), puts a `ChairShove` node under the seat and kicks it
  (`SHOVE` 64 px/s away from you, x0.6 on a sticky wheel). false = nothing to push, the E goes on as usual.
- The node owns a `chair_roll.gd` bound to the seat (`bind`: the chair sprite, the limits `lo` / `hi`, the sticky wheel), so the
  walls, the desk and the props stop it exactly like your own chair (reused physics: `FRICTION`, `_move`, `_place`). The coworker's
  x follows the seat. After `HOME_AFTER` 3 s standing still they scoot back (`HOME_SPEED` 38 px/s) and the node frees itself. If
  they stand up meanwhile the chair snaps home (as an empty rolled chair does).
- Reaction (the bump rules of `chair_roll.gd`): friendly +1 and a heart, cold or hostile -2, otherwise the `REACT` base (Alan -1,
  the rest 0) with a line each; one opinion change per person per 25 s (`WHO_MS`, static across pushes). No energy relief for
  rolling somebody else.
- Career: `Career.note_shove()` -> counter `chair_shoves`, medal **PUSHY** at 10.
- Test: `tests/chair_shove.gd` (the real main floor: push from both sides, limits, the ride, the way home, opinions, the 25 s
  rule, standing up mid-roll, empty chair / busy coworker / out of reach, the medal).

### The chair fight (`scripts/chair_fight.gd`)

- The third event on the chair race card. A `RefCounted` with no autoload references, like `chair_race.gd`; it has the fields
  `chair_track.gd` reads (`pos`, `lane`, `wobble`, `face`, `rivals`, `obstacles`, `checks`, `length`, `arena`, `fight = true`), so
  the race's puppets and side-scrolling drawing are reused as they are.
- Rules: two chairs on a strip of the warehouse floor (`LO` 250 to `HI` 510 as course positions, three lanes).
  `push(key)` is the race's push to the number (the same rhythm bands, impulse and stamina constants of `ChairRace`), in the
  direction the chair faces. `spin(dir)` turns the chair (`TURN` 0.3 s without a push). `change_lane(dir)`.
  When the chairs meet in one lane (`HIT_X` 15 px, `HIT_LANE` 0.62): whoever rolls at the other faster by `EDGE` 7 px/s (and at
  least `MIN_BUMP` 16 px/s) lands a bump; the other chair is knocked back, dizzy for `DIZZY` 1.3 s and safe for `SAFE` 2.4 s.
  About the same speed is a clash (both bounce, no point). A chair that is dizzy, turning or facing away is not attacking, so it
  is bumped as soon as you reach `MIN_BUMP`. The ends of the strip are walls (bounce x0.25 over 20 px/s).
  First to `TARGET` 3, or the most bumps at `LIMIT` 75 s. Stars: a win with at most one bump against 3, any other win 2, a draw
  or a loss with two bumps 1, else 0.
- The opponent is one of the racers who came, drawn on the seeded `chair` stream (`params.opponent` fixes it); the other racers
  are puppets watching from the two ends. With nobody in the party the opponent is Garrison.
- The crew's driver (`_drive`, per name in `STYLES`: skill, dodge, chase): faces you (a reaction beat), pushes at a gap its skill
  allows with now and then the wrong leg, rests when out of breath, follows you into your lane after a beat, and the careful
  ones step aside when they are about to lose a head-on. `you_auto` puts the driver in your chair too (tests, demos).
- Tiers: `chair.stamina` scales your push cost only; `chair.skill` (-0.08 / 0 / +0.08) is multiplied by `TIER_SKILL` 2.5 for the
  opponent (in a duel their legs are all there is).
- Bot result (`tests/chair_fight.gd`, a scripted average player, 80 fights per tier = 5 opponents x 16 seeds): wins
  **66 % easy, 55 % normal, 26 % hard**, about 20 s a fight, every fight ends, 600+ bumps in 240 fights.
- Co-op: the tandem of the race applies (player 1 pushes Z, player 2 pushes X); turning and lanes are player 1's keys.

### The second course: THE GAUNTLET (`scripts/chair_race.gd`)

- `ChairRace.COURSES` / `COURSE_ORDER`: `straight` (the old course, untouched, prop for prop) and `gauntlet`: 684 px (the line is
  drawn in code on the floor by `chair_track.gd`, a checkered stripe with FINISH over it), 11 zones 56 px apart, two props in
  every zone, the empty lane always one lane over from the last one, two checkpoints, star times x0.76.
- A race now has `course`, `length`, `checks`, `check_names` and `cp(i)`; `params.course` picks the course (unknown = straight).
  The static `LEN`, `CHECK_FRAC`, `CHECK_NAMES`, `check_pos` are still the straight's.
- The best time is kept per course: `Outings.chair_best[tier]` for the straight (as before), `"<tier>:gauntlet"` for the gauntlet.
- Bot result (`tests/chair_course.gd`): the driver bot finishes clean on every tier and seed (36 of 36), 3 stars reachable on
  12 / 12 / 11 of 12 seeds (easy / normal / hard); ploughing down one lane hits 5+ props.

### The chair card (`scripts/outings.gd`)

- `CHAIR_EVENTS = ["straight", "gauntlet", "fight"]`, `Outings.chair_event` (the pick, kept for the session, not saved).
  LEFT / RIGHT (or A / D, or a pad's stick) on the intro page cycles it (`_page_pick`); the room is re-dressed at once
  (`_chair_clear` + `_chair_setup`). The seeded stream is rewound to where the card opened (`g.rng0`), so looking at the other
  events does not use up draws. `opts.event` (and `opts.opponent`) fix the event for the toolbox and the tests; then the card
  cannot change it.
- `g.event` says what is being played; `g.race` is the `ChairRace` or the `ChairFight`. `_career_game()` is `"chairfight"` for
  the fight (its own `best`, its own Career stars; no mastery line), `"chair"` for both courses.
- HUD: the fight has its own strip (`_hud_fight`: the Z / X keys, the clock, three pips a side, the strip of floor with both
  chairs, stamina) and overlay page; the race's strip now reads the race's own `length` and `checks`.
- `CHAIR_KEYS` gained LEFT / RIGHT / A / D (the fight's turn keys; in a race they do nothing).

### Career (`scripts/career.gd`)

`Career.note_outing(game, result, info)` now reads `info.chair` (`{course, won, clean}` for a race, `{fight, won, bumps}` for the
fight) and `info.caps` (paintball).

| Medal | Rule | Counter |
|---|---|---|
| CLEAN LAP | a finished race, nothing hit, no false start | `chair_clean` |
| SPEED DEMON | win 3 chair races (first place, with rivals) | `chair_wins` |
| TRACK RAT | finish both courses (1+ star on each) | `chair_courses` (`course.<id>`) |
| BUMPER KING | win 3 chair fights | `chairfight_wins` (`chair_bumps` counts bumps) |
| PUSHY | push 10 coworker chairs | `chair_shoves` |
| FLAG RUNNER | carry 5 flags home at paintball | `flag_caps` |

New career screen rows: CHAIR RACES WON, CHAIR FIGHT BEST (`stars.chairfight`), CHAIR FIGHTS WON, CHAIRS PUSHED, FLAGS CARRIED
HOME. `WAREHOUSE_GAMES` is unchanged (the fight does not count for WAREHOUSE ALL-STAR). The medals are appended to
`DEFAULT_MEDALS`, so the `Career.MEDALS.<n>` ids in `story/strings.txt` of the older medals did not move (53 to 58 are new).

## R41 paintball

### Co-op: player 2 pilots a team mate

- `PaintGame.setup(params, names, rng, humans := 1)`: with 2, unit 1 (your first team mate) is named `P2` and is `human`; the crew
  moves down one place and the fifth sits out. `human(i)` says whether a person holds unit i (false for everybody with
  `you_auto`). `set_move_of(i, dir)`, `set_duck_of(i, on)`, `change_lane(i, d)`, `fire(i)` are the controls of any piloted unit
  (`set_move`, `set_duck`, `lane_you`, `fire_you` are still unit 0's). A piloted unit has the short reload and your aim.
  `p2_tags`, `p2_caps` count player 2's; `stars()` and the Career's flags count both pilots.
- `Outings._paint_setup` passes 2 when `Players.coop and Players.slots[1].joined` and gives the puppet player 2's own look.
  `_paint_tick` reads player 2's `move_left` / `move_right` / `run` actions (`Controls.action_for(1, ...)`), `_paint_press` moves
  whoever pressed (`_press_slot`), `_event_key_p2` turns player 2's A / X into fire. The result page has a line for player 2.
- The track leans the camera towards player 2 (up to a third of the screen), draws both pilots' tags in gold and keeps a pilot's
  tag at the edge of the screen when they are out of view. Player 2's real body was already hidden during the match.
- With two pilots the other team's aim is x`COOP_EDGE` 1.4.
- The team is the red one: the brief said "one of the blue team", but in the code the player's team is team 0, drawn red;
  player 2 joins the player's side.
- Test: `tests/coop_paintball.gd` (the handlers are called directly: a second pad's events do not reach an autoload's `_input`
  in a headless run; the held stick and duck button are pressed through `Input.action_press` on player 2's own actions).

### The night match

- `params.night` -> `PaintGame.night`, `reach = RANGE x NIGHT_RANGE` (0.82: 139 px instead of 170, for both sides).
- `Outings.paint_night`: drawn when the card opens on the seeded stream `Difficulty.rng_for("paint.night", Outings.count)` (about
  one evening in three), LEFT / RIGHT on the card switches it, `opts.night` fixes it.
- Drawing, all in `paintball_track.gd` over the existing set (no new art): a dark blue wash over the art (`NIGHT`), everybody and
  every prop in `Actors` tinted (`NIGHT_ACTORS`, restored by `clear()`), 70 fixed stars that twinkle and a crescent moon above
  the roofs, the four saloon windows, the saloon doorway and the jail window lit with a glow and a patch of light on the porch,
  a muzzle flash (`FLASH` 0.11 s) at every shot and a halo around flying paintballs.

### FLAG RUNNER

`flag_caps` counts the flags you (and player 2) carried home; the medal is at 5. The tuning run has the scripted player at
about 1.0 to 1.3 flags a match on normal, so it is four or five decent evenings, sooner on easy.

### The tuning run (`tests/paintball_tuning.gd`, `tests/bot_paint.gd`)

The bot stands in for the human play-test. `bot_paint.gd` is a scripted average player: it plays one piloted unit through the
keys' own calls and has a person's limits (0.32 s to notice somebody in its lane, 0.12 s late on the trigger, a decision about
lanes and cover every 0.5 s: sometimes it sidesteps out of the line of fire while it reloads or carries the flag, sometimes it
ducks behind a barricade, half the time it goes after a rival in the next lane). It runs for the flag, covers a team mate who
has it, and chases a carrier who is close.

**Before** (the rules as they were, 30 seeded matches a tier, 30 steps a second):

| tier | win | draw | loss | length | captures | your captures | your tags |
|---|---|---|---|---|---|---|---|
| easy | 97 % | 3 % | 0 % | 135 s | 2.5 | 1.93 | 18.1 |
| normal | 97 % | 3 % | 0 % | 137 s | 2.5 | 2.07 | 17.4 |
| hard | 87 % | 13 % | 0 % | 142 s | 2.0 | 1.63 | 17.9 |

Lopsided on every tier: the player never lost, and almost every capture of a match was the player's (the crew hit about one
shot in ten and a crew member with the flag walked down one lane until somebody tagged them).

What the sweeps showed (`-- --sweep`, normal tier):

- Crew aim alone (`AI_ACC` 0.18 -> 0.3 / 0.4 / 0.5 / 0.6, both teams): wins 70 / 60 / 45 / 10 %, but the rest are draws
  (25 / 35 / 40 / 90 %) and captures fall to 1.6 / 1.1 / 0.9 / 0.2 a match. More paint in the air means nobody gets home.
- Captures to win and the clock (to 2 in 150 s, to 3 in 120 s / 180 s, to 4 in 180 s): 100 / 90 / 100 / 100 % wins. They do not
  touch who wins. `TARGET` 3 and `LIMIT` 150 s stay.
- Your own aim x0.75 / x0.55: still 85 to 95 % wins.

**What was changed** (`paintball_game.gd`):

1. `RIVAL_EDGE` 2.3: the other team's aim is x2.3 (times the tier's `paint.skill`). `paint.skill` now scales the other team
   only (it used to scale your team mates as well, which is why the tiers barely differed). With `you_auto` (the crew in every
   unit) the edge is off, so the all-crew matches of `tests/paintball.gd` stay even.
2. `_ai_carry_lane` / `CARRY_DODGE` 0.8 s: a crew member with the flag steps out of a rival's lane after a beat (both teams).
   The crew really score now: 78 captures in the 20 all-crew matches of `tests/paintball.gd` (team 0 wins 9, team 1 wins 9,
   2 draws); the test asks for 12.
3. `CARRY` 0.85 -> 1.0: a flag carrier is no longer slowed. With the slowdown most matches ended level.
4. `COOP_EDGE` 1.4: x on the rivals' aim with two pilots (two bots won 97 % without it).

`AI_ACC` (0.18), `YOU_ACC` (0.8), `FIRE_GAP`, `AI_GAP`, `RESPAWN`, `TARGET` (3) and `LIMIT` (150 s) are as they were. The match
can also take `crew_acc`, `rival_edge`, `carry_dodge`, `respawn`, `carry`, `target`, `limit` in `params` (the sweep uses them).

**After** (`-- --full --seeds=100`: 100 seeded matches a row, 30 steps a second, all the test's bands hold):

| tier | win | draw | loss | length | captures | your captures | your tags |
|---|---|---|---|---|---|---|---|
| easy | 79 % | 13 % | 8 % | 137 s | 2.4 | 1.47 | 19.7 |
| normal | 57 % | 29 % | 14 % | 144 s | 2.2 | 1.24 | 19.4 |
| hard | 32 % | 34 % | 34 % | 145 s | 2.1 | 0.89 | 17.8 |
| easy (night) | 72 % | 19 % | 9 % | 133 s | 2.9 | 1.59 | 17.4 |
| normal (night) | 52 % | 33 % | 15 % | 142 s | 2.6 | 1.34 | 17.5 |
| hard (night) | 38 % | 39 % | 23 % | 144 s | 2.8 | 1.28 | 16.8 |
| normal, co-op (two bots) | 59 % | 38 % | 3 % | 148 s | 1.1 | 0.59 | 17.2 |

The same run with the default 30 seeds: easy 83 / 10 / 7, normal 47 / 33 / 20, hard 37 / 33 / 30, normal at night 60 / 27 / 13,
co-op 63 / 37 / 0 (win / draw / loss, %). Thirty matches move a row by about nine points either way, which is why the table above
uses a hundred. Co-op is the weak row: with the rivals' extra aim two pilots rarely lose but a flag gets home only about once a
match, so more than a third of the matches end level.

The default test run (`tests/paintball_tuning.gd`, 30 seeds, about a minute) asserts: every match ends; normal 45 to 65 % wins;
easy clearly easier and not above 92 %; hard clearly harder and not below 15 %; losses rise with the tier; a flag is carried
home in 75 % of matches or more; no row has more than 45 % draws; normal at night 40 to 70 %; co-op within 10 points under the
solo rate and not above 85 %. `-- --full` adds night on easy and hard, `-- --seeds=N` changes the sample, `-- --sweep` runs the
rows of `SWEEP`.

Draws stay common (a quarter to a third of the matches on normal): a match that ends level is 1 star and the crew says so.
An overtime rule (next flag wins) would cut them; it was left out because `tests/paintball.gd` pins "time up level is a draw".

## Decisions made

- **Push = Shift + E**, not "run into the chair": you run past seated coworkers all day, a push has to be meant.
- **The fight and the second course live on the chair race card** (LEFT / RIGHT), not as new outings: same room, same cost,
  same invitation, no new entry in the "where to?" list. The card opens on the last event you picked (the straight at first).
- **The fight is a duel against one crew member** drawn on the seeded stream, first to three bumps, 75 s; the others watch.
- **The fight has its own Career stars** (`stars.chairfight`) so a won duel is not a 3 star race for WAREHOUSE ALL-STAR.
- **THE GAUNTLET ends before the painted finish line**, with its own line drawn in code (no new art).
- **Night is cosmetic plus one symmetric rule** (the shorter range). It is drawn on its own seeded stream, so the `paint` stream
  of an old seed deals the same match as before.
- **Player 2 joins the player's team** (red in the code) in the first team mate's place.
- **FLAG RUNNER at 5 flags**, counted over a lifetime, player 2's flags included (the Career is shared).
- **The tuning changed the rivals' aim, the carrier's speed and the crew's flag running**, not the captures to win or the clock,
  because the sweeps showed those two do not move the win rate.

## Tests

| Test | What it proves |
|---|---|
| `tests/chair_shove.gd` | pushing a coworker's chair on the real main floor, opinions, limits, the way home, PUSHY |
| `tests/chair_fight.gd` | the fight's rules, 240 bot fights (3 tiers x 5 opponents x 16 seeds) all end, the card, the outing, the Career, the fight in the warehouse |
| `tests/chair_course.gd` | THE GAUNTLET's shape over 30 seeds, the bot finishes clean on every tier, the straight is unchanged, best time per course, CLEAN LAP / SPEED DEMON / TRACK RAT / FLAG RUNNER, the gauntlet in the warehouse |
| `tests/coop_paintball.gd` | player 2's unit and controls, two-bot matches end, night range, the pick on the card, the night field with two pilots in the room |
| `tests/paintball_tuning.gd` | the tuning table and its bands (uses `tests/bot_paint.gd`, a library: the `bot_*.gd` pattern keeps it out of the suite) |
| `tests/layout_audit.gd` | new block: the gauntlet and the fight (intro, playing, the in-room HUD strip, result), the night intro, paintball's HUD strip, in all three formats |

Existing tests run and passing after the change: `chair_race`, `chair_roll`, `coop_chair`, `coop_chair_body`, `paintball`,
`paintball_room`, `career`, `career_key`, `career_screen_detail`, `strings`, `canon_text`.

## Left open / wanted

- Art that would help (none was drawn): a painted finish line and a "ring" for the fight on the warehouse floor, a night
  version of the western set (lanterns, a lit sign), a pushing pose (the push uses `reach`).
- The Free Play toolbox has no entries for the chair events or the night match (`opts.event`, `opts.opponent`, `opts.night`
  work when passed to `Outings.start`).
- Co-op chair fight is the race's tandem (one chair, two pilots). Two chairs for two players, fighting each other, is not built.
- `docs/dev/balance_baseline.json` was not regenerated: paintball's results in it (if any cell plays it) are from the old rules.
