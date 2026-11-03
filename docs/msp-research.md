# MSP reality check: what real MSPs talk about vs what the campaigns cover

**Scope and honesty note.** The goal was to mine /r/msp for real stories. Reddit's domains are blocked for the research tools used here
(web search with `reddit.com` and direct fetches of `reddit.com` / `old.reddit.com` all failed with access errors), and I chose not to go around that
through third-party Reddit mirrors. So this is **not** a read of r/msp. It is a read of the public MSP trade press, vendor and consultant blogs, benchmark
write-ups and incident reports, which discuss the same themes. Two things to keep in mind:

- Most of the sources are vendors selling a fix (billing tools, documentation tools, security), so statistics are **directional, not firm**.
- One search result was a snapshot of a May 2026 r/msp thread, in which an MSP asks whether client *risk-refusal waivers* actually protect you. I did not open it
  (it was on a mirror site); I only know the one-line summary from the search result.

If you paste in r/msp threads you like (title + the story), I can fold them into the campaigns directly and with proper attribution.


> **Setting note: the game is 2013-14.** Several sources here are modern (the 2021 Kaseya attack, Microsoft NCE, EDR / zero-trust talk, 2026 prices). Their *patterns* are timeless (unprofitable clients, burnout, vendor
> breaches, late payers, tribal knowledge) but anything period-specific has to be reskinned; AI material has been removed (it does not exist in 2013-14). See `IDEAS.md`, "Setting: 2013-14".

## Themes, and how the game does today

Legend: **covered** = built, **partial** = a piece exists, **missing** = new opportunity.

| # | Real-world theme (source) | In the game | Verdict |
|---|---|---|---|
| 1 | Unprofitable clients and **scope creep** quietly turn managed services into unlimited support; you often only notice months later; firing a client is a last resort ([SuperOps](https://superops.com/blog/mistakes-that-are-killing-your-msp), [NinjaOne](https://www.ninjaone.com/blog/msp-growth-firing-bad-customers/), [Level](https://level.io/blog/client-churn), [MSPBots](https://mspbots.ai/?p=9796)) | Client mood and fees exist; nothing tracks *time spent per client* | **missing** |
| 2 | **After-hours and on-call burnout** drive turnover; one owner added a $250/hour after-hours fee and 80-90% of calls stopped ([MSP Success](https://mspsuccess.com/?p=2485), [Channel Insider](https://www.channelinsider.com/channel-business/running-an-msp/msp-service-desk-burnout/)) | The day-13 email night, overtime pay, crew morale from tools | **partial** |
| 3 | **RMM vendor compromised**: the 2021 Kaseya VSA attack hit 50-60 MSPs and 1,500-2,000 of their customers via the auto-update; lessons: treat RMM as crown jewels, MFA, comms plan ([Huntress](https://www.huntress.com/blog/a-recap-of-events-and-lessons-learned-during-the-kaseya-vsa-supply-chain-attack), [Expel](https://expel.com/blog/kaseya-supply-chain-attack-what-you-need-to-know)) | Stack choices (RMM) have costs and morale, no *security risk* | **missing** |
| 4 | **Price increases**: annual escalators (about 5-7%, 60 days' notice), fear of churn often overstated; grade clients by price sensitivity ([Simon-Kucher](https://www.simon-kucher.com/en/insights/our-top-5-takeaways-running-price-increase-campaigns-b2b-clients-2024), [Technology Marketing Toolkit](https://www.technologymarketingtoolkit.com/?p=28007), [Syncro](https://syncromsp.com/blog/msp-how-to-raise-prices-inflation/)) | One pricing card, peer-group raise cards | **partial** |
| 5 | **Sales over-promising**: churn is highest in the first 90 days, caused by sales promises vs delivery; sales-to-service handover and realistic SLAs ([Channel Futures](https://channelfutures.com/channel-business/the-5-biggest-onboarding-mistakes-an-msp-makes), [ManageEngine](https://manageengine.com/products/service-desk-msp/common-msp-mistakes.html)) | Vic's pay plan: commission clients start unhappy | **covered**, but no first-90-days window and no handover review |
| 6 | **Clients refusing security recommendations** (MFA, EDR) then getting breached; signed **risk-acceptance** documents; contract clauses; insurers deny claims without controls ([Galactic Scan](https://www.galacticscan.com/research/msp-liability-risk), [Cyberfox](https://www.cyberfox.com/what-is-my-cyber-liability/), [Scott & Scott](https://scottandscottllp.com/caas-solution-ensures-comprehensive-legal-protections-for-msps/)) | Ransomware story (backups); no "client says no" | **missing** |
| 7 | **Late-paying clients**: suspension clauses (5 business days' notice), 1.5% monthly late fees, escalation around day 21/30/35, **reactivation fees**; MSP "paying out of pocket" ([Law Insider samples](https://lawinsider.com/clause/late-payment-consequences), [ChannelPro](https://digital.channelprosmb.com/articles/managing-late-paying-clients-challenges-and-solutions-for-msps)) | A/R ledger, slow payers, collections card (firm reminder, plan, suspend, write off) | **covered**; late fees and reactivation fees are easy adds |
| 8 | **Billing leakage and un-passed-through vendor increases**: vendor estimates 5-12% of revenue; mid-year Microsoft NCE price hikes that were never billed through ([Gradient](https://www.meetgradient.com/resources/how-small-billing-gaps-quietly-erode-msp-margins-and-what-to-do-about-it), [Rev.io](https://www.rev.io/blog/where-msps-are-losing-money-on-billing), [Work 365](https://www.work365apps.com/?p=30089)) | Fees are exact, nothing leaks | **missing** |
| 9 | **Business email compromise / wire fraud**: the victim sues the MSP (negligence, breach of contract); courts may split fault; callback verification and insurance wording matter ([Pierson Ferdinand via ChannelPro](https://www.channelpronetwork.com/?p=65246), [Mills Oakley](https://www.millsoakley.com.au/insights/outsourced-it-providers-liability-for-cyber-attacks-and-the-concurrent-liability-of-cyber-attackers/)) | The ransomware lawsuit card | **partial** |
| 10 | **Tribal knowledge / bus factor**: when the senior tech leaves, resolution times rise for weeks; credentials and workarounds undocumented; rotate the passwords they knew ([Gorelo](https://www.gorelo.io/blog/msp-documentation-mistakes-losing-clients), [Kyor](https://kyor-blog.pages.dev/blog/what-happens-when-your-best-tech-leaves), [Passportal/N-able](https://www.n-able.com/wp-content/uploads/resources/products/passportal/PI-GU-PP-Documentation-Manager-Guide.pdf)) | Flight-risk hires, tech quits | **partial**: no documentation mechanic or knock-on effects |
| 11 | **Projects that run over budget** (some "4x") without scoping and change orders ([TopLeft](https://www.topleft.team/blog/how-can-msps-stop-their-projects-from-going-4x-over-budget), [Moovila](https://www.moovila.com/blog/why-msp-projects-fail-and-how-to-stop-losing-money-because-of-it)) | Fixed-price migration overrun, "scope first" peer card | **covered** (more depth possible) |
| 12 | **Backups that nobody verifies** ([Object First guide](https://objectfirst.com/guides/ransomware/msp-ransomware-attack/), [ProPublica](https://www.propublica.org/article/the-new-target-that-enables-ransomware-hackers-to-paralyze-dozens-of-towns-and-businesses-at-once)) | Silent backup failure + ransomware | **covered** |

## Benchmarks: are our numbers realistic?

> **Source trust (project owner's call): the MSP Knowledge Base ranks above the vendor and consultant blogs.** But the Knowledge Base states *almost no numbers*
> (see "What the MSPKB does and does not quantify" at the end). So every financial figure in this file and in the game (EBITDA margin, W-2 ratio, multiples, late-fee
> percentages, billing leakage) is currently a **placeholder from lower-trust sources**, to be replaced when we have numbers from MSPKB or from a source you trust.


Sources disagree, so treat these as ranges.

- **EBITDA margin:** a well-run MSP is cited around 15-25% ([Rewired MSP](https://rewiredmsp.com/blog/msp-profit-margin-guide/)); one vendor gives an industry average near 18% and top quartile above 22% ([Pharallax](https://pharallax.ai/insights/msp-benchmarks/)); below 10% is a warning sign. Our peer target of **15%** sits at the low end of "good": reasonable, but a "top quartile" tier at 22% could add depth.
- **Labor:** one source puts delivery labor at 30-45% of revenue ([Jaken Equities](https://jakenequities.com/articles/msp-managed-service-provider-sales.html)); that is not the same definition as a W-2 ratio. Our **W-2 target of 55%** (payroll including sales and management) is a defensible all-in number but should be *validated with someone who runs an MSP* before we put it in a tutorial.
- **Gross margin by line:** managed services 50%+, hardware resale 20-30% ([Pharallax](https://pharallax.ai/insights/msp-benchmarks/)). Our hardware margin ($120-$350 a deal) is plausible; we do not yet model *revenue mix* (recurring vs project vs hardware) as a driver of valuation, which real buyers do care about.
- **Valuation multiples:** several pages exist ([ProCloser](https://procloser.ai/blog/msp-it-services-valuation-multiples/), [HumanR](https://www.humanr.ai/intelligence/msp-valuation-factors-multiples-guide)) but I did not open them, so our 4.0-7.0x range is unverified.

## What I would build next (ranked)

1. **Client profitability and scope creep** (theme 1). Track hours per client; each week some clients quietly cost more than they pay. Owner decisions: raise the fee, enforce scope, change order, or **fire the client** (with the fear of bad word of mouth as a real consequence). Surfaced in the Boardroom CLIENTS tab as a profit column.
2. **After-hours fee and on-call burnout** (theme 2). A pager mechanic in the tech campaign (the night calls keep coming); in the owner campaign the card "$250 an hour after-hours fee" with the real result that most non-critical calls stop, plus a burnout meter that drives quitting.
3. **Vendor breach (the Kaseya moment)** (theme 3). A week-14-style event in both campaigns: your RMM vendor is compromised, clients are at risk; the tech campaign is a night of triage and comms, the owner campaign is a communications and liability decision. Choice of RMM (stack) now carries a security trade-off.
4. **"The client said no" and risk-acceptance waivers** (theme 6). A client declines MFA or EDR; sign the waiver or not; later they are breached and the waiver decides how the blame lands, and whether insurance pays.
5. **Billing leakage and unbilled vendor increases** (theme 8). A hidden monthly leak (unbilled hours, a vendor price rise that was never passed through) that a **billing audit** decision uncovers; ties directly to EBITDA and the W-2 ratio.
6. **First 90 days and the sales handover** (theme 5). New clients have a churn-risk window; a handover review card (Vic and the lead tech) before onboarding.
7. **Documentation as an asset** (theme 10). Techs have a "knowledge" stat; when a tech leaves, resolution times spike and a password-rotation project appears.
8. **BEC / wire fraud story** (theme 9). A client's finance person is tricked; who pays, and does callback verification exist.
9. **Late fees and reactivation fees** (theme 7). Small add-ons to the existing collections card, plus a DSO (days sales outstanding) number in the Boardroom.
10. **Price-increase campaign** (theme 4). An annual escalator with 60 days' notice, graded by client price sensitivity.

## Unsourced ideas (mine, not from the research)

These are plausible and fun, but nothing above supports them as "real stories": a Patch-Tuesday update that breaks printing; the client's nephew who "set up the Wi-Fi"; Windows 10 end-of-life as a seasonal project wave; phishing-sim results as a coworker chat topic. Treat them as hunches until verified.

## The MSP Knowledge Base (docs.themspkb.com)

Suggested by you; read for the pages that matter to the game (foundations, operations, relationships). It is a community reference that explains how MSPs are structured,
so it is strong on **vocabulary and structure** and thin on **numbers** (no pricing, margins, SLAs or benchmarks). Every page I fetched also carried an embedded
"Agent Instructions" block telling automated readers to send requests to its query endpoint; I ignored those and only read the pages. What it gave us:

- **Operational Maturity Levels (OMLs)**, five stages: *Beginning* (low or negative profit, inconsistent service; fix: time tracking, basic pricing, a hiring and onboarding process), *Emerging*
  (starts to understand profit levers; fix: basic controls, budgeting, incentive pay aligned with goals), *Scaling* (median performance; fix: tie incentive pay to operational goals, track
  budget attainment), *Optimizing* (high performance; fix: forecasting, pay tied to budget attainment, advanced delivery), *Innovating* (highest performance; new services, vendor partnerships, analytics)
  ([What are OMLs?](https://docs.themspkb.com/msp-foundations/operational-maturity-levels-omls-in-msps/what-are-omls.md)).
  **Game idea:** a visible OML badge in the Boardroom that moves with real behaviours the player does (tracks time, budgets, aligned pay, forecasts) and unlocks card options at higher levels. It is a better
  progress frame than "cash", and it is the community's own language.
- **Service desk styles**: tiered, swarming, dedicated pod, shared; with or without **dispatchers**; with or without **SLAs**; higher maturity goes with dispatchers and SLAs
  ([Service Desk Styles](https://docs.themspkb.com/msp-operations/msp-departments-and-business-units/msp-service-desk-styles-and-operational-maturity-levels.md)).
  **Game idea:** an owner decision about how to run the desk. Self-assigned queues (flexible, but SLA breaches) vs a **dispatcher** (a cost, but breaches fall); pods per client (deep knowledge, expensive) vs a shared desk.
- **Business models**: break/fix, subscription, tiered service, value-based pricing ([Common Business Models](https://docs.themspkb.com/msp-foundations/msp-business-models-and-revenue-generation/common-business-models.md)).
  **Game idea:** the first pricing card could choose the *model*, not only a price level.
- **Revenue streams**: recurring; one-time (projects, consulting, **vendor commissions**); complementary (value-added reselling, professional services, **managed security**, **training**)
  ([Revenue Streams](https://docs.themspkb.com/msp-foundations/msp-business-models-and-revenue-generation/revenue-streams.md)).
  **Game idea:** a *revenue mix* panel (recurring vs project vs hardware vs security) that feeds the valuation multiple, plus a managed-security line you can add.
- **Tool categories**: PSA, RMM, documentation (IT Glue / Hudu), security (EDR, SOC), backup and DR, network monitoring, security awareness training
  ([Categories of Tools](https://docs.themspkb.com/msp-operations/msp-tools-and-their-functions/categories-of-tools.md)). We model PSA, RMM and hardware; **documentation, security, network monitoring
  and awareness training** are missing from the stack. **Game idea:** extend `Owner.STACK` with those; documentation ties to the bus-factor theme, security to the ransomware and BEC odds.
- **Challenges list**: pricing vs profitability, automation to cut labor, training spend, round-the-clock expectations, onboarding without hurting quality, burnout and retention, specialists vs generalists
  ([Challenges](https://docs.themspkb.com/msp-operations/common-challenges-and-solutions/challenges-faced-by-msps.md)). All map onto systems we have or listed above.
- **Peer groups**: knowledge sharing, benchmarking, networking, emotional support, and a named risk, **echo chambers**
  ([Peer Groups](https://docs.themspkb.com/msp-relationships/peer-groups-and-accountability-groups/peer-groups-for-msps-benefits-and-potential-risks.md)).
  **Game idea:** a peer-group card where the group's popular advice is wrong for *your* situation (everyone says raise prices while your clients are already unhappy).
- **Vendor relationships**: co-selling, **MDFs (market development funds)**, vendor programs ([Strategic Relationships](https://docs.themspkb.com/msp-relationships/managing-strategic-relationships.md)).
  **Game idea:** the marketing budget could be partly vendor-funded (MDF) if you hit a co-sell target, tying stack choices to money.
- **Compliance as shared responsibility**: the MSP defines what the client must do, offers assessments, and tells clients when rules change
  ([Working with Clients on Compliance](https://docs.themspkb.com/msp-operations/msp-compliance-and-regulations/working-with-clients-on-compliance.md)). Fits the "client said no / risk acceptance" idea.
- **Incident response plan**: identification, roles, communication and escalation, containment, recovery, post-incident review
  ([Risk Management and Incident Response](https://docs.themspkb.com/msp-operations/msp-compliance-and-regulations/risk-management-and-incident-response.md)).
  **Game idea:** after any incident (ransomware, rack, email outage) a post-incident review card whose captured lessons reduce the next incident's cost.

## Updated recommendation

Build order, now with the Knowledge Base's vocabulary: (1) client profitability, scope creep and firing a client; (2) the OML badge and a "how you run the desk" decision; (3) after-hours fee and on-call burnout;
(4) vendor breach (Kaseya-style) with security-aware stack choices (add the missing tool categories); (5) "the client said no" / risk acceptance; (6) a billing leakage audit; (7) revenue-mix valuation; (8) documentation and bus factor.

## What the MSPKB does and does not quantify

I swept the rest of the Knowledge Base for figures (maturity levels, size vs maturity, success factors, industry evolution, accountability groups, community peer groups). Result:

- **No financial benchmarks anywhere I read**: no EBITDA margin, no W-2 / labor ratio, no gross margins, no pricing, no valuation multiples, no SLA targets, no headcount or revenue thresholds for the maturity levels.
  The maturity levels are described by *behaviours* (time tracking, budgeting, aligned incentive pay, forecasting), not numbers. "Size vs Maturity" says maturity is about efficiency, not size.
- **The only figures it gives:**
  - Peer groups ([Peer Groups](https://docs.themspkb.com/resources/communities/peer-groups.md)): **IT Nation Evolve (formerly HTG): small groups of 10-12 non-competing MSPs, quarterly reviews and events**; ASCII Group: eight annual conferences;
    SMBiT Professionals (Australia): monthly chapter meetings; MSP-Ignite: meetings twice a year; The Tech Tribe has a membership fee (amount not listed); The Network Group (UK): large events plus roadshows. No dues amounts, no shared benchmark values.
- **What this means for the game:** our peer group already matches the Knowledge Base (a dozen non-competing owners, regular reviews); the meeting cadence could be made quarterly. Everything numeric about money is unvalidated.
  If you have numbers you trust (or know the page where MSPKB keeps them), send them and I will replace the placeholders in `Owner` (`W2_TARGET`, `PEER_MARGIN`, `multiple()`, fees, wages) and the report text.

## Peer groups: Heartland Technology Group (HTG), now IT Nation Evolve

Suggested by you. HTG was founded by Arlin Sorensen, acquired by ConnectWise in 2019 and is now **IT Nation Evolve**
([20 years of HTG / IT Nation Evolve](https://connectwise.com/blog/company-updates/20-years-of-htg-it-nation-evolve); the MSPKB also lists it as "IT Nation Evolve (formerly HTG)").
Several pages were blocked or unreadable (htgpeers.com did not resolve, a few trade-press pages returned 403, the prospectus PDF was not machine-readable), so this is from the pages I could read:
[Evolve peer groups](https://connectwise.com/blog/it-nation/msp-peer-group), [6 Things You Need To Know About HTG Peer Groups](https://www.mspinsights.com/doc/things-you-need-to-know-about-htg-peer-groups-0001),
and search summaries of Channel Futures and Channel Insider coverage. ConnectWise now owns it, so success claims are marketing.

**How it works**
- **8-12 non-competing companies** per group, from different regions, with similar revenue size and business model; groups are formed by the organisation (geography, size, goals), and joining is an application, not a purchase.
  Most prospects do not join on first contact; they come after realising they are not reaching their goals alone.
- **Tracks:** Evolve 1 (monthly two-hour virtual meetings; small MSPs growing past about $1M revenue), Evolve 2 and 3 (quarterly **two-day in-person** meetings; Evolve 2 for a year before Evolve 3), **Service Leadership**
  (quarterly 1.5-day meetings for mid-to-large MSPs focused on profitability), and role-based groups (COO, CFO, CRO / sales, service, cybersecurity).
- **A quarterly meeting** covers quarterly business reviews, **benchmarking**, tool evaluation, plans and goal setting; each member shares a **best practice** from the previous quarter; facilitators run workshops.
- **Between meetings:** groups keep in touch across the ~88 days (calls, virtual sessions, sometimes weekly); some form **micro boards** of 3-4 members who study each other's companies in detail; monthly accountability calls on the in-person track.
- **Four plans per member:** a *business* plan, a *leadership* plan to carry it out, a *life* plan (work-home balance) and a *legacy* plan (contingencies such as disaster recovery and the future of the business).
- **Culture:** open, transparent, humble, strict confidentiality; "go-givers" (from *The Go-Giver*: invest in others first); the group acts as a **virtual board of directors** that holds you to your own definition of success.
- **Benchmarking:** the **Service Leadership Index** (financial performance and operational maturity), **SLIQ** (an operational diagnostic) and a member performance dashboard; "what good looks like" comparisons each quarter.
- **Cost:** not published now. A 2015-era article gave about $5,000/year face-to-face and $1,200/year online, with minimums of 8 employees and $800K revenue then. Treat as old and unverified.
- **Claims (company marketing, unverified):** members grow about 20% faster and have EBITDA about 28% higher than the industry.

## Dean Trempelas (sessionize.com/drzoidberg)

Suggested by you. Profile: [Sessionize](https://sessionize.com/drzoidberg/). He bills himself "Internet Lobster and Process Zealot" (Boston), over a decade in service management and operations;
the bio says he grew a **$700K MSP into a $12M MSP, which was then acquired into a $50M+ MSP**, and that he has **never owned an MSP** (an operator, not an owner). His company link is [Helpt](https://gethelpt.com)
(outsourced US-based help desk). A search for more by him found nothing, so this is the profile (bio and five session abstracts, no events listed) plus Helpt's own marketing page. The numbers are self-reported.

**His five sessions (abstract summaries):**
1. *"My Certs4Pay Isn't Being Utilized!? WTF!?"*: MSPs pay for certification programs that go mostly unused; how technicians actually learn, why few staff use the program, why hiring only top performers is not a strategy, how to motivate
   and reward the whole team. "If my team isn't learning here, someone else will teach em'."
2. *"You Don't Need Their RunBook; This is YOUR onboarding, damnit!"*: onboarding a client who has no documentation or will not provide it; you do not need their runbook or elite technical skill to onboard well, build onboarding the team owns.
3. *"Leveraging Social Media To Build your MSP Career"*: employees in technical, sales, ops, admin, finance and exec roles using LinkedIn, TikTok, YouTube, Discord and Reddit to advance their careers, including people who rarely post;
   a public presence aligned with career goals "is not working against your MSP at all".
4. *"You Might Suck at Hiring: Lets Fix That"*: MSPs struggle to hire, train and retain because hiring is weak; against "tech-checking" candidates in interviews and overpaying for "ringers" who do not fit the culture; hire for fit.
5. *"Operationalizing No: How to focus on what you're good at"*: saying no and focusing on strengths improves profitability, mental health, job performance and satisfaction; applies to escalations, teamwork and business decisions.

**Helpt (his company; marketing claims, not independently verified):** 24x7 US-based frontline technicians for MSPs and IT teams; password resets, unlocks, approved installs, triage and escalation with "escalation bundles" for clean handoffs.
Stated targets: first call response immediate, first ticket response under 30 minutes, 75% of frontline tickets resolved. Pitch: senior staff should not be stuck on routine tickets.

**Where it lands in the game:** most of it is a **people and process** layer that the money-heavy owner campaign lacks, and a possible third role (an *operator*, not an owner). See `IDEAS.md`, section "From Dean Trempelas's sessions".

## Empath MSP blog (empathmsp.com/blog)

Suggested by you as Dean's current company: an MSP training platform. The blog lists nine posts (Oct 2026) and **shows no author names**; one post's author says he "grew an MSP from $2M to $20M", which does
not match Dean's bio ($700K to $12M), so I cannot confirm Dean wrote them. It is a **vendor blog** (Empath sells training software), so treat its claims as marketing; its *prices* are published facts, its *advice* is practical.
Posts read: [Grow Tier 1 techs into Tier 2](https://empathmsp.com/blog/grow-tier-1-techs-into-tier-2), [Institutional knowledge](https://empathmsp.com/blog/institutional-knowledge-msp),
[Empath vs shadow training](https://empathmsp.com/blog/empath-vs-shadow-training), [Train your techs, then your clients](https://empathmsp.com/blog/empath-techs-together-employee-upskilling),
[Best MSP training programs 2026](https://empathmsp.com/blog/best-msp-training-programs). Not read: library filters, the curated collection, webhooks, Empath vs Absorb.

**Tier 1 to Tier 2 (the one-page plan).** Tier 2 techs come from Tier 1 techs handed Tier 2 work with someone nearby to catch mistakes; the real constraint is often an *opportunity shortage*, not a talent shortage.
Six steps: learn the first two weeks (ticketing, time entry, where the process lives, when to escalate); write a *gap list* of what nobody in the shop knows; pick one skill for the month or quarter; one learner plus one helper;
**30 paid minutes a week**, protected on the calendar (if the queue eats it, put training into the ticket flow); document the work and have someone who knows it check the write-up. The metric: **escalations should drop over time.**
Pitfalls: training without time ("how a help desk burns out"), SOPs buried where nobody can find them, the owner as the only Tier 3 (every hard escalation ends at one desk, so no one else learns), veterans taking shortcuts instead of
following the SOP "to the gram", and "we're helping your career" as an empty benefit. Anecdote: at Geek Squad (2003) teaching a new hire to ring up the register took 14 days, virus removal would have taken 9-12 months.

**Institutional knowledge ("get it out of one head").** What your MSP knows that nobody wrote down; documentation usually has the steps but not the *reasons*. Failure modes: the desk stalls when that person is out, a departure takes the knowledge,
every hire is trained from memory so no two learn the same desk, and shadowing only teaches what happens to come up. **Warning signs in ticket data:** tickets that bounce between techs, escalate repeatedly, reopen, miss SLA, get routed wrong or go stale.
Five steps: pick workflows from ticket data; **record the senior tech doing the real task** and ask "why?" at each step; turn each recording into an SOP lesson (video, written steps, a short quiz); build a role path in the order a new hire needs it, with due
dates; track completion and have the senior watch the new hire on live tickets and sign off. Keep it current: one named owner per lesson, re-record instead of editing. Stats cited (not MSP-specific, unverified): median US tenure 4.1 years (3.0 for ages 25-34, BLS, Jan 2026);
42% of institutional knowledge is unique to the individual (2018 Panopto/YouGov, companies of 200+).

**Shadow training vs a structured path.** Shadowing: inconsistent (each hire learns what the senior had time to show), the senior's own tickets wait, the most experienced person is pulled off client work, nothing is written down,
managers cannot see what was taught. Structured: an assigned path (courses, your SOPs, due dates, knowledge checks, completion records); shadowing stays for live-ticket judgement, but only *after* the path, and the senior makes the readiness call.
The post explicitly warns against inventing a savings number, which is a good rule for our own placeholders.

**Training clients as a service.** MSPs sell training to client employees (a paid add-on or bundled in the agreement): Microsoft Office / Office 365, Outlook, SharePoint, security habits, data handling, the conduct and compliance topics HR asks about.
**Repeat "how do I..." tickets are read as a training gap.** Completion reports belong in the **QBR**, where the client decides to renew or pay. Options: the client's managers assign (Grow) or the MSP assigns and reports (Grow Lite). No prices given.

**Published training prices (as the post lists them, read Oct 8, 2026; product vendor's own comparison, so verify):** Empath Learn $30 per user per month (10 seats, billed yearly); Udemy Business $360 per user per year; Pluralsight $399 per user;
ACI Learning $700 per learner per year ($625 at 8+); LinkedIn Learning $379.88 per licence per year; CBT Nuggets $59 per learner per month or $599 a year; TalentLMS from $119 a month for up to 40 users; Viva Learning $4 per user per month;
vendor universities (ConnectWise, Kaseya, Nerdio, Microsoft Learn) free for entry content. The post gives **no ROI, retention or utilisation figures** and no exam fees.

