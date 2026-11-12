extends SceneTree
# gdlint:disable=max-line-length
# Regressions of bugs the UI fuzzer (tests/fuzz_ui.gd) found: each one is the failing input reduced to the call that broke,
# checked through the fuzzer's Logger (an engine error is a failure). The log is docs/dev/notes-soak-ui.md.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/fuzz_regress.gd

const Lib := preload("res://tests/fuzz_lib.gd")

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print(("ok   " if cond else "FAIL ") + what)


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _errors(lib: Object) -> Array:
	return lib.logger.take()


func _run() -> void:
	var lib := Lib.new(self)
	await _wait(2)
	# 1. a stale swatch click: the hit list belongs to the last drawn page, the page turned before the next draw, and the row index
	#    from the old page ran past the new page's rows (charselect.gd _click "sw": Out of bounds get index '3'; floor:free, seed 1)
	var cs: Node = load("res://scripts/charselect.gd").new()
	root.add_child(cs)
	await _wait(3)
	cs.setup("free")
	await _wait(3)
	cs.set_page(2)
	cs._rects = [[Rect2(0, 0, 10, 10), "sw", 999]]
	_errors(lib)
	cs._click(Vector2(1, 1))
	await _wait(2)
	var errs := _errors(lib)
	ok(errs.is_empty(), "a swatch click for a row the page does not have is ignored (%s)" % str(errs))
	cs.queue_free()
	await _wait(2)
	# 2. a second GO in the same frame: title._on_select_done ran with its select already gone (title.gd:686, title:sub:tech, seed 2)
	root.get_node("Game").title_mode = true
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(10)
	var t := current_scene
	ok(t != null and t.get("_select") == null, "the title is up with no character select")
	_errors(lib)
	t._on_select_done({"summary": ""}, "tech_new")
	await _wait(2)
	errs = _errors(lib)
	ok(errs.is_empty() and t.get("_started") != true, "GO with no select open does nothing (%s)" % str(errs))
	# 3. a mouse over a greyed-out card row selected it, and Enter then did nothing (the fuzzer's recovery could not answer the card)
	var cards := root.get_node("Cards")
	cards.ask("TEST", "TEXT", [{"label": "FIRST", "id": "a"}, {"label": "SECOND", "id": "b", "enabled": false}], func(_id: String) -> void: pass)
	cards.sel = 0
	cards._hits = [{"r": Rect2(0, 0, 50, 50), "i": 1}, {"r": Rect2(60, 0, 50, 50), "i": 7}]
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(10, 10)
	cards._input(motion)
	ok(cards.sel == 0, "hovering a greyed-out option leaves the selection on an enabled one")
	motion.position = Vector2(70, 10)
	cards._input(motion)  # a stale hit rect with an index past this card's options
	ok(cards.sel == 0 and _errors(lib).is_empty(), "a stale hit rect with a bad index is ignored")
	cards.pick(0)
	# 4. a pause from a focus loss over an open phone, then QUIT TO TITLE: the phone followed you to the title screen and ate its Enter
	#    (floor:boardroom:clients, seed 2: ENTER did nothing on the title prompt)
	root.get_node("Game").title_mode = false
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(20)
	var ph := root.get_node("Phone")
	ph.os = "android"
	ph.open()
	ok(ph.is_open and root.get_node("Game").ui_open, "the phone is open")
	root.get_node("Game").go_title()
	await _wait(30)
	ok(not ph.is_open and not root.get_node("Game").ui_open, "going to the title closes the phone and clears ui_open")
	lib.finish()
	print("failures=%d" % fails)
	quit(1 if fails > 0 else 0)
