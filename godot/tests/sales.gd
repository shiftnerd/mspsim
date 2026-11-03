extends SceneTree
# The account manager: clients and satisfaction, workload, deals, complaints and the walk-in.
# cards) and Vic walking across the building to deliver one.

var frame := 0
var failures := 0
var t_id := 0
var vic_near := false


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _model() -> void:
	var c := root.get_node("Campaign")
	var sales := root.get_node("Sales")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	c.save_prefix = "user://test_"
	c.new_game("tech")
	_check(sales.active.size() == 5 and sales.workload() == 1.0, "five clients to start")
	var new_client: int = sales.sign_client()
	_check(
		new_client >= 5 and sales.active.size() == 6 and sales.workload() > 1.1,
		"signing a client adds work"
	)
	_check(msp.texts.size() >= 1 and msp.emails.size() >= 2, "Vic tells you about it")
	sales.active = [new_client]
	var t: Dictionary = msp._random_ticket("test")
	_check(int(t.client) == new_client, "tickets only come from active clients")
	sales.active = [0, 1, 2, 3, 4]

	msp.reset()
	var installs: int = sales.sell_install()
	_check(
		installs > 0 and msp.project_busy() and msp.ticket(installs).source == "sales",
		"Vic sells an install"
	)
	_check(sales.sell_install() == -1, "only one install project at a time")

	# satisfaction follows how the tickets go
	sales.reset()
	var tk: Dictionary = msp.create_ticket(2, 0, "test")
	var before: int = sales.mood(2)
	msp.close_ticket(tk.id)  # unfixed: reopens
	_check(sales.mood(2) == before - 6, "a reopened ticket upsets the client")
	msp.rmm_action(tk.endpoint, "spooler")
	msp.close_ticket(tk.id)
	_check(sales.mood(2) == before - 6 + 5, "a fixed ticket pleases them")
	sales.satisfaction[2] = 30
	sales.satisfaction[0] = 30
	sales.satisfaction[1] = 30
	sales.satisfaction[3] = 30
	sales.satisfaction[4] = 30
	_check(sales.rep_effect() == -2, "unhappy clients cost reputation")

	# a complaint: a late ticket from an unhappy client
	sales.reset()
	msp.reset()
	var late: Dictionary = msp.create_ticket(0, 1, "test")
	msp.ticket(late.id).sla_left = 10.0
	var found: Dictionary = sales.find_complaint()
	_check(found.get("ticket", 0) == late.id, "a late ticket becomes a complaint")
	sales.pending = found
	sales.deliver()
	_check(
		cards.is_open and cards.options.size() == 3 and cards.text.contains("Dr. Patel"),
		"Vic asks what to do: " + cards.text
	)
	var mood0: int = sales.mood(0)
	var vic0: int = social.value("Vic")
	cards.pick(0)
	_check(
		(
			not cards.is_open
			and msp.ticket(late.id).pri == 1
			and sales.mood(0) == mood0 + 6
			and social.value("Vic") == vic0 + 1
		),
		"prioritizing helps the client and Vic"
	)
	msp.ticket(late.id).sla_left = 10.0
	sales.pending = sales.find_complaint()
	sales.deliver()
	cards.pick(1)
	_check(
		sales.mood(0) == mood0 + 6 - 6 and social.value("Vic") == vic0 - 1,
		"brushing them off costs both"
	)

	# save + load
	sales.satisfaction[3] = 12
	sales.deals = 4
	c.save()
	c.new_game("free")
	_check(
		c.continue_game("tech") and sales.satisfaction[3] == 12 and sales.deals == 4,
		"sales saved with the campaign"
	)
	DirAccess.remove_absolute(c.save_path("tech"))


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var cards := root.get_node("Cards")
	match frame:
		5:
			_model()
			# walk-in test in free play: Vic crosses the building to tell the player
			root.get_node("Campaign").new_game("free")
			var t: Dictionary = msp.create_ticket(0, 0, "test")
			msp.ticket(t.id).sla_left = 5.0
			t_id = t.id
			world.chars["Vic"].scene = "cubicle_area"
			sales.pending = {"ticket": t.id, "client": 0}
			world.send_vic_to_player()
			_check(
				world.chars["Vic"].legs.size() >= 2 and world.chars["Vic"].legs[-1].kind == "news",
				"Vic is sent over (%d legs)" % world.chars["Vic"].legs.size()
			)
		_:
			if frame > 5 and cards.is_open and not vic_near:
				var vic: Node = current_scene.get_node_or_null("Actors/Vic")
				var player: Node = current_scene.get_node("Actors/Player")
				vic_near = (
					vic != null and absf(vic.global_position.x - player.global_position.x) < 60.0
				)
				_check(vic_near, "the card opens with Vic standing next to you (frame %d)" % frame)
				cards.pick(0)
				_check(msp.ticket(t_id).pri == 1, "your answer is applied")
			if frame > 6 and vic_near and frame % 1 == 0:
				_check(
					not cards.is_open and sales.pending.is_empty(), "card closed, complaint cleared"
				)
				print("failures=", failures)
				quit(1 if failures > 0 else 0)
			if frame > 6000:
				_check(false, "Vic never arrived")
				quit(1)
	return false
