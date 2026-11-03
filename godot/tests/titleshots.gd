extends SceneTree
# Screenshots of the title screen vignettes (needs a renderer): user://title_<format>_<n>.png

const JOBS := [["h", 0], ["h", 1], ["h", 2], ["h", 3], ["wide", 1], ["wide", 2], ["v", 1], ["v", 3]]
const WAIT := 400

var frame := 0
var job := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var t := frame - job * (WAIT + 10)
	var info: Array = JOBS[job]
	if t == 2:
		root.get_node("Game").set_format(info[0])
		current_scene.show_vignette(info[1])
		current_scene._t = -100.0  # no rotation while we wait
	if t == WAIT:
		root.get_texture().get_image().save_png("user://title_%s_%d.png" % [info[0], info[1]])
		print("saved %s %d (room %s)" % [info[0], info[1], current_scene._room.name])
		job += 1
		if job >= JOBS.size():
			print("DONE")
			quit()
	return false
