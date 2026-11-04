extends SceneTree
# The warehouse (chair race phase 1): a 1480 px room. It loads with its effects and props, every prop stands on the floor line,
# the walkway is clear, the loose race props are parked off the lane, the player walks from the entry door to the dock in every
# output format with the camera always inside the art, and the cast routes through the map are unchanged. Headless.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/warehouse.gd

var failures := 0


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


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	var world := root.get_node("World")
	game.title_mode = false
	root.get_node("Campaign").new_game(root.get_node("Campaign").FREE)

	change_scene_to_file("res://scenes/warehouse.tscn")
	_check(await _wait_scene("warehouse"), "the warehouse loads")
	var room := current_scene
	var bg: Sprite2D = room.get_node("Background")
	var art_w := bg.texture.get_size().x
	_check(art_w >= 1280.0, "the room is long (%d px wide, the old widest set is 368)" % int(art_w))
	for fx_name in ["FlickerLamp", "BenchScreen", "TreeLights", "Switch", "DartBoard"]:
		_check(room.get_node_or_null("Fx/" + fx_name) != null, "effect " + fx_name)
	_check(room.get_node_or_null("Interactables/DoorToCloset") != null, "a steel door back to the closet")
	_check(room.get_node_or_null("Interactables/ExitToCloset") != null, "the left edge leaves to the closet")
	_check(room.get_node_or_null("Spawns/from_main") != null and room.get_node_or_null("Spawns/from_closet") != null and room.get_node_or_null("Spawns/from_outing") != null, "entry spawns + from_outing")
	_check(room.get_node("Interactables/UseDartBoard").low_priority, "the dart board zone is low priority")

	# ---- props: all on the floor line, the walkway (feet y 110 to 127) is clear
	var actors := room.get_node("Actors")
	var sprites := 0
	var race := 0
	var bad := []
	for c in actors.get_children():
		if not (c is Sprite2D):
			continue
		sprites += 1
		var base: float = c.position.y  # the node sits on its sort line
		var bottom: float = base + c.offset.y + c.texture.get_size().y - 1.0
		if base > 110.0 or base < 85.0 or absf(bottom - base) > 12.0:
			bad.append("%s base %.0f bottom %.0f" % [c.name, base, bottom])
		if c.is_in_group("race_prop"):
			race += 1
	_check(bad.is_empty(), "every prop stands on the floor against the wall (%d props) %s" % [sprites, str(bad)])
	_check(race == 6, "six loose race props, parked off the lane (%d)" % race)
	for name in ["cone", "wet_sign", "oil_puddle", "pallet_small", "box_stack", "trash_can"]:
		var found := false
		for c in actors.get_children():
			if c.name.begins_with("race_" + name):
				found = true
		_check(found, "loose prop race_" + name)
	_check(room.get_node_or_null("Actors/overhead_door_0") != null, "the overhead door is its own sprite")

	# ---- the player walks the whole length at every format
	var player: CharacterBody2D = actors.get_node("Player")
	var x0: float = bg.position.x
	for fmt in ["wide", "h", "v"]:
		game.set_format(fmt)
		change_scene_to_file("res://scenes/warehouse.tscn")
		await _wait_scene("warehouse")
		room = current_scene
		player = room.get_node("Actors/Player")
		for c in room.get_node("Actors").get_children():
			if "routine" in c:
				c.queue_free()
		var half: float = float(game.FORMATS[fmt].size.x) * 0.5 / float(game.FORMATS[fmt].zoom)
		var cam := _cam()
		_check(cam != null, "%s: a follow camera runs in the long room" % fmt)
		Input.action_press("move_right")
		Input.action_press("run")
		var frames := 0
		var worst_out := 0.0
		var lost_player := false
		var start_x := player.global_position.x
		while player.global_position.x < x0 + art_w - 40.0 and frames < 2400:
			await process_frame
			frames += 1
			if frames % 5 == 0 and cam != null:
				var c := cam.get_screen_center_position()
				worst_out = maxf(worst_out, maxf(x0 - (c.x - half), (c.x + half) - (x0 + art_w)))
				if absf(c.x - player.global_position.x) > half - 4.0:
					lost_player = true
		Input.action_release("move_right")
		Input.action_release("run")
		var walked := player.global_position.x - start_x
		_check(_scene_name() == "warehouse", "%s: still in the warehouse at the dock end" % fmt)
		_check(walked > art_w - 140.0, "%s: walked %d px, entry to dock in %d frames" % [fmt, int(walked), frames])
		_check(worst_out <= 1.5, "%s: the camera stays inside the art (worst %.1f px out)" % [fmt, worst_out])
		_check(not lost_player, "%s: the player stays on screen" % fmt)
		_check(absf(player.global_position.y - 118.0) < 2.0, "%s: feet on the floor line" % fmt)
		# and back to the start: the left edge leaves for the closet
		Input.action_press("move_left")
		Input.action_press("run")
		frames = 0
		while _scene_name() == "warehouse" and frames < 2400:
			await process_frame
			frames += 1
		Input.action_release("move_left")
		Input.action_release("run")
		await _wait_scene("network_closet")
		_check(_scene_name() == "network_closet", "%s: the left end leads back to the network closet" % fmt)
		var cp: Node2D = current_scene.get_node("Actors/Player")
		_check(cp.global_position.x > 100.0, "%s: back in the closet at the warehouse end (x %d)" % [fmt, int(cp.global_position.x)])
	game.set_format("wide")

	# ---- the closet's right end enters the warehouse
	change_scene_to_file("res://scenes/network_closet.tscn")
	await _wait_scene("network_closet")
	var ex: Node2D = current_scene.get_node("Interactables/ExitToWarehouse")
	current_scene.get_node("Actors/Player").global_position = Vector2(ex.global_position.x, 118)
	await _wait_scene("warehouse")
	_check(_scene_name() == "warehouse", "the closet's right end leads into the warehouse")

	# ---- the cast: the map still routes as before, and nobody routes through the warehouse
	var data := load("res://scripts/world_data.gd")
	_check(data.SCENES.has("warehouse"), "the warehouse is in the world data")
	var expect := {
		["main_floor", "network_closet"]: ["cubicle_area", "network_closet"],
		["main_floor", "conference"]: ["cubicle_area", "conference"],
		["office_one", "kitchenette"]: ["main_floor", "kitchenette"],
		["kitchenette", "bathroom"]: ["bathroom"],
		["network_closet", "main_floor"]: ["cubicle_area", "main_floor"],
	}
	for pair in expect:
		var hops := []
		for h in world._route(pair[0], pair[1]):
			hops.append(h.to)
		_check(hops == expect[pair], "route %s -> %s unchanged %s" % [pair[0], pair[1], str(hops)])
	var through := 0
	for a in data.SCENES:
		for b in data.SCENES:
			if a == b or a == "warehouse" or b == "warehouse":
				continue
			for h in world._route(a, b):
				if h.to == "warehouse":
					through += 1
	_check(through == 0, "no cast route passes through the warehouse")
	_check(not world._route("main_floor", "warehouse").is_empty(), "the warehouse can be reached from the main floor (closet)")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
