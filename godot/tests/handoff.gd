extends SceneTree
# Michael, a tech at the second cubicle row, takes an ordinary ticket off you when you call him (twice a day at most).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var Calls = load("res://scripts/phone_calls.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	var found := {}
	for k in Calls.contacts():
		if str(k.id) == "michael":
			found = k
	_check(not found.is_empty() and str(found.sub) == "TECH", "Michael is on the phone list")
	world.clock = 11.0
	msp.tickets.clear()
	_check(str(Calls.act(found, "handoff").say).contains("NOTHING I CAN TAKE"), "an empty queue: nothing to take")
	# a story job and an ordinary one: he leaves the story job alone
	var story_t: Dictionary = msp.create_problem(0, msp.ADOBE, "email")
	var plain: Dictionary = msp.create_ticket(0, 0, "email")
	var plain_id := int(plain.id)
	var story_id := int(story_t.id)
	# a fixed seed does not matter here: run it until one of the two outcomes, then check both are sane
	var outcome: Dictionary = Calls.act(found, "handoff")
	var said := str(outcome.say)
	var t: Dictionary = msp.ticket(plain_id)
	var done: bool = str(t.status) == "Closed"
	_check(said.contains("#%d" % plain_id), "he works the ordinary ticket, not the story one (%s)" % said)
	_check(msp.ticket(story_id).status != "Closed", "the story job is still yours")
	_check(done == said.begins_with("GOT IT"), "closed exactly when he says it is done")
	_check(str(t.notes).contains("Michael"), "and the ticket says Michael had it")
	_check(msp.handoffs_today == 1 and not Calls.ready(found), "it counts for the day and he wants a few hours before the next")
	# the daily limit
	msp.handoffs_today = Calls.HANDOFF_MAX
	var call: Dictionary = Calls.open_call(found)
	_check(not call.voicemail and call.opts.size() == 1 and str(call.say).contains("TOMORROW"), "after two he is buried")
	msp.new_day(2)
	_check(msp.handoffs_today == 0, "the count resets in the morning")
	world.clock = world.DAY_END
	_check(bool(Calls.open_call(found).voicemail), "after hours it is his voicemail")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
