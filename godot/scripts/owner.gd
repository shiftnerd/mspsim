extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# The owner campaign: you run Pixel IT Partners as one of its two owners (Alan or Garrison). Each campaign "day" is a week of the business. Your crew (Dan, Maya,
# plus anyone you hire; Morgan manages the desk and your partner helps at half speed) works the ticket queue on their own at a speed set by the team; you make the
# business decisions as Cards (pricing, backups, hiring, quotes, vendors, crises) and watch cash, clients and
# reputation. Each week ends with a P&L report; week 20 is the board review (sell, expand or stay independent).
# Clients' moods (Sales) still drive churn, John still signs clients and brings complaints, and the same story beats
# (backups, ransomware, the rack, the migration, the 24x7 email outage...) happen to you as decisions.

const Dash := preload("res://scripts/dash.gd")  # the metrics record (R20): the crew's hours per day
const Incident := preload("res://scripts/incident.gd")  # R37: wire fraud and the post-incident review
const ByName := preload("res://scripts/byname.gd")  # R36: clients who ask for one tech by name
const OwnerCast := preload("res://scripts/owner_cast.gd")  # X11: Jen's and Michael's decision cards
const Rival := preload("res://scripts/rival.gd")  # R38: the rap sheet of the rival MSPs
const Habits := preload("res://scripts/habits.gd")  # R38: the good habits and the Standard
const Temptation := preload("res://scripts/temptation.gd")  # R38: shortcuts, skeletons, the conscience
const Takeover := preload("res://scripts/takeover.gd")  # R38: inherited messes
const RivalCards := preload("res://scripts/rival_cards.gd")  # R38: the rival arc and temptation cards (data)
const START_CASH := 7500
const FEE := 800  # weekly fee per client at standard pricing
const WAGE := 650  # a tech's weekly wage
const W2_TARGET := 0.55  # payroll as a share of revenue: healthy MSPs stay under this
const PEER_MARGIN := 0.15  # the peer group's typical EBITDA margin
const RENT := 500
const SEAT_COST := 55  # weekly cost of each client past five (licences, desks, insurance, a bigger line)
const ADVICE_GAP := 3  # weeks before Dana opens the same advice card again
const HIRE_RAMP_WEEKS := 3  # a new hire costs 60% of the wage for the first weeks
const TOOLS := 0  # tool costs now come from the stack
const DEFAULT_STACK := {"psa": "connectwhy", "rmm": "labrat", "hardware": "hewlitt"}
# What you run and sell. cost = weekly, speed = tech speed, morale = % effect on the crew, issues = ticket volume
# multiplier (bad hardware = more tickets), sales = John's close rate, margin = hardware resale profit per deal.
const STACK := {
	"psa":
	{
		# multiplier (bad hardware = more tickets), sales = John's close rate, margin = hardware resale profit per deal.
		"label": "PSA",
		"options":
		{
			"connectwhy":
			{
				"name": "ConnectWhy PSA",
				"cost": 60,
				"speed": 0.0,
				"morale": 0,
				"note": "THE STANDARD"
			},
			"ticketo":
			{
				"name": "Ticketo Lite",
				"cost": 15,
				"speed": -0.15,
				"morale": -8,
				"note": "CHEAP, THE CREW HATES IT"
			},
			"opsforge":
			{
				"name": "OpsForge Pro",
				"cost": 140,
				"speed": 0.1,
				"morale": 4,
				"note": "AUTOMATION THEY LOVE"
			},
		}
	},
	"rmm":
	{
		"label": "RMM",
		"options":
		{
			"labrat":
			{
				"name": "LabRat RMM",
				"cost": 80,
				"speed": 0.0,
				"morale": 0,
				"issues": 1.0,
				"risk": 1.0,
				"patching": 1.0,
				"note": "THE STANDARD"
			},
			"snoutech":
			{
				"name": "SnoutTech Basic",
				"cost": 25,
				"speed": -0.1,
				"morale": -4,
				"issues": 1.1,
				"risk": 1.5,
				"patching": 0.0,
				"note": "CHEAP, MISSES THINGS"
			},
			"labrat_gold":
			{
				"name": "LabRat Gold",
				"cost": 180,
				"speed": 0.15,
				"morale": 2,
				"issues": 0.9,
				"risk": 0.8,
				"patching": 3.0,
				"note": "CATCHES PROBLEMS EARLY"
			},
		}
	},
	"hardware":
	{
		"label": "HARDWARE",
		"options":
		{
			"hewlitt":
			{
				"name": "Hewlitt Packerd",
				"cost": 0,
				"issues": 1.0,
				"sales": 0.0,
				"margin": 200,
				"note": "THE STANDARD"
			},
			"dellight":
			{
				"name": "DellightCo Premium",
				"cost": 0,
				"issues": 0.85,
				"sales": -0.05,
				"margin": 350,
				"note": "SOLID, HARDER TO SELL"
			},
			"budgetbyte":
			{
				"name": "BudgetByte Value",
				"cost": 0,
				"issues": 1.35,
				"sales": 0.12,
				"margin": 120,
				"morale": -3,
				"note": "EASY SELL, FAILS OFTEN"
			},
		}
	},
}
const NAMES := [
	"Priya",
	"Marcus",
	"Jules",
	"Tomas",
	"Wendy",
	"Dev",
	"Rosa",
	"Kofi",
	"Ingrid",
	"Sal",
	"Mei",
	"Otis"
]
const TRAITS := {
	"wizard": {"label": "POWERSHELL WIZARD", "wage": 30},
	"people": {"label": "GREAT WITH CLIENTS", "mood": 1},
	"green": {"label": "GREEN BUT EAGER", "grow": 0.04, "wage": -40},
	"flight": {"label": "FLIGHT RISK", "quit": 0.06, "wage": -30},
	"steady": {"label": "STEADY AND RELIABLE"},
}
const SLOW_PAYERS := {2: 2, 6: 3, 7: 3}  # client -> weeks they pay late
const VIC_PLANS := {
	"salary": {"label": "SALARY ONLY", "wage": 750, "per_deal": 0, "skill": 0.0, "start_mood": 75},
	"balanced":
	{"label": "BALANCED", "wage": 550, "per_deal": 150, "skill": 0.05, "start_mood": 68},
	"commission":
	{"label": "COMMISSION-HEAVY", "wage": 350, "per_deal": 300, "skill": 0.12, "start_mood": 58},
}
const BANKRUPT := -3000
const COMPETITOR := "ByteBrothers"  # the rival MSP that circles your clients
const HEAVY := {2: 2.0, 7: 2.0}  # clients whose requests creep: they generate twice the tickets until you enforce the scope
const COST_PER_SEC := 2.9  # what a tech-second of work costs you (wages / capacity)
const OML_NAMES := ["BEGINNING", "EMERGING", "SCALING", "OPTIMIZING", "INNOVATING"]
const GOALS := {
	"w2": "W-2 RATIO UNDER 60%",
	"mood": "AVERAGE CLIENT MOOD 70% OR BETTER",
	"ar": "RECEIVABLES UNDER $1,500",
}
const WORK := {1: 180.0, 2: 140.0, 3: 100.0, 4: 72.0}  # tech-seconds a ticket needs, by priority
const JUNIOR := {"name": "Sam", "skill": 0.7, "wage": 450}
# X4: you are one of the two owners. The crew you manage is Dan, Maya and the hires, with Morgan as the manager (she does not
# work tickets but keeps the desk moving) and your partner helping at roughly half speed. The owners take a draw, not a wage.
const CREW := [{"name": "Dan", "skill": 1.2, "wage": 650}, {"name": "Maya", "skill": 1.0, "wage": 550}]
const MORGAN_WAGE := 750
const MANAGER_BOOST := 1.1  # a manager who runs the desk makes the same crew about 10% faster
const MAX_LOST := 1  # of the two employees at most one quits (hires can leave too)
const DRAW := {"none": 0, "small": 300, "normal": 600, "generous": 1000}  # weekly, for both owners together
const DRAW_START := 3  # the first week a draw is paid
const DRAW_FLOOR := 2000  # a draw that leaves less cash than this upsets Christy and the partner
const OUTING_BURN := 3.0  # extra burnout relief an outing gives the owner whose edge is culture
# what each owner is good and bad at (X4). Every number is read by an existing function through Owner.edge(key):
#   close_miss  chance a finished ticket comes back (was 7%)      rdp / stack_risk  break-in and vendor-breach odds multipliers
#   issues      ticket volume multiplier (stack choices)           backup_check      weekly chance a failed backup is noticed
#   marketing   marketing effect multiplier                        fee_accept        chance a fee rise is accepted (added)
#   qbr         business review success (added)                    new_mood          mood new clients start with (added)
#   poach       competitor poach risk (added)                      patch             patch debt grows this fast
#   morale      added to the crew's tool morale (%)                outing_relief     multiplier on burnout relief from outings
const OWNER_EDGES := {
	"Alan":
	{
		"close_miss": 0.04, "rdp": 0.8, "stack_risk": 0.85, "issues": 0.95, "backup_check": 0.35,
		"marketing": 0.7, "fee_accept": -0.08, "qbr": -0.08, "new_mood": 0, "poach": 0.0,
		"patch": 1.0, "morale": 0.0, "outing_relief": 1.0
	},
	"Garrison":
	{
		"close_miss": 0.09, "rdp": 1.2, "stack_risk": 1.1, "issues": 1.0, "backup_check": 0.12,
		"marketing": 1.25, "fee_accept": 0.08, "qbr": 0.1, "new_mood": 4, "poach": -0.02,
		"patch": 1.35, "morale": 3.0, "outing_relief": 1.5
	},
}
const DEFAULT_EDGE := {
	"close_miss": 0.07, "rdp": 1.0, "stack_risk": 1.0, "issues": 1.0, "backup_check": 0.2,
	"marketing": 1.0, "fee_accept": 0.0, "qbr": 0.0, "new_mood": 0, "poach": 0.0,
	"patch": 1.0, "morale": 0.0, "outing_relief": 1.0
}
# personal goals (shown in the weekly report, scored at the review)
const OWNER_GOALS := {
	"Alan": {"title": "A CLEAN YEAR", "parts": ["NO RANSOMWARE LOSS", "NO BREAK-INS", "A DOCUMENTED STACK (MATURITY 3)"]},
	"Garrison": {"title": "THE SHOP CLIENTS LOVE", "parts": ["CLIENT MOOD 75+", "THE TEAM STAYS"]},
}
const OPTIONS_OK := [{"label": "OK", "id": "ok"}]

# Card options: {label, need (cash), fx} or {label, need, roll: [[chance, fx, result text], ...]} plus optional text.
# fx keys: cash, rep, mood_all, mood {client: n}, flag, price, speed, weekly, vic, hire, lose_tech, sign, drop,
#          discount {mult, weeks}, ransom, quote {cash, cost, rep}
const DEFAULT_CARDS := {
	"welcome":
	{
		"speaker": "Christy (Controller)",
		"text":
		"Welcome to the owner side of the desk. Five clients, Dan and Maya on the crew, Morgan running the floor, John in sales and {cash} in the bank. Payroll and rent come out every week, and you and {partner} draw from what is left. How do you want to price our service?",
		"options":
		[
			{
				"label": "VOLUME PRICING (-15% FEES, JOHN SELLS MORE)",
				"fx": {"price": -0.15, "vic": 0.15}
			},
			{"label": "STANDARD PRICING", "fx": {}},
			{
				"label": "PREMIUM PRICING (+20% FEES, HARDER SELL)",
				"fx": {"price": 0.2, "vic": -0.1}
			},
		],
	},
	"backup":
	{
		"speaker": "{tech}",
		"text":
		"{me}, backup jobs fail silently and we only find out when someone needs them. A managed backup service checks them every night: $600 to set up and $100 a week.",
		"options":
		[
			{
				"label": "BUY THE BACKUP SERVICE ($600 + $100/WEEK)",
				"need": 600,
				"fx": {"cash": -600, "weekly": 100, "flag": "backup_service"}
			},
			{"label": "NO, WE WILL CHECK THEM BY HAND", "fx": {"flag": "no_backup_service"}},
		],
	},
	"queue":
	{
		"speaker": "John Marlowe",
		"text":
		"The queue is getting long and clients are noticing. We either need more hands or faster hands.",
		"options":
		[
			{"label": "SEE HIRING CANDIDATES", "fx": {"candidates": true}},
			{
				"label": "POWERSHELL TRAINING FOR THE CREW ($400)",
				"need": 400,
				"fx": {"cash": -400, "speed": 0.25}
			},
			{"label": "NEITHER, WE WILL COPE", "fx": {}},
		],
	},
	"desktop":
	{
		"speaker": "John Marlowe",
		"text":
		"Dr. Patel wants a new desktop set up and migrated. What do I quote? Cheap closes easily, premium might scare him off. The job costs us about $400 of tech time.",
		"options":
		[
			{
				"label": "$600 (ALMOST SURE)",
				"roll":
				[
					[
						0.95,
						{"quote": {"cash": 600, "cost": 400, "rep": 1}},
						"He accepts. The install goes smoothly."
					],
					[0.05, {}, "He shops around instead."]
				]
			},
			{
				"label": "$1,000 (PROBABLY)",
				"roll":
				[
					[
						0.75,
						{"quote": {"cash": 1000, "cost": 400, "rep": 1}},
						"Accepted. A tidy profit."
					],
					[0.25, {}, "He says it is too much."]
				]
			},
			{
				"label": "$1,600 (A LONG SHOT)",
				"roll":
				[
					[
						0.4,
						{"quote": {"cash": 1600, "cost": 400, "rep": 2}},
						"He accepts the premium quote!"
					],
					[0.6, {"mood": {"0": -4}}, "He is insulted and says so."]
				]
			},
		],
	},
	"prospect":
	{
		"speaker": "John Marlowe",
		"text":
		"New prospect %s wants us but asks for 20%% off for the first 6 weeks to sign. They are a good-sized account.",
		"options":
		[
			{
				"label": "OFFER THE DISCOUNT",
				"fx": {"sign": true, "discount_new": {"mult": 0.8, "weeks": 6}},
				"text": "Signed! John is thrilled. Their tickets start tomorrow."
			},
			{
				"label": "HOLD THE PRICE",
				"roll":
				[
					[0.5, {"sign": true}, "They sign at full price. John looks smug."],
					[0.5, {}, "They pass. John sulks."]
				]
			},
			{"label": "PASS", "fx": {}},
		],
	},
	"license":
	{
		"speaker": "{tech}",
		"text":
		"Our remote support software renews with a 30% hike. We can pay it, or switch to a cheaper tool and migrate everyone.",
		"options":
		[
			{"label": "PAY THE HIKE ($500)", "need": 500, "fx": {"cash": -500}},
			{
				"label": "SWITCH ($300, SOME PAIN)",
				"need": 300,
				"roll":
				[
					[
						0.7,
						{"cash": -300, "weekly": -30},
						"The switch goes smoothly and weekly costs drop."
					],
					[
						0.3,
						{"cash": -300, "rep": -3, "mood_all": -3},
						"The migration drags and clients notice."
					]
				]
			},
		],
	},
	"rack":
	{
		"speaker": "John Marlowe",
		"text":
		"Gnarly Gnomes' network rack fell off their plywood wall. Everything there is down and Bob is shouting. Who do we send?",
		"options":
		[
			{
				"label": "SEND {tech} NOW ($300)",
				"need": 300,
				"roll":
				[
					[
						0.85,
						{"cash": -300, "mood": {"2": 10}, "rep": 2},
						"{tech} rebuilds it properly. Bob buys them lunch."
					],
					[0.15, {"cash": -300, "mood": {"2": 2}}, "Fixed, but it took all night."]
				]
			},
			{
				"label": "SEND MAYA OR A NEW HIRE ($100)",
				"need": 100,
				"roll":
				[
					[0.5, {"cash": -100, "mood": {"2": 5}}, "Back up by evening."],
					[
						0.5,
						{"cash": -100, "mood": {"2": -12}, "rep": -2},
						"Cables were plugged into the wrong ports. Bob is furious."
					]
				]
			},
			{
				"label": "TELL THEM IT IS THEIR WALL",
				"roll":
				[
					[0.7, {"mood": {"2": -20}}, "They fix it themselves. They are not happy."],
					[0.3, {"mood": {"2": -20}, "drop": true}, "Gnarly Gnomes cancels the contract."]
				]
			},
		],
	},
	"migration":
	{
		"speaker": "John Marlowe",
		"text":
		"Brightside Realty wants their old server replaced. Do we quote a fixed price or bill time and materials?",
		"options":
		[
			{
				"label": "FIXED PRICE $3,000",
				"roll":
				[
					[0.6, {"cash": 3000, "rep": 1}, "Smooth job, nice margin."],
					[0.4, {"cash": 1800, "mood": {"1": -3}}, "The job overran. You ate $1,200."]
				],
				"roll_scoped":
				[
					[0.9, {"cash": 3000, "rep": 2}, "The scoping day paid off: a smooth job."],
					[0.1, {"cash": 2400}, "A small overrun, nothing serious."]
				]
			},
			{
				"label": "TIME AND MATERIALS (~$2,200)",
				"fx": {"cash": 2200},
				"text": "Brightside grumbles about the open-ended bill but pays."
			},
		],
	},
	"email24":
	{
		"speaker": "{tech}",
		"text":
		"Soggy Bottom's email just died. They run 24x7 and their fermentation alerts come by email. The vendor offers premium support. I will stay late if you approve overtime.",
		"options":
		[
			{
				"label": "PREMIUM VENDOR + OVERTIME ($800)",
				"need": 800,
				"roll":
				[
					[
						0.9,
						{"cash": -800, "mood": {"4": 12}, "rep": 3},
						"Fixed by 9pm. The brewery owner sends beer."
					],
					[0.1, {"cash": -800, "mood": {"4": 4}}, "Fixed, but after midnight."]
				]
			},
			{
				"label": "STANDARD VENDOR SUPPORT",
				"roll":
				[
					[0.4, {"mood": {"4": 3}}, "Fixed overnight, barely."],
					[
						0.6,
						{"mood": {"4": -20}, "rep": -3},
						"Down until morning. A batch is lost. Lucy is livid."
					]
				]
			},
			{
				"label": "GO IN YOURSELF",
				"roll":
				[
					[
						0.6,
						{"rep": 1, "mood": {"4": 6}},
						"You muddle through and fix it. {tech} is impressed."
					],
					[0.4, {"mood": {"4": -8}}, "You make it worse before you make it better."]
				]
			},
		],
	},
	"raise":
	{
		"speaker": "Dan (Service Manager)",
		"text":
		"{me}, I have taken on the hardest jobs all year. I would like a $100 a week raise.",
		"options":
		[
			{"label": "GIVE THE RAISE", "fx": {"payroll": 100, "speed": 0.1}},
			{
				"label": "NOT NOW",
				"roll":
				[
					[0.7, {}, "Dan shrugs and keeps working."],
					[
						0.3,
						{"lose_tech": true, "rep": -2},
						"Dan hands in his notice. The team is stretched thin."
					]
				]
			},
		],
	},
	"bid":
	{
		"speaker": "John Marlowe",
		"text":
		"Hoot and Holler is opening a branch and wants a network install. This is a big job.",
		"options":
		[
			{
				"label": "BID LOW $2,500",
				"risk": {"client": 3, "base": 0.0, "late": 0.08},
				"roll":
				[
					[
						0.78,
						{"cash": 2500, "cost": 0, "rep": 1, "burnout": 3},
						"They accept. The crew grumbles about the margin."
					],
					[
						0.12,
						{"cash": 1300, "burnout": 6},
						"They accept, then the job runs long. After the overtime you clear $1,300."
					],
					[0.1, {}, "They go with someone else."]
				]
			},
			{
				"label": "BID HIGH $4,500 (RISKY)",
				"risk": {"client": 3, "base": 0.03, "late": 0.14},
				"roll":
				[
					[0.35, {"cash": 4500, "rep": 2}, "They accept the premium bid and pay in full."],
					[
						0.2,
						{"cash": 3000, "mood": {"3": -8}},
						"They accept, then dispute the invoice after the work. You settle at $3,000 and the relationship is bruised."
					],
					[0.45, {"rep": -1}, "They balk, walk, and mention it to people they know."]
				]
			},
		],
	},
	"poach":
	{
		"speaker": "John Marlowe",
		"text":
		"ByteBrothers is calling our clients with a cheaper quote and a free 'IT assessment'. Word is they already talked to a couple of ours.",
		"options":
		[
			{
				"label": "LOYALTY DISCOUNT: -10% FOR 4 WEEKS",
				"fx": {"discount": {"mult": 0.9, "weeks": 4}, "mood_all": 8}
			},
			{
				"label": "HEALTH CHECK AT EVERY CLIENT ($300)",
				"need": 300,
				"fx": {"cash": -300, "health_check": true},
				"text":
				"Backups verified and updates pushed everywhere. There is less for them to find."
			},
			{
				"label": "IGNORE THEM",
				"roll":
				[
					[0.6, {}, "Nobody leaves."],
					[0.4, {"drop": true}, "A client switches to ByteBrothers."]
				]
			},
		],
	},
	"peer_invite":
	{
		"speaker": "Christy (Controller)",
		"text":
		"You were invited to the MSP Mastermind: a dozen non-competing MSP owners who meet regularly, compare their numbers (EBITDA, W-2 ratio) and warn each other about what is coming. Dues are $500 to join and $75 a week.",
		"options":
		[
			{
				"label": "JOIN THE PEER GROUP ($500 + $75/WEEK)",
				"need": 500,
				"fx": {"cash": -500, "weekly": 75, "flag": "peer_group", "vic": 0.05},
				"text": "You are in. The first meeting is in a few days."
			},
			{"label": "NOT NOW", "fx": {}},
		],
	},
	"mentor_offer":
	{
		"speaker": "Dana Whitfield (Consultant)",
		"text":
		"I ran an MSP for fifteen years and sold it. For $400 a week I will review your numbers, tell you what I would do, and nudge your big decisions in the right direction. You can dismiss me any time.",
		"options":
		[
			{
				"label": "HIRE DANA ($400/WEEK)",
				"fx": {"weekly": 400, "flag": "mentor"},
				"text": "Dana opens her notebook. Expect advice on Monday mornings."
			},
			{"label": "NO THANKS", "fx": {}},
		],
	},
	"peer1":
	{
		"speaker": "MSP Mastermind",
		"text":
		"Tonight's topic: backups. Two members lost clients to silent backup failures. The group has a deal on a managed backup service, and a few members say you could charge 10% more.",
		"options":
		[
			{
				"label": "BACKUP SERVICE VIA THE GROUP ($400)",
				"need": 400,
				"unless": "backup_service",
				"fx": {"cash": -400, "weekly": 100, "flag": "backup_service"}
			},
			{"label": "RAISE PRICES 10% (MOOD -2)", "fx": {"price": 0.1, "mood_all": -2}},
			{"label": "JUST NETWORK", "fx": {}},
		],
	},
	"peer2":
	{
		"speaker": "MSP Mastermind",
		"text":
		"A member got hit by ransomware last month because their backups had quietly died and nobody had checked in weeks. The group's advice: have your team check every client's backup today.",
		"options":
		[
			{
				"label": "HAVE THE TEAM CHECK EVERY BACKUP",
				"fx": {"check_backups": true},
				"text": "The crew checks them all. Any failing job is rerun."
			},
			{"label": "WE ARE FINE", "fx": {}},
		],
	},
	"peer3":
	{
		"speaker": "MSP Mastermind",
		"text":
		"A peer says fixed-price projects are where owners lose money: spend a day scoping the job before you quote anything.",
		"options":
		[
			{
				"label": "SCOPE PROJECTS FIRST ($300)",
				"need": 300,
				"fx": {"cash": -300, "flag": "scoped"},
				"text": "Your next fixed-price quote will be much safer."
			},
			{"label": "SKIP IT", "fx": {}},
		],
	},
	"peer4":
	{
		"speaker": "MSP Mastermind",
		"text":
		"Year-end benchmarks: members average a 15% EBITDA margin and keep payroll under 55% of revenue. Most raised prices at least 8% this year.",
		"options":
		[
			{"label": "RAISE PRICES 8% (MOOD -3)", "fx": {"price": 0.08, "mood_all": -3}},
			{"label": "HOLD PRICES", "fx": {}},
		],
	},
	"marketing":
	{
		"speaker": "John Marlowe",
		"text":
		"John wants a marketing budget: a website refresh, local events, email campaigns. It raises his close rate and brings in inbound leads. How much per week? (It counts against EBITDA.)",
		"options":
		[
			{"label": "NO MARKETING ($0)", "fx": {"marketing": 0}},
			{"label": "LIGHT ($150/WEEK)", "fx": {"marketing": 150}},
			{"label": "STANDARD ($400/WEEK)", "fx": {"marketing": 400}},
			{"label": "AGGRESSIVE ($900/WEEK)", "fx": {"marketing": 900}},
		],
	},
	"draw_policy": {
		"speaker": "Christy (Controller)",
		"text": "The owners' draw. You and {partner} pay yourselves out of the bank. It is not an expense, so it never shows in EBITDA, but it is real cash, and a bad week leaves the bank thin. What do we take?",
		"options": [
			{"label": "NORMAL DRAW ($600/WEEK, BOTH OF YOU)", "fx": {"draw": "normal"}, "text": "Christy writes it in the ledger. The draw starts in week 3."},
			{"label": "SMALL DRAW ($300/WEEK)", "fx": {"draw": "small", "trust": {"Alan": 1, "Garrison": 1}}, "text": "A small draw. Christy looks relieved and {partner} nods. The bank stays fat."},
			{"label": "GENEROUS DRAW ($1,000/WEEK)", "fx": {"draw": "generous"}, "text": "A generous draw. Christy says nothing, which is how she says a lot."},
			{"label": "NO DRAW (WE LIVE ON NOODLES)", "fx": {"draw": "none", "trust": {"Alan": 2, "Garrison": 2}}, "text": "No draw at all. You and {partner} split a sleeve of crackers. Christy frames the ledger."},
		],
	},
	"draw_review": {
		"speaker": "Christy (Controller)",
		"text": "Quarterly look at the owners' draw. Same as before, more, less, or nothing for now?",
		"options": [
			{"label": "KEEP THE DRAW AS IT IS", "fx": {}},
			{"label": "TAKE LESS (SMALL DRAW)", "fx": {"draw": "small", "trust": {"Alan": 1, "Garrison": 1}}, "text": "A smaller draw. The bank breathes easier."},
			{"label": "TAKE MORE (GENEROUS DRAW)", "fx": {"draw": "generous"}, "text": "A bigger draw. It is a good quarter, you tell yourself."},
			{"label": "SKIP THE DRAW FOR NOW", "fx": {"draw": "none", "trust": {"Alan": 2, "Garrison": 2}}, "text": "No draw this quarter. Christy pins a gold star on the ledger."},
		],
	},
	"stack_psa":
	{
		"speaker": "{tech}",
		"text":
		"Our PSA contract is up for renewal. ConnectWhy is the standard ($60/week). Ticketo Lite is much cheaper ($15) but the crew finds it clunky. OpsForge Pro ($140) is what the big shops run.",
		"options":
		[
			{"label": "KEEP CONNECTWHY PSA", "fx": {}},
			{
				"label": "TICKETO LITE ($15/WK, $300 TO MIGRATE)",
				"need": 300,
				"fx": {"cash": -300, "stack": {"psa": "ticketo"}},
				"text": "Migrated. The crew is not thrilled."
			},
			{
				"label": "OPSFORGE PRO ($140/WK, $300 TO MIGRATE)",
				"need": 300,
				"fx": {"cash": -300, "stack": {"psa": "opsforge"}},
				"text": "The crew loves the automation."
			},
		],
	},
	"stack_rmm":
	{
		"speaker": "{tech}",
		"text":
		"The RMM renewal is here. LabRat is the standard ($80/week). SnoutTech Basic is cheap ($25) but it misses things. LabRat Gold ($180) catches problems before clients call.",
		"options":
		[
			{"label": "KEEP LABRAT RMM", "fx": {}},
			{
				"label": "SNOUTECH BASIC ($25/WK, $300 TO MIGRATE)",
				"need": 300,
				"fx": {"cash": -300, "stack": {"rmm": "snoutech"}},
				"text": "Migrated. More surprises ahead."
			},
			{
				"label": "LABRAT GOLD ($180/WK, $200 TO UPGRADE)",
				"need": 200,
				"fx": {"cash": -200, "stack": {"rmm": "labrat_gold"}},
				"text": "Upgraded. Alerts start catching things early."
			},
		],
	},
	"stack_hw":
	{
		"speaker": "John Marlowe",
		"text":
		"Which hardware vendor do we recommend and resell? Hewlitt Packerd is the standard ($200 margin a deal). BudgetByte is cheap, so I sell more, but their machines fail more. DellightCo is premium and rock solid, but harder to sell.",
		"options":
		[
			{"label": "HEWLITT PACKERD (THE STANDARD)", "fx": {"stack": {"hardware": "hewlitt"}}},
			{
				"label": "BUDGETBYTE (+12% SALES, MORE TICKETS)",
				"fx": {"stack": {"hardware": "budgetbyte"}},
				"text": "John grins. Expect more calls about broken laptops."
			},
			{
				"label": "DELLIGHTCO (SOLID, $350 MARGIN)",
				"fx": {"stack": {"hardware": "dellight"}},
				"text": "Fewer fires, fatter margins, a slower sell."
			},
		],
	},
	"rn_invite": {
		"speaker": "John Marlowe",
		"text": "LabRat's yearly user conference, RODENT NATION, is at the Orlando resort this June. Registration is $450 a head plus the flight, and every vendor you pay every month will be in the hall with a pen and a discount. Go yourself, send {tech} with a shopping list, or stay and mind the queue?",
		"options": [
			{"label": "GO YOURSELF ($450)", "need": 450, "fx": {"cash": -450, "trip": true, "show": "rn_session"}},
			{"label": "SEND {tech} ($300, HE BRINGS BACK ONE IDEA)", "need": 300, "fx": {"cash": -300, "trip": true, "speed": 0.03, "burnout": 3}, "text": "{tech} comes back with a tote bag, a sunburn and one idea that really does save the crew an hour a week. (+3% team speed)"},
			{"label": "STAY HOME", "fx": {}, "text": "The invitation goes in the drawer with the others. The queue gets your full attention."},
		],
	},
	"rn_session": {
		"speaker": "RODENT NATION",
		"text": "The resort: palm trees in the lobby, carpet with swirls, a ballroom for a thousand MSP nerds and a keynote about a dashboard. Between the keynote and the vendor hall there is one breakout session you can sit in. Which one?",
		"options": [
			{"label": "PRICING AND PACKAGING CLINIC (PRICES +3%)", "fx": {"price": 0.03, "show": "rn_hall"}},
			{"label": "THE BURNOUT PANEL (CREW BURNOUT -10)", "fx": {"burnout": -10, "show": "rn_hall"}},
			{"label": "THE HALLWAY TRACK (REP +1, CLIENTS +1 MOOD)", "fx": {"mood_all": 1, "rep": 1, "show": "rn_hall"}},
		],
	},
	"rn_hall": {
		"speaker": "RODENT NATION",
		"text": "The vendor hall: a long row of booths, free pens, a man in a rat costume, and every badge scanner in the building pointed at you. The vendors you pay each month are here, and they are all selling. Which booth first?",
		"options": [
			{"label": "THE RMM BOOTH (LABRAT)", "unless": "rn_rmm", "fx": {"show": "rn_rmm"}},
			{"label": "THE PSA BOOTH (OPSFORGE)", "unless": "rn_psa", "fx": {"show": "rn_psa"}},
			{"label": "THE HARDWARE BOOTH (DELLIGHTCO)", "unless": "rn_hw", "fx": {"show": "rn_hw"}},
			{"label": "HEAD HOME", "fx": {"show": "rn_wrap"}},
		],
	},
	"rn_rmm": {
		"speaker": "LabRat Sales Rep",
		"text": "Show special, today only: upgrade to LabRat Gold ($180/week) and we waive half the migration, $150 instead of $300. Early alerts, better patching, fewer breaches. The three-year term and the add-on modules are in the fine print, and they come to about $25 a week.",
		"options": [
			{"label": "SIGN AT THE SHOW ($150, +$25/WK ADD-ONS)", "need": 150, "fx": {"cash": -150, "weekly": 25, "flag": "rn_rmm", "stack": {"rmm": "labrat_gold"}, "show": "rn_hall"}},
			{"label": "TAKE THE BROCHURE", "fx": {"flag": "rn_rmm", "show": "rn_hall"}},
		],
	},
	"rn_psa": {
		"speaker": "OpsForge Sales Rep",
		"text": "Switch to OpsForge Pro ($140/week) at the show and we do the data import for $150. The crew loves the automation. Implementation takes about two weeks, and the crew works the old and the new system side by side until then.",
		"options": [
			{"label": "SIGN AT THE SHOW ($150, SLOWER FOR A WHILE)", "need": 150, "fx": {"cash": -150, "speed": -0.05, "flag": "rn_psa", "stack": {"psa": "opsforge"}, "show": "rn_hall"}},
			{"label": "TAKE THE BROCHURE", "fx": {"flag": "rn_psa", "show": "rn_hall"}},
		],
	},
	"rn_hw": {
		"speaker": "DellightCo Rep",
		"text": "We want you on DellightCo Premium: fewer tickets, a $350 margin a deal, and the switch costs nothing. All we ask is a minimum order commitment, which John would have to hit, and he will sell less of the cheap stuff.",
		"options": [
			{"label": "SIGN AT THE SHOW (FREE, JOHN SELLS LESS)", "fx": {"vic": -0.03, "flag": "rn_hw", "stack": {"hardware": "dellight"}, "show": "rn_hall"}},
			{"label": "TAKE THE BROCHURE", "fx": {"flag": "rn_hw", "show": "rn_hall"}},
		],
	},
	"rn_wrap": {
		"speaker": "RODENT NATION",
		"text": "The last session lets out. You fly home with a tote bag, a stack of badge-scan emails you will be answering for a month and a lanyard you will keep. Back at the office the queue held up fine. The crew wants to hear about it.",
		"options": [
			{"label": "FLY HOME", "fx": {"mood_all": 1}, "text": "You tell the crew about the pens first. Then the ideas. (clients +1 mood)"},
		],
	},
	"vic_plan":
	{
		"speaker": "Christy (Controller)",
		"text":
		"How do we pay John? Salesmen respond to incentives, but commission-driven reps over-promise and new clients start out unhappy. Salary is steady but he sells less hard.",
		"options":
		[
			{"label": "SALARY ONLY ($750/WK)", "fx": {"vic_plan": "salary"}},
			{"label": "BALANCED ($550/WK + $150 A DEAL)", "fx": {"vic_plan": "balanced"}},
			{"label": "COMMISSION-HEAVY ($350/WK + $300 A DEAL)", "fx": {"vic_plan": "commission"}},
		],
	},
	"billing_audit":
	{
		"speaker": "Christy (Controller)",
		"text":
		"I have a hunch we are not billing for everything: extra hours, license price rises we never passed on. A one-time billing audit ($400) would check every invoice against what we pay vendors and the hours we really work.",
		"options":
		[
			{
				"label": "DO THE BILLING AUDIT ($400)",
				"need": 400,
				"fx": {"cash": -400, "fix_leak": true},
				"text":
				"The audit finds unbilled work and vendor increases nobody passed through. Fixed from now on."
			},
			{"label": "SKIP IT", "fx": {}},
		],
	},
	"after_hours":
	{
		"speaker": "{ops}",
		"text":
		"After-hours calls are burning the crew out: pages at 2 a.m. for things that could wait. Other owners charge an after-hours fee and most non-critical calls simply stop. Or we can pay an on-call stipend.",
		"options":
		[
			{
				"label": "ADOPT A $250/HOUR AFTER-HOURS FEE",
				"fx": {"flag": "after_hours_fee", "mood_all": -3},
				"text": "Most non-critical after-hours calls stop. A few clients grumble."
			},
			{
				"label": "PAY AN ON-CALL STIPEND ($150/WEEK)",
				"fx": {"weekly": 150, "flag": "oncall_stipend"},
				"text": "The crew feels valued. Calls keep coming, but the pain is shared."
			},
			{"label": "NEITHER, WE WILL COPE", "fx": {}},
		],
	},
	"oncall_policy":
	{
		"speaker": "{ops}",
		"text":
		"Clients are starting to call after hours. Somebody has to carry the pager. How do we run it?",
		"options":
		[
			{
				"label": "ROTATE EVERYONE, $100/WEEK POOL",
				"fx": {"weekly": 100, "flag": "oncall_stipend", "burnout": -4},
				"text":
				"A fair rota with a little money behind it. Nobody loves the pager, but everybody takes a turn."
			},
			{
				"label": "DAN TAKES IT EVERY WEEK (+$150)",
				"fx": {"weekly": 150, "flag": "oncall_one"},
				"text": "Dan says fine. For now. The same person every week is how people quit."
			},
			{
				"label": "YOU CARRY THE PAGER YOURSELF",
				"fx": {"flag": "owner_oncall", "burnout": -6},
				"text":
				"The crew is thrilled. Your nights will be less so, and it eats your owner hours every week."
			},
		],
	},
	"flex_hours":
	{
		"speaker": "{ops}",
		"text":
		"Three of the crew were late this month and two are asking for flexible hours. Route 9 is down to one lane. What is the policy?",
		"options":
		[
			{
				"label": "FLEXIBLE START TIMES (CORE 10 TO 4)",
				"fx": {"flag": "flex_hours", "burnout": -6, "speed": -0.02},
				"text": "Morale lifts. The phones are a little thin first thing."
			},
			{
				"label": "STRICT PUNCTUALITY, A QUIET WORD",
				"fx": {"flag": "strict_hours", "burnout": 4, "speed": 0.03},
				"text": "People are on time. They also watch the clock at 5:00."
			},
			{
				"label": "TRY A FOUR-DAY WEEK",
				"roll":
				[
					[
						0.5,
						{"flag": "four_day", "burnout": -15, "rep": 1},
						"The crew is a different crew on Mondays. Clients barely notice."
					],
					[
						0.5,
						{"mood_all": -4, "speed": -0.08, "burnout": -8},
						"Clients notice the quiet Fridays. Some are not happy."
					]
				]
			},
		],
	},
	"rdp_exposed":
	{
		"speaker": "{tech}",
		"text":
		"{me}, remote desktop is open to the whole internet at three client sites. The logs show thousands of password guesses a day from overseas. Most are just guessing common passwords, but one lucky guess is all it takes.",
		"options":
		[
			{
				"label": "AUTO-BLOCKING FIREWALLS ($600 + $40/WEEK)",
				"need": 600,
				"fx": {"cash": -600, "weekly": 40, "flag": "rdp_safe"},
				"text":
				"Repeated failed logins now get an address blocked automatically. The guessing stops."
			},
			{
				"label": "PUT REMOTE ACCESS BEHIND A VPN ($1,200)",
				"need": 1200,
				"fx": {"cash": -1200, "flag": "rdp_safe", "mood_all": -2},
				"text":
				"Remote access needs the VPN first. Users complain a little, attackers get nothing."
			},
			{
				"label": "CHANGE THE PORT NUMBERS ($100)",
				"need": 100,
				"fx": {"cash": -100, "flag": "rdp_weak"},
				"text": "It slows them down. It does not stop them."
			},
			{"label": "LEAVE IT", "fx": {}},
		],
	},
	"ransom_options":
	{
		"speaker": "{tech}",
		"text":
		"Hoot and Holler's server is encrypted by CryptoLocker. There is a countdown and a ransom demand in Bitcoin. The backup was not working. What now?",
		"options":
		[
			{
				"label": "PAY THE RANSOM ($500)",
				"need": 500,
				"roll":
				[
					[
						0.7,
						{"cash": -500, "ransom_end": "paid", "rep": -1},
						"The key arrives and the files unlock. Nobody feels good about it."
					],
					[
						0.3,
						{"cash": -500, "ransom_end": "lost"},
						"They took the money and the key never came."
					]
				]
			},
			{
				"label": "TRY WINDOWS SHADOW COPIES",
				"roll":
				[
					[
						0.4,
						{"ransom_end": "partial", "rep": -2},
						"Most files come back from shadow copies."
					],
					[0.6, {"ransom_end": "lost"}, "The malware deleted the shadow copies."]
				]
			},
			{
				"label": "CALL THE BACKUP VENDOR'S SUPPORT ($150)",
				"need": 150,
				"roll": [
					[0.5, {"cash": -150, "ransom_end": "vendor"}, "Support finds a version from before the infection and rolls the files back. Nothing is lost."],
					[0.5, {"cash": -150, "ransom_end": "lost"}, "The synced copies were overwritten with the encrypted files. They are sorry."],
				],
			},
			{
				"label": "ISOLATE IT AND REBUILD FROM THE IMAGE ($1,000)",
				"need": 1000,
				"fx": {"cash": -1000, "ransom_end": "rebuilt", "rep": -3, "mood": {"3": -8}},
				"text": "The server is clean by evening. Everything since the last good copy is gone, and the partners know it.",
			},
			{
				"label": "CALL THE CYBER-INSURANCE LINE ($250 DEDUCTIBLE)",
				"need": 250,
				"policy": true,
				"roll": [
					[0.65, {"cash": -250, "ransom_end": "insured", "rep": -1}, "The insurer sends a recovery firm. The files come back and you pay the deductible."],
					[0.35, {"cash": -250, "ransom_end": "lost"}, "The adjuster denies the claim: the policy wanted patched, backed-up systems."],
				],
			},
			{"label": "ACCEPT THE LOSS", "fx": {"ransom_end": "lost"}},
		],
	},
	"ransom_lost":
	{
		"speaker": "Christy (Controller)",
		"text":
		"Hoot and Holler lost years of case files because our backup was not working. Their lawyers are talking about suing us.",
		"options":
		[
			{
				"label": "SETTLE ($2,500)",
				"need": 2500,
				"fx": {"cash": -2500, "rep": -3, "mood": {"3": 10}}
			},
			{
				"label": "FIGHT IT",
				"roll":
				[
					[0.5, {"rep": -3}, "The case is dismissed, but it cost you sleep."],
					[0.5, {"cash": -6000, "rep": -8}, "You lose. It costs $6,000 and your name."]
				]
			},
		],
	},
	"bec_scare":
	{
		"speaker": "{tech}",
		"text":
		"{me}, {client}'s bookkeeper just forwarded us an email that looks like it came from their owner: wire {amount} to a new account today, keep it quiet, no phone calls. She had a bad feeling and asked us first. It is a fake. Someone read their mail for days and copied the owner's style. This is hitting small offices all over the country, and every client of ours has the same hole.",
		"options":
		[
			{
				"label": "WARN EVERY CLIENT, START A CALL-BACK RULE ($350)",
				"need": 350,
				"fx": {"cash": -350, "bec": "policy"},
				"text":
				"A one page letter goes to every client: no payment and no bank change without a phone call to a number you already had. Two clients thank you. Their bookkeepers start calling back."
			},
			{
				"label": "OFFER THE HOSTED EMAIL FILTER ($250 SETUP, $45/WEEK EACH)",
				"need": 250,
				"fx": {"cash": -250, "bec": "filter"},
				"text":
				"John and {tech} call around. The filter holds mail from lookalike domains and flags a sender that does not match the name. It is a recurring service, so it sells itself the way backups do."
			},
			{
				"label": "DO BOTH ($550)",
				"need": 550,
				"fx": {"cash": -550, "bec": "both"},
				"text":
				"The letter goes out with the filter offer attached. Christy says it is the cheapest insurance on the books."
			},
			{
				"label": "IGNORE IT, THEY CAUGHT THIS ONE THEMSELVES",
				"fx": {"bec": "ignore"},
				"text": "You file it under lucky. The next one may not come with a bookkeeper who asks first."
			},
		],
	},
	"bec_marge":
	{
		"speaker": "Christy (Controller)",
		"text":
		"{me}, a note came in from our hardware distributor: their bank changed, please pay this week's invoice of $2,400 to the new account on the attached form. It has their logo and the rep's signature. The reply address is a little different from the one in my file. We are already late and they are touchy about it.",
		"options":
		[
			{
				"label": "CALL THE DISTRIBUTOR ON THE NUMBER IN OUR FILE",
				"fx": {"bec": "self_check", "owner_hours": 1},
				"text":
				"The rep never sent it. 'Good catch,' he says. Christy adds a rule to the books: any bank change gets a phone call first, from us, to a number we already had."
			},
			{
				"label": "PAY IT, WE ARE LATE ALREADY",
				"roll":
				[
					[0.55, {"cash": -2400, "bec": "self_check"}, "It was fake. The money is gone and the real invoice is still unpaid. Christy never wants to see that happen again and writes the call-back rule down."],
					[0.45, {}, "It was real. The distributor changed banks. You got lucky and Christy knows it."]
				]
			},
			{
				"label": "REPLY TO THE EMAIL AND ASK IF IT IS REAL",
				"roll":
				[
					[0.7, {"cash": -2400, "bec": "self_check"}, "The answer came back in two minutes: yes, very real, please hurry. The scammer was on the other end. The money is gone."],
					[0.3, {}, "The real rep answers: yes, the bank changed. Nobody can tell you that was the right way to find out."]
				]
			},
		],
	},
	"bec_loss":
	{
		"speaker": "Christy (Controller)",
		"text":
		"{me}, {client} wired {amount} to a scammer this week. An email 'from' their owner told accounting to pay a new account and it worked. Their mailbox had been watched for days. Their owner is on the phone with the bank and his first question is what IT was doing. What do we say?",
		"options":
		[
			{
				"label": "CREDIT THEM 40% AND SIGN THEM FOR THE EMAIL FILTER",
				"fx": {"bec": "credit"},
				"text":
				"Christy cuts the credit memo. Their owner says it is fair and still not happy about the money. The filter goes on the next day."
			},
			{
				"label": "LET OUR LAWYER ANSWER THEIR LETTER ($600)",
				"need": 600,
				"fx": {"cash": -600, "bec": "lawyer"}
			},
			{
				"label": "ASK OUR INSURER",
				"fx": {"bec": "claim"}
			},
			{
				"label": "TELL THEM IT WAS THEIR OWN PROCESS",
				"fx": {"bec": "blame"}
			},
		],
	},
	"bec_lawyer_ok":
	{
		"speaker": "Christy (Controller)",
		"text":
		"Our lawyer reads the contract and the file. Email security is on the recommended list and payments are the client's own process. He writes a calm, short answer and points to the letter we sent. They drop the claim. The relationship is cooler, but it is alive.",
		"options": [{"label": "OK", "fx": {}}],
	},
	"bec_lawyer_bad":
	{
		"speaker": "Christy (Controller)",
		"text":
		"Our lawyer finds no written warning and no call-back rule on file. Their lawyer says we ran their mail and should have seen it. We settle for half the loss to keep this out of court. Word gets around the building.",
		"options": [{"label": "OK", "fx": {}}],
	},
	"bec_claim_ok":
	{
		"speaker": "Christy (Controller)",
		"text":
		"The broker comes back with good news: the funds transfer fraud rider covers a client who is tricked into sending money. We credit the client and the insurer pays most of it back after the deductible. The client sees you stand behind your work.",
		"options": [{"label": "OK", "fx": {}}],
	},
	"bec_claim_no":
	{
		"speaker": "Christy (Controller)",
		"text":
		"The insurer says our policy covers a breach of our own systems, not money a client sent to a criminal by choice. That is a crime policy question and we do not have the rider. We credit the client ourselves.",
		"options": [{"label": "OK", "fx": {}}],
	},
	"bec_blame_left":
	{
		"speaker": "Christy (Controller)",
		"text":
		"You tell their owner it was their process. He agrees quietly, then sends a termination letter for the end of the month. Two other firms in the building hear about it.",
		"options": [{"label": "OK", "fx": {}}],
	},
	"bec_blame_stay":
	{
		"speaker": "Christy (Controller)",
		"text":
		"You tell their owner it was their process. He goes quiet, then says they will stay for now. The tone of every email from them has changed.",
		"options": [{"label": "OK", "fx": {}}],
	},
	"bec_rider":
	{
		"speaker": "Christy (Controller)",
		"text":
		"Our broker called about the wire fraud. A funds transfer fraud rider on the crime policy would cover a client who is tricked into sending money and blames us, up to $25,000 a claim. It is $30 a week. Without it we pay out of pocket every time.",
		"options":
		[
			{
				"label": "ADD THE RIDER ($30/WEEK)",
				"fx": {"bec": "rider"},
				"text": "Signed. The next claim will be a phone call, not a crisis."
			},
			{"label": "LEAVE THE POLICY AS IT IS", "fx": {}},
		],
	},
	"pm_ransom":
	{
		"speaker": "{tech}",
		"text":
		"{me}, CryptoLocker is behind us. Before the week eats it, the team wants an afternoon: what happened, the real cause, what we change. Nobody gets blamed, it is about the process. We can do it properly, or skip it.",
		"options":
		[
			{
				"label": "HOLD THE REVIEW AND WRITE THE RUNBOOK (HALF A DAY)",
				"fx": {"pm": ["ransom", "runbook"], "owner_hours": 6, "burnout": -2, "social_all": 1},
				"text":
				"Four people, a whiteboard and an honest timeline. The backup alert sat unread for two days. The restore steps go on one page in the vault. Nobody was blamed, and everybody said so."
			},
			{
				"label": "HOLD IT AND ADD A WEEKLY RESTORE TEST ($250 + $15/WEEK)",
				"need": 250,
				"fx": {"cash": -250, "weekly": 15, "pm": ["ransom", "check"], "owner_hours": 3, "social_all": 1},
				"text":
				"Every Friday someone restores one real file from each client and signs the sheet. It takes twenty minutes and it would have caught this."
			},
			{
				"label": "SKIP IT, THE QUEUE IS FULL",
				"fx": {"pm": ["ransom", "skip"], "burnout": 2, "social_all": -1},
				"text": "The queue gets a little shorter. The whiteboard stays blank. Nobody says anything, which is its own answer."
			},
		],
	},
	"pm_rack": {
		"speaker": "{tech}",
		"text":
		"{me}, the fallen rack at Gnarly Gnomes is a story the team already tells at lunch. It is also a pattern: plywood walls, no labels, no photos. Do we write it down so the next one is boring?",
		"options":
		[
			{
				"label": "HOLD THE REVIEW AND START A SITE CHECKLIST (HALF A DAY)",
				"fx": {"pm": ["rack", "runbook"], "owner_hours": 5, "social_all": 1},
				"text":
				"Every closet gets a photo, labelled cables and a look at the wall. The team finds two more racks in the same state. The checklist fits on one page."
			},
			{
				"label": "HOLD IT AND BUY A SPARE SWITCH AND LABELS ($200)",
				"need": 200,
				"fx": {"cash": -200, "pm": ["rack", "check"], "owner_hours": 3, "social_all": 1},
				"text":
				"A spare switch and a roll of cable labels live in the van now. The next closet that fails is an hour, not an afternoon."
			},
			{
				"label": "SKIP IT, THEY ARE BACK UP",
				"fx": {"pm": ["rack", "skip"], "burnout": 2, "social_all": -1},
				"text": "Gnarly Gnomes is up and happy. The next wall is still plywood."
			},
		],
	},
	"pm_email": {
		"speaker": "{tech}",
		"text":
		"{me}, the email night at the brewery ran past midnight. Before we all forget it, the team wants a short review: what broke, why nobody saw it coming and what we change. No blame, just the list.",
		"options":
		[
			{
				"label": "HOLD THE REVIEW AND WRITE A STATUS TEMPLATE (HALF A DAY)",
				"fx": {"pm": ["email", "runbook"], "owner_hours": 5, "burnout": -2, "social_all": 1},
				"text":
				"A full log drive nobody watched, and a client who heard nothing for an hour. Now there is a disk alert and a one line status message every 30 minutes. Nobody was blamed."
			},
			{
				"label": "HOLD IT AND PAY FOR SECOND-LEVEL ALERTS ($300 + $20/WEEK)",
				"need": 300,
				"fx": {"cash": -300, "weekly": 20, "pm": ["email", "check"], "owner_hours": 3, "social_all": 1},
				"text":
				"Mail disks and queues page a second person now, so a quiet failure does not sit until the phone rings."
			},
			{
				"label": "SKIP IT, WE ARE TIRED",
				"fx": {"pm": ["email", "skip"], "burnout": 2, "social_all": -1},
				"text": "Everyone goes home. The disk is still the same size."
			},
		],
	},
	"pm_bec": {
		"speaker": "{tech}",
		"text":
		"{me}, the wire fraud at {client} cost them real money and us a lot of sleep. The team wants an hour: how it got through, which control would have stopped it, what we change. No blame for the bookkeeper, she did what the process allowed.",
		"options":
		[
			{
				"label": "HOLD THE REVIEW AND WRITE THE WIRE REQUEST CHECKLIST (HALF A DAY)",
				"fx": {"pm": ["bec", "runbook"], "owner_hours": 5, "social_all": 1},
				"text":
				"The checklist is short: call back on a known number, a second person for any new account, a hold on anything marked urgent and secret. We offer it to every client as a one page handout."
			},
			{
				"label": "HOLD IT AND MAKE TWO-FACTOR LOGIN STANDARD FOR EMAIL ($300)",
				"need": 300,
				"fx": {"cash": -300, "pm": ["bec", "check"], "owner_hours": 4, "social_all": 1},
				"text":
				"Two-factor login goes on every client mailbox that handles money, starting with the ones that were hit. A stolen password alone is not enough any more."
			},
			{
				"label": "SKIP IT, THE CLIENT IS ALREADY HANDLED",
				"fx": {"pm": ["bec", "skip"], "burnout": 2, "social_all": -1},
				"text": "The client is handled. The process that let it through is not."
			},
		],
	},
}
var CARDS: Dictionary = DEFAULT_CARDS.duplicate(true)
const DAYS := {
	1: [{"at": 9.1, "card": "welcome"}, {"at": 9.6, "event": "owner_goal"}],
	2: [{"at": 9.1, "card": "backup"}, {"at": 10.0, "card": "draw_policy"}, {"at": 15.0, "card": "peer_invite"}],
	3:
	[
		{"at": 9.1, "card": "queue"},
		{"at": 9.3, "event": "leak_start"},
		{"at": 15.0, "card": "marketing"}
	],
	4:
	[
		{"at": 9.5, "card": "desktop"},
		{"at": 12.0, "card": "oncall_policy"},
		{"at": 14.0, "card": "stack_psa"}
	],
	5:
	[
		{"at": 8.6, "event": "break_backup"},
		{"at": 11.0, "card": "stack_hw"},
		{"at": 14.0, "card": "billing_audit"},
		{"at": 15.0, "event": "peer", "card": "peer1"},
		{"at": 15.5, "event": "peer_goal"},
		{"at": 12.0, "event": "growth_plan"}, {"at": 10.2, "event": "partner", "card": "partner1"}
	],
	6:
	[
		{"at": 9.5, "event": "prospect"},
		{"at": 10.5, "event": "profit_review"},
		{"at": 12.0, "event": "client_no"},
		{"at": 15.0, "card": "mentor_offer"}
	],
	7:
	[
		{"at": 11.0, "event": "qbr"},
		{"at": 12.5, "card": "rdp_exposed"},
		{"at": 14.0, "card": "stack_rmm"}
	],
	8:
	[
		{"at": 9.5, "card": "license"},
		{"at": 13.0, "card": "vic_plan"},
		{"at": 15.0, "event": "peer", "card": "peer2"},
		{"at": 11.0, "event": "growth_stretch"}
	],
	9:
	[
		{"at": 9.8, "event": "grumble"},
		{"at": 10.5, "event": "ransomware"},
		{"at": 14.5, "card": "marketing"}, {"at": 13.0, "event": "partner", "card": "partner2"}
	],
	10:
	[
		{"at": 10.0, "card": "rack"},
		{"at": 10.8, "event": "profit_review"},
		{"at": 14.0, "event": "vic_report"},
		{"at": 12.0, "card": "flex_hours"},
		{"at": 16.0, "card": "rn_invite"}
	],
	11:
	[
		{"at": 10.4, "card": "pm_ransom"},
		{"at": 14.2, "card": "pm_rack"},
		{"at": 11.0, "event": "qbr"},
		{"at": 15.0, "event": "peer", "card": "peer3"},
		{"at": 15.2, "event": "leak_hint"}, {"at": 9.6, "card": "draw_review"},
		{"at": 15.5, "event": "peer_goal"}
	],
	12:
	[
		{"at": 9.5, "card": "migration"},
		{"at": 10.5, "card": "after_hours"},
		{"at": 11.5, "event": "growth_stretch"}
	],
	13: [{"at": 12.0, "card": "bec_scare"}, {"at": 15.5, "card": "email24"}, {"at": 10.0, "event": "partner", "card": "partner3"}, {"at": 9.5, "event": "vendor_rise"}],
	14:
	[
		{"at": 10.0, "event": "vendor_breach"},
		{"at": 11.0, "event": "profit_review"},
		{"at": 15.0, "card": "marketing"}
	],
	15:
	[{"at": 9.8, "card": "pm_email"}, {"at": 14.0, "card": "bec_marge"}, {"at": 9.5, "card": "raise"}, {"at": 10.5, "event": "grumble"}, {"at": 11.5, "event": "qbr"}, {"at": 13.0, "event": "credit_squeeze"}],
	16:
	[
		{"at": 9.5, "card": "bid"},
		{"at": 14.0, "event": "client_breach"},
		{"at": 11.0, "event": "growth_stretch"},
		{"at": 10.6, "event": "key_poach"}
	],
	17: [{"at": 15.0, "event": "peer", "card": "peer4"}, {"at": 10.0, "event": "partner", "card": "partner4"}, {"at": 15.5, "event": "peer_goal"}, {"at": 11.5, "event": "audit"}],
	18: [{"at": 9.5, "event": "poach_wave"}, {"at": 11.0, "event": "profit_review"}],
	19: [{"at": 11.0, "event": "qbr"}],
}

var cash := START_CASH
var flags := {}
var price := 1.0
var speed := 1.0
var vic_bonus := 0.0
var weekly_extra := 0
var payroll_extra := 0  # X9: raises and retention pay: W-2 payroll, not "other costs"
var lost_techs := 0
var draw_policy := "normal"  # the owners' weekly draw: none / small / normal / generous (card on week 2)
var draw_paid := 0  # total drawn so far
var draw_warned := -9  # the week Christy last complained about an oversized draw
var hire_quits := 0  # hires who left (for the Garrison goal: a team that stays)
var incidents := 0  # break-ins through remote desktop (for the Alan goal: a clean year)
var _outings_seen := 0
var extra_staff: Array = []
var marketing := 0  # weekly marketing budget
var stack := DEFAULT_STACK.duplicate()
var ar: Array = []  # unpaid invoices: {client, amount, age, delay}
var fee_boost := {}  # client -> fee multiplier won at a business review
var vic_plan := "salary"
var vic_deals := 0
var vic_signed: Array = []
var client_work := {}  # client -> tech-seconds spent this week
var profit_hist := {}  # client -> their last weekly profits
var scope_fixed := {}  # client -> true once you enforced the scope
var burnout := 0.0  # the crew's exhaustion 0-100
var bailout := 0  # cozy Easy: the one-time bank rescue (Campaign._cozy_close); the valuation does not count it
var leak := 0.0  # share of revenue silently lost to unbilled work and vendor increases
var leak_found := false
var risk_client := -1  # the client that refused your security recommendation
var risk_choice := ""
var goal := {}  # the accountability goal the peer group will check
var patch_debt := {}  # client -> weeks of missing updates (0-10)
var gone := {}  # clients lost to the competitor: client -> {week, reason, mood}
var discount := {}  # client -> {mult, weeks}
var income_extra := 0  # one-off income / costs this week (jobs)
var history: Array = []
var habits := {}  # R38: good habits: id -> {start, last, uses} (Habits)
var consc := 0  # R38: the conscience, 0 clean and negative below (shown as words only; Temptation)
var skel: Array = []  # R38: open skeletons {id, due, class, size} (Temptation)
var inherit := {}  # R38: client -> inherited risk 0-100 after a takeover (Takeover)

var _dynamic := {}  # cards built at run time (the consultant's advice, inbound leads)
var _advised := false
var _advice_week := {}  # advice topic -> week Dana last opened it (no repeats inside ADVICE_GAP weeks)
var _leads := 0
var _work := {}
var _tick := 0.0
var _fired := {}
var _leaving: Array = []  # clients that threatened to leave, asked about next morning
var _late: Array = []  # clients with invoices long overdue, asked about next morning
var _asked := {}  # client -> week we last chased them
var _qbr_done := {}  # client -> week of their last business review
var _commission_week := 0
var _handover: Array = []  # new clients waiting for a sales-to-service handover decision
var _burn_warned := false
var _poach_queue: Array = []  # competitor attempts waiting for the next morning
var _winback_queue: Array = []  # lost clients asking to come back
var _poach_cool := 0
var _poach_wave := 0  # weeks the competitor is running a campaign (double the risk)
var _ransom_ticket := 0
var _ransom_client := 3  # the client of the ransom card that is open (Story.RANSOM_CLIENT, or the victim of a skipped restore test)
var _ransom_forced := false  # the backup looked fine and still did not restore (H1 never tested, a skipped test, an inherited mess)
var _ransom_skip := false  # this ransom is the bill of the skipped restore test: no lawsuit on top


func _ready() -> void:
	for id in RivalCards.CARDS:  # R38: the rival arc and temptation cards are data in rival_cards.gd (shared with story/strings.txt)
		CARDS[id] = RivalCards.CARDS[id]
	for id in OwnerCast.CARDS:  # X11: the second cast's cards (owner_cast.gd)
		CARDS[id] = OwnerCast.CARDS[id]


# X8: the old active() gate is split into Campaign.crew_active() / books_active() / cards_active() (the mode registry)
func reset() -> void:
	cash = START_CASH + Build.cash_bonus()
	flags = {}
	price = 1.0
	speed = 1.0
	vic_bonus = 0.0
	weekly_extra = 0
	payroll_extra = 0
	lost_techs = 0
	draw_policy = "normal"
	draw_paid = 0
	draw_warned = -9
	hire_quits = 0
	incidents = 0
	_outings_seen = 0
	Partner.reset()
	extra_staff = []
	marketing = 0
	stack = DEFAULT_STACK.duplicate()
	ar = []
	fee_boost = {}
	vic_plan = "salary"
	vic_deals = 0
	vic_signed = []
	_late = []
	_asked = {}
	_qbr_done = {}
	_commission_week = 0
	client_work = {}
	profit_hist = {}
	scope_fixed = {}
	burnout = 0.0
	bailout = 0
	leak = 0.0
	leak_found = false
	risk_client = -1
	risk_choice = ""
	goal = {}
	patch_debt = {}
	gone = {}
	_poach_queue = []
	_winback_queue = []
	_poach_cool = 0
	_poach_wave = 0
	_ransom_ticket = 0
	_ransom_client = Story.RANSOM_CLIENT
	_ransom_forced = false
	_ransom_skip = false
	_handover = []
	_burn_warned = false
	discount = {}
	income_extra = 0
	history = []
	habits = {}
	consc = 0
	skel = []
	inherit = {}
	_work = {}
	_tick = 0.0
	_fired = {}
	_leaving = []
	_dynamic = {}
	_advised = false
	_advice_week = {}
	_leads = 0


# ---- the team works the queue ----------------------------------------------------------------
func team_speed() -> float:
	var total := crew_skill() + Partner.hands()
	for hire in extra_staff:
		total += float(hire.skill) + (0.1 if hire.get("trait", "") == "wizard" else 0.0)
	var morale := (
		(0.9 + clampf(Social.average() / 400.0, -0.1, 0.2)) * (1.0 + (stack_sum("morale") + edge("morale")) / 100.0)
	)
	return (
		total
		* (speed + stack_sum("speed"))
		* morale
		* MANAGER_BOOST
		* (1.0 - burnout / 300.0)
		* (1.0 - Growth.capacity_loss())
		* (1.0 - Projects.drag())
	)


# ---- the stack you run and sell ----------------------------------------------------------------
# ---- who is on the team (X4): Dan, Maya, the hires, Morgan as the manager and the partner at half speed ----------------
func crew_size() -> int:
	return maxi(0, CREW.size() - lost_techs)


func crew_names() -> Array:
	var out := []
	for i in crew_size():
		out.append(str(CREW[i].name))
	return out


# the ticket-working skill of the employees you started with (hires are added by team_speed)
func crew_skill() -> float:
	if Campaign.mode == "service":
		return Crew.skill()  # Maya and the two techs, scaled by morale (C4)
	var total := 0.0
	for i in crew_size():
		total += float(CREW[i].skill)
	return total


# everyone who works the queue, in people (the project capacity model counts heads, not skill)
func crew_heads() -> float:
	return float(crew_size()) + float(extra_staff.size()) + Partner.hands()


func crew_wages() -> int:
	var total := 0
	for i in crew_size():
		total += int(round(float(CREW[i].wage) * wage_mult()))
	return total + int(round(float(MORGAN_WAGE) * wage_mult()))


# ---- your edges (X4): Alan is the technical owner, Garrison the sales-and-culture one. Point-buy (X7) will add its bias
# floors in edges_for(), nothing else needs to change.
func edges_for(owner_name: String) -> Dictionary:
	var out: Dictionary = DEFAULT_EDGE.duplicate()
	var mine: Dictionary = OWNER_EDGES.get(owner_name, {})
	for key in mine:
		out[key] = mine[key]
	var plus: Dictionary = Build.edge_deltas(owner_name)  # point-buy (X7): the stats above the free floors
	for key in plus:
		if out.has(key):
			out[key] = Build.clamp_edge(str(key), float(out[key]) + float(plus[key]))
	return out


func edge(key: String) -> float:
	if Campaign.mode == "service":
		return Service.edge(key)  # the huddle focus and the memo effects (C4)
	return float(edges_for(Campaign.player_as)[key]) if Campaign.cards_active() else float(DEFAULT_EDGE[key])


func stack_option(category: String) -> Dictionary:
	return STACK[category].options[stack[category]]


func stack_sum(key: String) -> float:
	var total := 0.0
	for category in STACK:
		total += float(stack_option(str(category)).get(key, 0.0))
	return total


func stack_cost() -> int:
	return int(stack_sum("cost"))


# ticket volume multiplier: unreliable hardware and a weak RMM mean more calls
func issue_mult() -> float:
	if not Campaign.crew_active():
		return 1.0
	var m := float(edge("issues"))
	for category in STACK:
		m *= float(stack_option(str(category)).get("issues", 1.0))
	if flags.get("after_hours_fee", false):
		m *= 0.92  # most non-critical after-hours calls stop
	return m


# how exposed you are to a vendor compromise: the RMM you chose
func security_risk() -> float:
	return float(stack_option("rmm").get("risk", 1.0)) * float(edge("stack_risk"))


# scope creep: a few clients generate far more requests until you enforce the contract
func client_weight(client: int) -> float:
	if not Campaign.crew_active():
		return 1.0
	return 1.0 if scope_fixed.get(client, false) else float(HEAVY.get(client, 1.0))


func client_profit(client: int) -> int:
	var hist: Array = profit_hist.get(client, [])
	if hist.is_empty():
		return client_fee(client) - int(float(client_work.get(client, 0.0)) * COST_PER_SEC)
	var total := 0
	for value in hist:
		total += int(value)
	return int(total / hist.size())


# the community's own maturity ladder (Beginning ... Innovating): count the good habits you have built
func practices() -> int:
	var n := 0
	for flag in [
		"practice_profit",
		"practice_goal",
		"practice_handover",
		"collections_done",
		"backup_service"
	]:
		n += 1 if flags.get(flag, false) else 0
	n += 1 if price != 1.0 else 0
	n += 1 if flags.get("peer_group", false) or flags.get("mentor", false) else 0
	n += 1 if vic_plan != "salary" else 0
	n += 1 if stack_sum("speed") > 0.0 else 0
	n += 1 if flags.get("growth_done", false) else 0
	n += 1 if flags.get("practice_scope", false) else 0
	n += 1 if flags.get("practice_callback", false) else 0  # a call-back rule on payment changes
	n += 1 if flags.get("practice_postmortem", false) else 0  # a blameless post-incident review
	n += 1 if int(flags.get("outings", 0)) >= 2 else 0
	n += Habits.practice_count()  # R38: adopted habits count (at most 3)
	return n


func oml() -> int:
	# a habit takes weeks to show: the level is capped by the calendar (4 at week 12, 5 at week 16)
	return clampi(mini(1 + (practices() * 2) / 5, 1 + Campaign.day / 4), 1, 5)


# everything that makes John better or worse at selling (pay plan, marketing, price, hardware)
func vic_extra() -> float:
	if not Campaign.books_active():
		return 0.0
	return (
		vic_bonus
		+ marketing_bonus()
		+ float(VIC_PLANS[vic_plan].skill)
		+ stack_sum("sales")
		- Growth.vic_penalty()
		- Projects.vic_penalty()
	)


func hardware_margin() -> int:
	return int(stack_option("hardware").margin)


func new_client_mood() -> int:
	return int(VIC_PLANS[vic_plan].start_mood) + int(edge("new_mood"))


# John closed something: pay his commission, bank the hardware resale margin
func on_deal(kind: String, client: int) -> void:
	if not Campaign.books_active():
		return
	vic_deals += 1
	vic_signed.append(client)
	var bonus := int(VIC_PLANS[vic_plan].per_deal)
	cash -= bonus
	_commission_week += bonus
	var margin := hardware_margin() * (2 if kind == "client" else 1)
	cash += margin
	income_extra += margin
	if kind == "client":
		_handover.append(client)


func _process(delta: float) -> void:
	var crew := Campaign.crew_active()
	var cards := Campaign.cards_active()
	if not (crew or cards) or Game.title_mode or World.time_scale <= 0.0 or not Msp.enabled:
		return
	var dt := delta * World.time_scale
	if crew:
		_tick += dt
		if _tick >= 3.0:
			var slice := _tick
			_tick = 0.0
			_work_queue(slice)
	if not cards or Campaign.mode == "sales":
		return  # the sales campaign has its own weekly cards (SalesCampaign)
	var events: Array = events_on(Campaign.day) if Campaign.mode == "owner" else []
	for i in events.size():
		var ev: Dictionary = events[i]
		if not _fired.has(i) and World.clock >= float(ev.at):
			_fired[i] = true
			fire(ev)
	if (
		flags.get("mentor", false)
		and not _advised
		and Campaign.day >= 7
		and Campaign.day < Campaign.TOTAL_DAYS
		and World.clock >= 9.7
	):
		_advised = true
		advice()


# the scripted events of a week; Year 2 moves some of them by a week or two (Yeartwo.story_shuffle)
func events_on(day: int) -> Array:
	return Yeartwo.events_on("owner", day, OwnerCast.merged_days(RivalCards.merged_days(DAYS)))


func _work_queue(seconds: float) -> void:
	if Campaign.mode == "service":
		Service.work_queue(seconds)  # every tech works what is on his desk (C5)
		return
	var capacity := team_speed() * seconds
	for t in Msp.open_tickets():
		if t.fix == "project" or t.fix == "network" or t.internal:
			continue
		if Campaign.mode == "service" and str(t.special) != "":
			continue  # incidents are yours or your delegate's (Service.incident)
		if t.fix_done:
			Msp.close_ticket(int(t.id))
			continue
		if capacity <= 0.0:
			break
		var need: float = float(_work.get(int(t.id), WORK[int(t.pri)]))
		var take := minf(need, capacity)
		client_work[int(t.client)] = float(client_work.get(int(t.client), 0.0)) + take
		Dash.add_hours("CREW", take)
		capacity -= take
		need -= take
		_work[int(t.id)] = need
		if need <= 0.0:
			_finish_ticket(t)


func _finish_ticket(t: Dictionary) -> void:
	_work.erase(int(t.id))
	if Difficulty.rng("owner").randf() < float(edge("close_miss")):
		Msp.close_ticket(int(t.id))  # closed too early: it comes back
		return
	Growth.owner_escalation(t)
	Msp.set_status(int(t.id), "In Progress")
	Msp.rmm_action(str(t.endpoint), str(t.fix))
	Msp.close_ticket(int(t.id))


# ---- a new week ------------------------------------------------------------------------------
func begin_day(day: int) -> void:
	if Campaign.mode == "service":
		return  # the service campaign has its own mornings (Service.begin_day)
	_fired = {}
	_advised = false
	income_extra = 0
	if flags.get("backup_service", false):
		for c in Msp.backups.size():
			Msp.backups[c].ok = true
			Msp.backups[c].good_day = day
	else:
		for c in Sales.active:
			if not Msp.backups[int(c)].ok and Difficulty.rng("owner").randf() < float(edge("backup_check")):
				Msp.backup_rerun(int(c))  # a tech happened to check it
	if Campaign.mode == "sales":
		return  # no owner decisions for the account manager (SalesCampaign.begin_week deals the cards)
	if not _late.is_empty():
		var late_client: int = _late.pop_front()
		_collections(late_client)
	if not _leaving.is_empty():
		var client: int = _leaving.pop_front()
		_ask_leaving(client)
	if _leads > 0:
		_leads -= 1
		_inbound_lead()
	if not _handover.is_empty():
		_handover_card(int(_handover.pop_front()))
	if not _poach_queue.is_empty():
		_poach_card(_poach_queue.pop_front())
	if not _winback_queue.is_empty():
		_winback_card(int(_winback_queue.pop_front()))
	Incident.morning()
	Rival.morning(self)
	Projects.begin_week()


func fire(ev: Dictionary) -> void:
	if ev.get("event", "") == "partner":
		Partner.hold_beat(str(ev.card))  # a partner meeting (weeks 5, 9, 13, 17)
		return
	if ev.get("event", "") == "peer":
		if flags.get("peer_group", false):
			show_card(str(ev.card))
		return
	if ev.has("card"):
		show_card(str(ev.card))
		return
	match str(ev.event):
		"prospect":
			_prospect_card()
		"qbr":
			_qbr()
		"vic_report":
			_vic_report()
		"grumble":
			_grumble()
		"leak_start":
			leak = 0.06  # a vendor price rise nobody passed on; some work nobody billed
		"leak_hint":
			if leak > 0.02 and flags.get("peer_group", false):
				show_card("billing_audit")
		"profit_review":
			_profit_review()
		"client_no":
			_client_no()
		"client_breach":
			_client_breach()
		"vendor_breach":
			_vendor_breach()
		"poach_wave":
			_poach_wave = 3
			show_card("poach")
		"peer_goal":
			_peer_goal()
		"break_backup":
			Msp.break_backup(Story.RANSOM_CLIENT)
		"ransomware":
			_ransom()
		"owner_goal":
			_goal_card()
		"vendor_rise":
			_vendor_rise()
		"credit_squeeze":
			_credit_squeeze()
		"key_poach":
			_key_poach()
		"audit":
			_audit()
		"growth_plan":
			Growth.owner_plan_card()
		"growth_stretch":
			Growth.owner_stretch()


# week 1: Christy tells you what you are here for (your personal goal, scored at the review)
func _goal_card() -> void:
	var alan: bool = Campaign.player_as == "Alan"
	_dynamic["owner_goal"] = {
		"speaker": "Christy (Controller)",
		"text": (
			"Every owner wants something out of this place. Yours is a clean year: no ransomware loss, no break-ins, and a stack documented well enough to hand to a stranger (maturity 3). It goes on the weekly report."
			if alan
			else "Every owner wants something out of this place. Yours is the shop clients love: client mood of 75 or better, and a team that stays. It goes on the weekly report."
		),
		"options": [{"label": "GOOD. LET'S GO.", "fx": {}}],
	}
	show_card("owner_goal")


func card_data(id: String) -> Dictionary:
	return CARDS.get(id, _dynamic.get(id, {}))


func show_card(id: String) -> void:
	var card: Dictionary = card_data(id)
	var options := []
	for opt in card.options:
		var entry := {"label": str(opt.label), "id": str(options.size())}
		var need := int(opt.get("need", 0))
		if need > 0 and cash < need:
			entry["enabled"] = false
			entry["hint"] = "NEED $%d" % need
		if opt.get("policy", false) and not Msp.cyber_insured(_ransom_client):
			entry["enabled"] = false
			entry["hint"] = "NO POLICY"
		if opt.has("unless") and flags.get(str(opt.unless), false):
			entry["enabled"] = false
			entry["hint"] = "OWNED"
		if Partner.active() and (opt.get("fx", {}) as Dictionary).has("trust"):
			var d: int = Partner.trust_delta(opt)  # X9: the arrows: does this choice move the partnership?
			entry["trust_chip"] = "TRUST " + Partner.trust_word_for(d)
			entry["trust_dir"] = d
		var stance: String = "" if bool(card.get("beat", false)) else Partner.stance(opt)  # the other owner's opinion (a chip on the option)
		if stance != "":
			entry["stance"] = stance
			entry["chip"] = Partner.chip(stance)
			if Partner.blocks(stance):
				entry["enabled"] = false
				entry["hint"] = "PARTNER HAS TO AGREE"
		options.append(entry)
	Cards.ask(
		str(card.speaker),
		fill_text(str(card.text)),
		options,
		func(pick: String) -> void: _picked(id, int(pick))
	)


# X9: numbers a card quotes are read when it opens ({cash} = what is in the bank right now)
func fill_text(body: String) -> String:
	return Incident.fill(body.replace("{cash}", money(cash)))


# X9: a possessive that copes with names ending in s ("Lindqvist and Moss Architects'", not "Architects's")
func poss(name: String) -> String:
	return name + ("'" if name.ends_with("s") or name.ends_with("S") else "'s")


# $1,234 and -$23 (a minus sign goes in front of the dollar sign)
func money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return "%s$%s%s" % ["-" if amount < 0 else "", digits, out]


# a mentor shifts 10% of the odds from the worst outcome to the best
func tilted(table: Array) -> Array:
	var out := []
	for entry in table:
		out.append([float(entry[0]), entry[1], entry[2]])
	if flags.get("mentor", false) and out.size() >= 2:
		var shift := minf(0.1, float(out[out.size() - 1][0]))
		out[0][0] += shift
		out[out.size() - 1][0] -= shift
	# a pricing talk: Garrison sells a fee rise better than Alan does (edge fee_accept)
	var accept := float(edge("fee_accept"))
	if accept != 0.0 and out.size() >= 2 and (out[0][1] as Dictionary).has("fee_boost"):
		var moved := clampf(accept, 0.05 - float(out[0][0]), float(out[out.size() - 1][0]))
		out[0][0] += moved
		out[out.size() - 1][0] -= moved
	return out


func _picked(id: String, index: int) -> void:
	if card_data(id).is_empty():
		return  # a card left over from an earlier run (the books were reset under it)
	var opt: Dictionary = card_data(id).options[index]
	var partner_note := ""
	if not bool(card_data(id).get("beat", false)):
		partner_note = Partner.on_pick(Partner.stance(opt))  # follow their call, or override it
	elif Partner.active():
		var delta: int = Partner.trust_delta(opt)
		partner_note = (
			"%s: TRUST SAME." % Partner.who().to_upper()
			if delta == 0
			else "%s: TRUST %s%d." % [Partner.who().to_upper(), "+" if delta > 0 else "", delta]
		)
	var text := str(opt.get("text", ""))
	if opt.has("roll"):
		var roll := Difficulty.rng("owner").randf()
		var acc := 0.0
		var table: Array = opt.roll
		if opt.has("roll_scoped") and flags.get("scoped", false):
			table = opt.roll_scoped
		for entry in tilted(risk_adjust(opt, table)):
			acc += float(entry[0])
			if roll <= acc:
				apply(entry[1])
				text = str(entry[2])
				break
	else:
		apply(opt.get("fx", {}))
	flags["card_" + id] = index
	if partner_note != "" and (text != "" or partner_note.contains("OPPOSED") or bool(card_data(id).get("beat", false))):
		text = (text + " " + partner_note).strip_edges()
	if text != "":
		Cards.ask(str(card_data(id).speaker), text, OPTIONS_OK, func(_p: String) -> void: pass)


func apply(fx: Dictionary) -> void:
	cash += int(fx.get("cash", 0))
	if fx.has("rep"):
		Campaign.adjust_rep(int(fx.rep))
	if fx.has("mood_all"):
		for c in Sales.active:
			Sales.adjust(int(c), int(fx.mood_all))
	if fx.has("mood"):
		for key in fx.mood:
			Sales.adjust(int(key), int(fx.mood[key]))
	if fx.has("flag"):
		flags[str(fx.flag)] = true
	if fx.has("unflag"):
		flags[str(fx.unflag)] = false
	if fx.has("marketing"):
		marketing = int(fx.marketing)
	if fx.has("burnout"):
		burnout = clampf(burnout + float(fx.burnout), 0.0, 100.0)
	if fx.has("owner_hours"):
		Growth.owner_used += float(fx.owner_hours)  # hours of the owner's week (a review, a letter)
	if fx.has("social_all"):
		Social.change_all(int(fx.social_all))  # how the team feels about it
	if fx.has("pm"):
		Incident.owner_review(str(fx.pm[0]), str(fx.pm[1]))  # a post-incident review: class, how
	if fx.has("bec"):
		Incident.owner_fx(str(fx.bec))  # wire fraud
	if fx.has("remediate"):
		var healed := int(fx.remediate)
		Msp.backup_rerun(healed)
		patch_debt[healed] = 0.0
	if fx.has("discount_one"):
		var d: Dictionary = fx.discount_one
		discount[int(d.client)] = {"mult": float(d.mult), "weeks": int(d.weeks)}
	if fx.get("health_check", false):
		for c in Sales.active:
			Msp.backup_rerun(int(c))
			patch_debt[int(c)] = float(patch_debt.get(int(c), 0.0)) * 0.5
	if fx.has("rejoin"):
		var back := int(fx.rejoin)
		if not Sales.active.has(back):
			Sales.active.append(back)
		var extra := int((fx.get("mood", {}) as Dictionary).get(str(back), 0))
		Sales.satisfaction[back] = clampi(70 + extra, 0, 100)
		patch_debt[back] = 4.0  # nobody patched them while they were away
		gone.erase(back)
	if fx.has("gone_clear"):
		gone.erase(int(fx.gone_clear))
	if fx.has("ransom_end"):
		cash += int(float(fx.get("cash", 0)) * (Habits.ransom_mult() - 1.0))  # R38: H1, a tested restore halves the bill
		_ransom_finish(str(fx.ransom_end))
	if fx.has("fire"):
		var told: String = Projects.fire_client(int(fx.fire.client), str(fx.fire.how))
		Msp.send_text("Christy", told)
		Hints.toast(told, 4.0)
	if fx.has("squeeze"):
		for c in fx.squeeze:
			flags["squeeze_%d" % int(c)] = 2  # these clients pay this many weeks later from now on
	if fx.has("discount_set"):
		for d in fx.discount_set:
			discount[int(d[0])] = {"mult": float(d[1]), "weeks": int(d[2])}
	if fx.has("change_order"):
		var result: String = Projects.change_order(int(fx.change_order))
		Msp.send_text("Christy", result)
		Hints.toast(result, 4.0)
	if fx.has("scope"):
		scope_fixed[int(fx.scope)] = true
	if fx.get("fix_leak", false):
		leak = 0.01
		leak_found = true
	if fx.has("risk_choice"):
		risk_choice = str(fx.risk_choice)
		Habits.refusal(risk_choice)  # R38: H4, a refusal on paper
	if fx.has("goal"):
		goal = {"id": str(fx.goal), "week": Campaign.day}
	if fx.has("stack"):
		for category in fx.stack:
			cash -= Mutators.stack_fee(str(category), str(fx.stack[category]))
			stack[str(category)] = str(fx.stack[category])
	if fx.has("vic_plan"):
		vic_plan = str(fx.vic_plan)
	if fx.has("fee_boost"):
		fee_boost[int(fx.fee_boost.client)] = float(fx.fee_boost.mult)
	if fx.has("collect"):
		_collect(int(fx.collect), float(fx.get("fraction", 1.0)))
	if fx.has("writeoff"):
		_writeoff(int(fx.writeoff))
	if fx.has("drop_client"):
		drop_client(int(fx.drop_client), str(fx.get("left_for", "")))
	if fx.get("trip", false):
		Career.add("trips")
	if fx.get("candidates", false):
		_hire_card()
	if fx.has("show"):
		show_card(str(fx.show))
	if fx.get("check_backups", false):
		for c in Sales.active:
			Msp.backup_check(int(c))
			Msp.backup_rerun(int(c))
	price += float(fx.get("price", 0.0))
	speed += float(fx.get("speed", 0.0))
	vic_bonus += float(fx.get("vic", 0.0))
	weekly_extra += int(fx.get("weekly", 0))
	payroll_extra += int(fx.get("payroll", 0))
	if fx.get("train", false):
		speed += 0.25 if int(flags.get("trained_count", 0)) == 0 else 0.12  # the second course teaches less
		flags["trained_week"] = Campaign.day
		flags["trained_count"] = int(flags.get("trained_count", 0)) + 1
	if fx.has("hire"):
		var newbie: Dictionary = fx.hire.duplicate()
		newbie["age"] = 0
		extra_staff.append(newbie)
	if fx.get("lose_tech", false) and not Difficulty.cozy_on():
		if lost_techs < MAX_LOST:
			lost_techs += 1
		elif not extra_staff.is_empty():
			extra_staff.pop_back()
			hire_quits += 1
	if fx.has("draw"):
		draw_policy = str(fx.draw)
	if fx.has("trust"):
		Partner.change(int((fx.trust as Dictionary).get(Roles.partner(), 0)))
	if fx.get("sign", false):
		var signed: int = Sales.sign_client(int(fx.get("client", -1)))
		if signed >= 0:
			Habits.new_client(signed)  # R38: H10, a client who was told the truth starts happier
		if signed >= 0 and fx.has("sign_bonus"):
			# the owner closed it in person: better first-month mood and a better fee
			Sales.satisfaction[signed] = clampi(Sales.mood(signed) + int(fx.sign_bonus.mood), 0, 100)
			fee_boost[signed] = float(fx.sign_bonus.fee)
		if signed >= 0 and fx.has("discount_new"):
			discount[signed] = {
				"mult": float(fx.discount_new.mult), "weeks": int(fx.discount_new.weeks)
			}
	if fx.has("onsite_visit"):
		Onsite.start_visit(int(fx.onsite_visit.client), str(fx.onsite_visit.kind))
	if fx.get("drop", false):
		drop_random_client()
	if fx.has("discount"):
		for c in Sales.active:
			discount[int(c)] = {"mult": float(fx.discount.mult), "weeks": int(fx.discount.weeks)}
	if fx.has("quote"):
		var q: Dictionary = fx.quote
		cash += int(q.cash) - int(q.cost)
		income_extra += int(q.cash) - int(q.cost)
		Campaign.adjust_rep(int(q.rep))
	if fx.has("rap"):
		Rival.apply_rap(fx.rap)
	if fx.has("habit"):
		Habits.apply_touch(str(fx.habit))
	if fx.has("habit_start"):
		Habits.apply_start(fx.habit_start)
	if fx.has("habit_adopt"):
		Habits.apply_adopt(str(fx.habit_adopt))  # R38: a card from Christy or Alan, paid for
	if fx.has("consc"):
		Temptation.change_consc(int(fx.consc))
	if fx.has("skel"):
		Temptation.apply_skel(fx.skel)
	if fx.has("come_clean"):
		Temptation.come_clean(str(fx.come_clean))  # R38: own up to a skeleton before its bill
	if fx.get("vendor_switch", false):
		Temptation.switch_vendor(self)  # the intro rate, and the costs the card does not show
	if fx.get("ransom_end", "") == "insured" or fx.get("bec", "") == "claim":
		Temptation.claim(self)  # R38: an insurance claim reads the renewal answers (the dateless temp_quest bill)
	if fx.has("visit"):
		Takeover.visit(self, str(fx.visit))
	if fx.has("lead"):
		_leads += int(fx.lead)
	if fx.has("rival"):
		Rival.apply_fx(self, fx.rival)
	Msp.changed.emit()


# which advice card Dana opens: the relevant ones in priority order, never one shown in the last 3 weeks
func training_open() -> bool:
	return Campaign.day - int(flags.get("trained_week", -99)) >= 4 and int(flags.get("trained_count", 0)) < 2


func advice_topic(open: int, est: Dictionary) -> String:
	var relevant := []
	if cash < 1500:
		relevant.append("cash")
	if float(est.w2) > W2_TARGET + 0.15:
		relevant.append("w2")
	if Sales.average() < 55.0:
		relevant.append("mood")
	if open >= 5:
		relevant.append("queue")
	if relevant.is_empty():
		relevant.append("healthy")
	relevant.append_array(["lunch", "push"])
	if training_open():
		relevant.append("train")  # X9: never twice within four weeks, and only twice in a run
	var oldest := ""
	for topic in relevant:
		var since: int = Campaign.day - int(_advice_week.get(topic, -99))
		if since >= ADVICE_GAP:
			return str(topic)
		if oldest == "" or int(_advice_week.get(topic, -99)) < int(_advice_week.get(oldest, -99)):
			oldest = str(topic)
	return oldest


# the consultant's Monday advice: a card built from your actual numbers
func advice() -> void:
	var text := ""
	var options := []
	var open := Msp.open_tickets().size()
	var est := weekly_estimate()
	var key := advice_topic(open, est)
	_advice_week[key] = Campaign.day
	if key == "cash":
		text = "Cash is thin. I would look at pricing before anything else, and I would not add payroll right now."
		options = [
			{"label": "RAISE PRICES 8% (MOOD -3)", "fx": {"price": 0.08, "mood_all": -3}},
			{"label": "I WILL MANAGE", "fx": {}}
		]
	elif key == "w2":
		text = (
			"Your W-2 ratio is %d%%. Healthy MSPs stay near %d%%. Either grow revenue or hold payroll flat until you do."
			% [int(100.0 * float(est.w2)), int(100.0 * W2_TARGET)]
		)
		options = [
			{"label": "PUSH SALES (MARKETING $400/WEEK)", "fx": {"marketing": 400}},
			{"label": "HOLD PAYROLL FLAT", "fx": {}}
		]
	elif key == "mood":
		text = "Your clients are unhappy. That always turns into churn a few weeks later. Fix the relationship before the revenue disappears."
		options = [
			{
				"label": "CLIENT REVIEW LUNCHES ($300)",
				"need": 300,
				"fx": {"cash": -300, "mood_all": 8}
			},
			{"label": "FOCUS THE TEAM ON SLAS", "fx": {"speed": 0.1}}
		]
	elif key == "queue":
		text = (
			"Your queue is backing up (%d open). Either add hands or make the hands you have faster."
			% open
		)
		options = [
			{"label": "SEE HIRING CANDIDATES", "fx": {"candidates": true}},
			{"label": "TRAIN THE CREW ($400)", "need": 400, "fx": {"cash": -400, "train": true}}
		]
		if not training_open():
			options.pop_back()
	elif key == "healthy":
		text = (
			"Things look healthy: your EBITDA margin is %d%%. This is the time to invest in growth and put money behind John."
			% int(100.0 * float(est.margin))
		)
		options = [
			{"label": "MARKETING PUSH ($500)", "need": 500, "fx": {"cash": -500, "vic": 0.1}},
			{"label": "KEEP DOING WHAT WORKS", "fx": {}}
		]
	elif key == "train":
		text = "Whatever else is going on, the crew is the product. A week of training pays back in faster tickets and fewer reopens."
		options = [
			{"label": "TRAIN THE CREW ($400)", "need": 400, "fx": {"cash": -400, "train": true}},
			{"label": "NOT NOW", "fx": {}}
		]
	elif key == "lunch":
		text = "Clients rarely say they are unhappy until the day they leave. Take your best ones to lunch before the competitor does."
		options = [
			{"label": "CLIENT REVIEW LUNCHES ($300)", "need": 300, "fx": {"cash": -300, "mood_all": 8}},
			{"label": "NOT NOW", "fx": {}}
		]
	else:
		text = "Pipeline pays for next year. Your EBITDA margin is %d%%: put a little money behind John whatever the month looks like." % int(100.0 * float(est.margin))
		options = [
			{"label": "MARKETING PUSH ($500)", "need": 500, "fx": {"cash": -500, "vic": 0.1}},
			{"label": "NOT NOW", "fx": {}}
		]
	options.append(
		{"label": "DISMISS DANA (SAVE $400/WEEK)", "fx": {"weekly": -400, "unflag": "mentor"}}
	)
	_dynamic["advice"] = {
		"speaker": "Dana Whitfield (Consultant)", "text": text, "options": options
	}
	show_card("advice")


# week 6: a named prospect (one who is not a client yet) asks for a discount to sign
func _prospect_card() -> void:
	var pool := []
	for c in Msp.CLIENTS.size():
		if not Sales.active.has(c):
			pool.append(c)
	if pool.is_empty() or Sales.active.size() >= Sales.max_clients():
		return
	var who: int = pool[Difficulty.rng("owner").randi() % pool.size()]
	var card: Dictionary = CARDS.prospect.duplicate(true)
	card.text = str(card.text) % Msp.CLIENTS[who].name
	for opt in card.options:
		if opt.has("fx") and opt.fx.has("sign"):
			opt.fx["client"] = who
		if opt.has("roll"):
			for entry in opt.roll:
				if entry[1].has("sign"):
					entry[1]["client"] = who
	_dynamic["prospect_live"] = card
	show_card("prospect_live")


# marketing brought in a prospect: you can take the meeting or hand it to John
func _inbound_lead() -> void:
	if not Mutators.chance("lead_mult"):
		return
	var pool := []
	for c in Msp.CLIENTS.size():
		if not Sales.active.has(c):
			pool.append(c)
	if pool.is_empty() or Sales.active.size() >= Sales.max_clients():
		return
	pool.sort_custom(
		func(a: int, b: int) -> bool: return int(Onsite.has_site(a)) > int(Onsite.has_site(b))
	)
	var lead: int = pool[0]
	var prospect: String = Msp.CLIENTS[lead].name
	var vic_odds := clampf(Sales.vic_skill() + 0.25, 0.3, 0.95)
	_dynamic["lead"] = {
		"speaker": "John Marlowe",
		"text":
		"An inbound lead from our marketing: %s found us online and wants a meeting." % prospect,
		"options":
		[
			{
				"label": "TAKE THE MEETING YOURSELF (60%: HAPPIER, +10% FEE)",
				"roll":
				[
					[
						0.6,
						{"sign": true, "client": lead, "sign_bonus": {"mood": 15, "fee": 1.1}},
						"You charm them. %s signs at a better rate and starts happy." % prospect
					],
					[0.4, {}, "They say they will think about it."]
				]
			},
			{
				"label": "LET JOHN CLOSE IT (%d%%)" % int(vic_odds * 100.0),
				"roll":
				[
					[
						vic_odds,
						{"sign": true, "client": lead},
						"John closes it. %s signs." % prospect
					],
					[1.0 - vic_odds, {}, "John fumbles it. They go quiet."]
				]
			},
		],
	}
	if Onsite.has_site(lead):
		(
			_dynamic["lead"]
			. options
			. append(
				{
					"label": "PITCH THEM AT THEIR OFFICE (%d MIN)" % Onsite.estimate_minutes(lead),
					"fx": {"onsite_visit": {"client": lead, "kind": "pitch"}},
				}
			)
		)
	show_card("lead")


func marketing_bonus() -> float:
	var spend := float(marketing)
	return spend / (spend + 1500.0) * 0.4 * Growth.marketing_factor() * float(edge("marketing"))


# ---- hiring: three named candidates with skills and quirks ----------------------------
func make_candidates() -> Array:
	var pool: Array = NAMES.duplicate()
	Difficulty.shuffle_with(pool, Difficulty.rng("owner"))
	var trait_ids: Array = TRAITS.keys()
	var out := []
	for i in 3:
		var skill := snappedf(Difficulty.rng("owner").randf_range(0.5, 1.3), 0.05)
		var trait_id: String = trait_ids[Difficulty.rng("owner").randi() % trait_ids.size()]
		var wage := (
			int(round((280.0 + 250.0 * skill) / 10.0)) * 10 + int(TRAITS[trait_id].get("wage", 0))
		)
		out.append({"name": pool[i], "skill": skill, "wage": wage, "trait": trait_id})
	return out


func _hire_card() -> void:
	var options := []
	for cand in make_candidates():
		var label := (
			"%s  SKILL %.2f  $%d/WK  %s"
			% [
				str(cand.name).to_upper(),
				float(cand.skill),
				int(cand.wage),
				str(TRAITS[cand.trait].label)
			]
		)
		options.append(
			{"label": label, "fx": {"hire": cand}, "text": "%s joins the team." % cand.name}
		)
	options.append({"label": "NO ONE RIGHT NOW", "fx": {}})
	_dynamic["hire"] = {
		"speaker": "Christy (Controller)",
		"text":
		"Three candidates came through the door. Skill is relative to a solid, experienced tech at 1.0; wages are weekly and count toward your W-2 ratio.",
		"options": options,
	}
	show_card("hire")


# new hires change week by week: green ones learn, people-people please clients, flight risks leave
func _staff_week() -> void:
	for hire in extra_staff.duplicate():
		hire["age"] = int(hire.get("age", 99)) + 1
		var trait_data: Dictionary = TRAITS.get(str(hire.get("trait", "steady")), {})
		if trait_data.has("grow"):
			hire.skill = minf(1.0, float(hire.skill) + float(trait_data.grow))
		if trait_data.has("mood"):
			for c in Sales.active:
				Sales.adjust(int(c), int(trait_data.mood))
		var quit_chance := (
			float(trait_data.get("quit", 0.0)) + (0.08 if stack_sum("morale") <= -8.0 else 0.0)
		)
		if not Difficulty.cozy_on() and Difficulty.rng("owner").randf() < quit_chance:
			extra_staff.erase(hire)
			hire_quits += 1
			Msp.send_text("Christy", "%s quit." % hire.name)
			Habits.departure(str(hire.name))  # R38: H6, the offboarding checklist
	if stack_sum("morale") <= -8.0 and not Difficulty.cozy_on() and lost_techs < MAX_LOST and Difficulty.rng("owner").randf() < 0.08:
		lost_techs += 1
		Msp.send_text("Morgan", "One of the crew just quit over the tooling.")
		Habits.departure("The tech")
	if flags.get("oncall_one", false) and not Difficulty.cozy_on() and lost_techs < MAX_LOST and Difficulty.rng("owner").randf() < 0.05:
		lost_techs += 1
		flags["oncall_one"] = false
		Msp.send_text("Dan", "I am done carrying the pager every week. I quit.")
		Habits.departure("Dan")


# ---- the crew complains about bad tools ---------------------------------------------------------------
func _grumble() -> void:
	if stack_sum("morale") > -6.0:
		return
	var worst_cat := ""
	var worst := 0
	for category in STACK:
		var m := int(stack_option(str(category)).get("morale", 0))
		if m < worst:
			worst = m
			worst_cat = str(category)
	if worst_cat == "":
		return
	var fallback: Dictionary = {worst_cat: DEFAULT_STACK[worst_cat]}
	_dynamic["grumble"] = {
		"speaker": "{ops}",
		"text":
		(
			"The crew hates %s. Morale is sinking and people are updating their resumes."
			% str(stack_option(worst_cat).name)
		),
		"options":
		[
			{
				"label": "SWITCH BACK TO THE STANDARD ($300)",
				"need": 300,
				"fx": {"cash": -300, "stack": fallback},
				"text": "Cheers all round."
			},
			{
				"label": "PAY A TOOL BONUS ($400)",
				"need": 400,
				"fx": {"cash": -400, "speed": 0.1},
				"text": "A bonus buys goodwill, for a while."
			},
			{
				"label": "TELL THEM TO DEAL WITH IT",
				"roll":
				[
					[0.6, {}, "They grumble and carry on."],
					[
						0.4,
						{"lose_tech": true, "rep": -1},
						"One of the crew resigns over the tooling."
					]
				]
			},
		],
	}
	show_card("grumble")


# ---- accounts receivable: some clients pay late -------------------------------------------------
func pay_delay(client: int) -> int:
	var delay := int(SLOW_PAYERS.get(client, 0)) + int(Mutators.hook("pay_delay", 0))
	delay += int(flags.get("squeeze_%d" % client, 0))
	if Sales.mood(client) < 35:
		delay += 1
	return delay


func ar_total(client := -1) -> int:
	var total := 0
	for inv in ar:
		if client < 0 or int(inv.client) == client:
			total += int(inv.amount)
	return total


func overdue(client: int) -> bool:
	for inv in ar:
		if int(inv.client) == client and int(inv.age) >= 2:
			return true
	return false


func _collect(client: int, fraction: float) -> void:
	for inv in ar.duplicate():
		if int(inv.client) != client:
			continue
		if fraction >= 1.0:
			cash += int(inv.amount)
			ar.erase(inv)
		else:
			var part := int(float(inv.amount) * fraction)
			cash += part
			inv.amount = int(inv.amount) - part


func _writeoff(client: int) -> void:
	var lost := ar_total(client)
	for inv in ar.duplicate():
		if int(inv.client) == client:
			ar.erase(inv)
	income_extra -= lost  # bad debt hits EBITDA


func _collections(client: int) -> void:
	var owed := ar_total(client)
	if owed <= 0 or not Sales.active.has(client):
		return
	var key := str(client)
	_dynamic["collections"] = {
		"speaker": "Christy (Controller)",
		"text":
		(
			"%s owes us $%d and the invoices are weeks late. Their contact keeps saying the check is in the mail."
			% [Msp.CLIENTS[client].name, owed]
		),
		"options":
		[
			{
				"label": "SEND A FIRM REMINDER",
				"roll":
				[
					[0.55, {"collect": client, "mood": {key: -2}}, "They pay up, a bit sulkily."],
					[0.45, {"mood": {key: -4}}, "They promise next week. Again."]
				]
			},
			{
				"label": "OFFER A PAYMENT PLAN (HALF NOW)",
				"fx": {"collect": client, "fraction": 0.5, "mood": {key: 2}},
				"text": "Half arrives now. The rest will trickle in."
			},
			{
				"label": "SUSPEND SERVICE UNTIL THEY PAY",
				"roll":
				[
					[0.7, {"collect": client, "mood": {key: -12}}, "They pay in a hurry, furious."],
					[
						0.3,
						{"writeoff": client, "drop_client": client},
						"They walk away without paying."
					]
				]
			},
			{
				"label": "WRITE IT OFF",
				"fx": {"writeoff": client},
				"text": "Written off. Christy sighs and updates the books."
			},
		],
	}
	flags["collections_done"] = true
	show_card("collections")


func drop_client(client: int, reason := "") -> void:
	if reason != "":
		# lost to the competitor: they may come back if your service was otherwise good
		gone[client] = {"week": Campaign.day, "reason": reason, "mood": Sales.mood(client)}
	Sales.active.erase(client)
	discount.erase(client)
	fee_boost.erase(client)
	scope_fixed.erase(client)
	profit_hist.erase(client)
	client_work.erase(client)
	Projects.client_gone(client)
	if client == risk_client:
		risk_client = -1
	Habits.loss(client)  # R38: H5, the lost account review
	Msp.send_text("John", "%s is gone." % Msp.CLIENTS[client].name)


# a client is due a business review from week 6 on, 8 weeks after the last one (never at the start)
func review_due(client: int) -> bool:
	return Campaign.day >= 6 and Campaign.day - int(_qbr_done.get(client, -99)) >= 8


# ---- quarterly business review: a client meeting ----------------------------------------------------------
func _qbr() -> void:
	var pick := -1
	var worst := 100000
	for c in Sales.active:
		if not review_due(int(c)):
			continue
		var score := Sales.mood(int(c)) - client_fee(int(c)) / 100
		if score < worst:
			worst = score
			pick = int(c)
	if pick < 0:
		return
	_qbr_done[pick] = Campaign.day
	Habits.qbr(pick)  # R38: H2, the one page scorecard goes out with the review
	var key := str(pick)
	var odds := clampf(
		(
			Sales.vic_skill()
			+ 0.15
			+ (0.1 if Sales.mood(pick) >= 70 else 0.0)
			+ float(edge("qbr"))
			- pressure() * 0.15
		),
		0.15,
		0.65
	)
	# X9: a full review also puts the numbers on the table: an unhappy client uses it to ask for a discount
	var backfire := clampf(0.08 + pressure() * 0.12 + float(60 - Sales.mood(pick)) / 300.0, 0.05, 0.35)
	_dynamic["qbr"] = {
		"speaker": "John Marlowe",
		"text":
		(
			"Business review time with %s (mood %d%%, they pay $%d a week). How much do we prepare?"
			% [Msp.CLIENTS[pick].name, Sales.mood(pick), client_fee(pick)]
		),
		"options":
		[
			{
				"label": "FULL REVIEW WITH JOHN ($250)",
				"need": 250,
				"roll":
				[
					[
						odds,
						{
							"cash": -250,
							"mood": {key: 12},
							"fee_boost": {"client": pick, "mult": 1.1}
						},
						"A great review: they add premium support. Their fee goes up 10%."
					],
					[
						maxf(0.0, 1.0 - odds - backfire),
						{"cash": -250, "mood": {key: 6}},
						"A solid review. They feel heard."
					],
					[
						backfire,
						{"cash": -250, "mood": {key: -6}, "discount_set": [[pick, 0.9, 6]]},
						"The review goes badly: the numbers show how many tickets they were unhappy about. They ask for 10% off for six weeks to stay."
					]
				]
			},
			{
				"label": "QUICK CHECK-IN (FREE)",
				"roll":
				[
					[0.6, {"mood": {key: 4}}, "A friendly check-in."],
					[0.4, {"mood": {key: 1}}, "They seem distracted."]
				]
			},
			{"label": "JUST SEND A REPORT", "fx": {"mood": {key: 1}}},
		],
	}
	if Onsite.has_site(pick):
		(
			_dynamic["qbr"]
			. options
			. append(
				{
					"label": "GO ONSITE FOR THE REVIEW (%d MIN)" % Onsite.estimate_minutes(pick),
					"fx": {"onsite_visit": {"client": pick, "kind": "qbr"}},
				}
			)
		)
	show_card("qbr")


# ---- the owner's view of the sales guy ---------------------------------------------------------------------
func vic_new_client_mood() -> int:
	var total := 0
	var n := 0
	for c in vic_signed:
		if Sales.active.has(c):
			total += Sales.mood(int(c))
			n += 1
	return int(total / n) if n > 0 else -1


func _vic_report() -> void:
	var avg := vic_new_client_mood()
	var text := (
		"I have closed %d deals so far under the %s plan."
		% [vic_deals, str(VIC_PLANS[vic_plan].label).to_lower()]
	)
	if avg >= 0:
		text += " My new clients average %d%% happiness." % avg
		if avg < 60:
			text += " A few of them did say I over-promised."
	_dynamic["vic_report"] = {
		"speaker": "John Marlowe",
		"text": text,
		"options":
		[
			{
				"label": "GIVE HIM A BONUS ($300)",
				"need": 300,
				"fx": {"cash": -300, "vic": 0.05},
				"text": "John puts the bonus toward a very nice watch."
			},
			{"label": "CHANGE HIS PAY PLAN", "fx": {"show": "vic_plan"}},
			{"label": "NO CHANGES", "fx": {}},
		],
	}
	show_card("vic_report")


# ---- client profitability and scope creep -----------------------------------------------------------
func _profit_review() -> void:
	flags["practice_profit"] = true
	var pick := -1
	var worst := 1.0
	for c in Sales.active:
		if (profit_hist.get(int(c), []) as Array).size() < 2:
			continue
		var ratio := float(client_profit(int(c))) / float(maxi(1, client_fee(int(c))))
		if ratio < worst:
			worst = ratio
			pick = int(c)
	if pick < 0 or worst >= 0.2:
		return
	var key := str(pick)
	var fee := client_fee(pick)
	var profit := client_profit(pick)
	_dynamic["profit"] = {
		"speaker": "Christy (Controller)",
		"text":
		(
			"%s pays $%d a week but the work costs us about $%d: %d hours a week against %d included. After labor we %s $%d a week on them. What do we do?"
			% [
				Msp.CLIENTS[pick].name,
				fee,
				fee - profit,
				int(Projects.avg_hours(pick)),
				int(Projects.included_hours(pick)),
				"make" if profit >= 0 else "LOSE",
				absi(profit)
			]
		),
		"options":
		[
			{
				"label": "RAISE THEIR FEE 20%",
				"roll":
				[
					[
						0.55,
						{"fee_boost": {"client": pick, "mult": 1.2}, "mood": {key: -4}},
						"They grumble and agree. The fee goes up 20%."
					],
					[
						0.2,
						{"fee_boost": {"client": pick, "mult": 1.1}, "mood": {key: -12}},
						"They only accept 10% and resent it."
					],
					[0.25, {"drop_client": pick}, "They walk away rather than pay more."]
				]
			},
			{
				"label": "ENFORCE THE SCOPE (CHANGE ORDERS)",
				"roll":
				[
					[
						0.6,
						{"scope": pick, "mood": {key: -6}},
						"They grumble, but the endless small requests stop."
					],
					[0.4, {"mood": {key: -12}}, "They push back hard and refuse to sign anything."]
				]
			},
			{
				"label":
				(
					"BILL A CHANGE ORDER ($%d, ABOUT %d%% AGREE)"
					% [Projects.change_order_amount(pick), int(Projects.change_order_odds(pick) * 100.0)]
				),
				"fx": {"change_order": pick}
			},
			{"label": "OTHER: LET THEM GO, OR KEEP EATING IT", "fx": {"show": "profit_fire"}},
		],
	}
	_dynamic["profit_fire"] = {
		"speaker": "Christy (Controller)",
		"text":
		(
			"Firing %s is an option, but word travels in a small business crowd, especially if they leave angry. A polite exit with notice is safer than a sudden one."
			% Msp.CLIENTS[pick].name
		),
		"options":
		[
			{
				"label": "FIRE THEM POLITELY (30 DAYS NOTICE)",
				"fx": {"fire": {"client": pick, "how": "polite"}}
			},
			{"label": "FIRE THEM NOW", "fx": {"fire": {"client": pick, "how": "now"}}},
			{"label": "KEEP THEM AND EAT THE COST", "fx": {}},
		],
	}
	show_card("profit")


# ---- burnout: the crew has limits ------------------------------------------------------------------------------
func _burnout_week() -> void:
	var open := Msp.open_tickets().size()
	var relief := (
		(4.0 if flags.get("after_hours_fee", false) else 0.0)
		+ (3.0 if flags.get("oncall_stipend", false) else 0.0)
		+ 2.0 * float(extra_staff.size())
	)
	relief += (
		(2.0 if flags.get("flex_hours", false) else 0.0)
		+ (3.0 if flags.get("four_day", false) else 0.0)
	)
	relief -= (
		(3.0 if flags.get("oncall_one", false) else 0.0)
		+ (2.0 if flags.get("strict_hours", false) else 0.0)
	)
	burnout = clampf(burnout + clampf(float(open - 3) * 4.0, -6.0, 12.0) - relief, 0.0, 100.0)
	if burnout >= 50.0 and not _burn_warned:
		_burn_warned = true
		_dynamic["burnout"] = {
			"speaker": "{ops}",
			"text":
			"{me}, the crew is fried. Nights, weekends, a queue that never empties. Somebody is going to quit if nothing changes.",
			"options":
			[
				{"label": "SEE HIRING CANDIDATES", "fx": {"candidates": true}},
				{"label": "TALK ABOUT AFTER-HOURS PAY", "fx": {"show": "after_hours"}},
				{"label": "THEY WILL BE FINE", "fx": {}},
			],
		}
		show_card("burnout")
	if burnout >= 70.0 and not Difficulty.cozy_on() and lost_techs < MAX_LOST and Difficulty.rng("owner").randf() < 0.18:
		lost_techs += 1
		burnout = maxf(0.0, burnout - 20.0)
		Msp.send_text("Morgan", "One of the crew quit. Burned out.")


# ---- X9: late-game pressure: risky upsells, a squeeze on the books, a poached key hire, an audit, a slow payer -----
# how hard the company is squeezed: it grows from week 9 and with every client past six
func pressure() -> float:
	return clampf(float(Campaign.day - 8) / 10.0, 0.0, 1.0) + 0.05 * float(maxi(0, Sales.active.size() - 6))


# an option with "risk": {client, base, late} moves odds from its best outcome to its worst: an unhappy client, a busy
# late game and a partner with a weaker pricing edge make the gamble worse; a happy client makes it safer
func risk_shift(opt: Dictionary) -> float:
	if not opt.has("risk"):
		return 0.0
	var r: Dictionary = opt.risk
	var client := int(r.get("client", -1))
	var mood := Sales.average()
	if client >= 0 and Sales.active.has(client):
		mood = float(Sales.mood(client))
	return (
		float(r.get("base", 0.0))
		+ pressure() * float(r.get("late", 0.12))
		+ (60.0 - mood) / 250.0
		- float(edge("fee_accept")) * 0.5
	)


func risk_adjust(opt: Dictionary, table: Array) -> Array:
	var shift := risk_shift(opt)
	if shift == 0.0 or table.size() < 2:
		return table
	var out := []
	for entry in table:
		out.append([float(entry[0]), entry[1], entry[2]])
	var last := out.size() - 1
	var moved := clampf(shift, -float(out[last][0]), float(out[0][0]) - 0.05)
	out[0][0] -= moved
	out[last][0] += moved
	return out


# week 13: both vendors reprice per seat. The more clients, the more it hurts.
func _vendor_rise() -> void:
	var amount := 20 + 14 * Sales.active.size()
	var peer: bool = flags.get("peer_group", false)
	var haggle := 0.75 if peer else 0.55
	_dynamic["vendor_rise"] = {
		"speaker": "Christy (Controller)",
		"text":
		(
			"Our RMM and PSA vendors both announced per-seat pricing. With %d clients that is about $%d more every week from now on. The other MSPs got the same letter."
			% [Sales.active.size(), amount]
		),
		"options":
		[
			{"label": "PAY IT AND MOVE ON", "fx": {"weekly": amount}},
			{
				"label": "NEGOTIATE A TWO-YEAR DEAL",
				"roll":
				[
					[haggle, {"weekly": amount / 2}, "They meet you halfway: the rise is $%d a week." % (amount / 2)],
					[1.0 - haggle, {"weekly": amount}, "They will not move. Full price, and a cooler call."]
				]
			},
			{
				"label": "SWITCH VENDORS ($800 AND A ROUGH MONTH)",
				"need": 800,
				"fx": {"cash": -800, "burnout": 6, "mood_all": -2},
				"text": "The migration eats a month of evenings. The new bill is flat, and nobody sends flowers."
			},
		],
	}
	show_card("vendor_rise")


# week 16: ByteBrothers makes one of your people an offer
func _key_poach() -> void:
	var names := crew_names()
	for hire in extra_staff:
		names.append(str(hire.name))
	if names.is_empty():
		return
	var who: String = str(names[Difficulty.rng("owner").randi() % names.size()])
	_dynamic["key_poach"] = {
		"speaker": "Morgan (Operations Manager)",
		"text":
		(
			"%s just told me %s offered them $120 more a week and a company van. They have not said no. What do we do?"
			% [who, COMPETITOR]
		),
		"options":
		[
			{
				"label": "MATCH THE OFFER (+$120/WEEK)",
				"roll":
				[
					[0.85, {"payroll": 120, "burnout": -2}, "%s stays and says thanks twice." % who],
					[0.15, {"lose_tech": true, "burnout": 5}, "%s takes the raise as leverage and leaves anyway." % who]
				]
			},
			{
				"label": "COUNTER WITH A TITLE AND TRAINING",
				"roll":
				[
					[0.45, {"speed": 0.02}, "%s likes the title. They stay." % who],
					[0.55, {"lose_tech": true, "burnout": 5, "rep": -1}, "%s leaves for the van. The queue gets longer." % who]
				]
			},
			{
				"label": "WISH THEM LUCK",
				"fx": {"lose_tech": true, "burnout": 6},
				"text": "%s is gone by Friday. Everyone else counts how many tickets that is." % who
			},
		],
	}
	if Campaign.mode == "owner":  # R36: what losing this tech would put at risk
		ByName.note_leaver(who)
		_dynamic["key_poach"]["text"] = str(_dynamic["key_poach"].text) + ByName.risk_line(who)
	show_card("key_poach")


# week 17: an insurer wants proof, and a former client's lawyer hints it was your fault. Preparation counts.
func _audit() -> void:
	var calm := true
	for c in Sales.active:
		calm = calm and float(patch_debt.get(int(c), 0.0)) < 3.0
	var posture := clampf(
		(
			0.25
			+ (0.25 if flags.get("backup_service", false) else 0.0)
			+ 0.07 * float(oml())
			+ (0.12 if calm else 0.0)
			+ (0.1 if flags.get("rdp_safe", false) else 0.0)
		),
		0.2,
		0.9
	)
	var prepared := minf(0.95, posture + 0.25)
	_dynamic["audit"] = {
		"speaker": "Christy (Controller)",
		"text":
		"A client's insurer wants proof of backups, patching and access control, and a lawyer for a client we lost has hinted the lost files were our fault. Somebody will read our paperwork next week. How do we meet it?",
		"options":
		[
			{
				"label": "HIRE A CONSULTANT TO PREPARE THE FILE ($900)",
				"need": 900,
				"roll":
				[
					[prepared, {"cash": -900, "rep": 1}, "The file is spotless. The insurer sends a thank-you and the lawyer goes quiet."],
					[1.0 - prepared, {"cash": -2400, "rep": -1}, "The consultant finds gaps the day before. You fix them in a hurry and pay a fine."]
				]
			},
			{
				"label": "HANDLE IT OURSELVES",
				"roll":
				[
					[posture, {"rep": 1}, "The paperwork holds up. Your logs and backups speak for you."],
					[1.0 - posture, {"cash": -3000, "rep": -3, "mood_all": -3}, "The gaps are real. A $3,000 settlement, a notice to every client, and a bad week."]
				]
			},
			{
				"label": "SETTLE QUIETLY ($1,500)",
				"need": 1500,
				"fx": {"cash": -1500},
				"text": "Christy writes the cheque. The lawyer never calls again; neither does the feeling that it was close."
			},
		],
	}
	show_card("audit")


# week 15: the two biggest payers move to slow terms
func _credit_squeeze() -> void:
	var order := []
	for c in Sales.active:
		order.append(int(c))
	if order.size() < 2:
		return
	order.sort_custom(func(a: int, b: int) -> bool: return client_fee(a) > client_fee(b))
	var a: int = order[0]
	var b: int = order[1]
	var moods := {str(a): -4, str(b): -4}
	var harsh := {str(a): -10, str(b): -10}
	_dynamic["credit_squeeze"] = {
		"speaker": "Christy (Controller)",
		"text":
		(
			"%s and %s say accounting changed and they will pay on net-60 terms from now on. That is our two biggest invoices sitting out for two more weeks."
			% [Msp.CLIENTS[a].name, Msp.CLIENTS[b].name]
		),
		"options":
		[
			{"label": "ACCEPT THE NEW TERMS", "fx": {"squeeze": [a, b]}},
			{
				"label": "INSIST ON THE CONTRACT TERMS",
				"roll":
				[
					[0.55, {"mood": moods}, "They grumble and keep paying on time."],
					[0.45, {"mood": harsh, "squeeze": [a, b]}, "They dig in, resent the pressure, and pay late anyway."]
				]
			},
			{
				"label": "OFFER 2% OFF FOR PAYING ON TIME",
				"fx": {"discount_set": [[a, 0.98, 8], [b, 0.98, 8]]},
				"text": "They take the discount and pay on time, for now."
			},
		],
	}
	show_card("credit_squeeze")


# ---- a vendor breach: the RMM you chose ---------------------------------------------------------------------------
func _vendor_breach() -> void:
	var hit := clampf(0.35 * security_risk() * Incident.lesson_mult("email") * Takeover.worst_mult(), 0.05, 0.8)
	var vendor: String = str(stack_option("rmm").name)
	_dynamic["vendor_breach"] = {
		"speaker": "{tech}",
		"text":
		(
			"%s just announced a breach: attackers pushed malicious code through their update channel. Every shop that uses it is exposed, including us. How fast do we move?"
			% vendor
		),
		"options":
		[
			{
				"label": "NOTIFY CLIENTS + ROTATE CREDENTIALS ($600)",
				"need": 600,
				"fx": {"cash": -600, "mood_all": -3, "rep": 2},
				"text": "You got ahead of it. Clients respected the honesty."
			},
			{
				"label": "WAIT FOR THE VENDOR'S STATEMENT",
				"roll":
				[
					[
						hit,
						{"cash": -int(3500.0 * Habits.breach_mult()), "mood_all": -10, "rep": -4},
						"Two clients were hit before the vendor said a word. Lawyers are involved."
					],
					[1.0 - hit, {}, "Nothing happened, this time."]
				]
			},
			{
				"label": "SWITCH TO ANOTHER RMM NOW ($800)",
				"need": 800,
				"fx": {"cash": -800, "stack": {"rmm": "labrat_gold"}, "mood_all": -2},
				"text": "A painful weekend, but you are off the compromised tool."
			},
		],
	}
	show_card("vendor_breach")


# ---- the client who said no ---------------------------------------------------------------------------------------
func _client_no() -> void:
	var pool := []
	for c in Sales.active:
		pool.append(int(c))
	if pool.is_empty():
		return
	var pick: int = pool[Difficulty.rng("owner").randi() % pool.size()]
	risk_client = pick
	risk_choice = ""
	var key := str(pick)
	_dynamic["client_no"] = {
		"speaker": "{tech}",
		"text":
		(
			"%s owner refuses to turn on two-factor login for email. 'Too annoying for staff.' We have warned them twice. They will not budge."
			% poss(Msp.CLIENTS[pick].name)
		),
		"options":
		[
			{
				"label": "GET A SIGNED RISK-ACCEPTANCE WAIVER",
				"fx": {"risk_choice": "waiver", "mood": {key: -2}},
				"text": "Signed and filed. If anything happens, there is a paper trail."
			},
			{
				"label": "INSIST OR WE WALK AWAY",
				"roll":
				[
					[
						0.5,
						{"risk_choice": "insisted", "mood": {key: -6}},
						"They give in and turn two-factor login on."
					],
					[0.5, {"drop_client": pick}, "They fire you instead."]
				]
			},
			{"label": "LET IT GO", "fx": {"risk_choice": "ignored"}},
		],
	}
	show_card("client_no")


func _client_breach() -> void:
	if risk_client < 0 or not Sales.active.has(risk_client):
		return
	var name: String = Msp.CLIENTS[risk_client].name
	var key := str(risk_client)
	var text := ""
	match risk_choice:
		"insisted":
			apply({"mood": {key: 10}, "rep": 1})
			text = (
				"A phishing attempt at %s was stopped cold by the two-factor login you insisted on. They sent a thank-you."
				% name
			)
		"waiver":
			apply({"cash": -500 + Habits.refusal_save(), "mood": {key: -4}})
			text = (
				"An account at %s was taken over and a $12,000 payment redirected. Your signed waiver shows you warned them. You help them recover, and their insurer denies the claim."
				% name
			)
		_:
			if Difficulty.rng("owner").randf() < 0.5:
				apply({"cash": -4000, "rep": -4, "mood": {key: -15}})
				text = (
					"An account at %s was taken over and $12,000 was wired away. They blame you. A lawyer's letter arrives and you settle for $4,000."
					% name
				)
			else:
				apply({"cash": -1200, "rep": -2, "mood": {key: -8}})
				text = (
					"An account at %s was taken over. They blame you. You pay $1,200 to make it go away."
					% name
				)
	risk_client = -1
	Cards.ask("Christy (Controller)", text, OPTIONS_OK, func(_p: String) -> void: pass)


# ---- handing a new client from sales to service ---------------------------------------------------------------------
func _handover_card(client: int) -> void:
	if not Sales.active.has(client):
		return
	var key := str(client)
	_dynamic["handover"] = {
		"speaker": "John Marlowe",
		"text":
		(
			"Before we onboard %s: a proper handover between me and the lead tech (what I promised, their environment, their SLAs), or do we just start?"
			% Msp.CLIENTS[client].name
		),
		"options":
		[
			{
				"label": "FULL HANDOVER MEETING ($150)",
				"need": 150,
				"fx": {"cash": -150, "mood": {key: 8}, "flag": "practice_handover"},
				"text": "No surprises on day one. They start off happier."
			},
			{"label": "QUICK HALLWAY HANDOVER", "fx": {"mood": {key: 2}}},
			{
				"label": "JUST START, WE WILL FIGURE IT OUT",
				"fx": {"mood": {key: -6}},
				"text": "The first week is rough. They notice."
			},
		],
	}
	show_card("handover")


# ---- the peer group holds you to your goal -----------------------------------------------------------------------------
func _goal_met(id: String) -> bool:
	match id:
		"w2":
			return float(weekly_estimate().w2) <= 0.60
		"mood":
			return Sales.average() >= 70.0
		_:
			return ar_total() <= 1500


func _peer_goal() -> void:
	if not flags.get("peer_group", false):
		return
	if not goal.is_empty():
		var verdict := goal_verdict()
		Cards.ask("MSP Mastermind", verdict, OPTIONS_OK, func(_p: String) -> void: pass)
	var options := []
	for id in GOALS:
		options.append({"label": str(GOALS[id]), "fx": {"goal": str(id)}})
	options.append({"label": "NO GOAL THIS QUARTER", "fx": {}})
	var last_round := Campaign.day >= 17
	_dynamic["goal"] = {
		"speaker": "MSP Mastermind",
		"text":
		(
			"Set a goal for the final stretch. The group checks it at the board review: +2 reputation if you hit it, -1 if you miss."
			if last_round
			else "Set a goal for next quarter. The group checks it at the next meeting: +2 reputation if you hit it, -1 if you miss."
		),
		"options": options
	}
	show_card("goal")


# X9: the group checks the goal you set: reputation moves, the result is said out loud and the goal is cleared
func goal_verdict() -> String:
	var id := str(goal.id)
	var met := _goal_met(id)
	Campaign.adjust_rep(2 if met else -1)
	flags["practice_goal"] = true
	flags["goal_last"] = "met" if met else "missed"
	var text := (
		"GOAL MET: %s. REPUTATION +2. THE GROUP APPLAUDS." % str(GOALS[id])
		if met
		else "GOAL MISSED: %s. REPUTATION -1. THE GROUP IS DISAPPOINTED BUT SUPPORTIVE." % str(GOALS[id])
	)
	Msp.send_text("MSP Mastermind", text)
	goal = {}
	return text


# ---- patching: the quiet work that keeps clients safe (and keeps competitors out) -------------------------
func _patching(spare: float) -> void:
	var order := []
	for c in Sales.active:
		patch_debt[int(c)] = minf(10.0, float(patch_debt.get(int(c), 0.0)) + float(edge("patch")))
		order.append(int(c))
	order.sort_custom(
		func(x: int, y: int) -> bool: return float(patch_debt[x]) > float(patch_debt[y])
	)
	var jobs := int(spare / 60.0) + int(stack_sum("patching"))
	for i in mini(jobs, order.size()):
		patch_debt[order[i]] = maxf(0.0, float(patch_debt[order[i]]) - 2.0)


# ---- a competing MSP circles your clients --------------------------------------------------------------------------
func poach_gaps(client: int) -> Array:
	var out := []
	if not bool(Msp.backups[client].ok):
		out.append("failing backups")
	if float(patch_debt.get(client, 0.0)) >= 4.0:
		out.append("months of missing updates")
	if Sales.mood(client) < 50:
		out.append("unhappy users")
	if Habits.gap_restore():
		out.append("no restore proof")  # R38: H1 started and gone stale
	return out


func poach_risk(client: int) -> float:
	var r := maxf(0.0, 0.02 + float(edge("poach")))
	var mood := Sales.mood(client)
	if mood < 35:
		r += 0.12
	elif mood < 50:
		r += 0.06
	if not bool(Msp.backups[client].ok):
		r += 0.07
	var debt := float(patch_debt.get(client, 0.0))
	if debt >= 7.0:
		r += 0.10
	elif debt >= 4.0:
		r += 0.05
	if price >= 1.15:
		r += 0.03
	r += float(Mutators.hook("price_pressure", 0.0))
	r += Habits.poach_adjust(client)  # R38: a fresh restore test, listening to the front desk
	if _poach_wave > 0:
		r *= 2.0
	return minf(r, 0.6) * Difficulty.cz("poach", 1.0)  # cozy Easy: the rival calls half as often


func _poach_week() -> void:
	_poach_cool = maxi(0, _poach_cool - 1)
	if _poach_cool == 0 and Campaign.day >= 4 and not Sales.active.is_empty():
		var target := -1
		for c in Sales.active:
			# X9: the rival does not call the same client twice within six weeks (it varies the target)
			if Campaign.day - int(flags.get("poached_%d" % int(c), -99)) < 6:
				continue
			if Difficulty.rng("owner").randf() < poach_risk(int(c)):
				target = int(c)
				break
		if target < 0 and Difficulty.rng("owner").randf() < 0.04:  # rarer: a lower price, even when you did everything right
			var clean := []
			for c in Sales.active:
				if poach_gaps(int(c)).is_empty() and Campaign.day - int(flags.get("poached_%d" % int(c), -99)) >= 6:
					clean.append(int(c))
			if not clean.is_empty():
				target = clean[Difficulty.rng("owner").randi() % clean.size()]
		if target >= 0:
			_poach_queue.append(
				{"client": target, "kind": "gaps" if not poach_gaps(target).is_empty() else "price"}
			)
			flags["poached_%d" % target] = Campaign.day
			_poach_cool = 4  # X9: was 2 weeks
	_poach_wave = maxi(0, _poach_wave - 1)
	_winback_week()


func _poach_card(item: Dictionary) -> void:
	var client := int(item.client)
	if not Sales.active.has(client):
		return
	var name: String = Msp.CLIENTS[client].name
	var key := str(client)
	if str(item.kind) == "price":
		var saving := int(float(client_fee(client)) * 0.2)
		var odds := clampf(
			0.4 + float(Sales.mood(client)) / 200.0 + Sales.vic_skill() * 0.2, 0.3, 0.9
		)
		_dynamic["poach_price"] = {
			"speaker": "John Marlowe",
			"text":
			(
				"%s likes us and everything is in order, but %s offered them a price we cannot easily match: about $%d a week less. 'It is just IT,' they said."
				% [name, COMPETITOR, saving]
			),
			"options":
			[
				{
					"label": "SHOW THEM THE VALUE (REVIEW, $250)",
					"need": 250,
					"roll":
					[
						[
							odds,
							{"cash": -250, "mood": {key: 8}},
							"You walk them through the uptime, the backups, the patching. They stay."
						],
						[
							1.0 - odds,
							{"cash": -250, "drop_client": client, "left_for": "price"},
							"They liked you, but cheap won. They leave on good terms."
						]
					]
				},
				{
					"label": "MATCH PART OF IT (-10% FOR 12 WEEKS)",
					"roll":
					[
						[
							0.8,
							{
								"discount_one": {"client": client, "mult": 0.9, "weeks": 12},
								"mood": {key: 4}
							},
							"They stay on the lower price."
						],
						[0.2, {"drop_client": client, "left_for": "price"}, "They leave anyway."]
					]
				},
				{
					"label": "WISH THEM WELL",
					"fx": {"drop_client": client, "left_for": "price", "rep": 1},
					"text":
					"You part on good terms. If the cheap service disappoints, they know where to find you."
				},
			],
		}
		Rival.relabel(self, "poach_price", client)
		show_card("poach_price")
		return
	var gaps := poach_gaps(client)
	var save := clampf(
		0.8 - 0.12 * float(gaps.size()) + (0.1 if Sales.mood(client) >= 60 else 0.0), 0.3, 0.9
	)
	_dynamic["poach_gaps"] = {
		"speaker": "John Marlowe",
		"text":
		(
			"%s contact says %s walked in with a free 'IT assessment' that listed: %s. They are offering about 20%% less."
			% [poss(name), COMPETITOR, ", ".join(gaps)]
		),
		"options":
		[
			{
				"label": "FIX THE GAPS, PRESENT A PLAN ($400)",
				"need": 400,
				"roll":
				[
					[
						save,
						{"cash": -400, "remediate": client, "mood": {key: 15}},
						"You fix everything within a week and present the plan. They stay."
					],
					[
						1.0 - save,
						{
							"cash": -400,
							"remediate": client,
							"drop_client": client,
							"left_for": "gaps"
						},
						"You fixed it, but too late. They signed with the other MSP."
					]
				]
			},
			{
				"label": "MATCH THEIR PRICE (-15% FOR 8 WEEKS)",
				"roll":
				[
					[
						0.7,
						{
							"discount_one": {"client": client, "mult": 0.85, "weeks": 8},
							"mood": {key: 6}
						},
						"They stay at the lower price. The gaps are still there."
					],
					[
						0.3,
						{"drop_client": client, "left_for": "gaps"},
						"They leave anyway. Price was never the real problem."
					]
				]
			},
			{"label": "LET THEM GO", "fx": {"drop_client": client, "left_for": "gaps"}},
		],
	}
	Rival.relabel(self, "poach_gaps", client)
	show_card("poach_gaps")


# ---- they come back when the cheap service disappoints; you decide the price ----------------------------------------
func _winback_week() -> void:
	for key in gone.keys():
		var info: Dictionary = gone[key]
		var away := Campaign.day - int(info.week)
		if away < 3 or _winback_queue.has(int(key)):
			continue
		var mood := int(info.mood)
		var chance := 0.0
		if str(info.reason) == "price":
			chance = 0.12 if mood >= 60 else (0.04 if mood >= 45 else 0.0)
		else:
			chance = 0.06 if mood >= 45 else 0.0
		chance = minf(0.35, chance + 0.04 * float(maxi(0, away - 5)))
		if Difficulty.rng("owner").randf() < chance:
			_winback_queue.append(int(key))


func _winback_card(client: int) -> void:
	if not gone.has(client) or Sales.active.has(client):
		gone.erase(client)
		return
	var info: Dictionary = gone[client]
	var name: String = Msp.CLIENTS[client].name
	var key := str(client)
	var why := (
		"%s cheaper service fell apart: tickets sat for days and nobody knew their network."
		% poss(COMPETITOR)
	)
	if str(info.reason) != "price":
		why = "%s did not fix their problems either." % COMPETITOR
	var odds := 0.7 if int(info.mood) >= 60 else 0.5
	_dynamic["winback"] = {
		"speaker": "John Marlowe",
		"text": "%s called. %s They would like to come back." % [name, why],
		"options":
		[
			{
				"label": "WELCOME THEM BACK AT THEIR OLD PRICE",
				"fx": {"rejoin": client, "mood": {key: 10}, "rep": 1},
				"text": "They are back, a little embarrassed. Everyone is happier."
			},
			{
				"label": "RAISE THEIR PRICE 15%",
				"roll":
				[
					[
						odds,
						{
							"rejoin": client,
							"fee_boost": {"client": client, "mult": 1.15},
							"mood": {key: 4}
						},
						"They grumble and agree: they now know what cheap costs."
					],
					[
						1.0 - odds,
						{"gone_clear": client},
						"They shop around again and sign elsewhere."
					]
				]
			},
			{
				"label": "RAISE 15% AND PUT THE SCOPE IN WRITING",
				"roll":
				[
					[
						odds - 0.1,
						{
							"rejoin": client,
							"fee_boost": {"client": client, "mult": 1.15},
							"scope": client,
							"mood": {key: 2}
						},
						"Back at a higher price, with a clear scope this time."
					],
					[
						1.1 - odds,
						{"gone_clear": client},
						"They decide it is more trouble than it is worth."
					]
				]
			},
			{
				"label": "NOT AGAIN, THANKS",
				"fx": {"gone_clear": client},
				"text": "You wish them luck."
			},
		],
	}
	Rival.on_winback(self, client)
	show_card("winback")


func drop_random_client() -> void:
	if Sales.active.size() <= 3:
		return
	var pick: int = Sales.active[Difficulty.rng("owner").randi() % Sales.active.size()]
	Sales.active.erase(pick)
	discount.erase(pick)
	Msp.send_text("John", "We lost %s. Ouch." % Msp.CLIENTS[pick].name)


# the ransom cards name Hoot and Holler (the story client). A ransom at another client, or one whose backup looked fine and did not restore,
# shows a copy with the name, the mood target and the reason put right.
func _ransom_card(id: String) -> void:
	if _ransom_client == Story.RANSOM_CLIENT and not _ransom_forced:
		show_card(id)
		return
	var card: Dictionary = CARDS[id].duplicate(true)
	var who := str(Msp.CLIENTS[_ransom_client].name)
	var body := str(card.text)
	if _ransom_client != Story.RANSOM_CLIENT:
		body = body.replace("Hoot and Holler's", "{rvp}").replace("Hoot and Holler", who).replace("{rvp}", poss(who))
	if _ransom_forced:
		body = body.replace("The backup was not working.", "The backup light was green, and the restore failed halfway: nobody had tested it.")
		body = body.replace("because our backup was not working", "because our backup would not restore")
	card["text"] = body
	for opt in card.options:
		if opt.has("fx"):
			_ransom_retarget(opt.fx)
		for entry in opt.get("roll", []):
			_ransom_retarget(entry[1])
	_dynamic[id + "_v"] = card
	show_card(id + "_v")


func _ransom_retarget(fx: Dictionary) -> void:
	var key := str(Story.RANSOM_CLIENT)
	if _ransom_client != Story.RANSOM_CLIENT and fx.get("mood", {}) is Dictionary and (fx.get("mood", {}) as Dictionary).has(key):
		var mood: Dictionary = fx.mood
		mood[str(_ransom_client)] = mood[key]
		mood.erase(key)


# R38: the skipped restore test coming due is a real infection at one client (Temptation.ransom_bill). False when no ticket could be opened.
func ransom_at(client: int) -> bool:
	return _ransom(client)


func _ransom(client := Story.RANSOM_CLIENT) -> bool:
	var t := Msp.create_problem(client, Msp.RANSOM, "monitoring")
	if t.is_empty():
		for ep in Msp.endpoints:
			if ep.client == client and ep.name.contains("SRV"):
				ep.problem = ""
		t = Msp.create_problem(client, Msp.RANSOM, "monitoring")
	if t.is_empty():
		return false
	_ransom_ticket = int(t.id)
	_ransom_client = client
	_ransom_forced = false
	_ransom_skip = false
	if client != Story.RANSOM_CLIENT or Habits.skipped_test():
		return _ransom_untested(client)
	_ransom_story(t)
	return true


# a ransom whose restore may fail although the backup light is green. The skipped test (temp_restore still in the folder) fails for sure and
# the ransom is its bill; elsewhere the odds are H1's and the takeover's.
func _ransom_untested(client: int) -> bool:
	var t := Msp.ticket(_ransom_ticket)
	var odds := maxf(Habits.restore_fail(), Takeover.restore_fail(client))
	var failed := not bool(Msp.backups[client].ok) or odds >= 1.0 or (odds > 0.0 and Difficulty.rng("owner").randf() < odds)
	if failed:
		_ransom_forced = bool(Msp.backups[client].ok)
		if _ransom_forced:
			Msp.send_text("Alan", "The restore from backup failed halfway. Nobody ever tested it.")
		if Habits.skipped_test():
			_ransom_skip = true
			Temptation.ransom_hit(self, client)
		_ransom_card("ransom_options")
		return true
	Msp.rmm_action(str(t.endpoint), "restore")
	Msp.close_ticket(int(t.id))
	Msp.send_text("Alan", "%s got hit by CryptoLocker. We restored from backup. No data lost!" % str(Msp.CLIENTS[client].name))
	return true


func _ransom_story(t: Dictionary) -> void:
	var restore_fail := maxf(Habits.restore_fail(), Takeover.restore_fail(Story.RANSOM_CLIENT))  # R38 P4: an unfixed freezer bag. R38: H1, a backup nobody ever test restored may not restore
	var untested_fail := restore_fail > 0.0 and Difficulty.rng("owner").randf() < restore_fail
	if untested_fail:
		Msp.send_text("Alan", "The restore from backup failed halfway. Nobody ever tested it.")
	if untested_fail or not bool(Msp.backups[Story.RANSOM_CLIENT].ok):
		_ransom_forced = untested_fail and bool(Msp.backups[Story.RANSOM_CLIENT].ok)
		_ransom_card("ransom_options")  # no backup: pay, shadow copies, or accept the loss
		return
	Msp.rmm_action(str(t.endpoint), "restore")
	Msp.close_ticket(int(t.id))
	Msp.send_text(
		"Alan", "Hoot and Holler got hit by CryptoLocker. We restored from backup. No data lost!"
	)
	# X9: the good outcome gets a card too, so the backup service visibly earns its keep
	_dynamic["ransom_saved"] = {
		"speaker": "{tech}",
		"text":
		(
			"{me}, CryptoLocker hit Hoot and Holler's server this morning. The ransom note had a countdown on it. We restored last night's backup %s and nothing was lost. They only noticed because we called."
			% ("from the backup service" if flags.get("backup_service", false) else "from the one we had checked")
		),
		"options": [{"label": "GOOD. TELL THE CLIENT", "fx": {"rep": 1, "mood": {str(Story.RANSOM_CLIENT): 6}}}],
	}
	show_card("ransom_saved")


func _ransom_finish(kind: String) -> void:
	var t := Msp.ticket(_ransom_ticket)
	if t.is_empty():
		return
	var who := str(Msp.CLIENTS[_ransom_client].name)
	if kind == "lost":
		var hit := Msp.endpoint(str(t.endpoint))
		if _ransom_forced and not hit.is_empty():
			hit["restore_failed"] = true  # the backup looked fine and would not restore: closing the ticket is the loss
		else:
			Msp.rmm_action(str(t.endpoint), "restore")  # no backup: records the loss
		Msp.close_ticket(int(t.id))
		if _ransom_skip:
			Msp.send_text("Alan", "%s lost the files. No lawyers this time, but they know whose backup it was." % who)  # R38: the skipped test: the lost files and the name are the bill, no lawsuit on top
		else:
			_ransom_card("ransom_lost")
		return
	t.fix_done = true
	var ep := Msp.endpoint(str(t.endpoint))
	if not ep.is_empty():
		ep.problem = ""
	Msp.close_ticket(int(t.id))
	if _ransom_client == Story.RANSOM_CLIENT:
		Story.flags["ransom"] = kind
	Msp.send_text("Alan", "%s: %s." % [who, str(Msp.RANSOM_LINES.get(kind, Msp.RANSOM_LINES.partial))])


# ---- RDP open to the internet: a stolen login ----------------------------------------------------------------
func _rdp_week() -> void:
	if Campaign.day < 6 or flags.get("rdp_safe", false) or Sales.active.is_empty():
		return
	var chance := (0.04 if flags.get("rdp_weak", false) else 0.10) * float(edge("rdp")) * Incident.lesson_mult("ransom") * Habits.rdp_mult(bool(flags.get("rdp_weak", false))) * Takeover.worst_mult()
	if Difficulty.rng("owner").randf() >= chance:
		return
	var victim: int = Takeover.victim(Sales.active[Difficulty.rng("owner").randi() % Sales.active.size()])  # R38 P4: an inherited mess is the likelier door
	var cost := 1200 if flags.get("backup_service", false) else 2500
	if flags.get("pm_ransom", "") in ["runbook", "check"]:
		cost = int(cost * 0.75)  # the runbook: the team knows what to do
	incidents += 1
	apply({"cash": -cost, "mood": {str(victim): -12}, "rep": -3})
	Cards.ask(
		"Christy (Controller)",
		(
			"A guessed remote-desktop password at %s let someone in. They used the server to send spam and poke around the files. Cleanup and a very unhappy client cost $%d."
			% [Msp.CLIENTS[victim].name, cost]
		),
		OPTIONS_OK,
		func(_p: String) -> void: pass
	)


func _ask_leaving(client: int) -> void:
	var name: String = Msp.CLIENTS[client].name
	Cards.ask(
		"John Marlowe",
		(
			"%s is unhappy and talking about leaving. We can offer a 20%% discount for 4 weeks to keep them."
			% name
		),
		[{"label": "OFFER THE DISCOUNT", "id": "keep"}, {"label": "LET THEM GO", "id": "go"}],
		func(pick: String) -> void: _leaving_answer(client, pick)
	)


func _leaving_answer(client: int, pick: String) -> void:
	if pick == "keep":
		discount[client] = {"mult": 0.8, "weeks": 4}
		Sales.adjust(client, 25)
	else:
		Sales.active.erase(client)
		discount.erase(client)
		Msp.send_text("John", "%s is gone." % Msp.CLIENTS[client].name)


# ---- the books ---------------------------------------------------------------------------------
func client_fee(client: int) -> int:
	var mult := float(fee_boost.get(client, 1.0))
	if discount.has(client):
		mult *= float(discount[client].mult)
	return int(float(FEE) * price * mult)


# ---- costs that grow with the company and the calendar (X1 balance) ----------------------------
# the techs ask for a raise at week 12; a new hire works for 60% of the wage while they learn the ropes
func wage_mult() -> float:
	return 1.10 if Campaign.day >= 16 else (1.05 if Campaign.day >= 12 else 1.0)


func tech_wage() -> int:
	return int(round(float(WAGE) * wage_mult()))


func hire_wage(hire: Dictionary) -> int:
	var wage := int(round(float(hire.wage) * wage_mult()))
	if int(hire.get("age", 99)) < HIRE_RAMP_WEEKS:
		wage = int(round(float(wage) * 0.6))
	return wage


# rent (the lease escalates at weeks 9 and 14), liability insurance (week 12) and seats/licences/desks
# for every client past five
func overhead() -> int:
	var rent := RENT + (50 if Campaign.day >= 9 else 0) + (50 if Campaign.day >= 14 else 0)
	var insurance := 80 if Campaign.day >= 12 else 0
	var seats := maxi(0, Sales.active.size() - 5) * SEAT_COST
	# X9: service load: past six clients every extra desk needs after-hours cover and licences, and the audit year
	# raises the insurance again at week 16
	var service_load := maxi(0, Sales.active.size() - 6) * 30
	var audit_year := 60 if Campaign.day >= 16 else 0
	return rent + insurance + seats + service_load + audit_year


func weekly_estimate() -> Dictionary:
	var revenue := 0
	for c in Sales.active:
		revenue += client_fee(int(c))
	revenue = int(float(revenue) * (1.0 - leak)) + Projects.service_revenue()
	var payroll := crew_wages() + int(VIC_PLANS[vic_plan].wage) + _commission_week + payroll_extra
	for hire in extra_staff:
		payroll += hire_wage(hire)
	var fixed := int(float(overhead() + TOOLS + weekly_extra + stack_cost() + Projects.service_cost()) * Difficulty.cf("owner.cost"))
	var ebitda := revenue - payroll - fixed - marketing
	var rev := float(maxi(1, revenue))
	return {
		"revenue": revenue,
		"payroll": payroll,
		"fixed": fixed,
		"marketing": marketing,
		"ebitda": ebitda,
		"profit": ebitda,
		"draw": draw_due(),
		"cashflow": ebitda - draw_due(),
		"margin": float(ebitda) / rev,
		"w2": float(payroll) / rev,
	}


# the average weekly EBITDA of the last four settled weeks (what a buyer looks at)
func ebitda_weekly() -> float:
	if history.is_empty():
		return float(weekly_estimate().ebitda)
	var total := 0.0
	var n := mini(4, history.size())
	for i in n:
		total += float(history[history.size() - 1 - i].ebitda)
	return total / float(n)


# a buyer pays a multiple of annual EBITDA; recurring revenue quality, margin and the W-2 ratio move it
func multiple() -> float:
	var est := weekly_estimate()
	var m := 3.25  # X9: was 4.0 and up to 7.5x (now at most 5.5x); a small MSP sold for 3-5 times EBITDA in 2014
	if float(est.w2) <= W2_TARGET:
		m += 0.75
	if float(est.margin) >= PEER_MARGIN:
		m += 0.75
	if Sales.active.size() >= 6:
		m += 0.25
	if Campaign.rep >= 70:
		m += 0.25
	m += Habits.maturity_bonus(oml())  # an optimizing, innovating company is worth more (R38: replaces the old +0.25, never stacks)
	# a buyer discounts unhappy clients, a poor name and slow collections
	if Sales.average() < 35.0:
		m -= 2.0
	elif Sales.average() < 50.0:
		m -= 1.0
	if Campaign.rep < 30:
		m -= 0.5
	if ar_total() > int(float(est.revenue) * 3.0):
		m -= 0.5
	m -= Temptation.diligence()  # R38: due diligence checks Christy's folder
	return maxf(2.0, m)


# end of the week: pay the bills, collect the fees, check who is leaving
func settle() -> Dictionary:
	var est := weekly_estimate()
	Projects.week()  # payouts land before the books are added up, so profit and EBITDA agree
	var profit: int = int(est.ebitda) + income_extra
	# invoices: on-time clients pay now, slow payers join the receivables and pay weeks later
	var collected := 0
	for inv in ar.duplicate():
		inv.age = int(inv.age) + 1
		if int(inv.age) >= int(inv.delay):
			collected += int(inv.amount)
			ar.erase(inv)
	for c in Sales.active:
		# the billing leak is money you never invoiced: cash and reported revenue agree
		var fee := int(float(client_fee(int(c))) * (1.0 - leak))
		var delay := pay_delay(int(c))
		if delay <= 0:
			collected += fee
		else:
			ar.append({"client": int(c), "amount": fee, "age": 0, "delay": delay})
	collected += Projects.service_revenue()  # managed services are billed with the monthly fee
	for inv in ar:
		var who := int(inv.client)
		if (
			int(inv.age) >= 2
			and int(inv.delay) >= 3
			and not _late.has(who)
			and Campaign.day - int(_asked.get(who, -99)) >= 4
		):
			_late.append(who)
			_asked[who] = Campaign.day
	# the commission was already paid when the deals closed
	cash += collected - (int(est.payroll) - _commission_week) - int(est.fixed) - int(est.marketing)
	# the owners' draw (X4): cash out of the bank, never part of EBITDA
	var draw := draw_due()
	cash -= draw
	draw_paid += draw
	_draw_check(draw)
	_commission_week = 0
	# what each client really cost you this week
	for c in Sales.active:
		var spent := int(float(client_work.get(int(c), 0.0)) * COST_PER_SEC)
		var hist: Array = profit_hist.get(int(c), [])
		hist.append(client_fee(int(c)) - spent)
		while hist.size() > 4:
			hist.pop_front()
		profit_hist[int(c)] = hist
	var used := 0.0
	for spent_seconds in client_work.values():
		used += float(spent_seconds)
	_patching(maxf(0.0, team_speed() * 240.0 - used))
	Projects.record_week()
	client_work = {}
	_burnout_week()
	_rdp_week()
	Incident.week()
	if Campaign.mode == "owner":  # R38: the rival arc, the habits' decay and the skeleton bills (fixed order)
		Rival.arc_week(self, Campaign.day)
		Habits.week(self)
		Temptation.week(self)
		ByName.owner_week(self)  # R36: favourites, the lopsided crew, a client that follows a tech who left
	_poach_week()
	_staff_week()
	_owner_week(profit)
	var hours_row: Array = Growth.owner_week()
	if Difficulty.rng("owner").randf() < 0.12 + float(marketing) / 2500.0:
		_leads += 1
	for c in discount.keys():
		discount[c].weeks = int(discount[c].weeks) - 1
		if int(discount[c].weeks) <= 0:
			discount.erase(c)
	# premium prices wear clients down, volume pricing makes them happier
	var drift := -4 if price >= 1.15 else (2 if price <= 0.9 else 0)
	for c in Sales.active:
		Sales.adjust(int(c), drift)
		if Sales.mood(int(c)) < 35 and Difficulty.rng("owner").randf() < 0.6 and not _leaving.has(c):
			_leaving.append(c)
	var grade := "D"
	for entry in [[1500, "S"], [700, "A"], [0, "B"], [-1000, "C"]]:
		if profit >= int(entry[0]):
			grade = str(entry[1])
			break
	var red := Color("ff8a80")
	var green := Color("8fe3a0")
	var margin := 100.0 * float(profit) / float(maxi(1, int(est.revenue)))
	var rows := [
		["REVENUE", "$%d" % int(est.revenue), green],
		["PAYROLL (W-2)", "-$%d" % int(est.payroll), Color.WHITE],
		["OTHER COSTS + MARKETING", "-$%d" % (int(est.fixed) + int(est.marketing)), Color.WHITE],
		[
			"JOBS AND DEALS",
			"%s$%d" % ["+" if income_extra >= 0 else "-", absi(income_extra)],
			green if income_extra >= 0 else red
		],
		[
			"EBITDA",
			"%s$%d" % ["" if profit >= 0 else "-", absi(profit)],
			green if profit >= 0 else red
		],
		[
			"EBITDA MARGIN",
			"%d%% (PEERS %d%%)" % [int(margin), int(100.0 * PEER_MARGIN)],
			green if margin >= 100.0 * PEER_MARGIN else Color.WHITE
		],
		[
			"W-2 RATIO",
			"%d%% (TARGET %d%%)" % [int(100.0 * float(est.w2)), int(100.0 * W2_TARGET)],
			green if float(est.w2) <= W2_TARGET else red
		],
		["CASH", "$%d" % cash, green if cash >= 0 else red],
		[
			"CLIENTS, A/R OWED",
			"%d (%d%%), $%d" % [Sales.active.size(), int(Sales.average()), ar_total()],
			Color("ffd27a") if ar_total() > 0 else Color.WHITE
		],
	]
	rows.insert(
		7,
		[
			"OWNER DRAW",
			"-$%d (%s), NOT IN EBITDA" % [draw, draw_policy.to_upper()],
			Color.WHITE if draw <= 0 or cash >= DRAW_FLOOR else red
		]
	)
	rows.append(hours_row)
	if Incident.armed():
		rows.append(
			[
				"WIRE FRAUD RISK",
				"%s (%d CAUGHT, %d LOST)" % [Incident.risk_word(), int(flags.get("bec_caught", 0)), Incident.losses()],
				Color("8fe3a0") if Incident.risk_word() == "LOW" else Color("ffd27a")
			]
		)
	if Campaign.mode == "owner":  # R38
		if Habits.any():
			rows.append(["STANDARD", Habits.standard_text(), Color("8fe3a0") if Habits.standard() >= 60 else Color("ffd27a")])
		if Temptation.folder_count() > 0:
			rows.append(["FOLDER", Temptation.folder_text(), Color("ffd27a")])
		if int(flags.get("switches", 0)) > 0:
			rows.append(["SWITCHING COSTS", Temptation.switching_text(self), Color("ffd27a")])
		for rap_line in Rival.lines():
			rows.append(["RAP SHEET", rap_line, Color("ffd27a")])
		if ByName.report_text() != "":
			rows.append(["ASKED FOR BY NAME", ByName.report_text(), Color("8fe3a0")])  # R36
	rows.append(partner_row())
	rows.append(goal_row())
	if Campaign.day >= Campaign.TOTAL_DAYS and flags.get("peer_group", false) and not goal.is_empty():
		var final_verdict := goal_verdict()  # X9: the goal set in week 17 is checked at the review
		rows.append(["PEER GOAL", final_verdict.substr(0, final_verdict.find(".")), Color("8fe3a0") if flags.get("goal_last", "") == "met" else Color("ffd27a")])
	rows.append(
		[
			"RECURRING + PROJECTS",
			"$%d/WK + $%d JOBS" % [int(est.revenue), Projects.week_income],
			Color("8fe3a0")
		]
	)
	history.append(
		{
			"day": Campaign.day,
			"profit": profit,
			"ebitda": profit - Projects.take_week_income(),
			"cash": cash
		}
	)
	# X9: the estimate is written after this week joins the history, from the one valuation() everybody reads
	rows.append(["VALUE (ESTIMATE)", "%s, %s" % [value_text(), path_label()], Color("ffd27a")])
	return {
		"rows": rows,
		"title": "WEEK %d OF %d COMPLETE" % [Campaign.day, Campaign.TOTAL_DAYS],
		"grade": grade,
		"profit": profit,
		"bankrupt": cash < BANKRUPT,
	}


# what kind of company you are building, from how it looks right now
func path_label() -> String:
	var est := weekly_estimate()
	if Sales.active.size() >= 7:
		return "A GROWTH COMPANY"
	if float(est.margin) >= PEER_MARGIN:
		return "A PROFIT COMPANY"
	if (
		flags.get("peer_group", false)
		or flags.get("mentor", false)
		or flags.get("backup_service", false)
	):
		return "A SAFE PAIR OF HANDS"
	return "JUST SURVIVING"


func at_risk_count() -> int:
	var n := 0
	for c in Sales.active:
		n += 1 if poach_risk(int(c)) >= 0.12 else 0
	return n


# ---- the board review at the end ----------------------------------------------------------
# a buyer pays for the earnings AND the name: a poor reputation cuts the price (40% at worst)
func quality() -> float:
	return clampf(0.3 + 0.7 * pow(float(Campaign.rep) / 100.0, 1.5), 0.3, 1.0)  # X9: a poor name costs more


func valuation() -> int:
	# X9: a buyer discounts a young book of business (half the price at the start, full from week 12)
	var seasoning := clampf(0.5 + float(Campaign.day) / 24.0, 0.5, 1.0)
	return maxi(0, int(ebitda_weekly() * 52.0 * multiple() * quality() * seasoning) + cash - bailout)


# X9: the one text for the company value (weekly report, Boardroom, board review)
func value_text() -> String:
	return "$%d (%.1fX)" % [valuation(), multiple()]


# ---- the owners' draw, the partner and your personal goal (X4, X5) --------------------------------------------------
func draw_due() -> int:
	return int(DRAW.get(draw_policy, 0)) if Campaign.day >= DRAW_START else 0


# a draw that leaves the bank thin upsets the partner and Christy (at most once every three weeks)
func _draw_check(draw: int) -> void:
	if draw <= 0 or cash >= DRAW_FLOOR or Campaign.day - draw_warned < 3:
		return
	draw_warned = Campaign.day
	Partner.change(-3)
	Social.change(Roles.partner(), -2)
	_dynamic["draw_warn"] = {
		"speaker": "Christy (Controller)",
		"text": "We drew $%d this week and the bank is down to $%d. {partner} noticed too. Payroll comes out on Friday. Can the draw wait?" % [draw, cash],
		"options":
		[
			{"label": "CUT THE DRAW TO SMALL", "fx": {"draw": "small", "trust": {"Alan": 1, "Garrison": 1}}, "text": "Christy writes it down in pen. {partner} exhales."},
			{"label": "SKIP THE DRAW FOR NOW", "fx": {"draw": "none", "trust": {"Alan": 2, "Garrison": 2}}, "text": "Noodles for everybody. Christy looks almost cheerful."},
			{"label": "KEEP IT AS IT IS", "fx": {}},
		],
	}
	show_card("draw_warn")


func partner_row() -> Array:
	if Partner.left:
		return ["PARTNER", "%s HAS LEFT" % Roles.partner().to_upper(), Color("ff8a80")]
	var good: bool = Partner.trust >= 55
	return [
		"PARTNER TRUST",
		"%s %d (%s)" % [Roles.partner().to_upper(), Partner.trust, Partner.trust_word()],
		Color("8fe3a0") if good else (Color("ffd27a") if Partner.trust >= Partner.BLOCK_TRUST else Color("ff8a80"))
	]


# your personal goal, part by part: [{label, ok}]. `final` judges the maturity part strictly (the review).
func goal_parts(final := false) -> Array:
	var out := []
	if Campaign.player_as == "Alan":
		var ransom := str(Story.flags.get("ransom", ""))
		out.append({"label": "NO RANSOMWARE LOSS", "ok": ransom in ["", "saved", "vendor"]})
		out.append({"label": "NO BREAK-INS", "ok": incidents == 0})
		out.append({"label": "A DOCUMENTED STACK (MATURITY 3)", "ok": oml() >= 3 or (not final and Campaign.day < 12)})
	else:
		out.append({"label": "CLIENT MOOD 75+", "ok": Sales.average() >= 75.0 or (not final and Campaign.day < 6)})
		out.append({"label": "THE TEAM STAYS", "ok": lost_techs == 0 and hire_quits == 0})
	return out


func goal_title() -> String:
	return str(OWNER_GOALS.get(Campaign.player_as, OWNER_GOALS["Alan"]).title)


func goal_met() -> bool:
	for part in goal_parts(true):
		if not bool(part.ok):
			return false
	return true


func goal_row() -> Array:
	var parts := goal_parts()
	var ok := 0
	for part in parts:
		ok += 1 if bool(part.ok) else 0
	return [
		"PERSONAL GOAL",
		"%s: %d/%d%s" % [goal_title(), ok, parts.size(), " ON TRACK" if ok == parts.size() else ""],
		Color("8fe3a0") if ok == parts.size() else Color("ffd27a")
	]


# end-of-week upkeep of the partnership: outings, then the quiet drift of trust
func _owner_week(profit: int) -> void:
	var outs := int(flags.get("outings", 0))
	if outs > _outings_seen:
		var n := outs - _outings_seen
		_outings_seen = outs
		var extra := OUTING_BURN * (float(edge("outing_relief")) - 1.0) * 2.0 * float(n)
		burnout = clampf(burnout - extra, 0.0, 100.0)
		Partner.change(n)  # a night out with your partner
	Partner.week(profit)


func offers() -> Array:
	var out: Array = _base_offers()
	var p := Roles.partner()
	if p == "":
		return out
	var shown := []
	for offer in out:
		match str(offer.id):
			"sell":
				offer["label"] = "SELL THE COMPANY WITH %s FOR $%d" % [p.to_upper(), valuation()]
				offer["desc"] = (
					"BOTH SIGNATURES: A BIGGER MSP OFFERS $%d FOR THE CLIENT LIST, THE TEAM AND THE NAME. %s"
					% [valuation(), "%s SIGNS, SULKING." % p.to_upper() if Partner.rift() else "%s IS IN." % p.to_upper()]
				)
			"expand":
				if Partner.rift():
					continue  # a partner who is leaving does not co-sign a second office
			"stay":
				if Partner.left:
					offer["id"] = "left"
					offer["label"] = "CARRY ON WITHOUT %s" % p.to_upper()
					offer["desc"] = "%s WALKED OUT. YOUR NAME STAYS ON THE DOOR, ALONE." % p.to_upper()
				elif Partner.rift():
					offer["label"] = "STAY INDEPENDENT, UNEASILY"
					offer["desc"] = "NAME ON THE DOOR, BUT YOU AND %s BARELY TALK." % p.to_upper()
				else:
					offer["label"] = "STAY AND GROW TOGETHER"
					offer["desc"] = "YOUR NAME AND %s'S STAY ON THE DOOR. ONE MORE YEAR OF TICKETS." % p.to_upper()
		shown.append(offer)
	if Partner.rift() and cash >= Partner.BUYOUT_COST:
		shown.append(
			{
				"id": "buyout",
				"label": "BUY OUT %s ($%d)" % [p.to_upper(), Partner.BUYOUT_COST],
				"desc": "YOU PAY $%d FOR THEIR HALF. THE COMPANY IS YOURS ALONE." % Partner.BUYOUT_COST,
			}
		)
	if Partner.rift():
		shown.append(
			{
				"id": "sellout",
				"label": "SELL YOUR HALF TO %s ($%d)" % [p.to_upper(), valuation() / 2],
				"desc": "%s BUYS YOU OUT. YOU WALK AWAY WITH HALF THE VALUE AND NO ALARM CLOCK." % p.to_upper(),
			}
		)
	return shown


func _base_offers() -> Array:
	var out := [
		{
			"id": "sell",
			"label": "SELL THE COMPANY FOR $%d" % valuation(),
			"desc":
			"A BIGGER MSP OFFERS $%d FOR THE CLIENT LIST, THE TEAM AND THE NAME." % valuation(),
		}
	]
	if cash >= 10000 and Campaign.rep >= 55 and Sales.active.size() >= 6:
		out.append(
			{
				"id": "expand",
				"label": "OPEN A SECOND OFFICE",
				"desc":
				"YOU HAVE THE CASH, THE CLIENTS AND THE NAME TO GROW. MORE CLIENTS, MORE FIRES."
			}
		)
	(
		out
		. append(
			{
				"id": "stay",
				"label": "STAY INDEPENDENT" if cash >= 0 else "STAY (BARELY AFLOAT)",
				"desc":
				(
					"YOUR NAME STAYS ON THE DOOR."
					if cash >= 0
					else "THE BANK IS NERVOUS BUT THE DOORS STAY OPEN."
				),
			}
		)
	)
	return out


func _ending_text(ending: String) -> String:
	if Yeartwo.is_year2_ending(ending):
		return Yeartwo.ending_text(ending)
	var p := Roles.partner().to_upper()
	match ending:
		"buyout":
			return "YOU BUY OUT %s FOR $%d. THE DOOR SAYS ONLY YOUR NAME NOW. CHRISTY FRAMES THE CHEQUE." % [p, Partner.BUYOUT_COST]
		"sellout":
			return "YOU SELL YOUR HALF TO %s FOR $%d. YOU TAKE A LONG TRIP; THEY PROMISE NOT TO CHANGE THE COFFEE." % [p, valuation() / 2]
		"left":
			return "%s IS GONE. YOU RUN THE PLACE WITH MORGAN, CHRISTY AND TOO MANY SPREADSHEETS. THE PHONES KEEP RINGING." % p
	if Partner.trust >= 55:
		return "YOU AND %s KEEP YOUR NAMES ON THE DOOR. SAME TEAM, SAME PHONES, ONE MORE YEAR OF TICKETS, AND A PARTNER YOU TRUST." % p
	return "YOU KEEP YOUR NAME ON THE DOOR. SAME TEAM, SAME PHONES, ONE MORE YEAR OF TICKETS. YOU AND %s DO NOT TALK ABOUT THE REVIEW." % p


func review_lines(page: int, ending: String) -> Array:
	var blue := Color("1f4e8c")
	var ink := Color("17121f")
	var good := Color("1f7a3a")
	var lines := []
	match page:
		0:
			var est := weekly_estimate()
			lines.append(["CHRISTY (CONTROLLER) - BOARD REVIEW", blue])
			lines.append(["TWENTY WEEKS DONE. HERE IS WHERE WE STAND.", ink])
			lines.append(["CASH $%d   WEEKLY EBITDA ABOUT $%d" % [cash, int(ebitda_weekly())], ink])
			lines.append(
				[
					(
						"EBITDA MARGIN %d%%   W-2 RATIO %d%%"
						% [int(100.0 * float(est.margin)), int(100.0 * float(est.w2))]
					),
					ink
				]
			)
			lines.append(
				["CLIENTS %d   CLIENT MOOD %d%%" % [Sales.active.size(), int(Sales.average())], ink]
			)
			lines.append(
				[
					(
						"REPUTATION %d   STAFF %d"
						% [Campaign.rep, 4 + extra_staff.size() - lost_techs]
					),
					ink
				]
			)
			lines.append(["COMPANY VALUE: %s EBITDA" % value_text(), good])
			lines.append(
				[
					(
						"SALES: %d NEW CLIENTS, %d INSTALLS SOLD (%s)"
						% [Sales.deals, Sales.installs_sold, str(VIC_PLANS[vic_plan].label)]
					),
					ink
				]
			)
			lines.append(
				[
					(
						"STACK: %s, %s, %s"
						% [
							stack_option("psa").name,
							stack_option("rmm").name,
							stack_option("hardware").name
						]
					),
					ink
				]
			)
			lines.append(["A/R OWED $%d   MATURITY: %s" % [ar_total(), OML_NAMES[oml() - 1]], ink])
			if Habits.any():
				lines.append(["THE STANDARD: %s" % Habits.standard_text(), good])  # R38
			lines.append(
				[
					"RANSOMWARE: %s" % str(Msp.RANSOM_LABELS.get(str(Story.flags.get("ransom", "")), "-")),
					ink
				]
			)
		1:
			lines.append(["WHAT YOUR TEAM SAYS", blue])
			for who in Social.people():
				lines.append(["%s (%s):" % [who.to_upper(), Social.mood(who)], blue])
				lines.append(["'%s'" % str(Review.QUOTES[Social.mood(who)]), ink])
			# X9: the whole crew, not only the people with opinions: the employees and every hire
			var crew := crew_names()
			crew.append("MORGAN")
			lines.append(["THE CREW: %s" % ", ".join(crew).to_upper(), blue])
			if not extra_staff.is_empty() or hire_quits > 0:
				var hired := []
				for hire in extra_staff:
					hired.append("%s (%s)" % [str(hire.name), str(hire.get("trait", "steady")).replace("_", " ")])
				lines.append(["HIRES: %s%s" % [", ".join(hired).to_upper() if not hired.is_empty() else "NONE LEFT", "   QUIT: %d" % hire_quits if hire_quits > 0 else ""], ink])
		2:
			lines.append(["PARTNERSHIP", blue])
			lines.append(["YOU AND %s OWN THIS PLACE." % Roles.partner().to_upper(), ink])
			for line in Partner.status_lines():
				lines.append(line)
			lines.append(["YOUR GOAL: %s" % goal_title(), blue])
			for part in goal_parts(true):
				lines.append(["  %s: %s" % [str(part.label), "MET" if bool(part.ok) else "MISSED"], good if bool(part.ok) else Color("a02828")])
			lines.append(["TOOK $%d IN DRAW (%s)." % [draw_paid, draw_policy.to_upper()], ink])
			var plan := "NO PLAN" if not (flags.get("plan_sell", false) or flags.get("plan_grow", false) or flags.get("plan_split", false)) else ("SELL" if flags.get("plan_sell", false) else ("GROW" if flags.get("plan_grow", false) else "DISAGREE"))
			lines.append(["PARTNER MEETINGS HELD: %d OF 4. PLAN: %s" % [Partner.met.size(), plan], ink])
		3:
			lines.append(["YOUR OPTIONS", blue])
		_:
			lines.append(["THE END", blue])
			match ending:
				"sell":
					(
						lines
						. append(
							[
								(
									"YOU SELL FOR $%d. THE BUYER KEEPS THE TEAM AND THE CLIENTS. YOU TAKE A VERY LONG VACATION."
									% valuation()
								),
								ink
							]
						)
					)
				"expand":
					(
						lines
						. append(
							[
								"THE SECOND OFFICE OPENS NEXT MONTH. NEW CLIENTS, NEW TECHS, NEW FIRES. YOU WOULD NOT HAVE IT ANY OTHER WAY.",
								ink
							]
						)
					)
				_:
					(
						lines
						. append(
							[
								_ending_text(ending),
								ink
							]
						)
					)
			lines.append(["YOUR GOAL, %s: %s." % [goal_title(), "MET" if goal_met() else "MISSED"], good if goal_met() else ink])
			lines.append(["TECH CAMPAIGN: PLAY IT FROM THE FLOOR.", good])
	return lines


func to_dict() -> Dictionary:
	return {
		"cash": cash,
		"flags": flags,
		"price": price,
		"speed": speed,
		"vic": vic_bonus,
		"weekly": weekly_extra,
		"payroll_extra": payroll_extra,
		"lost": lost_techs,
		"draw_policy": draw_policy,
		"draw_paid": draw_paid,
		"draw_warned": draw_warned,
		"hire_quits": hire_quits,
		"incidents": incidents,
		"outings_seen": _outings_seen,
		"partner": Partner.to_dict(),
		"staff": extra_staff,
		"discount": discount,
		"history": history,
		"leaving": _leaving,
		"marketing": marketing,
		"leads": _leads,
		"stack": stack,
		"ar": ar,
		"fee_boost": fee_boost,
		"vic_plan": vic_plan,
		"vic_deals": vic_deals,
		"vic_signed": vic_signed,
		"late": _late,
		"asked": _asked,
		"qbr": _qbr_done,
		"profit_hist": profit_hist,
		"scope_fixed": scope_fixed,
		"burnout": burnout,
		"bailout": bailout,
		"leak": leak,
		"leak_found": leak_found,
		"risk_client": risk_client,
		"risk_choice": risk_choice,
		"goal": goal,
		"handover": _handover,
		"burn_warned": _burn_warned,
		"patch_debt": patch_debt,
		"gone": gone,
		"poach_queue": _poach_queue,
		"winback": _winback_queue,
		"poach_cool": _poach_cool,
		"poach_wave": _poach_wave,
		"habits": habits,
		"consc": consc,
		"skel": skel,
		"inherit": inherit,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	cash = int(data.get("cash", START_CASH))
	flags = data.get("flags", {})
	price = float(data.get("price", 1.0))
	speed = float(data.get("speed", 1.0))
	vic_bonus = float(data.get("vic", 0.0))
	weekly_extra = int(data.get("weekly", 0))
	payroll_extra = int(data.get("payroll_extra", 0))
	lost_techs = int(data.get("lost", 0))
	draw_policy = str(data.get("draw_policy", "normal"))
	draw_paid = int(data.get("draw_paid", 0))
	draw_warned = int(data.get("draw_warned", -9))
	hire_quits = int(data.get("hire_quits", 0))
	incidents = int(data.get("incidents", 0))
	_outings_seen = int(data.get("outings_seen", 0))
	Partner.from_dict(data.get("partner", {}))
	extra_staff = data.get("staff", [])
	var saved: Dictionary = data.get("discount", {})
	for key in saved:
		discount[int(key)] = saved[key]
	history = data.get("history", [])
	_leaving = data.get("leaving", [])
	marketing = int(data.get("marketing", 0))
	_leads = int(data.get("leads", 0))
	stack = data.get("stack", DEFAULT_STACK.duplicate())
	ar = data.get("ar", [])
	var boosts: Dictionary = data.get("fee_boost", {})
	for key in boosts:
		fee_boost[int(key)] = float(boosts[key])
	vic_plan = str(data.get("vic_plan", "salary"))
	vic_deals = int(data.get("vic_deals", 0))
	vic_signed = data.get("vic_signed", [])
	_late = data.get("late", [])
	var asked: Dictionary = data.get("asked", {})
	for key in asked:
		_asked[int(key)] = int(asked[key])
	var reviews: Dictionary = data.get("qbr", {})
	for key in reviews:
		_qbr_done[int(key)] = int(reviews[key])
	var hist: Dictionary = data.get("profit_hist", {})
	for key in hist:
		profit_hist[int(key)] = hist[key]
	var fixed_scopes: Dictionary = data.get("scope_fixed", {})
	for key in fixed_scopes:
		scope_fixed[int(key)] = true
	burnout = float(data.get("burnout", 0.0))
	bailout = int(data.get("bailout", 0))
	leak = float(data.get("leak", 0.0))
	leak_found = bool(data.get("leak_found", false))
	risk_client = int(data.get("risk_client", -1))
	risk_choice = str(data.get("risk_choice", ""))
	goal = data.get("goal", {})
	_handover = data.get("handover", [])
	_burn_warned = bool(data.get("burn_warned", false))
	var debts: Dictionary = data.get("patch_debt", {})
	for key in debts:
		patch_debt[int(key)] = float(debts[key])
	var lost: Dictionary = data.get("gone", {})
	for key in lost:
		gone[int(key)] = lost[key]
	_poach_queue = data.get("poach_queue", [])
	_winback_queue = data.get("winback", [])
	_poach_cool = int(data.get("poach_cool", 0))
	_poach_wave = int(data.get("poach_wave", 0))
	habits = data.get("habits", {})
	consc = int(data.get("consc", 0))
	skel = data.get("skel", [])
	var inherited: Dictionary = data.get("inherit", {})
	for key in inherited:
		inherit[int(key)] = int(inherited[key])
