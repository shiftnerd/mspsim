extends SceneTree
# X5: the partner model. Trust 0-100, stance chips derived from effect tags, trust moves, the four partner meetings with
# real effects, the veto at low trust, the partner walking out at zero, and every ending reachable through the board review.
# Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 30:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1


func _start(character: String) -> void:
	player_script.current_character = character
	root.get_node("Game").title_mode = false
	root.get_node("Campaign").new_game("owner")
	_clear(root.get_node("Cards"))


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var partner := root.get_node("Partner")
	var review := root.get_node("Review")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- stance chips come from the card's effect tags and the partner's priorities
	_start("office_alan")
	_check(partner.who() == "Garrison" and partner.trust == partner.START_TRUST, "as Alan the partner is Garrison, trust starts at 55")
	var welcome: Array = o.CARDS["welcome"].options
	_check(partner.stance(welcome[2], "Alan") == "oppose", "Alan opposes premium pricing")
	_check(partner.stance(welcome[2], "Garrison") == "warn", "Garrison warns about premium pricing")
	_check(partner.stance(welcome[0], "Garrison") == "agree", "Garrison agrees with volume pricing")
	_check(partner.stance(welcome[1], "Garrison") == "" and partner.stance(welcome[1], "Alan") == "", "standard pricing: no opinion")
	_check(partner.stance(o.CARDS["backup"].options[0], "Alan") == "agree", "Alan agrees with the backup service")
	var mkt: Array = o.CARDS["marketing"].options
	_check(partner.stance(mkt[mkt.size() - 1], "Garrison") == "agree", "Garrison agrees with aggressive marketing")
	_check(partner.stance(mkt[mkt.size() - 1], "Alan") in ["warn", "oppose"], "Alan does not like aggressive marketing")
	var chips := 0
	var total := 0
	for id in o.CARDS:
		for opt in o.CARDS[id].options:
			total += 1
			if partner.stance(opt, "Alan") != "" or partner.stance(opt, "Garrison") != "":
				chips += 1
	_check(chips > total / 8 and chips < total * 3 / 4, "the partner has an opinion on a good share of options (%d of %d)" % [chips, total])
	# the chip shows on the card
	o.show_card("welcome")
	var shown := ""
	for opt in cards.options:
		shown += str(opt.get("chip", "")) + "|"
	_check(cards.options[2].get("stance", "") == "warn" and str(cards.options[2].chip) == "G WARNS" and shown != "||||", "the card shows the partner's chip: " + shown)
	_clear(cards, 1)

	# ---- trust moves with your choices
	_start("casual_garrison")
	_check(partner.who() == "Alan", "as Garrison the partner is Alan")
	var t0: int = partner.trust
	o.show_card("backup")
	cards.pick(0)  # the backup service: Alan agrees
	_clear(cards)
	_check(partner.trust == t0 + 2 and partner.follows == 1, "following their call: trust +2")
	t0 = partner.trust
	o.show_card("welcome")
	cards.pick(2)  # premium pricing: Alan opposes
	_clear(cards)
	_check(partner.trust == t0 - 3 and partner.overrides == 1, "overriding them: trust -3")
	t0 = partner.trust
	o.show_card("welcome")
	cards.pick(1)
	_clear(cards)
	_check(partner.trust == t0, "a card they have no opinion on does not move trust")

	# ---- a fed-up partner vetoes what they oppose
	partner.trust = 20
	o.show_card("welcome")
	_check(not bool(cards.options[2].get("enabled", true)) and str(cards.options[2].hint) == "PARTNER HAS TO AGREE", "below trust 30 the partner vetoes what they oppose")
	_check(bool(cards.options[1].get("enabled", true)), "other options stay open")
	_clear(cards, 1)
	partner.trust = 70
	_check(partner.help_hours() == 6.0 and root.get_node("Growth").owner_free() > 0.0, "from trust 60 the partner takes owner hours off you")
	partner.trust = 40
	_check(partner.help_hours() == 0.0, "and not below")
	_check(absf(partner.hands() - 0.5) < 0.001, "a partner you get on with works at half speed")
	partner.trust = 20
	_check(partner.hands() < 0.5, "a sulking partner works less")

	# ---- the four partner meetings
	var weeks := {}
	for day in o.DAYS:
		for ev in o.DAYS[day]:
			if ev.get("event", "") == "partner":
				weeks[int(day)] = str(ev.card)
	_check(weeks == {5: "partner1", 9: "partner2", 13: "partner3", 17: "partner4"}, "meetings are scheduled for weeks 5, 9, 13 and 17: " + str(weeks))
	for who in ["Alan", "Garrison"]:
		for n in range(1, 5):
			for pick in 3:
				_start("office_alan" if who == "Garrison" else "casual_garrison")  # the partner is `who`
				var id := "partner%d" % n
				c.day = partner.BEATS[id].week
				var cash0: int = o.cash
				var price0: float = o.price
				var weekly0: int = o.weekly_extra
				var trust0: int = partner.trust
				var fx: Dictionary = partner.BEATS[id].options[pick].fx
				o.fire({"event": "partner", "card": id})
				var ok_open: bool = cards.is_open and cards.options.size() == 3 and cards.speaker.begins_with(who) and not cards.text.contains("{")
				if pick == 0:
					_check(ok_open, "%s %s: the meeting opens with %s speaking, 3 options" % [who, id, who])
				cards.pick(pick)
				var expected: int = int(fx.trust[who])
				_check(partner.trust == clampi(trust0 + expected, 0, 100), "%s %s option %d: trust %+d (%d -> %d)" % [who, id, pick, expected, trust0, partner.trust])
				var real: bool = (
					o.cash != cash0 or o.price != price0 or o.weekly_extra != weekly0
					or fx.has("trust") and fx.size() == 1
					or o.flags.has("plan_sell") or o.flags.has("plan_grow") or o.flags.has("plan_split")
					or fx.has("rep") or fx.has("mood_all") or fx.has("burnout") or fx.has("speed") or fx.has("vic")
				)
				_check(real, "%s %s option %d: it has a real effect" % [who, id, pick])
				_clear(cards)
				_check(partner.met.has(id), "the meeting is remembered")
	# a meeting is held once
	_start("casual_garrison")
	partner.hold_beat("partner1")
	_clear(cards)
	partner.hold_beat("partner1")
	_check(not cards.is_open, "a meeting is only held once")

	# ---- a partner at zero trust walks out at the weekly settle
	_start("office_alan")
	c.day = 6
	partner.change(-100)
	_check(partner.trust == 0 and not partner.left, "trust can hit zero")
	o.settle()
	_clear(cards)
	_check(partner.left and not world.chars.has("Garrison") and partner.hands() == 0.0, "the partner leaves the company and the building")
	_check(str(o.partner_row()[1]).contains("LEFT"), "the weekly report says so")
	var left_ids: Array = o.offers().map(func(x: Dictionary) -> String: return x.id)
	_check(left_ids.has("left") and left_ids.has("sell") and not left_ids.has("expand"), "ending offers after a walk-out: " + str(left_ids))

	# ---- the endings through the board review
	var seen := {}
	for setup in ["good", "rift", "rift_rich", "left", "rich_good"]:
		_start("office_alan")
		partner.left = false
		c.day = 20
		match setup:
			"good":
				partner.trust = 80
				o.cash = 3000
			"rift":
				partner.trust = 20
				o.cash = 3000
			"rift_rich":
				partner.trust = 20
				o.cash = 40000
			"left":
				partner.left = true
				o.cash = 3000
			"rich_good":
				partner.trust = 90
				o.cash = 40000
				c.rep = 80
				root.get_node("Sales").active = [0, 1, 2, 3, 4, 5]
		var offers: Array = o.offers()
		var ids: Array = offers.map(func(x: Dictionary) -> String: return x.id)
		print("     ", setup, " -> ", ids)
		for off in offers:
			seen[str(off.id)] = true
		# play each ending's text
		for i in offers.size():
			review.start()
			review.page = 3
			review.choose(i)
			var lines: Array = review.page_lines()
			var text := ""
			for line in lines:
				text += str(line[0]) + " "
			_check(review.page == 4 and text.contains("THE END") and text.contains("YOUR GOAL"), "%s: ending '%s' reads out" % [setup, offers[i].id])
			if offers[i].id == "buyout":
				_check(text.contains("BUY OUT"), "buy-out text")
			if offers[i].id == "sellout":
				_check(text.contains("SELL YOUR HALF"), "sell-your-half text")
			if offers[i].id == "left":
				_check(text.contains("IS GONE"), "partner-left text")
			review.is_open = false
			review._canvas.visible = false
	for id in ["sell", "expand", "stay", "buyout", "sellout", "left"]:
		_check(seen.has(id), "ending reachable: " + id)

	# ---- the partnership page and saving
	_start("casual_garrison")
	partner.trust = 77
	partner.left = false
	review.start()
	review.page = 2
	var plines: Array = review.page_lines()
	_check(str(plines[0][0]) == "PARTNERSHIP" and str(plines[2][0]).contains("77"), "the PARTNERSHIP page shows trust")
	review.is_open = false
	review._canvas.visible = false
	var saved: Dictionary = o.to_dict()
	partner.trust = 5
	o.from_dict(saved)
	_check(partner.trust == 77, "partner trust is saved with the campaign")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
