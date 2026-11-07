extends SceneTree
# Co-op phase 2: a door carries both players. Whoever takes it, both bodies arrive in the next room, beside each other, and the
# camera keeps working there.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_doors.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopdoors_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopdoors_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var game := root.get_node("Game")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	ok(players.count() == 2 and players.node(1) != null, "two players on the main floor")
	var first_scene := current_scene
	# player two walks to the door and uses it: the same transition, so both arrive
	game.go("kitchenette", "start")
	await create_timer(1.5).timeout
	await _wait(10)
	ok(current_scene != first_scene, "the room changed")
	ok(players.node(0) != null and players.node(1) != null, "both bodies are in the kitchenette")
	var gap := absf(players.node(0).global_position.x - players.node(1).global_position.x)
	ok(gap < 60.0, "they arrive side by side (%d px)" % int(gap))
	game.go("main_floor", "from_kitchenette")
	await create_timer(1.5).timeout
	await _wait(10)
	ok(players.node(0) != null and players.node(1) != null, "and both come back")
	ok(get_nodes_in_group("player").size() == 2, "never more than two bodies")
	players.enable_coop(false)
	print("fails=", fails)
	quit(1 if fails > 0 else 0)
