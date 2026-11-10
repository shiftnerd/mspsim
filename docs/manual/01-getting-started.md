<sub>MSPSIM INSTRUCTION MANUAL &nbsp;|&nbsp; CHAPTER 1 &nbsp;|&nbsp; PAGE 2</sub>

# GETTING STARTED

*Switching it on, finding the menu and not losing your place.*

---

## SWITCHING IT ON

1. Make sure you have **Godot 4.7.2** (the standard build).
2. Import the game's pictures and sounds once: `Godot --headless --path godot --import`.
3. Run it: `Godot --path godot`, or open `godot/project.godot` in the editor and press **F5**.

The game starts at the title screen. If it does not, see [Chapter 8: Tips and Troubleshooting](08-tips-and-troubleshooting.md).

> **NOTE:** The first run on a fresh copy may sit on a progress bar while Godot reads every sprite. That is the import. It is
> not frozen. It is thinking, which is more than the office printer can say.

---

## THE TITLE SCREEN

![The title screen: the MSPSim logo over the main floor, with a blinking start prompt.](img/title.png)

Behind the logo, the office puts on little scenes for you: a lineup by the desks, two people on the phones, the coffee machine,
a meeting in the conference room. They rotate every few seconds. Nobody is paid to do this.

**To begin, press `Enter`, `Space` or `E`, or click.** The home menu opens.

![The home menu: Continue, New, Free Play, Settings and Quit.](img/title-home.png)

| HOME LINE | WHAT IT IS |
|---|---|
| **CONTINUE** | Only shown once you have a save. Lists your newest saves from every campaign, most recent first, and the list scrolls when there are more than six. |
| **NEW** | A fresh campaign: the four modes below. `Esc` goes back to the home menu. |
| **FREE PLAY** | A sandbox with no scoring. |
| **SETTINGS** | The pause menu's settings before you start a run: the key lists and remap, the screen shape, sound on/off and the day length. The last row, CAREER, opens your medals, records and unlocks across every run. |
| **QUIT** | Leaves the game. |

![The new-campaign menu with four lines: Tech Campaign, Owner Campaign, Service Manager, Sales.](img/title-menu.png)

| NEW LINE | WHAT IT IS |
|---|---|
| **TECH CAMPAIGN** | The main game: a service desk tech's working days. |
| **OWNER CAMPAIGN** | The same office from the owner's chair. |
| **SERVICE MANAGER** | Running the desk instead of working it. |
| **SALES** | The account manager's side of the building. |

There is a one-paragraph tour of each in [Chapter 3: Game Modes](03-game-modes.md).

### Using the menu

| ACTION | KEYBOARD | GAMEPAD | MOUSE |
|---|---|---|---|
| Move the highlight | `Up` / `Down` | D-pad or left stick | Hover |
| Choose | `Enter`, `Space` or `E` | `A` | Click |
| Go back | `Esc` | `B` | none |
| Change the picture shape | `F9` | none | none |
| Mute or restore the sound | `M` (the title shows `SOUND ON` / `OFF`) | none | none |

> **NOTE:** On the title menu the letter keys do not move the highlight, only the arrows do. This is so that `E` can mean "OK"
> without anybody having to think about it.

### The submenu and your slots

Choose a campaign and, if you already have saved games in it, a submenu appears:

| ROW | WHAT IT DOES |
|---|---|
| **SLOT 1 - DAY 7 ... - NAME** | One row for each save you have. It shows the day (or week), the time if there is one, and your character's name. Choose it to carry on. |
| **CONTINUE** / **DAY n FROM THE START** | Appears when a slot has both a mid-day resume point and a start-of-day save. CONTINUE puts you back exactly where you were. FROM THE START replays that day. |
| **START YEAR 2** | Appears once you have finished a campaign's first year. See [Chapter 3](03-game-modes.md#year-2). |
| **NEW CAMPAIGN** | Starts a fresh run in the first empty slot. |

If you have no saves, **NEW CAMPAIGN** is the only door, so the game just opens it for you.

---

## CHOOSING YOUR PERSON

A new run goes through a short "pick your character" screen. You walk through it with the arrows and `Enter`, and `Esc` takes you
back a step.

![The character select screen: a row of people, a Make Your Own card, and the level and seed chips at the top.](img/charselect.png)

| CONTROL | WHAT IT DOES |
|---|---|
| `Left` / `Right` | Look along the row of people. |
| `Enter` (`E`, `Space`) | Pick the highlighted person and go on. |
| `Up` / `Down` | Change the **LEVEL** (difficulty). See below. |
| `X` | Open the **SEED** page. See below. |
| `T` | Open the toolbox (Free Play only, [Chapter 8](08-tips-and-troubleshooting.md#the-free-play-toolbox)). |
| `F9` | Change the picture shape. |
| `Esc` | Back. |

Some modes let you play as a person who already works at the office; others let you **make your own** (that card has its own
chapter: [Chapter 7: Make Your Own](07-make-your-own.md)). Depending on the mode, the screens after this one may also ask which
phone you carry and how to spend a handful of skill points on your starting build.

> **NOTE (COMING SOON):** This screen is being simplified so that it opens straight into the creator. Everything on it
> stays, but the order may change.

---

## DIFFICULTY

There are three levels. A campaign asks **HOW HARD?** on a page of its own, after you pick your person (and your phone): `Up` /
`Down` choose EASY, NORMAL or HARD, the line underneath says what that level feels like in this campaign, and `Enter` goes on. The
**LEVEL** row of the next page (SET UP THE RUN) shows the choice and can still change it; Free Play has only that row. The game
remembers your choice for next time.

| LEVEL | THE IDEA |
|---|---|
| **EASY** | Friendly timing everywhere. Inside a campaign, Easy is also the **cozy** mode (see below). |
| **NORMAL** | How the game was meant to be played the first time. |
| **HARD** | Tighter windows and stricter timers. Always beatable, never polite about it. |

The level reaches into every little game too: how fast the bowling markers swing, how much time you get in the escape room,
how generous the karaoke notes are, and so on.

### Cozy mode (Easy, inside a campaign)

Easy is the "wander and chat" setting. In a campaign, it softens the things that nag:

- Ticket timers are more forgiving, and being tired does not make your fixes fail.
- Your standing with the office has a floor, so there is no downward spiral. A rough stretch gets a gentle word, not a
  dramatic one.
- In the campaigns that handle money, a one-time rescue is available if the books run dry.
- The energy meter drains more slowly.

The pause menu shows a small **COZY** tag when it is on.

> **TIP:** Cozy does not take any of the puzzle away. You can still do everything the other levels can. It just has more patience.

---

## THE SEED AND THE DAILY SEED

Every run has a **seed**, a six-character code (like `29C110`) that decides the dice: which tickets come, which codes the escape
room picks, how the printer misbehaves. **The same seed on the same level gives the same dice**, so you can share one with a friend
and compare notes.

On the character select screen, press `X` (or click the **SEED** chip) to open the seed page:

| ROW | WHAT IT DOES |
|---|---|
| **The six wheels** | One wheel for each character of the code. `Left` / `Right` pick a wheel, `Up` / `Down` turn it (0 to 9, then A to F). Click the top or bottom half of a wheel to turn it with the mouse. A keyboard can also type the digits, and `Ctrl+V` pastes a code or a word (a word is turned into a seed). |
| **RANDOM** | Roll a fresh code. |
| **OK** | Use the code on the wheels. |
| **TODAY** | Use today's seed (shown with the date, like `03 NOV`). It comes from the date on your computer's clock, so everyone who picks TODAY on the same day plays the same dice. |

`Tab` (or `RB` on a gamepad) steps from the wheels to the buttons, and so does `Right` past the last wheel. `Enter` (`A`) on the
wheels uses the code, on a button it presses it, and `Esc` (`B`) closes the page. The whole page works with a gamepad or the
mouse alone.

---

## SAVING YOUR GAME

Think of it as a memory card with room for three. (It is not, in fact, a memory card. Please keep your memory cards out of the keyboard.)

- **Each campaign has three slots.** Tech, Owner, Service and Sales keep their own separate sets of three.
- **The game saves by itself** at the end of every working day.
- **A mid-day resume point** is kept when you open the pause menu, switch to another window, or close the game. That is what the
  **CONTINUE** row restores.
- **Free Play is not saved.** The pause menu even tells you so when you try to quit.
- **Your look, your level and your sound setting** are remembered between runs, in a small settings file next to the saves.
- When all three slots are full and you start another campaign, the game asks **OVERWRITE WHICH SLOT?** The row you pick is the confirmation,
  and **CANCEL** keeps all three.

> **WARNING:** Overwriting a slot is final. There is no undo, and there is no one to ring about it.

---

## THE PAUSE MENU

Press **`Esc`** (or the **`Pause`** key, or **`Start`** on a gamepad) while you are walking around a room. Everything stops: the clock,
the coworkers, the ticket timers.

![The pause menu with Resume, Controls, Shape, Day Length and Quit to Title.](img/pause.png)

| ROW | WHAT IT DOES |
|---|---|
| **RESUME** | Back to work. |
| **CONTROLS** | A three-page list of the keys. `Left` / `Right` turn the pages, `Esc` closes it. |
| **SHAPE: ...** | The picture shape. Same as **F9**: `Left` / `Right` or `Enter` cycles it. |
| **DAY LENGTH: 10 MIN** | In a campaign only. Cycle the length of a working day (5, 10 or 15 minutes in the tech campaign), which starts at the **next morning**. |
| **TICKET PACE: NORMAL** | Tech campaign only. RELAXED, NORMAL or BUSY: how many tickets a day brings and how many may be open at once. It changes at once and is remembered for the next run. |
| **OUTFIT** | Free Play only, in place of DAY LENGTH. Opens the character creator over the room. |
| **QUIT TO TITLE** | Asks first: **NO, KEEP PLAYING** / **YES, QUIT**. In a campaign it says `YOUR LAST SAVE IS KEPT`. In Free Play it says `FREE PLAY IS NOT SAVED`. |

![The Controls page of the pause menu.](img/pause-controls.png)

> **NOTE:** `Esc` does not open the pause menu while a computer, your phone, a card, an outing or a report is on screen, because
> those use `Esc` to close themselves. The **`Pause`** key still works over most of them.

> **TIP:** DAY LENGTH is a mercy and a challenge in one: 5 minutes makes a brisk day, 15 gives you room to chat.

---

## WHERE TO NEXT

- Learn the keys: [Chapter 2: Controls](02-controls.md)
- Pick a job: [Chapter 3: Game Modes](03-game-modes.md)

<sub>[Contents](README.md) &nbsp;|&nbsp; Next: [Chapter 2: Controls](02-controls.md) &gt;&gt;</sub>
