extends SceneTree
# Opens the kitchenette fridge, takes a drink and sips it (--write-movie shows it).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/kitchenette.tscn")


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
		5:
			for c in current_scene.get_node("Actors").get_children():
				if "routine" in c:
					c.queue_free()
		10:
			var area: Node2D = current_scene.get_node("Interactables/UseFridge")
			_player().global_position = Vector2(area.global_position.x, 118)
			_player().face("right")
		20:
			_tap("interact")
		70:
			print("opening: state=%s held='%s'" % [_player().state, _player().held])
		160:
			print("grabbed: held='%s'" % _player().held)
		300:
			print("done: held='%s'" % _player().held)
			_tap("drink")
		380:
			print("sipped: sips=%d" % _player().sips)
			print("DONE")
			quit()
	return false
