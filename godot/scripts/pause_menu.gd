extends CanvasLayer
# Autoload: the pause menu. ESC (or the Pause key) while you are walking around a room stops everything: the clock,
# the cast, the tickets, the SLA timers (the whole scene tree is paused; this node alone keeps running).
# Rows: RESUME, CONTROLS (the key list, 3 pages, Left / Right turn them), SHAPE (the output format, same as F9),
# QUIT TO TITLE (asks first; a campaign keeps its last end-of-day save). The key list lives in Controls.HELP.
# ESC does nothing here while a computer, phone, card, outing, report or other screen is open: those use ESC themselves.
# The Pause key works over those too, except on the title and character select screens.

const UiStyle := preload("res://scripts/ui_style.gd")

const ROW_H := 12.0
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
		return ["BACK", "CONTROLS", "SHAPE: %s" % Game.format.to_upper(), "SOUND: %s" % ("OFF" if Sfx.muted else "ON"), "DAY LENGTH: %s" % Difficulty.day_label(), "CAREER"]
	if _confirm:
		return ["NO, KEEP PLAYING", "YES, QUIT"]
	var rows := ["RESUME", "CONTROLS", "SHAPE: %s" % Game.format.to_upper()]
	if Campaign.active:
		rows.append("DAY LENGTH: %s" % Difficulty.day_label())  # R16: 5 / 10 / 15 minutes, starts at the next morning
		if Campaign.mode == "tech":
			rows.append("TICKET PACE: %s" % Msp.pace_label())  # X10: relaxed / normal / busy, at once
	elif Campaign.mode == Campaign.FREE:  # Free Play (R15 level 3 step e): change your look
		rows.append("OUTFIT")
		rows.append("CAREER")  # a pad has no free button for the J key, so the career screen is reachable from here too
	rows.append("QUIT TO TITLE")
	return rows


# the id of a menu row (the rows move with the mode): "resume", "controls", "shape", "day", "outfit", "quit"
func _row_id(i: int) -> String:
	if settings_mode:
		return ["resume", "controls", "shape", "sound", "day", "career"][clampi(i, 0, 5)]
	var ids := ["resume", "controls", "shape"]
	if Campaign.active:
		ids.append("day")
		if Campaign.mode == "tech":
			ids.append("pace")
	elif Campaign.mode == Campaign.FREE:
		ids.append("outfit")
		ids.append("career")
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
			"sound":
				Sfx.toggle_mute()
			"day":
				Difficulty.cycle_day_scale(1)
			"career":
				close()
				Career.open_screen.call_deferred()
		_canvas.queue_redraw()
		return
	if _confirm:
		if _sel == 1:
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
	if _row_id(_sel) == "career":
		close()
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
	_canvas.queue_redraw()


func _panel() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var h := 76.0 + (12.0 if Campaign.active else (24.0 if Campaign.mode == Campaign.FREE else 0.0))
	if Campaign.active and Campaign.mode == "tech":
		h += 12.0  # the TICKET PACE row
	if settings_mode:
		h = 100.0
	if _page >= 0:
		h = 108.0
	elif _confirm:
		h = 64.0
	return UiStyle.panel_rect(size, 172.0, h)


func _row_rect(i: int) -> Rect2:
	var body := _panel().position + Vector2(4.0, 16.0 + (14.0 if _confirm else 0.0))
	return Rect2(body.x, body.y + ROW_H * float(i), _panel().size.x - 8.0, ROW_H - 1.0)


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
			if event.keycode != KEY_ESCAPE:
				var done: bool
				if _rsel < walk:
					done = Controls.rebind(str(Controls.REMAPPABLE[_rsel]), int(event.physical_keycode))
				else:
					done = Controls.rebind_menu(str(Controls.MENU_ROLES[_rsel - walk][0]), int(event.physical_keycode))
				if done:
					Controls.save_binds()
			_capture = false
		elif event is InputEventJoypadButton and event.device == 0 and _rsel < walk:
			if Controls.rebind_button(str(Controls.REMAPPABLE[_rsel]), int(event.button_index)):
				Controls.save_binds()
			_capture = false
		Controls.capturing = _capture
		return
	var up: bool = event.is_action("ui_up") or (event is InputEventKey and event.keycode in [KEY_UP, KEY_W])
	var down: bool = event.is_action("ui_down") or (event is InputEventKey and event.keycode in [KEY_DOWN, KEY_S])
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
	var body := UiStyle.panel(c, r, "REMAP KEYS", "PRESS A KEY" if _capture else "")
	var first := clampi(_rsel - 2, 0, maxi(0, rows - 6))
	for k in mini(6, rows - first):
		var i := first + k
		var rr := Rect2(body.position.x, body.position.y + ROW_H * float(k) - 2.0, r.size.x - 8.0, ROW_H - 1.0)
		if i == _rsel:
			c.draw_rect(rr, UiStyle.HEAD)
		var col: Color = UiStyle.WHITE if i == _rsel else UiStyle.INK
		if i == rows - 1:
			UiStyle.text(c, "PUT ALL KEYS BACK", rr.position.x + 3.0, rr.position.y + 3.0, col)
		elif i >= walk:
			var role: Array = Controls.MENU_ROLES[i - walk]
			UiStyle.text(c, str(role[2]), rr.position.x + 3.0, rr.position.y + 3.0, col)
			var extra := Controls.menu_key_of(str(role[0]))
			var shown := "..." if (_capture and i == _rsel) else (Controls.key_name(extra) if extra > 0 else "-")
			UiStyle.text(c, shown, rr.position.x + rr.size.x - 4.0 - float(shown.length() * 4), rr.position.y + 3.0, col)
		else:
			var action := str(Controls.REMAPPABLE[i])
			UiStyle.text(c, action.replace("_", " ").to_upper(), rr.position.x + 3.0, rr.position.y + 3.0, col)
			var key_name := "..." if (_capture and i == _rsel) else Controls.key_name(Controls.key_of(action))
			if Controls.REMAPPABLE_PAD.has(action) and not (_capture and i == _rsel):
				key_name += "  " + Controls.button_name(Controls.button_of(action))
			UiStyle.text(c, key_name, rr.position.x + rr.size.x - 4.0 - float(key_name.length() * 4), rr.position.y + 3.0, col)
	UiStyle.footer(c, r, "ENTER, THEN KEY / BUTTON  ESC = BACK")


func _input(event: InputEvent) -> void:
	if not is_open:
		if event is InputEventKey and event.pressed and not event.echo:
			var esc: bool = event.keycode == KEY_ESCAPE and can_open(true)
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
	var left: bool = event.is_action("ui_left") or (event is InputEventKey and event.keycode in [KEY_LEFT, KEY_A])
	var right: bool = event.is_action("ui_right") or (event is InputEventKey and event.keycode in [KEY_RIGHT, KEY_D])
	var up: bool = event.is_action("ui_up") or (event is InputEventKey and event.keycode in [KEY_UP, KEY_W])
	var down: bool = event.is_action("ui_down") or (event is InputEventKey and event.keycode in [KEY_DOWN, KEY_S])
	if Controls.matches(event, "pause") or Controls.back(event):
		if _page >= 0:
			_page = -1
			_sel = 1
		elif _confirm:
			_confirm = false
			_sel = _labels().size() - 1
		else:
			close()
	elif _page >= 0 and event is InputEventKey and event.keycode == KEY_R:
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
		elif settings_mode and _row_id(_sel) == "sound":
			Sfx.toggle_mute()
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
		UiStyle.text(c, line, body.position.x, r.position.y + 14.0, UiStyle.MUTED)
	var labels := _labels()
	for i in labels.size():
		var rr := _row_rect(i)
		if i == _sel:
			c.draw_rect(rr, UiStyle.HEAD)
		UiStyle.text(c, labels[i], rr.position.x + 3.0, rr.position.y + 3.0, UiStyle.WHITE if i == _sel else UiStyle.INK)
	var foot := "ENTER = OK  ESC = BACK" if (_confirm or settings_mode) else "ENTER = OK  ESC = RESUME"
	if not _confirm and _row_id(_sel) == "day":
		foot = "NEXT MORNING  LEFT RIGHT = CHANGE"
	elif not _confirm and _row_id(_sel) == "pace":
		foot = "HOW MANY TICKETS  LEFT RIGHT = CHANGE"
	UiStyle.footer(c, r, foot)


# one page of the key list: what you do on the left, the key on the right
func _paint_help(c: CanvasItem, r: Rect2) -> void:
	var page: Array = Controls.HELP[_page]
	var body := UiStyle.panel(c, r, str(page[0]), "%d / %d" % [_page + 1, Controls.HELP.size()])
	var y := body.position.y + 2.0
	for row in page[1]:
		UiStyle.text(c, str(row[0]), body.position.x, y, UiStyle.INK)
		UiStyle.right(c, Controls.help_value(str(row[0]), str(row[1])), body.end.x, y, UiStyle.HEAD)
		y += 9.0
	UiStyle.footer(c, r, "ARROWS = PAGE  R = REMAP  ESC = BACK")
