extends SceneTree
# R7: the picked rubber duck skin and desk toy show on the main floor's desk; the chips on the desktop cycle them.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/desk_art.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_deskart_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_deskart_%d_settings.cfg" % pid
	var career := root.get_node("Career")
	ok(str(career.pick_of("duck").id) == "duck_classic", "the plain duck is the default")
	ok(str(career.pick_of("desk_toy").id) == "toy_none", "no toy is the default")
	ok(career.unlocked_of("duck").size() == 1, "nothing else is unlocked yet, so no chip is shown")
	career.earned["limbo_legend"] = true
	career.earned["full_house"] = true
	ok(career.unlocked_of("duck").size() == 2 and career.unlocked_of("desk_toy").size() == 2, "a medal adds an entry")
	career.cycle_pick("duck")
	career.cycle_pick("desk_toy")
	ok(str(career.pick_of("duck").id) == "duck_pirate", "cycling picks the pirate duck")
	ok(str(career.pick_of("desk_toy").id) == "toy_pendulum", "and the pendulum")
	root.get_node("Campaign").new_game("free")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.2).timeout
	for i in 10:
		await physics_frame
	var duck: Sprite2D = null
	for n in current_scene.get_node("Actors").get_children():
		if n is Sprite2D and n.name.begins_with("rubber_duck"):
			duck = n
	ok(duck != null, "the duck is on the desk")
	var skin: Texture2D = load("res://assets/props/rubber_duck_pirate.png")
	ok(duck != null and duck.texture == skin, "and it wears the pirate skin")
	career.prefs["duck"] = "duck_classic"
	for i in 6:
		await physics_frame
	ok(duck.texture != skin, "back to the plain duck")
	print("desk_art: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
