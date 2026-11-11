extends RefCounted
# gdlint:disable=max-line-length,class-variable-name,class-definitions-order
# X13: the owner campaign's fine print, found by the bot runs. A static helper (no state of its own: everything is in Owner.flags,
# which is saved with the campaign).
#   prices    what a card option can take out of the bank (cost) and the label as the card shows it (label): a cost the words do
#             not name is added, so no option takes money without saying how much. Owner.show_card reads both.
#   bills     a sum the bank cannot carry today becomes a dated bill: equal parts at the next BILL_WEEKS closes, a row on the
#             weekly report, counted against the company value. The scammed client's credit is paid that way by a thin bank.
#   leads     the inbound lead card: one story per card (LEADS, patchable from story/strings.txt as OwnerOps.LEADS), each at most
#             once in a run; when the stories run out John takes the meeting and texts the result.
#   the desk  the service desk's week as a row of the owner's report, and Morgan's card after two weeks over capacity.

const BILL_WEEKS := 8  # a dated bill is paid in this many weekly parts
const DESK_WARNINGS := 2  # Morgan says at most this often in a run that the desk is over capacity
const DESK_GAP := 4  # weeks between two of those cards
const GOOD := Color("8fe3a0")
const WARN := Color("ffd27a")
const BAD := Color("ff8a80")
# `text` takes the prospect's name; fee = the size of the contract (x the standard fee), mood = how they start, odds = added to
# both closing chances, catch = what signing them brings along (lead_catch). The first one is the plain lead and comes first.
const DEFAULT_LEADS := [
	{"id": "online", "text": "An inbound lead from our marketing: %s found us online and wants a meeting."},
	{
		"id": "referral",
		"text": "A referral. One of our clients told %s that we pick up the phone. They asked for you by name.",
		"mood": 6,
		"odds": 0.1,
		"won": "They had mostly decided before you sat down. %s signs and starts happy."
	},
	{
		"id": "burned",
		"text": "%s just fired their IT guy. His last invoice was for a server nobody can find. They want a meeting and they trust nobody.",
		"fee": 1.05,
		"mood": -8,
		"odds": -0.1,
		"won": "You listen for an hour and promise very little. %s signs, arms still folded."
	},
	{
		"id": "bargain",
		"text": "%s has our flyer in one hand and a ByteBrothers quote in the other. They will meet, and they want the first month cheap.",
		"odds": 0.1,
		"catch": "discount",
		"won": "The cheap first month does it. %s signs and asks what else is negotiable."
	},
	{
		"id": "growing",
		"text": "%s is opening a second office and the owner's nephew cannot keep up. Bigger than our usual: more seats, more questions.",
		"fee": 1.2,
		"odds": -0.05,
		"catch": "big",
		"won": "Two offices, one contract. %s signs and the crew starts counting desks."
	},
	{
		"id": "tiny",
		"text": "%s is five people and one printer. They found us on the chamber of commerce list. Small money, easy work.",
		"fee": 0.85,
		"mood": 4,
		"odds": 0.1,
		"won": "It takes twenty minutes. %s signs and offers you a muffin."
	},
	{
		"id": "paperwork",
		"text": "%s failed an insurance questionnaire and needs somebody who can spell backup. They will pay for it and read every line.",
		"fee": 1.15,
		"mood": -3,
		"won": "You answer the questionnaire line by line. %s signs at a better rate and keeps a copy."
	},
	{
		"id": "rush",
		"text": "%s lost their server on Tuesday. They want a provider yesterday. Whoever shows up first gets the contract, and the mess.",
		"fee": 1.1,
		"odds": 0.15,
		"catch": "rush",
		"won": "You show up first. %s signs on the hood of your car and the crew gets the mess."
	},
	{
		"id": "slowpay",
		"text": "%s wants a meeting. Christy looked them up: a good business that pays everybody on the sixtieth day.",
		"fee": 1.05,
		"odds": 0.05,
		"catch": "slow",
		"won": "A good meeting. %s signs. Christy sets a reminder for day sixty."
	},
	{
		"id": "seminar",
		"text": "%s sat through my lunch seminar and stayed for the questions. They want a proposal, not a pitch.",
		"mood": 3,
		"odds": 0.05,
		"won": "You bring the proposal yourself. %s signs at a better rate and starts happy."
	},
]
static var LEADS: Array = DEFAULT_LEADS.duplicate(true)


# ---- prices ---------------------------------------------------------------------------------------------------------
# what picking this option can take out of the bank at once: [the least, the most] in dollars. A rolled option has a figure
# per outcome; a sum that is only known when the card opens (the scammed client's credit) comes from Incident.
static func cost(opt: Dictionary) -> Array:
	var lo := 0
	var hi := 0
	if opt.has("roll"):
		var first := true
		for table in [opt.roll, opt.get("roll_scoped", [])]:
			for entry in table:
				var c := _fx_cost(entry[1])
				lo = c if first else mini(lo, c)
				hi = maxi(hi, c)
				first = false
	else:
		lo = _fx_cost(opt.get("fx", {}))
		hi = lo
	var extra: Array = Owner.Incident.option_cost(str((opt.get("fx", {}) as Dictionary).get("bec", "")))
	return [lo + int(extra[0]), hi + int(extra[1])]


static func _fx_cost(fx: Dictionary) -> int:
	var c := maxi(0, -int(fx.get("cash", 0)))
	if fx.has("quote"):
		c += maxi(0, int(fx.quote.cost) - int(fx.quote.cash))
	if fx.has("stack"):
		for category in fx.stack:
			c += Mutators.stack_fee(str(category), str(fx.stack[category]))
	return c


# what the bank must hold for the option to be open: its own `need`, or its price when that is only known now (`pay`)
static func need(opt: Dictionary, price: Array) -> int:
	return maxi(int(opt.get("need", 0)), int(price[0]) if opt.get("pay", false) else 0)


# the label as the card shows it: {pay} and {risk} are the two figures of cost(); a cost the words do not name is added
# (a sure one as "($600)", the worst case of a gamble as "(RISK $3,500)"). `later`: the label of the dated-bill variant.
static func label(opt: Dictionary, price: Array, later := false) -> String:
	var text := str(opt.get("label_later", opt.label)) if later else str(opt.label)
	var lo := int(price[0])
	var hi := int(price[1])
	var named: bool = text.contains("{pay}") or text.contains("{risk}")
	text = text.replace("{pay}", Owner.money(lo)).replace("{risk}", Owner.money(hi))
	if named:
		return text
	if hi > lo and not text.contains("RISK"):
		text += " (RISK %s)" % Owner.money(hi)
	elif lo > 0 and not text.contains("$"):
		text += " (%s)" % Owner.money(lo)
	return text


# ---- dated bills ----------------------------------------------------------------------------------------------------
static func bills() -> Array:
	return Owner.flags.get("bills", [])


static func bills_left() -> int:
	var total := 0
	for b in bills():
		total += int(b.left)
	return total


# `amount` in equal parts at the next `weeks` closes (cash out of the bank, never part of EBITDA)
static func add_bill(what: String, amount: int, weeks := BILL_WEEKS) -> void:
	if amount <= 0:
		return
	var list: Array = bills()
	var part := int(ceil(float(amount) / float(maxi(1, weeks))))
	list.append({"label": what, "part": part, "left": amount})
	Owner.flags["bills"] = list
	var note := "%s: %s A WEEK FOR %d WEEKS." % [what, Owner.money(part), weeks]
	Msp.send_text("Christy", note)
	Hints.toast(note, 4.0)


# pay it now when the bank can, else put it on a dated bill; true when it was billed
static func pay_or_bill(what: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if Owner.cash >= amount:
		Owner.cash -= amount
		return false
	add_bill(what, amount)
	return true


# the week's parts of every dated bill (Owner.settle): returns what left the bank
static func pay_bills() -> int:
	var paid := 0
	var open := []
	for b in bills():
		var part := mini(int(b.part), int(b.left))
		paid += part
		b.left = int(b.left) - part
		if int(b.left) > 0:
			open.append(b)
	if Owner.flags.has("bills"):
		Owner.flags["bills"] = open
	Owner.cash -= paid
	return paid


# an fx option marked `later` whose price the bank cannot carry: the cash part becomes a dated bill, the rest applies as it is
static func later_fx(opt: Dictionary) -> Dictionary:
	var fx: Dictionary = opt.get("fx", {})
	var due := maxi(0, -int(fx.get("cash", 0)))
	if not opt.get("later", false) or due <= 0 or Owner.cash >= due:
		return fx
	var out := fx.duplicate()
	out.erase("cash")
	add_bill(str(opt.get("bill", "SETTLEMENT")), due)
	return out


static func bills_row(paid: int) -> Array:
	return ["DATED BILLS", "-$%d THIS WEEK, $%d LEFT" % [paid, bills_left()], WARN]


# ---- inbound leads --------------------------------------------------------------------------------------------------
# the next lead story of this run: the plain one first, then the others in the run's own order, each once ({} when all are told)
static func next_story() -> Dictionary:
	var seen: Array = Owner.flags.get("leads_seen", [])
	var open := []
	for i in LEADS.size():
		if not seen.has(str(LEADS[i].id)):
			open.append(i)
	if open.is_empty():
		return {}
	var k: int = open[0] if seen.is_empty() else open[Difficulty.rng("owner.lead").randi() % open.size()]
	seen.append(str(LEADS[k].id))
	Owner.flags["leads_seen"] = seen
	return LEADS[k]


# what a lead's catch does once they sign: a cheap first month, a rushed start, a slow payer, a big onboarding
static func lead_catch(kind: String, lead: int) -> Dictionary:
	match kind:
		"discount":
			return {"discount_new": {"mult": 0.8, "weeks": 4}}
		"rush":
			return {"burnout": 5}
		"slow":
			return {"squeeze": [lead]}
		"big":
			return {"burnout": 3}
	return {}


# the card of one inbound lead (Owner._inbound_lead picked the prospect): {} when every story has been told, and then John
# has already taken the meeting himself
static func lead_card(lead: int, vic_odds: float) -> Dictionary:
	var prospect: String = Msp.CLIENTS[lead].name
	var story := next_story()
	if story.is_empty():
		_by_john(lead, vic_odds)
		return {}
	var fee := float(story.get("fee", 1.0))
	var mood := int(story.get("mood", 0))
	var own := clampf(0.6 + float(story.get("odds", 0.0)), 0.2, 0.95)
	var john := clampf(vic_odds + float(story.get("odds", 0.0)), 0.2, 0.95)
	var own_fx := {"sign": true, "client": lead, "sign_bonus": {"mood": 15 + mood, "fee": snappedf(1.1 * fee, 0.01)}}
	var john_fx := {"sign": true, "client": lead}
	if fee != 1.0 or mood != 0:
		john_fx["sign_bonus"] = {"mood": mood, "fee": fee}
	var catch_fx := lead_catch(str(story.get("catch", "")), lead)
	own_fx.merge(catch_fx)
	john_fx.merge(catch_fx)
	var won := str(story.get("won", "You charm them. %s signs at a better rate and starts happy.")) % prospect
	var card := {
		"speaker": "John Marlowe",
		"text": str(story.text) % prospect,
		"options":
		[
			{
				"label": "TAKE THE MEETING YOURSELF (%d%%: HAPPIER, +10%% FEE)" % int(round(own * 100.0)),
				"roll": [[own, own_fx, won], [1.0 - own, {}, "They say they will think about it."]]
			},
			{
				"label": "LET JOHN CLOSE IT (%d%%)" % int(round(john * 100.0)),
				"roll": [[john, john_fx, "John closes it. %s signs." % prospect], [1.0 - john, {}, "John fumbles it. They go quiet."]]
			},
		],
	}
	if Onsite.has_site(lead):
		card.options.append({"label": "PITCH THEM AT THEIR OFFICE (%d MIN)" % Onsite.estimate_minutes(lead), "fx": {"onsite_visit": {"client": lead, "kind": "pitch"}}})
	return card


# every story has been told: John takes the meeting and texts the result (no card)
static func _by_john(lead: int, odds: float) -> void:
	var prospect: String = Msp.CLIENTS[lead].name
	var note := "%s called about a meeting. I took it. They went quiet." % prospect
	if Difficulty.rng("owner").randf() < odds:
		Owner.apply({"sign": true, "client": lead})
		note = "%s called about a meeting. I took it. They signed." % prospect
	Msp.send_text("John", note)
	Hints.toast(note.to_upper(), 4.0)


# ---- the desk's capacity, said out loud -----------------------------------------------------------------------------
# The week's reputation change is the desk's (2 a close, -3 a missed clock, -1 a ticket left open) and the owner's report
# only showed money: a company with healthy books could lose its name without one line saying why. The report gets a
# SERVICE DESK row (DESK OVER CAPACITY when the loose ends outweigh the closes), and after two such weeks in a row Morgan
# says it in the morning with the numbers (at most DESK_WARNINGS times a run, DESK_GAP weeks apart).
static func desk_over(closed: int, missed: int, reopened: int, open_left: int) -> bool:
	return missed * 3 + reopened * 2 + open_left > closed * 2


# Campaign._end_day, owner campaign: adds the row to the report (above the owner's hours) and counts the weeks over
static func desk_week(r: Dictionary) -> void:
	var closed := int(r.get("closed", 0))
	var missed := int(r.get("missed", 0))
	var open_left := int(r.get("open_left", 0))
	var over := desk_over(closed, missed, int(r.get("reopened", 0)), open_left)
	Owner.flags["desk_over"] = int(Owner.flags.get("desk_over", 0)) + 1 if over else 0
	Owner.flags["desk_last"] = [closed, missed, open_left]
	var row := [
		"DESK OVER CAPACITY" if over else "SERVICE DESK",
		"%d CLOSED, %d MISSED, %d OPEN" % [closed, missed, open_left],
		BAD if over else (WARN if missed > 0 else GOOD)
	]
	var rows: Array = r.get("rows", [])
	var at := rows.size()
	for i in rows.size():
		if str(rows[i][0]) == "OWNER HOURS":
			at = i
	rows.insert(at, row)


# Owner.begin_day: Morgan's card ({} when there is nothing to say)
static func desk_card() -> Dictionary:
	var flags: Dictionary = Owner.flags
	if Campaign.mode != "owner" or int(flags.get("desk_over", 0)) < 2:
		return {}
	var told := int(flags.get("desk_warned", 0))
	if told >= DESK_WARNINGS or Campaign.day - int(flags.get("desk_warn_week", -99)) < DESK_GAP:
		return {}
	flags["desk_warned"] = told + 1
	flags["desk_warn_week"] = Campaign.day
	var last: Array = flags.get("desk_last", [0, 0, 0])
	var numbers := [int(last[0]), int(last[1]), int(last[2]), Sales.active.size(), Owner.crew_size() + Owner.extra_staff.size()]
	var text := (
		"{me}, the books look fine and the desk does not. Last week we closed %d tickets, missed %d and left %d open: %d clients on %d techs. That is the reputation line on your report, and it is why it is falling. More hands, faster hands or less work."
		% numbers
	)
	if told > 0:
		text = (
			"Still under water. %d closed, %d missed, %d open last week, with %d clients on %d techs. Every week like this costs us the name, whatever the bank says. What changes?"
			% numbers
		)
	var options := [{"label": "SEE HIRING CANDIDATES", "fx": {"candidates": true}}]
	if Owner.training_open():
		options.append({"label": "TRAIN THE CREW ($400)", "need": 400, "fx": {"cash": -400, "train": true}})
	options.append(
		{
			"label": "STOP TAKING NEW CLIENTS FOR NOW (MARKETING OFF)",
			"fx": {"marketing": 0},
			"text": "The ads stop. John looks at his phone a lot. The desk gets a few weeks to catch up."
		}
	)
	options.append({"label": "THEY WILL COPE", "fx": {}})
	return {"speaker": "{ops}", "text": text, "options": options}
