# Scope: rival habits and good habits (roadmap R38)

**Status: SCOPED, nothing built.** Design only. No code, art or story strings were changed by this document. Everything below is a proposal for the build agent and for the user to cut.

Goal: the competing MSPs in our story have bad habits. The player finds them out (and can win clients from them), and each bad habit teaches a matching good habit the player's own company can adopt. Bad habits also tempt the player, with the bill arriving weeks later. Owner campaign first, sales campaign second, service and tech campaigns only light touches.

House rules that apply to every line of text here: it is spring to summer 2014 (day 1 is Thu Apr 3 2014), no AI, no "MFA" (say "two-factor login"), parody names for anything whose UI or brand we imitate, text must be drawn by the 3x5 pixel font (letters, digits and `. , : ; ! ? - _ / ( ) ' @ # % & + = $ < > *` only: no square brackets, no curly quotes, no dashes longer than a hyphen), and `tests/forum.gd` style banned-word checks apply.

## 0. Inspiration and credit

- Inspired by the satirical blog series "The Trunk Slammer From Hell" (mspautomator.com, seven chapters) about a bad MSP owner and his careful rival. **Ideas only.** We took the TYPES of habit (an untested backup, a shared admin password, an unconfigured agent, a fudged questionnaire, a flat price) and nothing else: no character names, no plot beats, no scenes, no lines. The rivals below (Big Cheese Technology Group, Plumb Line Technology, and the existing ByteBrothers), their owners, businesses, incidents and wording are our own.
- Guard rail for the build: before text lands, the build agent diffs every new name and distinctive phrase against the chapters and drops any match. Add a `tests/habits_text.gd` banned-word list seeded by the user from the series' names.
- **Open item (user):** ask the author for a nod, or credit the series in `docs/manual/09-credits-and-legal.md` (under "Special thanks", one line: "The satirical MSP blog that made us think about backups in freezer bags"). Do this before the first public build that contains the rival arc. The doc does not edit the manual.

## 1. Summary and phased plan

The pitch in one paragraph: a sleazy local MSP, **Big Cheese Technology Group**, runs on shortcuts and says "business is booming" until the week it is not. The player meets its habits one piece at a time (a defecting client's assessment, a front-desk notebook, a takeover visit, Vic's intel, a forum thread, a vendor seat audit, an insurer's questionnaire). Each discovery is a small decision (win the client, warn them ethically, report to the vendor, or ignore it). Each habit has a good twin the player buys into on a new **HABITS** tab of the Boardroom. Eight **temptation cards** offer the same shortcuts to the player, with a seeded bill that arrives 3 to 9 weeks later. The careful rival (**Plumb Line Technology**) is the mirror lesson: right habits, cannot sell, so he loses clients; the player learns to show value (a one-page scorecard).

Everything is data-driven and rides on systems that already exist: `Owner.CARDS` and `Owner.DAYS`, `_poach_week` / `poach_gaps`, `_winback_card`, `Owner.oml()` practices, `Projects`, `Onsite` visits and `FINDINGS`, `Playbook.BOOKS`, `Incident` (the post-incident review), `Deals` / `QuoteBuilder` / `Handover` / `Retention` in the sales campaign.

| Phase | What | Size | Ships in |
|---|---|---|---|
| P0 | Scaffold: `Rival` static helper (data + rap sheet + evidence levels), new `Owner.flags` keys, save/load, read-only Boardroom RIVALS tab, strings roots | S | owner |
| P1 | Owner rival arc: 9 beat cards across weeks 4-19 (section 2.4), evidence channels wired into the poach card, winback card and Nerds forum, vendor seat audit and insurer questionnaire events | M | owner |
| P2 | Good habits: 14 habits, HABITS tab, freshness/decay, Standard score, hooks into backups / ransom / RDP / BEC / poaching / projects / valuation | M | owner |
| P3 | Temptation cards (8) with seeded consequences, the skeleton list, due diligence at the board review, conscience wording | M | owner |
| P4 | Inherited messes: 3 takeover jobs first (backup, credentials, firewall), then 3 more (blank dashboard, default passwords, ex-employee access) as Onsite jobs + Playbook books + Projects offers | M for 3, +S for the other 3 | owner (and tech as vignette) |
| P5 | Sales campaign: `incumbent` on leads, discovery shows the rival, ASSESS action, flat-vs-itemized quote gauge, VALUE PAGE, rumour cards, 4 new beats | M | sales |
| P6 | Light touches: tech campaign vignette (a client with a freezer-bag backup), service campaign runbook habit, 10 forum threads, Talk/Lynk lines, manual credit | S | tech, service |
| Total | | **L** (about 2 weeks) | |

**Cut first, in this order:** (1) Plumb Line as a character (keep the scorecard lesson inside the Big Cheese price card); (2) takeover jobs 4-6; (3) the DST habit (H9) and the default-passwords habit (H14); (4) forum threads and Talk lines; (5) the Boardroom RIVALS tab polish (keep the rap sheet as text lines in the review); (6) the sales rumour cards; (7) the vendor seat audit event (keep the temptation but make the bill a plain fine). **Never cut:** the rap sheet evidence levels, the delayed consequences, the HABITS tab and the freshness/decay rule; they are the game.

**Build order:** owner first (P0 to P4, shippable on its own), sales second (P5, reuses `Rival` and the habits), P6 whenever.

## 2. The rival

### 2.1 Cast (all invented, all 2013-14)

| Rival | What they are | Rap sheet | Role |
|---|---|---|---|
| **ByteBrothers** (exists: `Owner.COMPETITOR`, `_poach_week`, `Deals.resolve_pending`, `SalesBeats.undercut`) | The discount shop. Twenty percent under, twenty percent less delivered. Not crooks, just thin. | R04 unconfigured agents, R11 flat price, R12 undocumented work, R16 DST window, R17 ignores the front desk | The everyday rival the game already has. Rap sheet is mild and comic. |
| **Big Cheese Technology Group** (new, "BIG CHEESE TECH", slogan "WE DO IT ALL FOR $39 A SEAT"), owner **Rex Calloway** ("call me Rex, everyone does"), tech **Dusty** (half the staff, all the keys), a billboard on the county road, a booth at the Chamber of Commerce lunch | The sleazy one. Fast, friendly, cheap, always at the lunch, always "booked solid". | R01-R03, R05-R10, R13-R15 (section 2.2) | The story rival. Starts as a rumour, ends as a case study. |
| **Plumb Line Technology** (new), owner **Hollis Grady**, a careful ex-engineer, itemized 9-page proposals, a three-ring binder | The honest one who cannot sell. His quotes list 31 line items and clients cut ten of them. | none | Sales campaign only (and one optional mastermind cameo). The "show your value" mirror. |

Names are parody and local (a made-up county; no real company). Big Cheese is a rodent-adjacent pun like our other brands. Rex is not a copy of any blog character; he is a back-slapping Chamber of Commerce regular who sponsors the Little League shirts.

### 2.2 The rap sheet

The rap sheet is a per-rival list of **habits** (`Rival.HABITS`). Each habit has a **knowledge level** the player has earned: 0 UNKNOWN, 1 **RUMOUR** (heard, cannot be used), 2 **SEEN** (you saw it yourself, usable in your own sales talk and as a warning if phrased as what you saw), 3 **PROVEN** (a document, photo, log or vendor letter; unlocks formal actions). Evidence only goes up. It is shown in the Boardroom RIVALS tab and in the weekly report as one line ("BIG CHEESE: 3 PROVEN, 2 SEEN, 1 RUMOUR").

| Id | Habit (our wording) | What you learn | Matching good habit |
|---|---|---|---|
| R01 | The only backup is one USB drive in a freezer bag in the owner's trunk, trusted because "the light is on" | takeover visit (Delia's office), forum thread | H1 tested restore |
| R02 | One admin password for every client; the front desk has it on a yellow note | takeover visit, assessment | H7 break-glass and unique credentials |
| R03 | Two-factor login switched off "for convenience" on the hosted email | client assessment, insurer questionnaire | H4 risk forms / H7 |
| R04 | Antivirus, backup and monitoring agents are installed but never configured: a green dashboard, nothing watching (ByteBrothers too) | takeover visit, RMM look | H11 runbooks and a checked baseline |
| R05 | False answers on the client's and the insurer's security questionnaire | insurer claim letter (late), questionnaire copy | honest assessment (H10) |
| R06 | Lies to the vendor about seat counts for a discount | vendor seat audit (late) | H10 / vendor honesty |
| R07 | Bills a reboot as "advanced diagnostics" and invents fees | a client's itemized invoice, notebook | H2 itemized invoices |
| R08 | Fakes a fix (a "trace" on the phone) to calm a nervous client | notebook, Vic intel | H13 written authorisation / H5 real root cause |
| R09 | Fake Yowl reviews and forum personas; whispers that you are "not bonded, not HIPAA safe" | forum gossip, a prospect repeating it | honesty plus proof (certificate, the BAA) |
| R10 | Uses leads that came from reading your tickets (a client left a shared mailbox open) and "launders" them through a referral | Vic intel, a client's confession | H13 / H6 |
| R11 | One flat per-seat price, nothing itemized, so the client cannot see what is not included (ByteBrothers too) | the quote itself | H2 itemized pricing with a value page |
| R12 | Undocumented work: no SOW, no change ticket, three photos as "documentation" (ByteBrothers too) | takeover visit | H3 change requests, H11 |
| R13 | Email archiving switched off so a partner can delete messages (a law firm and a clinic) | assessment | H4 / H13 |
| R14 | Ex-employees and an ex-vendor rep still have working logins | takeover visit, RMM look | H6 offboarding |
| R15 | A "temporary" firewall exception open since 2012; default camera and printer passwords | takeover visit, assessment | H8 VPN, H14 device passwords |
| R16 | A 2:30 a.m. maintenance window that the clock change eats (last March 9, the spring-forward night) and root cause recorded as "Unknown" | notebook, a client's invoice | H9 calendar-aware windows, H5 |
| R17 | Ignores the one person at the client who sees the symptoms first; condescending ticket notes | the front-desk notebook | H12 listen to the front desk |

### 2.3 How the player learns (channels)

Each channel is an existing mechanism with a small hook. A habit can be reached by two or three channels so a lucky player and an unlucky one both see most of the sheet by week 20.

| Channel | Hook (exists) | New | Typical level |
|---|---|---|---|
| **Defect assessment** | `Owner._poach_card` (their "free IT assessment" lists your gaps) and `_winback_card` | when a client leaves for Big Cheese the exit chat card gains option ASK WHO THEIR NEW IT PERSON IS and, a few weeks later, the winback card carries the inherited mess | RUMOUR then SEEN |
| **Takeover visit** | `Onsite.start_visit(client, "takeover")` (new visit kind next to `qbr` / `pitch`), `Onsite.inspect` and `FINDINGS` | six takeover jobs (section 3) | SEEN, PROVEN with a photo or log |
| **Vic's intel** | owner campaign Vic cards (`Owner.on_deal`, `vic_report` week 10), sales campaign `lynk(...)` / `ask(...)` in `sales_beats.gd` | `Rival.intel(rival)`: Vic hears it at the Chamber lunch; unreliable (his `vic_penalty` and pay plan colour how much) | RUMOUR |
| **Forum gossip** | `Nerds.THREADS` (71) and `AMBIENT` exchanges, `needs:` conditions | 8 threads (a "who is doing the cheap flat-rate thing in my county" thread, an off-topic vent about a vendor audit) and 4 ambient lines that need `rap_bigcheese_*` | RUMOUR |
| **Front-desk notebook** | `Onsite.PETS` / site people, `STAFF` lines | the office manager's dated notebook is a prop-free card: she reads three entries | SEEN (becomes PROVEN with a photo) |
| **Insurer or HIPAA questionnaire** | `Incident` cards, `no2fa` / `_client_breach`, `HIPAA` beat 14 in the sales campaign | a questionnaire copy that a client forwards (our own renewal in week 16 is also the temptation) | SEEN |
| **Vendor seat audit** | `Expo.VENDORS` (WebWoot Security) | WebWoot's true-up letter to Big Cheese lands in a client's inbox (week 15) | PROVEN |

What a sensible player does with a discovery (this is the **decision**, the same four options every time, wording varies per habit):

| Option | Gain | Trade-off |
|---|---|---|
| **WIN THE CLIENT** (use it in your own sales and QBR, honestly: "here is what I would check") | the client or prospect: +mood, +win chance, a fair onboarding job | costs selling/owner hours; a client who stays loyal to a friendly Rex says no (30%) |
| **WARN THEM ETHICALLY** (a factual letter to that client only, what you saw, no gossip, no other client's name) | conscience +1, rep +1, the client usually switches within 6 weeks, other prospects hear you are fair | needs SEEN or better; if the warning is only RUMOUR it counts as slander (rep -2, a Rex counter-rumour card) |
| **REPORT TO THE VENDOR** (WebWoot, ShadowPoint) | needs PROVEN; a vendor rebate or partner credit (+$300 and an early invite), the seat lie gets a true-up | Rex retaliates with R09 rumours for 4 weeks; vendors sometimes do nothing |
| **IGNORE IT** | no cost now | if that client is later hurt and you knew (a flag), a later "you knew" card: rep -1, conscience -1; also leaves leads on the table |

### 2.4 The owner arc: Big Cheese over 20 weeks

"Business is booming" is true every week from 4 to 15. Every shortcut has a payoff date. Beats are cards in `Owner.CARDS` placed in `Owner.DAYS` (at a time of day, as the other cards), seeded by `Difficulty.rng("rival")`.

| Week | Beat (habit) | What happens | Consequence that arrives later |
|---|---|---|---|
| 3 | **Chamber lunch** (R11) | Garrison and Vic meet Rex at the Chamber of Commerce lunch: a flyer, $39 a seat, "everything included". Vic is impressed. Card `rival_flat` | seeds the price objection cards and the winback story |
| 5 | The billboard and the 5-star wall (R09) | Yowl (a Yelp-like review site) shows Big Cheese with 41 five-star reviews, 38 of them from accounts that review nothing else. Vic's intel RUMOUR | the reviews are exposed in week 12 |
| 7 | **Client defects on price** (R11) | uses the existing price-only poach (4%) or a gaps poach: a client signs with Big Cheese. Card `rival_defect`. Exit chat option keeps the door open and starts the clock | week 11 winback with a mess |
| 8 | Seat count (R06) | WebWoot's quarterly true-up to our own count, with Rex bragging at the lunch about his discount (the temptation `temp_seats` is offered to the player the same week) | the vendor audit in week 15 hits whoever lied |
| 9 | Reboot billing (R07) | a client's bookkeeper shows Marge an invoice with "ADVANCED DIAGNOSTICS $85" on a rebooted printer; same week the player is offered `temp_reboot` | week 14 (player) or week 15 (Rex) |
| 10 | **The notebook** (R17, R08, R16) | the defected client's office manager (Delia Pruitt) phones: her dated notebook has 14 entries since April. Card `rival_notebook`. Evidence SEEN, PROVEN if you ask her to photograph it | she becomes a referral source if you listen |
| 11 | **The inherited mess** (R01, R02, R04, R12, R14, R15) | the defected client returns (existing `_winback_week`) with patch debt 4 and a takeover onboarding. Card `rival_takeover`, then the takeover jobs (section 3) | the player's fixes become the "case study" in week 18 |
| 12 | Rumours (R09) | a prospect asks "are you bonded and HIPAA safe?" because Rex said you are not. Card `temp_review` (reply in kind with a fake Yowl account, or answer with the paper) | exposed fake reviews in week 17 if taken |
| 13 | Two-factor login off (R03) | a Big Cheese client's mailbox is the one the existing `bec_scare` fraud uses; we hear it from the bookkeeper | the week 16 questionnaire |
| 15 | **Vendor seat audit** (R06) | WebWoot's letter: Big Cheese is billed for 212 seats it never reported; its antivirus is suspended for the weekend. Clients call us at 6 pm. | the "bad day" begins |
| 16 | **Insurer questionnaire** (R05) | our own cyber renewal arrives; question 14 asks if two-factor login is on for every admin. `temp_quest`. A Big Cheese client's claim after a breach is refused because the answers were false (we hear it second-hand) | seeds the skeleton if the player fudged |
| 17 | Fake reviews exposed (R09) | a LabRat Nerds thread and a local paper blurb: "FIVE STARS FROM NOBODY". Rex deletes the thread; the Chamber lunch gets quiet | |
| 18 | The existing **competitor campaign** (poach wave x2) | Big Cheese "free assessment" blitz, now armed with a rumour. If the player holds PROVEN items and a good Standard the card gains an option SHOW THE SHEET | |
| 19 | **The bad day** (R01) | a Big Cheese client is hit by the CryptoLocker-style infection and the freezer-bag drive is dead. Five clients phone us. Card `rival_badday`. "Booked solid" ends | the board review (week 20) |
| 20 | Board review | a RAP SHEET and STANDARD readout; due diligence checks the player's own skeletons | |

The Rex arc ends without a villain's prison scene: he sells the book to an out-of-town outfit, the billboard is repainted. We do not spell out where he goes (keeps it funny rather than mean).

### 2.5 Sales weeks (Vic) over the 20 weeks

Vic's campaign already has 20 sales beats in `sales_beats.gd` (2 Chamber lunch, 6 ByteBrothers undercut, 14 HIPAA scare, 18 ByteBrothers recruits you, 19 Summit audits the book). The rival arc layers on top:

| Week | Beat | Habit | Notes |
|---|---|---|---|
| 2 | Lead card shows `INCUMBENT: BIG CHEESE` after the first call | R11 | discovery call reveals the incumbent (new field) |
| 3 | Chamber lunch (existing beat 2) gains Rex at the next table | R09, R11 | RUMOUR about the 5-star wall |
| 5 | **Flat price vs your itemized quote** (`sales_flat`) | R11 | price objection; the three-tier VALUE PAGE |
| 7 | ASSESS action on a Big Cheese client: a clean, honest list of findings | R02, R04, R12 | SEEN; creates promise points |
| 9 | A "referral" arrives that knows too much (`sales_laundered`) | R10 | temptation: take it |
| 11 | Plumb Line's quote beats you on trust but loses on price: you win the loser's client | mirror | the value-communication lesson, reversed |
| 13 | Rumour card in a prospect's office (bonded? HIPAA?) | R09 | honesty costs win % this week |
| 15 | Big Cheese's vendor audit makes three prospects go quiet then call | R06 | pipeline surge: capacity vs promise gap |
| 17 | Compare: renewals where the client was shown the scorecard | H2 | renew chance +0.06 |
| 19 | Summit due diligence (existing beat 19) also asks "how was the book sold?" | all | clawbacks and lies on the record |

### 2.6 Balance of the arc

The arc runs on the existing poach cooldown (`_poach_cool` 4 weeks) and `poached_<client>` flags; the Big Cheese beats do not add poach rolls on top, they **replace the label** of some rolls (when a poach is rolled, 50% from week 6 is attributed to Big Cheese if its habit is flat-price related, else ByteBrothers). So the total hit rate does not change; the story does.

## 3. Inherited messes (takeover jobs)

A client switching to you from a rival is a **takeover onboarding**: an onsite visit of a new kind, `Onsite.start_visit(client, "takeover")` (like `qbr`, `pitch`). It reuses the site scenes (`site_<type>_<skin>`), so **no new art is required for P4**; the freezer bag, sticky note and the blank dashboard are text and fx toasts first, with optional props later (a freezer-bag prop is a stretch).

Mechanics:
- On arrival Dan or Alan gets an "inherited risk" meter for that client: `Owner.inherit[client]` (0-100, starts at the count of unresolved takeover findings x 15). Each fixed finding drops it; unfixed findings raise the weekly incident chance (ransom, breach, outage) for that client.
- The walk-around uses existing `Onsite.inspect(obj)` and `FINDINGS` keyed by equipment (`pc`, closet cabinet, server, printer, x-ray, owner tablet). Takeover adds `FINDINGS_TAKEOVER` with 6 entries. LOG A TICKET / SELL IT AS A PROJECT / MAKE A NOTE FOR LATER all still exist.
- The big ones are Playbook books (`Playbook.BOOKS`, `pts`, `secs`, `hours`, `flag`, `req`, `needs`, `_outcome`), which also work in the tech campaign if a client is "taken over" there (as a vignette).
- Grade S/A/B/C/D of a takeover sets the client's start mood (as in `new_client_mood()`) and the follow-up tickets (`Story.queue_followup`).

| # | Job | Where | Finding and flow (choices, points, flags) | Maps to |
|---|---|---|---|---|
| T1 | **The freezer bag** | closet / owner's trunk (told by Delia) | The "backup" is one USB drive in a freezer bag with the light on. Steps: (1) find it (+2); (2) test restore on a spare PC: **fails 60%** (choice: do it now `pts 3 secs 40 flag tk_tested`, trust the light `pts 0 flag tk_trust`); (3) put it right: ShadowPoint BDR + offsite (`pts 4`, `hours 2`, needs `tk_tested` for the full 4), or replace the drive and call it done (`pts 1`); (4) write the recovery time down (`pts 2 flag tk_rto`). Skipping (2) and (3) sets `inherit` +25 and a ransom exposure x2 | `Projects.TYPES.backup_dr` and `SERVICES.backup` (chains the backup service sale), `Msp.backups[client]`, H1 |
| T2 | **Sticky notes and the one password** | front desk, then the RMM | A yellow note on the monitor; the same admin password works on two other former Big Cheese clients we also now serve. Steps: audit (`NETWORKING 1`), rotate everything and put the new ones in the vault (`pts 4 hours 1`), set up a break-glass account (`pts 3`, flag `tk_breakglass`), tell the client what was exposed (`pts 2`, honesty) or stay quiet (`pts 0`, flag `tk_quiet`, 30% a bad-news mail later) | `Playbook` book `takeover_creds`, `Owner.practice_*`, H7; vendor breach odds |
| T3 | **The door that was always open** | closet firewall | Port 3389 (and 21) forwarded since 2012, a "temporary" rule to a vendor rep who left in 2013. Steps: read the rules (+2), close it with a VPN (`pts 4`, `req [networking, 2]`), auto-blocking firewall (`pts 3`), change the port (`pts 1`, flag `tk_hole`), leave it (`pts 0`, flag `tk_hole`, break-in chance 8%/wk like `_rdp_week`) | existing `rdp` playbook (tech day 7) and `Owner.rdp_exposed`, `Projects.TYPES.security`, H8 |
| T4 | **Green and empty** | RMM (remote) | The LabRat dashboard is green because no alert policy was ever set. Steps: notice 0 alerts in 14 months (+2, only if `Skills.level("security") >= 1` or a walk-around hint), baseline the agents (AV policy, patch window, backup alert) `pts 4 secs 50`, quick-fix just the antivirus `pts 1`, leave `pts 0`. First week of real alerts floods Dan with tickets (`Growth` escalation counter up) | `Projects.SERVICES.patching`, RMM `patching` rate, `patch_debt` set to 4 on arrival, H11 |
| T5 | **Default passwords** | printer, camera, wireless | The printer (PrinterGame, admin page) and the ceiling camera still answer to admin/admin. A short job in the printer mini-game: change the password (`pts 2`) or skip (`pts 0`, flag `tk_default`); the camera is found in `FINDINGS` as a one-liner | `PrinterGame.MODELS` + `QUESTIONS`, H14 |
| T6 | **Who still has a key** | owner's office, then the mail admin | Ex-employees and an ex-vendor rep still have logins and a mailbox forwarding rule. Steps: list accounts (+2), disable them (`pts 3`), tell the owner (`pts 2`), write an offboarding checklist (`pts 3`, flag `tk_offboard`, gives H6 a head start). Ignored: 15% a "revenge" mail card two weeks later | `Owner._staff_week`, H6, `Incident` (BEC wording) |

Each job adds one record to `Rival` evidence: T1 gives R01 PROVEN (photo), T2 R02, T3 R15, T4 R04, T5 R15, T6 R14 (and R12 comes free with "no documentation at all" on arrival). Summary toast: "WHAT BIG CHEESE LEFT BEHIND: n ITEMS". The client can be asked for permission to share a sanitized version in a forum thread (conscience +1; a client who is not asked gets upset, mood -6).

Tech campaign: one new vignette (`Story.VIGNETTES`, kind `vignette`) in P6 uses T1 as a 6-line story at a client; no Playbook book.

## 4. Good habits for our MSP

A **habit** is a standing practice the player adopts once and has to keep doing. They live on a new **HABITS** tab of the Boardroom (next to BOOKS, CLIENTS, TEAM, STACK, PEERS, PROJECTS), drawn as a "STANDARD" checklist: 14 rows, a status word (NONE / ADOPTED / STALE / LAPSED), the weeks since last done, and what it earns. A **STANDARD** score (0-100) sums fresh habits; a band word shows in BOOKS and the board review (BARE under 35, PATCHY 35, SOLID 60, SHOWCASE 80).

**Freshness and decay.** Each habit has `every` (weeks between touches). ADOPTED until `every` weeks pass with no touch, then STALE (half the effect, row turns amber) until `2 x every`, then LAPSED (no effect, row red, a Marge nudge card once: "THE CHECKLIST HAS ONE EMPTY BOX"). Touching it again resets to ADOPTED for a smaller price (re-adopt is half the cost). This echoes `Owner.oml()`'s calendar cap: habits take weeks to show. A habit is "touched" by doing the real thing (a restore test, a QBR with a value page), not by clicking a button.

| Id | Habit | Cost (cash / owner hours / morale) | Effect and hook | Every | Shown how |
|---|---|---|---|---|---|
| H1 | **Tested restore each quarter** | $150 + 3 h per test; morale 0 | a restore test is a RMM action on one spare PC; passed = every ransom of a client with the backup service restores 100% (untested: 15% fail, the freezer lesson); ransom bill x0.5; `poach_risk` "failing backup" 7% -> 3% while FRESH; `Msp.backups[client].tested` | 13 | HABITS row, RMM BACKUPS tab shows TESTED date |
| H2 | **Itemized pricing with a one-page value scorecard** | $200 once + 1 h per QBR; morale 0 | quotes and renewals itemized; the scorecard goes out at each `_qbr` (weeks 7/11/15/19): mood +2, 'enforce scope' succeeds +15 points, `change_order` accept chance +10, sales `flat` objection penalty removed (section 6); neglect: only itemizing without the scorecard gives the 'doors to cut' penalty (-4 win points) | 8 | scorecard card at QBR; HABITS shows last sent |
| H3 | **Change requests with scope, steps, risk and rollback** | 2 h per project; morale -1 (paperwork) for 2 weeks | fixed-price creep 30% -> 18% (`Projects`), a failed cutover (migration card) costs half; adds the T3-style tested-change line to project completion | 10 | project quote card gets an extra line |
| H4 | **Signed risk-acceptance forms** | $0, 1 h per refusal | for `_client_no`, `no2fa`, declined security items: the paper trail makes blame cheaper (`_client_breach` waiver outcome extended to every declined recommendation); a refusal with no form is a skeleton | per refusal | HABITS count "OPEN REFUSALS" |
| H5 | **Lost-account review with a real root cause** | 2 h per lost client, no cash | pairs with `Incident` reviews: pick the true cause; right cause -0.02 poach risk for that cause class (8 weeks) and the lesson multiplier (like `Incident.lesson_mult`); 'Unknown' counts as a skeleton, a lie about the cause as two | per loss | review card after `fire_client` and a poached loss |
| H6 | **Offboarding checklist** (staff, clients, vendor reps) | $0, 1 h per departure | prevents the revenge card (a tech who quit keeps a password: 20% a card, $1,500 cost), vendor breach odds x0.9; a client who leaves gets their data back in writing | per departure | checked when someone leaves |
| H7 | **Break-glass account and unique admin credentials** | $240 once + $20/wk (vault), morale -1 for 2 weeks | vendor breach card damage x0.5 and its credential-rotation step is free; `_rdp_week` weak-password chance 4% -> 1%; BEC reset step; one shared password across clients is impossible | 26 | HABITS row, a 'sealed envelope' line in the BOOKS tab |
| H8 | **VPN, not open ports; firewall exceptions expire** | VPN $1,200 once (existing `rdp_exposed` fix) + 2 h per quarter review | the quarterly review closes forgotten exceptions: without it, 3% a week per site re-opens an RDP-like exposure after 13 weeks | 13 | HABITS row |
| H9 | **Maintenance windows that respect the calendar** (2014: the clock changes Nov 2, spring-forward was Mar 9) | $0, 1 h | overnight job failure 8% -> 6%; week 19 'the clocks change in November' card prevents a double-run/skipped backup; flavour mostly | 26 | week 19 card. **Cut candidate** |
| H10 | **Honest assessment** | selling hour + 2 tech hours per assessment | ASSESS action in sales and the owner pitch: lists real gaps, including ones that cost the client money; win chance -3 points, start mood +6, `churn` start -8, referral chance +10%; never lapses by time, only by taking a sales temptation | style | CRM ASSESS button; HABITS shows count |
| H11 | **Runbooks, a network map and labelled gear** | 6 tech hours per client map | ties to `Knowledge` (service campaign runbooks), the labelled patch panel (R37 cable tracing) and the `bus` playbook (tech day 19): onsite job time -20%, the 'only person who knows' event is neutralised; team speed +2% | 26 | per-client tick in CLIENTS; HABITS % mapped |
| H12 | **Listen to the front desk and keep a log** | 1 h per client per quarter (a coffee run), $15 | catches mood drift 2 weeks earlier (CLIENTS shows a warning chip), walk-around finding chance +20%; the person who sees the symptoms first becomes a source of tickets | 13 | CLIENTS flag; HABITS shows clients covered |
| H13 | **Written authorisation, even in an emergency** | $0, ten seconds | an email or text 'OK to proceed' before any emergency change; halves blame for `bec_loss` 'blame them' and rival disputes; lapses when you take an `emergency` shortcut | per emergency | HABITS count |
| H14 | **Default device passwords changed (cameras, printers, wireless)** | 3 tech hours per site, once | removes the walk-around 'default password' finding; small ransom/breach reduction; **Cut candidate** | once (check yearly) | tick per client |

**Connections to what exists:**
- Backups, ransomware, RDP: H1, H7, H8 plug into `ransom_options` (restore reliability), `_rdp_week`, `Msp.backups`, `Projects.SERVICES.backup`.
- BEC and wire fraud: H4, H7, H13 plug into `Incident.week()` miss share and `bec_loss`.
- Poaching and winback: H1, H5, H12 plug into `poach_gaps`/`poach_risk` (a third gap, "no restore proof" -> only when H1 is not fresh) and `_winback_card`.
- Projects and scope: H2, H3 plug into `Projects.change_order`, creep, `practice_scope`.
- Growth / team: H11, H3 touch `Growth` escalation counter and morale; H12 touches `Social` (client contact opinions, mood).
- Maturity and value: every ADOPTED/STALE habit counts as a practice in `Owner.practices()` once (cap +3 total, so the ladder still needs the calendar cap `Campaign.day / 4`). Valuation: Standard 70+ and `oml() >= 4` gives +0.5 (it **replaces** the existing +0.5 at oml 4+ rather than stacking; total maturity bonus stays at +0.5, avoiding a runaway), and due diligence deducts for skeletons (section 5).

## 5. Temptation cards

A temptation card offers a shortcut with a visible short-term gain, and the honest alternative with an honest price. Taking the shortcut seeds a **skeleton**: a record `{id, due_week, class, size}` in `Owner.skel`. The bill arrives when the due week comes (3 to 9 weeks later, jittered from `Difficulty.rng("skeleton")`) unless the player comes clean first (a COME CLEAN card is offered from the second skeleton on; it costs less than the bill). A **conscience** counter `Owner.consc` (0 clean to -n) rises by honest choices and falls by shortcuts; it feeds the board review wording, the due diligence multiple and one Marge ambient line. See open question 1 (visible or hidden).

| Id | Offered | Shortcut (gain) | Delayed consequence | Honest alternative |
|---|---|---|---|---|
| `temp_seats` | week 8 vendor true-up | report 41 seats instead of 63 to WebWoot: saves $308 a month for the rest of the run | week 15 vendor seat audit: back bill + 25% penalty ($1,900) and a mood hit with the vendor's rep (the stack option's `risk` +0.1); on a clean record WebWoot offers a partner rebate | pay the true-up ($308/month) and ask for a volume tier |
| `temp_reboot` | week 9 Marge | bill a reboot as ADVANCED DIAGNOSTICS ($85): +$85 x ~6 a month | week 14 a bookkeeper audits one invoice: refund + mood -10 at the client + rep -1; if several clients compare, a forum thread | bill the real minutes; or sell the client an actual monthly check |
| `temp_quest` | week 16 insurer renewal | answer 'yes' to every control (two-factor login for admins, tested restores): premium $38 a week instead of $65 and a smooth renewal | if a claim ever happens (any ransom/BEC loss afterwards) the insurer refuses it: you eat the bill (`bec_loss` insurer branch fails, 100%); due diligence counts it | answer truthfully (the $65 premium) and promise the broker you will fix two items by Q3 (H1, H7) |
| `temp_review` | week 12 rumour | open three fake accounts on Yowl and the forum to praise yourself and 'ask' about Big Cheese: +4 reputation, +1 lead a week for 3 weeks | week 17 a sleuth thread on LabRat Nerds traces the writing style: rep -6, lose your two friendliest forum regulars (`Nerds` friend -30) and a Chamber lunch card | reply once, politely, with the bond certificate and the BAA; ask two happy clients for a real review |
| `temp_launder` | week 9 (sales beat `sales_laundered`; owner version via Vic) | a 'referral' arrives that can only have come from a client's open shared mailbox where Big Cheese read our tickets: a hot lead with a ready pain | the lead's contact eventually asks how you knew; rep -3, the client whose mailbox it was leaves (mood -20), and conscience falls two | turn it down and tell the client their mailbox is open (a small free favour; pays back as H12) |
| `temp_price` | any poach / price card | drop the price 25% to win the client from Big Cheese: +1 client | thin margin: the profit review (`_profit_review`) reports a client under 20% of fee two weeks later; a 20% rise is then refused (45% walk) | sell value (existing 'show them the value $250'), or let them go |
| `temp_2fa` | week 6 (extends `_client_no`) and sales | switch two-factor login off 'just for the partner so he stops calling' | week 16 the existing `_client_breach` hits: your recommendation is not on paper, blame (no waiver!) $1,200-$4,000 and rep -2 to -4 | a signed waiver (H4) or insist (existing) |
| `temp_restore` | week 12 (quarterly H1 due) | skip the restore test: saves $150 and 3 hours, 'the light is on' | week 14-19 the ransom card: 15% the restore fails (never a total loss of a backup service client; a no-service client already risks it); poach risk 'failing backup' stays; one time it is the player's own freezer-bag moment | run the test; it often finds a real problem while it is cheap |

**Conscience:** each shortcut -2, each honest alternative +1 (max +1 a week), COME CLEAN +1. Bands: CLEAN BOOKS (0 or above), A FEW LOOSE ENDS (-1 to -3), SKELETONS (-4 to -6), A CLOSET FULL (-7 and below). It is felt, not graded: Marge says "I keep a folder called THINGS I WOULD RATHER NOT BE ASKED ABOUT" and the count of open skeletons is the number of items in it. At the board review, **due diligence** (a real thing in MSP sales; sales beat 19 already has it) checks the folder: each unresolved skeleton cuts the multiple by 0.5 (max -1.5) and the review shows 'FOUND IN DILIGENCE: n'. Ending epilogues vary with the band (`Yeartwo` style `TEXT` table).

## 6. Sales campaign hooks (Vic)

Mapped to `Deals`, `QuoteBuilder`, `Handover`, `Retention`, `SalesBeats`.

- **Incumbent field.** A lead dictionary (see `Deals`: `touch`, `notes`, `follow`, `quote`, `margin`, `discount`, `promises`) gains `incumbent` (`none`, `bytebrothers`, `bigcheese`, `plumbline`, `inhouse`), set at generation by `Difficulty.rng("leads")` (adds one draw per lead so seeds still repeat: always draw it, as the six-draw rule says). The CRM detail line already prints `RIVAL: BYTEBROTHERS` in the design; it becomes real and is hidden until the first CALL (the **discovery call**: "who is your IT person now?"), 85% revealed on a call, 100% on a visit.
- **Discovery to assessment.** New CRM button ASSESS (key A, one selling hour, like CHASE): needs the lead at MEETING. Result is a list of findings (`Rival.assessment(lead)`: from the incumbent's rap sheet, 3-5 items) shown as a card and recorded in `notes`. Each item becomes a **promise** you can keep (adds promise points: a finding you point at is a fix you are on the hook for) or ignore; the quote builder shows them as scope suggestions (like `Deals.EXTRAS`). Honest assessment (H10) lists the real items, including ones that cost the client; the cheap version ('looks fine, we can do it') wins 3 points more now and breaks later (`promise_gap` +0.5).
- **The flat price.** Quote builder gets a new gauge row `RIVAL PRICE` ($39 a seat from Big Cheese, flat; ByteBrothers 20% under list) and a new field `PRESENTED AS`: `ITEMIZED` (default, 31 lines, the Plumb Line mistake: each line is a door to cut: -4 win points and the client strikes the three lines that matter most), `FLAT` (matches the rival's form, +3 points, margin -8%, and nothing in writing on what is excluded, a promise-gap +0.5) and `THREE TIERS` plus a one-page VALUE PAGE (needs H2: removes the penalty, +2 points; asks for no more than three decisions). The price objection card (`sales_flat`, draft 11) is the explainer.
- **Winning and losing.** A win from a Big Cheese client starts a **takeover handover**: the handover card already has KEEP / RENEGOTIATE / DROP per promise; the findings from ASSESS are the promises. The inherited mess lands on Dan and Morgan (`capacity()` falls, `Retention` unresolved gap). Losing: ByteBrothers' steal chance (`Deals.resolve_pending`) is unchanged; a Big Cheese loss costs `rival_wins` +1 as for ByteBrothers (CRM review shows RIVAL WINS).
- **Plumb Line mirror beat** (week 11): the prospect picked Plumb Line (careful, nine-page proposal, 31 lines) and has not signed after six weeks; Hollis cannot answer 'which of these do I need?'. The prospect asks Vic for a second opinion. Options: SHOW THE THREE-TIER PAGE (needs the quote builder), JUST UNDERCUT HIM (temptation), or TELL THE PROSPECT HE IS GOOD AND SEND THEM BACK (honest, no deal; +conscience, +Hollis: a later Mastermind favour).
- **Rumours (reverse).** Big Cheese badmouths us: `sales_rumour` appears as a prospect asking if you are bonded and HIPAA safe. Honesty costs: answering with the paper (bond certificate, the BAA template) costs an hour and -3 win points on that deal (you looked defensive), badmouthing back wins +6 now (temptation, a counter-rumour card later), ignoring costs -5 points. All rumours expire after 4 weeks.
- **Retention and renewal.** Scorecards sent at business review (`Retention` renewal card option RUN A BUSINESS REVIEW) add `renew_chance` +0.06; a client who left because of a lie by us is not winnable back (6%).
- **Clawback and verdict.** A deal won by a lie (a temptation) is flagged `lie`; the 90-day churn gains +8; the week 20 verdict adds a LIES line; SALES DIRECTOR needs conscience above -3.

## 7. Draft content

Style: the same as `story/strings.txt` entries and `Owner.CARDS` (`speaker`, `text`, `options` with `label`, optional `need`, `fx`, and `text` that is the result). Speaker tokens: `{me}`, `{tech}` (Alan or Dan), `{sales_owner}` (Garrison), `{ops}` (Morgan), `{client}` (filled by `Incident.fill` / `Owner.fill_text`). New `fx` keys are sketched in section 8: `rap [rival, habit, level]`, `consc n`, `skel [id, weeks]`, `habit id`, `rep`, `mood`, `cash`. Characters in the 3x5 font only; no AI, no "MFA".

**1. `rival_flat` - owner week 3 (Garrison)**
- text: "{me}, I sat next to a man called Rex Calloway at the Chamber of Commerce lunch. Big Cheese Technology Group. He gave me a flyer: EVERYTHING INCLUDED, $39 A SEAT. No list of what everything is. Vic ate two of his cookies and says the price is a steal."
- opt `LOOK UP WHAT $39 A SEAT BUYS ($0, VIC ASKS AROUND)`: fx `rap [bigcheese, R11, 1]`, `consc 0`. text: "Vic calls two of Rex's clients. Both say the same thing: a person shows up, they are very nice, and nobody can say whether backups are in the price. You write EVERYTHING on a sticky note and put a question mark after it."
- opt `PRINT A ONE PAGE COMPARISON ($120)`: need 120, fx `cash -120`, `habit_start H2`. text: "Marge makes a one page chart: what you do each week, what it costs, and what is NOT included. It is the first time a client has seen a list like that. Two clients keep it on the fridge."
- opt `DROP YOUR PRICE TO MATCH`: fx `price -0.10`, `skel [temp_price, 6]`, `consc -2`. text: "Vic is thrilled. Alan does the margin on a napkin and puts the napkin in a drawer."
- opt `IGNORE HIM, HE WILL BE GONE BY JULY`: fx `rap [bigcheese, R11, 0]`. text: "Garrison says he has met a hundred Rexes. Rex is not gone by July."

**2. `rival_defect` - owner week 7 (Marge)**
- text: "{client} gave notice this morning. They are moving to Big Cheese. Their owner liked the $39 a seat and the free pizza on Fridays. Delia, the office manager, did not look at me when she handed me the letter."
- opt `MATCH THE PRICE FOR 8 WEEKS (-15%)`: fx `fee -0.15 8w`, `consc -1`, `skel [temp_price, 8]`. text: "They stay. You now run their office at a loss and everyone knows it."
- opt `SHOW THEM WHAT IS NOT IN THE FLAT PRICE ($250)`: need 250, roll 45% stay (`mood +10`), else leave. text: "You build the page with them: backups, patching, the 2 a.m. calls. The owner nods and says he will think about it."
- opt `WISH THEM WELL AND ASK FOR AN EXIT CHAT`: fx `defected client`, `consc +1`, `rap [bigcheese, R11, 2]`. text: "You hand over a clean folder of passwords and diagrams and say the door stays open. Delia puts your card in her notebook."
- opt `FIRE BACK: TELL THEM BIG CHEESE LOSES CLIENTS`: fx `rep -2`, `consc -1`. text: "It is true as far as you know, which is not very far. The owner stops listening."

**3. `rival_notebook` - owner week 10 (Delia, client's office manager)**
- text: "It's Delia from {client}. I have a notebook. Since April the server went slow on the 3rd, the 11th, the 17th, and twice on a Monday. I wrote it all down with the date. Rex says I should stop worrying. Would you like to see it?"
- opt `YES. COME IN AND BRING THE NOTEBOOK`: fx `rap [bigcheese, R17, 2]`, `rap [bigcheese, R16, 2]`, `habit_start H12`, `consc +1`. text: "She reads you fourteen entries. Three of them line up with a backup job that ran at 2:30 on the night the clocks moved. She is the only person in that office who has noticed anything."
- opt `ASK HER TO PHOTOGRAPH IT FOR YOUR FILE`: fx `rap [bigcheese, R16, 3]`, `rap [bigcheese, R17, 3]`. text: "Eight photos arrive by text. Your 'file' is now a lot bigger than Rex's."
- opt `TELL HER TO CANCEL BIG CHEESE NOW`: fx `rep -1`, `consc -1`. text: "You are not their IT person. Delia pauses, then says she will let you know."
- opt `THANK HER AND STAY OUT OF IT`: fx `knew client`. text: "Probably wise. Delia thanks you and goes back to writing."

**4. `rival_takeover` - owner week 11 (Alan)**
- text: "{client} wants to come back. Delia says Rex has not returned a call in nine days and the owner has a bad feeling about the black box in the closet. Alan says: 'Before we say yes, I want to see what they left behind.'"
- opt `SEND DAN FOR A TAKEOVER ASSESSMENT ($300, 4 HOURS)`: need 300, fx `visit takeover`, `habit_start H10`. text: "Dan takes a camera, a flashlight and a clipboard. He is very quiet on the drive back."
- opt `QUOTE A FIXED PRICE CLEANUP ($1,800)`: need 0, roll `project cleanup`, creep 30%. text: "Fixed price on an unknown mess. Alan stares at you like you are walking into a river."
- opt `ONLY SIGN WITH A CLEAN CONTRACT AND A TWO WEEK SCOPE FIRST`: fx `practice_scope`, `consc +1`. text: "They sign. You spend the first two weeks on what is actually there."
- opt `PASS, WE ARE FULL`: fx `consc 0`. text: "Delia says she understands. Her voice says she hoped."

**5. `temp_seats` - owner week 8 (Marge)**
- text: "WebWoot sent the quarterly seat true-up form. We have 63 users on the antivirus. If we put 41, the invoice drops $308 a month and nobody checks, Rex told Garrison he does it every quarter."
- opt `REPORT 41 AND KEEP THE $308`: fx `cash +308 x4`, `skel [temp_seats, 7]`, `consc -2`. text: "Marge types 41 and does not look up. The invoice drops. She puts the original in the folder."
- opt `REPORT 63 AND ASK FOR A VOLUME TIER`: fx `consc +1`, `stack antivirus -0.08`. text: "The rep sighs, then finds a tier that saves $90 a month. It is not $308, but it is true."
- opt `CHANGE VENDORS BECAUSE THIS IS ANNOYING ($800)`: need 800, fx `stack switch`. text: "Switching costs a week of grumbling. The new vendor audits you too, kindly."

**6. `temp_reboot` - owner week 9 (Vic)**
- text: "The printer at {client} needed a reboot. Eight minutes. Vic says Big Cheese bills that as ADVANCED DIAGNOSTICS, $85, and the clients never ask what that is. He thinks you could do the same."
- opt `BILL IT AS ADVANCED DIAGNOSTICS`: fx `cash +85`, `skel [temp_reboot, 5]`, `consc -2`. text: "The invoice goes out with the long phrase. Vic grins. A bookkeeper somewhere reaches for her glasses."
- opt `BILL THE EIGHT MINUTES`: fx `cash +20`, `consc +1`. text: "Twenty dollars and a short note: the printer needed a restart; here is the setting that stops it. The client keeps the note."
- opt `OFFER A MONTHLY PRINTER CHECK ($40/WEEK)`: fx `service printer`. text: "Now the reboot is part of something. Marge calls it recurring revenue with a stapler."

**7. `temp_quest` - owner week 16 (broker)**
- text: "Granite Mutual's renewal came in. Question 14: 'Is two-factor login enabled for every administrator account?' Question 19: 'Are restores tested at least quarterly?' Answer yes to both and the premium is $38 a week. Answer true and it's $65."
- opt `ANSWER YES TO EVERYTHING`: fx `weekly -27`, `skel [temp_quest, 99]`, `consc -2`. text: "The broker smiles and says it is a very common answer. The premium drops. A folder in Marge's cabinet gets thicker."
- opt `ANSWER TRUTHFULLY AND PROMISE TWO FIXES BY JULY`: fx `weekly +0`, `habit_start H1`, `habit_start H7`, `consc +1`. text: "The broker writes a note: IMPROVING. The policy renews at $65. You have two things to do before July."
- opt `ASK THE BROKER IF THERE IS A CHEAPER CARRIER`: fx `roll`, 40% cheaper carrier with the same truth. text: "He grumbles. Two phone calls later: $54, with a one-page list of what they need to see."

**8. `temp_review` - owner week 12 (Garrison)**
- text: "A prospect asked Vic if we're bonded and HIPAA safe because somebody told her we aren't. Big Cheese again. Meanwhile their page on Yowl has forty reviews. Garrison's nephew says he can set up a few accounts for us in an afternoon."
- opt `POST THREE REVIEWS AS CUSTOMERS`: fx `rep +4`, `lead +3`, `skel [temp_review, 5]`, `consc -2`. text: "Three glowing reviews from 'a happy dental office manager'. Alan reads them and does not speak for the rest of the day."
- opt `SHOW HER THE BOND CERTIFICATE AND THE BAA`: fx `consc +1`, `prospect +`. text: "Two documents and a coffee. She signs the following week and apologises for asking."
- opt `ASK TWO HAPPY CLIENTS FOR A REAL REVIEW`: fx `consc +1`, `rep +1`. text: "Delia writes the best one. She mentions the printer."
- opt `SAY NOTHING`: fx `rep -1`. text: "The rumour spreads, as rumours do at Chamber lunches."

**9. `temp_restore` - owner week 12 (Alan, the quarterly)**
- text: "It's been a quarter. The restore test is due: pull one machine off the backup and bring it back on a spare. Takes about three hours. Everything is green. Everything has been green for three months."
- opt `RUN THE TEST ($150, 3 HOURS)`: fx `cash -150`, `owner_hours 3`, `habit H1`, `roll 30% finds a real problem (fix it free, +consc)`. text: "It works. It also finds one machine that was never in the job. Alan fixes it before lunch."
- opt `SKIP IT, THE LIGHT IS ON`: fx `skel [temp_restore, 6]`, `consc -1`. text: "The light is on. You decide that is good enough, which is a sentence you will remember."
- opt `HAND IT TO DAN AND TRUST HIM`: fx `owner_hours 1`, `dan_stress +`. text: "Dan runs it. He labels the spare PC and the drive. He is slightly happy about the label."

**10. `rival_badday` - owner week 19 (Marge)**
- text: "Our phone has not stopped. Five Big Cheese clients called between 6 and 8. One had a machine encrypted, the freezer bag was found with a dead drive, and Rex's own phone rings out. They all want to know if we can take them tomorrow."
- opt `TAKE THEM ALL TOMORROW`: fx `clients +5`, `promise_gap +`, `capacity -`. text: "You say yes five times. Dan stares at the whiteboard for a while."
- opt `ASSESS EACH ONE FIRST AND TAKE THE BEST THREE`: fx `clients +3`, `visit takeover x3`, `consc +1`. text: "Three signed, two sent to a friendly MSP in the next county with a handshake. Alan calls it triage."
- opt `HELP THEM RECOVER WITHOUT TAKING THEM ($600)`: fx `cash -600`, `rep +3`, `consc +2`. text: "You spend a Saturday recovering what you can. Word gets around the Chamber of Commerce by Monday."
- opt `PASS, WE HAVE OUR OWN PROBLEMS`: fx `consc 0`. text: "The phones stop eventually."

**11. `sales_flat` - sales week 5 (the prospect, speaker `{client}`)**
- text: "Big Cheese quoted me $39 a seat, all in. You sent me a page with thirty-one lines. I don't understand half of them. I just want to know what I'm getting."
- opt `OFFER A ONE PAGE VALUE SUMMARY WITH THREE CHOICES`: need H2 (else a 'make it up' version at -2), fx `quote.presented three_tiers`, `win +2`. text: "GOOD, BETTER, BEST, one line each, and a box for what is NOT included. She circles BETTER."
- opt `MATCH THE FLAT PRICE`: fx `margin -0.08`, `promise_gap +0.5`, `skel`. text: "She signs in a day. Alan shows you the margin."
- opt `GO LINE BY LINE ON THE PHONE (AN HOUR)`: fx `hours 1`, `win +0.05`. text: "You read thirty-one lines. By line fourteen you both agree the list is the problem."
- opt `WALK, THEY WILL BE BACK IN SIX MONTHS`: fx `lose_lead`, `consc 0`. text: "You are right about the six months. You are wrong about it helping."

**12. `sales_laundered` - sales week 9 (Vic's phone)**
- text: "A woman named Gwen called, said a friend of hers recommended us. Her server is slow, she has XP in the front, and her IT person never calls back. She knows our rates and the name of our dispatcher. The friend is a client who has never mentioned us."
- opt `TAKE THE MEETING, SHE IS A GOOD LEAD`: fx `lead hot`, `skel [temp_launder, 6]`, `consc -2`. text: "She is a great lead. She is a great lead because someone read our tickets and sold her the story."
- opt `ASK HER HOW SHE HEARD`: fx `rap [bigcheese, R10, 2]`, `consc +1`. text: "She mentions the shared mailbox at the dental office. Vic goes quiet, then says he will make a call."
- opt `TELL THE DENTAL OFFICE THEIR MAILBOX IS OPEN, FOR FREE`: fx `mood +8 client`, `habit_start H12`, `consc +2`. text: "They fix the mailbox. Gwen becomes a client three weeks later, and she tells everyone why."

Each card above is the complete `speaker` / `text` / options set; the build agent turns it into `Owner.CARDS.<key>` dictionaries and strings.txt keys (`[Owner.CARDS.rival_flat.options.0.label]`, etc., following `bec_scare`). Check each against the charset test and a banned-word list before commit.

## 8. Data and model sketch (no code written)

Autoloads: **none new**. A `scripts/rival.gd` static helper (`RefCounted`, preloaded by `Owner`, `SalesCampaign`, `Onsite`, `Nerds`), the way `Incident` works, so `project.godot` does not change. State lives in `Owner.flags` and a few new Owner vars, saved in the campaign section; old saves default (clean book, no rap, no habits).

Owner (`owner.gd`):
- `flags["rap_<rival>_<habit>"]` int 0-3 (knowledge level); `flags["arc_<beat>"]` stage; `flags["knew_<client>"]` set when you ignored a known danger.
- `habits: Dictionary` `{H1: {state: "adopted", last: week, uses: n}}` and `consc: int`, `skel: Array` of `{id, due, size, class}`, `inherit: Dictionary` client -> int.
- New `fx` keys read by `Owner.apply`: `rap`, `habit`, `habit_start`, `consc`, `skel`, `visit` (takeover), `lead`, `weekly`. `Owner.settle()` gains rows `STANDARD`, `CONSCIENCE` (a word), `FOLDER` (open skeletons). `Owner.practices()` gains `habit_*`. `valuation()`/`multiple()` gain the Standard bonus (replaces the oml 4 bonus, section 4) and the due diligence deduction.
- New hooks: `Rival.week()` called from `settle` (arc beats, skeleton bills, habit decay, Standard); `poach_gaps` adds "no restore proof" when H1 is not fresh; `poach_risk` +/- from H1, H5, H12; `Incident.week()` reads H4, H7, H13; `Projects` reads H2, H3.
- Boardroom: tab HABITS and tab RIVALS (rap sheet), `Computer` window paint like the existing tabs (the file is near the 2500-line lint cap, so draw them from a new `habits_view.gd`, as `forum_view.gd` did).

Onsite (`onsite.gd`): visit kind `takeover`, `FINDINGS_TAKEOVER` (6), `JOBS` entries `takeover_*` or a Playbook book per job, the walk-around hook `Rival.on_inspect`.

Sales (`sales_campaign.gd`, `deals.gd`, `quote_builder.gd`, `crm.gd`): lead `incumbent`, `Rival.assessment(lead)`, CRM ASSESS button, quote builder field `PRESENTED AS` and the `RIVAL PRICE` gauge, `rival_wins` (exists), flag `lie` per deal, `consc` mirror in `SalesCampaign`, 4 new beats in `sales_beats.gd`.

Nerds / strings: `Nerds.THREADS` + `AMBIENT` entries with `needs: "rap:bigcheese:R05"`; new roots `Rival` (rap sheet text), `Habits` (names, rows) in `Strings.ROOTS` and `PATCHABLE`.

Other: `Career` counters (HABITS ADOPTED, SKELETONS PAID, TAKEOVERS, CLEAN SHEETS); `Yeartwo.TEXT` epilogue lines; `Difficulty` cozy Easy: skeleton bills are halved and honest alternatives are never locked; `Mutators` can add a "BIG CHEESE EXPANDS" window (rival aggression x1.5) later.

## 9. Test plan

New: `tests/rival.gd` (rap sheet only goes up; each channel sets the intended level; evidence gates the report/ethical-warning options), `tests/habits.gd` (adopt, freshness STALE at `every`, LAPSED at `2 x every`, re-adopt half price; effect numbers on ransom, `poach_risk`, `_rdp_week`, creep; Standard bands; `oml()` capped by the calendar), `tests/temptation.gd` (each shortcut seeds a skeleton that fires on its due week; the honest alternative seeds nothing; COME CLEAN removes it for less than the bill; conscience arithmetic), `tests/takeover.gd` (the six jobs through the real Onsite visit, inherit meter, flags, follow-up tickets), `tests/sales_rival.gd` (incumbent reveal, ASSESS findings become promises, flat vs itemized vs three tiers win chance, rumour expiry, `lie` flag and churn), `tests/habits_text.gd` (every new string in the 3x5 charset, no period slip, none of the series' names), `tests/rival_shots.gd` (renderer: HABITS, RIVALS, takeover card at wide / h / v). Extend `tests/owner_balance.gd` with strategies `honest` and `shortcuts`, and `tests/owner.gd` for the 20-week run staying deterministic with the seed.

## 10. Balance risks

- **Shortcuts must feel good first, then bite.** If skeleton bills are small, the player will always take them. Target: a bill is 2-3 times the gain (a seat audit penalty), and bundled with rep/mood so two shortcuts hurt more than 2x (stacked due diligence). Test with the `shortcuts` bot: it should end below `smart` on value and rep, above `cheap` on cash for the first 12 weeks, and below it by week 20.
- **Habits as a chore.** 14 rows can become a spreadsheet. Keep touch costs tiny, make decay forgiving (STALE halves, LAPSED is not punished beyond losing the bonus) and let the Standard score be earned mostly by things the player does anyway (QBR, offboarding, a restore test).
- **Double counting maturity and valuation.** `oml()`, practices and Standard overlap; section 4 caps the extra at +0.5 total and only the due diligence deduction is new risk.
- **Rival arc steals attention from poaching.** It re-labels existing rolls instead of adding new ones (section 2.6).
- **Takeover jobs flood the queue.** `inherit` and the flood of week 19 add load; cap arrivals (`Sales.max_clients()` 8, 10 in Year 2) and make 'take the best three' the recommended answer.
- **Cozy Easy:** nothing punishes you; bills halved, no locks. Keep the card text jokes, drop the consequences to a toast.
- **Seeds.** Every roll uses a named `Difficulty.rng`; always draw even when the result is unused so seeds repeat.
- **Noise.** Owner balance runs are noisy (a single event can halve a run): judge by three runs and by rep and mood, not valuation alone.

## 11. Open questions for the user

1. **Conscience: visible or hidden?** Recommendation: shown only as words and Marge's folder (open skeletons counted), never as a number; the review states the band. Alternative: a visible meter on the HABITS tab.
2. **Can consequences ever lose a campaign?** Recommendation: no hard fail beyond the existing rules (cash under -$3,000 or reputation 0); the worst stacked case costs about $6,000 and 8 reputation. Alternative: a lawsuit card ending the run on 3+ unresolved skeletons plus a loss.
3. **How bad can Big Cheese get before it stops being funny?** Recommendation: fraud with a laugh (flat prices, freezer bag, fake reviews, seat lies), no violence, no endangering patients; the worst consequence is a dead drive and a denied claim. Do you want to keep the HIPAA jokes at the clinic or soften them?
4. **Credit and permission:** a nod from the series' author, or a credit line in the manual, before release? (Section 0.)
5. **Plumb Line:** worth a full character, or fold the lesson into the price card? He costs about a fifth of P5.
6. **Rex's end:** a sale of the book (friendly) or a quiet collapse (current)? Also, does the player ever get to **buy** the Big Cheese book? (Not in this scope; an M&A item.)
7. **Tech and service campaigns:** just the light touches, or a full habit mini-set for each (a service manager habit tab with runbooks and handover)?
8. **Report to the vendor:** should this ever pay real rewards (a rebate, an early invite) or be a pure ethics move?
9. **Year 2 / New Game Plus:** carry the Standard (as a 60% carry-over like reputation) and a new rival, or reset?
10. **Art:** do we want a freezer-bag prop in the closet (a stretch for P4), or stay with text and fx toasts?
