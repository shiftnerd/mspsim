extends SceneTree
# gdlint:disable=max-line-length
# Dev tool (not a test): a bot run with a per-day trace of the decisions put in front of the player, standing in for the "manual
# replay" and "hand-played pacing pass" rows of the roadmap (X9, C7).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_trace.gd -- owner normal careful seeds=3 first=1 ts=4 [year2] [quiet]
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_trace.gd -- service normal careful seeds=5 ts=40
# Per run: the BOT line, one DAY line per day (week in the owner campaign) with the cards answered that day, and for the owner
# campaign the bank, reputation, partner trust and company value at each week's report. Then the checks, as FLAG lines:
#   dead      a day (week) without a single decision card (DEAD_OK lists the modes where that is normal)
#   gap       the longest stretch of game hours between two decisions, when over GAP_HOURS working hours
#   repeat    the same decision shown more than REPEAT_OK times in one run
# A decision is a card with two or more answers; a card with one (an answer's reply, a notice) is counted as a notice only.
#   runaway   owner only: cash or company value more than RUNAWAY x the week before (and over a floor), or a value that leaves
#             the sane range
# and a SUMMARY line per cell. Exit code 1 when a run was flagged "runaway" or a campaign day had no decision in a mode that
# promises one a day; the other flags are for reading.

const GAP_HOURS := {"tech": 12.0, "service": 9.0, "sales": 12.0, "owner": 9.0}
const REPEAT_OK := {"tech": 6, "service": 3, "sales": 3, "owner": 2}
const DEAD_OK := ["tech"]  # a tech day without a card is a quiet day at the desk: the tickets are the decisions there
const RUNAWAY := 3.0
const VALUE_MAX := 5000000


# the text a repeat is counted by: the opening words without names and numbers (so "Morning. 4 tickets open" is one card)
func _key(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("[0-9$%]+")
	return rx.sub(text, "#", true).substr(0, 34)


# cards that come every morning or every week by design (the huddle, the Friday numbers) are not repeats
func _daily(key: String) -> bool:
	for start in ["Morning. #", "Friday numbers", "Last night"]:
		if key.begins_with(start):
			return true
	return false


func _init() -> void:
	var mode := "owner"
	var tier := "normal"
	var strat := "careful"
	var seeds := 1
	var first := 1
	var ts := 4.0
	var year2 := false
	var quiet := false
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("seeds="):
			seeds = int(s.substr(6))
		elif s.begins_with("first="):
			first = int(s.substr(6))
		elif s.begins_with("ts="):
			ts = float(s.substr(3))
		elif s == "year2":
			year2 = true
		elif s == "quiet":
			quiet = true
		elif s in ["tech", "owner", "sales", "service"]:
			mode = s
		elif s in ["easy", "normal", "hard"]:
			tier = s
		else:
			strat = s
	await process_frame
	var world := root.get_node("World")
	var hours: float = float(world.DAY_END) - float(world.DAY_START)
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts
	var failed := false
	var total_cards := 0
	var total_days := 0
	var total_dead := 0
	var worst_gap := 0.0
	var worst_repeat := 0
	var worst_repeat_text := ""
	var flags := 0
	var notices := 0
	var busiest := 0
	var quietest := 999
	var by_hour := {}  # the hour of the game clock -> decisions (all runs)
	for k in seeds:
		var r: Dictionary
		if year2:
			r = await bots.play_year2(mode, tier, strat, first + k)
		else:
			r = await bots.play(mode, tier, strat, first + k)
		print(bots.line(r))
		var cards: Array = r.get("cards", [])
		var last_day := 0
		var by_day := {}
		var counts := {}
		var prev_t := 0.0
		var gap := 0.0
		var gap_at := ""
		for c in cards:
			var d := int(c.day)
			last_day = maxi(last_day, d)
			if int(c.get("n", 2)) < 2:
				notices += 1
				continue
			if not by_day.has(d):
				by_day[d] = []
			by_day[d].append("%s: %s -> %s" % [str(c.who), str(c.text).substr(0, 30), str(c.pick)])
			var key := _key(str(c.text))
			var hour := clampi(int(float(c.clock)), 0, 23)
			by_hour[hour] = int(by_hour.get(hour, 0)) + 1
			counts[key] = int(counts.get(key, 0)) + 1
			var t := float(d - 1) * hours + clampf(float(c.clock) - float(world.DAY_START), 0.0, hours)
			if t - prev_t > gap:
				gap = t - prev_t
				gap_at = "day %d" % d
			prev_t = t
		last_day = maxi(last_day, int(r.get("week", r.get("last_day", last_day))))
		var weeks: Array = r.get("weeks", [])
		var dead := []
		for d in range(1, last_day + 1):
			var list: Array = by_day.get(d, [])
			if list.is_empty():
				dead.append(d)
			if not quiet:
				var money := ""
				if d - 1 < weeks.size():
					var w: Dictionary = weeks[d - 1]
					money = " cash %d rep %d trust %d value %d clients %d |" % [int(w.cash), int(w.rep), int(w.trust), int(w.value), int(w.clients)]
				print("DAY %2d:%s %d cards | %s" % [d, money, list.size(), " ; ".join(list)])
		for d in range(1, last_day + 1):
			var n_day: int = by_day.get(d, []).size()
			total_cards += n_day
			busiest = maxi(busiest, n_day)
			quietest = mini(quietest, n_day)
		total_days += last_day
		total_dead += dead.size()
		worst_gap = maxf(worst_gap, gap)
		if not dead.is_empty():
			print("FLAG dead: seed %d, no decision on day(s) %s" % [first + k, str(dead)])
			flags += 1
			if not (mode in DEAD_OK):
				failed = failed or dead.size() > 2
		if gap > float(GAP_HOURS[mode]):
			print("FLAG gap: seed %d, %.1f working hours without a decision (ending %s)" % [first + k, gap, gap_at])
			flags += 1
		for key in counts:
			if int(counts[key]) > worst_repeat:
				worst_repeat = int(counts[key])
				worst_repeat_text = str(key)
			if int(counts[key]) > int(REPEAT_OK[mode]) and not _daily(str(key)):
				print("FLAG repeat: seed %d, %d x \"%s\"" % [first + k, int(counts[key]), str(key)])
				flags += 1
		for i in range(1, weeks.size()):
			var a: Dictionary = weeks[i - 1]
			var b: Dictionary = weeks[i]
			if int(b.value) > VALUE_MAX or (int(a.value) > 50000 and float(b.value) > RUNAWAY * float(a.value)) or (int(a.cash) > 5000 and float(b.cash) > RUNAWAY * float(a.cash)):
				print("FLAG runaway: seed %d week %d: cash %d -> %d, value %d -> %d" % [first + k, int(b.week), int(a.cash), int(b.cash), int(a.value), int(b.value)])
				flags += 1
				failed = true
	var hours: Array = by_hour.keys()
	hours.sort()
	var spread := []
	for h in hours:
		spread.append("%02d:00 %d" % [int(h), int(by_hour[h])])
	print("HOURS %s %s %s: decisions by the hour of the game clock: %s" % [mode, tier, strat, ", ".join(spread)])
	print("QUIETEST %s %s %s: the day with the fewest decisions had %d" % [mode, tier, strat, quietest])
	print("SUMMARY %s %s %s%s: runs %d, decisions per day %.2f (busiest day %d), notices per day %.2f, days without a decision %d of %d, longest gap %.1f h, most repeated decision %d x \"%s\", flags %d" % [mode, tier, strat, " year2" if year2 else "", seeds, float(total_cards) / float(maxi(1, total_days)), busiest, float(notices) / float(maxi(1, total_days)), total_dead, total_days, worst_gap, worst_repeat, worst_repeat_text, flags])
	quit(1 if failed else 0)
