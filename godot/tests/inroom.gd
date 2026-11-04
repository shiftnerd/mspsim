extends SceneTree
# gdlint:disable=max-line-length
# The outing games played inside the rooms: bowling on the lane (pins fall, the crew bowls next
# door), karaoke at the mic, the escape room's clues and keypad, dinner at the booth. Headless.

var failures := 0
var _others_checked := false
var _cool_at := {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _settle(name: String) -> void:
	var n := 0
	while (_scene_name() != name or root.get_node("Game").busy) and n < 600:
		await process_frame
		n += 1
	for i in 5:
		await process_frame


func _go(o: Node, game: String, room: String) -> void:
	o.start(game)
	var n := 0
	while not o.is_open and n < 800:
		await process_frame
		n += 1
	await _settle(room)


func _leave(o: Node) -> void:
	if o.phase == "play":
		o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	await _settle("main_floor")


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var world := root.get_node("World")
	var game := root.get_node("Game")
	var social := root.get_node("Social")
	var campaign := root.get_node("Campaign")
	game.title_mode = false
	campaign.new_game(campaign.FREE)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle("main_floor")
	o.enabled = true
	o.use_rooms = true

	# ---- bowling on the lane
	await _go(o, "bowling", "bowling_alley")
	_check(o.is_open and o.room_mode() and o.phase == "intro", "bowling opens in the alley")
	o.press(KEY_ENTER)
	_check(o.g.stage == "ready" and not game.ui_open, "you stay free until you step up")
	_check(
		o.hint().begins_with("E = STEP UP") and o.blocks_interact(),
		"ready: the hint says E steps up"
	)
	var fx := current_scene.get_node("Fx/Lanes")
	_check(
		fx.kind == "bowl_lane" and not fx._bowl_game().is_empty(), "the lanes draw from the game"
	)
	var player := current_scene.get_node("Actors/Player")
	player.global_position.x = 300.0
	o.press(KEY_E)
	_check(
		o.g.stage == "aim" and absf(player.global_position.x - (24.0 + 152.0)) < 1.0,
		"E steps you up to the lane"
	)
	_check(
		o.hint().begins_with("E = STOP THE AIM") and o._caption.contains("STOP THE AIM"),
		"aim: clear prompt"
	)
	o.g.marker = 0.5
	o.press(KEY_E)
	_check(o.g.stage == "power", "E stops the aim")
	_check(
		o.hint().begins_with("E = STOP THE POWER") and o._caption.contains("STOP THE POWER"),
		"power: clear prompt"
	)
	o.g.power = 0.85
	o.press(KEY_E)
	_check(o.g.stage == "roll", "E again throws")
	o.tick(1.0)
	_check(
		o.g.stage == "pause" and o.g.up[0].count(true) < 10,
		"pins fall: %d left up" % o.g.up[0].count(true)
	)
	_check(o.g.fall.size() > 0, "the fallen pins are drawn for a moment")
	var guard := 0
	var saw_others := false
	while o.phase == "play" and guard < 400:
		if o.g.stage == "ready":
			o.press(KEY_E)
		elif o.g.stage == "aim":
			o.g.marker = 0.5
			o.press(KEY_E)
		elif o.g.stage == "power":
			o.g.power = 0.85
			o.press(KEY_E)
		elif o.g.stage == "others":
			saw_others = true
			_check_others_once(o)
			o.press(KEY_E)
			_check(
				o.g.stage == "others" and o.hint().begins_with("WAIT"),
				"E is ignored on the crew's turn"
			)
		o.tick(0.4)
		guard += 1
	_check(saw_others, "after your frame Alan, Garrison and Dan bowl next door")
	_check(
		o.phase == "result" and o.stars >= 2,
		"a perfect game wins (%d stars, %d)" % [o.stars, o.g.totals["You"]]
	)
	_check(game.ui_open, "the result page freezes the room")
	await _leave(o)

	# ---- karaoke at the mic
	var cards := root.get_node("Cards")
	await _go(o, "karaoke", "karaoke_bar")
	o.press(KEY_ENTER)
	_check(
		cards.is_open and cards.speaker == "Karaoke host" and cards.options.size() == 4,
		"the card at the mic lists the songs"
	)
	_check(
		not bool(cards.options[3].get("enabled", true)) and cards.options[0].id == "wobble",
		"the rap is locked and the default song comes first"
	)
	var neon := -1
	for i in cards.options.size():
		if cards.options[i].id == "neon":
			neon = i
	cards.pick(neon)
	_check(
		o.phase == "play" and o.g.song.id == "neon" and not game.ui_open,
		"a song other than the default plays in the room"
	)
	player = current_scene.get_node("Actors/Player")
	_check(
		absf(player.global_position.x - (24.0 + 238.0)) < 1.0 and player.state == "emote",
		"you are on the mic"
	)
	for n in o.g.notes:
		o.g.t = n.time
		o.kara_hit(n.lane)
	_check(
		o.g.score == 2 * o.g.notes.size() and o._marks.size() > 0,
		"a flawless song makes the room cheer"
	)
	_check(float(o.g.mood) >= 99.0 and o.g.chorus, "and the crowd meter is full")
	_check(o.g.get("dance", false), "and a long streak gets you dancing")
	o.g.t = 100.0
	o.tick(0.1)
	_check(o.phase == "result" and o.stars == 3, "3 stars")
	await _leave(o)

	# ---- escape room: find the clues, then the keypad
	social.rel["Alan"] = 40
	await _go(o, "escape", "escape_room")
	o.press(KEY_ENTER)
	var code: Array = o.g.code
	_check(code.size() == 3 and code[0] != code[1] and code[1] != code[2], "a hidden code")
	_check(o.clue_answer(o.g.clues[0]) == code[0], "the chalkboard is the first digit")
	current_scene.get_node("Fx/Board").play()
	current_scene.get_node("Fx/WallClock").play()
	current_scene.get_node("Fx/Painting").play()
	_check(o.g.found.size() == 3, "all three clues are in the room")
	current_scene.get_node("Fx/Shelf").play()
	_check(
		o.g.found.size() == 3 and o.HERRINGS.has(o._caption),
		"on a three digit code the bookshelf is a red herring"
	)
	for zone in ["UseWallClock", "UsePainting", "UseBoard", "UseKeypad"]:
		var shp: Shape2D = current_scene.get_node("Interactables/%s/Shape" % zone).shape
		_check(shp.size.x >= 36.0, "%s zone is wide enough (%d px)" % [zone, int(shp.size.x)])
	current_scene.get_node("Fx/Painting").play()
	_check(o._caption.contains(str(o.g.clues[2].say)), "the plaque says " + o._caption)
	var hints_before: int = o.g.hints
	var said: String = o.escape_nudge()
	_check(said.contains("ALAN") and o.g.hints == hints_before - 1, "N asks a friend: " + said)
	current_scene.get_node("Fx/Keypad").play()
	_check(o.g.entry and game.ui_open, "the keypad takes over while you enter the code")
	o.press(KEY_ESCAPE)
	_check(
		not o.g.entry and not game.ui_open and o.phase == "play", "Esc backs away from the keypad"
	)
	current_scene.get_node("Fx/Keypad").play()
	o.g.cur = [0, 0, 0]
	var time0: float = o.g.time
	o.press(KEY_ENTER)
	_check(o.g.time == time0 - 10.0 and o.phase == "play", "a wrong code costs 10 seconds")
	o.g.cur = code.duplicate()
	o.press(KEY_ENTER)
	_check(
		o.phase == "result" and o.stars >= 2, "the right code opens the vault (%d stars)" % o.stars
	)
	await _leave(o)

	# ---- hard: four digits, four clues (the bookshelf joins in), a silent lock
	var dif := root.get_node("Difficulty")
	dif.set_tier("hard")
	await _go(o, "escape", "escape_room")
	o.press(KEY_ENTER)
	code = o.g.code
	_check(
		code.size() == 4 and o.g.clues.size() == 4 and o.g.cur.size() == 4,
		"hard: a four digit code"
	)
	for i in 4:
		_check(
			o.clue_answer(o.g.clues[i]) == code[i], "hard: clue %d is digit %d" % [i + 1, code[i]]
		)
	for node in ["Board", "WallClock", "Painting", "Shelf"]:
		current_scene.get_node("Fx/" + node).play()
	_check(o.g.found.size() == 4, "all four clues are in the room")
	_check(o._caption.contains("DIGIT 4 OF 4"), "the bookshelf is digit four: " + o._caption)
	var zones := ["UseWallClock", "UsePainting", "UseBoard", "UseKeypad", "UseShelf"]
	var clear := true
	for zone in zones:
		var area: Node2D = current_scene.get_node("Interactables/" + zone)
		var half: float = current_scene.get_node("Interactables/%s/Shape" % zone).shape.size.x * 0.5
		_check(half >= 18.0, "%s is 36 px wide" % zone)
		for spot in o.SPOTS["escape"]:
			if absf(float(spot) - area.global_position.x) < half:
				clear = false
	_check(clear, "nobody stands in a clue zone")
	current_scene.get_node("Fx/Keypad").play()
	time0 = o.g.time
	o.g.cur = [0, 0, 0, 0]
	o.press(KEY_ENTER)
	_check(
		o.g.time == time0 - 15.0 and o.g.guesses.is_empty(),
		"hard: a wrong code costs 15 seconds and the lock says nothing"
	)
	o.g.cur = code.duplicate()
	o.press(KEY_ENTER)
	_check(
		o.phase == "result" and o.stars >= 1,
		"the four digit code opens the vault (%d stars)" % o.stars
	)
	dif.set_tier("normal")
	await _leave(o)

	# ---- normal: the dial lock tells you what fits
	await _go(o, "escape", "escape_room")
	o.press(KEY_ENTER)
	current_scene.get_node("Fx/Keypad").play()
	o.g.cur = [o.g.code[0], 0, 0]
	o.press(KEY_ENTER)
	_check(
		o.g.guesses.size() == 1 and o._caption.contains("THE DIAL CLICKS"), "normal: " + o._caption
	)
	await _leave(o)

	# ---- dinner at the booth
	await _go(o, "dinner", "restaurant")
	o.press(KEY_ENTER)
	_check(o.g.stage == "sit", "dinner waits until you sit down")
	var seated := 0
	for who in ["Alan", "Garrison", "Dan", "Vic"]:
		var npc := current_scene.get_node_or_null("Actors/" + who)
		seated += 1 if npc != null and npc.seat != null else 0
	_check(seated == 4, "the team is already in their seats (%d of 4)" % seated)
	player = current_scene.get_node("Actors/Player")
	player.global_position = current_scene.get_node("Interactables/Seat2").global_position
	player.sit(current_scene.get_node("Interactables/Seat2"))
	guard = 0
	while o.g.stage == "sit" and guard < 300:
		await process_frame
		guard += 1
	_check(o.g.stage == "talk" and game.ui_open, "sitting down starts the conversation")
	for round_no in 5:
		var pick := 0
		var top := -1
		for i in 4:
			var pts := 0
			for who in o.diners():
				pts += o.diner_points(who, o.g.options[i])
			if pts > top:
				top = pts
				pick = i
		o.dinner_talk(pick)
		if round_no == 0:
			_check(
				o._marks.size() >= 3 and o._caption.contains("ALAN"),
				"their faces show it: " + o._caption
			)
		o.tick(2.0)
	_check(o.phase == "result" and o.stars >= 2, "good conversation: %d stars" % o.stars)
	await _leave(o)
	# ---- R21: cornhole in the warehouse (two boards, you at A, the crew member of the round at B)
	dif.seed_run(4242)  # these two play a bot through a seeded game, so the run is the same every time
	await _go(o, "cornhole", "warehouse")
	_check(o.is_open and o.room_mode() and o.phase == "intro", "cornhole opens in the warehouse")
	o.press(KEY_ENTER)
	var cg: RefCounted = o.g.game
	var wp := current_scene.get_node("Actors/Player")
	var wx0: float = o._x0()
	_check(absf(wp.global_position.x - (wx0 + o.CORN_A)) < 1.0 and not game.ui_open, "you stand at board A")
	o.tick(0.1)
	var alan := current_scene.get_node("Actors/Alan")
	var gar := current_scene.get_node("Actors/Garrison")
	_check(absf(alan.global_position.x - (wx0 + o.CORN_B)) < 2.0, "Alan, the first opponent, stands at board B")
	_check(absf(gar.global_position.x - (wx0 + float(o.SPOTS.cornhole[1]))) < 2.0, "Garrison watches with the audience")
	_check(o.blocks_interact() and o.hint().begins_with("WAIT FOR YOUR THROW"), "READY: wait for your throw")
	await process_frame
	await process_frame
	var cam := current_scene.get_viewport().get_camera_2d()
	_check(cam != null and absf(cam.offset.x - o.CORN_PAN) < 0.5 and cam.offset.y >= 0.0, "the camera sits between the boards and above the HUD (%s)" % str(cam.offset))
	_check(current_scene.get_node("Fx/BoardA")._corn_game() == cg and current_scene.get_node("Fx/BoardB")._corn_game() == cg, "both boards draw from the game")
	o.tick(1.5)
	_check(cg.phase == "aim" and o.hint().begins_with("E = STOP THE AIM") and o._caption.contains("AIM"), "aim: clear prompt")
	cg.marker = 0.5
	o.press(KEY_E)
	_check(cg.phase == "power" and o.hint().begins_with("E = STOP THE POWER"), "E stops the aim")
	cg.power = 0.6
	o.press(KEY_E)
	o.tick(0.1)
	_check(cg.phase == "flight" and wp.state == "emote", "E throws: the bag flies and you reach")
	o.tick(1.0)
	_check(cg.landed.size() == 1 and cg.landed[0].who == "you", "the bag lands on board B")
	var fxa := current_scene.get_node("Fx/BoardA")
	_check(absf(fxa.corn_xy("you", 39.0, 0.0).x - (1236.0 + 19.5)) < 0.01, "the hole is 19.5 px from the near end of board B")
	var heard := false
	var guard2 := 0
	while o.phase == "play" and guard2 < 6000:
		guard2 += 1
		if cg.phase == "aim":
			cg.marker = 0.5
			o.press(KEY_E)
		elif cg.phase == "power":
			cg.power = 0.6
			o.press(KEY_E)
		o.tick(0.1)
		if guard2 % 50 == 0:
			await process_frame
		if cg.round_no == 2 and cg.phase in ["aim", "ready"] and not heard:
			heard = true
			_check(absf(gar.global_position.x - (wx0 + o.CORN_B)) < 2.0 and absf(alan.global_position.x - (wx0 + float(o.SPOTS.cornhole[0]))) < 2.0, "round 2: Garrison walks to board B, Alan back to the audience")
	_check(heard and o.phase == "result" and o.stars >= 2, "a perfect game reaches the result page (%d stars)" % o.stars)
	await _leave(o)
	_check(not is_instance_valid(cam) or absf(cam.offset.x) < 0.5, "the camera is back to normal")

	# ---- R21: the cookout at the grill
	dif.seed_run(4244)
	await _go(o, "grill", "warehouse")
	o.press(KEY_ENTER)
	var gg: RefCounted = o.g.game
	wp = current_scene.get_node("Actors/Player")
	_check(absf(wp.global_position.x - (wx0 + o.GRILL_X)) < 1.0, "you stand at the grill")
	_check(absf(current_scene.get_node("Actors/Alan").global_position.x - (wx0 + float(o.SPOTS.grill[0]))) < 2.0, "the crew queues to your left")
	_check(o.blocks_interact() and o.hint().begins_with("ARROWS = PICK"), "the hint line: arrows, E, space, shift")
	_check(current_scene.get_node("Fx/Grill")._grill_game() == gg, "the grill draws from the game")
	await process_frame
	await process_frame
	cam = current_scene.get_viewport().get_camera_2d()
	_check(absf(cam.offset.x - o.GRILL_PAN) < 0.5, "the camera shows the queue")
	o.tick(1.5)
	_check(gg.open_tickets().size() == 1 and o._marks.size() >= 1, "the first order comes in with a bubble over the customer")
	o.press(KEY_RIGHT)
	_check(gg.sel == 1, "RIGHT picks the next patty")
	gg.slots[1].c = [0.45, 0.0]
	o.press(KEY_E)
	_check(gg.slots[1].down == 1 and wp.state == "emote", "E flips (you reach)")
	var guard3 := 0
	while o.phase == "play" and guard3 < 4000:
		guard3 += 1
		_grill_bot(o, gg)
		o.tick(0.1)
		if guard3 % 40 == 0:
			await process_frame
	_check(o.phase == "result" and o.stars >= 2 and gg.served >= 4, "a cook gets a result (%d stars, %d served)" % [o.stars, gg.served])
	await _leave(o)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func _check_others_once(o: Node) -> void:
	if _others_checked:
		return
	_others_checked = true
	_check(o.g.up.size() == 2 and o.g.queue.size() == 3, "the crew queue: Alan, Garrison, Dan")


# a cook that plays the real keys: picks the slot, flips with E, serves with Space, parks a flaring patty with Shift (and puts it back after 5 s)
func _grill_bot(o: Node, gg: RefCounted) -> void:
	for i in 4:
		var s: Dictionary = gg.slots[i]
		if not s.on:
			_cool_at.erase(i)
			continue
		var nw := 0
		var nm := 0
		for t in gg.open_tickets():
			nw += int(t.need.well) - int(t.have.well)
			nm += int(t.need.medium) - int(t.have.medium)
		var c: Array = s.c
		var lo := minf(float(c[0]), float(c[1]))
		var hi := maxf(float(c[0]), float(c[1]))
		var done: String = gg.doneness(i)
		var key := KEY_NONE
		if float(s.flare) > 0.0 and not s.cool:
			key = KEY_SHIFT
			_cool_at[i] = gg.clock
		elif s.cool:
			if gg.clock - float(_cool_at.get(i, 0.0)) > 5.0:
				key = KEY_SHIFT
		elif int(s.flipped) == 0 and float(c[s.down]) >= (0.58 if nw > nm else 0.4):
			key = KEY_E
		elif int(s.flipped) >= 1 and ((done == "medium" and nm > 0 and lo >= 0.37) or (done == "well" and nw > 0 and lo >= 0.58) or hi > 0.84):
			key = KEY_SPACE
		if key != KEY_NONE:
			gg.sel = i
			o.press(key)
