# MSPSim

**The year is 2014. Windows XP is dying. Somebody's CryptoLocker'd the law firm. The coffee machine has opinions.**

MSPSim is a cartoon pixel-art office sim about working at a managed service provider (an "MSP"): the small company that keeps
other companies' computers alive. You close tickets, plug and unplug real network cables, answer a headset phone, survive a
24-hour email outage, and still have time for a nerf gun war by the copier.

Think *Papers, Please* meets *Overcooked*, set in a tiny, grimy, very funny office that is secretly a pressure cooker.
The jokes come from real MSP life. So do the stakes (a backup you forgot to check, a firewall that is wide open to the internet).

> **Pixel IT Partners**: one small office, two owners who disagree about the thermostat, one rack in a closet behind a warehouse,
> and a sales guy who promised the client "by Friday".

Built with [Godot 4.7](https://godotengine.org) (GL Compatibility), all art drawn as code and Aseprite pixels. It is private and
very much in progress.

---

## Pick a job

| Mode | What it is |
|---|---|
| **Tech campaign** | 20 working days on the service desk. Fix tickets over the RMM, learn PowerShell, keep coworkers and clients happy, survive the big jobs, and decide your future at the yearly review. |
| **Owner campaign** | 20 weeks running the company: pricing, hiring, tools, marketing, collections, a competitor poaching your clients, a valuation at the end. |
| **Service manager / Sales** | The same office from the manager's and the account manager's chair. |
| **Free Play / Film Mode** | A sandbox with no scoring, for wandering, filming and playing dress-up. |
| **Career** | Medals, records and unlocks that follow you across runs. |
| **Year 2** | Finish a campaign and a harder year opens up. |

Three save slots per campaign, a seeded run (share a seed, or take the daily one), and three difficulty tiers. Easy is the **cozy**
one: the queue waits for you, nothing punishes you, you wander and chat.

## A day at the office

- **The work is a real puzzle.** A ticket comes in from ConnectWhy PSA, you dig into LabRat RMM, and there is a proper fix, a
  quick workaround that comes back to haunt you, a heavy fix that costs the client, and a clever fix if your skills are high enough.
  Reboot a machine without asking about unsaved work and you will hear about it.
- **Go onsite.** Six client site types (dental, law, vet, architect, realty, a demolition yard of office trailers), each with
  an IT closet, a server, and a mishap waiting (the vet's dog pees on the front desk PC; the plotter eats a forty-foot roll).
- **The big jobs.** Ransomware day. A rack falls off the wall. The server migration. The 24x7 email outage that runs into the night.
- **Real cables.** The network closet has a rack you can actually plug and unplug. Pull a patch cable and that desk goes offline,
  its monitor shows a red X, and a coworker walks over to find out why.
- **People with opinions.** Alan, Garrison, Dan, Vic, Maya and Morgan have moods, agendas, lunch plans and a memory. Chat, ask
  for help, take their advice, or get hit by a foam dart and find out who your friends are.
- **Chat, and the forum.** Lynk 2013 for office IM. **LabRat Nerds** for the forum (18 boards, 70+ threads) and an IRC
  channel where you can call a friend for work help or just ask how everyone's day is going and build real friendships.
- **Leaving the building.** Walk to a trade conference in Florida (Rodent Nation 2014), visit client sites, and go bowling.

## After work

Team outings take over the whole room: **bowling**, **karaoke**, an **escape room**, **dinner** at a neighbourhood grill,
**cornhole** and a **cookout** (burgers *and* hot dogs) in the warehouse lot, and a **chair race** down the dock. The hit zones
move around, and the games get sharper the more you play them well, so replays stay interesting.

## Make it yours

A character creator with hair, skin, glasses, hats, beards, a real wardrobe (shirts, bottoms, shoes, watch) and presets.
Swap outfits any time in Free Play (`Y`).

## 2014, strictly

Everything in the game is period-correct to 2013-14: Windows XP end of support, Heartbleed, the Target breach, CryptoLocker,
Flappy-style fads, Floppy Bat. No AI, no Teams or Slack, no Windows 10. Real brands are **parodied** (the PSA is *ConnectWhy*,
the RMM is *LabRat*, the mail client is *Outlookish 2013*, the phones are *iFone 5* and *Nexxus 5*).

## Running it

You need [Godot 4.7.2](https://godotengine.org/download) (the standard build). From the repo root:

```
Godot --path godot
```

or open `godot/project.godot` in the editor and press F5. The first time, import the assets (`Godot --headless --path godot --import`).

Formats: the game runs at 368x128 (the original), **320x180** (16:9) and **180x320** (9:16 for video). Press **F9** to cycle.

### Controls

| Key | Action |
|---|---|
| `A` `D` / arrows | Walk (`Shift` runs, `Space` jumps) |
| `E` | Use / sit / talk / open a computer |
| `Tab` | Pick the next thing in reach |
| `P` | Phone |
| `Q` / `X` | Wave / dance |
| `F` | Sip your drink |
| `Z` | Fire the nerf blaster (hold to aim) |
| `S` | Duck |
| `C` | Ask a coworker to follow you |
| `Y` | Change your outfit (Free Play) |
| `Esc` | Pause |

## For the curious

- `docs/GAME_BIBLE.md`: the pitch, the cast, the 20-day story arc. Written for reviewers, no code needed.
- `godot/story/strings.txt`: every line of story text in one plain file. Edit it and the game changes.
- `docs/ROADMAP.md`: what is built and what is next.
- `CLAUDE.md`: the long technical notes (art pipeline, scene generation, systems).

### Tests

```
python tools/run_tests.py -j 4        # the full headless suite (~150 tests)
python -I tools/check_generator.py     # the generated scripts match the generator
cd godot && gdlint scripts tests       # lint
```

`godot/scripts` is generated by `tools/make_godot.py` but is also hand-edited in step with it, so **do not rerun the generator in
the real tree**. Use the check script above.

## Credits

Pixel art drawn in [Aseprite](https://www.aseprite.org), characters and rooms built by Lua scripts so every animation works on
every person. Made by Ben and a very patient robot.

*Any resemblance to a real MSP is entirely because every MSP is like this.*
