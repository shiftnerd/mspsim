extends SceneTree
# gdlint:disable=max-line-length
# Deals as records (C2): stage transitions and decay (a touched lead stays warm, an untouched one cools and goes cold), the quoted
# deal ByteBrothers can steal (a seeded roll that rises with every week you leave it alone and falls with follow-ups, the same seed
# gives the same steals), the promises list a quote makes, the risk meter and the 90 day clock that starts on a win.
# Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 60:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1


func _start(seed_value: int) -> void:
	player_script.current_character = "office_john"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(seed_value)
	root.get_node("Campaign").new_game("sales")
	_clear(root.get_node("Cards"))


# a quoted deal waiting for an answer
func _quoted(sc: Node, diff: Node, n: int, day: int, idle: int, follow: int) -> Dictionary:
	var l: Dictionary = sc.make_lead(diff.rng_for("deals_test", n))
	l.id = 1000 + n
	l.stage = "QUOTED"
	l.quoted_day = day - 1
	l.touch = day - idle
	l.follow = follow
	l.called = true
	l.quote = sc.Deals.norm({"method": "fixed", "promise": "std", "price": "list", "win": 0.5})
	sc.leads.append(l)
	return l


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	var deals = load("res://scripts/deals.gd")

	_start(31)
	world.clock = 9.0
	msp.tickets = []

	# ---- stages and decay
	var l: Dictionary = sc.make_lead(diff.rng_for("deals_test", 1))
	sc.accept_lead(l)
	_check(str(l.stage) == "LEAD" and int(l.touch) == c.day and not l.notes.is_empty(), "a new lead is LEAD, touched today, with a first note")
	var q0: int = int(l.quality)
	_check(sc.call_lead(int(l.id)).begins_with("CALLED") and str(l.stage) == "MEETING" and str(l.notes.back()).contains("CALLED"), "a call moves it to MEETING and writes a note")
	c.day = 5
	_check(deals.stale_weeks(l) == 4 - 0 and deals.risk(l) == 100, "four weeks untouched: the risk meter is full")
	c.day = 3
	_check(deals.stale_weeks(l) == 2 and deals.risk(l) == 50, "two weeks untouched: the risk meter is half")
	deals.age(c.day)
	_check(str(l.stage) == "MEETING" and int(l.quality) == q0 + 5 - 3, "a lead nobody touches cools (quality -3 a week from the second)")
	deals.touch(l, "CALLED BACK")
	_check(deals.stale_weeks(l) == 0 and deals.risk(l) == 0, "a touch resets the clock")
	c.day = 7
	deals.age(c.day)
	_check(str(l.stage) == "LOST" and str(l.why) == "WENT COLD", "untouched for the cold limit (%d weeks), it goes cold" % sc.COLD_WEEKS)
	c.day = 1
	var l2: Dictionary = sc.make_lead(diff.rng_for("deals_test", 2))
	sc.accept_lead(l2)
	var hours: int = sc.slots_left()
	var msg: String = sc.follow_up(int(l2.id))
	_check(msg.begins_with("FOLLOWED UP") and int(l2.follow) == 1 and sc.slots_left() == hours - 1, "CHASE costs an hour and counts a follow-up")
	_check(sc.follow_up(999) == "NOTHING TO FOLLOW UP.", "nothing to chase on an unknown deal")

	# ---- the steal chance
	c.day = 6
	var a: Dictionary = _quoted(sc, diff, 3, 6, 0, 0)
	var b: Dictionary = _quoted(sc, diff, 4, 6, 3, 0)
	var f: Dictionary = _quoted(sc, diff, 5, 6, 3, 2)
	var p_fast: float = deals.steal_chance(a, 6)
	var p_slow: float = deals.steal_chance(b, 6)
	_check(p_slow > p_fast + 0.2, "a quote nobody chases is much easier to steal (%.2f vs %.2f)" % [p_slow, p_fast])
	_check(deals.steal_chance(f, 6) < p_slow - 0.1, "follow-ups bring the chance down (%.2f)" % deals.steal_chance(f, 6))
	_check(deals.steal_chance(b, 8) > deals.steal_chance(b, 6), "and it rises with the weeks")
	diff.tier = "hard"
	var p_hard: float = deals.steal_chance(b, 6)
	diff.tier = "easy"
	var p_easy: float = deals.steal_chance(b, 6)
	diff.tier = "normal"
	_check(p_hard > p_slow and p_easy < p_slow, "the tier scales the rival (easy %.2f, normal %.2f, hard %.2f)" % [p_easy, p_slow, p_hard])
	_check(deals.risk(b) > deals.risk(a), "the risk meter of a quoted deal is the steal chance (%d vs %d)" % [deals.risk(b), deals.risk(a)])
	sc.leads = []

	# ---- ByteBrothers: the same seed steals the same deals
	var runs := []
	for seed_value in [77, 77, 78]:
		diff.seed_run(seed_value)
		sc.leads = []
		sc.book = []
		sc.rival_wins = 0
		for i in 40:
			_quoted(sc, diff, 100 + i, 6, i % 4, 0)
		deals.resolve_pending(6)
		_clear(cards)
		var out := ""
		for x in sc.leads:
			out += str(x.stage).left(1) + str(x.get("why", "")).left(1)
		runs.append(out)
	_check(runs[0] == runs[1], "the same seed gives the same steals and answers")
	_check(runs[0] != runs[2], "another seed gives another run")
	_check(sc.rival_wins >= 1, "ByteBrothers took some of them (%d)" % sc.rival_wins)
	var fast_steals := 0
	var slow_steals := 0
	diff.seed_run(5)
	sc.leads = []
	sc.book = []
	for i in 160:
		var lead_x: Dictionary = _quoted(sc, diff, 200 + i, 6, 0 if i < 80 else 3, 0)
		lead_x.quote.win = 0.0
	deals.resolve_pending(6)
	_clear(cards)
	for x in sc.leads:
		if str(x.get("why", "")) == "BYTEBROTHERS TOOK IT":
			if int(x.id) < 1000 + 200 + 80:
				fast_steals += 1
			else:
				slow_steals += 1
	_check(slow_steals > fast_steals + 10, "over 80 deals each, the slow ones are stolen far more often (%d vs %d)" % [slow_steals, fast_steals])
	var stolen: Dictionary = {}
	for x in sc.leads:
		if str(x.get("why", "")) == "BYTEBROTHERS TOOK IT":
			stolen = x
			break
	_check(not stolen.is_empty() and str(stolen.stage) == "LOST" and str(stolen.notes.back()).contains("BYTEBROTHERS"), "a stolen deal is LOST with a note")
	sc.leads = []
	sc.book = []

	# ---- the quote's promises
	var lead: Dictionary = sc.make_lead(diff.rng_for("deals_test", 9))
	lead.users = 20
	lead.fee = 630
	lead.pain = "no backup of patient files"
	lead.quality = 50
	var q: Dictionary = {"method": "fixed", "promise": "high", "price": "list", "extras": ["backup", "security"], "onboard": "rush"}
	var list: Array = deals.promise_list(lead, q)
	var ids := []
	for p in list:
		ids.append(str(p.id))
	_check(ids == ["sla", "response", "x_backup", "x_security", "onboard"], "a premium quote with two services and a rush: " + str(ids))
	var sum := 0.0
	for p in list:
		sum += float(p.gap)
		_check(str(p.state) == "open" and str(p.kind) != "" and str(p.label) != "", "promise %s starts open and is labelled (%s)" % [str(p.id), str(p.label)])
	_check(absf(sum - deals.gap(lead, q)) < 0.05, "the promises' gaps add up to the deal's gap (%.1f of %.1f)" % [sum, deals.gap(lead, q)])
	_check(deals.promise_list(lead, {"method": "fixed", "promise": "low", "price": "list"}).size() == 2, "a basic quote promises the SLA and the onboarding date")
	_check(deals.pain_match(lead, "backup") and not deals.pain_match(lead, "security"), "a backup pain makes the backup service a fit")
	_check(deals.win(lead, q) > deals.win(lead, {"method": "fixed", "promise": "high", "price": "list", "extras": ["security"], "onboard": "rush"}), "a fitting service raises the win chance, an odd one lowers it")

	# ---- WON starts the 90 day clock
	sc.leads = []
	sc.book = []
	c.day = 4
	lead.stage = "QUOTED"
	lead["incumbent"] = "none"  # a Big Cheese client would bring its inherited mess to the handover (tests/sales_rival.gd)
	lead["site"] = false
	sc.leads.append(lead)
	var deal: Dictionary = sc.close_deal(lead, deals.norm(q))
	_clear(cards)
	_check(str(lead.stage) == "WON" and int(deal.week) == 4 and str(deal.state) == "handover", "a win books the client, week 4, waiting for the handover")
	_check(deal.promises.size() == 5 and int(deal.onboard_due) == 5 and int(deal.churn) == 10, "with its promises, the onboarding date and a starting churn meter")
	_check(deals.WINDOW_WEEKS == 13 and deals.risk(lead) == 10, "the clock is 13 weeks (90 days) and the WON risk meter is the churn meter")
	_check(int(deal.commission) == sc.commission_for(int(deal.mrr)) or int(deal.commission) > 0, "the commission is recorded for the clawback")

	c.finish_campaign("test")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
