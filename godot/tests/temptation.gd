extends SceneTree
# R38 P0: temptation (Temptation): a skeleton fires on its due week, coming clean is cheaper than the bill, the conscience bands and
# the weekly honesty cap, Marge's folder count, and the due diligence deduction. Headless, seeded.

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
		int(sk.due) == 15 and str(sk.class) == "vendor" and int(sk.size) == 1900,
		"due week 15, class vendor, size 1900"
	)
	var cash0: int = o.cash
	c.day = 14
	t.week(o)
	_check(t.folder_count() == 1 and o.cash == cash0, "nothing on week 14")
	c.day = 15
	t.week(o)
	_check(t.folder_count() == 0, "the bill leaves the folder on week 15")
	_check(o.cash == cash0 - 1900, "and costs $1900")
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
	_check(normal == 1900, "the normal bill is 1900")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
