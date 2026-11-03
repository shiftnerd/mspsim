extends SceneTree
# The bigger conference room (six seats) and the weekly all-hands (days 6, 11, 16).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var meeting := root.get_node("Meeting")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var sk := root.get_node("Skills")
	var owner := root.get_node("Owner")
	var data = world.DATA.SCENES["conference"]
	_check(data.W == 320 and data.seats.size() == 6, "the conference room has 320 px and six seats")
	c.save_prefix = "user://test_"
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	c.day = 6
	_check(
		meeting.is_meeting_day(6) and meeting.is_meeting_day(11) and not meeting.is_meeting_day(7),
		"days 6, 11, 16"
	)

	# ---- the whole cast sits, and there are still seats for the player
	for n in world.chars:
		world.chars[n].scene = world.CAST[n].home
		world.force_activity(n, "work")
	change_scene_to_file("res://scenes/conference.tscn")
	await _wait(20)
	world.time_scale = 1.0
	world.clock = 14.0
	meeting._process(0.1)
	_check(meeting.state == "called", "at 14:00 the boss calls the all-hands")
	var legs := 0
	for n in world.chars:
		for leg in world.chars[n].legs:
			legs += 1 if str(leg.get("kind", "")) == "meeting" else 0
	_check(legs == 5, "everyone gets a meeting leg (%d of 5)" % legs)
	await _wait(3200)
	var seated := 0
	for n in ["Alan", "Garrison", "Dan", "Vic", "Maya"]:
		var npc := current_scene.get_node_or_null("Actors/" + n)
		seated += 1 if npc != null and npc.seat != null else 0
	_check(seated >= 3, "the team sits down around the table (%d seated)" % seated)
	var free := 0
	for i in range(1, 7):
		var seat := current_scene.get_node("Interactables/Seat%d" % i)
		free += 0 if seat.occupied else 1
	_check(free >= 1, "and there is a seat for you (%d free)" % free)

	# ---- attend: a briefing and a question
	c.day = 11
	meeting.state = ""
	meeting.done_day = -1
	_drain(cards)
	var rep0: int = c.rep
	var xp0: int = sk.xp["people"]
	social.rel["Alan"] = 0
	world.clock = 14.3
	meeting.state = "called"
	meeting._process(0.1)
	_check(
		meeting.attended == 1 and cards.is_open and cards.speaker.contains("Morgan"),
		"you are in the room: Morgan briefs everyone"
	)
	_check(
		social.value("Alan") >= 1 and sk.xp["people"] == xp0 + 3,
		"attending helps (opinions up, +3 CUSTOMER XP)"
	)
	_check(cards.options.size() == 4, "four questions")
	cards.pick(2)
	_check(
		cards.is_open and cards.text.length() > 10, "what is coming up: " + cards.text.substr(0, 60)
	)
	cards.pick(0)
	_check(c.rep == rep0, "no penalty for attending")

	# ---- skip it: the boss notices
	c.day = 16
	meeting.state = ""
	meeting.done_day = -1
	_drain(cards)
	world.clock = 13.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(20)
	world.clock = 14.3
	meeting.state = "called"
	meeting._process(0.1)
	_check(meeting.missed == 1 and c.rep == rep0 - 1, "missing the all-hands costs 1 reputation")
	_check(root.get_node("Msp").texts[0].body.contains("missed"), "and Morgan texts you")
	meeting._process(0.1)
	_check(meeting.missed == 1, "once a day")

	# ---- the owner gives the speech
	c.new_game("owner")
	c.day = 6
	owner.burnout = 20.0
	change_scene_to_file("res://scenes/conference.tscn")
	await _wait(20)
	world.time_scale = 1.0
	world.clock = 14.3
	meeting.state = "called"
	meeting._process(0.1)
	_check(
		cards.is_open and cards.speaker == "All-hands" and cards.options.size() == 4,
		"owner: you address the crew"
	)
	cards.pick(0)
	_check(owner.burnout == 17.0, "sharing the numbers lowers burnout")
	cards.pick(0)
	meeting.reset()
	var data2: Dictionary = meeting.to_dict()
	_check(data2.attended == 0, "(saved)")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
