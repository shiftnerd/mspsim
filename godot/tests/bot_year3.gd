extends SceneTree
# gdlint:disable=max-line-length
# Dev tool (R10, not a test): can a careful bot finish Year 3 (or Year 2) without being fired? One campaign per process:
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_year3.gd -- tech normal careful seeds=3 [first=1] [ts=20] [year=3]
# (owner at ts=4 or lower: the owner bot answers per frame and loses weeks at a higher compression.)
# Every run starts as START YEAR <n> from the record tests/bot_lib.gd `_seed_year` writes (a decent finished year before:
# reputation 70, skills at 3). Prints the usual BOT line plus the year, the beat answers and the review's
# offers, then a YEAR3 summary. Exits 1 when a careful run is fired or times out, when the run did not start in the asked
# year, or when a beat of the year never fired.


func _init() -> void:
	var mode := "tech"
	var tier := "normal"
	var strat := "careful"
	var seeds := 3
	var first := 1
	var ts := 20.0
	var year := 3
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("seeds="):
			seeds = int(s.substr(6))
		elif s.begins_with("first="):
			first = int(s.substr(6))
		elif s.begins_with("ts="):
			ts = float(s.substr(3))
		elif s.begins_with("year="):
			year = int(s.substr(5))
		elif s in ["tech", "owner", "sales", "service"]:
			mode = s
		elif s in ["easy", "normal", "hard"]:
			tier = s
		else:
			strat = s
	await process_frame
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts
	bots.year = year
	var y := root.get_node("Yeartwo")
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	var review := root.get_node("Review")
	var failed := false
	var fired := 0
	var rep := 0.0
	var offered := 0
	for k in seeds:
		var r: Dictionary = await bots.play(mode, tier, strat, first + k)
		var bucket := "y%d" % clampi(year, 2, 3)
		var flags: Dictionary = story.flags.get(bucket, {})
		# (the sales bot goes back to the title when it is done, which resets Campaign.year: its beat answers say which year ran)
		var ran_year: int = c.year if c.active else (year if not flags.is_empty() else 1)
		var beats: Dictionary = ((y.YEAR3 if year >= 3 else y.YEAR2).beats as Dictionary).get(mode, {})
		var was_fired := bool(r.get("fired", false)) or str(r.get("ending", "")) in ["FIRED", "TIMEOUT"]
		var offers: Array = []
		if not was_fired:
			for o in review.offers:
				offers.append(str(o.id))
		var extra: Array = offers.filter(func(id: String) -> bool: return y.is_year2_ending(id))
		print("%s | year %d beats %s offers %s" % [bots.line(r), ran_year, str(flags), str(offers)])
		rep += float(r.get("rep", r.get("conf", c.rep)))
		if was_fired:
			fired += 1
		if not extra.is_empty():
			offered += 1
		if ran_year != year:
			print("FAIL the run was a year %d, not %d" % [ran_year, year])
			failed = true
		if not was_fired and flags.size() < beats.size():
			print("FAIL only %d of %d beats fired" % [flags.size(), beats.size()])
			failed = true
		if was_fired and strat == "careful":
			print("FAIL a careful bot did not finish year %d (%s)" % [year, str(r.get("ending", ""))])
			failed = true
	print("YEAR%d %s %s %s: n %d fired %d rep %.1f, a year-%d ending offered in %d" % [year, mode, tier, strat, seeds, fired, rep / float(maxi(1, seeds)), year, offered])
	quit(1 if failed else 0)
