extends SceneTree
# gdlint:disable=max-line-length
# The two newer LabRat Nerds forum regulars at Rodent Nation (R27), built like Priest Michael: GrizzleAdmin (expo_grizzle, the grumpy
# old-timer admin, in the lobby) and HELPPLZ_Pip (expo_pip, the newbie who posts in capitals, at the forum booth in the vendor hall):
# sheets and hands json in both facings, crowd places clear of the doors, chats with real effects once per trip, and their IRC lines.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fake(role: String) -> Node:
	var n := Node.new()
	n.set_meta("x", 0)
	n.set_script(load("res://tests/fake_npc.gd"))
	n.role = role
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cf := root.get_node("Expo")
	var cards := root.get_node("Cards")
	var sk := root.get_node("Skills")
	var nerds := root.get_node("Nerds")
	var social := root.get_node("Social")
	var intern: SpriteFrames = load("res://characters/office_intern.tres")
	var total_intern := 0
	for anim in intern.get_animation_names():
		total_intern += intern.get_frame_count(anim)
	for who in ["expo_grizzle", "expo_pip", "expo_ray", "expo_rita", "expo_tony", "expo_dot", "expo_walt"]:
		var frames: SpriteFrames = load("res://characters/%s.tres" % who)
		_check(frames != null, "%s has a SpriteFrames" % who)
		var total := 0
		for anim in frames.get_animation_names():
			total += frames.get_frame_count(anim)
		_check(total == total_intern, "%s has the same number of frames as the intern" % who)
		for side in ["right", "left"]:
			var sheet := Image.load_from_file(
				ProjectSettings.globalize_path("res://assets/characters/%s_%s.png" % [who, side])
			)
			_check(
				sheet != null and sheet.get_width() == 135 * 64 and sheet.get_height() == 80,
				"%s %s sheet is 135 frames of 64x80" % [who, side]
			)
			var f := FileAccess.open(
				"res://assets/characters/%s_%s_hands.json" % [who, side], FileAccess.READ
			)
			var rows: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
			_check(
				rows is Array and rows.size() == 135, "%s %s hands json has 135 rows" % [who, side]
			)
	# they look different from each other and from the priest (the sheets differ)
	var a := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/characters/expo_grizzle_right.png")
	)
	var b := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/characters/expo_pip_right.png")
	)
	var p := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/characters/expo_priest_right.png")
	)
	_check(
		(
			a.get_data() != b.get_data()
			and a.get_data() != p.get_data()
			and b.get_data() != p.get_data()
		),
		"three different people"
	)

	# placed in the world: the lobby and the vendor hall, off the doors and the check-in desk
	var spots := {}
	for room in cf.CROWD:
		for entry in cf.CROWD[room]:
			if str(entry.role).begins_with("forum:"):
				spots[str(entry.role)] = [room, float(entry.x)]
	_check(
		spots.has("forum:grizzle") and spots["forum:grizzle"][0] == "resort_lobby",
		"GrizzleAdmin stands in the lobby"
	)
	_check(
		spots.has("forum:pip") and spots["forum:pip"][0] == "vendor_hall",
		"Pip stands at the forum booth in the vendor hall"
	)
	for door in [37, 100, 263, 301]:
		_check(
			absf(float(spots["forum:grizzle"][1]) - float(door)) >= 25.0,
			"Grizzle is clear of x %d in the lobby (doors and the desk)" % door
		)
	_check(
		(
			absf(float(spots["forum:pip"][1]) - 247.0) <= 60.0
			and absf(float(spots["forum:pip"][1]) - 303.0) >= 25.0
		),
		"Pip is by the forum booth and not in the door"
	)

	# the chats
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)
	for id in ["grizzle", "pip"]:
		_check(
			not cf.forum_def(id).is_empty() and cf.forum_def(id).options.size() == 4,
			"%s has a chat with four options" % id
		)
	cf.reset()
	var s0: int = int(sk.xp.servers)
	cf.npc_use(_fake("forum:grizzle"), null)
	_check(
		cards.is_open and cards.speaker.begins_with("GrizzleAdmin") and cards.options.size() == 4,
		"E opens Grizzle's card"
	)
	cards.pick(0)
	_check(int(sk.xp.servers) == s0 + 4, "the old days are +4 servers XP")
	cards.pick(0)
	cf.npc_use(_fake("forum:grizzle"), null)
	_check(cards.options.size() == 1 and cards.text == str(cf.TEXT.chat_again), "once per trip")
	cards.pick(0)
	cf.reset()
	var k0: int = nerds.karma
	cf.npc_use(_fake("forum:grizzle"), null)
	cards.pick(2)
	_check(nerds.karma == k0 + 3, "his rules talk is +3 karma")
	cards.pick(0)
	cf.reset()
	var who: String = str(social.people()[0])
	social.rel[who] = 0
	cf.npc_use(_fake("forum:grizzle"), null)
	cards.pick(3)
	_check(social.value(who) == 1, "the coffee makes coworkers like you a little more")
	cards.pick(0)
	cf.reset()
	var p0: int = int(sk.xp.people)
	cf.npc_use(_fake("forum:pip"), null)
	_check(
		cards.speaker.begins_with("HELPPLZ_Pip") and cards.text.contains("CAPS LOCK"),
		"Pip talks in capitals"
	)
	cards.pick(0)
	_check(int(sk.xp.people) == p0 + 4, "helping Pip is +4 customer XP")
	cards.pick(0)
	cf.reset()
	k0 = nerds.karma
	cf.npc_use(_fake("forum:pip"), null)
	cards.pick(1)
	_check(nerds.karma == k0 + 3, "teaching him the search box is +3 karma")
	cards.pick(0)
	cf.reset()
	c.active = false
	k0 = nerds.karma
	cf.npc_use(_fake("forum:pip"), null)
	cards.pick(1)
	_check(
		nerds.karma == k0 and not cards.text.contains("karma"),
		"Free Play: no karma and no promise of it"
	)
	cards.pick(0)
	c.active = true

	# IRC: Grizzle grumbles, Pip shouts
	_check(
		(
			nerds.NICKS.has("GrizzleAdmin")
			and nerds.NICKS.has("HELPPLZ_Pip")
			and nerds.POSTERS.GrizzleAdmin == "ADMIN"
		),
		"both nicks are in the channel and on the forum"
	)
	var grumbled := 0
	var shouted := 0
	for i in 60:
		nerds.karma = 40
		nerds._lines = []
		nerds._last_ask = -999.0
		nerds.ask("which?", ["a fix", "b fix", "c fix", "d fix"], 1)
		for line in nerds._lines:
			if str(line[1]) == "GrizzleAdmin":
				for g in nerds.GRUMBLES:
					grumbled += 1 if str(line[2]).ends_with(str(g)) else 0
			if (
				str(line[1]) == "HELPPLZ_Pip"
				and str(line[2]) == str(line[2]).to_upper()
				and str(line[2]).ends_with("TOO")
			):
				shouted += 1
	_check(grumbled > 0, "Grizzle ends his answers with a grumble (%d)" % grumbled)
	_check(shouted > 0, "Pip answers in capitals (%d)" % shouted)
	# the next two regulars (R28): RTFM_Ray in the lobby, RegexRita in the hall; their chats pay out
	_check(
		spots.has("forum:ray") and spots["forum:ray"][0] == "resort_lobby" and spots.has("forum:rita") and spots["forum:rita"][0] == "resort_hall",
		"Ray is in the lobby and Rita in the hall"
	)
	for door in [37, 100, 263, 301]:
		_check(absf(float(spots["forum:ray"][1]) - float(door)) >= 25.0 or door == 100 and absf(float(spots["forum:ray"][1]) - 100.0) >= 25.0, "Ray is clear of x %d" % door)
	for id in ["ray", "rita"]:
		_check(not cf.forum_def(id).is_empty() and cf.forum_def(id).options.size() == 4, "%s has a chat with four options" % id)
	cf.reset()
	var n0: int = int(sk.xp.networking)
	cf.npc_use(_fake("forum:ray"), null)
	_check(cards.is_open and cards.speaker.begins_with("RTFM_Ray"), "E opens Ray's card")
	cards.pick(0)
	_check(int(sk.xp.networking) == n0 + 4, "Ray's page is +4 networking XP")
	cards.pick(0)
	cf.reset()
	var ps0: int = int(sk.xp.servers)
	cf.npc_use(_fake("forum:rita"), null)
	_check(cards.is_open and cards.speaker.begins_with("RegexRita"), "E opens Rita's card")
	cards.pick(0)
	_check(int(sk.xp.servers) == ps0 + 4, "Rita's one-liner is +4 servers XP")
	cards.pick(0)
	# two more regulars (R28): TapeTony in the breakout corridor between two doors, DNS_Dot in the vendor hall
	_check(
		spots.has("forum:tony") and spots["forum:tony"][0] == "resort_hall" and spots.has("forum:dot") and spots["forum:dot"][0] == "vendor_hall",
		"Tony is in the breakout corridor and Dot in the vendor hall"
	)
	for door in [41, 73, 143, 213, 283]:
		_check(absf(float(spots["forum:tony"][1]) - float(door)) >= 25.0, "Tony is clear of the door at x %d" % door)
	_check(absf(float(spots["forum:dot"][1]) - 327.0) >= 25.0, "Dot is clear of the vendor hall's door")
	for role in ["forum:tony", "forum:dot"]:
		for entry in cf.CROWD[spots[role][0]]:
			if str(entry.role) != role and not entry.has("seat") and not str(entry.routine).contains("walk"):
				_check(absf(float(entry.x) - float(spots[role][1])) >= 14.0, "%s does not stand in %s" % [role, entry.role])
	for id in ["tony", "dot"]:
		var def: Dictionary = cf.forum_def(id)
		_check(not def.is_empty() and def.options.size() == 4, "%s has a chat with four options" % id)
		var pays := {"skill": 0, "karma": 0, "social": 0}
		for o in def.get("options", []):
			pays.skill += 1 if str(o.get("skill", "")) != "" and int(o.get("xp", 0)) > 0 else 0
			pays.karma += 1 if int(o.get("karma", 0)) > 0 else 0
			pays.social += 1 if int(o.get("social", 0)) > 0 else 0
			_check(str(o.text) != "" and str(o.label) == str(o.label).to_upper(), "%s / %s has a label in capitals and a text" % [id, o.id])
		_check(pays.skill == 2 and pays.karma == 1 and pays.social == 1, "%s pays like the other regulars: two skills, karma, a social point (%s)" % [id, str(pays)])
	cf.reset()
	var tony0: int = int(sk.xp.servers)
	cf.npc_use(_fake("forum:tony"), null)
	_check(cards.is_open and cards.speaker.begins_with("TapeTony"), "E opens Tony's card")
	cards.pick(0)
	_check(int(sk.xp.servers) == tony0 + 4, "Tony's rotation is +4 servers XP")
	cards.pick(0)
	cf.reset()
	var dot0: int = int(sk.xp.networking)
	cf.npc_use(_fake("forum:dot"), null)
	_check(cards.is_open and cards.speaker.begins_with("DNS_Dot"), "E opens Dot's card")
	cards.pick(0)
	_check(int(sk.xp.networking) == dot0 + 4, "Dot's lookup is +4 networking XP")
	cards.pick(0)
	# they post on the forum too: a title under the nick and a reply each in an open thread
	var posted := {"TapeTony": 0, "DNS_Dot": 0}
	for th in nerds.THREADS:
		for post in th.get("posts", []):
			if posted.has(str(post.by)):
				posted[str(post.by)] += 1
	_check(nerds.POSTERS.has("TapeTony") and nerds.POSTERS.has("DNS_Dot"), "both have a forum title")
	_check(posted.TapeTony >= 1 and posted.DNS_Dot >= 1, "both have a post on the forum (%s)" % str(posted))
	# WSUS_Walt (R28 again): the patching regular in the lobby, a card that pays like the others, a title and a post
	_check(spots.has("forum:walt") and spots["forum:walt"][0] == "resort_lobby", "Walt is in the lobby")
	for door in [37, 301, 263]:
		_check(absf(float(spots["forum:walt"][1]) - float(door)) >= 25.0, "Walt is clear of the lobby door at x %d" % door)
	var wdef: Dictionary = cf.forum_def("walt")
	_check(not wdef.is_empty() and wdef.options.size() == 4, "walt has a chat with four options")
	cf.reset()
	var w0: int = int(sk.xp.servers)
	cf.npc_use(_fake("forum:walt"), null)
	_check(cards.is_open and cards.speaker.begins_with("WSUS_Walt"), "E opens Walt's card")
	cards.pick(0)
	_check(int(sk.xp.servers) == w0 + 4, "Walt's patch window is +4 servers XP")
	cards.pick(0)
	var walt_posts := 0
	for th in nerds.THREADS:
		for post in th.get("posts", []):
			walt_posts += 1 if str(post.by) == "WSUS_Walt" else 0
	_check(nerds.POSTERS.has("WSUS_Walt") and walt_posts >= 1, "Walt has a forum title and a post")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
