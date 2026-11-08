extends SceneTree
# Co-op phase 6: in the room games the active human's own body does the throwing and rolling: Outings._set_pilot makes the
# games' "Player" actor player 2's body for their turn (the old pilot steps aside, the new one takes the spot).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_outing_bodies.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopbodies_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopbodies_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var outings := root.get_node("Outings")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var p1: Node = players.node(0)
	var p2: Node = players.node(1)
	ok(outings._actor("Player") == p1, "by default the games' Player is player 1's body")
	p1.global_position.x = 400.0
	outings._set_pilot(1)
	ok(outings._actor("Player") == p2, "pilot 1 makes it player 2's body")
	ok(is_equal_approx(p2.global_position.x, 400.0) and p1.global_position.x < 400.0, "player 2 takes the spot and player 1 steps aside")
	outings._set_pilot(0)
	ok(outings._actor("Player") == p1, "and back")
	outings._set_pilot(1)
	outings.is_open = true
	outings.close()
	ok(outings._pilot == 0 and outings._actor("Player") == p1, "closing the outing gives the games back to player 1")
	players.enable_coop(false)
	print("coop_outing_bodies: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
