extends SceneTree
# Walks into a standing NPC and presses E: the player steps back to a talking distance.
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/chat.gd

var frame := 0
var dan: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var world := root.get_node("World")
	match frame:
		10:
			dan = current_scene.get_node("Actors/Dan")
			world.force_activity("Dan", "coffee")
			_player().global_position.x = 340.0
		200:
			print("dan state=%s x=%.0f" % [dan.state, dan.global_position.x])
			_player().global_position.x = dan.global_position.x + 5.0
			_player().face("left")
		215:
			print(
				(
					"overlap distance before: %.0f"
					% absf(_player().global_position.x - dan.global_position.x)
				)
			)
			Input.action_press("interact")
			Input.action_release("interact")
		260:
			var d := absf(_player().global_position.x - dan.global_position.x)
			print("talking distance after: %.0f (player %s)" % [d, _player().state])
		340:
			print("after chat: player %s dan %s" % [_player().state, dan.state])
			print("DONE")
			quit()
	return false
