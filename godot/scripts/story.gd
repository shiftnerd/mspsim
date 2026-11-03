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
const DEFAULT_VIGNETTES := {
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
				+ "seconds. - Morgan"
			)
		},
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
	],
	11: [{"at": 10.0, "kind": "callback_install"}],
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
			"You are back on call from Monday. First snow is forecast, so expect traffic and worse. - Morgan"
		},
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
	17: [{"at": 11.0, "kind": "growth_block"}],
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


func begin_day(day: int) -> void:
	_fired = {}
	_followed = false
	overtime = false
	ot_hours = 0.0
	Msp.new_day(day)


func _process(_delta: float) -> void:
	if not Campaign.active or Campaign.mode != "tech" or Game.title_mode or World.time_scale <= 0.0:
		return
	var events: Array = DAYS.get(Campaign.day, [])
	for i in events.size():
		var ev: Dictionary = events[i]
		if not _fired.has(i) and World.clock >= float(ev.at):
			_fired[i] = true
			fire(ev)
	if not _followed and World.clock >= 9.4:
		_followed = true
		_spawn_followups()


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
			Msp.spawn_return(item)
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
		"vignette":
			_vignette(str(ev.id))
		"adobe":
			Msp.create_problem(int(ev.client), Msp.ADOBE, "email")
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
	var v: Dictionary = VIGNETTES.get(id, {})
	if v.is_empty():
		return
	var options := []
	for o in v.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		str(v.speaker), str(v.text), options, func(pick: String) -> void: _vignette_answer(id, pick)
	)


func _vignette_answer(id: String, pick: String) -> void:
	var v: Dictionary = VIGNETTES[id]
	var text := ""
	for o in v.options:
		if str(o.id) == pick:
			text = str(o.text)
			_vignette_fx(o.get("fx", {}))
	Cards.ask(str(v.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _vignette_fx(fx: Dictionary) -> void:
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
				ep.problem = ""
		t = Msp.create_problem(RANSOM_CLIENT, Msp.RANSOM, "monitoring")
	flags["ransom_ticket"] = int(t.get("id", 0))
	var warning := "Hoot and Holler has a ransom note on their server. "
	warning += "Do NOT pay and do NOT reboot. Restore from backup!"
	Msp.send_text("Boss", warning)
