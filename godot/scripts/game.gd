extends Node
# Autoload: scene changes with a fade, the output format, and values that survive scene changes.
#   Format: Godot --path godot -- --format=h     (wide | h | v | vclose, or env PIXEL_FORMAT)
#   Video:  Godot --path godot --resolution 1920x1080 --fixed-fps 60 --write-movie out.avi
#           -- --format=h
# F9 cycles the format while playing.

signal format_changed
signal text_changed

const PixelFont := preload("res://scripts/pixelfont.gd")
const TextSize := preload("res://scripts/text_size.gd")

# size = logical pixels; zoom = camera zoom; cam_y = world y the camera centres on;
# scale = default window pixel scale without --resolution (6x of h = 1920x1080, 6x of v = 1080x1920)
const FORMATS := {
	"wide": {"size": Vector2i(368, 128), "zoom": 1.0, "cam_y": 64.0, "scale": 4, "follow": false},
	"h": {"size": Vector2i(320, 180), "zoom": 1.0, "cam_y": 50.0, "scale": 4, "follow": true},
	# R42: 16:10. x4 = 1280 x 800, the whole Steam Deck screen with no bars (h there is 1280 x 720 with 40 px bars)
	"deck": {"size": Vector2i(320, 200), "zoom": 1.0, "cam_y": 50.0, "scale": 4, "follow": true},
	"v": {"size": Vector2i(180, 320), "zoom": 1.0, "cam_y": 60.0, "scale": 3, "follow": true},
	"vclose": {"size": Vector2i(180, 320), "zoom": 2.0, "cam_y": 92.0, "scale": 3, "follow": true},
}
const ORDER := ["wide", "h", "deck", "v", "vclose"]
# R42 item 4, the TEXT setting. LARGE is the same picture in fewer logical pixels at a higher whole scale, so every glyph
# (and every sprite) is bigger on the physical screen: deck 256 x 160 at x5 is 25 px glyphs on a 1280 x 800 Deck (20 px at
# NORMAL), h 256 x 144 at x7 is 35 px on 1920 x 1080 (x5 on 1280 x 720 is exact). Only what differs from FORMATS is listed; see docs/dev/notes-textsize.md.
const LARGE := {
	"wide": {"size": Vector2i(320, 112), "scale": 5, "follow": true},
	"h": {"size": Vector2i(256, 144), "scale": 7},
	"deck": {"size": Vector2i(256, 160), "scale": 5},
	"v": {"size": Vector2i(144, 256), "scale": 4},
	"vclose": {"size": Vector2i(144, 256), "scale": 4},
}
# The one screen that does not fit a LARGE picture of a format: the printer mini-game lays out a fixed 176 px panel with
# hard-coded columns (tray, toner, test lists), 40 px too wide for LARGE `v` (144). While it is open the picture is the
# format's NORMAL size; every other screen keeps LARGE. screen -> the formats it falls back in (named in tests/text_size.gd).
const FALLBACK := {"printer": ["v"]}
const GAP_MS := 3000  # a frame that took longer than this in real time was a suspend (the Deck's power button): pause

const UI_STRIP := 0.2  # share of the screen height left visible above a computer / phone UI
# "full screen" is the exclusive mode: the shared one on Windows is a window 2 px taller than the screen, so the picture
# sat 2 px low under a black line (seen in a real window, docs/dev/notes-qa-ui.md)
const FULL_MODE := Window.MODE_EXCLUSIVE_FULLSCREEN

var vars := {}  # e.g. office_return = "from_office1"
var pending_spawn := "start"
var pending_x := -1.0  # one-shot x override for the next spawn (-1 = use the spawn point)
var busy := false
var format := "wide"
var title_mode := false  # the title screen shows real rooms without the player or the cast
var ui_open := false  # a computer / phone UI is open: the player is paused
var ui_shift := 0.0  # 0..1: the stage camera slides so the player shows in the faded strip
var fullscreen := true  # the DISPLAY setting: the game starts full screen, SETTINGS can make it a window
var text_large := false  # R42 item 4, the TEXT row: LARGE uses the format's smaller logical size (LARGE above)
var fallback_on := true  # tests: false draws every screen at LARGE, FALLBACK or not
var high_contrast := false  # the TEXT row's second switch: brighter hint text and darker plates (TextSize.apply)
var focus_pause := true  # R42, the setting: the game pauses when its window loses focus or the app is suspended
var focus_force := false  # tests: act on focus notifications in a script run too
var focus_lost := false  # the window is in the background (or the app is suspended) right now
var auto_format := ""  # the format the screen asked for at start ("" = none: a test run, or a screen that is not 16:10)
var _held := {}  # FALLBACK screens that are open: the picture is the format's NORMAL size while any is
var _held_pause := false  # this script paused the tree for a focus loss (no pause menu could open): undo it on return
var _last_ms := -1

var _fade: ColorRect


# ---- R42: the screen, focus and suspend ---------------------------------------------------------------------------
# a test or a tool run (a -s script, a movie, headless): the screen is not asked, the saved shape is not loaded and a
# focus change pauses nothing, so an existing test never changes with the monitor it runs on
func dev_run() -> bool:
	var args := OS.get_cmdline_args()
	for flag in ["-s", "--script", "--write-movie", "--resolution"]:
		if flag in args:
			return true
	return DisplayServer.get_name() == "headless" or OS.get_environment("MSPSIM_TEST") == "1"


func large_hold(screen: String) -> void:
	if not fallback_on or not text_large or not FALLBACK.get(screen, []).has(format) or _held.has(screen):
		return
	_held[screen] = true
	set_format(format)


func large_release(screen: String) -> void:
	if _held.erase(screen):
		set_format(format)


# the table row of a format for the text size now in force (or for `large` when asked): size, zoom, cam_y, scale, follow
func info(name: String, large: bool = text_large and _held.is_empty()) -> Dictionary:
	var f: Dictionary = FORMATS[name]
	if not large:
		return f
	var out: Dictionary = f.duplicate()
	out.merge(LARGE[name], true)
	return out


# the logical size of the picture now (what every screen lays out from)
func logical_size() -> Vector2:
	return Vector2(info(format).size)


# what a screen gets from a format with integer scaling: {scale, size (the picture in screen pixels), bars (left / right,
# top / bottom), fill (share of the screen that is picture)}
func fit(screen: Vector2i, name: String) -> Dictionary:
	var size: Vector2i = info(name).size
	var scale := maxi(1, mini(screen.x / size.x, screen.y / size.y))
	var shown := size * scale
	var fill := float(shown.x * shown.y) / float(maxi(1, screen.x * screen.y))
	return {"scale": scale, "size": shown, "bars": (screen - shown) / 2, "fill": fill}


# a Steam Deck (the environment says so in game mode, or the screen is its 1280 x 800)
func on_deck(screen: Vector2i) -> bool:
	return OS.get_environment("SteamDeck") == "1" or screen == Vector2i(1280, 800)


# the format a screen starts in: a 16:10 screen gets "deck" (it fills it), anything else the classic "wide"
func pick_format(screen: Vector2i, full: bool = false) -> String:
	if screen.x <= 0 or screen.y <= 0:
		return "wide"
	var ratio := float(screen.x) / float(screen.y)
	if absf(ratio - 1.6) < 0.02:
		return "deck"
	# full screen on a 16:9 screen (a ROG Ally's 1080p, a TV, most monitors): "h" fills it at a whole scale, "wide" leaves bars
	return "h" if full and absf(ratio - 16.0 / 9.0) < 0.02 else "wide"


# the saved choices (the pause menu's SHAPE row or F9, the UNFOCUSED row), kept in the settings file
func load_display() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(Difficulty.settings_path) != OK:
		return ""
	focus_pause = bool(cfg.get_value("display", "focus_pause", true))
	text_large = bool(cfg.get_value("display", "text_large", false))
	high_contrast = bool(cfg.get_value("display", "high_contrast", false))
	TextSize.apply(high_contrast)
	fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	return str(cfg.get_value("display", "format", ""))


func save_display(with_format: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Difficulty.settings_path)
	if with_format:
		cfg.set_value("display", "format", format)
	cfg.set_value("display", "focus_pause", focus_pause)
	cfg.set_value("display", "text_large", text_large)
	cfg.set_value("display", "high_contrast", high_contrast)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(Difficulty.settings_path)


# the DISPLAY row of SETTINGS: full screen (the default on every machine) or a window
func set_fullscreen(on: bool) -> void:
	fullscreen = on
	save_display(false)
	if dev_run() and not focus_force:
		return  # a test or a tool-driven run keeps its window
	get_window().mode = FULL_MODE if on else Window.MODE_WINDOWED
	if not on:
		place_window()


# a windowed game: the largest whole scale, up to the format's own, that fits the room a screen has
func window_scale(name: String, room: Vector2i) -> int:
	var size: Vector2i = info(name).size
	return clampi(mini(room.x / size.x, room.y / size.y), 1, int(info(name).scale))


# size the window to the format and centre it in the screen's free area (the taskbar is not part of it). Without this a
# SHAPE change kept the old top left corner: h to v on a 1080p screen ran off the bottom
func place_window() -> void:
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED or DisplayServer.get_name() == "headless":
		return
	var area := DisplayServer.screen_get_usable_rect(win.current_screen)
	var frame := win.get_size_with_decorations() - win.size  # the title bar and the borders
	var inset := win.position - win.get_position_with_decorations()
	win.size = Vector2i(info(format).size) * window_scale(format, area.size - frame)
	win.position = area.position + (area.size - win.size - frame) / 2 + inset


# Alt+Enter anywhere flips DISPLAY (F11 too in a release build: a debug build keeps F11 for its room jumps). The window
# hands the event over before any screen sees it; the key is blanked, so the Enter does not also confirm a menu row.
func _window_input(event: InputEvent) -> void:
	if Controls.take_display_key(event):
		set_fullscreen(not fullscreen)


# the TEXT row of SETTINGS: NORMAL / LARGE, applied at once (the picture is re-framed at the format's smaller size and every
# screen redraws from the new viewport), and HIGH CONTRAST on / off (TextSize.apply: the palette and the plates)
func set_text_large(on: bool) -> void:
	text_large = on
	save_display(false)
	set_format(format)
	text_changed.emit()


func set_high_contrast(on: bool) -> void:
	high_contrast = on
	TextSize.apply(on)
	save_display(false)
	text_changed.emit()
	format_changed.emit()  # every screen repaints


func set_focus_pause(on: bool) -> void:
	focus_pause = on
	save_display(false)


# at start (deferred, so the settings path is known): the shape you chose last time, else the one that fits the screen.
# A --format argument or PIXEL_FORMAT wins over both.
func start_display(screen: Vector2i, forced: bool) -> void:
	var saved := load_display()
	auto_format = pick_format(screen, fullscreen)
	if forced:
		return
	if FORMATS.has(saved):
		set_format(saved)
	elif auto_format != format:
		set_format(auto_format)
	if (fullscreen or on_deck(screen)) and DisplayServer.get_name() != "headless":
		get_window().mode = FULL_MODE  # the game starts full screen; SETTINGS has DISPLAY: WINDOW
	else:
		place_window()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		focus_out()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		focus_in()
	elif what == NOTIFICATION_UNPAUSED:
		_last_ms = -1  # the time spent paused is not a suspend


func _focus_on() -> bool:
	return focus_pause and (focus_force or not dev_run())


# the window went to the background, or the app is being suspended: stop the clock. With a player in a room that is the
# pause menu (it also writes the resume point); anywhere else (title, character select) the tree is held until you return
func focus_out() -> void:
	if focus_lost or not _focus_on():
		return
	focus_lost = true
	if get_tree().paused:
		return  # already paused (the pause menu is up)
	if is_instance_valid(PauseMenu) and PauseMenu.can_open(false):
		PauseMenu.open()
	else:
		_held_pause = true
		get_tree().paused = true


func focus_in() -> void:
	if not focus_lost:
		return
	focus_lost = false
	_last_ms = Time.get_ticks_msec()
	if _held_pause:
		_held_pause = false
		get_tree().paused = false


# a frame that took seconds of real time: the machine slept without telling us (a Deck suspend freezes the process).
# Called from the tree's process_frame signal, which comes before any node's _process of that frame: pausing here keeps
# the room from taking that one enormous step. The pause menu is left up.
func gap_check(now_ms: int) -> bool:
	var gap := 0 if _last_ms == -1 else now_ms - _last_ms  # -1: no frame seen yet (the start, or just unpaused)
	_last_ms = now_ms
	if gap < GAP_MS or not _focus_on() or get_tree().paused:
		return false
	focus_out()
	focus_lost = false  # nothing will send a focus-in: the menu (or the title) is simply there when you look
	if _held_pause:
		_held_pause = false
		get_tree().paused = false
	return true


func _frame_start() -> void:
	gap_check(Time.get_ticks_msec())


func _process(_delta: float) -> void:
	# Layout audit: with env LAYOUT_AUDIT=1 any test run prints text that leaves the viewport or overlaps other text.
	if PixelFont.audit != null and OS.get_environment("LAYOUT_AUDIT") == "1":
		for line in PixelFont.audit_report(format, true):
			print(line)


func _ready() -> void:
	if OS.get_environment("LAYOUT_AUDIT") == "1":
		PixelFont.audit = []
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	var wanted := OS.get_environment("PIXEL_FORMAT")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--format="):
			wanted = arg.substr(9)
	set_format(wanted if FORMATS.has(wanted) else "wide")
	get_tree().process_frame.connect(_frame_start)
	get_window().window_input.connect(_window_input)
	if not dev_run():
		start_display.call_deferred(DisplayServer.screen_get_size(), FORMATS.has(wanted))


func set_format(name: String) -> void:
	format = name
	var f: Dictionary = info(name)
	var size: Vector2i = f.size
	var win := get_window()
	win.content_scale_size = size
	if not "--resolution" in OS.get_cmdline_args() and DisplayServer.get_name() != "headless" and win.mode == Window.MODE_WINDOWED:
		if dev_run():
			win.size = size * int(f.scale)  # a test or a tool run: the plain size, wherever the window is
		else:
			place_window()
	format_changed.emit()


func cycle_format() -> void:
	set_format(ORDER[(ORDER.find(format) + 1) % ORDER.size()])
	if not dev_run() or focus_force:
		save_display()  # your choice wins over the screen's at the next start


# Test helper (Q4): a real mouse click at a LOGICAL UI point (0..size of the current format), sent through
# Input.parse_input_event. parse_input_event wants window pixels, so the point goes through the window's final
# (content scale) transform; that makes it independent of the window size, which differs in a hidden, headless or
# --resolution window. The UI scripts read event.position (logical), not the OS cursor, so the click lands.
func ui_to_window(ui_point: Vector2) -> Vector2:
	return get_window().get_final_transform() * ui_point


func hover_at(ui_point: Vector2) -> void:
	Input.use_accumulated_input = false
	var motion := InputEventMouseMotion.new()
	motion.position = ui_to_window(ui_point)
	motion.global_position = motion.position
	Input.parse_input_event(motion)


func click_at(ui_point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	hover_at(ui_point)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = ui_to_window(ui_point)
		ev.global_position = ev.position
		ev.button_index = button
		ev.pressed = pressed
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(ev)


func go_title() -> void:
	busy = false
	# a pause that came from losing focus can sit on top of an open phone or computer: they must not follow you to the title
	for screen in [Computer, Phone]:
		if screen.is_open:
			screen.close()
	Cards.clear_all()  # a card that was open or waiting (it came up over a pause) must not follow the run to the title
	ui_open = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func go(scene: String, spawn: String) -> void:
	if busy:
		return
	busy = true
	if spawn.begins_with("@"):
		spawn = str(vars.get(spawn.substr(1), "start"))
	var here := get_tree().current_scene
	if here != null and is_instance_valid(World):
		World.player_left(here.scene_file_path.get_file().get_basename(), scene)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.15)
	await t.finished
	pending_spawn = spawn
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.15)
	await t2.finished
	busy = false
