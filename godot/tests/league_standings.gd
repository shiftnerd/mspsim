extends SceneTree
# R11: after a league night the result shows the season table (pins plus handicaps, best first), the last night too.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var BV: GDScript = load("res://scripts/bowl_variety.gd")
	var league: Dictionary = BV.new_league()
	var night1: Dictionary = BV.record(league, {"You": 120, "Alan": 150, "Dan": 90})
	var st: Array = night1.standing
	var order1: Array = st.map(func(r: Dictionary) -> String: return str(r.who))
	_check(st.size() == 3 and str(st[0].who) == "Alan" and str(st[2].who) == "Dan", "night 1: the table is best first (%s)" % str(order1))
	_check(int(st[0].score) == 150 and int(st[0].games) == 1, "a row has its score and games")
	var night2: Dictionary = BV.record(league, {"You": 160, "Alan": 100, "Dan": 130})
	var order2: Array = night2.standing.map(func(r: Dictionary) -> String: return str(r.who))
	_check(order2.size() == 3 and int(night2.standing[0].score) >= int(night2.standing[1].score), "night 2 is sorted by score (%s)" % str(order2))
	var final: Dictionary = BV.record(league, {"You": 140, "Alan": 120, "Dan": 110})
	var last_ok: bool = bool(final.done) and (final.standing as Array).size() == 3 and str(final.standing[0].who) == str(final.winner)
	_check(last_ok, "the last night still returns the table, and the leader is the winner (%s)" % str(final.winner))
	_check(league.totals.is_empty() and int(league.night) == 0, "while the season itself resets")
	# the line on the result screen
	var o := root.get_node("Outings")
	root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	o.league = BV.new_league()
	o.game = "bowling"
	o.g = {"alley": "league", "totals": {"You": 120, "Alan": 150, "Dan": 90}, "hcp": {}}
	o.lines = []
	o._league_close()
	var found := ""
	for line in o.lines:
		if str(line).begins_with("STANDINGS:"):
			found = str(line)
	var shown: bool = found.begins_with("STANDINGS: 1 ALAN 150") and found.contains("2 YOU 147") and found.contains("3 DAN 144")
	_check(shown, "the result carries the table, pins plus the handicaps: %s" % found)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
