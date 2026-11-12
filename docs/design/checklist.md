# Design document checklist

What a game design document has to answer. Built on 2026-11-12 from four references, then widened for a game that ships on
handhelds in 2026. We audit our own docs against it (`gap-audit.md`) and write the new docs to it.

Sources (each item names its source in brackets):
- **R** = "Race'n'Chase Game Design", v1.05, 22 March 1995, DMA Design (the original Grand Theft Auto design document). A 12 page
  working brief for programmers, artists and producers. Strengths: rules as short testable statements, specific numbers,
  object lists with attributes, a win and a failure condition per mode, open items kept visible, milestones with dates.
- **D** = the Diablo design pitch, Condor Inc., 1994. An 8 page pitch for publishers. Strengths: a positioning hook, one
  defining mechanism that carries replay and expansion, a worked session and combat example, quantified content, a product
  line with a price, a team and a Gantt chart with test time reserved.
- **T** = the "Game Concept Document Template" (M. Sellers, 2018): one page of prompts. Strengths: hook first, everything tied
  to player experience, an interactivity taxonomy.
- **B** = the Doom Bible (id Software, 1993). NOT YET READ: its host refuses automated downloads. Add its items when a copy is
  saved to `archive/` (monster, weapon and level specifications, technology goals, what the player experiences).
- **M** = added for a modern, handheld-targeted game; in none of the references.

Status marks used by the audit: COVERED (where), THIN (what is missing), MISSING.

## A. Concept and positioning
1. The game in one or two sentences, and why it is fun. [R5.1, D, T]
2. A title that signals gameplay and style. [T]
3. Genre, and whether it is fresh or tired. [T]
4. Target audience: motivations, age rating and what the rating constrains. [T]
5. The gap in the market it fills, and comparable products with what is different. [D, T-USP, M]
6. The one defining mechanism or novelty everything hangs from. [D, R5.1]
7. The familiar elements that lower the risk. [D]
8. The player's role, point of view, fantasy and the emotions wanted. [T]
9. Pillars: three to five statements to settle arguments with, and what the game is NOT. [M]

## B. Structure, flow and progression
10. How the game is divided (modes, levels, missions) and what unlocks each part. [R5.3]
11. The objective and the win condition of EVERY mode. [R5.6]
12. The failure states of every mode, and what happens after one. [R5.6, D]
13. The core loop at three time scales: a minute, a session, the whole game. [D, T]
14. What the player does in the first 60 seconds and the first 10 minutes. [R, D, T]
15. A worked example of a session, turn by turn. [D]
16. Short-term and long-term goals, scoring and rewards; what counts as "enough" to progress. [T, R-thin]
17. Difficulty: tiers, what each changes, and how the curve is tuned. [M, R-thin]
18. The replay hook, and the content volume (levels, enemies, items, cards, hours). [D]
19. Session length and where a player can stop. [M]

## C. Systems and content
20. The list of systems, which are internal simulation and which the player touches. [T]
21. Every object, enemy, NPC or vehicle type with its attributes and behaviour. [R6.4, Doom]
22. How opponents or NPCs behave, communicate and escalate. [R6.5]
23. The economy: what is earned, what is spent, the sinks and the limits. [M]
24. Rules written as short statements that can be checked in play. [R]
25. Movement, physics or timing rules, with numbers. [R6.7]
26. Damage, consequence and recovery, and how each is shown. [R6.4]
27. Where randomness is used, and how it is seeded and bounded. [D-generator, M]
28. Every number the designer can tune, and where it lives. [M]

## D. Interface and access
29. Controls per input device, and how they should feel. [R6.6, D]
30. The camera, the view and what is on screen (HUD, popups, menus, map). [R5.7, D]
31. The front end: intro, menus, options, pause. [R7]
32. Accessibility: text size, contrast, remapping, assist modes, colour, subtitles, motor and cognitive options. [M]
33. Localisation and text volume. [M]
34. Settings and what is saved. [M]

## E. Fiction and presentation
35. The setting and period, and whether the story matters to play. [R5.2, D, T]
36. Tone, characters and voice. [D, T]
37. Visual style, with reference art and the pixel and palette rules. [T, D]
38. Audio style and the audio plan. [T, D]

## F. Technology and platform
39. Platforms, minimum hardware, engine and tools. [R3-4, T]
40. Performance and memory budgets, with a fallback. [R5.8, M]
41. Saving, persistence and old-save compatibility. [M]
42. Multiplayer, online or co-op, and what is out of scope. [R5.4, D]
43. The content and tooling pipeline (editors, builders, generators). [R8]
44. Build, test and release automation. [M]
45. Store and platform requirements (Steam Deck Verified, Handheld Optimized, ratings). [M]

## G. Production
46. The team, the roles and who owns what. [R9, D]
47. Milestones, each with a deliverable, and the dates. [R10, D]
48. The schedule, with test and balance time reserved. [D]
49. The budget and what happens if it is cut. [T, M]
50. The cut list: what goes first if time slips. [M]
51. A risk register, each risk with a mitigation and how it will be tested. [M]
52. The test plan: automated tests, bot runs, playtest questions and what each milestone must prove. [M]
53. Success measures. [M]
54. Marketing, the store page and the launch plan. [D, M]
55. The business model and price. [D, T]
56. Post-launch: patches, expansions, modding, sunset. [D, M]
57. Legal and rights: names, likenesses, trademarks and parody, licences of tools and assets. [M]

## H. Document hygiene
58. What is decided and what is only proposed, marked visibly. [R1.2]
59. Open items kept in view, with an owner. [R]
60. A revision history, and cross-references to the companion documents instead of copies. [R2]
