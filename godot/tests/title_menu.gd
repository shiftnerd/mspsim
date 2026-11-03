extends SceneTree
# The title menu's two levels (roadmap R17): six short top lines, a submenu per campaign (CONTINUE / START YEAR 2 /
# NEW CAMPAIGN by state), Esc backs out one level, a mode with nothing but NEW goes straight to the character select,
# keyboard, pad and mouse. Events go straight to the title's _unhandled_input. Saves go to user://test_<pid>_*.

var failures := 0
var title: Node
var c: Node
var y: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	title._unhandled_input(ev)


func _pad(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	title._unhandled_input(ev)


func _ids() -> Array:
	return title._items.map(func(i: Dictionary) -> String: return i.id)


func _labels() -> Array:
	return title._items.map(func(i: Dictionary) -> String: return i.label)


func _save(mode: String, day: int, year: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "day", day)
	cfg.set_value("campaign", "year", year)
	cfg.save(c.save_path(mode))


func _wipe() -> void:
	for mode in ["tech", "owner", "service", "sales"]:
		for n in range(1, 4):
			c.delete_slot(mode, n)
	DirAccess.remove_absolute(y.meta_path())


func _fresh_title() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	await process_frame
	title = current_scene
	title._open_menu()


func _init() -> void:
	await process_frame
	c = root.get_node("Campaign")
	y = root.get_node("Yeartwo")
	c.save_prefix = "user://test_tm_%d_" % OS.get_process_id()
	_wipe()

	# ---- top menu
	await _fresh_title()
	_check(title._menu_open and title._level == "top", "Enter opens the top menu")
	_check(_ids() == ["tech", "owner", "service", "sales", "free", "career"], "six top lines: %s" % str(_ids()))
	_check(
		_labels() == ["TECH CAMPAIGN", "OWNER CAMPAIGN", "SERVICE MANAGER", "SALES", "FREE PLAY", "CAREER"],
		"top labels %s" % str(_labels())
	)
	_check(title._items.all(func(i: Dictionary) -> bool: return i.enabled), "every campaign is playable")

	# ---- submenu items by state
	_check(title.sub_items("tech").map(func(i: Dictionary) -> String: return i.id) == ["tech_new"], "no save: NEW CAMPAIGN only")
	_save("owner", 5, 1)
	var rows: Array = title.sub_items("owner")
	_check(rows.map(func(i: Dictionary) -> String: return i.id) == ["owner_slot1", "owner_new"], "a save: its SLOT row then NEW CAMPAIGN")
	_check(str(rows[0].label) == "SLOT 1 - WEEK 5 - ADULT" and str(rows[1].label) == "NEW CAMPAIGN", "labels: %s" % str(rows.map(func(i: Dictionary) -> String: return i.label)))
	_save("owner", 5, 2)
	_check(str(title.sub_items("owner")[0].label) == "SLOT 1 - WEEK 5 (YEAR 2) - ADULT", "a Year 2 save shows the tag")
	_save("service", 3, 1)
	_check(str(title.sub_items("service")[0].label) == "SLOT 1 - DAY 3 - ADULT", "days for the tech-style modes")
	var meta := ConfigFile.new()
	y.record(meta, "owner", "stay")
	meta.save(y.meta_path())
	rows = title.sub_items("owner")
	_check(rows.map(func(i: Dictionary) -> String: return i.id) == ["owner_slot1", "owner_y2", "owner_new"], "save + finished year: SLOT 1, YEAR 2, NEW")
	_check(str(rows[1].label) == "START YEAR 2", "the Year 2 row reads START YEAR 2")
	DirAccess.remove_absolute(c.save_path("owner"))
	_check(title.sub_items("owner").map(func(i: Dictionary) -> String: return i.id) == ["owner_y2", "owner_new"], "finished year without a save: YEAR 2, NEW")
	_save("owner", 5, 1)

	# ---- keyboard: into a submenu, Esc back (cursor kept), Esc closes
	title._show_top(0)
	_key(KEY_DOWN)
	_check(title._sel == 1 and _ids()[1] == "owner", "Down goes to OWNER CAMPAIGN")
	_key(KEY_ENTER)
	_check(title._level == "sub" and title._heading == "OWNER CAMPAIGN", "Enter opens the owner submenu with its heading")
	_check(_ids() == ["owner_slot1", "owner_y2", "owner_new"] and title._sel == 0, "submenu rows %s, cursor on the first" % str(_ids()))
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	_check(_ids()[title._sel] == "owner_new", "Down walks the submenu")
	_key(KEY_ESCAPE)
	_check(title._level == "top" and title._menu_open and title._sel == 1, "Esc returns to the top menu on OWNER CAMPAIGN")
	_key(KEY_ESCAPE)
	_check(not title._menu_open and not title._menu.visible, "Esc on the top menu closes it")

	# ---- a mode with only NEW goes straight to the character select
	title._open_menu()
	_check(title._level == "top" and title._sel == 0, "reopening starts on the top menu")
	_key(KEY_ENTER)  # TECH CAMPAIGN: no save, no finished year
	_check(title._select != null and title._level == "top", "TECH with nothing saved skips the submenu")
	_check(title._select.mode == "tech", "... and opens the tech character select")
	title._close_select()
	_check(title._menu_open and title._level == "top" and title._menu.visible, "Esc on the select returns to the top menu")

	# ---- YEAR 2 opens the select with Year 2 pending, and backing out clears it
	_save("owner", 5, 1)
	title._show_top(1)
	title._choose(1)  # OWNER CAMPAIGN: slot 1, year 2, new
	title._choose(2)  # NEW CAMPAIGN
	_check(title._select != null and not y.pending, "NEW CAMPAIGN opens the select without Year 2")
	title._close_select()
	title._choose(1)
	_check(title._select != null and y.pending and title._select.mode == "owner", "START YEAR 2 opens the select with Year 2 pending")
	title._close_select()
	_check(not y.pending and title._level == "sub", "backing out of the select returns to the submenu")

	# ---- pad: D-pad, A, B
	title._show_top(0)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_A)
	_check(title._level == "sub" and title._sub_mode == "owner", "pad: D-pad down + A opens the owner submenu")
	_pad(JOY_BUTTON_B)
	_check(title._level == "top" and title._sel == 1, "pad: B backs out one level")
	_pad(JOY_BUTTON_B)
	_check(not title._menu_open, "pad: B on the top menu closes it")

	# ---- mouse: hover selects, click confirms, in both levels
	title._open_menu()
	for i in title._items.size():
		title._items[i]["rect"] = Rect2(100, 20 + i * 10, 100, 9)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(120, 20 + 1 * 10 + 4)
	title._unhandled_input(motion)
	_check(title._sel == 1, "mouse: hover selects the second line")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = motion.position
	title._unhandled_input(click)
	_check(title._level == "sub" and title._sub_mode == "owner", "mouse: a click opens the submenu")
	for i in title._items.size():
		title._items[i]["rect"] = Rect2(100, 20 + i * 10, 100, 9)
	motion.position = Vector2(120, 20 + 2 * 10 + 4)
	title._unhandled_input(motion)
	_check(_ids()[title._sel] == "owner_new", "mouse: hover selects NEW CAMPAIGN in the submenu")
	title._show_top(4)
	_check(title._items[title._sel].id == "free", "FREE PLAY stays on the top menu")
	title._show_top(5)
	_check(title._items[title._sel].id == "career", "CAREER stays on the top menu")

	# ---- a tech run with a mid-day resume point and a day-start save
	_wipe()
	c.new_game("tech")
	root.get_node("Game").title_mode = false
	var cards: Node = root.get_node("Cards")
	var guard := 0
	while cards.is_open and guard < 30:
		cards.pick(cards.options.size() - 1)
		guard += 1
	var world: Node = root.get_node("World")
	world.time_scale = 40.0
	guard = 0
	while world.clock < 12.0 and guard < 4000:
		while cards.is_open and guard < 4000:
			cards.pick(cards.options.size() - 1)
			guard += 1
		await process_frame
		guard += 1
	world.time_scale = 1.0
	await process_frame
	_check(c.snapshot() and not c.resume_info("tech").is_empty(), "a resume point exists at noon")
	c.active = false
	c.mode = ""
	root.get_node("Game").title_mode = true
	world.time_scale = 0.0
	await _fresh_title()
	rows = title.sub_items("tech")
	_check(rows.map(func(i: Dictionary) -> String: return i.id) == ["tech_slot1", "tech_new"], "resume point only: its SLOT row and NEW")
	_check(str(rows[0].label).begins_with("SLOT 1 - DAY 1  12:") or str(rows[0].label).begins_with("SLOT 1 - DAY 1  11:"), "the slot row shows day and clock: %s" % str(rows[0].label))
	title._choose(0)  # TECH CAMPAIGN -> submenu
	title._choose(0)  # the slot row: only a resume point, so it resumes at once
	await process_frame
	_check(title._started and c.active and c.slot == 1, "a slot with only a resume point resumes directly")
	c.active = false
	c.mode = ""
	root.get_node("Game").title_mode = true
	world.time_scale = 0.0
	await _fresh_title()
	_save("tech", 1, 1)
	rows = title.sub_items("tech")
	_check(rows.map(func(i: Dictionary) -> String: return i.id) == ["tech_slot1", "tech_new"], "resume + save: still one slot row")
	title._choose(0)  # TECH CAMPAIGN -> submenu
	_check(title._level == "sub" and title._select == null, "TECH with a save opens its submenu")
	title._choose(0)  # the slot row: both kinds of save, so a second choice
	_check(title._level == "slot" and not title._started and title._heading == "SLOT 1", "a slot with both opens CONTINUE / FROM THE START")
	_check(_ids() == ["tech_resume", "tech_continue"], "slot choice rows %s" % str(_ids()))
	_check(str(title._items[0].label).begins_with("CONTINUE - DAY 1  1") and str(title._items[1].label) == "DAY 1 FROM THE START", "slot choice labels: %s" % str(_labels()))
	_key(KEY_ESCAPE)
	_check(title._level == "sub" and title._sel == 0, "Esc backs out of the slot choice to the submenu")
	title._choose(0)
	title._choose(0)  # the resume row
	await process_frame
	_check(title._started and c.active and c.mode == "tech" and c.day == 1, "the resume row resumes the run")
	_wipe()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
