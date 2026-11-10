extends SceneTree
# gdlint:disable=max-line-length
# R42 Steam Deck: the 16:10 format and the pause on focus loss / suspend.
#   fit            what a 1280 x 800 screen gets from each format (integer scale, bars), and that "deck" fills it at x4
#   pick           a 16:10 screen starts in "deck", anything else in "wide"; a saved SHAPE choice wins; a test run asks nothing
#   glyphs         the pixel font is 5 logical px high, so 20 px on the Deck's screen at x4
#   focus          NOTIFICATION_APPLICATION_FOCUS_OUT / PAUSED open the pause menu in a room (no time passes), hold the
#                  tree on the title, and FOCUS_IN / RESUMED give it back; the UNFOCUSED setting turns it off
#   suspend        a frame that took seconds of real time (the process was frozen) pauses before the room moves on
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/deck_display.gd

const PixelFont := preload("res://scripts/pixelfont.gd")

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await _wait(2)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var game := root.get_node("Game")
	var world := root.get_node("World")
	var pm := root.get_node("PauseMenu")
	var camp := root.get_node("Campaign")
	var d := root.get_node("Difficulty")
	var pid := OS.get_process_id()
	camp.save_prefix = "user://test_%d_deck_" % pid
	d.settings_path = "user://test_%d_deck_settings.cfg" % pid
	var deck := Vector2i(1280, 800)

	# ---- what the Deck's screen gets -------------------------------------------------------------------------------
	for name in ["wide", "h", "deck", "v"]:
		var f: Dictionary = game.fit(deck, name)
		print("     %-5s on 1280x800: x%d = %dx%d, bars %d left/right and %d top/bottom, %d%% of the screen" % [name, f.scale, f.size.x, f.size.y, f.bars.x, f.bars.y, roundi(f.fill * 100.0)])
	var wide: Dictionary = game.fit(deck, "wide")
	var h: Dictionary = game.fit(deck, "h")
	var dk: Dictionary = game.fit(deck, "deck")
	_check(wide.scale == 3 and wide.size == Vector2i(1104, 384) and wide.bars == Vector2i(88, 208), "wide on a Deck: x3 = 1104 x 384, a letterbox of 208 px above and below")
	_check(h.scale == 4 and h.size == Vector2i(1280, 720) and h.bars == Vector2i(0, 40), "h on a Deck: x4 = 1280 x 720, 40 px bars")
	_check(dk.scale == 4 and dk.size == deck and dk.bars == Vector2i.ZERO and is_equal_approx(dk.fill, 1.0), "deck on a Deck: x4 = 1280 x 800, no bars")
	_check(game.FORMATS.deck.size == Vector2i(320, 200) and game.ORDER.has("deck"), "the format is 320 x 200 and the SHAPE row / F9 reach it")

	# ---- which format a screen starts in -----------------------------------------------------------------------------
	_check(game.pick_format(deck) == "deck" and game.pick_format(Vector2i(1920, 1200)) == "deck" and game.pick_format(Vector2i(2560, 1600)) == "deck", "16:10 screens start in deck")
	_check(game.pick_format(Vector2i(1920, 1080)) == "wide" and game.pick_format(Vector2i(3440, 1440)) == "wide" and game.pick_format(Vector2i(0, 0)) == "wide", "16:9, ultrawide and an unknown screen keep wide")
	_check(game.on_deck(deck) and not game.on_deck(Vector2i(1920, 1200)), "1280 x 800 is taken for a Deck (full screen), a 16:10 monitor is not")
	_check(game.dev_run() and game.format == "wide" and game.auto_format == "", "a test run asks no screen: wide, as before")
	game.start_display(deck, false)
	_check(game.format == "deck" and game.auto_format == "deck" and root.content_scale_size == Vector2i(320, 200), "start on a Deck screen: deck, 320 x 200 logical (%s)" % game.format)
	game.set_format("wide")
	game.start_display(deck, true)
	_check(game.format == "wide", "a --format argument wins over the screen")
	game.focus_force = true  # (also lets cycle_format save, as it does outside a test run)
	game.set_format("deck")
	game.cycle_format()
	var chosen: String = game.format
	_check(chosen == "v", "SHAPE steps on from deck (%s)" % chosen)
	game.set_format("wide")
	game.start_display(deck, false)
	_check(game.format == chosen, "the shape chosen in the settings is kept at the next start, whatever the screen (%s)" % game.format)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(d.settings_path))
	game.set_format("wide")
	game.start_display(Vector2i(1920, 1080), false)
	_check(game.format == "wide", "no saved choice on a 16:9 screen: wide")

	# ---- readable at 7 inches ------------------------------------------------------------------------------------------
	var rows := 99
	for ch in PixelFont.GLYPHS:
		rows = mini(rows, (PixelFont.GLYPHS[ch] as Array).size())
	_check(rows >= 5, "every glyph is at least 5 logical px high (%d): 20 px on the Deck at x4" % rows)
	_check(PixelFont.width("A", 1) >= 3, "and at least 3 px wide before its gap")

	# ---- focus loss in a room ------------------------------------------------------------------------------------------
	game.set_format("wide")
	game.title_mode = false
	camp.new_game("tech")
	camp.day = 3
	world.time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(40)
	_check(game.focus_pause, "the setting is on by default")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _wait(2)
	_check(pm.is_open and paused and game.focus_lost, "focus out in a room: the pause menu, the tree paused")
	var clock: float = world.clock
	await _wait(90)
	_check(is_equal_approx(world.clock, clock), "no time passes in the background")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _wait(2)
	_check(pm.is_open and paused and not game.focus_lost, "focus in: still paused, the menu is waiting for you")
	await _pad(JOY_BUTTON_B)
	_check(not pm.is_open and not paused, "B resumes")
	await _wait(60)
	_check(world.clock > clock, "and the clock runs again")
	# the app paused / resumed pair (a phone going to the background, a Deck suspend that says so)
	clock = world.clock
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _wait(30)
	_check(pm.is_open and paused and is_equal_approx(world.clock, clock), "APPLICATION_PAUSED pauses too")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _wait(2)
	pm.close()
	# a second focus-out while the menu is already up changes nothing
	pm.open()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _wait(2)
	_check(pm.is_open and paused, "focus out and in over an open pause menu leaves it open")
	pm.close()
	# a screen is open (the computer): the pause menu still takes over, and the screen is there afterwards
	var comp := root.get_node("Computer")
	comp.open(0)
	await _wait(5)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _wait(2)
	_check(pm.is_open and paused and comp.is_open, "focus out with the computer open: paused over it")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	pm.close()
	await _wait(2)
	_check(comp.is_open and not paused, "resume: the computer is still open")
	comp.close()
	await _wait(15)

	# ---- the switch ----------------------------------------------------------------------------------------------------
	game.set_focus_pause(false)
	clock = world.clock
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _wait(30)
	_check(not pm.is_open and not paused and world.clock > clock, "UNFOCUSED: RUN keeps the game going in the background")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.focus_pause = true
	_check(game.load_display() == "" and not game.focus_pause, "the switch is saved in the settings file")
	game.set_focus_pause(true)
	pm.open_settings()
	var row: int = pm._labels().find("UNFOCUSED: PAUSE")
	_check(row >= 0 and pm._row_id(row) == "focus", "the settings page has the UNFOCUSED row (%s)" % str(pm._labels()))
	pm._sel = row
	pm._activate()
	_check(not game.focus_pause and pm._labels().has("UNFOCUSED: RUN"), "confirm on it switches to RUN")
	pm._activate()
	pm.close()
	_check(game.focus_pause, "and back to PAUSE")

	# ---- a suspend nobody announced: a frame that took seconds -------------------------------------------------------
	var t0 := Time.get_ticks_msec()
	game._last_ms = t0
	_check(not game.gap_check(t0 + 16) and not paused, "an ordinary frame is not a suspend")
	_check(not game.gap_check(t0 + 16 + 900), "nor is a slow one (0.9 s)")
	_check(game.gap_check(t0 + 916 + 4 * 3600 * 1000) and pm.is_open and paused, "four hours between two frames: the pause menu is up")
	pm.close()
	game._last_ms = Time.get_ticks_msec()
	await _wait(3)
	_check(not pm.is_open and not paused, "resuming does not trip the check again")
	# the check runs at the start of a frame (the tree's process_frame signal), before any node's _process: the frame
	# that carries the enormous delta is already paused, so the room never takes that step
	game._last_ms = Time.get_ticks_msec() - 60000  # the next frame sees a minute's gap
	await process_frame  # (this frame was already under way; the next one starts here, Game's handler first)
	clock = world.clock
	_check(pm.is_open and paused, "a real gap seen at the start of a frame: paused at once")
	await process_frame
	await process_frame
	_check(is_equal_approx(world.clock, clock), "and the world's clock did not move in that frame (%.4f -> %.4f)" % [clock, world.clock])
	pm.close()
	game._last_ms = Time.get_ticks_msec()
	await _wait(2)

	# ---- on the title (no player): the tree is held and given back -------------------------------------------------
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(20)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _wait(2)
	_check(not pm.is_open and paused, "focus out on the title: the tree is held, no menu")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _wait(2)
	_check(not paused, "focus in: running again")
	game.focus_force = false
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
