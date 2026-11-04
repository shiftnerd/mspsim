extends SceneTree
# R37: the post-incident review (blameless post-mortem). Tech: Morgan runs a short card chain after the ransomware,
# the rack, the email night and the wire fraud (what happened, the root cause, up to two action items); skipping costs
# a little with Morgan; the items change odds elsewhere (backups, fix failures, ticket volume, the invoice scam).
# Owner: a lessons-learned card per incident class (hours, morale, cash), counted as a maturity practice.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _strings(v: Variant, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Dictionary:
		for k in v:
			_strings(v[k], out)
	elif v is Array:
		for x in v:
			_strings(x, out)


func _clear(cards: Node, choice := 0) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(choice if choice < cards.options.size() else 0)
		n += 1


# picks an option by id (the card options carry the ids of the chain)
func _pick_id(cards: Node, id: String) -> bool:
	for i in cards.options.size():
		if str(cards.options[i].get("id", "")) == id:
			cards.pick(i)
			return true
	return false


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var skills := root.get_node("Skills")
	var msp := root.get_node("Msp")
	var growth := root.get_node("Growth")
	var o := root.get_node("Owner")
	var inc: Script = load("res://scripts/incident.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- the table
	var pms: Dictionary = story.POSTMORTEMS
	_check(pms.size() == 4, "four incident classes have a review")
	var effs := ["backups", "fixes", "pace", "check", "calm", "xp", "mood"]
	for cls in ["ransom", "rack", "email", "bec"]:
		var pm: Dictionary = pms[cls]
		var right := 0
		for cause in pm.causes:
			right += 1 if bool(cause.get("right", false)) else 0
		_check((pm.causes as Array).size() == 3 and right == 1, "%s: three causes, one of them right" % cls)
		var ok_items := (pm.items as Array).size() == 4
		for item in pm.items:
			ok_items = ok_items and effs.has(str(item.eff))
		_check(ok_items, "%s: four action items with known effects" % cls)
		_check(["security", "networking", "servers"].has(str(pm.skill)), "%s: trains a skill" % cls)
	var texts: Array = []
	_strings(pms, texts)
	var low := ""
	var glyphs: Dictionary = load("res://scripts/pixelfont.gd").GLYPHS
	var odd := ""
	for t in texts:
		low += " " + str(t).to_lower()
		for ch in str(t).to_upper():
			if ch != "{" and ch != "}" and not glyphs.has(ch):
				odd += ch
	for bad in ["mfa ", " ai ", "chatgpt", "slack", "microsoft 365", "office 365", "windows 10", "teams"]:
		_check(not low.contains(bad), "no %s in the reviews" % bad.strip_edges())
	_check(odd == "", "the reviews use only letters the 3x5 font has: '%s'" % odd)

	# ---- on the calendar (tech) and in the weeks (owner)
	var days := {}
	for day in story.DAYS:
		for ev in story.DAYS[day]:
			if str(ev.get("kind", "")) == "postmortem":
				days[str(ev.cls)] = int(day)
	_check(days == {"bec": 11, "rack": 11, "ransom": 12, "email": 15}, "tech reviews follow their incidents: %s" % str(days))
	var weeks := {}
	for week in o.DAYS:
		for ev in o.DAYS[week]:
			if str(ev.get("card", "")).begins_with("pm_"):
				weeks[str(ev.card)] = int(week)
	_check(weeks == {"pm_ransom": 11, "pm_rack": 11, "pm_email": 15}, "owner reviews follow their incidents: %s" % str(weeks))
	_check(o.CARDS.has("pm_bec"), "the wire fraud review is queued after a loss")

	# ---- tech: the full chain, two items
	c.new_game("tech")
	_clear(cards)
	story.flags["ransom"] = "saved"
	var morgan0: int = social.value("Morgan")
	var clock0: float = root.get_node("World").clock
	var xp0: int = int(skills.xp.get("security", 0))
	inc.tech_start("ransom")
	_check(cards.is_open and cards.speaker.contains("Morgan") and cards.text.contains("blameless"), "Morgan opens a blameless review")
	_check(cards.options.size() == 2, "go or skip")
	cards.pick(0)
	_check(cards.options.size() == 3 and cards.text.contains("root cause"), "step 2: the root cause")
	_pick_id(cards, "backups")
	_check(cards.options.size() == 4 and cards.text.contains("first thing"), "step 3: four action items")
	_check(int(skills.xp.get("security", 0)) > xp0, "the right cause teaches something")
	_pick_id(cards, "backup_verify")
	_check(cards.options.size() == 4 and cards.options[3].label.contains("ENOUGH"), "step 4: three left plus enough")
	_pick_id(cards, "runbook")
	_check(cards.is_open and cards.text.contains("Morgan photographs"), "the review closes with a summary")
	cards.pick(0)
	_check(story.flags.pm_ransom == "done" and story.flags.get("pm_backup_verify", false) and story.flags.get("pm_runbook", false), "both items are recorded")
	_check(story.flags.get("pm_eff_backups", false) and story.flags.get("pm_eff_fixes", false), "and their effects")
	_check(social.value("Morgan") > morgan0, "Morgan thinks better of you")
	_check(root.get_node("World").clock > clock0, "the review takes half an hour")
	_check(inc.backup_fail_chance() == 0.04 and msp.Incident.backup_fail_chance() == 0.04, "backups fail half as often overnight")
	_check(inc.fix_bonus() < 0.0 and growth.fail_adjust("restore") < 0.0, "fixes fail a little less often")
	_check(inc.ticket_gap() == 1.0, "patch policy was not picked: tickets unchanged")
	inc.tech_start("ransom")
	_check(not cards.is_open, "one review per incident class")

	# ---- tech: skip costs a little, one item is enough, the wrong cause is not blamed on a person
	c.new_game("tech")
	story.flags["rack"] = "B"
	morgan0 = social.value("Morgan")
	inc.tech_start("rack")
	_pick_id(cards, "skip")
	_check(cards.is_open and story.flags.pm_rack == "skip", "skipping is recorded")
	cards.pick(0)
	_check(social.value("Morgan") == morgan0 - 2, "skipping costs 2 with Morgan")
	_check(inc.backup_fail_chance() == 0.08 and inc.ticket_gap() == 1.0, "a skipped review changes nothing")

	story.flags["email24"] = "A"
	morgan0 = social.value("Morgan")
	inc.tech_start("email")
	_pick_id(cards, "go")
	_pick_id(cards, "person")
	_check(social.value("Morgan") == morgan0 - 1, "naming a person in a blameless review costs 1")
	_check(not story.flags.has("pm_cause"), "the wrong cause gives no credit")
	_pick_id(cards, "disk_alerts")
	_pick_id(cards, "enough")
	_check(cards.is_open, "closing summary")
	cards.pick(0)
	_check(story.flags.pm_email == "done" and story.flags.get("pm_disk_alerts", false) and not story.flags.get("pm_status_template", false), "one item is enough")
	_check(inc.ticket_gap() == 1.05, "disk alerts: five percent fewer tickets")

	# ---- tech: waits for its incident (Year 2 moves the big jobs around)
	c.new_game("tech")
	inc.tech_start("bec")
	_check(not cards.is_open and (story.flags.pm_wait as Array).has("bec"), "no wire fraud yet: the review waits")
	inc.tech_morning()
	_check(not cards.is_open, "still waiting")
	story.flags["ceofraud"] = "A"
	inc.tech_morning()
	_check(cards.is_open and cards.text.contains("wire"), "the morning after the incident the review opens")
	_pick_id(cards, "go")
	_pick_id(cards, "process")
	_pick_id(cards, "wire_check")
	_pick_id(cards, "enough")
	cards.pick(0)
	_check(story.flags.get("pm_eff_check", false) and (story.flags.pm_wait as Array).is_empty(), "wire check recorded, wait list empty")

	# the lesson pays off: Brightside's landlord email
	var inv: Dictionary = story.VIGNETTES.invoice
	var shown := ""
	story._vignette("invoice")
	shown = cards.text
	_check(shown.contains("call-back") or shown.contains("never sent it"), "with the rule the bookkeeper called back")
	_check(cards.options.size() == 2, "the checked version has its own two answers")
	cards.pick(0)
	_clear(cards)
	c.new_game("tech")
	_clear(cards)
	story._vignette("invoice")
	_check(cards.text.contains("Should I just do it") and cards.options.size() == 3, "without the rule she asks what to do")
	cards.pick(2)
	_check(cards.text.contains("Friday"), "paying the fake rent hurts")
	cards.pick(0)
	_check(str(inv.speaker).contains("Karen") and int(days.get("bec", 0)) < 17, "the review comes before day 17's invoice")
	var d17 := false
	for ev in story.DAYS[17]:
		d17 = d17 or str(ev.get("id", "")) == "invoice"
	_check(d17, "the invoice email is on day 17")

	# ---- owner: the lessons-learned cards
	c.new_game("owner")
	_clear(cards)
	c.day = 11
	var cash0: int = o.cash
	var practices0: int = o.practices()
	o.show_card("pm_ransom")
	_check(cards.text.contains("CryptoLocker") and cards.options.size() == 3, "pm_ransom: hold it (two ways) or skip it")
	cards.pick(0)
	_clear(cards)
	_check(o.flags.pm_ransom == "runbook" and o.flags.get("practice_postmortem", false), "pm_ransom: held, recorded and a practice")
	_check(o.practices() == practices0 + 1 and o.cash == cash0, "it is a maturity practice and the runbook costs no cash")
	_check(growth.owner_used >= 6.0, "it takes the owner's hours")
	_check(inc.lesson_mult("ransom") == 0.6, "the same class of incident is 40% less likely")
	c.new_game("owner")
	_clear(cards)
	cash0 = o.cash
	var weekly0: int = o.weekly_extra
	o.show_card("pm_ransom")
	cards.pick(1)
	_clear(cards)
	_check(o.cash == cash0 - 250 and o.weekly_extra == weekly0 + 15 and o.flags.pm_ransom == "check", "the restore test costs $250 and $15 a week")
	_check(inc.lesson_mult("ransom") == 0.5, "the check variant is stronger")
	c.new_game("owner")
	_clear(cards)
	var burn0: float = o.burnout
	var mood0: int = social.value("Dan")
	o.show_card("pm_ransom")
	cards.pick(2)
	_clear(cards)
	_check(o.flags.pm_ransom == "skip" and not o.flags.get("practice_postmortem", false), "skipped: no practice")
	_check(o.burnout > burn0 and social.value("Dan") < mood0, "skipping costs morale")
	_check(inc.lesson_mult("ransom") > 1.0, "and repeats the mistake: the next break-in is more likely")
	# the RDP exposure follows the lesson
	var hits := {"skip": 0, "runbook": 0}
	for how in hits:
		c.new_game("owner")
		_clear(cards)
		c.day = 8
		o.flags["pm_ransom"] = how
		seed(99)
		for i in 400:
			var before: int = o.incidents
			o._rdp_week()
			_clear(cards)
			hits[how] += o.incidents - before
	_check(hits.skip > hits.runbook, "break-ins: %d after a skipped review, %d after a held one" % [hits.skip, hits.runbook])
	# the rack review speeds the crew a little
	c.new_game("owner")
	_clear(cards)
	var speed0: float = o.speed
	o.show_card("pm_rack")
	cards.pick(0)
	_clear(cards)
	_check(o.speed > speed0, "pm_rack: a labelled rack is quicker to fix")
	# the email night review cuts the vendor breach odds
	c.new_game("owner")
	_clear(cards)
	o.flags["pm_email"] = "runbook"
	_check(inc.lesson_mult("email") < 1.0, "pm_email: the vendor breach is less likely")
	# the wire fraud review cuts the exposure
	c.new_game("owner")
	_clear(cards)
	o.flags["card_bec_scare"] = 0
	var e0: float = inc.exposure()
	cash0 = o.cash
	o.show_card("pm_bec")
	cards.pick(1)
	_clear(cards)
	_check(inc.exposure() < e0 * 0.6 and o.flags.pm_bec == "check", "pm_bec: two-factor login halves the exposure")
	_check(o.cash == cash0 - 300, "pm_bec costs $300")

	# ---- saving
	var dict: Dictionary = o.to_dict()
	_check((dict.flags as Dictionary).get("pm_bec", "") == "check", "the review is in the save")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
