extends SceneTree
# gdlint:disable=max-line-length
# Q6: the same seed must give the same game. A bot plays the first days of the tech campaign (hard tier, where one ticket more
# or less moves the reputation) twice in one process with the same seed, and a whole sales campaign twice; the two rows of each
# pair must be equal. Between the two runs the office keeps running, so anything that survives Campaign.new_game with a value
# from before the seed (the bug this test was written for: World's meeting timer was drawn once at boot) shows up as a difference.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/determinism.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _sig(r: Dictionary) -> String:
	return "rep %d score %d closed %d missed %d ending %s | %s" % [int(r.rep), int(r.score), int(r.get("closed", 0)), int(r.get("missed", 0)), str(r.get("ending", "")), str(r.get("info", ""))]


func _init() -> void:
	await process_frame
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	# tech, hard, careful, seed 11: four days, twice
	bots.ts = 120.0
	bots.stop_day = 4
	var a: Dictionary = await bots.play("tech", "hard", "careful", 11)
	# let the office run on between the two games, as it does between two sessions
	root.get_node("World").time_scale = 30.0
	for i in 90:
		await process_frame
	var b: Dictionary = await bots.play("tech", "hard", "careful", 11)
	_check(int(a.closed) > 0, "the bot closed tickets in four days (%d)" % int(a.closed))
	_check(_sig(a) == _sig(b), "tech hard careful seed 11, days 1-4: two runs are the same\n     %s\n     %s" % [_sig(a), _sig(b)])
	var other: Dictionary = await bots.play("tech", "hard", "careful", 12)
	_check(_sig(a) != _sig(other), "another seed is another game")
	bots.stop_day = 0
	# sales, normal, careful, seed 11: the whole campaign, twice
	bots.ts = 20.0
	var s1: Dictionary = await bots.play("sales", "normal", "careful", 11)
	var s2: Dictionary = await bots.play("sales", "normal", "careful", 11)
	_check(_sig(s1) == _sig(s2), "sales normal careful seed 11: two runs are the same\n     %s\n     %s" % [_sig(s1), _sig(s2)])
	root.get_node("Campaign").quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
