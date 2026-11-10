extends SceneTree
# gdlint:disable=max-line-length
# Co-op paintball (roadmap R41): with a second player joined, player 2 pilots the first team mate (unit 1, "P2") with their own
# pad: the stick runs, UP / DOWN change lane, A or X fires, B ducks; the crew member whose place they took sits out; their tags
# and captures count for the team, for the stars and for the Career's flags; alone, nothing changes. The night match: a shorter
# range for everybody, the pick on the card, the field drawn dark with lit windows and muzzle flashes (drawn in code).
# (A second pad's events never reach an autoload's _input in a headless run, so the handlers are called directly.)
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_paintball.gd

const PB := preload("res://scripts/paintball_game.gd")
const BotPaint := preload("res://tests/bot_paint.gd")
const CREW := ["Alan", "Garrison", "Dan", "Maya", "John"]

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _game(humans: int, seed_n := 1, p := {"skill": 1.0, "acc": 1.0}) -> RefCounted:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var g: RefCounted = PB.new()
	g.setup(p, CREW, r, humans)
	return g


func _pad(button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = 1
	ev.button_index = button
	ev.pressed = true
	return ev


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# ---- the rules with two pilots
	var solo := _game(1)
	ok(solo.pilots == 1 and solo.units[1].name == "Alan" and not solo.units[1].human and not solo.human(1), "alone: unit 1 is Alan, played by the crew")
	var g := _game(2)
	ok(g.pilots == 2 and g.units.size() == 6 and g.units[1].name == "P2" and g.units[1].human and int(g.units[1].team) == 0, "two pilots: unit 1 is player 2, on your team")
	ok(g.units[2].name == "Alan" and g.units[3].name == "Garrison" and g.units[5].name == "Maya", "the crew moves down one place")
	ok(not g.units.any(func(u: Dictionary) -> bool: return u.name == "John"), "and the fifth sits this one out")
	ok(g.human(0) and g.human(1) and not g.human(2), "two units are held by people")
	g.count = 0.0
	g.step(0.01)
	# player 2 runs, and the crew's AI leaves the unit alone
	var x0: float = g.units[1].x
	g.set_move_of(1, 1)
	for k in 30:
		g.step(1.0 / 30.0)
	ok(float(g.units[1].x) > x0 + 30.0 and int(g.units[1].face) == 1, "player 2's stick runs their unit (%.0f px in a second)" % (float(g.units[1].x) - x0))
	ok(g.move_dir == 0 and absf(float(g.units[0].vx)) < 0.01, "and not yours")
	g.set_move_of(1, 0)
	var x1: float = g.units[1].x
	for k in 30:
		g.step(1.0 / 30.0)
	ok(absf(float(g.units[1].x) - x1) < 0.01, "with the stick at rest it stands still (the AI does not take over)")
	g.set_duck_of(1, true)
	ok(g.units[1].duck and not g.units[0].duck, "B ducks player 2 only")
	ok(not g.fire(1), "and a ducking pilot cannot fire")
	g.set_duck_of(1, false)
	g.units[1].lane = 1
	g.units[1].lane_cool = 0.0
	ok(g.change_lane(1, -1) and int(g.units[1].lane) == 0, "UP changes player 2's lane")
	# player 2 shoots like a person (the short reload, your aim), and it counts
	g.units[1].x = 300.0
	g.units[1].face = 1
	g.units[4].x = 340.0
	g.units[4].lane = g.units[1].lane
	g.units[4].down = 0.0
	for k in [3, 5]:
		g.units[k].x = 620.0
		g.units[k].lane = (int(g.units[1].lane) + 1) % 3
	g.units[1].cool = 0.0
	ok(g.fire(1) and is_equal_approx(float(g.units[1].cool), PB.FIRE_GAP), "player 2 reloads as fast as you do")
	var hits := 0
	for k in 40:
		g.units[1].cool = 0.0
		g.units[4].down = 0.0
		g.units[4].x = 340.0
		g.events = []
		g.fire(1)
		if g.events[0].hit >= 0:
			hits += 1
	ok(hits >= 20, "and aims as well (%d hits of 40 at 40 px)" % hits)
	ok(g.p2_tags >= 20 and g.you_tags == 0, "the tags are player 2's (%d), not yours" % g.p2_tags)
	g.units[1].x = PB.BASE_X[1]
	g.units[4].down = 3.0
	g._flags_for(1)
	ok(g.units[1].flag, "player 2 picks up the flag")
	g.units[1].x = PB.BASE_X[0]
	g._flags_for(1)
	ok(g.score[0] == 1 and g.p2_caps == 1 and g.you_caps == 0, "and carries it home: a point for the team, a capture for player 2")
	g.score[0] = 3
	g.step(0.01)
	ok(g.phase == "over" and g.winner == 0 and g.stars() == 3, "a clear win where player 2 did the work is 3 stars for both")
	# two bots play whole matches: every one ends, both pilots take part
	var done := 0
	var p2_part := 0
	for s in range(1, 9):
		var m := _game(2, s * 13)
		m.count = 0.0
		var bots := [BotPaint.new(s), BotPaint.new(s + 100)]
		var steps := 0
		while m.phase != "over" and steps < 30 * 400:
			bots[0].drive(m, 0, 1.0 / 30.0)
			bots[1].drive(m, 1, 1.0 / 30.0)
			m.step(1.0 / 30.0)
			steps += 1
		if m.phase == "over":
			done += 1
		if m.p2_tags + m.p2_caps > 0:
			p2_part += 1
	ok(done == 8 and p2_part == 8, "eight matches with two scripted pilots all end, and player 2 tags or scores in every one (%d, %d)" % [done, p2_part])

	# ---- night: the same match with a shorter range
	var day := _game(1)
	var night := _game(1, 1, {"skill": 1.0, "acc": 1.0, "night": true})
	ok(not day.night and is_equal_approx(day.reach, PB.RANGE), "by day a paintball flies %.0f px" % day.reach)
	ok(night.night and night.reach < day.reach and night.reach > 100.0, "at night %.0f px, for both sides" % night.reach)
	night.count = 0.0
	night.step(0.01)
	night.units[0].x = 300.0
	night.units[0].face = 1
	night.units[4].lane = night.units[0].lane
	night.units[4].x = 300.0 + night.reach + 10.0
	for k in [3, 5]:
		night.units[k].x = 20.0
	ok(night.target_of(0) == -1, "somebody past that is out of sight")
	night.units[4].x = 300.0 + night.reach - 10.0
	ok(night.target_of(0) == 4, "inside it they are a target")

	# ---- the outing: Outings with a second player joined
	var pid := OS.get_process_id()
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_%d_cooppaint_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_cooppaint_settings.cfg" % pid
	var career := root.get_node("Career")
	career.reset_all()
	career.toasts = false
	var players := root.get_node("Players")
	var o := root.get_node("Outings")
	var controls := root.get_node("Controls")
	o.enabled = true
	o.use_rooms = false
	o.start("paintball", false, {"party": CREW, "night": false})
	o.press(KEY_ENTER)
	ok(o.g.rules.pilots == 1 and o.g.rules.units[1].name == "Alan", "alone the outing is as it was: Alan is your team mate")
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	players.enable_coop(true)
	players.join(1, 1)
	o.start("paintball", false, {"party": CREW, "night": false})
	o.press(KEY_ENTER)
	var rules: RefCounted = o.g.rules
	ok(rules.pilots == 2 and rules.units[1].human and rules.units[1].name == "P2", "with player 2 joined the match has two pilots")
	o.tick(3.2)
	ok(rules.phase == "play", "the match is on")
	# the pad: A fires, D-pad changes lane (the game's key code for player 2's buttons)
	o.game = "paintball"
	o.phase = "play"
	o._press_slot = 1
	ok(o._event_key_p2(_pad(JOY_BUTTON_A)) == KEY_Z and o._event_key_p2(_pad(JOY_BUTTON_X)) == KEY_Z, "player 2's A and X fire")
	ok(o._event_key_p2(_pad(JOY_BUTTON_DPAD_UP)) == KEY_UP and o._event_key_p2(_pad(JOY_BUTTON_DPAD_DOWN)) == KEY_DOWN, "the D-pad is the lane keys")
	rules.units[1].lane = 1
	rules.units[1].lane_cool = 0.0
	rules.units[0].lane = 1
	o._paint_press(KEY_UP)
	ok(int(rules.units[1].lane) == 0 and int(rules.units[0].lane) == 1, "player 2's UP moves player 2")
	o._press_slot = 0
	rules.units[0].lane_cool = 0.0
	o._paint_press(KEY_DOWN)
	ok(int(rules.units[0].lane) == 2 and int(rules.units[1].lane) == 0, "yours moves you")
	rules.units[0].cool = 0.0
	rules.units[1].cool = 0.0
	o._press_slot = 1
	o._paint_press(KEY_Z)
	ok(float(rules.units[1].cool) > 0.0 and float(rules.units[0].cool) == 0.0, "player 2's fire button fires player 2's marker")
	o._press_slot = 0
	o._paint_press(KEY_Z)
	ok(float(rules.units[0].cool) > 0.0, "and yours fires yours")
	# the stick and the duck button are read every tick from player 2's own actions
	var x_before: float = rules.units[1].x
	Input.action_press(controls.action_for(1, "move_right"))
	for k in 30:
		o.tick(1.0 / 30.0)
	Input.action_release(controls.action_for(1, "move_right"))
	ok(float(rules.units[1].x) > x_before + 25.0 or float(rules.units[1].down) > 0.0, "holding player 2's stick right runs their unit (%.0f px)" % (float(rules.units[1].x) - x_before))
	Input.action_press(controls.action_for(1, "run"))
	o.tick(1.0 / 30.0)
	ok(rules.units[1].duck or float(rules.units[1].down) > 0.0, "holding player 2's B ducks")
	Input.action_release(controls.action_for(1, "run"))
	o.tick(1.0 / 30.0)
	ok(not rules.units[1].duck, "letting go stands up")
	# finish it: player 2 carried two flags home, you one
	rules.p2_caps = 2
	rules.you_caps = 1
	rules.p2_tags = 4
	rules.score[0] = 3
	o.tick(0.05)
	o.tick(1.6)
	ok(o.phase == "result" and o.stars == 3, "the match ends on the result page (%d stars)" % o.stars)
	ok(o.lines.any(func(l: String) -> bool: return l.begins_with("PLAYER 2 SCORED 2")), "with a line for player 2: %s" % str(o.lines.slice(0, 3)))
	ok(career.value("flag_caps") == 3 and career.value("stars.paintball") == 3, "the Career counts both pilots' flags (3)")
	o.press(KEY_ENTER)

	# ---- the pick on the card: day or night, seeded, and LEFT / RIGHT changes it
	o.start("paintball", false, {"party": CREW})
	var drawn: bool = o.paint_night
	o.press(KEY_RIGHT)
	ok(o.paint_night != drawn, "LEFT / RIGHT on the card switches between the day and the night match")
	o.press(KEY_LEFT)
	ok(o.paint_night == drawn, "and back")
	if not o.paint_night:
		o.press(KEY_RIGHT)
	o.press(KEY_ENTER)
	ok(o.g.rules.night and o.g.rules.reach < PB.RANGE, "the night match is set up with the shorter range")
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	var nights := 0
	for k in 60:
		o.count = k
		o.start("paintball", false, {"party": CREW})
		if o.paint_night:
			nights += 1
		o.press(KEY_ESCAPE)
		o.press(KEY_ENTER)
	ok(nights >= 8 and nights <= 36, "left alone, about one evening in three is a night match (%d of 60)" % nights)
	o.start("paintball", false, {"party": CREW, "night": true})
	ok(o.paint_night, "the toolbox can ask for the night")
	o.press(KEY_LEFT)
	ok(o.paint_night, "and then the card cannot change it")
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)

	# ---- in the room, at night, with two pilots: the dark field, player 2's puppet, both bodies hidden and back
	camp.new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	o.use_rooms = true
	o.start("paintball", false, {"night": true})
	await create_timer(2.5).timeout
	await _wait(10)
	ok(current_scene.name == "PaintballField" and o.is_open, "the two of you are at the field")
	o.press(KEY_ENTER)
	await _wait(5)
	var track: Node = o.g.track
	rules = o.g.rules
	ok(rules.pilots == 2 and track.puppets.size() == 6 and track.puppets[1].label == "P2", "six puppets, the second one is player 2's")
	ok(track.night() and current_scene.get_node("Actors").modulate != Color.WHITE and track._stars.size() > 40, "the night: everybody in the street is tinted and the stars are out")
	var actors := current_scene.get_node("Actors")
	ok(not actors.get_node("Player").visible and (actors.get_node_or_null("Player2") == null or not actors.get_node("Player2").visible), "both real bodies are hidden while the puppets play")
	rules.count = 0.0
	await _wait(5)
	rules.units[0].cool = 0.0
	rules.fire(0)
	await _wait(2)
	ok(track._flashes.size() >= 1, "a shot at night makes a muzzle flash")
	await _wait(30)
	ok(track._flashes.is_empty(), "that is gone in a blink")
	var bots := [BotPaint.new(5), BotPaint.new(6)]
	var guard := 0
	while rules.phase != "over" and guard < 30 * 400:
		bots[0].drive(rules, 0, 1.0 / 30.0)
		bots[1].drive(rules, 1, 1.0 / 30.0)
		rules.step(1.0 / 30.0)
		guard += 1
	await create_timer(2.5).timeout
	await _wait(10)
	ok(o.phase == "result", "two scripted pilots play the night match to the result page (phase %s, %d to %d)" % [o.phase, rules.score[0], rules.score[1]])
	o.press(KEY_ENTER)
	await create_timer(2.5).timeout
	await _wait(10)
	ok(not o.is_open and current_scene.name == "MainFloor", "and you are back at the office")
	ok(current_scene.get_node("Actors/Player").visible and current_scene.get_node("Actors").modulate == Color.WHITE, "visible, in daylight")
	players.enable_coop(false)
	career.reset_all()
	print("coop_paintball: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
