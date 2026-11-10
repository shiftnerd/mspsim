extends SceneTree
# gdlint:disable=max-line-length
# R9 leftovers: the cash_mult hook (Mutators.cash scales money coming in, neutral with no mutator), the three
# owner-only mutators (GOOD QUARTER, PRICE WAR, SUMMER LULL: valid rows, only dealt into a Year 2 plan so a first year
# is dealt exactly as before), and the owner's week actually collecting more or less under them.
# (The Free Play menu entry for the mutator chooser is in tests/controls_pad.gd.)
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/mutators_r9.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 60:
		var idx := 0
		for i in cards.options.size():
			if bool(cards.options[i].get("enabled", true)):
				idx = i
				break
		cards.pick(idx)
		n += 1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var mu := root.get_node("Mutators")
	var d := root.get_node("Difficulty")
	var owner := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var game := root.get_node("Game")
	var pid := OS.get_process_id()
	c.save_prefix = "user://test_%d_mutr9_" % pid
	d.settings_path = "user://test_%d_mutr9_settings.cfg" % pid
	game.title_mode = false
	var fresh := ["good_quarter", "price_war", "summer_lull"]
	# ---- the rows
	_check(mu.validate_all().is_empty(), "every mutator row is valid: %s" % str(mu.validate_all()))
	_check(mu.SCHEMA.has("cash_mult"), "cash_mult is a known hook")
	for id in fresh:
		var m: Dictionary = mu.MUTATORS.get(id, {})
		_check(not m.is_empty() and m.kinds == ["owner"] and bool(m.get("year2", false)), "%s: an owner-only, Year 2 row" % id)
		_check(mu.ids_for("owner").has(id) and not mu.ids_for("tech").has(id), "%s: listed for the owner campaign only" % id)
	# ---- a first year never draws them: the same seed gives the same plan as the old pool would
	c.new_game("owner")
	_drain(cards)
	_check(not root.get_node("Yeartwo").active(), "a new owner run is a first year")
	for id in fresh:
		_check(not mu.plan_ids("owner").has(id), "%s is not in a first year's pool" % id)
	var seen := {}
	for seed_i in 40:
		d.seed_run(1000 + seed_i)
		for tier in ["easy", "normal", "hard"]:
			for e in mu.make_plan("owner", tier):
				seen[str(e.id)] = true
	var leaked := false
	for id in fresh:
		leaked = leaked or seen.has(id)
	_check(not leaked and seen.size() >= 4, "120 first-year owner plans never hold one (%d different mutators dealt)" % seen.size())
	# ---- Year 2 deals them
	c.year = 2
	_check(root.get_node("Yeartwo").active() and mu.plan_ids("owner").has("price_war"), "Year 2: they join the pool")
	seen = {}
	for seed_i in 60:
		d.seed_run(2000 + seed_i)
		for e in mu.make_plan("owner", "normal"):
			seen[str(e.id)] = true
	var dealt := 0
	for id in fresh:
		dealt += 1 if seen.has(id) else 0
	_check(dealt == 3, "60 Year 2 owner plans deal all three (%d)" % dealt)
	c.year = 1
	# ---- the cash hook
	mu.plan = []
	_check(mu.cash(1000) == 1000 and mu.cash(-400) == -400 and mu.cash(0) == 0, "no mutator: cash is untouched")
	var now: int = c.day
	mu.plan = [{"id": "good_quarter", "from": 1, "to": 99}]
	_check(mu.current_id() == "good_quarter", "GOOD QUARTER is on (day %d)" % now)
	_check(mu.cash(1000) == 1150 and mu.cash(-400) == -400, "GOOD QUARTER: income x1.15, money going out is not scaled")
	mu.plan = [{"id": "price_war", "from": 1, "to": 99}]
	_check(mu.cash(1000) == 900 and float(mu.hook("price_pressure", 0.0)) > 0.0, "PRICE WAR: income x0.9 and poach pressure")
	mu.plan = [{"id": "summer_lull", "from": 1, "to": 99}]
	_check(mu.cash(1000) == 1000 and int(mu.hook("pay_delay", 0)) == 1 and float(mu.hook("lead_mult", 1.0)) < 1.0, "SUMMER LULL: fewer leads, late invoices, cash itself untouched")
	# ---- the owner's week collects through the hook: the same week three times from the same state
	var results := {}
	for id in ["", "good_quarter", "price_war"]:
		d.seed_run(4242)
		c.new_game("owner")
		_drain(cards)
		mu.plan = [] if id == "" else [{"id": id, "from": 1, "to": 99}]
		var before: int = owner.cash
		owner.settle()
		_drain(cards)
		results[id] = int(owner.cash) - before
	_check(results["good_quarter"] > results[""] and results["price_war"] < results[""], "an owner week banks more in a GOOD QUARTER and less in a PRICE WAR (%s)" % str(results))
	mu.plan = []
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
