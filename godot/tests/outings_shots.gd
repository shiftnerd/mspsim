extends SceneTree
# Screenshots of the four outing games and a result page (needs a renderer): user://outing_*.png

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://outing_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var o := root.get_node("Outings")
	match frame:
		10:
			root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
			root.get_node("Campaign").new_game("owner")
			o.start("bowling")
		20:
			_shot("bowling_intro")
			o.press(KEY_ENTER)
			o.g.stage = "power"
			o.g.power = 0.6
			o.g.marker = 0.4
			o.g.totals = {"You": 14, "Alan": 12, "Garrison": 17, "Dan": 9}
			o.g.pins = 6
		30:
			_shot("bowling")
			o.press(KEY_ESCAPE)
			o.press(KEY_ENTER)
			o.start("karaoke")
			o.press(KEY_ENTER)
			o.g.t = 6.0
			o.g.score = 14
			o.g.streak = 5
			o.g.flash = "PERFECT!"
			o.g.flash_t = 5.0
		40:
			o.g.flash_t = 5.0
			_shot("karaoke")
			o.press(KEY_ESCAPE)
			o.press(KEY_ENTER)
			o.start("escape")
			o.press(KEY_ENTER)
			o.g.code = [1, 2, 3]
			o.escape_try([3, 2, 0])
			o.escape_try([1, 5, 3])
			o.escape_hint()
		50:
			_shot("escape")
			o.press(KEY_ESCAPE)
			o.press(KEY_ENTER)
			o.start("dinner")
			o.press(KEY_ENTER)
			o.dinner_talk(0)
			o.g.wait = 99.0
		60:
			_shot("dinner")
			o._finish(2)
		70:
			_shot("result")
			quit()
	return false
