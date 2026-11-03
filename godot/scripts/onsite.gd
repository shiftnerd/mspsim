extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length,max-returns
# Onsite visits (tech campaign): some tickets cannot be fixed from the RMM. The PSA shows GO ONSITE; you drive to the client
# (drive time passes, other tickets keep ageing), walk around their office (a real set, see tools/client_sets.lua) and work on
# the equipment with E: the network cabinet, the front desk PC, the printer, the server. Each client site type exists in two
# skins (a = the client, b = a prospect that looks like another business).
# The story text lives in TEXT / JOBS / EVENTS so reviewers can edit it in story/strings.txt.

const DRIVE_MINUTES := {0: 20, 1: 35, 3: 25, 8: 50, 9: 30, 10: 70}  # the usual drive to each client site
const DEFAULT_DRIVE := 45
const SLA_PER_HOUR := 45.0  # seconds taken off the other tickets' clocks for each hour you are away
const SITES := {
	0: {"type": "dental", "skin": "a"},
	1: {"type": "realty", "skin": "a"},
	3: {"type": "law", "skin": "a"},
	8: {"type": "vet", "skin": "a"},
	9: {"type": "arch", "skin": "a"},
	10: {"type": "trailer", "skin": "a"},
}
const OBJECTS := {
	"dental": ["pc", "exam", "xray", "cabinet", "server", "vip"],
	"law": ["pc", "printer", "cabinet", "server", "vip"],
	"vet": ["pc", "exam", "cabinet", "server", "vip"],
	"arch": ["pc", "printer", "cabinet", "server", "vip"],
	"realty": ["pc", "printer", "cabinet", "server", "vip"],
	"trailer": ["pc", "printer", "cabinet", "server", "vip"],
}
const PCS := {"pc": "FRONT1", "exam": "EXAM1", "vip": "OWNER1"}
const SKIN_COLORS := {
	"dental": {"a": ["#CFE8EE", "#2E9AB8"], "b": ["#F2E6EE", "#B8508A"]},
	"law": {"a": ["#6A4A38", "#C8A04A"], "b": ["#3E4A5E", "#D8D0B0"]},
	"vet": {"a": ["#CDE6C8", "#3E8E4A"], "b": ["#F6E2C0", "#E07A2E"]},
	"arch": {"a": ["#E8E6E0", "#2A2D36"], "b": ["#DCE4D4", "#B8503E"]},
	"realty": {"a": ["#F4ECD2", "#E0A030"], "b": ["#DCE6F2", "#2E5AA8"]},
	"trailer": {"a": ["#B8A27A", "#E0A030"], "b": ["#A8B0A0", "#D2452E"]},
}
const DEFAULT_SITE_APPS := {
	"dental":
	{
		"app": "DENTALDESK PRO",
		"title": "TODAYS SCHEDULE",
		"rows":
		[
			"9:00 SMITH, J   CLEANING",
			"9:30 ORTEGA, M  CROWN PREP",
			"10:15 LEE, K     X-RAYS",
			"11:00 BAKER, T   FILLING",
			"1:00 NGUYEN, A  CONSULT"
		],
		"mails":
		[
			["Hygienist", "Please do not reboot the x-ray PC mid-scan"],
			["Supplier", "Your order of gloves has shipped"]
		],
	},
	"law":
	{
		"app": "CASELINE 8",
		"title": "OPEN MATTERS",
		"rows":
		[
			"M-2231 ESTATE OF HOLLIS",
			"M-2240 BANKS V. COUNTY",
			"M-2252 LEASE REVIEW",
			"M-2257 CLOSING: MILL ST",
			"M-2261 DEPOSITION PREP"
		],
		"mails":
		[
			["Paralegal", "Filed with the court at 4:55 (phew)"],
			["Court clerk", "Hearing moved to Thursday"]
		],
	},
	"vet":
	{
		"app": "PAWTRACK",
		"title": "TODAYS PATIENTS",
		"rows":
		[
			"8:30 REX (GOLDEN)   VACCINES",
			"9:00 MISS KITTY      CHECKUP",
			"9:45 BUDDY (BEAGLE)  EAR INFECTION",
			"10:30 OTIS (POODLE)   DENTAL",
			"11:15 PEANUT (HAMSTER) WEIGH-IN"
		],
		"mails":
		[
			["Vet tech", "The lab analyzer printed a blank page again"],
			["Pet supplier", "New shipment of flea treatment"]
		],
	},
	"arch":
	{
		"app": "DRAFTBOX CAD",
		"title": "PROJECTS",
		"rows":
		[
			"13-011 RIVERSIDE LIBRARY",
			"13-017 MILL ST LOFTS",
			"14-002 FIRE STATION 4",
			"14-005 HOUSE ADDITION",
			"14-009 PARKING DECK"
		],
		"mails":
		[
			["Contractor", "Need the revised plans by noon"],
			["Plotter", "Roll 40 ft almost out of paper"]
		],
	},
	"realty":
	{
		"app": "LISTINGHUB MLS",
		"title": "ACTIVE LISTINGS",
		"rows":
		[
			"412 OAK ST   $199K  2BD",
			"88 MAPLE CT  $249K  3BD",
			"7 LAKE RD    $325K  4BD",
			"1500 HILL DR $410K  4BD",
			"22 PINE LN   $179K  2BD"
		],
		"mails":
		[
			["Buyer", "Can we see the Oak St house Saturday?"],
			["MLS", "Three new listings in your area"]
		],
	},
	"trailer":
	{
		"app": "DISPATCHPLUS",
		"title": "TODAYS JOBS",
		"rows":
		[
			"OLD MILL: IMPLOSION PREP",
			"FIFTH AND MAIN: STRIP OUT",
			"WAREHOUSE 9: HAUL AWAY",
			"SCHOOL ANNEX: ASBESTOS CHECK",
			"BRIDGE ST: EQUIPMENT MOVE"
		],
		"mails":
		[
			["Foreman", "Truck 3 is stuck in the mud again"],
			["Safety", "Hard hat inspection tomorrow"]
		],
	},
}
var SITE_APPS: Dictionary = DEFAULT_SITE_APPS.duplicate(true)
const DEFAULT_FINDINGS := {
	"pc":
	[
		{
			"text": "Drive C on this PC is 98 percent full. Nobody has noticed.",
			"summary": "Front desk PC is almost out of disk space",
			"fix": "clear_temp",
			"pri": 3,
			"body":
			"%s here: the front desk computer is getting slower every day. Can you take a look?",
			"project": "desktops"
		},
		{
			"text":
			"The antivirus on this PC expired in January. A small red shield sits in the corner and nobody clicks it.",
			"summary": "Antivirus expired on a PC",
			"fix": "av",
			"pri": 3,
			"body": "%s here: we think the antivirus on one of our PCs has expired. Please check.",
			"project": "security"
		},
	],
	"exam":
	[
		{
			"text":
			"The exam room PC takes four minutes to open a chart. They have learned to start it before the patient arrives.",
			"summary": "Exam room PC is very slow",
			"fix": "clear_temp",
			"pri": 3,
			"body": "%s here: the exam room computer is crawling. Could you have a look?",
			"project": "desktops"
		},
	],
	"vip":
	[
		{
			"text":
			"The owner's laptop has 41 pending updates and a sticker with a password on the lid.",
			"summary": "Owner's laptop needs updates and a password policy",
			"fix": "av",
			"pri": 3,
			"body": "%s here: could you make sure my laptop is up to date?",
			"project": "security"
		},
	],
	"printer":
	[
		{
			"text":
			"The printer has a stack of old jobs stuck in the queue and a sticky note saying DO NOT USE.",
			"summary": "Printer queue is stuck",
			"fix": "spooler",
			"pri": 3,
			"body": "%s here: the printer is stuck again. Please clear it.",
			"project": ""
		},
	],
	"cabinet":
	[
		{
			"text":
			"The network is on an old grey hub with no labels and no battery backup. One power flicker and everything is down.",
			"summary": "Replace the old hub and add a battery backup",
			"fix": "onsite_upgrade",
			"pri": 4,
			"body":
			"%s here: we would like the network to be more reliable. Could you look at the equipment in the closet?",
			"project": "network"
		},
	],
	"server":
	[
		{
			"text":
			"The server's drive light has been amber for a while and the backup log says the last good copy was nine days ago.",
			"summary": "Server drive warning and old backup",
			"fix": "onsite_server",
			"pri": 2,
			"body": "%s here: someone noticed a light on the server. Can you check it today?",
			"project": "backup_dr"
		},
	],
	"xray":
	[
		{
			"text": "The x-ray sensor cable is bent in half and held with tape. It works. For now.",
			"summary": "Replace a damaged x-ray sensor cable",
			"fix": "onsite_xray",
			"pri": 4,
			"body": "%s here: could you look at the x-ray cable before it fails on a patient day?",
			"project": ""
		},
	],
}
var FINDINGS: Dictionary = DEFAULT_FINDINGS.duplicate(true)
const DEFAULT_MEETINGS := {
	"qbr":
	{
		"text":
		"The owner welcomes you into the office: it is review time. Coffee, the numbers on your laptop and a client who has opinions about the printer.",
		"options":
		[
			{
				"id": "numbers",
				"label": "WALK THROUGH THE NUMBERS",
				"text":
				"You show them tickets closed, response times and what the backups caught. They nod a lot."
			},
			{
				"id": "listen",
				"label": "ASK WHAT KEEPS THEM UP AT NIGHT",
				"text":
				"They talk for twenty minutes, and then mention a problem they never reported."
			},
			{
				"id": "service",
				"label": "OFFER A MANAGED SERVICE",
				"text":
				"You explain how a managed service would take a worry off their plate. They ask for a proposal."
			},
		],
	},
	"pitch":
	{
		"text":
		"The owner has twenty minutes. You have a folder, a business card and a company logo on your shirt. Their IT guy is a nephew.",
		"options":
		[
			{
				"id": "report",
				"label": "SHOW A SAMPLE REPORT",
				"text":
				"You show what a good month looks like: tickets, patches, backups. They look interested, with a pen in hand."
			},
			{
				"id": "pain",
				"label": "ASK ABOUT THEIR PAIN",
				"text":
				"You ask what goes wrong and then say nothing. People fill the silence, and you listen."
			},
			{
				"id": "moon",
				"label": "PROMISE THE MOON",
				"text":
				"You promise a ten minute response time, everything fixed by noon and free hardware. You are persuasive and you also know it is a lie."
			},
		],
	},
}
var MEETINGS: Dictionary = DEFAULT_MEETINGS.duplicate(true)
const SITE_PROSPECT := {
	"dental": "BRIGHT SMILES DENTAL",
	"law": "SPENCE AND ROE LLP",
	"vet": "HAPPY TAILS VET",
	"arch": "NORTHLIGHT DESIGN",
	"realty": "KEYSTONE HOMES",
	"trailer": "BLACKROCK WRECKING",
}
const OBJECT_NAMES := {
	"pc": "THE FRONT DESK PC",
	"cabinet": "THE NETWORK CABINET",
	"printer": "THE PRINTER",
	"server": "THE SERVER"
}
const DEFAULT_TEXT := {
	"fine": "You look it over. Nothing wrong with this one.",
	"inspected": "You already looked at that one.",
	"found_ticket":
	"You log a ticket. The team will pick it up. The client likes that you spotted it.",
	"found_project":
	"You note it as an opportunity. A quote will be waiting for you in the morning.",
	"found_note": "You make a mental note. It might become a problem.",
	"found_nocampaign": "You would log a ticket for that.",
	"missed_mail":
	"You looked right at it when you visited and did not say a word. Now it has broken. Please look at it today.",
	"meeting_done": "The meeting is over. You shake hands and walk out.",
	"pitch_signed": "They sign. The owner walks you to the door and says to send the paperwork.",
	"pitch_think": "They will think about it. You leave a card and a folder.",
	"qbr_fee": "They are so happy they add premium support. Their fee goes up 10 percent.",
	"audit_button": "LOOK AROUND",
	"door_title": "Your van is parked out front. Where to?",
	"door_ticket": "Ticket #%d needs you onsite at %s.",
	"visit_confirm":
	"Drive to %s? About %d minutes each way, and the queue keeps ageing while you are out.",
	"offer":
	"%s needs you onsite: this cannot be fixed from the RMM. The drive takes about %d minutes each way and your other tickets keep ageing while you are out.",
	"go": "DRIVE THERE NOW",
	"later": "NOT YET",
	"arrive":
	"You arrive at %s after %d minutes on the road. Walk to the equipment and press E on it.",
	"nothing": "Nothing wrong with this one. Look for what the ticket describes.",
	"no_job": "Everything looks fine here.",
	"leave_unmet":
	"You have not met the owner yet. If you leave now the visit was a waste of a drive.",
	"arrive_visit":
	"You arrive at %s after %d minutes on the road. Look around first, then ask for the owner (the OWNER door).",
	"intro_mail":
	"From day 3, some problems cannot be fixed from the RMM: a dead switch, a failing drive. The ticket will say GO ONSITE in the PSA. You can also use the front door any time to visit a client. Mind the clock: your other tickets keep ageing while you are out. - Morgan",
	"cooldown": "You already logged something for them today. Give them a day.",
	"leave_ask": "The ticket is still open. If you leave now the client will not be happy.",
	"stay": "STAY AND FINISH",
	"leave": "LEAVE ANYWAY",
	"home": "You drive back to the office (%d minutes). The queue has grown.",
	"fixed": "Fixed onsite. The client signs the ticket and thanks you.",
	"dropped": "You left before finishing. The client is not pleased.",
	"symptom": "NO RESPONSE FROM THE HOST. NEEDS HANDS ON THE EQUIPMENT: GO ONSITE FROM THE PSA.",
	"staff": "The front desk person points you toward the equipment and offers you a coffee.",
	"printer_stars3":
	"FLAWLESS. The printer prints a perfect test page. The whole office applauds. (+12 servers XP)",
	"printer_stars2": "You win, with a few scratches. The printer works, mostly. (+8 servers XP)",
	"printer_stars1":
	"It prints. The streaks are still there but nobody will say anything. (+4 servers XP)",
	"printer_stars0":
	"The printer won. You close the lid and promise to send a quote for a new one.",
	"printer_practice":
	"This printer is acting up. Want to take a crack at it? (practice: it does not count for a ticket)",
	"printer_practice_done": "Printer repair: %d of 3 stars.",
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)
const DEFAULT_JOBS := [
	{
		"id": "switch",
		"object": "cabinet",
		"pri": 1,
		"summary": "The whole office has no network",
		"body":
		"Nothing works since this morning. The little box on the wall has no lights. Please come out, we cannot work. - %s",
		"intro":
		"The network cabinet is dark. The switch has no lights, the power adapter is warm and one cable end has been chewed.",
		"options":
		[
			{
				"id": "swap",
				"label": "SWAP IN A NEW SWITCH",
				"hours": 0.75,
				"chance": 1.0,
				"skill": "networking",
				"xp": 8,
				"text":
				"New switch, same cables. Everything lights up and the whole office cheers. (+8 networking XP)"
			},
			{
				"id": "reseat",
				"label": "RESEAT THE POWER AND THE CABLES",
				"hours": 0.25,
				"chance": 0.35,
				"skill": "networking",
				"xp": 4,
				"text": "It lights up for a minute, then dies again. It really needs replacing."
			},
			{
				"id": "shop",
				"label": "TAKE IT BACK TO THE SHOP",
				"hours": 0.5,
				"chance": 0.0,
				"skill": "",
				"xp": 0,
				"text": "You bag the switch. The office is down until you come back. Not great."
			},
		],
	},
	{
		"id": "server",
		"object": "server",
		"pri": 1,
		"summary": "The server is beeping and email is slow",
		"body":
		"There is a loud beep coming from the server in the back and the email is crawling. Please send someone. - %s",
		"intro":
		"The server beeps every ten seconds. The front panel shows an amber light on the second drive: a failed disk in the RAID.",
		"options":
		[
			{
				"id": "hotswap",
				"label": "HOT-SWAP THE FAILED DRIVE",
				"hours": 0.75,
				"chance": 0.9,
				"skill": "servers",
				"xp": 8,
				"text":
				"You pull the dead disk and slide in the spare. The array starts to rebuild and the beeping stops. (+8 servers XP)"
			},
			{
				"id": "silence",
				"label": "SILENCE THE ALARM AND CHECK LATER",
				"hours": 0.1,
				"chance": 0.0,
				"skill": "",
				"xp": 0,
				"text": "It is quiet now. That is not fixing it."
			},
			{
				"id": "backup",
				"label": "RUN A BACKUP FIRST, THEN SWAP",
				"hours": 1.25,
				"chance": 1.0,
				"skill": "security",
				"xp": 6,
				"text":
				"It takes a long time, but you have a fresh copy before touching anything. Then the swap goes smoothly. (+6 security XP)"
			},
		],
	},
	{
		"id": "printer",
		"object": "printer",
		"pri": 3,
		"summary": "The big printer is making a grinding noise",
		"body":
		"The copier makes a terrible noise and the pages come out with black streaks. Nobody here knows what to do. - %s",
		"intro":
		"The printer grinds, leaves black streaks and smells hot. The fuser is shot and there is a scrap of paper wrapped around the rollers.",
		"options":
		[
			{
				"id": "fuser",
				"label": "REPLACE THE FUSER UNIT",
				"hours": 0.75,
				"chance": 0.9,
				"skill": "servers",
				"xp": 5,
				"text": "The new fuser snaps in. Crisp pages, no smell. (+5 servers XP)"
			},
			{
				"id": "clear",
				"label": "CLEAR THE PAPER AND CLEAN THE ROLLERS",
				"hours": 0.25,
				"chance": 0.4,
				"skill": "",
				"xp": 0,
				"text": "The streaks are gone, for now. The grinding comes back after twenty pages."
			},
			{
				"id": "vendor",
				"label": "CALL THE COPIER COMPANY",
				"hours": 0.15,
				"chance": 0.0,
				"skill": "people",
				"xp": 2,
				"text": "They can come Thursday. The client is not pleased."
			},
			{
				"id": "fight",
				"label": "OPEN IT UP AND FIGHT IT",
				"hours": 0.0,
				"chance": 1.0,
				"skill": "",
				"xp": 0,
				"text": "",
				"game": "printer"
			},
		],
	},
	{
		"id": "pc",
		"object": "pc",
		"pri": 2,
		"summary": "The front desk computer will not turn on",
		"body":
		"Our front desk PC is dead. No lights, nothing. We cannot check anyone in. Please come as soon as you can. - %s",
		"intro":
		"The front desk PC does not respond at all. You swap the power cable and still nothing: the power supply is dead.",
		"options":
		[
			{
				"id": "psu",
				"label": "SWAP THE POWER SUPPLY",
				"hours": 0.5,
				"chance": 0.85,
				"skill": "servers",
				"xp": 6,
				"text":
				"A new power supply and the machine boots on the first try. Windows 7 never looked so good. (+6 servers XP)"
			},
			{
				"id": "loaner",
				"label": "SET UP THE LOANER PC",
				"hours": 1.0,
				"chance": 1.0,
				"skill": "people",
				"xp": 4,
				"text":
				"You plug in the spare and restore the user's profile. It takes a while, but they are back to work. (+4 customer XP)"
			},
			{
				"id": "ignore",
				"label": "TELL THEM TO TRY THE POWER BUTTON",
				"hours": 0.1,
				"chance": 0.0,
				"skill": "",
				"xp": 0,
				"text": "They have tried the power button. Many times."
			},
		],
	},
	{
		"id": "upgrade",
		"object": "cabinet",
		"pri": 4,
		"summary": "Network upgrade: replace the old hub",
		"body":
		"We are still on the little grey hub from 2006 and everything is slow. Can you swap it for something modern while you are here? - %s",
		"intro":
		"An old 10/100 hub with a rat's nest of cables. A new gigabit switch is in the box. Every cable is a mystery.",
		"options":
		[
			{
				"id": "label",
				"label": "LABEL EVERY CABLE, THEN SWAP",
				"hours": 1.5,
				"chance": 1.0,
				"skill": "networking",
				"xp": 10,
				"text":
				"It takes all afternoon, but every cable has a label and the new switch hums happily. (+8 networking XP)"
			},
			{
				"id": "quick",
				"label": "SWAP IT FAST AND TEST AFTER",
				"hours": 0.5,
				"chance": 0.65,
				"skill": "networking",
				"xp": 5,
				"text":
				"Mostly fine. One printer cable goes to the wrong port and takes a while to find."
			},
			{
				"id": "wait",
				"label": "COME BACK AFTER HOURS",
				"hours": 0.1,
				"chance": 0.0,
				"skill": "",
				"xp": 0,
				"text":
				"You schedule it for tonight. The client is fine with that, but you have to come back."
			},
		],
	},
]
var JOBS: Array = DEFAULT_JOBS.duplicate(true)
const DEFAULT_MORE_JOBS := [
	{
		"id": "exam",
		"object": "exam",
		"pri": 2,
		"summary": "The exam room computer froze with a patient in the room",
		"body":
		"Exam room 2 is frozen. The patient is in the chair and I cannot pull up their chart. Please hurry. - %s",
		"intro":
		"The exam room PC is frozen on the practice software. A patient is waiting and the chart will not load.",
		"options":
		[
			{
				"id": "restart",
				"label": "RESTART THE PRACTICE SOFTWARE",
				"hours": 0.25,
				"chance": 0.5,
				"skill": "servers",
				"xp": 3,
				"text":
				"The software restarts, but it hangs again when it opens the chart. Something else is wrong."
			},
			{
				"id": "profile",
				"label": "REBUILD THE USER PROFILE",
				"hours": 0.75,
				"chance": 0.95,
				"skill": "servers",
				"xp": 7,
				"text":
				"A new profile, a quick reconnect to the database and the chart loads. The patient waited, but only a little. (+7 servers XP)"
			},
			{
				"id": "move",
				"label": "MOVE THE PATIENT TO THE OTHER EXAM ROOM",
				"hours": 0.1,
				"chance": 0.0,
				"skill": "people",
				"xp": 2,
				"text": "That works for today. The PC is still broken."
			},
		],
	},
	{
		"id": "xray",
		"object": "xray",
		"pri": 2,
		"summary": "The digital x-ray sensor is not detected",
		"body":
		"The x-ray sensor says NOT FOUND and the patient is waiting for a bitewing. Please come fix it. - %s",
		"intro":
		"The x-ray software cannot find the sensor. The USB cable has a kink and the driver shows a yellow warning.",
		"options":
		[
			{
				"id": "driver",
				"label": "REINSTALL THE SENSOR DRIVER",
				"hours": 0.5,
				"chance": 0.8,
				"skill": "servers",
				"xp": 6,
				"text":
				"The old driver was corrupted. The new one finds the sensor right away. (+6 servers XP)"
			},
			{
				"id": "cable",
				"label": "REPLACE THE USB CABLE",
				"hours": 0.25,
				"chance": 0.7,
				"skill": "networking",
				"xp": 4,
				"text":
				"A fresh cable and the sensor lights up. It was a kinked cable all along. (+4 networking XP)"
			},
			{
				"id": "call",
				"label": "CALL THE SENSOR VENDOR",
				"hours": 0.2,
				"chance": 0.0,
				"skill": "",
				"xp": 0,
				"text": "They want a serial number you cannot read. Nobody is happy."
			},
		],
	},
	{
		"id": "vip",
		"object": "vip",
		"pri": 2,
		"vip": true,
		"summary": "The boss cannot get email on his tablet",
		"body":
		"My email has stopped working on my iPad and I have a big meeting this afternoon. Please fix it right away. - %s",
		"intro":
		"The owner's tablet shows 'Cannot get mail'. The account password changed last week and the tablet still has the old one.",
		"options":
		[
			{
				"id": "account",
				"label": "RE-ENTER THE ACCOUNT AND TEST IT",
				"hours": 0.35,
				"chance": 0.95,
				"skill": "people",
				"xp": 6,
				"text":
				"You re-enter the password and send a test message. He is delighted. (+6 customer XP)"
			},
			{
				"id": "wifi",
				"label": "CHECK THE WIFI AND REBOOT THE TABLET",
				"hours": 0.2,
				"chance": 0.3,
				"skill": "",
				"xp": 0,
				"text": "The wifi is fine. The email is still broken. He is watching you."
			},
			{
				"id": "later",
				"label": "PROMISE TO CALL HIM BACK",
				"hours": 0.1,
				"chance": 0.0,
				"skill": "",
				"xp": 0,
				"text": "He is not pleased: the owner notices when a visit ends with a promise."
			},
		],
	},
]
var MORE_JOBS: Array = DEFAULT_MORE_JOBS.duplicate(true)
const DEFAULT_EVENTS := {
	"vet":
	{
		"id": "dog",
		"object": "pc",
		"text":
		"A golden retriever trots in, sniffs the front desk PC and lifts a leg. The tower sparks, the screen goes black and the dog looks very pleased.",
		"options":
		[
			{
				"id": "loaner",
				"label": "SET UP A LOANER PC",
				"hours": 1.0,
				"mood": 3,
				"text":
				"You set up the spare PC while the receptionist apologizes to the dog. The vet laughs and says it happens at least once a year."
			},
			{
				"id": "clean",
				"label": "CLEAN IT UP AND TRY TO REVIVE IT",
				"hours": 0.5,
				"mood": 1,
				"text":
				"The motherboard is a goner. You write up a bill and a story you will tell for years."
			},
			{
				"id": "laugh",
				"label": "TAKE A PHOTO FOR THE OFFICE",
				"hours": 0.0,
				"mood": -2,
				"text": "The photo is great. The vet was not amused."
			},
		],
	},
	"dental":
	{
		"id": "patient",
		"object": "cabinet",
		"text":
		"A patient in the chair asks if you can please hurry: the internet is down and the x-ray would not load. The dentist looks at you hopefully.",
		"options":
		[
			{
				"id": "hurry",
				"label": "PRIORITIZE THE X-RAY WORKSTATION",
				"hours": 0.25,
				"mood": 3,
				"text":
				"You get the x-ray running first. The patient gives you a thumbs up from the chair."
			},
			{
				"id": "order",
				"label": "FINISH THE NETWORK FIRST",
				"hours": 0.0,
				"mood": -1,
				"text": "The dentist sighs. The patient reschedules."
			},
		],
	},
	"law":
	{
		"id": "call",
		"object": "cabinet",
		"text":
		"Atty. Spence is on a call with a client and waves you silent. You crouch in the coat closet next to the server rack for twenty minutes.",
		"options":
		[
			{
				"id": "wait",
				"label": "WAIT QUIETLY",
				"hours": 0.35,
				"mood": 3,
				"text": "The attorney mouths a thank you when the call ends."
			},
			{
				"id": "work",
				"label": "KEEP WORKING (QUIETLY)",
				"hours": 0.0,
				"mood": -2,
				"text": "A cable tie snaps loudly in the middle of the call. Oops."
			},
		],
	},
	"arch":
	{
		"id": "plot",
		"object": "printer",
		"text":
		"The plotter just chewed a forty-foot roll of drawings that are due at noon. Erik Lindqvist stares at you, then at the plotter, then at you.",
		"options":
		[
			{
				"id": "free",
				"label": "FREE THE ROLL AND REPRINT",
				"hours": 0.5,
				"mood": 4,
				"text":
				"You pull the paper out in one piece and reprint. The architect nearly hugs you."
			},
			{
				"id": "blame",
				"label": "SAY IT IS A PAPER PROBLEM",
				"hours": 0.0,
				"mood": -3,
				"text": "It was not a paper problem. He knows."
			},
		],
	},
	"realty":
	{
		"id": "showing",
		"object": "pc",
		"text":
		"A showing is in progress: strangers walk through the office while you crawl under a desk to reach the cables.",
		"options":
		[
			{
				"id": "smile",
				"label": "SMILE AND KEEP WORKING",
				"hours": 0.1,
				"mood": 2,
				"text": "Karen introduces you as her IT genius. The prospects nod politely."
			},
			{
				"id": "hide",
				"label": "WAIT UNTIL THEY LEAVE",
				"hours": 0.3,
				"mood": 0,
				"text": "You spend ten minutes under the desk. Your knees will remember this."
			},
		],
	},
	"trailer":
	{
		"id": "breaker",
		"object": "server",
		"text":
		"The space heater trips the breaker and the whole trailer goes dark. The foreman swears. Your laptop is the only thing still on.",
		"options":
		[
			{
				"id": "reset",
				"label": "RESET THE BREAKER AND TELL THEM ABOUT THE HEATER",
				"hours": 0.25,
				"mood": 3,
				"text":
				"The lights come back. The foreman grudgingly moves the heater to another outlet."
			},
			{
				"id": "ups",
				"label": "PLUG THE SERVER INTO A BATTERY BACKUP",
				"hours": 0.3,
				"mood": 2,
				"text":
				"You bring in a small UPS from the van. The server survives the next brownout."
			},
		],
	},
}
var EVENTS: Dictionary = DEFAULT_EVENTS.duplicate(true)
const DEFAULT_STAFF := {
	"dental":
	[
		"Dr. Patel is with a patient. The x-ray machine is that grey box by the chair.",
		"We have a patient in the chair, so please keep the vacuum noises to a minimum.",
		"The coffee is for patients, but I will not tell if you have one."
	],
	"law":
	[
		"Please be quiet in the hall, Atty. Spence is on the phone with a judge.",
		"Everything here is confidential. Do not read anything on the desks.",
		"The copier is cranky. We name it after the opposing counsel."
	],
	"vet":
	[
		"Do not mind the dog. She likes computers. Too much.",
		"If you hear a howl from the back, it is just Otis getting his nails done.",
		"We have a cat in the closet. She is not lost. She is hiding from the beagle."
	],
	"arch":
	[
		"The plotter has opinions today. Good luck.",
		"Mind the model on the table, it took three weeks. And a lot of glue.",
		"If you move my pencil I will know."
	],
	"realty":
	[
		"I have a showing at one, so please be quick. Do you want coffee?",
		"Every house has a story. Most of them involve the plumbing.",
		"Do not mind the lockbox on the desk. It is very important."
	],
	"trailer":
	[
		"Mind the mud. And do not touch the heater. Last guy did and it was a whole thing.",
		"If the siren goes off, walk. Do not run. That is the demolition rule.",
		"The trailer shakes a little when they drop a wall. You get used to it."
	],
}
var STAFF: Dictionary = DEFAULT_STAFF.duplicate(true)
const NPC_SCENE := preload("res://scenes/npc.tscn")
const CAST_AT := {
	"dental":
	{  # [character, x, role] per site type, skin and room (main office, exam room, owner office)
		"a":
		{
			"main": [["client_dentrec_a", 104, "staff"], ["client_hygienist", 190, "staff"]],
			"exam": [["client_dentasst", 150, "staff"]],
			"office": [["expo_atta", 150, "owner"]]
		},
		"b":
		{
			"main": [["client_dentrec_b", 104, "staff"], ["expo_attd", 190, "staff"]],
			"exam": [["client_denthyg_b", 150, "staff"]],
			"office": [["client_dentdoc_b", 150, "owner"]]
		},
	},
	"vet":
	{
		"a":
		{
			"main": [["client_vetrec_a", 104, "staff"], ["expo_vendh", 190, "staff"]],
			"exam": [["client_vettech_a", 150, "staff"]],
			"office": [["client_brandt", 150, "owner"]]
		},
		"b":
		{
			"main": [["client_vetrec_b", 104, "staff"], ["client_vettech_b", 190, "staff"]],
			"exam": [["expo_vendi", 150, "staff"]],
			"office": [["client_vetdoc_b", 150, "owner"]]
		},
	},
	"law":
	{
		"a":
		{
			"main": [["client_paralegal", 170, "staff"], ["expo_attc", 214, "staff"]],
			"office": [["expo_attb", 150, "owner"]]
		},
		"b":
		{
			"main": [["expo_attf", 170, "staff"], ["client_paralegal_b", 214, "staff"]],
			"office": [["client_attorney_b", 150, "owner"]]
		},
	},
	"arch":
	{
		"a":
		{
			"main": [["client_designer_a", 160, "staff"], ["expo_atte", 214, "staff"]],
			"office": [["expo_vendp", 150, "owner"]]
		},
		"b":
		{
			"main": [["client_designer_b", 160, "staff"], ["expo_atta", 214, "staff"]],
			"office": [["client_mina", 150, "owner"]]
		},
	},
	"realty":
	{
		"a":
		{
			"main": [["client_agent_a", 100, "staff"], ["expo_vendp", 230, "staff"]],
			"office": [["client_karen", 150, "owner"]]
		},
		"b":
		{
			"main": [["client_agent_b", 100, "staff"], ["expo_attc", 230, "staff"]],
			"office": [["expo_atte", 150, "owner"]]
		},
	},
	"trailer":
	{
		"a":
		{
			"main": [["expo_vendo", 170, "staff"], ["expo_vendj", 214, "staff"]],
			"office": [["expo_attb", 150, "owner"]]
		},
		"b":
		{"main": [["client_foreman_a", 170, "staff"]], "office": [["expo_atta", 150, "owner"]]},
	},
}
const OWNER_B := {
	"dental": "Dr. Okafor",
	"law": "Atty. Roe",
	"vet": "Dr. Salazar",
	"arch": "Anika Northlight",
	"realty": "Marcus Keystone",
	"trailer": "Rex Blackrock",
}
const DEFAULT_PETS := {
	"dog":
	[
		"You scratch behind the dog's ears. Her tail thumps the floor.",
		"The dog leans against your leg and sighs happily.",
		"A very good dog. She licks your hand."
	],
	"cat":
	[
		"The cat purrs and head-butts your hand.",
		"You pet the cat. She tolerates it. Mostly.",
		"The cat stretches out and shows you her belly. It is a trap, but you pet her anyway."
	],
	"fish":
	[
		"You tap the glass. The fish pretends not to know you.",
		"The orange fish swims to the glass, looks at you and leaves."
	],
	"coffeebar":
	[
		"You pour a cup from the glass pot. It has been on the burner since the spring open house, but it is free.",
		"You fill a mug that says #1 IN SALES (2009). The coffee is hot and tastes like the pot.",
		"You help yourself to the open house coffee. The tip jar says 'for the intern'. You leave a quarter."
	],
	"coffeebar_full":
	[
		"You already have a cup. Greed is a sin, even in real estate.",
		"Your hands are full of coffee. The pot will wait."
	],
	"signin":
	[
		"You sign in. Reason for visit: 'IT'. Under it a previous visitor wrote 'Dave - plumbing - yes'.",
		"The pen is on a string and the string is shorter than your arm. You sign sideways.",
		"NAME / COMPANY / TIME IN / REASON. The last line says 'Karen - Karen - 9:02 - I am the owner'."
	],
	"recep":
	[
		"The receptionist: 'Are you here about the plotter? Please say you are here about the plotter.'",
		"The receptionist: 'The principals are in a charrette until five. Can I get you a coffee?'",
		"A roll of drawings on the desk has a sticky note: DO NOT TOUCH. NOT EVEN YOU, STEVE."
	],
}
var PETS: Dictionary = DEFAULT_PETS.duplicate(true)

var enabled := false  # set by the title menu, so older tests are not disturbed by onsite tickets
var visit_kind := ""  # "" (a plain visit or a job), "qbr" (a business review) or "pitch" (a prospect)
var visit_prospect := false  # the prospect's own office (the b skin)
var visit_findings := 0
var _inspected := {}
var _met := false
var _missed: Array = []
var _logged_day := {}
var _prev_msp := true
var _back_min := 45
var _prev_scale := 1.0
var active := false  # you are at a client site
var busy := false  # a visit is in progress (the day cannot end)
var ticket_id := 0
var client := -1
var job: Dictionary = {}
var done := false
var visits := 0
var fixed_count := 0
var pets := 0
var _pet_energy := 0
var _pet_first := true
var _event_done := false
var _roll_day := -1
var _spawn_at := -1.0


func _ready() -> void:
	Campaign.day_started.connect(_on_day)


func reset() -> void:
	active = false
	busy = false
	ticket_id = 0
	client = -1
	job = {}
	done = false
	visits = 0
	fixed_count = 0
	pets = 0
	_pet_energy = 0
	_pet_first = true
	_missed = []
	_logged_day = {}
	_inspected = {}
	visit_kind = ""
	visit_prospect = false
	_met = false
	_event_done = false
	_roll_day = -1
	_spawn_at = -1.0


func to_dict() -> Dictionary:
	return {"visits": visits, "fixed": fixed_count, "pets": pets, "missed": _missed}


func from_dict(data: Dictionary) -> void:
	reset()
	visits = int(data.get("visits", 0))
	fixed_count = int(data.get("fixed", 0))
	pets = int(data.get("pets", 0))
	_missed = data.get("missed", [])


func is_tech() -> bool:
	return Campaign.active and Campaign.mode == "tech"


func site_scene(client_index: int, prospect := false) -> String:
	var site: Dictionary = SITES.get(client_index, {})
	if site.is_empty():
		return ""
	return "site_%s_%s" % [str(site.type), "b" if prospect else str(site.skin)]


func site_type(client_index: int) -> String:
	return str(SITES.get(client_index, {}).get("type", ""))


func has_site(client_index: int) -> bool:
	return SITES.has(client_index)


# ---- onsite tickets turn up now and then
func _on_day(day: int) -> void:
	_spawn_at = -1.0
	_pet_energy = 0
	_missed_follow_up()
	if not enabled or not is_tech() or day < 3 or Game.title_mode:
		return
	if day == 3:
		Msp.mail(Story.MANAGER, "Onsite visits", str(TEXT.intro_mail))
	var guaranteed := day == 6 or day == 11 or day == 15
	var skip := [7, 9, 10, 12, 13, 16, 17, 18, 20].has(day)
	for t in Msp.tickets:
		if t.status != "Closed" and is_onsite(t):
			skip = true  # one onsite problem at a time
	if guaranteed or (not skip and randf() < 0.5):
		_spawn_at = 10.0 + randf() * 4.0
		if [5, 6, 10, 11, 15].has(day):
			_spawn_at = 9.6 + randf() * 1.6  # before the all-hands and the evening outing


func _process(_delta: float) -> void:
	if _spawn_at < 0.0 or not is_tech() or Game.title_mode or World.time_scale <= 0.0 or active:
		return
	if World.clock >= _spawn_at and World.clock < World.DAY_END - 1.0:
		_spawn_at = -1.0
		create_job()


func create_job(client_index := -1, job_id := "") -> Dictionary:
	var options := []
	for c in Sales.active:
		if SITES.has(int(c)) and Sales.takes_tickets(int(c)):
			options.append(int(c))
	if client_index < 0:
		if options.is_empty():
			return {}
		client_index = options[randi() % options.size()]
	var type := site_type(client_index)
	var pool := []
	var here: Array = OBJECTS.get(type, [])
	for j in JOBS + MORE_JOBS:
		if (job_id == "" or str(j.id) == job_id) and here.has(str(j.object)):
			pool.append(j)
	if pool.is_empty() or type == "":
		return {}
	var pick: Dictionary = pool[randi() % pool.size()]
	var prob := {
		"summary": str(pick.summary),
		"fix": "onsite_" + str(pick.id),
		"pri": int(pick.pri),
		"body": str(pick.body),
		"server": str(pick.object) == "server",
	}
	var made := Msp.create_problem(client_index, prob, "phone")
	if not made.is_empty() and Campaign.active:
		# the clock is paused on the road, but the client still expects a visit to be possible:
		# add the round trip (plus some work) to the SLA, in the same units as `_away`
		var extra := float(drive_minutes(client_index) * 2 + 30) / 60.0 * 60.0
		extra *= World.day_len / 600.0
		made.sla_total = float(made.sla_total) + extra
		made.sla_left = float(made.sla_left) + extra
	return made


func is_onsite(t: Dictionary) -> bool:
	return str(t.get("fix", "")).begins_with("onsite_")


func job_for(t: Dictionary) -> Dictionary:
	var id := str(t.get("fix", "")).trim_prefix("onsite_")
	for j in JOBS + MORE_JOBS:
		if str(j.id) == id:
			return j
	return {}


# ---- drive times: each site has its usual drive, and traffic changes it a little (never under 10 minutes)
func drive_minutes(c: int) -> int:
	return int(DRIVE_MINUTES.get(c, DEFAULT_DRIVE))


# the roads are busier at the morning rush, over lunch and especially in the evening rush
func traffic_factor(hour := -1.0) -> float:
	var h := World.clock if hour < 0.0 else hour
	if h < 9.5:
		return 1.35
	if h >= 16.0:
		return 1.45
	if h >= 11.5 and h < 13.5:
		return 1.2
	return 1.0


func traffic_label(hour := -1.0) -> String:
	var f := traffic_factor(hour)
	if f >= 1.4:
		return "EVENING RUSH HOUR" if (World.clock if hour < 0.0 else hour) >= 16.0 else "RUSH HOUR"
	if f >= 1.3:
		return "RUSH HOUR"
	if f > 1.0:
		return "LUNCH TRAFFIC"
	return "CLEAR ROADS"


# what the trip should take right now (shown on the cards)
# how many open tickets would run out of time during a trip of this many minutes (there and back, plus some work)
func at_risk(minutes: int, except_id := 0) -> int:
	var hours := float(minutes * 2 + 30) / 60.0
	var n := 0
	var scale := World.day_len / 600.0
	for t in Msp.tickets:
		if (
			t.status != "Closed"
			and int(t.id) != except_id
			and float(t.sla_left) - hours * SLA_PER_HOUR * scale <= float(t.sla_total) * 0.4
		):
			n += 1
	return n


func _risk_text(c: int, except_id := 0) -> String:
	var n := at_risk(estimate_minutes(c), except_id) if Campaign.active else 0
	return (
		""
		if n == 0
		else " %d of your open tickets will be close to breaching by the time you are back." % n
	)


func estimate_minutes(c: int) -> int:
	return maxi(10, int(round(float(drive_minutes(c)) * traffic_factor() / 5.0)) * 5)


func _trip_minutes(c: int) -> int:
	var base := float(drive_minutes(c)) * traffic_factor()
	return maxi(10, int(round(base * randf_range(0.9, 1.15) / 5.0)) * 5)


# ---- the front door: choose where to drive (the ticket you are working comes first)
func focus_ticket() -> Dictionary:
	var sel := Msp.ticket(Computer.psa_sel)
	if (
		not sel.is_empty()
		and sel.status != "Closed"
		and is_onsite(sel)
		and has_site(int(sel.client))
	):
		return sel
	for t in Msp.tickets:
		if t.status != "Closed" and is_onsite(t) and has_site(int(t.client)):
			return t
	return {}


func door_clients() -> Array:
	var list := []
	for c in SITES:
		var mine := Sales.active.has(int(c)) or not Campaign.active
		for t in Msp.tickets:
			if int(t.client) == int(c) and t.status != "Closed" and is_onsite(t):
				mine = true
		if mine:
			list.append(int(c))
	list.sort()
	var focus := focus_ticket()
	if not focus.is_empty() and list.has(int(focus.client)):
		list.erase(int(focus.client))
		list.push_front(int(focus.client))
	return list


func offer_door() -> void:
	if active or Cards.is_open or Game.ui_open:
		return
	_door_page(door_clients(), 0)


func _door_page(list: Array, page: int) -> void:
	var per := 2
	var focus := focus_ticket()
	var text := str(TEXT.door_title) + " " + traffic_label() + "."
	if not focus.is_empty() and page == 0:
		text = str(TEXT.door_ticket) % [int(focus.id), str(Msp.CLIENTS[int(focus.client)].name)]
		text += " " + traffic_label() + "."
	var options := []
	for c in list.slice(page * per, page * per + per):
		var label := "TO " + str(Msp.CLIENTS[int(c)].name).to_upper()
		label += " (%d MIN" % estimate_minutes(int(c))
		if not focus.is_empty() and int(focus.client) == int(c):
			label += ", TICKET #%d" % int(focus.id)
		label += ")"
		options.append({"label": label.left(44), "id": "c%d" % int(c)})
	if (page + 1) * per < list.size():
		options.append({"label": "MORE SITES...", "id": "more"})
	elif page > 0:
		options.append({"label": "BACK TO THE FIRST PAGE", "id": "back"})
	options.append({"label": "STAY HERE", "id": "leave"})
	Cards.ask("Front door", text, options, func(id: String) -> void: _door_pick(id, list, page))


func _door_pick(id: String, list: Array, page: int) -> void:
	if id == "more":
		_door_page(list, page + 1)
	elif id == "back":
		_door_page(list, 0)
	elif id.begins_with("c"):
		_go_site(int(id.substr(1)))


func _go_site(c: int) -> void:
	var focus := focus_ticket()
	var ticket := {}
	if not focus.is_empty() and int(focus.client) == c:
		ticket = focus
	else:
		for t in Msp.tickets:
			if int(t.client) == c and t.status != "Closed" and is_onsite(t):
				ticket = t
				break
	if not ticket.is_empty():
		offer(int(ticket.id))
		return
	Cards.ask(
		"Dispatch",
		_visit_text(c) + _risk_text(c),
		[
			{"label": str(TEXT.go), "id": "go"},
			{"label": str(TEXT.later), "id": "later"},
		],
		func(pick: String) -> void: _free_visit(pick, c)
	)


func _free_visit(pick: String, c: int) -> void:
	if pick != "go":
		return
	if Computer.is_open:
		Computer.close()
	ticket_id = 0
	client = c
	job = {}
	done = false
	_event_done = false
	_begin_trip()
	var mins := _trip_minutes(client)
	_back_min = _trip_minutes(client)
	_away(float(mins) / 60.0)
	active = true
	_pet_first = true
	Game.go(site_scene(client, visit_prospect), "from_van")
	Hints.toast(
		(
			str(TEXT.arrive_visit if visit_kind != "" else TEXT.arrive)
			% [str(Msp.CLIENTS[client].name), mins]
		),
		5.0
	)


# a business review (qbr) or a pitch to a prospect, at their own office
func start_visit(c: int, kind: String) -> void:
	if active or not has_site(c):
		return
	visit_kind = kind
	visit_prospect = kind == "pitch"
	_free_visit("go", c)


# freeze the office while you are away, remembering how it was (Free Play keeps its own settings)
func _begin_trip() -> void:
	_inspected = {}
	_met = false
	visit_findings = 0
	busy = true
	visits += 1
	_prev_msp = Msp.enabled
	_prev_scale = World.time_scale
	Msp.enabled = false
	World.time_scale = 0.0


# ---- go there
func offer(id: int) -> void:
	var t := Msp.ticket(id)
	if t.is_empty() or not is_onsite(t) or active or Cards.is_open:
		return
	if t.status == "Closed":
		Hints.toast("THAT TICKET IS ALREADY CLOSED.", 2.5)
		return
	if not has_site(int(t.client)):
		Hints.toast("NO SITE FOR THIS CLIENT YET.", 2.5)
		return
	Cards.ask(
		"Dispatch",
		(
			(
				str(TEXT.offer)
				% [str(Msp.CLIENTS[int(t.client)].name), estimate_minutes(int(t.client))]
			)
			+ _risk_text(int(t.client), id)
		),
		[
			{"label": str(TEXT.go), "id": "go"},
			{"label": str(TEXT.later), "id": "later"},
		],
		func(pick: String) -> void: _offer_answer(pick, id)
	)


func _offer_answer(pick: String, id: int) -> void:
	if pick == "go":
		_depart(id)


func _away(hours: float, except_id := 0) -> void:
	if not Campaign.active:
		return  # Free Play: the trip takes no time
	World.clock = minf(23.0, World.clock + hours)
	var scale := World.day_len / 600.0
	for t in Msp.tickets:
		if t.status != "Closed" and int(t.id) != except_id:
			t.sla_left = maxf(float(t.sla_total) * 0.35, t.sla_left - hours * SLA_PER_HOUR * scale)
	Shift.add_energy(-2.0 * hours)


func _depart(id: int) -> void:
	var t := Msp.ticket(id)
	if t.is_empty():
		return
	if Computer.is_open:
		Computer.close()
	ticket_id = id
	client = int(t.client)
	job = job_for(t)
	done = false
	_event_done = false
	_begin_trip()
	Msp.set_status(id, "In Progress")
	Msp.add_note(id, "Technician dispatched onsite.")
	var mins := _trip_minutes(client)
	_back_min = _trip_minutes(client)
	_away(float(mins) / 60.0, id)
	active = true
	_pet_first = true
	Game.go(site_scene(client), "from_van")
	Hints.toast(str(TEXT.arrive) % [str(Msp.CLIENTS[client].name), mins], 5.0)


# ---- at the site (E on the equipment, see fx kinds onsite_*)
func interact(obj: String) -> void:
	if Cards.is_open or Game.ui_open:
		return
	if obj == "door":
		_leave()
		return
	if obj in ["pc", "exam", "vip"]:
		_open_pc(obj)
		return
	if obj in ["dog", "cat", "fish"]:
		_pet(obj)
		return
	if obj in ["coffeebar", "signin", "recep"]:
		_site_line(obj)
		return
	if obj == "owner" and visit_kind != "" and not _met:
		_meeting()
		return
	if obj == "owner":
		var c := _site_client()
		var who := _owner_name(c)
		var greetings := [
			"Thank you for coming out. Let me know if you need anything.",
			"Come in, come in. Excuse the mess, it is a busy week.",
			"I appreciate you stopping by. Most IT people only call.",
		]
		Cards.ask(
			who,
			"%s: %s" % [who, str(greetings[randi() % greetings.size()])],
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
		return
	if obj == "staff":
		var lines: Array = STAFF.get(site_type(client), [str(TEXT.staff)])
		Cards.ask(
			"Staff",
			str(lines[randi() % lines.size()]),
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
		return
	if obj == "printer" and (not active or job.is_empty() or done or str(job.object) != "printer"):
		_printer_practice()
		return
	if not active:
		Hints.toast(str(TEXT.no_job), 2.0)
		return
	if job.is_empty() or done or obj != str(job.object):
		inspect(obj)
		return
	_work()


# the client's own computer: their desktop, their software, their mail. Your tools are in the TOOLS window.
func _scene_name() -> String:
	var sc := get_tree().current_scene
	return "" if sc == null else sc.scene_file_path.get_file().get_basename()


func _site_client() -> int:
	if client >= 0:
		return client
	var type := _scene_name().split("_")[1] if _scene_name().begins_with("site_") else ""
	for c in SITES:
		if str(SITES[c].type) == type:
			return int(c)
	return 0


# the prospect's office (the b skin) is the lead's own company: the sign, the PC and the owner use
# the client's real name and contact, so the lead card, the sign and the speaker all agree
func _host_prefix(c: int, _skin: String) -> String:
	return str(Msp.CLIENTS[c].short)


func _owner_name(c: int) -> String:
	return str(Msp.CLIENTS[c].contact)


func _open_pc(obj: String) -> void:
	var c := _site_client()
	var type := site_type(c)
	var scene := _scene_name()
	var skin := "b" if scene.ends_with("_b") else "a"
	var apps: Dictionary = SITE_APPS.get(type, {})
	var cols: Array = SKIN_COLORS.get(type, {}).get(skin, ["#CFE8EE", "#2E9AB8"])
	var mails := []
	if active and not job.is_empty():
		var t := Msp.ticket(ticket_id)
		if not t.is_empty():
			mails.append([str(Msp.CLIENTS[c].contact), "HELP: " + str(t.summary)])
	for mail in apps.get("mails", []):
		mails.append(mail)
	var info := {
		"name":
		str(Msp.CLIENTS[c].name).to_upper(),
		"type": type,
		"obj": obj,
		"wall": cols[0],
		"accent": cols[1],
		"pc": "%s-%s" % [_host_prefix(c, skin), str(PCS.get(obj, "PC1"))],
		"user": _owner_name(c),
		"app": str(apps.get("app", "PRACTICE")),
		"title": str(apps.get("title", "")),
		"rows": apps.get("rows", []),
		"mails": mails,
		"net":
		(
			"NO NETWORK CONNECTION"
			if active and not done and not job.is_empty() and str(job.object) == "cabinet"
			else "CONNECTED"
		),
	}
	Computer.open_site(info)


func job_here(obj: String) -> bool:
	return active and not job.is_empty() and not done and str(job.object) == obj


# the TOOLS window: DIAGNOSE AND FIX
func pc_diagnose(obj: String) -> void:
	if not active or job.is_empty() or done or str(job.object) != obj:
		Hints.toast(str(TEXT.nothing), 2.5)
		return
	_work()


# ---- walk-around: sales people and owners notice things while they visit, and can log them as tickets
func inspect(obj: String) -> void:
	if _inspected.has(obj):
		Hints.toast(str(TEXT.inspected), 2.0)
		return
	_inspected[obj] = true
	var pool: Array = FINDINGS.get(obj, [])
	var chance := 0.7 if visit_kind != "" else 0.3
	if pool.is_empty() or randf() > chance:
		Hints.toast(str(TEXT.fine), 2.0)
		return
	_found(pool[randi() % pool.size()])


func _found(f: Dictionary) -> void:
	var options := [{"label": "LOG A TICKET", "id": "ticket"}]
	if Owner.active() and str(f.get("project", "")) != "":
		options.append({"label": "SELL IT AS A PROJECT", "id": "project"})
	if visit_prospect:
		options = [{"label": "TELL THEM ABOUT IT (BUILDS YOUR PITCH)", "id": "tell"}]
	options.append({"label": "MAKE A NOTE FOR LATER", "id": "note"})
	Cards.ask(
		"You notice something", str(f.text), options, func(id: String) -> void: _found_answer(f, id)
	)


func _found_answer(f: Dictionary, id: String) -> void:
	var c := _site_client()
	visit_findings += 1
	if id in ["ticket", "project"]:
		if int(_logged_day.get(c, -1)) == Campaign.day:
			Hints.toast(str(TEXT.cooldown), 3.0)
			return
		_logged_day[c] = Campaign.day
	if id == "tell":
		Hints.toast("YOU MENTION IT. THEY LOOK IMPRESSED.", 3.0)
	elif id == "ticket":
		if Campaign.active:
			var prob := {
				"summary": str(f.summary), "fix": str(f.fix), "pri": int(f.pri), "body": str(f.body)
			}
			Msp.create_problem(c, prob, "walk-around")
			Sales.adjust(c, 2)
			Hints.toast(str(TEXT.found_ticket), 3.5)
		else:
			Hints.toast(str(TEXT.found_nocampaign), 3.0)
	elif id == "project":
		Projects.offer_project(c, str(f.project))
		Sales.adjust(c, 1)
		Hints.toast(str(TEXT.found_project), 3.5)
	else:
		if Campaign.active:
			_missed.append({"client": c, "f": f})
		Hints.toast(str(TEXT.found_note), 3.0)


# something you saw and did not log may break by itself
func _missed_follow_up() -> void:
	var keep: Array = []
	for entry in _missed:
		if randf() < 0.25 and Campaign.active and Msp.enabled:
			var f: Dictionary = entry.f
			var prob := {
				"summary": str(f.summary),
				"fix": str(f.fix),
				"pri": 2,
				"body": str(TEXT.missed_mail) + " - %s"
			}
			Msp.create_problem(int(entry.client), prob, "email")
			Sales.adjust(int(entry.client), -2)
		else:
			keep.append(entry)
	_missed = keep


# ---- the meeting with the owner (a business review or a pitch)
func _meeting() -> void:
	var mt: Dictionary = MEETINGS.get(visit_kind, {})
	if mt.is_empty():
		return
	var options := []
	for o in mt.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		_owner_name(_site_client()),
		str(mt.text),
		options,
		func(id: String) -> void: _meeting_answer(id)
	)


func _meeting_answer(id: String) -> void:
	var c := _site_client()
	var mt: Dictionary = MEETINGS.get(visit_kind, {})
	var text := ""
	for o in mt.get("options", []):
		if str(o.id) == id:
			text = str(o.text)
	_met = true
	if visit_kind == "qbr":
		match id:
			"numbers":
				Sales.adjust(c, 6)
				if randf() < 0.4:
					Owner.apply({"fee_boost": {"client": c, "mult": 1.1}})
					text += " " + str(TEXT.qbr_fee)
			"listen":
				Sales.adjust(c, 10)
				var pool: Array = FINDINGS.get(["cabinet", "server", "pc"][randi() % 3], [])
				if not pool.is_empty():
					Cards.ask(
						"The owner",
						text,
						[{"label": "GO ON", "id": "ok"}],
						func(_id: String) -> void: _found(pool[randi() % pool.size()])
					)
					return
			_:
				Sales.adjust(c, 4)
				Projects._queue.append(
					{
						"kind": "service",
						"client": c,
						"id": "patching" if Projects.has_service(c, "backup") else "backup"
					}
				)
	elif visit_kind == "pitch":
		var odds := 0.55
		if id == "pain":
			odds = 0.8 if visit_findings > 0 else 0.5
		elif id == "moon":
			odds = 0.45
		if randf() < odds:
			Sales.sign_client(c)
			if id == "moon":
				Sales.adjust(c, -8)
			text += " " + str(TEXT.pitch_signed)
		else:
			text += " " + str(TEXT.pitch_think)
	Cards.ask(_owner_name(c), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


# the realty coffee bar (a cup of coffee), the sign-in clipboard and the architects' reception desk (a line, no game effect)
func _site_line(kind: String) -> void:
	var p := get_tree().current_scene.get_node_or_null("Actors/Player")
	var key := kind
	if kind == "coffeebar" and p != null and str(p.held) == "coffee":
		key = "coffeebar_full"
	var lines: Array = PETS.get(key, [])
	if lines.is_empty():
		return
	Hints.toast(str(lines[randi() % lines.size()]), 3.0)
	if key == "coffeebar":
		get_tree().create_timer(1.0).timeout.connect(_pour.bind(p))


func _pour(p: Node) -> void:
	if is_instance_valid(p) and p.has_method("give"):
		p.give("coffee")


# you can always pet the animals (the rules)
func _pet(kind: String) -> void:
	var lines: Array = PETS.get(kind, [])
	if lines.is_empty():
		return
	pets += 1
	Career.add("pets")
	Hints.toast(str(lines[randi() % lines.size()]), 3.0)
	var p := get_tree().current_scene.get_node_or_null("Actors/Player")
	if p != null and p.has_method("start_emote") and kind != "fish":
		p.start_emote(
			"reach", 2.8, p.global_position.x + (10.0 if p.facing == "right" else -10.0), "heart"
		)
	if Campaign.active and Shift.active() and _pet_energy < 3:
		_pet_energy += 1
		Shift.add_energy(1.0)
	if active and client >= 0 and _pet_first:
		_pet_first = false
		Sales.adjust(client, 1)


func _work() -> void:
	var options := []
	for o in job.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		"Onsite: " + str(Msp.CLIENTS[client].name),
		str(job.intro),
		options,
		func(id: String) -> void: _chose(id)
	)


func _chose(id: String) -> void:
	var opt: Dictionary = {}
	for o in job.options:
		if str(o.id) == id:
			opt = o
	if str(opt.get("game", "")).begins_with("printer"):
		PrinterGame.start(
			func(stars: int) -> void: _printer_done(stars),
			_printer_model(str(opt.get("game", ""))),
			{"onsite": true}
		)
		return
	_away(float(opt.hours), ticket_id)
	var ok := randf() < float(opt.chance)
	var text := str(opt.text)
	if float(opt.chance) <= 0.0:
		Sales.adjust(client, -4 if bool(job.get("vip", false)) else -2)
	if ok:
		if str(opt.skill) != "":
			Skills.add_xp(str(opt.skill), int(opt.xp))
		done = true
	Cards.ask("Onsite", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: _after(ok))


# the printer mini-game finished: its stars decide how it went
func _printer_done(stars: int) -> void:
	if stars < 0:
		_work()  # backed out before starting: nothing happened
		return
	_away(maxf(0.25, 1.1 - 0.25 * float(stars)), ticket_id)
	var ok := stars >= 1
	if ok:
		Skills.add_xp("servers", 4 * stars)
		done = true
	Cards.ask(
		"Onsite",
		str(TEXT.get("printer_stars%d" % stars, "")),
		[{"label": "OK", "id": "ok"}],
		func(_id: String) -> void: _after(ok)
	)


# which printer model fights back: the job's game field can force one ("printer:inkjet"), else the site decides
# (architects: plotter, dentists: receipt or laser, law: multifunction, vets: inkjet, realty: laser or dot matrix,
# the trailers: dot matrix); the either-or sites roll once per client and day from the printer stream
func _printer_model(game := "printer") -> String:
	var forced := game.get_slice(":", 1) if game.contains(":") else ""
	if PrinterGame.MODELS.has(forced):
		return forced
	var either := ""
	match site_type(client):
		"arch":
			return "plotter"
		"law":
			return "mfp"
		"vet":
			return "inkjet"
		"trailer":
			return "dot"
		"dental":
			either = "receipt"
		"realty":
			either = "dot"
		_:
			return "laser"
	var r := Difficulty.rng_for("printer.model", client * 100 + Campaign.day)
	return either if r.randi() % 2 == 0 else "laser"


func _printer_practice() -> void:
	var options := [{"label": "OPEN IT UP AND FIGHT IT", "id": "go"}]
	if active:
		options.append({"label": str(TEXT.audit_button), "id": "look"})
	options.append({"label": "LEAVE IT ALONE", "id": "no"})
	Cards.ask(
		"Printer",
		str(TEXT.printer_practice),
		options,
		func(pick: String) -> void: _practice_answer(pick)
	)


func _practice_answer(pick: String) -> void:
	if pick == "look":
		inspect("printer")
	elif pick == "go":
		PrinterGame.start(
			func(stars: int) -> void:
				if stars >= 0:  # -1 = backed out on the intro page
					Hints.toast(str(TEXT.printer_practice_done) % stars, 3.0),
			_printer_model(),
			{"practice": true}
		)


func _after(ok: bool) -> void:
	if ok:
		_finish_job()
		return
	if not _event_done:
		_maybe_event()


# a mishap only happens where its text makes sense: the dog and the showing need a PC job,
# the breaker and the closet call need the closet, the plotter needs the printer
func event_fits(ev: Dictionary) -> bool:
	var groups := {
		"pc": ["pc", "exam", "vip", "xray"],
		"cabinet": ["cabinet", "server"],
		"server": ["cabinet", "server"],
		"printer": ["printer"],
	}
	var want := str(ev.get("object", ""))
	if want == "" or job.is_empty() or not groups.has(want):
		return true
	return (groups[want] as Array).has(str(job.get("object", "")))


# a random mishap at this kind of site (once per visit, 55%)
func _maybe_event() -> void:
	_event_done = true
	var ev: Dictionary = EVENTS.get(site_type(client), {})
	if ev.is_empty() or not event_fits(ev) or randf() > 0.55:
		return
	var options := []
	for o in ev.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		"Onsite: " + str(Msp.CLIENTS[client].name),
		str(ev.text),
		options,
		func(id: String) -> void: _event_answer(ev, id)
	)


func _event_answer(ev: Dictionary, id: String) -> void:
	var text := ""
	for o in ev.options:
		if str(o.id) == id:
			_away(float(o.hours), ticket_id)
			Sales.adjust(client, int(o.mood))
			text = str(o.text)
	Cards.ask("Onsite", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _finish_job() -> void:
	var t := Msp.ticket(ticket_id)
	if t.is_empty():
		return
	t.fix_done = true
	for ep in Msp.endpoints:
		if ep.name == t.endpoint:
			ep.problem = ""
	Msp.add_note(ticket_id, "Fixed onsite.")
	fixed_count += 1
	Msp.close_ticket(ticket_id)
	if not _event_done:
		_maybe_event()
	Hints.toast(str(TEXT.fixed), 3.0)


func _leave() -> void:
	if not active:
		return
	if not done and not job.is_empty():
		Cards.ask(
			"Onsite",
			str(TEXT.leave_ask),
			[
				{"label": str(TEXT.stay), "id": "leave"},
				{"label": str(TEXT.leave), "id": "go"},
			],
			func(id: String) -> void: _leave_answer(id, true)
		)
		return
	if visit_kind != "" and not _met:
		Cards.ask(
			"Onsite",
			str(TEXT.leave_unmet),
			[
				{"label": "STAY AND MEET THE OWNER", "id": "leave"},
				{"label": "LEAVE WITHOUT MEETING THEM", "id": "go"},
			],
			func(id: String) -> void: _leave_answer(id, false)
		)
		return
	_go_home(false)


func _leave_answer(id: String, dropped: bool) -> void:
	if id == "go":
		_go_home(dropped)


func _go_home(dropped: bool) -> void:
	if dropped:
		Sales.adjust(client, -6)
		Msp.add_note(ticket_id, "Technician left before the problem was fixed.")
		Hints.toast(str(TEXT.dropped), 3.0)
	_back_min = _trip_minutes(client)
	_away(float(_back_min) / 60.0)
	active = false
	busy = false
	visit_kind = ""
	visit_prospect = false
	Msp.enabled = _prev_msp
	World.time_scale = _prev_scale
	Game.go("main_floor", "from_outside")
	if Campaign.active:
		Hints.toast(str(TEXT.home) % _back_min, 4.0)
	else:  # free play has no queue to grow
		Hints.toast("You drive back to the office (%d minutes)." % _back_min, 4.0)


# the drive card: free play has no queue, so it does not mention one
func _visit_text(c: int) -> String:
	var name := str(Msp.CLIENTS[c].name)
	if not Campaign.active:
		return "Drive to %s? About %d minutes each way." % [name, estimate_minutes(c)]
	return str(TEXT.visit_confirm) % [name, estimate_minutes(c)]


# one staff member stands around at every client site (E: a line about the place)
func populate(stage: Node) -> void:
	var scene := stage.scene_file_path.get_file().get_basename()
	if not scene.begins_with("site_") or Game.title_mode:
		return
	var parts := scene.split("_")
	var kind := parts[1]
	var skin := parts[parts.size() - 1]
	var room := "main" if parts.size() == 3 else parts[2]
	var people: Array = CAST_AT.get(kind, {}).get(skin, {}).get(room, [])
	var x0 := float(World.DATA.SCENES[scene].x0)
	for entry in people:
		var npc: Node = NPC_SCENE.instantiate()
		npc.character = str(entry[0])
		npc.facing = "left" if int(entry[1]) > 120 else "right"
		npc.role = "site:" + str(entry[2])
		npc.routine = PackedStringArray(
			["wait:7", "say:2"] if str(entry[2]) == "staff" else ["wait:7", "talk:3"]
		)
		npc.position = Vector2(x0 + float(entry[1]), 118.0)
		var zone := RectangleShape2D.new()  # a narrower talk zone than the cast has, so doors and equipment next to them stay easy to hit
		zone.size = Vector2(30, 56)
		npc.get_node("Shape").shape = zone
		stage.get_node("Actors").add_child(npc)
