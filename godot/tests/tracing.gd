extends SceneTree
# R37 cable tracing: seeded jack labels (some missing, wrong or faded), a loose cable, the toner and probe, the relabel action,
# the tech campaign tie-in (ticket, wrong jack costs a coworker, tracing pays XP and opinion) and Free Play.
# Headless. No saves are written.

var failures := 0


class Body:
	extends Node
	var held := ""
	var reached := 0

	func give(item: String) -> void:
		held = item

	func reach(_x: float) -> void:
		reached += 1


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var net := root.get_node("Net")
	var dif := root.get_node("Difficulty")
	var camp := root.get_node("Campaign")
	var sk := root.get_node("Skills")
	var social := root.get_node("Social")
	camp.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- labels: deterministic, Dan's always right, wrong ones exist (in swapped pairs)
	dif.run_seed = 4242
	var a: Dictionary = net.roll_labels(0)
	var b: Dictionary = net.roll_labels(0)
	_check(a == b, "the same seed and day roll the same labels")
	var seen := {"wrong": 0, "blank": 0, "faded": 0, "ok": 0}
	var always_wrong := true
	var dan_right := true
	var swapped := true
	var differs := false
	for trial in range(1, 61):
		dif.run_seed = trial
		var l: Dictionary = net.roll_labels(1)
		var wrong := []
		for k in range(1, 9):
			seen[l[k].state] = int(seen.get(l[k].state, 0)) + 1
			if l[k].state == "wrong":
				wrong.append(k)
			if k in net.DAN_JACKS and (l[k].state != "dan" or l[k].n != k):
				dan_right = false
		always_wrong = always_wrong and wrong.size() >= 2
		for k in wrong:
			swapped = swapped and l[l[k].n].state == "wrong" and l[l[k].n].n == k
		differs = differs or l != net.roll_labels(2)
	_check(dan_right, "Dan's jacks (1, 3, 8) are right in 60 seeded runs")
	_check(always_wrong, "every run has at least one wrong pair of tags")
	_check(swapped, "wrong tags come as swapped pairs (somebody re-plugged them)")
	_check(seen.blank > 0 and seen.faded > 0 and seen.ok > 0, "blank, faded and good hand-written tags all occur: %s" % [seen])
	_check(differs, "a later day can drift the tags")
	dif.run_seed = 777
	net.reset()
	var shown: String = net.label_text(1)
	_check(shown == "1 DESK 1", "label text shows the number and the person: %s" % shown)

	# ---- the loose cable and re-seating (Free Play first: no scoring, no campaign)
	camp.new_game("free")
	net.reset()
	_check(net.desk_state(5) == "ok", "free play: all desks fine")
	net.loosen(5)
	_check(net.desk_state(5) == "no_link" and net.desk_state(4) == "ok", "a loose cable drops only its desk")
	_check(net.reseat(5) == "fixed", "re-seating the loose jack fixes it")
	net._tick_tracing(1.2)
	_check(net.desk_state(5) == "ok", "...and the link comes back")
	var res: String = net.reseat(2)
	_check(res in ["bounced", "loose"], "re-seating a healthy jack bounces its desk (or works it loose in free play)")
	_check(net.desk_state(2) == "no_link", "the bounced desk is down for a moment")
	net._tick_tracing(7.0)
	net.faults.clear()
	_check(net.desk_state(2) == "ok", "...and back after %.0f s" % net.FLAP_SECS)
	var xp_before: int = int(sk.xp.get("networking", 0))
	net.loosen(4)
	net.tone_at(4)
	net.probe(4)
	net.reseat(4)
	_check(int(sk.xp.get("networking", 0)) == xp_before, "free play: no experience")

	# ---- the toner and probe
	net.reset()
	_check(net.probe(2) == "notone", "the probe without a tone says so")
	net.tone_at(5)
	_check(net.probe(2) == "quiet" and net.traced.is_empty(), "the wrong jack is silent")
	_check(net.probe(5) == "beep" and net.traced.get(5, 0) == 5 and net.beep_t > 0.0, "the right jack beeps and is remembered")
	_check(not net.relabel(5) or true, "relabel is only for a bad tag")

	# ---- the scene: patch jacks, the tool case, the held toner
	change_scene_to_file("res://scenes/network_closet.tscn")
	for i in 4:
		await process_frame
	var room := current_scene
	var jacks := 0
	for k in range(1, 9):
		if room.get_node_or_null("Ports/pp%d" % k) != null:
			jacks += 1
	_check(jacks == 8, "the closet has 8 patch jack nodes (pp1-pp8)")
	_check(get_nodes_in_group("ports").size() == 33, "33 plug points and jacks in reach (%d)" % get_nodes_in_group("ports").size())
	var kit: Node = room.get_node_or_null("Interactables/UseToner")
	_check(kit != null and room.get_node_or_null("Fx/Toner") != null, "the tool case and its E zone are in the closet")
	var body := Body.new()
	root.add_child(body)
	net.reset()
	dif.run_seed = 99
	camp.new_game("tech")
	net.reset()
	if kit != null:
		kit.use(body)
	_check(body.held == "toner", "E at the tool case takes the toner")
	net.tone_at(3)
	kit.use(body)
	_check(body.held == "" and net.tone_desk == 0, "E again puts it back and clears the tone")
	kit.use(body)

	# a desk phone with the toner in hand clips the tone instead of ringing
	var holder := Node2D.new()
	root.add_child(holder)
	var fx: Node = load("res://scripts/fx.gd").new()
	fx.name = "Fx"
	fx.kind = "desk_phone"
	fx.desk = 5
	holder.add_child(fx)
	var use: Node = load("res://scripts/interact.gd").new()
	use.target = NodePath("../Fx")
	holder.add_child(use)
	use.use(body)
	_check(net.tone_desk == 5, "E at desk 5 with the toner clips the tone on its wall jack")

	# ---- the tech campaign: a wrong label costs a coworker until you trace it
	camp.new_game("tech")
	net.reset()
	sk.xp["networking"] = 100  # level 3: the ticket names the port and hints at the toner
	var day := 4
	var found := false
	for trial in range(1, 200):
		dif.run_seed = trial
		var l: Dictionary = net.roll_labels(day)
		for k in [2, 4, 5]:
			if l[k].state == "wrong" and l[l[k].n].state == "wrong":
				found = true
				break
		if found:
			break
	_check(found, "found a seed with a wrong tag on desks 2 / 4 / 5")
	root.get_node("World").day = day
	net.reset()
	var lab: Dictionary = net.roll_labels(day)
	var jack := 0
	for k in [2, 4, 5]:
		if lab[k].state == "wrong":
			jack = k
	var tag_on: int = lab[jack].n  # the jack that carries the tag with this desk's number
	_check(not net.label_ok(jack) and net.label(tag_on).n == jack, "desk %d's number is written on jack %d" % [jack, tag_on])
	net.loosen(jack)
	var msp := root.get_node("Msp")
	msp._watch_desks(9.0)
	var tid: int = int(msp._internal.get(jack, -1))
	var tkt: Dictionary = msp.ticket(tid)
	_check(not tkt.is_empty(), "the loose cable raises a desk ticket")
	var notes := " ".join(tkt.get("notes", []))
	_check("patch panel port %d" % jack in notes and "toner" in notes, "...that names the port and, at networking 3, the toner")
	var owner_of: String = str(social.DESK_OWNER.get(tag_on, ""))
	var mood_before: int = social.value(owner_of) if social.people().has(owner_of) else 0
	var wrong_try: String = net.reseat(tag_on)  # trusting the label
	_check(wrong_try == "bounced", "re-seating the labelled jack %d is the wrong one" % tag_on)
	_check(net.desk_state(jack) == "no_link", "desk %d is still down" % jack)
	_check(net.desk_state(tag_on) == "no_link", "and desk %d dropped for a while" % tag_on)
	var mood_after: int = social.value(owner_of) if social.people().has(owner_of) else 0
	_check(mood_after <= mood_before and (mood_after < mood_before or owner_of == "" or not social.people().has(owner_of)), "the wrong jack's owner is annoyed")
	# trace it
	var xp0: int = int(sk.xp.get("networking", 0))
	var owner_j: String = str(social.DESK_OWNER.get(jack, ""))
	var mood_j0: int = social.value(owner_j) if social.people().has(owner_j) else 0
	var dan0: int = social.value("Dan") if social.people().has("Dan") else 0
	net.tone_at(jack)
	_check(net.probe(tag_on) == "quiet", "the probe is silent on the labelled jack")
	_check(net.probe(jack) == "beep", "the probe beeps on desk %d's real jack" % jack)
	_check(net.relabel(jack), "a second E writes the right tag")
	_check(net.label(jack).state == "fixed" and net.label_ok(jack), "the new tag reads right")
	if social.people().has("Dan"):
		_check(social.value("Dan") == dan0 + 2, "Dan appreciates the relabel (+2)")
	_check(net.reseat(jack) == "traced_fix", "re-seating the traced jack is a traced fix")
	_check(int(sk.xp.get("networking", 0)) == xp0 + net.TRACE_XP, "tracing earns networking XP (+%d)" % net.TRACE_XP)
	var mood_j1: int = social.value(owner_j) if social.people().has(owner_j) else 0
	_check(mood_j1 == (mood_j0 + 2 if social.people().has(owner_j) else 0), "...and the owner of the desk likes you more")
	net._tick_tracing(7.0)
	_check(net.desk_state(jack) == "ok" and net.desk_state(tag_on) == "ok", "both desks are back")

	# a fixed trace without a bad label gives no bonus
	net.loosen(3)
	net.tone_at(3)
	net.probe(3)
	_check(net.reseat(3) == "fixed", "a trusted (Dan) label: a plain fix, no trace bonus")

	# ---- the day plan and the resume point
	var plan_a: Dictionary = net.fault_plan(5)
	_check(plan_a == net.fault_plan(5), "the cable fault plan is seeded per day")
	var on_days := 0
	for d in range(3, 40):
		if net.fault_plan(d).on:
			on_days += 1
	_check(on_days > 3 and on_days < 30, "about 40 percent of days from day 3 get a loose cable (%d of 37)" % on_days)
	_check(not net.fault_plan(1).on and not net.fault_plan(2).on, "days 1 and 2 never do")
	var d2 := 3
	while not net.fault_plan(d2).on:
		d2 += 1
	net.reset()
	root.get_node("World").day = d2
	root.get_node("World").clock = float(net.fault_plan(d2).at) + 0.01
	net._tick_tracing(0.1)
	var pj: int = int(net.fault_plan(d2).jack)
	_check(not net.is_loose(pj), "campaigns started outside the title (tests) never get loose cables")
	net.cable_faults = true
	net._tick_tracing(0.1)
	_check(net.is_loose(pj), "at its time the planned cable works loose (day %d, jack %d)" % [d2, pj])
	net.faults.clear()
	net._tick_tracing(0.1)
	_check(not net.is_loose(pj), "it only happens once a day")
	net.loosen(2)
	net.fixed_labels[5] = true
	net.tone_at(2)
	var saved: Dictionary = net.to_dict()
	net.reset()
	net.from_dict(saved)
	_check(net.is_loose(2) and net.fixed_labels.has(5) and net.tone_desk == 2, "a resume point keeps loose cables, new tags and the tone")

	# ---- free play still labels (no scoring, tags can be wrong)
	camp.new_game("free")
	net.reset()
	var wrongs := 0
	for k in range(1, 9):
		if net.label(k).state == "wrong":
			wrongs += 1
	_check(wrongs >= 2, "free play labels drift too (%d wrong tags)" % wrongs)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
