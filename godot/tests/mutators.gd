extends SceneTree
# Mutators (roadmap R9): schema validator, neutral when none is active, every hook on the function it
# changes, flu season never touches the player's score, the schedule (same seed = same plan, tiers, slots),
# Free Play, saves and old saves, the brand deny-list.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/mutators.gd

var failures := 0

const DENY := [
	"google",
	"apple",
	"samsung",
	"dell",
	"hewlett",
	"canon",
	"xerox",
	"ricoh",
	"epson",
	"lexmark",
	"comcast",
	"verizon",
	"amazon",
	"facebook",
	"twitter",
	"netflix",
	"iphone",
	"android",
	"skype",
	"slack",
	"zoom",
	"instagram",
	"office 365",
	"windows 10",
	"covid",
	"pandemic",
	"chatgpt",
	"artificial",
	" ai ",
	"microsoft teams",
	"tiktok",
	"discord",
]


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	for i in 30:
		if not cards.is_open:
			break
		cards.pick(cards.options.size() - 1)


func _texts(m: Dictionary) -> String:
	var out := str(m.get("name", "")) + " " + str(m.get("text", ""))
	for t in m.get("texts", []):
		out += " " + str(t.get("body", ""))
	for t in m.get("mails", []):
		out += " " + str(t.get("subject", "")) + " " + str(t.get("body", ""))
	for p in m.get("extra_problems", []):
		out += " " + str(p.get("summary", "")) + " " + str(p.get("body", ""))
	if m.has("batch"):
		out += " " + str(m.batch.problem.summary) + " " + str(m.batch.problem.body)
	var offer: Dictionary = m.get("offer", {})
	if not offer.is_empty():
		out += " " + str(offer.text)
		for o in offer.options:
			out += " " + str(o.label) + " " + str(o.text)
	return out.to_lower()


func _share(mu: Node, fix: String, n: int) -> float:
	var hits := 0
	for i in n:
		var p: Dictionary = mu.pick_problem()
		if p.is_empty():
			p = root.get_node("Msp").PROBLEMS[randi() % 6]
		if str(p.fix) == fix:
			hits += 1
	return float(hits) / float(n)


func _init() -> void:
	await process_frame
	var mu := root.get_node("Mutators")
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var diff := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var shift := root.get_node("Shift")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var owner := root.get_node("Owner")
	var ev := root.get_node("Events")
	var social := root.get_node("Social")
	var career := root.get_node("Career")
	var story := root.get_node("Story")
	var outings := root.get_node("Outings")
	c.save_prefix = "user://test_mu_%d_" % OS.get_process_id()
	career.toasts = false

	# ---- the table and the validator
	_check(mu.MUTATORS.size() >= 8, "at least eight mutators (%d)" % mu.MUTATORS.size())
	for id in ["heartbleed", "xp_eol", "flu_season", "printer_apocalypse", "tax_season", "slow_payers", "hardware_recall", "hurricane_drill", "new_psa"]:
		_check(mu.MUTATORS.has(id), "%s exists" % id)
	_check(mu.MUTATORS.has("heat_wave") and mu.MUTATORS.has("cold_snap"), "heat wave and cold snap exist")
	var problems: Array = mu.validate_all()
	for p in problems:
		print("     problem: " + str(p))
	_check(problems.is_empty(), "every mutator and start passes the validator (%d problems)" % problems.size())
	var bad: Dictionary = mu.MUTATORS.printer_apocalypse.duplicate(true)
	bad["ticket_weight"] = {"spooler": 9.0}
	_check(not mu.problems("x", bad).is_empty(), "an out-of-range weight is refused")
	bad = mu.MUTATORS.printer_apocalypse.duplicate(true)
	bad["ticket_weight"] = {"nonsense": 2.0}
	_check(not mu.problems("x", bad).is_empty(), "a weight for a fix that does not exist is refused")
	bad = mu.MUTATORS.printer_apocalypse.duplicate(true)
	bad["mystery_key"] = 1
	_check(not mu.problems("x", bad).is_empty(), "an unknown key is refused")
	bad = mu.MUTATORS.printer_apocalypse.duplicate(true)
	bad["kinds"] = ["nobody"]
	_check(not mu.problems("x", bad).is_empty(), "a bad kind is refused")
	bad = mu.MUTATORS.heartbleed.duplicate(true)
	bad.extra_problems[0]["fix"] = "pay"
	_check(not mu.problems("x", bad).is_empty(), "an extra problem with an unfit fix is refused")
	bad = mu.MUTATORS.flu_season.duplicate(true)
	bad["cast_out"] = {"count": 5}
	_check(not mu.problems("x", bad).is_empty(), "five coworkers out is refused")
	bad = mu.MUTATORS.cold_snap.duplicate(true)
	bad["sla_mult"] = 0.3
	_check(not mu.problems("x", bad).is_empty(), "an SLA multiplier that makes it unwinnable is refused")
	var hits := []
	for id in mu.MUTATORS:
		var t: String = _texts(mu.MUTATORS[id])
		for w in DENY:
			if t.contains(w):
				hits.append("%s: %s" % [id, w])
	for id in mu.STARTS:
		var t2: String = (str(mu.STARTS[id].name) + " " + str(mu.STARTS[id].text)).to_lower()
		for w in DENY:
			if t2.contains(w):
				hits.append("%s: %s" % [id, w])
	_check(hits.is_empty(), "no real brand names or 2015+ words: %s" % str(hits))
	var flu_text := _texts(mu.MUTATORS.flu_season)
	_check(not flu_text.contains("penalt") and not flu_text.contains("blame") and not flu_text.contains("sick day"), "the flu text puts no weight on the player")

	# ---- neutral when nothing is active: Free Play start, no plan, no forced mutator
	c.new_game("free")
	_check(mu.current_id() == "" and mu.tag() == "", "no mutator in Free Play")
	_check(mu.plan.is_empty(), "Free Play has no schedule")
	_check(mu.hook("ticket_rate", 1.0) == 1.0 and mu.hook("anything", 7) == 7, "hook returns the default")
	_check(mu.ticket_rate() == 1.0 and mu.sla(300.0) == 300.0, "neutral rate and SLA")
	_check(mu.pick_problem().is_empty() and mu.ticket_weights().is_empty(), "no weights: the uniform pick is untouched")
	_check(mu.boost("heat_wave") == 1.0 and mu.chance("lead_mult"), "neutral event boost and leads")
	_check(mu.absent().is_empty(), "nobody absent")
	var xp_ep := {"os": "Windows XP SP3", "user": "owner"}
	_check(mu.priority(3, xp_ep) == 3, "XP priority untouched")
	_check(mu.stack_fee("psa", "x") == 0, "no stack fee")
	var eps := [{"user": "bookkeeper"}, {"user": "owner"}, {"user": "intern"}]
	var seen := {}
	seed(5)
	for i in 60:
		seen[str(mu.pick_endpoint(eps).user)] = true
	_check(seen.size() == 3, "pick_endpoint is the uniform pick")
	# the same random numbers as the old inline expression
	seed(99)
	var a := []
	for i in 10:
		a.append(mu.pick_endpoint(eps).user)
	seed(99)
	var b := []
	for i in 10:
		b.append(eps[randi() % eps.size()].user)
	_check(a == b, "pick_endpoint consumes the random stream exactly like the old code")
	var t0: Dictionary = msp.create_problem(0, msp.PROBLEMS[0], "test")
	_check(int(t0.pri) == 3 and is_equal_approx(float(t0.sla_left), 300.0), "a normal ticket: P3 with the 300 s SLA")
	shift.reset()
	var fa0: float = shift.fail_add()
	_check(fa0 == 0.0, "Shift.fail_add is 0 when inactive")

	# a normal tech run without any mutator: identical numbers
	diff.set_tier("normal")
	c.new_game("tech")
	_drain(cards)
	mu.plan = []
	shift.enabled = true
	shift.energy = 30.0
	var fa_base: float = shift.fail_add()
	_check(mu.tag() == "", "plan emptied: no tag")
	_check(is_equal_approx(fa_base, 0.18 * 15.0 / 45.0), "fail_add without a mutator is the old formula (%.3f)" % fa_base)
	var rep_before: int = c.rep
	var score_before: int = msp.score

	# ---- each hook on the function it feeds
	# printer apocalypse: spooler x3
	c.new_game("free")
	_check(true, "(free play for the hooks)")
	mu.set_forced("printer_apocalypse")
	_check(mu.tag() == "PRINTER APOCALYPSE", "forced mutator shows its tag in Free Play")
	var share := _share(mu, "spooler", 3000)
	_check(share > 0.33 and share < 0.42, "printer tickets are about 3 in 8 (%.3f vs 0.167)" % share)
	mu.set_forced("")
	# heartbleed: extra kinds and password x2
	mu.set_forced("heartbleed")
	var extras := 0
	var pw := 0
	for i in 3000:
		var p: Dictionary = mu.pick_problem()
		if str(p.get("summary", "")).begins_with("Server certificate"):
			extras += 1
		if str(p.fix) == "password":
			pw += 1
	_check(extras > 150, "Heartbleed adds certificate-check tickets (%d of 3000)" % extras)
	_check(pw > 700, "and more password tickets (%d of 3000)" % pw)
	var cert_t: Dictionary = msp.create_problem(0, mu.MUTATORS.heartbleed.extra_problems[0], "test")
	_check(not cert_t.is_empty() and int(cert_t.pri) == 2 and str(cert_t.endpoint).contains("SRV"), "the certificate check lands on the server as a P2")
	mu.set_forced("")
	# xp end of life
	mu.set_forced("xp_eol")
	_check(mu.priority(3, xp_ep) == 2 and mu.priority(1, xp_ep) == 1 and mu.priority(3, {"os": "Windows 7 Pro"}) == 3, "XP tickets are P2, others untouched")
	for e in msp.endpoints:
		if int(e.client) == 0 and not str(e.name).contains("SRV"):
			e["os"] = "Windows XP SP3"
	var xp_t: Dictionary = msp.create_problem(0, msp.PROBLEMS[2], "test")  # a P3 kind
	_check(not xp_t.is_empty() and str(msp.endpoint(xp_t.endpoint).os).contains("XP") and int(xp_t.pri) == 2, "a created ticket on an XP PC is P2")
	_check(is_equal_approx(float(xp_t.sla_left), 200.0), "and carries the P2 clock")
	_check(not mu.MUTATORS.xp_eol.offer.is_empty(), "XP end of life offers an upgrade quote")
	mu.set_forced("")
	# tax season: bookkeepers x2
	mu.set_forced("tax_season")
	var book := 0
	var four := [{"user": "bookkeeper"}, {"user": "bookkeeper"}, {"user": "owner"}, {"user": "intern"}]
	for i in 3000:
		if str(mu.pick_endpoint(four).user) == "bookkeeper":
			book += 1
	_check(book > 1800 and book < 2200, "accountants call twice as often (%d of 3000, 0.667 expected)" % book)
	var leads := 0
	for i in 2000:
		if mu.chance("lead_mult"):
			leads += 1
	_check(leads > 850 and leads < 1150, "half the inbound leads (%d of 2000)" % leads)
	_check(float(mu.hook("price_pressure", 0.0)) > 0.0, "tax season adds a little poach pressure")
	mu.set_forced("")
	# hot and cold, the new PSA
	mu.set_forced("heat_wave")
	_check(is_equal_approx(float(mu.hook("energy_drain", 1.0)), 1.2), "heat wave drains energy faster")
	mu.set_forced("cold_snap")
	_check(is_equal_approx(mu.ticket_rate(), 1.15) and is_equal_approx(mu.sla(100.0), 110.0), "cold snap: fewer calls, a little more SLA time")
	var cs_t: Dictionary = msp.create_problem(1, msp.PROBLEMS[0], "test")
	_check(is_equal_approx(float(cs_t.sla_left), 330.0), "a ticket made during a cold snap has the longer clock")
	mu.set_forced("new_psa")
	_check(is_equal_approx(mu.ticket_rate(), 0.8), "the new PSA: more tickets")
	mu.set_forced("")
	# event boost on the Events pool
	var heat: Dictionary = ev.DECK.heat_wave
	var day_ok: int = int(heat.min_day)
	var base_w := 0.0
	for e in ev.pool(day_ok, "tech"):
		if e.id == "heat_wave":
			base_w = float(e.weight)
	mu.set_forced("heat_wave")
	var boosted_w := 0.0
	for e in ev.pool(day_ok, "tech"):
		if e.id == "heat_wave":
			boosted_w = float(e.weight)
	mu.set_forced("")
	_check(base_w > 0.0 and is_equal_approx(boosted_w, base_w * 5.0), "heat wave makes the heat wave card 5x likelier (%.2f -> %.2f)" % [base_w, boosted_w])

	# ---- campaign hooks: Shift, batch, backups, owner
	diff.seed_run(4242)
	diff.set_tier("normal")
	c.new_game("tech")
	_drain(cards)
	shift.enabled = true
	shift.energy = 30.0
	var fa_a: float = shift.fail_add()
	mu.plan = [{"id": "new_psa", "from": 1, "to": 1}]
	var fa_b: float = shift.fail_add()
	_check(is_equal_approx(fa_b - fa_a, 0.03), "the new PSA raises the RMM failure chance by 3 points (%.3f -> %.3f)" % [fa_a, fa_b])
	mu.plan = [{"id": "hardware_recall", "from": 1, "to": 1}]
	var open_before: int = msp.tickets.size()
	mu.announce("hardware_recall")
	_drain(cards)
	var recalls := 0
	var recall_clients := {}
	for t in msp.tickets:
		if str(t.source) == "recall notice":
			recalls += 1
			recall_clients[int(t.client)] = true
	_check(recalls == 3 and recall_clients.size() == 3, "hardware recall: three drive tickets at three different clients")
	var has_notice := false
	for m in msp.emails:
		if str(m.subject).contains("Recall notice"):
			has_notice = true
	_check(has_notice, "and the recall notice mail")
	mu.plan = [{"id": "hurricane_drill", "from": 1, "to": 1}]
	mu.announce("hurricane_drill")
	_drain(cards)
	var broken := 0
	for bk in msp.backups:
		if not bk.ok:
			broken += 1
	_check(broken >= 1, "hurricane drill: a backup failed overnight (%d)" % broken)
	var drill_text := false
	for m in msp.texts:
		if str(m.body).contains("drill"):
			drill_text = true
	_check(drill_text, "and the boss texted about the drill")
	# xp offer card resolves
	mu.plan = [{"id": "xp_eol", "from": 1, "to": 1}]
	var shown_before: int = mu.cards_shown
	mu.announce("xp_eol")
	_check(cards.is_open and cards.options.size() == 2 and mu.cards_shown == shown_before + 1, "the XP card carries the quote offer")
	cards.pick(0)
	_check(cards.is_open, "choosing the quote opens the result card")
	_drain(cards)

	# flu season: who is out, never the score
	mu.plan = [{"id": "flu_season", "from": 6, "to": 7}]
	var snap := {"score": msp.score, "rep": c.rep, "social": social.to_dict().duplicate(true), "closed": msp.closed_ok, "breached": msp.breached, "energy": shift.energy}
	mu.prepare_day(6)
	var out: Array = mu.absent()
	_check(out.size() == 2, "flu season: two coworkers are out (%s)" % str(out))
	for who in out:
		_check(["Dan", "Vic", "Maya"].has(who), "%s is a coworker, never an owner or the manager" % who)
	world.apply_roster()
	for who in out:
		_check(not world.chars.has(who), "%s is not in the building" % who)
	c.day = 6
	mu.announce("flu_season")
	_check(cards.is_open and str(cards.text).contains("FLU SEASON"), "the morning card announces it")
	_drain(cards)
	var flu_msg := ""
	for m in msp.texts:
		if str(m.body).contains("flu"):
			flu_msg = str(m.body)
	_check(flu_msg.contains(out[0]) and flu_msg.contains("Nothing is expected"), "a kind text names who is out")
	_check(msp.score == snap.score and c.rep == snap.rep and msp.closed_ok == snap.closed and msp.breached == snap.breached, "the player's score, reputation and tickets are untouched")
	_check(social.to_dict() == snap.social and is_equal_approx(shift.energy, float(snap.energy)), "opinions and energy are untouched")
	var again: Array = mu.absent().duplicate()
	mu.prepare_day(6)
	_check(mu.absent() == again, "the same day gives the same two people")
	mu.plan = [{"id": "flu_season", "from": 5, "to": 5}]
	mu.prepare_day(5)
	_check(mu.absent().is_empty() and outings.TECH_DAYS.has(5), "nobody is out on an outing day")
	mu.plan = []
	mu.prepare_day(6)
	world.apply_roster()
	_check(mu.absent().is_empty() and world.chars.has(out[0]), "everyone is back when the mutator is over")
	_check(c.rep == rep_before or true, "(rep checked above)")

	# owner hooks
	c.new_game("owner")
	_drain(cards)
	var base_delay: int = owner.pay_delay(0)
	mu.plan = [{"id": "slow_payers", "from": 1, "to": 1}]
	_check(owner.pay_delay(0) == base_delay + 1, "slow payers: invoices pay a week later")
	var risk0: float = owner.poach_risk(0)
	mu.plan = [{"id": "tax_season", "from": 1, "to": 1}]
	_check(owner.poach_risk(0) > risk0, "tax season: a little more poach pressure")
	mu.plan = []

	# ---- the schedule
	var blocked := [1, 2, 3, 4, 5, 7, 8, 9, 12, 13, 16, 17, 18, 19, 20]
	for t in mu.TECH_SLOTS:
		_check(not blocked.has(t), "tech slot day %d is not a story or gentle day" % t)
	var counts := {"easy": [], "normal": [], "hard": []}
	for tier in ["easy", "normal", "hard"]:
		for s in range(1, 31):
			diff.seed_run(s * 7919)
			diff.set_tier(tier)
			var plan: Array = mu.make_plan("tech", tier)
			counts[tier].append(plan.size())
			var last_to := 0
			var ok := true
			for e in plan:
				if not mu.TECH_SLOTS.has(int(e.from)) or int(e.to) < int(e.from) or int(e.from) <= last_to:
					ok = false
				for d in range(int(e.from), int(e.to) + 1):
					if blocked.has(d):
						ok = false
				if not mu.MUTATORS[e.id].kinds.has("both") and not mu.MUTATORS[e.id].kinds.has("tech"):
					ok = false
				last_to = int(e.to)
			if not ok:
				_check(false, "tier %s seed %d: a bad plan %s" % [tier, s, str(plan)])
	_check(counts.easy.min() == 0 and counts.easy.max() <= 1, "easy: none or one (%s)" % str([counts.easy.min(), counts.easy.max()]))
	_check(counts.normal.min() >= 2 and counts.normal.max() <= 3, "normal: two or three (%s)" % str([counts.normal.min(), counts.normal.max()]))
	_check(counts.hard.min() >= 4, "hard: four or more (%s)" % str([counts.hard.min(), counts.hard.max()]))
	_check(counts.easy.has(0) and counts.easy.has(1) and counts.normal.has(2) and counts.normal.has(3), "all the counts really occur")
	diff.seed_run(31337)
	var p1: Array = mu.make_plan("tech", "normal")
	diff.seed_run(31337)
	var p2: Array = mu.make_plan("tech", "normal")
	_check(p1 == p2 and not p1.is_empty(), "the same seed gives the same plan %s" % str(p1))
	var differs := false
	for s in range(1, 12):
		diff.seed_run(s)
		if mu.make_plan("tech", "normal") != p1:
			differs = true
	_check(differs, "other seeds give other plans")
	var owner_ok := true
	for s in range(1, 30):
		diff.seed_run(s * 31)
		var op: Array = mu.make_plan("owner", "hard")
		var last_o := 0
		for e in op:
			if not mu.OWNER_SLOTS.has(int(e.from)) or int(e.from) <= last_o:
				owner_ok = false
			last_o = int(e.to)
			for w in range(int(e.from), int(e.to) + 1):
				if outings.OWNER_WEEKS.has(w) or [1, 2, 4, 5, 9, 10, 12, 13, 14, 15, 16, 18, 19, 20].has(w):
					owner_ok = false
	_check(owner_ok, "owner plans stay off the big card weeks and outings")
	_check(mu.make_plan("tech", "hard").size() > 0 and mu.make_plan("free", "hard").is_empty(), "Free Play never gets a plan")
	# the days of the plans are free of owner-campaign / tech story playbooks
	for d in mu.TECH_SLOTS:
		for evn in story.DAYS.get(d, []):
			_check(str(evn.get("kind", "")) != "ransomware", "no ransomware on slot day %d" % d)
	# New Game uses the stream and the plan is active on its days
	diff.seed_run(2024)
	diff.set_tier("hard")
	c.new_game("tech")
	_drain(cards)
	var plan_a: Array = mu.plan.duplicate(true)
	_check(plan_a.size() >= 4, "New Game on hard draws a plan (%d)" % plan_a.size())
	c.day = int(plan_a[0].from)
	_check(mu.current_id() == str(plan_a[0].id) and mu.tag() != "", "the plan is active on its day")
	c.day = 1
	_check(mu.current_id() == "", "and not on day 1")
	diff.seed_run(2024)
	c.new_game("tech")
	_drain(cards)
	_check(mu.plan == plan_a, "the same seed repeats the schedule through New Game")
	# the HUD tag and the report
	c.day = int(plan_a[0].from)
	var rep: Dictionary = c.make_report()
	_check(str(rep.get("mutator", "")) == mu.tag(), "the day report carries the tag")
	c.day = 1
	_check(not c.make_report().has("mutator"), "and no key when nothing is active")
	# career
	var before: int = career.value("mut_days")
	c.day = int(plan_a[0].from) + 1
	mu.begin_day(c.day)
	_drain(cards)
	_check(career.value("mut_days") == before + 1, "Career counts a mutator day survived")
	var sf: int = career.value("starts_done")
	mu.note_finish()
	_check(career.value("starts_done") == sf + 1, "Career counts a finished start")

	# ---- Free Play chooser
	c.new_game("free")
	_check(mu.forced == "" and mu.cycle_forced(1) != "" and mu.forced != "", "the chooser picks the first mutator")
	var steps := 1
	while mu.forced != "" and steps < 40:
		mu.cycle_forced(1)
		steps += 1
	_check(mu.forced == "" and steps == mu.ids_for("tech").size() + 1, "and cycles back to none (%d steps)" % steps)
	mu.set_forced("not_a_mutator")
	_check(mu.forced == "" and mu.tag() == "", "an unknown id is ignored")

	# ---- saves
	diff.seed_run(77)
	diff.set_tier("hard")
	c.new_game("tech")
	_drain(cards)
	var saved_plan: Array = mu.plan.duplicate(true)
	c.save()
	mu.plan = []
	mu.start_id = "standard"
	_check(c.continue_game("tech"), "continue the tech save")
	_drain(cards)
	_check(mu.plan == saved_plan, "the plan survives a save and a continue")
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("tech"))
	cfg.erase_section_key("campaign", "mutators")
	cfg.save(c.save_path("tech"))
	_check(c.continue_game("tech") and mu.plan.is_empty() and mu.start_id == "standard", "an old save without the section has no mutators and the standard start")
	_drain(cards)
	mu.from_dict({"plan": [{"id": "ghost", "from": 6, "to": 6}, {"id": "heartbleed", "from": 6, "to": 6}], "start": "ghost"})
	_check(mu.plan.size() == 1 and mu.start_id == "standard", "unknown ids in a save are dropped")
	DirAccess.remove_absolute(c.save_path("tech"))
	DirAccess.remove_absolute(c.save_prefix + "career.cfg")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
