# Realism review packet (Q7)

For a real MSP owner. About 20 minutes. You do not need to read code or play the game.

**What this is.** MSPSim is a game set in 2013-14 about running (or working in) a small managed services provider (MSP). Every number below is what the game uses today. The "I believe" column is the developer's best guess at reality, with a confidence mark. Where it says **unverified**, nobody has checked it and it may be wrong. Please correct anything, including my guesses.

**How to answer.** Tick one box per row: **Keep** (the game number is fine), **Change** (write your figure in the margin), **Unsure**. If you only have time for ten rows, do the ones marked **(!)**: the developer thinks those are most likely off.

Notes on reading the game's numbers:
- One game week is five working days. In the tech and service campaigns a day is about eight minutes of real time, so "seconds" in the game are compressed. Only the ratios between them matter (see the SLA row).
- Money is in 2014 dollars. A fee of 800 is dollars per client per week.
- "Code" gives the file under `godot/scripts/` and the constant or function, so a developer can change it fast.
- Confidence: **high** = fairly sure. **med** = plausible, from general knowledge. **low** = a guess. **unverified** = no figure known. No row cites a source, because none has been checked.

---

## 1. Owner campaign: the books

| Item | As implemented (code) | I believe | Question | Keep / Change / Unsure |
|---|---|---|---|---|
| (!) W-2 ratio target | Payroll at or under 55% of revenue is "healthy" (`owner.gd` `W2_TARGET` 0.55) | 50-60% is often quoted for an MSP; **low**, unverified | Is 55% the right line for a 5-15 person shop, and does "payroll" include the owner's pay? | [ ] [ ] [ ] |
| (!) EBITDA vs peers | Peer margin 15% (`PEER_MARGIN` 0.15) | Healthy MSPs 10-20%; **low**, unverified | What EBITDA margin do your peers report? Is 15% good-not-great? | [ ] [ ] [ ] |
| (!) Sale multiple | Base 3.25x annual EBITDA; +0.75 if W-2 at or under target; +0.75 if margin at or over 15%; +0.25 each for 6+ clients, rep 70+, high maturity; -2.0 / -1.0 for unhappy clients, -0.5 poor name, -0.5 big A/R. Floor 2.0, practical max 5.5 (`owner.gd` `multiple()`) | Small MSPs sold for roughly 3-5x EBITDA in 2014; **med**, unverified | Are 3-5x and these bumps right for a 5-8 client shop? Does anyone sell on revenue instead? | [ ] [ ] [ ] |
| Quality factor | Price x (0.3 + 0.7 x (rep/100)^1.5): rep 100 = 1.0, rep 50 = 0.55 (`quality()`) | No real equivalent; **n/a** | Is "a poor name cuts the price by up to 70%" too harsh or too soft? | [ ] [ ] [ ] |
| Young-book discount | Valuation x (0.5 + week/24), full price from week 12 (`valuation()`) | Buyers do discount short contract history; **low** | Do buyers care how long the contracts have run? | [ ] [ ] [ ] |
| Weekly fee per client | $800 a week, about $3,470 a month (`FEE` 800) | $100-200 per user per month is common, so $3.5k is ~20-30 users; **med**, unverified | Is a flat per-client fee believable for a 15-30 seat office? | [ ] [ ] [ ] |
| Tech wage | $650 a week (~$34k a year); raises of 5% at week 12, 10% at week 16 (`WAGE`, `wage_mult()`) | 2014 help-desk / tier 2 pay was usually higher, $35-55k; **low**, unverified | Is $34k too low? Does the number include taxes and benefits? | [ ] [ ] [ ] |
| Other payroll | Dan $650, Maya $550, junior Sam $450, manager Morgan $750; salesman Vic $350-750 + $0-300 a deal (`CREW`, `JUNIOR`, `MORGAN_WAGE`, `VIC_PLANS`) | Same caveat; **low** | Same question. Is $750 fair for a manager at this scale? | [ ] [ ] [ ] |
| New-hire ramp | A new hire costs 60% of the wage for 3 weeks (`HIRE_RAMP_WEEKS`) | Usually full pay from day one with a productivity ramp; **low** | Better to pay full wage and show slower work instead? | [ ] [ ] [ ] |
| Overhead | Rent $500 (+$50 at weeks 9 and 14), insurance $80 from week 12, $55 per client past 5 for licences and desks (`RENT`, `SEAT_COST`, `overhead()`) | Plausible; **low**, unverified | Does overhead scale with clients like this? | [ ] [ ] [ ] |
| Owners' draw | None, $300, $600 or $1,000 a week for both owners (`DRAW`) | Owners often take salary plus profit; **low** | Are those draw sizes believable? | [ ] [ ] [ ] |
| (!) A/R and slow payers | Three clients pay 2-3 weeks late (`SLOW_PAYERS`); collections card after 2+ weeks; a buyer docks 0.5x if A/R is over 3 weeks of revenue (`ar_total()`) | Net-30 terms are normal; many small clients pay at 30-45 days; **med** | Are 2-3 weeks late too mild? What share of clients pay late? | [ ] [ ] [ ] |
| Collections options | Firm reminder pays up 55% of the time; payment plan = half now (`_collections()`) | **unverified** | Does a firm reminder really work more than half the time? | [ ] [ ] [ ] |
| (!) Late fees | **Not in the game.** Late payers cost mood and cash timing only | A 1.5% a month late fee in the contract is common; **med**, unverified | Is a late fee worth adding, and do clients ever actually pay it? | [ ] [ ] [ ] |
| (!) Billing leakage | 6% of revenue silently lost from week ~9 (unbilled work, unpassed vendor price rises) until you audit; the fix leaves 1% (`leak`, `leak_start` event) | 3-10% is a figure I have seen quoted; **low**, unverified | Is 6% right? Do most owners find it by audit? | [ ] [ ] [ ] |
| Scope creep | Two clients (2 and 7) send 2x the tickets until you enforce scope (`HEAVY` 2.0) | Plausible; **low** | Is "twice the tickets" a believable size for a problem client? | [ ] [ ] [ ] |
| Change orders | Extra hours x $95 x 4 weeks; accept chance 10-70%, base 22%, higher if the client is happy (`projects.gd` `BILL_RATE` 95, `change_order_odds()`) | $95-150 an hour was typical; **low** | Do clients accept change orders about 1 in 4? | [ ] [ ] [ ] |
| Rate raise | Raise a client's fee 20%: 55% accept, 20% take 10% and resent it, 25% walk (`_profit_review()`) | **unverified** | Is a 25% walk-away rate on a 20% raise sensible? | [ ] [ ] [ ] |
| After-hours fee | $250 an hour; non-critical calls drop 8%, clients -3 mood (`owner.gd` `after_hours` card) | After-hours is commonly 1.5-2x normal, $150-250 an hour; **med**, unverified | Right number? Do most calls really stop? | [ ] [ ] [ ] |
| On-call stipend | $150 a week (or $100 for a rota) (`oncall_policy`, `after_hours` cards) | $25-100 a day or $100-300 a week; **low** | Fair? | [ ] [ ] [ ] |
| (!) Turnover | A "flight risk" hire quits 6% a week; bad tooling (morale at or under -8) adds 8%; at most one of the two starting techs quits; a lone pager carrier quits 5% a week (`TRAITS`, `_staff_week()`, `MAX_LOST`) | MSP tech turnover is often 15-25% a year; **low**, unverified | 6% a week is ~27% a month for that one trait. Believable for a flight risk? | [ ] [ ] [ ] |
| Poaching | A rival MSP (ByteBrothers) calls a client when you have gaps; about 4% a week even when you do everything right (`COMPETITOR`, `_poach_week()`) | **unverified** | How often do competitors really approach your clients? | [ ] [ ] [ ] |
| Advisor (Dana) | $400 a week, can be dismissed (`mentor_offer` card) | Consultants / vCIOs: $150-300 an hour or $1-3k a month; **low** | Is $400 a week high or low for a part-time advisor? | [ ] [ ] [ ] |
| Peer group | $500 to join, $75 a week, gives numbers to compare and warnings (`peer_invite` card) | Peer groups cost $5-20k a year in 2014; **low**, unverified | Is ~$4k a year too cheap? | [ ] [ ] [ ] |
| Tool stack costs | PSA $15 / $60 / $140 a week; RMM $25 / $80 / $180; hardware margin $120 / $200 / $350 a deal (`STACK`) | Per-tech or per-endpoint pricing was typical; **low** | Do these relative prices (cheap, standard, premium) look right? | [ ] [ ] [ ] |
| Rodent Nation trip | $450 a head, or $300 to send a tech; booths: gold RMM $150 + $25 a week, PSA $150, hardware free (`rn_*` cards) | Conference tickets were usually $500-1,500 plus travel; **low** | Is $450 believable? Do vendors really push deals in the hall? | [ ] [ ] [ ] |

## 2. Tech campaign: the tech's week

| Item | As implemented (code) | I believe | Question | Keep / Change / Unsure |
|---|---|---|---|---|
| (!) SLA windows | P1 120 s, P2 200 s, P3 300 s, P4 480 s of game time, ratio 1 : 1.7 : 2.5 : 4 (`msp.gd` `SLA_SECS`) | Real targets are hours: P1 15-60 min response, P2 1-4 h, P3 next business day, P4 2-3 days; **low**, unverified | Real ratios are much wider. Should the game widen them? | [ ] [ ] [ ] |
| On-call pay | $40 per on-call day, two on-call weeks (`shift.gd` `ONCALL_PAY`, `ONCALL_WEEKS`) | $25-100 a day; **low** | Fair for the 2014 market? | [ ] [ ] [ ] |
| Overtime pay | $50 per hour staying late, costs energy (`STAY_PAY`) | Non-exempt staff get 1.5x; exempt techs get none; **med** | Are your techs hourly (time and a half) or salaried (no overtime)? | [ ] [ ] [ ] |
| Per diem | The conference trip pays expenses; there is no separate per diem rate in the game | $50-70 a day in 2014 for meals; **low** | Does your company cover per diem or just receipts? | [ ] [ ] [ ] |
| (!) Reimage time | Reimage takes 7x a simple fix; at a client with a site you can do it in person, and on the hard tier the remote version fails 25% and takes 1.3x (`msp.gd` `ALT_DEFS.reimage`, `tech.heavy_fail`, `tech.heavy_slow`) | A reimage with user data backup was 2-4 hours; **med** | Is "7x a spooler restart" about right? | [ ] [ ] [ ] |
| Quick vs proper fix | Quick workarounds take 0.3-0.6x the time but 35-60% come back 1-2 days later (`ALT_DEFS` `ret`) | **unverified** | Do band-aid fixes really come back this often? | [ ] [ ] [ ] |
| (!) Backup failure | Each client's backup breaks with 8% chance a day, about 80% over a 20-day campaign, until you re-run it (`msp.gd` `new_day()`, a bare 0.08, not a named constant) | Silent backup failures are common but 8% a day per client looks high; **low**, unverified | What share of your clients' nightly backups fail in a week? | [ ] [ ] [ ] |
| Ransom amount | $500 (`owner.gd` `ransom_options`, pay option) | CryptoLocker asked about $300 or 2 BTC with a 72-100 hour deadline; **med**, unverified | Right amount for a small law firm? | [ ] [ ] [ ] |
| (!) Paying works | 70% the key arrives, 30% it never does (`msp.gd` `_ransom_pay()`, `ransom_options` card) | Most CryptoLocker payers did get files back; I believe over 70%; **low**, unverified | Should paying work more often than 70%? | [ ] [ ] [ ] |
| Shadow copies | 40% most files return; free; one try (`_ransom_shadow()`) | CryptoLocker often deleted them but not always; **low** | Fair? | [ ] [ ] [ ] |
| Vendor versions (new) | Ask the cloud-backup vendor for an older version: 50% works, one try; $150 in owner mode, free in tech; 1.5x time (`VENDOR_ODDS`, `RANSOM_MULT.vendor`) | Sync-based backups often overwrite with the encrypted files; some vendors keep versions 30 days; **low**, unverified | Does support rolling back a version really work half the time? | [ ] [ ] [ ] |
| Isolate and rebuild (new) | Always works, but files since the last good copy are gone; tech: 4x time, score -10, rep -4; owner: $1,000, rep -3 (`RANSOM_MULT.rebuild`, `ransom_options`) | This is the usual recommendation; cost is labor and downtime; **med** | Is $1,000 and a day or two of work right for a file server? | [ ] [ ] [ ] |
| (!) Cyber insurance (new) | Half of clients have a policy (`INSURED_SHARE` 0.5); the claim works 65% (`INSURER_ODDS`); $250 deductible in owner mode | Few small businesses had cyber cover in 2014; **low**, unverified | How many small clients had a cyber policy in 2014, and would it pay out for ransomware? | [ ] [ ] [ ] |
| Settlement | After lost data: settle $2,500, or fight (50% win, else $6,000 and rep -8) (`ransom_lost` card) | **unverified** | Plausible law-firm reaction? | [ ] [ ] [ ] |

## 3. Sales campaign

| Item | As implemented (code) | I believe | Question | Keep / Change / Unsure |
|---|---|---|---|---|
| (!) Quota | Standard $9,000 of new monthly recurring revenue by June 30; safe $6,500, stretch $12,000 (`sales_campaign.gd` `QUOTAS`) | $9k of new MRR in a quarter is a very strong quarter for one rep; **low** | Is this quota realistic for one salesperson? | [ ] [ ] [ ] |
| (!) Win chance | Lead quality x 0.8, plus visit +10%, price/discount, extras that match the pain +4%; clamped 5-92% (`deals.gd` `win()`) | Proposal close rates of 20-40% on qualified leads; **low**, unverified | What close rate do you see on qualified proposals? | [ ] [ ] [ ] |
| Discounts | 10% off = +6% win, 20% off = +12%, premium price = -7% (`PRICES`) | **unverified** | Does a 20% discount really swing a deal that much? | [ ] [ ] [ ] |
| Commission plans | Weeks of new fee paid out: salary 1, balanced 2, commission 3; 1.5x after quota (`PLAN_RATE`, `ACCEL`); owner mode pays $0 / $150 / $300 a deal | 1-3 months of MRR as commission is more common; **low** | Fair? | [ ] [ ] [ ] |
| Margins | Managed services margin 50-56% by method; floors of 35 / 42 / 47% (`METHODS`, `FLOORS`) | 40-55% gross margin on managed services; **low** | Right range? | [ ] [ ] [ ] |
| Hardware resale | $120 / $200 / $350 a deal (`STACK.hardware.margin`) | Reseller margin on PCs was typically 5-15%; **low** | On a $900 PC what do you net? | [ ] [ ] [ ] |
| Pricing basis | $150 base + $24 per user per week (`BASE_FEE`, `PER_USER`) | **unverified** | Per-user is usually monthly; is this a sensible weekly equivalent? | [ ] [ ] [ ] |
| Pipeline | Up to 9 open leads; a lead goes cold after 4 weeks; a quote is lost after 3 (`MAX_OPEN`, `COLD_WEEKS`, `QUOTE_WEEKS`) | Sales cycles run 30-90 days; **low** | Right pace? | [ ] [ ] [ ] |

## 4. Service manager campaign

| Item | As implemented (code) | I believe | Question | Keep / Change / Unsure |
|---|---|---|---|---|
| Crew sizing | Starts with 3 techs (Maya, Sam, Terry), up to 6 with hires (`crew.gd` `ROSTER`) | One service desk tech per 75-150 users is typical; **low** | Is a team of three right for this client book? | [ ] [ ] [ ] |
| (!) Utilisation | 60-90% scores best; over 95% means stress and mood drop; under 45% means boredom (`service.gd` `close_day()`, `crew.gd` `end_day()`) | Healthy utilisation about 70-80%; **low** | Right band? | [ ] [ ] [ ] |
| Overload | Three tickets on one desk is overload (`crew.gd` `OVERLOAD_AT` 3) | **unverified** | Does a tech start to drown at 3 open tickets? | [ ] [ ] [ ] |
| Daily grade | SLA 35%, first-contact fix 20%, response speed 15%, backlog 10%, utilisation 10%, morale 10% of the score (`close_day()`) | Service desks watch SLA, first-contact fix, CSAT, backlog; **med** | Right mix of measures? | [ ] [ ] [ ] |
| 1:1s | Talk to each person about weekly, plus owner memos; trust moves by 1-2 (`service.gd` `ONE_ON_ONES`) | Weekly or fortnightly 1:1s are standard; **med** | Right frequency? | [ ] [ ] [ ] |
| Runbooks | Seven ticket runbooks and five job runbooks, written once, go stale when systems change (`RUNBOOKS`) | Runbooks go out of date; **med** | Does "stale after a change" match life? | [ ] [ ] [ ] |
| Escalation | An owner works 1.6x as fast, takes 2 tickets a day and costs trust (`OWNER_RATE`, `OWNER_DAY_CAP`, `OWNER_COST`) | **unverified** | Do owners really take escalations? | [ ] [ ] [ ] |

---

## 5. Period checks: 2013-14 (products, laws, events)

Please confirm each is what a small MSP would have faced in the story's spring of 2014. Tick **OK**, **Wrong** or **Unsure**.

| Item as it appears in the game | OK | Wrong | Unsure |
|---|---|---|---|
| Windows XP support ends April 8, 2014; clients scramble to replace desktops (install project, sales pains) | [ ] | [ ] | [ ] |
| Office 2003 support ends the same date; Outlook 2003 profiles and PSTs are moved | [ ] | [ ] | [ ] |
| Windows 8 / 8.1 complaints (no Start button; the 8.1 update) | [ ] | [ ] | [ ] |
| CryptoLocker ransomware (late 2013 to mid 2014), bitcoin ransom, countdown, sometimes deletes shadow copies | [ ] | [ ] | [ ] |
| Heartbleed (April 2014); clients ask if their servers are affected | [ ] | [ ] | [ ] |
| The Target breach news (Dec 2013) makes clients ask about cyber liability cover | [ ] | [ ] | [ ] |
| RDP open to the internet and brute-force logins as a common break-in | [ ] | [ ] | [ ] |
| Backup to external drives or an online backup service; the nightly job fails silently | [ ] | [ ] | [ ] |
| Dental x-ray software tied to XP; HIPAA worries for dental and vet clients | [ ] | [ ] | [ ] |
| Hosted VOIP replacing analog lines (new project `voip`, $2,200-3,200, 3 weeks) | [ ] | [ ] | [ ] |
| Moving mail from an on-site server to hosted email (new project `email_move`, $1,500-2,400, 2 weeks) | [ ] | [ ] | [ ] |
| Phones: an iPhone 5 style and a Nexus 5 style handset; a "Sugar Smash" style game in the waiting room | [ ] | [ ] | [ ] |
| Vendor user conference in June at a resort (the "Rodent Nation" parody): keynote, vendor hall, breakouts | [ ] | [ ] | [ ] |
| Peer groups of non-competing owners comparing W-2 ratio and EBITDA | [ ] | [ ] | [ ] |
| PSA and RMM as the tools: ticket board plus remote monitoring tree, patching, scripting | [ ] | [ ] | [ ] |

Anything missing that a small MSP in 2013-14 would obviously face? ________________________________

## 6. Parody names

The game never shows real product names on its own screens. If a name sits too close to a real company, or you think a vendor would object, please say so.

| Game name | What it stands in for |
|---|---|
| ConnectWhy PSA | a ticketing / PSA product |
| LabRat RMM, LabRat Gold, LabRat Nerds (forum) | an RMM product and its user forum |
| SnoutTech Basic | a cheap RMM |
| Ticketo Lite, OpsForge Pro | a budget PSA, a premium PSA |
| Hewlitt Packerd, DellightCo Premium, BudgetByte Value | PC makers |
| Outlookish 2013 | an email client |
| Lynk 2013 | a corporate IM / presence client |
| iFone 5, Nexxus 5 | two phones |
| Googol | a search bar |
| RODENT NATION | an RMM vendor's yearly user conference |
| ShadowPoint Backup, WebWoot Security, SoftSwipe PSA | conference vendors |
| ByteBrothers | a rival local MSP |
| MSP Mastermind | a peer group |
| Pixel IT Partners | the player's company |
| Acme Dental, Brightside Realty, Gnarly Gnomes, Hoot and Holler Law, Soggy Bottom Brewing | fictional clients |

Real names kept on purpose as period context that characters only mention (never a screen we draw): Windows 7 / 8.1 / XP, Exchange, Office 2003, Heartbleed, CryptoLocker, PowerShell, Floppy Bat, Sugar Smash.

## 7. Overall

1. The one thing that would make you stop playing because it is wrong: ________________________________
2. Any card text that nobody in the trade would say: ________________________________
3. Reviewer name and date: ________________________________
