extends SceneTree
# Dan's ride-along on days 1-3: the intro card, the steps that follow what the player does, and the way out.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _ids(story: Node, day: int) -> Array:
	var out := []
	for ev in story.events_on(day):
		if str(ev.kind) == "mentor":
			out.append(str(ev.id))
	return out


func _drain(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	var hints := root.get_node("Hints")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	_check(_ids(story, 1).has("mentor_intro") and _ids(story, 2).has("mentor_triage"), "Dan is on the first two days' schedules")
	_check(_ids(story, 3).has("mentor_fix") and _ids(story, 3).has("mentor_debrief"), "and on day 3 twice, the second time a debrief")
	_check(hints._mentor_step() == "", "no steps before he has been asked")

	# the player takes the walk-through
	story._vignette_answer("mentor_intro", "walk")
	_check(str(story.flags.get("mentor", "")) == "on", "WALK ME THROUGH IT turns it on")
	_check(hints._mentor_step() == str(hints.MENTOR.pc), "first step: open the computer")
	root.get_node("Computer").is_open = true
	_check(hints._mentor_step() == str(hints.MENTOR.wait), "computer open, no ticket yet: wait for one")
	root.get_node("Computer").is_open = false
	var t: Dictionary = msp.create_ticket(0, 0, "email")
	_check(hints._mentor_step() == str(hints.MENTOR.take), "a ticket is there: take it")
	t.status = "In Progress"
	_check(hints._mentor_step() == str(hints.MENTOR.fix), "taken: fix it in the RMM")
	t.fix_done = true
	_check(hints._mentor_step() == str(hints.MENTOR.close), "fixed: close it")
	t.status = "Closed"
	msp.closed_ok = 1
	_check(hints._mentor_step() == "" and hints.toast_text == str(hints.MENTOR.done), "closed: a word from Dan and the steps stop")
	_check(hints._mentor_step() == "", "and they stay stopped")

	# the player turns it down: no steps, and he does not come back on days 2 and 3
	c.new_game("tech")
	story._vignette_answer("mentor_intro", "alone")
	_check(str(story.flags.get("mentor", "")) == "off" and hints._mentor_step() == "", "I'VE GOT THIS: no steps")
	_drain(cards)  # the answer itself comes up as a card
	story._vignette("mentor_triage")
	_check(not cards.is_open, "and no card on day 2")
	# taking it: the later cards do open
	c.new_game("tech")
	story._vignette_answer("mentor_intro", "walk")
	_drain(cards)
	story._vignette("mentor_triage")
	_check(cards.is_open and cards.speaker.begins_with("Dan"), "after WALK ME THROUGH IT the day 2 card opens, from Dan")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
