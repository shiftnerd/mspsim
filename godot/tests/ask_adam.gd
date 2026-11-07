extends SceneTree
# Adam, the senior tech, is a number on your phone: ask him about a ticket you are stuck on.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var skills := root.get_node("Skills")
	var Calls = load("res://scripts/phone_calls.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	var found := {}
	var nums := {}
	for k in Calls.contacts():
		nums[k.num] = true
		if str(k.id) == "adam":
			found = k
	_check(not found.is_empty() and str(found.sub) == "SENIOR TECH", "Adam is on the phone list in the tech campaign")
	_check(nums.size() == Calls.contacts().size(), "and he has a number of his own")
	world.clock = 11.0
	var adam: Dictionary = world.chars["Adam"]
	adam.scene = "cubicle_two"
	adam.legs = [world._work_leg("Adam", true, 300.0)]  # at his desk
	var call: Dictionary = Calls.open_call(found)
	_check(not bool(call.voicemail) and str(call.opts[0].id) == "stuck", "he picks up and takes the question")
	msp.tickets.clear()
	_check(str(Calls.act(found, "stuck").say).contains("NOTHING IS STUCK"), "an empty queue: nothing is stuck")
	var t: Dictionary = msp.create_ticket(0, 0, "email")
	var xp0: int = skills.xp.get("servers", 0) if skills.get("xp") != null else 0
	var clock0: float = world.clock
	var reply: Dictionary = Calls.act(found, "stuck")
	_check(str(reply.say).contains("#%d" % int(t.id)), "he answers about the oldest open ticket: %s" % str(reply.say))
	_check(str(msp.ticket(int(t.id)).notes).contains("advice: on #"), "and his advice is noted on the ticket")
	_check(world.clock > clock0, "the call takes a little game time")
	_check(not Calls.ready(found), "he will not take another question for a couple of hours")
	adam.legs = [{"kind": "coffee"}]  # away from his desk: a message
	_check(bool(Calls.open_call(found).voicemail), "away from his desk it is his voicemail")
	adam.legs = [world._work_leg("Adam", true, 300.0)]
	world.clock = world.DAY_END
	_check(bool(Calls.open_call(found).voicemail), "after hours it is his voicemail")
	c.new_game("owner")
	var has := false
	for k in Calls.contacts():
		has = has or str(k.id) == "adam"
	_check(not has, "he is not in the owner campaign's list")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
