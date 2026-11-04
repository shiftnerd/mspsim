extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# RODENT NATION 2014: LabRat's yearly user conference (a parody of the real RMM vendor's June 2014 event).
# Tech campaign: Morgan announces on day 8 that the people who hit their KPIs get sent; day 12 is a progress note,
# day 16 the verdict, day 17 the trip itself (the office is frozen, you pick a session in each of three rounds, take in the
# keynote and the vendor hall, and enter the raffle). Missed the KPIs and Dan goes instead and brings back one tip.
# The story text lives in TEXT and ROUNDS so reviewers can edit it in story/strings.txt.

const INVITE_DAY := 8
const PROGRESS_DAY := 12
const VERDICT_DAY := 16
const TRIP_DAY := 17
const CLOCKS := [10.0, 13.0, 15.0]
const DOORS := ["from_a", "from_b", "from_c", "from_d"]
const NEED := 3  # how many of the four KPIs must be met
const MORGAN := "Morgan Reyes - Manager"
const Trip := preload("res://scripts/trip_variety.gd")
const DEFAULT_TEXT := {
	"invite_subject": "Rodent Nation 2014: top performers go",
	"invite_body":
	"LabRat's yearly user conference, RODENT NATION, is in Orlando this June. The company pays for one tech: whoever hits the KPIs by day 16. Reputation 55 or more, SLA misses under 20 percent of closes, reopens under 15 percent of closes, and PowerShell level 2. Hit three of the four and you go. - Morgan",
	"progress": "KPI check before the Rodent Nation trip: %s. Three of four wins the ticket.",
	"yes_subject": "Pack your bags: Rodent Nation",
	"yes_body":
	"You hit the KPIs (%s). You fly out tomorrow for a day of sessions: labs, panels, the vendor hall and the keynote. Dan will cover your queue. Come back smarter. - Morgan",
	"no_subject": "Rodent Nation: not this year",
	"no_body":
	"You did not quite make the KPIs (%s), so Dan is going to Rodent Nation this year. He will bring back notes. Aim for it next year. - Morgan",
	"arrive":
	"RODENT NATION 2014. Orlando, a resort the size of a small town: palm trees in the lobby, carpet with swirls, a ballroom that fits a thousand MSP nerds, and breakout rooms down every hallway. Your badge says TECH and has a little rat on it.",
	"keynote":
	"The LabRat CEO takes the stage in the ballroom under a sign that says AUTOMATE EVERYTHING. Eleven hundred people applaud a slide about a dashboard. Meanwhile your phone buzzes: the queue back home is not empty.",
	"keynote_listen":
	"You put the phone away and listen. The CEO says the future is scripts, monitoring and fewer truck rolls. You take notes. (+3 customer XP)",
	"keynote_peek":
	"You check the queue under the table. Dan has it, but you leave a few notes. It costs you half the keynote.",
	"hall":
	"The solutions pavilion: a long row of booths, free pens, a man in a rat costume, and every vendor wants a scan of your badge.",
	"hall_swag":
	"You collect a bag of pens, stress balls and a USB drive nobody will ever plug in. Alan will want a pen. (coworkers like you a little more)",
	"hall_nerds":
	"You find the LabRat Nerds forum regulars at the community table. Real faces behind the nicknames. (+4 forum karma)",
	"hall_vendor":
	"A backup vendor walks you through a disaster recovery demo that actually works. You take the brochure. (+6 security XP)",
	"raffle_win":
	"They call your badge number: you won the Rock Star Upgrade! A new laptop bag, a hotel suite night and a dinner for two. You sleep like a baby. (energy full, +3 reputation)",
	"raffle_lose":
	"Not your number. A man from Tulsa wins the Rock Star Upgrade and cries. Oh well.",
	"wrap":
	"The last session lets out. You fly home with a tote bag, a head full of ideas and a lanyard you will keep. Tomorrow the queue will want to hear about it.",
	"dan_back":
	"Dan is back from Rodent Nation with a tote bag and one thing he swears will change your life: always label the patch panel. (+6 networking XP)",
	"home_pile": "While you were away tickets piled up. Dan did what he could.",
	"home_ok": "You checked in during the keynote, so the pile is small. Dan says thanks.",
	"report": "RODENT NATION TRIP",
	"checkin":
	"Welcome to Rodent Nation! Here is your badge, a lanyard, the agenda and a tote bag full of flyers. The ballroom opens at nine. The vendor hall is open all day.",
	"checkin_again": "You already have your badge, hon. Keynote is in the ballroom, left door.",
	"usher": "Badge, please. No badge, no keynote. Registration is back in the lobby.",
	"greet_lurker": "(Nobody here has ever seen your name on the forum.)",
	"greet_member": "(They know your name from the forum.)",
	"greet_regular": "(Oh, you are THE regular from the forum! They are thrilled.)",
	"greet_guru": "(A forum guru in person! People stare at your badge.)",
	"boss_morgan":
	"Thanks for being on time. Remember: ask users to save before you reboot, and verify the backups every morning.",
	"boss_marge":
	"I have the weekly numbers ready for after the meeting. Cash is tight, but we are okay.",
	"chat_again": "You already chatted. They nod and go back to their coffee.",
	"vendor_again": "Back again? Here, take another pen. Let me know if you change your mind.",
	"spam_note":
	"Your inbox fills with follow-ups from the vendors whose booths you gave your badge to.",
	"to_ballroom": "The keynote starts at 9:00 in the BALLROOM. Left door in the lobby.",
	"to_hall":
	"Breakout sessions are down the HALL (right door). Each door is a different session, check the easels. The EXPO HALL is always open too.",
	"to_booth":
	"The vendor hall is always open: the EXPO HALL door in the lobby. Walk into a booth to see what they have.",
	"to_raffle": "The closing raffle is in the BALLROOM. Do not miss it.",
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)
const DEFAULT_ROUNDS := [
	{
		"title": "ROUND 1: TUESDAY MORNING",
		"intro": "The agenda has seven tracks at the same time. Pick one session.",
		"sessions":
		[
			{
				"id": "ps101",
				"short": "SCRIPTING 101 LAB",
				"label": "SCRIPTING 101 LAB",
				"skill": "powershell",
				"xp": 0,
				"text":
				"A hands-on lab where you write your first real LabRat script. The instructor walks the room. Everything clicks. (+1 PowerShell level)"
			},
			{
				"id": "monitor",
				"short": "MONITOR BEST PRACTICE",
				"label": "MONITORING BEST PRACTICES",
				"skill": "networking",
				"xp": 8,
				"text":
				"How to alert on what matters and stop drowning in noise: set thresholds, skip the disk-space-at-79-percent emails. (+8 networking XP)"
			},
			{
				"id": "patch",
				"short": "PATCH MGMT BEST PRACTICE",
				"label": "PATCH MANAGEMENT BEST PRACTICES",
				"skill": "servers",
				"xp": 8,
				"text":
				"Patch Tuesday, approvals, maintenance windows and rollback plans. You leave with a checklist. (+8 servers XP)"
			},
			{
				"id": "oml",
				"short": "SERVICE DESK MATURITY",
				"label": "YOUR SERVICE DESK MATURITY LEVEL",
				"skill": "people",
				"xp": 8,
				"text":
				"A consultant shows where service desks usually stall: no process, no metrics, no follow-up. You finally have words for what Morgan keeps asking for. (+8 customer XP)"
			},
		],
	},
	{
		"title": "ROUND 2: TUESDAY AFTERNOON",
		"intro": "Lunch was a rubber chicken. Pick the afternoon session.",
		"sessions":
		[
			{
				"id": "ps201",
				"short": "SCRIPTING 201 LAB",
				"label": "SCRIPTING 201 LAB",
				"skill": "servers",
				"xp": 8,
				"text":
				"Loops, variables and a script that restarts services across a whole client. Hard but useful. (+8 servers XP)"
			},
			{
				"id": "security",
				"short": "SECURITY FOR MODERN THREATS",
				"label": "RETHINKING SECURITY FOR MODERN THREATS",
				"skill": "security",
				"xp": 8,
				"text":
				"Antivirus alone is not enough anymore. Layers, patching, backups and training users. (+8 security XP)"
			},
			{
				"id": "bdr",
				"short": "MONEY MAKING BDR",
				"label": "ROLL YOUR OWN MONEY-MAKING BDR",
				"skill": "security",
				"xp": 6,
				"text":
				"A master MSP shows how a good backup and disaster recovery service pays for itself, and how to test restores. (+6 security XP)"
			},
			{
				"id": "panel",
				"short": "BIGGEST MISTAKE PANEL",
				"label": "PARTNER PANEL: MY BIGGEST MISTAKE",
				"skill": "people",
				"xp": 8,
				"text":
				"Five owners confess their worst outages. The common thread: no backups, no documentation and no one checking. (+8 customer XP)"
			},
		],
	},
	{
		"title": "ROUND 3: WEDNESDAY MORNING",
		"intro": "The last round before the flight. Pick one.",
		"sessions":
		[
			{
				"id": "hipaa",
				"short": "HIPAA FOR MSPS",
				"label": "THE HIPAA QUESTIONS EVERY MSP SHOULD ASK",
				"skill": "security",
				"xp": 8,
				"text":
				"Dental offices and doctors have rules about their data. You now know what to ask Acme Dental. (+8 security XP, Acme Dental trusts you more)"
			},
			{
				"id": "managed",
				"short": "BREAK FIX TO MANAGED",
				"label": "CONVERTING CLIENTS FROM BREAK/FIX TO MANAGED",
				"skill": "people",
				"xp": 8,
				"text":
				"How to explain monthly service to an owner who only calls when it is broken. (+8 customer XP)"
			},
			{
				"id": "hood",
				"short": "UNDER THE HOOD",
				"label": "UNDER THE HOOD: ADVANCED CONCEPTS",
				"skill": "servers",
				"xp": 8,
				"text":
				"Database tables, agent logs and a few things the vendor admits they do not document. (+8 servers XP)"
			},
			{
				"id": "stay",
				"short": "WHY I STAY PANEL",
				"label": "PARTNER PANEL: WHY I STAY (A TECH PERSPECTIVE)",
				"skill": "people",
				"xp": 8,
				"text":
				"Four techs from other MSPs say why they stayed: training budgets, a boss who answers the phone, and a real path to Tier 2. You think about Morgan. (+8 customer XP)"
			},
		],
	},
]
var ROUNDS: Array = DEFAULT_ROUNDS.duplicate(true)

const DEFAULT_VENDORS := [
	{
		"id": "backup",
		"speaker": "Brad (ShadowPoint Backup)",
		"text":
		"Friend! Do your clients have a real backup, or just a USB drive in a drawer? ShadowPoint does image-based backup with instant virtualization. Forty percent off if you sign up this week!",
		"options":
		[
			{
				"id": "demo",
				"label": "SIT THROUGH THE DEMO",
				"text":
				"Brad boots a dead server as a virtual machine in four minutes. You are actually impressed. (+6 security XP)"
			},
			{
				"id": "price",
				"label": "ASK ABOUT PRICING",
				"text":
				"Per server, per month, plus storage, plus a setup fee that is somehow not in the brochure. You write it all down. (+3 customer XP)"
			},
			{
				"id": "scan",
				"label": "SCAN MY BADGE FOR THE PRIZE",
				"text":
				"Beep. You are entered to win a tablet. Brad's smile gets a little wider. (raffle entry, expect emails)"
			},
			{
				"id": "no",
				"label": "NO THANKS, JUST LOOKING",
				"text": "Brad hands you a pen anyway and says he will be around all week."
			},
		],
		"mail":
		{
			"from": "Brad Kowalski <brad@shadowpoint.example>",
			"subject": "Great meeting you at Rodent Nation!!!",
			"body":
			"Hi, it was great talking at the show! I wanted to follow up on that 40 percent offer. It expires FRIDAY. Can we do a quick 15 minute call? - Brad"
		},
	},
	{
		"id": "webwoot",
		"speaker": "Dee (WebWoot Security)",
		"text":
		"Quick question: are your clients protected from CryptoLocker? Because the other guys are not! Our cloud antivirus catches threats before they exist!",
		"options":
		[
			{
				"id": "demo",
				"label": "WATCH THE THREAT MAP",
				"text":
				"A glowing map of the world with red dots everywhere. Dee says each dot is somebody who did not buy WebWoot. It is mostly marketing, but you learn a few real terms. (+6 security XP)"
			},
			{
				"id": "price",
				"label": "ASK HOW IT WORKS UNDER THE HOOD",
				"text":
				"Dee has to fetch an engineer. He explains how definitions and heuristics differ and which clients benefit. Useful. (+3 servers XP)"
			},
			{
				"id": "scan",
				"label": "SCAN MY BADGE FOR THE T-SHIRT",
				"text":
				"Beep. A free t-shirt and a lifetime of email. (raffle entry, expect emails)"
			},
			{
				"id": "no",
				"label": "WE ALREADY HAVE ANTIVIRUS",
				"text": "Dee says everyone says that, until they do not. She gives you a sticker."
			},
		],
		"mail":
		{
			"from": "Dee Kessler <dee@webwoot.example>",
			"subject": "Is your client protected? (reminder)",
			"body":
			"Hi! Following up from Rodent Nation. Did you know ransomware is way up this year? Let us show you a 30 day trial. Reply YES for a free assessment. - Dee"
		},
	},
	{
		"id": "psa",
		"speaker": "Rex (SoftSwipe PSA)",
		"text":
		"Still using ConnectWhy? I can hear it from here. SoftSwipe PSA: one pane of glass, tickets, billing, projects, even a CRM! Switch this quarter and we migrate your data FREE.",
		"options":
		[
			{
				"id": "demo",
				"label": "SEE THE DASHBOARD",
				"text":
				"A very busy dashboard with a very small font. The billing screen is genuinely good. (+6 customer XP)"
			},
			{
				"id": "price",
				"label": "ASK ABOUT MIGRATION",
				"text":
				"Rex goes quiet. Then he admits data migration is 'a partnership'. You note which fields are not imported. (+3 networking XP)"
			},
			{
				"id": "scan",
				"label": "SCAN MY BADGE FOR THE DRAWING",
				"text":
				"Beep. A chance at a game console and a follow-up call from Rex. (raffle entry, expect emails)"
			},
			{
				"id": "no",
				"label": "WE ARE HAPPY WITH WHAT WE HAVE",
				"text":
				"Rex hands you a stress ball shaped like a ticket and says he will check back in a month."
			},
		],
		"mail":
		{
			"from": "Rex Dalton <rex@softswipe.example>",
			"subject": "Following up: SoftSwipe PSA demo?",
			"body":
			"Hi! I saw you stopped by the booth. I would love to give you a personal demo of SoftSwipe PSA. Are you the decision maker? - Rex"
		},
	},
]
var VENDORS: Array = DEFAULT_VENDORS.duplicate(true)
const DEFAULT_CHATS := [
	{
		"speaker": "rodent_rick (Dave, small MSP, Ohio)",
		"text":
		"Six techs, forty clients. We dropped per-incident billing last year. Flat monthly or nothing. Best decision we ever made.",
		"options":
		[
			{
				"id": "learn",
				"label": "ASK HOW HE SOLD IT",
				"skill": "people",
				"xp": 4,
				"text":
				"He says: stop calling it a price increase and call it predictable IT. And never discount the first year. (+4 customer XP)"
			},
			{
				"id": "cards",
				"label": "SWAP BUSINESS CARDS",
				"skill": "",
				"xp": 0,
				"text": "You swap cards. His has a cartoon dog on it."
			},
			{
				"id": "bye",
				"label": "NICE TO MEET YOU",
				"skill": "",
				"xp": 0,
				"text": "He tells you to look him up in the forum."
			},
		],
	},
	{
		"speaker": "gnawer (Priya, in-house IT)",
		"text":
		"Forty Windows XP machines to go and support already ended in April. My boss thinks we can just leave them. Do you do XP migrations?",
		"options":
		[
			{
				"id": "learn",
				"label": "SHARE YOUR MIGRATION PLAN",
				"skill": "networking",
				"xp": 4,
				"text":
				"You compare notes: image first, move the data, check the printers. She writes it on her badge. (+4 networking XP)"
			},
			{
				"id": "cards",
				"label": "SWAP BUSINESS CARDS",
				"skill": "",
				"xp": 0,
				"text": "She promises to send you the checklist she is building."
			},
			{
				"id": "bye",
				"label": "GOOD LUCK WITH THAT",
				"skill": "",
				"xp": 0,
				"text": "She groans and laughs."
			},
		],
	},
	{
		"speaker": "PS_wizard (Gary, script guy)",
		"text":
		"I scripted our whole new-client onboarding in PowerShell. A weekend of work, saves me five hours a week. I will show anyone who asks.",
		"options":
		[
			{
				"id": "learn",
				"label": "ASK TO SEE IT",
				"skill": "servers",
				"xp": 4,
				"text":
				"He walks you through loops and a function you can steal. You take screenshots with your phone. (+4 servers XP)"
			},
			{
				"id": "cards",
				"label": "SWAP BUSINESS CARDS",
				"skill": "",
				"xp": 0,
				"text": "His card says SCRIPT WIZARD, which he printed himself."
			},
			{
				"id": "bye",
				"label": "MAYBE LATER",
				"skill": "",
				"xp": 0,
				"text": "He looks a little disappointed."
			},
		],
	},
	{
		"speaker": "old_hand (Tina, security consultant)",
		"text":
		"CryptoLocker hit two of my clients last month. Both had working backups, so it was a bad afternoon instead of a bad year. Test your restores!",
		"options":
		[
			{
				"id": "learn",
				"label": "ASK ABOUT HER RESTORE TEST",
				"skill": "security",
				"xp": 4,
				"text":
				"Once a quarter she restores a random file server into a lab and times it. You will do that. (+4 security XP)"
			},
			{
				"id": "cards",
				"label": "SWAP BUSINESS CARDS",
				"skill": "",
				"xp": 0,
				"text": "She hands you a card with an incident hotline on the back."
			},
			{
				"id": "bye",
				"label": "GOOD ADVICE, THANKS",
				"skill": "",
				"xp": 0,
				"text": "She tells you to do it before you need it."
			},
		],
	},
	{
		"speaker": "xX_n00b_Xx (Marcus, shy owner)",
		"text":
		"Is it rude to take the free pen and walk away? I have a rule: twenty minute pitches are not worth a pen.",
		"options":
		[
			{
				"id": "learn",
				"label": "TELL HIM TO USE THE BADGE TRICK",
				"skill": "people",
				"xp": 3,
				"text":
				"You explain: turn your badge around so they cannot scan it. He laughs for a full minute. (+3 customer XP)"
			},
			{
				"id": "cards",
				"label": "SWAP BUSINESS CARDS",
				"skill": "",
				"xp": 0,
				"text": "He swaps cards, a bit surprised that anyone asked."
			},
			{
				"id": "bye",
				"label": "ENJOY THE SHOW",
				"skill": "",
				"xp": 0,
				"text": "He says he will try."
			},
		],
	},
	{
		"speaker": "trollbot (Trent, 11,000 posts)",
		"text":
		"So YOU are the one from the forum. I read your answers. Wrong, all of them. I would correct them in person but I could go on for an hour.",
		"options":
		[
			{
				"id": "learn",
				"label": "ASK WHAT EXACTLY WAS WRONG",
				"skill": "people",
				"xp": 3,
				"text":
				"Forty minutes later you have learned nothing about PowerShell and a lot about staying calm with difficult people. (+3 customer XP)"
			},
			{
				"id": "cards",
				"label": "SWAP BUSINESS CARDS",
				"skill": "",
				"xp": 0,
				"text": "His card just says TRENT in a font you do not want to name."
			},
			{
				"id": "bye",
				"label": "WALK AWAY SLOWLY",
				"skill": "",
				"xp": 0,
				"text": "He is already explaining something to somebody else."
			},
		],
	},
]
var CHATS: Array = DEFAULT_CHATS.duplicate(true)
# who gives each session (name, company): the screen in each breakout room shows it (fx session_screen, Expo.room_info)
const SPEAKERS := {
	"ps101": ["GARY NOVAK", "LABRAT TRAINING"],
	"ps201": ["GARY NOVAK", "LABRAT TRAINING"],
	"monitor": ["RAJ PATEL", "BRIGHTLINE IT"],
	"patch": ["LINDA CHO", "UPTIME PARTNERS"],
	"oml": ["HAL BRENNER", "DESK COACH LLC"],
	"docs": ["PAM OKAFOR", "RUNBOOK CO"],
	"macs": ["TED LOWRY", "ODD MACHINE IT"],
	"security": ["DEE MARCHETTI", "WEBWOOT SECURITY"],
	"bdr": ["BRAD LUND", "SHADOWPOINT BACKUP"],
	"panel": ["FOUR MSP OWNERS", "MODERATED PANEL"],
	"hipaa": ["RUTH ANSELM", "HEALTHSAFE IT LAW"],
	"managed": ["STU KAPLAN", "TWO MAN MSP FOUNDER"],
	"spam": ["IVAN ROSE", "MAILGUARD"],
	"virt": ["CARL WEBB", "BOXES AND BYTES"],
	"hood": ["LABRAT ENGINEERS", "PRODUCT TEAM"],
	"stay": ["FOUR TECHS", "FROM OTHER MSPS"],
	"qbr": ["NINA FLORES", "CLIENT FIRST IT"],
	"ransom": ["OMAR SAYED", "DISASTER DRILL"],
}
const CROWD := {
	"resort_lobby":
	[
		{
			"who": "expo_regdesk",
			"role": "checkin",
			"x": 100,
			"facing": "right",
			"routine": ["wait:6", "say:2"]
		},
		{
			"who": "expo_atta",
			"role": "att:0",
			"x": 215,
			"facing": "left",
			"routine": ["talk:5", "wait:3"]
		},
		{
			"who": "expo_priya",
			"role": "att:1",
			"x": 243,
			"facing": "right",
			"routine": ["talk:5", "wait:3"]
		},
	],
	"resort_hall":
	[
		{
			"who": "expo_tina",
			"role": "att:3",
			"x": 140,
			"facing": "right",
			"routine": ["walk:60", "wait:3", "walk:250", "wait:2"]
		},
		{
			"who": "expo_attd",
			"role": "att:2",
			"x": 280,
			"facing": "left",
			"routine": ["wait:4", "say:2"]
		},
	],
	"ballroom":
	[
		{
			"who": "expo_atta",
			"role": "att:0",
			"x": 77,
			"facing": "right",
			"seat": "Seat1",
			"routine": ["wait:8"]
		},
		{
			"who": "expo_attb",
			"role": "att:4",
			"x": 157,
			"facing": "right",
			"seat": "Seat3",
			"routine": ["wait:8"]
		},
		{
			"who": "expo_tina",
			"role": "att:3",
			"x": 230,
			"facing": "left",
			"routine": ["wait:6", "say:2"]
		},
	],
	"breakout_a":
	[
		{
			"who": "expo_vendj",
			"role": "speaker",
			"x": 204,
			"facing": "left",
			"routine": ["wait:8", "say:2"]
		},
		{
			"who": "expo_attd",
			"role": "att:2",
			"x": 79,
			"facing": "right",
			"seat": "Seat1",
			"routine": ["wait:8"]
		},
		{
			"who": "expo_priya",
			"role": "att:1",
			"x": 139,
			"facing": "right",
			"seat": "Seat3",
			"routine": ["wait:8"]
		},
	],
	"breakout_b":
	[
		{
			"who": "expo_dee",
			"role": "speaker",
			"x": 214,
			"facing": "left",
			"routine": ["wait:8", "say:2"]
		},
		{
			"who": "expo_attb",
			"role": "att:4",
			"x": 71,
			"facing": "right",
			"seat": "Seat1",
			"routine": ["wait:8"]
		},
		{
			"who": "expo_atta",
			"role": "att:0",
			"x": 127,
			"facing": "right",
			"seat": "Seat3",
			"routine": ["wait:8"]
		},
	],
	"breakout_c":
	[
		{
			"who": "expo_vendp",
			"role": "speaker",
			"x": 192,
			"facing": "left",
			"routine": ["wait:8", "say:2"]
		},
		{
			"who": "expo_tina",
			"role": "att:3",
			"x": 91,
			"facing": "right",
			"seat": "Seat2",
			"routine": ["wait:8"]
		},
		{
			"who": "expo_attc",
			"role": "att:5",
			"x": 123,
			"facing": "right",
			"seat": "Seat3",
			"routine": ["wait:8"]
		},
	],
	"breakout_d":
	[
		{
			"who": "expo_vendg",
			"role": "speaker",
			"x": 204,
			"facing": "left",
			"routine": ["wait:8", "say:2"]
		},
		{
			"who": "expo_priya",
			"role": "att:1",
			"x": 85,
			"facing": "right",
			"seat": "Seat1",
			"routine": ["wait:8"]
		},
		{
			"who": "expo_atta",
			"role": "att:0",
			"x": 145,
			"facing": "right",
			"seat": "Seat3",
			"routine": ["wait:8"]
		},
	],
	"vendor_hall":
	[
		{
			"who": "expo_vendg",
			"role": "vendor:backup",
			"x": 159,
			"facing": "right",
			"routine": ["wait:5", "say:2"]
		},
		{
			"who": "expo_dee",
			"role": "vendor:webwoot",
			"x": 71,
			"facing": "right",
			"routine": ["wait:4", "say:2"]
		},
		{
			"who": "expo_vendo",
			"role": "vendor:psa",
			"x": 272,
			"facing": "right",
			"routine": ["wait:6", "say:2"]
		},
		{
			"who": "expo_attb",
			"role": "att:4",
			"x": 150,
			"facing": "right",
			"routine": ["walk:100", "wait:3", "walk:270", "wait:3"]
		},
		{
			"who": "expo_attc",
			"role": "att:5",
			"x": 238,
			"facing": "left",
			"routine": ["wait:5", "talk:3"]
		},
	],
}

var invited := false
var qualified := false
var decided := false
var went := false  # you went (saved: the review can mention it)
var picks: Array = []
var tot_closed := 0
var tot_missed := 0
var tot_reopened := 0
var away := false
var peeked := false
var _sent := {}
var _stage := ""
var _seen := ""
var rnd := 0
var badge := false
var spam := 0
var entries := 0
var cards_swapped := 0
var _met := {}
var _booths := {}
var _talked := {}
var _sign_cache := {}
var _shown := {}  # the session on the screen of the breakout room you are in (kept until you leave)


func _ready() -> void:
	Campaign.day_started.connect(_on_day)


func reset() -> void:
	invited = false
	qualified = false
	decided = false
	went = false
	picks = []
	tot_closed = 0
	tot_missed = 0
	tot_reopened = 0
	away = false
	peeked = false
	_sent = {}
	_stage = ""
	_seen = ""
	rnd = 0
	badge = false
	spam = 0
	entries = 0
	cards_swapped = 0
	_met = {}
	_booths = {}
	_talked = {}
	_shown = {}


func to_dict() -> Dictionary:
	return {
		"invited": invited,
		"qualified": qualified,
		"decided": decided,
		"went": went,
		"picks": picks,
		"closed": tot_closed,
		"missed": tot_missed,
		"reopened": tot_reopened,
		"spam": spam,
		"entries": entries,
		"swapped": cards_swapped,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	invited = bool(data.get("invited", false))
	qualified = bool(data.get("qualified", false))
	decided = bool(data.get("decided", false))
	went = bool(data.get("went", false))
	picks = data.get("picks", [])
	tot_closed = int(data.get("closed", 0))
	tot_missed = int(data.get("missed", 0))
	tot_reopened = int(data.get("reopened", 0))
	spam = int(data.get("spam", 0))
	entries = int(data.get("entries", 0))
	cards_swapped = int(data.get("swapped", 0))


func is_tech() -> bool:
	return Campaign.active and Campaign.mode == "tech"


# ---- the KPIs
func kpis() -> Array:
	var closed := maxi(1, tot_closed)
	return [
		{"name": "REPUTATION 55+", "ok": Campaign.rep >= 55, "now": str(Campaign.rep)},
		{
			"name": "SLA MISSES UNDER 20%",
			"ok": tot_missed * 5 <= closed,
			"now": "%d OF %d" % [tot_missed, tot_closed]
		},
		{
			"name": "REOPENS UNDER 15%",
			"ok": tot_reopened * 100 <= closed * 15,
			"now": "%d OF %d" % [tot_reopened, tot_closed]
		},
		{
			"name": "POWERSHELL LEVEL 2",
			"ok": Skills.level("powershell") >= 2,
			"now": str(Skills.level("powershell"))
		},
	]


func passed() -> int:
	var n := 0
	for k in kpis():
		n += 1 if bool(k.ok) else 0
	return n


func summary() -> String:
	var parts := []
	for k in kpis():
		parts.append("%s %s (%s)" % ["OK" if bool(k.ok) else "NO", str(k.name), str(k.now)])
	return ", ".join(parts)


func is_trip_day(day: int) -> bool:
	return is_tech() and day == TRIP_DAY and qualified


# ---- the schedule
func _process(_delta: float) -> void:
	if away and _stage != "done" and not Game.title_mode:
		_trip_tick()
		return
	if not is_tech() or Game.title_mode or World.time_scale <= 0.0 or Cards.is_open:
		return
	var day := Campaign.day
	if day == INVITE_DAY and not _sent.has("invite") and World.clock >= 10.0:
		_sent["invite"] = true
		invited = true
		Msp.mail(MORGAN, str(TEXT.invite_subject), str(TEXT.invite_body))
	elif day == PROGRESS_DAY and not _sent.has("progress") and World.clock >= 10.0:
		_sent["progress"] = true
		Msp.send_text("Boss", str(TEXT.progress) % summary())
	elif day == VERDICT_DAY and not _sent.has("verdict") and World.clock >= 9.2:
		_sent["verdict"] = true
		_verdict()


func _verdict() -> void:
	decided = true
	qualified = passed() >= NEED
	if qualified:
		Msp.mail(MORGAN, str(TEXT.yes_subject), str(TEXT.yes_body) % summary())
	else:
		Msp.mail(MORGAN, str(TEXT.no_subject), str(TEXT.no_body) % summary())


func _on_day(day: int) -> void:
	_sent = {}
	away = false
	if not is_tech():
		return
	if day == TRIP_DAY + 1:
		_home()
	if is_trip_day(day):
		away = true
		peeked = false
		picks = []
		went = true
		Career.add("trips")
		_stage = "arrive"
		rnd = 0
		_seen = ""
		badge = false
		_met = {}
		_booths = {}
		_talked = {}
		Msp.enabled = false
		World.time_scale = 0.0
		Cards.ask(
			"Morgan (Manager)",
			str(TEXT.arrive),
			[{"label": "FLY OUT", "id": "go"}],
			func(_id: String) -> void: _fly_out()
		)


func _home() -> void:
	if spam > 0:
		var sent := 0
		for v in VENDORS:
			if sent < spam and sent < VENDORS.size():
				Msp.mail(str(v.mail.from), str(v.mail.subject), str(v.mail.body))
				sent += 1
		Msp.send_text("You", str(TEXT.spam_note))
	if qualified and went:
		Msp.send_text("Dan", str(TEXT.home_ok) if peeked else str(TEXT.home_pile))
		if not peeked:
			for i in 2:
				var t: Dictionary = Msp._random_ticket("email")
				if not t.is_empty():
					t.sla_left = maxf(float(t.sla_total) * 0.5, float(t.sla_left) - 150.0)
	elif decided and not qualified:
		Msp.send_text("Dan", str(TEXT.dan_back))
		Skills.add_xp("networking", 6)


# ---- the trip: keynote, three rounds, the vendor hall, the raffle
func _fly_out() -> void:
	_stage = "keynote"
	World.clock = 8.7
	Game.go("resort_lobby", "from_taxi")
	Hints.toast(str(TEXT.to_ballroom), 5.0)


func _scene_name() -> String:
	var scene := get_tree().current_scene
	return "" if scene == null else scene.scene_file_path.get_file().get_basename()


# the trip is walked: what happens depends on the room you walk into and the stage you are at
func _trip_tick() -> void:
	match _stage:
		"keynote":
			Hints.objective = (
				"NEXT: THE KEYNOTE IN THE BALLROOM (LEFT DOOR)."
				if badge
				else "NEXT: THE KEYNOTE IN THE BALLROOM (LEFT DOOR). GET A BADGE AT REGISTRATION FIRST."
			)
		"round":
			Hints.objective = "NEXT: PICK A SESSION DOWN THE HALL (RIGHT DOOR). THE EXPO HALL IS OPEN TOO."
		"raffle":
			Hints.objective = "NEXT: THE CLOSING RAFFLE IN THE BALLROOM."
	if Cards.is_open or Game.ui_open or Game.busy:
		return
	var scene := _scene_name()
	if scene == "vendor_hall" and str(Game.vars.get("conf_booth", "")) != "":
		var booth := str(Game.vars.get("conf_booth", ""))
		Game.vars["conf_booth"] = ""
		_hall_answer(booth)
		return
	if not scene.begins_with("breakout_"):
		_shown = {}
	if scene == _seen:
		return
	_seen = scene
	match _stage:
		"keynote":
			if scene == "ballroom":
				if badge:
					World.clock = 9.0
					_keynote()
				else:
					Cards.ask(
						"Usher",
						str(TEXT.usher),
						[{"label": "BACK TO REGISTRATION", "id": "back"}],
						func(_id: String) -> void: Game.go("resort_lobby", "from_ballroom")
					)
		"round":
			if scene.begins_with("breakout_"):
				_enter_breakout()
		"raffle":
			if scene == "ballroom":
				World.clock = 16.5
				_raffle()


# ---- the agenda of this run (R11, see trip_variety.gd): the sessions in the four rooms of a round, the booths, the talks
func menu(round_index: int) -> Array:
	return Trip.menu(round_index, ROUNDS[round_index].sessions)


# every session a round can have (a pick is looked up here, whichever rooms showed it)
func pool(round_index: int) -> Array:
	var all: Array = ROUNDS[round_index].sessions.duplicate()
	if round_index < Trip.MORE_SESSIONS.size():
		all.append_array(Trip.MORE_SESSIONS[round_index])
	return all


func chat_def(index: int) -> Dictionary:
	var slots := Trip.chat_slots(CHATS)
	return slots[index % slots.size()]


func raffle_odds() -> float:
	return Trip.raffle_base() + 0.04 * float(mini(entries, 3))


func _vendor(id: String) -> Dictionary:
	var v := _vendor_base(id)
	if v.is_empty():
		for extra in Trip.EXTRA_VENDORS:
			if str(extra.id) == id:
				return extra
	return v


func _vendor_xp() -> Dictionary:
	var all := VENDOR_XP.duplicate()
	all.merge(Trip.VENDOR_XP)
	return all
func _enter_breakout() -> void:
	var idx := maxi(0, DOORS.find(str(Game.vars.get("conf_door", "from_a"))))
	var sessions: Array = menu(rnd)
	var found: Dictionary = sessions[mini(idx, sessions.size() - 1)]
	_shown = {"door": idx, "round": rnd, "id": str(found.id)}
	_session(rnd, str(found.id))


# the session on the screen of breakout room `door` (0 = A to 3 = D): the one you walked in on, else the round that is on now
func session_at(door: int) -> Dictionary:
	if not _shown.is_empty() and int(_shown.door) == door:
		return _shown
	var r := clampi(rnd, 0, ROUNDS.size() - 1)
	var sessions: Array = menu(r)
	var s: Dictionary = sessions[mini(door, sessions.size() - 1)]
	return {"door": door, "round": r, "id": str(s.id)}


# what the room's screen and sign show: round, time, the title wrapped to `chars` letters, the speaker (name, company)
func room_info(door: int, chars := 22) -> Dictionary:
	var at := session_at(door)
	var found := {}
	for s in pool(int(at.round)):
		if str(s.id) == str(at.id):
			found = s
	if found.is_empty():
		return {}
	var clock := float(CLOCKS[int(at.round)])
	var hour := int(clock)
	var minutes := int((clock - float(hour)) * 60.0)
	return {
		"id": str(at.id),
		"round": int(at.round) + 1,
		"time": "%d:%02d %s" % [hour if hour <= 12 else hour - 12, minutes, "AM" if hour < 12 else "PM"],
		"title": _wrap(str(found.get("short", found.label)), chars),
		"speaker": SPEAKERS.get(str(at.id), ["GUEST SPEAKER", "RODENT NATION"]),
	}


func _wrap(text: String, limit: int) -> Array:
	var lines := []
	var cur := ""
	for w in text.split(" "):
		if cur != "" and cur.length() + 1 + str(w).length() > limit:
			lines.append(cur)
			cur = str(w)
		else:
			cur = (cur + " " + str(w)).strip_edges()
	lines.append(cur)
	return lines


# the easel outside each breakout room shows what is on in it (the sign effect reads this)
func sign_lines(door: int) -> Array:
	if away and _stage == "round" and rnd < ROUNDS.size():
		var sessions: Array = menu(rnd)
		if door < sessions.size():
			return _wrap(str(sessions[door].get("short", sessions[door].label)), 9)
	return []


func _keynote() -> void:
	Cards.ask(
		"RODENT NATION",
		str(TEXT.keynote),
		[
			{"label": "LISTEN TO THE KEYNOTE", "id": "listen"},
			{"label": "CHECK THE QUEUE ON YOUR PHONE", "id": "peek"},
		],
		func(id: String) -> void: _keynote_answer(id)
	)


func _keynote_answer(id: String) -> void:
	_stage = "round"
	rnd = 0
	World.clock = float(CLOCKS[0])
	var text := str(TEXT.keynote_listen)
	if id == "peek":
		peeked = true
		text = str(TEXT.keynote_peek)
	else:
		Skills.add_xp("people", 3)
	Cards.ask(
		"RODENT NATION",
		text,
		[{"label": "ON TO THE SESSIONS", "id": "ok"}],
		func(_id: String) -> void: Hints.toast(str(TEXT.to_hall), 5.0)
	)


func _session(index: int, id: String) -> void:
	var found: Dictionary = {}
	for s in pool(index):
		if str(s.id) == id:
			found = s
	picks.append(id)
	Career.note_first("session", id, "sessions_seen")
	var text := str(found.get("text", ""))
	var skill := str(found.get("skill", ""))
	if id == "ps101":
		if Skills.ps_level < 3 and Skills.lesson_day != Campaign.day:
			Skills.ps_level += 1
			Skills.lesson_day = Campaign.day
			Skills.leveled.emit("powershell", Skills.ps_level)
		else:
			Skills.add_xp("servers", 8)
	elif id == "hipaa":
		Skills.add_xp("security", int(found.xp))
		Sales.adjust(0, 4)
	elif skill != "":
		Skills.add_xp(skill, int(found.xp))
	Cards.ask(
		"SESSION",
		text,
		[{"label": "NEXT", "id": "ok"}],
		func(_id: String) -> void: _after_session(index)
	)


func _after_session(index: int) -> void:
	rnd = index + 1
	if rnd >= ROUNDS.size():
		_stage = "raffle"
		World.clock = 16.0
		Hints.toast(str(TEXT.to_raffle), 5.0)
		return
	World.clock = float(CLOCKS[rnd])
	Hints.toast(str(TEXT.to_hall), 4.0)


func _hall() -> void:
	Cards.ask(
		"VENDOR HALL",
		str(TEXT.hall),
		[
			{"label": "WORK THE BOOTHS FOR SWAG", "id": "swag"},
			{"label": "FIND THE FORUM REGULARS", "id": "nerds"},
			{"label": "SIT THROUGH A BACKUP DEMO", "id": "vendor"},
		],
		func(id: String) -> void: _hall_answer(id)
	)


# a booth in the vendor hall (E on it): what it gives you, once each
func booth(id: String) -> void:
	_hall_answer(id)


func _hall_answer(id: String) -> void:
	var text := ""
	if not Campaign.active:
		Hints.toast("A BOOTH. YOU CHAT AND TAKE A PEN.", 2.5)
		return
	if _booths.has(id):
		Cards.ask(
			"VENDOR HALL",
			"You already visited this booth. They wave from behind the table.",
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
		return
	_booths[id] = true
	match id:
		"swag":
			Social.change_all(1)
			text = str(TEXT.hall_swag)
		"nerds":
			Nerds.karma += 4
			text = str(TEXT.hall_nerds)
		_:
			Skills.add_xp("security", 6)
			text = str(TEXT.hall_vendor)
	Cards.ask("VENDOR HALL", text, [{"label": "NEXT", "id": "ok"}], func(_id: String) -> void: pass)


func _raffle() -> void:
	var win := Difficulty.rng("trip").randf() < raffle_odds()
	var text := str(TEXT.raffle_win) if win else str(TEXT.raffle_lose)
	if win:
		Shift.add_energy(100.0)
		Campaign.adjust_rep(3)
		Career.add("raffle_wins")
	text += " " + (Trip.drum_line(Trip.raffle_base()) + " " if Trip.drum_line(Trip.raffle_base()) != "" else "") + str(TEXT.wrap)
	Cards.ask(
		"RODENT NATION",
		text,
		[{"label": "FLY HOME", "id": "ok"}],
		func(_id: String) -> void: _finish()
	)


func _finish() -> void:
	_stage = "done"
	Hints.objective = ""
	Game.vars["conf_booth"] = ""
	Msp.enabled = true
	Shift.skip_stay()
	World.time_scale = 1.0
	World.clock = World.DAY_END


# ---- the day report for the trip day
func adjust_report(r: Dictionary) -> Dictionary:
	if is_tech() and not away:
		tot_closed += int(r.closed)
		tot_missed += int(r.missed)
		tot_reopened += int(r.reopened)
	if away:
		r["closed"] = 0
		r["missed"] = 0
		r["reopened"] = 0
		r["open_left"] = Msp.open_tickets().size()
		r["points"] = 20
		r["pay"] = 150
		r["rep_delta"] = 2 + (1 if picks.size() >= 3 else 0)
		r["grade"] = "A"
	return r


# ---- the crowd: attendees and vendors in the venue rooms (npc.gd calls npc_use when you press E on one)
const NPC_SCENE := preload("res://scenes/npc.tscn")


func populate(stage: Node) -> void:
	if Game.title_mode:
		return
	var scene := stage.scene_file_path.get_file().get_basename()
	if scene == "conference" and Campaign.active and Meeting.state in ["called", "done"]:
		# Morgan is a real cast member now and hosts at the whiteboard herself; Marge still stands in for the owner campaign
		if Campaign.mode == "owner" or not World.chars.has("Morgan"):
			_boss(stage)
		return
	if not CROWD.has(scene):
		return
	var x0 := float(World.DATA.SCENES[scene].x0)
	for c in Trip.remap_crowd(CROWD[scene], scene):
		var npc: Node = NPC_SCENE.instantiate()
		npc.character = str(c.who)
		npc.facing = str(c.facing)
		npc.role = str(c.role)
		npc.routine = PackedStringArray(c.routine)
		npc.start_seat = str(c.get("seat", ""))
		npc.position = Vector2(x0 + float(c.x), 118.0)
		stage.get_node("Actors").add_child(npc)


# during the all-hands the boss stands at the whiteboard: Morgan (tech campaign) or Marge, the bookkeeper (owner campaign)
func _boss(stage: Node) -> void:
	var owner_mode := Campaign.mode == "owner"
	var npc: Node = NPC_SCENE.instantiate()
	npc.character = "office_marge" if owner_mode else "office_morgan"
	npc.facing = "right"
	npc.role = "boss:marge" if owner_mode else "boss:morgan"
	npc.routine = PackedStringArray(["wait:8", "talk:3"])
	npc.position = Vector2(float(World.DATA.SCENES["conference"].x0) + 60.0, 118.0)
	stage.get_node("Actors").add_child(npc)


func npc_use(npc: Node, _body: Node) -> void:
	var role := str(npc.role)
	if role.begins_with("boss:"):
		var who := role.substr(5)
		Cards.ask(
			"Morgan (Manager)" if who == "morgan" else "Marge (Bookkeeper)",
			str(TEXT.get("boss_" + who, "Thanks for coming.")),
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
	elif role == "checkin":
		_checkin()
	elif role == "speaker":
		Hints.toast("SHH. THE SPEAKER IS MID-SENTENCE. TAKE A SEAT.", 3.0)
	elif role == "site:owner":
		Onsite.interact("owner")
	elif role.begins_with("site:"):
		Onsite.interact("staff")
	elif role.begins_with("vendor:"):
		_pitch(role.substr(7))
	elif role.begins_with("att:"):
		_chat(int(role.substr(4)) % CHATS.size())


func _checkin() -> void:
	var text := str(TEXT.checkin_again)
	if not badge:
		badge = true
		text = str(TEXT.checkin)
	Cards.ask(
		"Registration", text, [{"label": "THANKS", "id": "ok"}], func(_id: String) -> void: pass
	)


func _vendor_base(id: String) -> Dictionary:
	for v in VENDORS:
		if str(v.id) == id:
			return v
	return {}


func _pitch(id: String) -> void:
	var v := _vendor(id)
	if v.is_empty():
		return
	if _met.has(id):
		Cards.ask(
			str(v.speaker),
			str(TEXT.vendor_again),
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
		return
	var options := []
	for o in v.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		str(v.speaker), str(v.text), options, func(oid: String) -> void: _pitch_answer(id, oid)
	)


const VENDOR_XP := {
	"backup": {"demo": ["security", 6], "price": ["people", 3]},
	"webwoot": {"demo": ["security", 6], "price": ["servers", 3]},
	"psa": {"demo": ["people", 6], "price": ["networking", 3]},
}


func _pitch_answer(id: String, oid: String) -> void:
	var v := _vendor(id)
	var text := ""
	for o in v.options:
		if str(o.id) == oid:
			text = str(o.text)
	if oid != "no":
		_met[id] = true
	if oid == "scan":
		spam += 1
		entries += 1
	elif _vendor_xp().get(id, {}).has(oid):
		var fx: Array = _vendor_xp()[id][oid]
		Skills.add_xp(str(fx[0]), int(fx[1]))
	Cards.ask(str(v.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _chat(index: int) -> void:
	var c: Dictionary = chat_def(index)
	if _talked.has(index):
		Cards.ask(
			str(c.speaker),
			str(TEXT.chat_again),
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
		return
	var options := []
	for o in c.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		str(c.speaker),
		_greeting() + str(c.text),
		options,
		func(oid: String) -> void: _chat_answer(index, oid)
	)


func _greeting() -> String:
	var line := str(TEXT.get("greet_" + Nerds.rank().to_lower(), ""))
	return line + " " if line != "" else ""


func _chat_answer(index: int, oid: String) -> void:
	var c: Dictionary = chat_def(index)
	var text := ""
	for o in c.options:
		if str(o.id) == oid:
			text = str(o.text)
			if int(o.xp) > 0 and str(o.skill) != "":
				Skills.add_xp(str(o.skill), int(o.xp))
	_talked[index] = true
	if oid == "cards":
		cards_swapped += 1
		Nerds.karma += 3 if Nerds.rank() in ["REGULAR", "GURU"] else 2
	Cards.ask(str(c.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
