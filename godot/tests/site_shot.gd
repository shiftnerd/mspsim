extends SceneTree
# One screenshot of a site room (renderer needed): -- --scene=NAME -> user://site_NAME.png

var frame := 0
var room := "site_vet_a"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			room = a.substr(8)
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	if frame == 12:
		root.get_node("Game").go(room, "start")
	elif frame == 62:
		for b in get_nodes_in_group("bells"):
			b.ring("dart")
	elif frame == 70:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://site_%s.png" % room)
		quit()
	return false
