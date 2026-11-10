extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# Seasonal tags (roadmap R8) and the seasonal calendar events (R16): the campaign calendar (unit -> month), the season
# spans, the seasonal cards (valid deck cards, in the pool only in season, drawn on the seeded `events` stream), the
# tagged old card, the calendar event of a season (shown once at its time, saved, dropped when the day got away),
# the office dressing names and the decor node drawing them. Headless.


var Seasons: Script  # loaded in _init: a -s script compiles before the autoloads exist
var OfficeDecor: Script  # loaded in _init: a -s script compiles before the autoloads exist
var failures := 0
var c: Node
var ev: Node
var cards: Node
var world: Node
var d: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


func _fresh(mode: String, run_seed := 7) -> void:
	d.set_tier("normal")
	d.seed_run(run_seed)
	root.get_node("Game").title_mode = false
	root.get_node("Game").ui_open = false
	world.time_scale = 1.0
	c.new_game(mode)
	_drain()


func _pool_ids(day: int, mode: String) -> Array:
	return ev.pool(day, mode).map(func(e: Dictionary) -> String: return str(e.id))


func _init() -> void:
	await process_frame
	Seasons = load("res://scripts/seasons.gd")
	OfficeDecor = load("res://scripts/office_decor.gd")
	c = root.get_node("Campaign")
	ev = root.get_node("Events")
	cards = root.get_node("Cards")
	world = root.get_node("World")
	d = root.get_node("Difficulty")
	var story := root.get_node("Story")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Career").toasts = false

	# ---- the calendar
	var months := []
	for u in range(1, 21):
		months.append(Seasons.month(u))
	_check(months[0] == "NOV" and months[2] == "DEC" and months[9] == "APR" and months[19] == "OCT", "20 units run from November to October: %s" % str(months))
	_check(Seasons.date_text(1, 1) == "NOV 2013" and Seasons.date_text(10, 1) == "APR 2014" and Seasons.date_text(10, 2) == "APR 2015", "dates: %s, %s, year 2 %s" % [Seasons.date_text(1, 1), Seasons.date_text(10, 1), Seasons.date_text(10, 2)])
	_check(Seasons.tags(3, 1) == ["holidays"] and Seasons.tags(5, 1).is_empty() and Seasons.tags(17, 1) == ["school"], "holidays in December, nothing in January, school in August")
	_check(Seasons.tags(9, 1) == ["tax", "xp"] and Seasons.tags(9, 2) == ["tax"], "March 2014 is tax season and the XP countdown; Year 2 has no XP season")
	_check(Seasons.tags(1, 1).is_empty() and Seasons.tags(20, 1).is_empty(), "the first and last unit have no season")

	# ---- the tables: every seasonal card and calendar event is a valid deck card inside its season
	var bad := []
	for table in [Seasons.CARDS, Seasons.EVENTS]:
		for id in table:
			var card: Dictionary = table[id]
			for p in ev.violations(card):
				bad.append(str(p))
			var season: String = Seasons.season_of(str(id))
			if not Seasons.SEASONS.has(season):
				bad.append("%s has no season" % str(id))
				continue
			var span: Dictionary = Seasons.SEASONS[season]
			if int(card.min_day) < int(span.from) or int(card.max_day) > int(span.to):
				bad.append("%s: its days are outside the %s season" % [str(id), season])
	_check(bad.is_empty(), "the seasonal cards and events are valid and inside their seasons %s" % str(bad))
	_check(Seasons.CARDS.size() >= 8 and Seasons.EVENTS.size() == Seasons.SEASONS.size(), "%d seasonal cards, one calendar event per season" % Seasons.CARDS.size())
	for id in Seasons.EVENT_AT:
		_check(Seasons.EVENTS.has(id) and Seasons.EVENT_NAMES.has(id) and Seasons.tags(int(Seasons.EVENT_AT[id][0]), 1).has(Seasons.season_of(str(id))), "calendar event %s sits in its season" % str(id))
	_check(ev.DECK.has("tax_season") and Seasons.season_of("tax_season") == "tax", "the old tax season card is tagged")

	# ---- the pool: in season only
	for mode in ["tech", "owner"]:
		_fresh(mode)
		var wrong := []
		for day in range(1, 21):
			var ids := _pool_ids(day, mode)
			for id in Seasons.CARDS:
				var want: bool = Seasons.tags(day, 1).has(Seasons.season_of(str(id)))
				if ids.has(str(id)) != want:
					wrong.append("%s day %d" % [str(id), day])
			if ids.has("tax_season") and not Seasons.tags(day, 1).has("tax"):
				wrong.append("tax_season day %d" % day)
		_check(wrong.is_empty(), "%s: seasonal cards are in the pool in season and never outside %s" % [mode, str(wrong)])
		_check(_pool_ids(7, mode).has("tax_season") and not _pool_ids(4, mode).has("tax_season"), "%s: the tagged tax card waits for February" % mode)
		_check(_pool_ids(4, mode).has("xmas_ecard") and _pool_ids(4, mode).size() > 3, "%s: December has the e-card next to the ordinary cards" % mode)
	_fresh("tech")
	c.year = 2
	_check(not _pool_ids(9, "tech").has("xp_six") and _pool_ids(9, "tech").has("tax_printer"), "Year 2: no XP cards, tax cards stay")
	c.year = 1

	# ---- the draw is seeded: the same seed gives the same card and time on a seasonal day, and a seasonal card shows
	_fresh("tech")
	var quiet := -1  # a quiet day (one that draws) inside tax season
	for day in range(6, 11):
		if quiet < 0 and ev.quiet_day(day, "tech"):
			quiet = day
	_check(quiet > 0, "tax season has a quiet day for the deck (day %d)" % quiet)
	var draws := []
	for k in 2:
		_fresh("tech", 4242)
		c.day = quiet
		ev.begin_day(quiet)
		draws.append(ev.pending.duplicate(true))
	_check(not draws[0].is_empty() and draws[0] == draws[1], "seed 4242, day %d: the same draw twice (%s)" % [quiet, str(draws[0].get("id", ""))])
	var seen_seasonal := {}
	for s in 40:
		_fresh("tech", 9000 + s)
		c.day = quiet
		ev.begin_day(quiet)
		var id := str(ev.pending.get("id", ""))
		if Seasons.season_of(id) != "":
			seen_seasonal[id] = true
	_check(seen_seasonal.size() >= 2, "over 40 seeds February draws its seasonal cards: %s" % str(seen_seasonal.keys()))
	_fresh("tech")
	c.day = 7
	ev.show_draw({"deck": "event", "id": "tax_printer", "at": 10.0, "who": "Dan"})
	_check(cards.is_open and cards.options.size() == 2, "a seasonal card opens like a deck card")
	cards.pick(0)
	_check(cards.is_open, "and shows its result")
	_drain()

	# ---- the calendar event: once, at its time, saved
	_fresh("tech")
	c.day = 4
	world.clock = 11.0
	var today: Dictionary = Seasons.event_today()
	_check(str(today.get("id", "")) == "potluck" and is_equal_approx(float(today.at), 12.2), "unit 4 has the potluck at 12:12 (%s)" % str(today))
	Seasons.tick()
	_check(not cards.is_open, "it waits for its time")
	world.clock = 12.3
	cards.ask("Test", "A card is open", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	Seasons.tick()
	_check(Seasons.event_today().get("id", "") == "potluck", "it waits while another card is open")
	_drain()
	var social_before: int = root.get_node("Social").value("Dan")
	for i in 40:
		await process_frame  # Events._process calls Seasons.tick
		if cards.is_open and str(cards.speaker) == "The office":
			break
		if cards.is_open:
			cards.pick(0)  # a story card of the day came first
	_check(cards.is_open and str(cards.speaker) == "The office", "the potluck card opens by itself")
	cards.pick(0)
	_drain()
	_check(root.get_node("Social").value("Dan") > social_before, "its choice has its effect")
	_check(Seasons.event_today().is_empty() and story.flags.get("season_seen", {}).has("potluck"), "it is marked as seen")
	for i in 3:
		await process_frame
	_check(not cards.is_open, "and does not come twice")
	c.save()
	c.new_game("free")
	_check(c.continue_game("tech"), "save and continue")
	_drain()
	c.day = 4
	_check(story.flags.get("season_seen", {}).has("potluck") and Seasons.event_today().is_empty(), "the seen flag is saved with the campaign")
	# a day that got away drops the event
	_fresh("owner")
	c.day = 8
	world.clock = 15.6
	_check(Seasons.event_today().get("id", "") == "tax_basket", "week 8 of the owner campaign has the basket")
	Seasons.tick()
	_check(not cards.is_open and Seasons.event_today().is_empty(), "past 15:30 it is dropped without a card")
	_fresh("tech")
	c.year = 2
	c.day = 10
	_check(Seasons.event_today().is_empty(), "Year 2 has no XP day")
	c.new_game("free")
	_check(Seasons.event_today().is_empty() and Seasons.current().is_empty() and Seasons.dressing().is_empty(), "Free Play has no calendar")

	# ---- the dressing
	_fresh("tech")
	var want := {3: ["lights"], 5: [], 7: ["boxes"], 9: ["boxes", "countdown"], 17: ["drive"]}
	var ok := true
	for day in want:
		c.day = int(day)
		ok = ok and Seasons.dressing() == want[day]
	_check(ok, "dressing per season: lights, boxes, countdown, drive")
	var node: Node2D = OfficeDecor.new()
	root.add_child(node)
	for day in [3, 9, 17]:
		c.day = int(day)
		node.queue_redraw()
		await process_frame
		await process_frame
	_check(is_instance_valid(node), "the decor node draws every dressing without an error")
	node.queue_free()

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
