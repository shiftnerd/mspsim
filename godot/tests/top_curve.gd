extends SceneTree
# gdlint:disable=max-line-length
# T2: the top of the tech campaign's reputation curve. A careful run stood at 100 on day 13 or 14 (the curve was drawn to end
# near 98 on day 20): every thank-you, by-name close and job grade was worth a whole point however high you stood, and a clean
# day another. From Campaign.TOP_REP (90) gains are banked as fractions (Campaign.rep_bank) and only whole points count; from
# TOP_LATE_REP (95) a little slower still. Below 90 nothing changes, losses are never slowed, other campaigns are not touched.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/top_curve.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1


# how many gains of `amount` it takes from `rep` (empty bank) to the next point
func _gains_for_a_point(c: Node, rep: int, amount: int) -> int:
	c.rep = rep
	c.rep_bank = 0.0
	var n := 0
	while c.rep == rep and n < 200:
		c.adjust_rep(amount)
		n += 1
	return n


# how many day reports of +`delta` it takes from `rep` to the next point
func _days_for_a_point(c: Node, rep: int, delta: int) -> int:
	c.rep = rep
	c.rep_bank = 0.0
	var n := 0
	while c.rep == rep and n < 200:
		var r := {"rep_delta": delta}
		c.top_report(r)
		c.rep += int(r.rep_delta)
		n += 1
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var d := root.get_node("Difficulty")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_topcurve_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Career").toasts = false
	d.seed_run(5)
	c.new_game("tech")
	d.set_tier("normal")
	_drain(cards)
	world.time_scale = 0.0

	# ---- below the top nothing changed: the scale of before, with its floor of one point
	var same := true
	for rep in [50, 59, 60, 71, 72, 84, 85, 89]:
		for amount in [1, 3, 5]:
			c.rep = rep
			c.rep_bank = 0.0
			c.adjust_rep(amount)
			var want: int = maxi(1, roundi(float(amount) * (0.25 if rep >= 85 else (0.3 if rep >= 72 else (0.6 if rep >= 60 else 1.0)))))
			same = same and c.rep == rep + want and c.rep_bank == 0.0
	_check(same, "below %d a gain is what it was (scaled, never less than a point), and nothing is banked" % c.TOP_REP)
	for rep in [50, 72, 89]:
		var r := {"rep_delta": 1}
		c.rep = rep
		c.rep_bank = 0.0
		c.top_report(r)
		same = same and int(r.rep_delta) == 1 and not r.has("notes")
	_check(same, "and a day report's gain is untouched")

	# ---- at the top: fractions
	c.rep = c.TOP_REP
	c.rep_bank = 0.0
	c.adjust_rep(1)
	_check(c.rep == c.TOP_REP and c.rep_bank > 0.1 and c.rep_bank < 0.15, "at %d a +1 is an eighth of a point in the bank (%.3f), not a point" % [c.TOP_REP, c.rep_bank])
	var small: int = _gains_for_a_point(c, 90, 1)
	var big: int = _gains_for_a_point(c, 90, 5)
	var late_small: int = _gains_for_a_point(c, 96, 1)
	var late_big: int = _gains_for_a_point(c, 96, 5)
	print("     gains for one point: +1 x%d and +5 x%d at 90, +1 x%d and +5 x%d at 96" % [small, big, late_small, late_big])
	_check(small == 8 and big == 2, "eight thank-yous or two S-grade jobs for a point at 90 (%d, %d)" % [small, big])
	_check(late_small > small and late_big > big and late_small <= 14, "slower again from %d (%d thank-yous, %d jobs)" % [c.TOP_LATE_REP, late_small, late_big])
	var days: int = _days_for_a_point(c, 91, 1)
	var late_days: int = _days_for_a_point(c, 96, 1)
	print("     clean days for one point: %d at 91, %d at 96" % [days, late_days])
	_check(days == 2 and late_days >= 3 and late_days <= 5, "two clean days for a point at 91, three to five at 96 (%d, %d)" % [days, late_days])
	# the report says why it shows +0
	c.rep = 92
	c.rep_bank = 0.0
	var quiet := {"rep_delta": 1}
	c.top_report(quiet)
	_check(int(quiet.rep_delta) == 0 and quiet.get("notes", []) == [c.TOP_NOTE], "a clean day that is not a whole point yet shows +0 and a line (%s)" % str(quiet.get("notes", [])))
	var whole := {"rep_delta": 1}
	c.top_report(whole)
	_check(int(whole.rep_delta) == 1 and not whole.has("notes"), "the next one brings the point, without the line")
	_check(str(c.TOP_NOTE).length() <= 46, "the line is no longer than the sloppy-day note")

	# ---- losses are never slowed, and do not touch the bank
	c.rep = 96
	c.rep_bank = 0.5
	c.adjust_rep(-3)
	_check(c.rep == 93 and is_equal_approx(c.rep_bank, 0.5), "a loss at 96 is a loss in full (%d)" % c.rep)
	var bad := {"rep_delta": -4}
	c.top_report(bad)
	_check(int(bad.rep_delta) == -4, "a bad day's report too")

	# ---- the ceiling still holds, and 100 can be reached
	c.rep = 99
	c.rep_bank = 0.95
	c.adjust_rep(5)
	_check(c.rep == 100, "the last point is reachable (%d)" % c.rep)
	c.adjust_rep(5)
	_check(c.rep == 100, "and 100 is the end")
	c.scars = 5
	c.rep = 95
	c.rep_bank = 0.99
	c.adjust_rep(5)
	_check(c.rep == 95, "a scarred ceiling (95) still stops it")
	c.scars = 0

	# ---- twenty days of a careful tech from 90 on day 12: not at 100 before the last days
	# (a clean day report, one job grade every other day and three small thank-yous a day: what the careful bot's days hold)
	c.rep = 90
	c.rep_bank = 0.0
	var by_day := []
	for day in range(12, 21):
		for k in 3:
			c.adjust_rep(1)
		if day % 2 == 0:
			c.adjust_rep(5)
		var r := {"rep_delta": 1}
		c.top_report(r)
		c.rep = mini(100, c.rep + int(r.rep_delta))
		by_day.append(c.rep)
	print("     a model careful run from 90 on day 12: %s" % str(by_day))
	_check(int(by_day[2]) <= 95 and int(by_day.back()) >= 95 and int(by_day[by_day.size() - 4]) < 100, "it is in the high 90s at the end, and not at 100 by day 14 or 17 (%s)" % str(by_day))

	# ---- the bank is in the save
	c.day = 14
	c.rep = 93
	c.rep_bank = 0.75
	c.save()
	c.rep_bank = 0.0
	_check(c.continue_game("tech") and is_equal_approx(c.rep_bank, 0.75) and c.rep == 93, "the bank is saved and loaded (%.2f)" % c.rep_bank)
	_drain(cards)
	c.new_game("tech")
	_drain(cards)
	_check(c.rep_bank == 0.0, "a new game starts with an empty bank")

	# ---- the tiers of the tech campaign share it; the other campaigns do not have it
	d.set_tier("hard")
	c.rep = 92
	c.rep_bank = 0.0
	c.adjust_rep(1)
	_check(c.rep == 92 and c.rep_bank > 0.0, "tech hard: the same top")
	d.set_tier("easy")
	c.rep = 92
	c.rep_bank = 0.0
	c.adjust_rep(1)
	var easy_day := {"rep_delta": 1}
	c.top_report(easy_day)
	_check(d.cozy_on() and c.rep == 93 and c.rep_bank == 0.0 and int(easy_day.rep_delta) == 1, "cozy Easy keeps its gentle climb: a gain at 92 is a point")
	d.set_tier("normal")
	for mode in ["owner", "service", "sales"]:
		c.new_game(mode)
		_drain(cards)
		c.rep = 92
		c.adjust_rep(1)
		var r := {"rep_delta": 1}
		c.top_report(r)
		_check(c.rep == 93 and c.rep_bank == 0.0 and int(r.rep_delta) == 1, "%s campaign: a gain at 92 is a point, as before" % mode)

	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
