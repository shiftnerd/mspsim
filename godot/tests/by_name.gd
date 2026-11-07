extends SceneTree
# R36: clients who know your name (tech campaign). A happy client sometimes asks for you by name: a marked ticket that pays a mood
# bonus, a point of reputation and a medal counter when closed in time, and costs mood when it breaches. A very happy client
# sometimes texts a thank-you after a clean close. Unhappy clients do neither, and other campaigns never.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _find_asked(msp: Node, sales: Node, tries: int) -> Dictionary:
	for i in tries:
		msp.named_day.clear()
		msp.spawned_today = 0
		sales.satisfaction[0] = 90
		var t: Dictionary = msp.create_problem(0, msp.PROBLEMS[0], "email", true)
		if t.is_empty():
			continue
		msp._maybe_by_name(t)
		if bool(t.get("asked_for", false)):
			return t
	return {}


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var career := root.get_node("Career")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	career.toasts = false
	c.new_game("tech")
	root.get_node("Difficulty").seed_run(21)
	# a happy client asks for you
	var t := _find_asked(msp, sales, 200)
	_check(not t.is_empty() and str(t.notes[-1]).contains("asked for you by name"), "a happy client sometimes asks for you by name")
	# closing it in time pays
	var rep0: int = c.rep
	var mood0: int = sales.mood(0)
	var ac0: int = int(career.value("asked_for"))
	t["breached"] = false
	t["fix_done"] = true
	msp.close_ticket(int(t.id))
	_check(sales.mood(0) > mood0 and c.rep == rep0 + 1 and int(career.value("asked_for")) == ac0 + 1, "closed in time: mood up, +1 reputation, counted")
	# a late one costs mood
	var late := _find_asked(msp, sales, 200)
	late["breached"] = true
	late["fix_done"] = true
	sales.satisfaction[0] = 90
	msp.close_ticket(int(late.id))
	_check(sales.mood(0) < 90 + 3, "a late by-name ticket does not earn the bonus (mood %d)" % sales.mood(0))
	# an unhappy client never asks
	var asked := 0
	for i in 150:
		msp.named_day.clear()
		sales.satisfaction[0] = 50
		var u: Dictionary = msp.create_problem(0, msp.PROBLEMS[0], "email", true)
		if not u.is_empty():
			msp._maybe_by_name(u)
			asked += 1 if bool(u.get("asked_for", false)) else 0
	_check(asked == 0, "a client below mood 75 never asks for you by name")
	# thank-you texts after a clean close of a very happy client
	var got := false
	for i in 120:
		msp.thanked_day.clear()
		sales.satisfaction[0] = 95
		var n0: int = msp.texts.size()
		var v: Dictionary = msp.create_problem(0, msp.PROBLEMS[0], "email", true)
		if v.is_empty():
			continue
		v["breached"] = false
		v["fix_done"] = true
		msp.close_ticket(int(v.id))
		if msp.texts.size() > n0:
			got = true
			break
	_check(got, "a very happy client sometimes texts a thank-you")
	# other campaigns do nothing
	c.new_game("service")
	var o: Dictionary = msp.create_problem(0, msp.PROBLEMS[0], "email", true)
	if not o.is_empty():
		sales.satisfaction[0] = 95
		msp._maybe_by_name(o)
	_check(o.is_empty() or not bool(o.get("asked_for", false)), "the service campaign has no by-name requests")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
