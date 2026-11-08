extends SceneTree
# Co-op phase 7: the owner campaign takes a second player: they are the other owner (Garrison when player 1 is Alan), that cast
# member is not also in the building as an NPC, and the tech campaign's x1.5 ticket pace does not apply here.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_owner.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopowner_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopowner_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var campaign := root.get_node("Campaign")
	var world := root.get_node("World")
	load("res://scripts/player.gd").current_character = "office_alan"
	campaign.new_game("owner")
	world.time_scale = 1.0
	players.enable_coop(true)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	root.get_node("Game").busy = false
	root.get_node("Game").ui_open = false
	ok(campaign.active and campaign.mode == "owner" and campaign.player_as == "Alan", "an owner campaign as Alan")
	ok(players.can_join(), "player 2 can join the owner campaign")
	ok(players.join(1, 1), "player 2 joins")
	await _wait(5)
	ok(players.slot(1).character == str(world.row("Garrison").character), "player 2 is the other owner")
	ok(not world.chars.has("Garrison"), "so Garrison is not also an NPC")
	ok(players.pace() == 1.0, "the owner campaign keeps its own pace")
	players.leave(1)
	await _wait(3)
	ok(world.chars.has("Garrison"), "and he is back when player 2 leaves")
	players.enable_coop(false)
	print("coop_owner: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
