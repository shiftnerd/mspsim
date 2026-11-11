# Notes: art-people (new characters, R23 conference audience)

## Quinn, Ross Calder, Terry Vance (Year 3)

- Drawn with the CHARS tables: `office_quinn` in `tools/make_fem.lua` (new hair style `twin`: two buns on the cap, black hair,
  magenta tee `#D0508A`, khakis, red sneakers), `office_ross` and `office_terry` in `tools/make_men.lua` (donor `office_dan`,
  long sleeves). Ross: silver hair, glasses, deep green button-down, black trousers (Summit buyer). Terry: sandy slicked hair,
  lavender button-down, tan trousers, brown shoes (the headhunter). Files in `sprites/staff/`, anim files built with
  `ONLY = {"office_quinn", "office_ross", "office_terry"}` (135 frames), `EXTRA_CHARACTERS` has the three, `characters/*.tres` generated.
- **Quinn on the floor**: `World.STAFF_CAST["Quinn"]` (home `conference`, `Seat6`, role `newhire`: hot-desks at the conference
  table like Terry the tech; there is no free desk on the floor). `roster_gone()` removes her unless the tech campaign runs in
  Year 3 (`Campaign.year >= 3`). `Yeartwo.beat()` sends her out with `World.force_activity("Quinn", "floor")` for the `newhire`
  (day 3) and `mentor` (day 11) beats, so she walks the main floor when the card opens.
- **Visitors**: `SalesBeats.buyer(stage)` (owner campaign, Year 3, the day of the `summit` beat, role `visitor:buyer`) and
  `SalesBeats.headhunter(stage)` (service campaign, Year 3, the day of the `terry` beat, role `visitor:headhunter`), called from
  `stage.gd` next to the auditor and the recruiter. `_visitor` got an optional `mode` argument (default `sales`).
- Test: `tests/year3_people.gd`.

## R23: the speaker talks, four people listen

- The four breakout rooms keep their speaker (`role speaker`) but his routine is now `talk:7 wait:2 talk:6 wait:3` (the `talk`
  frames, a speech bubble) instead of wait / say.
- Each room has three more seats (`Seat4` to `Seat6`, on the back row of chairs, y 103) in the scene, `world_data.gd` and the
  generator's `seats=` lists. Two audience members (`role audience`, `expo_atta` ... `expo_attf`, no new art) sit in `Seat4` and
  `Seat6`; with the two that were already there that is four per room, and two chairs stay free for you. Seated NPCs run the
  seated life poses by themselves (`npc.gd` with `seat_life.gd`).
- Test: `tests/conference.gd` (`_check_audience`).

## Decisions made

- Quinn hot-desks at the conference table (no free floor desk); no room set was changed for her.
- Ross and Terry are visitors (`office_` names like Trent and Pell), not staff: they walk in on the beat day only.
- Audience stays at four per room (the cap was six): more would leave the player no free chair.
- Not seen in a game screenshot: the new seats and the audience were checked by tests, not by eye.

## R28 again: WSUS_Walt

- `expo_walt` (`tools/make_men.lua`): glasses, cream short-sleeve shirt with a logo badge, navy trousers, grey-brown comb-over.
  Stands in the resort lobby (x 160, between Ray and Grizzle). Card `Expo.FORUM` id `walt` (inserted before Dot, so the
  `# Expo > FORUM` section of `strings.txt` was deleted and re-synced): patch window (+4 servers), the reboot (+3 customer),
  upvote his Friday rule (+3 karma), admit a Friday patch (+1 social). `Nerds.POSTERS` REGULAR, one post in the "Patch Tuesday
  auto-approve rules" thread. Test: `tests/forum_people.gd`. Strings are a first draft.
