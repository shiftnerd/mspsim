extends SceneTree
# The playbooks (rack, migration, 24x7 email outage, network install): paths, locks,
# flags, follow-ups, overtime and the story days that start them. Headless.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _best(pb: Node) -> int:
	var step: Dictionary = pb.current_step()
	var best := -1
	var best_pts := -1
	for i in step.choices.size():
		var ch: Dictionary = step.choices[i]
		if pb.lock_reason(ch) == "" and int(ch.pts) > best_pts:
			best_pts = int(ch.pts)
			best = i
	return best


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var pb := root.get_node("Playbook")
	var msp := root.get_node("Msp")
	var sk := root.get_node("Skills")
	var story := root.get_node("Story")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	c.new_game("tech")

	# the rack: every playbook has a reachable best score, flags drive the follow-ups
	var tid: int = pb.start("rack")
	_check(
		tid > 0 and msp.tickets.size() == 3 and pb.is_active(), "rack: three tickets, job starts"
	)
	var first: Dictionary = pb.current_step().choices[2]
	_check(first.flag == "damaged", "the sloppy first choice is the 'stand it up' one")
	pb.choose(1)  # photograph
	pb.choose(0)  # anchors
	var recable: Dictionary = pb.current_step()
	_check(
		pb.lock_reason(recable.choices[0]) == "" and pb.lock_reason(recable.choices[1]) != "",
		"photos unlock 'follow your photos'; the tester needs NETWORKING 2"
	)
	sk.xp["networking"] = 50
	_check(pb.lock_reason(recable.choices[1]) == "", "networking level unlocks the cable tester")
	pb.choose(0)
	pb.choose(0)  # power on in order
	pb.choose(0)  # verify
	_check(
		pb.active.done and pb.active.result.grade in ["S", "A"],
		"careful rack job: " + str(pb.active.result)
	)
	var closed_ok := true
	for t in msp.tickets:
		closed_ok = closed_ok and t.fix_done
	_check(
		closed_ok and story.flags.rack == pb.active.result.grade,
		"all rack tickets resolved, grade remembered"
	)

	# sloppy rack: follow-ups come back the next morning
	msp.reset()
	story.reset()
	c.day = 10
	pb.start("rack")
	pb.choose(2)
	pb.choose(2)
	pb.choose(3)
	pb.choose(2)
	pb.choose(1)
	_check(
		pb.active.result.grade in ["C", "D"],
		"sloppy rack job grades badly: " + str(pb.active.result.grade)
	)
	_check(
		story.flags.followups.size() == 3,
		"three follow-ups queued (wobbling rack, miswired, unverified)"
	)
	var before: int = msp.tickets.size()
	c.day = 11
	story.begin_day(11)
	world.clock = 9.5
	await process_frame
	await process_frame
	_check(
		msp.tickets.size() == before + 3 and story.flags.followups.is_empty(),
		"next morning the trouble returns as tickets"
	)

	# migration: skipping the backup check while the backup is broken is a disaster; checking saves you
	msp.reset()
	story.reset()
	msp.break_backup(1)
	pb.start("migration")
	pb.choose(1)  # skip
	for i in 4:
		pb.choose(_best(pb) if i != 0 else 0)
	var rep0: int = c.rep
	_check(pb.active.done and pb.active.flags.nocheck, "migration without checking")
	msp.reset()
	story.reset()
	msp.break_backup(1)
	pb.start("migration")
	pb.choose(0)
	_check(
		pb.active.flags.backup_fixed and msp.backups[1].ok,
		"checking found the failing backup and fixed it"
	)
	_check(msp.backups[1].checked_day == c.day, "and marked it checked")
	sk.ps_level = 3
	while pb.is_active():
		pb.choose(_best(pb))
	_check(
		pb.active.result.grade in ["S", "A"], "migration best path: " + str(pb.active.result.grade)
	)
	var lost_rep: int = c.rep
	msp.reset()
	story.reset()
	msp.break_backup(1)
	pb.start("migration")
	pb.choose(1)
	while pb.is_active():
		pb.choose(_best(pb))
	_check(
		c.rep <= lost_rep - 8,
		(
			"no backup check + broken backup costs a lot of reputation (rep %d -> %d)"
			% [lost_rep, c.rep]
		)
	)

	# the email outage runs into the night and holds the day open
	msp.reset()
	story.reset()
	c.new_game("tech")
	c.day = 13
	sk.ps_level = 2
	sk.xp["people"] = 50
	world.clock = 15.5
	pb.start("email24")
	_check(story.overtime, "email outage holds the day open")
	world.clock = world.DAY_END + 0.2
	await process_frame
	await process_frame
	_check(
		not root.get_node("DayReport").is_open,
		"the day does not end at 5pm while the outage is open"
	)
	while pb.is_active():
		pb.choose(_best(pb))
	_check(
		not story.overtime and story.ot_hours > 1.0,
		"overtime hours recorded: %.1f" % story.ot_hours
	)
	await process_frame
	await process_frame
	var report := root.get_node("DayReport")
	_check(report.is_open and report.report.overtime > 1.0, "the report shows overtime pay")
	report.finish()
	await create_timer(0.6).timeout

	# network install and the days that start each playbook
	msp.reset()
	story.reset()
	c.new_game("tech")
	pb.start("netinstall")
	sk.ps_level = 2
	while pb.is_active():
		pb.choose(_best(pb))
	_check(
		pb.active.result.grade in ["S", "A"] and pb.active.flags.documented,
		"network install best path"
	)
	for entry in [[10, "rack"], [12, "migration"], [13, "email24"], [16, "netinstall"]]:
		msp.reset()
		story.reset()
		c.day = entry[0]
		story.begin_day(entry[0])
		world.clock = 8.6
		await process_frame
		world.clock = 15.6
		await process_frame
		await process_frame
		_check(
			pb.active.get("id", "") == entry[1] and pb.is_active(),
			"day %d starts the %s job" % [entry[0], entry[1]]
		)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
