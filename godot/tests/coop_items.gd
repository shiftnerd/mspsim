extends SceneTree
# Co-op phase 4b: held items and darts are per player. Player 2 holds, aims and fires their own gun; player 1's ammo is untouched.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_items.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _act(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_coopitems_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopitems_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var nerf := root.get_node("Nerf")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var p1: Node = players.node(0)
	var p2: Node = players.node(1)
	p2.give("nerf")
	ok(p2.held == "nerf" and p1.held != "nerf", "only player 2 holds the gun")
	ok(nerf._ammo[1] == nerf.MAX_AMMO and nerf._ammo[0] == 0, "player 2 got the darts, player 1 none")
	var a0: int = nerf.ammo
	p2.state = "idle"
	ok(nerf.fire_player(p2), "player 2 fires")
	ok(nerf._ammo[1] == nerf.MAX_AMMO - 1 and nerf.ammo == a0, "their ammo drops, player 1's does not")
	nerf._cools[1] = 0.0
	await _wait(30)
	_act("p2_aim", true)
	await _wait(10)
	ok(nerf.is_charging(1) and not nerf.charging, "p2_aim charges player 2's shot only")
	await _wait(20)
	_act("p2_aim", false)
	await _wait(3)
	ok(not nerf.is_charging(1) and nerf._ammo[1] == nerf.MAX_AMMO - 2, "releasing fires it")
	p1.give("nerf")
	ok(nerf.ammo == nerf.MAX_AMMO and nerf._ammo[1] == nerf.MAX_AMMO - 2, "player 1 picking up a gun leaves player 2's count")
	players.enable_coop(false)
	print("coop_items: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
