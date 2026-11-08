extends SceneTree
# Co-op phase 6: the karaoke duet with two players. Player 1 sings the two left lanes, player 2 the two right ones (no
# friend's skill roll); a note on the other singer's lane is not yours to hit.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_karaoke.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _notes() -> Array:
	return [{"lane": 0, "time": 1.0, "state": ""}, {"lane": 3, "time": 1.0, "state": ""}]


func _base() -> Dictionary:
	return {"t": 1.0, "notes": _notes(), "score": 0, "perfect": 0, "good": 0, "miss": 0, "streak": 0, "flash": "", "flash_t": 0.0, "mood": 50.0, "chorus": false}


func _run() -> void:
	await process_frame
	var players := root.get_node("Players")
	var outings := root.get_node("Outings")
	outings.game = "karaoke"
	outings.g = _base()
	outings._press_slot = 0
	outings._assign_duet_with("")
	ok(not outings.g.get("human_duet", false), "alone: no human duet")
	players.enable_coop(true)
	players.join(1, 1)
	outings.g = _base()
	outings._assign_duet_with("")
	ok(outings.g.get("human_duet", false) and not outings.g.notes[1].get("auto", false), "two players: the right lanes are not a friend's")
	outings._press_slot = 1
	ok(outings.kara_hit(0) == "" and outings.g.notes[0].state == "", "player 2 cannot take player 1's lane")
	ok(outings.kara_hit(3) != "" and outings.g.notes[1].state != "", "player 2 hits their own lane")
	outings._press_slot = 0
	ok(outings.kara_hit(3) == "", "player 1 cannot take player 2's lane")
	ok(outings.kara_hit(0) != "" and outings.g.notes[0].state != "", "player 1 hits their own lane")
	ok(outings._room_hint().begins_with("P1 = LEFT"), "the hint says who sings what")
	players.enable_coop(false)
	print("coop_karaoke: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
