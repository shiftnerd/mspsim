extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the rap sheet of the rival MSPs (docs/scope-bad-habits.md section 2). A static helper (no state of its own, like Incident):
# what the player has learned lives in Owner.flags["rap_<rival>_<habit>"] (int 0-3, saved with the campaign) and only ever goes UP.
# Levels: 0 UNKNOWN, 1 RUMOUR (heard, cannot be used), 2 SEEN (you saw it yourself), 3 PROVEN (a document, photo, log or vendor letter).
# The beats of the 20 week arc are cards in RivalCards.CARDS. arc_week() queues them, morning() shows them.
# Ideas only from the blog series the doc credits: no names, scenes or lines from it. 2013-14 text rules apply (3x5 font charset).
# OWNER OF THIS FILE: the rival/beats agent. Public signatures below are FINAL.
# The beat cards are shown as a COPY (Owner._dynamic["rv_<id>"]) so {rc} (the client of the arc), {rh} (the habit decided) can be filled and
# gated options (SHOW THE SHEET, REPORT TO THE VENDOR) left out. Their fx key `rival` is applied by apply_fx() (called from Owner.apply).

const Habits := preload("res://scripts/habits.gd")
const Temptation := preload("res://scripts/temptation.gd")

const LEVELS := ["UNKNOWN", "RUMOUR", "SEEN", "PROVEN"]
const UNKNOWN := 0
const RUMOUR := 1
const SEEN := 2
const PROVEN := 3

# the 17 habits: name (short, for the tab), text (our wording), twin (the matching good habit of the player, Habits.HABITS)
const DEFAULT_HABITS := {
	"R01":
	{
		"name": "FREEZER BAG BACKUP",
		"text":
		"The only backup is one USB drive in a freezer bag in the owner's trunk, trusted because the light is on.",
		"twin": "H1"
	},
	"R02":
	{
		"name": "ONE ADMIN PASSWORD",
		"text": "One admin password for every client, and the front desk has it on a yellow note.",
		"twin": "H7"
	},
	"R03":
	{
		"name": "TWO-FACTOR LOGIN OFF",
		"text": "Two-factor login switched off for convenience on the hosted email.",
		"twin": "H4"
	},
	"R04":
	{
		"name": "GREEN DASHBOARD",
		"text":
		"Antivirus, backup and monitoring agents are installed but never configured: a green dashboard and nothing watching.",
		"twin": "H11"
	},
	"R05":
	{
		# the 17 habits: name (short, for the tab), text (our wording), twin (the matching good habit of the player, Habits.HABITS)
		"name": "FALSE QUESTIONNAIRES",
		"text": "False answers on the client's and the insurer's security questionnaire.",
		"twin": "H10"
	},
	"R06":
	{
		"name": "SEAT COUNT LIES",
		"text": "Lies to the vendor about seat counts for a discount.",
		"twin": "H10"
	},
	"R07":
	{
		"name": "REBOOT AS DIAGNOSTICS",
		"text": "Bills a reboot as advanced diagnostics and invents fees.",
		"twin": "H2"
	},
	"R08":
	{
		"name": "FAKE FIXES",
		"text": "Fakes a fix on the phone to calm a nervous client.",
		"twin": "H13"
	},
	"R09":
	{
		"name": "FAKE REVIEWS",
		"text":
		"Fake Yowl reviews and forum personas, and whispers that you are not bonded or HIPAA safe.",
		"twin": "H10"
	},
	"R10":
	{
		"name": "LAUNDERED LEADS",
		"text":
		"Uses leads that came from reading your tickets in a shared mailbox, then launders them through a referral.",
		"twin": "H13"
	},
	"R11":
	{
		"name": "FLAT PRICE",
		"text":
		"One flat per-seat price and nothing itemized, so the client cannot see what is not included.",
		"twin": "H2"
	},
	"R12":
	{
		"name": "NO DOCUMENTATION",
		"text": "Undocumented work: no scope, no change ticket, three photos as documentation.",
		"twin": "H3"
	},
	"R13":
	{
		"name": "ARCHIVING OFF",
		"text": "Email archiving switched off so a partner can delete messages.",
		"twin": "H4"
	},
	"R14":
	{
		"name": "OLD LOGINS ALIVE",
		"text": "Ex-employees and an ex-vendor rep still have working logins.",
		"twin": "H6"
	},
	"R15":
	{
		"name": "OPEN DOOR AND DEFAULTS",
		"text":
		"A temporary firewall exception open since 2012, and default camera and printer passwords.",
		"twin": "H8"
	},
	"R16":
	{
		"name": "CLOCK CHANGE WINDOW",
		"text":
		"A 2:30 a.m. maintenance window that the clock change eats, and root cause recorded as Unknown.",
		"twin": "H9"
	},
	"R17":
	{
		"name": "IGNORES THE FRONT DESK",
		"text": "Ignores the one person at the client who sees the symptoms first.",
		"twin": "H12"
	},
}
static var HABITS: Dictionary = DEFAULT_HABITS.duplicate(true)

# the rivals: name (for lines and tabs), owner, habits (the rap sheet), blurb (tab text)
const DEFAULT_RIVALS := {
	"bytebrothers":
	{
		"name": "BYTEBROTHERS",
		"owner": "THE BROTHERS",
		"habits": ["R04", "R11", "R12", "R16", "R17"],
		"blurb": "The discount shop. Twenty percent under, twenty percent less delivered."
	},
	"bigcheese":
	{
		"name": "BIG CHEESE",
		"owner": "REX CALLOWAY",
		"habits":
		[
			"R01",
			"R02",
			"R03",
			"R04",
			"R05",
			"R06",
			"R07",
			"R08",
			"R09",
			"R10",
			"R11",
			"R12",
			"R13",
			"R14",
			"R15",
			"R16",
			"R17"
		],
		"blurb": "Big Cheese Technology Group. We do it all for $39 a seat. Booked solid."
	},
	"plumbline":
	{
		"name": "PLUMB LINE",
		"owner": "HOLLIS GRADY",
		"habits": [],
		"blurb": "The careful one who cannot sell. Nine page proposals."
	},
}
static var RIVALS: Dictionary = DEFAULT_RIVALS.duplicate(true)

# the arc: the week a beat card should be SEEN -> its card id in RivalCards.CARDS (docs section 2.4). Skipped while the card does not exist.
const ARC := {
	3: "rival_flat",
	5: "rival_wall",
	7: "rival_defect",
	8: "temp_seats",
	9: "temp_reboot",
	10: "rival_notebook",
	11: "rival_takeover",
	12: "temp_review",
	13: "rival_2fa",
	15: "rival_vendor_audit",
	16: "temp_quest",
	17: "rival_exposed",
	18: "rival_blitz",
	19: "rival_badday",
	20: "rival_end",
}
const QUEUE_KEY := "arc_queue"  # Owner.flags: card ids waiting for the next morning


# ---- the rap sheet ----------------------------------------------------------------------------------------------
static func key(rival: String, habit: String) -> String:
	return "rap_%s_%s" % [rival, habit]


# 0-3 (see LEVELS)
static func rap(rival: String, habit: String) -> int:
	return clampi(int(Owner.flags.get(key(rival, habit), 0)), 0, 3)


# raise the level; evidence never goes down. True when it went up.
static func set_rap(rival: String, habit: String, level: int) -> bool:
	level = clampi(level, 0, 3)
	if level <= rap(rival, habit):
		return false
	Owner.flags[key(rival, habit)] = level
	return true


# how many habits of this rival are known at exactly this level
static func count(rival: String, level: int) -> int:
	var n := 0
	for h in RIVALS.get(rival, {}).get("habits", []):
		n += 1 if rap(rival, str(h)) == level else 0
	return n


# true when anything at all is known about the rival
static func known(rival: String) -> bool:
	for level in [RUMOUR, SEEN, PROVEN]:
		if count(rival, level) > 0:
			return true
	return false


# the weekly report line: BIG CHEESE: 3 PROVEN, 2 SEEN, 1 RUMOUR ("" while nothing is known)
static func line(rival: String) -> String:
	var parts := []
	for level in [PROVEN, SEEN, RUMOUR]:
		var n := count(rival, level)
		if n > 0:
			parts.append("%d %s" % [n, LEVELS[level]])
	if parts.is_empty():
		return ""
	return "%s: %s" % [str(RIVALS.get(rival, {}).get("name", rival.to_upper())), ", ".join(parts)]


# every known line, for the weekly report and the RIVALS tab
static func lines() -> Array:
	var out := []
	for r in RIVALS:
		var l := line(str(r))
		if l != "":
			out.append(l)
	return out


# the best level the player holds on a habit across all rivals (the warning options need SEEN or better)
static func best(habit: String) -> int:
	var top := 0
	for r in RIVALS:
		top = maxi(top, rap(str(r), habit))
	return top


# the evidence fx: rap [rival, habit, level], or a list of those
static func apply_rap(fx: Array) -> void:
	if not fx.is_empty() and fx[0] is Array:
		for one in fx:
			apply_rap(one)
		return
	if fx.size() >= 3:
		set_rap(str(fx[0]), str(fx[1]), int(fx[2]))


# ---- the arc (weeks 3-20) ---------------------------------------------------------------------------------------
# the evidence a beat card gives by being shown at all (a document, a letter, a forwarded email): rival, habit, level
const ON_SHOW := {
	"rival_2fa": [["bigcheese", "R03", 2]],
	"rival_vendor_audit": [["bigcheese", "R06", 3]],
	"rival_exposed": [["bigcheese", "R09", 3]],
}
# a beat that is followed, the same morning, by the four option decision about this habit
const DECIDES := {"rival_2fa": "R03", "rival_vendor_audit": "R06", "rival_exposed": "R09"}
# habits a vendor can act on (REPORT TO THE VENDOR needs PROVEN)
const VENDOR_HABITS := ["R04", "R06"]
# habits Vic can hear about at the Chamber lunch (the rest come from visits, notebooks and letters)
const INTEL_POOL := ["R09", "R10", "R08", "R07", "R06", "R05", "R03", "R01"]
const INTEL_WEEKS := [3, 6, 9, 12, 14]
const RELABEL_FROM := 6  # from this week half the price and gap poaches are Big Cheese (the label changes, never the number of rolls)
const KNEW_AFTER := 4  # weeks after ignoring a SEEN habit that the "you knew" card can come
const BC := "bigcheese"


# true when this client left for Big Cheese (flag set when it was dropped)
static func defected(client: int) -> bool:
	return Owner.flags.has("rival_def_%d" % client)


# the client the arc is about (Delia's office), -1 until one defects
static func arc_client() -> int:
	return int(Owner.flags.get("rival_client", -1))


# the client who is least happy and was not called by a rival lately: the one who gives notice in week 7
static func pick_client() -> int:
	var best_client := -1
	var worst := 1000
	for c in Sales.active:
		if Campaign.day - int(Owner.flags.get("poached_%d" % int(c), -99)) < 3:
			continue
		var m: int = Sales.mood(int(c))
		if m < worst:
			worst = m
			best_client = int(c)
	return best_client


# called from Owner.settle() with the week just finished: queue the beat for NEXT week (so the card comes up in the morning).
# Only cards that exist are queued; a queued beat is shown once (flag arc_<id>). Also runs the slow consequences.
static func arc_week(owner: Node, week: int) -> void:
	_consequences(owner, week)
	if INTEL_WEEKS.has(week):
		intel(BC)
	var id: String = str(ARC.get(week + 1, ""))
	if id == "" or owner.flags.has("arc_" + id) or owner.card_data(id).is_empty():
		return
	if id == "rival_defect" and Sales.active.size() < 2:
		return  # never take the last clients (the beat is skipped, the arc goes on)
	_queue(owner, id)


static func _queue(owner: Node, entry: String) -> void:
	var q: Array = owner.flags.get(QUEUE_KEY, [])
	if not q.has(entry):
		q.append(entry)
	owner.flags[QUEUE_KEY] = q


# retaliation of the vendor report, the "you knew" card of an ignored habit
static func _consequences(owner: Node, week: int) -> void:
	var r := int(owner.flags.get("rival_retaliate", 0))
	if r > 0 and (week == r + 1 or week == r + 3):
		Campaign.adjust_rep(-1)
		Msp.send_text(
			"Marge",
			"Someone at the Chamber lunch is telling people we cannot be trusted. Rex, I think."
		)
	var keys := []
	for k in owner.flags:
		if str(k).begins_with("rival_knew_"):
			keys.append(str(k))
	keys.sort()
	for k in keys:
		var since := int(owner.flags[k])
		var habit: String = k.substr("rival_knew_".length())
		if since <= 0 or week - since < KNEW_AFTER or owner.flags.has("knewdone_" + habit):
			continue
		owner.flags["knewdone_" + habit] = week
		if Difficulty.rng("rival").randf() < 0.6 or week - since >= KNEW_AFTER + 3:
			_queue(owner, "rival_knew|" + habit)


# called from Owner.begin_day() next to Incident.morning(): show one queued beat card (and the decision that follows some of them)
static func morning(owner: Node) -> void:
	var q: Array = owner.flags.get(QUEUE_KEY, [])
	if q.is_empty():
		return
	var entry := str(q.pop_front())
	owner.flags[QUEUE_KEY] = q
	var parts := entry.split("|")
	var id := str(parts[0])
	var arg := str(parts[1]) if parts.size() > 1 else ""
	if not ARC.values().has(id):
		show(owner, id, arg)  # a counter-rumour, a "you knew"
		return
	owner.flags["arc_" + id] = Campaign.day
	if not _ready(owner, id):
		return
	for rec in ON_SHOW.get(id, []):
		set_rap(str(rec[0]), str(rec[1]), int(rec[2]))
	show(owner, id, "")
	if DECIDES.has(id):
		show(owner, "rival_decide", str(DECIDES[id]))


# the conditions of the client beats; a beat that does not apply is dropped
static func _ready(owner: Node, id: String) -> bool:
	var rc := arc_client()
	match id:
		"rival_defect":
			if rc >= 0 and defected(rc):
				return false  # a Big Cheese poach already took a client: that is this beat
			rc = pick_client()
			if rc < 0 or Sales.active.size() < 2:
				return false
			owner.flags["rival_client"] = rc
		"rival_notebook":
			return rc >= 0 and owner.gone.has(rc) and defected(rc)
		"rival_takeover":
			return rc >= 0 and owner.gone.has(rc) and not Sales.active.has(rc)
	return true


# show a card of this file as a copy with the names filled in and the gated options left out
static func show(owner: Node, id: String, arg: String) -> void:
	var card: Dictionary = owner.card_data(id).duplicate(true)
	if card.is_empty():
		return
	var names := {"{rc}": "THE OFFICE", "{rh}": "", "{rl}": ""}
	var rc := arc_client()
	if rc >= 0 and rc < Msp.CLIENTS.size():
		names["{rc}"] = str(Msp.CLIENTS[rc].name)
	if id == "rival_decide" or id == "rival_knew":
		owner.flags["rival_dh"] = arg
		names["{rh}"] = str(HABITS.get(arg, {}).get("name", arg)).to_lower()
		names["{rl}"] = str(HABITS.get(arg, {}).get("text", ""))
	card = _fill(card, names)
	var options: Array = card.options
	for i in range(options.size() - 1, -1, -1):
		if not _allowed(id, i, arg):
			options.remove_at(i)
	card["beat"] = true
	owner._dynamic["rv_" + id] = card
	owner.show_card("rv_" + id)


static func _fill(v: Variant, names: Dictionary) -> Variant:
	if v is String:
		var s: String = v
		for k in names:
			s = s.replace(str(k), str(names[k]))
		return s
	if v is Array:
		for i in v.size():
			v[i] = _fill(v[i], names)
	elif v is Dictionary:
		for k in v:
			v[k] = _fill(v[k], names)
	return v


# which options of a card exist: SHOW THE SHEET needs a proven item and a Standard of 60; REPORT TO THE VENDOR needs PROVEN
static func _allowed(id: String, index: int, arg: String) -> bool:
	if id == "rival_blitz" and index == 1:
		return count(BC, PROVEN) > 0 and Habits.standard() >= 60
	if id == "rival_decide" and index == 2:
		return VENDOR_HABITS.has(arg) and best(arg) >= PROVEN
	return true


# ---- fx key `rival` (Owner.apply) ----------------------------------------------------------------------------------
# ops: tag n / defect (the client leaves for Big Cheese), exit (the exit chat: R11 SEEN), return (back from Big Cheese, takeover pending),
# scope, mood n, discount [mult, weeks], sign n, ignore habit, decide win|warn|vendor|ignore
static func apply_fx(owner: Node, ops: Dictionary) -> void:
	var rc := arc_client()
	if ops.has("defect") and rc >= 0 and Sales.active.has(rc):
		owner.drop_client(rc, "price")
		_tag(owner, rc)
	if ops.has("tag"):
		_tag(owner, int(ops.tag))
	if ops.has("exit"):
		defect_exit(BC, int(ops.exit) if ops.exit is int or ops.exit is float else rc)
	if ops.get("return", false) and rc >= 0 and owner.gone.has(rc) and not Sales.active.has(rc):
		owner.apply({"rejoin": rc, "mood": {str(rc): int(ops.get("mood", 0))}})
		owner.flags["takeover_pending_%d" % rc] = Campaign.day
		owner.flags["rival_returned"] = Campaign.day
	elif ops.has("mood") and rc >= 0 and Sales.active.has(rc):
		Sales.adjust(rc, int(ops.mood))
	if ops.get("scope", false) and Sales.active.has(rc):
		owner.scope_fixed[rc] = true
	if ops.has("discount") and rc >= 0 and Sales.active.has(rc):
		owner.discount[rc] = {"mult": float(ops.discount[0]), "weeks": int(ops.discount[1])}
	if ops.has("sign"):
		for _i in int(ops.sign):
			Sales.sign_client(-1)
	if ops.has("ignore"):
		_ignore(owner, str(ops.ignore))
	if ops.has("decide"):
		_decide(owner, str(ops.decide), str(owner.flags.get("rival_dh", "")))


static func _tag(owner: Node, client: int) -> void:
	owner.flags["bc_%d" % client] = Campaign.day
	owner.flags["rival_def_%d" % client] = Campaign.day
	if arc_client() < 0:
		owner.flags["rival_client"] = client
	if owner.gone.has(client):
		owner.gone[client]["rival"] = BC


static func _ignore(owner: Node, habit: String) -> void:
	if habit != "" and best(habit) >= SEEN and not owner.flags.has("rival_knew_" + habit):
		owner.flags["rival_knew_" + habit] = Campaign.day


static func _decide(owner: Node, kind: String, habit: String) -> void:
	var level := best(habit)
	owner.flags["rival_decided_" + habit] = kind
	match kind:
		"warn":
			if level >= SEEN:
				Temptation.change_consc(1)
				Campaign.adjust_rep(1)
				owner._leads += 1
			else:
				Campaign.adjust_rep(-2)
				Temptation.change_consc(-1)
				_queue(owner, "rival_counter")
				(
					Msp
					. send_text(
						"Marge",
						"That letter was only a rumour, not something we saw. It reads as slander, and Rex will say so."
					)
				)
		"vendor":
			owner.flags["rival_retaliate"] = Campaign.day
		"ignore":
			_ignore(owner, habit)


# ---- channels (other files call these) ----------------------------------------------------------------------------
# Vic hears it at the Chamber lunch: an unreliable RUMOUR about a habit of the rival. Returns the habit id learned ("" if none).
# Always draws the same two numbers, so the stream stays in step whatever the player did.
static func intel(rival: String) -> String:
	var r := Difficulty.rng("rival")
	var roll := r.randf()
	var pick := r.randi()
	var chance := Sales.vic_skill() - Growth.vic_penalty()
	chance += (
		0.1 if Owner.vic_plan == "commission" else (-0.05 if Owner.vic_plan == "salary" else 0.0)
	)
	var pool := []
	for h in INTEL_POOL:
		if RIVALS.get(rival, {}).get("habits", []).has(h) and rap(rival, str(h)) == UNKNOWN:
			pool.append(str(h))
	if pool.is_empty() or roll >= clampf(chance + 0.15, 0.2, 0.9):
		return ""
	var habit: String = pool[pick % pool.size()]
	set_rap(rival, habit, RUMOUR)
	Msp.send_text(
		"Vic",
		(
			"Heard at the Chamber lunch, only a rumour: %s. %s."
			% [str(RIVALS[rival].name), str(HABITS[habit].name)]
		)
	)
	return habit


# the defect / winback channel: what a client who left for the rival tells you (SEEN) about R11 and friends
static func defect_exit(rival: String, client: int) -> void:
	set_rap(rival, "R11", SEEN)
	if rival == BC and client >= 0:
		Owner.flags["bc_%d" % client] = Campaign.day


# Owner._poach_card: from week 6 half of the price and gap poaches are Big Cheese (a new label, never another roll), and the exit chat
# gains ASK WHO THEIR NEW IT PERSON IS. The generator draws once either way, so the stream does not depend on the answer.
static func relabel(owner: Node, card_id: String, client: int) -> void:
	if Campaign.day < RELABEL_FROM or Campaign.mode != "owner":
		return
	if Difficulty.rng("rival").randf() >= 0.5:
		return
	var card: Dictionary = owner._dynamic.get(card_id, {})
	if card.is_empty():
		return
	card["text"] = str(card.text).replace(owner.COMPETITOR, "Big Cheese")
	var reason := "price" if card_id == "poach_price" else "gaps"
	for opt in card.options:
		for fx in _fx_of(opt):
			if fx.has("drop_client"):
				fx["rival"] = {"tag": client}
	(
		card
		. options
		. append(
			{
				"label": "WISH THEM WELL AND ASK WHO THEIR NEW IT PERSON IS",
				"fx":
				{
					"drop_client": client,
					"left_for": reason,
					"consc": 1,
					"rival": {"tag": client, "exit": client}
				},
				"text":
				"You ask kindly. The owner tells you, a little proud, and shows you the flyer: EVERYTHING INCLUDED."
			}
		)
	)


# every fx dictionary of an option (its fx and the fx of each roll entry)
static func _fx_of(opt: Dictionary) -> Array:
	var out := []
	if opt.has("fx"):
		out.append(opt.fx)
	for entry in opt.get("roll", []):
		out.append(entry[1])
	return out


# Owner._winback_card: a client that left for Big Cheese comes back with the inherited mess (flag takeover_pending_<client>)
static func on_winback(owner: Node, client: int) -> void:
	if str(owner.gone.get(client, {}).get("rival", "")) != BC:
		return
	owner.flags["takeover_pending_%d" % client] = Campaign.day
	var card: Dictionary = owner._dynamic.get("winback", {})
	if not card.is_empty():
		card["text"] = str(card.text).replace(owner.COMPETITOR, "Big Cheese")


# the findings of an assessment of a lead's incumbent (the sales campaign P5 uses it): 3 to 5 habit ids, the ones you know first
static func assessment(rival: String) -> Array:
	var all: Array = RIVALS.get(rival, {}).get("habits", []).duplicate()
	var out := []
	for level in [PROVEN, SEEN, RUMOUR]:
		for h in all:
			if rap(rival, str(h)) == level and out.size() < 5:
				out.append(str(h))
	var rest := []
	for h in all:
		if not out.has(h):
			rest.append(str(h))
	Difficulty.shuffle(rest, "rival_assess")
	while out.size() < mini(3, all.size()) and not rest.is_empty():
		out.append(rest.pop_front())
	return out
