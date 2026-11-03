extends SceneTree
# Tech campaign flow (headless): new game, close tickets, closing time, report, next day (saved),
# continue, the final day, free play not ending days. Saves go to user://test_*.cfg.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var report := root.get_node("DayReport")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	DirAccess.remove_absolute(c.save_path("tech"))
	_check(not c.has_save("tech"), "no save yet")

	c.new_game("tech")
	_check(c.active and c.day == 1 and c.rep == 50, "new tech campaign")
	_check(world.day == 1 and world.clock < 9.0, "morning of day 1")
	for k in 3:
		var t: Dictionary = msp.create_ticket(k, 0, "test")
		msp.rmm_action(t.endpoint, "spooler")
		msp.close_ticket(t.id)
	msp.create_ticket(4, 1, "test")  # left open
	world.clock = world.DAY_END
	await process_frame
	await process_frame
	_check(report.is_open and world.time_scale == 0.0, "closing time shows the report")
	var r: Dictionary = report.report
	_check(r.closed == 3 and r.open_left == 1 and r.missed == 0, "report counts: %s" % str(r))
	_check(r.pay == 100 + 3 * 20 and c.cash == r.pay, "paycheck")
	_check(c.rep == 53 and r.grade == "A", "reputation (the day gain is capped at 3) %d, grade %s" % [c.rep, r.grade])
	report.finish()
	await create_timer(0.8).timeout
	_check(c.day == 2 and c.has_save("tech") and c.saved_day("tech") == 2, "next day saved")
	_check(
		world.day == 2 and world.time_scale == 1.0 and not root.get_node("Game").ui_open,
		"day 2 morning"
	)

	c.day = 7
	c.rep = 60
	c.cash = 999
	c.save()
	c.new_game("free")
	_check(not c.active and not msp.enabled, "free play is not a campaign")
	world.clock = world.DAY_END + 1.0
	await process_frame
	await process_frame
	_check(not report.is_open, "free play never ends the day")
	_check(
		c.continue_game("tech") and c.day == 7 and c.rep == 60 and c.cash == 999,
		"continue loads the save"
	)
	_check(msp.tickets.is_empty() and msp.enabled, "continue starts clean")

	c.day = c.TOTAL_DAYS
	world.clock = world.DAY_END
	await process_frame
	await process_frame
	_check(
		(
			report.is_open
			and report.report.final
			and report.report.ending.begins_with("YEAR COMPLETE")
		),
		"final day ending"
	)
	report.finish()
	await process_frame
	var review := root.get_node("Review")
	_check(review.is_open and c.has_save("tech"), "day 20 leads to the yearly review")
	review.choose(review.offers.size() - 1)
	review.finish()
	await create_timer(0.5).timeout
	_check(not c.has_save("tech") and not c.active, "finished campaign clears the save")

	root.get_node("Game").title_mode = false  # the title scene set it when the campaign ended
	c.new_game("tech")
	c.rep = 3
	c._base = {"score": 0, "closed": 0, "missed": 0, "reopened": 0}
	msp.breached = 2
	world.clock = world.DAY_END
	await process_frame
	await process_frame
	_check(report.report.fired and report.report.final, "reputation 0 = fired")
	DirAccess.remove_absolute(c.save_path("tech"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
