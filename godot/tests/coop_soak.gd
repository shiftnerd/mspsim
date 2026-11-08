extends SceneTree
# Co-op phase 8: a short soak. Open and close panes, change rooms and swap people over and over with two players; the node
# count must settle (no pane, card or body leaks) and nothing may error.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_soak.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopsoak_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopsoak_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var game := root.get_node("Game")
	root.get_node("Campaign").new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var host: Node = players.takeover_host()
	var rooms := ["kitchenette", "main_floor", "kitchenette", "main_floor"]
	var counts := []
	# SOAK_MINUTES=15 keeps cycling for that many minutes (the node count is checked per room against the first visit)
	var minutes := float(OS.get_environment("SOAK_MINUTES")) if OS.get_environment("SOAK_MINUTES") != "" else 0.0
	var started := Time.get_ticks_msec()
	var long_run := minutes > 0.0
	var rounds := 6
	var first_main := -1
	var worst_main := 0
	for round_n in 100000:
		if round_n >= rounds and (not long_run or float(Time.get_ticks_msec() - started) > minutes * 60000.0):
			break
		for i in 4:
			host.open_computer(1, 3)
			host.open_phone(0)
			await _wait(8)
			host.close_all()
			await _wait(4)
			players.node(1).swap_character(1)
			players.node(0).swap_character(1)
		game.go(rooms[round_n % rooms.size()], "start")
		await create_timer(1.2).timeout
		await _wait(10)
		game.busy = false
		game.ui_open = false
		counts.append(get_node_count_total())
		if rooms[round_n % rooms.size()] == "main_floor":
			if first_main < 0:
				first_main = counts[counts.size() - 1]
			worst_main = maxi(worst_main, counts[counts.size() - 1])
	ok(players.node(0) != null and players.node(1) != null, "both players are still in the room after the soak")
	ok(not players.ui[0] and not players.ui[1], "and nobody is stuck at a screen")
	# the same room gives the same count (the rooms alternate), so compare the last visit of each with the one before it
	var drift_a: int = counts[5] - counts[3]
	var drift_b: int = counts[4] - counts[2]
	ok(drift_a <= 10 and drift_b <= 10, "the node count settles per room (%s)" % [counts.slice(0, 8)])
	if long_run:
		print("soak: %d rounds in %.1f minutes, main_floor node count first %d worst %d" % [counts.size(), float(Time.get_ticks_msec() - started) / 60000.0, first_main, worst_main])
		ok(worst_main - first_main <= 40, "over the long run the node count stays flat (first %d, worst %d)" % [first_main, worst_main])
	players.enable_coop(false)
	print("coop_soak: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func get_node_count_total() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
