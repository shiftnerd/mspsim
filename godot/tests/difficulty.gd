extends SceneTree
# Difficulty: seeded streams, tier scalars (normal = the legacy constants), the settings file, the
# campaign save section (old saves load as normal), and every activity reading its tier. Headless.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/difficulty.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _draws(d: Node, stream: String, n: int) -> Array:
	var out := []
	for i in n:
		out.append(d.rng(stream).randi())
	return out


func _lanes(o: Node) -> Array:
	var out := []
	for n in o.g.notes:
		out.append(n.lane)
	return out


func _snap(d: Node, o: Node, pg: Node) -> Dictionary:
	d.seed_run(777)
	var out := {}
	o._kara_setup()
	out.kara = _lanes(o)
	o._escape_setup()
	out.code = o.g.code.duplicate()
	o._escape_room_setup()
	out.room = [o.g.code.duplicate(), o.g.eq.duplicate()]
	o._dinner_setup()
	out.dinner = o.g.options.duplicate()
	pg.start(Callable())
	pg._begin_toner()
	out.toner = pg.order.duplicate()
	pg._begin_test()
	out.asked = pg.asked.duplicate()
	pg._new_zone()
	out.zone = pg.zone
	pg.is_open = false
	root.get_node("Game").ui_open = false
	o._bowl_setup()
	out.bowl = [o._bowl_roll_opp("Alan"), o._bowl_roll_opp("Dan")]
	return out


func _init() -> void:
	await process_frame
	var d := root.get_node("Difficulty")
	var o := root.get_node("Outings")
	var pg := root.get_node("PrinterGame")
	var c := root.get_node("Campaign")
	d.settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://test_diff_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- streams
	d.seed_run(1234)
	var a: Array = _draws(d, "karaoke", 5)
	d.seed_run(1234)
	_check(_draws(d, "karaoke", 5) == a, "the same seed gives the same draws")
	d.seed_run(1234)
	_draws(d, "bowl", 7)
	_check(_draws(d, "karaoke", 5) == a, "streams are independent of each other")
	d.seed_run(99)
	_check(_draws(d, "karaoke", 5) != a, "another seed gives other draws")
	d.seed_run(1234)
	var e3a: int = d.rng_for("events", 3).randi()
	var e3b: int = d.rng_for("events", 3).randi()
	var e4: int = d.rng_for("events", 4).randi()
	_check(e3a == e3b, "rng_for is repeatable")
	_check(e3a != e4, "...and differs by salt")
	var list := [1, 2, 3, 4, 5, 6]
	d.shuffle(list, "dinner")
	d.seed_run(1234)
	var again := [1, 2, 3, 4, 5, 6]
	d.shuffle(again, "dinner")
	_check(list == again and list.size() == 6, "shuffle with a stream is repeatable")
	_check(d.seed_text().length() == 6 and d.run_seed == 1234, "the seed shows as 6 hex digits")

	# ---- the table
	_check(d.TIERS == ["easy", "normal", "hard"], "three tiers")
	var shaped := true
	for key in d.TABLE:
		shaped = shaped and d.TABLE[key].size() == 3
	_check(shaped, "every key has easy / normal / hard")
	d.set_tier("nonsense")
	_check(d.tier == "normal", "an unknown tier means normal")
	var legacy := {
		"karaoke.gap": 0.75,
		"karaoke.perfect": 0.12,
		"karaoke.good": 0.3,
		"karaoke.grace": 0.0,
		"karaoke.grace_drain": 6.0,
		"bowl.opp_skill": 0.0,
		"bowl.aim_speed": 1.5,
		"bowl.power_speed": 1.2,
		"bowl.oil": 1.0,
		"bowl.spin_noise": 1.0,
		"escape.time": 120.0,
		"escape.wrong_penalty": 10.0,
		"escape.hint_penalty": 0.0,
		"dinner.reveal": 3.0,
		"escape.digits": 3.0,
		"escape.dial": 1.0,
		"printer.speed": 1.0,
		"printer.zone": 1.0,
		"printer.questions": 2.0,
		"printer.chain": 3.0,
		"nerf.gap": 1.0,
		"chair.crash": 1.0,
		"chair.stamina": 1.0,
		"chair.slick": 1.0,
		"chair.par": 1.0,
		"chair.skill": 0.0,
		"corn.to": 15.0,
		"corn.opp_skill": 0.0,
		"corn.aim_speed": 1.3,
		"corn.power_speed": 1.1,
		"corn.assist": 0.0,
		"grill.cook_rate": 1.0,
		"grill.window": 1.0,
		"grill.tickets": 6.0,
		"grill.time": 75.0,
		"grill.flare": 1.0,
		"grill.dogs": 0.35,
		"darts.drift": 58.0,
		"darts.speed": 1.9,
		"darts.noise": 7.0,
		"darts.opp_skill": 0.0,
		"crew.pace": 1.0,
		"crew.sla": 1.0,
		"tech.pace": 1.0,
		"tech.sla": 1.0,
		"tech.alt_ret": 1.0,
		"tech.drain": 1.0,
		"tech.pair": 0.0,
		"tech.heavy_fail": 0.0,
		"tech.heavy_slow": 1.0,
		"tech.onsite_mood": 2.0,
		"tech.gain": 1.0,
		"tech.loss": 1.0,
		"rep.gain": 1.0,
		"rep.loss": 1.0,
		"owner.cost": 1.0,
		"sales.lead": 0.0,
		"sales.flow": 0.5,
		"service.trust": 1.0,
	}
	var same: bool = legacy.size() == d.TABLE.size()
	for key in legacy:
		same = same and is_equal_approx(d.f(key), float(legacy[key]))
	_check(same, "normal is exactly today's constants")
	_check(d.cycle_tier(1) == "hard" and d.cycle_tier(1) == "easy", "cycling wraps around")
	d.set_tier("normal")
	var fair := true
	for t in d.TIERS:
		fair = fair and float(d.at("karaoke.gap", t)) > 2.0 * float(d.at("karaoke.good", t))
		fair = fair and float(d.at("karaoke.perfect", t)) < float(d.at("karaoke.good", t))
		fair = (
			fair
			and (
				float(d.at("escape.time", t)) - 2.0 * float(d.at("escape.wrong_penalty", t)) >= 70.0
			)
		)
	_check(fair, "every tier stays beatable (notes apart, windows nested, 3 stars after two slips)")
	var order := true
	for key in [
		"karaoke.gap", "karaoke.perfect", "karaoke.good", "escape.time", "printer.zone", "nerf.gap"
	]:
		order = order and float(d.at(key, "easy")) > float(d.at(key, "normal"))
		order = order and float(d.at(key, "normal")) > float(d.at(key, "hard"))
	for key in ["bowl.aim_speed", "bowl.power_speed", "printer.speed", "escape.wrong_penalty"]:
		order = order and float(d.at(key, "easy")) < float(d.at(key, "normal"))
		order = order and float(d.at(key, "normal")) < float(d.at(key, "hard"))
	_check(order, "easy is gentler than normal and hard is tougher")

	# ---- the settings file
	DirAccess.remove_absolute(d.settings_path)
	d.set_tier("hard")
	d.save_settings()
	d.set_tier("normal")
	d.load_settings()
	_check(d.tier == "hard", "the tier is remembered in the settings file")
	d.set_tier("normal")
	d.save_settings()
	DirAccess.remove_absolute(d.settings_path)

	# ---- same seed, same setup (every activity)
	var r1: Dictionary = _snap(d, o, pg)
	var r2: Dictionary = _snap(d, o, pg)
	_check(r1 == r2, "a fixed seed reproduces karaoke, escape, dinner, printer and bowling")
	d.seed_run(778)
	o._kara_setup()
	_check(_lanes(o) != r1.kara, "a different seed gives another chart")

	# ---- the tiers reach the activities
	for t in d.TIERS:
		d.set_tier(t)
		d.seed_run(5)
		o._kara_setup()
		var gap: float = d.at("karaoke.gap", t)
		_check(
			is_equal_approx(float(o.g.notes[1].time), 1.5 + gap) and o.g.notes.size() == 24,
			"karaoke chart spacing: " + t
		)
		var note: Dictionary = o.g.notes[3]
		o.g.t = float(note.time) + 0.14
		var got: String = o.kara_hit(int(note.lane))
		_check(
			got == ("perfect" if t == "easy" else "good"),
			"a 0.14 s late hit is %s on %s" % [got, t]
		)
		o._escape_room_setup()
		_check(
			is_equal_approx(float(o.g.time), float(d.at("escape.time", t))), "escape clock: " + t
		)
		var before: float = o.g.time
		o._room_submit()
		_check(
			is_equal_approx(before - float(o.g.time), float(d.at("escape.wrong_penalty", t))),
			"escape wrong-code penalty: " + t
		)
		# E4: the first hint is free, every one after it costs seconds on easy only
		o._escape_room_setup()
		o.g.hints = 3
		o.g.hints_used = 0
		o.escape_hint()
		var after_first: float = o.g.time
		o.escape_hint()
		var cost: float = after_first - float(o.g.time)
		_check(is_equal_approx(cost, float(d.at("escape.hint_penalty", t))), "escape hint cost after the first: %s (%d s)" % [t, int(cost)])
		pg.start(Callable())
		pg._begin_test()
		_check(pg.asked.size() == int(d.at("printer.questions", t)), "test page questions: " + t)
		pg.phase = "jam"
		pg.marker = 0.0
		pg._dir = 1.0
		pg.spot = 0
		pg._process(0.1)
		_check(
			is_equal_approx(pg.marker, 0.08 * float(d.at("printer.speed", t))),
			"printer marker speed: " + t
		)
		pg.zone = 0.5
		pg.marker = 0.5 + 0.09
		pg.spot = 0
		pg._pull()
		var clean: bool = pg.spot == 1
		_check(clean == (t == "easy"), "a 0.09 off pull is clean: %s on %s" % [str(clean), t])
		pg.is_open = false
		root.get_node("Game").ui_open = false
		o._bowl_setup()
		o.g.stage = "aim"
		o.g.marker = 0.0
		o._bowl_tick(0.1)
		_check(
			is_equal_approx(float(o.g.marker), 0.1 * float(d.at("bowl.aim_speed", t))),
			"bowling aim speed: " + t
		)
	# opponents are weaker on easy and stronger on hard
	var means := {}
	for t in d.TIERS:
		d.set_tier(t)
		d.seed_run(31)
		var sum := 0
		for i in 300:
			sum += int(o._bowl_roll_opp("Alan").total)
		means[t] = sum
	_check(
		means.easy < means.normal and means.normal < means.hard, "opponent skill follows the tier"
	)

	# QA items 6 and 8: hard goes easy on the first two misses of a song and warns about doubles; its printer green zone is wider
	for t in d.TIERS:
		d.set_tier(t)
		d.seed_run(5)
		o._kara_setup()
		var want := [6.0, 6.0, 6.0] if t != "hard" else [3.0, 3.0, 6.0]
		_check(
			o._miss_drain(1) == want[0] and o._miss_drain(2) == want[1] and o._miss_drain(3) == want[2],
			"karaoke miss drain ramp: " + t
		)
		o.g.mood = 50.0
		o.g.t = float(o.g.notes[0].time) + float(o.g.good_win) + 0.01
		o._kara_tick(0.0)
		var expect := 50.0
		for k in int(o.g.miss):
			expect -= o._miss_drain(k + 1)
		_check(
			int(o.g.miss) >= 1 and is_equal_approx(float(o.g.mood), expect),
			"first miss drains %s on %s" % [str(50.0 - float(o.g.mood)), t]
		)
		_check(
			(o.kara_warning() != "") == (t != "easy"), "karaoke doubles warning is shown on " + t
		)
	d.set_tier("normal")
	_check(
		o.kara_warning("wobble") == "" and o.kara_warning("rap") != "", "normal: only the rap warns"
	)
	d.set_tier("hard")
	_check(o.kara_warning("wobble") != "", "hard warns on every song")
	_check(
		is_equal_approx(float(d.at("printer.zone", "easy")), 1.3)
		and is_equal_approx(float(d.at("printer.zone", "normal")), 1.0),
		"printer zone easy / normal unchanged"
	)
	# a clean pull at the slowest hard marker speed (0.8 x 1.25 tracks per second) lasts at least 120 ms
	var window: float = 0.14 * float(d.at("printer.zone", "hard")) / (0.8 * float(d.at("printer.speed", "hard")))
	_check(window >= 0.12 and window < 0.2, "hard clean pull window is %d ms" % int(window * 1000.0))
	d.set_tier("normal")

	# dinner: hard hides a face for the round, and what you could not read is not learned
	d.set_tier("hard")
	d.seed_run(8)
	o.known = {}
	o._dinner_setup()
	o.dinner_talk(0)
	var hidden: Array = o.g.hidden
	_check(hidden.size() == 1, "hard hides one face (the points still count)")
	_check(
		not o.known.has(hidden[0]) and o.known.size() == 2,
		"...and teaches nothing about that person"
	)
	d.set_tier("normal")
	o.known = {}
	o._dinner_setup()
	o.dinner_talk(0)
	_check(o.g.hidden.is_empty() and o.known.size() == 3, "normal shows all three faces, as before")

	# ---- the campaign save
	d.set_tier("hard")
	d.seed_run(4242)
	c.new_game("tech")
	_check(d.run_seed == 4242 and d.tier == "hard", "New Game keeps a seed fixed with seed_run")
	c.save()
	d.set_tier("easy")
	d.seed_run(1)
	var ok: bool = c.continue_game("tech")
	_check(ok and d.tier == "hard" and d.run_seed == 4242, "tier and seed come back with the save")
	c.new_game("tech")
	_check(d.run_seed >= 1 and d.run_seed <= d.SEED_MASK, "an unseeded New Game rolls a seed")
	d.set_tier("hard")
	d.seed_run(4242)
	c.new_game("tech")
	c.save()
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("tech"))
	_check(cfg.has_section_key("campaign", "difficulty"), "the save has a difficulty section")
	cfg.erase_section_key("campaign", "difficulty")
	cfg.save(c.save_path("tech"))
	d.set_tier("hard")
	ok = c.continue_game("tech")
	_check(ok and d.tier == "normal" and d.run_seed >= 1, "an old save loads as normal with a seed")
	DirAccess.remove_absolute(c.save_path("tech"))
	d.set_tier("normal")
	# R16: a note under the tier picker for every campaign and tier, and Easy's says cozy
	var notes_ok := true
	var cozy_ok := true
	for m in ["tech", "service", "sales", "owner"]:
		for t in ["easy", "normal", "hard"]:
			var line := str(d.TIER_NOTES.get(m, {}).get(t, ""))
			notes_ok = notes_ok and line != "" and line.length() <= 90
			cozy_ok = cozy_ok and (t != "easy" or line.contains("COZY"))
	_check(notes_ok, "every campaign has a short note for every tier")
	_check(cozy_ok, "the Easy notes say cozy")
	_check(d.tier_note("free") == "", "Free Play has no tier note")
	print("failures=%d" % failures)
	quit(failures)
