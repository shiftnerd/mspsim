extends SceneTree
# gdlint:disable=max-line-length
# R38: the skipped restore test (temp_restore) is a real ransom. While the entry is in Christy's folder Habits.restore_fail() is 1.0, the
# bill is an infection at one client whose restore fails (the ransom card, not a flat $800), a ransom that comes while it is open fails
# too, a real restore test (H1) afterwards clears it, and cozy keeps the flat halved bill.

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


func _pick_label(cards: Node, part: String) -> bool:
	for i in cards.options.size():
		if str(cards.options[i].label).contains(part):
			cards.pick(i)
			return true
	return false


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var story := root.get_node("Story")
	var d := root.get_node("Difficulty")
	var t: Script = load("res://scripts/temptation.gd")
	var h: Script = load("res://scripts/habits.gd")
	var rival: Script = load("res://scripts/rival.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	d.settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	var rc: int = story.RANSOM_CLIENT

	# ---- the link: the entry in the folder is what makes a restore fail
	_fresh(c, cards, 12)
	_check(h.restore_fail() == 0.0 and not h.skipped_test(), "no skipped test: a restore does not fail")
	t.add_skeleton("temp_restore", 2)
	_check(h.skipped_test() and h.restore_fail() == h.SKIP_FAIL and h.SKIP_FAIL == 1.0, "the skipped test in the folder: restore_fail is 1.0")

	# ---- the bill is a real ransom at the backup client
	msp.backups[rc].ok = true
	var cash0: int = o.cash
	var mood0: int = sales.satisfaction[rc]
	c.day = 13
	t.week(o)
	_check(not cards.is_open and t.folder_count() == 1, "nothing in week 13")
	c.day = 14
	t.week(o)
	_check(cards.is_open and str(cards.text).contains("encrypted") and str(cards.text).contains("restore failed halfway"), "week 14: the ransom card, and the restore failed: %s" % str(cards.text).substr(0, 60))
	_check(cards.options.size() == 6, "the six ransom options")
	_check(t.folder_count() == 0 and o.cash == cash0, "the entry left the folder and no flat bill was charged")
	_check(int(sales.satisfaction[rc]) == mood0 - int(t.BILLS.temp_restore.mood), "the client is hurt")
	var open_ransom := 0
	for tk in msp.tickets:
		if tk.fix == "restore" and tk.status != "Closed":
			open_ransom += 1
	_check(open_ransom == 1, "a real ransomware ticket is open")
	_check(_pick_label(cards, "REBUILD"), "isolate and rebuild")
	_clear(cards)
	_check(o.cash == cash0 - 1000, "the rebuild costs $1,000 (cash %d -> %d)" % [cash0, o.cash])
	_check((o.flags.get("arc_queue", []) as Array).has(t.LESSON_CARD), "Alan's lesson card is queued for the morning")
	_check(h.restore_fail() == 0.0, "and the next restore is not doomed any more")
	rival.morning(o)
	_check(cards.is_open and str(cards.text).contains(str(msp.CLIENTS[rc].name)) and not str(cards.text).contains("{vname}"), "the lesson card names the client")
	_check(_pick_label(cards, "RESTORE TEST"), "run a restore test on every client")
	_clear(cards)
	_check(h.fresh("H1"), "which starts the restore habit")

	# ---- giving up: the loss is recorded although the backup light was green
	_fresh(c, cards, 12)
	msp.backups[rc].ok = true
	t.add_skeleton("temp_restore", 1)
	var rep0: int = c.rep
	c.day = 13
	t.week(o)
	_check(cards.is_open and _pick_label(cards, "ACCEPT THE LOSS"), "accept the loss")
	_check(cards.is_open and str(cards.text).contains("would not restore"), "the lawsuit card says why: %s" % str(cards.text).substr(0, 70))
	_clear(cards)
	_check(c.rep < rep0, "reputation falls (%d -> %d)" % [rep0, c.rep])

	# ---- another client when the law firm is gone: the card names them
	_fresh(c, cards, 12)
	sales.active.erase(rc)
	t.add_skeleton("temp_restore", 1)
	c.day = 13
	t.week(o)
	var named := -1
	for cl in sales.active:
		if str(cards.text).contains(str(msp.CLIENTS[int(cl)].name)):
			named = int(cl)
	_check(cards.is_open and named >= 0 and not str(cards.text).contains("Hoot and Holler"), "the card names the client that was hit (%d)" % named)
	var m0 := int(sales.mood(named)) if named >= 0 else 0
	var rc0 := int(sales.mood(rc))
	_check(_pick_label(cards, "REBUILD"), "rebuild there")
	_clear(cards)
	_check(named >= 0 and int(sales.mood(named)) < m0 and int(sales.mood(rc)) == rc0, "the mood hit of the rebuild lands on that client (%d -> %d)" % [m0, int(sales.mood(named)) if named >= 0 else 0])

	# ---- the scheduled ransom while the entry is open: the restore fails, the entry is the bill
	_fresh(c, cards, 8)
	msp.backups[rc].ok = true
	t.add_skeleton("temp_restore", 6)
	o._ransom()
	_check(cards.is_open and str(cards.text).contains("restore failed halfway") and t.folder_count() == 0, "a ransom with the skipped test open fails to restore")
	_clear(cards)

	# ---- no skipped test, a working backup: the save, as before
	_fresh(c, cards, 8)
	msp.backups[rc].ok = true
	o._ransom()
	_check(cards.is_open and str(cards.text).contains("nothing was lost"), "without the skip the backup restores")
	_clear(cards)

	# ---- a real test afterwards finds it while it is cheap
	_fresh(c, cards, 12)
	t.add_skeleton("temp_restore", 4)
	h.start("H1")
	_check(h.restore_fail() == 1.0, "starting the habit on paper is not a test")
	h.touch("H1")
	_check(not h.skipped_test() and t.folder_count() == 0 and h.restore_fail() == 0.0, "a restore test clears the skipped one")

	# ---- cozy: the flat, halved bill
	d.set_tier("easy")
	_fresh(c, cards, 12)
	if d.cozy_on():
		t.add_skeleton("temp_restore", 1)
		var cz0: int = o.cash
		c.day = 13
		t.week(o)
		_check(o.cash == cz0 - int(t.BILLS.temp_restore.size) / 2, "cozy: a flat bill of half the size (%d)" % (cz0 - o.cash))
		_check(not str(cards.text).contains("encrypted"), "and no ransom")
		_clear(cards)
	else:
		_check(false, "the easy tier is cozy")
	d.set_tier("normal")

	# ---- H13: written authorisation halves the blame of the wire fraud answer
	_fresh(c, cards, 12)
	_check(h.blame_mult() == 1.0, "no written go-ahead: the full blame")
	h.start("H13")
	_check(h.blame_mult() == 0.5, "with it on file: half")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
