extends SceneTree
# gdlint:disable=max-line-length
# X13 (X10 leftover): a Playbook job is never held, so it used to land on a full queue (day 10's rack job is three tickets: nine
# open against a cap of six). Now the ordinary timed ticket in front of a job waits when one more ticket would let the job push
# the open queue more than Msp.JOB_OVER over its cap; the job itself comes on time whatever the queue looks like, and the
# ransomware and a ringing call are not touched.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/job_squeeze.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fill(msp: Node, n: int) -> void:
	var c := 0
	while msp.open_tickets().size() < n and c < 40:
		msp.create_problem(c % msp.CLIENTS.size(), msp.PROBLEMS[c % 5], "test", true)
		c += 1


func _close_all(msp: Node) -> void:
	for t in msp.open_tickets():
		t.fix_done = true
		msp.close_ticket(int(t.id))


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var story := root.get_node("Story")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var pb := root.get_node("Playbook")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_jobsq_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Career").toasts = false
	diff.seed_run(7)
	c.new_game("tech")
	diff.set_tier("normal")
	msp.set_pace(1)
	world.time_scale = 0.0

	# ---- the job days of the campaign: the biggest job that lands on a day with an open cap it can overfill
	var day := 0
	var at := 0.0
	var index := -1
	var n := 0
	var days := []
	for d in range(1, 21):
		var events: Array = story.events_on(d)
		for i in events.size():
			if str(events[i].kind) == "playbook":
				var size: int = pb.PROBLEMS[str(events[i].book)].size()
				days.append("d%d %s x%d at %.1f" % [d, str(events[i].book), size, float(events[i].at)])
				if size > n:
					n = size
					day = d
					at = float(events[i].at)
					index = i
	_check(n >= 3, "the campaign has a job of three tickets or more (%s)" % ", ".join(days))
	c.day = day
	story.begin_day(day)
	var cap: int = msp.open_cap()
	var edge: int = cap + msp.JOB_OVER - n  # with this many open, one more ticket and the job make cap + JOB_OVER + 1
	_check(edge < cap and edge >= 1, "day %d: cap %d, the job brings %d: the timed tickets wait from %d open on" % [day, cap, n, edge])

	# ---- the look-ahead
	world.clock = at - msp.JOB_AHEAD - 0.5
	_check(story.job_due(msp.JOB_AHEAD) == 0, "more than %.1f hours before the job nothing is due" % msp.JOB_AHEAD)
	_fill(msp, edge)
	_check(not msp.job_squeeze(), "so the timed tickets come as usual")
	world.clock = at - 1.0
	_check(story.job_due(msp.JOB_AHEAD) == n, "an hour before, the job and its size are known (%d)" % story.job_due(msp.JOB_AHEAD))
	_check(msp.job_squeeze(), "with %d open the next timed ticket waits" % edge)
	_close_all(msp)
	_fill(msp, edge - 1)
	_check(not msp.job_squeeze(), "with %d open there is room for one more and the job" % (edge - 1))

	# ---- the real clock: the timed spawn is skipped, not lost
	_fill(msp, edge)
	world.time_scale = 1.0
	var open0: int = msp.open_tickets().size()
	var calls0: int = msp.calls.size()
	msp._spawn_t = 0.01
	msp._process(0.05)
	_check(msp.open_tickets().size() == open0 and msp.calls.size() == calls0 and msp.squeezed_total == 1, "the timed ticket's turn passes without a ticket or a call (squeezed %d)" % msp.squeezed_total)
	_check(msp._spawn_t > 5.0, "and the timer runs again for the next one (%.0f s)" % msp._spawn_t)
	var spawned0: int = msp.spawned_today
	_close_all(msp)
	_fill(msp, edge - 1)
	open0 = msp.open_tickets().size()
	calls0 = msp.calls.size()
	msp._spawn_t = 0.01
	msp._process(0.05)
	_check(msp.open_tickets().size() + msp.calls.size() == open0 + calls0 + 1 and msp.squeezed_total == 1, "one fewer open: the timed ticket (or its call) comes (open %d, calls %d, spawned %d -> %d)" % [msp.open_tickets().size(), msp.calls.size(), spawned0, msp.spawned_today])
	world.time_scale = 0.0

	# ---- the job is never delayed: on a queue at its cap it still lands whole, and nothing is held
	msp.calls.clear()
	_close_all(msp)
	_fill(msp, cap)
	world.clock = at
	story._fired[index] = true
	story.fire(story.events_on(day)[index])
	var guard := 0
	while cards.is_open and guard < 10:
		cards.pick(0)
		guard += 1
	_check(pb.is_active() and msp.open_tickets().size() == cap + n and msp.held.is_empty(), "the job lands on time on a full queue (%d open, cap %d), nothing held" % [msp.open_tickets().size(), cap])
	_check(story.job_due(msp.JOB_AHEAD) == 0 and not msp.job_squeeze(), "once it has landed the timed tickets follow the cap alone")

	# ---- a day the careful way: with the queue kept at the edge the job tops out at cap + JOB_OVER
	_close_all(msp)
	if pb.is_active():
		pb.reset()
	story.begin_day(day)
	world.clock = at - 1.0
	world.time_scale = 1.0
	_fill(msp, cap - 1)
	var top := 0
	for step in 400:
		msp._spawn_t = minf(msp._spawn_t, 0.01)  # every step is a timed ticket's turn
		msp._process(0.05)
		msp.calls.clear()
		if msp.open_tickets().size() > edge:  # the tech closes down to the edge between turns
			var t: Dictionary = msp.open_tickets()[0]
			t.fix_done = true
			msp.close_ticket(int(t.id))
		top = maxi(top, msp.open_tickets().size())
	world.time_scale = 0.0
	story._fired[index] = true
	story.fire(story.events_on(day)[index])
	guard = 0
	while cards.is_open and guard < 10:
		cards.pick(0)
		guard += 1
	_check(msp.open_tickets().size() <= cap + msp.JOB_OVER, "an hour of timed turns before the job, then the job: %d open (cap %d + %d)" % [msp.open_tickets().size(), cap, msp.JOB_OVER])

	# ---- other modes and Free Play are not paced
	c.new_game("owner")
	_check(not msp.job_squeeze() and story.job_due(24.0) == 0, "the owner campaign has no such wait")
	c.new_game(c.FREE)
	_check(not msp.job_squeeze(), "nor has Free Play")

	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
