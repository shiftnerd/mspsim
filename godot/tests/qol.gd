extends SceneTree
# Quality of life: cards and the day report ignore an instant confirm, Space no longer confirms a
# card, day-1 control hints, the reboot button warns about unsaved work, an early tired warning.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var report := root.get_node("DayReport")
	var hints := root.get_node("Hints")
	var msp := root.get_node("Msp")
	var shift := root.get_node("Shift")
	var skills := root.get_node("Skills")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")

	# ---- a card cannot be skipped the instant it appears
	var picked := []
	cards.ask(
		"Test",
		"pick",
		[{"label": "A", "id": "a"}, {"label": "B", "id": "b"}],
		func(id: String) -> void: picked.append(id)
	)
	cards._input(_key(KEY_ENTER))
	_check(cards.is_open and picked.is_empty(), "Enter right after a card opens is ignored")
	OS.delay_msec(600)
	cards._input(_key(KEY_SPACE))
	_check(cards.is_open, "Space no longer confirms a card (it is the jump key)")
	cards._input(_key(KEY_ENTER))
	_check(not cards.is_open and picked == ["a"], "Enter confirms after a moment")

	# ---- the day report too
	var r: Dictionary = c.make_report()
	r["rep"] = 50
	r["cash"] = 0
	r["total_days"] = 20
	r["fired"] = false
	r["final"] = false
	r["ending"] = ""
	report.show_report(r)
	report._input(_key(KEY_ENTER))
	_check(report.is_open, "the report ignores Enter for the first moment")
	OS.delay_msec(700)
	report._input(_key(KEY_ENTER))
	_check(not report.is_open, "then Enter continues")

	# ---- day 1 hints
	c.day = 1
	hints.reset()
	hints._t = 5.0
	hints._process(0.1)
	_check(hints.active() and hints.text.contains("MOVE"), "day 1: the first hint teaches movement")
	hints._t = 50.0
	hints._process(0.1)
	_check(
		hints.text.contains("DESK") or hints.text.contains("USES"),
		"and the next ones follow: " + hints.text
	)
	c.day = 2
	hints._process(0.1)
	_check(hints.text == "", "no hints after day 1")
	c.day = 1

	# ---- the reboot button warns about unsaved work
	msp.reset()
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	var ep: Dictionary = msp.endpoint(t.endpoint)
	ep.unsaved = true
	_check(msp.reboot_label(ep) == "REBOOT (ASK FIRST?)", "reboot says ask first")
	skills.xp["people"] = 40
	_check(
		msp.reboot_label(ep) == "REBOOT (OPEN DOCS!)",
		"with CUSTOMER 2 you can see they have documents open"
	)
	ep.unsaved = false
	_check(msp.reboot_label(ep) == "REBOOT (NOTHING OPEN)", "...or that they do not")
	skills.xp["people"] = 0
	ep.asked = true
	_check(msp.reboot_label(ep) == "REBOOT (USER WARNED)", "after asking: warned")
	var bsod: Dictionary = msp.endpoint(msp.create_ticket(0, 3, "test").endpoint)
	_check(msp.reboot_label(bsod) == "REBOOT", "a blue screen: plain reboot")

	# ---- tired warning at 55
	shift.enabled = true
	shift.reset()
	shift.energy = 50.0
	shift._warned = 0
	var texts0: int = msp.texts.size()
	shift._process(0.1)
	_check(
		msp.texts.size() == texts0 + 1 and msp.texts[0].body.contains("tired"),
		"a warning at 55 energy"
	)
	DirAccess.remove_absolute(c.save_path("tech"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
