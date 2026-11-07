extends SceneTree
# gdlint:disable=max-line-length
# DARTS (the warehouse board, a casual game): the scoring table and the ring geometry, three darts a turn for three rounds, the crew's
# turns (order, temper, skill), the drifting reticle (steady spot, the sweet spot moves per dart from the zone stream), seeded
# determinism, the tiers and the mastery blend, the star thresholds, a bot with human timing wins most games and one that presses
# anywhere loses, and the casual game around it: the card, the overlay game, early exit, the campaign effects (clock, energy, a
# little goodwill once a day, a free game for the owner), Career records and the BULLSEYE medal, saves, no brand names.
# Headless: the rules run through DartsGame.step / press, the game through Outings.press / tick.

const Darts := preload("res://scripts/darts_game.gd")
const TIERS := {
	"easy": {"drift": 46.0, "speed": 1.5, "noise": 6.0, "opp_skill": -0.08},
	"normal": {"drift": 58.0, "speed": 1.9, "noise": 7.0, "opp_skill": 0.0},
	"hard": {"drift": 70.0, "speed": 2.4, "noise": 8.0, "opp_skill": 0.06},
}
const BRANDS := ["WINMAU", "UNICORN", "HARROWS", "BUDWEISER", "COORS", "PEPSI", "COCA", "HEINZ", "MCDONALD", "HOME DEPOT"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r


func _game(tier: String, seed_n: int, crew := ["Alan", "Garrison"], extra := {}) -> RefCounted:
	var p: Dictionary = TIERS[tier].duplicate()
	p["zone_rng"] = _rng(seed_n + 99)
	p.merge(extra, true)
	var g := Darts.new()
	g.setup(p, crew, _rng(seed_n))
	return g


# the moment of the aim (seconds) when the reticle is nearest a target, searched in [lo, hi]
func _aim_time(g: RefCounted, target: Vector2, lo: float, hi: float) -> float:
	var best_t := lo
	var best_d := 1e9
	var t := lo
	while t <= hi:
		var d: float = (g.reticle_at(t) - target).length()
		if d < best_d:
			best_d = d
			best_t = t
		t += 0.01
	return best_t


# plays a whole game: a "human" presses near the best moment for the bull (jitter = seconds of timing error), "random" anywhere
func _play(g: RefCounted, mode: String, jitter: float, r: RandomNumberGenerator) -> void:
	var guard := 0
	while not g.is_done() and guard < 20000:
		guard += 1
		if g.phase == "aim":
			if mode == "random":
				g.aim_t = r.randf_range(0.0, 4.0)
			else:
				g.aim_t = maxf(0.0, _aim_time(g, Vector2.ZERO, 0.8, 2.2) + r.randfn(0.0, jitter))
			g.press()
		g.step(0.05)


func _to_phase(g: RefCounted, want: String) -> void:
	var guard := 0
	while g.phase != want and guard < 2000:
		guard += 1
		g.step(0.05)


func _init() -> void:
	await process_frame
	var d := root.get_node("Difficulty")
	var o := root.get_node("Outings")
	var career := root.get_node("Career")
	var campaign := root.get_node("Campaign")
	var world := root.get_node("World")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var shift := root.get_node("Shift")
	var owner := root.get_node("Owner")
	var game := root.get_node("Game")
	var msp := root.get_node("Msp")
	var sfx := root.get_node("Sfx")
	sfx.silent = true
	d.settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	campaign.save_prefix = "user://test_%d_" % OS.get_process_id()
	career.reset_all()
	game.title_mode = false
	d.fixed_take = false

	# ---- the scoring table
	var ok_table := true
	for num in Darts.SEGMENTS:
		var single: Dictionary = Darts.score_at(Darts.wedge_centre(num, 60.0))
		var treble: Dictionary = Darts.score_at(Darts.wedge_centre(num, 103.0))
		var double: Dictionary = Darts.score_at(Darts.wedge_centre(num, 166.0))
		ok_table = ok_table and single.pts == num and single.ring == "single" and treble.pts == 3 * num and treble.ring == "treble" and double.pts == 2 * num and double.ring == "double"
	_check(ok_table, "every wedge scores its number: single, treble x3 (ring 99 to 107 mm) and double x2 (ring 162 to 170 mm)")
	_check(Darts.SEGMENTS.size() == 20 and Darts.SEGMENTS[0] == 20 and Darts.SEGMENTS[10] == 3 and Darts.SEGMENTS[5] == 6, "the wedges run 20 1 18 4 13 6 10 15 2 17 3 19 7 16 8 11 14 9 12 5 from the top, clockwise")
	_check(Darts.score_at(Vector2.ZERO).pts == 50 and Darts.score_at(Vector2.ZERO).ring == "bull", "the bull is 50")
	_check(Darts.score_at(Vector2(0.0, -10.0)).pts == 25 and Darts.score_at(Vector2(0.0, -10.0)).ring == "outer", "the outer bull is 25")
	_check(Darts.score_at(Vector2(6.3, 0.0)).ring == "bull" and Darts.score_at(Vector2(6.4, 0.0)).ring == "outer", "the bull ends at 6.35 mm")
	_check(Darts.score_at(Vector2(15.8, 0.0)).ring == "outer" and Darts.score_at(Vector2(16.0, 0.0)).ring == "single", "the outer bull ends at 15.9 mm")
	_check(Darts.score_at(Vector2(0.0, -98.0)).ring == "single" and Darts.score_at(Vector2(0.0, -100.0)).ring == "treble", "the treble ring starts at 99 mm")
	_check(Darts.score_at(Vector2(0.0, -106.0)).ring == "treble" and Darts.score_at(Vector2(0.0, -108.0)).ring == "single", "and ends at 107 mm")
	_check(Darts.score_at(Vector2(0.0, -161.0)).ring == "single" and Darts.score_at(Vector2(0.0, -163.0)).ring == "double", "the double ring starts at 162 mm")
	_check(Darts.score_at(Vector2(0.0, -169.0)).ring == "double" and Darts.score_at(Vector2(0.0, -171.0)).pts == 0, "the board ends at 170 mm: beyond it is nothing")
	_check(Darts.score_at(Vector2(0.0, -130.0)).pts == 20 and Darts.score_at(Vector2(0.0, 130.0)).pts == 3, "20 is straight up and 3 straight down")
	_check(Darts.score_at(Vector2(130.0, 0.0)).pts == 6 and Darts.score_at(Vector2(-130.0, 0.0)).pts == 11, "6 is on the right and 11 on the left")
	_check(Darts.score_at(Vector2(0.0, -103.0)).pts == 60 and Darts.score_at(Vector2(0.0, -166.0)).pts == 40, "treble 20 is 60, double 20 is 40")
	_check(Darts.ring_label(Darts.score_at(Vector2.ZERO)) == "BULLSEYE! 50" and Darts.ring_label(Darts.score_at(Vector2(0.0, -103.0))) == "TREBLE 20: 60", "the labels name the ring")

	# ---- three darts a turn, three rounds, in order
	var g := _game("normal", 5)
	_check(g.players == ["You", "Alan", "Garrison"] and g.rounds == 3, "you and the crew, three rounds")
	_check(g.thrower() == "You" and g.round_no() == 1 and g.phase == "ready", "you start")
	var order := []
	var darts_by := {"You": 0, "Alan": 0, "Garrison": 0}
	var guard := 0
	while not g.is_done() and guard < 20000:
		guard += 1
		if g.phase == "aim":
			g.aim_t = 1.3
			g.press()
		if g.phase == "flight" and g.t == 0.0:
			darts_by[g.flying.who] += 1
			if order.is_empty() or order[order.size() - 1] != g.flying.who:
				order.append(str(g.flying.who))
		g.step(0.05)
	_check(g.is_done() and order == ["You", "Alan", "Garrison", "You", "Alan", "Garrison", "You", "Alan", "Garrison"], "turns go You, Alan, Garrison, three times: %s" % str(order))
	_check(darts_by == {"You": 9, "Alan": 9, "Garrison": 9} and g.thrown == 9, "nine darts each, three a turn")
	_check(int(g.totals["You"]) >= 0 and g.best_opp() >= 0, "the totals add up")
	var sum_you := 0
	var again := _game("normal", 5)
	var guard_b := 0
	var seen := 0
	while not again.is_done() and guard_b < 20000:
		guard_b += 1
		if again.phase == "aim":
			again.aim_t = 1.3
			again.press()
		for e in again.events:
			if str(e.e) in ["dart", "bull"] and str(e.who) == "You":
				sum_you += int(e.pts)
				seen += 1
		again.events.clear()
		again.step(0.05)
	_check(seen == 9 and sum_you == int(again.totals["You"]), "the landing events add up to your total (%d in %d darts)" % [sum_you, seen])
	var mid := _game("normal", 6)
	_to_phase(mid, "aim")
	mid.aim_t = 1.3
	mid.press()
	_check(mid.phase == "flight" and mid.press() == "", "E while the dart is in the air does nothing")
	_to_phase(mid, "aim")
	_check(mid.dart_i == 1 and mid.darts_now.size() == 1, "the dart stays in the board for the turn")
	var solo := _game("normal", 6, [])
	_check(solo.players == ["You", "THE HOUSE"], "nobody around: you against the house")
	var cap := _game("normal", 6, ["John", "Dan", "Alan", "Maya", "Garrison"])
	_check(cap.crew == ["Alan", "Garrison", "Dan", "Maya", "John"], "the crew keeps the table order")

	# ---- pulling the darts, and the turn counter
	var pull := _game("normal", 8)
	for k in 3:
		_to_phase(pull, "aim")
		pull.aim_t = 1.3
		pull.press()
	_to_phase(pull, "pull")
	_check(pull.darts_now.size() == 3 and pull.turn_pts == int(pull.totals["You"]) and pull.msg.contains("THIS TURN"), "after three darts: the turn total on the screen")
	_to_phase(pull, "ready")
	_check(pull.darts_now.is_empty() and pull.thrower() == "Alan", "then the darts come out and Alan steps up")

	# ---- the reticle: it settles, and every dart has a new sweet spot
	var ret := _game("normal", 9)
	_check(is_equal_approx(ret.steadiness(0.0), 1.0) and is_equal_approx(ret.steadiness(Darts.STEADY_T), Darts.STEADY_MIN) and is_equal_approx(ret.steadiness(Darts.STEADY_T * 2.0), 1.0), "the wobble is full at the start, smallest at STEADY_T, full again when the arm tires")
	_check(ret.steadiness(0.6) > Darts.STEADY_MIN and ret.steadiness(2.0) > Darts.STEADY_MIN, "and in between it is on its way")
	var spread_steady := 0.0
	var spread_wobble := 0.0
	for k in 40:
		ret.roll_zone()
		spread_steady = maxf(spread_steady, (ret.reticle_at(Darts.STEADY_T) - ret.zc).length())
		spread_wobble = maxf(spread_wobble, (ret.reticle_at(0.0) - ret.zc).length())
	_check(spread_steady <= 58.0 * Darts.STEADY_MIN * 1.3 and spread_wobble > spread_steady, "the reticle stays within the drift of the centre, closer when steady (%.0f against %.0f mm)" % [spread_steady, spread_wobble])
	var zs := []
	var speeds := []
	var inside := true
	for k in 12:
		ret.roll_zone()
		zs.append(ret.zc)
		speeds.append(snappedf(ret.zs, 0.001))
		inside = inside and absf(ret.zc.x) <= Darts.ZONE_C and absf(ret.zc.y) <= Darts.ZONE_C and ret.zs >= 0.88 and ret.zs <= 1.14
	var distinct := {}
	for z in zs:
		distinct[str(z)] = true
	_check(inside and distinct.size() >= 10 and speeds.size() > 0, "the sweet spot moves every dart (centre within %.0f mm, speed 0.88 to 1.14), %d different centres in 12" % [Darts.ZONE_C, distinct.size()])
	_check(ret.reticle_at(1.0) != ret.reticle_at(1.2), "the reticle moves with time")
	var still := _game("normal", 9, ["Alan"], {"zone_rng": null})
	still.roll_zone()
	_check(still.zc == Vector2.ZERO and is_equal_approx(still.zs, 1.0), "without a zone stream the sweet spot stays on the bull")
	# the zone comes from Difficulty's own stream "darts_zone", like Difficulty.zone("darts", ...)
	d.seed_run(2468)
	var za: float = d.zone("darts", -1.0, 1.0)
	d.seed_run(2468)
	var zr: RandomNumberGenerator = d.rng("darts_zone")
	_check(is_equal_approx(za, zr.randf_range(-1.0, 1.0)), "Difficulty.zone('darts') and the game's zone stream are the same stream")

	# ---- the throw lands at the reticle plus the scatter
	var aim := _game("normal", 11, ["Alan"], {"noise": 0.0})
	_to_phase(aim, "aim")
	aim.aim_t = 1.3
	var where: Vector2 = aim.reticle()
	aim.press()
	_check(is_equal_approx(float(aim.flying.px), where.x) and is_equal_approx(float(aim.flying.py), where.y), "without scatter the dart lands exactly on the reticle")
	var far := 0.0
	for k in 40:
		var noisy := _game("normal", 200 + k, ["Alan"], {"noise": 10.0})
		_to_phase(noisy, "aim")
		noisy.aim_t = 1.3
		var at: Vector2 = noisy.reticle()
		noisy.press()
		far = maxf(far, (Vector2(float(noisy.flying.px), float(noisy.flying.py)) - at).length())
	_check(far > 1.0 and far < 60.0, "the scatter is a few millimetres (%.1f at most)" % far)

	# ---- seeded determinism
	var ra := _game("normal", 77)
	var rb := _game("normal", 77)
	var rc := _game("normal", 78)
	_play(ra, "human", 0.06, _rng(5))
	_play(rb, "human", 0.06, _rng(5))
	_play(rc, "human", 0.06, _rng(5))
	_check(ra.totals == rb.totals and ra.bulls == rb.bulls and ra.best_dart == rb.best_dart, "the same seed gives the same game (%s)" % str(ra.totals))
	_check(ra.totals != rc.totals, "another seed gives another game")

	# ---- the crew: skills, tempers, targets
	var crew_game := _game("normal", 31, ["Alan", "Garrison", "Dan", "Maya", "John"])
	var skills := {}
	for who in ["Alan", "Garrison", "Dan", "Maya", "John"]:
		skills[who] = crew_game.sigma_of(who)
	_check(skills.Alan < skills.Garrison and skills.Alan < skills.Dan and skills.Maya < skills.Dan, "Alan and Maya are the steadiest (error %.0f and %.0f mm), Dan the loosest (%.0f)" % [skills.Alan, skills.Maya, skills.Dan])
	_check(crew_game.target_of("Alan") != Vector2.ZERO and crew_game.target_of("Dan") == Vector2.ZERO, "the good ones aim at the treble 20, the rest at the bull")
	var wild := 0
	var steady := 0
	var dan := _game("normal", 41, ["Dan"])
	var maya := _game("normal", 41, ["Maya"])
	for k in 800:
		dan.turn_i = 1
		maya.turn_i = 1
		dan.throw_opp()
		maya.throw_opp()
		steady += 1 if (Vector2(float(dan.flying.px), float(dan.flying.py)) - dan.target_of("Dan")).length() > 70.0 else 0
		wild += 1 if (Vector2(float(maya.flying.px), float(maya.flying.py)) - maya.target_of("Maya")).length() > 70.0 else 0
	_check(steady > wild * 2, "Dan is wild: many more darts nobody planned (%d against Maya's %d)" % [steady, wild])
	var hot := _game("normal", 43, ["Garrison"])
	var cold_s: float = hot.sigma_of("Garrison")
	hot._hot = 1.0
	var hot_s: float = hot.sigma_of("Garrison")
	hot._hot = -1.0
	var cold_s2: float = hot.sigma_of("Garrison")
	_check(hot_s < cold_s and cold_s2 > cold_s, "Garrison is streaky: tighter after a big dart (%.1f), looser after a miss (%.1f)" % [hot_s, cold_s2])
	var vic := _game("normal", 44, ["John"])
	var vic_plain: float = vic.sigma_of("John")
	vic._you_big = true
	_check(vic.sigma_of("John") < vic_plain, "John shows off when you throw well")

	# ---- the tiers: human timing wins most games on every tier, pressing anywhere loses
	for tier in TIERS:
		var wins := 0
		var lost := 0
		var tot := 0.0
		for k in 20:
			var hg := _game(tier, 500 + k, ["Dan", "John"])
			_play(hg, "human", 0.05, _rng(k))
			wins += 1 if hg.stars() >= 2 else 0
			tot += float(hg.totals["You"])
			var rg := _game(tier, 600 + k, ["Dan", "John"])
			_play(rg, "random", 0.0, _rng(k))
			lost += 0 if rg.stars() >= 2 else 1
		_check(wins >= (12 if tier != "hard" else 9), "%s: a player with good timing wins most games (%d of 20, %.0f points on average)" % [tier, wins, tot / 20.0])
		_check(lost >= 15, "%s: pressing at any moment loses most games (%d of 20 lost)" % [tier, lost])

	# ---- the tiers' numbers and the mastery ramp
	d.set_tier("normal")
	career.reset_all()
	_check(d.f("darts.drift") == 58.0 and d.f("darts.speed") == 1.9 and d.f("darts.noise") == 7.0 and d.f("darts.opp_skill") == 0.0, "normal: the first play is exactly the table (58 mm, 1.9, 7 mm, 0)")
	_check(d.at("darts.drift", "easy") < d.at("darts.drift", "normal") and d.at("darts.drift", "normal") < d.at("darts.drift", "hard") and d.at("darts.speed", "easy") < d.at("darts.speed", "hard"), "harder tiers: a bigger, faster loop")
	_check(d.game_of("darts.drift") == "darts" and d.MASTERY_KEYS.has("darts.drift") and d.MASTERY_KEYS.has("darts.speed") and d.MASTERY_KEYS.has("darts.opp_skill") and not d.MASTERY_KEYS.has("darts.noise"), "the loop, its speed and the crew's skill ramp; the scatter does not")
	career.note_outing("darts", 2, {"casual": true})
	_check(is_equal_approx(d.mastery("darts"), 0.1) and d.f("darts.drift") > 58.0 and d.f("darts.speed") > 1.9, "a good game adds a tenth of the ramp and tightens the numbers (%.1f mm)" % d.f("darts.drift"))
	career.note_outing("darts", 1, {"casual": true})
	career.note_outing("darts", -1, {"casual": true})
	_check(is_equal_approx(d.mastery("darts"), 0.1), "one star and leaving early do not count")
	career.counters["good.darts"] = 10
	_check(is_equal_approx(d.f("darts.drift"), 70.0) and is_equal_approx(d.f("darts.speed"), 2.4) and is_equal_approx(d.f("darts.noise"), 7.0), "full mastery: normal reaches the hard numbers, the scatter stays")
	d.set_tier("hard")
	_check(d.f("darts.drift") > 70.0 and d.f("darts.drift") <= 70.0 + 0.25 * 12.0 + 0.001, "hard goes a little beyond its own value at most (%.1f mm)" % d.f("darts.drift"))
	d.set_tier("easy")
	_check(d.f("darts.drift") < 58.0 and d.f("darts.drift") > 46.0, "easy only blends part of the way (%.1f mm)" % d.f("darts.drift"))
	d.set_tier("normal")
	d.fixed_take = true
	_check(d.f("darts.drift") == 58.0 and d.mastery("darts") == 0.0, "the Free Play fixed take is always the first-play numbers")
	d.fixed_take = false
	career.reset_all()

	# ---- the stars
	var st := _game("normal", 51)
	st.phase = "done"
	st.totals = {"You": 200, "Alan": 150, "Garrison": 100}
	_check(st.stars() == 3 and st.margin() == 50, "a win by 40 or more is 3 stars")
	st.totals = {"You": 200, "Alan": 161, "Garrison": 100}
	_check(st.stars() == 2, "a win by 39 is 2 stars")
	st.totals = {"You": 150, "Alan": 149, "Garrison": 100}
	_check(st.stars() == 2 and st.margin() == 1, "a win by 1 is 2 stars")
	st.totals = {"You": 150, "Alan": 150, "Garrison": 100}
	_check(st.stars() == 1, "a tie is 1 star")
	st.totals = {"You": 100, "Alan": 124, "Garrison": 90}
	_check(st.stars() == 1, "losing by less than 25 is 1 star")
	st.totals = {"You": 100, "Alan": 125, "Garrison": 90}
	_check(st.stars() == 0, "losing by 25 or more is 0 stars")
	st.floor_stars = 1
	_check(st.stars() == 1, "Cozy Easy: never less than 1 star")
	st.phase = "aim"
	_check(st.stars() == 0, "a game that is not over has no stars")

	# ---- the casual game around it: the entry, the texts
	_check(o.GAMES.has("darts") and o.GAMES.darts.label == "DARTS" and o.GAMES.darts.casual and o.GAMES.darts.cost == 0, "the outing table has darts: casual and free")
	_check(o.ROOMS.darts == "warehouse" and o.SPOTS.darts.size() == 6 and o.ROOM_INTRO.has("darts") and str(o.GAMES.darts.keys).begins_with("E = THROW"), "it is played in the warehouse, with an intro and the hint E = THROW")
	_check(o.cost_range() == "$100 to $300", "the evening outing price range ignores it (%s)" % o.cost_range())
	var texts: Array = [str(o.GAMES.darts.blurb), str(o.ROOM_INTRO.darts), str(o.GAMES.darts.keys), str(o.GAMES.darts.label)]
	var brand := ""
	for text in texts:
		for name in BRANDS:
			if str(text).to_upper().contains(name):
				brand = "%s in '%s'" % [name, text]
		_check(str(text) == str(text).to_upper() or str(text).begins_with("E ="), "'%s' is upper case (3x5 font)" % str(text).substr(0, 24))
	_check(brand == "", "no brand names in the darts text (%s)" % brand)

	# ---- Free Play: the card at the board, the overlay game, early exit
	campaign.new_game(campaign.FREE)
	cards.is_open = false
	cards._queue.clear()
	world.time_scale = 1.0
	o.enabled = true
	o.use_rooms = false
	_check(o.darts_ready() and o.offer_darts() and cards.is_open and cards.options.size() == 2, "E at the board in Free Play: a card, play or never mind")
	_check(str(cards.text).contains("Free Play"), "it says nothing is scored")
	cards.pick(1)
	_check(not o.is_open, "NEVER MIND does nothing")
	_check(o.offer_darts(), "E again asks again")
	cards.pick(0)
	_check(o.is_open and o.game == "darts" and o.casual_on() and o.phase == "intro", "LET'S PLAY opens the game on its intro page")
	_check(not o.offer_darts() and not o.darts_ready(), "while a game is open the board offers nothing")
	_check(o.hint() == "ENTER = START  ESC = SKIP", "the intro hint")
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o.g.game.players.size() >= 2 and o.hint() == o.GAMES.darts.keys, "ENTER starts it; without a room the hint is the key line (E = THROW)")
	var dg: RefCounted = o.g.game
	o.tick(1.2)
	_check(dg.phase == "aim", "the reticle is up after the READY")
	var stars0: int = int(career.value("stars.darts"))
	o.press(KEY_ESCAPE)
	_check(o.phase == "result" and o.stars == -1 and o.lines[0].contains("PUT THE DARTS BACK"), "Esc leaves early, nobody minds")
	o.press(KEY_ENTER)
	_check(not o.is_open and career.value("stars.darts") == stars0 and career.value("casual_games") == 0 and career.value("good.darts") == 0, "leaving early records nothing")
	_check(not o.opts.get("casual", false), "and the casual flag is cleared")

	# ---- a whole game through the keys: E throws, the crew take their turns with bubbles
	d.seed_run(31337)
	o.start("darts", false, {"party": ["Alan", "Garrison"]})
	_check(o.casual_on() and o.darts_crew() == ["Alan", "Garrison"], "darts started without the flag is casual anyway; the party are the opponents")
	o.press(KEY_ENTER)
	dg = o.g.game
	o.press(KEY_E)
	_check(dg.phase == "ready", "E before the READY is over does nothing")
	guard = 0
	var heard := false
	var turns_seen := {}
	while o.phase == "play" and guard < 8000:
		guard += 1
		turns_seen[dg.thrower()] = true
		if dg.phase == "aim":
			dg.aim_t = _aim_time(dg, Vector2.ZERO, 0.9, 2.1)
			o.press(KEY_E)
		o.tick(0.05)
		heard = heard or sfx.played.has("dart_hit")
	_check(o.phase == "result" and turns_seen.has("Alan") and turns_seen.has("Garrison") and turns_seen.has("You"), "the whole game plays to the result page (%d stars, %s)" % [o.stars, str(dg.totals)])
	_check(heard, "the dart sounds were asked for")
	_check(career.value("stars.darts") == o.stars and career.value("casual_games") == 1 and career.value("outings") == 0, "the career notes the best stars and a casual game, not a team outing")
	_check(career.value("bulls") == dg.bulls and career.value("darts_best") == int(dg.totals["You"]), "bullseyes and the best score are counted (%d bulls, best %d)" % [dg.bulls, career.value("darts_best")])
	_check(o.lines.any(func(l: String) -> bool: return l.contains("YOU WIN") or l.contains("WINS WITH") or l.contains("TIE")) and o.lines.any(func(l: String) -> bool: return l.contains("BEST DART")), "the result page says who won and your best dart: %s" % str(o.lines))
	_check(o.lines.any(func(l: String) -> bool: return l.contains("FREE PLAY")), "and that Free Play scores nothing")
	_check(o.best.get("darts", -1) == o.stars and o.darts_plays == 1, "the outing remembers it")
	_check(career.has_medal("bullseye") == (dg.bulls > 0), "BULLSEYE is earned with the first bull (%d)" % dg.bulls)
	o.press(KEY_ENTER)
	_check(not o.is_open, "ENTER closes the result")

	# ---- Career: records, the medal, the all-star rule is unchanged
	career.reset_all()
	career.note_outing("darts", 3, {"casual": true, "bulls": 2, "score": 301})
	career.note_outing("darts", 2, {"casual": true, "bulls": 0, "score": 120})
	_check(career.value("stars.darts") == 3 and career.value("bulls") == 2 and career.value("darts_best") == 301 and career.value("casual_games") == 2, "stars, bulls and the best score keep the best")
	_check(career.has_medal("bullseye") and career.value("outings") == 0, "BULLSEYE is a medal, and darts are not outings")
	_check(career.WAREHOUSE_GAMES == ["cornhole", "grill", "chair"] and career.value("wh_stars3") == 0, "darts does not count toward the WAREHOUSE ALL-STAR rule (each of the three)")
	var medal_text := ""
	for m in career.MEDALS:
		if str(m.id) == "bullseye":
			medal_text = str(m.title) + " " + str(m.desc)
	var ids: Array = career.MEDALS.map(func(m: Dictionary) -> String: return str(m.id))
	_check(medal_text == "BULLSEYE HIT THE BULL AT DARTS" and ids.find("bullseye") >= 0 and ids.find("bullseye") < ids.find("year_two"), "the medal comes after the earlier ones, with its text (later medals were added after it)")
	var rows_have := ""
	for row in career.COUNTERS:
		rows_have += str(row[2]) + " "
	_check(rows_have.contains("stars.darts") and rows_have.contains("bulls"), "the career screen has DARTS BEST and BULLSEYES")
	career.save_file()
	var snap: Dictionary = career.counters.duplicate()
	career.reset_all()
	career.load_file()
	_check(career.value("stars.darts") == 3 and career.value("bulls") == snap.bulls and career.has_medal("bullseye"), "the records are saved and loaded")
	career.reset_all()

	# ---- saves: the day counters
	o.darts_plays = 4
	o.darts_day = 6
	o.darts_today = 2
	var saved: Dictionary = o.to_dict()
	o.reset()
	_check(o.darts_plays == 0 and o.darts_day == -1 and o.darts_today == 0, "reset clears them")
	o.from_dict(saved)
	_check(o.darts_plays == 4 and o.darts_day == 6 and o.darts_today == 2, "the save keeps the rounds and today's count")
	o.from_dict({"version": 2, "count": 1})
	_check(o.darts_plays == 0 and o.darts_today == 0, "an older save has none")
	o.reset()

	# ---- the campaign: a few minutes, a little energy, a little goodwill once a day, a free game for the owner
	d.set_tier("normal")
	for mode in ["tech", "owner"]:
		campaign.new_game(mode)
		cards.is_open = false
		cards._queue.clear()
		cards._canvas.visible = false
		world.time_scale = 1.0
		world.clock = 10.0
		msp.tickets.clear()
		msp.tickets.append({"id": 9001, "status": "Open", "sla_total": 600.0, "sla_left": 500.0})
		social.rel["Alan"] = 10
		social.rel["Garrison"] = 10
		social.rel["Dan"] = 10
		owner.cash = 5000
		owner.burnout = 40.0
		shift.energy = 50.0
		var rep0: int = campaign.rep
		var pty: Array = o.darts_party()
		_check(pty.size() >= 1 and pty.size() <= 2 and pty == o.darts_party(), "%s: one or two coworkers are up for it, the pick is repeatable" % mode)
		_check(o.offer_darts() and str(cards.text).contains("quarter of an hour"), "%s: the card says it takes about a quarter of an hour" % mode)
		cards.pick(0)
		_check(o.is_open and o.game == "darts" and o.casual_on(), "%s: the game starts" % mode)
		_check(owner.cash == 5000, "%s: it costs the owner nothing" % mode)
		o.press(KEY_ENTER)
		var cg: RefCounted = o.g.game
		var clock0: float = world.clock
		for who in pty:
			social.rel[who] = 10
		cg.totals = {"You": 300}
		for who in cg.crew:
			cg.totals[who] = 100
		cg.phase = "done"
		o.tick(0.1)
		o.tick(2.0)
		_check(o.phase == "result" and o.stars == 3, "%s: a win by 40 or more is 3 stars" % mode)
		if mode == "tech":
			_check(shift.energy == 52.0 and o.lines.any(func(l: String) -> bool: return l.contains("ENERGY +2")), "tech: +2 energy (%.0f)" % shift.energy)
			var liked := true
			for who in pty:
				liked = liked and social.value(who) == 11
			_check(liked and o.lines.any(func(l: String) -> bool: return l.contains("LIKE YOU")), "tech: the people who played like you one more")
			_check(social.value("Dan") == 10 or pty.has("Dan"), "tech: the others do not care")
		else:
			_check(owner.burnout == 38.0 and owner.cash == 5000, "owner: burnout down 2 and still free (%.0f)" % owner.burnout)
		_check(campaign.rep == rep0 and career.value("outings") == 0, "%s: no reputation and not an outing" % mode)
		o.press(KEY_ENTER)
		_check(not o.is_open and absf(world.clock - (clock0 + o.DARTS_LEN)) < 0.001, "%s: the round took a quarter of an hour on the clock" % mode)
		_check(float(msp.tickets[0].sla_left) < 500.0 and float(msp.tickets[0].sla_left) > 470.0, "%s: the open queue aged a little (%.1f)" % [mode, msp.tickets[0].sla_left])
		_check(o.darts_today == 1 and o.darts_plays == 1, "%s: the day's count" % mode)
		if mode == "tech":
			# the second round of the day: energy again, no more goodwill; the third: no more energy
			for k in 2:
				cards.is_open = false
				cards._queue.clear()
				_check(o.offer_darts(), "tech: round %d is offered" % (k + 2))
				cards.pick(0)
				o.press(KEY_ENTER)
				o.g.game.totals = {"You": 300}
				for who in o.g.game.crew:
					o.g.game.totals[who] = 100
				o.g.game.phase = "done"
				o.tick(0.1)
				o.tick(2.0)
				if k == 0:
					_check(shift.energy == 54.0 and not o.lines.any(func(l: String) -> bool: return l.contains("LIKE YOU")), "tech: the second round gives energy but no more goodwill (%.0f)" % shift.energy)
				else:
					_check(shift.energy == 54.0 and o.lines.any(func(l: String) -> bool: return l.contains("NO MORE BREAKS")), "tech: the third gives none (%.0f)" % shift.energy)
				o.press(KEY_ENTER)
			var next_day: int = campaign.day + 1
			campaign.day = next_day
			cards.is_open = false
			cards._queue.clear()
			_check(o.offer_darts(), "a new day offers again")
			cards.pick(0)
			o.press(KEY_ENTER)
			o.g.game.totals = {"You": 300}
			for who in o.g.game.crew:
				o.g.game.totals[who] = 100
			o.g.game.phase = "done"
			o.tick(0.1)
			o.tick(2.0)
			_check(o.darts_today == 1 and shift.energy == 56.0 and o.lines.any(func(l: String) -> bool: return l.contains("LIKE YOU")), "a new day: energy and goodwill again (%.0f)" % shift.energy)
			o.press(KEY_ENTER)
	# not now: the clock stopped, near closing time, something else has the player
	campaign.new_game("tech")
	cards.is_open = false
	cards._queue.clear()
	cards._canvas.visible = false
	world.time_scale = 1.0
	world.clock = 10.0
	_check(o.darts_ready(), "an ordinary moment in the workday is fine")
	world.time_scale = 0.0
	_check(not o.darts_ready() and not o.offer_darts(), "not while the clock is stopped")
	world.time_scale = 1.0
	world.clock = world.DAY_END - 0.1
	_check(not o.darts_ready(), "not in the last minutes of the day")
	world.clock = 10.0
	o.enabled = false
	_check(not o.darts_ready(), "not with outings off")
	o.enabled = true
	# Cozy Easy: nothing in the queue ages, a lost game is still a star
	d.set_tier("easy")
	campaign.new_game("tech")
	cards.is_open = false
	cards._queue.clear()
	cards._canvas.visible = false
	world.time_scale = 1.0
	world.clock = 10.0
	msp.tickets.clear()
	msp.tickets.append({"id": 9001, "status": "Open", "sla_total": 600.0, "sla_left": 500.0})
	_check(o.offer_darts(), "cozy: the card")
	cards.pick(0)
	o.press(KEY_ENTER)
	var cz: RefCounted = o.g.game
	_check(cz.floor_stars == 1 and is_equal_approx(cz.drift, d.f("darts.drift")), "cozy: the floor is passed to the game, and so is the tier's loop")
	cz.totals = {"You": 10}
	for who in cz.crew:
		cz.totals[who] = 200
	cz.phase = "done"
	o.tick(0.1)
	o.tick(2.0)
	_check(o.phase == "result" and o.stars == 1, "cozy: losing is still 1 star (%d)" % o.stars)
	o.press(KEY_ENTER)
	_check(float(msp.tickets[0].sla_left) == 500.0, "cozy: nothing in the queue aged")
	d.set_tier("normal")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
