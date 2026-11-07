extends SceneTree
# gdlint:disable=class-variable-name,function-variable-name,max-line-length
# Week 10 of the sales campaign: a quoted client shops the hardware on a shopping site. Defend the value, match, sell the box only, or let go.

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


func _lead(sc: Node, name: String, fee := 700) -> Dictionary:
	var l: Dictionary = SB.story_lead(name, "law", "Atty. Test", 20, "email goes down every week", 45)
	l["fee"] = fee
	l["stage"] = "QUOTED"
	l["quote"] = {"method": "fixed", "promise": "std", "price": "list", "discount": 0, "extras": [], "onboard": "std"}
	l["quoted_day"] = 1
	sc.leads.append(l)
	return l


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	player_script = load("res://scripts/player.gd")
	SB = load("res://scripts/sales_beats.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	_check(SB.WEEKS.get(10, "") == "shop" and sc.BEAT_TEXT.has("shop"), "week 10 is the shopping beat and has its text")

	_start()
	c.day = 10
	SB.week(10)
	_check(not cards.is_open and sc.flags.shop == "none", "nothing quoted: nothing to shop")
	var l1 := _lead(sc, "Cart Law")
	SB.week(10)
	_check(cards.is_open and str(cards.text).contains("Cart Law") and cards.options.size() == 4, "the card names the client and offers four ways out")
	_pick_id(cards, "match")
	var booked: Array = sc.book.filter(func(d: Dictionary) -> bool: return str(d.name) == "Cart Law")
	_check(booked.size() == 1 and int(booked[0].mrr) == int(round(700 * SB.MATCH_MULT)) and sc.flags.shop == "match", "matching closes at 15 percent off ($%d)" % int(booked[0].mrr if not booked.is_empty() else 0))

	_start()
	c.day = 10
	var l2 := _lead(sc, "Box Law")
	var comm0: int = sc.commission_total
	SB.week(10)
	_pick_id(cards, "box")
	_check(str(l2.stage) == "LOST" and sc.commission_total == comm0 + int(round(700 * SB.BOX_SHARE)) and sc.flags.shop == "box", "the box only: the lead is gone, a one-off commission of $%d" % (sc.commission_total - comm0))

	_start()
	c.day = 10
	var l3 := _lead(sc, "Walk Law")
	SB.week(10)
	_pick_id(cards, "walk")
	_check(str(l3.stage) == "LOST" and sc.flags.shop == "walk", "letting them go loses the lead on purpose")

	_start()
	c.day = 10
	var l4 := _lead(sc, "Value Law")
	SB.week(10)
	_pick_id(cards, "defend")
	_check(str(l4.stage) in ["WON", "LOST"] and sc.flags.shop == "defend", "defending the value is a seeded roll (%s)" % str(l4.stage))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
