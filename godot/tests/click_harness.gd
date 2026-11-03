extends SceneTree
# Q4: real mouse clicks at logical UI coordinates, through Input.parse_input_event (Game.click_at). Works in a
# hidden, headless or --resolution window because the point goes through the window's content-scale transform and the
# UI reads event.position instead of the OS cursor. Proves it on the title menu, a card option and a Computer app button.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/click_harness.gd [-- --format=wide|h|v]
# (also works with a renderer; run it without --headless to check the real window path.)

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


# Cards and the day report ignore clicks for 0.45 s of REAL time after they open (Time.get_ticks_msec), and
# --fixed-fps frames can run much faster than that, so wait on the wall clock.
func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


func _center(r: Rect2) -> Vector2:
	return r.position + r.size * 0.5


func _run() -> void:
	var game := root.get_node("Game")
	var campaign := root.get_node("Campaign")
	campaign.save_prefix = "user://test_clickharness_%d_" % OS.get_process_id()  # no saves: no Continue entry
	print("format ", game.format, " window ", root.size, " final scale ", root.get_final_transform().get_scale())
	# the transform maps a logical point to window pixels and back
	var p := Vector2(100, 50)
	_check((root.get_final_transform().affine_inverse() * game.ui_to_window(p)).is_equal_approx(p), "ui_to_window is the inverse of the content scale")

	# ---- title menu: a click opens the menu, a click on TECH CAMPAIGN opens the character select
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(30)
	var title := current_scene
	_check(title.name == "Title" and not title._menu_open, "the title is showing, menu closed")
	game.click_at(Vector2(184, 60))
	await _wait(10)
	_check(title._menu_open, "a click on the title opens the menu")
	await _wait(10)
	var first: Dictionary = title._items[0]
	_check(first.has("rect"), "menu items carry their drawn rect")
	var last_i: int = title._items.size() - 1
	game.hover_at(_center(title._items[last_i].rect))
	await _wait(3)
	_check(title._sel == last_i, "hovering the last item selects it (sel %d)" % title._sel)
	game.click_at(_center(first.rect))
	await _wait(20)
	_check(title._select != null, "clicking the first item (%s) opens the character select" % str(first.id))
	if title._select != null:
		title._close_select()
	await _wait(5)

	# ---- a card option
	root.get_node("Game").title_mode = false
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(30)
	var cards := root.get_node("Cards")
	var picked := []
	cards.ask("TEST", "PICK THE SECOND ONE.", [
		{"label": "FIRST", "id": "a"}, {"label": "SECOND", "id": "b"}, {"label": "THIRD", "id": "c"},
	], func(id: String) -> void: picked.append(id))
	await _wait_ms(600)  # cards ignore input for the first 0.45 s
	_check(cards.is_open and cards._hits.size() == 3, "the card is open with three option rects")
	var second: Rect2 = cards._hits[1].r
	game.click_at(_center(second))
	await _wait(10)
	_check(picked == ["b"], "clicking the second option picked it: %s" % str(picked))
	_check(not cards.is_open, "the card closed")

	# ---- a Computer app button
	var comp := root.get_node("Computer")
	comp.open(1)
	await _wait(20)
	comp.app = "desktop"
	comp._canvas.queue_redraw()
	await _wait(5)
	var target := ""
	var rect := Rect2()
	for h in comp._hits:
		if str(h.id).begins_with("app:") and str(h.id) != "app:":
			target = str(h.id)
			rect = h.r
			break
	_check(target != "", "the desktop lists app buttons (first: %s)" % target)
	game.click_at(_center(rect))
	await _wait(10)
	_check(comp.app == target.substr(4), "clicking %s opened the app (now %s)" % [target, str(comp.app)])
	comp.close()
	DirAccess.remove_absolute(campaign.save_prefix + "tech.cfg")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
