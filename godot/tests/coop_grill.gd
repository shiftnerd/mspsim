extends SceneTree
# Co-op phase 6: the cookout with two players. The grill is split: player 1 works slots 0-1, player 2 slots 2-3, each with
# their own cursor. Alone, the whole grill is yours.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_grill.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var players := root.get_node("Players")
	var outings := root.get_node("Outings")
	var Grill: GDScript = load("res://scripts/grill_game.gd")
	var gg = Grill.new()
	gg.setup({}, ["Alan"], RandomNumberGenerator.new())
	outings.g = {"game": gg}
	outings._press_slot = 0
	outings._grill_press(KEY_RIGHT)
	outings._grill_press(KEY_RIGHT)
	ok(gg.sel == 2, "alone: the cursor walks the whole grill")
	players.enable_coop(true)
	players.join(1, 1)
	gg = Grill.new()
	gg.setup({}, ["Alan"], RandomNumberGenerator.new())
	outings.g = {"game": gg}
	outings._press_slot = 0
	for i in 5:
		outings._grill_press(KEY_RIGHT)
	ok(gg.sel == 1, "player 1 stops at the middle of the grill")
	outings._press_slot = 1
	outings._grill_press(KEY_LEFT)
	outings._grill_press(KEY_LEFT)
	ok(gg.sel == 2, "player 2 cannot walk onto the left half")
	outings._grill_press(KEY_RIGHT)
	ok(gg.sel == 3, "but moves along the right half")
	outings._press_slot = 0
	outings._grill_press(KEY_LEFT)
	ok(gg.sel == 0 and outings.g.sels == [0, 3], "player 1 keeps their own cursor (%s)" % [outings.g.sels])
	var ev := InputEventJoypadButton.new()
	ev.device = 1
	ev.button_index = JOY_BUTTON_B
	ev.pressed = true
	outings.game = "grill"
	outings.phase = "play"
	ok(outings._event_key_p2(ev) == KEY_SHIFT, "player 2's B is the cool side")
	players.enable_coop(false)
	print("coop_grill: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
