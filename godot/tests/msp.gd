extends SceneTree
# gdlint: ignore=max-line-length
# Msp logic + Computer UI: tickets, RMM fix, close rules, then screenshots of each app (needs a renderer to
# save images; headless still checks the logic). Run: Godot --path godot -s res://tests/msp.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var msp: Node = root.get_node("Msp")
	var comp: Node = root.get_node("Computer")
	var game: Node = root.get_node("Game")
	check(msp.emails.size() == 1 and msp.unread() == 1, "welcome mail")
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	check(not t.is_empty() and msp.open_tickets().size() == 1, "ticket created")
	check(msp.unread() == 2, "client emailed")
	var closed_early: String = msp.close_ticket(t.id)
	check(closed_early.begins_with("REOPENED") and msp.score == -3, "closing unfixed reopens")
	check(
		msp.rmm_action(t.endpoint, "password") == "DONE. NOTHING CHANGED.", "wrong fix does nothing"
	)
	var msg: String = msp.rmm_action(t.endpoint, "spooler")
	check(msg.contains("spooler") and msp.ticket(t.id).fix_done, "right fix: " + msg)
	check(msp.close_ticket(t.id).begins_with("CLOSED") and msp.closed_ok == 1, "closes after fix")
	var t2: Dictionary = msp.create_ticket(1, 1, "test")
	msp.create_ticket(2, 2, "test")
	msp.create_ticket(3, 5, "test")

	var size := Vector2(root.size)
	print("viewport ", size)
	comp.open(1)
	await process_frame
	await create_timer(0.4).timeout
	check(game.ui_open and comp.is_open, "computer opens")
	var shots := ["desktop", "mail", "psa", "ticket", "rmm", "session"]
	for shot in shots:
		match shot:
			"mail":
				comp.activate("app:mail")
				comp.activate("mail:1")
			"psa":
				comp.activate("app:psa")
			"ticket":
				comp.activate("tk:%d" % t2.id)
			"rmm":
				comp.activate("app:rmm")
				comp.activate("client:%d" % t2.client)
				comp.activate("rmm:" + t2.endpoint)
			"session":
				comp.activate("connect")
				comp.activate("fix:password")
		await process_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://msp_%s.png" % shot)
	check(msp.ticket(t2.id).fix_done, "password reset through the RMM session")
	comp.activate("close_app")
	comp.back()
	await process_frame
	check(not comp.is_open and not game.ui_open, "back from desktop closes")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
