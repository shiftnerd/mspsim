extends SceneTree
# The RMM endpoint tree scrolls: with every client open the list is longer than the window, and
# every machine of every client (Piedmont Pediatrics included) can be reached with the wheel.

var frame := 0
var failures := 0
var seen := {}
var step := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var comp := root.get_node("Computer")
	if frame == 5:
		var c := root.get_node("Campaign")
		c.new_game(c.FREE)
		root.get_node("Game").title_mode = false
		root.get_node("Sales").active = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
		comp.open(1)
		comp.app = "rmm"
		comp.rmm_tab = "endpoints"
		comp.rmm_session = false
		comp.rmm_detail = false
		for i in 11:
			comp.rmm_open[i] = true
	elif frame > 8 and step < 40:
		for h in comp._hits:
			if str(h.id).begins_with("rmm:"):
				seen[str(h.id)] = true
		comp.scroll_list(1)
		step += 1
	elif step >= 40:
		var total := 0
		for ep in root.get_node("Msp").endpoints:
			total += 1
		_check(comp.rmm_scroll > 0, "the tree scrolls (%d px)" % comp.rmm_scroll)
		_check(seen.size() == total, "every machine was reachable: %d of %d" % [seen.size(), total])
		comp.scroll_list(-100)
		comp._canvas.queue_redraw()
		print("failures=", failures)
		quit(1 if failures > 0 else 0)
	return false
