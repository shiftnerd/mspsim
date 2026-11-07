extends SceneTree
# P4: the server room line printer is a boss model: no prayers, a longer jam chain, its own text, a medal, and it only turns up on an onsite
# printer job after three of the ordinary models have been won.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var pg := root.get_node("PrinterGame")
	var career := root.get_node("Career")
	var onsite := root.get_node("Onsite")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	career.counters = {}
	career.earned = {}
	career.toasts = false
	_check(pg.MODELS.has("line") and bool(pg.MODELS.line.get("boss", false)) and not pg.MODEL_ORDER.has("line"), "the line printer is a boss model outside the ordinary list")
	pg.start(func(_s: int) -> void: pass, "laser")
	_check(pg.faith == 3 and pg.jam_len == 3, "an ordinary model: three prayers and a jam chain of 3")
	pg.is_open = false
	pg.start(func(_s: int) -> void: pass, "line")
	_check(pg.model == "line" and pg.faith == 0 and pg.jam_len == 5, "the boss: no prayers and a jam chain of 5")
	_check(pg._tx("title") == "LINE PRINTER" and pg._tx("tray_slot") == "SPROCKETS", "and its own text")
	pg.is_open = false
	# the unlock
	_check(not career.boss_ready(), "not ready before any model is won")
	for m in ["laser", "inkjet"]:
		career.note_printer(m, 3, false, 1)
	_check(not career.boss_ready(), "two models are not enough")
	career.note_printer("plotter", 2, false, 1)
	_check(career.boss_ready() and career.value("printer_models") == 3, "three models unlock it")
	career.note_printer("line", 1, false, 1)
	_check(career.value("printer_models") == 3, "the boss does not count as one of the six models")
	career.check_medals()
	_check(career.has_medal("line_legend") and not career.has_medal("printer_whisperer"), "winning against it earns the medal, not the every-model one")
	# the offer: some onsite printer jobs, never before the unlock
	var seen := 0
	for day in range(1, 41):
		c.day = day
		onsite.client = 0
		if onsite._printer_model("printer", true) == "line":
			seen += 1
	_check(seen >= 3 and seen <= 20, "after the unlock about a quarter of the printer jobs are the boss (%d of 40 days)" % seen)
	var never := 0
	for day in range(1, 41):
		c.day = day
		if onsite._printer_model("printer", false) == "line":
			never += 1
	_check(never == 0, "practice jobs never are")
	career.counters = {}
	var early := 0
	for day in range(1, 41):
		c.day = day
		if onsite._printer_model("printer", true) == "line":
			early += 1
	_check(early == 0, "and before the unlock it never turns up")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
