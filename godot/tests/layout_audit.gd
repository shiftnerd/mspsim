extends SceneTree
# Catch-all layout audit (needs a renderer, not --headless): renders the key screens in wide, h and v and fails when
# any PixelFont text rect leaves the viewport. Text drawn through PixelFont.draw is logged with its rect in viewport
# pixels (PixelFont.audit, see pixelfont.gd). Overlapping text is listed as WARN lines and does not fail the run.
#   Godot --fixed-fps 60 --path godot -s res://tests/layout_audit.gd [-- --only=title,card]
# Any other test can be audited too: set env LAYOUT_AUDIT=1 and Game prints OFFSCREEN / OVERLAP lines as they happen.

const PixelFont := preload("res://scripts/pixelfont.gd")
const FORMATS := ["wide", "h", "v"]
const WHITE := Color.WHITE

var failures := 0
var warns := 0
var screens := 0
var fmt := "wide"
var only: PackedStringArray = PackedStringArray()
var shots := false  # -- --shots also saves user://audit_FORMAT_TAG.png for every screen


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7).split(",")
		elif arg == "--shots":
			shots = true
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _scene(path: String) -> void:
	change_scene_to_file(path)
	await _wait(3)
	while current_scene == null:
		await process_frame
	await _wait(5)


func _begin() -> void:
	PixelFont.audit = []


# Waits for a redraw, then fails on every text rect outside the viewport.
func _end(tag: String) -> void:
	await _wait(4)
	var seen: int = PixelFont.audit.size()
	if shots:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://audit_%s_%s.png" % [fmt, tag.replace(" ", "_")])
	screens += 1
	if seen == 0:
		failures += 1
		print("FAIL %s %s: nothing was drawn (the screen did not open?)" % [fmt, tag])
		return
	for line in PixelFont.audit_report("%s %s" % [fmt, tag], true):
		if line.begins_with("OFFSCREEN"):
			failures += 1
			print("FAIL " + line)
		else:
			warns += 1
			print("WARN " + line)
	PixelFont.audit = null


func _want(tag: String) -> bool:
	return only.is_empty() or only.has(tag)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(0)
		n += 1


class Probe:
	extends Node2D

	func _draw() -> void:
		PixelFont.draw(self, "PROBE TEXT", Vector2(-9, 3), Color.WHITE)


func _selftest() -> void:
	# the audit must catch text that sticks out of the viewport, or a clean report means nothing
	var layer := CanvasLayer.new()  # only text inside a CanvasLayer (screen-space UI) is audited
	root.add_child(layer)
	var probe := Probe.new()
	layer.add_child(probe)
	_begin()
	probe.queue_redraw()
	await _wait(3)
	var lines: Array = PixelFont.audit_report("selftest", true)
	layer.queue_free()
	PixelFont.audit = null
	if lines.size() != 1 or not lines[0].begins_with("OFFSCREEN"):
		failures += 1
		print("FAIL selftest: an off-screen probe was not detected: ", lines)


func _run() -> void:
	var game := root.get_node("Game")
	await _selftest()
	for f in FORMATS:
		fmt = f
		game.set_format(f)
		root.get_node("Campaign").save_prefix = "user://test_audit_%d_" % OS.get_process_id()
		root.get_node("Difficulty").settings_path = "user://test_audit_%d_settings.cfg" % OS.get_process_id()
		if _want("title"):
			await _title_phase()
		if _want("floor"):
			await _floor_phase()
		print("format %s: viewport %s" % [f, root.get_visible_rect().size])
	print("screens=%d failures=%d overlap_warnings=%d" % [screens, failures, warns])
	quit(1 if failures > 0 else 0)


func _title_phase() -> void:
	# the career and meta files of an earlier format's pass (medals, a finished year) would add CONTINUE entries to the
	# tech submenu and the second and third format would never reach the character select
	DirAccess.remove_absolute(root.get_node("Career").path())
	DirAccess.remove_absolute(root.get_node("Yeartwo").meta_path())
	for m in ["tech", "owner", "sales", "service"]:  # and so would the saves and resume files the floor phase wrote
		for slot in 3:
			DirAccess.remove_absolute(root.get_node("Campaign").save_path(m, slot))
			DirAccess.remove_absolute(root.get_node("Campaign").resume_path(m, slot))
	await _scene("res://scenes/title.tscn")
	var t := current_scene
	_begin()
	t._open_menu()
	await _end("title menu")
	# the tech submenu at its fullest: a save plus a finished year (CONTINUE, START YEAR 2, NEW CAMPAIGN)
	var camp := root.get_node("Campaign")
	var yt := root.get_node("Yeartwo")
	var old_prefix: String = camp.save_prefix
	camp.save_prefix = "user://test_audit_%d_" % OS.get_process_id()
	var save := ConfigFile.new()
	save.set_value("campaign", "day", 12)
	save.set_value("campaign", "year", 2)
	save.save(camp.save_path("tech"))
	var meta := ConfigFile.new()
	yt.record(meta, "tech", "lead")
	meta.save(yt.meta_path())
	_begin()
	t._choose(0)
	await _end("title submenu")
	DirAccess.remove_absolute(camp.save_path("tech"))
	DirAccess.remove_absolute(yt.meta_path())
	camp.save_prefix = old_prefix
	t._show_top(0)
	var new_row := 0  # R40: the home menu may start with CONTINUE; NEW opens the list of campaigns, whose first row is the tech campaign
	for i in t._items.size():
		if str(t._items[i].get("id", "")) == "new":
			new_row = i
	t._choose(new_row)
	await _wait(10)
	if is_instance_valid(t) and t._select == null:
		t._choose(0)
		await _wait(10)
	if not is_instance_valid(t) or t._select == null:
		print("WARN %s title: the character select did not open (items %s), its pages are not audited" % [fmt, str(t._items) if is_instance_valid(t) else "scene gone"])
		return
	var cs: Node = t._select
	for mode in ["free", "tech", "owner", "sales", "service"]:
		_begin()
		cs.setup(mode)
		await _end("charselect " + mode)
	for mode in ["free", "tech", "owner", "sales", "service"]:  # the pages after the character / creator: the phone (tech), the options, the build
		cs.setup(mode)
		await _wait(3)
		var guard := 0
		while cs.step != "options" and guard < 5:
			if cs.step == "phone":
				_begin()
				await _end("phone " + mode)
			if cs.step == "tier":  # R1: the difficulty step of a campaign
				_begin()
				cs.queue_redraw()
				await _end("tier " + mode)
			cs.confirm()
			guard += 1
		_begin()
		cs.queue_redraw()
		await _end("options " + mode)
		if mode == "tech" or mode == "owner":
			root.get_node("Yeartwo").begin_select(mode, true)  # the MUT row too
			cs.opt_row = 2
			_begin()
			cs.queue_redraw()
			await _end("options year2 " + mode)
			root.get_node("Yeartwo").pending = false
		if mode == "free":
			continue
		_begin()
		cs.confirm()
		await _end("build " + mode)
		if cs._panel != null:
			_begin()
			cs._panel.row = 5
			cs._panel.cycle_quirk(0, 1)
			cs.queue_redraw()
			await _end("build quirk " + mode)
	for mode in ["tech", "free"]:
		cs.setup(mode)  # opens straight in the creator, START row first
		await _wait(3)
		_begin()
		root.get_node("Look").look["name"] = "WWWWWWWWWW"
		cs.queue_redraw()
		await _end("creator " + mode)
		_begin()
		cs.set_start(cs.ids.size() - 1)  # the last ready-made person (READY-MADE tag)
		cs.queue_redraw()
		await _end("creator ready-made " + mode)
		cs.set_start(0)
		root.get_node("Look").look["name"] = "WWWWWWWWWW"
		_begin()
		cs.create_row = cs._page_rows().size()
		cs.queue_redraw()
		await _end("creator random row " + mode)
		_begin()
		root.get_node("Look").look["hair_style"] = "receding"  # the longest style name
		cs.create_row = 2
		cs.queue_redraw()
		await _end("creator style row " + mode)
		root.get_node("Look").look["hair_style"] = "side"
		# level 3 step e: the mirror preview's pose line (the longest label, held) and the wrapped keys line
		_begin()
		cs.create_row = 0
		cs.set_pose(6, true)  # HOLD SCRATCH
		cs.queue_redraw()
		await _end("creator pose held " + mode)
		cs.set_pose(3)
		cs.pose_hold = false
		cs.set_pose(0)
		# level 3: the CLOTHES page (the longest values), the bottom row on it, the presets chooser, the pad's name grid
		root.get_node("Look").look["pattern"] = "stripes"
		root.get_node("Look").look["shorts"] = "shorts"
		for page_name in ["clothes", "clothes bottom row"]:
			_begin()
			cs.set_page(1)
			cs.create_row = 1 if page_name == "clothes" else cs._page_rows().size()
			cs.queue_redraw()
			await _end("creator %s %s" % [page_name, mode])
		var lk := root.get_node("Look")
		# level 3 steps b to d: the EXTRAS and WORK pages with the longest names (a bucket hat leaves three hats locked), and the
		# STYLE row of a hairstyle a hat replaces (CURLY>SHORT)
		lk.acc = {"glasses": "aviator", "beard": "moustache", "hat": "bucket", "badge": "name", "lanyard": "conference", "watch": "silver", "beard_color": "", "frame_color": ""}
		lk.look["hair_style"] = "curly"
		_begin()
		cs.set_page(0)
		cs.create_row = 2
		cs.queue_redraw()
		await _end("creator style hat " + mode)
		for pg in [2, 3]:
			for rr in [0, 2]:
				_begin()
				cs.set_page(pg)
				cs.create_row = rr
				cs.queue_redraw()
				await _end("creator page %d row %d %s" % [pg, rr, mode])
		lk.acc = lk.default_acc()
		lk.look["hair_style"] = "side"
		lk.look["name"] = "WWWWWWWWWW"
		lk.presets = [lk.look.duplicate(), {}, lk.look.duplicate()]
		_begin()
		cs.open_presets()
		lk.presets = [lk.look.duplicate(), {}, lk.look.duplicate()]
		cs.queue_redraw()
		await _end("creator presets " + mode)
		cs.close_modal()
		_begin()
		cs.open_name_grid()
		cs._grid_i = 29
		await _end("creator name grid " + mode)
		cs.close_modal()
		cs.set_page(0)
		lk.look["pattern"] = "none"
		lk.look["shorts"] = "none"
	# level 3 step e: the Free Play outfit overlay (the create step over the room, no run chips)
	var ov = load("res://scripts/charselect.gd").new()
	t._front.add_child(ov)
	ov.setup_overlay()
	for pg in [0, 2]:
		_begin()
		ov.set_page(pg)
		ov.queue_redraw()
		await _end("outfit overlay page %d" % pg)
	ov.queue_free()
	root.get_node("Look").active = false
	t._close_select()
	await _wait(3)
	# career screen
	var c := root.get_node("Career")
	c.toasts = false
	for k in ["tickets", "outings", "bowl_strikes", "pets", "nerf_hits", "printer_wins", "meetings", "days.tech"]:
		c.counters[k] = 12
	c.check_medals()
	t._open_menu()
	await _wait(3)
	t._open_career()
	await _wait(10)
	var screen: Node = t._career
	if screen == null:
		failures += 1
		print("FAIL %s career: screen did not open" % fmt)
		return
	for p in screen.page_count():
		_begin()
		screen.go(1 if p > 0 else 0)
		if screen.get("_canvas") != null:
			screen._canvas.queue_redraw()
		else:
			screen.queue_redraw()
		await _end("career page %d" % p)
	screen.close()
	await _wait(3)
	# toolbox rows
	t._open_menu()
	await _wait(3)
	t._choose(t._items.map(func(i: Dictionary) -> String: return i.id).find("free"))
	await _wait(10)
	if t._select != null:
		var tb := root.get_node("Toolbox")
		t._select.setup("free")
		await _wait(3)
		_begin()
		t._select.open_tools()
		for g in tb.GAMES.size():
			tb.game_i = g
			tb.sel = 0
			tb._canvas.queue_redraw()
			await _wait(2)
		await _end("toolbox rows")
		tb.close()
		_begin()
		t._select.open_seed()
		await _end("toolbox seed page")
		tb.close()


func _report(kind: String) -> Dictionary:
	var r := {
		"day": 7, "total_days": 20, "closed": 6, "missed": 1, "reopened": 0, "open_left": 2, "clients": 72,
		"points": 14, "overtime": 1.5, "social": 3, "energy": 31, "late": 25, "oncall": 1, "pay": 340,
		"rep_delta": 3, "rep": 53, "cash": 1280, "grade": "B", "fired": false, "final": false, "ending": "",
	}
	if kind == "ending":
		r["day"] = 20
		r["final"] = true
		r["grade"] = "A"
		r["ending"] = "YOU KEPT YOUR JOB. MORGAN SAYS THE TEAM IS GLAD YOU STAYED AND THE CLIENTS ASK FOR YOU BY NAME."
	elif kind == "owner":
		r["grade"] = "A"
		r["title"] = "WEEK 9 OF 20 COMPLETE"
		r["rows"] = [
			["REVENUE", "$6400", Color("8fe3a0")], ["PAYROLL (W-2)", "-$3100", WHITE],
			["OTHER COSTS + MARKETING", "-$1300", WHITE], ["JOBS AND DEALS", "+$450", Color("8fe3a0")],
			["EBITDA", "$2450", Color("8fe3a0")], ["EBITDA MARGIN", "38% (PEERS 15%)", Color("8fe3a0")],
			["W-2 RATIO", "48% (TARGET 55%)", Color("8fe3a0")], ["CASH", "$9800", Color("8fe3a0")],
			["CLIENTS, A/R OWED", "8 (70%), $1200", Color("ffd27a")], ["OWNER HOURS", "22 FREE", WHITE],
			["PARTNER TRUST", "GARRISON 55 (SOLID)", WHITE], ["PERSONAL GOAL", "A CLEAN YEAR: 3/3 ON TRACK", WHITE],
			["RECURRING + PROJECTS", "$6400/WK + $450 JOBS", Color("8fe3a0")],
			["VALUE (ESTIMATE)", "$412000, A GROWTH COMPANY", Color("ffd27a")],
		]
	return r


func _new_game(mode: String, who: String) -> void:
	root.get_node("Game").title_mode = false
	load("res://scripts/player.gd").current_character = who
	root.get_node("Campaign").new_game(mode)
	root.get_node("Msp").enabled = false
	await _wait(5)
	_clear(root.get_node("Cards"))


func _floor_phase() -> void:
	var c := root.get_node("Campaign")
	var comp := root.get_node("Computer")
	var cards := root.get_node("Cards")
	var rep := root.get_node("DayReport")
	var world := root.get_node("World")
	# ---- tech campaign: cards, day report, computer apps, phone
	root.get_node("Game").title_mode = false
	await _scene("res://scenes/main_floor.tscn")
	await _new_game("tech", "office_intern")
	world.clock = 11.0
	_begin()
	cards.ask("MORGAN (MANAGER)", "TWO OWNERS, ONE ACCOUNT, AND A PROSPECT WHO WANTS AN ANSWER BY FRIDAY. WHOSE SIDE ARE YOU ON? I NEED THIS DECISION BEFORE THE END OF THE DAY.", [
		{"label": "GARRISON: TAKE THE LOGO AT 30% OFF AND HOPE THE MARGIN HOLDS UP", "id": "a", "trust_chip": "GARRISON +4", "trust_dir": 1},
		{"label": "ALAN: 10% OFF, LET THEM WALK", "id": "b", "trust_chip": "ALAN +4", "trust_dir": 1},
		{"label": "BROKER A SCOPED 15% (2 HOURS)", "id": "c"},
		{"label": "STALL UNTIL MONDAY AND SAY NOTHING TO EITHER", "id": "d", "trust_chip": "BOTH -2", "trust_dir": -1},
	], func(_id: String) -> void: pass)
	await _end("card long")
	_clear(cards)
	for kind in ["tech", "ending", "owner"]:
		_begin()
		rep.is_open = false
		rep.show_report(_report(kind))
		await _end("day report " + kind)
		rep.is_open = false
		rep._canvas.visible = false
	for app in ["desktop", "mail", "psa", "rmm", "learn", "lync"]:
		_begin()
		comp.open(1)
		comp.app = app
		comp._canvas.queue_redraw()
		await _end("computer " + app)
		comp.close()
		await _wait(2)
	var ph := root.get_node("Phone")
	ph.os = "android"
	for app in ["home", "mail", "texts", "tickets", "settings"]:
		_begin()
		ph.open()
		ph.app = app
		ph._canvas.queue_redraw()
		await _end("phone " + app)
		ph.close()
		await _wait(2)
	# R37: the camera app (viewfinder, the roll, a photo), on both phones
	for skin in ["android", "ios"]:
		ph.os = skin
		ph.photos = []
		ph.open()
		ph.locked = false
		ph.app = "camera"
		for view in ["finder", "roll", "photo"]:
			if view == "roll":
				ph.take_photo()
				ph.take_photo()
			ph.cam_view = view
			ph.cam_sel = 0
			_begin()
			ph._canvas.queue_redraw()
			await _end("phone camera %s %s" % [view, skin])
		ph.close()
		await _wait(2)
	ph.os = "android"
	ph.photos = []
	# R14 (4): the touch overlay over the room, and over the pause menu
	var ctl := root.get_node("Controls")
	ctl.touch_override = 1
	ctl.touch_refresh()
	_begin()
	await _end("touch overlay")
	var pm := root.get_node("PauseMenu")
	pm.open()
	_begin()
	pm._canvas.queue_redraw()
	await _end("touch overlay pause menu")
	pm.close()
	ctl.touch_override = -1
	ctl.touch_refresh()
	ctl.pad_active = false
	await _wait(2)
	# ---- owner campaign: boardroom tabs, partner trust cards
	await _scene("res://scenes/main_floor.tscn")
	await _new_game("owner", "office_alan")
	var o := root.get_node("Owner")
	o.flags["peer_group"] = true
	o.apply({"hire": o.JUNIOR})
	o.apply({"stack": {"psa": "ticketo", "hardware": "budgetbyte"}, "vic_plan": "balanced"})
	comp.open(1)
	for tab in ["books", "clients", "projects", "team", "stack"]:
		_begin()
		comp.activate("app:boardroom")
		comp.activate("btab:" + tab)
		await _end("boardroom " + tab)
	comp.close()
	_begin()
	o.show_card("peer4")
	await _end("owner card peer4")
	_clear(cards)
	# ---- sales campaign: CRM list, record, quote builder, handover
	await _scene("res://scenes/main_floor.tscn")
	await _new_game("sales", "office_john")
	var sc := root.get_node("SalesCampaign")
	var deals = load("res://scripts/deals.gd")
	sc.leads = []
	var l: Dictionary = sc.make_lead(root.get_node("Difficulty").rng_for("audit", 1))
	l.name = "Maple Street Dentistry"
	l.users = 24
	l.fee = 726
	l.stage = "QUOTED"
	l.called = true
	l.touch = 1
	l.quote = deals.norm({"method": "fixed", "promise": "high", "price": "list", "extras": ["backup"], "onboard": "rush", "win": 0.5})
	l.promises = deals.promise_list(l, l.quote)
	sc.leads.append(l)
	c.day = 4
	sc.crm_sel = int(l.id)
	_begin()
	sc.crm_page = 1
	comp.open(1)
	comp.activate("app:crm")
	await _end("crm record")
	_begin()
	sc.crm_page = 0
	comp._canvas.queue_redraw()
	await _end("crm list")
	comp.close()
	var l2: Dictionary = sc.make_lead(root.get_node("Difficulty").rng_for("audit", 2))
	l2.stage = "LEAD"
	l2.called = true
	sc.leads.append(l2)
	sc.start_quote(int(l2.id))
	comp.open(1)
	comp.activate("app:crm")
	for page in [0, 1]:
		_begin()
		sc.qb["page"] = page
		comp._canvas.queue_redraw()
		await _end("quote builder page %d" % page)
	sc.QuoteBuilder.close()
	comp.close()
	# ---- service campaign: dispatch, knowledge, desk design, hiring cards
	await _scene("res://scenes/main_floor.tscn")
	await _new_game("service", "office_dan")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	c.day = 8
	sv.apply_design("tiered", true)
	_clear(cards)
	world.clock = 11.5
	comp.open(1)
	comp.app = "dispatch"
	comp.dispatch.fuzz = 0
	for view in ["board", "capacity", "score"]:
		_begin()
		comp.dispatch.view = view
		comp._canvas.queue_redraw()
		await _end("dispatch " + view)
	comp.app = "knowledge"
	for view in ["books", "desk", "crew"]:
		_begin()
		sv.kb.view = view
		comp._canvas.queue_redraw()
		await _end("knowledge " + view)
	comp.close()
	_begin()
	sv.design = ""
	sv.design_changes = 0
	sv.design_card(false)
	await _end("desk design card")
	_clear(cards)
	_begin()
	sv.hire_card()
	await _end("hiring card")
	_clear(cards)
	# ---- the chair race: intro page, countdown, the race under way, result page
	var out := root.get_node("Outings")
	out.enabled = true
	out.use_rooms = false
	_begin()
	out.start("chair", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
	await _end("chair race intro")
	out.press(KEY_ENTER)
	_begin()
	out.tick(0.5)
	await _end("chair race countdown")
	out.tick(2.6)
	out.g.race.pos = 300.0
	out.g.race.cp_next = 1
	out.g.race.speed = 30.0
	out.g.race._say("CONE! +0.5S", 5.0)
	out.tick(0.5)
	_begin()
	await _end("chair race racing")
	out.g.race.finish_t = 21.5
	out.g.race.penalty = 3.5
	out.g.race.phase = "done"
	out.g.race.end_t = 2.0
	out.tick(0.1)
	_begin()
	await _end("chair race result")
	out.close()
	# ---- paintball (the overlay version: intro, countdown, a match under way, result page)
	_begin()
	out.start("paintball", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
	await _end("paintball intro")
	out.press(KEY_ENTER)
	_begin()
	out.tick(0.5)
	await _end("paintball countdown")
	out.tick(3.0)
	out.g.rules.say("ALAN HAS THE FLAG!", 5.0)
	out.tick(0.1)
	_begin()
	await _end("paintball playing")
	out.g.rules.score[0] = 3
	out.tick(0.1)
	out.tick(1.6)
	_begin()
	await _end("paintball result")
	out.close()
	# ---- R12 / R41: the chair card's other events (THE GAUNTLET, the chair fight) and the night match, as overlay pages and as
	# the in-room HUD strip (the strip is drawn when Outings thinks it is in the room: _traveled, set only while the frame is taken)
	for event in ["gauntlet", "fight"]:
		out.chair_event = "straight"
		_begin()
		out.start("chair", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
		out.press(KEY_RIGHT)
		if event == "fight":
			out.press(KEY_RIGHT)
		await _end("chair %s intro" % event)
		out.press(KEY_ENTER)
		out.tick(3.4)
		if event == "fight":
			out.g.race.chairs[0].bumps = 2
			out.g.race.chairs[1].bumps = 1
			out.g.race._say("GARRISON GOT YOU! 2 TO 1", 5.0)
		else:
			out.g.race.pos = 300.0
			out.g.race.cp_next = 1
			out.g.race._say("CHECKPOINT 1 OF 2", 5.0)
		out.tick(0.1)
		_begin()
		await _end("chair %s playing" % event)
		out._traveled = true
		_begin()
		await _end("chair %s hud strip" % event)
		out._traveled = false
		if event == "fight":
			out.g.race.chairs[0].bumps = 3
		else:
			out.g.race.finish_t = 14.5
			out.g.race.phase = "done"
			out.g.race.end_t = 2.0
		out.tick(0.1)
		out.tick(1.4)
		_begin()
		await _end("chair %s result" % event)
		out.close()
	out.chair_event = "straight"
	_begin()
	out.start("paintball", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"], "night": true})
	await _end("paintball night intro")
	out.press(KEY_ENTER)
	out.tick(3.2)
	out.g.rules.units[0].flag = true
	out.tick(0.1)
	out._traveled = true
	_begin()
	await _end("paintball hud strip")
	out._traveled = false
	out.close()
	# ---- R21: cornhole and the cookout (the overlay versions: intro, play, result)
	for id in ["cornhole", "grill", "darts"]:
		_begin()
		out.start(id, false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
		await _end("%s intro" % id)
		out.press(KEY_ENTER)
		out.tick(2.0)
		if id == "cornhole":
			out.g.game.marker = 0.4
			out.g.game.score_you = 7
			out.g.game.score_opp = 4
		elif id == "grill":
			out.g.game.slots[1].c = [0.5, 0.2]
			out.g.game.slots[2].flare = 3.0
			out.g.game.msg_t = 2.0
		else:
			for who in out.g.game.players:
				out.g.game.totals[who] = 87 if who == "You" else 52
		out.tick(0.3)
		_begin()
		await _end("%s play" % id)
		if id == "darts":
			for who in out.g.game.players:
				out.g.game.totals[who] = 214 if who == "You" else 132
			out.g.game.phase = "done"
		elif id == "grill":
			out.g.game.served = 5
			out.g.game.done = true
		else:
			out.g.game.score_you = 15
			out.g.game.phase = "round_end"
			out.g.game.t = 99.0
		out.tick(1.0)
		out.tick(2.0)
		_begin()
		await _end("%s result" % id)
		out.close()
	# ---- R6: the variety dinner (overlay): the intro with what you know, the ordering round, a table event, the result page
	var since := {"HOME BREWING": 2, "FANTASY FOOTBALL": 3, "RAISES AND BONUSES": 1}
	var alan := {"likes": ["HOME BREWING", "FANTASY FOOTBALL"], "hates": ["RAISES AND BONUSES"], "since": since, "diet": "mushroom", "diet_since": 2}
	out.known = {"Alan": alan}
	_begin()
	out.start("dinner", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"], "variety": true, "guest": 0})
	await _end("dinner variety intro")
	out.begin_play()
	_begin()
	await _end("dinner variety order")
	out.dinner_order(0)
	out.dinner_event("phone", "Garrison")
	_begin()
	await _end("dinner variety event")
	out.g.score = 99
	out.g.order.fit = true
	out.g.order.pick = "flatbread"
	out.g["tab"] = "fancy"
	out.dinner_guest().mood = 3
	out._dinner_end()
	_begin()
	await _end("dinner variety result")
	out.close()
	out.known = {}
	# ---- R4: the intro page of every themed escape room (the room version carries the theme's own, longer intro)
	for theme in out.THEME_ORDER:
		out.start("escape", false, {"party": ["Alan", "Garrison", "Dan"], "theme": theme, "panel": true})
		out._traveled = true  # the room's intro text without travelling there
		_begin()
		await _end("escape intro " + str(theme))
		out._traveled = false
		out.close()
	# ---- R23: the caption of a conference session you are sitting in (the longest line of the agenda)
	var expo := root.get_node("Expo")
	var longest := ""
	for round_i in expo.ROUNDS.size():
		for session in expo.pool(round_i):
			for line in expo.talk_lines(session):
				if str(line).length() > longest.length():
					longest = str(line)
	expo.seated = {"index": 0, "id": "patch", "title": "PATCH MANAGEMENT BEST PRACTICES", "door": 3, "lines": [longest, "X"], "at": 0, "t": 0.0, "clock": 10.0, "hours": 0.0}
	expo._canvas.visible = true
	root.get_node("Phone")._bq.clear()  # the mail banners that waited behind the outing pages slide in from above the screen:
	root.get_node("Phone").banner = {}  # they are not part of this screen
	_begin()
	await _end("session talk")
	expo.seated = {}
	expo._canvas.visible = false
	root.get_node("Game").ui_open = false
	out.enabled = false
	print("floor phase done for ", fmt, " (crew ", crew.members.size(), ")")
