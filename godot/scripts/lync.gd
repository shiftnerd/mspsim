extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Microsoft Lync 2013 on the desktop: presence (what your coworkers are doing, read from the cast simulation) and instant
# messages. Coworkers message you (lunch, "cover my phones", "how do you fix...", a thank-you) and you answer with quick
# replies that move how they feel about you; you can message them (lunch?, need a hand, thanks) and ask the boss
# (Morgan in the tech campaign, Marge in the owner campaign). Friends warn you before a ticket breaches its SLA.
# Campaign only; in free play the app shows presence and nothing else happens.

signal changed

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
	var out: Array = Social.PEOPLE.duplicate()
	out.append(boss())
	return out


# [status text, colour name] from what the cast is doing right now
func presence(who: String) -> Array:
	if who == boss():
		return ["AVAILABLE", "green"]
	if not World.chars.has(who):
		return ["OFFLINE", "grey"]
	var st: Dictionary = World.chars[who]
	if st.scene == World.OUTSIDE:
		var sales: bool = World.CAST[who].get("role", "") == "sales"
		return (
			["WITH A CLIENT", "amber"]
			if (sales and World.clock < World.DAY_END)
			else ["OFFLINE", "grey"]
		)
	var kind := str(st.legs[0].kind) if not st.legs.is_empty() else "work"
	return KIND_PRESENCE.get(kind, ["AVAILABLE", "green"])


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
	var pool := []
	for who in Social.PEOPLE:
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
	var msg: Dictionary = MESSAGES[kind]
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
	var willing: bool = Social.value(who) >= 0 or randf() < 0.4
	var ticket := _helpable_ticket()
	if not willing:
		_push(who, who, "Sorry, I am swamped.")
	elif ticket.is_empty():
		_push(who, who, "Nothing in your queue needs me. Looking good!")
	else:
		Msp.rmm_action(str(ticket.endpoint), str(ticket.fix))
		_push(who, who, "On it... done: #%d is fixed. You owe me one." % int(ticket.id))
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
	_push(who, "me", "Any advice?" if who == "Morgan" else "How are we doing?")
	var text := "You are doing fine."
	if who == "Marge":
		var est: Dictionary = Owner.weekly_estimate()
		text = (
			"Cash is $%d. We make about $%d a week before one-offs. Receivables are $%d."
			% [Owner.cash, int(est.ebitda), Owner.ar_total()]
		)
	else:
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
		for who in Social.PEOPLE:
			if Social.is_friendly(who) and presence(who)[0] == "AVAILABLE":
				_warned[int(t.id)] = true
				_push(
					who,
					who,
					"Heads up: #%d (%s) is about to breach its SLA." % [int(t.id), str(t.summary)]
				)
				return
