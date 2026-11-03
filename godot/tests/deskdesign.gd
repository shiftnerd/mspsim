extends SceneTree
# gdlint:disable=max-line-length
# C6 / V3: the desk design card (TIERED / SWARM / PODS, with or without a dispatcher): each design's assignment rules, speed and
# reopen numbers, the board lanes (Dispatch), the owners' reaction, the dispatcher's hours, the one allowed revisit and its cost,
# saving and an old save. Headless.

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


func _mk(fix: String, pri: int, client := -1) -> Dictionary:
	var msp := root.get_node("Msp")
	if msp.open_tickets().size() >= 6:
		for ot in msp.open_tickets():
			ot.status = "Closed"
	var used := []
	for ot in msp.open_tickets():
		used.append(str(ot.endpoint))
	for ep in msp.endpoints:
		if not used.has(str(ep.name)):
			ep.problem = ""
	var t: Dictionary = msp.create_ticket(client if client >= 0 else _mk_n % 5, 0, "email")
	_mk_n += 1
	t.fix = fix
	t.pri = pri
	msp.endpoint(str(t.endpoint)).problem = fix
	t.sla_total = 400.0
	t.sla_left = 400.0
	return t


func _fresh() -> void:
	var c := root.get_node("Campaign")
	c.new_game("service")
	_clear(root.get_node("Cards"))
	root.get_node("Msp").tickets.clear()
	root.get_node("World").clock = 9.5


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var computer := root.get_node("Computer")
	var difficulty := root.get_node("Difficulty")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	_fresh()

	# ---- before the choice: the C5 behaviour, unchanged
	_check(sv.design == "" and not sv.dispatcher, "no design chosen yet")
	_check(sv.lane_ids() == ["", "Maya", "Sam", "Terry", "Dan", "ESC"], "lanes before the choice: %s" % str(sv.lane_ids()))
	_check(sv.pickup_cap() == 2 and sv.design_speed("Sam", _mk("av", 3)) == 1.0 and sv.assist_rate() == sv.ASSIST, "no design: neutral numbers")
	_check(absf(sv.manager_hours_total() - 3.0) < 0.001, "you dispatch yourself: three manager hours")
	_check(sv.DAYS[3].any(func(e) -> bool: return str(e.kind) == "design"), "the design card is scripted for day 3")
	_check(sv.DAYS[6].any(func(e) -> bool: return str(e.kind) == "hire") and sv.DAYS[12].any(func(e) -> bool: return str(e.kind) == "hire"), "hiring cards on days 6 and 12")

	# ---- the card: three designs, then who dispatches
	var mails_before: int = msp.emails.size()
	var ta: int = sv.trust_of("Alan")
	var tg: int = sv.trust_of("Garrison")
	sv.fire({"at": 9.8, "kind": "design"})
	_check(cards.is_open and cards.options.size() == 3, "the design card has three options")
	_check(str(cards.options[0].label).begins_with("TIERED") and str(cards.options[1].label).begins_with("SWARM") and str(cards.options[2].label).begins_with("PODS"), "tiered, swarm, pods")
	cards.pick(0)
	_check(cards.is_open and cards.options.size() == 2 and str(cards.options[1].label).find("DISPATCHER") >= 0, "then: dispatch yourself, or hire a dispatcher")
	cards.pick(1)
	_clear(cards)
	_check(sv.design == "tiered" and sv.dispatcher, "TIERED with a dispatcher")
	_check(sv.trust_of("Alan") == ta + 4 + 2 and sv.trust_of("Garrison") == tg - 2 - 1, "Alan likes tiers and a dispatcher (+6), Garrison does not (-3)")
	_check(msp.emails.size() == mails_before + 2, "both owners mail their reaction")
	_check(absf(sv.manager_hours_total() - 5.0) < 0.001, "a dispatcher gives two manager hours back")
	_check(sv.pickup_cap() == 2, "...and picks up two tickets at a time")
	sv.fire({"at": 9.8, "kind": "design"})
	_check(not cards.is_open, "the card does not come back once decided")

	# ---- tiered: lanes and assignment rules
	_check(sv.lane_ids() == ["", "Sam", "Maya", "Terry", "Dan", "ESC"], "lanes are grouped L1 then L2: %s" % str(sv.lane_ids()))
	_check(sv.lane_tag("Sam") == "L1" and sv.lane_tag("Maya") == "L2" and sv.lane_tag("ESC") == "L3" and sv.lane_tag("Dan") == "", "lane tags L1 / L2 / L3")
	var dp = computer.dispatch
	_check(dp.lane_title("Sam", 12) == "L1 SAM" and dp.lane_title("Terry", 12) == "L2 TERRY" and dp.lane_title("ESC", 12) == "L3 OWNERS", "the board's lane heads carry the tier")
	sv.auto = "all"
	msp.tickets.clear()
	var easy := _mk("reboot", 3)  # servers 1: an L1 ticket
	var hard := _mk("av", 3)  # security 2: an L2 ticket
	_check(sv.route_for(easy) == "Sam", "an easy ticket goes to the L1 tech (%s)" % sv.route_for(easy))
	_check(sv.route_for(hard) in ["Maya", "Terry"], "a harder one to L2 (%s)" % sv.route_for(hard))
	sv._pickup()
	_check(crew.assignee_of(easy) == "Sam" and crew.assignee_of(hard) == "Terry", "the autopilot follows the lanes: Sam %s, Terry %s" % [crew.assignee_of(easy), crew.assignee_of(hard)])
	var e2 := _mk("spooler", 3)
	var e3 := _mk("clear_temp", 3)
	sv.assign(int(e2.id), "Sam", false)
	sv.assign(int(e3.id), "Sam", false)
	var hot := _mk("password", 1)
	_check(sv.route_for(hot) in ["Maya", "Terry"], "when L1 is full a hot ticket may cross into an idle L2 desk (%s)" % sv.route_for(hot))
	var cold := _mk("reboot", 4)
	_check(sv.route_for(cold) == "", "a cold one waits for its own lane instead")
	_check(sv.design_speed("Sam", easy) > sv.design_speed("Sam", hard) and sv.design_speed("Sam", hard) < 1.0, "out of lane is slower (%.2f against %.2f)" % [sv.design_speed("Sam", hard), sv.design_speed("Sam", easy)])
	_check(sv.design_reopen("Sam", easy) < 0.0 and sv.design_reopen("Sam", hard) > 0.0, "in lane reopens less, out of lane more")

	# ---- swarm: nobody owns a lane, tickets go wrong now and then, faster overall
	_fresh()
	sv.apply_design("swarm", false)
	_check(sv.design == "swarm" and not sv.dispatcher, "SWARM, you dispatch")
	_check(sv.lane_ids() == ["", "Maya", "Sam", "Terry", "Dan", "ESC"] and sv.lane_tag("Maya") == "ALL", "swarm lanes keep the crew order and say ALL")
	_check(sv.pickup_cap() == 1, "dispatching yourself picks up one ticket at a time")
	_check(sv.design_speed("Sam", _mk("av", 3)) > 1.05 and sv.design_reopen("Sam", _mk("av", 3)) > 0.0, "swarm is faster and sloppier")
	_check(sv.assist_rate() > sv.ASSIST, "...and the idle help the busy more")
	difficulty.seed_run(4321)
	var t_any := _mk("av", 3)
	var wrong := 0
	var tries := 300
	for i in tries:
		sv.misallocated = 0
		sv.route_for(t_any)
		wrong += sv.misallocated
	_check(wrong > tries / 20 and wrong < tries / 3, "about a sixth of the swarm's tickets land on the wrong desk (%d of %d)" % [wrong, tries])
	var wrong_d := 0
	sv.dispatcher = true
	for i in tries:
		sv.misallocated = 0
		sv.route_for(t_any)
		wrong_d += sv.misallocated
	_check(wrong_d < wrong, "a dispatcher halves that (%d against %d)" % [wrong_d, wrong])
	var first := ""
	difficulty.seed_run(777)
	var run_a := []
	for i in 20:
		run_a.append(sv.route_for(t_any))
	difficulty.seed_run(777)
	var run_b := []
	for i in 20:
		run_b.append(sv.route_for(t_any))
	_check(run_a == run_b and first == "", "the same seed gives the same routing")

	# ---- pods: a tech per client group, deep knowledge that builds, brittle when somebody leaves
	_fresh()
	var swarm_cost: int = sv.weekly_cost()
	sv.apply_design("pods", false)
	_check(sv.design == "pods" and sv.lane_tag("Sam") == "POD", "PODS")
	_check(sv.pods.size() == root.get_node("Sales").active.size() and sv.pods.size() > 0, "every client you serve belongs to a pod (%d)" % sv.pods.size())
	var covered := {}
	for cl in sv.pods:
		covered[sv.pods[cl]] = true
	_check(covered.size() >= 2 and covered.size() <= 3, "the clients are spread over the techs (%s)" % str(covered.keys()))
	var cl0: int = sv.pods.keys()[0]
	var owner_name: String = sv.pods[cl0]
	var pt := _mk("reboot", 3, cl0)
	_check(sv.route_for(pt) == owner_name, "a pod ticket goes to the pod owner (%s)" % owner_name)
	_check(sv.weekly_cost() == swarm_cost + sv.POD_STIPEND * crew.size(), "pod leads cost more every week (+$%d each)" % sv.POD_STIPEND)
	sv.pod_days[cl0] = 0
	var s0: float = sv.design_speed(owner_name, pt)
	sv.pod_days[cl0] = 2
	var s2: float = sv.design_speed(owner_name, pt)
	sv.pod_days[cl0] = 10
	var s10: float = sv.design_speed(owner_name, pt)
	_check(s0 >= 1.0 and s2 > s0 and s10 > s2 and s10 <= 1.121, "deep client knowledge builds day by day (%.2f, %.2f, %.2f)" % [s0, s2, s10])
	var stranger: String = "Sam" if owner_name != "Sam" else "Maya"
	_check(sv.design_speed(stranger, pt) < 1.0, "somebody outside the pod is a little slower")
	sv.begin_day(4)
	_clear(cards)
	_check(int(sv.pod_days[cl0]) == 11, "the knowledge grows each morning")
	var terry_pod: Array = sv.pod_of("Terry")
	crew.quit("Terry")
	var left_out := true
	for cl in sv.pods:
		left_out = left_out and sv.pods[cl] != "Terry"
	_check(left_out and sv.pods.size() == root.get_node("Sales").active.size(), "when a pod tech quits his clients are given to the others")
	if not terry_pod.is_empty():
		_check(int(sv.pod_days[terry_pod[0]]) == 0, "...and their deep knowledge starts again")
	sv.pods[cl0] = "Maya"
	msp.tickets.clear()
	var busy_t := _mk("reboot", 3, cl0)
	sv.assign(int(_mk("spooler", 3).id), "Maya", false)
	sv.assign(int(_mk("spooler", 3).id), "Maya", false)
	sv.assign(int(_mk("spooler", 3).id), "Maya", false)
	_check(sv.route_for(busy_t) == "", "a pod owner with three tickets does not take a fourth: it waits, nobody covers him")
	_check(sv.assist_rate() < sv.ASSIST, "pods help each other less")

	# ---- the dispatcher is a separate choice
	_fresh()
	sv.apply_design("tiered", false)
	_check(not sv.dispatcher and sv.pickup_cap() == 1 and absf(sv.manager_hours_total() - 3.0) < 0.001, "tiered without a dispatcher: slower pick-up, three hours")
	var no_disp: float = sv.design_speed("Sam", _mk("reboot", 3))
	sv.dispatcher = true
	_check(sv.design_speed("Sam", _mk("reboot", 3)) > no_disp, "tiered with a dispatcher is faster (the Knowledge Base's maturity point)")
	_check(sv.weekly_cost() > crew.payroll_week() and sv.cost_per_ticket() >= -1, "the dispatcher is on the payroll ($%d a week)" % sv.weekly_cost())

	# ---- revisit once, with a cost
	_fresh()
	sv.apply_design("tiered", false)
	var tra: int = sv.trust_of("Alan")
	var trg: int = sv.trust_of("Garrison")
	var mor: int = crew.morale_avg()
	_check(sv.can_change_design(), "the design can be changed once")
	var res: Dictionary = sv.apply_design("pods", false, true)
	_check(res.ok and sv.design == "pods" and sv.design_changes == 1, "changed to pods")
	_check(absf(sv.kb.hours_used - 2.0) < 0.001, "it cost two manager hours")
	_check(sv.trust_of("Alan") <= tra - 1 - 1 and sv.trust_of("Garrison") >= trg - 1 + 3, "both owners lost a point for the flip, Garrison likes the pods")
	_check(crew.morale_avg() <= mor - 2, "the crew is confused for a while (morale %d to %d)" % [mor, crew.morale_avg()])
	_check(not sv.can_change_design(), "no second change")
	res = sv.apply_design("swarm", false, true)
	_check(not res.ok and sv.design == "pods", "a second revisit is refused")
	_fresh()
	sv.apply_design("tiered", false)
	sv.kb.hours_used = 2.5
	_check(not sv.can_change_design(), "not enough hours left to change it")
	sv.kb.hours_used = 0.0
	sv.design_card(true)
	_check(cards.is_open and cards.options.size() == 4 and not bool(cards.options[0].get("enabled", true)), "the revisit card greys out the current design and adds KEEP")
	cards.pick(3)
	_check(sv.design == "tiered" and sv.design_changes == 0, "KEEP changes nothing")
	_clear(cards)

	# ---- save and old saves
	_fresh()
	sv.apply_design("pods", true)
	sv.training = "light"
	var data: Dictionary = sv.to_dict()
	sv.reset()
	_check(sv.design == "" and sv.pods.is_empty(), "reset clears the design")
	sv.from_dict(data)
	_check(sv.design == "pods" and sv.dispatcher and not sv.pods.is_empty() and sv.training == "light", "the design, dispatcher, pods and training budget survive a save")
	sv.from_dict({"trust": {"Alan": 50, "Garrison": 50}, "focus": "p1", "crew": {"members": {"Maya": {"skill": 1.0, "morale": 70}}}})
	_check(sv.design == "" and not sv.dispatcher and sv.pods.is_empty() and crew.morale("Maya") == 70 and crew.value("Sam", "wage") == 450, "an old save loads with defaults (and the roster's wages)")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
