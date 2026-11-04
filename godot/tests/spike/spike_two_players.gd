extends SceneTree
# THROWAWAY coop spike, risk 3 and 5 (docs/coop-risk-findings.md): TWO Player bodies in main_floor, P2 driven by p2_* actions
# (a runtime copy of player.gd with the Input.* action names prefixed, the real file is not touched), then probes of every
# single-player assumption, and the group door transition with Game.go. Runs headless:
#   Godot --headless --path godot -s res://tests/spike/spike_two_players.gd
# Then grep the log for "SCRIPT ERROR" (each is a finding).

const Lib := preload("res://tests/spike/spike_lib.gd")

var fails := 0
var p1: Node
var p2: Node
var stage: Node


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func info(what: String) -> void:
	print("INFO " + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func p2_player_script() -> GDScript:
	var src := FileAccess.get_file_as_string("res://scripts/player.gd")
	for fn in ["is_action_pressed", "is_action_just_pressed", "is_action_just_released", "get_action_strength"]:
		src = src.replace('Input.%s("' % fn, 'Input.%s("p2_' % fn)
	src = src.replace('Input.get_axis("move_left", "move_right")', 'Input.get_axis("p2_move_left", "p2_move_right")')
	var s := GDScript.new()
	s.source_code = src
	if s.reload() != OK:
		push_error("p2 player script failed")
	return s


func find_doors(n: Node, out: Array) -> void:
	if n is Area2D and "target_scene" in n:
		out.append(n)
	for c in n.get_children():
		find_doors(c, out)


func find_seats(n: Node, out: Array) -> void:
	if n is Area2D and "occupied" in n and "stand_y" in n:
		out.append(n)
	for c in n.get_children():
		find_seats(c, out)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ctl := root.get_node("Controls")
	for action in ctl.ACTIONS:
		if not InputMap.has_action("p2_" + action):
			InputMap.add_action("p2_" + action, 0.5)
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_spike2_%d_" % OS.get_process_id()
	root.get_node("Difficulty").settings_path = "user://test_spike2_%d_settings.cfg" % OS.get_process_id()
	camp.new_game("tech")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(2.0).timeout
	await _wait(10)
	stage = current_scene
	p1 = stage.get_node("Actors/Player")
	var dl0 := []
	find_doors(stage, dl0)
	for d in dl0:
		info("door %s auto=%s at %s size=%s -> %s" % [d.name, d.auto, d.global_position, d.get_child(0).shape.size if d.get_child_count() > 0 and d.get_child(0) is CollisionShape2D else "?", d.target_scene])
	info("scene %s, P1 at %s state=%s" % [stage.name, p1.global_position, p1.state])
	# ---- spawn P2 the way stage.gd could: instantiate player.tscn at runtime under Actors
	var ps: PackedScene = load("res://scenes/player.tscn")
	p2 = ps.instantiate()
	p2.set_script(p2_player_script())
	p2.name = "Player2"
	p2.position = p1.global_position + Vector2(24, 0)  # BEFORE add_child: a body added at (0,0) overlaps the ExitToKitchen auto door and fires Game.go
	stage.get_node("Actors").add_child(p2)
	p2.tree_exiting.connect(func() -> void: print("INFO p2 exiting tree; scene now=", current_scene, " stage valid=", is_instance_valid(stage)); print_stack())
	p2.global_position = p1.global_position + Vector2(24, 0)
	await _wait(10)
	ok(is_instance_valid(p2) and p2.is_inside_tree(), "P2 instantiated and in the tree")
	info("group 'player' members: %d (sfx.gd get_first_node_in_group picks only the first)" % get_nodes_in_group("player").size())
	# ---- scripted input: P1 right, P2 left; separation of actions
	var x1: float = p1.global_position.x
	var x2: float = p2.global_position.x
	Input.action_press("move_right")
	await _wait(30)
	Input.action_release("move_right")
	info("after P1 walk: scene=%s p1 valid=%s p2 valid=%s" % [current_scene.name if current_scene else "none", is_instance_valid(p1), is_instance_valid(p2)])
	var dl := []
	if is_instance_valid(stage):
		find_doors(stage, dl)
		for d in dl:
			info("door %s auto=%s at %s -> %s" % [d.name, d.auto, d.global_position, d.target_scene])
	var moved1: float = p1.global_position.x - x1
	ok(moved1 > 5.0 and absf(p2.global_position.x - x2) < 1.0, "P1 walked right %.1f px while P2 (no p2 input) stayed put" % moved1)
	x2 = p2.global_position.x
	var x1b: float = p1.global_position.x
	Input.action_press("p2_move_right")
	await _wait(30)
	Input.action_release("p2_move_right")
	ok(p2.global_position.x > x2 + 5.0 and absf(p1.global_position.x - x1b) < 1.0, "P2 walked right %.1f px on p2_move_right while P1 stayed put" % (p2.global_position.x - x2))
	info("collision: p1 layer=%d mask=%d, p2 layer=%d mask=%d" % [p1.collision_layer, p1.collision_mask, p2.collision_layer, p2.collision_mask])
	# ---- doors: two bodies in one zone; one leaves; does the other keep the arrow
	var doors := []
	find_doors(stage, doors)
	var door: Node = null
	for d in doors:
		if not d.auto and d.special == "" and not d.locked and d.occupancy == "":
			door = d
			break
	ok(door != null, "found a plain door: %s -> %s (%d doors in the room)" % [door.name if door else "", door.target_scene if door else "", doors.size()])
	p1.global_position = door.global_position
	p2.global_position = door.global_position + Vector2(3, 0)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	await _wait(8)
	info("door._player after both entered = %s (only the LAST body to enter is remembered)" % [door._player.name if door._player else "null"])
	ok(p1.nearest() == door and p2.nearest() == door, "both bodies list the door in their own _near (per-body list works)")
	p2.global_position = door.global_position + Vector2(200, 0)
	p2.velocity = Vector2.ZERO
	await _wait(8)
	info("after P2 walked away, P1 still in the zone: door._player=%s arrow.visible=%s p1.nearest()==door %s" % [door._player, door._arrow.visible if door._arrow else "n/a", p1.nearest() == door])
	ok(door._player != null and door._arrow.visible, "BUG CHECK: door keeps the arrow for P1 after P2 leaves the zone")
	# ---- seats
	var seats := []
	find_seats(stage, seats)
	info("%d seats in the room" % seats.size())
	var seat: Node = seats[0]
	p1.global_position = seat.global_position
	p2.global_position = seat.global_position
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	await _wait(6)
	seat.use(p1)
	seat.use(p2)
	await _wait(4)
	info("seat.occupied=%s; P1 state=%s P2 state=%s (a seat does not know about player bodies)" % [seat.occupied, p1.state, p2.state])
	ok(p1.state in ["sitdown", "sitting"] and p2.state in ["sitdown", "sitting"] and not seat.occupied, "CONFIRMED: both players sit in the same seat, occupied stays false")
	await _wait(60)
	p1._stand_up()
	p2._stand_up()
	await _wait(40)
	# ---- NPC and fx references
	var npcs := 0
	var bound_p1 := 0
	var bound_other := 0
	for n in stage.get_node("Actors").get_children():
		if n.has_method("_follow_tick") or "_stage" in n and "custom_look" in n:
			npcs += 1
			var cached = n.get("_player")
			if cached == p1:
				bound_p1 += 1
			elif cached == p2:
				bound_other += 1
	info("NPC nodes: %d, cached _player == P1: %d, == P2: %d" % [npcs, bound_p1, bound_other])
	# ---- Game.ui_open freezes both bodies
	var gm := root.get_node("Game")
	var px1: float = p1.global_position.x
	var px2: float = p2.global_position.x
	gm.ui_open = true
	Input.action_press("move_right")
	Input.action_press("p2_move_right")
	await _wait(20)
	Input.action_release("move_right")
	Input.action_release("p2_move_right")
	gm.ui_open = false
	ok(absf(p1.global_position.x - px1) < 1.0 and absf(p2.global_position.x - px2) < 1.0, "CONFIRMED: Game.ui_open (one global) freezes BOTH bodies")
	# ---- stage camera follows only P1
	var cam: Camera2D = null
	for c in stage.get_children():
		if c is Camera2D:
			cam = c
	info("stage camera: %s, stage._player == P1: %s (stage never sees P2)" % [cam != null, stage._player == p1])
	# ---- World/cast: free cast ghost and follow target
	var w := root.get_node("World")
	info("World.player_left uses no body; cast follow 'follow me' target is the cached _player of each NPC (P1)")
	# ---- an auto edge exit touched by P2 alone
	var adoor: Node = null
	for d in doors:
		if d.auto:
			adoor = d
			break
	if adoor != null and OS.get_environment("SPIKE_AUTO") == "1":
		var an: String = adoor.name
		var at: String = adoor.target_scene
		p1.global_position = Vector2(150, 118)
		p2.global_position = adoor.global_position
		await create_timer(0.8).timeout
		await _wait(10)
		info("P2 alone touched auto door '%s' -> %s: scene now %s, P1 valid=%s, P2 valid=%s" % [an, at, current_scene.name, is_instance_valid(p1), is_instance_valid(p2)])
		ok(not is_instance_valid(p1), "CONFIRMED: an auto exit touched by P2 alone changes the scene and P1 is left behind (freed)")
		print("failures=", fails)
		quit(0)
		return
	# ---- Game.go with two bodies
	var n_players_before := get_nodes_in_group("player").size()
	var g := root.get_node("Game")
	var tgt: String = door.target_scene
	g.go(tgt, door.target_spawn)
	await create_timer(0.8).timeout
	await _wait(10)
	var after := get_nodes_in_group("player")
	info("after Game.go(%s): %d player-group nodes before, %d after; new scene %s; P2 valid=%s" % [tgt, n_players_before, after.size(), current_scene.name, is_instance_valid(p2)])
	ok(after.size() == 1 and not is_instance_valid(p2), "CONFIRMED: Game.go frees P2 (only the scene's own Actors/Player remains)")
	print("failures=", fails)
	quit(0)
