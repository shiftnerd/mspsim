extends SceneTree
# gdlint:disable=max-line-length
# The small mini-game art (tools/make_game_art.lua): floor paint for the chair games (chair_track.gd), the asked-for star
# on a Dispatch chip (dispatch.gd), plates on the dinner table and Jen's headset (set_dressing.gd). Checks that the
# sprites are there at the sizes the code places them with, that the scripts find them, that the plates show only
# while a dinner has its food, and that the headset stands on Jen's desk.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var outings := root.get_node("Outings")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- the files
	var sizes := {
		"props/chair_finish": Vector2i(10, 24), "props/chair_ring_end": Vector2i(12, 28), "props/chair_ring_line": Vector2i(12, 2),
		"props/chair_ring_spot": Vector2i(30, 12), "ui/star_asked": Vector2i(5, 5), "props/dinner_plate_a": Vector2i(11, 6),
		"props/dinner_plate_b": Vector2i(11, 6), "props/dinner_plate_c": Vector2i(11, 6), "props/desk_headset": Vector2i(9, 12),
		"props/dinner_plate_d": Vector2i(11, 6), "props/dinner_setting": Vector2i(16, 7), "props/dinner_tent": Vector2i(7, 6), "props/dinner_briefcase": Vector2i(12, 10),
	}
	var files_ok := true
	for id in sizes:
		var path := "res://assets/%s.png" % id
		var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if t == null or Vector2i(t.get_size()) != sizes[id]:
			files_ok = false
			print("     missing or wrong size: %s" % id)
	_check(files_ok, "the thirteen sprites load at their sizes")

	# ---- the chair track finds its paint, and a missing one is null (the rectangles are the fallback)
	var track: Node2D = load("res://scripts/chair_track.gd").new()
	_check(track.floor_paint("finish") != null and track.floor_paint("ring_end") != null and track.floor_paint("ring_line") != null and track.floor_paint("ring_spot") != null, "the chair track loads the finish line and the ring")
	_check(track.floor_paint("nothing") == null, "a missing paint sprite is null")
	track.free()

	# ---- Dispatch: a ticket somebody was asked for gets the star until it is closed
	var dispatch: Object = load("res://scripts/dispatch.gd").new()
	_check(dispatch.star() != null, "Dispatch loads the star")
	_check(dispatch.asked_for({"asked_tech": "Dan", "status": "Open"}), "an open ticket with asked_tech is marked")
	_check(not dispatch.asked_for({"status": "Open"}) and not dispatch.asked_for({"asked_tech": "", "status": "Open"}), "a plain ticket is not")
	_check(not dispatch.asked_for({"asked_tech": "Dan", "status": "Closed"}), "a closed one is not")
	if dispatch is Node:
		dispatch.free()

	# ---- the restaurant: plates on the two tables, shown only while a dinner has its food
	game.title_mode = false
	game.ui_open = false
	c.new_game("free")
	root.get_node("Msp").enabled = false
	game.go("restaurant", "start")
	await _wait(40)
	var stage := current_scene
	var dress: Node = stage.get_node_or_null("SetDressing") if stage != null else null
	_check(dress != null and dress.plates.size() == 4, "the restaurant has the dressing node and four plates")
	if dress != null:
		var on_table := true
		for s in dress.plates:
			on_table = on_table and str(s.get_parent().name).begins_with("wood_table") and s.position.y + 6.0 == -37.0
		_check(on_table, "each plate stands on a table top")
		var was: String = outings.game
		var was_g: Dictionary = outings.g
		outings.game = ""
		dress.refresh()
		_check(not dress.plates[0].visible, "no dinner: no plates")
		outings.game = "dinner"
		outings.g = {"order": {"done": false}}
		dress.refresh()
		_check(not dress.plates[0].visible, "the table is still ordering: no plates")
		outings.g = {"order": {"done": true}}
		dress.refresh()
		_check(dress.plates[0].visible and dress.plates[3].visible, "the food has come: plates on both tables")
		outings.g = {}
		dress.refresh()
		_check(dress.plates[0].visible, "the classic dinner (no ordering round) has plates from the start")
		# a guest at the table: the setting, the name tent and the briefcase show, the second table's plates make room
		var x0: float = dress.plates[2].position.x
		_check(dress.guest.size() == 3 and not dress.guest[0].visible and not dress.guest[2].visible, "a dinner without a guest has no setting, tent or briefcase")
		outings.game = "dinner"
		outings.g = {"order": {"done": true}, "guest": {"client": 0, "name": "Pat", "firm": "Test Co"}}
		dress.refresh()
		_check(dress.guest[0].visible and dress.guest[1].visible and dress.guest[2].visible, "a guest at the table: setting, tent and briefcase show")
		_check(dress.plates[2].position.x < x0 and dress.plates[3].position.x + 11.0 < dress.guest[0].position.x + 7.0, "the plates step aside for the setting")
		_check(dress.guest[1].get_parent() == dress.plates[2].get_parent() and dress.guest[1].position.y + 7.0 == -37.0, "the setting stands on the table top")
		outings.g = {"order": {"done": true}}
		dress.refresh()
		_check(not dress.guest[0].visible and dress.plates[2].position.x == x0, "the guest goes home: the plates are back where they were")
		outings.game = was
		outings.g = was_g

	# ---- Jen's desk: the headset, where there is a Jen
	game.go("cubicle_two", "start")
	await _wait(40)
	stage = current_scene
	var desk: Node = stage.get_node_or_null("Actors/desk_cubicle_74_1") if stage != null else null
	var headset: Node = desk.get_node_or_null("Dressing_desk_headset") if desk != null else null
	_check(desk != null and (headset != null) == world.chars.has("Jen"), "the headset is on the front desk exactly when there is a Jen (Jen: %s)" % str(world.chars.has("Jen")))
	if headset != null:
		_check(headset.position == Vector2(3, -37) and headset.position.y + 12.0 == -25.0, "it stands on the desk top")
	_check(stage != null and stage.get_node_or_null("SetDressing") == null, "other rooms have no dressing node")

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
