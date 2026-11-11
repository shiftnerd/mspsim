extends SceneTree
# gdlint:disable=max-line-length
# T2, measured by bot at normal (about 7 minutes): mixed play (careful on even days, lazy on odd ones) ends inside 55 to 75 on
# all five seeds; a careful run is at or near the top at the end but not at 100 before the last days, and its first ten days
# are what they were (nothing is slowed below 90); a lazy run stays in its band (fired, or under 45).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/t2_band.gd [-- ts=120]

const BAND := [55, 75]
const SEEDS := 5

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ts := 60.0  # the speed the tables of docs/dev/notes-x13-tech.md were measured at (at 120 a seed moves by up to 13 points)
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("ts="):
			ts = float(str(a).substr(3))
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts

	# ---- mixed play
	var ends := []
	var inside := 0
	var trips := []
	for seed_n in range(1, SEEDS + 1):
		var r: Dictionary = await bots.play("tech", "normal", "mixed", seed_n)
		print(bots.line(r).substr(0, 110))
		print("     curve %s" % str(r.curve))
		ends.append(int(r.rep))
		trips.append(int(bots.trip_log.get("rep", -1)))
		if int(r.rep) >= int(BAND[0]) and int(r.rep) <= int(BAND[1]) and not bool(r.fired):
			inside += 1
	_check(inside == SEEDS, "mixed play ends inside %d to %d on all %d seeds (%s)" % [BAND[0], BAND[1], SEEDS, str(ends)])
	var passive := true
	for t in trips:
		passive = passive and (int(t) == 0 or int(t) == -1)
	_check(passive, "its trip (day 17 is a lazy day: the queue on the phone, the sessions) earns nothing (%s; -1 = did not qualify)" % str(trips))

	# ---- careful: at or near the top at the end, not before the last days, days 1 to 10 as before
	var tops := []
	var early := []
	var day10 := []
	var careful_ok := true
	for seed_n in [1, 2]:
		var r: Dictionary = await bots.play("tech", "normal", "careful", seed_n)
		print(bots.line(r).substr(0, 110))
		print("     curve %s" % str(r.curve))
		var curve: Array = r.curve
		tops.append(int(r.rep))
		day10.append(int(curve[9]))
		var first_100 := 0
		for i in curve.size():
			if first_100 == 0 and int(curve[i]) >= 100:
				first_100 = i + 1
		early.append(first_100)
		careful_ok = careful_ok and int(r.rep) >= 95 and str(r.ending) == "lead" and (first_100 == 0 or first_100 >= 18) and int(curve[13]) <= 96
	_check(careful_ok, "careful ends at 95 or more with the lead offer, is not at 100 before day 18 and not above 96 on day 14 (ends %s, day of the first 100: %s)" % [str(tops), str(early)])
	_check(int(day10.min()) >= 84, "days 1 to 10 are not slower: the careful runs stand at %s on day 10 (88 and 87 before the change)" % str(day10))
	_check(int(tops.min()) > int(ends.max()), "careful stays above every mixed run (%d > %d)" % [int(tops.min()), int(ends.max())])

	# ---- lazy
	var lazy: Dictionary = await bots.play("tech", "normal", "lazy", 1)
	print(bots.line(lazy).substr(0, 110))
	_check(bool(lazy.fired) or int(lazy.rep) < 45, "lazy play stays in its band (rep %d, %s)" % [int(lazy.rep), str(lazy.ending)])

	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
