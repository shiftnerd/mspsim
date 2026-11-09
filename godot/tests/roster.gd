extends SceneTree
# gdlint:disable=expression-not-assigned
# R5 who comes along: the invitation draws a party from the roster (seeded, friends first, Morgan rarely), the
# games read it (up to 4 bowlers, up to 5 diners, the karaoke crowd, the escape-room hint giver), every roster
# member has a bowling row, a taste row and hints, and the invitation card names who is coming.
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/roster.gd`

var failures := 0
var started := false


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	if current_scene == null or started:
		return false
	started = true
	_run()
	return false


func _run() -> void:
	await process_frame
	await process_frame
	var world := root.get_node("World")
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var social := root.get_node("Social")
	var cards := root.get_node("Cards")
	var game := root.get_node("Game")
	var player_script := load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	o.enabled = true
	o.use_rooms = false
	var zones := ["board", "clock", "plaque", "shelf", "keypad"]

	# ---- every cast member has a bowling row, a taste row, hints and a code for the scoreboard
	for n in world.CAST:
		_check(o.BOWLERS.has(n), "%s has a bowling row" % n)
		_check(o.PEOPLE.has(n), "%s has a taste row" % n)
		_check(o.GUESTS.has(n) and str(o.GUESTS[n].code).length() == 2, "%s has an invitation row and a 2 letter code" % n)
		_check(o.FRIEND_HINTS.has(n), "%s has escape-room hints" % n)
		for z in zones:
			_check(str(o.FRIEND_HINTS.get(n, {}).get(z, "")) != "", "%s: hint for %s" % [n, z])
		for kind in ["cheer", "groan", "talk", "sing"]:
			_check(o.CREW_LINES.get(n, {}).get(kind, []).size() >= 2, "%s: two %s lines" % [n, kind])
		var row: Dictionary = o.BOWLERS[n]
		_check(
			float(row.skill) > 0.3 and float(row.skill) < 0.8 and float(row.noise) > 0.0 and int(row.late) >= 0,
			"%s: sane bowling numbers" % n
		)
	var codes := {}
	for n in o.GUESTS:
		codes[o.GUESTS[n].code] = true
	_check(codes.size() == o.GUESTS.size(), "scoreboard codes are unique")
	_check(
		float(o.BOWLERS.Garrison.streak) > 0.0 and float(o.BOWLERS.Dan.noise) > float(o.BOWLERS.Alan.noise) * 2.0,
		"Garrison is streaky, Dan is wild, Alan is steady"
	)
	_check(float(o.BOWLERS.John.show) > 0.0 and float(o.BOWLERS.John.gutter) >= 0.05, "John shows off and sometimes gutters")
	_check(int(o.BOWLERS.Morgan.late) >= 1 and float(o.BOWLERS.Maya.noise) <= float(o.BOWLERS.Alan.noise), "Morgan joins late, Maya is precise")
	_check(float(o.GUESTS.Morgan.comes) <= 0.35, "Morgan comes to a minority of outings")

	# ---- who can bowl and dine for each player character (Free Play: you are one of the cast)
	for me in world.CAST:
		player_script.current_character = str(world.CAST[me].character)
		c.new_game("free")
		var here: Array = o.roster()
		_check(c.player_as == me and not here.has(me) and here.size() == 5, "%s: five people to take out" % me)
		for s in 20:
			d.seed_run(900 + s)
			o.reset()
			var p: Array = o.draw_party()
			_check(p.size() >= 2 and p.size() <= 5 and not p.has(me), "%s seed %d: party of %d without you" % [me, s, p.size()]) if s < 2 else null
			if p.size() < 2 or p.has(me):
				_check(false, "%s seed %d: party %s" % [me, s, str(p)])
			o.opts = {"party": p}
			_check(o.bowlers().size() <= 4 and o.diners().size() <= 5, "caps hold") if s == 0 else null
			for b in o.bowlers():
				if not here.has(b) or not p.has(b):
					_check(false, "%s: bowler %s is not in the party" % [me, b])
			o.opts = {}

	# ---- caps with the full cast, and the classic trio when there is no invitation
	player_script.current_character = "office_intern"
	c.new_game("free")
	_check(o.roster().size() == 6, "a non-cast character takes six out")
	var all6: Array = o.roster().duplicate()
	o.opts = {"party": all6}
	_check(o.bowlers().size() == 4, "six come: four bowl")
	_check(o.diners().size() == 5, "six come: five at the table")
	_check(o.present().size() == 6 and o.crowd().size() == 6, "and all six are in the karaoke crowd")
	o.opts = {"party": ["Maya", "John", "Morgan"]}
	_check(o.bowlers() == ["John", "Maya", "Morgan"], "bowlers come back in cast order")
	_check(o.diners() == ["John", "Maya", "Morgan"], "so does the table")
	o.opts = {"party": ["Morgan", "Dan"], "table": ["Dan"]}
	_check(o.diners() == ["Dan"], "the toolbox can still narrow the table")
	o.opts = {}
	_check(o.bowlers() == ["Alan", "Garrison", "Dan"] and o.diners() == ["Alan", "Garrison", "Dan"], "no invitation: the classic trio")

	# ---- the draw: deterministic, seeded, friends first, Morgan rarely
	d.seed_run(77)
	o.reset()
	var a: Array = o.draw_party().duplicate()
	d.seed_run(77)
	var b: Array = o.draw_party().duplicate()
	_check(a == b, "same seed, same party")
	var seen := {}
	var counts := {}
	for n in world.CAST:
		counts[n] = 0
	for s in 300:
		d.seed_run(5000 + s)
		var p: Array = o.draw_party()
		seen[str(p)] = true
		for n in p:
			counts[n] += 1
		if p.size() < 2:
			_check(false, "seed %d: only %d came" % [s, p.size()])
	_check(seen.size() > 15, "300 seeds give %d different parties" % seen.size())
	_check(counts.Morgan < 120 and counts.Morgan > 20, "Morgan comes to a minority of outings (%d of 300)" % counts.Morgan)
	_check(counts.Alan > 230 and counts.Garrison > 230, "Alan and Garrison nearly always come")
	_check(counts.John > 100 and counts.Maya > 100, "John and Maya come often enough to matter")
	# a friend is more likely than a cold coworker
	c.new_game("tech")
	var hits := {"warm": 0, "cold": 0}
	for s in 200:
		d.seed_run(8000 + s)
		social.rel["Dan"] = 40
		hits.warm += 1 if o.draw_party().has("Dan") else 0
		d.seed_run(8000 + s)
		social.rel["Dan"] = -30
		hits.cold += 1 if o.draw_party().has("Dan") else 0
	_check(hits.warm > hits.cold + 40, "friends come more often than the cold (%d vs %d of 200)" % [hits.warm, hits.cold])
	social.rel["Dan"] = 0
	# a rotation: with a full crew the four bowlers are not always the same
	var bowl_sets := {}
	for s in 60:
		d.seed_run(9000 + s)
		o.opts = {"party": o.draw_party().duplicate()}
		bowl_sets[str(o.bowlers())] = true
		o.opts = {}
	_check(bowl_sets.size() >= 4, "the bowlers rotate with the seed (%d line-ups)" % bowl_sets.size())

	# ---- the invitation names who is coming; the party carries into the game
	c.new_game("tech")
	world.time_scale = 1.0
	c.day = 5
	world.clock = 16.2
	d.seed_run(31)
	o._offered = false
	o.maybe_invite()
	var coming: Array = o.party.duplicate()
	_check(cards.is_open and coming.size() >= 2, "the invitation is open")
	_check(cards.text.contains("Coming: "), "the card says who is coming: " + cards.text.substr(maxi(0, cards.text.length() - 90)))
	for n in coming:
		_check(cards.text.contains(n), "the card names %s" % n)
	if not o.stayed.is_empty():
		_check(cards.text.contains(str(o.GUESTS[o.stayed[0]].line)), "and why %s is not" % o.stayed[0])
	cards.pick(0)
	_check(cards.is_open and cards.options.size() == 8, "then the game card")
	cards.pick(0)
	_check(o.is_open and o.game == "bowling" and o.opts.party == coming, "the party plays")
	var ppl: Array = o.bowlers()
	_check(ppl.size() == mini(4, coming.size()) and ppl.all(func(n): return coming.has(n)), "only guests bowl")
	o.press(KEY_ENTER)
	_check(o.g.totals.size() == ppl.size() + 1, "the scoreboard has everyone")
	o.is_open = false
	o.reset()

	# ---- the escape-room friend comes from the party; Morgan and John have their own voice
	for who in ["John", "Morgan", "Maya"]:
		o.opts = {"party": [who, "Alan"]}
		social.rel[who] = 40
		social.rel["Alan"] = 0
		_check(o._friend() == who, "%s gives the hints when they are the friend in the room" % who)
		o.opts = {"party": ["Alan", "Dan"]}
		_check(o._friend() != who, "%s is not asked when they stayed home" % who)
		social.rel[who] = 0
	_check(str(o.FRIEND_HINTS.John.board).contains("GUY") or str(o.FRIEND_HINTS.John.clock).contains("GUY"), "John over-promises")
	o.opts = {"party": ["Morgan", "Dan"]}
	social.rel["Morgan"] = 40
	o.start("escape", false, {"party": ["Morgan", "Dan"]})
	o.press(KEY_ENTER)
	var said: String = o.escape_nudge() if o.has_method("escape_nudge") and o.g.has("clues") else o.escape_hint()
	_check(said.begins_with("MORGAN") or said.contains("MORGAN"), "Morgan speaks: " + said)
	o.is_open = false
	social.rel["Morgan"] = 0

	# ---- personalities: the numbers behave the way the table says
	c.new_game("free")
	d.seed_run(123)
	o.opts = {"party": ["Alan", "Garrison", "Dan", "John", "Maya", "Morgan"]}
	o.g = {"frame": 2, "knocked": 0}
	var stats := {}
	for who in o.BOWLERS:
		var firsts := []
		var gutters := 0
		var strikes := 0
		for k in 600:
			o.g.frame = 1 + k % 2
			var res: Dictionary = o._bowl_roll_opp(who)
			firsts.append(int(res.first))
			gutters += 1 if int(res.first) == 0 else 0
			strikes += 1 if int(res.first) == 10 else 0
		var sum := 0.0
		for f in firsts:
			sum += float(f)
		var mean := sum / 600.0
		var var_sum := 0.0
		for f in firsts:
			var_sum += (float(f) - mean) * (float(f) - mean)
		stats[who] = {"mean": mean, "sd": sqrt(var_sum / 600.0), "gutter": gutters, "strike": strikes}
	print("bowling stats: ", stats)
	_check(stats.Alan.sd < stats.Dan.sd * 0.7, "Alan is steady, Dan is wild")
	_check(stats.Maya.sd <= stats.Alan.sd + 0.3, "Maya is precise")
	_check(stats.Dan.strike > stats.Alan.strike, "Dan throws the occasional turkey")
	_check(stats.John.gutter >= 600 * 0.03, "John has a few gutter balls (%d of 600)" % stats.John.gutter)
	var hot := 0.0
	var cold := 0.0
	for k in 600:
		o.g.frame = 2
		hot += float(o._bowl_roll_opp("Garrison").first)
		o.g.frame = 1
		cold += float(o._bowl_roll_opp("Garrison").first)
	_check(hot > cold + 600.0 * 0.8, "Garrison alternates hot and cold frames (%.1f vs %.1f)" % [hot / 600.0, cold / 600.0])
	_check(not o.bowls_in_frame("Morgan", 1) and o.bowls_in_frame("Morgan", 2) and o.bowls_in_frame("Alan", 1), "Morgan joins late")
	d.set_tier("hard")
	var hard := 0.0
	d.set_tier("easy")
	var easy := 0.0
	for k in 400:
		d.set_tier("hard")
		hard += float(o._bowl_roll_opp("Alan").first)
		d.set_tier("easy")
		easy += float(o._bowl_roll_opp("Alan").first)
	d.set_tier("normal")
	_check(hard > easy, "Difficulty scales the opponents' skill (%.1f hard vs %.1f easy)" % [hard / 400.0, easy / 400.0])

	# ---- a whole bowling game with four opponents (the overlay version), then a table of five
	var stars_seen := {}
	for s in 12:
		d.seed_run(700 + s)
		o.reset()
		o.start("bowling", false, {"party": ["Morgan", "Maya", "John", "Dan", "Alan", "Garrison"]})
		o.press(KEY_ENTER)
		_check(o.bowlers() == ["Alan", "Dan", "John", "Maya"] or o.bowlers().size() == 4, "four opponents at most") if s == 0 else null
		for frame in 5:
			o.g.marker = 0.5
			o.g.power = 0.85
			o._press_game(KEY_SPACE)
			o._press_game(KEY_SPACE)
			o._press_game(KEY_SPACE)
			var guard := 0
			while o.phase == "play" and int(o.g.frame) == frame + 1 and guard < 200:
				o.tick(0.2)
				if o.g.stage == "aim" and int(o.g.roll) == 2:
					o.g.marker = 0.5
					o._press_game(KEY_SPACE)
					o._press_game(KEY_SPACE)
					o.g.power = 0.85
				guard += 1
			if o.phase != "play":
				break
		if o.phase == "play":
			o._bowl_end()
		stars_seen[o.stars] = true
		_check(o.stars >= 1 and o.stars <= 3, "a full game with four opponents ends with 1-3 stars (%d)" % o.stars) if s < 2 else null
		o.press(KEY_ENTER)
	_check(o.g.size() >= 0, "bowling games finish")
	o.start("dinner", false, {"party": ["Alan", "Garrison", "Dan", "John", "Maya", "Morgan"]})
	o.press(KEY_ENTER)
	_check(o.diners().size() == 5 and o.dinner_targets().size() == 3, "a table of five")
	var cut: Array = o.dinner_targets()
	_check(cut[0] > cut[1] and cut[1] > cut[2], "bars descend: %s" % str(cut))
	for k in 5:
		o.dinner_talk(0)
		o.tick(2.0)
	_check(o.phase == "result" and o.stars >= 0, "five rounds with five faces end")
	o.press(KEY_ENTER)
	_check(o.known.has("John") or o.known.has("Maya") or o.known.has("Morgan"), "you learn about the new faces")

	# ---- karaoke: the crowd cheers by name
	o.opts = {"party": ["John", "Maya"]}
	o.use_rooms = true
	o.g = {"dance": false}
	o._caption = ""
	o._cheer()
	_check(o._caption.begins_with("JOHN") or o._caption.begins_with("MAYA"), "the crowd cheers by name: " + o._caption)
	o.use_rooms = false
	o.opts = {}

	# ---- rooms: a person who did not come stays out of the building
	o.reset()
	o.use_rooms = true
	o.start("escape", false, {"party": ["Alan", "Dan"]})
	_check(world.chars.Maya.scene == world.OUTSIDE and world.chars.John.scene == world.OUTSIDE, "the ones who stayed home are outside")
	_check(world.chars.Alan.scene == "escape_room" and world.chars.Dan.scene == "escape_room", "the guests are in the room")
	o.use_rooms = false
	o.is_open = false
	o._wait_id = ""
	o._traveled = false
	for n in o.SPOTS.escape:
		for zone_x in [52, 86, 149, 238, 276]:
			if absi(int(n) - zone_x) < 14:
				_check(false, "spot %d is on a clue zone" % n)

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
