extends SceneTree
# The story text file: matches the code, edits take effect, bad edits are rejected and reported.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _init() -> void:
	await process_frame
	var strings := root.get_node("Strings")
	var story := root.get_node("Story")
	var msp := root.get_node("Msp")

	# ---- the committed file matches the code
	var entries: Array = strings.entries()
	_check(entries.size() > 400, "%d editable strings in the game's tables" % entries.size())
	var table: Dictionary = strings.parse(FileAccess.get_file_as_string(strings.FILE))
	var missing := []
	for e in entries:
		if not table.has(str(e.key)):
			missing.append(str(e.key))
	_check(
		missing.is_empty(),
		(
			"every string is in story/strings.txt (missing %d: run story_export --sync)"
			% missing.size()
		)
	)
	_check(strings.report.is_empty(), "the file loads without problems: " + str(strings.report))
	_check(
		strings.applied == 0, "and the file says the same as the code (%d edits)" % strings.applied
	)

	# ---- the event deck and the drawn vignettes are editable too
	var ev: Node = root.get_node("Events")
	_check(table.has("Events.DECK.toner_late.text"), "the event deck is in story/strings.txt")
	_check(table.has("Story.VIGNETTES.captcha.options.0.text"), "the drawn vignettes are in story/strings.txt")
	_check(ev.DECK.size() >= 40, "the deck has 40 or more cards (%d)" % ev.DECK.size())
	var ev_text: String = ev.DECK.toner_late.text
	var ev_temp := "user://test_strings_ev.txt"
	_write(ev_temp, "[Events.DECK.toner_late.text]
The toner is late again.
")
	strings.load_file(ev_temp)
	_check(ev.DECK.toner_late.text == "The toner is late again." and ev.DEFAULT_DECK.toner_late.text == ev_text, "an edited event card is used, the default is kept")
	ev.DECK.toner_late.text = ev_text

	# ---- an edit takes effect
	var key := "Story.DAYS.1.0.body"
	var original: String = story.DAYS[1][0].body
	var temp := "user://test_strings.txt"
	_write(temp, "# a comment\n[%s]\nWelcome to the first day.\nThis wraps over two lines.\n" % key)
	var n: int = strings.load_file(temp)
	_check(
		n == 1 and story.DAYS[1][0].body == "Welcome to the first day. This wraps over two lines.",
		"an edited string is used by the game"
	)
	_check(story.DEFAULT_DAYS[1][0].body == original, "the code's own text is kept as the default")
	story.DAYS[1][0].body = original

	# ---- bad edits
	var pkey := "Msp.PROBLEMS.0.body"
	var pdefault: String = msp.PROBLEMS[0].body
	_write(temp, "[%s]\nMy printer is broken, no name here.\n" % pkey)
	n = strings.load_file(temp)
	_check(n == 0 and msp.PROBLEMS[0].body == pdefault, "an edit that drops a %s marker is ignored")
	_check(str(strings.report).contains("PLACEHOLDERS"), "and reported: " + str(strings.report))
	_write(temp, "[Story.DAYS.99.0.body]\nNo such day.\n[%s]\n\n" % key)
	n = strings.load_file(temp)
	_check(
		str(strings.report).contains("UNKNOWN KEY") and str(strings.report).contains("EMPTY"),
		"unknown keys and empty text are reported: " + str(strings.report)
	)
	_write(temp, "[%s]\nSlack me when the Windows 10 box is up.\n" % key)
	n = strings.load_file(temp)
	_check(
		str(strings.report).contains("PERIOD CHECK"),
		"2013-14 slips are flagged: " + str(strings.report)
	)
	story.DAYS[1][0].body = original

	# ---- syncing keeps edits and lists leftovers
	var built: String = strings.build(
		{key: "My edited welcome.", "Story.DAYS.77.0.body": "Left over."}
	)
	var again: Dictionary = strings.parse(built)
	_check(again.get(key) == "My edited welcome.", "sync keeps an edit")
	_check(
		again.get("Story.DAYS.77.0.body") == "Left over." and built.contains("NO LONGER USED"),
		"and lists strings the game no longer uses"
	)
	_check(again.size() >= entries.size(), "and still has every current string")
	_check(
		strings._placeholders("Hello %s, you have %d%% of %.1f") == ["s", "d", "f"],
		"placeholders are read correctly"
	)
	DirAccess.remove_absolute(temp)
	strings.load_file()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
