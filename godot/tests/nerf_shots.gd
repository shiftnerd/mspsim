extends SceneTree
# Screenshots of the nerf gun: the rack, the blaster, darts in flight and stuck (needs a renderer).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://nerf_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	if frame == 5:
		var c := root.get_node("Campaign")
		c.new_game(c.FREE)
		root.get_node("World").chars["John"].scene = "cubicle_area"
		root.get_node("World").force_activity("John", "work")
		change_scene_to_file("res://scenes/cubicle_area.tscn")
		return false
	var nerf := root.get_node("Nerf")
	var player := current_scene.get_node("Actors/Player")
	match frame:
		60:
			player.global_position.x = 262.0
			_shot("rack")
		80:
			player.give("nerf")
			player.global_position.x = 192.0
			player.facing = "right"
			var vic := current_scene.get_node_or_null("Actors/John")
			if vic != null:
				vic.global_position.x = 250.0
		100:
			_shot("held")
			nerf.fire_player(player)
		104:
			_shot("flight")
		160:
			nerf._cools[0] = 0.0
			player.state = "idle"
			player.global_position.x = 100.0
			nerf.fire_player(player)
		190:
			_shot("stuck")
			quit()
	return false
