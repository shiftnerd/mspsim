extends SceneTree
# Play-test the nerf gun with real key events: tap Z = a quick shot, hold Z = aim and a long lob.
# Prints where darts land. With a renderer it also saves frames: user://nerfplay_*.png

var frame := 0
var phase := 0
var land_tap := 0.0
var land_hold := 0.0
var failures := 0
var _t0 := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: int, down: bool) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = down
	Input.parse_input_event(k)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://nerfplay_%s.png" % name)


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
		change_scene_to_file("res://scenes/main_floor.tscn")
		return false
	var player := current_scene.get_node_or_null("Actors/Player")
	if player == null:
		return false
	for n in get_nodes_in_group("npcs"):
		n.queue_free()  # only the flight of the darts is tested here (coworkers would start a war)
	match phase:
		0:
			if frame > 40:
				player.give("nerf")
				player.global_position.x = 140.0
				player.facing = "right"
				player.velocity = Vector2.ZERO
				_key(KEY_Z, true)
				_key(KEY_Z, false)  # a tap
				phase = 1
				_t0 = frame
		1:
			var darts := get_nodes_in_group("darts")
			if frame == _t0 + 4:
				_check(darts.size() == 1, "tap Z: a dart appears")
				if darts.size() == 1:
					_check(
						darts[0].state == "fly" and darts[0].position.y < 100.0,
						"it is flying at shoulder height (%s)" % darts[0].position
					)
				_shot("tap_flight")
			if frame > _t0 + 180 or (darts.size() == 1 and darts[0].state != "fly"):
				if darts.size() == 1:
					land_tap = darts[0].position.x
					_check(
						darts[0].state == "floor" or darts[0].state == "stuck",
						"the dart comes to rest (%s at x=%d)" % [darts[0].state, int(land_tap)]
					)
				for d in darts:
					d.queue_free()
				phase = 2
				_t0 = frame
		2:
			if frame == _t0 + 5:
				player.global_position.x = 140.0
				player.facing = "right"
				nerf._cool = 0.0
				_key(KEY_Z, true)
			if frame == _t0 + 40:
				_check(
					nerf.charging and nerf.charge > 0.4,
					"holding Z charges (%d%%)" % int(nerf.charge * 100.0)
				)
				_check(player.state == "emote", "and you stand still to aim")
				_check(current_scene.get_node("Actors").get_child_count() > 0, "(scene alive)")
				_shot("aim")
			if frame == _t0 + 80:
				_key(KEY_Z, false)
			if frame == _t0 + 84:
				var darts := get_nodes_in_group("darts")
				_check(
					darts.size() == 1 and darts[0].state == "fly", "release: the lob is in the air"
				)
				_shot("lob_flight")
			if frame > _t0 + 90:
				var darts := get_nodes_in_group("darts")
				if frame > _t0 + 400 or (darts.size() == 1 and darts[0].state != "fly"):
					if darts.size() == 1:
						land_hold = darts[0].position.x
					var flat := _range_of(nerf, 0.0)
					var lob := _range_of(nerf, 1.0)
					_check(
						lob > flat + 80.0,
						(
							"a full lob flies much further: %d vs %d px in open air"
							% [int(lob), int(flat)]
						)
					)
					_check(
						land_hold > 0.0, "and the real lob came to rest at x=%d" % int(land_hold)
					)
					print("failures=", failures)
					quit(1 if failures > 0 else 0)
	return false


# where a dart launched from shoulder height lands in open air
func _range_of(nerf: Node, power: float) -> float:
	var pos := Vector2(0.0, 64.0)
	var v: Vector2 = nerf.launch_velocity(1.0, power)
	for i in 400:
		v.y += 75.0 * 0.02
		pos += v * 0.02
		if pos.y >= 116.0:
			break
	return pos.x
