extends SceneTree
# Renders each set at 16:9 and 9:16 with a Camera2D and saves screenshots to user://
#   Godot --path godot --fixed-fps 60 -s res://tests/format.gd     (not headless: needs a renderer)

const SETS := {
	"main_floor": [368, 0, 60],
	"cubicle_area": [320, 24, 80],
	"network_closet": [144, 112, 60],
	"kitchenette": [176, 96, 90],
	"conference": [320, 88, 120],
	"office_one": [176, 96, 80],
	"office_two": [176, 96, 108],
	"bathroom": [128, 120, 60],
}
const FORMATS := {"h": Vector2i(320, 180), "v": Vector2i(180, 320)}

var queue := []
var frame := 0
var cam: Camera2D


func _initialize() -> void:
	for set_name in SETS:
		for fmt in FORMATS:
			queue.append([set_name, fmt])
	_next()


func _next() -> void:
	if queue.is_empty():
		print("DONE %s" % ProjectSettings.globalize_path("user://"))
		quit()
		return
	var item: Array = queue.pop_front()
	change_scene_to_file("res://scenes/%s.tscn" % item[0])
	frame = 0
	root.set_meta("job", item)


func _process(_delta: float) -> bool:
	if not root.has_meta("job") or current_scene == null:
		return false
	frame += 1
	var job: Array = root.get_meta("job")
	var cfg: Array = SETS[job[0]]
	var size: Vector2i = FORMATS[job[1]]
	if frame == 5:
		root.content_scale_size = size
		cam = Camera2D.new()
		current_scene.add_child(cam)
		cam.make_current()
		var width: int = cfg[0]
		var x0: int = cfg[1]
		var half_w := size.x / 2
		var cx: float = x0 + width / 2.0
		if job[1] == "v":
			cx = clampf(float(cfg[2]) + x0 + 30.0, x0 + half_w, x0 + width - half_w)
		var cy := 50.0 if job[1] == "h" else 60.0
		cam.position = Vector2(cx, cy)
	if frame == 15:
		var img := root.get_texture().get_image()
		img.save_png("user://%s_%s.png" % [job[0], job[1]])
		print("saved %s_%s %s" % [job[0], job[1], img.get_size()])
		root.remove_meta("job")
		_next()
	return false
