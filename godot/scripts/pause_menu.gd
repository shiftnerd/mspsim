extends CanvasLayer
# Autoload: the pause menu. ESC (or the Pause key) while you are walking around a room stops everything: the clock,
# the cast, the tickets, the SLA timers (the whole scene tree is paused; this node alone keeps running).
# Rows: RESUME, SHAPE (the output format, same as F9), QUIT TO TITLE (asks first; a campaign keeps its last end-of-day save).
# ESC does nothing here while a computer, phone, card, outing, report or other screen is open: those use ESC themselves.
# The Pause key works over those too, except on the title and character select screens.

const UiStyle := preload("res://scripts/ui_style.gd")

const ROWS := ["RESUME", "SHAPE", "QUIT TO TITLE"]
const ROW_H := 12.0

var is_open := false

var _sel := 0
var _confirm := false
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
	return [ROWS[0], "SHAPE: %s" % Game.format.to_upper(), ROWS[2]]


func _activate() -> void:
	if _confirm:
		if _sel == 1:
			close()
			Game.go_title()
		else:
			_confirm = false
			_sel = 2
		_canvas.queue_redraw()
		return
	match _sel:
		0:
			close()
		1:
			Game.cycle_format()
		2:
			_confirm = true
			_sel = 0
	_canvas.queue_redraw()


func _panel() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	return UiStyle.panel_rect(size, 150.0, 76.0 if not _confirm else 88.0)


func _row_rect(i: int) -> Rect2:
	var body := _panel().position + Vector2(4.0, 16.0 + (14.0 if _confirm else 0.0))
	return Rect2(body.x, body.y + ROW_H * float(i), _panel().size.x - 8.0, ROW_H - 1.0)


func _input(event: InputEvent) -> void:
	if not is_open:
		if event is InputEventKey and event.pressed and not event.echo:
			var esc: bool = event.keycode == KEY_ESCAPE and can_open(true)
			var brk: bool = event.keycode == KEY_PAUSE and can_open(false)
			if esc or brk:
				open()
				get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var n := _labels().size()
		match event.keycode:
			KEY_ESCAPE, KEY_PAUSE:
				if _confirm:
					_confirm = false
					_sel = 2
					_canvas.queue_redraw()
				else:
					close()
			KEY_UP, KEY_W:
				_sel = (_sel + n - 1) % n
				_canvas.queue_redraw()
			KEY_DOWN, KEY_S:
				_sel = (_sel + 1) % n
				_canvas.queue_redraw()
			KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D:
				if not _confirm and _sel == 1:
					Game.cycle_format()
					_canvas.queue_redraw()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				_activate()
	elif event is InputEventMouseMotion:
		for i in _labels().size():
			if _row_rect(i).has_point(event.position) and _sel != i:
				_sel = i
				_canvas.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _labels().size():
			if _row_rect(i).has_point(event.position):
				_sel = i
				_activate()
				return


func _paint() -> void:
	if not is_open:
		return
	var c := _canvas
	var size := get_viewport().get_visible_rect().size
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var r := _panel()
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
