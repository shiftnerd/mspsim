extends SceneTree
# Owner campaign, research batch: profitability, burnout, vendor breach, the client who said no,
# billing leakage, the sales handover, peer goals and the maturity badge.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- scope creep and client profitability
	c.new_game("owner")
	_check(
		o.client_weight(2) == 2.0 and o.client_weight(0) == 1.0,
		"Gnarly Gnomes' requests creep: twice the weight"
	)
	var picks := 0
	for i in 3000:
		picks += 1 if sales.pick_client() == 2 else 0
	_check(picks > 800, "heavy clients generate more tickets (%d of 3000)" % picks)
	o.client_work[2] = 400.0
	o.client_work[0] = 60.0
	_check(
		o.client_profit(2) < 0 and o.client_profit(0) > 500,
		"400 tech-seconds cost more than the fee; a quiet client is very profitable"
	)
	o.settle()
	o.client_work[2] = 400.0
	o.settle()
	o._profit_review()
	_check(
		cards.is_open and cards.text.contains("LOSE") and cards.options.size() == 4,
		"the profit review flags the losing client: " + cards.text
	)
	var rep0: int = c.rep
	cards.pick(3)  # OTHER: let them go
	cards.pick(1)  # fire them now
	_clear(cards)
	_check(
		not sales.active.has(2) and c.rep <= rep0 - 1,
		"firing the client removes them and costs a little reputation"
	)
	c.new_game("owner")
	o.apply({"scope": 2})
	_check(o.client_weight(2) == 1.0, "enforcing the scope stops the creep")

	# ---- burnout and the after-hours fee
	c.new_game("owner")
	for i in 9:
		msp.create_ticket(i % 5, 0, "test")
	var speed0: float = o.team_speed()
	for i in 5:
		o._burnout_week()
		if cards.is_open:
			break
	_check(
		o.burnout >= 50.0 and cards.is_open and cards.text.contains("fried"),
		"a long queue burns the crew out (%d%%)" % int(o.burnout)
	)
	_check(o.team_speed() < speed0, "burnout slows the team")
	cards.pick(1)
	_check(
		cards.is_open and cards.speaker.begins_with("Alan") and cards.text.contains("After-hours"),
		"Alan raises the after-hours question"
	)
	var mult0: float = o.issue_mult()
	cards.pick(0)
	_clear(cards)
	_check(
		o.flags.after_hours_fee and absf(o.issue_mult() - mult0 * 0.92) < 0.001,
		"the after-hours fee cuts ticket volume 8%%"
	)
	var burn0: float = o.burnout
	o.burnout = 80.0
	var lost0: int = o.lost_techs
	for i in 40:
		o._burnout_week()
	_check(o.lost_techs > lost0, "pushed to the edge, a tech quits")

	# ---- vendor breach: the RMM you chose is the risk
	c.new_game("owner")
	_check(o.security_risk() == 1.0, "the standard RMM: normal risk")
	o.apply({"stack": {"rmm": "snoutech"}})
	_check(o.security_risk() == 1.5, "the cheap RMM is riskier")
	o.fire({"event": "vendor_breach"})
	_check(
		cards.is_open and cards.options.size() == 3 and cards.text.contains("SnoutTech"),
		"the vendor breach card names your RMM"
	)
	var cash0: int = o.cash
	cards.pick(0)
	_clear(cards)
	_check(o.cash == cash0 - 600, "notifying clients and rotating credentials costs $600")

	# ---- the client who said no
	c.new_game("owner")
	o._client_no()
	var who: int = o.risk_client
	_check(
		who >= 0 and cards.is_open and cards.options.size() == 3,
		"a client refuses two-factor login"
	)
	cards.pick(0)
	_clear(cards)
	_check(o.risk_choice == "waiver", "you got a signed risk-acceptance waiver")
	cash0 = o.cash
	o._client_breach()
	_check(
		o.cash == cash0 - 500 and cards.is_open and cards.text.contains("waiver"),
		"later they are breached: the waiver is what protects you"
	)
	_clear(cards)
	o.risk_client = 0
	o.risk_choice = "insisted"
	rep0 = c.rep
	o._client_breach()
	_check(
		c.rep == rep0 + 1 and cards.text.contains("two-factor"),
		"if you insisted, two-factor login stops the attack"
	)
	_clear(cards)
	o.risk_client = 1
	o.risk_choice = "ignored"
	cash0 = o.cash
	o._client_breach()
	_check(o.cash <= cash0 - 1200, "if you ignored it, they blame you and you pay")
	_clear(cards)

	# ---- billing leakage
	c.new_game("owner")
	var rev0: int = o.weekly_estimate().revenue
	o.fire({"event": "leak_start"})
	_check(
		o.leak == 0.06 and o.weekly_estimate().revenue < rev0, "a silent leak starts eating revenue"
	)
	o.show_card("billing_audit")
	cards.pick(0)
	_clear(cards)
	_check(
		o.leak_found and o.leak == 0.01 and o.weekly_estimate().revenue > rev0 * 0.98,
		"the billing audit finds it and fixes most of it"
	)

	# ---- the sales handover
	c.new_game("owner")
	o.cash = 5000
	var signed: int = sales.sign_client()
	_check(o._handover.has(signed), "a new client queues a handover decision")
	o.begin_day(3)
	_check(
		cards.is_open and cards.speaker.begins_with("Vic") and cards.text.contains("handover"),
		"Vic asks about the handover"
	)
	cash0 = o.cash
	var mood0: int = sales.mood(signed)
	cards.pick(0)
	_clear(cards)
	_check(
		o.cash == cash0 - 150 and sales.mood(signed) == mood0 + 8 and o.flags.practice_handover,
		"a full handover: new client starts happier"
	)

	# ---- the peer group's accountability goal
	c.new_game("owner")
	o.flags["peer_group"] = true
	c.day = 5
	o._peer_goal()
	_check(cards.is_open and cards.options.size() == 4, "the group asks you to set a goal")
	cards.pick(0)
	_clear(cards)
	_check(o.goal.id == "w2", "goal set: W-2 ratio under 60%")
	c.day = 11
	rep0 = c.rep
	o._peer_goal()
	_check(
		c.rep == rep0 - 1 and o.flags.practice_goal and cards.is_open,
		"missed it (67%%): the group is disappointed, and sets the next goal"
	)
	_clear(cards)
	o.goal = {"id": "mood", "week": 11}
	rep0 = c.rep
	for k in sales.active:
		sales.satisfaction[k] = 80
	c.day = 17
	o._peer_goal()
	_check(
		c.rep == rep0 + 2 and not cards.is_open,
		"hit the goal: reputation up, and no new goal after the last meeting"
	)

	# ---- the maturity badge
	c.new_game("owner")
	_check(o.oml() == 1, "a fresh company is at level 1: Beginning")
	c.day = 3
	o.flags["peer_group"] = true
	o.flags["practice_profit"] = true
	o.flags["backup_service"] = true
	o.apply({"price": 0.1, "vic_plan": "balanced"})
	_check(o.oml() <= 2, "habits alone do not buy maturity: it is capped by the week (%d at week 3)" % o.oml())
	c.day = 16
	_check(
		o.oml() >= 3,
		(
			"building good habits raises the maturity level (%d, %s)"
			% [o.oml(), o.OML_NAMES[o.oml() - 1]]
		)
	)
	o.flags["practice_goal"] = true
	o.flags["practice_handover"] = true
	o.flags["collections_done"] = true
	o.apply({"stack": {"psa": "opsforge"}})
	o.flags["growth_done"] = true
	o.flags["practice_scope"] = true
	_check(o.oml() == 5, "enough habits, given time, make you Innovating")

	# ---- everything survives a save
	c.new_game("owner")
	o.burnout = 42.0
	o.leak = 0.06
	o.risk_client = 3
	o.risk_choice = "waiver"
	o.goal = {"id": "ar", "week": 5}
	o.profit_hist = {1: [100, 200]}
	o.scope_fixed = {2: true}
	c.day = 6
	c.save()
	c.new_game("free")
	_check(
		(
			c.continue_game("owner")
			and o.burnout == 42.0
			and o.leak == 0.06
			and o.risk_choice == "waiver"
		),
		"state saved: burnout, leak, risk"
	)
	_check(
		o.goal.id == "ar" and o.profit_hist[1].size() == 2 and o.scope_fixed.get(2, false),
		"goal, profit history and scope saved"
	)
	DirAccess.remove_absolute(c.save_path("owner"))

	# ---- the Boardroom still draws every tab
	var comp := root.get_node("Computer")
	c.new_game("owner")
	comp.open(1)
	comp.activate("app:boardroom")
	for tab in ["clients", "team", "stack", "books"]:
		comp.activate("btab:" + tab)
		_check(comp.board_tab == tab, "boardroom tab " + tab)
	comp.close()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
