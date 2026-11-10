extends SceneTree
# gdlint:disable=max-line-length
# R14 / R34, pad-only reach: the functions that used to be raw keyboard keys work from a pad (or the touch overlay, which
# sends pad events), and the hint lines show the binding that works now.
#   hints            Controls.label / hint / world_hint: default text unchanged, a remapped key, pad buttons
#   seed picker      six digit wheels by D-pad and A (R14 6)
#   printer          Up / Down + A answer the test page; LB / RB shake; Y prays
#   computer         Y steps through an app's letter hotkeys, X presses the chosen one
#   Free Play        the pause menu's FREE PLAY MENU card: mutator, toolbox, outing, next person; R3 = next person
#   roll             the left trigger (the roll action) rolls a seated chair with the stick
#   touch overlay    stick, A, X / B, MENU, NEXT and ROLL feed the same actions; hidden unless a touch screen
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/controls_pad.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _pad(button: JoyButton, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _touch(index: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var c := root.get_node("Controls")
	var game := root.get_node("Game")
	var camp := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var tb := root.get_node("Toolbox")
	var d := root.get_node("Difficulty")
	var pm := root.get_node("PauseMenu")
	var muts := root.get_node("Mutators")
	var pid := OS.get_process_id()
	camp.save_prefix = "user://test_%d_pad_" % pid
	d.settings_path = "user://test_%d_pad_settings.cfg" % pid
	c.binds_path = "user://test_%d_pad_controls.cfg" % pid

	# ---- hints -------------------------------------------------------------------------------------------------
	c.pad_active = false
	var line := "UP DOWN ROW  ENTER GO  ESC BACK"
	_check(c.hint(line) == line and c.world_hint("E: SIT") == "E: SIT", "default keys on a keyboard: a hint is unchanged")
	_check(c.label("menu_confirm") == "ENTER" and c.label("menu_back") == "ESC" and c.label("game_a") == "Z", "label: the menu roles by their plain key")
	_check(c.label("interact") == c.key_name(KEY_E) and c.label("pray") == c.key_name(KEY_P), "label: an action by its key")
	_check(c.rebind_menu("menu_confirm", KEY_I), "an extra key on MENU CONFIRM")
	_check(c.hint(line) == "UP DOWN ROW  %s GO  ESC BACK" % c.key_name(KEY_I), "the hint shows the remapped menu key (%s)" % c.hint(line))
	_check(c.rebind("interact", KEY_G), "interact goes to G")
	_check(c.world_hint("E: SIT  P: PHONE") == "%s: SIT  P: PHONE" % c.key_name(KEY_G), "a walking prompt shows the remapped key (%s)" % c.world_hint("E: SIT  P: PHONE"))
	c.reset_binds()
	_check(c.hint(line) == line, "reset: the default text again")
	c.pad_active = true
	_check(c.hint(line) == "UP DOWN ROW  (A) GO  (B) BACK", "a pad: Enter and Esc become (A) and (B) (%s)" % c.hint(line))
	_check(c.hint("LEAVE (ESC)") == "LEAVE (B)" and c.hint("ARROWS  TAB") == "STICK  (RB)", "a pad: no doubled brackets, the stick, RB")
	_check(c.world_hint("E: SIT  P: PHONE") == "(X): SIT  (BACK): PHONE", "a pad: walking prompts show X and BACK (%s)" % c.world_hint("E: SIT  P: PHONE"))
	_check(c.hint("P = PRAY  A / D = SHAKE", {"P": "pray", "A": "shake_left", "D": "shake_right"}) == "(Y) = PRAY  (LB) / (RB) = SHAKE", "a pad: a screen's own letters by its map")
	_check(c.label("roll") == "(LT)" and c.label("aim") == "(RT)" and c.label("hot_next") == "(Y)", "a pad: triggers and buttons by name")
	c.pad_active = false
	Input.parse_input_event(_pad(JOY_BUTTON_DPAD_DOWN))
	await _wait(2)
	Input.parse_input_event(_pad(JOY_BUTTON_DPAD_DOWN, false))
	await _wait(2)
	_check(c.pad_active, "a pad press switches the hints to the pad")
	Input.parse_input_event(_key(KEY_F8))
	await _wait(2)
	_check(not c.pad_active, "a key press switches them back")

	# ---- the seed picker by pad -----------------------------------------------------------------------------------
	d.seed_run(0x4F2A9C)
	tb.open_seed()
	_check(tb.seed_buf == "4F2A9C" and tb.seed_focus == 0 and tb.seed_col == 0, "the wheels start on the seed in force")
	tb._key(_pad(JOY_BUTTON_DPAD_UP))
	_check(tb.seed_buf == "5F2A9C", "D-pad up turns the first wheel (%s)" % tb.seed_buf)
	tb._key(_pad(JOY_BUTTON_DPAD_RIGHT))
	tb._key(_pad(JOY_BUTTON_DPAD_DOWN))
	tb._key(_pad(JOY_BUTTON_DPAD_DOWN))
	_check(tb.seed_buf == "5D2A9C" and tb.seed_col == 1, "right moves on, down turns back (%s)" % tb.seed_buf)
	for i in 4:
		tb._key(_pad(JOY_BUTTON_DPAD_RIGHT))
	tb._key(_pad(JOY_BUTTON_DPAD_UP))
	tb._key(_pad(JOY_BUTTON_DPAD_UP))
	tb._key(_pad(JOY_BUTTON_DPAD_UP))
	tb._key(_pad(JOY_BUTTON_DPAD_UP))
	_check(tb.seed_buf == "5D2A90", "the last wheel wraps past F to 0 (%s)" % tb.seed_buf)
	tb._key(_pad(JOY_BUTTON_A))
	_check(not tb.is_open and d.run_seed == 0x5D2A90, "A applies the wheels (%s)" % d.seed_text())
	tb.open_seed()
	for i in 6:
		tb._key(_pad(JOY_BUTTON_DPAD_RIGHT))
	_check(tb.seed_focus == 1, "right past the last wheel reaches RANDOM")
	tb._key(_pad(JOY_BUTTON_DPAD_RIGHT))
	_check(tb.seed_focus == 2, "then TODAY")
	tb._key(_pad(JOY_BUTTON_B))
	_check(not tb.is_open and d.run_seed == 0x5D2A90, "B closes and changes nothing")
	tb.open_seed()
	await _wait(3)
	var wheel_dn := []
	for r in tb._rects:
		if str(r[1]) == "wheel_dn" and int(r[2]) == 2:
			wheel_dn = r
	_check(not wheel_dn.is_empty(), "the wheels are drawn with a click target on each half")
	if not wheel_dn.is_empty():
		tb._click((wheel_dn[0] as Rect2).get_center())
		_check(tb.seed_buf == "5D1A90" and tb.seed_col == 2, "a click on the lower half turns that wheel down (%s)" % tb.seed_buf)
	tb._key(_key(KEY_C))
	tb._key(_key(KEY_0))
	_check(tb.seed_buf == "5DC090", "a keyboard can still type hex digits onto the wheels (%s)" % tb.seed_buf)
	tb._key(_key(KEY_ESCAPE))

	# ---- the printer test page by pad -----------------------------------------------------------------------------
	var pg := root.get_node("PrinterGame")
	pg.start(func(_s: int) -> void: pass)
	pg.press("confirm")  # the intro
	var steps := 0
	while pg.phase == "jam" and steps < 40:
		pg.marker = pg.zone
		pg.press("confirm")
		steps += 1
	if pg.phase == "tray":
		pg.tray_sel = 0
		pg.press("confirm")
	while pg.phase == "toner" and steps < 80:
		pg.sel = int(pg.order[pg.step])
		pg.press("confirm")
		steps += 1
	_check(pg.phase == "shake", "the printer run reaches the shake step (%s)" % pg.phase)
	pg._input(_pad(JOY_BUTTON_LEFT_SHOULDER))
	pg._input(_pad(JOY_BUTTON_RIGHT_SHOULDER))
	_check(pg.shakes == 2, "LB and RB shake the cartridge (%d)" % pg.shakes)
	for i in 8:
		pg.press("a" if i % 2 == 0 else "d")
	_check(pg.phase == "test" and pg.ans_sel == -1, "then the test page (%s)" % pg.phase)
	pg.press("confirm")
	_check(not pg._answered, "the test page: confirm alone answers nothing (keyboard play is unchanged)")
	pg.press("down")
	pg.press("down")
	_check(pg.ans_sel == 1, "Down marks an answer")
	pg.press("confirm")
	_check(pg._answered and pg.ans_sel == -1, "confirm gives the marked answer")
	pg.press("escape")
	pg.press("confirm")
	pg.is_open = false
	pg._canvas.visible = false
	game.ui_open = false

	# ---- Free Play on the main floor ---------------------------------------------------------------------------------
	game.title_mode = false
	camp.new_game(camp.FREE)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(40)
	var p := current_scene.get_node("Actors/Player")
	var world := root.get_node("World")
	root.get_node("Outings").enabled = true
	for npc in ["Maya", "Garrison", "John"]:  # keep Seat2 free
		if world.chars.has(npc):
			world.chars[npc].scene = "office_two"
			world.force_activity(npc, "work")
	# the computer's hotkey strip
	var comp := root.get_node("Computer")
	comp.is_open = true
	comp.app = "dispatch"
	comp.dispatch.view = "board"
	comp.hot_i = 0
	var keys: Array = comp.hot_keys()
	_check(keys.size() >= 5 and comp.hot_text().find("NEXT") >= 0, "the dispatch board lists its letter hotkeys (%s)" % comp.hot_text())
	var want := -1
	for i in keys.size():
		if str(keys[i][0]) == "c":
			want = i
	for i in want:
		comp._route(_pad(JOY_BUTTON_Y))
	_check(comp.hot_i == want and comp.hot_text().find("CAPACITY") >= 0, "Y steps to CAPACITY (%s)" % comp.hot_text())
	comp._route(_pad(JOY_BUTTON_X))
	_check(comp.dispatch.view == "capacity", "X presses it: the capacity view")
	comp._route(_key(KEY_B))
	_check(comp.dispatch.view == "board", "the B key still goes back to the board")
	comp.app = "crm"
	_check(comp.hot_keys().size() == 8, "the CRM lists its eight letters")
	comp.app = "knowledge"
	_check(comp.hot_keys().size() == 8, "the knowledge base lists its letters")
	comp.app = "mail"
	_check(comp.hot_keys().is_empty() and comp.hot_text() == "", "an app without letter hotkeys has no strip")
	comp.app = "desktop"
	comp.is_open = false
	# the pause menu row and the Free Play menu card
	pm.open()
	var at: int = pm._labels().find("FREE PLAY MENU")
	_check(at >= 0, "the pause menu has a FREE PLAY MENU row in Free Play")
	pm._sel = at
	pm._activate()
	await _wait(3)
	_check(not pm.is_open and cards.is_open, "it closes the menu and opens the card")
	var ids := []
	for o in cards.options:
		ids.append(str(o.id))
	_check(ids == ["mutator", "tools", "outing", "person", "close"], "mutator, toolbox, outing, next person, close (%s)" % str(ids))
	var before: String = muts.forced
	cards.pick(0)
	await _wait(3)
	_check(muts.forced != before and cards.is_open, "MUTATOR steps to the next one and the card comes back (%s)" % muts.forced)
	_check(str(cards.options[0].label).find(muts.tag().to_upper()) >= 0 or str(cards.options[0].label).find(muts.tag()) >= 0, "and shows its name (%s)" % str(cards.options[0].label))
	muts.set_forced("")
	var who: String = p.character_id()
	cards.pick(ids.find("person"))
	await _wait(3)
	_check(p.character_id() != who, "NEXT PERSON swaps the character (%s -> %s)" % [who, p.character_id()])
	who = p.character_id()
	Input.parse_input_event(_pad(JOY_BUTTON_RIGHT_STICK))
	await _wait(3)
	Input.parse_input_event(_pad(JOY_BUTTON_RIGHT_STICK, false))
	await _wait(2)
	_check(p.character_id() != who, "R3 on a pad is the next person too")
	_check(tb.open_free_menu(), "the card opens again")
	await _wait(2)
	cards.pick(ids.find("tools"))
	await _wait(3)
	_check(tb.is_open and tb.mode == "tools", "TOOLBOX opens the toolbox")
	tb.close()
	tb.open_free_menu()
	await _wait(2)
	cards.pick(ids.find("outing"))
	await _wait(6)
	_check(cards.is_open and str(cards.speaker).to_lower().find("outing") >= 0, "TEAM OUTING asks the outing card (%s)" % str(cards.speaker))
	var guard := 0
	while cards.is_open and guard < 10:
		cards.pick(cards.options.size() - 1)
		guard += 1
		await _wait(2)

	# ---- roll: the left trigger + the stick -------------------------------------------------------------------------
	var seat: Node = null
	for cand in current_scene.get_node("Interactables").get_children():
		if not str(cand.name).begins_with("Seat") or p.state == "sitting":
			continue
		seat = cand
		p.global_position = Vector2(cand.global_position.x, 118)
		await _wait(5)
		p._pick = cand  # the arrow on the chair (a coworker may stand next to it)
		p._pick_x = p.global_position.x
		Input.action_press("interact")
		await _wait(2)
		Input.action_release("interact")
		await _wait(120)
		while cards.is_open:
			cards.pick(cards.options.size() - 1)
			await _wait(2)
	_check(p.state == "sitting", "seated (%s, %s)" % [p.state, str(seat.name)])
	var roll: Node = p._roll
	Input.action_press("roll")
	Input.action_press("move_left")
	await _wait(30)
	Input.action_release("move_left")
	Input.action_release("roll")
	_check(p.state == "sitting" and absf(roll.off) > 5.0, "the roll action + left rolls the chair and keeps you seated (off %.1f)" % roll.off)

	# ---- the touch overlay --------------------------------------------------------------------------------------------
	_check(c.touch == null and not c.touch_on(), "no touch screen: no overlay at all")
	c.touch_override = 1
	c.touch_refresh()
	await _wait(3)
	var ov: Node = c.touch
	_check(ov != null and root.get_child(root.get_child_count() - 1) == ov, "a touch screen: the overlay is the last node of the root")
	var btn: Dictionary = ov.buttons()
	_check(btn.has("a") and btn.has("b") and btn.has("menu") and btn.has("next") and btn.has("roll"), "stick, two buttons, MENU, and NEXT + ROLL while seated (%s)" % str(btn.keys()))
	var view: Rect2 = root.get_visible_rect()
	var inside := true
	var small := false
	for id in btn:
		inside = inside and view.encloses(btn[id])
		small = small or (btn[id] as Rect2).size.y < 19.0
	_check(inside and not small, "every button is on screen and 19 px high or more")
	var off0: float = roll.off
	if not btn.has("roll"):
		btn["roll"] = Rect2()
	_touch(1, (btn["roll"] as Rect2).get_center(), true)
	_touch(0, ov.stick_center() + Vector2(ov.STICK_R, 0.0), true)
	await _wait(70)
	_check(Input.is_action_pressed("move_right") and Input.is_action_pressed("roll"), "ROLL + the stick pushed right hold the roll and move_right actions")
	_check(p.state == "sitting" and roll.off > off0 + 5.0, "and the chair rolls right (%.1f -> %.1f)" % [off0, roll.off])
	_touch(0, ov.stick_center() + Vector2(ov.STICK_R, 0.0), false)
	_touch(1, (btn["roll"] as Rect2).get_center(), false)
	await _wait(3)
	_check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("roll"), "lifting the fingers lets go")
	_check(c.pad_active and c.hint("ENTER GO") == "(A) GO", "the overlay counts as a pad for the hints")
	_touch(0, (btn["menu"] as Rect2).get_center(), true)
	await _wait(3)
	_touch(0, (btn["menu"] as Rect2).get_center(), false)
	await _wait(3)
	_check(pm.is_open, "MENU opens the pause menu")
	_check(ov.label_of("b") == "B" and not ov.buttons().has("next"), "in a menu the second button is B (back) and NEXT is away")
	var sel0: int = pm._sel
	_touch(0, ov.stick_center() + Vector2(0.0, ov.STICK_R), true)
	await _wait(3)
	_touch(0, ov.stick_center() + Vector2(0.0, ov.STICK_R), false)
	await _wait(3)
	_check(pm._sel == sel0 + 1, "the stick pushed down moves the menu cursor (%d -> %d)" % [sel0, pm._sel])
	btn = ov.buttons()
	_touch(0, (btn["b"] as Rect2).get_center(), true)
	await _wait(3)
	_touch(0, (btn["b"] as Rect2).get_center(), false)
	await _wait(3)
	_check(not pm.is_open, "B closes it")
	c.touch_override = 0
	c.touch_refresh()
	await _wait(3)
	_check(c.touch == null, "the override off removes the overlay")
	c.reset_binds()
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
