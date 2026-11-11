extends SceneTree
# gdlint:disable=max-line-length
# T2 / Q6: the clean-day rule of the tech campaign's day report, the loose-ends count behind it and the displaced-ticket fix.
#   - under reputation CLEAN_REP the day report is as before
#   - from CLEAN_REP on a day with too many loose ends (SLAs missed, reopens, plain tickets left in the queue: more than one
#     for every CLEAN_PER tickets closed) adds nothing; from SLOPPY_REP on it costs SLOPPY_PER a loose end too many, at most
#     SLOPPY_MAX; the report carries a note
#   - a clean day is untouched, and so are the hard tier, the cozy easy tier and the other campaigns
#   - Msp.loose_open leaves out the jobs that run over days and the tickets whose clock already ran out
#   - a ticket whose machine is taken over by a bigger job (the ransomware on a server that already had one) counts as done
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/clean_day.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# a day report for a made-up day: `closed` closes, `missed` SLAs missed, `open` plain tickets left in the queue
func _day(tier: String, rep: int, closed: int, missed: int, open: int, mode := "tech") -> Dictionary:
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var d := root.get_node("Difficulty")
	d.set_tier(tier)
	d.seed_run(77)
	load("res://scripts/player.gd").current_character = "office_dan" if mode == "service" else "office_intern"
	c.new_game(mode)
	root.get_node("Cards").flush()
	msp.enabled = false
	c.rep = rep
	msp.closed_ok += closed
	msp.breached += missed
	msp.score += closed * 10
	for i in open:
		msp.spawned_today = 0
		msp.created_today = 0
		msp._random_ticket("test")
	return c._make_report()


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var d := root.get_node("Difficulty")
	var story := root.get_node("Story")
	c.save_prefix = "user://test_%d_clean_" % OS.get_process_id()
	d.settings_path = "user://test_%d_clean_settings.cfg" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	# ---- the arithmetic
	_check(c.clean_day(12, 2) and not c.clean_day(11, 2) and c.clean_day(0, 0) and not c.clean_day(5, 1), "one loose end is forgiven for every %d closed" % c.CLEAN_PER)
	_check(c.loose_excess(7, 4) == 3 and c.loose_excess(12, 1) == -1, "loose_excess counts the loose ends beyond the allowance")
	_check(d.at("tech.clean", "normal") > 0.0 and d.at("tech.clean", "hard") == 0.0 and d.at("tech.clean", "easy") == 0.0, "tech.clean is on at normal only")
	# ---- the day report
	var low: Dictionary = _day("normal", c.CLEAN_REP - 4, 7, 2, 2)
	_check(int(low.rep_delta) > 0 and not bool(low.sloppy), "under %d a busy day with loose ends still adds reputation (%+d)" % [c.CLEAN_REP, int(low.rep_delta)])
	var mid: Dictionary = _day("normal", c.CLEAN_REP, 7, 2, 2)
	_check(int(mid.rep_delta) == 0 and bool(mid.sloppy), "from %d on the same day adds nothing (%+d)" % [c.CLEAN_REP, int(mid.rep_delta)])
	var high: Dictionary = _day("normal", c.SLOPPY_REP + 10, 7, 1, 1)
	var want: int = -clampi(c.SLOPPY_PER * c.loose_excess(7, 2), c.SLOPPY_PER, c.SLOPPY_MAX)
	_check(int(high.rep_delta) == want and want < 0, "from %d on it costs %d a loose end too many (%+d)" % [c.SLOPPY_REP, c.SLOPPY_PER, int(high.rep_delta)])
	var awful: Dictionary = _day("normal", 90, 6, 4, 6)
	_check(int(awful.rep_delta) == -c.SLOPPY_MAX and int(awful.rep_delta) < want, "a worse day costs more, never more than %d (%+d)" % [c.SLOPPY_MAX, int(awful.rep_delta)])
	var slip: Dictionary = _day("normal", 80, 12, 1, 1)
	_check(int(slip.rep_delta) > 0 and not bool(slip.sloppy), "a good day with a slip or two is still a clean day (%+d)" % int(slip.rep_delta))
	var clean: Dictionary = _day("normal", 80, 9, 0, 0)
	_check(int(clean.rep_delta) == c.daily_cap() and not bool(clean.sloppy), "a clean day earns the daily cap (%+d)" % int(clean.rep_delta))
	var quiet: Dictionary = _day("normal", 80, 0, 0, 0)
	_check(not bool(quiet.sloppy), "a day with nothing to do is not sloppy")
	var hard: Dictionary = _day("hard", 80, 7, 2, 2)
	_check(not bool(hard.sloppy) and int(hard.rep_delta) > 0, "the hard tier has no clean-day rule (%+d before its own multiplier)" % int(hard.rep_delta))
	var easy: Dictionary = _day("easy", 80, 7, 2, 2)
	_check(not bool(easy.sloppy), "nor has the cozy easy tier")
	var service: Dictionary = _day("normal", 80, 7, 2, 2, "service")
	_check(not bool(service.get("sloppy", false)), "nor has the service campaign")
	# ---- the note reaches the report
	_day("normal", 80, 7, 2, 2)
	c._end_day()
	await process_frame
	var report := root.get_node("DayReport")
	_check(report.is_open and report.report.get("notes", []).has(c.SLOPPY_NOTE_LOSS), "a sloppy day's report says why the reputation slipped")
	_check(int(report.report.rep) < 80, "and the reputation went down (%d)" % int(report.report.rep))
	report.is_open = false
	report._canvas.visible = false
	root.get_node("Game").ui_open = false
	# ---- loose_open
	d.set_tier("normal")
	d.seed_run(78)
	c.new_game("tech")
	root.get_node("Cards").flush()
	msp.enabled = false
	msp.spawned_today = 0
	msp.created_today = 0
	var a: Dictionary = msp._random_ticket("test")
	msp.spawned_today = 0
	msp.created_today = 0
	var b: Dictionary = msp._random_ticket("test")
	_check(msp.loose_open() == 2, "two plain open tickets are two loose ends")
	b["breached"] = true
	_check(msp.loose_open() == 1, "a ticket whose clock already ran out is counted as missed, not again as loose")
	a["special"] = "rack"
	_check(msp.loose_open() == 0, "a story job is not a loose end")
	a["special"] = ""
	a["fix"] = "project"
	_check(msp.loose_open() == 0, "nor is the install project")
	msp.close_ticket(int(b.id))
	# ---- a displaced ticket: a server ticket, then the ransomware on the same server
	d.seed_run(79)
	c.new_game("tech")
	root.get_node("Cards").flush()
	msp.enabled = false
	var srv: Dictionary = msp.create_problem(story.RANSOM_CLIENT, {"summary": "Server not responding", "fix": "reboot", "pri": 1, "body": "%s here. The server is down.", "server": true}, "test")
	_check(not srv.is_empty() and not bool(srv.fix_done), "a server ticket at the ransomware client")
	story._ransomware()
	var ransom: Dictionary = msp.ticket(int(story.flags.get("ransom_ticket", 0)))
	_check(not ransom.is_empty() and str(ransom.endpoint) == str(srv.endpoint), "the ransomware lands on the same server")
	_check(bool(srv.fix_done), "the older ticket counts as done (it could never be fixed by its own fix again)")
	var closed0: int = msp.closed_ok
	msp.close_ticket(int(srv.id))
	_check(str(srv.status) == "Closed" and msp.reopened == 0 and msp.closed_ok == closed0 + 1, "and closes cleanly")
	c.quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
