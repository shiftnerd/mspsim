extends SceneTree
# gdlint:disable=max-line-length
# R30: the dinner ramp. Dinner has no timers or sweet spots, so its mastery ramp is three Difficulty keys in MASTERY_KEYS that go
# through the same hooks as the other games (Career "good.dinner", Difficulty.mastery / blend / f):
#   dinner.expect  points per diner on the 3 and 2 star bars (after good dinners the table expects more)
#   dinner.fits    how many of the four shared plates suit everybody (the ordering round)
#   dinner.hints   the share of the tastes you know that is marked on the topic list (fewer free hints)
# A first play, a fixed take and a fresh career use exactly the old numbers; the ramp stays fair (best play still gets 2+ stars).
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/dinner_ramp.gd`

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _start(o: Node, table: Array, variety := true) -> void:
	if o.is_open:
		o.close()
	o.start("dinner", false, {"party": table, "variety": variety})
	o.begin_play()


func _fit_count(o: Node) -> int:
	var n := 0
	for id in o.g.order.plates:
		n += 1 if o.dish_clash(str(id)).is_empty() else 0
	return n


func _best_dinner(o: Node, d: Node, seed_n: int, table: Array) -> int:
	d.seed_run(seed_n)
	o.reset()
	_start(o, table)
	for i in 4:
		if o.dish_clash(str(o.g.order.plates[i])).is_empty():
			o.dinner_order(i)
			break
	for round_no in 5:
		var pick := 0
		var top := -1
		for i in 4:
			var pts := 0
			for who in o.diners():
				pts += o.diner_points(who, o.g.options[i])
			if pts > top:
				top = pts
				pick = i
		o.dinner_talk(pick)
		o.tick(4.0)
	var result: int = o.stars
	o.press(KEY_ENTER)
	return result


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var career := root.get_node("Career")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	career.reset_all()
	d.fixed_take = false
	c.new_game("free")
	root.get_node("World").time_scale = 1.0
	d.set_tier("normal")
	var trio := ["Alan", "Garrison", "Dan"]
	var five := ["Alan", "Garrison", "Dan", "John", "Maya"]

	# ---- the keys go through the shared hooks
	for key in ["dinner.expect", "dinner.fits", "dinner.hints"]:
		_check(d.MASTERY_KEYS.has(key) and d.game_of(key) == "dinner", "%s is a mastery key of dinner" % key)
	_check(not d.MASTERY_KEYS.has("dinner.reveal"), "dinner.reveal (a count) stays fixed")
	_check(d.mastery("dinner") == 0.0 and is_equal_approx(d.f("dinner.expect"), 0.0) and is_equal_approx(d.f("dinner.fits"), 2.0) and is_equal_approx(d.f("dinner.hints"), 1.0), "a fresh career: the table's numbers")

	# ---- a first play is the classic dinner
	d.seed_run(5)
	o.reset()
	_start(o, trio, false)
	var bars0: Array = o.dinner_targets()
	var shifts := 0
	for who in o.diners():
		shifts += o.diner_shift(who)
	_check(bars0[0] == 22 + 3 * shifts and bars0[1] == 15 + 3 * shifts and bars0[2] == 10 + 3 * shifts, "first play: the classic bars (22 / 15 / 10 plus the moods): %s" % str(bars0))
	_start(o, trio)
	_check(_fit_count(o) == 2, "first play: two plates suit everybody")

	# ---- good dinners count, through the real finish path
	d.seed_run(5)
	o.reset()
	_start(o, trio)
	o.g.score = 99
	o._dinner_end()
	_check(o.stars == 3 and int(career.value("good.dinner")) == 1 and is_equal_approx(d.mastery("dinner"), 0.1), "a three star dinner counts once")
	_check(" ".join(o.lines).contains("MASTERY 1/10"), "the result page carries the mastery line for dinner now: %s" % str(o.lines))
	o.press(KEY_ENTER)
	_start(o, trio)
	o.g.score = 0
	o._dinner_end()
	o.press(KEY_ENTER)
	_start(o, trio)
	o._finish(-1)
	o.press(KEY_ENTER)
	_check(int(career.value("good.dinner")) == 1, "a poor dinner and leaving early do not count")

	# ---- the ramp: monotonic, and what it does at full mastery
	var prev_bar := -1
	var prev_fits := 9
	var prev_hint := 2.0
	var mono := true
	for k in range(0, 11):
		career.counters["good.dinner"] = k
		d.seed_run(5)
		o.reset()
		_start(o, five)
		var bar: int = o.dinner_targets()[0]
		var fits := _fit_count(o)
		var hint: float = d.f("dinner.hints")
		mono = mono and bar >= prev_bar and fits <= prev_fits and hint <= prev_hint + 0.0001
		prev_bar = bar
		prev_fits = fits
		prev_hint = hint
	_check(mono, "more good dinners never loosen anything (bars up, fitting plates down, hints down)")
	career.counters["good.dinner"] = 10
	d.seed_run(5)
	o.reset()
	_start(o, trio, false)
	var bars1: Array = o.dinner_targets()
	_check(bars1[0] == bars0[0] + 1 and bars1[1] == bars0[1] + 1 and bars1[2] == bars0[2], "full mastery, table of three: the 3 and 2 star bars are one point higher, the 1 star bar stays (%s)" % str(bars1))
	_start(o, five, false)
	var five_now: int = o.dinner_targets()[0]
	career.counters["good.dinner"] = 0
	var five_first: int = o.dinner_targets()[0]
	career.counters["good.dinner"] = 10
	_check(five_now == five_first + 2, "a table of five expects two more")
	_start(o, trio)
	_check(_fit_count(o) == 1, "full mastery: only one plate suits everybody")
	_check(str(o.dinner_brief()).contains("EXPECTS MORE"), "the intro page says the table expects more: %s" % str(o.dinner_brief()))
	# fewer free hints: every topic is known here, so every row would be marked; at full mastery about half are
	var marked := 0
	var rows := 0
	var every: Array = o.topic_ids()
	for seed_n in range(900, 940):
		d.seed_run(seed_n)
		o.reset()
		o.known = {"Alan": {"likes": every.duplicate(), "hates": []}}
		_start(o, trio)
		for id in o.g.options:
			if every.has(str(id)):
				rows += 1
				marked += 1 if o.g.marks.has(str(id)) else 0
	_check(marked > rows * 0.3 and marked < rows * 0.7, "full mastery marks about half of what you know (%d of %d)" % [marked, rows])
	career.counters["good.dinner"] = 0
	marked = 0
	rows = 0
	for seed_n in range(900, 940):
		d.seed_run(seed_n)
		o.reset()
		o.known = {"Alan": {"likes": every.duplicate(), "hates": []}}
		_start(o, trio)
		for id in o.g.options:
			if every.has(str(id)):
				rows += 1
				marked += 1 if o.g.marks.has(str(id)) else 0
	_check(marked == rows and rows > 100, "a first play marks all of it (%d of %d)" % [marked, rows])

	# ---- tiers: easy ramps less, hard is capped
	career.counters["good.dinner"] = 10
	d.set_tier("easy")
	_start(o, trio)
	_check(is_equal_approx(d.f("dinner.expect"), 0.0) and _fit_count(o) == 3 and is_equal_approx(d.f("dinner.hints"), 1.0), "easy at full mastery: nothing more expected, still three plates and every hint")
	d.set_tier("hard")
	_check(is_equal_approx(d.f("dinner.expect"), 0.5) and is_equal_approx(d.f("dinner.hints"), 0.375), "hard tops out at its value plus HARD_OVER of the step (%.2f, %.3f)" % [d.f("dinner.expect"), d.f("dinner.hints")])
	_start(o, trio)
	_check(_fit_count(o) == 1, "hard always has one plate that suits everybody")
	d.set_tier("normal")

	# ---- a fixed take is the first play again
	d.fixed_take = true
	d.seed_run(5)
	o.reset()
	_start(o, trio, false)
	_check(o.dinner_targets() == bars0 and d.mastery("dinner") == 0.0, "fixed take: the classic bars")
	_start(o, trio)
	_check(_fit_count(o) == 2, "fixed take: two plates")
	o.g.score = 99
	o._dinner_end()
	_check(not " ".join(o.lines).contains("MASTERY"), "fixed take: no mastery line")
	o.press(KEY_ENTER)
	d.fixed_take = false

	# ---- fairness: at full mastery best play still gets through
	career.counters["good.dinner"] = 10
	for table in [trio, five]:
		var dist := [0, 0, 0, 0]
		for seed_n in 100:
			dist[_best_dinner(o, d, 6000 + seed_n, table)] += 1
			career.counters["good.dinner"] = 10
		print("full mastery, table of %d, best play stars 0-3: %s" % [table.size(), str(dist)])
		_check(dist[2] + dist[3] >= 85 and dist[3] >= 15, "full mastery, table of %d: best play gets 2+ stars in 85%%+ and 3 stars now and then" % table.size())
	career.reset_all()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
