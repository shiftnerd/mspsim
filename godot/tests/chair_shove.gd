extends SceneTree
# gdlint:disable=max-line-length
# CHAIR SHOVE (roadmap R12): standing next to a seated coworker's rolling chair, Shift + E pushes it: the chair, the seat and the
# coworker roll off together, stop inside the chair's limits, and scoot back to the desk after a moment; they react (Alan
# minds, a friend laughs, a cold coworker glares, one opinion change per person per 25 s), plain E still talks, a seat with
# nobody in it or no rolling chair is not pushed, a coworker who gets up sends the chair home, and ten pushes are PUSHY.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/chair_shove.gd

var shove_script: GDScript  # loaded once the autoloads are there (the script names Career, Social, Hints)

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _press(action: String, frames := 2) -> void:
	Input.action_press(action)
	await _wait(frames)
	Input.action_release(action)


func _shove_keys() -> void:
	Input.action_press("run")
	await _wait(2)
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	Input.action_release("run")
	await _wait(2)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	shove_script = load("res://scripts/chair_shove.gd")
	var pid := OS.get_process_id()
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var social := root.get_node("Social")
	var career := root.get_node("Career")
	root.get_node("Game").title_mode = false
	c.save_prefix = "user://test_%d_chairshove_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_chairshove_settings.cfg" % pid
	c.new_game("tech")
	c.day = 3
	career.reset_all()
	career.toasts = false
	world.time_scale = 1.0
	for who in ["Alan", "Dan"]:
		world.chars[who].scene = "main_floor"
		world.force_activity(who, "work")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(60)
	var scene := current_scene
	var p := scene.get_node("Actors/Player")
	# a coworker at a desk with a rolling chair (seat them if the routine has them on their feet)
	var who := ""
	var npc: Node = null
	for name in ["Alan", "Dan"]:
		var n := scene.get_node_or_null("Actors/" + name)
		if n != null and n.seat != null:
			who = name
			npc = n
			break
	if npc == null:
		for n in get_nodes_in_group("npcs"):
			if str(n.cast_name) != "" and n.seat != null and n.visible:
				npc = n
				who = str(n.cast_name)
				break
	ok(npc != null, "a coworker is seated on the main floor (%s)" % who)
	if npc == null:
		quit(1)
		return
	var seat: Node2D = npc.seat
	npc._hold = 0.0
	var home: float = seat.position.x
	var probe: Node = shove_script.new()
	scene.add_child(probe)
	var rolling_chair: bool = probe.begin(seat, npc)
	var lo: float = probe.roll.lo
	var hi: float = probe.roll.hi
	probe.queue_free()
	ok(rolling_chair and lo < -8.0, "their seat has a rolling chair with room to roll (lo %.1f, hi %.1f)" % [lo, hi])
	social.rel[who] = 0

	# plain E next to them is a conversation, not a push
	p.global_position = Vector2(seat.global_position.x + 14.0, 118.0)
	await _wait(10)
	ok(seat.get_node_or_null("ChairShove") == null and seat.position.x == home, "standing next to them moves nothing")

	# Shift + E from the right: the chair rolls left, away from you, with them in it
	var shoves0: int = career.value("chair_shoves")
	await _shove_keys()
	var node: Node = seat.get_node_or_null("ChairShove")
	ok(node != null and node.roll.vel < 0.0, "Shift + E pushes the chair away from you (vel %.1f)" % (node.roll.vel if node != null else 0.0))
	ok(career.value("chair_shoves") == shoves0 + 1, "the Career counts the push")
	ok(str(p.sprite.animation).begins_with("reach"), "you reach out for the push (%s)" % p.sprite.animation)
	await _wait(40)
	ok(seat.position.x < home - 8.0, "the seat rolled (%.1f px)" % (seat.position.x - home))
	ok(is_equal_approx(npc.global_position.x, seat.global_position.x), "the coworker rides along")
	ok(is_equal_approx(node.roll.chair.position.x, seat.position.x - 15.0), "and so does the chair sprite")
	ok(npc.seat == seat and seat.occupied, "they are still sitting in it")
	var expect := -1 if who == "Alan" else 0
	ok(social.value(who) == expect, "%s's opinion: %d (now %d)" % [who, expect, social.value(who)])
	ok(npc._bubble.visible, "they react with a bubble")
	await _wait(150)
	ok(seat.position.x >= home + lo - 0.01 and seat.position.x <= home + hi + 0.01, "the chair stayed inside its limits (%.1f in %.1f .. %.1f)" % [seat.position.x - home, lo, hi])
	ok(absf(node.roll.vel) < 1.0, "friction stopped it")
	# after a moment they scoot back to the desk and the helper node is gone
	await _wait(60 * 6)
	ok(is_equal_approx(seat.position.x, home) and is_equal_approx(npc.global_position.x, seat.global_position.x), "they scoot back to the desk (seat %.1f, home %.1f)" % [seat.position.x, home])
	ok(seat.get_node_or_null("ChairShove") == null, "and the helper is gone")
	ok(npc.seat == seat, "still seated, back at work (%s)" % npc.sprite.animation)

	# a second push inside 25 s changes no opinion; a friend laughs, a cold coworker glares
	p.global_position = Vector2(seat.global_position.x + 14.0, 118.0)
	p._set_state("idle")
	await _wait(10)
	var before: int = social.value(who)
	await _shove_keys()
	ok(seat.get_node_or_null("ChairShove") != null and social.value(who) == before, "a second push rolls them again but changes no opinion (one per 25 s)")
	await _wait(60 * 8)
	shove_script._who = {}
	social.rel[who] = 40
	p.global_position = Vector2(seat.global_position.x + 14.0, 118.0)
	p._set_state("idle")
	await _wait(10)
	await _shove_keys()
	ok(social.value(who) == 41, "a friend laughs: +1 (now %d)" % social.value(who))
	await _wait(60 * 8)
	shove_script._who = {}
	social.rel[who] = -40
	p.global_position = Vector2(seat.global_position.x + 14.0, 118.0)
	p._set_state("idle")
	await _wait(10)
	await _shove_keys()
	ok(social.value(who) == -42, "a cold coworker glares: -2 (now %d)" % social.value(who))
	social.rel[who] = 0

	# they get up mid-roll: the chair is back at the desk at once, nobody is dragged along
	await _wait(20)
	node = seat.get_node_or_null("ChairShove")
	ok(node != null and seat.position.x != home, "(the chair is away from the desk)")
	npc.seat = null
	seat.occupied = false
	await _wait(5)
	ok(is_equal_approx(seat.position.x, home) and seat.get_node_or_null("ChairShove") == null, "they stood up: the chair snapped home and the helper is gone")
	var stand_x: float = npc.global_position.x
	await _wait(20)
	# (the freed coworker may wander off under their own routine in any state, so check the chair, not where they stand)
	var still: bool = is_equal_approx(npc.global_position.x, stand_x) or not npc.state.begins_with("sit")
	ok(still and is_equal_approx(seat.position.x, home) and seat.get_node_or_null("ChairShove") == null, "and they are not dragged about any more")

	# nothing to push: an empty chair, and somebody in the middle of a conversation
	p.global_position = Vector2(seat.global_position.x + 14.0, 118.0)
	p._set_state("idle")
	await _wait(10)
	ok(not shove_script.try_shove(p), "an empty chair is not pushed")
	npc._occupy(str(seat.name), true)
	await _wait(5)
	npc._hold = 5.0
	ok(npc.seat == seat and not shove_script.try_shove(p), "somebody who is busy talking is left alone")
	npc._hold = 0.0
	p.global_position = Vector2(seat.global_position.x + 80.0, 118.0)
	await _wait(10)
	ok(not shove_script.try_shove(p), "from across the room you reach nothing")

	# from the left it rolls right, as far as the desk allows
	p.global_position = Vector2(seat.global_position.x - 14.0, 118.0)
	p._set_state("idle")
	await _wait(10)
	ok(shove_script.try_shove(p), "from the other side")
	node = seat.get_node_or_null("ChairShove")
	ok(node != null and node.roll.vel > 0.0, "it goes the other way")
	await _wait(120)
	ok(seat.position.x <= home + hi + 0.01, "and stops at their own desk (%.1f, hi %.1f)" % [seat.position.x - home, hi])
	await _wait(60 * 6)

	# PUSHY: ten pushes
	career.reset_all()
	ok(not career.has_medal("pushy"), "no medal yet")
	for k in 10:
		career.note_shove()
	ok(career.has_medal("pushy") and career.value("chair_shoves") == 10, "ten pushed chairs: PUSHY")
	career.reset_all()
	print("chair_shove: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
