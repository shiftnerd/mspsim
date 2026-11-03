extends SceneTree
# Tickets with more than one valid fix (Msp.ALT_DEFS): quick workarounds that may come back, heavy
# fixes that always work but cost, and skill-gated clever fixes. Also the RMM session buttons.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# a fresh ticket: problem index into Msp.PROBLEMS (or -1 = the Adobe ticket)
func _t(msp: Node, prob: int, unsaved := false, asked := false) -> Dictionary:
	msp.reset()
	msp.alt_roll = -1.0
	root.get_node("Story").flags["followups"] = []
	root.get_node("Sales").satisfaction[0] = 70
	var t: Dictionary
	if prob < 0:
		t = msp.create_problem(0, msp.ADOBE, "test")
	else:
		t = msp.create_ticket(0, prob, "test")
	var ep: Dictionary = msp.endpoint(t.endpoint)
	ep.unsaved = unsaved
	ep.asked = asked
	return t


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var sk := root.get_node("Skills")
	var story := root.get_node("Story")
	var growth := root.get_node("Growth")
	c.save_prefix = "user://test_"
	root.get_node("Game").title_mode = false

	# outside a campaign a workaround comes back on a timer; clever fixes need a campaign
	var t := _t(msp, 0)
	var ep: Dictionary = msp.endpoint(t.endpoint)
	_check(msp.alts_for(ep) == ["clear_queue", "reinstall_printer"], "free play offers 2 spooler alts")
	msp.alt_roll = 0.0
	var res: String = msp.rmm_action(ep.name, "clear_queue")
	_check(msp._later.size() == 1, "free play: the workaround is queued to come back soon")
	msp._later[0].left = 0.0
	var n0: int = msp.tickets.size()
	msp._process(0.5)
	_check(msp.tickets.size() == n0 + 1 and msp._later.is_empty(), "...and the new ticket arrives")

	c.new_game("tech")
	var xp0 := 0

	# ---- the print spooler -----------------------------------------------------------------
	t = _t(msp, 0)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.99
	xp0 = sk.xp["networking"]
	res = msp.rmm_action(ep.name, "clear_queue")
	_check(
		res.contains("Stuck jobs") and msp.ticket(t.id).fix_done and ep.problem == "",
		"quick: clearing the queue fixes the ticket"
	)
	_check(sk.xp["networking"] == xp0 + 2, "...for 2 XP instead of 4")
	_check(
		sales.mood(0) == 70 and story.flags["followups"].is_empty(),
		"...no mood cost and (this roll) it does not come back"
	)
	t = _t(msp, 0)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	msp.rmm_action(ep.name, "clear_queue")
	var fl: Array = story.flags["followups"]
	_check(
		fl.size() == 1 and fl[0].fix == "spooler" and fl[0].days >= 1 and fl[0].days <= 2,
		"quick: it comes back as a follow-up in 1-2 days"
	)
	var esc0: int = int(growth.esc_skill.get("networking", 0))
	c.day += 2
	var open0: int = msp.open_tickets().size()
	story._spawn_followups()
	_check(
		msp.open_tickets().size() == open0 + 1 and msp.open_tickets()[0].summary != "",
		"...and the follow-up ticket is a real one"
	)
	var again: Dictionary = {}
	for tk in msp.tickets:
		if tk.summary == "Printer stuck again":
			again = tk
	_check(
		not again.is_empty() and again.fix == "spooler" and again.pri == 3,
		"...needing the proper fix"
	)
	_check(
		int(growth.esc_skill.get("networking", 0)) == esc0 + 1,
		"...and it counts as an escalation for Growth"
	)
	var aep: Dictionary = msp.endpoint(again.endpoint)
	msp.rmm_action(aep.name, "spooler")
	_check(msp.ticket(again.id).fix_done and msp.close_ticket(again.id).begins_with("CLOSED"), "proper fix closes it")

	t = _t(msp, 0)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	xp0 = sk.xp["networking"]
	res = msp.rmm_action(ep.name, "reinstall_printer")
	_check(
		msp.ticket(t.id).fix_done and sales.mood(0) == 69 and story.flags["followups"].is_empty(),
		"heavy: reinstalling the printer works, costs 1 mood, never comes back"
	)
	_check(sk.xp["networking"] == xp0 + 3, "...3 XP")

	# the proper fix does not return and costs nothing
	t = _t(msp, 0)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	xp0 = sk.xp["networking"]
	msp.rmm_action(ep.name, "spooler")
	_check(
		sk.xp["networking"] == xp0 + 4 and sales.mood(0) == 70 and story.flags["followups"].is_empty(),
		"the proper fix: 4 XP, nobody bothered, never returns"
	)

	# clever: NETWORKING 2
	t = _t(msp, 0)
	ep = msp.endpoint(t.endpoint)
	_check(not msp.alts_for(ep).has("copier_route"), "copier reroute is locked below NETWORKING 2")
	res = msp.rmm_action(ep.name, "copier_route")
	_check(res.contains("NOTHING CHANGED") and ep.problem == "spooler", "...and does nothing")
	sk.xp["networking"] = 40
	_check(sk.level("networking") == 2 and msp.alts_for(ep).has("copier_route"), "unlocked at 2")
	xp0 = sk.xp["networking"]
	res = msp.rmm_action(ep.name, "copier_route")
	_check(
		msp.ticket(t.id).fix_done and sales.mood(0) == 71 and sk.xp["networking"] == xp0 + 6,
		"clever: copier reroute fixes it, mood +1, 6 XP"
	)
	_check(sk.perk_text("networking", 2).contains("COPIER"), "the NETWORKING 2 perk text mentions it")

	# timing: quick < proper < heavy; clever < proper
	sk.ps_level = 1
	var proper: float = sk.fix_secs_for("spooler")
	_check(sk.fix_secs_for("clear_queue") < proper, "timing: the workaround is faster")
	_check(sk.fix_secs_for("reinstall_printer") > proper * 2.0, "timing: the heavy fix is much slower")
	_check(sk.fix_secs_for("copier_route") < proper, "timing: the clever fix is faster")
	sk.ps_level = 0

	# ---- locked out ------------------------------------------------------------------------
	t = _t(msp, 1)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	res = msp.rmm_action(ep.name, "temp_pass")
	_check(
		msp.ticket(t.id).fix_done and story.flags["followups"].size() == 1,
		"password quick: a temp password works and probably comes back"
	)
	t = _t(msp, 1, true)
	ep = msp.endpoint(t.endpoint)
	var score0: int = msp.score
	res = msp.rmm_action(ep.name, "new_profile")
	_check(
		res.contains("LOST UNSAVED") and sales.mood(0) == 62 and msp.score == score0 - 3,
		"password heavy: rebuilding the profile loses unwarned work (%d)" % sales.mood(0)
	)
	t = _t(msp, 1, true, true)
	ep = msp.endpoint(t.endpoint)
	res = msp.rmm_action(ep.name, "new_profile")
	_check(
		not res.contains("LOST") and sales.mood(0) == 68 and msp.ticket(t.id).fix_done,
		"...but not after asking the user to save"
	)
	t = _t(msp, 1)
	ep = msp.endpoint(t.endpoint)
	sk.ps_level = 1
	_check(not msp.alts_for(ep).has("unlock_ps"), "Unlock-ADAccount needs PowerShell 2")
	sk.ps_level = 2
	xp0 = sk.xp["security"]
	res = msp.rmm_action(ep.name, "unlock_ps")
	_check(
		msp.ticket(t.id).fix_done and sk.xp["security"] == xp0 + 6 and sales.mood(0) == 70,
		"password clever: PowerShell unlock, 6 XP, no cost"
	)
	sk.ps_level = 0

	# ---- slow computer ---------------------------------------------------------------------
	t = _t(msp, 2)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	msp.rmm_action(ep.name, "recycle")
	_check(
		msp.ticket(t.id).fix_done and story.flags["followups"][0].summary == "Computer is slow again",
		"slow quick: emptying the recycle bin works for a day"
	)
	t = _t(msp, 2, true)
	ep = msp.endpoint(t.endpoint)
	xp0 = sk.xp["servers"]
	res = msp.rmm_action(ep.name, "reimage")
	_check(
		res.contains("Reimaged") and res.contains("LOST") and sales.mood(0) == 60,
		"slow heavy: a reimage fixes it, -4 mood, -6 more for lost work (%d)" % sales.mood(0)
	)
	_check(sk.xp["servers"] == xp0 + 3 and story.flags["followups"].is_empty(), "...3 XP, never returns")
	t = _t(msp, 2)
	ep = msp.endpoint(t.endpoint)
	sk.ps_level = 2
	_check(not msp.alts_for(ep).has("disk_script"), "the cleanup script needs PowerShell 3")
	sk.ps_level = 3
	res = msp.rmm_action(ep.name, "disk_script")
	_check(msp.ticket(t.id).fix_done and sales.mood(0) == 70, "slow clever: cleanup script")
	sk.ps_level = 0

	# ---- pop-ups ---------------------------------------------------------------------------
	t = _t(msp, 4)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	msp.rmm_action(ep.name, "browser_reset")
	_check(
		msp.ticket(t.id).fix_done and story.flags["followups"][0].summary == "Pop-ups are back",
		"pop-ups quick: a browser reset hides it for now"
	)
	t = _t(msp, 4)
	ep = msp.endpoint(t.endpoint)
	_check(not msp.alts_for(ep).has("spyhunt"), "SpyHunt needs SECURITY 2")
	sk.xp["security"] = 40
	xp0 = sk.xp["security"]
	msp.rmm_action(ep.name, "spyhunt")
	_check(
		msp.ticket(t.id).fix_done and sk.xp["security"] == xp0 + 7, "pop-ups clever: SpyHunt log, 7 XP"
	)
	t = _t(msp, 4)
	ep = msp.endpoint(t.endpoint)
	msp.rmm_action(ep.name, "reimage")
	_check(msp.ticket(t.id).fix_done and sales.mood(0) == 66, "pop-ups heavy: reimage (-4, no work open)")

	# ---- blue screen (nothing to lose) -----------------------------------------------------
	t = _t(msp, 3, true)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	res = msp.rmm_action(ep.name, "last_good")
	_check(
		msp.ticket(t.id).fix_done and not res.contains("LOST") and sales.mood(0) == 69,
		"blue screen quick: Last Known Good, -1 mood, no lost work"
	)
	_check(story.flags["followups"][0].summary == "Blue screen again", "...and it comes back")
	t = _t(msp, 3)
	ep = msp.endpoint(t.endpoint)
	_check(not msp.alts_for(ep).has("safemode"), "safe mode driver rollback needs SERVERS 2")
	sk.xp["servers"] = 40
	msp.alt_roll = 0.0
	msp.rmm_action(ep.name, "safemode")
	_check(
		msp.ticket(t.id).fix_done and story.flags["followups"].is_empty(),
		"blue screen clever: rolls back the driver, never returns"
	)
	t = _t(msp, 3, true)
	ep = msp.endpoint(t.endpoint)
	res = msp.rmm_action(ep.name, "reimage")
	_check(msp.ticket(t.id).fix_done and not res.contains("LOST"), "blue screen heavy: reimage")

	# ---- the server ------------------------------------------------------------------------
	t = _t(msp, 5)
	ep = msp.endpoint(t.endpoint)
	_check(
		msp.alts_for(ep).has("restart_services") and not msp.alts_for(ep).has("last_good"),
		"servers get their own alternatives"
	)
	msp.alt_roll = 0.0
	msp.rmm_action(ep.name, "restart_services")
	_check(
		msp.ticket(t.id).fix_done and story.flags["followups"][0].server,
		"server quick: restart the services, it returns as a server ticket"
	)
	t = _t(msp, 5)
	ep = msp.endpoint(t.endpoint)
	score0 = msp.score
	msp.rmm_action(ep.name, "snapshot")
	_check(
		msp.ticket(t.id).fix_done and sales.mood(0) == 67 and msp.score == score0 - 2,
		"server heavy: snapshot rollback, -3 mood, -2 score"
	)
	t = _t(msp, 5)
	ep = msp.endpoint(t.endpoint)
	sk.xp["servers"] = 80
	_check(sk.level("servers") == 3 and msp.alts_for(ep).has("event_log"), "event log needs SERVERS 3")
	xp0 = sk.xp["servers"]
	msp.rmm_action(ep.name, "event_log")
	_check(
		msp.ticket(t.id).fix_done and sales.mood(0) == 71 and sk.xp["servers"] == xp0 + 8,
		"server clever: finds the hung service, +1 mood, 8 XP"
	)

	# ---- Adobe Reader ----------------------------------------------------------------------
	t = _t(msp, -1)
	ep = msp.endpoint(t.endpoint)
	msp.alt_roll = 0.0
	msp.rmm_action(ep.name, "print_browser")
	_check(
		msp.ticket(t.id).fix_done and story.flags["followups"][0].fix == "adobe",
		"adobe quick: print from the browser, it comes back"
	)
	t = _t(msp, -1)
	ep = msp.endpoint(t.endpoint)
	msp.rmm_action(ep.name, "reader_reinstall")
	_check(msp.ticket(t.id).fix_done and sales.mood(0) == 69, "adobe heavy: reinstall")

	# ---- guard rails -----------------------------------------------------------------------
	t = _t(msp, 0)
	ep = msp.endpoint(t.endpoint)
	res = msp.rmm_action(ep.name, "recycle")
	_check(res.contains("NOTHING CHANGED") and ep.problem == "spooler", "an alt for another problem does nothing")
	res = msp.rmm_action(ep.name, "reimage")
	_check(ep.problem == "spooler", "a reimage is not offered for a spooler problem")
	var healthy: Dictionary = {}
	for e in msp.endpoints:
		if e.problem == "":
			healthy = e
			break
	_check(msp.alts_for(healthy).is_empty(), "a healthy machine has no alternatives")
	_check(
		msp.alt_label(ep, "clear_queue") == "CLEAR PRINT QUEUE", "the button label comes from the table"
	)
	t = _t(msp, 2, true)
	ep = msp.endpoint(t.endpoint)
	sk.xp["people"] = 40
	_check(msp.alt_label(ep, "reimage").ends_with("!"), "CUSTOMER 2 flags a restart that would lose work")
	msp.rmm_action(ep.name, "save")
	_check(not msp.alt_label(ep, "reimage").ends_with("!"), "...but not once the user was asked")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
