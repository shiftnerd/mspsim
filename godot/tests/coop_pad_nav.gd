extends SceneTree
# Co-op phase 3: a pad player can walk a Computer pane without the stick: the shoulder buttons step the cursor through the
# screen's clickable regions (top to bottom, left to right), A clicks where it lands.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_pad_nav.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _btn(button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = 1
	ev.button_index = button
	ev.pressed = true
	return ev


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_coopnav_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopnav_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	var host: Node = players.takeover_host()
	var comp: Node = host.open_computer(1, 3)
	await _wait(15)
	ok(comp._hits.size() > 2, "the desktop has clickable regions (%d)" % comp._hits.size())
	var first: Vector2
	ok(host._pad_cursor(1, _btn(JOY_BUTTON_RIGHT_SHOULDER)), "RB steps the cursor")
	first = comp._mouse
	var inside := false
	for h in comp._hits:
		inside = inside or (h.r as Rect2).has_point(comp._mouse)
	ok(inside, "and lands inside a region")
	host._pad_cursor(1, _btn(JOY_BUTTON_RIGHT_SHOULDER))
	ok(comp._mouse != first, "RB again goes to the next one")
	host._pad_cursor(1, _btn(JOY_BUTTON_LEFT_SHOULDER))
	ok(comp._mouse == first, "LB goes back")
	host._pad_cursor(1, _btn(JOY_BUTTON_LEFT_SHOULDER))
	var wrapped: Vector2 = comp._mouse
	for i in comp._hits.size():
		host._pad_cursor(1, _btn(JOY_BUTTON_RIGHT_SHOULDER))
	ok(comp._mouse == wrapped, "a full lap comes back to the same region")
	var card := Node.new()
	ok(not host.snap_hit(null, 1) and not host.snap_hit(card, 1), "a screen without regions leaves the button alone")
	card.free()
	host.close_all()
	await _wait(5)
	players.enable_coop(false)
	print("coop_pad_nav: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
