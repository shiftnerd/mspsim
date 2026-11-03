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
const WAGES := {"Maya": 700, "Sam": 450, "Terry": 550}  # dollars a week (the hires bring their own)
const START_LANE := {"Maya": "L2", "Sam": "L1", "Terry": "L2"}  # tiered desk: who works which lane
# C6: the crew is capped at 6 (three starting techs and three hires). The seating you have: Maya (main floor desk 2) and Sam (desk 1)
# have desks, Terry and the hires hot-desk at the conference table (Seat6, then Seat4, Seat5 and Seat3 for hires one to three).
const MAX_CREW := 6
const HIRE_SEATS := ["Seat4", "Seat5", "Seat3"]
const HIRE_SHEETS := {
	"Priya": "client_agent_b", "Marcus": "expo_atta", "Jules": "expo_attb", "Tomas": "expo_attc", "Wendy": "client_vettech_b",
	"Dev": "expo_attd", "Rosa": "client_dentasst", "Kofi": "expo_atte", "Ingrid": "client_vetrec_b", "Sal": "expo_attf",
	"Mei": "client_designer_b", "Otis": "expo_vendh",
}
const FIT_AXES := ["culture", "comm", "curiosity"]
const FIT_LABEL := {"culture": "CULTURE", "comm": "COMMUNICATION", "curiosity": "CURIOSITY"}
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
var hire_order: Array = []  # names of the techs you hired, in order (they extend the ROSTER)
var pending: Array = []  # hires that start tomorrow: {cand, path, seat}
var hired_total := 0  # everybody ever hired (the retention number's denominator)


func _ready() -> void:
	reset()


func _blank(skill: float, areas: Dictionary) -> Dictionary:
	return {
		"skill": skill,
		"morale": START_MORALE,
		"stress": 20,
		"retain": 0,
		"mentored": 0,
		"gone": false,
		"last_oto": -9,
		"areas": areas.duplicate(),
		"focus": "",
		"over_t": 0.0,
		"work_t": 0.0,
		"over_days": 0,
		"done": 0,
		"stalls": 0,
		"wage": 500,
		"lane": "L1",
		"busy_until": 0.0,
		"shadow": 0,
		"hire": false,
		"fit": {},
		"trait": "steady",
		"path": "",
		"start_day": 0,
		"solo_h": -1.0,
		"reopens": 0,
		"seat": "",
		"sheet": "",
	}


func reset() -> void:
	members = {}
	for row in ROSTER:
		var m := _blank(float(row.skill), row.areas)
		m["wage"] = int(WAGES.get(str(row.name), 500))
		m["lane"] = str(START_LANE.get(str(row.name), "L1"))
		members[str(row.name)] = m
	stuck = {}
	quits = []
	farewells = []
	hire_order = []
	pending = []
	hired_total = 0


func roster_names() -> Array:
	var out := []
	for row in ROSTER:
		out.append(str(row.name))
	out.append_array(hire_order)
	return out


func names(include_gone := false) -> Array:
	var out := []
	for n in roster_names():
		if include_gone or not is_gone(str(n)):
			out.append(str(n))
	return out


# ---- hiring (C6): the world rows, seats and the candidate generator ----------------------------------------------------
func is_pool_name(n: String) -> bool:
	return HIRE_SHEETS.has(n)


func is_hire(n: String) -> bool:
	return hire_order.has(n)


# the World cast row of a hire: they hot-desk at the conference table
func hire_row(n: String) -> Dictionary:
	return {"character": str(HIRE_SHEETS.get(n, "office_teen")), "home": "conference", "seat": seat_of(n), "role": "crew"}


func seat_of(n: String) -> String:
	var s := str(members.get(n, {}).get("seat", ""))
	return s if s != "" else str(HIRE_SEATS[0])


func free_seat() -> String:
	var used := []
	for n in hire_order:
		if not is_gone(str(n)):
			used.append(seat_of(str(n)))
	for p in pending:
		used.append(str(p.get("seat", "")))
	for s in HIRE_SEATS:
		if not used.has(s):
			return str(s)
	return ""


func open_seats() -> int:
	return maxi(0, MAX_CREW - names().size() - pending.size())


func can_hire() -> bool:
	return open_seats() > 0 and free_seat() != ""


func _name_pool() -> Array:
	var taken := roster_names()
	for p in pending:
		taken.append(str(p.cand.name))
	var out := []
	for n in Owner.NAMES:
		if not taken.has(n) and HIRE_SHEETS.has(n):
			out.append(n)
	return out


# three named candidates: a ringer (high skill, poor fit, dear), a good fit with less skill who grows, and a middle one.
# Fit has three axes 1-5: culture (team mood), communication (clients), curiosity (how fast they learn). Seeded.
func make_candidates(count := 3) -> Array:
	var rng := Difficulty.rng("service.hire")
	var pool := _name_pool()
	for i in range(pool.size() - 1, 0, -1):  # a seeded shuffle
		var j := rng.randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var kinds := ["ringer", "fit", "mid"]
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp2 = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp2
	var out := []
	var tech_areas := ["powershell", "networking", "servers", "security"]
	for i in mini(count, pool.size()):
		var kind: String = kinds[i % kinds.size()]
		var skill := 1.0
		var fit := {}
		var trait_ids := ["steady"]
		match kind:
			"ringer":
				skill = snappedf(rng.randf_range(1.1, 1.3), 0.05)
				fit = {"culture": 1 + rng.randi() % 2, "comm": 2 + rng.randi() % 2, "curiosity": 2 + rng.randi() % 2}
				trait_ids = ["wizard", "flight"]
			"fit":
				skill = snappedf(rng.randf_range(0.55, 0.8), 0.05)
				fit = {"culture": 4 + rng.randi() % 2, "comm": 3 + rng.randi() % 3, "curiosity": 4 + rng.randi() % 2}
				trait_ids = ["green", "people", "steady"]
			_:
				skill = snappedf(rng.randf_range(0.8, 1.05), 0.05)
				fit = {"culture": 3 + rng.randi() % 2, "comm": 3 + rng.randi() % 2, "curiosity": 3 + rng.randi() % 2}
				trait_ids = ["steady", "people", "wizard"]
		var trait_id: String = trait_ids[rng.randi() % trait_ids.size()]
		var strong: String = tech_areas[rng.randi() % tech_areas.size()]
		var areas := {"powershell": 1.0, "networking": 1.0, "servers": 1.0, "security": 1.0, "people": 1.0 + (1.0 if int(fit.comm) >= 4 else 0.0)}
		areas[strong] = 3.0 if kind == "ringer" else (2.0 if skill >= 0.8 else 1.5)
		var wage := int(round((280.0 + 250.0 * skill) / 10.0)) * 10 + int(Owner.TRAITS[trait_id].get("wage", 0))
		if kind == "ringer":
			wage = int(round(float(wage) * 1.25 / 10.0)) * 10  # the ringer knows what he is worth
		out.append({"name": str(pool[i]), "skill": skill, "wage": wage, "trait": trait_id, "fit": fit, "area": strong, "areas": areas, "kind": kind})
	return out


func fit_avg(who: String) -> float:
	var f: Dictionary = members.get(who, {}).get("fit", {})
	if f.is_empty():
		return 3.0
	var total := 0.0
	for a in FIT_AXES:
		total += float(f.get(a, 3))
	return total / float(FIT_AXES.size())


# the hire starts tomorrow: path "shadow" (sits with the team for two days, no tickets of his own) or "structured"
func hire(cand: Dictionary, path: String) -> void:
	var seat := free_seat()
	pending.append({"cand": cand.duplicate(true), "path": path, "seat": seat})
	hired_total += 1


# called at the end of the day: the people hired today become crew members for tomorrow. Returns their names.
func onboard_pending(day: int) -> Array:
	var out := []
	for p in pending:
		var cand: Dictionary = p.cand
		var n := str(cand.name)
		var m := _blank(float(cand.skill), cand.areas)
		m["wage"] = int(cand.wage)
		m["hire"] = true
		m["fit"] = cand.fit.duplicate()
		m["trait"] = str(cand.trait)
		m["path"] = str(p.path)
		m["start_day"] = day + 1
		m["shadow"] = 2 if str(p.path) == "shadow" else 0
		m["seat"] = str(p.seat) if str(p.seat) != "" else str(HIRE_SEATS[0])
		m["sheet"] = str(HIRE_SHEETS.get(n, "office_teen"))
		m["lane"] = "L2" if float(cand.skill) >= 0.95 and float(cand.areas.get(str(cand.area), 1.0)) >= 2.0 else "L1"
		m["morale"] = START_MORALE + (3 if str(p.path) == "shadow" else 0)
		members[n] = m
		hire_order.append(n)
		out.append(n)
	pending = []
	return out


func is_shadowing(who: String) -> bool:
	return int(members.get(who, {}).get("shadow", 0)) > 0 and not is_gone(who)


func busy(who: String) -> bool:
	return World.clock < float(members.get(who, {}).get("busy_until", 0.0)) and not is_gone(who)


# somebody is away from the queue for `hours` of the working day (writing a runbook, a lesson, a day off)
func set_busy(who: String, hours: float) -> void:
	if members.has(who):
		members[who]["busy_until"] = maxf(float(members[who].get("busy_until", 0.0)), World.clock + hours)


func payroll_week() -> int:
	var total := 0
	for n in names():
		total += int(value(str(n), "wage"))
	return total


# techs still here against everyone who ever worked for you on the desk (the three you started with, plus the hires)
func retention_pct() -> int:
	var ever := ROSTER.size() + hired_total - pending.size()
	if ever <= 0:
		return 100
	return int(round(100.0 * float(names().size()) / float(ever)))


func newest_hire() -> String:
	return str(hire_order[-1]) if not hire_order.is_empty() else ""


# mean hours of working time from the first morning to the first ticket closed on their own (-1 = nobody has yet)
func solo_mean_hours() -> float:
	var total := 0.0
	var n := 0
	for h in hire_order:
		var v := value(str(h), "solo_h")
		if v >= 0.0:
			total += v
			n += 1
	return total / float(n) if n > 0 else -1.0


func note_reopen(who: String) -> void:
	if members.has(who):
		members[who]["reopens"] = int(members[who].get("reopens", 0)) + 1


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
	if is_gone(who) or is_shadowing(who) or busy(who):
		return 0.0
	var ramp := 0.8 if (is_hire(who) and str(members[who].get("path", "")) == "structured" and Campaign.day - int(members[who].get("start_day", 0)) < 2) else 1.0
	return value(who, "skill") * (0.75 + 0.5 * float(morale(who)) / 100.0) * ramp


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
	return need_of(t) - level(who, area_of(t)) - int(Service.kb.relief(t))


func gap_f(who: String, t: Dictionary) -> float:
	return float(need_of(t)) - area_level(who, area_of(t)) - float(Service.kb.relief(t))


# how fast he works this ticket compared with a perfect match
func match_mult(who: String, t: Dictionary) -> float:
	var g := gap_f(who, t)
	var m := minf(1.12, 1.0 - 0.06 * g) if g <= 0.0 else clampf(1.0 - 0.4 * g, 0.2, 1.0)
	return m * float(Service.kb.speed(t)) * float(Service.design_speed(who, t))


# extra odds that the ticket comes back (a fit is a little safer than neutral)
func reopen_add(who: String, t: Dictionary) -> float:
	var g := gap_f(who, t)
	var add := 0.0
	if g <= -1.0:
		add = -0.03
	elif g > 0.0:
		add = minf(0.3, 0.12 * g)
	return add + float(Service.kb.safety(t)) + float(Service.design_reopen(who, t)) + onboarding_reopen(who)


# the first ten days of a hire: shadowing leaves habits (a few more reopens), a structured start with runbooks a few fewer
func onboarding_reopen(who: String) -> float:
	if not is_hire(who) or Campaign.day - int(members[who].get("start_day", 0)) >= 10:
		return 0.0
	if str(members[who].get("path", "")) == "shadow":
		return 0.04
	return -0.02 if Service.kb.documented_count() >= 3 else 0.0


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
	if is_gone(who) or is_shadowing(who):
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
		if stuck.has(who) or is_shadowing(str(who)) or load_of(str(who)) >= max_load:
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
	if is_shadowing(who):
		return "SHADOW"
	if busy(who):
		return "WRITING"
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
	if is_hire(who) and float(members[who].get("solo_h", -1.0)) < 0.0:
		members[who]["solo_h"] = maxf(0.5, float(Campaign.day - int(members[who].get("start_day", Campaign.day))) * 8.0 + (World.clock - World.DAY_START))


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
	# a poor fit (or a flight risk) with a sinking mood is the one who walks (C6)
	var fitrisk := 0.0
	if is_hire(who) and morale(who) < 45:
		if fit_avg(who) < 3.0:
			fitrisk += 0.04 * (3.0 - fit_avg(who))
		if str(members[who].get("trait", "")) == "flight":
			fitrisk += 0.05
	if morale(who) >= QUIT_BELOW and worn <= 0.0 and fitrisk <= 0.0:
		return 0.0
	var base := float(QUIT_BELOW - morale(who)) / 40.0 if morale(who) < QUIT_BELOW else 0.0
	return clampf(base + worn + fitrisk - 0.03 * value(who, "retain"), 0.0, 0.8)


func quit(who: String) -> void:
	if not members.has(who) or is_gone(who):
		return
	members[who]["gone"] = true
	quits.append(who)
	stuck.erase(who)
	Service.kb.on_quit(who)
	Service.crew_changed()
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
		m["busy_until"] = 0.0
		if int(m.get("shadow", 0)) > 0:
			m["shadow"] = int(m.shadow) - 1
		if bool(m.get("hire", false)):
			_hire_day(str(who), m)
	for who in names():
		var chance := quit_chance(who)
		if chance > 0.0 and Difficulty.rng("service.crew").randf() < chance:
			quit(who)
			left.append(who)
			farewells.append(who)
	return left


# a hire's day: curiosity teaches, a good fit settles in, a poor fit (the ringer who does not belong) drags the others down
func _hire_day(who: String, m: Dictionary) -> void:
	var f: Dictionary = m.get("fit", {})
	if f.is_empty():
		return
	var cur := float(f.get("curiosity", 3))
	train(who, focus_of(who) if focus_of(who) != "" else weakest_area(who), 0.004 * cur)
	if str(m.get("trait", "")) == "green":
		m["skill"] = minf(MAYA_CAP, float(m.skill) + 0.012)
	if cur >= 4.0:
		m["skill"] = minf(MAYA_CAP, float(m.skill) + 0.008)
	if float(f.get("culture", 3)) >= 4.0:
		add_morale(who, 1)
	elif float(f.get("culture", 3)) <= 2.0:
		for other in names():
			if other != who:
				add_morale(str(other), -1)


func to_dict() -> Dictionary:
	return {
		"members": members.duplicate(true), "quits": quits.duplicate(), "farewells": farewells.duplicate(),
		"hire_order": hire_order.duplicate(), "pending": pending.duplicate(true), "hired_total": hired_total,
	}


# old saves (C4) only know skill, morale, stress and so on: the areas and the focus start from the roster
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("members", {})
	hire_order = data.get("hire_order", []).duplicate()
	pending = data.get("pending", []).duplicate(true)
	hired_total = int(data.get("hired_total", hire_order.size()))
	for h in hire_order:
		if saved.has(h):
			members[str(h)] = _blank(float(saved[h].get("skill", 1.0)), saved[h].get("areas", {}))
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
