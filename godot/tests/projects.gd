extends SceneTree
# Owner: client hours, scope creep, change orders, firing, services and projects.

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
	var o := root.get_node("Owner")
	var pr := root.get_node("Projects")
	var sales := root.get_node("Sales")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("owner")
	_drain(cards)

	# ---- hours and profitability
	_check(is_equal_approx(pr.hours(300.0), 20.0), "300 tech-seconds are 20 hours")
	_check(
		pr.included_hours(0) > 11.0 and pr.included_hours(0) < 13.0,
		"an $800 fee includes about 12 hours"
	)
	o.client_work[0] = 300.0
	pr.record_week()
	o.client_work[0] = 330.0
	pr.record_week()
	_check(
		is_equal_approx(pr.avg_hours(0), 21.0),
		"the average of the recorded weeks (%.1f)" % pr.avg_hours(0)
	)
	_check(
		pr.over_hours(0) > 8.0,
		"that is %.1f hours over what the fee covers: scope creep" % pr.over_hours(0)
	)
	o.client_work = {}

	# ---- the profit review card has a change order and a polite exit
	o.profit_hist[2] = [-100, -80]
	o._profit_review()
	_check(cards.is_open and cards.options.size() == 4, "the profit review offers four ways out")
	_check(
		str(cards.options[2].label).contains("CHANGE ORDER"),
		"one is a change order: " + str(cards.options[2].label)
	)
	_check(cards.text.contains("hours a week"), "and the card shows the hours")
	cards.pick(3)
	_check(
		(
			cards.is_open
			and cards.options.size() == 3
			and str(cards.options[0].label).contains("POLITELY")
		),
		"OTHER leads to firing politely, now, or keeping them"
	)
	_drain(cards)

	# ---- change orders
	o.client_work[2] = 600.0
	pr.record_week()
	pr.record_week()
	var accepted := 0
	for i in 60:
		o.cash = 1000
		sales.satisfaction[2] = 70
		o.scope_fixed.erase(2)
		pr.change_order(2)
		accepted += 1 if o.cash > 1000 else 0
	_check(
		accepted > 15 and accepted < 55,
		"a happy client pays (or half-pays) a change order about half the time (%d of 60)" % accepted
	)
	var billable := false
	for i in 80:
		o.scope_fixed.erase(2)
		sales.satisfaction[2] = 70
		pr.change_order(2)
		if o.scope_fixed.get(2, false):
			billable = true
			break
	_check(billable, "and requests beyond the plan become billable")

	# ---- firing and word of mouth
	var bad_now := 0
	var bad_polite := 0
	for i in 80:
		sales.active = [0, 1, 2, 3, 4]
		sales.satisfaction[1] = 30
		pr.wom_weeks = 0
		pr.fire_client(1, "now")
		bad_now += 1 if pr.wom_weeks > 0 else 0
		sales.active = [0, 1, 2, 3, 4]
		sales.satisfaction[1] = 30
		pr.wom_weeks = 0
		pr.fire_client(1, "polite")
		bad_polite += 1 if pr.wom_weeks > 0 else 0
		pr._queue = []
	_check(
		bad_now > 25 and bad_polite < bad_now - 10,
		(
			"firing an unhappy client suddenly invites bad word of mouth (%d of 80, vs %d polite)"
			% [bad_now, bad_polite]
		)
	)
	pr.wom_weeks = 6
	_check(pr.vic_penalty() > 0.0, "while it lasts Vic closes less")
	pr._queue = [{"kind": "wom", "client": 1}]
	pr.begin_week()
	_check(cards.is_open and cards.text.contains("hard to work with"), "a prospect mentions it")
	_drain(cards)
	sales.active = [0, 1, 2, 3, 4]
	pr.wom_weeks = 0
	pr._queue = []

	# ---- services are recurring revenue
	var rev0: int = o.weekly_estimate().revenue
	var fixed0: int = o.weekly_estimate().fixed
	pr.sell_service(0, "backup")
	_check(
		pr.service_revenue() == 110 and o.weekly_estimate().revenue == rev0 + 110,
		"a managed backup adds $110 a week"
	)
	_check(o.weekly_estimate().fixed == fixed0 + 35, "and costs us $35 a week")
	msp.backups[0].ok = false
	pr._services_week()
	_check(msp.backups[0].ok, "and it keeps the client's backup healthy")
	o.patch_debt[0] = 5.0
	pr.sell_service(0, "patching")
	pr._services_week()
	_check(o.patch_debt[0] == 3.0, "managed updates cut the patch debt")

	# ---- a service card that needs the platform first
	o.flags.erase("backup_service")
	o.cash = 5000
	pr.services = {}
	pr._queue = [{"kind": "service", "client": 3, "id": "backup"}]
	pr.begin_week()
	_check(
		cards.is_open and str(cards.options[0].label).contains("BUY THE PLATFORM"),
		"selling backup needs the platform first"
	)
	cards.pick(0)
	_drain(cards)
	_check(
		(
			o.flags.get("backup_service", false)
			and pr.has_service(3, "backup")
			and o.cash == 5000 - 600
		),
		"bought the platform and sold the service"
	)

	# ---- projects
	o.cash = 5000
	var q: Dictionary = pr.make_quote(0, "desktops")
	_check(
		q.price >= 1800 and q.price <= 3600 and q.hw > 0 and q.est == 18.0,
		"a desktop refresh quote: $%d, hardware $%d" % [q.price, q.hw]
	)
	var total := 0
	for i in 40:
		total += pr.quote_profit(pr.make_quote(0, "desktops"))
	_check(
		total > 0, "quotes make money on average if nothing goes wrong ($%d a job)" % (total / 40)
	)
	var speed0: float = o.team_speed()
	var p: Dictionary = pr.start_project(pr.make_quote(0, "server"), "fixed")
	_check(
		pr.drag() > 0.05 and o.team_speed() < speed0,
		(
			"a running project takes %d percent of the team's time from tickets"
			% int(pr.drag() * 100.0)
		)
	)
	p.creep = true  # force the creep so the rest of the test is not random
	p.est = float(p.est) * 1.25
	var price0: int = p.price
	pr._creep_answer(int(p.id), "co", int(price0 * 0.25), 1.0)
	_check(
		p.price == price0 + int(price0 * 0.25), "a change order raises the price of a creeping job"
	)
	var cash1: int = o.cash
	pr.week_income = 0
	p.weeks = 1
	pr._complete(p)
	_check(
		p.status == "done" and o.cash == cash1 + (p.price - p.hw),
		"completion banks the revenue minus hardware"
	)
	_check(
		pr.completed_count == 1 and pr.week_income == p.price - p.hw,
		"and counts as project income, left out of the valuation"
	)
	_check(
		pr.take_week_income() == p.price - p.hw and pr.week_income == 0,
		"which is taken out when the week is settled"
	)

	# a fixed job that creeps loses money; scoping first does not creep
	var creeps := 0
	for i in 200:
		var t: Dictionary = pr.start_project(pr.make_quote(0, "network"), "fixed")
		t.weeks = 2
		pr._projects_week()
		creeps += 1 if bool(t.creep) else 0
		t.status = "done"
	_check(
		creeps > 35 and creeps < 90,
		"fixed-price jobs creep about 30 percent of the time (%d of 200)" % creeps
	)
	var scoped_creeps := 0
	for i in 100:
		var t2: Dictionary = pr.start_project(pr.make_quote(0, "network"), "scope")
		t2.delay = 0
		t2.weeks = 2
		pr._projects_week()
		scoped_creeps += 1 if bool(t2.creep) else 0
		t2.status = "done"
	_check(scoped_creeps == 0, "scoping it first never creeps")
	pr._queue = []
	_drain(cards)

	# ---- an opportunity becomes a quote card and a project
	var count0: int = pr.projects.size()
	pr._queue = [{"kind": "project", "client": 0, "type": "desktops"}]
	pr.begin_week()
	_check(
		cards.is_open and cards.options.size() == 4 and cards.text.contains("quote"),
		"Vic brings a project: four ways to quote it"
	)
	cards.pick(1)
	_drain(cards)
	_check(
		pr.projects.size() == count0 + 1 and pr.projects[-1].scoped and pr.projects[-1].delay == 1,
		"scoping first starts next week, with a paid discovery"
	)

	# ---- saving
	var data: Dictionary = pr.to_dict()
	var before: int = pr.projects.size()
	pr.reset()
	pr.from_dict(data)
	_check(pr.projects.size() == before and pr.completed_count == 1, "projects are saved")

	# ---- the weekly report
	c.new_game("owner")
	_drain(cards)
	var books: Dictionary = o.settle()
	var found := false
	for r in books.rows:
		found = found or str(r[0]) == "RECURRING + PROJECTS"
	_check(found, "the weekly report shows recurring revenue and project money")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
