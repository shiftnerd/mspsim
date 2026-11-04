extends SceneTree
# Screenshots of the parking lot outside the warehouse dock (renderer needed): the doorway, the middle and the far end at morning, noon,
# dusk and night. Writes user://lot_FORMAT_CLOCK_POS.png
#   Godot --path godot -s res://tests/warehouse_lot_shots.gd -- --format=h

const CLOCKS := [9.3, 12.5, 17.0, 19.0]
const SPOTS := [90.0, 400.0, 680.0]

var frame := 0
var idx := 0


func _initialize() -> void:
	root.get_node("Game").title_mode = false
	root.get_node("Campaign").new_game(root.get_node("Campaign").FREE)
	root.get_node("World").door_open = 1.0
	change_scene_to_file("res://scenes/warehouse_lot.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var phase := (frame - 10) % 30
	var room := current_scene
	var ci := idx / SPOTS.size()
	var si := idx % SPOTS.size()
	if phase == 0:
		var player: Node2D = room.get_node("Actors/Player")
		player.global_position.x = room.get_node("Background").position.x + SPOTS[si]
		for n in room.get_node("Actors").get_children():
			if "routine" in n:
				n.queue_free()
		for n in room.get_children():
			if n is Camera2D:
				n.reset_smoothing()
		root.get_node("World").clock = CLOCKS[ci]
	elif phase == 25:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://lot_%s_%d_%d.png" % [root.get_node("Game").format, int(CLOCKS[ci] * 10.0), int(SPOTS[si])])
		idx += 1
		if idx >= CLOCKS.size() * SPOTS.size():
			quit()
	return false
