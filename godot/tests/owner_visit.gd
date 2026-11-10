extends SceneTree
# X6, what was left: owner help for onsite visits (an owner rings the client when a fix fails at the site; an owner watches the
# queue while you are out and gives the worst ticket a minute when you are back) and the walk to the front desk for the
# non-phone triggers (the owner walks to Jen's desk and takes it there instead of a call at their own desk).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _seat(world: Node, who: String) -> void:
	var st: Dictionary = world.chars[who]
	st.scene = world.row(who).home
	st.following = false
	st.legs = [world._work_leg(who, true, 300.0)]
	st.leg_t = 300.0


func _has_cover(world: Node, who: String, scene: String) -> bool:
	for leg in world.chars[who].legs:
		if str(leg.get("kind", "")) == "cover" and str(leg.get("scene", "")) == scene:
			return true
	return false


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owners")
	var on := root.get_node("Onsite")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var game := root.get_node("Game")
	var sales := root.get_node("Sales")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	root.get_node("Career").toasts = false
	c.new_game("tech")
	diff.set_tier("normal")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	c.day = 6
	await _wait(1.0)
	world.time_scale = 0.0
	world.clock = 10.0
	msp.reset()
	o.begin_day()
	_check(world.chars.has("Alan") and world.chars.has("Garrison") and world.chars.has("Jen"), "the owners and the front desk are in the building")
	_seat(world, "Alan")
	_seat(world, "Garrison")

	# ---- the walk to the front desk (non-phone triggers)
	var front := str(world.row("Jen").home)
	_check(world.send_owner_front("Alan"), "an owner can be sent to the front desk")
	_check(_has_cover(world, "Alan", front), "the plan has a cover leg at the front desk (%s)" % front)
	var legs: Array = world.chars["Alan"].legs
	_check(str(legs[0].kind) == "travel" and str(legs[legs.size() - 1].kind) == "work", "it starts with the walk there and ends back at work")
	var cover := {}
	for leg in legs:
		if str(leg.kind) == "cover":
			cover = leg
	_check(PackedStringArray(cover.routine).has("answer") and absf(float(cover.target_x) - float(world.DATA.SCENES[front].seats[str(world.row("Jen").seat)])) < 40.0, "the owner stands by Jen's desk and takes the call there")
	_check(not o.is_free("Alan"), "an owner on the way to the front desk is busy")
	_seat(world, "Alan")
	var p1: Dictionary = msp.create_ticket(1, 0, "test")
	p1.pri = 1
	p1.sla_left = 20.0
	var d: Dictionary = o.check()
	_check(d.get("reason", "") == "sla" and d.get("who", "") == "Alan", "a P1 about to breach calls Alan")
	o.step_in(str(d.who), str(d.reason), d)
	_check(_has_cover(world, "Alan", front), "stepping in for a ticket: Alan walks to the front desk")
	_check(is_equal_approx(float(p1.sla_left), 65.0), "and the ticket still gets its 45 seconds")
	_seat(world, "Alan")
	_seat(world, "Garrison")
	world.clock = 10.5
	sales.pending = {"client": 2, "ticket": int(p1.id)}
	o.step_in("Garrison", "complaint", {"client": 2, "ticket": int(p1.id)})
	_check(_has_cover(world, "Garrison", front), "a complaint: Garrison walks to the front desk too")
	_seat(world, "Garrison")
	o.fake_rings = 2
	world.clock = 11.0
	o.step_in("Garrison", "phones", {})
	_check(not _has_cover(world, "Garrison", front), "a ringing phone is answered at the phone, not at the front desk")
	o.fake_rings = 0
	var saved: Dictionary = world.chars
	world.chars = {}
	world.clock = 11.5
	o.step_in("Alan", "backlog", {"ticket": int(p1.id)})
	_check(o.stepped == 4, "with no world running the help still lands (a call at the desk)")
	world.chars = saved

	# ---- the limits of the onsite help
	msp.reset()
	o.begin_day()
	world.clock = 10.0
	_seat(world, "Alan")
	_seat(world, "Garrison")
	_check(o.visit_allowed(), "day 6, normal: the onsite help is allowed")
	msp.enabled = false
	_check(o.visit_allowed() and not o.active(), "also while the service desk is switched off at a site")
	msp.enabled = true
	c.day = 2
	_check(not o.visit_allowed(), "not on the first two days")
	c.day = 6
	diff.set_tier("hard")
	_check(not o.visit_allowed() and o.visit_cover().is_empty() and o.visit_rescue(0, 0) == "", "hard: no owner help onsite either")
	diff.set_tier("normal")
	msp.create_ticket(3, 0, "test")
	_check(o.visit_cover().is_empty() and o.stepped == 0, "back from a visit with a healthy queue: nobody steps in")

	# ---- a real visit: the fix fails, then the drive home
	msp.reset()
	o.begin_day()
	var other: Dictionary = msp.create_ticket(1, 0, "email")
	var t: Dictionary = on.create_job(0, "switch")
	_check(not t.is_empty(), "an onsite job")
	on.offer(int(t.id))
	cards.pick(0)
	await _wait(1.2)
	if cards.is_open and str(cards.options[0].get("id", "")) == "help":
		cards.pick(1)
	_check(on.active and not msp.enabled, "you are at the site")
	_seat(world, "Alan")
	_seat(world, "Garrison")
	var rep0: int = c.rep
	var soc0: Dictionary = root.get_node("Social").rel.duplicate()
	var mood0: int = sales.mood(0)
	var sla0: float = float(t.sla_left)
	on._event_done = true
	on._after(false)
	_check(o.stepped == 1 and str(o.log[0].reason) == "visit" and str(o.log[0].who) == "Garrison", "the fix fails: Garrison rings the client")
	_check(sales.mood(0) == mini(100, mood0 + o.VISIT_MOOD), "the client is a little happier (%d -> %d)" % [mood0, sales.mood(0)])
	_check(is_equal_approx(float(t.sla_left), sla0 + o.ONSITE_BONUS), "the job gets a minute on its clock")
	_check(str(t.notes[-1]).contains("rang the client"), "the ticket says who called")
	on._after(false)
	_check(o.stepped == 1, "only once a visit")
	other.sla_left = float(other.sla_total) * 0.36  # the drive aged it
	var left0: float = float(other.sla_left)
	on._go_home(false)
	await _wait(1.2)
	_check(not on.active and msp.enabled, "back at the office")
	_check(o.stepped == 2 and str(o.log[1].reason) == "onsite" and str(o.log[1].who) == "Alan", "a ticket was close to breaching: Alan watched the queue")
	_check(bool(other.get("owner_helped", false)) and float(other.sla_left) > left0, "that ticket got a minute")
	_check(c.rep == rep0 and root.get_node("Social").rel == soc0, "no reputation and no opinion change")
	_check(o.used["Alan"] == 1 and o.used["Garrison"] == 1, "both count against the owners' uses for the day")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
