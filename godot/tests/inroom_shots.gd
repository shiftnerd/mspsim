extends SceneTree
# Screenshots of the in-room games (renderer needed): user://inroom_*.png

var frame := 0
var cases := ["bowling", "karaoke", "escape", "dinner"]
var rooms := ["bowling_alley", "karaoke_bar", "escape_room", "restaurant"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://inroom_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var step := frame - 10
	var i := step / 300
	var t := step % 300
	if i >= 4:
		quit()
		return false
	if t == 0:
		root.get_node("Campaign").new_game(root.get_node("Campaign").FREE)
		o.enabled = true
		o.use_rooms = true
		o.start(cases[i])
	elif t == 120:
		o.press(KEY_ENTER)
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
				o.g._flash_x = 0
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
		_shot(rooms[i])
		if o.is_open:
			o.press(KEY_ESCAPE)
			o.press(KEY_ENTER)
	return false
