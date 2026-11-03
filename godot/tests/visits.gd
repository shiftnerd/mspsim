extends SceneTree
# Owner visits: a review and a pitch at the client office, and the walk-around findings.
# that finds problems you can log as tickets.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _scene() -> String:
	var sc := current_scene
	return "" if sc == null else sc.scene_file_path.get_file().get_basename()


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 10:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var on := root.get_node("Onsite")
	var cards := root.get_node("Cards")
	var game := root.get_node("Game")
	var sales := root.get_node("Sales")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	c.save_prefix = "user://test_"
	game.title_mode = false
	c.new_game("owner")
	_drain(cards)
	await _wait(1.0)
	world.clock = 9.0

	# the quarterly review offers to go to their office
	o._qbr_done = {}
	o._qbr()
	_check(
		cards.is_open and cards.options.size() == 4 and "GO ONSITE" in str(cards.options[3].label),
		"the review offers to go to the client's office"
	)
	_drain(cards)
	var mood0: int = sales.mood(0)
	on.start_visit(0, "qbr")
	await _wait(1.5)
	_check(
		on.active and on.visit_kind == "qbr" and _scene() == "site_dental_a",
		"you drive to Acme's office"
	)
	# walk around: look at the things in the closet and the front desk PC
	var tickets0: int = msp.tickets.size()
	on._inspected = {}
	on._found(on.FINDINGS["server"][0])
	_check(
		(
			cards.is_open
			and cards.options.size() == 3
			and "SELL IT AS A PROJECT" in str(cards.options[1].label)
		),
		"a finding can be a ticket, a project or a note"
	)
	cards.pick(0)
	_check(msp.tickets.size() == tickets0 + 1, "logging it creates a ticket for the team")
	on._logged_day = {}
	var q0: int = o.get_node_or_null("/root/Projects")._queue.size()
	on._found(on.FINDINGS["pc"][0])
	cards.pick(1)
	_check(root.get_node("Projects")._queue.size() == q0 + 1, "selling it queues a project quote")
	on._found(on.FINDINGS["cabinet"][0])
	cards.pick(2)
	_check(on._missed.size() == 1, "a note for later can come back as a problem")
	# the meeting in the owner's office
	game.go("site_dental_office_a", "from_office")
	await _wait(1.0)
	on.interact("owner")
	_check(
		(
			cards.is_open
			and cards.options.size() == 3
			and cards.options[0].label == "WALK THROUGH THE NUMBERS"
		),
		"the owner holds the review"
	)
	cards.pick(0)
	_drain(cards)
	_check(sales.mood(0) > mood0 and on._met, "the review raises their mood")
	on.interact("door")
	await _wait(1.2)
	_check(not on.active and on.visit_kind == "", "you drive back")

	# a prospect pitch at their own (b skin) office
	_drain(cards)
	world.clock = 9.0
	var clients0: int = sales.active.size()
	on.start_visit(8, "pitch")
	await _wait(1.5)
	_check(
		_scene() == "site_vet_b" and on.visit_prospect,
		"a prospect is pitched at their own office (the competitor skin)"
	)
	game.go("site_vet_office_b", "from_office")
	await _wait(1.0)
	var signed := false
	for i in 40:
		on._met = false
		sales.active = sales.active.filter(func(x: int) -> bool: return x != 8)
		on.interact("owner")
		cards.pick(0)  # show a sample report
		_drain(cards)
		if sales.active.has(8):
			signed = true
			break
	_check(
		signed and sales.active.size() >= clients0,
		"a pitch can win the client (Paws and Claws signs)"
	)
	on.interact("door")
	await _wait(1.2)

	# the inbound lead card offers a pitch for a prospect that has a site
	_drain(cards)
	sales.active = [0, 1, 2, 3, 4]
	o._inbound_lead()
	_check(
		(
			cards.is_open
			and cards.options.size() == 3
			and "PITCH THEM AT THEIR OFFICE" in str(cards.options[2].label)
		),
		"an inbound lead can be pitched in person"
	)
	_drain(cards)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
