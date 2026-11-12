extends SceneTree
# gdlint:disable=max-line-length
# The printer mini-game: pull the jam, install the toner, shake it, answer the test page; fewer mistakes = more stars.
# Also through an onsite printer job.

const DENY := ["hewlett", " hp ", "laserjet", "deskjet", "officejet", "designjet", "canon", "epson", "brother", "xerox", "ricoh", "kyocera", "lexmark", "konica", "minolta", "samsung", "okidata", "pixma", "zebra", "sharp"]

var failures := 0
var got := -1


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


# play one whole run on a model. perfect = no mistakes; otherwise: three torn pulls, a wrong tray, a wrong cartridge and wrong answers
func _play(pg: Node, perfect: bool, model := "laser") -> void:
	got = -1
	pg.start(func(stars: int) -> void: got = stars, model)
	pg.press("confirm")  # the intro
	var guard := 0
	var tears := 0
	while pg.phase == "jam" and guard < 40:
		if not perfect and tears < 3:
			pg.marker = pg.zone + 0.5 if pg.zone < 0.5 else pg.zone - 0.5
			tears += 1
		else:
			pg.marker = pg.zone
		pg.press("confirm")
		guard += 1
	if pg.phase == "tray":
		if not perfect:
			pg.tray_sel = 1
			pg.press("confirm")
		pg.tray_sel = 0
		pg.press("confirm")
	if pg.phase == "toner":
		var n: int = pg._names().size()
		if not perfect:
			pg.sel = (int(pg.order[pg.step]) + 1) % n
			pg.press("confirm")
		while pg.phase == "toner" and guard < 80:
			pg.sel = int(pg.order[pg.step])
			pg.press("confirm")
			guard += 1
	if pg.phase == "shake":
		for i in 10:
			pg.press("a" if i % 2 == 0 else "d")
	for i in 3:
		if pg.phase == "test":
			var q: Dictionary = pg.QUESTIONS[int(pg.asked[pg.qi])]
			pg.press(str(int(q.correct) + 1) if perfect else str((int(q.correct) + 1) % 3 + 1))
			pg.press("confirm")


# drive a run to its test page and return what was asked, the first zone and the cartridge order
func _to_test(pg: Node, opts: Dictionary) -> Array:
	pg.start(func(_s: int) -> void: pass, str(opts.get("model", "laser")), opts)
	pg.press("confirm")
	var first: float = pg.zone
	var guard := 0
	while pg.phase != "test" and guard < 60:
		match pg.phase:
			"jam":
				pg.marker = pg.zone
				pg.press("confirm")
			"tray":
				pg.tray_sel = 0
				pg.press("confirm")
			"toner":
				pg.sel = int(pg.order[pg.step])
				pg.press("confirm")
			"shake":
				for i in 10:
					pg.press("a" if i % 2 == 0 else "d")
		guard += 1
	var out: Array = [pg.asked.duplicate(), first, pg.order.duplicate()]
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")
	return out


# a road event with a choice can open a card on arrival (a random draw): skip it
func _skip_road(cards: Node) -> void:
	if cards.is_open and str(cards.options[0].get("id", "")) == "help":
		cards.pick(1)


func _init() -> void:
	await process_frame
	var pg := root.get_node("PrinterGame")
	var on := root.get_node("Onsite")
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	# the tier lives in a settings file the other tests (tiers_balance, the bots) also write: use a private one and the normal tier
	root.get_node("Difficulty").settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	root.get_node("Difficulty").set_tier("normal")
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
	_skip_road(cards)
	on.interact("printer")
	_check(
		(
			cards.is_open
			and cards.options.size() == 4
			and cards.options[3].label == "OPEN IT UP AND FIGHT IT"
		),
		"the printer job offers to fight it (open %s, %s)" % [cards.is_open, str(cards.options.map(func(o): return str(o.label)))]
	)
	cards.pick(3)
	_check(cards.is_open and cards.options.size() == 5 and cards.options[4].label == "NO BAG, JUST THE TOOLS", "P6: first the bag: four bags and no bag")
	cards.pick(4)  # no bag: the stars are the plain count
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
	# the architects' printer is a plotter: its own texts, rolls and questions; the laser keeps the defaults
	pg.start(func(_s: int) -> void: pass, "plotter")
	_check(pg._tx("title") == "PLOTTER REPAIR" and pg._tx("done") == pg.TEXT.done, "plotter texts overlay the defaults")
	pg.press("confirm")
	_check(pg._tray()[0] == "24 BOND", "the plotter loads rolls, not paper")
	pg._begin_test()
	var plot_ok := true
	for k in pg.asked:
		plot_ok = plot_ok and (pg.QUESTIONS[k].models.is_empty() or pg.QUESTIONS[k].models.has("plotter"))
	_check(plot_ok, "the plotter asks plotter (or general) questions")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")
	pg.start(func(_s: int) -> void: pass)
	_check(pg._tx("title") == "PRINTER REPAIR" and pg.model == "laser", "an ordinary printer keeps the defaults")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")
	await _models(pg, on, game)
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


func _bad_words(text: String) -> String:
	var low := " " + text.to_lower() + " "
	for w in DENY:
		if low.contains(w):
			return w
	return ""


func _models(pg: Node, on: Node, _game: Node) -> void:
	var diff := root.get_node("Difficulty")
	# the content tables
	_check(pg.QUESTIONS.size() >= 28, "28 or more questions (%d)" % pg.QUESTIONS.size())
	var tidy := true
	var long := ""
	var brand := ""
	for q in pg.QUESTIONS:
		tidy = tidy and q.options.size() == 3 and int(q.correct) >= 0 and int(q.correct) < 3
		tidy = tidy and (int(q.hit) == -1 or (int(q.hit) >= 0 and int(q.hit) < 3 and int(q.hit) != int(q.correct)))
		tidy = tidy and int(q.hard) >= 0 and int(q.hard) <= 2
		for m in q.models:
			tidy = tidy and pg.MODELS.has(m)
		if str(q.error).length() > 36 or str(q.why).length() > 112:
			long = str(q.error)
		for o in q.options:
			if str(o).length() > 36:
				long = str(o)
		brand += " " + str(q.error) + " " + " ".join(q.options) + " " + str(q.why)
	_check(tidy, "every question has three options, a valid correct / hit / hard and known models")
	_check(long == "", "every question fits the display (%s)" % long)
	for m in pg.MODEL_TEXT:
		for k in pg.MODEL_TEXT[m]:
			brand += " " + str(pg.MODEL_TEXT[m][k])
	for k in pg.TEXT:
		brand += " " + str(pg.TEXT[k])
	for m in pg.MODEL_PRAYERS:
		for k in pg.MODEL_PRAYERS[m]:
			brand += " " + " ".join(pg.MODEL_PRAYERS[m][k])
	_check(_bad_words(brand) == "", "no real brand names in the printer texts (%s)" % _bad_words(brand))
	var overs := true
	for m in pg.MODEL_TEXT:
		overs = overs and pg.MODELS.has(m)
	for m in pg.MODEL_PRAYERS:
		overs = overs and pg.MODELS.has(m)
	_check(overs, "every text and prayer overlay is for a known model")
	var wide := ""
	for m in pg.MODEL_TEXT:
		for k in ["intro1", "intro2"]:
			if str(pg.MODEL_TEXT[m].get(k, "")).length() > 42:
				wide = m + "." + k
	_check(wide == "" and pg.TEXT.intro1.length() <= 42 and pg.TEXT.intro2.length() <= 42, "intro lines fit the panel (%s)" % wide)
	for m in pg.MODEL_ORDER:
		var pool: Array = pg.pool_for(m)
		var seen := {}
		var dup := false
		for k in pool:
			dup = dup or seen.has(str(pg.QUESTIONS[k].error))
			seen[str(pg.QUESTIONS[k].error)] = true
		_check(not dup and pool.size() >= 6, "%s: %d questions, no duplicate error" % [m, pool.size()])
	# every model finishes, perfect and failed
	for m in pg.MODEL_ORDER:
		_play(pg, true, m)
		_check(pg.phase == "result" and pg.mistakes == 0 and pg.stars == 3, "%s: a perfect run is three stars (%d mistakes, %s)" % [m, pg.mistakes, pg.phase])
		pg._result_t = 1.0
		pg.press("confirm")
		_check(not pg.is_open and got == 3, "%s: closing hands back 3 stars" % m)
		_play(pg, false, m)
		_check(pg.phase == "result" and pg.stars <= 1 and pg.mistakes >= 5, "%s: a failed run ends with 0 or 1 star (%d mistakes, %s)" % [m, pg.mistakes, pg.phase])
		pg._result_t = 1.0
		pg.press("confirm")
	# a seed gives the same questions; another seed does not always
	diff.set_tier("normal")
	var same := true
	var differs := false
	for sd in [11, 12, 13, 14, 15, 16]:
		diff.seed_run(sd)
		pg.start(func(_s: int) -> void: pass, "mfp")
		pg._begin_test()
		var a1: Array = pg.asked.duplicate()
		diff.seed_run(sd)
		pg.start(func(_s: int) -> void: pass, "mfp")
		pg._begin_test()
		same = same and a1 == pg.asked
		diff.seed_run(sd + 100)
		pg.start(func(_s: int) -> void: pass, "mfp")
		pg._begin_test()
		differs = differs or a1 != pg.asked
		pg.press("escape")
		pg._result_t = 1.0
		pg.press("confirm")
	_check(same, "the same seed asks the same questions")
	_check(differs, "other seeds ask other questions")
	# tiers: how many questions, how long the jam chain, and easier tiers hold back the hard ones
	var counts := []
	for t in diff.TIERS:
		diff.set_tier(t)
		pg.start(func(_s: int) -> void: pass, "laser")
		pg._begin_test()
		counts.append(pg.asked.size())
		var ok_tier := true
		for k in pg.asked:
			ok_tier = ok_tier and int(pg.QUESTIONS[k].hard) <= diff.tier_index()
		_check(ok_tier, "%s tier: no question above its level" % t)
		pg._begin_jam()
		_check(pg.jam_len == int(diff.at("printer.chain", t)), "%s: jam chain of %d" % [t, pg.jam_len])
		pg.press("escape")
		pg._result_t = 1.0
		pg.press("confirm")
	_check(counts == [1, 2, 3], "1 / 2 / 3 questions by tier (%s)" % str(counts))
	# the jam chain: a tear adds a pull (to 6), two clean pulls take one off (never under 3)
	diff.set_tier("hard")
	pg.start(func(_s: int) -> void: pass)
	pg._begin_jam()
	_check(pg.jam_len == 5, "hard starts with five pulls")
	pg.marker = pg.zone
	pg.press("confirm")
	pg.marker = pg.zone
	pg.press("confirm")
	_check(pg.jam_len == 4 and pg.spot == 2, "two clean pulls in a row shorten the chain")
	pg.marker = pg.zone + 0.5 if pg.zone < 0.5 else pg.zone - 0.5
	pg.press("confirm")
	_check(pg.jam_len == 5 and pg.mistakes == 1 and pg.combo == 0, "a tear leaves a scrap: one more pull")
	for i in 5:
		pg.marker = pg.zone + 0.5 if pg.zone < 0.5 else pg.zone - 0.5
		pg.press("confirm")
	_check(pg.jam_len == 6, "the chain never grows past six")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")
	diff.set_tier("normal")
	# tiredness: only on an onsite job, up to 15 percent
	var shift := root.get_node("Shift")
	shift.enabled = true
	shift.energy = 10.0
	pg.start(func(_s: int) -> void: pass, "laser")
	_check(is_equal_approx(pg.tired, 1.0), "tired does nothing off the job")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")
	pg.start(func(_s: int) -> void: pass, "laser", {"onsite": true})
	var expect := 1.0 + clampf(shift.slow_mult() - 1.0, 0.0, 0.5) * 0.3
	_check(pg.tired > 1.0 and pg.tired <= 1.1501 and is_equal_approx(pg.tired, expect), "tired speeds the marker by up to 15 percent (%.3f)" % pg.tired)
	pg.phase = "jam"
	pg.marker = 0.0
	pg._dir = 1.0
	pg.spot = 0
	root.get_node("Career").reset_all()  # mastery 0: the table speed
	pg._process(0.1)
	_check(is_equal_approx(pg.marker, 0.08 * pg.tired), "the marker really runs faster when tired")
	pg.press("escape")
	pg._result_t = 1.0
	pg.press("confirm")
	shift.enabled = false
	shift.energy = 80.0
	# prayers and the no-prayer streak
	var own := true
	for m in pg.MODEL_PRAYERS:
		pg.start(func(_s: int) -> void: pass, m)
		own = own and pg._prayers() == pg.MODEL_PRAYERS[m]
		pg.press("escape")
	pg.start(func(_s: int) -> void: pass, "laser")
	own = own and pg._prayers() == pg.PRAYERS
	pg.press("escape")
	_check(own, "each model prays to its own gods")
	pg.reset()
	_play(pg, true, "laser")
	pg._result_t = 1.0
	pg.press("confirm")
	_play(pg, true, "dot")
	pg._result_t = 1.0
	pg.press("confirm")
	_check(pg.streak == 2, "two pray-free wins make a streak of two (%d)" % pg.streak)
	var saved: Dictionary = pg.to_dict()
	pg.reset()
	pg.from_dict(saved)
	_check(pg.streak == 2, "the streak is saved")
	pg.start(func(_s: int) -> void: pass, "laser")
	pg.press("confirm")
	pg.press("pray")
	pg.press("escape")
	_check(pg.streak == 0, "a prayer (or a lost run) ends the streak")
	pg._result_t = 1.0
	pg.press("confirm")
	# practice: model and seed on the intro page
	pg.start(func(_s: int) -> void: pass, "laser", {"practice": true, "seed": 7})
	pg.press("right")
	pg.press("right")
	_check(pg.model == "plotter" and pg.phase == "intro", "practice: right arrow picks the next model")
	pg.press("up")
	_check(pg.practice_seed == 8, "practice: up raises the seed")
	pg.press("escape")
	var r1 := _to_test(pg, {"model": "inkjet", "practice": true, "seed": 9})
	var r2 := _to_test(pg, {"model": "inkjet", "practice": true, "seed": 9})
	var r3 := _to_test(pg, {"model": "inkjet", "practice": true, "seed": 10})
	_check(r1 == r2, "practice with the same model and seed repeats the run")
	_check(r1 != r3, "another practice seed is another run")
	# the site decides the model
	var picks := {9: ["plotter"], 3: ["mfp"], 8: ["inkjet"], 10: ["dot"], 0: ["receipt", "laser"], 1: ["laser", "dot"]}
	var all_ok := true
	for c in picks:
		on.client = c
		all_ok = all_ok and picks[c].has(on._printer_model())
	_check(all_ok, "Onsite picks the model from the site type")
	on.client = 3
	_check(on._printer_model("printer:inkjet") == "inkjet", "a job can force a model with game: printer:model")
	var seen_m := {}
	for d in range(1, 12):
		root.get_node("Campaign").day = d
		on.client = 0
		seen_m[on._printer_model()] = true
	_check(seen_m.size() == 2, "the dentist's printer is sometimes a receipt printer, sometimes a laser")
