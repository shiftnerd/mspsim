extends CanvasLayer
# gdlint:disable=max-line-length
# The first touch overlay (roadmap R14, item 4). Only made on a touch screen (Controls.touch_on(): the display server
# says so, or Controls.touch_override = 1 in a test): a virtual stick at the bottom left, two action buttons at the
# bottom right, a MENU button at the top right, and two small buttons that come and go: NEXT (the next target in
# reach) and ROLL (seated: hold it and push the stick to roll the chair).
# It owns no game logic. Every control sends the event a pad would send (device 0), so it feeds the very same
# Controls actions and everything a pad reaches, a finger reaches:
#   stick   left stick axes              move, duck, the menus' up / down / left / right
#   A       pad A                        jump, confirm
#   USE     pad X  (walking around)      use, sit, doors, talk
#   BACK    pad B  (a screen is open)    back, cancel
#   MENU    pad Start                    the pause menu
#   NEXT    pad RB                       pick the next target
#   ROLL    the left trigger             the roll action
# A touch that lands on a control is kept from the screens below (the mouse events the engine makes up from a touch
# are swallowed there), so a tap on the stick never clicks a menu row under it. Touches anywhere else go through as
# the mouse clicks every screen already takes.

const PixelFont := preload("res://scripts/pixelfont.gd")
const STICK_R := 22.0  # the stick's base radius; the knob travels this far
const DEAD := 0.35  # of the radius: inside it the stick is centred
const BTN := Vector2(26.0, 24.0)  # a thumb needs 19 to 24 px
const INK := Color(0.06, 0.05, 0.1, 0.55)
const FACE := Color(1.0, 1.0, 1.0, 0.28)
const LIT := Color(1.0, 0.88, 0.54, 0.6)

var stick_touch := -1  # the finger on the stick (-1 = none)
var stick_vec := Vector2.ZERO  # -1..1 on each axis, what the game sees
var held := {}  # finger index -> the id of the button under it

var _canvas: Node2D
var _sent := Vector2.ZERO  # the axis values last sent
var _ctx := ""


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu is driven by it too
	_canvas = Node2D.new()
	add_child(_canvas)
	_canvas.draw.connect(_paint)


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


# a screen has the keys: the second button is BACK, and NEXT / ROLL are away
func in_menu() -> bool:
	return Game.ui_open or Game.title_mode or get_tree().paused or Cards.is_open or DayReport.is_open


func seated() -> bool:
	var scene := get_tree().current_scene
	var p: Node = Players.player0(scene) if scene != null else null
	return p != null and str(p.get("state")) == "sitting"


func stick_center() -> Vector2:
	return Vector2(10.0 + STICK_R, _size().y - 14.0 - STICK_R)


# id -> Rect2 of every button shown now (the stick is a circle: stick_center, STICK_R)
func buttons() -> Dictionary:
	var s := _size()
	var out := {
		"a": Rect2(s.x - BTN.x - 4.0, s.y - BTN.y - 22.0, BTN.x, BTN.y),
		"b": Rect2(s.x - 2.0 * BTN.x - 8.0, s.y - BTN.y - 12.0, BTN.x, BTN.y),
		"menu": Rect2(s.x - BTN.x - 2.0, 14.0, BTN.x, 19.0),
	}
	if not in_menu():
		out["next"] = Rect2(s.x - BTN.x - 4.0, s.y - 2.0 * BTN.y - 26.0, BTN.x, 20.0)
		if seated():
			out["roll"] = Rect2(s.x - 2.0 * BTN.x - 8.0, s.y - 2.0 * BTN.y - 16.0, BTN.x, 20.0)
	return out


func label_of(id: String) -> String:
	if id == "b":  # the pad letters, so they match the hint lines ("(A) PICK  (B) BACK")
		return "B" if in_menu() else "X"
	return id.to_upper()


# the control under a point: "stick", a button id, or ""
func control_at(at: Vector2) -> String:
	if at.distance_to(stick_center()) <= STICK_R + 8.0:
		return "stick"
	var list := buttons()
	for id in list:
		if (list[id] as Rect2).has_point(at):
			return str(id)
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		if event.index == stick_touch:
			_stick_to(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		# the mouse event the engine makes from a touch: not for the screens below when it is on a control
		if stick_touch >= 0 or not held.is_empty() or control_at(event.position) != "":
			get_viewport().set_input_as_handled()


func _touch_down(index: int, at: Vector2) -> void:
	var what := control_at(at)
	if what == "":
		return
	get_viewport().set_input_as_handled()
	if what == "stick":
		stick_touch = index
		_stick_to(at)
	else:
		held[index] = what
		_send_button(what, true)
	_canvas.queue_redraw()


func _touch_up(index: int) -> void:
	if index == stick_touch:
		stick_touch = -1
		_set_stick(Vector2.ZERO)
		get_viewport().set_input_as_handled()
	elif held.has(index):
		_send_button(str(held[index]), false)
		held.erase(index)
		get_viewport().set_input_as_handled()
	_canvas.queue_redraw()


func _stick_to(at: Vector2) -> void:
	var v := (at - stick_center()) / STICK_R
	if v.length() > 1.0:
		v = v.normalized()
	_set_stick(v if v.length() >= DEAD else Vector2.ZERO)
	_canvas.queue_redraw()


# the stick as a pad's left stick: each axis is sent when it changes side (-1, 0, 1), which is what the menus and the
# walking actions read
func _set_stick(v: Vector2) -> void:
	stick_vec = v
	var want := Vector2(signf(v.x) if absf(v.x) >= 0.5 else 0.0, signf(v.y) if absf(v.y) >= 0.5 else 0.0)
	if want.x != _sent.x:
		_send_axis(JOY_AXIS_LEFT_X, want.x)
	if want.y != _sent.y:
		_send_axis(JOY_AXIS_LEFT_Y, want.y)
	_sent = want


func _send_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _send_button(id: String, down: bool) -> void:
	if id == "roll":
		_send_axis(JOY_AXIS_TRIGGER_LEFT, 1.0 if down else 0.0)
		return
	var button := JOY_BUTTON_A
	match id:
		"b":
			button = JOY_BUTTON_B if in_menu() else JOY_BUTTON_X
		"menu":
			button = JOY_BUTTON_START
		"next":
			button = JOY_BUTTON_RIGHT_SHOULDER
	if not down and id == "b":
		# the screen may have closed (or opened) while the finger was down: let go of both
		for both in [JOY_BUTTON_B, JOY_BUTTON_X]:
			_send_pad(both, false)
		return
	_send_pad(button, down)


func _send_pad(button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = down
	ev.pressure = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func _process(_delta: float) -> void:
	var ctx := "%s %s %s" % [in_menu(), seated(), _size()]
	if ctx != _ctx:
		_ctx = ctx
		_canvas.queue_redraw()


func _paint() -> void:
	var c := stick_center()
	_canvas.draw_circle(c, STICK_R + 1.0, INK)
	_canvas.draw_circle(c, STICK_R, Color(1.0, 1.0, 1.0, 0.12))
	_canvas.draw_circle(c + stick_vec * (STICK_R - 8.0), 9.0, LIT if stick_touch >= 0 else FACE)
	var list := buttons()
	for id in list:
		var r: Rect2 = list[id]
		var down: bool = held.values().has(id)
		_canvas.draw_rect(Rect2(r.position - Vector2.ONE, r.size + Vector2(2.0, 2.0)), INK)
		_canvas.draw_rect(r, LIT if down else FACE)
		var text := label_of(str(id))
		var at := r.position + Vector2(floorf((r.size.x - float(PixelFont.width(text))) * 0.5), floorf((r.size.y - 5.0) * 0.5))
		PixelFont.draw(_canvas, text, at + Vector2.ONE, INK)
		PixelFont.draw(_canvas, text, at, Color.WHITE)
