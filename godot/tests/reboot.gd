extends SceneTree
# Rebooting: the spooler ticket's proper fix is restarting the service, a reboot also works but
# interrupts the user, and anyone with unsaved work who was not asked to save loses it.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _spooler(msp: Node, unsaved: bool) -> Dictionary:
	msp.reset()
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	var ep: Dictionary = msp.endpoint(t.endpoint)
	ep.unsaved = unsaved
	ep.asked = false
	root.get_node("Sales").satisfaction[0] = 70
	return t


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	c.save_prefix = "user://test_"
	root.get_node("Game").title_mode = false
	c.new_game("tech")

	# the proper fix: no side effects
	var t := _spooler(msp, true)
	var ep: Dictionary = msp.endpoint(t.endpoint)
	var res: String = msp.rmm_action(ep.name, "spooler")
	_check(
		res.contains("spooler restarted") and sales.mood(0) == 70,
		"restarting the spooler: fixed, nobody is bothered"
	)
	_check(msp.ticket(t.id).fix_done, "...and the ticket is fixed")

	# reboot without asking, with unsaved work
	t = _spooler(msp, true)
	ep = msp.endpoint(t.endpoint)
	var score0: int = msp.score
	var mails0: int = msp.emails.size()
	res = msp.rmm_action(ep.name, "reboot")
	_check(res.contains("LOST UNSAVED WORK"), "reboot without asking: " + res)
	_check(msp.ticket(t.id).fix_done and ep.problem == "", "the reboot did clear the spooler")
	_check(
		sales.mood(0) == 62,
		"the client is upset: -2 for the interruption, -6 for the lost work (%d)" % sales.mood(0)
	)
	_check(msp.score == score0 - 3, "and the score takes a hit")
	_check(
		msp.emails.size() == mails0 + 1 and msp.emails[0].subject == "I LOST MY WORK!",
		"an angry email arrives"
	)

	# ask first
	t = _spooler(msp, true)
	ep = msp.endpoint(t.endpoint)
	res = msp.rmm_action(ep.name, "save")
	_check(res.contains("SAVED") and ep.asked, "asking the user to save: " + res)
	res = msp.rmm_action(ep.name, "reboot")
	_check(
		not res.contains("LOST") and res.contains("QUIETER") and sales.mood(0) == 68,
		"reboot after asking: no work lost, but a small interruption (%d)" % sales.mood(0)
	)
	_check(msp.ticket(t.id).notes.size() >= 3, "the ticket notes tell the story")

	# nothing to lose
	t = _spooler(msp, false)
	ep = msp.endpoint(t.endpoint)
	res = msp.rmm_action(ep.name, "reboot")
	_check(not res.contains("LOST") and sales.mood(0) == 68, "no unsaved work: nothing lost")
	t = _spooler(msp, false)
	ep = msp.endpoint(t.endpoint)
	_check(
		msp.rmm_action(ep.name, "save").contains("NOTHING OPEN"), "asking someone with nothing open"
	)

	# the blue screen: nothing to save
	msp.reset()
	t = msp.create_ticket(0, 3, "test")
	ep = msp.endpoint(t.endpoint)
	sales.satisfaction[0] = 70
	ep.unsaved = true
	res = msp.rmm_action(ep.name, "reboot")
	_check(
		res.contains("Rebooted") and sales.mood(0) == 70,
		"a blue-screened PC has nothing to lose: the reboot is its fix"
	)

	# a needless reboot of a machine with another problem
	msp.reset()
	t = msp.create_ticket(0, 2, "test")
	ep = msp.endpoint(t.endpoint)
	ep.unsaved = true
	sales.satisfaction[0] = 70
	res = msp.rmm_action(ep.name, "reboot")
	_check(
		res.contains("NOTHING CHANGED") and res.contains("LOST") and ep.problem == "clear_temp",
		"rebooting for the wrong reason fixes nothing and costs their work"
	)
	_check(msp.FIXES.has("save") and msp.ALT_FIXES["spooler"].has("reboot"), "the tables")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
