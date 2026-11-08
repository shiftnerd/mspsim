extends SceneTree
# Co-op phase 2 (docs/scope-coop.md): the shared camera frames both players and the tether keeps both on screen.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_camera.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopcam_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopcam_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var game := root.get_node("Game")

	# ---- the pure math
	ok(is_equal_approx(players.coop_focus([100.0, 300.0]), 200.0), "the focus is the middle of the two")
	ok(is_equal_approx(players.coop_focus([150.0]), 150.0), "one body: its own x")
	var tight: Vector2 = players.tether_range(500.0, 368.0, 0.0, 368.0)
	ok(is_equal_approx(tight.x, 0.0) and is_equal_approx(tight.y, 368.0), "a room that fits the view has no tether")
	var mid: Vector2 = players.tether_range(400.0, 320.0, 0.0, 1000.0)
	ok(is_equal_approx(mid.y - mid.x, 320.0 - 2.0 * players.TETHER_MARGIN), "the allowed span is the view less a margin each side")
	var edge: Vector2 = players.tether_range(5.0, 320.0, 0.0, 1000.0)
	ok(edge.x >= 0.0 and is_equal_approx(edge.x, players.TETHER_MARGIN), "near a wall the view stops at the wall (the camera limit)")

	# ---- in a room: two players far apart in the h format get pulled onto one screen
	game.set_format("h")
	change_scene_to_file("res://scenes/warehouse.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.split_cam = false  # this test is about the tether; coop_split covers the second camera
	players.enable_coop(true)
	players.join(1, 1)
	var stage := current_scene
	var p2: Node = players.node(1)
	ok(p2 != null, "player two is in the warehouse")
	var p1: Node = players.node(0)
	p1.global_position.x = 150.0
	p2.global_position.x = 150.0
	await _wait(20)
	p1.global_position.x = 150.0
	p2.global_position.x = 900.0
	await _wait(30)
	var gap: float = absf(p1.global_position.x - p2.global_position.x)
	ok(gap <= 320.0, "the tether keeps two players within one screen (gap %d px)" % int(gap))
	var cam: Camera2D = stage.get_node("Camera2D") if stage.has_node("Camera2D") else null
	if cam == null:
		for c in stage.get_children():
			if c is Camera2D:
				cam = c
	var mid_x: float = (p1.global_position.x + p2.global_position.x) * 0.5
	ok(cam != null and absf(cam.global_position.x - mid_x) < 200.0, "the camera sits near the middle of the two")
	players.split_cam = true
	players.enable_coop(false)
	game.set_format("wide")
	print("fails=", fails)
	quit(1 if fails > 0 else 0)
