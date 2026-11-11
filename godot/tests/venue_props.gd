extends SceneTree
# gdlint:disable=max-line-length
# Small venue props (scripts/set_dressing.gd, art tools/make_game_art.lua): the restaurant's hanging OPEN / CLOSED sign and menu board,
# and the warehouse's trophy shelf (one trophy per chair-game medal). Each scene is dressed through SetDressing.dress like the stage does.
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/venue_props.gd`

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _dressed(room: String) -> Array:
	var stage: Node = load("res://scenes/%s.tscn" % room).instantiate()
	root.add_child(stage)
	var node: Node = load("res://scripts/set_dressing.gd").dress(stage)
	return [stage, node]


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var career := root.get_node("Career")
	root.get_node("Game").title_mode = false

	# ---- the restaurant
	var r := _dressed("restaurant")
	var stage: Node = r[0]
	var node: Node = r[1]
	_check(node != null and node.signs.size() == 2, "the restaurant has an OPEN and a CLOSED sign")
	var actors := stage.get_node("Actors")
	_check(actors.get_node_or_null("Dressing_venue_menu_board") != null, "and a menu board between the booths")
	var menu := actors.get_node("Dressing_venue_menu_board") as Sprite2D
	_check(menu.position.y < 60.0 and menu.position.x > 83.0 and menu.position.x + menu.texture.get_width() < 107.0, "the menu board hangs in the gap between the two booths")
	o.game = ""
	node.refresh()
	_check(not node.signs[0].visible and node.signs[1].visible, "no dinner: CLOSED")
	o.game = "dinner"
	node.refresh()
	_check(node.signs[0].visible and not node.signs[1].visible, "a dinner is on: OPEN")
	o.game = ""
	_check(node.signs[0].position == node.signs[1].position and node.signs[0].texture.get_size() == node.signs[1].texture.get_size(), "the two signs hang in the same place at the same size")
	stage.queue_free()

	# ---- the warehouse
	career.reset_all()
	var w := _dressed("warehouse")
	stage = w[0]
	node = w[1]
	_check(node != null and node.trophies.size() == 4 and stage.get_node("Actors").get_node_or_null("Dressing_venue_trophy_shelf") != null, "the warehouse has a trophy shelf and four trophy slots")
	var shown := 0
	for row in node.trophies:
		shown += 1 if row[1].visible else 0
	_check(shown == 0, "no medal, no trophy on the shelf")
	var ids := []
	for row in node.trophies:
		ids.append(str(row[0]))
	_check(ids == ["clean_lap", "speed_demon", "track_rat", "bumper_king"] and ids.all(func(id): return career.medal(id).has("title")), "the four slots are the chair-game medals: %s" % str(ids))
	for i in ids.size():
		career.earned[ids[i]] = true
		node.refresh()
		shown = 0
		for row in node.trophies:
			shown += 1 if row[1].visible else 0
		_check(shown == i + 1 and node.trophies[i][1].visible, "%s earned: %d trophy(s) on the shelf" % [ids[i], shown])
	# the trophies sit on the plank, inside it, left to right, above the chair rack
	var shelf := stage.get_node("Actors/Dressing_venue_trophy_shelf") as Sprite2D
	var tidy := true
	for i in 4:
		var t: Sprite2D = node.trophies[i][1]
		tidy = tidy and t.position.x >= shelf.position.x and t.position.x + 7.0 <= shelf.position.x + float(shelf.texture.get_width()) and absf(t.position.y + 10.0 - shelf.position.y) < 0.1
	_check(tidy, "every trophy stands on the plank")
	var rack := stage.get_node("Actors/chair_rack_1") as Sprite2D
	_check(shelf.position.y + float(shelf.texture.get_height()) <= rack.position.y + rack.offset.y + 3.0, "the shelf is on the wall above the chair rack")
	stage.queue_free()
	career.reset_all()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
