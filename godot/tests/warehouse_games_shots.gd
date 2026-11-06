extends SceneTree
# gdlint:disable=max-line-length
# R21 screenshots: cornhole and the cookout in the warehouse (renderer needed, `-- --format=wide|h|v`). The intro page, cornhole at the
# aim, with a bag in the air and at the end of a round, the cookout with a queue of orders, a flare-up and a half cooked grate, and
# both result pages. Files: user://wg_<tag>_<name>.png (tag from the env var WG_TAG, default "x").

var frame := 0
var tag := "x"


func _initialize() -> void:
	if OS.get_environment("WG_TAG") != "":
		tag = OS.get_environment("WG_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://wg_%s_%s.png" % [tag, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var campaign := root.get_node("Campaign")
	var step := frame - 10
	var i := step / 600
	var t := step % 600
	if i >= 2:
		quit()
		return false
	var id := "cornhole" if i == 0 else "grill"
	if t == 0:
		campaign.new_game(campaign.FREE)
		o.enabled = true
		o.use_rooms = true
		o.start(id, false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
	elif t == 150:
		_shot(id + "_intro")
		o.press(KEY_ENTER)
	elif t == 200:
		if id == "cornhole":
			o.tick(1.5)
			o.g.game.marker = 0.62
	elif t == 230:
		if id == "cornhole":
			_shot("cornhole_aim")
			o.g.game.marker = 0.5
			o.press(KEY_E)
			o.g.game.power = 0.45
			o.press(KEY_E)
			o.tick(0.35)
		else:
			o.tick(9.0)
			var gg: RefCounted = o.g.game
			gg.slots[0].c = [0.5, 0.1]
			gg.slots[1].c = [0.2, 0.0]
			gg.slots[2].c = [0.6, 0.62]
			gg.slots[2].flare = 3.0
			gg.slots[3].c = [0.85, 0.45]
			gg.slots[3].down = 1
			gg.sel = 1
			gg.msg = "FLARE-UP ON 3! SHIFT MOVES IT."
			gg.msg_t = 6.0
	elif t == 238:
		_shot(id + "_play")
		if id == "cornhole":
			# play the first round out quickly so bags lie on both boards
			var cg: RefCounted = o.g.game
			var guard := 0
			while cg.phase != "round_end" and guard < 3000:
				guard += 1
				if cg.phase == "aim":
					cg.marker = 0.5 + 0.12 * float(guard % 3 - 1)
					o.press(KEY_E)
				elif cg.phase == "power":
					cg.power = 0.6 + 0.08 * float(guard % 2)
					o.press(KEY_E)
				o.tick(0.1)
	elif t == 250:
		_shot(id + "_late")
		if id == "grill":
			var gg2: RefCounted = o.g.game
			gg2.served = 5
			gg2.done = true
		else:
			var cg2: RefCounted = o.g.game
			cg2.score_you = 15
			cg2.phase = "round_end"
			cg2.t = 99.0
		o.tick(0.5)
	elif t == 270:
		o.tick(3.0)
	elif t == 300:
		_shot(id + "_result")
		if o.is_open:
			o.press(KEY_ENTER)
	return false
