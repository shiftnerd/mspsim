extends SceneTree
# gdlint:disable=max-line-length
# Screenshots of the darts game and the warehouse's small interactions (renderer needed, `-- --format=wide|h|v`): the intro page, the
# aim at the wobbly start and at the steady moment, a dart in the air, three darts in the board with the turn total, a crew turn, the
# result page, then the vending machine, the chair rack, the radio, the tree's lights (with a popped bulb), the fan, the bench PC
# and the lamp. Files: user://wp_<tag>_<name>.png (tag from the env var WP_TAG, default "x").

# each small interaction: stand at x (set pixels), wait for the camera, press E on its zone, wait, take the picture
const SCENES := [
	[248.0, "Usevending_machine", 40, "vending"],
	[140.0, "Usechair_rack", 36, "chair_rack"],
	[905.0, "UseRadio", 24, "radio"],
	[992.0, "UseBenchPC", 24, "bench_pc"],
	[860.0, "UseLampChain", 16, "lamp_chain"],
	[392.0, "Usefloor_fan", 30, "fan"],
	[665.0, "UsePartsCage", 12, "parts_cage"],
	[1420.0, "UseTree", 4, "tree_lights"],
]

var frame := 0
var tag := "x"
var _stage := 0
var _wait := 0

func _initialize() -> void:
	if OS.get_environment("WP_TAG") != "":
		tag = OS.get_environment("WP_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://wp_%s_%s.png" % [tag, name])


func _scene() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _zone(prefix: String) -> Node:
	for z in current_scene.get_node("Interactables").get_children():
		if str(z.name).begins_with(prefix):
			return z
	return null


func _stand(x: float) -> Node:
	var p: Node2D = current_scene.get_node("Actors/Player")
	p.global_position = Vector2(float(current_scene.get_node("Background").position.x) + x, 118.0)
	p.velocity = Vector2.ZERO
	for c in current_scene.get_children():
		if c is Camera2D:
			c.reset_smoothing()
	return p


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	var o := root.get_node("Outings")
	var campaign := root.get_node("Campaign")
	var d := root.get_node("Difficulty")
	var hints := root.get_node("Hints")
	match _stage:
		0:
			campaign.new_game(campaign.FREE)
			d.seed_run(20140)
			o.enabled = true
			o.use_rooms = true
			o.start("darts", false, {"party": ["Alan", "Garrison", "Dan"]})
			_wait = 150
		1:
			_shot("darts_intro")
			o.press(KEY_ENTER)
			o.tick(1.3)
			var dg: RefCounted = o.g.game
			dg.aim_t = 0.3
			_wait = 30
		2:
			_shot("darts_aim_wobbly")
			o.g.game.aim_t = 1.3
			_wait = 6
		3:
			_shot("darts_aim_steady")
			var dg: RefCounted = o.g.game
			dg.aim_t = 1.3
			var best := 1e9
			var tt := 0.9
			while tt < 2.1:
				var dist: float = dg.reticle_at(tt).length()
				if dist < best:
					best = dist
					dg.aim_t = tt
				tt += 0.01
			o.press(KEY_E)
			o.tick(0.15)
			_wait = 4
		4:
			_shot("darts_flight")
			o.tick(0.4)
			_wait = 20
		5:
			# two more darts, to fill the turn
			var dg: RefCounted = o.g.game
			for k in 2:
				var guard := 0
				while dg.phase != "aim" and guard < 400:
					guard += 1
					o.tick(0.05)
				dg.aim_t = 1.1 + 0.4 * float(k)
				o.press(KEY_E)
				o.tick(0.9)
			_wait = 20
		6:
			_shot("darts_board")
			var dg: RefCounted = o.g.game
			var guard := 0
			while dg.phase != "opp" and guard < 800:
				guard += 1
				o.tick(0.05)
			o.tick(1.0)
			_wait = 20
		7:
			_shot("darts_opp")
			var dg: RefCounted = o.g.game
			dg.totals = {"You": 214, "Alan": 150, "Garrison": 132, "Dan": 101}
			dg.bulls = 2
			dg.best_dart = 50
			dg.phase = "done"
			o.tick(0.1)
			o.tick(2.0)
			_wait = 20
		8:
			_shot("darts_result")
			o.press(KEY_ENTER)
			o.use_rooms = false
			_wait = 60
		9:
			root.get_node("Game").go("warehouse", "start")
			_wait = 80
		10:
			if _scene() != "warehouse":
				_wait = 20
				return false
			hints.toast_text = ""
			current_scene.get_node("Actors/Player").held = ""
			_wait = 2
		_:
			_interactions()
			return false
	_stage += 1
	return false


func _interactions() -> void:
	var k := (_stage - 11) / 3
	var step := (_stage - 11) % 3
	if k >= SCENES.size():
		quit()
		return
	var row: Array = SCENES[k]
	if step == 0:
		_stand(float(row[0]))
		_wait = 6
	elif step == 1:
		var p := _stand(float(row[0]))
		var zone: Node = _zone(str(row[1]))
		if str(row[3]) == "tree_lights":
			var lights: Node = current_scene.get_node("Fx/TreeLights")
			lights.tree_on = true
			lights.tree_popped.append(2)
			lights._pop_i = 2
			lights._pop_t = lights._time
		else:
			zone.use(p)
		_wait = int(row[2])
	else:
		_shot(str(row[3]))
		_wait = 4
	_stage += 1
