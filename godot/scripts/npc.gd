extends Area2D
# gdlint:disable=class-definitions-order
# A background character that runs a routine of steps (strings). Cast members (cast_name set,
# see world.gd) run one leg of their agenda and then ask the World for the next; others loop:
#   walk:X (screen x)  wait:S  say:S  talk:S  use:prop  sit:Seat  stand  sip  exit:Name  sync:key:n
#   (sync waits until n characters have reached the same key)
# Waves when the player gets close; press E to chat.

const HELD_ITEM := preload("res://scripts/held_item.gd")
const PLAYER := preload("res://scripts/player.gd")
const SPEED := 32.0
const TALK_GAP := 32.0
const GREET_RANGE := 56.0
const GLYPHS := ["dots", "!", "?", "heart", "dots"]
const CHATTY := ["walk", "wait", "sync", "usewait", "await"]
const DESKS := {"Alan": 6, "Garrison": 7, "Dan": 3, "Vic": 4, "Maya": 2, "Morgan": 5, "Sam": 1}

@export var character := "office_dan"
var custom := false  # a copy of the player's custom person (Look): the teen sheet in their colours
@export var facing := "right"
@export var routine: PackedStringArray = []
@export var start_seat := ""
@export var start_item := ""
@export var role := ""  # Rodent Nation crowd: checkin / vendor:<id> / att:<n> (see expo.gd)

var cast_name := ""
var _flagged := false
var flag_glyph := ""  # "?" stuck / "!" overloaded (service campaign), shown over the head
var following := false
var state := "wait"
var seat: Node = null
var held := ""
var sips := 0
var ducking := false  # ducking a dart: a lower target (see nerf.gd)

var _duck_t := 0.0
var _step := -1
var _timer := 0.0
var _target_x := 0.0
var _fx: Node = null
var _gen := 0
var _key := ""
var _hold := 0.0
var _hold_len := 0.0
var _inside: Node = null
var _player: Node = null
var _greeted := false
var _bubble: Node2D
var _arrow: Node2D
var _item: Node2D
var _head_item: Node2D
var _desk: Node2D
var _leaving := false
var _chat_slide := INF
var _chat_check := 0.0
var _hold_phase := 0
var _follow_key := ""
var _hidden := false
var _offline := false  # the network at my desk is down
var _net_t := 0.0
var _grumble_t := 0.0
var _call_stage := ""  # "", "tap_on", "talking", "tap_off"
var _call_t := 0.0
var _call_len := 9.0  # seconds of the call (the owners' last-resort answers are shorter)
var _t := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var _stage: Node = get_parent().get_parent()


func _ready() -> void:
	sprite.sprite_frames = load("res://characters/%s.tres" % character)
	Look.apply(sprite, character, custom)
	add_to_group("npcs")
	sprite.animation_finished.connect(_on_animation_finished)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_arrow = preload("res://scripts/prompt_arrow.gd").new()
	_arrow.base_y = -72.0
	_arrow.position = Vector2(0, -72)
	_arrow.visible = false
	add_child(_arrow)
	_bubble = preload("res://scripts/bubble.gd").new()
	_bubble.position = Vector2(0, -64)
	_bubble.visible = false
	add_child(_bubble)
	_item = HELD_ITEM.new()
	add_child(_item)
	_head_item = HELD_ITEM.new()
	_head_item.mode = "ear"
	add_child(_head_item)
	_t = float(get_index())
	held = start_item
	_item.item = held
	if start_seat != "" and _occupy(start_seat, true):
		_stash()
		_play("type" if seat.typing else "sit")
	else:
		_play("idle")
	_next_step()


func use(body: Node) -> void:
	if role != "":
		if seat == null:
			_face(body.global_position.x)
		Expo.npc_use(self, body)
		return
	if _hold > 0.0 or Social.is_hostile(cast_name) or _hidden:
		_arrow.shake()
		return
	if Talk.available(cast_name) and (seat != null or _can_chat()):
		_talk_at_desk(body)
		return
	if not _can_chat():
		_arrow.shake()
		return
	_face(body.global_position.x)
	_begin_hold("talk", 2.6)
	var side := signf(body.global_position.x - global_position.x)
	if side == 0.0:
		side = -1.0
	var target := _clamp_x(global_position.x + side * TALK_GAP)
	if absf(target - global_position.x) < TALK_GAP - 6.0:
		target = _clamp_x(global_position.x - side * TALK_GAP)
	body.slide_to(target)
	body.start_emote("talk", 2.6, global_position.x, Social.glyph(cast_name))
	Social.note_chat(cast_name)


# a seated worker whose network is down stops typing and grumbles now and then
func _update_reactions(delta: float) -> void:
	if flag_glyph != "" and _hold <= 0.0 and _grumble_t <= 0.0:
		_bubble.glyph = flag_glyph
		_bubble.visible = true
	elif flag_glyph == "" and _flagged:
		_bubble.visible = false
	_flagged = flag_glyph != ""
	if _grumble_t > 0.0:
		_grumble_t -= delta
		if _grumble_t <= 0.0 and state == "wait" and _hold <= 0.0:
			_bubble.visible = false
	var down := false
	if cast_name != "" and seat != null and seat.typing:
		down = Net.desk_state(int(DESKS.get(cast_name, 0))) != "ok"
	if down != _offline:
		_offline = down
		_net_t = 2.0
		if state == "wait" and _hold <= 0.0:
			_play(_rest_anim())
	if _offline and state == "wait" and _hold <= 0.0:
		_net_t -= delta
		if _net_t <= 0.0:
			_net_t = 7.0 + randf() * 4.0
			grumble()


# hit by a foam dart: flinch (standing) and show how they feel about it
func react_hit(glyph: String) -> void:
	if _hidden:
		return
	if seat == null and _hold <= 0.0 and state != "walk":
		_begin_hold("hurt", 0.8)
	_bubble.glyph = glyph
	_bubble.visible = true
	_grumble_t = 1.6


func grumble() -> void:
	if _hold > 0.0 or _hidden:
		return
	_bubble.glyph = "!" if randf() < 0.6 else "?"
	_bubble.visible = true
	_grumble_t = 2.2


# somebody turned the lights off on us: get up, walk to the switch, turn them back on, carry on
func react_lights(switch_x: float) -> void:
	if _hold > 0.0 or _hidden or cast_name == "" or following:
		return
	var steps := PackedStringArray(["wait:1"])
	var seat_name := ""
	if seat != null:
		seat_name = str(seat.name)
		steps.append("stand")
	steps.append_array(PackedStringArray(["walk:%d" % int(switch_x), "lights:on"]))
	if seat_name != "":
		steps.append("sit:" + seat_name)
	steps.append_array(routine)
	set_routine(steps)


# campaigns: a real conversation (the Talk autoload), seated at a desk or standing
func _talk_at_desk(body: Node) -> void:
	if seat == null:
		_face(body.global_position.x)
	_begin_hold(_rest_anim() if seat != null else "talk", 100000.0)
	var side := signf(body.global_position.x - global_position.x)
	if side == 0.0:
		side = -1.0
	body.global_position.x = _clamp_x(global_position.x + side * TALK_GAP)
	Talk.start(cast_name, self)


func talk_end() -> void:
	_hold = 0.05


func _clamp_x(x: float) -> float:
	var left: Node2D = _stage.get_node_or_null("WallLeft")
	var right: Node2D = _stage.get_node_or_null("WallRight")
	if left == null or right == null:
		return x
	return clampf(x, left.position.x + 14.0, right.position.x - 14.0)


func _on_body_entered(body: Node) -> void:
	if body.has_method("sit"):
		_inside = body
		body.add_near(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("sit"):
		body.remove_near(self)
		_inside = null
	_arrow.visible = false


# standing people duck under a dart that is flying at them (about 6 times in 10)
func _duck_tick(delta: float) -> bool:
	if _duck_t > 0.0:
		_duck_t -= delta
		if _duck_t <= 0.0:
			ducking = false
			_play("walk" if state == "walk" else _rest_anim())
		return true
	if seat != null or _hidden or _hold > 0.0 or not visible:
		return false
	var key := "duck_%d" % get_instance_id()
	for d in get_tree().get_nodes_in_group("darts"):
		if str(d.state) != "fly" or d.has_meta(key) or str(d.shooter) == cast_name:
			continue
		var dx: float = global_position.x - d.global_position.x
		var above: float = global_position.y - d.global_position.y
		if absf(dx) < 80.0 and signf(d.vel.x) == signf(dx) and above > 4.0 and above < 90.0:
			d.set_meta(key, true)
			if randf() < 0.6:
				ducking = true
				_duck_t = 0.9
				_face(d.global_position.x)
				_play("crouch")
				return true
	return false


func _can_chat() -> bool:
	return seat == null and state in CHATTY and not _hidden


func character_id() -> String:
	return character


func _play(anim: String) -> void:
	var a := anim
	if held != "" and seat == null:
		if anim == "idle":
			a = "hold"
		elif anim == "walk":
			a = "walkhold"
	sprite.play("%s_%s" % [a, facing])


func _give(item: String) -> void:
	if item != "":
		held = item
		sips = 0
		_item.item = held


func _face(x: float) -> void:
	if absf(x - global_position.x) > 0.5:
		facing = "right" if x > global_position.x else "left"


func _rest_anim() -> String:
	if seat == null:
		return "idle"
	return "type" if seat.typing and not _offline else "sit"


func _find(node_name: String) -> Node:
	return _stage.get_node_or_null("Interactables/%s" % node_name)


func _find_use(kind: String) -> Node:
	for child in _stage.get_node("Interactables").get_children():
		var n := String(child.name).to_lower()
		if n.begins_with("use") and kind in n and "target" in child:
			return child
	return null


func _occupy(seat_name: String, instant: bool) -> bool:
	var s := _find(seat_name)
	if s == null or s.occupied:
		return false
	seat = s
	seat.occupied = true
	global_position = seat.global_position
	facing = seat.facing
	if instant:
		state = "sitting"
	else:
		state = "sitdown"
		_play("sitdown")
	return true


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


func _release() -> void:
	_unstash()
	global_position = Vector2(seat.global_position.x, seat.stand_y)
	seat.occupied = false
	seat = null


func _process(delta: float) -> void:
	_t += delta
	var is_player := cast_name != "" and character == PLAYER.current_character
	if is_player != _hidden:
		_hidden = is_player  # you are playing this character: the NPC lives on, unseen
		visible = not _hidden
		set_deferred("monitoring", not _hidden)
	if _update_call(delta):
		return
	if _duck_tick(delta):
		return
	if following and _follow_tick(delta):
		return
	_update_cast_chat(delta)
	_update_greeting()
	_update_reactions(delta)
	_arrow.visible = (
		_inside != null and _inside.nearest() == self and _can_chat() and _hold <= 0.0
	)
	if _hold > 0.0:
		_hold -= delta
		if _chat_slide != INF:
			global_position.x = move_toward(global_position.x, _chat_slide, 30.0 * delta)
		var turn := int((_hold_len - _hold) / 1.3) + _hold_phase
		_bubble.visible = turn % 2 == 0 and _hold_len > 2.0
		if _hold <= 0.0:
			_bubble.visible = false
			_chat_slide = INF
			_refresh()
		return
	match state:
		"walk":
			var d := _target_x - global_position.x
			if absf(d) <= SPEED * delta:
				global_position.x = _target_x
				_next_step()
			else:
				global_position.x += signf(d) * SPEED * delta
		"wait":
			_timer -= delta
			if _timer <= 0.0:
				_next_step()
		"say", "talk":
			_timer -= delta
			var turn := int(_t / 1.3)
			_bubble.visible = turn % 2 == get_index() % 2
			_bubble.glyph = GLYPHS[(turn / 2 + get_index()) % GLYPHS.size()]
			if _timer <= 0.0:
				_next_step()
		"await":
			if not _fx.busy:
				_start_use()
		"usewait":
			if not _fx.busy:
				_give(_fx.item)
				_next_step()
		"sync":
			if _stage.barriers[_key].gen > _gen:
				_next_step()


# ---- following the player ("C" next to a cast member) ------------------------
func toggle_follow(body: Node) -> void:
	if cast_name == "" or not _can_chat() or _hold > 0.0 or Social.is_cold(cast_name):
		_arrow.shake()
		return
	_face(body.global_position.x)
	World.set_following(cast_name, not following)
	_begin_hold("wave", 1.0)


# trail the player (a little behind them), stop when close; returns true while following
func _follow_tick(delta: float) -> bool:
	if _hold > 0.0 or seat != null:
		return false
	if _player == null:
		_player = _stage.get_node_or_null("Actors/Player")
		return false
	var px: float = _player.global_position.x
	var behind := -1.0 if _player.facing == "right" else 1.0
	var want := _clamp_x(px + behind * 30.0)
	var gap := want - global_position.x
	var moving := absf(gap) > 3.0
	var key := ("walk_" if moving else "stand_") + facing
	if moving:
		state = "walk"
		_target_x = want
		_face(want)
		global_position.x += signf(gap) * minf(absf(gap), SPEED * 1.4 * delta)
		key = "walk_" + facing
	else:
		state = "wait"
		_face(px)
		key = "stand_" + facing
	if key != _follow_key:
		_follow_key = key
		_refresh()
	return true


# ---- two cast members meet: they stop, face each other and talk for a few seconds --
func _update_cast_chat(delta: float) -> void:
	_chat_check -= delta
	if _chat_check > 0.0 or cast_name == "" or following or _hold > 0.0 or not _can_chat():
		return
	_chat_check = 0.25
	for other in _stage.get_node("Actors").get_children():
		if other == self or not ("cast_name" in other) or other.cast_name == "":
			continue
		var ox: float = other.global_position.x
		var close := absf(ox - global_position.x) < 52.0
		if not close or other.following or other._hold > 0.0 or not other._can_chat():
			continue
		if World.try_chat(cast_name, other.cast_name):
			var side := signf(ox - global_position.x)
			if side == 0.0:
				side = 1.0
			var mid := (global_position.x + ox) * 0.5
			var secs := randf_range(5.0, 8.0)
			begin_chat(mid - side * 16.0, ox, secs, 0)
			other.begin_chat(mid + side * 16.0, global_position.x, secs, 1)
			return


func begin_chat(target_x: float, face_x: float, secs: float, phase: int) -> void:
	_chat_slide = target_x
	_hold_phase = phase
	_face(face_x)
	_begin_hold("talk", secs)


func give_item(item: String) -> void:
	held = item
	sips = 0
	_item.item = item


func fade_in() -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(queue_free)


# a seated NPC answers a ringing phone: ear tap, headset on, talk while typing, tap off
# returns true while the ear tap pauses the routine
func _update_call(delta: float) -> bool:
	var pause := false
	match _call_stage:
		"":
			if seat != null and state == "wait" and _hold <= 0.0 and not Game.busy:
				var zone := _ringing_phone()
				if zone != null:
					zone.get_node(zone.target).play()
					_call_stage = "tap_on"
					_call_t = 0.7
					_play("sitcall")
					pause = true
		"tap_on":
			pause = true
			_call_t -= delta
			if _call_t <= 0.0:
				_call_stage = "talking"
				_call_t = _call_len
				_head_item.item = "headset"
				_refresh()
		"talking":
			_call_t -= delta
			if state != "say" and state != "talk":
				_bubble.glyph = "dots"
				_bubble.visible = (int((_call_len - _call_t) / 1.3) + get_index()) % 2 == 1
			if _call_t <= 0.0 and _hold <= 0.0:
				_call_stage = "tap_off"
				_call_t = 0.7
				_bubble.visible = false
				_play("sitcall" if seat != null else "call")
				pause = true
		"tap_off":
			pause = true
			_call_t -= delta
			if _call_t <= 0.0:
				_call_stage = ""
				_call_len = 9.0
				_head_item.item = ""
				_refresh()
	return pause


# Owners.step_in: a seated owner takes a headset call at the desk (no phone has to be ringing)
func desk_call() -> void:
	if seat != null and state == "wait" and _hold <= 0.0 and _call_stage == "":
		_call_stage = "tap_on"
		_call_t = 0.7
		_call_len = 5.0
		_play("sitcall")


# the "answer" routine step: a standing owner picks up a ringing phone next to them and talks with a headset
func _answer_phone() -> void:
	state = "wait"
	_timer = 7.5
	var best: Node = null
	for zone in get_tree().get_nodes_in_group("phones"):
		var fx: Node = zone.get_node(zone.target)
		if fx.ringing and not fx.busy and absf(zone.global_position.x - global_position.x) < 40.0:
			best = zone
	if best == null:
		_play("talk")
		return
	_face(best.global_position.x)
	best.get_node(best.target).play()
	_call_stage = "tap_on"
	_call_t = 0.7
	_call_len = 5.0
	_play("call")


func _ringing_phone() -> Node:
	for zone in get_tree().get_nodes_in_group("phones"):
		var fx: Node = zone.get_node(zone.target)
		var dx: float = zone.global_position.x - seat.global_position.x
		var near := dx > 20.0 and dx < 70.0  # a desk phone sits to the right of its own seat
		if fx.ringing and not fx.busy and near:
			return zone
	return null


func _update_greeting() -> void:
	if _player == null:
		_player = _stage.get_node_or_null("Actors/Player")
		return
	var d := absf(_player.global_position.x - global_position.x)
	if d > GREET_RANGE * 2.0:
		_greeted = false
	elif d < GREET_RANGE and not _greeted and _can_chat() and _hold <= 0.0 and not Game.busy:
		_greeted = true
		if Social.is_cold(cast_name):
			return  # they do not wave at someone they dislike
		_face(_player.global_position.x)
		_begin_hold("wave", 1.3)
		if Social.is_friendly(cast_name):
			_bubble.glyph = "heart"


func _begin_hold(anim: String, secs: float) -> void:
	_hold = secs
	_hold_len = secs
	_bubble.glyph = "dots"
	_play(anim)


func _refresh() -> void:
	if state == "walk":
		_face(_target_x)
		_play("walk")
	else:
		_play(_rest_anim())


func _next_step() -> void:
	_bubble.visible = false
	if routine.is_empty():
		_finish_routine()
		return
	for _i in routine.size():
		_step += 1
		if _step >= routine.size():
			if cast_name != "":
				break
			_step = 0
		if _start(routine[_step].split(":")):
			return
	if cast_name != "":
		_finish_routine()
		return
	state = "wait"
	_timer = 1.0
	_play(_rest_anim())


# a cast member has run out of steps: wait quietly and let the World hand over the next leg
func _finish_routine() -> void:
	state = "wait"
	_timer = 1.0e9
	_play(_rest_anim())
	if cast_name != "":
		World.leg_done.call_deferred(cast_name)


# lights:on / lights:off / lights:last (off only if nobody else of the cast is still in the room)
func _flip_lights(mode: String) -> bool:
	var room: String = _stage.scene_file_path.get_file().get_basename()
	var on: bool = World.lights_on(room)
	var changed := false
	World.lights_by_npc = true
	if mode == "on" and not on:
		World.set_lights(room, true)
		changed = true
	elif mode == "off" and on:
		World.set_lights(room, false)
		changed = true
	elif mode == "last" and on and World.last_one_out(room, cast_name):
		World.set_lights(room, false)
		changed = true
	World.lights_by_npc = false
	return changed


func set_routine(new_routine: PackedStringArray) -> void:
	routine = new_routine
	_step = -1
	_next_step()


func _exit_tree() -> void:
	if cast_name != "" and not _leaving and is_instance_valid(World):
		World.node_left(cast_name, held, sips)


# starts a step; returns false if it was skipped or finished instantly
func _start(parts: PackedStringArray) -> bool:
	var started := true
	match parts[0]:
		"walk":
			started = _start_walk(float(parts[1]))
		"wait":
			state = "wait"
			_timer = float(parts[1])
			_play(_rest_anim())
		"say", "talk":
			state = parts[0]
			_timer = float(parts[1])
			if parts[0] == "talk":
				_play("talk")
		"use":
			started = _start_use_step(parts[1])
		"sit":
			started = seat == null and _occupy(parts[1], false)
		"stand":
			started = seat != null
			if started:
				state = "standup"
				sprite.play_backwards("sitdown_%s" % facing)
		"sync":
			started = _start_sync(parts[1], int(parts[2]))
		"sip":
			started = held != ""
			if started:
				state = "sip"
				_item.item = held
				if _desk != null:
					_desk.item = ""
				_play("sitsip" if seat != null else "sip")
		"lights":
			started = _flip_lights(parts[1])
			if started:
				state = "wait"
				_timer = 0.8
				_play("reach")
		"notify":
			started = cast_name != ""
			if started:
				state = "wait"
				_timer = 3.0
				_play("talk")
				Sales.deliver.call_deferred()
		"answer":
			started = cast_name != ""
			if started:
				_answer_phone()
		"exit":
			started = cast_name != ""
			if started:
				state = "wait"
				_timer = 1.0e9
				_play("idle")
				World.leg_exit.call_deferred(cast_name)
		"drop":
			held = ""
			_item.item = ""
			if _desk != null:
				_desk.item = ""
			started = false
		_:
			started = false
	return started


func _start_walk(x: float) -> bool:
	_target_x = x
	if absf(_target_x - global_position.x) < 1.0:
		return false
	state = "walk"
	_face(_target_x)
	_play("walk")
	return true


func _start_use_step(kind: String) -> bool:
	var area := _find_use(kind)
	if area == null:
		return false
	_fx = area.get_node(area.target)
	_face(area.look_x if area.look_x != 0.0 else area.global_position.x)
	if _fx.busy:
		state = "await"
		_play("idle")
	else:
		_start_use()
	return true


# barrier: returns false (do not block) for the last character to arrive
func _start_sync(key: String, count: int) -> bool:
	_key = key
	var b: Dictionary = _stage.barriers.get(key, {"arrived": 0, "gen": 0})
	_gen = b.gen
	b.arrived += 1
	var last: bool = b.arrived >= count
	if last:
		b.arrived = 0
		b.gen += 1
	_stage.barriers[key] = b
	if not last:
		state = "sync"
		_play(_rest_anim())
	return not last


func _start_use() -> void:
	state = "use"
	_play("reach")
	_fx.play()


func _on_animation_finished() -> void:
	match state:
		"use":
			state = "usewait"
			_play("idle")
		"sip":
			sips += 1
			if sips >= (6 if seat != null else 3):
				held = ""
				_item.item = ""
			else:
				_stash()
			_next_step()
		"sitdown":
			state = "sitting"
			_stash()
			_next_step()
		"standup":
			_release()
			_next_step()
