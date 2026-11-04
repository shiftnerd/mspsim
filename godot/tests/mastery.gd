extends SceneTree
# gdlint:disable=max-line-length
# The per-game MASTERY ramp (Difficulty.mastery / blend, Career "good.<game>"): m is 0 on a fresh career, only 2+ star finished
# plays count (not 1 star, not leaving early), it caps at RAMP_PLAYS, tier blends only get tighter, the first play is exactly the
# TABLE value, hard stays under its fairness cap, Easy (cozy) blends less than Normal, fixed_take pins m to 0, counters persist.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/mastery.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var d := root.get_node("Difficulty")
	var c := root.get_node("Career")
	var o := root.get_node("Outings")
	d.settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	c.reset_all()
	d.fixed_take = false
	var ramp: int = d.RAMP_PLAYS
	_check(ramp == 10, "RAMP_PLAYS is 10")
	for game in ["karaoke", "bowling", "escape", "dinner", "printer", "grill", "chair", "cornhole"]:
		_check(d.mastery(game) == 0.0, "fresh career: mastery of %s is 0" % game)

	# first play = today's numbers on every tier and key
	for t in d.TIERS:
		var same := true
		for key in d.TABLE:
			same = same and is_equal_approx(d.blend(key, t, 0.0), float(d.at(key, t)))
		d.set_tier(t)
		for key in d.MASTERY_KEYS:
			same = same and is_equal_approx(d.f(key), float(d.at(key, t)))
		_check(same, "m = 0 gives the TABLE value (%s)" % t)

	# what counts
	c.note_outing("karaoke", 1)
	c.note_outing("karaoke", 0)
	c.note_outing("karaoke", -1)
	_check(d.mastery("karaoke") == 0.0, "1 star, 0 stars and leaving early do not count")
	c.note_outing("karaoke", 2)
	c.note_outing("karaoke", 3)
	_check(is_equal_approx(d.mastery("karaoke"), 0.2) and d.mastery("bowling") == 0.0, "2 and 3 star plays count, per game")
	# the real finish path
	o.game = "bowling"
	o.g = {}
	o._finish(-1)
	_check(d.mastery("bowling") == 0.0, "Outings._finish(-1) (Esc) does not count")
	o.game = "bowling"
	o.g = {}
	o._finish(1)
	_check(d.mastery("bowling") == 0.0, "Outings._finish(1) does not count")
	o.game = "bowling"
	o.g = {}
	o._finish(2)
	_check(is_equal_approx(d.mastery("bowling"), 0.1), "Outings._finish(2) counts once")
	_check(" ".join(o.lines).contains("MASTERY 1/10"), "the result page carries the mastery line")
	c.note_printer("plotter", 1, false, 0)
	_check(d.mastery("printer") == 0.0, "a 1 star printer win does not count")
	c.note_printer("plotter", 3, false, 0)
	_check(is_equal_approx(d.mastery("printer"), 0.1), "a 3 star printer win counts")

	# cap
	for i in 30:
		c.note_outing("escape", 3)
	_check(d.mastery("escape") == 1.0, "mastery caps at 1 after RAMP_PLAYS (and beyond)")

	# monotonic, first play, fairness
	var mono := true
	var cap_ok := true
	for t in d.TIERS:
		for key in d.MASTERY_KEYS:
			var row: Array = d.TABLE[key]
			var step: float = float(row[2]) - float(row[1])
			var prev: float = d.blend(key, t, 0.0)
			var dir := signf(float(row[2]) - float(row[0]))
			for k in range(1, 11):
				var v: float = d.blend(key, t, float(k) / 10.0)
				mono = mono and (v - prev) * dir >= -0.000001  # tighter = toward the harder direction, never back
				prev = v
			var hard_end: float = d.blend(key, "hard", 1.0)
			cap_ok = cap_ok and absf(hard_end - (float(row[2]) + d.HARD_OVER * step)) < 0.0001
	_check(mono, "more mastery never loosens a key (every key, every tier)")
	_check(cap_ok, "hard tops out at its own value plus HARD_OVER of the normal-to-hard step")
	_check(is_equal_approx(d.blend("karaoke.good", "normal", 1.0), d.at("karaoke.good", "hard")), "normal at full mastery equals the hard value")
	var easy_step: float = absf(d.blend("bowl.aim_speed", "easy", 1.0) - d.at("bowl.aim_speed", "easy"))
	var norm_step: float = absf(d.blend("bowl.aim_speed", "normal", 1.0) - d.at("bowl.aim_speed", "normal"))
	_check(easy_step > 0.0 and is_equal_approx(easy_step, d.EASY_RAMP * absf(d.at("bowl.aim_speed", "normal") - d.at("bowl.aim_speed", "easy"))), "easy (cozy) blends only EASY_RAMP of the way to normal")
	_check(easy_step < norm_step, "easy ramps less than normal")
	_check(d.blend("bowl.aim_speed", "easy", 1.0) < d.at("bowl.aim_speed", "normal"), "easy at full mastery stays below normal's value")

	# fixed numbers never move
	var fixed := true
	d.set_tier("hard")
	for key in ["karaoke.grace", "karaoke.grace_drain", "escape.digits", "escape.dial", "dinner.reveal", "printer.questions", "printer.chain", "corn.to", "corn.assist", "grill.tickets", "grill.flare", "grill.dogs"]:
		fixed = fixed and is_equal_approx(d.f(key), float(d.at(key, "hard"))) and not key in d.MASTERY_KEYS
	_check(fixed, "counts, switches and random frequencies stay fixed")

	# the call sites see the blend through f()
	d.set_tier("normal")
	_check(is_equal_approx(d.f("escape.time"), float(d.at("escape.time", "hard"))), "Difficulty.f reads the blend (escape at full mastery, normal tier)")
	var kg: float = d.blend("karaoke.gap", "normal", 0.5)
	_check(kg < 0.75 and kg > 0.55, "half mastery sits between normal and hard (%.3f)" % kg)

	# karaoke windows stay fair against the note gap at full mastery on every tier
	var fair := true
	for t in d.TIERS:
		var gap: float = d.blend("karaoke.gap", t, 1.0)
		var good: float = d.blend("karaoke.good", t, 1.0)
		var perfect: float = d.blend("karaoke.perfect", t, 1.0)
		fair = fair and gap > 2.0 * good and perfect < good and perfect > 0.05
	_check(fair, "karaoke windows still fit the gap at full mastery (every tier)")
	_check(is_equal_approx(d.mastery_blend("karaoke.gap", "normal"), d.blend("karaoke.gap", "normal", d.mastery("karaoke"))), "mastery_blend uses the game's own counter")

	# fixed take pins to 0
	d.fixed_take = true
	_check(d.mastery("escape") == 0.0 and is_equal_approx(d.f("escape.time"), float(d.at("escape.time", "normal"))), "fixed_take: mastery is 0 and the numbers are the table's")
	d.fixed_take = false

	# persistence through Career save / load
	c.save_file()
	var before := int(c.value("good.escape"))
	c.counters = {}
	c.load_file()
	_check(int(c.value("good.escape")) == before and before >= ramp, "good.<game> counters survive save and load")
	c.reset_all()
	_check(d.mastery("escape") == 0.0, "reset: back to 0")
	d.set_tier("normal")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
