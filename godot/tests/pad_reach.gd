extends SceneTree
# gdlint:disable=max-line-length
# R42 Steam Deck, the pad-only gaps of the controls batch. Pad events go through Input.parse_input_event.
#   gestures       the right stick: up dances, down asks a coworker to follow, right mutes, left gives the blaster away
#   blaster        the first player's pad: RT fires, RB / LB move the pick arrow, Y offers a war (they were keyboard only)
#   hints          Controls.label and the key list show the pad's buttons for those; an axis event is one direction only
#   escape room    the page game's hint key (H) has a pad twin (Y)
#   karaoke        a pad lets go of a hold note (a D-pad button released)
#   cards          A answers a card without also making you jump or stand up
#   reach          every click region of every Computer app and every phone screen takes the cursor with RB (the focus
#                  cycle), so A can press it: no button is mouse only. Screens are set up as tests/layout_audit.gd does.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/pad_reach.gd

var failures := 0
var screens := 0
var regions := 0
var comp: Node
var phone: Node
var cards: Node
var ctl: Node


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


func _button(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
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


func _flick(axis: JoyAxis, value: float, after := 3) -> void:
	_axis(axis, value)
	await _wait(3)
	_axis(axis, 0.0)
	await _wait(after)


func _under(scr: Node) -> String:
	for i in range(scr._hits.size() - 1, -1, -1):
		if scr._hits[i].r.has_point(scr._mouse):
			return str(scr._hits[i].id)
	return ""


# RB through the whole screen: every region id must come under the cursor once. Returns the ids that never did.
func _sweep(scr: Node, label: String, expect_some := true) -> void:
	scr._canvas.queue_redraw()
	await _wait(3)
	var want := {}
	for h in scr._hits:
		if (h.r as Rect2).size.x > 0.0 and (h.r as Rect2).size.y > 0.0 and str(h.id) != "none":  # ("none" only blocks a click)
			want[str(h.id)] = true
	var seen := {}
	var view: Rect2 = root.get_visible_rect()
	var off := []
	for i in scr._hits.size() + 2:
		await _tap(JOY_BUTTON_RIGHT_SHOULDER, 1)
		var id := _under(scr)
		if id != "":
			seen[id] = true
		if not view.has_point(scr._mouse):
			off.append(id)
	var missed := []
	for id in want:
		if not seen.has(id):
			missed.append(id)
	screens += 1
	regions += want.size()
	var enough: bool = not expect_some or not want.is_empty()
	_check(missed.is_empty() and off.is_empty() and enough, "%s: RB reaches all %d regions%s%s" % [label, want.size(), "" if missed.is_empty() else ", NOT " + str(missed), "" if off.is_empty() else ", off screen " + str(off)])


func _new_game(mode: String, character: String) -> void:
	var c := root.get_node("Campaign")
	root.get_node("Game").title_mode = false
	load("res://scripts/player.gd").current_character = character
	c.new_game(mode)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(40)
	var guard := 0
	while cards.is_open and guard < 40:
		cards.pick(0)
		guard += 1
		await _wait(2)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var game := root.get_node("Game")
	var camp := root.get_node("Campaign")
	var world := root.get_node("World")
	var sfx := root.get_node("Sfx")
	var nerf := root.get_node("Nerf")
	var out := root.get_node("Outings")
	var msp := root.get_node("Msp")
	comp = root.get_node("Computer")
	phone = root.get_node("Phone")
	cards = root.get_node("Cards")
	ctl = root.get_node("Controls")
	var pid := OS.get_process_id()
	camp.save_prefix = "user://test_%d_padreach_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_padreach_settings.cfg" % pid
	sfx.settings_path = "user://test_%d_padreach_settings.cfg" % pid
	ctl.binds_path = "user://test_%d_padreach_controls.cfg" % pid
	phone.save_path = "user://test_%d_padreach_phone.cfg" % pid

	# ---- the right stick: gestures -------------------------------------------------------------------------------------
	game.title_mode = false
	camp.new_game(camp.FREE)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(40)
	var p := current_scene.get_node("Actors/Player")
	await _flick(JOY_AXIS_RIGHT_Y, -1.0, 6)
	_check(p.state == "dance", "the right stick pushed up starts the dance (%s)" % p.state)
	await _flick(JOY_AXIS_RIGHT_Y, -1.0, 6)
	_check(p.state != "dance", "and again ends it (%s)" % p.state)
	var muted: bool = sfx.muted
	await _flick(JOY_AXIS_RIGHT_X, 1.0)
	_check(sfx.muted != muted, "the right stick pushed right mutes the sound")
	await _flick(JOY_AXIS_RIGHT_X, -1.0)
	_check(sfx.muted != muted, "pushed left it does not (that is give)")
	await _flick(JOY_AXIS_RIGHT_X, 1.0)
	_check(sfx.muted == muted, "right again: sound back on")
	# follow: next to a coworker who is on their feet, the right stick pushed down
	world.force_activity("Dan", "coffee")
	var mate: Node = world.chars["Dan"].node
	var guard := 0
	while mate != null and is_instance_valid(mate) and not mate._can_chat() and guard < 900:
		await process_frame
		guard += 1
	_check(mate != null and is_instance_valid(mate) and mate._can_chat(), "Dan is on his way to the coffee")
	if mate != null and is_instance_valid(mate):
		for turn in 2:
			guard = 0
			p.global_position.x = mate.global_position.x + 14.0
			await _wait(6)
			while (mate._hold > 0.0 or not mate._can_chat()) and guard < 600:  # he may be waving back: wait until he is free
				await process_frame
				guard += 1
			p.global_position.x = mate.global_position.x + 14.0
			await _wait(6)
			await _flick(JOY_AXIS_RIGHT_Y, 1.0, 10)
			if turn == 0:
				_check(mate.following, "the right stick pushed down asks him to follow")
			else:
				_check(not mate.following, "and again lets him go")
	# ---- the blaster on the first player's pad
	p.give("nerf")
	await _wait(3)
	await _tap(JOY_BUTTON_Y, 8)
	_check(cards.is_open and str(cards.speaker).to_upper().find("NERF") >= 0, "Y with the blaster offers a war: the card of games (%s)" % str(cards.speaker))
	guard = 0
	while cards.is_open and guard < 10:
		await _wait_ms(480)
		await _tap(JOY_BUTTON_DPAD_UP)  # up from the first row wraps to NEVER MIND
		await _tap(JOY_BUTTON_A, 6)
		guard += 1
	_check(not cards.is_open and nerf.war_t <= 0.0, "NEVER MIND closes it, no war")
	await _wait(10)
	if p._near.size() >= 2:
		var pick0: Node = p.nearest()
		await _tap(JOY_BUTTON_RIGHT_SHOULDER)
		_check(p.nearest() != pick0, "RB moves the pick arrow to the next thing in reach")
		await _tap(JOY_BUTTON_LEFT_SHOULDER)
		_check(p.nearest() == pick0, "LB moves it back")
	var shots: int = nerf._ammo[0]
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _wait(3)
	_check(nerf._charging[0], "RT held: the blaster is aimed")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait(2)
	_check(not nerf._charging[0] and (nerf._ammo[0] == shots - 1 or nerf._cools[0] > 0.0), "RT let go: a dart flies (%d -> %d darts)" % [shots, nerf._ammo[0]])
	await _wait(10)
	await _flick(JOY_AXIS_RIGHT_X, -1.0, 6)
	_check(str(p.held) == "", "the right stick pushed left gives the blaster away (%s)" % str(p.held))
	if sfx.muted != muted:
		sfx.toggle_mute()

	# ---- hints and labels ------------------------------------------------------------------------------------------------
	ctl.pad_active = true
	_check(ctl.label("dance") == "RS UP" and ctl.label("follow") == "RS DOWN" and ctl.label("give_item") == "RS LEFT" and ctl.label("mute") == "RS RIGHT", "labels: RS UP / DOWN / LEFT / RIGHT (%s)" % ctl.label("dance"))
	_check(ctl.help_value("DANCE", "X (FREE PLAY ENDS IT)") == "RS UP" and ctl.help_value("MUTE SOUND", "M") == "RS RIGHT", "the key list shows them on a pad")
	_check(ctl.help_value("START A WAR, GIVE", "V, G") == "(Y), RS LEFT" and ctl.help_value("WAVE", "Q") == "(Y)", "and the war / give / wave rows (%s)" % ctl.help_value("START A WAR, GIVE", "V, G"))
	_check(ctl.help_value("CAREER SCREEN", "J (FREE PLAY)") == "J (FREE PLAY)", "a row with no pad button keeps its text")
	ctl.pad_active = false
	_check(ctl.help_value("DANCE", "X (FREE PLAY ENDS IT)") == "X (FREE PLAY ENDS IT)" and ctl.label("dance") == ctl.key_name(KEY_X), "a keyboard sees the keys as before")
	var push := InputEventJoypadMotion.new()
	push.axis = JOY_AXIS_LEFT_X
	push.axis_value = -1.0
	_check(ctl.matches(push, "move_left") and not ctl.matches(push, "move_right"), "an axis event is the action of the side it is pushed to, not both")
	push.axis = JOY_AXIS_RIGHT_Y
	_check(ctl.matches(push, "dance") and not ctl.matches(push, "follow"), "the same on the right stick")

	# ---- a card: A answers and nothing else happens --------------------------------------------------------------------
	var seat: Node = current_scene.get_node("Interactables/Seat1")
	for who in ["Alan", "Garrison", "Dan", "John", "Maya", "Morgan"]:
		if world.chars.has(who):
			world.chars[who].scene = "office_two"
			world.force_activity(who, "work")
	await _wait(5)
	p.sit(seat)
	await _wait(120)
	_check(p.state == "sitting", "seated at a desk")
	var answers := []
	cards.ask("TEST", "PICK ONE.", [{"label": "FIRST", "id": "a"}, {"label": "SECOND", "id": "b"}], func(id: String) -> void: answers.append(id))
	await _wait_ms(480)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A, 30)
	_check(answers == ["b"] and p.state == "sitting" and p.seat == seat, "D-pad down and A answer the card; you stay in your chair (%s, %s)" % [str(answers), p.state])
	p._stand_up()
	await _wait(60)
	var y0: float = p.global_position.y
	cards.ask("TEST", "AGAIN.", [{"label": "OK", "id": "a"}], func(_id: String) -> void: pass)
	await _wait_ms(480)
	_button(JOY_BUTTON_A, true)
	var top := y0
	for i in 12:
		await process_frame
		top = minf(top, p.global_position.y)
	_button(JOY_BUTTON_A, false)
	await _wait(10)
	_check(not cards.is_open and top > y0 - 1.0, "standing: A closes the card and you do not jump (rose %.1f px)" % (y0 - top))
	await _tap(JOY_BUTTON_A, 2)
	top = y0
	for i in 14:
		await process_frame
		top = minf(top, p.global_position.y)
	_check(top < y0 - 3.0, "A afterwards jumps as always (rose %.1f px)" % (y0 - top))
	await _wait(40)

	# ---- the escape room's page game: Y is the hint key ------------------------------------------------------------------
	out.enabled = true
	out.start("escape", false, {"panel": true, "party": ["Alan", "Garrison", "Dan"]})
	await _wait(5)
	await _tap(JOY_BUTTON_A, 6)
	_check(out.is_open and out.phase == "play" and not out.room_mode(), "the escape room as a page game (%s)" % out.phase)
	var left: int = int(out.g.hints)
	await _tap(JOY_BUTTON_Y, 4)
	_check(int(out.g.hints) == left - 1, "Y asks for a hint (%d -> %d left)" % [left, int(out.g.hints)])
	ctl.pad_active = true
	_check(ctl.hint(out.hint(), {"N": "nudge", "E": "interact", "H": "nudge"}).find("(Y) = HINT") >= 0, "the footer names it: %s" % ctl.hint(out.hint(), {"N": "nudge", "E": "interact", "H": "nudge"}))
	ctl.pad_active = false
	await _tap(JOY_BUTTON_B, 6)
	await _tap(JOY_BUTTON_A, 6)
	_check(not out.is_open, "B leaves, A closes the result")

	# ---- karaoke: a pad lets go of a hold note ---------------------------------------------------------------------------
	out.start("karaoke", false, {"panel": true, "song": str(out.SONGS[0].id), "party": ["Alan", "Garrison", "Dan"]})
	await _wait(5)
	await _tap(JOY_BUTTON_A, 6)
	guard = 0
	while cards.is_open and guard < 6:
		cards.pick(0)
		guard += 1
		await _wait(3)
	_check(out.is_open and out.game == "karaoke" and out.phase == "play", "karaoke as a page game (%s)" % out.phase)
	if out.phase == "play":
		var note := {"time": float(out.g.t) + 5.0, "len": 4.0, "lane": 0, "state": "hit"}
		out.g["held"] = {0: {"note": note, "perfect": false}}
		_button(JOY_BUTTON_DPAD_LEFT, false)
		await _wait(3)
		_check(not (out.g.held as Dictionary).has(0), "letting the D-pad go ends the held note of that lane")
		out.g["held"] = {1: {"note": note, "perfect": false}}
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		await _wait(3)
		_check(not (out.g.held as Dictionary).has(1), "and so does the stick coming back to the middle")
	await _tap(JOY_BUTTON_B, 6)
	await _tap(JOY_BUTTON_A, 6)
	out.close()
	await _wait(5)

	# ---- reach: the Computer, tech campaign --------------------------------------------------------------------------------
	await _new_game("tech", "office_intern")
	camp.day = 3
	world.clock = 10.5
	for i in 3:
		msp.create_ticket(int(root.get_node("Sales").active[i % root.get_node("Sales").active.size()]), i, "phone")
	await _wait(10)
	comp.open(1)
	await _wait(15)
	for app in ["desktop", "mail", "psa", "rmm", "learn", "stats", "lync", "nerds", "dash", "shop"]:
		comp.app = app
		await _sweep(comp, "computer " + app, app != "stats")
	comp.app = "desktop"
	comp._menu = true
	await _sweep(comp, "computer start menu")
	comp._menu = false
	# sub-views
	comp.app = "mail"
	if not msp.emails.is_empty():
		comp.activate("mail:0")
		await _sweep(comp, "computer mail, one open")
	var tickets: Array = msp.open_tickets()
	_check(not tickets.is_empty(), "there are tickets to open")
	if not tickets.is_empty():
		comp.app = "psa"
		comp.activate("tk:%d" % int(tickets[0].id))
		await _sweep(comp, "computer ticket")
		comp.activate("close")
		_check(comp.close_ask, "CLOSE on an unfixed ticket asks first")
		await _sweep(comp, "computer ticket, close question")
		comp.close_ask = false
		comp.psa_detail = false
		var ep := str(tickets[0].endpoint)
		if ep != "" and not msp.endpoint(ep).is_empty():
			comp.app = "rmm"
			comp.rmm_open[int(msp.endpoint(ep).client)] = true
			await _sweep(comp, "computer rmm, a client unfolded")
			comp.activate("rmm:" + ep)
			await _sweep(comp, "computer rmm, a machine picked")
			comp.activate("connect")
			await _sweep(comp, "computer rmm session")
			comp.activate("disc")
	comp.app = "rmm"
	for tab in ["backups", "project", "endpoints"]:
		comp.activate("tab:" + tab)
		await _sweep(comp, "computer rmm tab " + tab)
	comp.app = "learn"
	comp._canvas.queue_redraw()
	await _wait(3)
	var lesson := ""
	for h in comp._hits:
		if str(h.id).begins_with("learn:") and lesson == "":
			lesson = str(h.id)
	if lesson != "":
		comp.activate(lesson)
		await _sweep(comp, "computer lesson (%s)" % lesson)
		comp.back()
	comp.app = "lync"
	comp._canvas.queue_redraw()
	await _wait(3)
	var contact := ""
	for h in comp._hits:
		if str(h.id).begins_with("lync:contact:") and contact == "":
			contact = str(h.id)
	if contact != "":
		comp.activate(contact)
		await _sweep(comp, "computer lynk conversation")
		comp.back()
	comp.app = "nerds"
	for tab in ["irc", "forum"]:
		comp._set_nerds_tab(tab)
		await _sweep(comp, "computer nerds " + tab)
	comp._set_nerds_tab("irc")
	for view in ["who", "topics", "join", "chat"]:
		comp.irc_view = view
		await _sweep(comp, "computer irc " + view, false)
	comp.close()
	await _wait(12)

	# ---- reach: the phone ----------------------------------------------------------------------------------------------------
	for skin in ["android", "ios"]:
		phone.os = skin
		phone.photos = []
		phone.open()
		await _wait(15)
		await _sweep(phone, "phone %s lock screen" % skin)
		phone.locked = false
		for app in ["home", "mail", "tickets", "texts", "settings", "phone", "camera"]:
			phone.app = app
			await _sweep(phone, "phone %s %s" % [skin, app])
		phone.app = "mail"
		if not msp.emails.is_empty():
			phone.activate("mail:0")
			await _sweep(phone, "phone %s mail, one open" % skin)
		phone.app = "tickets"
		if not msp.open_tickets().is_empty():
			phone.activate("tk:%d" % int(msp.open_tickets()[0].id))
			await _sweep(phone, "phone %s ticket" % skin)
			phone.tk_sel = -1
		phone.app = "texts"
		phone.activate("txt")
		await _sweep(phone, "phone %s texts, open" % skin, false)
		phone.txt_open = false
		phone.app = "phone"
		phone.activate("keypad")
		await _sweep(phone, "phone %s keypad" % skin)
		phone.activate("contacts")
		phone.app = "camera"
		phone.take_photo()
		phone.take_photo()
		for view in ["finder", "roll", "photo"]:
			phone.cam_view = view
			phone.cam_sel = 0
			await _sweep(phone, "phone %s camera %s" % [skin, view])
		phone.close()
		await _wait(12)
	phone.os = ""
	phone.open()
	await _wait(15)
	await _sweep(phone, "phone, the first choice of a phone")
	phone.close()
	phone.os = "android"
	await _wait(12)

	# ---- reach: the owner's Boardroom, the sales CRM, the service manager's Dispatch and Knowledge ----------------------
	await _new_game("owner", "office_alan")
	comp.open(1)
	await _wait(15)
	for tab in ["books", "clients", "projects", "team", "stack"]:
		comp.activate("app:boardroom")
		comp.activate("btab:" + tab)
		await _sweep(comp, "boardroom " + tab)
	comp.app = "desktop"
	await _sweep(comp, "owner desktop")
	comp.close()
	await _wait(12)
	await _new_game("sales", "office_john")
	comp.open(1)
	await _wait(15)
	comp.activate("app:crm")
	await _sweep(comp, "crm list", false)
	_check(comp.hot_keys().size() >= 1, "the CRM's letter keys are on the pad's hotkey strip (Y steps, X presses)")
	comp.close()
	await _wait(12)
	await _new_game("service", "office_dan")
	camp.day = 8
	comp.open(1)
	await _wait(15)
	comp.app = "dispatch"
	await _sweep(comp, "dispatch board", false)
	_check(comp.hot_keys().size() >= 5, "Dispatch: the letter keys are on the hotkey strip")
	comp.app = "knowledge"
	await _sweep(comp, "knowledge", false)
	_check(comp.hot_keys().size() >= 5, "Knowledge: the letter keys are on the hotkey strip")
	comp.app = "desktop"
	await _sweep(comp, "service desktop")
	comp.close()
	print("     %d screens, %d regions" % [screens, regions])
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
