extends SceneTree
# Screenshots of the character creator (needs a renderer): user://creator_FORMAT_STEP.png
#   Godot --path godot --fixed-fps 60 -s res://tests/creator_shots.gd -- --format=wide|h|v

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://creator_%s_%s.png" % [root.get_node("Game").format, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var look := root.get_node("Look")
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_crshots_%d_" % OS.get_process_id()
			root.get_node("Difficulty").settings_path = (
				"user://test_crshots_%d.cfg" % OS.get_process_id()
			)
		40:
			current_scene._open_menu()
			current_scene._choose(0)  # TECH CAMPAIGN
		80:
			current_scene._select.setup("tech")
			current_scene._select.sel = 0
			look.look = {
				"name": "JORDAN",
				"skin": "8d5524",
				"hair": "e05a9a",
				"shirt": "2f6b3a",
				"pants": "7a3030",
				"shoes": "cfc8b5"
			}
			current_scene._select._refresh_look()
		100:
			_shot("card")
			current_scene._select.confirm()
			current_scene._select.create_row = 3
			current_scene._select.queue_redraw()
		130:
			_shot("create")
			current_scene._select.setup("free")
			current_scene._select.sel = 0
			current_scene._select.confirm()
			look.look = {
				"name": "ZOE",
				"skin": "fbd7bc",
				"hair": "2a1c14",
				"shirt": "f4f2ea",
				"pants": "2b3550",
				"shoes": "2a2a33"
			}
			current_scene._select._refresh_look()
		160:
			_shot("create_free")
			print("DONE")
			quit(0)
	return false
