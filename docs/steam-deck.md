# Steam Deck readiness (roadmap R42)

State of the game against Valve's Deck Verified checks, what the tests prove, and what only a real Deck or a
Steamworks account can confirm. Written Nov 2026 on a Windows desktop: **no Deck, no pad and no Steamworks account
were available**, so every "met" below means "met in a headless or windowed test on this PC" and says which test.

Build notes for this work: `docs/dev/notes-deck.md`.

## 1. The short version

| Area | State |
|---|---|
| Pad-only play | **Met in tests.** Title, character select, a tech campaign day, the Computer, the phone, the pause menu, save / continue and all 11 mini-games are walked with pad events only (`tests/pad_only.gd`, `tests/pad_only_games.gd`, `tests/pad_reach.gd`). |
| 1280 x 800 | **Met in tests.** New `deck` format, 320 x 200 logical at x4 = 1280 x 800, no bars. The layout audit passes in it with no off-screen text (`tests/layout_audit.gd`). Picked by itself on a 16:10 screen (`tests/deck_display.gd`). |
| Text size | **Met by arithmetic.** The pixel font is 5 logical px high, 20 physical px at x4 (Valve's floor is 9 px, 12 px recommended). |
| Glyphs | **Met in tests, for the screens the scanner opens.** With a pad in use no prompt names a key or the mouse: `tests/pad_prompts.gd` walks about 220 screens in each of the four formats and fails on any that does (114 such lines before the fix, 0 now). Hint lines, footers and the key list draw button sprites; sentences, captions and card labels print `(A)` `(X)` `(BACK)` `RS UP` as text. The switch is live both ways. Xbox names and shapes, not the Deck's own glyph set. |
| Text input | **Met.** No screen needs typing: the name is a letter grid, the seed is six wheels. |
| Suspend / focus | **Met in tests.** Pauses on focus loss and on a frame gap of 3 s or more (a suspend), no time passes (`tests/deck_display.gd`). |
| Linux build | **Preset ready, not built.** The export templates are not installed on this PC (section 6). |
| Frame time | **Measured on this PC only** (section 7): 5 to 7 times under the 16.6 ms budget in rooms and mini-games, 2.1 times on the worst screen (the Computer's metrics dashboard). A Deck is roughly half as fast per core: fine everywhere except that dashboard, which lands on the line. Not measured on a Deck. |
| Steam Input, Deck Verified review | **Needs hardware / Steamworks.** |

## 2. Deck Verified checklist, item by item

Valve's four categories (Input, Display, Seamlessness, System Support) as published for Deck compatibility review.

### Input

| Check | State | Proof / what is left |
|---|---|---|
| The default controller configuration gives access to all content | **Met in tests** | `pad_only`, `pad_only_games`, `pad_reach`. The game speaks to a standard XInput-style pad through Godot's `Input` (SDL game controller mapping), which is what the Deck presents by default. **Needs hardware:** that the Deck's default Steam Input template ("Gamepad") is what the game receives, see section 5. |
| On-screen glyphs match the Deck's buttons (or Xbox glyphs), never keyboard / mouse glyphs while a pad is used | **Met in tests** (not seen on hardware) | `tests/pad_prompts.gd` (default suite, headless, about 30 s): every screen of the layout audit plus the tutorial lines, a talk card, the pause menu and its key list and remap page, the printer game and every outing as a page and in its room, drawn with `Controls.pad_active` on, in `wide`, `h`, `deck` and `v`; any text that names a key or the mouse as a prompt fails, and so does text that leaves the screen. Sentences carry key tokens (`PRESS {E} TO THROW`, `Controls.keys`) that are resolved when drawn, so they follow a remapped button too. A pad button, a key or a mouse move switches an open screen at once (read from the window, so also behind the pause menu and under a card). Open: (a) the glyphs are the Xbox set (A B X Y, LB RB LT RT, BACK, START), which the Deck's face buttons match, but there is no Deck-specific art for View / Menu or the trackpads; (b) the direction words LEFT RIGHT UP DOWN stay words on a pad (the stick and the D-pad have them); (c) screens the scanner does not open (the nested views of the Computer's apps, client-site screens, the other printer models) were checked by a search of the script strings, not by drawing them. |
| Text input: the on-screen keyboard opens by itself, or the game has its own entry | **Met** | No text field is left. Name: `CharSelect.open_name_grid` (A on the NAME row). Seed: six hex wheels (`Toolbox`, `tests/controls_pad.gd`). The remap page's "put a keyboard key on an action" is the only screen that wants a keyboard, and a pad player never needs it. |
| No mouse-only control | **Met in tests** | `tests/pad_reach.gd` steps the cursor with RB over every click region of every Computer app (tech, owner, sales, service) and every phone screen on both skins: 68 screens, about 500 regions, none unreachable. The dispatch board's drag and drop has keys (Enter picks up / drops) and the pad's hotkey strip. |

### Display

| Check | State | Proof / what is left |
|---|---|---|
| Supports the Deck's native resolution (1280 x 800 or 1280 x 720) | **Met in tests** | `Game.FORMATS.deck` = 320 x 200, integer scale 4 = 1280 x 800 exactly (`Game.fit`, `tests/deck_display.gd`). `h` (320 x 180) x4 = 1280 x 720 with 40 px bars is still there. |
| Good default configuration, no settings to change before playing | **Met in tests** | At start `Game.start_display` picks `deck` on a 16:10 screen and goes full screen when the screen is 1280 x 800 or the `SteamDeck=1` environment variable is set (SteamOS sets it in game mode). **Needs hardware:** that gamescope reports 1280 x 800 to `DisplayServer.screen_get_size()` (it should; an external monitor in docked mode reports its own size, then the rule is 16:10 or not). |
| Text is legible at 12 inches; the smallest font is at least 9 px high at 1280 x 800 | **Met by arithmetic, readability needs eyes** | Every glyph of `PixelFont` is 5 logical px high and 3 wide, drawn at scale 1 or 2: 20 or 40 physical px at x4. `tests/deck_display.gd` asserts the 5 px floor. Nothing is drawn below scale 1. **Needs hardware:** whether a 3 x 5 pixel font at 20 px reads comfortably on the 7 inch panel in long texts (cards, mail). |
| No text off screen or cut | **Met in tests** | `tests/layout_audit.gd` with `deck` in its format list: 604 audited screens over four formats; 0 off-screen in `deck` (one line of the paintball intro, the night match draw, is 203 px wide and leaves the 180 px `v` format about one run in three: older than this work, not a Deck format). |

### Seamlessness

| Check | State | Proof / what is left |
|---|---|---|
| No compatibility warnings | **Met by construction** | The game shows no OS, driver or hardware warning of its own. |
| Launchers are navigable with the controller | **Met** | There is no launcher. The title menu is pad-driven (`tests/pad_only.gd`, `tests/title_menu.gd`). |
| Suspend / resume (not a formal check, but reviewed in practice) | **Met in tests** | Section 8. **Needs hardware:** a real power-button suspend. |

### System Support

| Check | State | Proof / what is left |
|---|---|---|
| Runs on SteamOS: natively, or through Proton with supported middleware | **Not verified** | A native Linux x86_64 build is the plan (`Linux (Steam Deck)` preset). Godot 4.7 with the Compatibility (OpenGL) renderer runs on the Deck's Mesa drivers. No middleware, no anti-cheat, no video codecs, no launcher. The Windows build under Proton is the fallback (`Windows Desktop` preset): Godot Windows builds generally run under Proton without tweaks. **Needs hardware.** |

## 3. What the Deck's screen gets

`project.godot` renders with `stretch/mode = viewport` and `scale_mode = integer`. On 1280 x 800 (`Game.fit`):

| Format | Logical | Scale | Picture | Bars | Screen used |
|---|---|---|---|---|---|
| `wide` (the old default) | 368 x 128 | x3 | 1104 x 384 | 88 px left / right, 208 px top / bottom | 41 % |
| `h` | 320 x 180 | x4 | 1280 x 720 | 40 px top / bottom | 90 % |
| **`deck`** (new) | 320 x 200 | x4 | 1280 x 800 | none | 100 % |
| `v` | 180 x 320 | x2 | 360 x 640 | 460 px left / right, 80 px top / bottom | 23 % |

`deck` is `h` with 20 more logical rows: the same camera rules (the room scrolls with you, `follow = true`), the
same column widths, and every screen lays itself out from the viewport size, so it came at no layout cost. It is in
`Game.ORDER`, so the pause menu's SHAPE row and F9 reach it.

Choice at start (`Game.start_display`, only outside test runs): a `--format=` argument or `PIXEL_FORMAT` wins; else
the shape saved in the settings file (`display/format`, written when the player uses SHAPE or F9); else `deck` on a
16:10 screen (ratio within 0.02 of 1.6: 1280 x 800, 1920 x 1200, 2560 x 1600) and `wide` on anything else.

## 4. Pad map (standard pad, Xbox names; the Deck's buttons match)

| Button | Walking around | Screens |
|---|---|---|
| Left stick / D-pad | walk, D-pad up jumps, down ducks | move the highlight |
| A | jump | OK |
| B | run (hold) | back |
| X | use, sit, doors | press the chosen hotkey (Computer) |
| Y | wave; with the blaster: offer a war | next hotkey (Computer), nudge / hint (escape room), preset (build), pray (printer) |
| LB / RB | sip (LB), previous / next target | page (creator), shake (printer), **step the cursor from button to button (Computer, phone)** |
| LT | roll the chair (hold, seated) | |
| RT | aim and fire the blaster | |
| Right stick | **up dance, down follow, left give, right mute** | **move the cursor (Computer)** |
| L3 / R3 | change your look / next person (Free Play) | |
| Back (View) | phone | close the phone; **leave the chair race, the cookout, paintball** |
| Start (Menu) | pause | resume |

Bold = added in R42. Known shared buttons that do not clash on one screen but are worth a second look on hardware:
Y waves and nudges in the escape room; LB sips and steps the target back (it only sips while a drink is in the hand).

Not on the pad by design: putting a keyboard key on an action (remap page), typing a word as the seed, the debug F-keys.

## 5. Steam Input expectations

- The game reads **standard game controllers** through Godot (`InputEventJoypadButton` / `InputEventJoypadMotion`,
  SDL mappings). It does not use the Steamworks Steam Input API and needs no action manifest.
- Expected Deck default: the **"Gamepad"** template (face buttons, sticks, D-pad, bumpers, triggers, View / Menu),
  which Steam applies to a title with full controller support. Under it the Deck looks like an Xbox pad as device 0.
  Trackpads and back grips (L4 / L5 / R4 / R5) are unbound and unneeded; the right trackpad as mouse would also work
  (every screen still takes mouse clicks), but nothing depends on it.
- In the Steamworks settings the title should declare **full controller support** and ship the Gamepad template as
  the recommended layout. That is a partner-site setting, not a file in this repository.
- Triggers are read as axes (`JOY_AXIS_TRIGGER_LEFT / RIGHT`, pressed past half way). The Deck's analog triggers
  report that way under the Gamepad template.
- Rumble: `Controls.rumble` calls `Input.start_joy_vibration` (co-op hits, strikes). The Deck's haptics accept it
  through Steam Input; strength is untested there. There is a `rumble_on` flag.
- Co-op: the second player needs a second pad (device 1). On a Deck that is an external pad; Steam Input orders
  controllers, and "the Deck's own controls are player 1" is the default.

**Needs a Deck or a Steamworks account:** that the default template really is Gamepad for this title, that View
maps to `JOY_BUTTON_BACK` and Menu to `JOY_BUTTON_START`, glyph review, rumble strength, co-op controller order,
and the Deck Verified review itself.

## 6. Linux build

`godot/export_presets.cfg`:

- **`Linux (Steam Deck)`**: Linux x86_64, release, the `.pck` next to the binary, `story/*` included (the editable
  text files), `tests/*` and `dev/*` left out. Output `build/linux/mspsim.x86_64` + `mspsim.pck`.
- **`Windows Desktop`**: the same filters, `build/windows/mspsim.exe`. The Proton fallback.

To export (after `mkdir build/linux`):

    Godot --headless --path godot --export-release "Linux (Steam Deck)" ../build/linux/mspsim.x86_64

**State on this PC: not exported, because the export templates are not installed.** The command itself runs and finds
the preset; Godot 4.7.2 answers:

    ERROR: Cannot export project with preset "Linux (Steam Deck)" due to configuration errors:
    No export template found at the expected path:
    %APPDATA%/Godot/export_templates/4.7.2.stable/linux_debug.x86_64
    %APPDATA%/Godot/export_templates/4.7.2.stable/linux_release.x86_64

Nothing was downloaded. Installing the 4.7.2 templates (Editor, Manage Export Templates) is the only step left
before a first build. The preset has no other configuration error (that message lists them all).

Running the Windows build under Proton instead: nothing in the game is Windows-specific (no native libraries, no
registry, no absolute paths; saves go to Godot's `user://`, which under Proton lands in the prefix's AppData and
under a native build in `~/.local/share/godot/app_userdata/MSPSim`). Saves do **not** move between the two by
themselves: pick native before release, or ship one and never the other, or turn on Steam Cloud with a root override.

## 7. Frame time

Measured with `godot/tests/frame_time.gd` (a measurement script, not in the default test run):

    Godot --path godot -s res://tests/frame_time.gd              # with the renderer
    Godot --headless --path godot -s res://tests/frame_time.gd   # scripts and draw callbacks only

**This PC:** AMD Ryzen 9 5950X, GeForce RTX 3070, Windows 11, Godot 4.7.2 Compatibility renderer, window 1280 x 800,
`deck` format (320 x 200 logical), vsync off, no frame cap, 4 s per scene. The machine was busy with other test runs
at the time, so the "worst" column carries noise. "60 Hz frame" = the 95th percentile frame plus one physics step.

| Scene | avg frame | p95 | worst | 60 Hz frame | headroom vs 16.6 ms |
|---|---|---|---|---|---|
| Title | 1.23 ms | 1.80 | 8.06 | 1.86 ms | x8.9 |
| Main floor, Free Play (2 of the cast in the room) | 1.33 | 1.94 | 5.63 | 2.35 | x7.1 |
| Bowling alley, the whole party (9 people) | 1.53 | 2.25 | 3.55 | 2.70 | x6.1 |
| Paintball, a match | 2.09 | 3.00 | 5.21 | 3.36 | x4.9 |
| Chair race, racing | 1.99 | 2.90 | 10.41 | 3.40 | x4.9 |
| Tech day, main floor with the HUD | 1.43 | 1.99 | 4.98 | 2.46 | x6.7 |
| **Computer, metrics dashboard** | **6.06** | **7.79** | 11.19 | **8.02** | **x2.1** |
| Computer, service board | 2.08 | 2.79 | 16.05 | 3.01 | x5.5 |
| Computer, RMM | 2.67 | 3.65 | 6.67 | 4.29 | x3.9 |

Headless (no drawing, the engine's "slowest process step of each second"): title 1.0 ms, main floor 1.0 to 1.9,
bowling 1.5, paintball 2.0, chair race 1.7, dashboard 4.3, service board 6.8, RMM 6.0.

What the numbers say:

- **Rooms and mini-games: 5 to 7 times under budget here.** The office is never crowded: the cast is spread over
  the rooms (2 people on the main floor in the measurement), and the fullest room is an outing (9 at the bowling alley).
- **The Computer is the heavy screen, and the cost is text.** `PixelFont.draw` issues one `draw_rect` per lit pixel
  from GDScript, so a full repaint of an app is thousands of calls: 6 to 8 ms per repaint on this PC (the headless
  column, which is one repaint per second or so). The apps repaint every 0.4 s and on input, which is why their
  average is low and their slowest step is not. The **metrics dashboard** used to repaint every frame; it is capped
  at 30 repaints a second now (`Computer.DASH_REDRAW`), and it still costs 6 ms a frame on average because the
  renderer also has about 210 draw calls of rectangles to submit for it.

**After the text cache (R-perf, `docs/dev/notes-perf.md`):** `PixelFont.draw` now draws one cached texture per string and the
metrics board's digits use cached geometry, with identical pixels (`tests/text_cache.gd`). Same PC, average frame, three
interleaved runs: dashboard 6.4 -> 3.5 ms (60 Hz frame 8.5 -> 4.7 to 5.4 ms), service board 2.5 -> 1.9, RMM 2.9 -> 1.9, bowling
1.65 -> 1.4, paintball 2.2 -> 1.8, chair race 2.0 -> 1.8; title and floors unchanged. Text commands a frame on the dashboard
fell from 1824 `draw_rect` to 37 `draw_texture`. Not met: the dashboard under 3 ms (what remains is about 210 GL draw calls resubmitted every frame).

**The Deck is slower. Not measured.** Its Zen 2 APU has roughly half the single-thread speed of this CPU and the game's
cost is almost all single-thread GDScript and canvas submission (the GPU load of a 320 x 200 picture is nothing). With
a factor of 2: rooms and mini-games land at 4 to 7 ms a frame (fine), the Computer's apps at 6 to 9 ms with a repaint
frame of 12 to 16 ms every 0.4 s (a dropped frame now and then while a screen of text is up), and the **dashboard at
about 16 ms, right on the line**: expect it to hold 30 to 60 fps rather than a steady 60. That is the one screen to
look at on hardware. If it stutters, the fix is in `PixelFont.draw`: merge each glyph row's run of pixels into one
rect and cache the rect list per glyph (about 40 % fewer draw commands and a much shorter script loop), or paint the
Computer into a cached texture. Neither is done (the font file is shared with the pad glyph work).

The co-op soak numbers (`docs/scope-coop.md`: two bodies +0 ms, two animated metrics panes +4.3 ms on this PC) point
the same way: the metrics board is the outlier.

## 8. Suspend and focus

`Game` (the first autoload) handles it:

- `NOTIFICATION_APPLICATION_FOCUS_OUT` or `NOTIFICATION_APPLICATION_PAUSED`: with a player in a room the **pause
  menu** opens (the tree is paused, and `PauseMenu.open` writes the mid-day resume point, so a battery that dies in
  suspend loses nothing). On the title or the character select the tree is simply held and released on return.
- `FOCUS_IN` / `RESUMED`: nothing happens on its own. The pause menu is still up; A or B resumes.
- **A suspend nobody announced**: SteamOS freezes the process, so the first frame afterwards would carry hours of
  `delta`. `Game.gap_check` runs on the tree's `process_frame` signal, which comes before any node's `_process`: a
  frame gap of `GAP_MS` (3000) or more of real time pauses at once, so the room never takes that step. Physics is
  already safe (Godot caps physics steps per frame).
- The switch: title, SETTINGS, **UNFOCUSED: PAUSE / RUN** (`Game.focus_pause`, saved as `display/focus_pause`).
- Test runs (`-s` scripts, `--write-movie`, headless) ignore focus changes unless a test sets `Game.focus_force`,
  so a test window that loses focus on the desktop never pauses.

`tests/deck_display.gd` sends the notifications and checks that the world clock stands still, that the Computer is
still open afterwards, that the switch turns it off, and that a faked four-hour gap pauses before the clock moves.

**Needs hardware:** the Deck's power button (whether gamescope sends a focus-out first, which decides which of the two
paths fires; both end in the same pause), audio after resume, and whether a long wall-clock pause upsets anything
that reads real time (`Cards` ignore input for 0.45 s of real time after they open: harmless).

## 9. Only a Deck or Steamworks can confirm

1. The whole game in the hand: stick feel in the chair race, the rhythm of karaoke on the D-pad, reading mail at 7 inches.
2. Steam Input's default template for the title, View / Menu mapping, glyph review.
3. A real suspend and resume, docked mode on an external monitor (16:9: the game would start in `wide`; `h` is the
   better pick there and is one SHAPE press away), battery draw.
4. Frame time on the Deck's APU.
5. The native Linux export, or the Windows build under Proton.
6. Deck Verified itself: Valve runs the review on a submitted build.

## Windows handhelds (ROG Ally, Ally X and similar)

Generally the same as the Deck, and simpler in one way:

- **Build**: the ordinary Windows build runs natively. No Linux export, no Proton.
- **Input**: the built-in controls are a standard XInput pad, which is what `Controls` already speaks. Everything in the pad-only tests (`tests/pad_only.gd`, `pad_only_games.gd`, `pad_reach.gd`) applies unchanged. Microsoft's guaranteed inputs (A / B / X / Y, both bumpers, triggers and sticks, D-pad, Menu, View) are all the game uses.
- **Screen**: 1920x1080, 16:9, 7 inch. The game starts full screen (below), and full screen on a 16:9 screen starts in the `h` format (320x180), which fills 1080p exactly at x6 and 720p at x4. No bars.
- **Suspend and focus**: the same pause on focus loss, app pause and the 3 s frame-gap rule cover sleep and the overlay.
- **Performance**: the frame-time table above applies; nothing was measured on an Ally.

Nothing here was run on an Ally.

## Full screen by default (all machines)

The game starts full screen (owner decision, 2026-11-10). SETTINGS on the title has **DISPLAY: FULL SCREEN / WINDOW**; the choice is saved in the settings file (`display/fullscreen`), next to SHAPE and UNFOCUSED. Code: `Game.fullscreen`, `Game.set_fullscreen`, `Game.pick_format(screen, full)`; test `tests/deck_display.gd`.

What a screen starts in when no SHAPE was saved: 16:10 gets `deck`; 16:9 in full screen gets `h`; anything else (ultrawide, 4:3) and a 16:9 window get `wide`. A saved SHAPE always wins. Test runs, `-s` scripts, `--resolution`, `--write-movie` and `MSPSIM_TEST=1` keep their window and `wide`.

## The two published checklists, against the game (read 2026-11-10)

Sources: Valve, "Steam Hardware Compatibility Review" (partner.steamgames.com/doc/steamhardware/compat); Microsoft, handheld development guidance (the five guidelines and the considerations page on learn.microsoft.com). Microsoft's badge criteria, fps targets and test cases are in separate guides (aka.ms/hhcompatguide, aka.ms/hhperfguide) that were not read.

| Requirement | Source | State |
|---|---|---|
| The default controller configuration reaches all content, with no setting to turn on | Valve, Microsoft | Met by test: `pad_only`, `pad_only_games`, `pad_reach` (68 Computer and phone screens). Not tried on hardware |
| Glyphs match the active input; no keyboard or mouse glyphs while a pad is in use | Valve, Microsoft | **Met by test** (`tests/pad_prompts.gd`, about 220 screens x 4 formats, 0 keyboard or mouse prompts with a pad active; live switch both ways). Not seen on hardware. Xbox-style glyphs, no Deck-specific View / Menu art; see the row in section 2 for what the scanner does not open |
| Text entry works with a controller alone (own entry or the system keyboard) | Valve, Microsoft | Met: the seed is six wheels; no other typed input is required |
| Smallest text at least 9 px tall at 1280x800 (12 recommended) | Valve | Met: glyphs are 5 logical px, 20 px at x4 in `deck` |
| Text at least 9 px at 1280x720 and 14 px at 1080p (12 and 18 recommended); bitmap fonts need a larger option | Microsoft | Met: 20 px at 720p and 30 px at 1080p in `h`. No separate text-size option exists |
| Runs at 1280x800 (preferred) or 1280x720 | Valve | Met: `deck` fills 1280x800 |
| A playable framerate by default: 30 fps at 800p | Valve | Expected with a wide margin (section 7), not measured on a Deck |
| No warnings about unsupported hardware or software; no launcher | Valve | Met: there are none |
| Avoid substantial letterboxing; 16:9 or 16:10 | Microsoft | Met in full screen (`h` and `deck` fill). `wide` and the portrait formats letterbox by design when chosen |
| Good defaults on a handheld without settings changes | Microsoft | Met by full screen plus the aspect pick. The Windows handheld flag (`RtlGetDeviceFamilyInfoEnum`, form `DEVICEFAMILYDEVICEFORM_GAMING_HANDHELD`) is not read: it needs a native extension and the defaults no longer depend on it |
| Runs natively on Linux or through Proton | Valve | Not verified: export templates are not installed (section 6) |
| Power: stop world rendering in menus, pause when idle | Microsoft (recommendation) | Partly: the game pauses on focus loss and suspend; rendering continues under menus |

Valve reviews a native Linux build first and falls back to the Windows build under Proton, publishing the better result. A review is requested from Steamworks (Technical Tools, "Steam Hardware Compatibility Review") after the standard build review. A game Verified on Deck is also Verified on Steam Machine.

## Export status (2026-11-11)

The Godot 4.7.2 export templates are installed (`%APPDATA%\Godot\export_templates\4.7.2.stable`, from the official
`Godot_v4.7.2-stable_export_templates.tpz`). From the repo root:

    Godot.exe --headless --path godot --export-release "Linux (Steam Deck)" <dir>/mspsim.x86_64
    Godot.exe --headless --path godot --export-release "Windows Desktop" <dir>/mspsim.exe

Both build. Output of the presets is `build/` (ignored by git); write elsewhere when testing. The Windows build starts and
runs 300 headless frames with no errors. The Linux build has NOT been run: it needs a Linux machine or a Deck. CI runs
the test suite on Linux (green on 2026-11-11) but does not build or run the exported game. Valve tries a native Linux build
first and falls back to the Windows build under Proton.
