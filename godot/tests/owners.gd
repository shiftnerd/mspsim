extends SceneTree
# The owners as last-resort help (roadmap X6): the rule (tech campaign only, thresholds, day gate, cooldown, per-day
# limit, tiers, busy owners, no reputation / opinion cost, the report row, seeded repeat), ASK THE OWNER (Lynk and Talk),
# owner desks (no internal tickets), the growth helper list.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owners")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var social := root.get_node("Social")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var lync := root.get_node("Lync")
	var talk := root.get_node("Talk")
	var cards := root.get_node("Cards")
	var report := root.get_node("DayReport")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	diff.set_tier("normal")
	c.day = 5
	world.clock = 10.0
	msp.reset()
	o.begin_day()
	world.chars = {}  # nobody is out of the building unless a check below says so

	# ---- quiet day: nobody steps in
	_check(o.active(), "the rule is active in the tech campaign")
	msp.create_ticket(0, 0, "test")
	_check(o.check().is_empty(), "a quiet queue calls nobody")

	# ---- an SLA about to breach on a P1
	var t: Dictionary = msp.create_ticket(1, 0, "test")
	t.pri = 1
	t.sla_left = 20.0
	var rep0: int = c.rep
	var soc0: Dictionary = social.rel.duplicate()
	c.day = 2
	_check(o.check().is_empty(), "day 2: gentle first days, nobody")
	c.day = 5
	var d: Dictionary = o.check()
	_check(d.get("reason", "") == "sla" and d.who == "Alan", "a P1 about to breach: Alan (the technical owner)")
	o.step_in(d.who, d.reason, d)
	_check(is_equal_approx(float(msp.ticket(t.id).sla_left), 65.0), "+45 seconds on the clock")
	_check(o.used["Alan"] == 1 and o.stepped == 1, "counted: 1 use today")
	_check(c.rep == rep0 and social.rel == soc0, "no reputation and no opinion change")

	# ---- cooldown
	var t2: Dictionary = msp.create_ticket(2, 0, "test")
	t2.pri = 2
	t2.sla_left = 15.0
	world.clock = 10.0 + 2.0 / 60.0
	_check(o.check().is_empty(), "2 game minutes later: still cooling down")
	world.clock = 10.0 + 5.0 / 60.0
	d = o.check()
	_check(not d.is_empty() and d.reason == "sla", "5 minutes later: ready again")
	o.step_in(d.who, d.reason, d)
	_check(o.used["Alan"] == 2, "Alan used twice")

	# ---- per-day limit: Alan is done, Garrison covers; then nobody
	var t3: Dictionary = msp.create_ticket(3, 0, "test")
	t3.pri = 1
	t3.sla_left = 10.0
	world.clock = 10.5
	d = o.check()
	_check(d.get("who", "") == "Garrison", "Alan's two uses are gone: Garrison takes the next one")
	o.step_in(d.who, d.reason, d)
	o.used["Garrison"] = 2
	var t4: Dictionary = msp.create_ticket(4, 0, "test")
	t4.pri = 1
	t4.sla_left = 10.0
	world.clock = 11.0
	_check(o.check().is_empty(), "both owners used up: nobody")
	o.begin_day()
	_check(o.stepped == 0 and o.used["Alan"] == 0, "a new day resets the counters")

	# ---- the report row
	o.stepped = 2
	report.report = c.make_report()
	var found := false
	for group in report._groups():
		for row in group[1]:
			found = found or (str(row[0]) == "OWNERS STEPPED IN" and str(row[1]) == "2")
	_check(found, "the day report shows OWNERS STEPPED IN: 2")
	o.stepped = 0

	# ---- backlog and tiers
	msp.reset()
	o.begin_day()
	for i in 5:
		msp.create_ticket(i % 5, 0, "test")
	for k in msp.open_tickets():
		k.sla_left = 300.0
		k.pri = 3
	_check(o.check().is_empty(), "5 open tickets is not a backlog on normal")
	diff.set_tier("easy")
	d = o.check()
	_check(d.get("reason", "") == "backlog", "easy: 5 open tickets is already a backlog")
	_check(o.per_day() == 3 and o.cooldown_hours() < 4.0 / 60.0 + 0.001, "easy: three uses a day, a shorter cooldown")
	diff.set_tier("hard")
	_check(o.check().is_empty() and o.per_day() == 0, "hard: the owners never step in")
	diff.set_tier("normal")
	msp.create_ticket(0, 0, "test")
	for k in msp.open_tickets():
		k.sla_left = 300.0
		k.pri = 3
	d = o.check()
	_check(d.get("reason", "") == "backlog", "normal: 6 open tickets is a backlog")
	var soonest: Dictionary = msp.open_tickets()[0]
	o.step_in(d.who, d.reason, d)
	var helped := 0
	for k in msp.open_tickets():
		helped += 1 if is_equal_approx(float(k.sla_left), 345.0) else 0
	_check(helped == 1 and soonest != null, "exactly one ticket got +45 s")

	# ---- a complaint that waited, and ringing phones
	msp.reset()
	o.begin_day()
	var ct: Dictionary = msp.create_ticket(1, 0, "test")
	sales.pending = {"ticket": ct.id, "client": 1}
	o._pending_age = 10.0
	_check(o.check().is_empty(), "a fresh complaint is left to John and you")
	o._pending_age = 50.0
	var m0: int = sales.mood(1)
	d = o.check()
	_check(d.get("reason", "") == "complaint" and d.who == "Garrison", "a stale complaint: Garrison takes it")
	o.step_in(d.who, d.reason, d)
	_check(sales.pending.is_empty() and sales.mood(1) == m0 + 4, "complaint defused, client mood +4")
	o.begin_day()
	o.fake_rings = 1
	_check(o.check().is_empty(), "one ringing phone is nothing")
	o.fake_rings = 2
	var n0: int = msp.tickets.size()
	d = o.check()
	_check(d.get("reason", "") == "phones", "two phones ringing unanswered")
	o.step_in(d.who, d.reason, d)
	_check(msp.tickets.size() == n0, "the call is handled without adding work to your queue")

	# ---- not in Free Play, not in the owner campaign, not when the owner is busy
	o.begin_day()
	o.fake_rings = 2
	var saved_active: bool = c.active
	c.active = false
	_check(not o.active() and o.check().is_empty(), "Free Play: off")
	c.active = saved_active
	c.mode = "owner"
	_check(o.check().is_empty(), "owner campaign: off")
	c.mode = "tech"
	var backup: Dictionary = world.chars.duplicate()
	world.chars["Alan"] = {"scene": "conference", "following": false, "legs": [{"kind": "meeting"}], "node": null}
	world.chars["Garrison"] = {"scene": "office_two", "following": false, "legs": [{"kind": "work"}], "node": null}
	d = o.check()
	_check(d.get("who", "") == "Garrison", "Alan is in a meeting: Garrison is called")
	world.chars["Garrison"].legs = [{"kind": "lunch"}]
	_check(o.check().is_empty(), "both busy: nobody")
	world.chars["Garrison"] = {"scene": world.OUTSIDE, "following": false, "legs": [{"kind": "work"}], "node": null}
	_check(o.check().is_empty(), "out of the building: nobody")
	world.chars = backup
	o.fake_rings = 0

	# ---- the same seed repeats
	var runs := []
	for r in 2:
		diff.seed_run(777)
		var seq := []
		for i in 10:
			seq.append(o.pick_owner("phones"))
		runs.append(seq)
	_check(runs[0] == runs[1], "a seeded run picks the same owners")
	_check(runs[0].has("Alan") and runs[0].has("Garrison"), "and both owners get phone calls")

	# ---- ASK THE OWNER
	for who in ["Alan", "Garrison", "Dan"]:
		world.chars[who] = {"scene": "main_floor", "following": false, "legs": [{"kind": "work"}], "node": null}
	msp.reset()
	o.begin_day()
	var ot: Dictionary = msp.create_ticket(0, 0, "test")
	social.rel["Alan"] = 0
	var reply: String = o.ask("Alan")
	_check(reply.contains("payroll") and not o.approved_heavy, "a stranger gets no help from the owner")
	social.rel["Alan"] = 40
	lync.chats["Alan"] = []
	lync.send_action("Alan", "help")
	_check(o.approved_heavy and not msp.ticket(ot.id).fix_done, "Alan approves the heavy fix, he does not fix the ticket")
	_check(lync.chats["Alan"][-1][1].contains("sign for it"), "in Alan's voice")
	_check(o.ask("Alan").contains("already"), "once a day per owner")
	sales.satisfaction[0] = 70
	var ep: Dictionary = msp.endpoint(ot.endpoint)
	msp.rmm_action(ep.name, "reinstall_printer")
	_check(sales.mood(0) == 70 and not o.approved_heavy, "the next heavy fix costs no client mood")
	msp.reset()
	var gt: Dictionary = msp.create_ticket(0, 0, "test")
	social.rel["Garrison"] = 40
	var gm: int = sales.mood(0)
	var gs: float = gt.sla_left
	reply = o.ask("Garrison")
	_check(
		reply.contains("call") and sales.mood(0) == gm + 6 and is_equal_approx(float(msp.ticket(gt.id).sla_left), gs + 60.0),
		"Garrison calls the client: mood +6, SLA +60 s"
	)
	_check(o.ask("Garrison").contains("already"), "and only once a day")
	social.rel["Dan"] = 50
	msp.reset()
	var dt: Dictionary = msp.create_ticket(0, 0, "test")
	lync.send_action("Dan", "help")
	_check(msp.ticket(dt.id).fix_done, "Dan still fixes your ticket (the old help)")

	# ---- Talk labels
	talk._who = "Alan"
	talk._menu("Hi")
	_check(cards.options[1].label == "ASK THE OWNER", "Talk: ASK THE OWNER for an owner")
	cards._pick_leave()
	talk._who = "Dan"
	talk._menu("Hi")
	_check(cards.options[1].label == "ASK FOR HELP", "Talk: ASK FOR HELP for Dan")
	cards._pick_leave()
	talk._who = ""

	# ---- owner desks: no internal tickets, only an owner text
	msp.reset()
	var texts0: int = msp.texts.size()
	msp._down[6] = 9.0
	msp._owner_outage(6)
	_check(msp._internal.is_empty() and msp.texts.size() == texts0 + 1, "an outage in Alan's office is a text, not an internal ticket")
	_check(msp.texts[0].body.contains("payroll") or msp.texts[-1].body.contains("payroll"), "in owner words")
	_check(msp._owner_desk(6) and msp._owner_desk(7) and not msp._owner_desk(3), "desks 6 and 7 are the owners'")

	world.chars = {}
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
