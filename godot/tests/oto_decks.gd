extends SceneTree
# gdlint:disable=max-line-length
# C7: the service campaign's 1:1 decks. Twenty cards for Maya and John (C7b), 28 for the techs, dealt in an order of the run's own (seeded), no card twice in
# a run; when a deck is used up a 1:1 is a short check-in, and nobody walks up with nothing new to say. The last block plays a
# 20-day service run with the careful bot (two 1:1s a day, as the balance runs do) and checks that no 1:1 card came twice.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/oto_decks.gd

const FX_KEYS := ["morale", "retain", "skill", "speed", "stress", "trust", "social", "mood", "morale_who", "flag"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1
	return n


func _start(seed_n: int) -> void:
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(seed_n)
	root.get_node("Campaign").new_game("service")
	_clear(root.get_node("Cards"))


# the text of the card on screen, as the deck holds it (index in the deck, -1 when it is not a deck card)
func _deck_index(sv: Node, deck: String, who: String, shown: String) -> int:
	for i in sv.ONE_ON_ONES[deck].size():
		if str(sv.ONE_ON_ONES[deck][i].text).replace("{name}", who) == shown:
			return i
	return -1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var pid := OS.get_process_id()
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var d := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_oto_" % pid
	d.settings_path = "user://test_%d_oto_settings.cfg" % pid
	load("res://scripts/player.gd").current_character = "office_dan"
	d.set_tier("normal")

	# ---- the decks themselves
	var sizes := []
	var shape_ok := true
	var texts := {}
	var dup := ""
	for deck in sv.ONE_ON_ONES:
		sizes.append("%s %d" % [deck, sv.ONE_ON_ONES[deck].size()])
		for card in sv.ONE_ON_ONES[deck]:
			if texts.has(str(card.text)):
				dup = str(card.text)
			texts[str(card.text)] = true
			shape_ok = shape_ok and card.options.size() == 3
			for o in card.options:
				shape_ok = shape_ok and str(o.label) != "" and str(o.reply) != "" and str(o.label).length() <= 40
				for key in o.fx:
					shape_ok = shape_ok and key in FX_KEYS
			if deck == "Tech":
				shape_ok = shape_ok and str(card.text).begins_with("{name} says:")
	_check(sv.ONE_ON_ONES.Maya.size() >= 20 and sv.ONE_ON_ONES.Tech.size() >= 10 and sv.ONE_ON_ONES.John.size() >= 20, "Maya and John have twenty cards or more, the techs ten and more (%s)" % ", ".join(sizes))
	# C7: 28 tech cards, because a 20-day run holds 25 to 27 tech 1:1s (two techs, a 1:1 a day in turn, plus the walk-ups)
	_check(sv.ONE_ON_ONES.Tech.size() >= 28, "the techs' shared deck has 28 cards or more (%d)" % sv.ONE_ON_ONES.Tech.size())
	_check(shape_ok and dup == "", "every card has three options with a label, a reply and known effects; no text twice %s" % dup)
	# the same reading of the options in every card: the first is the considered answer, the last the curt one
	var order_ok := true
	for card in sv.ONE_ON_ONES.Maya:
		order_ok = order_ok and int(card.options[0].fx.get("morale", 0)) > 0 and int(card.options[0].fx.get("retain", 0)) >= 1 and int(card.options[2].fx.get("morale", 0)) < 0
	for card in sv.ONE_ON_ONES.Tech:
		order_ok = order_ok and int(card.options[0].fx.get("morale", 0)) > 0 and int(card.options[2].fx.get("morale", 0)) < 0
	for card in sv.ONE_ON_ONES.John:
		order_ok = order_ok and int(card.options[1].fx.social.John) > 0 and int(card.options[2].fx.social.John) < 0
	_check(order_ok, "the first option is the considered one and the last the curt one, in every card")

	# ---- C7b: a promise in a 1:1 comes back as a card (four in Maya's ten new cards, four in John's)
	var flagged := {"Maya": 0, "John": 0}
	var back_ok := true
	for flag in sv.ONE_BACK:
		var row: Dictionary = sv.ONE_BACK[flag]
		var from_deck := ""
		for deck in ["Maya", "John"]:
			for card in sv.ONE_ON_ONES[deck]:
				for o in card.options:
					if str(o.fx.get("flag", "")) == str(flag):
						from_deck = deck
		flagged[from_deck] = int(flagged.get(from_deck, 0)) + 1
		back_ok = back_ok and from_deck == str(row.who) and int(row.after) >= 3 and row.options.size() == 3 and int(row.after) <= 5
		for o in row.options:
			back_ok = back_ok and str(o.label) != "" and str(o.reply) != "" and str(o.label).length() <= 40
			for key in o.fx:
				back_ok = back_ok and key in FX_KEYS
		if str(row.who) == "Maya":
			back_ok = back_ok and int(row.options[0].fx.morale) > 0 and int(row.options[2].fx.morale) < 0
		else:
			back_ok = back_ok and int(row.options[1].fx.social.John) > 0 and int(row.options[2].fx.social.John) < 0
		_check(not texts.has(str(row.text)), "the callback of %s is not a deck card" % str(flag))
	_check(int(flagged.Maya) == 4 and int(flagged.John) == 4 and sv.ONE_BACK.size() == 8, "four of Maya's new cards and four of John's carry a flag with a callback (%s)" % str(flagged))
	_check(back_ok, "every callback has three options, known effects, a person who owns the flag and 3 to 5 days")
	_start(21)
	var promise: Dictionary = {}
	for card in sv.ONE_ON_ONES.Maya:
		for o in card.options:
			if str(o.fx.get("flag", "")) == "maya_visit":
				promise = card
	c.day = 4
	crew.members["Maya"]["morale"] = 50
	sv._answer_oto("Maya", "Maya", promise, 0, Callable())
	_clear(cards)
	_check(bool(sv.flags.get("maya_visit", false)) and int(sv.flags.get("flag_day_maya_visit", 0)) == 4, "the promise sets its flag and the day")
	sv._oto_backs(6)
	_check(not cards.is_open, "two days later it has not come back")
	sv._oto_backs(7)
	_check(cards.is_open and str(cards.text) == str(sv.ONE_BACK.maya_visit.text), "three days later Maya asks for it")
	var morale0: int = crew.morale("Maya")
	cards.pick(0)
	_clear(cards)
	_check(crew.morale("Maya") > morale0, "keeping the promise lifts her (morale %d -> %d)" % [morale0, crew.morale("Maya")])
	sv._oto_backs(9)
	_check(not cards.is_open, "it comes back once")
	var saved_flags: Dictionary = sv.to_dict()
	sv.from_dict(saved_flags)
	sv._oto_backs(12)
	_check(not cards.is_open, "a save in between keeps that")
	# without the promise nothing comes back
	_start(22)
	sv._oto_backs(30)
	_check(not cards.is_open, "no promise, no callback")

	# ---- a run deals a deck in its own order, every card once
	_start(11)
	var order_a: Array = sv.oto_order("Maya")
	var sorted_a: Array = order_a.duplicate()
	sorted_a.sort()
	_check(sorted_a == range(sv.ONE_ON_ONES.Maya.size()), "the order of a deck holds every card once (%s)" % str(order_a))
	_check(sv.oto_order("Maya") == order_a, "asked again it is the same order")
	var n_maya: int = sv.ONE_ON_ONES.Maya.size()
	var seen := []
	for day in range(1, n_maya + 1):
		c.day = day
		sv.one_on_one("Maya")
		seen.append(_deck_index(sv, "Maya", "Maya", str(cards.text)))
		_clear(cards)
	_check(seen == order_a, "ten days of 1:1s with Maya deal her deck in that order, no card twice (%s)" % str(seen))
	_check(sv.oto_left("Maya") == 0, "the deck is used up")
	# a save in the middle keeps the place and the order
	var saved: Dictionary = sv.to_dict()
	_check(int(saved.oto_seen.Maya) == n_maya, "the count is in the save")
	# used up: a check-in, a little morale, never a card of the deck again
	crew.members["Maya"]["morale"] = 50
	c.day = n_maya + 1
	sv.one_on_one("Maya")
	_check(cards.is_open and str(cards.text) == str(sv.ONE_TEXT.quiet) and cards.options.size() == 1, "after the last card a 1:1 is a short check-in (%s)" % str(cards.text))
	_clear(cards)
	_check(crew.morale("Maya") > 50 and crew.morale("Maya") <= 50 + sv.OTO_QUIET_MORALE + 1, "which is worth a little (morale 50 -> %d)" % crew.morale("Maya"))
	sv.one_on_one("Maya")
	_check(str(cards.text) == str(sv.ONE_TEXT.already), "still one 1:1 a day")
	_clear(cards)
	_check(sv.oto_log.size() == n_maya + 1 and sv.oto_log.back() == ["Maya", -1], "the run's log has every 1:1 (%d)" % sv.oto_log.size())

	# the tech deck is shared: what Sam was dealt Terry is not dealt again
	c.day = 30
	var tech_seen := []
	var techs := []
	for n in crew.names():
		if str(n) != "Maya":
			techs.append(str(n))
	_check(techs.size() >= 2, "two techs share the tech deck (%s)" % str(techs))
	var day := 30
	while sv.oto_left("Tech") > 0 and day < 60:
		for who in techs:
			if sv.oto_left("Tech") > 0:
				sv.one_on_one(who)
				tech_seen.append(_deck_index(sv, "Tech", who, str(cards.text)))
				_clear(cards)
		day += 1
		c.day = day
	var uniq := {}
	for i in tech_seen:
		uniq[i] = true
	_check(tech_seen.size() == sv.ONE_ON_ONES.Tech.size() and uniq.size() == tech_seen.size() and not uniq.has(-1), "the tech deck goes round every tech once, no card twice (%d cards)" % tech_seen.size())
	# nobody walks up to say the check-in line
	for who in techs:
		crew.members[who]["last_oto"] = 0
	c.day = 70
	sv._walk_up()
	_check(not cards.is_open, "with the tech deck used up nobody walks up to your desk")
	_clear(cards)

	# a load puts the count back, and the order is the run's
	sv.from_dict(saved)
	_check(sv.oto_left("Maya") == 0 and sv.oto_order("Maya") == order_a, "after a load the deck is where it was, in the same order")

	# another run: another order
	_start(12)
	var order_b: Array = sv.oto_order("Maya")
	_start(13)
	var order_c: Array = sv.oto_order("Maya")
	_check(order_a != order_b or order_a != order_c, "another run deals another order (%s / %s / %s)" % [str(order_a), str(order_b), str(order_c)])
	_check(sv.oto_log.is_empty() and sv.oto_left("Maya") == n_maya, "a new run starts with full decks")

	# ---- twenty days of 1:1s with each of the three decks: every card once, never a check-in
	_start(31)
	var tech_one: String = techs[0]
	var by_deck := {"Maya": [], "John": [], "Tech": []}
	var filler := 0
	for day20 in range(1, 21):
		c.day = day20
		for who in ["Maya", "John", tech_one]:
			sv.one_on_one(who)
			var deck_name: String = "Tech" if who == tech_one else who
			var at := _deck_index(sv, deck_name, who, str(cards.text))
			if at < 0:
				filler += 1
			by_deck[deck_name].append(at)
			_clear(cards)
	var no_repeat := true
	for deck_name in by_deck:
		var u := {}
		for i in by_deck[deck_name]:
			u[i] = true
		no_repeat = no_repeat and u.size() == by_deck[deck_name].size()
	_check(filler == 0 and no_repeat, "20 days, a 1:1 a day with each deck: no repeat, no filler (%d Maya, %d John, %d tech cards, %d filler)" % [by_deck.Maya.size(), by_deck.John.size(), by_deck.Tech.size(), filler])
	_check(sv.oto_left("Maya") == sv.ONE_ON_ONES.Maya.size() - 20 and sv.oto_left("John") == sv.ONE_ON_ONES.John.size() - 20, "Maya and John have as many cards as days (%d / %d left)" % [sv.oto_left("Maya"), sv.oto_left("John")])

	# ---- a 20-day run by the careful bot: no 1:1 card twice
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = 40.0
	var r: Dictionary = await bots.play("service", "normal", "careful", 3)
	var log: Array = sv.oto_log.duplicate(true)
	var shown := {}
	var twice := []
	var quiet := 0
	var per := {}
	for entry in log:
		var key := "%s:%d" % [str(entry[0]), int(entry[1])]
		per[str(entry[0])] = int(per.get(str(entry[0]), 0)) + 1
		if int(entry[1]) < 0:
			quiet += 1
		elif shown.has(key):
			twice.append(key)
		shown[key] = true
	_check(int(r.get("last_day", 0)) >= 20 and not bool(r.fired), "the bot played the 20 days (day %d, %s)" % [int(r.get("last_day", 0)), str(r.get("ending", ""))])
	_check(log.size() >= 30, "with 1:1s on every day (%d: %s)" % [log.size(), str(per)])
	var tech_quiet := 0
	var tech_cards := 0
	for entry in log:
		if str(entry[0]) == "Tech":
			tech_cards += 1
			if int(entry[1]) < 0:
				tech_quiet += 1
	_check(tech_quiet == 0 and tech_cards >= 15, "no tech 1:1 of the run was a check-in: the deck lasts the 20 days (%d tech 1:1s, %d check-ins, %d cards left)" % [tech_cards, tech_quiet, sv.oto_left("Tech")])
	_check(quiet == 0, "no 1:1 of the 20-day run was a check-in, whoever it was with (%d)" % quiet)
	_check(twice.is_empty(), "no 1:1 card came twice in the run (%d cards, %d check-ins after a used-up deck) %s" % [log.size() - quiet, quiet, str(twice)])
	# the same from what was on screen: the bot's own card log
	var texts_seen := {}
	var text_twice := 0
	var names: Array = ["Maya", "John"] + techs + crew.names() + crew.quits
	for entry in r.get("cards", []):
		var head := str(entry.text)
		var found := ""
		for deck in sv.ONE_ON_ONES:
			for card in sv.ONE_ON_ONES[deck]:
				for who in names:
					if found == "" and str(card.text).replace("{name}", str(who)).substr(0, 56).replace("\n", " ") == head:
						found = "%s|%s" % [deck, str(card.text)]
		if found != "":
			if texts_seen.has(found):
				text_twice += 1
			texts_seen[found] = true
	_check(text_twice == 0 and texts_seen.size() >= 20, "the cards the bot answered say the same (%d different 1:1 cards on screen, %d repeats)" % [texts_seen.size(), text_twice])

	d.set_tier("normal")
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
