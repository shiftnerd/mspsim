extends SceneTree
# gdlint:disable=max-line-length
# Vic's voices in the sales campaign (C3): Talk (greeting, small talk, tips and the "ask" question of each coworker as seen by a salesman)
# and Lynk (messages from the coworkers, presence lines, NEED A HAND). Headless; saves in user://test_*.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(cards.options.size() - 1)
		n += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var talk := root.get_node("Talk")
	var lync := root.get_node("Lync")
	var social := root.get_node("Social")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var game := root.get_node("Game")
	var player_script: GDScript = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	player_script.current_character = "sales_vic"
	game.busy = false
	root.get_node("Difficulty").seed_run(31)
	c.new_game("sales")
	_clear(cards)
	sc.leads.clear()
	sc.book.clear()

	var people := ["Alan", "Garrison", "Dan", "Morgan", "Maya"]
	_check(people.all(func(p: String) -> bool: return social.people().has(p)) and not social.people().has("Vic"), "you talk to Alan, Garrison, Dan, Morgan and Maya, not to Vic")

	# ---- greetings in each mood, with the live numbers filled in
	var tiers := {"friend": 80, "neutral": 0, "cold": -30}
	var greet_ok := true
	var token_ok := true
	for p in people:
		for t in tiers:
			social.rel[p] = tiers[t]
			talk._who = p
			var g: String = talk._greeting(p)
			if g == "" or g == str(talk.GREETINGS[p][t]):
				greet_ok = false
			if "{" in g:
				token_ok = false
	_check(greet_ok, "every coworker greets the salesman in his own words, in every mood")
	_check(token_ok, "no {token} is left in a greeting")
	social.rel["Garrison"] = 0
	talk._who = "Garrison"
	_check("pipeline" in talk._greeting("Garrison").to_lower(), "Garrison asks about the pipeline")
	social.rel["Alan"] = 0
	_check("pipeline" in talk._greeting("Alan").to_lower(), "and so does Alan")

	# ---- the menu: a question that fits the person
	talk._who = "Dan"
	social.rel["Dan"] = 0
	talk._menu("x")
	_check(cards.is_open and str(cards.options[1].label) == "CAN YOUR CREW TAKE ANOTHER CLIENT?" and str(cards.options[2].label) == "ANY TIPS?", "Dan: CAN YOUR CREW TAKE ANOTHER CLIENT?")
	_clear(cards)
	var labels := {}
	for p in people:
		talk._who = p
		talk._menu("x")
		labels[p] = str(cards.options[1].label)
		_clear(cards)
	print(labels)
	_check(labels.Morgan.contains("HANDOVER") and labels.Maya.contains("CLIENTS") and labels.Alan == "PIPELINE UPDATE" and labels.Garrison == "PIPELINE UPDATE", "Morgan asks about handovers, Maya about clients, the owners about the pipeline")

	# ---- Dan warns about capacity
	talk._who = "Dan"
	var cap: float = sc.capacity()
	_check("take one" in talk.sales_answer("Dan").to_lower() or "we can take" in talk.sales_answer("Dan").to_lower(), "with room: Dan says the crew can take one (capacity %.1f)" % cap)
	for i in 5:
		sc.book.append({"id": 700 + i, "name": "Recent %d" % i, "type": "law", "who": "x", "mrr": 500, "week": c.day, "gap": 0.0, "mood": 70, "resolved": true, "promises": [], "state": "active", "churn": 10})
	_check(sc.capacity() < 1.2, "five signings this week crush the capacity (%.1f)" % sc.capacity())
	var a: String = talk.sales_answer("Dan")
	_check("Not this week" in a and "{" not in a, "Dan: not this week (%s)" % a.left(40))
	talk._who = "Dan"
	social.rel["Dan"] = 30
	var tip: String = talk.sales_tip()
	_check("Capacity is" in tip and "Promise four hours" in tip, "Dan's tip warns about capacity: " + tip.left(50))
	sc.book.clear()

	# ---- Morgan warns about promises
	talk._who = "Morgan"
	social.rel["Morgan"] = 30
	_check("Clean so far" in talk.sales_answer("Morgan"), "Morgan: clean handovers")
	sc.book.append({"id": 800, "name": "Gap Dental", "type": "dental", "who": "x", "mrr": 500, "week": c.day, "gap": 1.5, "mood": 70, "resolved": false, "promises": [], "state": "active", "churn": 10})
	_check("Gap Dental" in talk.sales_answer("Morgan") and "Gap Dental" in talk.sales_tip(), "Morgan names the deal with a promise gap, in an answer and in a tip")
	sc.book.clear()

	# ---- Maya reads the client moods
	talk._who = "Maya"
	social.rel["Maya"] = 30
	sc.book.append({"id": 801, "name": "Grumpy Realty", "type": "realty", "who": "x", "mrr": 500, "week": c.day, "gap": 0.0, "mood": 35, "resolved": true, "promises": [], "state": "active", "churn": 10})
	_check("Grumpy Realty" in talk.sales_answer("Maya") and "Grumpy Realty" in talk.sales_tip() and "35 percent" in talk.sales_tip(), "Maya names the unhappiest client and the mood")
	sc.book.clear()

	# ---- the owners ask about the number
	talk._who = "Garrison"
	social.rel["Garrison"] = 30
	_check("percent" in talk.sales_answer("Garrison") and "{" not in talk.sales_tip(), "Garrison answers with the number")
	sc.q_signed[0] = sc.quota_target(0)
	_check(not sc.behind_pace() and "ahead" not in talk.sales_answer("Alan") and "pipe" in talk.sales_answer("Garrison").to_lower(), "ahead of pace: a different answer")
	sc.q_signed[0] = 0
	c.day = 6
	talk._who = "Alan"
	social.rel["Alan"] = 30
	sc.clawbacks = 1
	_check("clawbacks" in talk.sales_tip(), "Alan asks why you lost a commission")
	sc.clawbacks = 0

	# ---- small talk is in Vic's world, not about Vic
	talk._who = "Garrison"
	var pools_ok := true
	for p in people:
		talk._who = p
		social.rel[p] = 30
		for _i in 6:
			var line: String = talk.small_talk()
			if "I heard Vic" in line:
				pools_ok = false
	_check(pools_ok, "no coworker gossips to Vic about Vic")
	var small_ok := true
	for p in people:
		var fresh := 0
		for line in talk.VIC_SMALL[p]:
			if not (line in talk.DEFAULT_SMALL[p]):
				fresh += 1
		if fresh < 2:
			small_ok = false
	_check(small_ok and talk.VIC_SMALL.has("Maya") and talk.VIC_TIPS.has("Dan"), "the sales lines are their own tables (VIC_SMALL, VIC_TIPS)")
	var cold_tip: String
	social.rel["Dan"] = -30
	talk._who = "Dan"
	cold_tip = talk.sales_tip()
	_check("That is all you are getting." in cold_tip, "a cold coworker is curt")

	# ---- tech mode keeps its own voices
	c.mode = "tech"
	talk._who = "Dan"
	social.rel["Dan"] = 0
	_check(talk._greeting("Dan") == str(talk.GREETINGS.Dan.neutral), "the tech campaign still greets with the tech lines")
	talk._menu("x")
	_check(str(cards.options[1].label) != "CAN YOUR CREW TAKE ANOTHER CLIENT?", "and still has its own menu")
	_clear(cards)
	c.mode = "sales"

	# ---- Lynk
	lync.reset()
	lync.pending.clear()
	var texts := []
	for k in lync.VIC_MESSAGES:
		texts.append(str(lync.VIC_MESSAGES[k].text))
	var got := 0
	for who in people:
		world.chars[who].scene = "main_floor"
		world.chars[who].legs = []
	for _i in 12:
		lync.reset()
		lync.incoming()
		for who in lync.chats:
			var msg: String = str(lync.chats[who][-1][1])
			if texts.has(msg):
				got += 1
			elif "The backup vendor" in msg or "print spooler" in msg:
				got -= 100
	_check(got >= 6, "incoming messages come from the sales table (%d of 12)" % got)
	lync.reset()
	lync.incoming("help")
	var who_h := ""
	for who in lync.pending:
		who_h = who
	_check(who_h != "" and lync.pending[who_h].has("options") and lync.VIC_MESSAGES.has("help"), "a coworker asks you something in a sales voice (%s)" % who_h)
	if who_h != "":
		var s0: int = social.value(who_h)
		lync.reply(who_h, 0)
		_check(social.value(who_h) > s0, "the first reply makes them like you")
	# NEED A HAND = their view of delivery, not a ticket fix
	lync.reset()
	var before_tickets: int = msp.open_tickets().size()
	social.rel["Dan"] = 40
	lync._lend_a_hand("Dan")
	var last: String = str(lync.chats["Dan"][-1][1])
	_check("Capacity" in last or "take one" in last or "Not this week" in last or "Maybe" in last, "NEED A HAND to Dan answers about capacity: " + last.left(40))
	_check(msp.open_tickets().size() == before_tickets, "and fixes no ticket")
	lync.send_action("Morgan", "help")
	_check(lync.chats.has("Morgan") and not lync.chats["Morgan"].is_empty(), "asking Morgan is answered from the book")
	# presence
	sc.pending_handover = 5
	var pm: Array = lync.presence("Morgan")
	_check(str(pm[0]) in ["WAITING: HANDOVER", "AWAY", "AVAILABLE", "IN A CLIENT CALL"], "Morgan's presence is a sales one (%s)" % str(pm[0]))
	_check(lync.VIC_PRESENCE.handover[0] == "WAITING: HANDOVER" and lync._vic_presence("Morgan", "work")[0] == "WAITING: HANDOVER", "a handover waiting shows as WAITING: HANDOVER")
	sc.pending_handover = 0
	_check(lync._vic_presence("Dan", "meeting")[0] == "IN A CLIENT CALL", "a meeting is a client call in this job")
	# friend warning text
	c.mode = "sales"
	_check(str(lync.VIC_MESSAGES.warn.text).contains("#%d"), "the SLA heads-up is written for a salesman")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
