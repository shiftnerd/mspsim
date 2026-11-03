extends SceneTree
# C7 / V4: the rest of the service story. Each beat fires on its day with the right effects and flags, the owner-conflict arc
# (sides and compromises), the XP wave, Heartbleed, resets and the promotion, the Iron Mule onboarding job, the cost cut, the
# pager and the rota, the PSA cut over, the client escalation, the Summit audit and roll-up, the endings by flags and meters,
# stale runbooks when Mutators / Events change a system, saving, and the point-buy readers. Headless.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 40:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1
	return n


func _start() -> void:
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(11)  # a fixed seed: the pager nights and the beat details repeat
	root.get_node("Campaign").new_game("service")
	_clear(root.get_node("Cards"))
	root.get_node("Msp").tickets.clear()


func _day(n: int, clock := 9.0) -> void:
	root.get_node("Campaign").day = n
	root.get_node("World").clock = clock


func _tickets_with(prefix: String) -> int:
	var n := 0
	for t in root.get_node("Msp").tickets:
		if str(t.summary).begins_with(prefix):
			n += 1
	return n


func _opt(cards: Node, id: String) -> int:
	for i in cards.options.size():
		if str(cards.options[i].id) == id:
			return i
	return -1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var arc := root.get_node("ServiceArc")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var playbook := root.get_node("Playbook")
	var mut := root.get_node("Mutators")
	var events := root.get_node("Events")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- the schedule: fixed days, text without day numbers, tokens all filled
	_start()
	var tidy := true
	for id in arc.SCHEDULE:
		var s: Dictionary = arc.SCHEDULE[id]
		tidy = tidy and int(s.day) >= 1 and int(s.day) <= 20 and float(s.at) >= 9.0 and float(s.at) <= 16.0
	_check(tidy and arc.SCHEDULE.size() >= 12, "%d beats sit on a day and a clock time" % arc.SCHEDULE.size())
	var rx := RegEx.new()
	rx.compile("[Dd]ay [0-9]")
	var hard := 0
	for id in arc.ARC:
		var b: Dictionary = arc.ARC[id]
		var blob := JSON.stringify(b)
		if rx.search(blob) != null:
			hard += 1
	_check(hard == 0, "no card has a day number written into its text")
	_check(mut.plan.size() == 3 and str(mut.plan[0].id) == "xp_eol" and int(mut.plan[0].from) == 4 and str(mut.plan[1].id) == "heartbleed" and str(mut.plan[2].id) == "new_psa", "the mutator plan is the story: XP, Heartbleed, the new PSA")
	_check(playbook.BOOKS.has("onboard") and playbook.PROBLEMS.has("onboard") and playbook.BOOKS.onboard.steps.size() == 6, "the onboarding book is installed (six steps)")
	var t1: float = arc.time_of("heartbleed")
	_check(absf(t1 - 13.0) <= 0.3 and arc.time_of("heartbleed") == t1, "the clock time is the table's, nudged by the seed (%.1f)" % t1)

	# ---- Heartbleed: Garrison wants an email, Alan wants patches
	_start()
	_day(5, 13.5)
	var ta0: int = sv.trust_of("Alan")
	var tg0: int = sv.trust_of("Garrison")
	await process_frame
	await process_frame
	_check(arc.fired.has("heartbleed") and cards.is_open and cards.options.size() == 3, "Heartbleed fires on its day (clock 13.5): three answers")
	_check(_tickets_with("Heartbleed") >= 1, "security tickets are on the board (%d)" % _tickets_with("Heartbleed"))
	cards.pick(_opt(cards, "patch"))
	_clear(cards)
	_check(sv.trust_of("Alan") > ta0 and sv.trust_of("Garrison") < tg0 and sv.flags.get("hb_patch", false) and int(arc.sides.Alan) == 1, "patch first: Alan up, Garrison down, side noted")
	_day(6, 9.6)
	await process_frame
	await process_frame
	_check(arc.fired.has("heartbleed2"), "the follow-up arrives the next morning")
	_clear(cards)
	_start()
	_day(5, 13.5)
	await process_frame
	await process_frame
	var ta1: int = sv.trust_of("Alan")
	cards.pick(_opt(cards, "email"))
	_clear(cards)
	_day(6, 9.6)
	await process_frame
	await process_frame
	_clear(cards)
	_check(_tickets_with("Did you patch") == 2 and sv.trust_of("Alan") < ta1 - 4, "email first: two clients ask whether you patched, Alan is cold")
	_start()
	_day(5, 13.5)
	await process_frame
	await process_frame
	var hours0: float = sv.kb.hours_left()
	cards.pick(_opt(cards, "both"))
	_clear(cards)
	_check(sv.kb.hours_left() < hours0 and int(arc.sides.both) == 1 and sv.flags.get("hb_both", false), "holding email and patch order: an hour of your time, both owners")

	# ---- the XP wave against the crew
	_start()
	c.day = 4
	sv.beat("xp")
	_check(cards.is_open and str(cards.text).contains("14 machines"), "the XP card names the wave and the deadline")
	cards.pick(1)  # after hours
	_clear(cards)
	_check(str(arc.wave.mode) == "n" and float(arc.wave.rate) > 4.0, "after hours batches work fastest")
	for d in range(5, 9):
		arc.begin_day(d)
	_check(arc.wave_pct() >= 95, "four mornings of batches finish the wave (%d percent)" % arc.wave_pct())
	var morale_n: int = crew.morale_avg()
	_start()
	c.day = 4
	sv.beat("xp")
	cards.pick(2)  # give them to Maya
	_clear(cards)
	for d in range(5, 9):
		arc.begin_day(d)
	var pct_m: int = arc.wave_pct()
	_check(pct_m >= 65 and pct_m < 95, "Maya alone gets through most of it (%d percent)" % pct_m)
	_day(6, 14.4)
	arc.fired.erase("wave_adjust")
	var rate0: float = arc.wave.rate
	await process_frame
	await process_frame
	var guard := 0
	while cards.is_open and _opt(cards, "pull") < 0 and guard < 12:
		guard += 1
		cards.pick(0)  # the day's other cards (Vic's promise, the hire) come first
	_check(cards.is_open and _opt(cards, "pull") >= 0, "the mid-week adjustment asks how to spend the crew")
	cards.pick(_opt(cards, "pull"))
	_clear(cards)
	_check(float(arc.wave.rate) > rate0, "pulling a tech off the phones raises the rate")
	var ta2: int = sv.trust_of("Alan")
	_day(8, 15.8)
	await process_frame
	await process_frame
	_check(arc.fired.has("wave_check") and str(arc.picks.get("wave_check", "")) in ["most", "done"], "the check fires on its day")
	_clear(cards)
	_start()
	_day(8, 15.8)
	arc.wave["done"] = 3.0
	arc.fire("wave_check")
	_clear(cards)
	_check(str(arc.picks.wave_check) == "low" and arc.credits == 1 and arc.pending.has(9), "a failed wave: two infected XP boxes tomorrow and a clawback")
	msp.tickets.clear()
	c.day = 9
	arc.begin_day(9)
	_check(_tickets_with("Old XP machine") >= 1, "the XP tickets arrive the next morning")

	# ---- seniors on resets, the promotion
	_start()
	_day(8, 10.9)
	arc.fire("resets")
	_check(cards.is_open and cards.options.size() == 3 and _opt(cards, "doc") >= 0, "resets: tier it, write the runbook, or Alan keeps covering")
	var h1: float = sv.kb.hours_left()
	cards.pick(_opt(cards, "doc"))
	_clear(cards)
	_check(sv.kb.is_live("password") and sv.kb.hours_left() < h1, "the reset runbook costs an hour and is live")
	arc.fired.erase("resets")
	arc.fire("resets")
	_check(cards.is_open and cards.options.size() == 1 and str(cards.text).contains("runbook"), "with the runbook live Alan goes back to his servers")
	_clear(cards)
	_check(sv.trust_of("Alan") >= 50 + 3 + 3, "and he says so (trust %d)" % sv.trust_of("Alan"))
	_start()
	_day(8, 14.6)
	crew.members["Sam"]["done"] = 9.0
	arc.fire("promo")
	_check(cards.is_open and str(cards.speaker).begins_with("Sam"), "the Tier 1 tech with the most closes asks for a promotion")
	var wage0: int = int(crew.value("Sam", "wage"))
	cards.pick(0)
	_clear(cards)
	_check(sv.lane_of("Sam") == "L2" and int(crew.value("Sam", "wage")) == wage0 + 80 and int(sv.event_days.get("promotion", -1)) == 8, "promoted: Tier 2, $80 more, the retention event is not repeated")

	# ---- the margin vs logo beat: sides and a compromise
	_start()
	_day(10, 11.2)
	arc.fire("margin")
	var broker_i := _opt(cards, "broker")
	_check(broker_i >= 0 and bool(cards.options[broker_i].get("enabled", true)), "margin: the compromise is open while both owners trust you")
	cards.pick(broker_i)
	_clear(cards)
	_check(int(arc.sides.both) == 1 and sv.flags.get("logo_broker", false) and sv.trust_of("Alan") == 53 and sv.trust_of("Garrison") == 53, "a brokered deal lifts both owners a little")
	_start()
	sv.trust["Alan"] = 30
	_day(10, 11.2)
	arc.fire("margin")
	var br2 := _opt(cards, "broker")
	_check(not bool(cards.options[br2].get("enabled", true)), "an owner who does not trust you will not hear a compromise")
	cards.pick(_opt(cards, "full"))
	_clear(cards)
	_check(int(arc.sides.Garrison) == 1 and sv.flags.get("logo_full", false), "siding with the logo counts for Garrison")

	# ---- Iron Mule: the onboarding playbook
	_start()
	_day(12, 9.8)
	await process_frame
	await process_frame
	_check(arc.fired.has("onboard") and sales.active.has(10) and cards.is_open and cards.options.size() == 3, "Iron Mule signs and asks who onboards")
	cards.pick(0)  # take it yourself
	_clear(cards)
	_check(playbook.is_active() and str(playbook.active.id) == "onboard", "taking it starts the onboarding job")
	for step in 6:
		var choices: Array = playbook.current_step().choices
		var best := 0
		for i in choices.size():
			if int(choices[i].pts) > int(choices[best].pts) and playbook.lock_reason(choices[i]) == "":
				best = i
		playbook.choose(best)
	arc.job_done_check()
	var res: Dictionary = playbook.active.result
	_check(str(res.grade) in ["S", "A"] and str(sv.flags.get("job_onboard", "")) in ["S", "A"], "the careful route earns an S or an A (%s)" % str(res.get("grade", "?")))
	_check(arc.pending.is_empty(), "nothing comes back after a clean onboarding")
	playbook.reset()
	_start()
	_day(12, 9.8)
	arc.fire("onboard")
	cards.pick(0)
	_clear(cards)
	for step in 6:
		var ch2: Array = playbook.current_step().choices
		playbook.choose(ch2.size() - 1)  # the worst of every step
	arc.job_done_check()
	_check(arc.pending.has(13) and str(playbook.active.result.grade) in ["D", "C"], "the sloppy route: a leak and a broken server come back tomorrow (%s)" % str(playbook.active.result.grade))
	playbook.reset()
	_start()
	_day(12, 9.8)
	arc.fire("onboard")
	cards.pick(1)  # Maya
	_clear(cards)
	_check(sv.flags.has("job_onboard") and not playbook.is_active(), "Maya can run it, with a grade (%s)" % str(sv.flags.get("job_onboard", "?")))

	# ---- the cost cut proposal
	_start()
	_day(12, 15.3)
	sv.training = "full"
	arc.fire("cutcost")
	_check(cards.is_open and _opt(cards, "small") >= 0 and not bool(cards.options[_opt(cards, "small")].get("enabled", true)), "a smaller cut needs the numbers (25 percent documented)")
	cards.pick(_opt(cards, "cut"))
	_clear(cards)
	_check(sv.training == "none" and sv.flags.get("cut_training", false) and int(arc.sides.Alan) == 1, "cutting training is Alan's side")

	# ---- the pager and the rota
	_start()
	sv.memo("m5")
	cards.pick(0)
	_clear(cards)
	_check(str(arc.oncall.policy) == "rota", "the memo sets the on-call policy")
	_day(14, 13.2)
	arc.fire("stipend")
	cards.pick(_opt(cards, "40"))
	_clear(cards)
	_check(int(arc.oncall.stipend) == 40 and arc.oncall_cost() == 40, "the stipend is set and counted in the weekly cost")
	var nights := 0
	for d in range(15, 20):
		c.day = d
		cards.pending_clear() if cards.has_method("pending_clear") else null
		arc.begin_day(d)
		nights = int(arc.oncall.nights)
		if cards.is_open:
			cards.pick(2)  # take the next page yourself
			_clear(cards)
	_check(nights >= 1 and int(arc.oncall.dan) >= 1, "pages come in the nights (%d) and you can take one yourself" % nights)
	_check(arc.fairness() >= 0.5, "a rota is fair (%.2f)" % arc.fairness())
	_start()
	arc.oncall["policy"] = "volunteer"
	var maya_pages := 0
	for d in range(15, 20):
		c.day = d
		arc.begin_day(d)
		_clear(cards, 1)
	for n in arc.oncall.load:
		maya_pages = maxi(maya_pages, int(arc.oncall.load[n]))
	_check(int(arc.oncall.nights) <= 1 or arc.fairness() < 1.0, "volunteers carry the pager: fairness drops (%.2f)" % arc.fairness())

	# ---- the new PSA
	_start()
	_day(16, 9.5)
	sv.kb.rb("spooler")["state"] = sv.kb.DOCUMENTED
	sv.kb.rb("password")["state"] = sv.kb.DOCUMENTED
	sv.kb.rb("reboot")["state"] = sv.kb.DOCUMENTED
	mut.announce("new_psa")
	_clear(cards)
	var stale_n := 0
	for id in ["spooler", "password", "reboot"]:
		if bool(sv.kb.rb(id).stale):
			stale_n += 1
	_check(stale_n >= 1, "the mutator hook makes %d documented runbooks stale" % stale_n)
	for k in 6:
		var tk: Dictionary = msp.create_ticket(k % 5, 0, "email")
		sv.assign(int(tk.id), "Maya", false)
	arc.fire("psa")
	cards.pick(_opt(cards, "big"))
	_clear(cards)
	var unassigned := 0
	for t in msp.open_tickets():
		if crew.assignee_of(t) == "":
			unassigned += 1
	_check(arc.psa_mode == "big" and (unassigned >= 1 or _tickets_with("My ticket disappeared") >= 1), "a big bang cut over loses assignees and tickets")
	_start()
	_day(16, 9.5)
	arc.fire("psa")
	var tr := _opt(cards, "train")
	_check(bool(cards.options[tr].get("enabled", true)), "the training day is open with two manager hours")
	cards.pick(tr)
	_clear(cards)
	_check(sv.kb.hours_left() < 1.1 and arc.psa_mode == "trained", "training the crew first costs two hours")

	# ---- the client escalation: pick a side or broker
	_start()
	_day(17, 15.1)
	sv.trust["Garrison"] = 35
	arc.fire("escalation")
	var eb := _opt(cards, "broker")
	_check(not bool(cards.options[eb].get("enabled", true)), "no compromise while an owner trusts you under 40")
	cards.pick(_opt(cards, "hold"))
	_clear(cards)
	_check(sv.flags.get("esc_hold", false) and int(arc.sides.Alan) == 1, "holding the line is Alan's side")
	_start()
	_day(17, 15.1)
	arc.fire("escalation")
	cards.pick(_opt(cards, "broker"))
	_clear(cards)
	_check(arc.credits == 1 and sv.flags.get("esc_broker", false) and int(arc.sides.both) == 1, "a brokered answer costs a credit and pleases both")

	# ---- the Summit audit and the endings
	_start()
	msp.closed_ok = 20
	msp.breached = 10
	var a0: Dictionary = arc.audit_score()
	_check(int(a0.total) < 55 and int(a0.tier) <= 1, "an undocumented desk with a third of its SLAs missed scores low (%d of 100)" % int(a0.total))
	for id in ["spooler", "password", "reboot", "clear_temp", "av", "restore", "adobe", "rdp", "ransom", "rack"]:
		sv.kb.rb(id)["state"] = sv.kb.DOCUMENTED
	msp.closed_ok = 40
	msp.breached = 2
	var a1: Dictionary = arc.audit_score()
	_check(int(a1.total) >= 75 and int(a1.tier) == 3, "a documented, retained, on-time desk earns the rich offer (%d: doc %d ret %d sla %d claw %d)" % [int(a1.total), int(a1.doc), int(a1.ret), int(a1.sla), int(a1.claw)])
	arc.credits = 4
	arc.lost_clients = 1
	var a2: Dictionary = arc.audit_score()
	_check(int(a2.claw) < int(a1.claw) and int(a2.total) < int(a1.total), "clawbacks pull the score down")
	arc.credits = 0
	arc.lost_clients = 0
	_day(19, 15.1)
	arc.fire("rollup")
	_check(cards.is_open and str(cards.text).contains("of 100") and str(cards.text).contains("Ross Calder"), "the roll-up card shows the audit scorecard")
	cards.pick(_opt(cards, "sell"))
	_clear(cards)
	_check(str(arc.rollup_rec) == "sell" and sv.trust_of("Garrison") > sv.trust_of("Alan"), "recommending the sale pleases Garrison and worries Alan")
	sv.trust["Alan"] = 70
	sv.trust["Garrison"] = 65
	c.rep = 70
	var ids := []
	for o in sv.review_offers():
		ids.append(str(o.id))
	_check(ids.has("ops") and ids.has("rollup_yes") and ids.has("rollup_no") and ids.has("stay"), "endings: operations manager, roll-up accepted or declined, probation: " + str(ids))
	sv.trust["Garrison"] = 80
	sv.trust["Alan"] = 30
	ids = []
	for o in sv.review_offers():
		ids.append(str(o.id))
	_check(ids.has("garrison") and not ids.has("alan") and not ids.has("ops"), "an owner you lost cannot make you operations manager")
	c.rep = 40
	sv.trust["Alan"] = 40
	sv.trust["Garrison"] = 40
	ids = []
	for o in sv.review_offers():
		ids.append(str(o.id))
	_check(ids == ["stay"], "confidence under 45 leaves only probation: " + str(ids))
	_start()
	msp.closed_ok = 2
	msp.breached = 30
	arc.credits = 5
	arc.audit = {}
	_check(arc.extra_offers().is_empty(), "a failing desk gets no offer from Summit (%d)" % int(arc.audit_score().total))
	arc.credits = 0
	msp.closed_ok = 40
	msp.breached = 2
	for id in ["spooler", "password", "reboot", "clear_temp", "av", "restore", "adobe", "rdp"]:
		sv.kb.rb(id)["state"] = sv.kb.DOCUMENTED
	c.rep = 70
	review_text(sv)
	_check(sv.REVIEW.endings.has("rollup_yes") and str(sv.REVIEW.endings.rollup_yes.text).length() > 20, "the roll-up endings have an ending page")

	# fired by both owners: trust under 20 each
	_start()
	sv.trust["Alan"] = 15
	sv.trust["Garrison"] = 15
	world.clock = 16.9
	var rp: Dictionary = c.make_report()
	sv.close_day(rp)
	_check(int(rp.rep_delta) == -c.rep and str(rp.get("fired_text", "")).contains("BOTH OWNERS"), "both owners under 20: the desk goes to someone else, with its own line")
	c.rep = 0
	_check(c._ending({"fired": true, "fired_text": rp.fired_text}).contains("BOTH OWNERS"), "the fired report says why")

	# ---- systems change: Events and Mutators call kb.system_change
	_start()
	for id in ["reboot", "clear_temp", "av", "spooler", "adobe"]:
		sv.kb.rb(id)["state"] = sv.kb.DOCUMENTED
	var hit: Array = arc.on_mutator("xp_eol") if false else []
	mut.announce("xp_eol")
	_clear(cards)
	var stale_xp := 0
	for id in ["reboot", "clear_temp", "av"]:
		if bool(sv.kb.rb(id).stale):
			stale_xp += 1
	_check(stale_xp == 2, "XP end of support: two of the three classes go stale (%d)" % stale_xp)
	events.show_draw({"deck": "event", "id": "copier_lease", "who": ""})
	_clear(cards)
	_check(bool(sv.kb.rb("spooler").stale) or bool(sv.kb.rb("adobe").stale), "a copier lease event makes printing runbooks stale")
	var fresh: int = sv.kb.doc_pct()
	_check(fresh < 60, "documentation falls as the notes go stale (%d percent)" % fresh)
	_check(events.quiet_day(2, "service") and not events.quiet_day(8, "service") and not events.quiet_day(12, "service"), "the Events deck draws on quiet service days only")
	_check(arc.beat_count(8) >= 4 and arc.beat_count(2) == 1, "busy days carry several beats")

	# ---- the arc is saved
	_start()
	sv.memo("m1")
	cards.pick(0)
	_clear(cards)
	arc.credits = 2
	arc.wave["done"] = 7.0
	arc.rollup_rec = "stay"
	arc.oncall["policy"] = "hybrid"
	c.day = 9
	c.save()
	arc.reset()
	sv.reset()
	_check(c.continue_game("service"), "continue works")
	_clear(cards)
	_check(arc.credits == 2 and float(arc.wave.done) == 7.0 and arc.rollup_rec == "stay" and str(arc.oncall.policy) == "hybrid" and int(arc.sides.Alan) == 1 and str(arc.picks.get("m1", "")) == "a", "credits, wave, rec, rota and the sides survive a save")
	_check(playbook.BOOKS.has("onboard"), "the onboarding book is back after loading")

	# ---- the point-buy stats are read
	_start()
	var bd := root.get_node("Build")
	_check(bd.selectable("service") and bd.level("process") == 2 and bd.level("dispatch") == 1 and bd.level("people") == 0, "Dan's flat build: PROCESS 2, DISPATCH 1, PEOPLE 0")
	var base_scale: float = sv._people_scale()
	var b2: Dictionary = bd.apply_preset("service", "Dan", "normal", "coach")
	c.build = b2
	_check(bd.level("people") == 2 and bd.level("relations") == 2 and sv._people_scale() > base_scale, "the COACH preset: PEOPLE 2, RELATIONS 2, 1:1s gain more")
	sv.trust["Alan"] = 50
	sv.apply_fx({"trust": {"Alan": 10}}, 1.0)
	var gained: int = sv.trust_of("Alan") - 50
	c.build = bd.flat()
	sv.trust["Alan"] = 50
	sv.apply_fx({"trust": {"Alan": 10}}, 1.0)
	_check(gained > sv.trust_of("Alan") - 50, "CLIENT RELATIONS makes trust grow faster (%d against %d)" % [gained, sv.trust_of("Alan") - 50])
	c.build = bd.apply_preset("service", "Dan", "normal", "firefighter")
	_check(sv.owner_cost() < 2 and bd.level("dispatch") >= 3, "the FIREFIGHTER preset: ESCALATION costs the owners less, the board is exact")
	var d_fuzz = load("res://scripts/dispatch.gd").new()
	_check(not d_fuzz.fuzzy(), "DISPATCH 3 removes the fuzz")
	c.build = bd.flat()
	_check(d_fuzz.fuzzy(), "a flat build sees a fuzzy board")
	c.build = bd.apply_preset("service", "Dan", "normal", "label_maker")
	_check(sv.kb.process_mult() < 1.0 and sv.kb.follow() >= 1.0, "PROCESS 4: runbooks cost less and the crew follows them")
	c.build = bd.flat()
	var net0: float = float(root.get_node("Skills").level("networking"))
	_check(net0 >= 3.0, "Dan starts with NETWORKING 3 (the free floor), which speeds networking tickets")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func review_text(sv: Node) -> void:
	for k in sv.REVIEW.endings:
		sv.review_lines(3, str(k))
