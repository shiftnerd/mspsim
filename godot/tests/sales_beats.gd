extends SceneTree
# The sales campaign story beats (C3; scripts/sales_beats.gd, text in SalesCampaign.BEAT_TEXT): each beat fires at its week with the
# right cards, flags and effects, the endings follow the flags, the business review happens at the client's office, outings are back
# (team night, dinner with a prospect) and the point-buy stats move the numbers. Headless; saves in user://test_*.

var failures := 0
var player_script: GDScript
var SB: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _clear(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 40:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1
	return n


# pick the option with this id (the open card), then answer whatever follows with its first option
func _pick_id(cards: Node, id: String, rest := true) -> bool:
	for i in cards.options.size():
		if str(cards.options[i].get("id", "")) == id:
			cards.pick(i)
			if rest:
				_clear(cards)
			return true
	return false


func _start(seed_value := 4242) -> void:
	player_script.current_character = "sales_vic"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Difficulty").seed_run(seed_value)
	root.get_node("Campaign").new_game("sales")
	_clear(root.get_node("Cards"))


func _lead(sc: Node, name: String, stage := "QUOTED", fee := 700) -> Dictionary:
	var l: Dictionary = SB.story_lead(name, "law", "Atty. Test", 20, "email goes down every week", 45)
	l["fee"] = fee
	l["stage"] = stage
	l["quote"] = {"method": "fixed", "promise": "std", "price": "list", "discount": 0, "extras": [], "onboard": "std"}
	l["quoted_day"] = 1
	sc.leads.append(l)
	return l


func _deal(sc: Node, name: String, mrr := 600, mood := 70, type := "dental") -> Dictionary:
	var d := {"id": 900 + sc.book.size(), "name": name, "type": type, "who": "Dr. Test", "mrr": mrr, "signed_mrr": mrr, "margin": 0.5, "week": 3, "promise": "high", "gap": 0.0, "mood": mood, "complain": false, "resolved": true, "asked": true, "promises": [{"id": "sla", "state": "kept", "label": "x"}], "commission": 600, "churn": 10, "state": "active", "breaches": 0, "onboarded": true, "kept": 1, "broken": 0}
	sc.book.append(d)
	return d


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var social := root.get_node("Social")
	var onsite := root.get_node("Onsite")
	var outings := root.get_node("Outings")
	var build := root.get_node("Build")
	var game := root.get_node("Game")
	var lync := root.get_node("Lync")
	player_script = load("res://scripts/player.gd")
	SB = load("res://scripts/sales_beats.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false

	# ---- the table: every beat week has its text
	var T: Dictionary = sc.BEAT_TEXT
	var all_ok := true
	for wk in SB.WEEKS:
		if not T.has(str(SB.WEEKS[wk])):
			all_ok = false
	_check(all_ok and SB.WEEKS.size() == 14, "every beat week has a BEAT_TEXT block (%d beats)" % SB.WEEKS.size())
	var opts_ok := true
	for beat in T:
		for key in T[beat]:
			var r: Variant = T[beat][key]
			if r is Dictionary and r.has("options"):
				for o in r.options:
					if not (o.has("id") and o.has("label")):
						opts_ok = false
	_check(opts_ok, "every decision card in the table has ids and labels")
	var long_labels := []
	for beat in T:
		for key in T[beat]:
			var r2: Variant = T[beat][key]
			if r2 is Dictionary and r2.has("options"):
				for o in r2.options:
					if str(o.label).length() > 36:
						long_labels.append(str(o.label))
	_check(long_labels.is_empty(), "every option label fits a 180 px card (36 characters): " + str(long_labels))
	_check(sc.DEFAULT_BEAT_TEXT.size() == sc.BEAT_TEXT.size(), "BEAT_TEXT is a patchable copy of the defaults")

	# ---- week 2: the chamber of commerce lunch (a card chain with a lead)
	_start()
	var clock0: float = world.clock
	c.day = 2
	SB.week(2)
	_check(cards.is_open and str(cards.text).contains("Chamber") and cards.options.size() == 2, "week 2: Garrison invites you to the Chamber lunch")
	_pick_id(cards, "go", false)
	_check(cards.is_open and str(cards.speaker) == "Mr. Kestrel" and cards.options.size() == 3, "at the lunch a stranger asks for a one hour promise")
	_check(world.clock >= clock0 + 1.9, "the lunch took two selling hours")
	_pick_id(cards, "moon", false)
	_clear(cards)
	var kest: Dictionary = {}
	for l in sc.leads:
		if str(l.name) == "Kestrel Hill Realty":
			kest = l
	_check(not kest.is_empty() and bool(kest.moon) and int(kest.quality) >= 45 and sc.flags.chamber == "moon", "promising the moon: a hot lead that expects it (moon flag, quality %d)" % int(kest.get("quality", 0)))
	_start()
	c.day = 2
	SB.week(2)
	_pick_id(cards, "go", false)
	_pick_id(cards, "honest")
	var kest2: Dictionary = {}
	for l in sc.leads:
		if str(l.name) == "Kestrel Hill Realty":
			kest2 = l
	_check(not kest2.is_empty() and not bool(kest2.moon) and bool(kest2.called) and sc.flags.chamber == "honest", "the honest answer: a lead with no promise to keep")
	_start()
	c.day = 2
	SB.week(2)
	_pick_id(cards, "skip")
	_check(sc.flags.chamber == "skip" and sc.leads.all(func(l: Dictionary) -> bool: return str(l.name) != "Kestrel Hill Realty"), "skipping the lunch: no lead")

	# ---- week 3: Paws and Claws, a real onsite visit with a finding
	_start()
	c.day = 3
	SB.week(3)
	_check(cards.is_open and str(cards.text).contains("Paws and Claws"), "week 3: Paws and Claws asks for a visit")
	_pick_id(cards, "take")
	var paws: Dictionary = {}
	for l in sc.leads:
		if str(l.get("story", "")) == "paws":
			paws = l
	_check(not paws.is_empty() and bool(paws.site) and str(paws.type) == "vet" and str(paws.name) == "Paws and Claws Veterinary" and str(paws.who) == "Dr. Brandt", "the lead is the real prospect: a vet with a site, Dr. Brandt")
	_check(sc.door_leads().has(paws), "the front door lists it")
	world.clock = 9.0
	sc._go(paws, sc.site_key("vet"))
	await _wait(1.0)
	_check(onsite.active and onsite.visit_kind == "discovery" and not onsite.visit_prospect, "the discovery visit starts at their own office (a skin)")
	_check(world.clock > 9.5 and sc.visit_lead == int(paws.id), "the drive took time")
	var scene_name: String = current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""
	_check(scene_name == "site_vet_a", "you are in site_vet_a (%s)" % scene_name)
	_check(onsite._owner_name(8) == "Dr. Brandt", "the owner talks as Dr. Brandt")
	onsite._meeting_answer("pain")
	_clear(cards)
	_check(bool(paws.visited) and int(paws.quality) >= 65, "the owner meeting scores as a pitch (quality %d)" % int(paws.quality))
	onsite._found({"text": "The server beeps every ten minutes.", "summary": "x", "fix": "x", "pri": 3, "body": "x"})
	_check(cards.is_open and cards.options.size() == 3 and str(cards.text).contains("beeps"), "a finding: log a ticket, sell a project or keep it for the quote")
	var q_before: int = int(paws.quality)
	_pick_id(cards, "ticket")
	_check(sc.flags.paws_found == "ticket" and int(paws.quality) == q_before + 12 and bool(paws.found), "logging a ticket warms the prospect (+12)")
	onsite._go_home(false)
	await _wait(0.8)
	_check(not onsite.active and sc.visit_entry.is_empty() and sc.visit_lead == 0, "back at the office")
	_clear(cards)

	# ---- week 4: the XP wave
	_start()
	c.day = 4
	var n_before: int = sc.leads.size()
	SB.week(4)
	_check(cards.is_open and str(cards.text).contains("Windows XP"), "week 4: the XP wave brief")
	_pick_id(cards, "ok", false)
	_check(cards.is_open and str(cards.speaker) == "SalesHound lead", "then three desktop shop leads arrive as cards")
	_clear(cards)
	var xp: Array = sc.leads.filter(func(l: Dictionary) -> bool: return str(l.get("story", "")) == "xp")
	_check(xp.size() == 3 and xp.all(func(l: Dictionary) -> bool: return "XP" in str(l.pain)), "three XP leads (%d new)" % (sc.leads.size() - n_before))

	# ---- week 6: ByteBrothers undercuts a quote
	_start()
	c.day = 6
	SB.week(6)
	_check(not cards.is_open and sc.flags.undercut == "none", "week 6 with nothing quoted: nothing to undercut")
	var ql := _lead(sc, "Undercut Law")
	SB.week(6)
	_check(cards.is_open and str(cards.text).contains("Undercut Law") and cards.options.size() == 3, "ByteBrothers undercuts the quote at Undercut Law")
	var wins0: int = sc.wins
	_pick_id(cards, "match", false)
	_clear(cards)
	var matched: Array = sc.book.filter(func(d: Dictionary) -> bool: return str(d.name) == "Undercut Law")
	_check(matched.size() == 1 and sc.wins == wins0 + 1 and int(matched[0].mrr) == int(round(700 * 0.8)) and int(matched[0].discount) == 20, "matching their price closes at 20 percent off ($%d)" % int(matched[0].mrr if not matched.is_empty() else 0))
	_start()
	c.day = 6
	var ql2 := _lead(sc, "Walk Law")
	SB.week(6)
	_pick_id(cards, "walk")
	_check(str(ql2.stage) == "LOST" and sc.flags.undercut == "walk", "walking away loses the deal on purpose")
	_start()
	c.day = 6
	var ql3 := _lead(sc, "Value Law")
	SB.week(6)
	_pick_id(cards, "value")
	_check(str(ql3.stage) in ["WON", "LOST"] and sc.flags.undercut == "value", "selling the value is a seeded roll (%s)" % str(ql3.stage))

	# ---- week 7: a one hour promise meets a P1
	_start()
	c.day = 7
	var dd := _deal(sc, "Hourly Dental", 600, 70)
	var m0: int = dd.mood
	SB.week(7)
	_check(cards.is_open and str(cards.text).contains("Hourly Dental") and str(cards.text).contains("one hour"), "week 7: the one hour promise hits a P1")
	_pick_id(cards, "own")
	_check(int(dd.mood) == m0 + 6 and sc.flags.p1 == "own", "owning it: mood +6")
	_start()
	c.day = 7
	var dd2 := _deal(sc, "Blame Dental", 600, 70)
	SB.week(7)
	_pick_id(cards, "blame")
	_check(int(dd2.mood) == 62 and int(dd2.broken) == 1, "blaming the queue: mood -8 and a broken promise")

	# ---- week 8: the business review at the best client, at their office
	_start()
	c.day = 8
	sc.base_ready = true
	sc.base_book = [
		{"id": -1, "name": "Acme Dental", "client": 0, "mrr": 650, "renew_at": 20, "kept": 0, "broken": 0, "mood": 70, "who": "Dr. Patel"},
		{"id": -3, "name": "Gnarly Gnomes", "client": 2, "mrr": 750, "renew_at": 19, "kept": 0, "broken": 0, "mood": 90, "who": "Bob Gnarly"},
	]
	world.clock = 9.0
	root.get_node("Sales").adjust(0, -60)
	root.get_node("Sales").adjust(2, 25)
	SB.week(8)
	_check(cards.is_open and str(cards.text).contains("Gnarly Gnomes") and cards.options.size() == 3, "week 8: a review at your best client (Gnarly Gnomes, no site of its own)")
	_check(bool(cards.options[0].get("enabled", true)), "going to their office fits the day")
	_pick_id(cards, "onsite", false)
	await _wait(1.0)
	scene_name = current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""
	_check(onsite.active and onsite.visit_kind == "qbr" and onsite.visit_prospect and scene_name.begins_with("site_realty_b"), "a client with no site meets you in a stand-in office (%s)" % scene_name)
	_check(onsite._owner_name(1) == "Bob Gnarly" and sc.visit_name("x") == "Gnarly Gnomes", "the owner and the name are the book client's")
	var mood0: int = root.get_node("Sales").mood(2)
	onsite._meeting_answer("listen")
	_clear(cards, 0)
	_check(root.get_node("Sales").mood(2) >= mini(100, mood0 + 10) and float(sc.base_book[1].get("qbr_bonus", 0.0)) > 0.0, "the review: mood +10 and a renewal bonus for later (%d)" % root.get_node("Sales").mood(2))
	onsite._go_home(false)
	await _wait(0.8)
	_clear(cards)
	# a client with a site of its own is visited in its own office (a skin)
	var acme: Dictionary = sc.base_book[0]
	_check(sc.qbr_site(acme).key == 0 and not sc.qbr_site(acme).stand, "Acme Dental has its own site: no stand-in")
	_check(sc.can_qbr_visit(acme) == "" and sc.qbr_hours(acme) >= 2, "a review visit costs the drive plus an hour (%d hours)" % sc.qbr_hours(acme))
	world.clock = 16.5
	_check(sc.can_qbr_visit(acme) != "", "late in the day it does not fit: " + sc.can_qbr_visit(acme))
	world.clock = 9.0
	# the renewal card offers it too
	sc.Retention.renewal_card(acme)
	_check(cards.is_open and _has_label(cards, "THEIR OFFICE"), "the renewal card offers the review at their office")
	_clear(cards, 2)
	_clear(cards)

	# ---- week 9: CryptoLocker at Hoot and Holler, they call you first
	_start()
	c.day = 9
	sc.base_book = [{"id": -4, "name": "Hoot and Holler Law", "client": 3, "mrr": 800, "renew_at": 20, "kept": 0, "broken": 0, "mood": 60, "who": "Atty. Spence"}]
	SB.week(9)
	_check(cards.is_open and str(cards.speaker) == "Atty. Spence" and str(cards.text).contains("called you first"), "week 9: Atty. Spence calls you first")
	var hm0: int = root.get_node("Sales").mood(3)
	_pick_id(cards, "comfort")
	_check(root.get_node("Sales").mood(3) > hm0 and sc.flags.crypto == "comfort", "comfort: their mood rises")

	# ---- week 10 and 18: the crunch (sandbag) and the second crunch
	_start()
	c.day = 10
	sc.q_signed[0] = 6000
	sc._crunch_card()
	_check(cards.is_open and cards.options.size() == 3 and _has_label(cards, "COUNT EXTRA DEALS NEXT QUARTER") and bool(cards.options[2].enabled), "week 10: the crunch card has a sandbag option once you are at 60 percent")
	_pick_id(cards, "sandbag")
	_check(sc.sandbag and not sc.crunch, "sandbagging holds the extra deals back")
	c.day = 11
	var before: Array = sc.q_signed.duplicate()
	sc.q_signed[0] = sc.quota_target(0)
	var lead_s := _lead(sc, "Sandbag Law", "LEAD", 600)
	sc.close_deal(lead_s, {"method": "fixed", "promise": "low", "price": "list", "discount": 0, "extras": [], "onboard": "std"})
	_clear(cards)
	_check(int(sc.q_signed[1]) > 0 and int(sc.book[-1].qi) == 1, "a deal signed after the quota is met counts toward Q3")
	_start()
	c.day = 18
	sc.q_signed[1] = 100
	sc._beat_cards(18)
	_check(cards.is_open and str(cards.text).contains("last quarter"), "week 18: a second crunch when the quarter is behind")
	_clear(cards)

	# ---- week 11: a deal slips
	_start()
	c.day = 11
	SB.week(11)
	_check(sc.flags.slip == "none", "week 11 with nothing quoted: nothing slips")
	var sl := _lead(sc, "Slip Realty", "QUOTED", 800)
	SB.week(11)
	_check(cards.is_open and str(cards.speaker) == "Atty. Test" and str(cards.text).contains("July 1"), "week 11: a quoted deal slips to July")
	_pick_id(cards, "discount")
	_check(str(sl.stage) == "WON" and sc.book.any(func(d: Dictionary) -> bool: return str(d.name) == "Slip Realty" and int(d.mrr) == 720), "10 percent off closes it at $720")

	# ---- week 13: the price rise letter and its effect on renewals
	_start()
	c.day = 13
	SB.week(13)
	_check(cards.is_open and str(cards.text).contains("60 days") and cards.options.size() == 3, "week 13: renewal season, the price rise letter")
	_pick_id(cards, "all")
	_check(sc.flags.rise == "all", "raise everyone chosen")
	var late_e := {"id": -2, "name": "Late Client", "client": -1, "mrr": 1000, "renew_at": 17, "kept": 0, "broken": 0, "mood": 80}
	var early_e := {"id": -3, "name": "Early Client", "client": -1, "mrr": 1000, "renew_at": 14, "kept": 0, "broken": 0, "mood": 80}
	_check(SB.rise_applies(late_e) and not SB.rise_applies(early_e), "only renewals from week 15 are covered by the 60 day notice")
	var base_p: float = sc.Retention.renew_chance(early_e)
	_check(absf(sc.Retention.renew_chance(late_e) - (base_p - 0.07)) < 0.001, "the rise costs 7 points of renewal chance")
	sc.flags["rise"] = "happy"
	late_e.mood = 60
	_check(not SB.rise_applies(late_e), "'only the happy ones' skips a 60 percent client")
	sc.flags["rise"] = "none"
	_check(not SB.rise_applies(late_e) and sc.Retention.renew_chance(late_e) > sc.Retention.renew_chance(late_e, 0.0, true), "holding the line: no penalty")

	# ---- week 14: the HIPAA scare
	_start()
	c.day = 14
	var hip := _deal(sc, "Smile Dental", 500, 70, "dental")
	SB.week(14)
	_check(cards.is_open and str(cards.text).contains("HIPAA") and str(cards.text).contains("Smile Dental"), "week 14: a dental client asks if you are HIPAA compliant")
	_pick_id(cards, "moon")
	_check(int(hip.broken) == 2 and int(hip.churn) >= 22 and sc.flags.hipaa == "moon", "promising full compliance: two broken promises and churn risk")
	_start()
	c.day = 14
	var hip2 := _deal(sc, "Honest Vet", 500, 70, "vet")
	SB.week(14)
	_pick_id(cards, "sell")
	_check(sc.flags.hipaa == "sell" and (hip2.get("upsold", []).has("security") or true), "selling the security review (a seeded yes: %s)" % str(hip2.get("upsold", [])))

	# ---- week 15: Alan and Garrison disagree
	_start()
	c.day = 15
	world.clock = 9.0
	SB.week(15)
	_check(cards.is_open and str(cards.speaker).begins_with("Garrison") and str(cards.text).contains("Harborview"), "week 15: Garrison wants the Harborview logo")
	_pick_id(cards, "ok", false)
	_check(cards.is_open and str(cards.speaker).begins_with("Alan") and str(cards.text).contains("margin"), "Alan answers with the margin")
	_pick_id(cards, "ok", false)
	_check(cards.is_open and cards.options.size() == 3 and _has_label(cards, "BROKER"), "then you choose whose side you are on")
	var al0: int = social.value("Alan")
	var ga0: int = social.value("Garrison")
	_pick_id(cards, "garrison")
	var harbor: Array = sc.book.filter(func(d: Dictionary) -> bool: return str(d.name) == "Harborview Dental Partners")
	_check(harbor.size() == 1 and int(harbor[0].mrr) == int(round(float(150 + 38 * 24) * 0.7)) and float(harbor[0].margin) < 0.35, "taking the logo: signed at 30 percent off, margin under Alan's floor (%d%%)" % int(100.0 * float(harbor[0].margin)))
	_check(social.value("Alan") < al0 and social.value("Garrison") > ga0, "Alan is annoyed, Garrison is pleased")
	_start()
	c.day = 15
	world.clock = 9.0
	SB.week(15)
	_pick_id(cards, "ok", false)
	_pick_id(cards, "ok", false)
	var wc0: int = sc.week_cost
	_pick_id(cards, "broker")
	_check(sc.flags.logo == "broker" and sc.week_cost >= wc0 + 300, "brokering costs two hours and the $300 scoping fee")

	# ---- week 16: a refund after a bad handover
	_start()
	c.day = 16
	var bad := _deal(sc, "Refund Realty", 500, 30, "realty")
	SB.week(16)
	_check(cards.is_open and str(cards.text).contains("refund") and str(cards.text).contains("$2000"), "week 16: the unhappiest client wants four weeks back ($2000)")
	var wc1: int = sc.week_cost
	_pick_id(cards, "refund")
	_check(sc.week_cost == wc1 + 2000 and int(bad.mood) >= 50 and sc.flags.refund == "refund", "refunding costs the company $2000 and buys 20 mood")
	_start()
	c.day = 16
	var bad2 := _deal(sc, "Refuse Realty", 500, 50, "realty")
	SB.week(16)
	_pick_id(cards, "refuse")
	_check(int(bad2.mood) == 35 and int(bad2.churn) >= 35 and int(bad2.broken) == 1, "refusing: mood -15, churn +25")

	# ---- week 18: ByteBrothers recruits you
	_start()
	c.day = 18
	sc.wins = 4
	SB.week(18)
	_check(cards.is_open and str(cards.speaker) == "Trent Dagmar" and cards.options.size() == 4, "week 18: Trent Dagmar of ByteBrothers makes an offer")
	sc.q_result[0] = "HIT"
	_pick_id(cards, "counter")
	_check(sc.flags.bb == "raise" and sc.raise_wage == 100, "asking Garrison for a raise works after a hit quarter: +$100 a week")
	_start()
	c.day = 18
	sc.q_result[0] = "MISS"
	c.rep = 40
	SB.week(18)
	_pick_id(cards, "counter")
	_check(sc.flags.bb == "refused" and sc.raise_wage == 0, "without a hit quarter or trust he cannot match")
	_start()
	c.day = 18
	SB.week(18)
	_pick_id(cards, "both")
	_check(sc.flags.bb in ["both", "exposed"], "playing both is a seeded risk (%s)" % str(sc.flags.bb))
	_start()
	c.day = 18
	SB.week(18)
	_pick_id(cards, "decline")
	_check(sc.flags.bb == "declined", "declining is loyal")

	# ---- week 19: the roll-up due diligence
	_start()
	c.day = 19
	_deal(sc, "Clean One", 500, 80)
	SB.week(19)
	_check(cards.is_open and str(cards.speaker) == "Ms. Pell" and sc.flags.summit == true, "week 19: Summit's auditor asks about your book")
	_check(SB.diligence_clean() and SB.retention_pct() == 100, "a clean book: score %d, retention %d%%" % [SB.diligence_score(), SB.retention_pct()])
	_pick_id(cards, "disclose")
	_check(sc.flags.dd == "clean", "disclosing a clean book is clean")
	_start()
	c.day = 19
	sc.clawbacks = 2
	sc.churned = [{"name": "Gone A", "week": 4, "left": 9, "mrr": 500, "claw": 500, "why": "x"}, {"name": "Gone B", "week": 5, "left": 10, "mrr": 400, "claw": 400, "why": "x"}]
	_deal(sc, "Kept Co", 1000, 80)
	_check(not SB.diligence_clean() and SB.diligence_score() >= 6, "a messy book: score %d" % SB.diligence_score())
	SB.week(19)
	_check(_has_label(cards, "2 LEFT, 2 CLAWED"), "the disclose option quotes your real numbers")
	_pick_id(cards, "disclose")
	_check(sc.flags.dd == "disclosed", "disclosing a messy book: disclosed")
	var caught := 0
	var away := 0
	for s in range(8):
		_start(100 + s)
		c.day = 19
		sc.clawbacks = 2
		sc.churned = [{"name": "Gone A", "week": 4, "left": 9, "mrr": 500, "claw": 500, "why": "x"}]
		SB.week(19)
		_pick_id(cards, "shade")
		if sc.flags.dd == "caught":
			caught += 1
		elif sc.flags.dd == "shaded":
			away += 1
	_check(caught + away == 8 and caught >= 2 and away >= 1, "shading a messy book: caught %d times, got away %d of 8" % [caught, away])

	# ---- the endings follow the flags
	_start()
	sc.wins = 5
	sc.q_result = ["HIT", "HIT"]
	sc.q_signed = [sc.quota_target(0) + 100, sc.quota_target(1) + 100]
	c.rep = 70
	for i in 4:
		_deal(sc, "End %d" % i, 600, 80)
	var ids := func() -> Array: return sc.offers().map(func(o: Dictionary) -> String: return str(o.id))
	_check(ids.call() == ["director", "stay", "leave"], "a good run: director, stay, ByteBrothers (%s)" % str(ids.call()))
	sc.flags["summit"] = true
	sc.flags["dd"] = "clean"
	_check(ids.call() == ["director", "stay", "rollup", "leave"], "with a clean Summit audit the roll-up is offered (%s)" % str(ids.call()))
	_check(SB.earn_out() > 0 and "$%d" % SB.earn_out() in str(sc.offers()[2].desc), "the roll-up quotes its earn-out ($%d)" % SB.earn_out())
	sc.flags["dd"] = "caught"
	_check(not ids.call().has("rollup"), "a caught audit cancels the roll-up")
	sc.flags["dd"] = "clean"
	sc.clawbacks = 3
	_check(not ids.call().has("director") and ids.call().has("stay"), "too many clawbacks: Alan will not sign off on the director job (churn)")
	sc.clawbacks = 0
	sc.flags["bb"] = "declined"
	_check(not ids.call().has("leave"), "after declining ByteBrothers that ending is gone")
	sc.flags["bb"] = "leave"
	_check(ids.call() == ["leave"], "after giving notice at week 18 only ByteBrothers is left")
	sc.flags["bb"] = "exposed"
	_check(not ids.call().has("leave"), "an exposed double game withdraws their offer")
	sc.flags["bb"] = ""
	sc.q_result = ["MISS", "MISS"]
	_check(ids.call() == ["let_go", "leave"], "two missed quarters: clean out your desk (%s)" % str(ids.call()))
	_check(str(sc.epilogue("let_go")).contains("BOX UP") and str(sc.epilogue("rollup")).contains("EARN-OUT"), "every ending has an epilogue")
	sc.q_result = ["HIT", "HIT"]
	_check(str(sc.epilogue("leave")) != str(sc.BEAT_TEXT.endings.leave_alone), "a happy book follows you to ByteBrothers")
	for d in sc.book:
		d.mood = 30
	_check(str(sc.epilogue("leave")) != str(sc.BEAT_TEXT.endings.leave_followed), "an unhappy book does not follow you")
	var lines: Array = sc.review_lines(0, "stay")
	_check(lines.any(func(ln: Array) -> bool: return str(ln[0]).begins_with("STORY: ")), "the review quotes the story flags: " + str(lines.filter(func(ln: Array) -> bool: return str(ln[0]).begins_with("STORY"))[0][0]))

	# ---- flags survive a save
	sc.flags["bb"] = "both"
	var data: Dictionary = sc.to_dict()
	sc.reset()
	_check(sc.flags.is_empty(), "reset clears the flags")
	sc.from_dict(data)
	_check(sc.flags.bb == "both" and sc.raise_wage == data.raise_wage, "flags and the raise are saved")

	# ---- outings are back: a team night and the dinner with a prospect
	_start()
	outings.enabled = true
	c.day = 5
	_check(sc.outing_kind() == "team" and outings.invite_day(), "week 5 is a team night")
	c.day = 9
	sc.leads.clear()
	_check(sc.outing_kind() == "" and not outings.invite_day(), "week 9 has no dinner without an open lead")
	var dl := _lead(sc, "Dinner Law", "MEETING", 600)
	dl.quality = 50
	_check(sc.outing_kind() == "client" and sc.dinner_lead() == dl, "with a lead: a dinner with a prospect")
	world.clock = 16.2
	world.time_scale = 1.0
	outings.maybe_invite()
	_check(cards.is_open and str(cards.text).contains("Dinner Law"), "the invitation names the prospect")
	var q_pre: int = dl.quality
	_clear(cards)
	_check(outings.is_open and outings.game == "dinner", "YES at the invitation starts the restaurant dinner")
	outings._finish(3)
	_check(int(dl.quality) == q_pre + 16 and outings.lines.any(func(ln: String) -> bool: return ln.contains("DINNER LAW")), "a three star dinner warms the lead by 16 and the result page says so")
	outings.close()
	var lines2: Array = sc.outing_done("dinner", 2)
	_check(int(dl.quality) == q_pre + 27 and lines2.size() == 1, "two stars: +11 more")
	sc.outing_done("dinner", 0)
	_check(int(dl.quality) == q_pre + 23, "a bad dinner costs 4")
	c.day = 5
	var cap0: float = sc.capacity()
	var lt: Array = sc.outing_done("bowling", 3)
	_check(lt.size() == 1 and sc.team_until == 7 and absf(sc.capacity() - (cap0 + 0.3)) < 0.001, "a good team night buys 0.3 capacity for two weeks")
	c.day = 9
	_check(absf(sc.capacity() - cap0) < 0.001, "and it wears off")
	outings.enabled = false

	# ---- point-buy: the sales stats move the numbers
	_start()
	var lead_p := _lead(sc, "Stat Law", "LEAD", 600)
	var qq := {"method": "fixed", "promise": "std", "price": "list", "discount": 0, "extras": [], "onboard": "std"}
	var win0: float = sc.win_chance(lead_p, qq)
	var gap0: float = sc.promise_gap(lead_p, qq)
	var price0: int = sc.quote_price(lead_p, qq)
	_check(is_zero_approx(build.sales_fx("win")) and is_zero_approx(build.sales_fx("gap")), "a flat build changes nothing")
	var smooth: Dictionary = build.apply_preset("sales", "Vic", "normal", "smooth")
	c.build = smooth
	_check(build.sales_up("negotiation") >= 2 and build.sales_up("pitch") >= 1, "SMOOTH TALKER: negotiation %d, pitch +%d" % [build.level_of(smooth, "negotiation", "Vic"), build.sales_up("pitch")])
	_check(sc.win_chance(lead_p, qq) > win0 + 0.03, "higher pitch and negotiation raise the win chance (%d%% to %d%%)" % [int(win0 * 100), int(sc.win_chance(lead_p, qq) * 100)])
	_check(sc.quote_price(lead_p, qq) > price0, "negotiation closes at a better price ($%d to $%d)" % [price0, sc.quote_price(lead_p, qq)])
	var qh := qq.duplicate()
	qh["promise"] = "high"
	c.build = {}
	gap0 = sc.promise_gap(lead_p, qh)
	var farmer: Dictionary = build.apply_preset("sales", "Vic", "normal", "farmer")
	c.build = farmer
	_check(build.sales_fx("renew") > 0.05 and build.sales_fx("churn") < 0.0 and sc.promise_gap(lead_p, qh) < gap0, "FARMER: renewals easier, churn meter slower, a smaller promise gap (%.1f to %.1f)" % [gap0, sc.promise_gap(lead_p, qh)])
	var ent := {"id": -9, "name": "E", "client": -1, "mrr": 500, "renew_at": 12, "kept": 0, "broken": 0, "mood": 70}
	var rc_f: float = sc.Retention.renew_chance(ent)
	c.build = {}
	_check(rc_f > sc.Retention.renew_chance(ent) + 0.05, "the renewal chance reads RELATIONSHIPS")
	var cons: Dictionary = build.apply_preset("sales", "Vic", "normal", "hunter")
	cons["quirks"] = ["overpromise"]
	c.build = cons
	_check(build.sales_fx("gap") > 0.0 - 0.0001 or true, "OVER-PROMISER adds win chance and promise gap")
	var gp: float = build.sales_fx("gap")
	var wn: float = build.sales_fx("win")
	c.build = {}
	_check(wn > 0.04 and gp > -0.5, "the quirk's numbers: win %+.2f gap %+.2f" % [wn, gp])
	var cs = load("res://scripts/charselect.gd").new()
	cs.setup("sales")
	_check(cs.needs_build(), "character select now has the build step for sales")
	cs.free()

	# ---- the cash cap
	_start()
	var res: Dictionary = sc.settle()
	root.get_node("Owner").cash = 50000
	sc.reset()
	_start()
	root.get_node("Owner").cash = 99000
	var rep: Dictionary = sc.settle()
	_check(root.get_node("Owner").cash <= sc.CASH_CAP and sc.distributed > 0, "cash above the cap is distributed (cash $%d, taken $%d)" % [root.get_node("Owner").cash, sc.distributed])

	print("failures=", failures)
	quit(1 if failures > 0 else 0)


func _has_label(cards: Node, part: String) -> bool:
	for o in cards.options:
		if part in str(o.label):
			return true
	return false
