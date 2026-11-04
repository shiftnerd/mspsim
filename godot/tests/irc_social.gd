extends SceneTree
# gdlint:disable=max-line-length
# LabRat Nerds IRC, social side (R30): TALK topics answered in each nick's voice, seeded days, the chat cooldown and the daily cap,
# friendship (growth, levels, unlocks, saving, old saves), the bounded accuracy bonus, lurkers, the channel talking to itself
# (seeded, event-aware, on a timer), jumping into a conversation, the strings in the pixel font, and the screens at three formats. Headless.

const PixelFont := preload("res://scripts/pixelfont.gd")

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


# the nick's last line in the channel
func _last_of(nerds: Node, nick: String) -> String:
	var found := ""
	for entry in nerds.channel:
		if str(entry[0]) == nick:
			found = str(entry[1])
	return found


func _fresh(nerds: Node, day: int) -> void:
	root.get_node("Campaign").day = day
	nerds.reset()
	nerds.karma = 20
	nerds._last_social = -999.0
	nerds._open_at = -999.0


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var nerds := root.get_node("Nerds")
	var comp := root.get_node("Computer")
	var game := root.get_node("Game")
	var diff := root.get_node("Difficulty")
	var expo := root.get_node("Expo")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	c.new_game("tech")
	var nicks: Array = nerds.NICKS.keys()

	# ---- the data: every nick answers every topic, the strings fit the font and the period
	_check(nerds.TOPICS.size() >= 10, "at least 10 topics (%d)" % nerds.TOPICS.size())
	var thin := ""
	var pool_lines := 0
	for nick in nicks:
		for t in nerds.TOPICS:
			var pool: Array = nerds.CHAT.get(nick, {}).get(t.id, [])
			pool_lines += pool.size()
			if pool.size() < 2:
				thin += "%s/%s " % [nick, t.id]
		for kind in ["agree", "joke", "ask"]:
			if nerds.REPLIES.get(nick, {}).get(kind, []).size() < 2:
				thin += "reply %s/%s " % [nick, kind]
		if nerds.GREETINGS.get(nick, []).size() != 2:
			thin += "greeting " + str(nick)
	_check(thin == "", "every nick has 2+ lines for every topic and reply (missing: %s)" % thin)
	_check(pool_lines >= 9 * 10 * 2, "%d topic lines in the nick pools" % pool_lines)
	_check(nerds.AMBIENT.size() >= 15, "%d ambient exchanges" % nerds.AMBIENT.size())
	var every: Array = []
	for t in nerds.TOPICS:
		every.append(str(t.label))
	for nick in nerds.CHAT:
		for topic in nerds.CHAT[nick]:
			every.append_array(nerds.CHAT[nick][topic])
	for nick in nerds.REPLIES:
		for kind in nerds.REPLIES[nick]:
			every.append_array(nerds.REPLIES[nick][kind])
	for kind in nerds.YOU_SAY:
		every.append_array(nerds.YOU_SAY[kind])
	for nick in nerds.GREETINGS:
		every.append_array(nerds.GREETINGS[nick])
	var shape_bad := 0
	for ex in nerds.AMBIENT:
		if ex.lines.size() < 2 or not (nerds.NICKS.has(str(ex.lines[0][0]))):
			shape_bad += 1
		for line in ex.lines:
			if not nerds.NICKS.has(str(line[0])):
				shape_bad += 1
			every.append(str(line[1]).replace("{day}", "12").replace("{date}", "TUE APR 8, 2014").replace("{time}", "9:14 AM"))
	for key in ["irc_lurker", "irc_busy", "irc_up", "irc_vouch", "irc_locked", "irc_wait", "irc_nojoin"]:
		every.append(str(nerds.TEXT[key]).replace("%s", "gnawer"))
	_check(shape_bad == 0, "every ambient exchange has 2+ lines by real nicks")
	var glyphs: Dictionary = PixelFont.GLYPHS
	var banned := ["slack", "chatgpt", "windows 10", "windows 11", "discord", "tiktok", "office 365", "microsoft teams", "facebook", "twitter", "youtube", "netflix", "google", "apple", "samsung", "candy crush", "flappy", "veeam", "pharrell", "game of thrones", "iphone", "android"]
	var bad := ""
	var long_line := 0
	for text in every:
		var s: String = str(text)
		if s.length() > 100:
			long_line += 1
		for ch in s.to_upper():
			if ch != '"' and not glyphs.has(ch):
				bad += ch
		for word in banned:
			if s.to_lower().contains(word):
				bad += "[%s]" % word
	_check(bad == "", "every character is in the pixel font and nothing is out of period or a real brand (%s)" % bad)
	_check(long_line == 0, "no line over 100 characters (%d)" % long_line)

	# ---- friendship words and levels
	_fresh(nerds, 3)
	_check(nerds.friend_word("gnawer") == "STRANGER" and nerds.friend_level("gnawer") == 0, "everybody starts as a STRANGER")
	nerds.friend["gnawer"] = 10
	_check(nerds.friend_word("gnawer") == "REGULAR", "10 = REGULAR")
	nerds.friend["gnawer"] = 30
	_check(nerds.friend_word("gnawer") == "FRIEND", "30 = FRIEND")
	nerds.friend["gnawer"] = 60
	_check(nerds.friend_word("gnawer") == "BUDDY", "60 = BUDDY")
	nerds.friend["gnawer"] = 9999
	_check(nerds.friend_value("gnawer") == 100, "friendship stops at 100")

	# ---- accuracy bonus is small and bounded
	_fresh(nerds, 3)
	var b0: float = nerds.friend_bonus("PS_wizard")
	nerds.friend["PS_wizard"] = 50
	var b50: float = nerds.friend_bonus("PS_wizard")
	nerds.friend["PS_wizard"] = 100
	var b100: float = nerds.friend_bonus("PS_wizard")
	_check(b0 == 0.0 and b50 > b0 and b100 > b50 and b100 <= 0.1001, "the work-answer bonus grows with friendship and tops out at +10%% (%.3f)" % b100)
	nerds.friend["PS_wizard"] = 100000
	_check(nerds.friend_bonus("PS_wizard") <= 0.1001, "a corrupt value cannot break the bound")
	nerds.friend = {"PS_wizard": 100, "xX_n00b_Xx": 100, "HELPPLZ_Pip": 100, "trollbot": 100}
	var hits := 0
	for i in 400:
		nerds._lines = []
		nerds._last_ask = -999.0
		nerds.karma = 40
		var v: Dictionary = nerds.ask("which?", ["A", "B", "C", "D"], 2)
		hits += 1 if int(v.winner) == 2 else 0
	nerds.friend = {}
	var hits0 := 0
	for i in 400:
		nerds._lines = []
		nerds._last_ask = -999.0
		nerds.karma = 40
		var v0: Dictionary = nerds.ask("which?", ["A", "B", "C", "D"], 2)
		hits0 += 1 if int(v0.winner) == 2 else 0
	_check(hits >= hits0 - 40, "work questions still work with friends (%d vs %d agree on the best)" % [hits, hits0])

	# ---- each nick answers each topic in its own voice
	var wrong := ""
	for nick in nicks:
		for t in nerds.TOPICS:
			_fresh(nerds, 5)
			nerds.friend[nick] = 100
			var res: Dictionary = nerds.chat(nick, str(t.id))
			nerds._process(5.0)
			var said := _last_of(nerds, nick)
			var pool: Array = nerds.CHAT[nick][t.id]
			if not res.ok or said == "" or not (pool.has(said)):
				wrong += "%s/%s " % [nick, t.id]
	_check(wrong == "", "all 9 nicks answer all 12 topics from their own pools (%s)" % wrong)

	# ---- seeded: the same day and run seed give the same line, another day may differ
	_fresh(nerds, 7)
	nerds.chat("old_hand", "weekend")
	nerds._process(5.0)
	var first := _last_of(nerds, "old_hand")
	_fresh(nerds, 7)
	nerds.chat("old_hand", "weekend")
	nerds._process(5.0)
	_check(first != "" and first == _last_of(nerds, "old_hand"), "the same day gives the same answer twice")
	var differs := 0
	for d in range(8, 24):
		_fresh(nerds, d)
		nerds.chat("old_hand", "weekend")
		nerds._process(5.0)
		differs += 1 if _last_of(nerds, "old_hand") != first else 0
	_check(differs > 0, "other days pick the other line")
	diff.run_seed = 12345
	_fresh(nerds, 7)
	var seed_a := ""
	nerds.irc_open()
	for e in nerds.channel:
		seed_a += str(e[1])
	diff.run_seed = 999
	_fresh(nerds, 7)
	var seed_b := ""
	nerds.irc_open()
	for e in nerds.channel:
		seed_b += str(e[1])
	diff.run_seed = 12345
	_fresh(nerds, 7)
	var seed_c := ""
	nerds.irc_open()
	for e in nerds.channel:
		seed_c += str(e[1])
	_check(seed_a == seed_c and seed_a != seed_b, "the channel's own talk follows the run seed")

	# ---- cooldown, daily cap, lurkers
	_fresh(nerds, 9)
	var r1: Dictionary = nerds.chat("rodent_rick", "day")
	var r2: Dictionary = nerds.chat("gnawer", "day")
	_check(r1.ok and not r2.ok and r2.why == "cooldown", "a second chat right away waits for the social cooldown")
	_check(nerds.SOCIAL_COOLDOWN < nerds.COOLDOWN, "the social cooldown is lighter than the 45 s work cooldown")
	nerds._last_social = -999.0
	var r3: Dictionary = nerds.chat("rodent_rick", "music")
	nerds._last_social = -999.0
	var r4: Dictionary = nerds.chat("rodent_rick", "joke")
	_check(r3.ok and r3.gain == 2 and r1.gain == 3, "the first chat of a day gives 3, the second 2 (%d, %d)" % [r1.gain, r3.gain])
	_check(not r4.ok and r4.why == "tired" and nerds.friend_value("rodent_rick") == 5, "a third chat with the same nick that day gives nothing")
	_check(nerds.chat_left("rodent_rick") == 0 and nerds.chat_left("gnawer") == 2, "chats left today are counted per nick")
	c.day = 10
	nerds._last_social = -999.0
	var r5: Dictionary = nerds.chat("rodent_rick", "joke")
	_check(r5.ok and r5.gain == 3, "a new day opens the cap again")
	_fresh(nerds, 9)
	nerds.karma = 3
	var r6: Dictionary = nerds.chat("gnawer", "day")
	_check(not r6.ok and r6.why == "ignored" and nerds.friend_value("gnawer") == 0, "a lurker (karma under 4) is ignored and gains nothing")
	nerds._process(5.0)
	_check(_last_of(nerds, "gnawer") == "", "and nobody answers")

	# ---- levels, unlocks and the friend perk
	_fresh(nerds, 11)
	var locked: Dictionary = nerds.chat("MPriest", "personal")
	_check(not locked.ok and locked.why == "locked", "personal topics are locked for a stranger")
	nerds._last_social = -999.0
	var dream_locked: Dictionary = nerds.chat("MPriest", "dream")
	_check(dream_locked.why == "locked", "and the dream topic needs a BUDDY")
	nerds.friend["MPriest"] = 29
	var rep0: int = c.rep
	var karma0: int = nerds.karma
	nerds._last_social = -999.0
	var up: Dictionary = nerds.chat("MPriest", "day")
	_check(up.ok and up.up and nerds.friend_word("MPriest") == "FRIEND", "a chat can lift a nick to FRIEND")
	_check(nerds.karma >= karma0 + 1 and nerds.karma <= karma0 + 2, "a level-up earns +1 karma (and at most +1 more from a friend)")
	_check(c.rep == rep0, "friendship never touches the reputation")
	nerds._last_social = -999.0
	var personal: Dictionary = nerds.chat("MPriest", "personal")
	_check(personal.ok, "a FRIEND opens up")
	nerds._process(5.0)
	_check(nerds.CHAT["MPriest"]["personal"].has(_last_of(nerds, "MPriest")), "in his own words")
	nerds.friend["MPriest"] = 60
	c.day = 12
	nerds._last_social = -999.0
	_check(nerds.chat("MPriest", "dream").ok, "a BUDDY shares a dream")
	var karma_gain := 0
	for d in range(20, 60):
		_fresh(nerds, d)
		nerds.friend["PS_wizard"] = 40
		var k0: int = nerds.karma
		nerds.chat("PS_wizard", "win")
		karma_gain = maxi(karma_gain, nerds.karma - k0)
	_check(karma_gain <= 1, "a friend's vouch is at most +1 karma a day (%d)" % karma_gain)
	_fresh(nerds, 13)
	nerds.friend["PS_wizard"] = 40
	var xp0: int = root.get_node("Skills").xp["people"]
	nerds.chat("PS_wizard", "win")
	nerds._last_social = -999.0
	nerds.chat("PS_wizard", "lab")
	_check(root.get_node("Skills").xp["people"] == xp0 + 1, "the daily friend perk is +1 CUSTOMER XP, once a day")

	# ---- saving and old saves
	_fresh(nerds, 14)
	nerds.chat("gnawer", "day")
	nerds._last_social = -999.0
	nerds.chat("gnawer", "win")
	nerds.friend["PS_wizard"] = 33
	var data: Dictionary = nerds.to_dict()
	_check(data.friend.gnawer == 5 and data.friend.PS_wizard == 33, "friendship is in the saved Nerds section")
	nerds.reset()
	nerds.from_dict(data)
	_check(nerds.friend_value("gnawer") == 5 and nerds.friend_word("PS_wizard") == "FRIEND" and nerds.chat_left("gnawer") == 0, "it loads back, with today's chat count")
	nerds.reset()
	nerds.from_dict({"karma": 17, "mine": {}, "first_day": 2})
	_check(nerds.karma == 17 and nerds.friend.is_empty() and nerds.friend_word("gnawer") == "STRANGER", "an old save loads with everybody at 0")
	nerds.reset()
	nerds.from_dict({"friend": {"gnawer": 12, "nobody_here": 50, "trollbot": -5}})
	_check(nerds.friend_value("gnawer") == 12 and not nerds.friend.has("nobody_here") and nerds.friend_value("trollbot") == 0, "unknown nicks and negative values are dropped on load")
	c.day = 6
	nerds.friend["old_hand"] = 41
	nerds.karma = 31
	c.save()
	c.new_game("free")
	_check(c.continue_game("tech") and nerds.friend_value("old_hand") == 41 and nerds.karma == 31, "friendship is saved with the campaign next to karma")
	DirAccess.remove_absolute(c.save_path("tech"))

	# ---- the channel talks to itself
	_fresh(nerds, 4)
	var added: int = nerds.irc_open()
	var talkers := 0
	for e in nerds.channel:
		talkers += 1 if nerds.NICKS.has(str(e[0])) else 0
	_check(added >= 4 and talkers >= 4, "opening the tab scrolls in 2 to 4 exchanges (%d lines)" % added)
	_check(nerds.can_join() and nerds.amb_last.nick != "", "the last line can be jumped into")
	var again: int = nerds.irc_open()
	_check(again == 0, "opening it again at once adds nothing")
	var lines_a: Array = []
	for e in nerds.channel:
		lines_a.append(str(e[1]))
	_fresh(nerds, 4)
	nerds.irc_open()
	var lines_b: Array = []
	for e in nerds.channel:
		lines_b.append(str(e[1]))
	_check(lines_a == lines_b, "the same day looks the same twice")
	var seen_days := {}
	for d in range(1, 12):
		_fresh(nerds, d)
		nerds.irc_open()
		seen_days[str(nerds.channel.slice(1))] = true
	_check(seen_days.size() >= 8, "different days talk about different things (%d of 11)" % seen_days.size())
	_fresh(nerds, 2)
	world.clock = 9.0
	expo.went = false
	for b in msp.backups:
		b.ok = true
	var plain := ""
	nerds._roll_amb_day()
	for ex in nerds.AMBIENT:
		if str(ex.needs) == "went" and nerds._eligible(str(ex.needs)):
			plain += "went "
		if str(ex.needs) == "backup" and nerds._eligible(str(ex.needs)):
			plain += "backup "
		if str(ex.needs) == "day:4" and nerds._eligible(str(ex.needs)):
			plain += "day4 "
	_check(plain == "", "before the trip, with good backups, on day 2: no Rodent Nation, backup or XP-deadline talk")
	expo.went = true
	msp.backups[0].ok = false
	c.day = 4
	_check(nerds._eligible("went") and nerds._eligible("backup") and nerds._eligible("day:4") and not nerds._eligible("before:4"), "after the trip, a failing backup and day 4 the topical talk is allowed")
	var topical := 0
	for d in range(4, 12):
		_fresh(nerds, d)
		expo.went = true
		nerds.irc_open()
		nerds._process(0.1)
		for e in nerds.channel:
			if str(e[1]).contains("Rodent Nation") or str(e[1]).contains("backup job failed") or str(e[1]).contains("OpenSSL"):
				topical += 1
	_check(topical > 0, "the talk mentions the trip, a failed backup or the day's news (%d)" % topical)
	expo.went = false
	msp.backups[0].ok = true
	_fresh(nerds, 8)
	nerds.irc_open()
	var ex_day := false
	for e in nerds.channel:
		ex_day = ex_day or str(e[1]).contains("day 8") or str(e[1]).contains("{")
	_check(not str(nerds.channel).contains("{"), "no {placeholder} is left in the channel")
	# the greeting by name
	_fresh(nerds, 15)
	nerds.friend["HELPPLZ_Pip"] = 35
	nerds.irc_open()
	var greeted := false
	for e in nerds.channel:
		greeted = greeted or (str(e[0]) == "HELPPLZ_Pip" and str(e[1]).contains("FRESHRAT"))
	_check(greeted, "a friend greets FreshRat by name when the tab opens")
	_fresh(nerds, 15)
	nerds.irc_open()
	var nobody := true
	for e in nerds.channel:
		nobody = nobody and not str(e[1]).contains("FreshRat is") and not str(e[1]).contains("FRESHRAT")
	_check(nobody, "strangers do not")
	# the timer
	_fresh(nerds, 16)
	nerds.irc_open()
	var before_size: int = nerds.channel.size()
	nerds.force_watch = false
	nerds._process(100.0)
	_check(nerds.channel.size() == before_size, "nothing new arrives while the tab is closed")
	nerds.force_watch = true
	nerds._amb_timer = 0.0
	for i in 200:
		nerds._process(5.0)
	_check(nerds.channel.size() > before_size and nerds._amb_posted == nerds.AMBIENT_MAX, "new exchanges arrive on a timer while the tab is open (max %d a day)" % nerds.AMBIENT_MAX)
	var capped: int = nerds._amb_posted
	for i in 60:
		nerds._process(5.0)
	_check(nerds._amb_posted == capped, "and they stop at the daily maximum")
	nerds.force_watch = false

	# ---- jumping in
	_fresh(nerds, 17)
	nerds.irc_open()
	var spoke := str(nerds.amb_last.nick)
	var f0: int = nerds.friend_value(spoke)
	var j: Dictionary = nerds.join("joke")
	nerds._process(5.0)
	_check(j.ok and nerds.friend_value(spoke) == f0 + 2 and nerds.REPLIES[spoke]["joke"].has(_last_of(nerds, spoke)), "a joke gets the speaker's own reply and 2 points (%s)" % spoke)
	_check(not nerds.can_join(), "you cannot jump into the same line twice")
	_fresh(nerds, 17)
	nerds.irc_open()
	nerds.karma = 2
	var jl: Dictionary = nerds.join("agree")
	_check(not jl.ok and jl.why == "ignored", "a lurker's reply gets no answer")
	_fresh(nerds, 17)
	_check(not nerds.join("agree").ok, "with nothing said there is nothing to jump into")

	# ---- the work questions are unchanged: cooldown, karma, four answers
	_fresh(nerds, 18)
	nerds.karma = 20
	nerds._last_ask = -999.0
	nerds.ask("which?", ["A", "B", "C", "D"], 1)
	_check(nerds.karma == 19 and not nerds.can_ask() and nerds._lines.size() == 4, "a work question still costs 1 karma, waits 45 s and gets four answers")
	nerds._process(10.0)
	_check(nerds.channel.size() >= 5, "and they all arrive")

	# ---- Free Play: the same chat, nothing saved, no daily cap
	c.new_game("free")
	nerds.reset()
	nerds.karma = 20
	var free_ok := 0
	for i in 5:
		nerds._last_social = -999.0
		free_ok += 1 if nerds.chat("gnawer", "day").ok else 0
	_check(free_ok == 5 and nerds.friend_value("gnawer") > 0, "Free Play: social chat works (no daily cap)")
	c.new_game("tech")

	# ---- the screens: keys, mouse, back, layout at three formats
	_fresh(nerds, 19)
	nerds.friend["gnawer"] = 15
	comp.open(1)
	comp.activate("app:nerds")
	comp.nerds_key("tab")
	await _wait(2)
	_check(comp.nerds_tab == "irc" and comp.irc_view == "chat" and nerds.channel.size() > 1, "Tab opens IRC and the channel fills")
	comp.nerds_key("down")
	_check(comp.irc_view == "who", "Down opens the nick list")
	comp.nerds_key("down")
	comp.nerds_key("down")
	_check(comp.irc_sel == 2, "Down moves the pick")
	comp.nerds_key("enter")
	_check(comp.irc_view == "topics" and comp.irc_nick == "PS_wizard", "Enter picks the nick")
	comp.nerds_key("enter")
	_check(comp.irc_view == "chat" and "you" == str(nerds.channel[-1][0]) or nerds._sq.size() > 0, "Enter on a topic talks about it")
	nerds._process(5.0)
	_check(_last_of(nerds, "PS_wizard") != "", "and PS_wizard answers")
	comp.nerds_key("up")
	_check(comp.irc_view == "join", "Up opens JUMP IN")
	comp.escape()
	_check(comp.irc_view == "chat" and comp.app == "nerds", "Esc steps back to the log, not out of the app")
	comp.activate("nerds:view:who")
	comp.activate("nerds:who:gnawer")
	comp.nerds_key("left")
	_check(comp.irc_view == "who", "Left steps back from the topics to the nicks")
	comp.escape()
	comp.escape()
	_check(not comp.is_open, "and one more Esc closes the computer")
	comp.open(1)
	comp.activate("app:nerds")
	comp.nerds_key("left")
	_check(comp.nerds_tab == "forum", "Left on the log goes back to the forum")
	comp.close()
	await _wait(2)
	for fmt in ["wide", "h", "v"]:
		game.set_format(fmt)
		await _wait(3)
		_fresh(nerds, 19)
		nerds.friend["gnawer"] = 15
		nerds.friend["HELPPLZ_Pip"] = 70
		nerds.karma = 30
		comp.open(1)
		comp.activate("app:nerds")
		comp.activate("nerds:tab:irc")
		nerds.ask_ticket(msp.tickets[0] if not msp.tickets.is_empty() else {})
		nerds._process(10.0)
		var screens: Array = [["log", ""], ["who", "nerds:view:who"], ["topics", "nerds:who:HELPPLZ_Pip"], ["join", "nerds:view:join"]]
		PixelFont.audit = []
		for s in screens:
			if s[0] == "join":
				comp.activate("nerds:view:chat")
			if s[1] != "":
				comp.activate(str(s[1]))
			await _wait(3)
			var seen: int = PixelFont.audit.size()
			var problems: Array = PixelFont.audit_report("%s irc %s" % [fmt, str(s[0])], false)
			_check(seen > 6 and problems.is_empty(), "%s irc %s: drawn (%d texts), nothing off screen %s" % [fmt, str(s[0]), seen, str(problems)])
		comp.close()
		await _wait(2)
	game.set_format("wide")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
