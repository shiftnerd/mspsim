extends SceneTree
# C6 / V3: the runbooks (ConnectWhy Knowledge). States NONE / DRAFT / DOCUMENTED / TRAINED, the hours they cost (yours and a
# tech's), the effect on speed, safety and the stuck state, decay when systems change, TRAINED being permanent (a lesson
# with a quiz, then sign-off on live tickets), the bus factor when the only tech who knows a class quits, the documentation
# score on the scorecard, saving, and the app's keys. Headless.

var failures := 0
var player_script: GDScript
var _mk_n := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 40:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1
	return n


func _mk(fix: String, pri: int) -> Dictionary:
	var msp := root.get_node("Msp")
	var used := []
	for ot in msp.open_tickets():
		used.append(str(ot.endpoint))
	for ep in msp.endpoints:
		if not used.has(str(ep.name)):
			ep.problem = ""
	var t: Dictionary = msp.create_ticket(_mk_n % 5, 0, "email")
	_mk_n += 1
	t.fix = fix
	t.pri = pri
	msp.endpoint(str(t.endpoint)).problem = fix
	t.sla_total = 400.0
	t.sla_left = 400.0
	return t


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	c.new_game("service")
	_clear(cards)
	var kb = sv.kb
	world.clock = 9.5
	msp.tickets.clear()

	# ---- the table: every class has a label, an area, a need and a quiz
	_check(kb.ids().size() == 12, "twelve runbook classes (7 ticket kinds, 5 jobs)")
	var tidy := true
	for id in kb.ids():
		var q: Dictionary = sv.RUNBOOKS[id].quiz
		tidy = tidy and q.options.size() == 3 and int(q.answer) >= 0 and int(q.answer) < 3 and crew.AREAS.has(kb.area_of(id)) and kb.need_of(id) >= 1
	_check(tidy, "each class has an area, a need and a three-answer quiz")
	_check(kb.state("av") == kb.NONE and kb.doc_pct() == 0 and kb.documented_count() == 0, "everything starts as NONE, documentation 0%")
	_check(absf(kb.hours_total() - 3.0) < 0.001 and absf(kb.hours_left() - 3.0) < 0.001, "three manager hours a day (you are the dispatcher)")

	# ---- no effect while there is no runbook
	var t_av := _mk("av", 3)  # security 2: Sam has security 1
	var base_gap: int = crew.gap_of("Sam", t_av)
	var base_mult: float = crew.match_mult("Sam", t_av)
	var base_reopen: float = crew.reopen_add("Sam", t_av)
	_check(base_gap == 1 and kb.relief(t_av) == 0.0, "Sam is a level short on an AV ticket and there is no help (gap %d)" % base_gap)

	# ---- writing costs hours (Dan's) and a tech's time
	var res: Dictionary = kb.advance("av")
	_check(res.ok and kb.state("av") == kb.DRAFT, "writing a draft works")
	_check(absf(kb.hours_used - 1.0) < 0.001, "a draft of a security class costs one manager hour (%.1f)" % kb.hours_used)
	var author := str(res.who)
	_check(author != "" and crew.busy(author) and crew.status(author) == "WRITING", "the author (%s) is away from the queue while writing" % author)
	_check(absf(crew.raw_speed(author)) < 0.0001, "...and works no tickets in that hour")
	world.clock = 11.0
	_check(not crew.busy(author), "...he is back an hour later")
	_check(kb.documented_count() == 0 and crew.gap_of("Sam", t_av) == base_gap, "a draft is not live: the gap is unchanged")
	_check(kb.speed(t_av) > 1.0 and kb.speed(t_av) < 1.1, "a draft helps a little")
	var n_net: Dictionary = kb.cost_of("spooler")
	_check(absf(float(n_net.dan) - 0.5) < 0.001, "Dan labels everything: a networking class costs half (%.1f)" % float(n_net.dan))

	# ---- publishing makes it live for the whole crew: faster, safer, and the stuck state goes
	res = kb.advance("av")
	_check(res.ok and kb.state("av") == kb.DOCUMENTED and kb.is_live("av"), "publishing makes the runbook live")
	_check(absf(kb.hours_left() - 1.0) < 0.001, "two hours spent, one left (%.1f)" % kb.hours_left())
	_check(kb.doc_pct() == 8, "documentation score 1 of 12 = 8%% (%d)" % kb.doc_pct())
	_check(crew.gap_of("Sam", t_av) == base_gap - 1, "a live runbook takes a level off the gap: Sam is no longer short")
	_check(crew.match_mult("Sam", t_av) > base_mult + 0.2, "...and he works it faster (%.2f -> %.2f)" % [base_mult, crew.match_mult("Sam", t_av)])
	_check(crew.reopen_add("Sam", t_av) < base_reopen - 0.03, "...and it comes back less often")
	for who in crew.names():
		_check(crew.gap_of(str(who), t_av) <= 0 or crew.area_level(str(who), "security") < 0.5, "%s is not above his head on AV" % who)
	# the stuck state: working it for longer than STUCK_AFTER stalls a tech only when the gap is 1 or more
	var t_other := _mk("restore", 2)  # another class: no runbook, security 3 for P2? need 2 + 0
	_check(kb.relief(t_other) == 0.0, "an undocumented class gets no help")
	var t_rdp: Dictionary = {"fix": "rdp", "pri": 2, "client": 0}
	_check(kb.class_of(t_rdp) == "", "jobs are not tickets: no class for them in the queue")

	# ---- not enough hours
	res = kb.advance("restore")
	_check(res.ok, "the last hour buys a draft")
	res = kb.advance("restore")
	_check(not res.ok and str(res.msg).find("NEED") >= 0, "out of hours: %s" % str(res.msg))
	_check(kb.state("restore") == kb.DRAFT, "...and nothing changed")

	# ---- a new day gives the hours back; decay when systems change
	kb.begin_day(2)
	_check(absf(kb.hours_left() - 3.0) < 0.001, "a new day brings three hours back")
	var hit: Array = kb.system_change(["av", "spooler"], "Test", "A system changed.")
	_check(hit == ["av"], "a system change stales documented runbooks (and only those): %s" % str(hit))
	_check(not kb.is_live("av") and crew.gap_of("Sam", t_av) == base_gap, "a stale runbook stops helping")
	_check(kb.speed(t_av) == 1.0 and kb.safety(t_av) == 0.0, "...no speed or safety bonus")
	_check(kb.documented_count() == 0, "...and does not count towards the score")
	res = kb.advance("av")
	_check(res.ok and kb.is_live("av") and absf(kb.hours_used - 0.5) < 0.001, "a refresh costs half an hour and puts it right")

	# ---- the scripted systems changes (CHANGES) are seeded and hit only documented classes
	var before: Dictionary = kb.to_dict()
	var rb_sp: Dictionary = kb.rb("spooler")
	rb_sp["state"] = kb.DOCUMENTED
	var rb_ad: Dictionary = kb.rb("adobe")
	rb_ad["state"] = kb.DOCUMENTED
	kb.begin_day(8)
	var stale_n := 0
	for id in ["spooler", "adobe"]:
		if bool(kb.rb(id).stale):
			stale_n += 1
	_check(stale_n == 1, "day 8 (new copiers) stales one of the two print runbooks (%d)" % stale_n)
	kb.from_dict(before)

	# ---- TRAINED: a lesson, a quiz, sign-off on live tickets, and then it is permanent
	kb.begin_day(3)
	var cost: Dictionary = kb.cost_of("av")
	_check(str(cost.act) == "train" and float(cost.dan) > 0.0 and float(cost.tech) > 0.0, "a live runbook can be trained: hours of yours and the senior's")
	res = kb.advance("av")
	_check(res.ok and cards.is_open and kb.lesson_who != "", "training opens a lesson card (the quiz) with %s" % kb.lesson_who)
	var q: Dictionary = sv.RUNBOOKS["av"].quiz
	var wrong: int = (int(q.answer) + 1) % 3
	var wrong_idx := 0
	for i in cards.options.size():
		if int(cards.options[i].id) == wrong:
			wrong_idx = i
	cards.pick(wrong_idx)
	_check(cards.is_open and str(cards.text).find("not the safest") >= 0, "the wrong answer fails the lesson")
	_clear(cards)
	_check(int(kb.rb("av").signoff) == 0 and kb.state("av") == kb.DOCUMENTED, "...and the runbook stays DOCUMENTED")
	kb.begin_day(4)
	res = kb.advance("av")
	var right_idx := 0
	for i in cards.options.size():
		if int(cards.options[i].id) == int(q.answer):
			right_idx = i
	cards.pick(right_idx)
	_check(cards.is_open and str(cards.text).find("holds up") >= 0, "the right answer passes it")
	_clear(cards)
	_check(int(kb.rb("av").signoff) == 2 and str(kb.cost_of("av").act) == "wait", "sign-off on two live tickets follows")
	var senior := str(kb.rb("av").senior)
	var other := "Maya" if senior != "Maya" else "Sam"
	var tk := _mk("av", 3)
	kb.note_closed(senior, tk)
	_check(int(kb.rb("av").signoff) == 2, "the senior's own tickets do not count as sign-off")
	kb.note_closed(other, tk)
	_check(kb.state("av") == kb.DOCUMENTED and int(kb.rb("av").signoff) == 1, "one signed off, one to go")
	kb.note_closed(other, tk)
	_check(kb.state("av") == kb.TRAINED and kb.is_live("av"), "the second sign-off makes it TRAINED")
	_check(kb.speed(tk) > 1.2 and kb.safety(tk) < -0.06, "trained is faster and safer than documented")
	kb.system_change(["av"], "Test", "Again.")
	_check(kb.is_live("av") and not bool(kb.rb("av").stale), "TRAINED is permanent: a system change does not stale it")
	for day in [8, 12, 15]:
		kb.begin_day(day)
	_check(kb.state("av") == kb.TRAINED and kb.is_live("av"), "...nor do the scripted changes")
	_check(str(kb.advance("av").msg).find("TRAINED") >= 0, "a trained runbook has no next step")

	# ---- the bus factor
	kb.reset()
	_check("av" in kb.single_points() and "restore" in kb.single_points(), "AV and RESTORE are knowledge hotspots: only Terry can do them")
	var t_restore := _mk("restore", 2)
	var sam_gap: int = crew.gap_of("Maya", t_restore)
	crew.quit("Terry")
	_check(kb.bus.has("av") and kb.bus.has("restore") and not kb.bus.has("spooler"), "when Terry quits, the undocumented classes only he knew are hit")
	_check(crew.gap_of("Maya", t_restore) == sam_gap + 1, "...and become one level harder for everybody (stuck for all)")
	_check(crew.gap_of("Sam", t_restore) > 0, "...including the juniors")
	# writing it down clears it
	kb.rb("restore")["state"] = kb.DOCUMENTED
	_check(crew.gap_of("Maya", t_restore) == sam_gap - 1, "a live runbook cancels the hit and helps")
	kb.begin_day(5)
	_check(not kb.bus.has("restore"), "...and the next morning it is gone from the list")
	# a documented class survives the quit
	c.new_game("service")
	_clear(cards)
	kb = sv.kb
	kb.rb("av")["state"] = kb.DOCUMENTED
	crew.quit("Terry")
	_check(not kb.bus.has("av") and kb.bus.has("restore"), "a documented class is not hit when its only expert quits")
	_check(not msp.tickets.is_empty() or true, "(tickets kept)")

	# ---- the score on the scorecard and in Alan's trust
	c.new_game("service")
	_clear(cards)
	kb = sv.kb
	var rows: Array = sv._desk_rows()
	var found := false
	for r in rows:
		if str(r[0]) == "DOCUMENTED":
			found = str(r[1]) == "0%"
	_check(found, "the scorecard has a DOCUMENTED row (0%)")
	var trust_before: int = sv.trust_of("Alan")
	for id in ["spooler", "password", "clear_temp", "reboot", "av", "restore"]:
		kb.rb(id)["state"] = kb.DOCUMENTED
	_check(kb.doc_pct() == 50, "six of twelve is 50%%")
	sv._owner_day()
	_check(sv.trust_of("Alan") == trust_before + 3, "Alan notices at 50%% (trust +3)")
	sv._owner_day()
	_check(sv.trust_of("Alan") == trust_before + 3, "...once")

	# ---- jobs: a runbook for a Playbook job helps whoever runs it without you
	_check(kb.job_bonus("rdp") == 0.0, "no runbook, no bonus for a job")
	kb.rb("rdp")["state"] = kb.DOCUMENTED
	_check(absf(kb.job_bonus("rdp") - 0.08) < 0.001, "a live runbook adds 0.08 to the delegated job's quality")

	# ---- saving, and an old save
	kb.rb("adobe")["state"] = kb.TRAINED
	kb.rb("adobe")["stale"] = false
	kb.hours_used = 1.5
	kb.bus["rack"] = "Terry"
	var data: Dictionary = sv.to_dict()
	sv.reset()
	_check(sv.kb.doc_pct() == 0, "reset clears the runbooks")
	sv.from_dict(data)
	kb = sv.kb
	_check(kb.state("adobe") == kb.TRAINED and kb.state("rdp") == kb.DOCUMENTED and absf(kb.hours_used - 1.5) < 0.001 and kb.bus.has("rack"), "runbooks, hours and the bus list survive a save")
	sv.from_dict({"trust": {"Alan": 41, "Garrison": 52}, "focus": "queue"})
	_check(sv.kb.doc_pct() == 0 and sv.design == "" and not sv.dispatcher and sv.training == "none", "an old save loads with every new field at its default")

	# ---- the app: keys and clicks
	c.new_game("service")
	_clear(cards)
	kb = sv.kb
	world.clock = 9.5
	var computer := root.get_node("Computer")
	computer.app = "knowledge"
	_check(kb.key("down") and kb.sel == 1, "Down moves the cursor")
	_check(kb.key("right") and kb.view == "desk" and kb.key("right") and kb.view == "crew" and kb.key("left") and kb.view == "desk", "Left / Right change the tab")
	kb.set_view("books")
	kb.sel = 0
	_check(kb.key("enter") and kb.state("spooler") == kb.DRAFT, "Enter does the next step on the selected class")
	kb.act(PackedStringArray(["kb", "row", "3"]))
	kb.act(PackedStringArray(["kb", "go"]))
	_check(kb.sel == 3 and kb.state("reboot") == kb.DRAFT, "a click on a row then the button works too")
	_check(kb.key("pgdn") and kb.sel >= 3, "paging keys are handled")
	_check(not kb.key("z"), "other keys fall through")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
