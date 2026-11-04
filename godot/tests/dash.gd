extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# The metrics record and the board data (roadmap R20 step 1): Dash counts tickets opened, closed and missed per day and the hours the crew
# worked, keeps a 21 day window, saves and loads with the campaign (an old save loads empty), and Dashboard.tiles / series give ten tiles
# and two charts in every mode (cozy Easy: no red tile, no per-tech hours chart). Headless; saves in user://test_*.


var failures := 0
var Dash: GDScript  # loaded at run time: both scripts read the autoloads
var Board: GDScript
var c: Node
var cards: Node
var world: Node
var msp: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear() -> void:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(0)
		n += 1


func _fresh(mode: String, tier := "normal") -> void:
	root.get_node("Difficulty").set_tier(tier)
	root.get_node("Difficulty").seed_run(41)
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Build").pending = {}
	c.new_game(mode)
	root.get_node("Career").toasts = false
	_clear()
	world.clock = 9.0


func _init() -> void:
	await process_frame
	Dash = load("res://scripts/dash.gd")
	Board = load("res://scripts/dashboard.gd")
	c = root.get_node("Campaign")
	cards = root.get_node("Cards")
	world = root.get_node("World")
	msp = root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- the record: hooks in Msp
	_fresh("tech")
	_check(Dash.days.size() == 1 and int(Dash.today().d) == 1, "a new run has today's entry (day 1)")
	_check(int(Dash.today().opened) == 0 and int(Dash.today().closed) == 0 and int(Dash.today().missed) == 0, "all zero at the start")
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	_check(not t.is_empty() and int(Dash.today().opened) == 1, "a new ticket counts as opened")
	msp.create_internal(3, "NO NETWORK AT DESK 3", "test")
	_check(int(Dash.today().opened) == 2, "an internal ticket counts as opened too")
	t.sla_left = -1.0
	msp._process(0.1)
	_check(bool(t.breached) and int(Dash.today().missed) == 1, "a blown SLA counts as missed once")
	msp._process(0.1)
	_check(int(Dash.today().missed) == 1, "and only once")
	msp.close_ticket(int(t.id))
	_check(int(Dash.today().closed) == 0, "a ticket that is not fixed does not count as resolved (it reopens)")
	t.fix_done = true
	msp.close_ticket(int(t.id))
	_check(int(Dash.today().closed) == 1, "a fixed and closed ticket counts as resolved")
	Dash.add_hours("Dan", 60.0)
	Dash.add_hours("Dan", 60.0)
	_check(is_equal_approx(float(Dash.today().hours.Dan), 1.6), "hours are stored as working hours (120 s of a 600 s day = 1.6 h)")
	Dash.add_hours("Maya", -5.0)
	_check(not Dash.today().hours.has("Maya"), "no negative hours")

	# ---- days roll over, the window is 21
	c.day = 2
	c._begin_day()
	_check(Dash.days.size() == 2 and int(Dash.today().d) == 2 and int(Dash.today().opened) == 0, "a new day starts a fresh entry")
	_check(int(Dash.days[0].opened) == 2, "yesterday's counts stay")
	Dash.begin_day(2)
	_check(Dash.days.size() == 2, "beginning the same day again does not duplicate it")
	for d in range(3, 40):
		Dash.begin_day(d)
	_check(Dash.days.size() == Dash.WINDOW and int(Dash.today().d) == 39 and int(Dash.days[0].d) == 19, "a rolling window of %d days" % Dash.WINDOW)
	var rec: Array = Dash.recent(14)
	_check(rec.size() == 14 and int(rec[13].d) == 39 and int(rec[0].d) == 26, "recent(14) is the last 14 days oldest first")
	Dash.reset()
	Dash.begin_day(1)
	Dash.begin_day(2)
	rec = Dash.recent(14)
	_check(rec.size() == 14 and int(rec[13].d) == 2 and int(rec[12].d) == 1 and int(rec[11].d) == 0, "a short history is padded in front with empty days")

	# ---- save and load
	_fresh("service")
	Dash.today().opened = 5
	Dash.today().closed = 3
	Dash.add_hours("Dan", 150.0)
	Dash.begin_day(2)
	Dash.today().opened = 7
	var cfg := ConfigFile.new()
	c._write_sections(cfg)
	_check(cfg.has_section_key("campaign", "dash"), "the save has a dash section")
	var saved: Dictionary = cfg.get_value("campaign", "dash", {})
	Dash.reset()
	_check(Dash.days.is_empty(), "reset empties the record")
	Dash.from_dict(saved)
	_check(Dash.days.size() == 2 and int(Dash.days[0].opened) == 5 and int(Dash.days[0].closed) == 3 and int(Dash.days[1].opened) == 7, "the record loads back")
	_check(is_equal_approx(float(Dash.days[0].hours.Dan), 150.0 * 8.0 / world.day_len), "with the hours")
	Dash.from_dict({})
	_check(Dash.days.is_empty(), "an old save (no section) loads empty")
	var tl: Array = Board.tiles("tech")
	_check(int(tl[2].value) == 0, "and the tiles show zeros, not invented data")
	var empty: Dictionary = Board.series("tech")[1]
	var sum := 0.0
	for s in empty.series:
		for v in s.vals:
			sum += float(v)
	_check(empty.labels.size() == Dash.SHOWN and sum == 0.0, "the opened / resolved chart is %d empty days" % Dash.SHOWN)
	Dash.from_dict({"days": [{"d": "x"}, 5, {"d": 3, "opened": "4", "hours": 7}]})
	_check(Dash.days.size() == 2 and int(Dash.days[1].opened) == 4 and Dash.days[1].hours.is_empty(), "a damaged save keeps what it can")

	# ---- a real save file round trip through Campaign
	_fresh("tech")
	Dash.today().opened = 9
	c.day = 2  # the end-of-day save is written after the day counter moves on
	c.save()
	Dash.reset()
	c.continue_game("tech")
	_clear()
	_check(Dash.days.size() >= 2 and int(Dash.days[0].opened) == 9, "continue_game restores the record and starts the next day")

	# ---- tiles and series in every mode
	for mode in Board.MODES:
		_fresh(mode)
		var tiles: Array = Board.tiles(mode)
		var ids := {}
		var ok := tiles.size() == 10
		for tile in tiles:
			ids[tile.id] = true
			ok = ok and str(tile.label) != "" and "gor y".contains(str(tile.status)) and str(tile.text) != "" and str(tile.text).length() <= int(tile.digits) + 1
		_check(ok and ids.size() == 10, "%s: ten tiles with unique ids, a label, a status and a value that fits" % mode)
		var both: Array = Board.series(mode)
		var good: bool = both.size() == 2
		for ch in both:
			good = good and ch.labels.size() > 0
			for s in ch.series:
				good = good and s.vals.size() == ch.labels.size()
			good = good and float(ch.max) >= 1.0
		_check(good, "%s: two charts, values line up with labels" % mode)
		_check(str(both[1].title).begins_with("OPENED / RESOLVED"), "%s: the right chart is opened / resolved" % mode)

	# ---- the left chart per mode, and cozy Easy
	_fresh("service")
	var who := str(root.get_node("Crew").names()[0])
	Dash.add_hours(who, 300.0)
	var left: Dictionary = Board.series("service")[0]
	_check(str(left.title).begins_with("HOURS WORKED BY TECH"), "service: the left chart is the hours per tech")
	_check(is_equal_approx(float(left.series[0].vals[0]), snappedf(300.0 * 8.0 / world.day_len, 0.1)) and left.labels[0] == Board.initials(who), "%s's hours show under %s" % [who, Board.initials(who)])
	_fresh("service", "easy")
	left = Board.series("service")[0]
	_check(not str(left.title).begins_with("HOURS") and str(left.title).begins_with("OPEN TICKETS"), "cozy Easy hides the per-tech hours (no worst-tech bar)")
	_fresh("tech")
	_check(str(Board.series("tech")[0].title) == "OPEN TICKETS BY CLIENT" and Board.series("tech")[0].labels.size() == msp.CLIENTS.size(), "tech: open tickets by client")
	_check(Board.initials("Hoot and Holler Law") == "HH" and Board.initials("Dan") == "DA", "initials of clients and people")
	var nm: Array = Board.nice_max(13.0)
	_check(float(nm[0]) >= 13.0 and float(nm[0]) <= 20.0, "nice_max rounds an axis up (13 -> %s)" % str(nm[0]))
	_check(float(Board.nice_max(0.0)[0]) == 4.0, "and gives an empty chart a 0 to 4 axis")

	# ---- statuses: red tiles and the cozy amber rule
	_fresh("tech")
	_check(Board.red_tiles("tech").is_empty(), "a quiet desk has no red tile")
	msp.backups[1].ok = false
	var red: Array = Board.red_tiles("tech")
	_check(red.size() == 1 and str(red[0].id) == "bkp", "a failing backup turns BACKUPS FAILING red")
	var open_before: int = Board.tiles("tech")[0].value
	for i in 5:
		msp.create_ticket(i % 5, i, "test")
	_check(int(Board.tiles("tech")[0].value) > open_before and str(Board.tiles("tech")[0].status) == "r", "five open tickets: OPEN is red")


	# ---- the METRICS app in every mode (step 3)
	var comp := root.get_node("Computer")
	for mode in Board.MODES:
		_fresh(mode)
		comp.open(1)
		await process_frame
		comp._menu = true
		comp._canvas.queue_redraw()
		await process_frame
		var hit_ids := []
		for h in comp._hits:
			hit_ids.append(str(h.id))
		_check("app:dash" in hit_ids, "%s: the start menu has METRICS" % mode)
		comp._menu = false
		comp.activate("app:dash")
		await process_frame
		await process_frame
		hit_ids = []
		for h in comp._hits:
			hit_ids.append(str(h.id))
		_check(comp.app == "dash" and not comp.tv_mode and "close_app" in hit_ids, "%s: METRICS opens in a window" % mode)
		comp.escape()
		_check(not comp.is_open, "%s: Esc closes the computer" % mode)
		await process_frame
	_fresh("tech")
	comp.open(1)
	comp.activate("app:dash")
	comp.dash_chart = -1
	comp.enter()
	_check(comp.dash_chart in [0, 1], "Enter swaps the chart of a wide board")
	comp.close()
	await process_frame

	# ---- the wall TV (step 4): E opens the read-only board, Esc closes it; a TV in the cubicle area too
	for scene in ["main_floor", "cubicle_area"]:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await process_frame
		await process_frame
		var tv: Node = current_scene.get_node_or_null("Fx/TV")
		var use: Node = current_scene.get_node_or_null("Interactables/UseTV")
		_check(tv != null and use != null and tv.kind == "tv", "%s: has a wall TV with an E zone" % scene)
		if use != null:
			use.use(null)
			_check(comp.is_open and comp.app == "dash" and comp.tv_mode, "%s: E on the TV opens the board in TV mode" % scene)
			comp._canvas.queue_redraw()
			await process_frame
			var ids2 := []
			for h in comp._hits:
				ids2.append(str(h.id))
			_check(not ("start" in ids2), "%s: the TV board has no taskbar (read only)" % scene)
			comp.escape()
			_check(not comp.is_open, "%s: Esc closes the TV board" % scene)
			await process_frame
	var tvfx: Node = current_scene.get_node("Fx/TV")
	tvfx._channel = 3
	tvfx._static_until = -1.0
	tvfx._next_channel = 1e9
	tvfx.queue_redraw()
	await process_frame
	_check(true, "the micro channel draws without errors")

	# ---- the glance hint (step 5)
	_fresh("tech")
	_check(Board.glance_color().a == 0.0 and Board.glance_toast() == "", "nothing red: no flash, no toast")
	root.get_node("Msp").backups[0].ok = false
	_check(Board.glance_color().is_equal_approx(Board.COLORS.r), "a red tile flashes the frame red")
	var gt: String = Board.glance_toast()
	_check(gt.contains("BACKUPS DOWN") and Board.glance_toast() == "", "one toast a day")
	Dash.begin_day(Dash.now() + 1)
	_check(Board.glance_toast() != "", "and again the next day")
	_fresh("tech", "easy")
	root.get_node("Msp").backups[0].ok = false
	_check(Board.glance_color().is_equal_approx(Board.AMBER), "cozy Easy: the frame flashes amber, not red")
	_check(not Board.glance_toast().contains("RED"), "and the toast does not say red")
	_check(Board.status_color("r", true) == Board.AMBER, "cozy status colour for red is amber")
	_fresh("owner")
	var ow: Array = Board.tiles("owner")
	var kp := 0
	for tile in ow:
		if tile.kpi is Dictionary and tile.kpi.has("met"):
			kp += 1
	_check(kp == 3, "owner: three KPI ticks (W-2, A/R, client mood)")

	# ---- the escalations trend arrow (tech: five-day weeks, pace adjusted; owner: week on week)
	_fresh("tech")
	var gr := root.get_node("Growth")
	var et: Dictionary = {}
	for et_t in Board.tiles("tech"):
		if et_t.id == "esc":
			et = et_t
	_check(not et.is_empty() and int(et.value) == 0 and int(et.trend) == 0, "tech: ESCALATIONS tile, zero and flat at the start")
	var tp: int = gr.period()
	gr.esc[tp - 1] = 5
	gr.esc[tp] = 0
	_check(gr.esc_trend() == -1, "tech day 1: nothing yet against 5 last week is down (good)")
	gr.esc[tp] = 1
	_check(gr.esc_trend() == 0, "tech day 1: 1 against a pace of 1 is flat")
	gr.esc[tp] = 3
	_check(gr.esc_trend() == 1, "tech day 1: 3 against a pace of 1 is up (bad)")
	for et_t in Board.tiles("tech"):
		if et_t.id == "esc":
			et = et_t
	_check(int(et.value) == 3 and int(et.trend) == 1 and et.status == "o", "the tile carries the count and the up trend")
	gr.esc.clear()
	_check(gr.esc_trend() == 0, "no history and no escalations: flat")
	_fresh("owner")
	gr = root.get_node("Growth")
	gr.esc[gr.period() - 1] = 4
	gr.esc[gr.period()] = 1
	_check(gr.esc_trend() == -1, "owner: 1 this week against 4 is down")
	gr.esc[gr.period()] = 6
	_check(gr.esc_trend() == 1, "owner: 6 against 4 is up")
	var oe := 0
	for et_t in Board.tiles("owner"):
		if et_t.id == "esc" and et_t.has("trend"):
			oe += 1
	_check(oe == 1 and Board.tiles("owner").size() == 10, "owner board: one ESCALATIONS tile with a trend, still ten tiles")
	var tnode := Node2D.new()
	root.add_child(tnode)
	tnode.draw.connect(
		func() -> void:
			for tr in [-1, 0, 1]:
				Board._arrow(tnode, 0.0, 0.0, tr, false)
				Board._arrow(tnode, 0.0, 0.0, tr, true)
	)
	tnode.queue_redraw()
	await process_frame
	_check(true, "all three arrows draw (normal and cozy) without errors")
	tnode.queue_free()

	# ---- layouts
	_check(Board.layout_kind(Vector2(368, 128)) == "wide" and Board.layout_kind(Vector2(368, 84)) == "wide", "368 wide = the wide layout")
	_check(Board.layout_kind(Vector2(320, 180)) == "h" and Board.layout_kind(Vector2(320, 144)) == "h", "320x180 = the h layout")
	_check(Board.layout_kind(Vector2(180, 320)) == "v" and Board.layout_kind(Vector2(180, 237)) == "v", "180x320 = the v layout")
	for sz in [Vector2(368, 128), Vector2(368, 84), Vector2(320, 180), Vector2(320, 125), Vector2(180, 320), Vector2(180, 237)]:
		var lay: Dictionary = Board.layout(Rect2(Vector2.ZERO, sz))
		var inside := true
		for r in lay.tiles + lay.charts:
			inside = inside and Rect2(Vector2.ZERO, sz).encloses(r) and r.size.x > 4.0 and r.size.y > 4.0
		var apart := true
		for i in 10:
			for j in range(i + 1, 10):
				apart = apart and not lay.tiles[i].intersects(lay.tiles[j])
		_check(inside and apart and lay.tiles.size() == 10, "layout %s: every tile and chart fits inside and tiles do not overlap" % str(sz))

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
