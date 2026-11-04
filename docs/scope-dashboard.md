# Scope: metrics dashboard screen (roadmap R20)

**STATUS: built** (all five steps, see "Status (built)" below and CLAUDE.md "PIXEL IT METRICS").

Read-only scoping pass (Nov 2026) from the code, not play-tested. Items marked (inferred) are readings of the code. Reference: `archive/metrics.jpg` (a 2014 wall dashboard: ten tiles of 14-segment LED digits in orange / green / yellow / red, a green "hours worked by tech today" bar chart, a green and yellow opened / resolved tickets chart for the prior three weeks).

**Owner decision:** a computer app AND a wall TV, showing the same data.

## Data: what exists, what must be recorded
- **Tickets:** `Msp.tickets` carry `status` (New / In Progress / Closed), `pri`, `sla_left`, `breached`, `client`, `fix` (project and `onsite_*`). Tiles map as: COMPLETED = `Msp.closed_ok`; IN PROGRESS = status; BACKUP = `Msp.backups` with `ok == false`; SLA BREACHED (stands in for ON-HOLD, red) = `Msp.breached`. "Waiting on client / vendor" has no state today: derive WAITING ONSITE and WAITING ON PROJECT instead of inventing a status.
- **Hours per tech:** not recorded anywhere useful. Owner `_work_queue` only records tech-seconds per client; service `work_queue` has a per-tech dictionary that is discarded; in tech mode there is only the player, so a per-tech chart is pointless there (show the crew unnamed or initials only, hide it on Easy: no "worst tech" bar).
- **Opened vs resolved per day:** not recorded. Tickets have no opened / closed time; `Campaign.history` holds only `{day, grade, points}`.
- **To record:** a `Dash` module with `days: [{d, opened, closed, hours: {name: float}, missed}]`, hooked into `Msp.create_ticket` / `close_ticket` and the owner and service work queues, rolled over in `Msp.new_day`, saved as a rolling window of 21 entries in a `dash` section of the campaign save (an old save loads empty: show zeros, never fake data).

## Tiles per mode (ten tiles)
- **Tech:** OPEN, IN PROGRESS, CLOSED TODAY, SLA BREACHED, P1/P2 OPEN, BACKUPS FAILING, WAITING ONSITE, REOPENED, ENERGY, DAY SCORE.
- **Owner:** CASH, REVENUE/WK, EBITDA, W-2 %, CLIENTS, A/R OWED, OPEN TICKETS, BURNOUT, TEAM SPEED, VALUE / MULTIPLE.
- **Sales:** PIPELINE, MEETINGS, QUOTED, WON, QUOTA, DEALS, HOT LEADS, CLIENT MOOD, SELLING HOURS, LOST.
- **Service:** QUEUE per team, INCIDENTS, TRUST (both owners), ESCALATIONS, SLA BREACHED, UNASSIGNED, OVERTIME, MOOD, DAY SCORE.
- **Layout:** wide 368x128 is tight: 5x2 tiles plus one chart (a second chart on a tab or auto-rotate); h 320x180: 5x2 tiles plus two charts side by side; v 180x320: 2x5 tiles with the charts stacked, bar labels as initials.

## Rendering
- One shared `scripts/dashboard.gd` (a RefCounted with static functions): `tiles(mode)` and `series(mode)` as pure data (testable headless) and `paint(canvas, rect, mode, t, opts)` that only draws rectangles and polygons, like `crm.gd` and `chair_race.gd` already do.
- **14-segment digits:** 14 flags per glyph; unlit "ghost" segments at about 12% alpha give the reference its look. Colours: orange `#ff9a1f`, green `#3ddc55`, yellow `#f2e84a`, red `#ff3b30` chosen by a threshold per tile. Blinking colon, a slow pulse on red tiles, bars grow in over about a second. 3D-ish bars: front face, lighter top, darker side (2 px extrusion), paired green opened and yellow resolved.
- **Computer app:** a new `dash` app (icon METRICS, every mode) with `_paint_dash()`; `computer.gd` is already near the 2500-line lint cap, so the code lives in `dashboard.gd`.
- **Wall TV:** the existing `tv` fx screen is 32x14, far too small, so it gets a fifth "micro" channel (four coloured blocks plus a sparkline), and E opens a read-only full-size takeover like the computer (`Game.ui_open`, Esc closes). The main floor has a TV already; the cubicle area has none (add a `P.tv()` and a BGFX line, rebuild that set; optionally a bigger `P.tvWide()` 60x34).

## Gameplay value (beyond looking good)
- **Glance hint:** a red tile flashes the TV frame and toasts once a day; on cozy Easy use amber, not red.
- **Owner KPI board:** three targets (W-2 under 55%, mood 75 or more, A/R under $1,500) shown as ticks on the tiles and tied to the existing peer accountability goal.
- **Day report sparkline:** a 14-day opened / resolved sparkline from the recorded days (cheapest high-value use).
- **Growth tie-in:** ESCALATIONS tile with a trend arrow.
- **Avoid:** leaderboards against the cast or a worst-tech bar; morale effects should be flavour text on Easy.

## Steps
1. Data model `Dash`, hooks, save and load, `tiles` / `series` (S); test `tests/dash.gd`.
2. `dashboard.gd` renderer, 14-segment digits, three layouts (M); `tests/dash_shots.gd` at wide, h, v for all four modes.
3. Computer app: icon, paint, input routing (S).
4. Wall TV: micro channel, E takeover, the cubicle area TV prop and art rebuild (M).
5. Extras: day report sparkline, glance hint, owner KPI ticks (S).

## Risks
- 10 tiles plus charts may not fit at 128 px height (fallback: tabs).
- Per-tech hours mean nothing with one player.
- Brand rule: our own title ("PIXEL IT METRICS"); the photo's tile names include real vendor names, use invented ones.
- A save format change needs an old-save default.

## Status (built)
All five steps are built. Deviations from the plan above: `Dash` is a static script (no autoload, so Msp can use it while it loads); the owner board has CLIENT MOOD in place of TEAM SPEED (so the three KPI ticks W-2 under 55, A/R under $1,500 and mood 75+ each sit on a tile); the owner left chart is EBITDA by week, the tech and cozy-service left chart is open tickets by client, the sales one the pipeline by stage; owner hours are recorded as one "CREW" total; the wide layout shows one chart at a time (rotates every 6 s, Enter or a click swaps it); the TV has four channels (the micro one is the fourth); the cubicle-area TV replaced the framed notice position (the notice moved left). The growth ESCALATIONS trend arrow is built (Nov 2026): tech REOPENED and owner OPEN TICKETS gave their tile to ESCALATIONS (`Growth.esc_now`, arrow from `Growth.esc_trend`); the service board keeps its own daily ESCALATIONS tile without an arrow. Details: CLAUDE.md, section PIXEL IT METRICS.
