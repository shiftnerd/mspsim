# Build notes: outings and the conference venue (R6, R30, R4 E5, R23 / P5)

Batch of Nov 2026, branch `worktree-agent-a0bd3145058dbde91`. Four roadmap rows, each a tested first version.
All player-facing wording is a first draft (patchable in `godot/story/strings.txt`).

## R6 dinner variety (`scripts/outings.gd`, section "dinner variety (R6) and the dinner ramp (R30)")

**Switch.** Everything below is on only for a dinner started with `options.variety` (`_game_options("dinner")`: the
invitation and the Free Play O card; the sales client dinner passes it too). A dinner started without it (tests, the
toolbox) is the classic five rounds, so the older tests are unchanged. Every draw has its own seeded stream
(`dinner.order`, `dinner.events`, `dinner.guest`, `dinner.drift`, `dinner.hints`); the classic `dinner` stream keeps its
sequence (the same seed deals the same four topics, with ASK HOW THEY ARE taking slot 1).

- **D4 ordering round** (`_dinner_order_setup`, `dinner_ordering()`, `dinner_order(i)`, `dinner_rows()`): before the
  topics the list shows four shared plates (`DISHES`, 13 plates with tags). Each person avoids one tag (`DIETS`: Alan
  mushroom, Garrison meat, Dan spicy, John seafood, Maya gluten, Morgan onion; `DIET_TEXT`). `Difficulty dinner.fits`
  (3 / 2 / 1) of the four suit everybody. A plate that suits everyone: table +2 (`ORDER_BONUS`). Otherwise no bonus,
  the people it does not suit are learned (`known[who].diet`, `diet_since`) and that plate carries a red tick next
  time. Nobody is teased for it (the caption is "a side salad is ordered and nobody makes it a thing"). A test that
  calls `dinner_talk` straight away skips the plate.
- **D5 a client at the table** (`_dinner_guest_setup`, `dinner_guest()`, `_guest_react`): owner campaign = the client
  John brings (`Outings.guest_client`, already drawn by `draw_party`); tech campaign = a client comes to 40% of the
  team dinners (`TECH_GUEST`, drawn on `dinner.guest`); sales client dinner = the prospect (name only);
  `options.guest = client index` forces one (tests, a future toolbox row). The guest is not a diner (no seat, no star
  bar change): each round slot 2 of the list is one of `GUEST_TOPICS`. TALKING SHOP +1 twice then -1
  (`GUEST_SHOP_MAX`), HOW IS BUSINESS +1 once, THE SALES PITCH -2, a `touchy` topic -1; the points join the table
  score and `guest.mood`. Result page: client mood +-2 per mood point, capped at 4 (`Sales.adjust`); owner campaign
  with mood 3+ (`GUEST_GOOD`): `Owner.vic_bonus += 0.02` (a referral). This is on top of the older R5 line.
- **D6 the boss picks up the tab** (`tab_due()`, `ask_tab()`, `set_tab(id)`): tech campaign, day 15 (`TAB_DAY`), a
  variety dinner. ENTER on the intro opens Garrison's card: the usual / steaks (the fancy budget: everyone's mood +1,
  Garrison -1 opinion) / keep it modest (the cheap budget: mood -1, Garrison +2). No money moves in the tech campaign.
- **D7 table events** (`TABLE_EVENTS`, `_dinner_event`, `dinner_event(id, who)`): between two rounds a 50% roll
  (`EVENT_CHANCE`), at most two a dinner (`EVENT_MAX`), no repeats. A one-line caption, and the next deal reads it
  (`_dinner_dress`): `glass` = no sore subject next round, `toast` = a subject the named person loves, `phone` =
  VENDOR STORIES, `check` = RAISES AND BONUSES, `game` = THE BIG GAME on the list (slot 3).
- **D8 the talk afterwards** (`talk_due()`, `talk_who()`, `talk_answer(who, id)`, `POST_TALKS`): a three star variety
  dinner in a campaign (not sales, not a fixed take). ENTER on the result page opens a card from the person at the
  table who likes you least. STAY AND LISTEN: +2 opinion, they tell you a love (owner: burnout -3). OFFER SOME
  ADVICE: +1 opinion, +4 people XP (owner: burnout -2). CALL IT A NIGHT: nothing. `Outings.talks` counts them (saved).
- **D2 ASK HOW THEY ARE and "as of outing n"**: `known[who].since[topic]` = the outing (`outing_no()` = `count + 1`)
  you learned or last confirmed it at; shown as `FOOD (2)` on the overlay list and the intro page (`dinner_brief()`),
  spelled out by `known_notes(who)` ("LIKES FOOD, AS OF OUTING 2"). Tastes drift: at the start of a variety dinner
  (never the first outing) a 35% roll (`DRIFT_CHANCE`) swaps one love you KNOW about for another topic (saved in
  `tastes`), so the note is stale. ASK HOW THEY ARE (`ASK_TOPIC`, slot 1 in rounds 1 and 2 until used) scores as a
  neutral answer, re-marks everything you know as of tonight, corrects a drifted taste, and when nothing changed the
  person you know least about names a favourite (`_learn_one`). A like that no longer gets a smile is struck off
  when you see the reaction (`_known_mark`).
- **Marks on the list** (`_dinner_marks`, `_dinner_mark`): a green bar = somebody here likes it as far as you know,
  red = somebody dreads it (or, while ordering, cannot eat the plate).
- Patchable tables added: `Outings.DINNER_TEXT`, `TABLE_EVENTS`, `POST_TALKS` (`Strings.ROOTS`).
- Save: `Outings.to_dict` gains `talks`; `known` entries gain `since`, `diet`, `diet_since` (old saves load, their notes
  simply have no mark until confirmed).
- Tests: `tests/dinner_variety.gd` (every sub-item, seeded repeats, saving, and a 120 seed simulation: best play 2+
  stars in 90%+, careless picks far fewer 3 stars). `tests/layout_audit.gd` has the four variety screens.

## R30 the dinner ramp (`difficulty.gd`, `outings.gd`)

Same hooks as the other games (Career `good.dinner`, `Difficulty.mastery / blend / f`, `MASTERY_KEYS`, the result page
line, `fixed_take` = 0). Three new `Difficulty.TABLE` keys [easy, normal, hard]:

| key | values | what it does |
|---|---|---|
| `dinner.expect` | 0 / 0 / 0.4 | points per diner added to the 3 and 2 star bars (`dinner_targets`), rounded per table |
| `dinner.fits` | 3 / 2 / 1 | plates of the four that suit everybody (variety dinners) |
| `dinner.hints` | 1 / 1 / 0.5 | share of the known-taste marks that show (variety dinners) |

Normal at full mastery (10 good dinners): a table of three needs 1 more point for 3 and 2 stars, a table of five 2
more; one plate fits; half the marks show. Easy: nothing changes by rounding (35% of the way). Hard tops out at 0.5
points per diner and 0.375 of the marks. The result page now carries `MASTERY n/10` for dinner and the intro page says
"AFTER n GOOD DINNERS THE TABLE EXPECTS MORE OF YOU". Test: `tests/dinner_ramp.gd` (first play = classic bars, counting
through the real finish path, monotonic, tiers, fixed take, fairness at full mastery: best play 2+ stars in 85%+).

## R4 E5 themed escape rooms (`outings.gd` section "themed escape rooms", `fx.gd`, `toolbox.gd`)

- `Outings.THEME_ORDER` = study, server, detective, lab; `ESCAPE_THEMES[id]` (patchable): `title`, `short`, `tint`,
  `ink`, `intro`, `start`, `open`, `say` (a line per recipe with `{a} {b} {list} {hour} {n} {numeral} {letter}`), and
  for the three new rooms `shelf` (three red herring lines) and `herring` (safe, trunk, globe). The study keeps the
  older `HERRINGS` / `HERRING_TEXT` tables.
- The theme changes words (the intro page names the room: "TONIGHT'S ROOM: THE SERVER ROOM."; clue captions through
  `clue_say`; `herring_text`, `shelf_herring`; `escape_text("start" / "open")`), the room's tint (`_theme_look`:
  `modulate` on the scene's `Background` and `Fx` layers, not the people; lights-out keeps its own tint) and the colour
  of the writing on the board (`escape_ink()`, read by `fx.gd _draw_clue_board`). Zones, recipes and digits are the
  same in every theme.
- Draw: `options.theme` = "" (no option: the study; tests and the toolbox default), a theme id (a fixed pick), or
  anything else ("draw", what `_game_options("escape")` passes) = drawn on the stream `escape.theme` in `start()` after
  the fixed-take reset. `theme_id()`, `escape_theme()`.
- Free Play toolbox: a `ROOM` row (`Toolbox.theme_i`) passes a fixed theme.
- Test: `tests/escape_themes.gd`: table checks; every theme x zone x recipe x digit reads back from the caption's words
  (a text-only solver); a scripted solver plays all 72 recipe combinations per theme (three and four digits) through
  `interact` / the keypad keys, plus 12 seeded rooms with drawn spots per theme; the draw is seeded and has its own
  stream; the toolbox row; one run in the real room (tint, ink, opening caption, solved).
- Not themed in this version: the friends' hints (`FRIEND_HINTS` still say chalkboard, clock, painting, bookshelf).

## R23 conference seats and P5 the owner walking the venue (`scripts/conference.gd`, `scripts/owner.gd`)

- **Sitting in a session (tech trip).** Walking into a breakout room in the round stage now opens a choice card
  ("SALON A": the session, the speaker; TAKE A SEAT / TRY ANOTHER ROOM). The session starts when you sit on a chair
  (`_watch_seat`), plays its lines one at a time as a caption (`talk_lines(session)`: its own `lines`, else the
  sentences of its `text`, the reward in brackets being the last line; `LINE_SECS` 3.4 s a line, E or Enter skips,
  `talk_skip()`), you nod at each line (`sitnod`), the trip clock runs `SESSION_HOURS` 0.9 over the talk, and at the
  end the reward is applied (the old `_session`, without its card), you stand up and the next round opens. You are
  held in the chair (`Game.ui_open`) for the talk. `Expo.seated` is the running session, `talk_line()` the line on
  screen. No free chair in the scene (a test that is not in the room) = the old card.
- **The owner walks (P5).** `Owner.apply` asks `Expo.owner_show(id)` before showing a chained card. With the real
  rooms in use (`Outings.use_rooms`, what the title menu sets) GO YOURSELF on `rn_invite` flies the owner to the
  resort lobby instead of opening `rn_session`: one session is sat through in salon A, B or C (the three options of
  the `rn_session` card, effect applied when the talk ends; D is closed; talk lines in `Expo.TEXT.owner_talk_0..2`),
  the three booths of the expo hall are the vendor cards (`OWNER_BOOTHS`: swag = `rn_rmm`, nerds = `rn_psa`, vendor =
  `rn_hw`; the hub card `rn_hall` is swallowed while walking), and walking into the ballroom after the session opens
  `rn_wrap`, whose answer flies you home (`_owner_home`: back to the scene and x you left, time and `Msp.enabled`
  restored). The office is frozen during the walk like on the tech trip (`away`, `World.time_scale` 0) and the
  owner's week clock does not move. Without rooms the trip is the old chain of cards (`tests/owner_p5.gd` unchanged).
- Tests: `tests/conference.gd` (rewritten middle part: the choice card, nothing learned before the talk is over, a
  line on its timer, skipping, standing up, TRY ANOTHER ROOM), `tests/owner_trip_walk.gd` (the whole owner walk and
  the card fallback), `tests/trip_variety.gd` unchanged (the no-chair fallback). `layout_audit.gd` has a "session
  talk" screen with the longest line of the agenda.

## Decisions made

- Dinner variety is opt-in per start (`options.variety`) so the classic dinner, its simulation and every older test
  keep their numbers; the real game flows always pass it.
- The guest is a sixth voice, not a sixth diner: no seat or NPC (no art in this batch), no change to the star bars.
- Dietary quirks are fixed per person (not rolled per save) so they can be learned for good; they are never a joke.
- "Sign a lead" for the owner's guest became a small close-rate bonus for John (`vic_bonus` +0.02), not a free client.
- The post-dinner talk picks the person who likes you least (the "struggling" one) and never costs anything.
- The dinner ramp changes the Hard tier's first-play bar (0.4 points per diner, +1 for a table of three): the blend
  needs hard to differ from normal. Normal and Easy first plays are unchanged.
- `tests/outings.gd` and `tests/dinner_sim.gd` clear `good.dinner` where they assert first-play bars (the ramp would
  otherwise build up inside the test); `tests/difficulty.gd` lists the three new keys.
- Escape themes reuse the one set: a theme is words, tint and ink. The toolbox default stays the study.
- "The card stays as the choice of which session" was read as: the room's card asks sit in / try another room; the
  session itself is the seat.
- The owner gets one session (as the card did) and salon D is closed, because the card has three sessions.
- The owner walk hangs on `Outings.use_rooms` (the existing "go to the real room" switch) rather than a new setting.
- `outings.gd` has more than 80 public functions now: `extends CanvasLayer  # gdlint:ignore=max-public-methods`.

## Left for a full version / art wanted

- Escape rooms: real sets per theme (a rack wall with LEDs and a patch panel for the server room, a desk lamp, blinds
  and a case board for the detective, rows of beige PCs and CRTs for the lab), themed props for the safe / trunk /
  globe, themed friend hints.
- Dinner: a guest NPC at the booth (a seat and a client sprite), plates drawn on the table, a face for the guest in
  the HUD strip, a toolbox row for the variety options, a Career medal for a perfect table.
- Conference: the speaker talking in a bubble and the audience reacting, a keynote you sit through in the ballroom,
  the owner's hallway track as real conversations in the hall, a save point inside the trip.
- `layout_audit.gd` (run with a renderer) reports OFFSCREEN lines for a `MAIL ...` banner on the existing computer
  screens in this worktree; they are not from this batch (the banner is animating in from above the screen).
