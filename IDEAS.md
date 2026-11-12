# MSPSim ideas

A parking lot for things we have talked about but not built. Move an item to `CLAUDE.md` (as documentation) once it ships.
Sections: the two campaigns, the shared systems, the world and the characters, presentation, tooling.
Items marked **(real story)** came from the /r/msp research (see `docs/msp-research.md`).
Open bugs and polish live in `docs/BACKLOG.md`; the long replayability write-up is `docs/replayability-ideas.md` (effort S/M/L and code hooks for every item).

## Replayability and variety (built)
The ten approved replayability items are built: difficulty and seeds, printer variety, karaoke songs, the escape room recipes, who comes along, dinner variety, the career screen and medals, the event and vignette decks, mutators and starting conditions, Year 2 and the daily seed with the Free Play toolbox, plus bowling, nerf, trip and onsite variety. What is left from them is tracked in `docs/ROADMAP.md` (rows R1 to R12) and described in `docs/replayability-ideas.md`.
The rules stay: data tables (patchable, in `strings.txt` style) not code, numbers in one `TIERS` table, every game reads a seeded `Difficulty.rng(stream)` so runs and tests are reproducible, parody names only, 2013-14 only, and never punish the player for family or health reasons.

## New campaign paths (built)
**Canon (user): Alan and Garrison are the two owners of Pixel IT Partners.** Alan is the technical owner, Garrison the sales-and-culture owner (Office 1 and Office 2 are theirs). Morgan Reyes is the manager, Marge the bookkeeper, Vic the account manager.
**Names (canon change, Nov 2026): Vic became John (account manager) and Marge became Christy (controller).** Older lines below that still say Vic or Marge mean John and Christy; the game uses the new names everywhere.

Built from it: the owner campaign played as Alan or Garrison (the other is the co-owner NPC), the service manager campaign played as Dan, the sales campaign played as Vic, the owners as a last resort in the tech campaign, and point-buy stats at character select. Design write-up: `docs/campaign-paths.md`; what exists: `CLAUDE.md`.

## Tech campaign
- A real conference-room scene for the yearly review (Morgan, with the team visible behind).
- More story days for the quiet days: the weeks between the big jobs still need small human beats.
- Dialer / calling clients from the phone app, replies that do something, a notification buzz and banner on the HUD, a lock screen, a camera app.
- NPCs noticing and reporting outages themselves (a coworker calls it in before the monitoring does).
- (Built: labelled patch panel and cable tracing.) A spare laptop you can plug in, LEDs glowing through a pitch-black closet, a side view of the rack.
- Phone: more ticket types, a day-end score screen with a "best moment" recap.
- Coworkers invite you to things (lunch, a beer after a hard night), react to the clock themselves ("lunch?"), weekends and holidays, the day-20 review quoting what they said.
- A settings and credits screen, music, an animated logo. (The character-select / first-day screen with the phone pick is done: see CLAUDE.md "Logo + title screen".)
- More characters that can be played (Vic is now selectable as the 7th).

## Owner campaign
- Client QBR as a real conference-room scene with a client character (not only a card).
- Candidate interviews (ask questions, spot the red flags) before you pick a hire.
- Collections calls (you or Marge phoning a late payer, with a script and a mood read).
- Hardware refresh cycles and warranty claims, a reseller rebate program, vendor distributors and credit terms.
- Quotas and a performance improvement plan for Vic; commission clawbacks; Vic leaving with a client.
- Security-stack upsells (managed antivirus, spam filtering, two-factor login) that clients buy and that change ransomware odds.
- A second-office phase after "open a second office", cash-flow forecasting, a line of credit, payroll panic weeks.
- More peer-group topics (pricing, tool consolidation, hiring) and a mentor "graduation" (Dana's advice fades as you improve).
- Contracts: term lengths, auto-renewals, price escalators, termination for convenience, the client who wants to cancel.
- Insurance (cyber / E&O) as a decision and as a claims story.

## Shared systems
- Ticket sources and types: email-to-ticket noise, "urgent" tickets from important people, tickets nobody owns, duplicates, alert storms.
- Time tracking and billable vs non-billable hours as a driver of the W-2 ratio.
- Client onboarding as a project (discovery, documentation, agent rollout) and offboarding.
- Documentation as an asset (the tech who knows everything and will not write it down).
- A reputation breakdown screen: who thinks what of you (clients, coworkers, vendors, peers).

## World and characters
- NPCs that dance (the player does); more ambient motion and interactive props.
- Clients as visitors in the office (QBR, an angry walk-in, a new-hire interview).
- Weekends and the after-hours office: lights off, the player alone with the pager.
- Seasonal events (tax season, year-end, holiday freeze) that change ticket mix.

## Presentation and tooling
- Per-format vertical camera presets, a video capture mode for filming (Free Play is that today).
- An in-game glossary (PSA, RMM, W-2 ratio, EBITDA, QBR, SLA) for non-MSP players.
- Balance harness: a nightly run of the three owner strategies and a tech auto-run, with the numbers saved to a log.
- Test isolation: every test that uses `user://test_*` saves shares them; give each test its own prefix so they can run in parallel.

## Setting: 2013-14 (keep every idea period-correct)
The game is set in 2013-14: Outlookish 2013, an iFone 5 or a Nexxus 5, Windows 7 / 8.1 / XP, a ConnectWise- and LabTech-era PSA and RMM, hosted Exchange and early Office 365. Ideas and card text have to fit.

- **Not in this world:** AI helpdesks or assistants, TikTok / Discord / Slack-first workplaces, Microsoft Teams, Microsoft 365 as a brand, Microsoft CSP / NCE billing, EDR / SOC-as-a-service marketing, GDPR, Windows 10 / 11, "zero trust" language,
  WannaCry / NotPetya (2017), the 2021 Kaseya attack, remote-work-everywhere, MFA as an SMB norm (say *two-factor login*, and it is rare).
- **In this world (verify dates before shipping; from memory):** CryptoLocker ransomware (Sept 2013, Bitcoin / prepaid-card ransoms), the **Target breach** (Dec 2013, via an HVAC contractor's remote access: a vendor-access story),
  **Heartbleed** (April 2014), **Windows XP and Office 2003 end of support (April 8, 2014)**: a huge MSP project wave that fits the day-4 desktop install story perfectly; Windows Server 2003 end of support looming (July 2015);
  Windows 8 / 8.1 and the missing Start menu; BYOD and iPhones on the company mail; Dropbox and Google Apps as shadow IT; early hosted Exchange and Office 365 migrations; backup and disaster-recovery appliances; managed antivirus; spam.
- **Tools of the era:** ConnectWise, Autotask, Kaseya VSA, N-able, LabTech (our PSA and RMM names are fake but should feel like these), Spiceworks, StorageCraft / Datto-style backup, Webroot / Vipre / AVG managed antivirus.
- **Code already fixed for the period:** the "client said no" cards say two-factor login, not MFA.
- **Already period-safe:** ransomware (CryptoLocker era), PowerShell 4, Windows 7 / 8.1 / XP, Exchange, VLANs, NAS, Cat5e / Cat6, Bitcoin ransom notes.

## Team outings (all modes)
**Built:** bowling, karaoke, escape room, dinner, cornhole, the cookout and the chair race, as real rooms with the cast in them and in-room games, with invitations in the tech and owner campaigns and the O key in Free Play (see `CLAUDE.md`, "Team outings", "The outing rooms" and the warehouse sections). Still open from the list below: the pager going off mid-karaoke, Vic bringing a client, the annual off-site / holiday party, outings that take a struggling hire aside, and morale drifting down when outings are skipped for months.

Bowling, karaoke, an escape room, dinner. A way for the team to be people, not just a queue. Works in every mode because it plugs into systems that already exist.

- **Tech campaign:** the coworkers invite you (Garrison, the culture owner: "a few of us are going bowling Thursday"); you can say yes, no, or "only if the queue is quiet". Going raises coworker opinions (`Social`), especially with the ones who are cold to you;
  skipping too often lowers them. Mini-moments rather than a full mini-game: a scene in a bowling alley or karaoke bar with the cast (their sprites in a new set), a few choices (sing the song, pay for dinner, leave early because the pager
  went off). The pager going off mid-karaoke is a natural place for the on-call idea below.
- **Owner campaign:** a budget decision with a payoff: a team outing costs $150-$600 (dinner, bowling, an escape room, a karaoke night, an off-site day) and gives **morale** (which lowers burnout, raises team speed), a one-time bump
  to retention (flight-risk hires quit less), and sometimes a story (the quiet tech who turns out to be a karaoke legend; the client you meet at the next lane). Skipping outings for months has a slow cost (morale and loyalty drift).
  Compare with a raise: cheaper, shorter-lived. Vic may bring a client or a prospect along (a sales angle), or embarrass the company (an honest risk).
- **Different outings, different effects:** *bowling* (broad appeal, cheap, mild), *karaoke* (big mood swing, bonds, risk of awkwardness), *escape room* (teamwork: improves how the crew works together, a small speed bonus for a few weeks),
  *dinner* (the most expensive, best for one-on-one talks with a struggling hire or the team lead), *a team off-site / holiday party* (once a year, a larger bill).
- **Hooks:** `Social` (opinions), `Owner` burnout / morale, the `Cards` UI (invitation and choices), a new "outing" Set or two (bowling alley, karaoke bar) built with the existing set tooling, the coworker invite lines already on the list ("lunch?").
- **Free Play / film mode:** the outing sets and scenes are useful as extra locations for filming even without the game loop.
- **Chair race and rolling chairs, follow-ups (R12 shipped the first pass):** a second course (the kitchenette loop, the conference room table), (the warehouse version with the cast on chairs shipped in R18 phase 2), shoving someone else's chair or a coworker's chair as a prank (with the Nerf opinion rules), chair joust, a "boss walks in" slowdown, medals (CLEAN LAP, SPEED DEMON), a tiny time-trial ghost of your best run, a seeded course layout per day, and spinning with a tap (a chair is allowed to spin).
- **Keep it optional and kind:** nobody should be punished for family or health reasons; "can't make it" should be a graceful option with a mild, honest consequence, not a hidden penalty.

## LabRat Nerds: the community forum and IRC channel (2013 culture)
The LabTech community (LabTech Geek: a forum plus an IRC channel) was where techs learned and asked for help in real time. Ours is **LabRat Nerds**. It plays mostly into the tech campaign: more training, and a *call a friend* lifeline.

- **Forum (learning):** each day a handful of threads (print spooler on Server 2008 R2, locked-out accounts, CryptoLocker shadow copies, robocopy with permissions, VLANs on a cheap switch, stopping RDP brute force, Windows XP migration checklists).
  Reading a thread gives a little skill XP; *answering* one (needs the skill level) gives more XP and **karma**. Karma ranks you LURKER, MEMBER, REGULAR, GURU.
- **IRC (call a friend):** `#labratnerds` with a cast of nicks of different reliability: `rodent_rick` (calm, mostly right), `gnawer`, `PS_wizard` (great at scripts), `old_hand` (right but slow), `xX_n00b_Xx` (often wrong) and `trollbot` (jokes).
  **Ask the channel**: pick an open ticket (which fix?) or the current job step (what next?). Four nicks answer one by one over a few seconds, you see the votes and a confidence ("3 of 4 agree"). Accuracy rises with your karma, and the troll can lead you astray, so you still have to judge.
  The lifeline has a cooldown and costs a little karma each time; lurkers who only ask get ignored. Contributing on the forum is how you earn the right to ask.
- **The tradeoff:** the help is free but not free of risk (a wrong consensus is a real mistake), and leaning on it skips the learning (less XP from that ticket), so it is a lifeline, not a crutch.
- **Later ideas:** community scripts you can download that unlock a one-off fix (with a risk they are buggy); a meetup / conference (the real community had them) as an outing; being quoted in a thread when you solve something hard; owner campaign: encourage the crew to take part (training for free) or worry about them leaking client details; a rival forum with worse advice.
- **Period check:** forums and IRC are very 2013. No Slack, no Discord, no Teams.

## Lync 2013 on the desktop
Presence (available, away, in a meeting, with a client) and instant messages between coworkers; the friendly ones warn you before an SLA breaches; lunch invites and "can you cover my phones" come in as short chats; Morgan or Marge for advice. See `CLAUDE.md` for what is built.

## Hour management: commute, being late, the phone queue, staying late, on-call
**Built** (see `CLAUDE.md`, "Hour management"): energy, the commute and being late, the on-call pager, staying late, owner hours. The rest of this section is the original design; what is still open is listed under "Status update" below.
A big missing piece of a tech's real day. It is about time, not tickets, and it feeds directly into burnout, mistakes and efficiency.

- **The commute (tech campaign):** a morning decision and a small mini-flow: how early do you leave? Leaving early costs sleep and personal time; leaving late risks traffic (random, weather, an accident), and arriving late means the day starts behind.
  The day clock (`World.clock`) already runs 9:00-17:00; add a pre-day phase (the player's own start time) so being late shows as missed morning tickets, a manager's raised eyebrow (`Morgan`), SLA clocks that already started, and coworkers
  covering for you (an opinion hit or a favour). Different commutes per character and per week (a road closure, a snowy morning).
- **The phone queue:** some days (or shifts) you are the one on the phones; being late or away means a queue builds, calls abandon, a client escalates (hooks into `Msp.phone_call`, Vic's complaints, client mood). Rotating who covers the queue
  becomes a small negotiation with coworkers (`Social`).
- **Staying late:** the end-of-day choice you already half have (the email-night overtime): leave on time and leave the ticket for tomorrow (SLA clock keeps running), or stay and finish it. Staying late pays (overtime) but costs sleep and
  next-day efficiency; doing it repeatedly raises burnout. Optional: pay vs comp time vs "unpaid because the owner expects it" (a culture signal).
- **On call:** a weekly rota: some weeks you carry the pager. Calls at night (a real wake-up, a short remote fix, a "can it wait until morning" judgement call) cost sleep. The after-hours fee and stipend ideas from the research already
  fit here (owner side decides the policy; tech side lives it). A rotation that is unfair (the same person every week) is a story and a quit risk.
- **A fatigue / sleep model that touches everything:** sleep debt from a late night, a short commute margin, on-call wake-ups and long days feeds a **fatigue** stat. Fatigue slows fixes (the RMM jobs take longer, `Skills.fix_secs`), raises the chance a fix
  "does not stick" (`Skills.fail_chance`), makes **mistakes** (wrong server restarted, a deleted file, a missed backup check, a reopened ticket), and wears down coworker mood. Rested players get small bonuses.
- **Owner campaign side:** burnout already exists (`Owner.burnout`); this feeds it from real hours (overtime weeks, on-call load, late arrivals) and shows the owner the cost: hours worked per tech, who is on call, who is late a lot and why (a hard commute? a
  bad week?), the manager conversation ("a quiet word about punctuality" vs "flex hours") and policy cards (flexible start times, remote days, a four-day-week trial, an on-call stipend, a night rota).
- **Hooks:** `World.clock` and the day loop, `Msp` SLA clocks and the phone queue, `Skills` (speed and reliability), `Social` (covering for each other), `Owner.burnout` and the `after_hours` / stipend cards, `Campaign` day report (hours worked, sleep, late arrivals).
- **UI sketch:** a small morning card ("Alarm at 6:30 / 7:15 / 8:00") and an end-of-day card ("Go home / stay 1 hour / stay late"), and a tiny "energy" bar in the HUD. Keep the choices quick (one tap), the consequences visible in the day report.
- **Tone:** be honest about how real techs live (traffic, kids, the 2 a.m. page) without being preachy; a good day should feel good.

## From the MSP research (see `docs/msp-research.md` for sources and links)

Tags: **[gap]** the game has nothing like it, **[deepen]** a piece exists and could go further, **[KB]** from the MSP Knowledge Base, **[hunch]** my idea, not from the research,
**[validate]** needs a real MSP owner to confirm before it appears in player-facing text. Reddit itself was not reachable; sources are trade press, blogs and the Knowledge Base.

### Built since (July pass, see CLAUDE.md)
- **Client profitability and scope creep, with projects and services** (owner): hours per client in the Boardroom, change orders, firing a client with word-of-mouth consequences, project quotes (fixed, scope first, time and materials), managed backup / patching as recurring revenue.
- **Rodent Nation 2014** (tech, day 17): the KPI-gated conference trip with a resort venue, session picks, a vendor hall with badge-scan spam, forum regulars as attendees.
- **Onsite visits** (tech): onsite tickets, a front-door "where to" menu, drive times with traffic, six client site types (two looks each), the client's own PC, mishaps, a printer mini-game.
- **People and props:** eleven new women characters plus 14 more for client staff, ducking, a rubber duck, the sales bell, the petting zoo at the vet.
- **Maya** (Tier 1 tech) is a real coworker at main floor desk 2 in the tech campaign and Free Play, and on the crew in the owner campaign (talk, tips, Lync, opinions, all-hands, outings).
- *Still open from this pass:* walking the owner-campaign Rodent Nation trip in the venue; sitting in the conference sessions; more onsite jobs and onsite projects.

### Status: what from this list is built (owner campaign), what is still open
Built in the owner campaign (see `CLAUDE.md`, "Owner campaign, third pass"):
- **1 client profitability / scope creep / firing a client**: heavy clients (Gnarly Gnomes, Zen Garden) generate twice the tickets, per-client cost vs fee, a profit column, a profit-review card every four weeks (raise the fee, enforce scope, fire, eat it).
- **2 burnout + after-hours fee** (owner side): a burnout meter that slows the crew and makes techs quit; week-12 card (after-hours fee / stipend / neither). *Still open: the tech-campaign pager.*
- **3 vendor breach** (owner side): week 14, odds scale with the RMM you chose. *Still open: the tech-campaign night.*
- **4 "the client said no"** (owner side): week 6 two-factor refusal -> waiver / insist / ignore, then the week-16 breach pays off the choice. *Still open: tech-campaign version.*
- **5 billing leakage**: a silent 6% leak from week 3, a billing audit card (weeks 5 and 11).
- **6 sales-to-service handover** (the first-90-days churn window itself is still open).
- **17 maturity level badge**: counted from real habits, shown in the Boardroom, +0.5 valuation multiple at level 4+.
- **27b accountability goal**: the peer group sets and checks a goal each quarter (weeks 5, 11, 17).
Still open from the top of the list: 9 revenue mix, 10 post-incident review, 19-26 pricing models and stack categories, and the peer-group meeting overhaul (33-38). Documentation and bus factor (7), business email compromise / wire fraud (8) and desk design (18) are built in the tech, owner and service campaigns.

### Status update: built in the 2013-14 pass
Also built now (see `CLAUDE.md`, "2013-14 realism pass"): the day-4 **Windows XP end-of-support** story; **RDP open to the internet** (tech playbook and owner card, auto-blocking firewall as a real fix); **CryptoLocker options** with and without a backup
(restore, pay, shadow copies); **competitor poaching** (gaps vs the rarer price-only poach, patch debt, winback with a price rise, health check); **Lync 2013** on the desktop; **LabRat Nerds** (forum plus the IRC call-a-friend poll).
Built after that: **hour management** (energy, the morning commute and being late, the on-call pager, staying late, owner on-call and flexible-hours cards) and the **Tier 1 to Tier 2 growth plan** with the owner-hours resource (see `CLAUDE.md`).
Still open from the hour-management idea: the phone-queue shift rotation, comp time vs unpaid overtime, different commutes per character, remote days as a mechanic, coffee/lunch restoring energy, kids/sick-day events.
Still open: the tech-campaign vendor breach night; the LabRat Nerds later ideas (community scripts, meetups); revenue mix.

### Gaps (build these first)
1. **[gap]** Client profitability and scope creep: hours per client vs fee, unbilled "quick requests", change orders, auditing a new client's tickets weekly, turning recurring one-offs into billable services.
   Owner decisions: raise the fee, enforce scope, or *fire the client*, with the real fear of bad word of mouth. The Boardroom CLIENTS tab gets a profit column. Unprofitable contracts often go unnoticed for months.
2. **[gap]** After-hours and on-call burnout: a pager in the tech campaign that keeps ringing; fair rotation, stipends and comp time; service desk and L2 as the burnout hot spot. Owner card: an after-hours fee
   (a $250/hour fee stopped 80-90% of non-critical calls in one owner's story) and a burnout meter that drives quitting.
3. **[gap]** Vendor breach, Kaseya-style (a 2021 story that used an RMM auto-update to hit 50-60 MSPs and 1,500-2,000 of their customers; **too modern for 2013-14, so use a period equivalent**: the late-2013 Target breach came in through a contractor's remote access, or a compromised remote-support tool): the tech campaign is a night of triage and client comms, the owner campaign is a communications,
   liability and insurance decision. RMM stack choice carries a security trade-off; treat RMM and remote-access tools as crown jewels (two-factor login, least privilege, a communications plan written in advance).
4. **[gap]** "The client said no": a client declines two-factor login or managed antivirus; sign the risk-acceptance waiver or not (without a signed refusal it is your word against theirs); contract clauses that make the client responsible for
   recommended controls; later they are breached and the paper trail decides the blame; insurers can deny a claim if the controls were missing. (A May 2026 r/msp thread on whether waivers really protect you exists; not read.)
5. **[gap]** Billing leakage: a hidden monthly leak (unbilled hours, vendor price rises never passed through, licence renewal price rises nobody re-billed (Office, Windows Server and antivirus renewals), seat changes) that a *billing audit* decision uncovers;
   ties directly to EBITDA and the W-2 ratio. Vendor estimates put leakage at 5-12% of revenue (vendors sell billing tools; treat as directional).
6. **[gap]** First 90 days: new clients have a churn-risk window (churn is most likely early, often from sales promises vs delivery); a sales-to-service handover review card (Vic and the lead tech) before onboarding, one
   named owner for onboarding, SLAs that match what the team can really do. Onboarding as a project (discovery, documentation, agent rollout) with a real score.
7. **[gap]** Documentation and bus factor: techs have a knowledge stat; when a senior tech leaves, resolution times rise for weeks and a credential-rotation project appears (only the passwords they knew, if you documented
   which). Documentation tool in the stack; "write it up" as a post-job step; the tech who knows everything and writes nothing.
8. **[BUILT, R37]** Business email compromise / wire fraud at a client: the victim sues the MSP (negligence, breach of contract), courts may split the fault, callback verification on payment changes, and the insurance wording
   (cyber vs crime, client's policy vs yours). Both campaigns.
9. **[gap]** Revenue mix as a driver: recurring vs projects vs hardware vs managed security (managed services run ~50%+ gross margin, hardware resale ~20-30% in one source) feeding the valuation multiple; a
   managed-security service line you can add (and the incidents it prevents).
10. **[BUILT, R37]** Post-incident review: after any incident (ransomware, rack, email outage, vendor breach) a review card; the lessons you write up reduce the next incident's cost; skipping it repeats the mistake.

### Deepen what we have
11. **[deepen]** Late payers: late fees (about 1.5% a month in sample clauses), suspension only after written notice (about 5 business days), escalation around day 21 / 30 / 35, a reactivation fee equal to a month,
    a DSO (days sales outstanding) number in the Boardroom, an auto-pay discount, "paying out of pocket while they ride for free" for low-margin delinquent clients, suspension that conflicts with a regulated client.
12. **[deepen]** Price changes: a one-time pricing card today; add an annual escalator clause (about 5-7%, 60 days' notice), a price-increase campaign graded by client price sensitivity (low-usage clients smaller,
    high-usage larger), choice of packages, and the finding that churn fear is often overstated; offer smaller, more frequent rises vs a big one.
13. **[deepen]** Sales over-promising: first-90-days churn window (see 6), realistic SLAs that Vic *quotes* (a commission rep promises shorter SLAs, so new clients start with tighter SLA clocks), "yes, we can" on services
    you cannot deliver.
14. **[deepen]** Projects: time tracking per project, change orders, specific tasks so out-of-scope requests are obvious; some MSP projects run several times over budget. The fixed-price migration and the "scope first" peer card
    already cover the basic shape.
15. **[deepen]** Backups: not just "check them" but verify a *restore* (a restore test as a recurring chore), check the restore point predates the compromise, and know which client backups survived before promising a timeline.
16. **[deepen]** Hiring and retention: specialists vs cross-trained generalists, training spend and certifications, two weeks' notice and a handover checklist, a "lessons learned" template for workarounds.

### From the MSP Knowledge Base (docs.themspkb.com)
17. **[KB]** Operational Maturity Level badge: Beginning, Emerging, Scaling, Optimizing, Innovating. Moves with real behaviours (time tracking, pricing, budgets, aligned incentive pay, forecasting, analytics);
    higher levels unlock card options and cap the cheap-mistake events. A better progress frame than cash.
18. **[KB]** Service desk design as an owner decision: tiered vs swarming vs dedicated pods vs a shared desk; with or without a **dispatcher**; with or without formal **SLAs** (higher maturity goes with dispatchers and SLAs).
    Without a dispatcher: flexible, but misallocation and SLA breaches. Pods: deep client knowledge, higher cost.
19. **[KB]** Pricing model as the first decision: break/fix (volatile, an MSP with only this is not really an MSP), subscription, tiered service, value-based pricing (risky, lucrative).
20. **[KB]** Revenue streams as a panel: recurring, projects, consulting (assessments, roadmaps), vendor commissions, value-added reselling, professional services, managed security, training (workshops for clients).
21. **[KB]** More stack categories: documentation (IT Glue / Hudu style), security (managed antivirus / endpoint protection, spam filtering), backup and DR, network monitoring, security awareness training; the choosing criteria (integration, features, scalability,
    ease of use, total cost). We model PSA, RMM and hardware only.
22. **[KB]** Peer-group risk: the *echo chamber*. A peer card where the group's popular advice is wrong for your numbers (everyone says raise prices, your clients are already unhappy); reward players who check the books.
23. **[KB]** Vendor relationships: co-selling, **MDF** (market development funds), vendor programs and channel practices; a marketing budget partly funded by a vendor if you hit a co-sell target, tying the stack to money.
24. **[KB]** Compliance as shared responsibility: the MSP defines what the client must do, offers assessments and audits, tells clients when rules change (HIPAA, PCI). A compliance assessment as a billable service and a
    way a client discovers they were not compliant.
25. **[KB]** Incident response plan stages as a mini-game structure: identify, roles, communicate and escalate, contain, recover, post-incident review (see 10).
27. **[KB]** Roles and departments: dispatcher, project manager, automation engineer, integration specialist, security specialist, cloud specialist, on-site engineer: a roster for owner-campaign hires beyond "tech".

### More from the Knowledge Base (second pass, no numbers needed)
27a. **[KB]** Peer-group cadence and shape: IT Nation Evolve-style groups are 10-12 non-competing MSPs with quarterly reviews. Make the meetings quarterly (weeks 5, 9, 13, 17) and name the group size; other real
     groups to draw flavour from: ASCII Group (conferences), SMBiT (monthly chapters, vendor discounts and insurance access), MSP-Ignite (advisor-led, twice a year), The Tech Tribe (paid, in-person meetups).
27b. **[KB]** Accountability group: members set SMART goals (specific, measurable, achievable, relevant, time-bound), share them, report progress each meeting; peers give feedback. Game: each quarter you set a goal
     (e.g. "W-2 ratio under X", "no SLA misses in a month", "collect all A/R") and the group checks it; hitting goals pays off in reputation, missing them costs the group's respect. Works without any benchmark numbers.
27c. **[KB]** The three success factors beyond maturity: collaborative networking (chat communities, partnerships), digital presence and branding (LinkedIn, thought leadership, targeted marketing), and commitment to learning and
     innovation (industry trends, employee development). Game: marketing channels (LinkedIn / thought leadership vs events vs email) with different lead quality, a training budget, a "go to a conference" decision.
27e. **[KB]** Enterprise tools do not fit MSPs: multi-tenancy, integrations and automation built for the MSP model (the Knowledge Base's "industry evolution" point). Game: a cheap "enterprise" PSA/RMM option that is cheaper but
     lacks multi-tenancy, so costs rise as clients grow.

### Peer groups, the HTG / Evolve way (see the research doc)
33. **[peer]** Join as an application, not a purchase: a revenue/stage gate (Evolve 1 for small MSPs, 2 and 3 later, Service Leadership for profit focus, role-based groups), and the group is *assembled*: 8-12 named non-competing owners
    from other regions who recur as characters in your cards (their problems, their wins). A year in Evolve 2 before Evolve 3.
34. **[peer]** A real quarterly meeting (two days away from the office: the team runs without you, a small cost and a small risk): (a) a benchmarking board of your numbers vs the group ("what good looks like", placeholder numbers until
    we have real ones), (b) share a best practice from last quarter (pick something you actually did), (c) a hot seat: present your biggest problem and the group advises, sometimes conflicting (the echo-chamber risk), (d) set the next
    quarter's goal and be checked on it at the next meeting.
35. **[peer]** The four plans: business, leadership, **life** (an owner burnout / balance meter) and **legacy** (key-person risk, succession, "what if I get hit by a bus", disaster recovery for the business itself).
36. **[peer]** Micro board: 3-4 members who dig into *your* company and find what you cannot see (a deep-dive card that reveals billing leakage, an unprofitable client, a key-person risk).
37. **[peer]** Go-giver economy: help another member (answer their hot seat, lend a tool recommendation) and earn favours back later (a referral, a vendor discount, a hire recommendation); hoarding advice costs you.
38. **[peer]** Between-meeting accountability calls: monthly check-ins that nag you about the goal you set; skipping them costs the group's respect.

### From Dean Trempelas's sessions (sessionize.com/drzoidberg; see the research doc)
Tag **[dean]**. A people-and-process layer: learning, hiring for fit, saying no, onboarding, outsourcing the desk, and a different role.
39. **[dean]** **Certification programs nobody uses.** Owner: a certs / training subscription costs a weekly fee; how much the crew actually uses it depends on culture and rewards (a "learning culture" meter). Unused = wasted money, and techs who
    do not grow get picked off by someone who will teach them (a recruiter card). A reward scheme (study time, bonuses, titles) raises usage and speed. Tech campaign side: certs as a study-between-tickets track beside the PowerShell Academy,
    with a visible payoff (a cert unlocks a service line or a promotion). Do not build a team of "ringers" only: develop the whole bench.
40. **[dean]** **Onboarding without the client's runbook.** A client with no documentation (the old IT guy left, or they will not share it). The player builds *their own* onboarding: a discovery checklist (inventory, credentials, backups,
    firewall, licences), each step reveals hidden problems; a good onboarding produces documentation as an asset and sets the first-90-days mood; a rushed one leaves landmines (the unlabelled server, the shared admin password).
    A tech-campaign playbook and an owner decision (how much to invest per new client).
41. **[dean]** **Social media and the tech's career.** Techs have a public presence (LinkedIn, Twitter, Facebook, YouTube, blogs and forums such as Spiceworks). Upside: a tech who posts brings inbound leads and employer brand (a marketing channel with a human face), and
    makes hiring easier. Risks: a post that leaks a client's name or incident, a recruiter poaching your star. An owner policy card ("encourage it, with guidelines") vs "ban it"; a coworker whose post goes viral (a storyline). The tech's own
    career track: grow a following as a path to a better job (or to leave for one).
42. **[dean]** **Hire for fit, not ringers.** Candidates get a second axis: skill and *fit* (culture, communication, curiosity). The interview is a mini-game: a technical quiz ("tech-checking") reveals skill only; behavioural questions reveal fit.
    Overpaying for a ringer with poor fit hurts team mood (`Social`), raises quit risk and slows the group; a good-fit hire with lower skill grows (the existing green trait) and lifts retention. Ties directly to candidate interviews and the
    bartenders-before-IT-pros angle (hire for people skills) that came up in a search lead (an unread podcast).
43. **[dean]** **Operationalizing No.** A "no" mechanic: decline an out-of-scope escalation, a bad-fit prospect Vic wants to sign, a coworker's favour, a client project that does not fit. Each no costs a little goodwill and gives focus: burnout down,
    profit up, fewer fires. A **focus / niche** choice for the owner (specialise in dental / medical / legal clients): fewer, better clients, compliance packages, higher fees, fewer odd requests; but a smaller market and concentration risk.
    "What are you good at?" as a strategy card with real trade-offs.
44. **[dean]** **A third role: the operator.** He "never owned an MSP" and still took one from $700K to $12M and into a $50M+ roll-up. A campaign as the **operations / service manager**: you do not own the company, you own the *process*: dispatch,
    tiering, runbooks, SLAs, onboarding, hiring, escalations, and you answer to the owner (Morgan-like). Metrics: first response, first-call resolution, SLA, utilisation, tech retention, client mood. Fits the Knowledge Base's maturity ladder and
    the desk-design decision.
45. **[dean]** **Acquisition and integration.** The $700K -> $12M -> acquired into $50M+ arc: an owner-campaign endgame or an operator-campaign midgame: a roll-up buys you (or you buy a smaller MSP): merge tools (PSA/RMM migration), people and culture
    (the acquired team's habits), clients (some leave), with real integration risk. Valuation scale should widen (our placeholder numbers top out far below $12M revenue).
46. **[dean]** **Outsourced 24x7 help desk (his company's model).** Owner decision: outsource tier-0/1 to a US-based 24x7 desk: absorbs routine tickets and after-hours calls (burnout drops, senior techs work projects) for a recurring cost, but handoff
    quality matters: an *escalation bundle* that is complete resolves faster than a vague one (process reward), and you can lose the personal touch (client mood). Metrics to show: first-call response, first-ticket response (target under 30 minutes),
    percentage of frontline tickets resolved (a claimed 75%). Marketing claims, treat as a *gameplay* number set, not a benchmark.
47. **[dean]** **Senior techs stuck on routine tickets** (the tension Helpt sells against): a utilisation view: seniors drowning in password resets lose project time and quit; tiered triage fixes it at a price. Pairs with the desk-design idea.
48. **[dean]** **The process trap** (a podcast lead from the search, not read): the owner whose processes exist only in their head. Story card: a vacation or illness shows what breaks; documenting and delegating is the fix.

### From the Empath MSP blog (training, knowledge, growth; vendor blog, see the research doc)
Tag **[empath]**. Training as a *system* with time, owners and measurable effects.
49. **[empath]** **Grow a Tier 1 into a Tier 2.** The one-page plan as a mechanic: a **gap list** (what nobody in the shop can do: derived from escalations and reopens), pick one skill this month, assign a learner and a *helper who catches mistakes*,
    protect **30 paid minutes a week** (if the queue eats it, training moves into the ticket flow). The measurable result: **escalations drop** and the documented fix can then be handled at Tier 1. Tech campaign: you are the learner (a stretch ticket
    with a senior nearby; a mistake is caught, not punished). Owner campaign: choose who gets stretch work; skipping the protected time is exactly "how a help desk burns out".
50. **[empath]** **Opportunity shortage, not talent shortage.** A "stretch assignment" card: hand a Tier 1 a Tier 2 ticket with someone close enough to catch them. Risk: a visible mistake; payoff: a promotable tech, fewer escalations, a retained hire.
    Hiring only experienced people costs more than developing; some trained staff will leave anyway (a tenure model: median US tenure about 4 years, shorter for young workers; verify before showing it).
51. **[empath]** **The owner as the only Tier 3 (an owner-time resource).** Every hard escalation ends on the owner's desk: a weekly *owner hours* budget that escalations eat; unspent time goes to sales and strategy. Training, SOPs and good hires reduce
    escalations and free hours. When the owner is the bottleneck, nobody else learns the work.
52. **[empath]** **Institutional knowledge, the five steps.** Ticket-data signals (bouncing, repeat escalations, reopens, SLA misses, mis-routes, stale tickets) as a **"knowledge hotspot" view**; "record the senior tech doing it and ask why"; each recording
    becomes an SOP lesson with a short quiz; role paths in order with due dates; a senior **signs off** a new hire on live tickets; each lesson has a named owner and is re-recorded when stale. A "knowledge" stat per tech: documented knowledge cushions a
    departure, undocumented knowledge leaves with them (extends the bus-factor and documentation ideas).
53. **[empath]** **Shadow vs structured onboarding (a decision, not a given).** For each new hire: shadowing (free, slow, inconsistent, the senior's tickets wait, nothing recorded), a structured path (setup cost and time, consistent, tracked, a readiness
    sign-off), or a bought course library. Shadowing stays for live-ticket judgement, after the path. Never show a made-up savings number; show *what happened* (time to first solo ticket, reopens in the first month).
54. **[empath]** **Time to productive depends on the task.** A new hire can be productive on simple tasks in days and on hard ones in many months (the Geek Squad register vs virus removal example). Ticket classes with a learning curve per hire; assign
    by class; the gap list says which classes nobody can take.
55. **[empath]** **Training tickets in the PSA.** Assigned courses create weekly *training tickets* that compete with client work in the queue: the exact tension between protected time and the queue, visible in the game's own ticket list.
56. **[empath]** **Sell training to clients (a revenue stream).** A paid add-on or bundled: Microsoft Office 2013 / Office 365, Outlook, SharePoint, Lync, spotting phishing and bad attachments, security habits, data handling and the compliance topics HR asks about. Repeat "how do I" tickets mark a
    **training gap**: a client who gets training sends fewer tickets (and costs less to serve), and the **QBR** card shows completion and drives renewal or an upsell. Pairs with the revenue-streams and scope-creep ideas and the maturity badge.
57. **[empath]** **A training price list for the owner's budget** (published, vendor-stated prices; verify): about $30 per user per month for an MSP-specific library, $360-$700 per user per year for general libraries and certification labs, free vendor
    universities for entry content. Use these as realistic costs on the "certs nobody uses" and training cards (item 39) instead of invented ones.
59. **[empath]** **Automation that closes the loop.** An event (a reopen, an escalation, a missed SLA) can automatically create a coaching task and a record: a maturity-ladder feature (automation) and a stack option, with its own cost and failure mode.

### Unsourced hunches (mine; verify before treating as realistic)
28. **[hunch]** A Patch-Tuesday update that breaks printing; the client's nephew who "set up the Wi-Fi"; Windows XP and Office 2003 end of support (April 8, 2014) as a seasonal project wave; a spammy phishing email going round the office as coworker small talk; a licence audit
    letter from a software vendor; a client's office move; "can you just look at my home printer".

### Validate before shipping
29. **[validate]** (the Knowledge Base has NO financial benchmarks; the figures below are placeholders from lower-trust vendor and consultant sources until you supply trusted numbers) The W-2 ratio target (55%) and what counts as W-2 (payroll including sales and management vs delivery labor only; one source puts delivery labor at 30-45% of revenue). Our EBITDA peer margin (15%) is at
    the low end of the cited "good" range (about 15-25%, an average near 18%, top quartile above 22%).
30. **[validate]** Valuation multiples (we use 2.0-7.0x annual EBITDA with adjustments); the pages on MSP valuation exist but were not read.
31. **[validate]** The after-hours fee story, the late-fee percentages and escalation days, the 5-12% billing leakage figure and every turnover statistic: all come from vendor or consultant material.
32. **[validate]** Ask a real MSP owner to read the card text and the P&L lines for realism and tone before any player-facing release.

## Difficulty and seeds (built; see CLAUDE.md "Difficulty and seeds")
- Exists: a `Difficulty` autoload with an easy / normal / hard tier (chosen with Up / Down on the character select screen, remembered in `user://mspsim_settings.cfg`, saved with the campaign together with the run seed; old saves load as normal), one seeded random stream per system (`Difficulty.rng("karaoke")`, `seed_run(n)` for tests), and a single table of numbers for printer, karaoke, bowling, escape room, dinner and the nerf war. Normal equals the old behaviour.
- Left: a `level()` that also mixes progress and skill (the tier alone is used). Everything else from roadmap items 2-10 is built.

## Clients who know your name (R36, user idea, Nov 2026)
- **Direct texts.** Once a client's contact trusts you (high satisfaction, you fixed their big problem), they start texting your cell instead of calling the desk: "quick question, printer again?" It is work that never enters ConnectWhy: no ticket, no SLA, no credit. Options per text: do it now and log a ticket later (credit and a little risk), tell them to call the desk (their mood dips a little, Morgan is pleased), or ignore it until morning. Late-night texts cost energy. Too many and Morgan raises the policy question in a 1:1. Owner campaign: it is unbilled work and a key-person risk.
- **Asked for by name.** A client says "can the new guy do this one?". The ticket arrives pre-assigned to you with a client-mood bonus on success and a bigger penalty on failure. A pile-up burns you out; a coworker may grumble; Vic uses it in a pitch. Owner campaign: a client follows a tech who leaves (non-solicit card); service manager: your techs get requested and the crew gets lopsided.
- Needs a design pass before a build; see ROADMAP R36.
