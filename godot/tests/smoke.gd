extends SceneTree
# Headless smoke test:  Godot --headless --fixed-fps 60 --path godot -s res://tests/smoke.gd
# Loads every character resource and set scene, then drives the player with simulated input:
# walk, run, jump/land, hurt, die/revive, sit at a desk, stand, door to the office and back,
# edge exits.

var frame := 0
var last_state := ""
var last_scene := ""


func _player() -> Node:
	var s := current_scene
	return s.get_node_or_null("Actors/Player") if s else null


func _initialize() -> void:
	var names := ["office_teen", "office_adult", "office_dan", "office_alan", "site_alan"]
	names.append("casual_garrison")
	for ch in names:
		var sf: SpriteFrames = load("res://characters/%s.tres" % ch)
		var n_anims := sf.get_animation_names().size()
		var n_type := sf.get_frame_count("type_left")
		var n_sit := sf.get_frame_count("sitdown_right")
		print("[res] %s: %d anims, type_left=%d, sitdown_right=%d" % [ch, n_anims, n_type, n_sit])
	for s in [
		"main_floor",
		"office_one",
		"office_two",
		"conference",
		"kitchenette",
		"bathroom",
		"cubicle_area",
		"network_closet"
	]:
		var packed: PackedScene = load("res://scenes/%s.tscn" % s)
		var inst: Node = packed.instantiate()
		var n_props: int = inst.get_node("Actors").get_child_count() - 1
		var n_inter: int = inst.get_node("Interactables").get_child_count()
		print(
			"[scene] %s: loads=%s props=%d interactables=%d" % [s, packed != null, n_props, n_inter]
		)
		inst.free()
	change_scene_to_file("res://scenes/main_floor.tscn")


func _log(msg: String) -> void:
	var p := _player()
	if p == null:
		print("f%04d %s | (no player)" % [frame, msg])
		return
	var info := (
		"scene=%s state=%s anim=%s fr=%d"
		% [current_scene.name, p.state, p.sprite.animation, p.sprite.frame]
	)
	print("f%04d %s | %s pos=(%.0f, %.0f)" % [frame, msg, info, p.position.x, p.position.y])


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _process(_delta: float) -> bool:
	frame += 1
	var p := _player()
	if p != null and p.state != last_state:
		_log("state %s -> %s" % [last_state, p.state])
		last_state = p.state
	if current_scene != null and current_scene.name != last_scene:
		last_scene = current_scene.name
		_log("SCENE %s" % last_scene)
	match frame:
		20:
			_log("start")
		# --- basic moves
		22:
			_hold("move_right", true)
		50:
			_log("walking")
		51:
			_hold("move_right", false)
		# --- jump
		60:
			_tap("jump")
		120:
			_log("after jump")
		# --- sit at the open desk (chair at x=98): walk right until inside the seat area
		125:
			_hold("move_right", true)
		148:
			_hold("move_right", false)
		150:
			_log("by the chair")
		152:
			_tap("interact")
		200:
			_log("seated")
		205:
			_tap("interact")
		250:
			_log("stood up")
		# --- door to Office 1 (x=181)
		255:
			_hold("run", true)
		256:
			_hold("move_right", true)
		312:
			_hold("move_right", false)
		313:
			_hold("run", false)
		316:
			_log("by office door")
		318:
			_tap("interact")
		380:
			_log("in office")
		# --- walk to the office door and back out
		382:
			_hold("move_left", true)
		425:
			_hold("move_left", false)
		428:
			_log("near office door")
		430:
			_tap("interact")
		500:
			_log("back on main floor")
		# --- left edge exit to the kitchenette
		502:
			_hold("run", true)
		503:
			_hold("move_left", true)
		640:
			_hold("move_left", false)
		641:
			_hold("run", false)
		700:
			_log("after left exit")
		# --- kitchenette right edge back to main floor
		702:
			_hold("run", true)
		703:
			_hold("move_right", true)
		760:
			_hold("move_right", false)
		761:
			_hold("run", false)
		830:
			_log("after right exit")
		832:
			_hold("run", true)
		833:
			_hold("move_right", true)
		1060:
			_hold("move_right", false)
		1065:
			_log("main floor right edge -> cubicle area (expect CubicleArea)")
		1067:
			_hold("move_right", true)
		1235:
			_hold("move_right", false)
		1240:
			_log("cubicle area right edge -> conference (expect Conference)")
		1242:
			_hold("move_right", true)
		1342:
			_hold("move_right", false)
		1346:
			_log("by conference door")
		1348:
			_tap("interact")
		1420:
			_log("back on main floor from conference (expect MainFloor x=336)")
		1425:
			_hold("run", false)
			_hold("move_left", true)
		1430:
			_hold("move_left", false)
		1440:
			print("DONE")
			quit()
	return false
