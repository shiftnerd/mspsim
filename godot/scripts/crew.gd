extends Node
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# The service desk crew (service manager campaign, C4 / V1, real people in C5 / V2). You are Dan and these are the people who
# report to you: Maya, Sam and Terry. All three are real NPCs now (Maya and Sam have desks on the main floor, Terry hot-desks
# at the conference table with his laptop). Each has a skill (speed), five skill AREAS (the Skills areas; a ticket needs a
# level in one of them), a morale (0-100), a stress number, a "retention" bonus you earn in 1:1s, a mentoring count, an
# optional FOCUS area and a state: IDLE, WORKING, OVERLOAD (3 or more tickets on the desk), STUCK (the ticket needs an area
# level above theirs) or GONE. The crew works the queue through the crew gate (Owner.team_speed / Service.work_queue);
# skill() is what Owner.crew_skill() returns in this mode. Who works what is decided by assignments (Service.assign, the
# Dispatch board or the autopilot); a good match is faster and safer, a bad one slower and more likely to reopen.

const AREAS := ["powershell", "networking", "servers", "security", "people"]
const AREA_TAG := {"powershell": "PWS", "networking": "NET", "servers": "SRV", "security": "SEC", "people": "PPL"}
const FIX_AREA := {
	"spooler": "networking",
	"password": "security",
	"clear_temp": "powershell",
	"reboot": "servers",
	"av": "security",
	"restore": "security",
	"adobe": "servers",
}
const FIX_NEED := {"reboot": 1, "clear_temp": 1, "password": 1, "adobe": 1, "spooler": 1, "av": 2, "restore": 2}
const ROSTER := [
	{
		"name": "Maya", "skill": 1.0, "title": "TIER 1",
		"areas": {"powershell": 1.0, "networking": 2.0, "servers": 2.0, "security": 1.0, "people": 3.0},
	},
	{
		"name": "Sam", "skill": 0.7, "title": "TIER 1",
		"areas": {"powershell": 0.0, "networking": 1.0, "servers": 1.0, "security": 1.0, "people": 2.0},
	},
	{
		"name": "Terry", "skill": 0.9, "title": "TIER 1",
		"areas": {"powershell": 1.0, "networking": 1.0, "servers": 2.0, "security": 2.0, "people": 1.0},
	},
]
const START_MORALE := 65
const QUIT_BELOW := 22  # morale under this can make a tech quit at the end of the day
const MAYA_CAP := 1.3  # mentoring raises Maya's skill up to here
const AREA_CAP := 5.0
const OVERLOAD_AT := 3  # tickets on one desk at which a tech is overloaded
const STUCK_AFTER := 16.0  # seconds of working a ticket above your level before you stall
const STUCK_ASK := 20.0  # seconds a stuck tech waits for you before calling an owner
const STUCK_GIVE_UP := 50.0  # seconds before he pushes through alone (slow, and more likely to reopen)

var members := {}  # name -> {skill, morale, stress, retain, mentored, gone, last_oto, areas, focus, over_t, work_t, over_days, done, stalls}
var stuck := {}  # name -> {ticket, left, asked} while somebody waits for you or an owner
var quits: Array = []  # names that left during the run
var farewells: Array = []  # names that left and still owe you a goodbye card


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
			"areas": row.areas.duplicate(),
			"focus": "",
			"over_t": 0.0,
			"work_t": 0.0,
			"over_days": 0,
			"done": 0,
			"stalls": 0,
		}
	stuck = {}
	quits = []
	farewells = []


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


func is_stuck(who: String) -> bool:
	return stuck.has(who)


# a worker's speed: skill scaled by morale (low morale 0.75x, high 1.25x); somebody who is stuck adds nothing
func worker_speed(who: String) -> float:
	if is_gone(who) or stuck.has(who):
		return 0.0
	return raw_speed(who)


func raw_speed(who: String) -> float:
	if is_gone(who):
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


# ---- skill areas -----------------------------------------------------------------------------------------------------
func area_level(who: String, area: String) -> float:
	return float(members.get(who, {}).get("areas", {}).get(area, 0.0))


func level(who: String, area: String) -> int:
	return int(floor(area_level(who, area)))


func train(who: String, area: String, amount: float) -> void:
	if not members.has(who) or not AREAS.has(area):
		return
	members[who]["areas"][area] = minf(AREA_CAP, area_level(who, area) + amount)


# the lowest of the four technical areas (what coaching works on when no focus is set)
func weakest_area(who: String) -> String:
	var worst := "networking"
	for a in ["powershell", "networking", "servers", "security"]:
		if area_level(who, a) < area_level(who, worst):
			worst = a
	return worst


# coaching / 1:1 skill gain: the speed number and the area they are working on (their focus, else their weakest)
func skill_gain(who: String, amount: float) -> void:
	if not members.has(who):
		return
	members[who]["skill"] = minf(MAYA_CAP, value(who, "skill") + amount)
	var area := focus_of(who)
	train(who, area if area != "" else weakest_area(who), amount * 4.0)


func focus_of(who: String) -> String:
	return str(members.get(who, {}).get("focus", ""))


# people can be given a focus: the area they train in every day, and tickets of that area fit them better
func set_focus(who: String, area: String) -> void:
	if members.has(who) and (area == "" or AREAS.has(area)):
		members[who]["focus"] = area


func cycle_focus(who: String) -> String:
	var order := [""] + AREAS
	var i := order.find(focus_of(who))
	var next: String = order[(i + 1) % order.size()]
	set_focus(who, next)
	return next


# ---- tickets: what they need, how well somebody fits ----------------------------------------------------------------
func area_of(t: Dictionary) -> String:
	return str(FIX_AREA.get(str(t.fix), "servers"))


func need_of(t: Dictionary) -> int:
	return mini(4, int(FIX_NEED.get(str(t.fix), 1)) + (1 if int(t.pri) == 1 else 0))


func tag_of(t: Dictionary) -> String:
	return str(AREA_TAG[area_of(t)])


# whole levels between what the ticket needs and what he has (1 or more = the ticket is above his head)
func gap_of(who: String, t: Dictionary) -> int:
	return need_of(t) - level(who, area_of(t))


func gap_f(who: String, t: Dictionary) -> float:
	return float(need_of(t)) - area_level(who, area_of(t))


# how fast he works this ticket compared with a perfect match
func match_mult(who: String, t: Dictionary) -> float:
	var g := gap_f(who, t)
	if g <= 0.0:
		return minf(1.12, 1.0 - 0.06 * g)
	return clampf(1.0 - 0.4 * g, 0.2, 1.0)


# extra odds that the ticket comes back (a fit is a little safer than neutral)
func reopen_add(who: String, t: Dictionary) -> float:
	var g := gap_f(who, t)
	if g <= -1.0:
		return -0.03
	if g <= 0.0:
		return 0.0
	return minf(0.3, 0.12 * g)


func assignee_of(t: Dictionary) -> String:
	return str(t.get("assignee", ""))


func load_of(who: String) -> int:
	var n := 0
	for t in Msp.tickets:
		if str(t.status) != "Closed" and assignee_of(t) == who:
			n += 1
	return n


# skill match x load x mood (+ the focus bonus): 0 to about 1.2. `t` may already be on his desk (it does not count as load)
func fit(who: String, t: Dictionary) -> float:
	if is_gone(who):
		return 0.0
	var base := clampf(1.0 - 0.45 * gap_f(who, t), 0.1, 1.1)
	var load := load_of(who) - (1 if assignee_of(t) == who else 0)
	var f := base * (1.0 - 0.18 * float(load)) * (0.85 + 0.3 * float(morale(who)) / 100.0)
	if area_of(t) == focus_of(who):
		f += 0.1
	if stuck.has(who):
		f *= 0.2
	return clampf(f, 0.0, 1.2)


# the best tech for a ticket among those with fewer than `max_load` tickets who are not stuck ("" = nobody free)
func best_for(t: Dictionary, max_load := 2) -> String:
	var best := ""
	var best_fit := -1.0
	for who in names():
		if stuck.has(who) or load_of(str(who)) >= max_load:
			continue
		var f := fit(str(who), t)
		if f > best_fit + 0.0001:
			best_fit = f
			best = str(who)
	return best


# ---- state, load and hours --------------------------------------------------------------------------------------------
func status(who: String) -> String:
	if is_gone(who):
		return "GONE"
	if stuck.has(who):
		return "STUCK"
	var n := load_of(who)
	if n >= OVERLOAD_AT:
		return "OVERLOAD"
	return "WORKING" if n > 0 else "IDLE"


# the speech-bubble glyph over their head ("" = none)
func glyph_of(who: String) -> String:
	match status(who):
		"STUCK":
			return "?"
		"OVERLOAD":
			return "!"
	return ""


func remaining(t: Dictionary) -> float:
	return float(Owner._work.get(int(t.id), Owner.WORK[int(t.pri)]))


# ticket-seconds of work they do per second (the crew's total speed split by speed; ignores being stuck, for the bars)
func rate(who: String) -> float:
	var total := 0.0
	for n in names():
		total += raw_speed(str(n))
	if total <= 0.0:
		return 0.0
	return Owner.team_speed() * raw_speed(who) / total


func backlog_secs(who: String) -> float:
	var r := rate(who)
	if r <= 0.0:
		return 0.0
	var secs := 0.0
	for t in Msp.tickets:
		if str(t.status) != "Closed" and assignee_of(t) == who:
			secs += remaining(t) / (r * maxf(0.2, match_mult(who, t)))
	return secs


func secs_per_hour() -> float:
	return maxf(1.0, World.day_len / 8.0)


func hours_left() -> float:
	return maxf(0.0, World.DAY_END - World.clock)


func load_hours(who: String) -> float:
	return backlog_secs(who) / secs_per_hour()


# queued work over the hours left today (1.0 = just enough time, over 1.0 = it will not get done today)
func utilisation(who: String) -> float:
	var h := load_hours(who)
	if h <= 0.0:
		return 0.0
	return h / maxf(0.25, hours_left())


# called every frame-ish by Service._process: counts the time a tech spends overloaded and working
func tick(dt: float) -> void:
	for who in names():
		var m: Dictionary = members[who]
		var n := load_of(str(who))
		if n > 0:
			m["work_t"] = float(m.work_t) + dt
		if n >= OVERLOAD_AT:
			m["over_t"] = float(m.over_t) + dt


# he did a ticket: a little learning by doing (more when it stretched him)
func note_done(who: String, t: Dictionary) -> void:
	if not members.has(who):
		return
	members[who]["done"] = int(members[who].done) + 1
	train(who, area_of(t), 0.008 + (0.02 if gap_of(who, t) >= 1 else 0.0))


# the tech is helped: his stuck ticket was moved or closed
func free_stuck(who: String, reason: String) -> void:
	if not stuck.has(who):
		return
	stuck.erase(who)
	match reason:
		"closed":
			add_morale(who, 4)
		"moved":
			add_morale(who, 2)
			add_stress(who, -2)


# the plan kinds World picks from for a tech (busy techs stay at the desk, idle ones wander; a networking ticket sends him to the closet)
func plan_kinds(who: String) -> Array:
	var kinds: Array
	match status(who):
		"STUCK":
			kinds = ["work"]
		"OVERLOAD":
			kinds = ["work", "work", "work", "work", "work", "coffee"]
		"WORKING":
			kinds = ["work", "work", "work", "coffee", "cooler", "bathroom"]
		_:
			kinds = ["work", "coffee", "coffee", "cooler", "bathroom", "cooler"]
	if status(who) in ["WORKING", "OVERLOAD"]:
		for t in Msp.tickets:
			if str(t.status) != "Closed" and assignee_of(t) == who and area_of(t) == "networking":
				kinds.append("closet")
				break
	return kinds


# ---- coaching, quitting -----------------------------------------------------------------------------------------------
# a day of coaching for Maya: faster, a little happier
func mentor(who: String) -> void:
	if not members.has(who) or is_gone(who):
		return
	members[who]["mentored"] = int(value(who, "mentored")) + 1
	skill_gain(who, 0.03)
	add_morale(who, 2)


# the chance a tech with this morale walks out tonight (0 above QUIT_BELOW)
func quit_chance(who: String) -> float:
	if is_gone(who):
		return 0.0
	var worn := 0.0
	if morale(who) < 40 and int(members[who].get("over_days", 0)) >= 3:
		worn = 0.08 * float(int(members[who].over_days) - 2)  # three bad days of overload in a row wear anybody down
	if morale(who) >= QUIT_BELOW and worn <= 0.0:
		return 0.0
	var base := float(QUIT_BELOW - morale(who)) / 40.0 if morale(who) < QUIT_BELOW else 0.0
	return clampf(base + worn - 0.03 * value(who, "retain"), 0.0, 0.8)


func quit(who: String) -> void:
	if not members.has(who) or is_gone(who):
		return
	members[who]["gone"] = true
	quits.append(who)
	stuck.erase(who)
	Service.release_all(who)


# end of day: overload wears people down, a good day lifts them, a bad one sinks them. Returns the names who quit.
func end_day(util: float, grade: String) -> Array:
	var left := []
	for who in names():
		var m: Dictionary = members[who]
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
		# one person carrying too much: a quarter of the day with three or more tickets
		if float(m.over_t) > 0.25 * maxf(60.0, World.day_len):
			dm -= 2
			add_stress(who, 4)
			m["over_days"] = int(m.over_days) + 1
		else:
			m["over_days"] = maxi(0, int(m.over_days) - 1)
		m["over_t"] = 0.0
		m["work_t"] = 0.0
		var area := focus_of(who)
		if area != "":
			train(who, area, 0.02)  # the hour a day they spend on it
		add_morale(who, dm)
	for who in names():
		var chance := quit_chance(who)
		if chance > 0.0 and Difficulty.rng("service.crew").randf() < chance:
			quit(who)
			left.append(who)
			farewells.append(who)
	return left


func to_dict() -> Dictionary:
	return {"members": members.duplicate(true), "quits": quits.duplicate(), "farewells": farewells.duplicate()}


# old saves (C4) only know skill, morale, stress and so on: the areas and the focus start from the roster
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("members", {})
	for who in saved:
		if members.has(who):
			for key in saved[who]:
				if key == "areas":
					for a in saved[who]["areas"]:
						members[who]["areas"][a] = float(saved[who]["areas"][a])
				else:
					members[who][key] = saved[who][key]
	stuck = {}
	quits = data.get("quits", []).duplicate()
	farewells = data.get("farewells", []).duplicate()
