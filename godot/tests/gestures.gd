extends SceneTree
# Seated life (R26): every character sheet has the eight seated gestures in both facings (hands json and sheet width match the
# 135 frames), a seated NPC does a gesture within 18 s and goes back to type, never during a call / a chat / Game.busy, with a
# drink only head gestures and the sip, the picker is deterministic from the seed, and the player gestures when seated and idle.

const COUNTS := {
	"sitstretch": 5,
	"sitscratch": 6,
	"sitlook": 5,
	"sityawn": 5,
	"sitslump": 4,
	"sitmouse": 4,
	"sitphone": 5,
	"sitnod": 4,
	"toss": 6,
	"sitcouch": 6,
}
const NFRAMES := 135

var failures := 0
var seat_life: GDScript = null  # loaded in _initialize: the autoloads exist by then (preload would compile first)
var npc_scene: PackedScene = null
var frame := 0
var phase := 0
var _dan: Node = null
var _alan: Node = null
var _seen := false
var _gesture_frames := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _initialize() -> void:
	seat_life = load("res://scripts/seat_life.gd")
	npc_scene = load("res://scenes/npc.tscn")
	change_scene_to_file("res://scenes/cubicle_area.tscn")


func _anim_names(s: AnimatedSprite2D) -> String:
	return str(s.animation)


func _static_checks() -> void:
	var chars := 0
	var bad := ""
	for f in DirAccess.get_files_at("res://characters"):
		if not f.ends_with(".tres"):
			continue
		var name := f.get_basename()
		var frames: SpriteFrames = load("res://characters/%s" % f)
		chars += 1
		for side in ["right", "left"]:
			for g in COUNTS:
				var an := "%s_%s" % [g, side]
				if not frames.has_animation(an):
					bad += "%s lacks %s; " % [name, an]
				elif frames.get_frame_count(an) != COUNTS[g] or frames.get_animation_loop(an):
					bad += "%s %s frames/loop; " % [name, an]
			if frames.get_frame_count("sit_%s" % side) != 2:
				bad += "%s sit changed; " % name
			var txt: String = FileAccess.get_file_as_string(
				"res://assets/characters/%s_%s_hands.json" % [name, side]
			)
			var hands: Array = JSON.parse_string(txt)
			if hands.size() != NFRAMES:
				bad += "%s %s hands %d; " % [name, side, hands.size()]
			var tex: Texture2D = load("res://assets/characters/%s_%s.png" % [name, side])
			if tex.get_width() != NFRAMES * 64:
				bad += "%s %s sheet width %d; " % [name, side, tex.get_width()]
	_check(chars >= 56 and bad == "", "all %d characters: 8 gestures, the toss and the couch pose x 2 facings, 135 frames, hands json (%s)" % [chars, bad.left(200)])


func _picker_checks() -> void:
	var a: RefCounted = seat_life.new("Dan", seat_life.salt_for("Dan", 3))
	var b: RefCounted = seat_life.new("Dan", seat_life.salt_for("Dan", 3))
	var c: RefCounted = seat_life.new("Dan", seat_life.salt_for("Dan", 4))
	var same: bool = a.timer == b.timer
	var differs: bool = a.timer != c.timer
	for i in 30:
		var ga: String = a.pick(i % 2 == 0, false, true)
		same = same and ga == b.pick(i % 2 == 0, false, true) and a.timer == b.timer
		differs = differs or ga != c.pick(i % 2 == 0, false, true)
	_check(same, "the picker is deterministic from the seed (same person and day)")
	_check(differs, "and another day gives another sequence")
	var gaps_ok := true
	var rng_a: RefCounted = seat_life.new("Maya", 7)
	for i in 100:
		rng_a.pick(true, false, false)
		gaps_ok = gaps_ok and rng_a.timer >= 5.0 and rng_a.timer <= 18.0
	_check(gaps_ok, "gaps are 5 to 18 seconds")
	var held_ok := true
	var typing_ok := true
	var nod_ok := true
	var sips := 0
	var all := {}
	var alan: RefCounted = seat_life.new("Alan", 11)
	var plain: RefCounted = seat_life.new("Sam", 12)
	for i in 400:
		var g: String = alan.pick(true, true, true)
		held_ok = held_ok and (g == "sip" or g in seat_life.HEAD_ONLY)
		sips += 1 if g == "sip" else 0
		var h: String = plain.pick(false, false, false)
		typing_ok = typing_ok and h != "sitmouse"
		var t: String = plain.pick(true, false, false)
		nod_ok = nod_ok and t != "sitnod"
		all[t] = true
		all[h] = true
	_check(held_ok, "with a drink: only the sip and head gestures")
	_check(sips > 150, "Alan sips often (%d of 400 with a cup)" % sips)
	_check(typing_ok, "no desk gesture away from a desk")
	_check(nod_ok, "no meeting nod while typing")
	# the couch pose (R26) is for lounge seats only
	var couch_off := true
	var couch_on := 0
	var lounger: RefCounted = seat_life.new("Sam", 13)
	for i in 300:
		couch_off = couch_off and plain.pick(false, false, false) != "sitcouch" and plain.pick(true, false, false) != "sitcouch"
		lounger.lounge = true
		couch_off = couch_off and lounger.pick(true, false, false) != "sitcouch"
		couch_on += 1 if lounger.pick(false, false, false) == "sitcouch" else 0
	_check(couch_off, "no arm over the back at a desk or on an office chair")
	_check(couch_on > 20, "on a couch the arm over the back shows up (%d of 300)" % couch_on)
	_check(all.size() >= 7, "a plain sitter uses many gestures (%d)" % all.size())


func _spawn(character: String, seat_name: String, item: String) -> Node:
	var n: Node = npc_scene.instantiate()
	n.character = character
	n.start_seat = seat_name
	n.start_item = item
	n.routine = PackedStringArray(["wait:1000000"])
	current_scene.get_node("Actors").add_child(n)
	return n


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or (phase == 0 and frame < 10):
		return false
	var game := root.get_node("Game")
	if phase == 0:
		_static_checks()
		_picker_checks()
		for other in current_scene.get_node("Actors").get_children():
			if "seat" in other and other.seat != null:  # the cast already sits here: clear the chairs
				other.seat.occupied = false
				other.seat = null
				other.queue_free()
		for zone in get_nodes_in_group("phones"):
			zone.remove_from_group("phones")  # a ringing desk phone would turn the gesture into a call: keep the room quiet
		_dan = _spawn("office_dan", "Seat1", "")
		_alan = _spawn("office_alan", "Seat2", "coffee")
		phase = 1
		frame = 0
	elif phase == 1 and frame == 5:
		_check(_dan.seat != null and _alan.seat != null, "two NPCs sit at their desks")
		_check(_anim_names(_dan.sprite).begins_with("type_"), "and type (%s)" % _anim_names(_dan.sprite))
		# blocked: a call, Game.busy, a chat, a grumble
		_dan._life = seat_life.new("Dan", 1)
		_dan._life.timer = 0.0
		_dan._call_stage = "talking"
		_dan._call_t = 1.0e6
		phase = 2
		frame = 0
	elif phase == 2 and frame == 90:
		_check(_dan._gesture == "", "no gesture during a phone call")
		_dan._call_stage = ""
		game.busy = true
		_dan._life.timer = 0.0
	elif phase == 2 and frame == 180:
		_check(_dan._gesture == "", "no gesture while Game.busy")
		game.busy = false
		_dan._hold = 100.0
		_dan._life.timer = 0.0
	elif phase == 2 and frame == 270:
		_check(_dan._gesture == "", "no gesture during a chat / talk hold")
		_dan._hold = 0.0
		_dan._grumble_t = 100.0
		_dan._life.timer = 0.0
	elif phase == 2 and frame == 360:
		_check(_dan._gesture == "", "no gesture during an outage grumble")
		_dan._grumble_t = 0.0
		_dan._life = null  # a fresh person: the natural gap (5 to 18 s) must produce one
		phase = 3
		frame = 0
	elif phase == 3:
		if _dan._gesture != "":
			_seen = true
			_gesture_frames += 1
			if _gesture_frames == 3:
				_check(
					str(_dan.sprite.animation).begins_with(str(_dan._gesture) + "_"),
					"the gesture plays its animation (%s)" % _dan._gesture
				)
		if _seen and _dan._gesture == "":
			_check(true, "a seated NPC gestured within %.1f s" % (frame / 60.0))
			_check(
				str(_dan.sprite.animation).begins_with("type_"), "and is back to typing (%s)" % _dan.sprite.animation
			)
			_check(_dan._item.item == "", "and nothing floats in the hand (%s)" % _dan._item.item)
			phase = 4
			frame = 0
		elif frame > 19 * 60 + 600:
			_check(false, "a seated NPC gestured within 19 s (state %s, call %s, item %s)" % [str(_dan.state), str(_dan._call_stage), str(_dan._item.item)])
			phase = 4
			frame = 0
	elif phase == 4 and frame == 2:
		# a seated NPC holding a drink: only head gestures and the sip, many draws
		var ok := true
		var kinds := {}
		_alan._life = seat_life.new("Alan", 5)
		for i in 120:
			_alan._gesture = ""
			_alan._item.item = ""
			_alan._start_gesture()
			var g: String = _alan._gesture
			kinds[g] = true
			ok = ok and (g == "sip" or g in seat_life.HEAD_ONLY)
			_alan._gesture = ""
		_alan._item.item = ""
		_check(ok and kinds.has("sip"), "an NPC with a cup only sips or turns the head (%s)" % str(kinds.keys()))
		_alan.queue_free()
		_alan.seat.occupied = false
		# the player
		var seat: Node2D = current_scene.get_node("Interactables/Seat2")
		var p: CharacterBody2D = current_scene.get_node("Actors/Player")
		p.global_position = Vector2(seat.global_position.x, 118)
		phase = 5
		frame = 0
	elif phase == 5 and frame == 20:
		Input.action_press("interact")
		Input.action_release("interact")
	elif phase == 5 and frame == 100:
		var p: CharacterBody2D = current_scene.get_node("Actors/Player")
		_check(p.state == "sitting", "the player is seated (%s)" % p.state)
		game.busy = true
	elif phase == 5 and frame == 130:
		var p: CharacterBody2D = current_scene.get_node("Actors/Player")
		if p._life != null:
			p._life.timer = 0.0
	elif phase == 5 and frame == 190:
		var p: CharacterBody2D = current_scene.get_node("Actors/Player")
		_check(not p.gesturing(), "the player does not gesture while Game.busy")
		game.busy = false
		p._life.timer = 0.0
	elif phase == 5 and frame == 200:
		var p: CharacterBody2D = current_scene.get_node("Actors/Player")
		_check(p.gesturing(), "the seated idle player gestures (%s)" % p.sprite.animation)
		_seen = false
		_gesture_frames = 0
	elif phase == 5 and frame > 200:
		var p: CharacterBody2D = current_scene.get_node("Actors/Player")
		if not p.gesturing():
			_check(p.state == "sitting", "and keeps sitting")
			_check(str(p.sprite.animation).begins_with("type_"), "and is back to type (%s)" % p.sprite.animation)
			phase = 6
			frame = 0
		elif frame > 700:
			_check(false, "the player's gesture ended")
			phase = 6
			frame = 0
	elif phase == 6:
		print("failures=%d" % failures)
		print("DONE")
		quit(1 if failures > 0 else 0)
	return false
