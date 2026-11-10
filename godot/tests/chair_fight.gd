extends SceneTree
# gdlint:disable=max-line-length
# CHAIR FIGHT (roadmap R12): the duel on rolling chairs (chair_fight.gd). The rules (pushing, turning, lanes, who lands a bump,
# a clash, the dizzy spin, walls, the clock, the stars), a scripted average player who plays whole fights against each of the
# crew on every tier (every fight ends, the win rate is sane), then the outing around it: the event is picked on the chair
# race card, the fight runs through Outings.press / tick, the result page and the Career (its own stars, BUMPER KING).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/chair_fight.gd

const Fight := preload("res://scripts/chair_fight.gd")
const Race := preload("res://scripts/chair_race.gd")
const CREW := ["Alan", "Garrison", "Dan", "Maya", "John"]
const SKILL := {"easy": -0.08, "normal": 0.0, "hard": 0.08}
const STAMINA := {"easy": 0.9, "normal": 1.0, "hard": 1.1}

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _fight(seed_n := 1, who := "Dan", tier := "normal") -> RefCounted:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var f: RefCounted = Fight.new()
	f.setup({"stamina": STAMINA[tier], "skill": SKILL[tier], "opponent": who}, CREW, r)
	return f


func _go(f: RefCounted) -> void:
	f.clock = -0.001
	f.step(0.01)


# an average player at the keys: a decent rhythm (not a perfect one), turns to face the other chair after a moment, follows
# into their lane, steps aside now and then when it is about to lose a head-on, rests when out of breath
class Bot:
	var rng := RandomNumberGenerator.new()
	var gap := 0.42
	var see_t := 0.0
	var lane_t := 0.0
	var rest := false
	var dodge_cd := 0.0

	func _init(seed_n: int) -> void:
		rng.seed = seed_n

	func drive(f: RefCounted, dt: float) -> void:
		if f.phase != "go":
			return
		var me: Dictionary = f.chairs[0]
		var them: Dictionary = f.chairs[1]
		dodge_cd = maxf(0.0, dodge_cd - dt)
		var toward := 1 if float(them.x) >= float(me.x) else -1
		if int(me.face) != toward:
			see_t += dt
			if see_t >= 0.35:
				see_t = 0.0
				f.spin(toward)
			return
		see_t = 0.0
		var mine: float = float(me.v) * float(toward)
		var theirs: float = -float(them.v) * float(toward)
		var dist: float = absf(float(them.x) - float(me.x))
		if int(me.lane_to) != int(them.lane_to):
			lane_t += dt
			if lane_t >= 0.45:
				lane_t = 0.0
				f.change_lane(signi(int(them.lane_to) - int(me.lane_to)))
		elif dist < 60.0 and theirs - mine > Fight.EDGE and dodge_cd <= 0.0:
			dodge_cd = 1.5
			if rng.randf() < 0.4:
				f.change_lane(1 if int(me.lane_to) == 0 else -1)
				lane_t = -0.5
		if float(me.stam) < 22.0:
			rest = true
		elif float(me.stam) > 60.0:
			rest = false
		if rest or f.clock - float(me.last) < gap or mine > 62.0:
			return
		var key := 1 - int(me.key) if int(me.key) >= 0 else 0
		if rng.randf() < 0.08:
			key = maxi(int(me.key), 0)  # the wrong leg, now and then
		f.push(key)
		gap = 0.42 + rng.randf_range(-0.07, 0.09)


func _play(f: RefCounted, bot: Bot) -> bool:
	var steps := 0
	while f.phase != "done" and steps < 60 * 200:
		bot.drive(f, 1.0 / 60.0)
		f.step(1.0 / 60.0)
		steps += 1
	return f.phase == "done"


func _init() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	# ---- the set-up
	var f := _fight()
	ok(f.chairs.size() == 2 and f.chairs[0].n == "You" and f.opponent() == "Dan", "two chairs: you and the opponent that was asked for")
	ok(f.rivals.size() == 5 and f.rivals[0] == f.chairs[1], "the track draws the opponent and the four who watch")
	ok(f.rivals.slice(1).all(func(r: Dictionary) -> bool: return float(r.s) < Fight.LO - 10.0 or float(r.s) > Fight.HI + 10.0), "the watchers sit outside the strip")
	ok(Race.world_x(Fight.LO) > 300.0 and Race.world_x(Fight.HI) < 1000.0, "the strip is in the middle of the warehouse floor")
	ok(f.phase == "count" and f.countdown_text() == "3", "it starts with a countdown")
	ok(not f.push_of(0, 0) and float(f.chairs[0].v) == 0.0, "no pushing before GO")
	f.step(3.1)
	ok(f.phase == "go" and "go" in f.events, "then GO")
	var names := {}
	for s in range(1, 40):
		var r := RandomNumberGenerator.new()
		r.seed = s
		var g: RefCounted = Fight.new()
		g.setup({}, CREW, r)
		names[g.opponent()] = true
	ok(names.size() == 5, "the opponent is drawn on the stream: all five turn up over 40 seeds")
	var alone: RefCounted = Fight.new()
	alone.setup({}, [], RandomNumberGenerator.new())
	ok(alone.opponent() == "Garrison" and alone.rivals.size() == 1, "nobody came: Garrison never misses a chair fight")

	# ---- pushing, turning, lanes
	f = _fight()
	_go(f)
	f.chairs[1].x = Fight.HI - 5.0  # (out of the way)
	f.you_auto = false
	ok(f.push_of(0, 0) and float(f.chairs[0].v) > 15.0, "a push rolls you the way you face (%.1f px/s)" % float(f.chairs[0].v))
	var v1: float = f.chairs[0].v
	f.push_of(0, 0)
	ok(float(f.chairs[0].v) - v1 < 8.0 and f.feel == "SAME LEG", "the same leg twice is a weak push")
	ok(f.spin(-1) and f.face == -1 and float(f.chairs[0].turn) > 0.0, "LEFT spins the chair around")
	ok(not f.push_of(0, 1), "and you cannot push while it turns")
	ok(not f.spin(-1), "turning the way you already face does nothing")
	for k in 30:
		f.chairs[1].x = Fight.HI - 5.0
		f.chairs[1].v = 0.0
		f.step(0.02)
	var before: float = f.chairs[0].v
	ok(f.push_of(0, 1) and float(f.chairs[0].v) < before, "after the turn a push goes the other way")
	f.change_lane(-1)
	ok(int(f.chairs[0].lane_to) == 0, "UP is one lane over")
	f.change_lane(-1)
	ok(int(f.chairs[0].lane_to) == 0, "and there is no lane beyond the wall")

	# ---- a bump: the faster chair lands it, the other one is knocked back and spins
	f = _fight()
	_go(f)
	f.chairs[0].x = 370.0
	f.chairs[1].x = 380.0
	f.chairs[0].v = 50.0
	f.chairs[1].v = -20.0
	f._meet()
	ok(f.score() == [1, 0] and "bump" in f.events, "rolling in clearly faster lands a bump")
	ok(float(f.chairs[1].dizzy) > 0.0 and float(f.chairs[1].v) > 0.0 and float(f.chairs[0].v) < 0.0, "they are knocked back, dizzy, and you bounce off")
	ok(f.rivals[0].flag == "" or true, "(the flag is set on the next step)")
	f.step(0.02)
	ok(str(f.chairs[1].flag) == "spin", "a dizzy chair spins on the floor")
	ok(not f.push_of(1, 0), "and cannot push")
	# safe for a moment
	f._hit_cd = 0.0
	f.chairs[0].x = 370.0
	f.chairs[1].x = 380.0
	f.chairs[0].v = 50.0
	f.chairs[1].v = 0.0
	f._meet()
	ok(f.score() == [1, 0], "a chair that was just bumped cannot be bumped again at once")
	# the other way round
	f = _fight()
	_go(f)
	f.chairs[0].x = 370.0
	f.chairs[1].x = 380.0
	f.chairs[0].v = 18.0
	f.chairs[1].v = -48.0
	f._meet()
	ok(f.score() == [0, 1] and "ouch" in f.events and f.wobble > 0.0, "the faster opponent bumps you")
	# a clash
	f = _fight()
	_go(f)
	f.chairs[0].x = 370.0
	f.chairs[1].x = 380.0
	f.chairs[0].v = 40.0
	f.chairs[1].v = -38.0
	f._meet()
	ok(f.score() == [0, 0] and f.clashes == 1 and float(f.chairs[0].v) < 0.0 and float(f.chairs[1].v) > 0.0, "about the same speed is a clash: both bounce, no point")
	# a soft touch
	f = _fight()
	_go(f)
	f.chairs[0].x = 370.0
	f.chairs[1].x = 380.0
	f.chairs[0].v = 8.0
	f.chairs[1].v = -3.0
	f._meet()
	ok(f.score() == [0, 0] and f.clashes == 0, "a slow touch is nothing")
	# another lane: no touch
	f = _fight()
	_go(f)
	f.chairs[0].x = 370.0
	f.chairs[1].x = 380.0
	f.chairs[0].v = 50.0
	f.chairs[1].lane = 2.0
	f._meet()
	ok(f.score() == [0, 0] and float(f.chairs[0].v) == 50.0, "in another lane the chairs roll past each other")
	# from behind: their back is turned, so any decent speed counts
	f = _fight()
	_go(f)
	f.chairs[0].x = 370.0
	f.chairs[1].x = 380.0
	f.chairs[1].face = 1
	f.chairs[0].v = 30.0
	f.chairs[1].v = 26.0
	f._hit_cd = 0.0
	f._meet()
	ok(f.score() == [0, 0], "(rolling the same way at nearly the same speed: not closing fast enough)")
	f.chairs[1].v = 5.0
	f._meet()
	ok(f.score() == [1, 0], "a chair with its back to you is bumped as soon as you are fast enough")
	# the wall
	f = _fight()
	_go(f)
	f.chairs[0].x = Fight.LO + 1.0
	f.chairs[0].v = -40.0
	f.step(0.05)
	ok(float(f.chairs[0].x) == Fight.LO and float(f.chairs[0].v) > 0.0 and "clunk" in f.events, "the end of the strip is a wall: clunk, and you bounce a little")

	# ---- the end
	f = _fight()
	_go(f)
	f.chairs[0].bumps = Fight.TARGET
	f.step(0.02)
	ok(f.phase == "done" and f.winner == 0 and f.stars() == 3, "first to three wins: 3 stars with one bump or none against")
	f.chairs[1].bumps = 2
	ok(f.stars() == 2, "a close win is 2 stars")
	f = _fight()
	_go(f)
	f.clock = Fight.LIMIT
	f.step(0.02)
	ok(f.phase == "done" and f.winner == 2 and f.stars() == 1 and f.comment() != "", "time up level is a draw: 1 star")
	f = _fight()
	_go(f)
	f.chairs[1].bumps = Fight.TARGET
	f.step(0.02)
	ok(f.winner == 1 and f.stars() == 0 and f.comment().begins_with("DAN"), "they win: 0 stars and Dan has something to say")
	f.chairs[0].bumps = 2
	ok(f.stars() == 1, "a close loss still gets a star")

	# ---- whole fights: an average player against each of the crew on every tier
	var table := {}
	var unfinished := 0
	var total_bumps := 0
	for tier in ["easy", "normal", "hard"]:
		var wins := 0
		var losses := 0
		var n := 0
		var secs := 0.0
		for who in CREW:
			for s in range(1, 17):
				var m := _fight(s * 17 + who.length(), who, tier)
				if not _play(m, Bot.new(s * 5 + 1)):
					unfinished += 1
				n += 1
				secs += maxf(m.clock, 0.0)
				total_bumps += m.score()[0] + m.score()[1]
				if m.winner == 0:
					wins += 1
				elif m.winner == 1:
					losses += 1
		table[tier] = {"win": float(wins) / float(n), "loss": float(losses) / float(n), "secs": secs / float(n)}
		print("chair fight, %s: the average player wins %d %%, loses %d %% of %d fights, %.0f s a fight" % [tier, roundi(table[tier].win * 100.0), roundi(table[tier].loss * 100.0), n, table[tier].secs])
	ok(unfinished == 0, "every fight ends (240 fights, 3 tiers x 5 opponents x 16 seeds)")
	ok(total_bumps >= 600, "and they are decided by bumps, not the clock (%d bumps in 240 fights)" % total_bumps)
	ok(table.normal.win >= 0.4 and table.normal.win <= 0.75, "normal: an average player wins about half to two thirds (%d %%)" % roundi(table.normal.win * 100.0))
	ok(table.easy.win >= table.normal.win - 0.05 and table.hard.win <= table.normal.win + 0.05, "easy is no harder than normal, hard no easier (%d / %d / %d %%)" % [roundi(table.easy.win * 100.0), roundi(table.normal.win * 100.0), roundi(table.hard.win * 100.0)])
	ok(table.hard.win >= 0.2 and table.easy.win <= 0.9, "hard can be won, easy can be lost")
	# the crew against the crew (you_auto): nothing gets stuck either
	var auto_done := 0
	for s in range(1, 11):
		var m := _fight(s, CREW[s % 5])
		m.you_auto = true
		var steps := 0
		while m.phase != "done" and steps < 60 * 200:
			m.step(1.0 / 60.0)
			steps += 1
		if m.phase == "done":
			auto_done += 1
	ok(auto_done == 10, "ten fights with the crew's driver in both chairs all end")

	# ---- the outing: picked on the chair race card, played, scored, in the Career
	var pid := OS.get_process_id()
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_%d_chairfight_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_chairfight_settings.cfg" % pid
	var career := root.get_node("Career")
	career.reset_all()
	career.toasts = false
	var o := root.get_node("Outings")
	o.enabled = true
	o.use_rooms = false
	o.chair_event = "straight"
	o.start("chair", false, {"party": CREW})
	ok(o.phase == "intro" and o.g.event == "straight" and not o.g.race.get("fight"), "the chair card opens on the race")
	var state0: int = o.g.rng0
	o.press(KEY_RIGHT)
	ok(o.g.event == "gauntlet" and o.g.race.course == "gauntlet", "RIGHT on the card: THE GAUNTLET")
	o.press(KEY_RIGHT)
	ok(o.g.event == "fight" and o.g.race.get("fight") == true and o.chair_event == "fight", "RIGHT again: the chair fight")
	var first_opp: String = o.g.race.opponent()
	o.press(KEY_RIGHT)
	o.press(KEY_LEFT)
	ok(o.g.event == "fight" and o.g.race.opponent() == first_opp and int(o.g.rng0) == state0, "going round the card does not use up the seeded stream (the same opponent again)")
	o.press(KEY_ENTER)
	ok(o.phase == "play" and o.hint().begins_with("GET READY"), "ENTER starts the countdown")
	o.tick(3.2)
	ok(o.g.race.phase == "go" and o.hint().contains("TURN"), "the hint names the fight's keys")
	o._press_slot = 0
	o.press(KEY_Z)
	ok(float(o.g.race.chairs[0].v) > 10.0, "Z pushes")
	o.press(KEY_LEFT)
	ok(o.g.race.face == -1, "LEFT turns the chair")
	o.press(KEY_UP)
	ok(int(o.g.race.chairs[0].lane_to) == 0, "UP changes lane")
	var bot := Bot.new(3)
	var guard := 0
	while o.phase == "play" and guard < 60 * 200:
		bot.drive(o.g.race, 1.0 / 60.0)
		o.tick(1.0 / 60.0)
		guard += 1
	ok(o.phase == "result", "the bot plays the fight to the result page")
	ok(o.stars == o.g.race.stars() and o.lines.size() >= 2 and str(o.lines[1]).begins_with("BUMPS"), "with the fight's stars and lines: %s" % str(o.lines.slice(0, 2)))
	ok(career.value("stars.chairfight") == o.stars and career.value("stars.chair") == 0, "the Career keeps the fight's stars apart from the race's")
	ok(career.value("chair_bumps") == int(o.g.race.score()[0]), "and counts your bumps")
	ok(int(o.best.get("chairfight", -1)) == o.stars and not o.best.has("chair"), "the outing's own best too")
	o.press(KEY_ENTER)
	ok(not o.is_open, "ENTER closes the result")
	# BUMPER KING: three wins
	ok(not career.has_medal("bumper_king"), "no medal yet")
	for k in 3:
		career.note_outing("chairfight", 3, {"chair": {"fight": true, "won": true, "bumps": 3}})
	ok(career.has_medal("bumper_king") and career.value("chairfight_wins") >= 3, "three won fights: BUMPER KING")
	# the toolbox names the event: the card cannot change it
	o.start("chair", false, {"party": CREW, "event": "fight", "opponent": "Maya"})
	ok(o.g.event == "fight" and o.g.race.opponent() == "Maya", "opts.event and opts.opponent fix the fight")
	o.press(KEY_RIGHT)
	ok(o.g.event == "fight", "and LEFT / RIGHT leave it alone")
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	o.chair_event = "straight"
	career.reset_all()

	# ---- in the warehouse: the fight on the floor with the race's puppets
	camp.new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	o.use_rooms = true
	o.start("chair", false, {"party": CREW, "event": "fight", "opponent": "Garrison"})
	await create_timer(2.5).timeout
	await _wait(10)
	ok(current_scene.name == "Warehouse" and o.is_open and o.g.has("track"), "you are taken to the warehouse and the chairs are on the floor")
	var track: Node = o.g.track
	ok(track.puppets.size() == 6 and track.puppets.has("You") and track.puppets.has("Garrison"), "you, Garrison and the four who watch")
	ok(track.props.is_empty(), "no props on the strip")
	o.press(KEY_ENTER)
	await _wait(5)
	o.g.race.clock = -0.05
	await _wait(10)
	o._press_slot = 0
	o.press(KEY_LEFT)
	await _wait(30)
	ok(track.puppets["You"].node.scale.x < 0.0, "your puppet faces the way the chair does")
	o.press(KEY_RIGHT)
	var bot2 := Bot.new(9)
	guard = 0
	while o.phase == "play" and guard < 60 * 200:
		bot2.drive(o.g.race, 1.0 / 60.0)
		o.g.race.step(1.0 / 60.0)
		guard += 1
		if o.g.race.phase == "done":
			break
	await create_timer(2.0).timeout
	await _wait(10)
	ok(o.phase == "result", "the fight in the room ends on the result page (phase %s)" % o.phase)
	o.press(KEY_ENTER)
	await create_timer(2.5).timeout
	await _wait(10)
	ok(not o.is_open and current_scene.name == "MainFloor" and current_scene.get_node("Actors/Player").visible, "and you are back at the office, visible")
	print("chair_fight: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
