extends SceneTree
# gdlint:disable=max-line-length
# X12 housekeeping: Jen's walk from the main floor to her desk through the extra rooms, as a path test (it was a "live check" on
# the list). Jen comes in at the front door of the main floor; her desk is Seat1 of cubicle_two, two doors away.
#   1. the route: main floor -> cubicle area (the door at its right edge, ToCubicleTwo) -> cubicle two, and the same way back;
#      every door of the route is inside its room and lands on a spawn point the next room has;
#   2. off screen (nobody watching): the World walks her leg by leg through the same rooms and she ends at work at her desk;
#   3. on screen: in the real scenes she walks to each door, leaves through it, shows up at the next room's spawn and sits down
#      at Seat1 (the scene follows her from room to room).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/jen_walk.gd

const ROUTE := ["main_floor", "cubicle_area", "cubicle_two"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _room() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _goto(name: String) -> void:
	change_scene_to_file("res://scenes/%s.tscn" % name)
	var n := 0
	while (_room() != name or root.get_node("Game").busy) and n < 600:
		await process_frame
		n += 1
	await _wait(5)


# Jen has just come in at the front door: on the main floor, with the plan the World makes for somebody who is not at home
func _arrive(world: Node) -> Dictionary:
	var st: Dictionary = world.chars["Jen"]
	if st.node != null and is_instance_valid(st.node):
		st.node.queue_free()
	st.node = null
	st.scene = "main_floor"
	st.arrive = "from_outside"
	st.arriving = true
	st.following = false
	st.legs = world._plan("Jen")
	st.leg_t = st.legs[0].dur
	return st


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var data: Script = load("res://scripts/world_data.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	var cards := root.get_node("Cards")
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1
	world.time_scale = 1.0
	world.clock = 9.5
	world.meeting_gap = Vector2(1.0e6, 1.0e6)  # no all-hands in the middle of the walk
	world._meeting_t = 1.0e6
	root.get_node("Msp").enabled = false  # no phone call pulls her to the headset on the way

	# ---- 1. the route
	_check(world.chars.has("Jen") and str(world.row("Jen").home) == "cubicle_two" and str(world.row("Jen").seat) == "Seat1", "Jen's desk is Seat1 of cubicle two")
	var hops: Array = world._route("main_floor", "cubicle_two")
	var names := []
	for h in hops:
		names.append("%s>%s" % [str(h.from), str(h.to)])
	_check(names == ["main_floor>cubicle_area", "cubicle_area>cubicle_two"], "the way there is main floor, cubicle area, cubicle two (%s)" % str(names))
	_check(str(hops[1].name) == "ToCubicleTwo", "through the door at the cubicle area's right edge")
	var back: Array = world._route("cubicle_two", "main_floor")
	_check(back.size() == 2 and str(back[0].to) == "cubicle_area" and str(back[1].to) == "main_floor", "and the same two doors back")
	for h in hops + back:
		var from: Dictionary = data.SCENES[str(h.from)]
		var to: Dictionary = data.SCENES[str(h.to)]
		_check(float(h.x) >= float(from.x0) and float(h.x) <= float(from.x0 + from.W), "%s: the door %s (x %d) is inside the room" % [str(h.from), str(h.name), int(h.x)])
		_check(to.spawns.has(str(h.spawn)), "%s: it lands on the spawn %s of %s" % [str(h.name), str(h.spawn), str(h.to)])
		var at: float = float(to.spawns[str(h.spawn)][0])
		_check(at >= float(to.x0) and at <= float(to.x0 + to.W), "%s: that spawn (x %d) is inside %s" % [str(h.name), int(at), str(h.to)])
	var seat_x: float = float(data.SCENES.cubicle_two.seats.Seat1)
	_check(seat_x >= 0.0 and seat_x <= 368.0, "her seat (x %d) is in the room" % int(seat_x))

	# ---- 2. off screen: the World walks her through the rooms
	var st := _arrive(world)
	var kinds := []
	for leg in st.legs:
		kinds.append(str(leg.kind))
	_check(kinds == ["travel", "travel", "work"], "arriving, her plan is two doors and then work (%s)" % str(kinds))
	_check(int(st.legs[0].target_x) == int(hops[0].x) and int(st.legs[1].target_x) == int(hops[1].x), "she heads for the two doors of the route")
	var total := 0.0
	for leg in st.legs.slice(0, 2):
		total += float(leg.dur)
	_check(total > 8.0 and total < 40.0, "the walk takes %d seconds off screen" % int(total))
	var seen := ["main_floor"]
	guard = 0
	while guard < 5 and not (str(st.scene) == "cubicle_two" and str(st.legs[0].kind) == "work"):
		world._finish_leg("Jen")
		if seen[-1] != str(st.scene):
			seen.append(str(st.scene))
		guard += 1
	_check(seen == ROUTE, "off screen she passes main floor, cubicle area, cubicle two (%s)" % str(seen))
	_check(str(st.legs[0].kind) == "work" and bool(st.legs[0].seated) and int(st.legs[0].target_x) == int(seat_x), "and ends at work at her desk")
	_check(world.lights_on("cubicle_two"), "the lights of her room are on")

	# ---- 3. on screen: the scene follows her from room to room
	st = _arrive(world)
	await _goto("main_floor")
	var walked := []
	for i in ROUTE.size():
		var room: String = ROUTE[i]
		if _room() != room:
			await _goto(room)
		var node: Node = st.node
		_check(node != null and is_instance_valid(node) and str(st.scene) == room, "%s: Jen is in the room" % room)
		if node == null or not is_instance_valid(node):
			break
		var x0: float = node.global_position.x
		walked.append(room)
		if i < ROUTE.size() - 1:
			var door_x: float = float(hops[i].x)
			var spawn_x: float = float(data.SCENES[room].spawns[str(st.arrive)][0])
			_check(absf(x0 - spawn_x) < 24.0, "%s: she starts at the %s spawn (x %d)" % [room, str(st.arrive), int(x0)])
			var closest := absf(x0 - door_x)
			guard = 0
			while str(st.scene) == room and guard < 60 * 40:
				if is_instance_valid(node):
					closest = minf(closest, absf(node.global_position.x - door_x))
				await process_frame
				guard += 1
			_check(str(st.scene) == ROUTE[i + 1], "%s: she leaves through %s to %s (after %.1f s)" % [room, str(hops[i].name), ROUTE[i + 1], guard / 60.0])
			_check(closest < 6.0, "%s: she walked all the way to the door (closest %.1f px)" % [room, closest])
		else:
			guard = 0
			while guard < 60 * 40 and not (is_instance_valid(node) and node.seat != null and node.state != "sitdown"):
				await process_frame
				guard += 1
			_check(is_instance_valid(node) and node.seat != null and str(node.seat.name) == "Seat1", "%s: she sits down at Seat1 (after %.1f s)" % [room, guard / 60.0])
			_check(is_instance_valid(node) and absf(node.global_position.x - node.seat.global_position.x) < 2.0, "at her desk")
			await _wait(120)
			_check(is_instance_valid(node) and str(node.sprite.animation).begins_with("type_") or str(node.sprite.animation).begins_with("sit"), "and gets to work (%s)" % (str(node.sprite.animation) if is_instance_valid(node) else "gone"))
	_check(walked == ROUTE, "on screen she was seen in all three rooms, in order")
	print("jen_walk: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
