extends SceneTree
# R11: before a bowling game in a campaign a card lets you pick the lanes (tonight's seeded draw is marked and stays the default elsewhere).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(0)
	o.use_rooms = true
	o.is_open = true
	o.game = "bowling"
	o.phase = "intro"
	o.opts = {"alley": "rental"}
	o._press_page(KEY_ENTER)
	_check(cards.is_open and cards.options.size() == 3 and cards.speaker == "Bowling alley", "pressing start asks which lanes")
	var picks: Array = cards.options.filter(func(op: Dictionary) -> bool: return str(op.label).contains("TONIGHT'S PICK"))
	_check(picks.size() == 1 and str(picks[0].id) == "rental", "tonight's draw (the rec center) is marked")
	var league := 0
	for i in cards.options.size():
		if str(cards.options[i].id) == "league":
			league = i
	cards.pick(league)
	_check(o.opts.alley == "league" and o.phase == "play" and o.g.alley == "league", "picking league night plays league night")
	# a game with the alley already chosen goes straight in, and so does a run outside a campaign
	o.is_open = true
	o.phase = "intro"
	o.opts = {"alley": "strike_zone", "alley_picked": true}
	o._press_page(KEY_ENTER)
	_check(not cards.is_open and o.phase == "play", "an alley that was already picked starts at once")
	o.is_open = false
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
