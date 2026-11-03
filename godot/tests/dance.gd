extends SceneTree
# Dances (X), keeps dancing, stops on movement. Also checks the player is not dancing by itself.
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/dance.gd

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


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
			_player().global_position.x = 120.0
		30:
			print("before: state=%s" % _player().state)
			_tap("dance")
		60:
			print("dancing: state=%s anim=%s" % [_player().state, _player().sprite.animation])
		300:
			print("still dancing: state=%s" % _player().state)
			Input.action_press("move_right")
		310:
			Input.action_release("move_right")
			print("after move: state=%s" % _player().state)
		340:
			_player().face("left")
			_tap("dance")
		420:
			print("left dance: state=%s anim=%s" % [_player().state, _player().sprite.animation])
			_tap("dance")
		440:
			print("toggled off: state=%s" % _player().state)
			print("DONE")
			quit()
	return false
