extends SceneTree
# Three save slots per campaign mode (roadmap R19): slot 1 is the original file (an old save loads unchanged), slots 2
# and 3 add _s2 / _s3; the end-of-day save and the mid-day resume point (and its .bak) are per slot; finishing or being
# fired deletes only the active slot; Year 2 stays global per mode; the title picks the lowest empty slot for a new run
# and asks which full slot to overwrite (CANCEL keeps all three). Saves go to user://test_<pid>_*.

var failures := 0
var c: Node
var y: Node
var cards: Node
var world: Node
var title: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 30:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _ids() -> Array:
	return title._items.map(func(i: Dictionary) -> String: return i.id)


func _labels() -> Array:
	return title._items.map(func(i: Dictionary) -> String: return i.label)


# a minimal end-of-day save in slot n
func _put(mode: String, n: int, day: int, extra := {}) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "day", day)
	cfg.set_value("campaign", "year", 1)
	for key in extra:
		cfg.set_value("campaign", key, extra[key])
	cfg.save(c.save_path(mode, n))


func _wipe() -> void:
	for mode in ["tech", "owner", "service", "sales"]:
		for n in range(1, 4):
			c.delete_slot(mode, n)
	DirAccess.remove_absolute(y.meta_path())
	c.slot = 1


func _fresh_title() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	await process_frame
	title = current_scene
	title._open_menu()
	title._show_top(0)


func _init() -> void:
	await process_frame
	c = root.get_node("Campaign")
	y = root.get_node("Yeartwo")
	cards = root.get_node("Cards")
	world = root.get_node("World")
	c.save_prefix = "user://test_sl_%d_" % OS.get_process_id()
	_wipe()

	# ---- paths: slot 1 is the old name, every file wears the test prefix
	_check(c.save_path("tech") == c.save_prefix + "tech.cfg" and c.save_path("tech", 1) == c.save_path("tech"), "slot 1 keeps the old file name")
	_check(c.save_path("tech", 2) == c.save_prefix + "tech_s2.cfg" and c.save_path("owner", 3) == c.save_prefix + "owner_s3.cfg", "slots 2 and 3 add _s2 / _s3")
	_check(c.resume_path("tech") == c.save_prefix + "tech_resume.cfg" and c.resume_path("tech", 3) == c.save_prefix + "tech_s3_resume.cfg", "resume files per slot")
	c.slot = 2
	_check(c.save_path("tech") == c.save_path("tech", 2) and c.resume_path("tech") == c.resume_path("tech", 2), "the active slot is the default")
	c.slot = 1
	var all_prefixed := true
	for mode in ["tech", "owner", "service", "sales"]:
		for n in range(1, 4):
			all_prefixed = all_prefixed and c.save_path(mode, n).begins_with("user://test_sl_") and c.resume_path(mode, n).begins_with("user://test_sl_")
	_check(all_prefixed, "the per-process test prefix applies to every slot file")

	# ---- an old save (no slot keys) loads as slot 1, unchanged
	var old := ConfigFile.new()
	old.set_value("campaign", "day", 4)
	old.set_value("campaign", "rep", 61)
	old.set_value("campaign", "cash", 123)
	old.save(c.save_prefix + "tech.cfg")  # exactly where an earlier build wrote it
	_check(c.has_save("tech", 1) and c.saved_day("tech") == 4, "the old file is slot 1")
	var s1: Dictionary = c.slot_info("tech", 1)
	_check(bool(s1.exists) and int(s1.day) == 4 and str(s1.tag) == "" and str(s1.character_name) == "ADULT", "slot_info of the old save: %s" % str(s1))
	_check(not bool(c.slot_info("tech", 2).exists) and c.first_empty_slot("tech") == 2, "slots 2 and 3 are empty, the lowest empty is 2")
	_check(c.continue_game("tech") and c.day == 4 and c.rep == 61 and c.cash == 123 and c.slot == 1, "an old save continues unchanged in slot 1")

	# ---- slots 1 and 3 hold different runs and continue independently
	c.new_game("tech")
	_drain()
	c.slot = 3
	c.day = 9
	c.rep = 70
	c.cash = 777
	c.save()
	_check(FileAccess.file_exists(c.save_prefix + "tech_s3.cfg") and not FileAccess.file_exists(c.save_prefix + "tech_s2.cfg"), "a save in slot 3 writes the _s3 file only")
	_check(c.saved_day("tech", 1) == 4 and c.saved_day("tech", 3) == 9, "slot 1 is untouched by the save in slot 3")
	_check(c.first_empty_slot("tech") == 2, "slot 2 is still the lowest empty")
	c.slot = 1
	_check(c.continue_game("tech") and c.day == 4 and c.cash == 123, "continue slot 1")
	c.slot = 3
	_check(c.continue_game("tech") and c.day == 9 and c.rep == 70 and c.cash == 777, "continue slot 3")
	_drain()
	var info3: Dictionary = c.slot_info("tech", 3)
	_check(int(info3.day) == 9 and not bool(info3.has_resume), "slot_info of slot 3: day 9, no resume point")
	_put("tech", 2, 2, {"year": 2, "look": {"active": true, "name": "jamie"}})
	var info2: Dictionary = c.slot_info("tech", 2)
	_check(str(info2.tag) == " (YEAR 2)" and str(info2.character_name) == "JAMIE", "slot_info: the Year 2 tag and the custom person's name: %s" % str(info2))
	_check(y.saved_tag("tech", 2) == " (YEAR 2)" and y.saved_tag("tech", 1) == "", "Yeartwo.saved_tag per slot")
	_check(c.first_empty_slot("tech") == 0, "all three full: no empty slot")
	c.delete_slot("tech", 2)
	_check(not c.has_save("tech", 2) and c.has_save("tech", 1) and c.has_save("tech", 3), "delete_slot removes one slot only")

	# ---- the mid-day resume point and its .bak are per slot
	c.slot = 3
	c.continue_game("tech")
	_drain()
	world.clock = 12.0
	_check(c.can_snapshot() and c.snapshot() and c.snapshot(), "snapshots written in slot 3")
	_check(FileAccess.file_exists(c.save_prefix + "tech_s3_resume.cfg") and FileAccess.file_exists(c.save_prefix + "tech_s3_resume.cfg.bak"), "slot 3 has its resume file and the .bak")
	_check(not FileAccess.file_exists(c.save_prefix + "tech_resume.cfg") and not FileAccess.file_exists(c.save_prefix + "tech_s2_resume.cfg"), "no resume file in the other slots")
	_check(not c.resume_info("tech", 3).is_empty() and int(c.resume_info("tech", 3).day) == 9 and c.resume_info("tech", 1).is_empty(), "resume_info per slot")
	var s3: Dictionary = c.slot_info("tech", 3)
	_check(bool(s3.has_resume) and bool(s3.has_save) and str(s3.text).begins_with("12:"), "slot_info: both kinds of save, clock %s" % str(s3.text))
	c.new_game("free")
	c.slot = 3
	_check(c.continue_game("tech", true) and c.day == 9 and absf(world.clock - 12.0) < 0.05, "resume slot 3 returns to 12:00 of day 9")
	_drain()
	# a resume point in slot 1 stays when slot 3 is cleared
	var f := FileAccess.open(c.resume_path("tech", 1), FileAccess.WRITE)
	f.store_string("keep me")
	f.close()
	c.clear_resume("tech")  # the active slot (3)
	_check(not FileAccess.file_exists(c.resume_path("tech", 3)) and not FileAccess.file_exists(c.resume_path("tech", 3) + ".bak"), "clear_resume clears the active slot")
	_check(FileAccess.file_exists(c.resume_path("tech", 1)), "... and leaves slot 1's file")

	# ---- finishing slot 3 deletes slot 3 only; Year 2 is a per-mode unlock
	_check(not y.available("tech"), "no Year 2 before a finished year")
	c.slot = 3
	c.continue_game("tech")
	_drain()
	world.clock = 12.0
	c.snapshot()
	_check(c.has_save("tech", 3) and FileAccess.file_exists(c.resume_path("tech", 3)), "slot 3 has save and resume before the end")
	c.finish_campaign("lead")
	_check(not c.has_save("tech", 3) and not FileAccess.file_exists(c.resume_path("tech", 3)), "finishing deletes slot 3's save and resume file")
	_check(c.has_save("tech", 1) and c.saved_day("tech", 1) == 4 and FileAccess.file_exists(c.resume_path("tech", 1)), "... and keeps slot 1")
	_check(y.available("tech") and not y.available("owner"), "Year 2 is unlocked for the mode, not the slot")
	_check(str(y.meta_get("tech").ending) == "lead", "the ending went to the global meta")

	# ---- being fired deletes the active slot only
	root.get_node("Game").title_mode = false
	_put("owner", 1, 3)
	_put("owner", 2, 6)
	c.slot = 2
	_check(c.continue_game("owner") and c.day == 6, "continue owner slot 2")
	c._fired_out = true
	c.report_continue(true)
	_check(not c.has_save("owner", 2) and c.has_save("owner", 1), "fired in slot 2: slot 2 gone, slot 1 kept")
	c._fired_out = false
	root.get_node("Game").title_mode = false

	# ---- the title: lowest empty slot, the slot rows, the overwrite question
	_wipe()
	var meta := ConfigFile.new()
	y.record(meta, "tech", "lead")
	meta.save(y.meta_path())
	_put("tech", 1, 4)
	_put("tech", 3, 9, {"year": 2})
	await _fresh_title()
	_check(_ids().size() == 4, "four play lines")
	title._show_top(0)
	title._choose(0)
	_check(title._level == "sub" and _ids() == ["tech_slot1", "tech_slot3", "tech_y2", "tech_new", "tech_delask"], "submenu rows %s" % str(_ids()))
	_check(str(title._items[0].label).begins_with("SLOT 1 - DAY 4") and str(title._items[1].label).begins_with("SLOT 3 - DAY 9 (YEAR 2)"), "slot rows: %s" % str(_labels()))
	title._sel = 3
	title._choose(3)  # NEW CAMPAIGN with slot 2 empty
	_check(title._select != null and title._slot == 2 and not title._overwrite, "NEW CAMPAIGN uses the lowest empty slot without asking")
	title._close_select()
	title._choose(2)  # START YEAR 2 also takes the empty slot
	_check(title._select != null and title._slot == 2 and y.pending, "START YEAR 2 uses the first empty slot")
	title._close_select()
	_put("tech", 2, 6)
	title._show_sub("tech", 0)
	title._sel = _ids().find("tech_new")
	title._choose(title._sel)  # NEW CAMPAIGN with all three full
	_check(title._select == null and title._level == "over" and title._heading == "OVERWRITE WHICH SLOT?", "all full: the overwrite question")
	_check(_ids() == ["tech_over1", "tech_over2", "tech_over3", "cancel"], "overwrite rows %s" % str(_ids()))
	_check(str(title._items[1].label).begins_with("OVERWRITE SLOT 2 - DAY 6"), "overwrite labels: %s" % str(_labels()))
	title._choose(3)  # CANCEL
	_check(title._level == "sub" and title._select == null, "CANCEL returns to the submenu")
	_check(c.has_save("tech", 1) and c.has_save("tech", 2) and c.has_save("tech", 3) and c.saved_day("tech", 2) == 6, "cancel keeps all three saves")
	title._choose(_ids().find("tech_new"))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	title._unhandled_input(esc)
	_check(title._level == "sub" and c.has_save("tech", 1) and c.has_save("tech", 2) and c.has_save("tech", 3), "Esc also backs out and keeps all three")
	title._choose(_ids().find("tech_new"))
	title._choose(1)  # OVERWRITE SLOT 2
	_check(title._select != null and title._slot == 2 and title._overwrite, "picking a slot opens the character select for it")
	_check(c.has_save("tech", 2), "... nothing is deleted before the run starts")
	title._close_select()
	title._overwrite = true
	title._slot = 2
	title._start("tech_new")
	await create_timer(1.2).timeout
	_check(c.active and c.mode == "tech" and c.slot == 2 and not c.has_save("tech", 2), "starting replaces slot 2 only")
	_check(c.has_save("tech", 1) and c.has_save("tech", 3) and c.saved_day("tech", 3) == 9, "slots 1 and 3 are untouched")
	# a slot with both kinds of save asks CONTINUE / FROM THE START; one kind goes straight in
	c.active = false
	c.mode = ""
	root.get_node("Game").title_mode = true
	world.time_scale = 0.0
	await _fresh_title()
	c.slot = 3
	c.continue_game("tech")
	_drain()
	root.get_node("Game").title_mode = false
	world.clock = 12.0
	_check(c.snapshot(), "a resume point in slot 3")
	c.active = false
	c.mode = ""
	root.get_node("Game").title_mode = true
	world.time_scale = 0.0
	await _fresh_title()
	title._show_top(0)
	title._choose(0)
	var row3 := _ids().find("tech_slot3")
	title._choose(row3)
	_check(title._level == "slot" and title._heading == "SLOT 3" and _ids() == ["tech_resume", "tech_continue"], "slot 3 (both kinds) asks: %s" % str(_labels()))
	title._choose(1)  # FROM THE START
	await process_frame
	_check(c.active and c.slot == 3 and c.day == 9 and c.mode == "tech", "FROM THE START continues slot 3 at its day start")

	# ---- R19: DELETE A SLOT (a list, then a question; nothing is erased until YES)
	_wipe()
	_put("tech", 1, 4)
	_put("tech", 2, 6)
	c.active = false
	c.mode = ""
	root.get_node("Game").title_mode = true
	world.time_scale = 0.0
	await _fresh_title()  # the last run started: a new title screen
	title._show_top(0)
	title._choose(0)
	_check(_ids() == ["tech_slot1", "tech_slot2", "tech_new", "tech_delask"], "the submenu offers DELETE A SLOT when something is saved: %s" % str(_ids()))
	title._choose(_ids().find("tech_delask"))
	_check(title._level == "del" and title._heading == "DELETE WHICH SLOT?" and _ids() == ["tech_del1", "tech_del2", "cancel"], "the list names the saved slots and CANCEL: %s" % str(_ids()))
	_check(str(title._items[1].label).begins_with("DELETE SLOT 2 - DAY 6") and title._items[title._sel].id == "cancel", "labels say what goes, the cursor starts on CANCEL: %s" % str(_labels()))
	title._choose(1)  # DELETE SLOT 2
	_check(title._level == "del" and title._heading == "ERASE SLOT 2 FOR GOOD?" and _ids() == ["tech_delyes2", "cancel"], "the question: %s" % str(_ids()))
	_check(c.has_save("tech", 2) and title._items[title._sel].id == "cancel", "nothing is erased yet and the cursor starts on KEEP IT")
	title._choose(1)  # KEEP IT
	_check(title._level == "sub" and c.has_save("tech", 1) and c.has_save("tech", 2), "KEEP IT goes back with both saves")
	title._choose(_ids().find("tech_delask"))
	title._choose(1)
	var esc2 := InputEventKey.new()
	esc2.keycode = KEY_ESCAPE
	esc2.pressed = true
	title._menu_open = true
	title._unhandled_input(esc2)
	_check(title._level == "sub" and c.has_save("tech", 2), "Esc backs out of the question and keeps the slot")
	title._choose(_ids().find("tech_delask"))
	title._choose(1)
	title._choose(0)  # YES, DELETE SLOT 2
	_check(not c.has_save("tech", 2) and c.has_save("tech", 1) and title._level == "sub", "YES erases slot 2 only")
	_check(_ids() == ["tech_slot1", "tech_new", "tech_delask"], "and the submenu no longer lists it: %s" % str(_ids()))
	c.delete_slot("tech", 1)
	title._show_sub("tech", 0)
	_check(_ids() == ["tech_new"], "with nothing saved there is nothing to delete: %s" % str(_ids()))

	_wipe()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
