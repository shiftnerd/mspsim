extends SceneTree
# gdlint:disable=max-line-length
# R34 personal card routing: the unbilled favour text (R36, `Msp.ask_favour`) is personal: the client texts whoever closed their
# ticket. In co-op the card opens in that player's pane (card scope "player") and the answer is applied as that player: DO IT NOW
# costs the closer's energy and pays the closer's people XP. Alone (and for player 1 with co-op off) it is the old full-window card.
# Morgan's 1:1 about the favours stays a team card (it is about the run's count).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_favour.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _pick(card: Node, id: String) -> void:
	for i in card.options.size():
		if str(card.options[i].id) == id:
			card.pick(i)
			return


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_%d_coopfav_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_coopfav_settings.cfg" % pid
	var players := root.get_node("Players")
	var skills := root.get_node("Skills")
	var shift := root.get_node("Shift")
	var campaign := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var game := root.get_node("Game")

	# ---- alone: the old full-window card, the answer is yours
	campaign.new_game("tech")
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1
	root.get_node("World").time_scale = 1.0
	campaign.day = 6
	var e0: float = shift.energy
	var x0: int = skills.xp.get("people", 0)
	msp.ask_favour(0, 0)
	ok(cards.is_open and str(cards.speaker).ends_with("(text)"), "alone the favour is the usual card")
	_pick(cards, "fav_now")
	ok(is_equal_approx(shift.energy, e0 - msp.FAVOUR_ENERGY) and skills.xp.get("people", 0) == x0 + 3, "and DO IT NOW costs your energy, pays your XP")
	while cards.is_open:
		cards.pick(0)

	# ---- co-op: two players in the tech campaign
	players.enable_coop(true)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(10)
	game.busy = false
	game.ui_open = false
	ok(players.join(1, 1) and players.node(1) != null, "player 2 joins the tech campaign")
	await _wait(10)
	var host: Node = players.takeover_host()
	players.run_as(1, func() -> void: shift.energy = 60.0)
	e0 = shift.energy
	x0 = skills.xp.get("people", 0)
	var p2x: int = players.slot(1).skills.xp.get("people", 0)
	var done0: int = msp.favours_done()

	# player 2 closes the ticket (inside their pane: run_as 1), so the client texts player 2
	sales.satisfaction[1] = 90
	players.run_as(1, func() -> void: msp.ask_favour(1, 1))
	await _wait(5)
	var pc: Node = host.card_for(1)
	ok(pc.is_open and pc.pane_slot == 1 and str(pc.speaker).ends_with("(text)"), "the favour card opens in player 2's pane")
	ok(not cards.is_open and players.ui[1] and not players.ui[0], "player 1 is not held, there is no full-window card")
	ok(pc.options.size() == 3 and str(pc.options[0].id) == "fav_now", "the same three answers")
	_pick(pc, "fav_now")
	await _wait(3)
	ok(not pc.is_open and players.active_slot == 0, "answered, and the swap is clean")
	ok(is_equal_approx(players.slot(1).energy, 60.0 - msp.FAVOUR_ENERGY), "DO IT NOW cost player 2's energy (%.1f)" % players.slot(1).energy)
	ok(players.slot(1).skills.xp.get("people", 0) == p2x + 3, "and paid player 2's people XP")
	ok(is_equal_approx(shift.energy, e0) and skills.xp.get("people", 0) == x0, "player 1's energy and XP are untouched")
	ok(msp.favours_done() == done0 + 1 and sales.mood(1) == 94, "the favour counts for the run and the client is happier (shared)")

	# player 1's own favour in co-op: a card in player 1's pane, applied to player 1
	sales.satisfaction[2] = 90
	msp.ask_favour(2, 0)
	await _wait(5)
	var pc0: Node = host.card_for(0)
	ok(pc0.is_open and pc0.pane_slot == 0 and not pc.is_open and not cards.is_open, "player 1's favour opens in player 1's pane")
	ok(players.ui[0] and not players.ui[1], "and holds only player 1")
	_pick(pc0, "fav_now")
	await _wait(3)
	ok(is_equal_approx(shift.energy, e0 - msp.FAVOUR_ENERGY) and skills.xp.get("people", 0) == x0 + 3, "it is player 1's energy and XP this time")
	ok(is_equal_approx(players.slot(1).energy, 60.0 - msp.FAVOUR_ENERGY), "player 2's energy stays where it was")

	# an explicit slot wins over who is acting (a queued close), and the desk answer makes the shared ticket
	var tickets0: int = msp.tickets.size()
	sales.satisfaction[3] = 90
	msp.ask_favour(3, 0, 1)
	await _wait(5)
	ok(host.card_for(1).is_open and not host.card_for(0).is_open, "ask_favour(client, k, 1) goes to player 2's pane")
	_pick(host.card_for(1), "fav_desk")
	await _wait(3)
	ok(msp.tickets.size() == tickets0 + 1 and msp.desk_sends_today >= 1, "ASK THEM TO CALL THE DESK makes the ticket for the team")

	# Morgan's 1:1 about the favours is about the run: a team card for both
	msp.favour_talk()
	ok(cards.is_open and game.ui_open, "Morgan's 1:1 is a team card (full window)")
	cards.pick(0)
	while cards.is_open:
		cards.pick(0)
	host.close_all()
	players.enable_coop(false)
	print("coop_favour: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
