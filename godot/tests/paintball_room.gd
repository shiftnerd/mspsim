extends SceneTree
# The paintball outing in its room: the western field, six puppets, the match runs, the result pays out and you are back at the office.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/paintball_room.gd

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
	root.get_node("Campaign").save_prefix = "user://test_pbroom_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_pbroom_%d_settings.cfg" % pid
	var o := root.get_node("Outings")
	var camp := root.get_node("Campaign")
	camp.new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	ok(o.GAMES.has("paintball") and int(o.GAMES.paintball.cost) == 200, "paintball is an outing and costs $200")
	ok(o.ROOMS.paintball == "paintball_field" and o.SPOTS.paintball.size() == 6, "it has a room and six spots for the crew")
	ok(root.get_node("Difficulty").f("paint.skill") == 1.0, "the difficulty numbers are there (normal is 1.0)")
	o.use_rooms = true
	o.start("paintball")
	await create_timer(2.5).timeout
	await _wait(10)
	ok(current_scene.name == "PaintballField" and o.is_open and o.phase == "intro", "you are taken to the field and the intro shows")
	o.press(KEY_ENTER)
	await _wait(5)
	ok(o.phase == "play" and o.g.has("rules") and o.g.has("track"), "ENTER starts the match with a track in the room")
	var track: Node = o.g.track
	ok(track.puppets.size() == 6, "six players are on the street")
	ok(not current_scene.get_node("Actors/Player").visible, "the real player is hidden while the puppets play")
	var rules: RefCounted = o.g.rules
	rules.you_auto = true
	# the real loop for a while, then fast forward the clock
	await create_timer(5.0).timeout
	ok(rules.phase == "play" and rules.clock > 0.5, "the match is running")
	var guard := 0
	while rules.phase != "over" and guard < 20000:
		rules.step(1.0 / 30.0)
		guard += 1
	await create_timer(2.5).timeout
	await _wait(10)
	ok(o.phase == "result", "the result page comes up when the match is over (phase %s)" % o.phase)
	ok(o.stars >= 0 and o.stars <= 3, "with 0 to 3 stars (%d)" % o.stars)
	ok(o.lines.size() >= 2, "and lines about the match: %s" % str(o.lines.slice(0, 2)))
	ok(int(o.best.get("paintball", -1)) == o.stars, "the best of the game is recorded")
	o.press(KEY_ENTER)
	await create_timer(2.5).timeout
	await _wait(10)
	ok(not o.is_open and current_scene.name == "MainFloor", "you are back at the office")
	ok(current_scene.get_node("Actors/Player").visible, "and visible again")
	print("paintball_room: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
