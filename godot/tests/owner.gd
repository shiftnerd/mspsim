extends SceneTree
# The owner campaign: cards, the team, weekly books (EBITDA, W-2), churn, peers, mentor, marketing,
# then a whole 20-week run with every card auto-answered. Headless; saves in user://test_*.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear_cards(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var story := root.get_node("Story")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	c.save_prefix = "user://test_"
	root.get_node("Game").title_mode = false

	c.new_game("owner")
	_check(
		c.active and c.mode == "owner" and o.cash == 5000 and world.day_len == 240.0,
		"new owner campaign: $5,000, 4-minute weeks"
	)
	var est: Dictionary = o.weekly_estimate()
	_check(
		est.revenue == 4000 and est.payroll == 2700 and est.fixed == 640 and est.ebitda == 660,
		"week 1 books: " + str(est)
	)

	# day 1's pricing card
	world.clock = 8.6
	await process_frame
	world.clock = 9.2
	await process_frame
	await process_frame
	_check(
		cards.is_open and cards.speaker.begins_with("Marge"),
		"day 1: the bookkeeper asks about pricing"
	)
	cards.pick(2)
	_check(
		o.price == 1.2 and o.vic_bonus < 0.0 and o.client_fee(0) == 960, "premium pricing: fees 960"
	)
	_clear_cards(cards)
	_check(story.flags.is_empty(), "the tech story does not run in the owner campaign")

	# the backup card: cash gating, then the purchase
	o.cash = 300
	o.show_card("backup")
	_check(not cards.options[0].get("enabled", true), "can't afford the backup service at $300")
	cards.pick(1)
	_clear_cards(cards)
	o.cash = 5000
	o.show_card("backup")
	cards.pick(0)
	_check(
		o.cash == 4400 and o.weekly_extra == 100 and o.flags.backup_service,
		"bought the backup service"
	)
	msp.backups[1].ok = false
	o.begin_day(2)
	_check(msp.backups[1].ok, "the service keeps every backup healthy")

	# the team works the queue by itself
	msp.reset()
	var ids := []
	for k in 3:
		ids.append(int(msp.create_ticket(k, 0, "test").id))
	for i in 10:
		o._work_queue(30.0)
	var closed := 0
	for id in ids:
		closed += 1 if msp.ticket(id).status == "Closed" else 0
	_check(closed >= 2, "techs closed %d of 3 tickets on their own" % closed)
	o.speed = 0.1
	var slow: Dictionary = msp.create_ticket(0, 1, "test")
	o._work_queue(3.0)
	_check(msp.ticket(slow.id).status != "Closed", "a slow team leaves tickets open")
	o.speed = 1.0

	# ransomware: with the backup service it is a save, without it a lawsuit card
	msp.reset()
	story.flags = {}
	o.flags.backup_service = true
	o.fire({"event": "ransomware"})
	_check(
		story.flags.ransom == "saved" and not cards.is_open,
		"ransomware with the backup service: saved"
	)
	msp.reset()
	story.flags = {}
	o.flags.backup_service = false
	msp.break_backup(story.RANSOM_CLIENT)
	o.fire({"event": "ransomware"})
	_check(
		cards.is_open and cards.options.size() == 3,
		"no backup: pay, shadow copies or accept the loss"
	)
	cards.pick(2)  # accept the loss
	_check(
		story.flags.ransom == "lost" and cards.is_open and cards.speaker.begins_with("Marge"),
		"no backup, accepted the loss: data lost and a lawsuit card"
	)
	var cash0: int = o.cash
	cards.pick(0)
	_check(o.cash == cash0 - 2500, "settled for $2,500")
	_clear_cards(cards)

	# the books and churn
	o.cash = 5000
	o.income_extra = 0
	sales.satisfaction[3] = 10
	var books: Dictionary = o.settle()
	_check(
		(
			books.rows.size() == 12
			and o.cash > 4000
			and o.ar_total() > 0
			and books.grade in ["B", "A", "S", "C"]
		),
		"settle: cash %d, grade %s" % [o.cash, books.grade]
	)
	o._leaving = [3]
	o.begin_day(3)
	_check(
		cards.is_open and cards.text.contains("Hoot and Holler"),
		"an unhappy client threatens to leave"
	)
	cards.pick(1)
	_check(not sales.active.has(3), "letting them go removes the client")
	_clear_cards(cards)

	# EBITDA, the W-2 ratio and what a buyer would pay
	c.new_game("owner")
	est = o.weekly_estimate()
	_check(
		absf(est.w2 - 0.675) < 0.001 and absf(est.margin - 0.165) < 0.001,
		"W-2 ratio 67.5%% and EBITDA margin 16.5%%"
	)
	_check(
		o.multiple() == 5.0 and o.valuation() == int(660.0 * 52.0 * 5.0 * o.quality()) + o.cash,
		"valuation = 5.0x annual EBITDA x reputation quality + cash (%d)" % o.valuation()
	)
	o.apply({"hire": o.JUNIOR})
	_check(
		o.weekly_estimate().w2 > est.w2 and o.weekly_estimate().ebitda == 660 - 450,
		"a hire raises the W-2 ratio and costs EBITDA"
	)

	# marketing: a weekly budget that helps Vic and brings leads
	c.new_game("owner")
	var vic0: float = sales.vic_skill()
	o.show_card("marketing")
	_check(cards.options.size() == 4, "the marketing card offers four budgets")
	cards.pick(2)
	_check(
		o.marketing == 400 and sales.vic_skill() > vic0 and o.weekly_estimate().ebitda == 660 - 400,
		"standard marketing: Vic closes more, EBITDA pays for it"
	)
	_clear_cards(cards)
	o._leads = 1
	o.begin_day(5)
	_check(
		cards.is_open and cards.text.contains("inbound lead") and cards.options.size() >= 2,
		"marketing brings an inbound lead"
	)
	var active0: int = sales.active.size()
	cards.pick(1)
	_clear_cards(cards)
	_check(sales.active.size() >= active0, "lead handled")

	# the peer group
	c.new_game("owner")
	o.cash = 5000
	o.show_card("peer_invite")
	cards.pick(0)
	_clear_cards(cards)
	_check(o.flags.peer_group and o.weekly_extra == 75 and o.cash == 4500, "joined the peer group")
	o.fire({"event": "peer", "card": "peer1"})
	_check(cards.is_open and cards.speaker == "MSP Mastermind", "a peer meeting opens")
	cards.pick(0)
	_clear_cards(cards)
	_check(
		o.flags.backup_service and o.weekly_extra == 175,
		"bought the backup service through the group"
	)
	o.show_card("peer1")
	_check(
		not cards.options[0].get("enabled", true) and cards.options[0].hint == "OWNED",
		"the deal is greyed out once owned"
	)
	_clear_cards(cards, 2)
	msp.reset()
	msp.break_backup(3)
	o.fire({"event": "peer", "card": "peer2"})
	cards.pick(0)
	_clear_cards(cards)
	_check(msp.backups[3].ok, "the peers' warning gets the team to fix the failing backup")
	var guest := Node.new()
	o.flags.peer_group = false
	o.fire({"event": "peer", "card": "peer3"})
	_check(not cards.is_open, "no meetings if you never joined")
	guest.free()

	# the mentor
	var table := [[0.5, {}, "good"], [0.5, {}, "bad"]]
	o.flags.mentor = false
	_check(absf(o.tilted(table)[0][0] - 0.5) < 0.001, "no mentor: the odds are what they are")
	o.show_card("mentor_offer")
	cards.pick(0)
	_clear_cards(cards)
	_check(o.flags.mentor and o.weekly_extra >= 400, "hired Dana")
	_check(
		absf(o.tilted(table)[0][0] - 0.6) < 0.001 and absf(o.tilted(table)[1][0] - 0.4) < 0.001,
		"the mentor shifts 10%% of the odds to the good outcome"
	)
	o.cash = 900
	o.advice()
	_check(
		cards.is_open and cards.text.contains("Cash is thin") and cards.options.size() == 3,
		"Dana's advice follows your numbers (cash is thin)"
	)
	var weekly0: int = o.weekly_extra
	cards.pick(2)
	_clear_cards(cards)
	_check(
		not o.flags.mentor and o.weekly_extra == weekly0 - 400, "dismissing Dana saves $400 a week"
	)
	o.flags.scoped = true
	var scoped: Array = o.CARDS["migration"].options[0].roll_scoped
	_check(scoped[0][0] == 0.9, "scoping first makes the fixed-price job safer")

	# the stack you run and sell: cheap tools cost morale and speed, cheap hardware costs tickets
	c.new_game("owner")
	var speed0: float = o.team_speed()
	_check(
		o.stack_cost() == 140 and o.issue_mult() == 1.0 and o.hardware_margin() == 200,
		"default stack: $140/week, normal tickets, $200 margin"
	)
	o.cash = 5000
	o.show_card("stack_psa")
	cards.pick(1)
	_clear_cards(cards)
	_check(
		o.stack.psa == "ticketo" and o.cash == 4700 and o.stack_cost() == 95,
		"switched the PSA to Ticketo Lite: cheaper by $45/week"
	)
	_check(
		o.team_speed() < speed0 and o.stack_sum("morale") == -8.0,
		"the crew is slower and unhappier with the cheap PSA"
	)
	o.apply({"stack": {"hardware": "budgetbyte"}})
	_check(
		o.issue_mult() > 1.3 and o.vic_extra() > 0.11 and o.hardware_margin() == 120,
		"cheap hardware: more tickets, Vic sells more, thinner margin"
	)
	o.fire({"event": "grumble"})
	_check(
		cards.is_open and cards.text.contains("Ticketo Lite"),
		"the crew complains about the cheap tool"
	)
	cards.pick(0)
	_clear_cards(cards)
	_check(o.stack.psa == "connectwhy", "switching back to the standard PSA")
	o.apply({"stack": {"psa": "opsforge", "rmm": "labrat_gold"}})
	_check(
		o.team_speed() > speed0 and o.stack_sum("morale") > 0.0,
		"premium tools: faster, happier crew"
	)

	# hiring: three named candidates with skills, wages and traits
	c.new_game("owner")
	var cands: Array = o.make_candidates()
	var names := {}
	for cand in cands:
		names[cand.name] = true
	_check(
		cands.size() == 3 and names.size() == 3 and cands[0].wage >= 300,
		"three different candidates with wages"
	)
	o.show_card("queue")
	cards.pick(0)
	_check(
		cards.is_open and cards.options.size() == 4 and cards.text.contains("candidates"),
		"the queue card leads to the candidate list"
	)
	var payroll0: int = o.weekly_estimate().payroll
	cards.pick(0)
	_clear_cards(cards)
	_check(
		o.extra_staff.size() == 1 and o.weekly_estimate().payroll > payroll0,
		"hired someone: payroll and W-2 ratio go up"
	)
	o.extra_staff = [{"name": "Tom", "skill": 0.5, "wage": 400, "trait": "green"}]
	o._staff_week()
	_check(absf(o.extra_staff[0].skill - 0.54) < 0.001, "a green hire learns each week")
	o.extra_staff = [{"name": "Wiz", "skill": 1.0, "wage": 600, "trait": "wizard"}]
	_check(o.team_speed() > 3.0 * 1.0 * 0.9, "a wizard adds speed")

	# late payers: accounts receivable and the collections card
	c.new_game("owner")
	sales.active = [0, 1, 6]
	var cash1: int = o.cash
	o.settle()
	_check(
		o.ar_total() == 800 and o.ar[0].client == 6, "a slow payer's invoice goes into receivables"
	)
	var books1: Dictionary = o.settle()
	o.settle()
	o.settle()
	_check(o._late.has(6) or o.ar_total() > 0, "weeks later the invoice is long overdue")
	var owed: int = o.ar_total(6)
	o.begin_day(5)
	_check(cards.is_open and cards.text.contains("owes us"), "Marge brings the collections problem")
	var cash2: int = o.cash
	cards.pick(1)
	var cash_after: int = o.cash  # before any queued lead card can change the cash
	_clear_cards(cards)
	_check(cash_after == cash2 + owed / 2, "payment plan: half now")
	o.income_extra = 0
	o._writeoff(6)
	_check(o.ar_total(6) == 0 and o.income_extra < 0, "writing it off is bad debt against EBITDA")
	_check(books1.rows[8][0] == "CLIENTS, A/R OWED", "the weekly report shows what is owed")

	# a business review with a client
	c.new_game("owner")
	o._qbr()
	_check(
		cards.is_open and cards.options.size() >= 3 and cards.text.contains("Business review"),
		"business review card"
	)
	var reviewed: String = cards.text
	cards.pick(2)
	_clear_cards(cards)
	o._qbr()
	_check(cards.is_open and cards.text != reviewed, "the next review is with a different client")
	_clear_cards(cards)
	o.apply({"fee_boost": {"client": 0, "mult": 1.1}})
	_check(o.client_fee(0) == 880, "a successful review raised the client's fee 10%%")

	# Vic's pay plan: commission sells more but oversells
	c.new_game("owner")
	_check(
		o.new_client_mood() == 75 and o.weekly_estimate().payroll == 2700,
		"salary plan: steady, new clients start happy"
	)
	o.show_card("vic_plan")
	cards.pick(2)
	_clear_cards(cards)
	_check(
		o.vic_plan == "commission" and o.new_client_mood() == 58 and o.vic_extra() >= 0.12,
		"commission plan: Vic sells harder, new clients start unhappy"
	)
	var cash3: int = o.cash
	var signed: int = sales.sign_client()
	_check(
		sales.mood(signed) == 58 and o.vic_deals == 1 and o.cash == cash3 - 300 + 400,
		"a signing costs $300 commission and earns $400 of hardware margin"
	)
	_check(
		o.weekly_estimate().payroll == 2700 - 750 + 350 + 300,
		"commission counts toward payroll and the W-2 ratio"
	)
	o._vic_report()
	_check(
		cards.is_open and cards.text.contains("1 deals") and cards.text.contains("happiness"),
		"Vic's report: deals and how happy his clients are"
	)
	_clear_cards(cards, 2)
	var comp := root.get_node("Computer")
	comp.open(1)
	comp.activate("app:boardroom")
	for tab in ["clients", "team", "stack", "books"]:
		comp.activate("btab:" + tab)
		_check(comp.board_tab == tab, "boardroom tab " + tab)
	comp.close()

	# a bad week: bankruptcy = fired
	c.new_game("owner")
	o.cash = -5000
	_check(o.settle().bankrupt, "cash below -$3,000 is bankruptcy")

	# the whole 20 weeks
	c.new_game("owner")
	var weeks := 0
	for day in range(1, 21):
		world.clock = 8.6
		var hour := 8.6
		while not report.is_open and hour < 23.9:
			hour += 0.3
			world.clock = hour
			await process_frame
			await process_frame
			_clear_cards(cards, (day + int(hour)) % 2)
			o._work_queue(20.0)
		_check(report.is_open, "week %d ends with a P&L report (cash $%d)" % [day, o.cash])
		weeks += 1
		if report.report.get("final", false):
			break
		report.finish()
		await create_timer(0.7).timeout
		root.get_node("Game").busy = false
	await process_frame
	_check(report.is_open and weeks >= 1, "ran %d weeks" % weeks)
	if report.report.fired:
		report.finish()
		await create_timer(0.5).timeout
		print("(the run went bankrupt or lost its name: that is a valid ending)")
	else:
		report.finish()
		await process_frame
		_check(review.is_open, "board review at the end")
		var kinds: Array = review.offers.map(func(x: Dictionary) -> String: return x.id)
		_check(kinds.has("sell") and kinds.has("stay"), "offers: " + str(kinds))
		for page in 4:
			review.page_lines()
			if page == 2:
				review.choose(0)
			else:
				review.advance()
		review.finish()
		await create_timer(0.5).timeout
		_check(not c.active, "owner campaign finished")
	DirAccess.remove_absolute(c.save_prefix + "meta.cfg")
	DirAccess.remove_absolute(c.save_path("owner"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
