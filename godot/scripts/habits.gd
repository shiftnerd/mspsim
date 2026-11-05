extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the good habits of the player's own MSP (docs/scope-bad-habits.md section 4). A static helper like Incident.
# State is Owner.habits: {"H1": {"start": week, "last": week, "uses": n}} (saved with the campaign). A habit that is not in it is NONE.
# Freshness: age = Campaign.day - last. ADOPTED while age < every, STALE (half the effect) until age < 2 x every, then LAPSED (no effect).
# every = 0 means it never lapses by time (H10). Touching it again (the real action: a restore test, a QBR with a value page) resets it,
# and re-adopting a STALE or LAPSED habit costs half. Effects are read through fresh() / factor() by the other systems, and every query
# returns the NEUTRAL value (1.0, 0.0, false) while the habit is not adopted, so a game without habits plays exactly as before.
# OWNER OF THIS FILE: the habits agent (habits.gd + habits_view.gd). Public signatures below are FINAL; fill the TODO bodies.

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


# what adopting it costs now: full price when NONE, half when STALE or LAPSED (re-adopt), nothing more when fresh
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
	return true


# adopt (or re-adopt) and pay cost(id). False when it cannot be paid or the habit is unknown.
static func adopt(id: String) -> bool:
	if not HABITS.has(id):
		return false
	var c := cost(id)
	if int(c.cash) > Owner.cash:
		return false
	Owner.cash -= int(c.cash)
	Growth.owner_used += float(c.hours)
	# TODO(habits agent): morale cost (Social / burnout) for two weeks
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


# called from Owner.settle(): decay, the lapse nudge (once per habit), nothing when no habit is started
static func week(owner: Node) -> void:
	for id in HABITS:
		if state(str(id)) == LAPSED and not owner.flags.has("lapsed_" + str(id)):
			owner.flags["lapsed_" + str(id)] = Campaign.day
			# TODO(habits agent): the Marge nudge card once (THE CHECKLIST HAS ONE EMPTY BOX), via owner.show_card("habit_lapsed")
		elif state(str(id)) == ADOPTED:
			owner.flags.erase("lapsed_" + str(id))


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


# ---- queries the other systems call (neutral while the habit is not fresh) ---------------------------------------------
# poach_gaps: the third gap, "no restore proof", only for a player who started H1 and let it go stale
static func gap_restore() -> bool:
	return Owner.habits.has("H1") and not fresh("H1")


# poach_risk: a fresh restore test lowers the failing-backup risk from 7 to 3 percent; TODO(habits agent): H5 and H12 terms
static func poach_adjust(client: int) -> float:
	var r := 0.0
	if not bool(Msp.backups[client].ok):
		r -= 0.04 * factor("H1")
	return r


# Incident.miss_share multiplier (H4, H7, H13 together make a scam harder)
static func bec_mult() -> float:
	return 1.0 - 0.15 * factor("H7") - 0.05 * factor("H13")


# _rdp_week: a unique admin login makes a guessed password rarer (4 percent -> 1 percent when weak)
static func rdp_mult(weak: bool) -> float:
	return 1.0 - 0.75 * factor("H7") if weak else 1.0


# ransom restore: the share of ransoms that fail to restore when the client HAS the backup service (untested 15 percent)
static func restore_fail() -> float:
	# TODO(habits agent): wire into _ransom (neutral until then)
	if not Owner.habits.has("H1") or fresh("H1"):
		return 0.0
	return 0.15


# ransom bill multiplier (H1 fresh: x0.5)
static func ransom_mult() -> float:
	return 1.0 - 0.5 * factor("H1")


# vendor breach damage multiplier (H7: x0.5)
static func breach_mult() -> float:
	return 1.0 - 0.5 * factor("H7")


# fixed-price creep (H3: 30 percent -> 18 percent)
static func creep(base: float) -> float:
	return base - (base - 0.18) * factor("H3") if base > 0.18 else base
