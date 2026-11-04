extends SceneTree
# gdlint:disable=max-line-length
# The warehouse (chair race phase 1): a 1480 px room. It loads with its effects and props, every prop stands on the floor line,
# the walkway is clear, the loose race props are parked off the lane, the player walks from the entry door to the dock in every
# output format with the camera always inside the art, and the cast routes through the map (the closet trip passes through it). Headless.
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
	_check(room.get_node_or_null("Interactables/DoorToKitchenette") != null, "a steel door back to the kitchenette")
	_check(room.get_node_or_null("Interactables/ExitToKitchenette") != null, "the left edge leaves to the kitchenette")
	_check(room.get_node_or_null("Interactables/DoorToCloset") != null, "the blue steel door to the closet")
	var spawns := ["from_kitchenette", "from_closet", "from_outing"].filter(func(n: String) -> bool: return room.get_node_or_null("Spawns/" + n) != null)
	_check(spawns.size() == 3, "entry spawns + from_outing")
	_check(room.get_node("Interactables/UseDartBoard").low_priority, "the dart board zone is low priority")
	# R21: the cornhole boards, the bag tray and the grill are E zones with their own effect node (drawn in code, nothing solid on the floor)
	for pair in [["UseBoardA", "BoardA", "cornhole_a"], ["UseBoardB", "BoardB", "cornhole_b"], ["UseBagTray", "BagTray", "cornhole_tray"], ["UseGrill", "Grill", "grill"]]:
		var zone := room.get_node_or_null("Interactables/" + str(pair[0]))
		var fx_node := room.get_node_or_null("Fx/" + str(pair[1]))
		_check(zone != null and fx_node != null and fx_node.kind == pair[2] and zone.target == zone.get_path_to(fx_node), "%s starts the outing through the %s effect" % [pair[0], pair[2]])
	var corn_x: Array = []
	for zone_name in ["UseBoardA", "UseBoardB"]:
		corn_x.append(room.get_node("Interactables/" + zone_name).position.x)
	_check(corn_x[0] > -556.0 + 1098.0 and corn_x[1] < -556.0 + 1287.0 and corn_x[1] - corn_x[0] > 80.0, "the boards stand between the FINISH line (1098) and the door (1287), far enough apart to throw")

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
		# and back to the start: the left edge leaves for the kitchenette
		Input.action_press("move_left")
		Input.action_press("run")
		frames = 0
		while _scene_name() == "warehouse" and frames < 2400:
			await process_frame
			frames += 1
		Input.action_release("move_left")
		Input.action_release("run")
		await _wait_scene("kitchenette")
		_check(_scene_name() == "kitchenette", "%s: the left end leads back to the kitchenette" % fmt)
		var cp: Node2D = current_scene.get_node("Actors/Player")
		_check(cp.global_position.x > 150.0, "%s: back in the kitchenette beside the steel door (x %d)" % [fmt, int(cp.global_position.x)])
	game.set_format("wide")

	# ---- R21c: the overhead door, the switch and the outside
	change_scene_to_file("res://scenes/warehouse.tscn")
	await _wait_scene("warehouse")
	room = current_scene
	for c in room.get_node("Actors").get_children():
		if "routine" in c:
			c.queue_free()
	var sfx := root.get_node("Sfx")
	var outside_script := load("res://scripts/outside.gd")
	var hints := root.get_node("Hints")
	var bd: Node = room.get_node_or_null("Backdrop")
	_check(bd != null and room.get_node_or_null("Daylight") != null, "a Backdrop and a Daylight node")
	_check(bd != null and bd.get_index() < room.get_node("Background").get_index(), "the Backdrop is drawn behind the Background")
	_check(room.get_node("Background").texture.get_image().get_pixel(1300, 130).a == 0.0, "the doorway is a transparent hole in the baked art")
	_check(not room.get_node("Interactables/UseDoor").low_priority and not room.get_node("Interactables/UseDoorSwitch").low_priority, "the door and its switch are normal priority zones")
	var door: Node = room.get_node("Fx/Door")
	var plate: Node = room.get_node("Fx/DoorSwitch")
	var slats: Sprite2D = room.get_node("Actors/overhead_door_0")
	_check(door.open == 0.0 and door.goal == 0.0 and world.door_open == 0.0, "the door starts closed")
	_check(slats.region_enabled and slats.visible and int(slats.region_rect.size.y) == 82, "closed: the whole door sprite shows")
	_check(not bd.visible, "closed: the backdrop does not draw")
	# zone priority (the interact.gd nearest rule, like tests/prio.gd)
	var pl: CharacterBody2D = room.get_node("Actors/Player")
	var names := {}
	for at in [1347, 1422, 1047]:
		pl.global_position = Vector2(x0 + at, 118.0)
		pl._pick = null
		for i in 12:
			await process_frame
		var n: Node = pl.nearest()
		names[at] = "" if n == null else str(n.name)
	_check(names[1347] == "UseDoor" and names[1422] == "UseDoorSwitch" and names[1047] == "UseDartBoard", "E at the door, the switch and the dart board picks each one: %s" % str(names))
	# the switch opens it: 3 s, the rattle and the thunk, a toast
	sfx.clear_log()
	room.get_node("Interactables/UseDoorSwitch").use(pl)
	_check(door.goal == 1.0 and world.door_open == 1.0, "the switch asks for OPEN and the world remembers it")
	_check(hints.toast_text == "OPENING", "a toast says OPENING")
	for i in 60:
		await process_frame
	_check(door.open > 0.1 and door.open < 0.9 and slats.region_rect.size.y < 82.0 and slats.visible, "half way: the slats rise (open %.2f)" % door.open)
	_check(bd.visible and "door_rattle" in sfx.played, "while it moves the backdrop shows and the slats rattle")
	# pressing again while it moves reverses it
	room.get_node("Interactables/UseDoor").use(pl)
	_check(door.goal == 0.0 and world.door_open == 0.0 and hints.toast_text == "CLOSING", "pressing while it moves reverses it (CLOSING)")
	var guard := 0
	while door.open > 0.0 and guard < 600:
		await process_frame
		guard += 1
	_check(door.open == 0.0 and int(slats.region_rect.size.y) == 82 and slats.visible and "door_thunk" in sfx.played, "closed again: clip 82, thunk heard")
	# open all the way
	plate.door_press()
	guard = 0
	while door.open < 1.0 and guard < 600:
		await process_frame
		guard += 1
	_check(door.open == 1.0 and int(slats.region_rect.size.y) == 0 and not slats.visible, "open: the slats are gone from the doorway (clip 0)")
	_check(abs(guard - 180) < 40, "it takes about 3 s (%d frames at 60 fps)" % guard)
	for i in 4:
		await process_frame
	_check(room.get_node("Daylight").visible and room.get_node("Daylight").open == 1.0, "open: the daylight spill is on")
	# the lights switched off: the spill and the backdrop stay untinted
	world.set_lights("warehouse", false)
	for i in 30:
		await process_frame
	var plain: bool = room.get_node("Backdrop").modulate == Color(1, 1, 1, 1) and room.get_node("Daylight").modulate == Color(1, 1, 1, 1)
	_check(room.get_node("Background").modulate.r < 0.6 and plain and room.get_node("Daylight").visible, "lights out: the room goes dark, the outside and the daylight do not")
	world.set_lights("warehouse", true)
	# the walkway stays clear and the door sprite stays on its sort line
	_check(slats.position.y == 92.0 and room.get_node("Actors/Player").global_position.y >= 100.0, "the door does not touch the walkway")
	# darts: the closed door is a prop to stick into, the open one lets a dart out
	var nerf := root.get_node("Nerf")
	var mid := Vector2(x0 + 1347, 60.0)
	_check(nerf.door_gap(mid) and nerf.stick_target(mid) == null, "open: a dart at the doorway flies out")
	door.open = 0.0
	door.goal = 0.0
	door.door_apply()
	_check(not nerf.door_gap(mid) and nerf.stick_target(mid) == slats, "closed: a dart sticks into the door")
	# the sky follows the clock
	var morning: Dictionary = outside_script.phase(9.0)
	var noon: Dictionary = outside_script.phase(12.5)
	var dusk: Dictionary = outside_script.phase(17.0)
	var night: Dictionary = outside_script.phase(19.0)
	_check(morning.top != noon.top and noon.top != dusk.top and dusk.top != night.top, "the sky colour changes from morning to noon, dusk and night")
	var lum_noon: float = noon.top.get_luminance()
	_check(lum_noon > dusk.top.get_luminance() and dusk.top.get_luminance() > night.top.get_luminance(), "and gets darker toward closing")
	_check(dusk.bottom.r > dusk.bottom.b, "dusk is orange at the horizon")
	_check(outside_script.phase(8.0).top == outside_script.phase(8.5).top and outside_script.phase(23.0).top == night.top, "the clock is clamped at both ends")
	# the state is saved with the resume point and a new day starts closed
	world.door_open = 1.0
	var rs := root.get_node("Resume")
	var saved: Dictionary = rs.world_dict()
	_check(float(saved.get("door", -1.0)) == 1.0, "the resume point records the door")
	world.door_open = 0.0
	rs.apply_world(saved)
	_check(world.door_open == 1.0, "a resumed day keeps the door open")
	world.begin_next_day(world.day + 1)
	_check(world.door_open == 0.0, "a new day starts with the door closed")

	# ---- the cast: the map still routes as before, and nobody routes through the warehouse
	var data := load("res://scripts/world_data.gd")
	_check(data.SCENES.has("warehouse"), "the warehouse is in the world data")
	var expect := {
		["main_floor", "conference"]: ["cubicle_area", "conference"],
		["office_one", "kitchenette"]: ["main_floor", "kitchenette"],
		["kitchenette", "bathroom_1"]: ["bathroom_1"],
		["kitchenette", "bathroom_2"]: ["bathroom_2"],
		["main_floor", "warehouse"]: ["kitchenette", "warehouse"],
		["network_closet", "main_floor"]: ["warehouse", "kitchenette", "main_floor"],
	}
	for pair in expect:
		var hops := []
		for h in world._route(pair[0], pair[1]):
			hops.append(h.to)
		_check(hops == expect[pair], "route %s -> %s %s" % [pair[0], pair[1], str(hops)])
	var through := 0
	for a in data.SCENES:
		for b in data.SCENES:
			if a == b or a == "warehouse" or b == "warehouse" or a == "network_closet" or b == "network_closet" or a == "warehouse_lot" or b == "warehouse_lot":
				continue
			for h in world._route(a, b):
				if h.to == "warehouse":
					through += 1
	_check(through == 0, "only the closet trip passes through the warehouse")
	_check(not world._route("main_floor", "warehouse").is_empty(), "the warehouse can be reached from the main floor (kitchenette)")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
