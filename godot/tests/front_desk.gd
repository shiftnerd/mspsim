extends SceneTree
# The front desk: Jen takes some of the incoming calls and puts them in the queue; a call that finds her busy or away goes to voicemail.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# call _incoming until a call is waiting (it picks the phone about 40% of the time)
func _until_call(msp: Node, want: int) -> bool:
	for i in 80:
		msp._incoming()
		if msp.calls.size() >= want:
			return true
	return false


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	c.day = 10
	msp.new_day(10)
	_check(world.chars.has("Jen"), "Jen is in the building in the tech campaign")
	# she sits at her desk: a work leg in her own scene
	var jen: Dictionary = world.chars["Jen"]
	jen.scene = world.row("Jen").home
	jen.legs = [world._work_leg("Jen", true, 300.0)]
	_check(msp.front_desk() == "ready", "at her desk and free: ready")
	_check(_until_call(msp, 1) and not bool(msp.calls[0].voicemail), "a call comes in and she takes it")
	_check(msp.front_desk() == "away", "on a call she cannot take another")
	_check(_until_call(msp, 2) and bool(msp.calls[1].voicemail), "the second call goes to voicemail")
	msp.spawned_today = 0  # the waiting for a call above can spend the day cap on email tickets
	var before: int = msp.tickets.size()
	msp._tick_calls(msp.CALL_SECS + 0.5)
	_check(msp.calls.size() == 1 and msp.tickets.size() == before + 1, "her call becomes a ticket after a few seconds")
	var taken: Dictionary = msp.tickets[msp.tickets.size() - 1]
	_check(str(taken.source) == "phone call" and str(taken.notes).find("Taken by Jen") >= 0, "the ticket says Jen took it")
	msp.spawned_today = 0  # the waiting for a call above can spend the day cap on email tickets
	var texts_before: int = msp.texts.size()
	msp._tick_calls(msp.VOICEMAIL_SECS)
	_check(msp.calls.is_empty() and msp.tickets.size() == before + 2, "the voicemail is logged later")
	var vm: Dictionary = msp.tickets[msp.tickets.size() - 1]
	_check(str(vm.source) == "voicemail" and float(vm.sla_left) < float(vm.sla_total), "the voicemail has used up part of its SLA window")
	_check(msp.texts.size() == texts_before + 1 and str(msp.texts[0].body).find("voicemail") >= 0, "Jen texts you about it")
	# a call that rolled over is answered by picking up: no voicemail, a ticket with a note, and the phones ring
	msp.calls.clear()
	msp.calls.append({"t": msp.VOICEMAIL_SECS, "voicemail": true})
	msp.spawned_today = 0  # the waiting for a call above can spend the day cap on email tickets
	var n0: int = msp.tickets.size()
	msp._ring_rollover()  # no phones in this headless scene: it must not fail
	msp.phone_call(0)
	_check(msp.calls.is_empty() and msp.tickets.size() == n0 + 1, "picking up a rolled-over call answers it (no voicemail later)")
	_check(str(msp.tickets[msp.tickets.size() - 1].notes).contains("picked up the call yourself"), "and the ticket says you took it")
	var fx_script: GDScript = load("res://scripts/fx.gd")
	_check(fx_script.get_script_method_list().any(func(m: Dictionary) -> bool: return str(m.name) == "ring_for"), "desk phones can be told to ring for a rollover")
	# away from her desk: everything goes to voicemail
	jen.scene = "kitchenette"
	_check(msp.front_desk() == "away", "out of her seat: away")
	# no front desk in the service campaign (Sam has the desk): the old email spawn
	c.new_game("service")
	_check(msp.front_desk() == "", "no front desk in the service campaign")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
