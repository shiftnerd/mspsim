extends SceneTree
# gdlint:disable=max-line-length
# R38 sales twins: a sales lie also goes in the folder (Owner.skel, class "sales") and its bill lands on the deal weeks later: mood and
# churn, a reputation hit, or (a laundered lead) the client leaves. An open deal waits, one that never closes drops out. COME CLEAN costs
# commission and clears the lie flag; the open folder counts in Summit's diligence. Headless; saves in user://test_*.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 60:
		cards.pick(0)
		n += 1


func _lead(id: int) -> Dictionary:
	return {
		"id": id, "name": "Twin Dental %d" % id, "type": "dental", "who": "Dr. Twin", "users": 20, "pain": "x", "quality": 50,
		"fee": 600, "site": false, "week": 1, "stage": "MEETING", "called": true, "visited": false, "moon": false, "why": "",
		"touch": 1, "notes": [], "follow": 0, "incumbent": "none", "inc_seen": true
	}


func _deal(sc: Node, l: Dictionary) -> Dictionary:
	var deals = load("res://scripts/deals.gd")
	var handover = load("res://scripts/handover.gd")
	var d: Dictionary = sc.close_deal(l, deals.norm({"method": "fixed", "promise": "std", "price": "list"}))
	sc.pending_handover = 0
	sc.handover_queue = []
	handover.decide_all(d, "kept")
	handover.finish(d, false)
	return d


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var o := root.get_node("Owner")
	var diff := root.get_node("Difficulty")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	var sr = load("res://scripts/sales_rival.gd")
	var tp = load("res://scripts/temptation.gd")
	diff.seed_run(91)
	c.new_game("sales")
	_clear(cards)
	world.clock = 9.0
	msp.tickets = []
	sc.book = []
	sc.leads = []
	sc.q_signed = [0, 0]
	c.day = 6

	# ---- a lie seeds one folder entry with the lead's name
	var lf := _lead(81)
	var consc0: int = tp.consc()
	sr.mark_lie(lf, "MATCHED THE FLAT PRICE", "flat")
	var open: Array = sr.open_bills()
	_check(open.size() == 1 and str(open[0].lead) == str(lf.name) and str(open[0]["class"]) == "sales", "a flat-price lie puts one sales entry in the folder")
	_check(int(open[0].due) >= c.day + 3 and int(open[0].due) <= c.day + 5, "its date is inside the range (week %d)" % int(open[0].due))
	_check(tp.consc() == consc0 - 2 and tp.folder_count() == 1, "the conscience falls by two and the folder counts it")
	sr.mark_lie(lf, "MATCHED THE FLAT PRICE", "flat")
	_check(sr.open_bills().size() == 1, "one of each kind per lead")

	# ---- the bill lands on the deal
	var df := _deal(sc, lf)
	_clear(cards)
	var mood0: int = int(df.mood)
	var churn0: int = int(df.get("churn", 10))
	var com_f: int = sc.commission_total
	var claw_f := int(round(float(df.get("commission", 0)) * 2.0))
	c.day = int(open[0].due) - 1
	sr.bills_week(c.day)
	_check(sr.open_bills().size() == 1, "not before its week")
	c.day = int(open[0].due)
	sr.bills_week(c.day)
	_check(sr.open_bills().is_empty() and int(df.mood) == mood0 - 8 and int(df.churn) == churn0 + 6, "in its week the client is %d mood down and %d churn up" % [8, 6])
	_check(cards.is_open and cards.text.contains("A BILL FROM THE FOLDER"), "a card says so")
	_check(claw_f > 0 and sc.commission_total == com_f - claw_f, "and the commission comes back with a penalty (-$%d)" % claw_f)
	_clear(cards)

	# ---- a laundered lead: the client leaves
	var ll := _lead(82)
	sr.mark_lie(ll, "TOOK A LAUNDERED LEAD", "launder")
	var dl := _deal(sc, ll)
	_clear(cards)
	var claw0: int = sc.clawbacks
	var rep0: int = c.rep
	c.day += 12
	sr.bills_week(c.day)
	_clear(cards)
	_check(not sc.book.has(dl) and sc.clawbacks == claw0 + 1 and c.rep < rep0, "the laundered client leaves, the commission is clawed back and the rep falls")

	# ---- an open lead waits; one that never closes drops out
	var lo := _lead(83)
	sc.leads.append(lo)
	sr.mark_lie(lo, "UNDERCUT PLUMB LINE", "undercut")
	var due: int = int(sr.open_bills()[0].due)
	c.day = due + 1
	sr.bills_week(c.day)
	_check(sr.open_bills().size() == 1, "an open deal keeps its entry waiting")
	c.day = due + sr.BILL_PATIENCE + 1
	sr.bills_week(c.day)
	_check(sr.open_bills().is_empty(), "a deal that never closes drops out")

	# ---- COME CLEAN: costs commission, clears the lie, raises the conscience
	c.day = 20
	var lc := _lead(84)
	lc.lie = true
	sc.leads.append(lc)
	sr.mark_lie(lc, "TOLD THEM IT LOOKS FINE", "cheap")
	var id := "cheap:" + str(lc.name)
	var cost: int = tp.clean_cost(id)
	var com0: int = sc.commission_total
	var consc1: int = tp.consc()
	_check(cost >= 50 and sr.come_clean_sales(id), "coming clean is possible and costs $%d" % cost)
	_check(sc.commission_total == com0 - cost and not bool(lc.lie) and tp.consc() == consc1 + 1 and sr.open_bills().is_empty(), "the commission pays, the lie flag is cleared, the conscience rises, the folder is empty")

	# ---- the offer comes from the second entry, once in four weeks
	var l1 := _lead(85)
	var l2 := _lead(86)
	sr.mark_lie(l1, "MATCHED THE FLAT PRICE", "flat")
	sr.mark_lie(l2, "TOOK A LAUNDERED LEAD", "launder")
	sr.clean_offer(c.day)
	_check(cards.is_open and cards.options.size() >= 2 and cards.text.contains("2 deals"), "Garrison offers to phone the clients with two entries open")
	_clear(cards)
	sr.clean_offer(c.day + 1)
	_check(not cards.is_open, "and not again the next week")

	# ---- Summit's diligence counts the folder
	var base: int = sc.SalesBeats.diligence_score()
	sr.mark_lie(_lead(87), "UNDERCUT PLUMB LINE", "undercut")
	_check(sc.SalesBeats.diligence_score() == base + 1, "each open entry adds one to the diligence score")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
