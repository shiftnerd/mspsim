extends SceneTree
# Onsite visits: a ticket the RMM cannot fix, the drive, the site, the work, leaving.
# gdlint:disable=max-line-length

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
		cards.pick(0)
		guard += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var on := root.get_node("Onsite")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var game := root.get_node("Game")
	var sales := root.get_node("Sales")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	c.day = 6
	await _wait(1.0)

	# a ticket that needs hands
	var other: Dictionary = msp.create_ticket(0, 0, "email")
	var t: Dictionary = on.create_job(0, "switch")
	_check(not t.is_empty() and on.is_onsite(t), "an onsite ticket is created")
	_check(t.pri == 1 and str(t.fix) == "onsite_switch", "it is a P1 network outage")
	var ep: Dictionary = msp.endpoint(str(t.endpoint))
	msp.rmm_action(str(t.endpoint), "reboot")
	_check(str(ep.problem) == "onsite_switch" and not t.fix_done, "the RMM cannot fix it")
	_check(
		(
			on.site_scene(0) == "site_dental_a"
			and on.site_scene(8) == "site_vet_a"
			and on.site_scene(0, true) == "site_dental_b"
		),
		"clients map to a site and a prospect skin"
	)

	# go there
	var clock0: float = world.clock
	var sla0: float = other.sla_left
	on.offer(int(t.id))
	_check(cards.is_open and cards.options.size() == 2, "dispatch asks if you want to drive out")
	cards.pick(0)
	await _wait(1.2)
	_check(_scene() == "site_dental_a" and on.active and on.busy, "you arrive at the dental office")
	_check(
		world.clock > clock0 and other.sla_left < sla0,
		"the drive takes time and the other tickets age"
	)
	_check(not msp.enabled, "no new tickets arrive while you are away")
	var staff := 0
	for n in get_nodes_in_group("npcs"):
		staff += 1 if str(n.role) == "site:staff" else 0
	_check(staff == 2, "the receptionist and the hygienist are in the office")

	# the client's computer is not your desktop
	on.interact("pc")
	var comp := root.get_node("Computer")
	_check(comp.is_open and comp.app == "site", "a client PC opens their desktop, not yours")
	_check(
		(
			str(comp.site_info.name) == "ACME DENTAL GROUP"
			and str(comp.site_info.pc).begins_with("ACME-")
		),
		"it is Acme's computer (%s)" % str(comp.site_info.pc)
	)
	_check(
		comp.site_info.mails.size() >= 2 and str(comp.site_info.mails[0][1]).begins_with("HELP"),
		"their mail shows the problem"
	)
	comp.close()

	# the network cabinet is in the closet
	game.go("site_dental_closet_a", "from_office")
	await _wait(1.0)
	on.interact("cabinet")
	_check(
		cards.is_open and cards.options.size() == 3,
		"the closet cabinet offers three ways to fix the switch"
	)
	cards.pick(0)  # swap in a new switch
	_check(on.done, "swapping the switch fixes it")
	_drain(cards)
	_check(str(t.status) == "Closed", "the ticket is closed from the site")

	# leave
	on.interact("door")
	await _wait(1.2)
	_check(
		not on.active and not on.busy and msp.enabled and _scene() == "main_floor",
		"you drive back and the office is running again"
	)

	# leaving early costs you
	_drain(cards)
	var t2: Dictionary = on.create_job(3, "printer")
	var mood0: int = sales.mood(3)
	on.offer(int(t2.id))
	cards.pick(0)
	await _wait(1.2)
	on.interact("door")
	_check(
		cards.is_open and cards.options[1].label == "LEAVE ANYWAY",
		"leaving with the ticket open asks first"
	)
	cards.pick(1)
	await _wait(1.2)
	_check(
		sales.mood(3) < mood0 and str(t2.status) != "Closed",
		"walking out of a job upsets the client"
	)

	# an exam room PC problem, fixed through the PC's TOOLS window
	_drain(cards)
	var t3: Dictionary = on.create_job(0, "exam")
	on.offer(int(t3.id))
	cards.pick(0)
	await _wait(1.2)
	game.vars["exam_return"] = "from_exam1"
	game.go("site_dental_exam_a", "from_office")
	await _wait(1.0)
	on.interact("exam")
	_check(comp.is_open and comp.site_info.pc == "ACME-EXAM1", "the exam room PC has its own name")
	comp.activate("site:tools")
	comp.activate("site:diag")
	_check(cards.is_open and cards.options.size() == 3, "DIAGNOSE AND FIX opens the job")
	var tries := 0
	while not on.done and tries < 6:
		if not cards.is_open:
			on.interact("exam")
			comp.activate("site:tools")
			comp.activate("site:diag")
		cards.pick(1)
		_drain(cards)
		tries += 1
	_check(
		on.done and str(t3.status) == "Closed", "the exam room PC is fixed and the ticket closed"
	)
	on.interact("door")
	await _wait(1.2)

	# the front door: where to? the ticket you are working comes first
	world.clock = 9.0
	_drain(cards)
	game.go("main_floor", "start")
	await _wait(1.0)
	var t4: Dictionary = on.create_job(3, "switch")
	root.get_node("Computer").psa_sel = int(t4.id)
	var door := current_scene.get_node("Interactables/DoorFrontDoor")
	door.use(null)
	_check(
		(
			cards.is_open
			and "HOOT" in str(cards.options[0].label)
			and "TICKET" in str(cards.options[0].label)
		),
		"the front door offers the ticket's client first: %s" % str(cards.options[0].label)
	)
	_check(cards.options[cards.options.size() - 1].id == "leave", "and you can stay")
	cards.pick(0)  # the ticket's client
	_check(cards.is_open and cards.options[0].id == "go", "it asks to drive there")
	cards.pick(0)
	await _wait(1.2)
	_check(
		_scene() == "site_law_a" and on.active and on.ticket_id == int(t4.id),
		"the front door takes you to the law office with the ticket"
	)
	on.interact("door")
	cards.pick(1)  # leave anyway
	await _wait(1.2)
	# visiting a client with no ticket
	world.clock = 9.0
	_drain(cards)
	door = current_scene.get_node("Interactables/DoorFrontDoor")
	t4.status = "Closed"
	door.use(null)
	cards.pick(2)  # more sites (page 1 has two sites)
	_check(cards.is_open and cards.options.size() >= 2, "more sites are on another page")
	cards.pick(0)
	_check(
		cards.is_open and cards.options[0].id == "go", "a visit without a ticket just asks to drive"
	)
	cards.pick(0)
	await _wait(1.2)
	_check(
		on.active and on.job.is_empty() and _scene().begins_with("site_"),
		"you can visit a client with nothing to fix"
	)
	on.interact("door")
	await _wait(1.2)

	world.clock = 9.0
	game.ui_open = false
	# drive times differ by client and by the time of day
	world.clock = 14.0
	_check(
		(
			on.drive_minutes(0) == 20
			and on.drive_minutes(10) == 70
			and on.drive_minutes(3) != on.drive_minutes(8)
		),
		"each site has its own drive time"
	)
	_check(
		(
			on.traffic_factor(8.5) > on.traffic_factor(12.0)
			and on.traffic_factor(12.0) > on.traffic_factor(14.0)
			and on.traffic_factor(17.0) > on.traffic_factor(8.5)
		),
		"rush hour, lunch and the evening rush are slower than a quiet afternoon"
	)
	_check(
		(
			on.traffic_label(8.5) == "RUSH HOUR"
			and on.traffic_label(12.0) == "LUNCH TRAFFIC"
			and on.traffic_label(14.0) == "CLEAR ROADS"
			and on.traffic_label(17.0) == "EVENING RUSH HOUR"
		),
		"and the labels say so"
	)
	var lo := 999
	var hi := 0
	for i in 60:
		var m: int = on._trip_minutes(10)
		lo = mini(lo, m)
		hi = maxi(hi, m)
	_check(
		lo >= 60 and hi <= 85 and lo != hi,
		"traffic varies a little (%d to %d minutes for a 70 minute drive at 2 pm)" % [lo, hi]
	)
	world.clock = 17.0
	var evening := 0
	for i in 30:
		evening += on._trip_minutes(10)
	_check(
		float(evening) / 30.0 > 90.0,
		(
			"the same drive at 5 pm takes much longer (%d minutes on average)"
			% int(float(evening) / 30.0)
		)
	)
	_check(on._trip_minutes(0) % 5 == 0 and on._trip_minutes(0) >= 10, "in whole five minute steps")
	world.clock = 9.0

	# the vet has people and animals: you can always pet them
	_drain(cards)
	game.go("site_vet_a", "start")
	await _wait(1.0)
	var crew := []
	for n in get_nodes_in_group("npcs"):
		if str(n.role) == "site:staff":
			crew.append(str(n.character))
	_check(
		crew.size() == 2 and crew.any(func(c: String) -> bool: return c.begins_with("client_vet")),
		"the vet office has a receptionist and a tech: %s" % str(crew)
	)
	var pets_before: int = on.pets
	await _wait(0.8)
	on.interact("dog")
	_check(on.pets == pets_before + 1 and root.get_node("Hints").toast_text != "", "you can pet the dog")
	on.interact("cat")
	_check(on.pets == pets_before + 2, "and the cat")
	game.go("site_dental_b", "start")
	await _wait(1.0)
	var crew_b := []
	for n in get_nodes_in_group("npcs"):
		if str(n.role) == "site:staff":
			crew_b.append(str(n.character))
	game.go("site_dental_a", "start")
	await _wait(1.0)
	var crew_a := []
	for n in get_nodes_in_group("npcs"):
		if str(n.role) == "site:staff":
			crew_a.append(str(n.character))
	_check(
		crew_a.size() == 2 and crew_b.size() == 2 and crew_a != crew_b,
		"a competitor's dental office has different people: %s vs %s" % [str(crew_a), str(crew_b)]
	)

	# the review fixes: staying stays, ageing is floored, cooldowns, closed tickets, prospects
	_drain(cards)
	world.clock = 9.0
	game.ui_open = false
	var t5: Dictionary = on.create_job(3, "switch")
	on.offer(int(t5.id))
	cards.pick(0)
	await _wait(1.2)
	on.interact("door")
	_check(
		cards.is_open and cards.options[0].id == "leave" and cards.options[1].id == "go",
		"the leave card: Esc means stay"
	)
	cards.pick(0)
	_check(on.active and str(t5.status) != "Closed", "STAY AND FINISH really stays")
	var aged: Dictionary = msp.create_ticket(0, 0, "email")
	aged.sla_left = float(aged.sla_total)
	on._away(10.0)
	_check(
		float(aged.sla_left) >= float(aged.sla_total) * 0.35 - 0.01,
		"ten hours away still leaves 35 percent of an SLA"
	)
	_check(on.at_risk(70) >= 0, "the dispatch card can count tickets at risk")
	on._logged_day = {}
	on._found_answer(on.FINDINGS["pc"][0], "ticket")
	var toasts0: int = msp.tickets.size()
	on._found_answer(on.FINDINGS["pc"][1], "ticket")
	_check(
		msp.tickets.size() == toasts0, "a second ticket for the same client the same day is refused"
	)
	on.visit_prospect = true
	on._found(on.FINDINGS["pc"][0])
	_check(
		cards.is_open and cards.options[0].id == "tell" and cards.options.size() == 2,
		"at a prospect you can only tell them about it"
	)
	cards.pick(1)
	on.visit_prospect = false
	on.interact("door")
	cards.pick(1)
	await _wait(1.2)
	_drain(cards)
	var closed: Dictionary = msp.create_ticket(0, 0, "email")
	closed.status = "Closed"
	closed.fix = "onsite_switch"
	on.offer(int(closed.id))
	_check(not cards.is_open, "a closed ticket is not dispatched")
	var qa_vis := 0
	var pr := root.get_node("Projects")
	pr._queue = []
	for i in 5:
		pr.offer_project(3, "network")
	pr.offer_project(1, "server")
	pr.offer_project(2, "desktops")
	_check(
		pr._queue.size() == 2,
		"project quotes are deduplicated and capped at two (%d)" % pr._queue.size()
	)
	qa_vis += 1

	# the door menu pages wrap around
	root.get_node("DayReport").is_open = false  # an earlier step left the report up: it would hold cards back
	cards.flush()
	_drain(cards)
	game.ui_open = false
	var list: Array = on.door_clients()
	on._door_page(list, 0)
	_check(
		cards.is_open and cards.options[cards.options.size() - 2].id == "more",
		"page one offers MORE SITES"
	)
	cards.pick(cards.options.size() - 2)
	_check(cards.is_open, "and the next page opens")
	var guard := 0
	while cards.is_open and guard < 6 and cards.options[cards.options.size() - 2].id == "more":
		cards.pick(cards.options.size() - 2)
		guard += 1
	_check(
		cards.is_open and cards.options[cards.options.size() - 2].id == "back",
		"the last page goes back to the first"
	)
	cards.pick(cards.options.size() - 2)
	_check(
		cards.is_open and cards.options[cards.options.size() - 2].id == "more",
		"which is page one again"
	)
	_drain(cards)

	await _wait(1.5)
	# the realty coffee bar pours a coffee; the sign-in sheet and the architects' desk only talk
	game.go("site_realty_a", "start")
	await _wait(0.8)
	var pl := current_scene.get_node("Actors/Player")
	pl.give("")
	on.interact("coffeebar")
	await _wait(1.4)
	_check(str(pl.held) == "coffee", "the realty coffee bar gives you a coffee")
	on.interact("coffeebar")
	_check(str(pl.held) == "coffee", "a second pour does nothing more")
	pl.give("")
	var pets_site: int = on.pets
	on.interact("signin")
	on.interact("recep")
	_check(str(pl.held) == "" and on.pets == pets_site, "the sign-in sheet and the reception desk have no game effect")
	var names := []
	for z in current_scene.get_node("Interactables").get_children():
		names.append(str(z.name))
	_check("UseObjCoffee" in names and "UseObjSignin" in names, "realty has coffee bar and sign-in zones")
	_check(current_scene.get_node("Interactables/UseObjSignin").low_priority, "the sign-in zone is low priority")
	game.go("site_arch_b", "start")
	await _wait(0.8)
	var recep := current_scene.get_node_or_null("Interactables/UseObjRecep")
	_check(recep != null and recep.low_priority, "the architects' reception desk is a low priority zone")
	await _wait(1.5)
	# every room of every site loads, with something to use in it
	for site in ["dental", "law", "vet", "arch", "realty", "trailer"]:
		for skin in ["a", "b"]:
			var rooms := ["site_%s_%s", "site_%s_closet_%s", "site_%s_office_%s"]
			if site in ["dental", "vet"]:
				rooms.append("site_%s_exam_%s")
			for pattern in rooms:
				var name: String = pattern % [site, skin]
				game.go(name, "start")
				await _wait(0.6)
				var zones := 0
				for z in current_scene.get_node("Interactables").get_children():
					zones += (
						1
						if str(z.name).begins_with("UseObj") or str(z.name).begins_with("Use")
						else 0
					)
				_check(
					_scene() == name and zones >= 1, "%s loads (%d things to use)" % [name, zones]
				)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
