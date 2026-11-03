extends CharacterBody2D
# Side-on character controller. A/D or arrows move, Shift run, Space jump,
# E use/sit/chat, Q wave, X dance, C follow me, F sip, H/K/R hurt/die/revive, 1-6 character.

const HELD_ITEM := preload("res://scripts/held_item.gd")
const WALK_SPEED := 40.0
const RUN_SPEED := 90.0
const GRAVITY := 900.0
const JUMP_SPEED := 230.0
const CHARACTERS := [
	"office_teen",
	"office_adult",
	"office_dan",
	"office_alan",
	"site_alan",
	"casual_garrison",
	"sales_vic"
]

static var current_character := "office_adult"

var facing := "right"
var state := "idle"  # idle walk run crouch jump land hurt death sitdown sitting standup
var grounded_once := false  # no "airborne" until first floor contact (spawning on the floor)
var seat: Node = null
var held := ""  # "", "coffee", "water" (kept in Game.vars across rooms)
var sips := 0
var _item: Node2D
var _sip_pending := false
var _call_stage := ""  # "", "tap_on", "talking", "tap_off"
var _call_t := 0.0
var _call_len := 0.0
var _head_item: Node2D
var _dance_t := 0.0
var _slide_to := INF
var _desk: Node2D
var _emote_t := 0.0
var _emote_len := 0.0
var _bubble: Node2D = null
var _pick: Node = null  # the target chosen with Tab (until you walk away from it)
var _pick_x := 0.0
var _near: Array[Node] = []  # doors / seats whose area we are inside

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $Collision


func _ready() -> void:
	_add_inputs()
	held = str(Game.vars.get("held", ""))
	sips = int(Game.vars.get("sips", 0))
	_item = HELD_ITEM.new()
	_item.item = held
	add_child(_item)
	_head_item = HELD_ITEM.new()
	_head_item.mode = "ear"
	add_child(_head_item)
	add_to_group("player")
	_load_character(current_character)
	sprite.animation_finished.connect(_on_animation_finished)
	_play("idle")


func add_near(n: Node) -> void:
	if n not in _near:
		_near.append(n)


func remove_near(n: Node) -> void:
	_near.erase(n)


# the closest door/seat by x, so overlapping zones pick what you are standing at
func nearest() -> Node:
	if _pick != null and (_pick not in _near or absf(global_position.x - _pick_x) > 10.0):
		_pick = null
	if _pick != null:
		return _pick
	var best: Node = null
	var best_d := INF
	for n in _near:
		var d := absf(n.global_position.x - global_position.x)
		d += 0.02 * absf(n.global_position.y - (global_position.y - 40.0))
		if n.get("low_priority") == true:
			d += 14.0
		elif n.is_in_group("npcs") and str(n.get("role")).begins_with("site:"):
			d += 20.0  # doors and equipment beat small talk with the client staff (Tab still selects them)
		if d < best_d:
			best_d = d
			best = n
	return best


# Tab / Shift+Tab: move the arrow to the next / previous thing within reach without walking
func cycle_pick(step: int) -> void:
	var list: Array = _near.duplicate()
	if list.is_empty():
		return
	list.sort_custom(
		func(a: Node, b: Node) -> bool:
			if absf(a.global_position.x - b.global_position.x) > 0.5:
				return a.global_position.x < b.global_position.x
			return a.global_position.y < b.global_position.y
	)
	var at := list.find(nearest())
	_pick = list[posmod(at + step, list.size())]
	_pick_x = global_position.x


func face(side: String) -> void:
	facing = side
	_play("idle")


func _add_inputs() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"run": [KEY_SHIFT],
		"interact": [KEY_E],
		"hurt": [KEY_H],
		"die": [KEY_K],
		"revive": [KEY_R],
		"wave": [KEY_Q],
		"drink": [KEY_F],
		"dance": [KEY_X],
		"follow": [KEY_C],
		"duck": [KEY_S, KEY_DOWN],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code in keys[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)


func _load_character(name: String) -> void:
	current_character = name
	sprite.sprite_frames = load("res://characters/%s.tres" % name)


# swap the sprite sheet without losing the running animation (one-shots like sitdown / land /
# hurt would otherwise never emit animation_finished and the state machine would hang)
func _switch_character(name: String) -> void:
	var anim := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	var was_playing := sprite.is_playing()
	var speed := sprite.get_playing_speed()
	_load_character(name)
	sprite.animation = anim
	if was_playing:
		sprite.play(anim, speed, speed < 0.0)
	sprite.set_frame_and_progress(frame, progress)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_Z and not event.pressed:
		Nerf.charge_release(self)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			cycle_pick(-1 if event.shift_pressed else 1)
			return
		if event.keycode == KEY_Z:
			Nerf.charge_start(self)
			return
		if event.keycode == KEY_G and held == "nerf":
			give("")
			return
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < CHARACTERS.size() and not Campaign.active:
			_switch_character(CHARACTERS[i])
			Campaign.refresh_free()


func _play(action: String) -> void:
	var anim := action
	if action == "duck":
		anim = "crouch"
	if held != "":
		if action == "idle":
			anim = "hold"
		elif action in ["walk", "run"]:
			anim = "walkhold"
	sprite.play("%s_%s" % [anim, facing])


func character_id() -> String:
	return current_character


func give(item: String) -> void:
	if item == "nerf":
		Nerf.on_given()
	held = item
	sips = 0
	Game.vars["held"] = held
	Game.vars["sips"] = sips
	_item.item = held
	if state in ["idle", "walk", "run"]:
		_play(state)


# answer: tap the ear, a wireless headset appears, talk (walk or keep typing), tap it off
# step to this x while a conversation starts (so you stand a talking distance from the other person)
func slide_to(x: float) -> void:
	_slide_to = x


func start_call(secs: float) -> void:
	_call_len = secs
	_call_stage = "tap_on"
	start_emote("sitcall" if state == "sitting" else "call", 0.7)


func _call_tick(delta: float) -> void:
	if _call_stage != "talking":
		return
	_call_t -= delta
	_ensure_bubble()
	_bubble.glyph = "dots"
	_bubble.visible = state != "emote" and int((_call_len - _call_t) / 1.3) % 2 == 1
	if _call_t <= 0.0 and state in ["idle", "walk", "run", "sitting"]:
		_call_stage = "tap_off"
		start_emote("sitcall" if state == "sitting" else "call", 0.7)


func _ensure_bubble() -> void:
	if _bubble == null:
		_bubble = preload("res://scripts/bubble.gd").new()
		_bubble.position = Vector2(0, -64)
		add_child(_bubble)


# the nearest ringing desk phone within reach of the seat (answered without standing up)
func _ringing_phone() -> Node:
	if seat == null:
		return null
	for zone in get_tree().get_nodes_in_group("phones"):
		var fx: Node = zone.get_node(zone.target)
		var dx: float = zone.global_position.x - seat.global_position.x
		var near := dx > 20.0 and dx < 70.0  # a desk phone sits to the right of its own seat
		if fx.ringing and not fx.busy and near:
			return zone
	return null


# the computer in front of the seat (opened with E while seated)
func _seat_computer() -> Node:
	if seat == null:
		return null
	for zone in get_tree().get_nodes_in_group("computers"):
		var dx: float = zone.global_position.x - seat.global_position.x
		if dx > 5.0 and dx < 60.0:
			return zone
	return null


func drink() -> void:
	_sip_pending = true
	if state == "sitting":
		_item.item = held
		if _desk != null:
			_desk.item = ""
		start_emote("sitsip", 0.75)
	else:
		start_emote("sip", 0.75)


# seated at a desk the cup stands on the desktop; standing up picks it back up
func _stash() -> void:
	if held == "" or seat == null or not seat.stash:
		return
	_item.item = ""
	if _desk == null:
		_desk = preload("res://scripts/desk_cup.gd").new()
		get_parent().add_child.call_deferred(_desk)
	_desk.position = Vector2(seat.global_position.x + seat.cup_dx, 109.0)
	_desk.rest_y = seat.cup_y
	_desk.item = held


func _unstash() -> void:
	if _desk != null:
		_desk.item = ""
	_item.item = held


func _set_state(new_state: String) -> void:
	state = new_state
	if new_state != "jump":
		_play(new_state)


func sit(s: Node) -> void:
	seat = s
	state = "sitdown"
	velocity = Vector2.ZERO
	body_shape.set_deferred("disabled", true)
	global_position = s.global_position
	facing = s.facing
	_play("sitdown")


# the first frame of a run as a cast member: already at your desk
func sit_now(s: Node) -> void:
	seat = s
	state = "sitting"
	velocity = Vector2.ZERO
	body_shape.set_deferred("disabled", true)
	global_position = s.global_position
	facing = s.facing
	_play("type" if s.typing else "sit")
	_stash()


func _stand_up() -> void:
	state = "standup"
	sprite.play_backwards("sitdown_%s" % facing)


func reach(toward_x: float) -> void:
	_face_toward(toward_x)
	velocity = Vector2.ZERO
	state = "use"
	_play("reach")


# a timed gesture (wave / talk), optionally with a speech-bubble icon
func start_emote(anim: String, secs: float, toward_x := INF, glyph := "") -> void:
	if toward_x != INF:
		_face_toward(toward_x)
	velocity = Vector2.ZERO
	state = "emote"
	_emote_t = secs
	_emote_len = secs
	_play(anim)
	if glyph != "":
		_ensure_bubble()
		_bubble.glyph = glyph
		_bubble.visible = false


# X: dance on the spot until X again, a move or a jump (the player's choice; NPCs never dance)
func _start_dance() -> void:
	velocity = Vector2.ZERO
	state = "dance"
	_dance_t = 0.0
	_play("dance")
	_ensure_bubble()
	_bubble.glyph = "note"
	_bubble.visible = true


func _stop_dance() -> void:
	if _bubble != null:
		_bubble.visible = false
	_set_state("idle")


func _dance_tick(delta: float, wants_out: bool) -> bool:
	if state != "dance":
		return false
	velocity = Vector2.ZERO
	_dance_t += delta
	_bubble.visible = int(_dance_t / 0.9) % 2 == 0
	if wants_out or Input.is_action_just_pressed("dance"):
		_stop_dance()
	return true


# X dance, Q wave, F sip: gestures from the ground (returns true when one started)
func _try_gesture(locked: bool) -> bool:
	if locked or not is_on_floor():
		return false
	var did := true
	if Input.is_action_just_pressed("dance"):
		_start_dance()
	elif Input.is_action_just_pressed("wave"):
		start_emote("wave", 1.3)
	elif (
		Input.is_action_just_pressed("drink")
		and held != ""
		and not held.begins_with("plug_")
		and held != "nerf"
	):
		drink()
	elif Input.is_action_just_pressed("follow"):
		did = _ask_follow()
	else:
		did = false
	return did


# C next to someone: ask them to follow you (or to stop)
func _ask_follow() -> bool:
	var best: Node = null
	var best_d := INF
	for zone in _near:
		if zone.has_method("toggle_follow"):
			var d := absf(zone.global_position.x - global_position.x)
			if d < best_d:
				best_d = d
				best = zone
	if best != null:
		best.toggle_follow(self)
	return best != null


func _end_emote() -> void:
	if _bubble != null:
		_bubble.visible = false
	if _call_stage == "tap_on":
		_call_stage = "talking"
		_call_t = _call_len
		_head_item.item = "headset"
	elif _call_stage == "tap_off":
		_call_stage = ""
		_head_item.item = ""
		if _bubble != null:
			_bubble.visible = false
	if _sip_pending:
		_sip_pending = false
		sips += 1
		Game.vars["sips"] = sips
		if sips >= (6 if seat != null else 3):
			held = ""
			Game.vars["held"] = ""
			_item.item = ""
			if _desk != null:
				_desk.item = ""
	if seat != null:
		state = "sitting"
		_play("type" if seat.typing else "sit")
		_stash()
		return
	_set_state("idle")


func _face_toward(x: float) -> void:
	if absf(x - global_position.x) > 0.5:
		facing = "right" if x > global_position.x else "left"


func _physics_process(delta: float) -> void:
	if Game.ui_open:
		velocity = Vector2.ZERO
		return
	_call_tick(delta)
	var locked: bool = Game.busy
	var dir := 0.0 if locked else Input.get_axis("move_left", "move_right")
	var running := Input.is_action_pressed("run")
	var interact := (not locked) and Input.is_action_just_pressed("interact") and not Outings.blocks_interact()
	var jump := (not locked) and Input.is_action_just_pressed("jump")

	if state in ["use", "emote"]:
		velocity = Vector2.ZERO
		if _slide_to != INF:
			global_position.x = move_toward(global_position.x, _slide_to, 80.0 * delta)
			if is_equal_approx(global_position.x, _slide_to):
				_slide_to = INF
		if state == "emote":
			_emote_t -= delta
			if _bubble != null:
				_bubble.visible = int((_emote_len - _emote_t) / 1.3) % 2 == 1 and _emote_len > 2.0
			if _emote_t <= 0.0:
				_end_emote()
		return

	if _dance_tick(delta, dir != 0.0 or jump or interact):
		return

	if state in ["sitdown", "sitting", "standup"]:
		velocity = Vector2.ZERO
		if state == "sitting" and interact and _ringing_phone() != null:
			_ringing_phone().use(self)
		elif state == "sitting" and interact and _seat_computer() != null:
			_seat_computer().use(self)
		elif (
			state == "sitting"
			and held != ""
			and held != "nerf"
			and Input.is_action_just_pressed("drink")
		):
			drink()
		elif state == "sitting" and (interact or jump or dir != 0.0):
			_stand_up()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if not locked and not Campaign.active:
		if Input.is_action_just_pressed("die") and state != "death":
			_set_state("death")
			velocity.x = -60.0 * (1 if facing == "right" else -1)
		elif Input.is_action_just_pressed("hurt") and state not in ["death", "hurt"]:
			_set_state("hurt")
			velocity.x = -50.0 * (1 if facing == "right" else -1)
		elif Input.is_action_just_pressed("revive") and state == "death":
			_set_state("idle")

	var duck_held := (not locked) and Input.is_action_pressed("duck")
	if state == "duck" and (not duck_held or not is_on_floor()):
		_set_state("idle")
	elif duck_held and state in ["idle", "walk", "run"] and is_on_floor() and not Nerf.charging:
		_set_state("duck")
	match state:
		"death", "hurt":
			velocity.x = move_toward(velocity.x, 0.0, 250.0 * delta)
		"crouch", "land", "duck":
			velocity.x = 0.0
		_:
			velocity.x = dir * (RUN_SPEED if running else WALK_SPEED)
			if dir != 0.0:
				var side := "right" if dir > 0.0 else "left"
				if side != facing:
					facing = side
					if state != "jump":
						_play(state)

	if state in ["idle", "walk", "run"]:
		if _try_gesture(locked):
			return
		var target := nearest()
		if interact and target != null:
			target.use(self)
			if state in ["sitdown", "use", "emote"]:
				return
		if jump and is_on_floor():
			velocity.x = 0.0
			_set_state("crouch")
		elif not is_on_floor() and grounded_once:
			state = "jump"
		else:
			var want := "idle"
			if dir != 0.0:
				want = "run" if running else "walk"
			if want != state:
				_set_state(want)

	move_and_slide()
	if is_on_floor():
		grounded_once = true

	if state == "jump":
		# pick the frame from vertical speed: rise, apex, fall
		var frame := 0 if velocity.y < -90.0 else (1 if velocity.y < 90.0 else 2)
		if sprite.animation != StringName("jump_%s" % facing):
			sprite.play("jump_%s" % facing)
		sprite.pause()
		sprite.frame = frame
		if is_on_floor() and velocity.y >= 0.0:
			_set_state("land")


func _on_animation_finished() -> void:
	match state:
		"crouch":
			velocity.y = -JUMP_SPEED
			state = "jump"
		"land", "hurt", "use":
			_set_state("idle")
		"sitdown":
			state = "sitting"
			_play("type" if seat.typing else "sit")
			_stash()
		"standup":
			_unstash()
			global_position = Vector2(seat.global_position.x, seat.stand_y)
			body_shape.set_deferred("disabled", false)
			seat = null
			velocity = Vector2.ZERO
			state = "idle"
			_play("idle")
