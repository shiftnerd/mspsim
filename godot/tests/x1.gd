extends SceneTree
# Roadmap X1: owner-campaign round 2 (deterministic parts): the Vic complaint spread, Dana's advice
# without repeats, the billing leak in cash, REVIEW DUE at the start, one Esc closes the Computer,
# the outing invitation states its cost, the meeting upside and the balance helpers.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var msp := root.get_node("Msp")
	var projects := root.get_node("Projects")
	var outings := root.get_node("Outings")
	var comp := root.get_node("Computer")
	var game := root.get_node("Game")
	game.title_mode = false
	c.save_prefix = "user://test_x1_%d_" % OS.get_process_id()

	# 1. REVIEW DUE is not shown at the start; it comes round from week 6
	c.new_game("owner")
	_clear(cards)
	var any_due := false
	for cl in sales.active:
		any_due = any_due or o.review_due(int(cl))
	_check(not any_due, "no client shows REVIEW DUE in week 1")
	c.day = 6
	_check(o.review_due(int(sales.active[0])), "a client is due a review from week 6")
	o._qbr_done[int(sales.active[0])] = 6
	c.day = 9
	_check(not o.review_due(int(sales.active[0])), "a reviewed client is not due again for 8 weeks")
	c.day = 14
	_check(o.review_due(int(sales.active[0])), "and is due again after 8 weeks")

	# 2. the same client does not complain to Vic every week
	c.new_game("owner")
	_clear(cards)
	msp.reset()
	c.day = 5
	var ta: Dictionary = msp.create_ticket(0, 1, "test")
	var tb: Dictionary = msp.create_ticket(1, 1, "test")
	msp.ticket(ta.id).sla_left = 5.0
	msp.ticket(tb.id).sla_left = 6.0
	var first: Dictionary = sales.find_complaint()
	_check(not first.is_empty(), "a late ticket makes a complaint")
	sales.complained_day[int(first.client)] = c.day  # what _process records when Vic picks it up
	var second: Dictionary = sales.find_complaint()
	_check(
		not second.is_empty() and int(second.client) != int(first.client),
		"the next complaint comes from another client"
	)
	sales.complained_day[int(second.client)] = c.day
	_check(sales.find_complaint().is_empty(), "no one complains twice in the same week")
	c.day = 6
	_check(sales.find_complaint().is_empty(), "nor the week after")
	c.day = 7
	_check(not sales.find_complaint().is_empty(), "two weeks later they may complain again")
	# the real path records the client
	c.day = 20
	sales.complained_day = {}
	sales.pending = {}
	sales._cool = 0.0
	msp.enabled = true
	c.active = true
	world.time_scale = 1.0
	sales._process(0.1)
	_check(
		not sales.complained_day.is_empty(),
		"Sales._process stamps the complaining client"
	)
	sales.pending = {}

	# 3. Dana never repeats the same advice inside three weeks
	c.new_game("owner")
	_clear(cards)
	msp.reset()
	o.flags["mentor"] = true
	var seen := []
	var repeat := false
	for week in range(7, 17):
		c.day = week
		o.advice()
		var txt: String = cards.text
		for i in seen.size():
			if seen[i][1] == txt and week - int(seen[i][0]) < 3:
				repeat = true
		seen.append([week, txt])
		_clear(cards)
	_check(not repeat, "ten weeks of advice: no card repeats within three weeks")
	var distinct := {}
	for s in seen:
		distinct[s[1]] = true
	_check(distinct.size() >= 3, "and Dana has several different things to say (%d)" % distinct.size())
	c.new_game("owner")
	_clear(cards)
	o.cash = 500
	_check(o.advice_topic(0, o.weekly_estimate()) == "cash", "thin cash is the first topic")
	o._advice_week["cash"] = c.day
	_check(o.advice_topic(0, o.weekly_estimate()) != "cash", "and the next one is another relevant card")

	# 4. the billing leak and the services reach cash as well as revenue
	c.new_game("owner")
	_clear(cards)
	projects.enabled = false
	c.day = 3
	o.leak = 0.06
	o.ar = []
	projects.services = {0: ["backup"], 1: ["patching"]}
	var est: Dictionary = o.weekly_estimate()
	var cash0: int = o.cash
	o.settle()
	var delta: int = o.cash - cash0 + o.ar_total()
	_check(
		absi(delta - int(est.cashflow)) <= sales.active.size(),
		"cash change plus new receivables equals EBITDA with a leak and services (%d vs %d)" % [delta, int(est.ebitda)]
	)
	c.new_game("owner")
	_clear(cards)
	projects.enabled = false
	c.day = 3
	o.ar = []
	var est0: Dictionary = o.weekly_estimate()
	o.leak = 0.06
	var est6: Dictionary = o.weekly_estimate()
	_check(int(est6.revenue) < int(est0.revenue), "the leak lowers reported revenue")
	cash0 = o.cash
	o.settle()
	_check(
		absi(o.cash - cash0 + o.ar_total() - int(est6.cashflow)) <= sales.active.size(),
		"and the same amount is missing from cash"
	)
	projects.services = {}

	# 5. taking the meeting yourself now has an upside
	c.new_game("owner")
	_clear(cards)
	var before: int = sales.active.size()
	o.apply({"sign": true, "client": 6, "sign_bonus": {"mood": 15, "fee": 1.1}})
	_check(sales.active.size() == before + 1 and sales.active.has(6), "the meeting signs the client")
	_check(sales.mood(6) == o.new_client_mood() + 15, "who starts happier (%d)" % sales.mood(6))
	_check(o.client_fee(6) == int(float(o.FEE) * 1.1), "and pays 10 percent more (%d)" % o.client_fee(6))
	o._inbound_lead()
	var lead_label := ""
	for opt in cards.options:
		if str(opt.label).begins_with("TAKE THE MEETING"):
			lead_label = str(opt.label)
	_check("HAPPIER" in lead_label, "the lead card names the upside: %s" % lead_label)
	_clear(cards)

	# 6. one Esc closes the Computer; a sub-view takes the first one
	comp.is_open = true
	comp.app = "desktop"
	comp._input(_esc())
	_check(not comp.is_open, "Esc on the desktop closes the Computer")
	comp.is_open = true
	comp.app = "psa"
	comp.psa_detail = false
	comp._input(_esc())
	_check(not comp.is_open, "Esc inside an app closes it in one press")
	comp.is_open = true
	comp.app = "mail"
	comp.mail_view = true
	comp._input(_esc())
	_check(comp.is_open and not comp.mail_view, "Esc in an open mail only closes the mail")
	comp._input(_esc())
	_check(not comp.is_open, "and the next Esc closes the Computer")
	game.ui_open = false

	# 7. the outing invitation states its cost before the game pick
	c.new_game("owner")
	_clear(cards)
	outings.enabled = true
	outings._offered = false
	c.day = 4
	world.clock = 16.5
	world.time_scale = 1.0
	outings.maybe_invite()
	_check(
		cards.is_open and "$100 to $300" in cards.text,
		"the invitation says what the night costs: %s" % cards.text
	)
	_clear(cards)

	# 8. balance helpers: ramped first hire, calendar-capped maturity, costs that grow
	c.new_game("owner")
	_clear(cards)
	c.day = 3
	var base_over: int = o.overhead()
	var hire := {"name": "Test", "skill": 1.0, "wage": 500, "trait": "steady", "age": 0}
	_check(o.hire_wage(hire) == 300, "a new hire costs 60 percent of the wage at first (%d)" % o.hire_wage(hire))
	hire["age"] = 3
	_check(o.hire_wage(hire) == 500, "and the full wage after the ramp")
	c.day = 15
	_check(o.overhead() > base_over, "rent and insurance rise later in the game")
	_check(o.tech_wage() > o.WAGE, "the techs get a raise by week 12")
	for k in ["peer_group", "practice_profit", "backup_service", "practice_goal", "practice_handover", "collections_done", "growth_done", "practice_scope"]:
		o.flags[k] = true
	o.price = 1.1
	o.vic_plan = "balanced"
	c.day = 5
	_check(o.oml() <= 2, "clicking through habits early does not give maturity (level %d in week 5)" % o.oml())
	c.day = 18
	_check(o.oml() >= 4, "the same habits count later (level %d in week 18)" % o.oml())

	print("x1: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
