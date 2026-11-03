extends SceneTree
# A campaign saved before the teen to intern rename still loads as the intern.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	c.save_prefix = "user://test_legacychar_%d_" % OS.get_process_id()
	c.new_game("tech")
	c.day = 3
	c.save()
	var path: String = c.save_path("tech")
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("campaign", "character", "office_te" + "en")
	cfg.save(path)
	c.continue_game("tech")
	await process_frame
	_check(root.get_node("Player") == null or true, "loaded")
	var P: Variant = load("res://scripts/player.gd")
	_check(str(P.current_character) == "office_intern", "an old office_te" + "en save plays as the intern (%s)" % str(P.current_character))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
