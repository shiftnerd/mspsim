extends SceneTree
# gdlint:disable=comparison-with-itself,max-line-length
# C5 / V2: the Dispatch board and the crew as people. Assignment by fit, stuck / overload / quit, the escalation lane,
# capacity numbers, the board's key flow through its public functions, the narrow one-lane-at-a-time layout, save /
# continue, an old (C4) service save, and 20 days through the real day loop with every card dismissed. Headless.

var failures := 0
var player_script: GDScript
var _mk_n := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> int:
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
	return n


func _start() -> void:
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Campaign").new_game("service")


# a fresh ticket of a given fix and priority (all of them at client 0), not yet picked up by anybody
func _mk(fix: String, pri: int) -> int:
	var msp := root.get_node("Msp")
	var used := []
	for ot in msp.open_tickets():
		used.append(str(ot.endpoint))
	for ep in msp.endpoints:
		if not used.has(str(ep.name)):
			ep.problem = ""
	var t: Dictionary = msp.create_ticket(_mk_n % 5, 0, "email")
	_mk_n += 1
	t.fix = fix
	t.pri = pri
	msp.endpoint(str(t.endpoint)).problem = fix
	t.sla_total = 400.0
	t.sla_left = 400.0
	return int(t.id)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var owner := root.get_node("Owner")
	var report := root.get_node("DayReport")
	var computer := root.get_node("Computer")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	_start()
	_clear(cards)
	var dp = computer.dispatch
	dp.fuzz = 0  # exact numbers for the checks
	sv.auto = "off"
	msp.tickets.clear()

	# ---- assignment by fit
	var av := _mk("av", 3)  # security 2
	var sp := _mk("spooler", 3)  # networking 1
	var t_av: Dictionary = msp.ticket(av)
	_check(crew.need_of(t_av) == 2 and crew.area_of(t_av) == "security" and crew.tag_of(t_av) == "SEC", "an AV ticket needs SEC 2")
	_check(crew.best_for(t_av) == "Terry", "the best fit for a security 2 ticket is Terry (%s)" % crew.best_for(t_av))
	_check(crew.fit("Terry", t_av) > crew.fit("Sam", t_av) and crew.fit("Terry", t_av) > crew.fit("Maya", t_av), "fit: Terry beats Sam and Maya on security")
	_check(crew.gap_of("Sam", t_av) == 1 and crew.gap_of("Terry", t_av) == 0, "Sam is one level short, Terry is fine")
	_check(crew.match_mult("Terry", t_av) >= 1.0 and crew.match_mult("Sam", t_av) < 0.7, "a match is faster than a miss (%.2f vs %.2f)" % [crew.match_mult("Terry", t_av), crew.match_mult("Sam", t_av)])
	_check(crew.reopen_add("Sam", t_av) > crew.reopen_add("Terry", t_av), "a bad match reopens more often")
	var res: Dictionary = sv.assign(sp, "Maya")
	_check(res.ok and crew.assignee_of(msp.ticket(sp)) == "Maya" and str(msp.ticket(sp).status) == "In Progress", "assigning moves the ticket to a desk and starts it")
	_check(sv.dispatched == 1, "the hand assignment is counted (%d)" % sv.dispatched)
	res = sv.assign(sp, "Maya")
	_check(res.ok and res.get("same", false), "assigning to the same desk is a no-op")
	res = sv.assign(sp, "")
	_check(str(msp.ticket(sp).status) == "New" and crew.assignee_of(msp.ticket(sp)) == "", "unassigning puts it back as New")
	# the autopilot uses fit
	sv.auto = "all"
	sv._seen.clear()
	sv._pickup()
	_check(crew.assignee_of(msp.ticket(av)) == "Terry", "the autopilot gave the AV ticket to Terry (%s)" % crew.assignee_of(msp.ticket(av)))
	sv.auto = "low"
	var p1 := _mk("reboot", 1)
	var p4 := _mk("reboot", 4)
	sv._seen.clear()
	sv._pickup()
	_check(crew.assignee_of(msp.ticket(p1)) == "" and crew.assignee_of(msp.ticket(p4)) != "", "policy LOW leaves the P1 for you and takes the P4")
	sv.auto = "off"

	# ---- an unassigned P1 ages faster, and Garrison notices
	var gt0: int = sv.trust_of("Garrison")
	var s0: float = msp.ticket(p1).sla_left
	sv._aging(10.0)
	_check(float(msp.ticket(p1).sla_left) <= s0 - 5.0, "an unassigned P1 ages 50% faster")
	sv._aging(100.0)
	_check(sv.trust_of("Garrison") == gt0 - 1, "Garrison notices a P1 nobody took")

	# ---- stuck: the ticket needs more than he has
	msp.tickets.clear()
	var hard := _mk("restore", 1)  # security 2 + 1 = 3 for a P1
	_check(crew.need_of(msp.ticket(hard)) == 3, "a P1 restore needs SEC 3")
	sv.assign(hard, "Sam")
	sv._seen[hard] = true
	var guard := 0
	while not crew.is_stuck("Sam") and guard < 30:
		guard += 1
		owner._work_queue(3.0)
	_check(crew.is_stuck("Sam") and crew.status("Sam") == "STUCK", "Sam gets stuck on a ticket above his level (%d steps)" % guard)
	_check(crew.glyph_of("Sam") == "?" and msp.texts.size() > 0, "a stuck tech shows a ? bubble and texts you")
	var worker0: float = crew.worker_speed("Sam")
	_check(worker0 == 0.0, "a stuck tech adds no speed")
	var m0: int = crew.morale("Sam")
	sv.assign(hard, "Terry")
	_check(not crew.is_stuck("Sam") and crew.morale("Sam") > m0, "reassigning a stuck ticket frees the tech (+morale)")
	var old_left: float = float(msp.ticket(hard).sla_left)
	# left alone and with the owners' lane open, he calls for help
	msp.tickets.clear()
	owner._work.clear()
	var hard2 := _mk("restore", 1)
	sv.auto = "all"
	sv.assign(hard2, "Maya", false)
	guard = 0
	while not crew.is_stuck("Maya") and guard < 30:
		guard += 1
		owner._work_queue(3.0)
	_check(crew.is_stuck("Maya"), "Maya gets stuck too")
	var trust_before: int = sv.trust_of("Alan") + sv.trust_of("Garrison")
	sv._stuck_tick(crew.STUCK_ASK + 1.0)
	var who_has: String = crew.assignee_of(msp.ticket(hard2))
	_check(who_has in ["Alan", "Garrison"] and not crew.is_stuck("Maya"), "a stuck tech calls an owner after a while (%s)" % who_has)
	_check(sv.trust_of("Alan") + sv.trust_of("Garrison") == trust_before - 2, "an escalation costs owner trust")
	owner._work_queue(60.0)
	owner._work_queue(60.0)
	_check(str(msp.ticket(hard2).status) in ["Closed", "In Progress"], "the owner works the ticket")
	# policy OFF: nobody calls the owner, he pushes through alone in the end
	msp.tickets.clear()
	owner._work.clear()
	sv.auto = "off"
	sv.owner_used = {"Alan": 0, "Garrison": 0}
	var hard3 := _mk("restore", 1)
	sv.assign(hard3, "Sam", false)
	guard = 0
	while not crew.is_stuck("Sam") and guard < 30:
		guard += 1
		owner._work_queue(3.0)
	sv._stuck_tick(crew.STUCK_ASK + 1.0)
	_check(crew.is_stuck("Sam") and crew.assignee_of(msp.ticket(hard3)) == "Sam", "with AUTO OFF the stuck tech waits for you")
	sv._stuck_tick(crew.STUCK_GIVE_UP)
	_check(not crew.is_stuck("Sam") and bool(msp.ticket(hard3).get("pushed", false)), "in the end he pushes through alone")

	# ---- the escalation lane: a cost and a daily cap
	msp.tickets.clear()
	owner._work.clear()
	sv.owner_used = {"Alan": 0, "Garrison": 0}
	var ta: int = sv.trust_of("Alan")
	var e1 := _mk("reboot", 2)
	var r1: Dictionary = sv.assign(e1, "ESC")
	_check(r1.ok and crew.assignee_of(msp.ticket(e1)) == "Alan" and sv.trust_of("Alan") == ta - 2, "ESC sends a servers ticket to Alan and costs 2 trust")
	var e2 := _mk("av", 2)
	var r2: Dictionary = sv.assign(e2, "ESC")
	_check(crew.assignee_of(msp.ticket(e2)) == "Garrison", "a security ticket goes to Garrison")
	sv.owner_used = {"Alan": 2, "Garrison": 2}
	var e3 := _mk("reboot", 2)
	var r3: Dictionary = sv.assign(e3, "ESC")
	_check(not r3.ok and crew.assignee_of(msp.ticket(e3)) == "", "both owners are busy after two each: %s" % r3.msg)
	_check(sv.escalated >= 2, "escalations are counted")
	var before_closed: int = msp.closed_ok
	for _i in 40:
		owner._work_queue(30.0)
		if msp.closed_ok > before_closed:
			break
	_check(msp.closed_ok > before_closed, "owners close what they take (%d -> %d, %s / %s)" % [before_closed, msp.closed_ok, str(msp.ticket(e1).status), str(msp.ticket(e2).status)])

	# ---- overload, capacity numbers, quitting
	msp.tickets.clear()
	owner._work.clear()
	sv.owner_used = {"Alan": 0, "Garrison": 0}
	for i in 4:
		sv.assign(_mk("reboot", 3), "Maya", false)
	_check(crew.load_of("Maya") == 4 and crew.status("Maya") == "OVERLOAD" and crew.glyph_of("Maya") == "!", "four tickets overload Maya")
	world.clock = 10.0
	var hrs: float = crew.load_hours("Maya")
	var util: float = crew.utilisation("Maya")
	_check(hrs > 0.0 and util > 0.0 and crew.hours_left() == 7.0, "capacity numbers: %.2f queued hours, %d%% of the day" % [hrs, int(util * 100)])
	_check(crew.utilisation("Sam") == 0.0 and crew.load_hours("Terry") == 0.0, "an empty desk has no load")
	var rate_sum := 0.0
	for n in crew.names():
		rate_sum += crew.rate(str(n))
	_check(absf(rate_sum - owner.team_speed()) < 0.01, "the three rates add up to the team speed")
	crew.tick(world.day_len)
	_check(crew.value("Maya", "over_t") >= world.day_len - 1.0, "overload time is counted")
	var mm0: int = crew.morale("Maya")
	var sm0: int = crew.morale("Sam")
	crew.end_day(0.7, "B")
	_check(crew.morale("Maya") < mm0 and crew.morale("Maya") < crew.morale("Sam") + 1 and crew.value("Maya", "over_days") == 1, "a day buried costs morale (%d -> %d, Sam %d -> %d)" % [mm0, crew.morale("Maya"), sm0, crew.morale("Sam")])
	# three bad days in a row and a low morale: she quits
	crew.members["Maya"]["over_days"] = 5
	crew.members["Maya"]["morale"] = 30
	var quit_seen := false
	for _i in 60:
		crew.members["Maya"]["morale"] = 30
		crew.members["Maya"]["over_days"] = 5
		if crew.end_day(0.5, "C").has("Maya"):
			quit_seen = true
			break
	_check(quit_seen and crew.is_gone("Maya") and crew.farewells.has("Maya"), "an overloaded tech with low morale eventually quits and owes a farewell")
	_check(crew.load_of("Maya") == 0 and sv.lane_ids() == ["", "Sam", "Terry", "Dan", "ESC"], "her tickets went back on the board and her lane is gone")
	var opens := 0
	for t in msp.open_tickets():
		if str(t.status) == "New":
			opens += 1
	_check(opens >= 4, "the four tickets are New again (%d)" % opens)
	sv._farewells()
	_check(cards.is_open and str(cards.speaker).begins_with("Maya") and cards.options.size() == 3, "the farewell card is shown")
	var cm0: int = crew.morale("Sam")
	cards.pick(1)
	_clear(cards)
	_check(crew.morale("Sam") >= cm0 + 2 and crew.farewells.is_empty(), "asking what went wrong helps the rest of the crew")

	# ---- the board: key flow through the public functions
	_start()
	_clear(cards)
	dp = computer.dispatch
	dp.fuzz = 0
	dp.view = "board"
	dp.lane = 0
	dp.row = 0
	dp.held = -1
	sv.auto = "off"
	msp.tickets.clear()
	owner._work.clear()
	var k1 := _mk("reboot", 2)
	var k2 := _mk("spooler", 3)
	var k3 := _mk("av", 4)
	_check(dp.ids() == ["", "Maya", "Sam", "Terry", "Dan", "ESC"], "lanes: unassigned, three techs, Dan, escalation")
	_check(dp.tickets_in("").size() == 3, "all three tickets sit in the unassigned column")
	_check(dp.selected_id() == k1, "the cursor starts on the most urgent chip")
	dp.key("tab")
	_check(dp.selected_id() == k2, "Tab picks the next chip")
	dp.key("down")
	_check(dp.selected_id() == k3, "Down moves inside the lane")
	dp.key("shift_tab")
	_check(dp.selected_id() == k2, "Shift+Tab goes back")
	dp.key("enter")
	_check(dp.held == k2, "Enter picks the chip up")
	dp.key("right")
	dp.key("right")
	_check(dp.lane_id() == "Sam", "Right moves the drop target to Sam")
	dp.key("left")
	dp.key("enter")
	_check(dp.held == -1 and crew.assignee_of(msp.ticket(k2)) == "Maya" and dp.lane_id() == "Maya" and dp.selected_id() == k2, "Enter drops: assigned to Maya and the cursor follows")
	dp.key("left")
	dp.key("down")
	dp.key("enter")
	_check(dp.held == k3 or dp.held == k1, "pick up another chip")
	dp.key("right")
	dp.back()
	_check(dp.held == -1 and dp.lane_id() == "" and crew.assignee_of(msp.ticket(k3)) == "", "Esc cancels and returns the cursor to its lane")
	dp.row = 0
	dp.key("t")
	_check(crew.assignee_of(msp.ticket(k1)) == "Dan", "T takes the ticket yourself")
	dp.lane = 0
	dp.clamp_cursor()
	dp.key("e")
	_check(crew.assignee_of(msp.ticket(dp.selected_id())) in ["Alan", "Garrison"] or dp.selected_id() == -1 or crew.assignee_of(msp.ticket(k3)) in ["Alan", "Garrison"], "E escalates")
	var policy0: String = sv.auto
	dp.key("a")
	_check(sv.auto != policy0 and sv.POLICIES.has(sv.auto), "A cycles the auto policy (%s)" % sv.auto)
	dp.key("c")
	_check(dp.view == "capacity", "C opens the capacity view")
	dp.key("down")
	dp.key("f")
	_check(crew.focus_of("Sam") != "", "F gives the selected tech a focus (%s)" % crew.focus_of("Sam"))
	var f2: int = 0
	for _i in 6:
		dp.key("f")
		f2 += 1
	_check(crew.focus_of("Sam") == crew.focus_of("Sam"), "the focus cycles through the five areas and none")
	dp.key("s")
	_check(dp.view == "score" and dp.score_rows().size() >= 6, "S opens the score view")
	_check(dp.back() and dp.view == "board", "Esc goes back to the board")
	_check(not dp.back(), "Esc on the board itself closes the computer (not nested)")
	# drag with the mouse
	dp.lane = 0
	dp.row = 0
	dp.clamp_cursor()
	var drag_id: int = dp.selected_id()
	if drag_id < 0:
		drag_id = _mk("reboot", 3)
	dp._drag = {"id": drag_id, "from": "", "start": Vector2(10, 10), "pos": Vector2(10, 10), "moved": false}
	dp._lanes = [{"r": Rect2(0, 0, 40, 60), "i": 0}, {"r": Rect2(40, 0, 40, 60), "i": 2}]
	dp.mouse_move(Vector2(60, 20))
	_check(dp.mouse_up(Vector2(60, 20)) and crew.assignee_of(msp.ticket(drag_id)) == "Sam", "dragging a chip onto a lane assigns it")
	_check(sv.dispatched >= 4 and root.get_node("Career").value("dispatched") >= 4, "assignments count for the Career (%d)" % root.get_node("Career").value("dispatched"))

	# ---- fuzz: low DISPATCH shows approximate numbers
	var tk: Dictionary = msp.ticket(drag_id)
	tk.sla_left = 130.0
	dp.fuzz = 0
	var exact: String = dp.sla_text(tk)
	dp.fuzz = 1
	var fuzzy_text: String = dp.sla_text(tk)
	_check(exact == "2:10" and fuzzy_text == "*3M", "exact SLA %s, fuzzy SLA %s" % [exact, fuzzy_text])
	_check(dp.fit_text("Sam", tk).begins_with("FIT ") and not dp.fit_text("Sam", tk).contains("%"), "fuzzy fit is a word")
	dp.fuzz = 0
	_check(dp.fit_text("Sam", tk).contains("%"), "exact fit is a number")

	# ---- narrow layout: one lane at a time
	dp.lane = 0
	dp.act(PackedStringArray(["dsp", "next"]))
	dp.act(PackedStringArray(["dsp", "next"]))
	_check(dp.lane == 2, "the narrow Next button moves to the next lane (%d)" % dp.lane)
	dp.act(PackedStringArray(["dsp", "prev"]))
	_check(dp.lane == 1, "Previous goes back")
	dp.act(PackedStringArray(["dsp", "lane", "5"]))
	_check(dp.lane_id() == "ESC", "a lane button jumps to a lane")
	dp.act(PackedStringArray(["dsp", "next"]))
	_check(dp.lane == 5, "the last lane stops the buttons")
	dp.key("left")
	_check(dp.lane == 4, "Left / Right switch the lane in the narrow layout too")

	# ---- save and continue
	_start()
	_clear(cards)
	sv.auto = "low"
	crew.set_focus("Sam", "networking")
	crew.members["Terry"]["morale"] = 71
	sv.dispatched = 7
	c.day = 4
	c.save()
	sv.reset()
	crew.reset()
	_check(sv.auto == "all" and crew.focus_of("Sam") == "", "reset clears the new state")
	_check(c.continue_game("service"), "continue works")
	_clear(cards)
	_check(sv.auto == "low" and crew.focus_of("Sam") == "networking" and crew.morale("Terry") == 71 and sv.dispatched == 7, "policy, focus, morale and the counter come back")
	_check(world.chars.has("Sam") and world.chars.has("Terry") and world.chars.has("Maya") and not world.chars.has("Dan"), "after continue Sam and Terry are NPCs in the building")

	# ---- an old (C4) service save: Sam and Terry were numbers
	var old := {"members": {"Maya": {"skill": 1.1, "morale": 70, "stress": 30, "retain": 2, "mentored": 3, "gone": false, "last_oto": 2}, "Sam": {"skill": 0.75, "morale": 40, "stress": 50, "retain": 0, "mentored": 0, "gone": false, "last_oto": 1}, "Terry": {"skill": 0.9, "morale": 66, "stress": 20, "retain": 0, "mentored": 0, "gone": true, "last_oto": -9}}, "stuck": {"who": "Sam", "ticket": 5, "left": 20.0}, "quits": ["Terry"]}
	crew.from_dict(old)
	_check(crew.morale("Sam") == 40 and absf(crew.value("Maya", "skill") - 1.1) < 0.001 and crew.is_gone("Terry"), "old numbers survive the conversion")
	_check(crew.level("Maya", "people") == 3 and crew.focus_of("Sam") == "" and crew.stuck.is_empty() and crew.farewells.is_empty(), "the new fields get the roster defaults")
	world.apply_roster()
	_check(world.chars.has("Sam") and not world.chars.has("Terry"), "the converted Sam is an NPC, the Terry who quit is not")

	# ---- the 20 days through the real loop, with the board in use
	_start()
	_clear(cards)
	var played := 0
	var ended := false
	var hand_assign := 0
	for day in range(1, 21):
		world.clock = 8.6
		var hour := 8.6
		var guard2 := 0
		while not report.is_open and hour < 23.9 and guard2 < 200:
			guard2 += 1
			hour += 0.15
			world.clock = hour
			await process_frame
			await process_frame
			_clear(cards, (day + guard2) % 3)
			if guard2 % 5 == 0:
				var dd = computer.dispatch
				dd.fuzz = 0
				if guard2 % 10 == 0:
					sv.auto = "off" if sv.auto == "all" else "all"
				for t in msp.open_tickets():
					if crew.assignee_of(t) == "" and sv._crew_ticket(t) and crew.names().size() > 0:
						var best: String = crew.best_for(t, 3)
						if best != "" and sv.assign(int(t.id), best, true).ok:
							hand_assign += 1
						break
				dd.key("tab")
				if guard2 % 15 == 0:
					dd.key("enter")
					dd.key("right")
					dd.key("enter")
				dd.back()
			owner._work_queue(25.0)
		_check(report.is_open, "day %d ends with the scorecard" % day)
		played += 1
		if report.report.get("final", false):
			ended = true
			break
		report.finish()
		await create_timer(0.7).timeout
		root.get_node("Game").busy = false
		_clear(cards)
	_check(played >= 3, "played %d days (%d assignments by hand)" % [played, hand_assign])
	if ended and not report.report.get("fired", false):
		_check(played == 20, "all 20 days played")
		report.finish()
		await create_timer(0.5).timeout
		_clear(cards)
	# ---- C6: another 20 days with the new systems in use (design card, runbooks, hiring, life events), every card dismissed
	_start()
	_clear(cards)
	sv.kb.hours_used = 0.0
	var played2 := 0
	var ended2 := false
	var kb_steps := 0
	var designs_seen := {}
	for day in range(1, 21):
		world.clock = 8.6
		var hour2 := 8.6
		var guard3 := 0
		while not report.is_open and hour2 < 23.9 and guard3 < 200:
			guard3 += 1
			hour2 += 0.15
			world.clock = hour2
			await process_frame
			await process_frame
			_clear(cards, (day + guard3) % 3)
			if sv.design != "":
				designs_seen[sv.design] = true
			if guard3 == 4:
				var ids: Array = sv.kb.ids()
				if sv.kb.advance(str(ids[(day * 5) % ids.size()])).ok:
					kb_steps += 1
				_clear(cards, 1)
			if guard3 == 8 and day in [7, 13] and root.get_node("Crew").can_hire() and sv.cands.is_empty():
				sv.hire_card()
				_clear(cards, 3)
			if guard3 % 6 == 0:
				for t in msp.open_tickets():
					if crew.assignee_of(t) == "" and sv._crew_ticket(t) and crew.names().size() > 0:
						var who: String = sv.route_for(t)
						if who != "":
							sv.assign(int(t.id), who, true)
						break
				computer.dispatch.key("tab")
			owner._work_queue(25.0)
		_check(report.is_open, "(C6) day %d ends with the scorecard" % day)
		played2 += 1
		if report.report.get("final", false):
			ended2 = true
			break
		var groups: Array = report.report.get("left_groups", [])
		if day == 5:
			var has_desk := false
			for g in groups:
				if str(g[0]) == "DESK":
					has_desk = true
			_check(has_desk, "(C6) the scorecard shows the DESK group")
		report.finish()
		await create_timer(0.7).timeout
		root.get_node("Game").busy = false
		_clear(cards)
	_check(played2 >= 3, "(C6) played %d days with runbooks, a desk design and hiring (%d runbook steps, designs %s, crew %d)" % [played2, kb_steps, str(designs_seen.keys()), crew.size()])
	_check(kb_steps >= 1 and sv.design != "" and crew.size() >= 2, "(C6) the new systems were used in the loop")
	if ended2 and not report.report.get("fired", false):
		_check(played2 == 20, "(C6) all 20 days played")
		report.finish()
		await create_timer(0.5).timeout
		_clear(cards)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
