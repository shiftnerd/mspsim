# MSPSim: game guide and pitch bible

*A readable overview of the game for anyone who wants to review the story and design. No code needed. Line-by-line text is in
`godot/story/STORY.md` (generated, read-only) and can be changed in `godot/story/strings.txt` (plain text). See `godot/story/README.md`.*

*Looking for how to play, not the story? The spoiler-free [instruction manual](manual/README.md) covers the controls, menus and places.*

---

## 1. The pitch

**MSPSim is a cartoon pixel-art office sim about working at a managed service provider (an "MSP") in 2013-14.**
You are the person who keeps other companies' computers alive: the dentist whose X-ray software disappeared, the law firm hit by
CryptoLocker, the brewery whose email server dies at midnight. Between tickets you get coffee, argue about the thermostat, answer the phone,
and (because it is that kind of office) have nerf gun fights.

Think *Papers, Please* crossed with *Overcooked*, set in a tiny, grimy, very funny office that is secretly a pressure cooker.
The jokes come from real MSP life; the stakes come from real MSP life too (a backup you forgot to check, a firewall that is wide open).

**Several ways to play, one office:**
- **Tech campaign** (the main game): 20 working days as a service-desk tech. Close tickets, fix things remotely, learn PowerShell,
  keep your coworkers and clients happy, survive the big jobs, and decide your future at the yearly review.
- **Owner campaign**: 20 weeks as the owner of the company. Pricing, hiring, tools, marketing, collections, a competitor poaching your clients,
  and a valuation at the end.
- **Service manager campaign** (you are Dan): run the service desk crew, the Dispatch board, runbooks and the owners' pressure.
- **Sales campaign** (you are Vic): leads, quotes, deals, handovers and keeping clients.
- **Free Play / Film Mode**: the office as a sandbox with no scoring, for filming scenes, wandering around and playing dress-up.
- **Career and Year 2**: medals and records follow you across runs; finish a campaign and a harder second year opens up.

**Why it should be fun:** the work is a real puzzle with real consequences, the people are specific and funny, and the world is full of things
to poke (a coffee machine, a rack of network cables you can unplug, a foam dart gun).

---

## 2. Tone and setting

- **Year:** 2013 into spring 2014. **Windows XP support ends April 8, 2014** and everyone is panicking about it. CryptoLocker is the new scary thing.
  RDP is open to the internet at half of all small businesses, and most attacks are just password guessing. Target's breach is in the news.
  Floppy Bat, Sugar Smash, Lynk, the iFone 5 and Nexxus 5, LabRat and ConnectWhy are the furniture of daily life.
- **Hard rule:** nothing from after 2014. No AI, no Teams or Slack, no Windows 10/11, no "MFA" (say *two-factor login*), no TikTok or Discord.
  Reviewers: please flag any slip.
- **Voice:** warm, dry, a little absurd, never mean. Jargon is used correctly and explained by context. Every character has a way of speaking
  (Alan is the gruff-but-kind technical owner, Garrison is the excitable sales-and-culture owner with a security scare story for everything, Dan is quiet and obsessive about labelling cables, Vic is a salesman who
  over-promises). Emails and texts are short, human and slightly panicked, like real clients.
- **Look:** blocky pixel characters with big heads and flat colours. Rooms are slightly grimy 2010s offices:
  stained ceiling tiles, blue carpet, a green hallway. Outing rooms (bowling, karaoke, escape room, a neighbourhood grill) are dark and neon.
- **Real brands are parodied:** the PSA is **ConnectWhy**, the RMM is **LabRat RMM**, the mail client is **Outlookish 2013**, the community forum is **LabRat Nerds**.

---

## 3. The world

**Pixel IT Partners**: main floor, two offices, a kitchenette (with a fridge and a coffee machine that has opinions) and two restrooms,
a cubicle area, a conference room, a warehouse with a parking lot, and behind the warehouse a network closet with a real rack you can plug and unplug (its patch panel is labelled by Dan, mostly: some tags are missing, faded or wrong, and a toner and probe traces the real cable).
After work you can go bowling, sing karaoke, solve an escape room, eat at the restaurant, play cornhole and have a cookout, or race office chairs. The warehouse also has a dart board you can play any time (a quick round against one or two coworkers, nothing to do with the evening out), and a handful of small things to poke: the vending machine, the chair rack, the parts cage, the bench PC that is always being imaged, the pull chain of the dying light, a radio with three invented stations, a fan and the old tree's lights.

**The people** (canon: **Alan and Garrison are the two owners** of Pixel IT Partners. Alan leans technical, Garrison leans sales and culture; Office 1 and Office 2 are theirs. They are not ticket techs: they talk about payroll, clients, the van, vendors, hiring and the next outing, and in the tech campaign only jump in as a last resort. Morgan manages the floor for them.)
| Who | Role | Personality | What they do for you |
|---|---|---|---|
| **You** | Tech (or owner) | The new hire | |
| **Alan** | Co-owner, the technical one (servers, backups, the stack, the closet; Office 1) | Gruff, patient, a sandwich man. "Not at my desk, please." | Servers; warns you about failing backups ("it is my name on the contract") |
| **Garrison** | Co-owner, the sales and culture one (clients, hiring, morale, outings; Office 2; security-minded as a quirk) | Excitable, loves a good scare story | Security; tells you why Summer2013 is not a password; usually the one who invites you out after work |
| **Dan** | Network tech | Quiet, labels everything, plays Floppy Bat | Networking; notices when a desk has no link |
| **Vic Marlowe** | Account manager | Over-promising salesman with a tie | Brings in clients, relays complaints |
| **Morgan Reyes** | Your manager (reports to the two owners) | Fair, tired, a little dry | Runs the weekly all-hands, reviews you |
| **Marge** | Bookkeeper (owner mode) | Practical | Reads you the numbers |
| **Maya** | Tier 1 tech (tech campaign, owner crew and Free Play) | Friendly, ponytail, always has a granola bar | Customer skills; warns you when a ticket is about to breach; the first woman on the team |

**The clients** (eleven, each with a contact and a personality; eight can be signed at once): Acme Dental Group (Dr. Patel), Brightside Realty, Gnarly Gnomes Landscaping,
Hoot and Holler Law (Atty. Spence), Soggy Bottom Brewing, Piedmont Pediatrics, Rusty Anchor Marine Supply, Zen Garden Yoga, and three newer prospects: Paws and Claws
Veterinary (Dr. Brandt), Lindqvist and Moss Architects, Iron Mule Demolition (an office trailer yard).

**Client sites.** Six of them can be visited: dental, law, vet, architect, realty and the demolition trailers. Each site is several rooms (a front office, the IT closet
with the rack and the server, an owner's office, and exam rooms for dental and vet) and exists in two looks, so a competitor or a prospect can look like a different
business from your client. Medical and vet offices are staffed mostly by women; the competitors have different people. The vet has a dog and a cat, and you can pet both.

---

## 4. The core loop (tech campaign)

1. **A ticket arrives** in the PSA (by email, phone call or monitoring alert). It has a priority and an SLA clock.
2. **You diagnose and fix it** in the RMM: connect to the machine, read the symptom, pick the fix. Wrong fix: nothing changes. Right fix: ticket fixed.
3. **You close it** in the PSA. Closing something that is not really fixed reopens it with an angry email.
4. **The day ends** with a report: tickets closed, SLAs missed, reopened, client mood, coworker opinion, pay, reputation, a grade S to D.
5. **Reputation** carries across days. At zero you are fired. At day 20 you get a review and a choice.

**Things that make it more than a queue**
- **Reboot vs the proper fix.** Rebooting a PC works for some problems but interrupts the user. If you do not ask them to save first, they lose their work and you
  get an angry email. (The print spooler is the classic example.)
- **Backups.** Nightly backups can fail silently. You only know if you check. A failed backup is invisible until ransomware hits.
- **Skills.** PowerShell (lessons in the Academy; faster, more reliable fixes, scripts that fix a whole client) plus Networking, Servers, Security and Customer
  skills that give perks (faster fixes, see whether a user has work open, backups that check themselves).
- **Coworkers.** Everyone has an opinion of you based on how you act: answering their phones, not breaking their network, being friendly, helping.
  Friends cover for you, give tips, teach you things and warn you before an SLA breaks. You can talk to people at their desks.
- **Hours.** You choose when to leave for work (traffic!), whether to stay late, and some weeks you carry the pager. Tired techs make mistakes.
- **LabRat Nerds.** A forum and an IRC channel of other techs: read threads for experience, answer questions for karma, and ask the channel what to do
  (a "call a friend" poll that is mostly right and sometimes trolls you). The channel is also just a place to hang out: chat with the nine regulars about the weekend, the weather and the news of April 2014, overhear their own banter (about the backup that failed, the trip, the day), jump in, and over the days become friends with them. A friend answers your work questions a little better, greets you by name and sooner or later opens up about something real.
- **The big jobs.** Multi-step scenarios with real choices and consequences that come back the next morning (see below).

---

## 5. The 20-day tech story

| Day | What happens | Why it is there |
|---|---|---|
| 1 | Welcome mail. Only one random ticket. Look around. | Learn the controls, explore |
| 2 | Morgan: verify the backups every morning | Plant the backup habit |
| 3 | PowerShell Academy opens; the easy "Adobe Reader will not print" ticket | First real fix |
| 4 | **Windows XP is going away.** Replace Dr. Patel's PC and migrate his stuff (survey, back up, migrate, verify). Lose the X-ray software and he is furious. | A scored, careful job |
| 5 | A client's backup quietly breaks. On-call rota announced. First team outing. | Plant the ransomware |
| 6 | Growth plan with Morgan (pick a skill and a helper). First weekly all-hands. | Progression |
| 7 | **Remote access break-in** at Brightside: RDP open to the internet. Close the door properly (VPN, auto-blocking firewall) or suffer. | Period-correct security |
| 8 | **Wire request from the boss** at the law firm (a spoofed partner email asks for $38,000: read the headers, find the hidden forwarding rule, contain it, have the firm call the bank, leave a call-back rule and two-factor login). Stretch ticket with your helper. | 2013-14 CEO fraud, growth |
| 9 | **CryptoLocker** hits the law firm. With a good backup you are a hero; with none you shop for options (shadow copies, paying, praying). | The payoff of day 5 |
| 10 | **A client's network rack falls off the wall.** Photograph first, remount, recable, verify. | A hands-on crisis |
| 11 | Dr. Patel writes about how the install went; all-hands. **Morgan runs two blameless post-incident reviews** (the wire fraud, the fallen rack): root cause, then up to two action items. Optional; skipping costs 2 with Morgan. | Consequences, learning |
| 12 | **Server migration** at Brightside (check the backups first or the cutover is a disaster). Afternoon: the ransomware review. | A planning job |
| 13 | **24x7 email outage** at the brewery: a long night with a vendor call that runs past midnight | Overtime and endurance |
| 14 | **The client who said no:** Lucy refuses stronger logins. Also, the law firm writes about the ransomware. | Persuasion and consequences |
| 15 | Pager mail; second outing; the email night review | Hours |
| 16 | **Network install** at the law firm (survey, cable, certify, VLANs, Wi-Fi, document it); all-hands | Craft |
| 17 | Growth protected time. Brightside's bookkeeper gets a landlord email with "new bank details": with the wire check from the review she calls back and is grateful, without it she asks you (and may pay a scammer). | The review pays off or does not |
| 18 | Review warning; stretch ticket | Rising pressure |
| 19 | **The only person who knows:** the firewall fix needs Alan, who is out sick. | Documentation and bus factor |
| 20 | Morgan names your roughest job. **Yearly review**: your reputation, your coworkers' quotes, your best client. | The ending |

**The yearly review offers three futures:** become the **team lead** (more pay, a pager, three people who come to you with everything), take an
**in-house IT job** at your best client (calm hours, no nights), or **stay an MSP tech** (same desk, more skill, the tickets keep coming).

---

## 6. The big jobs (playbooks)

Each is a short story with 3 to 6 steps, each with choices. A choice can cost real seconds, game hours, or be locked behind a skill. Good choices score
points; sloppy ones leave consequences that return next morning as follow-up tickets and emails.

- **Windows XP replacement** (day 4)
- **Remote access break-in** (day 7)
- **Ransomware** (day 9)
- **Rack recovery** (day 10)
- **Server migration** (day 12)
- **24x7 email outage** (day 13, runs into the night)
- **Network install** (day 16)
- **Wire request from the boss** (day 8), **The client who said no** (day 14), **The only person who knows** (day 19)
- **Post-incident reviews** (days 11, 12, 15; a card chain, not a playbook): the choices set flags that change later odds (restore tests halve overnight backup failures, a runbook makes fixes safer, a patch policy trims ticket volume, a wire check changes the day 17 email)

*Review question: are the choices interesting? Is there ever an obviously right answer with no tension? Are the consequences funny and fair?*

---

## 7. The owner campaign (20 weeks)

You run the company. Each week is a decision and a P&L. The same story happens to you as decisions: backups, ransomware, the rack, the migration, the email night.

**Systems:** pricing, hiring (candidates with traits), software and hardware stack choices (a cheap PSA that techs hate), marketing, accounts receivable and late payers,
a peer group and a consultant (real advice from other owners), your account manager's pay plan, scope creep, burnout, client business reviews, remote access exposure,
and a rival MSP (ByteBrothers) that poaches clients with gaps (missing backups, missing updates) or, rarely, just a lower price. Clients often come back, and you can raise the price.

**Wire fraud (week 13 on, `Incident`):** a client's bookkeeper forwards a spoofed boss email asking for a wire. Warn every client and start a call-back rule ($350), sell the hosted email filter as a recurring service ($250 setup, $45 a week each, mood-dependent take-up), do both, or ignore it. From then on a weekly roll (about 3.5% per client; policy cuts the hits that get through to a quarter, the filter to a half) either catches a fake request (a toast and a text from Marge) or costs a client real money (at most two a run): credit them 40% and sign them for the filter, hire a lawyer ($600, better odds with the policy on file), ask your insurer (30% pays, 70% with the funds transfer fraud rider the broker offers after the first loss at $30 a week), or tell them it was their own process. Week 15 Marge shows you a "new bank account" email for your own distributor invoice ($2,400). The weekly report shows WIRE FRAUD RISK.

**Lessons learned (weeks 11 and 15, and after a wire loss):** a card per incident class (ransomware, the rack, the email night, wire fraud). Hold it (runbook: half a day of your hours, morale up; or a check: some cash and a small weekly cost) or skip it (morale down, and the same class of incident gets about 15% more likely). A held review is a maturity practice and makes the repeat 40-50% less likely (RDP break-ins and their cost, the vendor breach, wire fraud) or the crew a little faster (the rack).

**The numbers** that matter: EBITDA, the W-2 ratio (payroll vs revenue), client happiness, reputation. Week 20 is a board review with a valuation: sell, open a second office, or stay independent.

---

## 8. Things to poke (the "play" half)

- **Talk to people at their desks** (small talk, ask for help, tips from the live game state, a daily lesson from friends).
- **Instant messages** (Lynk): lunch invites, "cover my phones", help requests.
- **Pull the plug.** Turn the router off and desks lose network, people stop typing and grumble, and Dan walks to the closet. Turn the lights off and someone gets up and turns them back on.
- **The weekly all-hands** (days 6, 11, 16): attend for a briefing and a question, skip it and Morgan notices.
- **Team outings** (Fridays): bowling, karaoke, the escape room (find the code in the room), dinner (learn what each coworker likes). They happen in real rooms with the whole cast.
- **Darts** (any time, at the board in the warehouse): E at the board, pick LET'S PLAY, and one or two coworkers join you for three rounds of three darts. An aim reticle drifts over the board; press E to throw at wherever it is. It settles for a moment and then your arm tires, and every dart has a new sweet spot. Bull 50, treble x3, double x2, highest total wins. It costs about a quarter of an hour on the clock in a campaign and gives a little energy (the first two rounds of a day) and, the first time each day, a little goodwill with the people who played. A bullseye earns the BULLSEYE medal.
- **The warehouse, poked.** The vending machine sells a soda or a bottle of water (now and then it eats your quarter; thump it). The chair rack rolls a chair out for you. The parts cage hides junk and, rarely, something useful. The bench PC reports how far along the image is (press again to restart it, and wait for somebody to notice). The pull chain flickers the high bay light. The radio has three invented stations. The fan spins. E on the old tree toggles its lights, and a bulb pops now and then.
- **Nerf guns.** A rack of blasters on the cubicle wall. Tap Z for a quick shot, hold Z to lob. Hit a friendly coworker and they fire back. Darts stick in monitors and can be picked up.
- **Phone.** iFone 5 or Nexxus 5: mail, tickets, texts, and a PHONE app (contacts and a keypad: call a client to check in on a ticket, apologise for a late one or, when they love you, ask for a referral; chat with a coworker for a little goodwill; order lunch). Calls are text only, take a few minutes of game time and have a cooldown per contact. The phone opens on a lock screen (slide to unlock), and while it is in your pocket a small banner slides in at the top of the screen with a buzz when a text, email, SLA warning or Lynk message arrives.
- **Ducking.** Hold S or Down to duck; coworkers duck too. A rubber duck sits on your desk; press E on it.
- **The sales bell.** Hangs high on the main office wall. Vic rings it when he closes a deal. You cannot reach it, but a foam dart can.
- **The front door.** It is the way to the client sites: a "Where to?" menu with drive times that follow the clock (rush hour, lunch, the evening rush).
  If you are working an onsite ticket, that client is at the top.
- **Onsite visits** (tech campaign). Some tickets cannot be fixed remotely: a dead switch in the closet, a failing server drive, a dead exam room PC, a dental x-ray sensor,
  the boss's tablet. You drive out, walk through the office, and use the client's own computer (their desktop, their software, not yours). Mishaps happen: the vet's dog pees on
  the front desk PC. **Printers** are a small game: clear the jam, load the right paper when the display says PC LOAD LETTER, install the toner, answer the test page; you can
  pray to the sysadmin gods for luck.
- **Rodent Nation 2014** (tech campaign, day 17). A KPI-gated trip to LabRat's user conference in a Florida resort: keynote, three rounds of sessions picked from the real 2014
  agenda, a vendor hall where parody vendors try to sell you things (scan your badge for a raffle ticket and get spammed), forum regulars from LabRat Nerds in person.
- **Client profitability** (owner campaign). The Boardroom shows hours per client, who is over scope, and projects (desktop, network and server upgrades) and services (backup,
  patching) that add recurring and one-time money. Firing a client has real word-of-mouth consequences.

---

## 9. What the player should feel

- **Pressure that is funny, not punishing:** a P1 ticket and a ringing phone at the same time, but you can always see what you could have done.
- **Growth you can feel:** the fixes get faster, new options unlock, coworkers start to trust you.
- **Mastery:** the activities get a little sharper with every good play (2+ stars) of that game, up to 10 plays; the first play of any game is always exactly the chosen level, and the sweet spots in the skill checks move so the rhythm cannot be memorised.
- **Consequences:** the decisions you make early (check the backup! ask the user to save!) pay off or bite on day 9, day 11, day 14.
- **A workplace with people in it:** you can mess around, and the people react.

---

## 10. Review questions

1. **Story:** do the 20 days build? Which beats are strongest, weakest, missing? Which day would you cut or add?
2. **Jobs:** are the choices tense? Are the consequences fair and funny?
3. **Voice:** does each coworker sound like themselves? Are emails and texts believable for a 2013 small-business client?
4. **Period:** anything anachronistic?
5. **Owner campaign:** is the goal clear? Do the early decisions matter at week 20?
6. **Tone:** where are we too mean, too goofy, too dry?
7. **Gaps:** which MSP stories or jokes from your own experience should be in here?

---

## 11. Not built yet (ideas on the list)

Sitting in the Rodent Nation sessions, walking the owner campaign's Rodent Nation trip in the venue, a Friday nerf war event, a vendor-breach storyline for the tech campaign,
pricing models and a revenue-mix story. See `IDEAS.md` for the long list and `docs/ROADMAP.md` for what is queued.
