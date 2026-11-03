extends SceneTree
# Screenshots of the seed chip on the character select screen, the seed page and the toolbox pages (needs a renderer):
# user://toolbox_FORMAT_STEP.png
#   Godot --path godot --fixed-fps 60 -s res://tests/toolbox_shots.gd -- --format=wide|h|v

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://toolbox_%s_%s.png" % [root.get_node("Game").format, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var tb := root.get_node("Toolbox")
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_tbshots_%d_" % OS.get_process_id()
			root.get_node("Difficulty").settings_path = "user://test_tbshots_settings.cfg"
		40:
			current_scene._open_menu()
			current_scene._choose(current_scene._items.size() - 2)  # FREE PLAY
		70:
			current_scene._select.setup("free")
			root.get_node("Difficulty").seed_run(0x4F2A9C)
		80:
			_shot("select_free")
			current_scene._select.setup("tech")
			root.get_node("Difficulty").use_daily({"year": 2014, "month": 6, "day": 5})
		90:
			_shot("select_daily")
			current_scene._select.setup("free")
			root.get_node("Difficulty").seed_run(0x4F2A9C)
			current_scene._select.open_seed()
			for ch in "9BEE":
				tb.type_char(ch)
		100:
			_shot("seed_page")
			tb.seed_focus = 2
		105:
			_shot("seed_page_today")
			tb.close()
			current_scene._select.open_tools()
			tb.game_i = tb.GAMES.find("escape")
			tb.digits = 4
			tb._canvas.queue_redraw()
		115:
			_shot("tools_escape")
			tb.game_i = tb.GAMES.find("dinner")
			tb.table_i = 3
			tb.sel = 2
			tb._canvas.queue_redraw()
		125:
			_shot("tools_dinner")
			tb.game_i = tb.GAMES.find("printer")
			tb.set_fixed_take(false)
			tb.mutator = "flu"
			tb.sel = 4
			tb._canvas.queue_redraw()
		135:
			_shot("tools_printer")
			tb.close()
			print("DONE")
			quit(0)
	return false
