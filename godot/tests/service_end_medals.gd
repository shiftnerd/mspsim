extends SceneTree
# C7: the service endings earn Career medals (ops manager, right hand, Summit director); cozy runs do not count.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var career := root.get_node("Career")
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	career.toasts = false
	career.counters = {}
	career.earned = {}
	camp.new_game("service")
	root.get_node("Difficulty").tier = "normal"
	career.note_ending("stay")
	career.check_medals()
	_check(not career.has_medal("svc_ops") and not career.has_medal("svc_hand"), "staying earns none of them")
	career.note_ending("alan")
	career.check_medals()
	_check(career.has_medal("svc_hand"), "backing Alan earns RIGHT HAND")
	career.note_ending("ops")
	career.note_ending("rollup_yes")
	career.check_medals()
	_check(career.has_medal("svc_ops") and career.has_medal("svc_summit"), "the ops and Summit endings earn theirs")
	DirAccess.remove_absolute(career.path())
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
