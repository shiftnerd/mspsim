extends SceneTree
# Screenshots of the character select's build step (needs a renderer): user://build_FORMAT_NAME.png
#   Godot --path godot --fixed-fps 60 -s res://tests/build_shots.gd -- --format=wide|h|v

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://build_%s_%s.png" % [root.get_node("Game").format, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var cs: Node = current_scene._select
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_bshots_%d_" % OS.get_process_id()
		40:
			current_scene._open_menu()
			current_scene._choose(0)
		80:
			current_scene._select.setup("tech")
			current_scene._select.confirm()  # phone
			current_scene._select.confirm()  # the tier step (R1)
			current_scene._select.confirm()  # options
			current_scene._select.confirm()  # build
		100:
			_shot("tech")
			cs._panel.row = 5
			cs._panel.cycle_quirk(0, 1)
			cs.queue_redraw()
		110:
			_shot("quirk")
			cs._panel.row = 0
			cs._panel.b = root.get_node("Build").new_build("normal")
			cs._panel.set_level("powershell", 4)
			cs._panel.set_level("networking", 4)
			cs._panel.set_level("servers", 3)
			cs._panel.set_level("security", 3)
			cs.queue_redraw()
		120:
			_shot("note")
			cs.setup("owner")
			cs.confirm()  # the tier step (R1)
			cs.confirm()  # options
			cs.confirm()  # build
			cs._panel.row = 2
			cs._panel.set_level("sales", 3)
			cs.queue_redraw()
		140:
			_shot("owner_capped")
			cs.back()
			cs.back()
			cs.back()
			cs.move(1)
			cs.confirm()
			cs.confirm()
			cs.confirm()
			cs._panel.cycle_preset(1)
			cs._panel.row = 7
			cs.queue_redraw()
		160:
			_shot("garrison")
			cs.setup("sales")
			cs.confirm()  # the tier step (R1)
			cs.confirm()  # options
			cs.confirm()  # build (the sales campaign's stat set, C3)
			cs._panel.row = 1
			cs._panel.set_level("negotiation", 2)
			cs.queue_redraw()
		180:
			_shot("sales")
			cs._panel.row = 5
			cs._panel.cycle_quirk(0, 1)
			cs.queue_redraw()
		190:
			_shot("sales_quirk")
			print("DONE")
			quit(0)
	return false
