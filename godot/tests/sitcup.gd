extends SceneTree
# gdlint:disable=max-line-length
# R26 leftover: the coffee-cup reach while typing (`sitcup`). A seated NPC with a cup on the desk now and then slides the near
# hand over to the cup, pulls it along and puts it back, without drinking. No new frames: it plays the existing `sitmouse`
# animation, the cup leaves the desk for the hand (held_item.gd follows the sitmouse hand positions) from the second frame and
# stands on the desk again at the end. The picker offers it only while typing with a cup in reach; a sip is still a sip.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/sitcup.gd

var failures := 0
var seat_life: GDScript = null
var npc_scene: PackedScene = null
var frame := 0
var phase := 0
var _alan: Node = null
var _desk_x := 0.0
var _saw_on_desk := false  # frame 0 of the slide: the cup is still on the desk
var _saw_in_hand := false  # later frames: the cup is in the hand
var _hand_xs := {}
var _sips0 := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _initialize() -> void:
	seat_life = load("res://scripts/seat_life.gd")
	npc_scene = load("res://scenes/npc.tscn")
	change_scene_to_file("res://scenes/cubicle_area.tscn")


func _spawn(character: String, seat_name: String, item: String) -> Node:
	var n: Node = npc_scene.instantiate()
	n.character = character
	n.start_seat = seat_name
	n.start_item = item
	n.routine = PackedStringArray(["wait:1000000"])
	current_scene.get_node("Actors").add_child(n)
	return n


func _picker_checks() -> void:
	var held: GDScript = load("res://scripts/held_item.gd")
	_check(seat_life.ALL.has("sitcup") and seat_life.BASE.has("sitcup"), "the picker knows the cup reach")
	_check(held.START.has("sitmouse") and not held.START.has("sitcup"), "it has no frames of its own: the hand positions are sitmouse's")
	var plain: RefCounted = seat_life.new("Sam", 12)
	_check(plain.weight("sitcup", true, true, true) > 0.0, "typing with a cup in reach: possible")
	_check(plain.weight("sitcup", false, true, true) == 0.0, "not typing (a meeting, lunch): never")
	_check(plain.weight("sitcup", true, false, false) == 0.0 and plain.weight("sitcup", true, true, false) == 0.0, "no cup in reach: never")
	var kinds := {}
	var away := true
	for i in 600:
		var g: String = plain.pick(true, true, true)
		kinds[g] = int(kinds.get(g, 0)) + 1
		away = away and plain.pick(false, true, true) != "sitcup" and plain.pick(true, false, false) != "sitcup"
	_check(int(kinds.get("sitcup", 0)) > 60 and int(kinds.get("sip", 0)) > 60, "typing with a cup: reaches and sips both turn up (%s)" % str(kinds))
	_check(away, "600 draws without a cup or away from the keys: no cup reach")
	for g in kinds:
		_check(g in ["sip", "sitcup"] or g in seat_life.HEAD_ONLY, "with a cup the picker gives %s (a cup gesture or a head one)" % g)
	var a: RefCounted = seat_life.new("Alan", seat_life.salt_for("Alan", 3))
	var b: RefCounted = seat_life.new("Alan", seat_life.salt_for("Alan", 3))
	var same := true
	for i in 50:
		same = same and a.pick(true, true, true) == b.pick(true, true, true)
	_check(same, "the picker is still deterministic from the seed")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or (phase == 0 and frame < 10):
		return false
	if phase == 0:
		_picker_checks()
		for other in current_scene.get_node("Actors").get_children():
			if "seat" in other and other.seat != null:
				other.seat.occupied = false
				other.seat = null
				other.queue_free()
		for zone in get_nodes_in_group("phones"):
			zone.remove_from_group("phones")
		_alan = _spawn("office_alan", "Seat2", "coffee")
		phase = 1
		frame = 0
	elif phase == 1 and frame == 10:
		_check(_alan.seat != null and bool(_alan.seat.typing) and str(_alan.sprite.animation).begins_with("type_"), "Alan types at his desk")
		_check(_alan._desk != null and _alan._desk.item == "coffee" and _alan._item.item == "", "his coffee stands on the desk")
		_desk_x = _alan._desk.position.x
		_sips0 = _alan.sips
		# force the reach (the picker's choice is covered above)
		_alan._gesture = "sitcup"
		_alan.sprite.play("sitmouse_%s" % _alan.facing)
		phase = 2
		frame = 0
	elif phase == 2:
		if _alan._gesture == "sitcup":
			var f: int = _alan.sprite.frame
			if f < _alan.CUP_REACH_FRAME and _alan._desk.item == "coffee" and _alan._item.item == "":
				_saw_on_desk = true
			if f >= _alan.CUP_REACH_FRAME and frame > 2 and _alan._item.item == "coffee" and _alan._desk.item == "":
				_saw_in_hand = true
				if _alan._item.visible:
					_hand_xs[f] = _alan._item.position
		else:
			_check(_saw_on_desk, "the hand goes out first: on the first frame the cup is still on the desk")
			_check(_saw_in_hand, "then the cup is in the hand for the rest of the slide (off the desk)")
			_check(_hand_xs.size() >= 1, "the cup is drawn at the sitmouse hand positions (%s)" % str(_hand_xs))
			_check(str(_alan.sprite.animation).begins_with("type_"), "afterwards he types again (%s)" % _alan.sprite.animation)
			_check(_alan._desk.item == "coffee" and _alan._item.item == "" and is_equal_approx(_alan._desk.position.x, _desk_x), "and the cup is back on the desk where it stood")
			_check(_alan.sips == _sips0 and _alan.held == "coffee", "nothing was drunk: the sips are not counted")
			phase = 3
			frame = 0
		if frame > 600:
			_check(false, "the cup reach ended")
			phase = 3
			frame = 0
	elif phase == 3 and frame == 2:
		# through the picker in the room: many starts, the reach turns up and plays sitmouse; a sip still plays sitsip
		var seen := {}
		var anims_ok := true
		_alan._life = seat_life.new("Alan", 5)
		for i in 200:
			_alan._gesture = ""
			_alan._stash()
			_alan._start_gesture()
			var g: String = _alan._gesture
			seen[g] = true
			if g == "sitcup":
				anims_ok = anims_ok and str(_alan.sprite.animation).begins_with("sitmouse_") and _alan._desk.item == "coffee"
			elif g == "sip":
				anims_ok = anims_ok and str(_alan.sprite.animation).begins_with("sitsip_") and _alan._item.item == "coffee"
		_check(seen.has("sitcup") and seen.has("sip"), "in the room the picker starts both the reach and the sip (%s)" % str(seen.keys()))
		_check(anims_ok, "the reach plays sitmouse with the cup still on the desk, the sip plays sitsip with the cup in the hand")
		# cancelled halfway (a call comes in): the cup goes back to the desk
		_alan._gesture = "sitcup"
		_alan._unstash()
		_alan._cancel_gesture()
		_check(_alan._gesture == "" and _alan._desk.item == "coffee" and _alan._item.item == "", "a cancelled reach puts the cup back")
		phase = 4
		frame = 0
	elif phase == 4:
		print("sitcup: %d failure(s)" % failures)
		quit(1 if failures > 0 else 0)
	return false
