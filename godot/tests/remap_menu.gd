extends SceneTree
# Remapping the menus' and mini-games' fixed keys: an extra key per role, reserved keys refused, typing left alone, saved.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/remap_menu.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.keycode = code as Key
	e.pressed = pressed
	return e


class Typist:
	extends Node
	var on := false

	func is_typing() -> bool:
		return on


func _run() -> void:
	var controls := root.get_node("Controls")
	controls.binds_path = "user://test_remapmenu_%d.cfg" % OS.get_process_id()
	controls.reset_binds()
	ok(controls.menu_key_of("menu_confirm") == -1, "no extra key by default")
	ok(controls.rebind_menu("menu_confirm", KEY_U), "J can be the extra confirm")
	ok(controls.menu_key_of("menu_confirm") == KEY_U, "and it reads back")
	ok(not controls.rebind_menu("menu_back", KEY_ENTER), "the plain menu keys are refused")
	ok(not controls.rebind_menu("menu_back", KEY_F9), "so are the debug keys")
	ok(not controls.rebind_menu("menu_back", controls.key_of("jump")), "and a walking key")
	ok(not controls.rebind_menu("nope", KEY_T), "an unknown role is refused")
	ok(controls.rebind_menu("game_a", KEY_U), "a key another role had moves over")
	ok(controls.menu_key_of("menu_confirm") == -1 and controls.menu_key_of("game_a") == KEY_U, "and the old role lets go of it")
	controls.rebind_menu("menu_confirm", KEY_U)
	ok(controls.rebind_menu("menu_up", KEY_I) and controls.rebind_menu("game_cool", KEY_T), "more roles")

	# the walking rebind takes a key away from the menu alias
	var walk_key := KEY_L
	controls.rebind_menu("menu_down", walk_key)
	controls.rebind("jump", walk_key)
	ok(controls.menu_key_of("menu_down") == -1, "putting a walking action on a key frees it from the menu")
	controls.rebind("jump", KEY_SPACE)

	# the translation: J is delivered as Enter
	var typist := Typist.new()
	typist.add_to_group("typing_screen")
	root.add_child(typist)
	# run the autoload handler directly and watch what it injects
	var probe := GDScript.new()
	probe.source_code = "extends Node\nvar got: Array = []\nfunc _input(e):\n\tif e is InputEventKey and e.pressed:\n\t\tgot.append(int(e.keycode))\n"
	probe.reload()
	var node := Node.new()
	node.set_script(probe)
	root.add_child(node)
	await process_frame
	controls._input(_key(KEY_U))
	await process_frame
	await process_frame
	ok(node.got.has(KEY_ENTER), "an aliased J reaches the screens as Enter (%s)" % [node.got])
	node.got.clear()
	typist.on = true
	controls._input(_key(KEY_U))
	await process_frame
	await process_frame
	ok(not node.got.has(KEY_ENTER), "while a text field has the focus the key is left alone")
	typist.on = false
	controls.capturing = true
	controls._input(_key(KEY_U))
	await process_frame
	await process_frame
	ok(not node.got.has(KEY_ENTER), "and while the remap page waits for a key")
	controls.capturing = false

	# saved and loaded
	controls.save_binds()
	controls.reset_binds()
	ok(controls.menu_key_of("menu_confirm") == -1, "reset puts every extra key back")
	controls.save_binds()
	controls.rebind_menu("menu_back", KEY_B)
	controls.save_binds()
	controls.reset_binds()
	controls.load_binds()
	ok(controls.menu_key_of("menu_back") == KEY_B, "the extra keys come back from the file")
	controls.reset_binds()
	controls.save_binds()
	print("remap_menu: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
