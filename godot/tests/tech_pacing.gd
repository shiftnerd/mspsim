extends SceneTree
# X10 tech pacing: every client ticket counts toward the day's cap, a story / event ticket that can wait is held while the open
# queue is at its cap (order kept, let in at the next free slot, the next morning at the latest), the TICKET PACE setting
# (relaxed / normal / busy) scales the caps and the gap and is saved with the settings, and the pause menu has its row.
# Then a careful bot plays the 20 days at normal: no day above 13 tickets and every scripted story event of every day fired.

const DAY_LIMIT := 13  # "about 12": the cap is 12 and one time-critical story ticket may land on top

var failures := 0
var per_day_tickets := {}
var per_day_fired := {}
var per_day_events := {}
var specials := {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fill(msp: Node, n: int) -> void:
	var c := 0
	while msp.open_tickets().size() < n and c < 40:
		msp.create_problem(c % msp.CLIENTS.size(), msp.PROBLEMS[c % 5], "test", true)
		c += 1


func _close_one(msp: Node) -> void:
	var t: Dictionary = msp.open_tickets()[0]
	t.fix_done = true
	msp.close_ticket(int(t.id))


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var menu := root.get_node("PauseMenu")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Career").toasts = false
	_check(str(diff.settings_path).contains("test_"), "the test writes its own settings file")
	c.new_game("tech")
	diff.set_tier("normal")
	world.time_scale = 0.0
	c.day = 12
	msp.new_day(12)
	world.clock = 11.0

	# ---- the pace setting
	_check(msp.pace_setting == 1 and msp.pace_label() == "NORMAL", "the pace starts at NORMAL")
	_check(msp.day_cap() == 12 and msp.open_cap() == 6, "normal: 12 tickets a day and 6 open on day 12 (today's numbers)")
	var gap_n := 0.0
	var gap_r := 0.0
	var gap_b := 0.0
	for i in 40:
		diff.seed_run(5)
		gap_n += msp.next_spawn_gap()
	msp.set_pace(0)
	_check(msp.day_cap() == 9 and msp.open_cap() == 5, "relaxed: 9 a day, 5 open")
	for i in 40:
		diff.seed_run(5)
		gap_r += msp.next_spawn_gap()
	msp.set_pace(2)
	_check(msp.day_cap() == 15 and msp.open_cap() == 7, "busy: 15 a day, 7 open")
	for i in 40:
		diff.seed_run(5)
		gap_b += msp.next_spawn_gap()
	_check(gap_r > gap_n * 1.2 and gap_b < gap_n * 0.9, "the gap between timed tickets: relaxed longer, busy shorter")
	c.day = 1
	msp.set_pace(0)
	_check(msp.day_cap() == 1 and msp.open_cap() == 2, "relaxed day 1: still one ticket, never under two open")
	c.day = 12
	msp.set_pace(1)
	msp.cycle_pace(1)
	_check(msp.pace_setting == 2, "cycling goes to BUSY")
	msp.pace_setting = 1
	msp.load_pace()
	_check(msp.pace_setting == 2, "the setting is saved with the settings file and read back")
	msp.cycle_pace(-1)
	_check(msp.pace_setting == 1, "and back to NORMAL")

	# ---- the pause menu row (tech campaign only)
	var labels: Array = menu._labels()
	var at := labels.find("TICKET PACE: NORMAL")
	_check(at >= 0 and menu._row_id(at) == "pace", "the pause menu has a TICKET PACE row in the tech campaign")
	_check(str(labels[labels.size() - 1]) == "QUIT TO TITLE" and menu._row_id(labels.size() - 1) == "quit", "QUIT TO TITLE is still the last row")
	var panel: Rect2 = menu._panel()
	var last: Rect2 = menu._row_rect(labels.size() - 1)
	_check(panel.encloses(last) and last.end.y <= panel.end.y - 10.0, "the panel grew with the row: the last row is inside it, above the footer")
	menu._sel = at
	menu._activate()
	_check(msp.pace_setting == 2 and menu._labels().has("TICKET PACE: BUSY"), "Enter on the row changes the pace")
	msp.cycle_pace(-1)

	# ---- every ticket counts toward the day's cap
	msp.reset()
	msp.new_day(12)
	for i in 12:
		var st: Dictionary = msp.create_problem(i % msp.CLIENTS.size(), msp.PROBLEMS[i % 5], "story", true)
		st.fix_done = true
		msp.close_ticket(int(st.id))
	_check(msp.created_today == 12 and msp.spawned_today == 0, "story tickets are counted for the day")
	_check(msp._random_ticket("email").is_empty(), "twelve tickets today: no random one on top")
	msp.new_day(12)
	_check(not msp._random_ticket("email").is_empty(), "a new day: random tickets again")

	# ---- a full queue holds a story ticket; order kept; let in at the next free slot
	msp.reset()
	msp.new_day(12)
	_check(not msp.queue_full(), "an empty queue is not full")
	var now: Dictionary = msp.problem_or_hold(0, msp.ADOBE, "email")
	_check(not now.is_empty() and msp.held.is_empty(), "room in the queue: the story ticket is created at once")
	_fill(msp, 6)
	_check(msp.queue_full(), "six open on day 12: the queue is full")
	var first := {"summary": "First held", "fix": "spooler", "pri": 3, "body": "one - %s"}
	var second := {"summary": "Second held", "fix": "password", "pri": 3, "body": "two - %s"}
	_check(msp.problem_or_hold(1, first, "email").is_empty() and msp.held.size() == 1, "a full queue: the ticket is held, not created")
	msp.return_or_hold({"client": 2, "summary": "Second held", "pri": 3, "body": "two - %s", "fix": "password"})
	_check(msp.held.size() == 2 and msp.held_total == 2, "a second one waits behind it")
	var n0: int = msp.tickets.size()
	msp._tick_held(60.0)
	_check(msp.tickets.size() == n0 and msp.held.size() == 2, "still full: nothing is let in")
	_close_one(msp)
	msp._tick_held(1.0)
	_check(msp.tickets.size() == n0 + 1 and str(msp.tickets[-1].summary) == "First held", "a free slot: the first held ticket comes in")
	_check(msp.held.size() == 1, "the second still waits (the queue is full again)")
	_close_one(msp)
	msp._tick_held(1.0)
	_check(msp.held.size() == 1, "and not within the gap after the first")
	msp._tick_held(msp.HOLD_GAP)
	_check(msp.held.is_empty() and str(msp.tickets[-1].summary) == "Second held", "then the second: order kept")
	# a new arrival does not jump the line
	_fill(msp, 6)
	msp.problem_or_hold(1, first, "email")
	_close_one(msp)
	var jump: Dictionary = msp.problem_or_hold(3, second, "email")
	_check(jump.is_empty() and msp.held.size() == 2 and str(msp.held[0].prob.summary) == "First held", "with one waiting, a new one queues behind it even when there is room")
	msp._tick_held(msp.HOLD_GAP)
	_fill(msp, 6)

	# ---- never lost: the next morning it comes in whatever the queue looks like
	_check(msp.queue_full() and msp.held.size() == 1, "end of the day: one still held, queue full")
	world.clock = world.DAY_END + 0.1
	msp._tick_held(60.0)
	_check(msp.held.size() == 1, "nothing is let in after closing time")
	c.day = 13
	msp.new_day(13)
	world.clock = 9.2
	msp._tick_held(60.0)
	_check(msp.held.size() == 1, "not before 9:30 the next morning while the queue is full")
	world.clock = 9.6
	n0 = msp.tickets.size()
	msp._tick_held(60.0)
	_check(msp.held.is_empty() and msp.tickets.size() == n0 + 1, "9:30 the next morning: it comes in although the queue is full")

	# ---- the resume point keeps the held tickets
	_fill(msp, 6)
	msp.problem_or_hold(1, first, "email")
	var snap: Dictionary = msp.to_dict()
	msp.held.clear()
	msp.from_dict(snap)
	_check(msp.held.size() == 1 and str(msp.held[0].prob.summary) == "First held", "a held ticket survives the mid-day save")

	# ---- other campaigns: no holding, no shared cap
	c.new_game("service")
	msp.reset()
	_fill(msp, 8)
	var sv: Dictionary = msp.problem_or_hold(0, first, "email", true)
	_check(not sv.is_empty() and msp.held.is_empty() and msp.created_today == 0, "the service campaign never holds a ticket")
	_check(not menu._labels().has("TICKET PACE: NORMAL"), "and has no TICKET PACE row")

	# ---- a careful bot plays the campaign at normal
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = 20.0
	msp.ticket_added.connect(_on_ticket)
	process_frame.connect(_watch)
	var r: Dictionary = await bots.play("tech", "normal", "careful", 1)
	process_frame.disconnect(_watch)
	var top := 0
	var row := ""
	for d in range(1, 21):
		top = maxi(top, int(per_day_tickets.get(d, 0)))
		row += "d%d %d  " % [d, int(per_day_tickets.get(d, 0))]
	print("tickets per day: ", row)
	_check(str(r.ending) != "TIMEOUT" and not bool(r.fired), "the careful bot finishes the campaign (rep %s, %s)" % [str(r.rep), str(r.ending)])
	_check(top <= DAY_LIMIT, "no day above %d tickets (busiest %d)" % [DAY_LIMIT, top])
	var missing := []
	for d in range(1, 21):
		if int(per_day_fired.get(d, -1)) != int(per_day_events.get(d, 0)):
			missing.append("d%d %d/%d" % [d, int(per_day_fired.get(d, -1)), int(per_day_events.get(d, 0))])
	_check(missing.is_empty(), "every scripted story event of every day fired %s" % str(missing))
	var beats: bool = specials.has("adobe") and specials.has("install") and specials.has("ransomware")
	_check(beats, "the Adobe job, the desktop install and the ransomware all got their ticket %s" % str(specials.keys()))
	_check(msp.held.is_empty(), "nothing is left held at the end")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func _on_ticket(tk: Dictionary) -> void:
	var d := int(root.get_node("Campaign").day)
	per_day_tickets[d] = int(per_day_tickets.get(d, 0)) + 1
	if str(tk.get("special", "")) != "":
		specials[str(tk.special)] = true


func _watch() -> void:
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	if not c.active or c.mode != "tech":
		return
	var d := int(c.day)
	per_day_events[d] = story.events_on(d).size()
	per_day_fired[d] = maxi(int(per_day_fired.get(d, 0)), story._fired.size())
