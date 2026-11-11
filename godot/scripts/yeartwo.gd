extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Year 2 / New Game Plus (roadmap R10b, docs/replayability-ideas.md 3.2 and 3.3).
#
# Finishing a campaign (Campaign.finish_campaign, after the review or the board review) records the mode, the ending
# id, the final reputation, the company value / partner trust / skill levels, the difficulty and the year in the meta
# file (`user://mspsim_meta.cfg`, one section per mode). A mode whose registry row says `"year2": true` and that has
# been finished gets a title menu entry NEW GAME PLUS - <MODE> (YEAR 2). It opens the usual character select (the
# point-buy step gets +2 points) plus a MUT chip: AUTO, PICK <mutator> or BAN <mutator> (keys M and B).
#
# Year 2 is a number on the run: `Campaign.year` (1 = the normal game, 2 = Year 2; saved as `campaign/year`, an old
# save has none and loads as 1). Everything below is READ by existing functions through this autoload, so a Year 1
# run behaves exactly as before (tests/yeartwo.gd checks the neutral values):
#   CARRY   what comes over from the finished run: skills (a capped level), reputation (a fraction), the owner's company
#           value as a capped bit of start cash, the partner's trust, +2 build points. Career and Outings.known live
#           outside the campaign slot and simply stay.
#   YEAR2   what is harder: SLA clocks (Mutators.sla), the ticket weights and P1 share (Mutators.ticket_weights /
#           priority), the three newer clients active from day 1 (Sales.reset / max_clients), one tier more mutators
#           (Mutators.make_plan), the story shuffle (Story.events_on / Owner.events_on), the Year 2 beat cards that set
#           choice flags (`Story.flags["y2"]`, saved with the campaign) and the extra endings those flags unlock.
#   TEXT    the intro card, the beat cards, the offers and the epilogues (patchable like the rest).
# A new mode (service, sales) plugs in by getting `"year2": true` in Campaign.MODE_DEFS and rows in YEAR2.beats /
# YEAR2.shuffle / YEAR2.endings and TEXT; nothing else in this file names a mode except the day tables of `_base`.
#
# YEAR 3 (R10) is the last chapter and runs on the same machinery: `Campaign.year` is 3, START YEAR 3 opens once a Year 2
# run of that mode has been finished (`top_year` in the meta record; the Year 2 run's own record is kept under `y2` and is
# what Year 3 carries over from). Everything a Year 2 run reads is read through `year_cfg(key)` / `year_txt(key)`: the YEAR3 / TEXT3
# row where Year 3 has its own (the tighter clock, the closing beats, the endings that resolve the story), the Year 2 row
# otherwise (ticket weights, the newer clients, the mutator tier, the shuffle). Year 3 beat cards set `Story.flags["y3"]`.

const RivalTouches := preload("res://scripts/rival_touches.gd")  # R38 P6: the Standard carry-over and the Year 2 rival
const VERSION := 1
const YEAR := 2
const LAST_YEAR := 3  # Year 3 is the last chapter: there is no START YEAR 4
const DEFAULT_CARRY := {
	"skills": {"offset": -1, "cap": 3, "text": "SKILLS CARRY OVER ONE LEVEL LOWER, NEVER ABOVE 3."},
	"powershell": {"offset": 0, "cap": 3, "text": "POWERSHELL LESSONS YOU PASSED COUNT AS YOUR LEVEL, UP TO 3."},
	"rep": {"fraction": 0.6, "min": 40, "max": 70, "text": "REPUTATION RESTARTS AT 60 PERCENT OF WHERE YOU ENDED (40 AT LEAST)."},
	"cash": {"fraction": 0.01, "cap": 5000, "text": "ONE PERCENT OF THE COMPANY VALUE BECOMES START CASH, UP TO $5000."},
	"trust": {"min": 40, "max": 75, "text": "YOUR PARTNER'S TRUST CARRIES OVER (BETWEEN 40 AND 75)."},
	"build": {"points": 2, "text": "TWO EXTRA BUILD POINTS."},
}
var CARRY: Dictionary = DEFAULT_CARRY.duplicate(true)
const DEFAULT_YEAR2 := {
	"sla": {"mult": 0.85, "text": "SLA CLOCKS RUN 15 PERCENT TIGHTER."},
	"tickets": {
		"weights": {"spooler": 1.7, "av": 1.7, "password": 1.3, "server": 1.6},
		"p1_promote": 0.12,
		"text": "MORE PRINTER AND SECURITY TICKETS, AND MORE OF THEM ARE P1.",
	},
	"clients": {
		"client": ["Paws and Claws Veterinary", "Lindqvist and Moss Architects", "Iron Mule Demolition"],
		"max": 10,
		"text": "THREE NEW CLIENTS ARE ON THE BOOKS FROM DAY ONE.",
	},
	"mutators": {
		"counts": {"easy": [2, 3], "normal": [4, 5], "hard": [5, 6]},
		"text": "ONE TIER MORE MUTATORS.",
	},
	"shuffle": {
		"max_shift": 2,
		"text": "THE YEAR'S BIG JOBS MOVE AROUND BY A DAY OR TWO.",
		"tech": {
			"min_day": 3,
			"books": ["rdp", "ceofraud", "rack", "migration", "no2fa", "netinstall", "bus"],
			"vignettes": ["iphone", "heartbleed", "candy", "pizza", "win8", "selfreview"],
			"linked": {"donuts": "bus"},
			"fixed": ["email24", "ransomware", "install"],
		},
		"owner": {
			"min_day": 3,
			"events": ["qbr", "profit_review", "grumble", "vic_report"],
			"fixed": ["ransomware", "poach_wave", "vendor_breach", "client_breach"],
		},
	},
	"beats": {"tech": {"courted": 6, "desk": 11}, "owner": {"merger": 10, "franchise": 15}, "service": {"headhunt": 8}, "sales": {"poach": 9, "director": 14}},
	"endings": {"tech": ["head", "clientbuy"], "owner": ["merger", "franchise"]},
}
var YEAR2: Dictionary = DEFAULT_YEAR2.duplicate(true)
const DEFAULT_TEXT := {
	"intro": {
		"speaker": "YEAR 2",
		"text": "A NEW YEAR AT PIXEL IT PARTNERS. YOU KEEP WHAT YOU LEARNED, THE CLIENTS EXPECT MORE.",
	},
	"beats": {
		"tech": {
			"courted": {
				"speaker": "Tony Marsh (Iron Mule Demolition)",
				"text": "Between you and me: if you ever want out of the MSP life, I would pay Pixel a buyout fee and put you on my payroll as the IT director. Nothing to decide today.",
				"options": [
					{"label": "I AM LISTENING", "id": "listen", "reply": "Tony grins and slides over a business card with a hard hat on it.", "fx": {}},
					{"label": "TELL MORGAN FIRST", "id": "told", "reply": "Tony nods. Morgan hears it from you and quietly approves.", "fx": {"social": {"Morgan": 2}}},
					{"label": "THANKS, NO", "id": "no", "reply": "Tony shrugs. The offer stays open, he says, like a garage door.", "fx": {"rep": 1}},
				],
			},
			"desk": {
				"speaker": "Morgan (Manager)",
				"text": "I am at the vendor summit for a week. Could you run the morning stand-up and look after the desk schedule while I am gone?",
				"options": [
					{"label": "I WILL RUN THE DESK", "id": "run", "reply": "Morgan hands over the clipboard and the good pen. The team behaves, mostly.", "fx": {"xp": ["people", 8], "social_all": 1}},
					{"label": "MAYBE NEXT TIME", "id": "pass", "reply": "Morgan asks Dan instead and does not mention it again.", "fx": {}},
				],
			},
		},
		"service": {
			"headhunt": {
				"speaker": "Terry Vance (Recruiter)",
				"text": "I recruit for a bigger MSP across town. I hear your desk runs itself now. Anyone on your crew who would take a call? I pay a finder's fee for names.",
				"options": [
					{"label": "NOT MY CREW", "id": "no", "reply": "Terry smiles. Everybody says that until the offer is bigger.", "fx": {"rep": 1}},
					{"label": "ASK THEM ABOUT IT", "id": "ask", "reply": "Your crew is flattered and a little nervous. Morgan hears about it by lunch.", "fx": {"social_all": 1}},
					{"label": "GIVE HIM A NAME", "id": "name", "reply": "Terry writes it on a napkin. Somebody's phone buzzes before Friday.", "fx": {"rep": -2, "social_all": -1}},
				],
			},
		},
		"sales": {
			"poach": {
				"speaker": "Greg Pell (ByteBrothers)",
				"text": "You closed more than my whole team last year. ByteBrothers would pay you a signing bonus and a nicer tie. One lunch, no commitment.",
				"options": [
					{"label": "TELL GARRISON", "id": "told", "reply": "Garrison laughs, then asks what they offered. Then he matches half of it.", "fx": {"social": {"Garrison": 2}}},
					{"label": "KEEP IT TO YOURSELF", "id": "quiet", "reply": "Pell nods. The offer has a long shelf life, he says.", "fx": {}},
					{"label": "GO TO LUNCH", "id": "talk", "reply": "Pell buys lunch and a second dessert. Your phone shows a missed call from Garrison.", "fx": {"social": {"Garrison": -2}}},
				],
			},
			"director": {
				"speaker": "Garrison (Owner)",
				"text": "Same quota, new title. I want you running the sales side, and Wes reports to you now. You still close your own deals. You also answer for his.",
				"options": [
					{"label": "TAKE THE CHAIR", "id": "take", "reply": "Garrison hands you a key to the good filing cabinet. Wes salutes, then sits down fast.", "fx": {"xp": ["people", 8], "social": {"Garrison": 2}}},
					{"label": "STAY A CLOSER", "id": "closer", "reply": "Garrison sighs, then grins. Somebody has to keep selling, he says.", "fx": {"rep": 1}},
					{"label": "RAISE FIRST", "id": "raise", "reply": "Alan hears about it from the hallway. A title is not a salary, he says.", "fx": {"social": {"Alan": -1, "Garrison": 1}}},
				],
			},
		},
		"owner": {
			"merger": {
				"speaker": "Walt Reiner (Tri-County Tech Group)",
				"text": "I run the biggest shop in three counties and I like how yours is run. Lunch? I would like to talk about putting our names on one door.",
				"options": [
					{"label": "TAKE THE MEETING", "id": "talks", "reply": "Walt orders for both of you and asks for your client list on a napkin.", "fx": {}},
					{"label": "NOT INTERESTED", "id": "no", "reply": "Walt shakes your hand anyway. He has a long memory and a short lunch break.", "fx": {}},
				],
			},
			"franchise": {
				"speaker": "Pat Okafor (Consultant)",
				"text": "Your runbooks are better than most. Two shops in other towns would pay to use your name and your procedures. A pilot costs $1,500 for the binders and the signs.",
				"options": [
					{"label": "START A PILOT ($1500)", "id": "pilot", "reply": "Pat prints thirty binders. Christy frames the first invoice.", "fx": {"cash": -1500}, "need": 1500},
					{"label": "MAYBE LATER", "id": "later", "reply": "Pat leaves a folder on your desk. It stays there, glowing.", "fx": {}},
				],
			},
		},
	},
	"offers": {
		"head": {
			"label": "BECOME DEPARTMENT HEAD",
			"desc": "MORGAN MOVES UP AND THE OWNERS GIVE YOU THE WHOLE SERVICE DEPARTMENT: THE DESK, THE SCHEDULE AND THE BUDGET.",
		},
		"clientbuy": {
			"label": "LET IRON MULE BUY OUT YOUR CONTRACT",
			"desc": "TONY MARSH PAYS PIXEL A BUYOUT FEE AND MAKES YOU HIS IT DIRECTOR.",
		},
		"merger": {
			"label": "MERGE WITH TRI-COUNTY TECH GROUP",
			"desc": "A BIGGER SHOP, A BIGGER NOC AND BOTH NAMES ON THE DOOR. THEY VALUE YOUR SIDE AT ABOUT ${value}.",
		},
		"franchise": {
			"label": "LICENSE THE PIXEL IT NAME",
			"desc": "TWO SHOPS IN OTHER TOWNS RUN ON YOUR BINDERS AND PAY YOU A FEE. THE BRAND GOES REGIONAL.",
		},
	},
	"habits": {
		"carry": "YOUR GOOD HABITS COME OVER AT 60 PERCENT OF LAST YEAR'S STANDARD.",
		"rival_note": "BIG CHEESE IS GONE. HARD RIND IT HAS THE SAME FLYERS AND THE SAME HABITS.",
		"rival": {
			"name": "HARD RIND IT",
			"owner": "LYLE PRUITT",
			"blurb": "Hard Rind IT Services. Everything included, $41 a seat. Same flyers, new paint. Booked solid.",
		},
	},
	"endings": {
		"head": "YOU TAKE THE DEPARTMENT HEAD JOB. A DOOR WITH YOUR NAME ON IT, A BUDGET MEETING EVERY MONDAY AND A TEAM THAT LEARNED HOW TO RUN WITHOUT YOU WATCHING.",
		"clientbuy": "IRON MULE PAYS PIXEL THE BUYOUT FEE. YOUR NEW OFFICE SMELLS OF SAWDUST AND COFFEE, AND TONY MARSH TELLS EVERYONE HE HIRED THE BEST TECH IN THE COUNTY.",
		"merger": "THE PAPERS ARE SIGNED. TRI-COUNTY TECH GROUP AND PIXEL IT PARTNERS BECOME ONE SHOP WITH TWO LOGOS AND ONE VERY LONG ALL-HANDS. YOUR SIDE IS WORTH ABOUT ${value}.",
		"franchise": "TWO SHOPS IN OTHER TOWNS HANG A PIXEL IT SIGN AND RUN YOUR BINDERS. THE PHONE STILL RINGS IN YOUR OFFICE FIRST. CHRISTY ORDERS MORE FRAMES.",
	},
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)

# Year 3 (R10): only what differs from Year 2. `needs` are the thresholds of the endings (see _offer3_ok).
const DEFAULT_YEAR3 := {
	"sla": {"mult": 0.76, "text": "SLA CLOCKS RUN ANOTHER NOTCH TIGHTER: A QUARTER SHORTER THAN IN YOUR FIRST YEAR."},
	"beats": {
		"tech": {"newhire": 3, "mentor": 11, "fork": 18},
		"owner": {"summit": 6, "staff": 12, "handover": 17},
		"service": {"deputy": 4, "terry": 10, "table": 16},
		"sales": {"wes": 5, "split": 11, "chair": 16},
	},
	"endings": {
		"tech": ["y3_chair", "y3_senior", "y3_farewell"],
		"owner": ["y3_summit", "y3_staff", "y3_morgan"],
		"service": ["y3_coo", "y3_partner", "y3_across"],
		"sales": ["y3_director", "y3_wes", "y3_stake"],
	},
	"needs": {
		"y3_chair": {"rep": 60}, "y3_senior": {"rep": 55}, "y3_farewell": {"rep": 50},
		"y3_summit": {"rep": 55, "clients": 6}, "y3_staff": {"rep": 55}, "y3_morgan": {"rep": 55},
		"y3_coo": {"rep": 60}, "y3_partner": {"rep": 60, "trust": 50}, "y3_across": {"rep": 50},
		"y3_director": {"rep": 55}, "y3_wes": {"rep": 50}, "y3_stake": {"rep": 60},
	},
	# last year's endings in which you left Pixel IT: the intro card says how you came back
	"left": ["internal", "clientbuy", "leave", "sell", "sellout", "merger", "rollup", "rollup_yes", "let_go"],
}
var YEAR3: Dictionary = DEFAULT_YEAR3.duplicate(true)
const DEFAULT_TEXT3 := {
	"intro": {
		"speaker": "YEAR 3",
		"text": "YOUR THIRD YEAR AT PIXEL IT PARTNERS, AND THE ONE WHERE YOU DECIDE HOW THIS ENDS. YOU KEEP WHAT YOU LEARNED. THE CLIENTS HAVE STOPPED BEING IMPRESSED.",
		"back": "WHATEVER YOU SIGNED LAST YEAR DID NOT TAKE. PIXEL KEPT YOUR MUG.",
	},
	"beats": {
		"tech": {
			"newhire": {
				"lynk": {"from": "Morgan", "text": "The new hire starts today. Quinn. First IT job, good attitude, has never seen a print spooler. I put the desk next to yours on purpose."},
				"speaker": "Morgan (Manager)",
				"text": "You are the senior tech on this desk now, whether or not anybody printed it on a card. Quinn needs somebody to learn from. I would like that to be you and not the forum.",
				"options": [
					{"label": "SIT WITH QUINN EVERY MORNING", "id": "wing", "reply": "Quinn brings a notebook and writes down everything, including the jokes. Morgan pretends not to be pleased.", "fx": {"xp": ["people", 6], "social": {"Morgan": 2}}},
					{"label": "HAND OVER YOUR NOTES", "id": "notes", "reply": "Three years of notes in one text file. Quinn reads all of it and asks what 'DO NOT TRUST THE BLUE SWITCH' means.", "fx": {"social": {"Morgan": 1}}},
					{"label": "I HAVE A QUEUE", "id": "no", "reply": "Morgan sends Quinn to Dan. Dan hands over a label maker and says nothing for an hour.", "fx": {"social": {"Morgan": -1}}},
				],
			},
			"mentor": {
				"speaker": "Quinn (New hire)",
				"text": "I closed a ticket yesterday and it came back this morning, angry. I rebooted her PC and I did not ask her to save first. She lost a morning of invoices. Do I tell Morgan, or do you?",
				"options": [
					{"label": "WE CALL THE CLIENT TOGETHER", "id": "teach", "reply": "Quinn apologises, badly and honestly. The client softens. Nobody will ever have to tell Quinn to ask first again.", "fx": {"xp": ["people", 6], "mood_all": 1}},
					{"label": "I WILL FIX IT, GO TO LUNCH", "id": "fix", "reply": "You recover most of the invoices from a temp folder. Quinn learns that you are good at this, which was not the lesson.", "fx": {"rep": 1}},
					{"label": "TELL MORGAN YOURSELF", "id": "report", "reply": "Quinn walks to Morgan's desk like it is a long hallway. Morgan is fair about it. Quinn is quiet all week.", "fx": {}},
				],
			},
			"fork": {
				"lynk": {"from": "Dan", "text": "Alan wants me on projects full time from next year. Racks and cabling, no phones. Morgan will ask you something today. I labelled the drawer for whoever sits here next."},
				"speaker": "Morgan (Manager)",
				"text": "Dan is moving to projects. His chair comes with the schedule, the escalations and the label maker. The owners asked me who should sit in it and I said your name. Before the review: what do you want me to tell them?",
				"options": [
					{"label": "I WANT THE CHAIR", "id": "chair", "reply": "Morgan writes it down and underlines it once. Dan nods at you across the room, which from Dan is a speech.", "fx": {"social": {"Dan": 1, "Morgan": 1}}},
					{"label": "KEEP ME ON THE HARD TICKETS", "id": "tech", "reply": "Morgan is not surprised. There is a job for that, she says, and it does not come with a schedule to fill.", "fx": {"xp": ["servers", 6]}},
					{"label": "I HAVE BEEN THINKING ABOUT MOVING ON", "id": "go", "reply": "Morgan puts the pen down. Then tell me early and leave it tidy, she says. That is all I ever ask of anyone.", "fx": {"social": {"Morgan": 1}}},
				],
			},
		},
		"owner": {
			"summit": {
				"speaker": "Ross Calder (Summit Managed Holdings)",
				"text": "Summit buys well-run shops and leaves the sign up for a year. Yours is on a short list. I would like to see three years of numbers. Looking costs you nothing.",
				"options": [
					{"label": "SHOW HIM THE BOOKS", "id": "books", "reply": "Christy prints the reports and stays in the room while he reads them. He reads them twice.", "fx": {}},
					{"label": "LISTEN, SHOW NOTHING", "id": "listen", "reply": "He talks for an hour about multiples. You learn what the place is worth to a stranger. He leaves a card.", "fx": {}},
					{"label": "NOT FOR SALE", "id": "no", "reply": "He shakes your hand and says that everybody is for sale in October. The card stays on the front desk.", "fx": {"rep": 1}},
				],
			},
			"staff": {
				"speaker": "Christy (Controller)",
				"text": "Morgan and I saw the Summit man. If the company is ever for sale, we would like to be asked first. I ran it: the staff could buy it over five years out of the profit, if the owners carried the note.",
				"options": [
					{"label": "PUT IT ON PAPER", "id": "yes", "reply": "Christy already has it on paper. Morgan tells the team nothing and somehow they all know by Friday.", "fx": {"social_all": 1}},
					{"label": "NOT WHILE I AM STILL HERE", "id": "no", "reply": "Christy closes the folder without an argument. She keeps the folder.", "fx": {}},
				],
			},
			"handover": {
				"speaker": "Morgan (Manager)",
				"text": "You have not taken a week off in three years and it shows in your emails. Give me the day-to-day for a month. Approvals, hiring, the Monday numbers. You keep the cheque book. If it goes badly you will know by the smell.",
				"options": [
					{"label": "HAND MORGAN THE KEYS", "id": "trial", "reply": "You go fishing on a Tuesday. Nothing burns down. Morgan moves the stand-up fifteen minutes later and nobody tells you.", "fx": {"burnout": -2}},
					{"label": "NOT YET", "id": "no", "reply": "Morgan shrugs. The offer has no date on it, she says, but you do.", "fx": {}},
				],
			},
		},
		"service": {
			"deputy": {
				"speaker": "Morgan Reyes - Manager",
				"text": "Dan, the desk runs because you are standing at it. That is a compliment and a problem. Pick somebody on the crew to learn the board, so that it survives you taking a week off.",
				"options": [
					{"label": "TRAIN A DEPUTY", "id": "train", "reply": "You pick the one who reads the runbooks without being asked. By Friday the board has a second set of initials on it.", "fx": {"social_all": 1}},
					{"label": "WRITE IT ALL DOWN INSTEAD", "id": "write", "reply": "Forty pages, tabbed and labelled. Nobody opens it, but everybody knows where it is.", "fx": {"rep": 1}},
					{"label": "I AM NOT GOING ANYWHERE", "id": "no", "reply": "Morgan says that is what the last three managers said. She does not say where they went.", "fx": {}},
				],
			},
			"terry": {
				"speaker": "Terry Vance (Recruiter)",
				"text": "Last year I asked you for names. This year I am calling about yours. Service director across town: forty techs, a real budget, and a patch panel nobody has ever labelled. One coffee.",
				"options": [
					{"label": "ONE COFFEE", "id": "hear", "reply": "Terry brings an offer letter to a coffee. You fold it once and put it with the spare labels.", "fx": {}},
					{"label": "TELL MORGAN ABOUT THE CALL", "id": "told", "reply": "Morgan thanks you and goes straight to the owners' offices. Both doors close. That has not happened before.", "fx": {"rep": 2}},
					{"label": "NO, THANK YOU", "id": "no", "reply": "Terry says he will call again next year. He has said that before, and he did.", "fx": {"rep": 1}},
				],
			},
			"table": {
				"speaker": "Alan and Garrison - Owners",
				"text": "We agree on one thing this year, and it is you. Two ways to do it. Operations: Morgan's job and the back of the house, with a budget. Or a stake: five percent, your name on the paperwork, and you sign the line of credit with us. Which conversation are we having at the review?",
				"options": [
					{"label": "OPERATIONS", "id": "ops", "reply": "Alan nods. Garrison is already drawing a new org chart on a napkin. Your box is in the middle of it.", "fx": {"social": {"Alan": 1}}},
					{"label": "THE STAKE", "id": "partner", "reply": "Garrison shakes your hand with both of his. Alan slides a very thick folder across the desk and says read all of it.", "fx": {"social": {"Garrison": 1}}},
					{"label": "LET ME THINK", "id": "think", "reply": "They let you think. Alan gives it until the review. Garrison gives it until lunch.", "fx": {}},
				],
			},
		},
		"sales": {
			"wes": {
				"lynk": {"from": "Wes", "text": "Boss. I lost the dentist. Second quote in a row. Can you come along on my next call? I will not say anything stupid. I will try not to."},
				"speaker": "Wes Okafor",
				"text": "They said my quote was fine and then they signed with somebody else. I do not know what I am doing wrong and Garrison only tells me to smile more. Will you ride along on Thursday?",
				"options": [
					{"label": "RIDE ALONG, LET HIM TALK", "id": "coach", "reply": "You say nothing for forty minutes, which is a personal record. In the car you tell him the two things. He writes them on his hand.", "fx": {"xp": ["people", 6], "social": {"Garrison": 1}}},
					{"label": "TAKE THE CALL YOURSELF", "id": "take", "reply": "You close it in twenty minutes. Wes watches the way people watch a card trick. The deal goes on your board.", "fx": {"rep": 1}},
					{"label": "SEND HIM YOUR SCRIPT", "id": "script", "reply": "He reads your script word for word, including the part that says PAUSE HERE.", "fx": {}},
				],
			},
			"split": {
				"speaker": "Garrison (Owner)",
				"text": "The territory is too big for one book. Split it with Wes. You draw the line, and I will know what kind of boss you would be by where you draw it.",
				"options": [
					{"label": "GIVE HIM HALF THE WARM LEADS", "id": "fair", "reply": "Wes gets the north side and three leads that actually answer the phone. He buys you a coffee he cannot afford.", "fx": {"social": {"Garrison": 2}}},
					{"label": "GIVE HIM THE COLD SIDE", "id": "cold", "reply": "Wes gets the industrial park and a list of numbers that ring forever. He thanks you anyway. Garrison says nothing.", "fx": {"social": {"Garrison": -1}}},
					{"label": "KEEP THE BOOK WHOLE", "id": "keep", "reply": "Garrison lets it go. Somebody has to keep selling, he says, the same way he said it last year.", "fx": {}},
				],
			},
			"chair": {
				"speaker": "Garrison (Owner)",
				"text": "I am done carrying a bag. Somebody takes my chair at the review: the forecast, my client list and Wes. It can be you. It can be Wes, with you as the closer he calls when it matters. Or you tell me what you want instead.",
				"options": [
					{"label": "I WANT THE CHAIR", "id": "chair", "reply": "Garrison takes his name plate off the desk and puts it in his pocket. Not yet, he says. But start reading the forecast.", "fx": {"social": {"Garrison": 1}}},
					{"label": "GIVE IT TO WES", "id": "wes", "reply": "Garrison looks at you for a long moment. You trained him that well, he says. It is not a question.", "fx": {}},
					{"label": "A SHARE, NOT A TITLE", "id": "stake", "reply": "Alan hears it through the wall and comes in with a calculator. That is a good sign. He only brings the calculator to things he takes seriously.", "fx": {"social": {"Alan": 1}}},
				],
			},
		},
	},
	"offers": {
		"y3_chair": {"label": "TAKE DAN'S CHAIR", "desc": "THE SCHEDULE, THE ESCALATIONS AND THE LABEL MAKER. QUINN TAKES YOUR OLD DESK."},
		"y3_senior": {"label": "STAY TECHNICAL: SENIOR ENGINEER", "desc": "NO SCHEDULE TO FILL. THE HARD TICKETS, THE BIG JOBS AND THE LAST WORD ON THE STACK."},
		"y3_farewell": {"label": "LEAVE ON GOOD TERMS", "desc": "A MONTH OF NOTICE, A TIDY HANDOVER AND A DESK THAT RUNS WITHOUT YOU."},
		"y3_summit": {"label": "SELL TO SUMMIT", "desc": "SUMMIT MANAGED HOLDINGS BUYS THE COMPANY FOR ABOUT ${value}. THE SIGN STAYS UP FOR A YEAR."},
		"y3_staff": {"label": "SELL TO THE STAFF", "desc": "MORGAN, CHRISTY AND THE TEAM BUY IT OVER FIVE YEARS OUT OF THE PROFIT. YOU CARRY THE NOTE."},
		"y3_morgan": {"label": "KEEP IT, MORGAN RUNS IT", "desc": "YOUR NAME STAYS ON THE DOOR. MORGAN TAKES THE DAY-TO-DAY, YOU TAKE TUESDAYS OFF."},
		"y3_coo": {"label": "RUN OPERATIONS", "desc": "MORGAN'S JOB AND THE BACK OF THE HOUSE, WITH A BUDGET. YOUR DEPUTY TAKES THE BOARD."},
		"y3_partner": {"label": "BECOME A PARTNER", "desc": "FIVE PERCENT, YOUR NAME ON THE PAPERWORK AND YOUR SIGNATURE ON THE LINE OF CREDIT."},
		"y3_across": {"label": "TAKE THE JOB ACROSS TOWN", "desc": "TERRY VANCE'S OFFER: FORTY TECHS, A REAL BUDGET AND AN UNLABELLED PATCH PANEL."},
		"y3_director": {"label": "TAKE GARRISON'S CHAIR", "desc": "THE FORECAST, HIS CLIENT LIST AND WES. YOU STILL CLOSE, AND YOU ANSWER FOR HIS NUMBER TOO."},
		"y3_wes": {"label": "LET WES TAKE THE CHAIR", "desc": "WES RUNS THE TEAM. YOU KEEP THE BIG ACCOUNTS AND SKIP THE FORECAST MEETING."},
		"y3_stake": {"label": "TAKE A SHARE OF THE SALES SIDE", "desc": "NO TITLE. A PERCENTAGE OF EVERYTHING YOU SIGNED, FOR AS LONG AS IT STAYS SIGNED."},
	},
	"endings": {
		"y3_chair": "YOU TAKE DAN'S CHAIR. THE SCHEDULE IS YOURS, THE ESCALATIONS ARE YOURS, AND QUINN ANSWERS YOUR OLD PHONE ON THE SECOND RING. DAN LEFT A LABEL ON THE DRAWER. IT SAYS YOURS NOW.",
		"y3_senior": "SENIOR ENGINEER. NO SCHEDULE, NO BUDGET MEETING. THE TICKETS NOBODY ELSE CAN CLOSE COME TO YOU, AND SO DOES QUINN, ABOUT ONCE A DAY, WITH A NOTEBOOK. YOU FOUND THE JOB YOU WERE ALREADY DOING.",
		"y3_farewell": "YOU GIVE A MONTH OF NOTICE AND USE ALL OF IT. THE NOTES ARE WRITTEN, QUINN KNOWS ABOUT THE BLUE SWITCH, AND MORGAN SAYS THE DOOR OPENS BOTH WAYS. THE TEAM SIGNS A KEYBOARD. YOU TAKE THE MUG.",
		"y3_summit": "SUMMIT MANAGED HOLDINGS BUYS PIXEL IT PARTNERS FOR ABOUT ${value}. THE SIGN STAYS UP FOR A YEAR AND THE TEAM KEEPS THEIR DESKS. YOU SIGN FOR AN HOUR. THEN, FOR THE FIRST TIME IN THREE YEARS, YOUR PHONE IS SOMEBODY ELSE'S PROBLEM.",
		"y3_staff": "THE STAFF BUY THE COMPANY, A LITTLE EVERY MONTH FOR FIVE YEARS. CHRISTY RUNS THE NOTE TO THE PENNY. MORGAN GETS THE OFFICE WITH THE WINDOW. YOUR NAME COMES OFF THE DOOR SLOWLY, AND NOBODY HURRIES IT.",
		"y3_morgan": "YOU KEEP THE COMPANY AND GIVE MORGAN THE KEYS. SHE RUNS THE DAYS. YOU COME IN FOR THE NUMBERS, THE BIG CLIENTS AND THE COOKOUT. THE PHONES STILL RING. THEY JUST RING FOR HER FIRST.",
		"y3_coo": "YOU RUN OPERATIONS. THE DESK, THE WAREHOUSE AND THE BUDGET ALL REPORT TO ONE PERSON, AND THAT PERSON OWNS A LABEL MAKER. YOUR DEPUTY TAKES THE BOARD AND KEEPS YOUR COLOUR CODES.",
		"y3_partner": "YOU SIGN. FIVE PERCENT OF PIXEL IT PARTNERS, A THIRD SIGNATURE AT THE BANK AND A SEAT WHERE ALAN AND GARRISON ARGUE. YOU ARE THE TIE-BREAKER NOW. YOU LABEL YOUR SIDE OF THE TABLE.",
		"y3_across": "YOU TAKE THE JOB ACROSS TOWN AND LEAVE THE DESK BETTER THAN YOU FOUND IT. FORTY TECHS, ONE BUDGET, AND ON YOUR FIRST MORNING A PATCH PANEL WITH NOTHING WRITTEN ON IT. YOU BROUGHT YOUR OWN TAPE.",
		"y3_director": "GARRISON HANDS YOU THE CHAIR AND THE NAME PLATE HOLDER, EMPTY. THE FORECAST IS YOURS AND SO IS WES, WHO CLOSES HIS FIRST BIG ONE IN MARCH AND RINGS THE BELL TWICE. YOU LET HIM.",
		"y3_wes": "WES TAKES THE CHAIR. YOU TAUGHT HIM TO ASK WHAT HURTS FIRST, AND NOW HE ASKS YOU. YOU KEEP THE ACCOUNTS THAT MATTER AND NEVER SIT THROUGH A FORECAST MEETING AGAIN. HE STILL CALLS YOU BOSS.",
		"y3_stake": "NO TITLE, NO TEAM, AND A PERCENTAGE OF EVERY CONTRACT YOU SIGNED FOR AS LONG AS THE CLIENT STAYS. ALAN WROTE THE FORMULA. IT PAYS YOU TO KEEP YOUR PROMISES, WHICH WAS HIS WHOLE POINT.",
	},
}
var TEXT3: Dictionary = DEFAULT_TEXT3.duplicate(true)

var pending := false  # New Game Plus was chosen on the title menu: the next Campaign.new_game takes it
var _mut_tex := {}  # mutator id -> its icon or null (held here: an unheld texture is freed before the frame is drawn)
var pending_year := YEAR  # which year that is: 2, or 3 (START YEAR 3)
var pick := ""  # a mutator the plan must contain ("" = AUTO)
var ban := ""  # a mutator the plan must not contain
var mut_mode := "pick"  # what the character select chip does with the chosen mutator: "pick" or "ban"
var moves: Array = []  # the story shuffle: [{mode, key, from, to}]
var carried: Dictionary = {}  # what this run took over from the last one (shown on the intro card, saved)
var prev: Dictionary = {}  # the meta record of the finished run this one follows


func reset() -> void:
	moves = []
	carried = {}
	prev = {}
	RivalTouches.rival_year(1)


# ---- the tables of the running year ---------------------------------------------------------------------------
# Year 3 reads its own row where YEAR3 / TEXT3 has one and Year 2's otherwise; a Year 2 run only ever sees YEAR2 / TEXT
func year_cfg(key: String) -> Variant:
	if Campaign.year >= LAST_YEAR and YEAR3.has(key):
		return YEAR3[key]
	return YEAR2.get(key, {})


func year_txt(key: String) -> Variant:
	if Campaign.year >= LAST_YEAR and TEXT3.has(key):
		return TEXT3[key]
	return TEXT.get(key, {})


# "YEAR 2" / "YEAR 3" for the HUD, the day report and the character select; "" in a first year
func label(year := -1) -> String:
	var n := Campaign.year if year < 0 else year
	return "YEAR %d" % n if n >= YEAR else ""


# the " (YEAR 2)" mark of a save
func tag_of(year: int) -> String:
	return " (%s)" % label(year) if year >= YEAR else ""


# ---- the meta record (unlock) ---------------------------------------------------------------------------------
func meta_path() -> String:
	return Campaign.save_prefix + "meta.cfg"


func meta_get(mode: String) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(meta_path()) != OK or not file.has_section(mode):
		return {}
	var out := {}
	for key in file.get_section_keys(mode):
		out[key] = file.get_value(mode, key)
	return out


# finish_campaign calls this with the open meta file, after it wrote the ending id
func record(meta: ConfigFile, mode: String, ending: String) -> void:
	var done := int(meta.get_value(mode, "finished", 0)) + 1
	meta.set_value(mode, "finished", done)
	meta.set_value(mode, "ending", ending)
	meta.set_value(mode, "year", maxi(1, Campaign.year))
	meta.set_value(mode, "rep", Campaign.rep)
	meta.set_value(mode, "tier", Difficulty.tier)
	meta.set_value(mode, "cozy", Difficulty.cozy_on())  # R16: a cozy run is tagged; it still unlocks Year 2
	meta.set_value(mode, "seed", Difficulty.run_seed)
	meta.set_value(mode, "clients", Sales.active.size())
	var levels := {}
	for key in Skills.NAMES:
		levels[key] = Skills.level(str(key))
	meta.set_value(mode, "skills", levels)
	var books := Campaign.books_active()
	meta.set_value(mode, "value", Owner.valuation() if books else 0)
	meta.set_value(mode, "cash", Owner.cash if books else Campaign.cash)
	meta.set_value(mode, "trust", Partner.trust)
	meta.set_value(mode, "shop", Shop.owned.duplicate())
	meta.set_value(mode, "standard", RivalTouches.standard_now() if books else 0)  # R38: the Standard comes over at 60 percent
	if books:
		RivalTouches.note_year_end()
	if Campaign.year >= YEAR:
		Career.add("year2_done" if Campaign.year == YEAR else "year%d_done" % Campaign.year)
		# R10: the record of this year stays under its own key (the plain keys follow the LAST run, which may be a Year 1 again)
		var snap := {"flags": (Story.flags.get(_bucket(), {}) as Dictionary).duplicate(true)}
		for key in ["ending", "rep", "tier", "cozy", "seed", "clients", "skills", "value", "cash", "trust", "shop", "standard"]:
			snap[key] = meta.get_value(mode, key, null)
		meta.set_value(mode, "y%d" % Campaign.year, snap)
	meta.set_value(mode, "top_year", maxi(int(meta.get_value(mode, "top_year", 1)), maxi(1, Campaign.year)))


# can this mode start a Year 2? (the registry row allows it and a run of it has been finished)
# Year 3: a Year 2 run of it has been finished (an old meta file has no `top_year`: its `year` is the last finished run's)
func available(mode: String, year := YEAR) -> bool:
	if not Campaign.is_selectable(mode) or not bool(Campaign.prop("year2", false, mode)) or year > LAST_YEAR:
		return false
	var rec := meta_get(mode)
	if int(rec.get("finished", 1 if str(rec.get("ending", "")) != "" else 0)) <= 0:
		return false
	return year <= YEAR or int(rec.get("top_year", rec.get("year", 1))) >= year - 1


# the finished run a new `year` follows: the last run for Year 2 (as always), the Year 2 run for Year 3
func record_for(mode: String, year := YEAR) -> Dictionary:
	var rec := meta_get(mode)
	if year <= YEAR:
		return rec
	var snap: Variant = rec.get("y%d" % (year - 1), {})
	if snap is Dictionary and not (snap as Dictionary).is_empty():
		return snap
	return rec


# R17: what a START YEAR 2 (or 3) run keeps from the finished one, as one short line for the title menu row
func carry_summary(mode: String, year := YEAR) -> String:
	var rec := record_for(mode, year)
	if rec.is_empty():
		return ""
	var kept := carry_for(mode, rec)
	var parts := ["REP %d" % int(kept.rep)]
	if int(kept.cash) > 0:
		parts.append("$%d CASH" % int(kept.cash))
	if int(kept.trust) >= 0 and mode == "owner":
		parts.append("TRUST %d" % int(kept.trust))
	var levels := 0
	for key in kept.skills:
		levels += int(kept.skills[key])
	if levels > 0 or int(kept.ps) > 0:
		parts.append("SKILLS KEPT")
	return ", ".join(parts)


# the title menu rows of one year (one per mode that can start it); the title builds its own rows in Title.sub_items
func menu_items(year := YEAR) -> Array:
	var out := []
	for mode in Campaign.MODE_DEFS:
		if available(str(mode), year):
			out.append({"label": "NEW GAME PLUS - %s (YEAR %d)" % [str(mode).to_upper(), year], "id": "%s_y%d" % [str(mode), year], "enabled": true})
	return out


# the " - YEAR 2" mark of a saved run for the CONTINUE entries
func saved_tag(mode: String, for_slot := 0) -> String:
	var file := ConfigFile.new()
	if file.load(Campaign.save_path(mode, for_slot)) != OK:
		return ""
	return tag_of(int(file.get_value("campaign", "year", 1)))


# ---- choosing it on the character select ---------------------------------------------------------------------------
# the screen opens (setup): remember the choice; a normal run clears it
func begin_select(mode: String, year2: bool, year := YEAR) -> void:
	pending = year2 and available(mode, year)
	pending_year = clampi(year, YEAR, LAST_YEAR) if pending else YEAR
	pick = ""
	ban = ""
	mut_mode = "pick"


func take_pending(mode: String) -> bool:
	return take_year(mode) >= YEAR


# Campaign.new_game: the year of the run that starts now (1 unless START YEAR 2 / 3 was chosen), and what it follows
func take_year(mode: String) -> int:
	var year := pending_year if pending and available(mode, pending_year) else 1
	pending = false
	pending_year = YEAR
	prev = record_for(mode, year) if year >= YEAR else {}
	return year


func active() -> bool:
	return Campaign.active and Campaign.year >= YEAR


# the build step is open for a Year 2 run, or one is running
func build_bonus() -> int:
	return int(CARRY.build.points) if (pending or active()) else 0


# the ids the chip cycles through (AUTO first)
func mutator_ids(mode: String) -> Array:
	var out := [""]
	out.append_array(Mutators.ids_for(mode))
	return out


func change_mut(mode: String, step: int) -> void:
	var ids := mutator_ids(mode)
	var cur := pick if mut_mode == "pick" else ban
	var i := maxi(0, ids.find(cur))
	var next := str(ids[(i + step + ids.size()) % ids.size()])
	pick = next if mut_mode == "pick" else ""
	ban = next if mut_mode == "ban" else ""


func toggle_mut_mode() -> void:
	var cur := pick if mut_mode == "pick" else ban
	mut_mode = "ban" if mut_mode == "pick" else "pick"
	pick = cur if mut_mode == "pick" else ""
	ban = cur if mut_mode == "ban" else ""


# R9: the icon of the chosen mutator (assets/ui/mut_<id>.png, 12 x 12), null for AUTO or a missing file
func mut_icon() -> Texture2D:
	var id := pick if pick != "" else ban
	if not _mut_tex.has(id):
		var path := "res://assets/ui/mut_%s.png" % id
		_mut_tex[id] = load(path) if id != "" and ResourceLoader.exists(path) else null
	return _mut_tex[id]


func chip_text() -> String:
	var id := pick if pick != "" else ban
	if id == "":
		return "MUT  AUTO"
	var label := str(Mutators.MUTATORS.get(id, {}).get("name", id)).to_upper()
	if label.length() > 13:
		label = label.substr(0, 12) + "."
	return "%s %s" % ["PICK" if pick != "" else "BAN", label]


# ---- the numbers other scripts read ------------------------------------------------------------------------------
func sla_mult() -> float:
	return float((year_cfg("sla") as Dictionary).mult) if active() else 1.0


func ticket_weights() -> Dictionary:
	return YEAR2.tickets.weights if active() else {}


# a P2 ticket that becomes P1 (drawn from the year2 stream; never in Year 1)
func promote() -> bool:
	if not active():
		return false
	return Difficulty.rng("year2.p1").randf() < float(YEAR2.tickets.p1_promote)


func max_clients(base: int) -> int:
	return maxi(base, int(YEAR2.clients.max)) if active() else base


# Mutators.make_plan: the count range of the tier, one tier up in Year 2
func counts(tier: String, normal: Array) -> Array:
	if not active():
		return normal
	return YEAR2.mutators.counts.get(tier, normal)


func without_banned(ids: Array) -> Array:
	if not active() or ban == "" or pick != "":
		return ids
	var out := []
	for id in ids:
		if str(id) != ban:
			out.append(id)
	return out


# Mutators.start: the picked mutator is in the plan (it takes over one entry)
func apply_pick(plan: Array, mode: String) -> Array:
	if not active() or pick == "" or not Mutators.MUTATORS.has(pick):
		return plan
	for e in plan:
		if str(e.id) == pick:
			return plan
	var slots: Array = Mutators.slots_for(mode)
	if plan.is_empty():
		plan.append({"id": pick, "from": int(slots[0]), "to": int(slots[0])})
		return plan
	var r := Difficulty.rng("year2")
	var at := r.randi_range(0, plan.size() - 1)
	var e: Dictionary = plan[at]
	var next_from := 9999
	if at + 1 < plan.size():
		next_from = int(plan[at + 1].from)
	var to := int(e.from)
	while to - int(e.from) + 1 < Mutators.duration_of(pick, mode) and slots.has(to + 1) and to + 1 < next_from:
		to += 1
	plan[at] = {"id": pick, "from": int(e.from), "to": to}
	return plan


# ---- carrying over ---------------------------------------------------------------------------------------------
# the rules applied to a meta record: pure, so tests can feed it any record
func carry_for(_mode: String, rec: Dictionary) -> Dictionary:
	var out := {"rep": Campaign.START_REP, "skills": {}, "ps": 0, "cash": 0, "trust": -1}
	if rec.is_empty():
		return out
	var rep_row: Dictionary = CARRY.rep
	out["rep"] = clampi(roundi(float(rec.get("rep", Campaign.START_REP)) * float(rep_row.fraction)), int(rep_row.min), int(rep_row.max))
	var sk_row: Dictionary = CARRY.skills
	var saved: Dictionary = rec.get("skills", {}) if rec.get("skills", {}) is Dictionary else {}
	for key in Skills.NAMES:
		if str(key) == "powershell":
			continue
		out.skills[key] = clampi(int(saved.get(key, 0)) + int(sk_row.offset), 0, int(sk_row.cap))
	var ps_row: Dictionary = CARRY.powershell
	out["ps"] = clampi(int(saved.get("powershell", 0)) + int(ps_row.offset), 0, int(ps_row.cap))
	var cash_row: Dictionary = CARRY.cash
	out["cash"] = clampi(roundi(float(rec.get("value", 0)) * float(cash_row.fraction)), 0, int(cash_row.cap))
	var trust_row: Dictionary = CARRY.trust
	out["trust"] = clampi(int(rec.get("trust", 55)), int(trust_row.min), int(trust_row.max))
	return out


# Campaign.new_game, after the usual start (build, starting condition): the carry-over, the clients, the shuffle
func begin_run(mode: String) -> void:
	if not active():
		return
	carried = carry_for(mode, prev)
	Campaign.rep = int(carried.rep)
	Shop.restore(prev.get("shop", []))
	if not Campaign.books_active():
		for key in carried.skills:
			var lv := int(carried.skills[key])
			if lv > Skills.level(str(key)):
				Skills.xp[key] = Skills.need(lv - 1)
		Skills.ps_level = maxi(Skills.ps_level, int(carried.ps))
	else:
		Owner.cash += int(carried.cash)
		Partner.trust = clampi(int(carried.trust) + Build.trust_bonus(), 0, 100)
		RivalTouches.rival_year(Campaign.year)
		carried["habits"] = RivalTouches.year2_begin(prev)
	for cname in YEAR2.clients.client:
		var idx := client_index(str(cname))
		if idx >= 0 and not Sales.active.has(idx):
			Sales.active.append(idx)
	moves = story_shuffle(mode)
	Career.add("year2_runs" if Campaign.year == YEAR else "year%d_runs" % Campaign.year)


func client_index(cname: String) -> int:
	for i in Msp.CLIENTS.size():
		if str(Msp.CLIENTS[i].name) == cname:
			return i
	return -1


func intro_text() -> String:
	var intro: Dictionary = year_txt("intro")
	var parts: Array = [str(intro.text)]
	if Campaign.year >= LAST_YEAR and (YEAR3.left as Array).has(str(prev.get("ending", ""))) and intro.has("back"):
		parts.append(str(intro.back))
	for key in ["sla", "tickets", "clients", "mutators", "shuffle"]:
		parts.append(str((year_cfg(key) as Dictionary).text))
	if not carried.is_empty():
		var s := "YOU CARRY OVER: REPUTATION %d" % int(carried.rep)
		if Campaign.books_active():
			s += ", $%d START CASH, PARTNER TRUST %d" % [int(carried.cash), Partner.trust]
		else:
			var bits := []
			for key in carried.skills:
				if int(carried.skills[key]) > 0:
					bits.append("%s %d" % [str(Skills.NAMES[key]), int(carried.skills[key])])
			if int(carried.ps) > 0:
				bits.append("POWERSHELL %d" % int(carried.ps))
			if not bits.is_empty():
				s += ", " + ", ".join(bits)
		parts.append(s + ".")
		if Campaign.books_active() and not (carried.get("habits", []) as Array).is_empty():
			parts.append(str(TEXT.habits.carry))
			parts.append(str(TEXT.habits.rival_note))
	return " ".join(parts)


# ---- the story shuffle -----------------------------------------------------------------------------------------
# the day table of a mode (the scripted beats): the tech story or the owner weeks
func _base(mode: String) -> Dictionary:
	return Story.DAYS if mode == "tech" else (Owner.DAYS if mode == "owner" else {})


func _key(ev: Dictionary) -> String:
	var kind := str(ev.get("kind", ""))
	if kind == "playbook":
		return "book:" + str(ev.get("book", ""))
	if kind == "vignette":
		return "vig:" + str(ev.get("id", ""))
	if ev.has("kind"):
		return "kind:" + kind
	if ev.has("event") and not ev.has("card"):
		return "ev:" + str(ev.event)
	return ""


# the events of one day with the moves applied (the day tables are never edited)
func events_on(mode: String, day: int, base: Dictionary) -> Array:
	var list: Array = base.get(day, [])
	if moves.is_empty():
		return list
	var out := []
	for ev in list:
		var gone := false
		for m in moves:
			if str(m.mode) == mode and int(m.from) == day and str(m.key) == _key(ev):
				gone = true
				break
		if not gone:
			out.append(ev)
	for m in moves:
		if str(m.mode) == mode and int(m.to) == day:
			for ev in base.get(int(m.from), []):
				if _key(ev) == str(m.key):
					out.append(ev)
					break
	return out


# the days a moved beat may not land on
func blocked_days(mode: String) -> Dictionary:
	var out := {}
	var base := _base(mode)
	var cfg: Dictionary = YEAR2.shuffle.get(mode, {})
	var fixed: Array = cfg.get("fixed", [])
	for day in base:
		for ev in base[day]:
			var key := _key(ev)
			for f in fixed:
				if key.ends_with(":" + str(f)):
					out[int(day)] = true
	var outings: Array = Outings.OWNER_WEEKS if mode == "owner" else Outings.TECH_DAYS
	for d in outings:
		out[int(d)] = true
	if mode == "tech":
		out[Expo.TRIP_DAY] = true
	var beats: Dictionary = (year_cfg("beats") as Dictionary).get(mode, {})
	for id in beats:
		out[int(beats[id])] = true
	for e in Mutators.plan:
		for d in range(int(e.from), int(e.to) + 1):
			out[d] = true
	return out


# the beats that may move, as groups (a linked vignette follows its job): [{members: [{key, kind, from}]}]
func _groups(mode: String, base: Dictionary, cfg: Dictionary) -> Array:
	var movable: Array = []
	if mode == "tech":
		for b in cfg.get("books", []):
			movable.append("book:" + str(b))
		for v in cfg.get("vignettes", []):
			movable.append("vig:" + str(v))
	else:
		for e in cfg.get("events", []):
			movable.append("ev:" + str(e))
	var linked: Dictionary = cfg.get("linked", {})
	var days: Array = base.keys()
	days.sort()
	var out := []
	for key in movable:
		for day in days:
			for ev in base[day]:
				if _key(ev) != key:
					continue
				var members := [{"key": key, "from": int(day)}]
				for v in linked:
					if str(linked[v]) == key.substr(5):
						for d2 in days:
							for ev2 in base[d2]:
								if _key(ev2) == "vig:" + str(v):
									members.append({"key": "vig:" + str(v), "from": int(d2)})
				out.append({"members": members})
	return out


func _kind_of(key: String) -> String:
	return key.split(":")[0]


# one day's load: how many playbooks, vignettes and which keys are there after the moves so far
func _load(_mode: String, base: Dictionary, placed: Array, day: int) -> Dictionary:
	var out := {"books": 0, "vigs": 0, "n": 0, "keys": {}}
	var moved_away := []
	for p in placed:
		if int(p.from) == day:
			moved_away.append(str(p.key))
	for ev in base.get(day, []):
		var key := _key(ev)
		if moved_away.has(key):
			continue
		_count(out, key)
	for p in placed:
		if int(p.to) == day:
			_count(out, str(p.key))
	return out


func _count(loaded: Dictionary, key: String) -> void:
	loaded.n += 1
	loaded.keys[key] = true
	if key.begins_with("book:"):
		loaded.books += 1
	elif key.begins_with("vig:"):
		loaded.vigs += 1


# Where can the beats of a group go? Deterministic for a seed (Difficulty.rng("year2")), by at most `max_shift`
# days, never onto an outing day, the trip day, the overtime night, the ransomware or install day, a Year 2 beat
# day, a day inside the mutator plan, a day that already has a playbook (for a playbook) or a vignette (for a vignette).
func story_shuffle(mode: String, rng: RandomNumberGenerator = null) -> Array:
	var cfg: Dictionary = YEAR2.shuffle.get(mode, {})
	if cfg.is_empty():
		return []
	var r: RandomNumberGenerator = rng if rng != null else Difficulty.rng("year2")
	var base := _base(mode)
	var span := int(YEAR2.shuffle.max_shift)
	var lo := int(cfg.get("min_day", 3))
	var hi := Campaign.total_days() - 1
	var blocked := blocked_days(mode)
	var placed: Array = []  # the moves made so far
	var order: Array = _groups(mode, base, cfg)
	Difficulty.shuffle_with(order, r)  # who gets the free days first changes with the seed
	for g in order:
		var deltas: Array = []
		for d in range(-span, span + 1):
			if d != 0:
				deltas.append(d)
		Difficulty.shuffle_with(deltas, r)
		deltas.append(0)
		for d in deltas:
			if d == 0:
				break
			var ok := true
			var trial: Array = placed.duplicate()
			for m in g.members:
				var t := int(m.from) + int(d)
				var loaded := _load(mode, base, trial, t)
				var kind := _kind_of(str(m.key))
				if t < mini(lo, int(m.from)) or t > hi or blocked.has(t):
					ok = false
				elif kind == "book" and int(loaded.books) > 0:
					ok = false
				elif kind == "vig" and int(loaded.vigs) > 0:
					ok = false
				elif kind == "ev" and (loaded.keys.has(str(m.key)) or int(loaded.n) >= 4):
					ok = false
				if not ok:
					break
				trial.append({"key": str(m.key), "from": int(m.from), "to": t})
			if ok:
				placed = trial
				break
	var out := []
	for p in placed:
		out.append({"mode": mode, "key": str(p.key), "from": int(p.from), "to": int(p.to)})
	return out


# ---- the Year 2 beats (cards that set flags) ----------------------------------------------------------------------
# the choices of this year's beats live in Story.flags under "y2" (Year 2) or "y3" (Year 3), saved with the campaign
func _bucket() -> String:
	return "y%d" % clampi(Campaign.year, YEAR, LAST_YEAR)


func flag(key: String) -> String:
	var f: Dictionary = Story.flags.get(_bucket(), {})
	return str(f.get(key, ""))


func set_flag(key: String, value: String) -> void:
	var f: Dictionary = Story.flags.get(_bucket(), {})
	f[key] = value
	Story.flags[_bucket()] = f


# what you answered at a beat of the Year 2 run this one follows ("" in Year 2, or when that run is older than the record)
func last_flag(key: String) -> String:
	var f: Variant = prev.get("flags", {})
	return str((f as Dictionary).get(key, "")) if f is Dictionary else ""


# Campaign._begin_day
func begin_day(day: int) -> void:
	if not active() or Game.title_mode:
		return
	if day == 1:
		Cards.ask(str((year_txt("intro") as Dictionary).speaker), intro_text(), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	var beats: Dictionary = (year_cfg("beats") as Dictionary).get(Campaign.mode, {})
	for id in beats:
		if int(beats[id]) == day:
			beat(str(id))


# the card of a beat of the running year
func beat_row(id: String) -> Dictionary:
	return (year_txt("beats") as Dictionary).get(Campaign.mode, {}).get(id, {})


func beat(id: String) -> void:
	var row: Dictionary = beat_row(id)
	if row.is_empty():
		return
	if Campaign.mode == "tech" and Campaign.year >= 3 and (id == "newhire" or id == "mentor") and World.chars.has("Quinn"):
		World.force_activity("Quinn", "floor")  # Quinn is on the main floor for her two beats
	if row.has("lynk"):  # a Lynk line first: who is about to walk over, and why
		Lync._push(str(row.lynk.from), str(row.lynk.from), str(row.lynk.text))
	var options := []
	for o in row.options:
		var enabled := true
		if o.has("need") and Campaign.books_active():
			enabled = Owner.cash >= int(o.need)
		options.append({"label": str(o.label), "id": str(o.id), "enabled": enabled})
	Cards.ask(str(row.speaker), str(row.text), options, func(oid: String) -> void: answer(id, oid))


func answer(id: String, oid: String) -> void:
	var row: Dictionary = beat_row(id)
	for o in row.get("options", []):
		if str(o.id) != oid:
			continue
		set_flag(id, oid)
		var fx: Dictionary = o.get("fx", {})
		if not fx.is_empty():
			Events.apply_fx(fx)
		Cards.ask(str(row.speaker), str(o.reply), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


# ---- the Year 2 endings -----------------------------------------------------------------------------------------
func _offer_ok(id: String) -> bool:
	match id:
		"head":
			var need := 60 if str(prev.get("ending", "")) == "lead" else 65
			return flag("desk") == "run" and Campaign.rep >= need and Social.average() >= 0.0
		"clientbuy":
			return (flag("courted") == "listen" or flag("courted") == "told") and Campaign.rep >= 50
		"merger":
			return flag("merger") == "talks" and Campaign.rep >= 55 and Sales.active.size() >= 6 and Owner.cash >= 0
		"franchise":
			return flag("franchise") == "pilot" and Campaign.rep >= 60 and Sales.active.size() >= 6 and Owner.oml() >= 2
	return _offer3_ok(id)


# an ending's threshold (YEAR3.needs, patchable)
func need(id: String, key: String, fallback := 0) -> int:
	return int(((YEAR3.needs as Dictionary).get(id, {}) as Dictionary).get(key, fallback))


# The Year 3 endings: the last beat of each campaign asks what you want, the earlier two decide whether you have earned it.
#   tech     the chair needs somebody trained to take your desk; leaving on good terms needs the team to like you
#   owner    Summit needs the door left open, the staff sale and Morgan's keys need the yes you gave them
#   service  operations and the stake are the owners' question; the job across town needs a desk that survives you
#   sales    Garrison's chair needs a fair line and a rep you did not starve; Wes only gets it if you taught him
func _offer3_ok(id: String) -> bool:
	if Campaign.year < LAST_YEAR or Campaign.rep < need(id, "rep"):
		return false
	var ok := false
	match id:
		"y3_chair":
			ok = flag("fork") == "chair" and (flag("newhire") != "no" or flag("mentor") == "teach") and Social.average() >= 0.0
		"y3_senior":
			ok = flag("fork") == "tech"
		"y3_farewell":
			ok = flag("fork") == "go" and Social.average() >= 0.0
		"y3_summit":
			ok = flag("summit") in ["books", "listen"] and Sales.active.size() >= need(id, "clients") and Owner.cash >= 0
		"y3_staff":
			ok = flag("staff") == "yes" and Owner.cash >= 0
		"y3_morgan":
			ok = flag("handover") == "trial" and Owner.cash >= 0
		"y3_coo":
			ok = flag("table") == "ops"
		"y3_partner":
			ok = flag("table") == "partner" and mini(Service.trust_of("Alan"), Service.trust_of("Garrison")) >= need(id, "trust")
		"y3_across":
			ok = flag("terry") == "hear" and flag("deputy") != "no"
		"y3_director":
			ok = flag("chair") == "chair" and flag("split") != "cold" and flag("wes") != "take"
		"y3_wes":
			ok = flag("chair") == "wes" and flag("wes") == "coach"
		"y3_stake":
			ok = flag("chair") == "stake"
	return ok


func _fill(text: String) -> String:
	var value := "0"
	if Campaign.books_active():
		value = str(int(Owner.valuation() * 11 / 10))
	return text.replace("${value}", "$" + value).replace("{value}", value)


# the offers of the review, with the Year 2 endings the flags unlock slotted in before STAY
func extra_offers(out: Array) -> Array:
	if not active():
		return out
	var add := []
	for id in (year_cfg("endings") as Dictionary).get(Campaign.mode, []):
		if _offer_ok(str(id)):
			var row: Dictionary = (year_txt("offers") as Dictionary).get(str(id), {})
			add.append({"id": str(id), "label": _fill(str(row.get("label", id))), "desc": _fill(str(row.get("desc", "")))})
	if add.is_empty():
		return out
	var at := -1
	for i in out.size():
		if str(out[i].id) in ["stay", "left"]:
			at = i
			break
	if at < 0:
		return out  # nobody asked you to stay (let go, or notice already given): no promotion either
	var merged: Array = out.slice(0, at)
	merged.append_array(add)
	merged.append_array(out.slice(at))
	return merged


func ending_text(id: String) -> String:
	return _fill(str(TEXT.endings.get(id, TEXT3.endings.get(id, ""))))


# an ending this file owns (Year 2's or Year 3's); the reviews ask it for the epilogue
func is_year2_ending(id: String) -> bool:
	return TEXT.endings.has(id) or TEXT3.endings.has(id)


func is_year3_ending(id: String) -> bool:
	return TEXT3.endings.has(id)


# ---- saving ---------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"version": VERSION, "moves": moves.duplicate(true), "carried": carried.duplicate(true), "pick": pick, "ban": ban, "prev": prev.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("moves", [])
	if saved is Array:
		for m in saved:
			if m is Dictionary and m.has("key"):
				moves.append({"mode": str(m.get("mode", "tech")), "key": str(m.key), "from": int(m.get("from", 0)), "to": int(m.get("to", 0))})
	carried = data.get("carried", {}) if data.get("carried", {}) is Dictionary else {}
	prev = data.get("prev", {}) if data.get("prev", {}) is Dictionary else {}
	pick = str(data.get("pick", ""))
	ban = str(data.get("ban", ""))
	RivalTouches.rival_year(Campaign.year)  # a saved Year 2 run keeps the new rival name
