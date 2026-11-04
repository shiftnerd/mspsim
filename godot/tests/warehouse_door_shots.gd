extends SceneTree
# Screenshots of the warehouse dock door (renderer needed): closed, half open and open at morning and dusk, and open at night
# with the room's lights off. Writes user://door_FORMAT_CLOCK_OPEN[_dark].png
#   Godot --path godot -s res://tests/warehouse_door_shots.gd -- --format=h

const CASES := [[9.3, 0.0, true], [9.3, 0.5, true], [9.3, 1.0, true], [12.5, 1.0, true], [17.0, 0.0, true], [17.0, 0.5, true], [17.0, 1.0, true], [19.0, 1.0, false]]

var frame := 0
var idx := 0


func _initialize() -> void:
	root.get_node("Game").title_mode = false
	root.get_node("Campaign").new_game(root.get_node("Campaign").FREE)
	change_scene_to_file("res://scenes/warehouse.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var phase := (frame - 10) % 40
	var room := current_scene
	var door: Node = room.get_node("Fx/Door")
	if phase == 0:
		var c: Array = CASES[idx]
		var player: Node2D = room.get_node("Actors/Player")
		player.global_position.x = room.get_node("Background").position.x + 1300.0
		for n in room.get_node("Actors").get_children():
			if "routine" in n:
				n.queue_free()
		for n in room.get_children():
			if n is Camera2D:
				n.reset_smoothing()
		root.get_node("World").clock = c[0]
		root.get_node("World").set_lights("warehouse", c[2])
		door.open = c[1]
		door.goal = 1.0 if c[1] > 0.0 else 0.0
		door.door_apply()
		root.get_node("World").door_open = door.goal
	elif phase == 30:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			var c: Array = CASES[idx]
			img.save_png("user://door_%s_%d_%d%s.png" % [root.get_node("Game").format, int(c[0] * 10.0), int(c[1] * 10.0), "" if c[2] else "_dark"])
		idx += 1
		if idx >= CASES.size():
			quit()
	return false
