extends SceneTree
# gdlint:disable=class-variable-name,expression-not-assigned,max-line-length
# Onsite variety (R11): new job variants per site type, the seeded dispatch roulette (client, job, road event),
# the one-open-job rule, saving and the career counters.

var failures := 0
var V: Variant = null


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 10:
		cards.pick(0)
		guard += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var on := root.get_node("Onsite")
	V = on.Variety
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var d := root.get_node("Difficulty")
	var career := root.get_node("Career")
	var game := root.get_node("Game")
	var hints := root.get_node("Hints")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	career.toasts = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	c.day = 6
	d.seed_run(808)
	await _wait(0.5)

	# ---- the tables
	var old_ids := {}
	for j in on.JOBS + on.MORE_JOBS:
		old_ids[str(j.id)] = true
	var by_site := {}
	for j in V.VARIANT_JOBS:
		_check(not old_ids.has(str(j.id)), "%s is a new id" % j.id)
		old_ids[str(j.id)] = true
		for site in j.sites:
			by_site[site] = int(by_site.get(site, 0)) + 1
			_check((on.OBJECTS[site] as Array).has(str(j.object)), "%s: the %s exists at a %s site" % [j.id, j.object, site])
		_check(j.options.size() == 3, "%s has three ways to do it" % j.id)
		var best := 0.0
		var dud := false
		for o in j.options:
			best = maxf(best, float(o.chance))
			dud = dud or float(o.chance) <= 0.0
			_check(float(o.hours) > 0.0 and str(o.text).length() > 30 and str(o.label).length() > 6, "%s / %s has time and text" % [j.id, o.id])
		_check(best >= 0.85 and dud, "%s has a proper fix and a bad option" % j.id)
		_check(str(j.body).count("%s") == 1 and int(j.pri) in [1, 2, 3], "%s body names the client once" % j.id)
	for site in ["dental", "law", "vet", "trailer"]:
		_check(int(by_site.get(site, 0)) >= 2, "%s has at least two new jobs" % site)
		_check(V.jobs_for(site).size() >= 2, "jobs_for(%s)" % site)
	_check(V.jobs_for("dental").all(func(j: Dictionary) -> bool: return (j.sites as Array).has("dental")), "a site only gets its own variants")
	_check(V.fits({"id": "x"}, "vet") and not V.fits(V.VARIANT_JOBS[0], "vet"), "the old jobs fit everywhere, variants only where they belong")

	# ---- every variant played through
	var fixed0: int = career.value("onsite_fixed")
	var types0: int = career.value("site_types")
	var client_of := {"dental": 0, "law": 3, "vet": 8, "trailer": 10}
	for j in V.VARIANT_JOBS:
		var client: int = int(client_of[str(j.sites[0])])
		var t: Dictionary = on.create_job(client, str(j.id))
		_check(not t.is_empty() and str(t.fix) == "onsite_" + str(j.id), "%s makes a ticket" % j.id)
		_check(str(on.job_for(t).id) == str(j.id), "%s is found again from its ticket" % j.id)
		on.ticket_id = int(t.id)
		on.client = client
		on.job = on.job_for(t)
		on.done = false
		on.active = true
		on._event_done = true
		var tries := 0
		while not on.done and tries < 12:
			on._work()
			_check(cards.is_open and cards.options.size() == 3, "%s offers three options" % j.id) if tries == 0 else null
			cards.pick(0)
			_drain(cards)
			tries += 1
		_check(on.done and str(t.status) == "Closed", "the proper fix closes %s" % j.id)
		on.active = false
	_check(career.value("onsite_fixed") == fixed0 + V.VARIANT_JOBS.size(), "every fix counts for the career")
	_check(career.value("site_types") >= types0 + 4 and career.value("site_types") >= 4, "four site types fixed (%d)" % career.value("site_types"))

	# ---- the roulette
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var repeats := 0
	var last := -1
	var counts := {}
	for i in 600:
		var recent: Array = [last] if last >= 0 else []
		var pick: int = V.pick_client(rng, [0, 1, 3], recent)
		repeats += 1 if pick == last else 0
		counts[pick] = int(counts.get(pick, 0)) + 1
		last = pick
	_check(repeats < 600 / 3 * 0.6, "the client who just called is less likely to call again (%d of 600)" % repeats)
	_check(counts.size() == 3 and int(counts.values().min()) > 80, "every client still calls")
	var pool := [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	var hist := {"a": 6, "b": 0, "c": 0}
	var a_count := 0
	for i in 300:
		a_count += 1 if str(V.pick_job(rng, pool, hist).id) == "a" else 0
	_check(a_count < 60, "jobs you have seen a lot come up less (%d of 300)" % a_count)
	c.day = 9
	on.calls = 0
	var x1: float = on._roulette(1).randf()
	var x2: float = on._roulette(1).randf()
	_check(is_equal_approx(x1, x2), "the roulette is the same for the same day and call")
	on.calls = 1
	_check(not is_equal_approx(x1, on._roulette(1).randf()), "... and changes with the next call")
	c.day = 10
	on.calls = 0
	_check(not is_equal_approx(x1, on._roulette(1).randf()), "... and with the day")

	# ---- the one-open-job rule, and variety over many days
	while true:
		var open := false
		for t in msp.tickets:
			if t.status != "Closed" and on.is_onsite(t):
				open = true
				t.status = "Closed"
		if not open:
			break
	on.recent = []
	on.seen_jobs = {}
	on.calls = 0
	var made: Dictionary = on.create_job()
	_check(not made.is_empty() and on.has_open_job(), "the roulette creates a job when none is open")
	_check(on.create_job().is_empty(), "... and never a second one while it is open")
	var clients := {}
	var jobs := {}
	var run := 0
	var worst_run := 0
	var prev := -1
	for day in range(1, 41):
		for t in msp.tickets:
			if t.status != "Closed" and on.is_onsite(t):
				t.status = "Closed"
		for ep in msp.endpoints:
			ep.problem = ""
		c.day = day
		var t2: Dictionary = on.create_job()
		if t2.is_empty():
			continue
		clients[int(t2.client)] = true
		jobs[str(t2.fix)] = true
		run = run + 1 if int(t2.client) == prev else 1
		worst_run = maxi(worst_run, run)
		prev = int(t2.client)
	_check(clients.size() >= 3, "%d clients called over 40 days" % clients.size())
	_check(jobs.size() >= 8, "%d different jobs over 40 days" % jobs.size())
	_check(worst_run <= 3, "nobody calls more than three times in a row (%d)" % worst_run)
	_check(on.calls >= 30 and on.recent.size() <= 3, "the history is kept short (%d calls)" % on.calls)

	# ---- save and load
	var saved: Dictionary = on.to_dict()
	var calls: int = on.calls
	on.reset()
	_check(on.calls == 0 and on.recent.is_empty() and on.seen_jobs.is_empty(), "reset clears the roulette")
	on.from_dict(saved)
	_check(on.calls == calls and on.seen_jobs.size() == saved.seen.size(), "the roulette history is saved")
	on.from_dict({"visits": 2})
	_check(on.calls == 0 and on.visits == 2, "an old save loads with an empty history")

	# ---- the road
	var events := {}
	var some := 0
	for n in 400:
		var r2 := RandomNumberGenerator.new()
		r2.seed = n
		var ev: Dictionary = V.road_event(r2)
		if not ev.is_empty():
			some += 1
			events[str(ev.id)] = int(ev.min)
	_check(some > 100 and some < 190, "about a third of the drives have something on the road (%d of 400)" % some)
	_check(events.size() == V.ROAD.size(), "every road event can happen")
	var delays := 0
	var gains := 0
	for k in events:
		delays += 1 if int(events[k]) > 0 else 0
		gains += 1 if int(events[k]) < 0 else 0
	_check(delays >= 3 and gains >= 1, "most are delays, a couple are luck")
	# find a day with a delay and drive out on it
	var drive_day := -1
	for day in range(1, 200):
		var r3: RandomNumberGenerator = d.rng_for("onsite.road", day * 100 + on.visits + 1)
		var ev3: Dictionary = V.road_event(r3)
		if not ev3.is_empty() and int(ev3.min) > 0:
			drive_day = day
			break
	_check(drive_day > 0, "a day with a traffic jam exists (day %d)" % drive_day)
	c.day = drive_day
	for t in msp.tickets:
		if t.status != "Closed" and on.is_onsite(t):
			t.status = "Closed"
	for ep in msp.endpoints:
		ep.problem = ""
	var jams0: int = career.value("road_events")
	var expect: Dictionary = V.road_event(d.rng_for("onsite.road", drive_day * 100 + on.visits + 1))
	var tj: Dictionary = on.create_job(0, "dent_cam")
	on.offer(int(tj.id))
	cards.pick(0)
	await _wait(1.2)
	_check(on.active and str(hints.toast_text).find(str(expect.text)) >= 0, "the arrival toast tells you about the road")
	_check(career.value("road_events") == jams0 + 1, "a traffic jam is counted for the career")
	on.interact("door")
	cards.pick(1)
	await _wait(1.2)
	_check(not on.active and not on.busy, "you can drive back")
	# a free trip takes no time and has no road event
	c.active = false
	_check(on._roll_road(0).is_empty(), "a trip outside a campaign has no road event")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
