extends SceneTree
# The outing rooms (bowling alley, karaoke bar, escape room): they load, have their effects and
# props, the whole cast shows up for an outing, and everyone goes home afterwards. Headless.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _wait_scene(name: String, limit := 400) -> bool:
	var n := 0
	while _scene_name() != name and n < limit:
		await process_frame
		n += 1
	for i in 5:
		await process_frame
	n = 0
	while root.get_node("Game").busy and n < 200:
		await process_frame
		n += 1
	return _scene_name() == name


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var world := root.get_node("World")
	var game := root.get_node("Game")
	var campaign := root.get_node("Campaign")
	game.title_mode = false
	campaign.new_game(campaign.FREE)

	# ---- the rooms load, with their effects
	var expect := {
		"bowling_alley": ["NeonBowl", "NeonShoes", "Switch"],
		"karaoke_bar": ["NeonKaraoke", "Lyrics", "Disco", "Switch"],
		"escape_room": ["Keypad", "Timer", "RedLight", "LampGlow", "Switch"],
		"restaurant": ["NeonBar", "TvA", "TvB", "PendantA", "PendantB", "Switch"],
	}
	for room in expect:
		change_scene_to_file("res://scenes/%s.tscn" % room)
		_check(await _wait_scene(room), room + " loads")
		var missing := []
		for fx_name in expect[room]:
			if current_scene.get_node_or_null("Fx/" + fx_name) == null:
				missing.append(fx_name)
		_check(missing.is_empty(), room + " has its effects " + str(missing))
		_check(
			current_scene.get_node("Actors").get_child_count() >= 6,
			room + " has furniture (%d actors)" % current_scene.get_node("Actors").get_child_count()
		)
		_check(
			current_scene.get_node_or_null("Actors/Player") != null, room + ": the player is there"
		)
		_check(
			current_scene.get_node_or_null("Interactables/ExitToMain") != null,
			room + ": walking off the left edge leads home"
		)

	# ---- an outing in free play: the cast comes along, then everyone goes home
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait_scene("main_floor")
	o.enabled = true
	o.use_rooms = true
	o.start("karaoke")
	var guard := 0
	while not o.is_open and guard < 600:
		await process_frame
		guard += 1
	_check(
		o.is_open and _scene_name() == "karaoke_bar",
		"the karaoke outing opens inside the karaoke bar"
	)
	var here := 0
	for who in ["Alan", "Garrison", "Dan", "Vic"]:
		here += 1 if world.chars[who].scene == "karaoke_bar" else 0
	_check(here == 4, "the whole cast is at the bar")
	var seen := 0
	for who in ["Alan", "Garrison", "Dan", "Vic"]:
		seen += 1 if current_scene.get_node_or_null("Actors/" + who) != null else 0
	_check(seen == 4, "and they are standing in the room (%d of 4)" % seen)
	o.press(KEY_ENTER)
	var lyrics := current_scene.get_node("Fx/Lyrics")
	_check(lyrics.kind == "lyrics", "the lyrics screen is playing")
	o._finish(1)
	o.press(KEY_ENTER)
	_check(not o.is_open, "the outing is over")
	_check(await _wait_scene("main_floor"), "free play: back at the office")
	var outside := 0
	for who in ["Alan", "Garrison", "Dan", "Vic"]:
		outside += 1 if world.chars[who].scene == world.OUTSIDE else 0
	_check(outside == 4, "the cast walks back in through the front door")

	# ---- the escape room shows the game on the wall
	o.start("escape")
	guard = 0
	while not o.is_open and guard < 600:
		await process_frame
		guard += 1
	_check(
		_scene_name() == "escape_room" and o.is_open,
		"the escape outing opens inside the escape room"
	)
	o.press(KEY_ENTER)
	var keypad := current_scene.get_node("Fx/Keypad")
	var timer := current_scene.get_node("Fx/Timer")
	o.g.cur = [4, 2, 7]
	o.g.time = 83.0
	_check(
		keypad._outing_escape().cur == [4, 2, 7] and timer._outing_escape().time == 83.0,
		"the keypad and the countdown on the wall show your game"
	)
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	await _wait_scene("main_floor")

	# ---- dinner happens at the restaurant
	o.start("dinner")
	guard = 0
	while not o.is_open and guard < 600:
		await process_frame
		guard += 1
	_check(_scene_name() == "restaurant" and o.is_open, "dinner opens inside the restaurant")
	var diners := 0
	for who in ["Alan", "Garrison", "Dan", "Vic"]:
		diners += 1 if current_scene.get_node_or_null("Actors/" + who) != null else 0
	_check(diners == 4, "the whole team is at the restaurant (%d of 4)" % diners)
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	await _wait_scene("main_floor")

	# ---- the rooms are optional: with use_rooms off the outing opens where you stand
	o.use_rooms = false
	o.start("bowling")
	_check(
		o.is_open and _scene_name() == "main_floor",
		"without rooms the game opens over the current scene"
	)
	o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
