extends Node
# Autoload: the persistent cast. Alan, Garrison and Dan each live in exactly one place at a
# time and keep living when you are elsewhere. A workday clock (9:00 to 17:00, `day_len` real
# seconds long) drives their agenda: work at the desk, coffee, the copier and cooler, the
# bathroom, meetings in the conference room, lunch together at 12:00, then everyone leaves
# through the front door at 17:00 and comes back the next morning. In the room you are in they
# are real NPC nodes; anywhere else they are advanced by timers (each "leg" of their agenda has
# an estimated duration), so when you walk into a room they are where the simulation says.
# You can also ask someone to follow you (C next to them): they trail you through the doors
# until you ask again, they time out, or the day ends.

signal lights_changed(room: String)

const DATA := preload("res://scripts/world_data.gd")
const NPC_SCENE := preload("res://scenes/npc.tscn")
const HUD := preload("res://scripts/hud.gd")
const OUTSIDE := "__outside__"
const CAST := {
	"Alan": {"character": "office_alan", "home": "office_one", "seat": "Seat1"},
	"Garrison": {"character": "casual_garrison", "home": "office_two", "seat": "Seat1"},
	"Dan": {"character": "office_dan", "home": "main_floor", "seat": "Seat3"},
	"Vic": {"character": "sales_vic", "home": "cubicle_area", "seat": "Seat1", "role": "sales"},
	"Maya": {"character": "office_maya", "home": "main_floor", "seat": "Seat2"},
	# the manager: a desk in the cubicle area (desk 5), walks the floor, hosts the weekly all-hands. Not a tech.
	"Morgan": {"character": "office_morgan", "home": "cubicle_area", "seat": "Seat2", "role": "manager"},
}
const HOST_X := 84.0  # where the manager stands at the conference whiteboard during the all-hands
const SPEED := 32.0
const FLOOR_Y := 118.0
const SETTLE := 6.0  # after this long in a leg, someone you walk in on is already at the spot
const DAY_START := 9.0
const DAY_END := 17.0
const LUNCH_START := 12.0
const FOLLOW_SECS := 120.0
const CHAT_COOLDOWN := 60.0
const FOREVER := 1.0e9

var chars := {}  # name -> {scene, arrive, legs, leg_t, node, held, sips, ret, ...}
var time_scale := 1.0:
	get:
		# the day clock waits while a decision card or an outing is open
		if Campaign.active and (Cards.is_open or Outings.is_open):
			return 0.0
		return time_scale
var meeting_gap := Vector2(120.0, 190.0)
var day_len := 600.0  # real seconds for the 8 working hours
var clock := DAY_START
var day := 1
var hud_visible := true
var chat_count := 0
var chat_chance := 0.8
var lights := {}  # room -> bool (a missing room is lit)
var lights_by_npc := false  # a cast member is flipping a switch (nobody reacts to that)
var _outage_t := 0.0  # seconds the network has been down somewhere
var _closet_sent := false

var _meeting_t := 0.0
var _stage: Node = null
var _scene := ""
var _total := 0.0
var _pair_last := {}


func _ready() -> void:
	randomize()
	for n in CAST:
		chars[n] = _make_char(n)
	_meeting_t = Difficulty.rng("world.meeting").randf_range(meeting_gap.x, meeting_gap.y)
	lights_changed.connect(_on_lights_changed)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var hud := HUD.new()
	hud.visible = not OS.get_cmdline_args().has("--write-movie")
	hud_visible = hud.visible
	layer.add_child(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10 and not event.shift_pressed:
		hud_visible = not hud_visible


# ---- lights ------------------------------------------------------------------
func lights_on(room: String) -> bool:
	return lights.get(room, true)


func set_lights(room: String, on: bool) -> void:
	if lights_on(room) != on:
		lights[room] = on
		lights_changed.emit(room)


func toggle_lights(room: String) -> void:
	set_lights(room, not lights_on(room))


# nobody else of the cast is left in the room (so whoever is walking out turns the lights off)
func last_one_out(room: String, who: String) -> bool:
	for n in chars:
		if n != who and chars[n].scene == room:
			return false
	return true


func clock_text() -> String:
	var h := int(clock)
	var m := int((clock - float(h)) * 60.0)
	return "%d:%02d" % [h % 24, m]


# ---- the room the player is in -----------------------------------------------
func populate(stage: Node) -> void:
	_stage = stage
	_scene = stage.scene_file_path.get_file().get_basename()
	for n in chars:
		chars[n].node = null
		if chars[n].scene == _scene:
			_spawn(n)


func _spawn(n: String) -> void:
	var st: Dictionary = chars[n]
	var leg: Dictionary = st.legs[0]
	var info: Dictionary = DATA.SCENES[_scene]
	var npc: Node = NPC_SCENE.instantiate()
	npc.name = n
	npc.cast_name = n
	npc.character = CAST[n].character
	npc.start_item = st.held
	npc.sips = st.sips
	npc.following = st.following
	var elapsed: float = leg.dur - st.leg_t
	var routine: PackedStringArray = leg.routine
	var dark_arrival: bool = st.arrive != "" and not lights_on(_scene) and clock < DAY_END
	var spawn: Array = info.spawns.get(st.arrive, info.spawns["start"])
	var x := float(spawn[0])
	npc.facing = str(spawn[1])
	if str(leg.get("seat", "")) != "":
		npc.start_seat = str(leg.seat)
		routine = PackedStringArray(["wait:100000"])
		x = float(info.seats[leg.seat])
	elif leg.get("seated", false) and (leg.get("start_seated", false) or elapsed > SETTLE):
		npc.start_seat = CAST[n].seat
		routine = PackedStringArray(["wait:%d" % maxi(2, int(st.leg_t))])
		x = float(info.seats[CAST[n].seat])
	elif elapsed > SETTLE and leg.target_x >= 0.0 and leg.kind != "follow":
		x = leg.target_x
	elif dark_arrival and leg.kind != "follow":
		var pre := PackedStringArray(["walk:%d" % info.uses.switch, "lights:on"])
		pre.append_array(routine)
		routine = pre
	npc.routine = routine
	npc.position = Vector2(x, FLOOR_Y)
	if st.fresh:
		npc.modulate.a = 0.0
	_stage.get_node("Actors").add_child(npc)
	st.node = npc
	if st.fresh:
		st.fresh = false
		npc.fade_in()


# ---- events from NPC nodes ---------------------------------------------------
func leg_done(n: String) -> void:
	var st: Dictionary = chars[n]
	if st.legs.is_empty() or st.following:
		return
	st.legs.pop_front()
	if st.legs.is_empty():
		st.legs = _plan(n)
	st.leg_t = st.legs[0].dur
	if st.node != null and is_instance_valid(st.node):
		st.node.set_routine(st.legs[0].routine)


func leg_exit(n: String) -> void:
	var st: Dictionary = chars[n]
	var node: Node = st.node
	var to_outside: bool = st.legs[0].get("to_scene", "") == OUTSIDE
	if node != null and is_instance_valid(node):
		st.held = node.held
		st.sips = node.sips
		node._leaving = true
		if to_outside:
			node.fade_out()
		else:
			node.queue_free()
	st.node = null
	_finish_leg(n)


func node_left(n: String, held: String, sips: int) -> void:
	# the scene changed under a living NPC: carry on off-screen from about halfway through the leg
	if not chars.has(n):
		return  # a copy of somebody who just left the cast
	var st: Dictionary = chars[n]
	st.node = null
	st.held = held
	st.sips = sips
	st.leg_t = maxf(3.0, st.leg_t * 0.5)


# ---- off-screen simulation ---------------------------------------------------
func _process(delta: float) -> void:
	delta *= time_scale
	_total += delta
	clock += delta * 8.0 / day_len
	_watch_outage(delta)
	for n in chars:
		var st: Dictionary = chars[n]
		if st.following:
			st.follow_t -= delta
			if st.follow_t <= 0.0 or clock >= DAY_END:
				set_following(n, false)
		if st.node != null and is_instance_valid(st.node):
			continue
		st.leg_t -= delta
		if st.leg_t <= 0.0:
			_finish_leg(n)
	if clock >= DAY_END and _everyone_outside() and not Campaign.active:
		_new_day()
	_meeting_t -= delta
	if _meeting_t <= 0.0:
		_meeting_t = Difficulty.rng("world.meeting").randf_range(meeting_gap.x, meeting_gap.y)
		if clock < LUNCH_START - 0.3 or (clock > LUNCH_START + 1.3 and clock < DAY_END - 0.5):
			_start_meeting()


# ---- reactions: the network goes down, somebody switches the lights off ------------------------
func _watch_outage(delta: float) -> void:
	if delta <= 0.0 or Game.title_mode:
		return
	var down := false
	for d in range(1, 9):
		down = down or Net.desk_state(d) != "ok"
	if not down:
		_outage_t = 0.0
		_closet_sent = false
		return
	_outage_t += delta
	if _outage_t < 8.0 or _closet_sent or clock >= DAY_END - 0.3:
		return
	for who in ["Dan", "Alan", "Garrison", "Maya", "Vic"]:
		if not chars.has(who):
			continue
		var st: Dictionary = chars[who]
		var kind := str(st.legs[0].kind) if not st.legs.is_empty() else ""
		if st.following or st.scene != CAST[who].home or kind != "work":
			continue  # busy elsewhere right now: the next free person goes
		_closet_sent = true  # somebody is on the way; try again only after the network comes back
		force_activity(who, "closet")
		return


func _make_char(n: String) -> Dictionary:
	var leg := _work_leg(n, true, Difficulty.rng("world").randf_range(20.0, 50.0))
	return {
		"scene": CAST[n].home,
		"arrive": "",
		"legs": [leg],
		"leg_t": leg.dur,
		"node": null,
		"held": "",
		"sips": 0,
		"ret": "",
		"lunched": false,
		"following": false,
		"follow_t": 0.0,
		"fresh": false,
		"arriving": false,
	}


# the cast members who are NOT in the building right now: the person you play as (Campaign.player_as, a campaign
# or Free Play) and a partner who left (owner campaign). CAST itself never changes.
func roster_gone() -> Array:
	var gone := []
	if Campaign.player_as != "" and CAST.has(Campaign.player_as):
		gone.append(Campaign.player_as)
	# Maya is on your payroll in the owner campaign (X4); a partner who left the company is gone too
	if Campaign.active and Campaign.mode == "owner" and Partner.left and Roles.partner() != "":
		gone.append(Roles.partner())
	return gone


# the cast name of a character sheet ("office_dan" -> "Dan"), "" for someone who is not in CAST
func cast_of(character: String) -> String:
	for n in CAST:
		if str(CAST[n].character) == character:
			return n
	return ""


# where the person you play as sits at the start: {scene, seat} (empty when you are not a cast member)
func player_desk() -> Dictionary:
	var who := Campaign.player_as
	if who == "" or not CAST.has(who):
		return {}
	return {"scene": CAST[who].home, "seat": CAST[who].seat}


# remove whoever is gone from `chars` (their node too) and bring everyone else back, in CAST order
func apply_roster() -> void:
	var gone := roster_gone()
	for n in Mutators.absent():
		if not gone.has(n):
			gone.append(n)
	for n in gone:
		if chars.has(n):
			var st: Dictionary = chars[n]
			if st.node != null and is_instance_valid(st.node):
				st.node.queue_free()
			chars.erase(n)
	for n in CAST:
		if not gone.has(n) and not chars.has(n):
			chars[n] = _make_char(n)
			if _stage != null and is_instance_valid(_stage) and chars[n].scene == _scene:
				_spawn(n)  # you just stopped being them (Free Play): they are at their desk


func _on_lights_changed(room: String) -> void:
	if (
		lights_on(room)
		or lights_by_npc
		or Game.title_mode
		or room != _scene
		or clock >= DAY_END - 0.05
	):
		return
	get_tree().create_timer(2.5).timeout.connect(_react_to_dark.bind(room))


func _react_to_dark(room: String) -> void:
	if lights_on(room) or room != _scene or not is_instance_valid(_stage):
		return
	var switch_x := float(DATA.SCENES[room].uses.get("switch", -1.0))
	var present := []
	for n in chars:
		var node: Node = chars[n].node
		if node != null and is_instance_valid(node) and not chars[n].following:
			present.append(node)
	for node in present:
		node.grumble()
	if not present.is_empty() and switch_x >= 0.0:
		present[randi() % present.size()].react_lights(switch_x)


func _everyone_outside() -> bool:
	for n in chars:
		if chars[n].scene != OUTSIDE:
			return false
	return true


# campaign: send the whole cast home and start the morning of `number`
func begin_next_day(number: int) -> void:
	Mutators.prepare_day(number)
	apply_roster()
	for n in chars:
		var st: Dictionary = chars[n]
		if st.node != null and is_instance_valid(st.node):
			st.node._leaving = true
		st.node = null
		st.scene = OUTSIDE
		st.held = ""
		st.sips = 0
	lights.clear()
	day = number - 1
	_new_day()


# skip the night: next morning everyone drifts back in through the front door
func _new_day() -> void:
	day += 1
	clock = DAY_START - 0.5
	for n in chars:
		var st: Dictionary = chars[n]
		st.lunched = false
		st.following = false
		var wait_s := randf_range(5.0, 70.0)
		st.legs = [
			{
				"kind": "away",
				"scene": OUTSIDE,
				"routine": PackedStringArray(),
				"dur": wait_s,
				"target_x": -1.0,
				"to_scene": "main_floor",
				"to_spawn": "from_outside",
			}
		]
		st.leg_t = wait_s


# the current leg is over: step through its exit (if any) and start the next leg
func _finish_leg(n: String) -> void:
	var st: Dictionary = chars[n]
	var leg: Dictionary = st.legs.pop_front()
	if leg.get("visit", false):
		if Sales.visit_done():
			st["bell"] = true  # he rings the sales bell as soon as he is back in the office
	if leg.get("lights_last", false) and last_one_out(leg.scene, n):
		set_lights(leg.scene, false)
	if leg.has("to_scene"):
		var spawn: String = leg.to_spawn
		if spawn.begins_with("@"):
			spawn = st.ret
		if leg.get("remember", "") != "":
			st.ret = leg.remember
		st.scene = leg.to_scene
		st.arrive = spawn
		if st.scene != OUTSIDE and st.scene != _scene and clock < DAY_END:
			set_lights(st.scene, true)  # someone walking in unseen switches the lights on
		st.fresh = leg.kind == "away" and leg.scene == OUTSIDE
		st.arriving = st.fresh
		if st.scene == OUTSIDE:
			st.legs = [_away_leg()]
			st.leg_t = FOREVER
			if float(leg.get("visit_secs", 0.0)) > 0.0:
				var back: Dictionary = _away_leg()
				back["dur"] = float(leg.visit_secs)
				back["visit"] = true
				back["to_scene"] = "main_floor"
				back["to_spawn"] = "from_outside"
				st.legs = [back]
				st.leg_t = back.dur
			return
	if st.legs.is_empty():
		st.legs = _plan(n)
	if st.get("bell", false) and st.scene == "main_floor":
		st["bell"] = false
		(
			st
			. legs
			. push_front(
				{
					"kind": "bell",
					"scene": "main_floor",
					"target_x": 132.0,
					"routine": PackedStringArray(["stand", "walk:132", "use:salesbell", "wait:2"]),
					"dur": 9.0,
				}
			)
		)
	st.leg_t = st.legs[0].dur
	if st.scene == _scene and is_instance_valid(_stage) and st.node == null:
		_spawn(n)


# an outing: the whole cast stands around `spots` (set-pixel x values) in `room` until end_outing()
func start_outing(room: String, spots: Array, seats := {}, absent := []) -> void:
	var x0 := float(DATA.SCENES[room].x0)
	for n in chars:
		var i := CAST.keys().find(n)  # each person keeps their own standing spot, even when others are gone
		var st: Dictionary = chars[n]
		if st.node != null and is_instance_valid(st.node):
			st.node._leaving = true
		st.node = null
		if absent.has(n):  # not invited tonight (or has a thing): they stay out until the next morning / end_outing()
			st.scene = OUTSIDE
			st.following = false
			st.held = ""
			st.sips = 0
			st.legs = [_away_leg()]
			st.leg_t = FOREVER
			continue
		st.scene = room
		st.arrive = "from_outing"
		st.fresh = false
		st.arriving = false
		st.following = false
		st.held = ""
		st.sips = 0
		var x := x0 + float(spots[i % spots.size()])
		st.legs = [
			{
				"kind": "outing",
				"scene": room,
				"dur": FOREVER,
				"target_x": x,
				"seat": str(seats.get(n, "")),
				"routine": PackedStringArray(["wait:100000"]),
			}
		]
		st.leg_t = FOREVER - 100.0  # already standing at their spot when the room appears
	set_lights(room, true)


# the outing is over (free play): everyone drifts back in through the front door
func end_outing() -> void:
	for n in chars:
		var st: Dictionary = chars[n]
		if st.node != null and is_instance_valid(st.node):
			st.node._leaving = true
		st.node = null
		st.scene = OUTSIDE
		var back: Dictionary = _away_leg()
		back["dur"] = randf_range(4.0, 20.0)
		back["to_scene"] = "main_floor"
		back["to_spawn"] = "from_outside"
		st.legs = [back]
		st.leg_t = back.dur


func _away_leg() -> Dictionary:
	return {
		"kind": "away",
		"scene": OUTSIDE,
		"routine": PackedStringArray(),
		"dur": FOREVER,
		"target_x": -1.0,
	}


func _follow_leg() -> Dictionary:
	return {
		"kind": "follow",
		"scene": "",
		"routine": PackedStringArray(),
		"dur": FOREVER,
		"target_x": -1.0,
	}


# ---- following ---------------------------------------------------------------
func set_following(n: String, on: bool) -> void:
	var st: Dictionary = chars[n]
	if on == st.following:
		return
	st.following = on
	var node: Node = st.node if (st.node != null and is_instance_valid(st.node)) else null
	if on:
		st.follow_t = FOLLOW_SECS
		st.legs = [_follow_leg()]
		st.leg_t = FOREVER
	else:
		st.legs = _plan(n)
		st.leg_t = st.legs[0].dur
	if node != null:
		node.following = on
		if not on:
			node.set_routine(st.legs[0].routine)


# the player is changing rooms: everyone following heads for the same room
func player_left(_from: String, to: String) -> void:
	for n in chars:
		var st: Dictionary = chars[n]
		if not st.following or st.scene == OUTSIDE:
			continue
		var legs := []
		if st.scene != to:
			legs = _travel(st.scene, to, _hint_x(n))
		legs.append(_follow_leg())
		st.legs = legs
		st.leg_t = legs[0].dur


func _hint_x(n: String) -> float:
	var st: Dictionary = chars[n]
	if st.node != null and is_instance_valid(st.node):
		return st.node.global_position.x
	return _spawn_x(st.scene, st.arrive)


# ---- agendas -----------------------------------------------------------------
func _plan(n: String) -> Array:
	var st: Dictionary = chars[n]
	if st.following:
		return [_follow_leg()]
	if st.scene == OUTSIDE:
		return _outside_plan()
	var origin_x := _hint_x(n)
	if clock >= DAY_END:
		return _leave_plan(n, origin_x)
	if st.scene != CAST[n].home or st.arriving:
		st.arriving = false
		var legs := _travel(st.scene, CAST[n].home, origin_x)
		legs.append(_work_leg(n, false, Difficulty.rng("world").randf_range(25.0, 50.0)))
		return legs
	if clock >= LUNCH_START and not st.lunched and clock < LUNCH_START + 1.2:
		st.lunched = true
		# the account manager lunches with a client instead
		match str(CAST[n].get("role", "")):
			"sales":
				return _visit_plan(n, 50.0)
			"manager":
				return [_work_leg(n, true, 56.0)]  # the manager eats at her desk with the door open
		return _lunch_plan(n)
	var kinds := ["work", "work", "coffee", "coffee", "cooler", "bathroom"]
	if CAST[n].get("role", "") == "sales":
		kinds = ["work", "work", "visit", "visit", "coffee", "bathroom"]
	elif CAST[n].get("role", "") == "manager":
		kinds = ["work", "work", "floor", "floor", "floor", "coffee", "cooler"]
	return plan_for(n, kinds[Difficulty.rng("world").randi() % kinds.size()])


func plan_for(n: String, kind: String) -> Array:
	var legs := []
	match kind:
		"coffee":
			legs = _trip(n, "kitchenette", _coffee_leg())
		"visit":
			return _visit_plan(n, Difficulty.rng("world").randf_range(45.0, 90.0))
		"cooler":
			legs = _trip(n, "cubicle_area", _cooler_leg())
		"closet":
			legs = _trip(n, "network_closet", _closet_leg())
		"floor":
			legs = _trip(n, "main_floor", _floor_leg())
		"bathroom":
			legs = _trip(n, "bathroom", _bathroom_leg())
		_:
			return [_work_leg(n, true, Difficulty.rng("world").randf_range(30.0, 70.0))]
	legs.append(_work_leg(n, false, Difficulty.rng("world").randf_range(25.0, 55.0)))
	return legs


# there and back: travel legs, the activity leg, travel legs home
func _trip(n: String, scene: String, activity: Dictionary) -> Array:
	var home: String = CAST[n].home
	var x := float(DATA.SCENES[home].seats[CAST[n].seat])
	var legs := _travel(home, scene, x)
	activity.scene = scene
	legs.append(activity)
	legs.append_array(_travel(scene, home, activity.target_x))
	return legs


# lunch: bring a drink, then eat together at the conference table
func _lunch_plan(n: String) -> Array:
	var home: String = CAST[n].home
	var seat := "Seat%d" % (CAST.keys().find(n) + 1)
	var x := float(DATA.SCENES["conference"].seats[seat])
	var st: Dictionary = chars[n]
	st.held = ["soda", "bottle", "coffee"][randi() % 3]
	st.sips = 0
	if st.node != null and is_instance_valid(st.node):
		st.node.give_item(st.held)
	var routine := ["walk:%d" % x, "sit:%s" % seat]
	for _i in 9:
		routine.append_array(["wait:4", "say:2", "sip"])
	var eat := {
		"kind": "lunch",
		"scene": "conference",
		"target_x": x,
		"dur": 56.0,
		"routine": PackedStringArray(routine),
	}
	var legs := _travel(st.scene, "conference", _hint_x(n))
	legs.append(eat)
	legs.append_array(_travel("conference", home, x))
	legs.append(_work_leg(n, false, Difficulty.rng("world").randf_range(25.0, 45.0)))
	return legs


# end of the day: out through the front door; back at the start of the next day
func _leave_plan(n: String, from_x: float) -> Array:
	var door_x := float(DATA.SCENES["main_floor"].outside_x)
	var legs := _travel(chars[n].scene, "main_floor", from_x, true)
	var arrive_x := door_x
	if not legs.is_empty():
		arrive_x = _spawn_x("main_floor", legs[legs.size() - 1].to_spawn)
	(
		legs
		. append(
			{
				"kind": "leave",
				"scene": "main_floor",
				"target_x": door_x,
				"routine":
				PackedStringArray(
					[
						"stand",
						"walk:%d" % _uses("main_floor").switch,
						"lights:last",
						"walk:%d" % door_x,
						"exit:FrontDoor"
					]
				),
				"dur": absf(door_x - arrive_x) / SPEED + 4.0,
				"to_scene": OUTSIDE,
				"to_spawn": "",
				"lights_last": true,
			}
		)
	)
	return legs


# planned while outside with no way back queued: stay out after closing, else come in the front door
func _outside_plan() -> Array:
	if clock >= DAY_END:
		return [_away_leg()]
	var back := _away_leg()
	back["dur"] = randf_range(5.0, 20.0)
	back["to_scene"] = "main_floor"
	back["to_spawn"] = "from_outside"
	return [back]


# the account manager leaves for a client visit and comes back through the front door
func _visit_plan(n: String, secs: float) -> Array:
	var door_x := float(DATA.SCENES["main_floor"].outside_x)
	var legs := _travel(chars[n].scene, "main_floor", _hint_x(n))
	var arrive_x := door_x
	if not legs.is_empty():
		arrive_x = _spawn_x("main_floor", legs[legs.size() - 1].to_spawn)
	(
		legs
		. append(
			{
				"kind": "leave",
				"scene": "main_floor",
				"target_x": door_x,
				"routine": PackedStringArray(["stand", "walk:%d" % door_x, "exit:FrontDoor"]),
				"dur": absf(door_x - arrive_x) / SPEED + 3.0,
				"to_scene": OUTSIDE,
				"to_spawn": "",
				"visit_secs": secs,
			}
		)
	)
	return legs


# a client complained to Vic: he walks over to wherever you are and tells you
func send_vic_to_player() -> void:
	if not chars.has("Vic") or _scene == "":
		Sales.pending = {}
		return
	var st: Dictionary = chars["Vic"]
	if st.scene == OUTSIDE or st.following:
		var said := Sales.complaint_text()
		if said != "":
			Msp.send_text("Vic", said)
			Sales.adjust(int(Sales.pending.get("client", 0)), -2)
		Sales.pending = {}
		return
	var px := 150.0
	var player: Node = (
		_stage.get_node_or_null("Actors/Player") if is_instance_valid(_stage) else null
	)
	if player != null:
		px = player.global_position.x
	var info: Dictionary = DATA.SCENES[_scene]
	var from_x := _hint_x("Vic")
	var stand := clampf(
		px - 34.0 if from_x < px else px + 34.0,
		float(info.x0) + 16.0,
		float(info.x0 + info.W) - 16.0
	)
	var legs := []
	if st.scene != _scene:
		legs = _travel(st.scene, _scene, from_x)
	(
		legs
		. append(
			{
				"kind": "news",
				"scene": _scene,
				"target_x": stand,
				"routine": PackedStringArray(["stand", "walk:%d" % int(stand), "notify:news"]),
				"dur": absf(stand - from_x) / SPEED + 8.0,
			}
		)
	)
	st.legs = legs
	st.leg_t = legs[0].dur
	if st.node != null and is_instance_valid(st.node):
		st.node.set_routine(legs[0].routine)


func _travel(from_scene: String, to_scene: String, from_x: float, closing := false) -> Array:
	var legs := []
	var x := from_x
	for link in _route(from_scene, to_scene):
		var routine := ["stand", "walk:%d" % link.x, "exit:%s" % link.name]
		if closing:  # end of the day: the last one out of each room turns its lights off
			routine = (
				["stand", "walk:%d" % _uses(link.from).switch, "lights:last"] + routine.slice(1)
			)
		(
			legs
			. append(
				{
					"kind": "travel",
					"scene": link.from,
					"target_x": float(link.x),
					"routine": PackedStringArray(routine),
					"dur": absf(float(link.x) - x) / SPEED + (4.0 if closing else 2.0),
					"to_scene": link.to,
					"to_spawn": link.spawn,
					"remember": link.get("remember", ""),
					"lights_last": closing,
				}
			)
		)
		x = _spawn_x(link.to, link.spawn)
	return legs


func _spawn_x(scene: String, spawn: String) -> float:
	if not DATA.SCENES.has(scene):
		return 100.0
	var spawns: Dictionary = DATA.SCENES[scene].spawns
	return float(spawns.get(spawn, spawns["start"])[0])


func _route(a: String, b: String) -> Array:
	if not DATA.SCENES.has(a) or not DATA.SCENES.has(b):
		return []
	var came := {}
	var queue := [a]
	came[a] = null
	while not queue.is_empty() and not came.has(b):
		var cur: String = queue.pop_front()
		for link in DATA.SCENES[cur].links:
			if not came.has(link.to):
				var hop: Dictionary = link.duplicate()
				hop["from"] = cur
				came[link.to] = hop
				queue.append(link.to)
	var path := []
	var at := b
	while came.has(at) and came[at] != null:
		path.push_front(came[at])
		at = came[at].from
	return path if came.has(b) else []


func _uses(scene: String) -> Dictionary:
	return DATA.SCENES[scene].uses


# Owners.step_in: the owner walks to a ringing phone on the stage, answers it with a headset and goes back to work
func send_owner_cover(n: String, x: float) -> bool:
	if not chars.has(n) or _scene == "" or not DATA.SCENES.has(_scene):
		return false
	var st: Dictionary = chars[n]
	var from_x := _hint_x(n)
	var legs := _travel(st.scene, _scene, from_x)
	if st.scene != _scene and legs.is_empty():
		return false
	legs.append(
		{
			"kind": "cover",
			"scene": _scene,
			"target_x": x,
			"routine": PackedStringArray(["stand", "walk:%d" % int(x), "answer"]),
			"dur": absf(x - from_x) / SPEED + 10.0,
		}
	)
	legs.append_array(_travel(_scene, CAST[n].home, x))
	legs.append(_work_leg(n, false, 30.0))
	st.legs = legs
	st.leg_t = legs[0].dur
	if st.node != null and is_instance_valid(st.node):
		st.node.set_routine(legs[0].routine)
	return true


func _work_leg(n: String, start_seated: bool, secs: float) -> Dictionary:
	var seat: String = CAST[n].seat
	var x := float(DATA.SCENES[CAST[n].home].seats[seat])
	var half := int(secs * 0.5)
	return {
		"kind": "work",
		"scene": CAST[n].home,
		"seated": true,
		"start_seated": start_seated,
		"routine":
		PackedStringArray(
			["walk:%d" % x, "sit:%s" % seat, "wait:%d" % half, "sip", "wait:%d" % int(secs - half)]
		),
		"dur": secs + (0.0 if start_seated else 4.0),
		"target_x": x,
	}


func _coffee_leg() -> Dictionary:
	var u: Dictionary = _uses("kitchenette")
	var routine := ["walk:%d" % u.coffee, "use:coffee", "wait:1", "sip", "wait:2"]
	var dur := 20.0
	if randf() < 0.5:
		routine.append_array(["walk:%d" % u.fridge, "use:fridge", "wait:1", "sip"])
		dur += 12.0
	return {
		"kind": "coffee",
		"routine": PackedStringArray(routine),
		"dur": dur,
		"target_x": float(u.coffee)
	}


# somebody goes to look at the rack when the network has been down for a while
func _closet_leg() -> Dictionary:
	var x := float(DATA.SCENES["network_closet"].x0) + 86.0
	return {
		"kind": "closet",
		"dur": 22.0,
		"target_x": x,
		"routine": PackedStringArray(["walk:%d" % int(x), "wait:3", "talk:5", "wait:6"]),
	}


# the manager walks the main floor: a word at each desk, then back
func _floor_leg() -> Dictionary:
	return {
		"kind": "floor",
		"dur": 36.0,
		"target_x": 100.0,
		"routine":
		PackedStringArray(["walk:270", "wait:1", "talk:4", "walk:196", "wait:1", "talk:3", "walk:100", "wait:2"]),
	}


func _cooler_leg() -> Dictionary:
	var u: Dictionary = _uses("cubicle_area")
	return {
		"kind": "cooler",
		"dur": 24.0,
		"target_x": float(u.copier),
		"routine":
		PackedStringArray(
			[
				"walk:%d" % u.copier,
				"use:copier",
				"walk:%d" % u.cooler,
				"use:cooler",
				"wait:2",
				"sip"
			]
		),
	}


func _bathroom_leg() -> Dictionary:
	var u: Dictionary = _uses("bathroom")
	return {
		"kind": "bathroom",
		"dur": 12.0,
		"target_x": float(u.sink),
		"routine": PackedStringArray(["walk:%d" % u.sink, "use:sink", "wait:2"]),
	}


# ---- conversations between cast members --------------------------------------
# NPC nodes ask permission when they bump into each other (a cooldown stops endless chatter)
func try_chat(a: String, b: String) -> bool:
	var key := a + "|" + b if a < b else b + "|" + a
	if _total - float(_pair_last.get(key, -1.0e9)) < CHAT_COOLDOWN:
		return false
	if randf() > chat_chance:
		_pair_last[key] = _total - CHAT_COOLDOWN + 3.0  # try again in a few seconds
		return false
	_pair_last[key] = _total
	chat_count += 1
	return true


# ---- meetings ----------------------------------------------------------------
func _start_meeting() -> void:
	var ready_names := []
	for n in chars:
		var st: Dictionary = chars[n]
		var at_desk: bool = st.scene == CAST[n].home and st.legs.size() == 1
		if at_desk and st.legs[0].kind == "work" and not st.following:
			ready_names.append(n)
	if ready_names.size() < 2:
		return
	ready_names.shuffle()
	for i in mini(3, ready_names.size()):
		send_to_meeting(ready_names[i], "Seat%d" % (i + 1))


# the weekly all-hands: everyone goes to the conference room and sits (the last seats are yours)
func start_all_hands() -> void:
	var i := 1
	var owner_mode := Campaign.mode == "owner"
	for n in CAST:
		if not chars.has(n):
			continue
		if chars[n].following:
			set_following(n, false)
		if CAST[n].get("role", "") == "manager" and not owner_mode:
			send_to_meeting(n, "", 90.0)  # Morgan hosts: standing at the whiteboard, no chair
			continue
		send_to_meeting(n, "Seat%d" % i, 90.0)
		i += 1


func send_to_meeting(n: String, seat: String, secs := 48.0) -> void:
	var st: Dictionary = chars[n]
	var home: String = CAST[n].home
	var hosting := seat == ""
	var x := HOST_X if hosting else float(DATA.SCENES["conference"].seats[seat])
	var routine := ["walk:%d" % x]
	if not hosting:
		routine.append("sit:%s" % seat)
	for _i in int(secs / 6.0):
		routine.append_array(["wait:3", "talk:3"] if hosting else ["wait:3", "say:2"])
	var meeting := {
		"kind": "meeting",
		"scene": "conference",
		"target_x": x,
		"dur": secs,
		"routine": PackedStringArray(routine),
	}
	var here: String = st.scene
	var legs := _travel(here, "conference", _hint_x(n))
	legs.append(meeting)
	legs.append_array(_travel("conference", home, x))
	legs.append(_work_leg(n, false, Difficulty.rng("world").randf_range(25.0, 50.0)))
	st.legs = legs
	st.leg_t = legs[0].dur
	if st.node != null and is_instance_valid(st.node):
		st.node.set_routine(legs[0].routine)


# a character is sent off to do something now (used by tests and for scripted scenes)
func force_activity(n: String, kind: String) -> void:
	var st: Dictionary = chars[n]
	var legs := plan_for(n, kind)
	st.legs = legs
	st.leg_t = legs[0].dur
	if st.node != null and is_instance_valid(st.node):
		st.node.set_routine(legs[0].routine)
