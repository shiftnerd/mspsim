extends Node2D
# Title screen. A few vignettes rotate behind the MSPSim logo: the cast lined up in the office, two
# people on the phones at their desks, coffee and the fridge in the kitchenette, and a meeting in
# the conference room. Each one is the real room scene in "title mode" (no player, no World cast)
# with NPC nodes acting it out. Enter / Space / E / a click starts the game; F9 cycles the output
# format. The office clock is frozen until you start.

const NPC_SCENE := preload("res://scenes/npc.tscn")
const LOGO := preload("res://assets/ui/mspsim_logo.png")
const LOGO_SMALL := preload("res://assets/ui/mspsim_logo_s.png")
const PROMPT := preload("res://assets/ui/press_start.png")
const PixelFont := preload("res://scripts/pixelfont.gd")
const FLOOR_Y := 118.0
const SHOW_SECS := 9.0
const VIGNETTES := ["lineup", "phones", "kitchen", "conference"]
const ROOMS := {
	"lineup": "main_floor",
	"phones": "cubicle_area",
	"kitchen": "kitchenette",
	"conference": "conference"
}

var _cam: Camera2D
var _logo: Sprite2D
var _prompt: Sprite2D
var _fade: ColorRect
var _room: Node = null
var _index := 0
var _t := 0.0
var _busy := false
var _started := false
var _hud_was := true
var _menu_open := false
var _sel := 0
var _items: Array = []
var _menu: Node2D


func _ready() -> void:
	World.time_scale = 0.0
	_hud_was = World.hud_visible
	World.hud_visible = false
	Game.title_mode = true
	_cam = Camera2D.new()
	add_child(_cam)
	var back := CanvasLayer.new()
	back.layer = 10
	add_child(back)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.04, 0.08, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_fade)
	var front := CanvasLayer.new()
	front.layer = 20
	add_child(front)
	_logo = Sprite2D.new()
	_logo.centered = false
	front.add_child(_logo)
	_prompt = Sprite2D.new()
	_prompt.centered = false
	_prompt.texture = PROMPT
	front.add_child(_prompt)
	var blink := Timer.new()
	blink.wait_time = 0.55
	blink.autostart = true
	blink.timeout.connect(func() -> void: _prompt.visible = not _prompt.visible and not _menu_open)
	add_child(blink)
	_menu = Node2D.new()
	_menu.visible = false
	front.add_child(_menu)
	_menu.draw.connect(_draw_menu)
	Game.format_changed.connect(_on_format)
	show_vignette(0)


func _on_format() -> void:
	show_vignette(_index)


func _size() -> Vector2:
	return Vector2(Game.FORMATS[Game.format].size)


func _layout() -> void:
	var size := _size()
	var wide := size.x > 340.0 and size.y <= 130.0
	var narrow := size.x < 250.0
	var cam_y := 64.0 if size.y <= 130.0 else (50.0 if size.y <= 200.0 else 60.0)
	var cam_x := 184.0
	if VIGNETTES[_index] == "phones" and narrow:
		cam_x = 117.0  # the two desks
	_cam.zoom = Vector2.ONE
	_cam.position = Vector2(cam_x, cam_y)
	_logo.texture = LOGO_SMALL if narrow else LOGO
	var top := 4.0 if wide else (14.0 if not narrow else 24.0)
	_logo.position = Vector2(floorf((size.x - _logo.texture.get_width()) * 0.5), top)
	var pw := float(PROMPT.get_width())
	var ph := float(PROMPT.get_height())
	if wide:
		_prompt.position = Vector2(size.x - pw - 8.0, size.y - ph - 3.0)
	else:
		_prompt.position = Vector2(
			floorf((size.x - pw) * 0.5), size.y - ph - (17.0 if not narrow else 40.0)
		)


# build vignette number i (no fade; used at start, on a format change and by tests)
func show_vignette(i: int) -> void:
	_index = i % VIGNETTES.size()
	_t = 0.0
	if _room != null:
		remove_child(_room)
		_room.queue_free()
	var kind: String = VIGNETTES[_index]
	_room = load("res://scenes/%s.tscn" % ROOMS[kind]).instantiate()
	add_child(_room)
	_act(kind)
	_layout()


func _npc(who: String, facing: String, x: float, routine: Array, seat := "", item := "") -> void:
	var npc: Node = NPC_SCENE.instantiate()
	npc.character = who
	npc.facing = facing
	npc.routine = PackedStringArray(routine)
	npc.start_seat = seat
	npc.start_item = item
	npc.position = Vector2(x, FLOOR_Y)
	_room.get_node("Actors").add_child(npc)


func _act(kind: String) -> void:
	var data: Dictionary = World.DATA.SCENES[ROOMS[kind]]
	match kind:
		"lineup":
			var size := _size()
			var wide := size.x > 340.0 and size.y <= 130.0
			var narrow := size.x < 250.0
			var xs := (
				[150.0, 184.0, 218.0, -1.0]
				if narrow
				else ([128.0, 168.0, 208.0, -1.0] if wide else [142.0, 182.0, 270.0, 310.0])
			)
			var gap := ["talk:4", "wait:3"]
			_npc("casual_garrison", "left", xs[0], gap)
			_npc("office_alan", "right", xs[1], gap)
			_npc("office_dan", "left", xs[2], ["wait:3", "say:2", "wait:4"])
			if xs[3] >= 0.0:
				_npc("office_adult", "right", xs[3], ["wait:30"])
		"phones":
			_npc("casual_garrison", "right", data.seats.Seat1, ["wait:60"], "Seat1", "coffee")
			_npc("office_dan", "right", data.seats.Seat2, ["wait:60"], "Seat2")
			var phones := get_tree().get_nodes_in_group("phones")
			for i in phones.size():
				var zone: Node = phones[i]
				get_tree().create_timer(1.2 + 2.2 * i).timeout.connect(_ring.bind(zone))
		"kitchen":
			var u: Dictionary = data.uses
			_npc(
				"office_dan",
				"right",
				u.fridge + 40.0,
				[
					"walk:%d" % (u.fridge + 8),
					"use:fridge",
					"wait:1",
					"sip",
					"wait:4",
					"sip",
					"wait:2"
				]
			)
			_npc(
				"office_alan",
				"left",
				u.coffee + 40.0,
				[
					"walk:%d" % (u.coffee + 20),
					"use:coffee",
					"wait:1",
					"sip",
					"wait:4",
					"sip",
					"wait:3"
				]
			)
			_npc(
				"casual_garrison",
				"left",
				u.coffee + 70.0,
				["wait:2", "talk:5", "wait:2", "talk:4", "wait:1"]
			)
		"conference":
			var s: Dictionary = data.seats
			_npc(
				"office_dan",
				"right",
				s.Seat1,
				["wait:1", "say:3", "wait:4", "say:2"],
				"Seat1",
				"coffee"
			)
			_npc(
				"office_alan",
				"right",
				s.Seat2,
				["wait:4", "say:3", "wait:2", "say:3"],
				"Seat2",
				"soda"
			)
			_npc(
				"casual_garrison",
				"right",
				s.Seat3,
				["wait:2", "say:2", "wait:5", "say:2"],
				"Seat3",
				"bottle"
			)


func _ring(zone: Variant) -> void:
	if is_instance_valid(zone):
		var fx: Node = zone.get_node(zone.target)
		if not fx.busy:
			fx.ringing = true
			fx._ring_until = fx._time + 20.0


func _process(delta: float) -> void:
	if _busy or _started:
		return
	_t += delta
	if _t >= SHOW_SECS:
		_rotate()


func _rotate() -> void:
	_busy = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: show_vignette(_index + 1))
	tween.tween_property(_fade, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _busy = false)


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			Game.cycle_format()
			_menu.queue_redraw()
		go = event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]
		if _menu_open:
			_menu_key(event.keycode, go)
			return
	elif event is InputEventMouseMotion and _menu_open:
		_hover(get_viewport().get_mouse_position())
		return
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		go = true
		if _menu_open:
			if _hover(get_viewport().get_mouse_position()):
				_choose(_sel)
			return
	if go:
		_open_menu()


func _menu_key(code: Key, confirm: bool) -> void:
	if code == KEY_UP:
		_move(-1)
	elif code == KEY_DOWN:
		_move(1)
	elif confirm:
		_choose(_sel)
	elif code == KEY_ESCAPE:
		_menu_open = false
		_menu.visible = false


func _open_menu() -> void:
	_items = []
	if Campaign.has_save("tech"):
		var label := "CONTINUE TECH - DAY %d" % Campaign.saved_day("tech")
		_items.append({"label": label, "id": "tech_continue", "enabled": true})
		_items.append({"label": "NEW TECH CAMPAIGN", "id": "tech_new", "enabled": true})
	else:
		_items.append({"label": "TECH CAMPAIGN", "id": "tech_new", "enabled": true})
	if Campaign.has_save("owner"):
		var owner_label := "CONTINUE OWNER - WEEK %d" % Campaign.saved_day("owner")
		_items.append({"label": owner_label, "id": "owner_continue", "enabled": true})
		_items.append({"label": "NEW OWNER CAMPAIGN", "id": "owner_new", "enabled": true})
	else:
		_items.append({"label": "OWNER CAMPAIGN", "id": "owner_new", "enabled": true})
	_items.append({"label": "FREE PLAY - FILM MODE", "id": "free", "enabled": true})
	_sel = 0
	_menu_open = true
	_prompt.visible = false
	_menu.visible = true
	_menu.queue_redraw()


func _move(step: int) -> void:
	var i := _sel
	for _n in _items.size():
		i = (i + step + _items.size()) % _items.size()
		if _items[i].enabled:
			_sel = i
			break
	_menu.queue_redraw()


func _hover(at: Vector2) -> bool:
	for i in _items.size():
		if _items[i].enabled and _items[i].get("rect", Rect2()).has_point(at):
			_sel = i
			_menu.queue_redraw()
			return true
	return false


func _choose(i: int) -> void:
	if i < 0 or i >= _items.size() or not _items[i].enabled:
		return
	_started = true
	World.time_scale = 1.0
	World.hud_visible = _hud_was
	Game.title_mode = false
	Shift.enabled = true
	Outings.enabled = true
	Onsite.enabled = true
	Outings.use_rooms = true
	match str(_items[i].id):
		"tech_new":
			Campaign.new_game("tech")
		"tech_continue":
			Campaign.continue_game("tech")
		"owner_new":
			Campaign.new_game("owner")
		"owner_continue":
			Campaign.continue_game("owner")
		_:
			Campaign.new_game(Campaign.FREE)
	Game.go("main_floor", "start")


func _draw_menu() -> void:
	var size := _size()
	var y := _logo.position.y + float(_logo.texture.get_height()) + 7.0
	for i in _items.size():
		var item: Dictionary = _items[i]
		var label: String = item.label
		var w := float(PixelFont.width(label)) + 12.0
		var r := Rect2(floorf((size.x - w) * 0.5), y + float(i) * 10.0, w, 9.0)
		item["rect"] = r
		var chosen: bool = i == _sel and item.enabled
		var back := Color("f5d442") if chosen else Color(0.05, 0.07, 0.12, 0.8)
		var ink := Color("17121f") if chosen else (Color.WHITE if item.enabled else Color("7d8595"))
		_menu.draw_rect(r, back)
		PixelFont.draw(_menu, label, r.position + Vector2(6, 2), ink)
