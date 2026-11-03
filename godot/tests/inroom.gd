extends SceneTree
# The outing games played inside the rooms: bowling on the lane (pins fall, the crew bowls next
# door), karaoke at the mic, the escape room's clues and keypad, dinner at the booth. Headless.

var failures := 0
var _others_checked := false


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
	_check(o.hint().begins_with("E = STEP UP") and o.blocks_interact(), "ready: the hint says E steps up")
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
	_check(o.hint().begins_with("E = STOP THE AIM") and o._caption.contains("STOP THE AIM"), "aim: clear prompt")
	o.g.marker = 0.5
	o.press(KEY_E)
	_check(o.g.stage == "power", "E stops the aim")
	_check(o.hint().begins_with("E = STOP THE POWER") and o._caption.contains("STOP THE POWER"), "power: clear prompt")
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
			_check(o.g.stage == "others" and o.hint().begins_with("WAIT"), "E is ignored on the crew's turn")
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
	await _go(o, "karaoke", "karaoke_bar")
	o.press(KEY_ENTER)
	player = current_scene.get_node("Actors/Player")
	_check(
		absf(player.global_position.x - (24.0 + 238.0)) < 1.0 and player.state == "emote",
		"you are on the mic"
	)
	for n in o.g.notes:
		o.g.t = n.time
		o.kara_hit(n.lane)
	_check(o.g.score == 48 and o._marks.size() > 0, "a flawless song makes the room cheer")
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
	_check(o.g.eq[0] + o.g.eq[1] == code[0], "the chalkboard sum is the first digit")
	current_scene.get_node("Fx/Board").play()
	current_scene.get_node("Fx/WallClock").play()
	current_scene.get_node("Fx/Painting").play()
	_check(o.g.found.size() == 3, "all three clues are in the room")
	for zone in ["UseWallClock", "UsePainting", "UseBoard", "UseKeypad"]:
		var shp: Shape2D = current_scene.get_node("Interactables/%s/Shape" % zone).shape
		_check(shp.size.x >= 36.0, "%s zone is wide enough (%d px)" % [zone, int(shp.size.x)])
	_check(o._caption.contains(str(code[2])), "the plaque says " + o._caption)
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
			for who in o.DINERS:
				if o.LOVES[who].has(o.g.options[i]):
					pts += 2
				elif o.HATES[who] != o.g.options[i]:
					pts += 1
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
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func _check_others_once(o: Node) -> void:
	if _others_checked:
		return
	_others_checked = true
	_check(o.g.up.size() == 2 and o.g.queue.size() == 3, "the crew queue: Alan, Garrison, Dan")
