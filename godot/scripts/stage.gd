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
	"bathroom",
	"cubicle_area",
	"network_closet"
]

var barriers := {}  # npc sync points: key -> {arrived, gen}

var _cam: Camera2D
var _player: Node2D
var _room := ""
var _dark_a := 0.0  # 0 = lit, 1 = lights out


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
	_room = scene_file_path.get_file().get_basename()
	_set_dark(0.0 if World.lights_on(_room) else 1.0)
	World.lights_changed.connect(_on_lights)
	if Net.carrying != "" and _room != "network_closet":
		Net.drop_carry()  # a cable end cannot leave the closet
		_player.give("")


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


func _apply_format() -> void:
	var f: Dictionary = Game.FORMATS[Game.format]
	_cam.zoom = Vector2.ONE * float(f.zoom)
	_cam.enabled = true
	if not f.follow:
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
		_cam.global_position = Vector2(_player.global_position.x, float(f.cam_y))
		_cam.reset_smoothing()


func _process(_delta: float) -> void:
	if Game.title_mode or _player == null or _cam == null:
		return
	var f: Dictionary = Game.FORMATS[Game.format]
	if f.follow or Game.ui_shift > 0.0:
		var base_y: float = float(f.cam_y) if f.follow else 64.0
		_cam.global_position = Vector2(_player.global_position.x, _ui_cam_y(base_y, f))
		if not f.follow:
			_cam.global_position.x = 184.0


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
		if event.keycode == KEY_F9:
			Game.cycle_format()
			return
		if not OS.is_debug_build():
			return  # the F-key room jumps below are for development builds only
		if event.keycode == KEY_F11 and event.ctrl_pressed:
			var sites := []
			for t in ["dental", "law", "vet", "arch", "realty", "trailer"]:
				for skin in ["a", "b"]:
					sites.append("site_%s_%s" % [t, skin])
			var at := get_tree().current_scene.scene_file_path.get_file().get_basename()
			Game.go(sites[(sites.find(at) + 1) % sites.size()], "start")
			return
		if event.keycode == KEY_F11:
			Game.go("escape_room" if event.shift_pressed else "bowling_alley", "start")
			return
		if event.keycode == KEY_F12 and event.ctrl_pressed:
			var venue := ["resort_lobby", "resort_hall", "ballroom", "breakout_room", "vendor_hall"]
			var here := get_tree().current_scene.scene_file_path.get_file().get_basename()
			Game.go(venue[(venue.find(here) + 1) % venue.size()], "start")
			return
		if event.keycode == KEY_F12:
			Game.go("restaurant" if event.shift_pressed else "karaoke_bar", "start")
			return
		var i: int = event.keycode - KEY_F1
		if i >= 0 and i < SETS.size():
			Game.go(SETS[i], "start")
