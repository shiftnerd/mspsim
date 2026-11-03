extends SceneTree
# The quote builder screen (C2): the gauge maths (win chance, margin, promise gap against the crew's capacity and the queue, cash over
# four weeks), the steppers by keyboard and mouse, Alan's margin floor and Garrison's 20% sign-off as inline blocks with the owner's
# line, the selling-hours block, sending a quote, and the layout: both halves on a wide screen, paged (fields, then gauges) in
# portrait. Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 60:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


func _hit_ids(comp: Node) -> Array:
	var out := []
	for h in comp._hits:
		out.append(str(h.id))
	return out


func _key(comp: Node, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	comp._input(ev)


func _lead(users := 20, quality := 50) -> Dictionary:
	return {"id": 700, "name": "Test Dental", "type": "dental", "who": "Dr. Test", "users": users, "pain": "x", "quality": quality, "fee": 600, "site": false, "week": 1, "stage": "LEAD", "called": false, "visited": false, "moon": false, "why": "", "touch": 1, "notes": [], "follow": 0}


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var comp := root.get_node("Computer")
	var game := root.get_node("Game")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	var deals = load("res://scripts/deals.gd")
	var qb = load("res://scripts/quote_builder.gd")

	player_script.current_character = "sales_vic"
	game.busy = false
	diff.seed_run(52)
	c.new_game("sales")
	_clear(cards)
	world.clock = 9.0
	msp.tickets = []
	sc.book = []
	sc.plan = "balanced"
	sc.margin_floor = 0.35
	sc.crunch = false
	sc.q_signed = [0, 0]

	# ---- the gauge maths on a known lead (600 a week list, quality 50)
	var l := _lead()
	sc.leads = [l]
	var base := {"method": "fixed", "promise": "std", "price": "list"}
	var g: Dictionary = deals.gauges(l, base)
	_check(absf(float(g.win) - 0.45) < 0.001, "win chance: 0.4 quality + fixed 0.02 + standard SLA 0.03 = 45 percent (%.2f)" % float(g.win))
	_check(absf(float(g.margin) - 0.5) < 0.001 and int(g.price) == 600, "margin 50% and $600 a week at list")
	_check(float(g.gap) == 0.0 and absf(float(g.cap) - 3.0) < 0.001, "an empty queue: capacity 3, a standard promise has no gap")
	_check(int(g.cash4) == 4 * 300 - 100 - 1200, "cash over four weeks: 4 x $300 margin - $100 onboarding - $1,200 commission = %d" % int(g.cash4))
	var high: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "high", "price": "list"})
	_check(absf(float(high.gap) - 1.0) < 0.001 and absf(float(high.win) - 0.56) < 0.001, "a premium SLA: gap 1.0 (4 - 3), win 56 percent")
	var ex: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "std", "price": "list", "extras": ["backup"]})
	_check(int(ex.price) == 710 and absf(float(ex.margin) - (1.0 - 335.0 / 710.0)) < 0.001, "a backup service adds $110 to the fee and its cost to the margin (%.3f)" % float(ex.margin))
	var ex_high: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "high", "price": "list", "extras": ["backup"]})
	_check(float(ex.gap) == 0.0 and absf(float(ex_high.gap) - 1.3) < 0.001 and float(ex.win) < 0.45, "a service that does not fit the pain costs 1.5 points of win chance and adds 0.3 gap once the spare capacity is used up")
	var rush: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "high", "price": "list", "onboard": "rush"})
	var slow: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "high", "price": "list", "onboard": "slow"})
	_check(absf(float(rush.gap) - 1.7) < 0.001 and absf(float(slow.gap) - 0.7) < 0.001 and float(rush.win) > float(slow.win) and float(rush.cash4) < float(slow.cash4), "rush onboarding wins more and costs gap and cash; slow is the reverse")
	var d10: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "std", "price": "list", "discount": 10})
	_check(int(d10.price) == 540 and absf(float(d10.margin) - (1.0 - 0.5 / 0.9)) < 0.001 and absf(float(d10.win) - 0.51) < 0.001, "10% off: $540, margin 44%, win +6 points")
	var legacy: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "std", "price": "d10"})
	_check(int(legacy.price) == 540 and absf(float(legacy.win) - float(d10.win)) < 0.0001, "the old d10 price key still means 10% off")
	_check(float(deals.gauges(l, {"method": "scope", "promise": "std", "price": "list"}).margin) > 0.55, "scoping first protects the margin")

	# ---- capacity from the queue and the crew
	for i in 8:
		msp.tickets.append({"id": 900 + i, "status": "New", "pri": 3, "sla_left": 100.0 + i, "client": 0, "breached": false})
	_check(absf(sc.capacity() - 2.25) < 0.001, "eight open tickets cut the capacity to 2.25 (%.2f)" % sc.capacity())
	var tight: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "high", "price": "list"})
	_check(float(tight.gap) > float(high.gap) + 0.5, "so the same premium promise has a bigger gap (%.1f)" % float(tight.gap))
	var cap_before: float = sc.capacity()
	root.get_node("Owner").extra_staff.append({"name": "Sam", "skill": 0.7, "wage": 450, "trait": "steady", "age": 0})
	_check(sc.capacity() > cap_before + 0.3, "a new hire raises it")
	root.get_node("Owner").extra_staff.clear()
	msp.tickets = []

	# ---- Alan's floor and Garrison's sign-off, inline
	sc.margin_floor = 0.42
	var d20: Dictionary = deals.gauges(l, {"method": "fixed", "promise": "std", "price": "list", "discount": 20})
	_check(not d20.can_send and str(d20.blocks[0].who) == "ALAN" and "42%" in str(d20.blocks[0].text), "Alan blocks 20% off under his floor with his own line")
	sc.margin_floor = 0.35
	var small := _lead(10)
	c.day = 6
	sc.q_signed = [5000, 0]
	d20 = deals.gauges(small, {"method": "fixed", "promise": "std", "price": "list", "discount": 20})
	_check(not d20.can_send and str(d20.blocks[0].who) == "GARRISON" and bool(d20.blocks[0].hard), "ahead of pace Garrison refuses 20% for a small account")
	sc.q_signed = [0, 0]
	d20 = deals.gauges(small, {"method": "fixed", "promise": "std", "price": "list", "discount": 20})
	_check(d20.can_send and str(d20.blocks[0].who) == "GARRISON" and not bool(d20.blocks[0].hard), "behind pace he signs it off, with a line")
	c.day = 1
	sc.q_signed = [0, 0]
	world.clock = 16.5
	var late: Dictionary = deals.gauges(l, base)
	_check(not late.can_send and str(late.blocks[0].who) == "CLOCK", "no selling hours left blocks the quote")
	world.clock = 9.0
	_check(deals.gauges(l, {"method": "fixed", "promise": "high", "price": "list", "extras": ["backup", "security"], "onboard": "rush"}).blocks.any(func(b: Dictionary) -> bool: return str(b.who) == "MORGAN"), "a gap of 1.5+ brings Morgan's warning")

	# ---- the steppers
	sc.leads = [l]
	qb.begin(l)
	_check(sc.crm_view == "build" and qb.ROWS.size() == 8 and int(sc.qb.row) == 0, "begin opens the builder on the first row")
	qb.change("method", 1)
	qb.change("promise", 1)
	qb.change("promise", 1)
	qb.change("discount", 1)
	qb.change("onboard", -1)
	qb.change("backup", 1)
	qb.change("price", 1)
	var q: Dictionary = qb.quote()
	_check(str(q.method) == "scope" and str(q.promise) == "high" and int(q.discount) == 10 and str(q.onboard) == "rush" and q.extras == ["backup"] and str(q.price) == "premium", "steppers: method, SLA tier (clamped), discount, onboarding, a scope toggle, price")
	qb.change("promise", 1)
	qb.change("onboard", -1)
	_check(str(qb.quote().promise) == "high" and str(qb.quote().onboard) == "rush", "the ends stop")
	qb.change("backup", 1)
	_check(qb.quote().extras.is_empty() and qb.value_text("backup") == "OFF" and qb.value_text("promise") == "PREMIUM", "a toggle goes off again and the value text follows")
	qb.close()

	# ---- on screen: wide, keys and mouse
	game.set_format("wide")
	comp.open(1)
	await process_frame
	comp.activate("app:crm")
	sc.start_quote(700)
	await process_frame
	await process_frame
	var ids := _hit_ids(comp)
	_check(sc.crm_view == "build" and "crm:qb:chg:method:1" in ids and "crm:qb:chg:onboard:-1" in ids and "crm:qb:send" in ids and "crm:qb:back" in ids, "wide: the steppers and the gauge side with SEND are on one screen")
	comp.move(2)
	_check(int(sc.qb.row) == 2, "Down moves the row")
	_key(comp, KEY_RIGHT)
	_check(int(qb.quote().discount) == 10, "Right changes the value of that row")
	comp.activate("crm:qb:chg:promise:1")
	_check(str(qb.quote().promise) == "high" and int(sc.qb.row) == 3, "a click on a stepper arrow changes it and selects the row")
	comp.activate("crm:qb:row:5")
	_check(int(sc.qb.row) == 5, "a click on a row selects it")
	comp.activate("crm:qb:page")
	comp.escape()
	_check(sc.crm_view == "list" and comp.app == "crm", "Esc leaves the builder, not the CRM")
	sc.start_quote(700)
	var hours: int = sc.slots_left()
	_key(comp, KEY_S)
	_check(sc.crm_view == "list" and sc.quotes_sent == 1 and sc.slots_left() == hours - 1 and comp._toast.begins_with("QUOTE SENT"), "S sends the quote: an hour spent, the builder closes (%s)" % str(comp._toast))
	_check(str(l.stage) in ["QUOTED", "WON", "LOST"] and not l.promises.is_empty() and float(l.margin) > 0.0, "the deal now carries its quote, promises and margin")
	_clear(cards)

	# a blocked quote cannot be sent
	var l2 := _lead(10)
	l2.id = 701
	sc.leads.append(l2)
	sc.margin_floor = 0.47
	sc.start_quote(701)
	var sent: int = sc.quotes_sent
	qb.change("discount", 1)
	qb.change("discount", 1)
	comp.enter()
	_check(sc.quotes_sent == sent and sc.crm_view == "build" and comp._toast.begins_with("ALAN"), "Enter on a blocked quote says what is blocking it and sends nothing (%s)" % str(comp._toast))
	qb.close()
	sc.margin_floor = 0.35
	comp.close()

	# ---- portrait: paged
	game.set_format("v")
	await process_frame
	comp.open(1)
	await process_frame
	comp.activate("app:crm")
	sc.leads = [l2]
	sc.start_quote(701)
	await process_frame
	await process_frame
	ids = _hit_ids(comp)
	_check(comp._area.size.x < 250.0, "portrait is narrow (%d px)" % int(comp._area.size.x))
	_check(int(sc.qb.page) == 0 and "crm:qb:chg:method:1" in ids and "crm:qb:page" in ids and not ("crm:qb:send" in ids), "page 1: the fields, a GAUGES button and no send yet")
	comp.enter()
	await process_frame
	await process_frame
	ids = _hit_ids(comp)
	_check(int(sc.qb.page) == 1 and "crm:qb:send" in ids and "crm:qb:page" in ids and not ("crm:qb:chg:method:1" in ids), "page 2: the gauges, SEND QUOTE and a way back to the fields")
	_key(comp, KEY_TAB)
	_check(int(sc.qb.page) == 0, "Tab flips the page")
	qb.close()
	comp.close()
	game.set_format("wide")
	c.finish_campaign("test")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
