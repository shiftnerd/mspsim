extends SceneTree
# K5: a friend from the party sings the two right lanes (a duet): their notes resolve by a skill roll, you cannot hit them, and a song without a friend is unchanged.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	diff.seed_run(3)
	o._kara_setup()
	var plain: int = o.g.notes.filter(func(n: Dictionary) -> bool: return n.get("auto", false)).size()
	_check(plain == 0 and not o.g.has("partner"), "no friend, no duet: every note is yours")
	o._assign_duet_with("Dan")
	var theirs: Array = o.g.notes.filter(func(n: Dictionary) -> bool: return n.get("auto", false))
	var mine: Array = o.g.notes.filter(func(n: Dictionary) -> bool: return not n.get("auto", false))
	_check(str(o.g.partner) == "Dan" and theirs.size() > 0 and mine.size() > 0, "with Dan the right lanes are his (%d notes) and the left ones yours (%d)" % [theirs.size(), mine.size()])
	_check(theirs.all(func(n: Dictionary) -> bool: return int(n.lane) >= o.DUET_LANES), "only the two right lanes")
	var lane: int = int(theirs[0].lane)
	o.g.t = float(theirs[0].time)
	_check(o.kara_hit(lane) == "", "you cannot hit his notes")
	o.g.t = float(o.g.span) + 1.0
	o._duet_tick()
	var left: int = theirs.filter(func(n: Dictionary) -> bool: return n.state == "").size()
	var sang: int = o.g.perfect + o.g.good + o.g.miss
	_check(left == 0 and sang == theirs.size(), "when their time has passed all of them are resolved (%d of %d)" % [sang, theirs.size()])
	_check(o.g.score > 0 and o.g.perfect + o.g.good > o.g.miss, "he mostly hits: score %d, %d perfect, %d good, %d miss" % [o.g.score, o.g.perfect, o.g.good, o.g.miss])
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
