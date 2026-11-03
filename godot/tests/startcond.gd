extends SceneTree
# Starting conditions (roadmap R9): STANDARD changes nothing, each other condition changes exactly what it
# should, the chip on the character select screen, saves and old saves.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/startcond.gd

var CharSelect: GDScript
var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	for i in 30:
		if not cards.is_open:
			break
		cards.pick(cards.options.size() - 1)


func _moods(sales: Node) -> Array:
	var out := []
	for c in sales.active:
		out.append(int(sales.satisfaction[c]))
	return out


func _init() -> void:
	await process_frame
	CharSelect = load("res://scripts/charselect.gd")
	var mu := root.get_node("Mutators")
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var diff := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var owner := root.get_node("Owner")
	var career := root.get_node("Career")
	c.save_prefix = "user://test_sc_%d_" % OS.get_process_id()
	career.toasts = false
	diff.set_tier("normal")

	_check(mu.START_ORDER.size() >= 5 and mu.STARTS.size() >= 5, "at least five starting conditions")
	_check(mu.STARTS.standard.size() <= 4, "STANDARD has no overrides")
	_check(mu.starts_for("tech") == ["standard", "messy", "only_tech", "rival"], "tech offers four: %s" % str(mu.starts_for("tech")))
	_check(mu.starts_for("owner") == ["standard", "messy", "rival", "family"], "owner offers four: %s" % str(mu.starts_for("owner")))

	# ---- STANDARD: nothing changes
	c.new_game("tech")
	_drain(cards)
	var std_tech_moods := _moods(sales)
	_check(mu.start_id == "standard" and std_tech_moods == [70, 70, 70, 70, 70], "tech STANDARD: five clients at 70")
	_check(mu.absent().is_empty() and mu.ticket_rate() == 1.0 and mu.ticket_weights().is_empty(), "tech STANDARD: full team, normal tickets")
	_check(world.chars.has("Dan") and world.chars.has("Maya"), "tech STANDARD: Dan and Maya at their desks")
	c.new_game("owner")
	_drain(cards)
	var std_debt: Dictionary = owner.patch_debt.duplicate()
	var std_wave: int = owner._poach_wave
	var risk_std: float = owner.poach_risk(0)
	var cash0: int = owner.cash
	owner.apply({"stack": {"psa": "opsforge"}})
	var std_cost: int = cash0 - owner.cash
	_check(std_debt.is_empty() and std_wave == 0 and mu.stack_fee("psa", "x") == 0, "owner STANDARD: no debt, no wave, no fee")
	_check(_moods(sales) == [70, 70, 70, 70, 70] or _moods(sales).size() == 5, "owner STANDARD: moods untouched")

	# ---- INHERIT A MESSY MSP
	mu.pending_start = "messy"
	c.new_game("tech")
	_drain(cards)
	mu.plan = []
	var m := _moods(sales)
	var angry := 0
	for v in m:
		if v == 28:
			angry += 1
	_check(mu.start_id == "messy" and angry == 2 and m.count(70) == 3, "messy (tech): exactly two angry accounts %s" % str(m))
	_check(is_equal_approx(mu.ticket_rate(), 0.75) and mu.ticket_weights().has("reboot"), "messy (tech): more tickets in the first days")
	c.day = 10
	_check(is_equal_approx(mu.ticket_rate(), 0.75), "messy (tech): still on day 10")
	c.day = 11
	_check(mu.ticket_rate() == 1.0 and mu.ticket_weights().is_empty(), "messy (tech): normal again from day 11")
	_check(mu.pending_start == "standard", "the chip is back to STANDARD after New Game")
	c.day = 1
	var spawned := 0.0
	msp._spawn_t = 0.0
	for i in 1:
		spawned = 1.0
	mu.pending_start = "messy"
	c.new_game("owner")
	_drain(cards)
	mu.plan = []
	var all_debt := true
	for cl in sales.active:
		if float(owner.patch_debt.get(cl, 0.0)) != 6.0:
			all_debt = false
	_check(all_debt and owner.patch_debt.size() == sales.active.size(), "messy (owner): patch debt 6 on every client")
	_check(_moods(sales).count(28) == 2, "messy (owner): two angry accounts")
	_check(owner.poach_risk(sales.active[0]) > risk_std - 0.0001, "messy (owner): poach risk is not lower")
	c.day = 3
	_check(mu.ticket_rate() == 1.0, "messy (owner): the extra tickets end after week 2")
	c.day = 1

	# ---- THE ONLY TECH
	mu.pending_start = "only_tech"
	c.new_game("tech")
	_drain(cards)
	_check(mu.absent() == ["Maya", "Dan"] or mu.absent().size() == 2, "only tech: Maya and Dan are not there yet %s" % str(mu.absent()))
	_check(not world.chars.has("Dan") and not world.chars.has("Maya"), "only tech: neither is at a desk on day 1")
	_check(world.chars.has("Alan") and world.chars.has("Garrison") and world.chars.has("Vic"), "only tech: the owners and Vic are")
	_check(_moods(sales) == std_tech_moods and mu.ticket_rate() == 1.0, "only tech changes nothing else")
	c.day = 3
	world.begin_next_day(3)
	_check(mu.absent() == ["Dan"] and world.chars.has("Maya") and not world.chars.has("Dan"), "only tech: Maya joins on day 3")
	c.day = 5
	world.begin_next_day(5)
	_check(mu.absent().is_empty() and world.chars.has("Dan"), "only tech: Dan joins on day 5")
	mu.pending_start = "only_tech"
	c.new_game("owner")
	_drain(cards)
	_check(mu.start_id == "standard", "only tech is not offered to the owner: it falls back to STANDARD")

	# ---- A RIVAL WANTS YOUR CLIENT
	mu.pending_start = "rival"
	c.new_game("tech")
	_drain(cards)
	var texts := ""
	for t in msp.texts:
		texts += str(t.body)
	_check(texts.contains("rival shop"), "rival (tech): Vic warns you")
	var before := _moods(sales)
	c.day = 2
	mu.begin_day(2)
	_drain(cards)
	var after := _moods(sales)
	var drop := 0
	for i in before.size():
		drop += before[i] - after[i]
	_check(drop == 2, "rival (tech): one client is 2 happier lower after a call (%d)" % drop)
	c.day = 11
	before = _moods(sales)
	mu.begin_day(11)
	_drain(cards)
	_check(_moods(sales) == before, "rival (tech): the calls stop after day 10")
	mu.pending_start = "rival"
	c.new_game("owner")
	_drain(cards)
	_check(owner._poach_wave == 4 and owner.poach_risk(0) > risk_std * 1.9, "rival (owner): the competitor wave runs from week 1 (risk %.3f vs %.3f)" % [owner.poach_risk(0), risk_std])

	# ---- FAMILY BUSINESS
	mu.pending_start = "family"
	c.new_game("owner")
	_drain(cards)
	var cash1: int = owner.cash
	owner.apply({"stack": {"psa": "opsforge"}})
	var fam_cost: int = cash1 - owner.cash
	_check(fam_cost == std_cost + 250, "family: changing the stack costs $250 more (%d vs %d)" % [fam_cost, std_cost])
	cash1 = owner.cash
	owner.apply({"stack": {"psa": "opsforge"}})
	_check(cash1 == owner.cash, "family: choosing the same thing again costs nothing")
	cash1 = owner.cash
	owner.apply({"cash": -100})
	_check(cash1 - owner.cash == 100, "family: other cards are unchanged")
	mu.pending_start = "family"
	c.new_game("tech")
	_drain(cards)
	_check(mu.start_id == "standard", "family is owner-only")

	# ---- save round trip and old saves
	diff.seed_run(11)
	mu.pending_start = "messy"
	c.new_game("tech")
	_drain(cards)
	var moods_saved := _moods(sales)
	c.save()
	mu.start_id = "standard"
	_check(c.continue_game("tech") and mu.start_id == "messy", "the starting condition is saved with the campaign")
	_drain(cards)
	_check(_moods(sales) == moods_saved, "and the angry accounts with it")
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("tech"))
	cfg.erase_section_key("campaign", "mutators")
	cfg.save(c.save_path("tech"))
	_check(c.continue_game("tech") and mu.start_id == "standard", "an old save loads as STANDARD")
	_drain(cards)
	DirAccess.remove_absolute(c.save_path("tech"))
	mu.pending_start = "messy"
	c.new_game("free")
	_check(mu.start_id == "standard", "Free Play ignores the chip")

	# ---- the chip
	var cs: Node = CharSelect.new()
	root.add_child(cs)
	cs.setup("tech")
	_check(mu.pending_start == "standard", "the screen starts on STANDARD")
	cs.change_start(1)
	_check(mu.pending_start == "messy" and cs.summary().ends_with("MESSY MSP"), "the chip moves on and the summary names it")
	cs.change_start(-1)
	cs.change_start(-1)
	_check(mu.pending_start == "rival", "and wraps backwards")
	cs.setup("owner")
	_check(mu.pending_start == "standard", "setup resets it")
	for i in 3:
		cs.change_start(1)
	_check(mu.pending_start == "family", "the owner list ends with FAMILY BUSINESS")
	cs.setup("free")
	cs.change_start(1)
	_check(mu.pending_start == "standard", "Free Play has no chip")
	cs.queue_free()

	# ---- career
	var n: int = career.value("start.messy")
	mu.start_id = "messy"
	mu.note_finish()
	_check(career.value("start.messy") == n + 1, "finishing a campaign counts the start in Career")
	DirAccess.remove_absolute(c.save_prefix + "career.cfg")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
