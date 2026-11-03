extends SceneTree
# Skills, the PowerShell Academy, timed fixes, backups, ransomware and the story day events.
# Headless. Saves go to user://test_*.cfg.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var sk := root.get_node("Skills")
	var story := root.get_node("Story")
	var world := root.get_node("World")
	var comp := root.get_node("Computer")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# outside a campaign nothing changes: instant, reliable fixes and no experience
	c.new_game("free")
	_check(sk.fix_secs() == 0.0 and sk.fail_chance() == 0.0, "free play: instant reliable fixes")
	sk.add_xp("servers", 50)
	_check(sk.level("servers") == 0, "free play: no experience")

	c.new_game("tech")
	_check(
		sk.ps_level == 0 and sk.fix_secs() > 5.0 and sk.fail_chance() > 0.2,
		"campaign: slow, unreliable at level 0"
	)
	sk.add_xp("servers", 40)
	_check(sk.level("servers") == 2 and sk.progress("servers") == 0.0, "experience levels a skill")

	# the Academy: lesson 1 by answering everything right
	comp.open(1)
	comp.activate("app:learn")
	comp.activate("lesson:0")
	for q in 3:
		var right: String = sk.LESSONS[0].qs[q][1]
		comp.activate("ans:%d" % comp.learn_opts.find(right))
		comp.activate("qnext")
	_check(comp.learn_done and sk.ps_level == 1, "lesson 1 passed: PowerShell level 1")
	comp.activate("lback")
	comp.activate("lesson:0")  # not available again (only the next lesson starts)
	comp.activate("lback")
	comp.activate("lesson:1")
	for q in 3:
		comp.activate("ans:%d" % ((comp.learn_opts.find(sk.LESSONS[1].qs[q][1]) + 1) % 3))
		comp.activate("qnext")
	_check(sk.ps_level == 1, "lesson 2 failed: still level 1")

	# timed fix with the RMM
	sk.ps_level = 4
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	comp.rmm_sel = t.endpoint
	comp.activate("connect")
	comp.activate("fix:spooler")
	_check(
		not comp._job.is_empty() and comp._job.total == sk.FIX_SECS[4], "fix runs as a timed job"
	)
	comp._job.left = 0.0
	comp._finish_job()
	_check(
		msp.endpoint(t.endpoint).problem == "" and msp.ticket(t.id).fix_done, "job applies the fix"
	)

	# scripts fix a whole client / everyone
	var a: Dictionary = msp.create_ticket(1, 0, "test")
	var b: Dictionary = msp.create_ticket(1, 0, "test")
	var other: Dictionary = msp.create_ticket(2, 0, "test")
	_check(
		(
			msp.rmm_bulk(1, "spooler", false) == 2
			and msp.ticket(a.id).fix_done
			and msp.ticket(b.id).fix_done
		),
		"script: one client"
	)
	_check(
		not msp.ticket(other.id).fix_done and msp.rmm_bulk(0, "spooler", true) == 1,
		"script: all clients"
	)
	comp.close()

	# backups
	c.day = 5
	msp.new_day(5)
	story.fire({"kind": "backup_break", "client": story.RANSOM_CLIENT})
	var bk: Dictionary = msp.backups[story.RANSOM_CLIENT]
	_check(not bk.ok and bk.good_day == 4 and bk.checked_day < 5, "backup fails silently")
	msp.backup_check(story.RANSOM_CLIENT)
	_check(int(bk.checked_day) == 5, "checking marks it verified today")
	msp.backup_rerun(story.RANSOM_CLIENT)
	_check(bk.ok, "rerun fixes it")

	# ransomware WITH a backup
	story.fire({"kind": "ransomware"})
	var rt: Dictionary = msp.ticket(story.flags.ransom_ticket)
	_check(rt.special == "ransomware" and rt.pri == 1, "ransomware ticket")
	var rep0: int = c.rep
	_check(
		msp.rmm_action(rt.endpoint, "reboot").contains("NOTHING CHANGED"), "rebooting does nothing"
	)
	var msg: String = msp.rmm_action(rt.endpoint, "restore")
	_check(
		msg.contains("NO DATA LOST") and c.rep == rep0 + 5 and story.flags.ransom == "saved",
		"restore with a backup: " + msg
	)

	# ransomware WITHOUT a backup
	msp.break_backup(story.RANSOM_CLIENT)
	msp.tickets.clear()
	for ep in msp.endpoints:
		ep.problem = ""
	story.flags.erase("ransom")
	story.fire({"kind": "ransomware"})
	rt = msp.ticket(story.flags.ransom_ticket)
	rep0 = c.rep
	var score0: int = msp.score
	msg = msp.rmm_action(rt.endpoint, "restore")
	_check(
		(
			msg.contains("BACKUP FAILED")
			and c.rep == rep0
			and msp.score == score0
			and not story.flags.has("ransom")
			and msp.endpoint(rt.endpoint).problem == "restore"
		),
		"restore without a backup fails but leaves the other options: " + msg
	)
	msg = msp.close_ticket(rt.id)
	_check(
		msg.contains("DATA LOST") and c.rep == rep0 - 15 and msp.score == score0 - 30 and story.flags.ransom == "lost",
		"giving up on the files loses the data and the close earns nothing: " + msg
	)

	# the story day events fire by the clock (day 3: manager mail + the Adobe ticket)
	msp.reset()
	c.day = 3
	story.begin_day(3)
	world.clock = 8.5
	await process_frame
	var mails0: int = msp.emails.size()
	world.clock = 10.2
	await process_frame
	await process_frame
	_check(
		msp.emails.size() > mails0 and msp.open_tickets().size() == 1,
		"day 3: PowerShell mail and the Adobe ticket"
	)
	_check(msp.open_tickets()[0].summary == "Adobe Reader will not print", "the easy first ticket")
	var adobe: Dictionary = msp.open_tickets()[0]
	msp.rmm_action(adobe.endpoint, "adobe")
	_check(msp.ticket(adobe.id).fix_done, "repairing Adobe Reader fixes it")

	# save and continue keeps skills + backups + story flags
	sk.reset()
	sk.ps_level = 3
	sk.xp["security"] = 55
	msp.backups[1].ok = false
	story.flags = {"ransom": "lost"}
	c.day = 6
	c.save()
	c.new_game("free")
	_check(
		c.continue_game("tech") and sk.ps_level == 3 and sk.level("security") == 2, "skills saved"
	)
	_check(
		not msp.backups[1].ok and story.flags.get("ransom") == "lost", "backups + story flags saved"
	)
	DirAccess.remove_absolute(c.save_path("tech"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
