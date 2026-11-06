extends SceneTree
# NPCs react: a seated worker whose network is down stops typing and grumbles, someone goes to the
# closet if it stays down, and when you switch the lights off someone switches them back on.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	await process_frame
	var world := root.get_node("World")
	var net := root.get_node("Net")
	var campaign := root.get_node("Campaign")
	root.get_node("Game").title_mode = false
	campaign.new_game(campaign.FREE)
	world.time_scale = 1.0

	# ---- the lights go off in Office 1 with Alan at his desk
	world.chars["Alan"].scene = "office_one"
	world.force_activity("Alan", "work")
	change_scene_to_file("res://scenes/office_one.tscn")
	await _wait_frames(40)
	var alan := current_scene.get_node("Actors/Alan")
	if alan.seat == null:
		alan._occupy("Seat1", true)
	_check(
		alan.seat != null and world.lights_on("office_one"),
		"Alan is at his desk, the lights are on"
	)
	world.set_lights("office_one", false)
	await _wait_frames(180)
	_check(alan._bubble.visible or alan._grumble_t > 0.0, "he grumbles when the lights go out")
	var on := false
	for i in 1500:
		await process_frame
		if world.lights_on("office_one"):
			on = true
			break
	_check(on, "he gets up and turns them back on (after %d frames)" % 0)
	await _wait_frames(60)
	_check(not world.lights_by_npc, "(the NPC flag is cleared)")

	# ---- NPCs flipping lights themselves are not reacted to
	var before_count := 0
	world.lights_by_npc = true
	world.set_lights("office_one", false)
	world.lights_by_npc = false
	await _wait_frames(200)
	_check(
		not world.lights_on("office_one") and before_count == 0,
		"lights switched by a coworker are left alone"
	)
	world.set_lights("office_one", true)

	# ---- the network goes down at a desk
	world.chars["Dan"].scene = "main_floor"
	world.force_activity("Dan", "work")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait_frames(40)
	var dan := current_scene.get_node("Actors/Dan")
	if dan.seat == null:
		dan._occupy("Seat3", true)
	_check(
		dan.seat != null and not dan._offline and dan._rest_anim() == "type",
		"Dan types at his desk"
	)
	var saved: String = net.cables["p3"].end
	net.cables["p3"].end = ""
	await _wait_frames(30)
	_check(dan._offline and dan._rest_anim() == "sit", "network down: he stops typing")
	await _wait_frames(200)
	_check(dan._bubble.visible or dan._grumble_t > 0.0, "and grumbles")
	world._outage_t = 15.0
	for who in ["Dan", "Alan", "Garrison", "John", "Maya"]:
		world.chars[who].legs = [{"kind": "coffee", "dur": 30.0, "routine": PackedStringArray()}]
	world.chars["Dan"].scene = "kitchenette"
	world._closet_sent = false
	world._watch_outage(0.1)
	_check(not world._closet_sent, "nobody free: it keeps trying instead of giving up")
	world.chars["Dan"].scene = "main_floor"
	world._closet_sent = false
	world.chars["Alan"].scene = "office_one"
	world.force_activity("Alan", "work")
	world._watch_outage(0.1)
	var sent := ""
	for who in ["Dan", "Alan", "Garrison"]:
		for leg in world.chars[who].legs:
			if str(leg.get("kind", "")) == "closet":
				sent = who
	_check(sent != "", "after a while somebody goes to the closet to look (%s)" % sent)
	net.cables["p3"].end = saved
	await _wait_frames(40)
	_check(not dan._offline, "the network is back: he types again")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
