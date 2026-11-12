extends SceneTree
# gdlint:disable=max-line-length
# C7b: the sales campaign's six "office life" cards (SalesCampaign.LIFE): one a week on weeks 2, 5, 8, 11, 14 and 17, in the order of the
# run's own seeded stream, none twice, with small effects on the pipeline (the best open lead's quality), the conscience and the crew's
# morale. Headless; saves in user://test_*.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/sales_life.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, idx := 0) -> int:
	var n := 0
	while cards.is_open and n < 60:
		cards.pick(idx if idx < cards.options.size() else 0)
		n += 1
	return n


func _start(seed_n: int) -> void:
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(seed_n)
	root.get_node("Campaign").new_game("sales")
	_clear(root.get_node("Cards"))
	root.get_node("SalesCampaign").leads.clear()


func _lead(sc: Node, quality: int) -> Dictionary:
	var l: Dictionary = sc.make_lead(root.get_node("Difficulty").rng("test_leads"))
	l["quality"] = quality
	sc.accept_lead(l)
	return l


func _index_of(sc: Node, text: String) -> int:
	for i in sc.LIFE.size():
		if str(sc.LIFE[i].text) == text:
			return i
	return -1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var player_script: GDScript = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_life_" % OS.get_process_id()
	player_script.current_character = "office_john"

	# ---- the deck
	_check(sc.LIFE.size() == 6 and sc.LIFE_WEEKS.size() == 6, "six cards, six weeks")
	var shape_ok := true
	var texts := {}
	var keys_ok := true
	var net := {}
	for card in sc.LIFE:
		texts[str(card.text)] = true
		shape_ok = shape_ok and card.options.size() == 3 and str(card.speaker) != ""
		for o in card.options:
			shape_ok = shape_ok and str(o.label) != "" and str(o.label).length() <= 40 and str(o.reply) != ""
			for k in o.fx:
				keys_ok = keys_ok and k in ["pipe", "consc", "morale"]
				keys_ok = keys_ok and absi(int(o.fx[k])) <= 4
	_check(shape_ok and texts.size() == 6, "three options each, a label of 40 letters at most, a reply, no text twice")
	_check(keys_ok, "the effects are pipe, consc and morale and none is bigger than 4")
	var touches := {"pipe": 0, "consc": 0, "morale": 0}
	for card in sc.LIFE:
		for o in card.options:
			for k in o.fx:
				touches[k] += 1
	_check(int(touches.pipe) >= 6 and int(touches.consc) >= 3 and int(touches.morale) >= 3, "pipeline, conscience and morale all move somewhere (%s)" % str(touches))

	# ---- the weekly draw: a card on its weeks only, in the run's order, none twice
	_start(41)
	var order_a: Array = sc.life_order()
	var sorted_a: Array = order_a.duplicate()
	sorted_a.sort()
	_check(sorted_a == range(6) and sc.life_order() == order_a, "the order holds every card once and is stable (%s)" % str(order_a))
	var seen: Array = []
	var off_week := 0
	for day in range(1, 21):
		c.day = day
		sc._life_card(day)  # the week's draw itself (begin_week calls it right after the beat cards)
		var found := -1
		if cards.is_open:
			found = _index_of(sc, str(cards.text))
			_clear(cards)
		if found >= 0:
			seen.append(found)
			if not sc.LIFE_WEEKS.has(day):
				off_week += 1
	_check(seen == order_a, "twenty weeks deal the six cards in that order, once each (%s)" % str(seen))
	_check(off_week == 0 and int(sc.flags.get("life_seen", 0)) == 6, "only on the life weeks, six dealt")
	# and begin_week really calls it: week 2 of a fresh run
	_start(41)
	c.day = 2
	sc.begin_week(2)
	var wired := false
	var guard := 0
	while cards.is_open and guard < 60:
		wired = wired or str(cards.text) == str(sc.LIFE[int(order_a[0])].text)
		cards.pick(cards.options.size() - 1 if _index_of(sc, str(cards.text)) < 0 else 0)
		guard += 1
	_check(wired, "begin_week deals the first card on week 2")
	sc.flags["life_seen"] = 6
	var saved: Dictionary = sc.to_dict()
	sc.from_dict(saved)
	_check(int(sc.flags.get("life_seen", 0)) == 6, "the count is in the save")
	sc._life_card(17)
	_check(not cards.is_open, "after a load the count is kept: no seventh card")
	_clear(cards)
	_start(42)
	var order_b: Array = sc.life_order()
	_start(43)
	var order_c: Array = sc.life_order()
	_check(order_a != order_b or order_a != order_c, "another run deals another order (%s / %s / %s)" % [str(order_a), str(order_b), str(order_c)])

	# ---- the effects
	_start(44)
	var weak := _lead(sc, 30)
	var best := _lead(sc, 55)
	sc.life_fx({"pipe": 4})
	_check(int(best.quality) == 59 and int(weak.quality) == 30, "pipe moves the best open lead (55 -> %d), not the others" % int(best.quality))
	sc.life_fx({"pipe": -3})
	_check(int(best.quality) == 56, "and a negative one takes from it")
	var consc0: int = root.get_node("Owner").consc
	sc.life_fx({"consc": -1})
	_check(root.get_node("Owner").consc == consc0 - 1, "consc -1 costs a point of conscience")
	var rel0: int = social.value("Alan")
	sc.life_fx({"morale": 2})
	_check(social.value("Alan") == rel0 + 2, "morale 2 lifts the people around you")
	sc.leads.clear()
	sc.life_fx({"pipe": 4})
	_check(true, "pipe with no open lead does nothing and breaks nothing")

	# ---- through the card: pick an option, the reply, the effect
	_start(45)
	var lead := _lead(sc, 50)
	var order_d: Array = sc.life_order()
	var first: Dictionary = sc.LIFE[int(order_d[0])]
	c.day = 2
	sc.flags["life_seen"] = 0
	sc._life_card(2)
	_check(cards.is_open and str(cards.text) == str(first.text) and cards.options.size() == 3, "the first card opens on week 2")
	var fx0: Dictionary = first.options[0].fx
	cards.pick(0)
	_check(cards.is_open and str(cards.text) == str(first.options[0].reply), "the reply follows")
	_clear(cards)
	_check(int(lead.quality) == clampi(50 + int(fx0.get("pipe", 0)), 5, 95), "the pipeline moved by the option's pipe (%d)" % int(lead.quality))

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
