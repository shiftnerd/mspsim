extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: temptation cards, skeletons and the conscience (docs/scope-bad-habits.md section 5). A static helper like Incident.
# A shortcut card seeds a SKELETON in Owner.skel: {id, due, class, size}. When Campaign.day reaches due the bill arrives (week()), unless
# the player comes clean first (come_clean(): cheaper than the bill, conscience +1). due 99 means no date: a trigger fires it (TODO).
# Conscience (Owner.consc, int, 0 clean to negative) is shown ONLY as a band word and as Marge's folder (folder_count()), never a number.
# The cards themselves are data in RivalCards.CARDS (fx keys: skel [id, weeks], consc n). Cozy Easy halves every bill.
# OWNER OF THIS FILE: the temptation agent (temptation.gd + the temp_* cards). Public signatures below are FINAL; fill the TODO bodies.

const NO_DATE := 99
const CLEAN_SHARE := 0.4  # coming clean costs this share of the bill (never less than CLEAN_MIN)
const CLEAN_MIN := 50
const DILIGENCE_FROM := 16  # buyers start looking at the folder in week 16
const MAX_DEDUCTION := 1.5  # due diligence: -0.5 of the multiple per open skeleton, at most this
const PER_SKELETON := 0.5
const WEEKLY_HONEST := 1  # honest choices raise the conscience by at most this much a week
const VENDOR_COLD := 8  # a vendor that caught you stops the partner discount: this much more a week
const REBATE := 400  # a clean record earns a vendor partner rebate (one time, cash)
const REBATE_FROM := 16  # ... from the week the shortcut would have been audited
const FRIEND_LOSS := 30  # forum friendship lost by the two best regulars when fake reviews are traced
const CLEAN_EVERY := 4  # the COME CLEAN card comes at most this often (weeks), from the second open skeleton
const CLEAN_CARD := "temp_come_clean"
const BANDS := [
	[0, "CLEAN BOOKS"], [-3, "A FEW LOOSE ENDS"], [-6, "SKELETONS"], [-999, "A CLOSET FULL"]
]

# id -> class, lo / hi (weeks until the bill), size (the bill in cash), rep (reputation lost), mood (all clients), text (the toast / card line)
# Numbers follow docs section 5; the agent tunes them with the `shortcuts` bot (a bill is 2 to 3 times the gain).
const BILLS := {
	"temp_seats":
	{
		"class": "vendor",
		"lo": 6,
		"hi": 8,
		"size": 1100,
		"weekly": 71,
		"rep": 0,
		"mood": 0,
		"text": "The vendor audited the seat count. Back bill plus a 25 percent penalty."
	},
	"temp_reboot":
	{
		"class": "client",
		"lo": 4,
		"hi": 6,
		"size": 200,
		"weekly": 25,
		"rep": 1,
		"mood": 10,
		"text": "A bookkeeper audited one invoice. Refund, and the client is not happy."
	},
	"temp_quest":
	{
		"class": "insurer",
		"lo": NO_DATE,
		"hi": NO_DATE,
		"size": 1800,
		"weekly": 27,
		"rep": 2,
		"mood": 0,
		"text": "The insurer refused the claim because the questionnaire answers were false."
	},
	"temp_review":
	{
		"class": "reputation",
		"lo": 4,
		"hi": 5,
		"size": 0,
		"rep": 4,
		"mood": 0,
		"text": "A forum thread traced the writing style of the fake reviews."
	},
	"temp_launder":
	{
		"class": "client",
		"lo": 5,
		"hi": 7,
		"size": 0,
		"rep": 3,
		"mood": 20,
		"text": "The contact asked how you knew. The client whose mailbox it was leaves."
	},
	"temp_price":
	{
		"class": "margin",
		"lo": 2,
		"hi": 3,
		"size": 600,
		"rep": 0,
		"mood": 0,
		"text": "The profit review shows a client under 20 percent of the fee."
	},
	"temp_2fa":
	{
		"class": "client",
		"lo": 9,
		"hi": 10,
		"size": 1200,
		"rep": 3,
		"mood": 12,
		"text": "The breach hit and your recommendation was never on paper."
	},
	"temp_restore":
	{
		"class": "backup",
		"lo": 2,
		"hi": 7,
		"size": 800,
		"rep": 2,
		"mood": 8,
		"text": "The backup would not restore. The light was on. It was not enough."
	},
}


# ---- conscience -----------------------------------------------------------------------------------------------------
static func consc() -> int:
	return int(Owner.consc)


# change the conscience. A rise is capped at WEEKLY_HONEST a week (flag consc_week); a fall is not.
static func change_consc(n: int, force := false) -> void:
	if n > 0 and not force:
		if int(Owner.flags.get("consc_week", -1)) == Campaign.day:
			return
		n = mini(n, WEEKLY_HONEST)
		Owner.flags["consc_week"] = Campaign.day
	Owner.consc += n


# CLEAN BOOKS / A FEW LOOSE ENDS / SKELETONS / A CLOSET FULL
static func band() -> String:
	var c := consc()
	for b in BANDS:
		if c >= int(b[0]):
			return str(b[1])
	return "A CLOSET FULL"


# ---- skeletons ------------------------------------------------------------------------------------------------------
# the number of open skeletons: what Marge's folder holds
static func folder_count() -> int:
	return Owner.skel.size()


static func find(id: String) -> int:
	for i in Owner.skel.size():
		if str(Owner.skel[i].get("id", "")) == id:
			return i
	return -1


# seed a skeleton. weeks < 0: draw 3 to 9 weeks (or the BILLS range) from Difficulty.rng("skeleton"). One of each id at a time.
static func add_skeleton(id: String, weeks := -1) -> bool:
	if find(id) >= 0:
		return false
	var b: Dictionary = BILLS.get(id, {})
	if weeks < 0:
		var lo := int(b.get("lo", 3))
		var hi := int(b.get("hi", 9))
		weeks = lo if lo >= NO_DATE else Difficulty.rng("skeleton").randi_range(lo, hi)  # TODO(temptation agent): jitter
	var due := NO_DATE if weeks >= NO_DATE else Campaign.day + weeks
	Owner.skel.append(
		{
			"id": id,
			"due": due,
			"class": str(b.get("class", "other")),
			"size": int(b.get("size", 500))
		}
	)
	return true


# the fx skel [id, weeks], or a list of those
static func apply_skel(fx: Array) -> void:
	if not fx.is_empty() and fx[0] is Array:
		for one in fx:
			apply_skel(one)
	elif not fx.is_empty():
		add_skeleton(str(fx[0]), int(fx[1]) if fx.size() > 1 else -1)


# the bill for a skeleton (cozy Easy halves it)
static func bill_size(sk: Dictionary) -> int:
	var size := int(sk.get("size", 0))
	return size / 2 if Difficulty.cozy_on() else size


# what coming clean costs
static func clean_cost(id: String) -> int:
	var i := find(id)
	if i < 0:
		return 0
	var full := bill_size(Owner.skel[i])
	return maxi(CLEAN_MIN, int(float(full) * CLEAN_SHARE)) if full > 0 else 0


# own up before the bill: pay clean_cost(), remove the skeleton, conscience +1. False if there is no such skeleton.
static func come_clean(id: String) -> bool:
	var i := find(id)
	if i < 0:
		return false
	var cost := clean_cost(id)
	Owner.cash -= cost
	Owner.weekly_extra += int(BILLS.get(id, {}).get("weekly", 0))  # the true numbers again
	Owner.skel.remove_at(i)
	Career.add("skeletons_paid")  # R38 P6
	change_consc(1, true)
	return true


# the bill arrives: cash, reputation, the class extras (see _extras) and the card bill_<id> of RivalCards (a toast if it has none)
static func bill(owner: Node, sk: Dictionary) -> void:
	Career.add("skeletons_paid")  # R38 P6
	var id := str(sk.get("id", ""))
	var b: Dictionary = BILLS.get(id, {})
	var cost := bill_size(sk)
	if cost > 0:
		owner.cash -= cost
	if int(b.get("rep", 0)) > 0:
		Campaign.adjust_rep(-int(b.rep))
	var victim := _victim(owner, str(b.get("class", "")))
	_extras(owner, id, b, victim)
	var card := "bill_" + id
	if owner.card_data(card).is_empty():
		Hints.toast(
			"A BILL FROM THE FOLDER: " + str(b.get("text", "A SHORTCUT CAUGHT UP WITH YOU.")), 5.0
		)
		return
	owner._dynamic["tb_" + id] = _dress_bill(owner, owner.card_data(card), victim, cost, id)
	owner.show_card("tb_" + id)


# the client a bill falls on: the margin bill the one on the deepest discount, the backup bill the ransom client, the others the
# client of the wire story (Incident.fill remembers it) or one drawn from the "skeleton" stream. -1 when there is no client.
static func _victim(owner: Node, cls: String) -> int:
	if Sales.active.is_empty() or not ["client", "margin", "backup"].has(cls):
		return -1
	if cls == "margin":
		var worst := -1
		var mult := 2.0
		for k in owner.discount:
			if Sales.active.has(int(k)) and float(owner.discount[k].get("mult", 1.0)) < mult:
				mult = float(owner.discount[k].mult)
				worst = int(k)
		if worst >= 0:
			return worst
	if cls == "backup" and Sales.active.has(Story.RANSOM_CLIENT):
		return Story.RANSOM_CLIENT
	var named := int(owner.flags.get("bec_client", -1))
	if cls == "client" and Sales.active.has(named):
		return named
	var pick := Difficulty.rng("skeleton").randi() % Sales.active.size()  # always drawn: the stream stays in step
	return int(Sales.active[pick])


# what each class does besides the cash: the saving ends, a vendor goes cold, a client is hurt or leaves, forum friends go quiet
static func _extras(owner: Node, id: String, b: Dictionary, victim: int) -> void:
	var cls := str(b.get("class", ""))
	owner.weekly_extra += int(b.get("weekly", 0))  # the shortcut saving (or extra income) ends
	if cls == "vendor":
		owner.weekly_extra += VENDOR_COLD
		owner.flags["vendor_cold"] = Campaign.day
	if victim >= 0 and int(b.get("mood", 0)) > 0:
		Sales.adjust(victim, -int(b.mood))
	if id == "temp_launder" and victim >= 0 and not Difficulty.cozy_on():
		owner.drop_client(victim, "")
	if cls == "reputation":
		_lose_friends()


# the two best forum regulars lose FRIEND_LOSS of friendship (a thread traced the fake reviews)
static func _lose_friends() -> void:
	var nicks: Array = Nerds.friend.keys()
	nicks.sort_custom(func(x: Variant, y: Variant) -> bool: return int(Nerds.friend[x]) > int(Nerds.friend[y]))
	for i in mini(2, nicks.size()):
		Nerds.friend[nicks[i]] = maxi(0, int(Nerds.friend[nicks[i]]) - FRIEND_LOSS)


# a copy of the bill card with {vname} {bill} {vleave} filled and {v} (the client index) in fx; options that need a client are
# dropped when there is none
static func _dress_bill(owner: Node, card: Dictionary, victim: int, cost: int, id: String) -> Dictionary:
	var out: Dictionary = card.duplicate(true)
	var name := "your client"
	if victim >= 0 and victim < Msp.CLIENTS.size():
		name = str(Msp.CLIENTS[victim].name)
	var leave := "They are leaving us."
	if Difficulty.cozy_on() or id != "temp_launder":
		leave = "They are very upset."
	var names := {
		"{vname}": name,
		"{bill}": owner.money(cost),
		"{vleave}": leave,
		"{v}": str(victim)
	}
	var options: Array = out.options
	for i in range(options.size() - 1, -1, -1):
		if victim < 0 and str(options[i]).contains("{v}"):
			options.remove_at(i)
	out = _fill(out, names)
	out["beat"] = true
	return out


static func _fill(v: Variant, names: Dictionary) -> Variant:
	if v is String:
		var text: String = v
		for k in names:
			text = text.replace(str(k), str(names[k]))
		return text
	if v is Array:
		for i in v.size():
			v[i] = _fill(v[i], names)
		return v
	if v is Dictionary:
		var out := {}
		for k in v:
			out[_fill(k, names) if k is String else k] = _fill(v[k], names)
		return out
	return v


# the dateless insurer bill: a ransom or wire fraud claim reads the renewal answers (Owner.apply calls this when a claim is made)
static func claim(owner: Node) -> void:
	var i := find("temp_quest")
	if i < 0:
		return
	var sk: Dictionary = owner.skel[i]
	owner.skel.remove_at(i)
	bill(owner, sk)


# the COME CLEAN card (RivalCards temp_come_clean) with the costs and the skeleton ids filled in. Rival.show calls this.
static func dress(card: Dictionary) -> Dictionary:
	var oldest := ""
	var biggest := ""
	var top := -1
	for sk in Owner.skel:
		var id := str(sk.get("id", ""))
		if oldest == "":
			oldest = id
		if int(sk.get("size", 0)) > top:
			top = int(sk.get("size", 0))
			biggest = id
	var names := {
		"{n}": str(folder_count()),
		"{costa}": Owner.money(clean_cost(oldest)),
		"{costb}": Owner.money(clean_cost(biggest))
	}
	card = _fill(card, names)
	var options: Array = card.options
	if oldest == "":
		options.remove_at(1)
		options.remove_at(0)
		return card
	options[0]["fx"] = {"come_clean": oldest}
	options[0]["need"] = clean_cost(oldest)
	options[1]["fx"] = {"come_clean": biggest}
	options[1]["need"] = clean_cost(biggest)
	if biggest == oldest:
		options.remove_at(1)
	return card


# called from Owner.settle() (after Rival.arc_week and Habits.week): fire the bills that are due, and from the second open
# skeleton on queue the COME CLEAN card for the next morning (at most once in CLEAN_EVERY weeks)
static func week(owner: Node) -> void:
	for sk in owner.skel.duplicate():
		if int(sk.get("due", NO_DATE)) <= Campaign.day:
			owner.skel.erase(sk)
			bill(owner, sk)
	vendor_rebate(owner)
	if (
		folder_count() >= 2
		and Campaign.day - int(owner.flags.get("clean_offer", -99)) >= CLEAN_EVERY
		and not owner.card_data(CLEAN_CARD).is_empty()
	):
		owner.flags["clean_offer"] = Campaign.day
		var q: Array = owner.flags.get("arc_queue", [])
		if not q.has(CLEAN_CARD):
			q.append(CLEAN_CARD)
		owner.flags["arc_queue"] = q


# a clean record (conscience not below zero, nothing in the folder, the vendor never caught you) earns one partner rebate from week
# REBATE_FROM on. The honest side of the vendor audit that temp_seats would have caused.
static func vendor_rebate(owner: Node) -> bool:
	if Campaign.day < REBATE_FROM or owner.flags.has("vendor_rebate") or owner.flags.has("vendor_cold"):
		return false
	if consc() < 0 or folder_count() > 0:
		return false
	owner.flags["vendor_rebate"] = Campaign.day
	owner.cash += REBATE
	Hints.toast("WEBWOOT PARTNER REBATE: %s. Clean seat counts, clean books." % owner.money(REBATE), 5.0)
	return true


# due diligence from week 16 on (the board review): -0.5 of the multiple per open skeleton, at most MAX_DEDUCTION
static func diligence() -> float:
	if Campaign.day < DILIGENCE_FROM:
		return 0.0
	return minf(MAX_DEDUCTION, PER_SKELETON * float(folder_count()))


# the lines for the review: FOUND IN DILIGENCE: n
static func diligence_line() -> String:
	return "FOUND IN DILIGENCE: %d" % folder_count()


# Marge's folder as a line for the weekly report (a count, never the conscience number)
static func folder_text() -> String:
	return "%d IN THE FOLDER, %s" % [folder_count(), band()]
