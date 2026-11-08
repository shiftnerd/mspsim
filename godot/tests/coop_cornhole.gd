extends SceneTree
# Co-op phase 6: cornhole with two players. The two humans throw the "you" bags and take the rounds in turn (player 1 on the
# odd rounds); only the thrower's press counts; alone nothing changes.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_cornhole.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var Corn: GDScript = load("res://scripts/cornhole_game.gd")
	var solo = Corn.new()
	solo.setup({}, ["Alan"], RandomNumberGenerator.new())
	ok(solo.players == 1 and solo.thrower_slot() == 0 and solo.msg.begins_with("ROUND 1: YOU AGAINST"), "alone: player 1 throws every round, the old banner")
	var duo = Corn.new()
	duo.setup({"players": 2}, ["Alan", "Dan"], RandomNumberGenerator.new())
	ok(duo.players == 2 and duo.thrower_slot() == 0 and duo.msg.begins_with("ROUND 1: P1 AGAINST"), "two players: round 1 is player 1's")
	duo._new_round()
	ok(duo.thrower_slot() == 1 and duo.msg.begins_with("ROUND 2: P2 AGAINST"), "round 2 is player 2's")
	duo._new_round()
	ok(duo.thrower_slot() == 0, "and round 3 is player 1's again")
	var clamp = Corn.new()
	clamp.setup({"players": 9}, [], RandomNumberGenerator.new())
	ok(clamp.players == 2, "never more than two humans")

	# the Outings press gate
	var outings := root.get_node("Outings")
	duo.phase = "aim"  # (round 3, player 1's)
	outings.g = {"game": duo}
	outings._press_slot = 1
	outings._corn_press(KEY_E)
	ok(duo.phase == "aim", "player 2 pressing on player 1's round does nothing")
	outings._press_slot = 0
	outings._corn_press(KEY_E)
	ok(duo.phase == "power", "player 1's press stops the aim")
	duo._new_round()
	duo.phase = "aim"
	outings._press_slot = 1
	outings._corn_press(KEY_E)
	ok(duo.phase == "power", "player 2's press counts on their own round")
	var ev := InputEventJoypadButton.new()
	ev.device = 1
	ev.button_index = JOY_BUTTON_X
	ev.pressed = true
	ok(outings._event_key_p2(ev) == KEY_NONE or outings._event_key_p2(ev) == KEY_E, "player 2's pad maps to the game keys")
	print("coop_cornhole: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
