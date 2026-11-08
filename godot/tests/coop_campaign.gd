extends SceneTree
# Co-op phase 5a: a second player joins the tech campaign. Each player has their own skills and energy, swapped into the
# Skills / Shift autoloads only while their pane acts (Players.run_as); a pane Computer earns its own XP.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_campaign.gd

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
	root.get_node("Campaign").save_prefix = "user://test_coopcamp_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_coopcamp_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var skills := root.get_node("Skills")
	var shift := root.get_node("Shift")
	var campaign := root.get_node("Campaign")
	campaign.new_game("tech")
	root.get_node("World").time_scale = 1.0
	players.enable_coop(true)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	ok(campaign.active and campaign.mode == "tech", "a tech campaign is running")
	var game := root.get_node("Game")
	game.busy = false
	game.ui_open = false
	ok(players.can_join(), "player 2 can join the tech campaign")
	ok(players.join(1, 1) and players.node(1) != null, "player 2 joins and spawns")
	await _wait(10)

	# the swap: only inside run_as, slot 1's values; slot 0's come back
	var x0: int = skills.xp.get("networking", 0)
	var e0: float = shift.energy
	players.run_as(1, func() -> void:
		skills.add_xp("networking", 7)
		shift.energy = 12.0
		ok(players.active_slot == 1, "run_as marks the active slot")
	)
	ok(players.active_slot == 0, "and clears it")
	ok(skills.xp.get("networking", 0) == x0 and shift.energy == e0, "player 1's xp and energy are untouched")
	var seen := []
	players.run_as(1, func() -> void: seen.append([skills.xp.get("networking", 0), shift.energy]))
	ok(seen[0][0] == 7 and seen[0][1] == 12.0, "player 2's own xp and energy come back the next time (%s)" % [seen])
	# a nested run_as just runs
	players.run_as(1, func() -> void: players.run_as(1, func() -> void: skills.add_xp("networking", 1)))
	var again := []
	players.run_as(1, func() -> void: again.append(skills.xp.get("networking", 0)))
	ok(again[0] == 8 and players.active_slot == 0, "a nested call stays in the same slot")
	ok(players.run_as(0, func() -> int: return 42) == 42, "slot 0 and the return value pass straight through")


	# a ticket is claimed by the first player to open it; the closer gets the full XP, the claimer a quarter
	var msp := root.get_node("Msp")
	msp.enabled = true
	var t1: Dictionary = msp.create_ticket(0, 0, "phone")
	var t2: Dictionary = msp.create_ticket(0, 0, "phone")
	players.run_as(1, func() -> void: msp.claim_ticket(int(t1.id)))
	msp.claim_ticket(int(t1.id))  # slot 0 is second: the claim stays with slot 1
	ok(int(t1.get("claim", -1)) == 1, "the first opener keeps the claim")
	t1["fix_done"] = true
	t1["internal"] = false
	var mine_before: int = skills.xp.get("people", 0)
	var theirs_before: int = players.slot(1).skills.xp.get("people", 0)
	msp.close_ticket(int(t1.id))  # player 1 closes player 2's ticket
	ok(skills.xp.get("people", 0) > mine_before, "the closer is paid in full")
	ok(players.slot(1).skills.xp.get("people", 0) == theirs_before + 1, "the claimer gets a quarter (at least 1)")
	# the other way round, closed from inside slot 1's pane
	msp.claim_ticket(int(t2.id))
	ok(int(t2.get("claim", -1)) == 0, "player 1 claims the next one")
	t2["fix_done"] = true
	t2["internal"] = false
	var m2: int = skills.xp.get("people", 0)
	var closer := []
	players.run_as(1, func() -> void:
		msp.close_ticket(int(t2.id))
		closer.append(skills.xp.get("people", 0))
	)
	ok(skills.xp.get("people", 0) == m2 + 1 and closer[0] > theirs_before + 1, "player 2 closes it: paid in full, player 1 gets the quarter")
	ok(players.active_slot == 0, "and the swap is clean afterwards")


	# two people: more tickets, and the partner tires and rests with player 1
	ok(players.pace() == 1.5, "two players raise the ticket pace")
	players.slot(1).energy = 50.0
	players.add_partner_energy(-10.0)
	ok(is_equal_approx(players.slot(1).energy, 40.0), "the partner's energy follows player 1's drain")
	players.slot(1).energy = -1.0
	players.add_partner_energy(-5.0)
	ok(is_equal_approx(players.slot(1).energy, float(shift.START_ENERGY) - 5.0), "from a fresh day it starts at the usual energy")
	shift.reset()
	ok(players.slot(1).energy < 0.0, "a new run resets it")

	# a Computer pane of slot 1 acts as slot 1 in every entry point
	var host: Node = players.takeover_host()
	var comp: Node = host.open_computer(1, 3)
	await _wait(10)
	var x_before: int = skills.xp.get("networking", 0)
	var inside := []
	comp._step(0.0)  # (the real entry is _process: the wrapper routes it)
	players.run_as(1, func() -> void: inside.append(skills.xp.get("networking", 0)))
	ok(comp.pane_slot == 1 and inside[0] == 8, "the pane's player is slot 1")
	comp._canvas.queue_redraw()
	await _wait(3)
	ok(players.active_slot == 0 and skills.xp.get("networking", 0) == x_before, "painting and ticking leave player 1's values alone")
	host.close_all()
	await _wait(10)
	players.enable_coop(false)
	ok(players.pace() == 1.0, "and one player is the old pace")
	print("coop_campaign: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
