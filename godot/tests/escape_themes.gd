extends SceneTree
# gdlint:disable=max-line-length,max-returns
# R4 / E5: themed escape rooms (Outings.ESCAPE_THEMES: the old study, the server room, the detective's office, the 1990s computer
# lab). A theme changes the words, the tint and the ink, never the puzzle, so this test proves every theme x recipe is solvable:
#   1. table level: every theme x zone x recipe x digit gives a clue line a text-only solver reads the right digit from;
#   2. whole runs: for every theme and every combination of recipes (three and four digit codes) a scripted solver walks the room
#      through the public path (Outings.interact on each spot, reads the caption, types the code at the keypad) and gets out;
#   3. the draw: the invitation draws the theme on its own seeded stream, a game without the option is the study, the toolbox
#      names a fixed pick, the intro page names the room, and in the real room the theme tints the set.
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/escape_themes.gd`

const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _ints(text: String) -> Array:
	var out := []
	var cur := ""
	for ch in text + " ":
		if ch >= "0" and ch <= "9":
			cur += ch
		elif cur != "":
			out.append(int(cur))
			cur = ""
	return out


# the digit a clue line stands for, worked out from its words alone (what a player reads in the caption)
func _solve(line: String) -> int:
	var text := line.get_slice("  THAT IS DIGIT", 0)
	if text.contains(" + "):
		var left: Array = _ints(text.get_slice(" + ", 0))
		var right: Array = _ints(text.get_slice(" + ", 1))
		return int(left[-1]) + int(right[0])
	if text.contains(" X "):
		var left: Array = _ints(text.get_slice(" X ", 0))
		var right: Array = _ints(text.get_slice(" X ", 1))
		return int(left[-1]) * int(right[0])
	if text.contains("1 TO 9"):
		var total := 45
		for v in _ints(text.get_slice(":", 1)):
			total -= int(v)
		return total
	if text.contains("O'CLOCK"):
		var hour: int = int(_ints(text.get_slice(" O'CLOCK", 0))[-1])
		return hour * 2 if text.contains("TWICE") else hour
	if text.contains("ROMAN"):
		return ROMAN.find(text.get_slice("READS ", 1).get_slice(".", 0).strip_edges())
	if text.contains("ALPHABET"):
		return text.get_slice("LETTER ", 1).unicode_at(0) - 64
	return int(_ints(text)[-1])


func _fake_room(o: Node, options: Dictionary) -> void:
	o.opts = options.duplicate()
	o.game = "escape"
	o.is_open = true
	o._traveled = true
	o.phase = "play"
	o._pick_theme()
	o._escape_setup()
	o._escape_room_setup()


func _end_fake(o: Node) -> void:
	o.is_open = false
	o._traveled = false
	o.phase = "intro"
	root.get_node("Game").ui_open = false


# the scripted solver: look at every spot, read the caption, type the code, try it. Returns the stars (-1 when it could not read a clue).
func _play(o: Node) -> int:
	var n: int = o.g.code.size()
	var code := []
	code.resize(n)
	code.fill(-1)
	for kind in o.CLUE_KINDS:
		o.interact(kind)
		var cap: String = o._caption
		if not cap.contains("THAT IS DIGIT"):
			continue  # this spot is the red herring of the run
		var at: int = int(_ints(cap.get_slice("THAT IS DIGIT", 1))[0]) - 1
		code[at] = _solve(cap)
	if code.has(-1):
		return -1
	o.interact("keypad")
	for i in n:
		for step in int(code[i]):
			o.press(KEY_UP)
		o.press(KEY_RIGHT)
	o.press(KEY_ENTER)
	return o.stars if o.phase == "result" else -1


func _settle(name: String) -> void:
	var n := 0
	while (current_scene == null or current_scene.scene_file_path.get_file().get_basename() != name or root.get_node("Game").busy) and n < 600:
		await process_frame
		n += 1
	for i in 5:
		await process_frame


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var tb := root.get_node("Toolbox")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	root.get_node("Career").reset_all()
	c.new_game(c.FREE)
	d.set_tier("normal")
	d.seed_run(808)

	# ---- the table
	_check(o.THEME_ORDER.size() >= 4 and o.THEME_ORDER[0] == "study", "four rooms, the old study first (%s)" % str(o.THEME_ORDER))
	var recipes := []
	for zone in o.CLUE_ZONES:
		recipes.append_array(o.RECIPES[zone])
	var titles := {}
	for id in o.THEME_ORDER:
		var row: Dictionary = o.ESCAPE_THEMES[id]
		titles[str(row.title)] = true
		var whole := true
		for key in ["title", "short", "tint", "ink", "intro", "start", "open", "say"]:
			whole = whole and row.has(key)
		for recipe in recipes:
			whole = whole and row.say.has(recipe)
		_check(whole, "%s: a name, an intro, a tint, an ink and a line for all %d recipes" % [id, recipes.size()])
		_check(str(row.short).length() <= 12 and str(row.title).length() <= 24 and str(root.get_node("Controls").keys(str(row.start))).length() <= 78, "%s: the name and the opening caption fit" % id)
		if id != "study":
			_check(row.shelf.size() >= 3 and row.herring.size() == 3 and Color(str(row.tint)) != Color.WHITE, "%s: its own red herrings and a tint" % id)
			_check(str(row.say.sum) != str(o.ESCAPE_THEMES.study.say.sum) and str(row.intro) != str(o.ESCAPE_THEMES.study.intro), "%s: its own wording" % id)
	_check(titles.size() == o.THEME_ORDER.size(), "every room has its own name")

	# ---- 1. every theme x zone x recipe x digit reads back from the words
	var r: RandomNumberGenerator = d.rng_for("themes_test", 1)
	for id in o.THEME_ORDER:
		o.opts = {"theme": id}
		o._pick_theme()
		var cells := 0
		var wrong := []
		var longest := 0
		for zone in o.CLUE_ZONES:
			for recipe in o.RECIPES[zone]:
				for digit in range(1, 10):
					if not o.recipe_fits(recipe, digit):
						continue
					var clue: Dictionary = o.make_clue(zone, recipe, digit, r)
					cells += 1
					longest = maxi(longest, str(clue.say).length())
					if _solve(str(clue.say)) != digit or o.clue_answer(clue) != digit or str(clue.say).contains("{"):
						wrong.append("%s %d: %s" % [recipe, digit, str(clue.say)])
		_check(wrong.is_empty() and cells >= 70, "%s: %d clue lines, each one reads back to its digit %s" % [id, cells, str(wrong.slice(0, 3))])
		_check(longest <= 120, "%s: the longest clue line is %d letters (two caption lines with the digit note)" % [id, longest])

	# ---- 2. whole runs: every theme x every combination of recipes, three and four digits
	for id in o.THEME_ORDER:
		var runs := 0
		var solved := 0
		var opened := true
		for board in o.RECIPES.board:
			for clock in o.RECIPES.clock:
				for plaque in o.RECIPES.plaque:
					for shelf in o.RECIPES.shelf:
						for digits in [3, 4]:
							_fake_room(o, {"theme": id, "digits": digits, "recipes": {"board": board, "clock": clock, "plaque": plaque, "shelf": shelf}})
							runs += 1
							var stars := _play(o)
							solved += 1 if stars >= 1 else 0
							opened = opened and str(o.g.msg) == str(o.ESCAPE_THEMES[id].open)
							_end_fake(o)
		_check(solved == runs and runs == 72, "%s: the scripted solver gets out of all %d rooms (%d)" % [id, runs, solved])
		_check(opened, "%s: the vault opens with the theme's line" % id)
	# and with the drawn layout (which spot holds which clue) on a few seeds per theme
	for id in o.THEME_ORDER:
		var ok_runs := 0
		for seed_n in range(60, 72):
			d.seed_run(seed_n)
			_fake_room(o, {"theme": id})
			ok_runs += 1 if _play(o) >= 1 else 0
			_end_fake(o)
		_check(ok_runs == 12, "%s: 12 seeded rooms with drawn spots are solved (%d)" % [id, ok_runs])
	# the red herrings are the theme's
	_fake_room(o, {"theme": "server"})
	o.interact("herring_safe")
	_check(o._caption.contains("BACKUP TAPES"), "the server room's safe has its own line: %s" % o._caption)
	_end_fake(o)
	_fake_room(o, {})
	o.interact("herring_safe")
	_check(o._caption.begins_with(str(o.HERRING_TEXT.herring_safe)) and o.theme_id() == "study", "no option: the study and its old lines")
	_end_fake(o)

	# ---- 3. the draw
	var seen := {}
	var same := true
	for seed_n in range(1, 61):
		d.seed_run(seed_n)
		o.opts = o._game_options("escape")
		o._pick_theme()
		var first: String = o.theme_id()
		seen[first] = true
		d.seed_run(seed_n)
		o.opts = o._game_options("escape")
		o._pick_theme()
		same = same and o.theme_id() == first
	_check(str(o._game_options("escape").get("theme", "")) == "draw", "the invitation asks for a drawn room")
	_check(seen.size() == o.THEME_ORDER.size() and same, "60 seeds draw all %d rooms, and a seed always draws the same one" % seen.size())
	d.seed_run(808)
	var before: int = d.rng("escape").state
	o.opts = {"theme": "draw"}
	o._pick_theme()
	_check(d.rng("escape").state == before, "the theme has its own stream: the escape stream did not move")
	o.start("escape", false, {"panel": true})
	_check(o.theme_id() == "study" and o.escape_intro("X") == "X", "a game without the option is the old study, and its intro is unchanged")
	o.close()
	o.start("escape", false, {"panel": true, "theme": "draw"})
	_check(o.escape_intro("X").begins_with("TONIGHT'S ROOM: %s." % str(o.escape_theme().title)), "the intro page names the room: %s" % o.escape_intro("X").left(40))
	o.close()
	d.fixed_take = true
	var takes := {}
	for again in 3:
		o.start("escape", false, {"panel": true, "theme": "draw"})
		takes[o.theme_id()] = true
		o.close()
	d.fixed_take = false
	_check(takes.size() == 1, "a fixed take repeats the room")
	# the toolbox: a fixed pick
	tb.game_i = tb.GAMES.find("escape")
	tb.theme_i = 0
	_check(not tb.outing_options().has("theme"), "toolbox default: no theme option (the study)")
	var room_row := -1
	for i in tb.rows().size():
		if str(tb.rows()[i].id) == "room":
			room_row = i
	_check(room_row >= 0 and str(tb.rows()[room_row].value) == "OLD STUDY", "the toolbox has a ROOM row")
	tb.sel = room_row
	tb.change(1)
	_check(tb.theme_i == 1 and str(tb.outing_options().get("theme", "")) == "server" and str(tb.rows()[room_row].value) == "SERVER ROOM", "Right picks the server room, and it is passed to the outing")
	tb.theme_i = 0

	# ---- the look, in the real room
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle("main_floor")
	o.enabled = true
	o.use_rooms = true
	o.start("escape", false, {"theme": "detective"})
	var n := 0
	while not o.is_open and n < 800:
		await process_frame
		n += 1
	await _settle("escape_room")
	for i in 5:
		await process_frame
	var tint := Color(str(o.ESCAPE_THEMES.detective.tint))
	_check(o.room_mode() and current_scene.get_node("Background").modulate.is_equal_approx(tint), "the detective's office tints the room")
	_check(current_scene.get_node("Actors").modulate == Color.WHITE, "the people keep their colours")
	_check(o.escape_ink() == str(o.ESCAPE_THEMES.detective.ink), "the board is written in the theme's ink")
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o._caption == str(o.ESCAPE_THEMES.detective.start), "the opening caption is the theme's")
	_check(_play(o) >= 1 and str(o.g.msg) == str(o.ESCAPE_THEMES.detective.open), "and the real room is solved by the same solver")
	o.press(KEY_ENTER)
	await _settle("main_floor")
	_check(current_scene.get_node("Background").modulate == Color.WHITE, "back at the office nothing is tinted")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
