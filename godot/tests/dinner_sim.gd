extends SceneTree
# Plays 200 dinners headless through the real dinner_talk path, once with the best topic every
# round and once with random picks, and checks the star distributions: best play reaches 2 stars
# in 95%+ of seeds (and 3 stars often), careless play rarely gets 3 (it mostly lands on 2:
# the topic list always holds a treat, so even random picks are not punished).
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/dinner_sim.gd`

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _dinner(o: Node, d: Node, seed_n: int, best: bool) -> int:
	d.seed_run(seed_n)
	o.reset()
	o.start("dinner")
	o.begin_play()
	var r: RandomNumberGenerator = d.rng_for("sim", seed_n)
	for round_no in 5:
		var pick := 0
		if best:
			var top := -1
			for i in 4:
				var pts := 0
				for who in o.diners():
					pts += o.diner_points(who, o.g.options[i])
				if pts > top:
					top = pts
					pick = i
		else:
			pick = r.randi_range(0, 3)
		o.dinner_talk(pick)
		o.tick(2.0)
	var result: int = o.stars
	o.press(KEY_ENTER)
	return result


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	o.enabled = true
	c.new_game("free")
	root.get_node("World").time_scale = 1.0
	d.set_tier("normal")
	var dist := {"best": [0, 0, 0, 0], "random": [0, 0, 0, 0]}
	for seed_n in 200:
		dist.best[_dinner(o, d, 3000 + seed_n, true)] += 1
		dist.random[_dinner(o, d, 3000 + seed_n, false)] += 1
	print("best   stars 0-3: ", dist.best)
	print("random stars 0-3: ", dist.random)
	_check(dist.best[2] + dist.best[3] >= 190, "best play: 2+ stars in 95%+ of 200 dinners")
	_check(dist.best[3] >= 60, "best play: 3 stars often")
	_check(dist.random[3] <= 30, "random picks: 3 stars in at most 15%")
	var avg_best := float(dist.best[1] + 2 * dist.best[2] + 3 * dist.best[3]) / 200.0
	var avg_random := float(dist.random[1] + 2 * dist.random[2] + 3 * dist.random[3]) / 200.0
	_check(
		avg_best - avg_random >= 0.35,
		"best play beats random by %.2f stars" % (avg_best - avg_random)
	)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
