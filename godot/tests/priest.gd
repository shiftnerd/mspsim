extends SceneTree
# gdlint:disable=max-line-length
# Priest Michael (expo_priest, nick MPriest), the first LabRat Nerds forum regular at Rodent Nation (R28): the sheets and the hands
# json in both facings, his place in the hall crowd, his chat (once per trip, four options with real effects, Free Play) and his
# IRC nick with a blessing at the end of his answers.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


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
	var nerds := root.get_node("Nerds")
	var social := root.get_node("Social")

	# the character: both facings, the standard animations, the sheet of 129 frames and the 129 hand rows
	var frames: SpriteFrames = load("res://characters/expo_priest.tres")
	_check(frames != null, "expo_priest has a SpriteFrames")
	var intern: SpriteFrames = load("res://characters/office_intern.tres")
	for side in ["right", "left"]:
		var ok := frames != null
		for anim in ["idle", "walk", "run", "sit", "type", "dance", "crouch", "wave", "talk"]:
			ok = ok and frames.has_animation("%s_%s" % [anim, side])
		_check(ok, "expo_priest plays the standard animations facing %s" % side)
		var total := 0
		var total_intern := 0
		for anim in frames.get_animation_names():
			total += frames.get_frame_count(anim)
		for anim in intern.get_animation_names():
			total_intern += intern.get_frame_count(anim)
		_check(
			total == total_intern,
			"expo_priest has the same number of frames as the intern (%d)" % total
		)
		var sheet := Image.load_from_file(
			ProjectSettings.globalize_path("res://assets/characters/expo_priest_%s.png" % side)
		)
		_check(
			sheet != null and sheet.get_width() == 129 * 64 and sheet.get_height() == 80,
			"the %s sheet is 129 frames of 64x80" % side
		)
		var f := FileAccess.open(
			"res://assets/characters/expo_priest_%s_hands.json" % side, FileAccess.READ
		)
		var rows: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_check(rows is Array and rows.size() == 129, "the %s hands json has 129 rows" % side)

	# the hall crowd: he stands clear of the four doors and the easels, and nobody from a client site is in the venue
	var spot: Dictionary = {}
	for entry in cf.CROWD.resort_hall:
		if str(entry.who) == "expo_priest":
			spot = entry
	_check(
		not spot.is_empty() and str(spot.role) == "forum:priest",
		"the hall crowd has Priest Michael with the role forum:priest"
	)
	for door in [49, 119, 189, 259]:
		_check(
			absf(float(spot.get("x", 0)) - float(door)) >= 25.0,
			"he does not stand in front of the door at x %d" % door
		)
	var clients := []
	for room in cf.CROWD:
		for entry in cf.CROWD[room]:
			if str(entry.who).begins_with("client_"):
				clients.append(str(entry.who))
	_check(clients.is_empty(), "no client_* person in the venue (%s)" % str(clients))
	_check(
		not cf.forum_def("priest").is_empty() and cf.forum_def("priest").options.size() == 4,
		"his chat has four options"
	)
	_check(cf.forum_def("nobody").is_empty(), "an unknown forum id has no chat")

	# the chat in a campaign: the confession, once per trip
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	cf.reset()
	var servers0: int = int(sk.xp.servers)
	cf.npc_use(_fake("forum:priest"), null)
	_check(
		cards.is_open and cards.options.size() == 4 and cards.speaker.begins_with("MPriest"),
		"E opens his card with four options"
	)
	cards.pick(0)  # CONFESS A SYSADMIN SIN
	_check(
		int(sk.xp.servers) == servers0 + 4 and cards.text.contains("restore"),
		"the confession is a tip about restores (+4 servers XP)"
	)
	cards.pick(0)
	cf.npc_use(_fake("forum:priest"), null)
	_check(
		cards.is_open and cards.options.size() == 1 and cards.text == str(cf.TEXT.chat_again),
		"he is only good for one chat per trip"
	)
	cards.pick(0)
	var servers1: int = int(sk.xp.servers)
	cf.reset()  # a new trip
	var security0: int = int(sk.xp.security)
	cf.npc_use(_fake("forum:priest"), null)
	cards.pick(1)  # BLESS MY FRESH BACKUP
	_check(
		int(sk.xp.security) == security0 + 3 and int(sk.xp.servers) == servers1,
		"the blessing is +3 security XP"
	)
	cards.pick(0)
	cf.reset()
	var karma0: int = nerds.karma
	cf.npc_use(_fake("forum:priest"), null)
	cards.pick(2)  # ASK ABOUT THE FORUM
	_check(
		nerds.karma == karma0 + 3 and cards.text.contains("pins"),
		"asking about the forum gives +3 karma in a campaign"
	)
	cards.pick(0)
	cf.reset()
	var who: String = str(social.people()[0])
	social.rel[who] = 0
	cf.npc_use(_fake("forum:priest"), null)
	cards.pick(3)  # ASK ABOUT YOUR CREW
	_check(social.value(who) == 1, "his crew advice makes the coworkers like you a little more")
	cards.pick(0)

	# Free Play: no karma and no opinion, and the text does not promise them
	cf.reset()
	c.active = false
	karma0 = nerds.karma
	cf.npc_use(_fake("forum:priest"), null)
	cards.pick(2)
	_check(
		nerds.karma == karma0 and not cards.text.contains("karma"),
		"in Free Play there is no karma and the card does not claim any"
	)
	cards.pick(0)
	c.active = true

	# the IRC channel: nine nicks, four answer, and MPriest ends with a blessing
	_check(
		nerds.NICKS.has("MPriest") and nerds.NICKS.size() == 9,
		"MPriest is one of nine voices in #labratnerds"
	)
	var blessed := 0
	for i in 40:
		nerds.karma = 40
		nerds._lines = []
		nerds._last_ask = -999.0
		nerds.ask("which?", ["A", "B", "C", "D"], 1)
		if i == 0:
			_check(nerds._lines.size() == 4, "still four answers")
		for line in nerds._lines:
			if str(line[1]) == "MPriest":
				var ends := false
				for b in nerds.BLESSINGS:
					ends = ends or str(line[2]).ends_with(str(b))
				blessed += 1 if ends else 0
	_check(blessed > 0, "MPriest answered with a blessing (%d times in 40 questions)" % blessed)

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
