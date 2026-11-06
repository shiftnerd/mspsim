extends SceneTree
# gdlint:disable=max-line-length
# R38 P5: the rival and good-habit hooks of John's sales campaign (scripts/sales_rival.gd). The incumbent drawn for every lead (seeds
# repeat), revealed 85% on a discovery call and always on a visit; ASSESS (a selling hour, needs MEETING, 3 to 5 findings from
# Rival.assessment that become promises, or the cheap answer that is a lie); the quote builder PRESENTED AS field and the RIVAL PRICE
# gauge with the win-point effects of section 6; rumours that expire after four weeks; the lie flag (90 day churn +8, a LIES line, the
# SALES DIRECTOR needs a clean enough conscience); the takeover handover of a Big Cheese client; the nine beats; the scorecard bonus.
# Headless; saves in user://test_*.

var failures := 0


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


func _lead(id: int, inc: String, seen := true, users := 20, quality := 50) -> Dictionary:
	return {
		"id": id,
		"name": "Test Dental %d" % id,
		"type": "dental",
		"who": "Dr. Test",
		"users": users,
		"pain": "x",
		"quality": quality,
		"fee": 600,
		"site": false,
		"week": 1,
		"stage": "MEETING",
		"called": true,
		"visited": false,
		"moon": false,
		"why": "",
		"touch": 1,
		"notes": [],
		"follow": 0,
		"incumbent": inc,
		"inc_seen": seen
	}


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var game := root.get_node("Game")
	var owner := root.get_node("Owner")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	var sr = load("res://scripts/sales_rival.gd")
	var deals = load("res://scripts/deals.gd")
	var qb = load("res://scripts/quote_builder.gd")
	var rival = load("res://scripts/rival.gd")
	var habits = load("res://scripts/habits.gd")
	var temptation = load("res://scripts/temptation.gd")
	var handover = load("res://scripts/handover.gd")
	var retention = load("res://scripts/retention.gd")
	diff.seed_run(77)
	c.new_game("sales")
	_clear(cards)
	world.clock = 9.0
	msp.tickets = []
	sc.book = []
	sc.leads = []
	sc.q_signed = [0, 0]
	sc.margin_floor = 0.35

	# ---- the incumbent: always drawn, every kind appears, seeds repeat
	sc.used_names.clear()
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var kinds := {}
	var seq_a := []
	for i in 300:
		var la: Dictionary = sc.make_lead(a)
		kinds[str(la.incumbent)] = int(kinds.get(str(la.incumbent), 0)) + 1
		seq_a.append(str(la.incumbent) + str(la.name))
		if i % 20 == 19:
			sc.used_names.clear()
	sc.used_names.clear()
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	var seq_b := []
	for i in 300:
		var lb: Dictionary = sc.make_lead(b)
		seq_b.append(str(lb.incumbent) + str(lb.name))
		if i % 20 == 19:
			sc.used_names.clear()
	var same: bool = seq_a == seq_b
	_check(
		same and kinds.size() == 5,
		(
			"300 leads: the same seed gives the same incumbents and all five kinds appear (%s)"
			% str(kinds)
		)
	)
	_check(
		(
			int(kinds.get("none", 0)) > 50
			and int(kinds.get("bigcheese", 0)) > 30
			and int(kinds.get("plumbline", 0)) < int(kinds.get("bytebrothers", 0))
		),
		"the odds: many have nobody, Big Cheese is common, Plumb Line is rare"
	)
	var fresh: Dictionary = sc.make_lead(a)
	_check(not bool(fresh.inc_seen), "a new lead keeps its incumbent hidden")

	# ---- the discovery call reveals 85%, a visit always
	var hit := 0
	for i in 400:
		var l := _lead(1000 + i, "bigcheese", false)
		c.day = 3 + i % 7
		if sr.on_call(l):
			hit += 1
	_check(
		hit > 320 and hit < 360,
		"a discovery call reveals the incumbent about 85 percent of the time (%d of 400)" % hit
	)
	var lv := _lead(9, "plumbline", false)
	_check(sr.on_visit(lv) and sr.is_seen(lv), "a visit always shows it")
	_check(
		(
			sr.rival_line(_lead(9, "bytebrothers", false)).begins_with("RIVAL: UNKNOWN")
			and sr.rival_line(_lead(9, "bigcheese")) == "RIVAL: BIG CHEESE"
		),
		"the CRM line is hidden until you ask"
	)
	c.day = 2
	var lc := _lead(11, "bigcheese", false)
	lc.stage = "LEAD"
	lc.called = false
	sc.leads = [lc]
	sc.call_lead(11)
	_check(
		bool(lc.called) and lc.stage == "MEETING" and (sr.is_seen(lc) or (not sr.is_seen(lc))),
		"the real call_lead runs the reveal without errors"
	)

	# ---- Rival.assessment: 3 to 5 distinct habits from the rap sheet
	var ok_sets := true
	for who in ["bigcheese", "bytebrothers", "plumbline", "inhouse", "none"]:
		for n in 6:
			sc.flags["assess_n"] = n
			c.day = 5 + n
			var ids: Array = rival.assessment(who)
			var uniq := {}
			for h in ids:
				uniq[str(h)] = true
				ok_sets = ok_sets and rival.HABITS.has(str(h))
			ok_sets = ok_sets and ids.size() >= 3 and ids.size() <= 5 and uniq.size() == ids.size()
	_check(
		ok_sets, "Rival.assessment gives 3 to 5 distinct known habits for every kind of incumbent"
	)
	for h in rival.assessment("bytebrothers"):
		ok_sets = ok_sets and rival.RIVALS.bytebrothers.habits.has(str(h))
	_check(ok_sets, "a ByteBrothers assessment only lists habits on its rap sheet")

	# ---- ASSESS: one selling hour, needs the MEETING stage
	c.day = 6
	world.clock = 9.0
	var ll := _lead(21, "bigcheese", false, 20, 50)
	ll.stage = "LEAD"
	sc.leads = [ll]
	_check(sr.assess(21).begins_with("NEEDS A MEETING"), "ASSESS needs the MEETING stage")
	ll.stage = "MEETING"
	var hours: int = sc.slots_left()
	_check(
		sr.assess(21).begins_with("ASSESSING") and sc.slots_left() == hours - 1,
		"ASSESS costs one selling hour"
	)
	_check(
		sr.is_seen(ll) and ll.findings.size() >= 3 and ll.findings.size() <= 5 and cards.is_open,
		"it shows the incumbent, 3 to 5 findings and the choice card"
	)
	_check(cards.options.size() == 2, "honest list or it looks fine")
	var cons0: int = temptation.consc()
	cards.pick(0)
	_check(
		str(ll.assessed) == "honest" and sr.can_assess(ll).begins_with("ALREADY"),
		"the honest list is recorded and cannot be done twice"
	)
	_check(habits.state("H10") != "NONE", "doing the honest assessment starts the habit H10")
	_check(temptation.consc() >= cons0, "an honest list never lowers the conscience")
	# the findings become promises in the quote and the handover
	var q: Dictionary = deals.norm({"method": "fixed", "promise": "std", "price": "list"})
	var plist: Array = deals.promise_list(ll, q)
	var fixes := 0
	for p in plist:
		fixes += 1 if str(p.kind) == "FIX" else 0
	_check(fixes == ll.findings.size(), "each finding is a FIX promise in the quote (%d)" % fixes)
	var qh: Dictionary = deals.norm({"method": "fixed", "promise": "high", "price": "list"})
	_check(
		(
			absf(float(deals.gap(ll, qh)) - snappedf(1.0 + 0.2 * float(ll.findings.size()), 0.1))
			< 0.001
		),
		(
			"and each adds 0.2 promise gap once the spare capacity is used (%.1f)"
			% float(deals.gap(ll, qh))
		)
	)
	var total := 0.0
	for p in deals.promise_list(ll, qh):
		total += float(p.gap)
	_check(
		absf(total - float(deals.gap(ll, qh))) < 0.011, "the promise gaps add up to the deal's gap"
	)

	# ---- the cheap answer is a lie
	var lz := _lead(22, "bigcheese", true)
	sc.leads = [lz]
	world.clock = 9.0
	var cons1: int = temptation.consc()
	sr.assess(22)
	cards.pick(1)
	_check(
		(
			str(lz.assessed) == "cheap"
			and bool(lz.lie)
			and lz.findings.is_empty()
			and lz.hidden.size() >= 3
		),
		"it looks fine: flagged as a lie, nothing written down"
	)
	_check(temptation.consc() < cons1, "and the conscience falls")
	var base_l := _lead(23, "bigcheese")
	var win_base: float = deals.win(base_l, q)
	_check(
		absf(float(deals.win(lz, q)) - (win_base + 0.03)) < 0.0001,
		"the cheap answer wins 3 points more now"
	)
	_check(absf(float(deals.gap(lz, qh)) - 1.5) < 0.001, "and breaks later: promise gap +0.5")
	_check(
		absf(float(deals.win(ll, q)) - (win_base - 0.03)) < 0.0001,
		"the honest list costs 3 win points"
	)

	# ---- PRESENTED AS
	var bc := _lead(31, "bigcheese")
	var bb := _lead(32, "bytebrothers")
	var pl := _lead(33, "plumbline")
	var nn := _lead(34, "none")
	var itemized := {"method": "fixed", "promise": "std", "price": "list", "present": "itemized"}
	var flat := {"method": "fixed", "promise": "std", "price": "list", "present": "flat"}
	var tiers := {"method": "fixed", "promise": "std", "price": "list", "present": "tiers"}
	var w0: float = deals.win(nn, itemized)
	_check(
		(
			absf(float(deals.win(bc, itemized)) - (w0 - 0.04)) < 0.0001
			and absf(float(deals.win(bb, itemized)) - (w0 - 0.04)) < 0.0001
		),
		"itemized against a flat price: -4 points (thirty-one doors to cut)"
	)
	_check(
		absf(float(deals.win(pl, itemized)) - w0) < 0.0001,
		"against Plumb Line or nobody it costs nothing"
	)
	_check(
		absf(float(deals.win(bc, flat)) - (w0 + 0.03)) < 0.0001,
		"flat matches the rival's form: +3 points"
	)
	_check(
		absf(float(deals.margin(flat, bc)) - (float(deals.margin(itemized, bc)) - 0.08)) < 0.0001,
		"flat costs 8 points of margin"
	)
	var flat_h: Dictionary = {
		"method": "fixed", "promise": "high", "price": "list", "present": "flat"
	}
	var item_h: Dictionary = {
		"method": "fixed", "promise": "high", "price": "list", "present": "itemized"
	}
	_check(
		absf(float(deals.gap(bc, flat_h)) - float(deals.gap(bc, item_h)) - 0.5) < 0.001,
		"and adds 0.5 promise gap (nothing in writing on what is out)"
	)
	_check(
		absf(float(deals.win(bc, tiers)) - (w0 - 0.02)) < 0.0001,
		"three tiers without the habit behind them is a guess: -2 points"
	)
	habits.start("H2")
	_check(
		absf(float(deals.win(bc, tiers)) - (w0 + 0.02)) < 0.0001,
		"with the scorecard habit: +2 points"
	)
	_check(absf(float(deals.win(bc, itemized)) - w0) < 0.0001, "and the itemized penalty is gone")
	var g: Dictionary = deals.gauges(bc, flat)
	_check(
		g.blocks.any(
			func(x: Dictionary) -> bool: return str(x.who) == "ALAN" and "FLAT" in str(x.text)
		),
		"Alan comments on the flat form"
	)
	owner.habits.erase("H2")
	g = deals.gauges(bc, itemized)
	_check(
		g.blocks.any(func(x: Dictionary) -> bool: return str(x.who) == "JOHN"),
		"and John suggests three tiers against a flat rival"
	)
	_check(
		not deals.gauges(nn, itemized).blocks.any(
			func(x: Dictionary) -> bool: return str(x.who) == "JOHN"
		),
		"but not when nobody flat is in the picture"
	)

	# ---- RIVAL PRICE
	_check(
		int(g.rival.week) == 510 and bool(g.rival.known) and str(g.rival.name) == "BIG CHEESE",
		"RIVAL PRICE: Big Cheese is flat at 85 percent of list ($510 on $600)"
	)
	_check(
		int(deals.gauges(bb, itemized).rival.week) == 480, "ByteBrothers is 20 percent under list"
	)
	_check(int(deals.gauges(pl, itemized).rival.week) == 690, "Plumb Line is above list")
	_check(
		not bool(deals.gauges(_lead(35, "bigcheese", false), itemized).rival.known),
		"the gauge stays hidden until you have asked"
	)

	# ---- the builder field
	var lb2 := _lead(41, "bigcheese")
	lb2.present_pref = "tiers"
	sc.leads = [lb2]
	qb.begin(lb2)
	_check(
		qb.ROWS.has("present") and qb.value_text("present") == "3 TIERS",
		"the builder opens on the PRESENTED AS the lead prefers (3 TIERS)"
	)
	qb.change("present", 1)
	_check(qb.value_text("present") == "ITEMIZED", "the field cycles")
	qb.change("present", 1)
	_check(
		qb.value_text("present") == "FLAT" and str(qb.gauges().rival.name) == "BIG CHEESE",
		"to FLAT, with the RIVAL PRICE in the gauges"
	)
	qb.close()
	sc.crm_view = "list"

	# ---- rumours expire after four weeks
	var lr := _lead(51, "none")
	c.day = 13
	sr.set_rumour(lr, -0.05)
	_check(absf(float(deals.win(lr, itemized)) - (w0 - 0.05)) < 0.0001, "a rumour costs win points")
	c.day = 16
	_check(absf(float(deals.win(lr, itemized)) - (w0 - 0.05)) < 0.0001, "still there in week 16")
	c.day = 17
	_check(absf(float(deals.win(lr, itemized)) - w0) < 0.0001, "and gone after four weeks")
	sc.leads = [lr]
	sr.week(17)
	_clear(cards)
	_check(not lr.has("rumour"), "the weekly pass drops the expired rumour from the lead")

	# ---- a lie flag: 90 day churn +8, the LIES line, the director job
	c.day = 8
	var honest_l := _lead(61, "none")
	honest_l.assessed = "honest"
	honest_l.findings = ["R02", "R04", "R12"]
	var lie_l := _lead(62, "none")
	lie_l.lie = true
	var plain_l := _lead(63, "none")
	var d_h: Dictionary = sc.close_deal(
		honest_l, deals.norm({"method": "fixed", "promise": "std", "price": "list"})
	)
	var d_l: Dictionary = sc.close_deal(
		lie_l, deals.norm({"method": "fixed", "promise": "std", "price": "list"})
	)
	var d_p: Dictionary = sc.close_deal(
		plain_l, deals.norm({"method": "fixed", "promise": "std", "price": "list"})
	)
	_clear(cards)
	sc.pending_handover = 0
	sc.handover_queue = []
	for d in [d_h, d_l, d_p]:
		handover.decide_all(d, "kept")
		handover.finish(d, false)
	_clear(cards)
	_check(
		bool(d_l.lie) and not bool(d_p.lie) and bool(d_h.honest),
		"the deal carries the lie and the honest flags from the lead"
	)
	var exp_l: int = clampi(int(round(10.0 + 12.0 * float(d_l.gap))) + 8, 0, 100)
	_check(
		sr.churn_adjust(d_l) == 8 and sr.churn_adjust(d_h) == -8 and sr.churn_adjust(d_p) == 0,
		"the churn adjustments: lie +8, honest -8, plain 0"
	)
	_check(
		int(d_l.churn) == exp_l,
		"a lie adds 8 to the 90 day churn (%d, expected %d)" % [int(d_l.churn), exp_l]
	)
	_check(
		int(d_h.churn) < int(d_p.churn) and int(d_h.mood) > int(d_p.mood),
		(
			"an honest assessment starts the client calmer (churn %d against %d, mood %d against %d)"
			% [int(d_h.churn), int(d_p.churn), int(d_h.mood), int(d_p.mood)]
		)
	)
	_check(sr.lies() == 1, "one lie on the record")
	var lines: Array = sc.review_lines(0, "stay")
	var found := false
	for ln in lines:
		found = found or str(ln[0]).begins_with("LIES: 1 DEAL WON BY A SHORTCUT")
	_check(found, "the week 20 verdict has a LIES line")
	# the director job: the conscience in words
	owner.consc = 0
	_check(
		sr.conscience_ok() and temptation.band() == "CLEAN BOOKS",
		"a clean conscience (CLEAN BOOKS)"
	)
	owner.consc = -3
	_check(not sr.conscience_ok(), "conscience of minus three is no longer above the line")
	owner.consc = -2
	_check(sr.conscience_ok(), "minus two is still fine")
	sc.q_result = ["HIT", "HIT"]
	sc.q_signed = [999999, 999999]
	sc.churned = []
	sc.clawbacks = 0
	for d in sc.book:
		d["mood"] = 90
	c.rep = 80
	owner.consc = 0
	var director_clean: bool = sc.director_ok()
	owner.consc = -4
	var director_dirty: bool = sc.director_ok()
	_check(
		director_clean and not director_dirty,
		(
			"SALES DIRECTOR needs the conscience above the line (%s / %s)"
			% [str(director_clean), str(director_dirty)]
		)
	)
	_check(
		sr.lies_line().contains("DIRECTOR") and sr.lies_line().contains(temptation.band()),
		"the verdict says so in words"
	)
	owner.consc = 0

	# ---- the takeover handover of a Big Cheese client
	c.day = 10
	sc.book = []
	sc.pending_handover = 0
	sc.handover_queue = []
	var cap0: float = sc.capacity()
	var bl := _lead(71, "bigcheese")
	var dt: Dictionary = sc.close_deal(
		bl, deals.norm({"method": "fixed", "promise": "std", "price": "list"})
	)
	_clear(cards)
	_check(
		(
			bool(dt.takeover)
			and dt.promises.any(func(p: Dictionary) -> bool: return str(p.kind) == "INHERITED")
		),
		"winning an unassessed Big Cheese client brings the inherited mess to the handover"
	)
	_check(
		sc.capacity() < cap0 - 0.15,
		"Dan and Morgan lose capacity for it (%.2f to %.2f)" % [cap0, sc.capacity()]
	)
	_check(sr.takeover_line(dt).contains("Big Cheese"), "the handover intro names it")
	sc.pending_handover = 0
	sc.handover_queue = []
	c.day = 18
	_check(absf(sc.capacity() - cap0) < 0.15, "after six weeks the load is gone")

	# ---- the beats
	c.day = 2
	sc.book = []
	sc.leads = [_lead(81, "none", false, 12, 40)]
	sc.flags = {}
	sr.week(2)
	_clear(cards)
	_check(
		(
			sc.leads[0].incumbent == "bigcheese"
			and sr.is_seen(sc.leads[0])
			and int(sc.flags.incumbent) == 81
		),
		"week 2: the first call shows a Big Cheese incumbent"
	)
	sr.week(3)
	_clear(cards, 0)
	_check(str(sc.flags.rex) == "flyer", "week 3: Rex at the Chamber lunch (flyer)")
	sr.week(3)
	_clear(cards, 1)
	_check(str(sc.flags.rex) == "friend", "week 3 again: shaking his hand")
	# week 5: sales_flat
	sc.leads = [_lead(82, "bigcheese", true, 20, 50)]
	c.day = 5
	world.clock = 9.0
	sr.week(5)
	_check(cards.is_open and cards.options.size() == 4, "week 5: sales_flat has four answers")
	cards.pick(0)
	_clear(cards)
	_check(
		(
			str(sc.leads[0].get("present_pref", "")) == "tiers"
			and bool(sc.flags.get("value_page", false))
		),
		"the value page answer prefers THREE TIERS in the builder"
	)
	var cons2: int = temptation.consc()
	sc.leads = [_lead(83, "bigcheese", true, 20, 50)]
	sr.week(5)
	cards.pick(1)
	_clear(cards)
	_check(
		(
			bool(sc.leads[0].get("lie", false))
			and str(sc.leads[0].present_pref) == "flat"
			and temptation.consc() < cons2
		),
		"matching the flat price is a shortcut (lie flag, FLAT, conscience)"
	)
	# week 7: ASSESS on a Big Cheese client
	c.day = 7
	sc.leads = []
	sr.week(7)
	cards.pick(0)
	_clear(cards)
	var marlowe: Dictionary = sc.leads[0] if not sc.leads.is_empty() else {}
	_check(
		not marlowe.is_empty() and marlowe.incumbent == "bigcheese" and marlowe.stage == "MEETING",
		"week 7: a Big Cheese client is on the pipeline at MEETING"
	)
	world.clock = 9.0
	sr.assess(int(marlowe.id))
	var first3: Array = marlowe.findings.slice(0, 3)
	_check(
		first3 == ["R02", "R04", "R12"],
		"its assessment leads with the three findings the design names (%s)" % str(first3)
	)
	cards.pick(0)
	_clear(cards)
	# week 9: sales_laundered
	c.day = 9
	sc.leads = []
	var cons3: int = temptation.consc()
	sr.week(9)
	cards.pick(0)
	_clear(cards)
	_check(
		bool(sc.leads[0].get("lie", false)) and temptation.consc() < cons3,
		"week 9: taking the laundered lead is a lie and costs conscience"
	)
	sc.leads = []
	sr.week(9)
	cards.pick(1)
	_clear(cards)
	_check(not bool(sc.leads[0].get("lie", false)), "asking her how she heard is not")
	# week 11: Plumb Line
	c.day = 11
	sc.leads = []
	sr.week(11)
	cards.pick(0)
	_clear(cards)
	_check(
		(
			sc.leads.size() == 1
			and sc.leads[0].incumbent == "plumbline"
			and str(sc.leads[0].present_pref) == "tiers"
		),
		"week 11: the Plumb Line prospect arrives, ready for the three tier page"
	)
	sc.leads = []
	sr.week(11)
	cards.pick(1)
	_clear(cards)
	_check(sc.leads.size() == 1 and bool(sc.leads[0].lie), "undercutting Hollis is the temptation")
	sc.leads = []
	sr.week(11)
	cards.pick(2)
	_clear(cards)
	_check(
		sc.leads.is_empty() and bool(sc.flags.get("hollis_favour", false)),
		"sending her back wins no deal and a favour from Hollis"
	)
	# week 13: the rumour
	c.day = 13
	world.clock = 9.0
	sc.leads = [_lead(91, "none")]
	var base13: float = deals.win(sc.leads[0], itemized)
	sr.week(13)
	cards.pick(2)
	_clear(cards)
	_check(
		float(deals.win(sc.leads[0], itemized)) < base13 - 0.04,
		"week 13: ignoring the rumour costs 5 points"
	)
	sc.leads = [_lead(92, "none")]
	sr.week(13)
	cards.pick(0)
	_clear(cards)
	_check(
		absf(float(deals.win(sc.leads[0], itemized)) - (base13 - 0.03)) < 0.0001,
		"the paper costs 3 points (and an hour)"
	)
	sc.leads = [_lead(93, "none")]
	sr.week(13)
	cards.pick(1)
	_clear(cards)
	_check(
		float(deals.win(sc.leads[0], itemized)) > base13 + 0.05 and bool(sc.leads[0].lie),
		"badmouthing Rex back wins 6 points and is a lie"
	)
	_check(int(sc.flags.get("counter_wk", 0)) == 15, "and Rex answers in two weeks")
	var rep0: int = c.rep
	sr.week(15)
	_clear(cards)
	_check(c.rep == rep0 - 1, "week 15: the counter-rumour dents reputation")
	# week 15: the vendor audit surge
	c.day = 15
	sc.leads = []
	sc.flags.erase("counter_wk")
	sr.week(15)
	_clear(cards, 0)
	_check(
		(
			sc.leads.size() >= 1
			and sc.leads.all(
				func(x: Dictionary) -> bool: return x.incumbent == "bigcheese" and sr.is_seen(x)
			)
		),
		"week 15: Big Cheese's vendor audit sends prospects who name him (%d)" % sc.leads.size()
	)
	# week 17: the scorecard
	c.day = 17
	world.clock = 9.0
	sc.base_book = []
	retention.schedule_base()
	var e: Dictionary = sc.base_book[0]
	var chance0: float = retention.renew_chance(e)
	habits.start("H2")
	sr.week(17)
	cards.pick(0)
	_clear(cards)
	_check(
		(
			absf(float(e.scorecard) - 0.06) < 0.0001
			and absf(retention.renew_chance(e) - (chance0 + 0.06)) < 0.0001
		),
		"week 17: a client who saw the scorecard renews 0.06 more often"
	)
	owner.habits.erase("H2")
	sc.flags.erase("value_page")
	e.erase("scorecard")
	sr.week(17)
	cards.pick(0)
	_clear(cards)
	_check(
		absf(float(e.scorecard) - 0.03) < 0.0001, "without a value page behind it the bonus is half"
	)

	# ---- the text: every beat card has options and no forbidden words
	var bad := 0
	for k in [
		"incumbent", "rex", "flat", "assess", "laundered", "plumb", "rumour", "audit", "scorecard"
	]:
		bad += 0 if sc.BEAT_TEXT.has(k) else 1
	_check(bad == 0, "BEAT_TEXT has all nine beats")
	var charset := true
	var words := true
	for k in [
		"incumbent", "rex", "flat", "assess", "laundered", "plumb", "rumour", "audit", "scorecard"
	]:
		for key in sc.BEAT_TEXT[k]:
			var row: Dictionary = sc.BEAT_TEXT[k][key]
			var all := [str(row.get("text", "")), str(row.get("ok", ""))]
			for o in row.get("options", []):
				all.append(str(o.label))
			for t in all:
				for ch in t:
					if not (
						ch in " .,:;!?-_/()'@#%&+=$<>*{}"
						or (ch >= "A" and ch <= "Z")
						or (ch >= "a" and ch <= "z")
						or (ch >= "0" and ch <= "9")
					):
						charset = false
				var low: String = " " + t.to_lower() + " "
				for w in [
					" ai ", "mfa", "chatgpt", "slack", "teams", "tiktok", "windows 10", "windows 11"
				]:
					if low.contains(w):
						words = false
	_check(charset, "the beat text uses only the pixel font's characters")
	_check(words, "and no modern words slip into 2014")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
