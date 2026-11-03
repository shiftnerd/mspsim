extends SceneTree
# gdlint:disable=max-line-length
# The printer mini-game: pull the jam, install the toner, shake it, answer the test page; fewer mistakes = more stars.
# Also through an onsite printer job.

var failures := 0
var got := -1


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _play(pg: Node, perfect: bool) -> void:
	got = -1
	pg.start(func(stars: int) -> void: got = stars)
	pg.press("confirm")  # the intro
	var guard := 0
	while pg.phase == "jam" and guard < 12:
		pg.marker = pg.zone if perfect else (pg.zone + 0.5 if pg.zone < 0.5 else pg.zone - 0.5)
		pg.press("confirm")
		guard += 1
	if pg.phase == "tray":
		if not perfect:
			pg.tray_sel = 1
			pg.press("confirm")
		pg.tray_sel = 0
		pg.press("confirm")
	if pg.phase == "toner":
		while pg.phase == "toner" and guard < 30:
			pg.sel = int(pg.order[pg.step]) if perfect else (int(pg.order[pg.step]) + 1) % 4
			pg.press("confirm")
			if not perfect and pg.mistakes > 8:
				break
			guard += 1
	if pg.phase == "shake":
		for i in 10:
			pg.press("a" if i % 2 == 0 else "d")
	for i in 2:
		if pg.phase == "test":
			var q: Dictionary = pg.QUESTIONS[int(pg.asked[pg.qi])]
			pg.press(str(int(q.correct) + 1) if perfect else str((int(q.correct) + 1) % 3 + 1))
			pg.press("confirm")


func _init() -> void:
	await process_frame
	var pg := root.get_node("PrinterGame")
	var on := root.get_node("Onsite")
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)

	# a perfect run
	_play(pg, true)
	_check(
		pg.phase == "result" and pg.mistakes == 0 and pg.stars == 3,
		"a perfect run is three stars (%d mistakes)" % pg.mistakes
	)
	pg._result_t = 1.0
	pg.press("confirm")
	_check(
		not pg.is_open and got == 3 and not game.ui_open,
		"closing hands the stars back and gives the screen back"
	)

	# a bad run
	_play(pg, false)
	_check(
		pg.mistakes >= 5 and pg.stars <= 1,
		"a bad run is 0 or 1 stars (%d mistakes, %d stars)" % [pg.mistakes, pg.stars]
	)
	pg.press("confirm")

	# PC LOAD LETTER: the display says it and you load the right paper
	pg.start(func(_s: int) -> void: pass)
	pg.press("confirm")
	for i in 3:
		pg.marker = pg.zone
		pg.press("confirm")
	_check(pg.phase == "tray", "after the jam the display says PC LOAD LETTER")
	pg.tray_sel = 2
	pg.press("confirm")
	_check(pg.phase == "tray" and pg.mistakes == 1, "A4 is the wrong paper")
	pg.tray_sel = 0
	pg.press("confirm")
	_check(pg.phase == "toner", "LETTER paper solves it")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")

	# praying to the sysadmin gods
	var blessings := 0
	var curses := 0
	for n in 200:
		pg.start(func(_s: int) -> void: pass)
		pg.press("pray")
		blessings += pg.blessed
		curses += pg.mistakes
		if n == 0:
			_check(pg.faith == 2, "a prayer costs one of three")
		pg.press("escape")
		pg.press("confirm")
	_check(
		blessings > 70 and blessings < 150 and curses > 5 and curses < 50,
		"prayers help more than they hurt (%d blessings, %d curses in 200)" % [blessings, curses]
	)
	pg.start(func(_s: int) -> void: pass)
	pg.faith = 0
	pg.press("pray")
	_check(pg.faith == 0 and pg.msg == str(pg.TEXT.pray_none), "out of faith")
	pg.blessed = 1
	pg._mistake()
	_check(pg.mistakes == 0 and pg.blessed == 0, "a blessing forgives the next mistake")
	pg._mistake()
	_check(pg.mistakes == 1, "then they count again")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")

	# giving up (after starting) and backing out (before)
	got = -1
	pg.start(func(stars: int) -> void: got = stars)
	pg.press("confirm")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")
	_check(got == 0, "Esc gives up with zero stars")
	got = -5
	pg.start(func(stars: int) -> void: got = stars)
	pg.press("escape")
	_check(got == -1 and not pg.is_open, "Esc on the intro backs out for free")

	# the shake can run out of time
	pg.start(func(_s: int) -> void: pass)
	pg.press("confirm")
	pg._begin_shake()
	pg._shake_t = 0.0
	pg._process(0.1)
	_check(pg.phase == "test" and pg.mistakes == 1, "too slow a shake costs a mistake")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")

	# an onsite printer job: the fourth option is the mini-game
	c.day = 6
	var t: Dictionary = on.create_job(3, "printer")
	_check(not t.is_empty(), "a printer ticket at the law office")
	on.offer(int(t.id))
	cards.pick(0)
	await _wait(1.2)
	on.interact("printer")
	_check(
		(
			cards.is_open
			and cards.options.size() == 4
			and cards.options[3].label == "OPEN IT UP AND FIGHT IT"
		),
		"the printer job offers to fight it"
	)
	cards.pick(3)
	_check(pg.is_open, "the mini-game opens")
	_play_open(pg)
	pg._result_t = 1.0
	pg.press("confirm")
	_check(on.done, "winning fixes the printer and the ticket")
	while cards.is_open:
		cards.pick(0)
	_check(str(t.status) == "Closed", "the ticket is closed")
	on.interact("door")
	await _wait(1.2)

	# practice in Free Play (no ticket)
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	game.go("site_law_a", "start")
	await _wait(1.0)
	on.interact("printer")
	_check(
		cards.is_open and cards.options.size() == 2,
		"with no ticket you can practise on the printer"
	)
	cards.pick(1)
	# the architects' printer is a plotter: its own texts and questions, the ordinary printer keeps the defaults
	pg.start(func(_s: int) -> void: pass, "plotter")
	_check(pg._tx("title") == "PLOTTER REPAIR" and pg._tx("done") == pg.TEXT.done, "plotter texts overlay the defaults")
	pg.press("confirm")
	_check(pg._tray()[0] == "24 IN BOND", "the plotter loads rolls, not paper")
	pg._begin_test()
	_check(pg._qs() == pg.PLOTTER_QUESTIONS, "the plotter asks plotter questions")
	pg.press("escape")
	pg.start(func(_s: int) -> void: pass)
	_check(pg._tx("title") == "PRINTER REPAIR" and pg._qs() == pg.QUESTIONS, "an ordinary printer keeps the defaults")
	pg.press("escape")
	on.client = 9
	_check(on._printer_kind() == "plotter", "Onsite passes the plotter kind at the architects")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func _play_open(pg: Node) -> void:
	pg.press("confirm")
	var guard := 0
	while pg.phase == "jam" and guard < 12:
		pg.marker = pg.zone
		pg.press("confirm")
		guard += 1
	if pg.phase == "tray":
		pg.tray_sel = 0
		pg.press("confirm")
	while pg.phase == "toner" and guard < 30:
		pg.sel = int(pg.order[pg.step])
		pg.press("confirm")
		guard += 1
	if pg.phase == "shake":
		for i in 10:
			pg.press("a" if i % 2 == 0 else "d")
	for i in 2:
		if pg.phase == "test":
			var q: Dictionary = pg.QUESTIONS[int(pg.asked[pg.qi])]
			pg.press(str(int(q.correct) + 1))
			pg.press("confirm")
