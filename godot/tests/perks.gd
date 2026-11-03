extends SceneTree
# Progression: skill perks, the XP spread, one Academy lesson a day, earlier choices returning,
# the owner's value estimate and risks.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sk := root.get_node("Skills")
	var msp := root.get_node("Msp")
	var story := root.get_node("Story")
	var sales := root.get_node("Sales")
	var growth := root.get_node("Growth")
	var owner := root.get_node("Owner")
	var shift := root.get_node("Shift")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")

	# ---- XP spread
	_check(sk.FIX_XP["spooler"] == "networking", "printer problems train NETWORKING")
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	var before: int = sk.xp["people"]
	msp.rmm_action(t.endpoint, "spooler")
	msp.close_ticket(t.id)
	_check(sk.xp["people"] == before + 2, "closing a ticket gives 2 CUSTOMER XP now")
	_check(sk.xp["networking"] >= 4, "and the spooler fix gave NETWORKING XP")

	# ---- perks
	sk.ps_level = 0
	shift.enabled = false
	var base: float = sk.fix_secs()
	_check(is_equal_approx(sk.fix_secs_for("clear_temp"), base), "no SERVERS skill: normal speed")
	sk.xp["servers"] = 80
	_check(
		is_equal_approx(sk.fix_secs_for("clear_temp"), base * (1.0 - 0.06 * 3.0)),
		"SERVERS 3: server fixes 18% faster"
	)
	_check(is_equal_approx(sk.fix_secs_for("password"), base), "...but a security fix is not")
	growth.focus = "servers"
	growth.graduated = true
	_check(
		is_equal_approx(sk.fix_secs_for("clear_temp"), base * 0.82 * 0.75),
		"a Tier 2 in the skill is another 25% faster"
	)
	growth.graduated = false
	growth.focus = ""
	_check(sk.perk_text("security", 3).contains("BACKUP WATCH"), "SECURITY 3 perk text")
	_check(sk.perk_text("networking", 2).contains("CLOSET"), "NETWORKING 2 perk text")
	_check(sk.perk_text("people", 4) == "SLAS TICK 10% SLOWER", "CUSTOMER 4 perk text")
	sk.xp["security"] = 0
	_check(not sk.backup_watch(), "no backup watch yet")
	sk.xp["security"] = 80
	_check(sk.backup_watch(), "SECURITY 3: backups check themselves")
	sk.xp["people"] = 130
	_check(is_equal_approx(sk.sla_pace(), 0.9), "CUSTOMER 4: SLA clocks tick 10% slower")
	var texts0: int = msp.texts.size()
	sk.xp["people"] = 39
	sk.add_xp("people", 1)
	_check(
		msp.texts.size() > texts0 and msp.texts[0].body.contains("New:"),
		"the level-up text names the perk"
	)
	sk.xp["networking"] = 0
	_check(
		sk.next_perk().begins_with("NEXT PERK:"),
		"the profile shows the next perk: " + sk.next_perk()
	)

	# the closet tip
	sk.xp["networking"] = 40
	msp.create_internal(3, "No network", "help")
	var tip := false
	for k in msp.tickets:
		if k.internal:
			for n in k.notes:
				tip = tip or str(n).contains("patch panel port 3")
	_check(tip, "NETWORKING 2: outage tickets name the patch panel port")

	# ---- one Academy lesson a day
	sk.reset()
	c.day = 3
	shift.reset()
	var e0: float = shift.energy
	sk.pass_lesson(0)
	_check(sk.ps_level == 1 and shift.energy == e0 - 3.0, "a passed lesson costs 3 energy")
	sk.pass_lesson(1)
	_check(sk.ps_level == 1 and not sk.can_study(), "...and only one a day")
	c.day = 4
	sk.pass_lesson(1)
	_check(sk.ps_level == 2 and sk.can_study() == false, "the next day the next lesson")

	# ---- earlier choices come back
	story.flags["ransom"] = "saved"
	sales.satisfaction[story.RANSOM_CLIENT] = 60
	story.fire({"kind": "callback_ransom"})
	_check(
		msp.emails[0].subject == "Renewal" and sales.mood(story.RANSOM_CLIENT) == 68,
		"saved by the backup: a renewal"
	)
	story.flags["ransom"] = "lost"
	story.fire({"kind": "callback_ransom"})
	_check(msp.emails[0].subject.contains("Reviewing"), "lost: the client reviews their provider")
	story.flags["install"] = "lost"
	sales.satisfaction[0] = 50
	story.fire({"kind": "callback_install"})
	_check(
		sales.mood(0) == 42 and msp.emails[0].from.contains("Patel"),
		"a lost xray setup is remembered"
	)
	var mails0: int = msp.emails.size()
	story.flags = {"rack": "S", "migration": "A"}
	story.fire({"kind": "callback_worst"})
	_check(msp.emails.size() == mails0, "no bad job: nothing to bring up")
	story.flags = {"rack": "S", "migration": "D", "email24": "B"}
	story.fire({"kind": "callback_worst"})
	_check(
		msp.emails[0].body.contains("server migration"), "day 20: Morgan brings up the worst job"
	)
	_check(
		story.DAYS.has(11) and story.DAYS[14].size() >= 2 and story.DAYS[20].size() >= 2,
		"the callbacks are scheduled (days 11, 14, 20)"
	)

	# ---- owner
	c.new_game("owner")
	_check(owner.path_label() != "", "a path label: " + owner.path_label())
	var books: Dictionary = owner.settle()
	var found := false
	for r in books.rows:
		found = found or str(r[0]) == "VALUE (ESTIMATE)"
	_check(found, "the weekly report shows a value estimate and path")
	_check(owner.at_risk_count() >= 0, "at-risk count works")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
