extends Node2D
# gdlint:disable=max-returns
# Put the player on the spawn point chosen by the door they came through, and run the follow
# camera for the current output format (Game.format). F1-F7 jump between sets, F9 cycles format.

const SETS := [
	"main_floor",
	"office_one",
	"office_two",
	"conference",
	"kitchenette",
	"bathroom_1",
	"cubicle_area",
	"network_closet"
]

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SalesBeats := preload("res://scripts/sales_beats.gd")

var barriers := {}  # npc sync points: key -> {arrived, gen}

var _cam: Camera2D
var _player: Node2D
var _room := ""
var _dark_a := 0.0  # 0 = lit, 1 = lights out
var _long := false  # a room wider than the screen (the warehouse) follows the player even in the wide format
var _split_on := false  # co-op: the players are further apart than one screen shows, so each gets half the window
var _split_vp: SubViewport = null
var _split_cam: Camera2D = null
var _split_layer: CanvasLayer = null


func _ready() -> void:
	if Game.title_mode:
		var shown_player := get_node_or_null("Actors/Player")
		if shown_player != null:
			shown_player.free()
		return
	var spawn: Node = get_node_or_null("Spawns/%s" % Game.pending_spawn)
	if spawn == null:
		spawn = get_node_or_null("Spawns/start")
	Game.pending_spawn = "start"
	_player = get_node("Actors/Player")
	_player.global_position = spawn.global_position
	if Game.pending_x >= 0.0:  # a one-shot "put me back where I was" (after an outing)
		_player.global_position.x = Game.pending_x
		Game.pending_x = -1.0
	_player.face(str(spawn.get_meta("facing", "right")))
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 7.0
	add_child(_cam)
	var bg: Sprite2D = get_node("Background")
	var tex := bg.texture.get_size()
	_long = tex.x > 420.0
	_cam.limit_left = int(bg.position.x)
	_cam.limit_right = int(bg.position.x + tex.x)
	_cam.limit_top = int(bg.position.y)
	_cam.limit_bottom = int(bg.position.y + tex.y)
	Game.format_changed.connect(_apply_format)
	_apply_format()
	World.populate(self)
	_seat_player()
	Expo.populate(self)
	Onsite.populate(self)
	SalesBeats.auditor(self)
	SalesBeats.recruiter(self)
	Shop.dress(self)
	_room = scene_file_path.get_file().get_basename()
	_set_dark(0.0 if World.lights_on(_room) else 1.0)
	World.lights_changed.connect(_on_lights)
	if Net.carrying != "" and _room != "network_closet":
		Net.drop_carry()  # a cable end cannot leave the closet
		_player.give("")
	if Players.coop and Players.slot(1).joined:
		spawn_player2()  # co-op: the second player is already in (a room change keeps the roster)


# Co-op phase 1 (docs/scope-coop.md): the second player's body, next to the first. The position is set BEFORE add_child: a body
# added at (0, 0) would overlap the edge exit in the corner and fire Game.go on spawn. The two bodies pass through each other
# (collision exceptions both ways): nobody can block the other in a doorway or trap them against a wall. Both bodies use the
# one camera, which follows slot 0 only in phase 1.
func spawn_player2() -> Node:
	var actors := get_node_or_null("Actors")
	if Game.title_mode or _player == null or actors == null:
		return null
	var existing := get_node_or_null("Actors/Player2")
	if existing != null:
		return existing
	var p2: CharacterBody2D = PLAYER_SCENE.instantiate()
	p2.name = "Player2"
	p2.slot = 1
	var side := -1.0 if _player.facing == "left" else 1.0
	var at: Vector2 = _player.global_position + Vector2(24.0 * side, 0.0)
	var left := get_node_or_null("WallLeft")
	var right := get_node_or_null("WallRight")
	if left != null and right != null:
		at.x = clampf(at.x, left.position.x + 14.0, right.position.x - 14.0)
	p2.position = actors.to_local(at)
	actors.add_child(p2)
	p2.face(_player.facing)
	(_player as CollisionObject2D).add_collision_exception_with(p2)
	p2.add_collision_exception_with(_player)
	return p2


# the first room of a run as a cast member: you are already sitting at your desk
func _seat_player() -> void:
	var resume_seat := str(Game.vars.get("resume_seat", ""))
	if Game.vars.has("resume_seat"):  # a resumed run (Resume.apply_player): back in the chair they were in
		Game.vars.erase("resume_seat")
		Game.vars.erase("start_seated")
		var chair := get_node_or_null("Interactables/%s" % resume_seat) if resume_seat != "" else null
		if chair != null and _player.has_method("sit_now"):
			_player.sit_now(chair)
		return
	if not Game.vars.get("start_seated", false):
		return
	Game.vars.erase("start_seated")
	var desk: Dictionary = World.player_desk()
	if desk.is_empty() or str(desk.scene) != scene_file_path.get_file().get_basename():
		return
	var seat := get_node_or_null("Interactables/%s" % str(desk.seat))
	if seat != null and _player.has_method("sit_now"):
		_player.sit_now(seat)


func _on_lights(room: String) -> void:
	if room == _room:
		var target := 0.0 if World.lights_on(_room) else 1.0
		create_tween().tween_method(_set_dark, _dark_a, target, 0.25)


# lights out = a blue-grey tint on the background, the fx and everything standing in the room, so
# the depth order is untouched; screens and bubbles (group "emissive") cancel the tint and glow
func _set_dark(amount: float) -> void:
	_dark_a = amount
	var tint := Color(lerpf(1.0, 0.34, amount), lerpf(1.0, 0.38, amount), lerpf(1.0, 0.58, amount))
	for layer in ["Background", "Fx", "Actors"]:
		get_node(layer).modulate = tint
	var inverse := Color(1.0 / tint.r, 1.0 / tint.g, 1.0 / tint.b)
	for node in get_tree().get_nodes_in_group("emissive"):
		node.modulate = inverse


# the parking lot outside the dock (R21c): the light comes from the sky, so the whole picture takes the colour of the hour
func _lot_tint() -> void:
	var tint: Color = preload("res://scripts/outside.gd").phase(World.clock).tint
	for layer in ["Background", "Fx", "Actors"]:
		get_node(layer).modulate = tint


func _apply_format() -> void:
	var f: Dictionary = Game.FORMATS[Game.format]
	_cam.zoom = Vector2.ONE * float(f.zoom)
	if _split_on:
		_split_set(false, f)  # the views are re-framed for the new format
	_cam.enabled = true
	if not f.follow and not _long:
		# classic 368x128 view: no camera movement, the room sits centred like before
		_cam.limit_left = -10000000
		_cam.limit_right = 10000000
		_cam.limit_top = -10000000
		_cam.limit_bottom = 10000000
		_cam.position_smoothing_enabled = false
		_cam.global_position = Vector2(184, 64)
	else:
		var bg: Sprite2D = get_node("Background")
		var tex := bg.texture.get_size()
		_cam.limit_left = int(bg.position.x)
		_cam.limit_right = int(bg.position.x + tex.x)
		_cam.limit_top = int(bg.position.y)
		_cam.limit_bottom = int(bg.position.y + tex.y)
		_cam.position_smoothing_enabled = true
		_cam.global_position = Vector2(_player.global_position.x, float(f.cam_y) if f.follow else 64.0)
		_cam.reset_smoothing()


func _process(_delta: float) -> void:
	if Game.title_mode or _player == null or _cam == null:
		return
	if _room == "warehouse_lot":
		_lot_tint()
	var f: Dictionary = Game.FORMATS[Game.format]
	if f.follow or _long or Game.ui_shift > 0.0:
		var base_y: float = float(f.cam_y) if f.follow else 64.0
		_cam.global_position = Vector2(_player.global_position.x, _ui_cam_y(base_y, f))
		if not f.follow and not _long:
			_cam.global_position.x = 184.0
		_coop_frame(f)


# co-op phase 2: in a scrolling view the camera frames both players, and the tether keeps both of them on screen
func _coop_frame(f: Dictionary) -> void:
	if not Players.coop or not (f.follow or _long):
		return
	var bodies := Players.nodes(self)
	if bodies.size() < 2:
		return
	var xs := []
	for b in bodies:
		xs.append(b.global_position.x)
	var focus := Players.coop_focus(xs)
	var bg: Sprite2D = get_node("Background")
	var view_w := get_viewport_rect().size.x / float(f.zoom)
	if _split_update(bodies, view_w, bg, f):
		return
	_cam.global_position.x = focus
	var reach := Players.tether_range(focus, view_w, bg.position.x, bg.position.x + bg.texture.get_size().x)
	for b in bodies:
		b.global_position.x = clampf(b.global_position.x, reach.x, reach.y)


# co-op phase 3b, the true second camera: when the two bodies are further apart than one screen shows, the window splits in
# halves, the left one follows the player on the left and a second camera (a SubViewport sharing this world) the one on the
# right. The tether is off while it is split; it joins again once the two are within half a screen of each other.
func _split_update(bodies: Array, view_w: float, bg: Sprite2D, f: Dictionary) -> bool:
	var lo: Node2D = bodies[0]
	var hi: Node2D = bodies[0]
	for b in bodies:
		if b.global_position.x < lo.global_position.x:
			lo = b
		if b.global_position.x > hi.global_position.x:
			hi = b
	var sep: float = hi.global_position.x - lo.global_position.x
	var room_w := bg.texture.get_size().x
	var can: bool = Players.split_cam and room_w > view_w and Players.split_wanted(sep, view_w, _split_on)
	if can != _split_on:
		_split_set(can, f)
	if not _split_on:
		return false
	var y := _cam.global_position.y
	_cam.offset.x = view_w * 0.25
	_cam.global_position = Vector2(lo.global_position.x, y)
	_split_cam.global_position = Vector2(hi.global_position.x, y)
	return true


func _split_set(on: bool, f: Dictionary) -> void:
	_split_on = on
	if not on:
		_cam.offset.x = 0.0
		if _split_layer != null:
			_split_layer.visible = false
			_split_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var size := get_viewport_rect().size
	if _split_vp == null:
		_split_vp = SubViewport.new()
		_split_vp.transparent_bg = false
		_split_vp.disable_3d = true
		_split_vp.world_2d = get_viewport().world_2d
		_split_cam = Camera2D.new()
		_split_cam.position_smoothing_enabled = false
		_split_vp.add_child(_split_cam)
		add_child(_split_vp)
		_split_layer = CanvasLayer.new()
		_split_layer.layer = 1
		add_child(_split_layer)
		var view := TextureRect.new()
		view.name = "View"
		view.texture = _split_vp.get_texture()
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_SCALE
		_split_layer.add_child(view)
		var line := ColorRect.new()
		line.name = "Divider"
		line.color = Color("17121F")
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_split_layer.add_child(line)
	var half := Vector2(floorf(size.x * 0.5), size.y)
	_split_vp.size = Vector2i(half)
	_split_cam.zoom = Vector2.ONE * float(f.zoom)
	_split_cam.limit_left = _cam.limit_left
	_split_cam.limit_right = _cam.limit_right
	_split_cam.limit_top = _cam.limit_top
	_split_cam.limit_bottom = _cam.limit_bottom
	_split_cam.make_current()
	_cam.make_current()
	var view_rect: TextureRect = _split_layer.get_node("View")
	view_rect.position = Vector2(size.x - half.x, 0.0)
	view_rect.size = half
	var divider: ColorRect = _split_layer.get_node("Divider")
	divider.position = Vector2(size.x - half.x - 1.0, 0.0)
	divider.size = Vector2(2.0, size.y)
	_split_layer.visible = true
	_split_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


# a UI covers all but a strip at the top: slide the camera down so the player shows there
func _ui_cam_y(base_y: float, f: Dictionary) -> float:
	if Game.ui_shift <= 0.0:
		var bg: Sprite2D = get_node("Background")
		if _cam.limit_bottom == 100000 and Game.FORMATS[Game.format].follow:
			_cam.limit_bottom = int(bg.position.y + bg.texture.get_size().y)
			_cam.position_smoothing_enabled = true
		return base_y
	var half := get_viewport_rect().size.y * 0.5
	var strip := maxf(12.0, floorf(half * 2.0 * Game.UI_STRIP))
	var zoom: float = float(f.zoom)
	var target := _player.global_position.y - 28.0 + (half - strip * 0.5) / zoom
	# whatever lies below the art is hidden by the UI window: the camera may leave the set
	_cam.limit_bottom = 100000
	_cam.position_smoothing_enabled = false
	return lerpf(base_y, target, Game.ui_shift)


func _unhandled_input(event: InputEvent) -> void:
	if Game.title_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if Controls.word(event) == "f9":
			Game.cycle_format()
			return
		if not OS.is_debug_build():
			return  # the F-key room jumps below are for development builds only
		if Controls.word(event) == "f11" and event.alt_pressed:
			Game.go("warehouse_lot" if event.shift_pressed else "warehouse", "start")
			return
		if Controls.word(event) == "f11" and event.ctrl_pressed:
			var sites := []
			for t in ["dental", "law", "vet", "arch", "realty", "trailer"]:
				for skin in ["a", "b"]:
					sites.append("site_%s_%s" % [t, skin])
			var at := get_tree().current_scene.scene_file_path.get_file().get_basename()
			Game.go(sites[(sites.find(at) + 1) % sites.size()], "start")
			return
		if Controls.word(event) == "f11":
			Game.go("escape_room" if event.shift_pressed else "bowling_alley", "start")
			return
		if Controls.word(event) == "f12" and event.ctrl_pressed:
			var venue := ["resort_lobby", "resort_hall", "ballroom", "breakout_a", "breakout_b", "breakout_c", "breakout_d", "vendor_hall"]
			var here := get_tree().current_scene.scene_file_path.get_file().get_basename()
			Game.go(venue[(venue.find(here) + 1) % venue.size()], "start")
			return
		if Controls.word(event) == "f12":
			Game.go("restaurant" if event.shift_pressed else "karaoke_bar", "start")
			return
		if Controls.word(event) == "f6" and event.shift_pressed:
			Game.go("bathroom_2", "start")
			return
		var i: int = Controls.fkey(event) - 1
		if i >= 0 and i < SETS.size():
			Game.go(SETS[i], "start")
