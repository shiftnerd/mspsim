extends SceneTree
# gdlint:disable=max-line-length
# The Career autoload: counter hooks fired by real game calls, every medal rule at and just under its
# threshold, the save file outside the campaign slot, old / missing file defaults, cosmetic unlocks, the nerf war
# score card (the starter hit counts) and a brand deny-list over the medal and unlock tables.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/career.gd

const DENY := ["nintendo", "playstation", "xbox", "microsoft", "google", "apple", "sony", "sega", "atari", "hewlett", "canon", "epson", "xerox", "ricoh", "lexmark", "kyocera", "ikea", "pepsi", "coca", "mcdonald", "starbucks", "youtube", "facebook", "twitter", "amazon", "netflix", "nike", "disney", "pixar", "pokemon", "mario", "zelda", "tetris", "angry bird", "candy crush", "rickroll", " lego", "hasbro", " wii", "ps4"]
const NAMES := ["GUTTER GURU", "STICKY NOTES SAVIOR", "PRINTER WHISPERER", "NEVER RESTARTED", "MEETING SURVIVOR", "DUCK WHISPERER", "PEOPLE PERSON", "FRIDAY WARRIOR"]

var failures := 0
var c: Node
var prefix := ""


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fresh() -> void:
	c.reset_all()


# put a (possibly derived) counter at exactly v
func put(key: String, v: int) -> void:
	match key:
		"printer_models":
			var i := 0
			for m in root.get_node("PrinterGame").MODELS:
				c.counters["pr." + str(m)] = 1 if i < v else 0
				i += 1
		"stars3":
			var i := 0
			for g in c.GAMES:
				c.counters["stars." + g] = 3 if i < v else 0
				i += 1
		"days_total":
			c.counters["days.tech"] = v
		"tk_other":
			c.counters["tickets"] = v
		_:
			c.counters[key] = v


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


var started := false


func _process(_delta: float) -> bool:
	if current_scene == null or started:
		return false
	_run.call_deferred()
	started = true
	return false


func _run() -> void:
	await process_frame
	c = root.get_node("Career")
	var campaign := root.get_node("Campaign")
	prefix = "user://test_career_%d_" % OS.get_process_id()
	campaign.save_prefix = prefix
	c.toasts = false
	DirAccess.remove_absolute(c.path())
	_fresh()

	# ---- tables ------------------------------------------------------------------------------------
	_check(c.MEDALS.size() >= 20, "at least 20 medals (%d)" % c.MEDALS.size())
	var ids := {}
	var dup := false
	var wide := false
	for m in c.MEDALS:
		if ids.has(str(m.id)):
			dup = true
		ids[str(m.id)] = true
		if str(m.desc).length() > 30 or str(m.title).length() > 24:
			wide = true
	_check(not dup, "medal ids are unique")
	_check(not wide, "titles and hints fit the screen")
	var names := []
	for m in c.MEDALS:
		names.append(str(m.title))
	for n in NAMES:
		_check(n in names, "medal " + n)
	var bad := []
	for table in [c.MEDALS, c.UNLOCKS]:
		for row in table:
			var s := (str(row.title) + " " + str(row.get("desc", ""))).to_lower()
			for d in DENY:
				if s.contains(d):
					bad.append(s + " / " + d)
	_check(bad.is_empty(), "no real brand names in the tables " + str(bad))
	var orphans := []
	for u in c.UNLOCKS:
		if str(u.medal) != "" and c.medal(str(u.medal)).is_empty():
			orphans.append(u.id)
	_check(orphans.is_empty(), "every unlock points at a real medal")

	# ---- medal thresholds ---------------------------------------------------------------------------
	for m in c.MEDALS:
		for r in m.rules:
			var key := str(r[0])
			var n := int(r[2])
			_fresh()
			if str(r[1]) == ">=":
				put(key, n - 1)
				c.check_medals()
				_check(not c.has_medal(str(m.id)), "%s not earned at %d-1" % [m.id, n])
				put(key, n)
				var fresh: Array = c.check_medals()
				_check(c.has_medal(str(m.id)) and str(m.id) in fresh, "%s earned at %d" % [m.id, n])
			else:
				put(key, 0)
				c.check_medals()
				_check(not c.has_medal(str(m.id)), "%s not earned when never done" % m.id)
				put(key, n + 1)
				c.check_medals()
				_check(not c.has_medal(str(m.id)), "%s not earned at %d+1" % [m.id, n])
				put(key, n)
				c.check_medals()
				_check(c.has_medal(str(m.id)), "%s earned at %d" % [m.id, n])
	_fresh()
	c.toasts = true
	put("tickets", 49)
	c.add("tickets")
	var hints := root.get_node("Hints")
	_check(c.has_medal("ticket_machine") and hints.toast_text.contains("TICKET MACHINE"), "a toast announces the medal: " + hints.toast_text)
	c.toasts = false

	# ---- hooks from real game calls ---------------------------------------------------------------------
	_fresh()
	var msp := root.get_node("Msp")
	msp.reset()
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	msp.rmm_action(t.endpoint, str(t.fix))
	msp.close_ticket(t.id)
	_check(c.value("tickets") == 1 and c.value("tk." + str(t.fix)) == 1, "closing a ticket counts it by kind (%s)" % t.fix)
	var t2: Dictionary = msp.create_ticket(0, 0, "test")
	msp.close_ticket(t2.id)  # not fixed: reopened, must not count
	_check(c.value("tickets") == 1, "a reopened ticket is not counted")

	var o := root.get_node("Outings")
	o.game = "karaoke"
	o.g = {"perfect": 7}
	o._finish(2)
	_check(c.value("outings") == 1 and c.value("stars.karaoke") == 2 and c.value("kara_perfects") == 7, "karaoke result: outing, best stars, perfects")
	o.game = "karaoke"
	o.g = {"perfect": 3}
	o._finish(1)
	_check(c.value("stars.karaoke") == 2 and c.value("kara_perfects") == 10, "best stars keep the max, perfects add up")
	o.game = "escape"
	o.g = {"time": 80.0}
	o._finish(3)
	var secs: int = c.value("escape_best")
	_check(secs == roundi(root.get_node("Difficulty").f("escape.time") - 80.0), "escape best time = clock used (%d s)" % secs)
	o.g = {"time": 100.0}
	o._finish(2)
	_check(c.value("escape_best") == secs - 20 or c.value("escape_best") < secs, "a faster escape replaces it")
	o.game = "escape"
	o.g = {"time": 0.0}
	o._finish(0)
	_check(c.value("escape_best") < secs, "a lost escape does not set a time")
	o.game = "dinner"
	o.g = {"score": 26}
	o._finish(3)
	_check(c.value("dinner_best") == 26, "dinner best score")
	var before: int = c.value("outings")
	o.game = "dinner"
	o._finish(-1)
	_check(c.value("outings") == before, "leaving early is not an outing")
	var strikes_before: int = c.value("bowl_strikes")
	o.game = "bowling"
	o._bowl_setup()
	o.g.marker = 0.5
	o.g.power = 0.85
	o._bowl_resolve()
	_check(c.value("bowl_strikes") == strikes_before + 1, "a strike is counted")
	var gutter_ok := true
	var gutters := 0
	for i in 12:
		o._bowl_setup()
		o.g.marker = 0.0
		o.g.power = 0.0
		var g0: int = c.value("bowl_gutters")
		o._bowl_resolve()
		if int(o.g.knocked) == 0:
			gutters += 1
			gutter_ok = gutter_ok and c.value("bowl_gutters") == g0 + 1
		else:
			gutter_ok = gutter_ok and c.value("bowl_gutters") == g0
	_check(gutter_ok and gutters > 0, "gutter balls are counted (%d of 12)" % gutters)

	var pg := root.get_node("PrinterGame")
	pg.reset()
	pg.model = "inkjet"
	pg.prayed = false
	pg.stars = 3
	pg._record()
	pg.model = "plotter"
	pg.stars = 2
	pg._record()
	_check(c.value("printer_wins") == 2 and c.value("pr.inkjet") == 1 and c.value("pr.plotter") == 1, "printer wins per model")
	_check(c.value("pr_streak") == 2, "no-prayer streak is tracked")
	pg.model = "laser"
	pg.prayed = true
	pg.stars = 3
	pg._record()
	_check(c.value("pr_streak") == 2 and c.value("printer_wins") == 3, "a prayer ends the streak but keeps the best")
	pg.model = "laser"
	pg.stars = 0
	pg.prayed = false
	pg._record()
	_check(c.value("printer_wins") == 3, "a lost printer run is not a win")

	var pets: int = c.value("pets")
	root.get_node("Onsite")._pet("cat")
	_check(c.value("pets") == pets + 1, "petting an animal is counted")
	campaign.mode = "tech"
	campaign.day_started.emit(3)
	campaign.mode = "owner"
	campaign.day_started.emit(3)
	campaign.mode = ""
	_check(c.value("days.tech") == 1 and c.value("days.owner") == 1 and c.value("days_total") == 2, "days played per mode")

	# ---- nerf: counters and the war score ----------------------------------------------------------------
	var nerf := root.get_node("Nerf")
	nerf.reset()
	var actors := current_scene.get_node("Actors")
	var dan: Node = load("res://scenes/npc.tscn").instantiate()
	dan.character = "office_dan"
	dan.cast_name = "Dan"
	dan.position = Vector2(240.0, 118.0)
	actors.add_child(dan)
	await process_frame
	var dart_script := load("res://scripts/dart.gd")
	var dart: Node2D = dart_script.new()
	dart.shooter = "Player"
	dart.position = Vector2(240.0, 70.0)
	dart.set_meta("x0", 60.0)
	var h0: int = c.value("nerf_hits")
	nerf.dart_hit(dart, dan)
	_check(c.value("nerf_hits") == h0 + 1 and c.value("nerf_longest") == 180, "a hit is counted with its distance (%d)" % c.value("nerf_longest"))
	_check(nerf.war_t > 0.0 and nerf.war_hits == 1, "the hit that starts the war counts for the war (YOU HIT 1, not 0)")
	var d2: Node2D = dart_script.new()
	d2.shooter = "Player"
	d2.position = Vector2(240.0, 70.0)
	d2.set_meta("x0", 100.0)
	nerf.dart_hit(d2, dan)
	_check(nerf.war_hits == 2 and nerf.war_longest == 180, "later hits add up, longest stays")
	var dodge0: int = c.value("nerf_dodges")
	nerf._dodged(Node.new(), "Dan")
	_check(c.value("nerf_dodges") == dodge0 + 1 and nerf.war_dodged == 1, "the player ducking a dart is counted")
	nerf._dodged(dan, "Player")
	_check(c.value("nerf_dodges") == dodge0 + 1 and nerf.war_missed == 1, "a coworker ducking is not a player dodge")
	var d3: Node2D = dart_script.new()
	d3.shooter = "Maya"
	nerf.dart_hit(d3, dan)
	_check(nerf.war_ff == 1 and nerf.war_assists == 1, "a coworker hit by a coworker right after your hit is friendly fire and an assist")
	var wars: int = c.value("nerf_wars")
	nerf._end_war()
	_check(c.value("nerf_wars") == wars + 1 and nerf.last_result.hits == 2, "the war end counts a war and keeps the result")
	_check(root.get_node("Hints").toast_text.contains("YOU HIT 2"), "the war-over toast: " + root.get_node("Hints").toast_text)
	var titles: Array = nerf.war_titles({"hits": 6, "taken": 0, "dodged": 4, "missed": 0, "ff": 3, "assists": 0, "longest": 170})
	_check(titles.has("MOST DUCKED") and titles.has("SNIPER") and titles.has("FRIENDLY FIRE") and titles.has("UNTOUCHABLE"), "war titles: " + str(titles))
	_check(nerf.war_titles({"hits": 1, "taken": 1, "dodged": 2, "missed": 0, "ff": 2, "assists": 0, "longest": 149}).is_empty(), "no titles just below the thresholds")

	# ---- save / load outside the campaign slot -----------------------------------------------------------
	_fresh()
	c.add("tickets", 12)
	c.best("nerf_longest", 133)
	c.add("pets", 10)
	c.check_medals()
	c.save_file()
	_check(c.path() == prefix + "career.cfg" and FileAccess.file_exists(c.path()), "saved to the career file, not a campaign slot")
	_check(not campaign.has_save("tech") and not campaign.has_save("owner"), "no campaign slot was written")
	campaign.new_game("tech")
	campaign.new_game(campaign.FREE)
	_check(c.value("tickets") == 12 and c.has_medal("cat_person"), "New Game keeps the career")
	c.counters = {}
	c.earned = {}
	c.load_file()
	_check(c.value("tickets") == 12 and c.value("nerf_longest") == 133 and c.has_medal("cat_person"), "the file loads back")
	var old := ConfigFile.new()
	old.set_value("career", "version", 0)
	old.save(c.path())
	c.load_file()
	_check(c.value("tickets") == 0 and c.earned.is_empty() and c.prefs.wallpaper == "", "an old file with no sections loads as zero")
	DirAccess.remove_absolute(c.path())
	c.load_file()
	_check(c.value("pets") == 0 and c.earned_count() == 0, "no file: defaults")

	# ---- cosmetic unlocks ----------------------------------------------------------------------------------
	_fresh()
	_check(c.unlocked("wall_standard") and c.unlocked("ring_classic"), "default wallpaper and ringtone are free")
	_check(not c.unlocked("wall_sunset") and not c.unlocked("duck_gold") and not c.unlocked("nope"), "medal unlocks are locked, unknown ids are not unlocked")
	_check(c.wallpaper_color() == Color("2d6ca8") and c.ringtone_name() == "RING RING", "defaults without a pick")
	put("tickets", 50)
	c.check_medals()
	_check(c.unlocked("wall_sunset"), "ticket machine unlocks the sunset wallpaper")
	var pick: Dictionary = c.cycle_pick("wallpaper")
	_check(str(pick.id) == "wall_sunset" and c.wallpaper_color() == Color("b8683a"), "cycling picks the new wallpaper")
	c.cycle_pick("wallpaper")
	_check(c.wallpaper_color() == Color("2d6ca8"), "and wraps back to the standard one")
	put("duck_squeaks", 50)
	c.check_medals()
	_check(c.unlocked("duck_gold") and c.unlocked("ring_quack"), "duck whisperer unlocks the gold duck and a ringtone")
	c.cycle_pick("ringtone")
	_check(c.ringtone_name() == "QUACK QUACK", "the phone shows the ringtone name: " + c.ringtone_name())
	c.save_file()
	c.counters = {}
	c.earned = {}
	c.prefs = {"wallpaper": "", "ringtone": ""}
	c.load_file()
	_check(c.ringtone_name() == "QUACK QUACK", "the pick is saved")
	var comp := root.get_node("Computer")
	comp.activate("wall:next")
	_check(c.wallpaper_color() != Color("2d6ca8") or c.unlocked_of("wallpaper").size() == 1, "the computer desktop chip changes the wallpaper")

	# ---- the screen ----------------------------------------------------------------------------------------
	var screen: Node = c.open_screen()
	await process_frame
	await process_frame
	_check(screen.page_count() >= 3, "career screen has pages (%d)" % screen.page_count())
	screen.go(1)
	screen.go(-1)
	_check(screen.page == 0, "pages wrap with go()")
	var closed := [false]
	screen.closed.connect(func() -> void: closed[0] = true)
	screen.close()
	await process_frame
	await process_frame
	_check(closed[0] and not root.get_node("Game").ui_open, "closing frees the screen and the UI lock")

	# ---- clean up ------------------------------------------------------------------------------------------
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("test_career_%d_" % OS.get_process_id()):
			DirAccess.remove_absolute("user://" + f)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
