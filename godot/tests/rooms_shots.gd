extends SceneTree
# Screenshots of the three outing rooms with the cast and a game running (renderer needed).

var frame := 0
var rooms := ["bowling_alley", "karaoke_bar", "escape_room", "restaurant"]
var games := ["bowling", "karaoke", "escape", "dinner"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://room_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var o := root.get_node("Outings")
	var step := frame - 10
	if step < 0:
		return false
	var i := step / 260
	var t := step % 260
	if i >= 4:
		quit()
		return false
	if t == 0:
		root.get_node("Campaign").new_game(root.get_node("Campaign").FREE)
		o.enabled = true
		o.use_rooms = true
		o.start(games[i])
	elif t == 160:
		if o.is_open:
			o.press(KEY_ENTER)
			if games[i] == "karaoke":
				root.get_node("Cards").pick(0)  # the song card at the mic
				o.g.t = 5.0
	elif t == 230:
		_shot(rooms[i])
		o.press(KEY_TAB)
	elif t == 240:
		_shot(rooms[i] + "_peek")
		if o.is_open:
			o.press(KEY_ESCAPE)
			o.press(KEY_ENTER)
	return false
