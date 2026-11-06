extends SceneTree
# X4: the owner campaign played as Alan or Garrison. Both owners across 20 weeks with every card auto-answered; the
# crew (Dan, Maya, Morgan as manager, the partner at half speed), the per-owner edges, the personal goals, the card
# text pass ({tech} {ops} {me} {partner}), the weekly owner draw (policy card, cash but not EBITDA, an overdraw upsets
# the partner) and no script errors (the runner greps the output for SCRIPT ERROR). Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# answer every open card; if the wanted option is greyed out take the first open one
func _clear(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 30:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1
	return n


func _start(character: String) -> void:
	player_script.current_character = character
	root.get_node("Game").title_mode = false  # an earlier ending sent the game back to the title
	root.get_node("Game").busy = false
	root.get_node("Campaign").new_game("owner")
	_clear(root.get_node("Cards"))


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var social := root.get_node("Social")
	var roles := root.get_node("Roles")
	var partner := root.get_node("Partner")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var sales := root.get_node("Sales")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- who is on the team, as Alan and as Garrison
	for who in ["Alan", "Garrison"]:
		_start("office_alan" if who == "Alan" else "casual_garrison")
		var other: String = "Garrison" if who == "Alan" else "Alan"
		_check(c.player_as == who and roles.partner() == other, "%s: you are %s, the partner is %s" % [who, who, other])
		_check(
			not world.chars.has(who) and world.chars.has(other) and world.chars.has("Maya") and world.chars.has("Morgan") and world.chars.has("Dan"),
			"%s: Maya, Dan, Morgan and the partner are in the building" % who
		)
		_check(o.crew_names() == ["Dan", "Maya"] and absf(partner.hands() - 0.5) < 0.001, "%s: crew Dan and Maya, the partner works at 0.5" % who)
		var est: Dictionary = o.weekly_estimate()
		_check(est.payroll == 2700, "%s: payroll covers Dan, Maya, Morgan and John, no owners (%d)" % [who, int(est.payroll)])
		var speed: float = o.team_speed()
		_check(speed > 2.2 and speed < 3.4, "%s: team speed %.2f stays close to the old three-tech crew" % [who, speed])
		o.lost_techs = 1
		_check(o.crew_names() == ["Dan"] and o.team_speed() < speed, "%s: a quit takes Maya out of the queue" % who)
		o.lost_techs = 0

	# ---- the edges
	_start("office_alan")
	var alan_edges: Dictionary = o.edges_for("Alan")
	var garrison_edges: Dictionary = o.edges_for("Garrison")
	_check(alan_edges.close_miss < garrison_edges.close_miss, "Alan closes tickets for good more often")
	_check(absf(o.edge("close_miss") - 0.04) < 0.0001, "the edge table feeds the premature close chance (Alan 4%)")
	o.marketing = 400
	var alan_mkt: float = o.marketing_bonus()
	var alan_issue: float = o.issue_mult()
	var alan_risk: float = o.security_risk()
	var alan_mood: int = o.new_client_mood()
	var alan_poach: float = o.poach_risk(0)
	_start("casual_garrison")
	o.marketing = 400
	_check(o.marketing_bonus() > alan_mkt, "Garrison's marketing works better than Alan's")
	_check(o.issue_mult() > alan_issue, "Alan's stack choices cut tickets")
	_check(o.security_risk() > alan_risk, "Alan's vendor-breach exposure is lower")
	_check(o.new_client_mood() == alan_mood + 4, "Garrison's new clients start +4 happier")
	_check(o.poach_risk(0) < alan_poach, "Garrison keeps clients from the competitor")
	_check(o.edges_for("Nobody").close_miss == 0.07, "edges_for() falls back to the neutral edge (the hook for point-buy)")
	# fee rises: Garrison sells them, Alan does not
	var table := [[0.5, {"fee_boost": {"client": 0, "mult": 1.2}}, "yes"], [0.5, {}, "no"]]
	var g_table: Array = o.tilted(table)
	_start("office_alan")
	var a_table: Array = o.tilted(table)
	_check(float(g_table[0][0]) > float(a_table[0][0]), "a fee rise is accepted more often when Garrison asks")

	# ---- the card text pass
	_start("office_alan")
	o.show_card("backup")
	_check(cards.is_open and cards.speaker.begins_with("Dan") and cards.text.begins_with("Alan,"), "as Alan, Dan brings the backup question to you: %s" % cards.speaker)
	_clear(cards, 1)
	o.show_card("after_hours")
	_check(cards.speaker.begins_with("Morgan"), "Morgan brings the after-hours question")
	_clear(cards, 2)
	o.show_card("raise")
	_check(cards.speaker.begins_with("Dan") and cards.text.begins_with("Alan,"), "Dan asks for the raise")
	_clear(cards, 0)
	_start("casual_garrison")
	o.show_card("backup")
	_check(cards.speaker.begins_with("Alan") and cards.text.begins_with("Garrison,"), "as Garrison, Alan brings the backup question to you")
	_clear(cards, 1)
	o.show_card("rack")
	var labels := ""
	for opt in cards.options:
		labels += str(opt.label) + "|"
	_check(labels.contains("SEND ALAN NOW") and not labels.contains("{"), "no raw tokens on a card: " + labels.substr(0, 60))
	_clear(cards, 2)
	var banned := ["senior tech", "the techs", "Boss,", "three techs"]
	var hits := []
	for id in o.CARDS:
		var card: Dictionary = o.CARDS[id]
		var all := str(card.text) + str(card.speaker)
		for opt in card.options:
			all += str(opt.label) + str(opt.get("text", ""))
		for bad in banned:
			if all.contains(bad):
				hits.append(id + ":" + bad)
	_check(hits.is_empty(), "the card tables are free of the old tech wording " + str(hits))

	# ---- Maya is in the crew roster, the board shows the new team
	_start("office_alan")
	_check(social.people().has("Maya") and world.chars.has("Maya"), "Maya is one of your coworkers")

	# ---- the weekly owner draw
	_start("office_alan")
	c.day = 2
	o.show_card("draw_policy")
	_check(cards.is_open and cards.options.size() == 4, "week 2: Christy asks what the owners take")
	var est_before: Dictionary = o.weekly_estimate()
	cards.pick(2)
	_clear(cards)
	_check(o.draw_policy == "generous", "a generous draw is a policy choice")
	c.day = 4
	var est_gen: Dictionary = o.weekly_estimate()
	_check(est_gen.draw == 1000 and est_gen.ebitda == est_before.ebitda, "the draw is outside EBITDA")
	_check(est_gen.cashflow == est_gen.ebitda - 1000, "and it is a line in the cash flow")
	o.cash = 8000
	var cash0: int = o.cash
	var books: Dictionary = o.settle()
	var draw_row := false
	for row in books.rows:
		if str(row[0]) == "OWNER DRAW" and str(row[1]).contains("1000"):
			draw_row = true
	_check(draw_row, "the weekly report has an OWNER DRAW line")
	_check(o.draw_paid == 1000 and o.cash < cash0 + int(est_gen.revenue), "the draw leaves the bank (cash %d from %d)" % [o.cash, cash0])
	_clear(cards)
	# an oversized draw upsets Christy and the partner
	_start("office_alan")
	c.day = 5
	o.draw_policy = "generous"
	o.cash = 1500
	var trust0: int = partner.trust
	o.settle()
	_check(partner.trust < trust0 and cards.is_open and cards.speaker.begins_with("Christy"), "a draw the bank cannot take costs partner trust and Christy speaks up")
	_clear(cards)
	# no draw is allowed
	_start("casual_garrison")
	c.day = 2
	o.show_card("draw_policy")
	cards.pick(3)
	_clear(cards)
	c.day = 6
	_check(o.draw_policy == "none" and o.draw_due() == 0, "drawing nothing is allowed")
	_check(o.weekly_estimate().cashflow == o.weekly_estimate().ebitda, "and then cash flow equals EBITDA")
	o.draw_policy = "normal"
	c.day = 2
	_check(o.draw_due() == 0, "no draw is paid before week 3")

	# ---- personal goals
	_start("office_alan")
	_check(o.goal_parts(true).size() == 3 and o.goal_title() == "A CLEAN YEAR", "Alan's goal: a clean year (three parts)")
	o.incidents = 1
	_check(not o.goal_met(), "a break-in spoils the clean year")
	o.incidents = 0
	root.get_node("Story").flags["ransom"] = "lost"
	_check(not o.goal_parts()[0].ok, "so does losing data to ransomware")
	root.get_node("Story").flags["ransom"] = "saved"
	_check(o.goal_parts()[0].ok, "a ransomware attack stopped by the backup does not")
	_check(str(o.goal_row()[0]) == "PERSONAL GOAL", "the goal is a row in the weekly report")
	_start("casual_garrison")
	_check(o.goal_parts(true).size() == 2 and o.goal_title() == "THE SHOP CLIENTS LOVE", "Garrison's goal: the shop clients love")
	o.lost_techs = 1
	_check(not o.goal_parts()[1].ok, "a quit means the team did not stay")
	o.lost_techs = 0
	for cl in sales.active:
		sales.satisfaction[int(cl)] = 90
	_check(o.goal_parts(true)[0].ok and o.goal_parts()[1].ok and o.goal_met(), "happy clients and a team that stayed meet the goal")
	var dict: Dictionary = o.to_dict()
	o.draw_policy = "small"
	o.from_dict(dict)
	_check(o.draw_policy == "normal" and dict.has("draw_policy") and dict.has("partner"), "the draw policy and the partner are saved")

	# ---- 20 weeks, both owners, the automated path
	for who in ["Alan", "Garrison"]:
		_start("office_alan" if who == "Alan" else "casual_garrison")
		var weeks := 0
		var ended := false
		for day in range(1, 21):
			world.clock = 8.6
			var hour := 8.6
			while not report.is_open and hour < 23.9:
				hour += 0.3
				world.clock = hour
				await process_frame
				await process_frame
				_clear(cards, (day + int(hour)) % 2)
				o._work_queue(20.0)
			_check(report.is_open, "%s week %d ends with a P&L report (cash $%d)" % [who, day, o.cash])
			weeks += 1
			if report.report.get("final", false):
				ended = true
				break
			report.finish()
			await create_timer(0.7).timeout
			root.get_node("Game").busy = false
		_check(weeks >= 1, "%s: played %d weeks" % [who, weeks])
		var rows_ok := false
		for row in report.report.get("rows", []):
			if str(row[0]) == "PERSONAL GOAL":
				rows_ok = true
		_check(rows_ok, "%s: the weekly report tracks the personal goal" % who)
		_check(o.draw_paid > 0 or weeks < 4, "%s: the draw was paid" % who)
		if ended and not report.report.fired:
			report.finish()
			await process_frame
			_check(review.is_open and review.offers.size() >= 2, "%s: the board review offers %d endings" % [who, review.offers.size()])
			var lines: Array = review.page_lines()
			review.page = 2
			var partner_lines: Array = review.page_lines()
			_check(str(partner_lines[0][0]) == "PARTNERSHIP", "%s: the review has a PARTNERSHIP page" % who)
			review.page = 3
			review.choose(0)
			_check(review.page == 4, "%s: the ending is the page after the offers" % who)
			review.finish()
			await create_timer(0.5).timeout
		elif ended:
			report.finish()
			await create_timer(0.5).timeout
			print("(%s: the run went bankrupt or lost its name: that is a valid ending)" % who)

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
