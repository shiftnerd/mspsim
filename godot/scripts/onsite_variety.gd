extends RefCounted
# gdlint:disable=max-line-length
# Onsite variety (roadmap R11): more job variants per site type, a seeded dispatch roulette (which client calls, which job,
# what happens on the road) and the road events. Static helper that Onsite preloads; the state (calls, recent clients,
# jobs seen) lives in Onsite and is saved. Jobs use the same shape as Onsite.JOBS plus "sites" (the site types they fit).
# The one-open-job rule is kept by Onsite.create_job (the roulette never creates a second one).

const ROAD_CHANCE := 0.35
const ROAD := [
	{"id": "accident", "min": 20, "w": 1.0, "text": "AN ACCIDENT ON ROUTE 9 BACKS UP THE ROAD: +20 MIN."},
	{"id": "bus", "min": 10, "w": 1.5, "text": "A SCHOOL BUS STOPS AT EVERY CORNER: +10 MIN."},
	{"id": "bridge", "min": 15, "w": 0.8, "text": "THE DRAWBRIDGE IS UP FOR A BARGE: +15 MIN."},
	{"id": "roadwork", "min": 10, "w": 1.5, "text": "ROAD WORK. ONE LANE AND A MAN WITH A SIGN: +10 MIN."},
	{"id": "backroad", "min": -10, "w": 1.0, "text": "A BACK ROAD YOU HAD NEVER TRIED WORKS: -10 MIN."},
	{"id": "green", "min": -5, "w": 1.0, "text": "GREEN LIGHTS ALL THE WAY: -5 MIN."},
]
const VARIANT_JOBS := [
	{
		"id": "dent_cam",
		"sites": ["dental"],
		"object": "exam",
		"pri": 2,
		"summary": "The intraoral camera shows a black picture",
		"body": "Since the update last night the little camera shows nothing in exam room 2 and the hygienist cannot take her photos. - %s",
		"intro": "The exam room PC finds the camera, then the practice software shows a black square. The driver date is from last night.",
		"options":
		[
			{"id": "roll", "label": "ROLL BACK THE CAMERA DRIVER", "hours": 0.5, "chance": 0.95, "skill": "servers", "xp": 6, "text": "The old driver loads, the picture comes back and the hygienist waves the camera at you like a trophy. (+6 servers XP)"},
			{"id": "usb", "label": "TRY ANOTHER USB PORT", "hours": 0.2, "chance": 0.3, "skill": "servers", "xp": 2, "text": "A new port, the same black square. At least the cable is fine."},
			{"id": "vendor", "label": "CALL THE CAMERA VENDOR", "hours": 0.6, "chance": 0.0, "skill": "", "xp": 0, "text": "Hold music, a ticket number and a promise for Thursday. The camera does not work today."},
		],
	},
	{
		"id": "dent_claims",
		"sites": ["dental"],
		"object": "pc",
		"pri": 3,
		"summary": "The insurance claims website will not open",
		"body": "The front desk cannot send claims to the insurance site. It says my browser is too old. It is the browser I have always used. - %s",
		"intro": "The front desk PC runs an old browser and an old Java. The claims portal changed its login last week and refuses both.",
		"options":
		[
			{"id": "update", "label": "UPDATE THE BROWSER AND THE PLUGIN", "hours": 0.75, "chance": 0.9, "skill": "security", "xp": 6, "text": "A new browser, the right plugin and a long sigh from the receptionist. Claims go out. (+6 security XP)"},
			{"id": "compat", "label": "TURN ON COMPATIBILITY VIEW", "hours": 0.2, "chance": 0.35, "skill": "security", "xp": 2, "text": "The page loads for a minute, then asks for a plugin that is not there. Not quite."},
			{"id": "fax", "label": "SUGGEST THEY FAX THE CLAIMS", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "The receptionist looks at you for a long time. The claims still do not go out."},
		],
	},
	{
		"id": "law_scan",
		"sites": ["law"],
		"object": "printer",
		"pri": 3,
		"summary": "Scan to email stopped working on the copier",
		"body": "The big copier scans, but the email never arrives. The paralegals have been walking documents to each other's desks all morning. - %s",
		"intro": "The copier shows SENT, the mail server shows nothing. The scan to email settings still point at the server that was retired in March.",
		"options":
		[
			{"id": "smtp", "label": "POINT IT AT THE NEW MAIL SERVER", "hours": 0.5, "chance": 0.95, "skill": "networking", "xp": 6, "text": "New address, new test page, one scan to your own inbox. The paralegals stop walking. (+6 networking XP)"},
			{"id": "folder", "label": "SET UP SCAN TO A SHARED FOLDER", "hours": 0.75, "chance": 0.6, "skill": "servers", "xp": 4, "text": "Scans land in a folder on the server. Half the staff cannot find it. It works, mostly. (+4 servers XP)"},
			{"id": "reboot", "label": "POWER CYCLE THE COPIER", "hours": 0.15, "chance": 0.0, "skill": "", "xp": 0, "text": "It comes back with the same settings and the same problem, and a warm smell."},
		],
	},
	{
		"id": "law_files",
		"sites": ["law"],
		"object": "server",
		"pri": 2,
		"summary": "The partners cannot open client folders",
		"body": "Half of the case folders say access denied since a paralegal reorganized the shared drive. A hearing is at three. - %s",
		"intro": "The file server is up, but the Cases folder lost its permissions when it was dragged into another folder. Two partners and four paralegals are locked out.",
		"options":
		[
			{"id": "inherit", "label": "RESET INHERITED PERMISSIONS", "hours": 0.75, "chance": 0.9, "skill": "servers", "xp": 8, "text": "One reset on the top folder and every case opens again. The paralegal promises not to drag anything ever again. (+8 servers XP)"},
			{"id": "everyone", "label": "GIVE EVERYONE FULL ACCESS", "hours": 0.2, "chance": 0.0, "skill": "security", "xp": 1, "text": "It opens, but now the receptionist can read the divorce files. You have to come back to this."},
			{"id": "restore", "label": "RESTORE LAST NIGHT'S BACKUP", "hours": 1.5, "chance": 0.5, "skill": "servers", "xp": 4, "text": "The restore takes most of the afternoon and the permissions come back, with the paralegal's edits gone. (+4 servers XP)"},
		],
	},
	{
		"id": "vet_lab",
		"sites": ["vet"],
		"object": "exam",
		"pri": 2,
		"summary": "Lab results do not reach the patient records",
		"body": "The blood analyzer prints results, but they never show up in the pet's record on the computer. The doctor is typing them in by hand. - %s",
		"intro": "The analyzer is plugged into the exam room PC with a serial adapter. The practice software lost the port number after the last update.",
		"options":
		[
			{"id": "port", "label": "SET THE COM PORT IN THE SOFTWARE", "hours": 0.5, "chance": 0.95, "skill": "servers", "xp": 6, "text": "COM3, nine thousand six hundred baud and the results start arriving. A beagle's bloodwork scrolls past. (+6 servers XP)"},
			{"id": "adapter", "label": "REPLACE THE SERIAL ADAPTER", "hours": 0.6, "chance": 0.45, "skill": "servers", "xp": 3, "text": "A new adapter gets a new port number. It is better, but not fixed."},
			{"id": "manual", "label": "TELL THEM TO KEEP TYPING IT IN", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "The doctor is polite about it, which is worse."},
		],
	},
	{
		"id": "vet_desk",
		"sites": ["vet"],
		"object": "pc",
		"pri": 3,
		"summary": "The check in computer is crawling on boarding days",
		"body": "On boarding days the front desk computer takes a minute to open one record. There is a line of people with carriers. - %s",
		"intro": "The front desk PC has a full disk, forty startup programs and the booking software open in three windows. It is also the PC the dog sits next to.",
		"options":
		[
			{"id": "clean", "label": "CLEAN THE DISK AND THE STARTUP", "hours": 0.75, "chance": 0.9, "skill": "servers", "xp": 6, "text": "Twelve gigabytes of old photos moved to the server and the startup list cut to five. The line moves again. (+6 servers XP)"},
			{"id": "ram", "label": "ADD MEMORY", "hours": 0.5, "chance": 0.55, "skill": "servers", "xp": 3, "text": "More memory helps, a little. The disk is still the problem."},
			{"id": "later", "label": "TELL THEM TO PLAN FOR A NEW PC", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "True, and no help to the line of carriers today."},
		],
	},
	{
		"id": "trl_card",
		"sites": ["trailer"],
		"object": "pc",
		"pri": 2,
		"summary": "The foreman's laptop cannot reach the estimating software",
		"body": "I am in the trailer and the estimating program says no connection. The job bid is due at four. - %s",
		"intro": "The trailer connects to the main office through a cellular modem on the roof. The modem shows one bar and a message about a data plan.",
		"options":
		[
			{"id": "plan", "label": "FIX THE DATA PLAN AND MOVE THE MODEM", "hours": 0.75, "chance": 0.9, "skill": "networking", "xp": 7, "text": "A call to the carrier, the modem moved to the other window and four bars. The bid goes in at 3:40. (+7 networking XP)"},
			{"id": "hotspot", "label": "USE YOUR PHONE AS A HOTSPOT", "hours": 0.3, "chance": 0.5, "skill": "networking", "xp": 2, "text": "It works for the bid, for twenty minutes. Then your phone gets warm and the signal drops."},
			{"id": "drive", "label": "DRIVE THE FILES TO THE MAIN OFFICE ON A STICK", "hours": 1.0, "chance": 0.0, "skill": "", "xp": 0, "text": "You make the bid on time and the foreman is relieved. The trailer is still offline."},
		],
	},
	{
		"id": "trl_bridge",
		"sites": ["trailer"],
		"object": "cabinet",
		"pri": 1,
		"summary": "The second trailer has lost the network",
		"body": "The yard trailer cannot reach the printer or the files. The wireless thing between the trailers is blinking funny. - %s",
		"intro": "A wireless bridge links the two trailers. The one on the yard side is blinking amber and pointing a few degrees away from its partner.",
		"options":
		[
			{"id": "align", "label": "REALIGN THE BRIDGE AND RESET IT", "hours": 0.75, "chance": 0.9, "skill": "networking", "xp": 8, "text": "A ladder, a compass app and a firm hand. The light goes green and the yard trailer is back. (+8 networking XP)"},
			{"id": "cable", "label": "RUN A LONG CABLE ACROSS THE YARD", "hours": 1.0, "chance": 0.4, "skill": "networking", "xp": 3, "text": "It works until the first truck drives over it. You tape up what is left."},
			{"id": "skip", "label": "TELL THEM TO WALK FILES OVER", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "Nobody enjoys this suggestion. The foreman writes your name on a list."},
		],
	},
]


static func fits(job: Dictionary, site_type: String) -> bool:
	return not job.has("sites") or (job.sites as Array).has(site_type)


# jobs of one site type that are new in R11
static func jobs_for(site_type: String) -> Array:
	return VARIANT_JOBS.filter(func(j: Dictionary) -> bool: return fits(j, site_type))


# which client calls: the one who called last is less likely, then the one before
static func pick_client(rng: RandomNumberGenerator, options: Array, recent: Array) -> int:
	var weights: Array = []
	var total := 0.0
	for c in options:
		var w := 1.0
		var idx := recent.rfind(c)
		if idx >= 0:
			w = 0.25 if idx == recent.size() - 1 else 0.6
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in options.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return int(options[i])
	return int(options[options.size() - 1])


# which job: ones you have not seen yet are favoured
static func pick_job(rng: RandomNumberGenerator, pool: Array, seen: Dictionary) -> Dictionary:
	var total := 0.0
	var weights: Array = []
	for j in pool:
		var w := 1.0 / (1.0 + float(seen.get(str(j.id), 0)))
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


# what happens on the road (or {} for an ordinary drive)
static func road_event(rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= ROAD_CHANCE:
		return {}
	var total := 0.0
	for e in ROAD:
		total += float(e.w)
	var roll := rng.randf() * total
	for e in ROAD:
		roll -= float(e.w)
		if roll <= 0.0:
			return e
	return ROAD[0]
