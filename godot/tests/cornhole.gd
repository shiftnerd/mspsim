extends SceneTree
# gdlint:disable=max-line-length
# CORNHOLE (R21 a): the rules (where a bag lands, the hole, the board, cancellation scoring, the target, the stars), the crew
# (the order of the round, each person's temper), the tiers (a perfect run wins by 7 or more on every tier, a sloppy one loses),
# determinism from the seed, Cozy Easy, and the outing around it (the card, the overlay game, the hint line, the counters and the
# BAG MAN medal, the texts have no brand names). The game in the real warehouse is in tests/inroom.gd.
# Headless: the rules run through CornholeGame.step / press, the outing through Outings.press / tick.

const Corn := preload("res://scripts/cornhole_game.gd")
const CREW := ["Alan", "Garrison", "Dan", "Maya", "Vic"]
const TIERS := {
	"easy": {"to": 11, "opp_skill": -0.08, "aim_speed": 1.0, "power_speed": 0.8, "assist": true},
	"normal": {"to": 15, "opp_skill": 0.0, "aim_speed": 1.3, "power_speed": 1.1, "assist": false},
	"hard": {"to": 21, "opp_skill": 0.06, "aim_speed": 1.7, "power_speed": 1.5, "assist": false},
}
const BRANDS := ["WEBER", "TRAEGER", "COLEMAN", "BUDWEISER", "COORS", "HEINZ", "KRAFT", "MCDONALD", "WENDY", "HOME DEPOT", "PEPSI", "COCA", "SPAM"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r


func _game(tier: String, seed_n: int, crew := CREW, extra := {}) -> RefCounted:
	var p: Dictionary = TIERS[tier].duplicate()
	p.merge(extra, true)
	var g := Corn.new()
	g.setup(p, crew, _rng(seed_n))
	return g


# plays the whole game with the stops at aim a and power p (plus a sloppiness: standard deviations of the stop)
func _play(g: RefCounted, a_sd: float, p_sd: float, r: RandomNumberGenerator) -> void:
	var guard := 0
	while not g.is_done() and guard < 30000:
		guard += 1
		if g.phase == "aim":
			g.marker = clampf(0.5 + r.randfn(0.0, a_sd), 0.0, 1.0)
			g.press()
		elif g.phase == "power":
			g.power = clampf(Corn.POWER_BEST + r.randfn(0.0, p_sd), 0.0, 1.0)
			g.press()
		g.step(0.1)


# the next bag of yours: step to the aim phase
func _to_aim(g: RefCounted) -> void:
	var guard := 0
	while g.phase != "aim" and guard < 400:
		guard += 1
		g.step(0.1)


func _throw(g: RefCounted, aim: float, pow_v: float) -> void:
	_to_aim(g)
	g.marker = aim
	g.press()
	g.power = pow_v
	g.press()


func _finish_bag(g: RefCounted) -> void:
	var guard := 0
	while g.phase in ["flight", "settle"] and guard < 100:
		guard += 1
		g.step(0.1)


func _init() -> void:
	await process_frame
	var d := root.get_node("Difficulty")
	var o := root.get_node("Outings")
	var career := root.get_node("Career")
	var sfx := root.get_node("Sfx")
	var campaign := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var game := root.get_node("Game")
	var world := root.get_node("World")
	game.title_mode = false
	campaign.save_prefix = "user://test_corn_%d_" % OS.get_process_id()  # the career file of this test, not the real one
	career.reset_all()

	# ---- the tiers are in the table
	for key in ["corn.to", "corn.opp_skill", "corn.aim_speed", "corn.power_speed", "corn.assist"]:
		_check(d.TABLE.has(key) and d.TABLE[key].size() == 3, "%s has three tiers" % key)
	_check(d.TABLE["corn.to"] == [11, 15, 21], "play to 11 / 15 / 21")
	_check(d.TABLE["corn.aim_speed"][0] < d.TABLE["corn.aim_speed"][2] and d.TABLE["corn.power_speed"][0] < d.TABLE["corn.power_speed"][2], "the bars are slower on easy")
	_check(d.TABLE["corn.opp_skill"][0] < d.TABLE["corn.opp_skill"][2], "the crew is better on hard")
	for tier in TIERS:
		d.set_tier(tier)
		_check(d.i("corn.to") == TIERS[tier].to and is_equal_approx(d.f("corn.aim_speed"), TIERS[tier].aim_speed), "%s: Difficulty.f matches the table the test uses" % tier)
	d.set_tier("normal")

	# ---- where a bag lands
	var g := _game("normal", 1)
	_check(Corn.spot(0.5, Corn.POWER_BEST).is_equal_approx(Vector2(Corn.HOLE_X, 0.0)), "aim 0.5 and power 0.6 are the hole")
	_check(g._classify(Vector2(Corn.HOLE_X, 0.0)) == "hole", "the middle of the hole is a hole")
	_check(g._classify(Vector2(Corn.HOLE_X + Corn.HOLE_R - 0.5, 0.0)) == "hole", "inside the rim is a hole")
	_check(g._classify(Vector2(Corn.HOLE_X, Corn.HOLE_R + Corn.LIP + 1.0)) == "board", "past the lip it stays on the board")
	_check(g._classify(Vector2(20.0, 5.0)) == "board", "the middle of the board is a board")
	_check(g._classify(Vector2(20.0, 20.0)) == "floor", "off the side is the floor")
	_check(g._classify(Vector2(55.0, 0.0)) == "floor", "too long is the floor")
	_check(g._classify(Vector2(-3.0, 0.0)) == "floor", "short is the floor on normal")
	var easy := _game("easy", 1)
	_check(easy._classify(Vector2(-3.0, 0.0)) == "board", "easy: a bag that lands just short slides onto the board")
	_check(easy._classify(Vector2(-12.0, 0.0)) == "floor", "easy: but not a bag that lands far short")
	var lip_in := 0
	for k in 200:
		if _game("normal", k)._classify(Vector2(Corn.HOLE_X, Corn.HOLE_R + 1.0)) == "hole":
			lip_in += 1
	_check(lip_in > 60 and lip_in < 140, "a bag on the lip falls in about half the time (%d of 200)" % lip_in)

	# ---- the order of the round and the party
	_check([g.opponent_for(1), g.opponent_for(2), g.opponent_for(3), g.opponent_for(4), g.opponent_for(5), g.opponent_for(6)] == ["Alan", "Garrison", "Dan", "Maya", "Vic", "Alan"], "Alan, Garrison, Dan, Maya, Vic, then round again")
	var small := _game("normal", 1, ["Vic", "Dan", "Morgan"])
	_check(small.crew == ["Dan", "Vic"] and small.opponent_for(1) == "Dan" and small.opponent_for(2) == "Vic", "a smaller party plays in the same order (Morgan has no cornhole row)")
	var alone := _game("normal", 1, [])
	_check(alone.opponent_for(1) == "THE CREW", "nobody there: you play the house")

	# ---- a round: phases, four bags each, cancellation
	g = _game("normal", 7)
	_check(g.phase == "ready" and g.round_no == 1 and g.opp == "Alan" and g.score_you == 0, "a round opens with a short READY")
	_to_aim(g)
	_check(g.phase == "aim" and g.bag_no() == 1, "then the aim marker runs")
	g.marker = 0.5
	_check(g.press() == "aim" and g.phase == "power", "E stops the aim and the power bar starts")
	g.power = Corn.POWER_BEST
	_check(g.press() == "throw" and g.phase == "flight" and g.flying.who == "you", "E stops the power and the bag flies")
	_check(g.press() == "", "E does nothing while the bag is in the air")
	_finish_bag(g)
	_check(g.phase == "opp" and g.landed.size() == 1, "the crew member throws next")
	var guard := 0
	while g.phase != "aim" and g.phase != "round_end" and guard < 200:
		guard += 1
		g.step(0.1)
	_check(g.phase == "aim" and g.landed.size() == 2 and g.bag_no() == 2, "then bag two of yours")
	for k in 3:
		_throw(g, 0.5, Corn.POWER_BEST)
		_finish_bag(g)
	guard = 0
	while g.phase != "round_end" and guard < 300:
		guard += 1
		g.step(0.1)
	_check(g.phase == "round_end" and g.landed.size() == 8, "four bags each: eight bags")
	_check(g.round_you >= 9, "four bags at the hole score at least 9 (%d, a bag on the lip can miss)" % g.round_you)
	_check(g.score_you + g.score_opp == absi(g.round_you - g.round_opp), "only the difference scores (%d to %d: %d - %d)" % [g.score_you, g.score_opp, g.round_you, g.round_opp])
	# cancellation by hand
	g = _game("normal", 3)
	g.round_you = 7
	g.round_opp = 4
	g._end_round()
	_check(g.score_you == 3 and g.score_opp == 0 and g.round_net == 3, "7 against 4: you get 3")
	g.round_you = 5
	g.round_opp = 8
	g._end_round()
	_check(g.score_you == 3 and g.score_opp == 3, "5 against 8: they get 3")
	g.round_you = 6
	g.round_opp = 6
	g._end_round()
	_check(g.score_you == 3 and g.score_opp == 3 and g.msg.contains("CANCEL"), "6 against 6 cancels")
	# the next round has the next opponent
	g.phase = "round_end"
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.round_no == 2 and g.opp == "Garrison" and g.phase == "ready" and g.landed.is_empty(), "the next round: Garrison, a clear board")

	# ---- the target and the stars
	g = _game("normal", 4)
	g.score_you = 14
	g.round_you = 5
	g.round_opp = 0
	g._end_round()
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.is_done() and g.won and g.margin() == 19 and g.stars() == 3, "past the target by a mile: won, 3 stars")
	g = _game("normal", 4)
	g.score_you = 12
	g.score_opp = 9
	g.round_you = 4
	g.round_opp = 0
	g._end_round()
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.is_done() and g.won and g.margin() == 7 and g.stars() == 3, "a win by 7 is 3 stars")
	g = _game("normal", 4)
	g.score_you = 12
	g.score_opp = 11
	g.round_you = 4
	g.round_opp = 0
	g._end_round()
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.is_done() and g.won and g.margin() == 5 and g.stars() == 2, "a win by 5 is 2 stars")
	g = _game("normal", 4)
	g.score_opp = 14
	g.score_you = 3
	g.round_you = 0
	g.round_opp = 2
	g._end_round()
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.is_done() and not g.won and g.stars() == 0, "a loss is 0 stars")
	g = _game("normal", 4, CREW, {"floor": 1})
	g.score_opp = 14
	g.round_opp = 2
	g._end_round()
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.is_done() and g.stars() == 1, "Cozy Easy: a loss still earns a star")
	g = _game("normal", 4)
	_check(g.stars() == 0 and not g.is_done(), "no stars before the end")
	# the game cannot go on forever
	g = _game("hard", 4)
	g.round_no = Corn.MAX_ROUNDS
	g.score_you = 8
	g.score_opp = 8
	g._end_round()
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(not g.is_done() and g.round_no == Corn.MAX_ROUNDS + 1, "tied at the round limit: one more round")
	g.round_no = Corn.MAX_ROUNDS + 2
	g.phase = "round_end"
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.is_done() and not g.won, "a tie after the extra rounds is a loss")
	g = _game("hard", 4)
	g.round_no = Corn.MAX_ROUNDS
	g.score_you = 9
	g.score_opp = 8
	g.phase = "round_end"
	g.t = Corn.ROUND_PAUSE
	g.step(0.1)
	_check(g.is_done() and g.won and g.stars() == 2, "ahead at the round limit: a win")

	# ---- the crew: tempers
	var errs := {}
	for who in CREW:
		var h := _game("normal", 11, CREW)
		h.opp = who
		var n_in := 0
		var tot := 0
		for k in 400:
			h.throw_opp()
			var kind: String = h.flying.kind
			tot += 3 if kind == "hole" else (1 if kind == "board" else 0)
			n_in += 1 if kind == "hole" else 0
		errs[who] = float(tot) / 400.0
	_check(errs.Alan > errs.Dan, "Alan is a better thrower than Dan (%.2f against %.2f a bag)" % [errs.Alan, errs.Dan])
	_check(errs.Alan > errs.Garrison and errs.Maya > errs.Dan and errs.Alan > 1.3, "the crew scores 1.3 to 2.3 a bag, Alan on top (Alan %.2f, Garrison %.2f, Maya %.2f, Vic %.2f)" % [errs.Alan, errs.Garrison, errs.Maya, errs.Vic])
	var h2 := _game("normal", 5)
	h2.opp = "Alan"
	var sa: Vector2 = h2.opp_sigma("Alan")
	h2.opp = "Maya"
	var sm: Vector2 = h2.opp_sigma("Maya")
	_check(sa.y / sa.x < sm.y / sm.x, "Alan is precise: less sideways error than Maya for the same distance")
	h2._hot = 1.0
	var hot: Vector2 = h2.opp_sigma("Garrison")
	h2._hot = -1.0
	var cold: Vector2 = h2.opp_sigma("Garrison")
	_check(hot.x < cold.x, "Garrison is streaky: tighter after a hole (%.1f) than after a miss (%.1f)" % [hot.x, cold.x])
	var vic_crowd := _game("normal", 5, CREW)
	var vic_few := _game("normal", 5, ["Vic", "Alan"])
	_check(vic_crowd.opp_sigma("Vic").x < vic_few.opp_sigma("Vic").x, "Vic is a show-off: better with an audience (%.1f against %.1f)" % [vic_crowd.opp_sigma("Vic").x, vic_few.opp_sigma("Vic").x])
	vic_few._you_hole_round = true
	_check(is_equal_approx(vic_few.opp_sigma("Vic").x, vic_crowd.opp_sigma("Vic").x), "and when you just scored")
	var wild := 0
	var steady := 0
	var dan := _game("normal", 9)
	dan.opp = "Dan"
	var maya := _game("normal", 9)
	maya.opp = "Maya"
	for k in 600:
		dan.throw_opp()
		maya.throw_opp()
		wild += 1 if absf(float(dan.flying.px) - Corn.HOLE_X) > 22.0 else 0
		steady += 1 if absf(float(maya.flying.px) - Corn.HOLE_X) > 22.0 else 0
	_check(wild > steady * 2, "Dan is wild: far more throws nobody planned (%d against Maya's %d)" % [wild, steady])

	# ---- tiers: a perfect run wins by 7+ on every tier, and the crew mix; a sloppy one loses
	for tier in TIERS:
		var all3 := true
		var wins := 0
		for k in 12:
			var pg := _game(tier, 300 + k)
			_play(pg, 0.0, 0.0, _rng(k))
			all3 = all3 and pg.is_done() and pg.stars() == 3
			wins += 1 if pg.won else 0
		_check(all3, "%s: perfect play (aim 0.5, power 0.6) is 3 stars in 12 of 12 games" % tier)
		var lost := 0
		for k in 12:
			var pg := _game(tier, 400 + k)
			_play(pg, 0.3, 0.25, _rng(k))
			lost += 0 if pg.won else 1
		_check(lost >= 9, "%s: stopping the bars anywhere loses most games (%d of 12 lost)" % [tier, lost])
	var long_hard := _game("hard", 301)
	_play(long_hard, 0.0, 0.0, _rng(1))
	_check(long_hard.score_you >= 21 and long_hard.round_no <= 8, "hard: a perfect run needs the target 21 (%d rounds)" % long_hard.round_no)

	# ---- determinism
	var ra := _game("normal", 77)
	var rb := _game("normal", 77)
	var rc := _game("normal", 78)
	_play(ra, 0.07, 0.05, _rng(5))
	_play(rb, 0.07, 0.05, _rng(5))
	_play(rc, 0.07, 0.05, _rng(5))
	_check(ra.score_you == rb.score_you and ra.score_opp == rb.score_opp and ra.round_no == rb.round_no, "the same seed gives the same game (%d-%d)" % [ra.score_you, ra.score_opp])
	_check(ra.score_you != rc.score_you or ra.score_opp != rc.score_opp or ra.round_no != rc.round_no, "another seed gives another game")

	# ---- events and flight
	g = _game("normal", 21)
	_throw(g, 0.5, Corn.POWER_BEST)
	g.events.clear()
	_finish_bag(g)
	_check(g.events.any(func(e: Dictionary) -> bool: return e.e in ["hole", "knock", "thud"]), "a landing says what happened (for the sound)")
	_check(g.msg != "", "and leaves a message")

	# ---- the outing: card, overlay game, hint, counters, medal, texts
	_check(o.GAMES.has("cornhole") and o.GAMES.cornhole.label == "CORNHOLE" and o.GAMES.cornhole.cost == 100, "the outing list has cornhole at $100")
	_check(o.ROOMS.cornhole == "warehouse" and o.SPOTS.cornhole.size() == 6, "it is played in the warehouse with a spot for each cast member")
	_check(o.ROOM_INTRO.has("cornhole") and str(o.GAMES.cornhole.blurb).length() > 40, "it has its intro text")
	var texts: Array = [str(o.GAMES.cornhole.blurb), str(o.ROOM_INTRO.cornhole), str(o.GAMES.cornhole.keys)]
	for who in ["Alan", "Garrison", "Dan", "Vic", "Maya", "Morgan"]:
		for kind in ["hole", "miss"]:
			var lines: Array = o.CREW_LINES[who].get(kind, [])
			_check(lines.size() >= 2, "%s: two %s lines" % [who, kind])
			for line in lines:
				texts.append(str(line))
				_check(str(line).length() <= 40, "%s %s: '%s' fits a caption" % [who, kind, line])
	var brand := ""
	for text in texts:
		for name in BRANDS:
			if str(text).to_upper().contains(name):
				brand = "%s in '%s'" % [name, text]
	_check(brand == "", "no brand names in the cornhole text (%s)" % brand)
	campaign.new_game(campaign.FREE)
	world.time_scale = 1.0
	o.enabled = true
	o.use_rooms = false
	o.start("cornhole", false, {"party": ["Alan", "Garrison", "Dan"]})
	_check(o.is_open and o.game == "cornhole" and o.phase == "intro", "the overlay game opens on its intro page")
	_check(o.cornholers() == ["Alan", "Garrison", "Dan"], "the opponents are the party in cornhole order")
	_check(o.hint() == "ENTER = START  ESC = SKIP", "intro hint")
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o.g.has("game") and o.g.game.crew == ["Alan", "Garrison", "Dan"], "ENTER starts the game")
	_check(o.hint() == o.GAMES.cornhole.keys, "without a room the hint is the key line")
	o.tick(2.0)
	_check(o.g.game.phase == "aim", "the aim runs after the READY")
	o.press(KEY_E)
	_check(o.g.game.phase == "power", "E stops the aim")
	o.press(KEY_E)
	_check(o.g.game.phase == "flight", "E stops the power")
	var o_stars := 0
	guard = 0
	while o.phase == "play" and guard < 6000:
		guard += 1
		var cg: RefCounted = o.g.game
		if cg.phase == "aim":
			cg.marker = 0.5
			o.press(KEY_E)
		elif cg.phase == "power":
			cg.power = Corn.POWER_BEST
			o.press(KEY_E)
		o.tick(0.1)
	o_stars = o.stars
	_check(o.phase == "result" and o_stars >= 2, "a perfect game reaches the result page (%d stars)" % o_stars)
	_check(o.g.game.holes >= 10 and career.value("bags_in_hole") == o.g.game.holes, "your holes are counted (%d)" % o.g.game.holes)
	_check(career.value("stars.cornhole") == o_stars and career.value("outings") >= 1, "the best stars are noted for the career screen")
	_check(o.best.get("cornhole", 0) == o_stars, "the outing remembers the best result")
	_check(sfx.played.has("bag_hole") and sfx.played.has("bag_knock"), "the sounds were asked for")
	_check(career.has_medal("bag_man") == (career.value("bags_in_hole") >= 10), "BAG MAN is earned with 10 bags in the hole (%d)" % career.value("bags_in_hole"))
	_check(o.lines.any(func(l: String) -> bool: return l.contains("YOU WON")), "the result page says who won: %s" % str(o.lines))
	o.press(KEY_ENTER)
	_check(not o.is_open, "ENTER closes the result")
	# leaving early
	o.start("cornhole", false, {"party": ["Alan"]})
	o.press(KEY_ENTER)
	o.tick(2.0)
	o.press(KEY_ESCAPE)
	_check(o.phase == "result" and o.stars == -1, "Esc leaves early")
	o.press(KEY_ENTER)
	# a loss with Cozy Easy keeps a star
	d.set_tier("easy")
	campaign.new_game("tech")
	_check(d.cozy_on(), "cozy is on in a tech campaign on easy")
	o.start("cornhole", false, {"party": ["Alan", "Garrison"]})
	o.press(KEY_ENTER)
	var cz: RefCounted = o.g.game
	_check(cz.floor_stars == 1, "the cozy floor is passed to the game")
	cz.score_opp = 99
	cz.phase = "round_end"
	cz.t = Corn.ROUND_PAUSE
	o.tick(0.1)
	o.tick(2.0)
	_check(o.phase == "result" and o.stars == 1, "Cozy Easy: losing is still 1 star (%d)" % o.stars)
	o.press(KEY_ENTER)
	d.set_tier("normal")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
