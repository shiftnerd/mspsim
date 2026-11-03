extends SceneTree
# The sales bell: a dart rings it, the player cannot reach it, Vic rings it.

var frame := 0
var failures := 0
var phase := 0
var t0 := 0
var bell: Node = null


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


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
		change_scene_to_file("res://scenes/main_floor.tscn")
		return false
	var player := current_scene.get_node_or_null("Actors/Player")
	if player == null or frame < 40:
		return false
	if phase == 0:
		var bells := get_nodes_in_group("bells")
		_check(bells.size() == 1, "the office has a sales bell")
		bell = bells[0]
		_check(
			bell.global_position.y < 60.0,
			"it hangs high on the wall (y %d)" % int(bell.global_position.y)
		)
		_check(bell._bell_t == 0.0, "it is quiet")
		# a dart straight at it
		nerf._spawn(bell.global_position + Vector2(-30.0, 4.0), 1.0, "Player", 0.0)
		var darts := get_nodes_in_group("darts")
		darts[darts.size() - 1].vel = Vector2(150.0, 0.0)
		phase = 1
		t0 = frame
	elif phase == 1 and frame == t0 + 40:
		_check(bell._bell_t > 0.0, "a foam dart rings the bell")
		var zone := current_scene.get_node_or_null("Interactables/UseSalesBell")
		_check(zone != null, "Vic can walk up to it (an interact zone)")
		root.get_node("Hints").toast_text = ""
		if zone != null:
			zone.use(player)
		_check(
			root.get_node("Hints").toast_text.begins_with("TOO HIGH"), "the player cannot reach it"
		)
		root.get_node("Sales").last_deal = "VIC CLOSED ACME DENTAL GROUP!"
		bell._bell_t = 0.0
		bell.play()
		_check(
			bell._bell_t > 0.0 and root.get_node("Hints").toast_text.contains("ACME"),
			"Vic's ring says what he sold"
		)
		# Vic walks up to it and rings it
		bell._bell_t = 0.0
		var vic: Node = load("res://scenes/npc.tscn").instantiate()
		vic.character = "sales_vic"
		vic.routine = PackedStringArray(["walk:132", "use:salesbell", "wait:2"])
		vic.position = Vector2(70.0, 118.0)
		current_scene.get_node("Actors").add_child(vic)
		phase = 2
		t0 = frame
	elif phase == 2:
		if bell._bell_t > 0.0 or frame > t0 + 600:
			_check(bell._bell_t > 0.0, "Vic walked over and rang the bell himself")
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
