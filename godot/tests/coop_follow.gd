extends SceneTree
# Co-op phase 2 leftover: a coworker who was asked to follow trails the player who asked, not always player 1.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_follow.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopfollow_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopfollow_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	root.get_node("Campaign").new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var p1: Node = players.node(0)
	var p2: Node = players.node(1)
	var npc: Node = null
	for n in get_nodes_in_group("npcs"):
		if str(n.cast_name) != "" and n.seat == null:
			npc = n
			break
	if npc == null:
		for n in get_nodes_in_group("npcs"):
			if str(n.cast_name) != "":
				npc = n
				break
	ok(npc != null, "the room has a coworker")
	npc.seat = null
	npc._hold = 0.0
	npc._player = p1
	npc.following = true
	p1.global_position.x = 140.0
	p2.global_position.x = 300.0
	npc.global_position.x = 220.0
	npc._follow_slot = 1
	for i in 120:
		npc._follow_tick(0.05)
	ok(npc.global_position.x > 260.0, "asked by player 2, they walk to player 2 (%.0f)" % npc.global_position.x)
	npc._follow_slot = 0
	for i in 240:
		npc._follow_tick(0.05)
	ok(npc.global_position.x < 190.0, "asked by player 1, they walk to player 1 (%.0f)" % npc.global_position.x)
	players.enable_coop(false)
	print("coop_follow: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
