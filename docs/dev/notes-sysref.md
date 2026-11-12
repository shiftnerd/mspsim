# Systems and content reference (slug `docs-sysref`)

`docs/design/systems-reference.md` is the "tables of everything" companion to the design document: 9 sections, 74 tables, written from
the game's own data by `godot/tests/make_systems_reference.gd` (a `SceneTree` script, the same pattern as `tests/story_export.gd`).
Nothing in the tables is typed by hand; only the one-line "what this is" notes are.

## Regenerate (one line, from the repository root)

```
"C:\Program Files\Godot\Godot.exe" --headless --path godot -s res://tests/make_systems_reference.gd
```

Add `-- --out C:/some/path.md` to write somewhere else. The same command is in the header of the document.

## Check for drift

- `python tools/check_systems_reference.py` regenerates to a temp file and prints each changed section (`ADDED`, `REMOVED`,
  `CHANGED` with the row counts and the first differing line). `--update` also rewrites the committed document. Exit 1 when different.
- `tests/systems_reference.gd` (default suite): HARD fails only if the generator errors, writes nothing, has fewer than 9 sections or 60 tables, or has an
  empty table. It WARNs (prints, never fails) when a heading or a table's row count differs from the committed document, and when an
  era word from `Strings.BANNED` appears in the generated text. The generator itself (`make_systems_reference.gd`) is in `run_tests.py` SKIP, because it
  rewrites the document.
- Code-size table 9.3 (lines per file) changes with every commit: that is expected, regenerate before committing the doc.

## How the generator reads data

`_k(source, key)`: for an autoload ("Msp") it reads the live variable or constant; for a plain script ("world_data", "temptation", "habits",
"seasons", "rival", "rival_cards", "owner_cast", "owner_ops", "sales_beats", "chair_race", ...) it loads `res://scripts/<snake_case>.gd` and reads the
constant map. Counts of cards use the `DEFAULT_*` constants (the live `Owner.CARDS` merges the owner, cast and rival cards, so it would double count).

## Not data driven (text scans and "see file")

| Item | How the reference handles it |
|---|---|
| Year 1 endings and what each needs (1.5) | text scan: for each of `Review.make_offers`, `Owner._base_offers`, `Service.review_offers`, `SalesCampaign.offers` the `"id": "x"` entries are listed with the enclosing `if` / `elif` / `else` lines quoted. Indentation based, not a parser. |
| Year 2 ending gates (1.6) | "see `Yeartwo._offer_ok`" (a function); Year 3 thresholds are data (`DEFAULT_YEAR3.needs`) |
| Owner-mode partner endings (buyout, sellout, left) | named in a note, see `Owner._ending_text` |
| Settings and pause menu rows (8.2) | text scan of `PauseMenu._labels()` (quoted labels; values inside `if` expressions are skipped) |
| What the settings file saves (8.3) | text scan of `set_value("section", "key", ...)` calls in the scripts that use `settings_path` |
| Relationship levels | a note with the thresholds read from `Social.mood()` (see `scripts/social.gd`) |
| Grill game | "see `scripts/grill_game.gd`" (only the customer notes are a table) |

## Spot checks (20 numbers verified by hand against the code)

1. Tech campaign `day_len` 600 s, owner 240, service 360: `Campaign.MODE_DEFS` in `campaign.gd`.
2. Year 3 SLA multiplier 0.76 and Year 2 0.85: `Yeartwo.DEFAULT_YEAR3.sla` / `DEFAULT_YEAR2.sla`.
3. `y3_partner` needs rep 60 and trust 50: `DEFAULT_YEAR3.needs` in `yeartwo.gd`.
4. SLA clocks 120 / 200 / 300 / 480 s: `Msp.SLA_SECS`.
5. Fix seconds 6 / 5 / 4 / 3 / 2 / 1.5 and fail 0.25 / 0.18 / 0.1 / 0.04 / 0 / 0: `Skills.FIX_SECS`, `FAIL`.
6. XP for levels 15 / 40 / 80 / 130 / 200: `Skills.XP_AT`.
7. `karaoke.gap` 0.95 / 0.75 / 0.55 and `escape.time` 150 / 120 / 105: `Difficulty.TABLE`.
8. `Difficulty.TABLE` has 68 keys: counted with awk over the table lines.
9. Build budget 15 / 12 / 9 points: `Build.BUDGET`.
10. Bowling costs 120: `Outings.GAMES`; dinner budgets 150 / 300 / 520: `Outings.BUDGETS`.
11. Partner meeting weeks 5, 9, 13, 17: `Partner.MEETING_WEEKS`.
12. Tech outing days 5, 10, 15 and lunch days 3, 7, 12, 17: `Outings.TECH_DAYS`, `LUNCH_TECH`.
13. 72 medals: awk count of `{"id"` in `Career.DEFAULT_MEDALS`; 41 unlocks likewise.
14. 11 clients: awk count of `"name"` in `Msp.CLIENTS`; 6 base problems in `DEFAULT_PROBLEMS`.
15. 12 shop items (`Shop.CATALOG`), 7 decor items (`OfficeDecor.ITEMS`), 14 mutators, 14 habits (`DEFAULT_HABITS`).
16. 41 random events: awk count of keys in `Events.DEFAULT_DECK`; 32 rival cards in `RivalCards.DEFAULT_CARDS`.
17. 53 owner cards: awk count of keys in `Owner.DEFAULT_CARDS` (the live `Owner.CARDS` is 91 because it merges 32 rival and 6 cast cards).
18. 65 scenes in `WorldData.SCENES` (grep of top-level keys); `godot/scenes` has 68 `.tscn` files (`ls`).
19. 38 staff character stills (`ls sprites/staff | grep -vc _anim`); 4 export presets (`grep -c ^name= export_presets.cfg`).
20. Deck screen format 320 x 200 at scale 4 = 1280 x 800: `Game.FORMATS` and its comment; remappable `interact` = E, pad X: `Controls.ACTIONS`.

## Decisions made

- The generator lives in `godot/tests/` (like `story_export.gd`), because scripts under `tools/` are outside the Godot project.
- Warn only on drift in the test; the hard failure covers only a broken generator.
- No new `.gd` under `godot/scripts`, so nothing to port into `tools/make_godot.py`.
- Counts of "decks" use the `DEFAULT_*` tables, so a deck changed at run time by a patch file is not reflected (the patchable text is in `story/strings.txt`).
