extends SceneTree
# Ducking: hold S or Down to duck; coworkers duck under darts too.

var frame := 0
var phase := 0
var t0 := 0
var failures := 0
var trials := 0
var ducked := 0
var npc: Node = null
var hits0 := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: int, down: bool) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = down
	Input.parse_input_event(k)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var nerf := root.get_node("Nerf")
	if frame == 5:
		var c := root.get_node("Campaign")
		c.new_game(c.FREE)
		root.get_node("Game").title_mode = false
		root.get_node("World").time_scale = 0.0
		change_scene_to_file("res://scenes/resort_hall.tscn")
		return false
	var player := current_scene.get_node_or_null("Actors/Player")
	if player == null or frame < 40:
		return false
	var chest := Vector2(player.global_position.x, player.global_position.y - 50.0)
	var knees := Vector2(player.global_position.x, player.global_position.y - 20.0)
	if phase == 0:
		_check(nerf._hits(player, chest, null), "standing: a dart at chest height hits")
		_key(KEY_S, true)
		phase = 1
		t0 = frame
	elif phase == 1 and frame == t0 + 12:
		_check(player.state == "duck", "holding S ducks the player (%s)" % player.state)
		_check(not nerf._hits(player, chest, null), "ducking: a chest-high dart flies over")
		_check(nerf._hits(player, knees, null), "ducking: a low dart still hits")
		_key(KEY_S, false)
		phase = 2
		t0 = frame
	elif phase == 2 and frame == t0 + 12:
		_check(player.state == "idle", "releasing S stands the player up (%s)" % player.state)
		_check(nerf._hits(player, chest, null), "standing again: hit")
		# a standing coworker who is not seated
		var scene := load("res://scenes/npc.tscn")
		for other in get_nodes_in_group("npcs"):
			other.queue_free()
		npc = scene.instantiate()
		npc.character = "office_dan"
		npc.routine = PackedStringArray(["wait:999"])
		npc.position = Vector2(player.global_position.x + 100.0, 118.0)
		current_scene.get_node("Actors").add_child(npc)
		phase = 3
		t0 = frame
	elif phase == 3 and frame == t0 + 20:
		npc.ducking = true
		_check(
			not nerf._hits(npc, Vector2(npc.global_position.x, 118.0 - 50.0), null),
			"a ducking coworker is a lower target"
		)
		npc.ducking = false
		phase = 4
		t0 = frame
	elif phase == 4:
		# fire darts at him from the left, one every 70 frames: he ducks about 6 times in 10
		if (frame - t0) % 70 == 0 and trials < 20:
			trials += 1
			nerf._spawn(Vector2(npc.global_position.x - 70.0, 118.0 - 50.0), 1.0, "Player", 0.0)
		for d in get_nodes_in_group("darts"):
			if d.has_meta("dodged") and not d.has_meta("counted"):
				d.set_meta("counted", true)
				ducked += 1
		if trials >= 20 and (frame - t0) > 70 * 20 + 90:
			_check(ducked >= 5 and ducked <= 19, "the coworker ducked %d of 20 darts" % ducked)
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
