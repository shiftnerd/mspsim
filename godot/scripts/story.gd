extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# The tech campaign's script: what happens on each day (mails, texts, set-pieces) at a time of day.
# Events are data in DAYS; `kind` is mail / text / backup_break (silent) / ransomware.
# Plan (the rest is still to build): day 3 the easy Adobe Reader print ticket (built), day 4
# desktop install + migration (built: Msp.start_project, the RMM PROJECT tab), day 10 a
# client's network rack falls off the wall, day 12 server migration, day 13 the 24x7 email
# outage and vendor call, day 16 a network install, day 20 the yearly review with the manager.

const RANSOM_CLIENT := 3  # Hoot and Holler Law
const MANAGER := "Morgan Reyes - Manager"
const Incident := preload("res://scripts/incident.gd")  # R37: Morgan's post-incident reviews
const DEFAULT_POSTMORTEMS := {
	"ransom":
	{
		"title": "RANSOMWARE REVIEW",
		"skill": "security",
		"intro":
		"{me}, got half an hour? Before the ransomware week turns into a story we tell badly, let us write down what happened: the timeline, the real cause, what we change. It is blameless, we look at the process and not at a person. Or we can skip it.",
		"go": "SIT DOWN WITH MORGAN",
		"skip": "SKIP IT, TOO BUSY",
		"skipped": "Morgan nods and puts the marker back. 'We will see how it goes,' she says. It sounds like she thinks it will happen again.",
		"cause_q": "Morgan draws a timeline on the whiteboard. The files were encrypted at 10:30. The backup alert was in the queue for two days. What was the root cause?",
		"causes":
		[
			{
				"id": "backups",
				"label": "THE BACKUP ALERT SAT UNREAD AND NOBODY TESTED A RESTORE",
				"right": true,
				"note": "Morgan nods. The alert was real and the process had no owner. That is a system problem we can fix."
			},
			{
				"id": "person",
				"label": "THE STAFF CLICKED A BAD ATTACHMENT",
				"right": false,
				"note": "Morgan frowns. People click things. A process that needs everyone to be perfect is the problem. We do not put names on the board."
			},
			{
				"id": "luck",
				"label": "BAD LUCK, IT HAPPENS TO EVERYONE",
				"right": false,
				"note": "Morgan sighs. Luck was part of it, but luck is not an action item."
			},
		],
		"items_q": "Pick the first thing we change. Small and real beats big and never.",
		"more_q": "Good. One more, or is that enough for now?",
		"enough": "THAT IS ENOUGH FOR NOW",
		"items":
		[
			{
				"id": "backup_verify",
				"eff": "backups",
				"label": "A WEEKLY RESTORE TEST FOR EVERY BACKUP",
				"note": "Every Friday a tech restores one real file from each client and signs the sheet."
			},
			{
				"id": "runbook",
				"eff": "fixes",
				"label": "A ONE PAGE RANSOMWARE RUNBOOK",
				"note": "Isolate the machine, do not pay yet, check the backup, call the client. It goes in the vault."
			},
			{
				"id": "patch_policy",
				"eff": "pace",
				"label": "A PATCH POLICY: SECOND TUESDAY, NO EXCEPTIONS",
				"note": "Updates go out on a schedule instead of whenever someone remembers."
			},
			{
				"id": "drill",
				"eff": "xp",
				"label": "A FIRE DRILL: CUT A MACHINE OFF THE NETWORK",
				"note": "You time it. Four minutes the first run, ninety seconds the second."
			},
		],
		"done": "Morgan photographs the whiteboard and mails the list to the owners. It is short on purpose, and it has names next to every line, for next time."
	},
	"rack":
	{
		"title": "RACK REVIEW",
		"skill": "networking",
		"intro":
		"{me}, the fallen rack at Gnarly Gnomes is already a lunch story. It is also a pattern: plywood walls, no labels, no photos. Fifteen minutes, blameless, and we write it down. Or we skip it.",
		"go": "SIT DOWN WITH MORGAN",
		"skip": "SKIP IT, TOO BUSY",
		"skipped": "Morgan shrugs. 'The next wall is plywood too,' she says. 'I just hope someone tells me before it moves.'",
		"cause_q": "Morgan pulls up the photos you took. A rack bolted to plywood with drywall anchors, a fan in the closet and thirty unlabeled cables. What was the root cause?",
		"causes":
		[
			{
				"id": "mount",
				"label": "NOBODY CHECKS THE WALL OR THE LABELS WHEN WE INSTALL A RACK",
				"right": true,
				"note": "Morgan nods. We have no site checklist, so a good install and a bad one look the same on the invoice."
			},
			{
				"id": "person",
				"label": "WHOEVER INSTALLED IT THE FIRST TIME DID A BAD JOB",
				"right": false,
				"note": "Morgan shakes her head. We do not know who, and we do not need to. The question is why our process let it pass."
			},
			{
				"id": "client",
				"label": "THE CLIENT HUNG IT THERE, IT IS THEIR PROBLEM",
				"right": false,
				"note": "Morgan raises an eyebrow. It is their wall. It is also our rack in our report."
			},
		],
		"items_q": "What do we change? Pick the first.",
		"more_q": "Good. One more, or is that enough for now?",
		"enough": "THAT IS ENOUGH FOR NOW",
		"items":
		[
			{
				"id": "cable_labels",
				"eff": "fixes",
				"label": "LABEL CABLES AND PHOTOGRAPH EVERY RACK ON INSTALL",
				"note": "A photo and a label now means the next tech does not have to guess."
			},
			{
				"id": "anchor_check",
				"eff": "pace",
				"label": "ADD A WALL AND RACK CHECK TO EVERY SITE VISIT",
				"note": "It takes two minutes and it catches the quiet problems before they fall off a wall."
			},
			{
				"id": "spares",
				"eff": "calm",
				"label": "KEEP A SPARE SWITCH AND CABLES IN THE VAN",
				"note": "The team likes this one. Nobody wants to explain a missing part to an angry client."
			},
			{
				"id": "site_walk",
				"eff": "xp",
				"label": "WALK EVERY CLIENT CLOSET WITH A CHECKLIST",
				"note": "You learn more in a day of closets than from a week of tickets."
			},
		],
		"done": "Morgan prints the checklist and pins it above the van keys."
	},
	"email":
	{
		"title": "EMAIL OUTAGE REVIEW",
		"skill": "servers",
		"intro":
		"{me}, the brewery night ran past midnight, and the only thing worse than a long night is a long night we learn nothing from. Blameless review, twenty minutes, one page. Or we skip it.",
		"go": "SIT DOWN WITH MORGAN",
		"skip": "SKIP IT, TOO TIRED",
		"skipped": "Morgan nods slowly. 'Get some sleep,' she says. 'We will talk about it when it happens again.'",
		"cause_q": "Morgan reads the timeline. The log drive filled up, the mail database dismounted and the brewery heard nothing from us for an hour. What was the root cause?",
		"causes":
		[
			{
				"id": "disk",
				"label": "NOBODY WAS WATCHING THE LOG DRIVE, AND NOBODY TOLD THE CLIENT",
				"right": true,
				"note": "Morgan nods. No alert on a disk filling up, and no habit of telling the client what we know. Both are fixable."
			},
			{
				"id": "person",
				"label": "WHOEVER SET UP THE SERVER LEFT THE LOGS ON",
				"right": false,
				"note": "Morgan frowns. That is a person, and it was years ago. We do not write that on the board."
			},
			{
				"id": "vendor",
				"label": "THE SOFTWARE VENDOR SHOULD HAVE WARNED US",
				"right": false,
				"note": "Morgan taps the pen. Maybe. We cannot change them, though. We can change what we watch."
			},
		],
		"items_q": "What do we change? Pick the first.",
		"more_q": "Good. One more, or is that enough for now?",
		"enough": "THAT IS ENOUGH FOR NOW",
		"items":
		[
			{
				"id": "second_oncall",
				"eff": "calm",
				"label": "A SECOND PERSON ON CALL FOR 24x7 CLIENTS",
				"note": "Nobody likes being the only one who can fix it at 2 a.m. The team notices that you asked."
			},
			{
				"id": "status_template",
				"eff": "fixes",
				"label": "A STATUS MESSAGE EVERY 30 MINUTES DURING AN OUTAGE",
				"note": "One line to the client: what we know, what we are doing, when you hear from us next."
			},
			{
				"id": "disk_alerts",
				"eff": "pace",
				"label": "DISK AND MAIL QUEUE ALERTS ON EVERY SERVER",
				"note": "The RMM can watch free space. It just was not set to."
			},
			{
				"id": "vendor_contacts",
				"eff": "xp",
				"label": "A LIST OF VENDOR SUPPORT NUMBERS AND ACCOUNT PINS",
				"note": "Half the night went on finding who to call. Now it is on one sheet."
			},
		],
		"done": "Morgan files the page where the next person will see it first."
	},
	"bec":
	{
		"title": "WIRE FRAUD REVIEW",
		"skill": "security",
		"intro":
		"{me}, the fake wire request at Hoot and Holler could have gone very differently. Let us do a blameless review: how it got that far, which control would have stopped it, what we change for every client. Or we skip it.",
		"go": "SIT DOWN WITH MORGAN",
		"skip": "SKIP IT, TOO BUSY",
		"skipped": "Morgan taps the desk. 'The next one will look the same,' she says. 'Different law firm, same email.'",
		"cause_q": "Morgan lays the email next to a real one. Same wording, same amount, a lookalike domain, and a rule quietly forwarding the firm's mail. What was the root cause?",
		"causes":
		[
			{
				"id": "process",
				"label": "ONE PERSON CAN MOVE MONEY ON AN EMAIL, AND NOBODY WATCHES THE MAILBOX RULES",
				"right": true,
				"note": "Morgan nods. A single email was enough to move money, and a hidden rule had been reading the firm's mail for days. Both are process, not people."
			},
			{
				"id": "person",
				"label": "THE PARALEGAL SHOULD HAVE KNOWN BETTER",
				"right": false,
				"note": "Morgan shakes her head. She is the one who called us. The system should not need her to be perfect."
			},
			{
				"id": "filter",
				"label": "THE SPAM FILTER MISSED IT",
				"right": false,
				"note": "Morgan taps the filter report. It was a clean message from a real mailbox. A filter was never going to catch it."
			},
		],
		"items_q": "What do we change? Pick the first.",
		"more_q": "Good. One more, or is that enough for now?",
		"enough": "THAT IS ENOUGH FOR NOW",
		"items":
		[
			{
				"id": "wire_check",
				"eff": "check",
				"label": "A SECOND-PERSON CHECK AND A CALL-BACK ON EVERY WIRE REQUEST",
				"note": "Nobody moves money on an email alone. A second person calls the number we already had."
			},
			{
				"id": "two_factor",
				"eff": "check",
				"label": "TWO-FACTOR LOGIN FOR EVERY MAILBOX THAT HANDLES MONEY",
				"note": "A stolen password alone does not get you into the mailbox any more."
			},
			{
				"id": "rules_audit",
				"eff": "fixes",
				"label": "A MONTHLY AUDIT OF MAILBOX FORWARDING RULES",
				"note": "Ten minutes a client. The hidden rule would have shown up on the first check."
			},
			{
				"id": "client_talk",
				"eff": "mood",
				"label": "A SHORT TALK FOR EACH CLIENT'S ACCOUNTING STAFF",
				"note": "Clients like being told what to watch for. It feels like service, because it is."
			},
		],
		"done": "Morgan writes the owners a one page summary and says nothing about who was at fault. That is the point."
	},
}
var POSTMORTEMS: Dictionary = DEFAULT_POSTMORTEMS.duplicate(true)
const DEFAULT_VIGNETTES := {
	"adam_friday_good":
	{
		"speaker": "Adam (Senior Tech)",
		"text":
		"Friday numbers. {closed} closed this week, {missed} missed, {backlog} still open. That is a clean board. I do not say that often.",
		"options":
		[
			{
				"id": "thanks",
				"label": "THANKS, ADAM",
				"text": "Do not thank me. Do it again next week. (reputation +1)",
				"fx": {"rep": 1}
			},
			{
				"id": "how",
				"label": "WHAT WOULD YOU DO DIFFERENTLY?",
				"text":
				"Nothing yet. Keep an eye on the old tickets, they turn into the missed ones. (+2 customer XP)",
				"fx": {"xp": ["people", 2]}
			},
		],
	},
	"adam_friday_ok":
	{
		"speaker": "Adam (Senior Tech)",
		"text":
		"Friday numbers. {closed} closed, {missed} missed, {backlog} still open. Not bad, not great. Where did the week get away from you?",
		"options":
		[
			{
				"id": "tighten",
				"label": "I WILL TIGHTEN IT UP",
				"text": "Good. Look at the clock before you look at the client name. (+1 customer XP)",
				"fx": {"xp": ["people", 1]}
			},
			{
				"id": "rough",
				"label": "IT WAS A ROUGH WEEK",
				"text":
				"It is a rough week for everybody. That is why we measure it. Come ask me when it turns red, not after.",
				"fx": {}
			},
		],
	},
	"adam_friday_bad":
	{
		"speaker": "Adam (Senior Tech)",
		"text":
		"Friday numbers. {closed} closed, {missed} missed, {backlog} still open. That is not where we want to be. Walk me through it. Why?",
		"options":
		[
			{
				"id": "triage",
				"label": "I GOT BEHIND ON TRIAGE",
				"text":
				"Fair. Honest is a good start. Tell me earlier next time and I can take a ticket off you. (+2 customer XP)",
				"fx": {"xp": ["people", 2]}
			},
			{
				"id": "volume",
				"label": "THERE WERE TOO MANY TICKETS",
				"text":
				"The volume is the same for everyone. Show me which ones you could not have closed. (reputation -1)",
				"fx": {"rep": -1}
			},
			{
				"id": "help",
				"label": "SOME OF THEM WERE OVER MY HEAD",
				"text": "Then ask me before they go red. That is what I am here for. (+2 servers XP)",
				"fx": {"xp": ["servers", 2]}
			},
		],
	},
	"mentor_intro":
	{
		"speaker": "Dan (Service Manager)",
		"text":
		"Morning. I'm Dan, I run the service desk, so you're mine this week. I can walk you through the first few days, or leave you to it. No judgment either way. Which do you want?",
		"options":
		[
			{
				"id": "walk",
				"label": "WALK ME THROUGH IT",
				"text":
				"Good. I'll put little reminders on your screen for the first ticket, and I'll check in on days two and three. Start by sitting at your desk.",
				"fx": {"flag": ["mentor", "on"], "social": {"Dan": 2}}
			},
			{
				"id": "alone",
				"label": "I'VE GOT THIS",
				"text":
				"Fair enough. The PSA is on your computer, and I'm in the Lync list if you want me. Do not close anything that is not really fixed.",
				"fx": {"flag": ["mentor", "off"]}
			},
		],
	},
	"mentor_triage":
	{
		"speaker": "Dan (Service Manager)",
		"text":
		"Two tickets in the queue. One has two minutes left on its SLA. The other is from your biggest client, but it has all morning. Which one first?",
		"options":
		[
			{
				"id": "sla",
				"label": "THE ONE ABOUT TO BREACH",
				"text":
				"Right. The clock is the contract. A big client can wait ten minutes, a breached SLA stays on the report. (+3 customer XP)",
				"fx": {"xp": ["people", 3], "social": {"Dan": 1}}
			},
			{
				"id": "big",
				"label": "THE BIGGEST CLIENT",
				"text":
				"I get it, but the SLA timer does not care who is bigger. Look at the clocks first, then the names. (+1 customer XP)",
				"fx": {"xp": ["people", 1]}
			},
		],
	},
	"mentor_fix":
	{
		"speaker": "Dan (Service Manager)",
		"text":
		"That Adobe ticket will crash again tomorrow if you only restart it. You can do the two-click restart and move on, or spend half an hour finding out why. Your call.",
		"options":
		[
			{
				"id": "quick",
				"label": "RESTART IT AND MOVE ON",
				"text":
				"Quick, and it works today. It might come back tomorrow, and then it is your problem twice. (+1 servers XP)",
				"fx": {"xp": ["servers", 1]}
			},
			{
				"id": "cause",
				"label": "FIND THE CAUSE",
				"text": "Slower now, but it stays fixed. That is the whole job in one decision. (+4 servers XP)",
				"fx": {"xp": ["servers", 4], "hours": 0.3, "social": {"Dan": 1}}
			},
		],
	},
	"mentor_debrief":
	{
		"speaker": "Dan (Service Manager)",
		"text":
		"You're on your own from tomorrow. If a ticket really stumps you, ask Adam, he's our senior tech. He also goes over the numbers on Fridays, so do not let the queue get old. Good first three days.",
		"options":
		[
			{
				"id": "thanks",
				"label": "THANKS, DAN",
				"text": "Anytime. Lync me if the printer wins.",
				"fx": {"social": {"Dan": 2}}
			},
			{
				"id": "tips",
				"label": "ANY TIPS FOR THE QUEUE?",
				"text":
				"Triage by the clock, close only what is really fixed, and ask Adam before you guess. That is most of it. (+1 customer XP)",
				"fx": {"xp": ["people", 1]}
			},
		],
	},
	"iphone":
	{
		"speaker": "Karen Whitfield (Brightside Realty)",
		"text":
		"I just got a new iFone 5S and all my email is gone! I have a showing in an hour. Can you please set it up?",
		"options":
		[
			{
				"id": "proper",
				"label": "SET IT UP PROPERLY, WITH A PASSCODE",
				"text":
				"Her mail works and she has a passcode now. She says you are a lifesaver. (+4 customer XP)",
				"fx": {"xp": ["people", 4], "mood": [1, 4], "hours": 0.3}
			},
			{
				"id": "all",
				"label": "SET IT UP AND MOVE HER CONTACTS TOO",
				"text":
				"It takes a while, but every client's number is on the new phone. She hugs you. A little. (+3 customer XP)",
				"fx": {"xp": ["people", 3], "mood": [1, 6], "hours": 0.6, "energy": -1}
			},
			{
				"id": "store",
				"label": "TELL HER TO CALL THE PHONE STORE",
				"text": "She sighs and says she will ask her nephew.",
				"fx": {"mood": [1, -3]}
			},
		],
	},
	"invoice":
	{
		"speaker": "Karen Whitfield (Brightside Realty)",
		"text":
		"Our landlord emailed new bank details for the rent and wants it wired today. The signature looks right, but the address is a little off. Should I just do it? I do not want to be late.",
		"text_checked":
		"The landlord emailed new bank details for the rent. Then I remembered Morgan's rule: a call-back before any bank change. I called the number on the lease and he never sent it! Thank you for the rule.",
		"options":
		[
			{
				"id": "call",
				"label": "TELL HER TO CALL THE LANDLORD ON THE LEASE NUMBER",
				"text":
				"He never sent it. She is a little shaken and a lot grateful. (+4 security XP, reputation +1)",
				"fx": {"xp": ["security", 4], "rep": 1, "mood": [1, 5], "hours": 0.2}
			},
			{
				"id": "headers",
				"label": "CHECK THE EMAIL HEADERS FOR HER",
				"text":
				"The sender is a lookalike domain. She does not pay and you tell her to call him anyway. (+6 security XP)",
				"fx": {"xp": ["security", 6], "mood": [1, 3], "hours": 0.4}
			},
			{
				"id": "late",
				"label": "SAY IT IS PROBABLY FINE, PAY IT",
				"text":
				"She wires the rent. The real landlord calls on Friday asking where it is. Brightside is out the money and not happy. (reputation -2)",
				"fx": {"rep": -2, "mood": [1, -8]}
			},
		],
		"options_checked":
		[
			{
				"id": "ok",
				"label": "SAY YOU ARE GLAD THE RULE WORKED",
				"text":
				"She tells everyone in the office. Two of them ask who set it up. (+4 security XP, reputation +1)",
				"fx": {"xp": ["security", 4], "rep": 1, "mood": [1, 6]}
			},
			{
				"id": "more",
				"label": "OFFER A FIVE MINUTE TALK FOR HER WHOLE OFFICE",
				"text":
				"Nine people, one whiteboard, no jargon. The office manager asks for a copy of the checklist. (+6 security XP)",
				"fx": {"xp": ["security", 6], "mood": [1, 8], "hours": 0.4}
			},
		],
	},
	"heartbleed":
	{
		"speaker": "Garrison (Co-owner)",
		"text":
		"Every client is asking about Heartbleed, that bug in the news with a logo, and I told them we are on it. Are any of their servers affected? Please check before they call us again.",
		"options":
		[
			{
				"id": "check",
				"label": "CHECK EVERY CLIENT AND WRITE A SHORT NOTE",
				"text":
				"Most are fine. One old firewall needs a patch and you schedule it for tonight. Garrison nods. (+6 security XP, reputation +1)",
				"fx": {"xp": ["security", 6], "rep": 1, "hours": 0.5}
			},
			{
				"id": "mail",
				"label": "SEND A REASSURING EMAIL TO EVERYONE",
				"text":
				"You say 'we are looking into it and will update you'. Nobody replies. That is a good sign.",
				"fx": {"mood_all": 2}
			},
			{
				"id": "wait",
				"label": "WAIT UNTIL SOMEONE ASKS",
				"text": "Garrison sighs. 'That is what everyone said about Target.'",
				"fx": {"rep": -1, "social": {"Garrison": -2}}
			},
		],
	},
	"candy":
	{
		"speaker": "The hygienist (Acme Dental)",
		"text":
		"I put Sugar Smash on the front desk computer so the waiting room kids can play. Is that okay? It is very popular.",
		"options":
		[
			{
				"id": "remove",
				"label": "REMOVE IT AND EXPLAIN WHY",
				"text":
				"You explain malware and the license. She is a bit disappointed and very understanding. (+2 customer XP)",
				"fx": {"xp": ["people", 2], "mood": [0, 2]}
			},
			{
				"id": "play",
				"label": "PLAY ONE LEVEL TO TEST IT FIRST",
				"text": "Level 41. It is very hard. Your coffee goes cold. (+2 energy)",
				"fx": {"energy": 2, "hours": 0.2}
			},
			{
				"id": "tell",
				"label": "TELL DR. PATEL",
				"text": "Dr. Patel is not amused. The hygienist is not amused either.",
				"fx": {"mood": [0, -4]}
			},
		],
	},
	"pizza":
	{
		"speaker": "A salesman from a PSA vendor",
		"text":
		"Hi! I am bringing free pizza for the service desk and I would love just thirty minutes of your time to show you our ticketing software.",
		"options":
		[
			{
				"id": "listen",
				"label": "TAKE THE PIZZA AND LISTEN",
				"text":
				"The demo is okay, and you learn what the competition charges. The pizza is good. (+2 customer XP, +3 energy)",
				"fx": {"xp": ["people", 2], "energy": 3, "hours": 0.5}
			},
			{
				"id": "grab",
				"label": "TAKE A SLICE AND LEAVE",
				"text": "Alan notices. He says nothing, loudly. (+2 energy)",
				"fx": {"energy": 2, "social": {"Alan": -1}}
			},
			{
				"id": "decline",
				"label": "TELL HIM WE ARE HAPPY WITH WHAT WE HAVE",
				"text": "He leaves the pizza anyway. Everyone is happy.",
				"fx": {"social_all": 1}
			},
		],
	},
	"win8":
	{
		"speaker": "A realtor at Brightside",
		"text":
		"I updated my computer to Windows 8 and now there is no Start button! Where did it go? I have a listing to send in ten minutes.",
		"options":
		[
			{
				"id": "show",
				"label": "SHOW HER THE HOT CORNERS AND THE START SCREEN",
				"text":
				"She learns where everything went. She calls it 'the tiles' for the rest of the year. (+3 customer XP)",
				"fx": {"xp": ["people", 3], "mood": [1, 3], "hours": 0.3}
			},
			{
				"id": "menu",
				"label": "INSTALL A START MENU REPLACEMENT",
				"text": "A familiar button comes back and she cries a little. (+2 servers XP)",
				"fx": {"xp": ["servers", 2], "mood": [1, 4], "hours": 0.2}
			},
			{
				"id": "feature",
				"label": "TELL HER IT IS A FEATURE",
				"text": "Dan laughs quietly across the room. She does not.",
				"fx": {"mood": [1, -3], "social": {"Dan": 1}}
			},
		],
	},
	"selfreview":
	{
		"speaker": "Morgan (Manager)",
		"text": "Before reviews: what are you proudest of this year? I will remember what you say.",
		"options":
		[
			{
				"id": "jobs",
				"label": "THE BIG JOBS I GOT RIGHT",
				"text": "Morgan writes it down. 'That is what I will say to Alan and Garrison.'",
				"fx": {"rep": 1}
			},
			{
				"id": "learn",
				"label": "HOW MUCH I HAVE LEARNED",
				"text": "Morgan smiles. 'Keep doing that.' (+3 customer XP)",
				"fx": {"xp": ["people", 3]}
			},
			{
				"id": "team",
				"label": "THE TEAM I WORK WITH",
				"text": "Morgan says the team has noticed. Word gets around.",
				"fx": {"social_all": 2}
			},
		],
	},
	"donuts":
	{
		"speaker": "Alan (Co-owner)",
		"text":
		"I am back, and I brought donuts. Morgan says you covered for me while I was out. I read the page you wrote about the firewall I built. Show me how you set it up in the vault?",
		"text_reset":
		"I am back, and I brought donuts. Morgan says you covered for me while I was out, and I heard what happened to the firewall. I am not angry. Show me how it is set up now?",
		"text_plain":
		"I am back, and I brought donuts. Morgan says you covered for me while I was out. Nobody wrote down how the firewall is set up, so would you show me what you did?",
		"options":
		[
			{
				"id": "show",
				"label": "SHOW HIM, HE IS PROUD",
				"text": "Alan nods slowly. 'That is better than what I had.' (+3 servers XP)",
				"fx": {"xp": ["servers", 3], "social": {"Alan": 3}}
			},
			{
				"id": "nothing",
				"label": "SAY IT WAS NOTHING",
				"text": "He insists you are being modest and gives you the last donut.",
				"fx": {"social": {"Alan": 1}, "energy": 1}
			},
			{
				"id": "subject",
				"label": "EAT A DONUT AND CHANGE THE SUBJECT",
				"text": "You discuss the weather for a minute. The donut is very good. (+2 energy)",
				"fx": {"energy": 2}
			},
		],
	},
	"tape_swap":
	{
		"speaker": "The office manager (Gnarly Gnomes)",
		"text": "Nobody has changed the backup tape since Monday. We keep forgetting. Could we just leave it in forever?",
		"min_day": 3,
		"max_day": 20,
		"options": [
			{
				"id": "label",
				"label": "PUT A COLORED LABEL ON EACH DAY'S TAPE",
				"text": "She buys a roll of stickers. The tapes look like a rainbow.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						2,
						3
					]
				}
			},
			{
				"id": "auto",
				"label": "SWITCH THEM TO DISK-BASED BACKUPS",
				"text": "A small project for a rainy day.",
				"fx": {
					"xp": [
						"servers",
						3
					],
					"hours": 0.5
				}
			},
			{
				"id": "remind",
				"label": "SEND A DAILY REMINDER EMAIL",
				"text": "It works for two days.",
				"fx": {
					"mood": [
						2,
						1
					]
				}
			}
		]
	},
	"toolbar":
	{
		"speaker": "A realtor at Brightside",
		"text": "My browser has a toolbar I did not ask for, and another one, and now a third. The page is the size of a postage stamp.",
		"min_day": 3,
		"max_day": 20,
		"options": [
			{
				"id": "remove",
				"label": "REMOVE THEM ALL AND EXPLAIN THE 'NEXT' BUTTON",
				"text": "She will never press 'Next' again without reading.",
				"fx": {
					"xp": [
						"security",
						3
					],
					"mood": [
						1,
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "reset",
				"label": "RESET THE BROWSER",
				"text": "Clean and fast. She stops cursing.",
				"fx": {
					"xp": [
						"security",
						1
					],
					"mood": [
						1,
						2
					]
				}
			},
			{
				"id": "shrug",
				"label": "TELL HER TO CLOSE SOME TABS",
				"text": "Not the answer she wanted.",
				"fx": {
					"mood": [
						1,
						-3
					]
				}
			}
		]
	},
	"fax_black":
	{
		"speaker": "The paralegal (Hoot and Holler)",
		"text": "The fax machine is printing black pages. Every page. The partners are waiting on a signed document and it is only coming out black.",
		"min_day": 4,
		"max_day": 20,
		"options": [
			{
				"id": "clean",
				"label": "CLEAN THE SCANNER GLASS AND THE ROLLER",
				"text": "A smudge the size of a dime. The fax prints beautifully.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"mood": [
						3,
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "scan",
				"label": "SCAN AND EMAIL THE DOCUMENT INSTEAD",
				"text": "No fax needed. She looks at you as if you had invented email.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						3,
						4
					]
				}
			},
			{
				"id": "order",
				"label": "ORDER A NEW FAX MACHINE",
				"text": "A new machine is fine, but the document is still stuck.",
				"fx": {
					"mood": [
						3,
						-2
					]
				}
			}
		]
	},
	"sticky_dan":
	{
		"speaker": "Dan (Service Manager)",
		"text": "I found the main router password on a sticky note in three different offices. It is 'admin' in all three. Do you want me to fix it or yell?",
		"min_day": 4,
		"max_day": 20,
		"options": [
			{
				"id": "fix",
				"label": "TELL HIM TO FIX IT AND YOU WILL WRITE THE NOTE",
				"text": "He changes it. You write a short, friendly note. Dan nods.",
				"fx": {
					"xp": [
						"security",
						2
					],
					"social": {
						"Dan": 2
					}
				}
			},
			{
				"id": "yell",
				"label": "BOTH",
				"text": "You say it together and feel better.",
				"fx": {
					"social": {
						"Dan": 1
					},
					"energy": 1
				}
			},
			{
				"id": "later",
				"label": "SAY IT CAN WAIT",
				"text": "Dan raises an eyebrow, a very small one.",
				"fx": {
					"social": {
						"Dan": -1
					}
				}
			}
		]
	},
	"captcha":
	{
		"speaker": "A realtor at Brightside",
		"text": "The website keeps asking me to type distorted letters and I cannot read them. I have tried eleven times. Is the site broken?",
		"min_day": 5,
		"max_day": 20,
		"options": [
			{
				"id": "teach",
				"label": "SIT WITH HER AND SOLVE A FEW",
				"text": "She likes the one that reads 'banana'.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						1,
						3
					],
					"hours": 0.2
				}
			},
			{
				"id": "audio",
				"label": "SHOW HER THE AUDIO OPTION",
				"text": "It sounds like a ghost reading numbers, but it works.",
				"fx": {
					"mood": [
						1,
						2
					]
				}
			},
			{
				"id": "email",
				"label": "TELL HER TO EMAIL THEM",
				"text": "She does. They respond in a week.",
				"fx": {
					"mood": [
						1,
						-1
					]
				}
			}
		]
	},
	"cable_mess":
	{
		"speaker": "The owner (Gnarly Gnomes)",
		"text": "Behind the desk there is a nest of cables. My assistant says it is a fire hazard. Can you make it nice? It is not nice.",
		"min_day": 5,
		"max_day": 20,
		"options": [
			{
				"id": "tidy",
				"label": "LABEL, BUNDLE AND ROUTE EVERYTHING",
				"text": "Twenty velcro ties and forty minutes. It looks like a catalog photo.",
				"fx": {
					"xp": [
						"networking",
						4
					],
					"mood": [
						2,
						4
					],
					"hours": 0.7
				}
			},
			{
				"id": "some",
				"label": "TIDY THE WORST HALF",
				"text": "It is better. She says it is a start.",
				"fx": {
					"xp": [
						"networking",
						2
					],
					"mood": [
						2,
						2
					],
					"hours": 0.3
				}
			},
			{
				"id": "point",
				"label": "TELL HER IT IS NOT A HAZARD",
				"text": "It is slightly a hazard.",
				"fx": {
					"mood": [
						2,
						-2
					]
				}
			}
		]
	},
	"kid_laptop":
	{
		"speaker": "A client's teenager",
		"text": "I need help. My mom said you set up her computer, and my school laptop will not connect to anything. Mom says I can ask you, but I have to say please.",
		"min_day": 6,
		"max_day": 20,
		"options": [
			{
				"id": "fix",
				"label": "TAKE A LOOK, IT IS A FIVE MINUTE JOB",
				"text": "A wrong setting. She thanks you in a very serious voice.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						4,
						3
					],
					"hours": 0.2
				}
			},
			{
				"id": "teach",
				"label": "SHOW HER HOW TO CHECK IT HERSELF",
				"text": "She writes it down in a notebook. She will be running IT someday.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						4,
						2
					],
					"hours": 0.3
				}
			},
			{
				"id": "no",
				"label": "SAY YOU CAN ONLY HELP THE COMPANY",
				"text": "She understands. Probably.",
				"fx": {
					"mood": [
						4,
						-1
					]
				}
			}
		]
	},
	"voip_pitch":
	{
		"speaker": "A salesman from a phone company",
		"text": "Hi! Hosted phones are the next big thing. No more desk phone boxes in the closet. I would love to show you a quick demo with a headset.",
		"min_day": 6,
		"max_day": 20,
		"options": [
			{
				"id": "demo",
				"label": "TRY THE DEMO",
				"text": "The call is clear, the portal is clean, and the price is not.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"hours": 0.4
				}
			},
			{
				"id": "card",
				"label": "TAKE HIS CARD AND PASS IT TO THE OWNERS",
				"text": "Garrison files it with the other ideas. Alan nods slowly.",
				"fx": {
					"social_all": 1
				}
			},
			{
				"id": "no",
				"label": "SAY WE ARE HAPPY WITH WHAT WE HAVE",
				"text": "He leaves a pen with a logo on it.",
				"fx": {}
			}
		]
	},
	"spam_folder":
	{
		"speaker": "The office manager (Acme Dental)",
		"text": "The newsletter we send every month is landing in everybody's spam folder. Even mine. It looks fine to me!",
		"min_day": 7,
		"max_day": 20,
		"options": [
			{
				"id": "dns",
				"label": "CHECK THE MAIL SETTINGS AND FIX THE SENDER RECORD",
				"text": "One missing record. The mail lands in inboxes again.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"mood": [
						0,
						4
					],
					"hours": 0.6
				}
			},
			{
				"id": "tips",
				"label": "SUGGEST A BETTER SUBJECT LINE",
				"text": "'FREE TEETH!!!' becomes 'Your spring checkup'. It helps.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						0,
						2
					]
				}
			},
			{
				"id": "whitelist",
				"label": "TELL EVERYONE TO MARK IT AS SAFE",
				"text": "Half of them do. The other half do not read it.",
				"fx": {
					"mood": [
						0,
						1
					]
				}
			}
		]
	},
	"charger_drawer":
	{
		"speaker": "Dan (Service Manager)",
		"text": "There is a drawer full of chargers and nobody knows what goes with what. I made a chart. It has color coding. Do you want a copy?",
		"min_day": 8,
		"max_day": 20,
		"options": [
			{
				"id": "copy",
				"label": "YES, AND PUT IT ON THE WALL",
				"text": "The drawer becomes the most organized place in the office.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"social": {
						"Dan": 2
					}
				}
			},
			{
				"id": "help",
				"label": "HELP HIM LABEL THEM",
				"text": "You find a charger for a phone nobody remembers. It is a good morning.",
				"fx": {
					"social": {
						"Dan": 2
					},
					"energy": 1,
					"hours": 0.3
				}
			},
			{
				"id": "laugh",
				"label": "LAUGH AT THE CHART",
				"text": "Dan does not speak to you for twenty minutes.",
				"fx": {
					"social": {
						"Dan": -2
					}
				}
			}
		]
	},
	"tv_monitor":
	{
		"speaker": "A realtor at Brightside",
		"text": "I bought a 50 inch TV for my desk. It was on sale! It looks great, but my eyes hurt and the text is blurry. Can you fix it?",
		"min_day": 8,
		"max_day": 20,
		"options": [
			{
				"id": "set",
				"label": "SET THE RIGHT RESOLUTION AND TEXT SIZE",
				"text": "A tiny tweak. She says it is like new glasses.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						1,
						4
					],
					"hours": 0.3
				}
			},
			{
				"id": "mount",
				"label": "SUGGEST MOVING IT BACK A FEW FEET",
				"text": "She tries it. A TV across the room is a TV.",
				"fx": {
					"mood": [
						1,
						2
					]
				}
			},
			{
				"id": "return",
				"label": "SAY THAT A TV IS NOT A MONITOR",
				"text": "She says it is a monitor now.",
				"fx": {
					"mood": [
						1,
						-2
					]
				}
			}
		]
	},
	"scan_to_mail":
	{
		"speaker": "The paralegal (Hoot and Holler)",
		"text": "The new copier says it can 'scan to email', but it asks for a server name I do not have. Can you do whatever it is that I should do?",
		"min_day": 9,
		"max_day": 20,
		"options": [
			{
				"id": "setup",
				"label": "SET UP THE SCAN-TO-EMAIL PROPERLY",
				"text": "A mail relay and a small password. The partners can scan from the copier.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"mood": [
						3,
						4
					],
					"hours": 0.6
				}
			},
			{
				"id": "folder",
				"label": "SET UP SCAN TO A SHARED FOLDER",
				"text": "Simpler and safer. She approves.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"mood": [
						3,
						3
					],
					"hours": 0.4
				}
			},
			{
				"id": "later",
				"label": "TELL HER YOU WILL LOOK AT IT NEXT WEEK",
				"text": "She keeps using the fax. Which is black.",
				"fx": {
					"mood": [
						3,
						-2
					]
				}
			}
		]
	},
	"old_server_larry":
	{
		"speaker": "Alan (Co-owner)",
		"text": "There is a server in the back that Larry set up in 2006. Nobody knows what it does and nobody will turn it off. Can you find out what is on it?",
		"min_day": 10,
		"max_day": 20,
		"options": [
			{
				"id": "find",
				"label": "TRACE WHAT TALKS TO IT AND WRITE IT DOWN",
				"text": "It runs a label printer and one database for the front desk. You document both.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"social": {
						"Alan": 2
					},
					"hours": 0.6
				}
			},
			{
				"id": "ask",
				"label": "ASK EVERYONE IN THE OFFICE",
				"text": "Someone remembers a login that works. Alan chuckles.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"social": {
						"Alan": 1
					}
				}
			},
			{
				"id": "leave",
				"label": "LEAVE IT ALONE, LARRY KNOWS BEST",
				"text": "Larry left in 2009.",
				"fx": {
					"social": {
						"Alan": -1
					}
				}
			}
		]
	},
	"win81_update":
	{
		"speaker": "A realtor at Brightside",
		"text": "The computer says there is a free update to Windows 8.1 and she wants to know if it brings the Start button back. I have been told it does. Is that true?",
		"min_day": 11,
		"max_day": 20,
		"options": [
			{
				"id": "yes",
				"label": "TELL HER YES, AND INSTALL IT AFTER LUNCH",
				"text": "A shiny button comes back, and she is pleased.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						1,
						3
					],
					"hours": 0.5
				}
			},
			{
				"id": "careful",
				"label": "BACK UP FIRST, THEN INSTALL",
				"text": "It takes longer. It also does not fail.",
				"fx": {
					"xp": [
						"security",
						2
					],
					"mood": [
						1,
						2
					],
					"hours": 0.7
				}
			},
			{
				"id": "skip",
				"label": "TELL HER TO WAIT",
				"text": "She installs it herself and tells you about it.",
				"fx": {
					"mood": [
						1,
						-2
					]
				}
			}
		]
	},
	"thank_you_card":
	{
		"speaker": "A card from Soggy Bottom Brewing",
		"text": "A hand-written card arrives. 'Thank you for all your help this year. The beer is on us. Come by any Friday.' There is a drawing of a pint glass.",
		"min_day": 15,
		"max_day": 20,
		"options": [
			{
				"id": "frame",
				"label": "PIN IT TO THE WALL",
				"text": "Everyone reads it. It is a good morning.",
				"fx": {
					"social_all": 1
				}
			},
			{
				"id": "share",
				"label": "READ IT TO THE TEAM",
				"text": "A little applause. A little embarrassment.",
				"fx": {
					"rep": 1
				}
			},
			{
				"id": "keep",
				"label": "PUT IT IN YOUR DRAWER",
				"text": "A private small win.",
				"fx": {
					"energy": 2
				}
			}
		]
	},
	"alan_sandwich":
	{
		"speaker": "Alan (Co-owner)",
		"text": "I made two sandwiches this morning, one too many. Roast beef. You can have it if you tell me which of the three printers has been misbehaving the most.",
		"min_day": 17,
		"max_day": 20,
		"options": [
			{
				"id": "honest",
				"label": "TELL HIM THE TRUTH ABOUT THE PRINTERS",
				"text": "The sandwich is excellent. The answer is the one at Hoot and Holler.",
				"fx": {
					"energy": 5,
					"social": {
						"Alan": 2
					}
				}
			},
			{
				"id": "diplomatic",
				"label": "TAKE THE SANDWICH AND CHANGE THE SUBJECT",
				"text": "Alan raises an eyebrow, but the sandwich stays.",
				"fx": {
					"energy": 3,
					"social": {
						"Alan": 1
					}
				}
			},
			{
				"id": "no",
				"label": "SAY YOU ALREADY ATE",
				"text": "He eats both. He does not blame you.",
				"fx": {}
			}
		]
	},
	"first_week_note":
	{
		"speaker": "Morgan (Manager)",
		"text": "The year is almost over. Is there something you wish somebody had told you on your first day? I am writing a note for the next new hire.",
		"min_day": 18,
		"max_day": 20,
		"options": [
			{
				"id": "tips",
				"label": "WRITE DOWN THREE TIPS",
				"text": "Morgan reads them aloud and says, 'Perfect.'",
				"fx": {
					"xp": [
						"people",
						3
					],
					"rep": 1
				}
			},
			{
				"id": "short",
				"label": "SAY 'ASK QUESTIONS EARLY'",
				"text": "Morgan writes that down and underlines it.",
				"fx": {
					"xp": [
						"people",
						1
					]
				}
			},
			{
				"id": "none",
				"label": "SAY 'NOTHING, REALLY'",
				"text": "Morgan thinks you are being modest.",
				"fx": {}
			}
		]
	},
}
var VIGNETTES: Dictionary = DEFAULT_VIGNETTES.duplicate(true)
const DEFAULT_DAYS := {
	1:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Your first day",
			"body":
			(
				"Welcome to Pixel IT Partners. Alan and Garrison own the place and I run the floor for them. Tickets come in on ConnectWhy PSA, you fix things "
				+ "with LabRat RMM, and you only close a ticket once it is really fixed. Reopened tickets "
				+ "make me sad. Clients also call and text, so check your phone (P) now and then. - Morgan"
			)
		},
		{"at": 9.2, "kind": "mentor", "id": "mentor_intro"},
	],
	2:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Daily chore: verify backups",
			"body":
			(
				"Every morning open LabRat RMM, click BACKUPS and check each client. Backup jobs "
				+ "can fail silently and nobody notices until the day it really matters. It takes thirty "
				+ "seconds, until your security skills are good enough for the backup watch to do it for you. - Morgan"
			)
		},
		{"at": 9.6, "kind": "mentor", "id": "mentor_triage"},
		{"at": 10.5, "kind": "vignette", "id": "iphone"},
	],
	3:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Get good at PowerShell",
			"body":
			(
				"The PowerShell Academy is on your desktop. Every lesson makes your remote fixes "
				+ "faster and more reliable, and later levels unlock scripts that fix a whole client at "
				+ "once. Study between tickets. - Morgan"
			)
		},
		{"at": 10.0, "kind": "adobe", "client": 1},
		{"at": 10.6, "kind": "mentor", "id": "mentor_fix"},
		{"at": 16.2, "kind": "mentor", "id": "mentor_debrief"},
	],
	4:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Windows XP is going away",
			"body":
			(
				"Microsoft ends support for Windows XP and Office 2003 on April 8. After that there are no "
				+ "more security patches, so every XP machine at every client is a liability. "
				+ "Dr. Patel at Acme Dental is first. Survey the old PC (old software, old drivers, odd "
				+ "settings), back it up before you move anything, migrate, then verify with the user "
				+ "before you wipe it. - Morgan"
			)
		},
		{"at": 10.0, "kind": "install"},
	],
	5:
	[
		{"at": 8.6, "kind": "backup_break", "client": RANSOM_CLIENT},
		{"at": 9.6, "kind": "install_followup"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "On-call rota starts Monday",
			"body":
			(
				"You are on the pager next week (Monday to Friday nights). If a client alert wakes you, "
				+ "you can get up and fix it, check it first, or let it ride, "
				+ "but clients do not forgive a dead server. "
				+ "On-call pay is $40 a day. Leave for work early enough, too: "
				+ "Route 9 is down to one lane. - Morgan"
			)
		},
		{"at": 10.5, "kind": "vignette", "id": "heartbleed"},
		{"at": 15.8, "kind": "metrics"},
	],
	6: [{"at": 9.8, "kind": "growth_plan"}],
	7:
	[
		{
			"at": 10.0,
			"kind": "mail",
			"from": "Atty. Spence <spence@hootholler.example>",
			"subject": "Backup report?",
			"body":
			"Hi, I have not seen the nightly backup report email for a few days. Probably nothing? - Spence"
		},
		{
			"at": 13.0,
			"kind": "playbook",
			"book": "rdp",
			"text":
			(
				"Brightside's server is crawling and there are strangers in the logs. "
				+ "Their remote desktop may be open to the internet. Look, then close the door."
			)
		},
		{"at": 11.0, "kind": "growth_block"},
		{"at": 15.5, "kind": "vignette", "id": "candy"},
	],
	8:
	[
		{
			"at": 9.6,
			"kind": "playbook",
			"book": "ceofraud",
			"text":
			"Hoot and Holler got a strange email asking to wire money. The paralegal is waiting on you before she does anything."
		},
		{"at": 14.0, "kind": "growth_stretch"},
	],
	9: [{"at": 10.5, "kind": "ransomware"}],
	10:
	[
		{
			"at": 10.0,
			"kind": "playbook",
			"book": "rack",
			"text":
			"Gnarly Gnomes says their network rack fell off the wall. Everything is down. Go. Photos first!"
		},
		{"at": 15.8, "kind": "metrics"},
	],
	11:
	[
		{"at": 10.0, "kind": "callback_install"},
		{"at": 11.0, "kind": "postmortem", "cls": "bec"},
		{"at": 14.0, "kind": "postmortem", "cls": "rack"}
	],
	12:
	[
		{
			"at": 9.5,
			"kind": "playbook",
			"book": "migration",
			"text":
			"Brightside's server migration is today. Check the backups before you touch anything."
		},
		{"at": 11.0, "kind": "growth_block"},
		{"at": 14.0, "kind": "postmortem", "cls": "ransom"},
		{"at": 15.5, "kind": "vignette", "id": "pizza"},
	],
	13:
	[
		{
			"at": 15.5,
			"kind": "playbook",
			"book": "email24",
			"text":
			"Soggy Bottom Brewing runs 24x7 and their email just died. This could be a long night."
		},
		{"at": 14.0, "kind": "growth_stretch"},
	],
	14:
	[
		{
			"at": 13.0,
			"kind": "playbook",
			"book": "no2fa",
			"text":
			"Soggy Bottom keeps getting phished and still refuses stronger logins. Go and have the conversation."
		},
		{"at": 10.0, "kind": "callback_ransom"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "About last night",
			"body":
			(
				"Whatever happened with the brewery, thank you for staying late. Overtime is on your paycheck. "
				+ "Take it easy today. - Morgan"
			)
		},
		{"at": 15.5, "kind": "vignette", "id": "win8"},
	],
	15:
	[
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Pager again",
			"body":
			"You are back on call from Monday. Storm season is here, so expect rain, traffic and worse. - Morgan"
		},
		{"at": 10.5, "kind": "postmortem", "cls": "email"},
		{"at": 15.8, "kind": "metrics"},
	],
	16:
	[
		{
			"at": 9.5,
			"kind": "playbook",
			"book": "netinstall",
			"text":
			"Hoot and Holler's branch office network install is today. Do it right, they remember."
		},
	],
	17: [{"at": 11.0, "kind": "growth_block"}, {"at": 14.0, "kind": "vignette", "id": "invoice"}],
	18:
	[
		{"at": 14.0, "kind": "growth_stretch"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Reviews are coming",
			"body":
			(
				"Yearly reviews are on day 20. I look at your tickets, your big jobs and what "
				+ "your coworkers say about you. No pressure. A little pressure. - Morgan"
			)
		},
		{"at": 10.5, "kind": "vignette", "id": "selfreview"},
	],
	19:
	[
		{
			"at": 9.5,
			"kind": "playbook",
			"book": "bus",
			"text": "Acme's internet is flaky and the person who knows the firewall is out sick."
		},
		{"at": 15.0, "kind": "vignette", "id": "donuts"},
	],
	20:
	[
		{"at": 9.4, "kind": "callback_worst"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Review at the end of the day",
			"body":
			"We will sit down after close for your yearly review. There may be an offer or two. - Morgan"
		},
	],
}
var DAYS: Dictionary = DEFAULT_DAYS.duplicate(true)

var flags := {}  # story results (saved with the campaign)
var overtime := false  # an incident is keeping the day open past closing time
var ot_hours := 0.0

var _fired := {}
var _followed := false


func reset() -> void:
	flags = {}
	_fired = {}
	overtime = false
	ot_hours = 0.0
	_followed = false
	Playbook.reset()


# the resume point (R16): which of today's events already fired, so a mid-day continue does not repeat them
func snapshot() -> Dictionary:
	return {"fired": _fired.duplicate(), "followed": _followed, "overtime": overtime, "ot_hours": ot_hours}


func restore(data: Dictionary) -> void:
	_fired = {}
	var fired: Variant = data.get("fired", {})
	if fired is Dictionary:
		for k in fired:
			_fired[int(k)] = true
	_followed = bool(data.get("followed", false))
	overtime = bool(data.get("overtime", false))
	ot_hours = float(data.get("ot_hours", 0.0))


# the scripted events of a day; Year 2 moves some of them by a day or two (Yeartwo.story_shuffle)
func events_on(day: int) -> Array:
	return Yeartwo.events_on("tech", day, DAYS)


func begin_day(day: int) -> void:
	_fired = {}
	_followed = false
	overtime = false
	ot_hours = 0.0
	Msp.new_day(day)


func _process(_delta: float) -> void:
	if not Campaign.active or Campaign.mode != "tech" or Game.title_mode or World.time_scale <= 0.0:
		return
	var events: Array = events_on(Campaign.day)
	for i in events.size():
		var ev: Dictionary = events[i]
		if not _fired.has(i) and World.clock >= _at(ev, i):
			_fired[i] = true
			fire(ev)
	if not _followed and World.clock >= 9.4:
		_followed = true
		_spawn_followups()
		Incident.tech_morning()


# cozy Easy, day 1: the welcome mail and Dan's offer come in the first seconds, not after the walk-in half hour
func _at(ev: Dictionary, index: int) -> float:
	if Campaign.day == 1 and Difficulty.cozy_on():
		return minf(float(ev.at), World.DAY_START - 0.4 + 0.1 * float(index))
	return float(ev.at)


# trouble from sloppy jobs comes back the next morning
func queue_followup(item: Dictionary) -> void:
	var entry := item.duplicate()
	entry["due"] = Campaign.day + int(item.get("days", 1))
	var list: Array = flags.get("followups", [])
	list.append(entry)
	flags["followups"] = list


func _spawn_followups() -> void:
	var list: Array = flags.get("followups", [])
	var keep := []
	for item in list:
		if int(item.due) <= Campaign.day:
			Msp.return_or_hold(item)  # X10: waits for a free slot when the queue is full
		else:
			keep.append(item)
	flags["followups"] = keep


func fire(ev: Dictionary) -> void:
	match str(ev.kind):
		"mail":
			Msp.mail(str(ev.from), str(ev.subject), str(ev.body))
		"text":
			Msp.send_text(str(ev.from), str(ev.body))
		"backup_break":
			Msp.break_backup(int(ev.client))
		"ransomware":
			_ransomware()
		"playbook":
			Playbook.start(str(ev.book))
			Msp.send_text("Boss", str(ev.get("text", "A big job just came in.")))
		"vignette", "mentor":
			_vignette(str(ev.id))  # "mentor" is Dan's days 1-3, kept apart from the vignettes the Year 2 shuffle moves
		"metrics":
			_friday()
		"postmortem":
			Incident.tech_start(str(ev.cls))
		"adobe":
			Msp.problem_or_hold(int(ev.client), Msp.ADOBE, "email")  # X10: not time-critical, waits for a free slot
		"callback_install":
			_callback_install()
		"callback_ransom":
			_callback_ransom()
		"callback_worst":
			_callback_worst()
		"growth_plan":
			Growth.start_plan()
		"growth_block":
			if not Expo.away:
				Growth.offer_block()
		"growth_stretch":
			if not Expo.away:
				Growth.offer_stretch()
		"install":
			var t := Msp.create_problem(0, Msp.INSTALL, "email")
			Msp.start_project(int(t.get("id", 0)))
		"install_followup":
			if flags.get("install", "") == "lost":
				Msp.mail(
					"Dr. Patel <patel@acmedental.example>",
					"XRAY STILL MISSING",
					"I spent the evening reloading the xray software from CDs. Never again. - Patel"
				)
				(
					Msp
					. send_text(
						"Boss",
						"Acme lost their xray software in the migration. Always survey and back up first."
					)
				)


# ---- small quiet-day moments: a short card with a few choices and small effects
func _vignette(id: String) -> void:
	if id.begins_with("mentor_") and id != "mentor_intro" and str(flags.get("mentor", "")) != "on":
		return  # Dan only checks in on the days after you took his offer
	var v: Dictionary = VIGNETTES.get(id, {})
	if v.is_empty():
		return
	var options := []
	for o in _vopts(id, v):
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		str(v.speaker),
		_vignette_text(id, v),
		options,
		func(pick: String) -> void: _vignette_answer(id, pick)
	)


# R37: after a wire fraud review that added a check, Brightside's bookkeeper calls back first
func _checked(id: String) -> bool:
	return id == "invoice" and bool(flags.get("pm_eff_check", false))


func _vopts(id: String, v: Dictionary) -> Array:
	return v.options_checked if _checked(id) else v.options


# Alan's donut card follows how the firewall day went: only a documented firewall has a page to praise
# Adam's Friday review: the last five days from the metrics record, and one of three cards by how they went
func week_stats() -> Dictionary:
	var out := {"opened": 0, "closed": 0, "missed": 0, "backlog": Msp.open_tickets().size()}
	for e in Msp.Dash.recent(5):
		out.opened += int(e.opened)
		out.closed += int(e.closed)
		out.missed += int(e.missed)
	return out


func friday_card(stats: Dictionary) -> String:
	if int(stats.missed) == 0 and int(stats.backlog) <= 3:
		return "adam_friday_good"
	if int(stats.missed) <= 2 and int(stats.backlog) <= 5:
		return "adam_friday_ok"
	return "adam_friday_bad"


func _friday() -> void:
	var stats := week_stats()
	if int(stats.opened) == 0 and int(stats.closed) == 0:
		return  # nothing on the board to read
	_vignette(friday_card(stats))


func _fill_week(text: String) -> String:
	if not text.contains("{closed}"):
		return text
	var stats := week_stats()
	return text.replace("{closed}", str(stats.closed)).replace("{missed}", str(stats.missed)).replace("{backlog}", str(stats.backlog))


func _vignette_text(id: String, v: Dictionary) -> String:
	return _fill_week(_vignette_text_raw(id, v))


func _vignette_text_raw(id: String, v: Dictionary) -> String:
	if id == "invoice" and _checked(id):
		return str(v.text_checked)
	if id == "donuts" and not bool(flags.get("bus_doc", false)):
		return str(v.get("text_reset" if bool(flags.get("bus_reset", false)) else "text_plain", v.text))
	return str(v.text)


func _vignette_answer(id: String, pick: String) -> void:
	var v: Dictionary = VIGNETTES[id]
	var text := ""
	for o in _vopts(id, v):
		if str(o.id) == pick:
			text = str(o.text)
			_vignette_fx(o.get("fx", {}))
	Cards.ask(str(v.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _vignette_fx(fx: Dictionary) -> void:
	if fx.has("flag"):
		flags[str(fx.flag[0])] = fx.flag[1]
	if fx.has("xp"):
		Skills.add_xp(str(fx.xp[0]), int(fx.xp[1]))
	if fx.has("mood"):
		Sales.adjust(int(fx.mood[0]), int(fx.mood[1]))
	if fx.has("mood_all"):
		for c in Sales.active:
			Sales.adjust(int(c), int(fx.mood_all))
	if fx.has("rep"):
		Campaign.adjust_rep(int(fx.rep))
	for who in fx.get("social", {}):
		Social.change(str(who), int(fx.social[who]))
	if fx.has("social_all"):
		Social.change_all(int(fx.social_all))
	if fx.has("energy"):
		Shift.add_energy(float(fx.energy))
	if fx.has("hours"):
		World.clock += float(fx.hours)


# ---- earlier choices come back later
func _callback_install() -> void:
	var from := "Dr. Patel <patel@acmedental.example>"
	match str(flags.get("install", "")):
		"ok":
			(
				Msp
				. mail(
					from,
					"The new computer",
					"Two weeks in and the whole front desk asks who set up the new PC. The xray software even runs faster. Thank you. - Patel"
				)
			)
			Sales.adjust(0, 6)
		"restored":
			(
				Msp
				. mail(
					from,
					"The new computer",
					"It took an extra day to get the xray software back, but it works. Next time, please ask what I keep on there first. - Patel"
				)
			)
			Sales.adjust(0, 1)
		"lost":
			(
				Msp
				. mail(
					from,
					"Still thinking about the xray software",
					"My staff still talk about the week we spent reloading from CDs. I am asking for a quote from another IT company. - Patel"
				)
			)
			Sales.adjust(0, -8)


func _callback_ransom() -> void:
	var from := "Atty. Spence <spence@hootholler.example>"
	match str(flags.get("ransom", "")):
		"saved":
			(
				Msp
				. mail(
					from,
					"Renewal",
					"After what happened in March, the partners voted to sign a three year renewal. A colleague at another firm asked for your number. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, 8)
			Campaign.adjust_rep(1)
		"partial":
			(
				Msp
				. mail(
					from,
					"Recovered files",
					"We got most of the files back. Two clients' records are gone and I had to call them. The partners are watching your work closely. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, -4)
		"paid":
			(
				Msp
				. mail(
					from,
					"The ransom",
					"The partners still cannot believe we paid criminals in bitcoin. It worked, but we want a real backup plan, now. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, -3)
		"vendor":
			Msp.mail(from, "Recovered files", "The backup vendor found an older copy and we lost nothing. Please keep that service. - Spence")
			Sales.adjust(RANSOM_CLIENT, 3)
		"rebuilt":
			Msp.mail(from, "Rebuilt server", "The machine is clean, but a month of case notes is gone and I had to call clients. We want a real backup plan. - Spence")
			Sales.adjust(RANSOM_CLIENT, -6)
		"insured":
			Msp.mail(from, "The insurance claim", "Our insurer got the files back and now wants a security review from us. Fair enough. - Spence")
			Sales.adjust(RANSOM_CLIENT, -1)
		"lost":
			(
				Msp
				. mail(
					from,
					"Reviewing our IT provider",
					"We lost two years of client files and had to tell the bar association. The partners are reviewing every IT provider in the county. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, -12)


# before the review Morgan brings up the job that went worst
func _callback_worst() -> void:
	var names := {
		"install": "THE DESKTOP INSTALL",
		"ransom": "THE RANSOMWARE",
		"rack": "THE FALLEN RACK",
		"migration": "THE SERVER MIGRATION",
		"email24": "THE EMAIL NIGHT",
		"netinstall": "THE NETWORK INSTALL",
		"ceofraud": "THE WIRE FRAUD",
		"no2fa": "THE CLIENT WHO SAID NO",
		"bus": "THE DAY WITHOUT ALAN",
	}
	var scores := {
		"S": 5,
		"A": 4,
		"B": 3,
		"C": 2,
		"D": 1,
		"ok": 5,
		"restored": 3,
		"lost": 1,
		"saved": 5,
		"partial": 3,
		"paid": 2
	}
	var worst_key := ""
	var worst := 99
	for key in names:
		var value := str(flags.get(key, ""))
		if value != "" and int(scores.get(value, 3)) < worst:
			worst = int(scores.get(value, 3))
			worst_key = key
	if worst_key == "" or worst >= 4:
		return
	(
		Msp
		. mail(
			MANAGER.split(" - ")[0] + " <morgan@pixelit.example>",
			"Before we sit down",
			(
				"I will ask about %s. It was your roughest job this year. Think about what you would do differently. - Morgan"
				% str(names[worst_key]).to_lower()
			)
		)
	)


func _ransomware() -> void:
	var t := Msp.create_problem(RANSOM_CLIENT, Msp.RANSOM, "monitoring")
	if t.is_empty():
		for ep in Msp.endpoints:
			if ep.client == RANSOM_CLIENT and ep.name.contains("SRV"):
				Msp.supersede(str(ep.name))
				ep.problem = ""
		t = Msp.create_problem(RANSOM_CLIENT, Msp.RANSOM, "monitoring")
	flags["ransom_ticket"] = int(t.get("id", 0))
	var warning := "Hoot and Holler has a ransom note on their server. "
	warning += "Do NOT pay and do NOT reboot. Restore from backup! (If it fails: shadow copies.)"
	Msp.send_text("Boss", warning)
