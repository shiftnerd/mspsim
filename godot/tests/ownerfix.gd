extends SceneTree
# Owner play-through fixes: the clock waits for cards and outings, the final week settles once,
# project payouts in the valuation history, Vic's install is a job, the named prospect, the phone.

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


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var msp := root.get_node("Msp")
	var report := root.get_node("DayReport")
	var outings := root.get_node("Outings")
	var projects := root.get_node("Projects")
	var phone := root.get_node("Phone")
	var game := root.get_node("Game")
	game.title_mode = false
	c.save_prefix = "user://test_ownerfix_%d_" % OS.get_process_id()

	# 1. a card freezes the day clock and the report waits for it
	c.new_game("owner")
	_clear(cards)
	world.clock = 10.0
	cards.ask("Test", "A decision", [{"label": "OK", "id": "a"}], func(_p: String) -> void: pass)
	var before: float = world.clock
	for i in 30:
		await process_frame
	_check(is_equal_approx(world.clock, before), "the day clock waits while a card is open")
	world.clock = world.DAY_END
	for i in 10:
		await process_frame
	_check(not report.is_open, "no weekly report while a card is open")
	cards.pick(0)
	for i in 10:
		await process_frame
	_check(report.is_open, "the report opens once the card is answered")
	# a card asked while the report is up waits behind it
	cards.ask("Test", "Late card", [{"label": "OK", "id": "a"}], func(_p: String) -> void: pass)
	_check(not cards.is_open, "a card asked behind the report is queued")
	report.finish()
	await create_timer(0.7).timeout
	game.busy = false
	var seen_late := false
	var guard := 0
	while cards.is_open and guard < 20:
		seen_late = seen_late or cards.text == "Late card"  # new-week cards may come first
		cards.pick(0)
		guard += 1
	_check(seen_late, "the queued card shows after the report")

	# an outing in progress also holds the report back
	c.new_game("owner")
	_clear(cards)
	outings._wait_id = "bowling"
	_check(outings.busy(), "travelling to an outing counts as busy")
	world.clock = world.DAY_END
	for i in 10:
		await process_frame
	_check(not report.is_open, "no report while an outing is under way")
	outings._wait_id = ""

	# 2. the final week settles once
	c.new_game("owner")
	_clear(cards)
	c.day = 20
	world.clock = world.DAY_END
	for i in 10:
		await process_frame
	_check(report.is_open and report.report.get("final", false), "week 20 report")
	var cash_after: int = o.cash
	var hist: int = c.history.size()
	var rep_after: int = c.rep
	report.finish()
	for i in 90:
		await process_frame
	_check(c.history.size() == hist and o.cash == cash_after, "week 20 settles only once (cash)")
	_check(c.rep == rep_after and not report.is_open, "week 20 settles only once (report, rep)")

	# 3. project payouts: profit and EBITDA history agree
	c.new_game("owner")
	_clear(cards)
	projects.reset()
	projects.projects = [
		{
			"id": 1,
			"client": 0,
			"type": "network",
			"method": "fixed",
			"price": 4000,
			"hw": 0,
			"est": 10.0,
			"done": 0.0,
			"weeks": 1,
			"total": 1,
			"creep": false,
			"scoped": false,
			"delay": 0,
			"status": "active",
			"net": 0,
			"profit": 0,
		}
	]
	var est: Dictionary = o.weekly_estimate()
	var books: Dictionary = o.settle()
	var h: Dictionary = o.history[o.history.size() - 1]
	_check(int(books.profit) >= int(est.ebitda) + 3500, "the payout is inside the week's profit")
	_check(
		absi(int(h.ebitda) - int(est.ebitda)) <= 5,
		"history EBITDA is the recurring EBITDA (%d vs %d)" % [int(h.ebitda), int(est.ebitda)]
	)
	_clear(cards)

	# 4. Vic's sold install is a job, not a dead ticket, and never blocks the next sale
	c.new_game("owner")
	var tickets_before: int = msp.tickets.size()
	var cash0: int = o.cash
	var first: int = sales.sell_install()
	var second: int = sales.sell_install()
	_check(first >= 0 and second >= 0, "install sales are never blocked")
	_check(msp.tickets.size() == tickets_before and not msp.project_busy(), "no dead install ticket")
	_check(o.cash > cash0, "the install pays the company")

	# 5. the prospect card names a client who is not signed yet, and the discount applies
	c.new_game("owner")
	_clear(cards)
	sales.active = [0, 1, 2, 3, 4]
	o._prospect_card()
	_check(cards.is_open, "the prospect card opens")
	var named := -1
	for i in msp.CLIENTS.size():
		if not sales.active.has(i) and cards.text.contains(str(msp.CLIENTS[i].name)):
			named = i
	_check(named >= 0, "the card names a prospect: " + cards.text.left(40))
	cards.pick(0)
	_check(sales.active.has(named), "the named prospect is the client who signs")
	_check(o.discount.has(named) and int(o.discount[named].weeks) == 6, "20%% off for 6 weeks")
	var full := int(float(o.FEE) * o.price)
	_check(o.client_fee(named) == int(full * 0.8), "the discounted fee is 80%%")
	_clear(cards)

	# 6. phone: keyboard selection on the home screen
	phone.os = "ios"
	phone.app = "home"
	phone.home_sel = 0
	phone.home_move(1)
	phone.move(1)
	_check(phone.home_sel == 3, "arrows move the home selection")
	phone.home_sel = 2
	phone.enter()
	_check(phone.app == "texts", "Enter opens the selected app")
	phone.back()
	_check(phone.app == "home", "Esc goes back to the home screen")

	# the lead / pitch uses the client's own name at the site
	var on := root.get_node("Onsite")
	_check(on._host_prefix(5, "b") == str(msp.CLIENTS[5].short), "the prospect site uses the client name")
	_check(on._owner_name(5) == str(msp.CLIENTS[5].contact), "and the client's contact")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
