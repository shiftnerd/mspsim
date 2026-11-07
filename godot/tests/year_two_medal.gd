extends SceneTree
# R10: finishing a Year 2 run earns the SECOND YEAR medal (the Year 2 end counts year2_done once).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var career := root.get_node("Career")
	root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
	career.toasts = false
	career.counters = {}
	career.earned = {}
	var m: Dictionary = career.medal("year_two")
	_check(not m.is_empty() and str(m.title) == "SECOND YEAR", "the medal exists: %s" % str(m.get("desc", "")))
	_check(not career.check_medals().has("year_two") and not career.has_medal("year_two"), "not earned before a Year 2 run is finished")
	career.add("year2_runs")
	career.check_medals()
	_check(not career.has_medal("year_two"), "starting a Year 2 run is not enough")
	career.add("year2_done")
	career.check_medals()
	_check(career.has_medal("year_two"), "finishing one earns it")
	_check(not career.check_medals().has("year_two"), "and it is awarded once")
	DirAccess.remove_absolute(career.path())
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
