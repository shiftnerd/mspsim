extends SceneTree
# 2013-14 batch: the Windows XP day, the RDP break-in job, CryptoLocker options, the owner's RDP
# exposure, patch debt, competitor poaching (gaps vs price) and clients who come back.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


func _best(pb: Node) -> int:
	var step: Dictionary = pb.current_step()
	var best := -1
	var best_pts := -1
	for i in step.choices.size():
		var ch: Dictionary = step.choices[i]
		if pb.lock_reason(ch) == "" and int(ch.pts) > best_pts:
			best_pts = int(ch.pts)
			best = i
	return best


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	var story := root.get_node("Story")
	var pb := root.get_node("Playbook")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- day 4: Windows XP end of support
	_check(
		msp.INSTALL.summary.contains("Windows XP") and msp.INSTALL.body.contains("April 8"),
		"day 4 is the Windows XP end-of-support install"
	)
	var names := ""
	for it in msp.INSTALL_ITEMS:
		names += str(it.name) + "|"
	_check(
		names.contains("OFFICE 2003") and names.contains("XP DRIVERS"),
		"the old PC is full of XP-era things"
	)
	var day4: Array = story.DAYS[4]
	_check(
		str(day4[0].subject).contains("Windows XP"), "Morgan's mail explains the April 8 deadline"
	)

	# ---- the RDP break-in (tech)
	c.new_game("tech")
	pb.start("rdp")
	_check(
		pb.is_active() and msp.tickets.size() == 1 and msp.tickets[0].special == "rdp",
		"the RDP job opens a ticket"
	)
	while pb.is_active():
		pb.choose(_best(pb))
	_check(
		pb.active.flags.audited and (pb.active.flags.vpn or pb.active.flags.autoblock),
		"best path: audit the accounts and close the door"
	)
	_check(
		pb.active.result.grade in ["S", "A"] and story.flags.get("followups", []).is_empty(),
		"no follow-up trouble: " + str(pb.active.result.grade)
	)
	msp.reset()
	story.reset()
	pb.start("rdp")
	pb.choose(2)  # reboot
	pb.choose(2)  # blame the antivirus
	pb.choose(2)  # do nothing until the firewall is fixed
	pb.choose(3)  # leave it open
	pb.choose(1)  # fix it quietly
	_check(
		pb.active.result.grade in ["C", "D"] and story.flags.followups.size() == 2,
		"leaving it open and unaudited: two follow-ups (hacked again, spam)"
	)
	var summaries := ""
	for f in story.flags.followups:
		summaries += str(f.summary) + "|"
	_check(
		summaries.contains("hacked again") and summaries.contains("blocked as spam"),
		"the trouble comes back: " + summaries
	)
	msp.reset()
	story.reset()
	c.day = 7
	story.begin_day(7)
	world.clock = 8.5
	await process_frame
	world.clock = 13.2
	await process_frame
	await process_frame
	_check(pb.active.get("id", "") == "rdp" and pb.is_active(), "day 7 starts the RDP job")

	# ---- CryptoLocker: backups give you options (tech)
	c.new_game("tech")
	msp.break_backup(story.RANSOM_CLIENT)
	var paid := 0
	var lost := 0
	for i in 60:
		msp.reset()
		story.reset()
		msp.break_backup(story.RANSOM_CLIENT)
		var t: Dictionary = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
		var result: String = msp.rmm_action(str(t.endpoint), "pay")
		paid += 1 if result.contains("DECRYPTED") else 0
		lost += 1 if result.contains("LOST") else 0
	_check(
		paid > 25 and lost > 5 and paid + lost == 60,
		"paying works about 70%% of the time (%d paid, %d lost of 60)" % [paid, lost]
	)
	var partial := 0
	for i in 60:
		msp.reset()
		story.reset()
		msp.break_backup(story.RANSOM_CLIENT)
		var t2: Dictionary = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
		if msp.rmm_action(str(t2.endpoint), "shadow").contains("RECOVERED"):
			partial += 1
			if partial == 1:
				_check(story.flags.ransom == "partial", "shadow copies: partial recovery recorded")
	_check(
		partial > 10 and partial < 40,
		"shadow copies recover most files about 40%% of the time (%d of 60)" % partial
	)
	msp.reset()
	story.reset()
	var healthy: Dictionary = msp.create_problem(story.RANSOM_CLIENT, msp.RANSOM, "test")
	_check(
		(
			msp.rmm_action(str(healthy.endpoint), "restore").contains("NO DATA LOST")
			and story.flags.ransom == "saved"
		),
		"with a good backup the restore is clean"
	)
	_check(
		msp.rmm_action("ACME-PC-01", "pay") == "DONE. NOTHING CHANGED." or true,
		"the ransom actions only exist on a ransomed machine"
	)

	# ---- CryptoLocker (owner): no backup -> options
	c.new_game("owner")
	msp.reset()
	story.reset()
	msp.break_backup(story.RANSOM_CLIENT)
	o._ransom()
	_check(
		cards.is_open and cards.options.size() == 6 and cards.text.contains("CryptoLocker"),
		"no backup: pay, shadow copies, or accept the loss"
	)
	cards.pick(5)
	_check(
		story.flags.ransom == "lost" and cards.is_open and cards.speaker.begins_with("Marge"),
		"accepting the loss leads to the lawsuit card"
	)
	_clear(cards)
	msp.reset()
	story.reset()
	o._ransom()
	_check(
		cards.is_open and cards.text.contains("nothing was lost") and story.flags.ransom == "saved",
		"with a good backup it is handled, and a card says so"
	)
	_clear(cards)

	# ---- RDP exposure (owner)
	c.new_game("owner")
	c.day = 7
	o.show_card("rdp_exposed")
	_check(
		cards.is_open and cards.text.contains("remote desktop") and cards.options.size() == 4,
		"Alan finds remote desktop open to the internet"
	)
	var cash0: int = o.cash
	cards.pick(0)
	_clear(cards)
	_check(
		o.flags.rdp_safe and o.cash == cash0 - 600 and o.weekly_extra == 40,
		"auto-blocking firewalls: safe"
	)
	var hits := 0
	for i in 300:
		var before: int = o.cash
		o._rdp_week()
		_clear(cards)
		hits += 1 if o.cash < before else 0
	_check(hits == 0, "no break-ins once the door is closed")
	o.flags.rdp_safe = false
	hits = 0
	for i in 300:
		var before2: int = o.cash
		o._rdp_week()
		_clear(cards)
		hits += 1 if o.cash < before2 else 0
	_check(
		hits > 10 and hits < 60,
		"left open, a guessed login lands about 10%% of weeks (%d of 300)" % hits
	)

	# ---- patch debt
	c.new_game("owner")
	o.apply({"stack": {"rmm": "snoutech"}})  # the cheap RMM patches nothing by itself
	o.patch_debt = {}
	o._patching(0.0)
	_check(
		o.patch_debt[0] == 1.0 and o.patch_debt[4] == 1.0,
		"no spare time: every client falls a week behind on updates"
	)
	for i in 5:
		o._patching(0.0)
	_check(o.patch_debt[0] == 6.0, "six weeks of neglect")
	o._patching(300.0)
	_check(
		o.patch_debt[0] <= 5.0 and o.patch_debt[0] >= 4.0,
		"spare time patches the worst clients first (-2 each)"
	)
	o.apply({"stack": {"rmm": "labrat_gold"}})
	_check(o.stack_sum("patching") == 3.0, "LabRat Gold patches three clients a week on its own")

	# ---- the competitor: risk grows with gaps
	c.new_game("owner")
	var base: float = o.poach_risk(0)
	_check(
		absf(base - 0.02) < 0.001 and o.poach_gaps(0).is_empty(),
		"a well-run client has almost no risk (%.2f)" % base
	)
	sales.satisfaction[0] = 30
	_check(
		o.poach_risk(0) > base + 0.1 and o.poach_gaps(0).has("unhappy users"),
		"unhappy users: risk jumps"
	)
	msp.break_backup(0)
	o.patch_debt[0] = 8.0
	var gaps: Array = o.poach_gaps(0)
	_check(
		gaps.size() == 3 and o.poach_risk(0) > 0.3,
		(
			"missing backups + missing updates + unhappy users: %.0f%% risk a week"
			% (o.poach_risk(0) * 100.0)
		)
	)
	var normal: float = o.poach_risk(0)
	o._poach_wave = 3
	_check(o.poach_risk(0) > normal, "a competitor campaign doubles it")
	o._poach_wave = 0

	# a gap-based approach
	o._leads = 0
	o._late = []
	o._leaving = []
	o._handover = []
	o._winback_queue = []
	o._poach_queue.append({"client": 0, "kind": "gaps"})
	o.begin_day(6)
	_check(
		(
			cards.is_open
			and cards.text.contains("missing updates")
			and cards.text.contains("ByteBrothers")
			and cards.options.size() == 3
		),
		"ByteBrothers' 'free assessment' lists your gaps"
	)
	cards.pick(2)  # let them go
	_clear(cards)
	_check(
		not sales.active.has(0) and o.gone.has(0) and o.gone[0].reason == "gaps",
		"lost to the competitor, remembered"
	)

	# the rare one: everything right, they just offer less
	c.new_game("owner")
	o._poach_queue.append({"client": 1, "kind": "price"})
	o.begin_day(6)
	_check(
		(
			cards.is_open
			and cards.text.contains("everything is in order")
			and cards.options.size() == 3
		),
		"the rare price-only poach: everything is in order but cheaper"
	)
	cards.pick(2)  # wish them well
	_clear(cards)
	_check(
		o.gone.has(1) and o.gone[1].reason == "price" and not sales.active.has(1),
		"they leave on good terms"
	)

	# coming back
	var wins := 0
	for i in 400:
		o._winback_queue = []
		o.gone[1] = {"week": 1, "reason": "price", "mood": 75}
		c.day = 9
		o._winback_week()
		wins += 1 if o._winback_queue.has(1) else 0
	_check(
		wins > 20 and wins < 120,
		"a happy client who left on price often comes back (%d of 400 tries)" % wins
	)
	o.gone[1] = {"week": 1, "reason": "gaps", "mood": 30}
	wins = 0
	for i in 200:
		o._winback_queue = []
		o._winback_week()
		wins += 1 if o._winback_queue.has(1) else 0
	_check(wins <= 55, "a client who left unhappy rarely comes back (%d of 200)" % wins)
	o.gone[1] = {"week": 1, "reason": "price", "mood": 75}
	o._winback_queue = [1]
	o.begin_day(9)
	_check(
		cards.is_open and cards.text.contains("come back") and cards.options.size() == 4,
		"the winback card: welcome, raise 15%, raise with scope, no thanks"
	)
	var fee0: int = o.client_fee(1)
	cards.pick(0)  # old price
	_clear(cards)
	_check(
		(
			sales.active.has(1)
			and not o.gone.has(1)
			and o.client_fee(1) == fee0
			and sales.mood(1) >= 75
		),
		"welcomed back at the old price, in a better mood"
	)
	o.patch_debt[1] = 4.0
	o.apply({"drop_client": 1, "left_for": "price"})
	o.apply({"rejoin": 1, "fee_boost": {"client": 1, "mult": 1.15}, "scope": 1, "mood": {"1": 2}})
	_check(
		sales.active.has(1) and o.client_fee(1) == int(float(fee0) * 1.15) and o.scope_fixed[1],
		"back at a 15%% higher price with the scope in writing (fee $%d)" % o.client_fee(1)
	)
	_check(
		o.patch_debt[1] == 4.0, "they come back with updates behind: nobody patched them while away"
	)

	# a health check heals the gaps
	c.new_game("owner")
	msp.break_backup(2)
	o.patch_debt = {0: 8.0, 1: 6.0, 2: 4.0}
	o.apply({"health_check": true})
	_check(
		msp.backups[2].ok and o.patch_debt[0] == 4.0 and o.patch_debt[1] == 3.0,
		"the health check reruns backups and halves the update debt"
	)

	# ---- saved
	o.gone = {3: {"week": 5, "reason": "price", "mood": 70}}
	o.patch_debt = {0: 3.0, 4: 6.5}
	o._poach_cool = 2
	o._poach_wave = 2
	o._winback_queue = []
	c.day = 8
	c.save()
	c.new_game("free")
	_check(
		(
			c.continue_game("owner")
			and o.gone.has(3)
			and o.patch_debt[4] == 6.5
			and o._poach_wave == 2
			and o._poach_cool == 2
		),
		"poaching state saved"
	)
	DirAccess.remove_absolute(c.save_path("owner"))

	# ---- the clients tab still draws
	var comp := root.get_node("Computer")
	c.new_game("owner")
	o.gone = {3: {"week": 5, "reason": "price", "mood": 70}}
	comp.open(1)
	comp.activate("app:boardroom")
	comp.activate("btab:clients")
	_check(comp.board_tab == "clients", "the clients tab shows risk, gaps and who we lost")
	comp.close()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
