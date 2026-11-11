extends SceneTree
# gdlint:disable=max-line-length
# T2: what the conference trip does for your reputation. It was a flat +3 for anyone who went (the three sessions cannot be
# skipped, so "three sessions" was always true). Now it is what you did there (Expo.trip_effort: the keynote listened to, the
# sessions, two booths or pitches, two people talked to) and where you stand (a point less from 65, one at most from 80); a
# passive trip earns nothing and the report says so. And a trip day that ends without the closing raffle (a bot) still brings
# the ticket stream back the next morning.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/trip_rep.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node, want := "") -> void:
	var n := 0
	while cards.is_open and n < 20:
		var pick := 0
		for i in cards.options.size():
			if str(cards.options[i].get("id", "")) == want:
				pick = i
		cards.pick(pick)
		n += 1


# a trip with `effort` things done, set the way the venue sets them
func _trip(expo: Node, effort: int) -> void:
	expo.listened = effort >= 2
	expo.picks = ["a", "b", "c"] if effort >= 1 else []
	expo._booths = {"x": true, "y": true} if effort >= 3 else {}
	expo._met = {}
	expo._talked = {0: true, 1: true} if effort >= 4 else {}


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var expo := root.get_node("Expo")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var d := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_triprep_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Career").toasts = false
	d.seed_run(3)
	c.new_game("tech")
	d.set_tier("normal")
	_drain(cards)
	world.time_scale = 0.0

	# ---- the table: effort x standing
	var rows := []
	var table := {}
	for rep in [50, 64, 65, 79, 80, 95]:
		c.rep = rep
		var row := []
		for effort in 5:
			_trip(expo, effort)
			row.append(expo.trip_rep())
		table[rep] = row
		rows.append("rep %d: %s" % [rep, str(row)])
	print("     trip reputation by effort 0..4: " + "; ".join(rows))
	_check(table[50] == [0, 0, 1, 2, 3], "below 65: nothing for a passive trip, up to +3 for a full one (%s)" % str(table[50]))
	_check(table[64] == table[50], "64 is still below the line")
	_check(table[65] == [0, 0, 0, 1, 2] and table[79] == table[65], "from 65 a point less (%s)" % str(table[65]))
	_check(table[80] == [0, 0, 0, 1, 1] and table[95] == table[80], "from 80 one point at most (%s)" % str(table[80]))
	var never_more := true
	for rep in table:
		for effort in 5:
			never_more = never_more and int(table[rep][effort]) <= 3 and (effort == 0 or int(table[rep][effort]) >= int(table[rep][effort - 1]))
	_check(never_more, "never more than the old flat +3, and more effort is never worth less")

	# ---- what counts as effort
	_trip(expo, 0)
	_check(expo.trip_effort() == 0, "you went and did nothing: 0")
	expo.picks = ["a", "b", "c"]
	_check(expo.trip_effort() == 1 and expo.trip_rep() == 0, "the three sessions alone (they cannot be skipped) are a passive trip: +0")
	expo.picks = ["a", "b"]
	_check(expo.trip_effort() == 0, "two sessions are not the whole programme")
	expo.picks = ["a", "b", "c"]
	expo._booths = {"x": true}
	expo._met = {"backup": true}
	_check(expo.trip_effort() == 2, "a booth and a vendor pitch count as two stops")
	expo._talked = {0: true, "forum:x": true}
	_check(expo.trip_effort() == 3, "an attendee and a forum regular are two people")

	# ---- the keynote: listening is remembered, the phone is not
	expo.reset()
	expo.qualified = true
	c.day = expo.TRIP_DAY
	expo.away = true  # the trip day as Expo._on_day sets it up (without the flight: no venue scene in this test)
	expo.went = true
	expo._stage = "keynote"
	msp.enabled = false
	_check(expo.is_trip_day(expo.TRIP_DAY) and not expo.listened, "the trip day: away, tickets off, nothing heard yet")
	expo._keynote()
	_drain(cards, "listen")
	_check(expo.listened and not expo.peeked, "LISTEN TO THE KEYNOTE counts")
	expo.listened = false
	expo._keynote()
	_drain(cards, "peek")
	_check(not expo.listened and expo.peeked, "CHECK THE QUEUE ON YOUR PHONE does not")

	# ---- the day report of the trip day
	c.rep = 60
	_trip(expo, 4)
	var r: Dictionary = c.make_report()
	_check(int(r.rep_delta) == 3 and not r.has("notes"), "a full trip at 60: the report adds 3 (%d)" % int(r.rep_delta))
	_trip(expo, 1)
	r = c.make_report()
	_check(int(r.rep_delta) == 0 and str(r.notes[0]) == str(expo.TEXT.trip_quiet), "a passive trip: +0 and the report says why (%s)" % str(r.get("notes", [])))
	c.rep = 70
	_trip(expo, 2)
	r = c.make_report()
	_check(int(r.rep_delta) == 0 and str(r.notes[0]) == str(expo.TEXT.trip_known), "a fair trip at 70: +0, with the other line (%s)" % str(r.get("notes", [])))
	_check(str(expo.TEXT.trip_quiet).length() <= 46 and str(expo.TEXT.trip_known).length() <= 46, "both lines are no longer than the sloppy-day note (the report row fits)")

	# ---- the morning after a trip that never reached the raffle: the tickets are back
	expo._stage = "round"
	msp.enabled = false
	c.day = expo.TRIP_DAY + 1
	expo._on_day(expo.TRIP_DAY + 1)
	_drain(cards)
	_check(msp.enabled and not expo.away and str(expo._stage) == "done", "day 18 after an unfinished trip: the ticket stream is on again")
	# a trip that ended at the raffle is left alone
	expo._stage = "done"
	msp.enabled = true
	expo._on_day(expo.TRIP_DAY + 1)
	_drain(cards)
	_check(msp.enabled, "after a finished trip nothing changes")

	# ---- no trip, no change: an ordinary day's report is the campaign's own
	expo.reset()
	c.day = 5
	c.rep = 50
	r = c.make_report()
	_check(not r.has("notes") or not (str(expo.TEXT.trip_quiet) in r.notes), "an ordinary day has no trip line")

	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
