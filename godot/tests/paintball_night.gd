extends SceneTree
# R41: the paintball night match uses the painted night street (set and barricade pieces); a day match keeps the day art; the set
# geometry (size, props, sort lines) is the same. Dev: SHOT_OUT=C:/x/pb Godot --path godot -s res://tests/paintball_night.gd saves
# <SHOT_OUT>_day.png and <SHOT_OUT>_night.png (windowed, not headless).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/paintball_night.gd

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


func _match(o: Node, night: bool) -> Node:
	o.use_rooms = true
	o.start("paintball", false, {"night": night})
	await create_timer(2.5).timeout
	await _wait(10)
	o.press(KEY_ENTER)
	await _wait(20)
	return o.g.track


func _leave(o: Node) -> void:
	o.g.rules.you_auto = true
	var guard := 0
	while o.g.rules.phase != "over" and guard < 20000:
		o.g.rules.step(1.0 / 30.0)
		guard += 1
	await create_timer(2.5).timeout
	o.press(KEY_ENTER)
	await create_timer(2.5).timeout
	await _wait(10)
	if o.is_open:
		o.press(KEY_ENTER)
		await create_timer(2.0).timeout


func _shot(tag: String) -> void:
	var out := OS.get_environment("SHOT_OUT")
	if out == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, tag])


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_pbnight_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_pbnight_%d_settings.cfg" % pid
	var o := root.get_node("Outings")
	root.get_node("Campaign").new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	ok(ResourceLoader.exists("res://assets/sets/paintball_field_night.png"), "the night set texture exists")
	var day: Texture2D = load("res://assets/sets/paintball_field.png")
	var night_tex: Texture2D = load("res://assets/sets/paintball_field_night.png")
	ok(day.get_size() == night_tex.get_size(), "day and night sets are the same size (%s)" % str(night_tex.get_size()))
	for piece in ["crates", "barrels", "hay", "trough", "wagon", "cactus"]:
		var a: Texture2D = load("res://assets/props/pb_%s.png" % piece)
		var b: Texture2D = load("res://assets/props/pbn_%s.png" % piece)
		ok(a != null and b != null and a.get_size() == b.get_size(), "pbn_%s has the size of pb_%s" % [piece, piece])
	var track: Node = await _match(o, false)
	var scene := current_scene
	ok(scene.name == "PaintballField", "in the field")
	ok((scene.get_node("Background") as Sprite2D).texture.resource_path.ends_with("paintball_field.png"), "a day match keeps the day set")
	ok(not track._night_art, "no night art by day")
	await _shot("day")
	await _leave(o)
	track = await _match(o, true)
	scene = current_scene
	ok(track.night() and track._night_art, "a night match uses the painted night art")
	ok((scene.get_node("Background") as Sprite2D).texture.resource_path.ends_with("paintball_field_night.png"), "the background is the night set")
	var swapped := 0
	var total := 0
	for n in scene.get_node("Actors").get_children():
		if n is Sprite2D and n.name.begins_with("pb_"):
			total += 1
			if (n as Sprite2D).texture.resource_path.contains("pbn_"):
				swapped += 1
	ok(total >= 8 and swapped == total, "every barricade piece is its night version (%d of %d)" % [swapped, total])
	await _shot("night")
	await _leave(o)
	print("paintball_night: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
