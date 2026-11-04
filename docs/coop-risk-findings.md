# Co-op risk spikes: findings (Nov 2026)

Throwaway prototypes for the top risks of `docs/scope-coop.md`, run on Godot 4.7.2 (GL Compatibility, RTX 3070, Windows 11) from the code at the scope-doc commit. **No file in `godot/scripts` or any existing test was changed.** All prototype code is in `godot/tests/spike/` (not scanned by `tools/run_tests.py`, which lists only `godot/tests/*.gd`; `--list | grep spike` = 0 hits). Screenshots were rendered to a scratch folder and are not committed; the commands below regenerate them.

## Spike files (all throwaway)
| File | Risk | Run |
|---|---|---|
| `godot/tests/spike/spike_lib.gd` | helpers: `make_pane` (SubViewportContainer + SubViewport), `pane_script` (runtime copy of a script with the minimum pane edits) | (library) |
| `godot/tests/spike/spike_panes.gd` | 1 | `SPIKE_OUT=<dir> Godot --fixed-fps 60 --path godot -s res://tests/spike/spike_panes.gd [-- --sizes=184x128,160x180,180x160]` (window needed) |
| `godot/tests/spike/spike_input.gd` | 2 | `Godot --fixed-fps 60 --path godot -s res://tests/spike/spike_input.gd` (window needed: it reads the painted hit rectangles) |
| `godot/tests/spike/spike_two_players.gd` | 3, 5 | `Godot --headless --path godot -s res://tests/spike/spike_two_players.gd` (and with env `SPIKE_AUTO=1` for the auto-exit case) |
| `godot/tests/spike/spike_tether.gd` | 5 | `Godot --headless --path godot -s res://tests/spike/spike_tether.gd` |
| `godot/tests/spike/spike_perf.gd` | 6 | `Godot --path godot -s res://tests/spike/spike_perf.gd -- --format=h` (window, vsync forced off) |

Note: the headless Godot processes of the two-player spike take a long time to exit after `quit()` (leak warnings at shutdown); use `timeout`.

## Verdict table
| # | Risk | Before | Verdict | One-line evidence |
|---|---|---|---|---|
| 1 | Code-drawn takeovers at half-window size | medium / very high | **retired (reduced to a layout polish list)** | 135 screenshots (3 sizes x 45 screens) of a second `Computer`, `Phone`, `Cards`, `DayReport` in a `SubViewport`: every app renders and is clickable; 4 screens need layout work. |
| 2 | Pad-only play and a second pad | high / high | **reduced** (confirmed gaps, proven fix) | device 1 separates cleanly; pad 2 cannot confirm or go back today; a 60-line stick cursor opened 8/8 desktop apps and a ticket. |
| 3 | Two player bodies | not rated alone | **confirmed, smaller than feared** | no crash, no null deref with two bodies; 5 concrete bugs found, all small. |
| 4 | Cards: 156 asks, 26 tickers | medium / medium | **reduced** | the freeze is one getter (`World.time_scale`); about 85% of ask sites can stay team modal. |
| 5 | Group door and shared camera tether | medium / medium | **tether retired, group door confirmed** | tether math holds at all four formats and three room widths; `Game.go` frees P2, as expected. |
| 6 | Performance / memory | low-medium / medium | **reduced, with one watch item** | two bodies +0 ms; static panes +0.4 ms; animated metrics panes +4.3 ms on a fast PC. |

## Risk 1: takeovers at half-window sizes
**Method.** `spike_panes.gd` loads `main_floor`, starts a tech campaign (day 9, tickets, Nerds karma) and builds a pane (`SubViewportContainer` > `SubViewport` of the size under test). It instantiates a SECOND `computer.gd`, `phone.gd`, `cards.gd` and `day_report.gd` (`Script.new()` from a runtime-patched copy of the source, so the real files stay untouched) and screenshots every screen from the SubViewport texture (3x nearest) while running `PixelFont.audit` (the project's layout audit; it uses the pane's own visible rect, so it works per pane unchanged). Sizes: 184x128 (half of `wide`), 160x180 (half of `h`), 180x160 (half of `v`). Screens per size (45): desktop; mail list and read; PSA board, ticket, close-ask; RMM tree, endpoint, session, backups, project; PowerShell Academy list and lesson; profile; Lynk; forum index and board; IRC chat and who; metrics; Boardroom x5 tabs; onsite `open_site` desktop and its four windows; phone picker plus iFone and Nexxus (home, mail, ticket, texts, settings); two cards (long and short); day report (tech and owner variants).

**The pane patch (this is the change list for phase 3, 9 edits):**
1. `computer.gd:772` and `phone.gd:311`: `var top := maxf(12.0, floorf(size.y * Game.UI_STRIP))` becomes an instance field (`strip`, 0 in a pane). `phone.gd` also has `ptop := maxf(12.0, floorf(size.y * 0.17))`. `Game.UI_STRIP` is a `const`, so it cannot be changed per instance: that is why it must become a field.
2. `Game.ui_open = ...` writes (`computer.gd:123,141`, `phone.gd:70,79`, `cards.gd:73,101`) and `Game.ui_shift = value` (`computer.gd:150`, `phone.gd:88`) go through a per-instance hook, not the global (shown by the first run: global `Game.ui_open` stayed false only because the patch replaced them).
3. `phone.gd:62` `open()` refuses while `Game.ui_open` is true: a pane must not check the global.
4. A device guard line in each `_input` (`event.device != pad_device`).

**Results.** The code-drawn UIs size themselves from `get_viewport().get_visible_rect()` and mouse positions are local to the SubViewport, so a second instance simply works: everything painted, laid out and hit-tested in all three panes. Layout audit (text outside the pane or overlapping): 184x128: 3 screens flagged (`board_books` 7 offscreen + 2 overlaps, `day_report_tech` 11, `day_report_owner` 8); 160x180: 0 flagged; 180x160: `metrics` 1 overlap, both day reports 2 offscreen (the footer button). The audit does not see two more problems that I found by reading the screenshots.

| Screen | 184x128 | 160x180 | 180x160 |
|---|---|---|---|
| Desktop | icons fit in two columns, but the centred title "PIXEL IT PARTNERS" runs through the second icon column (LYNK, NERDS) | same overlap, 8 icons in two columns | fine |
| Mail, PSA board and ticket, close-ask | good (PSA summary truncates with ".." as designed) | good; PSA header "SLA MISSE.." cut | good |
| RMM tree, endpoint, session (12 buttons), backups, project | good, fully readable | good | good |
| PowerShell Academy, profile, Lynk | good | good | good |
| Forum, IRC | good | **tab row collides**: "IRC CHAT" button overlaps the "KARMA 24 REGULAR" label | good (just fits) |
| Metrics (dash) | tiles cramped but readable; chart legend tiny | fine | 1 overlap |
| Boardroom BOOKS | **overflows the bottom (7 lines lost)** | fits | fits |
| Boardroom clients, projects, team, stack | good | good | good |
| Onsite `open_site` desktop and windows | works; title overlaps the icons slightly | works | works |
| Phone (both skins, 8 screens) | good: `_sc` falls to 1x, the phone fits with room to spare | good | good |
| Cards (long and short) | good, wrap works | good | good |
| Day report | **overflows** (tech 11 lines, owner 8 lines lost) | fine for tech, owner variant dense but readable | footer button lost |

3x5 `PixelFont` stays at scale 1 everywhere (nothing needs to shrink below it); the small panes are readable at the intended 4x window scale. Windows scale (x4 of 368x128 = 1472x512, panes 736x512) leaves the pane at 4x.

**Fix list (layout polish, all small):** (a) desktop: drop the centred title when the area is under about 200 px wide (or draw it above the icons); the same `per_col` logic already exists, it is a 3-line change; (b) Nerds header: hide the rank text (`KARMA 24`) under 200 px; (c) Boardroom BOOKS and the day report: allow scrolling or the existing `_row_h` compaction; the day report should be a shared FULL-window screen in co-op anyway (as the scope doc says) so only the Boardroom matters; (d) PSA header summary: shorten `SLA MISSED` at narrow widths; (e) draw the pad cursor, not the stale mouse cursor, in a pane (each pane showed a mouse arrow at its last mouse position).
**Size.** Phase 3a (overlay panes) drops from XL to **L**: the structural question is answered, the remaining work is the nine edits, the Takeover host, scope-aware cards and about five layout fixes. 3b (true second camera) is separate: see risk 6.

## Risk 2: a second gamepad and pad-only operation
**What the input map says** (`spike_input.gd`, printed device ids): `Controls.ensure()` registers every pad event with `device = 0` (`move_right` [0, 0], `jump` [0, 0], `interact` [0]); `ui_accept` and `ui_cancel` pad events added by `Controls` are device 0; Godot's own `ui_up/down/left/right` pad events are device **-1 (any pad)**. There is no `project.godot` input map (everything is code registered; the `[input]` section does not exist). No `get_connected_joypads` or `joy_connection_changed` anywhere in `scripts/`.

**Experiments (all pass, `failures=0`):**
- A device-1 D-pad press does not drive `move_right`; a device-0 press does. A `p2_` copy of the whole `ACTIONS` table bound with `device = 1` fires only for pad 2; both pads pressing X at once make `interact` and `p2_interact` true together. Left stick on pad 2 drives only `p2_move_right` (strength remapped by the 0.5 deadzone, 0.8 gives 0.6). `Input.get_joy_axis(1, axis)` reflects injected motion events, so tests can drive pad 2 headless with `Input.parse_input_event` (scope doc 0a confirmed).
- **Gap 1:** a device-1 A press is NOT `ui_accept` and device-1 B is not `ui_cancel` (those are device 0 only), so `Controls.confirm` / `back` ignore pad 2 today. Every takeover would be unusable by pad 2 for confirm and back.
- **Leak:** `ui_up/down/left/right` are device -1, so a D-pad press on either pad moves the selection of every open takeover. With the autoload `Computer` and a pane `Computer` both open, a device-1 DOWN moved the autoload Computer's `mail_sel` (it moved from 0 to 1). A guard on `event.device` in each takeover fixed it (a pad-1 event pushed to the pane viewport moved only the pane; a pad-0 event was ignored by the pane).
- **Routing:** a `SubViewportContainer` did not deliver the root's pad event to the pane while the autoload consumed it first; the reliable design is that a `Players` host routes by slot (`sv.push_input(event)`), which worked.
- `Controls.pressed` stick-push state is keyed by `device * 32 + axis` and kept per device (pad 0 and pad 1 on the same axis both fired once; the held push did not re-fire).

**Where pad input is read (grep):** `Input.is_action_*`/`get_axis`: only `player.gd` (14 lines, 466-522; `_a`-style helper does not exist, they are literal action names); `Controls.pressed/nav/step/confirm/back/matches`: 80 calls in 14 files (`charselect.gd` 19, `outings.gd` 8, `toolbox.gd` 8, `phone.gd` 7, `computer.gd` 6, `player.gd` 6, `pause_menu.gd` 5, `cards.gd` 4, `printer_game.gd` 4, `title.gd` 4, `career_screen.gd` 3, `review.gd` 3, `day_report.gd` 2, `sfx.gd` 1); `InputEventJoypad*` objects: `controls.gd` (8) and `pause_menu.gd` (2, Start); `event.device`: only `controls.gd:223`. That is a short, closed list: a slot-aware `Controls` (`confirm(event, ..., slot)`, a `Players.slot_of(event)` guard at the top of each takeover `_input`) covers it.

**Pad-only operation of the computer (before the cursor).** Verified: on the desktop, D-pad and A do nothing (no focus model; `enter()` handles mail, PSA list, Crm and metrics only). Mouse-only interaction list (from the `_hits` ids painted per screen; hit rectangles per app at 160x180): desktop 10 (8 icons, wallpaper chip, START), mail 7, PSA 6, RMM 11 (tree rows, client expanders, tabs ENDPOINTS/BACKUPS/PROJECT, CONNECT, fix buttons), learn 4, profile 3, Lynk 9, Nerds 10 (forum tabs, board rows, IRC buttons), metrics 3, Boardroom tabs, the taskbar and START menu on every app, the red X, onsite `site:*` icons. Keyboard/pad paths that exist: mail list and PSA list (up/down/enter), Esc/B back, forum and IRC (`_nerds_pad`), Dispatch and Knowledge.

**Prototype virtual cursor (`VCursor` in `spike_input.gd`, about 45 lines):** right stick (device 1 only) moves a pointer inside the pane, A (or R3) calls the computer's own `click(pos)`. Closed-loop test with injected pad-2 events only (no mouse, no keyboard): **8 of 8 desktop apps opened**, a PSA ticket row opened, no hit rectangle centre lay outside the pane in any of the nine apps tested. Design (not built): `Takeover` host owns a `PadCursor` per pane; stick speed 140 px/s (about 1.2 s across a 160 px pane); snap-to-nearest-hit with the left stick/D-pad (jump between `_hits` centres by direction: removes most precision needs on a 3x5 font UI); A = click, B = back (`escape()`), triggers = scroll (`scroll_list`), Start = close pane; draw the cursor in place of the stale `_mouse`. Typed input (replying to mail, notes) does not exist in the game, so no on-screen keyboard is needed (the name entry already has a grid).
**Verdict: reduced.** The pad-only blocker has a proven small fix; a snap-to-hit pass makes it comfortable. **Size:** phase 1 input slice S to M (devices, `ensure_slot`, slot guard, `confirm/back` by slot), cursor M (needs per-screen testing of tiny targets such as the 9x6 close X).

## Risk 3: two player bodies
**Method.** `spike_two_players.gd` loads `main_floor` (tech campaign), instantiates `player.tscn` at runtime as `Actors/Player2` with a runtime copy of `player.gd` whose `Input.*` action names are prefixed `p2_`, then drives both through `Input.action_press`.
**Findings (log lines):**
1. **No crash and no null deref** with two bodies in a room: the only SCRIPT ERRORs in the log came from the spike itself (reading freed nodes after a scene change). Walking, gravity, animation, chair roll and the HUD all run for both. P1 and P2 are on layer 1 / mask 1: the two bodies **collide with each other** (they can block a doorway); decide on purpose (probably a separate layer so they pass through each other).
2. **Spawn position must be set before `add_child`.** A body added at (0,0) overlaps the `ExitToKitchen` auto door (x=4, 12x200) and `Game.go` fired within 10 frames, freeing the new player. Fix: `stage.gd` sets `position` before adding. Run-to-run flaky, so worth a test.
3. **Door loses the arrow (confirmed bug):** with P1 and P2 in `DoorOffice1`'s zone, after P2 walked away `door._player = null` and `_arrow.visible = false` while P1 was still inside and `p1.nearest() == door` (the zone nulls on ANY `body_exited`). Same code in `seat.gd` and `interact.gd`. Fix: replace `_player` by an `Array` of bodies; arrow visible if any body is nearest. A latent single-player-safe bug fix.
4. **Seats do not know players:** both players `sit()` the same seat; `occupied` stays false (`P1 state=sitdown, P2 state=sitdown, occupied=false`). Fix: `Seat.use` sets `occupied`, `_stand_up` clears it (S).
5. **One global `Game.ui_open` freezes both bodies** (P1 and P2 both moved 0 px with the flag set, while two inputs were held). Expected; needs the per-slot flag.
6. **Auto exits fire for either body:** P2 alone touching `ExitToKitchen` changed the scene and P1 was freed (the group-door rule must make this a group transition).
7. NPC cache: the one NPC node in the room (`npc.gd _player`) cached P1 only; `sfx.gd` `get_first_node_in_group("player")` finds the first of two group members; `stage._player` is P1 only so the camera follows P1 only; `Game.go` frees P2 (see risk 5). The 14 `Actors/Player` path lookups listed in the scope doc are all single-body (grep re-verified: fx 224, nerf 118, npc 430/586, onsite 1873/1898, outings 942, pause_menu 36, resume 77, sfx 337, stage 28/36, talk 397, toolbox 195, world 889).
**Fix list:** zones (3 scripts) to body lists; `Seat` occupancy; `Players.node(slot)` / `nearest_to(x)` replacing the 14 lookups; per-slot `ui_open`; spawn-before-add; layer for the bodies; auto exit rule; camera (risk 5).
**Verdict: confirmed but contained.** No hidden crash class. **Size:** phase 1 body/zone slice M (as in the scope doc), no change.

## Risk 4: cards
**Counts (grep, `godot/scripts`).** `Cards.ask(`: 154 matches in 26 files, of which 1 is `cards.gd` itself, so **153 external call sites in 25 files** (+1 `ask_first`). The scope doc's "156 in 27 scripts" is within a couple of lines (different counting of multi-line calls). Biggest users: `service.gd` 22, `conference.gd` 20, `onsite.gd` 18, `sales_campaign.gd` 16, `service_arc.gd` 13, `growth.gd` 9, `outings.gd` 7, `owner.gd` 6, `retention.gd` 6.
**The "26 time-pausing tickers" is a miscount of the mechanism.** `grep Cards.is_open` = **26 references in 15 files** (verified), but they are not 26 tickers: they are guards such as "do not start another event while a card is open" (`events.gd:2413`, `shift.gd:354`, `meeting.gd:54`, `conference.gd:1050`, `projects.gd:281`, ...), UI hiding (`hud.gd:25`), pause (`pause_menu.gd:40`), nerf and talk. **The actual freeze is a single getter:** `World.time_scale` returns 0.0 whenever `Campaign.active and (Cards.is_open or Outings.is_open)` (`world.gd:53-57`), and `msp.gd` and every ticker multiply by it. So making a card non-blocking for the sim means changing one getter to ask `Cards.team_open` (scope `team`) instead; the 26 reads then keep their meaning ("a team card is open").
**Per-player vs team (design).** Add `scope` ("team" default) and `slot` to `Cards.ask(who, body, choices, on_pick, valid, scope := "team", slot := -1)`; a `player` card is shown in that slot's pane and does not set `Cards.is_open`/freeze; the pane host keeps one queue per slot. Classification by file (call sites):
- **Stay team modal (about 130 of 153, about 85%):** `service` 22, `conference` 20 and `onsite` 18 (single-traveller flows: team in phase 7; they also set `time_scale = 0` themselves), `sales_campaign` 16, `service_arc` 13, `retention` 6, `owner` 6, `projects` 4, `meeting` 4, `handover` 3, `yeartwo` 3, `mutators` 3, `story` 2, `events` 2, `sales_beats` 2, `knowledge` 2, `campaign`, `partner`, `deals`, `sales`, and `outings` 7 (outings are their own modal).
- **Need per-player (about 16 to 20):** `growth` 9 (personal Tier plan), `shift` 3 (pager/energy), `talk` 3 (one conversation per slot), `nerf` 1, and the personal choices inside `events` (event deck decisions addressed to "you").
So the work is: the getter, the scope parameter with a default that reproduces today's behaviour for all 153 sites, then reclassify about 20 sites. The first-confirm rule and the 600 ms guard (`cards.gd _opened`) carry over. **Verdict: reduced.** **Size:** the cards slice of phase 3 drops from M to S (getter + scope arg + 20 reclassifications) + a per-slot queue.

## Risk 5: group door and the shared camera tether
**Tether math (`spike_tether.gd`, `failures=0`, 60 assertions).** Rule: camera x = midpoint of the two players clamped to the room limits (room centred if it fits), smoothed at speed 7 (like `stage.gd`); each player clamped to the camera rect minus a 10 px margin. Scenario 1: P1 runs 12 s with P2 idle, then they run in opposite directions; scenario 2: both run to the far end, P2 starting 3 s late. For every format in `Game.FORMATS` (view widths 368, 320, 180, 90 for `vclose`) and rooms 368, 640, 1480: both players always inside the view, separation never above `view - 2*margin` (348, 300, 160, 70 px), the camera never leaves the room, and both cross the room (1480 px: 17.5 s at run speed 90, 9.1 s for 640, 6.3 s for 368), so nobody is stuck. At `h` 320 the cap of 300 px is plenty (a character is 18 px); at `v` 160 px (nine characters) is fine; `vclose` (70 px, about four characters) is cramped but works, so the "disable v and vclose" recommendation can relax to "v allowed, vclose off". At `wide` the main floor (368) never scrolls, so the tether never binds.
**Group door (`spike_two_players.gd`).** `Game.go(office_one, start)` with two bodies in the room: 2 player-group nodes before, **1 after**; P2 is freed (`change_scene_to_file`), the new scene has only its own `Actors/Player`. Auto exits fire for either body alone (risk 3 item 6). What must change: (a) `Game.go` records both players' state (`Players.slots`), (b) `stage._ready` spawns P2 at the spawn point plus 14 px, position set BEFORE `add_child` (item 2), (c) one fade (the existing `busy` lock already makes it one event: `go()` returns if busy), (d) `door.use(body)` and the auto exits check the partner's takeover rule, (e) `World.player_left` gets both slots, (f) followers: NPC `follow` stores a slot, (g) the camera `stage._player` becomes a `Players` pair and `_process` calls the tether, (h) bathrooms are the single-occupancy split trip (unchanged from the scope doc).
**Verdict: tether retired; group door confirmed as planned.** **Size:** phase 2 M to **S-M** (the clamp is about 15 lines and proven; the group `Game.go` and door rule are the work).

## Risk 6: performance and memory (`spike_perf.gd`, h format, window 1280x720, vsync off)
Wall time per frame in ms over 300 frames (the `Performance.TIME_PROCESS` monitor updates about once a second and gave outliers of 86 to 556 ms from one-off script work, so wall time is the number to trust; GPU time of the root viewport stayed 0.5 to 0.7 ms):
| Scenario | wall ms/frame | draw calls | video mem |
|---|---|---|---|
| S0 one player, main floor | 1.15 | 31 | 69.4 MB |
| S1 two player bodies | 1.15 | 33 | 69.4 MB |
| S2 + two static computer panes (PSA + RMM, 160x180) | 1.56 | 37 | 80.0 MB |
| S3 + both panes on the animated metrics board (redraw every frame) | 5.48 | 67 | 80.0 MB |
| S4 two extra world cameras 160x180 sharing `world_2d` (true split screen) | 1.69 | 71 | 80.0 MB |
| S5 S4 + two animated panes | 5.94 | 105 | 80.4 MB |
Reading: a second body costs nothing measurable; two static takeover panes cost about 0.4 ms and about 10 MB of VRAM (the SubViewport buffers, bigger than the 0.11 MB RGBA targets would suggest); two extra world cameras cost about 0.5 ms (so **3b the true second camera is affordable**); the one real cost is the **code-drawn animated app**: the metrics board repaints every frame (`dash_t`, `queue_redraw` per `_process`), about 2 ms of CPU per pane on this machine, which is the figure to multiply by a console CPU factor (a Switch-class CPU is several times slower). Fix: redraw animated boards at 15 Hz (bars and pulses do not need 60), keep the 0.4 s redraw for the rest. Not measured: custom-look clothes overlays (about 2.6 MB VRAM per sheet, about 8 per look, from CLAUDE.md; two custom players about 40 MB), a real console, GPU time per SubViewport (the driver reported only the root). Verdict: **reduced**; no size change, add "redraw rate of animated panes" to phase 8.

## Updated sizes
| Phase | Scope doc | After the spikes | Why |
|---|---|---|---|
| 0 Spike | S | **done** | this doc |
| 1 Foundations | L | L (unchanged, input slice made explicit) | Controls device fix, zone lists, seats, spawn order, body layer |
| 2 Camera, tether, group doors | M | **S-M** | tether proven at all formats |
| 3 Split-screen takeovers | XL | **L** (3a), +M for 3b | nine edits proven in a pane, cards = getter + scope; pad cursor M and layout polish S are inside |
| 4 | M | M | |
| 5 to 8 | L, L, L, M | unchanged | not touched by the spikes |
Total: about **7 to 8 L** instead of 8 to 10. First playable slice (0 to 4) about 3 L instead of 4 to 5.

## Recommended first real build step
Phase 1 step 1 as a standalone, flag-off PR: `Players` autoload (slot 0 mirrors today), the zone `_player` fields turned into body lists (the door arrow bug is real today with the existing cast if two bodies ever share a zone, and it is the cheapest proof), `Seat.use` sets `occupied`, and `Controls.confirm/back` made slot-aware with the `p2_` action table behind `Controls.ensure_slot`. All 220 existing tests stay unchanged. Ship the zone and seat fixes first (S), then the `Players.node(slot)` replacement of the 14 lookups, then spawn P2 (flag on, Free Play) in `stage._ready`.
