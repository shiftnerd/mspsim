extends SceneTree
# Screenshots of the printer mini-game for every model (renderer needed, so no --headless):
#   Godot.exe --path godot -s res://tests/printer_shots.gd -- --format=wide|h|v [--model=laser]
# Saves user://printer_<model>_<phase>.png (intro, jam, tray, toner, test, result). Model names: laser inkjet plotter mfp receipt dot.

const STEP := 12
var frame := 0
var models: Array = []
var tag := ""


func _initialize() -> void:
	models = ["laser", "inkjet", "plotter", "mfp", "receipt", "dot"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			models = [a.substr(8)]
		if a.begins_with("--format="):
			tag = a.substr(9)
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(model: String, name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://printer_%s_%s_%s.png" % [tag, model, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var pg := root.get_node("PrinterGame")
	var n := (frame - 10) / (STEP * 7)
	var s := ((frame - 10) % (STEP * 7)) / STEP
	var edge := (frame - 10) % STEP == 0
	if n >= models.size():
		quit()
		return false
	if not edge:
		return false
	var m: String = models[n]
	match s:
		0:
			pg.start(func(_s: int) -> void: pass, m, {"practice": true, "seed": 3, "onsite": true})
			pg.tired = 1.1
		1:
			_shot(m, "intro")
			pg.press("confirm")
		2:
			pg.marker = pg.zone
			pg.press("confirm")
			pg.marker = pg.zone + 0.5 if pg.zone < 0.5 else pg.zone - 0.5
			pg.press("confirm")
			pg.press("pray")
		3:
			_shot(m, "jam")
			pg.phase = "jam"
			pg.spot = pg.jam_len - 1
			pg.marker = pg.zone
			pg.press("confirm")
		4:
			if pg.phase == "tray":
				pg.tray_sel = 1
				_shot(m, "tray")
				pg.tray_sel = 0
				pg.press("confirm")
			if pg.phase == "toner":
				pg.press("right")
				_shot(m, "toner")
			elif pg.phase != "test":
				pg._begin_test()
		5:
			if pg.phase != "test":
				pg._begin_test()
			_shot(m, "test")
			pg._answered = true
			pg.mistakes = 1
			pg._end()
			pg.streak = 3
		6:
			_shot(m, "result")
			pg.press("escape")
			pg._result_t = 1.0
			pg.press("confirm")
	return false
