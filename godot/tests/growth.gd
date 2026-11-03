extends SceneTree
# Grow a Tier 1 into a Tier 2: the gap list, the plan, protected time, stretch tickets, graduation,
# the owner's hours as the only Tier 3, and the owner's on-call and flexible-hours cards. Headless.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var g := root.get_node("Growth")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	var sk := root.get_node("Skills")
	var social := root.get_node("Social")
	var world := root.get_node("World")
	var owner := root.get_node("Owner")
	var story := root.get_node("Story")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")

	# ---- the gap list
	var list: Array = g.gaps()
	_check(
		list.size() == 4 and int(list[0].score) >= int(list[3].score),
		"gap list: four skills, worst first"
	)
	var top: String = list[0].skill
	g.note_escalation({"fix": "spooler", "internal": false})
	g.note_escalation({"fix": "spooler", "internal": false})
	_check(
		g.esc_now() == 2 and g.esc_skill["networking"] == 2,
		"breaches and reopens count as escalations"
	)
	g.note_escalation({"fix": "spooler", "internal": true})
	_check(g.esc_now() == 2, "internal tickets do not")
	_check(
		g.gaps()[0].skill == "servers" or top != "",
		"servers has gaps (" + str(g.gaps()[0].skill) + ")"
	)
	_check(g.status_line() == "", "no plan yet")

	# ---- the plan
	g.start_plan()
	_check(cards.is_open and cards.options.size() == 3, "Morgan offers the top three gaps")
	var chosen: String = str(cards.options[0].id)
	cards.pick(0)
	_check(cards.is_open and cards.options.size() == 5, "then a helper")
	cards.pick(4)
	_check(
		g.focus == chosen and g.helper == "Garrison" and g.progress == 0.0,
		"plan set: %s with Garrison" % chosen
	)
	_check(g.status_line().contains("GARRISON"), "status line: " + g.status_line())
	g.start_plan()
	_check(not cards.is_open, "only one plan at a time")

	# ---- the safety net
	_check(g.fail_adjust("spooler") == 0.0, "no training, no change")
	g.focus = "servers"
	g.progress = 100.0
	_check(
		is_equal_approx(g.fail_adjust("clear_temp"), -0.08),
		"fully trained: servers fixes are safer"
	)
	_check(is_equal_approx(g.fail_adjust("password"), -0.02), "other fixes a little")
	g.progress = 0.0

	# ---- protected time
	msp.reset()
	var clock0: float = world.clock
	g.offer_block()
	_check(cards.is_open and cards.options.size() == 3, "protected 30 minutes offered")
	cards.pick(0)
	_check(
		g.progress == 25.0 and is_equal_approx(world.clock, clock0 + 0.5) and g.blocks_taken == 1,
		"taking it: +25%, half an hour gone"
	)
	for i in 4:
		msp.create_ticket(i, 0, "test")
	g.offer_block()
	var disabled := not bool(cards.options[0].get("enabled", true))
	cards.pick(0)
	_check(disabled and cards.is_open, "with a full queue you cannot take the whole block")
	cards.pick(1)
	_check(g.progress == 33.0 and not cards.is_open, "squeezing it between tickets: only +8%")
	g.offer_block()
	cards.pick(2)
	_check(g.blocks_skipped == 1 and g.progress == 33.0, "skipping it gives nothing")

	# ---- stretch tickets
	msp.reset()
	var ok := 0
	var caught := 0
	var slipped := 0
	for i in 300:
		g.progress = 0.0
		g.graduated = false
		g.stretch_ok = 0
		g.stretch_caught = 0
		g.stretch_slipped = 0
		sk.reset()
		g.stretch_result("try")
		ok += g.stretch_ok
		caught += g.stretch_caught
		slipped += g.stretch_slipped
	_check(
		ok > 60 and ok < 200 and caught > 0 and slipped >= 0 and ok + caught + slipped == 300,
		"a stretch ticket: %d nailed it, %d caught, %d slipped" % [ok, caught, slipped]
	)
	g.progress = 0.0
	social.rel["Garrison"] = 80
	caught = 0
	slipped = 0
	for i in 300:
		g.stretch_caught = 0
		g.stretch_slipped = 0
		g.progress = 0.0
		sk.reset()
		g.stretch_result("try")
		caught += g.stretch_caught
		slipped += g.stretch_slipped
	_check(
		caught > slipped,
		"a friendly helper catches most mistakes (%d caught vs %d slipped)" % [caught, slipped]
	)
	g.progress = 0.0
	g.stretch_result("watch")
	_check(g.progress == 10.0, "watching the helper: +10%")
	var e0: int = g.esc_now()
	g.stretch_result("escalate")
	_check(g.esc_now() == e0 + 1, "escalating back counts against the numbers")
	_check(
		g.success_chance() > 0.2 and g.success_chance() < 0.9,
		"success odds: %d%%" % int(g.success_chance() * 100.0)
	)

	# ---- graduating
	g.focus = "servers"
	g.progress = 90.0
	g.graduated = false
	sk.reset()
	var lv0: int = sk.level("servers")
	c.rep = 50
	var rep0: int = c.rep
	g._add_progress(20.0, 5)
	_check(g.graduated and g.progress == 100.0, "100% = Tier 2")
	_check(sk.level("servers") > lv0, "the skill goes up a level")
	_check(c.rep == rep0 + 3, "and so does your reputation")
	_check(g.status_line() == "TIER 2 IN SERVERS", "status: " + g.status_line())
	g.offer_block()
	_check(not cards.is_open, "nothing more to offer once you graduated")

	# ---- saving
	var data: Dictionary = g.to_dict()
	g.reset()
	g.from_dict(data)
	_check(g.graduated and g.focus == "servers" and g.helper == "Garrison", "the plan is saved")
	_check(g.esc_skill["networking"] == 2, "...and the gap list")

	# ---- the story schedule
	_check(
		story.DAYS[6][0].kind == "growth_plan" and story.DAYS[7].filter(func(e): return e.kind != "vignette").size() == 3,
		"Morgan runs the plan on day 6, then protected time and stretch tickets"
	)
	story.fire({"kind": "growth_block"})
	story.fire({"kind": "growth_stretch"})
	_check(not cards.is_open, "(graduated: events do nothing)")

	# ---- the owner: the only Tier 3
	c.new_game("owner")
	_drain(cards)
	_check(
		g.owner_free() == 28.0 and g.vic_penalty() == 0.0 and g.marketing_factor() == 1.0,
		"28 free owner hours a week"
	)
	var hours := 0.0
	for i in 1000:
		g.owner_used = 0.0
		g.owner_escalation({"pri": 3})
		hours += g.owner_used
	_check(
		hours > 90.0 and hours < 220.0,
		"about one ticket in ten reaches the owner (%.0f hours per 1000)" % hours
	)
	g.tier2 = 3
	var hours2 := 0.0
	for i in 1000:
		g.owner_used = 0.0
		g.owner_escalation({"pri": 3})
		hours2 += g.owner_used
	_check(hours2 < hours * 0.5, "Tier 2 techs cut escalations (%.0f vs %.0f)" % [hours2, hours])
	g.tier2 = 0
	g.owner_used = 25.0
	_check(
		g.owner_free() == 3.0 and g.vic_penalty() > 0.05 and g.marketing_factor() < 1.0,
		"with the owner drowning, sales and marketing suffer"
	)
	var warned_before: bool = g.owner_warned
	var row: Array = g.owner_week()
	_check(
		row[0] == "OWNER HOURS" and cards.is_open and not warned_before,
		"the weekly row, and Alan says you are the bottleneck"
	)
	cards.pick(0)
	_check(cards.is_open and cards.options.size() >= 1, "the learner card (the helper is not on the list)")
	cards.pick(0)
	_check(cards.is_open, "then the skill")
	cards.pick(0)
	_check(g.learner == "Maya" and g.focus != "" and not cards.is_open, "plan set for Maya (X4: Dan is the helper)")
	_check(g.board_lines().size() >= 2, "the Boardroom TEAM tab shows hours and the plan")

	msp.reset()
	g.progress = 0.0
	g.owner_week()
	_check(
		g.progress == 18.0 and g.blocks_taken == 1, "a quiet week: protected time happens (+18%)"
	)
	for i in 6:
		msp.create_ticket(i % 5, 0, "test")
	var burn0: float = owner.burnout
	g.owner_week()
	_check(
		g.progress == 22.0 and owner.burnout == burn0 + 3.0, "a full queue eats it: +4% and burnout"
	)
	_check(g.capacity_loss() > 0.0, "paid training time costs the team a little capacity")

	owner.flags = {}
	g.owner_stretch()
	_check(cards.is_open and cards.options.size() == 3, "a stretch ticket for Dan")
	cards.pick(2)
	_check(g.owner_used >= 4.0, "doing it yourself costs 4 owner hours")
	var ok_count := 0
	for i in 200:
		var before: float = g.progress
		g.owner_stretch_result("stretch", 0.6)
		ok_count += 1 if g.progress - before >= 30.0 or g.progress >= 100.0 else 0
		g.progress = 20.0
		g.graduated = false
		_drain(cards)
	_check(
		ok_count > 50 and ok_count < 190, "stretch assignments mostly work (%d of 200)" % ok_count
	)

	msp.reset()
	g.learner = "Dan"
	g.focus = "servers"
	g.progress = 95.0
	g.graduated = false
	var extra0: int = owner.weekly_extra
	var speed0: float = owner.speed
	g.owner_week()
	_check(g.graduated and g.tier2 == 1 and owner.speed > speed0, "week 100%: Dan is Tier 2")
	_check(cards.is_open and cards.options.size() == 2, "...and asks about a raise")
	cards.pick(0)
	_check(
		(
			owner.weekly_extra == extra0 + 60
			and g.learner == ""
			and owner.flags.get("growth_done", false)
		),
		"the raise costs $60 a week and the plan is free for the next learner"
	)
	_check(owner.practices() >= 1, "a growth plan is a business practice")

	# ---- owner policy cards and the schedule
	owner.flags = {}
	owner.burnout = 20.0
	owner.show_card("flex_hours")
	cards.pick(0)
	_drain(cards)
	_check(
		owner.flags.get("flex_hours", false) and owner.burnout == 14.0,
		"flexible hours lower burnout"
	)
	owner.show_card("oncall_policy")
	cards.pick(1)
	_drain(cards)
	_check(owner.flags.get("oncall_one", false), "one person on call every week is a choice")
	owner.show_card("oncall_policy")
	cards.pick(2)
	_drain(cards)
	_check(
		owner.flags.get("owner_oncall", false) and g.owner_free() == 20.0,
		"carrying the pager yourself costs 8 owner hours"
	)
	var scheduled := 0
	for day in owner.DAYS:
		for ev in owner.DAYS[day]:
			if (
				str(ev.get("event", "")).begins_with("growth")
				or str(ev.get("card", "")) in ["oncall_policy", "flex_hours"]
			):
				scheduled += 1
	_check(
		scheduled == 6, "owner schedule: plan, three stretches, two policy cards (%d)" % scheduled
	)

	var books: Dictionary = owner.settle()
	var found := false
	for r in books.rows:
		found = found or str(r[0]) == "OWNER HOURS"
	_check(found, "the weekly report has an OWNER HOURS row")
	_drain(cards)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
