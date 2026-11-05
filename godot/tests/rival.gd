extends SceneTree
# R38 P0: the rap sheet (Rival), the saved state of the rival/habit/temptation scaffold in Owner, the hooks into settle and the
# Strings roots of the new tables. Headless, seeded.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1


func _start(c: Node, cards: Node, day: int) -> void:
	c.new_game("owner")
	_clear(cards)
	c.day = day
	seed(7)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var strings := root.get_node("Strings")
	var rival: Script = load("res://scripts/rival.gd")
	var habits: Script = load("res://scripts/habits.gd")
	var view: Script = load("res://scripts/habits_view.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- the tables
	_check(
		rival.HABITS.size() == 17 and rival.HABITS.has("R01") and rival.HABITS.has("R17"),
		"17 rival habits R01-R17"
	)
	_check(
		(
			rival.RIVALS.has("bigcheese")
			and rival.RIVALS.has("bytebrothers")
			and rival.RIVALS.has("plumbline")
		),
		"the three rivals"
	)
	for id in rival.HABITS:
		_check(
			habits.HABITS.has(str(rival.HABITS[id].twin)),
			"%s has a good twin that exists (%s)" % [id, rival.HABITS[id].twin]
		)

	# ---- the level only goes up
	_start(c, cards, 5)
	_check(
		rival.rap("bigcheese", "R01") == 0 and rival.line("bigcheese") == "",
		"nothing known at the start"
	)
	_check(rival.set_rap("bigcheese", "R01", 1), "rumour is recorded")
	_check(rival.set_rap("bigcheese", "R01", 3), "proof raises it")
	_check(
		not rival.set_rap("bigcheese", "R01", 2) and rival.rap("bigcheese", "R01") == 3,
		"a lower level never lowers it"
	)
	_check(
		not rival.set_rap("bigcheese", "R01", 0) and rival.rap("bigcheese", "R01") == 3,
		"unknown never lowers it"
	)
	_check(
		rival.set_rap("bigcheese", "R02", 99) and rival.rap("bigcheese", "R02") == 3,
		"levels are clamped to 3"
	)
	o.apply({"rap": ["bigcheese", "R11", 2]})
	_check(rival.rap("bigcheese", "R11") == 2, "fx rap sets a level")
	o.apply({"rap": [["bigcheese", "R17", 1], ["bigcheese", "R16", 2]]})
	_check(
		rival.rap("bigcheese", "R17") == 1 and rival.rap("bigcheese", "R16") == 2,
		"fx rap takes a list of records"
	)
	_check(
		rival.line("bigcheese") == "BIG CHEESE: 2 PROVEN, 2 SEEN, 1 RUMOUR",
		"the weekly line: " + rival.line("bigcheese")
	)
	_check(rival.lines().size() == 1, "only rivals you know something about get a line")
	_check(rival.best("R11") == 2, "best() is the best level across rivals")

	# ---- the weekly report rows (owner campaign only, only when there is something to say)
	var rows: Array = o.settle().rows
	var labels := []
	for r in rows:
		labels.append(str(r[0]))
	_check(
		labels.has("RAP SHEET") and not labels.has("STANDARD") and not labels.has("FOLDER"),
		"the report shows the rap sheet, no STANDARD or FOLDER row yet"
	)
	habits.start("H1")
	o.skel.append({"id": "temp_seats", "due": 99, "class": "vendor", "size": 100})
	labels = []
	for r in o.settle().rows:
		labels.append(str(r[0]))
	_check(
		labels.has("STANDARD") and labels.has("FOLDER"),
		"STANDARD and FOLDER rows appear once a habit or a skeleton exists"
	)

	# ---- save and load
	var saved: Dictionary = o.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	_start(c, cards, 5)
	_check(
		rival.rap("bigcheese", "R01") == 0 and o.habits.is_empty() and o.skel.is_empty(),
		"a new game starts with a clean book"
	)
	o.from_dict(parsed)
	_check(
		rival.rap("bigcheese", "R01") == 3 and rival.rap("bigcheese", "R11") == 2,
		"the rap sheet survives a JSON save"
	)
	_check(
		o.habits.has("H1") and o.skel.size() == 1 and str(o.skel[0].id) == "temp_seats",
		"habits and skeletons survive a JSON save"
	)
	o.inherit = {3: 45}
	var again: Variant = JSON.parse_string(JSON.stringify(o.to_dict()))
	o.from_dict(again)
	_check(
		o.inherit.has(3) and int(o.inherit[3]) == 45,
		"the inherited risk survives with its integer keys"
	)

	# ---- an old save (no R38 keys) loads with safe defaults
	var old := {"cash": 4321, "flags": {"practice_profit": true}, "price": 1.0}
	o.from_dict(old)
	_check(
		(
			o.cash == 4321
			and o.habits.is_empty()
			and o.consc == 0
			and o.skel.is_empty()
			and o.inherit.is_empty()
		),
		"an old save loads with a clean book"
	)
	_check(rival.lines().is_empty() and habits.standard() == 0, "and no rap sheet and no Standard")

	# ---- the arc: queues only cards that exist, shows each once
	_start(c, cards, 5)
	var real_flat: Dictionary = o.CARDS["rival_flat"]  # R38 rival agent: the real card exists now
	o.CARDS.erase("rival_flat")
	rival.arc_week(o, 2)
	_check(
		(o.flags.get("arc_queue", []) as Array).is_empty(),
		"no queue while the beat card does not exist"
	)
	o.CARDS["rival_flat"] = {
		"speaker": "Garrison", "text": "Test card.", "options": [{"label": "OK", "fx": {}}]
	}
	rival.arc_week(o, 2)
	_check(
		(o.flags.get("arc_queue", []) as Array) == ["rival_flat"], "week 2 queues the week 3 beat"
	)
	rival.morning(o)
	_check(cards.is_open and o.flags.has("arc_rival_flat"), "the morning shows it and remembers it")
	_clear(cards)
	rival.arc_week(o, 2)
	_check((o.flags.get("arc_queue", []) as Array).is_empty(), "a shown beat is never queued again")
	o.CARDS["rival_flat"] = real_flat

	# ---- the cards file is merged and the Strings roots work on static tables
	_check(
		o.RivalCards.CARDS.has("rival_flat") and o.RivalCards.merged_days({1: []}) == {1: []},
		"the rival cards exist and no placements yet"
	)
	var entries: Array = strings.entries()
	var keys := {}
	for e in entries:
		keys[str(e.key)] = true
	_check(
		keys.has("Rival.HABITS.R01.name") and keys.has("Habits.HABITS.H1.name"),
		"Strings sees the Rival and Habits tables"
	)
	var before: String = rival.HABITS.R01.name
	_check(
		(
			strings._store(["Rival", "HABITS", "R01", "name"], "TEST NAME")
			and rival.HABITS.R01.name == "TEST NAME"
		),
		"a strings.txt edit reaches the static table"
	)
	rival.HABITS.R01.name = before

	# ---- the Boardroom tabs stay hidden until the feature is live
	_start(c, cards, 1)
	_check(view.tabs().is_empty(), "no HABITS and RIVALS tabs in a fresh game")
	rival.set_rap("bigcheese", "R11", 1)
	_check(view.tabs().size() == 2, "the tabs appear once you know something")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
