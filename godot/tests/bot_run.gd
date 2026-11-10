extends SceneTree
# gdlint:disable=max-line-length
# Dev tool (Q6, not a test): the slow balance harness. One cell (or a few) per process:
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_run.gd -- tech normal careful seeds=6 [first=1] [ts=20]
# Words: mode (tech owner sales service; "coop" runs the tech bot as a pair), tier (easy normal hard), strategy (careful lazy chaotic shortcut); a word may be
# a comma list ("easy,normal,hard"). Prints one BOT line per run and a CELL summary per mode x tier x strategy.
# "mixed" (tech, service) is careful on even days and lazy on odd ones. The word "year2" plays a year 1 run and then Year 2 on what
# it left (New Game Plus: carry-over, tighter clocks); the BOT line is the Year 2 run, a Y1 line before it is the first year.
# Merge several processes with tools/ (see docs/balance-notes.md) or by eye.
# P5 (the newer owner content: temptations, takeover, the second cast's cards, by-name requests):
#   ... bot_run.gd -- owner normal careful,shortcut seeds=3 ts=4
# The owner "shortcut" strategy is careful's answers with every temptation taken. When both cells run in one process the run FAILS
# unless shortcut ends clearly below careful (mean value under SHORTCUT_MAX of careful's) and is not fired every time.

const SHORTCUT_MAX := 0.8


func _init() -> void:
	var modes: Array = ["tech"]
	var tiers: Array = ["normal"]
	var strats: Array = ["careful"]
	var seeds := 6
	var first := 1
	var ts := 20.0
	var coop := false
	var year2 := false
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("seeds="):
			seeds = int(s.substr(6))
		elif s.begins_with("first="):
			first = int(s.substr(6))
		elif s == "coop":
			coop = true
		elif s == "year2":
			year2 = true
		elif s.begins_with("ts="):
			ts = float(s.substr(3))
		else:
			var parts := s.split(",")
			if parts[0] in ["tech", "owner", "sales", "service"]:
				modes = Array(parts)
			elif parts[0] in ["easy", "normal", "hard"]:
				tiers = Array(parts)
			else:
				strats = Array(parts)
	var failed := false
	var cells := {}  # "mode tier strategy" -> {score, fired, n}
	await process_frame
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts
	bots.coop = coop
	for mode in modes:
		for tier in tiers:
			for strat in strats:
				var rows: Array = []
				for k in seeds:
					var r: Dictionary
					if year2:
						r = await bots.play_year2(str(mode), str(tier), str(strat), first + k)
						if r.has("year1"):
							print("Y1 " + bots.line(r.year1))
					else:
						r = await bots.play(str(mode), str(tier), str(strat), first + k)
					rows.append(r)
					print(bots.line(r))
				var good := 0
				var mid := 0
				var bad := 0
				var rep := 0.0
				var score := 0.0
				var fired := 0
				for r in rows:
					good += 1 if r.cls == "good" else 0
					mid += 1 if r.cls == "mid" else 0
					bad += 1 if r.cls == "bad" else 0
					rep += float(r.rep)
					score += float(r.score)
					fired += 1 if bool(r.fired) else 0
				var n := float(rows.size())
				print("CELL %s %s %s: n=%d good %d mid %d bad %d  rep %.1f score %.1f  fired %d" % [mode, tier, strat, rows.size(), good, mid, bad, rep / n, score / n, fired])
				cells["%s %s %s" % [mode, tier, strat]] = {"score": score / n, "fired": fired, "n": rows.size()}
				if str(tier) == "easy" and fired > 0:  # R16: easy is cozy, nobody is ever fired there
					print("FAIL cozy: %s easy %s was fired %d time(s)" % [mode, strat, fired])
					failed = true
	for tier in tiers:  # P5: the shortcut owner against the careful one
		var careful: Dictionary = cells.get("owner %s careful" % tier, {})
		var shortcut: Dictionary = cells.get("owner %s shortcut" % tier, {})
		if careful.is_empty() or shortcut.is_empty():
			continue
		var ratio := float(shortcut.score) / maxf(1.0, float(careful.score))
		print("CHECK owner %s: shortcut value %.0f vs careful %.0f (%.0f%%), shortcut fired %d of %d" % [tier, float(shortcut.score), float(careful.score), ratio * 100.0, int(shortcut.fired), int(shortcut.n)])
		if ratio >= SHORTCUT_MAX:
			print("FAIL owner %s: the shortcut owner is not clearly worse than the careful one" % tier)
			failed = true
		if int(shortcut.fired) >= int(shortcut.n) and str(tier) != "hard":
			print("FAIL owner %s: the shortcut owner is fired every time (the bills alone should not end the run)" % tier)
			failed = true
	quit(1 if failed else 0)
