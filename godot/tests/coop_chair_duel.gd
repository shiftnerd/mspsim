extends SceneTree
# gdlint:disable=max-line-length
# R12 leftover: the co-op chair fight is a duel, player 1's chair against player 2's (the two races stay a tandem). The rules
# with `params.duel` (nobody drives chair 1, both pay the tier's stamina, the crew all watch, 1 star for playing), the keys of
# each player through Outings (the second pad is driven the way tests/coop_chair.gd does it: the handlers with `_press_slot`,
# and a joypad event of device 1 through `_event_key_p2`), bot duels that all end, and the duel on the real warehouse floor.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_chair_duel.gd

const Fight := preload("res://scripts/chair_fight.gd")
const CREW := ["Alan", "Garrison", "Dan", "Maya", "John"]

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _duel(seed_n := 1) -> RefCounted:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var f: RefCounted = Fight.new()
	f.setup({"stamina": 1.0, "skill": 0.0, "duel": true}, CREW, r)
	return f


func _go(f: RefCounted) -> void:
	f.clock = -0.001
	f.step(0.01)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


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
	var players := root.get_node("Players")
	var o := root.get_node("Outings")
	var camp := root.get_node("Campaign")
	var career := root.get_node("Career")
	camp.save_prefix = "user://test_%d_" % OS.get_process_id()
	career.reset_all()

	# ---- the rules
	var f := _duel()
	ok(f.duel and f.opponent() == "P2" and f.chairs[1].color == Fight.P2_COLOR, "a duel: the second chair is player 2's")
	ok(f.rivals.size() == 1 + CREW.size() and f.rivals.filter(func(r: Dictionary) -> bool: return bool(r.get("watch", false))).size() == CREW.size(), "the whole crew watches")
	_go(f)
	var x1: float = f.chairs[1].x
	for i in 180:
		f.step(1.0 / 60.0)
	ok(is_equal_approx(float(f.chairs[1].x), x1) and int(f.chairs[1].pushes) == 0, "nobody drives player 2's chair")
	ok(f.push_of(1, 0) and float(f.chairs[1].v) < 0.0 and float(f.chairs[0].v) == 0.0, "player 2's push rolls their own chair (to the left, at player 1)")
	var stam: float = f.chairs[1].stam
	f = _duel()
	f.params.stamina = 2.0
	_go(f)
	f.push_of(1, 0)
	ok(100.0 - float(f.chairs[1].stam) > (100.0 - stam) * 1.5, "the tier's stamina cost is player 2's too")
	# player 1 charges, player 2 sits still: three bumps to player 1
	for who in 2:
		f = _duel(3 + who)
		_go(f)
		var guard := 0
		var key := 0
		var t := 0.0
		while f.phase != "done" and guard < 60 * 80:
			t += 1.0 / 60.0
			if t >= 0.42:
				t = 0.0
				var me: Dictionary = f.chairs[who]
				var toward := 1 if float(f.chairs[1 - who].x) >= float(me.x) else -1
				if int(me.face) != toward:
					f.spin_of(who, toward)
				else:
					f.push_of(who, key)
					key = 1 - key
			f.step(1.0 / 60.0)
			guard += 1
		ok(f.phase == "done" and f.winner == who and int(f.score()[who]) == Fight.TARGET, "player %d charges a chair that sits still and wins 3 to %d" % [who + 1, int(f.score()[1 - who])])
		ok(f.stars() == 1 and f.comment().begins_with("PLAYER %d WINS" % (who + 1)), "1 star for playing, and the line names the winner")
	# both chairs driven (the crew's driver in both): every duel ends
	var ended := 0
	var wins := [0, 0, 0]
	for s in 24:
		f = _duel(100 + s)
		f.you_auto = true
		_go(f)
		var guard2 := 0
		while f.phase != "done" and guard2 < 30 * 120:
			f.step(1.0 / 30.0)
			guard2 += 1
		if f.phase == "done":
			ended += 1
			wins[f.winner] += 1
	ok(ended == 24, "24 driven duels all end")
	ok(wins[0] >= 4 and wins[1] >= 4, "neither chair has the better end of the strip (player 1 %d, player 2 %d, draws %d)" % wins)

	# ---- the keys, through Outings
	o.game = "chair"
	o.opts = {"event": "fight"}
	ok(not o._chair_duel() and not bool(o._chair_params().duel), "alone the fight is against the crew")
	players.enable_coop(true)
	players.join(1, 1)
	ok(o._chair_duel() and bool(o._chair_params().duel), "with player 2 in, the fight is a duel")
	o.opts = {"event": "straight"}
	ok(not o._chair_duel(), "a race stays the tandem")
	o.opts = {"event": "fight"}
	f = _duel()
	_go(f)
	o.g = {"race": f, "event": "fight"}
	o.phase = "play"
	o._press_slot = 1
	o._chair_press(KEY_Z)
	ok(int(f.chairs[1].pushes) == 1 and int(f.chairs[0].pushes) == 0 and int(f.chairs[1].key) == 0, "player 2's first leg pushes player 2's chair only")
	f.clock += 0.42
	o._chair_press(KEY_X)
	ok(int(f.chairs[1].pushes) == 2 and int(f.chairs[1].key) == 1, "player 2 has both legs")
	o._press_slot = 0
	o._chair_press(KEY_X)
	ok(int(f.chairs[0].pushes) == 1 and int(f.chairs[1].pushes) == 2, "player 1's keys push player 1's chair")
	o._press_slot = 1
	o._chair_press(KEY_UP)
	ok(int(f.chairs[1].lane_to) == 0 and int(f.chairs[0].lane_to) == 1, "player 2 changes their own lane")
	f.chairs[1].turn = 0.0
	o._chair_press(KEY_RIGHT)
	ok(int(f.chairs[1].face) == 1 and int(f.chairs[0].face) == 1, "and turns their own chair")
	ok(o._event_key_p2(_pad(JOY_BUTTON_A)) == KEY_Z and o._event_key_p2(_pad(JOY_BUTTON_B)) == KEY_X, "on player 2's pad A and B are the two legs")
	ok(o._chair_hint().begins_with("P1 = Z X  P2 = A B"), "the hint says who has which keys")
	f.chairs[0].bumps = 3
	f._finish()
	var info: Dictionary = o._chair_career(1)
	ok(bool(info.duel) and not bool(info.won), "a duel is not a won chair fight for the Career")
	ok(str(o._chair_lines()[1]) == "BUMPS: PLAYER 1 3, PLAYER 2 0.", "the result names both players")
	# a race in co-op is still the tandem: player 2's A is the X push
	var race: RefCounted = load("res://scripts/chair_race.gd").new()
	race.setup({"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0, "skill": 1.0}, ["Alan"], RandomNumberGenerator.new())
	o.g = {"race": race}
	ok(o._event_key_p2(_pad(JOY_BUTTON_A)) == KEY_X, "in a race player 2's A is still the tandem's second push")
	o.g = {}
	o.phase = "intro"
	o.opts = {}
	o.game = ""
	players.enable_coop(false)

	# ---- on the warehouse floor: two chairs, two players
	camp.new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(10)
	o.use_rooms = true
	o.start("chair", false, {"party": CREW, "event": "fight"})
	await create_timer(2.5).timeout
	await _wait(10)
	ok(current_scene.name == "Warehouse" and o.is_open and o.g.has("track") and o.g.race.duel, "the duel is set up in the warehouse")
	var track: Node = o.g.track
	ok(track.puppets.has("You") and track.puppets.has("P2") and not track.puppets.has("You2"), "a chair each: no second pilot riding behind")
	var watching: int = o.racers().size()  # (player 2 plays one of the cast, who is therefore not in the crowd)
	ok(watching >= 3 and track.puppets.size() == 2 + watching, "and the %d of the crew who came stand at the two ends" % watching)
	ok(track.puppets["P2"].chair.visible, "player 2's puppet sits in its own chair")
	var p2 := current_scene.get_node_or_null("Actors/Player2")
	ok(p2 != null and not p2.visible, "player 2's own body is hidden while the puppet rides")
	o.press(KEY_ENTER)
	await _wait(5)
	o.g.race.clock = -0.05
	await _wait(10)
	var px: float = track.puppets["P2"].node.position.x
	o._press_slot = 1
	o.press(KEY_Z)
	await _wait(30)
	ok(track.puppets["P2"].node.position.x < px - 1.0, "player 2's push moves player 2's puppet across the floor")
	o._press_slot = 0
	o.g.race.chairs[1].bumps = 3
	await create_timer(2.5).timeout
	await _wait(20)
	ok(o.phase == "result" and o.stars == 1, "the duel ends on the result page with 1 star (phase %s)" % o.phase)
	ok(career.value("chairfight_wins") == 0, "and BUMPER KING is not fed by a duel")
	o.press(KEY_ENTER)
	await create_timer(2.5).timeout
	await _wait(10)
	p2 = current_scene.get_node_or_null("Actors/Player2")
	ok(not o.is_open and current_scene.name == "MainFloor" and (p2 == null or p2.visible), "back at the office, both visible")
	players.enable_coop(false)
	print("coop_chair_duel: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
