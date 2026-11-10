extends SceneTree
# gdlint:disable=max-line-length
# R4 leftover: the hint a friend gives in the escape room (N, `Outings.escape_nudge`) uses the wording of tonight's room. The old
# study keeps the FRIEND_HINTS lines word for word; the server room, the detective's office and the computer lab put their own
# nouns in (theme.words) and have their own recipe tips where the thing has another name (theme.tips). Every friend x zone x
# theme is asked here, and no line of a themed room may still talk about the chalkboard, the painting, the plaque or the bookshelf.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/escape_friend_hints.gd

const STUDY_ONLY := ["CHALKBOARD", "PAINTING", "PLAQUE", "BOOKSHELF", "BOOK ON", "A BOOK"]
# the noun each themed room must use for a zone (the words its clue captions use)
const NOUNS := {
	"server": {"board": "RACK BOARD|BOARD", "plaque": "NETWORK MAP", "shelf": "MANUAL SHELF|BINDER|SHELF", "keypad": "TAPE VAULT|KEYPAD|LOCK"},
	"detective": {"board": "CASE BOARD|BOARD", "plaque": "PORTRAIT", "shelf": "CASE FILE|SHELF", "keypad": "EVIDENCE VAULT|KEYPAD|LOCK"},
	"lab": {"board": "TEACHER'S BOARD|BOARD", "plaque": "CLASS PHOTO", "shelf": "MANUAL|SHELF", "keypad": "VAULT|KEYPAD|LOCK"},
}

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _fake_room(o: Node, options: Dictionary) -> void:
	o.opts = options.duplicate()
	o.game = "escape"
	o.is_open = true
	o._traveled = true
	o.phase = "play"
	o._pick_theme()
	o._escape_setup()
	o._escape_room_setup()


# the friend's line about one zone: every clue but that zone's counts as found (all of them for the keypad)
func _ask(o: Node, zone: String) -> String:
	o.g.found = []
	for i in o.g.clues.size():
		var z: String = o.CLUE_ZONES[int(o.g.spots[i]) if o.g.has("spots") else i]
		if z != zone:
			o.g.found.append(i)
	o.g.hints = 3
	return o.escape_nudge()


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var c := root.get_node("Campaign")
	var d := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Career").reset_all()
	c.new_game(c.FREE)
	d.set_tier("normal")
	d.seed_run(808)
	var friends: Array = o.FRIEND_HINTS.keys().filter(func(n: String) -> bool: return o.roster().has(n))
	_check(friends.size() >= 4, "the friends with hints are in the building (%s)" % str(friends))

	# ---- the table: every themed room has its words and tips, the study has none
	_check(not o.ESCAPE_THEMES.study.has("words") and not o.ESCAPE_THEMES.study.has("tips"), "the old study needs no words: the hints were written for it")
	for id in o.THEME_ORDER:
		if id == "study":
			continue
		var row: Dictionary = o.ESCAPE_THEMES[id]
		_check(row.get("words", {}).size() >= 6 and row.get("tips", {}).has("spine") and row.tips.has("ribbons"), "%s: its own nouns and the two shelf tips" % id)
		for from in row.words:
			_check(not str(row.words[from]).contains("CHALKBOARD") and str(row.words[from]) != str(from), "%s: %s becomes %s" % [id, from, row.words[from]])

	# ---- every theme x friend x zone
	var longest := 0
	for id in o.THEME_ORDER:
		var bad := []
		var missing := []
		var same := 0
		var asked := 0
		for friend in friends:
			_fake_room(o, {"theme": id, "party": [friend], "recipes": {"board": "sum", "clock": "hour", "plaque": "number", "shelf": "ribbons"}, "digits": 4})
			for zone in o.CLUE_ZONES + ["keypad"]:
				var line: String = _ask(o, zone)
				asked += 1
				longest = maxi(longest, line.length())
				var plain: String = "%s: %s" % [str(friend).to_upper(), str(o.FRIEND_HINTS[friend][zone])]
				if line.begins_with(plain):
					same += 1
				if not line.begins_with(str(friend).to_upper() + ": ") or line.length() < 20:
					bad.append("%s/%s: %s" % [friend, zone, line])
				if id == "study":
					continue
				for word in STUDY_ONLY:
					if line.contains(word):
						bad.append("%s/%s still says %s: %s" % [friend, zone, word, line])
				var want: String = str(NOUNS[id].get(zone, ""))
				if want != "" and not Array(want.split("|")).any(func(w: String) -> bool: return line.contains(w)):
					missing.append("%s/%s: %s" % [friend, zone, line])
		if id == "study":
			_check(same == asked and bad.is_empty(), "study: all %d hints are the old lines word for word" % asked)
		else:
			_check(bad.is_empty(), "%s: no hint talks about the study's furniture %s" % [id, str(bad)])
			_check(missing.is_empty(), "%s: every hint names the room's own thing %s" % [id, str(missing)])
			_check(same < asked / 2, "%s: most hints differ from the study's (%d of %d the same)" % [id, same, asked])
	_check(longest <= 140, "the longest hint is no longer than the room's own clue lines (%d characters)" % longest)

	# ---- the specialty tips: Alan's board tip is the recipe's, the shelf tips are the room's
	_fake_room(o, {"theme": "server", "party": ["Alan"], "recipes": {"board": "product", "clock": "hour", "plaque": "number", "shelf": "ribbons"}, "digits": 4})
	var alan: String = _ask(o, "board")
	_check(alan == "ALAN: THAT RACK BOARD IS MY KIND OF PROBLEM. DO THE MATH. " + str(o.RECIPE_TIPS.product), "Alan in the server room: %s" % alan)
	_check(o.recipe_tip("ribbons") == "COUNT THE CABLE TIES." and o.recipe_tip("spine").contains("BINDER") and o.recipe_tip("sum") == str(o.RECIPE_TIPS.sum), "the server room's shelf tips are about binders and cable ties, the rest are the usual")
	_fake_room(o, {"theme": "detective", "party": ["Garrison"], "recipes": {"board": "sum", "clock": "hour", "plaque": "number", "shelf": "ribbons"}, "digits": 4})
	_check(_ask(o, "plaque") == "GARRISON: A BRASS PLATE UNDER THE PORTRAIT! NOBODY HANGS A PORTRAIT FOR FREE.", "Garrison in the detective's office names the portrait")
	_check(o.recipe_tip("ribbons") == "COUNT THE RED STRINGS.", "and the red strings")
	_fake_room(o, {"theme": "lab", "party": ["Dan"], "recipes": {"board": "sum", "clock": "hour", "plaque": "number", "shelf": "ribbons"}, "digits": 4})
	_check(_ask(o, "shelf") == "DAN: THE MANUAL SHELF IS BOLTED TO THE WALL. SOMETHING ON IT IS NOT A MANUAL.", "Dan in the computer lab names the manual shelf")
	_fake_room(o, {"party": ["Dan"], "recipes": {"board": "sum", "clock": "hour", "plaque": "number", "shelf": "ribbons"}, "digits": 4})
	_check(_ask(o, "shelf") == "DAN: " + str(o.FRIEND_HINTS.Dan.shelf) and o.recipe_tip("ribbons") == str(o.RECIPE_TIPS.ribbons), "no theme option: the study's line and tip")
	# a patched line keeps working: the words are applied to whatever FRIEND_HINTS holds
	var keep: String = o.FRIEND_HINTS.Dan.shelf
	o.FRIEND_HINTS.Dan.shelf = "THE BOOKSHELF. OBVIOUSLY."
	_fake_room(o, {"theme": "lab", "party": ["Dan"], "recipes": {"board": "sum", "clock": "hour", "plaque": "number", "shelf": "ribbons"}, "digits": 4})
	_check(_ask(o, "shelf") == "DAN: THE MANUAL SHELF. OBVIOUSLY.", "an edited hint gets the room's nouns too")
	o.FRIEND_HINTS.Dan.shelf = keep
	o.is_open = false
	o._traveled = false
	o.phase = "intro"
	root.get_node("Game").ui_open = false
	print("escape_friend_hints: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
