extends SceneTree
# gdlint: ignore=max-line-length
# Play-through bug fixes: close confirmation, opinion cap, jobs that outlive the window, mail keys,
# onsite SLA / risk count / event filter, commute result text. Run: Godot --headless --path godot -s res://tests/bugfix.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var msp: Node = root.get_node("Msp")
	var comp: Node = root.get_node("Computer")
	var social: Node = root.get_node("Social")
	var camp: Node = root.get_node("Campaign")
	var onsite: Node = root.get_node("Onsite")
	var shift: Node = root.get_node("Shift")
	var skills: Node = root.get_node("Skills")
	camp.save_prefix = "user://test_"
	camp.new_game("tech")
	msp.reset()

	# CLOSE on an unfixed ticket asks first
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	comp.open(1)
	comp.activate("app:psa")
	comp.activate("tk:%d" % t.id)
	comp.activate("close")
	check(comp.close_ask and msp.reopened == 0 and msp.ticket(t.id).status != "Closed", "CLOSE on an unfixed ticket asks first")
	comp.back()
	check(not comp.close_ask and comp.psa_detail, "Esc cancels the question")
	comp.activate("close")
	comp.activate("closeno")
	check(not comp.close_ask and msp.reopened == 0, "KEEP WORKING does nothing")
	comp.activate("close")
	comp.activate("closeyes")
	check(msp.reopened == 1 and msp.ticket(t.id).status == "In Progress", "CLOSE ANYWAY reopens it")
	comp.activate("closeyes")
	check(msp.reopened == 1, "a stray YES without a question is ignored")
	msp.rmm_action(t.endpoint, "spooler")
	comp.activate("close")
	check(not comp.close_ask and msp.ticket(t.id).status == "Closed", "a fixed ticket closes without a question")

	# reopen opinion loss is capped per day
	social.reset()
	for i in 6:
		social.note_reopen()
	check(social.value("Alan") == -3, "reopens cost at most 3 opinion a day")
	social.begin_day()
	social.note_reopen()
	check(social.value("Alan") == -4, "the cap resets next day")

	# an RMM job keeps running when the computer is closed
	skills.ps_level = 4  # no failed fixes
	var t2: Dictionary = msp.create_ticket(1, 0, "test")
	comp.activate("close_app")
	comp.activate("app:rmm")
	comp.activate("client:%d" % t2.client)
	comp.activate("rmm:" + t2.endpoint)
	comp.activate("connect")
	comp.activate("fix:spooler")
	check(not comp._job.is_empty(), "the fix is running")
	comp.close()
	comp._process(0.1)
	check(not comp._job.is_empty(), "closing the computer keeps the job")
	comp._process(10.0)
	check(comp._job.is_empty() and msp.ticket(t2.id).fix_done, "the job finishes with the window closed")
	skills.ps_level = 0

	# endpoint alert dot follows unfixed tickets
	var t3: Dictionary = msp.create_ticket(2, 0, "test")
	var ep: Dictionary = msp.endpoint(t3.endpoint)
	check(comp._ep_alert(ep), "a broken endpoint shows an alert")
	ep.problem = ""
	check(comp._ep_alert(ep), "so does one with an open unfixed ticket")
	t3.fix_done = true
	check(not comp._ep_alert(ep), "a fixed one is green")

	# mail: Enter works from the first press, and long subjects get an ellipsis
	msp.mail("Vic", "Hello", "body")
	comp.open(1)
	comp.activate("app:mail")
	comp.mail_sel = -1
	var unread0: int = msp.unread()
	comp.enter()
	check(comp.mail_sel == 0 and comp.mail_view and msp.unread() == unread0 - (1 if unread0 > 0 else 0), "Enter opens the first mail and marks it read")
	var clipped: String = comp._clip("WELCOME TO THE SERVICE DESK", 20)
	check(clipped.length() == 20 and clipped.ends_with(".."), "long subjects end in an ellipsis")
	comp.close()

	# onsite: SLA covers the round trip, the risk count skips the ticket you are about to work
	msp.reset()
	var j: Dictionary = onsite.create_job(0, "switch")
	check(not j.is_empty() and float(j.sla_total) > float(msp.SLA_SECS[int(j.pri)]), "onsite tickets get a longer SLA")
	j.sla_left = 10.0
	check(onsite.at_risk(70) == 1 and onsite.at_risk(70, int(j.id)) == 0, "the risk count does not include the onsite ticket")
	onsite.job = {"object": "printer"}
	check(not onsite.event_fits({"object": "pc"}) and onsite.event_fits({"object": "printer"}), "events only fit their job")
	onsite.job = {"object": "server"}
	check(onsite.event_fits({"object": "cabinet"}), "closet events fit server jobs")
	onsite.job = {}

	# commute result line
	shift.late_min = 40
	check(shift._arrival_text(20, 2) == "YOU ARRIVE 40 MIN LATE. 2 TICKETS WAITING.", "late arrival line")
	shift.late_min = 0
	check(shift._arrival_text(-45, 0).contains("45 MIN EARLY") and shift._arrival_text(-5, 0).contains("EARLY"), "early arrival line")
	check(shift._arrival_text(0, 0) == "YOU ARRIVE ON TIME.", "on time line")

	DirAccess.remove_absolute(camp.save_path("tech"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
