extends RefCounted
# gdlint:disable=max-line-length
# R36, the owner and service part: clients who ask for one tech by name. A static helper (no state of its own).
#
# SERVICE campaign (state in Service.flags.bn): every ticket a tech closes at a client counts for him there. Once one tech has closed
# ASK_MIN tickets at a happy client, that client now and then asks for him by name: the ticket is marked (asked_tech), the autopilot
# routes it to him even when his desk is full (so the crew gets lopsided: he overloads while the others idle), and the Capacity tab
# shows who is being asked for. He closes it: mood +KEPT_MOOD, morale +KEPT_MORALE. Somebody else closes it: mood OTHER_MOOD. When a
# tech quits, the clients who asked for him are unhappy (FOLLOW_MOOD each) and Jen tells you who called.
#
# OWNER campaign (state in Owner.flags.bn): the crew is abstract there, so a client simply picks a favourite among the two employees
# (one new favourite in some weeks, mostly the tech who already has the most: the load gets lopsided). At LOPSIDED favourites Morgan
# raises it (let them, rotate, or pair the techs so the knowledge is shared). When a tech leaves, each client that asked for him and
# was never shared may follow him out: the non-solicit card (lawyer letter, a visit, or let them go).

const ASK_MIN := 3  # tickets closed at one client before they know a tech's name
const ASK_MOOD := 60
const ASK_CHANCE := 0.3
const ASK_GAP := 2  # days between two requests from one client
const ASK_LOAD := 4  # the asked tech takes it up to this many tickets on his desk
const KEPT_MOOD := 2
const KEPT_MORALE := 1
const OTHER_MOOD := -2
const FOLLOW_MIN := 4  # tickets at a client that make a tech "theirs"
const FOLLOW_MOOD := 8
const OWNER_MOOD := 65
const OWNER_CHANCE := 0.4  # a week brings one new favourite this often
const LEADER_SHARE := 0.7  # ... and this often it is the tech who already has the most
const OWNER_FROM := 3  # first week
const LOPSIDED := 3  # favourites on one tech that make Morgan raise it
const CARD_GAP := 6  # weeks between two lopsided cards
const LET_MOOD := 3
const LET_BURN := 5.0
const LET_SPEED := -0.03
const ROTATE_MOOD := -3
const ROTATE_SPEED := 0.02
const ROTATE_HOURS := 2
const PAIR_COST := 300
const FOLLOW_CHANCE := 0.6  # a client that asked for the tech who left wants to follow him
const LETTER_COST := 400
const LETTER_STAY := 0.6
const LETTER_MOOD := -8
const VISIT_HOURS := 3
const VISIT_STAY := 0.6
const VISIT_MOOD := 3
const QUIET_MOOD := -6  # a second follower in the same week only sulks


# ---- service campaign --------------------------------------------------------------------------------------------
static func state() -> Dictionary:
	if not Service.flags.has("bn"):
		Service.flags["bn"] = {"fav": {}, "day": {}, "asks": 0, "kept": 0, "other": 0, "followed": 0}
	return Service.flags["bn"]


# tickets `who` has closed at this client
static func count(client: int, who: String) -> int:
	return int((state().fav.get(str(client), {}) as Dictionary).get(who, 0))


# the tech this client knows by name ("" = nobody yet): the most tickets there, at least ASK_MIN, still on the crew
static func favourite(client: int) -> String:
	var best := ""
	var most := ASK_MIN - 1
	for who in Crew.names():
		var n := count(client, str(who))
		if n > most:
			most = n
			best = str(who)
	return best


# a new ticket (Msp.ticket_added): a happy client that knows a tech asks for him
static func on_ticket(t: Dictionary) -> void:
	if not Service.active() or not Service._crew_ticket(t):
		return
	var client := int(t.client)
	var st := state()
	var who := favourite(client)
	if who == "" or Sales.mood(client) < ASK_MOOD or int(st.day.get(str(client), -99)) > Campaign.day - ASK_GAP:
		return
	if Difficulty.rng("service.byname").randf() >= ASK_CHANCE:
		return
	st.day[str(client)] = Campaign.day
	st["asks"] = int(st.asks) + 1
	t["asked_tech"] = who
	t.notes.append("%s asked for %s by name." % [str(Msp.CLIENTS[client].contact), who])
	Hints.toast("%s ASKED FOR %s BY NAME." % [str(Msp.CLIENTS[client].short).to_upper(), who.to_upper()], 3.0)


# the autopilot's route for an asked ticket: the tech they asked for, even with a full desk ("" = route it as usual)
static func route(t: Dictionary) -> String:
	var who := str(t.get("asked_tech", ""))
	if who == "" or not Crew.has(who) or Crew.is_gone(who) or Crew.is_shadowing(who) or Crew.stuck.has(who):
		return ""
	return who if Crew.load_of(who) < ASK_LOAD else ""


# a tech closed a ticket (Service._finish)
static func on_done(who: String, t: Dictionary) -> void:
	if not Service.active() or not Crew.has(who) or bool(t.get("internal", false)):
		return
	var client := int(t.client)
	var st := state()
	var row: Dictionary = st.fav.get(str(client), {})
	row[who] = int(row.get(who, 0)) + 1
	st.fav[str(client)] = row
	var asked := str(t.get("asked_tech", ""))
	if asked == "" or bool(t.get("bn_done", false)):
		return
	t["bn_done"] = true
	if asked == who:
		st["kept"] = int(st.kept) + 1
		Sales.adjust(client, KEPT_MOOD)
		Crew.add_morale(who, KEPT_MORALE)
		t.notes.append("They asked for %s and got %s." % [who, who])
	else:
		st["other"] = int(st.other) + 1
		Sales.adjust(client, OTHER_MOOD)
		t.notes.append("They asked for %s and got %s." % [asked, who])


# open tickets that ask for this tech
static func asks_for(who: String) -> int:
	var n := 0
	for t in Msp.tickets:
		if str(t.status) != "Closed" and str(t.get("asked_tech", "")) == who:
			n += 1
	return n


# the clients (indices) that know this tech by name
static func fans(who: String) -> Array:
	var out := []
	for c in Sales.active:
		if favourite(int(c)) == who:
			out.append(int(c))
	return out


# the Capacity tab's tag for a tech row: "" or "ASK 2" (open requests), else "FANS 3" (clients that know him)
static func tag(who: String) -> String:
	var open := asks_for(who)
	if open > 0:
		return "ASK %d" % open
	var n := fans(who).size()
	return "FAN %d" % n if n > 0 else ""


# the Capacity tab's note for the selected tech ("" = nothing to say)
static func note(who: String, short := false) -> String:
	var names := []
	for c in fans(who):
		names.append(str(Msp.CLIENTS[int(c)].short).to_upper())
	if names.is_empty():
		return ""
	if short:
		return "FANS: " + " ".join(names)
	return "%s ASK%s FOR %s BY NAME" % [" AND ".join(names) if names.size() <= 2 else "%d CLIENTS" % names.size(), "S" if names.size() == 1 else "", who.to_upper()]


# a tech quit (Service.release_all): the clients that were his are unhappy, and Jen tells you who called. Returns those clients.
static func on_quit(who: String) -> Array:
	if not Service.active():
		return []
	var st := state()
	var lost := []
	for c in Sales.active:
		if count(int(c), who) >= FOLLOW_MIN and _was_theirs(int(c), who):
			lost.append(int(c))
	for key in st.fav:
		(st.fav[key] as Dictionary).erase(who)
	for t in Msp.tickets:
		if str(t.get("asked_tech", "")) == who:
			t.erase("asked_tech")
	if lost.is_empty():
		return lost
	var names := []
	for c in lost:
		Sales.adjust(int(c), -(FOLLOW_MOOD / 2 if Difficulty.cozy_on() else FOLLOW_MOOD))
		names.append(str(Msp.CLIENTS[int(c)].name))
	st["followed"] = int(st.followed) + lost.size()
	Cards.ask(
		"Jen",
		"%s called the front desk and asked for %s. I told them %s does not work here any more. It went very quiet on the line. They only ever wanted %s." % [" and ".join(names), who, who, who],
		[{"label": "OK", "id": "ok"}],
		func(_id: String) -> void: pass
	)
	return lost


# nobody else has closed more tickets there
static func _was_theirs(client: int, who: String) -> bool:
	var row: Dictionary = state().fav.get(str(client), {})
	for other in row:
		if str(other) != who and int(row[other]) > int(row.get(who, 0)):
			return false
	return true


# ---- owner campaign --------------------------------------------------------------------------------------------
static func ostate() -> Dictionary:
	if not Owner.flags.has("bn"):
		Owner.flags["bn"] = {"fav": {}, "shared": {}, "gone": [], "lost": 0, "card": -99, "followed": 0, "let": false}
	return Owner.flags["bn"]


# the employees a client can still ask for
static func techs() -> Array:
	var out := []
	var gone: Array = ostate().gone
	for row in Owner.CREW:
		if not gone.has(str(row.name)):
			out.append(str(row.name))
	return out


static func owner_fav(client: int) -> String:
	return str(ostate().fav.get(str(client), ""))


static func owner_fans(who: String) -> Array:
	var out := []
	for c in Sales.active:
		if owner_fav(int(c)) == who:
			out.append(int(c))
	return out


# fans that would follow him out (the ones that were never shared)
static func at_risk(who: String) -> Array:
	var out := []
	for c in owner_fans(who):
		if not bool(ostate().shared.get(str(c), false)):
			out.append(c)
	return out


# the tech with the most favourites ("" = none)
static func leader() -> String:
	var best := ""
	var most := 0
	for who in techs():
		var n := owner_fans(str(who)).size()
		if n > most:
			most = n
			best = str(who)
	return best


# the sentence a poaching card gets: what losing this tech would put at risk
static func risk_line(who: String) -> String:
	var n := at_risk(who).size()
	if n <= 0:
		return ""
	return " %d client%s ask%s for %s by name." % [n, "" if n == 1 else "s", "s" if n == 1 else "", who]


# the weekly report row ("" = nothing yet)
static func report_text() -> String:
	var parts := []
	for who in techs():
		var n := owner_fans(str(who)).size()
		if n > 0:
			parts.append("%s %d" % [str(who).to_upper(), n])
	return ", ".join(parts)


# remember who a poaching card is about, so the right name leaves (Owner._key_poach)
static func note_leaver(who: String) -> void:
	ostate()["leaver"] = who


# Owner.settle(), owner campaign only: departures first, then one new favourite, then the lopsided card
static func owner_week(owner: Node) -> void:
	var st := ostate()
	for key in st.fav.keys():
		if not Sales.active.has(int(key)):
			st.fav.erase(key)
			st.shared.erase(key)
	_departures(owner)
	if Campaign.day < OWNER_FROM or techs().is_empty():
		return
	var r := Difficulty.rng("owner.byname")
	var roll := r.randf()  # always three draws a week: the stream stays in step
	var pick := r.randf()
	var lead := r.randf()
	var open := []
	for c in Sales.active:
		if owner_fav(int(c)) == "" and Sales.mood(int(c)) >= OWNER_MOOD:
			open.append(int(c))
	if roll < OWNER_CHANCE and not open.is_empty():
		var client: int = open[mini(open.size() - 1, int(pick * open.size()))]
		var who := leader()
		var names := techs()
		if who == "" or lead >= LEADER_SHARE:
			who = str(names[mini(names.size() - 1, int(lead * names.size()))])
		st.fav[str(client)] = who
		Hints.toast("%s NOW ASKS FOR %s BY NAME." % [str(Msp.CLIENTS[client].name).to_upper(), who.to_upper()], 4.0)
	if bool(st.get("let", false)) and leader() != "" and owner_fans(leader()).size() >= LOPSIDED:
		owner.burnout = clampf(owner.burnout + 1.0, 0.0, 100.0)  # one desk carries the clients
	var top := leader()
	if top != "" and owner_fans(top).size() >= LOPSIDED and techs().size() >= 2 and Campaign.day - int(st.card) >= CARD_GAP:
		st["card"] = Campaign.day
		lopsided_card(owner, top)


# a tech left since last week: who it was, and which of his clients want to follow
static func _departures(owner: Node) -> void:
	var st := ostate()
	var lost := int(owner.lost_techs)
	while int(st.lost) < lost:
		st["lost"] = int(st.lost) + 1
		var names := techs()
		if names.is_empty():
			break
		var who := str(st.get("leaver", ""))
		if not names.has(who):
			who = str(names[names.size() - 1])
		st.erase("leaver")
		st.gone.append(who)
		left(owner, who)
	st.erase("leaver")


# the clients that asked for the tech who left: the shared ones stay, the first of the others brings the non-solicit card
static func left(owner: Node, who: String) -> void:
	var st := ostate()
	var carded := false
	var r := Difficulty.rng("owner.byname")
	for key in st.fav.keys():
		if str(st.fav[key]) != who:
			continue
		var client := int(key)
		st.fav.erase(key)
		var wants := r.randf() < FOLLOW_CHANCE
		if bool(st.shared.get(key, false)) or not Sales.active.has(client):
			st.shared.erase(key)
			continue
		if Difficulty.cozy_on() or not wants:
			Sales.adjust(client, QUIET_MOOD / 2)
			continue
		st["followed"] = int(st.followed) + 1
		if carded:
			Sales.adjust(client, QUIET_MOOD)
			continue
		carded = true
		follow_card(owner, client, who)


static func follow_card(owner: Node, client: int, who: String) -> void:
	var cname := str(Msp.CLIENTS[client].name)
	owner._dynamic["bn_follow"] = {
		"speaker": "Christy (Controller)",
		"text": "%s is gone, and %s asked for %s by name on every ticket. Their office manager wants to know where %s works now. Our contract has a non-solicit line. Their lawyer has read it too." % [who, cname, who, who],
		"options":
		[
			{
				"label": "SEND THE NON-SOLICIT LETTER ($%d)" % LETTER_COST,
				"need": LETTER_COST,
				"roll":
				[
					[LETTER_STAY, {"cash": -LETTER_COST, "mood": {str(client): LETTER_MOOD}}, "They stay. Nobody sends a fruit basket."],
					[1.0 - LETTER_STAY, {"cash": -LETTER_COST, "drop_client": client, "rep": -1}, "They leave anyway, and they show people the letter."]
				]
			},
			{
				"label": "GO THERE AND INTRODUCE THE CREW (%d HOURS)" % VISIT_HOURS,
				"roll":
				[
					[VISIT_STAY, {"owner_hours": VISIT_HOURS, "mood": {str(client): VISIT_MOOD}}, "You bring the crew and a box of donuts. By the end they are asking for somebody new by name."],
					[1.0 - VISIT_STAY, {"owner_hours": VISIT_HOURS, "drop_client": client}, "They are polite about it. They had already decided. They go where %s went." % who]
				]
			},
			{"label": "LET THEM GO", "fx": {"drop_client": client}, "text": "They follow %s. It was never our logo they were calling." % who},
		],
	}
	owner.show_card("bn_follow")


static func lopsided_card(owner: Node, who: String) -> void:
	var list: Array = owner_fans(who)
	var others := techs()
	others.erase(who)
	var other := str(others[0]) if not others.is_empty() else "the rest of the crew"
	Cards.ask(
		"Morgan (Operations Manager)",
		"%d clients will only talk to %s now. %s has a full board and %s is reading the manual. If %s ever leaves, those clients know the way out." % [list.size(), who, who, other, who],
		[
			{"label": "LET THEM HAVE WHO THEY ASK FOR", "id": "let"},
			{"label": "ROTATE: EVERY CLIENT MEETS THE CREW (%d H)" % ROTATE_HOURS, "id": "rotate"},
			{"label": "PAIR THE TECHS FOR A MONTH ($%d)" % PAIR_COST, "id": "pair", "enabled": owner.cash >= PAIR_COST, "hint": "NEED $%d" % PAIR_COST},
		],
		func(id: String) -> void: lopsided_pick(owner, who, id)
	)


static func lopsided_pick(owner: Node, who: String, id: String) -> void:
	var st := ostate()
	var list: Array = owner_fans(who)
	var text := ""
	match id:
		"rotate":
			st["let"] = false
			for i in list.size():
				owner.apply({"mood": {str(list[i]): ROTATE_MOOD}})
				if i > 0:
					st.fav.erase(str(list[i]))  # one keeps its favourite, the others get used to the whole crew
					st.shared.erase(str(list[i]))
			owner.apply({"owner_hours": ROTATE_HOURS, "speed": ROTATE_SPEED})
			text = "The clients grumble for a week about the new voice on the phone. The board evens out."
		"pair":
			st["let"] = false
			st["card"] = 9999  # settled: Morgan does not raise it again
			for c in list:
				st.shared[str(c)] = true
			owner.apply({"cash": -PAIR_COST, "mood_all": 1})
			text = "Two techs on every visit for a month. The clients learn a second name, and the second tech learns where the server closet key is."
		_:
			st["let"] = true
			st["card"] = 9999  # your call: Morgan does not raise it again
			for c in list:
				owner.apply({"mood": {str(c): LET_MOOD}})
			owner.apply({"burnout": LET_BURN, "speed": LET_SPEED})
			text = "The clients are happy. %s eats lunch at the desk now." % who
	Cards.ask("Morgan (Operations Manager)", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
