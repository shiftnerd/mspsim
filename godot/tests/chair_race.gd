extends SceneTree
# gdlint:disable=max-line-length
# CHAIR RACE (R12 part b): the rules (rhythm and stamina, crashes, countdown, false start), the course, the rivals and their
# seeded skill per tier, a driver bot that proves a perfect run is reachable on every tier and that mashing is not, the
# stars, and the outing around it (invitation card, Free Play, saving the best time, results, the toolbox, the hint line).
# Headless: the race runs through its public functions (ChairRace.step / push), the outing through Outings.press / tick.

const Race := preload("res://scripts/chair_race.gd")
const CREW := ["Alan", "Garrison", "Dan", "Maya", "Vic"]
const TIERS := {
	"easy": {"crash": 0.7, "stamina": 0.9, "slick": 0.8, "par": 1.2, "skill": -0.08},
	"normal": {"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0, "skill": 0.0},
	"hard": {"crash": 1.5, "stamina": 1.1, "slick": 1.3, "par": 0.9, "skill": 0.08},
}

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r


func _race(tier: String, seed_n: int, who := CREW) -> RefCounted:
	var race := Race.new()
	race.setup(TIERS[tier], who, _rng(seed_n))
	return race


# a driver: steers down the middle and round the cones, pushes in rhythm (alternating Z / X every 0.36 s), rests when tired
func _drive(race: RefCounted, mode: String, rest_lo: float, rest_hi: float, dt: float) -> void:
	var look: float = 14.0 + float(race.speed) * 0.3
	var aim: Dictionary = Race.at_s(minf(race.prog + look, Race.length()))
	var off := 0.0
	var best_ahead := 34.0
	for o in race.obstacles:
		if o.down:
			continue
		var d: Vector2 = o.pos - race.pos
		var ahead: float = Vector2.from_angle(race.heading).dot(d)
		if ahead > -2.0 and ahead < best_ahead:
			best_ahead = ahead
			if o.kind == "wet":
				off = 6.0
			elif o.kind == "copier":
				off = -6.0
			else:
				off = -float(o.side) * 6.0
	var target: Vector2 = aim.p + Vector2(-aim.dir.y, aim.dir.x) * off
	var diff: float = angle_difference(race.heading, (target - race.pos).angle())
	var steer := 0.0
	if absf(diff) > 0.05:
		steer = signf(diff)
	var gap := 0.36
	var resting: bool = bool(race.get_meta("rest", false))
	if race.stam < rest_lo:
		resting = true
	elif race.stam > rest_hi:
		resting = false
	race.set_meta("rest", resting)
	if mode == "mash":
		gap = 0.08
		resting = false
	var tight: bool = absf(diff) > 0.6 and mode != "mash"
	if race.clock >= 0.0 and race.clock - float(race._last_push) >= gap and not resting and not tight and float(race.speed) < 78.0:
		race.push(1 - int(race._last_key) if int(race._last_key) >= 0 else 0)
	race.set_meta("steer", steer)
	race.step(dt, steer)


func _run(race: RefCounted, mode: String, rest_lo := 25.0, rest_hi := 70.0) -> void:
	var guard := 0
	while race.phase != "done" and guard < 60 * 120:
		_drive(race, mode, rest_lo, rest_hi, 1.0 / 60.0)
		guard += 1


# the best total over a few ways of resting (any decent player finds one)
func _best_clean(tier: String, seed_n: int) -> float:
	var best := 999.0
	for lo in [20.0, 30.0]:
		for hi in [60.0, 80.0]:
			var race := _race(tier, seed_n)
			_run(race, "rhythm", lo, hi)
			if race.crashes == 0:
				best = minf(best, race.total())
	return best


func _init() -> void:
	await process_frame
	# ---- the course
	var len := Race.length()
	_check(len > 700.0 and len < 1200.0, "the course is a real hallway run (%.0f px)" % len)
	_check(Race.CHECKS.size() == 4 and Race.CHECK_NAMES.size() == 4, "four checkpoints")
	var cone_kinds := {}
	for o in Race.OBSTACLES:
		cone_kinds[o[4]] = true
	_check(cone_kinds.has("cone") and cone_kinds.has("wet") and cone_kinds.has("copier") and cone_kinds.has("bin"), "cones, a wet floor sign, the copier and trash cans")
	var inside := true
	for p in Race.POINTS:
		inside = inside and p.x > 0 and p.y > 0 and p.x < Race.WORLD.x and p.y < Race.WORLD.y
	_check(inside, "every course point is inside the building")
	var a := _race("normal", 7)
	var b := _race("normal", 7)
	var d := _race("normal", 8)
	var same := true
	var differs := false
	for i in a.obstacles.size():
		same = same and a.obstacles[i].pos.is_equal_approx(b.obstacles[i].pos)
		differs = differs or not a.obstacles[i].pos.is_equal_approx(d.obstacles[i].pos)
	_check(same, "a seed gives the same cones")
	_check(differs, "another seed puts some cones on the other side")

	# ---- countdown and false start
	var r := _race("normal", 1)
	_check(r.phase == "count" and r.countdown_text() == "3", "the race starts with a 3 2 1 countdown (%s)" % r.countdown_text())
	r.step(1.0, 0.0)
	_check(r.countdown_text() == "2" and r.speed == 0.0, "2 after a second, nobody moves")
	r.push(0)
	_check(r.false_started and absf(r.penalty - Race.FALSE_START) < 0.001 and r.speed == 0.0, "pushing before GO is a false start (+%.1f s)" % r.penalty)
	r.push(1)
	_check(absf(r.penalty - Race.FALSE_START) < 0.001, "only once")
	r.step(2.1, 0.0)
	_check(r.phase == "go" and r.clock >= 0.0, "GO")

	# ---- rhythm and stamina
	var rh := _race("normal", 1)
	rh.step(3.05, 0.0)
	rh.push(0)
	var v0: float = rh.speed
	_check(v0 > 15.0, "the first push is a full push (%.1f)" % v0)
	rh.step(0.4, 0.0)
	var before: float = rh.speed
	rh.push(1)
	var gain_good: float = rh.speed - before
	var rs := _race("normal", 1)
	rs.step(3.05, 0.0)
	rs.push(0)
	rs.step(0.4, 0.0)
	var before_s: float = rs.speed
	rs.push(0)
	var gain_same: float = rs.speed - before_s
	_check(gain_good > 3.0 * gain_same, "the same key twice is weak (%.1f against %.1f)" % [gain_same, gain_good])
	var rm := _race("normal", 1)
	rm.step(3.05, 0.0)
	rm.push(0)
	rm.step(0.1, 0.0)
	var before_m: float = rm.speed
	var stam_m: float = rm.stam
	rm.push(1)
	_check(rm.speed - before_m < 0.4 * gain_good and rm.stam < stam_m - 8.0, "mashing is weak and costs more stamina (%.1f for %.1f)" % [rm.speed - before_m, stam_m - rm.stam])
	var tired := _race("normal", 1)
	tired.step(3.05, 0.0)
	tired.stam = 0.0
	tired.push(0)
	_check(tired.speed < 0.45 * v0, "a tired chair pushes weakly (%.1f)" % tired.speed)
	var rest := _race("normal", 1)
	rest.step(3.05, 0.0)
	rest.stam = 20.0
	rest.step(2.0, 0.0)
	_check(rest.stam > 40.0, "coasting wins the stamina back (%.0f)" % rest.stam)

	# ---- crashes cost time
	var wall := _race("normal", 1)
	wall.step(3.05, 0.0)
	wall.heading = -PI * 0.5  # up into the cubicle wall
	wall.speed = 40.0
	var t_before: float = wall.total()
	wall.step(0.6, 0.0)
	_check(wall.crashes >= 1 and wall.penalty >= 1.0 and wall.speed < 15.0, "driving into the cubicle wall costs a second and the speed (%d, +%.1f)" % [wall.crashes, wall.penalty])
	_check(wall.total() > t_before + 1.0, "and it shows in the time")
	var hard := _race("hard", 1)
	hard.step(3.05, 0.0)
	hard.heading = -PI * 0.5
	hard.speed = 40.0
	hard.step(0.6, 0.0)
	_check(hard.penalty > wall.penalty, "hard costs more (%.1f against %.1f)" % [hard.penalty, wall.penalty])
	var cone := _race("normal", 1)
	cone.step(3.05, 0.0)
	var co: Dictionary = {}
	for o in cone.obstacles:
		if o.kind == "cone":
			co = o
			break
	cone.pos = co.pos + Vector2(-3, 0)
	cone.heading = 0.0
	cone.speed = 10.0
	cone.step(0.05, 0.0)
	_check(co.down and cone.cones == 1 and cone.penalty > 0.0 and cone.penalty < wall.penalty, "a cone goes down for half a crash (+%.1f)" % cone.penalty)

	# ---- the driver: a clean run, mashing, the tiers
	for tier in TIERS:
		var clean := _best_clean(tier, 1)
		var par3: float = Race.PAR3 * float(TIERS[tier].par)
		_check(clean < par3 * 0.97, "%s: a perfect run (%.1f s) is under the 3 star time (%.1f s)" % [tier, clean, par3])
	var good := _race("normal", 2)
	_run(good, "rhythm", 30.0, 80.0)
	var mash := _race("normal", 2)
	_run(mash, "mash")
	_check(good.phase == "done" and mash.phase == "done", "both runs finish")
	_check(good.stars() == 3 and good.crashes == 0, "rhythm: 3 stars, no crash (%.1f s)" % good.total())
	_check(mash.total() > good.total() * 1.8, "mashing is far slower (%.1f s against %.1f s)" % [mash.total(), good.total()])
	_check(mash.stars() == 1, "mashing still finishes: 1 star")
	var idle := _race("normal", 2)
	for i in 60 * 85:
		idle.step(1.0 / 60.0, 0.0)
	_check(idle.dnf and idle.stars() == 0 and idle.phase == "done", "a chair that never leaves the gate is a DNF after %d s" % int(Race.LIMIT))

	# ---- the stars
	var s := _race("normal", 1)
	s.finish_t = 20.0
	_check(s.stars() == 3, "20 s: 3 stars")
	s.finish_t = 28.0
	_check(s.stars() == 2, "28 s: 2 stars")
	s.finish_t = 40.0
	_check(s.stars() == 1, "40 s: 1 star")
	s.penalty = 4.0
	s.finish_t = 19.0
	_check(s.stars() == 2, "penalties count against the time (19 + 4 s: 2 stars)")
	var se := _race("easy", 1)
	se.finish_t = 25.0
	var sh := _race("hard", 1)
	sh.finish_t = 25.0
	_check(se.stars() == 3 and sh.stars() == 2, "easy is forgiving, hard is strict (25 s)")

	# ---- the rivals
	var finish := {}
	for tier in TIERS:
		var rv := _race(tier, 5)
		for i in 60 * 80:
			rv.step(1.0 / 60.0, 0.0)
			if rv.clock > 70.0:
				break
		rv.settle()
		var ts := []
		for x in rv.rivals:
			ts.append(float(x.done))
		ts.sort()
		finish[tier] = ts
		_check(float(ts[0]) > 16.0 and float(ts[-1]) < 34.0, "%s: the rivals finish in %.1f to %.1f s" % [tier, ts[0], ts[-1]])
	_check(float(finish.hard[0]) < float(finish.normal[0]) and float(finish.normal[0]) < float(finish.easy[0]), "tougher tiers have faster rivals (%.1f, %.1f, %.1f s)" % [finish.hard[0], finish.normal[0], finish.easy[0]])
	var win := _race("normal", 2)
	_run(win, "rhythm", 30.0, 80.0)
	_check(win.place() == 1 and win.standings()[0].n == "You", "a clean run beats the whole crew")
	_check(win.comment() != "" and win.standings().size() == 6, "somebody grumbles about it, six in the standings")
	var slow := _race("normal", 2)
	_run(slow, "mash")
	_check(slow.place() >= 5 and slow.comment().begins_with(slow.standings()[0].n.to_upper()), "mashing finishes behind most of them, and the winner boasts (%s)" % slow.comment())
	var gar := _race("normal", 11)
	var mayas := _race("normal", 11)
	for x in gar.rivals:
		if x.n == "Maya":
			_check(float(x.fade) > 0.0, "Maya is a sprinter: she fades")
		if x.n == "Vic":
			_check(x.stalls.size() == 1, "Vic spins out once for the crowd")
		if x.n == "Alan":
			_check(x.stalls.is_empty(), "Alan never crashes")
	var seen_stall := false
	for sd in range(1, 12):
		for x in _race("normal", sd).rivals:
			if x.n == "Garrison" and not x.stalls.is_empty():
				seen_stall = true
	_check(seen_stall, "Garrison makes mistakes on some seeds")
	var solo := _race("normal", 1, [])
	_check(solo.rivals.is_empty(), "a race with no rivals is a time trial")
	var some := _race("normal", 1, ["Dan", "Nobody"])
	_check(some.rivals.size() == 1, "unknown names do not race")
	_check(mayas.rivals.size() == 5, "five rivals when everybody comes")

	# ---- the outing around it
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var social := root.get_node("Social")
	var world := root.get_node("World")
	var shift := root.get_node("Shift")
	var game := root.get_node("Game")
	var cards := root.get_node("Cards")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_chair_%d_" % OS.get_process_id()
	game.title_mode = false
	o.enabled = true
	c.new_game("tech")
	diff.seed_run(4242)
	world.time_scale = 1.0
	_check(o.GAMES.has("chair") and o.GAMES.chair.label == "CHAIR RACE", "the outing list has the chair race")
	_check(not o.racers().is_empty() and o.racers().size() <= 5, "the rivals come from the cast (%s)" % ", ".join(o.racers()))
	o.party_set = false
	o.pick_game(false)
	var labels := []
	for opt in cards.options:
		labels.append(str(opt.label))
	_check(labels.has("CHAIR RACE"), "the team outing card offers it (%s)" % ", ".join(labels))
	var at: int = labels.find("CHAIR RACE")
	cards.pick(at)
	_check(o.is_open and o.game == "chair" and o.phase == "intro", "picking it on the card opens the race page")
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	_check(not o.is_open, "and ESC SKIP on the intro page leaves")
	diff.set_tier("normal")
	shift.energy = 50.0
	var before_rel: int = social.value("Alan")
	o.start("chair", false, {"party": ["Alan", "Garrison", "Dan"]})
	_check(o.is_open and o.phase == "intro" and o.game == "chair" and not o.room_mode(), "it opens as a page over wherever you are")
	_check(o.hint() == "ENTER = START  ESC = SKIP", "intro hint: %s" % o.hint())
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o.g.race.rivals.size() == 3, "ENTER starts: three rivals (the party)")
	_check(o.hint() == "GET READY  ESC = LEAVE", "countdown hint: %s" % o.hint())
	o.tick(3.1)
	_check(o.hint() == "ARROWS = STEER  Z X = PUSH  ESC = LEAVE", "race hint: %s" % o.hint())
	o.press(KEY_Z)
	o.tick(0.4)
	o.press(KEY_X)
	_check(o.g.race.pushes == 2 and o.g.race.speed > 20.0, "Z and X push the chair (%d pushes)" % o.g.race.pushes)
	o.press(KEY_A)
	_check(o.g.race.pushes == 2, "other keys do nothing")
	# drive it to the line with the bot, through Outings.tick
	var guard := 0
	while o.phase == "play" and guard < 60 * 100:
		_drive(o.g.race, "rhythm", 30.0, 80.0, 0.0)
		o.g.steer = o.g.race.get_meta("steer")  # (Outings reads the arrow keys: the test sets the steering instead)
		o.tick(1.0 / 60.0)
		guard += 1
	_check(o.phase == "result" and o.stars >= 2, "the race ends on the result page (%d stars, %.1f s)" % [o.stars, o.g.race.total()])
	_check(o.chair_best.has("normal") and absf(float(o.chair_best.normal) - o.g.race.total()) < 0.02, "the best time is saved (%.2f)" % float(o.chair_best.get("normal", 0.0)))
	_check(o.g.new_best and not o.lines.is_empty(), "NEW BEST is on the result page: %s" % str(o.lines))
	_check(o.best["chair"] == o.stars and o.count == 1, "stars and count are recorded like the other games")
	_check(social.value("Alan") > before_rel or not c.active, "a good night out makes friends in a campaign")
	var detail_ok: bool = int(o.g.place) >= 1 and int(o.g.place) <= 4
	_check(detail_ok, "place %d of %d" % [o.g.place, o.g.race.rivals.size() + 1])
	var saved: Dictionary = o.to_dict()
	_check(saved.chair.normal == o.chair_best.normal, "saved with the outings")
	o.press(KEY_ENTER)
	_check(not o.is_open and world.time_scale == 1.0 and not game.ui_open, "closing gives the office back")
	var old_best: float = o.chair_best.normal
	o.from_dict({"count": 3, "best": {}, "chair": {"hard": 21.5}})
	_check(is_equal_approx(float(o.chair_best.hard), 21.5) and not o.chair_best.has("normal"), "the best time loads")
	o.from_dict({"count": 3, "best": {}})
	_check(o.chair_best.is_empty(), "an older save has none")
	o.from_dict(saved)

	# a slower run does not replace the best time; mashing makes no records
	o.start("chair", false, {"party": ["Alan"]})
	o.press(KEY_ENTER)
	var rr: RefCounted = o.g.race
	rr.clock = 40.0
	rr.phase = "go"
	rr.pos = Race.at_s(Race.length() - 3.0).p
	rr.seg = 11
	rr.speed = 20.0
	rr.step(0.1, 0.0)
	rr.step(1.3, 0.0)
	o.tick(0.1)
	_check(o.phase == "result" and absf(float(o.chair_best.normal) - old_best) < 0.001, "a slower run keeps the best time (%.1f)" % float(o.chair_best.normal))
	_check(o.stars == 1, "40 s is 1 star")
	o.press(KEY_ENTER)

	# leaving early
	var before2: int = social.value("Dan")
	o.start("chair", false, {"party": ["Alan", "Dan"]})
	o.press(KEY_ENTER)
	o.tick(4.0)
	o.press(KEY_ESCAPE)
	_check(o.phase == "result" and o.stars == -1 and social.value("Dan") <= before2, "ESC leaves early: -1 opinion")
	o.press(KEY_ENTER)

	# owner campaign: it costs money
	c.new_game("owner")
	var cash: int = root.get_node("Owner").cash
	o.start("chair", false, {"party": ["Alan"]})
	_check(root.get_node("Owner").cash == cash - 120, "the owner pays $120")
	o.press(KEY_ESCAPE)
	_check(root.get_node("Owner").cash == cash, "leaving on the intro page refunds it")
	o.press(KEY_ENTER)
	c.new_game("tech")

	# Free Play: nothing is scored, and the toolbox can start it
	var tb := root.get_node("Toolbox")
	_check(tb.GAMES.has("chair") and tb.GAME_LABELS.chair == "CHAIR RACE", "the Free Play toolbox lists it")
	tb.game_i = tb.GAMES.find("chair")
	_check(tb.launch() and o.is_open and o.game == "chair", "the toolbox starts it")
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	_check(not o.is_open, "and it closes again")

	# the tiers feed the race
	for tier in ["easy", "normal", "hard"]:
		diff.set_tier(tier)
		var p: Dictionary = o._chair_params()
		_check(is_equal_approx(float(p.crash), float(TIERS[tier].crash)) and is_equal_approx(float(p.par), float(TIERS[tier].par)), "%s: Difficulty.TABLE gives crash %.1f, par x%.1f" % [tier, p.crash, p.par])
	diff.set_tier("normal")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
