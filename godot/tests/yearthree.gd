extends SceneTree
# gdlint:disable=max-line-length
# Year 3, the last chapter (roadmap R10, scripts/yeartwo.gd). A Year 2 run still reads exactly the Year 2 tables; START YEAR 3
# opens after a finished Year 2 (and for an old meta file); in each of the four campaigns a Year 3 run starts from the Year 2
# record, runs the tighter clock, fires its three beat cards on their days (with the Lynk line), every ending is offered by
# the review after the right answers, reads its epilogue, is recorded and earns its medal plus THIRD YEAR; a Year 3 save
# comes back; an old Year 2 save and a save without a year load as before; the calendar stays where Year 2 left it.
# The whole-year proof (a careful bot finishes Year 3 in every campaign) is tests/bot_year3.gd, a dev run.
# Headless; saves in user://test_*.

const MODES := ["tech", "owner", "service", "sales"]
# ending -> the answers that open it: {beat: option id}
const ROUTES := {
	"tech": {
		"y3_chair": {"newhire": "wing", "mentor": "teach", "fork": "chair"},
		"y3_senior": {"newhire": "no", "mentor": "fix", "fork": "tech"},
		"y3_farewell": {"newhire": "notes", "mentor": "report", "fork": "go"},
	},
	"owner": {
		"y3_summit": {"summit": "listen", "staff": "no", "handover": "no"},
		"y3_staff": {"summit": "no", "staff": "yes", "handover": "no"},
		"y3_morgan": {"summit": "no", "staff": "no", "handover": "trial"},
	},
	"service": {
		"y3_coo": {"deputy": "train", "terry": "no", "table": "ops"},
		"y3_partner": {"deputy": "write", "terry": "told", "table": "partner"},
		"y3_across": {"deputy": "train", "terry": "hear", "table": "think"},
	},
	"sales": {
		"y3_director": {"wes": "coach", "split": "fair", "chair": "chair"},
		"y3_wes": {"wes": "coach", "split": "keep", "chair": "wes"},
		"y3_stake": {"wes": "script", "split": "cold", "chair": "stake"},
	},
}

var failures := 0
var c: Node
var y: Node
var cards: Node
var review: Node
var career: Node
var story: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> Dictionary:
	var seen := {}  # speaker -> text of every card that was waiting (the campaign's own first cards may come before ours)
	var n := 0
	while cards.is_open and n < 40:
		seen[str(cards.speaker)] = str(cards.text)
		cards.pick(0)
		n += 1
	return seen


# a meta file as a finished Year 2 run leaves it
func _write_meta(mode: String, ending := "stay", with_snap := true) -> void:
	var meta := ConfigFile.new()
	meta.load(y.meta_path())
	var skills := {}
	for key in root.get_node("Skills").NAMES:
		skills[key] = 4
	var rec := {"ending": ending, "rep": 80, "tier": "normal", "cozy": false, "seed": 5, "clients": 9, "skills": skills, "value": 240000, "cash": 30000, "trust": 66, "shop": [], "standard": 0}
	for key in rec:
		meta.set_value(mode, key, rec[key])
	meta.set_value(mode, "finished", 2)
	meta.set_value(mode, "year", 2)
	if with_snap:
		var snap: Dictionary = rec.duplicate(true)
		snap["flags"] = {"courted": "told", "director": "take"}
		meta.set_value(mode, "y2", snap)
		meta.set_value(mode, "top_year", 2)
	meta.save(y.meta_path())


func _start(mode: String, year: int) -> void:
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	y.begin_select(mode, year >= 2, maxi(2, year))
	c.new_game(mode)


func _option(id: String) -> int:
	for i in cards.options.size():
		if str(cards.options[i].get("id", "")) == id:
			return i
	return -1


func _ids() -> Array:
	return review.offers.map(func(x: Dictionary) -> String: return str(x.id))


# good standing in every campaign, so that only the answers decide which ending is offered
func _good_standing(mode: String) -> void:
	c.rep = 80
	root.get_node("Social").change_all(10)
	if mode == "owner":
		root.get_node("Owner").cash = 20000
	if mode == "service":
		root.get_node("Service").trust = {"Alan": 70, "Garrison": 70}


func _init() -> void:
	await process_frame
	c = root.get_node("Campaign")
	y = root.get_node("Yeartwo")
	cards = root.get_node("Cards")
	review = root.get_node("Review")
	career = root.get_node("Career")
	story = root.get_node("Story")
	var mu := root.get_node("Mutators")
	var sales := root.get_node("Sales")
	var lync := root.get_node("Lync")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_y3_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	career.toasts = false
	career.counters = {}
	career.earned = {}
	DirAccess.remove_absolute(y.meta_path())
	diff.seed_run(2014)

	# ---- the tables: Year 3 has a row for every mode, every beat has its card, every ending its offer, epilogue, threshold and medal
	for m in MODES:
		var beats: Dictionary = y.YEAR3.beats.get(m, {})
		var ok := beats.size() == 3
		for id in beats:
			var row: Dictionary = y.TEXT3.beats.get(m, {}).get(id, {})
			ok = ok and str(row.get("speaker", "")) != "" and str(row.get("text", "")) != "" and (row.get("options", []) as Array).size() >= 2
			ok = ok and int(beats[id]) >= 2 and int(beats[id]) <= 19
			for o in row.get("options", []):
				ok = ok and str(o.get("reply", "")) != "" and str(o.label).length() <= 40
		_check(ok, "%s: three Year 3 beats with a card, replies and a day inside the year" % m)
		var ends: Array = y.YEAR3.endings.get(m, [])
		ok = ends.size() == 3 and (ROUTES[m] as Dictionary).keys() == ends
		for id in ends:
			ok = ok and y.TEXT3.offers.has(id) and y.TEXT3.endings.has(id) and y.YEAR3.needs.has(id) and y.is_year3_ending(str(id)) and y.is_year2_ending(str(id))
			ok = ok and not career.medal(str(id)).is_empty() and not root.get_node("Review").EPILOGUES.has(id)
		_check(ok, "%s: three Year 3 endings with offer, epilogue, threshold and medal %s" % [m, str(ends)])
	_check(not career.medal("year_three").is_empty() and str(career.medal("year_three").title) == "THIRD YEAR", "the THIRD YEAR medal exists")
	_check(not y.is_year3_ending("head") and y.is_year2_ending("head") and not y.is_year2_ending("stay"), "Year 2's endings are still Year 2's")

	# ---- a Year 2 run reads what it always read
	_check(y.label(1) == "" and y.label(2) == "YEAR 2" and y.label(3) == "YEAR 3" and y.tag_of(1) == "" and y.tag_of(2) == " (YEAR 2)" and y.tag_of(3) == " (YEAR 3)", "labels and save tags per year")
	var first := ConfigFile.new()
	first.set_value("tech", "ending", "stay")  # a meta file from before R10b: only the ending
	first.save(y.meta_path())
	_check(y.available("tech") and y.available("tech", 2) and not y.available("tech", 3), "a finished first year opens Year 2, not Year 3")
	_check(y.menu_items().map(func(i: Dictionary) -> String: return str(i.id)) == ["tech_y2"] and y.menu_items(3).is_empty(), "one NEW GAME PLUS row")
	_start("tech", 3)
	_check(c.year == 1 and not y.active(), "START YEAR 3 cannot be forced without a finished Year 2 (year %d)" % c.year)
	_start("tech", 2)
	_check(c.year == 2 and y.active() and y.year_cfg("sla") == y.YEAR2.sla and y.year_cfg("beats") == y.YEAR2.beats and y.year_txt("beats") == y.TEXT.beats, "a Year 2 run reads the Year 2 tables")
	_check(is_equal_approx(y.sla_mult(), 0.85) and is_equal_approx(mu.sla(100.0), 85.0 * diff.cm("sla") * diff.sla_scale() * float(mu.hook("sla_mult", 1.0))), "Year 2 clocks are 15 percent tighter, as before (%.3f)" % y.sla_mult())
	_check(cards.is_open and str(cards.speaker) == "YEAR 2", "Year 2 still opens with the YEAR 2 card")
	_drain()
	y.beat("courted")
	_check(cards.is_open and str(cards.speaker) == "Tony Marsh (Iron Mule Demolition)", "the Year 2 beat is still Tony's")
	cards.pick(0)
	_drain()
	_check(str(story.flags.get("y2", {}).get("courted", "")) == "listen" and not story.flags.has("y3"), "its answer is kept under y2")
	y.beat("newhire")
	_check(not cards.is_open, "a Year 3 beat does nothing in a Year 2 run")
	y.set_flag("fork", "tech")
	c.rep = 90
	review.offers = review.make_offers()
	_check(not _ids().has("y3_senior") and _ids().has("clientbuy"), "the Year 2 review offers Year 2's endings only %s" % str(_ids()))
	var sect: Dictionary = y.to_dict()
	_check(sect.keys() == ["version", "moves", "carried", "pick", "ban", "prev"] and int(sect.version) == 1, "the saved yeartwo section has the same keys and version as before")

	# ---- unlock: finishing that Year 2 run opens Year 3 and keeps the run's own record
	var meta := ConfigFile.new()
	meta.load(y.meta_path())
	y.record(meta, "tech", "clientbuy")
	meta.save(y.meta_path())
	var rec: Dictionary = y.meta_get("tech")
	_check(int(rec.year) == 2 and int(rec.top_year) == 2 and rec.get("y2", {}) is Dictionary and str(rec.y2.ending) == "clientbuy" and str(rec.y2.flags.get("courted", "")) == "listen", "the finished Year 2 is kept under y2 with its answers, top_year 2")
	_check(y.available("tech", 3) and not y.available("tech", 4) and not y.available("owner", 3), "START YEAR 3 is open for that campaign only, and there is no Year 4")
	_check(career.value("year2_done") == 1 and career.value("year3_done") == 0 and career.has_medal("year_two") and not career.has_medal("year_three"), "SECOND YEAR earned, THIRD YEAR not yet")
	# a first year played again afterwards does not lock Year 3, and Year 3 still follows the Year 2 run
	c.year = 1
	c.rep = 51
	meta = ConfigFile.new()
	meta.load(y.meta_path())
	y.record(meta, "tech", "stay")
	meta.save(y.meta_path())
	rec = y.meta_get("tech")
	_check(int(rec.year) == 1 and int(rec.top_year) == 2 and y.available("tech", 3), "a first year finished later leaves START YEAR 3 open")
	_check(int(y.record_for("tech", 3).rep) == 90 and int(y.record_for("tech", 2).rep) == 51, "Year 3 carries from the Year 2 run (rep 90), Year 2 from the last run (rep 51)")
	_check(y.carry_summary("tech", 3).begins_with("REP 54") and y.carry_summary("tech").begins_with("REP 40"), "the title rows say so: %s / %s" % [y.carry_summary("tech", 3), y.carry_summary("tech")])
	# an old meta file whose last finished run was a Year 2 (no top_year, no y2)
	DirAccess.remove_absolute(y.meta_path())
	_write_meta("owner", "franchise", false)
	_check(y.available("owner", 3) and str(y.record_for("owner", 3).ending) == "franchise", "an old record of a finished Year 2 opens Year 3 and is what it carries from")
	_check(y.menu_items().map(func(i: Dictionary) -> String: return str(i.id)) == ["owner_y2"] and y.menu_items(3).map(func(i: Dictionary) -> String: return str(i.id)) == ["owner_y3"], "both rows are listed")

	# ---- the title menu row
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	await process_frame
	var title := current_scene
	var rows: Array = title.sub_items("owner")
	_check(rows.map(func(i: Dictionary) -> String: return str(i.id)) == ["owner_y2", "owner_y3", "owner_new"], "the owner submenu: START YEAR 2, START YEAR 3, NEW CAMPAIGN")
	_check(str(rows[1].label).begins_with("START YEAR 3 - REP ") and str(rows[1].label).contains("TRUST 66"), "the Year 3 row carries the summary: %s" % str(rows[1].label))
	_check(title.sub_items("tech").map(func(i: Dictionary) -> String: return str(i.id)) == ["tech_new"], "a campaign nobody finished has neither row")
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "day", 7)
	cfg.set_value("campaign", "year", 3)
	cfg.save(c.save_path("owner"))
	_check(str(c.slot_info("owner", 1).tag) == " (YEAR 3)" and str(title.sub_items("owner")[0].label).contains("WEEK 7 (YEAR 3)"), "a Year 3 save shows the tag: %s" % str(title.sub_items("owner")[0].label))
	DirAccess.remove_absolute(c.save_path("owner"))
	title._slot = 1
	title._open_select("owner_y3")
	await process_frame
	_check(title._select != null and y.pending and y.pending_year == 3 and title._select.summary().contains("YEAR 3"), "the row opens the character select for Year 3: %s" % (title._select.summary() if title._select != null else "-"))
	_check(root.get_node("Build").budget("normal") == 14, "with the two extra build points")
	y.pending = false

	# ---- each campaign: start Year 3, the beats on their days, every ending
	var intro_seen := false
	for m in MODES:
		for ending in ROUTES[m]:
			DirAccess.remove_absolute(y.meta_path())
			_write_meta(m, "leave" if m == "service" else "stay")
			_start(m, 3)
			var route: Dictionary = ROUTES[m][ending]
			if ending == (ROUTES[m] as Dictionary).keys()[0]:
				_check(c.year == 3 and y.active() and not y.pending and str(y.prev.get("ending", "")) != "", "%s: a Year 3 run starts from the Year 2 record" % m)
				var day1: Dictionary = _drain()
				_check(str(day1.get("YEAR 3", "")).contains("THIRD YEAR") and not day1.has("YEAR 2"), "%s: the YEAR 3 card is asked on day 1" % m)
				_check(str(day1.get("YEAR 3", "")).contains("PIXEL KEPT YOUR MUG") == (m == "service"), "%s: the card says you came back only when you had left" % m)
				_check(is_equal_approx(y.sla_mult(), float(y.YEAR3.sla.mult)) and y.sla_mult() < 0.85, "%s: the clocks are a notch tighter than Year 2 (%.2f)" % [m, y.sla_mult()])
				_check(y.max_clients(8) == 10 and sales.active.has(y.client_index("Iron Mule Demolition")) and not y.ticket_weights().is_empty(), "%s: the rest of Year 2's difficulty stays on" % m)
				# (the service desk starts every year at its own confidence value: Service.begin_run sets it after the carry-over)
				_check((int(c.rep) == 48 or m == "service") and int(y.carried.rep) == 48 and y.last_flag("director") == "take", "%s: reputation carries over from the Year 2 run (%d) and its answers can be read" % [m, c.rep])
				_check(career.value("year3_runs") >= 1, "%s: the run is counted" % m)
				intro_seen = true
			_drain()
			# the days of the year: a card opens on the three beat days only
			var beats: Dictionary = y.YEAR3.beats[m]
			var fired := []
			for day in range(2, 21):
				var before: int = lync.unread_total()
				y.begin_day(day)
				if not cards.is_open:
					continue
				var id := ""
				for b in beats:
					if int(beats[b]) == day:
						id = str(b)
				var row: Dictionary = y.TEXT3.beats[m].get(id, {})
				if id == "" or str(cards.speaker) != root.get_node("Roles").speaker(root.get_node("Roles").fill(str(row.speaker))):
					_check(false, "%s day %d: an unexpected card from %s" % [m, day, str(cards.speaker)])
					_drain()
					continue
				if row.has("lynk") and lync.unread_total() != before + 1:
					_check(false, "%s %s: the Lynk line came first" % [m, id])
				var at := _option(str(route[id]))
				if at < 0:
					_check(false, "%s %s: option %s is on the card" % [m, id, str(route[id])])
					at = 0
				cards.pick(at)
				if not cards.is_open:
					_check(false, "%s %s: the reply card follows" % [m, id])
				_drain()
				fired.append(id)
			_check(fired == beats.keys() and y.flag(str(beats.keys()[2])) == str(route[beats.keys()[2]]) and (story.flags.get("y3", {}) as Dictionary).size() == 3, "%s %s: all three beats fired on their days, answers kept under y3 %s" % [m, ending, str(story.flags.get("y3", {}))])
			# the review
			c.rep = 30
			review.offers = review.make_offers()
			_check(not _ids().has(ending), "%s %s: not offered to somebody with a reputation of 30" % [m, ending])
			_good_standing(m)
			review.start()
			var ids := _ids()
			var others := 0
			for e in ROUTES[m]:
				if e != ending and ids.has(e):
					others += 1
			_check(ids.has(ending) and others == 0 and (ids.has("stay") or ids.has("left")), "%s %s: the review offers it, next to the usual ones %s" % [m, ending, str(ids)])
			_check(ids.find(ending) < maxi(ids.find("stay"), ids.find("left")), "%s %s: it sits above STAY" % [m, ending])
			review.choose(ids.find(ending))
			var want: String = y.ending_text(ending)
			var read := false
			for ln in review.page_lines():
				read = read or (want != "" and str(ln[0]) == want)
			_check(read and not want.contains("{"), "%s %s: the epilogue reads: %s" % [m, ending, want.substr(0, 50)])
			review.finish()
			await create_timer(0.3).timeout
			rec = y.meta_get(m)
			_check(not c.active and str(rec.ending) == ending and int(rec.year) == 3 and int(rec.top_year) == 3 and str(rec.get("y3", {}).get("ending", "")) == ending, "%s %s: recorded as a finished Year 3" % [m, ending])
			_check(career.has_medal(ending) and career.has_medal("year_three"), "%s %s: its medal and THIRD YEAR are earned" % [m, ending])
			if ending == "y3_chair":
				_check(y.available(m, 3) and y.available(m, 2), "%s: Year 3 can be played again" % m)
	_check(intro_seen, "the Year 3 intro card was checked")
	_check(career.value("year3_done") == 12 and career.earned_count() >= 14, "twelve finished Year 3 runs, twelve ending medals (%d earned)" % career.earned_count())

	# ---- guards: no stay row (sales, notice given), a cozy run, missing answers
	DirAccess.remove_absolute(y.meta_path())
	_write_meta("sales")
	_start("sales", 3)
	_drain()
	y.set_flag("chair", "stake")
	_good_standing("sales")
	_check(y.extra_offers([{"id": "leave"}]).size() == 1 and y.extra_offers([{"id": "let_go"}, {"id": "leave"}]).size() == 2, "a review with no STAY row (let go, notice given) gets no Year 3 ending")
	_check(y.extra_offers([{"id": "stay"}]).size() == 2, "with a STAY row it does")
	y.set_flag("chair", "")
	_check(y.extra_offers([{"id": "stay"}]).size() == 1, "no answer at the last beat: no Year 3 ending")
	career.counters.erase("end.y3_stake")
	diff.set_tier("easy")
	c.year = 3
	career.note_ending("y3_stake")
	_check(career.value("end.y3_stake") == 0, "a cozy (Easy) run does not count for an ending medal, like the other ending medals")
	diff.set_tier("normal")

	# ---- save and continue in the middle of Year 3
	DirAccess.remove_absolute(y.meta_path())
	_write_meta("tech")
	_start("tech", 3)
	_drain()
	y.begin_day(3)
	cards.pick(_option("notes"))
	_drain()
	c.day = 5
	var moves: Array = y.moves.duplicate(true)
	var carried: Dictionary = y.carried.duplicate(true)
	c.save()
	_start("tech", 1)
	_drain()
	_check(c.year == 1 and y.flag("newhire") == "" and is_equal_approx(y.sla_mult(), 1.0), "a first year in between is a plain first year")
	_check(c.continue_game("tech"), "Continue works for a Year 3 save")
	_drain()
	_check(c.year == 3 and c.day == 5 and y.active() and y.flag("newhire") == "notes" and y.moves == moves and y.carried == carried, "the year, the day, the answer, the shuffle and the carry-over come back")
	_check(is_equal_approx(y.sla_mult(), float(y.YEAR3.sla.mult)) and y.saved_tag("tech") == " (YEAR 3)" and str(y.prev.get("ending", "")) == "stay" and y.last_flag("courted") == "told", "so do the Year 3 clock, the tag and last year's record")
	y.begin_day(11)
	_check(cards.is_open and str(cards.speaker) == "Quinn (New hire)", "the next beat still fires after Continue")
	_drain()

	# ---- old saves: a Year 2 save from before Year 3 existed, and a save with no year at all
	_start("tech", 1)
	_drain()
	cfg = ConfigFile.new()
	cfg.load(c.save_path("tech"))
	cfg.set_value("campaign", "year", 2)
	cfg.set_value("campaign", "yeartwo", {"version": 1, "moves": [{"mode": "tech", "key": "book:rdp", "from": 7, "to": 6}], "carried": {"rep": 55}, "pick": "", "ban": "", "prev": {"ending": "lead", "rep": 80}})
	var st: Dictionary = cfg.get_value("story", "flags", {}) if cfg.has_section_key("story", "flags") else {}
	cfg.save(c.save_path("tech"))
	_check(c.continue_game("tech"), "an old Year 2 save loads")
	_drain()
	story.flags["y2"] = {"desk": "run", "courted": "told"}
	_check(c.year == 2 and y.active() and is_equal_approx(y.sla_mult(), 0.85) and y.moves.size() == 1 and int(y.carried.rep) == 55, "... as Year 2: the 0.85 clock, its shuffle and carry-over (%s)" % str(st.size()))
	_check(y.flag("desk") == "run" and y.last_flag("courted") == "" and y.saved_tag("tech") == " (YEAR 2)", "... its answers are read from y2 and the tag is (YEAR 2)")
	c.rep = 70
	root.get_node("Social").change_all(10)
	review.offers = review.make_offers()
	_check(_ids().has("head") and _ids().has("clientbuy") and not _ids().any(func(i: String) -> bool: return i.begins_with("y3_")), "... and its review offers what Year 2 always offered %s" % str(_ids()))
	_check(y.events_on("tech", 6, story.DAYS).any(func(ev: Dictionary) -> bool: return str(ev.get("book", "")) == "rdp"), "... with the moved job on its saved day")
	cfg = ConfigFile.new()
	cfg.load(c.save_path("tech"))
	cfg.erase_section_key("campaign", "year")
	cfg.erase_section_key("campaign", "yeartwo")
	cfg.save(c.save_path("tech"))
	_check(c.continue_game("tech"), "a save with no year loads")
	_drain()
	_check(c.year == 1 and not y.active() and is_equal_approx(y.sla_mult(), 1.0) and y.saved_tag("tech") == "", "... as a first year")

	# ---- the calendar: Year 3 does not move on from Year 2's, and has no XP season either
	var seasons: Script = load("res://scripts/seasons.gd")
	_check(seasons.date_text(1, 1) == "NOV 2013" and seasons.date_text(10, 2) == "APR 2015" and seasons.date_text(10, 3) == "APR 2015" and seasons.date_text(20, 3) == "OCT 2015", "the date line stops at Year 2's calendar: %s, %s" % [seasons.date_text(1, 3), seasons.date_text(20, 3)])
	_check(seasons.tags(9, 1) == ["tax", "xp"] and seasons.tags(9, 3) == ["tax"] and seasons.tags(3, 3) == ["holidays"] and seasons.tags(17, 3) == ["school"], "Year 3 keeps the yearly seasons and has no XP end of support")
	_check(not seasons.in_season("xp_six", 9, 3) and not seasons.in_season("xp_day", 10, 3) and seasons.in_season("tax_printer", 9, 3), "the XP cards stay out of a third year")

	for m in MODES:
		DirAccess.remove_absolute(c.save_path(m))
		c.clear_resume(m)
	DirAccess.remove_absolute(y.meta_path())
	DirAccess.remove_absolute(career.path())
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
