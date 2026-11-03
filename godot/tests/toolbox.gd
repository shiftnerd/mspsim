extends SceneTree
# gdlint:disable=class-definitions-order,max-line-length
# The Free Play toolbox: every entry launches the right game with the chosen parameters (headless, overlay games),
# fixed take (same notes every take, no mutator, no forced events), the seed page keys, row navigation and the
# open / close rules.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/toolbox.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(tb: Node, code: Key, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	tb._key(e)


func _notes(o: Node) -> Array:
	var out := []
	for n in o.g.notes:
		out.append(n.lane)
	return out


func _go(tb: Node, game: String) -> bool:
	tb.game_i = tb.GAMES.find(game)
	return tb.launch()


var frame := 0


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		_run()
	return false


func _run() -> void:
	var tb := root.get_node("Toolbox")
	var o := root.get_node("Outings")
	var pg := root.get_node("PrinterGame")
	var d := root.get_node("Difficulty")
	var m := root.get_node("Mutators")
	var campaign := root.get_node("Campaign")
	var nerf := root.get_node("Nerf")
	campaign.save_prefix = "user://test_toolbox_%d_" % OS.get_process_id()
	o.use_rooms = false
	d.fixed_take = false
	# ---- nothing chosen
	tb.game_i = 0
	_check(not tb.launch(), "no game chosen launches nothing")
	_check(tb.rows().size() >= 4 and str(tb.rows()[0].id) == "game", "rows start with GAME")
	# ---- each game
	_check(_go(tb, "bowling") and o.is_open and o.game == "bowling", "BOWLING launches bowling")
	o.begin_play()
	_check(not o.g.is_empty(), "bowling set up")
	o.close()
	# karaoke: a song by id (title shown in the row), even a locked one, no card at the mic
	var last_song: int = o.SONGS.size()
	tb.song_i = last_song
	_check(_go(tb, "karaoke") and o.game == "karaoke" and o.opts.get("song", "") == str(o.SONGS[last_song - 1].id), "KARAOKE passes the chosen song id")
	tb.sel = tb.rows().find_custom(func(r: Dictionary) -> bool: return str(r.id) == "song")
	_check(str(tb.current_row().value) == str(o.SONGS[last_song - 1].title), "the row shows the song title")
	o.begin_play()
	_check(str(o.g.song.id) == str(o.SONGS[last_song - 1].id), "the karaoke setup uses that song")
	var c2: Array = _notes(o)
	o.close()
	d.seed_run(77)
	_go(tb, "karaoke")
	o.begin_play()
	var c3: Array = _notes(o)
	o.close()
	d.seed_run(77)
	_go(tb, "karaoke")
	o.begin_play()
	_check(_notes(o) == c3 and not c3.is_empty(), "the same seed and song give the same chart")
	o.close()
	tb.song_i = 1
	_go(tb, "karaoke")
	o.begin_play()
	_check(str(o.g.song.id) == str(o.SONGS[0].id), "song 1 is the first of Outings.SONGS")
	o.close()
	tb.song_i = 0
	# escape: digits and fixed recipes
	tb.digits = 4
	tb.recipe_i["board"] = o.RECIPES["board"].find("product") + 1
	tb.recipe_i["clock"] = o.RECIPES["clock"].find("double") + 1
	_check(_go(tb, "escape") and o.game == "escape" and int(o.opts.get("digits", 0)) == 4 and o.opts.recipes.board == "product", "ESCAPE passes digits and recipes")
	o.begin_play()
	_check(o.g.code.size() == 4 and o.g.cur.size() == 4, "4 digit code and entry")
	o._escape_room_setup()  # the in-room deal (the overlay game has no clues)
	_check(o.g.clues.size() == 4 and str(o.g.clues[0].recipe) == "product" and str(o.g.clues[1].recipe) == "double", "the chosen recipes are the clues")
	_check(o.clue_answer(o.g.clues[0]) == int(o.g.code[0]) and o.clue_answer(o.g.clues[1]) == int(o.g.code[1]), "each clue works out to its code digit")
	var code4: Array = o.g.code.duplicate()
	var sc: Array = o.escape_score(code4)
	_check(int(sc[0]) == 4 and int(sc[1]) == 0, "a 4 digit guess scores 4 bulls")
	o.escape_try(code4.duplicate())
	_check(o.phase == "result" and o.stars >= 1, "cracking it ends the game")
	o.close()
	tb.digits = 3
	tb.recipe_i = {"board": 0, "clock": 0, "plaque": 0, "shelf": 0}
	_go(tb, "escape")
	o.begin_play()
	_check(o.g.code.size() == 3, "3 digits when chosen")
	o.close()
	tb.digits = 0
	tb.table_i = 1
	_check(_go(tb, "dinner") and o.game == "dinner" and o.opts.get("table", []) == ["Alan", "Garrison"], "DINNER passes the table")
	_check(o.diners() == ["Alan", "Garrison"], "only the chosen guests are at the table")
	o.close()
	tb.table_i = 0
	_go(tb, "dinner")
	_check(o.diners().size() == 3, "ALL THREE restores the table")
	o.close()
	tb.model_i = pg.MODEL_ORDER.find("plotter")
	_check(_go(tb, "printer") and pg.is_open and pg.model == "plotter", "PRINTER launches the chosen model")
	pg._finish()
	_check(not pg.is_open, "printer closes")
	_check(_go(tb, "nerf") and nerf.war_t > 0.0, "NERF WAR starts the war")
	nerf._end_war()
	# ---- fixed take
	tb.set_fixed_take(true)
	_check(d.fixed_take and m.current_id() == "" and m.forced == "", "fixed take: no mutator")
	m.forced = "flu"
	_check(m.current_id() == "", "fixed take ignores a forced mutator")
	m.forced = ""
	var rows_ids := []
	for r in tb.rows():
		rows_ids.append(str(r.id))
	_check(not rows_ids.has("mutator"), "the mutator row is hidden in fixed take")
	d.seed_run(0x1234AB)
	tb.song_i = 0
	_go(tb, "karaoke")
	o.begin_play()
	var t1: Array = _notes(o)
	o.close()
	# draw other things in between: a retake must still match
	d.rng("karaoke").randi()
	d.rng("escape").randi()
	_go(tb, "karaoke")
	o.begin_play()
	_check(_notes(o) == t1, "fixed take: a retake gives the same notes without a chosen song")
	o.close()
	_go(tb, "printer")
	_check(pg.practice and pg.practice_seed == 1 + d.run_seed % 99, "fixed take: the printer plays the practice set of the seed")
	pg._finish()
	tb.set_fixed_take(false)
	_check(not d.fixed_take, "fixed take can be switched off")
	d.seed_run(0x1234AB)
	_go(tb, "karaoke")
	o.begin_play()
	var u1: Array = _notes(o)
	o.close()
	_go(tb, "karaoke")
	o.begin_play()
	_check(_notes(o) != u1, "without fixed take a second take is a new chart")
	o.close()
	# a campaign start clears fixed take
	d.fixed_take = true
	campaign.new_game("tech")
	_check(not d.fixed_take, "starting a campaign clears fixed take")
	campaign.new_game("free")
	# ---- opening and keys
	_check(tb.can_open(), "can open in Free Play")
	tb.open_tools()
	_check(tb.is_open and root.get_node("Game").ui_open and not tb.can_open(), "open blocks the game")
	tb.sel = 0
	tb.game_i = 0
	var sel0: int = tb.sel
	_key(tb, KEY_DOWN)
	_check(tb.sel == sel0 + 1, "down moves the row")
	_key(tb, KEY_UP)
	_key(tb, KEY_RIGHT)
	_check(tb.game_id() == "bowling", "right on GAME steps to the next game")
	_key(tb, KEY_LEFT)
	_key(tb, KEY_LEFT)
	_check(tb.game_id() == "nerf", "left wraps to the last game")
	tb.game_i = 0
	_key(tb, KEY_ESCAPE)
	_check(not tb.is_open and not root.get_node("Game").ui_open, "Esc closes")
	# the seed page
	tb.open_tools()
	tb.sel = tb.rows().find_custom(func(r: Dictionary) -> bool: return str(r.id) == "seed")
	_key(tb, KEY_ENTER)
	_check(tb.mode == "seed", "Enter on SEED opens the seed page")
	for ch in "4f2a9c":
		tb.type_char(ch)
	_check(tb.seed_buf == "4F2A9C", "typing fills the field")
	tb.backspace()
	tb.type_char("D")
	_key(tb, KEY_ENTER)
	_check(tb.mode == "tools" and d.seed_text() == "4F2A9D" and d.run_seed == 0x4F2A9D, "Enter applies the typed seed and returns")
	tb.sel = tb.rows().find_custom(func(r: Dictionary) -> bool: return str(r.id) == "seed")
	_key(tb, KEY_ENTER)
	_key(tb, KEY_TAB)
	_key(tb, KEY_TAB)
	_check(tb.seed_focus == 2, "Tab moves to TODAY")
	_key(tb, KEY_ENTER)
	_check(d.run_seed == d.daily_seed() and d.daily != "" and tb.mode == "tools", "TODAY picks the date seed")
	_key(tb, KEY_ESCAPE)
	_check(not tb.is_open, "Esc leaves the toolbox")
	tb.open_seed()
	_key(tb, KEY_TAB)
	_key(tb, KEY_ENTER)
	_check(not tb.is_open and d.daily == "", "RANDOM rolls a new seed and closes")
	# title flow: GO queues the game
	var got := [false]
	tb.game_i = tb.GAMES.find("dinner")
	tb.open_tools(true, func(go: bool) -> void: got[0] = go)
	tb.sel = tb.rows().size() - 1
	_key(tb, KEY_ENTER)
	_check(got[0] and tb.queued and not tb.is_open, "START FREE PLAY from the title queues the game")
	tb.queued = false
	tb.game_i = 0
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)


