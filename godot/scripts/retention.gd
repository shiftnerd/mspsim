extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# Keeping what you sold (sales campaign, roadmap C2): the 90 day clock of a won client with a churn-risk meter, the clawback of the
# commission when they leave inside it, renewals on a schedule with the business review (QBR) and the upsell of services, and the
# new-client SLA priority bump for the first 30 days of a premium promise. Static functions; the state is in SalesCampaign (book,
# base_book, churned) so it saves with the campaign. Units: a campaign week is 7 game days, so the 90 day window is
# Deals.WINDOW_WEEKS = 13 weeks and the first 30 days are Deals.NEW_CLIENT_WEEKS = 4 weeks.

const Deals := preload("res://scripts/deals.gd")
const SalesBeats := preload("res://scripts/sales_beats.gd")
const RENEW_AFTER := 14  # weeks from signing to the first renewal (a twelve month contract, compressed)
const CLAW := {"salary": 0.5, "balanced": 1.0, "commission": 1.0}  # the share of the commission taken back on a churn inside the window
const CLAW_WORDS := {"salary": "HALF", "balanced": "ALL", "commission": "ALL"}
const BASE_NAMES := 5  # the clients that were already on the books come up for renewal too
const BASE_MRR := 650
const UPSELL_FEE := {"backup": 110, "patching": 80, "security": 95}


# ---- the book that was there before you ------------------------------------------------------------------
static func schedule_base() -> void:
	SalesCampaign.base_book = []
	var r: RandomNumberGenerator = Difficulty.rng_for("renewals", 7)
	var weeks := [6, 8, 10, 12, 14, 16, 17, 19]
	for i in mini(BASE_NAMES, Msp.CLIENTS.size()):
		var due: int = weeks[r.randi() % weeks.size()] + (r.randi() % 2)
		SalesCampaign.base_book.append({"id": -1 - i, "name": str(Msp.CLIENTS[i].name), "client": i, "mrr": BASE_MRR + 50 * i, "renew_at": due, "kept": 0, "broken": 0, "mood": 70, "who": str(Msp.CLIENTS[i].contact)})


static func entry_mood(e: Dictionary) -> int:
	if int(e.get("client", -1)) >= 0:
		return Sales.mood(int(e.client))
	return int(e.get("mood", 60))


static func adjust_mood(e: Dictionary, n: int) -> void:
	if int(e.get("client", -1)) >= 0:
		Sales.adjust(int(e.client), n)
	else:
		e["mood"] = clampi(int(e.get("mood", 60)) + n, 0, 100)


static func renew_at(e: Dictionary) -> int:
	return int(e.get("renew_at", int(e.get("week", 1)) + RENEW_AFTER))


static func due(day: int) -> Array:
	var out := []
	for e in SalesCampaign.base_book:
		if renew_at(e) == day:
			out.append(e)
	for d in SalesCampaign.book:
		if renew_at(d) == day and str(d.get("state", "active")) != "handover":
			out.append(d)
	return out


# ---- kept promises count for the renewal --------------------------------------------------------------
static func kept_count(e: Dictionary) -> int:
	var n := 0
	for p in e.get("promises", []):
		if str(p.state) == "kept":
			n += 1
	return n + int(e.get("kept", 0))


static func broken_count(e: Dictionary) -> int:
	var n := 0
	for p in e.get("promises", []):
		if str(p.state) == "dropped":
			n += 1
	return n + int(e.get("broken", 0))


static func renew_chance(e: Dictionary, bonus := 0.0, raise_price := false) -> float:
	var p: float = 0.40 + float(entry_mood(e)) / 250.0 + 0.04 * float(kept_count(e)) - 0.06 * float(broken_count(e)) + bonus
	if raise_price:
		p -= 0.15
	p += Build.sales_fx("renew") + SalesBeats.rise_penalty(e, raise_price) + float(e.get("qbr_bonus", 0.0)) + SalesCampaign.SalesRival.scorecard_bonus(e)
	return clampf(p, 0.10, 0.95)


# ---- the 90 day clock, once a week (SalesCampaign.settle) ------------------------------------------------
static func sla_state(d: Dictionary) -> String:
	for p in d.get("promises", []):
		if str(p.id) == "sla":
			return str(p.state)
	return "open"


static func week_tick(day: int) -> void:
	for d in SalesCampaign.book.duplicate():
		if str(d.get("state", "active")) == "handover" or int(d.week) == day:
			continue
		var delta := 0.0
		var gap_left: float = float(d.gap)
		if gap_left >= 0.5 and not bool(d.resolved):
			delta += 5.0 * gap_left
		var breaches := 0
		for t in Msp.tickets:
			if str(t.get("newclient", "")) == str(d.name) and bool(t.breached) and not bool(t.get("cc", false)):
				t["cc"] = true
				breaches += 1
		d["breaches"] = int(d.get("breaches", 0)) + breaches
		delta += 5.0 * float(breaches)
		var mood: int = int(d.mood)
		if mood < 50:
			delta += float(50 - mood) / 6.0
		elif mood >= 70:
			delta -= 2.0
		if not bool(d.get("onboarded", true)) and day >= int(d.get("onboard_due", 0)):
			if SalesCampaign.capacity() >= 1.2 or int(d.get("delays", 0)) >= 2:
				d["onboarded"] = true
				d["mood"] = clampi(int(d.mood) + 3, 0, 100)
				Msp.send_text("Morgan", "%s is live. Dan finished the onboarding." % str(d.name))
			else:
				d["delays"] = int(d.get("delays", 0)) + 1
				d["mood"] = clampi(int(d.mood) - 2, 0, 100)
				delta += 5.0
				Deals.note(SalesCampaign.lead_by_id(int(d.id)), "ONBOARDING SLIPPED")
		delta -= 1.5 * float(kept_count(d))
		delta += Build.sales_fx("churn")
		d["churn"] = clampi(int(round(float(d.get("churn", 10)) + delta)), 0, 100)
		var in_window: bool = day - int(d.week) <= Deals.WINDOW_WEEKS
		if in_window:
			var c: int = int(d.churn)
			var r: RandomNumberGenerator = Difficulty.rng_for("churn", int(d.id) * 100 + day)
			var p: float = maxf(0.0, float(c - 50) / 150.0)
			if c >= 100 or r.randf() < p:
				leave(d, _why(d, breaches))
				continue
		elif str(d.get("state", "active")) != "safe":
			d["state"] = "safe"
			Hints.toast("%s CLEARED THEIR 90 DAYS. THE COMMISSION IS YOURS." % str(d.name).to_upper(), 4.0)
			Lync._push("Garrison", "Garrison", "%s made it past 90 days. That is a real client. Well done." % str(d.name))
			Deals.note(SalesCampaign.lead_by_id(int(d.id)), "CLEARED 90 DAYS")


static func _why(d: Dictionary, breaches: int) -> String:
	if float(d.gap) >= 0.5 and not bool(d.resolved):
		return "THE PROMISE GAP: YOU SOLD MORE THAN WE COULD DELIVER"
	if int(d.get("breaches", 0)) >= 2 or breaches > 0:
		return "TICKETS KEPT BREACHING THEIR SLA"
	if int(d.mood) < 50:
		return "THEY WERE UNHAPPY FROM THE START"
	return "THE ONBOARDING DRAGGED ON"


# the client leaves inside the 90 days: the commission is clawed back by the pay plan, a short card explains
static func leave(d: Dictionary, why: String) -> void:
	var claw: int = int(round(float(d.get("commission", 0)) * float(CLAW.get(SalesCampaign.plan, 1.0))))
	SalesCampaign.commission_total -= claw
	SalesCampaign.week_clawback += claw
	SalesCampaign.clawbacks += 1
	SalesCampaign.clawed_total += claw
	var qi: int = int(d.get("qi", SalesCampaign.quarter_index(int(d.week))))
	if str(SalesCampaign.q_result[qi]) == "":
		SalesCampaign.q_signed[qi] = maxi(0, int(SalesCampaign.q_signed[qi]) - int(d.get("signed_mrr", d.mrr)))
	SalesCampaign.book.erase(d)
	SalesCampaign.churned.append({"name": str(d.name), "week": int(d.week), "left": Campaign.day, "mrr": int(d.mrr), "claw": claw, "why": why})
	var l: Dictionary = SalesCampaign.lead_by_id(int(d.id))
	if not l.is_empty():
		l.stage = "LOST"
		l["why"] = "LEFT IN THE 90 DAYS"
		Deals.note(l, "LEFT, CLAWBACK $%d" % claw)
	Career.add("clawbacks")
	Social.change("Garrison", -1)
	Campaign.adjust_rep(-1)
	Cards.ask(
		"{sales_owner}",
		"%s gave notice after %d weeks. %s. Your pay plan takes %s of the commission back: -$%d. Alan will ask what we learn from it." % [str(d.name), Campaign.day - int(d.week), why.capitalize(), str(CLAW_WORDS.get(SalesCampaign.plan, "ALL")).to_lower(), claw],
		[{"label": "UNDERSTOOD", "id": "ok"}],
		func(_id: String) -> void: pass
	)
	SalesCampaign.changed.emit()


# ---- the new-client SLA bump --------------------------------------------------------------------------------
# A new client with a premium promise (still being honoured) has its tickets worked first for 30 days. The book clients are not
# Msp.CLIENTS, so this models them as a share of the ticket stream: returns the name of the deal the ticket belongs to, or "".
static func new_client_for(_client: int, tid: int) -> String:
	if not SalesCampaign.in_mode():
		return ""
	var live := []
	for d in SalesCampaign.book:
		if Campaign.day - int(d.week) <= Deals.NEW_CLIENT_WEEKS and str(d.promise) == "high" and sla_state(d) != "dropped" and sla_state(d) != "renegotiated":
			live.append(d)
	if live.is_empty():
		return ""
	var r: RandomNumberGenerator = Difficulty.rng_for("newticket", tid)
	if r.randf() < minf(0.6, 0.25 * float(live.size())):
		return str(live[r.randi() % live.size()].name)
	return ""


# ---- renewals ---------------------------------------------------------------------------------------------------
static func renewal_card(e: Dictionary) -> void:
	var mood: int = entry_mood(e)
	var text := "%s: the contract is up for renewal. $%d a week, they are %d%% happy, %d promises kept, %d broken." % [str(e.name), int(e.mrr), mood, kept_count(e), broken_count(e)]
	var visit_why: String = SalesCampaign.can_qbr_visit(e)
	Cards.ask(
		"Renewal",
		text,
		[
			{"label": "RENEW AS IT IS (%d%%)" % int(round(100.0 * renew_chance(e))), "id": "same"},
			{"label": "RUN A BUSINESS REVIEW FIRST (1 HOUR)", "id": "qbr", "enabled": SalesCampaign.slots_left() >= 1, "hint": "NO SELLING HOURS LEFT"},
			{"label": "RAISE THE PRICE 10%% (%d%%)" % int(round(100.0 * renew_chance(e, 0.0, true))), "id": "raise"},
			{"label": "GO TO THEIR OFFICE FOR THE REVIEW", "id": "onsite", "enabled": visit_why == "", "hint": visit_why},
		],
		func(id: String) -> void: renewal_pick(e, id)
	)


static func renewal_pick(e: Dictionary, id: String) -> void:
	match id:
		"qbr":
			if not SalesCampaign.spend(1):
				return renewal_card(e)
			_qbr_card(e)
		"onsite":
			SalesCampaign.qbr_visit(e)
		"raise":
			renew_roll(e, 0.0, true)
		_:
			renew_roll(e, 0.0, false)


# the business review at the client: the same three talks as the owner campaign's QBR (Onsite.MEETINGS.qbr)
static func _qbr_card(e: Dictionary) -> void:
	var mt: Dictionary = Onsite.MEETINGS.get("qbr", {})
	var options := []
	for o in mt.get("options", []):
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		str(e.get("who", "The owner")),
		str(mt.get("text", "It is review time.")),
		options,
		func(id: String) -> void:
			Career.add("qbrs")
			match id:
				"numbers":
					adjust_mood(e, 6)
					renew_roll(e, 0.08, false)
				"listen":
					adjust_mood(e, 10)
					renew_roll(e, 0.12, false)
				_:
					adjust_mood(e, 3)
					upsell_card(e, func() -> void: renew_roll(e, 0.05, false))
	)


static func renew_roll(e: Dictionary, bonus: float, raise_price: bool) -> void:
	var r: RandomNumberGenerator = Difficulty.rng_for("renew", absi(int(e.id)) * 100 + Campaign.day)
	var p: float = renew_chance(e, bonus, raise_price)
	var ok: bool = r.randf() < p
	var policy: bool = SalesBeats.rise_applies(e) and not raise_price
	var base: bool = int(e.id) < 0
	if ok:
		e["renew_at"] = Campaign.day + RENEW_AFTER
		var com: int = int(round(float(e.mrr) * 0.5 * float(SalesCampaign.PLAN_RATE.get(SalesCampaign.plan, 2.0))))
		SalesCampaign.commission_total += com
		SalesCampaign.week_commission += com
		SalesCampaign.renewals_won += 1
		Career.add("renewals")
		var extra := ""
		if raise_price:
			var more: int = int(round(float(e.mrr) * 0.10))
			e["mrr"] = int(e.mrr) + more
			_expand(e, more)
			extra = " The new fee is $%d a week." % int(e.mrr)
		elif policy:
			var more: int = int(round(float(e.mrr) * SalesBeats.RISE_PCT))
			e["mrr"] = int(e.mrr) + more
			_expand(e, more)
			if base:
				SalesCampaign.expansion_base += more
			extra = " The price letter takes effect: $%d a week." % int(e.mrr)
		Social.change("Garrison", 1)
		Cards.ask(str(e.get("who", "The owner")), "We will stay another year. Thank you for sitting down with us.%s Your renewal commission is $%d." % [extra, com], [{"label": "THANK YOU", "id": "ok"}], func(_id: String) -> void: pass)
		if not base:
			var l: Dictionary = SalesCampaign.lead_by_id(int(e.id))
			if not l.is_empty():
				Deals.note(l, "RENEWED")
	else:
		SalesCampaign.renewals_lost += 1
		Campaign.adjust_rep(-1)
		Social.change("Garrison", -1)
		if base:
			SalesCampaign.lost_base += int(e.mrr)
			SalesCampaign.base_book.erase(e)
		else:
			SalesCampaign.book.erase(e)
			SalesCampaign.churned.append({"name": str(e.name), "week": int(e.week), "left": Campaign.day, "mrr": int(e.mrr), "claw": 0, "why": "DID NOT RENEW"})
		Cards.ask(str(e.get("who", "The owner")), "We have decided to look at other providers. It is nothing personal; the renewal price and the last few months just did not add up for us.", [{"label": "UNDERSTOOD", "id": "ok"}], func(_id: String) -> void: pass)
	SalesCampaign.changed.emit()


# new MRR from a price rise or an upsell counts toward the quarter
static func _expand(_e: Dictionary, more: int) -> void:
	var qi: int = SalesCampaign.quarter_index()
	SalesCampaign.q_signed[qi] = int(SalesCampaign.q_signed[qi]) + more
	SalesCampaign.week_new += more
	SalesCampaign.expansion_total += more


# ---- upsell: services you can sell to a client you already have -------------------------------------------------
static func upsold(e: Dictionary) -> Array:
	var out: Array = e.get("extras", []).duplicate()
	out.append_array(e.get("upsold", []))
	return out


static func upsell_options(e: Dictionary) -> Array:
	var have := upsold(e)
	var out := []
	for k in Deals.EXTRA_ORDER:
		if not have.has(k):
			out.append(k)
	return out


static func upsell_card(e: Dictionary, then := Callable()) -> void:
	var left := upsell_options(e)
	if left.is_empty():
		Hints.toast("THEY ALREADY HAVE EVERY SERVICE WE SELL.", 2.5)
		if then.is_valid():
			then.call()
		return
	var options := []
	for k in left:
		options.append({"label": "%s: $%d/WK" % [str(Deals.EXTRAS[k].label), int(UPSELL_FEE[k])], "id": k})
	options.append({"label": "NOT NOW", "id": "none"})
	Cards.ask(
		"Upsell",
		"%s is %d%% happy. Which service do you offer them?" % [str(e.name), entry_mood(e)],
		options,
		func(id: String) -> void:
			if id != "none":
				upsell_roll(e, id)
			if then.is_valid():
				then.call()
	)


static func upsell_roll(e: Dictionary, id: String) -> bool:
	var n: int = int(e.get("upsells", 0))
	var r: RandomNumberGenerator = Difficulty.rng_for("upsell", absi(int(e.id)) * 100 + Campaign.day * 7 + n)
	var p: float = 0.70 if entry_mood(e) >= 60 else 0.40
	e["upsells"] = n + 1
	if r.randf() >= p:
		Hints.toast("%s WANTS TO THINK ABOUT THE %s." % [str(e.name).to_upper(), str(Deals.EXTRAS[id].short)], 3.0)
		return false
	var fee: int = int(UPSELL_FEE[id])
	var list: Array = e.get("upsold", [])
	list.append(id)
	e["upsold"] = list
	if int(e.id) >= 0:
		var cost: int = int(Deals.EXTRAS[id].cost)
		var total: float = float(e.mrr) + float(fee)
		e["margin"] = (float(e.mrr) * float(e.get("margin", 0.5)) + float(fee - cost)) / total
	else:
		SalesCampaign.expansion_base += fee
	e["mrr"] = int(e.mrr) + fee
	_expand(e, fee)
	var com: int = int(round(float(fee) * 0.5 * float(SalesCampaign.PLAN_RATE.get(SalesCampaign.plan, 2.0))))
	SalesCampaign.commission_total += com
	SalesCampaign.week_commission += com
	SalesCampaign.upsells += 1
	Career.add("upsells")
	adjust_mood(e, 2)
	Hints.toast("SOLD %s TO %s: +$%d/WK, COMMISSION $%d." % [str(Deals.EXTRAS[id].short), str(e.name).to_upper(), fee, com], 4.0)
	SalesCampaign.changed.emit()
	return true
