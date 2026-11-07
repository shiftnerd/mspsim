extends SceneTree
# Adam's Friday review (days 5, 10, 15): one of three cards by the last five days of the metrics record, with the numbers in his text.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1


func _days(msp: Node, opened: int, closed: int, missed: int) -> void:
	msp.Dash.days = []
	for d in range(1, 6):
		var e: Dictionary = msp.Dash.blank(d)
		e.opened = opened
		e.closed = closed
		e.missed = missed
		msp.Dash.days.append(e)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	for d in [5, 10, 15]:
		var has := false
		for ev in story.events_on(d):
			has = has or str(ev.kind) == "metrics"
		_check(has, "day %d has Adam's review" % d)
	_check(story.friday_card({"missed": 0, "backlog": 2}) == "adam_friday_good", "no misses and a short queue: the good card")
	_check(story.friday_card({"missed": 2, "backlog": 5}) == "adam_friday_ok", "a couple of misses: the middling card")
	var bad_a: String = story.friday_card({"missed": 3, "backlog": 2})
	var bad_b: String = story.friday_card({"missed": 0, "backlog": 6})
	_check(bad_a == "adam_friday_bad" and bad_b == "adam_friday_bad", "many misses or a long queue: the bad card")
	_drain(cards)

	# the numbers come from the metrics record and show up in his text
	_days(msp, 12, 11, 2)
	msp.tickets.clear()
	var stats: Dictionary = story.week_stats()
	_check(int(stats.closed) == 55 and int(stats.missed) == 10 and int(stats.opened) == 60, "the week is the last five days of the record (%s)" % str(stats))
	story._friday()
	_check(cards.is_open and cards.speaker.begins_with("Adam") and cards.text.contains("55 closed") and cards.text.contains("10 missed"), "the bad week: Adam asks why, with the numbers")
	var rep0: int = c.rep
	var volume := 0
	for i in cards.options.size():
		if str(cards.options[i].id) == "volume":
			volume = i
	cards.pick(volume)
	_check(c.rep == rep0 - 1, "blaming the volume costs a point of reputation")
	_drain(cards)

	_days(msp, 12, 12, 0)
	story._friday()
	_check(cards.is_open and cards.text.contains("clean board"), "a clean week: the good card")
	_drain(cards)

	_days(msp, 0, 0, 0)
	story._friday()
	_check(not cards.is_open, "an empty board: nothing to read, no card")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
