extends SceneTree
# Gets a coffee, walks with it, sips until it is empty (--write-movie shows the cup).
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/items.gd

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
			var area: Node2D = current_scene.get_node("Interactables/UseCoffee")
			_player().global_position = Vector2(area.global_position.x, 118)
		20:
			_tap("interact")
		560:
			print("after brew: held=%s" % _player().held)
			Input.action_press("move_right")
		620:
			Input.action_release("move_right")
			print("walked: state=%s anim=%s" % [_player().state, _player().sprite.animation])
		650:
			_tap("drink")
		740:
			_tap("drink")
		830:
			_tap("drink")
		920:
			print("after 3 sips: held='%s' sips=%d" % [_player().held, _player().sips])
			print("DONE")
			quit()
	return false
