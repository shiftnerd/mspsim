extends SceneTree
# Saves one screenshot with the clock in the corner (needs a renderer): user://hud.png

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 40:
		root.get_texture().get_image().save_png("user://hud.png")
		print("DONE %s" % ProjectSettings.globalize_path("user://hud.png"))
		quit()
	return false
