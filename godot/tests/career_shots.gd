extends SceneTree
# gdlint:disable=max-line-length
# Screenshots of the career screen, the title menu with CAREER, the phone Settings and the desktop wallpaper chip
# (needs a renderer): user://career_FORMAT_NAME.png
#   Godot --path godot --fixed-fps 60 -s res://tests/career_shots.gd -- --format=wide|h|v

var frame := 0
var screen: Node = null


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://career_%s_%s.png" % [root.get_node("Game").format, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Career")
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_cshots_%d_" % OS.get_process_id()
			c.toasts = false
			c.reset_all()
			for k in ["tickets", "tk.password", "tk.spooler", "tk.reboot", "outings", "bowl_strikes", "pets", "nerf_hits", "nerf_dodges", "printer_wins", "pr.laser", "pr.mfp", "meetings", "days.tech", "duck_squeaks", "kara_perfects"]:
				c.counters[k] = 12
			c.counters["tickets"] = 53
			c.counters["stars.bowling"] = 3
			c.counters["escape_best"] = 47
			c.counters["nerf_longest"] = 163
			c.check_medals()
		40:
			current_scene._open_menu()
		50:
			_shot("title_menu")
			current_scene._choose(current_scene._items.size() - 1)
		70:
			screen = current_scene._career
			if screen == null:
				print("FAIL no career screen")
				quit(1)
				return true
			_shot("p0")
			print("pages=", screen.page_count())
		75:
			screen.go(1)
		85:
			_shot("p1")
			screen.go(1)
		95:
			_shot("p2")
			screen.go(1)
		105:
			_shot("p3")
			screen.go(1)
		115:
			_shot("p4")
			screen.go(1)
		125:
			_shot("p5")
			screen.close()
			root.get_node("Game").title_mode = false
			change_scene_to_file("res://scenes/main_floor.tscn")
		170:
			var ph := root.get_node("Phone")
			ph.os = "android"
			ph.open()
			ph.app = "settings"
		190:
			_shot("phone")
			root.get_node("Phone").close()
		200:
			print("DONE")
			quit(0)
	return false
