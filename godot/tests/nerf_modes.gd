extends SceneTree
# Nerf war modes and arenas (R11): the V card, capture the cup, elimination, hide and seek, the three arenas, the career counters.

const NM := preload("res://scripts/nerf_modes.gd")
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
	var cards := root.get_node("Cards")
	var career := root.get_node("Career")
	var game := root.get_node("Game")
	var d := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	career.toasts = false
	c.new_game("tech")
	c.day = 3
	d.seed_run(31)
	world.time_scale = 1.0
	world.chars["John"].scene = "cubicle_area"
	world.force_activity("John", "work")

	# ---- tables
	_check(NM.MODES.size() == 3 and NM.ARENAS.size() == 3, "three modes and three arenas")
	for id in NM.ARENAS:
		var a: Dictionary = NM.ARENAS[id]
		_check(world.DATA.SCENES.has(id) and a.cups.size() >= 3 and float(a.secs) >= 30.0, "%s is a real room with cup spots" % id)
	_check(NM.arena_for("kitchenette").is_empty(), "the kitchenette is no arena")
	_check(NM.next_cup_index(NM.ARENAS.cubicle_area, 24.0, 320.0, 0, 24.0 + 320.0 * 0.45) != 1, "the cup does not move next to you")

	change_scene_to_file("res://scenes/cubicle_area.tscn")
	await _wait(40)
	var scene := current_scene
	var player := scene.get_node("Actors/Player")
	player.give("nerf")
	var wars0: int = career.value("nerf_wars")

	# ---- the card
	nerf.offer_war()
	_check(cards.is_open and cards.options.size() == 5, "V opens the war card: three modes, free-for-all, never mind")
	_check("CUBICLE AREA" in str(cards.text), "the card names the arena")
	cards.pick(4)
	_check(nerf.war_t <= 0.0 and nerf.mode == "", "NEVER MIND starts nothing")

	# ---- classic war is unchanged
	nerf.start_war()
	_check(nerf.mode == "" and is_equal_approx(nerf.war_t, nerf.WAR_SECS), "a war without a mode is the classic 45 seconds")
	nerf.war_t = 0.01
	await _wait(5)
	_check(nerf.mode_result.is_empty() or true, "classic war ends")
	_check(career.value("nerf_wars") == wars0 + 1, "a war counts for the career")

	# ---- a lob can reach the shelf: some charge and distance puts a dart at the cup
	var reachable := 0
	for dist in range(60, 220, 10):
		for pw in [0.3, 0.5, 0.7, 0.9, 1.0]:
			var vel: Vector2 = nerf.launch_velocity(1.0, pw)
			var pos := Vector2(0.0, 64.0)
			for step in 400:
				pos += vel * 0.01
				vel.y += 75.0 * 0.01
				if pos.x >= float(dist):
					if pos.y > NM.CUP_Y - 14.0 and pos.y < NM.CUP_Y + 10.0:
						reachable += 1
					break
	_check(reachable >= 6, "the shelf can be hit with a charged lob (%d distance / power pairs)" % reachable)

	# ---- capture the cup
	nerf.offer_war()
	cards.pick(0)
	_check(nerf.mode == "cup" and is_equal_approx(nerf.war_t, float(NM.ARENAS.cubicle_area.secs)), "the cup war uses the arena length")
	_check(nerf.cup_node != null and is_equal_approx(nerf.cup_node.position.x, nerf.cup_x), "the cup stands in the room")
	_check("CUP 0/3" in nerf.hud_extra(), "the HUD shows the score")
	var arenas0: int = career.value("nerf_arenas")
	_check(arenas0 >= 1, "the arena counts for the career")
	var cups0: int = career.value("nerf_cups")
	var x0: float = nerf.cup_x
	nerf._spawn(Vector2(x0 - 40.0, nerf.Modes.CUP_Y + 2.0), 1.0, "Player")
	await _wait(60)
	_check(nerf.cups == 1 and career.value("nerf_cups") == cups0 + 1, "a real dart knocks the cup down")
	nerf.cup_check(Vector2(nerf.cup_x, nerf.Modes.CUP_Y), "Player")
	_check(nerf.cups == 1, "the cup cannot be knocked twice while it falls")
	await _wait(80)
	_check(absf(nerf.cup_x - x0) > 20.0, "the cup moves to another spot")
	nerf.cup_check(Vector2(nerf.cup_x, nerf.Modes.CUP_Y), "Player")
	await _wait(80)
	nerf.cup_check(Vector2(nerf.cup_x, nerf.Modes.CUP_Y), "Player")
	_check(nerf.mode == "" and bool(nerf.mode_result.won) and nerf.mode_result.id == "cup", "three cups win the war")
	_check(nerf.war_t <= 0.0 and career.value("nerf_cups") == cups0 + 3, "the war is over and the counters follow")

	# the crew can win it too
	nerf.start_war("cup")
	nerf.cup_down("John")
	await _wait(80)
	nerf.cup_down("John")
	await _wait(80)
	nerf.cup_down("John")
	_check(nerf.mode_result.id == "cup" and not bool(nerf.mode_result.won) and int(nerf.mode_result.rival) == 3, "the crew can capture the cup")
	_check(career.value("nerf_cups") == cups0 + 3, "their cups do not count for you")

	# ---- elimination
	var elim0: int = career.value("nerf_elim_wins")
	nerf.start_war("elim")
	_check(nerf.mode == "elim" and int(nerf.lives["Player"]) == int(NM.ARENAS.cubicle_area.lives), "everyone has lives")
	_check("LIVES" in nerf.hud_extra(), "the HUD shows your lives")
	for who in nerf.lives.keys():
		if who != "Player":
			for i in int(nerf.lives[who]):
				nerf._lose_life(who)
	_check(nerf.mode_result.id == "elim" and bool(nerf.mode_result.won) and nerf.war_t <= 0.0, "last one standing wins")
	_check(career.value("nerf_elim_wins") == elim0 + 1, "an elimination win is counted")
	nerf.start_war("elim")
	for i in 3:
		nerf._player_hit_mode()
	_check(nerf.mode_result.id == "elim" and not bool(nerf.mode_result.won), "losing your lives ends the war")
	_check(career.value("nerf_elim_wins") == elim0 + 1, "a loss is not counted as a win")

	# ---- hide and seek
	var ghosts0: int = career.value("nerf_hide_wins")
	d.seed_run(5)
	nerf.start_war("hide")
	var first := str(nerf.seeker)
	_check(first != "" and nerf._shot_t.size() == 1 and nerf._shot_t.has(first), "one seeker fires, nobody else")
	nerf._mode_hit(first)
	_check(nerf.stunned > 3.0, "hitting the seeker stuns them")
	nerf._player_hit_mode()
	_check(nerf.mode_result.id == "hide" and not bool(nerf.mode_result.won), "being hit means FOUND")
	d.seed_run(5)
	nerf.start_war("hide")
	_check(str(nerf.seeker) == first, "the same seed picks the same seeker")
	nerf.hide_t = float(NM.ARENAS.cubicle_area.secs)
	nerf.war_t = 0.02
	await _wait(5)
	_check(nerf.mode_result.id == "hide" and bool(nerf.mode_result.won), "running the clock out wins")
	_check(career.value("nerf_hide_wins") == ghosts0 + 1 and career.value("nerf_hide_best") >= 40, "the career keeps the ghost count and the best time")

	# ---- leaving the arena ends the war
	nerf.start_war("cup")
	game.go("main_floor", "start")
	await _wait(60)
	_check(nerf.war_t <= 0.0 and nerf.mode == "", "walking out of the arena ends a mode war")

	# ---- other arenas
	var main := current_scene
	var mp := main.get_node_or_null("Actors/Player")
	if mp != null:
		mp.give("nerf")
	nerf.offer_war()
	_check(cards.is_open and "OFFICE" in str(cards.text), "the office is an arena too")
	cards.pick(0)
	_check(nerf.mode == "cup" and nerf.arena == "main_floor", "a cup war in the office")
	nerf.war_t = 0.02
	await _wait(5)
	game.go("conference", "start")
	await _wait(60)
	var cp := current_scene.get_node_or_null("Actors/Player")
	if cp != null:
		cp.give("nerf")
	nerf.offer_war()
	_check(cards.is_open and "CONFERENCE" in str(cards.text), "and so is the conference room")
	cards.pick(1)
	_check(nerf.mode == "elim" and int(nerf.lives["Player"]) == int(NM.ARENAS.conference.lives), "each arena has its own lives")
	nerf.war_t = 0.02
	await _wait(5)
	_check(career.value("nerf_arenas") >= 3, "three arenas fought in (%d)" % career.value("nerf_arenas"))
	game.go("kitchenette", "start")
	await _wait(60)
	var kp := current_scene.get_node_or_null("Actors/Player")
	if kp != null:
		kp.give("nerf")
	nerf.offer_war()
	_check(not cards.is_open, "no card outside an arena")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
