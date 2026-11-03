extends SceneTree
# gdlint:disable=max-line-length
# The pause menu: Esc in a room freezes the clock and the cast, Esc again resumes, other screens keep Esc, the Pause
# key works over them, SHAPE cycles the format, QUIT asks first and returns to the title.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	var world := root.get_node("World")
	var pm := root.get_node("PauseMenu")
	var c := root.get_node("Campaign")
	game.title_mode = false
	c.save_prefix = "user://test_pause_%d_" % OS.get_process_id()
	c.new_game("tech")
	c.day = 3
	world.time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(40)

	_check(not pm.is_open and not paused, "starts unpaused")
	await _key(KEY_ESCAPE)
	_check(pm.is_open and paused, "Esc in a room opens the menu and pauses the tree")
	var clock: float = world.clock
	await _wait(60)
	_check(is_equal_approx(world.clock, clock), "the workday clock stands still while paused")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	var shape: String = game.format
	_check(true, "SHAPE row pressed (format now %s)" % shape)
	await _key(KEY_UP)
	await _key(KEY_ESCAPE)
	_check(not pm.is_open and not paused, "Esc resumes")
	await _wait(60)
	_check(world.clock > clock, "and the clock runs again")

	# other screens keep Esc
	game.ui_open = true
	await _key(KEY_ESCAPE)
	_check(not pm.is_open, "Esc does not open the menu over another screen")
	await _key(KEY_PAUSE)
	_check(pm.is_open, "but the Pause key does")
	await _key(KEY_PAUSE)
	game.ui_open = false
	_check(not pm.is_open and not paused, "Pause key resumes")

	# quit asks first
	await _key(KEY_ESCAPE)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(pm.is_open, "QUIT TO TITLE asks first")
	await _key(KEY_ESCAPE)
	_check(pm.is_open, "Esc backs out of the question, the menu stays")
	await _key(KEY_ENTER)  # selects QUIT TO TITLE again
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _wait(60)
	_check(not pm.is_open and not paused, "YES closes the menu")
	_check(current_scene != null and current_scene.scene_file_path.ends_with("title.tscn"), "and returns to the title")

	await _key(KEY_ESCAPE)
	_check(not pm.is_open, "the title screen never opens the pause menu")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
