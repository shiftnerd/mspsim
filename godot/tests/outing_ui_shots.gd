extends SceneTree
# Screenshots of every outing UI state: room intro / result pages, the four in-room HUDs with a
# caption, the overlay versions and the printer game (renderer needed, `-- --format=wide|h|v`).
# Files: user://ouiui_<tag>_<name>.png where <tag> comes from the env var OUI_TAG (default "x").

var frame := 0
var tag := "x"
var cases := ["bowling", "karaoke", "escape", "dinner"]
var rooms := ["bowling_alley", "karaoke_bar", "escape_room", "restaurant"]


func _initialize() -> void:
	if OS.get_environment("OUI_TAG") != "":
		tag = OS.get_environment("OUI_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://ouiui_%s_%s.png" % [tag, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var step := frame - 10
	var i := step / 300
	var t := step % 300
	if i >= 4:
		return _overlay_and_printer(frame - 1210)
	var campaign := root.get_node("Campaign")
	if t == 0:
		campaign.new_game(campaign.FREE)
		o.enabled = true
		o.use_rooms = true
		o.start(cases[i])
	elif t == 100:
		_shot(cases[i] + "_intro")
	elif t == 120:
		o.press(KEY_ENTER)
		if cases[i] == "karaoke":
			root.get_node("Cards").pick(0)  # the song card at the mic
		match cases[i]:
			"bowling":
				o.press(KEY_E)
				o.g.marker = 0.5
				o.press(KEY_E)
				o.g.power = 0.6
				o.g.totals = {"You": 13, "Alan": 9, "Garrison": 15, "Dan": 7}
			"karaoke":
				o.g.t = 6.0
				o.g.score = 14
				o.g.streak = 5
			"escape":
				var fx_root := current_scene.get_node("Fx")
				fx_root.get_node("Board").play()
				fx_root.get_node("Keypad").play()
				o.g.cur = [4, 2, 7]
				o.g.time = 83.0
			"dinner":
				var seat := current_scene.get_node("Interactables/Seat2")
				var p := current_scene.get_node("Actors/Player")
				p.global_position = seat.global_position
				p.sit(seat)
	elif t == 200:
		match cases[i]:
			"bowling":
				o.press(KEY_E)
			"dinner":
				o.dinner_talk(0)
	elif t == 232:
		_shot(cases[i] + "_play")
		if cases[i] == "bowling":
			o.g.stage = "ready"
			o.caption("YOUR TURN: PRESS E TO BOWL", 99.0)
		if cases[i] == "dinner":
			o.caption("PICK A TOPIC (UP / DOWN, ENTER). WATCH THEIR FACES.", 99.0)
	elif t == 240:
		if cases[i] == "bowling" or cases[i] == "dinner":
			_shot(cases[i] + "_caption")
		if o.is_open:
			o._finish(3 if i % 2 == 0 else 1)
	elif t == 280:
		_shot(cases[i] + "_result")
		o.close()
	return false


func _overlay_and_printer(s: int) -> bool:
	var o := root.get_node("Outings")
	var pg := root.get_node("PrinterGame")
	if s == 80:
		o.use_rooms = false
		o.close()
		root.get_node("Campaign").new_game("owner")
		o.start("bowling")
	elif s == 100:
		_shot("ov_intro")
		o.press(KEY_ENTER)
		o.g.stage = "power"
		o.g.power = 0.6
		o.g.totals = {"You": 14, "Alan": 12, "Garrison": 17, "Dan": 9}
	elif s == 110:
		_shot("ov_bowling")
		o._finish(2)
	elif s == 120:
		_shot("ov_result")
		o.close()
		pg.start(func(_s: int) -> void: pass)
	elif s == 130:
		_shot("pr_intro")
		pg.press("confirm")
	elif s == 150:
		pg.marker = pg.zone
		pg.press("confirm")
	elif s == 155:
		_shot("pr_jam")
		pg.spot = 3
		pg._begin_tray()
	elif s == 158:
		pg.press("right")
		pg.press("pray")
		_shot("pr_tray")
		pg._begin_toner()
	elif s == 160:
		pg.press("right")
		_shot("pr_toner")
		pg._begin_test()
	elif s == 165:
		_shot("pr_test")
		pg._answered = true
		pg.mistakes = 1
		pg._end()
	elif s == 170:
		_shot("pr_result")
		quit()
	return false
