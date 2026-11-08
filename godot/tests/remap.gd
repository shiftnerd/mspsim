extends SceneTree
# Phase 8: the walking actions can be put on other keys: swap on a clash, one key per action, saved and loaded, put back; the pause
# menu's R page drives it.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/remap.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var controls := root.get_node("Controls")
	controls.binds_path = "user://test_%d_controls.cfg" % OS.get_process_id()
	controls.reset_binds()
	ok(controls.key_of("interact") == KEY_E and controls.key_of("jump") == KEY_SPACE, "the default keys")
	ok(controls.matches(_key(KEY_E), "interact"), "E interacts by default")
	ok(not controls.rebind("pause", KEY_P) and not controls.rebind("interact", 0), "only the walking actions, and only a real key")
	ok(controls.rebind("interact", KEY_G), "interact goes to G")
	ok(controls.key_of("interact") == KEY_G and controls.matches(_key(KEY_G), "interact"), "G interacts")
	ok(not controls.matches(_key(KEY_E), "interact"), "and E no longer does")
	var codes := []
	for ev in InputMap.action_get_events("interact"):
		if ev is InputEventKey:
			codes.append(ev.physical_keycode)
	ok(codes == [KEY_G], "the action holds the one new key (%s)" % [codes])
	# a clash swaps
	ok(controls.rebind("wave", KEY_G), "wave onto G, which interact holds")
	ok(controls.key_of("wave") == KEY_G and controls.key_of("interact") == KEY_E or controls.key_of("interact") != KEY_G, "interact is given wave's old key, not left on the same key")
	# save and load
	controls.save_binds()
	var kept: int = controls.key_of("wave")
	controls.reset_binds()
	ok(controls.key_of("wave") == KEY_Q and controls.matches(_key(KEY_Q), "wave"), "put back: Q waves again")
	controls.load_binds()
	ok(controls.key_of("wave") == kept, "loading the file brings the remap back")
	controls.reset_binds()
	controls.save_binds()
	ok(not FileAccess.file_exists(controls.binds_path), "put back and saved leaves no file")
	# the pause menu's page
	var pm := root.get_node("PauseMenu")
	pm._page = 0
	pm._key(_key(KEY_R))
	ok(pm._page == pm.REMAP_PAGE, "R on the key list opens the remap page")
	pm._key(_key(KEY_ENTER))
	ok(pm._capture, "Enter waits for a key")
	pm._remap_key(_key(KEY_J))
	ok(controls.key_of("move_left") == KEY_J and not pm._capture, "the next key is taken")
	pm._rsel = 1
	pm._remap_key(_key(KEY_ENTER))
	pm._remap_key(_key(KEY_ESCAPE))
	ok(not pm._capture and controls.key_of("move_right") == KEY_D, "Escape cancels the wait and changes nothing")
	pm._rsel = controls.REMAPPABLE.size()
	pm._remap_key(_key(KEY_ENTER))
	ok(controls.key_of("move_left") == KEY_A, "the last row puts every key back")
	pm._remap_key(_key(KEY_ESCAPE))
	ok(pm._page == 0, "Escape goes back to the key list")
	controls.reset_binds()
	controls.save_binds()
	print("remap: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
