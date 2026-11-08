extends SceneTree
# Co-op phase 6: bowling with two players. Each frame player 1 rolls, then player 2, then the crew; the scorecard's YOU is the
# pair's average; only the roller's press counts. Alone, nothing changes.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_bowling.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_coopbowl_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopbowl_%d_settings.cfg" % pid
	await process_frame
	var players := root.get_node("Players")
	var outings := root.get_node("Outings")
	# alone
	outings.game = "bowling"
	outings._bowl_setup()
	ok(int(outings.g.players) == 1 and int(outings.g.turn) == 0, "alone: one bowler")
	outings._bowl_add(7)
	ok(outings.g.totals.You == 7, "alone: pins add straight to YOU")
	# two players
	players.enable_coop(true)
	players.join(1, 1)
	outings._bowl_setup()
	ok(int(outings.g.players) == 2, "two players: the frame is shared")
	outings._bowl_add(8)  # player 1
	ok(outings.g.totals.You == 4 and outings.g.by == [8, 0], "player 1's 8 pins: the pair's average is 4")
	outings.g.turn = 1
	outings._bowl_add(6)
	ok(outings.g.by == [8, 6] and outings.g.totals.You == 7, "player 2's 6 pins: the average is 7")
	# the frame hands over to player 2 after player 1's second roll, and to the crew after player 2's
	outings.g.turn = 0
	outings.g.roll = 2
	outings.g.pins = 0
	outings._bowl_next()
	ok(int(outings.g.turn) == 1 and int(outings.g.roll) == 1 and int(outings.g.pins) == 10, "after player 1's frame, player 2 gets fresh pins")
	outings.g.roll = 2
	outings._bowl_next()
	ok(int(outings.g.turn) == 0 and int(outings.g.frame) == 2, "after player 2's frame the crew bowls and the next frame is player 1's again")
	# only the roller's press counts
	outings.g.stage = "aim"
	outings._press_slot = 1
	outings._bowl_press(KEY_E)
	ok(outings.g.stage == "aim", "player 2 pressing on player 1's roll does nothing")
	outings._press_slot = 0
	outings._bowl_press(KEY_E)
	ok(outings.g.stage == "power", "player 1's press stops the aim")
	players.enable_coop(false)
	print("coop_bowling: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
