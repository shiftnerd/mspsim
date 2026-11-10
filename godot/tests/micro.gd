extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# Micro-sessions (roadmap R16, scripts/micro.gd): the QUICK PLAY rows of the title menu. ONE TICKET SHIFT puts five
# tickets in a Free Play queue, the goal chip counts them and a toast ends it; ONE OUTING hands a game to the Free
# Play toolbox (the games take turns). Both start Free Play (no campaign, nothing saved). Headless.


var Micro: Script  # loaded in _init: a -s script compiles before the autoloads exist
var Goals: Script  # loaded in _init: a -s script compiles before the autoloads exist
var failures := 0
var title: Node
var c: Node
var msp: Node
var career: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	title._unhandled_input(ev)


func _ids() -> Array:
	return title._items.map(func(i: Dictionary) -> String: return i.id)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _fresh_title() -> void:
	root.get_node("Game").title_mode = true
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(4)
	title = current_scene
	title._open_menu()


func _init() -> void:
	await process_frame
	Micro = load("res://scripts/micro.gd")
	Goals = load("res://scripts/goals.gd")
	c = root.get_node("Campaign")
	msp = root.get_node("Msp")
	career = root.get_node("Career")
	var hints := root.get_node("Hints")
	var toolbox := root.get_node("Toolbox")
	var outings := root.get_node("Outings")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	career.toasts = false
	career.reset_all()

	# ---- the title rows
	await _fresh_title()
	var home := _ids()
	_check(home.has("quick") and home.find("quick") == home.find("free") + 1, "the home menu has QUICK PLAY under FREE PLAY: %s" % str(home))
	title._choose(home.find("quick"))
	_check(title._level == "quick" and _ids() == ["micro_outing", "micro_tickets"] and title._heading == "QUICK PLAY", "QUICK PLAY lists one outing and one ticket shift")
	_key(KEY_ESCAPE)
	_check(title._level == "home", "Esc goes back to the home menu")
	title._choose(_ids().find("quick"))
	_key(KEY_DOWN)
	_check(title._sel == 1, "Down moves to the ticket shift")

	# ---- one ticket shift, started from the title
	_key(KEY_ENTER)
	await _wait(90)
	_check(not c.active and c.mode == c.FREE and not game.title_mode, "it starts Free Play, without the character select")
	_check(current_scene != null and current_scene.scene_file_path.get_file().get_basename() != "title", "a room is loaded")
	_check(Micro.active() and Micro.kind == "tickets" and msp.open_tickets().size() == Micro.TARGET, "five tickets are waiting (%d)" % msp.open_tickets().size())
	_check(Goals.shown() and Goals.goal() == "ONE SHIFT: 0 OF 5 TICKETS CLOSED" and Goals.next_up().is_empty(), "the goal chip counts them: %s" % Goals.goal())
	var list: Array = msp.open_tickets().duplicate()
	for i in 3:
		var t: Dictionary = list[i]
		msp.rmm_action(t.endpoint, str(t.fix))
		t.fix_done = true
		msp.close_ticket(t.id)
	await _wait(3)
	_check(Micro.closed() == 3 and Goals.goal() == "ONE SHIFT: 3 OF 5 TICKETS CLOSED" and Micro.active(), "three closed: %s" % Goals.goal())
	hints.toast_text = ""
	for i in range(3, 5):
		var t2: Dictionary = list[i]
		t2.fix_done = true
		msp.close_ticket(t2.id)
	await _wait(3)
	_check(not Micro.active() and str(hints.toast_text).begins_with("SHIFT DONE: 5 TICKETS IN "), "five closed: the shift ends with a toast (%s)" % str(hints.toast_text).substr(0, 34))
	_check(career.value("micro_shifts") == 1 and career.value("micro_best") >= 1, "the career counts the shift and keeps the best time")
	_check(not Goals.shown() and not c.has_save("tech") and c.all_slots().is_empty(), "the chip is gone and nothing was saved")

	# ---- one outing: the toolbox gets a game, they take turns
	_check(Micro.next_outing() == "bowling", "the first quick outing is bowling")
	await _fresh_title()
	_check(not Micro.active(), "back on the title no session is running")
	title._choose(_ids().find("quick"))
	_key(KEY_ENTER)
	_check(Micro.kind == "outing" and Micro.game == "bowling" and toolbox.game_id() == "bowling", "ONE OUTING hands bowling to the Free Play toolbox")
	_check(career.value("micro_outings") == 1 and Micro.next_outing() == "karaoke", "the next one will be karaoke")
	_check(Goals.goal() == "ONE OUTING: BOWLING" or game.title_mode, "the goal chip names it")
	var opened := false
	for i in 240:
		await process_frame
		if outings.is_open or outings.busy():
			opened = true
			break
	_check(opened and str(toolbox.last_launch.get("game", "")) == "bowling", "the toolbox launches the game once the room is up")
	_check(not c.active, "still Free Play")
	Micro.clear()
	var order := []
	for i in Micro.OUTINGS.size():
		order.append(Micro.OUTINGS[(career.value("micro_outings") + i) % Micro.OUTINGS.size()])
	_check(order.size() == 6 and order.has("darts") and order.has("escape"), "six games take turns: %s" % str(order))
	for g in Micro.OUTINGS:
		_check(toolbox.GAMES.has(g) and outings.GAMES.has(g), "%s is a toolbox game" % str(g))

	# ---- a campaign clears it
	Micro.kind = "tickets"
	game.title_mode = false
	root.get_node("Difficulty").set_tier("normal")
	c.new_game("tech")
	_check(not Micro.active(), "a campaign is never a micro-session")
	Micro.tick()
	_check(Micro.kind == "", "and the next tick clears it")
	career.reset_all()

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
