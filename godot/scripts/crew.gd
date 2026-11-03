extends Node
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# The service desk crew (service manager campaign, C4 / V1). You are Dan and these are the people who report to you:
# Maya (a real NPC on the main floor) and two techs who work the phones in the back (Sam and Terry, numbers only).
# Each has a skill, a morale (0-100), a stress number, a "retention" bonus you earn in 1:1s and a mentoring count.
# The crew works the ticket queue by itself through the crew gate (Owner.team_speed / _work_queue); skill() is what
# Owner.crew_skill() returns in this mode. Morale drifts at the end of each day (Service.close_day), a tech with very low
# morale can quit, and a tech who is "stuck" contributes nothing until you help or the time runs out. V1 keeps all of
# that as simple numbers; the Dispatch board, capacity view and real NPC techs are C5.

const ROSTER := [
	{"name": "Maya", "skill": 1.0, "title": "TIER 1"},
	{"name": "Sam", "skill": 0.7, "title": "TIER 1"},
	{"name": "Terry", "skill": 0.9, "title": "TIER 1"},
]
const START_MORALE := 65
const QUIT_BELOW := 22  # morale under this can make a tech quit at the end of the day
const MAYA_CAP := 1.3  # mentoring raises Maya's skill up to here

var members := {}  # name -> {skill, morale, stress, retain, mentored, gone, last_oto}
var stuck := {}  # {who, ticket, left} while somebody waits for your help (empty = nobody)
var quits: Array = []  # names that left during the run


func _ready() -> void:
	reset()


func reset() -> void:
	members = {}
	for row in ROSTER:
		members[str(row.name)] = {
			"skill": float(row.skill),
			"morale": START_MORALE,
			"stress": 20,
			"retain": 0,
			"mentored": 0,
			"gone": false,
			"last_oto": -9,
		}
	stuck = {}
	quits = []


func names(include_gone := false) -> Array:
	var out := []
	for row in ROSTER:
		var n := str(row.name)
		if include_gone or not is_gone(n):
			out.append(n)
	return out


func has(who: String) -> bool:
	return members.has(who)


func is_gone(who: String) -> bool:
	return bool(members.get(who, {}).get("gone", false))


func value(who: String, key: String) -> float:
	return float(members.get(who, {}).get(key, 0))


func morale(who: String) -> int:
	return int(value(who, "morale"))


# the average morale of everyone still here (0 when nobody is left)
func morale_avg() -> int:
	var total := 0
	var n := 0
	for who in names():
		total += morale(who)
		n += 1
	return int(round(float(total) / float(n))) if n > 0 else 0


func lowest() -> String:
	var worst := ""
	for who in names():
		if worst == "" or morale(who) < morale(worst):
			worst = who
	return worst


# a worker's speed: skill scaled by morale (low morale 0.75x, high 1.25x); somebody who is stuck adds nothing
func worker_speed(who: String) -> float:
	if is_gone(who) or str(stuck.get("who", "")) == who:
		return 0.0
	return value(who, "skill") * (0.75 + 0.5 * float(morale(who)) / 100.0)


# the crew's ticket-working skill (Owner.crew_skill in the service campaign)
func skill() -> float:
	var total := 0.0
	for who in names():
		total += worker_speed(who)
	return total


func size() -> int:
	return names().size()


func add_morale(who: String, amount: int) -> void:
	if not members.has(who) or is_gone(who):
		return
	members[who]["morale"] = clampi(morale(who) + amount, 0, 100)


func add_all(amount: int) -> void:
	for who in names():
		add_morale(who, amount)


func add_retain(who: String, amount: int) -> void:
	if members.has(who):
		members[who]["retain"] = clampi(int(value(who, "retain")) + amount, 0, 10)


func add_stress(who: String, amount: int) -> void:
	if members.has(who):
		members[who]["stress"] = clampi(int(value(who, "stress")) + amount, 0, 100)


# a day of coaching for Maya: faster, a little happier
func mentor(who: String) -> void:
	if not members.has(who) or is_gone(who):
		return
	members[who]["mentored"] = int(value(who, "mentored")) + 1
	members[who]["skill"] = minf(MAYA_CAP, value(who, "skill") + 0.03)
	add_morale(who, 2)


# the chance a tech with this morale walks out tonight (0 above QUIT_BELOW)
func quit_chance(who: String) -> float:
	if is_gone(who) or morale(who) >= QUIT_BELOW:
		return 0.0
	return clampf(float(QUIT_BELOW - morale(who)) / 40.0 - 0.03 * value(who, "retain"), 0.0, 0.8)


func quit(who: String) -> void:
	if not members.has(who) or is_gone(who):
		return
	members[who]["gone"] = true
	quits.append(who)
	if str(stuck.get("who", "")) == who:
		stuck = {}


# end of day: overload wears people down, a good day lifts them, a bad one sinks them. Returns the names who quit.
func end_day(util: float, grade: String) -> Array:
	var left := []
	for who in names():
		var dm := 0
		if util > 0.95:
			dm -= 3
			add_stress(who, 6)
		elif util < 0.45:
			dm -= 1
			add_stress(who, -4)
		else:
			add_stress(who, -3)
		dm += {"S": 2, "A": 1, "B": 0, "C": -1, "D": -3}.get(grade, 0)
		if value(who, "stress") >= 70.0:
			dm -= 1
		add_morale(who, dm)
	for who in names():
		var chance := quit_chance(who)
		if chance > 0.0 and Difficulty.rng("service.crew").randf() < chance:
			quit(who)
			left.append(who)
	return left


func to_dict() -> Dictionary:
	return {"members": members.duplicate(true), "stuck": stuck.duplicate(), "quits": quits.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("members", {})
	for who in saved:
		if members.has(who):
			for key in saved[who]:
				members[who][key] = saved[who][key]
	stuck = {}
	quits = data.get("quits", []).duplicate()
