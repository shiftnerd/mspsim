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
const UiStyle := preload("res://scripts/ui_style.gd")
const LINE_SECS := 3.4  # R23: seconds a line of a talk stays up while you sit in a session (E or Enter skips to the next line)
const SESSION_HOURS := 0.9  # game hours a session takes on the trip's clock
# P5: the owner's trip is walked too. The three sessions of the Owner card rn_session are in salons A, B and C (D is closed), and the
# three booths of the expo hall are the three vendor cards
const OWNER_BOOTHS := {"swag": "rn_rmm", "nerds": "rn_psa", "vendor": "rn_hw"}
const OWNER_SPEAKERS := [["DANA PRICE", "MARGIN CLINIC"], ["SAM OKORO", "MSP PEER GROUP"], ["WHOEVER SHOWS UP", "NO SLIDES"]]
const DEFAULT_TEXT := {
	"invite_subject": "Rodent Nation 2014: top performers go",
	"invite_body":
	"LabRat's yearly user conference, RODENT NATION, is in Orlando this June. The company pays for one tech: whoever hits the KPIs by day 16. Reputation 55 or more, SLA misses under 20 percent of closes, reopens under 15 percent of closes, and PowerShell level 2. Hit three of the four and you go. - Morgan",
	"progress": "KPI check before the Rodent Nation trip: %s. Three of four wins the ticket.",
	"seat_offer": "%s. On stage: %s, %s. The room is half full and there is a free chair in the middle.",
	"seat_yes": "TAKE A SEAT",
	"seat_no": "TRY ANOTHER ROOM",
	"seat_hint": "PICK A CHAIR AND SIT DOWN (E). THE SESSION STARTS WHEN YOU DO.",
	"seat_done": "THE SESSION LETS OUT. YOU STAND UP WITH A PAGE OF NOTES.",
	"owner_arrive": "RODENT NATION. THE SESSIONS ARE DOWN THE HALL (RIGHT DOOR): THERE IS TIME FOR ONE. THE EXPO HALL IS OPEN ALL DAY.",
	"owner_early": "THE BALLROOM IS BEING SET FOR THE CLOSING. SIT IN ON A SESSION FIRST.",
	"owner_one": "ONE SESSION IS ALL THE DAY HAS ROOM FOR. THE EXPO HALL IS STILL OPEN, AND THE CLOSING IS IN THE BALLROOM.",
	"owner_closed": "Salon D is dark: stacked chairs, a projector on a cart and a sign that says the room is being set for tomorrow.",
	"owner_booth_done": "YOU HAVE HEARD THIS PITCH. THE REP WAVES A PEN AT YOU ANYWAY.",
	"owner_talk_0": "A consultant puts one number on the screen: your effective hourly rate. Half the room goes quiet. Three packages: good, better and best, and never show the cheap one first. You rewrite your price sheet on a napkin.",
	"owner_talk_1": "Four owners on bar stools admit they have not had a week off since 2011. Burnout is a staffing plan, says the moderator, not a flaw in your character. You write down two things to stop doing yourself.",
	"owner_talk_2": "No slides and no chairs in rows. Six owners trade the stories they would never put in a case study. You swap cards with two of them. One of them knows your biggest client.",
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
			"Hi! Following up from Rodent Nation. Did you know ransomware is way up this year? Let's show you a 30 day trial. Reply YES for a free assessment. - Dee"
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
# LabRat Nerds forum regulars at the conference: each stands in the crowd with the role forum:<id> and has one short chat per trip
# (nobody is shuffled into a slot: they are fixed people). Option fields: skill + xp, karma (forum karma) and social (every coworker's
# opinion) only count in a campaign, text_free is what the option says in Free Play instead of text.
const DEFAULT_FORUM := [
	{
		"id": "priest",
		"speaker": "MPriest (Priest Michael, forum mod, Australia)",
		"text":
		"G'day! Michael. On the forum I am MPriest, and the collar is a long story. Half my private messages start with: Forgive me, father, for I rebooted production at 3 p.m. So, what is weighing on you?",
		"options":
		[
			{
				"id": "confess",
				"label": "CONFESS A SYSADMIN SIN",
				"skill": "servers",
				"xp": 4,
				"text":
				"You admit you never tested a restore. He sighs like a man who has heard it before. A green tick on the report is a rumour, mate, not a restore. Test one every month and go and sin no more. (+4 servers XP)"
			},
			{
				"id": "bless",
				"label": "BLESS MY FRESH BACKUP",
				"skill": "security",
				"xp": 3,
				"text":
				"He lays two fingers on your laptop. 'In the name of the full, the differential and the offsite copy.' Then he grins. 'It only counts once you have restored it. She'll be right.' (+3 security XP)"
			},
			{
				"id": "forum",
				"label": "ASK ABOUT THE FORUM",
				"skill": "",
				"xp": 0,
				"karma": 3,
				"text":
				"'Your answers are decent. Plain and polite, and nobody ever got banned for polite.' He pins one of your posts to the top of the thread. (+3 forum karma)",
				"text_free":
				"'Good bunch, the forum. Plain answers and no flame wars on my watch. Come back when you have a real job on.'"
			},
			{
				"id": "crew",
				"label": "ASK ABOUT YOUR CREW",
				"skill": "",
				"xp": 0,
				"social": 1,
				"text":
				"'Say thanks out loud. It costs nothing and techs remember it longer than the raise.' You decide to try it on Monday. (coworkers like you a little more)",
				"text_free": "'Say thanks out loud, mate. It costs nothing and techs remember it.'"
			},
		],
	},
	{
		"id": "grizzle",
		"speaker": "GrizzleAdmin (the forum admin since 2008)",
		"text":
		"Hmph. I run the boards. Been here since the forum was one box under a desk. Before you ask: yes, I read the FAQ, no, you did not, and no, I will not unban the guy who posted in capitals for a week.",
		"options":
		[
			{
				"id": "old",
				"label": "ASK ABOUT THE OLD DAYS",
				"skill": "servers",
				"xp": 4,
				"text":
				"He tells you about the first forum server: a desktop under a desk, the database on the same disk as the system. 'It died on a Friday. Separate the data from the system and back up both. Now go away.' (+4 servers XP)"
			},
			{
				"id": "lab",
				"label": "SHOW HIM YOUR LAB NOTES",
				"skill": "security",
				"xp": 3,
				"text":
				"He reads your notes for a long, silent minute. 'You test before production. Good. Nobody does.' He almost smiles. Almost. (+3 security XP)"
			},
			{
				"id": "rules",
				"label": "ASK ABOUT THE RULES",
				"skill": "",
				"xp": 0,
				"karma": 3,
				"text":
				"'Search first. Say what version. No capitals. Test on a lab box.' He nods. 'You follow them, which is why I have never banned you.' (+3 forum karma)",
				"text_free":
				"'Search first. Say what version. No capitals. Test on a lab box. That is all of it.'"
			},
			{
				"id": "coffee",
				"label": "OFFER HIM A COFFEE",
				"skill": "",
				"xp": 0,
				"social": 1,
				"text":
				"'Black. No sugar. The cup is always too small.' He tells you the best thing a tech can do is bring the coffee when the server is down. You will try it. (coworkers like you a little more)",
				"text_free": "'Black. No sugar. Hmph. Thanks.'"
			},
		],
	},
	{
		"id": "pip",
		"speaker": "HELPPLZ_Pip (forum newbie)",
		"text":
		"HI!!! I AM PIP!!! MY CAPS LOCK IS STUCK AND SO IS EVERYTHING ELSE!!! THE ADMIN SAYS I AM NOT ALLOWED TO TALK LIKE THIS!!! DO YOU HAVE A MINUTE???",
		"options":
		[
			{
				"id": "help",
				"label": "HELP WITH HIS PROBLEM",
				"skill": "people",
				"xp": 4,
				"text":
				"His PC is slow. You ask what it does when it is slow: he has 40 toolbars and 3 antivirus programs. You teach him to take things away one at a time. 'WOW THANK YOU!!!' (+4 customer XP)"
			},
			{
				"id": "search",
				"label": "TEACH HIM THE SEARCH BOX",
				"skill": "",
				"xp": 0,
				"karma": 3,
				"text":
				"You show him the search box and how to say which version he has. His next post is in lower case. The admin pins it out of pure shock. (+3 forum karma)",
				"text_free": "You show him the search box. He says 'WHAT A BUTTON.'"
			},
			{
				"id": "caps",
				"label": "ASK ABOUT THE CAPS",
				"skill": "people",
				"xp": 3,
				"text":
				"'IT IS ON SINCE 2011!!!' You press the key. He stares at the keyboard for a long time. 'MY WHOLE LIFE.' (+3 customer XP)"
			},
			{
				"id": "bag",
				"label": "GIVE HIM YOUR TOTE BAG",
				"skill": "",
				"xp": 0,
				"social": 1,
				"text":
				"He puts it on his head and tells everyone near the booth about you in capital letters. By Monday your coworkers have heard. (coworkers like you a little more)",
				"text_free": "He puts it on his head and tells everyone about you."
			},
		],
	},
	{
		"id": "ray",
		"speaker": "RTFM_Ray (forum regular)",
		"text":
		"Ray. Everyone on the board knows me as the guy who replies with a link. Nine times out of ten the answer is on page 12 of the manual. The tenth time the manual is wrong, and that one is a good day.",
		"options":
		[
			{
				"id": "page",
				"label": "ASK WHICH PAGE",
				"skill": "networking",
				"xp": 4,
				"text":
				"'The one about DHCP scopes. People skip it, then wonder why two printers have the same address.' He is right. You write the page number on your hand. (+4 networking XP)"
			},
			{
				"id": "wrong",
				"label": "ASK ABOUT THE WRONG MANUALS",
				"skill": "security",
				"xp": 3,
				"text":
				"'Vendor guides copy the default password into the example, and people copy the example.' You promise to change every default on day one. (+3 security XP)"
			},
			{
				"id": "link",
				"label": "ASK HIM FOR THE LINK",
				"skill": "",
				"xp": 0,
				"karma": 3,
				"text":
				"He sends you the link before you finish the sentence, with the paragraph highlighted. You thank him on the forum, which he calls 'the correct use of the thread.' (+3 forum karma)",
				"text_free": "He sends you the link before you finish the sentence."
			},
			{
				"id": "mug",
				"label": "COMPLIMENT THE MUG",
				"skill": "",
				"xp": 0,
				"social": 1,
				"text":
				"It says 'I READ THE FAQ SO YOU DON'T HAVE TO'. He lets you take a photo of it. It is in the team chat by Monday. (coworkers like you a little more)",
				"text_free": "It says 'I READ THE FAQ SO YOU DON'T HAVE TO'."
			},
		],
	},
	{
		"id": "rita",
		"speaker": "RegexRita (forum regular)",
		"text":
		"Rita. I answer the 'how do I rename 4,000 files' threads, mostly with one line nobody can read. I am told this is a problem. I disagree. What can I do for you?",
		"options":
		[
			{
				"id": "rename",
				"label": "ASK ABOUT RENAMING THE FILES",
				"skill": "servers",
				"xp": 4,
				"text":
				"She types it on a napkin: one line, three brackets, a dollar sign. 'Try it on a copy first.' You do. It works, and you do not know why. (+4 servers XP)"
			},
			{
				"id": "explain",
				"label": "ASK HER TO EXPLAIN IT",
				"skill": "people",
				"xp": 3,
				"text":
				"She takes it apart one piece at a time, in plain words, with a drawing. 'Nobody explains it, that is the whole problem.' You see why the forum loves her. (+3 customer XP)"
			},
			{
				"id": "karma",
				"label": "THANK HER ON THE FORUM",
				"skill": "",
				"xp": 0,
				"karma": 3,
				"text":
				"You post a thank-you under her answer. She replies with a link to a page about how to say thank you in fewer characters. (+3 forum karma)",
				"text_free": "You post a thank-you under her answer. She replies with a link."
			},
			{
				"id": "hair",
				"label": "ASK ABOUT THE HAIR",
				"skill": "",
				"xp": 0,
				"social": 1,
				"text":
				"'It matches my terminal theme.' She shows you the terminal. It does. Your coworkers hear about it before you are back at the booth. (coworkers like you a little more)",
				"text_free": "'It matches my terminal theme.' It does."},
		],
	},
	{
		"id": "tony", "speaker": "TapeTony (forum regular)",
		"text": "Tony. I answer the backup threads. Yes, I still run tape. A tape has never once asked me for a password reset. Sit down, I have opinions about your Friday rotation.",
		"options": [
			{"id": "rotate", "label": "ASK ABOUT THE ROTATION", "skill": "servers", "xp": 4, "text": "'Five dailies, four weeklies, twelve monthlies. Friday's tape leaves the building in somebody's bag.' He draws the calendar on your badge. You will not forget it now. (+4 servers XP)"},
			{"id": "restore", "label": "ASK WHEN HE LAST RESTORED", "skill": "security", "xp": 3, "text": "'Tuesday. One file every week, to a different machine, and the date goes on the label.' A backup nobody has restored is a rumour. (+3 security XP)"},
			{"id": "thread", "label": "QUOTE HIM IN THE BACKUP THREAD", "skill": "", "xp": 0, "karma": 3, "text": "You quote his rotation in the backup thread and give him the credit. He replies with a photo of a tape with your nick on the label. (+3 forum karma)", "text_free": "You quote his rotation in the backup thread. He replies with a photo of a tape."},
			{"id": "pocket", "label": "ASK WHAT IS IN HIS POCKET", "skill": "", "xp": 0, "social": 1, "text": "It is a tape. 'Last Friday's. It goes where I go.' He lets you hold it. Your coworkers do not believe you until they see the photo. (coworkers like you a little more)", "text_free": "It is a tape. 'Last Friday's. It goes where I go.'"},
		],
	},
	{
		"id": "dot", "speaker": "DNS_Dot (forum regular)",
		"text": "Dot. Whatever your problem is, it is DNS. I say that in every thread and I am right more often than is fair. I also label things. You are not labelled yet.",
		"options": [
			{"id": "dns", "label": "ASK WHY IT IS ALWAYS DNS", "skill": "networking", "xp": 4, "text": "'Because the name is the first thing every program asks for and the last thing anybody checks.' She shows you how to ask a server for a name by hand. It takes ten seconds. (+4 networking XP)"},
			{"id": "labels", "label": "ASK ABOUT THE LABEL MAKER", "skill": "people", "xp": 3, "text": "'A label is a note to the next tech, and the next tech is usually you, tired.' Both ends of every cable, the date on every change. (+3 customer XP)"},
			{"id": "thread", "label": "MARK HER ANSWER AS SOLVED", "skill": "", "xp": 0, "karma": 3, "text": "You go back to your old thread and mark her answer as the one that fixed it. It was DNS. She adds one to the counter in her signature. (+3 forum karma)", "text_free": "You mark her answer as the one that fixed it. It was DNS."},
			{"id": "badge", "label": "LET HER LABEL YOUR BADGE", "skill": "", "xp": 0, "social": 1, "text": "The label says 'ASK ME, I TESTED IT FIRST'. Three people at the booth read it out loud before lunch. (coworkers like you a little more)", "text_free": "The label says 'ASK ME, I TESTED IT FIRST'."
			},
		],
	},
]
var FORUM: Array = DEFAULT_FORUM.duplicate(true)
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
		{
			"who": "expo_grizzle",
			"role": "forum:grizzle",
			"x": 182,
			"facing": "left",
			"routine": ["wait:6", "say:2", "wait:4"]
		},
		{
			"who": "expo_ray",
			"role": "forum:ray",
			"x": 140,
			"facing": "right",
			"routine": ["wait:5", "talk:3", "wait:3"]
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
		{
			"who": "expo_rita",
			"role": "forum:rita",
			"x": 90,
			"facing": "right",
			"routine": ["talk:4", "wait:3", "say:2"]}, {"who": "expo_tony", "role": "forum:tony", "x": 178, "facing": "left", "routine": ["wait:5", "say:2", "wait:4"]
		},
		{
			"who": "expo_priest",
			"role": "forum:priest",
			"x": 224,
			"facing": "left",
			"routine": ["wait:5", "talk:4", "wait:3", "say:2"]
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
		{
			"who": "expo_pip",
			"role": "forum:pip",
			"x": 205,
			"facing": "right",
			"routine": ["wait:4", "talk:3", "wait:2", "say:2"]}, {"who": "expo_dot", "role": "forum:dot", "x": 115, "facing": "right", "routine": ["wait:4", "say:2", "wait:3"]
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
var seated := {}  # R23: the session you are sitting in ({index, id, title, door, lines, at, t, clock}); empty when you are not
var owner_walk := false  # P5: the owner campaign's trip is being walked through the venue
var _pending := {}  # the session you chose on the room's card, until you sit down
var _back := {}  # owner trip: where you came from (scene, x, time scale, Msp.enabled)
var _canvas: Node2D  # the caption of the talk


func _ready() -> void:
	Campaign.day_started.connect(_on_day)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_canvas = Node2D.new()
	_canvas.visible = false
	layer.add_child(_canvas)
	_canvas.draw.connect(_paint_talk)


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
	seated = {}
	_pending = {}
	owner_walk = false
	_back = {}
	if _canvas != null:
		_canvas.visible = false


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
func _process(delta: float) -> void:
	_talk_tick(delta)
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
		"o_session":
			Hints.objective = "NEXT: SIT IN ON ONE SESSION DOWN THE HALL (RIGHT DOOR). THE EXPO HALL IS OPEN TOO."
		"o_free":
			Hints.objective = "THE EXPO HALL HAS THREE BOOTHS. THE CLOSING IN THE BALLROOM (LEFT DOOR) IS THE WAY HOME."
	if Cards.is_open or Game.ui_open or Game.busy:
		return
	if owner_walk and Owner.flags.has("card_rn_wrap"):
		_owner_home()  # the closing card was answered: fly home
		return
	_watch_seat()
	var scene := _scene_name()
	if scene == "vendor_hall" and str(Game.vars.get("conf_booth", "")) != "":
		var booth := str(Game.vars.get("conf_booth", ""))
		Game.vars["conf_booth"] = ""
		booth_use(booth)
		return
	if not scene.begins_with("breakout_"):
		_shown = {}
		_pending = {}
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
		"o_session", "o_free":
			_owner_room(scene)
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
	if _free_seat() == null:
		_session(rnd, str(found.id))  # no chair to sit on (a test that is not in the room): the session is the old card
		return
	_offer_seat({"index": rnd, "id": str(found.id), "title": str(found.get("short", found.label)), "door": idx})


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
	if owner_walk:
		return owner_room_info(door, chars)
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
		"time":
		"%d:%02d %s" % [hour if hour <= 12 else hour - 12, minutes, "AM" if hour < 12 else "PM"],
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
	if owner_walk:
		return _wrap(owner_title(door), 9) if door < owner_sessions().size() else ["CLOSED"]
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
	if not seated.is_empty():
		return  # R23: you sat through it, the talk itself was the text
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
	booth_use(id)


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
	text += (
		" "
		+ (
			Trip.drum_line(Trip.raffle_base()) + " "
			if Trip.drum_line(Trip.raffle_base()) != ""
			else ""
		)
		+ str(TEXT.wrap)
	)
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


# ---- R23: sitting in a session ------------------------------------------------------------------------------------------------
# Walking into a breakout room no longer plays the session as a card. The card is now the choice (sit in on this one, or try
# another room); the session starts when you sit down on a chair, plays its lines one by one as a caption while the trip's clock
# runs, and you stand up when it is over (the reward is applied then). E / Enter skips to the next line.
func _free_seat() -> Node:
	var scene := get_tree().current_scene
	if scene == null or not _scene_name().begins_with("breakout_"):
		return null
	var taken := {}
	for n in get_tree().get_nodes_in_group("npcs"):
		taken[str(n.get("start_seat"))] = true
	var seats := scene.get_node_or_null("Interactables")
	if seats == null:
		return null
	for s in seats.get_children():
		if s.has_method("use") and s.get("occupied") != null and not taken.has(str(s.name)):
			return s
	return null


func _offer_seat(what: Dictionary) -> void:
	var info := room_info(int(what.door))
	var who: Array = info.get("speaker", ["A GUEST SPEAKER", "RODENT NATION"])
	Cards.ask(
		"SALON %s" % "ABCD"[clampi(int(what.door), 0, 3)],
		str(TEXT.seat_offer) % [str(what.title), str(who[0]), str(who[1])],
		[{"label": str(TEXT.seat_yes), "id": "sit"}, {"label": str(TEXT.seat_no), "id": "leave"}],
		func(id: String) -> void: _seat_answer(what, id)
	)


func _seat_answer(what: Dictionary, id: String) -> void:
	if id == "sit":
		_pending = what
		Hints.toast(str(TEXT.seat_hint), 5.0)
		return
	_pending = {}
	Game.go("resort_hall", str(Game.vars.get("conf_door", "from_a")))


# you chose a session and sat down: it begins
func _watch_seat() -> void:
	if _pending.is_empty() or not seated.is_empty():
		return
	Hints.objective = "TAKE A FREE CHAIR (E). THE SESSION STARTS WHEN YOU SIT DOWN."
	var me := Players.player0(get_tree().current_scene)
	if me != null and str(me.state) == "sitting":
		_begin_talk()


# the lines of a talk: its own `lines`, else the sentences of its text (the reward in brackets is the last line)
func talk_lines(found: Dictionary) -> Array:
	var own: Array = found.get("lines", [])
	if not own.is_empty():
		return own
	var out := []
	for part in str(found.get("text", "")).replace(". (", ".|(").replace(". ", ".|").split("|"):
		if str(part).strip_edges() != "":
			out.append(str(part).strip_edges().to_upper())
	return out


func _session_def(index: int, id: String) -> Dictionary:
	for s in pool(index):
		if str(s.id) == id:
			return s
	return {}


func _begin_talk() -> void:
	seated = _pending.duplicate()
	_pending = {}
	var found: Dictionary = {"text": str(TEXT.get("owner_talk_%d" % int(seated.index), ""))} if seated.get("owner", false) else _session_def(int(seated.index), str(seated.id))
	seated["lines"] = talk_lines(found)
	seated["at"] = 0
	seated["t"] = 0.0
	seated["clock"] = World.clock
	seated["hours"] = 0.0 if seated.get("owner", false) else SESSION_HOURS  # the owner's week keeps its own clock
	Game.ui_open = true  # you stay in the chair until it is over
	_canvas.visible = true
	_nod()


func talk_line() -> String:
	if seated.is_empty() or int(seated.at) >= seated.lines.size():
		return ""
	return str(seated.lines[int(seated.at)])


func _talk_tick(delta: float) -> void:
	if seated.is_empty():
		return
	if Cards.is_open:
		return
	Game.ui_open = true
	seated.t = float(seated.t) + delta
	var n: int = maxi(1, seated.lines.size())
	World.clock = float(seated.clock) + float(seated.hours) * minf(1.0, (float(seated.at) + float(seated.t) / LINE_SECS) / float(n))
	if float(seated.t) >= LINE_SECS:
		talk_skip()
	_canvas.queue_redraw()


# on to the next line (the timer, or E / Enter); after the last one the session is over
func talk_skip() -> void:
	if seated.is_empty():
		return
	seated.at = int(seated.at) + 1
	seated.t = 0.0
	if int(seated.at) >= seated.lines.size():
		_end_talk()
	else:
		_nod()


func _end_talk() -> void:
	var done := seated.duplicate()
	World.clock = float(done.clock) + float(done.hours)
	if done.get("owner", false):
		_owner_session_done(int(done.index))
	else:
		_session(int(done.index), str(done.id))  # the reward (no card: seated is still set)
	seated = {}
	_canvas.visible = false
	Game.ui_open = false
	var me := Players.player0(get_tree().current_scene)
	if me != null and str(me.state) == "sitting" and me.has_method("_stand_up"):
		me._stand_up()
	if done.get("owner", false):
		Hints.toast(str(TEXT.seat_done), 4.0)
	else:
		_after_session(int(done.index))


# a nod at every new line (the meeting gesture), from you in your chair
func _nod() -> void:
	var me := Players.player0(get_tree().current_scene)
	if me == null or str(me.state) != "sitting" or str(me.get("_gesture")) != "":
		return
	var anim := "sitnod_%s" % str(me.facing)
	if me.sprite.sprite_frames != null and me.sprite.sprite_frames.has_animation(anim):
		me._gesture = "sitnod"
		me.sprite.play(anim)


func _input(event: InputEvent) -> void:
	if seated.is_empty() or Cards.is_open or not Controls.pressed(event):
		return
	if float(seated.t) > 0.35 and (Controls.confirm(event) or Controls.matches(event, "interact")):
		talk_skip()
		get_viewport().set_input_as_handled()


# the talk on screen: a strip with the room and the title, the line as a caption, the key hint
func _paint_talk() -> void:
	if seated.is_empty():
		return
	var size := get_viewport().get_visible_rect().size
	UiStyle.hint_bar(_canvas, size, "E = NEXT LINE")
	var top := UiStyle.caption_bar(_canvas, size, talk_line())
	var head := "SALON %s  %d/%d  %s" % ["ABCD"[clampi(int(seated.door), 0, 3)], mini(int(seated.at) + 1, seated.lines.size()), seated.lines.size(), str(seated.title)]
	var wide := int((size.x - 12.0) / 4.0)
	var o := UiStyle.strip(_canvas, Rect2(0.0, top - UiStyle.STRIP_H, size.x, UiStyle.STRIP_H))
	UiStyle.text(_canvas, head.left(wide), o.x, o.y, UiStyle.WHITE)


# ---- P5: the owner walks the venue (Owner card rn_invite, GO YOURSELF) ------------------------------------------------------------
# Owner.apply asks here before it shows a chained card: with the real rooms in use (Outings.use_rooms) the session card rn_session
# becomes the walk (the lobby, one session in a salon, the three booths of the expo hall, the closing in the ballroom = rn_wrap),
# and the hub card rn_hall is not needed while you are standing in the venue. Without rooms the trip stays the old cards.
func owner_show(id: String) -> bool:
	if id == "rn_session":
		if not Outings.use_rooms or Game.title_mode or Campaign.mode != "owner" or get_tree().current_scene == null:
			return false
		_owner_fly()
		return true
	return owner_walk and id == "rn_hall"


func _owner_fly() -> void:
	var here := get_tree().current_scene
	var me := Players.player0(here)
	_back = {
		"scene": here.scene_file_path.get_file().get_basename(),
		"x": me.global_position.x if me != null else -1.0,
		"scale": World.time_scale if World.time_scale > 0.0 else 1.0,
		"msp": Msp.enabled,
	}
	owner_walk = true
	away = true
	_stage = "o_session"
	_seen = ""
	_met = {}
	_booths = {}
	_talked = {}
	_pending = {}
	seated = {}
	Owner.flags.erase("card_rn_wrap")
	Msp.enabled = false
	World.time_scale = 0.0
	Game.go("resort_lobby", "from_taxi")
	Hints.toast(str(TEXT.owner_arrive), 6.0)


func owner_sessions() -> Array:
	return Owner.card_data("rn_session").get("options", [])


# "PRICING AND PACKAGING CLINIC" (the option's label without the effect in brackets)
func owner_title(door: int) -> String:
	var list := owner_sessions()
	if door < 0 or door >= list.size():
		return "CLOSED"
	return str(list[door].label).get_slice(" (", 0)


func owner_room_info(door: int, chars := 22) -> Dictionary:
	if door < 0 or door >= owner_sessions().size():
		return {}
	return {"id": "owner%d" % door, "round": 1, "time": "2:00 PM", "title": _wrap(owner_title(door), chars), "speaker": OWNER_SPEAKERS[mini(door, OWNER_SPEAKERS.size() - 1)]}


# the room the owner just walked into
func _owner_room(scene: String) -> void:
	if scene.begins_with("breakout_"):
		var idx := maxi(0, DOORS.find(str(Game.vars.get("conf_door", "from_a"))))
		if _stage == "o_free":
			Hints.toast(str(TEXT.owner_one), 5.0)
		elif idx >= owner_sessions().size():
			Cards.ask(
				"SALON D",
				str(TEXT.owner_closed),
				[{"label": "BACK TO THE HALL", "id": "leave"}],
				func(_id: String) -> void: Game.go("resort_hall", str(Game.vars.get("conf_door", "from_a")))
			)
		elif _free_seat() == null:
			_owner_session_done(idx)  # no chair: the session counts as sat through
		else:
			_shown = {"door": idx, "round": 0, "id": "owner%d" % idx}
			_offer_seat({"index": idx, "id": "owner%d" % idx, "title": owner_title(idx), "door": idx, "owner": true})
	elif scene == "ballroom":
		if _stage == "o_free":
			Owner.show_card("rn_wrap")
		else:
			Hints.toast(str(TEXT.owner_early), 4.0)


# the session is over: its effect is the Owner card's (without the chained hub card)
func _owner_session_done(index: int) -> void:
	var list := owner_sessions()
	if index >= 0 and index < list.size():
		var fx: Dictionary = (list[index].get("fx", {}) as Dictionary).duplicate()
		fx.erase("show")
		Owner.apply(fx)
		Owner.flags["card_rn_session"] = index
	_stage = "o_free"


# a booth of the expo hall: the tech's freebies, or (owner) the vendor who sells you a better stack with a catch
func booth_use(id: String) -> void:
	if not owner_walk:
		_hall_answer(id)
		return
	var card := str(OWNER_BOOTHS.get(id, ""))
	if card == "":
		return
	if Owner.flags.get(card, false):
		Hints.toast(str(TEXT.owner_booth_done), 3.0)
	else:
		Owner.show_card(card)


func _owner_home() -> void:
	owner_walk = false
	away = false
	_stage = ""
	_pending = {}
	seated = {}
	Hints.objective = ""
	Game.vars["conf_booth"] = ""
	Msp.enabled = bool(_back.get("msp", true))
	World.time_scale = float(_back.get("scale", 1.0))
	Game.pending_x = float(_back.get("x", -1.0))
	Game.go(str(_back.get("scene", "main_floor")), "start")


# ---- the day report for the trip day
func adjust_report(r: Dictionary) -> Dictionary:
	if is_tech() and not away:
		tot_closed += int(r.closed)
		tot_missed += int(r.missed)
		tot_reopened += int(r.reopened)
	if away and not owner_walk:
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
		# Morgan is a real cast member now and hosts at the whiteboard herself; Christy still stands in for the owner campaign
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


# during the all-hands the boss stands at the whiteboard: Morgan (tech campaign) or Christy, the controller (owner campaign)
func _boss(stage: Node) -> void:
	var owner_mode := Campaign.mode == "owner"
	var npc: Node = NPC_SCENE.instantiate()
	npc.character = "office_christy" if owner_mode else "office_morgan"
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
			"Morgan (Manager)" if who == "morgan" else "Christy (Controller)",
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
	elif role.begins_with("forum:"):
		_forum(role.substr(6))


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


# a forum regular from Expo.FORUM (role forum:<id>): one chat per trip, an option can give XP, forum karma and coworker opinion
func forum_def(id: String) -> Dictionary:
	for f in FORUM:
		if str(f.id) == id:
			return f
	return {}


func _forum(id: String) -> void:
	var c := forum_def(id)
	if c.is_empty():
		return
	if _talked.has("forum:" + id):
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
		func(oid: String) -> void: _forum_answer(id, oid)
	)


func _forum_answer(id: String, oid: String) -> void:
	var c := forum_def(id)
	var text := ""
	for o in c.options:
		if str(o.id) != oid:
			continue
		text = str(o.text)
		if int(o.xp) > 0 and str(o.skill) != "":
			Skills.add_xp(str(o.skill), int(o.xp))
		if Campaign.active:
			Nerds.karma += int(o.get("karma", 0))
			if int(o.get("social", 0)) != 0:
				Social.change_all(int(o.social))
		elif o.has("text_free"):
			text = str(o.text_free)
	_talked["forum:" + id] = true
	Cards.ask(str(c.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


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
