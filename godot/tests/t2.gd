extends SceneTree
# T2: tech campaign fixes. `-- curve` prints only the reputation-by-day curves.

var failures := 0
var seen := {}
var kind := "good"


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0 if kind == "careless" else cards.options.size() - 1)
		guard += 1


func _best(pb: Node) -> int:
	var step: Dictionary = pb.current_step()
	var best := -1
	var best_pts := -1
	for i in step.choices.size():
		var ch: Dictionary = step.choices[i]
		if pb.lock_reason(ch) == "" and int(ch.pts) > best_pts:
			best_pts = int(ch.pts)
			best = i
	return best


func _work(msp: Node, pb: Node, day: int) -> void:
	var careful: bool = kind == "good" or (kind == "mixed" and day % 2 == 0)
	if msp.day_cap() > 50 and not seen.has("ticket"):
		msp._random_ticket("test")
	if careful:
		for client in msp.backups.size():
			msp.backup_rerun(client)  # a good tech keeps the backups green
		while pb.is_active():
			pb.choose(_best(pb))
		if not msp.project.is_empty() and not msp.project.done:
			msp.project_ask()
			msp.project_scan(true)
			msp.project_backup()
			msp.project_select_all()
			msp.project_migrate()
			msp.project_verify()
			msp.project_select_all()
			msp.project_migrate()
			msp.project_handover()
	elif pb.is_active() and kind == "careless":
		while pb.is_active():
			pb.choose(0)
	for t in msp.open_tickets():
		seen[str(t.special) if t.special != "" else "ticket"] = true
		if careful:
			if not t.fix_done and t.fix != "project" and t.fix != "network":
				msp.rmm_action(str(t.endpoint), str(t.fix))
			if t.fix_done:
				msp.close_ticket(int(t.id))
		elif t.pri >= 3 or kind == "careless":
			msp.close_ticket(int(t.id))  # closed without fixing
		else:
			t.sla_left = 0.0  # an unworked P1 or P2 runs out its clock (the test is faster than the SLA)


# returns the reputation after each report
func _run(mode: String, seed_value: int) -> Array:
	kind = mode
	seen = {}
	seed(seed_value)
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var report := root.get_node("DayReport")
	var pb := root.get_node("Playbook")
	var sk := root.get_node("Skills")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	sk.ps_level = 5
	for key in ["networking", "servers", "security", "people"]:
		sk.xp[key] = 200
	var reps := []
	for day in range(1, 21):
		world.clock = 8.6
		var hour := 8.6
		var guard := 0
		while not report.is_open and hour < 23.9:
			hour += 0.25
			world.clock = hour
			await process_frame
			await process_frame
			_drain(cards)
			_work(msp, pb, day)
		reps.append(int(report.report.get("rep", -1)))
		if OS.get_cmdline_user_args().has("verbose"):
			var rr: Dictionary = report.report
			print("  d%d %s closed=%d missed=%d reo=%d open=%d delta=%d rep=%d scars=%d mood=%d" % [day, kind, rr.closed, rr.missed, rr.reopened, rr.open_left, rr.rep_delta, rr.rep, c.scars, rr.clients])
		var fired: bool = bool(report.report.get("fired", false))
		report.finish()
		await create_timer(0.7).timeout
		root.get_node("Game").busy = false
		if fired or day == 20:
			break
	var rev := root.get_node("Review")
	if rev.is_open:
		rev.finish()
		await create_timer(0.3).timeout
	return reps


func _unit() -> void:
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var pb := root.get_node("Playbook")
	var story := root.get_node("Story")
	var cards := root.get_node("Cards")
	var shift := root.get_node("Shift")
	var review := root.get_node("Review")
	var expo := root.get_node("Expo")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")

	# --- reputation: gains slow down, scars lower the ceiling, 100 is hard to reach
	c.rep = 50
	c.adjust_rep(5)
	_check(c.rep == 55, "below 60 a gain counts in full")
	c.rep = 90
	c.adjust_rep(5)
	_check(c.rep > 90 and c.rep <= 92, "above 85 a +5 is worth about 1 (%d)" % c.rep)
	c.rep = 70
	c.add_scar(15)
	_check(c.rep_cap() == 85 and c.rep == 70, "a scar lowers the ceiling to 85")
	c.rep = 84
	c.adjust_rep(5)
	_check(c.rep == 85, "gains stop at the ceiling")
	c.scars = 0
	_check(c.daily_cap() <= 4, "the day report adds at most 4 a day")

	# --- review: every playbook job is listed and has a client
	for id in pb.BOOKS:
		var listed := false
		for job in review.JOBS:
			listed = listed or job[0] == id
		_check(listed and review.CLIENT_OF.has(id), "review lists the %s job" % id)
	story.flags = {"ransom": "lost", "netinstall": "S", "ceofraud": "A", "rack": "B"}
	_check(
		review.best_client() == "Gnarly Gnomes",
		"the in-house offer skips the client whose data you lost (%s)" % review.best_client()
	)
	story.flags = {"ransom": "lost"}
	_check(
		not review.best_client().begins_with("Hoot"),
		"with nothing else graded the offer is still not the burned client"
	)
	story.flags = {}

	# --- HUD hidden while the Review (or any panel) is open
	var hud: Node = load("res://scripts/hud.gd").new()
	review.is_open = true
	_check(hud.modal_open(), "the HUD strip hides while the Review is open")
	review.is_open = false
	_check(not hud.modal_open(), "and shows again afterwards")
	hud.free()

	# --- ransomware without a backup
	msp.reset()
	story.reset()
	msp.break_backup(story.RANSOM_CLIENT)
	var rt: Dictionary = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
	var ep: Dictionary = msp.endpoint(str(rt.endpoint))
	var closed0: int = msp.closed_ok
	var msg: String = msp.rmm_action(ep.name, "restore")
	_check(
		msg.contains("FAILED") and ep.problem == "restore" and not rt.fix_done,
		"RESTORE with a failed backup says so and leaves the problem: " + msg
	)
	_check(msp.rmm_action(ep.name, "restore").contains("FAILED"), "the restore can be tried again")
	var tried := ""
	for i in 12:
		tried = msp.rmm_action(ep.name, "shadow")
		if ep.problem != "restore":
			break
	_check(
		ep.problem != "restore" or tried.contains("LEFT"),
		"shadow copies are offered (and only once): " + tried
	)
	if ep.problem == "restore":
		msp.rmm_action(ep.name, "pay")
	var close_msg: String = msp.close_ticket(int(rt.id))
	if story.flags.get("ransom", "") == "lost":
		_check(
			close_msg.contains("DATA LOST") and msp.closed_ok == closed0,
			"a lost recovery closes with no points: " + close_msg
		)
	else:
		_check(close_msg.contains("CLOSED +4"), "a paid or partial recovery closes for few points: " + close_msg)
	msp.reset()
	story.reset()
	msp.break_backup(story.RANSOM_CLIENT)
	rt = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
	msp.rmm_action(rt.endpoint, "restore")
	c.rep = 60
	close_msg = msp.close_ticket(int(rt.id))
	_check(
		close_msg.contains("DATA LOST") and story.flags.ransom == "lost" and c.rep < 60,
		"closing the ticket after a failed restore is giving up: " + close_msg
	)

	# --- a playbook job always gets its ticket, even when the client's machines are all broken
	msp.reset()
	story.reset()
	for n in 6:
		msp.create_problem(0, msp.PROBLEMS[0], "test")
	var healthy := 0
	for e in msp.endpoints:
		if e.client == 0 and e.problem == "" and not e.name.contains("SRV"):
			healthy += 1
	_check(healthy == 0, "setup: every PC of client 0 is broken")
	var first: int = pb.start("bus")
	_check(first != 0 and not msp.ticket(first).is_empty(), "the job still gets a ticket on a broken client")
	pb.reset()
	for srv in msp.endpoints:
		if srv.client == 1 and srv.name.contains("SRV"):
			srv.problem = "reboot"
	var mig: int = pb.start("migration")
	_check(mig != 0, "and a server job gets one when the only server is broken")
	pb.reset()

	# --- finishing a job closes its tickets
	msp.reset()
	story.reset()
	var job_ticket: int = pb.start("rack")
	var guard := 0
	while pb.is_active() and guard < 20:
		pb.choose(_best(pb))
		guard += 1
	_check(not pb.is_active() and msp.ticket(job_ticket).status == "Closed", "a finished job closes its tickets")
	_check(msp.open_tickets().is_empty(), "nothing from the job is left to breach")
	pb.reset()

	# --- install: the handover closes its ticket
	msp.reset()
	var it: Dictionary = msp.create_problem(0, msp.INSTALL, "sales")
	msp.start_project(int(it.id))
	msp.project_ask()
	msp.project_scan(true)
	msp.project_backup()
	msp.project_select_all()
	msp.project_migrate()
	msp.project_verify()
	msp.project_select_all()
	msp.project_migrate()
	msp.project_handover()
	_check(msp.ticket(int(it.id)).status == "Closed", "the install handover closes its ticket")

	# --- the end-of-day card shows the real time and is not offered after overtime
	shift.enabled = true
	c.day = 13
	msp.reset()
	msp.create_ticket(0, 0, "test")
	_check(shift.active(), "setup: hour management is on")
	world.clock = 19.32
	story.ot_hours = 2.3
	shift.reset()
	shift.enabled = true
	_check(shift.can_end_day() and not cards.is_open, "no STAY offer when overtime already ran past closing")
	_check(shift.clock_label() == "7:19 PM", "clock label reads the time (%s)" % shift.clock_label())
	story.ot_hours = 0.0
	world.clock = 17.0
	shift.reset()
	shift.enabled = true
	var can_end: bool = shift.can_end_day()
	_check(not can_end and cards.is_open and cards.text.contains("STILL OPEN"), "a normal day still offers to stay")
	_check(shift.clock_label() == "5:00 PM", "and the card is headed 5:00 PM")
	while cards.is_open:
		cards.pick(0)
	var seen_pages := {}
	var last := ""
	var repeats := 0
	for i in 60:
		var now: String = shift._fresh(shift.PAGES, last)
		repeats += 1 if now == last else 0
		last = now
		seen_pages[now] = true
	_check(repeats == 0 and seen_pages.size() >= 8, "pager reasons: %d kinds, no immediate repeat" % seen_pages.size())
	shift.enabled = false

	# --- trip text
	_check(not str(expo.TEXT.yes_body).contains("two days"), "the trip is one day in the verdict mail")
	expo.qualified = true
	c.day = 16
	var preview: String = root.get_node("Meeting")._preview()
	_check(preview.contains("Rodent Nation"), "the day-16 preview mentions the trip: " + preview)
	var hints := root.get_node("Hints")
	expo.badge = true
	expo._stage = "keynote"
	expo._trip_tick()
	_check(not str(hints.objective).contains("GET A BADGE"), "the objective stops asking for a badge once you have it")
	expo.badge = false
	expo._trip_tick()
	_check(str(hints.objective).contains("GET A BADGE"), "and asks for one before that")
	expo._stage = ""
	expo.qualified = false

	# --- calendar slips
	_check(
		not str(shift.WEEK_TRAFFIC[3].text).contains("SNOW") and not str(story.DAYS[15][0].body).contains("now"),
		"no snow in a spring 2014 timeline"
	)
	var vendor := ""
	for step in pb.BOOKS.email24.steps:
		vendor += str(step.text)
	_check(not vendor.contains("17:40"), "the vendor call does not name a clock time")
	story.flags = {"bus": "B", "bus_reset": true, "bus_doc": false}
	var v: Dictionary = story.VIGNETTES.donuts
	_check(story._vignette_text("donuts", v).contains("heard what happened"), "donuts after a factory reset")
	story.flags = {"bus": "S", "bus_reset": false, "bus_doc": true}
	_check(story._vignette_text("donuts", v).contains("page you wrote"), "donuts after documenting the firewall")
	story.flags = {"bus": "C", "bus_reset": false, "bus_doc": false}
	_check(story._vignette_text("donuts", v).contains("Nobody wrote down"), "donuts when nothing was written down")
	story.flags = {}

	# --- small things: Spence, Morgan, a queued Vic card for a closed ticket, the RMM labels
	var all_text := ""
	for prob in pb.PROBLEMS.ceofraud:
		all_text += str(prob.body)
	_check(not all_text.contains("Mr. Spence"), "Atty. Spence everywhere")
	msp.reset()
	msp.mail("Morgan Reyes - Manager", "a", "b")
	msp.mail("Morgan Reyes <morgan@pixelit.example>", "c", "d")
	_check(msp.emails[0].from == msp.emails[1].from, "Morgan has one sender format")
	var ticket: Dictionary = msp.create_ticket(0, 0, "test")
	var later_ran := [false, ""]
	cards.ask("Someone", "first", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	cards.ask(
		"Vic Marlowe",
		"complaint",
		[{"label": "OK", "id": "ok"}],
		func(id: String) -> void:
			later_ran[0] = true
			later_ran[1] = id,
		func() -> bool: return str(msp.ticket(int(ticket.id)).status) != "Closed"
	)
	msp.ticket(int(ticket.id)).status = "Closed"
	cards.pick(0)
	_check(
		not cards.is_open and later_ran[0] and later_ran[1] == "__none",
		"a queued complaint for a ticket that closed meanwhile is dropped"
	)
	_check(
		msp.FIXES.pay.length() <= 18 and msp.FIXES.shadow.length() <= 18,
		"the ransom buttons fit the RMM button (%s / %s)" % [msp.FIXES.pay, msp.FIXES.shadow]
	)
	var big: Dictionary = root.get_node("DayReport").BIG_GRADES
	_check(str(big.B) != str(big.D), "the grade box has its own B")


func _init() -> void:
	await process_frame
	if not OS.get_cmdline_user_args().has("curve"):
		_unit()
	var curves := {}
	for mode in ["good", "careless", "mixed"]:
		var reps: Array = await _run(mode, 4242)
		curves[mode] = reps
		print("CURVE %s: %s" % [mode, str(reps)])
	var good: Array = curves.good
	var bad: Array = curves.careless
	var mixed: Array = curves.mixed
	_check(good[19] >= 85 and good[19] <= 100, "good play ends at 85-100 (%d)" % good[19])
	var early_cap := true
	for d in 14:
		early_cap = early_cap and good[d] < 100
	_check(early_cap and good[14] < 97, "and does not top out before day 15")
	_check(
		bad.back() < 40 and bad.size() < 20,
		"careless play ends below 40 and is fired (day %d, rep %d)" % [bad.size(), bad.back()]
	)
	_check(mixed[19] >= 55 and mixed[19] <= 80, "mixed play ends at 55-80 (%d)" % mixed[19])
	root.get_node("Campaign").quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
