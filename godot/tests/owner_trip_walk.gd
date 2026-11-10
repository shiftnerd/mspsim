extends SceneTree
# gdlint:disable=max-line-length
# P5: the owner campaign's Rodent Nation trip is walked through the venue when the real rooms are in use (Outings.use_rooms):
# GO YOURSELF on the rn_invite card flies you to the resort lobby, one session is sat through on a real chair in a salon (the
# three sessions of the Owner card rn_session are behind doors A, B and C, D is closed), the three booths of the expo hall are the
# three vendor cards, and the closing in the ballroom (rn_wrap) flies you home. Without rooms the trip is the old chain of cards.
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/owner_trip_walk.gd`

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


func _clear(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 40:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _settle(name: String) -> void:
	var n := 0
	while (_scene() != name or root.get_node("Game").busy) and n < 600:
		await process_frame
		n += 1
	for i in 5:
		await process_frame


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cf := root.get_node("Expo")
	var cards := root.get_node("Cards")
	var owner := root.get_node("Owner")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var game := root.get_node("Game")
	var outings := root.get_node("Outings")
	var hints := root.get_node("Hints")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	c.new_game("owner")
	_clear(cards)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle("main_floor")
	_clear(cards)

	# ---- without rooms: the old chain of cards
	outings.use_rooms = false
	owner.cash = 5000
	owner.show_card("rn_invite")
	cards.pick(0)
	_check(cards.is_open and cards.speaker == "RODENT NATION" and cards.options.size() == 3 and not cf.owner_walk, "no rooms: GO YOURSELF opens the session card as before")
	cards.pick(0)
	_check(cards.is_open and str(cards.options[0].label).contains("RMM BOOTH"), "then the hall card")
	cards.pick(3)
	_clear(cards)
	_check(_scene() == "main_floor" and not cf.away, "and you never left the office")

	# ---- with rooms: the trip is walked
	outings.use_rooms = true
	world.time_scale = 1.0
	world.clock = 16.1
	owner.cash = 5000
	var price0: float = owner.price
	var burn0: float = owner.burnout
	for flag in ["rn_rmm", "rn_psa", "rn_hw", "card_rn_wrap", "card_rn_session"]:
		owner.flags.erase(flag)
	owner.show_card("rn_invite")
	cards.pick(0)
	_check(owner.cash == 4550 and cf.owner_walk and cf.away and not cards.is_open, "GO YOURSELF: $450, and no session card")
	await _settle("resort_lobby")
	_check(_scene() == "resort_lobby" and not msp.enabled and world.time_scale == 0.0, "you land in the resort lobby, the office is frozen")
	await _wait(0.3)
	_check(str(hints.objective).contains("SESSION"), "the objective points at the sessions: %s" % str(hints.objective))
	game.go("ballroom", "from_lobby")
	await _settle("ballroom")
	await _wait(0.3)
	_check(not cards.is_open and cf._stage == "o_session", "the ballroom is not open yet (the closing comes after a session)")
	game.go("resort_hall", "from_lobby")
	await _settle("resort_hall")
	_check(" ".join(cf.sign_lines(0)).begins_with("PRICING") and cf.sign_lines(3) == ["CLOSED"], "the easels show the owner's sessions: %s, D is closed" % str(cf.sign_lines(0)))
	game.vars["conf_door"] = "from_d"
	game.go("breakout_d", "from_hall")
	await _settle("breakout_d")
	await _wait(0.3)
	_check(cards.is_open and cards.speaker == "SALON D" and cards.options.size() == 1, "salon D is closed")
	_check(cf.room_info(3).is_empty(), "and its screen is blank")
	cards.pick(0)
	await _settle("resort_hall")
	game.vars["conf_door"] = "from_a"
	game.go("breakout_a", "from_hall")
	await _settle("breakout_a")
	await _wait(0.3)
	_check(cards.is_open and cards.speaker == "SALON A" and str(cards.text).contains("PRICING AND PACKAGING CLINIC"), "salon A offers the pricing clinic")
	var info: Dictionary = cf.room_info(0)
	_check(" ".join(info.title).contains("PRICING") and str(info.speaker[0]) == "DANA PRICE", "the room's screen shows it: %s" % str(info.title))
	cards.pick(0)  # take a seat
	_check(is_equal_approx(owner.price, price0), "nothing changes until you have sat through it")
	var player: Node = current_scene.get_node("Actors/Player")
	var seat: Node = cf._free_seat()
	player.global_position = seat.global_position
	seat.use(player)
	await _wait(1.5)
	_check(str(player.state) == "sitting" and not cf.seated.is_empty() and cf.seated.lines.size() >= 3, "sitting down starts the talk (%d lines)" % cf.seated.get("lines", []).size())
	_check(cf.talk_line().contains("EFFECTIVE HOURLY RATE"), "the first line: %s" % cf.talk_line())
	var guard := 0
	while not cf.seated.is_empty() and guard < 30:
		cf.talk_skip()
		guard += 1
	await _wait(1.2)
	_check(is_equal_approx(owner.price, price0 + 0.03) and cf._stage == "o_free" and int(owner.flags.get("card_rn_session", -1)) == 0, "the clinic is the card's effect: prices +3%")
	_check(not cards.is_open and str(player.state) != "sitting" and not game.ui_open, "no hub card: you stand up in the room (card %s %s, state %s, ui %s)" % [str(cards.is_open), str(cards.speaker), str(player.state), str(game.ui_open)])
	game.go("resort_hall", "from_a")
	await _settle("resort_hall")
	game.vars["conf_door"] = "from_b"
	game.go("breakout_b", "from_hall")
	await _settle("breakout_b")
	await _wait(0.3)
	_check(not cards.is_open and is_equal_approx(owner.burnout, burn0), "one session is all there is time for")

	# ---- the expo hall: the three booths are the three vendor cards
	game.go("vendor_hall", "from_hall")
	await _settle("vendor_hall")
	cf.booth("swag")
	_check(cards.is_open and cards.speaker == "LabRat Sales Rep", "the first booth is the RMM vendor")
	var weekly0: int = owner.weekly_extra
	cards.pick(0)  # sign at the show
	_check(owner.stack.rmm == "labrat_gold" and owner.weekly_extra == weekly0 + 25 and owner.flags.get("rn_rmm", false), "signing changes the stack")
	_check(not cards.is_open, "and no hub card follows: you are standing in the hall")
	cf.booth("swag")
	_check(not cards.is_open, "a booth you finished only waves")
	game.vars["conf_booth"] = "nerds"
	await _wait(0.3)
	_check(cards.is_open and cards.speaker == "OpsForge Sales Rep", "walking into the second booth: the PSA vendor")
	cards.pick(1)  # the brochure
	_check(owner.flags.get("rn_psa", false) and owner.stack.psa != "opsforge", "the brochure changes nothing")
	cf.booth("vendor")
	_check(cards.is_open and cards.speaker == "DellightCo Rep", "the third booth: hardware")
	cards.pick(1)

	# ---- the closing in the ballroom is the way home
	game.go("ballroom", "from_lobby")
	await _settle("ballroom")
	await _wait(0.3)
	_check(cards.is_open and str(cards.options[0].label) == "FLY HOME", "the closing: the wrap card")
	cards.pick(0)
	_clear(cards)
	await _settle("main_floor")
	_clear(cards)  # the week goes on: whatever card was waiting (World.time_scale reads 0 while one is open)
	_check(_scene() == "main_floor" and not cf.owner_walk and not cf.away and msp.enabled and world.time_scale == 1.0, "home again: the office runs (%s walk %s away %s msp %s scale %s)" % [_scene(), str(cf.owner_walk), str(cf.away), str(msp.enabled), str(world.time_scale)])
	_check(str(hints.objective) == "", "the objective is cleared")
	var r: Dictionary = c.make_report()
	_check(not r.is_empty(), "the week's report is the owner's own (not the tech trip's)")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
