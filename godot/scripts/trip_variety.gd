extends RefCounted
# gdlint:disable=max-line-length
# Rodent Nation 2014 variety (roadmap R11): every run gets its own agenda. Static helper that Expo preloads.
#   - the session menu of each round (4 rooms: the headline session stays where it was, the rest rotate through a bigger pool)
#   - which three of five vendors have a booth and where, which attendees you meet (same sprite, different conversation)
#   - the raffle odds of the year (6 to 12 percent, plus 4 percent per badge scan as before)
# Everything is drawn from Difficulty.rng_for with the run seed, so a save resumes the same trip. The KPIs, the XP per
# session (8) and the per diem are not touched. Skills used: powershell (lab only), networking, servers, security, people.

# round index -> slot -> session id that never moves (the scripting lab and the security session)
const PINS := {0: {0: "ps101"}, 1: {1: "security"}}
const MORE_SESSIONS := [
	[
		{
			"id": "docs",
			"short": "DOCUMENTATION THAT GETS READ",
			"label": "DOCUMENTATION THAT GETS READ",
			"skill": "people",
			"xp": 8,
			"text": "A tired consultant shows a one page runbook that technicians actually open at 2 a.m. You rewrite three of yours on the flight home in your head. (+8 customer XP)"
		},
		{
			"id": "macs",
			"short": "THE ODD MACHINE: MAC AND LINUX",
			"label": "THE ODD MACHINE: MAC AND LINUX IN A WINDOWS SHOP",
			"skill": "networking",
			"xp": 8,
			"text": "Two clients have a designer with a laptop that nobody understands. The speaker has a checklist for them: sharing, backups and who gets the blame. (+8 networking XP)"
		},
	],
	[
		{
			"id": "spam",
			"short": "SPAM FILTERING THAT WORKS",
			"label": "SPAM FILTERING THAT WORKS",
			"skill": "security",
			"xp": 8,
			"text": "A filter, three rules and a quarantine email the user will read. The room laughs at the slide of the worst phishing mail of the year. (+8 security XP)"
		},
		{
			"id": "virt",
			"short": "VIRTUAL SERVERS ON A BUDGET",
			"label": "VIRTUAL SERVERS ON A BUDGET",
			"skill": "servers",
			"xp": 8,
			"text": "One good box instead of three tired ones. The speaker is firm about backups and gentle about licences. (+8 servers XP)"
		},
	],
	[
		{
			"id": "qbr",
			"short": "SELLING THE BUSINESS REVIEW",
			"label": "SELLING THE QUARTERLY BUSINESS REVIEW",
			"skill": "people",
			"xp": 8,
			"text": "Show the client what you did, then what is coming. The speaker's best slide is a chart of tickets that did not happen. (+8 customer XP)"
		},
		{
			"id": "ransom",
			"short": "CRYPTOLOCKER: WHAT WE LEARNED",
			"label": "CRYPTOLOCKER: WHAT WE LEARNED",
			"skill": "security",
			"xp": 8,
			"text": "Backups you have tested, shares that are not open to everyone and a plan for the Monday it happens anyway. (+8 security XP)"
		},
	],
]
const SLOT_GENDER := ["m", "f", "m", "f", "m", "m"]  # the attendee sprites of Expo.CROWD (att:0 .. att:5)
const VENDOR_IDS := ["backup", "webwoot", "psa", "voip", "rmmx"]
const VENDOR_LOOK := {"backup": "expo_vendg", "webwoot": "expo_dee", "psa": "expo_vendo", "voip": "expo_vendh", "rmmx": "expo_vendi"}
const BOOTH_X := [71, 159, 272]
const VENDOR_XP := {"voip": {"demo": ["networking", 6], "price": ["people", 3]}, "rmmx": {"demo": ["servers", 6], "price": ["security", 3]}}
const EXTRA_VENDORS := [
	{
		"id": "voip",
		"speaker": "Sam (CloudCall Voice)",
		"text": "Do your clients still have a phone closet from 2004? CloudCall hosts the whole system: desk phones, a mobile app and a receptionist who finally gets a vacation. First three months free!",
		"options":
		[
			{"id": "demo", "label": "TRY THE SOFTPHONE", "text": "You make a call from a laptop. The sound is clear, the latency is not. Sam says that is the hotel wifi. (+6 networking XP)"},
			{"id": "price", "label": "ASK ABOUT PRICING", "text": "Per seat, per month, plus a line for the fax, which you did not ask about. (+3 customer XP)"},
			{"id": "scan", "label": "SCAN MY BADGE FOR THE PRIZE", "text": "Beep. You are entered to win a headset. Sam's smile gets a little wider. (raffle entry, expect emails)"},
			{"id": "no", "label": "NO THANKS", "text": "Sam hands you a pen shaped like a phone anyway."},
		],
		"mail":
		{
			"from": "Sam Ortega <sam@cloudcall.example>",
			"subject": "Your free three months at CloudCall",
			"body": "Hi! It was great to see you in Florida. Your free three months are still waiting. Can I send over a quote for your biggest client? - Sam"
		},
	},
	{
		"id": "rmmx",
		"speaker": "Jordan (PatchPals RMM)",
		"text": "Patching the whole client base used to take a week. With PatchPals it takes a lunch break and one scary dashboard. Can I show you the dashboard?",
		"options":
		[
			{"id": "demo", "label": "WATCH THE DASHBOARD", "text": "Four hundred machines go green in a minute. Jordan does not mention the nine that stayed red. You do. (+6 servers XP)"},
			{"id": "price", "label": "ASK HOW IT HANDLES FAILURES", "text": "A long answer about retries and a short one about who gets the call. You write both down. (+3 security XP)"},
			{"id": "scan", "label": "SCAN MY BADGE FOR THE PRIZE", "text": "Beep. You are entered to win a tablet. Jordan's smile gets a little wider. (raffle entry, expect emails)"},
			{"id": "no", "label": "NO THANKS", "text": "Jordan gives you a sticker. It says PATCH IT."},
		],
		"mail":
		{
			"from": "Jordan Pike <jordan@patchpals.example>",
			"subject": "Following up from the Rodent Nation expo hall",
			"body": "Hi! Thanks for stopping by the booth. I put your name down for a pilot of PatchPals. Can we find fifteen minutes this week? - Jordan"
		},
	},
]
# extra attendees (same shape as Expo.CHATS) with the gender of the sprite they can use
const EXTRA_CHATS := [
	{
		"gender": "f",
		"speaker": "ticket_lena (Lena, help desk lead)",
		"text": "We answer in four minutes and the clients still say we are slow. I think it is the first sentence. What do you open with?",
		"options":
		[
			{"id": "learn", "label": "SHARE YOUR FIRST SENTENCE", "skill": "people", "xp": 4, "text": "She writes down: I have it, and here is what happens next. She says it is shorter than her old one. (+4 customer XP)"},
			{"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "You swap cards. Hers has a headset on it."},
			{"id": "bye", "label": "NICE TO MEET YOU", "skill": "", "xp": 0, "text": "She says to look her up on the forum."},
		],
	},
	{
		"gender": "m",
		"speaker": "omar_ops (Omar, two-person MSP)",
		"text": "My partner does the sales and I do everything else. How do you decide which client gets the Saturday?",
		"options":
		[
			{"id": "learn", "label": "TALK ABOUT SLAs AND A PHONE LIST", "skill": "servers", "xp": 4, "text": "He did not have a list. He takes a photo of your napkin. (+4 servers XP)"},
			{"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "You swap cards. His is handwritten."},
			{"id": "bye", "label": "NICE TO MEET YOU", "skill": "", "xp": 0, "text": "He has a flight to catch and he waves with his coffee."},
		],
	},
	{
		"gender": "f",
		"speaker": "rosa_net (Rosa, school district IT)",
		"text": "Eleven hundred students, one wireless controller and a principal who streams video in the hall. Any advice?",
		"options":
		[
			{"id": "learn", "label": "TALK ABOUT SEPARATE VLANS", "skill": "networking", "xp": 4, "text": "She grins. That was the exact thing she was afraid to propose. (+4 networking XP)"},
			{"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "You swap cards. Hers has a school bus on it."},
			{"id": "bye", "label": "NICE TO MEET YOU", "skill": "", "xp": 0, "text": "The bell rings on her phone. She says it is the principal."},
		],
	},
]


# the four sessions of one round: pinned rooms first, the rest from the pool in a seeded order
static func menu(round_index: int, base: Array) -> Array:
	var pool: Array = base.duplicate()
	if round_index < MORE_SESSIONS.size():
		pool.append_array(MORE_SESSIONS[round_index])
	var pins: Dictionary = PINS.get(round_index, {})
	var out: Array = []
	var rest: Array = []
	for s in pool:
		var pinned := false
		for slot in pins:
			if str(pins[slot]) == str(s.id):
				pinned = true
		if not pinned:
			rest.append(s)
	var r := Difficulty.rng_for("trip.menu", round_index)
	for i in range(rest.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var size := mini(4, pool.size())
	for slot in size:
		var picked: Dictionary = {}
		if pins.has(slot):
			for s in pool:
				if str(s.id) == str(pins[slot]):
					picked = s
		if picked.is_empty() and not rest.is_empty():
			picked = rest.pop_front()
		out.append(picked)
	return out


# the vendors with a booth this year: three of five, each at one of the three booth spots
static func trip_vendors() -> Array:
	var r := Difficulty.rng_for("trip.vendors", 0)
	var ids := VENDOR_IDS.duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	return ids.slice(0, 3)


static func booth_x(slot: int) -> int:
	var xs := BOOTH_X.duplicate()
	var r := Difficulty.rng_for("trip.booths", 0)
	for i in range(xs.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = xs[i]
		xs[i] = xs[j]
		xs[j] = tmp
	return int(xs[slot % xs.size()])


# the CROWD list of a scene with this year's vendors in the booths
static func remap_crowd(list: Array, scene: String) -> Array:
	if scene != "vendor_hall":
		return list
	var vendors := trip_vendors()
	var out: Array = []
	var slot := 0
	for c in list:
		var entry: Dictionary = c.duplicate(true)
		if str(entry.role).begins_with("vendor:"):
			var id := str(vendors[slot])
			entry["role"] = "vendor:" + id
			entry["who"] = str(VENDOR_LOOK[id])
			entry["x"] = booth_x(slot)
			slot += 1
		out.append(entry)
	return out


# which conversation each of the six attendee slots has this year (index into base + extras, same gender as the sprite)
static func chat_slots(base: Array) -> Array:
	var pool: Array = []
	for i in base.size():
		pool.append({"gender": SLOT_GENDER[i % SLOT_GENDER.size()], "chat": base[i]})
	for c in EXTRA_CHATS:
		pool.append({"gender": str(c.gender), "chat": c})
	var r := Difficulty.rng_for("trip.chats", 0)
	for i in range(pool.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	for slot in 6:
		var want: String = SLOT_GENDER[slot]
		for k in pool.size():
			if str(pool[k].gender) == want:
				out.append(pool[k].chat)
				pool.remove_at(k)
				break
	return out


# the raffle: 6, 8, 10 or 12 percent before the badge scans
static func raffle_base() -> float:
	var r := Difficulty.rng_for("trip.raffle", 0)
	return [0.06, 0.08, 0.1, 0.12][r.randi_range(0, 3)]


static func drum_line(base: float) -> String:
	if base < 0.07:
		return "The drum looked half empty. Everyone remembers that."
	if base > 0.11:
		return "The drum was packed with tickets this year."
	return ""
