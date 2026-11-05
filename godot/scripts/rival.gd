extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the rap sheet of the rival MSPs (docs/scope-bad-habits.md section 2). A static helper (no state of its own, like Incident):
# what the player has learned lives in Owner.flags["rap_<rival>_<habit>"] (int 0-3, saved with the campaign) and only ever goes UP.
# Levels: 0 UNKNOWN, 1 RUMOUR (heard, cannot be used), 2 SEEN (you saw it yourself), 3 PROVEN (a document, photo, log or vendor letter).
# The beats of the 20 week arc are cards in RivalCards.CARDS. arc_week() queues them, morning() shows them.
# Ideas only from the blog series the doc credits: no names, scenes or lines from it. 2013-14 text rules apply (3x5 font charset).
# OWNER OF THIS FILE: the rival/beats agent. Public signatures below are FINAL; fill the TODO bodies.

const LEVELS := ["UNKNOWN", "RUMOUR", "SEEN", "PROVEN"]
const UNKNOWN := 0
const RUMOUR := 1
const SEEN := 2
const PROVEN := 3

# the 17 habits: name (short, for the tab), text (our wording), twin (the matching good habit of the player, Habits.HABITS)
const DEFAULT_HABITS := {
	"R01":
	{
		"name": "FREEZER BAG BACKUP",
		"text":
		"The only backup is one USB drive in a freezer bag in the owner's trunk, trusted because the light is on.",
		"twin": "H1"
	},
	"R02":
	{
		"name": "ONE ADMIN PASSWORD",
		"text": "One admin password for every client, and the front desk has it on a yellow note.",
		"twin": "H7"
	},
	"R03":
	{
		"name": "TWO-FACTOR LOGIN OFF",
		"text": "Two-factor login switched off for convenience on the hosted email.",
		"twin": "H4"
	},
	"R04":
	{
		"name": "GREEN DASHBOARD",
		"text":
		"Antivirus, backup and monitoring agents are installed but never configured: a green dashboard and nothing watching.",
		"twin": "H11"
	},
	"R05":
	{
		# the 17 habits: name (short, for the tab), text (our wording), twin (the matching good habit of the player, Habits.HABITS)
		"name": "FALSE QUESTIONNAIRES",
		"text": "False answers on the client's and the insurer's security questionnaire.",
		"twin": "H10"
	},
	"R06":
	{
		"name": "SEAT COUNT LIES",
		"text": "Lies to the vendor about seat counts for a discount.",
		"twin": "H10"
	},
	"R07":
	{
		"name": "REBOOT AS DIAGNOSTICS",
		"text": "Bills a reboot as advanced diagnostics and invents fees.",
		"twin": "H2"
	},
	"R08":
	{
		"name": "FAKE FIXES",
		"text": "Fakes a fix on the phone to calm a nervous client.",
		"twin": "H13"
	},
	"R09":
	{
		"name": "FAKE REVIEWS",
		"text":
		"Fake Yowl reviews and forum personas, and whispers that you are not bonded or HIPAA safe.",
		"twin": "H10"
	},
	"R10":
	{
		"name": "LAUNDERED LEADS",
		"text":
		"Uses leads that came from reading your tickets in a shared mailbox, then launders them through a referral.",
		"twin": "H13"
	},
	"R11":
	{
		"name": "FLAT PRICE",
		"text":
		"One flat per-seat price and nothing itemized, so the client cannot see what is not included.",
		"twin": "H2"
	},
	"R12":
	{
		"name": "NO DOCUMENTATION",
		"text": "Undocumented work: no scope, no change ticket, three photos as documentation.",
		"twin": "H3"
	},
	"R13":
	{
		"name": "ARCHIVING OFF",
		"text": "Email archiving switched off so a partner can delete messages.",
		"twin": "H4"
	},
	"R14":
	{
		"name": "OLD LOGINS ALIVE",
		"text": "Ex-employees and an ex-vendor rep still have working logins.",
		"twin": "H6"
	},
	"R15":
	{
		"name": "OPEN DOOR AND DEFAULTS",
		"text":
		"A temporary firewall exception open since 2012, and default camera and printer passwords.",
		"twin": "H8"
	},
	"R16":
	{
		"name": "CLOCK CHANGE WINDOW",
		"text":
		"A 2:30 a.m. maintenance window that the clock change eats, and root cause recorded as Unknown.",
		"twin": "H9"
	},
	"R17":
	{
		"name": "IGNORES THE FRONT DESK",
		"text": "Ignores the one person at the client who sees the symptoms first.",
		"twin": "H12"
	},
}
static var HABITS: Dictionary = DEFAULT_HABITS.duplicate(true)

# the rivals: name (for lines and tabs), owner, habits (the rap sheet), blurb (tab text)
const DEFAULT_RIVALS := {
	"bytebrothers":
	{
		"name": "BYTEBROTHERS",
		"owner": "THE BROTHERS",
		"habits": ["R04", "R11", "R12", "R16", "R17"],
		"blurb": "The discount shop. Twenty percent under, twenty percent less delivered."
	},
	"bigcheese":
	{
		"name": "BIG CHEESE",
		"owner": "REX CALLOWAY",
		"habits":
		[
			"R01",
			"R02",
			"R03",
			"R04",
			"R05",
			"R06",
			"R07",
			"R08",
			"R09",
			"R10",
			"R11",
			"R12",
			"R13",
			"R14",
			"R15",
			"R16",
			"R17"
		],
		"blurb": "Big Cheese Technology Group. We do it all for $39 a seat. Booked solid."
	},
	"plumbline":
	{
		"name": "PLUMB LINE",
		"owner": "HOLLIS GRADY",
		"habits": [],
		"blurb": "The careful one who cannot sell. Nine page proposals."
	},
}
static var RIVALS: Dictionary = DEFAULT_RIVALS.duplicate(true)

# the arc: the week a beat card should be SEEN -> its card id in RivalCards.CARDS (docs section 2.4). Skipped while the card does not exist.
const ARC := {
	3: "rival_flat",
	5: "rival_wall",
	7: "rival_defect",
	8: "temp_seats",
	9: "temp_reboot",
	10: "rival_notebook",
	11: "rival_takeover",
	12: "temp_review",
	13: "rival_2fa",
	15: "rival_vendor_audit",
	16: "temp_quest",
	17: "rival_exposed",
	18: "rival_blitz",
	19: "rival_badday",
}
const QUEUE_KEY := "arc_queue"  # Owner.flags: card ids waiting for the next morning


# ---- the rap sheet ----------------------------------------------------------------------------------------------
static func key(rival: String, habit: String) -> String:
	return "rap_%s_%s" % [rival, habit]


# 0-3 (see LEVELS)
static func rap(rival: String, habit: String) -> int:
	return clampi(int(Owner.flags.get(key(rival, habit), 0)), 0, 3)


# raise the level; evidence never goes down. True when it went up.
static func set_rap(rival: String, habit: String, level: int) -> bool:
	level = clampi(level, 0, 3)
	if level <= rap(rival, habit):
		return false
	Owner.flags[key(rival, habit)] = level
	return true


# how many habits of this rival are known at exactly this level
static func count(rival: String, level: int) -> int:
	var n := 0
	for h in RIVALS.get(rival, {}).get("habits", []):
		n += 1 if rap(rival, str(h)) == level else 0
	return n


# true when anything at all is known about the rival
static func known(rival: String) -> bool:
	for level in [RUMOUR, SEEN, PROVEN]:
		if count(rival, level) > 0:
			return true
	return false


# the weekly report line: BIG CHEESE: 3 PROVEN, 2 SEEN, 1 RUMOUR ("" while nothing is known)
static func line(rival: String) -> String:
	var parts := []
	for level in [PROVEN, SEEN, RUMOUR]:
		var n := count(rival, level)
		if n > 0:
			parts.append("%d %s" % [n, LEVELS[level]])
	if parts.is_empty():
		return ""
	return "%s: %s" % [str(RIVALS.get(rival, {}).get("name", rival.to_upper())), ", ".join(parts)]


# every known line, for the weekly report and the RIVALS tab
static func lines() -> Array:
	var out := []
	for r in RIVALS:
		var l := line(str(r))
		if l != "":
			out.append(l)
	return out


# the best level the player holds on a habit across all rivals (the warning options need SEEN or better)
static func best(habit: String) -> int:
	var top := 0
	for r in RIVALS:
		top = maxi(top, rap(str(r), habit))
	return top


# the evidence fx: rap [rival, habit, level], or a list of those
static func apply_rap(fx: Array) -> void:
	if not fx.is_empty() and fx[0] is Array:
		for one in fx:
			apply_rap(one)
		return
	if fx.size() >= 3:
		set_rap(str(fx[0]), str(fx[1]), int(fx[2]))


# ---- the arc (weeks 3-20) ---------------------------------------------------------------------------------------
# called from Owner.settle() with the week just finished: queue the beat for NEXT week (so the card comes up in the morning).
# Only cards that exist are queued; a queued card is shown once (flag arc_<id>).
static func arc_week(owner: Node, week: int) -> void:
	var id: String = str(ARC.get(week + 1, ""))
	if id == "" or owner.flags.has("arc_" + id) or owner.card_data(id).is_empty():
		return
	# TODO(rival agent): conditions per beat (needs a client for rival_defect, only while the habit is unknown, jitter from Difficulty.rng("rival"))
	var q: Array = owner.flags.get(QUEUE_KEY, [])
	if not q.has(id):
		q.append(id)
	owner.flags[QUEUE_KEY] = q


# called from Owner.begin_day() next to Incident.morning(): show one queued beat card
static func morning(owner: Node) -> void:
	var q: Array = owner.flags.get(QUEUE_KEY, [])
	if q.is_empty():
		return
	var id := str(q.pop_front())
	owner.flags[QUEUE_KEY] = q
	owner.flags["arc_" + id] = Campaign.day
	owner.show_card(id)


# ---- channels (other files call these) ----------------------------------------------------------------------------
# Vic hears it at the Chamber lunch: an unreliable RUMOUR about a habit of the rival. Returns the habit id learned ("" if none).
static func intel(_rival: String) -> String:
	# TODO(rival agent): pick an unknown habit with Difficulty.rng("rival"), colour it by Owner.vic_plan, set RUMOUR
	return ""


# the defect / winback channel: what a client who left for the rival tells you (SEEN) about R11 and friends
static func defect_exit(_rival: String, _client: int) -> void:
	# TODO(rival agent): set_rap(rival, "R11", SEEN) and queue the inherited mess for the winback card
	pass


# the findings of an assessment of a lead's incumbent (the sales campaign P5 uses it): 3 to 5 habit ids from the rap sheet
static func assessment(rival: String) -> Array:
	var pool: Array = RIVALS.get(rival, {}).get("habits", []).duplicate()
	if pool.is_empty():  # nobody on file (in-house, no incumbent, Plumb Line): the usual mess of a small office
		pool = ["R01", "R02", "R04", "R12", "R14", "R15"]
	var r: RandomNumberGenerator = Difficulty.rng_for("assess", int(SalesCampaign.flags.get("assess_n", 0)) * 17 + Campaign.day)
	for i in range(pool.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var picked := pool.slice(0, mini(pool.size(), 3 + r.randi() % 3))
	picked.sort()
	return picked
