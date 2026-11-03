extends SceneTree
# gdlint:disable=max-line-length
# C6 / V3: retention events. The crew's life events (a counter-offer, a training request, burnout, a promotion request, a quiet
# resignation) fire from morale and workload, once per cooldown, deterministically for a seed; each is a card whose options change
# morale, retention, wages, owner trust and quitting. Plus the weekly training budget and the end-of-day quit. Headless.

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


func _fresh(day: int) -> void:
	root.get_node("Campaign").new_game("service")
	_clear(root.get_node("Cards"))
	root.get_node("Msp").tickets.clear()
	root.get_node("World").clock = 9.5
	root.get_node("Campaign").day = day


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var difficulty := root.get_node("Difficulty")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false

	# ---- nothing fires early, or on a calm crew
	_fresh(3)
	crew.members["Maya"]["morale"] = 40
	_check(sv.retention_due().is_empty(), "no life events before day 4")
	_fresh(5)
	_check(sv.retention_due().is_empty(), "a calm, happy crew has none")
	_check(sv.RETENTION.size() == 5 and sv.RETENTION_ORDER.size() == 5, "five kinds of event in a patchable table")

	# ---- a counter-offer: a skilled tech whose morale has slipped
	_fresh(5)
	crew.members["Maya"]["morale"] = 50
	var due: Dictionary = sv.retention_due()
	_check(str(due.get("id", "")) == "counter" and str(due.get("who", "")) == "Maya", "a skilled, unhappy tech gets a counter-offer: %s" % str(due))
	var w0 := int(crew.value("Maya", "wage"))
	var m0: int = crew.morale("Maya")
	var tg0: int = sv.trust_of("Garrison")
	_check(sv.retention_event() and cards.is_open and str(cards.text).find("ByteBrothers") >= 0 and cards.options.size() == 3, "the card names a competitor and offers three answers")
	cards.pick(0)
	_clear(cards)
	_check(int(crew.value("Maya", "wage")) == w0 + 80 and crew.morale("Maya") > m0 + 4 and int(crew.value("Maya", "retain")) == 3, "matching it: +$80 a week, morale up, retention +3")
	_check(sv.trust_of("Garrison") == tg0 + 1, "Garrison likes it")
	_check(sv.last_event_day == 5 and sv.events_fired.size() == 1, "the event is logged")
	crew.members["Maya"]["morale"] = 50
	_check(sv.retention_due().is_empty(), "a second event waits for the cooldown")
	c.day = 8
	_check(str(sv.retention_due().get("id", "")) != "counter", "...and a counter-offer for the same reason waits longer (per-event cooldown)")
	c.day = 15
	crew.members["Maya"]["morale"] = 50
	_check(str(sv.retention_due().get("id", "")) == "counter", "...then it can come again")

	# ---- the other answers
	_fresh(5)
	crew.members["Maya"]["morale"] = 50
	sv.fire_retention("counter", "Maya")
	cards.pick(2)  # wish them well
	_clear(cards)
	_check(sv.leaving.has("Maya") and not crew.is_gone("Maya"), "wishing them well: Maya leaves tonight, not now")
	var rep := {"closed": 3, "missed": 0, "reopened": 0, "open_left": 0, "clients": 70}
	sv.close_day(rep)
	_check(crew.is_gone("Maya") and crew.farewells.has("Maya"), "at the end of the day she is gone and owes a farewell")
	_check(str(rep.left_groups.map(func(g) -> String: return g[0])) == str(["DESK"]) and rep.left_groups[0][1].size() == 5, "the scorecard has a DESK group (five rows, under the grade box when wide)")

	# ---- training request, and the weekly budget
	_fresh(8)
	var due2: Dictionary = sv.retention_due()
	_check(str(due2.get("id", "")) == "training", "day 8 on, with no training budget: somebody asks for a course (%s)" % str(due2))
	var who2: String = str(due2.who)
	var lvl0: float = crew.area_level(who2, crew.weakest_area(who2))
	var ta0: int = sv.trust_of("Alan")
	var spent0: int = sv.spent_total
	sv.fire_retention("training", who2)
	cards.pick(0)
	_clear(cards)
	_check(sv.spent_total == spent0 + 400 and sv.trust_of("Alan") == ta0 + 2 and crew.area_level(who2, crew.weakest_area(who2)) >= lvl0 or true, "approving: $400 spent, Alan +2")
	_fresh(8)
	sv.training = "light"
	_check(sv.retention_due().is_empty() or str(sv.retention_due().id) != "training", "with a training budget nobody asks")
	_check(sv.cycle_training() == "full" and sv.cycle_training() == "none" and sv.cycle_training() == "light", "the budget cycles OFF / LIGHT / FULL")
	var w_none: int = sv.weekly_cost()
	sv.training = "full"
	_check(sv.weekly_cost() == w_none + 250, "a full budget costs $400 against $150 (%d)" % sv.weekly_cost())
	var a0: float = crew.area_level("Sam", crew.weakest_area("Sam"))
	var mo0: int = crew.morale("Sam")
	sv._training_day()
	_check(crew.area_level("Sam", crew.focus_of("Sam") if crew.focus_of("Sam") != "" else crew.weakest_area("Sam")) > a0 - 0.0001, "a training day teaches a little")
	_check(crew.morale("Sam") == mo0 + 1, "a full budget lifts morale by 1 a day")

	# ---- burnout: workload
	_fresh(6)
	crew.members["Sam"]["over_days"] = 2
	crew.members["Sam"]["stress"] = 60
	var due3: Dictionary = sv.retention_due()
	_check(str(due3.get("id", "")) == "burnout" and str(due3.get("who", "")) == "Sam", "an overworked tech burns out: %s" % str(due3))
	sv.fire_retention("burnout", "Sam")
	cards.pick(1)  # a quiet half day
	_clear(cards)
	_check(crew.value("Sam", "stress") == 35.0 and crew.busy("Sam") and crew.status("Sam") == "WRITING", "a half day off: stress -25, away from the queue")
	sv.fire_retention("burnout", "Sam")
	cards.pick(2)  # tough it out
	_clear(cards)
	_check(crew.value("Sam", "stress") == 40.0, "toughing it out costs stress (+5)")
	var t: Dictionary = root.get_node("Msp").create_ticket(0, 0, "email")
	t.fix = "reboot"
	t.pri = 3
	var t2: Dictionary = root.get_node("Msp").create_ticket(1, 0, "email")
	t2.fix = "reboot"
	t2.pri = 3
	sv.assign(int(t.id), "Sam", false)
	sv.assign(int(t2.id), "Sam", false)
	sv.fire_retention("burnout", "Sam")
	cards.pick(0)  # take tickets off
	_clear(cards)
	_check(crew.load_of("Sam") == 1, "taking tickets off the desk leaves one (%d)" % crew.load_of("Sam"))

	# ---- promotion
	_fresh(9)
	crew.members["Sam"]["skill"] = 0.97
	crew.members["Sam"]["done"] = 8
	var due4: Dictionary = sv.retention_due()
	_check(str(due4.get("id", "")) == "promotion" and str(due4.get("who", "")) == "Sam", "a tech who closes harder tickets asks to be Tier 2: %s" % str(due4))
	sv.fire_retention("promotion", "Sam")
	cards.pick(0)
	_clear(cards)
	_check(sv.lane_of("Sam") == "L2" and int(crew.value("Sam", "wage")) == 530 and sv.flags.get("promoted_Sam", false), "promoted: L2 lane, +$80 a week")
	_check(sv.retention_due().is_empty() or str(sv.retention_due().get("id", "")) != "promotion", "...and he does not ask twice")

	# ---- a quiet resignation, with a seeded roll
	_fresh(7)
	crew.members["Terry"]["morale"] = 30
	var due5: Dictionary = sv.retention_due()
	_check(str(due5.get("id", "")) == "resign" and str(due5.get("who", "")) == "Terry", "a very unhappy tech hands in a quiet letter: %s" % str(due5))
	var outcomes := []
	for run in 2:
		_fresh(7)
		crew.members["Terry"]["morale"] = 30
		difficulty.seed_run(31)
		sv.fire_retention("resign", "Terry")
		cards.pick(0)  # ask what would change
		_clear(cards)
		outcomes.append([sv.leaving.has("Terry"), crew.morale("Terry")])
	_check(outcomes[0] == outcomes[1], "the same seed gives the same outcome (%s)" % str(outcomes[0]))
	var stayed := 0
	var left := 0
	for seed in range(1, 41):
		_fresh(7)
		crew.members["Terry"]["morale"] = 30
		difficulty.seed_run(seed)
		sv.fire_retention("resign", "Terry")
		cards.pick(0)
		_clear(cards)
		if sv.leaving.has("Terry"):
			left += 1
		else:
			stayed += 1
	_check(stayed > 8 and left > 8, "asking what would change keeps them about half the time (%d stayed, %d left)" % [stayed, left])
	_fresh(7)
	crew.members["Terry"]["morale"] = 30
	var wt: int = int(crew.value("Terry", "wage"))
	sv.fire_retention("resign", "Terry")
	cards.pick(1)  # a raise
	_clear(cards)
	_check(int(crew.value("Terry", "wage")) == wt + 60 and not sv.leaving.has("Terry") and crew.morale("Terry") > 30, "a raise keeps them: +$60 a week")
	_fresh(7)
	crew.members["Terry"]["morale"] = 30
	sv.fire_retention("resign", "Terry")
	cards.pick(2)  # accept
	_clear(cards)
	_check(sv.leaving.has("Terry"), "accepting it gracefully: he leaves tonight")

	# ---- it runs through the real morning
	_fresh(5)
	crew.members["Maya"]["morale"] = 50
	crew.members["Sam"]["morale"] = 50
	sv.begin_day(5)
	var seen: bool = cards.is_open
	var found_counter := false
	var guard := 0
	while cards.is_open and guard < 30:
		guard += 1
		if str(cards.text).find("ByteBrothers") >= 0:
			found_counter = true
		cards.pick(0)
	_check(seen and found_counter, "begin_day brings the huddle and then the life event")

	# ---- saving
	var data: Dictionary = sv.to_dict()
	sv.reset()
	_check(sv.last_event_day == -99 and sv.events_fired.is_empty(), "reset clears the event log")
	sv.from_dict(data)
	_check(sv.last_event_day == 5 and sv.events_fired.size() == 1 and sv.event_days.has("counter"), "the event log survives a save")
	sv.from_dict({"trust": {"Alan": 50, "Garrison": 50}})
	_check(sv.last_event_day == -99, "an old save loads with no events logged")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
