extends SceneTree
# gdlint:disable=max-line-length
# R36, owner and service part (scripts/byname.gd). Service: a client that knows a tech asks for him, the ticket routes to him over a
# full desk (a lopsided crew), the Capacity tab shows it, the right or the wrong tech closing it moves the mood, a tech who quits
# leaves unhappy clients. Owner: favourites, the lopsided card, the risk line on the poaching card, a client that follows a tech out.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 40:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1
	return n


func _start(mode: String, who: String) -> void:
	player_script.current_character = who
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(777)
	root.get_node("Campaign").new_game(mode)
	_clear(root.get_node("Cards"))


# a fresh ordinary ticket at one client
func _mk(client: int) -> Dictionary:
	var msp := root.get_node("Msp")
	var used := []
	for ot in msp.open_tickets():
		used.append(str(ot.endpoint))
	for ep in msp.endpoints:
		if not used.has(str(ep.name)):
			ep.problem = ""
	var t: Dictionary = msp.create_ticket(client, 0, "email")
	t.sla_total = 400.0
	t.sla_left = 400.0
	return t


func _shut(t: Dictionary) -> void:
	t.status = "Closed"
	var ep: Dictionary = root.get_node("Msp").endpoint(str(t.endpoint))
	if not ep.is_empty():
		ep.problem = ""


func _pick_id(cards: Node, id: String) -> bool:
	for i in cards.options.size():
		if str(cards.options[i].get("id", "")) == id:
			cards.pick(i)
			return true
	return false


func _pick_label(cards: Node, part: String) -> bool:
	for i in cards.options.size():
		if str(cards.options[i].label).contains(part):
			cards.pick(i)
			return true
	return false


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var service := root.get_node("Service")
	var crew := root.get_node("Crew")
	var d := root.get_node("Difficulty")
	player_script = load("res://scripts/player.gd")
	var bn: Script = load("res://scripts/byname.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	d.settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()

	# ================= service =================
	_start("service", "office_dan")
	var cl: int = int(sales.active[0])
	sales.satisfaction[cl] = 80
	_check(bn.favourite(cl) == "" and bn.tag("Maya") == "", "nobody is known by name on day 1")
	# Maya closes three tickets there: they know her name
	for i in bn.ASK_MIN:
		var t0 := _mk(cl)
		bn.on_done("Maya", t0)
		_shut(t0)
	_check(bn.count(cl, "Maya") == bn.ASK_MIN and bn.favourite(cl) == "Maya", "after %d closes at one client, Maya is the name they know" % bn.ASK_MIN)
	_check(bn.fans("Maya") == [cl] and bn.tag("Maya") == "FAN 1", "the Capacity tag reads FAN 1")
	_check(bn.note("Maya").contains("FOR MAYA BY NAME") and bn.note("Maya", true).begins_with("FANS: "), "the Capacity note names the client: %s" % bn.note("Maya"))
	# a request: seeded draws, so try tickets until one asks (a chance of 0.3 each, with the day gap cleared)
	var asked := {}
	for i in 40:
		service.flags.bn.day = {}
		var t1 := _mk(cl)
		if str(t1.get("asked_tech", "")) == "Maya":
			asked = t1
			break
		_shut(t1)
	_check(not asked.is_empty(), "a happy client asks for Maya by name")
	_check(bn.asks_for("Maya") == 1 and bn.tag("Maya") == "ASK 1" and int(service.flags.bn.asks) >= 1, "one open request, the tag reads ASK 1")
	_check(str(asked.notes[asked.notes.size() - 1]).contains("asked for Maya by name"), "the ticket says so")
	# the route: Maya, even with two tickets already on her desk
	for i in 2:
		var filler := _mk(int(sales.active[1]))
		service.assign(int(filler.id), "Maya", false)
	_check(crew.load_of("Maya") == 2 and crew.best_for(asked, 2) != "Maya", "with two tickets on her desk the usual route skips Maya")
	_check(service.route_for(asked) == "Maya", "the asked ticket still routes to Maya (a lopsided crew)")
	var plain := _mk(int(sales.active[1]))
	_check(service.route_for(plain) != "Maya", "an ordinary ticket does not")
	for i in 2:
		var filler2 := _mk(int(sales.active[2]))
		service.assign(int(filler2.id), "Maya", false)
	_check(crew.load_of("Maya") >= bn.ASK_LOAD and bn.route(asked) == "", "at %d tickets even an asked one waits for a hand" % bn.ASK_LOAD)
	# she closes it: mood and morale up
	var mood0: int = sales.mood(cl)
	var morale0: int = crew.morale("Maya")
	bn.on_done("Maya", asked)
	_check(sales.mood(cl) == mood0 + bn.KEPT_MOOD and crew.morale("Maya") == morale0 + bn.KEPT_MORALE and int(service.flags.bn.kept) == 1, "Maya closes it: mood +%d, morale +%d" % [bn.KEPT_MOOD, bn.KEPT_MORALE])
	bn.on_done("Maya", asked)
	_check(sales.mood(cl) == mood0 + bn.KEPT_MOOD, "the result counts once")
	# somebody else closes an asked ticket: the client notices
	var other := _mk(cl)
	other["asked_tech"] = "Maya"
	var others: Array = crew.names()
	others.erase("Maya")
	var mood1: int = sales.mood(cl)
	bn.on_done(str(others[0]), other)
	_check(sales.mood(cl) == mood1 + bn.OTHER_MOOD and int(service.flags.bn.other) == 1, "%s closes Maya's request: mood %d" % [str(others[0]), bn.OTHER_MOOD])
	# save and load keeps it
	var saved: Dictionary = service.to_dict()
	service.from_dict(saved)
	_check(bn.favourite(cl) == "Maya" and int(service.flags.bn.kept) == 1, "the state survives a save")
	# Maya quits: the client is unhappy, Jen says who called, the requests are released
	var open_ask := _mk(cl)
	open_ask["asked_tech"] = "Maya"
	var mood2: int = sales.mood(cl)
	_clear(cards)
	crew.quit("Maya")
	_check(cards.is_open and str(cards.speaker) == "Jen" and str(cards.text).contains("asked for Maya"), "Jen says who called for Maya")
	_clear(cards)
	_check(sales.mood(cl) == mood2 - bn.FOLLOW_MOOD and int(service.flags.bn.followed) == 1, "the client that was hers loses %d mood" % bn.FOLLOW_MOOD)
	_check(not open_ask.has("asked_tech") and bn.favourite(cl) == "" and bn.asks_for("Maya") == 0, "her open requests go back to the board as ordinary tickets")
	# an old service save has no by-name state
	service.flags.erase("bn")
	_check(bn.favourite(cl) == "" and bn.tag("Sam") == "", "an old save starts with nobody known")

	# ================= owner =================
	_start("owner", "office_alan")
	c.day = 5
	_check(bn.techs() == ["Dan", "Maya"] and bn.report_text() == "" and bn.leader() == "", "owner: two employees, no favourites yet")
	for cidx in sales.active:
		sales.satisfaction[int(cidx)] = 80
	var weeks := 0
	while bn.report_text() == "" and weeks < 30:
		bn.owner_week(o)
		_clear(cards)
		weeks += 1
	_check(bn.report_text() != "", "within a few weeks a happy client asks for a tech by name (%d weeks): %s" % [weeks, bn.report_text()])
	# the lopsided card
	o.flags.bn.fav = {}
	var act: Array = sales.active
	for i in 3:
		o.flags.bn.fav[str(act[i])] = "Dan"
	o.flags.bn.card = -99
	_check(bn.leader() == "Dan" and bn.owner_fans("Dan").size() == 3 and bn.report_text().begins_with("DAN 3"), "three clients ask for Dan: %s" % bn.report_text())
	_check(bn.risk_line("Dan") == " 3 clients ask for Dan by name." and bn.risk_line("Maya") == "", "the risk line for a poaching card")
	bn.lopsided_card(o, "Dan")
	_check(cards.is_open and str(cards.text).contains("only talk to Dan") and cards.options.size() == 3, "Morgan raises the lopsided crew")
	var cash0: int = o.cash
	_check(_pick_id(cards, "pair"), "pair the techs")
	_clear(cards)
	_check(o.cash == cash0 - bn.PAIR_COST and bn.at_risk("Dan").is_empty() and bn.owner_fans("Dan").size() == 3, "pairing costs $%d and takes the follow risk away" % bn.PAIR_COST)
	# rotate: the load evens out, the clients grumble
	o.flags.bn.shared = {}
	var m0: int = sales.mood(int(act[1]))
	var speed0: float = o.speed
	bn.lopsided_card(o, "Dan")
	_pick_id(cards, "rotate")
	_clear(cards)
	_check(bn.owner_fans("Dan").size() == 1 and sales.mood(int(act[1])) == m0 + bn.ROTATE_MOOD and o.speed > speed0, "rotating leaves one favourite, costs mood and evens the board")
	# let them: happy clients, a tired crew
	for i in 3:
		o.flags.bn.fav[str(act[i])] = "Dan"
	var burn0: float = o.burnout
	var m1: int = sales.mood(int(act[0]))
	bn.lopsided_card(o, "Dan")
	_pick_id(cards, "let")
	_clear(cards)
	_check(sales.mood(int(act[0])) == m1 + bn.LET_MOOD and o.burnout > burn0 and bool(o.flags.bn.let), "letting them costs burnout and makes the clients happy")
	# the poaching card names the risk
	o._key_poach()
	var risk_shown: bool = cards.is_open and str(cards.text).contains("by name")
	var poached: String = "Dan" if str(cards.text).begins_with("Dan") else "Maya"
	_check(cards.is_open and (risk_shown or poached == "Maya"), "the poaching card says what %s leaving would risk" % poached)
	_check(_pick_label(cards, "WISH THEM LUCK"), "wish them luck")
	_clear(cards)
	_check(o.lost_techs == 1, "the tech leaves")
	# next week the clients that asked for the leaver may follow: with three of them at 60 percent, seed 777 brings the card
	if poached != "Dan":
		for i in 3:
			o.flags.bn.fav[str(act[i])] = poached
	var clients0: int = sales.active.size()
	bn.owner_week(o)
	_check(bn.techs().size() == 1 and not bn.techs().has(poached), "%s is off the list of names a client can ask for" % poached)
	_check(bn.owner_fans(poached).is_empty(), "nobody asks for %s any more" % poached)
	if cards.is_open and str(cards.text).contains("non-solicit"):
		_check(str(cards.text).contains(poached), "the non-solicit card names %s" % poached)
		_check(_pick_label(cards, "LET THEM GO"), "let them go")
		_clear(cards)
		_check(sales.active.size() == clients0 - 1 and int(o.flags.bn.followed) >= 1, "the client follows the tech out")
	else:
		_check(int(o.flags.bn.followed) == 0, "this seed: nobody wanted to follow")
	_clear(cards)
	# the follow card by hand: the letter keeps them or not, the visit, letting go
	_start("owner", "office_alan")
	c.day = 8
	var victim: int = int(sales.active[0])
	o.flags["bn"] = {"fav": {str(victim): "Maya"}, "shared": {}, "gone": [], "lost": 0, "card": -99, "followed": 0, "let": false}
	bn.follow_card(o, victim, "Maya")
	_check(cards.is_open and cards.options.size() == 3 and str(cards.text).contains(str(msp.CLIENTS[victim].name)), "the follow card names the client and has three answers")
	var cash1: int = o.cash
	_check(_pick_label(cards, "NON-SOLICIT"), "send the letter")
	_clear(cards)
	_check(o.cash == cash1 - bn.LETTER_COST, "the letter costs $%d either way" % bn.LETTER_COST)
	# a shared client never follows
	_start("owner", "office_alan")
	c.day = 8
	victim = int(sales.active[0])
	o.flags["bn"] = {"fav": {str(victim): "Maya"}, "shared": {str(victim): true}, "gone": [], "lost": 0, "card": -99, "followed": 0, "let": false}
	o.lost_techs = 1
	var n0: int = sales.active.size()
	bn.owner_week(o)
	_check(not cards.is_open or not str(cards.text).contains("non-solicit"), "a client that met both techs does not follow")
	_clear(cards)
	_check(sales.active.size() == n0 and int(o.flags.bn.followed) == 0, "and stays")
	# save / load
	o.flags.bn.fav[str(sales.active[1])] = "Dan"
	var od: Dictionary = o.to_dict()
	o.from_dict(od)
	_check(bn.owner_fav(int(sales.active[1])) == "Dan" and bn.techs() == ["Dan"], "the owner state survives a save")

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
