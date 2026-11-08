extends SceneTree
# Co-op phase 5: the roster is saved with the campaign (a "coop" section) and comes back on Continue; a save without it, or
# co-op switched off, loads as a single-player run.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_save.gd

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
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_coopsave_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopsave_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var skills := root.get_node("Skills")
	camp.new_game("tech")
	root.get_node("World").time_scale = 1.0
	players.enable_coop(true)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	root.get_node("Game").busy = false
	root.get_node("Game").ui_open = false
	ok(players.to_dict().is_empty(), "alone, the roster section is empty")
	players.join(1, 2)
	players.slot(1).skills = players._blank_skills()
	players.slot(1).skills.xp["servers"] = 33
	players.slot(1).skills.ps_level = 2
	players.slot(1).energy = 61.5
	players.slot(1).look = {"name": "PIP"}
	players.slot(1).stored_character = "office_alan"
	skills.xp["people"] = 11
	camp.save()
	var cfg := ConfigFile.new()
	cfg.load(camp.save_path("tech"))
	var saved: Dictionary = cfg.get_value("campaign", "coop", {})
	ok(int(saved.get("device", 0)) == 2 and saved.skills.xp.servers == 33, "the save holds the coop section")

	# wipe player 2, continue, and they are back
	players.leave(1)
	players.slot(1).skills = {}
	players.slot(1).energy = -1.0
	players.slot(1).stored_look = {}
	ok(camp.continue_game("tech"), "continue loads the save")
	var s = players.slot(1)
	ok(s.joined and s.device == 2 and s.character == "office_alan", "player 2 is back with their pad and person")
	ok(s.skills.xp.servers == 33 and s.skills.ps_level == 2 and is_equal_approx(s.energy, 61.5), "their skills and energy are back")
	ok(s.look.get("name", "") == "PIP", "and their look")
	ok(skills.xp.get("people", 0) == 11 and skills.xp.get("servers", 0) != 33, "player 1's own skills stay player 1's")

	# co-op off: the same save is a single-player run
	players.leave(1)
	players.slot(1).skills = {}
	players.enable_coop(false)
	ok(camp.continue_game("tech") and not players.slot(1).joined, "with co-op off the save loads single player")
	# an old save without the section
	cfg = ConfigFile.new()
	cfg.load(camp.save_path("tech"))
	cfg.erase_section_key("campaign", "coop")
	cfg.save(camp.save_path("tech"))
	players.enable_coop(true)
	ok(camp.continue_game("tech") and not players.slot(1).joined, "a save without a coop section loads single player")
	players.enable_coop(false)
	print("coop_save: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
