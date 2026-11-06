extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# The story beats of the sales campaign (roadmap C3; docs/campaign-paths.md section 5.5). One beat a week on a few weeks: a chain of
# Cards with John's choices, each one using an engine the campaign already has (cards, the quote close, the handover, the QBR visit,
# Lynk, outings, Social). Static functions; the state is SalesCampaign.flags (saved) and the text is SalesCampaign.BEAT_TEXT (patchable in
# story/strings.txt). Voices: Garrison is charming and wants the logo, Alan is gruff and wants the margin, Morgan and Dan are the
# delivery gate, John (you) is the salesman with the tie whose choices over-promise or do not.

const Deals := preload("res://scripts/deals.gd")
const Retention := preload("res://scripts/retention.gd")
const RISE_PCT := 0.08  # the price-rise letter of week 13
const RISE_FROM := 15  # renewals from this week on are covered by the 60 day notice
const WEEKS := {
	2: "chamber",
	3: "paws",
	4: "xpwave",
	6: "undercut",
	7: "sla_p1",
	8: "qbr",
	9: "crypto",
	11: "slip",
	13: "rise",
	14: "hipaa",
	15: "logo",
	16: "refund",
	18: "recruit",
	19: "diligence",
}
const TEAM_WEEKS := [5, 12]  # a team night after the first signing and after the quarter closes
const DINNER_WEEKS := [9, 17]  # a dinner with a prospect


# ---- plumbing ----------------------------------------------------------------------------------------------
static func row(beat: String, key: String) -> Dictionary:
	return SalesCampaign.BEAT_TEXT.get(beat, {}).get(key, {})


static func fmt(t: String, args: Array) -> String:
	return t % args if not args.is_empty() else t


static func rng(salt: int) -> RandomNumberGenerator:
	return Difficulty.rng_for("beats", salt)


static func lynk(beat: String, key := "lynk") -> void:
	var r := row(beat, key)
	if not r.is_empty():
		SalesCampaign._lynk(str(r.get("from", "Garrison")), str(r.get("text", "")))


# a decision card from the table. extra[id] = {args, enabled, hint} adjusts one option; who overrides the speaker
static func ask(beat: String, key: String, on_pick: Callable, args := [], extra := {}, who := "") -> void:
	var r := row(beat, key)
	var options := []
	for o in r.get("options", []):
		var ex: Dictionary = extra.get(str(o.id), {})
		var e := {"label": fmt(str(o.label), ex.get("args", [])), "id": str(o.id)}
		if ex.has("enabled"):
			e["enabled"] = bool(ex.enabled)
			e["hint"] = str(ex.get("hint", ""))
		options.append(e)
	Cards.ask(who if who != "" else str(r.get("speaker", "")), fmt(str(r.get("text", "")), args), options, on_pick)


# a card with one button
static func say(beat: String, key: String, args := [], then := Callable(), who := "") -> void:
	var r := row(beat, key)
	Cards.ask(
		who if who != "" else str(r.get("speaker", "")),
		fmt(str(r.get("text", "")), args),
		[{"label": str(r.get("ok", "OK")), "id": "ok"}],
		func(_id: String) -> void:
			if then.is_valid():
				then.call()
	)


static func story_lead(name: String, type: String, who: String, users: int, pain: String, quality: int, site := false, story := "") -> Dictionary:
	var l := {
		"id": SalesCampaign.next_id,
		"name": name,
		"type": type,
		"who": who,
		"users": users,
		"pain": pain,
		"quality": quality,
		"fee": SalesCampaign.BASE_FEE + users * SalesCampaign.PER_USER,
		"site": site,
		"week": Campaign.day,
		"stage": "LEAD",
		"called": false,
		"visited": false,
		"moon": false,
		"why": "",
		"touch": Campaign.day,
		"notes": [],
		"follow": 0,
		"story": story,
	}
	SalesCampaign.next_id += 1
	SalesCampaign.used_names.append(name)
	return l


static func flag(k: String, default: Variant = "") -> Variant:
	return SalesCampaign.flags.get(k, default)


static func set_flag(k: String, v: Variant) -> void:
	SalesCampaign.flags[k] = v


# a close at an agreed price (a multiple of the list fee): the deal goes through the normal close, handover and clawback
static func close_at(l: Dictionary, method: String, mult: float, promise := "std") -> void:
	var q := Deals.norm({"method": method, "promise": promise, "price": "list", "discount": 0, "extras": [], "onboard": "std"})
	var base: float = float(SalesCampaign.METHODS[method].base)
	q["price_week"] = int(round(float(l.fee) * mult * float(SalesCampaign.METHODS[method].mrr)))
	q["margin"] = 1.0 - (1.0 - base) / mult
	q["discount"] = int(round((1.0 - mult) * 100.0))
	q["win"] = 1.0
	l["quote"] = q.duplicate(true)
	l["margin"] = q.margin
	l["promises"] = Deals.promise_list(l, q)
	SalesCampaign.quotes_sent += 1
	SalesCampaign.close_deal(l, q)


static func quoted_lead() -> Dictionary:
	var best := {}
	for l in SalesCampaign.leads:
		if str(l.stage) == "QUOTED" and (best.is_empty() or int(l.fee) > int(best.fee)):
			best = l
	return best


static func lose_lead(l: Dictionary, why: String) -> void:
	l.stage = "LOST"
	l["why"] = why
	SalesCampaign.losses += 1
	Deals.note(l, why)


# the book entry that fits a beat: a deal in the 90 day window or a base client
static func lowest_mood_entry() -> Dictionary:
	var best := {}
	for d in SalesCampaign.book:
		if str(d.get("state", "active")) == "handover":
			continue
		if best.is_empty() or int(d.mood) < int(best.mood):
			best = d
	if best.is_empty():
		for e in SalesCampaign.base_book:
			if best.is_empty() or Retention.entry_mood(e) < Retention.entry_mood(best):
				best = e
	return best


static func best_base() -> Dictionary:
	var best := {}
	for e in SalesCampaign.base_book:
		if best.is_empty() or Retention.entry_mood(e) > Retention.entry_mood(best):
			best = e
	if best.is_empty():
		for d in SalesCampaign.book:
			if str(d.get("state", "active")) != "handover" and (best.is_empty() or int(d.mood) > int(best.mood)):
				best = d
	return best


static func base_entry(client: int) -> Dictionary:
	for e in SalesCampaign.base_book:
		if int(e.get("client", -1)) == client:
			return e
	return {}


static func entry_fee(e: Dictionary) -> int:
	return int(e.get("mrr", 0))


# ---- the weeks ---------------------------------------------------------------------------------------------
static func week(day: int) -> void:
	match str(WEEKS.get(day, "")):
		"chamber":
			chamber()
		"paws":
			paws()
		"xpwave":
			xpwave()
		"undercut":
			undercut()
		"sla_p1":
			sla_p1()
		"qbr":
			qbr()
		"crypto":
			crypto()
		"slip":
			slip()
		"rise":
			rise()
		"hipaa":
			hipaa()
		"logo":
			logo()
		"refund":
			refund()
		"recruit":
			recruit()
		"diligence":
			diligence()


# 2. the chamber of commerce lunch: a networking event with a promise to a stranger
static func chamber() -> void:
	lynk("chamber")
	ask("chamber", "invite", _chamber_invite, [], {"go": {"enabled": SalesCampaign.slots_left() >= 2, "hint": "NEEDS 2 HOURS"}})


static func _chamber_invite(id: String) -> void:
	if id != "go" or not SalesCampaign.spend(2):
		set_flag("chamber", "skip")
		return
	ask("chamber", "room", _chamber_done)


static func _chamber_done(id: String) -> void:
	var q: int = {"moon": 47, "honest": 42, "card": 33}.get(id, 33)
	var l := story_lead("Kestrel Hill Realty", "realty", "Mr. Kestrel", 16, "agents use personal email", q, false, "chamber")
	if id == "moon":
		l["moon"] = true
		Deals.note(l, "YOU PROMISED A 1 HOUR RESPONSE")
	elif id == "honest":
		l["called"] = true
		Social.change("Morgan", 1)
	SalesCampaign.accept_lead(l)
	set_flag("chamber", id)
	say("chamber", "res_" + id)


# 3. Paws and Claws: a real prospect visit at their own office, with a finding to deal with
static func paws() -> void:
	lynk("paws")
	ask(
		"paws",
		"offer",
		func(id: String) -> void:
			if id != "take":
				set_flag("paws", "pass")
				return
			var c: Dictionary = Msp.CLIENTS[8]
			var l := story_lead(str(c.name), "vet", str(c.contact), 18, "the server beeps and nobody knows why", 55, true, "paws")
			SalesCampaign.accept_lead(l)
			set_flag("paws", "lead")
	)


# the walk-around at Paws and Claws (Onsite._found calls this on a discovery visit)
static func discovery_found(f: Dictionary) -> void:
	var l := SalesCampaign.lead_by_id(SalesCampaign.visit_lead)
	if l.is_empty() or bool(l.get("found", false)):
		Hints.toast("YOU ALREADY HAVE YOUR FINDING FOR THIS VISIT.", 2.5)
		return
	l["found"] = true
	ask("paws", "found", func(id: String) -> void: _paws_found(l, id), [str(f.get("text", ""))])


static func _paws_found(l: Dictionary, id: String) -> void:
	set_flag("paws_found", id)
	match id:
		"ticket":
			l["quality"] = mini(100, int(l.quality) + 12)
			Social.change("Dan", -1)
			Deals.note(l, "LOGGED A TICKET FOR THEM")
		"project":
			l["quality"] = mini(100, int(l.quality) + 4)
			SalesCampaign.week_cost -= 500
			Social.change("Alan", 1)
			Deals.note(l, "SOLD THEM A PROJECT")
		_:
			l["quality"] = mini(100, int(l.quality) + 8)
			l["pain"] = "no backup of the server files"
			Deals.note(l, "KEPT FOR THE QUOTE")
	say("paws", "res_" + id)


# 4. the XP wave: three desktop shops after the end-of-support news
static func xpwave() -> void:
	lynk("xpwave")
	var r := rng(40)
	var types := ["dental", "law", "arch", "realty"]
	var fresh := []
	for _i in 3:
		var type: String = types[r.randi() % types.size()]
		var pool := []
		for n in SalesCampaign.TYPES[type].names:
			if not SalesCampaign.used_names.has(n):
				pool.append(n)
		var users := 8 + r.randi() % 7
		var quality := 30 + r.randi() % 20
		if pool.is_empty():
			continue
		var who: String = SalesCampaign.TYPES[type].who[r.randi() % 3]
		fresh.append(story_lead(str(pool[r.randi() % pool.size()]), type, who, users, "XP desktops before April 8", quality, false, "xp"))
	say("xpwave", "info", [], func() -> void: _xp_cards(fresh))


static func _xp_cards(fresh: Array) -> void:
	for l in fresh:
		SalesCampaign._lead_card(l)


# 6. ByteBrothers undercuts a quote: match, sell the value or walk
static func undercut() -> void:
	var l := quoted_lead()
	if l.is_empty():
		set_flag("undercut", "none")
		return
	lynk("undercut")
	ask(
		"undercut",
		"card",
		func(id: String) -> void: _undercut_pick(l, id),
		[str(l.name)],
		{"value": {"enabled": SalesCampaign.slots_left() >= 1, "hint": "NO SELLING HOURS LEFT"}}
	)


static func _undercut_pick(l: Dictionary, id: String) -> void:
	set_flag("undercut", id)
	match id:
		"match":
			Social.change("Garrison", 1)
			Social.change("Alan", -1)
			say("undercut", "res_match", [], func() -> void: close_at(l, str(l.get("quote", {}).get("method", "fixed")), 0.8))
		"value":
			SalesCampaign.spend(1)
			var p := 0.5 + 0.1 * float(mini(2, int(l.get("follow", 0)))) + Build.sales_fx("win")
			if rng(60 + int(l.id)).randf() < p:
				Social.change("Alan", 1)
				say("undercut", "res_value_win", [], func() -> void: close_at(l, str(l.get("quote", {}).get("method", "fixed")), 1.0))
			else:
				lose_lead(l, "BYTEBROTHERS UNDERCUT")
				SalesCampaign.rival_wins += 1
				say("undercut", "res_value_lose", [str(l.name)])
		_:
			Social.change("Alan", 1)
			lose_lead(l, "YOU WALKED AWAY")
			say("undercut", "res_walk")


# 7. a one hour promise meets a P1
static func sla_p1() -> void:
	var d := {}
	for x in SalesCampaign.book:
		if str(x.get("promise", "")) == "high" and Retention.sla_state(x) in ["open", "kept"] and str(x.get("state", "active")) != "handover":
			d = x
			break
	if d.is_empty():
		d = lowest_mood_entry()
	if d.is_empty():
		set_flag("p1", "none")
		return
	ask("sla_p1", "card", func(id: String) -> void: _p1_pick(d, id), [str(d.name)])


static func _p1_pick(d: Dictionary, id: String) -> void:
	set_flag("p1", id)
	match id:
		"own":
			Retention.adjust_mood(d, 6)
			Social.change("Morgan", 1)
		"blame":
			Retention.adjust_mood(d, -8)
			d["broken"] = int(d.get("broken", 0)) + 1
		_:
			Retention.adjust_mood(d, 8)
			Social.change("Dan", -1)
	say("sla_p1", "res_" + id, [str(d.name)])


# 8. the business review at your best client, with a backup upsell
static func qbr() -> void:
	var e := best_base()
	if e.is_empty():
		set_flag("qbr", "none")
		return
	var why: String = SalesCampaign.can_qbr_visit(e)
	ask(
		"qbr",
		"card",
		func(id: String) -> void: _qbr_pick(e, id),
		[str(e.name), Retention.entry_mood(e)],
		{"onsite": {"args": [SalesCampaign.qbr_minutes(e)], "enabled": why == "", "hint": why}, "phone": {"enabled": SalesCampaign.slots_left() >= 1, "hint": "NO SELLING HOURS LEFT"}}
	)


static func _qbr_pick(e: Dictionary, id: String) -> void:
	set_flag("qbr", id)
	match id:
		"onsite":
			SalesCampaign.qbr_visit(e, false)
		"phone":
			if SalesCampaign.spend(1):
				SalesCampaign.qbr_card(e, false)
		_:
			Retention.adjust_mood(e, 2)


# 9. CryptoLocker at Hoot and Holler: they call you first
static func crypto() -> void:
	var e := base_entry(3)
	if e.is_empty():
		set_flag("crypto", "none")
		return
	ask("crypto", "card", func(id: String) -> void: _crypto_pick(e, id), [], {}, str(e.get("who", "Atty. Spence")))


static func _crypto_pick(e: Dictionary, id: String) -> void:
	set_flag("crypto", id)
	match id:
		"comfort":
			Retention.adjust_mood(e, 10)
			Social.change("Garrison", 1)
			say("crypto", "res_comfort", [], Callable(), str(e.get("who", "")))
		"renew":
			say("crypto", "res_renew", [], func() -> void: Retention.renew_roll(e, 0.15, false), str(e.get("who", "")))
		_:
			Retention.adjust_mood(e, 4)
			Retention.upsell_card(e)


# 11. a deal slips past the quarter: sign it with a discount, wait or bluff
static func slip() -> void:
	var l := quoted_lead()
	if l.is_empty():
		set_flag("slip", "none")
		return
	ask("slip", "card", func(id: String) -> void: _slip_pick(l, id), [str(l.name)], {}, str(l.who))


static func _slip_pick(l: Dictionary, id: String) -> void:
	set_flag("slip", id)
	match id:
		"discount":
			say("slip", "res_discount", [], func() -> void: close_at(l, str(l.get("quote", {}).get("method", "fixed")), 0.9), str(l.who))
		"bluff":
			if rng(110 + int(l.id)).randf() < 0.5:
				say("slip", "res_bluff_win", [], func() -> void: close_at(l, str(l.get("quote", {}).get("method", "fixed")), 1.0), str(l.who))
			else:
				lose_lead(l, "THEY CALLED YOUR BLUFF")
				Social.change("Garrison", -1)
				say("slip", "res_bluff_lose", [str(l.name)], Callable(), str(l.who))
		_:
			l["quoted_day"] = Campaign.day
			say("slip", "res_wait", [], Callable(), str(l.who))


# 13. renewal season: the price rise letter has to go out 60 days ahead
static func rise() -> void:
	lynk("rise")
	ask("rise", "card", func(id: String) -> void: _rise_pick(id))


static func _rise_pick(id: String) -> void:
	set_flag("rise", id)
	match id:
		"all":
			Social.change("Alan", 1)
		"happy":
			Social.change("Alan", 1)
			Social.change("Garrison", 1)
		_:
			Social.change("Garrison", 1)
			Social.change("Alan", -1)
	say("rise", "res_" + id)


# does the price letter reach this renewal? (60 days notice: only the later renewals; "happy" = mood 70+)
static func rise_applies(e: Dictionary) -> bool:
	var policy := str(flag("rise", ""))
	if policy == "" or policy == "none" or Retention.renew_at(e) < RISE_FROM:
		return false
	return policy == "all" or Retention.entry_mood(e) >= 70


static func rise_penalty(e: Dictionary, raise_price: bool) -> float:
	return -0.07 if (not raise_price and rise_applies(e)) else 0.0


# 14. the HIPAA scare at a dental or vet client: sell what you can deliver
static func hipaa() -> void:
	var e := {}
	for d in SalesCampaign.book:
		if str(d.type) in ["dental", "vet"] and str(d.get("state", "active")) != "handover":
			e = d
			break
	if e.is_empty():
		e = base_entry(0)
	if e.is_empty():
		set_flag("hipaa", "none")
		return
	ask("hipaa", "card", func(id: String) -> void: _hipaa_pick(e, id), [str(e.name)], {}, str(e.get("who", "Dr. Patel")))


static func _hipaa_pick(e: Dictionary, id: String) -> void:
	set_flag("hipaa", id)
	var who := str(e.get("who", ""))
	match id:
		"sell":
			Social.change("Alan", 1)
			say("hipaa", "res_sell", [], func() -> void: Retention.upsell_roll(e, "security"), who)
		"moon":
			Retention.adjust_mood(e, 8)
			e["broken"] = int(e.get("broken", 0)) + 2
			if int(e.id) >= 0:
				e["churn"] = mini(100, int(e.get("churn", 10)) + 12)
			Social.change("Morgan", -1)
			say("hipaa", "res_moon", [], Callable(), who)
		_:
			Retention.adjust_mood(e, 4)
			Social.change("Morgan", 1)
			say("hipaa", "res_refer", [], Callable(), who)


# 15. the logo: Garrison wants the account, Alan wants the margin
static func logo() -> void:
	lynk("logo")
	lynk("logo", "lynk_alan")
	var l := story_lead("Harborview Dental Partners", "dental", "Dr. Lindgren", 38, "nervous about HIPAA", 52, false, "logo")
	say("logo", "garrison", [int(l.fee)], func() -> void: _logo_alan(l))


static func _logo_alan(l: Dictionary) -> void:
	var m_g := 1.0 - 0.5 / 0.7
	say("logo", "alan", [int(round(100.0 * m_g)), int(round(100.0 * SalesCampaign.margin_floor))], func() -> void: _logo_ask(l))


static func _logo_ask(l: Dictionary) -> void:
	ask("logo", "pick", func(id: String) -> void: _logo_pick(l, id), [], {"broker": {"enabled": SalesCampaign.slots_left() >= 2, "hint": "NEEDS 2 HOURS"}})


static func _logo_pick(l: Dictionary, id: String) -> void:
	set_flag("logo", id)
	SalesCampaign.accept_lead(l)
	match id:
		"garrison":
			Social.change("Garrison", 2)
			Social.change("Alan", -2)
			say("logo", "res_garrison", [], func() -> void: close_at(l, "fixed", 0.7))
		"alan":
			Social.change("Alan", 2)
			Social.change("Garrison", -1)
			if rng(150).randf() < 0.45:
				say("logo", "res_alan_win", [], func() -> void: close_at(l, "fixed", 0.9))
			else:
				lose_lead(l, "BYTEBROTHERS TOOK THE LOGO")
				SalesCampaign.rival_wins += 1
				say("logo", "res_alan_lose")
		_:
			SalesCampaign.spend(2)
			SalesCampaign.week_cost += SalesCampaign.DISCOVERY
			if rng(151).randf() < 0.65:
				Social.change("Garrison", 1)
				Social.change("Alan", 1)
				say("logo", "res_broker_win", [], func() -> void: close_at(l, "scope", 0.85))
			else:
				lose_lead(l, "TWO OWNERS, NO ANSWER")
				say("logo", "res_broker_lose")


# 16. a client wants a refund after a bad handover
static func refund() -> void:
	var e := lowest_mood_entry()
	if e.is_empty():
		set_flag("refund", "none")
		return
	var fee := entry_fee(e)
	ask(
		"refund",
		"card",
		func(id: String) -> void: _refund_pick(e, id),
		[str(e.name), 4 * fee],
		{"refund": {"args": [4 * fee]}},
		str(e.get("who", ""))
	)


static func _refund_pick(e: Dictionary, id: String) -> void:
	set_flag("refund", id)
	var fee := entry_fee(e)
	var who := str(e.get("who", ""))
	match id:
		"refund":
			SalesCampaign.week_cost += 4 * fee
			Retention.adjust_mood(e, 20)
			if int(e.id) >= 0:
				e["churn"] = maxi(0, int(e.get("churn", 10)) - 15)
			Social.change("Alan", -1)
			Social.change("Garrison", -1)
			say("refund", "res_refund", [], Callable(), who)
		"credit":
			if rng(160).randf() < 0.5 + float(Retention.entry_mood(e)) / 400.0:
				SalesCampaign.week_cost += 2 * fee
				Retention.adjust_mood(e, 12)
				say("refund", "res_credit_win", [], Callable(), who)
			else:
				Retention.adjust_mood(e, -4)
				if int(e.id) >= 0:
					e["churn"] = mini(100, int(e.get("churn", 10)) + 10)
				say("refund", "res_credit_lose", [], Callable(), who)
		_:
			Retention.adjust_mood(e, -15)
			e["broken"] = int(e.get("broken", 0)) + 1
			if int(e.id) >= 0:
				e["churn"] = mini(100, int(e.get("churn", 10)) + 25)
			Social.change("Alan", 1)
			say("refund", "res_refuse", [], Callable(), who)


# 18. ByteBrothers recruits you
static func recruit() -> void:
	ask("recruit", "card", func(id: String) -> void: _recruit_pick(id), [400 + 15 * mini(SalesCampaign.wins, 12)])


static func _recruit_pick(id: String) -> void:
	set_flag("bb", id)
	match id:
		"leave":
			Social.change("Garrison", -2)
			say("recruit", "res_leave")
		"counter":
			if str(SalesCampaign.q_result[0]) == "HIT" or Campaign.rep >= 55:
				SalesCampaign.raise_wage = 100
				Social.change("Garrison", 1)
				set_flag("bb", "raise")
				say("recruit", "res_counter_yes")
			else:
				Social.change("Garrison", -1)
				set_flag("bb", "refused")
				say("recruit", "res_counter_no")
		"both":
			if rng(180).randf() < 0.35:
				Social.change("Garrison", -3)
				Campaign.adjust_rep(-2)
				set_flag("bb", "exposed")
				say("recruit", "res_both_caught")
			else:
				set_flag("bb", "both")
				Hints.toast("YOU KEEP BOTH DOORS OPEN. NOBODY KNOWS.", 3.0)
		_:
			set_flag("bb", "declined")
			Social.change("Garrison", 2)
			Social.change("Alan", 1)
			say("recruit", "res_decline")


# 19. the roll-up due diligence: Summit Managed Holdings audits the book you sold
static func diligence_score() -> int:
	var broken := 0
	for d in SalesCampaign.book:
		broken += Retention.broken_count(d)
	return SalesCampaign.clawbacks * 2 + SalesCampaign.churned.size() + broken + SalesCampaign.at_risk() + SalesCampaign.SalesRival.open_bills().size()  # the folder: what Summit finds


static func diligence_clean() -> bool:
	return diligence_score() <= 2


static func diligence() -> void:
	set_flag("summit", true)
	lynk("diligence")
	var left := SalesCampaign.churned.size()
	ask(
		"diligence",
		"card",
		func(id: String) -> void: _dd_pick(id),
		[],
		{"disclose": {"args": [left, SalesCampaign.clawbacks]}}
	)


static func _dd_pick(id: String) -> void:
	var clean := diligence_clean()
	match id:
		"disclose":
			set_flag("dd", "clean" if clean else "disclosed")
			Social.change("Alan", 1)
			Social.change("Garrison", 1 if clean else 0)
			Campaign.adjust_rep(1)
			say("diligence", "res_disclose_clean" if clean else "res_disclose")
		"shade":
			if clean:
				set_flag("dd", "clean")
				say("diligence", "res_shade_clean")
			elif rng(190).randf() < 0.65:
				set_flag("dd", "caught")
				Social.change("Garrison", -3)
				Social.change("Alan", -2)
				Campaign.adjust_rep(-2)
				say("diligence", "res_shade_caught")
			else:
				set_flag("dd", "shaded")
				say("diligence", "res_shade_away")
		_:
			set_flag("dd", "clean" if clean else "disclosed")
			Social.change("Morgan", 1)
			say("diligence", "res_refer")


# ---- the endings ---------------------------------------------------------------------------------------------
# the share of the MRR you signed that is still on the books
static func retention_pct() -> int:
	var kept := SalesCampaign.book_mrr()
	var gone := 0
	for c in SalesCampaign.churned:
		if int(c.get("claw", 0)) > 0:
			gone += int(c.mrr)
	if kept + gone == 0:
		return 100
	return int(round(100.0 * float(kept) / float(kept + gone)))


static func earn_out() -> int:
	return int(round(float(SalesCampaign.book_mrr()) * 52.0 * 0.5 * float(retention_pct()) / 100.0 / 100.0)) * 100


static func rollup_ok() -> bool:
	return bool(flag("summit", false)) and str(flag("dd", "")) != "caught" and retention_pct() >= 50


static func churn_low() -> bool:
	return SalesCampaign.clawbacks <= 1 and SalesCampaign.churned.size() <= 2


static func bb_open() -> bool:
	return SalesCampaign.wins >= 3 and str(flag("bb", "")) != "exposed" and str(flag("bb", "")) != "declined"


static func bb_signed() -> bool:
	return str(flag("bb", "")) == "leave"
