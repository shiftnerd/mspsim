extends SceneTree
# gdlint:disable=max-line-length
# R42 item 4: the TEXT setting (NORMAL / LARGE) and the CONTRAST setting (NORMAL / HIGH). Notes: docs/dev/notes-textsize.md
#   table        every format has a LARGE row: a smaller logical size (so a bigger scale on any screen), a whole scale, and on the
#                screens that matter the picture still fills the screen; the Deck's glyphs go from 20 to 25 px
#   default      nothing switches LARGE on by itself, on a Deck, a 1080p screen or a test run
#   setting      set_text_large / set_high_contrast apply at once (the window's content size), are saved and read back, and survive a SHAPE change
#   rows         the SETTINGS page and the in-game pause menu both have TEXT and CONTRAST, they toggle from the menu, and a short picture
#                scrolls the rows so every row (and the last one) can be reached and is drawn inside the panel
#   contrast     TextSize.color pushes dim text away from the middle, leaves the default alone, plates go solid
#   wrap         a hint wider than the screen breaks at its spaces (UiStyle.fit_lines)
# The "every screen fits at LARGE" proof is tests/layout_audit.gd (renderer): its format list has wide+L, h+L, deck+L, v+L, deck+LC.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/text_size.gd

const PixelFont := preload("res://scripts/pixelfont.gd")
const TextSize := preload("res://scripts/text_size.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var game := root.get_node("Game")
	var d := root.get_node("Difficulty")
	var pm := root.get_node("PauseMenu")
	var camp := root.get_node("Campaign")
	var pid := OS.get_process_id()
	d.settings_path = "user://test_%d_textsize_settings.cfg" % pid
	camp.save_prefix = "user://test_%d_textsize_" % pid
	DirAccess.remove_absolute(d.settings_path)

	# ---- the table -------------------------------------------------------------------------------------------------------
	for name in game.ORDER:
		var n: Dictionary = game.info(name, false)
		var l: Dictionary = game.info(name, true)
		_check(game.LARGE.has(name), "%s has a LARGE row" % name)
		_check(l.size.x < n.size.x and l.size.y < n.size.y, "%s LARGE is a smaller logical picture (%s against %s)" % [name, l.size, n.size])
		_check(int(l.scale) >= int(n.scale), "%s LARGE keeps at least the window scale (x%d against x%d)" % [name, int(l.scale), int(n.scale)])
		_check(int(l.scale) * int(l.size.x) <= 1920 * 2 and l.size.x >= 128, "%s LARGE is a sane size" % name)
	var deck_n: Dictionary = game.fit(Vector2i(1280, 800), "deck")
	_check(deck_n.scale == 4 and deck_n.size == Vector2i(1280, 800) and deck_n.fill > 0.99, "NORMAL: the Deck gets deck at x4 filling 1280 x 800")
	game.text_large = true
	var dl: Dictionary = game.fit(Vector2i(1280, 800), "deck")
	_check(dl.scale == 5 and dl.size == Vector2i(1280, 800) and dl.fill > 0.99, "LARGE: the Deck gets 256 x 160 at x5 filling 1280 x 800, glyphs 25 px (20 before)")
	var hl: Dictionary = game.fit(Vector2i(1920, 1080), "h")
	_check(hl.scale == 7 and hl.fill > 0.85, "LARGE: 1920 x 1080 gets h at x7 (35 px glyphs, 30 before), %.0f%% filled" % (100.0 * hl.fill))
	var hl2: Dictionary = game.fit(Vector2i(1280, 720), "h")
	_check(hl2.scale == 5 and hl2.fill > 0.99, "LARGE: 1280 x 720 gets h at x5, exact")
	var wl: Dictionary = game.fit(Vector2i(1920, 1080), "wide")
	game.text_large = false
	var wn: Dictionary = game.fit(Vector2i(1920, 1080), "wide")
	_check(wl.scale > wn.scale, "LARGE: wide on 1920 x 1080 scales up one step more (x%d against x%d)" % [wl.scale, wn.scale])
	for screen in [Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1440), Vector2i(1366, 768), Vector2i(1280, 720)]:
		for name in ["wide", "h", "deck"]:
			var a: Dictionary = game.fit(screen, name)
			game.text_large = true
			var b: Dictionary = game.fit(screen, name)
			game.text_large = false
			_check(int(b.scale) >= int(a.scale), "%s on %s: LARGE never scales less (x%d, x%d)" % [name, screen, b.scale, a.scale])

	# ---- nothing switches by itself ------------------------------------------------------------------------------------------
	_check(not game.text_large and not game.high_contrast, "a fresh run is NORMAL, CONTRAST normal")
	game.start_display(Vector2i(1280, 800), false)
	_check(not game.text_large and game.format == game.pick_format(Vector2i(1280, 800), true), "a 1280 x 800 start does not switch to LARGE")
	game.start_display(Vector2i(1920, 1080), false)
	_check(not game.text_large and not game.high_contrast, "a 1920 x 1080 start does not switch either")
	game.set_format("wide")

	# ---- the one screen that falls back -------------------------------------------------------------------------------------------
	_check(game.FALLBACK == {"printer": ["v"]}, "the screens that stay NORMAL under LARGE are named: the printer game in `v` (and nothing else)")
	game.set_format("v")
	game.set_text_large(true)
	game.large_hold("printer")
	_check(root.content_scale_size == Vector2i(game.FORMATS.v.size), "v + LARGE: the printer game is drawn at the NORMAL size (%s)" % root.content_scale_size)
	game.large_release("printer")
	_check(root.content_scale_size == Vector2i(game.LARGE.v.size), "and everything else is LARGE again when it closes")
	game.set_format("deck")
	game.large_hold("printer")
	_check(root.content_scale_size == Vector2i(game.LARGE.deck.size), "deck + LARGE: no fallback, the printer game is LARGE too")
	game.large_release("printer")
	game.set_text_large(false)
	game.set_format("wide")

	# ---- the setting ----------------------------------------------------------------------------------------------------------
	for name in ["wide", "h", "deck", "v", "vclose"]:
		game.set_format(name)
		game.set_text_large(true)
		_check(root.content_scale_size == Vector2i(game.LARGE[name].size) and game.logical_size() == Vector2(game.LARGE[name].size), "%s: TEXT LARGE applies at once (%s)" % [name, root.content_scale_size])
		game.set_text_large(false)
		_check(root.content_scale_size == Vector2i(game.FORMATS[name].size), "%s: and back to NORMAL (%s)" % [name, root.content_scale_size])
	game.set_format("deck")
	game.set_text_large(true)
	game.set_high_contrast(true)
	game.cycle_format()
	_check(game.text_large and root.content_scale_size == Vector2i(game.LARGE[game.format].size), "SHAPE keeps the LARGE text (%s: %s)" % [game.format, root.content_scale_size])
	var cfg := ConfigFile.new()
	_check(cfg.load(d.settings_path) == OK and bool(cfg.get_value("display", "text_large", false)) and bool(cfg.get_value("display", "high_contrast", false)), "both are saved in the settings file")
	game.text_large = false
	game.high_contrast = false
	TextSize.apply(false)
	game.load_display()
	_check(game.text_large and game.high_contrast and TextSize.high, "and read back at the next start")
	game.set_text_large(false)
	game.set_high_contrast(false)
	game.set_format("wide")
	_check(cfg.load(d.settings_path) == OK and not bool(cfg.get_value("display", "text_large", true)) and not TextSize.high, "switching back is saved too")

	# ---- the rows ------------------------------------------------------------------------------------------------------------
	pm.settings_mode = true
	var labels: Array = pm._labels()
	_check(labels.has("TEXT: NORMAL") and labels.has("CONTRAST: NORMAL") and labels.size() == 10, "SETTINGS (the title's page) has TEXT and CONTRAST next to SHAPE and DISPLAY: %s" % str(labels))
	_check(labels.find("TEXT: NORMAL") == labels.find("SHAPE: WIDE") + 1 and labels.find("CONTRAST: NORMAL") == labels.find("TEXT: NORMAL") + 1, "they sit right after SHAPE")
	pm.settings_mode = false
	camp.active = true
	camp.mode = "tech"
	labels = pm._labels()
	_check(labels.has("TEXT: NORMAL") and labels.has("CONTRAST: NORMAL"), "the pause menu in a room has them too: %s" % str(labels))
	camp.active = false
	camp.mode = camp.FREE
	_check(pm._labels().has("TEXT: NORMAL"), "and in Free Play")
	# toggling from the menu (both modes), with the keyboard's Right and the pad's D-pad right / A
	for settings in [true, false]:
		pm.settings_mode = settings
		pm.is_open = true
		pm._confirm = false
		pm._page = -1
		var ids := []
		for i in pm._labels().size():
			ids.append(pm._row_id(i))
		pm._sel = ids.find("text")
		pm._activate()
		_check(game.text_large and pm._labels()[pm._sel] == "TEXT: LARGE", "%s: ENTER on TEXT switches to LARGE" % ("SETTINGS" if settings else "pause menu"))
		pm._key(_key(KEY_RIGHT))
		_check(not game.text_large, "%s: Right toggles it back" % ("SETTINGS" if settings else "pause menu"))
		pm._sel = ids.find("contrast")
		pm._key(_key(KEY_RIGHT))
		_check(game.high_contrast and TextSize.high and pm._labels()[pm._sel] == "CONTRAST: HIGH", "%s: Right on CONTRAST turns HIGH on" % ("SETTINGS" if settings else "pause menu"))
		pm._activate()
		_check(not game.high_contrast, "%s: ENTER turns it off again" % ("SETTINGS" if settings else "pause menu"))
		var pad_event := InputEventJoypadButton.new()
		pad_event.button_index = JOY_BUTTON_DPAD_RIGHT
		pad_event.pressed = true
		pm._sel = ids.find("text")
		pm._key(pad_event)
		_check(game.text_large, "%s: the D-pad's right does the same" % ("SETTINGS" if settings else "pause menu"))
		game.set_text_large(false)
	pm.is_open = false
	pm.settings_mode = false

	# ---- a short picture scrolls the rows --------------------------------------------------------------------------------------
	for f in ["wide", "h", "deck", "v"]:
		game.set_format(f)
		game.set_text_large(true)
		for settings in [true, false]:
			pm.settings_mode = settings
			pm.is_open = true
			camp.active = true
			camp.mode = "tech"
			var n: int = pm._labels().size()
			var all_in := true
			var panel: Rect2 = pm._panel()
			for sel in n:
				pm._sel = sel
				var rr: Rect2 = pm._row_rect(sel)
				if rr.size == Vector2.ZERO or not panel.grow(1.0).encloses(rr):
					all_in = false
			_check(all_in, "%s+L %s: every row is drawn inside the panel when it is selected (%d rows, %d visible)" % [f, "SETTINGS" if settings else "pause", n, pm._vis()])
			pm._sel = 0
			_check(pm._row_rect(0).size != Vector2.ZERO, "%s+L: the first row is visible at the top" % f)
			pm.is_open = false
		game.set_text_large(false)
	pm.settings_mode = false
	camp.active = false
	camp.mode = camp.FREE
	game.set_format("wide")

	# ---- contrast --------------------------------------------------------------------------------------------------------------
	TextSize.apply(false)
	_check(TextSize.color(UiStyle.MUTED) == UiStyle.MUTED and TextSize.plate(0.86) == 0.86, "NORMAL: colours and plates untouched")
	TextSize.apply(true)
	var m := TextSize.color(UiStyle.MUTED)
	var s := TextSize.color(UiStyle.SOFT)
	_check(m.get_luminance() < UiStyle.MUTED.get_luminance() - 0.03, "HIGH: the grey-blue hint text on a light panel gets darker")
	_check(s.get_luminance() > UiStyle.SOFT.get_luminance() + 0.03, "HIGH: the grey hint text on a dark bar gets lighter")
	_check(TextSize.color(Color(1, 1, 1, 0.0)).a == 0.0 and TextSize.plate(0.86) >= 0.97, "HIGH: invisible text stays invisible, plates go (nearly) solid")
	TextSize.apply(false)

	# ---- wrapping ----------------------------------------------------------------------------------------------------------------
	var long := "ARROWS MOVE  Z FIRE  SHIFT DUCK  ESC OUT  AND A LONG TAIL OF WORDS"
	var parts: Array = UiStyle.fit_lines(long, 100.0)
	var fits := true
	for p in parts:
		fits = fits and float(PixelFont.width(str(p))) <= 100.0
	_check(parts.size() >= 2 and fits and " ".join(parts).replace("  ", " ").length() >= long.replace("  ", " ").length() - parts.size(), "a long hint breaks into lines that fit (%d lines)" % parts.size())
	_check(UiStyle.fit_lines("SHORT", 100.0) == ["SHORT"], "a short one stays one line")

	DirAccess.remove_absolute(d.settings_path)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e
