extends SceneTree
# Screenshots of the difficulty chip on the character select screen (needs a renderer):
# user://difficulty_FORMAT_STEP.png
#   Godot --path godot --fixed-fps 60 -s res://tests/difficulty_shots.gd -- --format=wide|h|v

var frame := 0


func _initialize() -> void:
	root.get_node("Difficulty").settings_path = "user://test_dshots_settings.cfg"
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://difficulty_%s_%s.png" % [root.get_node("Game").format, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var d := root.get_node("Difficulty")
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_dshots_%d_" % OS.get_process_id()
			d.set_tier("normal")
		40:
			current_scene._open_menu()
			current_scene._choose(0)  # TECH CAMPAIGN
		80:
			current_scene._select.setup("tech")
		90:
			_shot("normal_char")
			current_scene._select.change_tier(1)
		110:
			_shot("hard_char")
			current_scene._select.confirm()
		130:
			_shot("hard_phone")
			current_scene._select.back()
			current_scene._select.change_tier(-2)
		150:
			_shot("easy_char")
			d.set_tier("normal")
			DirAccess.remove_absolute(d.settings_path)
			print("DONE")
			quit(0)
	return false
