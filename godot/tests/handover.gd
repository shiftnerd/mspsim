extends SceneTree
# gdlint:disable=max-line-length
# The handover scene (C2): a win queues a meeting in the conference room (Morgan and Dan are sent there, the objective line says so),
# the promise list is walked one card at a time (keep / renegotiate / drop), the gap that is left becomes the client's starting mood
# and the service risk (the churn meter), Dan and Morgan react, and a handover nobody attends turns into "just the paperwork".
# Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 60:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


func _lead(sc: Node, n: int) -> Dictionary:
	var l: Dictionary = sc.make_lead(root.get_node("Difficulty").rng_for("handover_test", n))
	l.users = 24
	l.fee = 726
	l.pain = "no backup of patient files"
	l.quality = 60
	l.called = true
	l.visited = true
	l.stage = "QUOTED"
	sc.leads.append(l)
	return l


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var social := root.get_node("Social")
	var hints := root.get_node("Hints")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	player_script.current_character = "office_john"
	diff.seed_run(88)
	c.new_game("sales")
	_clear(cards)
	world.clock = 9.0
	msp.tickets = []
	sc.book = []
	sc.plan = "balanced"
	var handover = load("res://scripts/handover.gd")
	var deals = load("res://scripts/deals.gd")

	# ---- the win queues the scene
	var l := _lead(sc, 1)
	var q: Dictionary = deals.norm({"method": "fixed", "promise": "high", "price": "list", "extras": ["backup", "security"], "onboard": "rush"})
	var deal: Dictionary = sc.close_deal(l, q)
	_check(cards.is_open and "commission" in str(cards.text).to_lower(), "the client thanks you first")
	sc.bell_ready = false
	hints.objective = ""
	cards.pick(0)
	_check(sc.pending_handover == int(deal.id) and str(deal.state) == "handover" and not cards.is_open, "then the handover is queued: no card, a meeting")
	_check("HANDOVER" in str(hints.objective) and "CONFERENCE" in str(hints.objective), "the objective line sends you to the conference room (%s)" % str(hints.objective))
	var morgan_legs: Array = world.chars.Morgan.legs
	var dan_legs: Array = world.chars.Dan.legs
	var m_meets := morgan_legs.any(func(x: Dictionary) -> bool: return str(x.get("scene", "")) == "conference" and str(x.get("kind", "")) == "meeting")
	var d_meets := dan_legs.any(func(x: Dictionary) -> bool: return str(x.get("scene", "")) == "conference" and str(x.get("kind", "")) == "meeting")
	_check(m_meets and d_meets, "Morgan and Dan are sent to sit in the conference room")
	handover.tick()
	_check(sc.pending_handover == int(deal.id) and not cards.is_open, "nothing starts while you are somewhere else")
	_check(deal.promises.size() == 5 and deal.promises.all(func(p: Dictionary) -> bool: return str(p.state) == "open"), "five promises are waiting: SLA tier, response, two services, the onboarding date")
	var gap_total: float = float(deal.gap)
	_check(gap_total >= 2.0, "a premium SLA, two services and a rush make a real gap (%.1f)" % gap_total)

	# ---- walk the list: keep the SLA, renegotiate the response time, drop the rest
	var dan0: int = social.value("Dan")
	var mor0: int = social.value("Morgan")
	handover.start(deal)
	_check(sc.pending_handover == 0 and cards.is_open and str(cards.speaker).begins_with("Morgan") and "5 promises" in str(cards.text), "in the room Morgan counts the promises")
	_check(not ("HANDOVER" in str(hints.objective)), "and the objective clears")
	cards.pick(0)
	var picks := [0, 1, 2, 2, 2]
	for i in 5:
		_check(cards.is_open and cards.options.size() == 3 and ("Promise %d of 5" % (i + 1)) in str(cards.text), "card %d names the promise and Dan's view of it" % (i + 1))
		_check("KEEP" in str(cards.options[0].label) and "RENEGOTIATE" in str(cards.options[1].label) and "DROP" in str(cards.options[2].label), "keep / renegotiate / drop")
		cards.pick(picks[i])
	var states := []
	var left := 0.0
	for p in deal.promises:
		states.append(str(p.state))
		left += float(p.left)
	_check(states == ["kept", "renegotiated", "dropped", "dropped", "dropped"], "each promise has its outcome: " + str(states))
	_check(float(deal.promises[0].left) == snappedf(float(deal.promises[0].gap) * 0.5, 0.1) and float(deal.promises[1].left) == 0.0 and float(deal.promises[2].left) == float(deal.promises[2].gap), "kept halves its gap, renegotiated clears it, dropped keeps all of it")
	_check(absf(float(deal.gap) - snappedf(left, 0.1)) < 0.001 and float(deal.gap) < gap_total, "the deal's gap is what is left (%.1f of %.1f)" % [float(deal.gap), gap_total])
	var mood_expected: int = clampi(72 - int(round(float(deal.gap) * 8.0)) - 3, 25, 85)
	_check(int(deal.mood) == mood_expected, "starting mood = 72 - 8 x gap - 3 for the renegotiation (%d)" % int(deal.mood))
	_check(int(deal.churn) == clampi(int(round(10.0 + 12.0 * float(deal.gap) + 12.0)), 0, 100), "the service risk is the churn meter's start (%d)" % int(deal.churn))
	_check(bool(deal.complain) and str(deal.state) == "active" and not bool(deal.onboarded) and int(deal.onboard_due) == int(deal.week) + 1, "the client will complain, is live and onboarding is due next week")
	_check(cards.is_open and str(cards.speaker).begins_with("Dan") and "Starting mood" in str(cards.text), "Dan answers with a short card that states the mood and the risk")
	cards.pick(0)
	_check(social.value("Morgan") == mor0 + 1, "Morgan likes the honest renegotiation")
	var heavy_kept: bool = float(deal.promises[0].gap) >= 0.5
	var heavy_dropped := false
	for k in [2, 3, 4]:
		heavy_dropped = heavy_dropped or float(deal.promises[k].gap) >= 0.5
	_check(social.value("Dan") == dan0 + 1 + (1 if heavy_kept else 0) - (1 if heavy_dropped else 0), "Dan: told the truth (+1), asked to plan a heavy SLA (+1), a heavy promise dropped on him (-1)")
	_check(deal.promises[0].state == "kept" and sc.handovers == 1, "the handover is counted")
	handover.bubble("Dan", "!")
	handover.bubble("Nobody", "heart")
	_check(true, "bubbles over people who are not in the room are a harmless no-op")

	# ---- outcomes compared: the same deal three ways
	var results := {}
	for how in ["kept", "renegotiated", "dropped"]:
		var l2 := _lead(sc, 20 + results.size())
		var d2: Dictionary = sc.close_deal(l2, q)
		_clear(cards)  # thank you; the queue
		sc.pending_handover = 0
		handover.decide_all(d2, how)
		handover.finish(d2, false)
		results[how] = d2
	_check(float(results.renegotiated.gap) == 0.0 and int(results.renegotiated.mood) == 72 - 15, "renegotiating all five: no gap, mood 72 - 3 x 5")
	_check(float(results.kept.gap) > 0.0 and float(results.kept.gap) < float(results.dropped.gap), "keeping halves the gap, dropping leaves it all")
	_check(int(results.dropped.mood) < int(results.kept.mood) and int(results.dropped.churn) > int(results.kept.churn), "so dropped promises start unhappier and riskier than kept ones")
	_check(int(results.kept.mood) > 72 - int(round(float(results.dropped.gap) * 8.0)), "kept promises leave the client happier than glossing over the gap")
	_check(handover.promise_text(results.kept, 0).contains("Promise 1 of 5"), "promise text names the position")

	# ---- the old three answers map onto the list
	var l3 := _lead(sc, 40)
	var d3: Dictionary = sc.close_deal(l3, q)
	_clear(cards)
	sc.pending_handover = 0
	var d3b: Dictionary = d3.duplicate(true)
	sc.handover(d3, "honest")
	sc.handover(d3b, "gloss")
	_check(float(d3.gap) == 0.0 and not bool(d3.complain) and float(d3b.gap) > 0.0 and bool(d3b.complain), "honest = renegotiate everything, gloss = drop everything")

	# ---- nobody comes: the paperwork goes over
	var l4 := _lead(sc, 50)
	var d4: Dictionary = sc.close_deal(l4, q)
	_clear(cards)
	_check(sc.pending_handover == int(d4.id), "another win waits for its meeting")
	msp.texts = []
	c.day += 1
	sc.begin_week(c.day)
	_clear(cards)
	_check(sc.pending_handover == 0 and str(d4.state) == "active" and d4.promises.all(func(p: Dictionary) -> bool: return str(p.state) == "dropped"), "next Monday it is just the paperwork: every promise dropped")
	_check(float(d4.gap) > 0.0 and bool(d4.complain) or float(d4.gap) < 0.5, "and the whole gap is the client's problem")
	var texted := false
	for t in msp.texts:
		if "paperwork" in str(t.body).to_lower() and str(t.from) == "Morgan":
			texted = true
	_check(texted, "Morgan texts you about it")
	_check(not ("HANDOVER" in str(hints.objective)), "the objective is cleared")

	# ---- old saves: a deal without promises uses the original arithmetic
	var legacy := {"id": 9001, "name": "Old Save", "mrr": 500, "margin": 0.5, "week": 1, "promise": "high", "gap": 1.0, "mood": 72, "complain": false, "resolved": true}
	sc.handover(legacy, "brief")
	_check(absf(float(legacy.gap) - 0.5) < 0.001 and int(legacy.mood) == 68, "a deal from an old save still halves the gap when briefed")
	c.finish_campaign("test")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
