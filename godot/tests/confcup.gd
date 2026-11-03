extends SceneTree
# Same as deskcup.gd but at the conference table (cup stands on the table).
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/deskcup.gd

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/conference.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _tap(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	match frame:
		10:
			_player().give("coffee")
			var seat: Node2D = current_scene.get_node("Interactables/Seat2")
			_player().global_position = Vector2(seat.global_position.x, 118)
		20:
			_tap("interact")
		100:
			print("seated: state=%s held=%s" % [_player().state, _player().held])
			_tap("drink")
		130:
			print("sipping: state=%s anim=%s" % [_player().state, _player().sprite.animation])
		200:
			print("after sip: state=%s sips=%d" % [_player().state, _player().sips])
			_tap("interact")
		300:
			print("stood: state=%s held=%s" % [_player().state, _player().held])
			print("DONE")
			quit()
	return false
