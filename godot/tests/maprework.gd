extends SceneTree
# R24 map rework: the warehouse is reached through the kitchenette's steel door, and the network closet through the warehouse's
# blue steel door. Walks main floor -> kitchenette -> warehouse -> closet and back through the real doors and edges, checks the
# cubicle area has no closet door, and that the cast routes and the closet check take the new way. Headless.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/maprework.gd

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


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _spawn_x(scene: String, spawn: String) -> float:
	return float(data.SCENES[scene].spawns[spawn][0])


func _use_door(door: String) -> void:
	var d: Node2D = current_scene.get_node("Interactables/" + door)
	_player().global_position = Vector2(d.global_position.x, 118)
	d.use(_player())


func _edge(exit_name: String) -> void:
	var e: Node2D = current_scene.get_node("Interactables/" + exit_name)
	_player().global_position = Vector2(e.global_position.x, 118)


func _arrived(scene: String, spawn: String, what: String) -> void:
	_check(await _wait_scene(scene), what + ": in " + scene)
	var want := _spawn_x(scene, spawn)
	_check(absf(_player().global_position.x - want) < 6.0, "%s: at spawn %s (x %d, want %d)" % [what, spawn, int(_player().global_position.x), int(want)])


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	var world := root.get_node("World")
	game.title_mode = false
	root.get_node("Campaign").new_game(root.get_node("Campaign").FREE)

	# ---- the cubicle area has no closet door any more
	change_scene_to_file("res://scenes/cubicle_area.tscn")
	await _wait_scene("cubicle_area")
	var inter := current_scene.get_node("Interactables")
	var door_count := 0
	for c in inter.get_children():
		if c.name.begins_with("Door"):
			door_count += 1
	_check(door_count == 0 and inter.get_node_or_null("DoorCloset") == null, "the cubicle area has no door at all (no closet door)")
	_check(current_scene.get_node_or_null("Spawns/from_closet") == null, "the cubicle area has no from_closet spawn")
	var links_to_closet := 0
	for l in data.SCENES["cubicle_area"].links:
		if l.to == "network_closet":
			links_to_closet += 1
	_check(links_to_closet == 0, "no cubicle area link names the closet")
	_check(inter.get_node_or_null("ExitToMain") != null and inter.get_node_or_null("ExitToConference") != null, "its left and right edges still lead out")

	# ---- main floor -> kitchenette (left edge)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait_scene("main_floor")
	_edge("ExitToKitchen")
	await _arrived("kitchenette", "from_main", "main floor left edge")
	_check(current_scene.get_node_or_null("Interactables/DoorToWarehouse") != null, "the kitchenette has the warehouse door")
	_check(current_scene.get_node_or_null("Interactables/DoorBathLeft") != null and current_scene.get_node_or_null("Interactables/DoorBathRight") != null, "both bathroom doors are still there")

	# ---- kitchenette -> warehouse (steel door)
	_use_door("DoorToWarehouse")
	await _arrived("warehouse", "from_kitchenette", "kitchenette steel door")
	_check(current_scene.get_node_or_null("Interactables/DoorToCloset") != null, "the warehouse has the blue door")

	# ---- warehouse -> closet (blue door)
	_use_door("DoorToCloset")
	await _arrived("network_closet", "from_warehouse", "blue door")

	# ---- and back: closet door -> warehouse next to the blue door
	_use_door("DoorToWarehouse")
	await _arrived("warehouse", "from_closet", "closet door")
	var blue: Node2D = current_scene.get_node("Interactables/DoorToCloset")
	_check(absf(_player().global_position.x - blue.global_position.x) < 50.0, "you stand beside the blue door")

	# ---- warehouse left edge -> kitchenette beside the steel door, then the kitchenette's right edge -> main floor
	_edge("ExitToKitchenette")
	await _arrived("kitchenette", "from_warehouse", "warehouse left edge")
	var steel: Node2D = current_scene.get_node("Interactables/DoorToWarehouse")
	_check(absf(_player().global_position.x - steel.global_position.x) < 50.0, "you stand beside the steel door")
	_edge("ExitToMain")
	await _arrived("main_floor", "from_kitchen", "kitchenette right edge")

	# ---- the warehouse's own steel door returns to the kitchenette
	change_scene_to_file("res://scenes/warehouse.tscn")
	await _wait_scene("warehouse")
	_use_door("DoorToKitchenette")
	await _arrived("kitchenette", "from_warehouse", "warehouse steel door")

	# ---- the cast: routes, the closet check, no bathroom on the way
	var hops := []
	for h in world._route("main_floor", "network_closet"):
		hops.append(h.to)
	_check(hops == ["kitchenette", "warehouse", "network_closet"], "main floor -> closet goes through the kitchenette and the warehouse %s" % str(hops))
	hops = []
	for h in world._route("cubicle_area", "network_closet"):
		hops.append(h.to)
	_check(hops == ["main_floor", "kitchenette", "warehouse", "network_closet"], "cubicle area -> closet %s" % str(hops))
	for n in ["Dan", "Alan"]:
		var legs: Array = world.plan_for(n, "closet")
		var total := 0.0
		var scenes := []
		var baths := 0
		for l in legs:
			total += float(l.dur)
			scenes.append(str(l.get("scene", "")))
			if l.has("bath") or str(l.get("kind", "")) == "bathroom":
				baths += 1
		_check(scenes.has("warehouse") and scenes.has("network_closet") and scenes.has("kitchenette"), "%s closet trip walks kitchenette, warehouse, closet" % n)
		_check(baths == 0, "%s uses no bathroom on the way" % n)
		_check(total > 60.0 and total < 170.0, "%s closet trip takes a sane time (%d s)" % [n, int(total)])
		_check(str(legs[legs.size() - 1].kind) == "work", "%s goes back to work after" % n)
	# nobody else enters the warehouse: only the closet trip routes through it
	var through := 0
	for a in data.SCENES:
		for b in data.SCENES:
			if a == b or a == "warehouse" or b == "warehouse" or b == "network_closet" or a == "network_closet":
				continue
			for h in world._route(a, b):
				if h.to == "warehouse":
					through += 1
	_check(through == 0, "no other route passes through the warehouse")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
