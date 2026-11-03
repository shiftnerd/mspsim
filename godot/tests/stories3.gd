extends SceneTree
# New tech stories: the wire-fraud scare, the client who said no, the day without Alan.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _best(pb: Node) -> int:
	var step: Dictionary = pb.current_step()
	var best := -1
	var best_pts := -1
	for i in step.choices.size():
		var ch: Dictionary = step.choices[i]
		if pb.lock_reason(ch) == "" and int(ch.pts) > best_pts:
			best_pts = int(ch.pts)
			best = i
	return best


func _play_best(pb: Node, id: String) -> void:
	pb.start(id)
	var guard := 0
	while pb.is_active() and not pb.active.done and guard < 12:
		pb.choose(_best(pb))
		guard += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var pb := root.get_node("Playbook")
	var story := root.get_node("Story")
	var sales := root.get_node("Sales")
	c.save_prefix = "user://test_"
	c.new_game("tech")
	root.get_node("Skills").xp["people"] = 60  # so CUSTOMER-locked choices are open

	# on the calendar
	var days: Dictionary = story.DAYS
	_check(
		(
			str(days[8][0].book) == "ceofraud"
			and str(days[14][0].book) == "no2fa"
			and str(days[19][0].book) == "bus"
		),
		"days 8, 14 and 19 start the new jobs"
	)

	# the wire fraud: the careful path
	_play_best(pb, "ceofraud")
	_check(
		pb.active.done and pb.active.result.grade in ["S", "A"],
		"wire fraud, careful: " + str(pb.active.result)
	)
	# the careless path: they wire the money
	var rep0: int = c.rep
	pb.start("ceofraud")
	pb.choose(3)  # wire it
	pb.choose(2)  # blame the spam filter
	pb.choose(2)  # delete the email
	pb.choose(1)  # email the bank
	pb.choose(2)  # fix it quietly
	_check(
		pb.active.done and pb.active.result.grade in ["D", "C"] and c.rep <= rep0 - 10,
		"wire fraud, careless: the money is gone and so is reputation (%d to %d)" % [rep0, c.rep]
	)

	# the client who said no
	_play_best(pb, "no2fa")
	_check(
		pb.active.done and pb.active.result.grade in ["S", "A", "B"],
		"client says no, shown and phased: " + str(pb.active.result)
	)
	var follow0: int = story.flags.get("followups", []).size()
	var mood0: int = sales.mood(4)
	pb.start("no2fa")
	pb.choose(3)  # let it go
	pb.choose(2)  # write down the risk
	pb.choose(1)  # nothing
	_check(
		story.flags.get("followups", []).size() > follow0 and sales.mood(4) < mood0,
		"ignoring the client brings a phishing ticket and a mood hit"
	)

	# the day without Alan
	_play_best(pb, "bus")
	_check(
		pb.active.done and pb.active.result.grade in ["S", "A"],
		"day without Alan, documented: " + str(pb.active.result)
	)
	var follow1: int = story.flags.get("followups", []).size()
	pb.start("bus")
	pb.choose(3)  # factory reset
	pb.choose(2)  # rebuild
	pb.choose(1)  # sticky note
	_check(
		pb.active.done and story.flags.get("followups", []).size() > follow1,
		"factory-resetting the firewall brings the internet back down"
	)

	# Vic's sales: signing a client or selling an install both ring the bell text without errors
	var signed := 0
	var installs := 0
	for i in 40:
		sales.active = [0, 1, 2, 3, 4]
		root.get_node("Msp").enabled = true
		var before: String = sales.last_deal
		if sales.visit_done():
			signed += 1 if "CLOSED" in str(sales.last_deal) else 0
			installs += 1 if "INSTALL" in str(sales.last_deal) else 0
	_check(
		signed + installs > 0 and sales.last_deal != "",
		"Vic's sales record what he sold (%d signed, %d installs)" % [signed, installs]
	)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
