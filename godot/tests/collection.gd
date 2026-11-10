extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# The collection pages and the cast relationship levels (roadmap R16, scripts/collection.gd): level thresholds, a
# level-up is announced once per run and kept in the career, the coffee perk from FRIEND up, the hooks that fill the
# collection (cast met, songs sung, clue recipes seen, printers beaten), the rows and pages, and the career screen:
# its collection pages, the C key, drawing in every format without text off the screen. Headless.

const PixelFont := preload("res://scripts/pixelfont.gd")

var Collection: Script  # loaded in _init: a -s script compiles before the autoloads exist
var failures := 0
var c: Node
var cards: Node
var career: Node
var social: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


func _fresh(mode: String) -> void:
	root.get_node("Difficulty").set_tier("normal")
	root.get_node("Game").title_mode = false
	root.get_node("Game").ui_open = false
	root.get_node("Shift").enabled = mode == "tech"
	c.new_game(mode)
	_drain()
	root.get_node("Msp").enabled = false


func _row(label: String) -> Dictionary:
	for it in Collection.items():
		if str(it.get("label", "")) == label:
			return it
	return {}


func _head(prefix: String) -> String:
	for it in Collection.items():
		if str(it.get("head", "")).begins_with(prefix):
			return str(it.head)
	return ""


func _init() -> void:
	await process_frame
	Collection = load("res://scripts/collection.gd")
	c = root.get_node("Campaign")
	cards = root.get_node("Cards")
	career = root.get_node("Career")
	social = root.get_node("Social")
	var hints := root.get_node("Hints")
	var shift := root.get_node("Shift")
	var story := root.get_node("Story")
	var outings := root.get_node("Outings")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	career.toasts = false
	career.reset_all()

	# ---- levels
	_check(Collection.level_of(0) == 0 and Collection.level_of(9) == 0 and Collection.level_of(10) == 1, "level 1 at 10")
	_check(Collection.level_of(25) == 2 and Collection.level_of(44) == 2 and Collection.level_of(45) == 3 and Collection.level_of(70) == 4 and Collection.level_of(100) == 4, "levels 2, 3, 4 at 25, 45, 70")
	_check(Collection.level_of(-60) == 0 and Collection.level_name(3) == "FRIEND", "a bad relationship is level 0; level 3 is FRIEND")
	var lines_ok := true
	for i in range(1, Collection.LEVELS.size()):
		lines_ok = lines_ok and str(Collection.LEVELS[i].line) != "" and str(Collection.LEVELS[i].perk) != ""
	_check(lines_ok, "every level has a line and a perk")

	# ---- a level-up: announced once, kept, with the coffee from FRIEND up
	_fresh("tech")
	_check(Collection.level("Maya") == 0 and Collection.best_level("Maya") == 0 and Collection.to_next("Maya") == 10, "a new run starts at level 0, 10 to go")
	hints.toast_text = ""
	social.change("Maya", 9)
	_check(Collection.level("Maya") == 0 and str(hints.toast_text) == "", "9 points: no level yet, no toast")
	social.change("Maya", 2)
	_check(Collection.level("Maya") == 1 and str(hints.toast_text).begins_with("MAYA, LEVEL 1: COWORKER"), "11 points: level 1 and a toast (%s)" % str(hints.toast_text).substr(0, 40))
	_check(career.value("rel.Maya") == 1 and career.value("met.Maya") == 1 and career.value("cast_met") == 1, "the career keeps the level and counts Maya as met")
	hints.toast_text = ""
	social.change("Maya", -5)
	social.change("Maya", 5)
	_check(str(hints.toast_text) == "" and int(story.flags.rel_lv.Maya) == 1, "dipping and coming back does not announce it twice")
	shift.energy = 50.0
	social.change("Maya", 40)
	_check(Collection.level("Maya") == 3 and str(hints.toast_text).contains("LEVEL 3: FRIEND") and is_equal_approx(shift.energy, 50.0 + Collection.COFFEE), "FRIEND: the coffee is on the desk (+%d energy)" % int(Collection.COFFEE))
	social.change("Maya", 30)
	_check(Collection.level("Maya") == 4 and is_equal_approx(shift.energy, 50.0 + 2.0 * Collection.COFFEE) and Collection.to_next("Maya") == 0, "WORK FAMILY: another coffee, nothing left to reach")
	_check(career.value("rel.Maya") == 4, "best level 4 in the career")
	c.save()
	c.new_game("free")
	_check(c.continue_game("tech"), "save and continue")
	_drain()
	hints.toast_text = ""
	social.change("Maya", 1)
	_check(str(hints.toast_text) == "" and int(story.flags.rel_lv.Maya) == 4, "the reached levels are saved with the campaign")
	_fresh("tech")
	_check(Collection.level("Maya") == 0 and Collection.best_level("Maya") == 4, "a new run starts over, the collection remembers the best")
	_fresh("owner")
	hints.toast_text = ""
	social.change("Dan", 50)
	_check(str(hints.toast_text).contains("DAN, LEVEL 3") and not str(hints.toast_text).contains("ENERGY"), "owner campaign: the level without the energy perk")
	c.new_game("free")
	social.change("Dan", 50)
	_check(Collection.level("Dan") == 0, "Free Play has no levels")

	# ---- the hooks that fill the collection
	social.note_chat("John")
	_check(career.value("met.John") == 1 and career.value("cast_met") == 3, "a chat counts as met (also in Free Play)")
	var song_id := str(outings.SONGS[0].id)
	outings.g = {"song": outings.SONGS[0]}
	career.note_outing("karaoke", 2, {"perfects": 3})
	career.note_outing("karaoke", 2, {"perfects": 1})
	_check(career.value("song." + song_id) == 1 and career.value("songs_sung") == 1, "a karaoke song is collected once")
	outings.g = {"clues": [{"recipe": "sum"}, {"recipe": "hour"}, {"recipe": "roman"}]}
	career.note_outing("escape", 1, {"secs": 90})
	_check(career.value("recipes_seen") == 3 and career.value("recipe.roman") == 1, "the escape room's clue recipes are collected")
	outings.g = {}
	career.note_printer("laser", 2, false, 1)

	# ---- rows and pages
	_check(_head("THE CAST") == "THE CAST 3/%d" % social.ALL.size(), "cast head: %s" % _head("THE CAST"))
	_check(str(_row("MAYA").value) == "LV 4 WORK FAMILY" and bool(_row("MAYA").on), "Maya's row: %s" % str(_row("MAYA")))
	_check(str(_row("JOHN").value) == "LV 0 NEW FACE" and str(_row("ALAN").value) == "NOT MET" and not bool(_row("ALAN").on), "met at level 0, and not met")
	_check(_head("KARAOKE SONGS") == "KARAOKE SONGS 1/%d" % outings.SONGS.size() and str(_row(str(outings.SONGS[0].title)).value) == "SUNG", "songs: %s" % _head("KARAOKE SONGS"))
	_check(_head("ESCAPE CLUES") == "ESCAPE CLUES 3/10" and str(_row("BOARD: SUM").value) == "SEEN" and str(_row("BOARD: PRODUCT").value) == "-", "clue recipes: %s" % _head("ESCAPE CLUES"))
	_check(_head("PRINTERS BEATEN") == "PRINTERS BEATEN 1/7" and str(_row("LASER").value) == "1 WIN", "printers: %s" % _head("PRINTERS BEATEN"))
	_check(str(_row("EARNED").value) == "%d/%d" % [career.earned_count(), career.MEDALS.size()], "the medal count")
	_check(str(_row("A TALL PLANT").value) == "REPUTATION 55", "office decor shows its rule while locked")
	var all: Array = Collection.items()
	for cap in [6, 15, 30]:
		var pages: Array = Collection.pages(cap)
		var n := 0
		var lonely := false
		for pg in pages:
			n += pg.rows.size()
			lonely = lonely or (pg.rows.size() == cap and pg.rows.back().has("head"))
			lonely = lonely or pg.rows.size() > cap
		_check(n == all.size() and not lonely, "pages of %d rows hold every row, no title alone at the bottom (%d pages)" % [cap, pages.size()])

	# ---- the career screen
	for fmt in ["wide", "h", "v"]:
		game.set_format(fmt)
		await process_frame
		var screen: Node = career.open_screen()
		for i in 3:
			await process_frame
		var canvas: Node = screen if screen.has_method("build") else screen.get_child(0)
		if screen.has_method("build") == false and "_canvas" in screen:
			canvas = screen._canvas
		_check(canvas.has_method("go_collection"), "%s: the career screen is open" % fmt)
		var first := -1
		var count := 0
		for i in canvas.pages.size():
			if canvas.pages[i].has("rows"):
				count += 1
				first = i if first < 0 else first
		_check(count >= 1 and str(canvas.pages[first].title) == "CAREER - COLLECTION", "%s: %d collection pages after the medals" % [fmt, count])
		canvas.page = 0
		var ev := InputEventKey.new()
		ev.keycode = KEY_C
		ev.pressed = true
		canvas._input(ev)
		_check(canvas.page == first, "%s: C jumps to the collection" % fmt)
		var off := []
		for p in range(first, first + count):
			canvas.page = p
			PixelFont.audit = []
			canvas.queue_redraw()
			for i in 4:
				await process_frame
			for line in PixelFont.audit_report("%s collection %d" % [fmt, p], false):
				off.append(line)
			PixelFont.audit = null
		_check(off.is_empty(), "%s: no collection text off the screen %s" % [fmt, str(off)])
		if canvas.has_method("close"):
			canvas.close()
		for i in 3:
			await process_frame
	game.set_format("wide")
	career.reset_all()

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
