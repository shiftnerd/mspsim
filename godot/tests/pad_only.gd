extends SceneTree
# gdlint:disable=max-line-length
# R42 Steam Deck: a walk through the game with a pad and nothing else. Every input in this file is an
# InputEventJoypadButton or InputEventJoypadMotion sent through Input.parse_input_event (no key event, no mouse event,
# no direct call into a screen's handlers): title, NEW, the character select (creator, phone, tier, options, build), a
# tech campaign day (walk, sit, the Computer, a ticket closed with a fix, a card, the phone, the pause menu and a
# setting), quit to the title, CONTINUE. The mini-games are in tests/pad_only_games.gd.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/pad_only.gd [-- --trace]

var failures := 0
var trace := false
var game: Node
var cards: Node
var comp: Node
var phone: Node
var pm: Node
var camp: Node
var world: Node
var msp: Node
var ctl: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


# ---- the pad ----------------------------------------------------------------------------------------------------------
func _button(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)


func _tap(b: JoyButton, after := 3) -> void:
	_button(b, true)
	await _wait(2)
	_button(b, false)
	await _wait(after)


func _axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


# push a stick to one side and let it go: a menu step, or a flick of the right stick
func _flick(axis: JoyAxis, value: float, after := 3) -> void:
	_axis(axis, value)
	await _wait(2)
	_axis(axis, 0.0)
	await _wait(after)


func _a() -> void:
	await _tap(JOY_BUTTON_A)


func _b() -> void:
	await _tap(JOY_BUTTON_B)


func _dpad(dir: String, times := 1) -> void:
	var b: JoyButton = {"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT}[dir]
	for i in times:
		await _tap(b)


func _player() -> Node:
	return current_scene.get_node_or_null("Actors/Player") if current_scene != null else null


func _room() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


# what is on the screen now (for the trace and for failures)
func _state() -> String:
	var out := "room %s" % _room()
	var p := _player()
	if p != null:
		out += " player %s x%d" % [p.state, int(p.global_position.x)]
	if cards.is_open:
		var labels := []
		for o in cards.options:
			labels.append(str(o.label))
		out += " | CARD %s: %s %s" % [cards.speaker, str(cards.text).substr(0, 60), str(labels)]
	if comp.is_open:
		out += " | COMPUTER %s" % comp.app
	if phone.is_open:
		out += " | PHONE %s%s" % [phone.app, " locked" if phone.locked else ""]
	if pm.is_open:
		out += " | PAUSE %s sel %d" % [str(pm._labels()), pm._sel]
	if root.get_node("DayReport").is_open:
		out += " | DAY REPORT"
	if root.get_node("Review").is_open:
		out += " | REVIEW"
	if root.get_node("Toolbox").is_open:
		out += " | TOOLBOX"
	if root.get_node("Outings").is_open:
		out += " | OUTING %s %s" % [root.get_node("Outings").game, root.get_node("Outings").phase]
	return out


func _note(what: String) -> void:
	if trace:
		print("     .. %s: %s" % [what, _state()])


# answer whatever cards are up with A (the first choice), waiting out the card's half second
func _answer_cards(limit := 12) -> int:
	var n := 0
	while cards.is_open and n < limit:
		_note("card")
		await _wait_ms(480)
		await _a()
		await _wait(4)
		n += 1
	return n


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	trace = "--trace" in OS.get_cmdline_user_args()
	game = root.get_node("Game")
	cards = root.get_node("Cards")
	comp = root.get_node("Computer")
	phone = root.get_node("Phone")
	pm = root.get_node("PauseMenu")
	camp = root.get_node("Campaign")
	world = root.get_node("World")
	msp = root.get_node("Msp")
	ctl = root.get_node("Controls")
	var pid := OS.get_process_id()
	camp.save_prefix = "user://test_%d_padonly_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_padonly_settings.cfg" % pid
	ctl.binds_path = "user://test_%d_padonly_controls.cfg" % pid
	phone.save_path = "user://test_%d_padonly_phone.cfg" % pid

	await _title_to_day()
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)


func _title_to_day() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(30)
	var title := current_scene
	_check(title.name == "Title" and not title._menu_open, "the title is up, the menu closed")
	await _a()
	_check(title._menu_open, "A opens the menu")
	_check(str(title._items[title._sel].id) == "play", "the cursor is on NEW (no save yet)")
	await _dpad("down")
	await _flick(JOY_AXIS_LEFT_Y, -1.0)
	_check(str(title._items[title._sel].id) == "play", "D-pad down and the stick pushed up move the cursor there and back")
	await _a()
	_check(title._level == "top" and str(title._items[title._sel].id) == "tech", "NEW lists the campaigns, the tech campaign first")
	await _b()
	_check(title._level == "home", "B goes back to the home menu")
	await _a()
	await _a()
	var cs: Node = title._select
	_check(cs != null and cs.step == "create" and cs.mode == "tech", "A on the tech campaign opens the creator")
	if cs == null:
		return
	# ---- the creator: change a row, turn a page with the shoulder buttons, name by the letter grid, DONE
	var look: Node = root.get_node("Look")
	var before: String = cs._look_sig()
	var guard := 0
	while str(cs._page_rows()[cs.create_row].kind) in ["start", "name"] and guard < 8:
		await _dpad("down")
		guard += 1
	await _dpad("right")
	_check(cs._look_sig() != before, "D-pad right changes the row under the cursor (%s)" % str(cs._page_rows()[cs.create_row].id))
	var page0: int = cs.create_page
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(cs.create_page != page0, "RB turns to the next page of the creator")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(cs.create_page == page0, "LB turns back")
	guard = 0
	while str(cs._page_rows()[cs.create_row].kind) != "name" and guard < 12:
		await _dpad("up")
		guard += 1
	_check(str(cs._page_rows()[cs.create_row].kind) == "name", "up to the NAME row")
	await _a()
	_check(cs.create_modal == "name", "A on the NAME row opens the letter grid (no typing)")
	var name0: String = str(look.look.get("name", ""))
	await _a()
	_check(str(look.look.get("name", "")) != name0, "A on a cell adds its letter (%s -> %s)" % [name0, str(look.look.get("name", ""))])
	await _b()
	_check(cs.create_modal == "" and str(look.look.get("name", "")) == name0, "B closes the grid and keeps the old name")
	guard = 0
	while cs.create_row != cs._page_rows().size() and guard < 12:
		await _dpad("down")
		guard += 1
	guard = 0
	while str(cs.CREATE_ACTIONS[cs.create_col]) != "done" and guard < 4:
		await _dpad("right")
		guard += 1
	_check(cs.create_row == cs._page_rows().size() and str(cs.CREATE_ACTIONS[cs.create_col]) == "done", "down to the bottom row, right to DONE")
	await _a()
	_check(cs.step == "phone", "A on DONE goes on to the phone (%s)" % cs.step)
	var phone0: int = cs.phone_sel
	await _dpad("right")
	_check(cs.phone_sel != phone0, "right picks the other phone")
	await _a()
	_check(cs.step == "tier", "then the difficulty step (%s)" % cs.step)
	var d: Node = root.get_node("Difficulty")
	await _dpad("right")
	_check(d.tier == "hard", "right steps to HARD")
	await _flick(JOY_AXIS_LEFT_X, -1.0)
	_check(d.tier == "normal", "the stick pushed left steps back to NORMAL")
	await _b()
	_check(cs.step == "phone", "B goes back a step")
	await _a()
	await _a()
	_check(cs.step == "options", "A, A: the options page (%s)" % cs.step)
	await _dpad("down")
	_check(str(cs.options_rows()[cs.opt_row].id) == "start", "down to the START row")
	await _a()
	_check(cs.step == "build", "A goes on to the build (%s)" % cs.step)
	await _tap(JOY_BUTTON_Y)
	await _dpad("down")
	await _dpad("right")
	await _dpad("left")
	_check(cs._panel.valid(), "Y steps the preset, the D-pad edits a row; the build is valid (%s)" % str(cs._panel.errors()))
	await _a()
	await _wait(60)
	_check(camp.active and camp.mode == "tech" and _player() != null, "A starts the tech campaign: a room with you in it (%s)" % _state())
	await _day()


# ---- screens made of click regions (the computer, the phone): RB steps the cursor, A presses ---------------------------
func _under(scr: Node) -> String:
	for i in range(scr._hits.size() - 1, -1, -1):
		if scr._hits[i].r.has_point(scr._mouse):
			return str(scr._hits[i].id)
	return ""


func _ids(scr: Node) -> Array:
	var out := []
	for h in scr._hits:
		out.append(str(h.id))
	return out


# RB until the cursor is on the region `want` (an id, or a prefix ending in ":"), then A. False when it is not on screen.
func _press_region(scr: Node, want: String) -> bool:
	await _wait(3)
	for i in scr._hits.size() + 3:
		var id := _under(scr)
		if scr.pad_focus and (id == want or (want.ends_with(":") and id.begins_with(want))):
			await _a()
			await _wait(3)
			return true
		await _tap(JOY_BUTTON_RIGHT_SHOULDER, 2)
	print("     (no region %s among %s)" % [want, str(_ids(scr))])
	return false


# hold the left stick until you stand at x
func _walk_to(x: float, slack := 5.0) -> void:
	var p := _player()
	var n := 0
	while absf(p.global_position.x - x) > slack and n < 900:
		_axis(JOY_AXIS_LEFT_X, 1.0 if x > p.global_position.x else -1.0)
		await process_frame
		n += 1
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _wait(6)


func _day() -> void:
	var p := _player()
	# ---- walk to the desk and sit
	var seat: Node = current_scene.get_node("Interactables/Seat1")
	var x0: float = p.global_position.x
	await _walk_to(seat.global_position.x)
	_check(absf(p.global_position.x - seat.global_position.x) <= 6.0 and absf(p.global_position.x - x0) > 5.0, "the left stick walks you to your desk (x %d -> %d)" % [int(x0), int(p.global_position.x)])
	_note("at the seat")
	await _tap(JOY_BUTTON_X)
	var n := 0
	while p.state != "sitting" and n < 240:
		await process_frame
		n += 1
		if cards.is_open:
			break
	_note("after X")
	_check(p.state == "sitting", "X sits down (%s)" % _state())
	# ---- a card: Dan's morning (it comes about a minute in); the D-pad moves, A answers
	n = 0
	while not cards.is_open and n < 6000:
		await process_frame
		n += 1
	_check(cards.is_open, "a card comes up (%s)" % _state())
	var sel0: int = cards.sel
	await _dpad("down")
	_check(cards.sel == sel0 + 1, "D-pad down moves the card's cursor")
	await _wait_ms(480)
	var said: String = str(cards.options[cards.sel].label)
	await _a()
	await _wait(6)
	_note("after the card")
	_check(not cards.is_open or str(cards.options[0].label) != "WALK ME THROUGH IT", "A answers it (%s)" % said)
	await _answer_cards()
	# ---- the first ticket that is fixed from the desk (a remote fix on a client's machine)
	var tk: Dictionary = {}
	n = 0
	while tk.is_empty() and n < 30000:
		for t in msp.open_tickets():
			if tk.is_empty() and not bool(t.internal) and str(t.endpoint) != "" and msp.FIXES.has(str(t.fix)) and not root.get_node("Onsite").is_onsite(t):
				tk = t
		await process_frame
		n += 1
		if cards.is_open:
			await _answer_cards()
	_check(not tk.is_empty(), "a ticket with a remote fix has come in")
	if tk.is_empty():
		return
	print("     ticket #%d %s, endpoint %s, fix %s" % [tk.id, tk.summary, tk.endpoint, tk.fix])
	_note("before the computer")
	await _tap(JOY_BUTTON_X)
	await _wait(20)
	_check(comp.is_open and comp.app == "desktop", "X at the desk opens the Computer (%s)" % _state())
	# ---- the Computer: every button is reached with RB (the focus cycle) and pressed with A
	_check(await _press_region(comp, "app:psa"), "RB steps to the service board's icon, A opens it")
	_check(comp.app == "psa" and not comp.psa_detail, "the PSA board (%s)" % _state())
	await _dpad("down")
	var rows := 0
	while comp.psa_sel != int(tk.id) and rows < 12:
		await _dpad("down")
		rows += 1
	await _a()
	_check(comp.psa_detail and comp.psa_sel == int(tk.id), "D-pad and A open the ticket (#%d)" % comp.psa_sel)
	_check(await _press_region(comp, "take"), "RB to TAKE, A")
	_check(str(msp.ticket(int(tk.id)).status) == "In Progress", "the ticket is in progress")
	_check(await _press_region(comp, "start"), "RB to START on the taskbar, A")
	_check(comp._menu, "the start menu is open")
	_check(await _press_region(comp, "app:rmm"), "RB to the RMM in the menu, A")
	_check(comp.app == "rmm", "the RMM (%s)" % _state())
	var ep_name := str(tk.endpoint)
	var client := int(msp.endpoint(ep_name).client)
	if not comp.rmm_open.get(client, false):
		_check(await _press_region(comp, "client:%d" % client), "RB to the client's row, A unfolds it")
	var found := await _press_region(comp, "rmm:" + ep_name)
	var scrolls := 0
	while not found and scrolls < 12:  # the tree scrolls with the D-pad when the machine is below the fold
		await _dpad("down")
		scrolls += 1
		found = await _press_region(comp, "rmm:" + ep_name)
	_check(found and comp.rmm_sel == ep_name, "RB to the machine (%s), A selects it" % ep_name)
	_check(await _press_region(comp, "connect"), "RB to CONNECT, A")
	_check(comp.rmm_session, "a remote session is open")
	_check(await _press_region(comp, "fix:" + str(tk.fix)), "RB to the fix (%s), A starts it" % str(tk.fix))
	_check(not comp._job.is_empty(), "the fix is running")
	var n2 := 0
	while not comp._job.is_empty() and n2 < 6000:
		await process_frame
		n2 += 1
	_check(bool(msp.ticket(int(tk.id)).fix_done), "the fix is done (%s)" % comp.rmm_msg)
	await _b()
	_check(not comp.rmm_session and comp.is_open, "B leaves the session, the Computer stays open")
	_check(await _press_region(comp, "start"), "START again")
	_check(await _press_region(comp, "app:psa"), "back to the PSA")
	if not comp.psa_detail:
		await _dpad("up", 12)
		rows = 0
		while comp.psa_sel != int(tk.id) and rows < 12:
			await _dpad("down")
			rows += 1
		await _a()
	_check(comp.psa_detail and comp.psa_sel == int(tk.id), "the ticket is open again")
	_check(await _press_region(comp, "close"), "RB to CLOSE, A")
	_check(str(msp.ticket(int(tk.id)).status) == "Closed", "the ticket is closed with its fix (%s)" % str(msp.ticket(int(tk.id)).status))
	# the right stick moves the cursor freely too
	var m0: Vector2 = comp._mouse
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _wait(20)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _wait(2)
	_check(comp._mouse.x > m0.x + 20.0 or comp._mouse.x >= root.get_visible_rect().size.x - 2.0, "the right stick moves the cursor (%d -> %d)" % [int(m0.x), int(comp._mouse.x)])
	await _b()
	if comp.is_open:
		await _b()
	await _wait(20)
	_check(not comp.is_open and p.state == "sitting", "B closes the Computer, you are still in your chair (%s)" % _state())
	# ---- the phone: BACK opens it, A unlocks, the D-pad picks an app, RB reaches its buttons, BACK puts it away
	await _tap(JOY_BUTTON_BACK)
	await _wait(20)
	_check(phone.is_open, "the BACK button takes out the phone (%s)" % _state())
	if phone.locked:
		await _a()
		var n3 := 0
		while phone.locked and n3 < 120:
			await process_frame
			n3 += 1
	_check(not phone.locked and phone.app == "home", "A unlocks it: the home screen")
	var home0: int = phone.home_sel
	await _dpad("right")
	_check(phone.home_sel == home0 + 1, "D-pad right moves to the next app")
	await _dpad("left")
	await _a()
	_check(phone.app == str(phone.HOME_APPS[home0]), "A opens it (%s)" % phone.app)
	await _b()
	_check(phone.app == "home", "B goes back to the home screen")
	_check(await _press_region(phone, "app:tickets"), "RB steps to the TICKETS icon, A opens it")
	_check(phone.app == "tickets", "the phone's ticket list")
	await _b()
	_check(await _press_region(phone, "app:camera"), "RB to the camera in the dock, A")
	_check(phone.app == "camera", "the camera")
	var shots: int = phone.photos.size()
	await _a()
	_check(phone.photos.size() == shots + 1, "A takes a photo")
	await _tap(JOY_BUTTON_BACK)
	await _wait(20)
	_check(not phone.is_open and p.state == "sitting", "BACK puts the phone away (%s)" % _state())

	# ---- the pause menu: START, a setting, quit to the title
	await _tap(JOY_BUTTON_START)
	_check(pm.is_open and paused, "START opens the pause menu and pauses")
	var d: Node = root.get_node("Difficulty")
	var day_row: int = pm._labels().find("DAY LENGTH: %s" % d.day_label())
	var guard := 0
	while pm._sel != day_row and guard < 10:
		await _dpad("down")
		guard += 1
	var day0: String = d.day_label()
	await _dpad("right")
	_check(pm._sel == day_row and d.day_label() != day0, "down to DAY LENGTH, right changes it (%s -> %s)" % [day0, d.day_label()])
	await _flick(JOY_AXIS_LEFT_Y, 1.0)
	var pace0: String = msp.pace_label()
	await _a()
	_check(msp.pace_label() != pace0, "the stick steps down to TICKET PACE, A changes it (%s -> %s)" % [pace0, msp.pace_label()])
	guard = 0
	while pm._sel != pm._labels().size() - 1 and guard < 10:
		await _dpad("down")
		guard += 1
	await _a()
	_check(pm._confirm, "A on QUIT TO TITLE asks first")
	await _dpad("down")
	await _a()
	await _wait(40)
	_check(_room() == "title" and not paused and not pm.is_open, "YES: back on the title (%s)" % _state())
	_check(bool(camp.slot_info("tech", 1).has_resume), "the pause wrote the resume point of the day")

	# ---- CONTINUE
	var title := current_scene
	await _a()
	_check(title._menu_open and str(title._items[title._sel].id) == "continue", "A opens the menu, the cursor is on CONTINUE")
	await _a()
	_check(title._level == "cont" and title._items.size() == 1, "the save list has the run (%s)" % str(title._items.map(func(i: Dictionary) -> String: return str(i.label))))
	await _a()
	await _wait(80)
	if is_instance_valid(title) and current_scene == title and title._level == "slot":
		await _a()  # CONTINUE / FROM THE START
		await _wait(80)
	_check(camp.active and camp.mode == "tech" and _player() != null and _room() != "title", "A continues the day (%s)" % _state())
	_check(d.day_label() != day0 and msp.pace_label() != pace0, "with the settings as they were changed")
	_check(str(msp.ticket(int(tk.id)).status) == "Closed", "and the closed ticket still closed (%s)" % str(msp.ticket(int(tk.id))))
	await _answer_cards()
	var x1: float = _player().global_position.x
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _wait(40)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _wait(40)
	_check(_player().state != "sitting" and absf(_player().global_position.x - x1) > 3.0, "and the stick walks you on (%s)" % _state())
