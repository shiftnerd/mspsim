extends SceneTree
# Co-op phase 1: two pads. Per-device p2_ actions, slot-aware confirm / back (pad 2 could not confirm or go back), no
# cross-talk between pads, join by A on pad 2, and the flag off changing nothing. Simulated like the spike
# (godot/tests/spike/spike_input.gd): InputEventJoypadButton / Motion with device 1.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_input.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func btn(dev: int, b: int, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	e.pressed = pressed
	return e


func axis(dev: int, a: int, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = a
	e.axis_value = v
	return e


func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_coopinput_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopinput_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var ctl := root.get_node("Controls")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	var stage := current_scene
	var p1: Node = stage.get_node("Actors/Player")

	# ---- flag off: nothing registered, pad 2 does nothing
	ok(not players.coop and not InputMap.has_action("p2_jump"), "flag off: no p2_ actions")
	ok(ctl.confirm_for(btn(0, JOY_BUTTON_A), 0), "flag off: confirm_for(pad 0 A, slot 0) is the old confirm")
	ok(ctl.confirm(btn(0, JOY_BUTTON_A)) and not ctl.confirm(btn(1, JOY_BUTTON_A)), "flag off: the old Controls.confirm is unchanged (pad 2 cannot confirm)")
	ok(not ctl.confirm_for(btn(1, JOY_BUTTON_A), 1) and not ctl.back_for(btn(1, JOY_BUTTON_B), 1), "flag off: nothing confirms for slot 1")
	Input.parse_input_event(btn(1, JOY_BUTTON_A))
	await _wait(4)
	Input.parse_input_event(btn(1, JOY_BUTTON_A, false))
	ok(players.node(1) == null and players.count() == 1, "flag off: A on pad 2 does not join")
	ok(ctl.slot_of(btn(1, JOY_BUTTON_A)) == -1 and ctl.slot_of(btn(0, JOY_BUTTON_A)) == 0, "slot_of: pad 0 is slot 0, an unclaimed pad is -1")

	# ---- flag on, before anyone joins
	players.enable_coop(true)
	var reg := InputMap.has_action("p2_move_right") and InputMap.has_action("p2_ui_accept") and InputMap.has_action("p2_ui_cancel")
	ok(reg, "enable_coop registers the p2_ table and the pad 2 confirm / cancel")
	ok(not InputMap.has_action("p2_nope"), "(sanity) unknown action is unknown")
	var table_ok := true
	for action in ctl.ACTIONS:
		table_ok = table_ok and InputMap.has_action("p2_" + action)
	ok(table_ok, "every Controls.ACTIONS entry has a p2_ copy")

	# cross-talk: dpad right on pad 2 is p2_move_right only; on pad 0 move_right only
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT))
	await _wait(2)
	ok(Input.is_action_pressed("p2_move_right") and not Input.is_action_pressed("move_right"), "pad 2 D-pad right: p2_move_right only")
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT, false))
	Input.parse_input_event(btn(0, JOY_BUTTON_DPAD_RIGHT))
	await _wait(2)
	ok(Input.is_action_pressed("move_right") and not Input.is_action_pressed("p2_move_right"), "pad 1 D-pad right: move_right only")
	Input.parse_input_event(btn(0, JOY_BUTTON_DPAD_RIGHT, false))
	Input.parse_input_event(btn(0, JOY_BUTTON_X))
	Input.parse_input_event(btn(1, JOY_BUTTON_X))
	await _wait(2)
	ok(Input.is_action_pressed("interact") and Input.is_action_pressed("p2_interact"), "both pads press X at once: both interact actions")
	Input.parse_input_event(btn(0, JOY_BUTTON_X, false))
	Input.parse_input_event(btn(1, JOY_BUTTON_X, false))
	Input.parse_input_event(axis(1, JOY_AXIS_LEFT_X, 0.9))
	await _wait(2)
	ok(Input.get_action_strength("p2_move_right") > 0.3 and Input.get_action_strength("move_right") == 0.0, "the left stick of pad 2 drives p2_move_right only")
	Input.parse_input_event(axis(1, JOY_AXIS_LEFT_X, 0.0))
	await _wait(2)

	# ---- slot-aware confirm / back
	var a1 := btn(1, JOY_BUTTON_A)
	var a0 := btn(0, JOY_BUTTON_A)
	var b1 := btn(1, JOY_BUTTON_B)
	var b0 := btn(0, JOY_BUTTON_B)
	ok(not ctl.confirm_for(a1, 1) and not ctl.confirm_for(a1, 0), "pad 2 A confirms for nobody until slot 1 has joined")
	ok(ctl.confirm_for(a0, 0) and not ctl.confirm_for(a0, 1), "pad 1 A confirms for slot 0 only")
	ok(not ctl.back_for(b1, 1) and not ctl.back_for(b1, 0), "pad 2 B goes back for nobody until slot 1 has joined")
	ok(ctl.back_for(b0, 0) and not ctl.back_for(b0, 1), "pad 1 B goes back for slot 0 only")
	ok(ctl.confirm_for(key(KEY_ENTER), 0) and not ctl.confirm_for(key(KEY_ENTER), 1), "Enter is slot 0's")
	ok(ctl.back_for(key(KEY_ESCAPE), 0) and not ctl.back_for(key(KEY_ESCAPE), 1), "Esc is slot 0's")
	ok(not ctl.confirm_for(key(KEY_E), 0, false, false) and ctl.confirm_for(key(KEY_E), 0), "the with_e / with_space switches still work for slot 0")
	ok(not ctl.confirm_for(btn(1, JOY_BUTTON_X), 1), "X on pad 2 is not a confirm")
	ok(not ctl.confirm(a1) and not ctl.back(b1), "the old Controls.confirm / back still ignore pad 2 (callers move to *_for per screen later)")

	# ---- join by A on pad 2
	Input.parse_input_event(a0)
	await _wait(3)
	Input.parse_input_event(btn(0, JOY_BUTTON_A, false))
	ok(players.node(1) == null, "A on pad 1 does not join (it is slot 0's)")
	var game := root.get_node("Game")
	game.ui_open = true
	Input.parse_input_event(a1)
	await _wait(3)
	Input.parse_input_event(btn(1, JOY_BUTTON_A, false))
	ok(players.node(1) == null, "no join while a takeover is open")
	game.ui_open = false
	Input.parse_input_event(a1)
	await _wait(10)
	Input.parse_input_event(btn(1, JOY_BUTTON_A, false))
	var p2: Node = players.node(1)
	ok(p2 != null and players.slot(1).joined and players.slot(1).device == 1, "A on pad 2 joins slot 1 (device 1)")
	ok(ctl.slot_of(btn(1, JOY_BUTTON_A)) == 1 and ctl.slot_of(key(KEY_A)) == 0, "slot_of: pad 2 is now slot 1, keys stay slot 0")
	ok(current_scene == stage, "joining did not change the room")
	ok(ctl.confirm_for(a1, 1) and not ctl.confirm_for(a1, 0), "joined: pad 2 A confirms for slot 1 only")
	ok(ctl.back_for(b1, 1) and not ctl.back_for(b1, 0), "joined: pad 2 B goes back for slot 1 only")
	ok(not ctl.confirm_for(a0, 1) and ctl.confirm_for(a0, 0), "joined: pad 1 A is still slot 0's")

	# ---- driving both bodies from two pads
	var x1: float = p1.global_position.x
	var x2: float = p2.global_position.x
	Input.parse_input_event(axis(1, JOY_AXIS_LEFT_X, 1.0))
	await _wait(40)
	Input.parse_input_event(axis(1, JOY_AXIS_LEFT_X, 0.0))
	ok(p2.global_position.x > x2 + 5.0 and absf(p1.global_position.x - x1) < 1.0, "pad 2's stick walks P2 only (%.1f px)" % (p2.global_position.x - x2))
	x1 = p1.global_position.x
	x2 = p2.global_position.x
	Input.parse_input_event(btn(0, JOY_BUTTON_DPAD_RIGHT))
	await _wait(40)
	Input.parse_input_event(btn(0, JOY_BUTTON_DPAD_RIGHT, false))
	ok(p1.global_position.x > x1 + 5.0 and absf(p2.global_position.x - x2) < 1.0, "pad 1's D-pad walks P1 only")
	# pad 2 jump (A) does not trigger slot 0's jump action
	Input.parse_input_event(a1)
	await _wait(2)
	ok(Input.is_action_pressed("p2_jump") and not Input.is_action_pressed("jump"), "A on pad 2 is p2_jump, not jump")
	Input.parse_input_event(btn(1, JOY_BUTTON_A, false))

	# ---- re-bind: slot 1 leaves, the flag moves it to pad 3
	players.leave(1)
	ok(players.node(1) == null and ctl.slot_of(btn(1, JOY_BUTTON_A)) == -1, "leave frees the slot and its pad")
	ok(players.join(1, 3), "slot 1 can join on pad 3")
	await _wait(6)
	Input.parse_input_event(btn(3, JOY_BUTTON_DPAD_LEFT))
	await _wait(2)
	ok(Input.is_action_pressed("p2_move_left"), "p2_ actions re-bound to pad 3")
	Input.parse_input_event(btn(3, JOY_BUTTON_DPAD_LEFT, false))
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT))
	await _wait(2)
	ok(not Input.is_action_pressed("p2_move_right"), "...and pad 2 no longer drives them")
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT, false))
	ok(ctl.confirm_for(btn(3, JOY_BUTTON_A), 1) and not ctl.confirm_for(btn(1, JOY_BUTTON_A), 1), "confirm_for(slot 1) follows the new device")

	print("failures=", fails)
	quit(1 if fails > 0 else 0)
