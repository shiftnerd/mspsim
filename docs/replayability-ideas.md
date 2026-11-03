# Replayability and variety: decision document

Scope: MSPSim (Godot 4.7.2, `godot/scripts/`). Read-only review of `outings.gd`, `printer_game.gd`, `nerf.gd`,
`onsite.gd`, `msp.gd`, `story.gd`, `owner.gd`, CLAUDE.md, IDEAS.md. Effort: S under a day, M 1-3 days, L a week or more.
Risk: how likely the change is to break existing tests, saves or art.

## 0. What the code does today (the constraints that matter)

| Fact | Where | Consequence |
|---|---|---|
| All randomness is global `randi()` / `randf()` / `shuffle()`; only `msp.gd` and `world.gd` call `randomize()`. No test sets a seed. | whole repo | Runs cannot be reproduced; tests assert on ranges or force state by writing into `Outings.g`. |
| Karaoke: `SONG_LEN := 24`, note time `1.5 + 0.75*i`, lane `randi() % 4`, windows 0.12 / 0.3 s, star cut-offs 0.75 / 0.5 / 0.25. The same `0.75` and `45.0` px/s appear in `_paint_karaoke`, the end check in `_kara_tick` and the song progress bar. | `_kara_setup`, `_kara_tick`, `_kara_end`, `_paint_karaoke` | Charts are random only in lane order. Tempo, length, title and note type are constants in 4 places: lift them into one chart dictionary first. |
| Escape room: overlay version has a 3-digit code of distinct 0-9 digits (`_escape_setup`); in-room version has 3 distinct digits 1-9 hidden at fixed spots (`_escape_room_setup`, `interact()` kinds `clue_board`, `clue_clock`, `clue_painting`, `keypad`). `ESCAPE_TIME` 120. Clue spots are set-art fx zones from `BGFX`. | `outings.gd` 748, 1043 | Only the numbers change run to run. A new clue type needs a zone plus a caption; a new room needs a new set. |
| Bowling: `BOWL_SKILL` {Alan .62, Garrison .55, Dan .48}, noise +-0.28, `bowl_strength()` noise +-0.08, aim speed 1.5, power speed 1.2, 5 frames, strike bonus +3. Stars from `bowl_rank()`. | `_bowl_roll_opp`, `_bowl_tick` | Skills are constants, so the field never changes. Aim and power speeds are the natural difficulty knobs. |
| Dinner: `DINERS`, `LOVES`, `HATES`, `TOPICS` (6) are consts; 5 rounds, 4 options per round, 2/1/0 points, 24 / 19 / 14 thresholds. `known` is saved across outings. | `_dinner_deal`, `dinner_talk`, `_dinner_end` | Because tastes are fixed, `known` makes later dinners trivially 3 stars. This is the least replayable game. |
| Printer: 3 rounds (jam, tray, toner, shake, test); jam zone `randf_range(0.22, 0.78)`; 4 `QUESTIONS`, 2 asked; stars from `_score()` (mistakes 0-1 = 3). `fast` flag, `blessed`, `faith`. `QUESTIONS` and `TEXT` already patchable. | `printer_game.gd` | One printer, one look. Best data-driven target in the repo. |
| Nerf war: 45 s (`WAR_SECS`), NPC fire gap 2-4.5 s, no score, no win condition, no arena variety. Ducking fixed (`DUCK_TOP` 40, 60% NPC duck). | `nerf.gd` `start_war`, `_process` | A war is an event with a toast at the end. Needs a goal before modes make sense. |
| Onsite: `JOBS` (+ `MORE_JOBS`), `EVENTS` once per visit at 55%, `FINDINGS`, `PETS`, all patchable tables with option dictionaries `{id,label,hours,chance,skill,xp,text}`. | `onsite.gd` | Already data-driven. Cheapest content to multiply. |
| Story: `VIGNETTES` (7, one per fixed quiet day), `DAYS`, `Playbook.BOOKS` fixed to days 8 / 14 / 19. Tickets: `Msp.PROBLEMS` picked with `randi()`. | `story.gd`, `msp.gd` | A 20-day tech run is the same story each time. Variance is only ticket dice and the commute. |
| Owner campaign has a bigger decision space (cards, hires, projects) but fixed weeks and fixed client roster. | `owner.gd` | Better replay already; needs mutators and starting conditions, not a rewrite. |

## 1. The difficulty and variety model

### 1.1 One dial, many consumers
A new autoload `Difficulty` (`scripts/difficulty.gd`, added after `Shift` and before `Outings` in `[autoload]`) owns:

- `tier`: `"easy" | "normal" | "hard"` (title menu setting, saved in the campaign file in a `difficulty` section).
- `level()` returning a float 0.0-1.0 that mixes four inputs. Keep the mix visible to the player on the intro page ("TONIGHT: HARD").

  | Input | Source (already exists) | Effect on `level()` |
  |---|---|---|
  | Tier | title menu | easy 0.0, normal 0.35, hard 0.7 base |
  | Progress | `Campaign.day` (tech 1-20) or week (owner 1-20) | +0.0 to +0.25 across the run (gentle first days stay gentle, matches `DAY_CAPS`) |
  | Skill | `Skills` levels, `best` stars per game in `Outings.best` | +0.0 to +0.1 for a player who three-starred the game before |
  | Cast | who attends (section 1.2) | +-0.05 |

  Energy is deliberately NOT in this sum for outings (a night out restores energy; punishing a tired player there is backwards). It is used only on the printer job, where `Shift.slow_mult()` already models tiredness (see 2.4).
- `get(game, key)`: looks up a number in `TIERS[game][key]` as a 3-value array (easy, normal, hard) and interpolates with `level()`. Every mini-game reads its knobs through this one call, never from its own constants.
- `rng(stream)`: returns a `RandomNumberGenerator` per stream name (`"karaoke"`, `"escape"`, `"printer"`, `"dinner"`, `"bowl"`, `"events"`), seeded from `run_seed ^ hash(stream) ^ n` where `n` counts how many times that stream was opened. `run_seed` is chosen at New Game (or typed in / fixed by the daily seed, section 3.3) and saved. `Difficulty.set_seed(n)` is what tests call.
- Fairness rule baked into the service: `get()` clamps so that a perfect run is always possible (windows never below a floor, timers never below the time a perfect run needs). Easy never fails a player who is merely slow.

Which knobs hang off it:

| Knob | Today | Easy / Normal / Hard (suggested) |
|---|---|---|
| Karaoke perfect / good window | 0.12 / 0.3 s | 0.16 / 0.36, 0.12 / 0.30, 0.09 / 0.24 |
| Karaoke note gap | 0.75 s | 0.95, 0.75, 0.55 |
| Bowling aim speed / power speed | 1.5 / 1.2 | 1.1 / 0.9, 1.5 / 1.2, 2.0 / 1.6 |
| Escape time / digits | 120 s / 3 | 150 s / 3, 120 s / 3, 105 s / 4 |
| Printer marker speed, zone width | see `_process` | -20% / base / +25%; wider green on easy |
| Dinner rounds / thresholds | 5 / 24-19-14 | same thresholds, hard adds a mood-of-the-day twist |
| Nerf war length / NPC fire gap | 45 s / 2-4.5 s | 35 s / 3-6, 45 s / 2-4.5, 60 s / 1.5-3 |

### 1.2 Who comes along (the cheapest big variety win)
`Outings.DINERS`, `BOWL_SKILL` and `SPOTS` (already 5 slots) hard-code three people. Add `Outings.roster()`: picks 3 or 4 from Alan, Garrison, Dan, Maya, Vic, plus an occasional guest (section 2.5), using `Social` opinion (cold people decline: "Dan has a thing tonight", never a family or health reason stated as a penalty). The roster feeds bowling opponents, dinner diners, karaoke audience and escape-room hint givers. `DINERS` and `BOWL_SKILL` become per-person data (section 3.1) so Maya and Vic need only a table row. Hook: `World.start_outing(room, spots, seats)` already takes spots.

## 2. Mini-games: concrete ideas

Each idea lists what changes, the hook in the code, effort and risk. "Table" means a new patchable table (section 3.1).

### 2.1 Karaoke (`_kara_setup`, `_kara_tick`, `kara_hit`, `_kara_end`, `_paint_karaoke`, `fx` kind `lyrics`)

Parody titles only; no real songs, bands or lyrics. Genres of 2013-14.

| # | Idea | Hook | Effort | Risk |
|---|---|---|---|---|
| K1 | **Song table** `SONGS`: id, parody title, artist, genre, bpm, length, gap, lane pattern generator, line text for the lyrics screen. Four to start: "Wobble Wobble Pop" (2013 pop hit, steady), "Dirt Road Friday" (country singalong, slow with long holds), "Neon Gym Class" (80s classic, syncopated), "Fast Rap Hot Mess" (rap, fast bursts, small windows). Picked from a card when you step to the mic, or random under a mutator. | New `_kara_chart(song)` replaces the loop in `_kara_setup`; `SONG_LEN` and `0.75` become `g.len`, `g.gap` (the 3 other uses in `_kara_tick`, `_kara_end`, `_paint_karaoke`). The `lyrics` fx reads `Outings.g.song.lines`. | M | Low if the 4 hard-coded sites are replaced together; run `tests/outings.gd` and `tests/inroom.gd`. |
| K2 | **Hold notes**: a note with `len` > 0 must be held (key down) until it ends; releasing early scores good, not perfect. | Notes get `hold` and `held` fields; `_kara_press` currently handles press only, add `_kara_release` from `_input`. Draw a tail in `_paint_karaoke`. | M | Medium: key release plumbing and in-room strip. Ship after K1. |
| K3 | **Double notes**: two lanes at one time stamp (two keys within 0.1 s). | Chart generator adds a second note with same `time`; `kara_hit` already picks per lane so scoring works unchanged. | S | Low. Hard tier and the rap song only. |
| K4 | **Crowd-mood meter** (0-100): perfects raise it, misses lower it, streaks multiply; at 0 the song ends early "THE ROOM TURNS TO THE BAR" (stars 0, no social penalty beyond today's). At 100 someone comes up and sings the last chorus (cheer, free 3 stars if above 50% share). | `_cheer()` and `_streak_broken()` already exist; add `g.mood` and a HUD bar in `_hud_karaoke`. | M | Low. Make mood-0 a soft stop with a laugh, not humiliation (tone rule). |
| K5 | **Duet**: a coworker from the roster takes lane pairs (they hit the other two lanes automatically with a skill roll). Rewards bringing a friend. | `g.partner`; extra notes auto-resolved in `_kara_tick`. | M | Medium: balance. |
| K6 | **Set list**: tech campaign: one song per outing, owner campaign: 2-song set with a bar tab decision between them. | `Outings._finish` is called after the last song; a `g.set` queue. | M | Low. |
| K7 | **Song-specific scoring bonus**: pop likes streaks, country likes holds, rap likes accuracy. Star cut-offs differ per song (`_kara_end` reads `g.cuts`). | `_kara_end` | S | Low. |
| K8 | **Pager interrupt** (already on the outings wish list): on call week, 25% a pager chime mid-song; ignore costs nothing in-game but you can answer afterwards. Never a hidden penalty. | `Shift` on-call flag; a toast in `_kara_tick` | S | Low if the pager is opt-in and cosmetic. |

### 2.2 Escape room (`_escape_setup`, `_escape_room_setup`, `interact`, `escape_nudge`, `_room_submit`, `ROOMS`, `ESCAPE_TIME`)

| # | Idea | Hook | Effort | Risk |
|---|---|---|---|---|
| E1 | **Clue recipes in the existing study** (no new art): each of the 3 digit clues picks a recipe from a table instead of being fixed. Recipes per zone: board = sum, product, "digit that is missing from 1-9 in this scrambled list"; clock = hour, minutes-hand digit, "twice the hour"; plaque = number, roman numeral (III, VII), a letter-to-number ("G is the 7th letter"). `interact()` formats the caption from `g.clues[i]`. | `_escape_room_setup` builds `g.clues`; `interact` kinds already exist | S | Low. Tests keep working if `g.code` is the final answer. |
| E2 | **4-digit code** on hard (a fourth clue appears: a poster, the grandfather clock chime count, a book spine). | Code length from `Difficulty.get("escape","digits")`; loops `for i in 3` at 5 places (`escape_score`, `escape_hint`, `_escape_press`, `_hud_escape`, `_paint_escape`) become `g.code.size()`. | M | Medium: new zone needs a `BGFX` entry and a fx kind; or reuse the trunk / desk lamp zones already in the set. |
| E3 | **Red herrings**: the safe, trunk and desk lamp already exist as props. Make them interactive: a calendar with a date that looks like a code, a note "the code is not 1-2-3". Each costs 2 s to read, no penalty beyond time. | `interact` new kinds, `BGFX` zones | M | Low. |
| E4 | **Timer scaling**: `ESCAPE_TIME` from `Difficulty.get`; each hint used past the first adds 5 s on easy only. Wrong-code penalty (currently 10 s) scales 5 / 10 / 15. | `_room_submit` | S | Low. |
| E5 | **Three more themed rooms** (art, then data): office server room (rack LEDs, cable colours as digits, a patch panel), 1990s arcade (high-score initials to digits, a cabinet playing attract mode), vault (a bank lobby with deposit slips). Each is a set in `tools/outing_sets.lua` plus a `ROOMS`-style entry `ESCAPE_ROOMS[theme]` with clue zones and recipe names. | `ROOMS["escape"]` becomes a theme pick; `SPOTS["escape"]` per theme (keep clear of zones) | L | Medium: art cost and `World.start_outing` spots per set. |
| E6 | **Random layout of clue spots**: the same 3 zones but the sets draw 5 props and `g.zone_for_clue` maps 3 of the 5 at random (clue on the clock one run, on the trunk the next). | `interact` mapping instead of kind = clue | M | Medium: the 5 props must all be interactive. |
| E7 | **Brute force vs puzzle**: the overlay version's bulls-and-cows (`escape_try`) stays as "Try the dial lock" mini-puzzle in the same room as a second route; harder tier removes it so the clues matter. | existing `escape_score` | S | Low. |
| E8 | **Friend hints that fit the friend**: Alan gives the chalkboard, Dan the wiring, Garrison the lock; Maya reads the plaque. Text lines from a table, not three fixed strings in `escape_nudge`. | `escape_nudge` | S | Low. |

### 2.3 Bowling (`BOWL_SKILL`, `_bowl_roll_opp`, `bowl_strength`, `_bowl_tick`, `fx` kind `bowl_lane`, `bowl_score`)

| # | Idea | Hook | Effort | Risk |
|---|---|---|---|---|
| B1 | **Opponent personalities** in a table: Alan steady (low noise 0.15), Garrison streaky (alternates hot and cold), Dan wild (big noise, occasional turkey), Maya precise, Vic show-off (bonus when watched; 5% gutter). Replaces the shared +-0.28 noise. | `_bowl_roll_opp` reads `PEOPLE[who]` {skill, noise, streak} | S | Low. |
| B2 | **Lane oil patterns**: each alley has a pattern: "house shot" (forgiving), "sport shot" (aim window narrow), "dry lane" (hook drifts right). Oil drifts the effective aim point so the best marker position is not exactly 0.5. | `bowl_strength`: `accuracy = 1 - abs(marker - (0.5 + oil_bias))` | S | Low. Show the bias on the intro page. |
| B3 | **Spin**: after power, a short third key press (hold Left or Right) adds curve to reach corner pins on splits. | add stage `"spin"`; `_bowl_resolve` picks which pins by `_pins_fall` choice | M | Medium: pin layout and the lane fx. |
| B4 | **Alleys**: three venues with different parameters (a cheap strip lane with a sticky return, a fancy glow-bowl night, a church-league alley). Same set art, different neon sign text and parameters. | `ROOMS["bowling"]` plus params | S | Low (no new art if only sign text changes; `neon_bowl` fx is text). |
| B5 | **League night**: three-game series over several outings with a handicap (average minus 180 times 0.9 style: `BOWL_SKILL` handicap bonus for weaker players). Table of league standings saved in `Outings.best`. | save in `to_dict` | M | Medium: save schema. |
| B6 | **Handicap mode**: everyone's total adds `(rank gap) * k` so a three-star is not just skill. Also lets an easy tier give the player a bonus. | `bowl_rank` | S | Low. |
| B7 | **Split and gutter-bumper rules**: on easy, bumpers (no gutter); on hard, the frame has a 10th-frame bonus ball. Also 10 frames on long evenings. | `_bowl_advance` (`frame >= 5`) | S | Low: stars still scale on rank. |
| B8 | **Spectators**: a kid's birthday party on lane 3, a league team in matching shirts, a loud guy. Cosmetic cheers and trash talk bubbles that change the pressure (a tight crowd lowers the power-bar sweet spot size by 10%). | `_bubble` | S | Low. |

### 2.4 Printer game (`QUESTIONS`, `TEXT`, `_begin_jam`, `_new_zone`, `_begin_toner`, `_begin_tray`, `_begin_test`, `_score`)

| # | Idea | Hook | Effort | Risk |
|---|---|---|---|---|
| P1 | **Printer models** (`MODELS` table): laser (current), inkjet (clogged nozzle, head alignment, cartridge chip), plotter (paper roll, long jam), multifunction (scanner glass, ADF jam, fax line), receipt printer (thermal paper, cutter), dot matrix at the realty office. Each has its own phase list, error pool, TEXT overrides and sprite colour. Chosen by site type: architect = plotter (closes the "plotter-flavoured printer game text" leftover), dental = receipt + laser, law = MFP. | `PrinterGame.start(callback, model)`; `_begin_*` read `MODELS[model].phases` | M | Medium: the phase list is the one structural change. |
| P2 | **Bigger error pool** (28+ items, tagged by model and difficulty): add 2013-14 items (ink alignment after a swap, spooler stuck with a 400 MB job, a USB printer shared from a Windows XP PC, IP changed after DHCP lease, wrong default printer after a laptop moves, "Out of memory" on a 2 MB laser, duplex unit open, paper-feed rollers glazed). `_begin_test` samples 2 now; sample by model and a tier-dependent number (2 / 3 / 4). Include one trick question: "the answer is that it's unplugged". | `_begin_test`; `QUESTIONS` is already patchable so strings.txt can hold them | S | Low. Highest value per effort in the game. |
| P3 | **Escalating jam sequences**: jam round has 3 spots today (`spot`), faster each time. Make it a chain of 3-6 with a combo: clean pulls shorten the chain, and tears leave scraps that appear as an extra pull at the end. Hard: a hidden second sheet. | `_pull`, `_begin_jam` | M | Medium. |
| P4 | **Boss level: server-room line printer** (a fan-fold impact printer, 2013 client with payroll forms): five phases back to back with one life bar (no prayer refills), ribbon, tractor-feed sprocket alignment, paper path, form alignment test, and a final test question. Reward: a unique ticket close and a permanent "PRINTER WHISPERER" medal. | Unlocks from Onsite after `best printer = 3` on two other models | M | Medium: new art for the big printer, but the draw is code (`_printer(y)`). |
| P5 | **Tiredness and pressure**: marker speed scales with `Shift.slow_mult()` (max +15%) on onsite jobs only, with a visible "TIRED" tag; client mood scales the cost of a mistake (an angry client waits; a patient one is forgiving). | `_process` reads `Shift` | S | Low. Tell the player. |
| P6 | **Parts and tool picks**: before starting, choose a bag (paper, fuser kit, compressed air, a network cable). The right bag removes one mistake allowance, the wrong one adds a mistake. | `start()` | M | Low. |
| P7 | **Prayer variants by religion of the printer**: new `PRAYERS` per model, a `faith` count tied to the number of times you have succeeded without praying (a "no-prayer streak" medal). | `_pray` | S | Low. |
| P8 | **Practice mode with seed**: in Free Play the intro page offers the model and a seed so tests and film shots reproduce. | `Difficulty.rng("printer")` | S | Low. |

### 2.5 Dinner (`DINERS`, `LOVES`, `HATES`, `TOPICS`, `_dinner_deal`, `dinner_talk`, `_dinner_end`, `_hud_dinner`)

| # | Idea | Hook | Effort | Risk |
|---|---|---|---|---|
| D1 | **Bigger topic pool** (16+): 2013-14 culture only, e.g. FANTASY FOOTBALL, A NEW PHONE, COMMUTE, ROAD TRIP, HOME BREWING, A NEW BABY, GARDENS, THE BIG GAME, A TV SHOW BINGE, KARAOKE. `TOPICS` gets a tag (`light`, `deep`, `touchy`). Each round picks 4 with at least one safe and one trap. | `_dinner_deal` | S | Low. |
| D2 | **Personality table** (`PEOPLE[name]`: loves (2-3), dislikes (1-2), quirks), with a per-save shuffle of two of the tastes so `known` is not a permanent cheat sheet; `known` keeps lines marked "as of outing n" and a "ASK HOW THEY ARE" topic reveals changes. | `LOVES`/`HATES` become data; `dinner_talk` unchanged | M | Medium: `Outings.known` save schema. Version the section. |
| D3 | **Mood of the day** for each diner: tired / chatty / distracted: shifts points by +-1 per round, shown by face icons at the start. Learn who is in which mood before choosing. | `dinner_talk` adds `mood_bonus` | S | Low. |
| D4 | **Dietary quirks** and ordering: before the topics, a short ordering round: who is vegetarian, who has a gluten allergy, who hates mushrooms (period-correct: no cauliflower-crust trend). Picking a shared plate that fits everyone = +2. Never joke at someone's health or religion. | new `g.stage = "order"` | M | Medium: tone; keep it affectionate and low-stakes. |
| D5 | **A client or prospect at the table** (owner: Vic brings one; tech: a client who got invited to the team dinner). A sixth person with a topic list; they like TALKING SHOP up to a point, hate being pitched. In owner mode a good dinner raises mood and can sign a lead. | `Sales.pick_client`, `Onsite.OWNER_B` skins | M | Medium: owner economy interaction. |
| D6 | **The owner pays**: owner mode: choose the budget (cheap, normal, fancy) before dinner; fancy lifts everyone's base mood but costs cash. Tech mode: the boss picks up the tab on day 15 as a story card. | `GAMES.dinner.cost` | S | Low. |
| D7 | **Table events**: a dropped glass, a long toast, someone's phone rings (a vendor call), a round of "pass the check". Each is a one-line card that changes the next round's topics. | `_dinner_tick` | S | Low. |
| D8 | **Post-dinner talks** (the IDEAS "one-on-one with a struggling hire"): if the score is 3 stars, a follow-up card. | `_finish` | M | Medium: shares code with `Talk`. |

### 2.6 Nerf war and ducking (`WAR_SECS`, `start_war`, `_process`, `_npc_shoots`, `_hits`, `DUCK_TOP`, `dodges`)

The war has no goal and no loser; modes require a goal first.

| # | Idea | Hook | Effort | Risk |
|---|---|---|---|---|
| N1 | **Score and medals**: count hits, dodges, assists; end screen with "MOST DUCKED", "SNIPER" (long lob), "FRIENDLY FIRE". Feeds the career screen (3.2). | `war_hits`, `war_taken`, `dodges` already counted | S | Low. |
| N2 | **Ammo scarcity**: `MAX_AMMO` 6 -> mode `scarce` (3 darts; darts left on the floor are the only refills, `NPC` also scavenge). Pickup priority makes the room matter. | `MAX_AMMO`, floor pick-up | S | Low. |
| N3 | **Capture the monitor** (CTF): each team has a monitor on a desk; hit it 3 times (`fx.hit()` already glitches a monitor) to win. NPC AI targets the monitor in 50% of volleys. | `_npc_shoots` target selection | M | Medium: AI and room coverage. |
| N4 | **VIP defence**: Morgan or the owner walks through; the player must keep them from being hit for 45 s while NPCs try. Hit them and the opinion/rep cost is small and funny. | `npc.cast_name`; reaction table `REACT` | M | Medium. Tone: playful, never a punishment for being the target. |
| N5 | **Arenas**: the war can start in conference, cubicles, kitchenette, or the main floor; each gets cover weights (desks block, whiteboard blocks). Use existing `Nerf.stick_target` blockers to compute cover. | `stick_target` | M | Medium: collisions. |
| N6 | **Rules cards**: "No head shots" (head = +1 ducked point), "Friday rules" (everyone gets 2 darts and a bell target: ring the sales bell for a bonus). | `Nerf.hit_bell` | S | Low. |
| N7 | **Duck skill**: a duck meter (stamina) that recharges; low-tier NPCs duck 40%, high 75%; "dodge-roll" on hard for the player. | `_duck_tick` in `npc.gd` (60% chance per dart) | S | Low. |
| N8 | **Cleanup duty**: after a war, scattered darts remain; picking them up gives a tiny reward and ends in a short dialog (Morgan walking in, as the CLAUDE.md "ideas left" says). | `gone(dart)` | S | Low. |

### 2.7 Other repeatable activities

| Area | Ideas (hook, effort) |
|---|---|
| **Onsite jobs** | Randomise **parameters** of each `JOBS` entry: success chances +-10%, hours +-0.25, a hidden second fault revealed after the first fix (swap switch, then a bad cable run). Add 2-3 jobs per site type to `MORE_JOBS` (S each). Add a **dispatch roulette** card: two jobs at once, choose a priority (M). |
| **`EVENTS`** | Only one event per visit at 55%: make it a weighted deck of 4-6 per site type with a "do not repeat for 10 days" memory (`Onsite._event_done`) (S). |
| **Tickets** (`Msp.PROBLEMS`) | Pull the problem with `Difficulty.rng("tickets")` weighted by day, client trait and mutator; add multi-step tickets (two valid fixes beyond the spooler, see QA leftovers: `ALT_FIXES`) (M). |
| **Vignettes** (`Story.VIGNETTES`) | Today 7 fixed days. Move to a **deck**: 24 vignettes, each tagged by earliest day; on a quiet day draw one (S per vignette). Period-correct ideas: a client "bricked" a Nexus 5 trying a ROM, Dropbox "shadow IT", an Adobe key prompt, a first Chromebook (period correct), Flappy Bird on the front-desk PC, a 3D printer demo at Acme, Windows XP end-of-support panic (April 2014), a dental x-ray sensor driver, a Candy Crush request. |
| **Conference trip** (`Expo`) | Randomise which three sessions the hall's doors A-D map to per run; swap vendor pitches (`VENDORS` pool of 6); attendee `CHATS` 5 -> 12; give the raffle a mini-game (spin the wheel with timing) (M). |
| **Commute / Lync / Talk** | More commute text variants and a weekday-specific weather deck (S). `Talk.SMALL_TALK` pools from a table (S). |
| **Owner cards** | Same `Owner.CARDS` layered with `Mutators` (section 3.2): a card chooses one of three phrasing variants and numbers by tier. |

## 3. Meta-replayability across a whole run

### 3.1 Random event deck
A new `Events` autoload (or a table inside `Story`): `DECK = [ {id, kinds, min_day, max_day, weight, cooldown, requires, card} ]`, drawn once per morning (`Campaign` start of day) using `Difficulty.rng("events")`. A card is the existing Cards format (speaker, text, options with `fx` keys: `xp`, `mood`, `mood_all`, `rep`, `social`, `energy`, `hours`: the same keys vignettes already use, so the vignette resolver is reused unchanged). Aim at 40 cards across tech and owner: client calls, supplier delays, a heat wave takes the AC down, a cousin of Vic's wants a website, a vendor sends free pizza, a cold snap (week-specific, there is `WEEK_TRAFFIC`), a lost phone. Period rules in section 5.

### 3.2 Difficulty settings, mutators, starting conditions
- **Tiers** (easy / normal / hard) applied by `Difficulty.get()` across `Msp.SLA_SECS`, `DAY_CAPS`, `Shift.DAY_DRAIN`, `Onsite.SLA_PER_HOUR`, owner `COST_PER_SEC`, `START_CASH`. Modes of the same table: `TIERS["msp"]["sla_mult"] = [1.25, 1.0, 0.8]`.
- **Mutators** (`MUTATORS` table: id, name, text, hooks). A week or a day can have one, announced by a morning card; a New Game+ can enable 1-3.
  Examples: **Heartbleed week** (tickets to check certificates, extra security tickets, Garrison busy), **XP end-of-life** (every XP desktop ticket P2, an upgrade project quote), **Flu season** (two coworkers out on random days; a kind text, never a penalty on you), **Printer apocalypse** (printer tickets x3, boss unlocks), **Tax season** (accountants call twice as often), **Slow payers** (invoices late), **Hardware recall** (a batch of drives fail), **Hurricane drill** (a DR test), **The new PSA** (migration day with chaos).
  Implement as dictionary keys read by existing functions (`Msp.problems_weight`, `Shift.fail_add`), no new systems.
- **Starting conditions** (owner and tech): *Inherit a messy MSP* (patch debt high, undocumented clients, two angry accounts), *the only tech* (no cast on the first 5 days; the cast joins as you hire), *a rival wants your client* (competitor wave from day 1, `_poach_wave`), *a spun-off division* (clean but small), *the family business* (a beloved owner who refuses change). Each is a small dictionary of overrides on the start state.
- **Alternate endings**: `Review.EPILOGUES` already exists. Add ending flags (the quiet exit, the buy-out, the merger, the franchise), keyed by choices stored in `Campaign` flags, so New Game+ can chase a different one.

### 3.3 New game plus, "year 2", daily seed, free play
- **Year 2 (New Game+)**: unlock after the day 20 review. Keeps skills (capped), reputation, and `Outings.known` as "reputation". Changes: a different ticket weight table, new clients (Paws and Claws, Lindqvist and Moss, Iron Mule Demolition are already prospect clients with sites, so they become active), the story beats shift days (a `story_shuffle` that moves playbooks by +-2 days within rules), harder SLA clock, mutators on. A new boss for the printer game.
- **Daily seed**: a button "TODAY'S SEED" (date-derived integer: `Time.get_date_dict_from_system`). Same ticket stream, same events, same karaoke song for all players that day. Needs `Difficulty.rng`. Local only; no network, no leaderboard (no online service in 2013-14 setting is relevant, it is a game menu feature, not an in-world object).
- **Seed in the save**: the New Game screen shows the seed ("RUN 4F2A9C"); typing one reproduces a run. Debug builds expose it to QA.
- **Career screen and medals**: a `Career` section saved outside the campaign slot (`user://career.json`) with lifetime stats (tickets, outings, stars per game, nerf hits, ducks, pets, deliveries), medals with parody-safe names (GUTTER GURU, STICKY NOTES SAVIOR, PRINTER WHISPERER, NEVER RESTARTED, MEETING SURVIVOR, DUCK WHISPERER, PEOPLE PERSON, FRIDAY WARRIOR). Medals unlock cosmetic rewards: outfits already exist as character files (`casual_garrison`, `office_alan`, `site_alan`), so a cosmetic is a skin choice; phone cases and ringtones (2013-14: wallpaper packs, no apps); desk toys (a second rubber duck, a stress ball); a Free Play toolbox unlock.
- **Free Play toolbox** (for filming): `Difficulty.freeplay` ignores tier and seeds; a panel (F-key) to pick any game, song, printer model, arena, escape theme, and seed; "fixed take" mode (deterministic RNG, no random events) for retakes. Hooks: `Outings.start(id)` and `PrinterGame.start()` already take parameters.

## 4. Data-driven content and testability

### 4.1 Tables, not code (follows the `PATCHABLE` / `strings.txt` pattern)
Add these as `DEFAULT_X` plus mutable `X` with `make_patchable` in `tools/make_godot.py` so reviewers edit text in `strings.txt`:

| Table | Home | Row shape |
|---|---|---|
| `SONGS` | `outings.gd` | `{id,title,artist,genre,bpm,len,gap,pattern,holds,doubles,cuts,lines[]}` |
| `ESCAPE_ROOMS` | `outings.gd` | `{id,theme,set,time,digits,zones[{kind,recipes[]}],herrings[],hints{}}` |
| `ALLEYS` / `LEAGUES` | `outings.gd` | `{id,name,oil_bias,aim_speed,bumpers,frames}` |
| `PEOPLE` (outing traits) | `outings.gd` | `{bowl:{skill,noise,streak}, loves[], dislikes[], quirks[], mood_pool[]}` |
| `TOPICS` + `DINNER_EVENTS` | `outings.gd` | `{id,label,tags,line_by_person{}}` |
| `MODELS`, `QUESTIONS`, `PRAYERS` | `printer_game.gd` | model `{label,phases[],colors,text_overrides,pool_tags}` |
| `ARENAS`, `WAR_MODES` | `nerf.gd` | `{scene,cover[],ammo,secs,goal}` |
| `DECK`, `MUTATORS`, `STARTS` | new `events.gd`, `mutators.gd` | see 3.1, 3.2 |
| `TIERS` | `difficulty.gd` | `{game:{key:[easy,normal,hard]}}` |

Rules: numbers live in `TIERS`; text lives in `strings.txt`; layout (note patterns, set positions) stays in code consts with a validator.

### 4.2 Testing story (keeps the "drive public functions" style)
- `Difficulty.set_seed(n)` plus `Difficulty.rng(stream)` makes every game deterministic. New tests assert exact charts: `tests/seeds.gd` runs each setup twice with the same seed and checks identical `g.notes`, `g.code`, `g.clues`, printer `asked`, dinner `options`; different seeds differ.
- Replace `randi()` / `randf()` / `shuffle()` in the touched functions with `_r.randi_range()` etc. where `_r = Difficulty.rng("karaoke")`. Existing tests that stub results by writing `Outings.g` keep working as long as keys they read remain.
- **Schema validators** `tests/content.gd`: every table row is checked (song gaps above the min window; all 4 lanes appear; every escape room has the 3-4 zones that exist in `BGFX`; every question has a valid `correct`; no real band or brand names via a deny-list; every text passes the 2013-14 word list `Strings` already warns on).
- **Balance simulation**: `tests/difficulty_sim.gd` plays each game with a scripted bot of fixed skill across seeds and tiers, prints stars distribution (as `owner_balance.gd` does for owner). Pass condition: skilled bot gets 3 stars on normal at least 60%, on easy at least 90%, on hard at most 40%.
- **Saves**: add `difficulty`, `career`, `mutators` sections with defaults so old saves load (`from_dict` already uses `data.get`). Test in `tests/strings.gd`-style: load an old save, confirm normal tier.
- **Screenshot tests** (`outings_shots.gd`, `printer_shots.gd`) get a `--seed=` parameter so images are comparable.

## 5. Prioritised roadmap (value per effort)

Status: item 1 is built (see CLAUDE.md, "Difficulty and seeds"). Differences from the spec below: `f(key)` (not `get`) reads a discrete easy / normal / hard table instead of interpolating a `level()`; `rng(stream)` returns one persistent generator per stream (plus `rng_for(stream, salt)`); the tier is chosen on the character select screen (Up / Down) and remembered in `user://mspsim_settings.cfg`; there is no seed field to type yet; only the seed (not the stream position) is saved. Items 2-10 are still open.

| # | Item | Effort | Why |
|---|---|---|---|
| 1 | **BUILT.** `Difficulty` autoload + seeded `rng(stream)` + tier setting in the title menu + save section | M | Unlocks everything else and fixes test determinism |
| 2 | Printer: bigger `QUESTIONS` pool (28+), 2-3 models with their own text (laser, inkjet, plotter), parameters from `Difficulty` | S-M | Best content-per-hour; printer is used on every onsite; closes the plotter leftover |
| 3 | Karaoke `SONGS` table (4 parody songs, tempo and note-type by tier) plus the 4-site constants cleanup | M | Biggest felt variety for the most-played outing |
| 4 | Escape room clue recipes + randomised clue spots + 4-digit hard + timer scaling (existing study) | M | Re-solves each run without new art |
| 5 | `Outings.roster()` and per-person tables (bowling personalities, dinner tastes, Maya and Vic join) | M | Reuses existing 5-slot `SPOTS`; makes every outing different people |
| 6 | Dinner pool (16 topics), mood of the day, owner-pays budget card | S-M | Fixes the weakest game's solved-by-memory problem |
| 7 | Career screen + medals (read from counters already kept) + nerf scoring | M | Cheap motivation to replay; nerf gets a goal |
| 8 | Event deck (40 cards) and vignette deck (24) using the existing `fx` resolver | M | Largest run-to-run variety in the campaign |
| 9 | Mutators (6 to start) and starting conditions (3) | M | Gives New Game+ a purpose |
| 10 | Year 2 / New Game+ (new clients active, shifted beats), daily seed | L | The big structural payoff; wait until 1, 8 and 9 exist |

Later: bowling oil / spin / league, themed escape rooms (art), nerf modes, printer boss.

### Specs for the top three

**1. `Difficulty` service and seeded RNG.** Create `godot/scripts/difficulty.gd` as an autoload placed after `Shift` and before `Outings`. It exposes `tier` (default `"normal"`), `run_seed` (int, random at New Game), `level()` (0.0-1.0 from tier, `Campaign.day`, best-star history), `get(game: String, key: String) -> float` (interpolates `TIERS[game][key]` with `level()` and clamps to a floor so a perfect run stays possible), `rng(stream: String) -> RandomNumberGenerator` (new instance per call, seeded `hash([run_seed, stream, n])`), `set_seed(n)` and `to_dict() / from_dict()` saved in the campaign file under `difficulty` (missing = normal, new seed). The title menu gets an EASY / NORMAL / HARD line and a seed field. In v1 only `Outings`, `PrinterGame` and `Nerf` read it; `Msp` and `Owner` keep their own randomness. Replace `randi()` / `randf()` / `shuffle()` in the six mini-game setup functions with an `_r` from `rng()`. Done when: (a) `tests/seeds.gd` shows the same seed gives identical `g` for each game and different seeds differ; (b) all existing `outings`, `printer`, `inroom`, `nerf` tests pass untouched; (c) a loaded old save has tier normal; (d) `gdlint` and `gdformat --check` clean.

**2. Printer variety.** Add `MODELS` (laser, inkjet, plotter first; MFP, receipt, line printer later) and grow `QUESTIONS` to 28 entries tagged `models` and `hard` (each with `error`, three `options`, `correct`, `why`; 2013-14 items only). `PrinterGame.start(callback, model := "laser")` stores `model` and `_begin_test` draws `Difficulty.get("printer","questions")` (2 / 3 / 4) from the pool filtered by model, using `rng("printer")`. Each model defines `phases` (ordered list drawn from jam, tray, toner/ink/roll, shake, test), `colors`, and `TEXT` overrides (help lines, intro). `Onsite` passes the model from the site type (`SITES`: architect plotter, dental receipt/laser, law MFP, vet inkjet, realty laser, trailer dot matrix later) and from the job's `game` field. Marker speed, zone width and `_score()` thresholds read `Difficulty`. `strings.txt` carries the questions and texts. Tests: extend `tests/printer.gd` (every model finishes on a perfect and a failed run; pool has no duplicate error per model; `correct` in range) and add `printer_shots.gd --model=`.

**3. Karaoke song table.** Add `SONGS` (4 entries: pop "Wobble Wobble Pop", country "Dirt Road Friday", 80s "Neon Gym Class", rap "Fast Rap Hot Mess"; all invented titles and lines) with `gap`, `len`, `lanes_pattern`, `doubles`, `holds`, `cuts`. Refactor `_kara_setup` to `_kara_chart(song, rng)` returning notes, and store `g.len` / `g.gap` so `_kara_tick`, `_kara_end`, `_paint_karaoke` (the `0.75`, `45.0` px/s and progress bar) and the `lyrics` fx all read the song, not constants. Song selection: a card at the mic (`Cards.ask`) listing 3 songs, with the 4th unlocked by a medal; in a campaign the default is the one not yet three-starred. Hit windows and gap multipliers come from `Difficulty.get("karaoke", ...)`. v1 skips hold notes and duets. Tests: `tests/outings.gd` plays each song through `kara_hit` with perfect timing (3 stars) and with no input (0 stars); `tests/content.gd` checks the minimum gap exceeds the good window and every lane appears; `inroom.gd` runs the in-room strip with one non-default song.

## 6. Things to avoid

- **Period**: no AI, no assistants, no streaming-first culture, no Slack, Teams, Discord, TikTok; no 2015+ phones, apps or events; no "zero trust", no MFA as an SMB norm; Windows 7 / 8.1 / XP only; Chromebooks, Dropbox, Instagram, Vine, Flappy Bird, Candy Crush, Heartbleed (April 2014) and the Target breach (Dec 2013) are fine. See IDEAS.md "Setting: 2013-14" for the full list.
- **No real brand names or real songs**: invented titles and invented lyric fragments only; no real bands, artists, labels, radio stations, TV shows or movies in topic lists (use "THE BIG GAME", "A TV SHOW", "A SUPERHERO MOVIE"). Printer models use fake makes (as the game already uses LabRat, ConnectWhy, Hewlitt). Add a deny-list check in `tests/content.gd`.
- **No punishment for family or health**: absence from an outing is always allowed gracefully (a mild, honest opinion cost as today, never hidden); NPCs who skip never cite a child or illness as a reason the player is judged; flu-season mutator hits the cast's availability, not the player's score. Dietary quirks are affectionate, not mocked. No difficulty effect tied to the player's energy in the outings; on the printer job it is capped and shown.
- **Fairness**: every harder tier must remain beatable (floors in `Difficulty.get`); randomness shown on the intro page; the first five days stay gentle (`DAY_CAPS`).
- **Do not** let Year 2 or mutators silently change save formats; version every new save section.
- **Do not** add online leaderboards or telemetry; a daily seed is local only.
- **Do not** make a mutator contradict an existing story beat (no Heartbleed week on the ransomware day 14, check `Playbook.BOOKS` days).
- **Do not** put art-heavy items (themed escape rooms, line-printer boss art) ahead of the table and seed work; they multiply cost without a harness to test them.
