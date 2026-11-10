extends SceneTree
# Screenshots of the cozy pieces (needs a renderer): the HUD goal chip and next-up list, the office decor and the
# seasonal dressing on the main floor. Writes user://cozy_<format>_<season>.png.
#   Godot --path godot -s res://tests/cozy_shots.gd

const SHOTS := [["wide", 4, "holidays"], ["wide", 9, "tax_xp"], ["wide", 17, "school"], ["h", 10, "busy"], ["v", 10, "busy"]]


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game := root.get_node("Game")
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var career := root.get_node("Career")
	c.save_prefix = "user://test_shots_%d_" % OS.get_process_id()
	career.toasts = false
	game.title_mode = false
	root.get_node("Shift").enabled = true
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(10)
	for shot in SHOTS:
		game.set_format(str(shot[0]))
		c.new_game("tech")
		while cards.is_open:
			cards.pick(0)
		root.get_node("Msp").enabled = false
		c.day = int(shot[1])
		c.rep = 80
		c.cash = 1600
		for m in career.MEDALS.slice(0, 8):
			career.earned[str(m.id)] = true
		root.get_node("World").clock = 9.6
		root.get_node("World").time_scale = 0.0
		root.get_node("Msp").create_ticket(1, 0, "test")
		game.go("main_floor", "start")
		await _wait(90)
		root.get_node("Hints").toast_text = ""
		await _wait(20)
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://cozy_%s_%s.png" % [str(shot[0]), str(shot[2])])
	career.reset_all()
	print("DONE")
	quit()
