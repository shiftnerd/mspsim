extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# The sales campaign as John (roadmap C1, phase S1; docs/campaign-paths.md section 5). You are the account manager: 20 weeks,
# April to August 2014, 4 real minutes a week. The company runs on autopilot behind you (the crew works the queue, light books);
# you sell. A week has SLOTS selling hours (the clock hours 9:00-17:00): a call or a quote costs an hour, a visit costs the drive
# plus the meeting. Leads arrive as cards from a seeded stream (Difficulty.rng("leads")), live in a small pipeline (the SalesHound
# CRM app, see crm.gd) and are quoted with a method, a promise level and a price; the win chance and the margin come from the
# tables below. Over-promising raises the chance now and becomes a promise gap at the handover (the new client starts unhappier
# and complains later). A won deal lets you ring the sales bell on the main floor wall. Quota is new MRR per quarter, commission
# per deal; week 20 ends in a verdict (sales director / stay / leave / let go).
# Garrison sets the quota and approves big discounts, Alan sets the margin floor (decision cards).
# C3: the story beats of weeks 2-19 (sales_beats.gd, text in BEAT_TEXT below), the endings wired to their flags, the business review at the
# client's office, the team night and the dinner with a prospect, the point-buy stats (Build.sales_fx) and the cash cap.

signal changed

const Deals := preload("res://scripts/deals.gd")
const Retention := preload("res://scripts/retention.gd")
const Handover := preload("res://scripts/handover.gd")
const QuoteBuilder := preload("res://scripts/quote_builder.gd")
const SalesBeats := preload("res://scripts/sales_beats.gd")
const SalesRival := preload("res://scripts/sales_rival.gd")  # R38 P5: incumbent, ASSESS, the quote form, lies
const CASH_CAP := 30000  # the owners draw what the company holds above this: the sales campaign is not about a bank balance
const QBR_TYPE := {2: "realty", 4: "law"}  # book clients with no site of their own meet you in a b skin office of this kind
const SLOTS := 8
const MAX_OPEN := 9  # open leads in the pipeline
const COLD_WEEKS := 4  # a lead nobody touched this long goes cold
const QUOTE_WEEKS := 3  # a quote nobody answers for this long is lost
const BASE_FEE := 150  # weekly managed-services fee: base + per user
const PER_USER := 24
const DISCOVERY := 300  # scope-first discovery fee (the company's cost)
const STAGES := ["LEAD", "MEETING", "QUOTED", "WON", "LOST"]
const TYPE_ORDER := ["dental", "law", "vet", "arch", "realty", "trailer"]
const TIER_QUOTA := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
const QUARTERS := [{"label": "Q2", "from": 1, "to": 12}, {"label": "Q3", "from": 13, "to": 20}]
const Q3_SHARE := 0.8  # the second quota is this share of the first (8 weeks, not 12)
const DEFAULT_QUOTA := "standard"
const QUOTAS := {
	"safe": {"label": "SAFE: $6,500 NEW MRR BY JUNE 30", "target": 6500, "words": "A number we will hit."},
	"standard": {"label": "STANDARD: $9,000 NEW MRR BY JUNE 30", "target": 9000, "words": "What the plan needs."},
	"stretch": {"label": "STRETCH: $12,000 NEW MRR BY JUNE 30", "target": 12000, "words": "Hit it and I will fight for your raise."},
}
# the pay plan reuses the owner campaign's wages (Owner.VIC_PLANS); `rate` = weeks of the new fee paid as commission
const PLAN_RATE := {"salary": 1.0, "balanced": 2.0, "commission": 3.0}
const ACCEL := 1.5  # commission multiplier once the quarter's quota is met
const FLOORS := {
	"loose": {"label": "LOOSE: 35% MARGIN FLOOR", "floor": 0.35},
	"standard": {"label": "STANDARD: 42% MARGIN FLOOR", "floor": 0.42},
	"strict": {"label": "STRICT: 47% MARGIN FLOOR", "floor": 0.47},
}
const DEFAULT_FLOOR := 0.35

# how a quote is sold: win chance bonus, base margin (cost to serve is 1 - base at list price), hours it takes, and what happens to the fee
const METHODS := {
	"fixed": {"label": "FIXED PRICE: ONE FLAT FEE", "win": 0.02, "base": 0.50, "hours": 1, "mrr": 1.0, "gap": 0.0},
	"scope": {"label": "SCOPE IT FIRST ($300 DISCOVERY, 2 HOURS)", "win": -0.03, "base": 0.56, "hours": 2, "mrr": 1.0, "gap": -1.0},
	"tm": {"label": "TIME AND MATERIALS: THEY PAY BY THE HOUR", "win": -0.06, "base": 0.52, "hours": 1, "mrr": 0.7, "gap": 0.0},
}
# how much you promise: win chance bonus and promise points (compared with what the crew can really take on)
const PROMISES := {
	"low": {"label": "ONLY WHAT THE CONTRACT SAYS", "win": 0.0, "pts": 1.0},
	"std": {"label": "NEXT-DAY FIXES, 4 HOUR RESPONSE", "win": 0.03, "pts": 2.0},
	"high": {"label": "1 HOUR RESPONSE, ANY TIME, ANY PROBLEM", "win": 0.14, "pts": 4.0},
}
const PRICES := {
	"premium": {"label": "PREMIUM: 10% ABOVE LIST", "win": -0.07, "mult": 1.10},
	"list": {"label": "LIST PRICE", "win": 0.0, "mult": 1.0},
	"d10": {"label": "10% OFF", "win": 0.06, "mult": 0.90},
	"d20": {"label": "20% OFF (GARRISON SIGNS OFF)", "win": 0.12, "mult": 0.80},
}
const TYPES := {
	"dental":
	{
		"label": "DENTAL",
		"names": ["Maple Street Dentistry", "Riverbend Family Dental", "Dr. Osei Orthodontics", "Harbor Smiles Dental"],
		"who": ["Dr. Reyes", "Dr. Osei", "Dr. Lindgren"],
		"pains": ["XP desktops before April 8", "x-ray software keeps freezing", "no backup of patient files", "nervous about HIPAA"],
	},
	"law":
	{
		"label": "LAW",
		"names": ["Calloway and Finch LLP", "Dunmore Legal Group", "Ridge Road Law Office", "Pruitt Estate Law"],
		"who": ["Atty. Calloway", "Atty. Pruitt", "Ms. Dunmore"],
		"pains": ["email goes down every week", "still on Windows XP", "client files with no backup", "a partner's laptop was stolen"],
	},
	"vet":
	{
		"label": "VET",
		"names": ["Cedar Hollow Animal Clinic", "Four Paws Veterinary", "Lakeside Pet Hospital", "Dr. Amara's Vet Care"],
		"who": ["Dr. Amara", "Dr. Whitt", "Dr. Santos"],
		"pains": ["the records PC is dying", "wifi in the kennels is a joke", "the server beeps and nobody knows why", "a printer that jams every morning"],
	},
	"arch":
	{
		"label": "ARCHITECT",
		"names": ["Keller and Voss Design", "Studio Fernhill", "Oak Park Drafting", "Tarn and Lowe Architects"],
		"who": ["Ms. Keller", "Mr. Voss", "Ms. Lowe"],
		"pains": ["the plotter eats rolls", "CAD files crawl on the server", "no backup of the drawings", "XP workstations on the CAD floor"],
	},
	"realty":
	{
		"label": "REALTY",
		"names": ["Summit Ridge Realty", "Larkspur Homes", "Gatehouse Realty", "Twin Oaks Properties"],
		"who": ["Ms. Abbott", "Mr. Gatehouse", "Ms. Oakes"],
		"pains": ["agents use personal email", "listing photos fill the server", "wifi drops during open houses", "XP desktops at the front desk"],
	},
	"trailer":
	{
		"label": "DEMOLITION",
		"names": ["Hammerfield Demolition", "Rubble and Sons", "Ironclad Excavating", "Big Dig Contracting"],
		"who": ["Mr. Hammerfield", "Ms. Rubble", "Mr. Ironclad"],
		"pains": ["estimates live on one laptop", "the trailer wifi is a phone hotspot", "a virus took the office PC down", "old desktops in two trailers"],
	},
}

const DEFAULT_BEAT_TEXT := {
	"chamber": {
		"lynk": {"from": "Garrison", "text": "Chamber of Commerce lunch on Thursday. Rubber chicken, two hundred business cards and exactly one person who needs us. Go find them."},
		"invite": {
			"speaker": "{sales_owner}",
			"text": "The Chamber lunch is Thursday at noon. It takes two hours, the chicken is dry and every owner in the county will be there. Wear the good tie. Someone at table six has an IT guy who is somebody's nephew.",
			"options": [{"id": "go", "label": "GO TO THE LUNCH (2 HOURS)"}, {"id": "skip", "label": "SKIP IT"}],
		},
		"room": {
			"speaker": "Mr. Kestrel",
			"text": "Kestrel Hill Realty, sixteen agents. Our whole office went down on Tuesday and the nephew was at a wedding. Can you guarantee that someone answers within the hour? Any time, any problem?",
			"options": [
				{"id": "moon", "label": "ONE HOUR, ANY TIME, ANY PROBLEM"},
				{"id": "honest", "label": "FOUR HOURS, IN WRITING"},
				{"id": "card", "label": "TAKE HIS CARD, PROMISE TO CALL"},
			],
		},
		"res_moon": {"speaker": "Mr. Kestrel", "text": "That is exactly what I wanted to hear. Call me Monday with a number. (He writes 'one hour' on the back of your card and underlines it twice.)"},
		"res_honest": {"speaker": "Mr. Kestrel", "text": "Four hours, in writing. Most of you people promise me the moon. Send me a proposal. Morgan will be glad you did it that way."},
		"res_card": {"speaker": "Mr. Kestrel", "text": "Fine. I have eleven cards from this lunch and one nephew. Call me and make it quick."},
	},
	"paws": {
		"lynk": {"from": "Garrison", "text": "Dr. Brandt from Paws and Claws sat next to me at the lunch and asked for you by name. Their server beeps every ten minutes and nobody knows why."},
		"offer": {
			"speaker": "{sales_owner}",
			"text": "Paws and Claws Veterinary wants someone to look at their office. Dr. Brandt is a talker and it is a real visit, fifty minutes each way. Use the front door, the van is out front, and keep your eyes open in the closet. Take the lead?",
			"options": [{"id": "take", "label": "TAKE THE LEAD"}, {"id": "pass", "label": "PASS"}],
		},
		"found": {
			"speaker": "You notice something",
			"text": "%s What do you do with it?",
			"options": [
				{"id": "ticket", "label": "LOG A TICKET: FREE FIX"},
				{"id": "project", "label": "SELL IT AS A PROJECT ($500)"},
				{"id": "note", "label": "KEEP IT FOR THE QUOTE"},
			],
		},
		"res_ticket": {"speaker": "Dr. Brandt", "text": "You logged a ticket before you even had a contract? Dan will look at it this week. I will tell everyone at the clinic association about you."},
		"res_project": {"speaker": "Dr. Brandt", "text": "A project quote, the same day? That is the kind of salesman I like. Put it on the pile with the managed service."},
		"res_note": {"speaker": "Dr. Brandt", "text": "You wrote it down and said nothing? Sneaky. I like it. Send me a number that covers all of it."},
	},
	"xpwave": {
		"lynk": {"from": "Garrison", "text": "The XP news is finally reaching the people with beige towers. Three of them phoned this morning. Quote what we can deliver; Dan has a list as long as his arm."},
		"info": {"speaker": "{sales_owner}", "text": "Windows XP stops getting patches on April 8 and every owner with a beige tower just discovered it. Three desktop shops called this week. Price against what Alan will sign and what Dan can install, in that order.", "ok": "SEND THEM OVER"},
	},
	"undercut": {
		"lynk": {"from": "Alan", "text": "ByteBrothers was seen in the parking lot of your last quote. Do not do anything stupid with the price."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "ByteBrothers undercut your quote at %s. Twenty percent under ours, and I hear their rep has a nicer tie than you. Match it, sell them on the value, or let it go?",
			"options": [
				{"id": "match", "label": "MATCH THEIR PRICE (20% OFF)"},
				{"id": "value", "label": "SELL THE VALUE (1 HOUR)"},
				{"id": "walk", "label": "WALK AWAY"},
			],
		},
		"res_match": {"speaker": "{tech_owner}", "text": "You matched them. Twenty percent off. I hope somebody enjoys the logo, because the margin is gone."},
		"res_value_win": {"speaker": "{sales_owner}", "text": "You walked them through the backups and the response numbers and they signed at the full fee. That is the John I hired."},
		"res_value_lose": {"speaker": "{sales_owner}", "text": "They like you, but the price won. ByteBrothers took %s. It happens."},
		"res_walk": {"speaker": "{tech_owner}", "text": "Good. A deal that loses money is worse than a deal we lose. Next one."},
	},
	"shop": {
		"lynk": {"from": "Garrison", "text": "A quoted client has been looking at the hardware on a big shopping site. Do not panic. Do not match anything yet."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "%s called back about your quote. They found the same boxes on Amazon for a lot less and want you to match it. They are not counting the setup, the migration, the backups or the phone number that answers on a Saturday. Match it, defend the value, sell them the box only, or let it go?",
			"options": [
				{"id": "defend", "label": "DEFEND THE VALUE (1 HOUR)"},
				{"id": "match", "label": "PRICE MATCH (15% OFF)"},
				{"id": "box", "label": "SELL THEM THE BOX ONLY"},
				{"id": "walk", "label": "LET THEM GO"},
			],
		},
		"res_defend_win": {"speaker": "{sales_owner}", "text": "You put the setup, the migration and the Saturday phone number on one page next to the shopping cart. They signed at the full fee. Nobody prices a Saturday until the server is down."},
		"res_defend_lose": {"speaker": "{sales_owner}", "text": "They heard you out and bought the box anyway. %s went with the cart. Some people have to find out what setup costs the hard way."},
		"res_match": {"speaker": "{tech_owner}", "text": "You matched the cart. Fifteen percent off, and we still do the setup, the migration and the backups. I would like it noted that the margin is now mostly the logo."},
		"res_box": {"speaker": "{sales_owner}", "text": "You sold %s the hardware at a fair margin and told them setup is optional. They will call when it does not come up. They always call. No monthly fee, but it was easy money."},
		"res_walk": {"speaker": "{tech_owner}", "text": "Good. A client who prices us against a shopping cart will do it again at renewal. Next one."},
	},
	"sla_p1": {
		"card": {
			"speaker": "{ops}",
			"text": "%s has a P1: the server is down and their contract says one hour, any time. Dan is on site elsewhere and the queue is full. They are not calling the desk, they are calling you.",
			"options": [
				{"id": "own", "label": "OWN IT: CALL AND STAY ON THE LINE"},
				{"id": "blame", "label": "TELL THEM DAN IS ON IT"},
				{"id": "dan", "label": "ASK DAN TO DROP EVERYTHING"},
			],
		},
		"res_own": {"speaker": "{ops}", "text": "You stayed on the phone with %s for forty minutes. They did not get a fix any faster, but they know where the buck stops. Keep it up."},
		"res_blame": {"speaker": "{ops}", "text": "You told %s the queue is busy. They know it is busy, they saw the van. The next time you promise an hour, check with me first."},
		"res_dan": {"speaker": "Dan", "text": "Fine, I dropped the printer job and drove over. %s is fixed. I am putting one hour response in the planning notes with your name next to it."},
	},
	"qbr": {
		"lynk": {"from": "Alan", "text": "Quarter is nearly over. Your best account is due a business review. Renewals are won in the room, not on the phone."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "%s is your best account and they are %d%% happy. A business review is where renewals are won, and where I would sell them the backup service. Do it at their office if you can.",
			"options": [
				{"id": "onsite", "label": "GO TO THEIR OFFICE (%d MIN EACH WAY)"},
				{"id": "phone", "label": "RUN IT BY PHONE (1 HOUR)"},
				{"id": "report", "label": "SEND THE REPORT, SKIP THE MEETING"},
			],
		},
	},
	"crypto": {
		"lynk": {"from": "Dan", "text": "Ransomware at the law office. Atty. Spence is on the phone and he asked for you by name. We will handle the tech side, you handle him."},
		"card": {
			"speaker": "Atty. Spence",
			"text": "It hit us at nine this morning. Every file on the paralegal's PC is locked and there is a countdown on the screen. I called you first, before my wife. Please tell me you are going to fix this.",
			"options": [
				{"id": "comfort", "label": "I AM ON MY WAY. DO NOT PAY ANYONE"},
				{"id": "renew", "label": "LET'S SECURE YOU FOR ANOTHER YEAR"},
				{"id": "backup", "label": "THAT IS WHAT MANAGED BACKUP IS FOR"},
			],
		},
		"res_comfort": {"speaker": "Atty. Spence", "text": "Thank you. I do not know what I would do without you people. I will not forget that you picked up the phone."},
		"res_renew": {"speaker": "Atty. Spence", "text": "You want to talk renewal while my files are locked? ...Actually, yes. Let's do it now, before I change my mind."},
	},
	"slip": {
		"lynk": {"from": "Garrison", "text": "A prospect likes the quote but their budget does not open until July. Hold the price or lose the deal. Think about it."},
		"card": {
			"speaker": "%s",
			"text": "My partners want to sign %s, but not before July 1. The budget year starts then. Can you hold the price?",
			"options": [
				{"id": "discount", "label": "SIGN BY FRIDAY: 10% OFF"},
				{"id": "wait", "label": "FINE, JULY IT IS"},
				{"id": "bluff", "label": "THE PRICE GOES UP ON JULY 1"},
			],
		},
		"res_discount": {"speaker": "%s", "text": "Ten percent off and a signature by Friday? Done. Send the paperwork."},
		"res_wait": {"speaker": "%s", "text": "Thank you for understanding. Call me on the second of July."},
		"res_bluff_win": {"speaker": "%s", "text": "I did not know prices go up on the first. All right, we sign today."},
		"res_bluff_lose": {"speaker": "%s", "text": "We talked to ByteBrothers and their price does not go up on the first. We are going with them. No hard feelings."},
	},
	"rise": {
		"lynk": {"from": "Alan", "text": "Our prices have not moved in two years. Our costs have. Tell Garrison I said so, nicely."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "Renewal season. The price rise letter has to go out 60 days before the contract date, so anyone renewing from week 15 on is covered by what you pick now. Raise everybody eight percent, raise only the clients who love us, or hold the line? Alan wants the margin. I want the logos.",
			"options": [
				{"id": "all", "label": "RAISE EVERYONE 8%"},
				{"id": "happy", "label": "RAISE ONLY THE HAPPY ONES (70%+)"},
				{"id": "none", "label": "HOLD THE PRICES"},
			],
		},
		"res_all": {"speaker": "{tech_owner}", "text": "Everyone. Good. Some will complain and some will leave, and the ones who leave were the ones who cost us money."},
		"res_happy": {"speaker": "{sales_owner}", "text": "Only the ones who love us. I like that. We keep the logos and Alan keeps the margin. Everybody is a little bit happy."},
		"res_none": {"speaker": "{sales_owner}", "text": "Holding the line. Good for the renewals, I will take that. Alan will say something about costs, let him."},
	},
	"hipaa": {
		"lynk": {"from": "Dan", "text": "A dental client wants a straight yes or no on HIPAA. Check what we actually have on file before you answer."},
		"card": {
			"speaker": "%s",
			"text": "The HIPAA omnibus rule has been law since last September and our attorney says we must have a risk assessment on file. %s is in the paperwork. Are we compliant with you? Yes or no?",
			"options": [
				{"id": "sell", "label": "SELL A SECURITY REVIEW (OURS)"},
				{"id": "moon", "label": "YES, FULLY COMPLIANT. NO WORRIES."},
				{"id": "refer", "label": "WE DO THE TECH PART, NOT THE POLICY"},
			],
		},
		"res_sell": {"speaker": "%s", "text": "A security review with encryption on the laptops? I can show that to the auditor. Send me a price for it."},
		"res_moon": {"speaker": "%s", "text": "Fully compliant. That is a relief; I will tell the attorney. (Morgan reads the email and looks at the ceiling for a while.)"},
		"res_refer": {"speaker": "%s", "text": "Fair enough. I appreciate you telling me what is yours and what is not. Most vendors would have said yes."},
	},
	"logo": {
		"lynk": {"from": "Garrison", "text": "Harborview Dental Partners has eleven offices and wants one provider. That is the biggest logo we have ever seen. Please do not mess this up."},
		"lynk_alan": {"from": "Alan", "text": "I saw the Harborview numbers. I do not sign deals that lose money on the first invoice."},
		"garrison": {"speaker": "{sales_owner}", "text": "Harborview Dental Partners: eleven offices, 38 users, $%d a week at list. The partners want 30 percent off to move all of them to us at once. It is a logo, John. A logo opens doors.", "ok": "WHAT DOES ALAN SAY?"},
		"alan": {"speaker": "{tech_owner}", "text": "Thirty percent off puts that account at %d percent margin. My floor is %d. I will not sign a deal that costs us money to deliver. It is a logo, not a living.", "ok": "I HEAR YOU BOTH"},
		"pick": {
			"speaker": "John Marlowe",
			"text": "Two owners, one account, and a prospect who wants an answer by Friday. Whose side are you on?",
			"options": [
				{"id": "garrison", "label": "GARRISON: TAKE THE LOGO AT 30% OFF"},
				{"id": "alan", "label": "ALAN: 10% OFF, LET THEM WALK"},
				{"id": "broker", "label": "BROKER A SCOPED 15% (2 H, $300)"},
			],
		},
		"res_garrison": {"speaker": "{tech_owner}", "text": "Thirty percent off. Fine. I said what I said, I will remember who wanted the logo when payroll is short."},
		"res_alan_win": {"speaker": "{sales_owner}", "text": "You held at ten percent and they still signed? I did not think you had it in you. Alan is smiling, I think."},
		"res_alan_lose": {"speaker": "{sales_owner}", "text": "They went to ByteBrothers. At twenty-five percent off. I told you that logo was ours. Alan, do not say anything."},
		"res_broker_win": {"speaker": "{sales_owner}", "text": "You put both of us in a room, scoped it first and they signed. Alan gave up three points and I gave up three. That is how it is done."},
		"res_broker_lose": {"speaker": "{sales_owner}", "text": "Two owners and no answer by Friday. They signed a deal with somebody who could say yes. We lost the logo and the afternoon."},
	},
	"refund": {
		"lynk": {"from": "Alan", "text": "A client says we missed the one hour response from your handover and wants last month back. Your handover, your call."},
		"card": {
			"speaker": "%s",
			"text": "%s: your handover promised us a one hour response and we have waited two days. We want a refund of the last month, $%d, or we walk. I am not angry. I am done.",
			"options": [
				{"id": "refund", "label": "REFUND THE MONTH (-$%d)"},
				{"id": "credit", "label": "HALF A MONTH BACK (-$%d), A RESET"},
				{"id": "refuse", "label": "REFUSE: THE CONTRACT SAYS SO"},
			],
		},
		"res_refund": {"speaker": "%s", "text": "A refund and an apology. That is more than I expected from a salesman. We will give you another chance."},
		"res_credit_win": {"speaker": "%s", "text": "Half a month and a meeting where Dan and Morgan explain what went wrong? That I can accept."},
		"res_credit_lose": {"speaker": "%s", "text": "A credit is not a refund. We will think about whether we renew. You have not heard the last of this."},
		"res_refuse": {"speaker": "%s", "text": "The contract says no refunds. It also says one hour response. Interesting. We will be calling our attorney."},
	},
	"newhire": {
		"lynk": {"from": "Garrison", "text": "The new kid starts Monday. Wes. He has a nice tie and no idea what a quote is. He is sitting with you this week."},
		"card": {
			"speaker": "Wes Okafor",
			"text": "Hi, Mr. Marlowe. Garrison said to stick with you this week. I wrote down everything you said at the last quote. Can I try the next call on my own, or do you want me to watch first?",
			"options": [
				{"id": "teach", "label": "WATCH FIRST, THEN WE TALK IT THROUGH"},
				{"id": "copy", "label": "USE MY PITCH, WORD FOR WORD"},
				{"id": "pass", "label": "SEND HIM TO MORGAN, I AM BUSY"},
			],
		},
		"res_teach": {"speaker": "Wes Okafor", "text": "You told me to ask what hurts before I say what we sell. It sounds so obvious. I think I am going to be good at this because of you."},
		"res_copy_ok": {"speaker": "Wes Okafor", "text": "It worked. Your whole speech, even the joke about the patch panel. The client laughed. I do not think they noticed it was yours."},
		"res_copy_bad": {"speaker": "{sales_owner}", "text": "Your new kid promised a client the same ninety minute response you promised last month, in the same words. Delivery is not thrilled. Teach him the difference between a pitch and a promise."},
		"res_pass": {"speaker": "{sales_owner}", "text": "You sent Wes to Morgan? She gave him a binder and a lecture about the ticket queue. He is a nice kid. He deserved a salesman."},
	},
	"recruit": {
		"lynk": {"from": "Garrison", "text": "Odd thing: a recruiter from across town asked whether you were happy here. I told him to ask you. Are you?"},
		"card": {
			"speaker": "Trent Dagmar",
			"text": "John. Trent Dagmar, ByteBrothers. I watched you work the Chamber lunch. We have a book of two hundred seats and nobody who can close. $%d a week base, forty percent commission, a company car, and you bring your card file. Think about it, but not for long.",
			"options": [
				{"id": "leave", "label": "GIVE NOTICE: I AM TAKING THE JOB"},
				{"id": "counter", "label": "TELL GARRISON, ASK FOR A RAISE"},
				{"id": "both", "label": "KEEP BOTH DOORS OPEN, SAY NOTHING"},
				{"id": "decline", "label": "NO THANKS. I AM LOYAL TO PIXEL."},
			],
		},
		"res_leave": {"speaker": "{sales_owner}", "text": "I am sorry to hear it. Finish the quarter strong. And I will expect your clients to stay with us, not follow you down the road."},
		"res_counter_yes": {"speaker": "{sales_owner}", "text": "ByteBrothers called you? Of course they did. You have been the best thing to happen to this company in a year. I can do one hundred more a week and a title. Stay."},
		"res_counter_no": {"speaker": "{sales_owner}", "text": "I would love to match them. I cannot, not this quarter. I hope you understand. The door is not locked."},
		"res_both_caught": {"speaker": "{sales_owner}", "text": "Trent Dagmar mentioned at the Chamber breakfast that you were on his shortlist. He thought I knew. I did not know. We will talk about trust."},
		"res_decline": {"speaker": "{sales_owner}", "text": "You said no to ByteBrothers? To their face? John, I will not forget that. Neither will Alan, though he will never say so."},
	},
	"diligence": {
		"lynk": {"from": "Garrison", "text": "Summit Managed Holdings is looking at buying us. Their auditor comes Thursday. Be charming and be accurate, in that order if you must."},
		"card": {
			"speaker": "Ms. Pell",
			"text": "Mr. Marlowe, I am auditing the book you sold for Summit Managed Holdings. Three questions: how many clients left in the first 90 days, how many commissions were clawed back, and how many promises in the handover binders were not kept? I have the paperwork. I would like your version.",
			"options": [
				{"id": "disclose", "label": "TELL HER ALL (%d LEFT, %d CLAWED)"},
				{"id": "shade", "label": "SAY THE NUMBERS ARE FINE"},
				{"id": "refer", "label": "SEND HER TO MORGAN AND ALAN"},
			],
		},
		"res_disclose_clean": {"speaker": "Ms. Pell", "text": "That matches the binders to the dollar. A clean book is rare. Summit pays an earn-out on retention and yours looks good."},
		"res_disclose": {"speaker": "Ms. Pell", "text": "You told me the bad numbers before I found them. I note that. The earn-out will be tied to retention, so the clients you still have matter a great deal."},
		"res_shade_clean": {"speaker": "Ms. Pell", "text": "The numbers are fine, you say, and they are. I had expected more drama from a salesman."},
		"res_shade_caught": {"speaker": "Ms. Pell", "text": "Mr. Marlowe, your binders and your answers do not agree. I have noted it in the file and Summit will take that into account. So will Mr. Alan."},
		"res_shade_away": {"speaker": "Ms. Pell", "text": "Fine, the numbers are fine. I will take your word for it. (Morgan does not.)"},
		"res_refer": {"speaker": "Ms. Pell", "text": "You send me to the delivery side. Honest, in its way. I will see what Morgan says about the promises."},
	},
	"outing": {
		"team": {"text": "You closed the quarter and the crew carried the load. A team night would be noticed. Come out with us?"},
		"client": {"text": "%s has been on the fence. Dinner with the owner and the crew at the grill might tip it. Bring your good tie and no shop talk."},
		"team_done": "THE CREW FEELS SEEN: DELIVERY HAS A LITTLE ROOM FOR THE NEXT TWO WEEKS.",
		"client_done": "THE OWNER OF %s ENJOYED THE EVENING: THE LEAD WARMS BY %d.",
		"client_bad": "THE DINNER WAS AWKWARD. THE OWNER OF %s IS NOT SOLD.",
	},
	"crunch2": {
		"speaker": "{sales_owner}",
		"text": "Two weeks to the end of the year's last quarter. You are at %d%% of quota. Do you want my sign-off for 20%% discounts until the end of August, or hold the price?",
		"options": [{"id": "yes", "label": "YES, APPROVE 20% OFF FOR THE CRUNCH"}, {"id": "no", "label": "NO, HOLD THE PRICE"}],
	},
	"sandbag": {"label": "COUNT EXTRA DEALS NEXT QUARTER", "hint": "NEEDS 60% OF QUOTA FIRST"},
	"endings": {
		"director": "YOU TAKE THE SALES DIRECTOR JOB. A TEAM OF ONE REP, A BIGGER QUOTA AND GARRISON'S OLD CLIENT LIST. THE BELL IS YOURS NOW.",
		"stay": "YOU STAY ON AS ACCOUNT MANAGER. THE BOOK YOU BUILT IS YOURS TO KEEP SAFE, AND NEXT YEAR'S QUOTA IS ALREADY ON YOUR DESK.",
		"leave": "YOU TAKE YOUR CARD FILE AND YOUR COFFEE MUG TO BYTEBROTHERS. THE CLIENTS GET A PHONE CALL FROM YOU ON MONDAY. SOME OF THEM ANSWER.",
		"leave_followed": "YOU TAKE YOUR CARD FILE AND YOUR COFFEE MUG TO BYTEBROTHERS. THE CLIENTS YOU LOOKED AFTER FOLLOW YOU, ONE PHONE CALL AT A TIME. GARRISON SENDS A BOTTLE OF SOMETHING AND A LAWYER'S LETTER.",
		"leave_alone": "YOU TAKE YOUR CARD FILE AND YOUR COFFEE MUG TO BYTEBROTHERS. THE CLIENTS GET A PHONE CALL FROM YOU ON MONDAY. NOBODY ANSWERS. YOU HAD PROMISED THEM A LOT.",
		"rollup": "SUMMIT MANAGED HOLDINGS BUYS PIXEL IT PARTNERS. YOU STAY ON AS REGIONAL SALES LEAD WITH AN EARN-OUT OF $%d TIED TO HOW MANY OF YOUR CLIENTS STAY. KEEP THE PROMISES YOU MADE.",
		"let_go": "YOU BOX UP THE DESK. GARRISON SHAKES YOUR HAND AND SAYS IT WAS NOT PERSONAL. THE BELL STAYS ON THE WALL.",
	},
	# R38 P5: the rival and good-habit beats (sales_rival.gd; docs/scope-bad-habits.md sections 2.5 and 6)
	"incumbent": {
		"lynk": {"from": "Garrison", "text": "First question on every call: who is your IT person now? Write the answer in SalesHound. It tells you who you are really up against."},
		"found": {"speaker": "Dr. Pine", "text": "We use Big Cheese Technology Group. A man named Rex Calloway. He is very friendly and everything is included at $39 a seat, so I never see a bill I understand. Why do you ask?", "ok": "WRITE IT DOWN"},
	},
	"rex": {
		"lynk": {"from": "Garrison", "text": "Rex Calloway was at the Chamber lunch. Big Cheese Technology Group, the billboard on the county road. Everybody likes him."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "Rex Calloway from Big Cheese sat at the next table and told everyone business is booming. He has forty-one five-star reviews on Yowl, and I hear most of them come from accounts that review nothing else. Do something with that, or do not.",
			"options": [{"id": "flyer", "label": "READ HIS FLYER, ASK AROUND (1 HOUR)"}, {"id": "friend", "label": "SHAKE HIS HAND, HE SEEMS NICE"}, {"id": "ignore", "label": "IGNORE HIM"}],
		},
		"res_flyer": {"speaker": "John", "text": "EVERYTHING INCLUDED, $39 A SEAT. No list of what everything is. You ask around and three prospects say the same thing: they like him, and they cannot say what they are paying for. Now you know who to ask about on every call.", "ok": "NOTED"},
		"res_friend": {"speaker": "Rex Calloway", "text": "Call me Rex, everyone does. He laughs at your tie and gives you a flyer and a cookie. Garrison thinks it was good manners. Alan thinks you have just met the competition.", "ok": "OK"},
		"res_ignore": {"speaker": "John", "text": "He will not be gone by July. You were warned by the cookie crumbs on the flyer.", "ok": "OK"},
	},
	"flat": {
		"lynk": {"from": "Garrison", "text": "A prospect says Big Cheese quoted a flat price and our quote looks complicated. Call them back before they sign it."},
		"card": {
			"speaker": "Prospect",
			"text": "Big Cheese quoted me $39 a seat, all in. You sent me a page with thirty-one lines. I don't understand half of them. I just want to know what I'm getting.",
			"options": [
				{"id": "tiers", "label": "ONE PAGE, THREE CHOICES"},
				{"id": "match", "label": "MATCH THE FLAT PRICE"},
				{"id": "lines", "label": "GO LINE BY LINE (AN HOUR)"},
				{"id": "walk", "label": "WALK, THEY'LL BE BACK IN 6 MONTHS"},
			],
		},
		"res_tiers": {"speaker": "Prospect", "text": "GOOD, BETTER, BEST, one line each, and a box for what is NOT included. She circles BETTER. Set PRESENTED AS to 3 TIERS in the quote builder.", "ok": "GOOD"},
		"res_match": {"speaker": "Prospect", "text": "She signs in a day, if you send it. Alan shows you the margin. Nothing is in writing about what is left out, and you both know it.", "ok": "OK"},
		"res_lines": {"speaker": "Prospect", "text": "You read thirty-one lines. By line fourteen you both agree the list is the problem. She trusts you a little more.", "ok": "OK"},
		"res_walk": {"speaker": "John", "text": "You are right about the six months. You are wrong about it helping.", "ok": "OK"},
	},
	"assess": {
		"lynk": {"from": "Garrison", "text": "A dental office on Pine Road is unhappy with Big Cheese. Call them, then press ASSESS in SalesHound. An hour in their closet finds what Rex left out."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "Dr. Marlowe is a Big Cheese client and he wants a second opinion before he renews. Use ASSESS on him: an hour, an honest list, and every item you write down is a promise you are on the hook for.",
			"options": [{"id": "take", "label": "ADD HIM TO THE PIPELINE"}, {"id": "pass", "label": "PASS"}],
		},
		"res_take": {"speaker": "Dr. Marlowe", "text": "Rex says it is all included. Nobody can show me where it says so. Come and look at the closet.", "ok": "ON MY WAY"},
	},
	"laundered": {
		"lynk": {"from": "Garrison", "text": "A woman called Gwen phoned for you. She knows our rates and our dispatcher's name. Odd."},
		"card": {
			"speaker": "John's phone",
			"text": "A woman named Gwen called, said a friend of hers recommended us. Her server is slow, she has XP at the front, and her IT person never calls back. She knows our rates and the name of our dispatcher. The friend is a client who has never mentioned us.",
			"options": [
				{"id": "take", "label": "TAKE THE MEETING, SHE IS A GOOD LEAD"},
				{"id": "ask", "label": "ASK HER HOW SHE HEARD"},
				{"id": "tell", "label": "WARN THE DENTAL OFFICE, FOR FREE"},
			],
		},
		"res_take": {"speaker": "John", "text": "She is a great lead. She is a great lead because someone read our tickets and sold her the story. You write it down in a folder you do not name.", "ok": "OK"},
		"res_ask": {"speaker": "Gwen", "text": "She mentions the shared mailbox at the dental office. John goes quiet, then says he will make a call. She is still a lead, just a more honest one.", "ok": "OK"},
		"res_tell": {"speaker": "John", "text": "They fix the mailbox in an afternoon. Gwen turns up as a lead a few weeks later, and she tells everyone why.", "ok": "OK"},
	},
	"plumb": {
		"lynk": {"from": "Garrison", "text": "Plumb Line Technology has been sitting on a proposal for six weeks. The prospect wants a second opinion from us. Hollis Grady is a careful man."},
		"card": {
			"speaker": "Ms. Cedar",
			"text": "I asked Hollis Grady at Plumb Line for a quote six weeks ago. Nine pages, thirty-one line items, a binder and all. I like him. I trust him. I cannot tell which of the thirty-one I need. Would you give me a second opinion?",
			"options": [
				{"id": "tiers", "label": "SHOW HER THE THREE TIER PAGE"},
				{"id": "undercut", "label": "JUST UNDERCUT HIM"},
				{"id": "honest", "label": "SAY HE IS GOOD, SEND HER BACK"},
			],
		},
		"res_tiers": {"speaker": "Ms. Cedar", "text": "Three choices and a box for what is not included. She says it is the first time anyone has told her what she gets. Hollis is good. He just cannot sell it.", "ok": "OK"},
		"res_undercut": {"speaker": "Ms. Cedar", "text": "Easy. Hollis had no answer to a lower number. Alan raises an eyebrow about the margin, and you feel slightly unclean.", "ok": "OK"},
		"res_honest": {"speaker": "Ms. Cedar", "text": "She is surprised. You tell her to ask Hollis which three of the thirty-one she needs, and to call you if he cannot say. Hollis hears about it, and he does not forget.", "ok": "OK"},
	},
	"favour": {
		"lynk": {"from": "Garrison", "text": "Hollis Grady rang the front desk and asked for you by name. He was polite about it. He is always polite about it."},
		"res_lead": {"speaker": "Hollis Grady", "text": "You sent Ms. Cedar back to me with the right question. I answered it, and she signed. Tidewater Title rang me this week: nine people, too small for the way I work. I gave Mr. Whitlow your number and told him why.", "ok": "THANK HIM"},
		"res_full": {"speaker": "Hollis Grady", "text": "You sent Ms. Cedar back to me with the right question. I had a small office to pass on to you, but I hear your pipeline is full. I will keep you in mind. I do not forget.", "ok": "THANK HIM"},
	},
	"rumour": {
		"lynk": {"from": "Garrison", "text": "Somebody is telling prospects we are not bonded and not HIPAA safe. Guess who sits at the next table at the Chamber lunch."},
		"card": {
			"speaker": "Prospect",
			"text": "Quick question before we go further. Are you bonded? And HIPAA safe? Somebody at the Chamber lunch told me you are not.",
			"options": [
				{"id": "paper", "label": "SHOW THE BOND AND THE BAA (1 HOUR)"},
				{"id": "back", "label": "BADMOUTH BIG CHEESE BACK"},
				{"id": "ignore", "label": "LAUGH IT OFF AND MOVE ON"},
			],
		},
		"res_paper": {"speaker": "Prospect", "text": "Two documents and a coffee. She is satisfied, though you looked a little defensive. The rumour will fade in about four weeks.", "ok": "OK"},
		"res_back": {"speaker": "Prospect", "text": "She leans in. It works, today. You say things about Rex you cannot prove, and Garrison will hear them back.", "ok": "OK"},
		"res_ignore": {"speaker": "Prospect", "text": "She nods and writes something down. The rumour stands for about four weeks.", "ok": "OK"},
		"counter": {"speaker": "{sales_owner}", "text": "Rex heard what you said about him. He is telling the whole lunch table you are the one who cannot be trusted. Reputation takes a dent.", "ok": "OK"},
	},
	"audit": {
		"lynk": {"from": "Morgan", "text": "Dan says five tickets are open and three more prospects will phone by Monday. Please quote only what we can carry."},
		"info": {"speaker": "{sales_owner}", "text": "WebWoot audited Big Cheese: 212 seats nobody reported, and its antivirus was suspended over the weekend. Three of Rex's clients phoned us by Monday, one asking for you by name. Quote only what Dan and Morgan can carry.", "ok": "SHOW ME THE LEADS"},
	},
	"intro": {
		"lynk": {"from": "Garrison", "text": "A prospect wants a reason to sign this month. An intro rate is fine. An intro rate nobody can find the end of is not."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "%s likes the quote and not the number. They would sign today for half price on the first three months. The list price after that can go on page one, or in the paragraph nobody reads. Or you hold the price.",
			"options": [
				{"id": "pageone", "label": "INTRO RATE, THE STEP ON PAGE ONE"},
				{"id": "smallprint", "label": "INTRO RATE, PRICE IN THE SMALL PRINT"},
				{"id": "hold", "label": "HOLD THE LIST PRICE (1 HOUR)"},
			],
		},
		"res_pageone": {"speaker": "{sales_owner}", "text": "Three months at half, then the list price, in the first paragraph. They read it twice and said they would think about it. People who think about it and still sign tend to stay."},
		"res_smallprint": {"speaker": "{tech_owner}", "text": "They signed. Month four is on page six, in grey. A vendor did this to me once. I remember exactly how I felt about that vendor in month four."},
		"res_hold": {"speaker": "{sales_owner}", "text": "You held the price and spent the hour on what it buys. No discount now and no surprise in month four. They are still talking to you."},
	},
	"scorecard": {
		"lynk": {"from": "Garrison", "text": "Renewals are coming. The clients who see a one page scorecard stay. The others get a polite email in January."},
		"card": {
			"speaker": "{sales_owner}",
			"text": "Renewal season. The clients we show a one page scorecard (tickets closed, hours saved, and what is NOT included) renew more often. The rest renew on price alone, and Rex is cheaper.",
			"options": [
				{"id": "all", "label": "SEND ONE TO EVERY CLIENT (2 HOURS)"},
				{"id": "top", "label": "SEND TO THE BIGGEST 3 (1 HOUR)"},
				{"id": "skip", "label": "SKIP IT"},
			],
		},
		"res_all": {"speaker": "Christy", "text": "One page each: what we did, what it cost, what is not included. Two clients put it on the fridge.", "ok": "OK"},
		"res_top": {"speaker": "Christy", "text": "Three pages to the three biggest accounts. The others will get theirs next quarter, maybe.", "ok": "OK"},
		"res_skip": {"speaker": "Christy", "text": "Renewals will have to stand on their own, then.", "ok": "OK"},
	},
}
var BEAT_TEXT: Dictionary = DEFAULT_BEAT_TEXT.duplicate(true)

var leads: Array = []  # {id, name, type, who, users, pain, quality, fee, site, week, stage, called, visited, moon, why}
var book: Array = []  # won deals: {id, name, type, mrr, margin, week, promise, gap, mood, complain, resolved}
var next_id := 1
var used_names: Array = []
var quota_level := DEFAULT_QUOTA
var plan := "balanced"
var margin_floor := DEFAULT_FLOOR
var crunch := false  # Garrison cleared 20% discounts for the end-of-quarter crunch
var q_signed: Array = [0, 0]  # new MRR signed in each quarter
var q_result: Array = ["", ""]  # "", "HIT" or "MISS" once the quarter has closed
var warned := false  # a missed quarter: Garrison's performance warning
var week_new := 0
var week_deals := 0
var week_commission := 0
var week_cost := 0  # one-off costs this week (discovery fees)
var week_calls := 0
var week_visits := 0
var week_quotes := 0
var commission_total := 0
var wins := 0
var losses := 0
var quotes_sent := 0
var complaints := 0
var bell_ready := false
var bell_rings := 0
var crm_sel := 0
var crm_tab := "ALL"
var visit_lead := 0  # the lead you are visiting (Onsite hooks read it)
var last_report := ""
# C2: the deeper loop
var crm_view := "list"  # the CRM shows the pipeline ("list") or the quote builder ("build")
var crm_page := 0  # the detail pane: 0 summary, 1 promises and risk
var qb: Dictionary = {}  # the quote being built: {id, q, row, page}
var pending_handover := 0  # id of the won deal waiting for the conference room
var handover_queue: Array = []  # more wins waiting behind it
var rival_wins := 0  # quoted deals ByteBrothers took
var clawbacks := 0
var clawed_total := 0
var week_clawback := 0
var churned: Array = []  # clients that left: {name, week, left, mrr, claw, why}
var base_book: Array = []  # the clients you inherited, up for renewal on a schedule
var base_ready := false
var lost_base := 0  # weekly fee lost with base clients that did not renew
var expansion_base := 0  # weekly fee added to base clients by upsells
var expansion_total := 0  # new MRR from upsells and price rises
var renewals_won := 0
var renewals_lost := 0
var upsells := 0
var handovers := 0
# C3
var flags: Dictionary = {}  # what the story beats decided (chamber, paws, undercut, p1, qbr, crypto, slip, rise, hipaa, logo, refund, bb, summit, dd ...)
var raise_wage := 0  # weekly raise Garrison gave you against the ByteBrothers offer
var sandbag := false  # Garrison let you count deals signed after the quota is met in the next quarter
var team_until := 0  # a good team night buys delivery capacity until this week
var distributed := 0  # cash above CASH_CAP the owners took out
var week_distrib := 0
var visit_entry: Dictionary = {}  # the book entry a business review visit is for
var qbr_renewal := false
var _poll := 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	leads = []
	book = []
	next_id = 1
	used_names = []
	quota_level = DEFAULT_QUOTA
	plan = "balanced"
	margin_floor = DEFAULT_FLOOR
	crunch = false
	q_signed = [0, 0]
	q_result = ["", ""]
	warned = false
	week_new = 0
	week_deals = 0
	week_commission = 0
	week_cost = 0
	week_calls = 0
	week_visits = 0
	week_quotes = 0
	commission_total = 0
	wins = 0
	losses = 0
	quotes_sent = 0
	complaints = 0
	bell_ready = false
	bell_rings = 0
	crm_sel = 0
	crm_tab = "ALL"
	visit_lead = 0
	last_report = ""
	crm_view = "list"
	crm_page = 0
	qb = {}
	pending_handover = 0
	handover_queue = []
	rival_wins = 0
	clawbacks = 0
	clawed_total = 0
	week_clawback = 0
	churned = []
	base_book = []
	base_ready = false
	lost_base = 0
	expansion_base = 0
	expansion_total = 0
	renewals_won = 0
	renewals_lost = 0
	upsells = 0
	handovers = 0
	flags = {}
	raise_wage = 0
	sandbag = false
	team_until = 0
	distributed = 0
	week_distrib = 0
	visit_entry = {}
	qbr_renewal = false
	if Hints.objective.begins_with("RING THE SALES BELL") or Hints.objective.begins_with("HANDOVER"):
		Hints.objective = ""


# the handover waits for you in the conference room: check twice a second
func _process(delta: float) -> void:
	if pending_handover == 0:
		return
	_poll += delta
	if _poll >= 0.4:
		_poll = 0.0
		Handover.tick()


# the sales campaign is the running mode
func in_mode() -> bool:
	return Campaign.active and Campaign.mode == "sales"


# a new run or a continued one starts here (Campaign.new_game / continue_game); outings follow the title menu's setting (C3: team night, dinner with a prospect)
func begin_run() -> void:
	Owner.vic_plan = plan


# ---- time: selling slots are clock hours ---------------------------------------------------------------
func slots_left() -> int:
	return clampi(int(floor(World.DAY_END - maxf(World.clock, World.DAY_START) + 0.001)), 0, SLOTS)


# a call or a quote takes `hours` of the day: the clock moves, the queue ages a little (Onsite._away does both)
func spend(hours: int) -> bool:
	if slots_left() < hours:
		Hints.toast("NOT ENOUGH SELLING HOURS LEFT THIS WEEK.", 2.5)
		return false
	Onsite._away(float(hours))
	changed.emit()
	return true


func quarter_index(day := -1) -> int:
	return 0 if (Campaign.day if day < 0 else day) <= int(QUARTERS[0].to) else 1


func quarter_label(day := -1) -> String:
	return str(QUARTERS[quarter_index(day)].label)


func quota_target(qi: int) -> int:
	var base := float(QUOTAS[quota_level].target) * (1.0 if qi == 0 else Q3_SHARE)
	base *= float(TIER_QUOTA.get(Difficulty.tier, 1.0))
	return int(round(base / 50.0)) * 50


func quota_pct(qi := -1) -> int:
	var i := quarter_index() if qi < 0 else qi
	return int(round(100.0 * float(q_signed[i]) / float(maxi(1, quota_target(i)))))


# how much of the quarter has passed, 0..1 (the end of the week counts)
func elapsed(day := -1) -> float:
	var d := Campaign.day if day < 0 else day
	var q: Dictionary = QUARTERS[quarter_index(d)]
	return clampf(float(d - int(q.from) + 1) / float(int(q.to) - int(q.from) + 1), 0.0, 1.0)


func quota_met() -> bool:
	return q_signed[quarter_index()] >= quota_target(quarter_index())


func behind_pace() -> bool:
	return float(quota_pct()) / 100.0 < elapsed() - 0.001


# ---- leads --------------------------------------------------------------------------------------------
func lead_by_id(id: int) -> Dictionary:
	for l in leads:
		if int(l.id) == id:
			return l
	return {}


func heat(lead: Dictionary) -> String:
	var q := int(lead.quality)
	return "HOT" if q >= 50 else ("WARM" if q >= 35 else "COLD")


func is_open(lead: Dictionary) -> bool:
	return ["LEAD", "MEETING", "QUOTED"].has(str(lead.stage))


func open_leads() -> Array:
	var out := []
	for l in leads:
		if is_open(l):
			out.append(l)
	return out


func pipeline_value() -> int:
	var total := 0
	for l in open_leads():
		total += int(l.fee)
	return total


func book_mrr() -> int:
	var total := 0
	for d in book:
		total += int(d.mrr)
	return total


func names_for(type: String) -> Array:
	return [str(Onsite.SITE_PROSPECT[type])] + TYPES[type].names


# one lead from the stream: always seven draws (the last one is the incumbent), so a seed repeats
func make_lead(r: RandomNumberGenerator) -> Dictionary:
	var type: String = TYPE_ORDER[r.randi() % TYPE_ORDER.size()]
	var info: Dictionary = TYPES[type]
	var pool := []
	for n in names_for(type):
		if not used_names.has(n):
			pool.append(n)
	if pool.is_empty():
		for n in names_for(type):
			used_names.erase(n)
			pool.append(n)
	var pick: String = pool[r.randi() % pool.size()]
	used_names.append(pick)
	var users := 6 + r.randi() % 30
	var quality := 20 + r.randi() % 46 + int(round(Build.sales_fx("lead"))) + int(Difficulty.cf("sales.lead"))
	var pain: String = info.pains[r.randi() % info.pains.size()]
	var who: String = info.who[r.randi() % info.who.size()]
	var inc: String = SalesRival.incumbent_for(r.randf())
	var lead := {
		"id": next_id,
		"name": pick,
		"type": type,
		"who": who,
		"users": users,
		"pain": pain,
		"quality": quality,
		"fee": BASE_FEE + users * PER_USER,
		"site": pick == str(Onsite.SITE_PROSPECT[type]),
		"week": Campaign.day,
		"stage": "LEAD",
		"called": false,
		"visited": false,
		"moon": false,
		"why": "",
		"touch": Campaign.day,
		"notes": [],
		"follow": 0,
		"incumbent": inc,
		"inc_seen": false,
	}
	next_id += 1
	return lead


func draw_week(r: RandomNumberGenerator) -> Array:
	var out := []
	var n := 2 + (1 if r.randf() < Difficulty.cf("sales.flow") else 0)
	for _i in n:
		out.append(make_lead(r))
	return out


func lead_text(l: Dictionary) -> String:
	return (
		"%s (%s), %d users. Their problem: %s. A %s lead, about $%d a week at list price. %s"
		% [str(l.name), str(TYPES[str(l.type)].label).to_lower(), int(l.users), str(l.pain), heat(l).to_lower(), int(l.fee), "You can visit their office." if bool(l.site) else "Phone only: too far to drive."]
	)


func accept_lead(l: Dictionary) -> void:
	Deals.touch(l, "ON THE PIPELINE")
	leads.append(l)
	changed.emit()


func drop_lead(id: int, why := "DROPPED") -> void:
	var l := lead_by_id(id)
	if l.is_empty() or not is_open(l):
		return
	l.stage = "LOST"
	l.why = why
	changed.emit()


func _age_leads(day: int) -> void:
	Deals.age(day)


# ---- the week --------------------------------------------------------------------------------------------
func begin_week(day: int) -> void:
	if not in_mode():
		return
	week_new = 0
	week_deals = 0
	week_commission = 0
	week_cost = 0
	week_calls = 0
	week_visits = 0
	week_quotes = 0
	week_clawback = 0
	if not base_ready:
		base_ready = true
		if base_book.is_empty():
			Retention.schedule_base()
	Handover.paperwork_all()
	Deals.resolve_pending(day)
	_age_leads(day)
	_beat_cards(day)
	var fresh := draw_week(Difficulty.rng("leads"))
	if not fresh.is_empty():
		var hot: Array = fresh.filter(func(x: Dictionary) -> bool: return int(x.quality) >= 50)
		Msp.send_text(
			"SalesHound",
			"%d new leads this week%s. Open the SalesHound app on your PC." % [fresh.size(), (": %s looks hot" % str(hot[0].name)) if not hot.is_empty() else ""]
		)
	for l in fresh:
		_lead_card(l)
	for d in book:
		if bool(d.get("complain", false)) and not bool(d.get("resolved", false)) and day >= int(d.week) + 2 and not bool(d.get("asked", false)):
			d["asked"] = true
			_complaint_card(d)
	for e in Retention.due(day):
		Retention.renewal_card(e)
	changed.emit()


func _lead_card(l: Dictionary) -> void:
	Cards.ask(
		"SalesHound lead",
		"New lead: " + lead_text(l),
		[
			{"label": "WORK IT (ADD TO THE PIPELINE)", "id": "work", "enabled": open_leads().size() < MAX_OPEN, "hint": "PIPELINE FULL"},
			{"label": "PASS", "id": "pass"},
		],
		func(id: String) -> void:
			if id == "work":
				accept_lead(l)
	)


func _lynk(who: String, text: String) -> void:
	Lync._push(who, who, text)


# Garrison and Alan: the decision cards (quota, comp plan, margin floor, the crunch, the warning)
func _beat_cards(day: int) -> void:
	if day == 1:
		_lynk("Garrison", "Welcome to the territory. Quota is on your desk in a minute. Sell what we can deliver.")
		_quota_card()
	elif day == 4:
		_lynk("Alan", "I will set the margin floor today. I do not sign deals that lose money.")
		_floor_card()
	elif day == 10:
		_crunch_card()
	elif day == 13 and warned:
		_warning_card()
	elif day == 18 and not quota_met():
		_crunch_card(true)
	elif day >= 2:
		_review_card(day)
	SalesBeats.week(day)
	SalesRival.week(day)


func _review_card(day: int) -> void:
	var qi := quarter_index(day)
	var left := int(QUARTERS[qi].to) - day + 1
	var text := (
		"Monday numbers. %d open leads worth $%d a week. %s is at %d%% of quota with %d weeks left, and the book is %d%% happy."
		% [open_leads().size(), pipeline_value(), str(QUARTERS[qi].label), quota_pct(qi), left, int(client_mood())]
	)
	Cards.ask("{sales_owner}", text, [{"label": "GOT IT", "id": "ok"}], func(_id: String) -> void: pass)


func _quota_card() -> void:
	var options := []
	for k in ["safe", "standard", "stretch"]:
		options.append({"label": str(QUOTAS[k].label), "id": k})
	Cards.ask(
		"{sales_owner}",
		"Your quota for the quarter ending June 30. Brand new MRR, signed and handed over. Pick a number you can stand behind; I will hold you to it.",
		options,
		func(id: String) -> void:
			quota_level = id
			Cards.ask_first(
				"{sales_owner}",
				"%s Now your pay. Salary pays $750 a week and a week of the fee per deal. Balanced pays $550 and two weeks of the fee. Commission-heavy pays $350 and three weeks of the fee. If a client leaves inside 90 days the commission comes back: half on salary, all of it on the other two plans." % str(QUOTAS[id].words),
				[
					{"label": "SALARY: $750 + 1 WEEK OF THE FEE", "id": "salary"},
					{"label": "BALANCED: $550 + 2 WEEKS OF THE FEE", "id": "balanced"},
					{"label": "COMMISSION-HEAVY: $350 + 3 WEEKS", "id": "commission"},
				],
				func(pid: String) -> void:
					plan = pid
					Owner.vic_plan = pid
			)
	)


func _floor_card() -> void:
	var options := []
	for k in ["loose", "standard", "strict"]:
		options.append({"label": str(FLOORS[k].label), "id": k})
	Cards.ask(
		"{tech_owner}",
		"I looked at what the XP desktop quotes cost us to deliver. Pick a margin floor: below it a quote cannot go out without me. Lower floors win more bids and leave less to pay the crew.",
		options,
		func(id: String) -> void: margin_floor = float(FLOORS[id].floor)
	)


func _crunch_card(second := false) -> void:
	if second:
		var row: Dictionary = BEAT_TEXT.crunch2
		var opts := []
		for o in row.options:
			opts.append({"label": str(o.label), "id": str(o.id)})
		Cards.ask(str(row.speaker), str(row.text) % quota_pct(1), opts, func(id: String) -> void: crunch = id == "yes")
		return
	var sb: Dictionary = BEAT_TEXT.sandbag
	Cards.ask(
		"{sales_owner}",
		"Two weeks to the quarter. You are at %d%% of quota. Do you want my sign-off for 20%% discounts on every deal until June 30, or hold the price?" % quota_pct(),
		[
			{"label": "YES, APPROVE 20% OFF FOR THE CRUNCH", "id": "yes"},
			{"label": "NO, HOLD THE PRICE", "id": "no"},
			{"label": str(sb.label), "id": "sandbag", "enabled": quota_pct() >= 60, "hint": str(sb.hint)},
		],
		func(id: String) -> void:
			crunch = id == "yes"
			sandbag = id == "sandbag"
	)


func _warning_card() -> void:
	Cards.ask(
		"{sales_owner}",
		"You missed the quarter: %d%% of quota. This is a performance warning. Miss the next one and we part ways.%s What do you need?" % [quota_pct(0), (" Unless the two quarters together reach %d%% of the year: it is a big number, I know." % int(100.0 * Difficulty.cf("sales.keep"))) if Difficulty.cf("sales.keep") > 0.0 else ""],
		[
			{"label": "UNDERSTOOD. I WILL CLOSE MORE.", "id": "ok"},
			{"label": "THE LEADS WERE THIN", "id": "excuse"},
		],
		func(id: String) -> void:
			if id == "excuse":
				Campaign.adjust_rep(-2)
	)


# ---- the quote -----------------------------------------------------------------------------------------
func discount_ok(lead: Dictionary) -> bool:
	return crunch or behind_pace() or int(lead.users) >= 25


func margin_pct(q: Dictionary, lead: Dictionary = {}) -> float:
	return Deals.margin(q, lead)


func quote_price(lead: Dictionary, q: Dictionary) -> int:
	return Deals.price(lead, q)


func win_chance(lead: Dictionary, q: Dictionary) -> float:
	return Deals.win(lead, q)


# what the crew can honestly take on right now (points; a 1-hour response promise is 4)
func capacity() -> float:
	var recent := 0
	for d in book:
		if Campaign.day - int(d.week) <= 1:
			recent += 1
	var open := Msp.open_tickets().size()
	var cap := 3.0 - 0.15 * maxf(0.0, float(open) - 3.0) - 0.5 * float(recent) - 0.05 * float(book.size()) + 0.4 * float(Owner.extra_staff.size())
	if Campaign.day <= team_until:
		cap += 0.3  # a good team night
	cap -= SalesRival.takeover_load()
	return clampf(cap, 0.5, 3.5)


func promise_gap(lead: Dictionary, q: Dictionary) -> float:
	return Deals.gap(lead, q)


func commission_for(mrr: int) -> int:
	var c := float(mrr) * float(PLAN_RATE.get(plan, 2.0))
	if quota_met():
		c *= ACCEL
	return int(round(c))


# the quote builder is a screen inside the CRM (see quote_builder.gd); the cards that used to ask method, promise and price are gone
func start_quote(id: int) -> void:
	var l := lead_by_id(id)
	if l.is_empty() or not ["LEAD", "MEETING"].has(str(l.stage)):
		Hints.toast("NOTHING TO QUOTE ON THAT ONE.", 2.0)
		return
	if slots_left() < 1:
		Hints.toast("NO SELLING HOURS LEFT THIS WEEK.", 2.5)
		return
	QuoteBuilder.begin(l)
	changed.emit()


# a follow-up call keeps a deal warm: an hour, the last touch resets and a quoted deal is harder for ByteBrothers to take
func follow_up(id: int) -> String:
	var l := lead_by_id(id)
	if l.is_empty() or not is_open(l):
		return "NOTHING TO FOLLOW UP."
	if int(l.get("follow", 0)) >= Deals.MAX_FOLLOW and str(l.stage) == "QUOTED":
		return "YOU HAVE CHASED THIS ONE ENOUGH."
	if not spend(1):
		return "NO SELLING HOURS LEFT."
	l["follow"] = int(l.get("follow", 0)) + 1
	l["quality"] = mini(100, int(l.quality) + 2)
	Deals.touch(l, "FOLLOWED UP")
	changed.emit()
	return "FOLLOWED UP WITH %s" % str(l.who).to_upper()


# the quote goes out: hours and discovery fee are spent, one seeded roll decides: a yes on the spot, "we will think about it" (the
# deal stays QUOTED and ByteBrothers may take it before they answer) or a no
func send_quote(l: Dictionary, q_in: Dictionary) -> void:
	var q := Deals.norm(q_in)
	var hours := int(METHODS[str(q.method)].hours)
	if not spend(hours):
		return
	if str(q.method) == "scope":
		week_cost += DISCOVERY
	week_quotes += 1
	quotes_sent += 1
	q["win"] = win_chance(l, q)
	q["price_week"] = quote_price(l, q)
	q["margin"] = margin_pct(q, l)
	l["quote"] = q.duplicate(true)
	l["margin"] = q.margin
	l["discount"] = q.discount
	l["promises"] = Deals.promise_list(l, q)
	Deals.touch(l, "QUOTE $%d/WK, WIN %d%%" % [int(q.price_week), int(round(100.0 * float(q.win)))])
	var roll := Difficulty.rng("deals").randf()
	var p := float(q.win)
	if roll < p:
		l.stage = "QUOTED"
		close_deal(l, q)
	elif roll < p + (1.0 - p) * Deals.HOLD:
		l.stage = "QUOTED"
		l["quoted_day"] = Campaign.day
		l["follow"] = 0
		Cards.ask(
			str(l.who),
			"Thank you for the proposal. We like it. Give us a few days to talk it over. (We are also talking to ByteBrothers.)",
			[{"label": "I WILL CALL YOU IN A FEW DAYS", "id": "ok"}],
			func(_id: String) -> void: pass
		)
	else:
		l.stage = "LOST"
		l.why = "WENT ELSEWHERE"
		losses += 1
		Cards.ask(
			str(l.who),
			"Thank you for the proposal. We went with another provider: their price was close and the owner's brother-in-law knows a guy. Keep us in mind.",
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
	changed.emit()


func close_deal(l: Dictionary, q_in: Dictionary) -> Dictionary:
	var q := Deals.norm(q_in)
	var mrr := int(q.price_week) if q.has("price_week") else quote_price(l, q)
	if not q.has("margin"):
		q["margin"] = margin_pct(q, l)
	var gap := promise_gap(l, q)
	var com := commission_for(mrr)
	var qi := quarter_index()
	if sandbag and qi == 0 and int(q_signed[0]) >= quota_target(0):
		qi = 1  # the quota is met: Garrison lets the extra deals count in the next quarter
	q_signed[qi] = int(q_signed[qi]) + mrr
	week_new += mrr
	week_deals += 1
	week_commission += com
	commission_total += com
	week_cost += int(Deals.ONBOARD[str(q.onboard)].cost)
	wins += 1
	Career.add("deals_won")
	var promises: Array = l.get("promises", [])
	if promises.is_empty():
		promises = Deals.promise_list(l, q)
	var deal := {
		"id": int(l.id),
		"name": str(l.name),
		"type": str(l.type),
		"who": str(l.who),
		"mrr": mrr,
		"signed_mrr": mrr,
		"margin": float(q.margin),
		"week": Campaign.day,
		"qi": qi,
		"promise": str(q.promise),
		"gap": gap,
		"mood": 72,
		"complain": false,
		"resolved": false,
		"asked": false,
		"discount": int(q.discount),
		"extras": q.extras.duplicate(),
		"onboard": str(q.onboard),
		"promises": promises,
		"commission": com,
		"churn": 10,
		"state": "handover",
		"breaches": 0,
		"onboarded": false,
		"onboard_due": Campaign.day + int(Deals.ONBOARD[str(q.onboard)].weeks),
		"kept": 0,
		"broken": 0,
	}
	SalesRival.stamp(deal, l)
	book.append(deal)
	l.stage = "WON"
	l["promises"] = promises
	Deals.touch(l, "WON $%d/WK" % mrr)
	Sales.deals += 1
	Sales.last_deal = "YOU CLOSED %s!" % str(l.name).to_upper()
	bell_ready = true
	Hints.toast("DEAL! %s SIGNED AT $%d A WEEK. RING THE SALES BELL (E ON IT)." % [str(l.name).to_upper(), mrr], 4.0)
	Hints.objective = "RING THE SALES BELL ON THE MAIN FLOOR WALL (E)"
	Cards.ask(
		str(l.who),
		"We are in. Send the paperwork. Weekly fee $%d, signed for twelve months. Your commission is $%d." % [mrr, com],
		[{"label": "THANK YOU", "id": "ok"}],
		func(_id: String) -> void: Handover.queue(deal)
	)
	changed.emit()
	return deal


# the old three-answer handover maps onto the promise list: tell the real SLA = renegotiate everything, brief them = keep everything,
# send the paperwork = drop everything. A deal without a promise list (an old save) uses the original arithmetic.
func handover(deal: Dictionary, how: String) -> void:
	if not deal.get("promises", []).is_empty():
		Handover.decide_all(deal, {"honest": "renegotiated", "brief": "kept"}.get(how, "dropped"))
		Handover.finish(deal, false)
		return
	var gap: float = float(deal.gap)
	match how:
		"honest":
			deal["gap"] = 0.0
			Social.change("Dan", 1)
			Social.change("Morgan", 1)
		"brief":
			deal["gap"] = snappedf(gap * 0.5, 0.1)
			Social.change("Dan", 1)
			Social.change("Morgan", 1)
		_:
			if gap >= 0.5:
				Social.change("Dan", -1)
	var g: float = float(deal.gap)
	deal["mood"] = clampi(72 - int(round(g * 8.0)) - (2 if how == "honest" and gap >= 0.5 else 0), 25, 85)
	deal["complain"] = g >= 0.5
	deal["state"] = "active"
	changed.emit()


func _complaint_card(deal: Dictionary) -> void:
	complaints += 1
	Cards.ask(
		"{ops}",
		"%s has called Dan twice. You told them %s and they are not getting it. They are asking for you." % [str(deal.name), str(PROMISES[str(deal.promise)].label).to_lower()],
		[
			{"label": "OWN IT: CALL THEM TODAY", "id": "own"},
			{"label": "TELL THEM THE QUEUE IS BUSY", "id": "blame"},
			{"label": "ASK DAN TO JUMP THEIR TICKETS", "id": "dan"},
		],
		func(id: String) -> void: resolve_complaint(deal, id)
	)


func resolve_complaint(deal: Dictionary, id: String) -> void:
	deal["resolved"] = true
	deal["gap"] = 0.0
	match id:
		"own":
			deal["mood"] = clampi(int(deal.mood) + 10, 0, 100)
			Social.change("Morgan", 1)
		"dan":
			deal["mood"] = clampi(int(deal.mood) + 6, 0, 100)
			Social.change("Dan", -1)
		_:
			deal["mood"] = clampi(int(deal.mood) - 8, 0, 100)
	changed.emit()


# ---- calls and visits ----------------------------------------------------------------------------------
func call_lead(id: int) -> String:
	var l := lead_by_id(id)
	if l.is_empty() or not ["LEAD", "MEETING"].has(str(l.stage)):
		return "NOTHING TO CALL."
	if bool(l.called):
		return "YOU ALREADY CALLED THEM."
	if not spend(1):
		return "NO SELLING HOURS LEFT."
	l.called = true
	l.stage = "MEETING"
	l.quality = mini(100, int(l.quality) + 5)
	SalesRival.on_call(l)
	Deals.touch(l, "CALLED")
	week_calls += 1
	changed.emit()
	return "CALLED %s: %s" % [str(l.who).to_upper(), str(l.pain).to_upper()]


# hours a visit needs: the drive there and back plus an hour in the owner's office
func visit_hours(l: Dictionary) -> int:
	var key := site_key(str(l.type))
	return int(ceil(float(Onsite.estimate_minutes(key) * 2) / 60.0 + 1.0))


func site_key(type: String) -> int:
	for k in Onsite.SITES:
		if str(Onsite.SITES[k].type) == type:
			return int(k)
	return 0


func door_leads() -> Array:
	var out := []
	for l in open_leads():
		if bool(l.site) and ["LEAD", "MEETING"].has(str(l.stage)):
			out.append(l)
	return out


func can_visit(l: Dictionary) -> String:
	if not bool(l.site):
		return "PHONE ONLY"
	if not ["LEAD", "MEETING"].has(str(l.stage)):
		return "NOT A MEETING STAGE LEAD"
	if bool(l.visited):
		return "ALREADY VISITED"
	if slots_left() < visit_hours(l):
		return "NEEDS %d HOURS" % visit_hours(l)
	return ""


# the front door in the sales campaign lists your leads with a site
func offer_door() -> void:
	if Cards.is_open or Game.ui_open or Onsite.active:
		return
	var options := []
	for l in door_leads().slice(0, 4):
		var why := can_visit(l)
		options.append(
			{
				"label": ("TO %s (%d MIN)" % [str(l.name).to_upper(), Onsite.estimate_minutes(site_key(str(l.type)))]).left(44),
				"id": "v%d" % int(l.id),
				"enabled": why == "",
				"hint": why,
			}
		)
	options.append({"label": "STAY HERE", "id": "leave"})
	Cards.ask(
		"Front door",
		"Where to? The van is out front. %s." % Onsite.traffic_label() + (" Your meetings are the leads below." if options.size() > 1 else " You have no lead to visit right now."),
		options,
		func(id: String) -> void:
			if id.begins_with("v"):
				visit(int(id.substr(1)))
	)


func visit(id: int) -> void:
	var l := lead_by_id(id)
	if l.is_empty() or can_visit(l) != "":
		return
	var key := site_key(str(l.type))
	Cards.ask(
		"Dispatch",
		"Drive to %s? About %d minutes each way. Meeting their owner takes an hour. %s" % [str(l.name), Onsite.estimate_minutes(key), Onsite._risk_text(key)],
		[{"label": "GO NOW", "id": "go"}, {"label": "LATER", "id": "leave"}],
		func(pick: String) -> void:
			if pick == "go":
				_go(l, key)
	)


func _go(l: Dictionary, key: int) -> void:
	if Computer.is_open:
		Computer.close()
	visit_lead = int(l.id)
	SalesRival.on_visit(l)
	week_visits += 1
	Onsite.start_visit(key, "discovery" if str(l.get("story", "")) == "paws" else "pitch")


func visit_name(default_name: String) -> String:
	if not visit_entry.is_empty():
		return str(visit_entry.get("name", default_name))
	var l := lead_by_id(visit_lead)
	return default_name if l.is_empty() else str(l.name)


func visit_owner() -> String:
	if not visit_entry.is_empty():
		return str(visit_entry.get("who", ""))
	var l := lead_by_id(visit_lead)
	return "" if l.is_empty() else str(l.who)


# the pitch answer in the owner's office (Onsite._meeting_answer calls this in the sales campaign)
func pitch_answer(id: String, text: String) -> void:
	var l := lead_by_id(visit_lead)
	if l.is_empty():
		return
	l.visited = true
	l.stage = "MEETING"
	Deals.touch(l, "VISITED THE OFFICE")
	match id:
		"report":
			l.quality = mini(100, int(l.quality) + 6)
		"pain":
			l.quality = mini(100, int(l.quality) + 10 + int(round(Build.sales_fx("pain"))))
		_:
			l.quality = mini(100, int(l.quality) + 14)
			l.moon = true
			text += " Now they expect it."
	World.clock = minf(23.0, World.clock + 1.0)
	Cards.ask(str(l.who), text + " They ask you to send a quote.", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	changed.emit()


func visit_end() -> void:
	var l := lead_by_id(visit_lead)
	visit_lead = 0
	visit_entry = {}
	qbr_renewal = false
	if not l.is_empty() and bool(l.visited):
		Hints.toast("BACK AT THE OFFICE. QUOTE %s IN SALESHOUND." % str(l.name).to_upper(), 4.0)


# ---- the business review at the client's office (C3) -----------------------------------------------------------
# a book client has no site of its own: the review happens in the client's own office when the client index has a site (Acme Dental,
# Hoot and Holler ...), else in the b skin office of its kind (a stand-in), and counts like the card version
func qbr_site(e: Dictionary) -> Dictionary:
	var c := int(e.get("client", -1))
	if c >= 0 and Onsite.has_site(c):
		return {"key": c, "stand": false}
	var type := str(e.get("type", QBR_TYPE.get(c, "dental")))
	return {"key": site_key(type), "stand": true}


func qbr_minutes(e: Dictionary) -> int:
	return Onsite.estimate_minutes(int(qbr_site(e).key))


func qbr_hours(e: Dictionary) -> int:
	return int(ceil(float(qbr_minutes(e) * 2) / 60.0 + 1.0))


func can_qbr_visit(e: Dictionary) -> String:
	if Onsite.active or Onsite.busy:
		return "YOU ARE ALREADY OUT"
	if slots_left() < qbr_hours(e):
		return "NEEDS %d HOURS" % qbr_hours(e)
	return ""


func qbr_visit(e: Dictionary, renewal := true) -> void:
	if can_qbr_visit(e) != "":
		return
	var site := qbr_site(e)
	visit_entry = e
	visit_lead = int(e.id) if int(e.id) > 0 else 0
	qbr_renewal = renewal
	week_visits += 1
	if Computer.is_open:
		Computer.close()
	Onsite.start_visit(int(site.key), "qbr", bool(site.stand))


# the owner's answer at the review (Onsite._meeting_answer): the text card first, then the effects
func qbr_answer(id: String, text: String) -> void:
	var e := visit_entry
	if e.is_empty():
		return
	World.clock = minf(23.0, World.clock + 1.0)
	e["qbr_week"] = Campaign.day
	var renewal := qbr_renewal
	Cards.ask(str(e.get("who", "The owner")), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: qbr_apply(e, id, renewal, true))


# the phone version: the same three talks as a card
func qbr_card(e: Dictionary, renewal: bool) -> void:
	var mt: Dictionary = Onsite.MEETINGS.get("qbr", {})
	var options := []
	for o in mt.get("options", []):
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(str(e.get("who", "The owner")), str(mt.get("text", "It is review time.")), options, func(id: String) -> void: qbr_apply(e, id, renewal, false))


func qbr_apply(e: Dictionary, id: String, renewal: bool, in_person: bool) -> void:
	Career.add("qbrs")
	var bonus := 0.0
	match id:
		"numbers":
			Retention.adjust_mood(e, 6)
			bonus = 0.08
		"listen":
			Retention.adjust_mood(e, 10)
			bonus = 0.12
		_:
			Retention.adjust_mood(e, 3)
			bonus = 0.05
	if in_person:
		bonus += 0.04
	var finish := func() -> void:
		if renewal:
			Retention.renew_roll(e, bonus, false)
		else:
			e["qbr_bonus"] = float(e.get("qbr_bonus", 0.0)) + bonus * 0.5
		changed.emit()
	if id == "service":
		Retention.upsell_card(e, finish)
	else:
		finish.call()


# the finding at the Paws and Claws discovery visit (Onsite._found)
func discovery_found(f: Dictionary) -> void:
	SalesBeats.discovery_found(f)


# ---- outings: a team night and the dinner with a prospect (C3) ----------------------------------------------------
func outing_kind() -> String:
	if not in_mode():
		return ""
	var day := Campaign.day
	if SalesBeats.TEAM_WEEKS.has(day):
		return "team"
	if SalesBeats.DINNER_WEEKS.has(day) and not dinner_lead().is_empty():
		return "client"
	return ""


# the lead you would take to dinner: the best open one
func dinner_lead() -> Dictionary:
	var best := {}
	for l in open_leads():
		if best.is_empty() or int(l.quality) > int(best.quality):
			best = l
	return best


func outing_text() -> String:
	if outing_kind() == "client":
		var l := dinner_lead()
		flags["dinner_lead"] = int(l.id)
		return str(BEAT_TEXT.outing.client.text) % str(l.name)
	return str(BEAT_TEXT.outing.team.text)


# the outing is over: what it did for the book (the lines go on the result page)
func outing_done(game: String, stars: int) -> Array:
	var out := []
	if outing_kind() == "client" and game == "dinner" and flags.has("dinner_lead"):
		var l := lead_by_id(int(flags.dinner_lead))
		if not l.is_empty():
			var gain: int = [-4, 6, 11, 16][clampi(stars, 0, 3)] if stars >= 0 else -6
			l["quality"] = clampi(int(l.quality) + gain, 0, 100)
			Deals.touch(l, "DINNER, %d STARS" % maxi(stars, 0))
			if stars >= 2 and str(l.stage) == "QUOTED":
				l["follow"] = int(l.get("follow", 0)) + 1
			out.append((str(BEAT_TEXT.outing.client_done) % [str(l.name).to_upper(), gain]) if gain > 0 else (str(BEAT_TEXT.outing.client_bad) % str(l.name).to_upper()))
			flags["dinners"] = int(flags.get("dinners", 0)) + 1
	elif outing_kind() == "team":
		flags["team_nights"] = int(flags.get("team_nights", 0)) + 1
		Social.change("Dan", 1)
		Social.change("Morgan", 1)
		if stars >= 2:
			team_until = Campaign.day + 2
			out.append(str(BEAT_TEXT.outing.team_done))
	return out


# ---- the sales bell ----------------------------------------------------------------------------------
func ring_bell(fx: Node) -> bool:
	if not (in_mode() and Campaign.player_as == "John"):
		return false
	if not bell_ready:
		Hints.toast("NO DEAL TO CELEBRATE YET. CLOSE ONE.", 2.5)
		return true
	bell_ready = false
	bell_rings += 1
	Hints.objective = ""
	if pending_handover != 0:
		Handover._objective()
	fx.ring("player")
	Social.change_all(1)
	Campaign.adjust_rep(1)
	return true


# ---- the people and the book --------------------------------------------------------------------------
func client_mood() -> float:
	var total := Sales.average() * float(Sales.active.size())
	var n := Sales.active.size()
	for d in book:
		total += float(d.mood)
		n += 1
	return total / float(maxi(1, n))


func extra_load() -> float:
	return 0.1 * float(book.size()) if in_mode() else 0.0


# ---- the week closes -----------------------------------------------------------------------------------
func _grade(ratio: float) -> String:
	if ratio >= 1.25:
		return "S"
	if ratio >= 1.0:
		return "A"
	if ratio >= 0.75:
		return "B"
	if ratio >= 0.5:
		return "C"
	return "D"


# clients of the new book whose churn meter is in the red
func at_risk() -> int:
	var n := 0
	for d in book:
		if int(d.get("churn", 0)) >= 60:
			n += 1
	return n


func settle() -> Dictionary:
	var day := Campaign.day
	_hire_for_book()
	# the book: new clients settle in, unkept promises wear them down, then the 90 day clock ticks (a client may leave)
	for d in book:
		if int(d.week) == day:
			continue
		var drift := 1
		if float(d.gap) >= 0.5 and not bool(d.resolved):
			drift = -2
		if Sales.average() < 55.0:
			drift -= 1
		d["mood"] = clampi(int(d.mood) + drift, 0, 100)
	Retention.week_tick(day)
	var est: Dictionary = Owner.weekly_estimate()
	var serve := 0
	for d in book:
		serve += int(round(float(d.mrr) * (1.0 - float(d.margin))))
	var revenue := Mutators.cash(int(est.revenue) + book_mrr() - lost_base + expansion_base)
	var profit := revenue - int(est.payroll) - int(est.fixed) - serve - week_commission - week_cost + week_clawback - raise_wage
	Owner.cash += profit
	week_distrib = 0
	if Owner.cash > CASH_CAP:
		week_distrib = Owner.cash - CASH_CAP
		distributed += week_distrib
		Owner.cash = CASH_CAP  # the owners take the rest out as a distribution
	Owner.history.append({"day": day, "profit": profit, "ebitda": profit, "cash": Owner.cash})
	var qi := quarter_index(day)
	var q: Dictionary = QUARTERS[qi]
	var pct := quota_pct(qi)
	var ratio := (float(pct) / 100.0) / maxf(elapsed(day), 0.34)
	var grade := _grade(ratio)
	var verdict := "BEHIND PACE"
	if ratio >= 1.25:
		verdict = "WELL AHEAD OF QUOTA"
	elif ratio >= 1.0:
		verdict = "ON PACE FOR QUOTA"
	elif ratio >= 0.75:
		verdict = "A LITTLE BEHIND"
	elif ratio < 0.5:
		verdict = "FAR BEHIND. GARRISON IS WATCHING"
	var closing := day == int(q.to)
	if closing:
		q_result[qi] = "HIT" if pct >= 100 else "MISS"
		verdict = "%s %s AT %d%%" % [str(q.label), "HIT" if pct >= 100 else "MISSED", pct]
		if q_result[qi] == "MISS" and qi == 0:
			warned = true
			verdict += Difficulty.ct("coach_first") if Difficulty.cozy_on() else ": WARNING"
		elif q_result[qi] == "MISS":
			verdict += Difficulty.ct("coach_second") if Difficulty.cozy_on() else (": SECOND MISS, THE YEAR HELD AT %d%%" % int(100.0 * year_share()) if year_saves() else ": SECOND MISS")
		_lynk("Garrison", "Quarter closed at %d%%. %s" % [pct, "Good work." if pct >= 100 else "We need to talk."])
	var mood := client_mood()
	var grade_rep: Dictionary = {"S": 2, "A": 1, "B": 0, "C": -1, "D": -2}
	var rep_delta: int = int(grade_rep[grade]) + (1 if mood >= 80.0 else (-1 if mood < 50.0 else 0))
	var red := Color("ff8a80")
	var green := Color("8fe3a0")
	var warn := Color("ffd27a")
	var rows := [
		["NEW MRR SIGNED", "$%d/WK (%d DEAL%s)" % [week_new, week_deals, "" if week_deals == 1 else "S"], green if week_new > 0 else warn],
		["PIPELINE VALUE", "$%d/WK, %d LEADS" % [pipeline_value(), open_leads().size()], Color.WHITE],
		["QUOTA %s" % str(q.label), "%d%% ($%d/$%d)" % [pct, int(q_signed[qi]), quota_target(qi)], green if pct >= 100 else (warn if ratio >= 0.75 else red)],
		["COMMISSION EARNED", "$%d ($%d TOTAL)%s" % [week_commission, commission_total, (", -$%d CLAWED BACK" % week_clawback) if week_clawback > 0 else ""], red if week_clawback > 0 else (green if week_commission > 0 else Color.WHITE)],
		["CLIENT MOOD", "%d%% (%d NEW)" % [int(mood), book.size()], green if mood >= 70.0 else (red if mood < 50.0 else warn)],
		["SELLING HOURS", "%d CALLS, %d VISITS, %d QUOTES" % [week_calls, week_visits, week_quotes], Color.WHITE],
		["NEW BOOK", "$%d/WK, %d CLIENT%s, %d AT RISK" % [book_mrr(), book.size(), "" if book.size() == 1 else "S", at_risk()], Color.WHITE],
		["COMPANY", "EBITDA %s, CASH %s%s" % [_money(profit), _money(Owner.cash), (" (CAP)" if week_distrib > 0 else "")], green if profit >= 0 else red],
		["VERDICT", verdict, red if grade in ["C", "D"] or (closing and q_result[qi] == "MISS") else green],
	]
	if warned and q_result[0] == "MISS" and day > int(QUARTERS[0].to):
		if Difficulty.cozy_on():
			rows.append([Difficulty.ct("coach_row"), Difficulty.ct("coach_text"), warn])
		else:
			var keep := Difficulty.cf("sales.keep")  # X13: on hard the whole year can still save the job
			rows.append(["PERFORMANCE WARNING", ("MISS AGAIN UNDER %d%% OF THE YEAR AND YOU ARE OUT" % int(100.0 * keep)) if keep > 0.0 else "ONE MORE MISSED QUARTER AND YOU ARE OUT", red])
	last_report = verdict
	return {
		"rows": rows,
		"title": "WEEK %d OF %d COMPLETE" % [day, Campaign.total_days()],
		"grade": grade,
		"profit": profit,
		"bankrupt": Owner.cash < Owner.BANKRUPT,
		"rep_delta": rep_delta,
	}


# the company cannot take on a book this size with Dan and Maya alone: one more tech for every five new clients
const NEW_HIRES := ["Sam", "Priya", "Jo"]


func _hire_for_book() -> void:
	while Owner.extra_staff.size() < mini(book.size() / 5, NEW_HIRES.size()):
		var who: String = NEW_HIRES[Owner.extra_staff.size()]
		Owner.extra_staff.append({"name": who, "skill": 0.7, "wage": 450, "trait": "steady", "age": 0})
		Msp.send_text("Morgan", "We hired %s to cover the new accounts. Keep the promises realistic." % who)


func _money(n: int) -> String:
	return "%s$%d" % ["-" if n < 0 else "", absi(n)]


# ---- the verdict (week 20) -----------------------------------------------------------------------------
func pip_failed() -> bool:
	return q_result[0] == "MISS" and q_result[1] == "MISS" and not year_saves()


# X13: how much of the year's two quotas together was signed (1.0 = both targets)
func year_share() -> float:
	return float(int(q_signed[0]) + int(q_signed[1])) / float(maxi(1, quota_target(0) + quota_target(1)))


# X13 (Difficulty `sales.keep`, hard only): the hard quota is a fifth higher than the plan needs, so two missed quarters only end
# the job there when the year as a whole came in under this share of it. 0 = off: two misses are the end (easy, normal).
func year_saves() -> bool:
	if Difficulty.cozy_on():
		return true  # cozy Easy: nobody is fired, two missed quarters do not end the job (the coach text on the report says so)
	var keep := Difficulty.cf("sales.keep")
	return keep > 0.0 and year_share() >= keep - 0.0001


func director_ok() -> bool:
	var total_target: int = quota_target(0) + quota_target(1)
	var total: int = int(q_signed[0]) + int(q_signed[1])
	return (
		q_result[1] == "HIT"
		and (q_result[0] == "HIT" or float(total) >= 0.9 * float(total_target))
		and client_mood() >= 60.0
		and Campaign.rep >= 55
		and SalesBeats.churn_low()
		and SalesRival.conscience_ok()
	)


func offers() -> Array:
	var out := []
	var leave := {"id": "leave", "label": "TAKE YOUR BOOK TO BYTEBROTHERS", "desc": "THEY OFFER MORE MONEY. THE CLIENTS WILL FOLLOW YOU, OR NOT."}
	if SalesBeats.bb_signed():
		return [leave]  # you gave notice at week 18: the promotion is off the table
	if pip_failed():
		out.append({"id": "let_go", "label": "CLEAN OUT YOUR DESK", "desc": "TWO MISSED QUARTERS. GARRISON WALKS YOU TO THE FRONT DOOR."})
	else:
		if director_ok():
			out.append({"id": "director", "label": "BECOME SALES DIRECTOR", "desc": "GARRISON GIVES YOU THE TEAM AND THE TERRITORY. ALAN SIGNS OFF ON THE MARGIN."})
		out.append({"id": "stay", "label": "STAY ON AS ACCOUNT MANAGER", "desc": "SAME DESK, A BIGGER BOOK AND A QUOTA FOR NEXT YEAR."})
		if SalesBeats.rollup_ok():
			out.append({"id": "rollup", "label": "JOIN THE ROLL-UP (SUMMIT)", "desc": "SUMMIT MANAGED HOLDINGS BUYS THE COMPANY. YOUR EARN-OUT IS $%d AND DEPENDS ON RETENTION (%d%%)." % [SalesBeats.earn_out(), SalesBeats.retention_pct()]})
	if SalesBeats.bb_open():
		out.append(leave)
	return out


# the epilogue of an ending (the text is BEAT_TEXT.endings); ByteBrothers and the roll-up read the book
func epilogue(ending: String) -> String:
	var t: Dictionary = BEAT_TEXT.endings
	if ending == "leave":
		return str(t.leave_followed if (client_mood() >= 65.0 and clawbacks == 0) else (t.leave_alone if client_mood() < 50.0 else t.leave))
	if ending == "rollup":
		return str(t.rollup) % SalesBeats.earn_out()
	return str(t.get(ending, Yeartwo.ending_text(ending)))  # R10: a Year 3 ending's epilogue is Yeartwo's
const DEFAULT_QUOTE := "DOES THE JOB. HARD TO READ."


func review_lines(page: int, ending: String) -> Array:
	var ink := Color("17121f")
	var blue := Color("1f4e8c")
	var good := Color("1f7a3a")
	var bad := Color("b3262c")
	var lines := []
	match page:
		0:
			lines.append(["GARRISON AND ALAN - SALES REVIEW", blue])
			lines.append(["TWENTY WEEKS IN THE TERRITORY. HERE IS THE BOOK.", ink])
			for qi in 2:
				var res := str(q_result[qi])
				lines.append(
					[
						"QUOTA %s: %d%% ($%d OF $%d) %s" % [str(QUARTERS[qi].label), quota_pct(qi), int(q_signed[qi]), quota_target(qi), res],
						good if res == "HIT" else (bad if res == "MISS" else ink),
					]
				)
			if q_result[0] == "MISS" and q_result[1] == "MISS" and year_saves():
				lines.append(["THE YEAR: %d%% OF BOTH QUOTAS TOGETHER. ENOUGH TO STAY." % int(100.0 * year_share()), ink])  # X13
			lines.append(["DEALS WON %d  QUOTES LOST %d  COMMISSION $%d" % [wins, losses, commission_total], ink])
			lines.append(["BOOK: $%d A WEEK NEW, CLIENT MOOD %d%%" % [book_mrr(), int(client_mood())], good if client_mood() >= 60.0 else bad])
			lines.append(["PROMISE COMPLAINTS %d  GARRISON TRUST %d" % [complaints, Campaign.rep], ink])
			lines.append(["STORY: " + story_summary(), ink])
			lines.append([SalesRival.lies_line(), bad if (SalesRival.lies() > 0 or not SalesRival.conscience_ok()) else ink])
			if not Build.is_flat(Build.cur()):
				lines.append([Build.describe(Build.cur(), "sales", "John"), ink])
			lines.append(["CLAWBACKS %d ($%d)  RENEWALS %d WON %d LOST  UPSELLS %d  RIVAL WINS %d" % [clawbacks, clawed_total, renewals_won, renewals_lost, upsells, rival_wins], bad if clawbacks > 0 else ink])
		1:
			lines.append(["WHAT THE OWNERS AND YOUR TEAM SAY", blue])
			for who in Social.people():
				var quotes: Dictionary = Review.OWNER_QUOTES if Social.is_owner(who) else Review.QUOTES
				lines.append(["%s (%s):" % [who.to_upper(), Social.mood(who)], blue])
				lines.append(["'%s'" % str(quotes.get(Social.mood(who), DEFAULT_QUOTE)), ink])
		2:
			lines.append(["YOUR OPTIONS", blue])
		_:
			lines.append(["THE END", blue])
			lines.append([epilogue(ending), ink])
	return lines


# one line for the review: what you did at the beats
func story_summary() -> String:
	var parts := []
	if str(flags.get("bb", "")) != "":
		parts.append("BB " + str(flags.bb).to_upper())
	if str(flags.get("dd", "")) != "":
		parts.append("AUDIT " + str(flags.dd).to_upper())
	parts.append("KEPT %d%%" % SalesBeats.retention_pct())
	return ", ".join(parts)


func to_dict() -> Dictionary:
	return {
		"flags": flags,
		"raise_wage": raise_wage,
		"sandbag": sandbag,
		"team_until": team_until,
		"distributed": distributed,
		"leads": leads,
		"book": book,
		"next_id": next_id,
		"used": used_names,
		"quota": quota_level,
		"plan": plan,
		"floor": margin_floor,
		"crunch": crunch,
		"q_signed": q_signed,
		"q_result": q_result,
		"warned": warned,
		"commission": commission_total,
		"wins": wins,
		"losses": losses,
		"quotes": quotes_sent,
		"complaints": complaints,
		"bell": bell_ready,
		"rings": bell_rings,
		"rival_wins": rival_wins,
		"clawbacks": clawbacks,
		"clawed": clawed_total,
		"churned": churned,
		"base_book": base_book,
		"base_ready": base_ready,
		"lost_base": lost_base,
		"exp_base": expansion_base,
		"expansion": expansion_total,
		"renewals_won": renewals_won,
		"renewals_lost": renewals_lost,
		"upsells": upsells,
		"handovers": handovers,
		"pending": pending_handover,
		"hqueue": handover_queue,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	flags = data.get("flags", {})
	raise_wage = int(data.get("raise_wage", 0))
	sandbag = bool(data.get("sandbag", false))
	team_until = int(data.get("team_until", 0))
	distributed = int(data.get("distributed", 0))
	leads = data.get("leads", [])
	book = data.get("book", [])
	next_id = int(data.get("next_id", 1))
	used_names = data.get("used", [])
	quota_level = str(data.get("quota", DEFAULT_QUOTA))
	plan = str(data.get("plan", "balanced"))
	margin_floor = float(data.get("floor", DEFAULT_FLOOR))
	crunch = bool(data.get("crunch", false))
	q_signed = data.get("q_signed", [0, 0])
	q_result = data.get("q_result", ["", ""])
	warned = bool(data.get("warned", false))
	commission_total = int(data.get("commission", 0))
	wins = int(data.get("wins", 0))
	losses = int(data.get("losses", 0))
	quotes_sent = int(data.get("quotes", 0))
	complaints = int(data.get("complaints", 0))
	bell_ready = bool(data.get("bell", false))
	bell_rings = int(data.get("rings", 0))
	rival_wins = int(data.get("rival_wins", 0))
	clawbacks = int(data.get("clawbacks", 0))
	clawed_total = int(data.get("clawed", 0))
	churned = data.get("churned", [])
	base_book = data.get("base_book", [])
	base_ready = bool(data.get("base_ready", false))
	lost_base = int(data.get("lost_base", 0))
	expansion_base = int(data.get("exp_base", 0))
	expansion_total = int(data.get("expansion", 0))
	renewals_won = int(data.get("renewals_won", 0))
	renewals_lost = int(data.get("renewals_lost", 0))
	upsells = int(data.get("upsells", 0))
	handovers = int(data.get("handovers", 0))
	pending_handover = int(data.get("pending", 0))
	handover_queue = data.get("hqueue", [])
