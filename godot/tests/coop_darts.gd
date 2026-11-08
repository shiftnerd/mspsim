extends SceneTree
# Co-op phase 6: darts with two players. The two humans throw the "You" turns one round each in turn (player 1 on odd
# rounds); only the thrower's press counts. Alone nothing changes.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_darts.gd

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
	var Darts: GDScript = load("res://scripts/darts_game.gd")
	var solo = Darts.new()
	solo.setup({}, ["Alan"], RandomNumberGenerator.new())
	ok(solo.humans == 1 and solo.thrower_slot() == 0, "alone: player 1 throws every round")
	var duo = Darts.new()
	duo.setup({"humans": 2}, ["Alan"], RandomNumberGenerator.new())
	ok(duo.humans == 2 and duo.thrower_slot() == 0, "two players: round 1 is player 1's")
	duo.turn_i = duo.players.size()  # the next round
	ok(duo.thrower_slot() == 1, "round 2 is player 2's")
	duo.turn_i = duo.players.size() * 2
	ok(duo.thrower_slot() == 0, "round 3 is player 1's again")
	var many = Darts.new()
	many.setup({"humans": 7}, [], RandomNumberGenerator.new())
	ok(many.humans == 2, "never more than two humans")
	players.enable_coop(true)
	players.join(1, 1)
	duo.turn_i = duo.players.size()
	duo.phase = "aim"
	outings.g = {"game": duo}
	outings._press_slot = 0
	outings._darts_press(KEY_E)
	ok(duo.phase == "aim", "player 1 pressing on player 2's round does nothing")
	ok(outings._darts_hint().begins_with("P2:"), "the hint says whose throw it is")
	outings._press_slot = 1
	outings._darts_press(KEY_E)
	ok(duo.phase != "aim", "player 2's press throws on their own round")
	players.enable_coop(false)
	print("coop_darts: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
