extends SceneTree
# The cell phone: pick a skin, open every app, screenshot them (needs a renderer).
#   Godot --path godot --fixed-fps 60 -s res://tests/phone_ui.gd -- --format=h

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://phone_%s.png" % name)


func _init() -> void:
	await process_frame
	var phone := root.get_node("Phone")
	var msp := root.get_node("Msp")
	phone.os = ""
	msp.create_ticket(0, 5, "test")
	msp.create_ticket(1, 1, "test")
	msp.create_ticket(2, 0, "test")
	_check(msp.unread_texts() >= 2, "urgent tickets text you")
	phone.open()
	await create_timer(0.4).timeout
	_check(phone.is_open and phone.app == "choose", "first open asks for a phone")
	await _shot("choose")
	for os in ["ios", "android"]:
		phone.activate("os:" + os)
		_check(phone.os == os and phone.app == "home", "picked " + os)
		await _shot(os + "_home")
		for app in ["mail", "tickets", "texts", "settings"]:
			phone.activate("app:" + app)
			if app == "mail":
				phone.activate("mail:1")
			if app == "tickets":
				phone.activate("tk:%d" % msp.open_tickets()[0].id)
			await _shot(os + "_" + app)
		phone.back()
		phone.activate("home")
	_check(msp.unread_texts() == 0, "texts marked read")
	phone.close()
	await create_timer(0.4).timeout
	_check(not phone.is_open and not root.get_node("Game").ui_open, "closed")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
