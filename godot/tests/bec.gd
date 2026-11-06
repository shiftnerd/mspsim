extends SceneTree
# R37: business email compromise (wire fraud), owner campaign: the scare card, the call-back rule, the email filter
# service, the weekly exposure roll, the loss cards (credit, lawyer, insurer, blame), the rider, Christy's own invoice,
# saving, and the 2013-14 text rules. Also the tech chain on day 8 is still the BEC job. Headless, seeded.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


func _strings(v: Variant, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Dictionary:
		for k in v:
			_strings(v[k], out)
	elif v is Array:
		for x in v:
			_strings(x, out)


func _start(c: Node, cards: Node, day: int, reseed := true) -> void:
	c.new_game("owner")
	_clear(cards)
	c.day = day
	if reseed:
		seed(7)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	var proj := root.get_node("Projects")
	var msp := root.get_node("Msp")
	var growth := root.get_node("Growth")
	var inc: Script = load("res://scripts/incident.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- the calendar and the text
	var scare_week := 0
	var marge_week := 0
	for day in o.DAYS:
		for ev in o.DAYS[day]:
			if str(ev.get("card", "")) == "bec_scare":
				scare_week = int(day)
			if str(ev.get("card", "")) == "bec_marge":
				marge_week = int(day)
	_check(scare_week == 13 and marge_week == 15, "scare on week 13, Christy's invoice on week 15")
	for id in ["bec_scare", "bec_marge", "bec_loss", "bec_rider", "bec_lawyer_ok", "bec_lawyer_bad", "bec_claim_ok", "bec_claim_no", "bec_blame_left", "bec_blame_stay"]:
		_check(o.CARDS.has(id) and (o.CARDS[id].options as Array).size() >= 1, "card %s exists" % id)
	_check((o.CARDS.bec_scare.options as Array).size() == 4, "the scare has four answers (policy, filter, both, ignore)")
	_check(proj.SERVICES.has("mailfilter") and int(proj.SERVICES.mailfilter.price) > int(proj.SERVICES.mailfilter.cost), "the email filter is a recurring service with a margin")
	var texts: Array = []
	_strings(o.CARDS, texts)
	var low := ""
	for t in texts:
		low += " " + str(t).to_lower()
	for bad in ["mfa ", "chatgpt", " ai ", "microsoft 365", "office 365", "teams", "slack", "windows 10", "zelle"]:
		_check(not low.contains(bad), "no %s in the cards" % bad.strip_edges())
	var glyphs: Dictionary = load("res://scripts/pixelfont.gd").GLYPHS
	var odd := ""
	for id in o.CARDS:
		if str(id).begins_with("bec_") or str(id).begins_with("pm_"):
			var all: Array = []
			_strings(o.CARDS[id], all)
			for t in all:
				for ch in str(t).to_upper():
					if ch != "{" and ch != "}" and not glyphs.has(ch):
						odd += ch
	_check(odd == "", "the new cards use only letters the 3x5 font has: '%s'" % odd)

	# ---- the scare: policy, filter, both, ignore
	_start(c, cards, 13)
	var cash0: int = o.cash
	o.show_card("bec_scare")
	_check(cards.text.contains(msp.CLIENTS[int(o.flags.bec_client)].name) and cards.text.contains("$"), "the scare names a client and a sum")
	cards.pick(0)
	_clear(cards)
	_check(o.flags.get("bec_policy", false) and o.flags.get("practice_callback", false) and o.cash == cash0 - 350, "the call-back rule costs $350 and counts as a maturity practice")
	_check(growth.owner_used >= 4.0, "it also takes the owner's hours")

	_start(c, cards, 13)
	cash0 = o.cash
	o.show_card("bec_scare")
	cards.pick(1)
	_clear(cards)
	var signed := 0
	for cl in sales.active:
		if proj.has_service(int(cl), "mailfilter"):
			signed += 1
	_check(signed >= 1 and o.cash == cash0 - 250, "the filter offer signs at least the client in the story: %d signed" % signed)
	_check(not o.flags.get("bec_policy", false), "the filter alone is not the call-back rule")
	_check(proj.service_revenue() >= 45 * signed, "the filter adds recurring revenue")

	_start(c, cards, 13)
	o.show_card("bec_scare")
	cards.pick(3)
	_clear(cards)
	_check(o.flags.get("bec_ignored", false), "ignoring is remembered")

	# ---- the exposure falls with the policy and the filter
	_start(c, cards, 13)
	o.flags["card_bec_scare"] = 0
	var base: float = inc.exposure()
	o.flags["bec_policy"] = true
	var with_policy: float = inc.exposure()
	for cl in sales.active:
		proj.sell_service(int(cl), "mailfilter")
	var with_both: float = inc.exposure()
	_check(base > with_policy and with_policy > with_both, "exposure %.3f > %.3f > %.3f with policy and filter" % [base, with_policy, with_both])
	_check(inc.risk_word() == "LOW", "a protected shop reads LOW")
	o.flags["bec_policy"] = false
	o.flags["pm_bec"] = "skip"
	for cl in sales.active:
		(proj.services as Dictionary).erase(int(cl))
	_check(inc.exposure() > base, "a skipped review makes the exposure worse")
	_check(inc.risk_word() == "HIGH", "an unprotected shop reads HIGH")

	# ---- the roll: unarmed before the scare, a hit queues the cards, caps and gaps hold
	_start(c, cards, 13)
	var hits := 0
	for i in 60:
		o.flags.erase("bec_losses")
		o.flags.erase("bec_last")
		o.flags.erase("inc_queue")
		inc.week()
	_check(int(o.flags.get("bec_losses", 0)) == 0, "no scare card yet: no roll")
	o.flags["card_bec_scare"] = 0
	o.flags["bec_ignored"] = true
	for i in 40:
		o.flags.erase("bec_losses")
		o.flags.erase("bec_last")
		o.flags.erase("inc_queue")
		inc.week()
		hits += int(o.flags.get("bec_losses", 0))
	_check(hits > 0, "an ignored shop gets hit sometimes (%d of 40 weeks)" % hits)
	o.flags["bec_losses"] = 2
	o.flags["inc_queue"] = []
	for i in 30:
		inc.week()
	_check((o.flags.inc_queue as Array).is_empty(), "no more than two losses a run")
	o.flags["bec_losses"] = 0
	o.flags["bec_last"] = c.day
	for i in 30:
		inc.week()
	_check((o.flags.inc_queue as Array).is_empty(), "two weeks apart at the least")

	# a forced hit: queue order, one a day
	_start(c, cards, 14)
	o.flags["card_bec_scare"] = 0
	inc._hit(int(sales.active[0]))
	var q: Array = o.flags.inc_queue
	_check(q == ["bec_loss", "bec_rider", "pm_bec"], "the loss, the rider offer and the review are queued: %s" % str(q))
	_check(sales.mood(int(sales.active[0])) <= 88, "the client's mood drops at once")
	inc.morning()
	_check(cards.is_open and cards.text.contains("wired"), "next morning the loss card")
	_clear(cards)
	_check((o.flags.inc_queue as Array).size() == 2, "one card a day")

	# ---- the loss answers
	var key := ""
	var victim := 0
	for pick in 4:
		_start(c, cards, 14)
		victim = int(sales.active[0])
		o.flags["bec_client"] = victim
		o.flags["bec_amount"] = 10000
		cash0 = o.cash
		var mood0: int = sales.mood(victim)
		o.show_card("bec_loss")
		cards.pick(pick)
		match pick:
			0:
				_check(o.cash == cash0 - 4000, "credit: 40% of $10,000 comes off the books")
				_check(proj.has_service(victim, "mailfilter"), "credit: they sign for the filter")
				_check(sales.mood(victim) > mood0, "credit: mood rises")
			1:
				_check(o.cash <= cash0 - 600, "lawyer: $600 for the letter")
				_check(cards.is_open and (cards.text.contains("lawyer") or cards.text.contains("Our lawyer")), "lawyer: an outcome card follows")
			2:
				_check(cards.is_open and (cards.text.contains("insurer") or cards.text.contains("broker")), "insurer: an outcome card follows")
				_check(o.cash >= cash0 - 4000, "insurer: never worse than the credit")
			3:
				_check(cards.is_open, "blame: an outcome card follows")
		_clear(cards)

	# the lawyer is better with a written warning on file
	seed(5)
	var wins := [0, 0]
	for k in 2:
		for i in 80:
			_start(c, cards, 14, false)
			o.flags["bec_client"] = int(sales.active[0])
			o.flags["bec_amount"] = 10000
			o.flags["bec_policy"] = k == 1
			inc.owner_fx("lawyer")
			if cards.text.contains("drop the claim"):
				wins[k] += 1
			_clear(cards)
	_check(wins[1] > wins[0], "the lawyer wins more often with the policy on file (%d vs %d of 80)" % [wins[1], wins[0]])

	# the insurer pays more often with the rider
	seed(6)
	var paid := [0, 0]
	for k in 2:
		for i in 80:
			_start(c, cards, 14, false)
			o.flags["bec_client"] = int(sales.active[0])
			o.flags["bec_amount"] = 10000
			o.flags["bec_rider"] = k == 1
			inc.owner_fx("claim")
			if cards.text.contains("good news"):
				paid[k] += 1
			_clear(cards)
	_check(paid[1] > paid[0], "the insurer pays more often with the rider (%d vs %d of 80)" % [paid[1], paid[0]])

	# the rider card
	_start(c, cards, 14)
	var weekly0: int = o.weekly_extra
	o.show_card("bec_rider")
	cards.pick(0)
	_clear(cards)
	_check(o.flags.get("bec_rider", false) and o.weekly_extra == weekly0 + 30, "the rider is $30 a week")

	# ---- Christy's own invoice
	_start(c, cards, 13)
	cash0 = o.cash
	o.show_card("bec_marge")
	cards.pick(0)
	_clear(cards)
	_check(o.cash == cash0 and o.flags.get("bec_self_check", false), "calling the distributor costs nothing and starts the habit")
	var lost := 0
	seed(11)
	for i in 60:
		_start(c, cards, 13, false)
		cash0 = o.cash
		o.show_card("bec_marge")
		cards.pick(1)
		_clear(cards)
		if o.cash == cash0 - 2400:
			lost += 1
	_check(lost > 15 and lost < 55, "paying without checking loses $2,400 about half the time (%d of 60)" % lost)

	# ---- the books: the report row, the save, the maturity count
	_start(c, cards, 13)
	var rows: Array = o.settle().rows
	var has_row := false
	for r in rows:
		has_row = has_row or str(r[0]) == "WIRE FRAUD RISK"
	_check(not has_row, "no risk row before the scare card")
	o.flags["card_bec_scare"] = 0
	o.flags["bec_policy"] = true
	rows = o.settle().rows
	var row_text := ""
	for r in rows:
		if str(r[0]) == "WIRE FRAUD RISK":
			row_text = str(r[1])
	_check(row_text != "", "the weekly report shows the wire fraud risk: " + row_text)
	o.flags["practice_callback"] = false
	var practices0: int = o.practices()
	o.flags["practice_callback"] = true
	_check(o.practices() == practices0 + 1, "the call-back rule is a practice")
	var saved: Dictionary = o.to_dict()
	var f2: Dictionary = saved.flags
	_check(f2.get("bec_policy", false), "the policy is in the save")

	# ---- the tech campaign's wire fraud job is still on day 8
	c.new_game("tech")
	var story := root.get_node("Story")
	var day8 := ""
	for ev in story.DAYS[8]:
		day8 += str(ev.get("book", ""))
	_check(day8 == "ceofraud", "the tech campaign's BEC job is on day 8")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
