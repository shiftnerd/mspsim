extends SceneTree
# Screenshots of the warehouse at several x positions (renderer needed): user://wh_FORMAT_X.png
#   Godot --path godot -s res://tests/warehouse_shots.gd -- --format=h [--xs=60,300,600]

var frame := 0
var xs := [60, 220, 420, 640, 860, 1060, 1200, 1400]
var idx := 0
var _x0 := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--xs="):
			xs = []
			for s in a.substr(5).split(","):
				xs.append(int(s))
	change_scene_to_file("res://scenes/warehouse.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var phase := (frame - 10) % 40
	var player: Node2D = current_scene.get_node("Actors/Player")
	if phase == 0:
		_x0 = current_scene.get_node("Background").position.x
		player.global_position.x = _x0 + float(xs[idx])
		for c in current_scene.get_node("Actors").get_children():
			if "routine" in c:
				c.queue_free()
		for c in current_scene.get_children():
			if c is Camera2D:
				c.reset_smoothing()
	elif phase == 30:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://wh_%s_%d.png" % [root.get_node("Game").format, xs[idx]])
		idx += 1
		if idx >= xs.size():
			quit()
	return false
