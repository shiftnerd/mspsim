extends Node
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# The sales campaign as Vic (roadmap C1, phase S1; docs/campaign-paths.md section 5). You are the account manager: 20 weeks,
# April to August 2014, 4 real minutes a week. The company runs on autopilot behind you (the crew works the queue, light books);
# you sell. A week has SLOTS selling hours (the clock hours 9:00-17:00): a call or a quote costs an hour, a visit costs the drive
# plus the meeting. Leads arrive as cards from a seeded stream (Difficulty.rng("leads")), live in a small pipeline (the SalesHound
# CRM app, see crm.gd) and are quoted with a method, a promise level and a price; the win chance and the margin come from the
# tables below. Over-promising raises the chance now and becomes a promise gap at the handover (the new client starts unhappier
# and complains later). A won deal lets you ring the sales bell on the main floor wall. Quota is new MRR per quarter, commission
# per deal; week 20 ends in a verdict (sales director / stay / leave / let go).
# Garrison sets the quota and approves big discounts, Alan sets the margin floor (decision cards).

signal changed

const SLOTS := 8
const MAX_OPEN := 9  # open leads in the pipeline
const COLD_WEEKS := 4  # a lead nobody touched this long goes cold
const QUOTE_WEEKS := 3  # a quote nobody answers for this long is lost
const BASE_FEE := 150  # weekly managed-services fee: base + per user
const PER_USER := 24
const DISCOVERY := 300  # scope-first discovery fee (the company's cost)
const STAGES := ["LEAD", "MEETING", "QUOTED", "WON", "LOST"]
const TYPE_ORDER := ["dental", "law", "vet", "arch", "realty", "trailer"]
const TIER_QUOTA := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
const QUARTERS := [{"label": "Q2", "from": 1, "to": 12}, {"label": "Q3", "from": 13, "to": 20}]
const Q3_SHARE := 0.8  # the second quota is this share of the first (8 weeks, not 12)
const DEFAULT_QUOTA := "standard"
const QUOTAS := {
	"safe": {"label": "SAFE: $5,000 NEW MRR BY JUNE 30", "target": 5000, "words": "A number we will hit."},
	"standard": {"label": "STANDARD: $6,500 NEW MRR BY JUNE 30", "target": 6500, "words": "What the plan needs."},
	"stretch": {"label": "STRETCH: $8,000 NEW MRR BY JUNE 30", "target": 8000, "words": "Hit it and I will fight for your raise."},
}
# the pay plan reuses the owner campaign's wages (Owner.VIC_PLANS); `rate` = weeks of the new fee paid as commission
const PLAN_RATE := {"salary": 1.0, "balanced": 2.0, "commission": 3.0}
const ACCEL := 1.5  # commission multiplier once the quarter's quota is met
const FLOORS := {
	"loose": {"label": "LOOSE: 35% MARGIN FLOOR", "floor": 0.35},
	"standard": {"label": "STANDARD: 42% MARGIN FLOOR", "floor": 0.42},
	"strict": {"label": "STRICT: 47% MARGIN FLOOR", "floor": 0.47},
}
const DEFAULT_FLOOR := 0.35

# how a quote is sold: win chance bonus, base margin (cost to serve is 1 - base at list price), hours it takes, and what happens to the fee
const METHODS := {
	"fixed": {"label": "FIXED PRICE: ONE FLAT FEE", "win": 0.02, "base": 0.50, "hours": 1, "mrr": 1.0, "gap": 0.0},
	"scope": {"label": "SCOPE IT FIRST ($300 DISCOVERY, 2 HOURS)", "win": -0.03, "base": 0.56, "hours": 2, "mrr": 1.0, "gap": -1.0},
	"tm": {"label": "TIME AND MATERIALS: THEY PAY BY THE HOUR", "win": -0.06, "base": 0.52, "hours": 1, "mrr": 0.7, "gap": 0.0},
}
# how much you promise: win chance bonus and promise points (compared with what the crew can really take on)
const PROMISES := {
	"low": {"label": "ONLY WHAT THE CONTRACT SAYS", "win": 0.0, "pts": 1.0},
	"std": {"label": "NEXT-DAY FIXES, 4 HOUR RESPONSE", "win": 0.03, "pts": 2.0},
	"high": {"label": "1 HOUR RESPONSE, ANY TIME, ANY PROBLEM", "win": 0.14, "pts": 4.0},
}
const PRICES := {
	"premium": {"label": "PREMIUM: 10% ABOVE LIST", "win": -0.07, "mult": 1.10},
	"list": {"label": "LIST PRICE", "win": 0.0, "mult": 1.0},
	"d10": {"label": "10% OFF", "win": 0.06, "mult": 0.90},
	"d20": {"label": "20% OFF (GARRISON SIGNS OFF)", "win": 0.12, "mult": 0.80},
}
const TYPES := {
	"dental":
	{
		"label": "DENTAL",
		"names": ["Maple Street Dentistry", "Riverbend Family Dental", "Dr. Osei Orthodontics", "Harbor Smiles Dental"],
		"who": ["Dr. Reyes", "Dr. Osei", "Dr. Lindgren"],
		"pains": ["XP desktops before April 8", "x-ray software keeps freezing", "no backup of patient files", "nervous about HIPAA"],
	},
	"law":
	{
		"label": "LAW",
		"names": ["Calloway and Finch LLP", "Dunmore Legal Group", "Ridge Road Law Office", "Pruitt Estate Law"],
		"who": ["Atty. Calloway", "Atty. Pruitt", "Ms. Dunmore"],
		"pains": ["email goes down every week", "still on Windows XP", "client files with no backup", "a partner's laptop was stolen"],
	},
	"vet":
	{
		"label": "VET",
		"names": ["Cedar Hollow Animal Clinic", "Four Paws Veterinary", "Lakeside Pet Hospital", "Dr. Amara's Vet Care"],
		"who": ["Dr. Amara", "Dr. Whitt", "Dr. Santos"],
		"pains": ["the records PC is dying", "wifi in the kennels is a joke", "the server beeps and nobody knows why", "a printer that jams every morning"],
	},
	"arch":
	{
		"label": "ARCHITECT",
		"names": ["Keller and Voss Design", "Studio Fernhill", "Oak Park Drafting", "Tarn and Lowe Architects"],
		"who": ["Ms. Keller", "Mr. Voss", "Ms. Lowe"],
		"pains": ["the plotter eats rolls", "CAD files crawl on the server", "no backup of the drawings", "XP workstations on the CAD floor"],
	},
	"realty":
	{
		"label": "REALTY",
		"names": ["Summit Ridge Realty", "Larkspur Homes", "Gatehouse Realty", "Twin Oaks Properties"],
		"who": ["Ms. Abbott", "Mr. Gatehouse", "Ms. Oakes"],
		"pains": ["agents use personal email", "listing photos fill the server", "wifi drops during open houses", "XP desktops at the front desk"],
	},
	"trailer":
	{
		"label": "DEMOLITION",
		"names": ["Hammerfield Demolition", "Rubble and Sons", "Ironclad Excavating", "Big Dig Contracting"],
		"who": ["Mr. Hammerfield", "Ms. Rubble", "Mr. Ironclad"],
		"pains": ["estimates live on one laptop", "the trailer wifi is a phone hotspot", "a virus took the office PC down", "old desktops in two trailers"],
	},
}

var leads: Array = []  # {id, name, type, who, users, pain, quality, fee, site, week, stage, called, visited, moon, why}
var book: Array = []  # won deals: {id, name, type, mrr, margin, week, promise, gap, mood, complain, resolved}
var next_id := 1
var used_names: Array = []
var quota_level := DEFAULT_QUOTA
var plan := "balanced"
var margin_floor := DEFAULT_FLOOR
var crunch := false  # Garrison cleared 20% discounts for the end-of-quarter crunch
var q_signed: Array = [0, 0]  # new MRR signed in each quarter
var q_result: Array = ["", ""]  # "", "HIT" or "MISS" once the quarter has closed
var warned := false  # a missed quarter: Garrison's performance warning
var week_new := 0
var week_deals := 0
var week_commission := 0
var week_cost := 0  # one-off costs this week (discovery fees)
var week_calls := 0
var week_visits := 0
var week_quotes := 0
var commission_total := 0
var wins := 0
var losses := 0
var quotes_sent := 0
var complaints := 0
var bell_ready := false
var bell_rings := 0
var crm_sel := 0
var crm_tab := "ALL"
var visit_lead := 0  # the lead you are visiting (Onsite hooks read it)
var last_report := ""


func _ready() -> void:
	reset()


func reset() -> void:
	leads = []
	book = []
	next_id = 1
	used_names = []
	quota_level = DEFAULT_QUOTA
	plan = "balanced"
	margin_floor = DEFAULT_FLOOR
	crunch = false
	q_signed = [0, 0]
	q_result = ["", ""]
	warned = false
	week_new = 0
	week_deals = 0
	week_commission = 0
	week_cost = 0
	week_calls = 0
	week_visits = 0
	week_quotes = 0
	commission_total = 0
	wins = 0
	losses = 0
	quotes_sent = 0
	complaints = 0
	bell_ready = false
	bell_rings = 0
	crm_sel = 0
	crm_tab = "ALL"
	visit_lead = 0
	last_report = ""
	if Hints.objective.begins_with("RING THE SALES BELL"):
		Hints.objective = ""


# the sales campaign is the running mode
func in_mode() -> bool:
	return Campaign.active and Campaign.mode == "sales"


# a new run or a continued one starts here (Campaign.new_game / continue_game): outings return with the chamber lunch in S3
func begin_run() -> void:
	Outings.enabled = false
	Owner.vic_plan = plan


# ---- time: selling slots are clock hours ---------------------------------------------------------------
func slots_left() -> int:
	return clampi(int(floor(World.DAY_END - maxf(World.clock, World.DAY_START) + 0.001)), 0, SLOTS)


# a call or a quote takes `hours` of the day: the clock moves, the queue ages a little (Onsite._away does both)
func spend(hours: int) -> bool:
	if slots_left() < hours:
		Hints.toast("NOT ENOUGH SELLING HOURS LEFT THIS WEEK.", 2.5)
		return false
	Onsite._away(float(hours))
	changed.emit()
	return true


func quarter_index(day := -1) -> int:
	return 0 if (Campaign.day if day < 0 else day) <= int(QUARTERS[0].to) else 1


func quarter_label(day := -1) -> String:
	return str(QUARTERS[quarter_index(day)].label)


func quota_target(qi: int) -> int:
	var base := float(QUOTAS[quota_level].target) * (1.0 if qi == 0 else Q3_SHARE)
	base *= float(TIER_QUOTA.get(Difficulty.tier, 1.0))
	return int(round(base / 50.0)) * 50


func quota_pct(qi := -1) -> int:
	var i := quarter_index() if qi < 0 else qi
	return int(round(100.0 * float(q_signed[i]) / float(maxi(1, quota_target(i)))))


# how much of the quarter has passed, 0..1 (the end of the week counts)
func elapsed(day := -1) -> float:
	var d := Campaign.day if day < 0 else day
	var q: Dictionary = QUARTERS[quarter_index(d)]
	return clampf(float(d - int(q.from) + 1) / float(int(q.to) - int(q.from) + 1), 0.0, 1.0)


func quota_met() -> bool:
	return q_signed[quarter_index()] >= quota_target(quarter_index())


func behind_pace() -> bool:
	return float(quota_pct()) / 100.0 < elapsed() - 0.001


# ---- leads --------------------------------------------------------------------------------------------
func lead_by_id(id: int) -> Dictionary:
	for l in leads:
		if int(l.id) == id:
			return l
	return {}


func heat(lead: Dictionary) -> String:
	var q := int(lead.quality)
	return "HOT" if q >= 50 else ("WARM" if q >= 35 else "COLD")


func is_open(lead: Dictionary) -> bool:
	return ["LEAD", "MEETING", "QUOTED"].has(str(lead.stage))


func open_leads() -> Array:
	var out := []
	for l in leads:
		if is_open(l):
			out.append(l)
	return out


func pipeline_value() -> int:
	var total := 0
	for l in open_leads():
		total += int(l.fee)
	return total


func book_mrr() -> int:
	var total := 0
	for d in book:
		total += int(d.mrr)
	return total


func names_for(type: String) -> Array:
	return [str(Onsite.SITE_PROSPECT[type])] + TYPES[type].names


# one lead from the stream: always six draws, so a seed repeats
func make_lead(r: RandomNumberGenerator) -> Dictionary:
	var type: String = TYPE_ORDER[r.randi() % TYPE_ORDER.size()]
	var info: Dictionary = TYPES[type]
	var pool := []
	for n in names_for(type):
		if not used_names.has(n):
			pool.append(n)
	if pool.is_empty():
		for n in names_for(type):
			used_names.erase(n)
			pool.append(n)
	var pick: String = pool[r.randi() % pool.size()]
	used_names.append(pick)
	var users := 6 + r.randi() % 30
	var quality := 20 + r.randi() % 46
	var pain: String = info.pains[r.randi() % info.pains.size()]
	var who: String = info.who[r.randi() % info.who.size()]
	var lead := {
		"id": next_id,
		"name": pick,
		"type": type,
		"who": who,
		"users": users,
		"pain": pain,
		"quality": quality,
		"fee": BASE_FEE + users * PER_USER,
		"site": pick == str(Onsite.SITE_PROSPECT[type]),
		"week": Campaign.day,
		"stage": "LEAD",
		"called": false,
		"visited": false,
		"moon": false,
		"why": "",
	}
	next_id += 1
	return lead


func draw_week(r: RandomNumberGenerator) -> Array:
	var out := []
	var n := 2 + (1 if r.randf() < 0.5 else 0)
	for _i in n:
		out.append(make_lead(r))
	return out


func lead_text(l: Dictionary) -> String:
	return (
		"%s (%s), %d users. Their problem: %s. A %s lead, about $%d a week at list price. %s"
		% [str(l.name), str(TYPES[str(l.type)].label).to_lower(), int(l.users), str(l.pain), heat(l).to_lower(), int(l.fee), "You can visit their office." if bool(l.site) else "Phone only: too far to drive."]
	)


func accept_lead(l: Dictionary) -> void:
	leads.append(l)
	changed.emit()


func drop_lead(id: int, why := "DROPPED") -> void:
	var l := lead_by_id(id)
	if l.is_empty() or not is_open(l):
		return
	l.stage = "LOST"
	l.why = why
	changed.emit()


func _age_leads(day: int) -> void:
	for l in leads.duplicate():
		var age := day - int(l.week)
		match str(l.stage):
			"LEAD", "MEETING":
				if age >= COLD_WEEKS:
					l.stage = "LOST"
					l.why = "WENT COLD"
			"QUOTED":
				if age >= COLD_WEEKS + QUOTE_WEEKS:
					l.stage = "LOST"
					l.why = "NO ANSWER"
			_:
				if age >= 3 + COLD_WEEKS:
					leads.erase(l)


# ---- the week --------------------------------------------------------------------------------------------
func begin_week(day: int) -> void:
	if not in_mode():
		return
	week_new = 0
	week_deals = 0
	week_commission = 0
	week_cost = 0
	week_calls = 0
	week_visits = 0
	week_quotes = 0
	_age_leads(day)
	_beat_cards(day)
	var fresh := draw_week(Difficulty.rng("leads"))
	if not fresh.is_empty():
		var hot: Array = fresh.filter(func(x: Dictionary) -> bool: return int(x.quality) >= 50)
		Msp.send_text(
			"SalesHound",
			"%d new leads this week%s. Open the SalesHound app on your PC." % [fresh.size(), (": %s looks hot" % str(hot[0].name)) if not hot.is_empty() else ""]
		)
	for l in fresh:
		_lead_card(l)
	for d in book:
		if bool(d.get("complain", false)) and not bool(d.get("resolved", false)) and day >= int(d.week) + 2 and not bool(d.get("asked", false)):
			d["asked"] = true
			_complaint_card(d)
	changed.emit()


func _lead_card(l: Dictionary) -> void:
	Cards.ask(
		"SalesHound lead",
		"New lead: " + lead_text(l),
		[
			{"label": "WORK IT (ADD TO THE PIPELINE)", "id": "work", "enabled": open_leads().size() < MAX_OPEN, "hint": "PIPELINE FULL"},
			{"label": "PASS", "id": "pass"},
		],
		func(id: String) -> void:
			if id == "work":
				accept_lead(l)
	)


func _lynk(who: String, text: String) -> void:
	Lync._push(who, who, text)


# Garrison and Alan: the decision cards (quota, comp plan, margin floor, the crunch, the warning)
func _beat_cards(day: int) -> void:
	if day == 1:
		_lynk("Garrison", "Welcome to the territory. Quota is on your desk in a minute. Sell what we can deliver.")
		_quota_card()
	elif day == 4:
		_lynk("Alan", "I will set the margin floor today. I do not sign deals that lose money.")
		_floor_card()
	elif day == 10:
		_crunch_card()
	elif day == 13 and warned:
		_warning_card()
	elif day >= 2:
		_review_card(day)


func _review_card(day: int) -> void:
	var qi := quarter_index(day)
	var left := int(QUARTERS[qi].to) - day + 1
	var text := (
		"Monday numbers. %d open leads worth $%d a week. %s is at %d%% of quota with %d weeks left, and the book is %d%% happy."
		% [open_leads().size(), pipeline_value(), str(QUARTERS[qi].label), quota_pct(qi), left, int(client_mood())]
	)
	Cards.ask("{sales_owner}", text, [{"label": "GOT IT", "id": "ok"}], func(_id: String) -> void: pass)


func _quota_card() -> void:
	var options := []
	for k in ["safe", "standard", "stretch"]:
		options.append({"label": str(QUOTAS[k].label), "id": k})
	Cards.ask(
		"{sales_owner}",
		"Your quota for the quarter ending June 30. Brand new MRR, signed and handed over. Pick a number you can stand behind; I will hold you to it.",
		options,
		func(id: String) -> void:
			quota_level = id
			Cards.ask(
				"{sales_owner}",
				"%s Now your pay. Salary pays $750 a week and a week of the fee per deal. Balanced pays $550 and two weeks of the fee. Commission-heavy pays $350 and three weeks of the fee." % str(QUOTAS[id].words),
				[
					{"label": "SALARY: $750 + 1 WEEK OF THE FEE", "id": "salary"},
					{"label": "BALANCED: $550 + 2 WEEKS OF THE FEE", "id": "balanced"},
					{"label": "COMMISSION-HEAVY: $350 + 3 WEEKS", "id": "commission"},
				],
				func(pid: String) -> void:
					plan = pid
					Owner.vic_plan = pid
			)
	)


func _floor_card() -> void:
	var options := []
	for k in ["loose", "standard", "strict"]:
		options.append({"label": str(FLOORS[k].label), "id": k})
	Cards.ask(
		"{tech_owner}",
		"I looked at what the XP desktop quotes cost us to deliver. Pick a margin floor: below it a quote cannot go out without me. Lower floors win more bids and leave less to pay the crew.",
		options,
		func(id: String) -> void: margin_floor = float(FLOORS[id].floor)
	)


func _crunch_card() -> void:
	Cards.ask(
		"{sales_owner}",
		"Two weeks to the quarter. You are at %d%% of quota. Do you want my sign-off for 20%% discounts on every deal until June 30, or hold the price?" % quota_pct(),
		[
			{"label": "YES, APPROVE 20% OFF FOR THE CRUNCH", "id": "yes"},
			{"label": "NO, HOLD THE PRICE", "id": "no"},
		],
		func(id: String) -> void: crunch = id == "yes"
	)


func _warning_card() -> void:
	Cards.ask(
		"{sales_owner}",
		"You missed the quarter: %d%% of quota. This is a performance warning. Miss the next one and we part ways. What do you need?" % quota_pct(0),
		[
			{"label": "UNDERSTOOD. I WILL CLOSE MORE.", "id": "ok"},
			{"label": "THE LEADS WERE THIN", "id": "excuse"},
		],
		func(id: String) -> void:
			if id == "excuse":
				Campaign.adjust_rep(-2)
	)


# ---- the quote -----------------------------------------------------------------------------------------
func discount_ok(lead: Dictionary) -> bool:
	return crunch or behind_pace() or int(lead.users) >= 25


func margin_pct(q: Dictionary) -> float:
	var base := float(METHODS[str(q.method)].base)
	return 1.0 - (1.0 - base) / float(PRICES[str(q.price)].mult)


func quote_price(lead: Dictionary, q: Dictionary) -> int:
	return int(round(float(lead.fee) * float(PRICES[str(q.price)].mult) * float(METHODS[str(q.method)].mrr)))


func win_chance(lead: Dictionary, q: Dictionary) -> float:
	var p := float(lead.quality) / 100.0 * 0.8
	if bool(lead.get("visited", false)):
		p += 0.10
	if bool(lead.get("called", false)):
		p += 0.04
	if bool(lead.get("moon", false)):
		p += 0.05
	p += float(METHODS[str(q.method)].win) + float(PROMISES[str(q.promise)].win) + float(PRICES[str(q.price)].win)
	return clampf(p, 0.05, 0.92)


# what the crew can honestly take on right now (points; a 1-hour response promise is 4)
func capacity() -> float:
	var recent := 0
	for d in book:
		if Campaign.day - int(d.week) <= 1:
			recent += 1
	var open := Msp.open_tickets().size()
	var cap := 3.0 - 0.15 * maxf(0.0, float(open) - 3.0) - 0.5 * float(recent) - 0.05 * float(book.size()) + 0.4 * float(Owner.extra_staff.size())
	return clampf(cap, 0.5, 3.5)


func promise_gap(lead: Dictionary, q: Dictionary) -> float:
	var gap := float(PROMISES[str(q.promise)].pts) - capacity() + float(METHODS[str(q.method)].gap)
	if bool(lead.get("moon", false)):
		gap += 1.5
	return snappedf(maxf(0.0, gap), 0.1)


func commission_for(mrr: int) -> int:
	var c := float(mrr) * float(PLAN_RATE.get(plan, 2.0))
	if quota_met():
		c *= ACCEL
	return int(round(c))


func start_quote(id: int) -> void:
	var l := lead_by_id(id)
	if l.is_empty() or not ["LEAD", "MEETING"].has(str(l.stage)):
		Hints.toast("NOTHING TO QUOTE ON THAT ONE.", 2.0)
		return
	if slots_left() < 1:
		Hints.toast("NO SELLING HOURS LEFT THIS WEEK.", 2.5)
		return
	_ask_method(l, {})


func _ask_method(l: Dictionary, q: Dictionary) -> void:
	var options := []
	for k in ["fixed", "scope", "tm"]:
		var enabled := slots_left() >= int(METHODS[k].hours)
		options.append({"label": str(METHODS[k].label), "id": k, "enabled": enabled, "hint": "NEEDS %d HOURS" % int(METHODS[k].hours)})
	options.append({"label": "NOT NOW", "id": "leave"})
	Cards.ask(
		"Quote builder",
		"%s, %d users. %s. How do you want to sell it?" % [str(l.name), int(l.users), str(l.pain).capitalize()],
		options,
		func(id: String) -> void:
			if id == "leave":
				return
			q["method"] = id
			_ask_promise(l, q)
	)


func _ask_promise(l: Dictionary, q: Dictionary) -> void:
	var options := []
	for k in ["low", "std", "high"]:
		options.append({"label": "%s (+%d%%)" % [str(PROMISES[k].label), int(round(100.0 * float(PROMISES[k].win)))], "id": k})
	options.append({"label": "BACK", "id": "leave"})
	Cards.ask(
		"Quote builder",
		"What do you promise on service? Dan and Morgan will have to deliver it. Capacity today is about %.1f; a 1 hour response needs 4." % capacity(),
		options,
		func(id: String) -> void:
			if id == "leave":
				_ask_method(l, q)
				return
			q["promise"] = id
			_ask_price(l, q, false)
	)


func _ask_price(l: Dictionary, q: Dictionary, no_20: bool) -> void:
	var options := []
	for k in ["premium", "list", "d10", "d20"]:
		var t := {"method": q.method, "promise": q.promise, "price": k}
		var m := margin_pct(t)
		var ok := m >= margin_floor - 0.0001
		var hint := "ALAN: UNDER THE MARGIN FLOOR"
		if k == "d20" and no_20:
			ok = false
			hint = "GARRISON SAID NO"
		options.append(
			{
				"label": "$%d/WK  WIN %d%%  MARGIN %d%%  %s" % [quote_price(l, t), int(round(100.0 * win_chance(l, t))), int(round(100.0 * m)), str(PRICES[k].label).get_slice(":", 0).get_slice(" (", 0)],
				"id": k,
				"enabled": ok,
				"hint": hint,
			}
		)
	options.append({"label": "BACK", "id": "leave"})
	Cards.ask(
		"Quote builder",
		"Pick the price for %s. The margin floor is %d%%; the promise gap if you win would be %.1f." % [str(l.name), int(round(100.0 * margin_floor)), promise_gap(l, q)],
		options,
		func(id: String) -> void:
			if id == "leave":
				_ask_promise(l, q)
				return
			q["price"] = id
			if id == "d20":
				_approve_discount(l, q)
			else:
				send_quote(l, q)
	)


func _approve_discount(l: Dictionary, q: Dictionary) -> void:
	var yes := discount_ok(l)
	Cards.ask(
		"{sales_owner}",
		(
			"Twenty percent for %s? %s Fine, but get it signed." % [str(l.name), "We need the logo." if int(l.users) >= 25 else "You are behind on the quarter."]
			if yes
			else "Twenty percent for a small account? No. Ten, tops. Find me the money somewhere else."
		),
		[{"label": "OK", "id": "ok"}],
		func(_id: String) -> void:
			if yes:
				send_quote(l, q)
			else:
				_ask_price(l, q, true)
	)


# the quote goes out: hours and discovery fee are spent, the dice decide (a seeded stream), the result lands at once
func send_quote(l: Dictionary, q: Dictionary) -> void:
	var hours := int(METHODS[str(q.method)].hours)
	if not spend(hours):
		return
	if str(q.method) == "scope":
		week_cost += DISCOVERY
	week_quotes += 1
	quotes_sent += 1
	q["win"] = win_chance(l, q)
	q["price_week"] = quote_price(l, q)
	q["margin"] = margin_pct(q)
	l["quote"] = q.duplicate()
	var won := Difficulty.rng("deals").randf() < float(q.win)
	if won:
		l.stage = "QUOTED"
		close_deal(l, q)
	else:
		l.stage = "LOST"
		l.why = "WENT ELSEWHERE"
		losses += 1
		Cards.ask(
			str(l.who),
			"Thank you for the proposal. We went with another provider: their price was close and the owner's brother-in-law knows a guy. Keep us in mind.",
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
	changed.emit()


func close_deal(l: Dictionary, q: Dictionary) -> Dictionary:
	var mrr := int(q.price_week)
	var gap := promise_gap(l, q)
	var com := commission_for(mrr)
	var qi := quarter_index()
	q_signed[qi] = int(q_signed[qi]) + mrr
	week_new += mrr
	week_deals += 1
	week_commission += com
	commission_total += com
	wins += 1
	var deal := {
		"id": int(l.id),
		"name": str(l.name),
		"type": str(l.type),
		"mrr": mrr,
		"margin": float(q.margin),
		"week": Campaign.day,
		"promise": str(q.promise),
		"gap": gap,
		"mood": 72,
		"complain": false,
		"resolved": false,
		"asked": false,
	}
	book.append(deal)
	l.stage = "WON"
	Sales.deals += 1
	Sales.last_deal = "YOU CLOSED %s!" % str(l.name).to_upper()
	bell_ready = true
	Hints.toast("DEAL! %s SIGNED AT $%d A WEEK. RING THE SALES BELL (E ON IT)." % [str(l.name).to_upper(), mrr], 4.0)
	Hints.objective = "RING THE SALES BELL ON THE MAIN FLOOR WALL (E)"
	Cards.ask(
		str(l.who),
		"We are in. Send the paperwork. Weekly fee $%d, signed for twelve months. Your commission is $%d." % [mrr, com],
		[{"label": "THANK YOU", "id": "ok"}],
		func(_id: String) -> void: _handover_card(deal)
	)
	changed.emit()
	return deal


# the handover to Morgan and Dan: the promise against what they can carry
func handover(deal: Dictionary, how: String) -> void:
	var gap: float = float(deal.gap)
	match how:
		"honest":
			deal["gap"] = 0.0
			Social.change("Dan", 1)
			Social.change("Morgan", 1)
		"brief":
			deal["gap"] = snappedf(gap * 0.5, 0.1)
			Social.change("Dan", 1)
			Social.change("Morgan", 1)
		_:
			if gap >= 0.5:
				Social.change("Dan", -1)
	var g: float = float(deal.gap)
	# an honest SLA conversation costs a little goodwill up front; a gap costs a lot of it
	deal["mood"] = clampi(72 - int(round(g * 8.0)) - (2 if how == "honest" and gap >= 0.5 else 0), 25, 85)
	deal["complain"] = g >= 0.5
	changed.emit()


func _handover_card(deal: Dictionary) -> void:
	var g := float(deal.gap)
	var gap_text := (
		"You promised more than we can carry today: a gap of %.1f." % g
		if g >= 0.5
		else "What you promised fits what we can do."
	)
	Cards.ask(
		"{ops}",
		"Handover for %s with Dan and me. $%d a week, %s. %s" % [str(deal.name), int(deal.mrr), str(PROMISES[str(deal.promise)].label).to_lower(), gap_text],
		[
			{"label": "TELL THEM THE REAL SLA, BRIEF DAN AND MORGAN", "id": "honest"},
			{"label": "BRIEF DAN AND MORGAN ON THE PROMISE", "id": "brief"},
			{"label": "JUST SEND THE SIGNED PAPERWORK OVER", "id": "gloss"},
		],
		func(id: String) -> void: handover(deal, id)
	)


func _complaint_card(deal: Dictionary) -> void:
	complaints += 1
	Cards.ask(
		"{ops}",
		"%s has called Dan twice. You told them %s and they are not getting it. They are asking for you." % [str(deal.name), str(PROMISES[str(deal.promise)].label).to_lower()],
		[
			{"label": "OWN IT: CALL THEM TODAY", "id": "own"},
			{"label": "TELL THEM THE QUEUE IS BUSY", "id": "blame"},
			{"label": "ASK DAN TO JUMP THEIR TICKETS", "id": "dan"},
		],
		func(id: String) -> void: resolve_complaint(deal, id)
	)


func resolve_complaint(deal: Dictionary, id: String) -> void:
	deal["resolved"] = true
	deal["gap"] = 0.0
	match id:
		"own":
			deal["mood"] = clampi(int(deal.mood) + 10, 0, 100)
			Social.change("Morgan", 1)
		"dan":
			deal["mood"] = clampi(int(deal.mood) + 6, 0, 100)
			Social.change("Dan", -1)
		_:
			deal["mood"] = clampi(int(deal.mood) - 8, 0, 100)
	changed.emit()


# ---- calls and visits ----------------------------------------------------------------------------------
func call_lead(id: int) -> String:
	var l := lead_by_id(id)
	if l.is_empty() or not ["LEAD", "MEETING"].has(str(l.stage)):
		return "NOTHING TO CALL."
	if bool(l.called):
		return "YOU ALREADY CALLED THEM."
	if not spend(1):
		return "NO SELLING HOURS LEFT."
	l.called = true
	l.stage = "MEETING"
	l.quality = mini(100, int(l.quality) + 5)
	week_calls += 1
	changed.emit()
	return "CALLED %s: %s" % [str(l.who).to_upper(), str(l.pain).to_upper()]


# hours a visit needs: the drive there and back plus an hour in the owner's office
func visit_hours(l: Dictionary) -> int:
	var key := site_key(str(l.type))
	return int(ceil(float(Onsite.estimate_minutes(key) * 2) / 60.0 + 1.0))


func site_key(type: String) -> int:
	for k in Onsite.SITES:
		if str(Onsite.SITES[k].type) == type:
			return int(k)
	return 0


func door_leads() -> Array:
	var out := []
	for l in open_leads():
		if bool(l.site) and ["LEAD", "MEETING"].has(str(l.stage)):
			out.append(l)
	return out


func can_visit(l: Dictionary) -> String:
	if not bool(l.site):
		return "PHONE ONLY"
	if not ["LEAD", "MEETING"].has(str(l.stage)):
		return "NOT A MEETING STAGE LEAD"
	if bool(l.visited):
		return "ALREADY VISITED"
	if slots_left() < visit_hours(l):
		return "NEEDS %d HOURS" % visit_hours(l)
	return ""


# the front door in the sales campaign lists your leads with a site
func offer_door() -> void:
	if Cards.is_open or Game.ui_open or Onsite.active:
		return
	var options := []
	for l in door_leads().slice(0, 4):
		var why := can_visit(l)
		options.append(
			{
				"label": ("TO %s (%d MIN)" % [str(l.name).to_upper(), Onsite.estimate_minutes(site_key(str(l.type)))]).left(44),
				"id": "v%d" % int(l.id),
				"enabled": why == "",
				"hint": why,
			}
		)
	options.append({"label": "STAY HERE", "id": "leave"})
	Cards.ask(
		"Front door",
		"Where to? The van is out front. %s." % Onsite.traffic_label() + (" Your meetings are the leads below." if options.size() > 1 else " You have no lead to visit right now."),
		options,
		func(id: String) -> void:
			if id.begins_with("v"):
				visit(int(id.substr(1)))
	)


func visit(id: int) -> void:
	var l := lead_by_id(id)
	if l.is_empty() or can_visit(l) != "":
		return
	var key := site_key(str(l.type))
	Cards.ask(
		"Dispatch",
		"Drive to %s? About %d minutes each way. Meeting their owner takes an hour. %s" % [str(l.name), Onsite.estimate_minutes(key), Onsite._risk_text(key)],
		[{"label": "GO NOW", "id": "go"}, {"label": "LATER", "id": "leave"}],
		func(pick: String) -> void:
			if pick == "go":
				_go(l, key)
	)


func _go(l: Dictionary, key: int) -> void:
	if Computer.is_open:
		Computer.close()
	visit_lead = int(l.id)
	week_visits += 1
	Onsite.start_visit(key, "pitch")


func visit_name(default_name: String) -> String:
	var l := lead_by_id(visit_lead)
	return default_name if l.is_empty() else str(l.name)


func visit_owner() -> String:
	var l := lead_by_id(visit_lead)
	return "" if l.is_empty() else str(l.who)


# the pitch answer in the owner's office (Onsite._meeting_answer calls this in the sales campaign)
func pitch_answer(id: String, text: String) -> void:
	var l := lead_by_id(visit_lead)
	if l.is_empty():
		return
	l.visited = true
	l.stage = "MEETING"
	match id:
		"report":
			l.quality = mini(100, int(l.quality) + 6)
		"pain":
			l.quality = mini(100, int(l.quality) + 10)
		_:
			l.quality = mini(100, int(l.quality) + 14)
			l.moon = true
			text += " Now they expect it."
	World.clock = minf(23.0, World.clock + 1.0)
	Cards.ask(str(l.who), text + " They ask you to send a quote.", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	changed.emit()


func visit_end() -> void:
	var l := lead_by_id(visit_lead)
	visit_lead = 0
	if not l.is_empty() and bool(l.visited):
		Hints.toast("BACK AT THE OFFICE. QUOTE %s IN SALESHOUND." % str(l.name).to_upper(), 4.0)


# ---- the sales bell ----------------------------------------------------------------------------------
func ring_bell(fx: Node) -> bool:
	if not (in_mode() and Campaign.player_as == "Vic"):
		return false
	if not bell_ready:
		Hints.toast("NO DEAL TO CELEBRATE YET. CLOSE ONE.", 2.5)
		return true
	bell_ready = false
	bell_rings += 1
	Hints.objective = ""
	fx.ring("player")
	Social.change_all(1)
	Campaign.adjust_rep(1)
	return true


# ---- the people and the book --------------------------------------------------------------------------
func client_mood() -> float:
	var total := Sales.average() * float(Sales.active.size())
	var n := Sales.active.size()
	for d in book:
		total += float(d.mood)
		n += 1
	return total / float(maxi(1, n))


func extra_load() -> float:
	return 0.1 * float(book.size()) if in_mode() else 0.0


# ---- the week closes -----------------------------------------------------------------------------------
func _grade(ratio: float) -> String:
	if ratio >= 1.25:
		return "S"
	if ratio >= 1.0:
		return "A"
	if ratio >= 0.75:
		return "B"
	if ratio >= 0.5:
		return "C"
	return "D"


func settle() -> Dictionary:
	var day := Campaign.day
	_hire_for_book()
	var est: Dictionary = Owner.weekly_estimate()
	var serve := 0
	for d in book:
		serve += int(round(float(d.mrr) * (1.0 - float(d.margin))))
	var revenue := int(est.revenue) + book_mrr()
	var profit := revenue - int(est.payroll) - int(est.fixed) - serve - week_commission - week_cost
	Owner.cash += profit
	Owner.history.append({"day": day, "profit": profit, "ebitda": profit, "cash": Owner.cash})
	# the book: new clients settle in, unkept promises wear them down
	for d in book:
		if int(d.week) == day:
			continue
		var drift := 1
		if float(d.gap) >= 0.5 and not bool(d.resolved):
			drift = -2
		if Sales.average() < 55.0:
			drift -= 1
		d["mood"] = clampi(int(d.mood) + drift, 0, 100)
	var qi := quarter_index(day)
	var q: Dictionary = QUARTERS[qi]
	var pct := quota_pct(qi)
	var ratio := (float(pct) / 100.0) / maxf(elapsed(day), 0.34)
	var grade := _grade(ratio)
	var verdict := "BEHIND PACE"
	if ratio >= 1.25:
		verdict = "WELL AHEAD OF QUOTA"
	elif ratio >= 1.0:
		verdict = "ON PACE FOR QUOTA"
	elif ratio >= 0.75:
		verdict = "A LITTLE BEHIND"
	elif ratio < 0.5:
		verdict = "FAR BEHIND. GARRISON IS WATCHING"
	var closing := day == int(q.to)
	if closing:
		q_result[qi] = "HIT" if pct >= 100 else "MISS"
		verdict = "%s %s AT %d%%" % [str(q.label), "HIT" if pct >= 100 else "MISSED", pct]
		if q_result[qi] == "MISS" and qi == 0:
			warned = true
			verdict += ": WARNING"
		elif q_result[qi] == "MISS":
			verdict += ": SECOND MISS"
		_lynk("Garrison", "Quarter closed at %d%%. %s" % [pct, "Good work." if pct >= 100 else "We need to talk."])
	var mood := client_mood()
	var grade_rep: Dictionary = {"S": 2, "A": 1, "B": 0, "C": -1, "D": -2}
	var rep_delta: int = int(grade_rep[grade]) + (1 if mood >= 80.0 else (-1 if mood < 50.0 else 0))
	var red := Color("ff8a80")
	var green := Color("8fe3a0")
	var warn := Color("ffd27a")
	var rows := [
		["NEW MRR SIGNED", "$%d/WK (%d DEAL%s)" % [week_new, week_deals, "" if week_deals == 1 else "S"], green if week_new > 0 else warn],
		["PIPELINE VALUE", "$%d/WK, %d LEADS" % [pipeline_value(), open_leads().size()], Color.WHITE],
		["QUOTA %s" % str(q.label), "%d%% ($%d/$%d)" % [pct, int(q_signed[qi]), quota_target(qi)], green if pct >= 100 else (warn if ratio >= 0.75 else red)],
		["COMMISSION EARNED", "$%d ($%d TOTAL)" % [week_commission, commission_total], green if week_commission > 0 else Color.WHITE],
		["CLIENT MOOD", "%d%% (%d NEW)" % [int(mood), book.size()], green if mood >= 70.0 else (red if mood < 50.0 else warn)],
		["SELLING HOURS", "%d CALLS, %d VISITS, %d QUOTES" % [week_calls, week_visits, week_quotes], Color.WHITE],
		["NEW BOOK", "$%d/WK, %d CLIENT%s" % [book_mrr(), book.size(), "" if book.size() == 1 else "S"], Color.WHITE],
		["COMPANY", "EBITDA %s, CASH %s" % [_money(profit), _money(Owner.cash)], green if profit >= 0 else red],
		["VERDICT", verdict, red if grade in ["C", "D"] or (closing and q_result[qi] == "MISS") else green],
	]
	if warned and q_result[0] == "MISS" and day > int(QUARTERS[0].to):
		rows.append(["PERFORMANCE WARNING", "ONE MORE MISSED QUARTER AND YOU ARE OUT", red])
	last_report = verdict
	return {
		"rows": rows,
		"title": "WEEK %d OF %d COMPLETE" % [day, Campaign.total_days()],
		"grade": grade,
		"profit": profit,
		"bankrupt": Owner.cash < Owner.BANKRUPT,
		"rep_delta": rep_delta,
	}


# the company cannot take on a book this size with Dan and Maya alone: one more tech for every five new clients
const NEW_HIRES := ["Sam", "Priya", "Jo"]


func _hire_for_book() -> void:
	while Owner.extra_staff.size() < mini(book.size() / 5, NEW_HIRES.size()):
		var who: String = NEW_HIRES[Owner.extra_staff.size()]
		Owner.extra_staff.append({"name": who, "skill": 0.7, "wage": 450, "trait": "steady", "age": 0})
		Msp.send_text("Morgan", "We hired %s to cover the new accounts. Keep the promises realistic." % who)


func _money(n: int) -> String:
	return "%s$%d" % ["-" if n < 0 else "", absi(n)]


# ---- the verdict (week 20) -----------------------------------------------------------------------------
func pip_failed() -> bool:
	return q_result[0] == "MISS" and q_result[1] == "MISS"


func director_ok() -> bool:
	var total_target: int = quota_target(0) + quota_target(1)
	var total: int = int(q_signed[0]) + int(q_signed[1])
	return (
		q_result[1] == "HIT"
		and (q_result[0] == "HIT" or float(total) >= 0.9 * float(total_target))
		and client_mood() >= 60.0
		and Campaign.rep >= 55
	)


func offers() -> Array:
	var out := []
	if pip_failed():
		out.append({"id": "let_go", "label": "CLEAN OUT YOUR DESK", "desc": "TWO MISSED QUARTERS. GARRISON WALKS YOU TO THE FRONT DOOR."})
	else:
		if director_ok():
			out.append({"id": "director", "label": "BECOME SALES DIRECTOR", "desc": "GARRISON GIVES YOU THE TEAM AND THE TERRITORY. ALAN SIGNS OFF ON THE MARGIN."})
		out.append({"id": "stay", "label": "STAY ON AS ACCOUNT MANAGER", "desc": "SAME DESK, A BIGGER BOOK AND A QUOTA FOR NEXT YEAR."})
	if wins >= 3:
		out.append({"id": "leave", "label": "TAKE YOUR BOOK TO BYTEBROTHERS", "desc": "THEY OFFER MORE MONEY. THE CLIENTS WILL FOLLOW YOU, OR NOT."})
	return out


const EPILOGUES := {
	"director": "YOU TAKE THE SALES DIRECTOR JOB. A TEAM OF ONE REP, A BIGGER QUOTA AND GARRISON'S OLD CLIENT LIST. THE BELL IS YOURS NOW.",
	"stay": "YOU STAY ON AS ACCOUNT MANAGER. THE BOOK YOU BUILT IS YOURS TO KEEP SAFE, AND NEXT YEAR'S QUOTA IS ALREADY ON YOUR DESK.",
	"leave": "YOU TAKE YOUR CARD FILE AND YOUR COFFEE MUG TO BYTEBROTHERS. THE CLIENTS GET A PHONE CALL FROM YOU ON MONDAY. SOME OF THEM ANSWER.",
	"let_go": "YOU BOX UP THE DESK. GARRISON SHAKES YOUR HAND AND SAYS IT WAS NOT PERSONAL. THE BELL STAYS ON THE WALL.",
}
const DEFAULT_QUOTE := "DOES THE JOB. HARD TO READ."


func review_lines(page: int, ending: String) -> Array:
	var ink := Color("17121f")
	var blue := Color("1f4e8c")
	var good := Color("1f7a3a")
	var bad := Color("b3262c")
	var lines := []
	match page:
		0:
			lines.append(["GARRISON AND ALAN - SALES REVIEW", blue])
			lines.append(["TWENTY WEEKS IN THE TERRITORY. HERE IS THE BOOK.", ink])
			for qi in 2:
				var res := str(q_result[qi])
				lines.append(
					[
						"QUOTA %s: %d%% ($%d OF $%d) %s" % [str(QUARTERS[qi].label), quota_pct(qi), int(q_signed[qi]), quota_target(qi), res],
						good if res == "HIT" else (bad if res == "MISS" else ink),
					]
				)
			lines.append(["DEALS WON %d  QUOTES LOST %d  COMMISSION $%d" % [wins, losses, commission_total], ink])
			lines.append(["BOOK: $%d A WEEK NEW, CLIENT MOOD %d%%" % [book_mrr(), int(client_mood())], good if client_mood() >= 60.0 else bad])
			lines.append(["PROMISE COMPLAINTS %d  GARRISON TRUST %d" % [complaints, Campaign.rep], ink])
		1:
			lines.append(["WHAT THE OWNERS AND YOUR TEAM SAY", blue])
			for who in Social.people():
				var quotes: Dictionary = Review.OWNER_QUOTES if Social.is_owner(who) else Review.QUOTES
				lines.append(["%s (%s):" % [who.to_upper(), Social.mood(who)], blue])
				lines.append(["'%s'" % str(quotes.get(Social.mood(who), DEFAULT_QUOTE)), ink])
		2:
			lines.append(["YOUR OPTIONS", blue])
		_:
			lines.append(["THE END", blue])
			lines.append([str(EPILOGUES.get(ending, "")), ink])
	return lines


func to_dict() -> Dictionary:
	return {
		"leads": leads,
		"book": book,
		"next_id": next_id,
		"used": used_names,
		"quota": quota_level,
		"plan": plan,
		"floor": margin_floor,
		"crunch": crunch,
		"q_signed": q_signed,
		"q_result": q_result,
		"warned": warned,
		"commission": commission_total,
		"wins": wins,
		"losses": losses,
		"quotes": quotes_sent,
		"complaints": complaints,
		"bell": bell_ready,
		"rings": bell_rings,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	leads = data.get("leads", [])
	book = data.get("book", [])
	next_id = int(data.get("next_id", 1))
	used_names = data.get("used", [])
	quota_level = str(data.get("quota", DEFAULT_QUOTA))
	plan = str(data.get("plan", "balanced"))
	margin_floor = float(data.get("floor", DEFAULT_FLOOR))
	crunch = bool(data.get("crunch", false))
	q_signed = data.get("q_signed", [0, 0])
	q_result = data.get("q_result", ["", ""])
	warned = bool(data.get("warned", false))
	commission_total = int(data.get("commission", 0))
	wins = int(data.get("wins", 0))
	losses = int(data.get("losses", 0))
	quotes_sent = int(data.get("quotes", 0))
	complaints = int(data.get("complaints", 0))
	bell_ready = bool(data.get("bell", false))
	bell_rings = int(data.get("rings", 0))
