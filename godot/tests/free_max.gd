extends SceneTree
# X7: Free Play has no build screen, but Tab on its character select switches the MAX build preset (every stat at 5, for filming).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var build := root.get_node("Build")
	var cs: Node2D = load("res://scripts/charselect.gd").new()
	cs.setup("free")
	_check(not cs._free_max and not cs.summary().contains("MAX BUILD"), "Free Play starts without the preset")
	cs.change_start(1)
	_check(cs._free_max and cs.summary().contains("MAX BUILD"), "Tab switches it on and the summary says so (%s)" % cs.summary())
	var b: Dictionary = cs._pending_build()
	_check(str(b.get("preset", "")) == "max" and not build.is_flat(b), "the run starts with the MAX build")
	build.pending = b
	var taken: Dictionary = build.take_pending("free")
	_check(str(taken.get("preset", "")) == "max", "Free Play keeps the MAX preset when the run starts")
	cs.change_start(-1)
	_check(not cs._free_max and not cs.summary().contains("MAX BUILD"), "Tab again switches it off")
	cs.setup("free")
	cs.change_start(1)
	cs.setup("free")
	_check(not cs._free_max, "a new screen starts with it off")
	cs.setup("tech")
	cs.change_start(1)
	_check(not cs._free_max, "the tech campaign's Tab still cycles the starting condition, not the preset")
	cs.free()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
