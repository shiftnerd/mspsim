extends SceneTree
# gdlint:disable=max-line-length
# Q6: a body the World has let go of must not speak for its person any more. World.begin_next_day (a new day, a new game) drops
# every cast member's body; before, the body stayed in the scene with `_leaving` set, kept running its old routine and, when
# that ran out, called World.leg_done for its person: the new day's plan of that person was thrown away at a moment that
# depended on a routine from before the new game. In the bot runs that made the same seed two different owner campaigns.
#   - begin_next_day frees the bodies of the day before
#   - a leaving body that finishes its routine does not touch its person's plan, and its "exit" step does nothing
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/npc_leaving.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var world := root.get_node("World")
	var c := root.get_node("Campaign")
	c.save_prefix = "user://test_%d_leaving_" % OS.get_process_id()
	root.get_node("Difficulty").settings_path = "user://test_%d_leaving_settings.cfg" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	change_scene_to_file("res://scenes/main_floor.tscn")
	for i in 20:
		await process_frame
	var bodies := []
	for n in world.chars:
		var st: Dictionary = world.chars[n]
		if st.node != null and is_instance_valid(st.node):
			bodies.append([n, st.node])
	_check(bodies.size() >= 2, "the office floor has people with a body (%d)" % bodies.size())
	world.begin_next_day(2)
	var let_go := true
	for row in bodies:
		let_go = let_go and bool(row[1]._leaving) and row[1].is_queued_for_deletion() and world.chars[row[0]].node == null
	_check(let_go, "a new day lets go of every body and frees it")
	# a leaving body that runs out of steps (the frame before it is freed) leaves its person's plan alone
	var who: String = bodies[0][0]
	var body: Node = bodies[0][1]
	var st: Dictionary = world.chars[who]
	var plan_before: Array = st.legs.duplicate(true)
	var left_before: float = st.leg_t
	body._finish_routine()
	body._start(PackedStringArray(["exit"]))
	await process_frame
	# (the World's own clock keeps running: the leg's time left may only have gone down, the legs themselves are the same)
	_check(st.legs == plan_before and float(st.leg_t) <= left_before and st.scene == world.OUTSIDE, "its finished routine and its exit step do not touch the plan of %s" % who)
	await process_frame
	var gone := true
	for row in bodies:
		gone = gone and not is_instance_valid(row[1])
	_check(gone, "and the bodies are gone a frame later")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
