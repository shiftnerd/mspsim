extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# Deals as records (sales campaign, roadmap C2; docs/campaign-paths.md section 5): a deal is the lead dictionary that lives in
# SalesCampaign.leads, extended with the quote, the promises made, the discount, the last touch and notes. Stages: LEAD, MEETING,
# QUOTED (a quote the client is still thinking about), WON, LOST. The rules live here as static functions, the state stays in
# SalesCampaign: stale deals cool off (the quality drops and an untouched lead goes cold), a quoted deal can be stolen by ByteBrothers
# (a seeded roll per week that rises with every week you leave it untouched) and the quote maths of the builder screen
# (price, SLA tier, scope items, onboarding speed, discount -> win chance, margin, promise gap, cash flow) is here too.

const WINDOW_WEEKS := 13  # the 90 day clock: 13 campaign weeks of 7 days (91 days)
const NEW_CLIENT_WEEKS := 4  # the first 30 days of a new client
const HOLD := 0.45  # of the quotes that do not win on the spot, this share stays open ("we will think about it")
const MAX_FOLLOW := 3
const EXTRAS := {
	"backup": {"label": "MANAGED BACKUP", "short": "BACKUP", "fee": 110, "cost": 35, "pts": 0.3, "pain": ["backup", "files"]},
	"patching": {"label": "MANAGED UPDATES AND AV", "short": "UPDATES+AV", "fee": 80, "cost": 25, "pts": 0.2, "pain": ["xp", "virus", "printer"]},
	"security": {"label": "MANAGED SECURITY", "short": "SECURITY", "fee": 95, "cost": 40, "pts": 0.4, "pain": ["hipaa", "stolen", "virus"]},
}
const EXTRA_ORDER := ["backup", "patching", "security"]
const ONBOARD := {
	"rush": {"label": "LIVE IN 1 WEEK", "short": "1 WEEK", "weeks": 1, "win": 0.05, "pts": 0.7, "cost": 250},
	"std": {"label": "LIVE IN 2 WEEKS", "short": "2 WEEKS", "weeks": 2, "win": 0.0, "pts": 0.0, "cost": 100},
	"slow": {"label": "LIVE IN 4 WEEKS", "short": "4 WEEKS", "weeks": 4, "win": -0.03, "pts": -0.3, "cost": 0},
}
const ONBOARD_ORDER := ["rush", "std", "slow"]
const TIER_NAME := {"low": "BASIC", "std": "STANDARD", "high": "PREMIUM"}
const RESPONSE := {"low": "NEXT BUSINESS DAY", "std": "4 HOUR RESPONSE", "high": "1 HOUR RESPONSE, ANY TIME"}
const DISCOUNTS := [0, 10, 20]
const METHOD_ORDER := ["fixed", "scope", "tm"]
const METHOD_SHORT := {"fixed": "FIXED PRICE", "scope": "SCOPE FIRST", "tm": "TIME + MATERIALS"}
const TIER_RIVAL := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
const NOTE_KEEP := 6


# ---- the quote: a normal form so the old {method, promise, price} dictionaries and the builder's both work
static func norm(q: Dictionary) -> Dictionary:
	var n: Dictionary = q.duplicate()
	var price: String = str(q.get("price", "list"))
	var disc: int = int(q.get("discount", 0))
	if price == "d10":
		price = "list"
		disc = maxi(disc, 10)
	elif price == "d20":
		price = "list"
		disc = maxi(disc, 20)
	n["price"] = price
	n["discount"] = disc
	n["method"] = str(q.get("method", "fixed"))
	n["promise"] = str(q.get("promise", "std"))
	n["extras"] = q.get("extras", [])
	n["onboard"] = str(q.get("onboard", "std"))
	return n


static func price_mult(q: Dictionary) -> float:
	var n := norm(q)
	return (1.10 if str(n.price) == "premium" else 1.0) * (1.0 - float(n.discount) / 100.0)


static func extras_fee(q: Dictionary) -> int:
	var total := 0
	for e in norm(q).extras:
		total += int(EXTRAS[str(e)].fee)
	return total


static func extras_cost(q: Dictionary) -> int:
	var total := 0
	for e in norm(q).extras:
		total += int(EXTRAS[str(e)].cost)
	return total


static func margin(q: Dictionary, lead: Dictionary = {}) -> float:
	var n := norm(q)
	var list: float = float(lead.fee) if not lead.is_empty() else 600.0
	var base: float = float(SalesCampaign.METHODS[str(n.method)].base)
	var rev: float = (list + float(extras_fee(n))) * price_mult(n)
	var cost: float = (1.0 - base) * list + float(extras_cost(n))
	return 1.0 - cost / maxf(1.0, rev)


static func price(lead: Dictionary, q: Dictionary) -> int:
	var n := norm(q)
	return int(round((float(lead.fee) + float(extras_fee(n))) * price_mult(n) * float(SalesCampaign.METHODS[str(n.method)].mrr)))


static func pain_match(lead: Dictionary, extra: String) -> bool:
	var pain: String = str(lead.get("pain", "")).to_lower()
	for k in EXTRAS[extra].pain:
		if pain.contains(str(k)):
			return true
	return false


static func win(lead: Dictionary, q: Dictionary) -> float:
	var n := norm(q)
	var p: float = float(lead.quality) / 100.0 * 0.8
	if bool(lead.get("visited", false)):
		p += 0.10
	if bool(lead.get("called", false)):
		p += 0.04
	if bool(lead.get("moon", false)):
		p += 0.05
	p += float(SalesCampaign.METHODS[str(n.method)].win) + float(SalesCampaign.PROMISES[str(n.promise)].win)
	p += (-0.07 if str(n.price) == "premium" else 0.0) + 0.006 * float(n.discount)
	for e in n.extras:
		p += 0.04 if pain_match(lead, str(e)) else -0.015
	p += float(ONBOARD[str(n.onboard)].win)
	return clampf(p, 0.05, 0.92)


# the promise gap in points, and where it comes from (kept in step with SalesCampaign.promise_gap)
static func gap_parts(lead: Dictionary, q: Dictionary) -> Dictionary:
	var n := norm(q)
	var sla: float = float(SalesCampaign.PROMISES[str(n.promise)].pts) - SalesCampaign.capacity() + float(SalesCampaign.METHODS[str(n.method)].gap)
	if bool(lead.get("moon", false)):
		sla += 1.5
	var extras := 0.0
	for e in n.extras:
		extras += float(EXTRAS[str(e)].pts)
	var onboard: float = float(ONBOARD[str(n.onboard)].pts)
	var total: float = maxf(0.0, sla + extras + onboard)
	return {"sla": sla, "extras": extras, "onboard": onboard, "total": snappedf(total, 0.1)}


static func gap(lead: Dictionary, q: Dictionary) -> float:
	return float(gap_parts(lead, q).total)


# the cash effect over the first four weeks: gross profit minus onboarding, discovery and the commission
static func cash4(lead: Dictionary, q: Dictionary) -> int:
	var n := norm(q)
	var p: int = price(lead, n)
	var gp: float = float(p) * margin(n, lead)
	var cost: int = int(ONBOARD[str(n.onboard)].cost)
	if str(n.method) == "scope":
		cost += SalesCampaign.DISCOVERY
	return int(round(4.0 * gp)) - cost - SalesCampaign.commission_for(p)


# everything the builder shows, in one place (tests read this too)
static func gauges(lead: Dictionary, q: Dictionary) -> Dictionary:
	var n := norm(q)
	var m: float = margin(n, lead)
	var g: float = gap(lead, n)
	var hours: int = int(SalesCampaign.METHODS[str(n.method)].hours)
	var blocks := []
	var can_send := true
	if m < SalesCampaign.margin_floor - 0.0001:
		blocks.append({"who": "ALAN", "text": "%d%% IS UNDER MY %d%% FLOOR." % [int(round(100.0 * m)), int(round(100.0 * SalesCampaign.margin_floor))], "hard": true})
		can_send = false
	if int(n.discount) >= 20:
		if SalesCampaign.discount_ok(lead):
			blocks.append({"who": "GARRISON", "text": "20%% OFF, OK: %s. GET IT SIGNED." % ("WE NEED THE LOGO" if int(lead.users) >= 25 else "YOU ARE BEHIND ON THE QUARTER"), "hard": false})
		else:
			blocks.append({"who": "GARRISON", "text": "20%% FOR A SMALL ACCOUNT? NO. TEN, TOPS.", "hard": true})
			can_send = false
	if SalesCampaign.slots_left() < hours:
		blocks.append({"who": "CLOCK", "text": "THIS QUOTE NEEDS %d SELLING HOURS." % hours, "hard": true})
		can_send = false
	if g >= 1.5:
		blocks.append({"who": "MORGAN", "text": "GAP %.1f: DAN AND I CANNOT CARRY THAT TODAY." % g, "hard": false})
	return {
		"win": win(lead, n),
		"margin": m,
		"gap": g,
		"price": price(lead, n),
		"cash4": cash4(lead, n),
		"hours": hours,
		"blocks": blocks,
		"can_send": can_send,
		"cap": SalesCampaign.capacity(),
	}


# ---- touches, notes, staleness and the risk meter -----------------------------------------------------
static func touch(l: Dictionary, text := "") -> void:
	l["touch"] = Campaign.day
	if text != "":
		note(l, text)


static func note(l: Dictionary, text: String) -> void:
	var notes: Array = l.get("notes", [])
	notes.append("WK%d %s" % [Campaign.day, text])
	while notes.size() > NOTE_KEEP:
		notes.pop_front()
	l["notes"] = notes


static func stale_weeks(l: Dictionary, day := -1) -> int:
	var d: int = Campaign.day if day < 0 else day
	return maxi(0, d - int(l.get("touch", l.week)))


# the chance ByteBrothers takes a quoted deal this week: it rises every week you leave it alone and falls with every follow-up
static func steal_chance(l: Dictionary, day := -1) -> float:
	var d: int = Campaign.day if day < 0 else day
	var weeks: int = maxi(0, d - int(l.get("quoted_day", d)))
	var p: float = 0.08 + 0.09 * float(stale_weeks(l, d)) + 0.04 * float(weeks) - 0.10 * float(int(l.get("follow", 0)))
	p *= float(TIER_RIVAL.get(Difficulty.tier, 1.0))
	return clampf(p, 0.04, 0.6)


# 0..100: how close the deal is to going cold, being stolen, or (once won) churning
static func risk(l: Dictionary) -> int:
	match str(l.stage):
		"LEAD", "MEETING":
			return clampi(int(round(100.0 * float(stale_weeks(l)) / float(SalesCampaign.COLD_WEEKS))), 0, 100)
		"QUOTED":
			return clampi(int(round(100.0 * steal_chance(l, Campaign.day + 1))), 0, 100)
		"WON":
			var d: Dictionary = book_deal(int(l.id))
			return int(d.get("churn", 0)) if not d.is_empty() else 0
	return 0


static func book_deal(id: int) -> Dictionary:
	for d in SalesCampaign.book:
		if int(d.id) == id:
			return d
	return {}


# ---- the week: pending quotes are answered, stale leads cool ---------------------------------------------
static func resolve_pending(day: int) -> void:
	for l in SalesCampaign.leads.duplicate():
		if str(l.stage) != "QUOTED":
			continue
		var weeks: int = day - int(l.get("quoted_day", day))
		if weeks <= 0:
			continue
		var r: RandomNumberGenerator = Difficulty.rng_for("rival", int(l.id) * 100 + day)
		if r.randf() < steal_chance(l, day):
			steal(l)
			continue
		var q: Dictionary = l.get("quote", {})
		var p: float = minf(0.9, float(q.get("win", 0.4)) * 0.8 + 0.12 * float(int(l.get("follow", 0))))
		if r.randf() < p:
			note(l, "THEY SAID YES")
			SalesCampaign.close_deal(l, q)
		elif weeks >= 3:
			l.stage = "LOST"
			l["why"] = "NO ANSWER"
			SalesCampaign.losses += 1
			note(l, "NO ANSWER")


static func steal(l: Dictionary) -> void:
	l.stage = "LOST"
	l["why"] = "BYTEBROTHERS TOOK IT"
	SalesCampaign.losses += 1
	SalesCampaign.rival_wins += 1
	note(l, "BYTEBROTHERS UNDERCUT")
	Lync._push("Garrison", "Garrison", "ByteBrothers signed %s. They called them while we were thinking about it." % str(l.name))
	Cards.ask(
		"{sales_owner}",
		"ByteBrothers just signed %s, the quote we sent %d weeks ago. They called every other day. Slow quotes lose to the guy who phones back." % [str(l.name), Campaign.day - int(l.get("quoted_day", Campaign.day))],
		[{"label": "NOTED. I WILL FOLLOW UP FASTER.", "id": "ok"}],
		func(_id: String) -> void: pass
	)


# a leads ages by the week since it was last touched: the quality fades, then it goes cold (QUOTED ones are handled above)
static func age(day: int) -> void:
	for l in SalesCampaign.leads.duplicate():
		var idle: int = stale_weeks(l, day)
		match str(l.stage):
			"LEAD", "MEETING":
				if idle >= SalesCampaign.COLD_WEEKS:
					l.stage = "LOST"
					l["why"] = "WENT COLD"
					note(l, "WENT COLD")
				elif idle >= 2:
					l["quality"] = maxi(10, int(l.quality) - 3)
			"QUOTED":
				if day - int(l.get("quoted_day", l.week)) >= SalesCampaign.COLD_WEEKS + SalesCampaign.QUOTE_WEEKS:
					l.stage = "LOST"
					l["why"] = "NO ANSWER"
			"LOST":
				if day - int(l.week) >= 3 + SalesCampaign.COLD_WEEKS:
					SalesCampaign.leads.erase(l)
			"WON":
				if day - int(l.week) > WINDOW_WEEKS + 1:
					SalesCampaign.leads.erase(l)


# ---- the promises ---------------------------------------------------------------------------------------
# one entry per promise made in the quote; the deal's gap is split between them (so the handover can treat each on its own)
static func promise_list(lead: Dictionary, q: Dictionary) -> Array:
	var n := norm(q)
	var parts := gap_parts(lead, n)
	var total: float = float(parts.total)
	var raw := []
	var sla_raw: float = maxf(0.0, float(parts.sla))
	var items := []
	var promise: String = str(n.promise)
	if promise == "low":
		items.append({"id": "sla", "kind": "SLA", "label": "%s SLA: %s" % [TIER_NAME[promise], RESPONSE[promise]], "raw": sla_raw})
	else:
		items.append({"id": "sla", "kind": "SLA", "label": "%s SLA TIER" % TIER_NAME[promise], "raw": sla_raw * 0.4})
		items.append({"id": "response", "kind": "RESPONSE", "label": RESPONSE[promise], "raw": sla_raw * 0.6})
	for e in n.extras:
		items.append({"id": "x_" + str(e), "kind": "SCOPE", "label": str(EXTRAS[str(e)].label), "raw": float(EXTRAS[str(e)].pts)})
	var ob: Dictionary = ONBOARD[str(n.onboard)]
	items.append({"id": "onboard", "kind": "ONBOARDING", "label": str(ob.label), "raw": maxf(0.0, float(ob.pts))})
	var sum := 0.0
	for it in items:
		sum += float(it.raw)
	for it in items:
		var share: float = (float(it.raw) / sum) if sum > 0.0 else 0.0
		it["gap"] = snappedf(total * share, 0.1)
		it["state"] = "open"
		it.erase("raw")
		raw.append(it)
	# the snapped shares add up to the total exactly (the largest one takes the rounding)
	if not raw.is_empty():
		var big := 0
		var sum2 := 0.0
		for k in raw.size():
			sum2 += float(raw[k].gap)
			if float(raw[k].gap) > float(raw[big].gap):
				big = k
		raw[big]["gap"] = snappedf(maxf(0.0, float(raw[big].gap) + total - sum2), 0.1)
	return raw


static func promise_gap_total(list: Array, state_gap: bool) -> float:
	var total := 0.0
	for p in list:
		total += float(p.get("left", p.gap)) if state_gap else float(p.gap)
	return total
