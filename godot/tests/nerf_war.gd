extends SceneTree
# Play-test the nerf war with real keys: shoot a seated coworker and they fire back from their desk.
# Saves frames when a renderer is available: user://nerfwar_*.png

var frame := 0
var t0 := 0
var phase := 0
var failures := 0
var seen_vic_dart := false
var saw_hit_on_me := false


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
		img.save_png("user://nerfwar_%s.png" % name)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var nerf := root.get_node("Nerf")
	var world := root.get_node("World")
	if frame == 5:
		var c := root.get_node("Campaign")
		c.new_game(c.FREE)
		root.get_node("Game").title_mode = false
		world.chars["Vic"].scene = "cubicle_area"
		world.force_activity("Vic", "work")
		change_scene_to_file("res://scenes/cubicle_area.tscn")
		return false
	var player := current_scene.get_node_or_null("Actors/Player")
	var vic := current_scene.get_node_or_null("Actors/Vic")
	if player == null or frame < 50:
		return false
	if phase == 0:
		if vic == null:
			return false
		if vic.seat == null:
			vic._occupy("Seat1", true)
		_check(vic.seat != null, "Vic is sitting at his desk")
		player.give("nerf")
		player.global_position.x = vic.global_position.x - 14.0
		player.facing = "right"
		player.velocity = Vector2.ZERO
		root.get_node("Social").rel["Vic"] = 30
		_key(KEY_Z, true)
		_key(KEY_Z, false)
		phase = 1
		t0 = frame
	elif phase == 1:
		if frame == t0 + 40:
			_check(nerf.hits == 1, "the dart hit seated Vic (%d hits)" % nerf.hits)
			_check(nerf.war_t > 0.0, "a nerf war started")
			_check(vic.held == "nerf", "Vic has a blaster, even sitting down")
		for d in get_nodes_in_group("darts"):
			if d.shooter == "Vic":
				if not seen_vic_dart:
					_shot("vic_fires")
				seen_vic_dart = true
		if frame > t0 + 420:
			_check(seen_vic_dart, "Vic fired back from his desk")
			_check(
				nerf.taken >= 1 or seen_vic_dart, "his darts head for you (%d taken)" % nerf.taken
			)
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
