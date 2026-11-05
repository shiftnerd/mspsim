extends SceneTree
# gdlint:disable=max-line-length
# Controls' menu helpers: pressed / nav / step / confirm / back answer for plain key events (tests, keyboards),
# pad buttons, the stick and named actions alike.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/controls.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: int, pressed := true, echo := false, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	e.shift_pressed = shift
	return e


func _pad(button: int, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _stick(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _act(name: String, pressed := true) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = pressed
	return e


func _init() -> void:
	await process_frame
	var c := root.get_node("Controls")
	# pressed: fresh presses only
	_check(c.pressed(_key(KEY_A)), "a key press is a press")
	_check(not c.pressed(_key(KEY_A, false)), "a key release is not")
	_check(not c.pressed(_key(KEY_A, true, true)), "a key repeat is not")
	_check(c.pressed(_pad(JOY_BUTTON_A)) and not c.pressed(_pad(JOY_BUTTON_A, false)), "a pad button press, not its release")
	_check(c.pressed(_act("ui_down")) and not c.pressed(_act("ui_down", false)), "an action press, not its release")
	_check(not c.pressed(InputEventMouseMotion.new()), "the mouse is not a press")
	# nav: arrows, W A S D, D-pad, ui actions
	_check(c.nav(_key(KEY_UP)) == "up" and c.nav(_key(KEY_DOWN)) == "down", "arrows up and down")
	_check(c.nav(_key(KEY_LEFT)) == "left" and c.nav(_key(KEY_RIGHT)) == "right", "arrows left and right")
	_check(c.nav(_key(KEY_W)) == "up" and c.nav(_key(KEY_S)) == "down", "W and S")
	_check(c.nav(_key(KEY_A)) == "left" and c.nav(_key(KEY_D)) == "right", "A and D")
	_check(c.nav(_key(KEY_W), false) == "" and c.nav(_key(KEY_D), false) == "", "letters off: W and D are nothing")
	_check(c.nav(_key(KEY_UP), false) == "up", "letters off: the arrows still work")
	_check(c.nav(_key(KEY_UP, true, true)) == "" and c.nav(_key(KEY_UP, false)) == "", "a repeat or a release is nothing")
	_check(c.nav(_key(KEY_ENTER)) == "" and c.nav(_key(KEY_X)) == "", "other keys are nothing")
	_check(c.nav(_pad(JOY_BUTTON_DPAD_UP)) == "up" and c.nav(_pad(JOY_BUTTON_DPAD_DOWN)) == "down", "D-pad up and down")
	_check(c.nav(_pad(JOY_BUTTON_DPAD_LEFT)) == "left" and c.nav(_pad(JOY_BUTTON_DPAD_RIGHT)) == "right", "D-pad left and right")
	_check(c.nav(_pad(JOY_BUTTON_DPAD_UP, false)) == "", "a D-pad release is nothing")
	_check(c.nav(_pad(JOY_BUTTON_A)) == "", "A is not a direction")
	_check(c.nav(_act("ui_left")) == "left" and c.nav(_act("ui_right")) == "right", "the ui_left and ui_right actions")
	_check(c.nav(_act("ui_up")) == "up" and c.nav(_act("ui_down")) == "down", "the ui_up and ui_down actions")
	_check(c.step(_key(KEY_UP), true) == -1 and c.step(_key(KEY_DOWN), true) == 1 and c.step(_key(KEY_LEFT), true) == 0, "step, vertical")
	_check(c.step(_key(KEY_LEFT), false) == -1 and c.step(_key(KEY_D), false) == 1 and c.step(_key(KEY_D), false, false) == 0, "step, horizontal")
	# the stick: one press per push past half way
	_check(c.nav(_stick(JOY_AXIS_LEFT_Y, 1.0)) == "down", "the stick pushed down is down")
	_check(c.nav(_stick(JOY_AXIS_LEFT_Y, 0.9)) == "", "the stick held down does not repeat")
	_check(c.nav(_stick(JOY_AXIS_LEFT_Y, 0.0)) == "", "the stick back to centre is nothing")
	_check(c.nav(_stick(JOY_AXIS_LEFT_Y, -1.0)) == "up", "then pushed up is up")
	var one := _stick(JOY_AXIS_LEFT_X, 1.0)
	_check(c.nav(one) == "right" and c.nav(one) == "right", "two screens looking at one stick event both see the push")
	# confirm / back, with the stricter forms the old screens had
	_check(c.confirm(_key(KEY_ENTER)) and c.confirm(_key(KEY_KP_ENTER)) and c.confirm(_key(KEY_SPACE)) and c.confirm(_key(KEY_E)), "confirm: Enter, Space, E")
	_check(not c.confirm(_key(KEY_E), false) and c.confirm(_key(KEY_SPACE), false), "confirm without E")
	_check(not c.confirm(_key(KEY_E), false, false) and not c.confirm(_key(KEY_SPACE), false, false) and c.confirm(_key(KEY_ENTER), false, false), "confirm, Enter only")
	_check(c.confirm(_pad(JOY_BUTTON_A)) and c.confirm(_act("ui_accept")) and not c.confirm(_pad(JOY_BUTTON_DPAD_UP)), "confirm from the pad A button and the ui_accept action")
	_check(c.back(_key(KEY_ESCAPE)) and c.back(_key(KEY_BACKSPACE)), "back: Esc, Backspace")
	_check(c.back(_key(KEY_ESCAPE), false) and not c.back(_key(KEY_BACKSPACE), false), "back, Esc only")
	_check(c.back(_pad(JOY_BUTTON_B)) and c.back(_act("ui_cancel")) and not c.back(_pad(JOY_BUTTON_A)), "back from the pad B button and the ui_cancel action")
	# matches still takes plain keys and pad buttons
	_check(c.matches(_key(KEY_Z), "push_a") and c.matches(_pad(JOY_BUTTON_A), "push_a"), "push_a: Z and the A button")
	_check(c.matches(_key(KEY_X), "push_b") and c.matches(_pad(JOY_BUTTON_B), "push_b"), "push_b: X and the B button")
	_check(c.matches(_key(KEY_E), "interact") and c.matches(_pad(JOY_BUTTON_X), "interact"), "interact: E and the X button")
	# a real event through the engine reaches nav the same way
	var seen := []
	var script := GDScript.new()
	script.source_code = "extends Node\nvar seen: Array\nfunc _input(event: InputEvent) -> void:\n\tvar d: String = Controls.nav(event)\n\tif d != \"\":\n\t\tseen.append(d)\n"
	script.reload()
	var probe := Node.new()
	probe.set_script(script)
	probe.seen = seen
	root.add_child(probe)
	Input.parse_input_event(_pad(JOY_BUTTON_DPAD_DOWN))
	await process_frame
	await process_frame
	Input.parse_input_event(_key(KEY_UP))
	await process_frame
	await process_frame
	_check(seen == ["down", "up"], "events sent through Input reach a handler as nav: %s" % str(seen))
	# ---- run is bound to Shift both as a physical key and as a logical key (macOS reports modifiers by their logical key)
	var phys := false
	var logical := false
	for ev in InputMap.action_get_events("run"):
		if ev is InputEventKey:
			phys = phys or (ev.physical_keycode == KEY_SHIFT and ev.keycode == KEY_NONE)
			logical = logical or (ev.keycode == KEY_SHIFT and ev.physical_keycode == KEY_NONE)
	_check(phys and logical, "run listens for Shift by physical and by logical key")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
