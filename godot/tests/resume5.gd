extends SceneTree
# gdlint:disable=max-returns,max-line-length
# Resume point step 5 (roadmap R16): save, quit, reload round trips that end in the same state for
#  1. a Playbook job in progress (tech), 2. an onsite visit (standing at the client site, with the room loaded),
#  3. the owner, service and sales campaigns in the middle of their day / week.
# "Quit" is Free Play wiping the live state; the reload is Campaign.continue_game(mode, true).
# Saves go to user://test_<pid>_*.

var failures := 0
var c: Node
var msp: Node
var world: Node
var cards: Node
var resume: Node
var game: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 40:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _scene() -> String:
	var sc := current_scene
	return "" if sc == null else sc.scene_file_path.get_file().get_basename()


func _wipe() -> void:
	for mode in c.MODES:
		c.clear_resume(mode)
		DirAccess.remove_absolute(c.save_path(mode))


func _ticket_view() -> Array:
	var out := []
	for t in msp.tickets:
		out.append([t.id, t.status, t.pri, snappedf(float(t.sla_left), 0.001), t.endpoint, t.fix_done, t.breached])
	return out


# deep compare with a float tolerance; returns the first path that differs ("" = equal)
func _diff(a: Variant, b: Variant, path := "") -> String:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return "%s (size %d / %d)" % [path, a.size(), b.size()]
		for k in a:
			if not b.has(k):
				return "%s/%s (missing)" % [path, str(k)]
			var d := _diff(a[k], b[k], "%s/%s" % [path, str(k)])
			if d != "":
				return d
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s (size %d / %d)" % [path, a.size(), b.size()]
		for i in a.size():
			var d := _diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if (a is float or a is int) and (b is float or b is int):
		return "" if absf(float(a) - float(b)) < 0.0005 else "%s (%s / %s)" % [path, str(a), str(b)]
	return "" if a == b else "%s (%s / %s)" % [path, str(a), str(b)]


func _run_to(hour: float) -> void:
	world.time_scale = 40.0
	var guard := 0
	while world.clock < hour and guard < 6000 and c.active:
		_drain()
		await process_frame
		guard += 1
	world.time_scale = 1.0
	_drain()
	await process_frame
	_drain()


func _init() -> void:
	await process_frame
	c = root.get_node("Campaign")
	msp = root.get_node("Msp")
	world = root.get_node("World")
	cards = root.get_node("Cards")
	resume = root.get_node("Resume")
	game = root.get_node("Game")
	var pb := root.get_node("Playbook")
	var on := root.get_node("Onsite")
	var report := root.get_node("DayReport")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	root.get_node("Difficulty").set_tier("normal")
	root.get_node("Difficulty").seed_run(11)
	_wipe()

	# ---- 1. a Playbook job in progress ----
	c.new_game("tech")
	_drain()
	c.day = 6
	c.save()
	await _run_to(10.5)
	var tid: int = pb.start("rack")
	pb.choose(1)
	pb.choose(0)
	_check(pb.is_active() and int(pb.active.step) == 2 and tid > 0, "a rack job is two steps in")
	_check(c.can_snapshot(), "the gate passes with a Playbook job open")
	var want_job: Dictionary = pb.active.duplicate(true)
	var want_tickets := _ticket_view()
	var want_clock: float = world.clock
	var want_score: int = msp.score
	_check(c.snapshot(), "snapshot with the job open")
	c.new_game("free")
	_check(not pb.is_active() and msp.tickets.is_empty(), "quit: the job and the queue are gone")
	_check(c.continue_game("tech", true), "reload")
	_drain()
	_check(_diff(want_job, pb.active) == "", "the job is back at the same step with its points, flags and log %s" % _diff(want_job, pb.active))
	_check(_ticket_view() == want_tickets and msp.score == want_score, "the queue (with the job's tickets) and the score are back")
	_check(absf(world.clock - want_clock) < 0.001 and c.day == 6, "same clock and day")
	var steps: int = pb.steps_of("rack").size()
	var guard := 0
	while pb.is_active() and guard < steps + 2:
		pb.choose(0)
		guard += 1
	_drain()
	_check(not pb.is_active() and bool(pb.active.get("done", false)), "the resumed job can be finished")

	# ---- 2. an onsite visit (the room is loaded) ----
	_wipe()
	c.new_game("tech")
	_drain()
	c.day = 6
	c.save()
	game.go("main_floor", "start")
	await _wait(1.0)
	_drain()
	world.clock = 10.0  # the gate wants office hours, and the drive adds its minutes
	var other: Dictionary = msp.create_ticket(0, 0, "email")
	var t: Dictionary = on.create_job(0, "switch")
	on.offer(int(t.id))
	cards.pick(0)
	await _wait(1.2)
	_drain()
	_check(_scene() == "site_dental_a" and on.active and on.busy, "you are at the dental office")
	var p: Node = root.get_node("Players").player0(current_scene)
	p.position.x += 23.0
	var want_x: float = p.position.x
	_check(c.can_snapshot(), "the gate passes at the site with nothing open")
	var want_deep: Dictionary = resume.deep_dict().Onsite.duplicate(true)
	want_tickets = _ticket_view()
	want_clock = world.clock
	_check(c.snapshot(), "snapshot at the site")
	_check(str(c.resume_info("tech").get("text", "")) != "", "the title has a line for it")
	c.new_game("free")
	game.go("main_floor", "start")
	await _wait(1.0)
	_check(not on.active and _scene() == "main_floor", "quit: back in a plain office")
	world.time_scale = 1.0
	_check(c.continue_game("tech", true), "reload")
	game.go(c.start_scene(), "start")
	await _wait(1.2)
	_check(_scene() == "site_dental_a", "the run opens at the client site again (%s)" % _scene())
	_check(on.active and on.busy and int(on.ticket_id) == int(t.id) and int(on.client) == 0, "the visit is on, same ticket and client")
	var got_deep: Dictionary = resume.deep_dict().Onsite
	want_deep.erase("_prev_msp")
	want_deep.erase("_prev_scale")
	got_deep.erase("_prev_msp")
	got_deep.erase("_prev_scale")
	_check(_diff(want_deep, got_deep) == "", "every onsite field is back %s" % _diff(want_deep, got_deep))
	_check(_ticket_view() == want_tickets and absf(world.clock - want_clock) < 0.001, "same queue and clock")
	_check(not msp.enabled and world.time_scale == 0.0, "the office is frozen while you are out")
	p = root.get_node("Players").player0(current_scene)
	_check(p != null and absf(p.position.x - want_x) < 0.5, "you stand where you stood (x %.1f, wanted %.1f)" % [p.position.x if p != null else -1.0, want_x])
	var staff := 0
	for n in get_nodes_in_group("npcs"):
		staff += 1 if str(n.role) == "site:staff" else 0
	_check(staff == 2, "the client's staff is there")
	game.go("site_dental_closet_a", "from_office")
	await _wait(1.0)
	on.interact("cabinet")
	_check(cards.is_open, "the job can be worked after the resume")
	cards.pick(0)
	_drain()
	t = msp.ticket(int(on.ticket_id))
	_check(on.done and str(t.status) == "Closed", "and finished")
	on.interact("door")
	await _wait(1.2)
	_drain()
	_check(not on.active and not on.busy and msp.enabled and world.time_scale == 1.0 and _scene() == "main_floor", "the drive home starts the office again")
	_check(other.is_empty() == false, "the other ticket object exists")

	# the drive itself is refused: busy without being there
	on.busy = true
	on.active = false
	_check(not c.can_snapshot(), "no snapshot while driving")
	on.busy = false
	current_scene.queue_free()
	await process_frame

	# ---- 3. owner, service and sales in the middle of their day / week ----
	for mode in ["owner", "service", "sales"]:
		_wipe()
		c.new_game(mode)
		_drain()
		await _run_to(10.0)
		_drain()
		# a second unit, so the end-of-unit save exists and the resume point is of a later one
		world.clock = world.DAY_END
		guard = 0
		while not report.is_open and guard < 600:
			_drain()
			await process_frame
			guard += 1
		_check(report.is_open, "%s: the first %s ends" % [mode, str(c.prop("unit", "DAY")).to_lower()])
		report.finish()
		await _wait(0.8)
		_drain()
		await _run_to(12.5)
		_check(c.active and c.day == 2 and world.clock >= 12.5, "%s: unit 2 at %.2f" % [mode, world.clock])
		guard = 0
		while not c.can_snapshot() and guard < 200:
			_drain()
			await process_frame
			guard += 1
		_check(c.can_snapshot(), "%s: the gate passes mid-unit" % mode)
		var want: Dictionary = resume.deep_dict().duplicate(true)
		var want_main := {"clock": world.clock, "rep": c.rep, "cash": c.cash, "score": msp.score, "day": c.day}
		want_tickets = _ticket_view()
		var want_mail: int = msp.emails.size()
		_check(c.snapshot() and FileAccess.file_exists(c.resume_path(mode)), "%s: snapshot written" % mode)
		var info: Dictionary = c.resume_info(mode)
		_check(int(info.get("day", 0)) == 2 and bool(c.slot_info(mode, 1).has_resume), "%s: the title sees it (%s)" % [mode, str(info)])
		c.new_game("free")
		_check(not c.active and msp.tickets.is_empty(), "%s: quit" % mode)
		_check(c.continue_game(mode, true), "%s: reload" % mode)
		var got_main := {"clock": world.clock, "rep": c.rep, "cash": c.cash, "score": msp.score, "day": c.day}
		_check(_diff(want_main, got_main) == "", "%s: clock, reputation, cash, score and unit are back %s" % [mode, _diff(want_main, got_main)])
		_check(_ticket_view() == want_tickets and msp.emails.size() == want_mail, "%s: the queue and the mail are back (%d tickets)" % [mode, want_tickets.size()])
		var d := _diff(want, resume.deep_dict())
		_check(d == "", "%s: every field of the mode's state is back %s" % [mode, d])
		_check(c.mode == mode and c.active and not cards.is_open, "%s: running, no day-begin card a second time" % mode)
		# and it plays on to the end of the unit
		guard = 0
		while not report.is_open and guard < 6000:
			_drain()
			if on.active and not cards.is_open:
				on._go_home(false)  # a card of the week sent you to a client: the resume point was at their office
			world.time_scale = 40.0
			await process_frame
			guard += 1
		world.time_scale = 1.0
		_check(report.is_open, "%s: the resumed unit ends in its report (clock %.2f, scale %.1f, card %s, ui %s, outing %s)" % [mode, world.clock, world.time_scale, str(cards.is_open), str(game.ui_open), str(root.get_node("Outings").busy())])
		report.finish()
		await _wait(0.8)
		_drain()
		_check(c.day == 3 and not FileAccess.file_exists(c.resume_path(mode)), "%s: the next unit starts and the resume point is gone" % mode)

	# ---- 4. the title menu: a service slot with both saves offers CONTINUE (the resume point) and starts it
	_wipe()
	c.new_game("service")
	_drain()
	world.clock = world.DAY_END
	guard = 0
	while not report.is_open and guard < 600:
		_drain()
		await process_frame
		guard += 1
	report.finish()
	await _wait(0.8)
	_drain()
	await _run_to(11.0)
	guard = 0
	while not c.can_snapshot() and guard < 200:
		_drain()
		await process_frame
		guard += 1
	_check(c.snapshot() and c.has_save("service"), "service day 2: an end-of-day save and a resume point")
	var saved_clock: float = world.clock
	game.title_mode = true
	change_scene_to_file("res://scenes/title.tscn")
	for i in 5:
		await process_frame
	var title: Node = current_scene
	title._open_menu()
	title._enter_slot("service", 1)
	var ids: Array = title._items.map(func(i: Dictionary) -> String: return str(i.id))
	_check(title._level == "slot" and ids == ["service_resume", "service_continue"], "the slot offers the resume point first: %s" % str(ids))
	_check(str(title._items[0].label).begins_with("CONTINUE - DAY 2  11:"), "its label has the day and the time (%s)" % str(title._items[0].label))
	c.new_game("free")
	title._choose(0)
	await _wait(1.0)
	_drain()
	_check(c.active and c.mode == "service" and c.day == 2 and world.clock >= saved_clock and world.clock < saved_clock + 0.5, "CONTINUE resumes the service day at %.2f (saved %.2f)" % [world.clock, saved_clock])
	_check(_scene() != "title" and _scene() != "", "in a room (%s)" % _scene())

	_wipe()
	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
