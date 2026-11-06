extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# R38 P5: the rival and good-habit hooks of John's sales campaign (docs/scope-bad-habits.md sections 2.5 and 6). A static helper (no state
# of its own): the state lives on the lead dictionaries (incumbent, inc_seen, findings, assessed, rumour, lie ...), on the book entries
# (honest, lie, takeover, scorecard) and in SalesCampaign.flags, so it saves with the campaign. Conscience is Owner.consc through
# Temptation (words only, never a number). The text of the beats is SalesCampaign.BEAT_TEXT (patchable in story/strings.txt).
#   incumbent: none / bytebrothers / bigcheese / plumbline / inhouse, drawn for every lead from Difficulty.rng("leads"); the discovery
#     call shows it 85% of the time, a visit always (hidden in the CRM until then).
#   ASSESS (CRM, one selling hour, needs the MEETING stage): 3 to 5 findings from Rival.assessment(incumbent); the honest list becomes
#     promises of the quote and the handover, the cheap one ("it looks fine") wins a little now and breaks later.
#   PRESENTED AS (quote builder): ITEMIZED / FLAT / THREE TIERS with a one page value page, and the RIVAL PRICE gauge.
#   lie flag on a deal won by a shortcut: 90 day churn +8, a LIES line in the week 20 verdict, SALES DIRECTOR needs a clean enough book.

const Habits := preload("res://scripts/habits.gd")
const Rival := preload("res://scripts/rival.gd")
const Temptation := preload("res://scripts/temptation.gd")

const INCUMBENTS := ["none", "bytebrothers", "bigcheese", "plumbline", "inhouse"]
const CUM := [0.30, 0.55, 0.75, 0.85, 1.0]  # the cumulative odds of each incumbent above
const NAMES := {
	"none": "NONE",
	"bytebrothers": "BYTEBROTHERS",
	"bigcheese": "BIG CHEESE",
	"plumbline": "PLUMB LINE",
	"inhouse": "IN-HOUSE"
}
const FLAT_RIVALS := ["bigcheese", "bytebrothers"]
const SEEN_ON_CALL := 0.85
const PRESENT := ["itemized", "flat", "tiers"]
const PRESENT_SHORT := {"itemized": "ITEMIZED", "flat": "FLAT", "tiers": "3 TIERS"}
const WIN_ITEMIZED := -0.04  # thirty-one lines are thirty-one doors to cut (against a flat price, without the scorecard)
const WIN_FLAT := 0.03
const MARGIN_FLAT := 0.08
const GAP_FLAT := 0.5  # nothing in writing on what is left out
const WIN_TIERS := 0.02
const WIN_GUESS := -0.02  # a three tier page made up without the habit behind it
const WIN_HONEST := -0.03
const WIN_CHEAP := 0.03
const GAP_CHEAP := 0.5
const FINDING_GAP := 0.2
const HONEST_MOOD := 6
const HONEST_CHURN := -8
const LIE_CHURN := 8
const RUMOUR_WEEKS := 4
const SCORECARD := 0.06
const TAKEOVER_LOAD := 0.2  # a won Big Cheese client costs Dan and Morgan this much capacity for six weeks
const TAKEOVER_WEEKS := 6
const WEEKS := {
	2: "incumbent",
	3: "rex",
	5: "flat",
	7: "assess",
	9: "laundered",
	11: "plumb",
	13: "rumour",
	15: "audit",
	17: "scorecard"
}
const COUNTER_AFTER := 2  # weeks until Rex answers a badmouthing


# ---- the incumbent -------------------------------------------------------------------------------------
# one draw per lead (always drawn, so seeds repeat)
static func incumbent_for(roll: float) -> String:
	for i in INCUMBENTS.size():
		if roll < float(CUM[i]):
			return str(INCUMBENTS[i])
	return "none"


static func incumbent(l: Dictionary) -> String:
	return str(l.get("incumbent", "none"))


static func is_seen(l: Dictionary) -> bool:
	return bool(l.get("inc_seen", false))


static func name_of(key: String) -> String:
	return str(NAMES.get(key, key.to_upper()))


static func flat_rival(l: Dictionary) -> bool:
	return FLAT_RIVALS.has(incumbent(l))


# the discovery call ("who is your IT person now?"): 85% of the time they tell you
static func on_call(l: Dictionary) -> bool:
	var r: RandomNumberGenerator = Difficulty.rng_for("incumbent", int(l.id) * 100 + Campaign.day)
	if r.randf() < SEEN_ON_CALL:
		return reveal(l)
	return false


# a visit always shows it
static func on_visit(l: Dictionary) -> bool:
	return reveal(l)


static func reveal(l: Dictionary) -> bool:
	if is_seen(l):
		return false
	l["inc_seen"] = true
	if incumbent(l) != "none":
		SalesCampaign.Deals.note(l, "INCUMBENT: " + name_of(incumbent(l)))
	return true


# the CRM line: hidden until the first call
static func rival_line(l: Dictionary) -> String:
	if not is_seen(l):
		return "RIVAL: UNKNOWN. CALL THEM FIRST"
	if incumbent(l) == "none":
		return "RIVAL: NOBODY (FIRST MSP)"
	return "RIVAL: " + name_of(incumbent(l))


# the RIVAL PRICE gauge: what the incumbent charges for this lead a week
static func rival_price(l: Dictionary) -> Dictionary:
	var fee := float(l.get("fee", 600))
	var key := incumbent(l)
	var out := {"key": key, "known": is_seen(l), "name": name_of(key), "week": 0, "note": ""}
	match key:
		"bigcheese":
			out["week"] = int(round(fee * 0.85))
			out["note"] = "$39 A SEAT FLAT"
		"bytebrothers":
			out["week"] = int(round(fee * 0.80))
			out["note"] = "20% UNDER LIST"
		"plumbline":
			out["week"] = int(round(fee * 1.15))
			out["note"] = "31 LINES"
		"inhouse":
			out["note"] = "THEIR NEPHEW"
	return out


# ---- PRESENTED AS and the effects on the quote ----------------------------------------------------------
static func present_of(n: Dictionary) -> String:
	var p := str(n.get("present", "itemized"))
	return p if PRESENT.has(p) else "itemized"


static func win_delta(l: Dictionary, n: Dictionary) -> float:
	var d := 0.0
	match present_of(n):
		"flat":
			d += WIN_FLAT
		"tiers":
			d += WIN_TIERS if Habits.fresh("H2") else WIN_GUESS
		_:
			if flat_rival(l) and not Habits.fresh("H2"):
				d += WIN_ITEMIZED
	match str(l.get("assessed", "")):
		"honest":
			d += WIN_HONEST
		"cheap":
			d += WIN_CHEAP
	return d + float(l.get("pts", 0.0)) + rumour_delta(l)


static func margin_delta(n: Dictionary) -> float:
	return MARGIN_FLAT if present_of(n) == "flat" else 0.0


# promise points the pricing form and the assessment add to the quote's gap
static func gap_delta(l: Dictionary, n: Dictionary) -> float:
	var d := GAP_FLAT if present_of(n) == "flat" else 0.0
	if str(l.get("assessed", "")) == "cheap":
		d += GAP_CHEAP
	return d + FINDING_GAP * float(findings(l).size())


# extra promise entries for Deals.promise_list: the form, the cheap assessment and one per honest finding
static func promise_items(l: Dictionary, n: Dictionary) -> Array:
	var items := []
	if present_of(n) == "flat":
		items.append(
			{
				"id": "flat",
				"kind": "PRICING",
				"label": "FLAT PRICE: NOTHING IN WRITING ON WHAT IS OUT",
				"raw": GAP_FLAT
			}
		)
	if str(l.get("assessed", "")) == "cheap":
		items.append(
			{
				"id": "cheap",
				"kind": "ASSESSMENT",
				"label": "WE SAID IT LOOKED FINE",
				"raw": GAP_CHEAP
			}
		)
	for h in findings(l):
		items.append(
			{
				"id": "f_" + str(h),
				"kind": "FIX",
				"label": "FIX: " + str(Rival.HABITS.get(str(h), {}).get("name", str(h))),
				"raw": FINDING_GAP
			}
		)
	return items


# true when the builder block lines apply (the form against a flat rival)
static func form_blocks(l: Dictionary, n: Dictionary) -> Array:
	var out := []
	match present_of(n):
		"itemized":
			if flat_rival(l) and not Habits.fresh("H2"):
				out.append(
					{
						"who": "JOHN",
						"text": "THIRTY-ONE LINES ARE THIRTY-ONE DOORS TO CUT. TRY THREE TIERS.",
						"hard": false
					}
				)
		"flat":
			out.append(
				{
					"who": "ALAN",
					"text": "FLAT TAKES 8 POINTS OFF THE MARGIN AND LEAVES WHAT IS OUT UNWRITTEN.",
					"hard": false
				}
			)
		"tiers":
			if not Habits.fresh("H2"):
				out.append(
					{
						"who": "JOHN",
						"text": "NO SCORECARD BEHIND THE PAGE YET. IT IS GUESSWORK.",
						"hard": false
					}
				)
	return out


# ---- ASSESS ----------------------------------------------------------------------------------------------
static func findings(l: Dictionary) -> Array:
	return l.get("findings", [])


static func finding_names(ids: Array) -> String:
	var out := []
	for h in ids:
		out.append(str(Rival.HABITS.get(str(h), {}).get("name", str(h))))
	return ", ".join(out)


static func can_assess(l: Dictionary) -> String:
	if l.is_empty() or str(l.stage) != "MEETING":
		return "NEEDS A MEETING. CALL THEM FIRST."
	if str(l.get("assessed", "")) != "":
		return "ALREADY ASSESSED."
	if SalesCampaign.slots_left() < 1:
		return "NO SELLING HOURS LEFT."
	return ""


# the CRM button: one selling hour, 3 to 5 findings, then the choice between the honest list and the cheap answer
static func assess(id: int) -> String:
	var l: Dictionary = SalesCampaign.lead_by_id(id)
	var why := can_assess(l)
	if why != "":
		return why
	if not SalesCampaign.spend(1):
		return "NO SELLING HOURS LEFT."
	reveal(l)
	var n := int(SalesCampaign.flags.get("assess_n", 0))
	SalesCampaign.flags["assess_n"] = n + 1
	var ids: Array = Rival.assessment(incumbent(l))
	if str(l.get("story", "")) == "assess_bc":  # week 7: the clean, honest list the doc names
		var first := ["R02", "R04", "R12"]
		for h in ids:
			if not first.has(h) and first.size() < 5:
				first.append(h)
		ids = first
	l["findings"] = ids
	l["assessed"] = "open"
	SalesCampaign.Deals.touch(l, "ASSESSED: %d FINDINGS" % ids.size())
	var text := (
		"I walked %s's office and checked their closet. %d findings: %s. Do I write up the honest list, or tell them it looks fine?"
		% [str(l.name), ids.size(), finding_names(ids)]
	)
	Cards.ask(
		"John (your notes)",
		text,
		[
			{"label": "WRITE UP THE HONEST LIST", "id": "honest"},
			{"label": "TELL THEM IT LOOKS FINE", "id": "cheap"},
		],
		func(pick: String) -> void: assess_pick(l, pick)
	)
	SalesCampaign.changed.emit()
	return "ASSESSING %s" % str(l.name).to_upper()


static func assess_pick(l: Dictionary, pick: String) -> void:
	if pick == "cheap":
		l["assessed"] = "cheap"
		l["hidden"] = findings(l)
		l["findings"] = []
		mark_lie(l, "TOLD THEM IT LOOKS FINE", "cheap")
	else:
		l["assessed"] = "honest"
		Habits.apply_touch("H10")
		Temptation.change_consc(1)
		SalesCampaign.Deals.note(l, "HONEST LIST: %d FIXES" % findings(l).size())
	SalesCampaign.changed.emit()


# ---- lies and conscience ----------------------------------------------------------------------------------
# a shortcut: the lead is flagged, the conscience falls (words only for the player)
static func mark_lie(l: Dictionary, why: String, kind := "") -> void:
	l["lie"] = true
	SalesCampaign.Deals.note(l, why)
	Temptation.change_consc(-2)
	if BILLS.has(kind):
		seed_bill(l, kind)


# ---- dated bills (the sales twins of the owner temptations) -----------------------------------------------------------
# A lie also goes in Christy's folder (Owner.skel, class "sales", with the lead's name). When its week comes and the deal is on the book the
# bill lands: mood and churn on the client, reputation, or the client leaves (a laundered lead). A deal that is still open waits; one that
# never closed drops out (BILL_PATIENCE weeks). COME CLEAN costs a share of the commission and clears the lie flag. Cozy halves the hurt and
# the laundered client stays.
const BILLS := {
	"cheap": {"lo": 4, "hi": 6, "mood": 10, "churn": 10, "rep": 1, "claw": 2.5, "leave": false, "text": "THE FIXES YOU TOLD THEM WERE NOT NEEDED TURNED INTO OUTAGES."},
	"flat": {"lo": 3, "hi": 5, "mood": 8, "churn": 6, "rep": 1, "claw": 2.0, "leave": false, "text": "THEY ASKED FOR THE SETUP THEY ASSUMED WAS INCLUDED. NOTHING WAS IN WRITING."},
	"launder": {"lo": 5, "hi": 7, "mood": 0, "churn": 0, "rep": 3, "leave": true, "text": "THE CONTACT ASKED HOW YOU KNEW ABOUT THEIR MAILBOX."},
	"undercut": {"lo": 4, "hi": 6, "mood": 6, "churn": 8, "rep": 1, "claw": 2.0, "leave": false, "text": "THE UNDERCUT PRICE CAME WITH UNDERCUT SERVICE. THEY NOTICED."}
}
const BILL_PATIENCE := 8
const CLEAN_FLOOR := 50


static func seed_bill(l: Dictionary, kind: String) -> void:
	var b: Dictionary = BILLS[kind]
	var id := kind + ":" + str(l.name)
	if Temptation.find(id) >= 0:
		return
	var weeks := Difficulty.rng("skeleton").randi_range(int(b.lo), int(b.hi))
	var size := maxi(CLEAN_FLOOR * 2, int(round(float(l.get("fee", 100)) * float(SalesCampaign.PLAN_RATE.get(SalesCampaign.plan, 2.0)))))
	Owner.skel.append({"id": id, "due": Campaign.day + weeks, "class": "sales", "size": size, "lead": str(l.name), "kind": kind})


# the open sales entries of the folder
static func open_bills() -> Array:
	var out := []
	for sk in Owner.skel:
		if sk.has("lead"):
			out.append(sk)
	return out


static func _deal_named(lead: String) -> Dictionary:
	for d in SalesCampaign.book:
		if str(d.name) == lead:
			return d
	return {}


static func _lead_named(lead: String) -> Dictionary:
	for l in SalesCampaign.leads:
		if str(l.name) == lead:
			return l
	return {}


# the bills that are due this week
static func bills_week(day: int) -> void:
	for sk in open_bills():
		if int(sk.due) > day:
			continue
		var d := _deal_named(str(sk.lead))
		if d.is_empty():
			var l := _lead_named(str(sk.lead))
			if str(l.get("stage", "")) == "LOST" or day > int(sk.due) + BILL_PATIENCE:
				Owner.skel.erase(sk)
			continue
		Owner.skel.erase(sk)
		_bill(d, sk)


static func _bill(d: Dictionary, sk: Dictionary) -> void:
	var b: Dictionary = BILLS.get(str(sk.kind), {})
	var cozy := Difficulty.cozy_on()
	Career.add("skeletons_paid")
	if int(b.get("rep", 0)) > 0:
		Campaign.adjust_rep(-int(b.rep))
	var text := str(b.get("text", "A SHORTCUT CAUGHT UP WITH YOU."))
	if bool(b.get("leave", false)) and not cozy:
		SalesCampaign.Retention.leave(d, text)
		return
	var mood := int(b.get("mood", 0)) / (2 if cozy else 1)
	var churn := int(b.get("churn", 0)) / (2 if cozy else 1)
	SalesCampaign.Retention.adjust_mood(d, -mood)
	d["churn"] = clampi(int(d.get("churn", 10)) + churn, 0, 100)
	var claw := int(round(float(d.get("commission", 0)) * float(b.get("claw", 0.0)))) / (2 if cozy else 1)
	SalesCampaign.commission_total -= claw
	SalesCampaign.week_clawback += claw
	SalesCampaign.clawed_total += claw
	Cards.ask(
		"{sales_owner}",
		"A BILL FROM THE FOLDER, %s: %s THE COMMISSION COMES BACK WITH A PENALTY: -$%d." % [str(d.name).to_upper(), text, claw],
		[{"label": "UNDERSTOOD", "id": "ok"}],
		func(_id: String) -> void: pass
	)


# own up before the bill: the cost comes out of the commission, the lie flag is cleared, the conscience rises
static func come_clean_sales(id: String) -> bool:
	var i := Temptation.find(id)
	if i < 0:
		return false
	var sk: Dictionary = Owner.skel[i]
	SalesCampaign.commission_total -= Temptation.clean_cost(id)
	var l := _lead_named(str(sk.get("lead", "")))
	if not l.is_empty():
		l["lie"] = false
	var d := _deal_named(str(sk.get("lead", "")))
	if not d.is_empty() and bool(d.get("lie", false)):
		d["lie"] = false
		SalesCampaign.flags["lies"] = maxi(0, lies() - 1)
	Owner.skel.remove_at(i)
	Career.add("skeletons_paid")
	Temptation.change_consc(1, true)
	return true


# from the second open entry on, Garrison offers to phone the clients first (at most once in CLEAN_EVERY weeks)
static func clean_offer(day: int) -> void:
	var open := open_bills()
	if open.size() < 2 or day - int(SalesCampaign.flags.get("clean_offer", -99)) < Temptation.CLEAN_EVERY:
		return
	SalesCampaign.flags["clean_offer"] = day
	var oldest: Dictionary = open[0]
	var biggest: Dictionary = open[0]
	for sk in open:
		if int(sk.due) < int(oldest.due):
			oldest = sk
		if int(sk.size) > int(biggest.size):
			biggest = sk
	var options := []
	options.append({"label": "OWN UP TO %s ($%d)" % [str(oldest.lead).to_upper(), Temptation.clean_cost(str(oldest.id))], "id": "oldest"})
	if str(biggest.id) != str(oldest.id):
		options.append({"label": "OWN UP TO %s ($%d)" % [str(biggest.lead).to_upper(), Temptation.clean_cost(str(biggest.id))], "id": "biggest"})
	options.append({"label": "NOT YET", "id": "no"})
	Cards.ask(
		"{sales_owner}",
		"We have %d deals that could still come back on us. I can phone the clients and tell them the truth before they find it. It costs less out of your commission than the bill would." % open.size(),
		options,
		func(pick: String) -> void:
			if pick == "oldest":
				come_clean_sales(str(oldest.id))
			elif pick == "biggest":
				come_clean_sales(str(biggest.id))
	)


static func lies() -> int:
	return int(SalesCampaign.flags.get("lies", 0))


static func conscience_ok() -> bool:
	return Temptation.consc() > -3


static func lies_line() -> String:
	var n := lies()
	if n == 0 and conscience_ok():
		return "NO DEALS WON BY A SHORTCUT. CONSCIENCE: " + Temptation.band()
	var tail := "" if conscience_ok() else ". THE DIRECTOR JOB WANTS CLEAN BOOKS"
	return (
		"LIES: %d DEAL%s WON BY A SHORTCUT. CONSCIENCE: %s%s"
		% [n, "" if n == 1 else "S", Temptation.band(), tail]
	)


# the book entry of a deal that has just closed (SalesCampaign.close_deal): what the handover and the churn meter read
static func stamp(deal: Dictionary, l: Dictionary) -> void:
	deal["incumbent"] = incumbent(l)
	deal["honest"] = str(l.get("assessed", "")) == "honest"
	deal["lie"] = bool(l.get("lie", false))
	if bool(deal.lie):
		SalesCampaign.flags["lies"] = lies() + 1
	if incumbent(l) == "bigcheese":
		deal["takeover"] = true
		if findings(l).is_empty():  # nobody looked: the mess shows up at the handover
			var promises: Array = deal.get("promises", [])
			var ids: Array = Rival.assessment("bigcheese").slice(0, 2)
			for h in ids:
				promises.append(
					{
						"id": "f_" + str(h),
						"kind": "INHERITED",
						"label":
						"INHERITED: " + str(Rival.HABITS.get(str(h), {}).get("name", str(h))),
						"gap": 0.3,
						"state": "open"
					}
				)
			deal["promises"] = promises


static func mood_adjust(deal: Dictionary) -> int:
	return HONEST_MOOD if bool(deal.get("honest", false)) else 0


static func churn_adjust(deal: Dictionary) -> int:
	return (
		(HONEST_CHURN if bool(deal.get("honest", false)) else 0)
		+ (LIE_CHURN if bool(deal.get("lie", false)) else 0)
	)


# the handover meeting for a client who came from Big Cheese
static func takeover_line(deal: Dictionary) -> String:
	if not bool(deal.get("takeover", false)):
		return ""
	return " This one comes from Big Cheese. Whatever Rex left behind is ours now."


static func takeover_load() -> float:
	var n := 0
	for d in SalesCampaign.book:
		if bool(d.get("takeover", false)) and Campaign.day - int(d.week) <= TAKEOVER_WEEKS:
			n += 1
	return TAKEOVER_LOAD * float(n)


# ---- rumours (they expire after four weeks) ----------------------------------------------------------------
static func rumour_delta(l: Dictionary) -> float:
	var r: Dictionary = l.get("rumour", {})
	if r.is_empty() or Campaign.day - int(r.week) >= RUMOUR_WEEKS:
		return 0.0
	return float(r.mod)


static func set_rumour(l: Dictionary, mod: float) -> void:
	l["rumour"] = {"week": Campaign.day, "mod": mod}


# the scorecard of the week 17 beat: a renewal chance bonus on the book entry
static func scorecard_bonus(e: Dictionary) -> float:
	return float(e.get("scorecard", 0.0))


static func value_ready() -> bool:
	return Habits.fresh("H2") or bool(SalesCampaign.flags.get("value_page", false))


# ---- the beats -----------------------------------------------------------------------------------------------
static func week(day: int) -> void:
	_expire(day)
	bills_week(day)
	clean_offer(day)
	match str(WEEKS.get(day, "")):
		"incumbent":
			beat_incumbent()
		"rex":
			beat_rex()
		"flat":
			beat_flat()
		"assess":
			beat_assess()
		"laundered":
			beat_laundered()
		"plumb":
			beat_plumb()
		"rumour":
			beat_rumour()
		"audit":
			beat_audit()
		"scorecard":
			beat_scorecard()
	if int(SalesCampaign.flags.get("counter_wk", 0)) == day:
		beat_counter()


# a rumour that has run its four weeks is dropped from the lead
static func _expire(day: int) -> void:
	for l in SalesCampaign.leads:
		var r: Dictionary = l.get("rumour", {})
		if not r.is_empty() and day - int(r.week) >= RUMOUR_WEEKS:
			l.erase("rumour")


static func _best_open() -> Dictionary:
	var best := {}
	for l in SalesCampaign.leads:
		if SalesCampaign.is_open(l) and (best.is_empty() or int(l.quality) > int(best.quality)):
			best = l
	return best


static func _room() -> bool:
	return SalesCampaign.open_leads().size() < SalesCampaign.MAX_OPEN


static func _story(
	name: String,
	type: String,
	who: String,
	users: int,
	pain: String,
	quality: int,
	story: String,
	inc: String
) -> Dictionary:
	var l: Dictionary = SalesCampaign.SalesBeats.story_lead(
		name, type, who, users, pain, quality, false, story
	)
	l["incumbent"] = inc
	l["inc_seen"] = inc != "none"
	return l


# week 2: the first call shows who the incumbent is
static func beat_incumbent() -> void:
	var sb := SalesCampaign.SalesBeats
	sb.lynk("incumbent")
	var l := {}
	for x in SalesCampaign.leads:  # the best open lead you have not asked yet
		if (
			SalesCampaign.is_open(x)
			and not is_seen(x)
			and (l.is_empty() or int(x.quality) > int(l.quality))
		):
			l = x
	if l.is_empty():
		if not _room():
			return
		l = _story(
			"Pinecrest Orthodontics",
			"dental",
			"Dr. Pine",
			14,
			"the IT guy is the owner's cousin and nobody can reach him",
			44,
			"incumbent",
			"bigcheese"
		)
		SalesCampaign.accept_lead(l)
	else:
		l["incumbent"] = "bigcheese"
		l["inc_seen"] = true
	if not bool(l.get("called", false)):
		l["called"] = true
		l["stage"] = "MEETING"
	SalesCampaign.Deals.note(l, "INCUMBENT: BIG CHEESE")
	sb.set_flag("incumbent", int(l.id))
	sb.say("incumbent", "found", [], Callable(), str(l.who))


# week 3: Rex at the next table at the Chamber lunch
static func beat_rex() -> void:
	var sb := SalesCampaign.SalesBeats
	sb.lynk("rex")
	sb.ask(
		"rex",
		"card",
		func(id: String) -> void: _rex_pick(id),
		[],
		{"flyer": {"enabled": SalesCampaign.slots_left() >= 1, "hint": "NO SELLING HOURS LEFT"}}
	)


static func _rex_pick(id: String) -> void:
	var sb := SalesCampaign.SalesBeats
	sb.set_flag("rex", id)
	match id:
		"flyer":
			SalesCampaign.spend(1)
			for l in SalesCampaign.leads:
				if incumbent(l) == "bigcheese":
					reveal(l)
		"friend":
			Social.change("Garrison", 1)
	sb.say("rex", "res_" + id)


# week 5: sales_flat, the price objection (a flat price against your itemized quote)
static func beat_flat() -> void:
	var sb := SalesCampaign.SalesBeats
	var l := _best_open()
	if l.is_empty():
		sb.set_flag("flat", "none")
		return
	sb.lynk("flat")
	sb.ask(
		"flat",
		"card",
		func(id: String) -> void: _flat_pick(l, id),
		[],
		{"lines": {"enabled": SalesCampaign.slots_left() >= 1, "hint": "NO SELLING HOURS LEFT"}},
		str(l.who)
	)


static func _flat_pick(l: Dictionary, id: String) -> void:
	var sb := SalesCampaign.SalesBeats
	sb.set_flag("flat", id)
	match id:
		"tiers":
			l["present_pref"] = "tiers"
			SalesCampaign.flags["value_page"] = true
			l["pts"] = float(l.get("pts", 0.0)) + (0.02 if Habits.fresh("H2") else -0.02)
			SalesCampaign.Deals.note(l, "OFFERED THREE CHOICES")
		"match":
			l["present_pref"] = "flat"
			mark_lie(l, "MATCHED THE FLAT PRICE", "flat")
		"lines":
			SalesCampaign.spend(1)
			l["pts"] = float(l.get("pts", 0.0)) + 0.05
			SalesCampaign.Deals.note(l, "WENT LINE BY LINE")
		_:
			sb.lose_lead(l, "YOU WALKED AWAY")
	sb.say("flat", "res_" + id, [], Callable(), str(l.who))


# week 7: a Big Cheese client wants a second opinion: use ASSESS
static func beat_assess() -> void:
	var sb := SalesCampaign.SalesBeats
	sb.lynk("assess")
	sb.ask(
		"assess",
		"card",
		func(id: String) -> void: _assess_pick(id),
		[],
		{"take": {"enabled": _room(), "hint": "PIPELINE FULL"}}
	)


static func _assess_pick(id: String) -> void:
	var sb := SalesCampaign.SalesBeats
	sb.set_flag("assess", id)
	if id != "take":
		return
	var l := _story(
		"Marlowe Family Dental",
		"dental",
		"Dr. Marlowe",
		19,
		"Big Cheese says everything is included and nobody can say what",
		52,
		"assess_bc",
		"bigcheese"
	)
	l["called"] = true
	l["stage"] = "MEETING"
	SalesCampaign.accept_lead(l)
	sb.say("assess", "res_take", [], Callable(), str(l.who))


# week 9: sales_laundered, a referral that knows too much
static func beat_laundered() -> void:
	var sb := SalesCampaign.SalesBeats
	sb.lynk("laundered")
	sb.ask("laundered", "card", func(id: String) -> void: _laundered_pick(id))


static func _laundered_pick(id: String) -> void:
	var sb := SalesCampaign.SalesBeats
	sb.set_flag("laundered", id)
	var l := _story(
		"Tillman Surveying",
		"arch",
		"Gwen Tillman",
		14,
		"slow server, XP at the front desk, an IT person who never calls back",
		62,
		"laundered",
		"bigcheese"
	)
	match id:
		"take":
			l["quality"] = 70
			mark_lie(l, "TOOK A LAUNDERED LEAD", "launder")
		"ask":
			l["quality"] = 52
			Temptation.change_consc(1)
		_:
			l["quality"] = 58
			Temptation.change_consc(2)
			var e: Dictionary = sb.best_base()
			if not e.is_empty():
				SalesCampaign.Retention.adjust_mood(e, 8)
	if _room():
		SalesCampaign.accept_lead(l)
	sb.say("laundered", "res_" + id)


# week 11: the Plumb Line mirror beat with Hollis Grady
static func beat_plumb() -> void:
	var sb := SalesCampaign.SalesBeats
	sb.lynk("plumb")
	sb.ask("plumb", "card", func(id: String) -> void: _plumb_pick(id), [], {}, "Ms. Cedar")


static func _plumb_pick(id: String) -> void:
	var sb := SalesCampaign.SalesBeats
	sb.set_flag("plumb", id)
	var l := _story(
		"Cedar Point Realty",
		"realty",
		"Ms. Cedar",
		17,
		"six weeks and still no signed proposal",
		55,
		"plumb",
		"plumbline"
	)
	match id:
		"tiers":
			l["quality"] = 68 if value_ready() else 60
			l["present_pref"] = "tiers"
			SalesCampaign.Deals.note(l, "PLUMB LINE LOST HER ON THE LIST")
		"undercut":
			l["quality"] = 74
			mark_lie(l, "UNDERCUT PLUMB LINE", "undercut")
		_:
			sb.set_flag("hollis_favour", true)
			Temptation.change_consc(1)
			sb.say("plumb", "res_honest", [], Callable(), "Ms. Cedar")
			return
	if _room():
		SalesCampaign.accept_lead(l)
	sb.say("plumb", "res_" + id, [], Callable(), "Ms. Cedar")


# week 13: Big Cheese badmouths us (bonded? HIPAA safe?); the rumour lasts four weeks
static func beat_rumour() -> void:
	var sb := SalesCampaign.SalesBeats
	var l := _best_open()
	if l.is_empty():
		sb.set_flag("rumour", "none")
		return
	sb.lynk("rumour")
	sb.ask(
		"rumour",
		"card",
		func(id: String) -> void: _rumour_pick(l, id),
		[],
		{"paper": {"enabled": SalesCampaign.slots_left() >= 1, "hint": "NO SELLING HOURS LEFT"}},
		str(l.who)
	)


static func _rumour_pick(l: Dictionary, id: String) -> void:
	var sb := SalesCampaign.SalesBeats
	sb.set_flag("rumour", id)
	match id:
		"paper":
			SalesCampaign.spend(1)
			set_rumour(l, -0.03)
			SalesCampaign.Deals.note(l, "ANSWERED WITH THE PAPER")
		"back":
			set_rumour(l, 0.06)
			mark_lie(l, "BADMOUTHED REX BACK")
			SalesCampaign.flags["counter_wk"] = Campaign.day + COUNTER_AFTER
		_:
			set_rumour(l, -0.05)
			SalesCampaign.Deals.note(l, "LET THE RUMOUR STAND")
	sb.say("rumour", "res_" + id, [], Callable(), str(l.who))


# two weeks after a badmouthing Rex answers in kind
static func beat_counter() -> void:
	SalesCampaign.flags.erase("counter_wk")
	Campaign.adjust_rep(-1)
	SalesCampaign.SalesBeats.say("rumour", "counter")


# week 15: Big Cheese's vendor audit sends three prospects, quiet and then calling (capacity against the promise gap)
static func beat_audit() -> void:
	var sb := SalesCampaign.SalesBeats
	sb.lynk("audit")
	var fresh := []
	var types := ["dental", "law", "vet"]
	var pains := [
		"our antivirus was switched off over the weekend and nobody told us",
		"a letter from the vendor and a man who does not return calls",
		"the dashboard was green and the server was not"
	]
	var r := sb.rng(150)
	for i in 3:
		var pool := []
		for n in SalesCampaign.TYPES[types[i]].names:
			if not SalesCampaign.used_names.has(n):
				pool.append(n)
		if pool.is_empty():
			continue
		var who: String = SalesCampaign.TYPES[types[i]].who[r.randi() % 3]
		var l := _story(
			str(pool[r.randi() % pool.size()]),
			types[i],
			who,
			10 + r.randi() % 10,
			pains[i],
			48 + r.randi() % 12,
			"audit",
			"bigcheese"
		)
		fresh.append(l)
	sb.set_flag("audit", fresh.size())
	sb.say("audit", "info", [], func() -> void: _audit_cards(fresh))


static func _audit_cards(fresh: Array) -> void:
	for l in fresh:
		SalesCampaign._lead_card(l)


# week 17: scorecards at renewal (+0.06 renew chance for a client who saw one)
static func beat_scorecard() -> void:
	var sb := SalesCampaign.SalesBeats
	sb.lynk("scorecard")
	sb.ask(
		"scorecard",
		"card",
		func(id: String) -> void: _scorecard_pick(id),
		[],
		{
			"all": {"enabled": SalesCampaign.slots_left() >= 2, "hint": "NEEDS 2 HOURS"},
			"top": {"enabled": SalesCampaign.slots_left() >= 1, "hint": "NO SELLING HOURS LEFT"},
		}
	)


static func _entries() -> Array:
	var out := []
	for e in SalesCampaign.base_book:
		out.append(e)
	for d in SalesCampaign.book:
		if str(d.get("state", "active")) != "handover":
			out.append(d)
	return out


static func _scorecard_pick(id: String) -> void:
	var sb := SalesCampaign.SalesBeats
	sb.set_flag("scorecard", id)
	var bonus := SCORECARD if value_ready() else SCORECARD * 0.5
	var list := _entries()
	if id == "top":
		list.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("mrr", 0)) > int(b.get("mrr", 0))
		)
		list = list.slice(0, 3)
	if id != "skip":
		SalesCampaign.spend(2 if id == "all" else 1)
		for e in list:
			e["scorecard"] = bonus
	sb.say("scorecard", "res_" + id)
