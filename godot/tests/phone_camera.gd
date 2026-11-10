extends SceneTree
# gdlint:disable=max-line-length
# R37, the phone's CAMERA app: the icon in the dock, the viewfinder on what is in front of you, the shutter, the roll of
# the last six photos, a photo page, and the real use: a photo of the patch panel in the network closet keeps the jack
# tags, and a "no link" ticket read on the phone at your desk quotes the tag for that desk from the photo (printed by
# Dan = trust it, hand-written tape = it may have drifted). Keys, pad-style moves and clicks; saved with the campaign.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/phone_camera.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	_run.call_deferred()


func _hit(phone: Node, id: String) -> Rect2:
	for h in phone._hits:
		if str(h.id) == id:
			return h.r
	return Rect2()


func _run() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var phone := root.get_node("Phone")
	var net := root.get_node("Net")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var pid := OS.get_process_id()
	c.save_prefix = "user://test_%d_cam_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_cam_settings.cfg" % pid
	phone.save_path = "user://test_%d_cam_phone.cfg" % pid
	game.title_mode = false
	c.new_game("tech")
	msp.enabled = false
	phone.set_os("android")
	_check(phone.photos.is_empty() and phone.HOME_APPS.has("camera"), "a new campaign: an empty roll, CAMERA is a home app")

	# ---- in the network closet: the patch panel
	change_scene_to_file("res://scenes/network_closet.tscn")
	await _wait(30)
	phone.open()
	await _wait(3)
	phone.activate("home")
	await _wait(3)
	_check(_hit(phone, "app:camera").size.x > 0.0, "the home screen has a CAMERA icon to tap")
	phone.home_sel = 0
	for i in 8:
		phone.home_move(1)
	_check(str(phone.HOME_APPS[phone.home_sel]) == "camera", "the arrows (or a pad) reach it")
	phone.enter()
	await _wait(3)
	_check(phone.app == "camera" and phone.cam_view == "finder", "Enter opens the viewfinder")
	var seen: Dictionary = phone.camera_subject()
	_check(seen.kind == "panel" and seen.cap == "PATCH PANEL" and seen.lines.size() == 8, "in the closet it sees the patch panel and its eight tags")
	_check(_hit(phone, "shoot").size.x > 0.0, "a shutter button to tap")
	phone.enter()
	await _wait(3)
	_check(phone.photos.size() == 1 and phone.photos[0].kind == "panel" and int(phone.photos[0].day) == int(world.day), "Enter takes the photo: on the roll with the day")
	var tag3: Dictionary = phone.photos[0].tags[3]
	_check(str(tag3.text) == net.label_text(3) and str(tag3.state) == "dan", "the photo holds the tags as they read (port 3: %s)" % str(tag3.text))
	_check(_hit(phone, "roll").size.x > 0.0, "the roll button shows up once there is a photo")
	phone.move(1)
	await _wait(3)
	_check(phone.cam_view == "roll" and _hit(phone, "photo:0").size.x > 0.0, "Down from the viewfinder: the roll, one row a photo")
	phone.enter()
	await _wait(3)
	_check(phone.cam_view == "photo", "Enter opens the photo")
	phone.back()
	_check(phone.cam_view == "roll", "Back: the roll")
	phone.back()
	_check(phone.cam_view == "finder" and phone.app == "camera", "Back: the viewfinder")
	phone.back()
	_check(phone.app == "home", "Back: home")
	phone.close()

	# ---- back at your desk: the photo answers for a no-link ticket
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(30)
	var line3: String = phone.panel_line(3)
	_check(line3.find("PORT 3") >= 0 and line3.find("PRINTED") >= 0 and line3.find("OLD") < 0, "Dan's desk: the photo names port 3 and says the tag is printed (%s)" % line3)
	var tape := 0
	for desk in net.DRIFT_JACKS:
		var line: String = phone.panel_line(desk)
		_check(line.begins_with("PHOTO:"), "desk %d has an answer from the photo (%s)" % [desk, line])
		tape += 1 if line.find("TAPE") >= 0 else 0
	_check(tape >= 1, "hand-written tags are marked TAPE (%d)" % tape)
	_check(phone.panel_line(0) == "", "no desk, no line")
	phone.open()
	phone.activate("app:camera")
	await _wait(3)
	var here: Dictionary = phone.camera_subject()
	_check(here.kind in ["room", "person"] and here.tags.is_empty(), "on the main floor the camera sees the room or a coworker (%s)" % str(here.cap))
	phone.activate("shoot")
	_check(phone.photos.size() == 2 and phone.photos[0].kind != "panel" and not phone.panel_photo().is_empty(), "a second photo goes on top; the panel photo is still found")
	# the ticket page quotes it
	var t: Dictionary = msp.create_ticket(0, 0, "email")
	t.fix = "network"
	t["desk"] = 3
	phone.activate("app:tickets")
	phone.activate("tk:%d" % int(t.id))
	var pf := load("res://scripts/pixelfont.gd")
	pf.audit = []
	phone._canvas.queue_redraw()
	await _wait(4)
	var quoted := false
	for row in pf.audit:
		quoted = quoted or str(row).find("PHOTO:") >= 0
	pf.audit = null
	_check(quoted, "the ticket page of a no-link ticket shows the PHOTO line")
	phone.close()

	# ---- the roll keeps six, a next-day photo is marked old, saves and loads
	for i in 7:
		phone.take_photo()
	_check(phone.photos.size() == phone.MAX_PHOTOS and phone.panel_photo().is_empty(), "the roll keeps the newest six (the panel photo fell off)")
	_check(phone.panel_line(3) == "", "without a panel photo a ticket gets no line")
	change_scene_to_file("res://scenes/network_closet.tscn")
	await _wait(30)
	phone.take_photo()
	world.day += 1
	_check(phone.panel_line(3).find("OLD PHOTO") >= 0, "a photo from another day says so (%s)" % phone.panel_line(3))
	world.day -= 1
	var saved: Dictionary = phone.to_dict()
	var text := var_to_str(saved)
	phone.reset()
	_check(phone.photos.is_empty(), "a new campaign clears the roll")
	phone.from_dict(str_to_var(text))
	_check(phone.photos.size() == phone.MAX_PHOTOS and phone.panel_line(3).find("PORT 3") >= 0, "the roll is saved with the campaign and the photo still answers (%s)" % phone.panel_line(3))
	phone.from_dict({"cd": {}, "n": {}, "calls": 2})
	_check(phone.photos.is_empty() and phone.calls_made == 2, "an old save without photos loads with an empty roll")
	# a client site's closet: a rack photo (flavour, no tags)
	change_scene_to_file("res://scenes/site_dental_closet_a.tscn")
	await _wait(30)
	var rack: Dictionary = phone.camera_subject()
	_check(rack.kind == "rack" and str(rack.cap) == "DENTAL RACK" and str(rack.lines[0]).begins_with("ASSET TAG"), "a site closet: the client's rack with its asset tag (%s)" % str(rack.lines))
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
