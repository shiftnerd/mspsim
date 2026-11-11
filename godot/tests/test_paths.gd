extends SceneTree
# gdlint:disable=max-line-length
# X13: a test run never reads or writes the player's own files. The settings file and the save / career prefix get the
# per-process test name before ANY autoload is ready (Difficulty._init and Campaign._init), so an autoload that loads before
# them reads the test's file too: Msp reads the TICKET PACE in its _ready, twenty autoloads before Difficulty is ready, and used
# to read it from the real user://mspsim_settings.cfg (a RELAXED or BUSY pace there changed the day cap of every tech test).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/test_paths.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var pid := OS.get_process_id()
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var career := root.get_node("Career")
	var own_settings := "user://test_%d_settings.cfg" % pid
	_check(str(d.settings_path) == own_settings, "the settings file is the test's own (%s)" % d.settings_path)
	_check(str(c.save_prefix) == "user://test_%d_" % pid, "saves, the career and the meta file have the test's prefix (%s)" % c.save_prefix)
	_check(str(msp.pace_path) == own_settings, "Msp read the ticket pace from the test's file at boot, not from the player's (%s)" % msp.pace_path)
	_check(msp.pace_setting == 1, "so the pace is NORMAL whatever the player's own setting is (%s)" % msp.pace_label())
	_check(str(root.get_node("Sfx").settings_path) == own_settings, "the sound settings too (%s)" % root.get_node("Sfx").settings_path)
	# X13 hygiene: the phone's file and the remapped keys are the test's own too (each autoload's _init)
	var ph := root.get_node("Phone")
	var ctl := root.get_node("Controls")
	_check(str(ph.save_path) == "user://test_%d_phone.cfg" % pid, "the phone's file is the test's own (%s)" % ph.save_path)
	_check(str(ctl.binds_path) == "user://test_%d_controls.cfg" % pid, "the remapped keys are the test's own (%s)" % ctl.binds_path)
	ph.os = "pear"
	ph._save()
	_check(FileAccess.file_exists("user://test_%d_phone.cfg" % pid), "a saved phone setting lands in the test's file")
	ph.os = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(ph.save_path)))
	ctl.rebind("interact", KEY_T)
	ctl.save_binds()
	_check(FileAccess.file_exists("user://test_%d_controls.cfg" % pid), "a remapped key lands in the test's file")
	ctl.reset_binds()
	ctl.save_binds()
	_check(not FileAccess.file_exists("user://test_%d_controls.cfg" % pid), "and putting the keys back removes it again")
	# the autoload order is what made the old place (_ready) too late: Msp is ready before Difficulty
	_check(msp.get_index() < d.get_index() and msp.get_index() < c.get_index(), "Msp is an earlier autoload than Difficulty and Campaign (%d < %d, %d)" % [msp.get_index(), d.get_index(), c.get_index()])
	# the career file follows the prefix
	var career_path := ""
	for m in ["path", "_path", "file_path"]:
		if career.has_method(m):
			career_path = str(career.call(m))
	_check(career_path == "" or career_path.begins_with("user://test_%d_" % pid), "the career file is under the prefix (%s)" % career_path)
	# a pace saved by this test lands in its own file and is read back from there
	msp.set_pace(2)
	msp.save_pace()
	msp.set_pace(1)
	msp.load_pace()
	_check(msp.pace_setting == 2 and FileAccess.file_exists(own_settings), "a saved pace goes to the test's file and comes back from it")
	msp.set_pace(1)
	msp.save_pace()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(own_settings))
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
