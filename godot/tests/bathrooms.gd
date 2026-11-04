extends SceneTree
# R22: two unique single-occupancy bathrooms behind the kitchenette doors. Both load with their fixtures, each door leads to its
# own room and back, a person inside (the player or a cast member, on screen or not) locks the kitchenette door for everybody else
# (arrow shakes, OCCUPIED toast, red dot on the plate), leaving unlocks it, two cast members never share a room, somebody who finds
# both occupied waits and retries and then gives up, a person inside at 17:00 is released, and old saves that say `bathroom` load.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bathrooms.gd

var failures := 0
var world: Node
var game: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _wait_scene(name: String) -> bool:
	var n := 0
	while _scene_name() != name and n < 400:
		await process_frame
		n += 1
	for i in 5:
		await process_frame
	n = 0
	while game.busy and n < 200:
		await process_frame
		n += 1
	return _scene_name() == name


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _door(door_name: String) -> Node2D:
	return current_scene.get_node("Interactables/%s" % door_name)


func _use_door(door_name: String) -> void:
	var d := _door(door_name)
	_player().global_position = Vector2(d.global_position.x, 118)
	d.use(_player())


# everybody at their desk with a long work leg (the clock is frozen so nothing else happens)
func _reset_cast() -> void:
	for n in world.chars:
		var st: Dictionary = world.chars[n]
		st.node = null
		st.scene = world.row(n).home
		st.arrive = ""
		st.following = false
		st.legs = [world._work_leg(n, true, 1.0e6)]
		st.leg_t = 1.0e6


# a cast member standing in the kitchenette about to go to the nearest bathroom, then back to work
func _send(n: String) -> void:
	var st: Dictionary = world.chars[n]
	st.scene = "kitchenette"
	st.arrive = "from_main"
	st.legs = world._bath_legs(world._baths_near(172.0)[0], 172.0) + [world._work_leg(n, false, 30.0)]
	world._gate_bathroom(n)
	st.leg_t = st.legs[0].dur


func _bath_of(n: String) -> String:
	var legs: Array = world.chars[n].legs
	return str(legs[0].get("bath", "")) if not legs.is_empty() else ""


func _init() -> void:
	await process_frame
	game = root.get_node("Game")
	world = root.get_node("World")
	var campaign := root.get_node("Campaign")
	game.title_mode = false
	campaign.new_game(campaign.FREE)
	world.day_len = 1.0e9  # a frozen clock: no meetings, no 17:00
	world.meeting_gap = Vector2(9999.0, 9999.0)
	world._meeting_t = 9999.0
	_reset_cast()

	# ---- both rooms load with their fixtures, spawns and a door back to their own kitchenette spawn
	var back := {"bathroom_1": "from_bath_left", "bathroom_2": "from_bath_right"}
	for b in ["bathroom_1", "bathroom_2"]:
		change_scene_to_file("res://scenes/%s.tscn" % b)
		_check(await _wait_scene(b), "%s loads" % b)
		for fx_name in ["Sink", "Toilet", "Switch"]:
			_check(current_scene.get_node_or_null("Fx/" + fx_name) != null, "%s has the %s fx" % [b, fx_name])
		_check(current_scene.get_node_or_null("Spawns/start") != null, "%s has a start spawn" % b)
		_check(current_scene.get_node_or_null("Spawns/from_kitchenette") != null, "%s has a from_kitchenette spawn" % b)
		var d := _door("DoorToKitchenette")
		_check(d.target_scene == "kitchenette" and d.target_spawn == back[b], "%s door returns to %s" % [b, back[b]])
		var u: Dictionary = world.DATA.SCENES[b].uses
		_check(u.has("sink") and u.has("toilet") and u.has("switch"), "%s has sink, toilet and switch uses for the cast" % b)

	# ---- the two rooms are not the same room
	_check(world.DATA.SCENES["bathroom_1"].links[0].x != world.DATA.SCENES["bathroom_2"].links[0].x, "the doors are on opposite sides")
	change_scene_to_file("res://scenes/bathroom_1.tscn")
	await _wait_scene("bathroom_1")
	_check(current_scene.get_node_or_null("Fx/BarLight") != null, "bathroom 1 has the flickering bar light")
	var t1: Image = load("res://assets/sets/bathroom_1.png").get_image()
	var t2: Image = load("res://assets/sets/bathroom_2.png").get_image()
	var diff := 0
	for x in range(100, 220, 3):
		for y in range(100, 190, 3):
			if t1.get_pixel(x, y) != t2.get_pixel(x, y):
				diff += 1
	_check(diff > 600, "the two backgrounds differ (%d of 1200 sampled pixels)" % diff)

	# ---- the kitchenette doors lead to the right room and back; nobody inside = unlocked
	change_scene_to_file("res://scenes/kitchenette.tscn")
	await _wait_scene("kitchenette")
	_check(_door("DoorBathLeft").occupancy == "bathroom_1" and _door("DoorBathRight").occupancy == "bathroom_2", "each kitchenette door watches its own room")
	_check(not _door("DoorBathLeft").is_locked() and not _door("DoorBathRight").is_locked(), "both doors are open when nobody is inside")
	for pair in [["DoorBathLeft", "bathroom_1", 92.0], ["DoorBathRight", "bathroom_2", 152.0]]:
		_use_door(pair[0])
		_check(await _wait_scene(pair[1]), "%s leads to %s" % [pair[0], pair[1]])
		_check(world.bathroom_occupied(pair[1]), "the player inside makes %s occupied" % pair[1])
		_use_door("DoorToKitchenette")
		_check(await _wait_scene("kitchenette"), "back out to the kitchenette")
		_check(is_equal_approx(_player().global_position.x, pair[2]), "the door spawn is at x %d" % int(pair[2]))
		_check(not world.bathroom_occupied(pair[1]), "leaving unlocks %s" % pair[1])

	# ---- a cast member inside (off screen) locks the door for the player
	world.chars["Alan"].scene = "bathroom_1"
	_check(world.bathroom_occupied("bathroom_1") and not world.bathroom_occupied("bathroom_2"), "Alan inside: only bathroom 1 is occupied")
	_check(_door("DoorBathLeft").is_locked() and not _door("DoorBathRight").is_locked(), "so only the left door is locked")
	root.get_node("Hints").toast_text = ""
	_player().global_position = Vector2(_door("DoorBathLeft").global_position.x, 118)
	_door("DoorBathLeft").use(_player())
	await process_frame
	_check(_scene_name() == "kitchenette", "the locked door does not open")
	_check(root.get_node("Hints").toast_text == "OCCUPIED", "the toast says OCCUPIED")
	_check(_door("DoorBathLeft")._arrow.shaking(), "the arrow shakes")
	var light: Node = current_scene.get_node("Fx/LightLeft")
	_check(light.kind == "occupied_1" and current_scene.get_node("Fx/LightRight").kind == "occupied_2", "the plates have their occupied lights")
	world.chars["Alan"].scene = world.row("Alan").home
	_check(not _door("DoorBathLeft").is_locked(), "Alan out: the left door is open again")

	# ---- somebody walking in locks the door at that moment (the leg is the current one), and two people never share a room
	_reset_cast()
	_send("Alan")
	var first := _bath_of("Alan")
	_check(first == "bathroom_2", "the nearest free bathroom from the main floor side is bathroom 2 (%s)" % first)
	_check(_door("DoorBathRight").is_locked(), "Alan on his way in: the right door is locked for the player")
	_send("Garrison")
	_check(_bath_of("Garrison") == "bathroom_1", "Garrison takes the other one (%s)" % _bath_of("Garrison"))
	_send("Dan")
	_check(world.chars["Dan"].legs[0].kind == "wait", "both taken: Dan waits outside")
	_check(world.chars["Dan"].legs[0].routine.has("dots:4"), "with a dots bubble")
	# the room frees up and Dan's retry takes it
	world.chars["Garrison"].scene = world.row("Garrison").home
	world.chars["Garrison"].legs = [world._work_leg("Garrison", true, 1.0e6)]
	world._finish_leg("Dan")  # the wait is over
	_check(_bath_of("Dan") == "bathroom_1", "Garrison out: Dan's retry takes bathroom 1 (%s)" % _bath_of("Dan"))
	_check(not world.bathroom_occupied("bathroom_1", "Dan"), "and nobody else was in it")

	# ---- the player inside locks the cast out: they take the other room
	_reset_cast()
	change_scene_to_file("res://scenes/bathroom_1.tscn")
	await _wait_scene("bathroom_1")
	_send("Maya")
	_check(_bath_of("Maya") == "bathroom_2", "the player is in bathroom 1: Maya goes to bathroom 2 (%s)" % _bath_of("Maya"))
	_send("Morgan")
	_check(world.chars["Morgan"].legs[0].kind == "wait", "and Morgan waits (both are taken)")

	# ---- giving up: both rooms stay occupied, the waiter retries and then goes back to work
	_reset_cast()
	change_scene_to_file("res://scenes/bowling_alley.tscn")  # nobody of the cast is ever here
	await _wait_scene("bowling_alley")
	_reset_cast()
	world.chars["Maya"].scene = "bathroom_1"
	world.chars["Morgan"].scene = "bathroom_2"
	_send("Alan")
	var waits := 0
	var entered := false
	for i in 400:
		var legs: Array = world.chars["Alan"].legs
		if not legs.is_empty() and legs[0].kind == "wait" and world.chars["Alan"].leg_t >= world.BATH_WAIT + 2.9:
			waits += 1
		world._process(0.25)
		entered = entered or world.chars["Alan"].scene.begins_with("bathroom")
	_check(waits == world.BATH_TRIES, "Alan waited %d times (limit %d)" % [waits, world.BATH_TRIES])
	_check(not entered, "and never went in")
	_check(world.chars["Alan"].scene == world.row("Alan").home, "then gave up and is back at his desk")
	_check(str(world.chars["Alan"].legs[0].kind) == "work", "working again (%s)" % str(world.chars["Alan"].legs[0].kind))

	# ---- everybody wants the bathroom at once: never two in one room, nobody is stuck
	_reset_cast()
	var names: Array = world.chars.keys()
	for n in names:
		world.force_activity(n, "bathroom")
	var worst := 0
	var waited := 0
	var visits := {}
	var streak := {}
	var longest := 0.0
	for i in 1600:
		world._process(0.25)
		for b in ["bathroom_1", "bathroom_2"]:
			var inside := 0
			for n in names:
				if world.chars[n].scene == b:
					inside += 1
					visits[n] = true
			worst = maxi(worst, inside)
		for n in names:
			if world.chars[n].legs[0].kind == "wait":
				waited += 1
				streak[n] = float(streak.get(n, 0.0)) + 0.25
				longest = maxf(longest, streak[n])
			else:
				streak[n] = 0.0
	_check(worst == 1, "at most one person in a bathroom at any time (worst %d)" % worst)
	_check(waited > 0, "somebody had to wait (%d wait steps)" % waited)
	_check(visits.size() >= 2, "several people did get in (%d)" % visits.size())
	_check(longest <= 40.0, "nobody waited more than 40 s in a row (%.1f s)" % longest)

	# ---- a person inside at 17:00 is released
	_reset_cast()
	world.chars["Alan"].scene = "bathroom_2"
	world.chars["Alan"].legs = [world._bath_legs("bathroom_2", 172.0)[1]] + world._travel("bathroom_2", "kitchenette", 136.0)
	world.chars["Alan"].leg_t = world.chars["Alan"].legs[0].dur
	world.clock = world.DAY_END + 0.1
	var out := false
	for i in 1200:
		world._process(0.25)
		if world.chars["Alan"].scene == world.OUTSIDE:
			out = true
			break
	_check(out, "Alan, inside at 17:00, comes out and leaves the building")
	_check(not world.bathroom_occupied("bathroom_2"), "and the bathroom is free")
	world.clock = world.DAY_START + 1.0

	# ---- old saves and resume files that say `bathroom`
	var resume := root.get_node("Resume")
	resume.apply_player({"room": "bathroom", "held": "", "sips": 0, "seat": ""})
	_check(campaign._resume_scene == "bathroom_1", "an old resume point in `bathroom` opens bathroom_1 (%s)" % campaign._resume_scene)
	campaign._resume_scene = ""
	resume.apply_world(
		{
			"day": 1,
			"clock": 10.0,
			"lights": {"bathroom": false},
			"cast": {"Alan": {"scene": "bathroom", "held": "", "sips": 0, "lunched": false, "ret": "from_bath_left"}},
		}
	)
	_check(world.lights.get("bathroom_1", true) == false and not world.lights.has("bathroom"), "old lights state maps to bathroom_1")
	_check(world.chars["Alan"].scene == world.row("Alan").home, "a person who was in the old `bathroom` is re-planned at their desk")
	_check(ResourceLoader.exists("res://scenes/bathroom_1.tscn") and not ResourceLoader.exists("res://scenes/bathroom.tscn"), "no stale bathroom scene")

	print("DONE failures=%d" % failures)
	quit()
