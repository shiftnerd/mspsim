<sub>MSPSIM INSTRUCTION MANUAL &nbsp;|&nbsp; CHAPTER 8 &nbsp;|&nbsp; PAGE 30</sub>

# TIPS AND TROUBLESHOOTING

*If something looks wrong, it probably is. If it looks right, it may also be wrong. This is IT.*

---

## GENERAL TIPS

None of these give anything away. They are the sort of thing a coworker would tell you in the first week, if the coworker liked you.

| # | TIP |
|---|---|
| 1 | **Read the hint bar** at the bottom of the screen. It is on your side. |
| 2 | **Stand still next to a thing** and wait for its arrow. If two things have arrows, `Tab` chooses. |
| 3 | **There is almost never only one way to fix something.** The fast way and the lasting way are often different ways. |
| 4 | **Look at the backups** more often than seems reasonable. The RMM has a tab for it. |
| 5 | **Take the PowerShell lessons early.** Every level makes your fixes faster and less likely to fail. |
| 6 | **Be nice on Lynk.** `THANKS!` takes one click and is remembered. |
| 7 | **Think before you reboot** somebody's computer. People keep things open. |
| 8 | **Small joys count.** A dart that lands, a lap of the office in your chair, a good night out: they lift your mood, and the numbers know. |
| 9 | **Your phone works when the network does not.** Keep it close. |
| 10 | **Not sure?** Pause (`Esc`) and check the **CONTROLS** pages. The game will wait. |
| 11 | **The day length is yours to set.** Pause, then **DAY LENGTH**, for a briefer or more leisurely day starting next morning. |
| 12 | **If you are struggling,** try the **EASY** level (the cozy one). Nobody gives out medals for suffering. |

---

## FREQUENTLY ASKED QUESTIONS

### The door is locked.

| DOOR | WHY |
|---|---|
| A **bathroom** | Someone is in it. The game says `OCCUPIED`. Wait a moment. |
| The **warehouse doorway to the lot** | The overhead door is down. Roll it up with the door or its switch, then try again. The game says `THE DOOR IS SHUT. ROLL IT UP FIRST.` |
| Any door whose arrow is **grey and shakes** | It cannot be used right now. |
| A door that just **does nothing** | You are not close enough, or something else has the arrow. Walk up and press `Tab`. |

### Why is everybody yelling?

A phone may be ringing at a desk, a **nerf war** may have broken out (they last about forty-five seconds and are nobody's fault), or an
outing may be under way. If the noise is the problem, press **`M`** to mute.

### Where do I save?

You do not, mostly. The game saves **at the end of every working day** and keeps a **resume point** when you pause or close it. Free
Play is not saved. See [Chapter 1](01-getting-started.md#saving-your-game).

### Where are my saves, on disk?

In Godot's user-data folder for the game (`MSPSim`):

| SYSTEM | LOCATION |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\MSPSim` |
| macOS | `~/Library/Application Support/Godot/app_userdata/MSPSim` |
| Linux | `~/.local/share/godot/app_userdata/MSPSim` |

> **WARNING:** Please do not delete files from this folder while the game is running. It does not enjoy it.

### My screen is tiny.

Press **`F9`** to cycle through the picture shapes (`wide`, `h`, `v`, `vclose`). The window opens at a multiple of the chosen
shape's size, so you may also just need to maximise it. The pause menu's **SHAPE** row does the same thing.

### My screen is the wrong shape (very tall, very thin).

That is `v` or `vclose`, the portrait shapes made for phones and vertical video. Press **`F9`** until you reach `wide` or `h`.

### The game feels too hard.

Choose **EASY** on the character select screen (`Up` / `Down` on the **LEVEL** chip). In a campaign, Easy is the **cozy** mode.
The pause menu's **DAY LENGTH** also stretches the working day. See [Chapter 1](01-getting-started.md#difficulty).

### The game feels too easy.

Choose **HARD**. If you have finished a Tech or Owner campaign, **START YEAR 2** is waiting on the title screen.

### The pause menu will not open.

`Esc` does not open it while a computer, a phone, a card, an outing or a report is up, because those use `Esc` to close
themselves. Close them first, or press the **`Pause`** key, which works over most of them.

### I pressed `E` and nothing happened.

Look for the arrow. If there is none, you are not close enough to anything. If there is one and it shook, it is locked or busy.
If something is already happening (a coworker is mid-sentence, a machine is pouring), wait a moment.

### I am stuck in a chair.

You are not. Press any move key and you will stand. (At a desk with a computer, `E` opens the computer; at other seats, `E` stands you up.)

### I pressed `F11` and ended up in a bowling alley.

The `F1` to `F12` keys (and some with `Ctrl`, `Alt` or `Shift`) jump straight to rooms in **development builds**, for the people
who build the game. Press `Esc`, quit to the title, and start again. A regular release does not do this.

### My controller does not do everything.

Correct. A gamepad covers walking, using, the phone, menus and most screens. See [Chapter 2](02-controls.md#gamepad) for what it does and does
not do yet.

### The first launch is slow, or something looks missing.

Run the import once: `Godot --headless --path godot --import`. See [Chapter 1](01-getting-started.md).

### The sound is too loud, or I want to film in peace.

`M` mutes. `F10` hides the HUD.

### Performance is poor.

MSPSim draws everything at a tiny internal resolution (as low as 180 x 320) and scales it up, so it does not ask much. If it stutters:

- Check that Godot is using your real graphics card rather than a software renderer.
- If you launched it from the editor, try running the game directly (`Godot --path godot`): the editor takes a share of the machine.
- Close the browser tab with 400 other tabs in it.

---

## THE FREE PLAY TOOLBOX

In **Free Play**, the toolbox lets you play any single game, with settings of your choice, and replay it exactly.

**To open it:** press **`T`** on the Free Play character select screen (**GO** then starts Free Play and launches the game once the
room is up), or press **`Shift`+`F10`** at any time in Free Play.

| KEY | WHAT IT DOES |
|---|---|
| `Up` / `Down` | Pick a row. |
| `Left` / `Right` | Change the row's value. (With the mouse: click the left half of a row to step back, the right half to step forward.) |
| `Enter` | **GO** (start the game), or open the **SEED** page. |
| `Esc` | Close the toolbox. |

| ROW | WHAT IT DOES |
|---|---|
| **GAME** | `NONE`, `BOWLING`, `KARAOKE`, `ESCAPE ROOM`, `DINNER`, `PRINTER`, `NERF WAR`, `CHAIR RACE`, `CORNHOLE`, `COOKOUT`. |
| *(settings for the chosen game)* | **KARAOKE:** which `SONG` (even one that is locked). **ESCAPE ROOM:** the number of `CODE DIGITS`, and which kind of clue each zone shows. **DINNER:** who is at the `TABLE`. **PRINTER:** which printer `MODEL`. |
| **SEED** | Type or paste a seed, roll one, or use today's ([Chapter 1](01-getting-started.md#the-seed-and-the-daily-seed)). |
| **FIXED TAKE** | `ON` makes every launch start again from the seed, with no random events and no twists, so a retake is **identical**. Handy for filming the same scene twice. |
| **MUTATOR** | A twist to run the world under (hidden while FIXED TAKE is on). |
| **GO / START FREE PLAY / CLOSE** | The big button at the bottom. |

> **TIP:** Fixed Take plus a seed is how you film a perfect scene, then do it again to see if the second take was better.

---

## STILL STUCK?

Open an issue. See [Chapter 9: Credits and Legal](09-credits-and-legal.md#customer-support).

<sub>&lt;&lt; Previous: [Chapter 7](07-make-your-own.md) &nbsp;|&nbsp; [Contents](README.md) &nbsp;|&nbsp; Next: [Chapter 9: Credits and Legal](09-credits-and-legal.md) &gt;&gt;</sub>
