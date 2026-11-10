extends SceneTree
# gdlint:disable=class-variable-name,function-variable-name,max-line-length
# R38: the sales intro-rate temptation (week 12). A prospect would sign today for a cheap first quarter: put the step to list price on
# page one (honest), hide it in the small print (the deal closes now, a lie, a dated bill with a clawback) or hold the list price.

var failures := 0
var player_script: GDScript
var SB: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		var idx := 0
		for i in cards.options.size():
			if bool(cards.options[i].get("enabled", true)):
				idx = i
				break
		cards.pick(idx)
		n += 1


func _pick_id(cards: Node, id: String) -> void:
	for i in cards.options.size():
		if str(cards.options[i].get("id", "")) == id:
			cards.pick(i)
			_clear(cards)
			return


func _start() -> void:
	player_script.current_character = "office_john"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(4242)
	root.get_node("Campaign").new_game("sales")
	_clear(root.get_node("Cards"))


func _lead(sc: Node, name: String, fee := 700, stage := "QUOTED") -> Dictionary:
	var l: Dictionary = SB.story_lead(name, "law", "Atty. Test", 20, "email goes down every week", 45)
	l["fee"] = fee
	l["stage"] = stage
	if stage == "QUOTED":
		l["quote"] = {"method": "fixed", "promise": "std", "price": "list", "discount": 0, "extras": [], "onboard": "std"}
		l["quoted_day"] = 1
	sc.leads.append(l)
	return l


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var o := root.get_node("Owner")
	player_script = load("res://scripts/player.gd")
	SB = load("res://scripts/sales_beats.gd")
	var sr: Script = load("res://scripts/sales_rival.gd")
	var tp: Script = load("res://scripts/temptation.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	_check(sr.WEEKS.get(12, "") == "intro" and sc.BEAT_TEXT.has("intro") and sr.BILLS.has("intro"), "week 12 is the intro-rate beat, with its text and its bill")

	# ---- nothing to sell to: no card
	_start()
	c.day = 12
	for l in sc.leads:
		l.stage = "LOST"
	sr.beat_intro()
	_check(not cards.is_open and sc.flags.intro == "none", "no open lead: no card")

	# ---- the small print: the deal closes now at the full fee, a lie with a dated bill
	_start()
	c.day = 12
	var l1 := _lead(sc, "Grey Print Law")
	var consc0: int = tp.consc()
	var lies0: int = sr.lies()
	sr.week(12)
	_check(cards.is_open and str(cards.text).contains("Grey Print Law") and cards.options.size() == 3, "the card names the prospect and has three options")
	_check(str(cards.options[0].id) == "pageone", "the honest answer is the first option")
	_pick_id(cards, "smallprint")
	var booked: Array = sc.book.filter(func(d: Dictionary) -> bool: return str(d.name) == "Grey Print Law")
	_check(booked.size() == 1 and int(booked[0].mrr) == 700, "the small print closes the deal at the full fee")
	_check(bool(l1.get("lie", false)) and tp.consc() == consc0 - 2 and sr.lies() == lies0 + 1, "it is a lie on the record and the conscience falls")
	var open: Array = sr.open_bills()
	_check(open.size() == 1 and str(open[0].kind) == "intro" and int(open[0].due) >= 15 and int(open[0].due) <= 17, "a bill is in the folder for week 15 to 17 (%d)" % (int(open[0].due) if not open.is_empty() else -1))
	_check(sc.flags.intro == "smallprint", "the flag remembers the choice")
	var d1: Dictionary = booked[0] if not booked.is_empty() else {}
	var mood0 := int(d1.get("mood", 0))
	var churn0 := int(d1.get("churn", 10))
	var com0: int = sc.commission_total
	var claw := int(round(float(d1.get("commission", 0)) * 2.0))
	c.day = int(open[0].due)
	sr.bills_week(c.day)
	_check(cards.is_open and str(cards.text).contains("SMALL PRINT"), "the bill card says the intro rate ended")
	_clear(cards)
	_check(int(d1.get("mood", 0)) == mood0 - 10 and int(d1.get("churn", 0)) == churn0 + 10, "the client is 10 mood down and 10 churn up")
	_check(claw > 0 and sc.commission_total == com0 - claw and sr.open_bills().is_empty(), "the commission comes back twice over (-$%d)" % claw)

	# ---- page one: no lie, a small edge, the conscience rises
	_start()
	c.day = 12
	var l2 := _lead(sc, "Page One Law")
	var consc2: int = tp.consc()
	sr.week(12)
	_pick_id(cards, "pageone")
	_check(not bool(l2.get("lie", false)) and absf(float(l2.get("pts", 0.0)) - sr.INTRO_PTS) < 0.001 and sr.open_bills().is_empty(), "page one: no lie, no bill, +%d win points" % int(sr.INTRO_PTS * 100))
	_check(tp.consc() >= consc2 and str(l2.stage) == "QUOTED", "the conscience does not fall and the deal is still open")
	_check(o.skel.is_empty(), "Christy's folder is empty")

	# ---- holding the price costs a selling hour
	_start()
	c.day = 12
	var l3 := _lead(sc, "List Price Law")
	var slots0: int = sc.slots_left()
	sr.week(12)
	_pick_id(cards, "hold")
	_check(sc.slots_left() == slots0 - 1 and absf(float(l3.get("pts", 0.0)) - sr.HOLD_PTS) < 0.001 and not bool(l3.get("lie", false)), "holding the price takes an hour and is no lie")

	# ---- a lead that is not quoted yet: the small print is a lie and a head start, no instant close
	_start()
	c.day = 12
	for l in sc.leads:
		l.stage = "LOST"
	var l4 := _lead(sc, "Early Law", 600, "MEETING")
	sr.week(12)
	_pick_id(cards, "smallprint")
	_check(bool(l4.get("lie", false)) and absf(float(l4.get("pts", 0.0)) - sr.INTRO_FAST) < 0.001 and str(l4.stage) == "MEETING", "not quoted yet: a lie and +%d points, no instant close" % int(sr.INTRO_FAST * 100))

	# ---- an honest ASSESS list goes on the rival's rap sheet
	_start()
	var rv: Script = load("res://scripts/rival.gd")
	var l5 := _lead(sc, "Sheet Law", 600, "MEETING")
	l5["incumbent"] = "bigcheese"
	l5["findings"] = ["R02", "R04"]
	_check(rv.rap("bigcheese", "R02") == rv.UNKNOWN, "nothing known about the rival yet")
	sr.assess_pick(l5, "honest")
	_check(rv.rap("bigcheese", "R02") == rv.SEEN and rv.rap("bigcheese", "R04") == rv.SEEN, "the honest list is SEEN evidence on the rap sheet")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
