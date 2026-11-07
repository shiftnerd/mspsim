extends SceneTree
# K6: in the owner campaign a karaoke night is a two song set with a bar tab decision between the songs (a round, keep moving, or call it a night).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _pick(cards: Node, id: String) -> void:
	for i in cards.options.size():
		if str(cards.options[i].get("id", "")) == id:
			cards.pick(i)
			return


func _play(o: Node, perfect: bool) -> void:
	o.g.score = o.g.notes.size() * 2 if perfect else 0
	o.g.t = 100.0
	o.tick(0.1)


func _drain(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var cards := root.get_node("Cards")
	var owner := root.get_node("Owner")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	o.enabled = true
	o.use_rooms = false
	root.get_node("World").time_scale = 1.0

	# the tech campaign: one song, no card
	c.new_game("tech")
	_drain(cards)
	o.start("karaoke")
	o.press(KEY_ENTER)
	_play(o, true)
	_check(o.phase == "result" and not cards.is_open, "tech campaign: one song and the result, no bar tab")

	# the owner campaign: song one, the bar tab, a round, song two, the two averaged
	c.new_game("owner")
	_drain(cards)
	o.start("karaoke")
	o.press(KEY_ENTER)
	var first_song := str(o.g.song.id)
	_play(o, true)
	_check(cards.is_open and cards.speaker == "The bar" and o.phase == "play" and o.g.wait, "owner: after song one the bar tab card comes up")
	var cash0: int = owner.cash
	_pick(cards, "round")
	_check(owner.cash == cash0 - o.SET_TAB, "a round costs %d" % o.SET_TAB)
	_check(o.g.encore and int(o.g.first) == 3 and float(o.g.mood) == 80.0 and not o.g.get("wait", false), "song two starts with a warm room")
	_check(str(o.g.song.id) != first_song, "and it is another song (%s, then %s)" % [first_song, str(o.g.song.id)])
	_check(o.phase == "play", "still playing, not at the result")
	_play(o, false)
	_check(o.phase == "result" and o.stars == 2, "3 stars then 0 average to 2 (%d)" % o.stars)
	o.press(KEY_ENTER)

	# keep moving: a normal mood and no charge
	o.start("karaoke")
	o.press(KEY_ENTER)
	_play(o, true)
	var cash1: int = owner.cash
	_pick(cards, "skip")
	_check(owner.cash == cash1 and float(o.g.mood) == 50.0 and o.g.encore, "keep it moving: no charge, a normal room")
	_play(o, true)
	_check(o.phase == "result" and o.stars == 3, "two flawless songs: 3 stars")
	o.press(KEY_ENTER)

	# call it a night: the first song stands
	o.start("karaoke")
	o.press(KEY_ENTER)
	_play(o, true)
	_pick(cards, "stop")
	_check(o.phase == "result" and o.stars == 3, "call it a night: the first song's stars stand")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
