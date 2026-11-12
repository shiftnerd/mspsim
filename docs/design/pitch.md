# MSPSim: the pitch

One page for the README and a future store page. Written 2026-11-12. Numbers come from `docs/design/systems-reference.md`
(generated from the game's data) and the facts table in `docs/design/gap-audit.md` section 5. Anything marked
**PROPOSED** or **OPEN** is not decided. The pillars and non-goals used here are DECIDED (gap-audit D-1).

## Concept statement (three sizes)

**Tweet length (under 280 characters)**
> It is 2014 and you work for a small IT support company. Close tickets, answer phones, drive to a dental office to fix a
> printer, then lose a bowling night to your coworkers. A blocky pixel-art office sim. Four jobs, one office, a second pad
> for a friend.

**One paragraph**
MSPSim is a pixel-art comedy sim about the small companies that keep other small companies' computers alive. You are a
tech, a service manager, a salesman or the owner of Pixel IT Partners, and you spend twenty working days (or weeks) in the
same blocky office, watching the same events from a different chair. A choice you make on Tuesday comes back as a ticket,
a card or a joke on Wednesday. After work there are nine team games, from bowling to a foam dart war by the copier. It is
set in 2013-14, down to the Windows XP end-of-support date, and it plays on a keyboard, a pad or a Steam Deck.

**The long hook**
Papers, Please made a queue of strangers into a game. Overcooked made a kitchen into a party. MSPSim sits between them, in
a cubicle: a queue of tickets with timers, a computer you actually operate (a service board, a remote monitoring console, a
phone), and a team that drags you out for karaoke when you have not closed the one about the blue screen. There are four
ways to play the same year (tech, owner, service manager, sales), three years to play it in, and a story that ends
differently depending on who you were nice to and which backups you checked. The pressure is comic. On Easy, nothing
punishes you.

## What it is, and what it is not

It is a **blocky pixel-art office sim about running IT support for small businesses in 2013-14**. Four campaigns, party
nights, a couch co-op mode, and a pad-and-handheld-friendly interface (every screen was walked with a pad alone in tests).

It is **not** (DECIDED, non-goals): an online game, a game with telemetry, a game with real brands or real songs, a game
from the AI / Slack / Windows 10 era, a combat game (nerf darts and paintball are party games, played for laughs), or a
Switch game. It is not a training course in real MSP operations either: the card numbers are a developer's first guess and
a real MSP owner has not checked them yet (OPEN, roadmap Q7).

## The one idea

**The office is the toy, and decisions come back.** Every system is something to poke, and a choice today is a ticket,
a card or a coworker's remark tomorrow. The same office plays as four jobs, so a second run shows you the other side of a
story you already lived.

## What you do

- Triage tickets against SLA timers, fix them from a chair (the remote console) or from a van (onsite visits), and close
  them in the service board. Skip a backup and pay for it later.
- Run the company: weekly cards, the books, hires, clients, a rival firm, a board review with a valuation.
- Sell, dispatch a crew, read the room at one-to-ones, and survive a conference trip.
- After work: bowling, karaoke, an escape room (four themes), dinner with a client, chair races, paintball, cornhole,
  a cookout and darts.
- Make your own person (ten hairstyles, clothes, hats, glasses) and unlock 72 medals that carry between runs.

## A short session (illustrative, built from the day-1 flow in the gap audit, I-4)

9:00. The clock starts. A hint says ARROWS TO MOVE, SHIFT TO RUN. 9:10, Morgan's mail: "Your first day." Garrison leans over:
one question, three answers, and he will remember which. A minute and a quarter in, the first ticket lands: a printer
that "does not print", which in this office means a spooler. You sit, open the remote console, restart the spooler,
and the client's mood ticks up. You close the ticket. The day report gives you a B and a line about the toner.
Tomorrow there are more tickets. Day 5 is bowling.

## Why it is fun

It is a small, legible loop (a ticket in, a fix, a result) wrapped in a lot of people with opinions. The short days
(2 to 10 minutes each) are natural stopping points; the cards are short, dry and mostly choices between two bad ideas;
the party games reset your head. Easy turns the pressure off completely for people who just want to wander the office.

## Content, in numbers (from the generated reference)

| What | Count |
|---|---|
| Campaigns / years | 4 campaigns, 3 years each (Year 2 and 3 unlock) |
| Pixel people with art | 78 (19 staff, 22 clients, 27 at the trade expo, 10 hairstyles) |
| Decision cards, beats and vignettes | 549 counted; plus 81 forum threads |
| Mini-games | 11 (9 team outings plus the printer and the dart war) |
| Career medals | 72 |
| Mutators / starting conditions | 14 / 5 |
| Difficulty tiers | 3 (Easy is cozy) |
| Rooms and client sites | 68 scenes |
| Text | about 146,000 words of patchable story text |

## Facts

| | |
|---|---|
| Title | MSPSim (working title; the plain subtitle "an office sim about IT support in 2013" is PROPOSED, gap-audit D-9) |
| Platforms | Windows PC and Steam Deck (Linux build, started in CI, not yet played on a Deck); ROG Ally and other Windows handhelds by the same Windows build. No Switch (DECIDED). Mac, Android, iOS: not planned |
| Players | 1; 2 on one couch with two pads (Free Play and the tech campaign; built, not yet tried with two humans) |
| Modes | Tech, Owner, Service manager, Sales, Free Play, Quick Play, Career |
| Length of a run (Normal, clock time) | Tech 200 min, Owner 80, Service 120, Sales 80; DAY LENGTH halves or adds half. A Normal tech run is 4 to 5 hours in 20 stopping points |
| Input | keyboard, gamepad, touch overlay; the mouse helps in the computer screens |
| Languages | English only (PROPOSED, gap-audit D-7; the font has no accents) |
| Engine | Godot 4.7.2, 2D, GL Compatibility |
| Status | Playable end to end; tested by 304 headless tests and bots; no human has played tech days 6 to 20 (OPEN) |
| Price | PROPOSED $9.99 to $14.99, one paid release, no DLC, no ads (gap-audit D-3) |
| Rating | OPEN. The README cover's "RATED E" is a joke box. Proposed target E10+ / PEGI 7 through IARC, see `scope-risks-tests.md` section 6 |
| Release date | OPEN |

## Screenshots (all exist in `docs/manual/img/`)

`title.png` (cover), `title-menu.png` (pick a campaign), `cubicles.png` (the office), `psa.png` (service board),
`rmm.png` (remote console), `boardroom.png` (owner), `crm.png` (sales), `conference.png`, `warehouse.png`, `bowling.png`,
`paintball.png`, `creator.png`, `kitchenette.png`, `mail.png`. Gaps: no co-op shot, no Deck shot, no 1280 x 800 shot,
no trailer.

## Store page features (draft, PROPOSED)

- Four jobs in one office: tech, service manager, sales, owner. Three years each.
- A real console to work in: tickets, SLA clocks, remote fixes, onsite visits, a phone.
- Nine team games after work, with a couch co-op mode for two.
- Make your own person; 72 medals and a collection that carry over.
- Easy is cozy: nobody gets fired. Hard is not.
- A seed for every run and a seed of the day.
- Plays on a pad and fits the Steam Deck screen (1280 x 800).
- Set in 2013-14, down to the printer. Every product is a parody.

## Tags and comparables (PROPOSED, to confirm against the game before use)

Tags: Management, Simulation, Pixel Graphics, Comedy, Cute, Local Co-Op, Casual, Colorful, Singleplayer. Not claimed: any
soundtrack tag (audio is on hold).

Comparables, and the part that is true: Papers, Please (a queue you triage under rules and timers); Overcooked (party
chaos, couch co-op, short rounds); Two Point Hospital (comedy management in a workplace). Not claimed: the depth of
Software Inc. or the multiplayer of either.

## What is different

Most office sims are about a business you build. This one is about a job you survive, from four chairs, in one year people
remember. The humour comes from real support life (the printer, the password, the backup nobody checked) and the cast
is caricatures of real people, with real first names kept for now (**revisit before any store page**).
