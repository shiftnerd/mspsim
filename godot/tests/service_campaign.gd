extends SceneTree
# gdlint:disable=max-line-length
# C4 / V1: the service manager campaign played as Dan. Select + new game + save / continue, the huddle focus, the crew
# autopilot, the scorecard rows, 1:1s, owner memos (trust moves), incidents (take / send / ask), the review endings and a
# 20-day run through the real day loop with every card dismissed. Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


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


func _start() -> void:
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Campaign").new_game("service")


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var owner := root.get_node("Owner")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var sales := root.get_node("Sales")
	var social := root.get_node("Social")
	var talk := root.get_node("Talk")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- the registry row and the select screen
	_check(c.is_selectable("service") and c.MODES.has("service") and not c.is_planned("service"), "service is selectable")
	var def: Dictionary = c.MODE_DEFS.service
	_check(def.crew and not def.books and def.cards and def.day_len == 360.0 and def.review == "service", "gates: crew + cards, no books; 6 minute days")
	var cs = load("res://scripts/charselect.gd").new()
	_check(cs.choices("service") == ["office_dan"], "character select offers only Dan")
	cs.setup("service")
	_check(str(cs.info("office_dan").blurb).contains("LABELS EVERYTHING"), "Dan has a one-line blurb")
	cs.free()

	# ---- new game
	_start()
	_clear(cards)  # the huddle
	_check(c.active and c.mode == "service" and c.player_as == "Dan", "new game: you are Dan")
	_check(not world.chars.has("Dan") and world.chars.has("Maya") and world.chars.has("Vic") and world.chars.has("Morgan"), "Dan's NPC copy is gone, the rest are in")
	_check(c.crew_active() and not c.books_active() and c.cards_active(), "crew true, books false, cards true")
	_check(world.day_len == 360.0 and c.rep == 55, "day_len 360, confidence starts at 55")
	_check(str(world.player_desk().scene) == "main_floor" and str(world.player_desk().seat) == "Seat3", "your desk is main floor Seat3")
	_check(crew.names() == ["Maya", "Sam", "Terry"] and sv.trust_of("Alan") == 50 and sv.trust_of("Garrison") == 50, "crew and trust meters")
	_check(not social.people().has("Dan") and social.people().has("Maya"), "Social.people excludes you")
	var speed: float = owner.team_speed()
	_check(speed > 1.8 and speed < 3.4, "crew autopilot speed %.2f" % speed)

	# ---- huddle focus
	c.day = 1
	sv.begin_day(1)
	_check(cards.is_open and cards.speaker == "Morning huddle" and cards.options.size() == 4, "the huddle card has four focuses")
	_check(str(cards.options[0].label) == "P1 FIRST" and str(cards.options[3].label) == "PROJECT DAY", "huddle labels")
	cards.pick(1)
	_check(sv.focus == "queue" and owner.speed > 1.05, "CLEAR THE QUEUE speeds the crew (%.2f)" % owner.speed)
	var miss_queue: float = owner.edge("close_miss")
	sv.set_focus("p1")
	_check(owner.speed < 1.0 and owner.edge("close_miss") < miss_queue, "P1 FIRST is slower and safer")
	sv.set_focus("project")
	sv.project_days = 3
	_check(owner.edge("issues") < 1.0, "project days cut ticket volume (%.2f)" % owner.edge("issues"))
	sv.project_days = 0
	sv.set_focus("p1")
	_clear(cards)

	# ---- the crew works the queue and picks tickets up
	msp.tickets.clear()
	var t: Dictionary = msp.create_ticket(0, 0, "email")
	var tid := int(t.id)
	sv._pickup()
	_check(str(msp.ticket(tid).status) == "In Progress" and str(msp.ticket(tid).get("assignee", "")) != "", "the crew picks up a new ticket")
	var before: int = msp.closed_ok
	for _i in 12:
		owner._work_queue(40.0)
	_check(msp.closed_ok > before or msp.reopened > 0, "the autopilot closes tickets")

	# ---- 1:1s
	crew.members["Maya"]["morale"] = 50
	var m0: int = crew.morale("Maya")
	sv.one_on_one("Maya")
	_check(cards.is_open and cards.options.size() == 3, "Maya's 1:1 card has three options")
	cards.pick(0)
	_check(cards.is_open, "the reply card follows")
	_clear(cards)
	_check(crew.morale("Maya") > m0 and crew.value("Maya", "retain") >= 1, "a good answer lifts Maya's morale and retention (%d)" % crew.morale("Maya"))
	sv.one_on_one("Maya")
	_check(str(cards.text).contains("this morning"), "only one 1:1 a day per person")
	_clear(cards)
	var low_before: int = crew.morale("Sam")
	c.day = 5
	sv.one_on_one("Sam")
	cards.pick(2)
	_clear(cards)
	_check(crew.morale("Sam") < low_before, "a curt answer to a tech hurts (%d -> %d)" % [low_before, crew.morale("Sam")])
	var vic0: int = social.value("Vic")
	sv.one_on_one("Vic")
	cards.pick(1)
	_clear(cards)
	_check(social.value("Vic") > vic0, "a 1:1 with Vic moves his opinion")
	_check(talk.has_method("start") and sv.has_one_on_one("Maya") and sv.has_one_on_one("Vic") and not sv.has_one_on_one("Alan"), "Talk offers a 1:1 for Maya and Vic")
	var deck_ok := true
	for deck in sv.ONE_ON_ONES:
		deck_ok = deck_ok and sv.ONE_ON_ONES[deck].size() >= 3
	_check(deck_ok, "every 1:1 deck has 3+ cards")

	# ---- owner memos
	var ta0: int = sv.trust_of("Alan")
	var tg0: int = sv.trust_of("Garrison")
	sv.memo("m1")
	_check(cards.is_open and cards.speaker.begins_with("Alan") and cards.options.size() == 3, "the day 2 memo is Alan's")
	cards.pick(0)
	_clear(cards)
	_check(sv.trust_of("Alan") > ta0 and sv.trust_of("Garrison") < tg0, "siding with Alan: his trust up, Garrison's down")
	var issues_after: float = owner.edge("issues")
	_check(issues_after < 1.0, "the memo's real effect: fewer tickets (%.2f)" % issues_after)
	ta0 = sv.trust_of("Alan")
	tg0 = sv.trust_of("Garrison")
	sv.memo("m2")
	_check(cards.speaker.begins_with("Garrison"), "the day 5 memo is Garrison's")
	cards.pick(0)
	_clear(cards)
	_check(sv.trust_of("Garrison") > tg0 and sv.trust_of("Alan") < ta0, "siding with Garrison moves the meters the other way")
	sv.memo("m3")
	cards.pick(2)
	_clear(cards)
	_check(sv.memos_done.size() == 3, "memos are marked done")
	var memo_days := []
	for id in sv.MEMOS:
		memo_days.append(int(sv.MEMOS[id].day))
	_check(memo_days.size() >= 6 and memo_days.min() == 2, "memos start on day 2 and come every few days")

	# ---- incidents: send Maya, ask the owner, take it
	c.day = 11
	sv.incident("rack", "rack")
	_check(cards.is_open and cards.options.size() == 3, "an incident asks who takes it")
	cards.pick(1)
	_clear(cards)
	_check(str(sv.flags.get("job_rack", "")) != "" and not root.get_node("Playbook").is_active(), "Maya ran the rack job: grade %s" % str(sv.flags.get("job_rack", "")))
	var ta1: int = sv.trust_of("Alan")
	sv.run_incident("migration", "ask")
	_clear(cards)
	_check(sv.trust_of("Alan") == ta1 + 3, "asking Alan costs Garrison's goodwill and earns Alan's")
	sv.run_incident("rdp", "take")
	_check(root.get_node("Playbook").is_player_job() if root.get_node("Playbook").has_method("is_player_job") else root.get_node("Playbook").is_active(), "taking it yourself starts the Playbook job")
	root.get_node("Playbook").reset()
	msp.backups[3].ok = true
	sv.run_incident("ransom", "send")
	_clear(cards)
	_check(str(root.get_node("Story").flags.get("ransom", "")) == "saved", "a good backup: the ransomware is restored")

	# ---- scorecard rows
	_start()
	_clear(cards)
	world.clock = 16.9
	sv._cap = 100.0
	var r: Dictionary = c.make_report()
	sv.close_day(r)
	var labels := []
	for g in r.groups:
		for row in g[1]:
			labels.append(str(row[0]))
	for want in ["FIRST RESPONSE", "SLA KEPT", "TICKETS CLOSED", "REOPENS", "UTILISATION", "TECH MORALE", "CLIENT MOOD", "ALAN TRUST", "GARRISON TRUST"]:
		_check(labels.has(want), "scorecard row " + want)
	_check(r.grade in ["S", "A", "B", "C", "D"] and r.has("rep_delta") and r.rep_name == "CONFIDENCE", "scorecard grade and confidence change")

	# ---- stuck, morale and quits
	_start()
	_clear(cards)
	crew.members["Sam"]["morale"] = 5
	var quit_seen := false
	for _i in 40:
		crew.members["Sam"]["morale"] = 5
		if crew.end_day(0.5, "D").has("Sam"):
			quit_seen = true
			break
	_check(quit_seen and crew.is_gone("Sam") and crew.size() == 2, "a tech with no morale left eventually quits")
	_check(crew.skill() < 2.2, "the crew gets slower")

	# ---- save / continue
	_start()
	_clear(cards)
	sv.add_trust("Alan", 9)
	sv.focus = "mentor"
	crew.members["Maya"]["morale"] = 77
	c.day = 6
	c.save()
	_check(c.has_save("service") and c.saved_day("service") == 6, "the service save exists (day 6)")
	sv.reset()
	crew.reset()
	_check(c.continue_game("service"), "continue works")
	_clear(cards)
	_check(sv.trust_of("Alan") == 59 and crew.morale("Maya") == 77 and c.player_as == "Dan" and c.day == 6, "trust, morale and player_as come back")

	# ---- the review endings
	sv.trust["Alan"] = 70
	sv.trust["Garrison"] = 65
	c.rep = 70
	var ids := []
	for o in sv.review_offers():
		ids.append(str(o.id))
	_check(ids.has("ops") and ids.has("alan") and ids.has("leave") and ids.has("stay"), "ops / alan / leave / stay offered: " + str(ids))
	sv.trust["Garrison"] = 80
	sv.trust["Alan"] = 30
	ids = []
	for o in sv.review_offers():
		ids.append(str(o.id))
	_check(ids.has("garrison") and not ids.has("ops") and not ids.has("alan"), "siding with Garrison shows only his offer")
	c.rep = 20
	_check(sv.review_offers().size() >= 1 and str(sv.review_offers().back().id) == "stay", "probation is always there")
	c.rep = 70

	# ---- 20 days through the real day loop
	_start()
	_clear(cards)
	var played := 0
	var ended := false
	for day in range(1, 21):
		world.clock = 8.6
		var hour := 8.6
		var guard := 0
		while not report.is_open and hour < 23.9 and guard < 200:
			guard += 1
			hour += 0.15
			world.clock = hour
			await process_frame
			await process_frame
			_clear(cards, (day + guard) % 3)
			owner._work_queue(25.0)
			if guard % 7 == 0 and crew.has("Maya"):
				crew.add_all(1)
		_check(report.is_open, "day %d ends with the scorecard" % day)
		played += 1
		if day == 5:
			var seen := false
			for g in report.report.get("groups", []):
				for row in g[1]:
					seen = seen or str(row[0]) == "SLA KEPT"
			_check(seen, "the scorecard shows service rows")
		if report.report.get("final", false):
			ended = true
			break
		report.finish()
		await create_timer(0.7).timeout
		root.get_node("Game").busy = false
		_clear(cards)
	_check(played >= 3, "played %d days" % played)
	if ended and not report.report.get("fired", false):
		_check(played == 20, "all 20 days played")
		var arc := root.get_node("ServiceArc")
		_check(arc.fired.size() == arc.SCHEDULE.size(), "C7: every story beat fired on its own day (%d of %d)" % [arc.fired.size(), arc.SCHEDULE.size()])
		_check(sv.memos_done.size() == 6 and arc.picks.has("m1") and arc.picks.has("m6"), "C7: six memos answered, the sides noted (%s)" % str(arc.sides))
		_check(arc.audit.has("total"), "C7: the audit was computed (%s of 100)" % str(arc.audit.get("total", "?")))
		var ending_ids := []
		for o in sv.review_offers():
			ending_ids.append(str(o.id))
			_check(sv.review_lines(3, str(o.id)).size() >= 2 and str(sv.review_lines(3, str(o.id))[1][0]).length() > 20, "C7: ending %s has its page" % str(o.id))
		_check(ending_ids.has("stay"), "C7: probation is always on the list: " + str(ending_ids))
		report.finish()
		await process_frame
		_check(review.is_open and review.offers.size() >= 2, "the review offers %d endings" % review.offers.size())
		_check(str(review.page_lines()[0][0]).begins_with("MORGAN"), "review page 1 is Morgan's summary")
		review.page = 2
		review.choose(0)
		_check(review.page == 3 and review.page_lines().size() >= 2, "the ending page")
		review.finish()
		await create_timer(0.5).timeout
	elif ended:
		report.finish()
		await create_timer(0.5).timeout
		print("(the run was fired: a valid ending)")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
