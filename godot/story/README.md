# Reviewing and editing the story (no code needed)

There are three files for three kinds of reader:

| File | For | What it is |
|---|---|---|
| `docs/GAME_BIBLE.md` | Anyone | The pitch, tone, characters, the 20-day arc, the big jobs, the owner campaign. Start here. |
| `godot/story/STORY.md` | Reviewers | Every mail, text, job, card and line of dialogue in play order, each ending with its `[key]`. Read-only (generated). |
| `godot/story/strings.txt` | Editors | The same text as plain text. Change a line here and the game uses it. |

## Suggesting a change

Any of these works:
- **Comment** on the line in `STORY.md` (or a copy of it in a document): "Day 4 mail body `[Story.DAYS.4.0.body]`: too long, try ..."
- **Edit `strings.txt` directly** (in any text editor, on GitHub, anywhere) and send the file or a diff. You do not need to run anything.
- **Write a note** in `GAME_BIBLE.md` for ideas bigger than one line (a new day, a new job, a new character).

## How `strings.txt` works

```
# Day 4, 9:05, MAIL
[Story.DAYS.4.0.body]
Microsoft ends support for Windows XP and Office 2003 on April 8. After that there are no more security patches ...
```

- The text under a `[key]` is what the game shows. Keep the `[key]` line exactly as it is.
- A line that starts with `#` is a comment. Lines under a key are joined into one paragraph, so you can wrap long text however you like.
- Keep `%s` and `%d` markers: the game fills them in (a client's first name, a number). A change that adds or removes one is ignored and reported.
- If a string is missing from the file the game uses its built-in text, so you can keep a short file with only your edits.
- A key in braces is a **key token**: `PRESS {E} TO THROW` shows `E` on a keyboard and `(X)` with a gamepad, and follows a
  remapped key. Keep the braces. The forms are `{E}` (a key by its letter or name: `{ENTER}`, `{ESC}`, `{SPACE}`, `{SHIFT}`),
  `{ESC:pause}` (the word for the keyboard, then the game's name of the control for the gamepad) and
  `{PRESS A OR D|PUSH THE STICK}` (the keyboard's words, then the gamepad's). Other braces (`{me}`, `{c}`) are names the game fills in.

## Rules of the world

- It is **2013-14**. No AI, Teams, Slack, Windows 10/11, MFA (say "two-factor login"), TikTok, Discord. The checker below flags slips.
- Brand names are parodies: ConnectWhy PSA, LabRat RMM, Outlookish 2013, LabRat Nerds.
- Keep the voice: short, human, slightly panicked clients; dry, warm coworkers.

## For the person who builds the game

From the project folder (`godot/`):
```
Godot --headless --path godot -s res://tests/story_export.gd -- --check    # problems in strings.txt (unknown keys, changed markers, 2013-14 slips)
Godot --headless --path godot -s res://tests/story_export.gd -- --sync     # refresh strings.txt after the code changes (keeps edits, adds new strings)
Godot --headless --path godot -s res://tests/story_export.gd -- --doc      # regenerate STORY.md from the text as the game uses it now
```
The game reads `strings.txt` when it starts (autoload `Strings`) and prints any problems as warnings.

**Not in the text file yet** (still written inside the code): the outcome emails after the big jobs and their follow-up tickets, the day 9/11/14/20 callbacks,
the weekly all-hands speeches, the owner campaign cards that are built from the numbers, the growth-plan prompts and the pager. Say if one of these needs review and it can be moved.
