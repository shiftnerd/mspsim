extends SceneTree
# Screenshots of people sitting in chairs (renderer needed). Sits the player in a seat of each listed scene and saves the
# whole frame plus a 4x crop around the seat to user://seatchair_<tag>_<scene>_<seat>[_crop].png.
#   Godot --path godot -s res://tests/seat_chair_shots.gd -- --format=wide|h|v
# Env SC_TAG names the run (default "x"); SC_ONLY = "scene/Seat1,scene/Seat2" limits the list.

const ENTRIES := [
	["main_floor", "Seat1"],
	["main_floor", "Seat2"],
	["cubicle_area", "Seat1"],
	["office_one", "Seat1"],
	["office_one", "Seat2"],
	["office_two", "Seat1"],
	["conference", "Seat1"],
	["conference", "Seat3"],
	["restaurant", "Seat1"],
	["karaoke_bar", "Seat1"],
	["site_realty_a", "Seat1", 140],
	["site_arch_a", "Seat1", 180],
]
const BLOCK := 70

var frame := 0
var tag := "x"
var entries: Array = ENTRIES


func _initialize() -> void:
	if OS.get_environment("SC_TAG") != "":
		tag = OS.get_environment("SC_TAG")
	if OS.get_environment("SC_ONLY") != "":
		entries = []
		for s in OS.get_environment("SC_ONLY").split(","):
			entries.append(s.split("/"))
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String, center: Vector2) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.save_png("user://seatchair_%s_%s.png" % [tag, name])
	var vs := root.get_viewport().get_visible_rect().size
	var sc := img.get_width() / vs.x
	var xf := root.get_viewport().get_canvas_transform()
	var c: Vector2 = xf * center * sc
	var half := Vector2(60, 48) * sc
	var r := Rect2i(Vector2i((c - half).max(Vector2.ZERO)), Vector2i(half * 2.0))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("user://seatchair_%s_%s_crop.png" % [tag, name])


func _process(_delta: float) -> bool:
	frame += 1
	var f := frame - 20
	if f < 0:
		return false
	var k := int(f / float(BLOCK))
	var t := f % BLOCK
	if k >= entries.size():
		print("DONE")
		quit()
		return false
	var scene_name: String = entries[k][0]
	var seat_name: String = entries[k][1]
	match t:
		0:
			if scene_name.begins_with("site_"):
				root.get_node("Game").go(scene_name, "start")
			else:
				change_scene_to_file("res://scenes/%s.tscn" % scene_name)
		10:
			var seat: Node2D = current_scene.get_node_or_null("Interactables/%s" % seat_name)
			var player: CharacterBody2D = current_scene.get_node("Actors/Player")
			if seat != null:
				player.global_position = Vector2(seat.global_position.x, 118)
				player.velocity = Vector2.ZERO
		20:
			Input.action_press("interact")
			Input.action_release("interact")
		60:
			var seat: Node2D = current_scene.get_node_or_null("Interactables/%s" % seat_name)
			if seat == null:
				var cx := float(entries[k][2]) if entries[k].size() > 2 else 160.0
				_shot("%s_%s" % [scene_name, seat_name], Vector2(cx, 70))
			else:
				_shot("%s_%s" % [scene_name, seat_name], seat.global_position + Vector2(0, -30))
	return false
