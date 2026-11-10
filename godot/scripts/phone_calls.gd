extends RefCounted
# gdlint:disable=class-definitions-order,max-returns
# The phone's dialer rules (no drawing): who is in the contacts list, what a call offers and what it does. Calls are
# text only. State (cooldowns, call counts) lives in the Phone autoload (`call_cd`, `call_n`) so it can be saved.
#   PhoneCalls.contacts()            -> [{id, name, sub, kind, num, client?, who?}]
#   PhoneCalls.open_call(contact)    -> {say, opts: [{id, label}], voicemail}
#   PhoneCalls.act(contact, opt_id)  -> {say}   applies the effect, costs time / energy, starts the cooldown
# Free Play: no time or energy cost and no cooldown (opinion and mood changes are no-ops outside a campaign anyway).

const CLIENT_GAP := 3.0  # game hours before the same client takes another call
const CO_GAP := 2.0  # game hours before the same coworker takes another chat
const PIZZA_GAP := 8.0
const REFERRAL_GAP := 24.0
const REFERRAL_ODDS := 0.35
const REFERRAL_MOOD := 80
const CHECK_COST := 0.1  # game hours a client call takes (about six minutes)
const CHAT_COST := 0.05
const Collection := preload("res://scripts/collection.gd")  # R16: relationship levels on the contacts
const LEVEL_WHO := {"senior": "Adam", "tech": "Michael"}  # the contacts with their own numbers are cast members too
const LEVEL_PIPS := 4  # one pip per level above NEW FACE
const PIZZA := {"id": "pizza", "name": "TONY'S PIZZA", "sub": "LUNCH ORDERS", "kind": "pizza", "num": "5550199"}
const HANG := {"id": "hang", "label": "HANG UP"}
const SENIOR := {"id": "adam", "name": "ADAM", "sub": "SENIOR TECH", "kind": "senior", "num": "5550333"}
const SENIOR_GAP := 2.0  # game hours before he takes another question
const TECH := {"id": "michael", "name": "MICHAEL", "sub": "TECH", "kind": "tech", "num": "5550334"}
const HANDOFF_MAX := 2  # tickets he takes off you in a day
const HANDOFF_GAP := 3.0  # game hours between two of them
const HANDOFF_ODDS := 0.85  # the chance he fixes it for good; otherwise it comes back to you with a note
const CHAT_REPLIES := {
	"talk":
	{
		"good": ["HA, YOU TOO. COFFEE LATER?", "ANYTIME. HOW IS YOUR DAY GOING?"],
		"neutral": ["YEAH, ALL GOOD HERE. BACK TO IT.", "FINE, THANKS. BUSY ONE."],
		"cold": ["UH HUH. I AM BUSY.", "OK. BYE."],
	},
	"thanks":
	{
		"good": ["NO PROBLEM! ANYTIME.", "ANY TIME. WE ARE A TEAM."],
		"neutral": ["SURE. NO PROBLEM.", "OK, THANKS FOR SAYING."],
		"cold": ["MM. OK.", "SURE."],
	},
	"lunch":
	{
		"good": ["YES! I WILL BRING MY COUPONS.", "SANDWICHES AT NOON? DEAL."],
		"neutral": ["MAYBE. TEXT ME AT NOON.", "I MIGHT EAT AT MY DESK."],
		"cold": ["I HAVE PLANS.", "NOT TODAY."],
	},
}


static func now_hours() -> float:
	return float(Campaign.day) * 24.0 + World.clock


static func number_text(num: String) -> String:
	return num.substr(0, 3) + "-" + num.substr(3)


static func contacts() -> Array:
	var out := []
	var wanted := range(Msp.CLIENTS.size())
	if Campaign.active:
		var live := []
		for c in wanted:
			if Sales.is_active(int(c)):
				live.append(c)
		if not live.is_empty():
			wanted = live
	for c in wanted:
		var cl: Dictionary = Msp.CLIENTS[int(c)]
		out.append(
			{
				"id": "c:%d" % int(c),
				"name": str(cl.contact).to_upper(),
				"sub": str(cl.short),
				"kind": "client",
				"client": int(c),
				"num": "55501%02d" % (10 + int(c)),
			}
		)
	var team: Array = Lync.contacts()
	for i in team.size():
		var who := str(team[i])
		if who in ["Adam", "Michael"]:
			continue  # they have their own numbers below (a stuck ticket, a hand-off)
		var sub := Social.role(who)
		if sub == "":
			sub = "OFFICE MANAGER" if who == Lync.boss() else "TEAM"
		out.append(
			{
				"id": "w:" + who,
				"name": who.to_upper(),
				"sub": sub,
				"kind": "coworker",
				"who": who,
				"num": "55502%02d" % (10 + i),
			}
		)
	if Campaign.mode in ["tech", ""]:
		out.append(SENIOR.duplicate())  # Adam, the senior tech: ask him about a ticket you are stuck on
		if World.chars.has("Michael"):
			out.append(TECH.duplicate())  # Michael: hand him an ordinary ticket
	out.append(PIZZA.duplicate())
	return out


# R16: the relationship level of a contact (Collection.LEVELS, 0-4); -1 for somebody who has none (clients, the pizza place,
# a coworker outside the cast, no campaign running)
static func level(contact: Dictionary) -> int:
	var who := str(contact.get("who", ""))
	if who == "":
		who = str(LEVEL_WHO.get(str(contact.get("kind", "")), ""))
	if who == "" or not Campaign.active or not Social.people().has(who):
		return -1
	return Collection.level(who)


# "LV 2 LUNCH BUDDY" ("" without a level): the second line of the selected contact
static func level_text(contact: Dictionary) -> String:
	var lv := level(contact)
	return "" if lv < 0 else "LV %d %s" % [lv, Collection.level_name(lv)]


# the second line of a contact row: the role, LATER while they do not take calls, the level on the selected row
static func row_sub(contact: Dictionary, selected: bool) -> String:
	if wait_left(contact) > 0.0:
		return "LATER"
	if selected and level(contact) >= 0:
		return level_text(contact)
	return str(contact.get("sub", ""))


static func find(id: String) -> Dictionary:
	for c in contacts():
		if str(c.id) == id:
			return c
	return {}


static func by_number(digits: String) -> Dictionary:
	for c in contacts():
		if str(c.num) == digits:
			return c
	return {}


static func gap_of(contact: Dictionary) -> float:
	match str(contact.get("kind", "")):
		"client":
			return CLIENT_GAP
		"pizza":
			return PIZZA_GAP
	return CO_GAP


# game hours left before this contact takes another call (0 = ready; Free Play is always ready)
static func wait_left(contact: Dictionary) -> float:
	if not Campaign.active:
		return 0.0
	return maxf(0.0, float(Phone.call_cd.get(str(contact.get("id", "")), -1000.0)) - now_hours())


static func ready(contact: Dictionary) -> bool:
	return wait_left(contact) <= 0.0


static func client_tickets(client: int) -> Array:
	var out := []
	for t in Msp.open_tickets():
		if int(t.client) == client:
			out.append(t)
	return out


static func late_ticket(client: int) -> Dictionary:
	for t in client_tickets(client):
		if bool(t.breached) or float(t.sla_left) < 90.0:
			return t
	return {}


static func _mmss(secs: float) -> String:
	var s := maxi(0, int(secs))
	return "%d:%02d" % [s / 60, s % 60]


# what the client tells you about their most urgent ticket (the hint a check-in earns)
static func ticket_hint(t: Dictionary) -> String:
	var ep: Dictionary = Msp.endpoint(str(t.endpoint))
	var line := "#%d IS %s." % [int(t.id), str(t.endpoint)]
	if not ep.is_empty() and bool(ep.get("unsaved", false)) and not bool(ep.get("asked", false)):
		line += " DOCUMENTS ARE OPEN ON IT: ASK FIRST."
	elif bool(t.breached):
		line += " IT IS LATE AND THEY ARE ANGRY."
	else:
		line += " THEY NEED IT WITHIN %s." % _mmss(float(t.sla_left))
	return line


static func _tier(mood: int) -> String:
	if mood >= 70:
		return "good"
	return "neutral" if mood >= 40 else "cold"


static func open_call(contact: Dictionary) -> Dictionary:
	var kind := str(contact.get("kind", "none"))
	match kind:
		"client":
			var c := int(contact.client)
			var who := str(Msp.CLIENTS[c].contact)
			if World.clock >= World.DAY_END:
				return _mail_box("OFFICE CLOSED. YOU GET %s'S VOICEMAIL." % who.to_upper())
			var mood := Sales.mood(c)
			var say: String = {
				"good": "HEY, GOOD TO HEAR FROM YOU!",
				"neutral": "PIXEL IT? WHAT IS UP?",
				"cold": "I HOPE THIS IS GOOD NEWS.",
			}[_tier(mood)]
			var opts := [{"id": "check", "label": "CHECK IN"}]
			if not late_ticket(c).is_empty():
				opts.append({"id": "sorry", "label": "APOLOGISE"})
			if mood >= REFERRAL_MOOD or not Campaign.active:
				opts.append({"id": "refer", "label": "REFERRAL?"})
			opts.append(HANG)
			return {"say": say, "opts": opts, "voicemail": false}
		"coworker":
			var who := str(contact.who)
			if Lync.presence(who)[0] != "AVAILABLE":
				return _mail_box("%s IS %s. YOU LEAVE A MESSAGE." % [who.to_upper(), str(Lync.presence(who)[0])])
			return {
				"say": "HELLO?",
				"opts":
				[
					{"id": "talk", "label": "SMALL TALK"},
					{"id": "thanks", "label": "THANK THEM"},
					{"id": "lunch", "label": "LUNCH PLANS"},
					HANG,
				],
				"voicemail": false,
			}
		"senior":
			if World.clock >= World.DAY_END:
				return _mail_box("ADAM HAS GONE HOME. YOU GET HIS VOICEMAIL.")
			if Lync.presence("Adam")[0] != "AVAILABLE":
				return _mail_box("ADAM IS %s. YOU LEAVE A MESSAGE." % str(Lync.presence("Adam")[0]))
			return {
				"say": "ADAM. WHAT HAVE YOU GOT?",
				"opts": [{"id": "stuck", "label": "STUCK ON A TICKET"}, HANG],
				"voicemail": false,
			}
		"tech":
			if World.clock >= World.DAY_END:
				return _mail_box("MICHAEL HAS GONE HOME. YOU GET HIS VOICEMAIL.")
			if Lync.presence("Michael")[0] != "AVAILABLE":
				return _mail_box("MICHAEL IS %s. YOU LEAVE A MESSAGE." % str(Lync.presence("Michael")[0]))
			if Msp.handoffs_today >= HANDOFF_MAX:
				return {"say": "I AM BURIED, I HAVE TAKEN TWO OF YOURS ALREADY. ASK ME TOMORROW.", "opts": [HANG], "voicemail": false}
			return {"say": "MICHAEL. YEAH?", "opts": [{"id": "handoff", "label": "TAKE A TICKET OFF ME"}, HANG], "voicemail": false}
		"pizza":
			return {
				"say": "TONY'S: PIXEL IT? THE USUAL LARGE PEPPERONI?",
				"opts": [{"id": "pizza", "label": "ORDER LUNCH"}, HANG],
				"voicemail": false,
			}
	return _mail_box("THE NUMBER YOU HAVE DIALED IS NOT IN SERVICE.")


static func _mail_box(say: String) -> Dictionary:
	return {"say": say, "opts": [HANG], "voicemail": true}


static func _cost(hours: float, energy: float) -> void:
	if not Campaign.active:
		return
	World.clock = minf(World.DAY_END - 0.05, World.clock + hours)
	if Shift.active():
		Shift.add_energy(-energy)


static func _cooldown(contact: Dictionary, hours: float) -> void:
	if Campaign.active:
		Phone.call_cd[str(contact.id)] = now_hours() + hours


static func act(contact: Dictionary, opt: String) -> Dictionary:
	var id := str(contact.get("id", ""))
	var n := int(Phone.call_n.get(id, 0))
	Phone.call_n[id] = n + 1
	match opt:
		"check", "sorry", "refer":
			return _client_act(contact, opt, n)
		"talk", "thanks", "lunch":
			var who := str(contact.who)
			var tier: String = {"FRIEND": "good", "FRIENDLY": "good", "NEUTRAL": "neutral"}.get(Social.mood(who), "cold")
			var lines: Array = CHAT_REPLIES[opt][tier]
			if Social.mood(who) != "HOSTILE":
				Social.change(who, 1)
			_cost(CHAT_COST, 0.0)
			_cooldown(contact, CO_GAP)
			return {"say": str(lines[n % lines.size()])}
		"stuck":
			return _senior_act(contact)
		"handoff":
			return _handoff_act(contact)
		"pizza":
			_cost(CHAT_COST, 0.0)
			_cooldown(contact, PIZZA_GAP)
			if Campaign.active and Shift.active():
				Shift.add_energy(2.0)
			return {"say": "LARGE PEPPERONI. 25 MINUTES. THEY SAY THANKS FOR CALLING."}
	return {"say": ""}


# Michael takes the oldest ordinary ticket (no story job, nothing internal): usually he fixes it, now and then it comes back with a note
static func _handoff_act(contact: Dictionary) -> Dictionary:
	var pick := {}
	for t in Msp.open_tickets():
		if bool(t.get("internal", false)) or str(t.get("special", "")) != "":
			continue
		if pick.is_empty() or int(t.id) < int(pick.id):
			pick = t
	_cost(CHAT_COST, 0.0)
	_cooldown(contact, HANDOFF_GAP)
	if pick.is_empty():
		return {"say": "THERE IS NOTHING I CAN TAKE. YOUR QUEUE IS CLEAR OR IT IS ALL YOURS."}
	Msp.handoffs_today += 1
	var id := int(pick.id)
	if Difficulty.rng("msp.tickets").randf() < HANDOFF_ODDS:
		pick["fix_done"] = true
		Msp.add_note(id, "Handled by Michael.")
		Msp.close_ticket(id)
		return {"say": "GOT IT. #%d IS DONE." % id}
	Msp.add_note(id, "Michael looked at it and it still needs you.")
	return {"say": "I LOOKED AT #%d. IT NEEDS YOU, SORRY." % id}


# Adam takes the oldest open ticket: the clever fix when there is one (it is slower now and saves a call-back), otherwise the careful routine
static func _senior_act(contact: Dictionary) -> Dictionary:
	var stuck := {}
	for t in Msp.open_tickets():
		if bool(t.get("internal", false)):
			continue
		if stuck.is_empty() or int(t.id) < int(stuck.id):
			stuck = t
	_cost(CHAT_COST * 3.0, 0.0)
	_cooldown(contact, SENIOR_GAP)
	if stuck.is_empty():
		return {"say": "NOTHING IS STUCK. YOUR QUEUE IS EMPTY. GO GET A COFFEE."}
	var ep: Dictionary = Msp.endpoint(str(stuck.endpoint))
	var alts: Array = Msp.alts_for(ep) if not ep.is_empty() else []
	var say := ""
	if alts.is_empty():
		say = "ON #%d: THE CAREFUL WAY. BACK IT UP, FIX IT, TEST IT BEFORE YOU CLOSE." % int(stuck.id)
	else:
		say = "ON #%d, TRY: %s. IT TAKES LONGER NOW AND IT STAYS FIXED." % [int(stuck.id), str(Msp.alt_label(ep, str(alts[0]))).to_upper()]
	Msp.add_note(int(stuck.id), "Adam's advice: " + say.to_lower())
	Skills.add_xp("servers", 1)
	return {"say": say}


static func _client_act(contact: Dictionary, opt: String, n: int) -> Dictionary:
	var c := int(contact.client)
	_cost(CHECK_COST, 1.0)
	var gap := CLIENT_GAP
	var say := ""
	match opt:
		"check":
			var list := client_tickets(c)
			if list.is_empty():
				Sales.adjust(c, 1)
				say = "NOTHING WRONG. NICE OF YOU TO CHECK IN!"
			else:
				Sales.adjust(c, 2)
				say = ticket_hint(list[0])
		"sorry":
			Sales.adjust(c, 4)
			say = "I APPRECIATE THAT. JUST GET IT DONE."
		"refer":
			gap = REFERRAL_GAP
			var rng := Difficulty.rng_for("phone.referral", Campaign.day * 100 + c * 7 + n)
			if rng.randf() < REFERRAL_ODDS:
				Campaign.adjust_rep(1)
				if Campaign.active:
					Skills.add_xp("people", 3)
				say = "I WILL PASS YOUR NUMBER TO A FRIEND."
			else:
				say = "NOT RIGHT NOW. I WILL KEEP YOU IN MIND."
	_cooldown(contact, gap)
	return {"say": say}
