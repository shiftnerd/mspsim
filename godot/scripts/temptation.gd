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
		"size": 1900,
		"rep": 0,
		"mood": 0,
		"text": "The vendor audited the seat count. Back bill plus a 25 percent penalty."
	},
	"temp_reboot":
	{
		"class": "client",
		"lo": 4,
		"hi": 6,
		"size": 255,
		"rep": 1,
		"mood": 10,
		"text": "A bookkeeper audited one invoice. Refund, and the client is not happy."
	},
	"temp_quest":
	{
		"class": "insurer",
		"lo": NO_DATE,
		"hi": NO_DATE,
		"size": 4000,
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
		"rep": 6,
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
		"size": 2400,
		"rep": 3,
		"mood": 0,
		"text": "The breach hit and your recommendation was never on paper."
	},
	"temp_restore":
	{
		"class": "backup",
		"lo": 2,
		"hi": 7,
		"size": 1200,
		"rep": 2,
		"mood": 0,
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
	Owner.skel.remove_at(i)
	Career.add("skeletons_paid")  # R38 P6
	change_consc(1, true)
	return true


# the bill arrives: cash, reputation, client mood, a card or a toast. TODO(temptation agent): per-class extras (vendor mood, client leaves,
# forum friends lost, insurer branch of bec_loss) and the card bill_<id> from RivalCards when it exists.
static func bill(owner: Node, sk: Dictionary) -> void:
	Career.add("skeletons_paid")  # R38 P6
	var b: Dictionary = BILLS.get(str(sk.get("id", "")), {})
	var cost := bill_size(sk)
	if cost > 0:
		owner.cash -= cost
	if int(b.get("rep", 0)) > 0:
		Campaign.adjust_rep(-int(b.rep))
	if int(b.get("mood", 0)) > 0:
		for c in Sales.active:
			Sales.adjust(int(c), -int(b.mood) / 4)  # TODO(temptation agent): the one client it hit, not everybody
	var card := "bill_" + str(sk.get("id", ""))
	if not owner.card_data(card).is_empty():
		owner.show_card(card)
	else:
		Hints.toast(
			"A BILL FROM THE FOLDER: " + str(b.get("text", "A SHORTCUT CAUGHT UP WITH YOU.")), 5.0
		)


# called from Owner.settle() (after Rival.arc_week and Habits.week): fire the bills that are due
static func week(owner: Node) -> void:
	for sk in owner.skel.duplicate():
		if int(sk.get("due", NO_DATE)) <= Campaign.day:
			owner.skel.erase(sk)
			bill(owner, sk)
	# TODO(temptation agent): offer the COME CLEAN card (temp_come_clean) from the second open skeleton on, once per 4 weeks


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
