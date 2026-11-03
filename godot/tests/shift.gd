extends SceneTree
# Hour management: the morning commute, being late, the on-call pager, staying late, and energy
# slowing your fixes. Headless.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var shift := root.get_node("Shift")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var sk := root.get_node("Skills")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	shift.enabled = true
	c.new_game("tech")

	_check(
		shift.energy == 80.0 and not cards.is_open and world.time_scale > 0.0,
		"day 1: no morning card, energy 80"
	)

	# ---- energy changes how you work
	shift.energy = 95.0
	_check(
		is_equal_approx(shift.slow_mult(), 0.9) and shift.fail_add() < 0.0,
		"rested: fixes are a little faster and safer"
	)
	shift.energy = 60.0
	_check(shift.slow_mult() == 1.0 and shift.fail_add() == 0.0, "fine: no effect")
	shift.energy = 15.0
	_check(
		shift.slow_mult() > 1.3 and shift.fail_add() > 0.1 and shift.is_tired(),
		"exhausted: slower, more mistakes"
	)
	sk.ps_level = 5
	_check(sk.fail_chance() > 0.1, "even a PowerShell expert slips when exhausted")
	shift.energy = 60.0
	_check(sk.fail_chance() == 0.0, "a rested expert does not")
	sk.ps_level = 0
	shift.enabled = false
	shift.energy = 10.0
	_check(sk.fix_secs() == 6.0, "the system is off outside real play (tests, free play)")
	shift.enabled = true

	# ---- the commute card
	c.day = 2
	shift.energy = 70.0
	world.time_scale = 0.0
	shift.commute_card()
	_check(
		cards.is_open and cards.options.size() == 3 and world.time_scale == 0.0,
		"morning card with three departure times; the clock waits"
	)
	cards.pick(2)
	_check(
		world.time_scale == 1.0 and shift.late_min >= 20, "sleeping in always means arriving late"
	)
	_check(shift.energy >= 70.0 + 5.0 - 3.0, "sleeping in gives energy back")

	var late_count := {"early": 0, "ontime": 0, "late": 0}
	for choice in late_count:
		for i in 300:
			shift.late_min = 0
			shift.energy = 70.0
			shift.commute(choice)
			late_count[choice] += 1 if shift.late_min >= 10 else 0
	_check(
		late_count.early < late_count.ontime and late_count.ontime < late_count.late,
		"later departures are late more often (%s)" % str(late_count)
	)
	_check(late_count.late == 300, "leaving at 8:30 is always late")
	_check(late_count.early < 60, "leaving early is rarely late (%d of 300)" % late_count.early)

	# ---- what being late does
	msp.reset()
	var texts_before: int = msp.texts.size()
	var mood_before: int = sales.mood(0)
	sales.satisfaction = {}
	for i in msp.CLIENTS.size():
		sales.satisfaction[i] = 70
	var tickets_before: int = msp.tickets.size()
	msp.spawned_today = 0
	shift.late_min = 45
	shift._arrive("AN ACCIDENT")
	_check(msp.tickets.size() >= tickets_before + 2, "late: tickets were already waiting")
	var aged := 0
	for t in msp.tickets:
		aged += 1 if float(t.sla_left) < float(t.sla_total) - 30.0 else 0
	_check(aged >= 2, "late: their SLA clocks were already running (%d aged)" % aged)
	_check(sales.average() < 70.0, "late: calls were missed and clients noticed")
	_check(msp.texts.size() > texts_before, "late: the boss texts you")
	_check(shift.rep_delta() == -1, "30 minutes late costs reputation at the end of the day")
	shift.late_min = 5
	_check(shift.rep_delta() == 0, "5 minutes late does not")
	_check(mood_before >= 0, "(sanity)")

	# ---- on call
	_check(shift.on_call(6) and shift.on_call(10) and not shift.on_call(5), "days 6-10 are on call")
	_check(shift.on_call(16) and not shift.on_call(11), "days 16-20 are on call")
	c.day = 7
	_check(shift.is_on_call(), "day 7: on call")
	shift.energy = 70.0
	shift._page_card()
	_check(cards.is_open and cards.speaker == "PAGER", "a page wakes you")
	var e0: float = shift.energy
	cards.pick(0)
	_check(shift.energy < e0, "getting up costs energy")
	_check(cards.is_open and cards.speaker == "MORNING", "then comes the commute")
	cards.pick(0)
	_check(not cards.is_open and shift.pages == 1, "page counted")

	var rep_hits := 0
	var fixed := 0
	for i in 200:
		c.rep = 50
		shift.pages_fixed = 0
		shift._page_result("ignore", 0, "the mail queue is stuck")
		if cards.is_open:
			cards.pick(2)
		rep_hits += 1 if c.rep < 50 else 0
		shift._page_result("fix", 0, "the mail queue is stuck")
		if cards.is_open:
			cards.pick(2)
		fixed += shift.pages_fixed
	_check(
		rep_hits > 70 and rep_hits < 150,
		"ignoring a real page costs reputation (%d of 200)" % rep_hits
	)
	_check(fixed > 160, "getting up usually fixes it (%d of 200)" % fixed)

	# ---- staying late
	c.day = 3
	msp.reset()
	shift.begin_day(3)
	if cards.is_open:
		cards.pick(0)
	shift.energy = 70.0
	shift._asked = false
	world.time_scale = 1.0
	msp.create_ticket(0, 0, "test")
	world.clock = 17.0
	_check(
		not shift.can_end_day() and cards.is_open, "closing time with an open ticket: stay or go?"
	)
	cards.pick(2)
	_check(
		shift.stay_hours == 2.0 and is_equal_approx(shift.energy, 54.0) and shift.stays == 1,
		"staying two hours costs 16 energy"
	)
	_check(not shift.can_end_day(), "the day stays open while you work")
	world.clock = 19.1
	_check(shift.can_end_day(), "...and ends after the extra hours")
	_check(shift.pay_extra() == 100, "overtime pays $50 an hour")
	var report: Dictionary = c.make_report()
	_check(
		float(report.overtime) == 2.0 and int(report.energy) == 54,
		"the day report shows the overtime and energy"
	)

	shift._asked = false
	shift._stay_until = 0.0
	for t in msp.tickets:
		t.status = "Closed"
	_check(shift.can_end_day(), "nothing open: the day just ends")
	shift._asked = false
	shift.stay_hours = 0.0
	msp.create_ticket(0, 0, "test")
	shift.can_end_day()
	cards.pick(0)
	_check(shift.can_end_day() and shift.stay_hours == 0.0, "go home: the day ends, tickets wait")

	# ---- on-call pay and the drain
	c.day = 8
	shift.begin_day(8)
	while cards.is_open:
		cards.pick(0)
	_check(shift.oncall_pay() == 40 and shift.pay_extra() == 40, "an on-call day pays $40")
	world.time_scale = 1.0
	shift.energy = 80.0
	shift._process(60.0)
	_check(is_equal_approx(shift.energy, 78.0), "a tenth of the day costs 2 energy")
	shift.energy = 30.0
	shift._warned = 0
	var texts0: int = msp.texts.size()
	shift._process(60.0)
	shift.energy = 34.0
	shift._process(60.0)
	_check(msp.texts.size() > texts0, "you get a text when you run on fumes")

	# ---- saving
	shift.energy = 63.0
	shift.late_total = 3
	shift.pages = 4
	var data: Dictionary = shift.to_dict()
	shift.reset()
	shift.from_dict(data)
	_check(
		shift.energy == 63.0 and shift.late_total == 3 and shift.pages == 4,
		"energy and the hour stats are saved"
	)
	_check(shift.summary().contains("LATE 3"), "summary line: " + shift.summary())
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
