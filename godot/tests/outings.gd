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
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	o.enabled = true
	c.new_game("tech")
	world.time_scale = 1.0
	root.get_node("Difficulty").seed_run(4240)  # pinned: the run seed must not change the order of the dependent outings

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
	for n in o.g.notes:
		n.erase("auto")  # these checks are about the classic song: a friendly party member would sing the right lanes (see karaoke_duet.gd)
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
	for n in o.g.notes:
		n.erase("auto")
	o.g.t = o.g.notes[0].time + 0.2
	_check(o.kara_hit((o.g.notes[0].lane + 1) % 4) == "", "the wrong arrow does nothing")
	o.g.t = o.g.notes[0].time + 0.2
	_check(o.kara_hit(o.g.notes[0].lane) == "good", "a little late is only good")
	o.tick(60.0)
	_check(
		o.phase == "result" and o.stars == 0 and o.g.miss >= 8,
		"standing there with the microphone: 0 stars"
	)
	o.press(KEY_ENTER)

	# ---- escape room
	for who in social.people():
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
	root.get_node("Difficulty").seed_run(4241)
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
				pts += o.diner_points(who, o.g.options[i])
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
				pts += o.diner_points(who, o.g.options[i])
			if pts < low:
				low = pts
				worst = i
		o.dinner_talk(worst)
		o.tick(2.0)
	_check(
		o.phase == "result" and o.stars <= 2, "talking about the wrong things: %d stars" % o.stars
	)
	o.press(KEY_ENTER)

	# ---- escape room: clue recipes, 3 or 4 digits, friend hints
	var dif := root.get_node("Difficulty")
	var recipes_seen := {}
	for tier in ["normal", "hard"]:
		dif.set_tier(tier)
		var want := 3 if tier == "normal" else 4
		for seed_n in 60:
			dif.seed_run(1000 + seed_n)
			o.game = "escape"
			o._escape_room_setup()
			var code: Array = o.g.code
			var answers := []
			for cl in o.g.clues:
				answers.append(o.clue_answer(cl))
				recipes_seen[cl.recipe] = true
			var distinct := true
			for i in code.size():
				distinct = (
					distinct
					and code.count(code[i]) == 1
					and int(code[i]) >= 1
					and int(code[i]) <= 9
				)
			if code.size() != want or o.g.clues.size() != want or answers != code or not distinct:
				_check(
					false, "%s seed %d: code %s clues %s" % [tier, seed_n, str(code), str(answers)]
				)
				break
		_check(
			o.g.code.size() == want and o.g.cur.size() == want, "%s: a %d digit code" % [tier, want]
		)
		_check(
			o.g.dial == (tier == "normal"),
			"%s: the dial lock %s" % [tier, "talks" if tier == "normal" else "is silent"]
		)
		# the overlay version has the same length
		o._escape_setup()
		_check(
			o.g.code.size() == want and o.g.cur.size() == want,
			"%s: the overlay code is %d digits too" % [tier, want]
		)
		var code2: Array = o.g.code.duplicate()
		_check(
			o.escape_score(code2) == [want, 0], "%s: bulls and cows with %d digits" % [tier, want]
		)
		var swapped := code2.duplicate()
		var tmp = swapped[0]
		swapped[0] = swapped[1]
		swapped[1] = tmp
		_check(o.escape_score(swapped) == [want - 2, 2], "%s: two digits swapped" % tier)
	_check(recipes_seen.size() == 10, "every recipe was dealt (%d of 10)" % recipes_seen.size())
	dif.set_tier("normal")
	dif.seed_run(12)
	o.start("escape")
	o.press(KEY_ENTER)
	for step in 4:
		o.press(KEY_RIGHT)
	_check(o.g.cursor == 1, "three digits: right x4 wraps to slot 2")
	o._finish(-1)
	o.press(KEY_ENTER)
	dif.set_tier("hard")
	o.start("escape")
	o.press(KEY_ENTER)
	for step in 4:
		o.press(KEY_RIGHT)
	_check(o.g.cursor == 0 and o.g.cur.size() == 4, "four digits: right x4 wraps all the way round")
	o.press(KEY_LEFT)
	_check(o.g.cursor == 3, "left from the first slot goes to the fourth")
	o.g.code = [1, 2, 3, 4]
	o.escape_try([1, 2, 3, 4])
	_check(o.phase == "result" and o.stars == 3, "a four digit code cracked first time")
	o.press(KEY_ENTER)
	dif.set_tier("normal")

	# friend hints: each friend speaks about the next clue in their own words
	dif.seed_run(77)
	o.start("escape")
	o.press(KEY_ENTER)
	for friend in ["Alan", "Garrison", "Dan", "Maya", "John"]:
		for who in social.people():
			social.rel[who] = 0
		social.rel[friend] = 60
		o._escape_room_setup()
		o.g.hints = 3
		var said: String = o.escape_nudge()
		var line: String = o.FRIEND_HINTS[friend]["board"]
		_check(
			said.begins_with(friend.to_upper() + ": ") and said.contains(line),
			"%s's hint about the chalkboard: %s" % [friend, said]
		)
		_check(
			(friend == "Alan") == said.contains(o.RECIPE_TIPS[o.g.clues[0].recipe]),
			"only Alan adds the recipe tip (%s)" % friend
		)
		o.g.found = [0, 1, 2]
		o.g.hints = 3
		said = o.escape_nudge()
		_check(
			said.contains(o.FRIEND_HINTS[friend]["keypad"]),
			"%s: all found, go to the keypad" % friend
		)
		if friend == "Garrison":
			_check(said.contains(o.RECIPE_TIPS["dial"]), "Garrison, the lock, explains the dial")
	for who in social.people():
		social.rel[who] = 0
	o._finish(-1)
	o.press(KEY_ENTER)

	# ---- dinner: a bigger pool, safe and trap topics, moods, tastes, the owner pays
	_check(o.TOPICS.size() >= 16, "%d dinner topics" % o.TOPICS.size())
	var rounds_ok := true
	var seen_topics := {}
	var moods_seen := {}
	for seed_n in 40:
		dif.seed_run(2000 + seed_n)
		o.reset()
		o.game = "dinner"
		o.phase = "play"
		o._dinner_setup()
		var used := []
		for round_no in 5:
			var opts: Array = o.g.options
			var traps := 0
			var safes := 0
			var uniq := {}
			for t in opts:
				seen_topics[t] = true
				uniq[t] = true
				traps += 1 if o.is_trap(t) else 0
				safes += 0 if o.is_trap(t) else 1
				rounds_ok = rounds_ok and not used.has(t)
			rounds_ok = (
				rounds_ok and opts.size() == 4 and traps >= 1 and safes >= 1 and uniq.size() == 4
			)
			used.append(opts[0])
			o.dinner_talk(0)
			o.tick(2.0)
		for who in o.DINERS:
			moods_seen[o.g.moods[who]] = true
	_check(
		rounds_ok, "every round: four different topics, one safe and one trap at least, no repeats"
	)
	_check(seen_topics.size() >= 16, "%d different topics came up" % seen_topics.size())
	_check(moods_seen.size() == 5, "all five moods of the day came up")
	# a mood shifts the points; the face still shows the taste
	dif.seed_run(5)
	o.reset()
	o._dinner_setup()
	var topic: String = o.g.options[0]
	var base := {}
	for who in o.DINERS:
		base[who] = o.taste_pts(who, topic)
	o.g.moods = {"Alan": "chatty", "Garrison": "tired", "Dan": "easygoing"}
	_check(
		(
			o.diner_points("Alan", topic) == clampi(base.Alan + 1, 0, 3)
			and o.diner_points("Garrison", topic) == clampi(base.Garrison - 1, 0, 3)
			and o.diner_points("Dan", topic) == base.Dan
		),
		"chatty +1, tired -1, easygoing 0"
	)
	var total: int = o.dinner_talk(0)
	_check(
		(
			total
			== (
				o.diner_points("Alan", topic)
				+ o.diner_points("Garrison", topic)
				+ o.diner_points("Dan", topic)
			)
		),
		"the table score adds the moods"
	)
	_check(
		o.g.react.Alan == ("love" if base.Alan == 2 else ("hate" if base.Alan == 0 else "meh")),
		"the face shows the taste, not the mood"
	)
	_check(
		o.dinner_targets()[0] == 22,
		"the 3 star bar follows the table's mood (chatty and tired cancel)"
	)

	# tastes: a per save shuffle of one or two, kept in the save, old saves keep the classic ones
	dif.seed_run(31)
	o.reset()
	for who in o.DINERS:
		var t: Dictionary = o.taste(who)
		var row: Dictionary = o.PEOPLE[who]
		var swaps := 0
		for l in row.loves:
			swaps += 0 if t.loves.has(l) else 1
		for h in row.hates:
			swaps += 0 if t.hates.has(h) else 1
		_check(swaps >= 1 and swaps <= 2, "%s: %d taste(s) swapped" % [who, swaps])
		_check(
			t.loves.size() == row.loves.size() and t.hates.size() == row.hates.size(),
			"%s keeps the same number of loves and dislikes" % who
		)
		for h in t.hates:
			_check(
				not o.PROTECTED_TOPICS.has(h) and not t.loves.has(h),
				"%s dreads %s (not family, not a love)" % [who, h]
			)
	var first_tastes: Dictionary = o.tastes.duplicate(true)
	dif.seed_run(32)
	o.reset()
	var differs := false
	for who in o.DINERS:
		differs = differs or o.taste(who) != first_tastes[who]
	_check(differs, "another save, other tastes")
	dif.seed_run(31)
	o.reset()
	o.known = {"Alan": {"likes": ["FOOD"], "hates": []}}
	var saved: Dictionary = o.to_dict()
	_check(
		(
			int(saved.version) == 2
			and saved.tastes.size() >= 3
			and saved.tastes.Alan == first_tastes.Alan
		),
		"the save carries version 2 and the tastes"
	)
	o.reset()
	dif.seed_run(99)
	o.from_dict(saved)
	_check(
		o.known.Alan.likes == ["FOOD"] and o.tastes == saved.tastes,
		"known tastes and real tastes round trip"
	)
	for who in o.DINERS:
		_check(o.taste(who) == first_tastes[who], "%s: the loaded tastes are the saved ones" % who)
	var old := {
		"count": 3,
		"skipped": 1,
		"best": {"dinner": 2},
		"known": {"Dan": {"likes": ["FOOD"], "hates": ["MOVIES"]}}
	}
	o.reset()
	o.from_dict(old)
	_check(
		o.count == 3 and o.known.Dan.hates == ["MOVIES"] and o.song_best.is_empty(),
		"an old save loads"
	)
	_check(
		(
			o.taste("Alan") == {"loves": ["SPORTS", "FOOD"], "hates": ["WORK DRAMA"]}
			and o.taste("Garrison") == {"loves": ["MOVIES", "WEEKEND PLANS"], "hates": ["SPORTS"]}
			and o.taste("Dan") == {"loves": ["KIDS AND PETS", "FOOD"], "hates": ["MOVIES"]}
		),
		"an old save keeps the classic tastes, so what it knew is still true"
	)
	o.reset()

	# the owner pays: the budget card
	c.new_game("owner")
	world.time_scale = 1.0
	owner.cash = 5000
	o.use_rooms = true
	o._open("dinner", false)
	_check(owner.cash == 4700, "the owner pays $300 on arrival")
	o.press(KEY_ENTER)
	_check(
		cards.is_open and cards.speaker == "Restaurant host" and cards.options.size() == 3,
		"the budget card appears"
	)
	_check(
		cards.options[0].id == "normal" and cards.options[0].label.contains("$300"),
		"normal is the default"
	)
	cards.pick(2)
	_check(
		o.phase == "play" and o.g.budget == "fancy" and owner.cash == 5000 - 520, "fancy costs $520"
	)
	o.g.moods = {"Alan": "easygoing", "Garrison": "easygoing", "Dan": "easygoing"}
	# the table is the roster minus you (in the owner campaign you are Alan or Garrison)
	var table_n: int = o.diners().size()
	var first: String = o.diners()[0]
	_check(
		o.diner_shift(first) == 1 and o.dinner_targets()[0] == 5 * table_n + int(o.TABLE_BARS[table_n][0]) + 3 * table_n,
		"a fancy table lifts everyone's mood (and the bar)"
	)
	o.set_budget("cheap")
	_check(
		owner.cash == 5000 - 150 and o.diner_shift("Dan") == -1,
		"a cheap table refunds the difference and sinks the mood"
	)
	o.set_budget("normal")
	_check(owner.cash == 4700 and o.diner_shift("Dan") == 0, "normal is the old price")
	o._finish(-1)
	o.press(KEY_ENTER)
	owner.cash = 350
	o._open("dinner", false)
	var spare: Array = o.budget_options()
	_check(
		not bool(spare[2].get("enabled", true)) and bool(spare[1].get("enabled", true)),
		"a thin bank greys out the fancy table"
	)
	o._finish(-1)
	o.press(KEY_ENTER)
	# the song card at the mic
	c.new_game("tech")
	o._open("karaoke", false)
	o.press(KEY_ENTER)
	_check(
		cards.is_open and cards.speaker == "Karaoke host" and o.phase == "intro",
		"the card asks for a song before the game starts"
	)
	o.press(KEY_ENTER)
	_check(cards.is_open and o.phase == "intro", "keys do nothing behind the card")
	var picked: String = cards.options[1].id
	cards.pick(1)
	_check(o.phase == "play" and o.g.song.id == picked, "the picked song plays")
	o._finish(-1)
	o.press(KEY_ENTER)
	o.use_rooms = false

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
	_check(cards.is_open and cards.options.size() == 7, "then the seven activities")
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
	# R21: cornhole ($100) and the cookout ($150) are on the card for the owner, cost money, refund on the intro page
	owner.cash = 5000
	o._offered = false
	world.clock = 16.2
	o.maybe_invite()
	cards.pick(0)
	var labels: Array = cards.options.map(func(opt: Dictionary) -> String: return str(opt.label))
	_check(labels.has("CORNHOLE ($100)") and labels.has("COOKOUT ($150)"), "the card offers cornhole and the cookout with prices")
	cards.pick(5)
	_check(o.is_open and o.game == "cornhole" and owner.cash == 4900, "cornhole costs $100")
	o.press(KEY_ESCAPE)
	_check(owner.cash == 5000, "leaving cornhole before you start refunds it")
	o.press(KEY_ENTER)
	o._offered = false
	world.clock = 16.2
	o.maybe_invite()
	cards.pick(0)
	cards.pick(6)
	_check(o.is_open and o.game == "grill" and owner.cash == 4850, "the cookout costs $150")
	o.press(KEY_ESCAPE)
	_check(owner.cash == 5000, "leaving the cookout before you start refunds it")
	o.press(KEY_ENTER)
	_check(o.cost_range() == "$100 to $300" or o.cost_range() == "$100 to $520", "the cost range starts at the $100 cornhole (%s)" % o.cost_range())

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
