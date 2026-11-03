extends SceneTree
# Dart hit boxes match the art: a standing person is about 62 px tall, so a lob over a near coworker's head
# does not hit them, and it can come down on the one behind.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var nerf := root.get_node("Nerf")
	root.get_node("Game").title_mode = false
	c.new_game("free")
	var world := root.get_node("World")
	world.time_scale = 1.0
	for who in ["Alan", "Dan"]:
		world.chars[who].scene = "main_floor"
		world.force_activity(who, "work")
	change_scene_to_file("res://scenes/main_floor.tscn")
	for i in 40:
		await process_frame
	var scene := current_scene
	var a := scene.get_node_or_null("Actors/Alan")
	var d := scene.get_node_or_null("Actors/Dan")
	_check(a != null and d != null, "Alan and Dan are in the room")
	if a == null or d == null:
		quit(1)
		return
	for n in [a, d]:
		n.seat = null
		n.state = "idle"
		n._hold = 99.0
	a.global_position = Vector2(100.0, 118.0)
	d.global_position = Vector2(160.0, 118.0)
	_check(is_equal_approx(nerf.body_height(a), nerf.BODY_H), "a standing person is %d px tall for a dart" % int(nerf.BODY_H))
	_check(not nerf._hits(a, Vector2(100.0, 118.0 - 70.0), null), "a dart 70 px up flies over Alan's head")
	_check(not nerf._hits(a, Vector2(100.0, 118.0 - 64.0), null), "even 64 px up misses (the art is about 62 px)")
	_check(nerf._hits(a, Vector2(100.0, 118.0 - 50.0), null), "a dart at chest height hits him")
	_check(nerf._hits(d, Vector2(160.0, 118.0 - 30.0), null), "and one coming down at Dan's waist hits Dan")
	# a lob from the left: passes over Alan, comes down on Dan
	var pos := Vector2(40.0, 60.0)
	var vel := Vector2(70.0, -45.0)
	var hit: Node = null
	var passed_alan := false
	for i in 400:
		pos += vel * 0.01
		vel.y += 75.0 * 0.01
		if nerf._hits(a, pos, null):
			hit = a
			break
		if absf(pos.x - 100.0) < 8.0:
			passed_alan = true
		if nerf._hits(d, pos, null):
			hit = d
			break
	_check(passed_alan, "the lob passes Alan's column over his head")
	_check(hit == d, "and it hits Dan behind him, not Alan")
	# seated people are lower still
	a.seat = scene.get_node_or_null("Interactables/Seat1")
	if a.seat != null:
		_check(is_equal_approx(nerf.body_height(a), nerf.SEATED_H), "a seated person is lower (%d px)" % int(nerf.SEATED_H))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
