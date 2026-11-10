extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# The HUD's today's-goal chip and next-up list (roadmap R16, scripts/goals.gd): the goal line of each campaign, the
# next-up list (soonest first, at most three, only the schedule), and the layout: in every format (wide, h, v) every
# HUD text is inside the screen and the chip overlaps none of the HUD's own lines, also on the busiest day
# (on call, an outing after work, a toast). Headless; the layout part reads PixelFont's draw log.

const PixelFont := preload("res://scripts/pixelfont.gd")

var Goals: Script  # loaded in _init: a -s script compiles before the autoloads exist
var Seasons: Script  # loaded in _init: a -s script compiles before the autoloads exist
var failures := 0
var c: Node
var cards: Node
var world: Node
var msp: Node
var hud: Node2D


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


func _fresh(mode: String) -> void:
	root.get_node("Difficulty").set_tier("normal")
	root.get_node("Difficulty").seed_run(3)
	root.get_node("Game").title_mode = false
	root.get_node("Game").ui_open = false
	root.get_node("Shift").enabled = mode == "tech"
	world.time_scale = 1.0
	c.new_game(mode)
	_drain()
	msp.enabled = false


func _texts(list: Array) -> Array:
	return list.map(func(e: Dictionary) -> String: return str(e.text))


# redraw the HUD and return the draw log problems: every OFFSCREEN line, and every OVERLAP that involves a chip row
func _audit(tag: String) -> Array:
	var phone := root.get_node("Phone")
	var guard := 0
	while (not phone.banner.is_empty() or not phone._bq.is_empty()) and guard < 3000:  # a phone banner hides the chip: let it slide away first
		await process_frame
		guard += 1
	PixelFont.audit = []
	hud.queue_redraw()
	for i in 4:
		await process_frame
	var seen: int = PixelFont.audit.size()
	var out := []
	for line in PixelFont.audit_report(tag, true):
		if line.begins_with("OFFSCREEN") or line.contains("'GOAL: ") or line.contains("'NEXT: ") or line.contains("'      "):
			out.append(line)
	PixelFont.audit = null
	if seen == 0:
		out.append("%s: the HUD drew nothing" % tag)
	if not phone.banner.is_empty():
		out.append("%s: a phone banner was still up" % tag)
	return out


func _init() -> void:
	await process_frame
	Goals = load("res://scripts/goals.gd")
	Seasons = load("res://scripts/seasons.gd")
	c = root.get_node("Campaign")
	cards = root.get_node("Cards")
	world = root.get_node("World")
	msp = root.get_node("Msp")
	var game := root.get_node("Game")
	var shift := root.get_node("Shift")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Career").toasts = false
	for ch in world.get_children():
		if ch is CanvasLayer and ch.get_child_count() > 0 and ch.get_child(0).has_method("modal_open"):
			hud = ch.get_child(0)
	_check(hud != null, "the HUD node is there")

	# ---- the goal line
	c.new_game("free")
	_check(Goals.goal() == "" and Goals.next_up().is_empty() and not Goals.shown(), "Free Play: no chip")
	_fresh("tech")
	_check(Goals.goal() == "OPEN THE COMPUTER AT YOUR DESK", "tech day 1, empty queue: %s" % Goals.goal())
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	_check(Goals.goal() == "CLOSE YOUR FIRST TICKET", "tech day 1 with a ticket: %s" % Goals.goal())
	msp.rmm_action(t.endpoint, "spooler")
	msp.close_ticket(t.id)
	_check(Goals.goal().begins_with("QUEUE CLEAR"), "after the first close: %s" % Goals.goal())
	msp.create_ticket(1, 0, "test")
	msp.create_ticket(2, 1, "test")
	_check(Goals.goal() == "CLEAR THE QUEUE: 2 OPEN", "an open queue: %s" % Goals.goal())
	root.get_node("Playbook").start("rack")
	_check(Goals.goal() == "FINISH THE JOB: RACK RECOVERY", "a big job is the goal: %s" % Goals.goal())
	root.get_node("Playbook").reset()
	_fresh("owner")
	_check(Goals.goal() == root.get_node("Owner").goal_title() and Goals.goal() != "", "owner: %s" % Goals.goal())
	root.get_node("Owner").cash = -50
	_check(Goals.goal() == "GET THE CASH BACK ABOVE ZERO", "owner in the red: %s" % Goals.goal())
	_fresh("service")
	_check(Goals.goal().begins_with("BOARD CLEAR") or Goals.goal().begins_with("KEEP THE BOARD MOVING"), "service: %s" % Goals.goal())
	_fresh("sales")
	_check(Goals.goal().contains(" QUOTA "), "sales: %s" % Goals.goal())

	# ---- next up
	_fresh("tech")
	world.clock = 9.5
	var up := _texts(Goals.next_up())
	_check(up == ["12:00 LUNCH", "17:00 CLOSING TIME"], "a plain morning: %s" % str(up))
	world.clock = 13.0
	_check(_texts(Goals.next_up()) == ["17:00 CLOSING TIME"], "after lunch only closing time is left")
	c.day = 10  # an outing day in the on-call week
	world.clock = 9.5
	up = _texts(Goals.next_up())
	_check(up == ["11:00 XP SUPPORT ENDS", "12:00 LUNCH", "17:00 CLOSING TIME"], "at most three, soonest first: %s" % str(up))
	var long_list: Array = _texts(Goals.next_up(9))
	_check(long_list.size() == 5 and long_list[3] == "AFTER WORK: A TEAM OUTING" and long_list[4] == "TONIGHT: ON CALL", "the outing and on call tonight come after the timed ones: %s" % str(long_list))
	c.day = 4
	world.clock = 9.5
	up = _texts(Goals.next_up())
	_check(up.has("12:12 HOLIDAY POTLUCK") and up.find("12:00 LUNCH") < up.find("12:12 HOLIDAY POTLUCK"), "the season's calendar event is listed at its time: %s" % str(up))
	c.day = 2
	_check(_texts(Goals.next_up(9)).has("NEXT DAY: THE HOLIDAYS"), "a season that starts tomorrow is announced")
	c.day = 3
	_check(not _texts(Goals.next_up(9)).has("NEXT DAY: THE HOLIDAYS"), "but not once it runs")
	world.clock = 17.5
	c.day = 12
	_check(Goals.next_up().is_empty(), "nothing left after closing time on a plain day")
	_fresh("owner")
	world.clock = 9.5
	_check(_texts(Goals.next_up()) == ["17:00 THE BOOKS CLOSE"], "owner week: %s" % str(_texts(Goals.next_up())))
	var all_rows: Array = Goals.rows(20)
	var fits := true
	for row in all_rows:
		fits = fits and str(row).length() <= 20
	_check(fits and all_rows.size() >= 2 and str(all_rows[0]).begins_with("GOAL: "), "rows are cut to the width: %s" % str(all_rows))
	_check(Goals.rows(40, true).size() == 1, "compact (a screen is open): the goal line alone")

	# ---- layout in wide, h and v
	for fmt in ["wide", "h", "v"]:
		game.set_format(fmt)
		await process_frame
		for mode in ["tech", "owner", "service", "sales"]:
			_fresh(mode)
			world.hud_visible = true
			if mode == "tech":
				c.day = 10
				shift.energy = 100.0
				msp.create_ticket(1, 0, "test")
			world.clock = 9.5
			var problems: Array = await _audit("%s %s" % [fmt, mode])
			_check(problems.is_empty(), "%s %s: chip on screen, no overlap %s" % [fmt, mode, str(problems)])
		# the busiest HUD: tech, on call, an outing day, a toast at the bottom
		_fresh("tech")
		c.day = 10
		world.clock = 9.5
		root.get_node("Hints").toast("A LONG TOAST LINE AT THE BOTTOM OF THE SCREEN TO SEE THAT NOTHING COLLIDES", 5.0)
		var problems2: Array = await _audit("%s busy" % fmt)
		_check(problems2.is_empty(), "%s busy day with a toast: no overlap %s" % [fmt, str(problems2)])
		var size := root.get_visible_rect().size
		var canvas := Node2D.new()
		var layer := CanvasLayer.new()
		root.add_child(layer)
		layer.add_child(canvas)
		var rects: Array = []
		canvas.draw.connect(func() -> void: rects.append_array(Goals.draw(canvas, 6)))
		canvas.queue_redraw()
		await process_frame
		await process_frame
		var inside := not rects.is_empty()
		for r in rects:
			inside = inside and Rect2(Vector2.ZERO, size).encloses(r)
		_check(inside, "%s: with six HUD lines on the left the chip is still inside %s (%d rows)" % [fmt, str(size), rects.size()])
		layer.queue_free()
	game.set_format("wide")

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
