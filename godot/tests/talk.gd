extends SceneTree
# Talking to people at their desks: E on a seated coworker opens a conversation; small talk, help,
# tips from the live game state, a daily lesson from a friend, the owner's check-in. Esc leaves.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var talk := root.get_node("Talk")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var sk := root.get_node("Skills")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var owner := root.get_node("Owner")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")

	# ---- the real thing: E on Alan at his desk
	var world := root.get_node("World")
	world.chars["Alan"].scene = "office_one"
	world.force_activity("Alan", "work")
	change_scene_to_file("res://scenes/office_one.tscn")
	for i in 30:
		await process_frame
	var alan := current_scene.get_node_or_null("Actors/Alan")
	var player := current_scene.get_node("Actors/Player")
	if alan != null and alan.seat == null:
		alan._occupy("Seat1", true)
	_check(alan != null and alan.seat != null, "Alan is at his desk in Office 1")
	player.global_position = alan.global_position + Vector2(-40, 0)
	alan.use(player)
	_check(
		cards.is_open and talk._who == "Alan" and cards.options.size() == 4,
		"E opens a conversation with a seated coworker"
	)
	_check(
		cards.speaker == "Alan" and cards.options[3].id == "leave", "four topics, the last is LEAVE"
	)
	cards._input(_key(KEY_ESCAPE))
	_check(not cards.is_open and talk._who == "", "Esc leaves the conversation")
	_check(alan._hold <= 0.1, "Alan goes back to work")

	# ---- small talk makes a friend
	talk._who = "Garrison"
	social.rel["Garrison"] = 0
	var line: String = talk.small_talk()
	_check(line.length() > 20, "small talk: " + line.substr(0, 40))
	_check(social.value("Garrison") >= 1, "and chatting counts toward their opinion")

	# ---- asking for help
	talk._who = "Dan"
	world.chars["Dan"].scene = "main_floor"
	world.force_activity("Dan", "work")
	social.rel["Dan"] = 50
	msp.reset()
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	var reply: String = talk.ask_help()
	_check(reply != "" and msp.ticket(t.id).fix_done, "a friend fixes your ticket: " + reply)
	talk._who = "Dan"
	var helped := 0
	for i in 40:
		social.rel["Dan"] = -30
		msp.reset()
		t = msp.create_ticket(0, 0, "test")
		talk.ask_help()
		helped += 1 if msp.ticket(t.id).fix_done else 0
	_check(helped < 25, "someone who does not like you mostly does not (%d of 40)" % helped)

	# ---- tips from what is going on
	talk._who = "Alan"
	social.rel["Alan"] = 40
	sales.active = [0, 1]
	msp.backups[1].ok = false
	var xp0: int = sk.xp["servers"]
	var tip: String = talk.tip()
	_check(
		tip.contains(msp.CLIENTS[1].name),
		"Alan warns you about the failing backup: " + tip.substr(0, 50)
	)
	_check(
		sk.xp["servers"] == xp0 + 6 and tip.contains("+6"),
		"a friend also teaches you something (+6 SERVERS XP)"
	)
	talk.tip()
	_check(sk.xp["servers"] == xp0 + 6, "but only once a day")
	talk._who = "Garrison"
	social.rel["Garrison"] = 0
	tip = talk.tip()
	_check(tip.contains("good side"), "a neutral coworker tips but will not teach")
	talk._who = "John"
	social.rel["John"] = 40
	sales.satisfaction[0] = 30
	_check(talk.tip().contains(msp.CLIENTS[0].name), "John tells you who is unhappy")
	talk._who = "Dan"
	social.rel["Dan"] = 0
	var net := root.get_node("Net")
	net.cables["p3"].end = ""
	_check(talk.tip().contains("no network"), "Dan notices a desk without a link")
	net.cables["p3"].end = net.cables["p3"].fixed if net.cables["p3"].has("fixed") else ""
	talk._who = "Alan"
	social.rel["Alan"] = -30
	_check(talk.tip().contains("That is all you are getting"), "a cold coworker is curt")

	# ---- owner: how are you holding up
	c.new_game("owner")
	talk._who = "Alan"
	owner.burnout = 70.0
	var hold: String = talk.holding_up()
	_check(
		hold.contains("burning out") and owner.burnout == 68.0,
		"owner: Alan is honest, and being asked helps"
	)
	talk.holding_up()
	_check(owner.burnout == 68.0, "once a week")
	owner.burnout = 10.0
	talk._who = "Garrison"
	_check(talk.holding_up().begins_with("I am good"), "a rested crew says so")
	owner.flags = {}
	talk._who = "Garrison"
	_check(talk.owner_idea().contains("backup service"), "Garrison pushes the backup service")

	# ---- Free Play stays simple
	c.new_game(c.FREE)
	_check(not talk.available("Alan"), "no conversations in Free Play")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
