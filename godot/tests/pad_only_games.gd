extends SceneTree
# gdlint:disable=max-line-length
# R42 Steam Deck, part two of the pad-only walk (tests/pad_only.gd is the campaign day): every mini-game is started, played a
# little and finished or cleanly left from Free Play with a pad and nothing else. Every input is an InputEventJoypadButton
# or InputEventJoypadMotion through Input.parse_input_event. Free Play is reached from the title (FREE PLAY, the creator,
# the options page), each game from START, FREE PLAY MENU, TOOLBOX (the pad's road to the toolbox): bowling, karaoke, the
# escape room, dinner, the printer, a nerf war, the chair race / gauntlet / chair fight, paintball, cornhole, the cookout
# and darts. Then the blaster rack in the cubicles: RT fires, Y offers a war, the right stick gives the blaster away.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/pad_only_games.gd [-- --only=bowling,darts] [--trace]

var failures := 0
var trace := false
var only: PackedStringArray = PackedStringArray()
var game: Node
var cards: Node
var comp: Node
var phone: Node
var pm: Node
var camp: Node
var world: Node
var msp: Node
var ctl: Node
var outings: Node
var tb: Node
var printer: Node
var nerf: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


# ---- the pad ----------------------------------------------------------------------------------------------------------
func _button(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)


func _tap(b: JoyButton, after := 3) -> void:
	_button(b, true)
	await _wait(2)
	_button(b, false)
	await _wait(after)


func _axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


# push a stick to one side and let it go: a menu step, or a flick of the right stick
func _flick(axis: JoyAxis, value: float, after := 3) -> void:
	_axis(axis, value)
	await _wait(2)
	_axis(axis, 0.0)
	await _wait(after)


func _a() -> void:
	await _tap(JOY_BUTTON_A)


func _b() -> void:
	await _tap(JOY_BUTTON_B)


func _dpad(dir: String, times := 1) -> void:
	var b: JoyButton = {"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT}[dir]
	for i in times:
		await _tap(b)


func _player() -> Node:
	return current_scene.get_node_or_null("Actors/Player") if current_scene != null else null


func _room() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


# what is on the screen now (for the trace and for failures)
func _state() -> String:
	var out := "room %s" % _room()
	var p := _player()
	if p != null:
		out += " player %s x%d" % [p.state, int(p.global_position.x)]
	if cards.is_open:
		var labels := []
		for o in cards.options:
			labels.append(str(o.label))
		out += " | CARD %s: %s %s" % [cards.speaker, str(cards.text).substr(0, 60), str(labels)]
	if comp.is_open:
		out += " | COMPUTER %s" % comp.app
	if phone.is_open:
		out += " | PHONE %s%s" % [phone.app, " locked" if phone.locked else ""]
	if pm.is_open:
		out += " | PAUSE %s sel %d" % [str(pm._labels()), pm._sel]
	if root.get_node("DayReport").is_open:
		out += " | DAY REPORT"
	if root.get_node("Review").is_open:
		out += " | REVIEW"
	if root.get_node("Toolbox").is_open:
		out += " | TOOLBOX"
	if root.get_node("Outings").is_open:
		out += " | OUTING %s %s" % [root.get_node("Outings").game, root.get_node("Outings").phase]
	return out


func _note(what: String) -> void:
	if trace:
		print("     .. %s: %s" % [what, _state()])


# answer whatever cards are up with A (the first choice), waiting out the card's half second
func _answer_cards(limit := 12) -> int:
	var n := 0
	while cards.is_open and n < limit:
		_note("card")
		await _wait_ms(480)
		await _a()
		await _wait(4)
		n += 1
	return n


# ---- screens made of click regions (the computer, the phone): RB steps the cursor, A presses ---------------------------
func _under(scr: Node) -> String:
	for i in range(scr._hits.size() - 1, -1, -1):
		if scr._hits[i].r.has_point(scr._mouse):
			return str(scr._hits[i].id)
	return ""


func _ids(scr: Node) -> Array:
	var out := []
	for h in scr._hits:
		out.append(str(h.id))
	return out


# RB until the cursor is on the region `want` (an id, or a prefix ending in ":"), then A. False when it is not on screen.
func _press_region(scr: Node, want: String) -> bool:
	await _wait(3)
	for i in scr._hits.size() + 3:
		var id := _under(scr)
		if scr.pad_focus and (id == want or (want.ends_with(":") and id.begins_with(want))):
			await _a()
			await _wait(3)
			return true
		await _tap(JOY_BUTTON_RIGHT_SHOULDER, 2)
	print("     (no region %s among %s)" % [want, str(_ids(scr))])
	return false


# hold the left stick until you stand at x
func _walk_to(x: float, slack := 5.0) -> void:
	var p := _player()
	var n := 0
	while absf(p.global_position.x - x) > slack and n < 900:
		_axis(JOY_AXIS_LEFT_X, 1.0 if x > p.global_position.x else -1.0)
		await process_frame
		n += 1
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _wait(6)



func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace":
			trace = true
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",")
	game = root.get_node("Game")
	cards = root.get_node("Cards")
	comp = root.get_node("Computer")
	phone = root.get_node("Phone")
	pm = root.get_node("PauseMenu")
	camp = root.get_node("Campaign")
	world = root.get_node("World")
	msp = root.get_node("Msp")
	ctl = root.get_node("Controls")
	outings = root.get_node("Outings")
	tb = root.get_node("Toolbox")
	printer = root.get_node("PrinterGame")
	nerf = root.get_node("Nerf")
	var pid := OS.get_process_id()
	camp.save_prefix = "user://test_%d_padgames_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_padgames_settings.cfg" % pid
	ctl.binds_path = "user://test_%d_padgames_controls.cfg" % pid
	phone.save_path = "user://test_%d_padgames_phone.cfg" % pid

	await _free_play()
	for id in ["bowling", "karaoke", "escape", "dinner", "printer", "nerf", "chair", "gauntlet", "fight", "paintball", "cornhole", "grill", "darts"]:
		if only.is_empty() or only.has(id):
			await _game(id)
	if only.is_empty() or only.has("rack"):
		await _rack()
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)


# ---- the title to Free Play ---------------------------------------------------------------------------------------------
func _free_play() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(30)
	var title := current_scene
	await _a()
	var guard := 0
	while str(title._items[title._sel].id) != "free" and guard < 8:
		await _dpad("down")
		guard += 1
	await _a()
	var cs: Node = title._select
	_check(cs != null and cs.mode == "free" and cs.step == "create", "title: A, down to FREE PLAY, A: the creator")
	if cs == null:
		return
	await _dpad("up")  # from the first row up wraps to the bottom row (RANDOM | PRESETS | DONE)
	guard = 0
	while str(cs.CREATE_ACTIONS[cs.create_col]) != "done" and guard < 4:
		await _dpad("right")
		guard += 1
	await _a()
	_check(cs.step == "options", "DONE goes on to the options (%s)" % cs.step)
	guard = 0
	while is_instance_valid(cs) and title._select != null and guard < 4:
		await _a()
		await _wait(4)
		guard += 1
	await _wait(60)
	_check(camp.mode == camp.FREE and not camp.active and _player() != null, "A starts Free Play: a room with you in it (%s)" % _state())


# START, FREE PLAY MENU, TOOLBOX, the GAME row, GO
func _launch(id: String) -> bool:
	await _answer_cards()
	await _tap(JOY_BUTTON_START)
	if not pm.is_open:
		print("     (the pause menu did not open: %s)" % _state())
		return false
	var guard := 0
	while pm._row_id(pm._sel) != "free" and guard < 10:
		await _dpad("down")
		guard += 1
	await _a()
	await _wait(6)
	if not cards.is_open:
		print("     (no FREE PLAY MENU card: %s)" % _state())
		return false
	await _wait_ms(480)
	guard = 0
	while str(cards.options[cards.sel].id) != "tools" and guard < 6:
		await _dpad("down")
		guard += 1
	await _a()
	await _wait(6)
	if not tb.is_open:
		print("     (the toolbox did not open: %s)" % _state())
		return false
	guard = 0
	while str(tb.current_row().id) != "game" and guard < 12:
		await _dpad("up")
		guard += 1
	guard = 0
	while tb.game_id() != id and guard < 14:
		await _dpad("right")
		guard += 1
	guard = 0
	while str(tb.current_row().id) != "go" and guard < 14:
		await _dpad("down")
		guard += 1
	await _a()
	await _wait(4)
	return not tb.is_open and tb.game_id() == id


func _ostate() -> String:
	var s := "%s open %s phase %s room_mode %s stars %d" % [outings.game, outings.is_open, outings.phase, outings.room_mode(), outings.stars]
	var g: Dictionary = outings.g
	for k in ["stage", "entry", "event", "t", "score", "turn"]:
		if g.has(k):
			s += " %s=%s" % [k, str(g[k]).substr(0, 30)]
	return s + " | hint: " + outings.hint() + " | " + _state()


# the interactable of the room whose prop is of this kind ("keypad", "clue_board", "nerf_rack" ...), or null
func _zone(kind: String) -> Node:
	for it in current_scene.get_node("Interactables").get_children():
		if it.get("target") == null:
			continue
		var fx: Node = it.get_node_or_null(it.target)
		if fx != null and str(fx.get("kind")).begins_with(kind):
			return it
	return null


# walk to an interactable and press X on it
func _use(it: Node) -> void:
	await _walk_to(it.global_position.x, 3.0)
	var fx: Node = it.get_node_or_null(it.target) if it.get("target") != null else null
	var guard := 0
	while fx != null and fx.get("busy") == true and guard < 600:  # a prop that was just used finishes its little animation first
		await process_frame
		guard += 1
	guard = 0
	while _player().state not in ["idle", "walk", "run"] and guard < 300:  # still reaching out from the last press
		await process_frame
		guard += 1
	guard = 0
	while _player().nearest() != it and guard < 8:  # RB moves the arrow when something else is closer
		await _tap(JOY_BUTTON_RIGHT_SHOULDER)
		guard += 1
	await _tap(JOY_BUTTON_X, 8)


# B (or BACK where B is a game button) leaves, A closes the result page, and you are back in the office
func _leave(id: String, button: JoyButton = JOY_BUTTON_B) -> void:
	if outings.is_open and outings.phase != "result":
		await _tap(button, 10)
		_check(outings.phase == "result" and outings.stars == -1, "%s: %s leaves, the result page says so (%s)" % [id, "BACK" if button == JOY_BUTTON_BACK else "B", _ostate()])
	await _back_home(id)


func _back_home(id: String) -> void:
	var n := 0
	while (outings.is_open or game.busy or _room() != "main_floor" or cards.is_open) and n < 1200:
		if cards.is_open:
			await _answer_cards()
		elif outings.is_open and outings.phase == "result" and n % 20 == 0:
			await _a()
		await process_frame
		n += 1
	await _wait(20)
	_check(not outings.is_open and _room() == "main_floor" and not game.ui_open and _player() != null, "%s: A closes the result, back in the office (%s)" % [id, _state()])


func _game(id: String) -> void:
	var tool_id := "chair" if id in ["gauntlet", "fight"] else id
	var ok := await _launch(tool_id)
	_check(ok, "%s: START, FREE PLAY MENU, TOOLBOX, GAME, GO" % id)
	if not ok:
		return
	if id == "printer":
		await _printer()
		return
	if id == "nerf":
		await _nerf_war()
		return
	var n := 0
	while not (outings.is_open and outings.phase == "intro") and n < 600:
		await process_frame
		n += 1
	_check(outings.is_open and outings.game == tool_id and outings.phase == "intro", "%s: the intro page (%s)" % [id, _ostate()])
	if tool_id == "chair":
		var want := "straight" if id == "chair" else id
		var guard := 0
		while outings._chair_event_now() != want and guard < 4:
			await _dpad("right")
			guard += 1
		_check(outings._chair_event_now() == want, "%s: D-pad right on the card picks the event (%s)" % [id, outings._chair_event_now()])
	await _a()
	await _wait(10)
	if cards.is_open:  # karaoke: the song card at the mic
		await _answer_cards()
	n = 0
	while outings.phase != "play" and n < 300:
		await process_frame
		n += 1
	_check(outings.phase == "play", "%s: A starts it (%s)" % [id, _ostate()])
	if outings.phase != "play":
		outings.close()
		return
	match id:
		"bowling":
			await _bowling()
		"karaoke":
			await _karaoke()
		"escape":
			await _escape()
		"dinner":
			await _dinner()
		"chair", "gauntlet", "fight":
			await _chair(id)
		"paintball":
			await _paintball()
		"cornhole":
			await _cornhole()
		"grill":
			await _grill()
		"darts":
			await _darts()


func _bowling() -> void:
	var g: Dictionary = outings.g
	var n := 0
	while str(g.stage) != "ready" and n < 1200:
		await process_frame
		n += 1
	await _tap(JOY_BUTTON_X, 6)
	_check(str(g.stage) == "aim", "bowling: X steps up to the lane (%s)" % str(g.stage))
	await _dpad("left")
	_check(int(g.get("spin", 0)) == -1, "bowling: D-pad left asks for a hook")
	await _dpad("left")
	await _tap(JOY_BUTTON_X, 6)
	_check(str(g.stage) == "power", "bowling: X stops the aim (%s)" % str(g.stage))
	await _tap(JOY_BUTTON_X, 6)
	_check(str(g.stage) == "roll", "bowling: X stops the power, the ball rolls (%s)" % str(g.stage))
	await _wait(120)
	await _leave("bowling")


func _karaoke() -> void:
	var g: Dictionary = outings.g
	var dirs := ["left", "up", "down", "right"]
	var hit := 0
	var tried := 0
	var n := 0
	while tried < 4 and n < 3600:
		var note: Dictionary = {}
		for cand in g.notes:
			if str(cand.state) == "" and not cand.get("auto", false) and float(cand.get("len", 0.0)) <= 0.0 and float(cand.time) > float(g.t) + 0.1:
				note = cand
				break
		if note.is_empty():
			break
		while float(note.time) - float(g.t) > 0.02 and n < 3600:
			await process_frame
			n += 1
		await _dpad(dirs[int(note.lane)])
		tried += 1
		if str(note.state) != "" and str(note.state) != "miss":
			hit += 1
	_check(hit >= 1 and int(g.score) > 0, "karaoke: the D-pad hits the notes on the line (%d of %d, score %d)" % [hit, tried, int(g.score)])
	await _leave("karaoke")


func _escape() -> void:
	var g: Dictionary = outings.g
	var hints: int = int(g.hints)
	await _tap(JOY_BUTTON_Y, 6)
	_check(int(g.hints) == hints - 1, "escape room: Y asks a friend for a nudge (%d -> %d)" % [hints, int(g.hints)])
	var clue := _zone("clue_")
	_check(clue != null, "escape room: there is a clue to look at")
	if clue != null:
		var found: int = (g.found as Array).size()
		var time0: float = float(g.time)
		await _use(clue)
		_check((g.found as Array).size() > found or outings._caption_t > 0.0 or float(g.time) < time0 - 1.0, "escape room: X on it reads the clue (%d found)" % (g.found as Array).size())
	var pad := _zone("keypad")
	_check(pad != null, "escape room: the keypad")
	if pad == null:
		await _leave("escape")
		return
	await _use(pad)
	_check(bool(g.get("entry", false)), "escape room: X at the keypad opens the code entry")
	await _b()
	_check(not bool(g.get("entry", false)) and outings.is_open and outings.phase == "play", "escape room: B backs off from the keypad, the game goes on")
	await _use(pad)
	var code: Array = g.code
	for k in code.size():
		var guard := 0
		while int(g.cursor) != k and guard < 8:
			await _dpad("right")
			guard += 1
		guard = 0
		while int(g.cur[k]) != int(code[k]) and guard < 12:
			await _dpad("up")
			guard += 1
	_check(str(g.cur) == str(code), "escape room: the D-pad dials the code (%s)" % str(g.cur))
	await _a()
	var n := 0
	while outings.phase != "result" and n < 600:
		await process_frame
		n += 1
	_check(outings.phase == "result" and outings.stars >= 1, "escape room: A tries it, the door opens: finished with %d stars" % outings.stars)
	await _back_home("escape")


func _dinner() -> void:
	var g: Dictionary = outings.g
	var seat: Node = null
	for it in current_scene.get_node("Interactables").get_children():
		if str(it.name).begins_with("Seat") and not it.get("occupied") and (seat == null or absf(it.global_position.x - _player().global_position.x) < absf(seat.global_position.x - _player().global_position.x)):
			seat = it
	_check(seat != null, "dinner: a free seat at the booth")
	if seat == null:
		await _leave("dinner")
		return
	await _use(seat)
	var n := 0
	while str(g.get("stage", "")) == "sit" and n < 600:
		await process_frame
		n += 1
	_check(str(g.get("stage", "")) != "sit" and _player().state == "sitting", "dinner: X sits down with the team (%s)" % _ostate())
	var picks := 0
	n = 0
	while outings.phase == "play" and n < 6000 and picks < 12:
		if cards.is_open:
			await _answer_cards()
		elif (g.react as Dictionary).is_empty() and str(g.get("stage", "")) != "sit":
			if picks == 1:
				await _dpad("down")  # the second pick: another row
			await _a()
			await _wait(4)
			picks += 1
		await process_frame
		n += 1
	if cards.is_open:
		await _answer_cards()
	_check(outings.phase == "result" and outings.stars >= 0, "dinner: the plate and five rounds of talk by D-pad and A: finished with %d stars (%d picks)" % [outings.stars, picks])
	await _back_home("dinner")


func _chair(id: String) -> void:
	var race: RefCounted = outings.g.race
	var n := 0
	while float(race.clock) < 0.0 and n < 600:
		await process_frame
		n += 1
	_check(float(race.clock) >= 0.0, "%s: the countdown is over" % id)
	ctl.pad_active = true
	var shown: String = ctl.hint(outings.hint(), outings._hint_map())
	_check(shown.find("(B) = LEAVE") < 0, "%s: the hint does not promise B for leaving (%s)" % [id, shown])
	if id == "fight":
		for i in 10:
			await _tap(JOY_BUTTON_A if i % 2 == 0 else JOY_BUTTON_B, 4)
		await _dpad("right")
		await _dpad("down")
		_check(outings.is_open and outings.phase == "play", "fight: A and B push, the D-pad turns and changes lane; B does not leave here")
		await _leave(id, JOY_BUTTON_BACK)
		return
	var pos0: float = float(race.pos)
	for i in 12:
		await _tap(JOY_BUTTON_A if i % 2 == 0 else JOY_BUTTON_B, 4)
	_check(float(race.pos) > pos0 + 10.0, "%s: A and B in turn push the chair (%d -> %d px)" % [id, int(pos0), int(race.pos)])
	var lane0: int = int(race.lane_to)
	await _dpad("down")
	var lane1: int = int(race.lane_to)
	await _dpad("up")
	_check(lane1 == lane0 + 1 and int(race.lane_to) == lane0, "%s: D-pad down and up change lane (%d, %d, %d)" % [id, lane0, lane1, int(race.lane_to)])
	if id == "gauntlet":
		await _leave(id, JOY_BUTTON_BACK)
		return
	# the straight race is run to the end
	n = 0
	var k := 0
	while outings.phase == "play" and n < 5000:
		_button(JOY_BUTTON_A if k % 2 == 0 else JOY_BUTTON_B, true)
		await _wait(3)
		_button(JOY_BUTTON_A if k % 2 == 0 else JOY_BUTTON_B, false)
		await _wait(3)
		k += 1
		n += 6
	_check(outings.phase == "result" and outings.stars >= 0, "chair: pushed to the finish line: finished with %d stars after %d more pushes" % [outings.stars, k])
	await _back_home(id)


func _paintball() -> void:
	var rules: RefCounted = outings.g.rules
	var n := 0
	while str(rules.phase) != "play" and n < 600:
		await process_frame
		n += 1
	_check(str(rules.phase) == "play", "paintball: the countdown is over (%s)" % str(rules.phase))
	var me: Dictionary = rules.units[0]
	var x0: float = float(me.x)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _wait(40)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _wait(2)
	_check(float(me.x) > x0 + 5.0, "paintball: the stick runs up the street (%d -> %d)" % [int(x0), int(me.x)])
	var lane0: int = int(me.lane)
	await _dpad("down")
	var lane1: int = int(me.lane)
	await _dpad("up")
	_check(lane1 != lane0 or int(me.lane) != lane1, "paintball: D-pad up / down change lane (%d, %d, %d)" % [lane0, lane1, int(me.lane)])
	var cool0: float = float(me.cool)
	await _tap(JOY_BUTTON_A, 2)
	_check(float(me.cool) > cool0, "paintball: A fires (the marker reloads for %.2f s)" % float(me.cool))
	_button(JOY_BUTTON_B, true)
	await _wait(6)
	_check(bool(me.duck), "paintball: B held ducks")
	_button(JOY_BUTTON_B, false)
	await _wait(4)
	_check(not bool(me.duck) and outings.phase == "play", "paintball: B let go stands up (B does not leave here)")
	ctl.pad_active = true
	await _leave("paintball", JOY_BUTTON_BACK)


func _cornhole() -> void:
	var cg: RefCounted = outings.g.game
	var n := 0
	while not (cg.your_turn() and str(cg.phase) == "aim") and n < 1800:
		await process_frame
		n += 1
	_check(cg.your_turn() and str(cg.phase) == "aim", "cornhole: your throw (%s)" % str(cg.phase))
	await _tap(JOY_BUTTON_X, 4)
	_check(str(cg.phase) == "power", "cornhole: X stops the aim (%s)" % str(cg.phase))
	await _tap(JOY_BUTTON_X, 4)
	_check(str(cg.phase) != "power" and str(cg.phase) != "aim", "cornhole: X stops the power, the bag flies (%s)" % str(cg.phase))
	await _wait(60)
	await _leave("cornhole")


func _grill() -> void:
	var gg: RefCounted = outings.g.game
	await _wait(30)
	var sel0: int = int(gg.sel)
	await _dpad("right")
	_check(int(gg.sel) != sel0, "cookout: D-pad right picks the next spot on the grill (%d -> %d)" % [sel0, int(gg.sel)])
	await _dpad("left")
	await _tap(JOY_BUTTON_X, 4)
	await _tap(JOY_BUTTON_A, 4)
	await _tap(JOY_BUTTON_B, 4)
	_check(outings.is_open and outings.phase == "play", "cookout: X flips, A serves, B moves to the cool side (B does not leave here)")
	ctl.pad_active = true
	await _leave("grill", JOY_BUTTON_BACK)


func _darts() -> void:
	var dg: RefCounted = outings.g.game
	var thrown := 0
	var n := 0
	while outings.phase == "play" and n < 6000 and thrown < 40:
		if dg.aiming():
			await _tap(JOY_BUTTON_X, 6)
			thrown += 1
		await process_frame
		n += 1
	if cards.is_open:
		await _answer_cards()
	_check(outings.phase == "result" and thrown >= 1, "darts: X throws each dart: the round is finished (%d darts, %d stars)" % [thrown, outings.stars])
	await _back_home("darts")


func _printer() -> void:
	var n := 0
	while not printer.is_open and n < 120:
		await process_frame
		n += 1
	_check(printer.is_open and printer.phase == "intro", "printer: the page is up (%s)" % printer.phase)
	await _a()
	_check(printer.phase != "intro", "printer: A starts the job (%s)" % printer.phase)
	var n2 := 0
	while printer.phase == "jam" and n2 < 900:  # the paper jam: A when the marker is in the zone, until the sheet is out
		if absf(float(printer.marker) - float(printer.zone)) < 0.03:
			await _tap(JOY_BUTTON_A, 1)
		await process_frame
		n2 += 1
	_check(printer.phase != "jam", "printer: A in the zone pulls the jammed sheet out (%s)" % printer.phase)
	await _tap(JOY_BUTTON_Y)
	_check(printer.prayed, "printer: Y prays")
	await _b()
	_check(printer.phase == "result", "printer: B gives up, the result page (%s)" % printer.phase)
	n = 0
	while printer.is_open and n < 10:
		await _wait_ms(300)
		await _a()
		await _wait(10)
		n += 1
	_check(not printer.is_open and not game.ui_open, "printer: A closes it (%s)" % _state())


func _nerf_war() -> void:
	_check(nerf.war_t > 0.0, "nerf: the war is on (%d s)" % int(nerf.war_t))
	_button(JOY_BUTTON_DPAD_DOWN, true)
	await _wait(10)
	_check(_player().state == "duck", "nerf: D-pad down ducks under the darts (%s)" % _player().state)
	_button(JOY_BUTTON_DPAD_DOWN, false)
	var n := 0
	while nerf.war_t > 0.0 and n < 4000:
		await process_frame
		n += 1
	_check(nerf.war_t <= 0.0 and not nerf.last_result.is_empty(), "nerf: the war runs out and the score card is written (%s)" % str(nerf.last_result.get("titles", [])))


# ---- the blaster rack in the cubicles: walk there, X takes one, RT fires, Y offers a war, the right stick gives it away
func _rack() -> void:
	await _answer_cards()
	var p := _player()
	var door: Node = current_scene.get_node_or_null("Interactables/ExitToCubicles")
	_check(door != null, "rack: the way to the cubicles")
	_axis(JOY_AXIS_LEFT_X, 1.0)
	var n := 0
	while _room() != "cubicle_area" and n < 1500:
		await process_frame
		n += 1
		if n % 120 == 0 and _room() == "main_floor" and _player() != null and absf(_player().global_position.x - door.global_position.x) < 12.0:
			await _tap(JOY_BUTTON_X)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _wait(40)
	_check(_room() == "cubicle_area", "rack: the stick walks you through to the cubicles (%s)" % _state())
	if _room() != "cubicle_area":
		return
	p = _player()
	var rack := _zone("nerf_rack")
	_check(rack != null, "rack: the blaster rack is here")
	if rack == null:
		return
	await _use(rack)
	n = 0
	while str(p.held) != "nerf" and n < 120:
		await process_frame
		n += 1
	_check(str(p.held) == "nerf", "rack: X takes a blaster (%s)" % str(p.held))
	await _wait(30)
	var ammo: int = nerf._ammo[0]
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _wait(3)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait(20)
	_check(nerf._ammo[0] < ammo or nerf.war_t > 0.0, "rack: RT fires a dart (%d -> %d)" % [ammo, nerf._ammo[0]])
	if nerf.war_t <= 0.0:
		await _tap(JOY_BUTTON_Y, 8)
		_check(cards.is_open and str(cards.speaker).to_upper().find("NERF") >= 0, "rack: Y offers a war, the card of games (%s)" % _state())
		await _wait_ms(480)
		await _a()
		await _wait(10)
		_check(nerf.war_t > 0.0 and not cards.is_open, "rack: A picks the first game, the war is on (%s, %d s)" % [str(nerf.mode), int(nerf.war_t)])
	await _flick(JOY_AXIS_RIGHT_X, -1.0, 6)
	_check(str(p.held) == "", "rack: the right stick pushed left gives the blaster away")
	n = 0
	while nerf.war_t > 0.0 and n < 4500:
		await process_frame
		n += 1
		if cards.is_open:
			await _answer_cards()
	_check(nerf.war_t <= 0.0, "rack: the war ends (%s)" % _state())
