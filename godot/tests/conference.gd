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


func _fake(role: String) -> Node:
	var n := Node.new()
	n.set_meta("x", 0)
	n.set_script(load("res://tests/fake_npc.gd"))
	n.role = role
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cf := root.get_node("Expo")
	var cards := root.get_node("Cards")
	var sk := root.get_node("Skills")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	c.save_prefix = "user://test_"
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
	game.go("breakout_room", "from_hall")
	await _wait(1.0)
	_check(cards.is_open and cf.picks.size() == 1, "walking into room A starts that session")
	cards.pick(0)
	_check(
		sk.ps_level == ps0 + 1 and cf.rnd == 1,
		"the scripting lab teaches PowerShell and round 2 opens"
	)
	game.go("resort_hall", "from_a")
	await _wait(1.0)
	var sec0: int = int(sk.xp.security)
	game.vars["conf_door"] = "from_b"
	game.go("breakout_room", "from_hall")
	await _wait(1.0)
	cards.pick(0)
	_check(int(sk.xp.security) > sec0 and cf.rnd == 2, "the security session gives experience")
	game.go("resort_hall", "from_b")
	await _wait(1.0)
	game.vars["conf_door"] = "from_d"
	game.go("breakout_room", "from_hall")
	await _wait(1.5)
	_check(
		_scene() == "breakout_room" and cards.is_open and cf.picks.size() == 3,
		"room D of round 3 is a session now"
	)
	cards.pick(0)
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
