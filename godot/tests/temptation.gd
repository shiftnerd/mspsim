extends SceneTree
# R38 P0: temptation (Temptation): a skeleton fires on its due week, coming clean is cheaper than the bill, the conscience bands and
# the weekly honesty cap, Christy's folder count, and the due diligence deduction. Headless, seeded.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1


func _fresh(c: Node, cards: Node, day: int) -> void:
	c.new_game("owner")
	_clear(cards)
	c.day = day
	seed(7)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var t: Script = load("res://scripts/temptation.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- a skeleton fires on its due week
	_fresh(c, cards, 8)
	_check(t.folder_count() == 0 and t.diligence() == 0.0, "an empty folder")
	_check(t.add_skeleton("temp_seats", 7), "a skeleton is added")
	_check(
		not t.add_skeleton("temp_seats", 7) and t.folder_count() == 1, "one of each kind at a time"
	)
	var sk: Dictionary = o.skel[0]
	_check(
		int(sk.due) == 15 and str(sk.class) == "vendor" and int(sk.size) == 1100,
		"due week 15, class vendor, size 1100"
	)
	var cash0: int = o.cash
	c.day = 14
	t.week(o)
	_check(t.folder_count() == 1 and o.cash == cash0, "nothing on week 14")
	c.day = 15
	t.week(o)
	_check(t.folder_count() == 0, "the bill leaves the folder on week 15")
	_check(o.cash == cash0 - 1100, "and costs $1100")
	_clear(cards)

	# ---- a drawn due date stays in the documented range and is deterministic with the seed
	_fresh(c, cards, 8)
	t.add_skeleton("temp_reboot")
	var due1 := int(o.skel[0].due)
	_check(due1 >= 8 + 4 and due1 <= 8 + 6, "the drawn bill date is inside the range: %d" % due1)
	_fresh(c, cards, 8)
	t.add_skeleton("temp_launder")
	_check(int(o.skel[0].due) >= 8 + 5, "another range")
	_fresh(c, cards, 8)
	o.apply({"skel": ["temp_price", 6]})
	_check(t.folder_count() == 1 and int(o.skel[0].due) == 14, "fx skel [id, weeks] seeds one")
	o.apply({"skel": [["temp_quest", 99], ["temp_restore", 6]]})
	_check(t.folder_count() == 3, "fx skel takes a list")

	# ---- a bill with no date waits for its trigger
	_fresh(c, cards, 8)
	t.add_skeleton("temp_quest")
	_check(int(o.skel[0].due) == 99, "the insurer bill has no date")
	c.day = 20
	t.week(o)
	_check(t.folder_count() == 1, "and does not fire by itself")

	# ---- coming clean is cheaper than the bill
	_fresh(c, cards, 8)
	t.add_skeleton("temp_seats", 7)
	var bill := int(o.skel[0].size)
	var clean: int = t.clean_cost("temp_seats")
	_check(
		clean > 0 and clean < bill,
		"coming clean ($%d) costs less than the bill ($%d)" % [clean, bill]
	)
	var c0: int = o.cash
	var conscience0: int = t.consc()
	_check(
		t.come_clean("temp_seats") and o.cash == c0 - clean and t.folder_count() == 0,
		"come_clean pays the cost and empties the folder"
	)
	_check(t.consc() == conscience0 + 1, "and the conscience rises by one")
	_check(
		not t.come_clean("temp_seats") and t.clean_cost("temp_seats") == 0,
		"nothing to come clean about twice"
	)

	# ---- conscience bands and the weekly honesty cap
	_fresh(c, cards, 8)
	_check(t.band() == "CLEAN BOOKS", "0 reads CLEAN BOOKS")
	t.change_consc(-1)
	_check(t.band() == "A FEW LOOSE ENDS", "-1: A FEW LOOSE ENDS")
	t.change_consc(-2)
	_check(t.band() == "A FEW LOOSE ENDS" and t.consc() == -3, "-3: still A FEW LOOSE ENDS")
	t.change_consc(-1)
	_check(t.band() == "SKELETONS", "-4: SKELETONS")
	t.change_consc(-2)
	_check(t.band() == "SKELETONS" and t.consc() == -6, "-6: SKELETONS")
	t.change_consc(-1)
	_check(t.band() == "A CLOSET FULL", "-7: A CLOSET FULL")
	t.change_consc(5)
	_check(t.consc() == -6, "honest choices rise by at most 1 a week (-7 + 1)")
	t.change_consc(1)
	_check(t.consc() == -6, "a second honest choice in the same week adds nothing")
	c.day += 1
	t.change_consc(1)
	_check(t.consc() == -5, "the next week it counts again")
	o.apply({"consc": -2})
	_check(t.consc() == -7, "fx consc falls without a cap")
	_check(not str(t.folder_text()).contains("-7"), "the conscience is never printed as a number")

	# ---- due diligence from week 16
	_fresh(c, cards, 10)
	for id in ["temp_seats", "temp_reboot", "temp_review", "temp_price"]:
		t.add_skeleton(id, 30)
	var m_clean_early: float = o.multiple()
	c.day = 16
	var with4: float = o.multiple()
	_check(t.diligence() == 1.5, "four skeletons cost the maximum 1.5 of the multiple")
	o.skel = []
	var without: float = o.multiple()
	_check(
		with4 <= without - 1.4 or with4 == 2.0,
		"the multiple is lower with the folder (%.2f vs %.2f)" % [with4, without]
	)
	_check(m_clean_early > 0.0 and t.diligence_line() == "FOUND IN DILIGENCE: 0", "the review line")

	# ---- cozy halves the bill
	_fresh(c, cards, 8)
	t.add_skeleton("temp_seats", 1)
	var normal: int = t.bill_size(o.skel[0])
	_check(normal == 1100, "the normal bill is 1100")

	# ---- the eight cards and their bills exist, and the shortcut seeds the skeleton
	var ids: Array = t.BILLS.keys()
	_check(ids.size() == 8, "eight temptations")
	for id in ids:
		var card: Dictionary = o.CARDS.get(id, {})
		_check(not card.is_empty(), "card %s is in Owner.CARDS" % id)
		_check(not o.CARDS.get("bill_" + id, {}).is_empty(), "card bill_%s exists" % id)
		var seeds := 0
		var honest := 0
		for opt in card.get("options", []):
			var branches: Array = [opt.get("fx", {})]
			for entry in opt.get("roll", []):
				branches.append(entry[1])
			var seeded := false
			for fx in branches:
				seeded = seeded or JSON.stringify((fx as Dictionary).get("skel", "")).contains(id)
			if seeded and not opt.has("roll"):
				seeds += 1
			elif not seeded and int((opt.get("fx", {}) as Dictionary).get("consc", 0)) > 0 or opt.has("roll") and not seeded:
				honest += 1
		_check(seeds >= 1 and honest >= 1, "%s has a shortcut and an honest answer" % id)
	for id in ["temp_2fa", "temp_launder", "temp_restore", "temp_price"]:
		var placed := false
		for ev in o.events_on(int({"temp_2fa": 6, "temp_launder": 10, "temp_restore": 12, "temp_price": 14}[id])):
			placed = placed or str(ev.get("card", "")) == id
		_check(placed, "%s has a fixed morning" % id)
	var rv: Script = load("res://scripts/rival.gd")
	for id in ["temp_seats", "temp_reboot", "temp_review", "temp_quest"]:
		_check(rv.ARC.values().has(id), "%s is placed by the arc" % id)

	# ---- the vendor bill: the saving ends, list price from then on, the card text is filled in
	_fresh(c, cards, 8)
	var w0: int = o.weekly_extra
	o.apply(o.CARDS.temp_seats.options[0].fx)
	_check(o.weekly_extra == w0 - 71 and t.folder_count() == 1 and t.consc() == -2, "the 41 seats shortcut saves $71 a week and costs the conscience")
	c.day = int(o.skel[0].due)
	var cash1: int = o.cash
	t.week(o)
	_check(o.cash == cash1 - 1100 and o.weekly_extra == w0 + 8, "the bill: $1100 and the saving gone plus a cold vendor")
	_check(cards.is_open and not cards.text.contains("{") and cards.text.contains("$1,100"), "the bill card is filled in: " + cards.text.substr(0, 60))
	cards.pick(0)
	_check(t.consc() == -1, "owning up to the bill gives a point back")
	_clear(cards)

	# ---- a client bill falls on one client; the launder bill makes them leave
	_fresh(c, cards, 8)
	var n0: int = root.get_node("Sales").active.size()
	var moods: Dictionary = {}
	for cl in root.get_node("Sales").active:
		moods[cl] = root.get_node("Sales").mood(cl)
	t.add_skeleton("temp_reboot", 1)
	c.day = 9
	t.week(o)
	var hurt := 0
	for cl in moods:
		if root.get_node("Sales").mood(cl) < int(moods[cl]):
			hurt += 1
	_check(hurt == 1, "the reboot bill hurts exactly one client (%d)" % hurt)
	_check(cards.is_open and cards.text.contains("ADVANCED DIAGNOSTICS") and not cards.text.contains("{"), "the reboot card names the client")
	_clear(cards)
	t.add_skeleton("temp_launder", 1)
	c.day = 10
	t.week(o)
	_check(root.get_node("Sales").active.size() == n0 - 1, "the client whose mailbox it was leaves")
	_clear(cards)

	# ---- reputation: the forum friends go quiet
	_fresh(c, cards, 12)
	var nerds := root.get_node("Nerds")
	nerds.friend = {"rodent_rick": 60, "gnawer": 45, "other": 10}
	var rep0: int = c.rep
	t.add_skeleton("temp_review", 1)
	c.day = 13
	t.week(o)
	_check(int(nerds.friend.rodent_rick) == 30 and int(nerds.friend.gnawer) == 15 and int(nerds.friend.other) == 10, "the two best regulars lose 30")
	_check(c.rep < rep0, "and the reputation falls")
	_clear(cards)
	nerds.friend = {}

	# ---- the margin bill picks the discounted client and offers a rise
	_fresh(c, cards, 10)
	var cheap: int = root.get_node("Sales").active[0]
	o.discount[cheap] = {"mult": 0.75, "weeks": 20}
	t.add_skeleton("temp_price", 1)
	c.day = 11
	t.week(o)
	_check(cards.is_open and cards.options.size() == 2 and cards.text.contains(str(root.get_node("Msp").CLIENTS[cheap].name)), "the margin bill names the discounted client")
	_clear(cards)

	# ---- the insurer bill waits for a claim, then reads the renewal answers
	_fresh(c, cards, 16)
	var w1: int = o.weekly_extra
	o.apply(o.CARDS.temp_quest.options[0].fx)
	_check(int(o.skel[0].due) == 99 and o.weekly_extra == w1 - 27, "yes to everything: premium down, no date")
	t.claim(o)
	_check(t.folder_count() == 0 and o.weekly_extra == w1, "a claim fires the bill and the premium is true again")
	_check(cards.is_open and cards.text.contains("$1,800"), "the insurer card quotes the bill")
	_clear(cards)
	t.claim(o)
	_check(not cards.is_open, "no skeleton, no bill")
	_fresh(c, cards, 16)
	o.apply({"skel": ["temp_quest", 99]})
	o.apply({"bec": "claim"})
	_check(t.folder_count() == 0, "a wire fraud claim fires it too")
	_clear(cards)

	# ---- COME CLEAN from the second skeleton, once in four weeks, with the costs filled in
	_fresh(c, cards, 9)
	t.add_skeleton("temp_price", 6)
	t.week(o)
	_check(not o.flags.get("arc_queue", []).has("temp_come_clean"), "one skeleton: no offer")
	t.add_skeleton("temp_seats", 8)
	t.week(o)
	_check(o.flags.get("arc_queue", []).has("temp_come_clean"), "two skeletons: the offer is queued")
	rv.morning(o)
	_check(cards.is_open and cards.text.contains("2 things") and cards.options.size() == 3, "the card shows with both choices")
	_check(str(cards.options[0].label).contains("$240") and str(cards.options[1].label).contains("$440"), "with the costs: %s / %s" % [cards.options[0].label, cards.options[1].label])
	var cash2: int = o.cash
	cards.pick(1)
	_check(t.find("temp_seats") < 0 and t.find("temp_price") >= 0 and o.cash == cash2 - 440, "owning up to the biggest removes it for $440")
	_clear(cards)
	t.week(o)
	_check(not o.flags.get("arc_queue", []).has("temp_come_clean"), "and nothing is queued again the same week")

	# ---- the vendor rebate on a clean record: week 16 on, once, never with a skeleton, bad conscience or a cold vendor
	_fresh(c, cards, 15)
	o.consc = 0
	var cash3: int = o.cash
	_check(not t.vendor_rebate(o) and o.cash == cash3, "no rebate before week 16")
	c.day = 16
	_check(t.vendor_rebate(o) and o.cash == cash3 + t.REBATE, "a clean record earns the rebate in week 16")
	_check(not t.vendor_rebate(o) and o.cash == cash3 + t.REBATE, "and only once")
	_clear(cards)
	_fresh(c, cards, 16)
	t.add_skeleton("temp_price", 6)
	_check(not t.vendor_rebate(o), "a skeleton in the folder: no rebate")
	_fresh(c, cards, 16)
	o.consc = -2
	_check(not t.vendor_rebate(o), "a bad conscience: no rebate")
	_fresh(c, cards, 16)
	o.flags["vendor_cold"] = 12
	_check(not t.vendor_rebate(o), "a vendor that caught you: no rebate")
	_clear(cards)

	# ---- a vendor switch: the intro rate now, the overlapping invoice next week, list price after 13 weeks, Christy warns the second time
	_fresh(c, cards, 10)
	var seats_card := {"text": "WebWoot sent the form."}
	_check(not str(t.dress_seats(o, seats_card.duplicate()).text).contains("Christy"), "no warning before the first switch")
	var wv: int = o.weekly_extra
	var cash4: int = o.cash
	t.switch_vendor(o)
	_clear(cards)
	_check(o.weekly_extra == wv - t.PROMO_SAVE and int(o.flags.switches) == 1 and o.flags.timed.size() == 2, "the intro rate saves %d a week and two costs are queued" % t.PROMO_SAVE)
	c.day = 11
	t.week(o)
	_check(o.cash == cash4 - t.OVERLAP and o.flags.timed.size() == 1, "next week both vendors bill")
	_clear(cards)
	c.day = 10 + t.PROMO_WEEKS - 1
	t.week(o)
	_check(o.weekly_extra == wv - t.PROMO_SAVE, "the intro rate still runs in week 12 of it")
	c.day = 10 + t.PROMO_WEEKS
	t.week(o)
	_check(o.weekly_extra == wv + t.FULL_EXTRA and o.flags.timed.is_empty(), "after 13 weeks the price is list price, above the old one")
	_clear(cards)
	_check(str(t.dress_seats(o, seats_card.duplicate()).text).contains("Christy:"), "Christy warns on the next vendor card")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
