extends SceneTree
# Co-op phase 6: dinner with two players. The topics go round the table: player 1 picks the first, player 2 the second, and so on;
# a press from the other player does nothing. Alone, nothing changes.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_dinner.gd

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
	outings.g = {"react": {}, "stage": "", "sel": 0, "options": ["A", "B", "C", "D"], "picked": []}
	outings._press_slot = 1
	outings._dinner_press(KEY_DOWN)
	ok(outings.g.sel == 1, "alone: any press moves the choice")
	players.enable_coop(true)
	players.join(1, 1)
	outings.g.sel = 0
	outings._press_slot = 1
	outings._dinner_press(KEY_DOWN)
	ok(outings.g.sel == 0, "two players: player 2 cannot pick the first topic")
	outings._press_slot = 0
	outings._dinner_press(KEY_DOWN)
	ok(outings.g.sel == 1, "player 1 can")
	outings.g.picked = ["A"]
	outings.g.sel = 0
	outings._press_slot = 0
	outings._dinner_press(KEY_DOWN)
	ok(outings.g.sel == 0, "the second topic is not player 1's")
	outings._press_slot = 1
	outings._dinner_press(KEY_DOWN)
	ok(outings.g.sel == 1, "it is player 2's")
	players.enable_coop(false)
	print("coop_dinner: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
