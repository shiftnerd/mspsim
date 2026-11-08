extends SceneTree
# Co-op phase 7: every campaign mode takes a second player (tech, owner, service, sales) as well as Free Play; the x1.5 ticket
# pace is the tech campaign's alone.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_modes.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopmodes_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopmodes_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var campaign := root.get_node("Campaign")
	players.enable_coop(true)
	ok(players.COOP_MODES.size() == 4, "four campaign modes take a second player")
	for mode in ["service", "sales"]:
		campaign.new_game(mode)
		root.get_node("World").time_scale = 1.0
		change_scene_to_file("res://scenes/%s.tscn" % campaign.start_scene())
		await create_timer(1.2).timeout
		await _wait(10)
		root.get_node("Game").busy = false
		root.get_node("Game").ui_open = false
		ok(campaign.active and campaign.mode == mode, "a %s campaign is running" % mode)
		ok(players.can_join(), "player 2 can join the %s campaign" % mode)
		ok(players.join(1, 1) and players.node(1) != null, "and does")
		ok(players.pace() == 1.0, "the %s campaign keeps its own ticket pace" % mode)
		players.leave(1)
		await _wait(3)
	players.enable_coop(false)
	print("coop_modes: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
