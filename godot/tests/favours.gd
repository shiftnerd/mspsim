extends SceneTree
# R36 (tech part): direct texts from a happy client that ask for unbilled work. Three answers (do it now / ask them to call the
# desk / ignore it), each with its own small consequence, a row in the day report, and Morgan raising it in a 1:1 after the
# third unbilled favour (promise, stand by it, or ask her to talk to the clients).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clean_close(msp: Node, client: int) -> Dictionary:
	var t: Dictionary = msp.create_problem(client, msp.PROBLEMS[0], "email", true)
	t["breached"] = false
	t["fix_done"] = true
	msp.close_ticket(int(t.id))
	return t


# close clean tickets of a client until a direct ask comes (or not)
func _until_ask(msp: Node, sales: Node, cards: Node, mood: int, tries: int) -> bool:
	for i in tries:
		msp.favour_day.clear()
		msp.thanked_day.clear()
		msp._favour_ask_day = -1
		sales.satisfaction[0] = mood
		_clean_close(msp, 0)
		if cards.is_open:
			return true
	return false


func _ids(cards: Node) -> Array:
	var out := []
	for o in cards.options:
		out.append(str(o.id))
	return out


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var cards := root.get_node("Cards")
	var story := root.get_node("Story")
	var world := root.get_node("World")
	var social := root.get_node("Social")
	var report := root.get_node("DayReport")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Career").toasts = false
	c.new_game("tech")
	root.get_node("Difficulty").set_tier("normal")
	root.get_node("Difficulty").seed_run(21)
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	world.time_scale = 0.0
	c.day = 6
	world.clock = 11.0
	msp.reset()

	# ---- who asks, and when
	_check(not _until_ask(msp, sales, cards, 60, 120), "a client below mood %d never texts for a favour" % msp.FAVOUR_MOOD)
	c.day = 3
	_check(not _until_ask(msp, sales, cards, 95, 120), "not in the first three days")
	c.day = 6
	var texts0: int = msp.texts.size()
	_check(_until_ask(msp, sales, cards, 95, 200), "a happy client sometimes texts your cell after a clean close")
	_check(_ids(cards) == ["fav_now", "fav_desk", "fav_ignore"], "the card has the three answers %s" % str(_ids(cards)))
	_check(str(cards.speaker) == "Dr. Patel (text)" and msp.texts.size() > texts0 and str(msp.texts[0].from) == "Dr. Patel", "it is a text from the client's contact (%s)" % str(cards.speaker))
	_check(str(msp.texts[0].body) == str(cards.text), "the phone shows the same message")

	# ---- do it now: no ticket, no credit, the queue gets older
	var open: Dictionary = msp.create_problem(3, msp.PROBLEMS[1], "email", true)
	var sla0: float = float(open.sla_left)
	var n0: int = msp.tickets.size()
	var score0: int = msp.score
	var closed0: int = msp.closed_ok
	var rep0: int = c.rep
	sales.satisfaction[0] = 80
	cards.pick(0)
	_check(msp.tickets.size() == n0 and msp.score == score0 and msp.closed_ok == closed0, "do it now: no ticket, no score, no closed count")
	_check(sales.mood(0) == 84, "the client is happier (+4)")
	_check(is_equal_approx(float(open.sla_left), sla0 - msp.FAVOUR_SECS), "every open ticket loses %d s of its clock" % int(msp.FAVOUR_SECS))
	_check(msp.favours_today == 1 and msp.favours_done() == 1 and c.rep == rep0, "it is counted as an unbilled favour, reputation unchanged")
	var r: Dictionary = c.make_report()
	_check(int(r.get("favours", 0)) == 1, "the day's report carries the count")
	report.report = r
	report.report["rep"] = c.rep
	var found := false
	for g in report._groups_raw():
		for row in g[1]:
			found = found or (str(row[0]) == "UNBILLED FAVOURS" and str(row[1]) == "1")
	_check(found, "the day report has an UNBILLED FAVOURS row")
	_check(_until_ask(msp, sales, cards, 95, 200), "another day, another ask")
	cards.pick(0)
	msp._favour_ask_day = c.day
	msp.favour_day.clear()
	var again := false
	for i in 80:
		sales.satisfaction[0] = 95
		_clean_close(msp, 0)
		again = again or cards.is_open
	_check(not again, "at most one direct ask a day")

	# ---- ask them to call the desk: a real ticket
	sales.satisfaction[1] = 80
	var morgan0: int = social.value("Morgan")
	n0 = msp.tickets.size()
	msp.ask_favour(1, 0)
	cards.pick(1)
	var made: Dictionary = msp.tickets[-1]
	_check(msp.tickets.size() == n0 + 1 and int(made.client) == 1 and int(made.pri) == 4 and str(made.fix) == "spooler", "call the desk: it becomes a real P4 ticket")
	_check(str(made.notes[-1]).contains("sent them to the desk") and str(made.status) != "Closed", "the ticket says how it came in")
	_check(sales.mood(1) == 78, "the client is a little put out (-2)")
	_check(msp.desk_sends_today == 1 and msp.favours_done() == 2, "it is not an unbilled favour")
	_check(social.value("Morgan") == morgan0 + 1, "Morgan likes it (+1)")

	# ---- ignore it: it comes back as a ticket the next morning
	sales.satisfaction[2] = 80
	n0 = msp.tickets.size()
	msp.ask_favour(2, 1)
	cards.pick(2)
	_check(sales.mood(2) == 77 and msp.tickets.size() == n0, "ignore it: mood -3, nothing in the queue today")
	var due: Array = story.flags.get("followups", [])
	_check(due.size() == 1 and int(due[0].due) == c.day + 1 and str(due[0].fix) == "password", "it is due tomorrow morning")
	c.day = 7
	msp.new_day(7)
	world.clock = 9.5
	story._spawn_followups()
	var late: Dictionary = msp.tickets[-1]
	_check(msp.tickets.size() == n0 + 1 and int(late.client) == 2 and int(late.pri) == 3 and str(late.body).contains("heard nothing"), "the next morning they call the desk themselves (a P3)")
	_check(msp.favours_today == 0, "the day's count starts again")

	# ---- Morgan raises it after the third favour
	_check(str(story.flags.get("favour_talk", "")) == "", "two favours: Morgan has said nothing")
	msp.ask_favour(4, 2)
	cards.pick(0)
	_check(msp.favours_done() == 3 and str(story.flags.get("favour_talk", "")) == "due", "the third favour: a 1:1 is due")
	world.clock = 11.0
	msp._tick_favour_talk()
	_check(not cards.is_open, "not on the same day")
	c.day = 8
	msp.new_day(8)
	world.clock = 9.5
	msp._tick_favour_talk()
	_check(not cards.is_open, "not before ten the next morning")
	world.clock = 10.1
	msp._tick_favour_talk()
	var asked: bool = cards.is_open and str(cards.speaker) == "Morgan (Manager)" and _ids(cards) == ["fav_log", "fav_fine", "fav_shield"]
	_check(asked, "the next morning Morgan asks about it (%s)" % str(cards.speaker))
	rep0 = c.rep
	texts0 = msp.texts.size()
	cards.pick(0)
	_check(c.rep == rep0 + 1 and str(story.flags.favour_talk) == "fav_log" and msp.texts.size() == texts0 + 1, "promise to send them to the desk: +1 reputation and her reply")
	msp._tick_favour_talk()
	_check(not cards.is_open, "she asks once")
	# the promise has teeth both ways
	rep0 = c.rep
	msp.ask_favour(5, 3)
	cards.pick(0)
	_check(c.rep == rep0 - 1 and str(msp.texts[0].body).contains("We talked about this"), "another favour after the promise: -1 reputation and a text from Morgan")
	rep0 = c.rep
	msp.ask_favour(6, 3)
	cards.pick(1)
	_check(c.rep == rep0 + 1, "sending one to the desk after the promise: +1 reputation")

	# ---- the other two answers
	story.flags["favour_talk"] = "due"
	story.flags["favour_talk_day"] = c.day - 1
	msp._tick_favour_talk()
	rep0 = c.rep
	cards.pick(1)
	_check(c.rep == rep0 - 1 and str(story.flags.favour_talk) == "fav_fine", "stand by it: -1 reputation")
	story.flags["favour_talk"] = "due"
	msp._tick_favour_talk()
	rep0 = c.rep
	var mails0: int = msp.emails.size()
	sales.satisfaction[4] = 80
	cards.pick(2)
	_check(c.rep == rep0 and int(story.flags.favour_quiet) == c.day + msp.FAVOUR_QUIET_DAYS, "ask Morgan to talk to them: no reputation change, quiet for %d days" % msp.FAVOUR_QUIET_DAYS)
	_check(msp.emails.size() == mails0 + 1 and sales.mood(4) == 79, "a policy mail goes out and those clients cool a little (-1)")
	_check(not _until_ask(msp, sales, cards, 95, 120), "no direct asks while it is quiet")
	c.day = int(story.flags.favour_quiet)
	_check(_until_ask(msp, sales, cards, 95, 200), "and they start again afterwards")
	cards.pick(2)

	# ---- saved with the campaign (Story.flags)
	_check(int(story.flags.get("favours", 0)) == msp.favours_done() and msp.favours_done() >= 4, "the run's count lives in Story.flags (%d)" % msp.favours_done())

	# ---- other campaigns never
	c.new_game("service")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	c.day = 6
	_check(not _until_ask(msp, sales, cards, 95, 60), "the service campaign has no direct asks")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
