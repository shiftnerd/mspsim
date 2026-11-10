extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# The owners as last-resort help (tech campaign only; roadmap X6). Alan and Garrison are busy owners: they do not
# work tickets day to day. When the day goes badly wrong, one of them who is in the building and free steps in:
#   phones    two or more desk phones ringing unanswered: the owner walks to one, puts on a headset and takes the call
#             (the call is handled, a client is a little happier)
#   sla       a P1 / P2 about to breach: +45 seconds on its clock
#   backlog   six or more open tickets: the soonest one to breach gets +45 seconds
#   complaint John's complaint has waited too long (Sales.pending): Garrison calms the client (mood +4)
# Stepping in is FREE: no reputation, no opinion loss, no grade effect. It only shows a toast in the owner's own voice
# and a row in the day report (OWNERS STEPPED IN). Limits: not on days 1-2, a per-day limit for each owner, a cooldown
# in game minutes, and the Difficulty tier (easy a bit more help, hard none). Random choices come from the `owners`
# stream, so the same seed repeats. Free Play and the owner campaign never use it.
# ASK THE OWNER (Talk and Lynk) is the lifeline version: you ask, a friendly owner helps once a day (`ask`).

signal stepped_in(who: String, reason: String)

const OWNERS := ["Alan", "Garrison"]
# legs an owner can be pulled out of (not lunch, a meeting, an errand outside, a trip, following you)
const FREE_KINDS := ["work", "coffee", "cooler", "bathroom", "floor", "closet"]
# [easy, normal, hard]
const PER_DAY := [3, 2, 0]  # uses a day for each owner
const COOL_MIN := [3.0, 4.0, 4.0]  # game minutes between two uses (either owner)
const BACKLOG := [5, 6, 99]  # open client tickets that count as a backlog
const FIRST_DAY := 3  # gentle first days
const SLA_BONUS := 45.0
const SLA_WARN := 30.0  # a P1 / P2 under this many seconds counts as about to breach
const COMPLAINT_WAIT := 40.0  # game seconds a complaint may wait for you before Garrison takes it
const CHECK_GAP := 2.0
# onsite visits (X6): `onsite` = you come back from a client site and a ticket is close to breaching (the drive aged it to under
# ONSITE_RISK of its clock): an owner who was in the building watched the queue, +ONSITE_BONUS seconds on the worst one.
# `visit` = a fix failed at the site: an owner rings the client (mood +VISIT_MOOD) and the job's own clock gets ONSITE_BONUS.
# Same limits as the rest (day 3 on, uses a day, the cooldown, the tier), still free: no reputation, no opinion.
const ONSITE_RISK := 0.45
const ONSITE_BONUS := 60.0
const VISIT_MOOD := 3
const VISIT_LINES := {
	"onsite": {"Alan": "I kept an eye on your queue while you were out.", "Garrison": "I told them you were on the road. They can wait a bit."},
	"visit": {"Alan": "I talked them down. Try the other fix.", "Garrison": "I called them. Take your time and get it right."},
}
const LINES := {
	"Alan": ["I will take this one.", "Give me that phone. Keep working.", "I have got it. Back to your queue."],
	"Garrison": ["Hi, this is Garrison, how can I help?", "Garrison here, let me see what I can do.", "I will handle this one, you carry on."],
}
const ASK_LINES := {
	"cold": {
		"Alan": "I like you fine, but I have payroll to run. Ask me again once we have worked together a bit more.",
		"Garrison": "Love the energy, but I am slammed. Let's get to know each other first, yeah?",
	},
	"used": {
		"Alan": "I already did what I could for you today. Tomorrow.",
		"Garrison": "I already made your call today. Ask me tomorrow, okay?",
	},
	"approve": "Fine. Take the longer fix if you need to, buy the part, I will sign for it. Your next heavy fix will not cost you with the client.",
	"tip": "Nothing is on fire, so here is a tip: label both ends of every cable and keep a spare power brick. It saves a Saturday.",
	"call": "Give me the number. I will call %s myself and smooth it over.",
	"nobody": "Nothing in your queue needs a call from me right now. Keep it that way.",
}

var used := {"Alan": 0, "Garrison": 0}  # last-resort uses today
var stepped := 0  # today's total (the day report row)
var log: Array = []  # [{who, reason, clock}] today
var last_clock := -99.0
var approved_heavy := false  # Alan signed off on the next heavy alternative fix (no client mood hit)
var fake_rings := 0  # tests: phones that count as ringing
var _asked := {}  # owner -> day of the last ASK THE OWNER
var _t := 0.0
var _pending_age := 0.0


func _ready() -> void:
	Campaign.day_started.connect(func(_d: int) -> void: begin_day())


func begin_day() -> void:
	used = {"Alan": 0, "Garrison": 0}
	stepped = 0
	log = []
	last_clock = -99.0
	approved_heavy = false
	fake_rings = 0
	_t = 0.0
	_pending_age = 0.0


# the tech campaign only (Free Play and the owner campaign never call the owners in)
func active() -> bool:
	return Campaign.active and Campaign.mode == "tech" and Msp.enabled and not Game.title_mode


func per_day() -> int:
	return int(PER_DAY[Difficulty.tier_index()])


func cooldown_hours() -> float:
	return float(COOL_MIN[Difficulty.tier_index()]) / 60.0


func backlog_size() -> int:
	return int(BACKLOG[Difficulty.tier_index()])


# is the ASK THE OWNER lifeline in play for this person?
func asks_owner(who: String) -> bool:
	return Campaign.active and Campaign.mode == "tech" and OWNERS.has(who)


func _process(delta: float) -> void:
	if not active() or Onsite.busy:
		return
	var dt := delta * World.time_scale
	if dt <= 0.0:
		return
	_pending_age = _pending_age + dt if not Sales.pending.is_empty() else 0.0
	_t += dt
	if _t < CHECK_GAP:
		return
	_t = 0.0
	var d := check()
	if not d.is_empty():
		step_in(str(d.who), str(d.reason), d)


# ---- the rule -----------------------------------------------------------------------------------------------
func allowed_now() -> bool:
	if not active() or Campaign.day < FIRST_DAY or per_day() <= 0:
		return false
	if World.clock >= World.DAY_END - 0.25:
		return false
	return World.clock - last_clock >= cooldown_hours() or last_clock < 0.0


# {who, reason, ...} or {} when nobody steps in right now
func check() -> Dictionary:
	if not allowed_now():
		return {}
	var trig := trigger()
	if trig.is_empty():
		return {}
	var who := pick_owner(str(trig.reason))
	if who == "":
		return {}
	trig["who"] = who
	return trig


func trigger() -> Dictionary:
	if not Sales.pending.is_empty() and _pending_age >= COMPLAINT_WAIT:
		var ct := Msp.ticket(int(Sales.pending.get("ticket", 0)))
		if not ct.is_empty() and str(ct.status) != "Closed":
			return {"reason": "complaint", "client": int(Sales.pending.get("client", 0)), "ticket": int(ct.id)}
	var open := 0
	var soonest := {}
	for t in Msp.open_tickets():
		if t.internal or str(t.status) == "Waiting":
			continue
		open += 1
		if t.fix_done or t.breached or bool(t.get("owner_helped", false)):
			continue
		if int(t.pri) <= 2 and float(t.sla_left) < SLA_WARN:
			return {"reason": "sla", "ticket": int(t.id)}
		if soonest.is_empty() or float(t.sla_left) < float(soonest.sla_left):
			soonest = t
	var zones := ringing_phones()
	if zones.size() + fake_rings >= 2:
		return {"reason": "phones", "zone": zones[0] if not zones.is_empty() else null}
	if open >= backlog_size() and not soonest.is_empty():
		return {"reason": "backlog", "ticket": int(soonest.id)}
	return {}


func ringing_phones() -> Array:
	var out := []
	var tree := get_tree()
	if tree == null:
		return out
	for zone in tree.get_nodes_in_group("phones"):
		var fx: Node = zone.get_node_or_null(zone.target)
		if fx != null and bool(fx.get("ringing")) and not bool(fx.get("busy")):
			out.append(zone)
	return out


# ---- onsite visits (X6) ---------------------------------------------------------------------------------------
# the same limits as allowed_now, but it also holds while you are at a site (the service desk is switched off there)
func visit_allowed() -> bool:
	if not Campaign.active or Campaign.mode != "tech" or Game.title_mode or Campaign.day < FIRST_DAY or per_day() <= 0:
		return false
	return World.clock - last_clock >= cooldown_hours() or last_clock < 0.0


# Onsite._go_home: back at the office. {who, ticket} when an owner covered the queue, else {}
func visit_cover() -> Dictionary:
	if not visit_allowed():
		return {}
	var worst := {}
	for t in Msp.open_tickets():  # sorted: the most urgent first
		if t.internal or t.fix_done or t.breached or str(t.status) == "Waiting" or bool(t.get("owner_helped", false)):
			continue
		if float(t.sla_left) <= float(t.sla_total) * ONSITE_RISK:
			worst = t
			break
	if worst.is_empty():
		return {}
	var who := pick_owner("onsite")
	if who == "":
		return {}
	step_in(who, "onsite", {"ticket": int(worst.id)})
	return {"who": who, "ticket": int(worst.id)}


# Onsite._after: the fix you tried at the site did not work. The owner who rang the client, or "" when nobody could
func visit_rescue(client: int, ticket_id: int) -> String:
	if not visit_allowed():
		return ""
	var who := pick_owner("visit")
	if who == "":
		return ""
	step_in(who, "visit", {"client": client, "ticket": ticket_id})
	return who


# who answers: Garrison takes the clients, Alan the technical trouble, either takes the phones
func pick_owner(reason: String) -> String:
	var prefs := ["Alan", "Garrison"]
	if reason == "complaint" or reason == "visit":
		prefs = ["Garrison", "Alan"]
	elif reason == "phones" and Difficulty.rng("owners").randf() < 0.5:
		prefs = ["Garrison", "Alan"]
	for who in prefs:
		if int(used[who]) < per_day() and is_free(who):
			return who
	return ""


# in the building and not busy: not out, at lunch, in a meeting, on a trip, following you or talking to you
func is_free(who: String) -> bool:
	if not Social.people().has(who):
		return false
	if not World.chars.has(who):
		return true  # no world running (tests): in the building
	var st: Dictionary = World.chars[who]
	if str(st.get("scene", "")) == World.OUTSIDE or bool(st.get("following", false)):
		return false
	var legs: Array = st.get("legs", [])
	var kind := str(legs[0].get("kind", "work")) if not legs.is_empty() else "work"
	return FREE_KINDS.has(kind) and Talk._who != who


# ---- the effect ---------------------------------------------------------------------------------------------
func step_in(who: String, reason: String, info := {}) -> void:
	match reason:
		"complaint":
			var client := int(info.get("client", Sales.pending.get("client", 0)))
			Sales.adjust(client, 4)
			_help_ticket(int(info.get("ticket", 0)), who, 30.0, "%s called the client back." % who)
			Sales.pending = {}
		"phones":
			_answer_phone(who, info)
		"onsite":
			_help_ticket(int(info.get("ticket", 0)), who, ONSITE_BONUS, "%s watched the queue while you were onsite: +60 s on the clock." % who)
		"visit":
			Sales.adjust(int(info.get("client", 0)), VISIT_MOOD)
			_help_ticket(int(info.get("ticket", 0)), who, ONSITE_BONUS, "%s rang the client while the visit was going badly." % who)
		_:
			_help_ticket(int(info.get("ticket", 0)), who, SLA_BONUS, "%s stepped in: +45 s on the clock." % who)
	used[who] = int(used[who]) + 1
	stepped += 1
	Career.add("owner_help")
	last_clock = World.clock
	log.append({"who": who, "reason": reason, "clock": World.clock})
	if reason in ["sla", "backlog", "complaint"]:
		# X6: the owner walks to the front desk and takes it there; with no route to it, a headset call at their own desk
		if not World.send_owner_front(who):
			var node: Node = World.chars[who].get("node") if World.chars.has(who) else null
			if node != null and is_instance_valid(node) and node.has_method("desk_call"):
				node.desk_call()
	var line := _line(who, reason)
	Hints.toast("%s: %s" % [who.to_upper(), line.to_upper()], 3.2)
	Msp.changed.emit()
	stepped_in.emit(who, reason)


func _line(who: String, reason: String) -> String:
	if VISIT_LINES.has(reason):
		return str(VISIT_LINES[reason][who])
	var lines: Array = LINES[who]
	if reason == "phones" or reason == "complaint":
		return str(lines[0])
	return str(lines[Difficulty.rng("owners").randi_range(0, lines.size() - 1)])


func _help_ticket(id: int, who: String, secs: float, note: String) -> void:
	var t := Msp.ticket(id)
	if t.is_empty():
		return
	t.sla_left = float(t.sla_left) + secs
	t["owner_helped"] = true
	t.notes.append(note)
	if who == "":
		return


func _answer_phone(who: String, info: Dictionary) -> void:
	if not Sales.active.is_empty():
		var rng := Difficulty.rng("owners")
		Sales.adjust(int(Sales.active[rng.randi_range(0, Sales.active.size() - 1)]), 2)
	var zone: Node = info.get("zone", null)
	if zone == null or not is_instance_valid(zone):
		return
	var fx: Node = zone.get_node_or_null(zone.target)
	if fx == null:
		return
	if World.send_owner_cover(who, zone.global_position.x - 10.0):
		fx._ring_until = fx._time + 20.0  # keep ringing until the owner gets there
	else:
		fx.play()  # nobody to walk: the call is simply picked up


# ---- ASK THE OWNER ------------------------------------------------------------------------------------------
# Lync "need a hand" and Talk "ask the owner" land here. Needs a friendly owner, once a day each. Alan approves a
# heavier fix (the next heavy alternative fix costs no client mood) or, with nothing open, passes on a tip; Garrison
# calls the client of your oldest open ticket (mood +6, SLA +60 s). No reputation, no opinion cost.
func ask(who: String) -> String:
	if not Social.is_friendly(who):
		return str(ASK_LINES.cold[who])
	if int(_asked.get(who, -1)) == Campaign.day:
		return str(ASK_LINES.used[who])
	if who == "Alan":
		var work := false
		for t in Msp.open_tickets():
			work = work or (not t.internal and not t.fix_done)
		_asked[who] = Campaign.day
		if work:
			approved_heavy = true
			return str(ASK_LINES.approve)
		Skills.add_xp("servers", 6)
		return str(ASK_LINES.tip) + " (+6 SERVERS XP)"
	var oldest := {}
	for t in Msp.open_tickets():
		if t.internal or t.fix_done:
			continue
		if oldest.is_empty() or int(t.id) < int(oldest.id):
			oldest = t
	if oldest.is_empty():
		return str(ASK_LINES.nobody)  # not used up: ask again when there is something to call about
	_asked[who] = Campaign.day
	Sales.adjust(int(oldest.client), 6)
	oldest.sla_left = float(oldest.sla_left) + 60.0
	oldest.notes.append("Garrison called the client: +60 s.")
	Msp.changed.emit()
	return str(ASK_LINES.call) % str(Msp.CLIENTS[int(oldest.client)].name)


# Msp._alt_fix: a heavy fix (one that normally costs client mood) after Alan's approval is free, once
func take_approval() -> bool:
	if not approved_heavy:
		return false
	approved_heavy = false
	return true
