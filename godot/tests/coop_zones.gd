extends SceneTree
# Co-op phase 1: door / seat / interact / talk zones keep a LIST of bodies (the arrow stays for the player still inside when
# the other leaves), a chair holds one player when co-op is on, and single player is unchanged with the flag off.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_zones.gd

var fails := 0
var stage: Node
var p1: Node
var p2: Node


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _init() -> void:
	_run.call_deferred()


func _collect(n: Node, out: Array, kind: String) -> void:
	if n is Area2D:
		if kind == "door" and "target_scene" in n:
			out.append(n)
		elif kind == "seat" and "stand_y" in n and "occupied" in n:
			out.append(n)
		elif kind == "interact" and "low_priority" in n and "target" in n:
			out.append(n)
	for c in n.get_children():
		_collect(c, out, kind)


# a spot well away from x (and from the edge exits at the room's ends)
func _far(x: float) -> float:
	return clampf(x - 120.0 if x > 184.0 else x + 120.0, 70.0, 300.0)


func _put(body: Node, at: Vector2) -> void:
	body.global_position = at
	body.velocity = Vector2.ZERO


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_coopzones_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopzones_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	stage = current_scene
	p1 = stage.get_node("Actors/Player")
	var doors := []
	_collect(stage, doors, "door")
	var door: Node = null
	for d in doors:
		if not d.auto and d.special == "" and not d.locked and d.occupancy == "":
			door = d
			break
	var seats := []
	_collect(stage, seats, "seat")
	var seat: Node = seats[0]
	ok(door != null and not seats.is_empty(), "main_floor has a plain door and seats (%d doors)" % doors.size())

	# ---- flag off: the single body path is unchanged
	var away := Vector2(_far(door.global_position.x), 118)
	_put(p1, door.global_position)
	await _wait(8)
	ok(door._bodies.size() == 1 and door._arrow.visible, "flag off: one body at the door shows the arrow")
	_put(p1, away)
	await _wait(8)
	ok(door._bodies.is_empty() and not door._arrow.visible, "flag off: the arrow goes when the body leaves")
	_put(p1, seat.global_position)
	await _wait(8)
	seat.use(p1)
	await _wait(4)
	ok(p1.state in ["sitdown", "sitting"] and not seat.occupied, "flag off: Seat.use leaves occupied false (as before)")
	await _wait(60)
	p1._stand_up()
	await _wait(40)
	ok(p1.state == "idle" and not seat.occupied, "flag off: standing up leaves occupied false")

	# ---- two bodies at one door
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	p2 = players.node(1)
	ok(p2 != null, "slot 1 is in")
	_put(p1, door.global_position)
	_put(p2, door.global_position + Vector2(3, 0))
	await _wait(8)
	ok(door._bodies.size() == 2, "the door lists both bodies")
	ok(p1.nearest() == door and p2.nearest() == door and door._arrow.visible, "both have the door; arrow shown")
	_put(p2, Vector2(_far(door.global_position.x), 118))
	await _wait(8)
	ok(door._bodies == [p1] and door._arrow.visible, "P2 left: the arrow STAYS for P1")
	_put(p2, door.global_position + Vector2(3, 0))
	await _wait(8)
	_put(p1, away)
	await _wait(8)
	ok(door._bodies == [p2] and door._arrow.visible, "P1 left: the arrow stays for P2")
	_put(p2, away + Vector2(30, 0))
	await _wait(8)
	ok(door._bodies.is_empty() and not door._arrow.visible, "both gone: the arrow is hidden")
	# a sitting player does not show the door arrow, the other still does
	_put(p1, door.global_position)
	_put(p2, door.global_position + Vector2(3, 0))
	await _wait(8)
	p1.state = "sitting"
	await _wait(3)
	ok(door._arrow.visible, "P1 'sitting' but P2 standing: arrow stays")
	p1.state = "idle"

	# ---- interact zone
	var zones := []
	_collect(stage, zones, "interact")
	var zone: Node = null
	for z in zones:
		var fx: Node = z.get_node(z.target)
		if fx.kind in ["bell", "tv"] or fx.busy:
			continue
		_put(p1, Vector2(z.global_position.x, 118))
		await _wait(6)
		if p1.nearest() == z:
			zone = z
			break
	ok(zone != null, "found an interact zone that P1 owns (%s)" % (zone.name if zone else "?"))
	if zone != null:
		_put(p1, Vector2(zone.global_position.x, 118))
		_put(p2, Vector2(zone.global_position.x + 1, 118))
		await _wait(8)
		ok(zone._bodies.size() == 2 and zone._arrow.visible, "the interact zone lists both bodies")
		_put(p2, Vector2(_far(zone.global_position.x), 118))
		await _wait(8)
		ok(zone._bodies == [p1] and zone._arrow.visible, "P2 left the interact zone: the arrow stays for P1")
		_put(p1, away)
		await _wait(8)
		ok(zone._bodies.is_empty() and not zone._arrow.visible, "nobody left: no arrow")

	# ---- seats: one body per chair when co-op is on
	_put(p1, away)
	_put(p2, away + Vector2(30, 0))
	await _wait(6)
	_put(p1, seat.global_position)
	_put(p2, seat.global_position)
	await _wait(8)
	ok(seat._bodies.size() == 2, "the seat lists both bodies")
	seat.use(p1)
	await _wait(3)
	ok(seat.occupied and p1.state in ["sitdown", "sitting"], "co-op: P1 sat and the seat is occupied")
	seat.use(p2)
	await _wait(3)
	ok(p2.state not in ["sitdown", "sitting"] and p2.seat == null, "the second player is refused the occupied seat")
	await _wait(60)
	ok(not seat._arrow.visible, "no sit arrow on an occupied chair")
	p1._stand_up()
	await _wait(45)
	ok(p1.state == "idle" and not seat.occupied, "standing up frees the seat")
	_put(p2, seat.global_position)
	await _wait(8)
	seat.use(p2)
	await _wait(3)
	ok(seat.occupied and p2.state in ["sitdown", "sitting"], "P2 can take it now")
	await _wait(60)
	# the player who leaves the tree while seated frees the chair
	players.leave(1)
	await _wait(4)
	ok(not seat.occupied, "slot 1 leaving while seated frees the chair")

	# ---- spawn order: P2 is placed before it is added, so nothing fires at (0, 0)
	var autos := []
	_collect(stage, autos, "door")
	var auto_door: Node = null
	for d in autos:
		if d.auto:
			auto_door = d
			break
	ok(auto_door != null, "the room has an auto edge exit")
	_put(p1, Vector2(184, 118))
	await _wait(4)
	var before := current_scene
	players.join(1, 1)
	await _wait(30)
	ok(current_scene == before and players.node(1) != null, "joining in the middle of the room: no scene change")
	ok(players.node(1).global_position.x > 100.0, "...and the body was placed before it entered the tree (x=%.0f, not 0)" % players.node(1).global_position.x)

	print("failures=", fails)
	quit(1 if fails > 0 else 0)
