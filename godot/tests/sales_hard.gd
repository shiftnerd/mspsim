extends SceneTree
# gdlint:disable=max-line-length
# X13: sales on hard is hard but winnable by careful play. Five seeds (1 to 5), the bots of bot_lib.gd, about two minutes:
#   - the careful account manager is not let go in year 1 on any seed
#   - in Year 2 (New Game Plus on the record each year 1 left) at most one of the five is let go
#   - the lazy one still fails on hard on every seed (let go or fired)
#   - careful on hard still ends below careful on normal (the tier is still harder)
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/sales_hard.gd

const SEEDS := 5

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = 20.0
	var gone_y1 := 0
	var gone_y2 := 0
	var hard_score := 0.0
	var y1 := []
	var y2 := []
	for k in SEEDS:
		var r: Dictionary = await bots.play_year2("sales", "hard", "careful", 1 + k)
		var first: Dictionary = r.get("year1", r)
		print(bots.line(first))
		y1.append("%d/%d" % [int(first.q2), int(first.q3)])
		hard_score += float(first.score)
		gone_y1 += 1 if str(first.cls) == "bad" else 0
		if r.has("year1"):
			print(bots.line(r))
			y2.append("%d/%d" % [int(r.q2), int(r.q3)])
			gone_y2 += 1 if str(r.cls) == "bad" else 0
	_check(gone_y1 == 0, "hard, careful, year 1: nobody is let go (%d of %d; Q2/Q3 %s)" % [gone_y1, SEEDS, " ".join(PackedStringArray(y1))])
	_check(y2.size() == SEEDS and gone_y2 <= 1, "hard, careful, Year 2: at most one of five is let go (%d of %d; Q2/Q3 %s)" % [gone_y2, y2.size(), " ".join(PackedStringArray(y2))])
	var lazy_bad := 0
	for k in SEEDS:
		var r: Dictionary = await bots.play("sales", "hard", "lazy", 1 + k)
		print(bots.line(r))
		lazy_bad += 1 if str(r.cls) == "bad" else 0
	_check(lazy_bad == SEEDS, "hard, lazy: fails on every seed (%d of %d)" % [lazy_bad, SEEDS])
	var normal_score := 0.0
	for k in SEEDS:
		var r: Dictionary = await bots.play("sales", "normal", "careful", 1 + k)
		normal_score += float(r.score)
	_check(hard_score < normal_score * 0.95, "hard is still harder than normal for the careful bot (mean quota %d%% against %d%%)" % [int(hard_score / SEEDS), int(normal_score / SEEDS)])
	# the rule itself: two missed quarters, the year at 73% and at 50% of both quotas, on hard and on normal
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	for tier in ["hard", "normal", "easy"]:
		d.set_tier(tier)
		c.new_game("sales")
		var n := 0
		while cards.is_open and n < 30:
			cards.pick(0)
			n += 1
		sc.q_result = ["MISS", "MISS"]
		sc.q_signed = [int(0.8 * sc.quota_target(0)), int(0.65 * sc.quota_target(1))]
		var close_year: bool = sc.pip_failed()
		sc.q_signed = [int(0.5 * sc.quota_target(0)), int(0.5 * sc.quota_target(1))]
		var poor_year: bool = sc.pip_failed()
		if tier == "hard":
			_check(not close_year and poor_year and is_equal_approx(d.cf("sales.keep"), 0.65), "hard: two misses with 73%% of the year keep the job, with 50%% they end it (keep %.2f)" % d.cf("sales.keep"))
			var ids := []
			for of in sc.offers():
				ids.append(str(of.id))
			_check(ids.has("let_go"), "and the review of the poor year offers the door: %s" % str(ids))
		else:
			if tier == "easy":
				_check(not close_year and not poor_year and d.cf("sales.keep") == 0.0, "easy is cozy: two misses never end the job")
			else:
				_check(close_year and poor_year and d.cf("sales.keep") == 0.0, "%s: two misses end the job, as before" % tier)
	d.set_tier("normal")
	root.get_node("Campaign").quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
