extends SceneTree
# gdlint:disable=max-line-length
# CHAIR RACE (R12 part b, side-scrolling in the warehouse since R18 phase 2): the rules (rhythm and stamina, lanes, crashes,
# countdown, false start), the course and its props, the rivals and their seeded skill per tier, a driver bot that proves a
# perfect run is reachable on every tier and that mashing is not, the stars, the outing around it (invitation card, Free
# Play, saving the best time, results, the toolbox, the hint line) and the race in the real warehouse (racers as puppets,
# the copied props, the hidden player the camera follows, the way back).
# Headless: the race runs through its public functions (ChairRace.step / push / change_lane), the outing through Outings.press / tick.

const Race := preload("res://scripts/chair_race.gd")
const CREW := ["Alan", "Garrison", "Dan", "Maya", "John"]
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


# a prop to put in front of the chair
func _prop(x: float, lane: int, kind: String) -> Dictionary:
	return {"x": x, "lane": lane, "kind": kind, "down": false, "hit": false}


# the lane the bot wants: the empty lane nearest to the one it is in, for the next group of props (null = keep going)
func _bot_lane(race: RefCounted) -> int:
	var first: Variant = null
	for o in race.obstacles:
		if float(o.x) - race.pos > -14.0 and (first == null or float(o.x) < float(first.x)):
			first = o
	if first == null or float(first.x) - race.pos > 60.0 + race.speed * 0.3:
		return race.lane_to
	var blocked := {}
	for o in race.obstacles:
		if absf(float(o.x) - float(first.x)) < 40.0:
			blocked[int(o.lane)] = true
	if not blocked.has(race.lane_to):
		return race.lane_to
	var best: int = race.lane_to
	var best_d := 9
	for l in Race.LANES:
		if not blocked.has(l) and absi(l - race.lane_to) < best_d:
			best_d = absi(l - race.lane_to)
			best = l
	return best


# a driver: takes the empty lane, pushes in rhythm (alternating Z / X every 0.36 s), rests when tired; "mash" hammers instead
func _drive(race: RefCounted, mode: String, rest_lo: float, rest_hi: float, dt: float, via_outings: Node = null) -> void:
	var lane := _bot_lane(race)
	if via_outings != null:
		via_outings.g.lane = lane  # (Outings steers from g.lane in a test, there is no keyboard)
	else:
		race.go_lane(lane)
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
	if race.clock >= 0.0 and race.clock - float(race._last_push) >= gap and not resting and float(race.speed) < 78.0:
		race.push(1 - int(race._last_key) if int(race._last_key) >= 0 else 0)
	if via_outings == null:
		race.step(dt)


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
			if race.crashes == 0 and race.cones == 0:
				best = minf(best, race.total())
	return best


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _settle(name: String) -> void:
	var n := 0
	while (_scene_name() != name or root.get_node("Game").busy) and n < 600:
		await process_frame
		n += 1
	for i in 5:
		await process_frame


func _init() -> void:
	await process_frame
	# ---- the course
	_check(Race.LEN > 850.0 and Race.LEN < 950.0, "the course is a long room (%.0f px, the old one was 903)" % Race.LEN)
	_check(Race.CHECK_FRAC.size() == 3 and Race.CHECK_NAMES.size() == 3, "three checkpoints at 25, 50 and 75%")
	_check(Race.ORIGIN_X + 11.0 < 198.0 and Race.world_x(Race.LEN) > 1096.0 and Race.world_x(Race.LEN) < 1107.0, "the grid is behind the START line (x 198) and the course ends on the FINISH line (x 1096 to 1107)")
	_check(Race.LANES == 3 and Race.LANE_Y[0] >= 110.0 and Race.LANE_Y[2] <= 127.0 and Race.lane_y(0.5) > Race.LANE_Y[0] and Race.lane_y(9.0) == Race.LANE_Y[2], "three lanes inside the floor band (y 110 to 127), lane_y blends and clamps")
	var kinds := {}
	for sd in range(1, 7):
		for o in _race("normal", sd).obstacles:
			kinds[o.kind] = true
	_check(kinds.size() == 6, "all six props turn up over a few seeds (%s)" % ", ".join(kinds.keys()))
	var a := _race("normal", 7)
	var b := _race("normal", 7)
	var d := _race("normal", 8)
	var same: bool = a.obstacles.size() == b.obstacles.size()
	var differs := false
	for i in mini(a.obstacles.size(), b.obstacles.size()):
		same = same and absf(float(a.obstacles[i].x) - float(b.obstacles[i].x)) < 0.001 and a.obstacles[i].kind == b.obstacles[i].kind
	for i in mini(a.obstacles.size(), d.obstacles.size()):
		differs = differs or absf(float(a.obstacles[i].x) - float(d.obstacles[i].x)) > 0.001
	_check(same, "a seed gives the same props")
	_check(differs, "another seed lays them differently")
	# never all three lanes blocked: scan the course for the lanes a chair could not pass at each x
	var worst := 0
	var empty_zone := true
	for sd in range(1, 21):
		var rc := _race("normal", sd)
		var x := 0.0
		while x < Race.LEN:
			var blocked := {}
			for o in rc.obstacles:
				if absf(float(o.x) - x) < Race.prop_width(str(o.kind)) * 0.5 + Race.REACH + 10.0:
					blocked[int(o.lane)] = true
			worst = maxi(worst, blocked.size())
			x += 2.0
		for z in Race.ZONES:
			var zx: float = Race.ZONE_FIRST + Race.ZONE_GAP * float(z)
			var used := {}
			for o in rc.obstacles:
				if absf(float(o.x) - zx) < 40.0:
					used[int(o.lane)] = true
			empty_zone = empty_zone and used.size() <= 2
	_check(worst <= 2, "never all three lanes blocked at one x (the most: %d, over 20 seeds)" % worst)
	_check(empty_zone, "every zone of props leaves a lane with nothing in it")

	# ---- countdown and false start
	var r := _race("normal", 1)
	_check(r.phase == "count" and r.countdown_text() == "3", "the race starts with a 3 2 1 countdown (%s)" % r.countdown_text())
	r.step(1.0)
	_check(r.countdown_text() == "2" and r.speed == 0.0, "2 after a second, nobody moves")
	r.push(0)
	_check(r.false_started and absf(r.penalty - Race.FALSE_START) < 0.001 and r.speed == 0.0, "pushing before GO is a false start (+%.1f s)" % r.penalty)
	r.push(1)
	_check(absf(r.penalty - Race.FALSE_START) < 0.001, "only once")
	r.step(2.1)
	_check(r.phase == "go" and r.clock >= 0.0, "GO")
	_check(r.events.has("go") and r.events.has("false"), "the sounds are queued: %s" % str(r.events))

	# ---- lanes
	var ln := _race("normal", 1)
	_check(ln.lane_to == 1 and ln.lane == 1.0, "you start in the middle lane")
	ln.step(3.05)
	ln.change_lane(-1)
	ln.step(0.05)
	_check(ln.lane < 1.0 and ln.lane > 0.0, "a lane change is smooth, not a jump (%.2f)" % ln.lane)
	ln.step(0.3)
	_check(ln.lane == 0.0 and ln.lane_to == 0, "UP takes you to the far lane in about a fifth of a second")
	ln.change_lane(-1)
	ln.step(0.5)
	_check(ln.lane == 0.0, "and you cannot leave the floor band")
	ln.change_lane(1)
	ln.change_lane(1)
	ln.change_lane(1)
	ln.step(1.0)
	_check(ln.lane == 2.0, "DOWN twice takes you to the near lane, no further")

	# ---- rhythm and stamina
	var rh := _race("normal", 1)
	rh.step(3.05)
	rh.push(0)
	var v0: float = rh.speed
	_check(v0 > 15.0, "the first push is a full push (%.1f)" % v0)
	rh.step(0.4)
	var before: float = rh.speed
	rh.push(1)
	var gain_good: float = rh.speed - before
	var rs := _race("normal", 1)
	rs.step(3.05)
	rs.push(0)
	rs.step(0.4)
	var before_s: float = rs.speed
	rs.push(0)
	var gain_same: float = rs.speed - before_s
	_check(gain_good > 3.0 * gain_same, "the same key twice is weak (%.1f against %.1f)" % [gain_same, gain_good])
	var rm := _race("normal", 1)
	rm.step(3.05)
	rm.push(0)
	rm.step(0.1)
	var before_m: float = rm.speed
	var stam_m: float = rm.stam
	rm.push(1)
	_check(rm.speed - before_m < 0.4 * gain_good and rm.stam < stam_m - 8.0, "mashing is weak and costs more stamina (%.1f for %.1f)" % [rm.speed - before_m, stam_m - rm.stam])
	var tired := _race("normal", 1)
	tired.step(3.05)
	tired.stam = 0.0
	tired.push(0)
	_check(tired.speed < 0.45 * v0, "a tired chair pushes weakly (%.1f)" % tired.speed)
	var rest := _race("normal", 1)
	rest.step(3.05)
	rest.stam = 20.0
	rest.step(2.0)
	_check(rest.stam > 40.0, "coasting wins the stamina back (%.0f)" % rest.stam)

	# ---- props cost time
	var wall := _race("normal", 1)
	wall.step(3.05)
	wall.obstacles = [_prop(100.0, 1, "can")]
	wall.pos = 80.0
	wall.speed = 40.0
	var t_before: float = wall.total()
	wall.step(0.4)
	_check(wall.crashes == 1 and wall.penalty >= 1.0 and wall.speed < 15.0 and wall.wobble > 0.0, "driving into a trash can costs a second and most of the speed, and the chair wobbles (%d, +%.1f)" % [wall.crashes, wall.penalty])
	_check(wall.total() > t_before + 1.0 and wall.events.has("crash"), "it shows in the time")
	wall.step(0.3)
	_check(wall.crashes == 1, "one prop, one crash")
	for kind in ["wet", "box", "pallet"]:
		var cr := _race("normal", 1)
		cr.step(3.05)
		cr.obstacles = [_prop(100.0, 1, kind)]
		cr.pos = 70.0
		cr.speed = 50.0
		cr.step(0.6)
		_check(cr.crashes == 1, "a %s is a crash" % kind)
	var aside := _race("normal", 1)
	aside.step(3.05)
	aside.obstacles = [_prop(100.0, 0, "can")]
	aside.pos = 80.0
	aside.speed = 40.0
	aside.step(1.0)
	_check(aside.crashes == 0 and aside.penalty == 0.0, "the same prop in another lane is nothing")
	var hard := _race("hard", 1)
	hard.step(3.05)
	hard.obstacles = [_prop(100.0, 1, "can")]
	hard.pos = 80.0
	hard.speed = 40.0
	hard.step(0.4)
	_check(hard.penalty > wall.penalty, "hard costs more (%.1f against %.1f)" % [hard.penalty, wall.penalty])
	var cone := _race("normal", 1)
	cone.step(3.05)
	cone.obstacles = [_prop(100.0, 1, "cone")]
	cone.pos = 85.0
	cone.speed = 20.0
	cone.step(0.2)
	_check(cone.obstacles[0].down and cone.cones == 1 and cone.crashes == 0 and cone.penalty > 0.0 and cone.penalty < wall.penalty, "a cone goes down for half a crash (+%.1f)" % cone.penalty)
	var oil := _race("normal", 1)
	oil.step(3.05)
	oil.obstacles = [_prop(100.0, 1, "puddle")]
	oil.pos = 100.0
	oil.speed = 40.0
	oil.step(0.1)
	var dry_run := _race("normal", 1)
	dry_run.step(3.05)
	dry_run.obstacles = []
	dry_run.pos = 100.0
	dry_run.speed = 40.0
	dry_run.step(0.1)
	_check(oil.slick and oil.speed < dry_run.speed * 0.9 and oil.crashes == 0, "oil is a speed dip, not a crash (%.1f against %.1f)" % [oil.speed, dry_run.speed])
	oil.change_lane(-1)
	oil.step(0.1)
	var in_oil: float = oil.lane
	var dry := _race("normal", 1)
	dry.step(3.05)
	dry.change_lane(-1)
	dry.step(0.1)
	_check(in_oil > dry.lane + 0.15, "and lane changes are sluggish in it (%.2f against %.2f after 0.1 s)" % [in_oil, dry.lane])
	var slicker := _race("hard", 1)
	slicker.step(3.05)
	slicker.obstacles = [_prop(100.0, 1, "puddle")]
	slicker.pos = 100.0
	slicker.speed = 40.0
	slicker.step(0.1)
	_check(slicker.speed < oil.speed, "a hard puddle is bigger and takes more speed")

	# ---- the driver: a clean run, mashing, the tiers
	var clean_times := {}
	for tier in TIERS:
		var clean := _best_clean(tier, 1)
		clean_times[tier] = clean
		var par3: float = Race.PAR3 * float(TIERS[tier].par)
		_check(clean > 12.0 and clean < 19.5, "%s: a clean run takes %.1f s" % [tier, clean])
		_check(clean < par3 * 0.97, "%s: and is under the 3 star time (%.1f s)" % [tier, par3])
	_check(clean_times.easy < clean_times.normal and clean_times.normal < clean_times.hard, "tougher tiers need a tighter run")
	var good := _race("normal", 2)
	_run(good, "rhythm", 30.0, 80.0)
	var mash := _race("normal", 2)
	_run(mash, "mash")
	_check(good.phase == "done" and mash.phase == "done", "both runs finish")
	_check(good.stars() == 3 and good.crashes == 0, "rhythm: 3 stars, no crash (%.1f s)" % good.total())
	_check(mash.total() > 40.0 and mash.total() > good.total() * 2.0, "mashing takes 40 s and more (%.1f s against %.1f s)" % [mash.total(), good.total()])
	_check(mash.stars() == 1, "mashing still finishes: 1 star")
	var idle := _race("normal", 2)
	for i in 60 * 85:
		idle.step(1.0 / 60.0)
	_check(idle.dnf and idle.stars() == 0 and idle.phase == "done", "a chair that never leaves the gate is a DNF after %d s" % int(Race.LIMIT))
	var driven := _race("normal", 3)
	_run(driven, "rhythm", 30.0, 80.0)
	_check(driven.cp_next == 3 and driven.pos >= Race.LEN and driven.finish_t > 0.0, "the bot passes all three checkpoints and the line")
	for i in 120:
		driven.step(1.0 / 60.0)
	_check(driven.pos <= Race.LEN + 70.0 and driven.pos > Race.LEN, "after the line the chair coasts a little and stops (%.0f)" % (driven.pos - Race.LEN))

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
		var ts := []
		for x in rv.projected():
			ts.append(float(x.done))
		ts.sort()
		finish[tier] = ts
		_check(float(ts[0]) > 19.5 and float(ts[-1]) < 27.0, "%s: the rivals finish in %.1f to %.1f s" % [tier, ts[0], ts[-1]])
	_check(float(finish.hard[0]) < float(finish.normal[0]) and float(finish.normal[0]) < float(finish.easy[0]), "tougher tiers have faster rivals (%.1f, %.1f, %.1f s)" % [finish.hard[0], finish.normal[0], finish.easy[0]])
	for tier in TIERS:
		_check(float(clean_times[tier]) + 1.0 < float(finish[tier][0]), "%s: a clean run (%.1f s) beats the fastest rival (%.1f s) by a second or more" % [tier, clean_times[tier], finish[tier][0]])
	var win := _race("normal", 2)
	_run(win, "rhythm", 30.0, 80.0)
	_check(win.place() == 1 and win.standings()[0].n == "You", "a clean run beats the whole crew")
	var seen := []
	for x in win.rivals:
		seen.append(float(x.s))
	win.standings()
	win.comment()
	var untouched := true
	for i in win.rivals.size():
		untouched = untouched and is_equal_approx(float(win.rivals[i].s), float(seen[i]))
	_check(untouched, "working out the standings does not move the racers you see")
	_check(win.comment() != "" and win.standings().size() == 6, "somebody grumbles about it, six in the standings")
	var slow := _race("normal", 2)
	_run(slow, "mash")
	_check(slow.place() >= 5 and slow.comment().begins_with(slow.standings()[0].n.to_upper()), "mashing finishes behind most of them, and the winner boasts (%s)" % slow.comment())
	var mayas := _race("normal", 11)
	for x in mayas.rivals:
		if x.n == "Maya":
			_check(float(x.fade) > 0.0, "Maya is a sprinter: she fades")
		if x.n == "John":
			_check(x.stalls.size() == 1 and int(x.stalls[0].o) < 0, "John spins out once for the crowd, at a checkpoint")
		if x.n == "Alan":
			_check(x.stalls.is_empty(), "Alan never crashes")
	var seen_stall := false
	for sd in range(1, 12):
		for x in _race("normal", sd).rivals:
			if x.n == "Garrison" and not x.stalls.is_empty():
				seen_stall = true
	_check(seen_stall, "Garrison makes mistakes on some seeds")
	var alan := _race("normal", 4, ["Alan"])
	var touched := 0
	for i in 60 * 40:
		alan.step(1.0 / 60.0)
		var ar: Dictionary = alan.rivals[0]
		for o in alan.obstacles:
			if o.kind != "puddle" and absf(float(ar.lane) - float(o.lane)) < 0.5 and absf(float(ar.s) - float(o.x)) < Race.prop_width(str(o.kind)) * 0.5:
				touched += 1
	_check(touched == 0, "Alan dodges every prop (%d frames inside one)" % touched)
	var grid := _race("normal", 1)
	var lanes_used := {}
	for x in grid.rivals:
		lanes_used[int(round(float(x.lane)))] = true
	_check(lanes_used.size() == 3 and float(grid.rivals[2].s) < 0.0 and float(grid.rivals[0].s) == 0.0, "the rivals line up on a grid over all three lanes, the back row behind the line")
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
	_check(o.ROOMS.chair == "warehouse" and o.SPOTS.chair.size() == 6, "it is played in the warehouse")
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
	o.use_rooms = false
	o.start("chair", false, {"party": ["Alan", "Garrison", "Dan"]})
	_check(o.is_open and o.phase == "intro" and o.game == "chair" and not o.room_mode(), "without rooms it opens as a page over wherever you are (numbers only)")
	_check(o.hint() == "ENTER = START  ESC = SKIP", "intro hint: %s" % o.hint())
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o.g.race.rivals.size() == 3, "ENTER starts: three rivals (the party)")
	_check(o.hint() == "GET READY  ESC = LEAVE", "countdown hint: %s" % o.hint())
	o.tick(3.1)
	_check(o.hint() == "ARROWS = LANE  Z X = PUSH  ESC = LEAVE", "race hint: %s" % o.hint())
	o.press(KEY_Z)
	o.tick(0.4)
	o.press(KEY_X)
	_check(o.g.race.pushes == 2 and o.g.race.speed > 20.0, "Z and X push the chair (%d pushes)" % o.g.race.pushes)
	o.press(KEY_A)
	_check(o.g.race.pushes == 2, "other keys do nothing")
	o.press(KEY_UP)
	_check(o.g.race.lane_to == 0, "UP moves to the far lane")
	o.press(KEY_DOWN)
	o.press(KEY_DOWN)
	_check(o.g.race.lane_to == 2, "DOWN twice to the near lane")
	o.g.lane = 1
	o.tick(0.01)
	_check(o.g.race.lane_to == 1, "the test override steers to a lane")
	# drive it to the line with the bot, through Outings.tick
	var guard := 0
	while o.phase == "play" and guard < 60 * 100:
		_drive(o.g.race, "rhythm", 30.0, 80.0, 0.0, o)
		o.tick(1.0 / 60.0)
		guard += 1
	_check(o.phase == "result" and o.stars >= 2, "the race ends on the result page (%d stars, %.1f s)" % [o.stars, o.g.race.total()])
	_check(o.chair_best.has("normal") and absf(float(o.chair_best.normal) - o.g.race.total()) < 0.02, "the best time is saved (%.2f)" % float(o.chair_best.get("normal", 0.0)))
	_check(o.g.new_best and not o.lines.is_empty(), "NEW BEST is on the result page: %s" % str(o.lines))
	_check(o.best["chair"] == o.stars and o.count == 1, "stars and count are recorded like the other games")
	_check(root.get_node("Career").value("stars.chair") == o.stars, "the career keeps the best chair race stars")
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
	rr.obstacles = []
	rr.pos = Race.LEN - 3.0
	rr.speed = 20.0
	rr.step(0.3)
	rr.step(1.3)
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

	# the tiers feed the race (a fresh career: the mastery ramp starts at 0)
	root.get_node("Career").reset_all()
	for tier in ["easy", "normal", "hard"]:
		diff.set_tier(tier)
		var p: Dictionary = o._chair_params()
		_check(is_equal_approx(float(p.crash), float(TIERS[tier].crash)) and is_equal_approx(float(p.par), float(TIERS[tier].par)), "%s: Difficulty.TABLE gives crash %.1f, par x%.1f" % [tier, p.crash, p.par])
	diff.set_tier("normal")

	# ---- in the warehouse
	c.new_game(c.FREE)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle("main_floor")
	o.use_rooms = true
	diff.set_tier("normal")
	o.start("chair", false, {"party": ["Alan", "Garrison", "Dan"]})
	var wait := 0
	while not o.is_open and wait < 800:
		await process_frame
		wait += 1
	await _settle("warehouse")
	var scene := current_scene
	var me := scene.get_node("Actors/Player")
	_check(_scene_name() == "warehouse" and o.is_open and o.room_mode() and o.phase == "intro", "the race opens in the warehouse")
	_check(scene.get_node_or_null("Spawns/from_outing") != null, "the warehouse has a from_outing spawn")
	var track: Node = o.g.get("track")
	_check(track != null and is_instance_valid(track) and track.get_parent() == scene, "the track is in the room")
	_check(track.puppets.size() == o.racers().size() + 1 and track.puppets.has("You") and track.puppets.has(str(o.racers()[0])), "one puppet on the grid for you and one for each rival (%d, racers %s)" % [track.puppets.size(), str(o.racers())])
	_check(not me.visible and game.ui_open, "the real player is hidden and frozen")
	var nobody := true
	for n in get_nodes_in_group("npcs"):
		nobody = nobody and not (n.get("cast_name") in ["Alan", "Garrison", "Dan"])
	_check(nobody, "the racers are not also standing around as people")
	var actors := scene.get_node("Actors")
	var pup: Node2D = track.puppets.You.node
	_check(pup.get_parent() == actors and actors.y_sort_enabled, "puppets are y-sorted among the room's actors")
	_check(pup.get_child_count() == 2 and pup.get_child(0) is Sprite2D and pup.get_child(1) is AnimatedSprite2D, "a puppet is the real chair with the seated character on it")
	_check(str(pup.get_child(1).animation).begins_with("sit_") and pup.get_child(1).sprite_frames != null, "in the sit pose of the character's own sprite")
	var ys_ok := true
	for k in track.puppets:
		var yy: float = track.puppets[k].node.position.y
		ys_ok = ys_ok and yy >= 110.0 and yy <= 127.0
	_check(ys_ok, "everybody is on the floor band")
	var parked := get_nodes_in_group("race_prop").size()
	var want_props := 0
	for ob in o.g.race.obstacles:
		if ob.kind != "puddle":
			want_props += 1
	_check(parked == 6 and track.props.size() == want_props, "the six parked props stay on the wall, copies stand on the lanes (%d)" % track.props.size())
	var props_ok := true
	for pr in track.props:
		var pp: Node2D = pr.node
		props_ok = props_ok and pp.position.y >= 111.0 and pp.position.y <= 128.0 and pp.get_parent() == actors
	_check(props_ok, "the props stand on the lanes, sorted with the actors")
	_check(o.hint() == "ENTER = START  ESC = SKIP  TAB = LOOK", "intro hint in the room: %s" % o.hint())
	await process_frame
	_check(absf(me.global_position.x - (-556.0 + Race.world_x(0.0))) < 80.0, "the camera target waits at the start line (%.0f)" % me.global_position.x)
	var dock: Node = scene.get_node("Fx/Door")
	_check(dock.goal == 0.0 and dock.open == 0.0 and world.door_open == 0.0, "the overhead door is shut while the grid is set up")
	o.press(KEY_ENTER)
	_check(o.phase == "play" and game.ui_open and not me.visible, "ENTER starts the countdown; the player stays frozen")
	_check(dock.goal == 1.0 and world.door_open == 1.0, "the start rolls the overhead door up (the roll_door fx goal)")
	for i in 200:  # the door takes 3 s of real frames
		await process_frame
		if dock.open >= 1.0:
			break
	_check(dock.open >= 1.0 and dock._door != null and dock._door.visible == false, "and it gets all the way up (open %.2f)" % dock.open)
	o.tick(3.1)
	_check(o.hint() == "ARROWS = LANE  Z X = PUSH  ESC = LEAVE", "the hint bar says what the keys do")
	_check(o._room_wants(KEY_Z) and o._room_wants(KEY_UP) and o._room_wants(KEY_ESCAPE) and not o._room_wants(KEY_E), "Z X and the arrows belong to the race, E does not")
	var x_before: float = me.global_position.x
	Input.action_press("move_right")
	for i in 5:
		await process_frame
	Input.action_release("move_right")
	_check(absf(me.global_position.x - x_before) < 2.0, "the move keys do not walk the player around")
	guard = 0
	var sample_x := []
	while o.phase == "play" and guard < 60 * 100:
		_drive(o.g.race, "rhythm", 30.0, 80.0, 0.0, o)
		o.tick(1.0 / 60.0)
		track._sync()
		if guard % 300 == 0:
			sample_x.append(me.global_position.x)
		guard += 1
	_check(sample_x.size() > 3 and sample_x[-1] > sample_x[0] + 400.0, "the camera target rolls down the room with your puppet (%.0f to %.0f)" % [sample_x[0], sample_x[-1]])
	_check(absf(pup.position.x - (-556.0 + Race.world_x(o.g.race.pos))) < 1.0, "the puppet is where the sim says")
	var downs := 0
	for pr in track.props:
		if pr.marked:
			downs += 1
	_check(o.phase == "result" and o.stars >= 2 and o.g.race.crashes == 0, "the bot wins the race in the warehouse (%d stars, %.1f s)" % [o.stars, o.g.race.total()])
	_check(dock.goal == 0.0 and world.door_open == 0.0, "the finish rolls the door down again")
	o.press(KEY_ENTER)
	await _settle("main_floor")
	_check(world.door_open == 0.0, "the door is closed for the day after the race")
	_check(not o.is_open and not game.ui_open and _scene_name() == "main_floor", "closing goes back to where the outing started")
	_check(not is_instance_valid(track) or track.is_queued_for_deletion(), "and the track is cleared")
	await process_frame

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
