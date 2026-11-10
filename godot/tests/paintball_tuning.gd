extends SceneTree
# gdlint:disable=max-line-length
# PAINTBALL TUNING (roadmap R41): the bot run that stands in for a human play-test. A scripted average player (tests/bot_paint.gd:
# human reaction times, the keys' own calls) plays unit 0 against the crew, SEEDS seeded matches per tier, by day and by night.
# It prints the table (win / draw / loss, match length, captures, your own captures and tags) and fails when a tier is lopsided:
# normal 45 to 65 % wins, easy easier than normal, hard harder, every match ends, and a flag gets carried home in most of them.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/paintball_tuning.gd [-- --seeds=200]

const PB := preload("res://scripts/paintball_game.gd")
const BotPaint := preload("res://tests/bot_paint.gd")
const STEP := 1.0 / 30.0  # the rules at 30 steps a second (the game runs them at 60; the timers in them are 0.3 s and up)
const TIERS := ["easy", "normal", "hard"]
# -- --sweep rows: [your aim x, crew aim, rival edge, captures to win, seconds, carrier dodge beat, respawn, carry speed x]
const SWEEP := [[1.0, 0.18, 2.0, 3, 150.0, 0.8, 4.0, 1.0], [1.0, 0.18, 2.6, 3, 150.0, 0.8, 4.0, 1.0], [1.0, 0.18, 3.2, 3, 150.0, 0.8, 4.0, 1.0], [1.0, 0.18, 1.0, 3, 150.0, 99.0, 4.0, 0.85]]

var fails := 0
var seeds := 30
var full := false  # -- --full: night on easy and hard too (the default run leaves those two rows out to stay under a minute)
var sweep := false  # -- --sweep: the normal tier over a range of crew aim, captures to win and clock lengths (the tuning itself)


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.substr(8))
		elif arg == "--sweep":
			sweep = true
		elif arg == "--full":
			full = true
	_run.call_deferred()


# one match; returns {winner, secs, caps: [a, b], you_caps, you_tags, ended}
func _match(p: Dictionary, seed_n: int, humans := 1) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n * 7919 + 13
	var g: RefCounted = PB.new()
	g.setup(p, ["Alan", "Garrison", "Dan", "Maya", "John"], r, humans)
	g.count = 0.0
	var bots := []
	for k in humans:
		bots.append(BotPaint.new(seed_n * 31 + k))
	var steps := 0
	while g.phase != "over" and steps < 30 * 400:
		for k in humans:
			bots[k].drive(g, k, STEP)
		g.step(STEP)
		steps += 1
	return {"winner": g.winner, "secs": g.clock, "caps": g.score.duplicate(), "you_caps": g.you_caps, "you_tags": g.you_tags, "ended": g.phase == "over", "p2": g.p2_caps + g.p2_tags}


func _table(label: String, p: Dictionary, humans := 1) -> Dictionary:
	var w := [0, 0, 0]
	var secs := 0.0
	var caps := 0
	var mine := 0
	var tags := 0
	var ended := 0
	var with_cap := 0
	var p2 := 0
	for s in range(1, seeds + 1):
		var m := _match(p, s, humans)
		if bool(m.ended):
			ended += 1
			w[int(m.winner)] += 1
		secs += float(m.secs)
		caps += int(m.caps[0]) + int(m.caps[1])
		mine += int(m.you_caps)
		tags += int(m.you_tags)
		p2 += int(m.p2)
		if int(m.caps[0]) + int(m.caps[1]) > 0:
			with_cap += 1
	var n := float(seeds)
	var row := {"win": w[0] / n, "loss": w[1] / n, "draw": w[2] / n, "secs": secs / n, "caps": caps / n, "mine": mine / n, "tags": tags / n, "ended": ended, "with_cap": with_cap / n, "p2": p2 / n}
	print("| %s | %d %% | %d %% | %d %% | %d s | %.1f | %.2f | %.1f |" % [label, roundi(row.win * 100.0), roundi(row.draw * 100.0), roundi(row.loss * 100.0), roundi(row.secs), row.caps, row.mine, row.tags])
	return row


func _run() -> void:
	var diff := root.get_node("Difficulty")
	print("paintball tuning: %d seeded matches per row, TARGET %d, LIMIT %d s, AI_ACC %.2f" % [seeds, PB.TARGET, int(PB.LIMIT), PB.AI_ACC])
	print("| tier | win | draw | loss | length | captures | your captures | your tags |")
	if sweep:
		for cfg: Array in SWEEP:
			_table(str(cfg), {"skill": 1.0, "acc": cfg[0], "crew_acc": cfg[1], "rival_edge": cfg[2], "target": cfg[3], "limit": cfg[4], "carry_dodge": cfg[5], "respawn": cfg[6], "carry": cfg[7]})
		quit(0)
		return
	var rows := {}
	for night in [false, true]:
		for tier in TIERS:
			if night and tier != "normal" and not full:
				continue
			var p := {"skill": float(diff.at("paint.skill", tier)), "acc": float(diff.at("paint.acc", tier)), "night": night}
			rows["%s%s" % [tier, " night" if night else ""]] = _table("%s%s" % [tier, " (night)" if night else ""], p)
	var duo: Dictionary = _table("normal, co-op (two bots)", {"skill": float(diff.at("paint.skill", "normal")), "acc": float(diff.at("paint.acc", "normal"))}, 2)
	for key in rows:
		ok(int(rows[key].ended) == seeds, "%s: every match ends" % key)
	var e: Dictionary = rows["easy"]
	var m: Dictionary = rows["normal"]
	var h: Dictionary = rows["hard"]
	ok(float(m.win) >= 0.45 and float(m.win) <= 0.65, "normal: the average player wins 45 to 65 %% (%d %%)" % roundi(m.win * 100.0))
	ok(float(e.win) > float(m.win) + 0.05 and float(e.win) <= 0.92, "easy is easier, not a walkover (%d %%)" % roundi(e.win * 100.0))
	ok(float(h.win) < float(m.win) - 0.05 and float(h.win) >= 0.15, "hard is harder, not hopeless (%d %%)" % roundi(h.win * 100.0))
	ok(float(e.loss) < float(m.loss) + 0.05 and float(m.loss) < float(h.loss) + 0.05, "and you lose more often the harder it gets (%d / %d / %d %%)" % [roundi(e.loss * 100.0), roundi(m.loss * 100.0), roundi(h.loss * 100.0)])
	for key in rows:
		var row: Dictionary = rows[key]
		ok(float(row.with_cap) >= 0.75, "%s: a flag is carried home in most matches (%d %%)" % [key, roundi(row.with_cap * 100.0)])
		ok(float(row.secs) >= 60.0, "%s: a match is not over in a blink (%d s)" % [key, roundi(row.secs)])
		ok(float(row.draw) <= 0.45, "%s: most matches have a winner (%d %% draws)" % [key, roundi(row.draw * 100.0)])
	var n: Dictionary = rows["normal night"]
	ok(float(n.win) >= 0.4 and float(n.win) <= 0.7, "normal at night stays near the day's odds (%d %%)" % roundi(n.win * 100.0))
	ok(float(m.mine) >= 0.5 and float(m.mine) <= 2.0, "normal: you carry a flag home about once a match (%.2f): FLAG RUNNER at 5 is a few good evenings" % m.mine)
	ok(int(duo.ended) == seeds and float(duo.win) >= float(m.win) - 0.1 and float(duo.win) <= 0.85 and float(duo.p2) > 0.5, "co-op: two pilots win a little more often than one, not always (%d %%), and player 2 does its share (%.1f tags and captures a match)" % [roundi(duo.win * 100.0), duo.p2])
	print("paintball_tuning: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
