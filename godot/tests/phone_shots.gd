extends SceneTree
# Screenshots of the R37 phone upgrades in both skins (needs a renderer, not headless):
#   Godot --path godot --fixed-fps 60 -s res://tests/phone_shots.gd -- --format=h|v|wide
# Saves user://phone2_<format>_<skin>_<name>.png (lock, home, contacts, keypad, dial, talk, done, voicemail, banner).

var failures := 0
var fmt := "wide"


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _shot(skin: String, name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("user://phone2_%s_%s_%s.png" % [fmt, skin, name])


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--format="):
			fmt = arg.substr(9)
	await process_frame
	var phone := root.get_node("Phone")
	var msp := root.get_node("Msp")
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	phone.save_path = "user://test_%d_phone.cfg" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	diff.set_tier("normal")
	c.new_game("tech")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	world.clock = 10.25
	world.time_scale = 0.0
	var t: Dictionary = msp.create_ticket(0, 5, "test")
	msp.create_ticket(1, 1, "test")
	sales.satisfaction[0] = 82
	msp.emails[0].unread = true
	msp.send_text("Boss", "Why is the Acme ticket still open?")
	msp._mail("Dr. Patel <patel@acmedental.example>", "PRINTER IS ON FIRE AGAIN", "Please help.", 0)
	root.get_node("Lync")._push("Dan", "Dan", "Heads up: #3 is about to breach its SLA.")
	phone.poll_notifications()
	phone._bq.clear()
	phone.banner = {}
	for skin in ["ios", "android"]:
		phone.os = skin
		# the banner on the HUD (phone closed)
		phone.notify("TEXT", "Dispatch", "P1 #4 PRINTER DOWN - ACME DENTAL")
		phone.step_banner(0.0)
		phone.step_banner(0.6)
		await _shot(skin, "banner")
		phone.banner = {}
		phone._bq.clear()
		phone.open()
		await create_timer(0.4).timeout
		await _shot(skin, "lock")
		phone.activate("unlock")
		phone._process(0.5)
		phone.activate("app:home")
		await _shot(skin, "home")
		phone.home_sel = 4
		phone.activate("app:phone")
		await _shot(skin, "contacts")
		phone.ph_sel = 9
		await _shot(skin, "contacts_scrolled")
		phone.ph_sel = 0
		phone.activate("keypad")
		phone.kp_text = "5550110"
		await _shot(skin, "keypad")
		phone.activate("contacts")
		phone.activate("call:0")
		await _shot(skin, "dial")
		phone.step_call(1.3)
		phone.step_call(8.0)
		await _shot(skin, "talk")
		phone.choose(0)
		await _shot(skin, "done")
		phone.hang_up()
		phone.call_cd.clear()
		t["breached"] = true
		phone.activate("call:%d" % (phone.Calls.contacts().size() - 3))
		phone.pick_up()
		await _shot(skin, "coworker")
		phone.hang_up()
		phone.kp_text = "1234567"
		phone.dial_number()
		phone.pick_up()
		await _shot(skin, "voicemail")
		phone.hang_up()
		phone.close()
		await create_timer(0.4).timeout
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
