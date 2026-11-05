extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Lynk 2013 on the desktop: presence (what your coworkers are doing, read from the cast simulation) and instant
# messages. Coworkers message you (lunch, "cover my phones", "how do you fix...", a thank-you) and you answer with quick
# (the owners, Alan and Garrison, ask owner things instead: MESSAGES keys like "phones_Alan" win over "phones")
# replies that move how they feel about you; you can message them (lunch?, need a hand, thanks) and ask the boss
# (Morgan in the tech campaign, Marge in the owner campaign). Friends warn you before a ticket breaches its SLA.
# Campaign only; in free play the app shows presence and nothing else happens.

signal changed

const RivalTouches := preload("res://scripts/rival_touches.gd")  # R38 P6
const COLORS := {
	"green": Color("3cc15a"),
	"amber": Color("e0a030"),
	"red": Color("d23c3c"),
	"grey": Color("8b93a1")
}
const KIND_PRESENCE := {
	"meeting": ["IN A MEETING", "red"],
	"lunch": ["AWAY - LUNCH", "amber"],
	"coffee": ["AWAY", "amber"],
	"cooler": ["AWAY", "amber"],
	"bathroom": ["AWAY", "amber"],
	"news": ["BUSY", "red"],
	"leave": ["OFFLINE", "grey"],
}
const DEFAULT_MESSAGES := {
	"lunch":
	{
		"text": "Lunch? A few of us are grabbing sandwiches.",
		"options":
		[
			{"label": "SURE, LET'S GO", "social": 2, "reply": "Great, see you there!"},
			{"label": "CAN'T, SWAMPED", "social": 0, "reply": "No worries, next time."},
		],
	},
	"phones":
	{
		"text": "Can you cover my phones for ten minutes? I am stuck in a meeting.",
		"options":
		[
			{"label": "SURE", "social": 2, "reply": "Thanks, you are the best."},
			{"label": "SORRY, CAN'T", "social": -1, "reply": "Okay..."},
		],
	},
	"help":
	{
		"text": "Quick one: how do you fix a print spooler that keeps stopping on Server 2008?",
		"options":
		[
			{
				"label": "WALK THEM THROUGH IT",
				"social": 2,
				"xp": 2,
				"reply": "That did it! Thanks."
			},
			{"label": "TOO BUSY RIGHT NOW", "social": -1, "reply": "Sure. No problem."},
		],
	},
	"thanks": {"text": "Hey, thanks for being easy to work with.", "options": []},
	"lunch_Alan":
	{
		"text": "Lunch? I am ordering sandwiches for whoever is around. The company is paying, God help the books.",
		"options":
		[
			{"label": "SURE, LET'S GO", "social": 2, "reply": "Good. I ordered extra pickles."},
			{
				"label": "CAN'T, SWAMPED",
				"social": 0,
				"reply": "No worries. I will leave one in the fridge."
			},
		],
	},
	"lunch_Garrison":
	{
		"text": "Lunch? I am taking the team out for sandwiches. Company card, I promise.",
		"options":
		[
			{"label": "SURE, LET'S GO", "social": 2, "reply": "Great, see you there!"},
			{
				"label": "CAN'T, SWAMPED",
				"social": 0,
				"reply": "No worries, next time. I will tell them you said hi."
			},
		],
	},
	"phones_Alan":
	{
		"text": "Acme's office manager wants a call back and I am buried in vendor invoices. Can you ring them for me?",
		"options":
		[
			{"label": "SURE", "social": 2, "reply": "Thanks. That saves me twenty minutes."},
			{"label": "SORRY, CAN'T", "social": -1, "reply": "Okay... I will do it after the invoices."},
		],
	},
	"phones_Garrison":
	{
		"text": "A client wants a call back and I am stuck in a prospect meeting. Can you ring them and say we are on it?",
		"options":
		[
			{"label": "SURE", "social": 2, "reply": "Thanks, you are the best."},
			{"label": "SORRY, CAN'T", "social": -1, "reply": "Okay... I will step out."},
		],
	},
	"help_Alan":
	{
		"text": "The backup vendor wants us to renew. Can you look at their numbers and tell me if I am being sold something?",
		"options":
		[
			{
				"label": "TAKE A LOOK AT IT",
				"social": 2,
				"xp": 2,
				"reply": "That did it! Thanks. I will push back on the price."
			},
			{
				"label": "TOO BUSY RIGHT NOW",
				"social": -1,
				"reply": "Sure. No problem. I will read the fine print myself."
			},
		],
	},
	"help_Garrison":
	{
		"text": "I have a QBR with Brightside on Thursday. Can you join and answer the technical questions?",
		"options":
		[
			{
				"label": "JOIN THE QBR",
				"social": 2,
				"xp": 2,
				"reply": "Perfect, thank you! I do the charm, you do the facts."
			},
			{
				"label": "TOO BUSY RIGHT NOW",
				"social": -1,
				"reply": "Sure. No problem. I will fake the technical parts."
			},
		],
	},
	"thanks_Alan":
	{
		"text": "Thanks for covering the floor lately. The clients notice, and so do the books.",
		"options": [],
	},
	"thanks_Garrison":
	{
		"text": "Thanks for being great with the clients. They keep mentioning you.",
		"options": [],
	},
	"lunch_Morgan":
	{
		"text": "Lunch? I am eating at my desk again. Bring me a sandwich and I will approve whatever you ask for.",
		"options":
		[
			{"label": "SURE, I WILL BRING ONE", "social": 2, "reply": "Turkey, no pickles. You are a good person."},
			{"label": "CAN'T, SWAMPED", "social": 0, "reply": "Understood. Close the P1s first."},
		],
	},
	"phones_Morgan":
	{
		"text": "I need ten quiet minutes with the owners' budget. Can you cover my phones?",
		"options":
		[
			{"label": "SURE", "social": 2, "reply": "Thank you. I owe you one. Do not tell anyone I said that."},
			{"label": "SORRY, CAN'T", "social": -1, "reply": "Fair. I will let it ring."},
		],
	},
	"help_Morgan":
	{
		"text": "Quick one: Alan wants a count of every Windows XP box we manage before April. Can you pull the list from the RMM for me?",
		"options":
		[
			{"label": "PULL THE LIST", "social": 2, "xp": 2, "reply": "That is exactly what I needed. Thank you."},
			{"label": "TOO BUSY RIGHT NOW", "social": -1, "reply": "Sure. I will do it the slow way."},
		],
	},
	"thanks_Morgan":
	{
		"text": "Thanks for keeping your tickets tidy. It makes my Friday report a lot shorter.",
		"options": [],
	},
}
var MESSAGES: Dictionary = DEFAULT_MESSAGES.duplicate(true)

var chats := {}  # who -> [[from, text], ...]
var unread := {}
var pending := {}  # who -> the message waiting for your reply

var _t := 40.0
var _warn_t := 5.0
var _warned := {}
var _thanked := {}


func _ready() -> void:
	reset()


# ---- Vic's Lynk (sales campaign, C3): the coworkers write to the account manager --------------------------------
const DEFAULT_VIC_MESSAGES := {
	"lunch": {
		"text": "Lunch? A few of us are grabbing sandwiches. No shop talk. Okay, a little shop talk.",
		"options": [
			{"label": "SURE, LET'S GO", "social": 2, "reply": "Great, see you there!"},
			{"label": "CAN'T, I HAVE A CALL", "social": 0, "reply": "No worries, next time."},
		],
	},
	"phones": {
		"text": "One of your new clients keeps calling my desk because someone gave them my number. Can you call them back and say who to ring?",
		"options": [
			{"label": "SURE, SORRY ABOUT THAT", "social": 2, "reply": "Thanks, you are the best."},
			{"label": "THEY LIKE YOU, KEEP THEM HAPPY", "social": -1, "reply": "Okay... I will give them the number of the desk."},
		],
	},
	"help": {
		"text": "Sanity check before you quote: can we really promise a one hour response to a twenty seat shop this month?",
		"options": [
			{"label": "NO. I WILL QUOTE FOUR HOURS", "social": 2, "reply": "Thank you. That is what the crew can honestly do."},
			{"label": "SURE, WE WILL MANAGE", "social": -1, "reply": "Sure. Sure. Put it in writing for Morgan."},
		],
	},
	"thanks": {"text": "Hey, thanks for putting the real SLA in the handover. It makes a difference.", "options": []},
	"lunch_Garrison": {
		"text": "Lunch with a prospect? I am taking someone to the grill and I want you across from them. Company card, I promise.",
		"options": [
			{"label": "SURE, LET'S GO", "social": 2, "reply": "Great, bring the good tie."},
			{"label": "CAN'T, I HAVE A QUOTE DUE", "social": 0, "reply": "No worries. I will tell them you said hi."},
		],
	},
	"phones_Garrison": {
		"text": "A prospect wants a call back and I am stuck in a meeting. Say we are on it and give them a number that sounds like a price.",
		"options": [
			{"label": "SURE", "social": 2, "reply": "Thanks, you are the best."},
			{"label": "I DON'T QUOTE UNTIL I KNOW THE SCOPE", "social": -1, "reply": "Fair, Vic. Fair. I will step out."},
		],
	},
	"help_Garrison": {
		"text": "ByteBrothers just posted a price list. Can you look at it and tell me where they are lying?",
		"options": [
			{"label": "TAKE A LOOK AT IT", "social": 2, "reply": "Perfect. That is why I pay you."},
			{"label": "TOO BUSY RIGHT NOW", "social": -1, "reply": "Sure. No problem. I will ask Alan. He will tell me everything wrong."},
		],
	},
	"lunch_Alan": {
		"text": "Lunch? I am ordering sandwiches. We need to talk about the discounts. Briefly. With pickles.",
		"options": [
			{"label": "SURE, LET'S GO", "social": 2, "reply": "Good. I ordered extra pickles."},
			{"label": "CAN'T, I AM WITH A CLIENT", "social": 0, "reply": "Fine. I will leave one in the fridge."},
		],
	},
	"phones_Alan": {
		"text": "I do not call clients. You call clients. Acme's office manager wants a quote on a printer. Go.",
		"options": [
			{"label": "SURE", "social": 2, "reply": "Thanks. That saves me twenty minutes."},
			{"label": "SORRY, CAN'T", "social": -1, "reply": "Okay... I will do it after the invoices."},
		],
	},
	"help_Alan": {
		"text": "Question: what is the margin on the quote you sent yesterday? Not what you told Garrison. What is it?",
		"options": [
			{"label": "I'LL SEND YOU THE NUMBERS", "social": 2, "reply": "Good. That is all I wanted."},
			{"label": "IT IS FINE, ALAN", "social": -1, "reply": "'Fine' is not a number. I will look it up myself."},
		],
	},
	"help_Dan": {
		"text": "Quick one: the new client says they want 'everything monitored'. What does that mean in dollars? I need to size it.",
		"options": [
			{"label": "I WILL FIND OUT BEFORE I QUOTE", "social": 2, "reply": "Thanks. Ask them how many servers, not how many dreams."},
			{"label": "JUST SAY YES, WE'LL FIGURE IT OUT", "social": -1, "reply": "Sure. I will add that to the list of things we figure out."},
		],
	},
	"help_Morgan": {
		"text": "I am reading the binder for the last deal. The SLA line and the email you sent do not agree. Which one is true?",
		"options": [
			{"label": "THE BINDER. I WILL CORRECT THE EMAIL", "social": 2, "reply": "Thank you. I will note that you were honest about it."},
			{"label": "THE EMAIL. THE CLIENT WAS EXPECTING IT", "social": -1, "reply": "Then we need to change what we can do. Come see me."},
		],
	},
	"help_Maya": {
		"text": "The owner of one of your clients cried on the phone today. She is fine, it was the printer. Do you want me to send flowers? From you.",
		"options": [
			{"label": "YES, PLEASE. THANK YOU", "social": 2, "reply": "Done. I used the company card, do not tell Alan."},
			{"label": "NO, I WILL CALL HER", "social": 1, "reply": "That is even better. Call her before lunch."},
		],
	},
	"warn": {"text": "Heads up: #%d (%s) is about to breach its SLA. That client has your number, Vic."},
}
var VIC_MESSAGES: Dictionary = DEFAULT_VIC_MESSAGES.duplicate(true)
const DEFAULT_VIC_PRESENCE := {
	"meeting": ["IN A CLIENT CALL", "red"],
	"handover": ["WAITING: HANDOVER", "amber"],
	"dan_busy": ["QUEUE IS FULL", "red"],
	"news": ["ON THE PHONE", "red"],
}
var VIC_PRESENCE: Dictionary = DEFAULT_VIC_PRESENCE.duplicate(true)


func reset() -> void:
	chats = {}
	unread = {}
	pending = {}
	_t = 40.0
	_warn_t = 5.0
	_warned = {}
	_thanked = {}


func color_of(key: String) -> Color:
	return COLORS.get(key, Color("8b93a1"))


func boss() -> String:
	return "Marge" if Campaign.mode == "owner" else "Morgan"


func contacts() -> Array:
	var out: Array = Social.people()
	if not out.has(boss()):
		out.append(boss())  # Marge in the owner campaign (Morgan is already a cast member)
	if Campaign.mode == "service":
		for n in Crew.names():
			if not out.has(str(n)):
				out.append(str(n))  # C7: the crew you run are contacts too
	return out


# [status text, colour name] from what the cast is doing right now
func presence(who: String) -> Array:
	if who == boss() and not World.chars.has(who):
		return ["AVAILABLE", "green"]
	if not World.chars.has(who):
		return ["OFFLINE", "grey"]
	var st: Dictionary = World.chars[who]
	if st.scene == World.OUTSIDE:
		var sales: bool = World.row(who).get("role", "") == "sales"
		return (
			["WITH A CLIENT", "amber"]
			if (sales and World.clock < World.DAY_END)
			else ["OFFLINE", "grey"]
		)
	var kind := str(st.legs[0].kind) if not st.legs.is_empty() else "work"
	if Campaign.mode == "sales":
		var vp := _vic_presence(who, kind)
		if not vp.is_empty():
			return vp
	return KIND_PRESENCE.get(kind, ["AVAILABLE", "green"])


# the sales campaign's presence lines: who is waiting for you, who is swamped (C3)
func _vic_presence(who: String, kind: String) -> Array:
	if (who == "Morgan" or who == "Dan") and SalesCampaign.pending_handover != 0 and kind in ["meeting", "work"]:
		return VIC_PRESENCE.handover
	if who == "Dan" and kind == "work" and Msp.open_tickets().size() >= 5:
		return VIC_PRESENCE.dan_busy
	if kind in ["meeting", "news"]:
		return VIC_PRESENCE[kind]
	return []


func unread_total() -> int:
	var n := 0
	for who in unread:
		n += int(unread[who])
	return n


func mark_read(who: String) -> void:
	unread[who] = 0


func open_chat(who: String) -> void:
	mark_read(who)
	changed.emit()


func _push(who: String, from_name: String, text: String) -> void:
	var lines: Array = chats.get(who, [])
	lines.append([from_name, text])
	while lines.size() > 30:
		lines.pop_front()
	chats[who] = lines
	if from_name != "me":
		unread[who] = int(unread.get(who, 0)) + 1
	changed.emit()


func _process(delta: float) -> void:
	if not Campaign.active or Game.title_mode or World.time_scale <= 0.0:
		return
	var dt := delta * World.time_scale
	_t -= dt
	if _t <= 0.0:
		_t = randf_range(50.0, 100.0)
		incoming()
	_warn_t -= dt
	if _warn_t <= 0.0:
		_warn_t = 5.0
		friend_warning()


# a coworker messages you
func incoming(forced_kind := "") -> void:
	if Campaign.mode == "service" and forced_kind == "":
		ServiceArc.lynk_incoming()  # C7: the service cast has its own voices
		return
	if Campaign.mode == "owner" and forced_kind == "" and randf() < 0.2:
		var touch := RivalTouches.lynk_note(Social.people(), boss(), randi())  # R38: the rival, the Standard, the folder
		if not touch.is_empty():
			_push(str(touch[0]), str(touch[0]), str(touch[1]))
			return
	var pool := []
	for who in Social.people():
		if presence(who)[0] == "AVAILABLE" and not pending.has(who):
			pool.append(who)
	if pool.is_empty() or pending.size() >= 2:
		return
	var who: String = pool[randi() % pool.size()]
	if forced_kind == "" and Social.is_cold(who) and randf() < 0.7:
		return
	var kind := forced_kind
	if kind == "":
		var lunch_time: bool = World.clock >= 11.4 and World.clock <= 12.4
		var roll := randf()
		if lunch_time and roll < 0.6:
			kind = "lunch"
		elif roll < 0.45:
			kind = "phones"
		elif roll < 0.8:
			kind = "help"
		else:
			kind = "thanks"
	var table: Dictionary = VIC_MESSAGES if Campaign.mode == "sales" else MESSAGES
	var msg: Dictionary = table.get(kind, MESSAGES[kind])
	if table.has(kind + "_" + who):
		msg = table[kind + "_" + who]
	if kind == "thanks" and Social.value(who) < 25 and forced_kind == "":
		return
	_push(who, who, str(msg.text))
	if not (msg.options as Array).is_empty():
		pending[who] = msg


func reply(who: String, index: int) -> void:
	if not pending.has(who):
		return
	var msg: Dictionary = pending[who]
	var opt: Dictionary = msg.options[clampi(index, 0, msg.options.size() - 1)]
	pending.erase(who)
	_push(who, "me", str(opt.label).capitalize())
	Social.change(who, int(opt.social))
	if opt.has("xp"):
		Skills.add_xp("people", int(opt.xp))
	if Campaign.mode == "service":
		ServiceArc.lynk_reply(who, opt)
	_push(who, who, str(opt.reply))


# you message them: kind = lunch / help / thanks (advice / status for the boss)
func send_action(who: String, kind: String) -> String:
	if who == boss():
		return _boss_reply(who)
	var labels := {
		"lunch": "Lunch?",
		"help": "Got a minute? I could use a hand.",
		"thanks": "Thanks for the help earlier!"
	}
	if kind == "help" and Owners.asks_owner(who):
		labels["help"] = "Do you have a minute? I could use your help."
	_push(who, "me", str(labels.get(kind, "Hi")))
	var status := str(presence(who)[0])
	if status != "AVAILABLE":
		_push(who, who, "I am %s right now. Catch you later." % status.to_lower())
		return "away"
	match kind:
		"lunch":
			var accept: bool = (
				Social.value(who) >= 25 or (Social.value(who) > -15 and randf() < 0.6)
			)
			_push(who, who, "Sure, give me five minutes." if accept else "Not today, sorry.")
			if accept:
				Social.change(who, 2)
		"thanks":
			var now := Time.get_ticks_msec() / 1000.0
			if now - float(_thanked.get(who, -999.0)) > 60.0:
				Social.change(who, 1)
				_thanked[who] = now
			_push(who, who, "Anytime!")
		_:
			_lend_a_hand(who)
	return kind


func _lend_a_hand(who: String) -> void:
	if Campaign.mode == "sales":
		_push(who, who, Talk.sales_answer(who))  # a coworker's view of delivery, not a ticket fix
		return
	if Social.is_manager(who):
		_push(who, who, "I run the desk, I do not take tickets. Tell me what is blocking you and I will clear the road.")
		return
	if Owners.asks_owner(who):
		_push(who, who, Owners.ask(who))  # ASK THE OWNER (tech campaign): an approval, a tip or a call to the client
		return
	var willing: bool = Social.value(who) >= 0 or randf() < 0.4
	var ticket := _helpable_ticket()
	var owner_voice := Social.is_owner(who)
	if not willing:
		_push(who, who, "Sorry, I am buried in the books today." if owner_voice else "Sorry, I am swamped.")
	elif ticket.is_empty():
		_push(who, who, "Nothing in your queue needs me. Looking good!")
	else:
		Msp.rmm_action(str(ticket.endpoint), str(ticket.fix))
		var done := "On it... done: #%d is fixed. You owe me one."
		if owner_voice:
			done = "Fine, I will look. Done: #%d is fixed. Do not make a habit of it."
		_push(who, who, done % int(ticket.id))
		Social.change(who, -1)


func _helpable_ticket() -> Dictionary:
	for t in Msp.open_tickets():
		if (
			t.internal
			or t.fix_done
			or str(t.special) != ""
			or t.fix == "project"
			or t.fix == "network"
		):
			continue
		return t
	return {}


func _boss_reply(who: String) -> String:
	if Campaign.mode == "sales":
		_push(who, "me", "Anything I should know about delivery?")
		_push(who, who, Talk.sales_answer(who))
		return "boss"
	_push(who, "me", "Any advice?" if who == "Morgan" else "How are we doing?")
	var text := "You are doing fine."
	if Campaign.mode == "service":
		text = ServiceArc.boss_line()
	if who == "Marge":
		var est: Dictionary = Owner.weekly_estimate()
		text = (
			"Cash is $%d. We make about $%d a week before one-offs. Receivables are $%d."
			% [Owner.cash, int(est.ebitda), Owner.ar_total()]
		)
		var touch := RivalTouches.marge_line()
		if touch != "":
			text += " " + touch
	elif Campaign.mode != "service":
		var unchecked := false
		for c in Sales.active:
			unchecked = unchecked or int(Msp.backups[int(c)].checked_day) != Campaign.day
		if unchecked:
			text = "Have you checked the client backups today?"
		elif Msp.open_tickets().size() >= 4:
			text = "The queue is getting long. Work the P1s first."
		elif Skills.ps_level < 2:
			text = "Try a PowerShell lesson between tickets. It pays off."
	_push(who, who, text)
	return "boss"


# a friend tells you before an SLA breach
func friend_warning() -> void:
	for t in Msp.open_tickets():
		if t.internal or _warned.has(int(t.id)) or t.breached or float(t.sla_left) > 40.0:
			continue
		for who in Social.people():
			if Social.is_friendly(who) and presence(who)[0] == "AVAILABLE":
				_warned[int(t.id)] = true
				_push(
					who,
					who,
					(str(VIC_MESSAGES.warn.text) if Campaign.mode == "sales" else "Heads up: #%d (%s) is about to breach its SLA.") % [int(t.id), str(t.summary)]
				)
				return
