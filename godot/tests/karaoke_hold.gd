extends SceneTree
# K2: the country song has hold notes: keep the key down until the note ends; letting go early turns a perfect into a good.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _first_hold(o: Node) -> Dictionary:
	for n in o.g.notes:
		if float(n.get("len", 0.0)) > 0.0:
			return n
	return {}


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	diff.seed_run(11)
	o._kara_setup("wobble")
	_check(_first_hold(o).is_empty(), "the pop song has no hold notes")
	diff.seed_run(11)
	o._kara_setup("dirt")
	var n: Dictionary = _first_hold(o)
	var hold_len := float(n.get("len", 0.0))
	_check(hold_len > 0.0 and hold_len < float(o.g.gap), "the country song has hold notes, shorter than the gap (%.2f of %.2f)" % [hold_len, float(o.g.gap)])
	n.erase("auto")
	var lane: int = int(n.lane)
	var key: int = o.LANE_KEYS[lane]
	# let go early: the perfect becomes a good
	o.g.t = float(n.time)
	_check(o.kara_hit(lane) == "perfect" and o.g.held.has(lane), "pressing on time is a perfect and the key is being held")
	var score0: int = o.g.score
	var perfect0: int = o.g.perfect
	o.g.t = float(n.time) + 0.1
	o._kara_release(key)
	var early_ok: bool = n.state == "good" and o.g.score == score0 - 1 and o.g.perfect == perfect0 - 1 and not o.g.held.has(lane)
	_check(early_ok, "letting go early: only good (score %d, perfect %d)" % [int(o.g.score), int(o.g.perfect)])
	# hold to the end: it stays perfect
	diff.seed_run(11)
	o._kara_setup("dirt")
	n = _first_hold(o)
	lane = int(n.lane)
	o.g.t = float(n.time)
	o.kara_hit(lane)
	var score1: int = o.g.score
	o.g.t = float(n.time) + float(n.len) + 0.05
	o._kara_tick(0.0)
	_check(not o.g.held.has(lane), "held to its end the hold completes by itself")
	o._kara_release(o.LANE_KEYS[lane])
	_check(n.state == "perfect" and o.g.score == score1, "and letting go afterwards changes nothing")
	o._kara_release(o.LANE_KEYS[(lane + 1) % 4])
	_check(o.g.score == score1, "releasing a key that holds nothing does nothing")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
