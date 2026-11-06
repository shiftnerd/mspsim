extends SceneTree
# Lynk 2013 (presence, messages, friend warnings, the boss) and LabRat Nerds (forum karma, the
# IRC call-a-friend poll, its accuracy and cooldown). Headless.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var lync := root.get_node("Lync")
	var nerds := root.get_node("Nerds")
	var world := root.get_node("World")
	var social := root.get_node("Social")
	var msp := root.get_node("Msp")
	var sk := root.get_node("Skills")
	var pb := root.get_node("Playbook")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")

	# ---- Lync: presence comes from what the cast is doing
	_check(
		lync.boss() == "Morgan" and lync.contacts().has("Morgan") and lync.contacts().size() == 6,
		"contacts: the cast plus Morgan"
	)
	world.chars["Alan"].legs = [{"kind": "work"}]
	world.chars["Alan"].scene = "office_one"
	_check(lync.presence("Alan")[0] == "AVAILABLE", "Alan at his desk: available")
	world.chars["Alan"].legs = [{"kind": "meeting"}]
	_check(
		lync.presence("Alan")[0] == "IN A MEETING" and lync.presence("Alan")[1] == "red",
		"in a meeting: red"
	)
	world.chars["Alan"].legs = [{"kind": "coffee"}]
	_check(lync.presence("Alan")[0] == "AWAY", "fetching coffee: away")
	world.chars["Alan"].scene = world.OUTSIDE
	_check(lync.presence("Alan")[0] == "OFFLINE", "outside the building: offline")
	world.chars["John"].scene = world.OUTSIDE
	world.clock = 11.0
	_check(lync.presence("John")[0] == "WITH A CLIENT", "John out on a client visit")
	world.chars["Alan"].scene = "office_one"
	world.chars["Alan"].legs = [{"kind": "work"}]
	world.chars["John"].scene = "cubicle_area"
	world.chars["John"].legs = [{"kind": "work"}]

	# ---- incoming messages and your replies
	for n in ["Alan", "Garrison", "Dan", "John"]:
		world.chars[n].scene = world.CAST[n].home
		world.chars[n].legs = [{"kind": "work"}]
	lync.incoming("lunch")
	var asker := ""
	for who in lync.pending:
		asker = who
	_check(
		asker != "" and lync.unread_total() == 1 and lync.pending[asker].options.size() == 2,
		"a coworker messages you about lunch"
	)
	var before: int = social.value(asker)
	lync.reply(asker, 0)
	_check(
		(
			social.value(asker) == before + 2
			and not lync.pending.has(asker)
			and lync.chats[asker].size() == 3
		),
		"saying yes to lunch makes a friend"
	)
	lync.incoming("phones")
	asker = ""
	for who in lync.pending:
		asker = who
	before = social.value(asker)
	lync.reply(asker, 1)
	_check(social.value(asker) == before - 1, "refusing to cover the phones costs a little")
	lync.incoming("help")
	asker = ""
	for who in lync.pending:
		asker = who
	var xp0: int = sk.xp["people"]
	lync.reply(asker, 0)
	_check(sk.xp["people"] == xp0 + 2, "helping a coworker earns customer-skill experience")
	lync.mark_read(asker)

	# ---- your messages
	social.rel["Dan"] = 30
	world.chars["Dan"].legs = [{"kind": "meeting"}]
	lync.send_action("Dan", "lunch")
	_check(
		lync.chats["Dan"][-1][1].contains("meeting"),
		"ask someone in a meeting and you get an auto-reply"
	)
	world.chars["Dan"].legs = [{"kind": "work"}]
	var accepted := 0
	for i in 40:
		social.rel["Dan"] = 30
		lync.chats["Dan"] = []
		lync.send_action("Dan", "lunch")
		accepted += 1 if lync.chats["Dan"][-1][1].begins_with("Sure") else 0
	_check(accepted == 40, "a friend always says yes to lunch")
	social.rel["Garrison"] = -30
	accepted = 0
	for i in 60:
		lync.chats["Garrison"] = []
		lync.send_action("Garrison", "lunch")
		accepted += 1 if lync.chats["Garrison"][-1][1].begins_with("Sure") else 0
	_check(accepted == 0, "someone cold to you says no to lunch")
	msp.reset()
	social.rel["Dan"] = 40
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	lync.send_action("Dan", "help")
	_check(
		msp.ticket(t.id).fix_done and social.value("Dan") == 39,
		"a friend fixes your ticket and says you owe them one"
	)

	# ---- a friend warns you before an SLA breach
	msp.reset()
	var late: Dictionary = msp.create_ticket(1, 1, "test")
	msp.ticket(late.id).sla_left = 20.0
	social.rel["Alan"] = 40
	lync.friend_warning()
	var warned := false
	for who in lync.chats:
		for line in lync.chats[who]:
			warned = warned or str(line[1]).contains("about to breach")
	_check(warned, "a friend warns you the ticket is about to breach its SLA")

	# ---- the boss
	lync.send_action("Morgan", "boss")
	_check(
		lync.chats["Morgan"].size() == 2 and lync.chats["Morgan"][-1][1].length() > 10,
		"Morgan answers: " + str(lync.chats["Morgan"][-1][1])
	)
	c.new_game("owner")
	_check(
		lync.boss() == "Marge" and lync.contacts().has("Marge"),
		"owner campaign: Marge replaces Morgan"
	)
	lync.send_action("Marge", "boss")
	_check(lync.chats["Marge"][-1][1].contains("Cash is $"), "Marge reports the numbers")

	# ---- the desktop apps open and draw
	var comp := root.get_node("Computer")
	comp.open(1)
	comp.activate("app:lync")
	comp.activate("lync:contact:Alan")
	comp.activate("lync:act:thanks")
	_check(comp.app == "lync" and comp.lync_sel == "Alan", "the Lync window opens a chat")
	comp.activate("app:nerds")
	_check(comp.app == "nerds", "the LabRat Nerds window opens")
	comp.close()

	# ---- Nerds: karma and ranks
	c.new_game("tech")
	_check(nerds.karma == 10 and nerds.rank() == "MEMBER", "you start as a MEMBER")
	nerds.karma = 3
	_check(nerds.rank() == "LURKER", "low karma: LURKER")
	nerds.karma = 25
	_check(nerds.rank() == "REGULAR", "25 karma: REGULAR")
	nerds.karma = 45
	_check(
		nerds.rank() == "GURU" and nerds.accuracy_mult() > 1.05,
		"45 karma: GURU, and the nicks are likelier to be right"
	)
	nerds.karma = 10

	# ---- the forum
	nerds.ensure_threads()
	_check(nerds.threads.size() == 5, "five threads a day")
	var xp_before := 0
	for key in ["servers", "security", "networking", "people"]:
		xp_before += int(sk.xp.get(key, 0))
	nerds.read_thread(0)
	var xp_after := 0
	for key in ["servers", "security", "networking", "people"]:
		xp_after += int(sk.xp.get(key, 0))
	_check(
		xp_after == xp_before + 2 and nerds.threads[0].read,
		"reading a thread gives a little experience"
	)
	nerds.threads[1].id = 4  # CryptoLocker: security level 2
	sk.xp["security"] = 0
	var karma0: int = nerds.karma
	_check(
		nerds.answer_thread(1).contains("NOT SURE") and nerds.karma == karma0 - 1,
		"you cannot answer what you do not know"
	)
	sk.xp["security"] = 100
	_check(
		nerds.answer_thread(1).contains("POSTED") and nerds.karma == karma0 + 1,
		"with the skill you can answer: +2 karma"
	)
	_check(nerds.answer_thread(1) == "ALREADY ANSWERED", "once per thread")

	# ---- IRC: call a friend
	nerds.karma = 40
	var right_high := 0
	for i in 300:
		nerds.karma = 40
		nerds._lines = []
		nerds._last_ask = -999.0
		var verdict: Dictionary = nerds.ask("which?", ["A", "B", "C", "D"], 2)
		right_high += 1 if int(verdict.winner) == 2 else 0
	nerds.karma = 5
	var right_low := 0
	for i in 300:
		nerds.karma = 5
		nerds._lines = []
		nerds._last_ask = -999.0
		var verdict2: Dictionary = nerds.ask("which?", ["A", "B", "C", "D"], 2)
		right_low += 1 if int(verdict2.winner) == 2 else 0
	_check(
		right_high > 255 and right_low < right_high,
		(
			"the channel is mostly right, more so for a GURU (%d vs %d of 300)"
			% [right_high, right_low]
		)
	)
	nerds.karma = 10
	nerds._lines = []
	nerds._last_ask = -999.0
	nerds.ask("which?", ["A", "B", "C", "D"], 1)
	_check(
		not nerds.can_ask() and nerds.cooldown_left() > 40.0,
		"there is a cooldown between questions"
	)
	_check(nerds.hint.pending and nerds._lines.size() == 4, "four nicks will answer, one at a time")
	nerds._process(10.0)
	var said := 0
	for line in nerds.channel:
		said += 1 if nerds.NICKS.has(str(line[0])) else 0
	_check(
		said == 4 and not nerds.hint.pending,
		"after a few seconds all four have answered and the verdict is in"
	)
	nerds._last_ask = -999.0
	nerds.karma = 2
	var ignored: Dictionary = nerds.ask("which?", ["A", "B"], 0)
	_check(ignored.get("ignored", false), "nobody answers a lurker")

	# asking about a ticket and about a job step
	nerds.karma = 40
	msp.reset()
	var spool: Dictionary = msp.create_ticket(0, 0, "test")
	nerds._lines = []
	nerds._last_ask = -999.0
	var tv: Dictionary = nerds.ask_ticket(spool)
	_check(not tv.is_empty() and tv.total == 4, "ask about a ticket: a verdict arrives")
	var right_fix := 0
	for i in 200:
		nerds.karma = 40
		nerds._lines = []
		nerds._last_ask = -999.0
		var tv2: Dictionary = nerds.ask_ticket(spool)
		right_fix += 1 if str(tv2.best).contains("SPOOLER") else 0
	_check(right_fix > 160, "the channel usually tells you the right fix (%d of 200)" % right_fix)
	nerds._lines = []
	nerds._last_ask = -999.0
	var none: Dictionary = nerds.ask_step()
	_check(none.is_empty(), "no job running: it tells you to ask about a ticket")
	pb.start("rack")
	nerds._last_ask = -999.0
	var step_verdict: Dictionary = nerds.ask_step()
	_check(
		not step_verdict.is_empty() and str(step_verdict.question).contains("what next"),
		"during a job you can ask what to do at this step"
	)

	# ---- saved
	nerds.karma = 33
	c.day = 5
	c.save()
	c.new_game("free")
	_check(c.continue_game("tech") and nerds.karma == 33, "karma is saved with the campaign")
	DirAccess.remove_absolute(c.save_path("tech"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
