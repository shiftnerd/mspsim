extends SceneTree
# gdlint:disable=max-line-length
# The parking lot outside the warehouse dock (R21c follow-up, scene warehouse_lot): a closed overhead door blocks the way out,
# an open one lets you walk out (E at the doorway zone) and the lot has a doorway and a left edge back in (spawn at the door),
# the door state survives the trip, the sky and the tint follow the game clock, the street lights glow at night, the player
# walks the whole length at wide / h / v with the camera inside the art, the resume point names the room, and nobody from the
# cast routes through it. Headless.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/warehouse_lot.gd

var failures := 0
var data: GDScript = load("res://scripts/world_data.gd")


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _wait_scene(name: String) -> bool:
	var n := 0
	while _scene_name() != name and n < 400:
		await process_frame
		n += 1
	for i in 5:
		await process_frame
	n = 0
	while root.get_node("Game").busy and n < 200:
		await process_frame
		n += 1
	return _scene_name() == name


func _cam() -> Camera2D:
	for c in current_scene.get_children():
		if c is Camera2D:
			return c
	return null


func _quiet() -> void:
	for c in current_scene.get_node("Actors").get_children():
		if "routine" in c:
			c.queue_free()


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	var world := root.get_node("World")
	var outside := load("res://scripts/outside.gd")
	game.title_mode = false
	root.get_node("Campaign").new_game(root.get_node("Campaign").FREE)
	world.door_open = 0.0

	# ---- the warehouse side: the doorway is a zone that only works while the overhead door is all the way up
	change_scene_to_file("res://scenes/warehouse.tscn")
	await _wait_scene("warehouse")
	var room := current_scene
	_quiet()
	var dock: Node = room.get_node_or_null("Interactables/DoorToLot")
	_check(dock != null and dock.special == "dock" and dock.target_scene == "warehouse_lot" and dock.target_spawn == "from_warehouse", "the warehouse has a doorway zone to the lot")
	_check(room.get_node_or_null("Spawns/from_lot") != null, "the warehouse has a from_lot spawn")
	var door: Node = room.get_node("Fx/Door")
	var pl: CharacterBody2D = room.get_node("Actors/Player")
	_check(dock.is_locked(), "closed door: the doorway is locked")
	pl.global_position = Vector2(dock.global_position.x, 118.0)
	dock.use(pl)
	for i in 30:
		await process_frame
	_check(_scene_name() == "warehouse", "closed door: E at the doorway does not leave")
	room.get_node("Fx/DoorSwitch").door_press()  # up
	for i in 40:
		await process_frame
	_check(dock.is_locked(), "while it rolls up the doorway is still locked (open %.2f)" % door.open)
	var guard := 0
	while door.open < 1.0 and guard < 600:
		await process_frame
		guard += 1
	_check(door.open == 1.0 and not dock.is_locked(), "all the way up: the doorway is open")
	_check(world.door_open == 1.0, "the world remembers the open door")
	pl.global_position = Vector2(dock.global_position.x, 118.0)
	dock.use(pl)
	_check(await _wait_scene("warehouse_lot"), "open door: E at the doorway leads out to the lot")

	# ---- the lot
	room = current_scene
	_quiet()
	pl = room.get_node("Actors/Player")
	var spawn_x: float = float(data.SCENES["warehouse_lot"].spawns["from_warehouse"][0])
	_check(absf(pl.global_position.x - spawn_x) < 6.0 and spawn_x < 130.0, "arrive at the dock doorway (x %d)" % int(pl.global_position.x))
	_check(world.door_open == 1.0, "the door is still open outside")
	var bg: Sprite2D = room.get_node("Background")
	var art_w := bg.texture.get_size().x
	_check(art_w >= 760.0 and art_w <= 800.0, "the lot is %d px wide" % int(art_w))
	var bd: Node = room.get_node_or_null("Backdrop")
	_check(bd != null and bd.mode == "lot" and bd.get_index() < bg.get_index() and bd.visible, "the sky backdrop sits behind the art and always draws")
	var img := bg.texture.get_image()
	_check(img.get_pixel(400, 20).a == 0.0 and img.get_pixel(400, 300).a == 1.0, "the sky is a hole in the art, the asphalt is solid")
	var pieces := []
	for c in room.get_node("Actors").get_children():
		if c is Sprite2D:
			pieces.append(str(c.name).rstrip("_0123456789"))
	for want in ["lot_sedan", "lot_hatch", "lot_van", "lot_dumpster", "lot_pole"]:
		_check(pieces.has(want), "the lot has a " + want)
	_check(room.get_node_or_null("Interactables/DoorToWarehouse") != null and room.get_node_or_null("Interactables/ExitToWarehouse") != null, "a doorway and the left edge lead back in")
	_check(not room.get_node("Interactables/DoorToWarehouse").is_locked(), "the way back in is never locked")
	# the sky follows the clock: the tint of the whole picture and the glow of the street lights
	world.clock = 12.5
	await process_frame
	await process_frame
	var noon_tint: Color = bg.modulate
	_check(absf(noon_tint.g - outside.phase(12.5).tint.g) < 0.01 and noon_tint.r > 0.99, "noon: the picture takes the noon colour")
	world.clock = 18.5
	await process_frame
	await process_frame
	var night_tint: Color = bg.modulate
	_check(night_tint.b > night_tint.r and night_tint.get_luminance() < noon_tint.get_luminance() - 0.3, "night: the picture goes dark and blue")
	_check(room.get_node("Actors").modulate.is_equal_approx(night_tint), "and so do the people in it")
	_check(outside.lamp(12.5) == 0.0 and outside.lamp(18.5) == 1.0 and outside.lamp(17.2) > 0.0, "the street lights come on in the evening")
	_check(room.get_node_or_null("Lamp0") != null and room.get_node_or_null("Lamp1") != null and room.get_node("Lamp0").mode == "lamp", "two glowing street lights")
	world.clock = 9.0

	# ---- walk the whole length at every format, then leave by the left edge
	var x0: float = bg.position.x
	for fmt in ["wide", "h", "v"]:
		game.set_format(fmt)
		change_scene_to_file("res://scenes/warehouse_lot.tscn")
		await _wait_scene("warehouse_lot")
		room = current_scene
		_quiet()
		pl = room.get_node("Actors/Player")
		var half: float = float(game.FORMATS[fmt].size.x) * 0.5 / float(game.FORMATS[fmt].zoom)
		var cam := _cam()
		_check(cam != null, "%s: a follow camera runs in the lot" % fmt)
		Input.action_press("move_right")
		Input.action_press("run")
		var frames := 0
		var worst_out := 0.0
		var start_x := pl.global_position.x
		while pl.global_position.x < x0 + art_w - 40.0 and frames < 2400:
			await process_frame
			frames += 1
			if frames % 5 == 0 and cam != null:
				var c := cam.get_screen_center_position()
				worst_out = maxf(worst_out, maxf(x0 - (c.x - half), (c.x + half) - (x0 + art_w)))
		Input.action_release("move_right")
		Input.action_release("run")
		_check(_scene_name() == "warehouse_lot" and pl.global_position.x - start_x > art_w - 150.0, "%s: walked %d px to the fence end" % [fmt, int(pl.global_position.x - start_x)])
		_check(worst_out <= 1.5, "%s: the camera stays inside the art (worst %.1f px out)" % [fmt, worst_out])
		Input.action_press("move_left")
		Input.action_press("run")
		frames = 0
		while _scene_name() == "warehouse_lot" and frames < 2400:
			await process_frame
			frames += 1
		Input.action_release("move_left")
		Input.action_release("run")
		_check(await _wait_scene("warehouse"), "%s: the left edge leads back into the warehouse" % fmt)
		var back: Node2D = current_scene.get_node("Actors/Player")
		var want_x: float = float(data.SCENES["warehouse"].spawns["from_lot"][0])
		_check(absf(back.global_position.x - want_x) < 6.0, "%s: back at the dock doorway (x %d)" % [fmt, int(back.global_position.x)])
		_check(current_scene.get_node("Fx/Door").open == 1.0 and world.door_open == 1.0, "%s: the door is still open" % fmt)
		_check(current_scene.get_node("Interactables/DoorToLot").is_locked() == false, "%s: and the doorway still works" % fmt)
	game.set_format("wide")

	# ---- the doorway of the lot (E) leads in as well
	change_scene_to_file("res://scenes/warehouse_lot.tscn")
	await _wait_scene("warehouse_lot")
	room = current_scene
	pl = room.get_node("Actors/Player")
	var inner: Node2D = room.get_node("Interactables/DoorToWarehouse")
	pl.global_position = Vector2(inner.global_position.x, 118.0)
	inner.use(pl)
	_check(await _wait_scene("warehouse"), "E at the lot's doorway leads back in")

	# ---- the resume point and the new day
	change_scene_to_file("res://scenes/warehouse_lot.tscn")
	await _wait_scene("warehouse_lot")
	var rs := root.get_node("Resume")
	var camp := root.get_node("Campaign")
	var pd: Dictionary = rs.player_dict()
	var wd: Dictionary = rs.world_dict()
	_check(str(pd.get("room", "")) == "warehouse_lot" and float(wd.get("door", -1.0)) == 1.0, "the resume point names the lot and the open door")
	camp._resume_scene = ""
	rs.apply_player(pd)
	_check(camp._resume_scene == "warehouse_lot", "resuming opens the lot")
	camp._resume_scene = ""
	world.door_open = 0.0
	rs.apply_world(wd)
	_check(world.door_open == 1.0, "and the door is open again")
	change_scene_to_file("res://scenes/warehouse_lot.tscn")
	await _wait_scene("warehouse_lot")
	_check(world.door_open == 1.0 and current_scene.get_node("Interactables/DoorToWarehouse") != null, "the lot loads with the resumed state")
	world.begin_next_day(world.day + 1)
	_check(world.door_open == 0.0, "the next day starts with the door closed")

	# ---- the map: a dead end past the warehouse; nobody is sent out there
	var info: Dictionary = data.SCENES["warehouse_lot"]
	_check(info.links.size() == 2 and info.links.all(func(l: Dictionary) -> bool: return l.to == "warehouse" and l.spawn == "from_lot"), "the lot only links back to the warehouse")
	var hops := []
	for h in world._route("warehouse_lot", "main_floor"):
		hops.append(h.to)
	_check(hops == ["warehouse", "kitchenette", "main_floor"], "route lot -> main floor %s" % str(hops))
	var cast_in := 0
	for n in world.chars:
		if str(world.chars[n].scene) == "warehouse_lot":
			cast_in += 1
		for l in world.chars[n].legs:
			if str(l.get("scene", "")) == "warehouse_lot" or str(l.get("to_scene", "")) == "warehouse_lot":
				cast_in += 1
	_check(cast_in == 0, "no cast member is in or headed for the lot")
	var through := 0
	for a in data.SCENES:
		for b in data.SCENES:
			if a == b or a == "warehouse_lot" or b == "warehouse_lot":
				continue
			for h in world._route(a, b):
				if h.to == "warehouse_lot":
					through += 1
	_check(through == 0, "no route between other rooms passes through the lot")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
