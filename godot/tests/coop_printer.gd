extends SceneTree
# Co-op phase 6: the printer game with two players. The steps of the job go round the two players, one phase each; the intro and
# the result belong to either. Alone, nothing changes.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_printer.gd

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
	var pg := root.get_node("PrinterGame")
	pg.model = "laser"
	pg.phase = "jam"
	ok(pg.turn_slot() == -1, "alone: nobody's turn is gated")
	players.enable_coop(true)
	players.join(1, 1)
	var seen := []
	for ph in pg._phases():
		pg.phase = ph
		seen.append(pg.turn_slot())
	ok(seen[0] == 0 and seen[1] == 1 and seen[2] == 0, "the phases alternate, player 1 first (%s)" % [seen])
	pg.phase = "intro"
	ok(pg.turn_slot() == -1, "the intro belongs to either player")
	pg.phase = "result"
	ok(pg.turn_slot() == -1, "and so does the result")
	players.enable_coop(false)
	print("coop_printer: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
