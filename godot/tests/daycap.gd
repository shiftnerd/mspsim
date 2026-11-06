extends SceneTree
# The first tech days are gentle: day 1 gets one random ticket, days 2 and 3 a few.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _spawn_many(msp: Node, n: int) -> int:
	var made := 0
	for i in n:
		made += 0 if msp._random_ticket("email").is_empty() else 1
	return made


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	_check(msp.day_cap() == 1 and msp._spawn_t >= 60.0, "day 1: one ticket, and not for a minute")
	_check(_spawn_many(msp, 8) == 1, "day 1 only ever makes one random ticket")
	msp.reset()
	msp.new_day(1)
	c.day = 2
	msp.new_day(2)
	_check(msp.day_cap() == 3 and _spawn_many(msp, 8) == 3, "day 2: three")
	c.day = 3
	msp.new_day(3)
	_check(_spawn_many(msp, 8) == 5, "day 3: five")
	c.day = 4
	msp.new_day(4)
	_check(msp.day_cap() == 6 and _spawn_many(msp, 12) == 6, "day 4: six")
	c.day = 10
	msp.new_day(10)
	_check(msp.day_cap() == 12 and msp.open_cap() == 6, "day 10: twelve, six open")
	c.day = 1
	_check(msp.open_cap() == 3, "day 1: three open at most")
	c.day = 17
	msp.new_day(17)
	_check(msp.day_cap() == 12 and msp.open_cap() == 6, "day 17: still twelve")
	c.day = 21
	msp.new_day(21)
	_check(msp.day_cap() == 99 and msp.open_cap() == 6, "past the campaign: no cap")
	c.new_game(c.FREE)
	_check(msp.day_cap() == 99, "free play is never capped")
	c.new_game("owner")
	_check(msp.day_cap() == 99, "the owner campaign is not capped")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
