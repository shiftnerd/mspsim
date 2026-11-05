extends SceneTree
# gdlint:disable=class-definitions-order,max-line-length
# The event deck (roadmap R8): schema and balance guard, seeded draws, cooldowns, quiet days only, saves,
# showing and resolving the cards, and the 17 extra vignettes that share the draw.

var failures := 0

# real products and companies that the deck must not name (Dropbox, Chromebook, Windows and Exchange are
# era context and are allowed)
const DENY := [
	"google",
	"apple",
	"samsung",
	"dell",
	"hewlett",
	"canon",
	"xerox",
	"ricoh",
	"epson",
	"lexmark",
	"comcast",
	"verizon",
	"amazon",
	"ebay",
	"facebook",
	"twitter",
	"netflix",
	"starbucks",
	"walmart",
	"costco",
	"fedex",
	"iphone",
	"ipad",
	"android",
	"youtube",
	"skype",
	"slack",
	"zoom",
	"whatsapp",
	"instagram",
	"office 365",
	"windows 10",
	"covid",
	"pandemic",
	"cloudflare",
	"wifi password manager",
	"artificial",
	"chatgpt",
]


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _texts(card: Dictionary) -> String:
	var out := str(card.get("speaker", "")) + " " + str(card.get("text", ""))
	for o in card.get("options", []):
		out += " " + str(o.get("label", "")) + " " + str(o.get("text", ""))
	return out.to_lower()


func _sequence(ev: Node, mode_days: int) -> Array:
	var out := []
	for d in range(1, mode_days + 1):
		ev.begin_day(d)
		out.append(str(ev.pending.get("id", "")))
	return out


func _new(c: Node, cards: Node, mode: String) -> void:
	c.new_game(mode)
	for i in 20:
		if cards.is_open:
			for k in cards.options.size():
				cards.pick(k)
				if not cards.is_open or cards.speaker != "":
					break
		else:
			break


func _new_drain(cards: Node) -> void:
	for i in 20:
		if not cards.is_open:
			break
		cards.pick(0)


func _init() -> void:
	await process_frame
	var ev := root.get_node("Events")
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	var cards := root.get_node("Cards")
	var diff := root.get_node("Difficulty")
	var sales := root.get_node("Sales")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- the table
	_check(ev.DECK.size() >= 40, "the deck has 40 or more cards (%d)" % ev.DECK.size())
	var problems: Array = ev.validate_all()
	for p in problems:
		print("     problem: " + str(p))
	_check(problems.is_empty(), "every card passes the schema and the balance guard (%d problems)" % problems.size())
	var kinds := {"tech": 0, "owner": 0, "both": 0}
	for id in ev.DECK:
		kinds[str(ev.DECK[id].kinds[0])] += 1
	_check(kinds.tech >= 10 and kinds.owner >= 8 and kinds.both >= 10, "cards for both campaigns: %s" % str(kinds))
	var drawn_vignettes := []
	var fixed_vignettes := []
	for id in story.VIGNETTES:
		(drawn_vignettes if story.VIGNETTES[id].has("min_day") else fixed_vignettes).append(id)
	_check(story.VIGNETTES.size() == 25, "the vignette deck has 25 cards (%d)" % story.VIGNETTES.size())
	_check(fixed_vignettes.size() == 8 and drawn_vignettes.size() == 17, "8 fixed and 17 drawn vignettes")
	for id in ["iphone", "heartbleed", "candy", "pizza", "win8", "selfreview", "donuts", "invoice"]:
		_check(not story.VIGNETTES[id].has("min_day"), "%s stays on its fixed day" % id)
	var ids := {}
	for id in ev.DECK:
		_check(not story.VIGNETTES.has(id), "%s is not also a vignette id" % id)
	for id in ev.DECK:
		ids[id] = true

	# the guard really catches bad cards
	var good: Dictionary = ev.DECK.toner_late.duplicate(true)
	var bad_xp := good.duplicate(true)
	bad_xp.options[0].fx = {"xp": ["servers", 9]}
	_check(not ev.violations(bad_xp).is_empty(), "xp 9 is refused")
	var bad_key := good.duplicate(true)
	bad_key.options[0].fx = {"teleport": 1}
	_check(not ev.violations(bad_key).is_empty(), "an unknown fx key is refused")
	var bad_mood := good.duplicate(true)
	bad_mood.options[0].fx = {"mood": [1, -20]}
	_check(not ev.violations(bad_mood).is_empty(), "mood -20 is refused")
	var bad_rep := good.duplicate(true)
	bad_rep.options[0].fx = {"rep": 3}
	_check(not ev.violations(bad_rep).is_empty(), "rep +3 is refused")
	var bad_energy := good.duplicate(true)
	bad_energy.options[0].fx = {"energy": -12}
	_check(not ev.violations(bad_energy).is_empty(), "energy -12 is refused")
	var one := good.duplicate(true)
	one.options = [one.options[0]]
	_check(not ev.violations(one).is_empty(), "a card with one option is refused")
	var four: Dictionary = good.duplicate(true)
	four.options.append(four.options[0].duplicate(true))
	four.options.append(four.options[0].duplicate(true))
	_check(not ev.violations(four).is_empty(), "a card with four options is refused")
	var cash_on_tech := good.duplicate(true)
	cash_on_tech.kinds = ["tech"]
	cash_on_tech.options[0].fx = {"cash": 100}
	_check(not ev.violations(cash_on_tech).is_empty(), "cash on a tech card is refused")
	var maya_owner := good.duplicate(true)
	maya_owner.kinds = ["owner"]
	maya_owner.text = "Maya wants a word."
	_check(not ev.violations(maya_owner).is_empty(), "Maya on an owner card is refused")
	var morgan_both := good.duplicate(true)
	morgan_both.text = "Morgan wants a word."
	_check(not ev.violations(morgan_both).is_empty(), "Morgan on a both card is refused")
	var trap := good.duplicate(true)
	for o in trap.options:
		o.fx = {"rep": -1}
	_check(not ev.violations(trap).is_empty(), "a card with no safe option is refused")
	var bad_day := good.duplicate(true)
	bad_day.min_day = 12
	bad_day.max_day = 4
	_check(not ev.violations(bad_day).is_empty(), "min_day after max_day is refused")
	var bad_social := good.duplicate(true)
	bad_social.options[0].fx = {"social": {"Nobody": 1}}
	_check(not ev.violations(bad_social).is_empty(), "a social change for a stranger is refused")
	var bad_vig: Dictionary = story.VIGNETTES.captcha.duplicate(true)
	bad_vig.options[0].fx = {"mood": [1, 30]}
	_check(not ev.vignette_violations("captcha", bad_vig).is_empty(), "a drawn vignette is held to the same bounds")

	# ---- period and brand deny-list
	var banned := ["slack", " ai ", "microsoft teams", "windows 10", "tiktok", "discord", "zoom call", "mfa "]
	var hits := []
	var all_cards := []
	for id in ev.DECK:
		all_cards.append(ev.DECK[id])
	for id in drawn_vignettes:
		all_cards.append(story.VIGNETTES[id])
	for card in all_cards:
		var t := _texts(card)
		for word in DENY:
			if t.contains(word):
				hits.append("%s: %s" % [str(card.get("id", card.get("speaker", ""))), word])
		for word in banned:
			if t.contains(word):
				hits.append("%s: %s" % [str(card.get("id", card.get("speaker", ""))), word])
	_check(hits.is_empty(), "no real brand names or 2015+ words in the cards: %s" % str(hits))

	# ---- drawing: same seed, same sequence
	_new(c, cards, "tech")
	diff.seed_run(4242)
	ev.reset()
	var first: Array = _sequence(ev, 20)
	diff.seed_run(4242)
	ev.reset()
	var second: Array = _sequence(ev, 20)
	_check(first == second, "the same seed gives the same 20 days: %s" % str(first))
	var drawn := 0
	for id in first:
		if id != "":
			drawn += 1
			_check(ids.has(id) or story.VIGNETTES.has(id), "%s is a real card" % id)
	_check(drawn >= 5 and drawn <= 16, "a run draws some cards but not every day (%d)" % drawn)
	var other_differs := false
	for seed_n in [1, 2, 3, 4, 5]:
		diff.seed_run(seed_n)
		ev.reset()
		if _sequence(ev, 20) != first:
			other_differs = true
	_check(other_differs, "other seeds give other sequences")
	_check(first[0] == "" and first[1] == "" and first[19] == "", "no card on days 1, 2 or the last day")

	# ---- cooldown, once-per-run vignettes, kinds, day windows (many seeds)
	var cool_ok := true
	var once_ok := true
	var window_ok := true
	var kind_ok := true
	var mood_cards := 0
	for mode in ["tech", "owner"]:
		_new(c, cards, mode)
		for seed_n in range(1, 41):
			diff.seed_run(seed_n * 77)
			ev.reset()
			var seen_day := {}
			var seen_vig := {}
			for d in range(1, 21):
				ev.begin_day(d)
				if ev.pending.is_empty():
					continue
				var id := str(ev.pending.id)
				if ev.pending.deck == "event":
					var card: Dictionary = ev.DECK[id]
					if seen_day.has(id) and d - int(seen_day[id]) < int(card.cooldown):
						cool_ok = false
					seen_day[id] = d
					if d < int(card.min_day) or d > int(card.max_day):
						window_ok = false
					if not (card.kinds.has(mode) or card.kinds.has("both")):
						kind_ok = false
				else:
					if seen_vig.has(id) or mode != "tech":
						once_ok = false
					seen_vig[id] = true
					if d < int(story.VIGNETTES[id].min_day):
						window_ok = false
				mood_cards += 1
	_check(cool_ok, "a card is never drawn again inside its cooldown (80 runs)")
	_check(once_ok, "a drawn vignette comes once per run, in the tech campaign only")
	_check(window_ok, "cards stay inside their day windows")
	_check(kind_ok, "tech cards stay in the tech campaign, owner cards in the owner campaign")

	# ---- quiet days only
	_new(c, cards, "tech")
	var busy_days := []
	for d in story.DAYS:
		for e in story.DAYS[d]:
			if str(e.kind) == "vignette" or str(e.kind) == "ransomware":
				busy_days.append(int(d))
	for d in [5, 10, 15]:
		busy_days.append(d)  # outings
	busy_days.append(13)  # the overtime night
	busy_days.append(17)  # the conference trip
	busy_days.append(20)
	root.get_node("Expo").qualified = true
	var quiet_clean := true
	for seed_n in range(1, 31):
		diff.seed_run(seed_n * 131)
		ev.reset()
		for d in busy_days:
			ev.begin_day(d)
			if not ev.pending.is_empty():
				quiet_clean = false
				print("     busy day %d drew %s" % [d, ev.pending.id])
	root.get_node("Expo").qualified = false
	_check(quiet_clean, "no card on a day with a story vignette, the ransomware, an outing, the night or the trip")
	_check(not ev.quiet_day(1, "tech") and not ev.quiet_day(2, "tech"), "the gentle first days are quiet")
	_check(ev.quiet_day(6, "tech"), "an ordinary day (6) can draw")
	_new(c, cards, "owner")
	_check(not ev.quiet_day(4, "owner") and not ev.quiet_day(19, "owner"), "owner outing weeks do not draw")
	_check(not ev.quiet_day(9, "owner") and not ev.quiet_day(13, "owner"), "the ransomware and email weeks do not draw")
	var owner_quiet := 0
	for d in range(1, 21):
		if ev.quiet_day(d, "owner"):
			owner_quiet += 1
	_check(owner_quiet >= 4, "the owner campaign has quiet weeks to draw on (%d)" % owner_quiet)

	# ---- Free Play never draws
	_new(c, cards, "free")
	diff.seed_run(9)
	ev.reset()
	for d in range(1, 21):
		ev.begin_day(d)
	_check(ev.pending.is_empty() and ev.draws == 0, "Free Play draws nothing")

	# ---- saving: old saves, round trip, and the stream picks up where it left off
	ev.from_dict({})
	_check(ev.draws == 0 and ev.last.is_empty() and ev.recent.is_empty(), "an old save (no events section) starts empty")
	_new(c, cards, "tech")
	diff.seed_run(555)
	ev.reset()
	var whole: Array = _sequence(ev, 20)
	diff.seed_run(555)
	ev.reset()
	var head: Array = _sequence(ev, 10)
	var saved: Dictionary = ev.to_dict()
	_check(int(saved.version) == 1 and int(saved.draws) == ev.draws and saved.last.size() > 0, "to_dict keeps draws and recent ids")
	diff.seed_run(555)  # a continued run restarts its streams from the seed
	ev.from_dict(saved)
	var tail := []
	for d in range(11, 21):
		ev.begin_day(d)
		tail.append(str(ev.pending.get("id", "")))
	_check(head + tail == whole, "a continued run draws the same cards as an unbroken one")
	var tmp_prefix := "user://test_%d_ev_" % OS.get_process_id()
	c.save_prefix = tmp_prefix
	_new(c, cards, "tech")
	ev.draws = 3
	ev.last = {"toner_late": 4}
	ev.recent = ["toner_late"]
	c.save()
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("tech"))
	_check(cfg.has_section_key("campaign", "events"), "the campaign save has an events section")
	ev.reset()
	c.continue_game("tech")
	_check(ev.draws >= 3 and ev.last.has("toner_late"), "continue restores the draw counter and recent ids")
	cfg.erase_section_key("campaign", "events")
	cfg.save(c.save_path("tech"))
	c.continue_game("tech")
	_check(ev.draws <= 1, "a save without the section loads with defaults")
	DirAccess.remove_absolute(c.save_path("tech"))

	# ---- the roster: nobody who is not in the campaign
	_new(c, cards, "tech")
	var tech_roster: Array = ev.roster()
	_check(tech_roster.has("Maya") and tech_roster.has("Dan") and not tech_roster.has("Alan") and not tech_roster.has("Garrison"), "tech roster: the coworkers, not the owners: %s" % str(tech_roster))
	_new(c, cards, "owner")
	var owner_roster: Array = ev.roster()
	_check(not owner_roster.has("Maya") and owner_roster.has("Dan"), "owner roster: Maya is not on payroll: %s" % str(owner_roster))
	for id in ev.DECK:
		var card: Dictionary = ev.DECK[id]
		var text := _texts(ev.resolve(card, "Dan"))
		_check(not text.contains("{c}"), "%s: no placeholder is left after resolving" % id)
		if card.kinds.has("owner"):
			_check(not text.contains("maya") and not text.contains("morgan"), "%s: no Maya or Morgan in an owner card" % id)

	# ---- showing and resolving every card in the right campaign
	_new(c, cards, "tech")
	var skills := root.get_node("Skills")
	var shown_ok := true
	for id in ev.DECK:
		var card: Dictionary = ev.DECK[id]
		if not (card.kinds.has("tech") or card.kinds.has("both")):
			continue
		for i in card.options.size():
			world.clock = 10.0
			ev.show_draw({"deck": "event", "id": id, "who": "Dan"})
			await process_frame
			shown_ok = shown_ok and cards.is_open
			cards.pick(i)
			await process_frame
			shown_ok = shown_ok and cards.is_open  # the result card
			cards.pick(0)
			await process_frame
			shown_ok = shown_ok and not cards.is_open
	_check(shown_ok, "every tech / both card opens, resolves and closes (each option)")
	_new(c, cards, "owner")
	world.clock = 9.5  # let the week's own opening cards come and go first
	await process_frame
	await process_frame
	_new_drain(cards)
	shown_ok = true
	for id in ev.DECK:
		var card: Dictionary = ev.DECK[id]
		if not (card.kinds.has("owner") or card.kinds.has("both")):
			continue
		for i in card.options.size():
			world.clock = 9.6
			ev.show_draw({"deck": "event", "id": id, "who": "Dan"})
			await process_frame
			shown_ok = shown_ok and cards.is_open
			cards.pick(i)
			await process_frame
			cards.pick(0)
			await process_frame
			if cards.is_open:
				print("     still open after %s/%s: %s" % [id, i, cards.text])
				_new(c, cards, "owner")
			shown_ok = shown_ok and not cards.is_open
	_check(shown_ok, "every owner / both card opens, resolves and closes (each option)")

	# ---- the fx really apply
	_new(c, cards, "tech")
	var mood_before: int = sales.mood(2)
	var xp_before: int = int(skills.xp.get("servers", 0))
	world.clock = 10.0
	ev.show_draw({"deck": "event", "id": "cold_snap", "who": "Dan"})
	await process_frame
	cards.pick(0)
	await process_frame
	cards.pick(0)
	await process_frame
	_check(sales.mood(2) == mood_before + 3, "cold snap: client mood +3")
	_check(int(skills.xp.get("servers", 0)) == xp_before + 3, "cold snap: +3 servers XP")
	_check(absf(world.clock - 10.3) < 0.01, "cold snap: the hours move the clock")
	world.clock = 16.0
	ev.apply_fx({"hours": 0.6})
	_check(absf(world.clock - 16.0) < 0.01, "late in the day a card does not push the clock")
	_new(c, cards, "owner")
	var owner := root.get_node("Owner")
	var cash_before: int = owner.cash
	ev.show_draw({"deck": "event", "id": "payroll_error", "who": "Dan"})
	await process_frame
	cards.pick(0)
	await process_frame
	cards.pick(0)
	await process_frame
	_check(owner.cash == cash_before + 220, "owner card: cash +220")
	var burn_before: float = owner.burnout
	ev.apply_fx({"burnout": 3, "xp": ["servers", 4], "energy": -5})
	_check(is_equal_approx(owner.burnout, burn_before + 3.0), "owner card: burnout moves, XP and energy are ignored")

	# ---- a drawn vignette and the timing of a draw
	_new(c, cards, "tech")
	ev.show_draw({"deck": "vignette", "id": "captcha"})
	await process_frame
	_check(cards.is_open and cards.speaker == story.VIGNETTES.captcha.speaker, "a drawn vignette opens the vignette card")
	cards.pick(0)
	await process_frame
	cards.pick(0)
	await process_frame
	diff.seed_run(31)
	ev.reset()
	var day := 6
	ev.begin_day(day)
	_check(not ev.pending.is_empty(), "day 6 draws a card")
	var at := float(ev.pending.at)
	_check(at >= 10.0 and at <= 13.6, "the card is set for between 10:00 and 13:30 (%s)" % str(at))
	var due_id := str(ev.pending.id)
	world.clock = at - 0.5
	world.time_scale = 1.0
	ev._process(0.0)
	_check(not cards.is_open and not ev.pending.is_empty(), "it waits for its time")
	world.clock = at + 0.1
	ev._process(0.0)
	await process_frame
	_check(cards.is_open and ev.last_shown == due_id and ev.pending.is_empty(), "it shows once the clock passes")
	cards.pick(0)
	await process_frame
	cards.pick(0)
	await process_frame
	ev.begin_day(6)
	world.clock = 16.0
	ev._process(0.0)
	_check(ev.pending.is_empty() and not cards.is_open, "a card that never got its moment is dropped late in the day")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
