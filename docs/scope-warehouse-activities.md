# Scope: warehouse activities (roadmap R21): the grill, cornhole, the overhead door

**Built (Nov 2026): A (the grill / cookout) and B (cornhole)**, see CLAUDE.md "Cornhole and the cookout". Differences from this plan: both are drawn by `fx.gd` in code (no sprite art, `warehouse_set.lua` untouched), the cornhole boards are at set x 1140 and 1236 with you and the crew member of the round at the two ends (bags fly both ways), the grate is a HUD box because the grill sprite is only 32 x 36, hot dogs and the toss pose were left for R29 (**now built**, Nov 2026: the `toss` pose, hot dogs on the grate with one flip, and a campaign lunch break, see CLAUDE.md "Hot dogs and the lunch break"), `Career.GAMES` was left as the four classic games (FULL HOUSE keeps its meaning). C (the overhead door) is another agent's.

Read-only scoping pass (Nov 2026) from the code and docs, nothing was run. Line numbers drift. The warehouse itself (R18 phase 1) is built: `tools/warehouse_set.lua`, `godot/scenes/warehouse.tscn`, `tests/warehouse.gd`.

## What shapes the designs
- Mini-games are outings run by `Outings` (`outings.gd`: `ROOMS`, `SPOTS` with six x positions in cast order, `start()` which calls `World.start_outing` and `Game.go(room, "from_outing")`, `_finish`). The warehouse needs a `from_outing` spawn (it only has `start`, `from_main`, `from_closet`).
- The chair race has no `ROOMS` entry and opens in place: the precedent for playing inside the warehouse in Free Play (O key, `pick_game` card, `cost_range` loop over `GAMES`).
- Bowling is the model: aim and power, `_room_wants`, `_bowl_others` / `BOWLERS` for the crew's turns, `CREW_LINES`, live fx drawing (`bowl_lane`). Results: opinions +(1 + stars), energy +(4 + 2 x stars), owner burnout, 3 stars = reputation +1; `Career.note_outing`, `Career.GAMES`, medals; toolbox `GAMES`; `Difficulty.TABLE` keys and `Difficulty.rng("grill")` / `rng("cornhole")`.
- Existing player animations: `reach`, `hold`, `sip`, `talk`, `wave`, `dance`. There is no throw or flip pose.
- The grill is a plain 32x36 prop sprite near set x 1309; interact zones are an Area2D pointing at an `fx.gd` node (see the dart board).

## A. Grill: COOKOUT (`grill`)
- E at the grill starts it. Four burgers on the grate: arrows pick a slot, E flips, Space pulls the burger onto a plate and serves the oldest matching ticket, Shift (hold) moves it to the cool side during a flare-up. Works with the D-pad.
- Each side has a cook value 0 to 1: raw below 0.35, medium 0.35 to 0.55, done 0.55 to 0.8, burnt above 0.9; the flip window is 0.35 to 0.7. Seeded flare-ups cook one slot at double speed. Hot dogs are an optional second item.
- A round is 6 tickets in 75 s ("2 WELL, 1 MEDIUM", "NO CHEESE") from named coworkers who queue with bubbles. Stars: 3 = at least 5 of 6 correct with nothing burnt, 2 = at least 4, 1 = at least 2.
- Tier keys (inferred): `grill.cook_rate`, `grill.window`, `grill.tickets`, `grill.time`, `grill.flare`. Cozy Easy: no flare-ups, no timer penalty, burnt burgers are "crispy, the crew eats them", floor of 1 star.
- Art: patties, smoke and flames drawn by the fx in code (rects), generic names only ("BURGER", "DOG", "SMOKY SAUCE"); procedural Sfx for sizzle, flare whoosh and a bell. Player uses `reach` to flip and `hold` to serve.
- Rewards via `_finish`; a campaign lunch break (R29, built) is its own card at noon on lunch days, not an evening outing day.

## B. Cornhole (`cornhole`)
- Like bowling: E stops an aim marker (sideways lane), E stops a power bar (distance). Board = 1, hole = 3, bags cancel, four bags a turn, play to 21 (tier keys `corn.to` 11 / 15 / 21), you against one crew member a round; skill tables per person: Alan precise, Garrison streaky, Dan wild, Maya steady, Vic show-off with an audience bonus; reuse `CREW_LINES`.
- Flight arc: a new fx kind `cornhole_bag` (side-view parabola). Stars: win by 7+ = 3, win = 2, loss = 1 on cozy Easy (with a short-miss slide assist).
- **Where:** boards at set x about 1125 and 1275 between the FINISH line (1100) and the dock, low and non-colliding, so the walkway stays clear. The chair race ends at 1100 so it does not need that stretch. Fallback: park them off-lane like the race props and move them in only while playing.
- Throw pose: `reach` in v1, **the `toss` pose since R29**; (it needed a `poses.lua` edit and a rebuild of every character's animation files).
- Tier keys: `corn.opp_skill`, `corn.aim_speed`, `corn.power_speed`, `corn.to`.

## C. Overhead door and the outside
**BUILT (Nov 2026, R21 part c):** see CLAUDE.md "The warehouse" (R21c). Left for later: a walkable `warehouse_lot` scene, the chair race rolling the door up at the start.
- The door is already its own 120x80 sprite (set x 1287); the doorway is drawn into the baked background.
- **Outside:** a separate backdrop node behind the Background, with a transparent hole in the baked art, so the sky can follow the game clock (morning, noon, late afternoon, dusk) with a gradient and clouds drawn in code. One ~120x80 pixel lot image (asphalt, painted lines, two 2013-14 cars, the company van, a light pole, a dumpster, a fence).
- **Door:** an fx kind `roll_door` with `open` 0..1 in 12 fps steps (the slats rise, clipped). A wall switch prop beside it with a normal-priority interact zone (so it beats the dart board), rattle and thunk sounds; warm daylight spill on the floor when open; door state kept as a field and saved with the scene; independent of `World.lights`.
- **Walking out:** a view only in v1; a `warehouse_lot` scene is large (new set, links, spawns, cast routing), so later.
- **Chair race:** the door starts closed; rolling it up at the start is an optional cinematic.
- Cost: S for the switch and door fx, M for the backdrop and the baked-art hole, S for the sky and sounds, S for tests.

## Integration
- `Outings.GAMES`: `grill` ($150 for the owner) and `cornhole` ($100) with labels, blurbs and key hints, plus the invitation card text; `ROOMS`, `SPOTS`, a warehouse `from_outing` spawn, a small branch in `start()` for in-place play; `Career.GAMES`, counters (`burgers_served`, `bags_in_hole`) and medals (GRILL SERGEANT: a run with nothing burnt, BAG MAN: 10 in the hole); toolbox `GAMES` and `GAME_LABELS`; `strings.txt` sync for the patchable text.
- Tests: `tests/grill.gd`, `tests/cornhole.gd` (state machines, tiers, cozy floor), rows in `tests/outings.gd`, toolbox, `layout_audit` screens, a deny-list check for real brand names, door tests in `tests/warehouse.gd` (switch toggles state, door at 0 and 1, sky tint per clock phase).

## Steps
- **Cornhole first (cheaper: reuses bowling):** (1) `GAMES` / `ROOMS` / `SPOTS`, boards, zone, spawn (S); (2) aim, power, bag flight, crew turns (M); (3) rounds to 21, stars, tiers, HUD strip (M); (4) Career, toolbox, tests (S); (5) optional toss pose (M).
- **Overhead door (independent):** switch and door fx (S), backdrop, hole in the art, sky and sounds (M), tests (S).
- **Grill (a new real-time per-item system):** (1) spawn, entries, zone, fx stub (S); (2) cook state machine, tickets, tiers (M); (3) HUD strip, patties and smoke drawing, sounds (M); (4) Career, toolbox, tests (S); (5) crew lines and queue bubbles (S).

## Risks
The warehouse is a dead end behind the closet (teleporting the cast in and back should work as for other rooms, `World.end_outing`); in-place Free Play inside the warehouse needs a new branch; wide 368x128 is small, so the HUD strip must fit 164 px; a campaign lunch break is new design.
