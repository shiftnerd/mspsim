extends SceneTree
# Screenshots of the dual-monitor desks (needs a renderer, not --headless): normal, then desk 2 on no link and desk 3 on
# no internet, then the nearby-sitter scroll. Saves user://dualmon_main_floor.png and user://dualmon_offline.png.
#   Godot --path godot -s res://tests/dualmon_shots.gd

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://dualmon_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var net := root.get_node("Net")
	match frame:
		40:
			_shot("main_floor")
			net.pick("p2")  # desk 2: no link
			net.pick("up")  # desks 1 and 3: link but no internet
		100:
			_shot("offline")
			net.reset()
		110:
			quit()
	return false
