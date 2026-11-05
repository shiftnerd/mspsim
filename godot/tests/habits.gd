extends SceneTree
# R38 P0: the good habits (Habits): adopt, freshness (STALE at `every`, LAPSED at twice that), re-adopt at half price, the Standard
# and its bands, and that every query is neutral while no habit is adopted (so the existing balance does not move).

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


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var growth := root.get_node("Growth")
	var h: Script = load("res://scripts/habits.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("owner")
	_clear(cards)
	c.day = 4

	_check(h.HABITS.size() == 14, "14 habits H1-H14")
	var weights := 0
	for id in h.HABITS:
		weights += int(h.HABITS[id].weight)
	_check(weights == 100, "the weights add up to 100: %d" % weights)

	# ---- neutral while nothing is adopted
	_check(not h.any() and h.standard() == 0 and h.band() == "BARE", "no habits: Standard 0, BARE")
	_check(h.state("H1") == "NONE" and not h.fresh("H1") and h.factor("H1") == 0.0, "H1 is NONE")
	_check(
		(
			h.bec_mult() == 1.0
			and h.rdp_mult(true) == 1.0
			and h.ransom_mult() == 1.0
			and h.breach_mult() == 1.0
		),
		"every multiplier is 1.0"
	)
	_check(
		not h.gap_restore() and h.poach_adjust(0) == 0.0 and h.restore_fail() == 0.0,
		"no gap, no risk change, no restore failure"
	)
	_check(
		h.practice_count() == 0 and h.maturity_bonus(4) == 0.25 and h.maturity_bonus(3) == 0.0,
		"the maturity bonus is the old +0.25 at oml 4"
	)
	var practices0: int = o.practices()

	# ---- adopt costs and pays
	var cash0: int = o.cash
	var hours0: float = growth.owner_used
	_check(
		h.adopt("H1") and o.cash == cash0 - 150 and growth.owner_used == hours0 + 3.0,
		"adopting H1 costs $150 and 3 hours"
	)
	_check(h.state("H1") == "ADOPTED" and h.fresh("H1") and h.factor("H1") == 1.0, "H1 is ADOPTED")
	_check(h.age("H1") == 0 and int(o.habits.H1.uses) == 0, "age 0, no uses yet")
	_check(h.cost("H1").cash == 0, "a fresh habit costs nothing more")
	_check(h.ransom_mult() == 0.5 and h.breach_mult() == 1.0, "a fresh H1 halves the ransom bill")
	_check(o.practices() == practices0 + 1, "a habit counts as a practice")
	_check(not h.adopt("H99"), "an unknown habit cannot be adopted")
	o.cash = 10
	_check(not h.adopt("H7"), "adopting without the cash fails")
	o.cash = cash0

	# ---- freshness: STALE at every (13), LAPSED at 2 x every
	c.day = 4 + 12
	_check(h.state("H1") == "ADOPTED", "week 12 after: still ADOPTED")
	c.day = 4 + 13
	_check(
		h.state("H1") == "STALE" and h.factor("H1") == 0.5 and not h.fresh("H1"),
		"13 weeks later: STALE, half the effect"
	)
	_check(h.gap_restore(), "a stale restore test shows up as a gap in poach_gaps")
	_check(h.practice_count() == 1, "STALE still counts as a practice")
	c.day = 4 + 25
	_check(h.state("H1") == "STALE", "25 weeks: STALE")
	c.day = 4 + 26
	_check(
		h.state("H1") == "LAPSED" and h.factor("H1") == 0.0 and h.practice_count() == 0,
		"26 weeks: LAPSED, no effect, no practice"
	)
	h.week(o)
	_check(o.flags.has("lapsed_H1"), "the lapse is noted once")

	# ---- re-adopt at half price; touch is free and resets
	cash0 = o.cash
	_check(int(h.cost("H1").cash) == 75, "re-adopting costs half")
	_check(
		h.adopt("H1") and o.cash == cash0 - 75 and h.state("H1") == "ADOPTED", "re-adopted for $75"
	)
	h.week(o)
	_check(not o.flags.has("lapsed_H1"), "the lapse note clears when it is fresh again")
	c.day += 14
	_check(h.state("H1") == "STALE" and int(h.cost("H1").cash) == 75, "stale again, half price")
	_check(
		h.touch("H1") and h.state("H1") == "ADOPTED" and int(o.habits.H1.uses) == 1,
		"doing the real thing resets it for free"
	)
	_check(not h.touch("H2"), "touching a habit you never started does nothing")
	h.apply_touch("H2")
	_check(h.state("H2") == "ADOPTED", "fx habit starts a habit that was never started")

	# ---- a habit that never lapses by time (H10)
	h.start("H10")
	c.day += 200
	_check(h.state("H10") == "ADOPTED", "H10 never lapses by time")

	# ---- the Standard and its bands
	c.new_game("owner")
	_clear(cards)
	c.day = 4
	_check(h.standard() == 0 and h.band() == "BARE", "reset: BARE")
	for id in ["H1", "H2", "H3"]:
		h.start(id)
	_check(h.standard() == 28 and h.band() == "BARE", "H1-H3 fresh: 28, BARE (%d)" % h.standard())
	h.start("H7")
	h.start("H10")
	_check(h.standard() == 46 and h.band() == "PATCHY", "46: PATCHY (%d)" % h.standard())
	for id in ["H4", "H5", "H6"]:
		h.start(id)
	_check(h.standard() == 66 and h.band() == "SOLID", "66: SOLID (%d)" % h.standard())
	for id in ["H8", "H11", "H12"]:
		h.start(id)
	_check(h.standard() == 89 and h.band() == "SHOWCASE", "89: SHOWCASE (%d)" % h.standard())
	_check(h.practice_count() == 3, "the practice count is capped at 3")
	_check(
		(
			h.band(34) == "BARE"
			and h.band(35) == "PATCHY"
			and h.band(59) == "PATCHY"
			and h.band(60) == "SOLID"
			and h.band(79) == "SOLID"
			and h.band(80) == "SHOWCASE"
		),
		"band edges 35 / 60 / 80"
	)
	c.day += 20
	_check(h.standard() < 89, "stale habits count half and the score falls")
	_check(
		h.standard() > 0 and h.standard_text().contains("("),
		"standard_text gives the score and the band"
	)

	# ---- the valuation bonus replaces the old one and never stacks
	c.new_game("owner")
	_clear(cards)
	c.day = 20
	for id in h.HABITS:
		h.start(str(id))
	_check(
		h.standard() == 100 and h.maturity_bonus(4) == 0.5 and h.maturity_bonus(3) == 0.0,
		"Standard 70+ and oml 4+: the bonus is 0.5, not 0.25 + 0.5"
	)
	_check(h.maturity_bonus(5) == 0.5, "oml 5 as well")

	# ---- the hooks in poach and the incident
	c.new_game("owner")
	_clear(cards)
	c.day = 6
	var client := int(root.get_node("Sales").active[0])
	var base_gaps: Array = o.poach_gaps(client)
	var base_risk: float = o.poach_risk(client)
	h.start("H1")
	_check(o.poach_gaps(client) == base_gaps, "a fresh H1 adds no gap")
	c.day = 6 + 13
	_check(o.poach_gaps(client).has("no restore proof"), "a stale H1 adds the third gap")
	c.day = 6
	root.get_node("Msp").backups[client].ok = false
	var failing: float = o.poach_risk(client)
	o.habits = {}
	var failing_without: float = o.poach_risk(client)
	_check(
		failing < failing_without,
		"a fresh H1 lowers the failing-backup risk (%.3f < %.3f)" % [failing, failing_without]
	)
	_check(base_risk >= 0.0, "base risk is sane")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
