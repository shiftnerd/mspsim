extends SceneTree
# Edge cases around sitting: switch character while seated / mid sit-down,
# and sit again right after standing.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/extras.gd

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _press_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _tap(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _log(msg: String) -> void:
	var p := _player()
	var info := "char=%s state=%s anim=%s" % [p.current_character, p.state, p.sprite.animation]
	print(
		(
			"f%03d %s | %s pos=(%.0f, %.0f)"
			% [frame, msg, info, p.global_position.x, p.global_position.y]
		)
	)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		10:
			var seat: Node2D = current_scene.get_node("Interactables/Seat1")
			_player().global_position = Vector2(seat.global_position.x, 118)
		20:
			_tap("interact")
		26:
			_press_key(KEY_3)
			_log("switch char DURING sit-down (should be ignored or applied safely)")
		80:
			_log("seated")
		85:
			_press_key(KEY_4)
		95:
			_log("switched to char 4 while seated (anim should still be type_*)")
		100:
			_tap("interact")
		106:
			_press_key(KEY_5)
			_log("switch char DURING stand-up")
		130:
			_log("stood up")
		133:
			_tap("interact")
		200:
			_log("sat down again immediately")
		205:
			_tap("interact")
		240:
			_log("stood up again")
		242:
			_tap("interact")
		300:
			_log("third sit")
			_tap("interact")
		340:
			_log("stood (3rd time)")
			_tap("jump")
		347:
			_press_key(KEY_6)
			_log("switch char DURING crouch")
		370:
			_press_key(KEY_2)
			_log("switch char IN THE AIR")
		440:
			_log("after landing (expect idle)")
			_tap("hurt")
		443:
			_press_key(KEY_3)
			_log("switch char DURING hurt")
		500:
			_log("after hurt (expect idle)")
			_tap("die")
		506:
			_press_key(KEY_4)
		600:
			_log("dead, switched char (expect state=death, anim=death_*)")
			print("DONE")
			quit()
	return false
