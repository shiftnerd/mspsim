extends SceneTree
# Co-op phase 1 (docs/scope-coop.md): the Players autoload, slot mirroring, the flag off by default, the second body.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_slots.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_coopslots_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopslots_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var ctl := root.get_node("Controls")
	var game := root.get_node("Game")
	var player_script := load("res://scripts/player.gd")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	var stage := current_scene
	var p1: Node = stage.get_node("Actors/Player")

	# ---- flag off: single player, nothing new
	ok(not players.coop, "Players.coop is false by default")
	ok(players.count() == 1 and players.slot(0).joined and not players.slot(1).joined, "one player joined: slot 0")
	ok(players.node(0) == p1 and players.player0() == p1 and players.player0(stage) == p1, "Players.node(0) / player0() find Actors/Player")
	ok(players.node(1) == null and stage.get_node_or_null("Actors/Player2") == null, "no second body with the flag off")
	ok(not players.join(1, 1) and players.count() == 1, "join(1) is refused while the flag is off")
	ok(not InputMap.has_action("p2_move_right") and not InputMap.has_action("p2_ui_accept"), "no p2_ action is registered with the flag off")
	ok(get_nodes_in_group("player").size() == 1, "one node in the player group")
	ok(players.player0(null) == p1, "player0(null) means the current scene")
	ok(players.slot_of(InputEventKey.new()) == 0, "a key event belongs to slot 0")

	# ---- slot 0 mirrors today's globals (no copy of its own)
	ok(players.slot(0).character == player_script.current_character, "slot 0 character mirrors Player.current_character")
	players.slot(0).character = "office_alan"
	ok(player_script.current_character == "office_alan", "setting slot 0's character sets Player.current_character")
	players.slot(0).character = "office_adult"
	p1.give("coffee")
	ok(players.slot(0).held == "coffee" and game.vars.get("held", "") == "coffee", "slot 0 held mirrors Game.vars.held")
	ok(players.slot(0).look == root.get_node("Look").look, "slot 0 look is Look.look")
	ok(p1.character_id() == player_script.current_character and p1.slot == 0, "the stage player is slot 0")
	p1.give("")

	# ---- flag on, slot 1 joins
	players.enable_coop(true)
	ok(players.coop and InputMap.has_action("p2_move_right") and InputMap.has_action("p2_ui_accept"), "enable_coop registers the p2_ actions")
	ok(not players.join(1, 0), "pad 0 cannot be slot 1's pad")
	var x_before: float = p1.global_position.x
	ok(players.join(1, 1), "join(1, 1) works with the flag on")
	await _wait(10)
	var p2: Node = players.node(1)
	ok(p2 != null and p2.is_inside_tree() and p2.name == "Player2" and p2.slot == 1, "Actors/Player2 spawned as slot 1")
	ok(current_scene == stage and is_instance_valid(p1), "spawning slot 1 did not change the room (no auto exit fired at spawn)")
	ok(players.count() == 2 and players.nodes().size() == 2 and get_nodes_in_group("player").size() == 2, "two players, two bodies")
	ok(absf(p2.global_position.x - x_before) > 8.0 and absf(p2.global_position.x - x_before) < 40.0, "slot 1 stands beside slot 0 (%.1f px)" % (p2.global_position.x - x_before))
	ok(p2.global_position.y == p1.global_position.y, "...on the same floor line")
	ok(p1.character_id() != p2.character_id() and players.slot(1).character == p2.character_id(), "slot 1 is a different stock character (%s)" % p2.character_id())
	ok(p1.sprite.sprite_frames != p2.sprite.sprite_frames, "slot 1 has its own sprite frames")
	ok(players.nearest_to(p2.global_position.x) == p2, "nearest_to picks the closer body")
	ok(players.join(1, 1) and not players.join(1, 3), "joining again on the same pad is fine, on another pad refused")

	# ---- own held item; Game.vars stays slot 0's
	p1.give("coffee")
	p2.give("water")
	ok(players.slot(0).held == "coffee" and players.slot(1).held == "water", "each slot has its own held item")
	ok(game.vars.get("held", "") == "coffee", "Game.vars.held is still slot 0's")
	p1.give("")
	p2.give("")

	# ---- bodies pass through each other; each reads its own actions
	p2.global_position = p1.global_position + Vector2(10, 0)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	var start1: float = p1.global_position.x
	var start2: float = p2.global_position.x
	Input.action_press("move_right")
	await _wait(40)
	Input.action_release("move_right")
	ok(p1.global_position.x > start2 + 4.0, "P1 walks straight through P2 (%.1f -> %.1f, P2 at %.1f)" % [start1, p1.global_position.x, p2.global_position.x])
	ok(absf(p2.global_position.x - start2) < 1.0, "P2 did not move on P1's action")
	var at2: float = p2.global_position.x
	var at1: float = p1.global_position.x
	Input.action_press("p2_move_left")
	await _wait(30)
	Input.action_release("p2_move_left")
	ok(p2.global_position.x < at2 - 5.0 and absf(p1.global_position.x - at1) < 1.0, "p2_move_left moves P2 only")
	ok(p2.facing == "left", "P2 faces its own way")

	# ---- the keyboard events are slot 0's (the character keys do not change slot 1)
	var char2: String = p2.character_id()
	var ev := InputEventKey.new()
	ev.keycode = KEY_3
	ev.pressed = true
	p2._unhandled_input(ev)
	ok(p2.character_id() == char2, "a number key does not switch slot 1's character")

	# ---- a room change keeps the roster
	game.go("kitchenette", "start")
	await create_timer(1.0).timeout
	await _wait(10)
	var stage2 := current_scene
	ok(stage2 != stage and stage2.get_node_or_null("Actors/Player2") != null, "Player2 exists in the next room too")
	ok(players.node(1) == stage2.get_node("Actors/Player2") and players.node(1).character_id() == char2, "...with the same character")
	ok(stage2.get_node("Actors/Player2").global_position.distance_to(stage2.get_node("Actors/Player").global_position) < 40.0, "...standing beside slot 0 at the arrival spawn")

	# ---- leave / flag off again
	players.enable_coop(false)
	await _wait(3)
	ok(not players.coop and players.count() == 1 and players.node(1) == null, "turning the flag off removes slot 1")
	ok(get_nodes_in_group("player").size() == 1, "one player node again")
	ok(not players.join(1, 1), "join is refused again")
	ok(ctl.prefix(0) == "" and ctl.prefix(1) == "p2_" and ctl.action_for(1, "jump") == "p2_jump" and ctl.action_for(0, "jump") == "jump", "Controls.prefix / action_for")
	print("failures=", fails)
	quit(1 if fails > 0 else 0)
