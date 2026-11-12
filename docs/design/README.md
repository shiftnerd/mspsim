# Design documents (index)

What a reader needs to know about MSPSim as a product, built against a checklist of what a game design document has to
answer. Written 2026-11-12.

| Document | Purpose | Read it if you are | Kind |
|---|---|---|---|
| [checklist.md](checklist.md) | The 60 questions a design document must answer, from Race'n'Chase, the Diablo pitch, the concept template, and modern handheld items | writing or reviewing any design doc | Reference, stable |
| [gap-audit.md](gap-audit.md) | Our docs and game checked against the checklist: what is covered, thin or missing, issues in the game, proposed rows, owner decisions, a fact sheet | the owner, the coordinator | **Dated snapshot** (commit `2d16945`); never updated, replaced by a new audit |
| [game-design-document.md](game-design-document.md) | The design document itself: modes, loops, rules, systems, with status lines per area (written by a parallel agent; may not exist until merged) | a designer, a new contributor | Living |
| [pitch.md](pitch.md) | One-page public pitch: three concept statements, facts table, store features, tags | the owner, anyone writing the README or store page | Living, public |
| [scope-risks-tests.md](scope-risks-tests.md) | Build status, milestones, cut list, risk register, test plan and playtest script, platform, rating, Steam and legal checklists, metrics policy | the owner, whoever plans a release | Living |
| [systems-reference.md](systems-reference.md) | Tables of everything (modes, cast, tickets, cards, outings, medals, rooms, controls, code size) read from the game's data | anyone who needs a number | **Generated: do not edit** |

## Regenerating the systems reference

```
"C:\Program Files\Godot\Godot.exe" --headless --path godot -s res://tests/make_systems_reference.gd
```

`python tools/check_systems_reference.py` lists which sections drifted (`--update` rewrites the file). Notes:
`docs/dev/notes-sysref.md`.

## Keeping them current

1. The systems reference is generated. Regenerate it after any content change and commit the result; never hand-edit it.
2. When a roadmap row changes state, update the matching status line in the game design document in the same change.
3. The gap audit is a dated snapshot. Do not edit it to follow the code; run a new audit instead and say so in its header.
4. `pitch.md` and `scope-risks-tests.md` carry numbers from the systems reference and the audit. Recheck them before the
   milestones M1, M4 and M5 in `scope-risks-tests.md`.
5. Mark every item DECIDED, PROPOSED or OPEN. Only the owner moves an item to DECIDED.
6. Do not copy the Steam Deck tables (`docs/steam-deck.md`) or the manual: link them.
