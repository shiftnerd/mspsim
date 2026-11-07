# Scope: 2-player local couch co-op (roadmap R34)

Read-only scoping pass (Nov 2026) from the code at commit 752a63f, not play-tested. Every claim below was checked by grep or by reading the file; line numbers drift, function names are the stable handle. One claim was checked by running Godot 4.7.2 on a scratch script outside the repo (the device-id behaviour in section 2.1, finding 5). Items marked (inferred) are readings of the code, not runs. Section 8 lists what I could not determine.

**User design (decided):** optional 2-player local co-op, Mario style: ONE shared screen in the SAME room, the camera frames the group, a player cannot run out of the shared view (the other holds the group back), anyone who uses a door or room portal takes everyone with them. Takeover screens (computer, phone, cards, day report, mini-game pages) become NON-BLOCKING: the world keeps running, and the takeover is the only thing that splits the screen (one pane per player, the other player keeps playing in the room). Outings become genuinely two-player. Two gamepads, one each; keyboard plus pad for testing. Switch or PC later, never mobile; online is far off, so keep the architecture netcode-friendly. Single-player must stay byte-for-byte the default (a feature flag).

## 1. Summary and recommended plan

**Verdict: feasible, and cheaper than it looks, because three things in the code already point the right way.**
1. **One room is one scene, and the world is simulated apart from the scenes.** `Game.go` does `change_scene_to_file`, `World.chars` holds every cast member as data (`scene`, `legs`, `leg_t`), and NPC nodes only exist for the loaded room (`World.populate`, `_spawn`). So "everyone goes through the door together" needs no multi-scene streaming: both players are always in the loaded scene, and `Game.go` simply places both at the arrival spawn.
2. **The takeover screens do not stop the world today, they only stop the player body.** `Computer.open` sets `Game.ui_open = true`; `World.time_scale` is untouched, tickets, SLA and the cast keep running (`msp.gd` `dt := delta * World.time_scale`). Only the modal systems freeze things: `Cards.is_open` gates 26 tickers (`shift.gd:354`, `meeting.gd:54`, `events.gd:2413` ...), and `Outings._open` / `Onsite` set `World.time_scale = 0.0` (`outings.gd:967`, `onsite.gd:1516`). Non-blocking takeovers are therefore mostly a matter of replacing the single global `Game.ui_open` by a per-slot flag.
3. **The UI is code-drawn and instantiable.** `computer.gd`, `phone.gd`, `cards.gd`, `day_report.gd` have no `static var` and no reference to their own autoload name (grep), they size themselves from `get_viewport().get_visible_rect().size` (`computer.gd:769`), and the layouts already branch on width (`body.size.x < 250.0` = narrow, `body.size.y < 100.0` = compact). A second `COMPUTER.new()` placed under a `SubViewport` is a second computer with its own state, no rewrite of the 2889-line file. This is the riskiest assumption and phase 0 proves it.

**What is hard:** (a) the global singletons that hold "the player": `Game.ui_open`, `Game.busy`, `Game.ui_shift`, `Player.current_character` (a `static var`), `Look.look / acc / active`, `Skills`, `Shift.energy`, `Growth`, `Nerf.ammo`, `Game.vars held / sips`, and 14 `Actors/Player` lookups; (b) every interactable zone remembers exactly one player (`door.gd:14`, `seat.gd:16`, `interact.gd:11`); (c) pad-only play: the computer is mouse-centric and the pad events are bound to device 0 only; (d) the 54 tests that find `Actors/Player`.

### Recommended design in one table
| Topic | Recommendation |
|---|---|
| Formats | Co-op supports `h` (320x180) and `wide` (368x128). `v` and `vclose` are disabled while co-op is on (F9 skips them): at 180 px (or 90 px set width at zoom 2) two characters plus a tether leave no room. `h` is the design format: x4 = 1280x720 (Switch handheld) and x6 = 1080p, both integer scales (`Game.FORMATS`). |
| Camera | Shared. Rooms that fit one screen (most are 176 to 320 wide in `world_data.gd`) need no scrolling and no tether in `wide`. In `h` and for long rooms (`stage.gd` `_long`) the camera follows the midpoint and the lead player is clamped to the view. |
| Doors | Whoever uses the door takes the group. A partner with an open takeover refuses the door (toast), E held for 1.5 s forces it (their pane closes, a running RMM job survives). Bathrooms are the one allowed split (section 3). |
| Takeovers | One pane per player (half the window), the other half stays the live room. Phase 3a covers a half with the pane and slides the camera (the existing `Game.ui_shift` idea, horizontal); phase 3b is a true second camera. |
| Career state | **Shared:** reputation, cash, tickets, SLA, clock, story flags, coworker opinions, difficulty, seed. **Per player:** skills and XP, PowerShell level, energy, build, growth plan, look, phone choice, held item, darts. XP goes to the player who ran the fix. |
| Input | A `Players` autoload with two slots; per-slot InputMap actions (`p2_` prefix) with the pad's device id; slot 0 keeps today's action names, so single-player is untouched. Join by pressing A. |
| Online later | Slots, inputs as data, per-slot state in `RefCounted` objects, no new global singletons for per-player state (section 5.4). |

### Phased plan
Sizes follow ROADMAP: S under a day, M 1 to 3 days, L a week or more, XL two or more L.

| Phase | Deliverable | Size | Test strategy |
|---|---|---|---|
| **0 Spike (DONE, `docs/coop-risk-findings.md`)** | Prove (a) two pads separate in 4.7.2 (done, below), (b) a second `computer.gd` instance inside a `SubViewport` of 160x180 draws, takes pad input and a pad cursor, while the room behind it keeps ticking, (c) two `Player` nodes in `main_floor` with a group door. Throwaway branch, no flag, no saves. | S | A scratch test that prints pass lines; the layout audit (`LAYOUT_AUDIT=1`, `PixelFont.audit_report`) over the pane at 160x180 and 184x128. |
| **1 Foundations (flag off)** | `Players` autoload and `PlayerSlot`; `Controls` slots, devices, join and hot-plug; `Player.slot`; second player spawned by `stage.gd`; zone `_player` fields become lists; seat occupancy for players; per-slot Tab pick; per-slot `Look` use; NPC "nearest player"; bathroom rule. Free Play only, no takeovers yet. | L | All 220 existing tests unchanged and green with the flag off; new `tests/coop_*.gd` (section 6). |
| **2 Camera, tether, group doors** | Shared camera framing, clamp (math proven at every format), edge markers, `Game.go` carries both players (spawn position BEFORE `add_child`), auto exits count as group doors, `World.player_left` and follow-me use the group, split trips (bathrooms), long rooms. | S-M | `coop_camera`, `coop_doors`; extend `followcam`/`format` screenshots. |
| **3 Split-screen takeovers** | Per-slot `ui_open`; a `Takeover` host that puts a `Computer` / `Phone` / `Cards` instance in a half-window `SubViewport`; `Game.ui_shift` removed from the co-op path; cards get a scope (player or team; the freeze is the single `World.time_scale` getter); pad cursor (snap-to-hit) and pad-only navigation for every takeover; day report shared; layout fixes for the four narrow-pane screens. 3a overlay half (proven), 3b second camera (proven affordable). | L (3a) + M (3b) | `coop_takeover`, `coop_cards`, layout audit per pane size, pad-only click-through of every app. |
| **4 Free Play co-op complete** | Character select and creator for player 2 (sequential), outfit swap per slot, held items and cups per slot, darts per slot, follow-me target, pause, number-key character swap per slot, `Look` as a per-slot object. | M | `coop_look`, `coop_items`, updated `outfit`, `playeras` variants. |
| **5 Tech campaign co-op** | Per-slot `Skills`, `Shift.energy`, `Growth`, `Build`; ticket claim and XP credit; shared rep and SLA; co-op difficulty dial; `Roles` for two players; save and resume `coop` section; Career profiles; co-op bot. | L | `coop_campaign`, `coop_save`, bot balance run with two bots. |
| **6 Outings, genuinely two-player** | Bowling in turns, karaoke duet, two-player escape room, cornhole teams, cookout together, chair race side by side; printer game and dinner last. | L | `coop_bowling`, `coop_chair_race` ... headless on the existing `RefCounted` rules. |
| **7 Other campaigns** | Owner (Alan and Garrison, the second owner is player 2), service manager, sales, onsite visits, Rodent Nation trip. | L | `coop_owner` and friends. |
| **8 Polish and console readiness** | Remap, rumble, per-pane font and layout polish, performance pass with two viewports, controller-only title and menus, Switch dry run if an export path exists. | M | Frame-time test, soak test. |
| (later) Online | Not scheduled; section 5.4 keeps the door open. | XL+ | n/a |

**Total after the spikes: about 7 to 8 L of work** (was 8 to 10; P3a dropped from XL to L, P2 from M to S-M). **First playable slice = phases 0 to 4** (Free Play, two people in the office, split computers, shared cards). The tech campaign (phase 5) is the first full mode.

**Cut first, in this order:** online; phase 7 service and sales (keep owner as the natural Alan + Garrison duo); phase 6 printer game and dinner (they have no obvious second seat); 3b true second camera (keep the 3a overlay); per-player `Growth` (share it); Career profiles (P2 earns no medals); `vclose`/`v`, which are already cut.

### Phase 0 spike: the riskiest assumption
The riskiest assumption is not "two characters can walk in one room" (mechanical). It is **"the code-drawn takeover UIs can run twice, in half-size viewports, driven by a pad, while the room stays live."** If that fails, phase 3 is not an XL, it is a rewrite of `computer.gd`, `phone.gd` and `cards.gd`.
- **0a (done in this pass).** Per-device InputMap matching, run on 4.7.2 in a scratch script: actions `p0_right` and `p1_right` bound to a D-pad event with `device = 0` and `device = 1`; a device-1 `parse_input_event` makes only `p1_right` true; an event left at the default `device` (0) does **not** match a device-1 press; `device = -1` matches any. So per-slot actions work headless, and tests can drive pad 2 with `Input.parse_input_event`.
- **0b.** In a scratch test: `var c = preload("res://scripts/computer.gd").new()` inside a `SubViewport` (160x180), `open(1)`, press D-pad and A through `parse_input_event(device=1)`, add a stick-driven cursor that calls `c.click(at)`; assert it paints with no layout-audit hits, and that `Msp.tickets` keeps changing (the room is live). Needs `SubViewport.world_2d` shared for 3b; for 3a it does not.
- **0c.** `stage.gd` spawns `player.tscn` as `Actors/Player2`; both walk; `Game.go` through `main_floor` -> `kitchenette` with both.
- **Pass:** 0b paints and navigates by pad, no engine errors, no more than ~2 ms extra frame time. **Fail:** fall back to "one takeover at a time, the world live, the second player queued" (Plan B, costs about half of phase 3) and say so to the user before phase 1.

## 2. Audit of single-player assumptions

### 2.1 Findings that shape the plan (each verified)
1. **`Actors/Player` is a fixed node name in every room.** 63 of the 66 scene files instance `player.tscn` under `Actors` (`grep 'instance=ExtResource("player")'`); `stage.gd:36` does `get_node("Actors/Player")`. Eleven scripts look it up by path (14 hits): `fx.gd:224`, `nerf.gd:118`, `npc.gd:430` and `:586`, `onsite.gd:1873` and `:1898`, `outings.gd:942`, `pause_menu.gd:36`, `resume.gd:77`, `stage.gd:28/36`, `talk.gd:397`, `toolbox.gd:195`, `world.gd:889`. Plus `outings.gd` has 12 `_actor("Player")` calls (`outings.gd:2318`). The second player does not need to be in the .tscn files: `stage.gd` can instantiate `player.tscn` at runtime (so `tools/make_godot.py` and `tools/check_generator.py` stay untouched).
2. **Every interactable remembers one player.** `door.gd:14`, `seat.gd:16`, `interact.gd:11` each have `var _player: Node`, set on `body_entered` and **nulled on any `body_exited`**. With two bodies in one zone, when one leaves the other loses the arrow (`_arrow.visible = false`, `_player = null`). The per-body `_near` list in `player.gd:51` is fine; the zone side is not.
3. **A seat does not know about the player.** `seat.occupied` is written only in `npc.gd:316` and `:349`; `Player.sit()` (`player.gd:306`) never sets it. Today nothing else can compete for a chair; with two players both can sit in the same seat (and `chair_roll.gd:288` reads `occupied`).
4. **`Game.ui_open` is the one switch that freezes the player, and 19 scripts write or read it (52 hits).** `player.gd:460` returns from `_physics_process` while it is true; it also gates nerf (`nerf.gd:133,151,185,412`), toasts and hints (`hints.gd:65`, `hud.gd:98-102`), the phone (`phone.gd:62`), the outfit swap, pause (`pause_menu.gd:40`) and the glance fx. `cards.gd:101` recomputes it as `Computer.is_open or Phone.is_open or PrinterGame.is_open or Outings.is_open or Toolbox.outfit_open` when a card closes.
5. **Gamepad events are bound to device 0 only.** `Controls.ensure()` builds `InputEventJoypadButton.new()` and `InputEventJoypadMotion.new()` and never sets `device`; on 4.7.2 a new event has `device = 0` and the InputMap match is strict (spike 0a). So a second pad does nothing today, and so does a first pad that Windows enumerates as index 1. There is no `Input.get_connected_joypads` or `joy_connection_changed` anywhere in `scripts/` (grep). Keyboard actions are device independent.
6. **The look system already takes an explicit look.** `Look.apply(sprite, character, custom, look_dict)`, `Look.frames_for`, `Look.sheet_for`, `Look.make_material(look, acc)` and `Look.copy_look()` all accept a look dictionary, because the NPC copy of the player uses it (`npc.gd:21 custom_look`, `tests/npc_twin.gd`). `HeadGear` and `ClothesGear` hash `[_on, _look or [Look.look, Look.acc]]` (`head_gear.gd:65`, `clothes_gear.gd:43`). What is global is only `Look.look / acc / active` and `Look.is_custom()` (`look.gd:492`: `active and PLAYER.current_character == BASE`).
7. **`Player.current_character` is a `static var`** (`player.gd:22`), read by `campaign.gd` (lines 249, 288-291, 366-378, 448), `look.gd:493`, `npc.gd:355` (a cast member whose character equals it is hidden: the "ghost" rule), `charselect.gd` and `toolbox.gd:210`.
8. **The three heaviest takeovers are plain `CanvasLayer` scripts with their state in fields**: `Computer` (layer 60, ~60 fields), `Phone` (61), `Cards` (65), `DayReport` (70), `Review` (72), `Outings` (66). `Computer.open(desk)` sets the PC (network via `Net.desk_state`), `app`, selection, `_job`.
9. **Random streams: partly deterministic already.** `Difficulty.rng(stream)` / `rng_for(stream, salt)` (`difficulty.gd:452`, `:469`) seed one `RandomNumberGenerator` per named stream from `run_seed`; the stream states are saved (`Difficulty.to_dict`). About 133 call lines use them (tickets, fleet, fix outcomes, pairs: `msp.gd:550-1603`; printer, karaoke, bowling, chair race, dinner). About 113 call lines still use the global RNG (heuristic grep: `owner.gd` 23, `outings.gd` 16, `projects.gd` 12, `shift.gd` 9, `nerds.gd` 9, `world.gd` 8), and the RMM fix failure is one of them: `computer.gd:619` `randf() < Skills.fail_chance() + ...`. For co-op, per-slot streams are a one-liner: `Difficulty.rng_for("fix", slot)`.

### 2.2 Audit table (where the single player is baked in)
| Area | Where | Assumption | Co-op change |
|---|---|---|---|
| Player node | `player.gd`, 63 scenes, `stage.gd:36` | one node `Actors/Player`; `add_to_group("player")` (`player.gd:65`); `sfx.gd:337` uses `get_first_node_in_group("player")` | `Player.slot` export; group `players`; second node `Actors/Player2` spawned in `stage._ready`; helper `Players.node(slot)`. Keep the `Actors/Player` path for slot 0. |
| Input reads | `player.gd:466-522` (14 `Input.*`), `_unhandled_input:161` | global action names, any device | `_a("move_left")` -> `"p2_move_left"`; `Controls.matches(event, action, slot)`. |
| Character | `player.gd:22,128`; `_switch_character:136` | one static name | instance `character` field plus the static as the slot-0 mirror (so 13 references stay valid). |
| `Game.ui_open` | 19 scripts, 52 hits | one global | `Players.ui_open(slot)`; `Game.ui_open` becomes `any slot` for old callers (keeps today's value in single-player). |
| `Game.busy` | 10 scripts, 17 hits (`Game.go`, `player.gd:465`, `phone.gd:62`, `npc.gd:507,591`) | one fade/transition lock | stays global: a group transition is one event. |
| `Game.ui_shift`, `UI_STRIP` | `game.gd:22,31`, `stage.gd:143-165`, `computer.gd:148,772`, `phone.gd:86` | camera slides down so the player shows in a strip above one full-screen UI | not used in co-op: pane per half; `UI_STRIP` becomes an instance variable (0 inside a pane). |
| Camera | `stage.gd:35-48,113-165` | one `Camera2D` following `_player.global_position.x`; `wide` is static at (184, 64) | midpoint plus clamp (section 3). |
| World cast | `world.gd`: `populate:227`, `player_left:685`, `set_following:665`, `send_vic_to_player:875`, `cast_of:423`, `player_desk:431`, `roster_gone:405` | one `Campaign.player_as`; "follow me" has no owner; John walks to one player | `follow` stores a slot; `player_left` becomes `group_left`; John/Morgan visits go to the nearest player; roster gone = all players' cast characters. |
| NPC awareness | `npc.gd:353-360` (ghost), `:426` `_follow_tick`, `:584` `_update_greeting`, 12 `_player` uses; `fx.gd:223-271,1296` | `_player` = `Actors/Player` cached | `Players.nearest_to(x)`; ghost rule over all slots. |
| Doors | `door.gd`, `Game.go:109`, `World.player_left` | `use(_body)` ignores who | group transition (section 3). `occupancy` doors call `World.bathroom_occupied`, which counts any `CharacterBody2D` in `Actors` (`world.gd:132-146`), so a second player already counts as "somebody inside". |
| Seats | `seat.gd`, `player.gd:306`, `world.gd` seats, `seat_life.gd` | occupancy only by NPCs | `Seat.use(body)` sets `occupied` for players; `_stand_up` clears; the second player walks on to the next free seat (arrow shakes: `seat.gd:53` already does that for `occupied`). |
| Chair roll | `chair_roll.gd`, child node of each `Player` (`player.gd` `_roll`) | bumps NPCs only (`BLOCKERS`, coworker REACT) | already per player instance; add players to the bump list. |
| Held items | `held_item.gd`, `player.gd:202 give`, `Game.vars["held"/"sips"]` (read in `_ready`) | one cup | per-slot `held / sips` in `PlayerSlot`; `Game.vars` keys stay for slot 0. |
| Nerf, aim, duck | `nerf.gd` (`ammo`, `charge`, `charging`, `_player()` at 116), `aim.gd`, `player.gd` duck | one gun, one charge | `Nerf.ammo/charge/charging` move to the slot; `fire_player(p)` already takes the node. No friendly fire between players by default. |
| Interact target | `player.gd:81 nearest()`, `:104 cycle_pick`, `_pick` | per node already | works per `Player` unchanged; Tab/Shift+Tab become the slot's `pick_next/pick_prev` action. |
| Talk | `talk.gd:393-397` `_player()`; one `_who/_npc` | one conversation | one conversation per slot, or one at a time with the first asker (Phase 4, recommend one at a time). |
| HUD, hints | `hud.gd:30-124`, `hints.gd:55 toast`, `Hints.text/toast_text/objective` | one clock/count block, one toast line, hidden while `ui_open` | team block stays; add `NRG a | b` per slot; `Hints.toast(msg, secs, slot := -1)`, drawn in the player's colour. |
| Bubbles | `bubble.gd`, `player._ensure_bubble` | per node | unchanged. |
| Cards | `cards.gd:37 ask`, 156 `Cards.ask` calls in 27 scripts, 90 tests mention `Cards` | one modal, one queue, freezes 26 tickers | scope parameter (section 3); `ask` signature gains a trailing optional `slot := -1`. |
| Day report | `day_report.gd:59,88`, 473 lines | one modal | shared full-screen, both continue. |
| Computer | `computer.gd` (2889 lines), 12 scripts reference `Computer.` | one autoload | slot 0 stays the autoload; slot 1 is an instance in a pane (phase 0b). `Computer.is_open` callers (9) ask `Players.any_computer_open()`. |
| Phone | `phone.gd` (806), `Phone.os` saved in `user://mspsim_phone.cfg` | one phone | one instance per slot; each player picks iFone or Nexxus. |
| Pause | `pause_menu.gd:36-42,167`; `get_tree().paused = true` | tree-wide pause; Start button on `Controls` | fine for local; any pad's Start; `can_open` needs "any player node". Pause menu ownership: the slot that opened it navigates. |
| Title, select | `title.gd` (618), `charselect.gd` (1519; `setup`, `confirm:471` writes `PLAYER.current_character` and `Look.active`) | one picker | second sequential `CharSelect` instance (it already runs as an overlay in `Toolbox.setup_overlay`). |
| Saves | `campaign.gd:442 _write_sections`, `resume.gd:75 player_dict`, `apply_player:193` | one `character`, one `look`, one `skills` ... | add a `coop` section; old saves lack it and load single-player. |
| Career | `career.gd`, `user://mspsim_career.cfg` | one profile per machine | P2 profile later (cut candidate). |
| Outings | `outings.gd` (3919 lines), `chair_race.gd`, `cornhole_game.gd`, `grill_game.gd` | "YOU" against crew | section 3 per game. |
| Onsite, Rodent Nation | `onsite.gd:1405...`, `conference.gd:1150` | one traveller | phase 7. |

### 2.3 Autoload state: shared, per player, per profile
| Autoload | Holds | Co-op |
|---|---|---|
| `Skills` (`skills.gd:89-91`) | `xp`, `ps_level`, `lesson_day` | **per player** (it has `to_dict/from_dict`, `reset()` reads `Build.tech_levels()`). |
| `Shift` (`shift.gd:67-83`) | `energy`, `late_min`, pager counters, `stay_*` | `energy`, `late_min` **per player**; day-level traffic and on-call roster shared (alternate on-call by day). |
| `Growth` (`growth.gd:28-44`) | focus, helper, progress, graduated | **per player** (cut candidate: share). |
| `Social` (`social.gd:33`) | `rel` coworker opinions, `day_delta` | **shared** (the team's standing). |
| `Campaign` | `rep`, `cash`, `scars`, `day`, `player_as`, `build` | shared except `player_as`/`build` per player. |
| `Msp` | tickets, emails, texts, endpoints, backups | **shared** with a per-ticket `claim` slot. |
| `Hints`, `Toolbox` | one-line toast; Free Play tools UI | toast per slot; Toolbox stays a Free Play thing for slot 0 (+ outfit per slot). |
| `Look` | `look`, `presets`, `acc`, `active` | **per player** (a `LookSet` object). Presets per profile. |
| `Nerf` | `ammo`, `charge`, `charging`; war score | ammo/charge per player; score shared. |
| `Resume` | `player_dict` | list of players. |
| `Net` | `carrying` (a cable end, `net.gd`, checked at `campaign.gd:491`) | per player (two cable ends is a free co-op puzzle). |
| `Difficulty` | tier, seed, streams | shared; add `rng_for("...", slot)`. |
| `Phone.os` | iFone or Nexxus | per player. |

### 2.4 The takeover screens at half size
- **Mechanics.** Every takeover paints from `_paint()` on a `Node2D` canvas under a `CanvasLayer`, hit-tests its own `_hits` array, and reads `get_viewport()`. Under a `SubViewport` `get_viewport()` is the sub viewport, so the size and the mouse position are local. `_paint` in `computer.gd:768` also uses `Game.UI_STRIP` (`:772`) to leave 20% of the height visible for the room: inside a pane that strip is wasted and must be 0 (instance variable).
- **Window sizes.** Per pane: `h` 160x180 (close to the portrait `v` layout the code already supports at 180x320, but 140 px shorter), `wide` 184x128 (height is the problem: `compact` is `body.size.y < 100.0` in `_paint_backups`, `computer.gd:1608`, the taskbar takes `TB = 11`). I did not run the audit at those sizes (section 8). The tool exists: `LAYOUT_AUDIT=1` plus `tests/layout_audit.gd` reports text that leaves the viewport or overlaps.
- **Phone.** `_sc = 2 if body.size.x >= 118.0 else 1` (`phone.gd:325`): scales itself; a pane of 160x180 fits.
- **Cards / day report / review.** Plain panels sized from the viewport (`UiStyle.panel_rect`), fine at 160 wide with `wrap_text`; the card text lengths are the risk (long owner-campaign cards).
- **Mouse.** One mouse. Every takeover has mouse clicks plus partial key/pad navigation. `Computer._input` (`:187-239`): arrows and A/B move a list and confirm (`move`, `enter`, `escape`), `_app_key` adds pad handling for Dispatch, Knowledge and Nerds. The desktop icons, taskbar apps, the RMM session buttons, PSA CLOSE and most dialogs are `_hits` rectangles reached by mouse only. **Pad-only play needs a stick cursor** that calls the same `click(at)`: the `_hits` design makes that about 80 lines, not per-screen work. Gap list for the audit: computer desktop and taskbar, RMM tree and session actions, PSA buttons (close ask), boardroom tabs, Lynk, forum, `Crm` (keys by `event.keycode`), Dashboard chart switch; phone home/apps are keyboard-capable (`home_sel`) but check the settings page; `outings.gd` mostly uses `Controls.*`, with 48 raw `keycode` checks (digits, letters) for escape and dinner; `charselect.gd` has 19 `Controls` calls and 12 raw key checks (name entry grid is pad-ready: `open_name_grid`).

### 2.5 Tests that assume one player
220 test files in `godot/tests` (`ls | grep -c '.gd$'` minus the harness). 54 mention `Actors/Player`: `bathrooms bell castchat chair_race chair_roll chat closet computer confcup dance deskcup doors dualmon duck edges emote extras fx fridge gestures follow followcam inroom inroom_shots items lights maprework nerf nerf_duck nerf_modes nerf_play nerf_shots nerf_war npcphone onsite outfit outing_content_shots outing_ui_shots phone playeras prio rooms roster_shots sales seats sipface smoke talk variety_shots warehouse warehouse_door_shots warehouse_lot warehouse_lot_shots warehouse_shots`. 23 drive input with `Input.action_press`, 12 with `parse_input_event`, 21 with `InputEventKey`; 90 reference `Cards`, 40 reach `Computer` by `root.get_node("Computer")` (so **autoload names must not change**). None needs to change in phase 1: they run with the flag off. Two-player variants (new files, not edits) are listed in section 6.

## 3. Design questions with recommendations
| Question | Recommendation | Why (code) |
|---|---|---|
| Shared career or per player? | **Shared team score, per-player build.** One reputation, cash, day grade and ticket book; skills, PowerShell level, energy, growth and look per player. | `Campaign.rep` and `Msp` are single and everything else reads them; `Skills`/`Shift` already have `to_dict/from_dict`, so per-slot copies are mechanical. |
| Who gets XP? | **The player who ran the fix.** Ticket gains `claim` (slot of the first opener); closing a ticket someone else claimed pays the closer in full and the claimer 25%. | XP is added in `Skills` from the RMM job end (`computer.gd _finish_job`); the job knows its pane. |
| One ticket queue? Same desk? | One queue. Two players cannot use the same PC: a seat is exclusive once players set `occupied`, and `_seat_computer()` (`player.gd:260`) opens only from your own seat. Standing at the monitor zone (`interact.gd:67`) is blocked while the desk's PC is in use (`Players.pc_busy(desk)`). The PSA greys a ticket "IN USE BY P2" while the other pane has its detail open. | Prevents double closes and double `_job`s on one endpoint. |
| SLA and reputation | Shared. Co-op dial `coop.pace` (Difficulty TABLE) raises ticket arrival about 1.5x so two players are not bored; SLA windows unchanged. Start at 1.5, tune with two bots. | `msp.gd:1585` gap is `randf_range(45, 90) * pace / workload`. |
| Tether and room change | `stage.gd` computes the camera x from the midpoint (clamped by the existing `limit_*`), and clamps each player to the camera rect minus 12 px. Rooms that already fit the screen need nothing. The tether stops the leader without a rope; an edge arrow marks an off-screen partner (only possible in long rooms). `Game.go(scene, spawn)` stays one call; it records `Players` (character, held, sips, state) and `stage._ready` places player 2 at the same spawn +14 px. `World.player_left` gets both slots. | `Game.go:109`, `stage.gd:26-48`, `world.gd:685`. |
| Mid-takeover when the group walks out? | The door **refuses** (toast "P2 IS AT THE COMPUTER") while the partner has a takeover that is not safely closable; hold E 1.5 s to force: their pane closes with the existing `close()`. RMM fix and script jobs keep running with the pane closed (`computer.gd _process`, lines 159-171 keep `fix/script/scriptall` jobs, drop others). Auto doors (`auto = true`, edge exits) check the same rule. | A door that silently drags a partner out of a half-typed note is the one thing that would feel hostile. |
| Seat and bathroom rules | Players set `occupied`; a taken seat shakes the arrow for the second player. Bathrooms are single occupancy by design (R22): the **one split trip**. Only the door user enters; the partner idles at the door (frozen, a dots bubble), the camera follows the one inside, the trip is capped by the existing bathroom wait logic (`BATH_WAIT`), and the group reunites on exit. A second player cannot follow in because `World.bathroom_occupied` is true. | `door.gd occupancy`, `world.gd:132-170`. |
| Doors that need both | None exist today. New co-op-only props (later): cable end carry in the closet (`Net.carrying`, one end each), the warehouse overhead door (`special = "dock"`: two switches), the two-person lift. | `net.gd`, `door.gd:49`. |
| Speech/chat cards, whose card? | Every card has a **scope**: `player` (shown in the asker's pane; talk menus, phone texts, personal decisions) or `team` (full-screen for both: owner decisions, story beats, anything the day report depends on). Default for the existing 156 call sites is `team` (identical behaviour), then reclassify `Talk` and the personal ones as `player`. Team cards: the first player to confirm answers (the existing 600 ms early-confirm guard, `cards.gd _opened`, stays). Only `team` cards freeze the sim (`Cards.is_open` gates). | `cards.gd:37-110`. |
| Shared camera and formats | `wide` 368x128: fits every normal room, two characters (18 px wide) fit comfortably; takeover halves 184x128 are tight (see 2.4). `h` 320x180: design format; tether active in the 368-wide main floor. `v` 180x320 and `vclose`: disabled in co-op (a 150 px usable width with a tether is a one-lane corridor). Long rooms (warehouse 1480, a 780 px set) scroll in every format. | `game.gd:14`, `world_data.gd`, `stage.gd _long`. |
| Difficulty tiers and cozy Easy | One tier per table. Cozy (rep floor, soft SLA) applies to the shared score unchanged; per-player energy slowdowns follow each player's own energy. | `difficulty.gd cozy_on()`. |
| Mastery ramp | Per profile (`Career good.<game>`); for a shared game use the **mean of the participants**. P2 without a profile uses the host's. | `difficulty.gd mastery`, `career.gd`. |
| Free Play creator for player 2 | Sequential: P1 picks, then a second `CharSelect` for P2 (it already runs as an overlay). Same stock character twice is allowed; the second is auto-tinted and both get a coloured arrow (P1 blue, P2 orange) above the head. | `charselect.gd setup/confirm`. |
| Outfit swap and `Look` | `Players.slots[i].look` replaces the three globals. `Look.is_custom()` becomes `Look.is_custom_for(slot)`. Keep `Look.look` as a property that returns slot 0's, so single-player callers (44 hits in 6 files) are untouched. The outfit overlay opens as a pane for the slot that pressed Y. | `look.gd:216-220,492`, `toolbox.gd:205`. |
| `HeadGear`, `ClothesGear` overlays | Already per sprite (they hash their own look). Memory: a custom person in real clothes carries about 8 overlay sheets at 2.6 MB VRAM each, about 8 per look including hair (CLAUDE.md, character creator step f); two custom players are about 20 MB of VRAM before the body sheets. Fine on PC; check on Switch. | `clothes_gear.gd`, `head_gear.gd`, CLAUDE.md. |
| Twin-style NPC copy | `Look.copy_look(over)` (`look.gd:767`) copies slot 0's look. It takes the active slot as an argument; an NPC copy of player 2 is possible and free. | `npc.gd:21`. |
| Cast rule (playing as a cast member) | Free Play: both can pick cast characters; both ghosts hide (`npc.gd:355` generalised). Tech campaign never plays a cast member (`campaign.gd:248-259`), so both are new hires. Owner campaign: P1 Alan or Garrison, **P2 is the other owner** (replaces the co-owner NPC, `Roles.partner()`, `Partner`). | `campaign.gd derive_player_as`, `roles.gd`. |
| Outings | See table below. | |

### Outings as real multiplayer
| Game | Today | Co-op |
|---|---|---|
| Bowling (`_bowl_setup`, `bowl_variety.gd`) | you against up to 4 crew, five frames | frames in turn order P1, P2, crew; each player's pad stops aim then power; one scorecard row each. |
| Karaoke (`_kara_setup`) | one lane of arrows | duet: two lanes (one per player), a shared crowd meter; lyrics screen unchanged. |
| Escape room (`_escape_setup`, `_escape_room_setup`) | one code, hints from friends | each player holds half the clue zones in the room, the code is entered by either; a shared timer. |
| Cornhole (`cornhole_game.gd`, RefCounted) | you against one crew member per round | teams: P1 + P2 against a crew pair, alternating throws; the rules class has no autoload references, so headless tests are easy. |
| Cookout (`grill_game.gd`) | one grill | one grill each, shared order ticket. |
| Chair race (`chair_race.gd`, `ChairTrack`) | you plus crew rivals, `push_a/push_b` alternating Z/X | two racers side by side on lanes; the rules class takes `racers` and a stream, so a second human is an extra rival with an input feed. |
| Printer game, dinner | one decision stream | cut candidates; dinner could let each pick a topic alternately. |

## 4. Input and platform plan
**Slots and devices.** `Players` keeps `slots[i].device`: `-1` keyboard, `0..n` joypad index. Slot 0 defaults to keyboard plus the first pad that presses A; slot 1 is the next pad. A "keyboard split" profile (P1 WASD, P2 arrows) is a data change in `Controls.ACTIONS`, which is table driven (`controls.gd` top).
**Actions.** `Controls.ensure()` stays; `Controls.ensure_slot(i, device)` registers `p2_*` copies of the `ACTIONS` table with `device` set on every pad event (and keyboard events for a keyboard slot). Slot 0 keeps the names `move_left`, `interact` ... so every existing `Input.is_action_*` and `Controls.matches` call and all 23 + 12 + 21 input tests are unchanged. While co-op is on, slot 0's pad events get `device = slot0.device` instead of `0`.
**Events.** `Controls.slot_of(event)` returns the slot that owns an event (key events: the keyboard's slot; pad events: by `event.device`). Each takeover guards its `_input` with one line `if Players.slot_of(event) != my_slot: return`. `Controls.pressed/nav/confirm/back` stay as they are (they already take events, and the stick-push state is keyed by `device * 32 + axis`: `controls.gd:223`, which is already multi-device safe).
**Joining.** A "PRESS A TO JOIN" strip on the title/character select; join by A on any unclaimed pad; Start from a joined pad pauses. Leaving: hold Back 2 s drops the player to an idle NPC-like state (they stand and wait, never block a door); rejoin by A.
**Hot-plug.** Subscribe to `Input.joy_connection_changed`; on disconnect pause the game and show "RECONNECT PAD 2 (A TO RESUME)"; on reconnect re-bind by device id. Nothing like it exists today (grep).
**Remap.** Not today: `Controls.HELP` is a text table. Phase 8: a `user://mspsim_controls.cfg` with per-slot overrides read by `ensure_slot`.
**Pad-only UI gaps.** See 2.4: the stick cursor is the single biggest item and must exist before any takeover ships to a pad player. Also add pad labels in `Controls.HELP` (pages exist per input kind) and the `Hints.DAY1` texts, which describe keys only.
**Console readiness (Switch or PC).** Renderer is GL Compatibility already (`project.godot`: `renderer/rendering_method="gl_compatibility"`). `h` at x4 is exactly 1280x720 (handheld), x6 is 1080p (docked) with `window/stretch/mode="viewport"`, `scale_mode="integer"`. Two extra SubViewports at 160x180 are small; the budget risk is VRAM (above) and the full-screen redraws every 0.4 s of `Computer._canvas.queue_redraw()` (`computer.gd _process`: `_tick > 0.4`), times two. I cannot assess a Switch export path (section 8). Mobile: the project has `config/quit_on_go_back=false` and resume-point hooks from R16 but no touch layer; co-op on a phone is out of scope as you said.

## 5. Data model, migration, risks
### 5.1 `Players` autoload and `PlayerSlot`
```gdscript
# scripts/players.gd  (autoload "Players", registered after Controls)
extends Node
signal roster_changed
const MAX_SLOTS := 2
var enabled := false              # the co-op flag; false = single-player, byte for byte
var slots: Array = []             # [PlayerSlot]; slots[0] always exists
var active := 0                   # the slot whose state the delegating autoloads currently show (5.3)

func slot(i: int) -> RefCounted
func count() -> int
func node(i: int) -> Node         # the Player in the current scene (Actors/Player, Actors/Player2)
func nearest_to(x: float) -> Node # for NPCs
func slot_of(event: InputEvent) -> int
func ui_open(i: int) -> bool
func any_ui_open() -> bool        # what Game.ui_open returns for old callers
func to_dict() -> Dictionary
func from_dict(d: Dictionary) -> void

# scripts/player_slot.gd  (RefCounted, no node references; everything here is saveable and replicable)
var index := 0
var device := -1                  # -1 keyboard, 0.. joypad index
var character := "office_adult"
var look := {}                    # a Look dictionary (look + acc + active)
var held := ""
var sips := 0
var skills := {}                  # Skills.to_dict()
var shift := {}                   # energy, late_min
var growth := {}
var build := {}
var phone_os := ""
var darts := 0
var ui := ""                      # "", "computer", "phone", "card", "outfit" ... what this player has open
func to_dict() / from_dict()
```
`Player` gets `@export var slot := 0`; its `held`, `sips` and `character` read and write the slot. `Controls` gains `ensure_slot(i, device)`, `action(i, name)` and `slot_of(event)`. `Game.ui_open` becomes a computed property over `Players` when co-op is on (a setter keeps old writers working: they set slot 0's flag), and a plain bool when it is off.
### 5.2 Migration order (single-player stays default and green)
1. Add `Players` with `enabled = false` and `slots = [slot0]` mirroring today's globals (read-through to `Player.current_character`, `Look`, `Game.vars`). No behaviour change; run the full suite.
2. Replace the three zone `_player` fields by lists (this is a latent bug fix with one player too; guard with a test).
3. `Seat.use` sets `occupied` for players (single-player: the same, nothing else competes).
4. Add `Controls.ensure_slot` and `slot_of`; slot 0 unchanged.
5. `stage.gd` spawns slot 1 only when `Players.enabled`; helper `Players.node`.
6. Per-slot `ui_open`; `Game.ui_open` property.
7. Camera, group `Game.go`.
8. Takeover host and panes.
9. Per-slot state delegation (5.3), saves, campaign.
10. Outings, other modes.
Rule at every step: the suite with the flag off must pass with no edits to existing tests; any change that alters a single-player value is a bug.
### 5.3 Delegation without rewriting 200 call sites
Keep `Skills.xp`, `Shift.energy`, `Growth.focus` as they are, and let `Players.run_as(slot, callable)` swap the slot's dictionaries into the autoloads for the duration of one call (Dictionaries are references: `Skills.xp = slot.skills.xp`). Every entry point that acts for a player already has a pane or a `Player` node that knows its slot (`Computer._input`, `_finish_job`, `Phone._input`, `Player._physics_process`, `Cards.pick`), so the wrapper goes in a handful of places. Add an assertion test that `Players.active == 0` between frames.
### 5.4 Netcode friendliness (rules to follow from phase 1)
1. Per-player input goes through slot-scoped actions, then a per-frame `PlayerInput` struct (move, buttons) written by `Controls`/`Players`; `Player._physics_process` reads only that struct, never `Input` directly (today it reads `Input` in 14 places, `player.gd:466-522`).
2. Per-player state lives in `PlayerSlot` (`to_dict`), not in autoload fields or `Game.vars`.
3. No new global for per-player state; new fields go on the slot.
4. Simulation randomness through `Difficulty.rng` / `rng_for(stream, slot)` (already seeded, saved, resumable). Convert the ~113 raw `randf/randi` lines opportunistically (owner, outings, projects first); note `computer.gd:619`.
5. The shared sim (`Msp`, `World`, `Story`, `Events`) must stay free of node references (`World.chars` already is data; `World.populate` is the view).
6. Takeover UIs only call model methods (`Msp.rmm_action`, `Skills.pass_lesson`, `Campaign.*`), never touch another UI's fields.
7. `get_tree().paused` for pause is local only; an online mode would need a different pause.
### 5.5 Risks, ranked
| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| 1 | Code-drawn takeovers do not behave in a half `SubViewport` (mouse transforms, layout at 184x128, 160x180) | medium / very high | Phase 0b first; Plan B = one takeover at a time. |
| 2 | Pad-only navigation of the computer (mouse centric, `_hits` rectangles) | high / high | Stick cursor calling `click(at)`; audit list in 2.4; ship nothing to a pad player before it. |
| 3 | Per-slot state leaks through the autoload delegation (a timer fires with `Players.active` wrong) | medium / high | One wrapper at every entry, an invariant test each frame in the coop tests, and keep `Game.ui_open`-style compat properties. |
| 4 | Cards: 156 call sites and 26 tickers assume "a card pauses time" | medium / medium | Default scope `team` (same behaviour); reclassify gradually; `Cards.is_open` remains true for team cards only. |
| 5 | Balance: two players double throughput, the tech campaign trivialises | high / medium | `coop.pace` dial, two-bot run via `bot_lib.gd`; XP split rules. |
| 6 | `wide` 368x128 is too small for two panes and for readable cards | medium / medium | Make `h` the co-op format; keep wide as best effort; audit tool. |
| 7 | Seat, door and zone code paths multiplied (bathroom, front door cards `Onsite.offer_door`, lobby) have hidden single-player logic | medium / medium | Zone fix first (migration step 2); 2-player variants of `doors`, `bathrooms`, `seats`. |
| 8 | VRAM and memory on console (2.6 MB per clothes sheet, about 8 per look) | low-medium / medium | Crop sheets per piece (CLAUDE.md notes it as the fix); measure on target. |
| 9 | Scope creep into every mode | high / medium | The cut list in section 1. |

## 6. Test plan
**Simulating two pads headless.** Verified in the spike: `Input.parse_input_event(ev)` with an `InputEventJoypadButton` (or `InputEventJoypadMotion`) whose `device = 1` triggers only actions registered with `device = 1`. Add `tests/coop_lib.gd` (a `RefCounted` helper like `bot_lib.gd`): `pad(device, button, pressed)`, `stick(device, axis, value)`, `tap(device, button)`, and `enable(devices := [-1, 0])` that calls `Players.enable_coop(...)` with the test's save prefix. Short form for movement tests: `Input.action_press("p2_move_right")`. The runner (`tools/run_tests.py`) needs no change; every new file named `coop_*.gd` is picked up automatically.
| Phase | New tests |
|---|---|
| 0 | scratch only (spike). |
| 1 | `coop_input` (two devices, no cross-talk, hot-plug signal, join by A, keyboard split), `coop_zones` (two bodies in a door/seat/interact zone, one leaves, the other keeps the arrow), `coop_seats` (occupancy, second player refused), `coop_flag_off` (a checksum of key single-player outputs with the flag off: spawn x, nearest(), Controls table). |
| 2 | `coop_camera` (midpoint, clamp, edge case at room limits, warehouse), `coop_doors` (group transition, busy partner refusal, forced door, bathroom split), `coop_follow` (follow-me target slot, `World.player_left`). |
| 3 | `coop_takeover` (pane open/close per slot, world keeps ticking, `Game.ui_open` compatibility), `coop_cards` (scope player/team, first-confirm wins, sim frozen only by team), `coop_pane_layout` (layout audit at 160x180 and 184x128 for every Computer app and the phone), `coop_padclick` (cursor reaches every `_hits` entry on the desktop, PSA, RMM). |
| 4 | `coop_look` (two looks, overlays, the NPC copy of slot 1), `coop_items` (held/sips per slot, Game.vars compatibility), `coop_select` (second CharSelect), extend `playeras`/`outfit` variants. |
| 5 | `coop_campaign` (shared rep, per-slot XP and energy, claim and 25% share), `coop_save` (round trip, old save without `coop` loads single, co-op save loaded with the flag off), `coop_resume`, bot run with two bots (`bot_run.gd` flags). |
| 6 | `coop_bowling`, `coop_karaoke`, `coop_escape`, `coop_cornhole`, `coop_grill`, `coop_chair_race` on the `RefCounted` rules (turn order, scoring with two humans). |
| 7 | `coop_owner` (Alan + Garrison, no co-owner NPC), `coop_service`, `coop_sales`. |
Two-player variants of existing behaviours (new files, existing ones stay): doors, edges, seats, bathrooms, chair_roll, nerf, talk, follow, items, deskcup, phone, computer, outfit, playeras, pause, resume, charselect, campaign, plus the `*_shots` renderer tests for a screenshot of each pane layout.

## 7. Suggested first steps
1. Run phase 0 (a day): the scratch test above; report numbers and screenshots; decide Plan A or B.
2. Do migration steps 1 to 3 (zones, seats) as a standalone PR: they fix latent bugs and have no flag.
3. Decide the open questions in section 8 with the user, especially the default format and whether Career profiles matter.

## 8. What I could not determine
Status after the risk spikes (details, numbers and screenshots-as-text in `docs/coop-risk-findings.md`; spike code in `godot/tests/spike/spike_*.gd`):
- **RESOLVED: panes at 184x128 and 160x180 (and 180x160).** A second `Computer`, `Phone`, `Cards` and `DayReport` in a `SubViewport` renders and hit-tests correctly at all three sizes (135 screenshots read, layout audit run). Four layout fixes needed (desktop title over the second icon column, forum header, Boardroom BOOKS at 128 px high, PSA header); the day report stays a shared full-window screen. Phase 3a drops from XL to L.
- **RESOLVED: `SubViewport` mouse and `world_2d`.** Mouse is local to the pane (no transform work). A second world view with `sv.world_2d = root.world_2d` plus a `Camera2D` works (phase 3b feasible). A `SubViewportContainer` did not forward pad events while the autoload consumed them first: the host must route by slot with `sv.push_input`.
- **RESOLVED (this machine): frame cost.** Two bodies +0 ms; two static panes +0.4 ms; two extra world cameras +0.5 ms; two animated metrics panes +4.3 ms (the code-drawn animated board repaints every frame: cap it at 15 Hz). Console numbers still unknown.
- **PARTLY RESOLVED: card classification.** Counted 153 external `Cards.ask` sites in 25 files; about 130 stay team modal, about 20 (`growth`, `shift`, `talk`, `nerf`, event decisions) need per-player. The "26 tickers" are 26 `Cards.is_open` reads in 15 files; the freeze itself is one getter, `World.time_scale` (`world.gd:53`).
- **RESOLVED (headless): pad device behaviour and pad-only play.** Pad 2 separates; `ui_accept`/`ui_cancel` pad events are device 0 so pad 2 cannot confirm or go back until `Controls.confirm/back` become slot-aware; `ui_up/down/left/right` are device -1, so any pad navigates every open takeover (needs a slot guard). A 45-line stick cursor opened 8/8 desktop apps from pad 2 alone. Still not tested: real hardware, Steam Input, a pad that Windows lists as index 1 (no pad was connected on this machine).
- **RESOLVED: two bodies in a room.** No crash; five bugs listed in the findings doc (zone `_player` nulling, seats, spawn before `add_child`, auto exits, `ui_open` global) plus the bodies collide with each other (layer 1 / mask 1).
- **RESOLVED: tether.** The midpoint camera plus clamp holds at `wide`, `h`, `v` and `vclose` for rooms of 368, 640 and 1480 px; `v` can stay enabled in co-op (cap 160 px), only `vclose` (70 px) is cramped.
- **Still open:** which scene is 780 px wide and exact per-room fit in `h`; a Switch or any console export path and real console frame budget; custom-look overlays VRAM for two players (taken from CLAUDE.md, not measured); hidden single-player logic in `onsite.gd`, `conference.gd` trip flow, `playbook.gd`, `review.gd`, `lync.gd`, `service.gd`; balance numbers (`coop.pace` 1.5, the 25% assist share, mastery mean); whether the user wants Career medals for player 2, host/guest asymmetry, or drop-in drop-out.

## 9. Phase 1 status (Foundations behind a flag)
Built in the worktree branch `wt/agent-a322ca88b323791bb`; single player is the default and every existing test is unchanged.
- **Flag:** `Players.coop` (autoload `Players`, registered right after `Controls`), false by default. Turn it on with the launch arg `-- --coop` or `Players.enable_coop(true)`. No UI yet. With it off nothing registers a `p2_` action, no `Player2` exists and `Players.join` refuses.
- **Players API:** `slot(i)` (`Slot`: `device`, `joined`, `character`, `look`, `held`), `count()`, `node(i, scene)` / `nodes()` / `nearest_to(x)`, `player0(scene)` (the safe replacement for `get_node_or_null("Actors/Player")`, used at the 12 non-test call sites in fx, nerf, onsite, outings, pause_menu, resume, talk, toolbox, world, npc), `enable_coop(on)`, `can_join()`, `join(slot, device)`, `leave(slot)`, `slot_of(event)`, signal `roster_changed`. Slot 0 is a read-through to `Player.current_character`, `Look.look`, `Game.vars.held`; slot 1 owns its character (default Dan, the intern when slot 0 is Dan) and held item.
- **Controls:** `prefix(slot)` / `action_for(slot, name)`, `ensure_slot(slot, device)` (p2_ copy of `ACTIONS` bound to one pad, plus `p2_ui_accept` / `p2_ui_cancel` = that pad's A / B), `slot_of(event)`, `confirm_for(event, slot, ...)` and `back_for(event, slot, ...)`. The old `confirm` / `back` are untouched (a second positional `slot` would collide with `with_e`); each takeover moves to `*_for` in phase 3. No keyboard mapping for slot 1: tests press `p2_*` actions directly (`Input.action_press("p2_move_right")`). The `ui_up/down/left/right` leak (any pad navigates every takeover) is NOT fixed yet (phase 3).
- **Two-body bugs fixed:** door, seat, interact and NPC talk zones keep a list of bodies (`_bodies`, `_inside`): the arrow stays for the player still inside. `Seat.use` and `Player.sit_now` set `occupied` only when `Players.coop` (NPC seating is unchanged for single player); standing up or leaving the tree frees it; a second player is refused with the arrow shake. Auto exits are body-list safe and `spawn_player2` sets the position BEFORE `add_child` (nothing fires at (0, 0)); the group transition itself is phase 2.
- **Second body:** `Stage.spawn_player2()` adds `Actors/Player2` (`Player.slot = 1`) 24 px beside player 1, clamped to the walls, on `Players.join(1, device)` and on every room change while joined. **Bodies pass through each other** (collision exceptions both ways): nobody can block the other in a doorway or push them into a wall; revisit if shoving is wanted. Pad join: A on any pad other than pad 0 while co-op is on, in a room, in Free Play (not a campaign), with nothing open and not busy.
- **Still single player:** `Game.ui_open` / `Game.busy` are one global freeze for BOTH bodies; the camera follows slot 0 only (player 2 can walk off screen); a door or auto exit takes only whoever used it (player 2 is freed on a room change and respawned beside player 1 at the arrival spawn); Skills, Shift, Growth, Campaign, Phone, Computer, Cards, Look and the character keys 1-6 are slot 0's (keyboard events are ignored by slot 1); `Nerf` and every NPC (follow, talk, look-at) only know player 1; slot 1 is always a stock character; no save/resume of the roster.
- **Tests (new):** `coop_slots` (flag off, slot mirroring, spawn, own held item, pass-through, own actions, roster across a room change, leave), `coop_zones` (two bodies per door, interact zone and seat, arrow stays, seat occupancy, spawn order), `coop_input` (two simulated pads, per-device cross-talk, confirm / back per slot, join by A, re-bind to another pad). Generator check 0 differ, `gdlint scripts tests` clean.

## 10. Phase 2 status (camera, tether, group doors; Nov 2026)
- **Shared camera:** in a scrolling view (`h`, `v`, `vclose`, or a long room such as the warehouse) `Stage._coop_frame` points the camera at the middle of the two bodies (`Players.coop_focus`). The `wide` format with a room that fits the screen does not scroll, so nothing changes there.
- **Tether:** `Players.tether_range(focus, view_w, room_l, room_r)` is the x range both bodies may stand in so both stay on screen (the view around the camera centre, kept inside the room as the camera limits do, less `TETHER_MARGIN` 10 px). `Stage._coop_frame` clamps both bodies to it every frame. A room that fits the view has no tether.
- **Edge markers:** not needed yet. The tether keeps the partner on screen, so there is nothing to point at; they come back if a takeover (phase 3) ever hides a body.
- **Group doors:** already true from phase 1 and now tested: `Game.go` changes the room, the roster persists and `Stage.spawn_player2` puts player 2 beside player 1 at the arrival spawn, so whoever uses the door takes both. Auto exits (the room edges) go through the same `Game.go`.
- **Not done:** NPC follow-me (`World.player_left`) still follows slot 0, a partner with an open takeover refusing the door (phase 3), and split trips for the bathrooms.
- **Tests (new):** `coop_camera` (the math, and two bodies 750 px apart pulled within one screen in the warehouse), `coop_doors` (both bodies cross two doors and stay side by side).
