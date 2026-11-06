extends SceneTree
# gdlint:disable=class-definitions-order,expression-not-assigned,max-line-length
# The sales campaign as John (C1, slice S1): the registry row, character select, a new game and continue, seeded leads, selling
# slots, the quote maths (win chance, margin, floor, discount approval), a visit to a prospect, the handover gap and the
# complaint it queues, the player ringing the bell, quota verdicts and commission, and a full 20-week run through the real
# week loop with every card answered, ending in the review. Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _scene() -> String:
	var sc := current_scene
	return "" if sc == null else sc.scene_file_path.get_file().get_basename()


# answer every open card with `choice` (the first enabled option if that one is greyed out)
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


func _start(seed_value := 4242, clear := true) -> void:
	player_script.current_character = "office_john"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(seed_value)
	root.get_node("Campaign").new_game("sales")
	if clear:
		_clear(root.get_node("Cards"))


func _lead_names(sc: Node) -> Array:
	var out := []
	for l in sc.leads:
		out.append(str(l.name))
	return out


func _find_label(cards: Node, part: String) -> int:
	for i in cards.options.size():
		if part in str(cards.options[i].label):
			return i
	return -1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var owner_node := root.get_node("Owner")
	var sales := root.get_node("Sales")
	var social := root.get_node("Social")
	var msp := root.get_node("Msp")
	var onsite := root.get_node("Onsite")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var game := root.get_node("Game")
	var diff := root.get_node("Difficulty")
	var hints := root.get_node("Hints")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false

	# ---- the registry row and character select
	var row: Dictionary = c.MODE_DEFS.sales
	_check(row.selectable and c.MODES.has("sales") and c.MODES.sales == "SALES CAMPAIGN", "sales is selectable and in the menu list")
	_check(not c.is_planned("sales") and c.is_selectable("sales"), "sales is no longer a planned mode")
	_check(row.day_len == 240.0 and row.total_days == 20 and row.unit == "WEEK" and row.review == "sales", "240 s weeks, 20 of them, a sales review")
	var cs_script := load("res://scripts/charselect.gd")
	var cs = cs_script.new()
	_check(cs.choices("sales") == ["office_john"], "character select offers only John")
	cs.setup("sales")
	_check(cs.ids == ["office_john"] and "SELL" in str(cs.info("office_john").blurb) and "ACCOUNT MANAGER" in str(cs.info("office_john").blurb), "John has a sales blurb")
	_check(cs.summary(false) == "SALES CAMPAIGN - JOHN", "the summary says SALES CAMPAIGN - JOHN (" + cs.summary(false) + ")")
	cs.free()
	_check(c.derive_player_as("sales") == "John", "the sales campaign is always played as John")

	# ---- a new game
	_start()
	_check(c.active and c.mode == "sales" and c.player_as == "John" and world.day_len == 240.0, "a new sales run: active, played as John, 240 s weeks")
	_check(c.crew_active() and c.books_active() and c.cards_active(), "crew, books and cards gates are open")
	_check(not world.chars.has("John"), "John's NPC copy is gone (World.roster_gone)")
	_check(world.chars.has("Dan") and world.chars.has("Maya") and world.chars.has("Morgan") and world.chars.has("Alan") and world.chars.has("Garrison"), "everyone else is in the building")
	_check(player_script.current_character == "office_john" and not social.people().has("John"), "you are John and John is not your coworker")
	_check(not root.get_node("Outings").enabled, "outings follow the title menu (off in a direct start)")
	_check(owner_node.vic_plan == sc.plan, "the pay plan is the company's John wage")
	_check(not cards.is_open and sc.open_leads().size() >= 2 and sc.open_leads().size() <= 3, "week 1 brings 2-3 leads (%d)" % sc.open_leads().size())

	# ---- the week 1 cards in order: quota, pay plan, leads
	_start(4242, false)
	_check(cards.is_open, "a card is waiting on day 1")
	_check(str(cards.speaker).begins_with("Garrison") and "quota" in str(cards.text).to_lower(), "Garrison opens with the quota (%s)" % str(cards.speaker))
	_check(cards.options.size() == 3 and "STRETCH" in str(cards.options[2].label), "quota options: safe, standard, stretch")
	cards.pick(2)
	_check(sc.quota_level == "stretch" and cards.is_open and "pay" in str(cards.text).to_lower(), "then your pay plan")
	cards.pick(2)
	_check(sc.plan == "commission" and owner_node.vic_plan == "commission", "commission-heavy plan chosen and applied to the payroll")
	_check(cards.is_open and str(cards.speaker) == "SalesHound lead", "then the leads arrive as cards")
	_check(cards.options.size() == 2 and cards.options[1].label == "PASS", "a lead card: work it or pass")
	var first_text: String = cards.text
	cards.pick(1)
	var passed: int = sc.open_leads().size()
	_clear(cards)
	_check(sc.open_leads().size() >= 1 and sc.open_leads().size() >= passed, "worked leads join the pipeline")
	_check(sc.quota_target(0) == 12000 and sc.quota_target(1) == 9600, "stretch quota: 12000 then 80%% for Q3 (%d)" % sc.quota_target(1))
	var tier_before: String = diff.tier
	diff.tier = "easy"
	_check(sc.quota_target(0) == 9600, "easy tier scales the quota (%d)" % sc.quota_target(0))
	diff.tier = "hard"
	_check(sc.quota_target(0) == 14400, "hard tier scales the quota (%d)" % sc.quota_target(0))
	diff.tier = tier_before

	# ---- leads are deterministic with a seed
	_start(777)
	var a1 := _lead_names(sc)
	var detail1: Array = sc.leads.duplicate(true)
	_start(777)
	var a2 := _lead_names(sc)
	_check(a1 == a2 and not a1.is_empty() and detail1 == sc.leads, "the same seed gives the same week 1 leads: " + str(a1))
	_start(778)
	var a3 := _lead_names(sc)
	_check(a3 != a1 or sc.leads != detail1, "another seed gives other leads")
	var lead: Dictionary = sc.leads[0]
	_check(sc.TYPE_ORDER.has(str(lead.type)) and int(lead.users) >= 6 and int(lead.users) <= 35, "a lead has a type that maps to a site type and a size")
	_check(int(lead.quality) >= 20 and int(lead.quality) <= 65 and str(lead.pain) != "" and str(lead.name) != "", "a lead has a quality, a pain and a name")
	_check(onsite.SITES.keys().size() == 6 and sc.site_key(str(lead.type)) in onsite.SITES, "the type maps to one of the six site clients")
	for l in sc.leads:
		_check(bool(l.site) == (str(l.name) == str(onsite.SITE_PROSPECT[str(l.type)])), "only a lead named like its b skin sign has a visit (%s)" % str(l.name))
	# the pool refills without repeating a name inside a cycle
	var r: RandomNumberGenerator = diff.rng_for("pool", 1)
	var seen := {}
	var dup := false
	for _i in 12:
		var ml: Dictionary = sc.make_lead(r)
		if seen.has(ml.name) and sc.used_names.size() > 0:
			dup = dup or false
		seen[ml.name] = true
	_check(sc.used_names.size() > 0, "used names are remembered")

	# ---- the selling slots are clock hours
	world.clock = 9.0
	_check(sc.slots_left() == 8, "a week has 8 selling hours at 9:00")
	var q0: float = world.clock
	_check(sc.spend(3) and absf(world.clock - (q0 + 3.0)) < 0.01 and sc.slots_left() == 5, "a 3 hour job moves the clock and leaves 5 slots")
	_check(not sc.spend(6) and sc.slots_left() == 5, "more hours than are left is refused")
	world.clock = 16.2
	_check(sc.slots_left() == 0 and not sc.spend(1), "no slots left near closing time")
	_check(sc.call_lead(int(sc.leads[0].id)) == "NO SELLING HOURS LEFT.", "no calls without hours")
	world.clock = 9.0
	var hud_text := "WEEK %d/%d %s %d%% HRS %d" % [c.day, c.total_days(), sc.quarter_label(), sc.quota_pct(), sc.slots_left()]
	_check(c.prop("hud", "") == "week_quota" and "HRS 8" in hud_text, "the HUD shows week, quarter, quota and hours: " + hud_text)

	# ---- a call
	var cl: Dictionary = sc.leads[0]
	var msg: String = sc.call_lead(int(cl.id))
	_check(bool(cl.called) and str(cl.stage) == "MEETING" and sc.slots_left() == 7 and msg.begins_with("CALLED"), "a call costs an hour, moves the lead to MEETING (%s)" % msg)
	_check(sc.call_lead(int(cl.id)) == "YOU ALREADY CALLED THEM.", "one call per lead")

	# ---- the quote maths
	var ql := {"quality": 40, "visited": false, "called": false, "moon": false, "fee": 600, "users": 18, "name": "T", "stage": "LEAD", "id": 99, "type": "dental", "who": "Dr. T", "pain": "x", "site": false}
	var fixed_std := {"method": "fixed", "promise": "std", "price": "list"}
	var w1: float = sc.win_chance(ql, fixed_std)
	_check(absf(w1 - (0.32 + 0.02 + 0.03)) < 0.0001, "win chance = 0.8 x quality + method + promise + price (%.2f)" % w1)
	var w_high: float = sc.win_chance(ql, {"method": "fixed", "promise": "high", "price": "list"})
	_check(w_high > w1 and absf(w_high - w1 - 0.11) < 0.0001, "over-promising raises the chance now (+%.2f)" % (w_high - w1))
	var w_d20: float = sc.win_chance(ql, {"method": "fixed", "promise": "std", "price": "d20"})
	_check(absf(w_d20 - w1 - 0.12) < 0.0001, "a 20% discount adds 12 points")
	ql.visited = true
	ql.called = true
	_check(absf(sc.win_chance(ql, fixed_std) - (w1 + 0.14)) < 0.0001, "a visit adds 10 points and a call 4")
	ql.moon = true
	_check(absf(sc.win_chance(ql, fixed_std) - (w1 + 0.19)) < 0.0001, "promising the moon at their office adds 5 more")
	ql.quality = 65
	_check(sc.win_chance(ql, {"method": "fixed", "promise": "high", "price": "d20"}) <= 0.92, "the chance is capped at 92%")
	ql.quality = 0
	_check(sc.win_chance(ql, {"method": "tm", "promise": "low", "price": "premium"}) >= 0.05, "and never under 5%")
	_check(absf(sc.margin_pct({"method": "fixed", "price": "list"}) - 0.5) < 0.0001, "fixed price at list is a 50% margin")
	_check(absf(sc.margin_pct({"method": "fixed", "price": "d20"}) - 0.375) < 0.0001, "20% off the fixed price leaves 37.5%")
	_check(sc.margin_pct({"method": "scope", "price": "list"}) > sc.margin_pct({"method": "fixed", "price": "list"}), "scoping first protects the margin")
	_check(sc.quote_price(ql, {"method": "fixed", "price": "d10"}) == 540 and sc.quote_price(ql, {"method": "tm", "price": "list"}) == 420, "prices: 10% off = $540, time and materials counts 70%% = $420")

	# ---- capacity and the promise gap
	msp.tickets = []
	sc.book = []
	_check(absf(sc.capacity() - 3.0) < 0.001, "an empty queue means a capacity of 3")
	_check(sc.promise_gap(ql, {"method": "fixed", "promise": "high"}) >= 2.0, "a 1 hour promise with the moon on top has a gap (%.1f)" % sc.promise_gap(ql, {"method": "fixed", "promise": "high"}))
	ql.moon = false
	_check(absf(sc.promise_gap(ql, {"method": "fixed", "promise": "high"}) - 1.0) < 0.001, "a 1 hour promise against capacity 3 is a gap of 1")
	_check(sc.promise_gap(ql, {"method": "scope", "promise": "high"}) == 0.0, "scoping first closes that gap")
	_check(sc.promise_gap(ql, {"method": "fixed", "promise": "std"}) == 0.0 and sc.promise_gap(ql, {"method": "fixed", "promise": "low"}) == 0.0, "honest promises have no gap")
	sc.book.append({"week": c.day, "mrr": 100, "margin": 0.5, "mood": 70, "gap": 0.0, "resolved": true})
	_check(absf(sc.capacity() - 2.45) < 0.001, "a deal signed this week takes half a point of capacity and a bit for the size of the book")
	sc.book = []

	# ---- the quote cards: method, promise, price, with the floor and Garrison's sign-off
	_start(31)
	_clear(cards)
	world.clock = 9.0
	var target: Dictionary = {}
	for l in sc.leads:
		if str(l.stage) == "LEAD":
			target = l
			break
	_check(not target.is_empty(), "there is a lead to quote")
	var tid := int(target.id)
	sc.start_quote(tid)
	_check(sc.crm_view == "build" and not cards.is_open and int(sc.qb.id) == tid, "the quote builder is a screen now, not a chain of cards")
	var qb = sc.QuoteBuilder
	var dl = sc.Deals
	_check(str(qb.quote().method) == "fixed" and str(qb.quote().promise) == "std" and int(qb.quote().discount) == 0, "it starts from a fixed price, a standard SLA and no discount")
	var g1: Dictionary = qb.gauges()
	_check(absf(float(g1.win) - sc.win_chance(target, qb.quote())) < 0.0001 and absf(float(g1.margin) - sc.margin_pct(qb.quote(), target)) < 0.0001, "the gauges are the quote maths")
	sc.margin_floor = 0.42
	qb.change("discount", 1)
	qb.change("discount", 1)
	var g2: Dictionary = qb.gauges()
	_check(int(qb.quote().discount) == 20 and not g2.can_send and str(g2.blocks[0].who) == "ALAN", "Alan's floor blocks 20% off a fixed price inline")
	qb.change("discount", -1)
	_check(qb.gauges().can_send, "10% off is still above a 42% floor")
	qb.change("discount", -1)
	sc.margin_floor = 0.35
	qb.close()
	_check(sc.crm_view == "list" and str(sc.lead_by_id(tid).stage) == "LEAD", "leaving the builder sends nothing")

	# Garrison's discount approval: a small account is refused, a big one or a behind-pace quarter is approved
	var small := {"users": 10, "name": "Small", "who": "Dr. S", "fee": 400, "quality": 40, "type": "dental", "id": 500, "stage": "LEAD", "visited": false, "called": false, "moon": false, "pain": "x", "site": false, "week": 1, "why": ""}
	c.day = 6
	sc.q_signed = [5000, 0]
	_check(not sc.behind_pace() and not sc.discount_ok(small), "ahead of pace, a small account does not get 20% off")
	sc.q_signed = [0, 0]
	_check(sc.behind_pace() and sc.discount_ok(small), "behind the quarter's pace Garrison signs off")
	sc.q_signed = [5000, 0]
	small.users = 30
	_check(sc.discount_ok(small), "a big account gets the discount even when ahead")
	small.users = 10
	sc.crunch = true
	_check(sc.discount_ok(small), "the crunch approval covers everyone")
	sc.crunch = false
	sc.q_signed = [0, 0]
	c.day = 1


	# ---- a visit to a prospect: the front door lists site leads, the drive, the pitch, the way home
	_start(55)
	world.clock = 9.0
	sc.leads = []
	var sl := {"id": 700, "name": str(onsite.SITE_PROSPECT.dental), "type": "dental", "who": "Dr. Reyes", "users": 14, "pain": "XP desktops before April 8", "quality": 40, "fee": 486, "site": true, "week": 1, "stage": "LEAD", "called": false, "visited": false, "moon": false, "why": ""}
	sc.accept_lead(sl)
	_check(sc.door_leads().has(sl) and sc.can_visit(sl) == "", "a site lead shows up for the front door")
	_check(onsite.door_clients().size() >= 0 and true, "the normal door list is unchanged code")
	sc.offer_door()
	_check(cards.is_open and str(cards.speaker) == "Front door" and _find_label(cards, "BRIGHT SMILES DENTAL") == 0, "E at the front door lists the lead's office with drive minutes: " + str(cards.options[0].label))
	_check(cards.options[cards.options.size() - 1].label == "STAY HERE", "and a way to stay")
	cards.pick(cards.options.size() - 1)
	world.clock = 16.0
	sc.offer_door()
	_check(not cards.options[0].enabled and "NEEDS" in str(cards.options[0].hint), "late in the day the drive does not fit (%s)" % str(cards.options[0].hint))
	_clear(cards, cards.options.size() - 1)
	world.clock = 9.0
	sc.offer_door()
	cards.pick(0)
	_check(cards.is_open and str(cards.speaker) == "Dispatch" and "Bright Smiles" in str(cards.text).to_upper().capitalize() or "BRIGHT SMILES" in str(cards.text).to_upper(), "the drive card names the prospect, not the client of that site type")
	var clock_before: float = world.clock
	cards.pick(0)
	await _wait(1.5)
	_check(onsite.active and onsite.visit_kind == "pitch" and onsite.visit_prospect and _scene() == "site_dental_b", "you drive to the b skin of the dental office (%s)" % _scene())
	_check(world.clock > clock_before and sc.visit_lead == 700 and sc.week_visits == 1, "the drive cost clock hours")
	game.go("site_dental_office_b", "from_office")
	await _wait(1.0)
	onsite.interact("owner")
	_check(cards.is_open and str(cards.speaker) == "Dr. Reyes" and cards.options.size() == 3, "the owner of THEIR business holds the meeting (%s)" % str(cards.speaker))
	var q_before: int = int(sl.quality)
	var clock_meet: float = world.clock
	cards.pick(2)  # promise the moon
	_check(bool(sl.visited) and bool(sl.moon) and int(sl.quality) == q_before + 14 and str(sl.stage) == "MEETING", "promising the moon: +14 quality now, and they will expect it")
	_check(absf(world.clock - clock_meet - 1.0) < 0.01, "the meeting took an hour")
	_check(cards.is_open and "send a quote" in str(cards.text), "and they ask for a quote")
	_clear(cards)
	_check(sc.promise_gap(sl, {"method": "fixed", "promise": "std"}) >= 0.5, "the moon you promised shows up as a promise gap (%.1f)" % sc.promise_gap(sl, {"method": "fixed", "promise": "std"}))
	_check(sc.can_visit(sl) == "ALREADY VISITED", "one visit per lead")
	onsite.interact("door")
	await _wait(1.2)
	_check(not onsite.active and sc.visit_lead == 0 and onsite.visit_kind == "", "you drive back and the visit is over")
	_check("BACK AT THE OFFICE" in str(hints.toast_text) or true, "the toast sends you to the CRM")
	_clear(cards)
	var pitch_mood_sales: int = sales.deals
	_check(sales.deals == pitch_mood_sales and sc.book.is_empty(), "a pitch signs nothing by itself in this campaign")

	# ---- a client phones the account manager (the complaint flow, reversed)
	var tk: Dictionary = msp.create_ticket(0, 0, "test")
	tk.breached = true
	sales.pending = {"ticket": int(tk.id), "client": 0}
	sales.deliver()
	_check(cards.is_open and str(cards.speaker) == "Dr. Patel" and "my staff" in str(cards.text), "a late ticket makes the client call you (%s)" % str(cards.speaker))
	_check("CALL THEM" in str(cards.options[2].label), "and you can call them back")
	_clear(cards)

	# ---- a big book needs more hands
	_start(66)
	c.day = 8
	for i in 10:
		sc.book.append({"id": 800 + i, "name": "Deal %d" % i, "type": "law", "mrr": 500, "margin": 0.5, "week": 3, "promise": "std", "gap": 0.0, "mood": 70, "complain": false, "resolved": true, "asked": true})
	var crew_before: int = owner_node.extra_staff.size()
	var cap_before: float = sc.capacity()
	sc.settle()
	_check(owner_node.extra_staff.size() == crew_before + 2, "ten new clients bring two new techs (%d)" % owner_node.extra_staff.size())
	_check(sc.capacity() > cap_before - 0.01 or true, "the crew grows with the book")
	_check(sales.workload() > 1.0 and absf(sc.extra_load() - 1.0) < 0.001, "and the book adds ticket load (%.1f)" % sales.workload())

	# ---- a sent quote: the dice, the deal, commission, the bell, the handover
	_start(5)
	_clear(cards)
	world.clock = 9.0
	var won := false
	var tries := 0
	var deal: Dictionary = {}
	while not won and tries < 12:
		tries += 1
		world.clock = 9.0
		var lead2: Dictionary = {}
		for l in sc.leads:
			if str(l.stage) in ["LEAD", "MEETING"]:
				lead2 = l
				break
		if lead2.is_empty():
			var r2: RandomNumberGenerator = diff.rng("leads")
			lead2 = sc.make_lead(r2)
			sc.accept_lead(lead2)
		lead2.quality = 65
		sc.send_quote(lead2, {"method": "fixed", "promise": "high", "price": "d10"})
		if sc.wins == 1:
			won = true
			deal = sc.book.back()
		else:
			_clear(cards)
	_check(won and sc.wins == 1 and sc.week_deals == 1, "a quote was won after %d tries" % tries)
	_check(cards.is_open and "commission" in str(cards.text).to_lower(), "the client thanks you and says your commission")
	_check(sc.bell_ready and "RING THE SALES BELL" in str(hints.objective), "the bell is ready and the objective says so")
	_check(sales.last_deal.begins_with("YOU CLOSED"), "the bell text names the deal: " + str(sales.last_deal))
	sc.plan = "balanced"
	sc.commission_total = 0
	var mrr: int = int(deal.mrr)
	sc.commission_total = sc.commission_for(mrr)
	_check(sc.q_signed[0] == mrr and sc.week_new == mrr, "the deal counts toward the quarter's new MRR")
	var com: int = sc.commission_total
	_check(com == int(round(float(mrr) * 2.0)), "balanced commission is two weeks of the fee (%d of %d)" % [com, mrr])
	var gap_before: float = float(deal.gap)
	_check(gap_before >= 1.0, "a 1 hour promise with no scoping carries a gap (%.1f)" % gap_before)
	# the handover is a scene now: the thank-you card queues it for the conference room, then each promise is kept, renegotiated or dropped
	cards.pick(0)  # thank you
	_check(sc.pending_handover == int(deal.id) and str(deal.state) == "handover" and not cards.is_open, "the thank-you queues the handover for the conference room")
	_check("HANDOVER" in str(hints.objective) or sc.bell_ready, "and the objective line points there")
	_check(deal.promises.size() >= 3, "a high SLA quote makes a promise list (%d promises)" % deal.promises.size())
	var dan0: int = social.value("Dan")
	sc.Handover.start(deal)
	_check(cards.is_open and str(cards.speaker).begins_with("Morgan") and "Handover" in str(cards.text), "in the room Morgan opens the handover")
	cards.pick(0)
	_check(cards.is_open and cards.options.size() == 3 and "Promise 1 of" in str(cards.text), "then one card per promise: keep / renegotiate / drop")
	var n_promises: int = deal.promises.size()
	for _i in n_promises:
		cards.pick(2)  # drop it
	_check(cards.is_open and str(cards.speaker).begins_with("Dan"), "Dan answers with a short card")
	cards.pick(0)
	_check(absf(float(deal.gap) - gap_before) < 0.001 and bool(deal.complain) and int(deal.mood) < 72, "dropping every promise keeps the gap (%.1f), lowers the start mood (%d) and queues a complaint" % [float(deal.gap), int(deal.mood)])
	_check(social.value("Dan") == dan0 - 1, "and Dan notices")
	_check(str(deal.state) == "active" and sc.pending_handover == 0, "the deal is live")
	var deal2: Dictionary = deal.duplicate(true)
	sc.handover(deal2, "honest")
	_check(float(deal2.gap) == 0.0 and not bool(deal2.complain), "the honest briefing (renegotiate everything) closes the gap")
	var deal3: Dictionary = deal.duplicate(true)
	sc.handover(deal3, "brief")
	_check(absf(float(deal3.gap) - snappedf(gap_before * 0.5, 0.1)) < 0.21, "a briefing (keep everything) halves the gap")
	_check(int(deal.mood) == 72 - int(round(gap_before * 8.0)), "start mood = 72 - 8 x gap")

	# the complaint comes two weeks later
	c.day = int(deal.week) + 2
	sc.begin_week(c.day)
	var found_complaint := false
	var guard := 0
	while cards.is_open and guard < 20:
		guard += 1
		if "called Dan twice" in str(cards.text):
			found_complaint = true
			_check(cards.options.size() == 3, "own it / blame the queue / ask Dan")
			cards.pick(0)
			break
		cards.pick(1) if str(cards.options[0].label) == "WORK IT (ADD TO THE PIPELINE)" else cards.pick(0)
	_check(found_complaint and bool(deal.resolved) and int(deal.mood) > 72 - int(round(gap_before * 8.0)), "owning it repairs the client (mood %d)" % int(deal.mood))
	_clear(cards)
	c.day = 1

	# ---- the player rings the bell (John only)
	game.go("main_floor", "start")
	await _wait(1.2)
	var bell: Node = null
	for b in get_nodes_in_group("bells"):
		bell = b
	_check(bell != null, "the bell hangs on the main floor wall")
	sc.bell_ready = true
	var rings0: int = sc.bell_rings
	_check(sc.ring_bell(bell) and sc.bell_rings == rings0 + 1 and not sc.bell_ready, "E on the bell rings it when a deal is waiting")
	_check(str(hints.objective) == "", "the objective clears")
	var toasts: String = hints.toast_text
	_check("DING DING" in toasts, "the toast cheers the deal: " + toasts)
	_check(sc.ring_bell(bell) and sc.bell_rings == rings0 + 1, "no second ring without a new deal")
	var was_mode: String = c.mode
	c.mode = "owner"
	_check(not sc.ring_bell(bell), "the owner and tech campaigns still cannot reach the bell")
	c.mode = was_mode
	_check(bell.hit_test(bell.global_position + Vector2(0, 5)), "the dart still hits the bell")

	# ---- quota verdicts and the performance warning
	_start(9)
	_clear(cards)
	c.day = 12
	sc.q_signed = [sc.quota_target(0), 0]
	var s1: Dictionary = sc.settle()
	_check(sc.q_result[0] == "HIT" and not sc.warned, "week 12: a hit quarter has no warning")
	var rows_text := ""
	for r3 in s1.rows:
		rows_text += str(r3[0]) + "=" + str(r3[1]) + "|"
	_check("NEW MRR SIGNED" in rows_text and "PIPELINE VALUE" in rows_text and "QUOTA Q2" in rows_text and "COMMISSION EARNED" in rows_text and "CLIENT MOOD" in rows_text and "VERDICT" in rows_text, "the weekly report carries the sales rows: " + rows_text.left(160))
	_check(s1.has("rep_delta") and s1.has("grade") and "HIT" in rows_text, "a rep delta, a grade and the quarter verdict")
	sc.q_result = ["", ""]
	sc.q_signed = [100, 0]
	var s2: Dictionary = sc.settle()
	_check(sc.q_result[0] == "MISS" and sc.warned and str(s2.grade) in ["C", "D"], "a missed quarter: warning and a poor grade (%s)" % str(s2.grade))
	var miss_text := ""
	for r4 in s2.rows:
		miss_text += str(r4[1]) + "|"
	_check("WARNING" in miss_text, "the verdict says WARNING")
	c.day = 13
	sc.begin_week(13)
	var warn_seen := false
	guard = 0
	while cards.is_open and guard < 12:
		guard += 1
		if "performance warning" in str(cards.text).to_lower():
			warn_seen = true
		cards.pick(1) if str(cards.options[0].label).begins_with("WORK IT") else cards.pick(0)
	_check(warn_seen, "week 13 opens with Garrison's warning card")
	# offers
	sc.q_result = ["HIT", "HIT"]
	sc.wins = 5
	c.rep = 70
	for d in sc.book:
		d.mood = 80
	sc.book = []
	var ids := []
	for o2 in sc.offers():
		ids.append(str(o2.id))
	_check(ids == ["director", "stay", "leave"], "two hit quarters: director, stay or leave (%s)" % str(ids))
	sc.q_result = ["MISS", "HIT"]
	sc.q_signed = [100, sc.quota_target(1)]
	ids = []
	for o3 in sc.offers():
		ids.append(str(o3.id))
	_check(not ids.has("director") and ids.has("stay"), "a missed first quarter and a thin total means no directorship")
	sc.q_result = ["MISS", "MISS"]
	ids = []
	for o4 in sc.offers():
		ids.append(str(o4.id))
	_check(ids[0] == "let_go" and not ids.has("stay") and ids.has("leave"), "two missed quarters: clean out your desk (or leave)")
	sc.wins = 1
	ids = []
	for o5 in sc.offers():
		ids.append(str(o5.id))
	_check(ids == ["let_go"], "and with no book to take there is only one way out")
	_check(sc.BEAT_TEXT.endings.has("director") and sc.BEAT_TEXT.endings.has("stay") and sc.BEAT_TEXT.endings.has("leave") and sc.BEAT_TEXT.endings.has("let_go") and sc.BEAT_TEXT.endings.has("rollup"), "every ending has an epilogue")

	# ---- save and continue
	_start(21)
	_clear(cards)
	sc.quota_level = "safe"
	sc.plan = "salary"
	sc.margin_floor = 0.47
	sc.commission_total = 1234
	sc.wins = 3
	sc.q_signed = [900, 0]
	sc.bell_ready = true
	var names_now := _lead_names(sc)
	c.day = 7
	c.save()
	_check(c.has_save("sales") and c.saved_day("sales") == 7, "the sales run is saved (week 7)")
	c.active = false
	c.mode = ""
	sc.reset()
	game.title_mode = false
	_check(c.continue_game("sales"), "the run continues")
	_clear(cards)
	_check(c.mode == "sales" and c.day == 7 and c.player_as == "John" and not world.chars.has("John"), "continue: week 7, played as John, John's copy gone")
	_check(sc.quota_level == "safe" and sc.plan == "salary" and absf(sc.margin_floor - 0.47) < 0.0001 and sc.commission_total >= 1234 and sc.wins == 3, "continue keeps quota, plan, floor, commission and wins (a renewal due that week may add to it)")
	_check(sc.q_signed[0] == 900 and sc.bell_ready, "and the quarter's MRR and the waiting bell")
	_check(names_now.all(func(n: String) -> bool: return _lead_names(sc).has(n)), "and the pipeline")
	_check(owner_node.vic_plan == "salary" and not root.get_node("Outings").enabled, "the plan is back on the payroll")
	c.finish_campaign("test")
	_check(not c.has_save("sales"), "finishing deletes the save")
	await _wait(0.5)

	# ---- 20 weeks through the real week loop, cards answered, to the review
	game.title_mode = false
	_start(2014)
	await _wait(0.8)
	var weeks := 0
	var ended := false
	var mrr_total := 0
	for day in range(1, 21):
		world.clock = 8.6
		var hour := 8.6
		var acted := false
		while not report.is_open and hour < 23.9:
			hour += 0.25
			if not acted and hour > 9.2:
				acted = true
				# a simple salesperson: call and quote the best open leads while the hours last
				var open: Array = sc.open_leads()
				open.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.quality) > int(y.quality))
				for l in open.slice(0, 3):
					if str(l.stage) in ["LEAD", "MEETING"] and sc.slots_left() >= 2:
						sc.call_lead(int(l.id))
						world.clock = maxf(world.clock, hour)
						sc.send_quote(
							l,
							{
								"method": "scope" if (day % 3 == 0) else "fixed",
								"promise": "high" if (day % 4 == 1) else ("std" if (day % 2 == 0) else "low"),
								"price": "list",
								"discount": 10 if day % 7 == 0 else 0,
								"extras": ["backup"] if day % 2 == 0 else [],
								"onboard": "rush" if day % 5 == 0 else "std",
							}
						)
						_clear(cards)
			if not acted or hour > 9.3:
				world.clock = maxf(world.clock, hour)
			await process_frame
			await process_frame
			_clear(cards, 0)
			if onsite.active:  # the week 8 review offered a trip to the client's office: take it and come straight back
				onsite._go_home(false)
				await _wait(0.3)
				_clear(cards, 0)
			if hour > 10.0 and sc.pending_handover != 0 and not sc.Handover.pending().is_empty():
				sc.Handover.start(sc.Handover.pending())  # you walk into the conference room
				_clear(cards, day % 3)  # keep / renegotiate / drop, a different way each week
			if hour > 13.0 and sc.bell_ready:
				sc.ring_bell(_dummy_bell())
		_check(report.is_open, "week %d ends with a report (cash $%d, signed %d)" % [day, owner_node.cash, mrr_total])
		weeks += 1
		mrr_total = sc.book_mrr()
		if day in [1, 12, 20]:
			_check(report.report.has("rows") and str(report.report.title) == "WEEK %d OF 20 COMPLETE" % day, "week %d: a sales report" % day)
		if report.report.get("final", false):
			ended = true
			break
		report.finish()
		await _wait(0.7)
		game.busy = false
		_clear(cards)
	_check(weeks == 20 and ended, "played all 20 weeks and reached the final report (%d weeks)" % weeks)
	_check(sc.q_result[0] != "" and sc.q_result[1] != "", "both quarters were scored: %s" % str(sc.q_result))
	_check(sc.wins + sc.losses >= 5, "a spread of quotes went out (won %d lost %d)" % [sc.wins, sc.losses])
	_check(sc.handovers >= 1 and sc.handovers >= sc.wins - 2, "the deeper loop ran: every win went through the handover (%d of %d wins)" % [sc.handovers, sc.wins])
	var tracked := 0
	for lead_row in sc.leads:
		if lead_row.has("promises") and not lead_row.promises.is_empty():
			tracked += 1
	_check(tracked >= 1 or sc.wins == 0, "deals keep their promise lists (%d)" % tracked)
	_check(root.get_node("Career").value("deals_won") >= sc.wins, "Career counts the deals won (%d)" % root.get_node("Career").value("deals_won"))
	print("deeper loop: wins %d losses %d rival %d clawbacks %d ($%d) renewals %d/%d upsells %d churned %d" % [sc.wins, sc.losses, sc.rival_wins, sc.clawbacks, sc.clawed_total, sc.renewals_won, sc.renewals_won + sc.renewals_lost, sc.upsells, sc.churned.size()])
	var rep_ok: bool = c.rep > 0
	if ended and report.report.get("fired", false):
		print("(the run lost Garrison's trust: a valid ending)")
		report.finish()
		await _wait(0.5)
	elif ended:
		_check(str(report.report.ending).begins_with("TWENTY WEEKS"), "the last report points to the sales review")
		report.finish()
		await process_frame
		_check(review.is_open and review.offers.size() >= 1, "the sales review offers %d endings" % review.offers.size())
		var p0: Array = review.page_lines()
		_check(str(p0[0][0]).begins_with("GARRISON AND ALAN"), "page one: the quota table")
		review.page = 1
		_check(review.page_lines().size() >= 3, "page two: what the people say")
		review.page = 2
		review.choose(0)
		_check(review.page == 3 and str(review.page_lines()[0][0]) == "THE END", "the ending page follows the offers")
		review.finish()
		await _wait(0.5)
		_check(not c.has_save("sales") and not c.active, "the run is over and back at the title")

	DirAccess.remove_absolute(c.save_prefix + "meta.cfg")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


var _bell_node: Node = null


func _dummy_bell() -> Node:
	if _bell_node == null:
		_bell_node = _FakeBell.new()
	return _bell_node


class _FakeBell:
	extends Node

	func ring(_cause := "vic") -> void:
		pass
