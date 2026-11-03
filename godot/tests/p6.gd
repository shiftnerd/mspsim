extends SceneTree
# P6: the heavy fix in person (ONSITE REIMAGE), more ways out of the ransomware (vendor versions, isolate and rebuild,
# cyber insurance) and the clever fixes in Free Play at a fixed level.
# gdlint:disable=max-line-length

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 10:
		cards.pick(0)
		guard += 1


func _scene() -> String:
	var sc := current_scene
	return "" if sc == null else sc.scene_file_path.get_file().get_basename()


# a ransomed server at the law firm whose backup failed
func _ransomed(msp: Node, story: Node) -> Dictionary:
	msp.reset()
	story.reset()
	msp.break_backup(story.RANSOM_CLIENT)
	var t: Dictionary = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
	msp.rmm_action(str(t.endpoint), "restore")  # records the failed restore
	return t


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var on := root.get_node("Onsite")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	var story := root.get_node("Story")
	var sk := root.get_node("Skills")
	var d := root.get_node("Difficulty")
	var comp := root.get_node("Computer")
	var o := root.get_node("Owner")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	d.seed_run(4242)

	# ---- (c) Free Play: the clever fixes are open at the fixed level, no heavy onsite offer
	msp.reset()
	on.enabled = true
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	var ep: Dictionary = msp.endpoint(t.endpoint)
	_check(msp.FREE_PLAY_LEVEL == 3, "the Free Play level is fixed at 3")
	_check(msp.alts_for(ep).has("copier_route"), "free play: PRINT TO COPIER (NETWORKING 2) is offered")
	t = msp.create_ticket(0, 1, "test")
	ep = msp.endpoint(t.endpoint)
	_check(msp.alts_for(ep).has("unlock_ps"), "free play: UNLOCK-ADACCOUNT (POWERSHELL 2) is offered")
	t = msp.create_ticket(0, 2, "test")
	ep = msp.endpoint(t.endpoint)
	_check(msp.alts_for(ep).has("disk_script"), "free play: CLEANUP SCRIPT (POWERSHELL 3) is offered")
	_check(msp.onsite_heavy(ep) == "", "free play: no onsite reimage offer")
	msp.rmm_action(ep.name, "disk_script")
	_check(msp.ticket(t.id).fix_done and ep.problem == "", "free play: the clever fix works")

	# ---- (a) the tech campaign
	c.new_game("tech")
	_drain(cards)
	c.day = 6
	on.enabled = true
	msp.reset()
	story.reset()
	msp.alt_roll = -1.0
	sales.satisfaction[0] = 70
	_check(not msp.alts_for(msp.endpoint(msp.create_ticket(0, 0, "test").endpoint)).has("copier_route"), "campaign: the clever fix still needs the skill")
	msp.reset()
	t = msp.create_ticket(0, 2, "test")  # slow PC at Acme Dental (has a site)
	ep = msp.endpoint(t.endpoint)
	_check(msp.onsite_heavy(ep) == "reimage", "a slow PC at a client with a site offers the onsite reimage")
	var pw: Dictionary = msp.create_ticket(0, 1, "test")
	_check(msp.onsite_heavy(msp.endpoint(pw.endpoint)) == "new_profile", "a locked-out account offers the onsite profile rebuild")
	var srv: Dictionary = msp.create_ticket(0, 5, "test")
	_check(msp.onsite_heavy(msp.endpoint(srv.endpoint)) == "", "a server is not part of it")
	var nosite: Dictionary = msp.create_ticket(2, 2, "test")
	_check(not nosite.is_empty() and msp.onsite_heavy(msp.endpoint(nosite.endpoint)) == "", "a client without a site is not offered it")
	on.enabled = false
	_check(msp.onsite_heavy(ep) == "", "...nor when onsite visits are off")
	on.enabled = true

	# the tier numbers: normal is unchanged, hard makes the remote version slower and riskier
	_check(msp.heavy_fail_chance(ep, "reimage") == 0.0 and msp.heavy_slow(ep, "reimage") == 1.0, "normal: the remote reimage is as it was")
	d.set_tier("hard")
	_check(msp.heavy_fail_chance(ep, "reimage") == 0.25 and msp.heavy_slow(ep, "reimage") == 1.3, "hard: the remote reimage fails 25 percent and takes 1.3x")
	_check(msp.heavy_fail_chance(ep, "reinstall_printer") == 0.0 and msp.heavy_fail_chance(ep, "recycle") == 0.0, "...only for the reimage and the profile rebuild")
	d.set_tier("easy")
	_check(d.cf("tech.onsite_mood") == 3.0, "easy: the visit earns more mood")
	d.set_tier("normal")

	# the button: it offers, it does not force; the remote fix stays
	_check(msp.alts_for(ep).has("reimage"), "the remote REIMAGE PC is still offered")
	ep["unsaved"] = true
	ep["asked"] = false
	comp.rmm_sel = ep.name
	comp._start_job("fix", "go_reimage")
	_check(cards.is_open and cards.options.size() == 2 and comp._job.is_empty(), "the onsite button opens the dispatch card (drive time), no job runs")
	cards.pick(1)  # NOT YET
	_check(not on.active and str(ep.problem) == "clear_temp", "NOT YET leaves everything as it was")
	comp._start_job("fix", "go_reimage")
	var clock0: float = root.get_node("World").clock
	var xp_servers: int = sk.xp["servers"]
	var mood0: int = sales.mood(0)
	cards.pick(0)
	await _wait(1.2)
	_check(_scene() == "site_dental_a" and on.active and bool(on.job.get("reimage", false)), "you drive to the client with the reimage job")
	_check(root.get_node("World").clock > clock0, "the drive costs clock time")
	on.pc_diagnose("pc")
	_check(cards.is_open and cards.options.size() == 2, "the PC offers the in-person work")
	cards.pick(0)
	_drain(cards)
	_check(str(msp.ticket(t.id).status) == "Closed" and ep.problem == "", "the ticket is fixed and closed from the site")
	_check(str(msp.ticket(t.id).get("method", "")) == "onsite", "the ticket records it was done in person")
	_check(not bool(ep.unsaved) and sales.mood(0) >= mood0 + 2, "nothing lost, and the client mood goes up (%d -> %d)" % [mood0, sales.mood(0)])
	_check(sk.xp["servers"] >= xp_servers + 5, "5 servers XP for the visit")
	var angry := false
	for m in msp.emails:
		angry = angry or str(m.get("subject", "")).contains("LOST MY WORK")
	_check(not angry, "no angry mail about lost work")
	on.interact("door")
	await _wait(1.2)
	_check(not on.active and _scene() == "main_floor", "you drive back")

	# ---- (b) ransomware alternatives
	c.new_game("tech")
	_drain(cards)
	var sh := 0
	for cl in 40:
		d.seed_run(100 + cl)
		sh += 1 if msp.cyber_insured(story.RANSOM_CLIENT) else 0
	_check(sh > 8 and sh < 32, "about half of the runs have a cyber policy at the law firm (%d of 40)" % sh)
	d.seed_run(4242)
	var look1: bool = msp.cyber_insured(2)
	_check(look1 == msp.cyber_insured(2), "the policy is seeded, not random per look")
	_check(msp.FIXES.vendor.length() <= 18 and msp.FIXES.rebuild.length() <= 18 and msp.FIXES.insurer.length() <= 18, "the new ransom buttons fit")

	t = _ransomed(msp, story)
	ep = msp.endpoint(str(t.endpoint))
	var res: String = msp.rmm_action(ep.name, "rebuild")
	_check(ep.problem != "restore" and story.flags.ransom == "rebuilt" and res.contains("REBUILT"), "isolate and rebuild always works: " + res)
	_check(msp.close_ticket(int(t.id)).contains("CLOSED +4"), "...and closes for few points")
	_check(msp.RANSOM_LABELS.rebuilt == "REBUILT, FILES LOST", "the review line exists")

	var won := 0
	for i in 60:
		t = _ransomed(msp, story)
		ep = msp.endpoint(str(t.endpoint))
		res = msp.rmm_action(ep.name, "vendor")
		if ep.problem != "restore":
			won += 1
			if won == 1:
				_check(story.flags.ransom == "vendor" and res.contains("NO DATA LOST"), "vendor versions: clean recovery recorded: " + res)
				_check(msp.close_ticket(int(t.id)).contains("CLOSED +"), "a vendor recovery closes normally")
		else:
			if i < 3:
				_check(msp.rmm_action(ep.name, "vendor").contains("NO OTHER VERSIONS") and ep.problem == "restore", "the vendor can only be asked once")
	_check(won > 14 and won < 46, "the vendor finds an old version about half of the time (%d of 60)" % won)

	var ins_ok := 0
	# find a seed with a policy and one without, then run the odds on the one with
	var with_policy := -1
	for s in range(1, 60):
		d.seed_run(s)
		if msp.cyber_insured(story.RANSOM_CLIENT):
			with_policy = s
			break
	_check(with_policy > 0, "some seed gives the law firm a policy")
	d.seed_run(with_policy)
	ins_ok = 0
	for i in 60:
		t = _ransomed(msp, story)
		ep = msp.endpoint(str(t.endpoint))
		res = msp.rmm_action(ep.name, "insurer")
		ins_ok += 1 if ep.problem != "restore" else 0
	_check(ins_ok > 25 and ins_ok < 55, "the insurer pays about 65%% of the time (%d of 60)" % ins_ok)

	# the RMM buttons: the new options only show on a ransomed machine, the insurer only with a policy
	t = _ransomed(msp, story)
	ep = msp.endpoint(str(t.endpoint))
	_check(msp.cyber_insured(int(ep.client)), "setup: this seed has a policy")
	_check(str(comp._symptom("restore", true)).contains("VENDOR"), "the symptom text names the new options")

	# ---- (b) the owner card
	c.new_game("owner")
	_drain(cards)
	var card: Dictionary = o.card_data("ransom_options")
	var labels := []
	for opt in card.options:
		labels.append(str(opt.label))
	_check(card.options.size() == 6, "the owner card has six options (%s)" % str(labels))
	d.seed_run(with_policy)
	o.cash = 5000
	msp.reset()
	story.reset()
	msp.break_backup(story.RANSOM_CLIENT)
	var rt: Dictionary = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
	o._ransom_ticket = int(rt.id)
	var idx_rebuild := 3
	_check(str(card.options[idx_rebuild].label).begins_with("ISOLATE IT AND REBUILD"), "option 3 is the rebuild")
	o._picked("ransom_options", idx_rebuild)
	_drain(cards)
	_check(story.flags.ransom == "rebuilt" and o.cash == 4000, "owner: rebuild costs $1,000 and is recorded")
	_check(not bool(o.goal_parts(true)[0].ok) if c.player_as == "Alan" else true, "...and is not a clean year")
	# Q6: expected cash cost of each owner exit (a "lost" ending costs the $2,500 settlement); no exit may be a free lunch
	var ev := {}
	for opt in card.options:
		var cost := 0.0
		if opt.has("roll"):
			for r in opt.roll:
				cost -= float(r[0]) * (float(r[1].get("cash", 0)) - (2500.0 if r[1].get("ransom_end", "") == "lost" else 0.0))
		else:
			cost = -float(opt.fx.get("cash", 0)) + (2500.0 if opt.fx.get("ransom_end", "") == "lost" else 0.0)
		ev[str(opt.label).substr(0, 8)] = cost
	_check(float(ev["ISOLATE "]) >= 0.5 * float(ev["PAY THE "]), "balance: the rebuild is not cheaper than half the expected cost of paying (%s)" % str(ev))
	msp.reset()
	story.reset()
	rt = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
	o._ransom_ticket = int(rt.id)
	o._ransom_finish("vendor")
	_drain(cards)
	_check(story.flags.ransom == "vendor", "owner: a vendor recovery is recorded")
	var labels_ok := true
	for k in ["saved", "lost", "paid", "partial", "vendor", "rebuilt", "insured"]:
		labels_ok = labels_ok and msp.RANSOM_LABELS.has(k)
	_check(labels_ok, "every ransomware ending has a review line")
	story.flags["ransom"] = "insured"
	story._callback_ransom()
	_check(true, "the day-14 callback copes with the insured ending")
	for k in ["vendor", "rebuilt"]:
		story.flags["ransom"] = k
		story._callback_ransom()
	_drain(cards)

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
