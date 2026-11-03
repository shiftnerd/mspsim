extends SceneTree
# Walks the player across the main floor so the follow camera pans. Record it with:
#   python tools/render_video.py --format h --script res://tests/followcam.gd --upscale 6

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	match frame:
		5:
			var p: CharacterBody2D = current_scene.get_node("Actors/Player")
			p.global_position.x = 40.0
			for c in current_scene.get_node("Actors").get_children():
				if "routine" in c:
					c.queue_free()
		10:
			Input.action_press("move_right")
			Input.action_press("run")
		260:
			Input.action_release("move_right")
			Input.action_press("move_left")
		400:
			Input.action_release("move_left")
			Input.action_release("run")
		420:
			quit()
	return false
