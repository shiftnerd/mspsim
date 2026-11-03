extends SceneTree
# The 90 day window, clawback, renewals and the new-client SLA priority (C2): a won client has a churn-risk meter fed by the promise
# gap, tickets that breach, mood and slow onboarding; leaving inside 13 weeks (90 days) claws the commission back by the pay plan;
# kept promises raise the renewal chance; renewals come up on a schedule with a business review and upsells; a premium promise
# bumps the new client's tickets for the first 30 days (4 weeks). Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 60:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


func _lead(sc: Node, n: int) -> Dictionary:
	var l: Dictionary = sc.make_lead(root.get_node("Difficulty").rng_for("churn_test", n))
	l.users = 24
	l.fee = 726
	l.quality = 60
	l.stage = "QUOTED"
	sc.leads.append(l)
	return l


func _win(sc: Node, cards: Node, n: int, how: String, promise := "high") -> Dictionary:
	var deals = load("res://scripts/deals.gd")
	var l := _lead(sc, n)
	var d: Dictionary = sc.close_deal(l, deals.norm({"method": "fixed", "promise": promise, "price": "list", "extras": ["backup"], "onboard": "std"}))
	_clear(cards)
	sc.pending_handover = 0
	var handover = load("res://scripts/handover.gd")
	handover.decide_all(d, how)
	handover.finish(d, false)
	return d


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var career := root.get_node("Career")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	player_script.current_character = "sales_vic"
	diff.seed_run(91)
	c.new_game("sales")
	_clear(cards)
	world.clock = 9.0
	msp.tickets = []
	sc.book = []
	sc.plan = "balanced"
	sc.q_signed = [0, 0]
	var ret = load("res://scripts/retention.gd")
	var deals = load("res://scripts/deals.gd")
	career.counters.erase("clawbacks")

	# ---- the clock
	_check(deals.WINDOW_WEEKS == 13 and deals.NEW_CLIENT_WEEKS == 4 and ret.RENEW_AFTER == 14, "units: 90 days = 13 weeks, the first 30 days = 4 weeks, the first renewal after 14")
	c.day = 2
	var d1 := _win(sc, cards, 1, "dropped")
	var l1: Dictionary = sc.lead_by_id(int(d1.id))
	_check(str(d1.state) == "active" and int(d1.churn) > 20 and int(d1.mood) < 66, "a client whose promises were dropped starts with a high churn meter (%d) and a low mood (%d)" % [int(d1.churn), int(d1.mood)])
	var d2 := _win(sc, cards, 2, "kept")
	_check(int(d2.churn) < int(d1.churn), "kept promises start lower (%d vs %d)" % [int(d2.churn), int(d1.churn)])

	# ---- what feeds the meter
	c.day = 3
	var before1: int = int(d1.churn)
	var before2: int = int(d2.churn)
	ret.week_tick(3)
	_check(int(d1.churn) > before1, "an unresolved promise gap raises the meter every week (%d to %d)" % [before1, int(d1.churn)])
	_check(int(d2.churn) <= before2 + 5, "a kept-promise client stays calm (%d to %d)" % [before2, int(d2.churn)])
	var m1: int = int(d1.churn)
	msp.tickets = [{"id": 5001, "status": "New", "pri": 2, "sla_left": -5.0, "client": 0, "breached": true, "newclient": str(d1.name)}]
	ret.week_tick(4)
	var with_breach: int = int(d1.churn)
	_check(int(d1.breaches) == 1 and with_breach >= m1 + 5, "a breached ticket of the new client adds to the meter (%d)" % with_breach)
	ret.week_tick(5)
	_check(int(d1.breaches) == 1, "and a breach counts once")
	msp.tickets = []
	var low_mood: Dictionary = d2.duplicate(true)
	low_mood["mood"] = 20
	low_mood["churn"] = 30
	low_mood["promises"] = []
	low_mood["kept"] = 0
	low_mood["gap"] = 0.0
	low_mood["id"] = 7777
	low_mood["week"] = 1
	low_mood["onboarded"] = true
	sc.book.append(low_mood)
	ret.week_tick(6)
	_check(int(low_mood.churn) >= 35, "an unhappy client (mood 20) pushes it up (%d)" % int(low_mood.churn))
	sc.book.erase(low_mood)
	var slow: Dictionary = d2.duplicate(true)
	slow["id"] = 7778
	slow["churn"] = 30
	slow["mood"] = 60
	slow["gap"] = 0.0
	slow["promises"] = []
	slow["onboarded"] = false
	slow["onboard_due"] = 3
	slow["delays"] = 0
	slow["week"] = 1
	sc.book.append(slow)
	msp.tickets = []
	for i in 8:
		msp.tickets.append({"id": 6000 + i, "status": "New", "pri": 3, "sla_left": 100.0, "client": 0, "breached": false})
	ret.week_tick(6)
	_check(not bool(slow.onboarded) and int(slow.delays) == 1 and int(slow.churn) >= 35 and int(slow.mood) < 60, "slow onboarding (a busy queue, no capacity) delays go-live and adds to the meter")
	msp.tickets = []
	ret.week_tick(7)
	_check(bool(slow.onboarded), "once the queue clears the client goes live")
	sc.book.erase(slow)

	# ---- leaving inside the window: the clawback
	var com: int = int(d1.commission)
	var total0: int = sc.commission_total
	var signed0: int = int(sc.q_signed[0])
	var cb0: int = int(career.counters.get("clawbacks", 0))
	var rep0: int = c.rep
	d1["churn"] = 100
	ret.week_tick(8)
	_check(not sc.book.has(d1) and sc.clawbacks == 1 and sc.churned.size() == 1, "at 100 the client gives notice inside the 90 days")
	_check(sc.commission_total == total0 - com and sc.week_clawback == com and sc.clawed_total == com, "the balanced plan takes all of the commission back ($%d)" % com)
	_check(int(sc.q_signed[0]) == signed0 - int(d1.signed_mrr), "and the MRR comes off the quarter")
	_check(str(l1.stage) == "LOST" and str(l1.why) == "LEFT IN THE 90 DAYS" and int(career.counters.get("clawbacks", 0)) == cb0 + 1, "the deal is LOST and Career counts the clawback")
	_check(c.rep < rep0, "Garrison's trust drops")
	_check(cards.is_open and "gave notice" in str(cards.text) and ("-$%d" % com) in str(cards.text) and "promise gap" in str(cards.text).to_lower(), "a short card explains why and how much")
	_clear(cards)
	sc.plan = "salary"
	var d3 := _win(sc, cards, 3, "dropped")
	var total1: int = sc.commission_total
	d3["churn"] = 100
	ret.week_tick(9)
	_check(sc.commission_total == total1 - int(round(float(d3.commission) * 0.5)), "on the salary plan half of it comes back")
	_clear(cards)
	sc.plan = "balanced"
	var report: Dictionary = sc.settle()
	var txt := ""
	for row in report.rows:
		if str(row[0]) == "COMMISSION EARNED":
			txt = str(row[1])
	_check("CLAWED BACK" in txt, "the weekly report shows it (%s)" % txt)
	_clear(cards)

	# ---- the window ends: the commission is safe, and no more leaving for a bad month
	var d4 := _win(sc, cards, 4, "dropped")
	d4["churn"] = 100
	ret.week_tick(int(d4.week) + deals.WINDOW_WEEKS + 1)
	_check(sc.book.has(d4) and str(d4.state) == "safe", "after 13 weeks the client is safe: no clawback")
	_clear(cards)

	# ---- the churn roll is seeded
	var runs := []
	for seed_value in [5, 5, 6]:
		diff.seed_run(seed_value)
		var out := ""
		for i in 30:
			var r: RandomNumberGenerator = diff.rng_for("churn", 100 * i + 9)
			out += "1" if r.randf() < 0.3 else "0"
		runs.append(out)
	_check(runs[0] == runs[1] and runs[0] != runs[2], "same seed, same churn rolls")

	# ---- renewals
	diff.seed_run(91)
	ret.schedule_base()
	_check(sc.base_book.size() == 5, "the five clients you inherited are on a renewal schedule")
	var weeks := []
	for e in sc.base_book:
		weeks.append(int(e.renew_at))
		_check(int(e.renew_at) >= 6 and int(e.renew_at) <= 20, "%s renews in week %d" % [str(e.name), int(e.renew_at)])
	var first: Dictionary = sc.base_book[0]
	_check(ret.due(int(first.renew_at)).has(first), "the schedule lists who is due that week")
	_check(ret.due(1).is_empty(), "nobody is due in week 1")
	var keen := _win(sc, cards, 5, "kept")
	var burnt := _win(sc, cards, 6, "dropped")
	keen["mood"] = 70
	burnt["mood"] = 70
	_check(ret.kept_count(keen) >= 3 and ret.broken_count(burnt) >= 3, "kept and broken promises are counted")
	_check(ret.renew_chance(keen) > ret.renew_chance(burnt) + 0.2, "kept promises raise the renewal chance (%.2f vs %.2f)" % [ret.renew_chance(keen), ret.renew_chance(burnt)])
	_check(ret.renew_chance(keen, 0.0, true) < ret.renew_chance(keen), "raising the price lowers it")
	_check(ret.renew_chance(keen, 0.12) > ret.renew_chance(keen), "a business review raises it")
	c.day = int(first.renew_at)
	sc.week_commission = 0
	ret.renewal_card(first)
	_check(cards.is_open and str(cards.speaker) == "Renewal" and cards.options.size() == 3 and "RENEW" in str(cards.options[0].label) and "REVIEW" in str(cards.options[1].label) and "RAISE" in str(cards.options[2].label), "the renewal card: renew / business review / raise the price")
	var hours: int = sc.slots_left()
	cards.pick(1)
	_check(sc.slots_left() == hours - 1 and cards.is_open and cards.options.size() == 3 and "WALK THROUGH THE NUMBERS" in str(cards.options[0].label), "the review costs an hour and reuses the owner campaign's QBR talks")
	var mood0: int = ret.entry_mood(first)
	cards.pick(0)
	_check(ret.entry_mood(first) == mood0 + 6, "walking through the numbers lifts their mood")
	_clear(cards)
	_check(sc.renewals_won + sc.renewals_lost >= 1, "the renewal was decided (won %d, lost %d)" % [sc.renewals_won, sc.renewals_lost])
	# a forced win and a forced loss
	var e_win: Dictionary = {"id": -11, "name": "Test Win", "client": -1, "mrr": 700, "renew_at": 8, "mood": 100, "kept": 8, "broken": 0, "who": "Mr. Win"}
	sc.base_book.append(e_win)
	var won0: int = sc.renewals_won
	var com0: int = sc.commission_total
	var new0: int = sc.week_new
	ret.renew_roll(e_win, 0.5, true)
	_clear(cards)
	_check(sc.renewals_won == won0 + 1 and int(e_win.mrr) == 770 and int(e_win.renew_at) == c.day + 14, "a renewal with a 10 percent rise: $770, due again in 14 weeks")
	_check(sc.commission_total > com0 and sc.week_new == new0 + 70 and sc.expansion_total >= 70, "it pays a renewal commission and the rise counts as new MRR")
	_check(int(career.counters.get("renewals", 0)) >= 1, "Career counts renewals")
	var e_lose: Dictionary = {"id": -12, "name": "Test Lose", "client": -1, "mrr": 700, "renew_at": 8, "mood": 5, "kept": 0, "broken": 9, "who": "Mr. Lose"}
	sc.base_book.append(e_lose)
	var lost0: int = sc.renewals_lost
	var lb0: int = sc.lost_base
	ret.renew_roll(e_lose, -1.0, true)
	_clear(cards)
	_check(sc.renewals_lost == lost0 + 1 and sc.lost_base == lb0 + 700 and not sc.base_book.has(e_lose), "a lost renewal takes $700 a week off the books")

	# ---- upsells
	var up := _win(sc, cards, 7, "kept", "std")
	up["mood"] = 90
	var mrr0: int = int(up.mrr)
	var opts: Array = ret.upsell_options(up)
	_check(opts.size() == 2 and not opts.has("backup"), "services already in the quote cannot be sold again (%s)" % str(opts))
	var sold := false
	for i in 8:
		up["upsells"] = i
		if ret.upsell_roll(up, "patching"):
			sold = true
			break
	_check(sold and int(up.mrr) == mrr0 + 80 and up.upsold == ["patching"], "a service is sold to a happy client: +$80 a week")
	_check(sc.upsells >= 1 and int(career.counters.get("upsells", 0)) >= 1 and sc.expansion_total >= 80, "counted in the campaign and Career")
	_check(not ret.upsell_options(up).has("patching"), "and it is gone from the menu")

	# ---- the new-client SLA bump
	sc.book = []
	msp.tickets = []
	c.day = 10
	var prem := _win(sc, cards, 8, "kept", "high")
	_check(ret.sla_state(prem) == "kept", "a kept premium SLA")
	var bumped := 0
	var plain := 0
	var base_pri: int = int(msp.PROBLEMS[0].pri)
	for i in 60:
		msp.tickets = []
		for ep in msp.endpoints:
			ep.problem = ""
		var t: Dictionary = msp.create_ticket(0, 0, "test")
		if t.is_empty():
			continue
		if str(t.get("newclient", "")) == str(prem.name):
			bumped += 1
			if bumped == 1:
				_check(int(t.pri) == maxi(1, base_pri - 1), "a new client's ticket is one priority higher (P%d, base P%d)" % [int(t.pri), base_pri])
		else:
			plain += 1
			if plain == 1:
				_check(int(t.pri) == base_pri and str(t.get("newclient", "")) == "", "other tickets keep their priority")
	_check(bumped >= 5 and plain >= 20, "about a quarter of the tickets are the new client's (%d of 60)" % bumped)
	prem.promises[0]["state"] = "dropped"
	var any := false
	for i in 40:
		msp.tickets = []
		for ep in msp.endpoints:
			ep.problem = ""
		var t2: Dictionary = msp.create_ticket(0, 0, "test")
		any = any or str(t2.get("newclient", "")) != ""
	_check(not any, "no bump if you dropped the SLA promise (or renegotiated it)")
	prem.promises[0]["state"] = "kept"
	c.day = 10 + deals.NEW_CLIENT_WEEKS + 1
	any = false
	for i in 40:
		msp.tickets = []
		for ep in msp.endpoints:
			ep.problem = ""
		var t3: Dictionary = msp.create_ticket(0, 0, "test")
		any = any or str(t3.get("newclient", "")) != ""
	_check(not any, "and the bump ends after the first 30 days")
	c.day = 10
	prem["promise"] = "std"
	any = false
	for i in 40:
		msp.tickets = []
		for ep in msp.endpoints:
			ep.problem = ""
		var t4: Dictionary = msp.create_ticket(0, 0, "test")
		any = any or str(t4.get("newclient", "")) != ""
	_check(not any, "a standard SLA gets no bump")

	# ---- the other campaigns are untouched
	c.active = false
	c.mode = ""
	_check(ret.new_client_for(0, 1) == "", "outside the sales campaign nobody gets a bump")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
