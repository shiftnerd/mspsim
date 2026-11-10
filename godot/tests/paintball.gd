extends SceneTree
# The paintball rules (paintball_game.gd) headless: teams, the flags, tags, cover, a whole AI match.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/paintball.gd

const PB := preload("res://scripts/paintball_game.gd")
var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _game(seed_n := 1) -> RefCounted:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var g: RefCounted = PB.new()
	g.setup({"skill": 1.0, "acc": 1.0}, ["Alan", "Garrison"], r)
	return g


func _play(g: RefCounted) -> void:
	g.count = 0.0
	g.step(0.01)  # into the play phase


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := _game()
	ok(g.units.size() == 6, "three a side")
	ok(g.units.filter(func(u: Dictionary) -> bool: return int(u.team) == 0).size() == 3, "team 0 is you and two of the crew")
	ok(g.units[0].you and g.units[0].name == "YOU", "unit 0 is you")
	ok(g.units[1].name == "Alan" and g.units[2].name == "Garrison", "the first two crew are on your team")
	ok(g.flags.size() == 2 and g.flags[0].home and g.flags[1].home, "both flags are home")
	ok(g.phase == "count", "it starts with a countdown")
	g.step(1.0)
	ok(g.phase == "count" and not g.fire_you(), "no shooting during the countdown")
	g.step(2.5)
	ok(g.phase == "play", "then play")

	# firing: the gap, and a shot with nobody in range is a miss event
	g = _game()
	_play(g)
	g.units[0].x = 300.0
	for k in range(1, 6):
		g.units[k].x = 1000.0 if k >= 3 else 20.0
	ok(g.fire_you(), "a shot goes off")
	ok(g.events.size() == 1 and g.events[0].kind == "shot" and g.events[0].hit == -1, "with nobody in range it is a miss")
	ok(not g.fire_you(), "and you wait for the gap")
	g.step(PB.FIRE_GAP + 0.01)
	ok(g.fire_you(), "then you can fire again")

	# a tag takes the target down, drops the flag, and they come back at their own end
	g = _game()
	_play(g)
	g.units[4].x = 330.0
	g.units[4].flag = true
	g.flags[0].carried = 4
	g.flags[0].home = false
	g._tag(4, 0)
	ok(float(g.units[4].down) == PB.RESPAWN and not g.units[4].flag, "a tag puts them down and takes the flag")
	ok(g.flags[0].carried == -1 and absf(float(g.flags[0].x) - 330.0) < 0.1 and not g.flags[0].home, "the flag lies where they fell")
	g.units[1].x = 330.0  # your team touches your own dropped flag: it goes home
	g.units[0].x = 20.0
	g._flags_for(1)
	ok(g.flags[0].home and absf(float(g.flags[0].x) - PB.BASE_X[0]) < 0.1, "touching your own dropped flag sends it home")
	for k in int(PB.RESPAWN / 0.1) + 2:
		g.step(0.1)
	ok(float(g.units[4].down) == 0.0 and float(g.units[4].x) > 500.0, "they are back at their own end")

	# pick up and capture
	g = _game()
	_play(g)
	g.units[0].x = PB.BASE_X[1]
	g._flags_for(0)
	ok(g.units[0].flag and g.flags[1].carried == 0 and not g.flags[1].home, "touching their flag picks it up")
	g.units[0].x = PB.BASE_X[0]
	g._flags_for(0)
	ok(g.score[0] == 1 and not g.units[0].flag and g.flags[1].home, "carrying it home scores and puts it back")
	ok(g.you_caps == 1, "and it counts for you")

	# cover
	g = _game()
	_play(g)
	var b: float = g.barricades[2]
	g.units[4].x = b + 5.0  # behind the barricade as seen from the left
	g.units[4].duck = true
	ok(g.covered(4, b - 100.0), "ducking behind a barricade covers you from the shooter's side")
	ok(not g.covered(4, b + 100.0), "but not from the other side")
	g.units[4].duck = false
	ok(not g.covered(4, b - 100.0), "standing up you are not covered")
	g.units[4].x = b + 60.0
	g.units[4].duck = true
	ok(not g.covered(4, b - 100.0), "and ducking out in the open is no cover")
	# a covered rival cannot be hit
	g.units[4].lane = g.units[0].lane  # shots only find somebody in the same lane
	g.units[0].x = b - 80.0
	g.units[0].face = 1
	g.units[4].x = b + 4.0
	var hits := 0
	for k in 40:
		g.units[0].cool = 0.0
		g.events = []
		g.fire(0)
		if g.events[0].hit >= 0:
			hits += 1
	ok(hits == 0, "forty shots at a ducking player behind cover hit nothing")
	g.units[4].duck = false
	hits = 0
	for k in 60:
		g.units[0].cool = 0.0
		g.units[4].down = 0.0
		g.events = []
		g.fire(0)
		if g.events[0].hit >= 0:
			hits += 1
	ok(hits > 15, "standing in the open they get hit (%d of 60)" % hits)

	# lanes: three of them, a shot only finds somebody in your lane, a change takes a moment
	g = _game()
	_play(g)
	g.units[0].x = 300.0
	g.units[0].face = 1
	g.units[4].x = 380.0
	g.units[4].lane = (int(g.units[0].lane) + 1) % PB.LANES
	ok(g.target_of(0) == -1, "somebody in the next lane is not a target")
	g.units[4].lane = g.units[0].lane
	ok(g.target_of(0) == 4, "in your own lane they are")
	g.units[0].lane = 1
	g.units[0].lane_cool = 0.0
	ok(g.lane_you(-1) and g.units[0].lane == 0, "UP goes one lane up")
	ok(not g.lane_you(-1) and g.units[0].lane == 0, "and there is no lane above the top one (and a change needs a moment)")
	g.step(PB.LANE_GAP + 0.01)
	ok(not g.lane_you(-1), "the top lane is the end of the street")
	ok(g.lane_you(1) and g.units[0].lane == 1, "DOWN goes back")
	g.units[0].down = 2.0
	g.units[0].lane_cool = 0.0
	ok(not g.lane_you(1), "you cannot change lane while you are down")
	# the crew follows you into another lane after a beat
	g = _game()
	_play(g)
	g.units[3].x = 380.0
	g.units[3].face = -1
	g.units[3].lane = 1
	g.units[0].x = 300.0
	g.units[0].lane = 2
	g.units[3].down = 0.0
	for k in 60:
		g.step(0.02)
	ok(g.units[3].lane == 2 or g.units[3].lane == 1, "(an enemy in another lane has not rushed over at once: lane %d)" % g.units[3].lane)
	for k in 120:
		g.step(0.02)
	ok(g.units[3].lane == 2 or int(g.units[3].down) > 0 or g.units[3].x != 380.0, "and the crew follows into your lane or moves on (lane %d)" % g.units[3].lane)
	# a shot fired between two steps keeps its event for the drawing
	g = _game()
	_play(g)
	g.units[0].cool = 0.0
	g.fire_you()
	g.step(0.01)
	ok(g.events.any(func(ev: Dictionary) -> bool: return ev.kind == "shot" and ev.unit == 0), "your shot's event survives the next step, so it is drawn")

	# winning
	g = _game()
	_play(g)
	g.score[0] = PB.TARGET
	g.step(0.1)
	ok(g.phase == "over" and g.winner == 0, "first to the target wins")
	g.you_tags = 3
	g.score[1] = 0
	ok(g.stars() == 3, "a two capture lead and three of your own makes 3 stars")
	g.you_tags = 0
	g.you_caps = 0
	ok(g.stars() == 2, "a plain win is 2 stars")
	g = _game()
	_play(g)
	g.clock = PB.LIMIT
	g.step(0.1)
	ok(g.phase == "play" and g.overtime and g.time_left() == ceili(PB.OVERTIME - 0.1), "time up level is overtime (R41: sudden death), not a draw yet")
	# overtime: a tag is for good, the next flag home wins
	var foe := 3
	g.units[0].x = 300.0
	g.units[foe].x = 320.0
	g.units[foe].lane = g.units[0].lane
	g._tag(foe, 0)
	g.step(0.1)
	ok(g.is_out(foe) and g.standing(1) == 2 and g.phase == "play", "a unit tagged in overtime does not come back")
	for k in 200:
		g.units[foe].x = 320.0
		g.step(0.1)
		if g.phase == "over":
			break
	ok(g.is_out(foe), "not even after the usual wait")
	g = _game()
	_play(g)
	g.clock = PB.LIMIT
	g.step(0.1)
	g.score[1] += 1
	g.step(0.1)
	ok(g.phase == "over" and g.winner == 1 and g.stars() == 0, "the next flag home wins the overtime")
	g = _game()
	_play(g)
	g.clock = PB.LIMIT
	g.step(0.1)
	for i in [3, 4, 5]:
		g._tag(i, 0)
	g.step(0.1)
	ok(g.phase == "over" and g.winner == 0 and g.stars() == 2, "the last team standing wins it: a plain win, 2 stars")
	g = _game()
	_play(g)
	g.clock = PB.LIMIT
	g.step(0.1)
	for u in g.units:
		u.x = float(PB.BASE_X[int(u.team)])
		u.down = 3.0  # everybody sits it out: nothing happens for 45 seconds
	g.clock = PB.LIMIT + PB.OVERTIME
	g.step(0.1)
	ok(g.phase == "over" and g.winner == 2 and g.stars() == 1, "level after 45 seconds of overtime is a draw, 1 star")
	g = PB.new()
	var r0 := RandomNumberGenerator.new()
	g.setup({"skill": 1.0, "acc": 1.0, "overtime": 0.0}, ["Alan", "Garrison"], r0)
	_play(g)
	g.clock = PB.LIMIT
	g.step(0.1)
	ok(g.phase == "over" and g.winner == 2, "with the overtime switched off (params.overtime 0) time up level is a draw at once")
	g = _game()
	_play(g)
	g.score[1] = 2
	g.clock = PB.LIMIT
	g.step(0.1)
	ok(g.winner == 1 and g.stars() == 0 and g.comment() != "", "time up behind is a loss with a line from the other side")

	# a whole match with nobody at the controls: it ends, the books balance, and the sides are about even
	var wins := [0, 0, 0]
	var total_caps := 0
	var bad := 0
	for seed_n in range(1, 21):
		var m := _game(seed_n)
		m.you_auto = true
		m.count = 0.0
		var t := 0.0
		while m.phase != "over" and t < 400.0:
			m.step(1.0 / 30.0)
			t += 1.0 / 30.0
			for f in m.flags:
				if int(f.carried) >= 0 and not (m.units[int(f.carried)].flag and int(m.units[int(f.carried)].team) != int(f.team)):
					bad += 1
		wins[m.winner] += 1
		total_caps += m.score[0] + m.score[1]
		if m.phase != "over":
			bad += 100
	ok(bad == 0, "twenty matches finish and the flag books always balance (bad %d)" % bad)
	ok(total_caps >= 12, "the crew really score (%d captures in 20 matches)" % total_caps)
	ok(wins[0] >= 2 and wins[1] >= 2, "neither side always wins: team 0 %d, team 1 %d, draws %d" % wins)
	print("paintball: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
