extends SceneTree
# C7: the Summit auditor (Ms. Pell) walks the main floor on the diligence day of the sales campaign, and only then.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _stage() -> Node:
	var st := Node.new()
	st.scene_file_path = "res://scenes/main_floor.tscn"
	var actors := Node.new()
	actors.name = "Actors"
	st.add_child(actors)
	root.add_child(st)
	return st


func _count(st: Node) -> int:
	var n := 0
	for a in st.get_node("Actors").get_children():
		n += 1 if str(a.get("role")) == "visitor:auditor" else 0
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("sales")
	var sb := load("res://scripts/sales_beats.gd")
	c.day = 18
	var st := _stage()
	sb.auditor(st)
	_check(_count(st) == 0, "no auditor before the diligence day")
	st.queue_free()
	c.day = 19
	st = _stage()
	sb.auditor(st)
	_check(_count(st) == 1, "the auditor is on the main floor on the diligence day")
	st.queue_free()
	c.new_game("tech")
	c.day = 19
	st = _stage()
	sb.auditor(st)
	_check(_count(st) == 0, "and not in another campaign")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
