extends SceneTree
# Co-op phase 6: the tandem's second pilot is drawn riding the same chair (no second chair), player 2's own body is hidden while
# they ride and shown again when the race is cleared.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_chair_body.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopchairbody_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopchairbody_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	root.get_node("Campaign").new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var Chair: GDScript = load("res://scripts/chair_race.gd")
	var Track: GDScript = load("res://scripts/chair_track.gd")
	var race = Chair.new()
	race.setup({"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0, "skill": 1.0}, ["Alan"], RandomNumberGenerator.new())
	var specs := [
		{"key": "You", "character": "office_adult", "custom": false, "color": Color.WHITE, "label": "YOU"},
		{"key": "You2", "character": "office_dan", "custom": false, "color": Color.WHITE, "label": "P2", "rider": true, "look": {}},
	]
	var track = Track.new()
	track.setup(current_scene, race, 0.0, specs)
	await _wait(3)
	ok(track.puppets.has("You") and track.puppets.has("You2"), "both pilots have a puppet")
	ok(track.puppets.You.chair.visible and not track.puppets.You2.chair.visible, "but only one chair is drawn")
	ok(not players.node(1).visible, "player 2's own body is hidden while they ride")
	ok(track.puppets.You2.node.position.x == track.puppets.You.node.position.x, "the rider sits on the same spot as the driver")
	track.clear()
	await _wait(3)
	ok(players.node(1).visible and players.node(0).visible, "clearing the race shows both bodies again")
	players.enable_coop(false)
	print("coop_chair_body: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
