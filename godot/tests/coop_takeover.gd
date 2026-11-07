extends SceneTree
# Co-op phase 3a: a computer opens as the player's own half-window pane. Only that player is frozen, the room keeps going, the
# pad player drives the pane with a stick cursor and A, and a room change closes the panes.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_takeover.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _pad(button: int, pressed: bool, device := 1) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _stick(axis: int, value: float, device := 1) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_cooptake_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_cooptake_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var game := root.get_node("Game")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var p1: Node = players.node(0)
	var p2: Node = players.node(1)
	ok(p1 != null and p2 != null, "two players in the room")

	var host: Node = players.takeover_host()
	var comp: Node = host.open_computer(1, 3)
	await _wait(20)
	ok(comp.is_open and comp.pane_slot == 1, "slot 1's computer is open as a pane")
	ok(players.ui[1] and not players.ui[0], "only slot 1 has a takeover open")
	ok(not game.ui_open, "the global freeze stays off")
	ok(not root.get_node("Computer").is_open, "the full-window autoload is untouched")
	var r0: Rect2 = host.pane_rect(0)
	var r1: Rect2 = host.pane_rect(1)
	ok(is_equal_approx(r0.end.x, r1.position.x) and r0.size.y == r1.size.y and r0.position.y > 0.0, "two half panes under the strip of the office")
	ok(Vector2(comp.get_viewport().get_visible_rect().size) == r1.size, "the pane viewport has its half-window size")

	# only slot 1 is frozen: slot 0 walks, slot 1 does not
	var x0: float = p1.global_position.x
	var x1: float = p2.global_position.x
	Input.action_press("move_right")
	Input.action_press("p2_move_right")
	await _wait(20)
	Input.action_release("move_right")
	Input.action_release("p2_move_right")
	ok(p1.global_position.x > x0 + 2.0, "player 1 keeps walking while player 2 is at the computer")
	ok(absf(p2.global_position.x - x1) < 1.0, "player 2 stands still at the computer")

	# the pad player moves the cursor with the right stick and A clicks it
	var m0: Vector2 = comp._mouse
	_stick(JOY_AXIS_RIGHT_X, 1.0)
	await _wait(30)
	_stick(JOY_AXIS_RIGHT_X, 0.0)
	ok(comp._mouse.x > m0.x + 20.0, "the right stick moves the pane's cursor (%.0f -> %.0f)" % [m0.x, comp._mouse.x])
	ok(comp._mouse.x <= float(r1.size.x) - 1.0, "the cursor stays inside the pane")
	comp.activate("app:psa")
	ok(comp.app == "psa", "an app opens in the pane")
	# B (device 1, passed on as ui_cancel) goes back one screen
	_pad(JOY_BUTTON_B, true)
	await _wait(3)
	_pad(JOY_BUTTON_B, false)
	await _wait(3)
	ok(not comp.is_open and not players.ui[1], "pad B closes the pane (nothing nested) and frees player 2")
	host.open_computer(1, 3)
	await _wait(10)

	# slot 0's own pad / keys do not drive slot 1's pane
	var app_before: String = comp.app
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(3)
	ok(comp.app == app_before and comp.is_open, "keys (slot 0) never reach slot 1's pane")

	# slot 0 opens its own pane at the same time, the other stays open
	var comp0: Node = host.open_computer(0, 1)
	await _wait(10)
	ok(comp0.is_open and comp.is_open and players.ui[0] and players.ui[1], "both players have a pane open")
	ok(comp0 != comp, "two Computer instances, one per player")
	var other_before: String = comp.app
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(3)
	ok(comp.app == other_before and comp.is_open, "keys reach slot 0's pane only")

	# the room keeps ticking underneath
	var before: float = root.get_node("World").clock
	await _wait(30)
	ok(root.get_node("World").clock != before, "the world clock keeps running with both panes open")

	# a room change closes the panes and frees both players
	game.go("kitchenette", "start")
	await create_timer(1.5).timeout
	await _wait(10)
	ok(not host.is_open(0) and not host.is_open(1), "a room change closes both panes")
	ok(not players.ui[0] and not players.ui[1], "both players are free again")
	players.enable_coop(false)
	print("coop_takeover: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
