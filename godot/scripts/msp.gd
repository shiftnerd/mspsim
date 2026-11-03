extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint: ignore=max-line-length
# Autoload: the managed-service-provider side of the game. Pixel IT Partners looks after a handful of silly
# small-business clients. Problems turn into tickets in the PSA (ConnectWhy PSA); the client
# emails you about them (Outlookish 2013); and the RMM (LabRat RMM) lets you remote into the
# client's PC to fix them. Your own office's network outages (the closet!) become internal
# tickets. Ticket SLA clocks run in real seconds scaled by
# World.time_scale, so they freeze on the title screen.

signal changed
signal ticket_added(ticket: Dictionary)
signal text_received(message: Dictionary)

const COMPANY := "Pixel IT Partners"
const MORGAN_FROM := "Morgan Reyes - Manager <morgan@pixelit.example>"
const CLIENTS := [
	{
		"name": "Acme Dental Group",
		"short": "ACME",
		"contact": "Dr. Patel",
		"mail": "patel@acmedental.example"
	},
	{
		"name": "Brightside Realty",
		"short": "BRSD",
		"contact": "Karen Whitfield",
		"mail": "karen@brightside.example"
	},
	{
		"name": "Gnarly Gnomes Landscaping",
		"short": "GNGN",
		"contact": "Bob Gnarly",
		"mail": "bob@gnarlygnomes.example"
	},
	{
		"name": "Hoot and Holler Law",
		"short": "HHLW",
		"contact": "Atty. Spence",
		"mail": "spence@hootholler.example"
	},
	{
		"name": "Soggy Bottom Brewing",
		"short": "SGBB",
		"contact": "Lucy Malt",
		"mail": "lucy@soggybottom.example"
	},
	{
		"name": "Piedmont Pediatrics",
		"short": "PEDI",
		"contact": "Dr. Okafor",
		"mail": "okafor@piedmontpeds.example"
	},
	{
		"name": "Rusty Anchor Marine Supply",
		"short": "RSTY",
		"contact": "Gil Anchor",
		"mail": "gil@rustyanchor.example"
	},
	{
		"name": "Zen Garden Yoga",
		"short": "ZENY",
		"contact": "Mina Park",
		"mail": "mina@zengarden.example"
	},
	{
		"name": "Paws and Claws Veterinary",
		"short": "PAWS",
		"contact": "Dr. Brandt",
		"mail": "brandt@pawsandclaws.example"
	},
	{
		"name": "Lindqvist and Moss Architects",
		"short": "LMAR",
		"contact": "Erik Lindqvist",
		"mail": "erik@lindqvistmoss.example"
	},
	{
		"name": "Iron Mule Demolition",
		"short": "IMUL",
		"contact": "Tony Marsh",
		"mail": "tony@ironmule.example"
	},
]
# fix = the RMM action that solves it; body uses %s for the contact's first name
const DEFAULT_PROBLEMS := [
	{
		"summary": "Printer will not print",
		"fix": "spooler",
		"pri": 3,
		"body": "Every time I hit print it just sits there. I deleted the jobs and it did nothing. The copier down the hall is on the network too. People are waiting. Please help! - %s"
	},
	{
		"summary": "Locked out of my PC",
		"fix": "password",
		"pri": 2,
		"body":
		"It says my account is locked out. I swear I did nothing. Can you just give me a temporary password, or make me a fresh login? I cannot work until this is fixed. - %s"
	},
	{
		"summary": "Computer is very slow",
		"fix": "clear_temp",
		"pri": 3,
		"body": "It takes ten minutes to open one document. I emptied the recycle bin and nothing changed. Last time somebody just wiped it. Is it the weather? - %s"
	},
	{
		"summary": "Computer frozen on a blue screen",
		"fix": "reboot",
		"pri": 2,
		"body":
		"There is a blue screen with a sad face on it. It has been like this since lunch. I tried the F8 menu but did not know what to pick. Do I need a new computer? - %s"
	},
	{
		"summary": "Pop-ups everywhere",
		"fix": "av",
		"pri": 2,
		"body":
		"Hundreds of pop-ups say I won a free cruise. Did I win a cruise? I reset my browser and they came right back. Also I cannot close them. - %s"
	},
	{
		"summary": "Server not responding - nobody can work",
		"fix": "reboot",
		"pri": 1,
		"server": true,
		"body":
		"THE SERVER IS DOWN. Nobody can open anything. Everyone is standing around. Somebody says restart the services, somebody else says roll it back to last night. FIX IT! - %s"
	},
]
var PROBLEMS: Array = DEFAULT_PROBLEMS.duplicate(true)
const DEFAULT_RANSOM := {
	"summary": "Files encrypted - ransom note on the server",
	"fix": "restore",
	"pri": 1,
	"server": true,
	"special": "ransomware",
	"body": "All our files have strange names and there is a note demanding bitcoin! HELP! - %s",
}
var RANSOM: Dictionary = DEFAULT_RANSOM.duplicate(true)
const DEFAULT_ADOBE := {
	"summary": "Adobe Reader will not print",
	"fix": "adobe",
	"pri": 4,
	"special": "adobe",
	"body": "I can open PDFs but print in Adobe Reader does nothing. Everything else prints, even from the browser. - %s",
}
var ADOBE: Dictionary = DEFAULT_ADOBE.duplicate(true)
const DEFAULT_INSTALL := {
	"summary": "Windows XP is ending: new desktop for Dr. Patel",
	"fix": "project",
	"pri": 3,
	"special": "install",
	"body":
	(
		"Microsoft is dropping support for Windows XP on April 8 and my old computer is on it. "
		+ "The new one arrived! Please set it up and move everything over. "
		+ "I am with patients all day. - %s"
	),
}
var INSTALL: Dictionary = DEFAULT_INSTALL.duplicate(true)
# what lives on the old PC: key = losing it is a disaster; hidden = you must find it
const INSTALL_ITEMS := [
	{
		"id": "docs",
		"name": "MY DOCUMENTS (OFFICE 2003 FILES)",
		"secs": 3.0,
		"key": true,
		"hidden": ""
	},
	{"id": "mail", "name": "OUTLOOK 2003 PROFILE + PST", "secs": 3.0, "key": true, "hidden": ""},
	{"id": "desktop", "name": "DESKTOP FILES", "secs": 1.5, "key": false, "hidden": ""},
	{"id": "printers", "name": "PRINTERS", "secs": 1.0, "key": false, "hidden": ""},
	{"id": "bookmarks", "name": "BROWSER BOOKMARKS", "secs": 1.0, "key": false, "hidden": ""},
	{
		"id": "xray",
		"name": "XRAY SOFTWARE + XP DRIVERS",
		"secs": 2.5,
		"key": true,
		"hidden": "both"
	},
	{"id": "drives", "name": "MAPPED DRIVES", "secs": 1.0, "key": false, "hidden": "deep"},
	{"id": "sticky", "name": "STICKY NOTES", "secs": 0.5, "key": false, "hidden": "ask"},
]
const FIXES := {
	"spooler": "RESTART PRINT SPOOLER",
	"password": "RESET PASSWORD",
	"clear_temp": "CLEAR TEMP FILES",
	"reboot": "REBOOT",
	"av": "RUN AV SCAN",
	"restore": "RESTORE BACKUP",
	"adobe": "REPAIR ADOBE READER",
	"shadow": "SHADOW COPIES",
	"pay": "PAY THE RANSOM",
	"save": "ASK USER TO SAVE",
}
# problems a reboot also clears (it works, but it is not the proper fix: the user is interrupted)
const ALT_FIXES := {"spooler": ["reboot"]}
# other valid fixes. kind: quick (fast, little XP, may come back 1-2 days later), heavy (slow, always
# works, costs the client something), clever (needs a skill level: faster, more XP).
# for = the problems it clears (server = a server only); mult = time vs the proper fix;
# xp = experience; mood/score = consequences; ret = chance it comes back; loses = restarts the PC
# (the user loses unsaved work they were not warned about; a blue-screened PC has none);
# back/back_body = the follow-up ticket
const ALT_DEFS := {
	"clear_queue":
	{
		"for": ["spooler"],
		"kind": "quick",
		"label": "CLEAR PRINT QUEUE",
		"mult": 0.4,
		"xp": 2,
		"ret": 0.45,
		"text": "Stuck jobs deleted. The printer wakes up, for now.",
		"note": "Deleted the stuck print jobs (the spooler itself was never restarted).",
		"back": "Printer stuck again",
		"back_body": "The printer worked for a day and now it just sits there again. - %s",
	},
	"reinstall_printer":
	{
		"for": ["spooler"],
		"kind": "heavy",
		"label": "REINSTALL PRINTER",
		"mult": 3.0,
		"xp": 3,
		"mood": -1,
		"text": "Driver removed and reinstalled. Slow, but the printer is solid now.",
		"note": "Removed and reinstalled the printer driver.",
	},
	"copier_route":
	{
		"for": ["spooler"],
		"kind": "clever",
		"label": "PRINT TO COPIER",
		"skill": "networking",
		"lvl": 2,
		"mult": 0.5,
		"xp": 6,
		"mood": 1,
		"text": "Mapped the hallway copier and made it their default printer. Back to work.",
		"note": "Pointed the user at the network copier while the spooler gets fixed later.",
	},
	"temp_pass":
	{
		"for": ["password"],
		"kind": "quick",
		"label": "GIVE TEMP PASSWORD",
		"mult": 0.4,
		"xp": 1,
		"ret": 0.5,
		"text": "Gave a temporary password over the phone. Please change it, please.",
		"note": "Read a temporary password over the phone (it will end up on a sticky note).",
		"back": "Locked out of my PC again",
		"back_body": "I wrote the temporary password on a sticky note and typed it wrong. Locked out again. - %s",
	},
	"new_profile":
	{
		"for": ["password"],
		"kind": "heavy",
		"label": "REBUILD PROFILE",
		"mult": 4.0,
		"xp": 3,
		"mood": -2,
		"loses": true,
		"text": "New domain profile built. Desktop and settings are back to factory.",
		"note": "Deleted and rebuilt the user's profile.",
	},
	"unlock_ps":
	{
		"for": ["password"],
		"kind": "clever",
		"label": "UNLOCK-ADACCOUNT",
		"skill": "powershell",
		"lvl": 2,
		"mult": 0.5,
		"xp": 6,
		"text": "One line of PowerShell unlocked the account and cleared the lockout source.",
		"note": "Unlocked the account with Unlock-ADAccount and killed the stale mapped drive.",
	},
	"recycle":
	{
		"for": ["clear_temp"],
		"kind": "quick",
		"label": "EMPTY RECYCLE BIN",
		"mult": 0.4,
		"xp": 2,
		"ret": 0.6,
		"text": "Recycle bin emptied. A few GB back, it will not last.",
		"note": "Emptied the recycle bin (the temp files are still there).",
		"back": "Computer is slow again",
		"back_body": "It was better for a day and now it is crawling again. The disk light never stops. - %s",
	},
	"disk_script":
	{
		"for": ["clear_temp"],
		"kind": "clever",
		"label": "CLEANUP SCRIPT",
		"skill": "powershell",
		"lvl": 3,
		"mult": 0.5,
		"xp": 6,
		"text": "Script cleared temp, old profiles and the update cache. Disk space is back.",
		"note": "Ran a cleanup script across the profile, temp and update cache folders.",
	},
	"browser_reset":
	{
		"for": ["av"],
		"kind": "quick",
		"label": "RESET BROWSER",
		"mult": 0.4,
		"xp": 1,
		"ret": 0.5,
		"text": "Browser reset to defaults. The pop-ups stopped, the adware did not.",
		"note": "Reset the browser settings (the adware is still installed).",
		"back": "Pop-ups are back",
		"back_body": "The pop-ups came back and now they have a new toolbar. Still no cruise. - %s",
	},
	"spyhunt":
	{
		"for": ["av"],
		"kind": "clever",
		"label": "SPYHUNT LOG SCAN",
		"skill": "security",
		"lvl": 2,
		"mult": 0.6,
		"xp": 7,
		"text": "SpyHunt log showed the startup entry. Removed it by hand, no full scan needed.",
		"note": "Read the SpyHunt log and removed the adware startup entry and its service by hand.",
	},
	"reimage":
	{
		"for": ["clear_temp", "av", "reboot"],
		"kind": "heavy",
		"label": "REIMAGE PC",
		"mult": 7.0,
		"xp": 3,
		"mood": -4,
		"loses": true,
		"text": "Reimaged from the gold image. Clean machine, but the user logs in to everything again.",
		"note": "Reimaged the PC from the gold image.",
	},
	"last_good":
	{
		"for": ["reboot"],
		"kind": "quick",
		"label": "LAST KNOWN GOOD",
		"mult": 0.6,
		"xp": 2,
		"mood": -1,
		"ret": 0.35,
		"text": "Booted the Last Known Good Configuration. Windows loads, for now.",
		"note": "Rebooted into Last Known Good Configuration (the driver is still bad).",
		"back": "Blue screen again",
		"back_body": "The blue screen is back, same as before. It came up fine for a day. - %s",
	},
	"safemode":
	{
		"for": ["reboot"],
		"kind": "clever",
		"label": "SAFE MODE DRIVER",
		"skill": "servers",
		"lvl": 2,
		"mult": 0.7,
		"xp": 7,
		"mood": -1,
		"text": "Safe mode, rolled back the bad driver, normal boot. Fixed for good.",
		"note": "Booted safe mode and rolled back the driver that caused the STOP error.",
	},
	"restart_services":
	{
		"for": ["reboot"],
		"server": true,
		"kind": "quick",
		"label": "RESTART SERVICES",
		"mult": 0.5,
		"xp": 2,
		"ret": 0.4,
		"text": "Restarted the file and mail services. Users are back, the cause is still there.",
		"note": "Restarted the key services (no root cause found).",
		"back": "Server slow and dropping again",
		"back_body": "The server is hanging again. Same as the other day. Everyone is waiting. - %s",
	},
	"snapshot":
	{
		"for": ["reboot"],
		"server": true,
		"kind": "heavy",
		"label": "ROLL BACK SNAPSHOT",
		"mult": 5.0,
		"xp": 3,
		"mood": -3,
		"score": -2,
		"text": "Rolled back to last night's snapshot. Up, but today's changes are gone.",
		"note": "Reverted the server VM to last night's snapshot (the day's file changes were lost).",
	},
	"event_log":
	{
		"for": ["reboot"],
		"server": true,
		"kind": "clever",
		"label": "FIND HUNG SERVICE",
		"skill": "servers",
		"lvl": 3,
		"mult": 0.6,
		"xp": 8,
		"mood": 1,
		"text": "The event log named the hung service. Fixed it without a reboot. Nobody noticed.",
		"note": "Read the event log, killed the hung service and patched the cause. No reboot.",
	},
	"print_browser":
	{
		"for": ["adobe"],
		"kind": "quick",
		"label": "PRINT FROM BROWSER",
		"mult": 0.3,
		"xp": 1,
		"ret": 0.6,
		"text": "Showed them how to open PDFs in the browser and print from there.",
		"note": "Workaround: open PDFs in the browser and print from there.",
		"back": "Adobe Reader still will not print",
		"back_body": "I opened another PDF in Reader and it will not print either. Please fix it properly. - %s",
	},
	"reader_reinstall":
	{
		"for": ["adobe"],
		"kind": "heavy",
		"label": "REINSTALL READER",
		"mult": 3.0,
		"xp": 3,
		"mood": -1,
		"text": "Uninstalled and reinstalled Adobe Reader. Printing works.",
		"note": "Uninstalled and reinstalled Adobe Reader.",
	},
}
const FIX_DONE_TEXT := {
	"spooler": "Print spooler restarted. Queued jobs are printing.",
	"password": "Password reset and account unlocked.",
	"clear_temp": "Cleared 41 GB of temp files. Disk space is back.",
	"reboot": "Rebooted. System is responding.",
	"av": "Scan finished. 407 threats removed (mostly cruise related).",
	"restore": "Restored from the last good backup.",
	"adobe": "Adobe Reader repaired. Printing works again.",
	"shadow": "Recovered most files from the shadow copies.",
	"pay": "Ransom paid. The files are decrypted.",
	"save": "The user saved their work.",
}
const SLA_SECS := {1: 120.0, 2: 200.0, 3: 300.0, 4: 480.0}
# gentle first days: random tickets allowed per day in the tech campaign (day -> cap)
const DAY_CAPS := {1: 1, 2: 3, 3: 5}
const OS_NAMES := ["Windows 7 Pro", "Windows 7 Pro", "Windows 8.1", "Windows XP SP3"]
const USERS := ["front desk", "office manager", "owner", "bookkeeper", "intern"]
const DESK_NAMES := {
	1: "Main floor desk 1",
	2: "Main floor desk 2 (Maya)",
	3: "Main floor desk 3",
	4: "Cubicle 4",
	5: "Cubicle 5",
	6: "Office 1",
	7: "Office 2",
	8: "The copier",
}

var tickets: Array = []
var emails: Array = []
var texts: Array = []  # {from, body, unread}: SMS on the cell phone
var endpoints: Array = []  # {name, client, user, os, problem}
var score := 0
var closed_ok := 0
var breached := 0
var reopened := 0
var backups: Array = []  # per client: {ok, good_day, checked_day}
var project := {}  # the install project in progress (see start_project)
var enabled := true  # false = free play / film mode: no random tickets, texts or SLA pressure
var pace := 1.0  # campaign difficulty: ticket spawn interval multiplier
var spawned_today := 0  # random tickets so far today (see DAY_CAPS)

var _next_id := 10421
var _next_mail := 1
var _spawn_t := 20.0
var _down := {}  # desk -> seconds without network
var _up := {}  # desk -> seconds with network
var _internal := {}  # desk -> ticket id of the open internal ticket


func _ready() -> void:
	randomize()
	reset()


func reset() -> void:
	tickets.clear()
	emails.clear()
	texts.clear()
	endpoints.clear()
	score = 0
	closed_ok = 0
	breached = 0
	reopened = 0
	pace = 1.0
	_next_id = 10421
	_next_mail = 1
	_spawn_t = 20.0
	_down.clear()
	_up.clear()
	_internal.clear()
	_later.clear()
	backups.clear()
	project = {}
	for c in CLIENTS.size():
		backups.append({"ok": true, "good_day": 0, "checked_day": -1})
	for c in CLIENTS.size():
		for n in 3:
			endpoints.append(_endpoint(c, "PC-%02d" % (n + 1), OS_NAMES[randi() % OS_NAMES.size()]))
		endpoints.append(_endpoint(c, "SRV-01", "Server 2008 R2"))
	_mail(
		COMPANY + " HR",
		"Welcome to the service desk",
		(
			"Welcome aboard! Open the PSA to see the ticket board, use the RMM to fix client PCs, and watch "
			+ "your inbox. If your own computer says it has no network, check the closet. - HR"
		),
		0
	)
	send_text("Dispatch", "Welcome! Press P for your phone. I will text you about urgent tickets.")


func _endpoint(client: int, suffix: String, os_name: String) -> Dictionary:
	return {
		"name": "%s-%s" % [CLIENTS[client].short, suffix],
		"client": client,
		"user": USERS[randi() % USERS.size()] if not suffix.begins_with("SRV") else "server",
		"os": os_name,
		"problem": "",
		"unsaved": false,
		"asked": false,
	}


func endpoint(name: String) -> Dictionary:
	for ep in endpoints:
		if ep.name == name:
			return ep
	return {}


func ticket(id: int) -> Dictionary:
	for t in tickets:
		if t.id == id:
			return t
	return {}


func open_tickets() -> Array:
	var out := []
	for t in tickets:
		if t.status != "Closed":
			out.append(t)
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.pri < b.pri or (a.pri == b.pri and a.sla_left < b.sla_left)
	)
	return out


func unread_texts() -> int:
	var n := 0
	for m in texts:
		if m.unread:
			n += 1
	return n


func send_text(from_name: String, body: String) -> void:
	var m := {"from": Roles.sender(from_name), "body": body, "unread": true}
	texts.push_front(m)
	text_received.emit(m)
	changed.emit()


func unread() -> int:
	var n := 0
	for m in emails:
		if m.unread:
			n += 1
	return n


func client_text(t: Dictionary) -> String:
	return COMPANY + " (internal)" if t.client < 0 else CLIENTS[t.client].name


# ---- tickets -----------------------------------------------------------------
func create_ticket(client: int, problem: int, source: String) -> Dictionary:
	return create_problem(client, PROBLEMS[problem], source)


# force: a story job must always get its ticket, even when every machine of the client is already broken
func create_problem(
	client: int, prob: Dictionary, source: String, force := false
) -> Dictionary:
	var contact: String = CLIENTS[client].contact
	var eps := []
	for ep in endpoints:
		var is_server: bool = ep.name.contains("SRV")
		if ep.client == client and ep.problem == "" and is_server == prob.get("server", false):
			eps.append(ep)
	if eps.is_empty() and force:
		if prob.get("server", false):
			for ep in endpoints:
				if ep.client == client and ep.name.contains("SRV"):
					eps.append(ep)  # the one server: the bigger job takes it over
		else:
			var count := 0
			for ep in endpoints:
				if ep.client == client and not ep.name.contains("SRV"):
					count += 1
			var extra := _endpoint(client, "PC-%02d" % (count + 1), "Windows 7 Pro")
			endpoints.append(extra)
			eps.append(extra)
	if eps.is_empty():
		return {}
	var picked: Dictionary = eps[randi() % eps.size()]
	picked.problem = prob.fix
	picked["unsaved"] = randf() < 0.65  # somebody is working on it: documents are open
	picked["asked"] = false
	picked.erase("restore_failed")
	picked.erase("shadow_tried")
	var t := {
		"id": _next_id,
		"client": client,
		"contact": contact,
		"summary": prob.summary,
		"pri": prob.pri,
		"body": prob.body % contact.split(" ")[0],
		"status": "New",
		"sla_left": SLA_SECS[prob.pri],
		"sla_total": SLA_SECS[prob.pri],
		"endpoint": picked.name,
		"fix": prob.fix,
		"fix_done": false,
		"notes": ["Ticket created by " + source + "."],
		"internal": false,
		"special": prob.get("special", ""),
		"desk": 0,
		"source": source,
		"breached": false,
	}
	_next_id += 1
	tickets.append(t)
	_mail(contact + " <" + CLIENTS[client].mail + ">", t.summary, t.body, t.id)
	ticket_added.emit(t)
	if t.pri <= 2:
		send_text("Dispatch", "P%d #%d %s - %s" % [t.pri, t.id, t.summary, CLIENTS[client].name])
	changed.emit()
	return t


func day_cap() -> int:
	if Campaign.active and Campaign.mode == "tech":
		return int(DAY_CAPS.get(Campaign.day, 99))
	return 99


func _random_ticket(source: String) -> Dictionary:
	if spawned_today >= day_cap():
		return {}
	for tries in 6:
		var t := create_ticket(Sales.pick_client(), randi() % PROBLEMS.size(), source)
		if not t.is_empty():
			spawned_today += 1
			return t
	return {}


# answering the phone at a desk: a client is on the line with a problem
func phone_call(_desk: int) -> void:
	Social.note_call_answered()
	if not Game.title_mode and enabled:
		_random_ticket("phone call")


func create_internal(desk: int, summary: String, body: String) -> void:
	var t := {
		"id": _next_id,
		"client": -1,
		"contact": DESK_NAMES.get(desk, "Staff"),
		"summary": summary,
		"pri": 2,
		"body": body,
		"status": "New",
		"sla_left": SLA_SECS[2],
		"sla_total": SLA_SECS[2],
		"endpoint": "",
		"fix": "network",
		"fix_done": false,
		"internal": true,
		"desk": desk,
		"source": "monitoring",
		"notes":
		(
			["Detected automatically."]
			+ (
				["Tip: check patch panel port %d in the closet." % desk]
				if Campaign.active and Skills.level("networking") >= 2
				else []
			)
		),
		"breached": false,
	}
	_next_id += 1
	tickets.append(t)
	_internal[desk] = t.id
	Social.note_outage(desk)
	_mail("Staff - " + str(DESK_NAMES.get(desk, "?")), summary, body, t.id)
	ticket_added.emit(t)
	changed.emit()


func set_status(id: int, status: String) -> void:
	var t := ticket(id)
	if not t.is_empty() and t.status != "Closed":
		t.status = status
		t.notes.append("Status: " + status + ".")
		changed.emit()


func add_note(id: int, text: String) -> void:
	var t := ticket(id)
	if not t.is_empty():
		t.notes.append(text)
		changed.emit()


# close a ticket: points if it was really fixed, otherwise it comes back with an angry email
func close_ticket(id: int) -> String:
	var t := ticket(id)
	if t.is_empty() or t.status == "Closed":
		return ""
	if not t.fix_done and t.fix == "restore":
		var ransomed := endpoint(str(t.endpoint))
		if not ransomed.is_empty() and ransomed.get("restore_failed", false):
			_ransom_lost(ransomed, "Gave up on the files. Data lost.")  # closing it is giving up
	if not t.fix_done:
		t.status = "In Progress"
		t.sla_left = maxf(t.sla_left, t.sla_total * 0.4)
		t.notes.append("Client reopened the ticket: still broken!")
		score -= 3
		reopened += 1
		Growth.note_escalation(t)
		Social.note_reopen()
		if not t.internal:
			Sales.adjust(int(t.client), -6)
		if not t.internal:
			_mail(
				CLIENTS[t.client].contact + " <" + CLIENTS[t.client].mail + ">",
				"RE: " + t.summary,
				"It is STILL not fixed. Why did you close this? Please try again.",
				t.id
			)
		changed.emit()
		return "REOPENED - NOT FIXED YET"
	t.status = "Closed"
	t.notes.append("Ticket closed.")
	if t.internal:
		_internal.erase(t.desk)
	if str(t.get("outcome", "")) == "lost":
		t.notes.append("Ticket closed. The data is gone.")
		changed.emit()
		return "CLOSED - DATA LOST"  # no points, and it does not count as a good close
	var points := 10 if not t.breached else 4
	if str(t.get("outcome", "")) in ["paid", "partial"]:
		points = 4
	score += points
	closed_ok += 1
	Career.note_ticket(str(t.fix))
	Skills.add_xp("networking" if t.internal else "people", 2)
	Social.note_ticket_closed(t)
	if not t.internal:
		Sales.adjust(int(t.client), 3 if t.breached else 5)
	changed.emit()
	return "CLOSED +%d" % points


# ---- the RMM -----------------------------------------------------------------
func rmm_action(name: String, action: String) -> String:
	var ep := endpoint(name)
	if ep.is_empty():
		return "NO SUCH ENDPOINT"
	var special := _rmm_special(ep, action)
	if special != "":
		return special
	if ep.problem == action and not action.begins_with("onsite_"):
		ep.problem = ""
		for t in tickets:
			if t.endpoint == name and t.status != "Closed" and t.fix == action:
				t.fix_done = true
				t.notes.append("Remote fix: " + FIXES[action].capitalize() + ".")
		Skills.add_xp(str(Skills.FIX_XP.get(action, "servers")), 4)
		changed.emit()
		return str(FIX_DONE_TEXT[action])
	if action == "reboot":
		return _reboot_other(ep)
	if ALT_DEFS.has(action):
		return _alt_fix(ep, action)
	return "DONE. NOTHING CHANGED."


# ---- other valid fixes (ALT_DEFS) -------------------------------------------------
var alt_roll := -1.0  # tests: a fixed roll for "does the workaround come back?"
var _later: Array = []  # follow-ups outside a campaign: {left, item}


func alt_unlocked(d: Dictionary) -> bool:
	var sk := str(d.get("skill", ""))
	if sk == "":
		return true
	if not Campaign.active:
		return false
	var lv: int = Skills.ps_level if sk == "powershell" else Skills.level(sk)
	return lv >= int(d.lvl)


# the other fixes on offer for this machine's problem
func alts_for(ep: Dictionary) -> Array:
	var out := []
	if str(ep.get("problem", "")) in ["", "restore", "project"]:
		return out
	var is_server: bool = ep.user == "server"
	for id in ALT_DEFS:
		var d: Dictionary = ALT_DEFS[id]
		if d["for"].has(str(ep.problem)) and bool(d.get("server", false)) == is_server:
			if alt_unlocked(d):
				out.append(id)
	return out


func alt_label(ep: Dictionary, id: String) -> String:
	var d: Dictionary = ALT_DEFS[id]
	var unsaved: bool = bool(ep.get("unsaved", false)) and not bool(ep.get("asked", false))
	var up: bool = bool(d.get("loses", false)) and unsaved and ep.problem != "reboot"
	if up and Skills.sees_open_docs():
		return str(d.label) + " !"
	return str(d.label)


func _alt_fix(ep: Dictionary, action: String) -> String:
	if not alts_for(ep).has(action):
		return "DONE. NOTHING CHANGED."
	var d: Dictionary = ALT_DEFS[action]
	var client := int(ep.client)
	var prob := str(ep.problem)
	var lost: bool = (
		bool(d.get("loses", false))
		and prob != "reboot"
		and bool(ep.get("unsaved", false))
		and not bool(ep.get("asked", false))
	)
	var tk := {}
	for t in tickets:
		if t.endpoint == str(ep.name) and t.status != "Closed" and t.fix == prob:
			tk = t
			t.fix_done = true
			t["method"] = str(d.kind)
			t.notes.append(str(d.note) + (" The user lost unsaved work." if lost else ""))
	if int(d.get("mood", 0)) != 0:
		Sales.adjust(client, int(d.mood))
	score += int(d.get("score", 0))
	Skills.add_xp(str(Skills.FIX_XP.get(prob, "servers")), int(d.xp))
	ep.problem = ""
	var text := str(d.text)
	if lost:
		_lose_work(ep, int(tk.get("id", 0)))
		text += " THE USER LOST UNSAVED WORK!"
	ep.unsaved = false
	ep.asked = false
	var roll := alt_roll if alt_roll >= 0.0 else randf()
	if roll < float(d.get("ret", 0.0)) and not tk.is_empty():
		_queue_return(tk, d, prob)
	changed.emit()
	return text


# a restart that cost somebody their unsaved work
func _lose_work(ep: Dictionary, ticket_id: int) -> void:
	var client := int(ep.client)
	Sales.adjust(client, -6)
	score -= 3
	var contact: Dictionary = CLIENTS[client]
	_mail(
		str(contact.contact) + " <" + str(contact.mail) + ">",
		"I LOST MY WORK!",
		(
			"You restarted my computer while I had a report open and I never saved it. "
			+ "Hours of work, gone. A warning would have taken ten seconds. - "
			+ str(contact.contact).split(" ")[0]
		),
		ticket_id
	)


# a workaround that did not hold: the same problem is back in 1-2 days (tech campaign) or soon
func _queue_return(t: Dictionary, d: Dictionary, prob: String) -> void:
	var item := {
		"client": int(t.client),
		"summary": str(d.back),
		"pri": int(t.pri),
		"body": str(d.back_body),
		"fix": prob,
		"server": str(t.endpoint).contains("SRV"),
		"esc": true,
	}
	t.notes.append("Only a workaround: this will probably come back.")
	if Campaign.active and Campaign.mode == "tech":
		item["days"] = 1 + randi() % 2
		Story.queue_followup(item)
	else:
		_later.append({"left": randf_range(150.0, 300.0), "item": item})


# the follow-up ticket for a workaround that came back (also used by Story's follow-ups)
func spawn_return(item: Dictionary) -> void:
	var prob := {
		"summary": item.summary,
		"fix": item.get("fix", "reboot"),
		"pri": item.pri,
		"body": item.body,
		"server": item.get("server", false),
	}
	var t := create_problem(int(item.client), prob, "email")
	if not t.is_empty() and bool(item.get("esc", false)):
		Growth.note_escalation(t)


# actions with their own rules: asking the user to save, and the ransomware options
func _rmm_special(ep: Dictionary, action: String) -> String:
	if action == "save":
		return _ask_save(ep)
	if ep.problem == "restore":
		if action == "pay":
			return _ransom_pay(ep)
		if action == "shadow":
			return _ransom_shadow(ep)
		if action == "restore":
			return _restore(ep)
	return ""


# what the REBOOT button says: whether the user could lose work
func reboot_label(ep: Dictionary) -> String:
	if ep.problem in ["reboot", "restore"] or ep.user == "server":
		return str(FIXES["reboot"])
	if bool(ep.get("asked", false)):
		return "REBOOT (USER WARNED)"
	if Skills.sees_open_docs():
		return "REBOOT (OPEN DOCS!)" if bool(ep.get("unsaved", false)) else "REBOOT (NOTHING OPEN)"
	return "REBOOT (ASK FIRST?)"


# ask the person at the machine to save before you touch it
func _ask_save(ep: Dictionary) -> String:
	ep["asked"] = true
	Skills.add_xp("people", 2)
	for t in tickets:
		if t.endpoint == str(ep.name) and t.status != "Closed":
			t.notes.append("Asked the user to save their work first.")
	changed.emit()
	if bool(ep.get("unsaved", false)):
		return "THE USER SAVED THEIR WORK. THANKS FOR ASKING."
	return "THEY HAD NOTHING OPEN. THANKS FOR ASKING."


# a reboot that is not the ticket's own fix: it may still clear the problem (ALT_FIXES) but the
# user is interrupted, and anyone with unsaved work who was not warned loses it
func _reboot_other(ep: Dictionary) -> String:
	if not ep.has("unsaved"):
		ep["unsaved"] = randf() < 0.5
	var client := int(ep.client)
	var lost: bool = bool(ep.unsaved) and not bool(ep.get("asked", false))
	var alt: bool = ALT_FIXES.get(str(ep.problem), []).has("reboot")
	var ticket_id := 0
	for t in tickets:
		if t.endpoint == str(ep.name) and t.status != "Closed":
			ticket_id = int(t.id)
			t.notes.append("Rebooted the PC" + (" (the user lost unsaved work)." if lost else "."))
			if alt and t.fix == ep.problem:
				t.fix_done = true
	Sales.adjust(client, -2)  # any needless reboot interrupts people
	var text := "REBOOTED. NOTHING CHANGED."
	if alt:
		Skills.add_xp(str(Skills.FIX_XP.get(str(ep.problem), "servers")), 2)
		ep.problem = ""
		text = "REBOOTED. FIXED, BUT RESTARTING THE SERVICE WOULD HAVE BEEN QUIETER."
	if lost:
		Sales.adjust(client, -6)
		score -= 3
		var contact: Dictionary = CLIENTS[client]
		_mail(
			str(contact.contact) + " <" + str(contact.mail) + ">",
			"I LOST MY WORK!",
			(
				"You restarted my computer while I had a report open and I never saved it. "
				+ "Hours of work, gone. A warning would have taken ten seconds. - "
				+ str(contact.contact).split(" ")[0]
			),
			ticket_id
		)
		text += " THE USER LOST UNSAVED WORK!"
	ep.unsaved = false
	ep.asked = false
	changed.emit()
	return text


# fix every endpoint of one client (or all clients) that has this problem: the PowerShell scripts
func rmm_bulk(client: int, action: String, all_clients: bool) -> int:
	var done := 0
	for ep in endpoints:
		var scriptable: bool = action != "restore" and action != "project"
		if ep.problem == action and (all_clients or ep.client == client) and scriptable:
			rmm_action(ep.name, action)
			done += 1
	return done


# ---- backups -------------------------------------------------------------------
func backup_check(client: int) -> Dictionary:
	var b: Dictionary = backups[client]
	b.checked_day = Campaign.day
	Skills.add_xp("security", 1)
	changed.emit()
	return b


func backup_rerun(client: int) -> void:
	var b: Dictionary = backups[client]
	for ep in endpoints:
		if ep.client == client and ep.problem == "restore":
			return  # the job would only copy the encrypted files
	if not b.ok:
		b.ok = true
		b.good_day = Campaign.day
		Skills.add_xp("security", 6)
		changed.emit()


func break_backup(client: int) -> void:
	var b: Dictionary = backups[client]
	if b.ok:
		b.ok = false
		b.good_day = Campaign.day - 1


# start of a campaign day: working jobs refresh, a few quietly fail overnight
func new_day(day: int) -> void:
	spawned_today = 0
	# a desktop sitting in its box: Vic reminds you where the job is, for a few days
	if Campaign.active and project_busy() and int(project.get("since", day)) < day:
		if int(project.get("nagged", 0)) < 3:
			project["nagged"] = int(project.get("nagged", 0)) + 1
			var waiting := ticket(int(project.ticket))
			if not waiting.is_empty() and waiting.status != "Closed":
				send_text(
					"Vic",
					(
						"%s is still waiting on the new desktop. Ticket #%d, RMM PROJECT tab on %s."
						% [CLIENTS[int(project.client)].contact, int(waiting.id), waiting.endpoint]
					)
				)
	if Campaign.active and Campaign.mode == "tech" and day == 1:
		_spawn_t = 75.0  # time to look around before the first ticket
	for c in backups.size():
		var b: Dictionary = backups[c]
		if not b.ok:
			continue
		if day >= 2 and c != Story.RANSOM_CLIENT and randf() < 0.08 and Campaign.active:
			b.ok = false
			b.good_day = day - 1
		else:
			b.good_day = day


func mmss(secs: float) -> String:
	var whole := maxi(0, int(secs))
	return "%d:%02d" % [whole / 60, whole % 60]


func project_busy() -> bool:
	return not project.is_empty() and not bool(project.done)


# ---- the desktop install project ------------------------------------------------
func start_project(ticket_id: int) -> void:
	project = {
		"ticket": ticket_id,
		"client": int(ticket(ticket_id).get("client", 0)),
		"found": {},
		"selected": {},
		"migrated": {},
		"backup": false,
		"verified": false,
		"done": false,
		"result": {},
		"since": Campaign.day,
		"nagged": 0,
	}
	for it in INSTALL_ITEMS:
		project.found[it.id] = it.hidden == ""
	changed.emit()


func project_secs(action: String) -> float:
	var base := {"scan": 4.0, "deep": 8.0, "backup": 6.0, "verify": 3.0}
	var secs := 0.0
	if action == "migrate":
		for it in INSTALL_ITEMS:
			if project.selected.get(it.id, false) and not project.migrated.get(it.id, false):
				secs += it.secs
	else:
		secs = float(base.get(action, 0.0))
	# PowerShell makes the copy scripts faster; 0 outside a campaign = instant
	var scale := Skills.fix_secs() / 6.0
	return secs * scale


func project_scan(deep: bool) -> void:
	for it in INSTALL_ITEMS:
		if deep and (it.hidden == "deep" or it.hidden == "both"):
			project.found[it.id] = true
	changed.emit()


func project_ask() -> void:
	for it in INSTALL_ITEMS:
		if it.hidden == "ask" or it.hidden == "both":
			project.found[it.id] = true
	changed.emit()


func project_backup() -> void:
	project.backup = true
	changed.emit()


func project_toggle(item_id: String) -> void:
	if project.found.get(item_id, false) and not project.migrated.get(item_id, false):
		project.selected[item_id] = not project.selected.get(item_id, false)
		changed.emit()


func project_select_all() -> void:
	for it in INSTALL_ITEMS:
		if project.found.get(it.id, false) and not project.migrated.get(it.id, false):
			project.selected[it.id] = true
	changed.emit()


func project_migrate() -> void:
	for it in INSTALL_ITEMS:
		if project.selected.get(it.id, false):
			project.migrated[it.id] = true
	changed.emit()


# checking with the user reveals everything that is still missing; returns those names
func project_verify() -> Array:
	var missing := []
	project.verified = true
	for it in INSTALL_ITEMS:
		if not project.migrated.get(it.id, false):
			project.found[it.id] = true
			missing.append(it.name)
	changed.emit()
	return missing


# hand the PC over: the old one is wiped, so what was not copied is gone (unless backed up)
func project_handover() -> Dictionary:
	if project.is_empty() or project.done:
		return project.get("result", {})
	var pts := 0
	var lost := []
	for it in INSTALL_ITEMS:
		if project.migrated.get(it.id, false):
			pts += 20 if it.key else 5
		elif it.key:
			lost.append(it.name)
	pts += 10 if project.backup else 0
	pts += 5 if project.verified else 0
	var t := ticket(int(project.ticket))
	if not t.is_empty() and t.breached:
		pts -= 10
	pts = clampi(pts, 0, 100)
	var grade := "D"
	for entry in [[92, "S"], [80, "A"], [65, "B"], [45, "C"]]:
		if pts >= entry[0]:
			grade = entry[1]
			break
	var rep_delta: int = {"S": 5, "A": 3, "B": 1, "C": -2, "D": -5}[grade]
	var outcome := "ok"
	if not lost.is_empty():
		outcome = "restored" if project.backup else "lost"
		rep_delta -= 3 if project.backup else 8
	score += int((pts - 50) / 2.5) - (0 if outcome != "lost" else 15)
	Campaign.adjust_rep(rep_delta)
	if outcome != "ok":
		Campaign.add_scar(8 if outcome == "lost" else 2)
	Skills.add_xp("servers", 10)
	project.done = true
	project.result = {"pts": pts, "grade": grade, "lost": lost, "outcome": outcome}
	Story.flags["install"] = outcome
	if not t.is_empty():
		t.fix_done = true
		t.notes.append("Handed over: grade %s (%d%%)." % [grade, pts])
		var endpoint_state := endpoint(str(t.endpoint))
		if not endpoint_state.is_empty():
			endpoint_state.problem = ""
		# the handover is the work: the ticket closes with it instead of sitting open for days
		if t.status != "Closed":
			t.status = "Closed"
			t.notes.append("Ticket closed with the handover.")
			if grade in ["S", "A", "B"] and outcome != "lost":
				closed_ok += 1
	var who: String = CLIENTS[int(project.client)].contact
	var address: String = who + " <" + CLIENTS[int(project.client)].mail + ">"
	var text := "Everything is just where I left it. Great job! - " + who
	if outcome == "lost":
		text = (
			"WHERE IS MY XRAY SOFTWARE? Patients are waiting and the old computer is wiped!! - "
			+ who
		)
	elif outcome == "restored":
		text = "We were missing the xray software, but you had a backup. Phew. - " + who
	elif grade in ["C", "D"]:
		text = "It works, but a lot of little things are missing. Please be more careful. - " + who
	_mail(address, "RE: " + INSTALL.summary, text, 0)
	changed.emit()
	return project.result


func mail(from_name: String, subject: String, body: String) -> void:
	_mail(from_name, subject, body, 0)
	changed.emit()


# ransomware: with a good backup it is a save; without one the restore fails and the other options stay open
func _restore(ep: Dictionary) -> String:
	var contact: String = CLIENTS[ep.client].contact
	var address: String = contact + " <" + CLIENTS[ep.client].mail + ">"
	var good: bool = backups[ep.client].ok
	if not good:
		var first: bool = not ep.get("restore_failed", false)
		ep["restore_failed"] = true
		for t in tickets:
			if t.endpoint == ep.name and t.status != "Closed" and t.fix == "restore" and first:
				t.notes.append(
					(
						"Backup restore FAILED: the last good copy is from day %d and unusable. "
						+ "Options left: shadow copies, pay the ransom, or give up the files."
					)
					% int(backups[ep.client].good_day)
				)
		if first:
			send_text("Boss", "The backup will not restore?! Try the shadow copies. Do not pay yet.")
		changed.emit()
		return "BACKUP FAILED. TRY SHADOW COPIES OR PAY."
	ep.problem = ""
	for t in tickets:
		if t.endpoint == ep.name and t.status != "Closed" and t.fix == "restore":
			t.fix_done = true
			t.notes.append("Restored from backup. No data lost.")
	score += 15
	Campaign.adjust_rep(5)
	Skills.add_xp("security", 15)
	_mail(
		address,
		"RE: " + RANSOM.summary,
		"Everything is back. You saved the whole firm. Thank you!!! - " + contact,
		0
	)
	Story.flags["ransom"] = "saved"
	changed.emit()
	return "RESTORED. NO DATA LOST."


# CryptoLocker (2013): with no backup you still have options, none of them good
func _ransom_close(ep: Dictionary, note: String, outcome := "lost") -> void:
	ep.problem = ""
	for t in tickets:
		if t.endpoint == ep.name and t.status != "Closed" and t.fix == "restore":
			t.fix_done = true
			t.outcome = outcome  # a lost recovery earns nothing when it is closed
			t.notes.append(note)


func _ransom_lost(ep: Dictionary, note: String) -> String:
	var contact: String = CLIENTS[ep.client].contact
	_ransom_close(ep, note)
	score -= 30
	Campaign.adjust_rep(-15)
	Campaign.add_scar(15)
	_mail(
		CLIENTS[ep.client].contact + " <" + CLIENTS[ep.client].mail + ">",
		"RE: " + RANSOM.summary,
		"Years of files are gone and nothing worked. We are reviewing our contract. - " + contact,
		0
	)
	send_text("Boss", "The files are gone and the backup was not there. We need to talk.")
	Story.flags["ransom"] = "lost"
	changed.emit()
	return "NOTHING WORKED. DATA LOST."


func _ransom_pay(ep: Dictionary) -> String:
	var contact: String = CLIENTS[ep.client].contact
	if randf() < 0.7:
		_ransom_close(ep, "Ransom paid in Bitcoin. Files decrypted.", "paid")
		score -= 5
		Campaign.adjust_rep(-2)
		Story.flags["ransom"] = "paid"
		_mail(
			CLIENTS[ep.client].contact + " <" + CLIENTS[ep.client].mail + ">",
			"RE: " + RANSOM.summary,
			(
				"The files are back, but we paid criminals and the whole firm is shaken. "
				+ "Make sure it never happens again. - "
				+ contact
			),
			0
		)
		changed.emit()
		return "RANSOM PAID. FILES DECRYPTED."
	return _ransom_lost(ep, "The criminals took the money and never sent the key.")


func _ransom_shadow(ep: Dictionary) -> String:
	if ep.get("shadow_tried", false):
		return "NO SHADOW COPIES LEFT. TRY SOMETHING ELSE."
	if randf() < 0.4:
		var contact: String = CLIENTS[ep.client].contact
		_ransom_close(ep, "Recovered most files from shadow copies. Some are gone.", "partial")
		score -= 8
		Campaign.adjust_rep(-3)
		Story.flags["ransom"] = "partial"
		_mail(
			CLIENTS[ep.client].contact + " <" + CLIENTS[ep.client].mail + ">",
			"RE: " + RANSOM.summary,
			(
				"Most of our files are back, a few are gone for good. Thank you for trying. - "
				+ contact
			),
			0
		)
		changed.emit()
		return "SHADOW COPIES RECOVERED MOST FILES."
	ep["shadow_tried"] = true
	return "NO SHADOW COPIES LEFT. TRY SOMETHING ELSE."


# ---- clock -------------------------------------------------------------------
func _process(delta: float) -> void:
	if Game.title_mode or not enabled:
		return
	var dt := delta * World.time_scale
	if dt <= 0.0:
		return
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(45.0, 90.0) * pace / maxf(0.5, Sales.workload()) / Owner.issue_mult()
		if open_tickets().size() < 6 and World.clock < World.DAY_END:
			_random_ticket("email")
	for i in range(_later.size() - 1, -1, -1):
		_later[i].left -= dt
		if _later[i].left <= 0.0:
			var item: Dictionary = _later[i].item
			_later.remove_at(i)
			spawn_return(item)
	for t in tickets:
		if t.status != "Closed" and t.status != "Waiting":
			t.sla_left -= dt * Skills.sla_pace()
			if t.sla_left <= 0.0 and not t.breached:
				t.breached = true
				breached += 1
				score -= 5
				if int(t.pri) == 1:
					Campaign.add_scar(2)  # an unworked P1 is remembered
				Growth.note_escalation(t)
				if not t.internal:
					Sales.adjust(int(t.client), -8)
				_mail(
					"Pixel IT Partners - Manager",
					"SLA breached on #%d" % t.id,
					"Ticket #%d (%s) blew its SLA. Please look at it." % [t.id, t.summary],
					t.id
				)
				send_text("Boss", "#%d blew its SLA: -5 score, client mood -8. Why?" % t.id)
	_watch_desks(dt)


# our own network trouble becomes tickets; they resolve themselves once the desk is back online
func _watch_desks(dt: float) -> void:
	for d in range(1, 9):
		var state := Net.desk_state(d)
		if state != "ok":
			_down[d] = float(_down.get(d, 0.0)) + dt
			_up[d] = 0.0
			if _down[d] >= 8.0 and not _internal.has(d):
				var what := "no network cable" if state == "no_link" else "no internet"
				create_internal(
					d,
					"%s: %s" % [DESK_NAMES[d], what],
					(
						"Help! The computer here has "
						+ what
						+ ". Nothing loads. Can someone check the closet? - Staff"
					)
				)
		else:
			_down[d] = 0.0
			_up[d] = float(_up.get(d, 0.0)) + dt
			if _internal.has(d) and _up[d] >= 3.0:
				var t := ticket(_internal[d])
				if not t.is_empty() and not t.fix_done and t.status != "Closed":
					t.fix_done = true
					t.status = "Resolved"
					t.notes.append("Network restored.")
					Social.note_outage_fixed(d)
					changed.emit()


func _mail(from_name: String, subject: String, body: String, ticket_id: int) -> void:
	if from_name.begins_with("Morgan"):
		from_name = MORGAN_FROM  # one sender format for the manager, whichever way the story wrote it
	emails.push_front(
		{
			"id": _next_mail,
			"from": from_name,
			"subject": subject,
			"body": body,
			"unread": true,
			"ticket": ticket_id
		}
	)
	_next_mail += 1
