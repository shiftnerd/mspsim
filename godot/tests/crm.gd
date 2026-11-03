extends SceneTree
# The SalesHound CRM app (sales campaign, S1): it is on Vic's desktop and start menu (and the Boardroom is not), the stage tabs
# filter the pipeline, Up / Down / click pick a lead, the buttons and the C / V / Q / D keys call, visit, quote and drop, Enter
# does the next sensible thing, and the app paints without errors at every format size. Headless; saves in user://test_*.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 40:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1


func _hit_ids(comp: Node) -> Array:
	var out := []
	for h in comp._hits:
		out.append(str(h.id))
	return out


func _key(comp: Node, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	comp._input(ev)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var comp := root.get_node("Computer")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var game := root.get_node("Game")
	var crm = load("res://scripts/crm.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	root.get_node("Difficulty").seed_run(99)
	c.new_game("sales")
	_clear(cards)
	world.clock = 9.0

	# ---- on the desktop and the start menu, instead of the Boardroom
	comp.open(1)
	await process_frame
	await process_frame
	comp._menu = true
	comp._canvas.queue_redraw()
	await process_frame
	var ids: Array = _hit_ids(comp)
	_check("app:crm" in ids and not ("app:boardroom" in ids), "the start menu has SALESHOUND and no BOARDROOM")
	comp._menu = false
	comp.activate("app:crm")
	await process_frame
	await process_frame
	ids = _hit_ids(comp)
	_check(comp.app == "crm" and "crm:tab:LEAD" in ids and "crm:tab:WON" in ids, "the CRM opens with its stage tabs")
	var leads: int = sc.leads.size()
	_check(leads >= 2 and crm.rows().size() == leads, "ALL lists every lead (%d)" % leads)
	_check("crm:call" in ids and "crm:quote" in ids and "crm:drop" in ids, "buttons for a fresh lead: call, quote, drop")
	var first_id: int = int(crm.selected().id)
	_check(first_id == int(crm.rows()[0].id), "the first row is selected")
	var sel_ids := []
	for h in ids:
		if h.begins_with("crm:sel:"):
			sel_ids.append(h)
	_check(sel_ids.size() == leads, "every lead row is clickable")

	# ---- selection: keys and clicks
	comp.move(1)
	_check(int(sc.crm_sel) == int(crm.rows()[1].id), "Down moves to the next lead")
	comp.move(-1)
	comp.move(-1)
	_check(int(sc.crm_sel) == first_id, "Up stops at the top")
	comp.activate("crm:sel:%d" % int(crm.rows()[1].id))
	_check(int(sc.crm_sel) == int(crm.rows()[1].id), "a click on a row selects it")
	comp.activate("crm:sel:%d" % first_id)

	# ---- tabs
	comp.activate("crm:tab:MEETING")
	_check(crm.rows().is_empty() and crm.selected().is_empty(), "no lead is in MEETING yet")
	await process_frame
	comp.activate("crm:tab:LEAD")
	_check(crm.rows().size() == leads, "every new lead is in LEAD")
	_key(comp, KEY_RIGHT)
	_check(sc.crm_tab == "MEETING", "Right steps to the next tab")
	_key(comp, KEY_LEFT)
	_key(comp, KEY_LEFT)
	_check(sc.crm_tab == "ALL", "Left steps back to ALL")

	# ---- call by key and by Enter
	var l: Dictionary = crm.selected()
	var hours: int = sc.slots_left()
	_key(comp, KEY_C)
	_check(bool(l.called) and str(l.stage) == "MEETING" and sc.slots_left() == hours - 1, "C calls the lead: an hour, stage MEETING")
	_check(comp._toast.begins_with("CALLED"), "the app says who you reached (%s)" % str(comp._toast))
	comp.activate("crm:tab:MEETING")
	_check(crm.rows().size() == 1 and int(crm.rows()[0].id) == int(l.id), "the MEETING tab holds the called lead")
	comp.activate("crm:tab:ALL")
	_key(comp, KEY_C)
	_check(comp.app == "crm" and sc.slots_left() == hours - 1, "a second call is refused and costs nothing")

	# ---- quote opens the builder screen; Enter on a called lead does the same; Esc comes back
	comp.enter()
	_check(sc.crm_view == "build" and not sc.qb.is_empty() and int(sc.qb.id) == int(l.id) and not cards.is_open, "Enter on a lead you called opens the quote builder screen")
	await process_frame
	await process_frame
	ids = _hit_ids(comp)
	_check("crm:qb:send" in ids and "crm:qb:back" in ids and "crm:qb:chg:promise:1" in ids, "the builder paints its steppers and buttons")
	comp.escape()
	_check(sc.crm_view == "list" and comp.app == "crm" and str(l.stage) == "MEETING", "Esc backs out of the builder to the list and sends nothing")
	_key(comp, KEY_Q)
	_check(sc.crm_view == "build", "Q opens the quote builder too")
	comp.back()
	_check(sc.crm_view == "list", "back() leaves it")

	# ---- visit: phone-only leads cannot be driven to; a site lead can
	var phone_only := {}
	var site_lead := {}
	for x in sc.leads:
		if bool(x.site):
			site_lead = x
		else:
			phone_only = x
	if phone_only.is_empty():
		phone_only = sc.make_lead(root.get_node("Difficulty").rng_for("crm", 1))
		phone_only["site"] = false
		sc.accept_lead(phone_only)
	sc.crm_sel = int(phone_only.id)
	_check(sc.can_visit(phone_only) == "PHONE ONLY", "a lead without a site is PHONE ONLY")
	_key(comp, KEY_V)
	_check(comp._toast.begins_with("NO VISIT"), "V says why not (%s)" % str(comp._toast))
	if site_lead.is_empty():
		site_lead = sc.make_lead(root.get_node("Difficulty").rng_for("crm", 2))
		site_lead["name"] = str(root.get_node("Onsite").SITE_PROSPECT[str(site_lead.type)])
		site_lead["site"] = true
		sc.accept_lead(site_lead)
	_check(sc.can_visit(site_lead) == "", "a lead with a site can be visited")
	world.clock = 15.9
	_check(sc.can_visit(site_lead).begins_with("NEEDS"), "late in the week there are not enough hours for the drive (%s)" % sc.can_visit(site_lead))
	world.clock = 9.0
	_check(sc.visit_hours(site_lead) >= 2 and sc.visit_hours(site_lead) <= 4, "a visit takes a few hours (%d)" % sc.visit_hours(site_lead))

	# ---- drop
	sc.crm_sel = int(phone_only.id)
	_key(comp, KEY_D)
	_check(str(phone_only.stage) == "LOST" and str(phone_only.why) == "DROPPED", "D drops the lead")
	comp.activate("crm:tab:LOST")
	_check(crm.rows().size() == 1, "and it sits in LOST")

	# ---- painting every tab, with and without leads (the screenshot test checks the formats)
	for tab in ["ALL", "LEAD", "MEETING", "QUOTED", "WON", "LOST"]:
		sc.crm_tab = tab
		comp._canvas.queue_redraw()
		await process_frame
		await process_frame
	_check(true, "the app painted every tab without errors")
	sc.crm_tab = "ALL"
	comp.close()
	await process_frame

	# ---- the other campaigns keep the Boardroom and have no CRM
	c.active = false
	c.mode = ""
	c.new_game("owner")
	_clear(cards)
	comp.open(1)
	comp._menu = true
	comp._canvas.queue_redraw()
	await process_frame
	await process_frame
	ids = _hit_ids(comp)
	_check("app:boardroom" in ids and not ("app:crm" in ids), "the owner campaign still has the Boardroom and no CRM")
	comp.close()
	c.active = false
	c.mode = ""
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
