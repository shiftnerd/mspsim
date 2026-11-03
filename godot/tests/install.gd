extends SceneTree
# Day 4: the new desktop install + migration project (Msp.project_*, RMM PROJECT tab).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var story := root.get_node("Story")
	var world := root.get_node("World")
	var comp := root.get_node("Computer")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	c.new_game("tech")

	# the story event on day 4 creates the ticket and the project
	c.day = 4
	story.begin_day(4)
	world.clock = 8.5
	await process_frame
	world.clock = 10.2
	await process_frame
	await process_frame
	_check(
		not msp.project.is_empty() and msp.ticket(int(msp.project.ticket)).special == "install",
		"day 4: install ticket + project"
	)
	var tid: int = msp.project.ticket
	var known0 := 0
	for it in msp.INSTALL_ITEMS:
		known0 += 1 if msp.project.found[it.id] else 0
	_check(known0 == 5, "five items are visible at the start, three are hidden")

	# the careful way, through the computer UI
	comp.open(1)
	comp.activate("app:rmm")
	comp.activate("tab:project")
	comp.activate("proj:ask")
	_check(
		msp.project.found.xray and msp.project.found.sticky and not msp.project.found.drives,
		"asking the user reveals the xray + sticky notes"
	)
	comp.activate("proj:deep")
	_check(not comp._job.is_empty() and comp._job.total > 1.0, "deep scan is a timed job")
	comp._job.left = 0.0
	comp._finish_job()
	_check(msp.project.found.drives, "deep scan finds the mapped drives")
	comp.activate("proj:backup")
	comp._job.left = 0.0
	comp._finish_job()
	comp.activate("proj:all")
	comp.activate("proj:migrate")
	_check(comp._job.total > 5.0, "migrating everything takes a while")
	comp._job.left = 0.0
	comp._finish_job()
	comp.activate("proj:verify")
	comp._job.left = 0.0
	comp._finish_job()
	_check(
		(
			msp.project.migrated.xray
			and msp.project.migrated.docs
			and msp.project.verified
			and msp.project.backup
		),
		"everything copied, backed up, verified"
	)
	var score0: int = msp.score
	comp.activate("proj:hand")
	var res: Dictionary = msp.project.result
	_check(
		res.pts == 100 and res.grade == "S" and res.outcome == "ok",
		"perfect handover is an S: %s" % str(res)
	)
	_check(
		msp.score == score0 + 20 and msp.ticket(tid).fix_done, "score + the ticket can be closed"
	)
	_check(msp.close_ticket(tid).begins_with("CLOSED"), "ticket closes")
	comp.close()

	# the sloppy way: copy only what you can see, no backup, no verify -> the xray data is lost
	msp.reset()
	story.flags = {}
	var t: Dictionary = msp.create_problem(0, msp.INSTALL, "test")
	msp.start_project(t.id)
	msp.project_scan(false)
	msp.project_select_all()
	msp.project_migrate()
	var rep0: int = c.rep
	res = msp.project_handover()
	_check(
		res.outcome == "lost" and res.lost == ["XRAY SOFTWARE + XP DRIVERS"],
		"skipping the survey loses the xray data"
	)
	_check(
		res.grade in ["C", "D"] and c.rep < rep0 - 8,
		"bad grade + reputation hit: %s rep %d -> %d" % [res.grade, rep0, c.rep]
	)
	_check(story.flags.install == "lost", "story remembers it")
	story.flags = {"install": "lost"}
	var mails0: int = msp.emails.size()
	story.fire({"kind": "install_followup"})
	_check(msp.emails.size() == mails0 + 1, "day 5: Dr. Patel is still angry")

	# missed the key data but there is a backup: much milder
	msp.reset()
	t = msp.create_problem(0, msp.INSTALL, "test")
	msp.start_project(t.id)
	msp.project_backup()
	msp.project_select_all()
	msp.project_migrate()
	res = msp.project_handover()
	_check(res.outcome == "restored", "backup turns the loss into a restore")

	# verify catches what you missed
	msp.reset()
	t = msp.create_problem(0, msp.INSTALL, "test")
	msp.start_project(t.id)
	msp.project_select_all()
	msp.project_migrate()
	var missing: Array = msp.project_verify()
	_check(missing.size() == 3 and msp.project.found.xray, "verify reveals what is missing")
	msp.project_select_all()
	msp.project_migrate()
	res = msp.project_handover()
	_check(res.outcome == "ok", "fixing it before handover is fine")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
