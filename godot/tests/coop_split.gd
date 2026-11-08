extends SceneTree
# Co-op phase 3b: the true second camera. Two players further apart than one screen get half the window each; close again,
# the view joins.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_split.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_coopsplit_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopsplit_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var game := root.get_node("Game")

	# the pure decision, with hysteresis
	ok(not players.split_wanted(200.0, 320.0, false), "close together: no split")
	ok(players.split_wanted(320.0, 320.0, false), "a screen apart: split")
	ok(players.split_wanted(200.0, 320.0, true), "once split it stays split until they are within half a screen")
	ok(not players.split_wanted(100.0, 320.0, true), "close again: join")

	game.set_format("h")
	change_scene_to_file("res://scenes/warehouse.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	var stage := current_scene
	var p1: Node = players.node(0)
	var p2: Node = players.node(1)
	p1.global_position.x = 150.0
	p2.global_position.x = 150.0
	await _wait(20)
	ok(not stage._split_on, "together: one view")
	p2.global_position.x = 900.0
	await _wait(30)
	ok(stage._split_on, "far apart: the window splits")
	ok(absf(p1.global_position.x - p2.global_position.x) > 600.0, "and nobody is pulled back by the tether (gap %d)" % int(absf(p1.global_position.x - p2.global_position.x)))
	var vp: SubViewport = stage._split_vp
	ok(vp != null and vp.world_2d == root.world_2d, "the second view shares the world")
	ok(vp.size.x * 2 <= int(stage.get_viewport_rect().size.x) + 1, "and takes half the window")
	ok(absf(stage._split_cam.global_position.x - 900.0) < 5.0, "its camera follows the right player")
	ok(absf(stage._cam.global_position.x - 150.0) < 40.0, "the main camera follows the left one")
	# swap sides: the left pane always follows the leftmost body
	p1.global_position.x = 1000.0
	p2.global_position.x = 300.0
	await _wait(10)
	ok(absf(stage._split_cam.global_position.x - 1000.0) < 5.0, "the right view follows whoever is on the right")
	p1.global_position.x = 900.0
	p2.global_position.x = 850.0
	await _wait(30)
	ok(not stage._split_on, "back together: the view joins")
	ok(stage._cam.offset.x == 0.0 and not stage._split_layer.visible, "and the camera offset and overlay are put away")
	# the switch
	players.split_cam = false
	p1.global_position.x = 150.0
	p2.global_position.x = 900.0
	await _wait(30)
	ok(not stage._split_on and absf(p1.global_position.x - p2.global_position.x) <= 320.0, "with the second camera off the tether holds them together")
	players.split_cam = true
	players.enable_coop(false)
	game.set_format("wide")
	print("coop_split: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
