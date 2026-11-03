extends SceneTree
# gdlint:disable=comparison-with-itself
# Bowling variety (R11): oil patterns, the hook, three alleys, bowling styles, league night and the tiers.
# Headless; the game is driven through Outings.start / press / tick like tests/outings.gd.

const BV := preload("res://scripts/bowl_variety.gd")
var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _play(o: Node, marker: float, spin: int) -> void:
	var guard := 0
	while o.phase == "play" and guard < 60:
		o.g.marker = marker
		if spin != 0:
			o.press(KEY_LEFT if spin < 0 else KEY_RIGHT)
		o.press(KEY_SPACE)
		o.g.power = 0.85
		o.press(KEY_SPACE)
		o.tick(2.0)
		o.tick(2.0)
		if o.phase == "play" and o.g.stage == "pause":
			o.tick(2.0)
		guard += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var career := root.get_node("Career")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	career.toasts = false
	o.enabled = true
	c.new_game("tech")
	d.seed_run(4242)

	# ---- tables
	_check(BV.ALLEYS.size() == 3 and BV.OILS.size() == 3, "three alleys and three oil patterns")
	var share := 0.0
	for id in BV.ALLEYS:
		share += float(BV.ALLEYS[id].share)
		_check(BV.OILS.has(str(BV.ALLEYS[id].oil)), "%s has a real oil pattern" % id)
	_check(is_equal_approx(share, 1.0), "the alley shares add up")
	_check(is_equal_approx(BV.center("house", 0), 0.5), "the house shot is centred like the classic bar")
	_check(BV.center("dry", 0) < 0.4, "dry lanes push the green zone left (%.2f)" % BV.center("dry", 0))
	_check(
		BV.center("dry", -1) > BV.center("dry", 0) and BV.center("dry", 1) < BV.center("dry", 0),
		"a hook against the drift cancels most of it, a hook with it makes it worse"
	)
	_check(
		is_equal_approx(BV.accuracy("house", 0.5, 0), 1.0) and is_equal_approx(BV.accuracy("house", 0.0, 0), 0.0),
		"house accuracy is the old formula"
	)
	_check(
		BV.accuracy("sport", 0.3, 0) < BV.accuracy("house", 0.3, 0) - 0.04,
		"the sport shot punishes a miss harder"
	)
	_check(BV.accuracy("dry", BV.center("dry", 0), 0) > 0.99, "the dry green zone is perfect where it sits")

	# ---- the classic game is unchanged
	o.start("bowling")
	o.press(KEY_ENTER)
	_check(o.g.alley == "strike_zone" and o.oil_id() == "house", "no options = the classic alley")
	_check(is_equal_approx(o.bowl_center(), 0.5) and is_equal_approx(o.bowl_zone_width(), 0.2), "classic green zone")
	_play(o, 0.5, 0)
	_check(o.phase == "result" and o.stars >= 2, "perfect classic bowling still wins (%d stars)" % o.stars)
	o.press(KEY_ENTER)

	# ---- dry lanes and the hook
	o.start("bowling", false, {"alley": "rental"})
	_check(str(o.opts.alley) == "rental", "the alley comes from the options")
	o.press(KEY_ENTER)
	_check(o.oil_id() == "dry" and o.bowl_center() < 0.4, "the rented lanes are dry")
	o.g.stage = "aim"
	o.g.marker = BV.center("dry", 0)
	var straight: float = 0.0
	for i in 20:
		straight += o.bowl_strength()
	o.g.marker = 0.5
	var middle: float = 0.0
	for i in 20:
		middle += o.bowl_strength()
	_check(straight > middle + 1.0, "aiming at the dry green zone beats aiming at the middle")
	o.press(KEY_LEFT)
	_check(int(o.g.spin) == -1 and o.bowl_center() > BV.center("dry", 0), "LEFT sets a left hook and moves the zone")
	o.press(KEY_LEFT)
	_check(int(o.g.spin) == 0, "pressing the same hook again clears it")
	o.press(KEY_RIGHT)
	_check(int(o.g.spin) == 1, "RIGHT sets a right hook")
	# a wild hook leaves the lane
	o.g.alley = "league"
	o.g.spin = 1
	o.g.marker = 0.0
	o.g.power = 0.85
	o.g.stage = "power"
	o.press(KEY_SPACE)
	o.tick(2.0)
	_check(int(o.g.knocked) == 0 and "HOOKED" in str(o.g.msg), "a hook thrown far off the green zone goes off the lane")
	_check(int(o.g.spin) == 0, "the hook is cleared for the next roll")
	var hooks0: int = career.value("bowl_hooks")
	var strikes := 0
	for i in 30:
		o.g.stage = "aim"
		o.g.roll = 1
		o.g.pins = 10
		o.g.spin = -1
		o.g.marker = BV.center("dry", -1)
		o.g.power = 0.85
		o.g.stage = "power"
		o.press(KEY_SPACE)
		o.tick(2.0)
		strikes += 1 if int(o.g.knocked) >= 10 else 0
	_check(strikes >= 5, "a good hook on dry lanes strikes often (%d of 30)" % strikes)
	_check(career.value("bowl_hooks") >= hooks0 + 30 and career.value("bowl_hook_strikes") >= strikes, "hooks are counted for the career")
	o.g.alley = "rental"
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)

	# ---- styles on the lanes
	o.start("bowling", false, {"alley": "strike_zone"})
	o.press(KEY_ENTER)
	var avg := {}
	for alley in ["rental", "strike_zone", "league"]:
		o.g.alley = alley
		for who in ["Garrison", "Dan", "Morgan"]:
			var sum := 0.0
			for i in 300:
				sum += float(o._bowl_roll_opp(who).knock)
			avg[alley + who] = sum / 300.0
	_check(
		avg["rentalGarrison"] > avg["leagueGarrison"] + 0.15,
		"Garrison the hooker likes dry lanes more than the sport shot (%.2f vs %.2f)" % [avg["rentalGarrison"], avg["leagueGarrison"]]
	)
	_check(
		avg["leagueMorgan"] > avg["rentalMorgan"] + 0.1,
		"Morgan the precise bowler likes the sport shot (%.2f vs %.2f)" % [avg["leagueMorgan"], avg["rentalMorgan"]]
	)
	_check(BV.style_of("Dan") == "power" and BV.style_of("Vic") == "show", "every bowler has a style")
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)

	# ---- the seeded draw
	var seen := {}
	for n in 200:
		seen[BV.pick_alley(d.rng_for("alley", n), 0)] = true
	_check(seen.size() == 3, "the draw reaches all three alleys")
	var league_runs := 0
	for n in 200:
		league_runs += 1 if BV.pick_alley(d.rng_for("alley", n), 1) == "league" else 0
	_check(league_runs >= 100, "a season in progress pulls people back to league night (%d of 200)" % league_runs)
	_check(
		BV.pick_alley(d.rng_for("alley", 5), 0) == BV.pick_alley(d.rng_for("alley", 5), 0),
		"the same seed picks the same alley"
	)
	d.seed_run(77)
	var a77: Dictionary = o._game_options("bowling")
	d.seed_run(77)
	_check(o._game_options("bowling").alley == a77.alley and a77.has("party"), "the card options repeat with the seed")
	_check(not o._game_options("karaoke").has("alley"), "only bowling gets an alley")

	# ---- tiers
	var oil_easy: float = d.at("bowl.oil", "easy")
	var oil_hard: float = d.at("bowl.oil", "hard")
	_check(oil_easy < d.at("bowl.oil", "normal") and d.at("bowl.oil", "normal") < oil_hard and d.at("bowl.oil", "normal") == 1.0, "the oil gets stricter by tier")
	_check(d.at("bowl.spin_noise", "easy") < d.at("bowl.spin_noise", "hard"), "a hook is wilder on hard")
	var acc := {}
	for tier in ["easy", "hard"]:
		d.tier = tier
		acc[tier] = BV.accuracy("house", 0.4, 0, d.f("bowl.oil"))
	d.tier = "normal"
	_check(acc.easy > acc.hard, "the same miss costs more on hard")

	# ---- league night
	var lg: Dictionary = BV.new_league()
	_check(BV.handicap(lg, "You") == 0, "no handicap on the first night")
	var r1: Dictionary = BV.record(lg, {"You": 20, "Alan": 40, "Dan": 10})
	_check(int(r1.night) == 1 and not bool(r1.done), "night one of three")
	_check(BV.handicap(lg, "Dan") > BV.handicap(lg, "Alan") and BV.handicap(lg, "Alan") == 0, "weaker bowlers get a handicap, the best none")
	_check(BV.handicap(lg, "Dan") == roundi((40.0 - 10.0) * 0.9), "handicap = 0.9 x the gap to the best average")
	BV.record(lg, {"You": 20, "Alan": 40, "Dan": 10})
	var r3: Dictionary = BV.record(lg, {"You": 30, "Alan": 40, "Dan": 38})
	_check(bool(r3.done) and str(r3.winner) != "" and int(lg.night) == 0 and lg.totals.is_empty(), "three nights make a season and the table resets")
	_check(int(lg.seasons) == 1, "seasons are counted")

	# ---- a full league night through Outings
	o.reset()
	o.league = BV.new_league()
	var titles0: int = career.value("league_titles")
	var nights0: int = career.value("league_nights")
	for night in 3:
		o.start("bowling", false, {"alley": "league"})
		o.press(KEY_ENTER)
		_check(o.is_league() and not (o.g.hcp as Dictionary).is_empty() or night == 0, "night %d has a handicap table" % (night + 1))
		_play(o, BV.center("sport", 0), 0)
		_check(o.phase == "result", "league night %d ends" % (night + 1))
		var text := ""
		for line in o.lines:
			text += str(line) + " "
		_check("LEAGUE NIGHT %d OF 3" % (night + 1) in text, "the result page names the league night (%d)" % (night + 1))
		o.press(KEY_ENTER)
	_check(career.value("league_nights") == nights0 + 3 and career.value("league_seasons") >= 1, "the career counts league nights and the season")
	_check(int(o.league.night) == 0 and int(o.league.seasons) == 1, "the season closed after three nights")
	var data: Dictionary = o.to_dict()
	o.league = BV.new_league()
	o.from_dict(data)
	_check(int(o.league.seasons) == 1, "the league is saved")
	o.from_dict({"count": 2})
	_check(int(o.league.night) == 0 and int(o.count) == 2, "an old save has a fresh league")

	# ---- alleys bowled
	_check(career.value("alleys") >= 2, "the career counts the alleys you bowled at (%d)" % career.value("alleys"))

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
