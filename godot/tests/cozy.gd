extends SceneTree
# gdlint:disable=max-line-length
# Cozy Easy (roadmap R16): the Easy tier inside a campaign is the cozy mode. Never fired in any mode, one bailout, no SLA / reopen /
# pay / reputation losses, no energy trouble, a safe commute, a report without minus lines, the DAY LENGTH option, the medal rule.
# Normal must behave as before. Headless.

var failures := 0
var d: Node
var c: Node
var msp: Node
var shift: Node
var cards: Node
var world: Node
var sales: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fresh(mode: String, tier: String) -> void:
	d.set_tier(tier)
	d.seed_run(5)
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Game").ui_open = false
	root.get_node("Build").pending = {}
	shift.enabled = mode == "tech"
	c.new_game(mode)
	root.get_node("Career").toasts = false
	while cards.is_open:
		cards.pick(0)


func _day(n: int) -> void:
	c.day = n
	c._begin_day()
	while cards.is_open:
		cards.pick(0)


func _close_day_now() -> void:
	# the end of a day without waiting for the clock: drain the stay-late card, then let the campaign close it
	world.clock = world.DAY_END
	for i in 6:
		await process_frame
		if cards.is_open:
			cards.pick(0)
	if not root.get_node("DayReport").is_open:
		c._end_day()
	await process_frame


func _init() -> void:
	await process_frame
	d = root.get_node("Difficulty")
	c = root.get_node("Campaign")
	msp = root.get_node("Msp")
	shift = root.get_node("Shift")
	cards = root.get_node("Cards")
	world = root.get_node("World")
	sales = root.get_node("Sales")
	var report := root.get_node("DayReport")
	var career := root.get_node("Career")
	c.save_prefix = "user://test_cozy_%d_" % OS.get_process_id()

	# ---- the one switch
	d.set_tier("easy")
	_check(d.cozy_chosen() and not d.cozy_on(), "easy outside a campaign: chosen, not on")
	_check(d.cz("sla_window", 1.0) == 1.0 and d.sla_scale() == 1.0, "no cozy numbers outside a campaign")
	_fresh("tech", "easy")
	_check(d.cozy_on() and d.cz("rep_floor", 0.0) == 15.0 and is_equal_approx(d.sla_scale(), 1.6), "easy in a campaign is cozy (SLA windows x1.6)")
	_fresh("tech", "normal")
	_check(not d.cozy_on() and d.cz("rep_floor", 0.0) == 0.0 and d.sla_scale() == 1.0, "normal is not cozy")
	_check(d.cozy_tag() == "" and d.ct("probation_tech") != "", "no tag on normal, the texts exist")

	# ---- never fired, in every mode (reputation forced to 0); normal still fires
	for mode in ["tech", "service", "owner", "sales"]:
		_fresh(mode, "easy")
		c.rep = -20
		c._end_day()
		var r: Dictionary = report.report
		_check(not bool(r.fired) and c.rep >= 15 and not bool(r.final) and bool(r.get("cozy", false)), "%s easy: rep 0 is not fired (rep %d)" % [mode, c.rep])
		_check((r.get("notes", []) as Array).size() >= 1 and str(r.notes[0]) == d.ct("probation_note"), "%s easy: a PROBATION line on the report" % mode)
		_check(str(msp.texts[0].body) == d.ct("probation_" + mode), "%s easy: the probation text arrived" % mode)
		report.finish()
		while cards.is_open:
			cards.pick(0)
		await process_frame
		_fresh(mode, "normal")
		c.rep = -20
		c._end_day()
		_check(bool(report.report.fired) and bool(report.report.final), "%s normal: rep 0 still fires" % mode)
		report.is_open = false

	# ---- the bailout: once, flagged against the valuation (owner and sales)
	for mode in ["owner", "sales"]:
		_fresh(mode, "easy")
		var o := root.get_node("Owner")
		o.cash = -9000
		c._end_day()
		var r2: Dictionary = report.report
		_check(not bool(r2.fired) and not bool(r2.get("bankrupt", false)), "%s easy: bankrupt books are not the end" % mode)
		_check(o.bailout == 2000 and o.cash > -9000 + 1500, "%s easy: the bailout paid %d (cash %d)" % [mode, o.bailout, o.cash])
		_check(cards.is_open or cards.waiting() > 0, "%s easy: a bailout card from the bank" % mode)
		report.is_open = false
		while cards.is_open:
			cards.pick(0)
		o.cash = -9000
		c._end_day()
		_check(o.bailout == 2000 and o.cash <= -9000 + 1000 and not bool(report.report.fired), "%s easy: only one bailout per run (cash %d)" % [mode, o.cash])
		report.is_open = false
		_fresh(mode, "normal")
		o.cash = -9000
		c._end_day()
		_check(bool(report.report.fired) and o.bailout == 0, "%s normal: bankruptcy still ends the run" % mode)
		report.is_open = false
	_fresh("owner", "easy")
	var ow := root.get_node("Owner")
	ow.cash = 20000
	var v0: int = ow.valuation()
	ow.bailout = 2000
	_check(ow.valuation() == v0 - 2000, "the valuation does not count the bailout")
	var saved: Dictionary = ow.to_dict()
	ow.bailout = 0
	ow.from_dict(saved)
	_check(ow.bailout == 2000, "the bailout flag is saved")

	# ---- SLA, reopens, pay and reputation losses
	var mood_drop := {}
	var scars := {}
	var pays := {}
	var reps := {}
	for tier in ["easy", "normal"]:
		_fresh("tech", tier)
		_day(12)
		var t: Dictionary = msp.create_ticket(2, 0, "test")
		t.pri = 1
		var before: int = sales.mood(int(t.client))
		t.sla_left = 0.1
		world.time_scale = 1.0
		msp._process(1.0)
		mood_drop[tier] = before - sales.mood(int(t.client))
		scars[tier] = c.scars
		_check(t.breached and msp.breached == 1, "%s: the ticket breached" % tier)
		var t2: Dictionary = msp.create_ticket(3, 1, "test")
		var m2: int = sales.mood(int(t2.client))
		msp.close_ticket(t2.id)  # not fixed: reopened
		mood_drop[tier + "_reopen"] = m2 - sales.mood(int(t2.client))
		var rep_r: Dictionary = c.make_report()
		pays[tier] = rep_r.pay
		reps[tier] = rep_r.rep_delta
		_check(rep_r.missed == 1 and rep_r.reopened == 1 and rep_r.open_left >= 1, "%s: the counts are honest (missed %d reopened %d open %d)" % [tier, rep_r.missed, rep_r.reopened, rep_r.open_left])
	_check(mood_drop.easy == 2 and mood_drop.normal == 8, "SLA breach: client mood -2 on easy, -8 on normal (%s)" % str(mood_drop))
	_check(mood_drop.easy_reopen == 1 and mood_drop.normal_reopen == 6, "reopen: client mood -1 on easy, -6 on normal")
	_check(scars.easy == 0 and scars.normal == 2, "no scar for an unworked P1 on easy, one on normal (%s)" % str(scars))
	_check(pays.easy == 100 and pays.normal == 100 - 25 - 10, "no pay lost to a miss or a reopen on easy (%s)" % str(pays))
	_check(reps.easy == 0 and reps.normal < 0, "no reputation lost to a miss, a reopen or open tickets on easy (%s)" % str(reps))

	# SLA windows
	_fresh("tech", "easy")
	var te: Dictionary = msp.create_ticket(1, 0, "test")
	var easy_ratio: float = float(te.sla_total) / float(msp.SLA_SECS[int(te.pri)])
	_fresh("tech", "normal")
	var tn: Dictionary = msp.create_ticket(1, 0, "test")
	var norm_ratio: float = float(tn.sla_total) / float(msp.SLA_SECS[int(tn.pri)])
	_check(is_equal_approx(easy_ratio / norm_ratio, 1.3 * 1.6), "SLA windows: easy is the tier's 1.3 times the cozy 1.6 of normal (%.2f)" % (easy_ratio / norm_ratio))

	# ---- energy
	var sk := root.get_node("Skills")
	_fresh("tech", "easy")
	shift.energy = 12.0
	sk.ps_level = 0
	_check(shift.slow_mult() == 1.0 and shift.fail_add() == 0.0 and not shift.is_tired(), "easy: exhausted costs no speed and no mistakes")
	_check(sk.fail_chance() == float(sk.FAIL[0]) + root.get_node("Build").fx("fail"), "easy: no fix failure from fatigue")
	var drain := {}
	for tier in ["easy", "normal"]:
		_fresh("tech", tier)
		shift.energy = 80.0
		world.time_scale = 1.0
		world.day_len = 600.0
		shift._process(30.0)
		drain[tier] = 80.0 - shift.energy
	_check(drain.easy < 0.5 * drain.normal + 0.001, "easy: the energy drain is halved (and then some): %s" % str(drain))
	_fresh("tech", "normal")
	shift.energy = 12.0
	_check(shift.slow_mult() > 1.3 and shift.fail_add() > 0.1, "normal: exhausted still slows and fails")
	_fresh("tech", "easy")
	shift.energy = 50.0
	shift.stay("2")
	_check(shift.energy == 50.0 and shift.stay_label(1).find("ENERGY") < 0 and shift.stay_label(2).find("+$100") >= 0, "easy: staying late costs no energy and says so")
	_fresh("tech", "normal")
	shift.energy = 50.0
	shift.stay("1")
	_check(shift.energy == 42.0 and shift.stay_label(1).find("ENERGY") >= 0, "normal: staying late costs energy")

	# ---- commute and pager
	var late_easy := 0
	var rep_before: int = 0
	_fresh("tech", "easy")
	c.day = 3
	for choice in ["early", "ontime", "late"]:
		for i in 80:
			shift.late_min = 0
			shift.energy = 70.0
			shift.commute(choice)
			late_easy += 1 if shift.late_min > 0 else 0
	_check(late_easy == 0, "easy: the commute is always safe, no late arrivals (%d)" % late_easy)
	_check(shift.rep_delta() == 0, "easy: no lateness penalty on the report")
	rep_before = c.rep
	var asked_ok := true
	for i in 40:
		shift._page_result("ignore", 0, "the mail queue is stuck")
		asked_ok = asked_ok and cards.is_open
		while cards.is_open:
			cards.pick(0)
	_check(asked_ok and c.rep == rep_before, "easy: ignoring the pager costs nothing")
	_fresh("tech", "normal")
	rep_before = c.rep
	for i in 60:
		shift._page_result("ignore", 0, "the mail queue is stuck")
		while cards.is_open:
			cards.pick(0)
	_check(c.rep < rep_before, "normal: ignoring the pager still costs reputation")

	# ---- crew quits and poaching
	_fresh("service", "easy")
	var crew := root.get_node("Crew")
	for who in crew.names():
		crew.members[who]["morale"] = 5
		crew.members[who]["over_days"] = 6
		_check(crew.quit_chance(who) == 0.0, "easy: %s does not quit" % who)
		break
	_fresh("owner", "easy")
	var oe := root.get_node("Owner")
	var risk_easy: float = oe.poach_risk(0)
	_fresh("owner", "normal")
	_check(is_equal_approx(risk_easy, root.get_node("Owner").poach_risk(0) * 0.5), "easy: the rival's poaching risk is halved")

	# ---- ransomware
	for tier in ["easy", "normal"]:
		_fresh("tech", tier)
		c.rep = 60
		var ep: Dictionary = msp.endpoints[0]
		msp._ransom_lost(ep, "test")
		reps[tier + "_ransom"] = 60 - c.rep
		scars[tier + "_ransom"] = c.scars
	_check(reps.easy_ransom <= 6 and scars.easy_ransom == 0, "easy: lost ransom files cost about 5 reputation and no scar (%d)" % reps.easy_ransom)
	_check(reps.normal_ransom >= 10 and scars.normal_ransom >= 10, "normal: lost ransom files still cost 15 and a scar")

	# ---- the day report has no minus lines
	_fresh("tech", "easy")
	_day(12)
	var tb: Dictionary = msp.create_ticket(2, 0, "test")
	tb.sla_left = 0.1
	world.time_scale = 1.0
	msp._process(1.0)
	msp.close_ticket(msp.create_ticket(3, 1, "test").id)
	msp.create_ticket(4, 2, "test")
	await _close_day_now()
	_check(report.is_open and bool(report.report.get("cozy", false)), "easy: the report opens and is cozy")
	var groups: Array = report._groups()
	var labels := []
	var reds := 0
	for g in groups:
		for row in g[1]:
			labels.append(str(row[0]))
			reds += 1 if row[2] == report.BAD else 0
	_check(not labels.has("SLA MISSED") and not labels.has("REOPENED") and labels.has("CLOSED"), "easy report: no SLA MISSED or REOPENED rows (%s)" % str(labels))
	_check(labels.has(d.ct("open_row")) and reds == 0, "easy report: open tickets are 'carried over' and nothing is red")
	var tiles: Array = report._hero()
	var neg := false
	for tile in tiles:
		neg = neg or str(tile[2]).begins_with("-") or tile[3] == report.BAD
	_check(not neg, "easy report: no negative tiles")
	_check(str(report.report.grade) in ["S", "A", "B", "C", "D"], "easy report: the grade letter stays (%s)" % str(report.report.grade))
	report.is_open = false

	# ---- the DAY LENGTH option: applied at the morning, saved, restored, old saves
	_fresh("tech", "easy")
	_check(d.day_scale == 1.0 and world.day_len == 600.0 and d.day_label() == "10 MIN", "day length starts at 10 minutes")
	d.set_day_scale(1.5)
	_check(world.day_len == 600.0 and d.day_label() == "15 MIN", "choosing a length changes nothing until the morning")
	c.day = 3
	c.save()
	world.begin_next_day(4)
	_check(world.day_len == 900.0 and d.day_scale == 1.5, "the next morning: 900 s day")
	d.cycle_day_scale(1)
	_check(is_equal_approx(d.day_scale_next, 0.5) and d.day_label() == "5 MIN", "the option cycles 15 -> 5")
	d.set_day_scale(0.5)
	c.save()
	_check(c.continue_game("tech") and d.day_scale == 0.5 and world.day_len == 300.0, "continue restores the 5 minute day (%s s)" % str(world.day_len))
	d.from_dict({"tier": "easy", "seed": 9})
	_check(d.day_scale == 1.0 and d.day_scale_next == 1.0, "an old save without it loads the normal day")
	d.new_run()
	_check(d.day_scale == 1.0, "a new run starts at 10 minutes")
	# tech 300 / 600 / 900, the other modes scale their own default
	for mode in ["owner", "service"]:
		_fresh(mode, "easy")
		d.set_day_scale(1.5)
		world.begin_next_day(2)
		_check(is_equal_approx(world.day_len, c.day_len_for(mode) * 1.5), "%s: day length x1.5 (%s s)" % [mode, str(world.day_len)])
	# the pause menu row
	var pause := root.get_node("PauseMenu")
	_fresh("tech", "easy")
	_check(pause._labels().size() == 5 and str(pause._labels()[3]).begins_with("DAY LENGTH"), "the pause menu has a DAY LENGTH row in a campaign")
	pause._sel = 3
	pause._activate()
	_check(is_equal_approx(d.day_scale_next, 1.5), "ENTER on the row cycles the length")
	c.quit_to_title()
	_check(pause._labels().size() == 4, "no DAY LENGTH row outside a campaign")

	# ---- ticket pace and SLA clocks scale with the day: the same tickets per game hour
	_fresh("tech", "normal")
	c.day = 12
	var counts := {}
	var gaps := {}
	var ratios := {}
	for s in [0.5, 1.0, 1.5]:
		d.seed_run(77)
		d.day_scale = s
		d.day_scale_next = s
		gaps[s] = msp.next_spawn_gap()
		d.seed_run(77)
		var tk: Dictionary = msp.create_ticket(1, 0, "test")
		ratios[s] = float(tk.sla_total) / float(msp.SLA_SECS[int(tk.pri)])
		# simulate a whole day of real time and count the random tickets that arrive
		msp.reset()
		msp.enabled = true
		msp.pace = 1.0
		msp._spawn_t = 0.0
		world.time_scale = 1.0
		world.day_len = 600.0 * s
		var made := 0
		msp.spawned_today = 0  # the daily cap (12 from day 10 to 20) counts per day, and each size is one day
		var next_id: int = msp._next_id
		var steps := int(world.day_len / 0.5)
		for i in steps:
			msp._process(0.5)
			for t in msp.tickets:
				t.status = "Closed"  # keep the queue short so the cap of six never bites
		made = msp._next_id - next_id
		counts[s] = made
	_check(is_equal_approx(gaps[0.5] * 2.0, gaps[1.0]) and is_equal_approx(gaps[1.5], gaps[1.0] * 1.5), "the gap between tickets scales with the day length (%s)" % str(gaps))
	_check(is_equal_approx(ratios[0.5] * 2.0, ratios[1.0]) and is_equal_approx(ratios[1.5], ratios[1.0] * 1.5), "SLA windows scale with the day length (%s)" % str(ratios))
	var lo := mini(counts[0.5], mini(counts[1.0], counts[1.5]))
	var hi := maxi(counts[0.5], maxi(counts[1.0], counts[1.5]))
	_check(lo >= 6 and hi - lo <= 3, "tickets per day stay about the same at 5, 10 and 15 minutes (%s)" % str(counts))
	d.day_scale = 1.0
	d.day_scale_next = 1.0

	# ---- the run record, medals and Year 2
	for tier in ["easy", "normal"]:
		_fresh("tech", tier)
		var meta := ConfigFile.new()
		root.get_node("Yeartwo").record(meta, "tech", "head")
		_check(bool(meta.get_value("tech", "cozy", false)) == (tier == "easy"), "%s: the run record is tagged cozy=%s" % [tier, str(tier == "easy")])
		career.reset_all()
		career.note_ending()
		_check(career.value("endings") == (0 if tier == "easy" else 1) and career.has_medal("year_one") == (tier != "easy"), "%s: the ending medal counts only for non-cozy runs" % tier)
	_fresh("tech", "easy")
	career.reset_all()
	career.counters["tickets"] = 49
	var tm: Dictionary = msp.create_ticket(2, 3, "test")
	msp.rmm_action(tm.endpoint, str(tm.fix))
	msp.close_ticket(tm.id)
	_check(career.value("tickets") >= 50 and career.has_medal("ticket_machine"), "a cozy run still earns the ordinary medals")
	var meta2 := ConfigFile.new()
	root.get_node("Yeartwo").record(meta2, "tech", "head")
	meta2.save(c.save_prefix + "meta.cfg")
	_check(root.get_node("Yeartwo").available("tech"), "a cozy run unlocks Year 2")
	_check(d.cozy_tag() == "COZY", "the COZY tag shows beside the seed on easy")

	c.quit_to_title()
	d.set_tier("normal")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
