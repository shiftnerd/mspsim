extends SceneTree
# gdlint:disable=max-line-length
# The LabRat Nerds forum overhaul (R27): the data (boards, ~70 threads with posts, period-correct text the pixel font can draw),
# counts that grow with the day, last-post lines, footer statistics and the clock, seeded randomness, posting (karma, rank,
# signature, your post in the thread, the correction, cozy Easy), the newest member, the tie-ins (PowerShell, dashboards, vendors),
# navigation by keys and by mouse, and the screens at wide, h and v (nothing drawn outside the screen). Headless.

const PixelFont := preload("res://scripts/pixelfont.gd")

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var nerds := root.get_node("Nerds")
	var sk := root.get_node("Skills")
	var diff := root.get_node("Difficulty")
	var expo := root.get_node("Expo")
	var comp := root.get_node("Computer")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	c.new_game("tech")

	# ---- the data
	var boards: Array = nerds.BOARDS
	_check(boards.size() == 18, "18 boards (two are sub-forums of the Plugin Sandbox)")
	var ids := []
	for b in boards:
		ids.append(str(b.id))
	_check(
		(
			ids.has("scripts")
			and ids.has("vendor")
			and ids.has("vip")
			and ids.has("dash")
			and ids.has("tabs")
		),
		"Script Swap, Vendor Lounge, VIP Area, Dashboards and Custom Tabs exist"
	)
	_check(
		(
			nerds.board("vendor").get("is_new", false)
			and nerds.board_locked("vip")
			and not nerds.board_open_to_you("vendor")
		),
		"the Vendor Lounge is NEW and read-only for you, the VIP Area is locked"
	)
	_check(
		(
			str(nerds.board("tabs").parent) == "sandbox"
			and str(nerds.board("dash").parent) == "sandbox"
		),
		"Custom Tabs and Dashboards sit under the Plugin Sandbox"
	)
	_check(nerds.THREADS.size() >= 60, "about 60 threads or more (%d)" % nerds.THREADS.size())
	_check(
		(
			str(nerds.THREADS[4].title).begins_with("CryptoLocker")
			and nerds.THREADS[4].skill == "security"
		),
		"the original ten are still ids 0 to 9"
	)
	var glyphs: Dictionary = PixelFont.GLYPHS
	var bad := ""
	var banned := [
		"slack",
		"chatgpt",
		"windows 10",
		"windows 11",
		"discord",
		"tiktok",
		"office 365",
		"microsoft teams"
	]
	var per_board := {}
	var bad_shape := 0
	for i in nerds.THREADS.size():
		var th: Dictionary = nerds.THREADS[i]
		per_board[th.board] = int(per_board.get(th.board, 0)) + 1
		if (
			nerds.board(str(th.board)).is_empty()
			or not sk.NAMES.has(str(th.skill))
			or th.posts.size() < 3
		):
			bad_shape += 1
		var texts := [str(th.title), str(th.get("answer", ""))]
		for p in th.posts:
			texts.append(str(p.text))
			texts.append(str(p.by))
		for t in texts:
			for ch in t.to_upper():
				if ch != '"' and not glyphs.has(ch):
					bad += ch
			for word in banned:
				if t.to_lower().contains(word):
					bad += "[" + word + "]"
	_check(
		bad_shape == 0,
		"every thread has a real board, a real skill and an opening post with at least two replies"
	)
	_check(
		bad == "", "every character is in the pixel font and nothing is out of period (%s)" % bad
	)
	var ok_boards := 0
	for b in boards:
		if int(per_board.get(str(b.id), 0)) >= 3 or str(b.id) == "vip":
			ok_boards += 1
	_check(ok_boards == boards.size(), "every board has 3 to 6 threads (the VIP Area has none)")
	var answers := 0
	for i in nerds.THREADS.size():
		if nerds.is_question(i):
			answers += 1 if str(nerds.THREADS[i].answer).length() > 20 else 0
	_check(answers >= 50, "%d open-question threads carry your answer text" % answers)

	# ---- the clock and the date
	c.day = 4
	_check(
		nerds.date_text(4) == "TUE APR 8, 2014",
		"day 4 is Tuesday April 8, 2014 (the end of support for XP)"
	)
	_check(
		(
			nerds.time_text(9 * 60 + 5) == "9:05 AM"
			and nerds.time_text(0) == "12:00 AM"
			and nerds.time_text(13 * 60 + 30) == "1:30 PM"
		),
		"12 hour clock text"
	)
	var weekend := 0
	for d in range(-30, 40):
		weekend += (
			1
			if nerds.date_text(d).begins_with("SAT") or nerds.date_text(d).begins_with("SUN")
			else 0
		)
	_check(
		(
			weekend == 0
			and nerds.date_text(1) == "THU APR 3, 2014"
			and nerds.date_text(7).begins_with("FRI")
		),
		"campaign days are working days: no weekends"
	)
	root.get_node("World").clock = 9.25
	_check(
		nerds.clock_line() == "IT IS CURRENTLY TUE APR 8, 2014 9:15 AM",
		"the footer clock line uses the game clock (%s)" % nerds.clock_line()
	)
	_check(
		(
			nerds.when_text(4, 540) == "TODAY 9:00 AM"
			and nerds.when_text(3, 960) == "YESTERDAY 4:00 PM"
			and nerds.when_text(1, 600) == "APR 3 10:00 AM"
			and nerds.day_text(2) == "APR 4"
		),
		"relative times"
	)
	_check(
		(
			nerds.commas(8408) == "8,408"
			and nerds.commas(999) == "999"
			and nerds.commas(1234567) == "1,234,567"
		),
		"thousands commas"
	)

	# ---- counts, last posts and the footer
	var general_day4: Array = nerds.board_counts("general")
	c.day = 14
	var general_day14: Array = nerds.board_counts("general")
	_check(
		general_day14[0] > general_day4[0] and general_day14[1] > general_day4[1],
		"board counts grow with the day (%s -> %s)" % [str(general_day4), str(general_day14)]
	)
	_check(nerds.board_counts("vip") == [0, 0], "the VIP Area is empty")
	var stats4: Dictionary = {}
	c.day = 4
	stats4 = nerds.stats()
	c.day = 14
	var stats14: Dictionary = nerds.stats()
	_check(
		(
			int(stats14.posts) > int(stats4.posts)
			and int(stats14.topics) > int(stats4.topics)
			and int(stats14.members) > int(stats4.members)
		),
		"total posts, topics and members grow"
	)
	_check(nerds.NEW_MEMBERS.has(str(stats14.newest)), "the newest member is one of the names")
	c.day = 6
	var line_a: String = nerds.last_post_line("scripts")
	_check(
		line_a.begins_with("LAST POST: RE: ") and line_a.contains(" BY "),
		"a last-post line names a thread and a nick (%s)" % line_a
	)
	_check(
		nerds.last_post_line("scripts") == line_a and nerds.stats().newest == nerds.stats().newest,
		"the same day gives the same lines (seeded)"
	)
	var differ := 0
	for d in range(7, 17):
		c.day = d
		if nerds.last_post_line("scripts") != line_a:
			differ += 1
	_check(differ >= 6, "other days give other last posts (%d of 10)" % differ)
	_check(nerds.last_post_line("vip") == "NO POSTS", "the VIP Area has no last post")
	var lp: Dictionary = nerds.last_post("general")
	_check(
		nerds.board_of(int(lp.thread)) == "general",
		"the last post of a board comes from a thread on that board"
	)
	c.day = 20
	var vendor_ids: Array = nerds.board_threads("vendor")
	_check(
		vendor_ids.size() == 4 and nerds.is_sticky(int(vendor_ids[0])),
		"the Vendor Lounge shows its sticky first and the 3 ads (%d)" % vendor_ids.size()
	)
	var order_ok := true
	var general_ids: Array = nerds.board_threads("general")
	for k in range(1, general_ids.size()):
		if not nerds.is_sticky(general_ids[k]) and not nerds.is_sticky(general_ids[k - 1]):
			order_ok = (
				order_ok and nerds.age_days(general_ids[k - 1]) <= nerds.age_days(general_ids[k])
			)
	_check(
		order_ok and nerds.is_sticky(int(general_ids[0])),
		"threads are stickies first, then the newest"
	)
	var posts: Array = nerds.thread_posts(int(general_ids[1]))
	var chrono := true
	for k in range(1, posts.size()):
		chrono = (
			chrono
			and (
				int(posts[k].day) > int(posts[k - 1].day)
				or (
					int(posts[k].day) == int(posts[k - 1].day)
					and int(posts[k].minute) >= int(posts[k - 1].minute)
				)
			)
		)
	_check(chrono, "the posts of a thread are in time order")

	# ---- today's five questions
	c.day = 8
	nerds.reset()
	nerds.ensure_threads()
	_check(nerds.threads.size() == 5, "five open questions a day")
	var first_ids := []
	for th in nerds.threads:
		first_ids.append(int(th.id))
		_check(
			nerds.is_question(int(th.id)),
			"question %d is a real open question, not a sticky or a vendor ad" % int(th.id)
		)
	var easy := 0
	for id in first_ids:
		easy += (
			1
			if int(nerds.THREADS[id].level) == 0 and int(nerds.THREADS[id].get("ps", 0)) == 0
			else 0
		)
	_check(easy >= 2, "at least two are easy ones")
	nerds._day = -1
	nerds.threads = []
	nerds.ensure_threads()
	var again := []
	for th in nerds.threads:
		again.append(int(th.id))
	_check(again == first_ids, "the same day and seed give the same questions (seeded)")
	var days_seen := {}
	for d in range(9, 20):
		c.day = d
		nerds._day = -1
		nerds.ensure_threads()
		var key := ""
		for th in nerds.threads:
			key += "%d," % int(th.id)
		days_seen[key] = true
	_check(
		days_seen.size() >= 9,
		"other days ask other questions (%d different lists in 11 days)" % days_seen.size()
	)

	# ---- reading and posting
	c.day = 9
	nerds.reset()
	nerds.ensure_threads()
	nerds.karma = 10
	var q0: int = nerds.threads[0].id
	nerds.threads[0].id = 2  # disk full: servers 0
	var xp0: int = sk.xp.servers
	var absent := -1  # an id that is not among today's questions (which ones are in the day depends on the run seed)
	for cand in range(100, 400):
		if nerds.today_index(cand) == -1:
			absent = cand
			break
	_check(
		nerds.today_index(2) == 0 and absent > 0,
		"today_index finds today's questions"
	)
	nerds.open_thread(2)
	_check(
		nerds.threads[0].read and sk.xp.servers == xp0 + 2,
		"opening one of today's questions reads it (+2 XP)"
	)
	nerds.open_thread(2)
	_check(sk.xp.servers == xp0 + 2, "reading is once")
	nerds.threads[1].id = 4  # CryptoLocker: security 2
	sk.xp.security = 0
	var k0: int = nerds.karma
	var msg: String = nerds.answer_thread(1)
	_check(
		msg.contains("NOT SURE") and nerds.karma == k0 - 1 and not nerds.threads[1].answered,
		"a wrong answer costs 1 karma and is not posted"
	)
	_check(
		nerds.corrections.has(4) and nerds.thread_posts(4).size() == 4 and not nerds.mine.has(4),
		"a polite correction from a nick shows in the thread"
	)
	var corr: Dictionary = nerds.thread_posts(4)[3]
	_check(
		str(corr.text).begins_with("Re: ") and nerds.POSTERS.has(str(corr.by)),
		"the correction is a Re: line from a known nick (%s)" % str(corr.by)
	)
	diff.tier = "easy"
	_check(diff.cozy_on(), "Easy in a campaign is cozy")
	k0 = nerds.karma
	msg = nerds.answer_thread(1)
	_check(
		msg.contains("NOT SURE") and msg.contains("NO KARMA LOST") and nerds.karma == k0,
		"cozy Easy: a wrong answer loses no karma"
	)
	diff.tier = "normal"
	sk.xp.security = 90
	_check(
		sk.level("security") >= 2 and nerds.need_text(4) == "",
		"with the level the thread needs nothing more"
	)
	k0 = nerds.karma
	msg = nerds.answer_thread(1)
	_check(
		msg == "POSTED. +2 KARMA" and nerds.karma == k0 + 2 and nerds.threads[1].answered,
		"the right level posts: +2 karma"
	)
	var mine_post: Dictionary = nerds.thread_posts(4)[nerds.thread_posts(4).size() - 1]
	_check(
		(
			bool(mine_post.mine)
			and mine_post.by == nerds.PLAYER_NICK
			and str(mine_post.text).length() > 20
		),
		"your post shows in the thread with your nick"
	)
	_check(not nerds.corrections.has(4), "the correction goes away once you answer")
	_check(nerds.answer_thread(1) == "ALREADY ANSWERED", "once per thread")
	_check(
		(
			nerds.first_day == 9 and nerds.last_post("general").get("by", "") == nerds.PLAYER_NICK
			or nerds.board_of(4) != "general"
		),
		"your post is the last post of its board"
	)
	_check(
		nerds.stats().newest == nerds.PLAYER_NICK,
		"the newest member is you on the day of your first answer"
	)
	_check(
		(
			nerds.board_counts(nerds.board_of(4))[1]
			== (
				int(nerds.board(nerds.board_of(4)).posts)
				+ 9 * int(nerds.board(nerds.board_of(4)).gp)
				+ 1
			)
		),
		"your post counts on the board"
	)
	nerds.karma = 5
	_check(nerds.rank() == "LURKER" and nerds.signature() == "", "no signature for a lurker")
	nerds.karma = 25
	_check(
		nerds.rank() == "REGULAR" and nerds.signature().begins_with("--"),
		"a regular gets a signature"
	)
	nerds.karma = 45
	_check(
		nerds.rank() == "GURU" and nerds.signature() != nerds.TEXT.sig_regular,
		"a guru gets another one"
	)
	nerds.karma = 10

	# ---- saved
	nerds.karma = 17
	c.save()
	c.new_game("free")
	_check(
		(
			c.continue_game("tech")
			and nerds.karma == 17
			and nerds.mine.has(4)
			and nerds.first_day == 9
		),
		"karma and your posts are saved with the campaign"
	)
	DirAccess.remove_absolute(c.save_path("tech"))

	# ---- the tie-ins
	c.new_game("tech")
	sk.ps_level = 0
	nerds.ensure_threads()
	var script_thread := -1
	for i in nerds.THREADS.size():
		if str(nerds.THREADS[i].board) == "scripts" and int(nerds.THREADS[i].get("ps", 0)) == 2:
			script_thread = i
	_check(script_thread >= 0, "Script Swap has threads that need PowerShell level 2")
	nerds.threads[0].id = script_thread
	nerds.threads[0].answered = false
	sk.xp[str(nerds.THREADS[script_thread].skill)] = 400
	_check(
		nerds.need_text(script_thread).contains("POWERSHELL LEVEL 2"),
		"the thread says it needs PowerShell level 2 (%s)" % nerds.need_text(script_thread)
	)
	_check(
		nerds.answer_thread(0).contains("NOT SURE"),
		"without PowerShell the script thread is over your head"
	)
	sk.ps_level = 2
	_check(
		nerds.answer_thread(0) == "POSTED. +3 KARMA",
		"with PowerShell 2 (SCRIPT: THIS CLIENT) a script answer earns +1 extra karma"
	)
	comp.open(1)
	comp.activate("app:nerds")
	comp.forum.reset()
	comp.activate("nerds:board:scripts")
	comp._canvas.queue_redraw()
	await _wait(3)
	var notes: Array = comp.forum._board_notes("scripts")
	_check(
		notes.size() == 1 and str(notes[0][0]).contains("SCRIPT: THIS CLIENT IS UNLOCKED"),
		"the Script Swap header shows the perk"
	)
	sk.ps_level = 0
	notes = comp.forum._board_notes("tools")
	_check(str(notes[0][0]).contains("LEVEL 2"), "Cool Tools shows how far the perk is")
	_check(
		(
			comp.forum._board_notes("dash").size() == 1
			and comp.forum._board_notes("general").is_empty()
		),
		"Dashboards is a plain board with one tip, General has none"
	)
	expo.went = false
	expo.spam = 0
	_check(
		nerds.board_threads("vendor").size() == 4,
		"before Rodent Nation the Vendor Lounge has 3 ads and the sticky"
	)
	expo.went = true
	_check(
		nerds.board_threads("vendor").size() == 5,
		"after the trip the vendors thank you for stopping by"
	)
	expo.spam = 2
	_check(
		nerds.board_threads("vendor").size() == 6 and comp.forum._board_notes("vendor").size() == 2,
		"with a scanned badge the follow-up thread shows and the note counts the vendors"
	)
	var vendor_nicks := ["ShadowPoint_Brad", "WebWoot_Dee", "SoftSwipe_Rex"]
	var vendor_ok := true
	for v in expo.VENDORS:
		vendor_ok = (
			vendor_ok and str(v.speaker).contains("ShadowPoint")
			or str(v.speaker).contains("WebWoot")
			or str(v.speaker).contains("SoftSwipe")
		)
	_check(
		(
			vendor_ok
			and nerds.POSTERS.has(vendor_nicks[0])
			and nerds.POSTERS[vendor_nicks[1]] == "VENDOR"
		),
		"the lounge posters are the conference vendors"
	)
	expo.went = false
	expo.spam = 0
	comp.close()

	# ---- navigation by keys and by mouse
	c.new_game("tech")
	c.day = 6
	comp.open(1)
	comp.activate("app:nerds")
	await _wait(2)
	var f = comp.forum
	_check(
		f.view == "boards" and comp.nerds_tab == "forum", "the NERDS app opens on the board index"
	)
	_check(f.selected_action() == "nerds:board:general", "the first board is selected")
	comp.nerds_key("down")
	comp.nerds_key("down")
	_check(
		f.selected_action() == "nerds:board:sandbox",
		"Down moves the selection (%s)" % f.selected_action()
	)
	comp.nerds_key("up")
	comp.nerds_key("enter")
	_check(f.view == "threads" and f.board_id == "burrow", "Enter opens the board")
	comp.nerds_key("enter")
	_check(
		f.view == "thread" and f.thread_id == nerds.board_threads("burrow")[0],
		"Enter opens the first thread"
	)
	var t0: int = f.top
	comp.nerds_key("down")
	comp.nerds_key("pgdn")
	_check(f.top >= t0, "Down and Page Down scroll the thread")
	comp.nerds_key("pgup")
	comp.nerds_key("up")
	comp.back()
	_check(f.view == "threads", "Esc steps back to the board")
	_check(comp.nerds_key("left") and f.view == "boards", "Left also steps back")
	comp.escape()
	_check(not comp.is_open, "Esc on the index closes the computer in one press")
	comp.open(1)
	comp.activate("app:nerds")
	_check(
		comp.nerds_key("right") and comp.nerds_tab == "irc",
		"Right on the index goes to the IRC tab"
	)
	_check(comp.nerds_key("left") and comp.nerds_tab == "forum", "Left comes back")
	comp.nerds_key("tab")
	_check(comp.nerds_tab == "irc", "Tab toggles the tabs")
	comp.nerds_key("tab")
	# mouse: a click on the VIP row toasts the joke, a click on a board opens it
	comp.activate("nerds:board:vip")
	_check(
		f.view == "boards" and comp._toast.contains("VIP"),
		"the VIP Area stays locked with a joke (%s)" % comp._toast
	)
	nerds.karma = 45
	comp.activate("nerds:board:vip")
	_check(comp._toast.contains("GURU"), "a guru gets another joke")
	nerds.karma = 10
	comp.activate("nerds:board:tools")
	_check(f.view == "threads" and f.board_id == "tools", "a click opens a board")
	var tid: int = nerds.board_threads("tools")[0]
	comp.activate("nerds:thread:%d" % tid)
	_check(f.view == "thread" and f.thread_id == tid, "a click opens a thread")
	comp.activate("nerds:back")
	comp.activate("nerds:back")
	_check(f.view == "boards", "BACK goes up one level at a time")
	f.scroll(5)
	_check(f.top >= 1 or f._max_top() == 0, "the wheel and the DN button scroll")
	comp.scroll_list(-10)
	comp.activate("nerds:up")
	# replying from inside a thread with Enter and with the REPLY button
	nerds.reset()
	nerds.ensure_threads()
	nerds.threads[0].id = 2
	nerds.threads[1].id = 4
	sk.xp.servers = 0
	comp.forum.reset()
	comp.activate("nerds:thread:2")
	_check(nerds.threads[0].read, "opening a question from the list reads it")
	var karma_before: int = nerds.karma
	comp.nerds_key("enter")
	_check(
		(
			nerds.threads[0].answered
			and nerds.karma == karma_before + 2
			and comp._toast.contains("POSTED")
		),
		"Enter in a thread replies"
	)
	comp.forum.reset()
	nerds.threads = nerds.threads.filter(func(t: Dictionary) -> bool: return int(t.id) != 7)  # thread 7 is not one of today's questions
	comp.activate("nerds:thread:7")
	comp.activate("nerds:reply")
	_check(comp._toast.contains("SOLVED"), "a thread that is not an open question says SOLVED")
	comp.forum.reset()
	comp.activate("nerds:thread:%d" % nerds.board_threads("general")[0])
	comp.activate("nerds:reply")
	_check(comp._toast.contains("STICKY"), "a sticky thread is locked")
	comp.forum.reset()
	comp.activate("nerds:thread:%d" % nerds.board_threads("vendor")[1])
	comp.activate("nerds:reply")
	_check(
		comp._toast.contains("approved vendors") or comp._toast.contains("APPROVED"),
		"the Vendor Lounge is read-only for you"
	)
	comp.close()

	# ---- the screens at the three formats: nothing drawn outside the screen, every row reachable
	for fmt in ["wide", "h", "v"]:
		game.set_format(fmt)
		await _wait(3)
		comp.open(1)
		comp.activate("app:nerds")
		comp.forum.reset()
		var screens: Array = [
			["index", ""],
			["board", "nerds:board:scripts"],
			["thread", "nerds:thread:%d" % nerds.board_threads("scripts")[1]]
		]
		PixelFont.audit = []
		for s in screens:
			if s[1] != "":
				comp.activate(str(s[1]))
			await _wait(3)
			var seen: int = PixelFont.audit.size()
			var problems: Array = PixelFont.audit_report("%s %s" % [fmt, str(s[0])], false)
			_check(
				seen > 10 and problems.is_empty(),
				(
					"%s %s: drawn (%d texts), nothing off screen %s"
					% [fmt, str(s[0]), seen, str(problems)]
				)
			)
		comp.close()
		await _wait(2)
	game.set_format("wide")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
