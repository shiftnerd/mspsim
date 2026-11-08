extends SceneTree
# Level 3 polish: the brows follow the hair colour (R15). The default look keeps the intern's brow exactly.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/brows.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var look := root.get_node("Look")
	var lk: Dictionary = look.default_look()
	var brow := Color.html("6b3416")
	ok(look.map_color(brow, lk).is_equal_approx(brow), "the default hair keeps the original brow")
	var dark: Dictionary = lk.duplicate()
	dark.hair = "2a1c14"
	var blonde: Dictionary = lk.duplicate()
	blonde.hair = "e8d090"
	var d: Color = look.map_color(brow, dark)
	var b: Color = look.map_color(brow, blonde)
	ok(d.v < look.map_color(brow, lk).v, "dark hair gives darker brows (%s)" % d.to_html(false))
	ok(b.v > look.map_color(brow, lk).v and b != d, "blonde hair gives lighter brows (%s)" % b.to_html(false))
	ok(look.map_color(Color.html("3a2418"), blonde).is_equal_approx(Color.html("3a2418")), "the pupil is left alone")
	ok(look.map_color(Color.html("6b3416"), dark, {}).a == 1.0, "and the alpha is kept")
	print("brows: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
