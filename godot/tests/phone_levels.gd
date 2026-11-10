extends SceneTree
# gdlint:disable=max-line-length
# R16 leftover: the relationship levels (Collection.LEVELS) are on the phone's contacts too: four pips on a cast member's row
# and "LV 2 LUNCH BUDDY" as the second line of the selected row. Clients, the pizza place and a game without a campaign have none.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/phone_levels.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var soc := root.get_node("Social")
	var phone := root.get_node("Phone")
	var calls: Script = load("res://scripts/phone_calls.gd")
	var coll: Script = load("res://scripts/collection.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- no campaign: nobody has a level
	var dan0: Dictionary = calls.find("w:Dan")
	_check(not dan0.is_empty() and calls.level(dan0) == -1 and calls.level_text(dan0) == "", "outside a campaign a contact has no level")
	_check(calls.row_sub(dan0, true) == str(dan0.sub), "and the selected row shows the role")

	c.new_game("tech")
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1
	var dan: Dictionary = calls.find("w:Dan")
	_check(calls.level(dan) == 0 and calls.level_text(dan) == "LV 0 NEW FACE", "a new run: Dan is LV 0 NEW FACE")
	for step in [[10, 1], [25, 2], [45, 3], [70, 4], [100, 4], [-20, 0]]:
		soc.rel["Dan"] = int(step[0])
		_check(calls.level(dan) == int(step[1]) and calls.level(dan) == coll.level("Dan"), "Dan at %d is level %d, the collection page's number" % step)
	soc.rel["Dan"] = 30
	_check(calls.level_text(dan) == "LV 2 LUNCH BUDDY", "the text names the level")
	_check(calls.row_sub(dan, false) == str(dan.sub) and calls.row_sub(dan, true) == "LV 2 LUNCH BUDDY", "the row shows the role, the selected row the level")
	phone.call_cd[str(dan.id)] = calls.now_hours() + 2.0
	_check(calls.row_sub(dan, true) == "LATER", "somebody who is not taking calls reads LATER as before")
	phone.call_cd.erase(str(dan.id))
	# the senior tech has his own number: he is a cast member too
	var adam: Dictionary = calls.find("adam")
	if soc.people().has("Adam") and not adam.is_empty():
		soc.rel["Adam"] = 50
		_check(calls.level(adam) == 3 and calls.row_sub(adam, true) == "LV 3 FRIEND", "Adam's own number shows his level")
	var levelled := 0
	for ct in calls.contacts():
		var lv: int = calls.level(ct)
		if str(ct.kind) in ["client", "pizza"]:
			_check(lv == -1 and calls.row_sub(ct, true) == str(ct.sub), "%s has no level" % str(ct.name))
		elif lv >= 0:
			levelled += 1
	_check(levelled >= 4, "the cast in the contacts have levels (%d of them)" % levelled)
	_check(calls.LEVEL_PIPS == coll.LEVELS.size() - 1, "one pip per level above NEW FACE")

	# ---- the contacts page draws with the pips on both phones (no script error), the selected row on a cast member
	var list: Array = calls.contacts()
	var at := 0
	for i in list.size():
		if str(list[i].id) == "w:Dan":
			at = i
	for skin in ["android", "ios"]:
		phone.os = skin
		phone.open()
		phone.activate("app:phone")
		phone.ph_view = "contacts"
		phone.ph_sel = at
		phone._canvas.queue_redraw()
		await process_frame
		await process_frame
		_check(phone.is_open and phone.app == "phone" and phone.ph_sel == at, "the contacts page is up on %s with Dan selected" % skin)
		phone.close()
		await create_timer(0.4).timeout
	print("phone_levels: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
