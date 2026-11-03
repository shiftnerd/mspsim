extends SceneTree
# The mode registry (X8, "P0b"): Campaign.MODE_DEFS rows, the three gates crew / books / cards, identical behaviour for
# tech, owner and sales (C1), the planned service mode present but not selectable, and no call site left on the old
# Owner.active() gate. Headless; saves in user://test_*.

var failures := 0

const PROPS := [
	"label", "selectable", "crew", "books", "cards", "books_lite", "day_len", "total_days", "unit", "hud", "report",
	"review", "review_heading", "review_pages", "pace", "shift", "scars", "maya_in_events", "ending_fired", "ending_final",
]


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _gates(c: Node) -> Array:
	return [c.crew_active(), c.books_active(), c.cards_active()]


func _scripts_text() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://scripts")
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out[f] = FileAccess.get_file_as_string("res://scripts/" + f)
	return out


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var pr := root.get_node("Projects")
	var pa := root.get_node("Partner")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- the registry rows
	var defs: Dictionary = c.MODE_DEFS
	_check(defs.keys() == ["tech", "owner", "service", "sales"], "four registered modes: " + str(defs.keys()))
	var complete := true
	for m in defs:
		for p in PROPS:
			if not defs[m].has(p):
				complete = false
				print("     missing %s.%s" % [m, p])
	_check(complete, "every row carries every property")
	var sel := {}
	for m in defs:
		if defs[m].selectable:
			sel[m] = defs[m].label
	_check(sel == c.MODES, "MODES lists exactly the selectable rows")
	_check(
		_row_gates(defs.tech) == [false, false, false]
		and _row_gates(defs.owner) == [true, true, true]
		and _row_gates(defs.service) == [true, false, true]
		and _row_gates(defs.sales) == [true, true, true] and defs.sales.books_lite and not defs.owner.books_lite,
		"gate rows: tech none, owner all, service crew+cards, sales crew+books(lite)+cards"
	)
	_check(
		defs.tech.day_len == 600.0 and defs.owner.day_len == 240.0 and defs.service.day_len == 360.0
		and defs.sales.day_len == 240.0 and defs.tech.total_days == c.TOTAL_DAYS and defs.owner.total_days == c.TOTAL_DAYS,
		"day length and campaign length per mode"
	)
	_check(
		defs.tech.hud == "day_rep" and defs.owner.hud == "week_cash" and defs.tech.report == "day"
		and defs.owner.report == "pnl" and defs.tech.review == "yearly" and defs.owner.review == "board"
		and defs.owner.review_pages == 3 and defs.tech.review_pages == 2,
		"HUD, report and review types"
	)
	_check(
		defs.sales.hud == "week_quota" and defs.sales.report == "pnl" and defs.sales.settle == "sales" and defs.sales.review == "sales"
		and defs.sales.review_pages == 2 and defs.sales.selectable and not defs.service.selectable,
		"sales: HUD, report, settle and review types; service still planned"
	)
	_check(
		defs.owner.pace == 0.6 and defs.tech.pace == 1.0 and not defs.owner.maya_in_events and defs.tech.maya_in_events
		and defs.owner.unit == "WEEK" and defs.tech.unit == "DAY",
		"ticket pace, Maya in events, unit label"
	)

	# ---- outside a campaign every gate is closed
	_check(_gates(c) == [false, false, false] and c.mode_def().is_empty(), "no mode: all gates closed")
	c.new_game(c.FREE)
	_check(_gates(c) == [false, false, false] and not c.active, "Free Play: all gates closed")

	# ---- tech: what Owner.active() implied (false) at every call-site category
	c.new_game("tech")
	_check(c.active and c.mode == "tech" and world.day_len == 600.0 and msp.pace == 1.0, "tech: 600 s days, pace 1.0")
	_check(_gates(c) == [false, false, false], "tech: crew, books and cards all closed (old active() false)")
	_check(o.issue_mult() == 1.0 and o.client_weight(0) == 1.0, "tech, crew sites: ticket volume and scope creep are neutral")
	var deals: int = o.vic_deals
	o.on_deal("client", 0)
	_check(o.vic_deals == deals and o.vic_extra() == 0.0, "tech, books sites: no commission, no Vic bonus")
	_check(not pr.active() and not pa.active(), "tech, books and cards sites: Projects and Partner are off")
	_check(o.edge("issues") == o.DEFAULT_EDGE["issues"], "tech, cards site: the profile edge is the default")
	_check(c.prop("hud", "") == "day_rep" and c.total_days() == 20, "tech: HUD type and length from the registry")

	# ---- owner: what Owner.active() implied (true)
	c.new_game("owner")
	_check(c.active and c.mode == "owner" and world.day_len == 240.0 and msp.pace == 0.6, "owner: 240 s weeks, pace 0.6")
	_check(_gates(c) == [true, true, true], "owner: crew, books and cards all open (old active() true)")
	_check(pr.active() and pa.active(), "owner, books and cards sites: Projects and Partner are on")
	deals = o.vic_deals
	o.on_deal("client", 0)
	_check(o.vic_deals == deals + 1, "owner, books site: a deal pays the commission")
	_check(
		o.edge("issues") == float(o.edges_for(c.player_as)["issues"]), "owner, cards site: the profile edge applies"
	)
	_check(c.prop("hud", "") == "week_cash" and c.prop("report", "") == "pnl", "owner: HUD and report type from the registry")
	# the same owner run must be identical whatever the gate: a week of the crew working the queue
	_check(o.team_speed() > 0.0, "owner: the crew has a work rate")

	# ---- planned modes are present but cannot be started, chosen or saved
	var was_mode: String = c.mode
	c.active = false
	c.mode = ""
	for m in ["service"]:
		c.new_game(m)
		_check(not c.active and c.mode == "", "%s: new_game refuses a planned mode" % m)
		_check(not c.continue_game(m), "%s: continue_game refuses a planned mode" % m)
		_check(c.is_planned(m) and not c.is_selectable(m), "%s: registered, not selectable" % m)
		_check(not c.MODES.has(m), "%s: not in the menu list" % m)
		var cs := load("res://scripts/charselect.gd")
		var sel_screen = cs.new()
		_check(sel_screen.choices(m).is_empty(), "%s: character select offers nobody" % m)
		sel_screen.free()
	# a planned mode forced on by mistake still never reaches a save file
	c.active = true
	c.mode = "service"
	var gates_service := _gates(c)
	c.save()
	_check(not c.has_save("service"), "a planned mode is never saved")
	c.mode = "sales"
	var gates_sales := _gates(c)  # sales became selectable in C1 (tests/sales_campaign.gd covers its saves)
	c.active = false
	c.mode = ""
	_check(gates_service == [true, false, true] and gates_sales == [true, true, true], "service / sales gates read their rows")
	c.mode = was_mode

	# ---- no call site left on the old gate (generated scripts and the generator)
	var texts := _scripts_text()
	var hits: Array = []
	for f in texts:
		var t: String = texts[f]
		if t.contains("Owner.active(") or t.contains("owner.active("):
			hits.append(f)
	_check(hits.is_empty(), "no script calls Owner.active(): " + str(hits))
	_check(not texts["owner.gd"].contains("func active()"), "Owner no longer defines active()")
	var gen := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../tools/make_godot.py"))
	if gen != "":
		_check(not gen.contains("Owner.active(") and not gen.contains("owner.active("), "make_godot.py has no Owner.active() either")
		_check(gen.contains("MODE_DEFS") and gen.contains("func crew_active()"), "make_godot.py carries the registry")

	c.active = false
	c.mode = ""
	print("modes: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _row_gates(row: Dictionary) -> Array:
	return [row.crew, row.books, row.cards]
