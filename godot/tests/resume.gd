extends SceneTree
# The mid-day resume point (roadmap R16, headless, no room loaded): run a day to 12:00, snapshot, start something else,
# resume and compare; the story does not refire; a truncated, wrong-day or wrong-version file falls back to the
# day-start Continue (the .bak is tried first); the gate refuses with a card open; the end of the day removes the file;
# the lifecycle notifications write; each mode has its own file. Saves go to user://test_<pid>_*.

var failures := 0
var c: Node
var msp: Node
var world: Node
var cards: Node
var resume: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 30:
		cards.pick(cards.options.size() - 1)
		guard += 1


# a tech run on `day` at 12:00 with a few tickets, closed and open; the end-of-day save of that day is written
func _noon(day: int) -> void:
	c.new_game("tech")
	_drain()
	c.day = day
	if day > 1:
		c.save()
	for k in 3:
		var t: Dictionary = msp.create_ticket(k, 0, "test")
		msp.rmm_action(t.endpoint, "spooler")
		msp.close_ticket(t.id)
	msp.create_ticket(4, 1, "test")
	msp.create_ticket(2, 2, "test")
	world.time_scale = 40.0
	var guard := 0
	while world.clock < 12.0 and guard < 4000:
		_drain()
		await process_frame
		guard += 1
	world.time_scale = 1.0
	_drain()
	await process_frame


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe() -> void:
	for mode in ["tech", "owner"]:
		c.clear_resume(mode)
		DirAccess.remove_absolute(c.save_path(mode))


func _streams() -> Dictionary:
	var out := {}
	var all: Dictionary = root.get_node("Difficulty").to_dict().streams
	for k in all:
		if str(k).begins_with("msp") or str(k) == "events":
			out[k] = all[k]
	return out


func _ticket_view() -> Array:
	var out := []
	for t in msp.tickets:
		out.append([t.id, t.status, t.pri, snappedf(float(t.sla_left), 0.001), t.endpoint, t.fix_done, t.breached])
	return out


func _init() -> void:
	await process_frame
	c = root.get_node("Campaign")
	msp = root.get_node("Msp")
	world = root.get_node("World")
	cards = root.get_node("Cards")
	resume = root.get_node("Resume")
	var story := root.get_node("Story")
	var diff := root.get_node("Difficulty")
	var report := root.get_node("DayReport")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	_wipe()

	# ---- 1. run a day to 12:00, snapshot, resume, compare ----
	await _noon(1)
	_check(c.active and world.clock >= 12.0 and msp.tickets.size() >= 5, "day 1 at noon with tickets (%.2f, %d)" % [world.clock, msp.tickets.size()])
	var want_clock: float = world.clock
	var want_tickets := _ticket_view()
	var want_mails: int = msp.emails.size()
	var want_texts: int = msp.texts.size()
	var want := {"score": msp.score, "rep": c.rep, "cash": c.cash, "closed": msp.closed_ok, "breached": msp.breached}
	var want_streams := _streams()
	var want_fired: Dictionary = story.snapshot().fired
	var want_base: Dictionary = c._base.duplicate()
	var want_lights: Dictionary = world.lights.duplicate()
	var want_next: int = msp._next_id
	_check(c.can_snapshot(), "the gate passes at noon with nothing open")
	_check(c.snapshot() and FileAccess.file_exists(c.resume_path("tech")), "the snapshot is written")
	_check(not FileAccess.file_exists(c.resume_path("tech") + ".tmp"), "no temp file left behind")
	var info: Dictionary = c.resume_info("tech")
	_check(int(info.get("day", 0)) == 1 and absf(float(info.clock) - want_clock) < 0.01, "title info: %s" % str(info))
	var ref_rng: RandomNumberGenerator = diff.rng("msp.tickets")
	var ref_draws := [ref_rng.randf(), ref_rng.randf(), ref_rng.randf()]  # what the uninterrupted run would roll next
	c.new_game("free")  # something else wipes the live state
	_check(msp.tickets.is_empty() and not c.active, "live state wiped by Free Play")
	_check(FileAccess.file_exists(c.resume_path("tech")), "Free Play leaves the tech resume file alone")
	_check(c.continue_game("tech", true), "resume succeeds")
	_drain()
	_check(c.active and c.mode == "tech" and c.day == 1, "the campaign is back")
	_check(absf(world.clock - want_clock) < 0.001 and world.day == 1, "clock back: %.3f" % world.clock)
	_check(_ticket_view() == want_tickets, "every ticket and SLA clock is back (%d)" % msp.tickets.size())
	_check(msp.emails.size() == want_mails and msp.texts.size() == want_texts, "emails and texts back")
	_check(msp._next_id == want_next, "next ticket id back")
	_check(
		msp.score == want.score and c.rep == want.rep and c.cash == want.cash and msp.closed_ok == want.closed and msp.breached == want.breached,
		"score, reputation, cash and counters back"
	)
	var got_streams := _streams()
	var same_streams := true
	for k in want_streams:  # (a stream nobody had touched yet may show up after a load: it sits at its seed)
		same_streams = same_streams and got_streams.get(k, "") == want_streams[k]
	_check(same_streams and want_streams.size() >= 2, "msp stream positions back %s" % str(want_streams.keys()))
	var after_rng: RandomNumberGenerator = diff.rng("msp.tickets")
	_check([after_rng.randf(), after_rng.randf(), after_rng.randf()] == ref_draws, "the next tickets roll exactly as before")
	_check(story.snapshot().fired == want_fired, "story events already fired stay fired (%d)" % want_fired.size())
	_check(c._base == want_base, "the day's starting counts are back (the report needs them)")
	_check(world.lights == want_lights, "lights back")
	var seated := true
	for n in world.chars:
		var st: Dictionary = world.chars[n]
		if st.node != null or st.legs.is_empty() or st.leg_t <= 0.0:
			seated = false
		if st.scene != world.OUTSIDE and st.scene != world.row(n).home:
			seated = false
	_check(seated and world.chars.size() > 0, "the cast is re-planned and back at their desks")
	_check(msp.enabled and not c._awaiting, "service desk running")
	var before_extra: int = msp.emails.size() - msp.tickets.size()
	for i in 20:
		await process_frame
	_check(msp.emails.size() - msp.tickets.size() == before_extra, "no story event fires a second time")
	_check(story.snapshot().fired == want_fired, "still the same events fired")

	# ---- 2. the gate ----
	_check(c.snapshot(), "snapshot again after the resume")
	var before := _read(c.resume_path("tech"))
	cards.ask("Test", "A card is open", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	_check(cards.is_open and not c.can_snapshot() and not c.snapshot(), "the gate refuses with a card open")
	_check(_read(c.resume_path("tech")) == before, "the last good snapshot is kept")
	_drain()
	story.overtime = true
	_check(not c.can_snapshot(), "no snapshot in overtime")
	story.overtime = false
	root.get_node("Game").ui_open = true
	_check(not c.can_snapshot(), "no snapshot with a screen open")
	root.get_node("Game").ui_open = false
	var clock_keep: float = world.clock
	world.clock = world.DAY_END
	_check(not c.can_snapshot(), "no snapshot after closing time")
	world.clock = clock_keep
	_check(c.can_snapshot(), "the gate passes again")
	c.new_game("free")
	_check(not c.can_snapshot() and not c.snapshot(), "Free Play is never saved")

	# ---- 3. truncated, wrong-day, wrong-version files fall back to the day-start Continue ----
	_wipe()
	await _noon(3)
	_check(c.day == 3 and c.has_save("tech") and c.saved_day("tech") == 3, "day 3 with its end-of-day save")
	_check(c.snapshot() and not c.resume_info("tech").is_empty(), "good resume file on day 3")
	var good := _read(c.resume_path("tech"))
	DirAccess.remove_absolute(c.resume_path("tech") + ".bak")  # the hourly writes left one: these cases are about the main file
	_write(c.resume_path("tech"), good.substr(0, good.length() / 2))
	_check(c.resume_info("tech").is_empty(), "a truncated file is not a resume point")
	# cut at a line end inside a section: still no header, so still refused
	var cut := good.find("[resume]")
	_write(c.resume_path("tech"), good.substr(0, cut))
	_check(c.resume_info("tech").is_empty(), "a file cut just before the header is refused")
	c.new_game("free")
	_check(c.continue_game("tech", true) and msp.tickets.is_empty() and world.clock < 9.5, "truncated: Continue falls back to the morning")
	_check(c.day == 3, "the fallback is the saved day")

	_write(c.resume_path("tech"), good)
	_check(not c.resume_info("tech").is_empty(), "restored good file")
	c.day = 4
	c.save()  # the end-of-day save moved on (a later day was finished)
	_check(c.resume_info("tech").is_empty(), "a wrong-day file is refused")
	c.new_game("free")
	_check(c.continue_game("tech", true) and c.day == 4 and msp.tickets.is_empty(), "wrong day: Continue falls back")
	c.day = 3
	c.save()
	_write(c.resume_path("tech"), good.replace("version\": %d" % resume.VERSION, "version\": 99"))
	_check(c.resume_info("tech").is_empty(), "a wrong-version file is refused")
	_write(c.resume_path("tech"), "not a config file at all [[[")
	_check(c.resume_info("tech").is_empty(), "garbage is refused")

	# the .bak: the main file is cut but the one before it is good
	_write(c.resume_path("tech"), good)
	c.active = true
	c.mode = "tech"
	c.new_game("tech")
	_drain()
	c.day = 3
	world.clock = 12.0
	_check(c.snapshot() and c.snapshot() and FileAccess.file_exists(c.resume_path("tech") + ".bak"), "the second write keeps a .bak")
	_write(c.resume_path("tech"), good.substr(0, 40))
	_check(not c.resume_info("tech").is_empty(), "a cut main file falls back to the .bak")

	# ---- 4. lifecycle ----
	_wipe()
	await _noon(2)
	for what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		c.clear_resume("tech")
		resume._notification(what)
		_check(FileAccess.file_exists(c.resume_path("tech")), "notification %d writes the snapshot" % what)
	var kept := _read(c.resume_path("tech"))
	cards.ask("Test", "A card is open", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	resume._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_read(c.resume_path("tech")) == kept, "an unsafe moment keeps the last good snapshot")
	_drain()
	var pm := root.get_node("PauseMenu")
	c.clear_resume("tech")
	pm.open()
	_check(FileAccess.file_exists(c.resume_path("tech")), "opening the pause menu writes the snapshot")
	resume._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not pm.is_open and not paused, "back from the pause menu resumes the game")
	resume._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not pm.is_open, "back outside a room does not open the pause menu")

	# the hourly trigger: crossing an hour writes one
	c.clear_resume("tech")
	world.clock = 12.95
	c._last_hour = 12
	world.time_scale = 40.0
	for i in 600:
		if FileAccess.file_exists(c.resume_path("tech")):
			break
		await process_frame
	world.time_scale = 1.0
	_check(FileAccess.file_exists(c.resume_path("tech")) and int(c.resume_info("tech").clock) >= 13, "crossing 13:00 writes the hourly snapshot")

	# ---- 5. one file per mode ----
	_check(c.resume_path("tech") != c.resume_path("owner") and c.resume_path("tech").ends_with("tech_resume.cfg"), "paths per mode")
	_check(c.resume_path("tech") != c.save_path("tech"), "the resume file is not the end-of-day save")
	_write(c.resume_path("owner"), "keep me")
	c.clear_resume("owner")
	_check(FileAccess.file_exists(c.resume_path("tech")) and not FileAccess.file_exists(c.resume_path("owner")), "clearing one mode leaves the other")
	c.save_prefix = c.save_prefix + "other_"
	_check(not FileAccess.file_exists(c.resume_path("tech")), "another prefix is another campaign")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- 6. the end of the day removes the file ----
	_check(c.snapshot() and FileAccess.file_exists(c.resume_path("tech")), "a resume file before closing time")
	_check(c.snapshot(), "second write for a .bak")
	world.clock = world.DAY_END
	await process_frame
	await process_frame
	_check(report.is_open, "closing time shows the report")
	report.finish()
	await create_timer(0.8).timeout
	_check(
		not FileAccess.file_exists(c.resume_path("tech")) and not FileAccess.file_exists(c.resume_path("tech") + ".bak"),
		"the end of the day removes the resume file and its .bak"
	)
	_check(c.has_save("tech") and c.saved_day("tech") == 3, "the end-of-day save moved on")
	_drain()

	# a new game removes it too
	await _noon(1)
	_check(c.snapshot(), "snapshot on a new run")
	c.new_game("tech")
	_check(not FileAccess.file_exists(c.resume_path("tech")), "a new game removes the old resume file")

	_wipe()
	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
