extends SceneTree
# gdlint:disable=max-line-length
# THE GAUNTLET (roadmap R12): the second chair race course and the chair medals. The course (shorter, a zone every 56 px, two
# props in every one, the empty lane always the one next to the last), a driver bot that finishes it clean on every tier and seed (so the
# stars are reachable and nothing is stuck), the rivals reach its line, the old course is untouched, the best time is kept per
# course, and the Career: CLEAN LAP, SPEED DEMON, TRACK RAT. Then the race in the warehouse on the new course.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/chair_course.gd

const Race := preload("res://scripts/chair_race.gd")
const CREW := ["Alan", "Garrison", "Dan", "Maya", "John"]
const TIERS := {
	"easy": {"crash": 0.7, "stamina": 0.9, "slick": 0.8, "par": 1.2, "skill": -0.08},
	"normal": {"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0, "skill": 0.0},
	"hard": {"crash": 1.5, "stamina": 1.1, "slick": 1.3, "par": 0.9, "skill": 0.08},
}

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _race(tier: String, seed_n: int, course := "gauntlet") -> RefCounted:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var p: Dictionary = TIERS[tier].duplicate()
	p["course"] = course
	var race: RefCounted = Race.new()
	race.setup(p, CREW, r)
	return race


# the lane with nothing in it at the next zone (the gauntlet always has exactly one)
func _free_lane(race: RefCounted) -> int:
	var first: Variant = null
	for o in race.obstacles:
		if float(o.x) - race.pos > -9.0 and (first == null or float(o.x) < float(first.x)):
			first = o
	if first == null:
		return race.lane_to
	var blocked := {}
	for o in race.obstacles:
		if absf(float(o.x) - float(first.x)) < 20.0:
			blocked[int(o.lane)] = true
	for l in Race.LANES:
		if not blocked.has(l):
			return l
	return race.lane_to


# a driver: steers for the gap, pushes in rhythm, rests when tired, and keeps the speed down so the next lane change is made in time
func _drive(race: RefCounted, top: float, dt: float) -> void:
	race.go_lane(_free_lane(race))
	var resting: bool = bool(race.get_meta("rest", false))
	if race.stam < 25.0:
		resting = true
	elif race.stam > 65.0:
		resting = false
	race.set_meta("rest", resting)
	if race.clock >= 0.0 and race.clock - float(race._last_push) >= 0.36 and not resting and float(race.speed) < top:
		race.push(1 - int(race._last_key) if int(race._last_key) >= 0 else 0)
	race.step(dt)


func _run_race(race: RefCounted, top := 62.0) -> void:
	var guard := 0
	while race.phase != "done" and guard < 60 * 120:
		_drive(race, top, 1.0 / 60.0)
		guard += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# ---- the course
	ok(Race.COURSE_ORDER == ["straight", "gauntlet"] and Race.COURSES.has("gauntlet"), "two courses: THE STRAIGHT and THE GAUNTLET")
	var g := _race("normal", 1)
	ok(g.course == "gauntlet" and g.length < Race.LEN - 100.0 and g.length > 500.0, "the gauntlet is shorter (%.0f px, the straight is %.0f)" % [g.length, Race.LEN])
	ok(g.checks.size() == 2 and g.check_names.size() == 2 and g.cp(1) < g.length, "it has two checkpoints")
	var shape_ok := true
	var moves := 0
	for s in range(1, 31):
		var c := _race("normal", s)
		var zones := {}
		for o in c.obstacles:
			var z := roundi((float(o.x) - Race.G_FIRST) / Race.G_GAP)
			if not zones.has(z):
				zones[z] = []
			zones[z].append(int(o.lane))
			if float(o.x) > c.length - 20.0 or float(o.x) < 60.0:
				shape_ok = false
		if zones.size() != Race.G_ZONES:
			shape_ok = false
		var last := -1
		for z in range(Race.G_ZONES):
			var lanes: Array = zones.get(z, [])
			if lanes.size() != 2 or lanes[0] == lanes[1]:
				shape_ok = false
				continue
			var free := 3 - int(lanes[0]) - int(lanes[1])
			if last >= 0 and absi(free - last) != 1:
				shape_ok = false
			if last >= 0:
				moves += absi(free - last)
			last = free
	ok(shape_ok, "30 seeds: eleven zones, two props in each, one empty lane, always the lane next to the last one, clear of the grid and the line")
	ok(moves == 30 * 10, "so you change lane at every zone (%d lane changes over 30 courses)" % moves)
	var a := _race("normal", 7, "straight")
	var b := Race.new()
	var r7 := RandomNumberGenerator.new()
	r7.seed = 7
	b.setup(TIERS.normal, CREW, r7)
	var same: bool = a.obstacles.size() == b.obstacles.size() and a.length == Race.LEN and a.checks.size() == 3
	for i in mini(a.obstacles.size(), b.obstacles.size()):
		same = same and a.obstacles[i].x == b.obstacles[i].x and a.obstacles[i].kind == b.obstacles[i].kind
	ok(same, "the straight is the old course, prop for prop (a race set up without a course is the straight)")
	var odd := Race.new()
	odd.setup({"course": "nonsense"}, CREW, RandomNumberGenerator.new())
	ok(odd.course == "straight", "an unknown course id is the straight")

	# ---- the bot: clean on every tier and seed, and the stars are there
	var clean := 0
	var runs := 0
	var done := 0
	var three := {"easy": 0, "normal": 0, "hard": 0}
	var worst := 0.0
	for tier in TIERS:
		for s in range(1, 13):
			var best := 999.0
			var any_done := false
			for top: float in [70.0, 58.0, 50.0]:
				var c := _race(tier, s)
				_run_race(c, top)
				any_done = any_done or (c.phase == "done" and not c.dnf)
				if c.phase == "done" and not c.dnf and c.crashes == 0 and c.cones == 0:
					best = minf(best, c.total())
					if c.stars() == 3:
						three[tier] += 1
						break
			runs += 1
			if any_done:
				done += 1
			if best < 999.0:
				clean += 1
				worst = maxf(worst, best)
	ok(done == runs, "the bot reaches the line on every tier and seed (%d of %d)" % [done, runs])
	ok(clean >= runs - 2, "and nearly always without touching a prop (%d of %d clean, slowest %.1f s)" % [clean, runs, worst])
	ok(three.easy >= 10 and three.normal >= 8 and three.hard >= 5, "3 stars are reachable: easy %d, normal %d, hard %d of 12 seeds" % [three.easy, three.normal, three.hard])
	var lazy := _race("normal", 3)
	var guard := 0
	while lazy.phase != "done" and guard < 60 * 120:
		if lazy.clock >= 0.0 and lazy.clock - float(lazy._last_push) >= 0.36 and lazy.stam > 30.0:
			lazy.push(1 - int(lazy._last_key) if int(lazy._last_key) >= 0 else 0)
		lazy.step(1.0 / 60.0)  # straight down the middle lane, through everything
		guard += 1
	ok(lazy.phase == "done" and lazy.crashes + lazy.cones >= 5 and lazy.stars() <= 2, "ploughing down one lane hits most zones (%d hits) and loses the third star" % (lazy.crashes + lazy.cones))
	# the rivals finish too, and somebody can beat a slow you
	var rv := _race("normal", 5)
	var proj: Array = rv.projected()
	ok(proj.all(func(r: Dictionary) -> bool: return float(r.done) > 8.0 and float(r.done) < 60.0), "every rival reaches the gauntlet's line (%.1f to %.1f s)" % [float(proj[0].done), float(proj[proj.size() - 1].done)])
	_run_race(rv, 62.0)
	ok(rv.place() >= 1 and rv.place() <= 6 and rv.cp_next == 2, "the standings work on it (the bot is P%d) and both checkpoints were passed" % rv.place())

	# ---- the outing and the Career
	var pid := OS.get_process_id()
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_%d_chaircourse_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_chaircourse_settings.cfg" % pid
	var career := root.get_node("Career")
	career.reset_all()
	career.toasts = false
	var o := root.get_node("Outings")
	o.enabled = true
	o.use_rooms = false
	o.chair_best = {}
	o.start("chair", false, {"party": CREW, "event": "gauntlet"})
	ok(o.g.race.course == "gauntlet", "opts.event picks the gauntlet")
	o.press(KEY_ENTER)
	guard = 0
	while o.phase == "play" and guard < 60 * 120:
		var race: RefCounted = o.g.race
		o.g.lane = _free_lane(race)
		if race.clock >= 0.0 and race.clock - float(race._last_push) >= 0.36 and race.stam > 30.0 and float(race.speed) < 58.0:
			race.push(1 - int(race._last_key) if int(race._last_key) >= 0 else 0)
		o.tick(1.0 / 60.0)
		guard += 1
	ok(o.phase == "result" and o.stars >= 1, "the bot finishes the gauntlet through the outing (%d stars, %.1f s)" % [o.stars, o.g.race.total()])
	var tier: String = root.get_node("Difficulty").tier
	ok(o.chair_best.has(tier + ":gauntlet") and not o.chair_best.has(tier), "its best time is kept apart from the straight's")
	ok(career.value("stars.chair") == o.stars and career.value("chair_courses") == 1, "the Career has the race and one course")
	var was_clean: bool = o.g.race.crashes + o.g.race.cones == 0
	ok(career.has_medal("clean_lap") == was_clean, "CLEAN LAP: a finished race with nothing hit (clean this time: %s)" % str(was_clean))
	o.press(KEY_ENTER)
	career.reset_all()
	career.note_outing("chair", 2, {"chair": {"course": "straight", "won": true, "clean": false}})
	ok(not career.has_medal("clean_lap") and not career.has_medal("track_rat") and career.value("chair_wins") == 1, "a win on the straight with a crash: no CLEAN LAP, one course")
	career.note_outing("chair", 0, {"chair": {"course": "gauntlet", "won": false, "clean": false}})
	ok(not career.has_medal("track_rat"), "a DNF on the gauntlet does not count as finishing it")
	career.note_outing("chair", 3, {"chair": {"course": "gauntlet", "won": true, "clean": true}})
	ok(career.has_medal("track_rat") and career.has_medal("clean_lap"), "TRACK RAT for finishing both, CLEAN LAP for the clean one")
	ok(not career.has_medal("speed_demon"), "SPEED DEMON needs three wins")
	career.note_outing("chair", 3, {"chair": {"course": "straight", "won": true, "clean": true}})
	ok(career.has_medal("speed_demon") and career.value("chair_courses") == 2, "the third win: SPEED DEMON (and still two courses)")
	for id in ["clean_lap", "speed_demon", "track_rat", "bumper_king", "pushy", "flag_runner"]:
		var m: Dictionary = career.medal(id)
		ok(not m.is_empty() and str(m.desc).length() <= 30, "medal %s is in the table and its line fits (%s)" % [id, str(m.get("desc", ""))])
	career.reset_all()
	career.note_outing("paintball", 2, {"caps": 2})
	career.note_outing("paintball", 0, {"caps": 2})
	ok(career.value("flag_caps") == 4 and not career.has_medal("flag_runner"), "four flags carried home: not yet")
	career.note_outing("paintball", 3, {"caps": 1})
	ok(career.has_medal("flag_runner"), "the fifth: FLAG RUNNER")
	career.reset_all()

	# ---- in the warehouse: the gauntlet on the floor
	camp.new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	o.use_rooms = true
	o.chair_event = "straight"
	o.start("chair", false, {"party": CREW})
	await create_timer(2.5).timeout
	await _wait(10)
	ok(current_scene.name == "Warehouse" and o.g.has("track") and o.g.race.course == "straight", "the card in the warehouse opens on the straight")
	var straight_props: int = o.g.track.props.size()
	o.press(KEY_RIGHT)
	await _wait(5)
	ok(o.g.race.course == "gauntlet" and o.g.has("track") and is_instance_valid(o.g.track), "RIGHT lays the gauntlet on the floor")
	var track: Node = o.g.track
	var solid: int = o.g.race.obstacles.filter(func(ob: Dictionary) -> bool: return ob.kind != "puddle").size()
	ok(track.props.size() == solid and track.puppets.size() == 6, "its props (%d, the straight had %d) and the six racers are in the room" % [track.props.size(), straight_props])
	ok(current_scene.get_node("Actors").get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("Racer_") and not n.is_queued_for_deletion()).size() == 6, "and the first course's puppets are gone")
	o.press(KEY_ENTER)
	await _wait(5)
	guard = 0
	while o.phase == "play" and guard < 60 * 120:
		var race: RefCounted = o.g.race
		race.go_lane(_free_lane(race))
		if race.clock >= 0.0 and race.clock - float(race._last_push) >= 0.36 and race.stam > 30.0 and float(race.speed) < 58.0:
			race.push(1 - int(race._last_key) if int(race._last_key) >= 0 else 0)
		race.step(1.0 / 60.0)
		guard += 1
		if race.phase == "done" and race.end_t > 1.3:
			break
	await create_timer(1.0).timeout
	await _wait(10)
	ok(o.phase == "result", "the race on the floor ends on the result page (phase %s)" % o.phase)
	o.press(KEY_ENTER)
	await create_timer(2.5).timeout
	await _wait(10)
	ok(not o.is_open and current_scene.name == "MainFloor" and current_scene.get_node("Actors/Player").visible, "and you are back at the office")
	o.chair_event = "straight"
	print("chair_course: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
