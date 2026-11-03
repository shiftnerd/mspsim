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
	for id in story.VIGNETTES:
		_check(scheduled.has(id), "%s is scheduled" % id)
		var v: Dictionary = story.VIGNETTES[id]
		_check(v.options.size() >= 2 and v.options.size() <= 4, "%s has 2-4 options" % id)
		for i in v.options.size():
			var o: Dictionary = v.options[i]
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
