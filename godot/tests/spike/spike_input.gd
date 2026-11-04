extends SceneTree
# THROWAWAY coop spike, risk 2 (docs/coop-risk-findings.md): second gamepad (device 1), per-device actions, the leak of the
# built-in ui_* actions, pad-only operation of a pane Computer with a virtual (stick) cursor.
#   Godot --fixed-fps 60 --path godot -s res://tests/spike/spike_input.gd        (needs a window: hits are painted)

const Lib := preload("res://tests/spike/spike_lib.gd")
const PixelFont := preload("res://scripts/pixelfont.gd")

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


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


# the prototype virtual cursor: right stick moves a pointer in the pane, A clicks what is under it, B backs out
class VCursor:
	extends Node
	var comp: Node
	var dev := 1
	var pos := Vector2(40, 40)
	var vel := Vector2.ZERO
	var speed := 140.0  # pane pixels per second at full tilt
	var clicks := 0

	func _input(event: InputEvent) -> void:
		if event is InputEventJoypadMotion and event.device == dev:
			if event.axis == JOY_AXIS_RIGHT_X:
				vel.x = event.axis_value if absf(event.axis_value) > 0.2 else 0.0
			elif event.axis == JOY_AXIS_RIGHT_Y:
				vel.y = event.axis_value if absf(event.axis_value) > 0.2 else 0.0
		elif event is InputEventJoypadButton and event.device == dev and event.pressed:
			if event.button_index == JOY_BUTTON_RIGHT_STICK or event.button_index == JOY_BUTTON_A:
				if hovered() != "" or event.button_index == JOY_BUTTON_RIGHT_STICK:
					clicks += 1
					comp.click(pos)
					get_viewport().set_input_as_handled()

	func tick(delta: float) -> void:
		var sz: Vector2 = Vector2(get_viewport().get_visible_rect().size)
		pos = (pos + vel * speed * delta).clamp(Vector2.ZERO, sz - Vector2.ONE)
		comp._mouse = pos
		comp._canvas.queue_redraw()

	func hovered() -> String:
		for i in range(comp._hits.size() - 1, -1, -1):
			if comp._hits[i].r.has_point(pos):
				return str(comp._hits[i].id)
		return ""


func _move_cursor_to(vc: VCursor, target: Vector2) -> bool:
	for i in 240:
		var d := target - vc.pos
		if d.length() < 2.0:
			vc.vel = Vector2.ZERO
			return true
		var v := (d / maxf(d.length(), 1.0)) * minf(1.0, d.length() / 20.0 + 0.25)
		vc._input(axis(1, JOY_AXIS_RIGHT_X, v.x))
		vc._input(axis(1, JOY_AXIS_RIGHT_Y, v.y))
		vc.tick(1.0 / 60.0)
		await process_frame
	return false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _wait(3)
	var ctl := root.get_node("Controls")
	# ---- A: what the input map says about devices
	for a in ["move_right", "jump", "interact", "ui_accept", "ui_cancel", "ui_up"]:
		var devs := []
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				devs.append(ev.device)
		print("INFO action %s pad event devices: %s" % [a, devs])
	var pads := Input.get_connected_joypads()
	print("INFO connected joypads on this machine: ", pads)
	# ---- B: device 0 vs device 1 on slot-0 actions and a p2 copy
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT))
	await process_frame
	ok(not Input.is_action_pressed("move_right"), "slot-0 action move_right ignores a device-1 D-pad press (device bound to 0)")
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT, false))
	Input.parse_input_event(btn(0, JOY_BUTTON_DPAD_RIGHT))
	await process_frame
	ok(Input.is_action_pressed("move_right"), "device-0 D-pad press drives move_right")
	Input.parse_input_event(btn(0, JOY_BUTTON_DPAD_RIGHT, false))
	await process_frame
	# per-slot copy of the whole ACTIONS table for device 1 (what Controls.ensure_slot would do)
	for action in ctl.ACTIONS:
		var name: String = "p2_" + action
		if InputMap.has_action(name):
			continue
		InputMap.add_action(name, 0.5)
		var spec: Array = ctl.ACTIONS[action]
		for b in spec[1]:
			var e := InputEventJoypadButton.new()
			e.button_index = b
			e.device = 1
			InputMap.action_add_event(name, e)
		for ax in spec[2]:
			var m := InputEventJoypadMotion.new()
			m.axis = ax[0]
			m.axis_value = ax[1]
			m.device = 1
			InputMap.action_add_event(name, m)
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT))
	await process_frame
	ok(Input.is_action_pressed("p2_move_right") and not Input.is_action_pressed("move_right"), "p2_move_right (device 1) fires, move_right does not")
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_RIGHT, false))
	Input.parse_input_event(btn(0, JOY_BUTTON_X))
	Input.parse_input_event(btn(1, JOY_BUTTON_X))
	await process_frame
	ok(Input.is_action_pressed("interact") and Input.is_action_pressed("p2_interact"), "both pads press X at once: interact and p2_interact both true")
	Input.parse_input_event(btn(0, JOY_BUTTON_X, false))
	Input.parse_input_event(btn(1, JOY_BUTTON_X, false))
	# stick analog strength per device
	Input.parse_input_event(axis(1, JOY_AXIS_LEFT_X, 0.8))
	await process_frame
	print("INFO stick 0.8 on pad 2: p2_move_right strength=%s (deadzone remapped), move_right=%s" % [Input.get_action_strength("p2_move_right"), Input.get_action_strength("move_right")])
	ok(Input.get_action_strength("p2_move_right") > 0.3 and Input.get_action_strength("move_right") == 0.0, "left stick on pad 2 drives p2_move_right only")
	Input.parse_input_event(axis(1, JOY_AXIS_LEFT_X, 0.0))
	ok(absf(Input.get_joy_axis(1, JOY_AXIS_LEFT_X)) < 0.01 or true, "(info) Input.get_joy_axis after injection = %s" % Input.get_joy_axis(1, JOY_AXIS_LEFT_X))
	# ---- C: the leak: built-in ui_accept is device -1
	var ev_a := btn(1, JOY_BUTTON_A)
	ok(not ev_a.is_action("ui_accept"), "GAP: a device-1 A press is NOT ui_accept (Controls registers it with device 0): pad 2 cannot confirm anything today")
	ok(not ctl.confirm(ev_a) and not ctl.back(btn(1, JOY_BUTTON_B)), "GAP: Controls.confirm / back ignore pad 2 (A and B)")
	ok(btn(1, JOY_BUTTON_DPAD_DOWN).is_action("ui_down"), "LEAK: ui_up/down/left/right are device -1 (any pad): a D-pad press on EITHER pad navigates EVERY open takeover")
	ok(ctl.nav(btn(1, JOY_BUTTON_DPAD_UP)) == "up", "Controls.nav(device-1 D-pad up) = up (also unguarded)")
	# stick-push state is keyed by device*32+axis: two pads do not eat each other's pushes
	await _wait(2)
	var s0 := axis(0, JOY_AXIS_RIGHT_Y, 1.0)
	await _wait(1)
	var s1 := axis(1, JOY_AXIS_RIGHT_Y, 1.0)
	ok(ctl.pressed(s0) and ctl.pressed(s1), "Controls.pressed(stick) keeps per-device push state (pad 0 then pad 1 on the same axis both fire once)")
	ok(not ctl.pressed(axis(1, JOY_AXIS_RIGHT_Y, 1.0)), "...and a held push on pad 1 does not re-fire")
	ctl.pressed(axis(0, JOY_AXIS_RIGHT_Y, 0.0))
	ctl.pressed(axis(1, JOY_AXIS_RIGHT_Y, 0.0))
	# ---- D: panes: does a SubViewportContainer forward pad events, does the autoload Computer also react?
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(12)
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_spikei_%d_" % OS.get_process_id()
	camp.new_game("tech")
	camp.day = 9
	var msp := root.get_node("Msp")
	for i in 3:
		msp.create_ticket(i, i, "spike")
	var auto := root.get_node("Computer")
	var sv := Lib.make_pane(root, Vector2i(160, 180))
	var pc = Lib.pane_script("res://scripts/computer.gd").new()
	pc.pad_device = 1
	sv.add_child(pc)
	await _wait(2)
	pc.open(2)
	auto.open(1)  # slot 0 has its own computer open at the same time
	await create_timer(0.4).timeout
	await _wait(3)
	root.get_node("Game").ui_open = false
	# real routing test 1: root.parse_input_event of a device-1 "down" D-pad press: who sees it?
	var seen_auto := [0]
	var seen_pane := [0]
	var old_tab = auto.mail_sel
	auto.app = "mail"
	pc.app = "mail"
	auto.mail_sel = 0
	pc.mail_sel = 0
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_DOWN))
	await _wait(3)
	Input.parse_input_event(btn(1, JOY_BUTTON_DPAD_DOWN, false))
	print("INFO device-1 DOWN through Input.parse_input_event: autoload Computer mail_sel=%d (was 0), pane mail_sel=%d (was 0)" % [auto.mail_sel, pc.mail_sel])
	ok(auto.mail_sel == 1, "autoload Computer (slot 0) REACTS to a device-1 press (needs slot filter to change)")
	print("INFO pane Computer reacted to the root-routed event: ", pc.mail_sel == 1, " (SubViewportContainer forwards: ", pc.mail_sel == 1, ")")
	# route 2: push_input straight into the pane's viewport (a host routes by slot)
	pc.mail_sel = 0
	auto.mail_sel = 0
	sv.push_input(btn(1, JOY_BUTTON_DPAD_DOWN))
	await _wait(2)
	ok(pc.mail_sel == 1 and auto.mail_sel == 0, "sv.push_input(device 1 DOWN): only the pane Computer moves (mail_sel 0 -> 1)")
	sv.push_input(btn(0, JOY_BUTTON_DPAD_DOWN))
	await _wait(2)
	ok(pc.mail_sel == 1, "pane ignores a device-0 press (pad_device guard)")
	auto.close()
	await _wait(5)
	# ---- E: pad-only, no keyboard, no mouse: what does the D-pad alone do on the desktop?
	pc.app = "desktop"
	var app0: String = pc.app
	for b in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A]:
		sv.push_input(btn(1, b))
		sv.push_input(btn(1, b, false))
		await _wait(2)
	ok(pc.app == app0, "pad only, no cursor: D-pad + A on the desktop do NOTHING (app still '%s'): the desktop has no focus model" % pc.app)
	var vc := VCursor.new()
	vc.comp = pc
	sv.add_child(vc)  # added AFTER the computer: _input runs last-added first, so the cursor sees the event first
	ok(not ("app:psa" in [] ), "(cursor attached)")
	# ---- E2: virtual cursor reaches everything on the desktop
	await _wait(4)
	var desktop_ids := []
	for h in pc._hits:
		desktop_ids.append(str(h.id))
	print("INFO desktop hit ids: ", desktop_ids)
	var reached := 0
	var tried := 0
	for h in pc._hits.duplicate():
		var id := str(h.id)
		if not id.begins_with("app:"):
			continue
		tried += 1
		pc.activate("close_app")
		await _wait(2)
		var center: Vector2 = h.r.position + h.r.size * 0.5
		var good := await _move_cursor_to(vc, center)
		sv.push_input(btn(1, JOY_BUTTON_A))
		sv.push_input(btn(1, JOY_BUTTON_A, false))
		await _wait(3)
		if good and pc.app == id.substr(4):
			reached += 1
		else:
			print("  cursor miss for ", id, " app now ", pc.app, " moved=", good)
		pc.app = "desktop"
		await _wait(3)
	ok(tried > 0 and reached == tried, "virtual cursor (right stick + A, device 1 only) opened %d / %d desktop apps" % [reached, tried])
	# ---- E3: end to end pad-only: PSA ticket -> RMM -> connect -> fix, then close the ticket
	pc.activate("app:psa")
	await _wait(4)
	var tk := ""
	for h in pc._hits:
		if str(h.id).begins_with("tk:"):
			tk = str(h.id)
			break
	var hit_r: Rect2
	for h in pc._hits:
		if str(h.id) == tk:
			hit_r = h.r
	await _move_cursor_to(vc, hit_r.position + hit_r.size * 0.5)
	sv.push_input(btn(1, JOY_BUTTON_A))
	sv.push_input(btn(1, JOY_BUTTON_A, false))
	await _wait(3)
	ok(pc.psa_detail, "cursor click opens the ticket row (%s)" % tk)
	# the keyboard path that exists: B backs out
	sv.push_input(btn(1, JOY_BUTTON_B))
	sv.push_input(btn(1, JOY_BUTTON_B, false))
	await _wait(3)
	ok(pc.psa_detail, "GAP (expected): B from pad 2 does NOT step back (ui_cancel is device 0 only)")
	# how many hit rectangles per screen (what a cursor must reach) and how many have no key path
	var apps := ["desktop", "mail", "psa", "rmm", "learn", "stats", "lync", "nerds", "dash"]
	for a in apps:
		pc.activate("close_app")
		pc.app = a
		pc.psa_detail = false
		pc._canvas.queue_redraw()
		await _wait(4)
		var n: int = pc._hits.size()
		var off := 0
		for h in pc._hits:
			var c: Vector2 = h.r.position + h.r.size * 0.5
			if not Rect2(Vector2.ZERO, Vector2(160, 180)).has_point(c):
				off += 1
		print("INFO app %-8s hit rects=%d, centers outside the pane=%d" % [a, n, off])
	print("failures=", fails)
	quit(1 if fails > 0 else 0)
