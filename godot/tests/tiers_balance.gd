extends SceneTree
# gdlint:disable=max-line-length
# Q6 smoke test: three campaigns (sales, tech, service) with a careful and a lazy bot at easy / normal / hard, one or two seeds,
# time compressed (about 4 minutes in all). Asserts the ordering the tiers must keep:
#   careful: easy >= normal >= hard (by reputation, and by the share of good endings)
#   careful > lazy on every tier
#   normal is unchanged by the tier machinery (Difficulty.cf is 1.0 / 0.0 outside a campaign)
# The owner campaign is too slow for a smoke test: tests/bot_run.gd -- owner ... covers it (docs/balance-notes.md).
# Full distributions: tests/bot_run.gd, one cell per process.

var failures := 0
var rows := {}  # "mode tier strategy" -> Array of rows


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _avg(mode: String, tier: String, strat: String, key: String) -> float:
	var list: Array = rows.get("%s %s %s" % [mode, tier, strat], [])
	var t := 0.0
	for r in list:
		t += float(r[key])
	return t / float(maxi(1, list.size()))


func _good(mode: String, tier: String, strat: String) -> float:
	var list: Array = rows.get("%s %s %s" % [mode, tier, strat], [])
	var n := 0
	for r in list:
		n += 1 if r.cls == "good" else 0
	return float(n) / float(maxi(1, list.size()))


func _init() -> void:
	await process_frame
	var d := root.get_node("Difficulty")
	# outside a campaign the new dials read as normal, whatever the tier
	d.set_tier("hard")
	_check(is_equal_approx(d.cf("tech.pace"), 1.0) and is_equal_approx(d.cf("rep.loss"), 1.0) and d.cf("sales.lead") == 0.0, "campaign dials read normal outside a campaign")
	d.set_tier("normal")
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	var plan := {"sales": [2, 20.0], "tech": [1, 120.0], "service": [1, 40.0]}
	for mode in plan:
		bots.ts = float(plan[mode][1])
		for tier in ["easy", "normal", "hard"]:
			for strat in ["careful", "lazy"]:
				var key := "%s %s %s" % [mode, tier, strat]
				rows[key] = []
				for k in int(plan[mode][0]):
					var r: Dictionary = await bots.play(mode, tier, strat, 11 + k)
					rows[key].append(r)
					print(bots.line(r))
		_check(_avg(mode, "easy", "careful", "rep") >= _avg(mode, "normal", "careful", "rep") - 0.5, "%s careful: easy >= normal (rep)" % mode)
		_check(_avg(mode, "normal", "careful", "rep") >= _avg(mode, "hard", "careful", "rep") - 0.5, "%s careful: normal >= hard (rep)" % mode)
		_check(_good(mode, "easy", "careful") >= _good(mode, "normal", "careful") and _good(mode, "normal", "careful") >= _good(mode, "hard", "careful"), "%s careful: good endings easy >= normal >= hard" % mode)
		if mode == "tech":  # Q6b: tech hard has its own pressure (paired incidents, faster drain), so it must now cost the careful bot
			_check(_avg("tech", "hard", "careful", "rep") < _avg("tech", "normal", "careful", "rep"), "tech careful: hard rep < normal rep (%.0f vs %.0f)" % [_avg("tech", "hard", "careful", "rep"), _avg("tech", "normal", "careful", "rep")])
		for tier in ["easy", "normal", "hard"]:
			_check(_avg(mode, tier, "careful", "rep") > _avg(mode, tier, "lazy", "rep"), "%s %s: careful beats lazy (%.0f vs %.0f)" % [mode, tier, _avg(mode, tier, "careful", "rep"), _avg(mode, tier, "lazy", "rep")])
	root.get_node("Campaign").quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
