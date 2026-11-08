extends SceneTree
# Co-op phase 4a: each player picks their own stock person (the pad's R3 / p2_character_next), never the partner's.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_look.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_cooplook_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_cooplook_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var p1: Node = players.node(0)
	var p2: Node = players.node(1)
	var before: String = p2.character_id()
	_press("p2_character_next")
	await _wait(5)
	var after: String = p2.character_id()
	ok(after != before, "player 2's key swaps their person (%s -> %s)" % [before, after])
	ok(after != p1.character_id(), "never the partner's person")
	ok(players.slot(1).character == after, "the slot remembers it")
	# walk the whole list: the partner's person is always skipped
	var clash := false
	for i in 9:
		p2.swap_character(1)
		clash = clash or p2.character_id() == p1.character_id()
	ok(not clash, "a full lap never lands on player 1's person")
	var mine: String = p1.character_id()
	p1.swap_character(1)
	ok(p1.character_id() != mine and p1.character_id() != p2.character_id(), "player 1 steps on without taking player 2's")
	players.enable_coop(false)
	print("coop_look: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
