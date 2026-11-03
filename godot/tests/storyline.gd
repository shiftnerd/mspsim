extends SceneTree
# Plays the whole tech campaign automatically: 20 days, every scripted event, the day
# reports and the yearly review. Headless; saves in user://test_*.

var failures := 0
var seen := {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# a decision card now freezes the day: dismiss whatever the story events opened
func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(cards.options.size() - 1)
		guard += 1


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


# do the work the way a good tech would
func _work(msp: Node, pb: Node) -> void:
	if msp.day_cap() > 50 and not seen.has("ticket"):
		msp._random_ticket("test")  # the first days are capped
	for client in msp.backups.size():
		msp.backup_rerun(client)  # a good tech keeps the backups green
	for t in msp.open_tickets():
		seen[str(t.special) if t.special != "" else "ticket"] = true  # jobs close their tickets when they end
	while pb.is_active():
		pb.choose(_best(pb))
	if not msp.project.is_empty() and not msp.project.done:
		msp.project_ask()
		msp.project_scan(true)
		msp.project_backup()
		msp.project_select_all()
		msp.project_migrate()
		msp.project_verify()
		msp.project_select_all()
		msp.project_migrate()
		msp.project_handover()
	for t in msp.open_tickets():
		seen[str(t.special) if t.special != "" else "ticket"] = true
		if not t.fix_done and t.fix != "project" and t.fix != "network":
			msp.rmm_action(str(t.endpoint), str(t.fix))
		if t.fix_done:
			msp.close_ticket(int(t.id))


# the build variants of the extremes: nothing, the worst quirks on hard, one maxed stat, a preset
func _pick_build(variant: String) -> void:
	var build := root.get_node("Build")
	var diff := root.get_node("Difficulty")
	var tier := "hard" if variant == "worst" else "normal"
	diff.set_tier(tier)
	var b: Dictionary = build.new_build(tier)
	match variant:
		"zero":
			b = build.flat()
		"worst":
			b.preset = "custom"
			b.quirks = ["caffeine", "slow"]
		"ps4", "net4", "people4":
			var stat := {"ps4": "powershell", "net4": "networking", "people4": "people"}[variant] as String
			b.preset = "custom"
			build.try_set(b, stat, 4, "tech", "")
		"scripter":
			b = build.apply_preset("tech", "", tier, "scripter")
	build.pending = build.finalize(b, "tech", "") if variant != "zero" else b


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var pb := root.get_node("Playbook")
	var sk := root.get_node("Skills")
	var story := root.get_node("Story")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	# `-- --build=zero|worst|ps4|net4|people4|scripter` plays the same 20 days with a point-buy build instead of the
	# maxed skills (X7: the build extremes must still pass the story)
	var variant := ""
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--build="):
			variant = str(arg).substr(8)
	if variant != "":
		_pick_build(variant)
	c.new_game("tech")
	if variant == "":
		sk.ps_level = 5
		for key in ["networking", "servers", "security", "people"]:
			sk.xp[key] = 200
	else:
		print("build: ", root.get_node("Build").describe(c.build, "tech", ""), " tier ", root.get_node("Difficulty").tier)
	var reports := 0
	for day in range(1, 21):
		_check(c.day == day and c.active, "day %d starts" % day)
		world.clock = 8.6
		var hour := 8.6
		while not report.is_open and hour < 23.9:
			hour += 0.25
			world.clock = hour
			await process_frame
			await process_frame
			_drain(cards)
			_work(msp, pb)
		_check(
			report.is_open,
			"day %d ends with a report (grade %s)" % [day, str(report.report.get("grade", "?"))]
		)
		reports += 1
		report.finish()
		if day < 20:
			await create_timer(0.7).timeout
			root.get_node("Game").busy = false
	await process_frame
	_check(review.is_open, "yearly review after day 20")
	_check(
		review.offers.size() >= 2,
		"offers: %s" % str(review.offers.map(func(o: Dictionary) -> String: return o.id))
	)
	for page in 4:
		review.page_lines()
		if page == 2:
			review.choose(0)
		else:
			review.advance()
	_check(
		review.ending != "" and not review.is_open or review.page == 3,
		"review reaches the epilogue (%s)" % review.ending
	)
	review.finish()
	await create_timer(0.5).timeout
	_check(not c.active and not c.has_save("tech"), "campaign finished and the save is gone")
	for key in [
		"ticket", "ransomware", "adobe", "install", "rack", "migration", "email24", "netinstall"
	]:
		_check(seen.has(key), "saw a '%s' ticket during the run" % key)
	for key in ["ransom", "rack", "migration", "email24", "netinstall", "install"]:
		_check(story.flags.has(key), "story flag '%s' = %s" % [key, str(story.flags.get(key, "-"))])
	DirAccess.remove_absolute(c.save_prefix + "meta.cfg")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
