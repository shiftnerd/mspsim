extends SceneTree
# Regression: planning for someone outside the building must not crash (it routed through the
# "__outside__" pseudo-scene) and must give them a way back (or keep them out after closing time).


func _init() -> void:
	await process_frame
	var world := root.get_node("World")
	var failures := 0
	world.chars["Dan"].scene = world.OUTSIDE
	world.clock = 11.0
	var legs: Array = world._plan("Dan")
	var ok: bool = legs.size() == 1 and legs[0].get("to_scene", "") == "main_floor"
	print(("ok   " if ok else "FAIL ") + "someone outside mid-day gets a way back")
	failures += 0 if ok else 1
	world.clock = world.DAY_END + 0.5
	legs = world._plan("Dan")
	ok = legs.size() == 1 and not legs[0].has("to_scene")
	print(("ok   " if ok else "FAIL ") + "after closing they stay out")
	failures += 0 if ok else 1
	ok = world._route(world.OUTSIDE, "main_floor").is_empty()
	print(("ok   " if ok else "FAIL ") + "routing from outside is empty, not an error")
	failures += 0 if ok else 1
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
