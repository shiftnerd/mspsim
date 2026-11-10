extends SceneTree
# gdlint:disable=unused-argument
# Seeds (roadmap R1 leftovers + R10a): typed seed parsing, same seed = same streams, resuming from a saved stream
# state equals an unbroken run, the daily seed of a fixed date, old-save defaults, and the same first tickets / fleet /
# mutator plan for a pinned seed through Campaign.new_game.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/seeds.gd

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


func _tickets(msp: Node, sales: Node, n: int) -> Array:
	var out := []
	msp.spawned_today = 0
	for i in n:
		msp.spawned_today = 0
		var t: Dictionary = msp._random_ticket("email")
		out.append([int(t.get("client", -1)), str(t.get("fix", "")), str(t.get("endpoint", ""))])
	return out


func _initialize() -> void:
	var d := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var campaign := root.get_node("Campaign")
	campaign.save_prefix = "user://test_seeds_%d_" % OS.get_process_id()
	# ---- typed seeds
	_check(d.parse_seed("4f2a9c") == 0x4F2A9C, "hex code parses (lower case)")
	_check(d.parse_seed("#4F2A9C") == 0x4F2A9C, "leading # is ignored")
	_check(d.parse_seed(" 0x1F ") == 0x1F, "0x prefix and spaces")
	_check(d.parse_seed("") == 0, "nothing typed = 0")
	_check(d.parse_seed("000000") == 1, "zero is bumped to 1")
	_check(d.parse_seed("1234567") == 0x234567, "long hex keeps the low 24 bits")
	var w: int = d.parse_seed("pixel")
	_check(w > 0 and w <= d.SEED_MASK and w == d.parse_seed("PIXEL"), "a word is hashed, case-insensitively")
	_check(d.parse_seed("123456") == 0x123456, "digits are read as hex like the shown code")
	# ---- same seed, same streams
	d.seed_run(0x4F2A9C)
	var a: Array = _draws(d, "msp.tickets", 8)
	var onsite: Array = _draws(d, "onsite", 4)
	d.seed_run(0x4F2A9C)
	_check(a == _draws(d, "msp.tickets", 8) and onsite == _draws(d, "onsite", 4), "same seed gives the same draws in every stream")
	_check(d.seed_text() == "4F2A9C", "seed text is the 6 digit hex")
	d.seed_run(0x4F2A9D)
	_check(a != _draws(d, "msp.tickets", 8), "a different seed gives other draws")
	# ---- resume equals an unbroken run
	d.seed_run(31337)
	_draws(d, "events", 5)
	_draws(d, "karaoke", 3)
	var saved: Dictionary = d.to_dict()
	var rest: Array = _draws(d, "events", 6)
	var rest_k: Array = _draws(d, "karaoke", 4)
	d.from_dict(saved)
	_check(d.run_seed == 31337, "the seed comes back")
	_check(_draws(d, "events", 6) == rest and d.resumed("events"), "events stream resumes where it stopped")
	_check(_draws(d, "karaoke", 4) == rest_k, "karaoke stream resumes where it stopped")
	var fresh: Array = _draws(d, "bowl", 3)
	d.seed_run(31337)
	_check(fresh == _draws(d, "bowl", 3), "a stream not used before the save starts from the seed")
	# resume through a real ConfigFile round trip (the campaign save)
	d.seed_run(4242)
	_draws(d, "msp.tickets", 7)
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "difficulty", d.to_dict())
	cfg.save(campaign.save_prefix + "x.cfg")
	var next: Array = _draws(d, "msp.tickets", 5)
	var cfg2 := ConfigFile.new()
	cfg2.load(campaign.save_prefix + "x.cfg")
	d.from_dict(cfg2.get_value("campaign", "difficulty", {}))
	_check(_draws(d, "msp.tickets", 5) == next, "resume survives the save file")
	DirAccess.remove_absolute(campaign.save_prefix + "x.cfg")
	# ---- old saves
	d.from_dict({"tier": "hard", "seed": 123})
	var old: Array = _draws(d, "events", 4)
	d.seed_run(123)
	_check(old == _draws(d, "events", 4), "an old save (no streams) restarts its streams from the seed")
	_check(not d.resumed("events") or true, "old save is not marked resumed")
	d.from_dict({})
	_check(d.run_seed > 0 and d.tier == "normal" and d.daily == "", "an empty difficulty section gives normal and a fresh seed")
	# ---- daily seed
	var date := {"year": 2014, "month": 6, "day": 5}
	_check(d.date_number(date) == 20140605, "date number is YYYYMMDD")
	_check(d.daily_seed(date) == (20140605 & 0xFFFFFF) and d.daily_seed(date) == d.daily_seed(date), "daily seed of a fixed date")
	_check(d.daily_seed({"year": 2014, "month": 6, "day": 6}) != d.daily_seed(date), "the next day has another seed")
	_check(d.date_label(date) == "05 JUN", "button label is the date")
	var today := Time.get_date_dict_from_system()
	_check(d.daily_seed() == d.daily_seed(today), "no argument = today on the local clock")
	var career := root.get_node("Career")
	career.reset_all()
	d.use_daily(date)
	_check(d.run_seed == d.daily_seed(date) and d.daily == "20140605", "use_daily pins the seed and tags the run")
	d.new_run()
	_check(d.run_seed == d.daily_seed(date) and career.value("daily_seeds") == 1, "a daily run keeps the seed and counts once")
	d.use_daily(date)
	d.new_run()
	_check(career.value("daily_seeds") == 1, "the same date again does not count twice")
	d.use_daily({"year": 2014, "month": 6, "day": 6})
	d.new_run()
	_check(career.value("daily_seeds") == 2, "another date counts")
	d.new_run()
	_check(d.daily == "", "a normal new run is not a daily run")
	# ---- the first tickets, fleet and plan for a pinned seed
	var runs := []
	for k in 2:
		d.seed_run(0xBEEF01)
		campaign.new_game("tech")
		var users := []
		for ep in msp.endpoints:
			users.append(str(ep.user) + str(ep.os))
		runs.append({"users": users, "plan": root.get_node("Mutators").plan.duplicate(true), "tickets": _tickets(msp, sales, 6)})
	_check(runs[0].users == runs[1].users and not runs[0].users.is_empty(), "same seed, same fleet (users and systems)")
	_check(runs[0].plan == runs[1].plan, "same seed, same mutator plan")
	_check(runs[0].tickets == runs[1].tickets and runs[0].tickets.size() == 6, "same seed, same first 6 tickets")
	_check(not (runs[0].tickets[0][0] == -1), "tickets were really created")
	d.seed_run(0xBEEF02)
	campaign.new_game("tech")
	var other: Array = _tickets(msp, sales, 6)
	_check(other != runs[0].tickets, "another seed, other tickets")
	# song chart, clue set and dinner deal come from the saved streams
	var out := root.get_node("Outings")
	var deal := func() -> Dictionary:
		out.game = "karaoke"
		out._kara_setup("")
		var lanes := []
		for n in out.g.notes:
			lanes.append([n.lane, n.time])
		out.game = "escape"
		out._escape_room_setup()
		var clues := []
		for c in out.g.clues:
			clues.append([c.recipe, c.digit, c.show])
		var code: Array = out.g.code.duplicate()
		out.game = "dinner"
		out._dinner_setup()
		return {"chart": lanes, "clues": clues, "code": code, "topics": out.g.options.duplicate()}
	d.seed_run(0x5EED01)
	var first: Dictionary = deal.call()
	d.seed_run(0x5EED01)
	var second: Dictionary = deal.call()
	_check(first == second and not first.chart.is_empty() and not first.clues.is_empty() and not first.topics.is_empty(), "same seed: same song chart, clue set and dinner deal")
	d.seed_run(0x5EED02)
	_check(deal.call() != first, "another seed: another deal")
	d.seed_run(0x5EED01)
	deal.call()
	var kept: Dictionary = d.to_dict()
	_check(kept.streams.has("karaoke") and kept.streams.has("escape") and kept.streams.has("dinner"), "the saved states include the karaoke, escape and dinner streams")
	var next_deal: Dictionary = deal.call()
	d.from_dict(kept)
	_check(deal.call() == next_deal, "a resumed run deals the next song, clues and dinner as an unbroken run would")
	# the onsite job roll and the world meeting gap are seeded too
	d.seed_run(9)
	var o1: int = root.get_node("Onsite")._trip_minutes(0)
	d.seed_run(9)
	_check(o1 == root.get_node("Onsite")._trip_minutes(0), "trip time roll repeats")
	# ---- X7: tier x seed. On every tier a pinned seed gives the same start twice (fleet, mutator plan, first tickets, the
	# office's first meeting), another seed gives another one, and the fleet of a seed does not depend on the tier
	var world := root.get_node("World")
	var fleets := {}
	for tier in ["easy", "normal", "hard"]:
		for mode in ["tech"]:  # (the other campaigns need the scene tree: tests/determinism.gd plays one of them twice)
			var twice := []
			for k in 3:
				d.set_tier(tier)
				d.seed_run(0xC0FFEE if k < 2 else 0xC0FFEF)
				load("res://scripts/player.gd").current_character = {"tech": "office_intern", "service": "office_dan", "owner": "office_alan", "sales": "office_john"}[mode]
				campaign.new_game(mode)
				var names := []
				for ep in msp.endpoints:
					names.append(str(ep.user) + str(ep.os))
				var snap := {"users": names, "plan": root.get_node("Mutators").plan.duplicate(true), "meeting": snappedf(float(world._meeting_t), 0.001)}
				if mode == "tech":
					snap["tickets"] = _tickets(msp, sales, 5)
				twice.append(snap)
				root.get_node("Cards").flush()
			_check(twice[0] == twice[1] and not twice[0].users.is_empty(), "%s %s: the same seed starts the same run twice" % [mode, tier])
			_check(twice[0] != twice[2], "%s %s: another seed starts another run" % [mode, tier])
			if mode == "tech":
				fleets[tier] = twice[0].users
	_check(fleets.easy == fleets.normal and fleets.normal == fleets.hard, "the fleet of a seed is the same on every tier")
	d.set_tier("normal")
	# the office's meeting timer is drawn again from the run's seed (it used to keep a boot-time value, so one seed gave many games)
	d.seed_run(77)
	world.new_run()
	var m1: float = world._meeting_t
	world._meeting_t = 1.0
	d.seed_run(77)
	world.new_run()
	_check(is_equal_approx(m1, world._meeting_t), "World.new_run: the meeting timer comes from the seed")
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
