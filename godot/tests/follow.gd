extends SceneTree
# Ask Dan to follow (C), walk into the cubicle area, wait for Dan to arrive, then dismiss him.
# then asks him to stop.
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/follow.gd

var frame := 0
var world: Node


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
	world = root.get_node("World")
	match frame:
		5:
			world.meeting_gap = Vector2(9999.0, 9999.0)
			world._meeting_t = 9999.0
			world.force_activity("Dan", "bathroom")
			_player().global_position.x = 330.0
		110:
			var dan := current_scene.get_node("Actors/Dan")
			print("dan walking: state=%s x=%.0f" % [dan.state, dan.global_position.x])
			_player().global_position.x = dan.global_position.x + 14.0
		125:
			_tap("follow")
		160:
			var dan2 := current_scene.get_node("Actors/Dan")
			print("asked: following=%s state=%s" % [dan2.following, dan2.state])
			Input.action_press("move_right")
			Input.action_press("run")
		230:
			Input.action_release("move_right")
			Input.action_release("run")
		700:
			var here := current_scene.name
			var dan3 := current_scene.get_node_or_null("Actors/Dan")
			var dist := (
				-1.0 if dan3 == null else absf(dan3.global_position.x - _player().global_position.x)
			)
			print("scene=%s dan present=%s distance=%.0f" % [here, dan3 != null, dist])
		710:
			var dan4 := current_scene.get_node_or_null("Actors/Dan")
			if dan4 != null:
				_player().global_position.x = dan4.global_position.x + 12.0
		720:
			_tap("follow")
		780:
			print("dismissed: following=%s" % world.chars["Dan"].following)
			print("DONE")
			quit()
	return false
