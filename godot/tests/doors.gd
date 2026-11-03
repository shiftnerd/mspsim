extends SceneTree
# Bathroom doors (both, and the way back out to the same door) + the locked front door.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/doors.gd

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/kitchenette.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _tap(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _goto_door(door_name: String) -> void:
	var door: Node2D = current_scene.get_node("Interactables/%s" % door_name)
	_player().global_position = Vector2(door.global_position.x, 118)


func _log(msg: String) -> void:
	var p := _player()
	var info := (
		"scene=%s state=%s busy=%s" % [current_scene.name, p.state, root.get_node("Game").busy]
	)
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
			_goto_door("DoorBathLeft")
		20:
			_tap("interact")
		80:
			_log("left bath door -> bathroom (expect Bathroom, x=180)")
		85:
			_goto_door("DoorToKitchenette")
		95:
			_tap("interact")
		150:
			_log("back out (expect Kitchenette, x=156 = left door spawn)")
		155:
			_goto_door("DoorBathRight")
		165:
			_tap("interact")
		220:
			_log("right bath door -> bathroom (expect Bathroom)")
		225:
			_goto_door("DoorToKitchenette")
		235:
			_tap("interact")
		290:
			_log("back out (expect Kitchenette, x=216 = right door spawn)")
			change_scene_to_file("res://scenes/main_floor.tscn")
		310:
			_goto_door("DoorFrontDoor")
		320:
			_tap("interact")
		345:
			_log("front door is locked (expect still MainFloor, busy=false)")
			print("DONE")
			quit()
	return false
