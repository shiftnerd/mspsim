extends SceneTree
# K8: on a call week a pager chime can interrupt a karaoke song (a quarter of them); ignoring it costs nothing and the call waits in the queue.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var diff := root.get_node("Difficulty")
	var shift := root.get_node("Shift")
	var msp := root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	shift.enabled = true
	var call_day := 0
	var quiet_day := 0
	for d in range(2, 21):
		if shift.on_call(d) and call_day == 0:
			call_day = d
		if not shift.on_call(d) and quiet_day == 0:
			quiet_day = d
	_check(call_day > 0 and quiet_day > 0, "the campaign has call weeks (day %d) and quiet ones (day %d)" % [call_day, quiet_day])
	# a quiet week: never
	c.day = quiet_day
	var quiet := 0
	for s in 40:
		diff.seed_run(100 + s)
		o._kara_setup()
		quiet += 1 if float(o.g.pager_at) > 0.0 else 0
	_check(quiet == 0, "no pager on a quiet week (%d of 40)" % quiet)
	# a call week: some songs, not all
	c.day = call_day
	var paged := 0
	for s in 60:
		diff.seed_run(200 + s)
		o._kara_setup()
		paged += 1 if float(o.g.pager_at) > 0.0 else 0
	_check(paged >= 5 and paged <= 30, "on a call week about a quarter of the songs get a pager chime (%d of 60)" % paged)
	# the chime: at its time, a flash and a flag; at the end, a ticket and a text, no penalty
	diff.seed_run(1)
	o._kara_setup()
	o.g.pager_at = 1.0
	o._kara_tick(0.5)
	_check(not o.g.paged, "before its time nothing happens")
	o._kara_tick(0.6)
	_check(o.g.paged and str(o.g.flash).begins_with("PAGER"), "at its time the pager goes off (%s)" % str(o.g.flash))
	var tickets0: int = msp.tickets.size()
	var texts0: int = msp.texts.size()
	var rep0: int = c.rep
	o._kara_end()
	_check(msp.texts.size() == texts0 + 1 and str(msp.texts[0].body).contains("pager"), "afterwards a text says the page is waiting")
	_check(msp.tickets.size() >= tickets0 and c.rep == rep0, "and ignoring it cost no reputation")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
