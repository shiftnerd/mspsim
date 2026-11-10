extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P4: inherited messes (docs/scope-bad-habits.md section 3). A static helper like Incident.
# A client that switches to you from a rival is a takeover onboarding: an onsite visit of the kind "takeover". The state is
# Owner.inherit: client -> inherited risk 0-100 (starts at the unresolved findings x 15, each fixed finding drops it, saved with the campaign).
# The visit: Onsite meets the owner with MEETING, every object you inspect shows the next of the six FINDINGS_TAKEOVER (a card: take the
# Playbook job, patch it now, sell it as a project, or note it), and leaving grades the visit. The six jobs are Playbook books (BOOKS and
# PROBLEMS below, merged into Playbook.BOOKS / PROBLEMS); finishing one calls outcome(), which fixes the finding and proves the rap.
# Per client state (saved in Owner.flags["tk_<client>"]): {found: [job ids], acted: [job ids], done: [job ids]}.
# All the text is here (3x5 font, 2013-14, no names from the blog series).

const Rival := preload("res://scripts/rival.gd")
const Habits := preload("res://scripts/habits.gd")

const ENABLED := true
const KIND := "takeover"
const PER_FINDING := 15  # inherited risk per unresolved finding
const RIVAL := "bigcheese"
const OPEN_RESTORE_FAIL := 0.6  # an unfixed freezer bag fails a restore this often

# the six jobs: name (card text), rap (the habit that becomes PROVEN when it is done), twin (the good habit it teaches)
const JOBS := {
	"T1": {"name": "THE FREEZER BAG", "rap": "R01", "twin": "H1", "book": "tk_backup"},
	"T2": {"name": "STICKY NOTES AND THE ONE PASSWORD", "rap": "R02", "twin": "H7", "book": "tk_creds"},
	"T3": {"name": "THE DOOR THAT WAS ALWAYS OPEN", "rap": "R15", "twin": "H8", "book": "tk_firewall"},
	"T4": {"name": "GREEN AND EMPTY", "rap": "R04", "twin": "H11", "book": "tk_dashboard"},
	"T5": {"name": "DEFAULT PASSWORDS", "rap": "R15", "twin": "H14", "book": "tk_defaults"},
	"T6": {"name": "WHO STILL HAS A KEY", "rap": "R14", "twin": "H6", "book": "tk_keys"},
}
# the object that shows each job first (a site without that object shows the next job that is still hidden)
const PREFER := {"server": "T1", "pc": "T2", "cabinet": "T3", "vip": "T4", "printer": "T5", "exam": "T6", "xray": "T6"}

const TEXT := {
	"arrive": "WHAT DID BIG CHEESE LEAVE BEHIND? LOOK AROUND (E ON THE EQUIPMENT), THEN MEET THE OWNER.",
	"nothing": "NOTHING ELSE LEFT BEHIND HERE.",
	"title": "THEY LEFT THIS BEHIND",
	"job": "TAKE THE JOB (RMM, PROJECT TAB)",
	"job_busy": "THE RMM ALREADY HAS A JOB",
	"job_started": "THE JOB IS IN THE RMM, ON THE PROJECT TAB.",
	"quick": "PATCH IT NOW (%d H)",
	"quick_done": "PATCHED FOR NOW. THE REAL FIX STILL WAITS.",
	"project": "SELL IT AS A PROJECT",
	"project_sold": "THEY ASKED FOR A PROPOSAL.",
	"note": "MAKE A NOTE FOR LATER",
	"noted": "NOTED. IT IS STILL OUT THERE.",
	"fresh": "A FRESH START. THEY SIT UP A LITTLE STRAIGHTER.",
	"go_on": "GO ON",
	"left": "WHAT BIG CHEESE LEFT BEHIND: %d ITEMS FOUND, %d STILL OPEN. START MOOD %s.",
}

# the owner meeting of the visit (same shape as Onsite.MEETINGS rows)
const MEETING := {
	"text": "The owner shows you in and talks fast. Their old IT company has stopped answering calls, and nobody here can say what is in the closet. They would like a straight answer for once.",
	"options":
	[
		{
			"id": "list",
			"label": "ASK FOR EVERY LOGIN AND KEY",
			"text": "You ask who has a login, who has a key and who has the password. The owner goes quiet and opens a desk drawer."
		},
		{
			"id": "past",
			"label": "ASK HOW THE BACKUPS WORK",
			"text": "You ask how the backups work. The owner says the old IT man took care of it, and that it is in a bag, in a freezer."
		},
		{
			"id": "fresh",
			"label": "PROMISE A FRESH START",
			"text": "You promise a written list of what you find and no surprises. It is the first thing anyone has promised them in a year."
		},
	],
}

# the six walk-around findings (same shape as Onsite.FINDINGS entries, plus id, book, hours, drop, quick). text = the card.
const FINDINGS_TAKEOVER: Array = [
	{
		"id": "T1",
		"text": "A USB drive sits in a freezer bag on a shelf, next to the server. A green light is on. That is the whole backup, and the light is all anybody ever checked.",
		"summary": "Backup is one USB drive and nobody has tested it",
		"fix": "onsite_server",
		"pri": 2,
		"body": "%s here: we heard our backup is just one drive. Is that true?",
		"project": "backup_dr",
		"service": "",
		"hours": 2,
		"drop": 8,
		"quick": "You swap in a new drive and run one backup. Better than a freezer bag, and still never restored."
	},
	{
		"id": "T2",
		"text": "A yellow sticky note on the monitor says ADMIN and a password. The same password opens the server, the router and the mail. A second company the old shop looked after uses it too.",
		"summary": "One admin password is shared by every system",
		"fix": "av",
		"pri": 2,
		"body": "%s here: the password for everything is on a note. Please fix that.",
		"project": "security",
		"service": "",
		"hours": 1,
		"drop": 8,
		"quick": "You peel off the note and change the admin password. Nobody has the new one written anywhere yet."
	},
	{
		"id": "T3",
		"text": "The firewall forwards remote desktop and file transfer to the server. The rule is labelled TEMP, dated 2012, and was made for a vendor rep who left the company in 2013.",
		"summary": "Firewall has had a temporary hole open since 2012",
		"fix": "onsite_upgrade",
		"pri": 2,
		"body": "%s here: we were told our firewall has a hole in it. Please check.",
		"project": "security",
		"service": "",
		"hours": 1,
		"drop": 8,
		"quick": "You disable the old rule and save the config. It is only a patch on a ten year old router."
	},
	{
		"id": "T4",
		"text": "The monitoring dashboard is all green. You look at it twice: there is not one alert policy and no alert in fourteen months. Green does not mean fine here. It means nobody asked.",
		"summary": "Monitoring was never set up: green because nothing is watched",
		"fix": "av",
		"pri": 3,
		"body": "%s here: our dashboard says all is well. Is it really?",
		"project": "",
		"service": "patching",
		"hours": 2,
		"drop": 8,
		"quick": "You turn on antivirus alerts and leave the rest. The first alerts roll in before you reach the car."
	},
	{
		"id": "T5",
		"text": "The printer and the ceiling camera both still answer to admin and admin. So does the wireless box. The sticker with the default password is still on the back of each one.",
		"summary": "Printer, camera and wireless still use default passwords",
		"fix": "spooler",
		"pri": 3,
		"body": "%s here: someone said the camera has no real password. Please look.",
		"project": "security",
		"service": "",
		"hours": 1,
		"drop": 8,
		"quick": "You change the printer password and put the camera on your list. One out of three."
	},
	{
		"id": "T6",
		"text": "The account list shows four people who no longer work here and a login for the old vendor rep. One mailbox forwards every message to an address nobody can name.",
		"summary": "Ex-employees and a former rep still have working logins",
		"fix": "clear_temp",
		"pri": 2,
		"body": "%s here: a former employee says his login still works. Please check.",
		"project": "security",
		"service": "",
		"hours": 1,
		"drop": 8,
		"quick": "You disable the ex-employees and leave the rep's login for the owner to decide. Half the keys are still out."
	},
]

# ---- the six Playbook books (merged into Playbook.BOOKS and PROBLEMS; the client is set when the job starts) -----------------
const BOOKS := {
	"tk_backup":
	{
		"title": "THE FREEZER BAG",
		"client": 0,
		"specials": ["tk_backup"],
		"steps":
		[
			{
				"title": "FIND IT",
				"text": "The whole backup is one USB drive in a freezer bag. What do you do with it first?",
				"choices":
				[
					{"label": "PHOTOGRAPH THE BAG AND THE LIGHT", "secs": 3.0, "pts": 15, "hours": 0.1, "flag": "photo", "note": "Photographed. That is evidence."},
					{"label": "UNPLUG IT AND LOOK", "secs": 2.0, "pts": 5, "hours": 0.1, "note": "A drive with a label from 2011."},
				]
			},
			{
				"title": "TEST THE RESTORE",
				"text": "Does anything come back off that drive? There is a spare PC in the corner.",
				"choices":
				[
					{"label": "RESTORE TO THE SPARE PC", "secs": 10.0, "pts": 25, "hours": 0.7, "flag": "tested", "note": "The restore failed halfway. Now you know."},
					{"label": "TRUST THE LIGHT", "secs": 1.0, "pts": 0, "hours": 0.0, "flag": "trust", "note": "The light is on. That is all you know."},
				]
			},
			{
				"title": "PUT IT RIGHT",
				"text": "What replaces the freezer bag?",
				"choices":
				[
					{"label": "BACKUP SERVICE WITH AN OFFSITE COPY", "secs": 10.0, "pts": 35, "hours": 1.5, "needs": "tested", "needs_label": "NEEDS A TEST FIRST", "flag": "offsite", "note": "Nightly backup, copied offsite."},
					{"label": "REPLACE THE DRIVE, CALL IT DONE", "secs": 5.0, "pts": 10, "hours": 0.5, "flag": "swapped", "note": "A newer bag, a newer drive."},
					{"label": "LEAVE THE BAG, ADD A NOTE", "secs": 1.0, "pts": 0, "hours": 0.0, "flag": "open", "note": "The bag stays. The note will not help."},
				]
			},
			{
				"title": "WRITE THE TIME DOWN",
				"text": "How long to get this office back after a bad day? Nobody knows.",
				"choices":
				[
					{"label": "WRITE DOWN THE RECOVERY TIME", "secs": 4.0, "pts": 15, "hours": 0.2, "flag": "rto", "note": "One page, taped inside the closet door."},
					{"label": "SKIP THE PAPER", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "No paper. They will ask again."},
				]
			},
		],
	},
	"tk_creds":
	{
		"title": "STICKY NOTES",
		"client": 0,
		"specials": ["tk_creds"],
		"steps":
		[
			{
				"title": "AUDIT THE PASSWORD",
				"text": "One admin password, written on a note. Where else does it work?",
				"choices":
				[
					{"label": "LIST EVERY PLACE IT WORKS", "secs": 6.0, "pts": 20, "hours": 0.4, "flag": "audited", "note": "It opens the server, the router, the mail and a second company's file share."},
					{"label": "CHANGE JUST THIS ONE", "secs": 2.0, "pts": 5, "hours": 0.1, "flag": "partial", "note": "Fixed one door of many."},
				]
			},
			{
				"title": "ROTATE IT ALL",
				"text": "Every login gets a new password. Where do the new ones live?",
				"choices":
				[
					{"label": "UNIQUE PASSWORDS, KEPT IN A VAULT", "secs": 8.0, "pts": 30, "hours": 1.0, "note": "A password manager. One master phrase on paper in the owner's safe."},
					{"label": "A NEW PASSWORD, SAME NOTE", "secs": 2.0, "pts": 0, "hours": 0.1, "flag": "noted", "note": "The note is back on the monitor by lunch."},
				]
			},
			{
				"title": "BREAK-GLASS ACCOUNT",
				"text": "If you are not reachable, can the owner still get in?",
				"choices":
				[
					{"label": "A SEALED BREAK-GLASS ACCOUNT", "secs": 5.0, "pts": 20, "hours": 0.3, "flag": "breakglass", "note": "One sealed envelope, one account, one log entry the day it is used."},
					{"label": "SKIP IT", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "No spare key."},
				]
			},
			{
				"title": "TELL THE CLIENT",
				"text": "That password was in use at two other companies. Do you say what was exposed?",
				"choices":
				[
					{"label": "TELL THEM WHAT WAS EXPOSED", "secs": 3.0, "pts": 15, "hours": 0.2, "flag": "told", "note": "A hard talk. Then a thank you."},
					{"label": "STAY QUIET ABOUT IT", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "quiet", "note": "You say nothing. It may come out anyway."},
				]
			},
		],
	},
	"tk_firewall":
	{
		"title": "THE OPEN DOOR",
		"client": 0,
		"specials": ["tk_firewall"],
		"steps":
		[
			{
				"title": "READ THE RULES",
				"text": "Remote desktop and file transfer are forwarded to the server. The note says TEMP, 2012.",
				"choices":
				[
					{"label": "READ EVERY RULE AND THE LOG", "secs": 6.0, "pts": 20, "hours": 0.5, "flag": "read", "note": "Thousands of failed logins from far away. The door has been tried every night."},
					{"label": "GLANCE AT THE LIST", "secs": 2.0, "pts": 5, "hours": 0.1, "note": "A quick look. Plenty you did not read."},
				]
			},
			{
				"title": "CLOSE THE DOOR",
				"text": "How do you shut it?",
				"choices":
				[
					{"label": "CLOSE THE PORTS, ADD A VPN", "secs": 10.0, "pts": 35, "hours": 1.5, "req": ["networking", 2], "note": "Nothing is open. Staff come in through the VPN."},
					{"label": "TURN ON AUTO-BLOCKING", "secs": 6.0, "pts": 25, "hours": 0.7, "note": "Bad guesses get blocked. The door is still there."},
					{"label": "MOVE IT TO ANOTHER PORT", "secs": 3.0, "pts": 8, "hours": 0.2, "flag": "hole", "note": "Same door, new number."},
					{"label": "LEAVE IT", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "hole", "note": "The door stays open."},
				]
			},
			{
				"title": "THE FORMER REP",
				"text": "The rule was made for a vendor rep who left in 2013. His account is still on the router.",
				"choices":
				[
					{"label": "REMOVE HIS ACCOUNT AND LOG IT", "secs": 3.0, "pts": 15, "hours": 0.2, "note": "Removed. One line in the change log."},
					{"label": "LEAVE HIS ACCOUNT", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "He may still have the password."},
				]
			},
		],
	},
	"tk_dashboard":
	{
		"title": "GREEN AND EMPTY",
		"client": 0,
		"specials": ["tk_dashboard"],
		"steps":
		[
			{
				"title": "NOTICE",
				"text": "The dashboard is green. Why?",
				"choices":
				[
					{"label": "COUNT THE ALERTS OF THE LAST 14 MONTHS", "secs": 5.0, "pts": 20, "hours": 0.3, "flag": "counted", "note": "Zero alerts. No alert policy was ever made."},
					{"label": "TRUST THE GREEN", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "trust", "note": "Green is green."},
				]
			},
			{
				"title": "SET A BASELINE",
				"text": "Which agents do you set up?",
				"choices":
				[
					{"label": "ANTIVIRUS, PATCH WINDOW AND BACKUP ALERT", "secs": 8.0, "pts": 40, "hours": 1.0, "note": "Three policies. Everything old suddenly turns red."},
					{"label": "JUST THE ANTIVIRUS", "secs": 3.0, "pts": 10, "hours": 0.3, "flag": "partial", "note": "One policy. The rest stays blind."},
				]
			},
			{
				"title": "WARN THE TEAM",
				"text": "The first week of real alerts will be loud.",
				"choices":
				[
					{"label": "WARN THE TEAM AND THE OWNER", "secs": 2.0, "pts": 15, "hours": 0.1, "note": "A short note: it will look worse before it looks better."},
					{"label": "SAY NOTHING", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "flood", "note": "Nobody is ready for the flood."},
				]
			},
		],
	},
	"tk_defaults":
	{
		"title": "DEFAULT PASSWORDS",
		"client": 0,
		"specials": ["tk_defaults"],
		"steps":
		[
			{
				"title": "FIND THEM",
				"text": "The printer, the camera and the wireless box all use factory settings.",
				"choices":
				[
					{"label": "WALK THE PRINTER, CAMERA AND WIRELESS", "secs": 6.0, "pts": 20, "hours": 0.4, "flag": "walked", "note": "Three devices, all admin and admin."},
					{"label": "TRY JUST THE PRINTER", "secs": 2.0, "pts": 5, "hours": 0.1, "note": "The printer opens right up."},
				]
			},
			{
				"title": "CHANGE THEM",
				"text": "What do you do with the passwords?",
				"choices":
				[
					{"label": "NEW PASSWORD ON ALL THREE, IN THE VAULT", "secs": 8.0, "pts": 40, "hours": 0.8, "note": "Three new passwords. Three more things on the device list."},
					{"label": "ONLY THE PRINTER", "secs": 3.0, "pts": 15, "hours": 0.2, "flag": "camera", "note": "The camera still waves hello to anyone."},
					{"label": "SKIP IT", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "default", "note": "Default is default."},
				]
			},
			{
				"title": "THE DEVICE LIST",
				"text": "Where do you write down what you changed?",
				"choices":
				[
					{"label": "ADD THEM TO THE DEVICE LIST", "secs": 4.0, "pts": 15, "hours": 0.2, "note": "Every device, a name and a date."},
					{"label": "KEEP IT IN YOUR HEAD", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "Your head is not a backup."},
				]
			},
		],
	},
	"tk_keys":
	{
		"title": "WHO HAS A KEY",
		"client": 0,
		"specials": ["tk_keys"],
		"steps":
		[
			{
				"title": "LIST THE ACCOUNTS",
				"text": "Four people who left, one old vendor rep, one odd mail rule.",
				"choices":
				[
					{"label": "LIST EVERY ACCOUNT AND MAIL RULE", "secs": 6.0, "pts": 20, "hours": 0.4, "flag": "listed", "note": "Six logins to question and a rule that copies every message outside."},
					{"label": "SKIM THE LIST", "secs": 2.0, "pts": 5, "hours": 0.1, "note": "You catch the obvious ones."},
				]
			},
			{
				"title": "TURN THEM OFF",
				"text": "Which logins do you disable?",
				"choices":
				[
					{"label": "DISABLE ALL OF THEM AND THE MAIL RULE", "secs": 6.0, "pts": 30, "hours": 0.5, "note": "Everything off. A short note in each file."},
					{"label": "EX-EMPLOYEES ONLY", "secs": 3.0, "pts": 15, "hours": 0.3, "flag": "repkey", "note": "The rep and the mail rule are still there."},
					{"label": "LEAVE THEM, ASK LATER", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "open", "note": "Nothing changed."},
				]
			},
			{
				"title": "TELL THE OWNER",
				"text": "Do you tell the owner what you found?",
				"choices":
				[
					{"label": "TELL THE OWNER EVERYTHING", "secs": 3.0, "pts": 15, "hours": 0.2, "note": "Awkward. Honest."},
					{"label": "KEEP IT TO YOURSELF", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "You will have to explain it later."},
				]
			},
			{
				"title": "THE CHECKLIST",
				"text": "The next person who leaves should not leave a key behind.",
				"choices":
				[
					{"label": "WRITE A LEAVER CHECKLIST", "secs": 5.0, "pts": 20, "hours": 0.3, "flag": "offboard", "note": "One page: accounts, mail, keys, phones."},
					{"label": "SKIP THE PAPER", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "It will happen again."},
				]
			},
		],
	},
}

# the tickets a job opens (shape of Playbook.PROBLEMS; the %s of a body is the contact)
const PROBLEMS := {
	"tk_backup": [{"summary": "Backup is a drive in a freezer bag", "fix": "project", "pri": 2, "special": "tk_backup", "server": true, "body": "We just learned our backup is one drive in a freezer bag. Please fix it. - %s"}],
	"tk_creds": [{"summary": "One password opens everything", "fix": "project", "pri": 2, "special": "tk_creds", "body": "The password for everything is on a sticky note. Please sort it out. - %s"}],
	"tk_firewall": [{"summary": "Firewall hole open since 2012", "fix": "project", "pri": 2, "special": "tk_firewall", "server": true, "body": "We heard the firewall has had a hole in it for years. Please close it. - %s"}],
	"tk_dashboard": [{"summary": "Monitoring was never configured", "fix": "project", "pri": 3, "special": "tk_dashboard", "body": "Our monitoring says all green but you said it watches nothing. Can you set it up? - %s"}],
	"tk_defaults": [{"summary": "Devices still on default passwords", "fix": "project", "pri": 3, "special": "tk_defaults", "body": "The printer and the camera have the factory password. Please change them. - %s"}],
	"tk_keys": [{"summary": "Old employees still have logins", "fix": "project", "pri": 2, "special": "tk_keys", "body": "Somebody who left last year can still log in. Please close those accounts. - %s"}],
}

# what each job earns: bad = flags that leave the mess open, bump = risk added when it stays open, follow = ticket per flag,
# ok / mail_bad = the client's reply
const OUTCOMES := {
	"tk_backup":
	{
		"job": "T1",
		"bad": ["trust", "open"],
		"bump": 25,
		"ok": "We have a real backup now, and somebody wrote down how long it takes to come back. Thank you.",
		"mail_bad": "The light is still green. I would like to believe it. Please tell me it has been tested.",
		"follow": {"swapped": ["Backup drive is new but never restored", "Is the new backup drive tested? Nobody has ever opened a file from it. - %s"]},
	},
	"tk_creds":
	{
		"job": "T2",
		"bad": ["noted", "partial"],
		"bump": 10,
		"ok": "Every login is different now and the spare key is in the safe. I did not know any of that was possible.",
		"mail_bad": "The note is back on my monitor. Everyone says it is easier.",
		"follow": {"quiet": ["The other company heard about the password", "A friend at the other company says their password was the same as ours. Why were we not told? - %s"]},
	},
	"tk_firewall":
	{
		"job": "T3",
		"bad": ["hole"],
		"bump": 10,
		"ok": "The door is shut and the VPN works from home. Thank you.",
		"mail_bad": "You said the hole was fixed. The log still shows strangers knocking.",
		"follow": {"hole": ["Strangers keep knocking on the server", "The same address is trying our server every night. - %s"]},
	},
	"tk_dashboard":
	{
		"job": "T4",
		"bad": ["trust", "partial"],
		"bump": 10,
		"ok": "We get real alerts now. It was loud for a week and then it was quiet, the right kind of quiet.",
		"mail_bad": "The dashboard is green again. I am not sure that means anything.",
		"follow": {"flood": ["So many alerts all at once", "The new alerts are flooding the inbox. Is everything broken? - %s"]},
	},
	"tk_defaults":
	{
		"job": "T5",
		"bad": ["default", "camera"],
		"bump": 10,
		"ok": "Every device has its own password. The camera finally has one too.",
		"mail_bad": "Our ceiling camera still answers to the factory password.",
		"follow": {},
	},
	"tk_keys":
	{
		"job": "T6",
		"bad": ["open", "repkey"],
		"bump": 10,
		"ok": "Nobody has a key who should not. The checklist is on the wall next to the coffee machine.",
		"mail_bad": "A man who left last year just sent a mail from an old login.",
		"follow": {"open": ["A mail came from an old employee account", "Somebody who left sent a mail from his old account. Did you close those? - %s"]},
	},
}

# the grade of a walk-around becomes the start mood (Sales.adjust) and, for C and D, a follow-up ticket
const GRADE_MOOD := {"S": 10, "A": 6, "B": 2, "C": -3, "D": -8}
const GRADE_FOLLOW := {
	"summary": "Still no real answer on the old IT mess",
	"body": "We asked you for a straight answer and the closet is the same as before. Can you finish the list? - %s",
}


# ---- the meter -------------------------------------------------------------------------------------------------------------
# the inherited risk of a client (0 = none)
static func inherit(client: int) -> int:
	return clampi(int(Owner.inherit.get(client, 0)), 0, 100)


static func set_inherit(client: int, value: int) -> void:
	value = clampi(value, 0, 100)
	if value <= 0:
		Owner.inherit.erase(client)
	else:
		Owner.inherit[client] = value


# a takeover starts: the risk is the number of open findings times PER_FINDING (all six unless told otherwise)
static func begin(client: int, open_findings := 6) -> void:
	Career.add("takeovers")  # R38 P6
	set_inherit(client, open_findings * PER_FINDING)
	Rival.set_rap(RIVAL, "R12", Rival.SEEN)  # no documentation at all on arrival


# a finding was fixed: the risk drops by PER_FINDING. Returns the new risk. A job id also marks that job done.
static func fixed(client: int, job := "") -> int:
	if job != "":
		_mark(client, "done", job)
	set_inherit(client, inherit(client) - PER_FINDING)
	return inherit(client)


# clients that still carry an inherited mess
static func open_clients() -> Array:
	var out := []
	for c in Owner.inherit:
		if inherit(int(c)) > 0:
			out.append(int(c))
	return out


# weekly effect of the unfixed mess on a client's incident chances (1.0 = none): BEC attempts, remote desktop break-ins, vendor breach
static func risk_mult(client: int) -> float:
	return 1.0 + float(inherit(client)) / 200.0


# the worst multiplier of any client you serve (1.0 when nothing is inherited)
static func worst_mult() -> float:
	var worst := 1.0
	for c in open_clients():
		if Sales.active.has(c):
			worst = maxf(worst, risk_mult(c))
	return worst


# a random victim may be replaced by the client with the biggest mess: the more inherited, the likelier (no draw when there is none)
static func victim(pick: int) -> int:
	var best := -1
	for c in open_clients():
		if Sales.active.has(c) and (best < 0 or inherit(c) > inherit(best)):
			best = c
	if best >= 0 and randf() < float(inherit(best)) / 200.0:
		return best
	return pick


# an unfixed freezer bag: a restore at this client may fail (0 = no takeover job open)
static func restore_fail(client: int) -> float:
	var st := state(client)
	if st.is_empty() or "T1" in st.done:
		return 0.0
	return OPEN_RESTORE_FAIL if inherit(client) > 0 else 0.0


# ---- the per client state -------------------------------------------------------------------------------------------------
static func state(client: int) -> Dictionary:
	var st: Variant = Owner.flags.get("tk_%d" % client, {})
	if st is Dictionary and not (st as Dictionary).is_empty():
		var out: Dictionary = st
		for k in ["found", "acted", "done"]:
			if not out.has(k):
				out[k] = []
		return out
	return {}


static func _mark(client: int, what: String, job: String) -> void:
	var st := state(client)
	if st.is_empty():
		st = {"found": [], "acted": [], "done": []}
	if not (job in st[what]):
		st[what].append(job)
	Owner.flags["tk_%d" % client] = st


static func found_count(client: int) -> int:
	return state(client).get("found", []).size()


# ---- the visit ------------------------------------------------------------------------------------------------------------
# the client of the next takeover visit: a returned Big Cheese client first (takeover_pending_<c>), then the client of the rival arc
static func target() -> int:
	var best := -1
	var day := 9999
	for c in Sales.active:
		var d := int(Owner.flags.get("takeover_pending_%d" % int(c), 9999))
		if d < day and state(int(c)).is_empty():
			best = int(c)
			day = d
	if best >= 0:
		return best
	var arc := Rival.arc_client()
	if arc >= 0 and Sales.active.has(arc) and state(arc).is_empty():
		return arc
	return -1


# the fx visit <kind>: start a takeover visit for the returned client. Does nothing when no client has a mess to look at.
static func visit(_owner: Node, kind: String) -> void:
	if kind != KIND or not ENABLED:
		return
	var client := target()
	if client < 0:
		return
	if not Onsite.has_site(client):
		return  # X12: no office to walk around, so no visit and no inherited mess to carry (the findings only show on a visit)
	Owner.flags.erase("takeover_pending_%d" % client)
	Owner.flags["tk_%d" % client] = {"found": [], "acted": [], "done": []}
	begin(client, JOBS.size())
	if Onsite.has_site(client) and not Onsite.active:
		Onsite.start_visit(client, KIND)
	else:
		Hints.toast(str(TEXT.arrive), 4.0)


# the job that shows for an object, or {} when all six are found
static func next_finding(client: int, obj: String) -> Dictionary:
	var found: Array = state(client).get("found", [])
	var want := str(PREFER.get(obj, ""))
	if want != "" and not (want in found):
		return _entry(want)
	for f in FINDINGS_TAKEOVER:
		if not (str(f.id) in found):
			return f
	return {}


static func _entry(job: String) -> Dictionary:
	for f in FINDINGS_TAKEOVER:
		if str(f.id) == job:
			return f
	return {}


# the walk-around hook (Onsite.inspect calls it with the object): every object shows what the last shop left in it
static func on_inspect(client: int, obj: String) -> void:
	var f := next_finding(client, obj)
	if f.is_empty():
		Hints.toast(str(TEXT.nothing), 2.5)
		return
	show_finding(client, f)


# the card of one finding
static func show_finding(client: int, f: Dictionary) -> void:
	var job := str(f.id)
	_mark(client, "found", job)
	Rival.set_rap(RIVAL, str(JOBS[job].rap), Rival.SEEN)
	var options := []
	var busy := Playbook.is_active() or not Campaign.active
	options.append({"label": str(TEXT.job_busy if busy else TEXT.job), "id": "job", "enabled": not busy})
	options.append({"label": str(TEXT.quick) % int(f.hours), "id": "quick"})
	if Campaign.books_active() and (str(f.project) != "" or str(f.service) != ""):
		options.append({"label": str(TEXT.project), "id": "project"})
	options.append({"label": str(TEXT.note), "id": "note"})
	Cards.ask(str(TEXT.title) + ": " + str(JOBS[job].name), str(f.text), options, func(id: String) -> void: answer(client, f, id))


static func answer(client: int, f: Dictionary, id: String) -> void:
	var job := str(f.id)
	match id:
		"job":
			if Playbook.is_active() or not Campaign.active:
				Hints.toast(str(TEXT.job_busy), 3.0)
				return
			_mark(client, "acted", job)
			Playbook.start(str(JOBS[job].book), "walk-around", client)
			Hints.toast(str(TEXT.job_started), 4.0)
		"quick":
			_mark(client, "acted", job)
			Owner.apply({"owner_hours": int(f.hours)})
			set_inherit(client, inherit(client) - int(f.drop))
			Hints.toast(str(TEXT.quick_done), 4.0)
			Cards.ask("Onsite", str(f.quick), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
		"project":
			_mark(client, "acted", job)
			if str(f.service) != "":
				if not Projects.has_service(client, str(f.service)):
					Projects._queue.append({"kind": "service", "client": client, "id": str(f.service)})
			else:
				Projects.offer_project(client, str(f.project))
			Sales.adjust(client, 1)
			Hints.toast(str(TEXT.project_sold), 3.5)
		_:
			Hints.toast(str(TEXT.noted), 3.0)


# the owner meeting of the visit (Onsite._meeting_answer): two answers show a finding, the third is a promise
static func meeting_answer(client: int, id: String, text: String) -> void:
	var job := ""
	match id:
		"list":
			job = "T2"
		"past":
			job = "T1"
		_:
			Sales.adjust(client, 4)
			text += " " + str(TEXT.fresh)
	var after := func(_id: String) -> void:
		if job != "" and not (job in state(client).get("found", [])):
			show_finding(client, _entry(job))
	Cards.ask("The owner", text, [{"label": str(TEXT.go_on), "id": "ok"}], after)


# leaving the site (Onsite._go_home): the walk-around grade is the start mood, a C or D asks to be finished
static func finish_visit(client: int) -> void:
	var st := state(client)
	if st.is_empty():
		return
	var found: int = st.get("found", []).size()
	var acted: int = st.get("acted", []).size()
	var percent := int(100.0 * float(found * 2 + acted) / float(JOBS.size() * 3))
	var grade := str(Playbook.grade_for(percent))
	Sales.adjust(client, int(GRADE_MOOD[grade]))
	var open: int = JOBS.size() - st.get("done", []).size()
	Hints.toast(str(TEXT.left) % [found, open, grade], 6.0)
	if grade in ["C", "D"]:
		var follow: Dictionary = GRADE_FOLLOW.duplicate()
		follow["client"] = client
		follow["pri"] = 3
		Story.queue_followup(follow)


# ---- a Playbook job finished (Playbook._outcome) ---------------------------------------------------------------------------
# returns {rep, score, mail, follow}; a good job fixes the finding and proves the rap, a bad one leaves the mess (more risk)
static func outcome(id: String, flags: Dictionary, client: int) -> Dictionary:
	var out := {"rep": 0, "score": 0, "mail": "Thank you, that was handled well.", "follow": []}
	var o: Dictionary = OUTCOMES.get(id, {})
	if o.is_empty():
		return out
	var job := str(o.job)
	var bad := false
	for f in o.bad:
		bad = bad or bool(flags.get(f, false))
	out.mail = str(o.mail_bad) if bad else str(o.ok)
	if bad:
		set_inherit(client, inherit(client) + int(o.bump))
		out.rep = -1
	else:
		fixed(client, job)
		Rival.set_rap(RIVAL, str(JOBS[job].rap), Rival.PROVEN)
		Habits.touch_if(str(JOBS[job].twin))
		out.rep = 1
	for f in o.follow:
		if bool(flags.get(f, false)):
			var pair: Array = o.follow[f]
			out.follow.append({"client": client, "summary": str(pair[0]), "body": str(pair[1]), "pri": 2})
	if job == "T2" and bool(flags.get("quiet", false)) and randf() < 0.3:
		Sales.adjust(client, -6)
	return out
