extends SceneTree
# Dev tool (Q6, not a test): the slow balance harness. One cell (or a few) per process:
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_run.gd -- tech normal careful seeds=6 [first=1] [ts=20]
# Words: mode (tech owner sales service), tier (easy normal hard), strategy (careful lazy chaotic shortcut); a word may be
# a comma list ("easy,normal,hard"). Prints one BOT line per run and a CELL summary per mode x tier x strategy.
# Merge several processes with tools/ (see docs/balance-notes.md) or by eye.


func _init() -> void:
	var modes: Array = ["tech"]
	var tiers: Array = ["normal"]
	var strats: Array = ["careful"]
	var seeds := 6
	var first := 1
	var ts := 20.0
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("seeds="):
			seeds = int(s.substr(6))
		elif s.begins_with("first="):
			first = int(s.substr(6))
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
	await process_frame
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts
	for mode in modes:
		for tier in tiers:
			for strat in strats:
				var rows: Array = []
				for k in seeds:
					var r: Dictionary = await bots.play(str(mode), str(tier), str(strat), first + k)
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
				if str(tier) == "easy" and fired > 0:  # R16: easy is cozy, nobody is ever fired there
					print("FAIL cozy: %s easy %s was fired %d time(s)" % [mode, strat, fired])
					failed = true
	quit(1 if failed else 0)
