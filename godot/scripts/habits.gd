extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the good habits of the player's own MSP (docs/scope-bad-habits.md section 4). A static helper like Incident.
# State is Owner.habits: {"H1": {"start": week, "last": week, "uses": n}} (saved with the campaign). A habit that is not in it is NONE.
# Freshness: age = Campaign.day - last. ADOPTED while age < every, STALE (half the effect) until age < 2 x every, then LAPSED (no effect).
# every = 0 means it never lapses by time (H10). Touching it again (the real action: a restore test, a QBR with a value page) resets it,
# and re-adopting a STALE or LAPSED habit costs half. Effects are read through fresh() / factor() by the other systems, and every query
# returns the NEUTRAL value (1.0, 0.0, false) while the habit is not adopted, so a game without habits plays exactly as before.
# R38 P2: the real touch rules (act, qbr, project, refusal, loss, departure), the decay and the pitches (week), the effects as neutral queries.
# OWNER OF THIS FILE: the habits agent (habits.gd + habits_view.gd).

const NONE := "NONE"
const ADOPTED := "ADOPTED"
const STALE := "STALE"
const LAPSED := "LAPSED"
const STALE_FACTOR := 0.5

# id -> name, cost (what adopting costs: cash, owner hours, morale), every (weeks between touches, 0 = never lapses by time),
# weight (points of the 100 point Standard), earns (the tab text: what it earns), shown (where the player sees it)
const DEFAULT_HABITS := {
	"H1":
	{
		# weight (points of the 100 point Standard), earns (the tab text: what it earns), shown (where the player sees it)
		"name": "TESTED RESTORE EACH QUARTER",
		"cost": {"cash": 150, "hours": 3, "morale": 0},
		"every": 13,
		"weight": 12,
		"earns":
		"A passed restore test means a ransom restores 100 percent and the bill is halved.",
		"shown": "RMM BACKUPS TESTED DATE"
	},
	"H2":
	{
		"name": "ITEMIZED PRICING AND VALUE PAGE",
		"cost": {"cash": 200, "hours": 1, "morale": 0},
		"every": 8,
		"weight": 10,
		"earns": "A one page scorecard at each review: mood +2, scope held, renewals up.",
		"shown": "SCORECARD AT QBR"
	},
	"H3":
	{
		"name": "CHANGE REQUESTS WITH ROLLBACK",
		"cost": {"cash": 0, "hours": 2, "morale": -1},
		"every": 10,
		"weight": 6,
		"earns": "Fixed price creep 30 to 18 percent, a failed cutover costs half.",
		"shown": "PROJECT QUOTE LINE"
	},
	"H4":
	{
		"name": "SIGNED RISK FORMS",
		"cost": {"cash": 0, "hours": 1, "morale": 0},
		"every": 13,
		"weight": 6,
		"earns": "A refusal on paper makes blame cheaper.",
		"shown": "OPEN REFUSALS"
	},
	"H5":
	{
		"name": "LOST ACCOUNT REVIEW",
		"cost": {"cash": 0, "hours": 2, "morale": 0},
		"every": 13,
		"weight": 6,
		"earns": "The real cause lowers that risk for 8 weeks.",
		"shown": "REVIEW AFTER A LOSS"
	},
	"H6":
	{
		"name": "OFFBOARDING CHECKLIST",
		"cost": {"cash": 0, "hours": 1, "morale": 0},
		"every": 13,
		"weight": 8,
		"earns": "No revenge mail from a departed tech, vendor breach odds down.",
		"shown": "CHECKED WHEN SOMEONE LEAVES"
	},
	"H7":
	{
		"name": "BREAK-GLASS AND UNIQUE ADMIN LOGINS",
		"cost": {"cash": 240, "hours": 1, "morale": -1},
		"every": 26,
		"weight": 10,
		"earns": "Vendor breach damage halved, weak password break-ins rarer.",
		"shown": "SEALED ENVELOPE (BOOKS)"
	},
	"H8":
	{
		"name": "VPN AND EXPIRING FIREWALL EXCEPTIONS",
		"cost": {"cash": 1200, "hours": 2, "morale": 0},
		"every": 13,
		"weight": 8,
		"earns": "A quarterly review closes forgotten open ports.",
		"shown": "HABITS ROW"
	},
	"H9":
	{
		"name": "CALENDAR-AWARE WINDOWS",
		"cost": {"cash": 0, "hours": 1, "morale": 0},
		"every": 26,
		"weight": 3,
		"earns": "Fewer failed overnight jobs, and a card before the clocks change in November.",
		"shown": "WEEK 19 CARD"
	},
	"H10":
	{
		"name": "HONEST ASSESSMENT",
		"cost": {"cash": 0, "hours": 2, "morale": 0},
		"every": 0,
		"weight": 8,
		"earns": "Win chance -3 points, start mood +6, referrals up.",
		"shown": "CRM ASSESS COUNT"
	},
	"H11":
	{
		"name": "RUNBOOKS AND A NETWORK MAP",
		"cost": {"cash": 0, "hours": 6, "morale": 0},
		"every": 26,
		"weight": 8,
		"earns": "Onsite jobs 20 percent faster, no only-person-who-knows event.",
		"shown": "CLIENTS MAPPED"
	},
	"H12":
	{
		"name": "LISTEN TO THE FRONT DESK",
		"cost": {"cash": 15, "hours": 1, "morale": 0},
		"every": 13,
		"weight": 7,
		"earns": "Mood drift seen 2 weeks earlier, more walk-around findings.",
		"shown": "CLIENTS COVERED"
	},
	"H13":
	{
		"name": "WRITTEN OK, EVEN IN AN EMERGENCY",
		"cost": {"cash": 0, "hours": 0, "morale": 0},
		"every": 13,
		"weight": 4,
		"earns": "Blame halved in disputes about emergency changes.",
		"shown": "EMERGENCY COUNT"
	},
	"H14":
	{
		"name": "DEFAULT DEVICE PASSWORDS CHANGED",
		"cost": {"cash": 0, "hours": 3, "morale": 0},
		"every": 52,
		"weight": 4,
		"earns": "No default password finding, a small breach reduction.",
		"shown": "SITES DONE"
	},
}
static var HABITS: Dictionary = DEFAULT_HABITS.duplicate(true)

# the Standard (0-100) band words: lowest score of each band
const BANDS := [[80, "SHOWCASE"], [60, "SOLID"], [35, "PATCHY"], [0, "BARE"]]
const PRACTICE_CAP := 3  # Owner.practices() counts adopted habits up to this many
const VALUATION_STANDARD := 70  # Standard at or above this (with oml 4+) is worth the maturity bonus
const MATURITY_BONUS := 0.25  # what oml 4+ has always added to the multiple (code value; the doc says 0.5)
const STANDARD_BONUS := 0.5  # the replacement bonus at Standard 70+ (never stacks with MATURITY_BONUS)

# the real thing, done now: what a repeat costs ([cash, owner hours]) once the habit is fresh. Habits not listed repeat for their hours.
const REDO := {
	"H1": [150, 3.0],
	"H2": [0, 1.0],
	"H7": [0, 1.0],
	"H8": [0, 2.0],
	"H12": [15, 1.0],
	"H14": [0, 3.0]
}
# the habits the player can do on the spot from the HABITS tab (the others are touched by what happens: a review, a project, a loss)
const DOABLE := ["H1", "H7", "H8", "H9", "H10", "H11", "H12", "H13", "H14"]
# the order of the pitches from Marge or Alan: one every OFFER_GAP weeks from OFFER_FROM, for a habit nobody has started
const OFFER_ORDER := [
	"H1", "H7", "H2", "H6", "H12", "H3", "H4", "H5", "H13", "H8", "H11", "H10", "H9", "H14"
]
const ALAN := ["H3", "H5", "H9", "H11", "H12", "H14"]  # the others are pitched by Marge
const OFFER_FROM := 3
const OFFER_GAP := 2
const H9_WEEK := 18  # the card comes in the week 19 morning (the clocks change in November)
const DRIFT_DROP := 3  # a mood fall this big in a week shows as a chip once the front desk is listened to
const REVENGE_CHANCE := 0.20
const PORTS_CHANCE := 0.03  # per client and week, once the firewall review is stale

const DEFAULT_TEXT := {
	"short_H1": "RANSOM RESTORES 100%, BILL HALVED, LESS POACH RISK",
	"short_H2": "SCORECARD AT EACH REVIEW: MOOD +2, CHANGE ORDERS +10",
	"short_H3": "CREEP CHANCE 30% TO 18% ON FIXED PRICE JOBS",
	"short_H4": "A REFUSAL ON PAPER MAKES BLAME CHEAPER",
	"short_H5": "THE REAL CAUSE CUTS THAT RISK FOR 8 WEEKS",
	"short_H6": "NO REVENGE MAIL, VENDOR BREACH ODDS DOWN",
	"short_H7": "BREACH DAMAGE HALVED, WEAK PASSWORD BREAK-INS RARER",
	"short_H8": "A REVIEW CLOSES FORGOTTEN OPEN PORTS",
	"short_H9": "FEWER FAILED NIGHT JOBS, CLOCKS CARD IN WEEK 19",
	"short_H10": "WIN CHANCE -3 POINTS, NEW CLIENTS START 6 HAPPIER",
	"short_H11": "ONSITE JOBS 20% FASTER AT MAPPED CLIENTS",
	"short_H12": "SEE MOOD DRIFT EARLY, MORE WALK-AROUND FINDINGS",
	"short_H13": "BLAME HALVED FOR EMERGENCY CHANGES",
	"short_H14": "NO DEFAULT PASSWORD FINDING, SMALL BREACH CUT",
	"started": "%s STARTED. IT KEEPS ITS EDGE ONLY IF YOU KEEP DOING IT.",
	"nocash": "NOT ENOUGH CASH.",
	"uptodate": "ALREADY FRESH. IT COUNTS WHEN THE REAL THING HAPPENS.",
	"nobackup": "NO WORKING BACKUP TO TEST. GET ONE RUNNING FIRST.",
	"h1": "RESTORE TEST PASSED AT %s. A SPARE PC CAME BACK FROM LAST NIGHT.",
	"h7": "NEW ADMIN LOGINS ARE IN THE SEALED ENVELOPE. THE OLD ONES ARE DEAD.",
	"h8": "FIREWALL EXCEPTIONS REVIEWED AND THE OLD ONES CLOSED.",
	"h9": "THE JOB WINDOWS FOLLOW THE CALENDAR NOW.",
	"h10": "AN HONEST ASSESSMENT IS ON FILE. THE GAPS ARE LISTED, ALL OF THEM.",
	"h11": "%s IS MAPPED: RUNBOOK, NETWORK MAP AND LABELLED GEAR.",
	"h11all": "EVERY CLIENT IS MAPPED ALREADY.",
	"h12": "COFFEE RUN DONE. THE FRONT DESK TOLD YOU WHAT THE TICKETS DO NOT.",
	"h13": "THE RULE IS ON THE WALL: NO EMERGENCY CHANGE WITHOUT A WRITTEN OK.",
	"h14": "DEFAULT PASSWORDS CHANGED AT %s: CAMERAS, PRINTERS, WIRELESS.",
	"h14all": "EVERY SITE IS DONE ALREADY.",
	"scorecard":
	"The one page scorecard went to %s: tickets closed, backups tested, what we fixed. Mood up.",
	"review":
	"Lost account review done. The real cause is written down, and the same mistake will cost less for eight weeks.",
	"offboard": "%s's logins and keys are closed. The checklist is signed."
}
static var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)

const DEFAULT_CARDS := {
	"habit_offer":
	{
		"speaker": "Marge (Bookkeeper)",
		"text": "Idea for the shop: %s. %s It would cost %s. Start it?",
		"options":
		[
			{"label": "NOT NOW", "fx": {}},
			{"label": "START IT", "fx": {"habit_adopt": ""}, "text": "Good. Now keep doing it."}
		]
	},
	"habit_lapsed":
	{
		"speaker": "Marge (Bookkeeper)",
		"text":
		"THE CHECKLIST HAS ONE EMPTY BOX. %s has not been done in a long while, so it has stopped helping. Doing it again costs half.",
		"options":
		[
			{"label": "DO IT AGAIN (HALF PRICE)", "fx": {"habit_adopt": ""}},
			{"label": "LET IT GO", "fx": {}}
		]
	},
	"habit_clocks":
	{
		"speaker": "Alan (Co-owner)",
		"text":
		"The clocks change on Sunday, November 2. Anything that runs at 2 in the morning will run twice or not at all, including the backups. Move the windows?",
		"options":
		[
			{
				"label": "MOVE THE WINDOWS (1 HOUR)",
				"fx": {"habit": "H9", "owner_hours": 1},
				"text": "Done. The jobs now start at 4, clear of the change."
			},
			{"label": "WE WILL WING IT", "fx": {}}
		]
	},
	"habit_revenge":
	{
		"speaker": "Marge (Bookkeeper)",
		"text":
		"%s left on bad terms and nobody closed their logins. This morning a nasty mail went out to three of our clients from an account that should be dead. Cleanup and apologies cost $1,500.",
		"options": [{"label": "CLOSE EVERY LOGIN NOW", "fx": {"cash": -1500, "rep": -1}}]
	},
	"habit_ports":
	{
		"speaker": "Alan (Co-owner)",
		"text":
		"The last job left a firewall exception open and nobody reviewed it. Remote desktop is open to the internet again at one client. Close it now?",
		"options":
		[
			{
				"label": "CLOSE IT AND REVIEW THEM ALL (2 HOURS)",
				"fx": {"habit": "H8", "owner_hours": 2, "flag": "rdp_safe"}
			},
			{"label": "LEAVE IT", "fx": {}}
		]
	}
}
static var CARDS: Dictionary = DEFAULT_CARDS.duplicate(true)


# ---- state --------------------------------------------------------------------------------------------------------
static func all() -> Array:
	return HABITS.keys()


static func entry(id: String) -> Dictionary:
	return Owner.habits.get(id, {})


# true once any habit has ever been started (the weekly report shows the STANDARD row from then on)
static func any() -> bool:
	return not Owner.habits.is_empty()


# weeks since the last touch (-1 while NONE)
static func age(id: String) -> int:
	var e := entry(id)
	if e.is_empty():
		return -1
	return maxi(0, Campaign.day - int(e.get("last", 0)))


# NONE / ADOPTED / STALE / LAPSED
static func state(id: String) -> String:
	var a := age(id)
	if a < 0:
		return NONE
	var every := int(HABITS.get(id, {}).get("every", 0))
	if every <= 0 or a < every:
		return ADOPTED
	if a < 2 * every:
		return STALE
	return LAPSED


# true only for a FRESH (ADOPTED) habit: the full effect
static func fresh(id: String) -> bool:
	return state(id) == ADOPTED


# the share of the effect that counts now: 1.0 ADOPTED, 0.5 STALE, 0.0 LAPSED or NONE
static func factor(id: String) -> float:
	match state(id):
		ADOPTED:
			return 1.0
		STALE:
			return STALE_FACTOR
	return 0.0


# what adopting costs now: full price when NONE, half when STALE or LAPSED (re-adopt), nothing more when fresh
static func cost(id: String) -> Dictionary:
	var c: Dictionary = HABITS.get(id, {}).get("cost", {})
	var scale := 1.0
	match state(id):
		STALE, LAPSED:
			scale = 0.5
		ADOPTED:
			scale = 0.0
	return {
		"cash": int(float(c.get("cash", 0)) * scale),
		"hours": float(c.get("hours", 0)) * scale,
		"morale": int(float(c.get("morale", 0)) * scale)
	}


# what the real thing costs to do again while the habit is fresh: {cash, hours}
static func redo_cost(id: String) -> Dictionary:
	if REDO.has(id):
		return {"cash": int(REDO[id][0]), "hours": float(REDO[id][1])}
	return {"cash": 0, "hours": float(HABITS.get(id, {}).get("cost", {}).get("hours", 0))}


# start it without paying (a card already charged for it: fx habit_start). Does not reset a habit that is already fresh.
static func start(id: String) -> bool:
	if not HABITS.has(id):
		return false
	if state(id) == ADOPTED:
		return false
	if not Owner.habits.has(id):
		Career.add("habits_adopted")  # R38 P6
	var e := entry(id)
	e["start"] = int(e.get("start", Campaign.day))
	e["last"] = Campaign.day
	e["uses"] = int(e.get("uses", 0))
	Owner.habits[id] = e
	if id == "H8":
		Owner.flags["rdp_safe"] = true  # the VPN is part of the habit (the same fix as the exposed remote desktop card)
	return true


# adopt (or re-adopt) and pay cost(id): cash, owner hours and the paperwork morale (back after two weeks). False when it cannot be paid.
static func adopt(id: String) -> bool:
	if not HABITS.has(id):
		return false
	var c := cost(id)
	if int(c.cash) > Owner.cash:
		return false
	Owner.cash -= int(c.cash)
	Growth.owner_used += float(c.hours)
	var m := int(c.morale)
	if m != 0:
		Social.change_all(m)
		Owner.flags["morale_back"] = int(Owner.flags.get("morale_back", 0)) - m
		Owner.flags["morale_due"] = Campaign.day + 2
	return start(id)


# the real thing was done again (a restore test, a QBR with a value page): resets freshness for free and counts a use. False while NONE.
static func touch(id: String) -> bool:
	var e := entry(id)
	if e.is_empty():
		return false
	e["last"] = Campaign.day
	e["uses"] = int(e.get("uses", 0)) + 1
	Owner.habits[id] = e
	return true


# the real thing happened in the game (a review, a project, a loss): it counts only while the habit still works (ADOPTED or STALE)
static func touch_if(id: String) -> bool:
	if factor(id) <= 0.0:
		return false
	return touch(id)


# ---- the Standard -------------------------------------------------------------------------------------------------
# 0-100: the weights of all habits, each times its factor
static func standard() -> int:
	var total := 0.0
	for id in HABITS:
		total += float(HABITS[id].get("weight", 0)) * factor(str(id))
	return clampi(int(round(total)), 0, 100)


static func band(score := -1) -> String:
	if score < 0:
		score = standard()
	for b in BANDS:
		if score >= int(b[0]):
			return str(b[1])
	return "BARE"


# the weekly report row text: 64 (SOLID)
static func standard_text() -> String:
	return "%d (%s)" % [standard(), band()]


# how many habits are ADOPTED or STALE (Owner.practices() counts them, capped)
static func practice_count() -> int:
	var n := 0
	for id in HABITS:
		var s := state(str(id))
		n += 1 if s == ADOPTED or s == STALE else 0
	return mini(n, PRACTICE_CAP)


# the multiple's maturity bonus: replaces the +0.25 of oml 4+ (never stacks). With no habits it equals the old rule exactly.
static func maturity_bonus(oml: int) -> float:
	if oml < 4:
		return 0.0
	return STANDARD_BONUS if standard() >= VALUATION_STANDARD else MATURITY_BONUS


# ---- doing the real thing now (the HABITS tab button) ---------------------------------------------------------------
# {label, enabled}: what the button says for this habit now
static func action(id: String) -> Dictionary:
	var st := state(id)
	var c: Dictionary = redo_cost(id) if st == ADOPTED else cost(id)
	var price := ""
	if int(c.cash) > 0:
		price += " $%d" % int(c.cash)
	if float(c.hours) > 0.0:
		price += " %sH" % _hours(float(c.hours))
	var can: bool = int(c.cash) <= Owner.cash
	match st:
		NONE:
			return {"label": "ADOPT" + price, "enabled": can}
		STALE, LAPSED:
			return {"label": "RE-ADOPT" + price, "enabled": can}
	if DOABLE.has(id):
		return {"label": "DO IT NOW" + price, "enabled": can}
	return {"label": "FRESH", "enabled": false}


static func _hours(h: float) -> String:
	return str(int(h)) if is_equal_approx(h, float(int(h))) else "%.1f" % h


# do it: adopt or re-adopt (pays the price) and do the real thing where there is one. Returns the line to show.
static func act(id: String) -> String:
	if not HABITS.has(id):
		return ""
	var st := state(id)
	if st == ADOPTED and not DOABLE.has(id):
		return str(TEXT.uptodate)
	var c: Dictionary = redo_cost(id) if st == ADOPTED else cost(id)
	if int(c.cash) > Owner.cash:
		return str(TEXT.nocash)
	if id == "H1" and _backup_client() < 0:
		return str(TEXT.nobackup)  # a restore test that has nothing to restore does not count
	if st == ADOPTED:
		Owner.cash -= int(c.cash)
		Growth.owner_used += float(c.hours)
		touch(id)
	else:
		adopt(id)
		touch(id)
		if not DOABLE.has(id):
			return str(TEXT.started) % str(HABITS[id].name)
	return _perform(id)


# the first active client whose backup works (the spare PC for a restore test), or -1
static func _backup_client() -> int:
	for c in Sales.active:
		if bool(Msp.backups[int(c)].ok):
			return int(c)
	return -1


static func _client_short(c: int) -> String:
	return str(Msp.CLIENTS[c].short).to_upper()


static func _perform(id: String) -> String:
	var e := entry(id)
	match id:
		"H1":
			var c := _backup_client()
			Msp.backup_check(c)
			e["tested"] = Campaign.day
			Owner.habits[id] = e
			return str(TEXT.h1) % _client_short(c)
		"H7":
			return str(TEXT.h7)
		"H8":
			Owner.flags["rdp_safe"] = true
			return str(TEXT.h8)
		"H9":
			return str(TEXT.h9)
		"H10":
			e["assessed"] = int(e.get("assessed", 0)) + 1
			Owner.habits[id] = e
			return str(TEXT.h10)
		"H11":
			var maps: Array = e.get("maps", [])
			for c in Sales.active:
				if not _listed(maps, int(c)):
					maps.append(int(c))
					e["maps"] = maps
					Owner.habits[id] = e
					return str(TEXT.h11) % _client_short(int(c))
			return str(TEXT.h11all)
		"H12":
			e["covered"] = Campaign.day
			Owner.habits[id] = e
			return str(TEXT.h12)
		"H13":
			return str(TEXT.h13)
		"H14":
			var sites: Array = e.get("sites", [])
			for c in Sales.active:
				if not _listed(sites, int(c)):
					sites.append(int(c))
					e["sites"] = sites
					Owner.habits[id] = e
					return str(TEXT.h14) % _client_short(int(c))
			return str(TEXT.h14all)
	return ""


# a short progress line for the tab: how far the real thing has got
static func progress(id: String) -> String:
	var e := entry(id)
	var uses := int(e.get("uses", 0))
	var live := Sales.active.size()
	match id:
		"H1":
			return "LAST TEST: " + ("NEVER" if not e.has("tested") else "WEEK %d" % int(e.tested))
		"H2":
			return "SCORECARDS SENT: %d" % uses
		"H3":
			return "PROJECTS WITH A CHANGE PLAN: %d" % uses
		"H4":
			return "FORMS SIGNED: %d" % uses
		"H5":
			return "LOSSES REVIEWED: %d" % uses
		"H6":
			return "DEPARTURES CHECKED: %d" % uses
		"H7":
			return "SEALED ENVELOPE: " + ("YES" if factor(id) > 0.0 else "NO")
		"H10":
			return "ASSESSMENTS: %d" % int(e.get("assessed", 0))
		"H11":
			return "CLIENTS MAPPED: %d OF %d" % [mapped_count(), live]
		"H12":
			return "CLIENTS COVERED: %d" % (live if e.has("covered") else 0)
		"H13":
			return "WRITTEN OKS: %d" % uses
		"H14":
			return "SITES DONE: %d OF %d" % [(e.get("sites", []) as Array).size(), live]
	return "DONE %d TIMES" % uses


# a client in a saved list (JSON turns the ints into floats, so compare as ints)
static func _listed(list: Array, client: int) -> bool:
	for v in list:
		if int(v) == client:
			return true
	return false


static func mapped_count() -> int:
	var n := 0
	for c in Sales.active:
		if _listed(entry("H11").get("maps", []), int(c)):
			n += 1
	return n


# ---- the week -------------------------------------------------------------------------------------------------------
# called from Owner.settle(): morale comes back, decay, the lapse nudge (once per habit), a pitch now and then
static func week(owner: Node) -> void:
	if owner.flags.has("morale_due") and Campaign.day >= int(owner.flags.morale_due):
		var back := int(owner.flags.get("morale_back", 0))
		owner.flags.erase("morale_due")
		owner.flags.erase("morale_back")
		if back != 0:
			Social.change_all(back)
	var shown := false
	for id in HABITS:
		var s := state(str(id))
		if s == LAPSED and not owner.flags.has("lapsed_" + str(id)):
			owner.flags["lapsed_" + str(id)] = Campaign.day
			if not shown:
				shown = true
				_card("habit_lapsed", str(id), [str(HABITS[id].name)])
		elif s == ADOPTED:
			owner.flags.erase("lapsed_" + str(id))
	_week_memory()
	_week_ports(owner)
	if Campaign.day >= H9_WEEK and state("H9") != NONE and not owner.flags.has("h9_card"):
		owner.flags["h9_card"] = Campaign.day
		shown = true
		_card("habit_clocks", "H9", [])
	if not shown:
		_offer(owner)


# H12 remembers last week's moods (the drift chip compares with it)
static func _week_memory() -> void:
	if state("H12") == NONE:
		return
	var e := entry("H12")
	var moods := {}
	for c in Sales.active:
		moods[str(c)] = Sales.mood(int(c))
	e["moods"] = moods
	Owner.habits["H12"] = e


# H8 neglected: a forgotten firewall exception opens remote desktop again (3 percent a week per client)
static func _week_ports(owner: Node) -> void:
	var s := state("H8")
	if (s == STALE or s == LAPSED) and owner.flags.get("rdp_safe", false):
		if randf() < minf(0.3, PORTS_CHANCE * float(Sales.active.size())):
			owner.flags["rdp_safe"] = false
			_card("habit_ports", "H8", [])


# one pitch from Marge or Alan every OFFER_GAP weeks, in the order of the table, for a habit nobody has started yet
static func _offer(owner: Node) -> void:
	if (
		Campaign.day < OFFER_FROM
		or Campaign.day - int(owner.flags.get("offer_day", -9)) < OFFER_GAP
	):
		return
	for id in OFFER_ORDER:
		if state(id) != NONE or owner.flags.has("offered_" + id):
			continue
		if id == "H9" and Campaign.day > H9_WEEK:
			continue
		owner.flags["offered_" + id] = Campaign.day
		owner.flags["offer_day"] = Campaign.day
		var c: Dictionary = HABITS[id].cost
		var parts := []
		if int(c.cash) > 0:
			parts.append("$%d" % int(c.cash))
		if float(c.hours) > 0.0:
			parts.append("%s hours of your time" % _hours(float(c.hours)))
		var price := " and ".join(parts) if not parts.is_empty() else "nothing but a habit"
		_card("habit_offer", id, [str(HABITS[id].name).to_lower(), str(HABITS[id].earns), price])
		return


# show a habit card: a copy with the habit's id in the adopt option, the cash it needs and the speaker
static func _card(card: String, id: String, args: Array) -> void:
	var c: Dictionary = (CARDS[card] as Dictionary).duplicate(true)
	c["text"] = str(c.text) % args if not args.is_empty() else str(c.text)
	if card == "habit_offer" and ALAN.has(id):
		c["speaker"] = "Alan (Co-owner)"
	for opt in c.options:
		if (opt.fx as Dictionary).has("habit_adopt"):
			opt.fx["habit_adopt"] = id
			opt["need"] = int(cost(id).cash)
	var key := "%s_%s" % [card, id]
	Owner._dynamic[key] = c
	Owner.show_card(key)


# fx habit_adopt: pay and start (or re-start) a habit from a card
static func apply_adopt(id: String) -> void:
	if adopt(id):
		touch(id)


# the fx habit_start forwarder: one id or a list of ids
static func apply_start(ids: Variant) -> void:
	if ids is Array:
		for one in ids:
			start(str(one))
	else:
		start(str(ids))


# the fx habit forwarder
static func apply_touch(id: String) -> void:
	if not touch(id):
		start(id)  # first time: doing the real thing counts as adopting it


# ---- the real events (each a one line hook in the system it belongs to; all do nothing while the habit is not working) ---
# H2: a business review goes out with the one page scorecard (mood +2, a better chance for a change order)
static func qbr(client: int) -> void:
	var f := factor("H2")
	if f <= 0.0:
		return
	touch("H2")
	Growth.owner_used += 1.0
	Sales.adjust(client, int(round(2.0 * f)))
	Msp.send_text("Marge", str(TEXT.scorecard) % str(Msp.CLIENTS[client].name))


# H2: extra odds for Projects.change_order (+10 points)
static func change_odds() -> float:
	return 0.10 * factor("H2")


# H3: a project is quoted with scope, steps, risk and rollback (2 hours of the owner)
static func project() -> void:
	if touch_if("H3"):
		Growth.owner_used += 2.0


# H4: a refusal went on paper (the waiver option of the client who said no)
static func refusal(choice: String) -> void:
	if choice == "waiver" and touch_if("H4"):
		Growth.owner_used += 1.0


# H4: what the paper saves when the refused thing goes wrong (cash)
static func refusal_save() -> int:
	return int(250.0 * factor("H4"))


# H5: a client is gone: review the real cause (2 hours), the same loss costs less for 8 weeks
static func loss(_client: int) -> void:
	if touch_if("H5"):
		Growth.owner_used += 2.0
		Owner.flags["h5_until"] = Campaign.day + 8
		Msp.send_text("Marge", str(TEXT.review))


# H6: someone left (a hire or a tech): the checklist closes their logins; without it a revenge mail may come (only for a habit let go)
static func departure(who: String) -> void:
	if touch_if("H6"):
		Growth.owner_used += 1.0
		Msp.send_text("Marge", str(TEXT.offboard) % who)
		return
	var s := state("H6")
	if (s == STALE or s == LAPSED) and randf() < REVENGE_CHANCE:
		_card("habit_revenge", "H6", [who])


# H10: a new client signed after an honest assessment starts happier (mood +6)
static func new_client(client: int) -> void:
	var bonus := int(round(6.0 * factor("H10")))
	if bonus != 0:
		Sales.adjust(client, bonus)


# H10: win chance points taken off an assessment-led pitch (-3 points), for the sales code to read
static func assess_win_adj() -> float:
	return -0.03 * factor("H10")


# H11: the share of the onsite job time left at a client with a runbook and a map (0.8 fresh)
static func onsite_mult(client: int) -> float:
	if _listed(entry("H11").get("maps", []), client):
		return 1.0 - 0.2 * factor("H11")
	return 1.0


# H12: walk-around finding chance times this (+20 percent)
static func walk_mult() -> float:
	return 1.0 + 0.2 * factor("H12")


# H12: the front desk saw the mood slip (the CLIENTS chip)
static func drifting(client: int) -> bool:
	if factor("H12") <= 0.0:
		return false
	var prev: Dictionary = entry("H12").get("moods", {})
	if not prev.has(str(client)):
		return false
	return Sales.mood(client) <= int(prev[str(client)]) - DRIFT_DROP


# ---- queries the other systems call (neutral while the habit is not fresh) ---------------------------------------------
# poach_gaps: the third gap, "no restore proof", only for a player who started H1 and let it go stale
static func gap_restore() -> bool:
	return Owner.habits.has("H1") and not fresh("H1")


# poach_risk: a fresh restore test lowers the failing-backup risk from 7 to 3 percent; a loss review lowers it for 8 weeks
static func poach_adjust(client: int) -> float:
	var r := 0.0
	if not bool(Msp.backups[client].ok):
		r -= 0.04 * factor("H1")
	if int(Owner.flags.get("h5_until", -1)) >= Campaign.day:
		r -= 0.02 * factor("H5")
	return r


# Incident.miss_share multiplier (H4, H7, H13 together make a scam harder)
static func bec_mult() -> float:
	return 1.0 - 0.15 * factor("H7") - 0.05 * factor("H13") - 0.05 * factor("H4")


# _rdp_week: a unique admin login makes a guessed password rarer (4 percent -> 1 percent when weak)
static func rdp_mult(weak: bool) -> float:
	return 1.0 - 0.75 * factor("H7") if weak else 1.0


# ransom restore: the share of ransoms that fail to restore when the client HAS the backup service (untested 15 percent)
static func restore_fail() -> float:
	if not Owner.habits.has("H1") or fresh("H1"):
		return 0.0
	return 0.15


# ransom bill multiplier (H1 fresh: x0.5)
static func ransom_mult() -> float:
	return 1.0 - 0.5 * factor("H1")


# vendor breach damage multiplier (H7: x0.5, offboarding x0.9, default passwords changed a little less)
static func breach_mult() -> float:
	return (
		(1.0 - 0.5 * factor("H7"))
		* (1.0 - 0.1 * factor("H6"))
		* (1.0 - 0.05 * site_share() * factor("H14"))
	)


# the share of the clients whose default device passwords are changed
static func site_share() -> float:
	if Sales.active.is_empty():
		return 0.0
	var n := 0
	for c in Sales.active:
		if _listed(entry("H14").get("sites", []), int(c)):
			n += 1
	return float(n) / float(Sales.active.size())


# fixed-price creep (H3: 30 percent -> 18 percent)
static func creep(base: float) -> float:
	return base - (base - 0.18) * factor("H3") if base > 0.18 else base
