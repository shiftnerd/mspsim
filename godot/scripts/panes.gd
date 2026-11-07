extends CanvasLayer
# gdlint:disable=class-definitions-order,max-line-length,unsafe-method-access
# Co-op phase 3a (docs/scope-coop.md): the takeover host. In co-op each player's computer opens as its own pane: a Computer
# instance (computer.gd with pane_slot set) living in a SubViewport. The two panes share the bottom of the window, slot 0 on
# the left and slot 1 on the right, under the strip of the office the single-player screens already leave at the top (the
# camera slides down by Game.ui_shift, so both bodies stay visible there). A pane freezes only its own player
# (Players.ui[slot]); the room, the other player and the sim keep going.
# Input is routed by this host, never by the engine: a mouse event goes to the pane under it, keys to slot 0's pane and a
# pad to the pane of the slot that joined on it. A pad player has no mouse, so the right stick moves a cursor in the pane
# and A clicks where it is (the same Computer.click() a mouse uses); B and the D-pad / left stick go through as the usual
# back and navigation. Pad A / B events of slot 1 are passed on as device 0 so ui_accept / ui_cancel match them.

const COMPUTER := preload("res://scripts/computer.gd")
const CURSOR_SPEED := 150.0  # px / s at full stick
const DEADZONE := 0.25

var panes := {}  # slot -> {sv, view, comp, stick}
var _scene: Node = null


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


# the strip of the office kept above the panes, as Computer paints it for the full-window screen
func region() -> Rect2:
	var s := get_viewport().get_visible_rect().size
	var top := maxf(12.0, floorf(s.y * Game.UI_STRIP))
	return Rect2(0.0, top, s.x, s.y - top)


func pane_rect(slot: int) -> Rect2:
	var r := region()
	var half := floorf(r.size.x * 0.5)
	if slot <= 0:
		return Rect2(r.position, Vector2(half, r.size.y))
	return Rect2(r.position + Vector2(half, 0.0), Vector2(r.size.x - half, r.size.y))


func is_open(slot: int) -> bool:
	return panes.has(slot) and panes[slot].comp.is_open


func computer(slot: int) -> Node:
	return panes[slot].comp if panes.has(slot) else null


func open_computer(slot: int, desk: int) -> Node:
	var p := _pane(slot)
	p.comp.open(desk)
	p.comp._mouse = pane_rect(slot).size * 0.5 if slot > 0 else p.comp._mouse
	return p.comp


func close_all() -> void:
	for slot in panes:
		var c: Node = panes[slot].comp
		if c.is_open:
			c.close()


func _pane(slot: int) -> Dictionary:
	if panes.has(slot):
		return panes[slot]
	if _scene == null:
		_scene = get_tree().current_scene
	var rect := pane_rect(slot)
	var sv := SubViewport.new()
	sv.size = Vector2i(rect.size)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sv)
	var comp: Node = COMPUTER.new()
	comp.pane_slot = slot
	sv.add_child(comp)
	var view := TextureRect.new()
	view.texture = sv.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.visible = false
	add_child(view)
	panes[slot] = {"sv": sv, "view": view, "comp": comp, "stick": Vector2.ZERO}
	_place(slot)
	return panes[slot]


func _place(slot: int) -> void:
	var p: Dictionary = panes[slot]
	var rect := pane_rect(slot)
	if Vector2i(rect.size) != p.sv.size:
		p.sv.size = Vector2i(rect.size)
	p.view.position = rect.position
	p.view.size = rect.size


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:  # a room change closes the panes (a door refusal for a busy partner is a later slice)
		_scene = scene
		close_all()
	for slot in panes:
		var p: Dictionary = panes[slot]
		var comp: Node = p.comp
		var shown: bool = comp._canvas.visible
		p.view.visible = shown
		p.sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		if not shown:
			continue
		_place(slot)
		if comp.is_open and slot > 0 and p.stick != Vector2.ZERO:
			var size := Vector2(p.sv.size)
			comp._mouse = (comp._mouse + p.stick * CURSOR_SPEED * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
			comp._canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if panes.is_empty():
		return
	var slot := -1
	var out: InputEvent = event
	if event is InputEventMouse:
		for s in panes:
			if is_open(s) and pane_rect(s).has_point(event.position):
				slot = s
		if slot < 0:
			return
		out = event.duplicate()
		out.position = event.position - pane_rect(slot).position
		out.global_position = out.position
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		slot = Players.slot_of(event)
		if slot < 0 or not is_open(slot):
			return
		if slot > 0 and _pad_cursor(slot, event):
			get_viewport().set_input_as_handled()
			return
		if slot > 0 and event is InputEventJoypadButton:
			out = event.duplicate()
			out.device = 0  # the ui_accept / ui_cancel pad events are registered for pad 0
	elif event is InputEventKey:
		slot = 0
		if not is_open(0):
			return
	else:
		return
	panes[slot].sv.push_input(out, true)
	get_viewport().set_input_as_handled()


# the right stick moves the cursor of a pad player's pane, A clicks where it is. True when the event was used up.
func _pad_cursor(slot: int, event: InputEvent) -> bool:
	var p: Dictionary = panes[slot]
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_X or event.axis == JOY_AXIS_RIGHT_Y:
			var v: Vector2 = p.stick
			var val: float = event.axis_value if absf(event.axis_value) > DEADZONE else 0.0
			if event.axis == JOY_AXIS_RIGHT_X:
				v.x = val
			else:
				v.y = val
			p.stick = v
			return true
		return false
	if event.button_index == JOY_BUTTON_A:
		if event.pressed:
			p.comp.click(p.comp._mouse)
		return true
	return false
