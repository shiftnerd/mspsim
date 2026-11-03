extends SceneTree
# 1) Press the switch in the kitchenette twice (off, then on again).
# 2) Office 1 at closing time: Alan walks to the switch, turns the lights off and leaves.
#    Record with: Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/lights.gd

var frame := 0
var world: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/kitchenette.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _tap(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _dark() -> float:
	return current_scene._dark_a


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	world = root.get_node("World")
	match frame:
		5:
			var zone: Node2D = current_scene.get_node("Interactables/UseSwitch")
			_player().global_position = Vector2(zone.global_position.x, 118)
		20:
			_tap("interact")
		60:
			print(
				(
					"pressed once: lights_on=%s darkness=%.2f"
					% [world.lights_on("kitchenette"), _dark()]
				)
			)
		80:
			_tap("interact")
		120:
			print(
				(
					"pressed twice: lights_on=%s darkness=%.2f"
					% [world.lights_on("kitchenette"), _dark()]
				)
			)
			world.meeting_gap = Vector2(9999.0, 9999.0)
			world._meeting_t = 9999.0
			change_scene_to_file("res://scenes/office_one.tscn")
		150:
			world.clock = 17.0
			world.chars["Alan"].legs = world._plan("Alan")
			world.chars["Alan"].leg_t = world.chars["Alan"].legs[0].dur
			current_scene.get_node("Actors/Alan").set_routine(world.chars["Alan"].legs[0].routine)
		600:
			print(
				"office_one lights_on=%s darkness=%.2f" % [world.lights_on("office_one"), _dark()]
			)
			print("alan: %s" % world.chars["Alan"].scene)
			print("DONE")
			quit()
	return false
