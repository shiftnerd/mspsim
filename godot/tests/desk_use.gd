extends SceneTree
# gdlint:disable=max-line-length
# X13: what the use button does at your own desk.
#   seated, a coworker standing at the desk (anywhere from behind the chair to on top of the monitor): one press opens the
#     Computer, 30 runs out of 30 (15 with the keyboard action, 15 with a pad's X button sent as a real joypad event)
#   standing, facing the monitor with a coworker standing in front of it: the Computer; facing the coworker with the monitor
#     behind your back: the coworker
#   somebody who walked over with news for you (John and a client's complaint, Npc.wants_you) is reached with one press,
#     seated or standing, and tells you once
#   a desk phone that rings within reach is still answered first (it is meant to interrupt), the next press is the Computer
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/desk_use.gd

var npc_scene: PackedScene  # loaded once the autoloads are there

var fails := 0
var cards: Node
var comp: Node
var p: Node
var seat: Node


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _press_key() -> void:
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(8)


func _press_pad() -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_X
		e.pressed = down
		e.pressure = 1.0 if down else 0.0
		Input.parse_input_event(e)
		await _wait(2)
	await _wait(8)


func _press(pad: bool) -> void:
	if pad:
		await _press_pad()
	else:
		await _press_key()


# everything closed, nobody talking, no phone ringing: the state a press starts from
func _calm() -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(cards.options.size() - 1)  # a conversation's last option is LEAVE
		n += 1
	if comp.is_open:
		comp.close()
	root.get_node("Game").ui_open = false
	root.get_node("Game").busy = false
	for zone in get_nodes_in_group("phones"):
		var fx: Node = zone.get_node(zone.target)
		fx.ringing = false
		fx._next_ring = 1.0e12
	p._call_stage = ""
	p._head_item.item = ""
	await _wait(4)
	n = 0
	while str(p.state) in ["emote", "use", "sitdown", "standup"] and n < 600:
		if str(p.state) == "emote":
			p._emote_t = 0.0
		await physics_frame
		n += 1


func _seat_player() -> void:
	await _calm()
	if p.seat != seat or str(p.state) != "sitting":
		p.sit_now(seat)
	p._gesture = ""
	await _wait(6)


func _stand_player(x: float, facing: String) -> void:
	await _calm()
	p.seat = null
	p.state = "idle"
	p.body_shape.set_deferred("disabled", false)
	p.global_position = Vector2(x, 118.0)
	p.velocity = Vector2.ZERO
	p._pick = null
	p.face(facing)
	await _wait(12)


func _stand_npc(npc: Node, x: float) -> void:
	if npc.seat != null:
		npc._release()
	npc.global_position = Vector2(x, 118.0)
	npc._hold = 0.0
	npc.set_routine(PackedStringArray(["wait:100000"]))


func _make_npc(scene: Node, who: String, x: float) -> Node:
	var world := root.get_node("World")
	var old := scene.get_node_or_null("Actors/" + who)
	if old != null:
		old._leaving = true
		old.name = "Old" + who
		old.queue_free()
	var npc: Node = npc_scene.instantiate()
	npc.name = who
	npc.cast_name = who
	npc.character = world.row(who).character
	npc._leaving = true  # the World is not asked for a next leg: this body stays where the test puts it
	npc.routine = PackedStringArray(["wait:100000"])
	npc.position = Vector2(x, 118.0)
	scene.get_node("Actors").add_child(npc)
	return npc


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	npc_scene = load("res://scenes/npc.tscn")
	var pid := OS.get_process_id()
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var talk := root.get_node("Talk")
	cards = root.get_node("Cards")
	comp = root.get_node("Computer")
	root.get_node("Game").title_mode = false
	c.save_prefix = "user://test_%d_deskuse_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_deskuse_settings.cfg" % pid
	root.get_node("Phone").save_path = "user://test_%d_deskuse_phone.cfg" % pid
	c.new_game("tech")
	root.get_node("Career").toasts = false
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	await _wait(60)
	# the office stands still: no story card, no ticket, no walk-up of its own during the presses
	world.time_scale = 0.0
	world.set_process(false)
	msp.set_process(false)
	sales.set_process(false)
	root.get_node("Story").set_process(false)
	var scene := current_scene
	p = scene.get_node("Actors/Player")
	seat = scene.get_node("Interactables/Seat1")
	var pc: Node = null
	for zone in get_nodes_in_group("computers"):
		var dx: float = zone.global_position.x - seat.global_position.x
		if dx > 5.0 and dx < 60.0:
			pc = zone
	ok(pc != null, "your desk has a computer in front of the chair")
	if pc == null:
		quit(1)
		return
	var pc_x: float = pc.global_position.x
	var dan := _make_npc(scene, "Dan", pc_x)
	await _wait(10)
	ok(talk.available("Dan") and dan._can_chat(), "Dan is standing there and would talk if asked")

	# ---- seated: the Computer, wherever the coworker stands. 30 presses, half of them a pad's X
	var opened := 0
	var where := []
	for i in 30:
		await _seat_player()
		var x: float = seat.global_position.x - 14.0 + float(i % 15) * 4.0  # from behind the chair to past the monitor
		_stand_npc(dan, x)
		await _wait(10)
		await _press(i >= 15)
		var good: bool = comp.is_open and str(comp.app) == "desktop" and not cards.is_open and str(p.state) == "sitting"
		if good:
			opened += 1
		else:
			where.append("run %d: Dan at x %d, player %s, card %s" % [i, int(x), p.state, cards.is_open])
	ok(opened == 30, "seated with a coworker at the desk, one press opens the Computer: %d runs of 30 %s" % [opened, str(where)])

	# ---- standing in front of the monitor, the coworker between you and it (nearer than the monitor): the Computer
	var stand_x: float = pc_x - 8.0
	var hits := 0
	for i in 6:
		await _stand_player(stand_x, "right")
		_stand_npc(dan, pc_x - 5.0 + float(i))
		await _wait(12)
		var want: Node = p.nearest()
		await _press(i % 2 == 1)
		if want == pc and comp.is_open and not cards.is_open:
			hits += 1
	ok(hits == 6, "standing, facing the monitor: the Computer wins over the coworker in front of it (%d of 6)" % hits)

	# ---- facing the coworker, the monitor behind your back: the coworker
	await _stand_player(pc_x - 10.0, "left")
	_stand_npc(dan, pc_x - 14.0)
	await _wait(12)
	p.face("left")
	await _wait(2)
	ok(p.nearest() == dan, "standing with the monitor behind you and Dan in front: the arrow is on Dan (%s)" % str(p.nearest()))
	await _press(false)
	ok(cards.is_open and not comp.is_open and str(talk._who) == "Dan", "one press talks to him (card %s, computer %s)" % [cards.is_open, comp.is_open])
	await _calm()

	# ---- the thing you face beats a nearer thing behind you (no people involved)
	await _stand_player(seat.global_position.x + 7.0, "right")
	_stand_npc(dan, 300.0)
	await _wait(12)
	var facing_right: Node = p.nearest()
	p.face("left")
	await _wait(2)
	var facing_left: Node = p.nearest()
	ok(facing_right == pc and facing_left == seat, "between the chair and the monitor, the one you face is picked (right: %s, left: %s)" % [str(facing_right.name), str(facing_left.name)])
	# Tab still reaches the other one
	p.face("right")
	p.cycle_pick(1)
	ok(p.nearest() != pc, "Tab moves the pick off the faced thing")
	p._pick = null

	# ---- John on his way over with a complaint: one press reaches him, seated ...
	var t: Dictionary = msp._random_ticket("email") if msp.open_tickets().is_empty() else msp.open_tickets()[0]
	var john := _make_npc(scene, "John", pc_x + 6.0)
	await _wait(10)
	for seated in [true, false]:
		if seated:
			await _seat_player()
		else:
			await _stand_player(stand_x, "right")
		_stand_npc(john, pc_x + (6.0 if seated else -3.0))
		_stand_npc(dan, pc_x - 6.0)
		sales.pending = {"ticket": int(t.id), "client": int(t.client)}
		await _wait(12)
		var how := "seated" if seated else "standing in front of the monitor"
		ok(john.wants_you(), "%s: John has something to tell you" % how)
		await _press(seated)
		ok(cards.is_open and str(cards.speaker).begins_with("John") and not comp.is_open, "%s: one press and John tells you (card %s %s, computer %s)" % [how, cards.is_open, cards.speaker, comp.is_open])
		ok(not john.wants_you(), "%s: he has said it" % how)
		sales.deliver()  # his walk ends a moment later and would tell you again
		var n := 0
		while cards.is_open and n < 20:
			cards.pick(0)
			n += 1
		await _wait(4)
		ok(not cards.is_open and sales.pending.is_empty(), "%s: told once, answered once (%d cards)" % [how, n])
		# with nothing left to say he is a coworker like any other: the Computer again
		if seated:
			await _seat_player()
		else:
			await _stand_player(stand_x, "right")
		await _press(not seated)
		ok(comp.is_open and not cards.is_open, "%s: after that the press is the Computer again" % how)
	await _calm()
	_stand_npc(john, 320.0)

	# ---- a ringing desk phone within reach still comes first (calls are meant to interrupt), then the Computer
	await _seat_player()
	var phone: Node = null
	for zone in get_nodes_in_group("phones"):
		var dx: float = zone.global_position.x - seat.global_position.x
		if dx > 20.0 and dx < 70.0:
			phone = zone
	if phone != null:
		var fx: Node = phone.get_node(phone.target)
		fx.ringing = true
		fx._ring_until = 1.0e12
		await _wait(2)
		if p._ringing_phone() != null:
			await _press(true)
			ok(not comp.is_open and str(p._call_stage) != "", "a ringing desk phone is answered first (call stage %s)" % p._call_stage)
			fx.ringing = false
			var n2 := 0
			while str(p.state) == "emote" and n2 < 300:
				await physics_frame
				n2 += 1
			await _press(true)
			ok(comp.is_open, "and the next press opens the Computer")
		else:
			print("     (the phone is busy or offline: skipped)")

	print("done, failures: %d" % fails)
	quit(1 if fails > 0 else 0)
