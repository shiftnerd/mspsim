extends SceneTree
# Team outings: the invitation, the four mini-games (bowling, karaoke, escape room, dinner), what
# they change in each mode. Headless: the games are driven through their public functions.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var world := root.get_node("World")
	var owner := root.get_node("Owner")
	var shift := root.get_node("Shift")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_"
	game.title_mode = false
	o.enabled = true
	c.new_game("tech")
	world.time_scale = 1.0

	# ---- bowling
	o.start("bowling")
	_check(
		o.is_open and o.phase == "intro" and world.time_scale == 0.0 and game.ui_open,
		"an outing freezes the office"
	)
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o.g.frame == 1, "bowling starts")
	var before: int = social.value("Alan")
	var guard := 0
	while o.phase == "play" and guard < 40:
		o.g.marker = 0.5
		o.press(KEY_SPACE)
		o.g.power = 0.85
		o.press(KEY_SPACE)
		o.tick(2.0)
		o.tick(2.0)
		if o.phase == "play" and o.g.stage == "pause":
			o.tick(2.0)
		guard += 1
	_check(
		o.phase == "result" and o.stars >= 2,
		"perfect bowling wins: %d stars, total %d" % [o.stars, o.g.totals["You"]]
	)
	_check(social.value("Alan") > before and o.count == 1, "a good night out makes friends")
	_check(o.best["bowling"] == o.stars, "best score is remembered")
	o.press(KEY_ENTER)
	_check(
		not o.is_open and world.time_scale == 1.0 and not game.ui_open,
		"closing gives the office back"
	)

	var avg_bad := 0.0
	for i in 12:
		o.start("bowling")
		o.press(KEY_ENTER)
		guard = 0
		while o.phase == "play" and guard < 40:
			o.g.marker = 0.0
			o.press(KEY_SPACE)
			o.g.power = 0.0
			o.press(KEY_SPACE)
			o.tick(2.0)
			o.tick(2.0)
			if o.phase == "play" and o.g.stage == "pause":
				o.tick(2.0)
			guard += 1
		avg_bad += float(o.stars)
		o.press(KEY_ENTER)
	_check(avg_bad / 12.0 < 1.5, "gutter balls lose (average %.1f stars)" % (avg_bad / 12.0))

	# ---- karaoke
	o.start("karaoke")
	o.press(KEY_ENTER)
	_check(o.g.notes.size() == 24, "a 24 note song")
	var perfect := 0
	for n in o.g.notes:
		o.g.t = n.time
		var lane: int = n.lane
		perfect += 1 if o.kara_hit(lane) == "perfect" else 0
	_check(perfect == 24 and o.g.score == 48, "hitting every note on time is a perfect set")
	o.g.t = 100.0
	o.tick(0.1)
	_check(o.phase == "result" and o.stars == 3, "3 stars for a flawless song")
	o.press(KEY_ENTER)
	o.start("karaoke")
	o.press(KEY_ENTER)
	o.g.t = o.g.notes[0].time + 0.2
	_check(o.kara_hit((o.g.notes[0].lane + 1) % 4) == "", "the wrong arrow does nothing")
	o.g.t = o.g.notes[0].time + 0.2
	_check(o.kara_hit(o.g.notes[0].lane) == "good", "a little late is only good")
	o.tick(60.0)
	_check(
		o.phase == "result" and o.stars == 0 and o.g.miss >= 20,
		"standing there with the microphone: 0 stars"
	)
	o.press(KEY_ENTER)

	# ---- escape room
	for who in social.PEOPLE:
		social.rel[who] = 0
	social.rel["Alan"] = 60
	social.rel["Dan"] = 40
	o.start("escape")
	o.press(KEY_ENTER)
	_check(o.g.hints == 2, "two friends = two hints")
	o.g.code = [1, 2, 3]
	_check(o.escape_score([3, 2, 0]) == [1, 1], "bulls and cows")
	_check(o.escape_score([4, 5, 6]) == [0, 0], "nothing in common")
	_check(o.escape_score([3, 1, 2]) == [0, 3], "right digits, wrong places")
	var hint: String = o.escape_hint()
	_check(hint.contains("SLOT") and o.g.hints == 1 and o.g.revealed.size() == 1, "a hint: " + hint)
	o.press(KEY_UP)
	o.escape_try([1, 2, 3])
	_check(o.phase == "result" and o.stars == 3, "cracked on the first try with a hint: 3 stars")
	o.press(KEY_ENTER)
	o.start("escape")
	o.press(KEY_ENTER)
	o.g.code = [1, 2, 3]
	for i in 6:
		o.escape_try([9, 8, 7])
	o.escape_try([1, 2, 3])
	_check(o.phase == "result" and o.stars == 1, "seventh try: just made it, 1 star")
	o.press(KEY_ENTER)
	o.start("escape")
	o.press(KEY_ENTER)
	o.g.code = [1, 2, 3]
	for i in 8:
		o.escape_try([9, 8, 7])
	_check(o.phase == "result" and o.stars == 0, "eight wrong guesses: locked in")
	o.press(KEY_ENTER)
	o.start("escape")
	o.press(KEY_ENTER)
	o.tick(121.0)
	_check(o.phase == "result" and o.stars == 0, "time runs out")
	o.press(KEY_ENTER)

	# ---- dinner
	social.rel["Alan"] = 0
	var best_score := 0
	o.start("dinner")
	o.press(KEY_ENTER)
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
		best_score += o.dinner_talk(pick)
		o.tick(2.0)
	_check(
		o.phase == "result" and o.stars >= 2,
		"good conversation: %d of 30, %d stars" % [best_score, o.stars]
	)
	_check(
		(
			(
				o.known["Alan"].likes.size()
				+ o.known["Garrison"].likes.size()
				+ o.known["Dan"].likes.size()
			)
			>= 2
		),
		"you learn what they like"
	)
	o.press(KEY_ENTER)
	o.start("dinner")
	o.press(KEY_ENTER)
	for round_no in 5:
		var worst := 0
		var low := 99
		for i in 4:
			var pts := 0
			for who in o.DINERS:
				if o.LOVES[who].has(o.g.options[i]):
					pts += 2
				elif o.HATES[who] != o.g.options[i]:
					pts += 1
			if pts < low:
				low = pts
				worst = i
		o.dinner_talk(worst)
		o.tick(2.0)
	_check(
		o.phase == "result" and o.stars <= 1, "talking about the wrong things: %d stars" % o.stars
	)
	o.press(KEY_ENTER)

	# ---- leaving early
	social.rel["Garrison"] = 20
	o.start("bowling")
	o.press(KEY_ENTER)
	o.press(KEY_ESCAPE)
	_check(
		o.phase == "result" and o.stars == -1 and social.value("Garrison") == 19,
		"leaving early costs goodwill"
	)
	o.press(KEY_ENTER)

	# ---- tech invitations
	c.new_game("tech")
	world.time_scale = 1.0
	c.day = 6
	world.clock = 16.2
	o.maybe_invite()
	_check(not cards.is_open, "no invitation on a normal day")
	c.day = 5
	social.rel["Alan"] = 10
	o.maybe_invite()
	_check(
		cards.is_open and cards.options.size() == 2 and cards.speaker.contains("Garrison"),
		"Friday: Garrison invites you"
	)
	cards.pick(1)
	_check(o.skipped == 1 and social.value("Alan") == 9, "saying no costs a little goodwill")
	o.maybe_invite()
	_check(not cards.is_open, "only one invitation a day")
	_check(not o.invite_due(), "after the invitation the day is free to end")
	o._offered = false
	world.clock = 17.4
	_check(o.invite_due(), "a trip that gets you home after five still owes you the invitation")
	o.maybe_invite()
	_check(cards.is_open and cards.speaker.contains("Garrison"), "and it is offered late")
	cards.pick(1)
	world.clock = 16.2
	o._offered = false
	o.maybe_invite()
	cards.pick(0)
	_check(cards.is_open and cards.options.size() == 4, "then the four activities")
	var energy0: float = shift.energy
	cards.pick(0)
	_check(o.is_open and o.game == "bowling" and o._from_invite, "off to bowling")
	o.press(KEY_ENTER)
	o._finish(3)
	_check(shift.energy > energy0, "tech: a night out gives energy")
	o.press(KEY_ENTER)
	_check(
		world.clock >= world.DAY_END and shift._asked,
		"the evening is gone: the day ends, no stay-late offer"
	)

	# ---- owner invitations cost money
	c.new_game("owner")
	world.time_scale = 1.0
	c.day = 4
	world.clock = 16.2
	owner.cash = 5000
	owner.burnout = 30.0
	o.maybe_invite()
	cards.pick(0)
	_check(cards.options[3].label.contains("$300"), "the owner sees prices")
	cards.pick(2)
	_check(owner.cash == 5000 - 240 and o.game == "escape", "the escape room costs $240")
	o.press(KEY_ENTER)
	o.g.code = [4, 5, 6]
	o.escape_try([4, 5, 6])
	_check(
		o.stars == 3 and owner.burnout < 30.0 and owner.flags["outings"] == 1,
		"burnout drops after a great night"
	)
	_check(owner.speed > 1.0, "the escape room builds teamwork")
	o.press(KEY_ENTER)
	owner.cash = 130
	o._offered = false
	world.clock = 16.2
	o.maybe_invite()
	cards.pick(0)
	var broke := not bool(cards.options[1].get("enabled", true))
	cards.pick(0)
	_check(broke, "karaoke is greyed out when you cannot afford it")
	o.press(KEY_ESCAPE)
	_check(owner.cash == 130, "leaving before you start refunds the money")
	o.press(KEY_ENTER)

	# ---- free play: the O key
	c.new_game(c.FREE)
	world.time_scale = 1.0
	o._unhandled_input(_key(KEY_O))
	_check(cards.is_open and cards.speaker == "Team outing", "free play: O offers an outing")
	cards.pick(0)
	cards.pick(3)
	_check(o.is_open and o.game == "dinner", "free play outing starts")
	var al: int = social.value("Alan")
	o._finish(3)
	_check(social.value("Alan") == al, "free play changes nothing")
	o.press(KEY_ENTER)

	# ---- saving
	o.count = 4
	o.known = {"Alan": {"likes": ["FOOD"], "hates": []}}
	o.skipped = 2
	var data: Dictionary = o.to_dict()
	o.reset()
	o.from_dict(data)
	_check(o.count == 4 and o.skipped == 2 and o.known.has("Alan"), "outings are saved")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
