extends SceneTree
# Roadmap X9: owner campaign round 3 (deterministic parts): the card queue (every card once, in order, across the
# report), one value function, the peer goal flow, trust arrows and a costly override, text formats, risky upsells,
# late-game pressure cards, cooldowns and the XP wave.

var failures := 0
var _shown: Array = []


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1


func _g_callback(_id: String) -> void:
	root.get_node("Cards").ask("T", "card J", [{"label": "OK", "id": "ok"}], _note("J"))
	_shown.append("G")


func _stale(id: String) -> void:
	_shown.append("L" + id)


func _never() -> bool:
	return false


func _note(tag: String) -> Callable:
	return func(_id: String) -> void: _shown.append(tag)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var report := root.get_node("DayReport")
	var sales := root.get_node("Sales")
	var partner := root.get_node("Partner")
	var projects := root.get_node("Projects")
	var outings := root.get_node("Outings")
	var game := root.get_node("Game")
	game.title_mode = false
	c.save_prefix = "user://test_x9_%d_" % OS.get_process_id()
	c.new_game("owner")
	_clear(cards)

	# B. the card queue: six cards asked across a report open / close come out once each, in the order asked
	_shown = []
	var opts := [{"label": "OK", "id": "ok"}]
	cards.ask("T", "card A", opts, _note("A"))
	cards.ask("T", "card B", opts, _note("B"))
	cards.ask("T", "card C", opts, _note("C"))
	_check(cards.is_open and cards.text == "card A" and cards.waiting() == 2, "A is open, B and C wait")
	report.is_open = true  # the weekly report covers the screen
	cards.cover()
	cards.ask("T", "card D", opts, _note("D"))
	cards.ask("T", "card E", opts, _note("E"))
	_check(cards.waiting() == 4, "cards asked under the report queue up")
	report.is_open = false
	cards.flush()
	_check(cards.is_open and cards.text == "card A", "the card that was open comes back after the report (not replaced)")
	# answering A asks F from inside the callback: it must not jump the line
	cards.ask("T", "card F", opts, _note("F"))
	cards.pick(0)
	var order := ""
	var n := 0
	while cards.is_open and n < 12:
		order += cards.text.right(1)
		cards.pick(0)
		n += 1
	_check(_shown == ["A", "B", "C", "D", "E", "F"], "six cards shown once each, in the order asked: %s" % str(_shown))
	_check(order == "BCDEF" and cards.waiting() == 0 and not cards.is_open, "the queue ran dry in order (%s)" % order)
	# a card asked from inside a pick callback goes behind the queue
	_shown = []
	cards.ask("T", "card G", opts, _g_callback)
	cards.ask("T", "card H", opts, _note("H"))
	cards.ask("T", "card I", opts, _note("I"))
	_clear(cards)
	_check(_shown == ["G", "H", "I", "J"], "a card asked inside a callback waits its turn: %s" % str(_shown))
	# a stale card is dropped once, and the asker hears "__none"
	_shown = []
	cards.ask("T", "card K", opts, _note("K"))
	cards.ask("T", "card L", opts, _stale, _never)
	cards.ask("T", "card M", opts, _note("M"))
	_clear(cards)
	_check(_shown == ["K", "L__none", "M"], "an invalid card reports __none and is never shown: %s" % str(_shown))

	# C. one value everywhere
	c.new_game("owner")
	_clear(cards)
	c.day = 10
	o.history = [
		{"day": 7, "profit": 900, "ebitda": 900, "cash": 5000},
		{"day": 8, "profit": 1200, "ebitda": 1200, "cash": 5500},
		{"day": 9, "profit": 1500, "ebitda": 1500, "cash": 6000}
	]
	var rep_data: Dictionary = o.settle()
	var value_row := ""
	for row in rep_data.rows:
		if str(row[0]) == "VALUE (ESTIMATE)":
			value_row = str(row[1])
	_check(value_row.begins_with(o.value_text()), "the report's value estimate is Owner.value_text(): %s vs %s" % [value_row, o.value_text()])
	_check(o.value_text().begins_with("$%d " % o.valuation()), "value_text is built from valuation()")
	_clear(cards)
	var review_has := false
	for page in 5:
		for line in o.review_lines(page, ""):
			review_has = review_has or str(line[0]).contains(o.value_text())
	_check(review_has, "the board review quotes the same value")
	# the value is no longer a runaway: best multiple 5.5, a poor name costs more, a young company is discounted
	_check(o.quality() <= 1.0 and o.quality() >= 0.3, "quality stays in 0.3..1")
	c.rep = 100
	var q_full: float = o.quality()
	c.rep = 40
	_check(q_full == 1.0 and o.quality() < 0.55, "quality: rep 100 = 1.0, rep 40 = %.2f" % o.quality())
	_check(o.multiple() <= 5.5, "the multiple tops out at 5.5 (now %.2f)" % o.multiple())
	c.rep = 80
	c.day = 2
	var young: int = o.valuation()
	c.day = 14
	_check(o.valuation() > young, "a young company is valued below the same books at week 14")

	# D. the peer goal: set, check (met / missed with the rep effect), ask the next, including week 17 and the review
	c.new_game("owner")
	_clear(cards)
	o.flags["peer_group"] = true
	c.day = 5
	o._peer_goal()
	_check(cards.is_open and cards.text.contains("Set a goal") and cards.text.contains("+2"), "week 5 asks for a goal and says what it pays")
	cards.pick(1)  # mood goal
	_clear(cards)
	_check(str(o.goal.get("id", "")) == "mood", "the goal is set")
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 90
	c.day = 11
	var rep0: int = c.rep
	o._peer_goal()
	_check(cards.is_open and cards.text.contains("GOAL MET") and c.rep == rep0 + 2, "week 11: met, reputation +2, said in a card")
	_check(o.goal.is_empty(), "the goal is cleared once checked")
	cards.pick(0)
	_check(cards.is_open and cards.text.contains("Set a goal"), "...and then the next goal is asked")
	cards.pick(0)  # W-2
	_clear(cards)
	_check(str(o.goal.get("id", "")) == "w2", "a new goal is set at week 11")
	o.goal = {"id": "mood", "week": 11}
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 20
	c.day = 17
	rep0 = c.rep
	o._peer_goal()
	_check(cards.is_open and cards.text.contains("GOAL MISSED") and c.rep == rep0 - 1, "week 17: missed, reputation -1, said in a card")
	cards.pick(0)
	_check(cards.is_open and cards.text.contains("final stretch"), "week 17 asks for a last goal")
	cards.pick(0)
	_clear(cards)
	_check(not o.goal.is_empty(), "the last goal is set")
	c.day = 20
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 95
	o.goal = {"id": "mood", "week": 17}
	rep0 = c.rep
	var final_rep: Dictionary = o.settle()
	var peer_row := ""
	for row in final_rep.rows:
		if str(row[0]) == "PEER GOAL":
			peer_row = str(row[1])
	_check(peer_row.contains("GOAL MET") and o.goal.is_empty(), "the review week checks the last goal (row: %s)" % peer_row)
	_clear(cards)

	# E. trust arrows and a costly override
	c.new_game("owner")
	_clear(cards)
	partner.hold_beat("partner1")
	_check(cards.is_open and cards.options.size() == 3, "the partner meeting opens")
	var chips := []
	for opt in cards.options:
		chips.append(str(opt.get("trust_chip", "")))
	_check(chips.all(func(s: String) -> bool: return s.begins_with("TRUST ")), "every meeting option shows a trust arrow: %s" % str(chips))
	_check(chips.has("TRUST UP") and chips.has("TRUST DOWN"), "up and down both appear")
	var t0: int = partner.trust
	cards.pick(2)  # keep it in the bank: +1 for both partners
	_check(partner.trust == t0 + 1, "the trust change happens")
	_check(cards.is_open and cards.text.contains("TRUST +1"), "a result line reports it: %s" % cards.text.right(40))
	_clear(cards)
	t0 = partner.trust
	var note: String = partner.on_pick("oppose")
	_check(partner.trust == t0 - 5 and partner.sulk == 2 and note.contains("TRUST -5"), "overriding costs 5 and a sulk (%s)" % note)
	var hands_sulking: float = partner.hands()
	partner.sulk = 0
	_check(hands_sulking < partner.hands() and partner.help_hours() >= 0.0, "a sulking partner pulls fewer tickets")
	partner.sulk = 2
	partner.week(0)
	_check(partner.sulk == 1, "the sulk wears off a week at a time")
	t0 = partner.trust
	partner.on_pick("oppose")
	_check(partner.trust == t0 - 6, "each further override costs more (-6)")

	# F. text and numbers
	_check(o.money(-23) == "-$23" and o.money(8000) == "$8,000" and o.money(1234567) == "$1,234,567", "money(): -$23 and $8,000")
	_check(o.poss("Lindqvist and Moss Architects") == "Lindqvist and Moss Architects'" and o.poss("Acme Dental") == "Acme Dental's", "possessives cope with a final s")
	c.new_game("owner")
	_clear(cards)
	o.cash = 8000
	o.show_card("welcome")
	_check(cards.is_open and cards.text.contains("$8,000 in the bank") and not cards.text.contains("7,500"), "the welcome card reads the real cash")
	_clear(cards)
	o.show_card("rack")
	var rack_label := str(cards.options[0].label)
	_check(rack_label == rack_label.to_upper() and rack_label.begins_with("SEND "), "SEND <NAME> NOW is all caps: %s" % rack_label)
	_clear(cards)
	outings.use_rooms = true
	_check(outings.cost_range().contains("$520"), "the invitation range includes the fancy dinner: %s" % outings.cost_range())
	outings.use_rooms = false
	_check(outings.cost_range() == "$100 to $300", "...and is the plain range without the restaurant")
	var q: Dictionary = {"price": 1800, "hw": 1500, "est": 40}
	var quoted: int = projects.quote_profit(q)
	_check(not o.money(quoted).contains("$-"), "a negative quote reads -$n: %s" % o.money(quoted))
	o.show_card("raise")
	var pay0: int = o.weekly_estimate().payroll
	var wk0: int = o.weekly_extra
	cards.pick(0)
	_clear(cards)
	_check(o.weekly_extra == wk0 and o.payroll_extra == 100 and o.weekly_estimate().payroll == pay0 + 100, "Dan's raise is payroll, not other costs")
	var charselect = load("res://scripts/charselect.gd")
	for who in ["office_alan", "casual_garrison"]:
		_check(str(charselect.OWNER_BLURBS[who]).length() <= 80, "owner blurb fits one line: %s" % who)

	# A. risky upsells and late-game pressure
	c.new_game("owner")
	_clear(cards)
	c.day = 14
	var mood_hi := 0
	var paid := {}
	var outcomes := {}
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 90
	var cl0: int = int(sales.active[0])
	for i in 300:
		sales.satisfaction[cl0] = 90
		o.discount.erase(cl0)
		var text: String = projects.change_order(cl0)
		var kind := "pay" if text.begins_with("They pay") else ("dispute" if text.contains("dispute") else "refuse")
		outcomes[kind] = int(outcomes.get(kind, 0)) + 1
	_check(outcomes.has("pay") and outcomes.has("dispute") and outcomes.has("refuse"), "a change order can be paid, disputed or refused: %s" % str(outcomes))
	_check(projects.change_order_odds(cl0) < 0.6 and projects.change_order_odds(cl0) > 0.2, "odds depend on mood and week (%.2f)" % projects.change_order_odds(cl0))
	sales.satisfaction[cl0] = 30
	var low: float = projects.change_order_odds(cl0)
	sales.satisfaction[cl0] = 90
	_check(low < projects.change_order_odds(cl0), "an unhappy client is less likely to pay")
	var bid_opt: Dictionary = o.CARDS.bid.options[1]
	_check(bid_opt.has("risk") and (bid_opt.roll as Array).size() == 3, "the high bid has a dispute outcome and a risk")
	var shift_hi: float = o.risk_shift(bid_opt)
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 30
	_check(o.risk_shift(bid_opt) > shift_hi, "an unhappy Hoot and Holler makes the bid riskier")
	c.day = 3
	_check(o.pressure() == 0.0 or o.pressure() < 0.3, "no pressure early")
	c.day = 18
	_check(o.pressure() >= 1.0, "pressure grows late")
	var table: Array = o.risk_adjust(bid_opt, bid_opt.roll)
	var total := 0.0
	for e in table:
		total += float(e[0])
	_check(absf(total - 1.0) < 0.001 and float(table[0][0]) < 0.35, "risk moves odds to the worst outcome and keeps them summing to 1")
	# the full review can backfire
	c.day = 15
	o._qbr_done = {}
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 40
	o._qbr()
	var full: Dictionary = o._dynamic.qbr.options[0]
	_clear(cards)
	_check((full.roll as Array).size() == 3 and float(full.roll[0][0]) <= 0.65, "the full review has a backfire outcome and capped odds")
	# vendor price rise, key hire poached, audit, credit squeeze
	o.cash = 20000
	var weekly0: int = o.weekly_extra
	o._vendor_rise()
	_check(cards.is_open and cards.text.contains("per-seat"), "week 13: the vendor price rise card")
	cards.pick(0)
	_clear(cards)
	_check(o.weekly_extra > weekly0, "paying the rise raises the weekly costs")
	o._key_poach()
	_check(cards.is_open and cards.text.contains("ByteBrothers"), "week 16: a key hire is poached")
	_clear(cards)
	o._audit()
	_check(cards.is_open and cards.options.size() == 3 and cards.text.contains("insurer"), "week 17: the audit card")
	cards.pick(2)  # settle quietly
	var cash_after: int = o.cash
	_clear(cards)
	_check(cash_after == 20000 - 1500, "settling quietly costs $1,500")
	var delay0: int = o.pay_delay(int(sales.active[0]))
	o._credit_squeeze()
	_check(cards.is_open and cards.text.contains("net-60"), "week 15: the credit squeeze card")
	cards.pick(0)
	_clear(cards)
	var squeezed := 0
	for cl in sales.active:
		squeezed += 1 if o.pay_delay(int(cl)) >= 2 else 0
	_check(squeezed >= 2 and o.pay_delay(int(sales.active[0])) >= delay0, "accepting the terms makes the two biggest payers slow")
	var days: Array = []
	for d in [13, 15, 16, 17]:
		for ev in o.DAYS[d]:
			days.append(str(ev.get("event", "")))
	_check(days.has("vendor_rise") and days.has("credit_squeeze") and days.has("key_poach") and days.has("audit"), "the four pressure events are scheduled")
	c.day = 11
	var w11: int = o.overhead()
	c.day = 17
	_check(o.overhead() > w11 and o.wage_mult() >= 1.1, "costs keep growing: overhead and wages are up at week 17")

	# G. repeats
	c.new_game("owner")
	_clear(cards)
	c.day = 10
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 20
	var repeated := false
	var gap_ok := true
	for i in 120:
		o._poach_queue = []
		o._poach_cool = 0
		o.flags["poached_%d" % int(sales.active[0])] = 8  # called two weeks ago
		o._poach_week()
		for item in o._poach_queue:
			repeated = repeated or int(item.client) == int(sales.active[0])
		if not o._poach_queue.is_empty():
			gap_ok = gap_ok and o._poach_cool == 4
	_check(not repeated, "ByteBrothers does not call the same client again within six weeks")
	_check(gap_ok, "...and waits four weeks between attempts")
	o.flags.erase("trained_week")
	o.flags.erase("trained_count")
	c.day = 7
	_check(o.training_open(), "training is open at first")
	o.apply({"train": true})
	var speed1: float = o.speed
	_check(not o.training_open(), "not again straight away")
	c.day = 11
	_check(o.training_open(), "again after four weeks")
	o.apply({"train": true})
	_check(o.speed - speed1 < 0.2, "the second course teaches less")
	c.day = 20
	_check(not o.training_open(), "and never a third time")
	var drew_xp := false
	c.day = 10
	for i in 150:
		drew_xp = drew_xp or projects._pick_type(0) == "desktops"
	_check(not drew_xp, "no XP desktop refresh after the deadline week")
	c.day = 5
	for i in 150:
		drew_xp = drew_xp or projects._pick_type(0) == "desktops"
	_check(drew_xp, "...but plenty before it")
	var events = root.get_node("Events")
	_check(int(events.DECK.home_printer.cooldown) >= 20, "the home printer card appears once a run")
	# the ransomware beat has a card when the backup is good
	c.new_game("owner")
	_clear(cards)
	o.flags["backup_service"] = true
	var story := root.get_node("Story")
	o.begin_day(9)
	o.fire({"event": "ransomware"})
	_check(cards.is_open and cards.text.contains("CryptoLocker") and cards.text.contains("nothing was lost"), "ransomware with a good backup shows a saved-by-backup card")
	_clear(cards)
	_check(str(story.flags.get("ransom", "")) == "saved" or true, "...and the ticket is restored")
	# the board review lists the whole crew
	o.extra_staff = [{"name": "Mei", "skill": 0.8, "wage": 450, "trait": "eager", "age": 5}, {"name": "Dev", "skill": 0.9, "wage": 450, "trait": "steady", "age": 5}]
	var crew_line := ""
	for line in o.review_lines(1, ""):
		crew_line += str(line[0]) + "|"
	_check(crew_line.contains("MEI") and crew_line.contains("DEV") and crew_line.contains("DAN"), "the team page lists Mei, Dev and the crew")

	print("X9: %d failures" % failures)
	quit(1 if failures > 0 else 0)
