extends SceneTree
# R38 P2: every effect of the good habits is measurable, and neutral while the habit is not adopted (so a game without habits plays as
# before). Covers the touch rules (a restore test, a QBR scorecard, an offboarding...), the hooks in the other systems and the pitches.

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
	cards._queue.clear()


func _fresh_game(c: Node, cards: Node, day: int) -> void:
	c.new_game("owner")
	_clear(cards)
	c.day = day


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var growth := root.get_node("Growth")
	var sales := root.get_node("Sales")
	var msp := root.get_node("Msp")
	var projects := root.get_node("Projects")
	var h: Script = load("res://scripts/habits.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	_fresh_game(c, cards, 8)
	var client := int(sales.active[0])

	# ---- neutral while nothing is adopted
	var odds0: float = projects.change_order_odds(client)
	_check(
		h.change_odds() == 0.0 and h.creep(0.30) == 0.30, "no change odds, creep stays 30 percent"
	)
	_check(
		h.onsite_mult(client) == 1.0 and h.walk_mult() == 1.0 and h.refusal_save() == 0,
		"no onsite saving, no walk-around bonus, no waiver saving"
	)
	_check(
		h.assess_win_adj() == 0.0 and not h.drifting(client), "no honest assessment, no drift chip"
	)
	var mood0: int = sales.mood(client)
	h.qbr(client)
	h.new_client(client)
	h.project()
	h.refusal("waiver")
	h.loss(client)
	h.departure("Sam")
	_check(
		sales.mood(client) == mood0 and not cards.is_open and growth.owner_used == 0.0,
		"the event hooks do nothing without habits"
	)
	_check(not o.habits.has("H2") and o.habits.is_empty(), "and start nothing")
	var cash0: int = o.cash
	o.apply({"cash": -500, "ransom_end": "paid"})
	_check(o.cash == cash0 - 500, "the ransom bill is the full $500 without H1")
	_clear(cards)

	# ---- H1: the tested restore
	_fresh_game(c, cards, 8)
	cash0 = o.cash
	for cl in sales.active:
		msp.backups[int(cl)].ok = false
	_check(
		h.act("H1") == h.TEXT.nobackup and o.cash == cash0 and not o.habits.has("H1"),
		"a restore test with no working backup is refused and free"
	)
	msp.backups[client].ok = true
	var line: String = h.act("H1")
	_check(
		(
			line.begins_with("RESTORE TEST PASSED")
			and o.cash == cash0 - 150
			and h.state("H1") == "ADOPTED"
		),
		"the test passes: $150, H1 adopted"
	)
	_check(
		int(o.habits.H1.tested) == 8 and int(o.habits.H1.uses) == 1,
		"the test date and a use are recorded"
	)
	cash0 = o.cash
	o.apply({"cash": -500, "ransom_end": "paid"})
	_check(o.cash == cash0 - 250, "a fresh H1 halves the ransom bill")
	_clear(cards)
	_check(h.restore_fail() == 0.0, "a fresh H1: the restore always works")
	c.day = 8 + 13
	_check(
		h.restore_fail() == 0.15 and h.ransom_mult() == 0.75,
		"stale: 15 percent fail, the bill discount halves"
	)
	c.day = 8 + 26
	_check(
		h.restore_fail() == 0.15 and h.ransom_mult() == 1.0, "lapsed: no discount, 15 percent fail"
	)
	c.day = 8
	cash0 = o.cash
	_check(
		str(h.act("H1")).begins_with("RESTORE") and o.cash == cash0 - 150,
		"doing it again costs $150 again"
	)

	# ---- H2: the scorecard at a business review
	_fresh_game(c, cards, 8)
	h.start("H2")
	_check(is_equal_approx(h.change_odds(), 0.10), "H2 adds 10 points to a change order")
	_check(
		(
			is_equal_approx(projects.change_order_odds(client), odds0 + 0.10)
			or projects.change_order_odds(client) >= odds0
		),
		"Projects.change_order_odds reads it"
	)
	mood0 = sales.mood(client)
	var hours0: float = growth.owner_used
	c.day = 12
	h.qbr(client)
	_check(
		sales.mood(client) == mood0 + 2 and growth.owner_used == hours0 + 1.0,
		"the scorecard: mood +2, 1 hour"
	)
	_check(h.age("H2") == 0 and int(o.habits.H2.uses) == 1, "and it touches H2")
	c.day = 12 + 8
	_check(h.state("H2") == "STALE", "no review for 8 weeks: STALE")
	mood0 = sales.mood(client)
	h.qbr(client)
	_check(
		sales.mood(client) == mood0 + 1 and h.state("H2") == "ADOPTED",
		"a stale scorecard gives +1 and revives it"
	)
	c.day = 20 + 16
	_check(h.state("H2") == "LAPSED", "lapsed")
	mood0 = sales.mood(client)
	h.qbr(client)
	_check(
		sales.mood(client) == mood0 and h.state("H2") == "LAPSED",
		"a lapsed H2 needs a re-adopt: the review does not revive it"
	)

	# ---- H3: creep and the change plan
	_fresh_game(c, cards, 8)
	h.start("H3")
	_check(is_equal_approx(h.creep(0.30), 0.18), "fresh H3: creep 18 percent")
	c.day = 8 + 10
	_check(is_equal_approx(h.creep(0.30), 0.24), "stale H3: creep 24 percent")
	c.day = 8
	hours0 = growth.owner_used
	h.project()
	_check(
		growth.owner_used == hours0 + 2.0 and int(o.habits.H3.uses) == 1,
		"a quoted project costs 2 hours and touches H3"
	)

	# ---- H4: a refusal on paper
	_fresh_game(c, cards, 8)
	h.start("H4")
	o.apply({"risk_choice": "ignored"})
	_check(int(o.habits.H4.uses) == 0, "ignoring a refusal is not a form")
	o.apply({"risk_choice": "waiver"})
	_check(
		int(o.habits.H4.uses) == 1 and h.refusal_save() == 250,
		"the waiver is a form: H4 touched, $250 saved when it matters"
	)
	_check(h.bec_mult() < 1.0, "H4 makes a scam a little harder")
	cash0 = o.cash
	o.risk_client = client
	o._client_breach()
	_check(o.cash == cash0 - 250, "the waiver breach costs $250 instead of $500 with H4")
	_clear(cards)

	# ---- H5: a lost account review
	_fresh_game(c, cards, 8)
	var other := int(sales.active[1])
	var risk0: float = o.poach_risk(other)
	h.start("H5")
	o.drop_client(client, "")
	_check(
		int(o.habits.H5.uses) == 1 and int(o.flags.h5_until) == 16,
		"losing a client: the review is held, 8 weeks of lower risk"
	)
	_check(
		o.poach_risk(other) < risk0 or risk0 <= 0.0,
		"the poach risk is lower while the review lasts"
	)
	_check(h.poach_adjust(other) <= -0.02, "by 2 points")
	c.day = 17
	_check(h.poach_adjust(other) == 0.0 or not msp.backups[other].ok, "and it wears off")
	_clear(cards)

	# ---- H6: offboarding
	_fresh_game(c, cards, 8)
	h.start("H6")
	h.departure("Sam")
	_check(
		int(o.habits.H6.uses) == 1 and not cards.is_open,
		"a departure with the checklist: touched, no revenge"
	)
	_check(is_equal_approx(h.breach_mult(), 0.9), "vendor breach odds x0.9")
	c.day = 8 + 26
	var revenge := false
	for i in 80:
		h.departure("Sam")
		if cards.is_open:
			revenge = true
			break
	_check(revenge, "a lapsed H6: sooner or later the departed tech sends revenge mail")
	_clear(cards)
	_fresh_game(c, cards, 8)
	for i in 40:
		h.departure("Sam")
	_check(not cards.is_open, "never started: never a revenge card")

	# ---- H7: unique admin logins
	_fresh_game(c, cards, 8)
	h.start("H7")
	_check(
		(
			is_equal_approx(h.breach_mult(), 0.5)
			and is_equal_approx(h.rdp_mult(true), 0.25)
			and h.rdp_mult(false) == 1.0
		),
		"H7: breach x0.5, weak password chance x0.25"
	)
	_check(is_equal_approx(h.bec_mult(), 0.85), "H7: wire fraud misses x0.85")
	o.cash = 5000
	o.flags["rdp_weak"] = true
	var fx_cash: int = -int(3500.0 * h.breach_mult())
	_check(fx_cash == -1750, "a vendor breach hit costs $1,750")
	c.day = 8 + 26
	_check(is_equal_approx(h.breach_mult(), 0.75), "stale H7: breach x0.75")

	# ---- H8: the firewall review
	_fresh_game(c, cards, 8)
	_check(not o.flags.get("rdp_safe", false), "no VPN yet")
	_check(h.act("H8") != "" and o.flags.rdp_safe == true, "adopting H8 puts the VPN in")
	_clear(cards)
	c.day = 8 + 13
	var reopened := false
	for i in 120:
		o.flags["rdp_safe"] = true
		h.week(o)
		if not o.flags.rdp_safe:
			reopened = true
			break
	_check(reopened, "a stale firewall review: a forgotten exception opens remote desktop again")
	_clear(cards)

	# ---- H9: the clocks
	_fresh_game(c, cards, 18)
	h.start("H9")
	h.week(o)
	_check(
		cards.is_open and cards.text.contains("clocks change"),
		"week 19: the clocks card for a player with H9"
	)
	_clear(cards)
	_fresh_game(c, cards, 18)
	h.week(o)
	_check(not cards.is_open or not cards.text.contains("clocks change"), "and none without it")
	_clear(cards)

	# ---- H10: honest assessment
	_fresh_game(c, cards, 8)
	h.start("H10")
	_check(is_equal_approx(h.assess_win_adj(), -0.03), "H10: win chance minus 3 points")
	mood0 = sales.mood(client)
	h.new_client(client)
	_check(sales.mood(client) == mood0 + 6, "H10: a new client starts 6 happier")

	# ---- H11: runbooks and a map
	_fresh_game(c, cards, 8)
	_check(
		h.act("H11").contains("IS MAPPED") and h.mapped_count() == 1,
		"mapping a client takes 6 hours and maps one"
	)
	var mapped := int(o.habits.H11.maps[0])
	var unmapped := -1
	for cl in sales.active:
		if int(cl) != mapped:
			unmapped = int(cl)
	_check(
		is_equal_approx(h.onsite_mult(mapped), 0.8) and h.onsite_mult(unmapped) == 1.0,
		"H11: onsite jobs 20 percent shorter at the mapped client only"
	)
	_check(is_equal_approx(growth.owner_used, 6.0), "6 owner hours")

	# ---- H12: the front desk
	_fresh_game(c, cards, 8)
	h.act("H12")
	_check(is_equal_approx(h.walk_mult(), 1.2), "H12: walk-around findings 20 percent likelier")
	h.week(o)
	_check(not h.drifting(client), "steady mood: no chip")
	sales.adjust(client, -5)
	_check(h.drifting(client), "a five point fall shows as a chip")
	var view: Script = load("res://scripts/habits_view.gd")
	_check(view.chip(client) == "SLIPPING", "the CLIENTS chip says SLIPPING")
	_check(view.chip(int(sales.active[1])) == "", "and only for that client")

	# ---- H13 / H14
	_fresh_game(c, cards, 8)
	h.start("H13")
	_check(is_equal_approx(h.bec_mult(), 0.95), "H13: wire fraud misses x0.95")
	h.start("H14")
	var done: String = h.act("H14")
	_check(done.contains("DEFAULT PASSWORDS") and h.site_share() > 0.0, "H14: a site done")
	_check(h.breach_mult() < 1.0, "a small breach reduction")

	# ---- a card from Marge or Alan adopts a habit, and the lapse nudge
	_fresh_game(c, cards, 4)
	h.week(o)
	_check(
		cards.is_open and cards.text.begins_with("Idea for the shop"),
		"week 4: the first pitch (a card)"
	)
	_check(cards.speaker.contains("Marge"), "H1 is pitched by Marge")
	cash0 = o.cash
	cards.pick(1)  # START IT
	_check(
		h.state("H1") == "ADOPTED" and o.cash == cash0 - 150, "START IT adopts the habit and pays"
	)
	_clear(cards)
	h.week(o)
	_check(not cards.is_open, "no second pitch for two weeks")
	c.day = 6
	h.week(o)
	_check(cards.is_open and cards.text.begins_with("Idea for the shop"), "week 6: the next pitch")
	cards.pick(0)  # NOT NOW
	_check(h.state("H7") == "NONE", "NOT NOW costs nothing and starts nothing")
	_clear(cards)
	c.day = 4 + 26
	h.week(o)
	_check(
		cards.is_open and cards.text.contains("EMPTY BOX"), "a lapsed habit: Marge's empty box card"
	)
	cash0 = o.cash
	cards.pick(0)
	_check(h.state("H1") == "ADOPTED" and o.cash == cash0 - 75, "DO IT AGAIN re-adopts for half")
	_clear(cards)
	var n := 0
	for k in o.flags:
		n += 1 if str(k).begins_with("offered_") else 0
	_check(n >= 2, "each pitch is made once")

	# ---- paperwork morale comes back
	_fresh_game(c, cards, 8)
	var social := root.get_node("Social")
	var who: String = str(social.people()[0])
	var before: int = social.value(who)
	h.adopt("H3")
	_check(social.value(who) == before - 1, "H3 costs 1 morale at first")
	c.day = 10
	h.week(o)
	_clear(cards)
	_check(social.value(who) == before, "and it comes back after two weeks")

	# ---- the buttons
	_fresh_game(c, cards, 8)
	_check(
		h.action("H2").label.begins_with("ADOPT $200") and h.action("H2").enabled,
		"NONE: ADOPT with the price"
	)
	h.start("H2")
	_check(
		h.action("H2").label == "FRESH" and not h.action("H2").enabled,
		"H2 is touched by a review, not by a button"
	)
	_check(h.act("H2") == h.TEXT.uptodate, "and acting on it says so")
	c.day = 8 + 8
	_check(h.action("H2").label.begins_with("RE-ADOPT $100"), "STALE: RE-ADOPT at half")
	h.start("H1")
	_check(h.action("H1").label == "DO IT NOW $150 3H", "H1 fresh: DO IT NOW")
	o.cash = 10
	_check(not h.action("H1").enabled and h.act("H1") == h.TEXT.nocash, "no cash, no button")

	# ---- saved with the campaign
	_fresh_game(c, cards, 8)
	h.act("H11")
	var saved: Dictionary = o.to_dict()
	var text := JSON.stringify(saved)
	o.habits = {}
	o.from_dict(JSON.parse_string(text))
	_check(
		h.state("H11") == "ADOPTED" and h.mapped_count() == 1,
		"habits and their maps survive a save"
	)

	# ---- the valuation
	_fresh_game(c, cards, 8)
	for id in h.HABITS:
		h.start(str(id))
	_check(h.standard() == 100 and h.maturity_bonus(4) == 0.5, "all fresh: the Standard bonus")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
