extends SceneTree
# R7: J opens the career screen in Free Play (a campaign keeps the phone's Settings route). R8: the career screen counts the cards seen.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key() -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_J
	e.keycode = KEY_J
	e.pressed = true
	return e


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var tool := root.get_node("Toolbox")
	var game := root.get_node("Game")
	var controls := root.get_node("Controls")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	_check(controls.matches(_key(), "career"), "J is the career action")
	c.new_game(c.FREE)
	game.busy = false
	game.ui_open = false
	var before := root.get_child_count()
	tool._unhandled_input(_key())
	_check(root.get_child_count() == before + 1 and game.ui_open, "in Free Play J opens the career screen")
	# close it again the way a close button would
	var layer: Node = root.get_child(root.get_child_count() - 1)
	layer.queue_free()
	game.ui_open = false
	await process_frame
	c.new_game("tech")
	game.busy = false
	game.ui_open = false
	before = root.get_child_count()
	tool._unhandled_input(_key())
	_check(root.get_child_count() == before and not game.ui_open, "in a campaign J does nothing")
	# R8: the career screen counts the cards put in front of you
	var cards := root.get_node("Cards")
	var career := root.get_node("Career")
	var seen0: int = int(career.counters.get("cards_seen", 0))
	cards.ask("Dan", "A card.", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	_check(int(career.counters.get("cards_seen", 0)) == seen0 + 1, "a shown card counts as seen")
	cards.pick(0)
	var listed := false
	for row in career.COUNTERS:
		listed = listed or str(row[2]) == "cards_seen"
	_check(listed, "and the career screen lists it")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
