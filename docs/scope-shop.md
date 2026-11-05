# Scope: the shop (roadmap S1)

**Status: SCOPED, nothing built.** Requested by the user (Nov 2026): the tech earns dollars per day but cannot spend them. Add an in-game store for desk upgrades.

## Idea
Spend paycheck cash on upgrades for your own desk and gear. Every purchase changes something you can SEE at the player's desk (a prop on the open desk, a different chair, lighting) and has a small, honest effect on play. The point is a reason to care about the cash and a sense of making the place yours (cozy loop), not a power curve.

## Where you shop
- A new desktop app **SHOP** on the work computer (a parody of a 2014 online hardware store, for example "NEWEGGG"/"AMAZOOM"-style parody name, 2013-14 catalogue and prices) and a **phone** entry (orders arrive the next morning on the desk, in a box you open with E).
- Cash comes from `Campaign.cash` (tech paycheck: 100 + 20 per ticket closed, minus penalties, plus on-call and overtime pay). Prices should make a purchase every few days realistic, a full desk by day 20 possible only if you play well.

## Catalogue (first pass, 2013-14 prices, parody brands)
| Item | Price | Seen at the desk | Effect |
|---|---|---|---|
| Mechanical keyboard (blue switches) | $90 | new keyboard sprite, clacky typing bubble | typing animations faster; RMM fix time -4%; coworkers within earshot lose 1 opinion a week unless you buy a quiet one (brown) at $100 |
| Ergonomic / vertical mouse | $45 | new mouse | energy drain -1 per day |
| Standing desk converter | $180 | the desk gains a riser; a stand/sit toggle (E on the desk) | stand = energy drain +1 but fewer slumps; sit = normal; both change the seated pose |
| Second chair cushion / lumbar | $60 | chair art tweak | tired penalty starts at 50 energy instead of 55 |
| RGB desk lighting (a strip behind the monitors) | $70 | colour-cycling glow, tints the desk at night | purely cosmetic; cozy; Maya and Dan comment |
| Desk speakers | $55 | two small speakers | unlocks a small desk radio (ambient music from the audio system, volume under Settings) |
| Headset upgrade | $110 | better wireless headset | phone calls give +1 customer XP |
| Second coffee mug / desk kettle | $25 | kettle on desk | one free sip refill a day |
| Plant, desk toy (newton's cradle, stress ball) | $15-30 | prop | +1 energy once a day on E |
| Poster/frame for the wall | $20 | wall art | cosmetic |
Owner/service/sales campaigns can reuse the same app later with their own budgets.

## Hooks (existing systems)
- Purchases saved in the campaign file (`shop` section, like `meeting`).
- Desk art: props are y-sorted pieces from `tools/build_sets.lua` (the rubber duck is the model for a small prop; a keyboard/mouse swap needs alternate sprites for the open desk). Cosmetic unlocks already exist in `Career.UNLOCKS`; reuse the same `unlocked(id)` pattern or add `Shop.owns(id)`.
- Effects read through one place: `Shop.factor("fix_secs")`, `Shop.energy_drain()` etc., so each hook in `Skills.fix_secs_for`, `Shift` is one line.
- Easy tier (cozy): items cost less; nothing breaks.
- Free Play: everything is unlocked for filming.

## Open questions for the user
1. Cosmetic only, or small real effects as in the table? (Recommendation: small effects, capped, so cash matters but nobody is forced to buy.)
2. A shop app on the computer only, or phone orders with next-morning delivery as well? (Recommendation: both; delivery box is a nice beat.)
3. Do purchases carry into Year 2 / New Game+? (Recommendation: yes, the desk stays yours.)
4. Parody store name and any brand parodies for the products.
5. Art budget: how many alternate desk sprites (keyboard, mouse, riser, lighting, speakers) are wanted in the first pass? (Recommendation: keyboard, mouse, speakers, RGB strip, riser = five small pieces.)
