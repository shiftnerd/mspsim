extends SceneTree
# gdlint:disable=max-line-length
# Rodent Nation: the KPI gate, the verdict, the trip (keynote, three rounds, hall, raffle) and the day report.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _scene() -> String:
	var sc := current_scene
	return "" if sc == null else sc.scene_file_path.get_file().get_basename()


# R23: sit down on the free chair of the breakout room and stay for the whole session (the first line plays out on its timer, the
# rest are skipped with the key's function); returns the number of lines the talk had
func _sit_through(cf: Node) -> int:
	var player: Node = current_scene.get_node("Actors/Player")
	var seat: Node = cf._free_seat()
	_check(seat != null and cf.seated.is_empty(), "%s has a free chair, and nothing starts before you sit" % _scene())
	if seat == null:
		return 0
	player.global_position = seat.global_position
	seat.use(player)
	await _wait(1.5)
	var game := root.get_node("Game")
	_check(str(player.state) == "sitting" and not cf.seated.is_empty() and game.ui_open, "sitting down starts the session and keeps you in the chair")
	var lines: int = cf.seated.lines.size()
	_check(lines >= 2 and cf.talk_line() != "" and cf._canvas.visible, "the talk is %d lines, shown one at a time: %s" % [lines, cf.talk_line()])
	var clock0: float = root.get_node("World").clock
	await _wait(cf.LINE_SECS + 0.4)
	_check(int(cf.seated.get("at", 0)) == 1 and root.get_node("World").clock > clock0, "a line lasts %.1f seconds and the clock runs" % cf.LINE_SECS)
	var guard := 0
	while not cf.seated.is_empty() and guard < 30:
		cf.talk_skip()
		guard += 1
	await _wait(1.2)
	_check(cf.seated.is_empty() and str(player.state) != "sitting" and not game.ui_open and not cf._canvas.visible, "when it is over you stand up")
	return lines


func _fake(role: String) -> Node:
	var n := Node.new()
	n.set_meta("x", 0)
	n.set_script(load("res://tests/fake_npc.gd"))
	n.role = role
	return n


# the speaker NPC of a breakout room must be fully visible from the chest up: nothing in front of him reaches above chest height
func _check_speaker(room: String) -> void:
	var speaker: Node = null
	for n in get_nodes_in_group("npcs"):
		if str(n.role) == "speaker":
			speaker = n
	_check(speaker != null, "%s has a speaker standing in it" % room)
	if speaker == null:
		return
	var in_front_ok := true
	for child in current_scene.get_node("Actors").get_children():
		if not (child is Sprite2D) or child.texture == null:
			continue
		if child.position.y < speaker.position.y:
			continue  # behind the speaker
		var top: float = child.position.y + child.offset.y
		var left: float = child.position.x
		var right: float = left + child.texture.get_width()
		if right > speaker.position.x - 10.0 and left < speaker.position.x + 10.0 and top < speaker.position.y - 45.0:
			in_front_ok = false
	_check(in_front_ok, "%s: nothing in front of the speaker rises above his chest" % room)
	# no chair sits where the speaker stands, and every prop chair has a seat beside it or is a back row chair
	var stray := 0
	for child in current_scene.get_node("Actors").get_children():
		if str(child.name).begins_with("chair_") and absf(child.position.x + 9.0 - speaker.position.x) < 14.0:
			stray += 1
	_check(stray == 0, "%s: no stray chair under the speaker" % room)


# four different rooms: separate scenes with their own background, props and seats, behind four different hall doors
func _check_rooms_distinct() -> void:
	var rooms := ["breakout_a", "breakout_b", "breakout_c", "breakout_d"]
	var seen_bg := {}
	var seen_props := {}
	for room in rooms:
		var scene: Node = load("res://scenes/%s.tscn" % room).instantiate()
		seen_bg[str(scene.get_node("Background").texture.resource_path)] = true
		var kinds := []
		for child in scene.get_node("Actors").get_children():
			kinds.append(str(child.name).rstrip("0123456789"))
		kinds.sort()
		seen_props[",".join(kinds)] = true
		scene.free()
	_check(seen_bg.size() == 4, "the four breakout rooms have four different backgrounds")
	_check(seen_props.size() == 4, "the four breakout rooms have different furniture")
	var hall: Node = load("res://scenes/resort_hall.tscn").instantiate()
	var targets := {}
	for door in hall.get_node("Interactables").get_children():
		if str(door.name).begins_with("DoorRoom"):
			targets[str(door.target_scene)] = true
	hall.free()
	_check(targets.size() == 4, "the four hall doors lead to four different rooms")
	for room in rooms:
		var scene: Node = load("res://scenes/%s.tscn" % room).instantiate()
		_check(scene.get_node_or_null("Fx/Screen") != null, "%s has a session screen" % room)
		scene.free()


# nobody from a client site works the conference: no client_* sprite in the crowd, the vendors or their looks
func _check_crowd_clean() -> void:
	var cf := root.get_node("Expo")
	var bad := []
	for room in cf.CROWD:
		for entry in cf.CROWD[room]:
			if str(entry.who).begins_with("client_"):
				bad.append("%s:%s" % [room, entry.who])
	for id in cf.Trip.VENDOR_LOOK:
		if str(cf.Trip.VENDOR_LOOK[id]).begins_with("client_"):
			bad.append("vendor:%s" % id)
	_check(bad.is_empty(), "no client_* person works the venue (%s)" % str(bad))
	var clerk := ""
	for entry in cf.CROWD.resort_lobby:
		if str(entry.role) == "checkin":
			clerk = str(entry.who)
	_check(clerk == "expo_regdesk", "the check-in clerk is the conference staffer (%s)" % clerk)
	# Priest Michael, the LabRat Nerds forum regular (tests/priest.gd has the rest), stands in the hall
	var priest := 0
	for entry in cf.CROWD.resort_hall:
		priest += 1 if str(entry.who) == "expo_priest" and str(entry.role) == "forum:priest" else 0
	_check(priest == 1, "Priest Michael stands in the hall")
	for room in ["breakout_a", "breakout_b", "breakout_c", "breakout_d"]:
		var speakers := 0
		for entry in cf.CROWD[room]:
			speakers += 1 if str(entry.role) == "speaker" else 0
		_check(speakers == 1, "%s has one speaker in the crowd" % room)
	# the attendee sprites still match the gender of their chat slot
	for room in cf.CROWD:
		for entry in cf.CROWD[room]:
			if str(entry.role).begins_with("att:"):
				var slot := int(str(entry.role).substr(4))
				var female: bool = ["expo_priya", "expo_tina"].has(str(entry.who))
				_check(female == (cf.Trip.SLOT_GENDER[slot] == "f"), "%s: %s fits chat slot %d" % [room, entry.who, slot])


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cf := root.get_node("Expo")
	var cards := root.get_node("Cards")
	var sk := root.get_node("Skills")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)

	# the KPI gate
	cf.tot_closed = 20
	cf.tot_missed = 2
	cf.tot_reopened = 1
	c.rep = 70
	sk.ps_level = 2
	_check(cf.passed() == 4, "a good record meets all four KPIs")
	cf.tot_missed = 10
	sk.ps_level = 0
	c.rep = 40
	_check(cf.passed() == 1, "a poor one meets only one (%d)" % cf.passed())

	# day 8 invite, day 16 verdict
	c.day = cf.INVITE_DAY
	world.clock = 10.5
	var mails0: int = msp.emails.size()
	cf._process(0.0)
	_check(
		cf.invited and msp.emails.size() == mails0 + 1, "day 8: Morgan's mail announces the trip"
	)
	cf.tot_missed = 2
	c.rep = 70
	sk.ps_level = 2
	c.day = cf.VERDICT_DAY
	world.clock = 9.5
	cf._process(0.0)
	_check(cf.decided and cf.qualified, "day 16: the verdict says you go")
	_check(
		cf.is_trip_day(cf.TRIP_DAY) and not cf.is_trip_day(cf.TRIP_DAY - 1),
		"the trip is on day 17 only"
	)

	# the trip is walked through the venue
	var game := root.get_node("Game")
	cf._on_day(cf.TRIP_DAY)
	c.day = cf.TRIP_DAY
	_check(
		cf.away and cards.is_open and not msp.enabled, "day 17: you are away, the office is quiet"
	)
	cards.pick(0)  # fly out
	await _wait(1.0)
	_check(_scene() == "resort_lobby" and cf._stage == "keynote", "you land in the resort lobby")
	game.go("ballroom", "from_lobby")
	await _wait(1.0)
	_check(
		cards.is_open and cards.speaker == "Usher", "no badge, no keynote: the usher sends you back"
	)
	cards.pick(0)
	await _wait(1.0)
	cf.npc_use(_fake("checkin"), null)
	_check(cards.is_open and cf.badge, "the registration desk hands you a badge")
	cards.pick(0)
	game.go("ballroom", "from_lobby")
	await _wait(1.0)
	_check(_scene() == "ballroom" and cards.is_open, "with a badge the keynote starts")
	cards.pick(0)  # listen
	cards.pick(0)  # on to the sessions
	_check(cf._stage == "round" and cf.rnd == 0, "then the breakout rounds begin")
	game.go("resort_hall", "from_lobby")
	await _wait(1.0)
	_check(cf.sign_lines(0).size() > 0, "the easels in the hall show the round's sessions")
	var ps0: int = sk.ps_level
	game.vars["conf_door"] = "from_a"
	game.go("breakout_a", "from_hall")
	await _wait(1.0)
	_check(cards.is_open and cards.speaker == "SALON A" and cf.picks.size() == 0, "walking into room A offers the session: the card is the choice")
	_check(str(cards.text).contains("SCRIPTING 101") and cards.options.size() == 2, "the card names the session and the speaker")
	var info_a: Dictionary = cf.room_info(0)
	_check(
		str(info_a.id) == "ps101" and int(info_a.round) == 1 and str(info_a.time) == "10:00 AM",
		"room A's screen shows the session behind door A (id, round, time)"
	)
	_check(info_a.title.size() > 0 and str(info_a.speaker[0]) != "", "the screen has a title and a speaker")
	_check_speaker("breakout_a")
	cards.pick(0)  # take a seat
	_check(not cards.is_open and cf.picks.size() == 0 and sk.ps_level == ps0, "TAKE A SEAT: nothing is learned until you have sat through it")
	await _sit_through(cf)
	_check(cf.picks.size() == 1 and not cards.is_open, "the session counts once it is over, without a card")
	_check(cf.room_info(0).id == "ps101", "the screen keeps your session after the talk (the round moved on)")
	_check(
		sk.ps_level == ps0 + 1 and cf.rnd == 1,
		"the scripting lab teaches PowerShell and round 2 opens"
	)
	game.go("resort_hall", "from_a")
	await _wait(1.0)
	var sec0: int = int(sk.xp.security)
	game.vars["conf_door"] = "from_b"
	game.go("breakout_b", "from_hall")
	await _wait(1.0)
	var menu1: Array = cf.menu(1)
	_check(
		str(cf.room_info(1).id) == str(menu1[1].id) and cf.room_info(1).round == 2,
		"room B's screen shows the round 2 session behind door B (%s)" % str(menu1[1].id)
	)
	_check(
		cf.room_info(0, 22).title != cf.room_info(1, 22).title,
		"rooms A and B show different sessions"
	)
	_check_speaker("breakout_b")
	cards.pick(1)  # try another room
	await _wait(1.0)
	_check(_scene() == "resort_hall" and cf.picks.size() == 1 and cf.rnd == 1, "TRY ANOTHER ROOM: back in the hall, nothing picked")
	game.go("breakout_b", "from_hall")
	await _wait(1.0)
	_check(cards.is_open and cards.speaker == "SALON B", "walking back in offers it again")
	cards.pick(0)
	await _sit_through(cf)
	_check(int(sk.xp.security) > sec0 and cf.rnd == 2, "the security session gives experience")
	_check(is_equal_approx(world.clock, cf.CLOCKS[2]), "and the clock is at the next round")
	game.go("resort_hall", "from_b")
	await _wait(1.0)
	game.vars["conf_door"] = "from_d"
	game.go("breakout_d", "from_hall")
	await _wait(1.5)
	_check(
		_scene() == "breakout_d" and cards.is_open and cards.speaker == "SALON D",
		"room D of round 3 is a session now"
	)
	_check_speaker("breakout_d")
	cards.pick(0)
	await _sit_through(cf)
	_check(cf.picks.size() == 3, "three sessions sat through")
	_check(cf.room_info(3).id == "stay" or cf.room_info(3).id == cf.picks[2], "room D's screen shows the session you picked")
	await _check_rooms_distinct()
	_check_crowd_clean()
	_check(cf._stage == "raffle", "then it is time for the raffle")
	game.go("vendor_hall", "from_hall")
	await _wait(1.0)
	var karma0: int = root.get_node("Nerds").karma
	cf.booth("nerds")
	await _wait(0.5)
	_check(
		cards.is_open and root.get_node("Nerds").karma == karma0 + 4,
		"the vendor hall is open any time: a booth gives karma"
	)
	cards.pick(0)
	game.go("ballroom", "from_lobby")
	await _wait(1.0)
	_check(cards.is_open and cards.options[0].label == "FLY HOME", "the raffle ends the day")
	cards.pick(0)
	_check(
		msp.enabled and world.clock >= world.DAY_END,
		"back to normal and the clock jumps to closing"
	)
	var r: Dictionary = c.make_report()
	_check(r.grade == "A" and r.pay == 150 and r.rep_delta >= 2, "the trip day pays a per diem")
	_check(cf.went and cf.picks.size() == 3, "the picks are recorded")
	# the day report would open at closing and queue every later card behind it: keep the day open
	world.clock = 12.0

	# vendors pitch, attendees chat, the crowd is in the room
	game.go("vendor_hall", "from_hall")
	await _wait(1.0)
	var vendors := 0
	for n in get_nodes_in_group("npcs"):
		vendors += 1 if str(n.role).begins_with("vendor:") else 0
	_check(vendors == 3, "three vendors work the booths (%d)" % vendors)
	var sec1: int = int(sk.xp.security)
	cf.npc_use(_fake("vendor:backup"), null)
	_check(
		cards.is_open and cards.options.size() == 4, "a vendor pitches you with four ways to answer"
	)
	cards.pick(0)  # the demo
	cards.pick(0)
	_check(int(sk.xp.security) > sec1, "the demo teaches something")
	cf.npc_use(_fake("vendor:webwoot"), null)
	cards.pick(2)  # scan the badge
	cards.pick(0)
	_check(cf.spam == 1 and cf.entries == 1, "scanning your badge gets you on the mailing list")
	var karma1: int = root.get_node("Nerds").karma
	cf.npc_use(_fake("att:0"), null)
	cards.pick(1)  # swap cards
	cards.pick(0)
	_check(
		cf.cards_swapped == 1 and root.get_node("Nerds").karma == karma1 + 2,
		"swapping business cards"
	)
	var mails1: int = msp.emails.size()
	cf._home()
	_check(msp.emails.size() > mails1, "the vendors follow up by email")

	# saving
	var data: Dictionary = cf.to_dict()
	cf.reset()
	cf.from_dict(data)
	_check(cf.went and cf.qualified and cf.picks.size() == 3, "the trip is saved")

	# missed KPIs: Dan goes and brings back a tip
	cf.reset()
	cf.decided = true
	cf.qualified = false
	var net0: int = int(sk.xp.networking)
	c.day = cf.TRIP_DAY + 1
	cf._on_day(cf.TRIP_DAY + 1)
	_check(int(sk.xp.networking) == net0 + 6, "when you stay home Dan comes back with a tip")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
