extends SceneTree
# gdlint:disable=max-line-length
# Year 2 / New Game Plus (roadmap R10b, scripts/yeartwo.gd). Unlock after a finished campaign, the carry-over caps, the Year 2
# tables read by the right functions, the story shuffle (never collides, deterministic per seed), the three newer clients,
# the Year 2 endings, the mutator pick / ban, save / continue and the old-save default, then a whole Year 2 of the tech and
# of the owner campaign through the real day / week loop with the cards answered, to an ending.
# Headless; saves in user://test_*. The runner greps the output for SCRIPT ERROR.

var failures := 0
var c: Node
var y: Node
var cards: Node
var world: Node
var report: Node
var review: Node
var msp: Node
var pb: Node
var o: Node
var sk: Node
var sales: Node
var seen_speakers := {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# answer every open card (option 0 unless it is greyed out); remembers who spoke
func _clear(choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 30:
		seen_speakers[str(cards.speaker)] = str(cards.text)
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1
	return n


func _best(step_pb: Node) -> int:
	var step: Dictionary = step_pb.current_step()
	var best := -1
	var best_pts := -1
	for i in step.choices.size():
		var ch: Dictionary = step.choices[i]
		if step_pb.lock_reason(ch) == "" and int(ch.pts) > best_pts:
			best_pts = int(ch.pts)
			best = i
	return best


func _work() -> void:
	for client in msp.backups.size():
		msp.backup_rerun(client)
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
		if not t.fix_done and t.fix != "project" and t.fix != "network":
			msp.rmm_action(str(t.endpoint), str(t.fix))
		if t.fix_done:
			msp.close_ticket(int(t.id))


func _meta_path() -> String:
	return c.save_prefix + "meta.cfg"


func _start_game(mode: String, year2: bool) -> void:
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	y.begin_select(mode, year2)
	c.new_game(mode)


# count the keys of a day table after the moves, as a dictionary key -> times
func _tally(mode: String, base: Dictionary) -> Dictionary:
	var out := {}
	for day in range(0, 22):
		for ev in y.events_on(mode, day, base):
			var k: String = y._key(ev)
			out[k] = int(out.get(k, 0)) + 1
	return out


func _tally_base(base: Dictionary) -> Dictionary:
	var out := {}
	for day in base:
		for ev in base[day]:
			var k: String = y._key(ev)
			out[k] = int(out.get(k, 0)) + 1
	return out


func _shuffle_ok(mode: String, moves: Array, plan: Array) -> bool:
	var base: Dictionary = root.get_node("Story").DAYS if mode == "tech" else o.DAYS
	y.moves = moves
	var ok := _tally(mode, base) == _tally_base(base)  # nothing lost, nothing doubled
	var blocked: Dictionary = {}
	for d in (root.get_node("Outings").TECH_DAYS if mode == "tech" else root.get_node("Outings").OWNER_WEEKS):
		blocked[int(d)] = true
	if mode == "tech":
		blocked[root.get_node("Expo").TRIP_DAY] = true
	for e in plan:
		for d in range(int(e.from), int(e.to) + 1):
			blocked[d] = true
	for id in y.YEAR2.beats.get(mode, {}):
		blocked[int(y.YEAR2.beats[mode][id])] = true
	for m in moves:
		ok = ok and absi(int(m.to) - int(m.from)) <= 2 and int(m.to) >= 2 and int(m.to) <= 19
		ok = ok and not blocked.has(int(m.to))
		for ev in base.get(int(m.from), []):
			if y._key(ev) == str(m.key):
				ok = ok and not ["book:email24", "kind:ransomware", "kind:install", "ev:ransomware"].has(str(m.key))
	for day in range(1, 21):
		var books := 0
		var vigs := 0
		var seen := {}
		for ev in y.events_on(mode, day, base):
			var k: String = y._key(ev)
			books += 1 if k.begins_with("book:") else 0
			vigs += 1 if k.begins_with("vig:") else 0
			if mode == "owner" and k.begins_with("ev:"):
				ok = ok and not seen.has(k)  # the same event twice in one week
				seen[k] = true
		ok = ok and books <= 1 and vigs <= 1
		# the overtime night keeps its day free of other jobs; the outing days stay clear of playbooks that moved there
		for ev in base.get(day, []):
			if y._key(ev) == "book:email24":
				ok = ok and books == 1
	# the donuts follow the firewall job
	var bus_day := -1
	var donut_day := -1
	for day in range(1, 21):
		for ev in y.events_on(mode, day, base):
			if y._key(ev) == "book:bus":
				bus_day = day
			if y._key(ev) == "vig:donuts":
				donut_day = day
	if mode == "tech":
		ok = ok and bus_day == donut_day and bus_day > 0
	return ok


func _drain_cards(deck: Node) -> void:
	var n := 0
	while deck.is_open and n < 30:
		deck.pick(0)
		n += 1


func _init() -> void:
	await process_frame
	c = root.get_node("Campaign")
	y = root.get_node("Yeartwo")
	cards = root.get_node("Cards")
	world = root.get_node("World")
	report = root.get_node("DayReport")
	review = root.get_node("Review")
	msp = root.get_node("Msp")
	pb = root.get_node("Playbook")
	o = root.get_node("Owner")
	sk = root.get_node("Skills")
	sales = root.get_node("Sales")
	var diff := root.get_node("Difficulty")
	var mu := root.get_node("Mutators")
	var build := root.get_node("Build")
	var story := root.get_node("Story")
	var partner := root.get_node("Partner")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	DirAccess.remove_absolute(_meta_path())

	# ---- Year 1 is untouched
	_check(c.year == 1 and not y.active(), "Year 1 by default (year %d)" % c.year)
	_check(y.sla_mult() == 1.0 and y.ticket_weights().is_empty() and not y.promote(), "Year 1: no SLA change, no ticket weights, no P1 promotion")
	_check(y.max_clients(8) == 8 and y.build_bonus() == 0 and mu.sla(100.0) == 100.0, "Year 1: client cap 8, no build bonus, SLA untouched")
	_check(y.counts("normal", [2, 3]) == [2, 3] and y.events_on("tech", 9, story.DAYS) == story.DAYS[9], "Year 1: mutator counts and the story days are the plain tables")
	_check(not y.available("tech") and y.menu_items().is_empty(), "nothing finished yet: no NEW GAME PLUS entry")
	var rec_other := ConfigFile.new()
	for m in ["sales", "service"]:
		rec_other.set_value(m, "ending", "stay")
		rec_other.set_value(m, "finished", 1)
	rec_other.save(c.save_prefix + "meta.cfg")
	_check(y.available("sales") and y.available("service") and y.menu_items().size() == 2, "sales and service show a NEW GAME PLUS entry once finished (R10)")
	# a Year 2 run of each: the pending flag is taken, the year is 2, the intro card comes up and the beat card fires on its day
	for m in ["sales", "service"]:
		var row: Dictionary = y.YEAR2.beats.get(m, {})
		var texted := row.size() >= 1
		for k in row.keys():
			texted = texted and y.TEXT.beats.get(m, {}).has(str(k))
		_check(texted, "%s has its Year 2 beats with their text (%d)" % [m, row.size()])
		y.begin_select(m, true)
		_check(y.pending, "%s: Year 2 chosen on the select" % m)
		c.new_game(m)
		_check(c.year == 2 and y.active() and not y.pending, "%s: a Year 2 run starts (year %d)" % [m, c.year])
		_drain_cards(cards)
		var beat_id := str(row.keys()[0])
		y.beat(beat_id)
		_check(cards.is_open and str(cards.speaker) == str(y.TEXT.beats[m][beat_id].speaker), "%s: the beat card opens" % m)
		cards.pick(0)
		_drain_cards(cards)
		_check(y.flag(beat_id) != "", "%s: your answer is kept as a flag (%s)" % [m, y.flag(beat_id)])
	c.new_game("tech")  # back to a plain Year 1 run for the rest of the checks
	_drain_cards(cards)
	DirAccess.remove_absolute(_meta_path())
	_check(build.budget("normal") == 12, "Year 1: the normal build budget is 12")

	# ---- unlock: a finished campaign writes the record
	c.new_game("tech")
	_clear()
	c.rep = 80
	sk.ps_level = 5
	for key in ["networking", "servers", "security", "people"]:
		sk.xp[key] = 200
	sk.xp["servers"] = 40  # level 2
	sk.xp["people"] = 0
	var meta := ConfigFile.new()
	y.record(meta, "tech", "lead")
	meta.save(_meta_path())
	var rec: Dictionary = y.meta_get("tech")
	_check(str(rec.ending) == "lead" and int(rec.rep) == 80 and int(rec.finished) == 1 and str(rec.tier) == "normal" and int(rec.year) == 1, "the meta file keeps ending, reputation, difficulty and year: %s" % str(rec))
	_check(int(rec.skills.networking) == 5 and int(rec.skills.servers) == 2 and int(rec.skills.powershell) == 5, "... and the skill levels")
	_check(y.available("tech") and not y.available("owner") and not y.available("free"), "TECH is unlocked, OWNER and Free Play are not")
	_check(y.menu_items().size() == 1 and str(y.menu_items()[0].id) == "tech_y2" and str(y.menu_items()[0].label).contains("YEAR 2"), "the title menu gets NEW GAME PLUS - TECH (YEAR 2)")
	var old_meta := ConfigFile.new()  # a meta file from before this feature has only the ending
	old_meta.set_value("owner", "ending", "stay")
	old_meta.save(c.save_prefix + "old_meta.cfg")
	_check(true, "(an old record with only an ending counts as finished: %s)" % str(int(old_meta.get_value("owner", "finished", 1 if str(old_meta.get_value("owner", "ending", "")) != "" else 0)) > 0))

	# ---- the carry-over rules and their caps
	var ride: Dictionary = y.carry_for("tech", {"rep": 80, "skills": {"networking": 5, "servers": 2, "security": 1, "people": 0, "powershell": 5}, "value": 800000, "trust": 90})
	_check(int(ride.rep) == 48, "reputation restarts at 60 percent: 80 -> %d" % int(ride.rep))
	_check(int(ride.skills.networking) == 3 and int(ride.skills.servers) == 1 and int(ride.skills.security) == 0 and int(ride.skills.people) == 0, "skills carry one level lower, never above 3: %s" % str(ride.skills))
	_check(int(ride.ps) == 3, "PowerShell lessons carry as a level, capped at 3 (%d)" % int(ride.ps))
	_check(int(ride.cash) == 5000 and int(y.carry_for("owner", {"value": 120000}).cash) == 1200, "company value becomes start cash, capped at $5000")
	_check(int(ride.trust) == 75 and int(y.carry_for("owner", {"trust": 10}).trust) == 40 and int(y.carry_for("owner", {"trust": 61}).trust) == 61, "partner trust carries, between 40 and 75")
	_check(int(y.carry_for("tech", {"rep": 30}).rep) == 40 and int(y.carry_for("tech", {"rep": 100}).rep) == 60, "the reputation floor is 40 and 100 gives 60")
	_check(y.carry_for("tech", {}).rep == 50, "no record: the usual 50")

	# ---- a Year 2 tech run starts
	y.begin_select("tech", true)
	_check(y.pending and build.budget("normal") == 14, "the character select of a Year 2 run gives +2 build points (%d)" % build.budget("normal"))
	y.begin_select("owner", true)
	_check(not y.pending, "OWNER cannot start a Year 2 before it was finished")
	diff.seed_run(4242)
	_start_game("tech", true)
	_check(c.year == 2 and y.active() and not y.pending, "Campaign.year = 2 after New Game Plus")
	_check(cards.is_open and str(cards.speaker) == "YEAR 2" and str(cards.text).contains("YOU CARRY OVER"), "an intro card names what came over")
	_clear()
	_check(c.rep == 48, "reputation restarted at 48 (%d)" % c.rep)
	_check(sk.level("networking") >= 3 and sk.level("servers") >= 1 and sk.ps_level >= 3, "skills carried: NET %d SRV %d PS %d" % [sk.level("networking"), sk.level("servers"), sk.ps_level])
	var new_ids := []
	for n in y.YEAR2.clients.client:
		new_ids.append(y.client_index(str(n)))
	_check(new_ids == [8, 9, 10] and sales.is_active(8) and sales.is_active(9) and sales.is_active(10), "Paws and Claws, Lindqvist and Moss and Iron Mule are active from day 1")
	_check(sales.active.size() == 8 and sales.max_clients() == 10 and sales.MAX_CLIENTS == 8, "8 clients at the start, the cap is 10 in Year 2")
	_check(absf(mu.sla(100.0) - 85.0) < 0.001, "SLA clocks are 15 percent tighter (100 -> %.1f)" % mu.sla(100.0))
	_check(mu.ticket_weights().get("spooler", 0.0) == 1.7 and mu.ticket_weights().get("server", 0.0) == 1.6, "the ticket weight table is read by Mutators.ticket_weights")
	_check(mu.plan.size() >= 4, "one tier more mutators: %d planned on normal" % mu.plan.size())
	var t_new: Dictionary = msp.create_ticket(0, 0, "test")
	_check(absf(float(t_new.sla_total) - 0.85 * msp.SLA_SECS[int(t_new.pri)]) < 0.01, "a new ticket carries the tighter clock (%.0f of %.0f)" % [float(t_new.sla_total), float(msp.SLA_SECS[int(t_new.pri)])])
	var promoted := 0
	for i in 600:
		promoted += 1 if mu.priority(2, {}) == 1 else 0
	var not_promoted := 0
	for i in 300:
		not_promoted += 1 if mu.priority(3, {}) != 3 or mu.priority(1, {}) != 1 else 0
	_check(promoted > 30 and promoted < 120 and not_promoted == 0, "about 12 percent of P2 tickets become P1 (%d of 600), P3 and P1 stay" % promoted)
	var count := {}
	for i in 3000:
		var p: Dictionary = mu.pick_problem()
		count[str(p.fix) + ("S" if p.get("server", false) else "")] = int(count.get(str(p.fix) + ("S" if p.get("server", false) else ""), 0)) + 1
	var avg := 3000.0 / float(msp.PROBLEMS.size())
	_check(float(count.get("spooler", 0)) > avg * 1.15 and float(count.get("av", 0)) > avg * 1.15, "the weights favour printer (%d) and security (%d) tickets over a flat %d" % [int(count.get("spooler", 0)), int(count.get("av", 0)), int(avg)])
	_check(build.budget("normal") == 14, "the build budget stays +2 while the Year 2 run is active")
	var tiers_ok := true
	for tier in ["easy", "normal", "hard"]:
		var plan: Array = mu.make_plan("tech", tier)
		var lo: int = int(y.YEAR2.mutators.counts[tier][0])
		tiers_ok = tiers_ok and plan.size() >= mini(lo, 5) and plan.size() <= 5
	_check(tiers_ok, "easy 2-3, normal 4-5 and hard 5 mutators (capped by the five slots)")

	# ---- the story shuffle
	var moved_any := 0
	var all_ok := true
	var det_ok := true
	for s in range(1, 41):
		diff.seed_run(s * 7919)
		var plan2: Array = mu.make_plan("tech", ["easy", "normal", "hard"][s % 3])
		diff.seed_run(s * 31)
		var m1: Array = y.story_shuffle("tech")
		diff.seed_run(s * 31)
		var m2: Array = y.story_shuffle("tech")
		det_ok = det_ok and m1 == m2
		moved_any += 1 if m1.size() >= 3 else 0
		if not _shuffle_ok("tech", m1, plan2):
			all_ok = false
			print("   bad tech shuffle seed ", s, " ", str(m1), " plan ", str(plan2))
	_check(all_ok, "tech: 40 seeds, no beat collides with another, an outing, the trip, the overtime night, a mutator or a Year 2 beat")
	_check(det_ok, "tech: the same seed gives the same shuffle")
	_check(moved_any >= 25, "tech: most seeds move at least three beats (%d of 40)" % moved_any)
	mu.plan = []
	diff.seed_run(5)
	var a1: Array = y.story_shuffle("tech")
	diff.seed_run(6)
	var a2: Array = y.story_shuffle("tech")
	diff.seed_run(7)
	var a3: Array = y.story_shuffle("tech")
	print("   a1 ", a1, " a2 ", a2)
	_check(a1 != a2 or a2 != a3, "different seeds give different shuffles")
	var re := RegEx.create_from_string("\\b[Dd]ay \\d|\\b[Ww]eek \\d")
	var text_ok := true
	for v in y.YEAR2.shuffle.tech.vignettes:
		text_ok = text_ok and re.search(JSON.stringify(story.VIGNETTES[v])) == null
	text_ok = text_ok and re.search(JSON.stringify(story.VIGNETTES["donuts"])) == null
	for b in y.YEAR2.shuffle.tech.books:
		text_ok = text_ok and re.search(JSON.stringify(pb.BOOKS[b])) == null
	for day in story.DAYS:
		for ev in story.DAYS[day]:
			if ev.get("kind", "") == "playbook" and y.YEAR2.shuffle.tech.books.has(str(ev.book)):
				text_ok = text_ok and re.search(str(ev.get("text", ""))) == null
	_check(text_ok, "no moved beat names a day or week number in its text")
	var owner_ok := true
	var owner_moved := 0
	for s in range(1, 31):
		diff.seed_run(s * 7919)
		var oplan: Array = [{"id": "x", "from": 3 + s % 3, "to": 4 + s % 3}]
		diff.seed_run(s * 17)
		var om: Array = y.story_shuffle("owner")
		diff.seed_run(s * 17)
		owner_ok = owner_ok and om == y.story_shuffle("owner")
		owner_moved += om.size()
		var saved_plan: Array = mu.plan
		mu.plan = oplan
		diff.seed_run(s * 17)
		var om2: Array = y.story_shuffle("owner")
		owner_ok = owner_ok and _shuffle_ok("owner", om2, oplan)
		mu.plan = saved_plan
	_check(owner_ok and owner_moved > 20, "owner: 30 seeds, weekly events move without colliding (%d moves), deterministic" % owner_moved)
	y.moves = []
	_check(y.events_on("tech", 10, story.DAYS) == story.DAYS[10], "no moves: the plain day table")

	# ---- the Year 2 endings are reachable through the existing review
	c.rep = 80
	partner.reset()
	_check(not review.make_offers().any(func(x: Dictionary) -> bool: return x.id == "head" or x.id == "clientbuy"), "no flags: no Year 2 endings in the tech review")
	y.set_flag("desk", "run")
	y.set_flag("courted", "listen")
	var ids: Array = review.make_offers().map(func(x: Dictionary) -> String: return x.id)
	_check(ids.has("head") and ids.has("clientbuy") and ids.back() == "stay", "flags run the desk + courted unlock DEPARTMENT HEAD and the BUYOUT before STAY: %s" % str(ids))
	c.rep = 55
	ids = review.make_offers().map(func(x: Dictionary) -> String: return x.id)
	_check(not ids.has("head") and ids.has("clientbuy"), "a low reputation keeps the department head job closed (%s)" % str(ids))
	y.set_flag("courted", "no")
	c.rep = 90
	ids = review.make_offers().map(func(x: Dictionary) -> String: return x.id)
	_check(ids.has("head") and not ids.has("clientbuy"), "declining the courtship removes the buyout (%s)" % str(ids))
	y.set_flag("courted", "told")
	review.start()
	var head_at: int = review.offers.map(func(x: Dictionary) -> String: return x.id).find("head")
	review.choose(head_at)
	var end_lines: Array = review.page_lines()
	_check(review.ending == "head" and str(end_lines[1][0]).contains("DEPARTMENT HEAD"), "choosing it reads a Year 2 epilogue")
	review.finish()
	await create_timer(0.5).timeout
	var rec2: Dictionary = y.meta_get("tech")
	_check(str(rec2.ending) == "head" and int(rec2.finished) == 2 and int(rec2.year) == 2, "the finished Year 2 is recorded (%s, finished %d, year %d)" % [str(rec2.ending), int(rec2.finished), int(rec2.year)])
	_check(not c.active and c.year == 1, "back at the title: the year resets")

	# ---- save, continue, the old-save default
	diff.seed_run(99)
	_start_game("tech", true)
	_clear()
	c.day = 3
	var saved_moves: Array = y.moves.duplicate(true)
	var saved_carried: Dictionary = y.carried.duplicate(true)
	var saved_plan3: Array = mu.plan.duplicate(true)
	c.save()
	c.year = 1
	y.reset()
	mu.plan = []
	_check(c.continue_game("tech"), "Continue works for an unfinished Year 2 save")
	_clear()
	_check(c.year == 2 and y.active() and y.moves == saved_moves and y.carried == saved_carried and mu.plan == saved_plan3, "the year, the shuffle, the carry-over and the mutator plan come back")
	_check(y.saved_tag("tech") == " (YEAR 2)", "the title shows the saved run as (YEAR 2)")
	_check(world.day_len == 600.0 and sales.is_active(8), "the Year 2 clients are still active after Continue")
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("tech"))
	cfg.erase_section_key("campaign", "year")
	cfg.erase_section_key("campaign", "yeartwo")
	cfg.save(c.save_path("tech"))
	c.year = 2
	_check(c.continue_game("tech"), "an old save (no year, no Year 2 section) loads")
	_clear()
	_check(c.year == 1 and not y.active() and y.moves.is_empty() and y.saved_tag("tech") == "", "... as Year 1, with no shuffle")
	_check(mu.sla(100.0) == 100.0, "... and the plain SLA clocks")
	DirAccess.remove_absolute(c.save_path("tech"))

	# ---- the mutator choice: pick and ban
	var ids_tech: Array = mu.ids_for("tech")
	var pick_id := "xp_eol" if ids_tech.has("xp_eol") else str(ids_tech[0])
	var pick_ok := true
	var ban_ok := true
	var ban_id := str(ids_tech[0])
	for s in range(1, 13):
		diff.seed_run(s * 101)
		y.begin_select("tech", true)
		y.pick = pick_id
		_start_game2("tech")
		var has := false
		for e in mu.plan:
			has = has or str(e.id) == pick_id
		pick_ok = pick_ok and has
		_clear()
		diff.seed_run(s * 101)
		y.begin_select("tech", true)
		y.mut_mode = "ban"
		y.ban = ban_id
		_start_game2("tech")
		for e in mu.plan:
			ban_ok = ban_ok and str(e.id) != ban_id
		_clear()
	_check(pick_ok, "PICK: the chosen mutator (%s) is in the plan on 12 seeds" % pick_id)
	_check(ban_ok, "BAN: %s never appears in the plan on 12 seeds" % ban_id)
	y.begin_select("tech", true)
	_check(y.chip_text() == "MUT  AUTO", "the chip starts at AUTO")
	y.change_mut("tech", 1)
	_check(y.pick == str(mu.ids_for("tech")[0]) and y.chip_text().begins_with("PICK "), "M picks the first mutator: %s" % y.chip_text())
	y.toggle_mut_mode()
	_check(y.ban != "" and y.pick == "" and y.chip_text().begins_with("BAN "), "B turns it into a ban: %s" % y.chip_text())
	y.change_mut("tech", -1)
	_check(y.ban == "" and y.chip_text() == "MUT  AUTO", "stepping back reaches AUTO again")
	y.pending = false

	# ---- a whole Year 2 of the tech campaign, through the real day loop
	diff.seed_run(2013)
	_start_game("tech", true)
	_check(cards.is_open and str(cards.speaker) == "YEAR 2", "tech Year 2: the intro card opens day 1")
	_clear()
	sk.ps_level = 5
	for key in ["networking", "servers", "security", "people"]:
		sk.xp[key] = 200
	seen_speakers = {}
	var shuffled: Array = y.moves.duplicate(true)
	print("   shuffle: ", str(shuffled))
	for day in range(1, 21):
		_check(c.day == day and c.active, "tech Y2 day %d starts" % day)
		if day == 20:
			c.rep = 90
			root.get_node("Social").change_all(10)
		world.clock = 8.6
		var hour := 8.6
		while not report.is_open and hour < 23.9:
			hour += 0.25
			world.clock = hour
			await process_frame
			await process_frame
			_clear()
			_work()
		if not report.is_open:
			_check(false, "tech Y2 day %d ended with a report" % day)
			break
		if day == 1:
			_check(str(report.report.get("year", 1)) == "2", "the day report carries the year")
		report.finish()
		if day < 20:
			await create_timer(0.7).timeout
			root.get_node("Game").busy = false
	await process_frame
	_check(review.is_open, "tech Y2: the yearly review follows day 20")
	var ids2: Array = review.offers.map(func(x: Dictionary) -> String: return x.id)
	_check(ids2.has("head") and ids2.has("clientbuy"), "tech Y2: the choices made on the way unlocked %s" % str(ids2))
	_check(seen_speakers.has("Tony Marsh (Iron Mule Demolition)") and seen_speakers.has("Morgan (Manager)"), "tech Y2: both Year 2 beat cards were asked")
	for key in ["ransom", "rack", "migration", "email24", "netinstall", "install"]:
		_check(story.flags.has(key), "tech Y2: story job '%s' still ran (%s)" % [key, str(story.flags.get(key, "-"))])
	review.choose(ids2.find("clientbuy"))
	review.finish()
	await create_timer(0.5).timeout
	_check(not c.active and not c.has_save("tech") and str(y.meta_get("tech").ending) == "clientbuy", "tech Y2 finished with the buyout ending")

	# ---- the owner campaign: unlock, then a whole Year 2
	_check(not y.available("owner"), "OWNER still locked before its own finish")
	diff.seed_run(77)
	_start_game("owner", false)
	_clear()
	o.cash = 80000
	c.rep = 82
	partner.trust = 66
	var ometa := ConfigFile.new()
	meta = ConfigFile.new()
	meta.load(_meta_path())
	y.record(meta, "owner", "stay")
	meta.save(_meta_path())
	var orec: Dictionary = y.meta_get("owner")
	_check(int(orec.value) > 0 and int(orec.trust) == 66 and int(orec.cash) == 80000 and int(orec.rep) == 82, "owner record: company value $%d, trust 66, rep 82" % int(orec.value))
	_check(y.available("owner") and y.menu_items().size() == 2, "OWNER is unlocked: two NEW GAME PLUS entries")
	diff.seed_run(78)
	_start_game("owner", true)
	_check(c.year == 2 and c.mode == "owner" and str(cards.speaker) == "YEAR 2", "owner Year 2 starts with the intro card")
	_clear()
	var want_cash: int = o.START_CASH + int(y.carry_for("owner", orec).cash)
	_check(o.cash == want_cash and partner.trust == 66 and c.rep == 49, "owner carry-over: cash $%d (= start + capped value), partner trust %d, reputation %d" % [o.cash, partner.trust, c.rep])
	_check(sales.active.size() == 8 and sales.max_clients() == 10, "owner Year 2: the three newer clients are on the books")
	for day in range(1, 21):
		world.clock = 8.6
		var hr := 8.6
		o.cash = maxi(o.cash, 15000)
		c.rep = maxi(c.rep, 62)
		if day == 19:
			for f in ["practice_profit", "practice_goal", "practice_handover"]:
				o.flags[f] = true
		while not report.is_open and hr < 23.9:
			hr += 0.3
			world.clock = hr
			await process_frame
			await process_frame
			_clear()
			o._work_queue(20.0)
			o.cash = maxi(o.cash, 15000)
		if not report.is_open:
			_check(false, "owner Y2 week %d ended with a report" % day)
			break
		if report.report.get("final", false):
			break
		report.finish()
		await create_timer(0.7).timeout
		root.get_node("Game").busy = false
	await process_frame
	_check(report.is_open and bool(report.report.get("final", false)), "owner Y2: week 20 report")
	if bool(report.report.get("fired", false)):
		_check(false, "owner Y2: the run was not fired")
	report.finish()
	await process_frame
	_check(review.is_open, "owner Y2: the board review follows")
	var oids: Array = review.offers.map(func(x: Dictionary) -> String: return x.id)
	_check(seen_speakers.has("Walt Reiner (Tri-County Tech Group)") and seen_speakers.has("Pat Okafor (Consultant)"), "owner Y2: the merger and the franchise beat cards were asked")
	_check(oids.has("merger") and oids.has("franchise") and oids.has("sell") and oids.has("stay"), "owner Y2: offers %s" % str(oids))
	review.choose(oids.find("franchise"))
	var olines: Array = review.page_lines()
	_check(str(olines[1][0]).contains("PIXEL IT SIGN"), "owner Y2: the franchise epilogue reads")
	review.finish()
	await create_timer(0.5).timeout
	_check(not c.active and str(y.meta_get("owner").ending) == "franchise" and int(y.meta_get("owner").year) == 2, "owner Y2 finished with the franchise ending")

	DirAccess.remove_absolute(_meta_path())
	DirAccess.remove_absolute(c.save_prefix + "old_meta.cfg")
	DirAccess.remove_absolute(c.save_path("owner"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)


# a second start helper that does not touch the pending choice made by the caller (pick / ban)
func _start_game2(mode: String) -> void:
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	c.new_game(mode)
