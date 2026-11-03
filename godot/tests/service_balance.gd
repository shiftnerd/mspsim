extends SceneTree
# gdlint:disable=class-definitions-order,expression-not-assigned,max-line-length,max-returns
# Dev tool (not a test): plays the service manager campaign for twenty days with one fixed strategy, several seeds, in compressed time.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/service_balance.gd -- careful|lazy|chaotic [seeds=5] [ts=15] [first=1]
# careful: assigns by fit (rescues stuck techs), documents every day, interviews and hires for fit, one on ones, brokers the owners.
# lazy:    the autopilot only: takes the first answer of every card, writes nothing down, never touches the board.
# chaotic: a swarm desk with no documentation, random answers, tickets moved around at random, no one on ones.
# Prints one line per run (scorecard numbers, trust, the audit, the endings on offer) and the averages.

var strategy := "careful"
var seeds := 5
var first_seed := 1
var ts := 15.0
var rng := RandomNumberGenerator.new()
var results: Array = []
var _last_day := 0
var _ticks := 0
var _jobs := 0
var _talk_i := 0

const KB_ORDER := ["password", "spooler", "reboot", "clear_temp", "av", "restore", "adobe", "rdp", "ransom", "rack", "email24", "migration"]


func _args() -> void:
	var rest: Array = OS.get_cmdline_user_args()
	for a in rest:
		var s := str(a)
		if s in ["careful", "lazy", "chaotic"]:
			strategy = s
		elif s.begins_with("seeds="):
			seeds = int(s.substr(6))
		elif s.begins_with("ts="):
			ts = float(s.substr(3))
		elif s.begins_with("first="):
			first_seed = int(s.substr(6))


func _init() -> void:
	_args()
	await process_frame
	for k in seeds:
		await _run(first_seed + k)
	_summary()
	quit(0)


func _enabled(cards: Node) -> Array:
	var out := []
	for i in cards.options.size():
		if bool(cards.options[i].get("enabled", true)):
			out.append(i)
	return out


func _idx_of(cards: Node, id: String) -> int:
	for i in cards.options.size():
		if str(cards.options[i].id) == id and bool(cards.options[i].get("enabled", true)):
			return i
	return -1


# ---- what each strategy answers --------------------------------------------------------------------------------
func _answer(cards: Node) -> int:
	var en := _enabled(cards)
	if en.is_empty():
		return 0
	var ids := []
	for o in cards.options:
		ids.append(str(o.id))
	var text := str(cards.text)
	if strategy == "lazy":
		return int(en[0])
	if strategy == "chaotic":
		if ids.has("tiered") and ids.has("swarm"):
			return _idx_of(cards, "swarm")
		return int(en[rng.randi() % en.size()])
	# careful
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var day: int = root.get_node("Campaign").day
	if ids.has("p1") and ids.has("queue") and ids.has("mentor"):
		return _idx_of(cards, "mentor") if (day % 4 == 2 and crew.morale_avg() >= 50) else _idx_of(cards, "p1")
	if ids.has("tiered"):
		return _idx_of(cards, "tiered")
	if ids.has("decide"):
		var done: int = sv.interviewed.size()
		if done < 2:
			for i in en:
				if str(cards.options[i].id).begins_with("i"):
					return int(i)
		return _idx_of(cards, "decide")
	if ids.has("h0"):
		var best := 0
		var best_v := -1.0
		for i in sv.cands.size():
			var f: Dictionary = sv.cands[i].fit
			var v := float(f.culture) + float(f.comm) + float(f.curiosity) + 2.0 * float(sv.cands[i].skill)
			if v > best_v:
				best_v = v
				best = i
		return _idx_of(cards, "h%d" % best)
	if ids.has("structured"):
		var s := _idx_of(cards, "structured")
		return s if s >= 0 else _idx_of(cards, "shadow")
	if ids.has("take") and ids.has("send") and ids.has("ask"):
		if text.contains("ransom") or text.contains("Ransom"):
			return _idx_of(cards, "ask")
		return _idx_of(cards, "take")
	for pref in ["broker", "small", "doc", "train", "par", "none", "both", "tier", "n", "pull", "40", "l", "m", "t", "home", "cover"]:
		if ids.has(pref) and not (pref == "m" and ids.has("p")):
			var j := _idx_of(cards, pref)
			if j >= 0:
				return j
	if ids.has("a") and ids.has("b") and ids.has("c"):  # an owner memo: do both while the crew is rested, else the sender's ask
		return _idx_of(cards, "c") if crew.morale_avg() >= 55 else _idx_of(cards, "a")
	if ids.has("q") and ids.has("s") and ids.has("b"):
		return _idx_of(cards, "q")
	if ids.has("d") and ids.has("n") and ids.has("m"):
		return _idx_of(cards, "n")
	return int(en[0])


# a taken Playbook job: the best choice of every step (the careful manager does the work properly)
func _do_job() -> void:
	var pb := root.get_node("Playbook")
	var guard := 0
	while pb.is_active() and guard < 12:
		guard += 1
		var choices: Array = pb.current_step().choices
		var best := -1
		for i in choices.size():
			if pb.lock_reason(choices[i]) == "":
				if best < 0 or int(choices[i].pts) > int(choices[best].pts):
					best = i
		if best < 0:
			break
		pb.choose(best)
	root.get_node("ServiceArc").job_done_check()


func _morning() -> void:
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var c := root.get_node("Campaign")
	if OS.has_environment("SB_DEBUG"):
		print("  day %d conf %d trust %d/%d morale %d doc %d%% mood %d" % [c.day, c.rep, sv.trust_of("Alan"), sv.trust_of("Garrison"), crew.morale_avg(), sv.kb.doc_pct(), int(root.get_node("Sales").average())])
	if strategy == "careful":
		# the runbooks: the cheapest next step of the first class that is not live
		var guard := 0
		while sv.kb.hours_left() >= 0.5 and guard < 12:
			guard += 1
			var did := false
			for id in KB_ORDER:
				var cost: Dictionary = sv.kb.cost_of(id)
				if str(cost.act) in ["none", "wait", "train"]:
					if str(cost.act) == "train" and sv.kb.hours_left() >= float(cost.dan) and guard < 12 and c.day >= 8:
						pass
					else:
						continue
				if float(cost.dan) <= sv.kb.hours_left() + 0.001:
					var res: Dictionary = sv.kb.advance(str(id))
					if bool(res.get("ok", false)):
						did = true
						break
			if not did:
				break
		# one on ones: two people a day, in turn, and the quiet ones first
		var who := ["Maya", "Vic"]
		for n in crew.names():
			if n != "Maya":
				who.append(str(n))
		for k in 2:
			sv.one_on_one(str(who[_talk_i % who.size()]))
			_talk_i += 1
		_drain_cards()
		if c.day == 4 and sv.training == "none":
			sv.training = "light"


func _drain_cards() -> void:
	var cards := root.get_node("Cards")
	var n := 0
	while cards.is_open and n < 60:
		n += 1
		cards.pick(_answer(cards))
	if strategy == "careful" and root.get_node("Playbook").is_active():
		_do_job()
		_drain_cards_tail()


func _drain_cards_tail() -> void:
	var cards := root.get_node("Cards")
	var n := 0
	while cards.is_open and n < 20:
		n += 1
		cards.pick(_answer(cards))


func _board_tick() -> void:
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var msp := root.get_node("Msp")
	_ticks += 1
	if strategy == "careful":
		for who in crew.stuck.keys():
			var st: Dictionary = crew.stuck[who]
			var t: Dictionary = msp.ticket(int(st.ticket))
			if t.is_empty():
				continue
			var better: String = crew.best_for(t, 2)
			if better != "" and better != who:
				sv.assign(int(t.id), better, true)
			else:
				sv.assign(int(t.id), "Dan", true)
		# your own hands: close the tickets on your lane, one every few seconds
		if _ticks % 6 == 0:
			for t in msp.open_tickets():
				if crew.assignee_of(t) == "Dan" and str(t.special) == "":
					t["fix_done"] = true
					msp.close_ticket(int(t.id))
					break
	elif strategy == "chaotic" and _ticks % 4 == 0:
		var open: Array = msp.open_tickets()
		if not open.is_empty():
			var t: Dictionary = open[rng.randi() % open.size()]
			if str(t.special) == "":
				var lanes: Array = crew.names() + ["Dan", "ESC", ""]
				sv.assign(int(t.id), str(lanes[rng.randi() % lanes.size()]), true)


# ---- one run -----------------------------------------------------------------------------------------------------
func _run(seed_n: int) -> void:
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var arc := root.get_node("ServiceArc")
	var sales := root.get_node("Sales")
	load("res://scripts/player.gd").current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	c.save_prefix = "user://bal_%d_" % OS.get_process_id()
	rng.seed = seed_n * 7919
	root.get_node("Difficulty").seed_run(seed_n)
	c.new_game("service")
	_last_day = 0
	_ticks = 0
	_talk_i = 0
	var frames := 0
	var ended := false
	var fired := false
	var row := {}
	while frames < 400000 and not ended:
		frames += 1
		await process_frame
		if report.is_open:
			var r: Dictionary = report.report
			if bool(r.get("final", false)):
				fired = bool(r.get("fired", false))
				row = _snapshot(seed_n, fired)
				report.finish()
				await process_frame
				if not fired:
					await create_timer(0.3).timeout
					review.page = 2
					var pick := _ending_index(review)
					row["offers"] = _offer_ids(review)
					row["ending"] = str(review.offers[pick].id) if not review.offers.is_empty() else "?"
					review.choose(pick)
					review.is_open = false  # (finish() would send the game back to the title screen)
					review._canvas.visible = false
					root.get_node("Game").ui_open = false
				else:
					row["offers"] = []
					row["ending"] = "FIRED"
				ended = true
				break
			report.finish()
			await create_timer(0.7).timeout
			root.get_node("Game").busy = false
			continue
		if cards.is_open:
			_drain_cards()
			continue
		if c.day != _last_day:
			_last_day = c.day
			_morning()
			continue
		world.time_scale = ts
		if frames % 10 == 0:
			_board_tick()
	if not ended:
		row = _snapshot(seed_n, false)
		row["ending"] = "TIMEOUT"
		row["offers"] = []
	results.append(row)
	print(_line(row))
	await process_frame
	cards.flush() if cards.has_method("flush") else null


func _offer_ids(review: Node) -> Array:
	var out := []
	for o in review.offers:
		out.append(str(o.id))
	return out


func _ending_index(review: Node) -> int:
	var arc := root.get_node("ServiceArc")
	var prio := ["ops", "alan", "garrison", "rollup_yes", "leave", "stay"]
	for p in prio:
		if p == "rollup_yes" and int(arc.audit_score().tier) < 2:
			continue  # a low-ball offer is not an ending anyone is proud of
		for i in review.offers.size():
			if str(review.offers[i].id) == p:
				return i
	return review.offers.size() - 1


func _snapshot(seed_n: int, fired: bool) -> Dictionary:
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var arc := root.get_node("ServiceArc")
	var msp := root.get_node("Msp")
	var count := {"S": 0, "A": 0, "B": 0, "C": 0, "D": 0}
	for g in sv.grades:
		count[str(g.grade)] = int(count[str(g.grade)]) + 1
	var a: Dictionary = arc.audit_score()
	return {
		"seed": seed_n, "day": c.day, "conf": c.rep, "ta": sv.trust_of("Alan"), "tg": sv.trust_of("Garrison"), "crew": crew.size(), "quits": crew.quits.size(),
		"morale": crew.morale_avg(), "doc": sv.kb.doc_pct(), "ret": crew.retention_pct(), "sla": arc._sla_pct(), "closed": msp.closed_ok, "missed": msp.breached,
		"reopened": msp.reopened, "audit": int(a.total), "tier": int(a.tier), "grades": count, "fired": fired, "sides": arc.sides.duplicate(), "credits": arc.credits,
		"wave": arc.wave_pct(), "design": sv.design, "pages": arc.oncall.nights, "fair": snappedf(arc.fairness(), 0.01),
	}


func _line(r: Dictionary) -> String:
	var g: Dictionary = r.grades
	return "RUN %s seed %d: day %d CONF %d  TRUST A %d G %d  CREW %d (quit %d) MORALE %d  DOC %d%% RET %d%% SLA %d%% (closed %d missed %d reopen %d)  AUDIT %d tier %d  GRADES S%d A%d B%d C%d D%d  WAVE %d%%  SIDES %s  ENDING %s OFFERS %s" % [
		strategy, int(r.seed), int(r.day), int(r.conf), int(r.ta), int(r.tg), int(r.crew), int(r.quits), int(r.morale), int(r.doc), int(r.ret), int(r.sla), int(r.closed), int(r.missed), int(r.reopened),
		int(r.audit), int(r.tier), int(g.S), int(g.A), int(g.B), int(g.C), int(g.D), int(r.wave), str(r.sides), str(r.get("ending", "?")), str(r.get("offers", [])),
	]


func _summary() -> void:
	var keys := ["conf", "ta", "tg", "crew", "morale", "doc", "ret", "sla", "audit"]
	var avg := {}
	for k in keys:
		var t := 0.0
		for r in results:
			t += float(r[k])
		avg[k] = snappedf(t / float(maxi(1, results.size())), 0.1)
	var endings := {}
	for r in results:
		endings[str(r.ending)] = int(endings.get(str(r.ending), 0)) + 1
	print("SUMMARY %s (%d runs): %s  ENDINGS %s" % [strategy, results.size(), str(avg), str(endings)])
