extends SceneTree
# Co-op phase 8: pad rumble goes to the slot's own pad and never throws without one (a headless run has no joypads).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/rumble.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var controls := root.get_node("Controls")
	var players := root.get_node("Players")
	ok(controls.rumble_on, "rumble is on by default")
	ok(controls.rumble_device(0) == (0 if Input.get_connected_joypads().has(0) else -1), "slot 0's rumble goes to pad 0 when it is connected")
	players.enable_coop(true)
	players.join(1, 3)
	ok(controls.rumble_device(1) == (3 if Input.get_connected_joypads().has(3) else -1), "slot 1's goes to the pad it joined with")
	controls.rumble(0, 1.0, 0.1)
	controls.rumble(1, 2.0, 0.1)
	ok(true, "rumbling with no pad connected does nothing and does not fail")
	controls.rumble_on = false
	controls.rumble(0, 1.0, 0.1)
	controls.rumble_on = true
	players.enable_coop(false)
	print("rumble: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
