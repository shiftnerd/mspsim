extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Hour management for the tech campaign. A tech's day is more than tickets: when you leave for
# work (traffic), whether you stay late, and the on-call pager all feed ENERGY (0-100).
#   - Every morning (from day 2) a commute card: leave early (safe, tiring), on time (a gamble) or sleep
#     in (rested, late). Arriving late means tickets already ticking, abandoned calls, a coworker covering
#     for you and a text from the boss.
#   - Weeks 2 and 4 you carry the pager: some nights a page wakes you (fix it, triage it, or ignore it).
#   - At closing with tickets open: go home, or stay 1-2 hours (paid, but it costs energy).
#   - Low energy slows RMM fixes and makes them fail more; rested (85+) is a small bonus.
# Only runs when `enabled` (the title menu turns it on), so older tests are unaffected.

signal changed

const START_ENERGY := 80
const DAY_DRAIN := 20.0  # energy lost over a full working day
const REST := 22  # energy a night of sleep gives back
const STAY_COST := 8  # per hour of overtime
const STAY_PAY := 50  # per hour of overtime
const ONCALL_PAY := 40  # per on-call day
const ONCALL_WEEKS := [1, 3]  # 0-based weeks (days 6-10 and 16-20)
const PAGE_CHANCE := 0.6
const COMMUTES := {
	"early": {"base": -45, "p": 0.10, "energy": -6},
	"ontime": {"base": -5, "p": 0.30, "energy": 0},
	"late": {"base": 20, "p": 0.60, "energy": 5},
}
const DEFAULT_WEEK_TRAFFIC := {
	1: {"text": "THE HIGHWAY IS DOWN TO ONE LANE THIS WEEK.", "extra": 0.15},
	3:
	{
		"text": "SPRING STORM SEASON. THE UNDERPASS FLOODS AND EVERYONE DRIVES LIKE IT IS THE END OF THE WORLD.",
		"extra": 0.20
	},
}
var WEEK_TRAFFIC: Dictionary = DEFAULT_WEEK_TRAFFIC.duplicate(true)
const DEFAULT_REASONS := [
	"AN ACCIDENT ON THE HIGHWAY",
	"A STALLED TRUCK IN THE LEFT LANE",
	"A TRAIN SITTING ON THE CROSSING",
	"RAIN AND A FENDER BENDER",
	"ROAD WORK NOBODY WARNED YOU ABOUT",
	"A SCHOOL BUS BROKEN DOWN AT THE LIGHT",
	"A WATER MAIN BREAK AND A DETOUR THROUGH TOWN",
	"A DRAWBRIDGE STUCK OPEN",
	"A SLOW FUNERAL PROCESSION",
	"A BLOWN TIRE ON THE SHOULDER AHEAD OF YOU",
]
var REASONS: Array = DEFAULT_REASONS.duplicate(true)
const DEFAULT_PAGES := [
	"the file server is almost out of disk space",
	"the nightly backup job failed",
	"the VPN is down for the remote staff",
	"the mail queue is stuck",
	"the domain controller stopped answering pings",
	"the RAID array says it is degraded",
	"the firewall locked everybody out after the firmware update",
	"the phone system lost its SIP trunk",
	"the Exchange server is out of mailbox space",
	"the antivirus server stopped pushing updates",
	"the UPS is on battery and beeping",
	"the print server queue is stuck again",
]
var PAGES: Array = DEFAULT_PAGES.duplicate(true)

var enabled := false
var energy := float(START_ENERGY)
var late_min := 0  # today's arrival delay
var late_total := 0
var stays := 0
var stay_hours := 0.0  # today
var pages := 0
var pages_fixed := 0
var pages_ignored := 0
var last_note := ""

var _asked := false
var _last_page := ""
var _last_reason := ""
var _stay_until := 0.0
var _warned := 0
var _oncall_pay := 0


func _ready() -> void:
	reset()


func reset() -> void:
	energy = clampf(float(START_ENERGY) + Build.fx("energy"), 0.0, 100.0)  # CAFFEINE DEPENDENT / EARLY BIRD (X7)
	late_min = 0
	late_total = 0
	stays = 0
	stay_hours = 0.0
	pages = 0
	pages_fixed = 0
	pages_ignored = 0
	last_note = ""
	_asked = false
	_stay_until = 0.0
	_warned = 0
	_oncall_pay = 0


func active() -> bool:
	return enabled and Campaign.active and Campaign.mode == "tech" and not Game.title_mode


func week_of(day: int) -> int:
	return (day - 1) / 5


func on_call(day: int) -> bool:
	return ONCALL_WEEKS.has(week_of(day))


func is_on_call() -> bool:
	return active() and on_call(Campaign.day)


func traffic_text(day: int) -> String:
	return str(WEEK_TRAFFIC.get(week_of(day), {}).get("text", ""))


func is_tired() -> bool:
	return active() and energy < 30.0


func slow_mult() -> float:
	if not active():
		return 1.0
	if energy >= 85.0:
		return 0.9
	return 1.0 + clampf((55.0 - energy) / 55.0, 0.0, 1.0) * 0.5


func fail_add() -> float:
	if not active():
		return 0.0
	var extra := float(Mutators.hook("fail_add", 0.0))
	if energy >= 85.0:
		return -0.03 + extra
	return clampf((45.0 - energy) / 45.0, 0.0, 1.0) * 0.18 + extra


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, 100.0)
	changed.emit()


func label() -> String:
	if energy >= 70.0:
		return "RESTED" if energy >= 85.0 else "FINE"
	if energy >= 45.0:
		return "TIRED"
	return "WORN OUT" if energy >= 25.0 else "EXHAUSTED"


# ---- the morning ------------------------------------------------------------------------------
func begin_day(day: int) -> void:
	late_min = 0
	stay_hours = 0.0
	_asked = false
	_stay_until = 0.0
	_warned = 0
	_oncall_pay = ONCALL_PAY if on_call(day) else 0
	last_note = ""
	if not active():
		return
	if day > 1:
		energy = minf(100.0, energy + float(REST) + Build.fx("rest"))
	if day <= 1:
		return
	if Expo.is_trip_day(day):
		return
	World.time_scale = 0.0
	if on_call(day - 1) and randf() < PAGE_CHANCE:
		_page_card()
	else:
		commute_card()


# a random line that is not the one used last time
func _fresh(list: Array, last: String) -> String:
	if list.size() < 2:
		return str(list[0]) if not list.is_empty() else ""
	var pick: String = str(list[randi() % list.size()])
	while pick == last:
		pick = str(list[randi() % list.size()])
	return pick


func _page_card() -> void:
	var client := Sales.pick_client()
	var what: String = _fresh(PAGES, _last_page)
	_last_page = what
	pages += 1
	var text := (
		"2:10 AM. THE PAGER GOES OFF. %s: %s."
		% [str(Msp.CLIENTS[client].name).to_upper(), what.to_upper()]
	)
	Cards.ask(
		"PAGER",
		text,
		[
			{"label": "GET UP AND FIX IT REMOTELY", "id": "fix"},
			{"label": "CHECK THE ALERT, THEN DECIDE", "id": "triage"},
			{"label": "IGNORE IT, GO BACK TO SLEEP", "id": "ignore"},
		],
		func(id: String) -> void: _page_result(id, client, what)
	)


func _page_result(id: String, client: int, what: String) -> void:
	var cname: String = Msp.CLIENTS[client].name
	match id:
		"fix":
			add_energy(-6.0 if Skills.ps_level >= 3 else -10.0)
			if randf() < 0.9 + 0.02 * float(Skills.ps_level):
				pages_fixed += 1
				Sales.adjust(client, 4)
				Msp.score += 3
				last_note = "FIXED THE PAGE AT 2 AM."
				Msp.send_text(
					"Boss", "%s noticed you caught their problem at 2 AM. Good catch." % cname
				)
			else:
				add_energy(-3.0)
				Sales.adjust(client, -2)
				last_note = "A HALF-ASLEEP TYPO MADE IT WORSE."
				Msp.send_text("Boss", "%s says last night's fix made things worse." % cname)
		"triage":
			var noise := clampf(0.4 + 0.08 * float(Skills.level("networking")), 0.4, 0.75)
			if randf() < noise:
				add_energy(-2.0)
				last_note = "FALSE ALARM."
			else:
				add_energy(-8.0)
				pages_fixed += 1
				Sales.adjust(client, 2)
				last_note = "REAL, AND YOU FIXED IT."
		_:
			pages_ignored += 1
			if randf() < 0.55:
				Sales.adjust(client, -6)
				Campaign.adjust_rep(-2)
				last_note = "THE PAGE WAS REAL. THEY CALLED THE BOSS."
				Msp.send_text(
					"Boss",
					(
						"The pager went off and nobody answered. %s called me at 7 AM. %s."
						% [cname, what.capitalize()]
					)
				)
			else:
				last_note = "IT RESOLVED ITSELF."
	commute_card()


func commute_card() -> void:
	var extra := traffic_text(Campaign.day)
	var text := (
		"DAY %d, 6:45 AM. THE ALARM IS GOING OFF. %s WHEN DO YOU LEAVE?" % [Campaign.day, extra]
	)
	if last_note != "":
		text = last_note + " " + text
	Cards.ask(
		"MORNING",
		text,
		[
			{"label": "LEAVE AT 7:30. EARLY AND TIRED", "id": "early"},
			{"label": "LEAVE AT 8:00. A GAMBLE", "id": "ontime"},
			{"label": "SLEEP IN. LEAVE AT 8:30 (LATE, TICKETS WAIT)", "id": "late"},
		],
		func(id: String) -> void: commute(id)
	)


func commute(choice: String) -> void:
	var c: Dictionary = COMMUTES[choice]
	var extra: float = float(WEEK_TRAFFIC.get(week_of(Campaign.day), {}).get("extra", 0.0))
	var traffic := randf() < float(c.p) + extra
	var delay := int(c.base)
	var reason := ""
	if traffic:
		delay += randi_range(15, 60)
		reason = _fresh(REASONS, _last_reason)
		_last_reason = reason
		add_energy(-3.0)
	late_min = maxi(0, delay)
	add_energy(float(c.energy))
	if late_min >= 10:
		late_total += 1
	var waiting := _arrive(reason)
	World.time_scale = 1.0
	Hints.toast(_arrival_text(delay, waiting), 6.0)
	changed.emit()


# the line shown right after the commute card: how it went
func _arrival_text(delay: int, waiting: int) -> String:
	if late_min >= 10:
		return (
			"YOU ARRIVE %d MIN LATE. %d TICKET%s WAITING."
			% [late_min, waiting, "" if waiting == 1 else "S"]
		)
	if delay < 0:
		return "YOU ARRIVE %d MIN EARLY. COFFEE FIRST." % -delay
	return "YOU ARRIVE ON TIME."


# returns how many tickets were already waiting when you got in
func _arrive(reason: String) -> int:
	var waiting := 0
	if late_min >= 10:
		var sorry := "You arrive %d minutes late" % late_min
		Msp.send_text(
			"Commute", sorry + (": " + reason.capitalize() + "." if reason != "" else ".")
		)
		for i in clampi(late_min / 15, 1, 3):
			var t: Dictionary = Msp._random_ticket("email")
			if not t.is_empty():
				waiting += 1
				t.sla_left = maxf(
					float(t.sla_total) * 0.5, float(t.sla_left) - float(late_min) * 1.25
				)
		for i in late_min / 12:
			Sales.adjust(Sales.pick_client(), -2)
		if late_min >= 20:
			var pool: Array = ["Alan", "Garrison", "Dan"].filter(func(n: String) -> bool: return Social.people().has(n))
			if not pool.is_empty():
				var who: String = pool[randi() % pool.size()]
				Social.change(who, -1)
				Lync._push(who, who, "Phones were backing up and I picked up. I would rather not. Please be on time.")
		if late_min >= 30:
			Msp.send_text("Boss", "Where are you? Clients are asking for you.")
	elif reason != "":
		Msp.send_text("Commute", "Traffic: %s. You left early enough. Phew." % reason.capitalize())
	return waiting


# ---- the day ---------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not active() or World.time_scale <= 0.0 or Cards.is_open:
		return
	var dt := delta * World.time_scale
	energy = maxf(0.0, energy - DAY_DRAIN * Difficulty.cf("tech.drain") * float(Mutators.hook("energy_drain", 1.0)) * (1.0 + Build.fx("drain")) * dt / maxf(60.0, World.day_len))
	if _warned < 1 and energy < 55.0:
		_warned = 1
		Msp.send_text("You", "You are getting tired. Fixes will start taking longer.")
	if _warned < 2 and energy < 35.0:
		_warned = 2
		Msp.send_text("You", "You are running on fumes. A mistake would be easy right now.")
	if _warned < 3 and energy < 20.0:
		_warned = 3
		Msp.send_text("Boss", "You look rough. Go home when you can.")


# the real time of day for card titles, 12 hour style
func clock_label() -> String:
	var h := int(World.clock)
	var m := int((World.clock - float(h)) * 60.0)
	return "%d:%02d %s" % [(h + 11) % 12 + 1, m, "PM" if h % 24 >= 12 else "AM"]


# Campaign asks this before ending the day. With tickets still open at closing it offers to stay late.
func can_end_day() -> bool:
	if not active():
		return true
	if Cards.is_open:
		return false
	if not _asked and Story.ot_hours > 0.0 and World.clock >= World.DAY_END + 0.25:
		_asked = true  # an overtime job already took the evening: staying later is not on offer
	if not _asked:
		_asked = true
		var open := Msp.open_tickets().size()
		if open > 0:
			Cards.ask(
				clock_label(),
				(
					"%d TICKET(S) ARE STILL OPEN AND THE OFFICE IS EMPTYING OUT. STAY AND FINISH THEM?"
					% open
				),
				[
					{"label": "GO HOME", "id": "home"},
					{"label": "STAY 1 HOUR (+$%d, -%d ENERGY)" % [STAY_PAY, STAY_COST], "id": "1"},
					{
						"label": "STAY 2 HOURS (+$%d, -%d ENERGY)" % [STAY_PAY * 2, STAY_COST * 2],
						"id": "2"
					},
				],
				func(id: String) -> void: stay(id)
			)
			return false
	return World.clock >= _stay_until


# an outing took the evening: no offer to stay late
func skip_stay() -> void:
	_asked = true


func stay(id: String) -> void:
	if id == "home":
		return
	var hours := float(int(id))
	stay_hours = hours
	stays += 1
	_stay_until = World.DAY_END + hours
	add_energy(-float(STAY_COST) * hours)


# ---- the report -------------------------------------------------------------------------------
func pay_extra() -> int:
	return (int(stay_hours * float(STAY_PAY)) + _oncall_pay) if active() else 0


func oncall_pay() -> int:
	return _oncall_pay if active() else 0


func rep_delta() -> int:
	return -1 if active() and late_min >= 30 else 0


# called as the day is closed: exhaustion makes you short with your coworkers
func close_day() -> void:
	if active() and energy < 25.0:
		Social.change_all(-1)


func summary() -> String:
	return (
		"LATE %d   PAGES %d (FIXED %d)   LATE NIGHTS %d" % [late_total, pages, pages_fixed, stays]
	)


func to_dict() -> Dictionary:
	return {
		"energy": energy,
		"late": late_total,
		"stays": stays,
		"pages": pages,
		"fixed": pages_fixed,
		"ignored": pages_ignored,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	energy = float(data.get("energy", START_ENERGY))
	late_total = int(data.get("late", 0))
	stays = int(data.get("stays", 0))
	pages = int(data.get("pages", 0))
	pages_fixed = int(data.get("fixed", 0))
	pages_ignored = int(data.get("ignored", 0))
