extends CanvasLayer
# Autoload: the pause menu. ESC (or the Pause key) while you are walking around a room stops everything: the clock,
# the cast, the tickets, the SLA timers (the whole scene tree is paused; this node alone keeps running).
# Rows: RESUME, CONTROLS (the key list, 3 pages, Left / Right turn them), SHAPE (the output format, same as F9),
# QUIT TO TITLE (asks first; a campaign keeps its last end-of-day save). The key list lives in Controls.HELP.
# ESC does nothing here while a computer, phone, card, outing, report or other screen is open: those use ESC themselves.
# The Pause key works over those too, except on the title and character select screens.

const UiStyle := preload("res://scripts/ui_style.gd")

const ROW_H := 12.0

var is_open := false

var _sel := 0
var _confirm := false
var _page := -1  # -1 = the menu, 0.. = a page of the controls list
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
	if scene == null or Game.title_mode or Game.busy or scene.get_node_or_null("Actors/Player") == null:
		return false
	if not strict:
		return true
	if Game.ui_open or Cards.is_open or DayReport.is_open or Outings.is_open or PrinterGame.is_open:
		return false
	return not (Review.is_open or Toolbox.is_open or Computer.is_open or Phone.is_open)


func open() -> void:
	if is_open:
		return
	is_open = true
	_sel = 0
	_confirm = false
	_page = -1
	visible = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	_canvas.queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false


func _labels() -> Array:
	if _confirm:
		return ["NO, KEEP PLAYING", "YES, QUIT"]
	return ["RESUME", "CONTROLS", "SHAPE: %s" % Game.format.to_upper(), "QUIT TO TITLE"]


func _activate() -> void:
	if _confirm:
		if _sel == 1:
			close()
			Game.go_title()
		else:
			_confirm = false
			_sel = 3
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
			_confirm = true
			_sel = 0
	_canvas.queue_redraw()


func _panel() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var h := 76.0
	if _page >= 0:
		h = 108.0
	elif _confirm:
		h = 64.0
	return UiStyle.panel_rect(size, 172.0, h)


func _row_rect(i: int) -> Rect2:
	var body := _panel().position + Vector2(4.0, 16.0 + (14.0 if _confirm else 0.0))
	return Rect2(body.x, body.y + ROW_H * float(i), _panel().size.x - 8.0, ROW_H - 1.0)


func _turn_page(step: int) -> void:
	_page = posmod(_page + step, Controls.HELP.size())
	_canvas.queue_redraw()


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
			_sel = 3
		else:
			close()
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
	if _page >= 0:
		_paint_help(c, r)
		return
	var body := UiStyle.panel(c, r, "PAUSED", "QUIT?" if _confirm else "")
	if _confirm:
		var line := "YOUR LAST SAVE IS KEPT" if Campaign.active else "FREE PLAY IS NOT SAVED"
		UiStyle.text(c, line, body.position.x, r.position.y + 14.0, UiStyle.MUTED)
	var labels := _labels()
	for i in labels.size():
		var rr := _row_rect(i)
		if i == _sel:
			c.draw_rect(rr, UiStyle.HEAD)
		UiStyle.text(c, labels[i], rr.position.x + 3.0, rr.position.y + 3.0, UiStyle.WHITE if i == _sel else UiStyle.INK)
	UiStyle.footer(c, r, "ENTER = OK  ESC = BACK" if _confirm else "ENTER = OK  ESC = RESUME")


# one page of the key list: what you do on the left, the key on the right
func _paint_help(c: CanvasItem, r: Rect2) -> void:
	var page: Array = Controls.HELP[_page]
	var body := UiStyle.panel(c, r, str(page[0]), "%d / %d" % [_page + 1, Controls.HELP.size()])
	var y := body.position.y + 2.0
	for row in page[1]:
		UiStyle.text(c, str(row[0]), body.position.x, y, UiStyle.INK)
		UiStyle.right(c, str(row[1]), body.end.x, y, UiStyle.HEAD)
		y += 9.0
	UiStyle.footer(c, r, "LEFT RIGHT = PAGE  ESC = BACK")
