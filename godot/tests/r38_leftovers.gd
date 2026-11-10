extends SceneTree
# gdlint:disable=max-line-length
# R38 small leftovers: H9 cuts the overnight job failures (8 -> 6 percent), H3 halves the overrun of the failed cutover (the migration
# card), the default password finding of the walk-around until H14 covers the site, the TESTED date on the RMM BACKUPS tab, and the
# consumer of the Hollis favour flag (sales week 14: a warm lead).

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(0)
		n += 1
	cards._queue.clear()


func _owner_game(c: Node, cards: Node, day: int) -> void:
	c.new_game("owner")
	_clear(cards)
	c.day = day


func _fresh(h: Script, o: Node, c: Node, id: String) -> void:
	h.adopt(id)
	h.touch(id)
	o.habits[id]["last"] = c.day


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	var msp := root.get_node("Msp")
	var onsite := root.get_node("Onsite")
	var h: Script = load("res://scripts/habits.gd")
	var inc: Script = load("res://scripts/incident.gd")
	var comp: Script = load("res://scripts/computer.gd")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- H9: the overnight job failure rate
	_owner_game(c, cards, 8)
	_check(h.night_mult() == 1.0 and is_equal_approx(inc.backup_fail_chance(), 0.08), "without H9 a backup fails overnight 8 percent of the time")
	_check(h.act("H9") != "" and h.fresh("H9"), "H9 is done from the HABITS tab")
	_check(is_equal_approx(h.night_mult(), 0.75) and is_equal_approx(inc.backup_fail_chance(), 0.06), "with H9 fresh: 6 percent")
	# measured: 4000 nights with and without the habit, the same stream
	var fails := [0, 0]
	for pass_i in 2:
		if pass_i == 1:
			o.habits.erase("H9")
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 4000:
			if rng.randf() < inc.backup_fail_chance():
				fails[pass_i] += 1
	print("MEASURE overnight failures in 4000 nights: with H9 %d, without %d" % fails)
	_check(fails[0] < fails[1] and fails[0] > 180 and fails[1] < 400, "fewer nights fail with H9 (about 240 against 320)")

	# ---- H3: the failed cutover costs half
	_owner_game(c, cards, 8)
	var cash0: int = o.cash
	o.apply({"cash": 1800, "overrun": 1200})
	_check(o.cash == cash0 + 1800 and h.overrun_back(1200) == 0, "without H3 the overrun of the migration is eaten in full ($1,200)")
	_fresh(h, o, c, "H3")
	_check(h.fresh("H3"), "H3 adopted")
	cash0 = o.cash
	o.apply({"cash": 1800, "overrun": 1200})
	_check(o.cash == cash0 + 1800 + 600, "with a change request on file the failed cutover costs half ($600 back)")
	var row: Array = o.CARDS.migration.options[0].roll[1]
	_check(int(row[1].get("overrun", 0)) == 1200 and int(o.CARDS.migration.options[0].roll_scoped[1][1].get("overrun", 0)) == 600, "the migration card's two overrun rows carry what was eaten")
	cash0 = o.cash
	o.apply({"cash": 3000, "rep": 1})
	_check(o.cash == cash0 + 3000, "a smooth job pays the same as before")

	# ---- H14: the default password walk-around finding
	_owner_game(c, cards, 8)
	var client := int(sales.active[0])
	var other := int(sales.active[1])
	_check(h.default_pw(client) and h.default_pw(other), "an owner's client still has default passwords")
	onsite.client = client
	onsite.visit_kind = ""
	onsite._inspected.clear()
	onsite.inspect("printer")
	_check(cards.is_open and cards.text == str(h.TEXT.pw_text), "inspecting the printer finds them (a card)")
	var open0: int = msp.tickets.size()
	cards.pick(0)  # LOG A TICKET
	_check(msp.tickets.size() == open0 + 1 and str(msp.tickets[-1].summary) == str(h.TEXT.pw_summary), "LOG A TICKET makes the ticket")
	_clear(cards)
	_check(not h.default_pw(client), "the finding comes once per client")
	_fresh(h, o, c, "H14")
	h.act("H14")
	h.act("H14")
	var sites: Array = o.habits.H14.get("sites", [])
	_check(sites.size() >= 1, "H14 changes the passwords site by site (%d done)" % sites.size())
	var done := int(sites[0])
	o.flags.erase("pw_seen")
	_check(not h.default_pw(done), "a site whose passwords were changed has no finding")
	c.mode = "tech"
	_check(not h.default_pw(other), "the finding is an owner campaign thing")
	c.mode = "owner"
	onsite.client = -1

	# ---- the TESTED date on the RMM BACKUPS tab
	_owner_game(c, cards, 9)
	client = int(sales.active[0])
	msp.backups[client].ok = true
	_check(comp.backup_status("OK - LAST GOOD: TODAY", msp.backups[client], false) == "OK - LAST GOOD: TODAY", "an untested backup row reads as before")
	h.act("H1")
	_check(int(msp.backups[client].get("tested", -1)) == 9, "a restore test stamps the client's backup row")
	_check(comp.backup_status("OK - LAST GOOD: TODAY", msp.backups[client], false) == "OK - LAST GOOD: TODAY - TESTED WK 9", "the row shows TESTED WK 9")
	_check(comp.backup_status("OK - LAST GOOD: TODAY", msp.backups[client], true) == "OK - TESTED WK 9", "the compact row drops LAST GOOD to fit")
	_check(comp.backup_status("FAILED! LAST GOOD: 2 DAYS AGO", msp.backups[client], true) == "FAILED! - TESTED WK 9", "also on a failed row")
	c.save()
	msp.backups[client].erase("tested")
	c.continue_game("owner")
	_clear(cards)
	_check(int(msp.backups[client].get("tested", -1)) == 9, "the date is saved")

	# ---- the Hollis favour (sales, week 14)
	var sc := root.get_node("SalesCampaign")
	var sr: Script = load("res://scripts/sales_rival.gd")
	player_script.current_character = "office_john"
	root.get_node("Difficulty").seed_run(4242)
	c.new_game("sales")
	_clear(cards)
	_check(sr.WEEKS.get(14, "") == "favour" and sc.BEAT_TEXT.has("favour"), "week 14 is the favour beat, with its text")
	c.day = 14
	var n0: int = sc.leads.size()
	sr.week(14)
	_check(not cards.is_open and sc.leads.size() == n0 and str(sc.flags.get("favour", "")) == "none", "no favour owed: nothing happens")
	for l in sc.leads:
		l.stage = "LOST"
	sr._plumb_pick("honest")
	_clear(cards)
	_check(bool(sc.flags.get("hollis_favour", false)), "sending Ms. Cedar back sets the favour")
	n0 = sc.leads.size()
	sr.week(14)
	_check(cards.is_open and cards.speaker == "Hollis Grady", "Hollis rings in week 14")
	_clear(cards)
	var got: Dictionary = sc.leads[-1] if sc.leads.size() == n0 + 1 else {}
	_check(not got.is_empty() and str(got.name) == "Tidewater Title" and int(got.quality) == sr.FAVOUR_QUALITY and sc.is_open(got), "he passes on a warm lead")
	_check(str(got.get("incumbent", "")) == "none" and not bool(sc.flags.get("hollis_favour", true)) and str(sc.flags.favour) == "lead", "nobody to displace, and the favour is spent")
	sr.week(14)
	_check(not cards.is_open and sc.leads.size() == n0 + 1, "it pays once")
	# a full pipeline: he keeps you in mind, a point of conscience instead
	sc.flags["hollis_favour"] = true
	while sc.open_leads().size() < sc.MAX_OPEN:
		var filler: Dictionary = load("res://scripts/sales_beats.gd").story_lead("Filler %d" % sc.leads.size(), "law", "Atty. Test", 10, "x", 40)
		sc.leads.append(filler)
	n0 = sc.leads.size()
	sr.beat_favour()
	_check(cards.is_open and sc.leads.size() == n0 and str(sc.flags.favour) == "full", "with a full pipeline there is no lead, only the call")
	_clear(cards)

	print("r38_leftovers: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
