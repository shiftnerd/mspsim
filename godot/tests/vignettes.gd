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
			if str(ev.get("kind", "")) == "vignette":
				scheduled[str(ev.id)] = d
	_check(scheduled.size() == 7, "seven vignettes are on the calendar")
	_check(story.VIGNETTES.size() == 24, "the vignette deck has 24 cards")
	var drawn := 0
	for id in story.VIGNETTES:
		if story.VIGNETTES[id].has("min_day"):
			drawn += 1
			_check(not scheduled.has(id), "%s is drawn from the deck, not on the calendar" % id)
			_check(int(story.VIGNETTES[id].min_day) >= 3, "%s is tagged with an earliest day" % id)
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
