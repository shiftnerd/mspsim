extends CanvasLayer
# Autoload: the pause menu. ESC (or the Pause key) while you are walking around a room stops everything: the clock,
# the cast, the tickets, the SLA timers (the whole scene tree is paused; this node alone keeps running).
# Rows: RESUME, CONTROLS (the key list, 3 pages, Left / Right turn them), SHAPE (the output format, same as F9),
# QUIT TO TITLE (asks first; a campaign keeps its last end-of-day save). The key list lives in Controls.HELP.
# ESC does nothing here while a computer, phone, card, outing, report or other screen is open: those use ESC themselves.
# The Pause key works over those too, except on the title and character select screens.

const UiStyle := preload("res://scripts/ui_style.gd")
const PadGlyphs := preload("res://scripts/pad_glyphs.gd")

const ROW_H := 12.0
const ROW_MIN := 8.0  # R42: rows never get thinner than this (5 px of text and a pixel either side): a short screen scrolls the list
const REMAP_PAGE := 100  # the key list's R page: put the walking actions on other keys

var is_open := false
var settings_mode := false  # R40: opened from the title's SETTINGS line (nothing is paused, no QUIT TO TITLE)

var _sel := 0
var _confirm := false
var _page := -1  # -1 = the menu, 0.. = a page of the controls list, REMAP_PAGE = the remap list
var _rsel := 0
var _capture := false  # waiting for the key to put on the selected action
var _canvas: Control


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	visible = false
	Game.format_changed.connect(_canvas.queue_redraw)


# true when there is a room with a player in it and nothing else has the screen
func can_open(strict := true) -> bool:
	var scene := get_tree().current_scene
	if scene == null or Game.title_mode or Game.busy or Toolbox.outfit_open or Players.player0(scene) == null:
		return false
	if not strict:
		return true
	if Game.ui_open or Cards.is_open or DayReport.is_open or Outings.is_open or PrinterGame.is_open:
		return false
	return not (Review.is_open or Toolbox.is_open or Computer.is_open or Phone.is_open)


func open() -> void:
	if is_open:
		return
	Campaign.snapshot()  # the mid-day resume point (R16); refused at an unsafe moment
	is_open = true
	_sel = 0
	_confirm = false
	_page = -1
	visible = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	_canvas.queue_redraw()


# R40: the pause menu's settings pages from the title screen: CONTROLS (key list and remap), SHAPE, SOUND, DAY LENGTH
func open_settings() -> void:
	if is_open:
		return
	settings_mode = true
	is_open = true
	_sel = 0
	_confirm = false
	_page = -1
	visible = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.queue_redraw()


func close() -> void:
	if not is_open:
		return
	settings_mode = false
	is_open = false
	visible = false
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false


# the Android back button (Resume.go_back): the same as ESC in the menu
func back() -> void:
	if not is_open:
		return
	if _page >= 0:
		_page = -1
		_sel = 1
	elif _confirm:
		_confirm = false
		_sel = 3
	else:
		close()
	_canvas.queue_redraw()


func _labels() -> Array:
	if settings_mode:
		var sound := "SOUND: %s" % ("OFF" if Sfx.muted else "ON")
		var unfocused := "UNFOCUSED: %s" % ("PAUSE" if Game.focus_pause else "RUN")  # R42
		var display := "DISPLAY: %s" % ("FULL SCREEN" if Game.fullscreen else "WINDOW")
		return ["BACK", "CONTROLS", "SHAPE: %s" % Game.format.to_upper(), _text_label(), _contrast_label(), display, sound, "DAY LENGTH: %s" % Difficulty.day_label(), unfocused, "CAREER"]
	if _confirm:
		return ["NO, KEEP PLAYING", "YES, QUIT"]
	var rows := ["RESUME", "CONTROLS", "SHAPE: %s" % Game.format.to_upper(), _text_label(), _contrast_label()]
	if Campaign.active:
		rows.append("DAY LENGTH: %s" % Difficulty.day_label())  # R16: 5 / 10 / 15 minutes, starts at the next morning
		if Campaign.mode == "tech":
			rows.append("TICKET PACE: %s" % Msp.pace_label())  # X10: relaxed / normal / busy, at once
	elif Campaign.mode == Campaign.FREE:  # Free Play (R15 level 3 step e): change your look
		rows.append("OUTFIT")
		rows.append("CAREER")  # a pad has no free button for the J key, so the career screen is reachable from here too
		rows.append("FREE PLAY MENU")  # R9 / R14: the mutator, the toolbox, a team outing, the next person (Toolbox.open_free_menu)
	rows.append("QUIT TO TITLE")
	return rows


# R42 item 4: the TEXT size and CONTRAST rows (SETTINGS and the pause menu both have them)
func _text_label() -> String:
	return "TEXT: %s" % ("LARGE" if Game.text_large else "NORMAL")


func _contrast_label() -> String:
	return "CONTRAST: %s" % ("HIGH" if Game.high_contrast else "NORMAL")


# the id of a menu row (the rows move with the mode): "resume", "controls", "shape", "day", "outfit", "quit"
func _row_id(i: int) -> String:
	if settings_mode:
		return ["resume", "controls", "shape", "text", "contrast", "display", "sound", "day", "focus", "career"][clampi(i, 0, 9)]
	var ids := ["resume", "controls", "shape", "text", "contrast"]
	if Campaign.active:
		ids.append("day")
		if Campaign.mode == "tech":
			ids.append("pace")
	elif Campaign.mode == Campaign.FREE:
		ids.append("outfit")
		ids.append("career")
		ids.append("free")
	ids.append("quit")
	return ids[clampi(i, 0, ids.size() - 1)]


func _activate() -> void:
	if settings_mode:
		match _row_id(_sel):
			"resume":
				close()
			"controls":
				_page = 0
			"shape":
				Game.cycle_format()
			"text":
				Game.set_text_large(not Game.text_large)
			"contrast":
				Game.set_high_contrast(not Game.high_contrast)
			"display":
				Game.set_fullscreen(not Game.fullscreen)
			"sound":
				Sfx.toggle_mute()
			"day":
				Difficulty.cycle_day_scale(1)
			"focus":  # R42: pause when the window is in the background (a Deck suspend), or keep running
				Game.set_focus_pause(not Game.focus_pause)
			"career":
				close()
				Career.open_screen.call_deferred()
		_canvas.queue_redraw()
		return
	if _confirm:
		if _sel == 1:
			Campaign.snapshot()  # again: the resume point carries what this menu changed (day length, ticket pace)
			close()
			Game.go_title()
		else:
			_confirm = false
			_sel = _labels().size() - 1
		_canvas.queue_redraw()
		return
	if _row_id(_sel) in ["day", "pace"]:
		if _row_id(_sel) == "day":
			Difficulty.cycle_day_scale(1)
		else:
			Msp.cycle_pace(1)  # X10
		_canvas.queue_redraw()
		return
	if _row_id(_sel) == "outfit":
		close()
		Toolbox.open_outfit.call_deferred()
		return
	if _row_id(_sel) in ["career", "free"]:
		var free_menu := _row_id(_sel) == "free"
		close()
		if free_menu:
			Toolbox.open_free_menu.call_deferred()
		else:
			Career.open_screen.call_deferred()
		return
	if _sel == _labels().size() - 1:
		_confirm = true
		_sel = 0
		_canvas.queue_redraw()
		return
	match _sel:
		0:
			close()
		1:
			_page = 0
		2:
			Game.cycle_format()
		3:
			Game.set_text_large(not Game.text_large)
		4:
			Game.set_high_contrast(not Game.high_contrast)
	_canvas.queue_redraw()


func _panel() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var h := 100.0 + (12.0 if Campaign.active else (36.0 if Campaign.mode == Campaign.FREE else 0.0))  # (76 before the TEXT and CONTRAST rows)
	if Campaign.active and Campaign.mode == "tech":
		h += 12.0  # the TICKET PACE row
	if settings_mode:
		h = 148.0  # ten rows with TEXT, CONTRAST and DISPLAY
	if _page >= 0:
		h = 108.0
	elif _confirm:
		h = 64.0
	return UiStyle.panel_rect(size, 172.0, h)


# how many rows the panel shows at once (all of them unless the screen is so short that they would be thinner than ROW_MIN),
# and the first one: the list scrolls so the selected row is always on screen (R42: ten SETTINGS rows on a 112 px picture)
func _vis() -> int:
	var top := 16.0 + (14.0 if _confirm else 0.0)
	return clampi(int((_panel().size.y - top - 9.0) / ROW_MIN), 1, maxi(1, _labels().size()))


func _first_row() -> int:
	return clampi(_sel - _vis() + 1, 0, maxi(0, _labels().size() - _vis()))


func _row_rect(i: int) -> Rect2:
	var top := 16.0 + (14.0 if _confirm else 0.0)
	var body := _panel().position + Vector2(4.0, top)
	# the 128 px high format gives the panel 114 px: the ten SETTINGS rows get 8 px each there, or the last one
	# (CAREER) sat under the footer line; a shorter picture scrolls
	var vis := _vis()
	var first := _first_row()
	if i < first or i >= first + vis:
		return Rect2()
	var row_h := minf(ROW_H, floorf((_panel().size.y - top - 9.0) / float(vis)))
	return Rect2(body.x, body.y + row_h * float(i - first), _panel().size.x - 8.0, row_h - 1.0)


func _turn_page(step: int) -> void:
	if _page == REMAP_PAGE:
		return
	_page = posmod(_page + step, Controls.HELP.size())
	_canvas.queue_redraw()


# the remap list: up / down pick an action, Enter waits for a key (ESC cancels), the last row puts every key back
func _remap_key(event: InputEvent) -> void:
	var walk: int = Controls.REMAPPABLE.size()
	var rows: int = walk + Controls.MENU_ROLES.size() + 1
	Controls.capturing = _capture
	if _capture:
		if event is InputEventKey:
			if Controls.word(event) != "esc":
				var done: bool
				if _rsel < walk:
					done = Controls.rebind(str(Controls.REMAPPABLE[_rsel]), Controls.physical(event))
				else:
					done = Controls.rebind_menu(str(Controls.MENU_ROLES[_rsel - walk][0]), Controls.physical(event))
				if done:
					Controls.save_binds()
			_capture = false
		elif event is InputEventJoypadButton and event.device == 0 and _rsel < walk:
			if Controls.rebind_button(str(Controls.REMAPPABLE[_rsel]), int(event.button_index)):
				Controls.save_binds()
			_capture = false
		Controls.capturing = _capture
		return
	var up: bool = Controls.nav(event) == "up"  # arrows, W A S D, the D-pad or the stick
	var down: bool = Controls.nav(event) == "down"
	if Controls.back(event) or Controls.matches(event, "pause"):
		_page = 0
	elif up:
		_rsel = (_rsel + rows - 1) % rows
	elif down:
		_rsel = (_rsel + 1) % rows
	elif Controls.confirm(event):
		if _rsel == rows - 1:
			Controls.reset_binds()
			Controls.save_binds()
		else:
			_capture = true


func _paint_remap(c: CanvasItem, r: Rect2) -> void:
	var walk: int = Controls.REMAPPABLE.size()
	var rows: int = walk + Controls.MENU_ROLES.size() + 1
	var body := UiStyle.panel(c, r, Controls.keys("REMAP {KEYS|BUTTONS}"), Controls.keys("PRESS A {KEY|BUTTON}") if _capture else "")
	var first := clampi(_rsel - 2, 0, maxi(0, rows - 6))
	for k in mini(6, rows - first):
		var i := first + k
		var rr := Rect2(body.position.x, body.position.y + ROW_H * float(k) - 2.0, r.size.x - 8.0, ROW_H - 1.0)
		if i == _rsel:
			c.draw_rect(rr, UiStyle.HEAD)
		var col: Color = UiStyle.WHITE if i == _rsel else UiStyle.INK
		if i == rows - 1:
			UiStyle.text(c, "PUT ALL {KEYS|BUTTONS} BACK", rr.position.x + 3.0, rr.position.y + 3.0, col)
		elif i >= walk:
			var role: Array = Controls.MENU_ROLES[i - walk]
			UiStyle.text(c, str(role[2]), rr.position.x + 3.0, rr.position.y + 3.0, col)
			var extra := Controls.menu_key_of(str(role[0]))
			var shown := "..." if (_capture and i == _rsel) else (Controls.key_name(extra) if extra > 0 and not Controls.pad_active else "-")
			UiStyle.text(c, shown, rr.position.x + rr.size.x - 4.0 - float(shown.length() * 4), rr.position.y + 3.0, col)
		else:
			var action := str(Controls.REMAPPABLE[i])
			UiStyle.text(c, action.replace("_", " ").to_upper(), rr.position.x + 3.0, rr.position.y + 3.0, col)
			var key_name := "..." if (_capture and i == _rsel) else Controls.key_name(Controls.key_of(action))
			var end_x := rr.position.x + rr.size.x - 4.0
			if Controls.pad_active and not (_capture and i == _rsel):  # R42: on a pad the row shows what the pad has for it, no key
				key_name = ""
				if not Controls.REMAPPABLE_PAD.has(action):
					var shown_pad: String = Controls.pad_label(action) if Controls.pad_label(action) != "" else "-"
					PadGlyphs.draw(c, shown_pad, Vector2(end_x - float(PadGlyphs.width(shown_pad)), rr.position.y + 3.0), col)
			if Controls.REMAPPABLE_PAD.has(action) and not (_capture and i == _rsel):
				var pad_name := Controls.button_name(Controls.button_of(action))
				var gi := PadGlyphs.NAMES.find(pad_name) if PadGlyphs.atlas() != null else -1
				if gi >= 0:  # the pad button as its glyph, right of the key
					end_x -= float(PadGlyphs.WIDTHS[gi])
					PadGlyphs.glyph(c, pad_name, Vector2(end_x, rr.position.y + 2.0))
					end_x -= 6.0
				else:
					key_name = (key_name + "  " + pad_name).strip_edges()
			UiStyle.text(c, key_name, end_x - float(key_name.length() * 4), rr.position.y + 3.0, col)
	UiStyle.footer(c, r, Controls.hint("ENTER, THEN {KEY / BUTTON|A BUTTON}  ESC = BACK"))


func _input(event: InputEvent) -> void:
	if not is_open:
		if event is InputEventKey and event.pressed and not event.echo:
			var esc: bool = Controls.word(event) == "esc" and can_open(true)
			var brk: bool = Controls.matches(event, "pause") and can_open(false)
			if esc or brk:
				open()
				get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and Controls.matches(event, "pause") and can_open(false):
			open()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo or event is InputEventJoypadButton and event.pressed:
		_key(event)
	elif event is InputEventJoypadMotion and Controls.nav(event) != "":  # the stick moves the cursor too (R14: pad-only play)
		_key(event)
	elif event is InputEventMouseMotion and _page < 0:
		for i in _labels().size():
			if _row_rect(i).has_point(event.position) and _sel != i:
				_sel = i
				_canvas.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _page >= 0:
			_turn_page(1)
			return
		for i in _labels().size():
			if _row_rect(i).has_point(event.position):
				_sel = i
				_activate()
				return


func _key(event: InputEvent) -> void:
	var n := _labels().size()
	if _page == REMAP_PAGE:
		_remap_key(event)
		_canvas.queue_redraw()
		return
	var left: bool = Controls.nav(event) == "left"
	var right: bool = Controls.nav(event) == "right"
	var up: bool = Controls.nav(event) == "up"  # arrows, W A S D, the D-pad or the stick
	var down: bool = Controls.nav(event) == "down"
	if Controls.matches(event, "pause") or Controls.back(event):
		if _page >= 0:
			_page = -1
			_sel = 1
		elif _confirm:
			_confirm = false
			_sel = _labels().size() - 1
		else:
			close()
	elif _page >= 0 and (Controls.word(event) == "r" or (event is InputEventJoypadButton and Controls.matches(event, "hold_pose"))):
		_page = REMAP_PAGE
		_rsel = 0
		_capture = false
	elif _page >= 0:
		if left or up:
			_turn_page(-1)
		elif right or down or Controls.confirm(event):
			_turn_page(1)
	elif up:
		_sel = (_sel + n - 1) % n
	elif down:
		_sel = (_sel + 1) % n
	elif left or right:
		if not _confirm and _sel == 2:
			Game.cycle_format()
		elif not _confirm and _row_id(_sel) == "text":
			Game.set_text_large(not Game.text_large)
		elif not _confirm and _row_id(_sel) == "contrast":
			Game.set_high_contrast(not Game.high_contrast)
		elif settings_mode and _row_id(_sel) == "display":
			Game.set_fullscreen(not Game.fullscreen)
		elif settings_mode and _row_id(_sel) == "sound":
			Sfx.toggle_mute()
		elif settings_mode and _row_id(_sel) == "focus":
			Game.set_focus_pause(not Game.focus_pause)
		elif not _confirm and _row_id(_sel) == "day":
			Difficulty.cycle_day_scale(1 if right else -1)
		elif not _confirm and _row_id(_sel) == "pace":
			Msp.cycle_pace(1 if right else -1)
	elif Controls.confirm(event):
		_activate()
		return
	_canvas.queue_redraw()


func _paint() -> void:
	if not is_open:
		return
	var c := _canvas
	var size := get_viewport().get_visible_rect().size
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var r := _panel()
	if _page == REMAP_PAGE:
		_paint_remap(c, r)
		return
	if _page >= 0:
		_paint_help(c, r)
		return
	var body := UiStyle.panel(c, r, "SETTINGS" if settings_mode else "PAUSED", "QUIT?" if _confirm else ("COZY" if Difficulty.cozy_on() else ""))
	if _confirm:
		var line := "YOUR LAST SAVE IS KEPT" if Campaign.active else "FREE PLAY IS NOT SAVED"
		if Campaign.active and not Campaign.can_snapshot():
			# no resume point can be written right now (a card is waiting, a drive, overtime): say how far the save goes
			var info: Dictionary = Campaign.resume_info(Campaign.mode, Campaign.slot)
			line = ("SAVED AS OF %s TODAY" % str(info.text)) if not info.is_empty() else "SAVED AS OF THIS MORNING"
		UiStyle.text(c, line, body.position.x, r.position.y + 14.0, UiStyle.MUTED)
	var labels := _labels()
	for i in labels.size():
		var rr := _row_rect(i)
		if rr.size == Vector2.ZERO:
			continue  # scrolled out of the window
		if i == _sel:
			c.draw_rect(rr, UiStyle.HEAD)
		UiStyle.text(c, labels[i], rr.position.x + 3.0, rr.position.y + floorf((rr.size.y - 5.0) * 0.5), UiStyle.WHITE if i == _sel else UiStyle.INK)
	if _vis() < labels.size():  # more rows above or below: a small marker at the right edge
		var mx := r.end.x - 9.0
		if _first_row() > 0:
			c.draw_colored_polygon(PackedVector2Array([Vector2(mx, r.position.y + 15.0), Vector2(mx + 5.0, r.position.y + 15.0), Vector2(mx + 2.5, r.position.y + 12.0)]), UiStyle.MUTED)
		if _first_row() + _vis() < labels.size():
			c.draw_colored_polygon(PackedVector2Array([Vector2(mx, r.end.y - 11.0), Vector2(mx + 5.0, r.end.y - 11.0), Vector2(mx + 2.5, r.end.y - 8.0)]), UiStyle.MUTED)
	var foot := "ENTER = OK  ESC = BACK" if (_confirm or settings_mode) else "ENTER = OK  ESC = RESUME"
	if not _confirm and (_row_id(_sel) == "text" or _row_id(_sel) == "contrast"):
		foot = "LEFT RIGHT = CHANGE  ESC = BACK"
	if not _confirm and _row_id(_sel) == "day":
		foot = "NEXT MORNING  LEFT RIGHT = CHANGE"
	elif not _confirm and _row_id(_sel) == "pace":
		foot = "HOW MANY TICKETS  LEFT RIGHT = CHANGE"
	UiStyle.footer(c, r, Controls.hint(foot))


# one page of the key list: what you do on the left, the key on the right
func _paint_help(c: CanvasItem, r: Rect2) -> void:
	var page: Array = Controls.HELP[_page]
	var body := UiStyle.panel(c, r, str(page[0]), "%d / %d" % [_page + 1, Controls.HELP.size()])
	var y := body.position.y + 2.0
	for row in page[1]:
		UiStyle.text(c, str(row[0]), body.position.x, y, UiStyle.INK)
		var value := Controls.help_value(str(row[0]), str(row[1]))  # on a pad: the button that does it (drawn as a glyph)
		PadGlyphs.draw(c, value, Vector2(body.end.x - float(PadGlyphs.width(value)), y), UiStyle.HEAD)
		y += 9.0
	UiStyle.footer(c, r, Controls.hint("ARROWS = PAGE  R = REMAP  ESC = BACK", {"R": "hold_pose"}))
