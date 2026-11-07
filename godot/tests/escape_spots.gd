extends SceneTree
# E6: which spots in the escape room hold the clues is drawn each run (the one left over is the red herring on a three digit code); the
# clues still work out to their digits, the toolbox keeps the fixed layout, and the draw is seeded.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	diff.set_tier("normal")
	var herrings := {}
	var all_ok := true
	for s in 24:
		diff.seed_run(500 + s)
		o.opts = {}
		o._escape_room_setup()
		var spots: Array = o.g.spots
		var distinct: bool = spots.size() == 3 and spots[0] != spots[1] and spots[1] != spots[2] and spots[0] != spots[2]
		for i in 3:
			all_ok = all_ok and o.clue_answer(o.g.clues[i]) == int(o.g.code[i])
		all_ok = all_ok and distinct
		for z in 4:
			if not spots.has(z):
				herrings[z] = true
	_check(all_ok, "three distinct spots and every clue works out to its digit, 24 seeds")
	_check(herrings.size() >= 3, "the red herring is on different spots from run to run (%d of 4 seen)" % herrings.size())
	diff.seed_run(77)
	o.opts = {}
	o._escape_room_setup()
	var first: Array = o.g.spots.duplicate()
	diff.seed_run(77)
	o._escape_room_setup()
	_check(o.g.spots == first, "the same seed lays the room out the same way")
	diff.seed_run(77)
	o.opts = {"fixed_spots": true}
	o._escape_room_setup()
	_check(o.g.spots == [0, 1, 2], "a fixed layout (the toolbox) keeps board, clock, painting")
	diff.set_tier("hard")
	diff.seed_run(81)
	o.opts = {}
	o._escape_room_setup()
	var hard: Array = o.g.spots.duplicate()
	hard.sort()
	_check(hard == [0, 1, 2, 3] and o.g.clues.size() == 4, "hard uses all four spots in a drawn order")
	diff.set_tier("normal")
	o.opts = {}
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
