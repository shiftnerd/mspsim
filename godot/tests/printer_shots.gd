extends SceneTree
# Screenshots of the printer mini-game (renderer needed): user://printer_<phase>.png

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://printer_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var pg := root.get_node("PrinterGame")
	match frame:
		12:
			pg.start(func(_s: int) -> void: pass)
		20:
			_shot("intro")
			pg.press("confirm")
		40:
			pg.marker = pg.zone
			pg.press("confirm")
		45:
			_shot("jam")
			pg.spot = 3
			pg._begin_tray()
		48:
			pg.press("right")
			pg.press("pray")
			_shot("tray")
			pg._begin_toner()
		50:
			pg.press("right")
			_shot("toner")
			pg._begin_test()
		55:
			_shot("test")
			pg._answered = true
			pg.mistakes = 1
			pg._end()
		60:
			_shot("result")
			quit()
	return false
