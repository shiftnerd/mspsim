<div align="center">

```
+--------------------------------------------------------------------+
|  PIXEL IT PARTNERS INTERACTIVE                         PRIVATE BETA|
|                                                                    |
|      __  __  ____  ____  ____  ___  __  __                        |
|     |  \/  |/ ___||  _ \/ ___||_ _||  \/  |                       |
|     | |\/| |\___ \| |_) \___ \ | | | |\/| |                       |
|     | |  | | ___) |  __/ ___) || | | |  | |                       |
|     |_|  |_||____/|_|   |____/|___||_|  |_|                       |
|                                                                    |
|            M  S  P     S  I  M  U  L  A  T  O  R                  |
|                                                                    |
|   "The year is 2014. The coffee machine has opinions."             |
|                                                                    |
|                       INSTRUCTION MANUAL                           |
|                                                                    |
|  +--------------------------------------------------------------+  |
|  | RATED E FOR EVERYONE                                         |  |
|  | Mild IT Jargon, Cartoon Nerf Violence,                       |  |
|  | Coffee Machine Opinions                                      |  |
|  +--------------------------------------------------------------+  |
|                                                                    |
|   1 PLAYER (ONE CHAIR)      SAVES: 3 SLOTS PER CAMPAIGN            |
|   DESIGNED FOR GODOT 4.7.2     PIXELS: DRAWN BY CODE, MOSTLY       |
+--------------------------------------------------------------------+
```

![The MSPSim title screen: the logo over the office, four coworkers lined up.](docs/manual/img/title.png)

</div>

Thank you for choosing **MSPSim**, the cartoon pixel-art office sim about working at a managed service provider (an "MSP": the
small company that keeps other companies' computers alive). You will close tickets, answer phones, fix things from a chair and
sometimes from a van, and still find time for a foam dart war by the copier.

Please read this manual before you play. Or do not. Nobody reads these. But the controls are on page 2, and
there is a coffee machine you will want to find.

> **NOTE:** MSPSim is **private and in progress**. It is not for sale, not shipped, and some screens in this manual may be a
> little newer (or older) than the game on your machine. Where a page and the game disagree, believe the game and tell us.

---

## CONTENTS

| | PAGE |
|---|---:|
| [GETTING STARTED](#getting-started) (what you need, how to switch it on) | 2 |
| [SAVING](#saving) (three slots, like a memory card) | 3 |
| [CONTROLS AT A GLANCE](#controls-at-a-glance) | 4 |
| [THE FULL MANUAL](#the-full-manual) (nine chapters, with pictures) | 5 |
| [FOR TINKERERS](#for-tinkerers) (tests, generators, here be scripts) | 6 |
| [CREDITS](#credits) | 7 |

---

## GETTING STARTED

### What you need

| ITEM | NOTES |
|---|---|
| **Godot 4.7.2** | The standard build (not .NET). Get it at [godotengine.org/download](https://godotengine.org/download). |
| A computer that can run a 2D game | The game renders in OpenGL Compatibility mode, so a toaster from this decade will do. |
| A keyboard | A gamepad works for walking and menus. A mouse helps in the computer and phone screens. |
| Coffee | Optional. The in-game machine is a prop with feelings, not a supply. |

> **NOTE:** Please do not insert a disc. There is no disc. Please do not blow on anything either.

### Switching it on

From the folder you downloaded, run:

```
Godot --path godot
```

Or open `godot/project.godot` in the Godot editor and press **F5**.

### The very first time (the import)

The first time you run a fresh copy, Godot has to look over every picture and sound before it can use them. Do it once, up front, and
the game will start in seconds from then on:

```
Godot --headless --path godot --import
```

> **TIP:** If you skip this and press F5 anyway, Godot will do the same thing in the editor with a progress bar. It is the same
> import, just with more waiting and a view.

### Formats and the F9 key

MSPSim was built to be filmed as well as played, so the picture comes in four shapes. Press **F9** at any time (title screen, menus
and rooms) to cycle through them.

| SHAPE | SIZE | WHAT IT IS FOR |
|---|---|---|
| `wide` | 368 x 128 | The original: the whole office in one long strip. |
| `h` | 320 x 180 | 16:9 widescreen. The comfortable default for most screens. |
| `v` | 180 x 320 | 9:16 portrait, for phones and for video that goes vertically. |
| `vclose` | 180 x 320 | The same portrait, zoomed in 2x on the action. |

> **NOTE:** The window opens at a multiple of the chosen size. If your screen looks tiny, you probably pressed nothing yet: press
> **F9** until it fits. The pause menu also has a **SHAPE** row that does the same thing.

---

## SAVING

MSPSim saves like a console from the memory-card era: you get **three slots for each campaign**, they are kept on your computer
(not in the cloud, not on a card), and nobody will ask you to remove the card before powering off.

| WHEN | WHAT HAPPENS |
|---|---|
| **End of each working day** | The game saves to your slot by itself. |
| **You pause or close the window mid-day** | A resume point is kept, so **CONTINUE** drops you back where you stood. |
| **Start a new campaign** | It takes the first empty slot. If all three are full the game asks which one to overwrite (and has a CANCEL button, like a polite person). |
| **Free Play** | Nothing is saved. It is a sandbox. Go wild. |

On the title screen, a campaign with saved games lists each slot with its day and your character's name. Choose a slot to
continue, or **NEW CAMPAIGN** to start another.

> **WARNING:** Do not unplug the network closet during business hours. (Saves are unaffected. Everyone's mood is not.)

The full details are in [Chapter 1: Getting Started](docs/manual/01-getting-started.md#saving-your-game).

---

## CONTROLS AT A GLANCE

| ACTION | KEYBOARD | GAMEPAD |
|---|---|---|
| Walk | `A` `D` or arrow keys | Left stick or D-pad |
| Run | Hold `Shift` | `B` (hold) |
| Jump | `Space`, `W` or Up | `A` |
| Duck | `S` or Down | Down on the D-pad or stick |
| Use / sit / talk / open | `E` | `X` |
| Pick the next target | `Tab` (`Shift`+`Tab` goes back) | see Chapter 2 |
| Phone | `P` | `Back` / `Select` |
| Wave / sip your drink | `Q` / `F` | `Y` / `LB` |
| Dance | `X` (the key, not the pad) | none |
| Ask a coworker to follow you | `C` next to them | none |
| Nerf blaster | Tap `Z` to fire, hold to aim | see Chapter 2 |
| Roll your chair | Seated: hold `Shift` + `A`/`D` | none |
| Mute the sound | `M` | none |
| Pause and the key list | `Esc` or `Pause` | `Start` |
| Change the picture shape | `F9` | none |
| Hide the clock and counters | `F10` | none |

> **TIP:** The pause menu has a **CONTROLS** page that lists these keys in-game. Press `Esc` and have a look.

All the controls, with what every one of them does and what changes while you are seated, are in
[Chapter 2: Controls](docs/manual/02-controls.md).

---

## THE FULL MANUAL

The complete instruction manual lives in [`docs/manual/`](docs/manual/README.md). It is spoiler-free: it explains how to
**get around** this lovely story, not how it ends.

| CHAPTER | WHAT IT COVERS |
|---|---|
| [1. Getting Started](docs/manual/01-getting-started.md) | Launching, the title screen, difficulty (including cozy Easy), seeds, save slots, the pause menu |
| [2. Controls](docs/manual/02-controls.md) | Every key and button, seated and standing |
| [3. Game Modes](docs/manual/03-game-modes.md) | Tech, Owner, Service, Sales, Free Play and Career |
| [4. The Office](docs/manual/04-the-office.md) | A guided tour and a map of the building |
| [5. Your Computer and Phone](docs/manual/05-your-computer-and-phone.md) | The apps, the HUD counters, how the screens work |
| [6. After Work](docs/manual/06-after-work.md) | Bowling, karaoke, the escape room and the rest |
| [7. Make Your Own](docs/manual/07-make-your-own.md) | The character creator and your wardrobe |
| [8. Tips and Troubleshooting](docs/manual/08-tips-and-troubleshooting.md) | Questions, answers and the Free Play toolbox |
| [9. Credits and Legal](docs/manual/09-credits-and-legal.md) | The limited warranty and customer support |

---

## FOR TINKERERS

This section is for people who want to look under the case. If you only want to play, you may stop reading here, and
you will not be missing anything. (Okay, you will be missing the warranty. It is in Chapter 9.)

### Where things live

| PATH | WHAT IS IN IT |
|---|---|
| `godot/` | The game itself (Godot 4.7 project, GL Compatibility). |
| `godot/story/strings.txt` | Every line of story text in one plain file. Edit it and the game changes. |
| `godot/scripts/` | The game scripts. |
| `godot/tests/` | The headless test suite and the screenshot scripts. |
| `tools/` | Lua scripts for Aseprite (all art is drawn by code and Aseprite pixels), the script generator and the test runner. |
| `docs/GAME_BIBLE.md` | The pitch, the cast and the design. Written for reviewers. Contains story: **spoilers**. |
| `docs/ROADMAP.md` | What is built and what is next. |
| `CLAUDE.md` | The long technical notes (art pipeline, scene generation, systems). |

### Tests

```
python tools/run_tests.py -j 4        # the full headless suite
python -I tools/check_generator.py     # the generated scripts match the generator
cd godot && gdlint scripts tests       # lint
```

> **WARNING:** `godot/scripts` is generated by `tools/make_godot.py` but is also hand-edited in step with it. **Do not rerun the
> generator in the real tree.** Use the check script above, which compares without overwriting.

### Taking your own screenshots

The manual's pictures were taken with ordinary Godot scripts: a `SceneTree` script that waits for a few frames and saves the
viewport. See any `godot/tests/*_shots.gd` for the pattern, and run it with the project's Godot, **without** `--headless`,
for example `Godot --path godot --fixed-fps 60 --script <your script>`.

---

## CREDITS

Pixel art drawn in [Aseprite](https://www.aseprite.org); characters and rooms built by Lua scripts so every animation works on every
person. Built with [Godot](https://godotengine.org). Made by Ben and a very patient robot.

*All company, product and brand names in MSPSim are parody. Any resemblance to a real MSP is entirely because every MSP is like this.*

<div align="right"><sub>PAGE 1 OF 7 &nbsp;|&nbsp; PIXEL IT PARTNERS INTERACTIVE &nbsp;|&nbsp; PRINTED IN YOUR BROWSER</sub></div>
