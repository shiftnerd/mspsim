extends SceneTree
# gdlint:disable=max-line-length
# R38 P6: the light touches. Forum threads and IRC lines gated by the rap sheet (needs: rap:<rival>:<habit>), the Talk and Lynk lines
# that follow the rival, the Standard band and the conscience band (words only), the freezer bag tip, the runbook note, the career
# counters and medals, and Year 2 (the Standard at 60 percent, a new rival name). Headless.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fresh(c: Node, cards: Node, o: Node) -> void:
	c.new_game("owner")
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1
	c.day = 6
	o.flags = {}
	o.habits = {}
	o.skel = []
	o.consc = 0


func _rap_threads(nerds: Node) -> Array:
	var out := []
	for i in nerds.THREADS.size():
		if str(nerds.THREADS[i].get("needs", "")).begins_with("rap:"):
			out.append(i)
	return out


func _visible(nerds: Node) -> int:
	var n := 0
	for i in _rap_threads(nerds):
		n += 1 if nerds.thread_visible(i) else 0
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var nerds := root.get_node("Nerds")
	var career := root.get_node("Career")
	var yt := root.get_node("Yeartwo")
	var sk := root.get_node("Skills")
	var rival: Script = load("res://scripts/rival.gd")
	var habits: Script = load("res://scripts/habits.gd")
	var temp: Script = load("res://scripts/temptation.gd")
	var take: Script = load("res://scripts/takeover.gd")
	var rt: Script = load("res://scripts/rival_touches.gd")
	c.save_prefix = "user://test_rt_%d_" % OS.get_process_id()
	career.toasts = false
	root.get_node("Game").title_mode = false
	_fresh(c, cards, o)

	# ---- the forum threads and IRC lines
	var ids := _rap_threads(nerds)
	_check(ids.size() >= 10, "ten or more rap: threads (%d)" % ids.size())
	var shape_bad := 0
	for i in ids:
		var th: Dictionary = nerds.THREADS[i]
		if (
			nerds.board(str(th.board)).is_empty()
			or not sk.NAMES.has(str(th.skill))
			or th.posts.size() < 3
		):
			shape_bad += 1
		if nerds.is_question(i):
			shape_bad += 1
	_check(
		shape_bad == 0,
		"every rap: thread has a real board and skill, 3 or more posts, and is never a daily question"
	)
	var amb := 0
	for ex in nerds.AMBIENT:
		if str(ex.get("needs", "")).begins_with("rap:"):
			amb += 1
			for line in ex.lines:
				if not nerds.NICKS.has(str(line[0])):
					amb += 100
	_check(
		amb >= 4 and amb < 100,
		"four or more IRC exchanges need a rap sheet entry, all by channel nicks (%d)" % amb
	)
	var old_banned := [
		"slack",
		"chatgpt",
		"windows 10",
		"windows 11",
		"discord",
		"tiktok",
		"office 365",
		"microsoft teams",
		" mfa",
		" ai "
	]
	var slip := ""
	for i in ids:
		var texts := [str(nerds.THREADS[i].title)]
		for p in nerds.THREADS[i].posts:
			texts.append(str(p.text))
		for t in texts:
			for w in old_banned:
				if (" " + t.to_lower() + " ").contains(w):
					slip += w
	_check(slip == "", "no out of period words in the new threads (%s)" % slip)

	# ---- needs gating
	_check(_visible(nerds) == 0, "a fresh game shows none of the rap: threads")
	_check(
		not rt.needs_ok("rap:bigcheese:R11") and not rt.needs_ok("went") and not rt.needs_ok(""),
		"needs_ok is false with no entry and for other needs"
	)
	rival.set_rap("bigcheese", "R11", rival.RUMOUR)
	var after_r11 := _visible(nerds)
	_check(after_r11 == 2, "a RUMOUR of R11 opens exactly its two threads (%d)" % after_r11)
	_check(
		rt.needs_ok("rap:bigcheese:R11") and not rt.needs_ok("rap:bigcheese:R11:2"),
		"a level can be asked for (rap:...:2 needs SEEN)"
	)
	rival.set_rap("bigcheese", "R11", rival.SEEN)
	_check(
		rt.needs_ok("rap:bigcheese:R11:2") and not rt.needs_ok("rap:bigcheese:R11:3"),
		"SEEN passes level 2, not 3"
	)
	_check(
		nerds._eligible("rap:bigcheese:R11") and not nerds._eligible("rap:bigcheese:R01"),
		"the IRC condition follows the rap sheet"
	)
	var shown := 0
	for b in nerds.BOARDS:
		for t in nerds.board_threads(str(b.id)):
			shown += 1 if ids.has(int(t)) else 0
	_check(shown == 2, "the boards list only the visible rap: threads (%d)" % shown)
	for h in ["R01", "R02", "R04", "R05", "R06"]:
		rival.set_rap("bigcheese", h, 1)
	_check(
		_visible(nerds) >= 10,
		"with R01 R02 R04 R05 R06 R11 known the ten rap: threads are open (%d)" % _visible(nerds)
	)
	var posts: Array = nerds.thread_posts(int(ids[0]))
	_check(
		posts.size() >= 3 and str(posts[0].by) != "", "an opened thread has its posts with times"
	)
	nerds.irc_open()
	_check(
		nerds.channel.size() >= 1, "the IRC channel still fills up with the new exchanges around"
	)

	# ---- the state and the lines
	_fresh(c, cards, o)
	_check(
		rt.state_key() == "" and rt.talk_line("Alan") == "" and rt.marge_line() == "",
		"a clean new game says nothing"
	)
	rival.set_rap("bigcheese", "R11", 1)
	_check(rt.state_key() == "bare", "the rival known and a bare Standard: bare")
	for who in ["Alan", "Garrison", "Dan", "Maya", "Vic"]:
		for key in ["rival", "bare", "solid", "showcase", "loose", "closet"]:
			if str(rt.TALK.get(who, {}).get(key, "")) == "":
				_check(false, "TALK has %s / %s" % [who, key])
	for who in ["Alan", "Garrison", "Dan", "Maya", "Vic", "Marge"]:
		for key in ["rival", "solid", "loose", "closet"]:
			if str(rt.LYNK.get(who, {}).get(key, "")) == "":
				_check(false, "LYNK has %s / %s" % [who, key])
	_check(
		rt.talk_line("Alan") != "" and rt.talk_line("Vic") != "" and rt.talk_line("Nobody") == "",
		"everyone at a desk has a line about the rival"
	)
	for id in habits.HABITS:
		habits.start(str(id))
	_check(
		rt.state_key() == habits.band().to_lower(),
		"all the habits fresh: the Standard band speaks (%s)" % habits.band()
	)
	o.habits = {}
	for id in ["H1", "H2", "H3", "H4", "H5", "H6"]:
		habits.start(id)
	var band: String = habits.band()
	var want := (
		band.to_lower()
		if band in ["SOLID", "SHOWCASE"]
		else ("bare" if habits.standard() < 35 else "rival")
	)
	_check(rt.state_key() == want, "a middling Standard (%s): %s" % [band, rt.state_key()])
	o.consc = -2
	_check(
		rt.state_key() == "loose" and temp.band() == "A FEW LOOSE ENDS", "a few loose ends: loose"
	)
	o.consc = -8
	_check(
		rt.state_key() == "closet", "skeletons: closet (the conscience speaks before the Standard)"
	)
	var text: String = rt.marge_line()
	_check(
		text != "" and not text.contains("-8") and not text.contains("8"),
		"Marge says it in words, no number (%s)" % text.left(30)
	)
	o.consc = -2

	# Lynk: a note from someone, once, then quiet for a while
	o.flags = {}
	var people: Array = ["Alan", "Garrison", "Dan", "Vic", "Maya"]
	var first: Array = rt.lynk_note(people, "Marge", 3)
	_check(
		first.size() == 2 and str(rt.LYNK[first[0]].loose) == str(first[1]),
		"a note is [who, the loose-ends line]"
	)
	var said := [str(first[0])]
	for k in 10:
		var more: Array = rt.lynk_note(people, "Marge", k)
		if more.is_empty():
			break
		_check(
			not said.has(str(more[0])), "nobody repeats a note within %d weeks" % rt.SAME_AGAIN_DAYS
		)
		said.append(str(more[0]))
	_check(
		said.size() == 6 and rt.lynk_note(people, "Marge", 1).is_empty(),
		"six people spoke once, then nothing"
	)
	c.day += rt.SAME_AGAIN_DAYS + 1
	_check(
		not rt.lynk_note(people, "Marge", 1).is_empty(), "after a few weeks they may speak again"
	)

	# the live Lynk and Talk hooks
	var lync := root.get_node("Lync")
	lync.reset()
	o.flags = {}
	var got := false
	for k in 60:
		lync.incoming()
		for who in lync.chats:
			for line in lync.chats[who]:
				if (
					str(line[0]) != "me"
					and rt.LYNK.has(str(who))
					and str(rt.LYNK[who].loose) == str(line[1])
				):
					got = true
		if got:
			break
	_check(got, "Lync.incoming() in the owner campaign delivers a rival and habit note")
	lync._boss_reply("Marge")
	var last := str(lync.chats["Marge"][-1][1])
	_check(
		last.contains("Cash is") and last.contains(str(rt.LYNK.Marge.loose)),
		"Marge adds a sentence about the folder to HOW ARE WE DOING"
	)

	# the freezer bag tip, the runbook note
	_check(
		(
			rt.freezer_tip("Alan", "tech", 0.1).contains("freezer bag")
			and rt.freezer_tip("Dan", "tech", 0.1) != ""
		),
		"Alan and Dan tell the freezer bag tip in the tech campaign"
	)
	_check(
		(
			rt.freezer_tip("Alan", "tech", 0.9) == ""
			and rt.freezer_tip("Alan", "owner", 0.1) == ""
			and rt.freezer_tip("Garrison", "tech", 0.1) == ""
		),
		"rarely, only in the tech campaign, only those two"
	)
	_check(
		(
			rt.runbook_note("restore") != ""
			and rt.runbook_note("av") != ""
			and rt.runbook_note("spooler") == ""
		),
		"the green dashboard note is on the restore and antivirus runbooks only"
	)

	# ---- the career
	var keys := []
	for row in career.COUNTERS:
		keys.append(str(row[2]))
	for k in rt.COUNTERS:
		_check(keys.has(k), "the career screen lists the counter %s" % k)
	var medal_ids := []
	for m in career.MEDALS:
		medal_ids.append(str(m.id))
		if str(m.desc).length() > 30:
			_check(false, "medal description too long: " + str(m.desc))
	for id in ["habit_forming", "spring_cleaning", "cleanup_crew", "clean_sheet"]:
		_check(medal_ids.has(id), "medal " + id)
	career.reset_all()
	_fresh(c, cards, o)
	habits.start("H1")
	habits.start("H1")
	habits.adopt("H2")
	_check(
		career.value("habits_adopted") == 2,
		"two habits adopted count two (a repeat does not) (%d)" % career.value("habits_adopted")
	)
	habits.start("H3")
	habits.start("H4")
	_check(not career.has_medal("habit_forming"), "four habits are not the medal")
	habits.start("H5")
	_check(career.has_medal("habit_forming"), "the fifth habit earns HABIT FORMING")
	temp.add_skeleton("temp_seats", 5)
	temp.add_skeleton("temp_reboot", 5)
	o.cash = 5000
	_check(
		temp.come_clean("temp_seats") and career.value("skeletons_paid") == 1,
		"coming clean counts a skeleton paid"
	)
	temp.week(o)
	c.day = 20
	temp.week(o)
	_check(career.value("skeletons_paid") == 2, "a bill that arrives counts too")
	take.begin(0, 6)
	take.begin(1, 6)
	_check(career.value("takeovers") == 2, "each takeover assessment counts")
	var rows_before: int = career.value("clean_sheets")
	_check(
		rt.note_year_end() and career.value("clean_sheets") == rows_before + 1,
		"a year that ends with no skeletons and clean books is a clean sheet"
	)
	temp.add_skeleton("temp_price", 9)
	_check(not rt.note_year_end(), "an open skeleton is not a clean sheet")

	# ---- Year 2
	_fresh(c, cards, o)
	_check(rt.carry_habits(0).is_empty(), "no Standard last year, nothing carries")
	var total := 0
	for id in rt.carry_habits(100):
		total += int(habits.HABITS[id].weight)
	_check(total <= 60 and total >= 50, "100 last year carries about 60 (%d)" % total)
	var old_name := str(rival.RIVALS.bigcheese.name)
	rt.rival_year(2)
	_check(str(rival.RIVALS.bigcheese.name) == "HARD RIND IT", "Year 2 renames the rival")
	rival.set_rap("bigcheese", "R11", 1)
	_check(
		rival.line("bigcheese").begins_with("HARD RIND IT"),
		"the rap sheet line carries the new name"
	)
	yt.reset()
	_check(
		str(rival.RIVALS.bigcheese.name) == old_name,
		"Yeartwo.reset puts the old name back (%s)" % rival.RIVALS.bigcheese.name
	)
	var before: int = career.value("habits_adopted")
	o.habits = {}
	var started: Array = rt.year2_begin({"standard": 80})
	_check(
		not started.is_empty() and habits.standard() <= 48 and habits.standard() >= 36,
		"a Standard of 80 comes back as about 48 (%d)" % habits.standard()
	)
	_check(career.value("habits_adopted") == before, "carried habits are not new adoptions")
	var meta := ConfigFile.new()
	yt.record(meta, "owner", "test")
	_check(
		int(meta.get_value("owner", "standard", -1)) == habits.standard(),
		"the meta record keeps the Standard for the next run"
	)
	yt.prev = {"standard": 80}
	yt.carried = {"rep": 50, "cash": 0, "skills": {}, "ps": 0, "habits": started}
	var intro: String = yt.intro_text()
	_check(
		intro.contains("60 PERCENT") and intro.contains("HARD RIND"),
		"the Year 2 intro card says what carries and who the new rival is"
	)
	_check(yt.TEXT.habits.rival.name == "HARD RIND IT", "the Year 2 note lives in Yeartwo.TEXT")

	# ---- docs
	var manual := ProjectSettings.globalize_path("res://").path_join(
		"../docs/manual/09-credits-and-legal.md"
	)
	if FileAccess.file_exists(manual):
		_check(
			FileAccess.get_file_as_string(manual).contains("backups in freezer bags"),
			"the manual credits the satirical MSP blog under Special thanks"
		)
	rival.RIVALS.bigcheese.name = old_name
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
