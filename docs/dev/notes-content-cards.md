# Content cards (slug `content-cards`)

More writing, tested. All wording is a first draft for the owner to edit (`godot/story/strings.txt`, synced). No sound, no art.

## 1. 1:1 decks (service campaign)

- `Service.ONE_ON_ONES.Maya` and `.John` now have **20 cards each** (10 new each, appended so no old `strings.txt` key moved). The Tech deck is unchanged (28).
  Voices: Maya is earnest, a little overwhelmed and funny by accident (the stapler, "you too" at nine in the morning); John is charming, evasive about
  numbers, always has a client story (the fruitcake, "Dale", a ballgame with peanuts). Effects stay in the old ranges (morale 2..6, retain 1..2, skill 0.01..0.03,
  stress -5..3; John: social -4..3, trust Alan / Garrison -2..2, an occasional mood or morale +-1..3).
  Shape kept: option 0 is the considered one (Maya: morale > 0 and retain >= 1), the last the curt one (morale < 0 / social < 0), labels <= 40 letters.
- **A promise that comes back.** 4 of Maya's 10 new cards and 4 of John's carry `"flag": "<id>"` in the first option's fx (`maya_visit`, `maya_notes`,
  `maya_panel`, `maya_desk`, `john_numbers`, `john_game`, `john_demo`, `john_labels`). New patchable table `Service.ONE_BACK` (`DEFAULT_ONE_BACK`, root added to
  `Strings.ROOTS.Service`): `{flag: {who, after, text, options}}`, the same shape as a deck card (`after` = 3 to 5 days).
  - `_answer_oto` stores `flags["flag_day_<id>"] = Campaign.day` when the option has a flag (the flag itself is set by `apply_fx`).
  - `begin_day` ends with `_oto_backs(day)`: for every flag set and not yet done, when `day >= flag_day + after` it sets `flags["back_done_<id>"]` and asks
    the callback card (answered by the same `_answer_oto`, so crew morale / retain go to Maya, social / trust to John). Once a run. Skipped silently if the person is gone.
  - Not part of a deck: no `oto_seen`, no `oto_log` entry. Flags are saved with the rest of `Service.flags`.
  - The callback's best option keeps the promise (Maya +5..6 morale, retain 1..2; John social +2, trust Alan +2), the curt one breaks it (Maya -5..-6, retain -1).
- Test `tests/oto_decks.gd` (extended, 47 s): decks have >= 20 / 28 cards; 4 + 4 callbacks with a card that sets each flag, 3 options, known fx;
  the promise sets its flag and day, nothing comes back after 2 days, the card comes after 3, once, and not after a save / load; no promise, no callback;
  a direct 20-day run with a 1:1 a day with Maya, John and one tech shows no repeat and **no filler** for any deck; the careful bot's 20-day run has no check-in at all.

## 2. Owner campaign: Christy and Morgan (`scripts/owner_cast.gd`)

Check result: the owner campaign already had Christy's cards (week 1 goal, the draw, bank change, credit memo...) and Jen and Michael (X11, three each). Morgan had none
(only texts). Added two cards each to `OwnerCast.CARDS` (merged into `Owner.CARDS` as before, patchable as `OwnerCast.CARDS`), placed in `OwnerCast.DAYS`:

| card | week | at | speaker | what it does |
|---|---|---|---|---|
| `christy_net45` | 10 | 15.2 | Christy (Controller) | receivables: 2% for ten days (cash +600 now, $40/wk), phone them (cash +400, mood -2), keep polite (cash -300) |
| `christy_card` | 11 | 12.4 | Christy | company card: one page policy ($30/wk saved), a word at the huddle (1 owner hour, $15/wk), leave it (cash -200) |
| `morgan_overtime` | 13 | 10.8 | Morgan (Manager) | evenings: hard stop at six (speed -0.03, burnout -5), time back (payroll +90, burnout -3), let it ride (speed +0.04, burnout +5) |
| `morgan_reviews` | 16 | 12.6 | Morgan | reviews: in person (2 owner hours, speed +0.02, mood +2), written with raises (payroll +80), skip (mood -2) |

Every option has real fx (cash, weekly, payroll, speed, burnout, mood_all, social_all, owner_hours) and the partner's trust. They sit on weeks that were already busy
(`events.gd` counts the quiet owner weeks: a week with more than 3 events is not quiet, and it needs >= 4 quiet weeks) and are clear of every other event by 0.15 h.
`tests/second_cast.gd` now expects 10 cards (3 Jen, 3 Michael, 2 Christy, 2 Morgan), all placed, and plays four of the new ones through the card flow with their numbers.

## 3. Sales campaign colour (`SalesCampaign.LIFE`)

Six "office life" cards (lost proposal, a client who calls at 4:55, a trade show lanyard, a rival's flyer, a messy CRM list, a receptionist who says he might be in).
Speaker "Office life", three options each, short replies. fx keys: `pipe` (the best open lead's quality +-1..4, clamped 5..95), `consc` (`Temptation.change_consc`,
+-1; the lies the director job reads), `morale` (`Social.change_all`, +-1..2). New `SalesCampaign.LIFE` / `DEFAULT_LIFE` (patchable, `Strings.ROOTS.SalesCampaign`),
`LIFE_WEEKS = [2, 5, 8, 11, 14, 17]`, `life_order()`, `_life_card(day)` (called from `begin_week` right after the beat cards, before the lead cards), `life_fx()`.
**Seeded, no repeat**: the order is `Difficulty.shuffle_with(range(6), rng_for("sales.life", 0))`, the count dealt is `flags.life_seen` (saved with the flags), so a load keeps it
and another run deals another order. Test `tests/sales_life.gd` (8 s); `sales_balance` and `sales_hard` still pass.

## 4. Tech-campaign vignettes (`Story.VIGNETTES`: 33 -> 41)

Eight drawn vignettes (`min_day` 6..14, `max_day` 20), 2013-14, three options each (first safe): `byod_phone` (a work email on a personal phone), `usb_found` (a drive found in the
parking lot), `remote_scam` ("Windows Support" calls the front desk), `vga_hdmi` (the projector and the new laptop), `dst_clock` (the server clock after the time change),
`streaming_lunch` (video all lunch hour on the brewery's router), `pst_archive` (a 4 GB mail archive on the desktop), `wifi_twin` (the coffee shop's wifi has the office's name).
Effects are the vignette deck's own: xp 2..4, a client's mood +-1..3, social with Alan, hours 0.2..0.7. They pass `Events.validate_all()`.
Drawn, not scheduled: `tests/vignettes.gd` (41 cards, 25 drawn) and `tests/events.gd` (25 drawn) were updated on purpose; the comment in `events.gd` says 25.

## Decisions made

- The callback cards are a small separate table (`ONE_BACK`) and not entries of the deck, so deck sizes, the shuffle and the no-repeat count of the old test stay exactly as they were.
- A promise is only the *first* option (the considered answer); the flag is not set by the curt one, so a curt answer never creates a debt.
- The sales cards use the weeks 2, 5, 8, ... (every third week) instead of a random roll: the draw is seeded and no run misses a card.
- `strings.txt`: `--sync` only added keys (1364 lines, no line removed), so no existing edit could be lost and the stale section did not have to be deleted by hand.
- `John` cards name Dr. Okafor (Piedmont) and Soggy Bottom because those are the clients of the game; avoid a second Okafor at Brightside.

## Files

`godot/scripts/service.gd`, `strings.gd`, `owner_cast.gd`, `sales_campaign.gd`, `story.gd`, `events.gd` (a comment), `tools/make_godot.py` (ported with `port_edit.py`; the one-word edits
of the compact `strings.gd` line and the `Morgan` placement were done with `sed` on both texts), `godot/story/strings.txt` (synced), tests: `oto_decks`, `second_cast`, `sales_life` (new), `vignettes`, `events`.
