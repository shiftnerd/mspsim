extends SceneTree
# gdlint:disable=max-line-length
# The quit risks of the cozy design review (roadmap R16), each measured by a scripted headless run on the Easy tier
# (the MEASURE lines are the numbers in docs/dev/notes-cozy.md) and checked against the eased values:
#  1. the idle start of day 1: how long until the first mail, card, hint and ticket
#  2. a C (or D) grade reading as failure on Easy: the grade floor and the words that go with it
#  3. the day 2 commute: no lateness, no waiting tickets, no energy lost, whatever you pick
#  4. week 2 piling on-call: pager cards in the on-call week
# Normal is measured next to it and must not change.

var failures := 0
var d: Node
var c: Node
var msp: Node
var shift: Node
var cards: Node
var world: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fresh(tier: String, run_seed := 5) -> void:
	d.set_tier(tier)
	d.seed_run(run_seed)
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Game").ui_open = false
	root.get_node("Build").pending = {}
	shift.enabled = true
	world.time_scale = 1.0
	c.new_game("tech")
	root.get_node("Career").toasts = false


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


# seconds of day 1 until the first mail, card, hint line and ticket (time_scale 1, 60 frames a second)
func _first_minutes(tier: String) -> Dictionary:
	_fresh(tier)
	var hints := root.get_node("Hints")
	var out := {"mail": -1.0, "card": -1.0, "hint": -1.0, "ticket": -1.0}
	var t := 0.0
	for i in 60 * 100:
		if float(out.mail) < 0.0 and msp.emails.size() > 0:
			out["mail"] = t
		if float(out.hint) < 0.0 and (str(hints.text) != "" or str(hints.toast_text) != ""):
			out["hint"] = t
		if cards.is_open:
			if float(out.card) < 0.0:
				out["card"] = t
			_drain()
		if msp.tickets.size() > 0:
			out["ticket"] = t
			break
		await process_frame
		t += 1.0 / 60.0
	return out


func _commute(tier: String, choice: String) -> Dictionary:
	_fresh(tier)
	_drain()
	c.day = 2
	shift.energy = 60.0
	var open0: int = msp.tickets.size()
	var rep0: int = c.rep
	shift.late_min = 0
	shift.commute(choice)
	return {"late": shift.late_min, "waiting": msp.tickets.size() - open0, "energy": int(shift.energy) - 60, "rep": shift.rep_delta() + c.rep - rep0}


# the mornings after the five on-call days of week 2 (days 7 to 11): how many pager cards
func _pages(tier: String, run_seed: int) -> int:
	_fresh(tier, run_seed)
	_drain()
	var before: int = shift.pages
	for day in range(7, 12):
		c.day = day
		shift.begin_day(day)
		_drain()
	world.time_scale = 1.0
	return shift.pages - before


func _init() -> void:
	await process_frame
	d = root.get_node("Difficulty")
	c = root.get_node("Campaign")
	msp = root.get_node("Msp")
	shift = root.get_node("Shift")
	cards = root.get_node("Cards")
	world = root.get_node("World")
	var report := root.get_node("DayReport")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- 1. the idle start
	var easy1: Dictionary = await _first_minutes("easy")
	var norm1: Dictionary = await _first_minutes("normal")
	print("MEASURE day1 easy   first mail %.1f s, card %.1f s, hint %.1f s, ticket %.1f s" % [easy1.mail, easy1.card, easy1.hint, easy1.ticket])
	print("MEASURE day1 normal first mail %.1f s, card %.1f s, hint %.1f s, ticket %.1f s" % [norm1.mail, norm1.card, norm1.hint, norm1.ticket])
	_check(float(easy1.ticket) > 0.0 and float(easy1.ticket) <= 45.0, "easy: the first ticket of day 1 arrives within 45 s (20 s, plus the call when it comes by phone) (%.1f)" % easy1.ticket)
	_check(float(easy1.mail) >= 0.0 and float(easy1.mail) <= 10.0 and float(easy1.card) <= 20.0, "easy: a mail inside 10 s and a card inside 20 s")
	_check(float(norm1.ticket) > 74.0 and float(norm1.ticket) < 100.0, "normal: the first ticket still takes its 75 s (plus the call) (%.1f)" % norm1.ticket)
	_fresh("easy")
	var goals: Script = load("res://scripts/goals.gd")
	_check(str(goals.goal()) != "", "easy: the goal chip has a line from the first second (%s)" % str(goals.goal()))

	# ---- 2. the grade
	var grades := {}
	for tier in ["easy", "normal"]:
		for case in ["nothing", "bad"]:
			_fresh(tier)
			_drain()
			if case == "bad":
				msp.score -= 6
			c._end_day()
			var r: Dictionary = report.report
			grades[tier + "/" + case] = str(r.grade)
			print("MEASURE grade %s, a day with %s: %s  notes %s" % [tier, "nothing closed" if case == "nothing" else "a score of -6", str(r.grade), str(r.get("notes", []))])
			if tier == "easy":
				var notes: Array = r.get("notes", [])
				_check(str(r.grade) == "C", "easy (%s): the grade floor is C (%s)" % [case, str(r.grade)])
				_check(notes.has(d.ct("grade_c")) and d.ct("grade_c") != "", "easy (%s): the C comes with a calm line" % case)
				_check(int(c.history[c.history.size() - 1].points) <= 0 and str(c.history[c.history.size() - 1].grade) == "C", "easy (%s): the history keeps the floored grade" % case)
			report.is_open = false
			_drain()
	_check(grades["normal/nothing"] == "C" and grades["normal/bad"] == "D", "normal: C and D as before")
	_fresh("easy")
	_drain()
	for k in 3:
		var t: Dictionary = msp.create_ticket(k, 0, "test")
		msp.rmm_action(t.endpoint, "spooler")
		msp.close_ticket(t.id)
	msp.score = int(c._base.score) + 12
	c._end_day()
	_check(str(report.report.grade) == "B" and not (report.report.get("notes", []) as Array).has(d.ct("grade_c")), "easy: a B day has no C line")
	report.is_open = false
	_drain()

	# ---- 3. the day 2 commute
	for tier in ["easy", "normal"]:
		for choice in ["early", "ontime", "late"]:
			var m := _commute(tier, choice)
			print("MEASURE commute %s %s: late %d min, %d tickets waiting, energy %+d, reputation %+d" % [tier, choice, m.late, m.waiting, m.energy, m.rep])
			if tier == "easy":
				_check(int(m.late) == 0 and int(m.waiting) == 0 and int(m.rep) >= 0 and int(m.energy) >= 0, "easy: leaving %s costs nothing" % choice)
	var late_n := _commute("normal", "late")
	_check(int(late_n.late) >= 20 and int(late_n.waiting) >= 1, "normal: sleeping in is still late with tickets waiting")
	var early_n := _commute("normal", "early")
	_check(int(early_n.energy) < 0, "normal: leaving early still costs energy")

	# ---- 4. on-call in week 2
	var sum := {"easy": 0, "normal": 0}
	var worst := {"easy": 0, "normal": 0}
	var seeds := 12
	for tier in ["easy", "normal"]:
		for s in seeds:
			var n := _pages(tier, 100 + s)
			sum[tier] += n
			worst[tier] = maxi(int(worst[tier]), n)
		print("MEASURE on-call week 2 %s: %.2f pager cards a week on average, worst week %d (%d seeds)" % [tier, float(sum[tier]) / float(seeds), int(worst[tier]), seeds])
	_check(int(worst.easy) <= 1, "easy: at most one page in the on-call week (worst %d)" % int(worst.easy))
	_check(float(sum.normal) / float(seeds) >= 2.0, "normal: the pager is as busy as before (%.2f a week)" % (float(sum.normal) / float(seeds)))

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
