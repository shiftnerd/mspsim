extends SceneTree
# gdlint:disable=max-line-length
# R6 dinner variety (Outings, a dinner started with options.variety): the ordering round and dietary quirks (D4), a client at the
# table (D5), the boss picking up the tab in the tech campaign (D6), table events (D7), the talk after a three star dinner (D8),
# ASK HOW THEY ARE and the "as of outing n" marks (D2). Also checks that a dinner without the option is the classic one, that
# every draw is seeded, and (a small simulation) that best play still beats careless play.
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/dinner_variety.gd`

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _start(o: Node, extra := {}) -> void:
	if o.is_open:
		o.close()
	var options := {"party": ["Alan", "Garrison", "Dan"], "variety": true}
	options.merge(extra, true)
	o.start("dinner", false, options)
	o.begin_play()


func _clear(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 40:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _fit_index(o: Node) -> int:
	for i in 4:
		if o.dish_clash(str(o.g.order.plates[i])).is_empty():
			return i
	return -1


func _clash_index(o: Node) -> int:
	for i in 4:
		if not o.dish_clash(str(o.g.order.plates[i])).is_empty():
			return i
	return -1


# one variety dinner on a seed: best play (the plate that suits everyone, then the best topic each round) or careless picks
func _sim(o: Node, d: Node, seed_n: int, best: bool, table: Array) -> int:
	d.seed_run(seed_n)
	o.reset()
	_start(o, {"party": table})
	var r: RandomNumberGenerator = d.rng_for("sim", seed_n)
	o.dinner_order(maxi(0, _fit_index(o)) if best else r.randi_range(0, 3))
	for round_no in 5:
		var pick := r.randi_range(0, 3)
		if best:
			var top := -1
			for i in 4:
				var pts := 0
				for who in o.diners():
					pts += o.diner_points(who, o.g.options[i])
				if pts > top:
					top = pts
					pick = i
		o.dinner_talk(pick)
		o.tick(4.0)
	var result: int = o.stars
	o.press(KEY_ENTER)
	return result


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var sales := root.get_node("Sales")
	var career := root.get_node("Career")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	career.reset_all()
	o.enabled = true
	c.new_game("free")
	root.get_node("World").time_scale = 1.0
	d.set_tier("normal")

	# ---- a dinner without the option is the classic one
	d.seed_run(77)
	o.reset()
	o.start("dinner")
	o.begin_play()
	var classic: Array = o.g.options.duplicate()
	_check(not o.g.has("order") and not o.dinner_ordering() and o.dinner_rows() == o.g.options, "no option: no ordering round")
	_check(not classic.has(o.ASK_TOPIC) and o.dinner_guest().is_empty(), "no option: the classic four topics, nobody extra at the table")
	o.close()
	d.seed_run(77)
	o.reset()
	_start(o)
	var same_rest := true
	for i in [0, 2, 3]:
		same_rest = same_rest and str(o.g.options[i]) == str(classic[i])
	_check(same_rest and str(o.g.options[1]) == o.ASK_TOPIC, "with the option the classic deal is kept and ASK HOW THEY ARE takes one slot")

	# ---- D4: the ordering round
	_check(o.dinner_ordering() and o.g.order.plates.size() == 4, "the dinner opens with four shared plates")
	var fits := 0
	for id in o.g.order.plates:
		fits += 1 if o.dish_clash(str(id)).is_empty() else 0
	_check(fits == 2, "normal tier: two of the four suit everybody (%d)" % fits)
	_check(o.dinner_rows().size() == 4 and str(o.dinner_rows()[0]) == str(o.dish(str(o.g.order.plates[0])).label), "the list shows the plates while you order")
	var plates_a: Array = o.g.order.plates.duplicate()
	d.seed_run(77)
	o.reset()
	_start(o)
	_check(o.g.order.plates == plates_a, "the same seed deals the same plates")
	var widest := true
	for dish in o.DISHES:
		widest = widest and str(dish.label).length() <= 19
	_check(widest, "every plate name fits the list (19 letters)")
	for who in o.DIETS:
		var hits := 0
		for dish in o.DISHES:
			hits += 1 if dish.has.has(o.DIETS[who]) else 0
		_check(hits >= 2 and o.DIET_TEXT.has(o.DIETS[who]), "%s: %s, on %d plates" % [who, o.DIET_TEXT[o.DIETS[who]], hits])
	var any_table := true
	for table in [["Alan"], ["Alan", "Garrison", "Dan", "John", "Maya"], ["Garrison", "Dan", "John", "Maya", "Morgan"]]:
		_start(o, {"party": table})
		any_table = any_table and _fit_index(o) >= 0 and _clash_index(o) >= 0
	_check(any_table, "every table gets at least one plate that suits it and one that does not")
	_start(o)
	var score0: int = o.g.score
	_check(o.dinner_order(_fit_index(o)) == o.ORDER_BONUS and int(o.g.score) == score0 + 2 and not o.dinner_ordering(), "a plate that suits everybody: table +2, on to the topics")
	_check(o.dinner_rows() == o.g.options, "then the list shows the topics")
	_start(o)
	var bad := _clash_index(o)
	var who_out: Array = o.dish_clash(str(o.g.order.plates[bad]))
	o.g.sel = bad
	o.press(KEY_ENTER)  # the key path: ENTER orders the highlighted plate
	var learned: Dictionary = o.known.get(who_out[0], {})
	_check(int(o.g.score) == 0 and str(learned.get("diet", "")) == str(o.DIETS[who_out[0]]) and int(learned.get("diet_since", 0)) == 1, "a plate somebody cannot eat: no bonus, and you learn it (%s: %s)" % [who_out[0], str(learned.get("diet", ""))])
	_check(str(o.known_notes(who_out[0])).contains("AS OF OUTING 1"), "the note is marked as of outing 1: %s" % str(o.known_notes(who_out[0])))
	_check(o._dish_known_clash(str(o.g.order.pick)), "next time that plate is ticked on the list")
	_start(o)
	var topic0: String = str(o.g.options[0])
	o.dinner_talk(0)
	_check(not o.dinner_ordering() and o.g.picked == [topic0], "a test that talks straight away skips the plate")

	# ---- D2: what you learn is marked, ASK HOW THEY ARE confirms or corrects it
	d.seed_run(31)
	o.reset()
	_start(o)
	o.dinner_order(0)
	var ask_at: int = o.g.options.find(o.ASK_TOPIC)
	_check(ask_at == 1, "ASK HOW THEY ARE is on the list in round 1")
	var total: int = o.dinner_talk(ask_at)
	var neutral := 0
	for who in o.diners():
		neutral += o.diner_points(who, o.ASK_TOPIC)
	_check(total == neutral and o.g.asked, "asking is a neutral answer for everybody (%d)" % total)
	var knew := 0
	for who in o.known:
		knew += o.known[who].likes.size()
	_check(knew == 1 and str(o.g.note).contains("FAVOURITE"), "nobody changed, so somebody tells you a favourite subject: %s" % str(o.g.note))
	o.tick(4.0)
	_check(not o.g.options.has(o.ASK_TOPIC), "it is asked once a dinner")
	# a taste drifts between outings: the stale note is corrected by asking
	var drifted := false
	for seed_n in range(200, 260):
		d.seed_run(seed_n)
		o.reset()
		o.count = 2
		var first_love: String = str(o.taste("Alan").loves[0])
		o.known = {"Alan": {"likes": [first_love], "hates": [], "since": {first_love: 1}}}
		_start(o)
		if o.g.drift.has("Alan"):
			drifted = true
			var now_love: String = str(o.g.drift.Alan.now)
			_check(not o.taste("Alan").loves.has(first_love) and o.taste("Alan").loves.has(now_love), "seed %d: Alan went off %s, it is %s now" % [seed_n, first_love, now_love])
			_check(o.known.Alan.likes.has(first_love), "your note is stale until you find out")
			o.dinner_talk(o.g.options.find(o.ASK_TOPIC))
			_check(not o.known.Alan.likes.has(first_love) and o.known.Alan.likes.has(now_love) and int(o.known.Alan.since[now_love]) == 3, "asking corrects it, as of outing 3")
			_check(str(o.g.note).contains("GONE OFF"), "and says so: %s" % str(o.g.note))
			break
	_check(drifted, "a known taste drifts on some seeds")
	var quiet := 0
	for seed_n in range(200, 240):
		d.seed_run(seed_n)
		o.reset()  # the first outing: nothing to go stale
		_start(o)
		quiet += 1 if o.g.drift.is_empty() else 0
	_check(quiet == 40, "nothing drifts on a first outing")
	# a like that no longer gets a smile is struck off; a confirmed one gets tonight's mark
	d.seed_run(31)
	o.reset()
	o.count = 4
	var alan_love: String = str(o.taste("Alan").loves[0])
	o.known = {"Alan": {"likes": [alan_love, "COMMUTE"], "hates": []}}
	o.start("dinner")
	o.begin_play()
	o.g.options[0] = alan_love
	o.g.options[1] = "COMMUTE"
	o.dinner_talk(0)
	o.tick(2.0)
	o.g.options[1] = "COMMUTE"
	o.dinner_talk(1)
	_check(int(o.known.Alan.since[alan_love]) == 5 and not o.known.Alan.likes.has("COMMUTE"), "a note from an old save gets a mark when it is confirmed, a wrong one is struck off")
	_check(o._with_marks(o.known.Alan, o.known.Alan.likes) == ["%s (5)" % alan_love], "the table list shows the mark: %s" % str(o._with_marks(o.known.Alan, o.known.Alan.likes)))
	_check(str(o.dinner_brief()).contains("YOU KNOW: ALAN LIKES %s (5)" % alan_love), "the intro page says what you know: %s" % str(o.dinner_brief()))
	o.close()

	# ---- D5: a client at the table
	d.seed_run(12)
	o.reset()
	_start(o, {"guest": 0})
	var guest: Dictionary = o.dinner_guest()
	_check(str(guest.name) == str(root.get_node("Msp").CLIENTS[0].contact) and o.GUEST_TOPICS.has(str(o.g.options[2])), "the guest is at the table and brings a subject (%s)" % str(o.g.options[2]))
	_check(o._dinner_open_line().contains(str(guest.name).to_upper()), "sitting down names the guest")
	o.dinner_order(0)
	var crew_pts := 0
	for who in o.diners():
		crew_pts += o.diner_points(who, "TALKING SHOP")
	o.g.options[0] = "TALKING SHOP"
	_check(o.dinner_talk(0) == crew_pts + 1 and int(guest.mood) == 1, "talking shop: the guest joins in (+1)")
	o.tick(4.0)
	o.g.options[0] = "TALKING SHOP"
	o.dinner_talk(0)
	o.tick(4.0)
	o.g.options[0] = "TALKING SHOP"
	_check(o.dinner_talk(0) == crew_pts - 1 and int(guest.mood) == 1, "the third round of shop talk is one too many (-1)")
	o.tick(4.0)
	o.g.options[0] = "THE SALES PITCH"
	o.dinner_talk(0)
	_check(int(guest.mood) == -1 and str(o.g.note).contains("PITCH"), "a pitch at dinner costs two: %s" % str(o.g.note))
	o.tick(4.0)
	o.g.options[0] = "HOW IS BUSINESS"
	o.dinner_talk(0)
	_check(int(guest.mood) == 0, "asking about their business helps once")
	o.close()
	# the result moves the client's mood (a campaign)
	c.new_game("tech")
	_clear(cards)
	c.day = 5
	d.seed_run(12)
	o.reset()
	_start(o, {"guest": 0})
	o.dinner_order(0)
	o.g.options[0] = "WORK DRAMA"
	o.dinner_talk(0)
	_check(int(o.dinner_guest().mood) == -1 and str(o.g.note).contains("LAUNDRY"), "a sore subject in front of a client is awkward")
	o.dinner_guest().mood = 3
	var mood0: int = sales.mood(0)
	o._finish(2)
	_check(sales.mood(0) == mood0 + 4 and str(o.lines).contains("HAD A GOOD NIGHT"), "a good evening lifts the client's mood by up to 4 (%d to %d)" % [mood0, sales.mood(0)])
	o.press(KEY_ENTER)
	var came := 0
	for seed_n in range(500, 600):
		d.seed_run(seed_n)
		o.reset()
		_start(o)
		came += 0 if o.dinner_guest().is_empty() else 1
	_check(came >= 25 and came <= 55, "tech campaign: a client comes along to about 40%% of the team dinners (%d of 100)" % came)
	o.close()

	# ---- D7: table events
	c.new_game("free")
	d.seed_run(40)
	o.reset()
	_start(o)
	o.dinner_order(0)
	o.dinner_talk(0)
	var line: String = o.dinner_event("phone", "Alan")
	_check(line.contains("ALAN") and str(o.g.line) == line, "an event is a one-line caption: %s" % line)
	o.g.events.append_array(o.TABLE_EVENTS.keys())  # no random event on top of this one
	o.tick(4.0)
	_check(o.g.options.has("VENDOR STORIES") and o.g.event.is_empty(), "the phone call puts VENDOR STORIES on the next list")
	o.dinner_talk(0)
	o.dinner_event("glass")
	o.tick(4.0)
	var traps := 0
	for id in o.g.options:
		traps += 1 if o.is_trap(str(id)) else 0
	_check(traps == 0, "after the dropped glass there is no sore subject on the list")
	o.dinner_talk(0)
	o.dinner_event("toast", "Dan")
	o.tick(4.0)
	var dan_love := false
	for id in o.g.options:
		dan_love = dan_love or o.taste("Dan").loves.has(str(id))
	_check(dan_love, "after Dan's toast a subject Dan loves is on the list")
	var seen := {}
	var most := 0
	var repeat_ok := true
	for seed_n in range(700, 760):
		var runs := []
		for again in 2:
			d.seed_run(seed_n)
			o.reset()
			_start(o)
			o.dinner_order(0)
			for round_no in 4:
				o.dinner_talk(0)
				o.tick(4.0)
			runs.append(o.g.events.duplicate())
		repeat_ok = repeat_ok and runs[0] == runs[1]
		most = maxi(most, runs[0].size())
		for id in runs[0]:
			seen[id] = true
	_check(repeat_ok, "the same seed has the same table events")
	_check(most == o.EVENT_MAX and seen.size() == o.TABLE_EVENTS.size(), "at most %d a dinner, and every event turns up (%d kinds)" % [o.EVENT_MAX, seen.size()])
	for id in o.TABLE_EVENTS:
		var row: Dictionary = o.TABLE_EVENTS[id]
		_check(str(row.text).length() <= 110 and ["notrap", "love", "topic"].has(str(row.fx)) and (str(row.fx) != "topic" or o.topic_ids().has(str(row.topic))), "event %s is a short line with a known effect" % id)
	o.close()

	# ---- D6: the boss picks up the tab (tech campaign, day 15)
	c.new_game("tech")
	_clear(cards)
	c.day = 14
	d.seed_run(9)
	o.reset()
	o.start("dinner", false, {"party": ["Alan", "Garrison", "Dan"], "variety": true})
	_check(not o.tab_due(), "no tab on another day")
	o.close()
	c.day = o.TAB_DAY
	o.start("dinner", false, {"party": ["Alan", "Garrison", "Dan"], "variety": true})
	_check(o.tab_due(), "day 15: the tab is on the company")
	var garrison0: int = social.value("Garrison")
	o.press(KEY_ENTER)
	_check(cards.is_open and str(cards.speaker).begins_with("Garrison") and cards.options.size() == 3, "ENTER on the intro: Garrison's card")
	cards.pick(1)  # the steaks
	_check(o.phase == "play" and str(o.g.budget) == "fancy" and o.diner_shift("Dan") >= 0 and social.value("Garrison") == garrison0 - 1, "steaks: the fancy table, and Garrison noticed")
	o._finish(2)
	_check(str(o.lines).contains("PAID AND READ THE RECEIPT"), "the result page says who paid")
	o.press(KEY_ENTER)
	o.start("dinner", false, {"party": ["Alan", "Garrison", "Dan"]})
	_check(not o.tab_due(), "a dinner without the option has no tab card")
	o.close()

	# ---- D8: the talk after a three star dinner
	c.day = 5
	d.seed_run(9)
	o.reset()
	social.change("Dan", -3)
	_start(o)
	_check(o.talk_who() == "Dan", "the person who likes you least stays behind")
	o.dinner_order(0)
	for round_no in 5:
		o.g.score = 99
		o.dinner_talk(0)
		o.tick(4.0)
	_check(o.phase == "result" and o.stars == 3 and o.talk_due(), "three stars: a talk is due")
	var dan0: int = social.value("Dan")
	var dan_knew: int = o.known.get("Dan", {}).get("likes", []).size()
	o.press(KEY_ENTER)
	_check(cards.is_open and cards.speaker == "Dan" and o.is_open, "ENTER on the result page: Dan has something to say")
	cards.pick(0)  # stay and listen
	_check(social.value("Dan") == dan0 + 2 and o.talks == 1 and not o.is_open, "listening: Dan likes you 2 more and the evening ends")
	_check(o.known.Dan.likes.size() == dan_knew + 1, "and he tells you something he loves")
	_clear(cards)
	d.seed_run(9)
	_start(o)
	o.dinner_order(0)
	o._finish(2)
	o.press(KEY_ENTER)
	_check(not cards.is_open and not o.is_open, "two stars: no talk, the page just closes")
	for who in ["Alan", "Garrison", "Dan", "John", "Maya", "Morgan", "_"]:
		var row: Dictionary = o.POST_TALKS.get(who, {})
		_check(row.has("text") and row.has("listen") and row.has("advise"), "a talk is written for %s" % who)

	# ---- saving
	var data: Dictionary = o.to_dict()
	var known_before: String = str(o.known)
	o.reset()
	o.from_dict(data)
	_check(o.talks == 1 and str(o.known) == known_before, "the talks and the marks are saved")

	# ---- best play still beats careless play
	c.new_game("free")
	career.reset_all()
	for size in [3, 5]:
		var table: Array = ["Alan", "Garrison", "Dan", "John", "Maya"].slice(0, size)
		var dist := {"best": [0, 0, 0, 0], "random": [0, 0, 0, 0]}
		for seed_n in 120:
			dist.best[_sim(o, d, 4000 + seed_n, true, table)] += 1
			dist.random[_sim(o, d, 4000 + seed_n, false, table)] += 1
		print("variety table of %d  best stars 0-3: %s  random: %s" % [size, str(dist.best), str(dist.random)])
		_check(dist.best[2] + dist.best[3] >= 108, "table of %d, best play: 2+ stars in 90%%+ of 120 dinners" % size)
		_check(dist.best[3] > dist.random[3] and dist.random[3] <= 36, "table of %d: careless picks get 3 stars far less often" % size)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
