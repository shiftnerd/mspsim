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

	# the phone is a pane too: each player's own, with its own freeze
	host.close_all()
	await _wait(30)
	ok(not players.ui[0] and not players.ui[1], "both panes closed")
	var ph: Node = host.open_phone(1)
	await _wait(10)
	ok(ph != null and ph.is_open and ph.pane_slot == 1 and players.ui[1] and not players.ui[0], "slot 1's phone opens as a pane and freezes only slot 1")
	ok(not root.get_node("Phone").is_open and not game.ui_open, "the full-window phone autoload stays closed")
	var ph0: Node = host.open_phone(0)
	await _wait(10)
	ok(ph0 != null and ph0 != ph and ph0.is_open and ph.is_open, "both players hold their own phone at once")
	ok(host.open_phone(1) == null, "a player with a pane open cannot open another")
	host.close_all()
	await _wait(30)
	ok(not host.is_open(0) and not host.is_open(1), "closing frees both")
	var pev := InputEventAction.new()
	pev.action = "p2_phone"
	pev.pressed = true
	Input.parse_input_event(pev)
	await _wait(10)
	ok(host.is_open(1) and host.active(1).pane_slot == 1, "player 2's phone key opens their phone pane")
	host.close_all()
	await _wait(30)

	# cards: a personal card (scope player) shows in its owner's pane and holds only them
	var cards: Node = root.get_node("Cards")
	var picked := []
	cards.ask("Someone", "Hello there.", [{"label": "HI", "id": "hi"}, {"label": "LEAVE", "id": "leave"}], func(id: String) -> void: picked.append(id), Callable(), 1)
	await _wait(5)
	var pc: Node = host.card_for(1)
	ok(pc.is_open and pc.pane_slot == 1 and players.ui[1] and not players.ui[0], "a player-scope card opens in slot 1's pane and holds only slot 1")
	ok(not cards.is_open and not game.ui_open, "the team card stays shut and the room is not frozen")
	pc._opened = 0  # the early-confirm guard counts wall-clock ms, a headless run is faster
	_pad(JOY_BUTTON_A, true)
	await _wait(3)
	_pad(JOY_BUTTON_A, false)
	await _wait(3)
	ok(picked == ["hi"] and not pc.is_open and not players.ui[1], "pad A on slot 1 picks the card and frees them")
	# a team card (the old full-window one): pad 2's A confirms it too
	var team := []
	cards.ask("Boss", "Everyone listen.", [{"label": "OK", "id": "ok"}], func(id: String) -> void: team.append(id))
	cards._opened = 0
	ok(cards.is_open and game.ui_open, "a team card is the full-window freeze")
	_pad(JOY_BUTTON_A, true)
	await _wait(3)
	_pad(JOY_BUTTON_A, false)
	await _wait(3)
	ok(team == ["ok"] and not cards.is_open, "player 2's A answers a team card (first to confirm wins)")
	await _wait(5)

	# a door refuses while the partner is at a screen; trying again makes them leave
	host.open_computer(1, 3)
	await _wait(10)
	var door: Node = null
	for d in current_scene.find_children("*", "Area2D", true, false):
		if d.has_method("is_locked") and not d.auto and d.special == "" and d.occupancy == "":
			door = d
	ok(door != null, "the room has a plain door")
	ok(players.busy_partner(p1) == 1 and players.busy_partner(p2) == -1, "player 1 sees player 2 as busy, not the other way round")
	var scene_before := current_scene
	door.use(p1)
	await _wait(5)
	ok(players.ui[1] and current_scene == scene_before, "the first door try is refused and the pane stays")
	door.use(p1)
	await create_timer(1.5).timeout
	ok(current_scene != scene_before, "the second try takes both through and closes the partner's pane")
	ok(not players.ui[1], "the partner is free")
	await _wait(10)
	host.close_all()
	await _wait(10)

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
