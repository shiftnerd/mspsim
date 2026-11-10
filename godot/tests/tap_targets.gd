extends SceneTree
# gdlint:disable=max-line-length
# R14 (5), the tap-target audit for the tall `v` format (180 x 320, the phone shape): everything a finger taps on the
# title menu, a card, the cell phone and the day report is at least TAP px high (a thumb needs 19 to 24), and no two
# targets of one screen overlap. The glyphs stay the size they are; the hit rects (and the row pitch) grow.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/tap_targets.gd [-- --measure]
# --measure only prints every target with its height (no failures), for tuning.

const TAP := 19.0

var failures := 0
var measure := false


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	measure = OS.get_cmdline_user_args().has("--measure")
	_run.call_deferred()


# every rect is TAP high or more, and no two overlap
func _audit(tag: String, rects: Array) -> void:
	var low := []
	var clash := []
	for i in rects.size():
		var a: Rect2 = rects[i].r
		if measure:
			print("  %s %s: %s h=%.0f" % [tag, str(rects[i].id), a, a.size.y])
		if a.size.y < TAP - 0.01:
			low.append("%s %.0fpx" % [str(rects[i].id), a.size.y])
		for j in range(i + 1, rects.size()):
			var b: Rect2 = rects[j].r
			if a.grow(-1.01).intersects(b.grow(-1.01)):  # a shared edge or a 2 px lap (the home icons' label rows) is not a clash
				clash.append("%s x %s" % [str(rects[i].id), str(rects[j].id)])
	if measure:
		print("%s: %d targets, %d under %d px, %d overlaps" % [tag, rects.size(), low.size(), int(TAP), clash.size()])
		return
	_check(rects.size() > 0, "%s: has tap targets (%d)" % [tag, rects.size()])
	_check(low.is_empty(), "%s: every target is %d px high or more %s" % [tag, int(TAP), str(low.slice(0, 6))])
	_check(clash.is_empty(), "%s: no two targets overlap %s" % [tag, str(clash.slice(0, 6))])


func _phone_rects(phone: Node) -> Array:
	var out := []
	for h in phone._hits:
		if str(h.id) != "none":
			out.append({"r": h.r, "id": h.id})
	return out


func _run() -> void:
	await process_frame
	var game := root.get_node("Game")
	var camp := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var phone := root.get_node("Phone")
	var rep := root.get_node("DayReport")
	camp.save_prefix = "user://test_%d_tap_" % OS.get_process_id()
	root.get_node("Difficulty").settings_path = "user://test_%d_tap_settings.cfg" % OS.get_process_id()
	game.set_format("v")
	# ---- the title menu and its submenu
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(10)
	var t := current_scene
	t._open_menu()
	await _wait(4)
	var rows := []
	for item in t._items:
		if (item.rect as Rect2).size.y > 0.0:
			rows.append({"r": item.rect, "id": item.label})
	_audit("title menu", rows)
	t._choose(0)
	await _wait(4)
	rows = []
	for item in t._items:
		if (item.rect as Rect2).size.y > 0.0:
			rows.append({"r": item.rect, "id": item.label})
	_audit("title submenu", rows)
	# ---- a card with four answers
	game.title_mode = false
	camp.new_game("tech")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(30)
	cards.ask("Alan", "A card with four answers, to measure its rows.", [{"label": "ONE", "id": "a"}, {"label": "TWO", "id": "b"}, {"label": "THREE", "id": "c"}, {"label": "A LONGER FOURTH ANSWER THAT WRAPS ONTO A SECOND LINE OF THE CARD", "id": "d"}], func(_id: String) -> void: pass)
	await _wait(4)
	rows = []
	for h in cards._hits:
		rows.append({"r": h.r, "id": "option %d" % int(h.i)})
	_audit("card", rows)
	cards.pick(0)
	await _wait(2)
	# ---- the cell phone: the home screen and the list apps
	phone.open()
	await _wait(4)
	if phone.locked:
		phone.activate("unlock")
		await _wait(4)
	_audit("phone home", _phone_rects(phone))
	for app in ["mail", "tickets", "texts", "phone", "settings"]:
		phone.activate("app:" + app)
		await _wait(4)
		if phone.app == app:
			_audit("phone " + app, _phone_rects(phone))
		phone.activate("home")
		await _wait(3)
	phone.activate("app:camera")  # R37: the viewfinder, then the roll
	await _wait(3)
	phone.take_photo()
	phone.take_photo()
	await _wait(3)
	_audit("phone camera", _phone_rects(phone))
	phone.activate("roll")
	await _wait(3)
	_audit("phone camera roll", _phone_rects(phone))
	phone.activate("home")
	await _wait(3)
	phone.activate("app:phone")
	await _wait(3)
	phone.activate("keypad")
	await _wait(4)
	_audit("phone keypad", _phone_rects(phone))
	phone.activate("home")
	phone.set_os("ios" if not phone._is_ios() else "android")  # the other phone: its round home button, no nav bar
	await _wait(4)
	_audit("phone home, the other phone", _phone_rects(phone))
	phone.activate("app:settings")
	await _wait(4)
	_audit("phone settings, the other phone", _phone_rects(phone))
	phone.close()
	await _wait(2)
	# ---- the day report
	var data := {"day": 7, "total_days": 20, "closed": 6, "missed": 1, "reopened": 0, "open_left": 2, "clients": 72, "points": 14, "overtime": 1.5, "social": 3}
	data.merge({"energy": 31, "late": 25, "oncall": 1, "pay": 340, "rep_delta": 3, "rep": 53, "cash": 1280, "grade": "B", "fired": false, "final": false, "ending": ""})
	rep.show_report(data)
	await _wait(6)
	_audit("day report", [{"r": rep._button, "id": "button"}])
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
