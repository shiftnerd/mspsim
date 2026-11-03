extends SceneTree
# Screenshots of the new outing content: the song card at the mic, the lyrics screen with a song
# playing (and the crowd meter), the dinner HUD with the mood faces, a 4 digit escape room.
# Renderer needed: `Godot --path godot -s res://tests/outing_content_shots.gd -- --format=wide|h|v`
# Files: user://ocs_<tag>_<name>.png (tag from the env var OCS_TAG, default "x").

var frame := 0
var tag := "x"
var cases := ["karaoke", "escape", "dinner"]


func _initialize() -> void:
	if OS.get_environment("OCS_TAG") != "":
		tag = OS.get_environment("OCS_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://ocs_%s_%s.png" % [tag, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var cards := root.get_node("Cards")
	var d := root.get_node("Difficulty")
	var step := frame - 10
	var i := step / 400
	var t := step % 400
	if i >= cases.size():
		quit()
		return false
	var campaign := root.get_node("Campaign")
	if t == 0:
		campaign.new_game(campaign.FREE)
		o.enabled = true
		o.use_rooms = true
		d.seed_run(41)
		d.set_tier("hard" if cases[i] == "escape" else "normal")
		o.best["karaoke"] = 3
		o.start(cases[i])
	elif t == 200:
		o.press(KEY_ENTER)
		if cases[i] == "karaoke":
			var neon := 0
			for k in cards.options.size():
				if cards.options[k].id == "neon":
					neon = k
			cards.sel = neon
	elif t == 215:
		if cases[i] == "karaoke":
			_shot("songcard")
			cards.pick(cards.sel)
			o.g.t = 9.5
			o.g.score = 0
			for n in o.g.notes:
				if float(n.time) < 9.3:
					n.state = "perfect"
					o.g.score += 2
			o.g.streak = 5
			o.g.mood = 72.0
		elif cases[i] == "dinner":
			var seat := current_scene.get_node("Interactables/Seat2")
			var p := current_scene.get_node("Actors/Player")
			p.global_position = seat.global_position
			p.sit(seat)
		else:
			var fx_root := current_scene.get_node("Fx")
			for n in ["Board", "WallClock", "Painting", "Shelf"]:
				fx_root.get_node(n).play()
			fx_root.get_node("Keypad").play()
			o.g.cur = [4, 2, 7, 1]
			o.g.time = 71.0
	elif t == 260:
		_shot({"karaoke": "lyrics", "dinner": "dinner_hud", "escape": "escape4"}[cases[i]])
	elif t == 280 and cases[i] == "dinner":
		o.dinner_talk(0)
	elif t == 320:
		_shot(
			{"karaoke": "lyrics_late", "dinner": "dinner_talk", "escape": "escape4_late"}[cases[i]]
		)
	elif t == 285 and cases[i] == "karaoke":
		o.g.t = 14.0
		o.g.mood = 12.0
		for n in o.g.notes:
			if float(n.time) < 13.8 and n.state == "":
				n.state = "good"
	elif t == 300 and cases[i] == "karaoke":
		_shot("lyrics_cool")
	elif t == 350:
		if o.is_open:
			o._finish(2)
		o.close()
	return false
