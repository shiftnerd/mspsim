extends SceneTree
# gdlint:disable=max-line-length
# X11: the second cast in the owner campaign. Jen and Michael each have three decision cards in the owner's weekly card flow with real
# effects (capacity, cash every week, payroll, mood, burnout, the partner's trust), and a save from before John and Christy (the old
# account manager's and bookkeeper's names as keys and values) loads with those names mapped.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		var idx := 0
		for i in cards.options.size():
			if bool(cards.options[i].get("enabled", true)):
				idx = i
				break
		cards.pick(idx)
		n += 1


func _start(mode: String, who: String) -> void:
	player_script.current_character = who
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(99)
	root.get_node("Campaign").new_game(mode)
	_clear(root.get_node("Cards"))


# every branch of an option: its fx, or the fx of each roll entry
func _branches(opt: Dictionary) -> Array:
	var out: Array = []
	if opt.has("fx"):
		out.append(opt.fx)
	for entry in opt.get("roll", []):
		out.append(entry[1])
	return out


# the reverse of the migration: put the old names back into a value (keys and exact strings)
func _age(v: Variant, back: Dictionary) -> Variant:
	if v is String:
		return back.get(v, v)
	if v is Array:
		for i in v.size():
			v[i] = _age(v[i], back)
		return v
	if v is Dictionary:
		for k in v.keys():
			v[k] = _age(v[k], back)
			if k is String and back.has(k):
				v[back[k]] = v[k]
				v.erase(k)
		return v
	return v


func _has_old(v: Variant, olds: Array) -> bool:
	if v is String:
		return olds.has(v)
	if v is Array:
		for item in v:
			if _has_old(item, olds):
				return true
	if v is Dictionary:
		for k in v:
			if (k is String and olds.has(k)) or _has_old(v[k], olds):
				return true
	return false


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var partner := root.get_node("Partner")
	var social := root.get_node("Social")
	player_script = load("res://scripts/player.gd")
	var cast: Script = load("res://scripts/owner_cast.gd")
	var mig: Script = load("res://scripts/save_migrate.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- the cards exist, sit in the owner's weeks and do something real
	_start("owner", "office_alan")
	var jen := 0
	var michael := 0
	var real_keys := ["cash", "speed", "weekly", "payroll", "mood_all", "burnout", "trust", "rep", "owner_hours", "social_all"]
	for id in cast.CARDS:
		var card: Dictionary = cast.CARDS[id]
		jen += 1 if str(card.speaker).begins_with("Jen") else 0
		michael += 1 if str(card.speaker).begins_with("Michael") else 0
		_check(o.CARDS.has(id) and (card.options as Array).size() == 3, "%s is an owner card with three options" % id)
		var all_real := true
		var moves_trust := false
		var moves_capacity_or_cash := false
		for opt in card.options:
			for fx in _branches(opt):
				var hit := false
				for k in real_keys:
					hit = hit or (fx as Dictionary).has(k)
				all_real = all_real and hit
				moves_trust = moves_trust or (fx as Dictionary).has("trust")
				moves_capacity_or_cash = moves_capacity_or_cash or fx.has("speed") or fx.has("weekly") or fx.has("payroll") or fx.has("cash")
		_check(all_real and moves_trust and moves_capacity_or_cash, "%s: every option has an effect, and the card moves trust and capacity or cash" % id)
	_check(jen == 3 and michael == 3, "three cards for Jen and three for Michael (%d / %d)" % [jen, michael])
	var placed := 0
	for day in cast.DAYS:
		for ev in cast.DAYS[day]:
			var found := false
			var clear := true
			for other in o.events_on(int(day)):
				if str(other.get("card", "")) == str(ev.card):
					found = true
				elif absf(float(other.at) - float(ev.at)) < 0.15:
					clear = false
			placed += 1 if found else 0
			_check(found and clear, "%s comes in week %d at %.1f, clear of the other events" % [str(ev.card), int(day), float(ev.at)])
	_check(placed == 6, "all six are placed")

	# ---- real effects through the card flow
	_check(partner.active(), "the other owner is there (trust moves)")
	var speed0: float = o.speed
	var trust0: int = partner.trust
	o.show_card("jen_intake")
	_check(cards.is_open and str(cards.speaker).begins_with("Jen") and cards.options.size() == 3, "Jen's intake card opens")
	cards.pick(0)
	_clear(cards)
	_check(absf(o.speed - (speed0 + 0.05)) < 0.001, "three questions on every call: the crew is 5 points faster")
	var weekly0: int = o.weekly_extra
	o.show_card("jen_phones")
	cards.pick(1)
	_clear(cards)
	_check(o.weekly_extra == weekly0 + 110, "the second voice costs $110 a week")
	var pay0: int = o.payroll_extra
	var speed1: float = o.speed
	o.show_card("michael_catch")
	_check(str(cards.speaker).begins_with("Michael"), "Michael's card opens")
	_check(str(cards.options[2].get("trust_chip", "")) == "TRUST DOWN" and str(cards.options[1].get("trust_chip", "")) == "TRUST UP", "the options show which way the partner's trust moves")
	cards.pick(2)
	_clear(cards)
	_check(o.payroll_extra == pay0 + 100 and absf(o.speed - (speed1 + 0.07)) < 0.001, "making escalations his job: payroll +$100, capacity +7 points")
	_check(partner.who() == "Garrison" and partner.trust_delta(cast.CARDS.michael_catch.options[2]) == -1, "Garrison, the other owner, likes that less (the card's own trust -1)")
	trust0 = partner.trust
	o.apply(cast.CARDS.michael_catch.options[1].fx)
	_check(partner.trust == trust0 + 1, "the cap on hand-offs moves the partnership up by one (trust %d -> %d)" % [trust0, partner.trust])
	var burn0: float = o.burnout
	o.burnout = 20.0
	o.show_card("jen_wall")
	cards.pick(0)
	_clear(cards)
	_check(absf(o.burnout - 14.0) < 0.001, "Jen as the wall: burnout -6")
	o.burnout = burn0
	var weekly1: int = o.weekly_extra
	var speed2: float = o.speed
	o.show_card("michael_offer")
	cards.pick(2)
	_clear(cards)
	_check(o.weekly_extra == weekly1 - 180 and absf(o.speed - (speed2 - 0.04)) < 0.001, "lending Michael out: $180 a week in, capacity -4 points")
	var cash0: int = o.cash
	o.show_card("michael_teach")
	cards.pick(0)
	_clear(cards)
	_check(o.cash == cash0 - 150, "the Friday hour costs $150")

	# ---- the migration itself
	var olds := [mig.OLD_SALES, mig.OLD_BOOKS, mig.OLD_SALES + " Marlowe", "office_" + mig.OLD_SALES.to_lower(), "office_" + mig.OLD_BOOKS.to_lower()]
	var count := [0]
	var sample: Dictionary = {mig.OLD_SALES: 61, "list": [mig.OLD_BOOKS, "Alan", {"who": mig.OLD_SALES + " Marlowe"}], "text": "%s said hello." % mig.OLD_SALES, "John": 5}
	sample = mig.fix(sample, count)
	_check(int(sample.John) == 5 and not sample.has(mig.OLD_SALES), "a save with both names keeps the new one's value")
	_check(sample.list[0] == "Christy" and sample.list[2].who == "John Marlowe", "names inside lists and nested tables are mapped")
	_check(str(sample.text).begins_with(mig.OLD_SALES), "a sentence that mentions the old name is left alone")
	_check(int(count[0]) == 3, "three renames counted (%d)" % int(count[0]))

	# ---- an old save: the old names as keys and values everywhere, loaded without errors
	for mode_who in [["owner", "office_alan"], ["sales", "office_john"], ["service", "office_dan"]]:
		var mode := str(mode_who[0])
		_start(mode, str(mode_who[1]))
		social.rel["John"] = 77
		o.flags["talked_John"] = 3
		c.save()
		var cfg := ConfigFile.new()
		_check(cfg.load(c.save_path(mode)) == OK, "%s: the save is written" % mode)
		var back := {}
		for k in mig.MAP:
			back[mig.MAP[k]] = k
		for section in cfg.get_sections():
			for key in cfg.get_section_keys(section):
				cfg.set_value(section, key, _age(cfg.get_value(section, key), back))
		var seeded := false
		for section in cfg.get_sections():
			for key in cfg.get_section_keys(section):
				seeded = seeded or _has_old(cfg.get_value(section, key), olds)
		_check(seeded, "%s: the file now holds the old names" % mode)
		cfg.save(c.save_path(mode))
		social.rel["John"] = 50
		_check(c.continue_game(mode), "%s: the old save loads" % mode)
		_clear(cards)
		_check(int(social.rel.get("John", -1)) == 77 and not social.rel.has(mig.OLD_SALES), "%s: the old account manager's standing is John's" % mode)
		c.save()
		var again := ConfigFile.new()
		again.load(c.save_path(mode))
		var left := false
		for section in again.get_sections():
			for key in again.get_section_keys(section):
				left = left or _has_old(again.get_value(section, key), olds)
		_check(not left, "%s: saved again, no old name is left" % mode)
		_check(player_script.CHARACTERS.has(player_script.current_character), "%s: the player is a real character (%s)" % [mode, player_script.current_character])

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
