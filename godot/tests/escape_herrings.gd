extends SceneTree
# E3: the safe, the trunk and the globe in the escape room can be read: a couple of seconds off the clock, no clue.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	var scene := FileAccess.get_file_as_string("res://scenes/escape_room.tscn")
	for kind in ["herring_safe", "herring_trunk", "herring_globe"]:
		_check(scene.contains('kind = "%s"' % kind) and o.HERRING_TEXT.has(kind) and str(o.HERRING_TEXT[kind]) != "", "%s is a zone in the room and has its text" % kind)
	o.game = "escape"  # the room version: travelled and open, in play
	o.is_open = true
	o._traveled = true
	o.phase = "play"
	o._escape_setup()
	var t0: float = o.g.time
	var clue_count: int = o.g.clues.size() if o.g.has("clues") else 0
	o.interact("herring_safe")
	_check(is_equal_approx(float(o.g.time), t0 - o.HERRING_COST), "reading the safe costs %d seconds" % int(o.HERRING_COST))
	o.interact("herring_trunk")
	o.interact("herring_globe")
	_check(is_equal_approx(float(o.g.time), t0 - 3.0 * o.HERRING_COST) and (not o.g.has("found") or o.g.found.is_empty()), "three looks, three costs, and no clue found")
	_check(clue_count == (o.g.clues.size() if o.g.has("clues") else 0), "the clues are untouched")
	o.is_open = false
	o._traveled = false
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
