extends SceneTree
# Screenshots of the Rodent Nation venue rooms (renderer needed): user://venue_<room>.png

var frame := 0
var rooms := ["resort_lobby", "resort_hall", "ballroom", "breakout_room", "vendor_hall"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var step := frame - 10
	var i := step / 60
	var t := step % 60
	if i >= rooms.size():
		quit()
		return false
	if t == 0:
		root.get_node("Game").go(rooms[i], "start")
	elif t == 55:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://venue_%s.png" % rooms[i])
	return false
