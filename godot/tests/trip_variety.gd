extends SceneTree
# gdlint:disable=class-variable-name,max-line-length
# Rodent Nation variety (R11): seeded session menus, vendor booths, attendee conversations and raffle odds per run,
# with the KPIs and the XP per session untouched.

var failures := 0
var TV: Variant = null


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _ids(list: Array) -> String:
	var out: Array = []
	for s in list:
		out.append(str(s.id))
	return ",".join(PackedStringArray(out))


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var cf := root.get_node("Expo")
	TV = cf.Trip
	var cards := root.get_node("Cards")
	var d := root.get_node("Difficulty")
	var sk := root.get_node("Skills")
	var career := root.get_node("Career")
	root.get_node("Game").title_mode = false
	career.toasts = false
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	c.new_game("tech")
	while cards.is_open:
		cards.pick(cards.options.size() - 1)

	# ---- the pool
	var skills_ok := ["powershell", "networking", "servers", "security", "people"]
	var ids := {}
	for r in cf.ROUNDS.size():
		for s in cf.pool(r):
			_check(not ids.has(str(s.id)), "session id %s is unique" % s.id)
			ids[str(s.id)] = true
			_check(str(s.skill) in skills_ok and int(s.xp) <= 8 and str(s.text).length() > 40, "%s has a valid skill, xp <= 8 and text" % s.id)
	_check(cf.pool(0).size() >= 6 and cf.pool(1).size() >= 6 and cf.pool(2).size() >= 6, "every round has at least six sessions to draw from")

	# ---- menus
	var menus0 := {}
	var seen_extra := {}
	for seed_n in range(1, 41):
		d.seed_run(seed_n)
		for r in 3:
			var menu: Array = cf.menu(r)
			var seen := {}
			for s in menu:
				seen[str(s.id)] = true
				if TV.MORE_SESSIONS[r].any(func(e: Dictionary) -> bool: return str(e.id) == str(s.id)):
					seen_extra[str(s.id)] = true
			if menu.size() != 4 or seen.size() != 4:
				_check(false, "seed %d round %d has four different sessions: %s" % [seed_n, r, _ids(menu)])
			if r == 0:
				menus0[_ids(menu)] = true
				if str(menu[0].id) != "ps101":
					_check(false, "the scripting lab keeps room A (seed %d)" % seed_n)
			if r == 1 and str(menu[1].id) != "security":
				_check(false, "the security session keeps room B (seed %d)" % seed_n)
	_check(menus0.size() >= 4, "round one has %d different menus over 40 runs" % menus0.size())
	_check(seen_extra.size() >= 5, "the new sessions turn up (%d of 6)" % seen_extra.size())
	d.seed_run(9)
	var a: String = _ids(cf.menu(2))
	d.seed_run(9)
	_check(_ids(cf.menu(2)) == a, "the same seed gives the same menu")
	d.seed_run(10)
	var other := false
	for seed_n in range(11, 30):
		d.seed_run(seed_n)
		other = other or _ids(cf.menu(2)) != a
	_check(other, "other seeds differ")

	# ---- the easel and the door follow the menu
	d.seed_run(21)
	cf.away = true
	cf._stage = "round"
	cf.rnd = 0
	var m: Array = cf.menu(0)
	var lines: Array = cf.sign_lines(2)
	_check(lines.size() > 0 and str(m[2].get("short", m[2].label)).begins_with(str(lines[0]).split(" ")[0]), "the easel of room C shows its session (%s)" % str(lines))
	root.get_node("Game").vars["conf_door"] = "from_c"
	var picks0: int = cf.picks.size()
	cf._enter_breakout()
	_check(cards.is_open and cf.picks.size() == picks0 + 1 and str(cf.picks[-1]) == str(m[2].id), "room C starts the session on the easel")
	var sess0: int = career.value("sessions_seen")
	cards.pick(0)
	_check(sess0 >= 1 and career.value("sessions_seen") >= 1, "a new session counts for the career")
	cf.rnd = 0
	cf.picks = []

	# ---- XP is unchanged for the pooled sessions
	var net0: int = int(sk.xp.networking)
	var sec0: int = int(sk.xp.security)
	cf._session(2, "ransom")
	cards.pick(0)
	_check(int(sk.xp.security) == sec0 + 8, "a new session gives the same 8 XP")
	cf._session(0, "macs")
	cards.pick(0)
	_check(int(sk.xp.networking) == net0 + 8, "... in its own skill")

	# ---- vendors
	for id in TV.VENDOR_IDS:
		_check(not cf._vendor(id).is_empty() and cf._vendor(id).options.size() == 4, "vendor %s has a pitch with four answers" % id)
	var combos := {}
	for seed_n in range(1, 41):
		d.seed_run(seed_n)
		var v: Array = TV.trip_vendors()
		var uniq := {}
		for id in v:
			uniq[id] = true
		if v.size() != 3 or uniq.size() != 3:
			_check(false, "three different vendors (seed %d)" % seed_n)
		combos[",".join(PackedStringArray(v))] = true
	_check(combos.size() >= 4, "%d different vendor sets over 40 runs" % combos.size())
	d.seed_run(33)
	var crowd: Array = TV.remap_crowd(cf.CROWD["vendor_hall"], "vendor_hall")
	var roles := []
	var xs := {}
	for e in crowd:
		if str(e.role).begins_with("vendor:"):
			roles.append(str(e.role).substr(7))
			xs[int(e.x)] = true
			_check(str(e.who) == str(TV.VENDOR_LOOK[str(e.role).substr(7)]), "booth %s has its own look" % e.role)
	_check(roles.size() == 3 and xs.size() == 3 and roles == TV.trip_vendors(), "three booths at three spots with this year's vendors")
	_check(TV.remap_crowd(cf.CROWD["resort_lobby"], "resort_lobby") == cf.CROWD["resort_lobby"], "other rooms are untouched")
	var sec1: int = int(sk.xp.networking)
	cf._met = {}
	cf._pitch("voip")
	_check(cards.is_open and cards.options.size() == 4, "the new vendor pitches")
	cards.pick(0)
	cards.pick(0)
	_check(int(sk.xp.networking) == sec1 + 6, "his demo teaches 6 networking XP")
	var spam0: int = cf.spam
	cf._pitch("rmmx")
	cards.pick(2)
	cards.pick(0)
	_check(cf.spam == spam0 + 1 and cf.entries >= 1, "scanning a new vendor's badge is a raffle entry and spam")

	# ---- attendees
	var chat_sets := {}
	var extra_seen := {}
	for seed_n in range(1, 41):
		d.seed_run(seed_n)
		var slots: Array = TV.chat_slots(cf.CHATS)
		var speakers := {}
		for i in slots.size():
			speakers[str(slots[i].speaker)] = true
			var base_g: String = TV.SLOT_GENDER[i]
			var found_g := ""
			for e in TV.EXTRA_CHATS:
				if str(e.speaker) == str(slots[i].speaker):
					found_g = str(e.gender)
					extra_seen[str(e.speaker)] = true
			for k in cf.CHATS.size():
				if str(cf.CHATS[k].speaker) == str(slots[i].speaker):
					found_g = TV.SLOT_GENDER[k]
			if found_g != base_g:
				_check(false, "slot %d keeps the gender of its sprite (seed %d)" % [i, seed_n])
		if slots.size() != 6 or speakers.size() != 6:
			_check(false, "six different conversations (seed %d)" % seed_n)
		chat_sets[",".join(PackedStringArray(speakers.keys()))] = true
	_check(chat_sets.size() >= 4 and extra_seen.size() >= 2, "%d different attendee sets, %d of 3 new people met" % [chat_sets.size(), extra_seen.size()])
	d.seed_run(5)
	var karma0: int = root.get_node("Nerds").karma
	cf._talked = {}
	var cards0: int = cf.cards_swapped
	for i in 6:
		var chat: Dictionary = cf.chat_def(i)
		_check(chat.options.size() == 3 and str(chat.options[1].id) == "cards", "attendee %d offers learn / swap cards / bye" % i)
	cf._chat(1)
	cards.pick(1)
	cards.pick(0)
	_check(cf.cards_swapped == cards0 + 1 and root.get_node("Nerds").karma > karma0, "swapping cards works with any attendee")

	# ---- the raffle
	var bases := {}
	for seed_n in range(1, 41):
		d.seed_run(seed_n)
		bases[TV.raffle_base()] = true
	_check(bases.size() >= 3, "raffle odds vary by run (%s)" % str(bases.keys()))
	for b in bases:
		_check(b >= 0.06 and b <= 0.12, "base odds %.2f are fair" % b)
	d.seed_run(3)
	cf.entries = 3
	_check(cf.raffle_odds() <= 0.24 and cf.raffle_odds() >= 0.18, "three scans add 12 percent (%.2f)" % cf.raffle_odds())
	_check(TV.drum_line(0.06) != "" and TV.drum_line(0.12) != "" and TV.drum_line(0.08) == "", "a light or packed drum is mentioned")
	var wins0: int = career.value("raffle_wins")
	for seed_n in range(100, 160):
		if career.value("raffle_wins") > wins0:
			break
		d.seed_run(seed_n)
		cf.entries = 3
		cf._raffle()
		while cards.is_open:
			cards.pick(cards.options.size() - 1)
	_check(career.value("raffle_wins") > wins0, "the raffle can be won and is counted")

	# ---- the KPIs are untouched
	cf.reset()
	cf.tot_closed = 20
	cf.tot_missed = 2
	cf.tot_reopened = 1
	c.rep = 70
	sk.ps_level = 2
	_check(cf.kpis().size() == 4 and cf.passed() == 4, "the four KPIs and the pass mark are as before")
	cf.qualified = true
	c.day = cf.TRIP_DAY
	var trips0: int = career.value("trips")
	cf._on_day(cf.TRIP_DAY)
	_check(career.value("trips") == trips0 + 1, "the trip is counted for the career")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
