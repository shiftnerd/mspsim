extends SceneTree
# gdlint:disable=max-line-length
# X13, the owner campaign findings of the bot runs:
#   1  the scammed-client card names its prices; a thin bank pays the credit as a dated bill (never greyed, never bankrupt)
#   2  dated bills: equal weekly parts at the close, a row on the report, counted against the company value
#   3  the desk's capacity is said out loud: a SERVICE DESK row on the weekly report, Morgan's card after two bad weeks
#   5  the inbound lead: ten stories, each once a run, then John takes the meeting without a card
#   6  the company value has a floor from recurring revenue (it read $0 while the profit was negative)
# (card_costs.gd scans every card for unnamed costs; determinism.gd covers the order of owner seeds.)
#   Godot --headless --path godot -s res://tests/x13_owner.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


func _start(c: Node, cards: Node, day: int) -> void:
	c.new_game("owner")
	_clear(cards)
	c.day = day


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	var proj := root.get_node("Projects")
	var msp := root.get_node("Msp")
	var inc: Script = load("res://scripts/incident.gd")
	var ops: Script = load("res://scripts/owner_ops.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Difficulty").seed_run(1313)

	# ---- 1. the scammed client: prices on the answers
	_start(c, cards, 14)
	var victim: int = int(sales.active[0])
	o.flags["bec_client"] = victim
	o.flags["bec_amount"] = 10000
	o.cash = 7500
	o.show_card("bec_loss")
	var l0 := str(cards.options[0].label)
	var l1 := str(cards.options[1].label)
	var l2 := str(cards.options[2].label)
	_check(l0.contains("$4,000") and bool(cards.options[0].get("enabled", true)), "the credit names its price: " + l0)
	_check(l1.contains("$600") and l1.contains("RISK $5,600"), "the lawyer names his fee and the settlement he can lose: " + l1)
	_check(l2.contains("$800") and l2.contains("$4,000"), "the insurer names the deductible and the uncovered sum: " + l2)
	_check(not str(cards.options[3].label).contains("$"), "blaming the client costs no money and says none")
	cards.pick(0)
	_clear(cards)
	_check(o.cash == 3500 and ops.bills_left() == 0, "a bank that can pay the credit pays it at once (%d)" % o.cash)

	# a thin bank: the honest answer stays open and becomes a dated bill
	_start(c, cards, 14)
	victim = int(sales.active[0])
	o.flags["bec_client"] = victim
	o.flags["bec_amount"] = 10000
	o.cash = 1033
	o.show_card("bec_loss")
	_check(bool(cards.options[0].get("enabled", true)) and str(cards.options[0].label).contains("OVER 8 WEEKS") and str(cards.options[0].label).contains("$4,000"), "with $1,033 the credit is still open, as a bill over 8 weeks: " + str(cards.options[0].label))
	_check(bool(cards.options[1].get("enabled", true)), "the lawyer ($600) is affordable too")
	cards.pick(0)
	_clear(cards)
	_check(o.cash == 1033 and ops.bills_left() == 4000, "nothing leaves the bank today; $4,000 is on a dated bill (%d left)" % ops.bills_left())
	_check(proj.has_service(victim, "mailfilter"), "they sign for the email filter all the same")
	var with_bill: int = o.valuation()
	var kept: Array = o.flags.bills
	o.flags["bills"] = []
	var without_bill: int = o.valuation()
	o.flags["bills"] = kept
	_check(without_bill - with_bill == 4000, "the bill counts against the company value (%d with it, %d without)" % [with_bill, without_bill])
	var paid: int = ops.pay_bills()
	_check(paid == 500 and o.cash == 533 and ops.bills_left() == 3500, "a close pays one part of eight ($%d)" % paid)
	for i in 7:
		ops.pay_bills()
	_check(ops.bills_left() == 0 and ops.bills().is_empty() and ops.pay_bills() == 0, "after eight closes the bill is gone")

	# the report shows it, and a thin week is survivable where the old credit was the end
	_start(c, cards, 15)
	o.cash = 1033
	o.pay_or_bill("CREDIT NOTE", 2200)
	var rep: Dictionary = o.settle()
	var row_text := ""
	for row in rep.rows:
		if str(row[0]) == "DATED BILLS":
			row_text = str(row[1])
	_check(row_text.contains("-$275 THIS WEEK") and row_text.contains("$1925 LEFT"), "the weekly report has a DATED BILLS row: " + row_text)
	_check(not bool(rep.bankrupt), "the week 15 of the bot's bankruptcy ($1,033 in the bank, a $2,200 credit) ends alive (cash %d)" % o.cash)
	_clear(cards)

	# the gambles of the same card bill what the bank cannot carry
	var worst := 0
	for i in 40:
		_start(c, cards, 14)
		o.flags["bec_client"] = int(sales.active[0])
		o.flags["bec_amount"] = 10000
		o.cash = 700
		inc.owner_fx("claim" if i % 2 == 0 else "lawyer")
		worst = maxi(worst, 700 - o.cash)
		_clear(cards)
	_check(worst == 0, "a lost claim or a lost case never takes more than the bank holds at once (took %d of $700)" % worst)

	# the lawsuit after lost files (found by card_costs.gd): an empty bank was left with FIGHT IT alone
	_start(c, cards, 12)
	o.cash = 300
	var rep_before: int = c.rep
	o.show_card("ransom_lost")
	_check(bool(cards.options[0].get("enabled", true)) and str(cards.options[0].label) == "SETTLE ($2,500 OVER 8 WEEKS)" and str(cards.options[1].label).contains("RISK $6,000"), "the lawsuit with $300: settling stays open, in parts: %s / %s" % [str(cards.options[0].label), str(cards.options[1].label)])
	cards.pick(0)
	_clear(cards)
	_check(o.cash == 300 and ops.bills_left() == 2500 and c.rep == rep_before - 3, "settled: nothing today, $2,500 on a dated bill, the reputation cost as before")
	_start(c, cards, 12)
	o.cash = 5000
	o.show_card("ransom_lost")
	_check(str(cards.options[0].label) == "SETTLE ($2,500)", "a bank that can pay settles at once")
	cards.pick(0)
	_clear(cards)
	_check(o.cash == 2500 and ops.bills_left() == 0, "and pays at once")

	# ---- the label rules of every owner option
	var lab: String = ops.label({"label": "FIGHT IT", "roll": [[0.5, {"rep": -3}, ""], [0.5, {"cash": -6000}, ""]]}, [0, 6000])
	_check(lab == "FIGHT IT (RISK $6,000)", "a gamble for money names its stake: " + lab)
	lab = ops.label({"label": "CLOSE EVERY LOGIN NOW", "fx": {"cash": -1500}}, [1500, 1500])
	_check(lab == "CLOSE EVERY LOGIN NOW ($1,500)", "a sure cost the words do not name is added: " + lab)
	lab = ops.label({"label": "BUY IT ($600)", "fx": {"cash": -600}}, [600, 600])
	_check(lab == "BUY IT ($600)", "a label that names its price is left alone")
	var cost: Array = ops.cost({"label": "X", "roll": [[0.5, {"cash": -900}, ""], [0.5, {"cash": -2400}, ""]]})
	_check(int(cost[0]) == 900 and int(cost[1]) == 2400, "option_cost of a roll is the least and the most (%s)" % str(cost))

	# ---- 3. the desk on the weekly report
	_start(c, cards, 6)
	_check(ops.desk_over(4, 2, 0, 5) and not ops.desk_over(10, 1, 0, 3), "over capacity = the loose ends outweigh the closes")
	var r := {"closed": 4, "missed": 2, "reopened": 0, "open_left": 5, "rows": [["CASH", "$1", Color.WHITE], ["OWNER HOURS", "x", Color.WHITE], ["VALUE", "y", Color.WHITE]]}
	ops.desk_week(r)
	_check(str(r.rows[1][0]) == "DESK OVER CAPACITY" and str(r.rows[1][1]) == "4 CLOSED, 2 MISSED, 5 OPEN" and str(r.rows[2][0]) == "OWNER HOURS", "a bad week: DESK OVER CAPACITY above the owner's hours: %s" % str(r.rows[1]))
	o._desk_morning()
	_check(not cards.is_open, "one bad week: no card yet")
	r = {"closed": 5, "missed": 3, "reopened": 0, "open_left": 6, "rows": []}
	ops.desk_week(r)
	o._desk_morning()
	_check(cards.is_open and cards.text.contains("closed 5 tickets, missed 3 and left 6 open") and cards.text.contains("reputation"), "two bad weeks in a row: Morgan says it with the numbers: " + cards.text)
	_check(str(cards.options[0].label) == "SEE HIRING CANDIDATES", "the first answer is hiring")
	cards.pick(0)
	_check(cards.is_open and cards.text.contains("candidates"), "and it opens the candidates")
	var staff0: int = o.extra_staff.size()
	cards.pick(0)
	_clear(cards)
	_check(o.extra_staff.size() == staff0 + 1, "a hire joins")
	c.day = 7
	ops.desk_week({"closed": 5, "missed": 3, "reopened": 0, "open_left": 6, "rows": []})
	o._desk_morning()
	_check(not cards.is_open, "not again within four weeks")
	c.day = 10
	o._desk_morning()
	_check(cards.is_open and cards.text.begins_with("Still under water"), "four weeks on, still over: the second card has other words")
	_clear(cards, 9)
	c.day = 16
	ops.desk_week({"closed": 5, "missed": 3, "reopened": 0, "open_left": 6, "rows": []})
	o._desk_morning()
	_check(not cards.is_open, "at most twice in a run")
	r = {"closed": 12, "missed": 0, "reopened": 0, "open_left": 2, "rows": []}
	ops.desk_week(r)
	_check(str(r.rows[0][0]) == "SERVICE DESK" and int(o.flags.desk_over) == 0, "a good week: SERVICE DESK, and the count starts again")
	# through the real week close
	_start(c, cards, 4)
	c._end_day()
	var has_desk := false
	for row in root.get_node("DayReport").report.get("rows", []):
		has_desk = has_desk or str(row[0]) in ["SERVICE DESK", "DESK OVER CAPACITY"]
	_check(has_desk, "the owner's weekly report carries the desk row")
	root.get_node("DayReport").finish()
	await create_timer(0.8).timeout
	root.get_node("Game").busy = false
	_clear(cards)

	# ---- 5. the inbound lead: ten stories, each once
	_start(c, cards, 10)
	var texts := []
	var keys := {}
	var rx := RegEx.new()
	rx.compile("[0-9$%]+")
	var shown := 0
	for i in ops.LEADS.size() + 3:
		for cl in sales.active.duplicate():  # keep room: the lead needs somebody who is not a client yet
			if sales.active.size() > 5:
				sales.active.erase(cl)
		o._inbound_lead()
		if cards.is_open:
			shown += 1
			var body := str(cards.text)
			for cl in msp.CLIENTS.size():
				body = body.replace(str(msp.CLIENTS[cl].name), "NAME")
			texts.append(body)
			keys[rx.sub(body, "#", true).substr(0, 34)] = true
			_check(cards.options.size() >= 2 and str(cards.options[0].label).begins_with("TAKE THE MEETING YOURSELF (") and str(cards.options[1].label).begins_with("LET JOHN CLOSE IT ("), "lead %d has the two closers: %s" % [i, body.substr(0, 40)])
			_clear(cards, 9)
	_check(shown == ops.LEADS.size(), "%d lead cards for %d stories; after that John takes the meeting without a card" % [shown, ops.LEADS.size()])
	_check(keys.size() == ops.LEADS.size(), "no lead text comes twice in a run (%d different openings)" % keys.size())
	_check(texts[0].begins_with("An inbound lead from our marketing"), "the plain lead comes first")
	_check(ops.LEADS.size() >= 8, "at least eight stories")
	var sizes := {}
	var catches := {}
	for story in ops.LEADS:
		sizes[float(story.get("fee", 1.0))] = true
		catches[str(story.get("catch", ""))] = true
		_check(str(story.text).count("%s") == 1, "story %s names the prospect once" % str(story.id))
	_check(sizes.size() >= 4 and catches.size() >= 4, "the stories differ in size (%d fees) and in their catch (%d kinds)" % [sizes.size(), catches.size()])
	_check(ops.lead_catch("discount", 3).has("discount_new") and ops.lead_catch("slow", 3).squeeze == [3] and ops.lead_catch("", 3).is_empty(), "the catches are real effects")
	# a story's size and catch reach the signed client
	_start(c, cards, 10)
	o.flags["leads_seen"] = []
	for story in ops.LEADS:
		if str(story.id) != "growing":
			o.flags.leads_seen.append(str(story.id))
	o._inbound_lead()
	var data: Dictionary = o._dynamic["lead"]
	var own_fx: Dictionary = data.options[0].roll[0][1]
	var john_fx: Dictionary = data.options[1].roll[0][1]
	_check(is_equal_approx(float(own_fx.sign_bonus.fee), 1.32) and is_equal_approx(float(john_fx.sign_bonus.fee), 1.2) and int(own_fx.burnout) == 3, "the growing office: fee x1.2 (x1.32 if you close it) and a heavy onboarding")
	_clear(cards, 9)
	var keys_file := {}
	for e in root.get_node("Strings").entries():
		keys_file[str(e.key)] = true
	_check(keys_file.has("OwnerOps.LEADS.1.text") and keys_file.has("OwnerOps.LEADS.3.won"), "the lead stories are in the strings workflow")

	# ---- 6. the company value while the profit is negative
	_start(c, cards, 8)
	o.cash = 1200
	o.history = []
	for i in 4:
		o.history.append({"day": 4 + i, "profit": -400, "ebitda": -400, "cash": 1200})
	var est: Dictionary = o.weekly_estimate()
	var v: int = o.valuation()
	var book := int(float(est.revenue) * 52.0 * o.VALUE_FLOOR * o.quality() * clampf(0.5 + 8.0 / 24.0, 0.5, 1.0))
	_check(v == book + 1200 and v > 20000, "four losing weeks: the value is the contracts' (%d), not $0" % v)
	_check(o._value_on_book() and o.value_text() == "$%d (CONTRACTS)" % v, "and the text says so: " + o.value_text())
	o.history = []
	for i in 4:
		o.history.append({"day": 4 + i, "profit": 1500, "ebitda": 1500, "cash": 1200})
	var earned := int(1500.0 * 52.0 * o.multiple() * o.quality() * clampf(0.5 + 8.0 / 24.0, 0.5, 1.0))
	_check(not o._value_on_book() and o.valuation() == earned + 1200 and o.value_text().ends_with("X)"), "a profitable company is valued on its earnings as before (%d)" % o.valuation())
	_check(earned > book, "and the earnings give more than the floor (%d vs %d)" % [earned, book])

	c.quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
