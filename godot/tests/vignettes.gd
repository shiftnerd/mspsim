extends SceneTree
# Quiet-day vignettes: each one opens a card, every option applies its effects and closes cleanly.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	c.new_game("tech")
	var scheduled := {}
	for d in story.DAYS:
		for ev in story.DAYS[d]:
			if str(ev.get("kind", "")) in ["vignette", "mentor"]:
				scheduled[str(ev.id)] = d
	for id in ["adam_friday_good", "adam_friday_ok", "adam_friday_bad"]:
		scheduled[id] = 5  # Adam's Friday review picks one of these by the numbers (event kind metrics, days 5, 10, 15)
	_check(scheduled.size() == 15, "fifteen vignettes are on the calendar (eight, Dan and Adam)")
	_check(story.VIGNETTES.size() == 33, "the vignette deck has 33 cards")
	var drawn := 0
	for id in story.VIGNETTES:
		if story.VIGNETTES[id].has("min_day"):
			drawn += 1
			_check(not scheduled.has(id), "%s is drawn from the deck, not on the calendar" % id)
			_check(int(story.VIGNETTES[id].min_day) >= 3, "%s is tagged with an earliest day" % id)
		elif id == "hello":
			_check(not scheduled.has(id), "hello follows Dan's intro card, it has no calendar slot of its own")
		else:
			_check(scheduled.has(id), "%s is scheduled" % id)
	_check(drawn == 17, "17 vignettes are drawn from the deck")
	_check(root.get_node("Events").validate_all().is_empty(), "the deck passes the balance guard")
	for id in story.VIGNETTES:
		var v: Dictionary = story.VIGNETTES[id]
		_check(v.options.size() >= 2 and v.options.size() <= 4, "%s has 2-4 options" % id)
		for i in v.options.size():
			var o: Dictionary = v.options[i]
			root.get_node("World").clock = 10.0  # the hours effects must not run the day out
			for k in story.events_on(c.day).size():
				story._fired[k] = true  # today's own scheduled cards (Dan's intro is at 9:20) must not come up on top
			story.flags["mentor"] = "on"  # Dan's later cards only come up after you took his offer
			story.fire({"kind": "vignette", "id": id})
			await process_frame
			_check(cards.is_open, "%s/%s opens a card" % [id, o.id])
			cards.pick(i)
			await process_frame
			_check(cards.is_open, "%s/%s shows the result" % [id, o.id])
			cards.pick(0)
			await process_frame
			_check(not cards.is_open, "%s/%s closes" % [id, o.id])
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
