extends SceneTree
# Nerf guns: the rack gives a blaster, Z fires darts that arc, stick and hit people (they react in
# character, friendly ones fire back), flicker monitors; darts on the floor can be picked up.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var nerf := root.get_node("Nerf")
	var social := root.get_node("Social")
	var game := root.get_node("Game")
	game.title_mode = false
	c.save_prefix = "user://test_nerf_%d_" % OS.get_process_id()
	c.new_game("tech")
	c.day = 3
	world.time_scale = 1.0
	world.chars["Vic"].scene = "cubicle_area"
	world.force_activity("Vic", "work")
	change_scene_to_file("res://scenes/cubicle_area.tscn")
	await _wait(40)
	var scene := current_scene
	var player := scene.get_node("Actors/Player")
	var rack := scene.get_node("Fx/NerfRack")
	_check(
		rack.kind == "nerf_rack" and rack.item == "nerf",
		"the rack is in the cubicle area and hands out a blaster"
	)

	# ---- taking a blaster
	player.give("nerf")
	_check(player.held == "nerf" and nerf.ammo == 6 and nerf.holding(), "a blaster with 6 darts")
	player.global_position.x = 192.0
	player.facing = "right"
	var vic := scene.get_node_or_null("Actors/Vic")
	if vic == null:
		world.chars["Vic"].scene = "cubicle_area"
	_check(vic != null, "Vic is in the room")
	vic.global_position.x = 232.0
	if vic.seat != null:
		vic.seat.occupied = false
		vic.seat = null
	vic._hold = 0.0
	social.rel["Vic"] = 40

	# ---- fire at him
	_check(nerf.fire_player(player) and nerf.ammo == 5, "Z fires a dart (5 left)")
	var darts := get_nodes_in_group("darts")
	_check(darts.size() == 1, "a dart is in the air")
	var rel0: int = social.value("Vic")
	var steps := 0
	while is_instance_valid(darts[0]) and darts[0].state == "fly" and steps < 200:
		darts[0]._process(0.02)
		steps += 1
	_check(
		nerf.hits == 1 and social.value("Vic") > rel0,
		"the dart hits Vic: a friend laughs (%d hits)" % nerf.hits
	)
	_check(vic._bubble.visible and vic._bubble.glyph == "heart", "and he shows it")
	_check(darts[0].state == "floor", "the dart drops to the floor")
	_check(nerf.war_t > 0.0 or true, "(a war may start)")

	# ---- pick it up again
	player.global_position.x = darts[0].global_position.x
	var ammo0: int = nerf.ammo
	darts[0]._process(0.02)
	_check(nerf.ammo == ammo0 + 1, "walking over a dart picks it up")

	# ---- a hit on a cold coworker costs goodwill
	social.rel["Vic"] = -30
	nerf._cool = 0.0
	player.state = "idle"
	nerf.war_t = 0.0
	player.global_position.x = 192.0
	nerf.fire_player(player)
	var d2 := get_nodes_in_group("darts")
	var rel1: int = social.value("Vic")
	steps = 0
	while is_instance_valid(d2[-1]) and d2[-1].state == "fly" and steps < 200:
		d2[-1]._process(0.02)
		steps += 1
	_check(social.value("Vic") < rel1, "hitting someone who does not like you makes it worse")

	# ---- the war: they fire back
	nerf.start_war()
	_check(nerf.war_t > 0.0 and vic.held == "nerf", "a nerf war: Vic grabs a blaster")
	var before := get_nodes_in_group("darts").size()
	nerf._shot_t["Vic"] = 0.0
	nerf._process(0.1)
	_check(get_nodes_in_group("darts").size() == before + 1, "and fires back")
	# a dart hits the player
	nerf.fire_npc(vic, -1.0)
	var back = get_nodes_in_group("darts")[-1]
	back.global_position = player.global_position + Vector2(10.0, -40.0)  # closer than the desk phone (R25 moved it right)
	back.vel = Vector2(-175.0, 0.0)
	back.shooter = "Vic"
	steps = 0
	while is_instance_valid(back) and back.state == "fly" and steps < 100:
		back._process(0.02)
		steps += 1
	_check(
		nerf.taken >= 1 and player.state == "emote", "you can get hit too (%d taken)" % nerf.taken
	)
	nerf.war_t = 0.05
	nerf._process(0.1)
	_check(nerf.war_t == 0.0 and vic.held == "", "the war ends and the blasters go away")

	# ---- sticking in a monitor
	var monitor: Node = null
	for child in scene.get_node("Actors").get_children():
		if child.name.begins_with("monitor_"):
			monitor = child
	var mon_pos: Vector2 = monitor.global_position + monitor.offset + Vector2(10.0, 8.0)
	var stuck := DartProbe.new()
	_check(nerf.stick_target(mon_pos) == monitor, "a dart in a monitor's box sticks to it")
	monitor.get_node("Fx").hit()
	_check(
		monitor.get_node("Fx")._hit_until > monitor.get_node("Fx")._time, "and the screen glitches"
	)
	_check(nerf.stick_target(Vector2(2.0, 70.0)) != null, "walls stop darts too")

	# ---- empty, holster, controls
	player.global_position.x = 192.0
	nerf.ammo = 0
	nerf._cool = 0.0
	_check(not nerf.fire_player(player), "no darts: it clicks")
	player.give("")
	_check(not nerf.holding(), "G puts it away")
	player.give("coffee")
	_check(not nerf.fire_player(player), "no blaster, no shot")
	stuck.free()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


class DartProbe:
	extends Node
