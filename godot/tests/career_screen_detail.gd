extends SceneTree
# R7: the career screen's mastery page and the medal detail panel.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/career_screen_detail.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code as Key
	e.physical_keycode = code as Key
	e.pressed = true
	return e


func _run() -> void:
	root.get_node("Campaign").save_prefix = "user://test_cdetail_%d_" % OS.get_process_id()
	var career := root.get_node("Career")
	career.toasts = false
	career.reset_all()
	var s: Node = load("res://scripts/career_screen.gd").new()
	root.add_child(s)
	await process_frame
	await process_frame
	s.build(Vector2(368, 128))
	var mastery := -1
	var medals := -1
	for i in s.pages.size():
		if s.pages[i].has("mastery"):
			mastery = i
		if s.pages[i].has("medals") and medals < 0:
			medals = i
	ok(mastery >= 0 and medals > mastery, "there is a mastery page, before the medals")
	s.page = medals
	ok(not s.detail and s.sel == 0, "no detail at first")
	s._input(_key(KEY_DOWN))
	ok(s.sel == 1, "down moves the cursor")
	s._input(_key(KEY_UP))
	s._input(_key(KEY_UP))
	ok(s.sel == s._medals_here().size() - 1, "up wraps")
	s.sel = 2
	s._input(_key(KEY_ENTER))
	ok(s.detail, "Enter opens the detail")
	s._input(_key(KEY_DOWN))
	ok(s.sel == 2, "the cursor stays while the detail is open")
	s._input(_key(KEY_ESCAPE))
	ok(not s.detail and s.is_inside_tree(), "Escape closes the detail first, not the screen")
	s.go(1)
	ok(s.sel == 0 and not s.detail, "turning a page resets the cursor")
	s.page = mastery
	s._input(_key(KEY_ENTER))
	ok(not s.detail, "Enter does nothing on the mastery page")
	print("career_screen_detail: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
