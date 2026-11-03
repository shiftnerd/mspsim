extends SceneTree
# Screenshots of a client's computer onsite (renderer needed): user://onsite_*.png

var frame := 0
var shots := ["vet", "dental"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var step := frame - 10
	var i := step / 120
	var t := step % 120
	if i >= shots.size():
		quit()
		return false
	if t == 0:
		root.get_node("Computer").close()
		root.get_node("Game").go("site_%s_a" % shots[i], "start")
	elif t == 40:
		root.get_node("Onsite").interact("pc")
	elif t == 80:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://onsite_%s.png" % shots[i])
		root.get_node("Computer").activate("site:tools")
	elif t == 110:
		var img2 := root.get_viewport().get_texture().get_image()
		if img2 != null and not img2.is_empty():
			img2.save_png("user://onsite_%s_tools.png" % shots[i])
	return false
