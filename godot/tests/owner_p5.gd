extends SceneTree
# P5, owner campaign leftovers: Maya on the owner's payroll (it was already built in X4), the new onsite jobs and findings,
# the new projects (hosted phones, email migration) and the owner Rodent Nation card chain tied to the Owner.STACK.
# Headless; saves in user://test_*.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var on := root.get_node("Onsite")
	var pr := root.get_node("Projects")
	var career := root.get_node("Career")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("owner")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)

	# 1. Maya: on the crew from the first week (she is not a hire; X4 made her an employee)
	_check(
		o.crew_names().has("Maya") and world.chars.has("Maya"),
		"owner campaign: Maya is on the crew and in the building"
	)
	var wages: int = o.crew_wages()
	_check(wages >= 1200, "and her wage is in the payroll (%d)" % wages)

	# 2. the new onsite jobs, reachable from the owner campaign
	var reached := {}
	for id in ["phones", "wifi", "mailbox"]:
		var job: Dictionary = {}
		for j in on.MORE_JOBS:
			if str(j.id) == id:
				job = j
		_check(not job.is_empty(), "job %s is in the patchable MORE_JOBS table" % id)
		var good := 0.0
		for opt in job.get("options", []):
			good = maxf(good, float(opt.chance))
		_check(good >= 0.9 and (job.options as Array).size() == 3, "%s has a good fix and 3 options" % id)
		for client in 9:
			if not on.has_site(client):
				continue
			if not (on.OBJECTS[on.site_type(client)] as Array).has(str(job.object)):
				continue
			var t: Dictionary = on.create_job(client, id)
			if not t.is_empty():
				reached[id] = on.is_onsite(t) and str(on.job_for(t).id) == id
				break
	_check(
		reached.size() == 3 and not reached.values().has(false),
		"all three become onsite tickets for a client with a site (%s)" % str(reached)
	)
	# every finding names a real fix and a real project
	var bad := 0
	for obj in on.FINDINGS:
		for f in on.FINDINGS[obj]:
			if str(f.project) != "" and not pr.TYPES.has(str(f.project)):
				bad += 1
			var fix := str(f.fix)
			if fix.begins_with("onsite_") and on.job_for({"fix": fix}).is_empty():
				bad += 1
	_check(bad == 0, "every finding points to a real project and onsite job")
	var projects_found := []
	for obj in on.FINDINGS:
		for f in on.FINDINGS[obj]:
			projects_found.append(str(f.project))
	_check(
		projects_found.has("voip") and projects_found.has("email_move"),
		"findings in the closet and at a PC offer the new projects"
	)

	# 3. the new projects
	for id in ["voip", "email_move"]:
		_check(pr.TYPES.has(id), "project %s exists" % id)
		var profit := 0
		for i in 10:
			profit += pr.quote_profit(pr.make_quote(0, id))
		_check(profit > 0, "%s earns money when nothing creeps (%d over 10 quotes)" % [id, profit])
	c.day = 6
	var drew := {}
	for i in 400:
		drew[pr._pick_type(0)] = true
	_check(drew.has("voip") and drew.has("email_move"), "week 6 quotes can be phones and email")
	c.day = 2
	drew = {}
	for i in 200:
		drew[pr._pick_type(0)] = true
	_check(not drew.has("voip") and not drew.has("email_move"), "but not in the first weeks")
	pr._queue = []
	pr.offer_project(1, "voip")
	_check(pr._queue.size() == 1, "a phone project can be offered as a quote")
	pr._queue = []

	# 4. the owner Rodent Nation chain
	_check(
		_has_card_on(o, 10, "rn_invite"), "Rodent Nation is invited on week 10 in the owner campaign"
	)
	var career_trips: int = career.value("trips")
	o.cash = 200
	o.show_card("rn_invite")
	_check(
		not bool(cards.options[0].get("enabled", true)) and not bool(cards.options[1].get("enabled", true)),
		"with $200 neither trip can be paid for"
	)
	cards.pick(2)  # stay home
	_check(o.cash == 200 and cards.is_open, "staying home costs nothing and gets a short note")
	cards.pick(0)
	o.cash = 5000
	var speed0: float = o.speed
	o.show_card("rn_invite")
	cards.pick(1)  # send the tech
	_check(o.cash == 4700 and o.speed > speed0, "sending the tech: $300 and a small speed idea")
	cards.pick(0)
	_check(not cards.is_open, "and that is the whole trip")
	o.cash = 5000
	speed0 = o.speed
	var weekly0: int = o.weekly_extra
	var price0: float = o.price
	o.show_card("rn_invite")
	cards.pick(0)  # go yourself
	_check(o.cash == 4550 and cards.is_open and cards.speaker == "RODENT NATION", "going yourself: $450, then the session card")
	cards.pick(0)  # pricing clinic
	_check(is_equal_approx(o.price, price0 + 0.03) and cards.is_open, "the pricing clinic raises prices 3% and opens the hall")
	_check(
		cards.options.size() == 4 and cards.options[3].label == "HEAD HOME", "the hall offers three booths and the way home"
	)
	cards.pick(0)  # the RMM booth
	_check(cards.speaker.begins_with("LabRat"), "the RMM booth is the RMM vendor")
	cards.pick(0)  # sign
	_check(
		o.stack.rmm == "labrat_gold" and o.cash == 4400 and o.weekly_extra == weekly0 + 25 and o.flags.get("rn_rmm", false),
		"signing the show special: LabRat Gold for $150 and +$25 a week of add-ons"
	)
	_check(
		cards.is_open and not bool(cards.options[0].get("enabled", true)), "back in the hall that booth is done (OWNED)"
	)
	cards.pick(1)  # PSA
	var speed1: float = o.speed
	cards.pick(0)
	_check(
		o.stack.psa == "opsforge" and o.cash == 4250 and o.speed < speed1 + 0.001 and is_equal_approx(speed1 - o.speed, 0.05),
		"the PSA special: OpsForge for $150 and the crew is slower for a while"
	)
	cards.pick(2)  # hardware
	var vic0: float = o.vic_bonus
	cards.pick(0)
	_check(
		o.stack.hardware == "dellight" and is_equal_approx(vic0 - o.vic_bonus, 0.03),
		"the hardware special is free, and Vic sells less"
	)
	# a brochure changes nothing
	o.stack.hardware = "hewlitt"
	o.flags["rn_hw"] = false
	var cash1: int = o.cash
	cards.pick(2)
	cards.pick(1)
	_check(o.stack.hardware == "hewlitt" and o.cash == cash1, "taking the brochure leaves the stack alone")
	cards.pick(3)  # head home
	_check(cards.is_open and cards.speaker == "RODENT NATION", "the trip ends with a wrap-up card")
	cards.pick(0)  # fly home
	_check(cards.is_open, "the wrap-up has a closing note")
	cards.pick(0)
	_check(not cards.is_open, "and then you are home")
	_check(career.value("trips") >= career_trips + 2, "both trips count as trips for the career")

	# the books still work with the new stack
	var est: Dictionary = o.weekly_estimate()
	_check(int(est.fixed) > 0 and est.has("ebitda"), "the weekly books still add up")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func _has_card_on(o: Node, week: int, id: String) -> bool:
	for entry in o.DAYS[week]:
		if str(entry.get("card", "")) == id:
			return true
	return false
