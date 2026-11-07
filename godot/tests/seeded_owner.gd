extends SceneTree
# R1: Owner, Shift and Projects draw from the run's seeded streams, so the same seed gives the same candidates and rolls.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _names(cands: Array) -> Array:
	return cands.map(func(c: Dictionary) -> String: return str(c.get("name", "")) + str(c.get("skill", "")))


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var diff := root.get_node("Difficulty")
	var owner := root.get_node("Owner")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("owner")
	diff.seed_run(5)
	var a: Array = _names(owner.make_candidates())
	diff.seed_run(5)
	var b: Array = _names(owner.make_candidates())
	diff.seed_run(6)
	var other: Array = _names(owner.make_candidates())
	_check(a.size() > 0 and a == b, "the same seed gives the same hiring candidates")
	_check(a != other, "another seed gives other candidates")
	var src := ""
	for f in ["owner", "shift", "projects", "growth"]:
		src += FileAccess.get_file_as_string("res://scripts/%s.gd" % f)
	var raw := RegEx.create_from_string(r"(^|[^.\w])(randf|randi|randf_range|randi_range)\(")
	_check(raw.search(src) == null, "no global randf / randi call is left in Owner, Shift, Projects or Growth")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
