extends Node2D
# gdlint:disable=class-definitions-order,max-returns
# Procedural ambient motion and one-shot "use" animations, drawn over the art.
# Coordinates are art-local: (0, 0) is the top-left of the piece/background art this node sits on.

signal finished
signal handed  # the item is ready to hand over (mid-effect for the fridge)

const PixelFont := preload("res://scripts/pixelfont.gd")
const BowlVariety := preload("res://scripts/bowl_variety.gd")
const DUCK_SKINS := {
	"duck_gold": preload("res://assets/props/rubber_duck_gold.png"),
	"duck_pirate": preload("res://assets/props/rubber_duck_pirate.png"),
}
const Dashboard := preload("res://scripts/dashboard.gd")  # the wall TV's micro channel and the glance hint (R20)
const STEP := 1.0 / 12.0
const ITEMS := {"coffee": "coffee", "cooler": "water", "nerf_rack": "nerf"}
const LYRICS := [
	"OH OH FRIDAY AT FIVE",
	"WE ARE THE TICKET QUEUE",
	"GOT NO SLA TONIGHT",
	"TURN IT OFF AND ON AGAIN",
	"SING IT FOR THE HELP DESK",
	"PASSWORD ONE TWO THREE",
]
const NEON := {
	"neon_bowl": [Vector2(53, 21), Color("e04ecb")],
	"neon_shoes": [Vector2(44, 16), Color("f2c94c")],
	"neon_karaoke": [Vector2(60, 16), Color("3ee0e0")],
	"neon_bar": [Vector2(39, 21), Color("e04e4e")],
}
const DURATIONS := {
	"coffee": 7.0,
	"copier": 3.2,
	"cooler": 1.8,
	"sink": 2.6,
	"toilet": 3.0,
	"tv": 0.5,
	"monitor": 0.0,
	"fridge": 3.2,
	"desk_phone": 10.4,
	"switch": 0.35,
	"vending_machine": 1.8
}
# seconds into the effect when the item is handed over (default: at the end)
const HAND_AT := {"fridge": 1.5, "vending_machine": 1.2}
const DART_LINES := [
	"BULLSEYE... NEARLY.",
	"TWENTY. NOT BAD.",
	"THREE DARTS. ONE IN THE WOOD.",
	"SOMEONE KEEPS SCORE ON THE SHEET.",
]
# the old Christmas tree at the end of the warehouse (E): the first time there is a Santa hat in the box of ornaments (the OLD TREE
# medal unlocks it in the character creator), after that the tree just stands there
const TREE_FIRST := "A BOX OF ORNAMENTS. A SANTA HAT, STILL GOOD. YOURS NOW."
const TREE_LINES := [
	"NOBODY HAS TAKEN THE TREE DOWN SINCE DECEMBER.",
	"ONE STRING OF BULBS STILL WORKS. GOOD ENOUGH.",
	"A TREE IN A WAREHOUSE. IT FITS.",
]
const TREE_BULBS := [
	Vector2(17, 10),
	Vector2(12, 18),
	Vector2(22, 20),
	Vector2(9, 28),
	Vector2(25, 30),
	Vector2(14, 36),
	Vector2(20, 38),
	Vector2(6, 44),
	Vector2(28, 46),
	Vector2(17, 48),
]

@export var kind := "monitor"
@export var seed_offset := 0
@export var desk := 0  # desk 1-8 = its patch panel port; the network decides if it works
@export var panel := 0  # monitor screens: 0 = the single big monitor, 1 = the 4:3 panel A (E opens the computer), 2 = the 16:9 panel B

var busy := false
var item := ""
var style := ""  # "call": the user holds the handset to the ear for the length of the effect
var ringing := false
var call_secs := 9.0  # time on the headset (plus 0.7 s to put it on and take it off)

var _handed := false
var _ring_until := 0.0
var _next_ring := 0.0
var _ring_snd := 0.0
var _coffee_stage := 0  # which part of the coffee machine sound has played (pump, pour, groan)
var _handset: Texture2D
var _room := ""

var _hit_until := 0.0
var _dart_n := 0
var _time := 0.0
var _acc := 0.0
var _scroll := 0.0
var _start := -100.0
var _level := 0.0
var _channel := 0
var _glance_t := 0.0  # the TV checks the board once a second
var _glance_col := Color(0, 0, 0, 0)  # the colour the TV frame flashes (clear = nothing red)
var _next_channel := 7.0
var _static_until := 0.0
var _player: Node = null

const DOOR_SECS := 3.0  # the roll-up door takes this long
const DOOR_TEX_H := 82  # the door sprite: 120 x 80 plus the outline pad
var open := 0.0  # roll_door: how far open the slats are (0 closed, 1 open), moved toward goal
var goal := 0.0  # roll_door: the state asked for (World.door_open)
var _door: Sprite2D = null
var _door_acc := 0.0
var _door_snd := 0.0
var _door_loud := false  # the rattle is heard everywhere (the chair race start), not by distance


func _ready() -> void:
	item = ITEMS.get(kind, "")
	if str(name) == "TvB":
		seed_offset = 1
	_time = float(seed_offset) * 1.7
	_room = owner.scene_file_path.get_file().get_basename() if owner != null else ""
	if kind == "monitor":
		style = "computer"
	if (
		(
			kind
			in [
				"monitor",
				"tv",
				"fridge",
				"lyrics",
				"keypad",
				"ledtimer",
				"redlight",
				"sports_tv",
				"bowl_score",
				"bench_screen",
				"tree_lights",
				"session_screen"
			]
		)
		or kind.begins_with("neon")
	):
		add_to_group("emissive")  # screens and the open fridge keep glowing when the lights are out
	if kind == "bell":
		add_to_group("bells")
	if kind == "desk_phone":
		style = "call"
		_handset = load("res://assets/props/desk_phone_handset.png")
		_next_ring = _time + 14.0 + float(seed_offset % 5) * 8.0
	_next_channel = _time + 7.0
	_start = _time - 100.0
	if kind == "roll_door":
		_door_ready()
	if kind == "dart_board":
		z_index = 1  # the live darts are drawn over the panel sprite (an actor) they stick in


# a foam dart hit this screen: it glitches for a moment
func hit() -> void:
	_hit_until = _time + 1.4


# a rolled-over call: this desk phone rings for a while (the player may pick it up)
func ring_for(secs: float) -> void:
	if kind == "desk_phone" and not busy:
		ringing = true
		_ring_until = _time + secs


func play() -> void:
	if kind.begins_with("clue_") or kind.begins_with("herring_") or kind == "keypad" or kind.begins_with("cornhole_") or kind == "grill":
		Outings.interact(kind)
		return
	if kind == "bell":
		ring("vic")  # only John reaches that high (the player's use is blocked in interact.gd)
		return
	if kind == "rubber_duck":
		_duck_press()
		return
	if kind == "roll_door" or kind == "door_switch":
		door_press()
		return
	if kind == "dart_board":
		if not Outings.offer_darts():  # a round of darts (a card); when none can start now the board just makes a joke
			_dart_n += 1
			Hints.toast(DART_LINES[(_dart_n - 1) % DART_LINES.size()], 2.5)
		return
	if _warehouse_press():
		return
	if kind == "old_tree":
		_tree_press()
		return
	if kind.begins_with("booth_"):
		Expo.booth(kind.substr(6))
		return
	if kind.begins_with("onsite_"):
		Onsite.interact(kind.substr(7))
		return
	if busy:
		return
	if kind == "vending_machine" and not _vend_start():
		return
	busy = true
	_handed = false
	_start = _time
	if kind == "vending_machine":
		_vend_go()
	if kind == "fridge":
		item = ["soda", "bottle"][randi() % 2]
	if kind == "desk_phone":
		ringing = false
		Sfx.play_near("headset", self)
	if kind == "coffee":
		Sfx.play_near("coffee", self)
		_coffee_stage = 0
	if kind == "switch":
		World.toggle_lights(_room)
	if kind == "tv":
		_next_channel = _time + 7.0
		_channel = (_channel + 1) % 4
		_static_until = _time + 0.4


# E on the old tree: the first time it counts for the OLD TREE medal (the Santa hat of the character creator), later it is a remark
func _tree_press() -> void:
	var first := not Career.has_medal("old_tree")
	Career.add("old_tree")
	_dart_n += 1
	var lights: Node = get_parent().get_node_or_null("TreeLights")
	if first or lights == null or _dart_n % 3 == 0:
		Hints.toast(TREE_FIRST if first else TREE_LINES[(_dart_n - 1) % TREE_LINES.size()], 3.0)
	else:
		Hints.toast(lights.tree_toggle(), 3.0)


func _process(delta: float) -> void:
	_time += delta
	if kind == "tv":
		_tv_tick(delta)
	if kind == "roll_door":
		_door_tick(delta)
	if kind == "rubber_duck":
		_duck_tick(delta)
	if kind == "vending_machine":
		_vend_tick()
	if _bell_t > 0.0:
		_bell_t = maxf(0.0, _bell_t - delta)
		queue_redraw()
	if _player == null and get_tree().current_scene != null:
		_player = Players.player0()
	if busy and not _handed and _time - _start >= float(HAND_AT.get(kind, 99.0)):
		_handed = true
		handed.emit()
	if busy and _time - _start >= float(DURATIONS.get(kind, 1.0)):
		busy = false
		if not _handed:
			_handed = true
			handed.emit()
		if kind == "desk_phone":
			_next_ring = _time + 40.0
		finished.emit()
	if kind == "desk_phone" and not busy:
		if Net.desk_state(desk) != "ok":
			ringing = false
		elif ringing and _time > _ring_until:
			ringing = false
			_next_ring = _time + 35.0 + float(seed_offset % 4) * 6.0
		elif not ringing and _time >= _next_ring:
			ringing = true
			_ring_until = _time + 12.0
		if ringing and _time >= _ring_snd:
			_ring_snd = _time + 3.5
			Sfx.play_near("phone_ring", self)
	if kind == "monitor":
		_scroll += delta * (3.0 if _typing_nearby() else 0.7)
	if kind == "coffee":
		if busy:
			_level = minf(1.0, (_time - _start) / 5.5)
			if _coffee_stage == 0 and _time - _start >= 1.6:
				_coffee_stage = 1
				Sfx.play_near("coffee_pour", self)
			elif _coffee_stage == 1 and _time - _start >= 4.9:
				_coffee_stage = 2
				Sfx.play_near("coffee_done", self)
		else:
			_level = maxf(0.0, _level - delta / 40.0)
	_acc += delta
	if _acc >= STEP:
		_acc = 0.0
		queue_redraw()


func _typing_nearby() -> bool:
	return (
		_player != null
		and _player.state == "sitting"
		and absf(_player.global_position.x - global_position.x) < 40.0
	)


func _draw() -> void:
	match kind:
		"monitor":
			_draw_monitor()
		"tv":
			_draw_tv()
		"rack":
			_draw_rack()
		"toner_kit":
			_draw_toner_kit()
		"switch":
			_draw_switch()
		"door_switch":
			_draw_door_switch()
		"desk_phone":
			_draw_phone()
		"fridge":
			_draw_fridge()
		"coffee":
			_draw_coffee()
		"copier":
			_draw_copier()
		"cooler":
			_draw_cooler()
		"sink":
			_draw_sink()
		"toilet":
			_draw_toilet()
		"neon_bowl", "neon_shoes", "neon_karaoke", "neon_bar":
			_draw_neon()
		"sports_tv":
			_draw_sports()
		"bowl_lane":
			_draw_bowl_lane()
		"cornhole_a":
			_draw_cornhole_a()
		"cornhole_b":
			_draw_cornhole_board("b")
		"cornhole_tray":
			_draw_cornhole_tray()
		"grill":
			_draw_grill()
		"bowl_score":
			_draw_bowl_score()
		"clue_board":
			_draw_clue_board()
		"clue_clock":
			_draw_clue_clock()
		"clue_painting":
			_draw_clue_painting()
		"clue_shelf":
			_draw_clue_shelf()
		"lyrics":
			_draw_lyrics()
		"discoball":
			_draw_disco()
		"keypad":
			_draw_keypad()
		"ledtimer":
			_draw_timer()
		"redlight":
			_draw_redlight()
		"lamp":
			_draw_lamp()
		"session_sign":
			_draw_session_sign()
		"session_screen":
			_draw_session_screen()
		"bell":
			_draw_bell()
		"rubber_duck":
			_draw_duck()
		"flicker_lamp":
			_draw_flicker_lamp()
		"occupied_1", "occupied_2":
			_draw_occupied()
		"bench_screen":
			_draw_bench_screen()
		"tree_lights":
			_draw_tree_lights()
		"dart_board":
			_draw_dart_board()
		"vending_machine":
			_draw_vending()
		"chair_rack":
			_draw_chair_rack()
		"cage":
			_draw_cage()
		"lamp_chain":
			_draw_lamp_chain()
		"radio":
			_draw_radio()
		"floor_fan":
			_draw_floor_fan()


func _outing_escape() -> Dictionary:
	if (
		Outings.is_open
		and Outings.game == "escape"
		and Outings.phase != "intro"
		and not Outings.g.is_empty()
	):
		return Outings.g
	return {}


func _draw_neon() -> void:
	var info: Array = NEON[kind]
	var size: Vector2 = info[0]
	var col: Color = info[1]
	var pulse := 0.10 + 0.06 * sin(_time * 2.4 + float(seed_offset))
	if kind == "neon_bowl":
		_draw_alley_sign(size, col)
	if _h(int(_time * 9.0)) % 31 == 0:
		_r(0, 0, size.x, size.y, Color(0.05, 0.04, 0.09, 0.55))  # a flicker
		return
	_r(0, 0, size.x, size.y, Color(col, pulse))
	_r(-2, size.y, size.x + 4, 1, Color(col, pulse * 1.6))


# R11: the big sign over the lanes names tonight's alley (the baked art says BOWL): a dark panel and the short name in neon
func _draw_alley_sign(size: Vector2, col: Color) -> void:
	var key := "%d:%d" % [Outings.count, int(Outings.league.night)]
	if key != _sign_key:
		_sign_key = key
		# the same seeded draw the game uses
		_sign_text = str(BowlVariety.alley(str(Outings._game_options("bowling").alley)).short)
	_r(1, 1, size.x - 2.0, size.y - 2.0, Color("120a1c"))
	_r(1, 1, size.x - 2.0, 1, Color(col, 0.7))
	_r(1, size.y - 2.0, size.x - 2.0, 1, Color(col, 0.7))
	var words: PackedStringArray = _sign_text.split(" ")
	var lines: Array = [_sign_text] if PixelFont.width(_sign_text, 1) <= size.x - 4.0 else [words[0], " ".join(words.slice(1))]
	var y := floorf((size.y - 6.0 * float(lines.size()) + 1.0) * 0.5)
	for ln in lines:
		var w := PixelFont.width(str(ln), 1)
		PixelFont.draw(self, str(ln), Vector2(floorf((size.x - w) * 0.5), y), col.lightened(0.35), 1)
		y += 6.0


func _bowl_game() -> Dictionary:
	if (
		Outings.is_open
		and Outings.game == "bowling"
		and Outings.phase == "play"
		and Outings.g.has("up")
	):
		return Outings.g
	return {}


func _lane_x(lane: int, y: float) -> float:
	return lerpf(
		float(Outings.LANE_FAR[lane]),
		float(Outings.LANE_NEAR[lane]),
		clampf((y - 28.0) / 55.0, 0.0, 1.0)
	)


func _lane_w(y: float) -> float:
	return lerpf(22.0, 52.0, clampf((y - 28.0) / 55.0, 0.0, 1.0))


# ---- cornhole and the cookout in the warehouse (R21). Set x / y numbers: board A (yours, blue) and board B (the crew's, red) on the floor,
# 24 px long and 12 deep (half a pixel an inch), the hole 19.5 px from the near end; the bags are 3 px.
const CORN_BOARD := {"a": 1140.0, "b": 1236.0, "len": 24.0, "dep": 12.0, "y": 115.0, "hole": 19.5}
const BAG_YOU := Color("5aa0e8")
const BAG_CREW := Color("e0463c")


func _corn_game() -> RefCounted:
	if Outings.is_open and Outings.game == "cornhole" and Outings.phase != "intro" and Outings.g.has("game"):
		return Outings.g.game
	return null


func _grill_game() -> RefCounted:
	if Outings.is_open and Outings.game == "grill" and Outings.phase != "intro" and Outings.g.has("game"):
		return Outings.g.game
	return null


# a set-x / y point in this node's own coordinates
func _wx(set_x: float, y: float) -> Vector2:
	return to_local(Vector2(float(World.DATA.SCENES[_room].x0) + set_x, y))


# where a bag lands, in set pixels: yours go to board B (px runs to the right), the crew's to board A (to the left)
func corn_xy(who: String, px: float, py: float) -> Vector2:
	if who == "you":
		return Vector2(float(CORN_BOARD.b) + px * 0.5, float(CORN_BOARD.y) + py * 0.5)
	return Vector2(float(CORN_BOARD.a) + float(CORN_BOARD.len) - px * 0.5, float(CORN_BOARD.y) - py * 0.5)


func _draw_cornhole_board(side: String) -> void:
	var a := side == "a"
	var left := float(CORN_BOARD[side])
	var blen := float(CORN_BOARD.len)
	var dep := float(CORN_BOARD.dep)
	var top := float(CORN_BOARD.y) - dep * 0.5
	var col := Color("3d78c4") if a else Color("c0392b")
	var dark := col.darkened(0.45)
	draw_rect(Rect2(_wx(left + 1.0, top + dep + 1.0), Vector2(blen, 3.0)), Color(0, 0, 0, 0.3))  # the shadow
	draw_rect(Rect2(_wx(left + 1.0, top + dep), Vector2(2.0, 3.0)), Color("3a2a1c"))  # legs
	draw_rect(Rect2(_wx(left + blen - 3.0, top + dep), Vector2(2.0, 3.0)), Color("3a2a1c"))
	draw_rect(Rect2(_wx(left, top + dep - 1.0), Vector2(blen, 2.0)), dark)  # the front edge
	draw_rect(Rect2(_wx(left, top), Vector2(blen, dep - 1.0)), col)  # the painted top
	draw_rect(Rect2(_wx(left, top), Vector2(blen, 1.0)), col.lightened(0.3))
	var near := left + blen - 3.0 if a else left
	draw_rect(Rect2(_wx(near, top), Vector2(3.0, dep - 1.0)), Color("f4f1e8"))  # a white band at the near end
	var far := left if a else left + blen - 2.0
	draw_rect(Rect2(_wx(far, top), Vector2(2.0, dep - 1.0)), dark)  # the raised far end
	var hx := left + blen - float(CORN_BOARD.hole) if a else left + float(CORN_BOARD.hole)
	draw_circle(_wx(hx, float(CORN_BOARD.y) - 0.5), 3.4, dark)
	draw_circle(_wx(hx, float(CORN_BOARD.y) - 0.5), 2.7, Color("120d14"))
	var game := _corn_game()
	if game == null:
		return
	for bag in game.landed:
		if (str(bag.who) == "you") == a or str(bag.kind) == "hole":
			continue
		_draw_bag(corn_xy(str(bag.who), float(bag.px), float(bag.py)), str(bag.who) == "you", 0.0)


func _draw_bag(at: Vector2, mine: bool, lift: float) -> void:
	var col := BAG_YOU if mine else BAG_CREW
	var p := _wx(at.x - 1.5, at.y - 1.5 - lift)
	draw_rect(Rect2(p + Vector2(0, 1), Vector2(3, 2)), col.darkened(0.4))
	draw_rect(Rect2(p, Vector2(3, 2)), col)
	draw_rect(Rect2(p, Vector2(3, 1)), col.lightened(0.3))


# board A also draws the bag in the air (one arc from the thrower's hand to where it comes down)
func _draw_cornhole_a() -> void:
	_draw_cornhole_board("a")
	var game := _corn_game()
	if game == null or game.flying.is_empty():
		return
	var mine := str(game.flying.who) == "you"
	var from := Vector2(Outings.CORN_A + 8.0, 92.0) if mine else Vector2(Outings.CORN_B - 8.0, 92.0)
	var land := corn_xy(str(game.flying.who), float(game.flying.px), float(game.flying.py))
	var t := clampf(float(game.flying.t), 0.0, 1.0)
	var at := from.lerp(land, t)
	var up := 4.0 * 30.0 * t * (1.0 - t)
	at.y += 0.0
	draw_rect(Rect2(_wx(at.x - 1.5, land.y + 1.0), Vector2(3, 1)), Color(0, 0, 0, 0.3))
	_draw_bag(Vector2(at.x, at.y), mine, up)


func _draw_cornhole_tray() -> void:
	var x := 1100.0
	draw_rect(Rect2(_wx(x, 112.0), Vector2(14, 7)), Color("6b4a2a"))
	draw_rect(Rect2(_wx(x, 112.0), Vector2(14, 1)), Color("8a6338"))
	draw_rect(Rect2(_wx(x + 1.0, 109.0), Vector2(3, 3)), BAG_YOU)
	draw_rect(Rect2(_wx(x + 5.0, 109.0), Vector2(3, 3)), BAG_YOU.darkened(0.2))
	draw_rect(Rect2(_wx(x + 9.0, 109.0), Vector2(3, 3)), BAG_CREW)
	draw_rect(Rect2(_wx(x + 3.0, 107.0), Vector2(3, 3)), BAG_CREW.darkened(0.2))


# the grill: a little smoke always, more while patties cook, flames in a flare-up, plates for what was served, and a bubble with
# the order over each coworker in the queue (the grate itself is in the HUD, the sprite is too small)
func _draw_grill() -> void:
	var game := _grill_game()
	var busy_grill: bool = game != null and game.cooking()
	var puffs := 4 if busy_grill else 2
	for i in puffs:
		var ph := fmod(_time * (0.55 if busy_grill else 0.3) + float(i) / float(puffs), 1.0)
		var r := 1.2 + ph * 2.6
		draw_circle(Vector2(15.0 + sin(_time * 1.7 + float(i) * 2.1) * 3.0 + ph * 3.0, -1.0 - ph * 24.0), r, Color(0.75, 0.75, 0.78, 0.42 * (1.0 - ph)))
	if game == null:
		return
	for slot in game.flare_slots():
		var fx := 5.0 + 7.0 * float(slot)
		var flick := 4.0 + 3.0 * sin(_time * 22.0 + float(slot) * 1.7)
		draw_colored_polygon(PackedVector2Array([Vector2(fx, 4.0), Vector2(fx + 3.0, 4.0 - flick - 4.0), Vector2(fx + 6.0, 4.0)]), Color("f08a30"))
		draw_colored_polygon(PackedVector2Array([Vector2(fx + 1.5, 4.0), Vector2(fx + 3.0, 4.0 - flick), Vector2(fx + 4.5, 4.0)]), Color("ffe36b"))
	for i in mini(game.served, 6):  # the plates
		draw_rect(Rect2(36.0 + float(i % 3) * 5.0, 33.0 - floorf(float(i) / 3.0) * 3.0, 4.0, 2.0), Color("f4f1e8"))
		draw_rect(Rect2(37.0 + float(i % 3) * 5.0, 32.0 - floorf(float(i) / 3.0) * 3.0, 2.0, 1.0), Color("8f5233"))
	var scene := get_tree().current_scene
	if scene == null or not Outings.room_mode() or get_viewport_rect().size.y < 170.0:  # wide (128 px) has no room over the heads: the HUD box lists the orders
		return
	for t in game.open_tickets():
		var node := scene.get_node_or_null("Actors/" + str(t.who))
		if node == null:
			continue
		var ls: Array = game.lines(t)
		var w := 4.0
		for line in ls:
			w = maxf(w, float(str(line).length()) * 4.0 + 3.0)
		var h := 7.0 * float(ls.size()) + 3.0
		var at := to_local(node.global_position + Vector2(0.0, -62.0 - 9.0 * float(int(t.id) % 2)))
		var rect := Rect2(at.x - w * 0.5, at.y - h, w, h)
		var frac := clampf(float(t.left) / Outings.GrillGame.PATIENCE, 0.0, 1.0)
		draw_rect(Rect2(rect.position - Vector2.ONE, rect.size + Vector2(2, 2)), Color("17121f"))
		draw_rect(rect, Color("f4f1e8"))
		draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x * (1.0 if game.cozy else frac), 1.0), Color("2f9e4f") if frac > 0.4 or game.cozy else Color("c0392b"))
		draw_rect(Rect2(at.x - 1.0, rect.end.y + 1.0, 2.0, 2.0), Color("17121f"))
		for k in ls.size():
			PixelFont.draw(self, str(ls[k]), Vector2(rect.position.x + 2.0, rect.position.y + 1.0 + 7.0 * float(k)), Color("17121f"), 1)


func _draw_bowl_lane() -> void:
	var game := _bowl_game()
	for lane in 2:
		var px := float(Outings.LANE_FAR[lane])
		var idx := 0
		for row in 4:
			for k in row + 1:
				var x := px + floorf((float(k) - float(row) * 0.5) * 5.0)
				var y := 36.0 - float(row) * 3.0
				var standing := true
				var falling := false
				if not game.is_empty():
					standing = bool(game.up[lane][idx])
					falling = game.fall.has("%d_%d" % [lane, idx])
				if standing:
					_r(x - 1.0, y, 2, 3, Color("f4f2ea"))
					_r(x - 1.0, y, 2, 1, Color("e04e4e"))
				elif falling:
					_r(x - 2.0 + float(idx % 3) - 1.0, y + 1.0, 4, 1, Color("f4f2ea"))
				idx += 1
	if game.is_empty():
		return
	if str(game.stage) == "roll":
		_draw_ball(0, float(game.ball), float(game.marker))
	if str(game.opp) != "" and int(game.opp_phase) == 0:
		_draw_ball(1, float(game.opp_ball), float(game.opp_off))


func _draw_ball(lane: int, t: float, aim: float) -> void:
	var y := lerpf(82.0, 38.0, t)
	var off := clampf((aim - 0.5) * 2.6, -1.3, 1.3)
	var x := _lane_x(lane, y) + off * _lane_w(y) * 0.5
	var r := lerpf(3.0, 1.5, t)
	_r(x - r, y - r, r * 2.0, r * 2.0, Color("2a2a8a") if lane == 0 else Color("8a2a5a"))
	_r(x - r, y - r, 1, 1, Color("ffffff"))


func _draw_bowl_score() -> void:
	_r(0, 0, 60, 14, Color("0a1a12"))
	var game := _bowl_game()
	var green := Color("5fe08a")
	if game.is_empty():
		PixelFont.draw(self, "BOWL!", Vector2(11, 2), green, 2)
		return
	if str(game.stage) == "pause" and str(game.msg) != "" and int(_time * 4.0) % 2 == 0:
		PixelFont.draw(self, str(game.msg).substr(0, 7), Vector2(2, 2), Color("ffe36b"), 2)
		return
	# up to five names on two lines: 14 characters of two letters and two digits fit the 60 px screen
	var t: Dictionary = game.totals
	var cells := ["YO%02d" % int(t["You"])]
	for who in Outings.bowlers():
		cells.append("%s%02d" % [str(Outings.GUESTS[who].code), int(t.get(who, 0))])
	PixelFont.draw(self, " ".join(cells.slice(0, 3)), Vector2(2, 1), green, 1)
	if cells.size() > 3:
		PixelFont.draw(self, " ".join(cells.slice(3, 6)), Vector2(2, 8), green, 1)


func _escape_game() -> Dictionary:
	if (
		Outings.is_open
		and Outings.game == "escape"
		and Outings.phase == "play"
		and Outings.g.has("clues")
	):
		return Outings.g
	return {}


# the clue a zone shows: Outings.g.clues[index] (the shape of each recipe is in Outings.make_clue)
func _clue(index: int) -> Dictionary:
	var game := _escape_game()
	if game.is_empty():
		return {}
	if game.has("spots"):
		index = (game.spots as Array).find(index)  # the zone index to the clue that sits there
	if index < 0 or index >= game.clues.size():
		return {}
	return game.clues[index]


func _draw_clue_board() -> void:
	var clue := _clue(0)
	var text := "2+2=?" if clue.is_empty() else str(clue.show)
	var lines := text.split("|")
	var y := 8.0 if lines.size() == 1 else 5.0
	for line in lines:
		var scale := 2 if PixelFont.width(line, 2) <= 44 else 1
		var yy := y + (3.0 if scale == 1 and lines.size() == 1 else 0.0)
		PixelFont.draw(self, line, Vector2(8, yy), Color("e8e8e0"), scale)
		y += 12.0 if scale == 2 else 8.0


func _draw_clue_clock() -> void:
	var clue := _clue(1)
	var hour := 10 if clue.is_empty() else int(clue.args.hour)
	var c := Vector2(9, 9)
	var a := float(hour % 12) / 12.0 * TAU - PI * 0.5
	draw_line(c, c + Vector2(cos(a), sin(a)) * 4.0, Color("17121f"), 1.0)
	draw_line(c, c + Vector2(0, -6), Color("17121f"), 1.0)
	_r(c.x - 1.0, c.y - 1.0, 2, 2, Color("c0392b"))
	if not clue.is_empty() and str(clue.recipe) == "double":
		PixelFont.draw(self, "X2", Vector2(5, 14), Color("17121f"), 1)


func _draw_clue_painting() -> void:
	var clue := _clue(2)
	var text := "?" if clue.is_empty() else str(clue.show)
	var w := maxi(12, PixelFont.width(text, 1) + 4)
	_r(13 - w / 2, 33, w, 7, Color("c99a3c"))
	_r(13 - w / 2, 33, w, 1, Color("e8c45a"))
	PixelFont.draw(self, text, Vector2(15 - w / 2, 34), Color("17121f"), 1)


# the bookshelf (a clue only on a 4 digit game): a book label, or bookmark ribbons
func _draw_clue_shelf() -> void:
	var clue := _clue(3)
	if clue.is_empty():
		return
	if str(clue.recipe) == "ribbons":
		for i in int(clue.args.n):
			_r(3 + i * 2, 30, 1, 5, Color("b8292f") if i % 2 == 0 else Color("e8c45a"))
		return
	var w := PixelFont.width(str(clue.show), 1) + 4
	_r(14 - w / 2, 28, w, 7, Color("e8dcb0"))
	_r(14 - w / 2, 28, w, 1, Color("c9b878"))
	PixelFont.draw(self, str(clue.show), Vector2(16 - w / 2, 29), Color("17121f"), 1)


func _draw_sports() -> void:
	var w := 42.0
	var h := 22.0
	var replay := fmod(_time + float(seed_offset) * 4.0, 11.0) > 9.0
	_r(0, 0, w, h, Color("2a7a3a") if not replay else Color("3a9a4a"))
	for i in 6:
		_r(float(i) * 8.0 + 2.0, 0, 1, h, Color(1, 1, 1, 0.18))
	_r(0, h * 0.5, w, 1, Color(1, 1, 1, 0.18))
	for i in 8:
		var phase := _time * (0.8 + float(i % 3) * 0.35) + float(i) * 1.9 + float(seed_offset) * 2.3
		var px := fposmod(float(i) * 11.0 + sin(phase) * 7.0, w - 2.0)
		var py := 4.0 + float((i * 7) % 15) + cos(phase * 1.3) * 2.0
		_r(px, py, 2, 2, Color("e8e8f4") if i < 4 else Color("e04e4e"))
	var bx := fposmod(_time * 9.0 + float(seed_offset) * 13.0, w - 2.0)
	_r(bx, 8.0 + sin(_time * 3.0) * 4.0, 2, 2, Color("f2f2ea"))
	_r(0, 0, w, 5, Color(0.05, 0.05, 0.1, 0.8))
	PixelFont.draw(
		self, "3-2 Q4" if seed_offset == 0 else "7-7 2ND", Vector2(2, 0), Color("ffe36b"), 1
	)
	if replay:
		PixelFont.draw(self, "REPLAY", Vector2(w - 25.0, h - 6.0), Color("ffffff"), 1)


func _draw_lyrics() -> void:
	var w := 88.0
	var h := 34.0
	_r(0, 0, w, h, Color("161a44"))
	for i in 6:
		_r(0, float(i) * 6.0, w, 3.0, Color(0.35, 0.2, 0.55, 0.12))
	var lines: Array = LYRICS
	var title := "TOTALLY LEGAL HIT"
	var line_secs := 4.5
	var idx := 0
	var frac := 0.0
	var game := _karaoke_game()
	if game.is_empty():
		idx = int(_time / line_secs) % lines.size()
		frac = fmod(_time, line_secs) / line_secs
	else:
		# the lyrics follow the song: each line gets an equal share of its length
		lines = game.song.lines
		title = str(game.song.title)
		line_secs = maxf(1.0, (float(game.span) - 1.5) / float(lines.size()))
		var pos := maxf(0.0, float(game.t) - 1.5) / line_secs
		idx = mini(int(pos), lines.size() - 1)
		frac = clampf(pos - float(idx), 0.0, 1.0)
	var line: String = lines[idx]
	var words := line.split(" ")
	var total := PixelFont.width(line, 1)
	var x := floorf((w - float(total)) * 0.5)
	var y := 15.0
	var shown := frac * float(line.length())
	var pos := 0
	var ball_x := x
	for word in words:
		for ch in word:
			var done := float(pos) < shown
			PixelFont.draw(
				self, str(ch), Vector2(x, y), Color("ffe36b") if done else Color("e8e8f4"), 1
			)
			if done:
				ball_x = x
			x += 4.0
			pos += 1
		x += 4.0
		pos += 1
	var next: String = lines[(idx + 1) % lines.size()]
	PixelFont.draw(
		self,
		next.substr(0, 21),
		Vector2(floorf((w - float(PixelFont.width(next.substr(0, 21), 1))) * 0.5), 25.0),
		Color("7a82b8"),
		1
	)
	PixelFont.draw(self, title.substr(0, 21), Vector2(4, 3), Color("e04ecb"), 1)
	_r(ball_x + 1.0, 9.0 - absf(sin(_time * 7.0)) * 4.0, 3.0, 3.0, Color("ffffff"))


func _karaoke_game() -> Dictionary:
	if (
		Outings.is_open
		and Outings.game == "karaoke"
		and Outings.phase == "play"
		and Outings.g.has("song")
	):
		return Outings.g
	return {}


func _draw_disco() -> void:
	for i in 18:
		var spd := 6.0 + float(i % 4) * 3.0
		var x := fposmod(float(i) * 37.0 + _time * spd, 320.0) - 145.0
		var y := 6.0 + float((i * 29) % 80)
		var cols := [Color("e04ecb"), Color("3ee0e0"), Color("f2c94c"), Color("ffffff")]
		_r(x, y, 3, 3, Color(cols[i % 4], 0.22))
	if _h(int(_time * 10.0)) % 3 == 0:
		_r(-3, 18, 2, 2, Color(1, 1, 1, 0.9))
		_r(8, 24, 2, 2, Color(1, 1, 1, 0.9))


func _draw_keypad() -> void:
	var game := _outing_escape()
	var digits := [0, 0, 0]
	if not game.is_empty():
		digits = game.cur
	var pitch := 5.0 if digits.size() <= 3 else 4.0
	for i in digits.size():
		PixelFont.draw(
			self,
			str(int(digits[i])),
			Vector2(3.0 + float(i) * pitch + (1.0 if digits.size() <= 3 else 0.0), 4.0),
			Color("4cff7a"),
			1
		)
	var solved := (
		Outings.is_open
		and Outings.game == "escape"
		and Outings.phase == "result"
		and Outings.stars > 0
	)
	var lit := solved or (int(_time * 2.0) % 2 == 0 and not game.is_empty())
	_r(18, 12, 2, 2, Color("4cff7a") if solved else (Color("ff3b30") if lit else Color("5a1812")))


func _draw_timer() -> void:
	var game := _outing_escape()
	var left := 120.0
	if not game.is_empty():
		left = maxf(0.0, float(game.time))
	var text := "%02d:%02d" % [int(left) / 60, int(left) % 60]
	var col := Color("ff3b30") if left > 20.0 or int(_time * 3.0) % 2 == 0 else Color("5a1812")
	PixelFont.draw(self, text, Vector2(4.0, 4.0), col, 2)


func _draw_redlight() -> void:
	var a := 0.20 + 0.28 * (0.5 + 0.5 * sin(_time * 4.0))
	_r(-6, -2, 24, 14, Color(1, 0.1, 0.05, a * 0.35))
	_r(2, 1, 8, 6, Color(1, 0.25, 0.2, a))


# the sales bell, hung high on the wall: John rings it after a deal, and a foam dart can ring it too
var _bell_t := 0.0
var _bell_msg := ""


func ring(cause := "vic") -> void:
	if _bell_t > 1.2 and cause == "dart":
		return
	_bell_t = 2.6
	_bell_msg = "DING!"
	Sfx.play_near("bell", self)
	if cause == "dart":
		Hints.toast("DING! A DART HIT THE SALES BELL.", 2.5)
		if int(Game.vars.get("bell_day", -1)) != World.day:
			Game.vars["bell_day"] = World.day
			Social.change("John", 1)
	else:
		Hints.toast("DING DING! " + str(Sales.last_deal), 4.0)


func hit_test(pos: Vector2) -> bool:
	return Rect2(global_position + Vector2(-9, -3), Vector2(18, 20)).has_point(pos)


func _draw_bell() -> void:
	var amp := 0.0
	if _bell_t > 0.0:
		amp = 5.0 * (_bell_t / 2.6)
	var sway := sin(_time * 22.0) * amp
	var brass := Color("d8b84a")
	var hi := Color("f2d878")
	var sh := Color("a8862a")
	var ink := Color("17121f")
	_r(-7, -5, 14, 3, ink)  # the bracket
	_r(-6, -4, 12, 1, sh)
	_r(-1, -2, 2, 3, ink)  # the chain
	var rows := [
		[2, 3],
		[3, 3],
		[4, 4],
		[5, 4],
		[6, 4],
		[7, 5],
		[8, 5],
		[9, 5],
		[10, 6],
		[11, 6],
		[12, 7],
		[13, 7]
	]
	for r in rows:
		var y: float = r[0]
		var half: float = r[1]
		var off := sway * (y / 13.0)
		_r(-half - 1 + off, y, half * 2.0 + 2.0, 1, ink)
		_r(-half + off, y, half * 2.0, 1, brass)
		_r(-half + 1 + off, y, 1.0, 1, hi)
		_r(half - 2 + off, y, 1.0, 1, sh)
	_r(-8 + sway, 14, 16, 1, ink)
	_r(-1 + sway * 1.4, 15, 3, 3, ink)  # the clapper
	_r(0 + sway * 1.4, 15, 1, 2, brass)
	if _bell_t > 0.0:
		for i in 3:
			var k := float(i) * 3.0
			_r(-14 - k, 4 + k * 0.5, 3, 1, Color(1, 0.95, 0.6, minf(1.0, _bell_t)))
			_r(11 + k, 4 + k * 0.5, 3, 1, Color(1, 0.95, 0.6, minf(1.0, _bell_t)))
		if _bell_t > 1.4:
			var w := PixelFont.width(_bell_msg)
			PixelFont.draw(self, _bell_msg, Vector2(-w * 0.5, -14.0), Color("fff2a0"), 1)


# the rubber duck on your monitor: it squeaks, stares blankly or listens
var _duck_t := 0.0
var _duck_msg := ""
var _duck_count := 0
var _duck_base := 0.0


func _duck_press() -> void:
	_duck_count += 1
	Career.add("duck_squeaks")
	_duck_t = 1.6
	var roll := randf()
	if _duck_count % 10 == 0:
		_duck_msg = "!"
		Hints.toast("THE DUCK HAS HEARD ENOUGH FOR TODAY.", 3.0)
	elif roll < 0.55:
		_duck_msg = "SQUEAK!"
	elif roll < 0.85:
		_duck_msg = "..."
		Hints.toast("THE DUCK STARES AT YOU BLANKLY.", 3.0)
	else:
		_duck_msg = "?"
		Hints.toast("YOU EXPLAIN THE PROBLEM TO THE DUCK. IT SAYS NOTHING. IT HELPS ANYWAY.", 4.0)


func _duck_tick(delta: float) -> void:
	var sprite := get_parent()
	if not (sprite is Sprite2D):
		return
	# R7: the duck you picked (gold, pirate) and the desk toy beside it
	if _duck_tex == null:
		_duck_tex = sprite.texture
	var skin := str(Career.pick_of("duck").get("id", "duck_classic"))
	if skin != _duck_skin:
		_duck_skin = skin
		sprite.texture = DUCK_SKINS.get(skin, _duck_tex)
	var toy := str(Career.pick_of("desk_toy").get("id", "toy_none"))
	if toy != _duck_toy or toy == "toy_pendulum":
		_duck_toy = toy
		queue_redraw()
	if _duck_base == 0.0:
		_duck_base = sprite.offset.y
	if _duck_t > 0.0:
		_duck_t = maxf(0.0, _duck_t - delta)
		var hop := 0.0
		if _duck_msg == "SQUEAK!" and _duck_t > 1.15:
			hop = absf(sin((1.6 - _duck_t) * 16.0)) * 3.0
		sprite.offset.y = _duck_base - hop
		queue_redraw()
	elif sprite.offset.y != _duck_base:
		sprite.offset.y = _duck_base


# the desk toys on the desk phone next to the duck (this node sits at the duck's top-left corner, the phone's top is at y 20)
func _draw_toy() -> void:
	var dark := Color("17121f")
	if _duck_toy == "toy_stress_ball":
		draw_circle(Vector2(25, 15), 4.5, dark)
		draw_circle(Vector2(25, 15), 3.5, Color("e0463c"))
		_r(23, 13, 2, 1, Color("f27a6c"))
	elif _duck_toy == "toy_pendulum":
		_r(19, 9, 13, 1, dark)
		_r(19, 9, 1, 11, dark)
		_r(31, 9, 1, 11, dark)
		var swing := sin(_time * 3.2)
		var a := clampf(swing, -1.0, 1.0) * 0.75
		for i in 4:
			var anchor := Vector2(22.0 + 2.5 * float(i), 10.0)
			var ang := 0.0
			if i == 0 and swing < 0.0:
				ang = a
			elif i == 3 and swing > 0.0:
				ang = a
			var ball := anchor + Vector2(sin(ang), cos(ang)) * 6.0
			draw_line(anchor, ball, Color("c8ccd8"), 1.0)
			draw_circle(ball, 1.7, dark)
			draw_circle(ball, 1.0, Color("e8e8ee"))


func _draw_duck() -> void:
	_draw_toy()
	if _duck_t <= 0.0:
		return
	var w := PixelFont.width(_duck_msg)
	var x := -float(w) * 0.5 + 6.0
	_r(x - 2.0, -11.0, w + 4.0, 9.0, Color(1, 1, 1, 0.92))
	_r(x - 1.0, -12.0, w + 2.0, 1.0, Color(1, 1, 1, 0.92))
	PixelFont.draw(self, _duck_msg, Vector2(x, -9.0), Color("17121f"), 1)


func _draw_session_sign() -> void:
	var lines: Array = Expo.sign_lines(int(str(name).right(1)))
	var y := 0.0
	for line in lines:
		PixelFont.draw(self, str(line), Vector2(2.0, y), Color("14566e"), 1)
		y += 6.0


# the screen of a breakout room (SALON A to D) shows the session of that door: round and time, the title, the speaker
func _draw_session_screen() -> void:
	var letter := _room.right(1)
	var st := _screen_style(letter)
	var info: Dictionary = Expo.room_info("abcd".find(letter), int(st.chars))
	if info.is_empty():
		return
	PixelFont.draw(self, "ROUND %d  %s" % [int(info.round), str(info.time)], Vector2(2, 1), st.head, 1)
	var lines: Array = info.title
	var y := 9.0
	for i in mini(lines.size(), int(st.lines)):
		PixelFont.draw(self, str(lines[i]), Vector2(2, y), st.title, 1)
		y += 6.0
	var who: Array = info.speaker
	PixelFont.draw(self, str(who[0]), Vector2(2, float(st.h) - 12.0), st.who, 1)
	PixelFont.draw(self, str(who[1]), Vector2(2, float(st.h) - 6.0), st.head, 1)


# text area, letters per line, title lines and colours of each room's screen (blue wall screen, white pull-down, gold display, whiteboard)
func _screen_style(letter: String) -> Dictionary:
	match letter:
		"b":
			return {"h": 44, "chars": 24, "lines": 3, "head": Color("6a6f7a"), "title": Color("14566e"), "who": Color("8a2434")}
		"c":
			return {"h": 40, "chars": 23, "lines": 3, "head": Color("8a93a8"), "title": Color("f2d878"), "who": Color("ffffff")}
		"d":
			return {"h": 36, "chars": 25, "lines": 2, "head": Color("6a6f7a"), "title": Color("2a4fb8"), "who": Color("c03030")}
	return {"h": 40, "chars": 22, "lines": 3, "head": Color("bfe4f8"), "title": Color("ffffff"), "who": Color("f2c94c")}


func _draw_lamp() -> void:
	draw_circle(Vector2(6, 4), 26.0, Color(1.0, 0.85, 0.4, 0.07 + 0.015 * sin(_time * 3.0)))
	draw_circle(Vector2(6, 4), 14.0, Color(1.0, 0.9, 0.5, 0.09))


# a dying light (the warehouse high bay, the old bathroom's bar light): mostly on, now and then a burst of flicker; dark
# with the room's lights (the node sits on the bulb)
func _draw_flicker_lamp() -> void:
	var slot := int(_time * 9.0)
	var burst := _h(floori(slot / 14.0)) % 3 == 0
	if (burst and _h(slot) % 3 == 0) or not World.lights_on(_room):
		return
	if _time < _kick_until and (_time < _kick_until - 0.6 or _h(slot) % 2 == 0):
		return  # the pull chain: dark, then a stutter back
	_r(-6, 0, 13, 2, Color("fff3c0"))
	draw_circle(Vector2(0, 10), 18.0, Color(1.0, 0.95, 0.7, 0.09))
	draw_circle(Vector2(0, 40), 46.0, Color(1.0, 0.95, 0.7, 0.04))


# the dot on a bath door plate in the kitchenette: red while somebody is in that bathroom, green when it is free
func _draw_occupied() -> void:
	var taken := World.bathroom_occupied("bathroom_" + kind.right(1))
	_r(0, 0, 2, 2, Color("e04040") if taken else Color("4ed06a"))


# the bench PC being imaged: a blue screen with a progress bar that fills over and over
func _draw_bench_screen() -> void:
	var p := fmod((_time - _img_t0) * 6.0, 100.0)
	_r(0, 0, 18, 12, Color("1f5fa8"))
	_r(1, 1, 16, 1, Color("8fc0f0"))
	PixelFont.draw(self, "IMG", Vector2(2, 3), Color("ffffff"), 1)
	_r(2, 8, 14, 2, Color("0d3a70"))
	_r(2, 8, floorf(14.0 * p / 100.0), 2, Color("4ec46a"))


# the long-forgotten string of lights on the old tree: a few bulbs still work, and they flicker
func _draw_tree_lights() -> void:
	var cols := [Color("e04e4e"), Color("f2c94c"), Color("4ec46a"), Color("4a8fe0")]
	if _time - _pop_t < 0.5 and _pop_i >= 0:  # a bulb just popped: a white spark
		var sp: Vector2 = TREE_BULBS[_pop_i]
		draw_circle(sp + Vector2(1, 1), 3.0 + 6.0 * (_time - _pop_t), Color(1.0, 1.0, 0.85, 0.6 - (_time - _pop_t)))
	if not tree_on:
		return
	for i in TREE_BULBS.size():
		if tree_popped.has(i) or i % 4 == 3 or (i % 3 == 1 and _h(int(_time * 4.0) + i) % 4 == 0):
			continue
		var b: Vector2 = TREE_BULBS[i]
		_r(b.x, b.y, 2, 2, cols[i % 4])
		draw_circle(b + Vector2(1, 1), 3.0, Color(cols[i % 4], 0.12))


func _h(n: int) -> int:
	return posmod(n * 1103515245 + 12345 + seed_offset * 7919, 2147483647) >> 8


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _draw_monitor() -> void:
	if panel > 0:
		_draw_panel()
		return
	if _time < _hit_until:
		for bx in 9:
			for by in 5:
				var v := 0.3 + 0.1 * float(_h(bx + by * 9 + int(_time * 25.0)) % 6)
				_r(3 + bx * 2, 6 + by * 2, 2, 2, Color(v, v, v + 0.04))
		return
	var net := Net.desk_state(desk)
	if net != "ok":
		_draw_monitor_error(net)
		return
	var ink := Color("9fb4c8")
	var step := int(_scroll)
	_r(3, 6, 19, 9, Color("dde8f0"))
	if _h(step / 7) % 3 == 0:
		for j in 5:
			var bh := 1 + _h(j + step / 2) % 7
			_r(4 + j * 3, 14 - bh, 2, bh, Color("7fa6d8") if j % 2 == 0 else ink)
	else:
		var last_len := 0
		for i in 4:
			last_len = 4 + _h(step + i) % 14
			_r(4, 7 + i * 2, last_len, 1, ink)
		if int(_time * 2.0) % 2 == 0:
			_r(5 + last_len, 13, 1, 1, Color("3c4660"))
	if (int(_time) + seed_offset * 3) % 11 == 0 and fmod(_time, 1.0) < 0.15:
		_r(3, 3, 19, 12, Color(1, 1, 1, 0.3))


# the screen areas under the art's blue title bar: the lone monitor, then the dual-desk panels A (4:3) and B (16:9)
const PANELS := [Rect2(3, 6, 19, 9), Rect2(3, 5, 14, 8), Rect2(2, 4, 20, 9)]


# one screen of a dual-monitor desk: A shows the PSA ticket list / mail, B the RMM chart and tree; they never show the
# same frame (the content cycle is offset per panel). Offline desks show the same icons as the single monitor.
func _draw_panel() -> void:
	var rc: Rect2 = PANELS[panel]
	var px := rc.position.x
	var py := rc.position.y
	var pw := rc.size.x
	var ph := rc.size.y
	if _time < _hit_until:
		for bx in int(pw / 2.0):
			for by in int(ph / 2.0):
				var v := 0.3 + 0.1 * float(_h(bx + by * 9 + int(_time * 25.0)) % 6)
				_r(px + bx * 2.0, py + by * 2.0, 2, 2, Color(v, v, v + 0.04))
		return
	var net := Net.desk_state(desk)
	if net != "ok":
		_draw_panel_error(rc, net)
		return
	var ink := Color("9fb4c8")
	var step := int(_scroll) + panel * 5
	_r(px, py, pw, ph, Color("dde8f0"))
	var chart := _h(step / 7) % 4 != 0 if panel == 2 else _h(step / 7) % 4 == 0
	if chart:
		for j in int(pw / 3.0):
			var bh := 1.0 + float(_h(j + step / 2) % int(ph - 2.0))
			_r(px + 1 + j * 3.0, py + ph - bh, 2, bh, Color("7fa6d8") if j % 2 == 0 else ink)
	else:
		var last_len := 0.0
		for i in int((ph - 1.0) / 2.0):
			last_len = 3.0 + float(_h(step + i) % int(pw - 6.0))
			if panel == 1:
				_r(px + 1, py + 1 + i * 2.0, 2, 1, Color("d99a4a") if _h(step + i * 3) % 3 == 0 else Color("7fa6d8"))
				_r(px + 4, py + 1 + i * 2.0, last_len, 1, ink)
			else:
				_r(px + 1 + float((i + step) % 3) * 2.0, py + 1 + i * 2.0, last_len - 2.0, 1, ink)
		if panel == 1 and int(_time * 2.0) % 2 == 0:
			_r(px + 5 + last_len, py + ph - 2, 1, 1, Color("3c4660"))
	if (int(_time) + seed_offset * 3) % 11 == 0 and fmod(_time, 1.0) < 0.15:
		_r(px, py - 2, pw, ph + 2, Color(1, 1, 1, 0.3))


func _draw_panel_error(rc: Rect2, state: String) -> void:
	_r(rc.position.x, rc.position.y, rc.size.x, rc.size.y, Color("1e2a44"))
	var cx := int(rc.position.x + rc.size.x / 2.0)
	var y0 := int(rc.position.y) + int((rc.size.y - 7.0) / 2.0)
	if state == "no_link":
		for i in 7:
			_r(cx - 3 + i, y0 + i, 1, 1, Color("e04646"))
			_r(cx + 3 - i, y0 + i, 1, 1, Color("e04646"))
	else:
		for row in 6:
			_r(cx - (row >> 1), y0 + row, 1 + row, 1, Color("f2c230"))
		_r(cx, y0 + 2, 1, 3, Color("1e2a44"))
		_r(cx, y0 + 6, 1, 1, Color("1e2a44"))


func _draw_tv() -> void:
	if _time > _next_channel:
		_next_channel = _time + 7.0
		_channel = (_channel + 1) % 4
		_static_until = _time + 0.4
	if _glance_col.a > 0.0 and int(_time * 2.0) % 2 == 0:  # something on the metrics board is red: the frame flashes
		_r(1, 1, 36, 1, _glance_col)
		_r(1, 19, 36, 1, _glance_col)
		_r(1, 1, 1, 19, _glance_col)
		_r(36, 1, 1, 19, _glance_col)
	var sx := 3.0
	var sy := 3.0
	var w := 32.0
	var h := 14.0
	if _time < _static_until:
		for bx in 16:
			for by in 7:
				var v := 0.35 + 0.1 * float(_h(bx + by * 16 + int(_time * 30.0)) % 6)
				_r(sx + bx * 2, sy + by * 2, 2, 2, Color(v, v, v + 0.03))
		return
	match _channel:
		0:
			_tv_sheet(sx, sy, w, h)
		1:
			_tv_bars(sx, sy, w, h)
		2:
			_tv_news(sx, sy, w, h)
		_:
			Dashboard.paint_micro(self, sx, sy, w, h)


# once a second: is a tile of the metrics board red? (the frame flashes; a toast says which, once a day)
func _tv_tick(delta: float) -> void:
	_glance_t -= delta
	if _glance_t > 0.0:
		return
	_glance_t = 1.0
	_glance_col = Dashboard.glance_color()
	if _glance_col.a > 0.0 and not Game.ui_open and World.time_scale > 0.0:
		var text: String = Dashboard.glance_toast()
		if text != "":
			Hints.toast(text, 3.5)


func _tv_sheet(sx: float, sy: float, w: float, h: float) -> void:
	var line := Color("c9d4dc")
	_r(sx, sy, w, h, Color("eef3f6"))
	_r(sx, sy, w, 3, Color("7fa6d8"))
	for r in 3:
		if r % 2 == 0:
			_r(sx, sy + 4 + r * 3, w, 2, line)
	_r(sx + 10, sy + 3, 1, h - 3, line)
	_r(sx + 21, sy + 3, 1, h - 3, line)
	var tick := int(_time * 1.5)
	var col := tick % 3
	var row := (tick / 3) % 3
	for c in 3:
		for r in 3:
			var n := 2 + _h(c * 3 + r) % 5
			_r(sx + 2 + c * 11, sy + 4 + r * 3, n, 1, Color("5a6a80"))
	_r(sx + col * 11, sy + 3 + row * 3, 11, 1, Color("2f6fd0"))
	_r(sx + col * 11, sy + 6 + row * 3, 11, 1, Color("2f6fd0"))


func _tv_bars(sx: float, sy: float, w: float, h: float) -> void:
	_r(sx, sy, w, h, Color("eef3f6"))
	var cols := [Color("7fa6d8"), Color("6eb45a"), Color("e6963c")]
	for i in 7:
		var bh := 2.0 + float(_h(i + int(_time * 1.2)) % 9)
		_r(sx + 2 + i * 4, sy + h - 1 - bh, 3, bh, cols[i % 3])
	_r(sx + 1, sy + h - 1, w - 2, 1, Color("3c4660"))


func _tv_news(sx: float, sy: float, w: float, h: float) -> void:
	_r(sx, sy, w, h, Color("34548c"))
	_r(sx + 14, sy + 3, 4, 4, Color("e6b48c"))
	_r(sx + 11, sy + 7, 10, 3, Color("3c3c46"))
	_r(sx + 2, sy + h - 6, 22, 3, Color("eef3f6"))
	_r(sx + 2, sy + h - 6, 5, 3, Color("d23c3c"))
	_r(sx, sy + h - 2, w, 2, Color("1e2846"))
	for i in 6:
		var x := fposmod(float(i * 6) - floorf(_time * 8.0), w)
		_r(sx + x, sy + h - 2, 3, 1, Color("c8d2e6"))
	if int(_time * 2.0) % 2 == 0:
		_r(sx + w - 4, sy + 2, 2, 2, Color("e03c3c"))


# ---- the network rack: live LEDs and cables drawn over the static rack art ----
func _draw_rack() -> void:
	var st := Net.status()
	_rack_leds(Net.layout, st)
	_rack_ups(Net.layout, st)
	_rack_labels()
	_rack_cables()
	_rack_beep()


# the tag beside each patch panel jack (R37): Dan's printed ones are white and crisp, hand-written tape is yellow, faded tape
# is pale with a ghost of a number, torn-off tape leaves nothing. Wrong tags look just like right ones: only the probe knows.
func _rack_labels() -> void:
	for jack in range(1, 9):
		var far := Net.far_pos("p%d" % jack)
		var tag: Dictionary = Net.label(jack)
		var x := far.x + 2.0
		var ink := Color("17121f")
		match str(tag.state):
			"dan", "fixed":
				_r(x, 3, 4, 7, Color("efebdd"))
			"ok", "wrong":
				_r(x, 3, 4, 7, Color("dcc46a"))
			"faded":
				_r(x, 3, 4, 7, Color("b9b08a"))
				ink = Color("a79f80")
			"blank":
				_r(x, 8, 4, 2, Color("8a8468"))  # a stub of tape left on the panel
				continue
		PixelFont.draw(self, str(int(tag.n)), Vector2(x + 0.5, 4), ink, 1)
		if tag.state == "fixed":
			_r(x + 1, 9, 2, 1, Color("5fbf4a"))


# ---- the tool case with the toner and probe (R37): E takes the toner out, E again puts it back ----
# E on this fx (interact.gd): the tool case takes / returns the toner, and the toner at a desk's monitor, phone or the copier
# clips its tone onto that desk's wall jack (probe the patch panel in the closet to find the cable). True = handled.
func toner_use(body: Node, reach_x: float) -> bool:
	if kind == "toner_kit":
		toner_press(body)
		return true
	if body.held == "toner" and desk >= 1 and kind in ["monitor", "desk_phone", "copier"]:
		Net.tone_at(desk)
		Hints.toast("TONE ON AT DESK %d. NOW PROBE THE PATCH PANEL IN THE CLOSET" % desk, 3.5)
		Sfx.play("ui_pick")
		body.reach(reach_x)
		return true
	return false


func toner_press(body: Node) -> void:
	body.reach(global_position.x)
	if body.held == "toner":
		body.give("")
		Net.tone_at(0)
		Hints.toast("TONER BACK IN THE CASE", 2.0)
	elif body.held == "":
		body.give("toner")
		Hints.toast("TONER AND PROBE. E AT A DESK CLIPS THE TONE ON, E AT A PATCH JACK PROBES", 4.0)
	else:
		Hints.toast("HANDS FULL", 1.8)


func _draw_toner_kit() -> void:
	var out: bool = Game.vars.get("held", "") == "toner"
	_r(0, 0, 12, 7, Color("17121f"))
	_r(1, 1, 10, 5, Color("e8a030"))
	_r(1, 1, 10, 1, Color("f6c85a"))
	_r(5, 0, 2, 2, Color("17121f"))  # the handle
	if out:
		_r(2, 3, 8, 2, Color("3a2a10"))  # the foam is empty
	else:
		_r(3, 3, 6, 2, Color("3c414d"))
		_r(9, 3, 1, 2, Color("9fe870") if int(_time * 2.0) % 2 == 0 else Color("2f5a28"))


# the probe found a cable: a green ring round its jack for a moment
func _rack_beep() -> void:
	if Net.beep_t <= 0.0 or int(Net.beep_t * 6.0) % 2 == 1:
		return
	var at := Net.far_pos("p%d" % Net.beep_jack)
	var ring := Color("9fe870")
	_r(at.x - 3, at.y - 4, 7, 1, ring)
	_r(at.x - 3, at.y + 3, 7, 1, ring)
	_r(at.x - 3, at.y - 3, 1, 6, ring)
	_r(at.x + 3, at.y - 3, 1, 6, ring)


func _led(pos: Array, color: Color) -> void:
	_r(pos[0], pos[1], 1, 1, color)


func _traffic(cable: String, st: Dictionary) -> bool:
	if cable.begins_with("p") and cable.length() == 2:
		return Net.desk_state(int(cable.substr(1))) == "ok"
	if cable == "up":
		return st.uplink
	return st.nas_ready


func _rack_leds(lay: Dictionary, st: Dictionary) -> void:
	var green := Color("5be07a")
	var amber := Color("ffb23c")
	var dim := Color("1d3a28")
	var blink := int(_time * 5.0) % 2 == 0
	for j in 12:
		var occ := Net.occupant("sw%d" % (j + 1))
		if occ != "" and st.sw:
			_led(lay.leds.sw_link[j], green if (st.sw_ready or blink) else dim)
			var tick: bool = (int(_time * 9.0) + j * 3) % 5 == 0
			if st.sw_ready and tick and _traffic(occ, st):
				_led(lay.leds.sw_act[j], amber)
	var rt: Dictionary = lay.leds.rt
	if st.rt:
		_led(rt.pwr, green if (st.rt_ready or blink) else amber)
		if Net.cables.wan.end == "wan":
			_led(rt.wan, green)
		if Net.cables.up.end.begins_with("sw"):
			_led(rt.lan, green)
		if st.rt_ready:
			_led(rt.net, green if st.internet else (amber if blink else dim))
	if st.nas:
		_led(lay.leds.nas_pwr, green if (st.nas_ready or blink) else amber)
		for b in 4:
			var lit: bool = (int(_time * 7.0) + b * 5) % 4 == 0 if st.nas_ready else blink
			if lit:
				_led(lay.leds.nas_bay[b], amber)
	if st.pdu:
		_led(lay.leds.pdu, green)
		for k in 6:
			if Net.occupant("pdu%d" % (k + 1)) != "":
				var pp: Vector2 = Net.port_pos["pdu%d" % (k + 1)]
				_r(pp.x - 1, pp.y - 3, 1, 1, green)


func _rack_ups(lay: Dictionary, st: Dictionary) -> void:
	var lcd: Array = lay.leds.ups_lcd
	if not Net.ups_on:
		_r(lcd[0] + 1, lcd[1] + 1, lcd[2] - 2, lcd[3] - 2, Color("0c110e"))
		return
	_led(lay.leds.ups_pwr, Color("5be07a"))
	_r(lcd[0] + 1, lcd[1] + 1, lcd[2] - 2, lcd[3] - 2, Color("324d3a"))
	var level := Net.battery
	var bars := int(ceilf(level * 5.0))
	var color := Color("5be07a")
	if level < 0.35:
		color = Color("ffb23c")
	if not st.wall and level < 0.2:
		color = Color("e04646")
	for i in 5:
		_r(lcd[0] + 3 + i * 4, lcd[1] + 3, 3, 6, color if i < bars else Color("1f2c23"))
	if not st.wall and int(_time * 3.0) % 2 == 0:
		_r(lcd[0] + lcd[2] - 5, lcd[1] + 1, 3, 1, Color("ffb23c"))  # running on battery


func _ctrl(id: String, a: Vector2, b: Vector2) -> Vector2:
	var mid := (a + b) * 0.5
	var fixed := {
		"wan": Vector2(mid.x, -12.0),
		"ups_in": Vector2(mid.x, 98.0),
		"sw_pwr": Vector2(74.0, mid.y),
		"rt_pwr": Vector2(78.0, mid.y),
		"nas_pwr": Vector2(82.0, mid.y),
		"pdu_in": Vector2(86.0, mid.y),
		"up": Vector2(mid.x - 6.0, mid.y - 4.0),
		"nas": Vector2(mid.x + 14.0, mid.y),
	}
	return fixed.get(id, mid + Vector2(0.0, 7.0))  # patch cables just sag a little


func _cable(a: Vector2, b: Vector2, ctrl: Vector2, color: Color) -> void:
	var steps := int(maxf(a.distance_to(b), 10.0) * 1.3)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var point := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t).round()
		draw_rect(Rect2(point, Vector2.ONE), color)


func _hand() -> Vector2:
	if _player == null:
		return Vector2(40, 90)
	var side := 1.0 if _player.facing == "right" else -1.0
	return to_local(_player.global_position + Vector2(8.0 * side, -34.0))


func _rack_cables() -> void:
	var heads := []
	for id in Net.cables:
		var c: Dictionary = Net.cables[id]
		var far := Net.far_pos(id)
		var color := Net.cable_color(id)
		var near: Vector2
		var ctrl: Vector2
		if c.end != "":
			near = Net.port_pos[c.end]
			ctrl = _ctrl(id, far, near)
			heads.append([near, color])
		else:
			var power: bool = c.kind in ["pwr", "feed", "inlet"]
			near = _hand() if Net.carrying == id else far + Vector2(6.0 if power else -6.0, 14.0)
			ctrl = (far + near) * 0.5 + Vector2(0.0, 8.0)
			heads.append([near, color])
		_cable(far, near, ctrl, color)
		_r(far.x - 1, far.y - 1, 3, 3, color)
	for h in heads:
		var at: Vector2 = h[0]
		_r(at.x - 1, at.y - 2, 3, 4, h[1])
		_r(at.x, at.y - 2, 1, 1, Color(1, 1, 1, 0.55))


func _draw_monitor_error(state: String) -> void:
	_r(3, 6, 19, 9, Color("1e2a44"))
	if state == "no_link":
		for i in 7:
			_r(9 + i, 7 + i, 1, 1, Color("e04646"))
			_r(15 - i, 7 + i, 1, 1, Color("e04646"))
	else:
		for row in 6:
			_r(12 - (row >> 1), 7 + row, 1 + row, 1, Color("f2c230"))
		_r(12, 9, 1, 3, Color("1e2a44"))
		_r(12, 13, 1, 1, Color("1e2a44"))


# a desk (or the copier) that has lost its network: the interaction says no
func offline() -> bool:
	if kind == "desk_phone":
		return Net.desk_state(desk) != "ok"
	if kind == "copier":
		return Net.desk_state(8) != "ok"
	return false


func _draw_switch() -> void:
	_r(-1, -1, 7, 10, Color("17121f"))
	_r(0, 0, 5, 8, Color("efebdd"))
	_r(1, 1, 3, 6, Color("c9c4b2"))
	if World.lights_on(_room):
		_r(2, 1, 1, 3, Color("8e939e"))
		_r(2, 0, 1, 1, Color("9fe870"))
	else:
		_r(2, 4, 1, 3, Color("8e939e"))


# ---- the dock door (R21c): the switch and the door itself are both E zones; pressing while it moves reverses it
func door_press() -> void:
	var door: Node = self if kind == "roll_door" else get_tree().get_first_node_in_group("roll_door")
	if door != null:
		door.door_toggle()


func door_toggle() -> void:
	goal = 0.0 if goal > 0.5 else 1.0
	World.door_open = goal
	Hints.toast("OPENING" if goal > 0.5 else "CLOSING", 1.8)
	Sfx.play_near("door_rattle", self)
	_door_snd = _time + 0.9


# the chair race rolls the door up for its start and down again after (the rattle plays at full volume, the door is far
# from the starting line); a door that was already open is left alone
func door_set(want: float, loud := false) -> void:
	goal = clampf(want, 0.0, 1.0)
	World.door_open = goal
	_door_loud = loud
	_door_rattle()
	_door_snd = _time + 0.9


func _door_rattle() -> void:
	if _door_loud:
		Sfx.play("door_rattle")
	else:
		Sfx.play_near("door_rattle", self)


func _door_ready() -> void:
	add_to_group("roll_door")
	goal = clampf(World.door_open, 0.0, 1.0)
	open = goal
	var actors: Node = owner.get_node_or_null("Actors") if owner != null else null
	if actors != null:
		for c in actors.get_children():
			if c is Sprite2D and str(c.name).begins_with("overhead_door"):
				_door = c
	door_apply()


# the slats rise into the housing: the sprite shows its lowest rows from the top edge, so the bottom bar climbs
func door_apply() -> void:
	if _door == null:
		return
	var rows := clampi(roundi((1.0 - open) * float(DOOR_TEX_H)), 0, DOOR_TEX_H)
	_door.region_enabled = true
	_door.region_rect = Rect2(0, DOOR_TEX_H - rows, _door.texture.get_width(), rows)
	_door.visible = rows > 0


# moves continuously, shows in 12 fps steps; a rattle while it rolls and a thunk when it stops
func _door_tick(delta: float) -> void:
	if is_equal_approx(open, goal):
		return
	open = move_toward(open, goal, delta / DOOR_SECS)
	if _time >= _door_snd:
		_door_rattle()
		_door_snd = _time + 0.9
	_door_acc += delta
	var done := is_equal_approx(open, goal)
	if done:
		open = goal
	if _door_acc >= STEP or done:
		_door_acc = 0.0
		door_apply()
	if done:
		if _door_loud:
			Sfx.play("door_thunk")
		else:
			Sfx.play_near("door_thunk", self)
		_door_loud = false


# the wall plate: an up button (open, green) and a down button (close, amber); a red light blinks while it rolls
func _draw_door_switch() -> void:
	var up: bool = goal > 0.5
	_r(-1, -1, 8, 14, Color("17121f"))
	_r(0, 0, 6, 12, Color("efebdd"))
	_r(1, 1, 4, 10, Color("c9c4b2"))
	_r(2, 2, 2, 3, Color("9fe870") if up else Color("5a6a58"))
	_r(2, 7, 2, 3, Color("6a5a3a") if up else Color("e8b040"))
	if not is_equal_approx(open, goal) and int(_time * 4.0) % 2 == 0:
		_r(2, 5, 2, 1, Color("e05050"))



func _draw_phone() -> void:
	if not busy and Net.desk_state(desk) != "ok":
		_r(5, 2, 5, 3, Color("4e5a4e"))  # no network: a dead, greyed LCD
		_r(6, 3, 3, 1, Color("2e382e"))
	var lcd_ink := Color("5b7a5e")
	if busy:
		var t := _time - _start
		_r(5, 2, 5, 3, Color("a9c3a4"))  # on a call: the LCD shows a running timer
		_r(6, 3, 3, 1, lcd_ink)
		_r(6, 4, 1.0 + float(int(t * 2.0) % 3), 1, lcd_ink)
	var jitter := 0.0
	if ringing:
		var on := int(_time * 8.0) % 2 == 0
		_r(5, 2, 5, 3, Color("e9f7de") if on else Color("a9c3a4"))
		_r(11, 8, 1, 1, Color("ff6a6a") if on else Color("7a2a2a"))
		if int(_time * 16.0) % 2 == 0:
			jitter = -1.0
		var wave := Color(1, 1, 1, 0.85)
		var k := float(int(_time * 5.0) % 3)
		_r(-2.0 - k, 3, 1, 3, wave)
		_r(15.0 + k, 3, 1, 3, wave)
		_r(-4.0 - k, 2, 1, 5, Color(1, 1, 1, 0.45))
		_r(17.0 + k, 2, 1, 5, Color(1, 1, 1, 0.45))
	if _handset != null:
		draw_texture(_handset, Vector2(0.0, jitter))


func _draw_fridge() -> void:
	if not busy:
		return
	var t := _time - _start
	var dur := float(DURATIONS["fridge"])
	var p := minf(clampf(t / 0.35, 0.0, 1.0), clampf((dur - t) / 0.35, 0.0, 1.0))
	if p <= 0.0:
		return
	var taken := t >= float(HAND_AT["fridge"])
	var ink := Color("17121f")
	var dw := int(7.0 * p)
	_r(-dw - 2, 23, dw + 1, 38, ink)  # the lower door, swung open to the left
	_r(-dw - 1, 24, dw, 36, Color("b8bcc4"))
	_r(-dw - 1, 24, 1, 36, Color("9498a2"))
	if dw >= 3:
		_r(-2, 30, 1, 10, Color("6a6f7a"))
	if p < 0.5:
		return
	_r(1, 23, 24, 37, ink)  # the opening
	_r(2, 24, 22, 35, Color("f2f4f8"))
	_r(2, 24, 22, 2, Color("fffbe0"))  # the light
	_r(23, 24, 1, 35, Color("d6d9df"))
	for y in [33, 42, 51]:
		_r(2, y, 22, 1, Color("b8bcc4"))
	if not (taken and item == "bottle"):
		_r(4, 26, 3, 7, Color("5e9fd0"))
		_r(5, 25, 1, 1, Color("f4f2ea"))
	_r(9, 25, 5, 8, Color("f4f2ea"))
	_r(9, 25, 5, 2, Color("4f7fd0"))
	_r(17, 28, 4, 5, Color("c9955a"))
	for i in range(3):
		if i == 0 and taken and item == "soda":
			continue
		_r(4 + i * 4, 35, 3, 7, Color("d23c3c"))
		_r(4 + i * 4, 35, 3, 1, Color("b8bcc4"))
	_r(5, 44, 9, 7, Color("b8864e"))
	_r(5, 44, 9, 1, Color("8a5e36"))
	_r(16, 46, 3, 5, Color("f4f2ea"))
	_r(16, 46, 3, 1, Color("e87a9a"))
	_r(3, 53, 20, 6, Color("a9d0e6"))
	_r(-6, 61, 36, 5, Color(1.0, 0.98, 0.85, 0.28))  # light spilling onto the floor
	_r(-3, 66, 30, 4, Color(1.0, 0.98, 0.85, 0.16))


func _draw_coffee() -> void:
	var t := _time - _start
	if busy:
		_r(3, 7, 2, 2, Color("e85050") if int(_time * 3.0) % 2 == 0 else Color("5a1818"))
	if _level > 0.0:
		var ch := _level * 10.0
		_r(15, 14 - ch, 4, ch, Color("5a3620"))
	if busy and t < 5.8:
		var y := fposmod(_time * 24.0, 12.0)
		var stop := 14.0 - _level * 10.0
		if 3.0 + y < stop:
			_r(17, 3.0 + y, 1, 2, Color("5a3620"))
	if _level > 0.12:
		for i in 3:
			var p := fposmod(_time * 0.8 + float(i) * 0.33, 1.0)
			var a := (1.0 - p) * 0.85
			var sx := 15.0 + i * 2.0 + roundf(sin(_time * 3.0 + i))
			_r(sx, 1.0 - p * 6.0, 1, 2, Color(0.93, 0.95, 0.98, a))


func _draw_copier() -> void:
	var t := _time - _start
	if busy:
		var sweep := fposmod(t * 1.25, 1.0)
		var x := 3.0 + (sweep if int(t * 1.25) % 2 == 0 else 1.0 - sweep) * 24.0
		_r(x, 8, 2, 2, Color("d8ffd0"))
		_r(x - 1, 8, 4, 1, Color(0.85, 1.0, 0.8, 0.5))
		var dots := int(clampf(t / 3.0, 0.0, 1.0) * 8.0)
		_r(5, 14, dots, 1, Color("62d070"))
		if t > 1.0:
			var out := clampf((t - 1.0) / 1.6, 0.0, 1.0) * 5.0
			_r(18, 15, 8, out, Color("f4f2ea"))
	elif t < 12.0:
		_r(18, 19, 8, 2, Color("f4f2ea"))


func _draw_cooler() -> void:
	var t := _time - _start
	var amb := fposmod(_time, 9.0)
	if not busy and amb < 1.2:
		_r(5 + (seed_offset % 3), 9.0 - amb * 6.0, 1, 1, Color("e8f2fa"))
	if busy:
		for i in 3:
			var p := fposmod(t * 2.2 + float(i) * 0.37, 1.0)
			_r(4 + i * 2, 9.0 - p * 7.0, 1, 1, Color("e8f2fa"))
		_r(6, 18, 1, 3, Color("8cb4dc"))
		_r(5, 20, 3, 1, Color("c8e0f4"))


func _draw_sink() -> void:
	if busy:
		var t := _time - _start
		_r(8, 3, 1, 4, Color("8cb4dc"))
		var w := 2 + int(fposmod(t * 6.0, 3.0))
		_r(8.0 - w / 2.0, 7, w, 1, Color("8cb4dc"))


func _draw_toilet() -> void:
	var t := _time - _start
	if busy:
		_r(10, 2 if t > 0.25 else 1, 2, 2, Color("9a9ca8"))
		var k := int(t * 8.0)
		if t < 2.2:
			_r(4, 12 + k % 2, 9, 1, Color("8cb4dc"))
			_r(6 + k % 3, 14, 5, 1, Color("b4d4ec"))


# ---- the dart board in the warehouse: the live darts of a round (Outings game "darts", see darts_game.gd) ----------------------
# The board is the baked 21 px one at art (1046, 74), 10.4 px for the 170 mm radius. Darts are drawn over the actors (z 1) as a coloured
# 2 px dot with a steel tip, the colour of whoever threw it; the dart in the air flies from the throw line in a small arc.
const DART_C := Vector2(-1.0, 8.0)  # the board's centre in this node's coordinates
const DART_PX := 10.4 / 170.0  # pixels a millimetre
const DART_FROM := Vector2(-55.0, 14.0)  # the hand at the throw line
const DART_COLORS := [Color("5aa0e8"), Color("f2862e"), Color("e0463c"), Color("5fd068")]


func _darts_game() -> RefCounted:
	if Outings.is_open and Outings.game == "darts" and Outings.phase != "intro" and Outings.g.has("game"):
		return Outings.g.game
	return null


func _draw_dart_board() -> void:
	var dg := _darts_game()
	if dg == null:
		return
	for d in dg.darts_now:
		var at: Vector2 = DART_C + Vector2(float(d.px), float(d.py)) * DART_PX
		var col: Color = DART_COLORS[maxi(0, dg.players.find(str(d.who))) % DART_COLORS.size()]
		_r(at.x - 1.0, at.y - 1.0, 2, 2, col)
		_r(at.x + 1.0, at.y, 1, 1, Color("c8ccd8"))
	if dg.phase == "flight" and not dg.flying.is_empty():
		var u: float = float(dg.flying.t)
		var end: Vector2 = DART_C + Vector2(float(dg.flying.px), float(dg.flying.py)) * DART_PX
		var pos: Vector2 = DART_FROM.lerp(end, u) + Vector2(0.0, -6.0 * sin(PI * u))
		var dir: Vector2 = (end - DART_FROM).normalized()
		var col: Color = DART_COLORS[maxi(0, dg.players.find(str(dg.flying.who))) % DART_COLORS.size()]
		draw_line(pos - dir * 3.0, pos, col, 1.0)
		_r(pos.x, pos.y, 1, 1, Color("c8ccd8"))


# ---- the warehouse's odds and ends (small E interactions, drawn in code; no set art) ---------------------------------------------
# vending_machine (a soda or water, rarely "it ate your quarter"), chair_rack (a chair rolls out), cage (a peek into the parts cage),
# bench_pc (the imaging PC: how far along, press again to restart), lamp_chain (the high bay light), radio (three fake stations on the
# bench), floor_fan (it spins), and the old tree's lights (E toggles them, a bulb now and then pops). All except the machine are low
# priority (they never steal E from a door); every line is picked with Difficulty.rng_for from the day so a day reads the same.
const VEND_LINES := [
	"CLUNK. A SODA, ONLY A LITTLE WARM.",
	"CLUNK. COLD ENOUGH.",
	"TWO QUARTERS WELL SPENT.",
	"THE MACHINE GRUNTS AND PAYS OUT.",
]
const VEND_WATER := "A BOTTLE OF WATER. HEALTHY. SUSPICIOUS."
const VEND_ATE := "IT ATE YOUR QUARTER. PRESS E TO THUMP IT."
const VEND_THUMP := "YOU THUMP THE SIDE. A SODA FALLS OUT. JUSTICE."
const VEND_FULL := "YOUR HANDS ARE FULL."
const RACK_LINES := [
	"A CHAIR WITH ONE GOOD WHEEL. YOU KNOW THE TYPE.",
	"IT SQUEAKS. THEY ALL SQUEAK.",
	"A FRESH CHAIR. YOUR BACK WILL NOT NOTICE.",
	"THE RACK HAS SIX MORE JUST LIKE IT.",
]
const RACK_AGAIN := "IT SPINS ONCE AND STOPS. THE FLOOR IS NOT LEVEL."
const CAGE_LINES := [
	"A BOX OF PS/2 KEYBOARDS. LABELED KEEP.",
	"SIXTEEN SERIAL CABLES. NOBODY KNOWS WHY.",
	"A TOWER LABELED DO NOT WIPE. IT IS WIPED.",
	"BAGS OF SCREWS. NOT ONE FITS ANYTHING.",
	"A SHELF OF OLD POWER BRICKS. ALL DIFFERENT.",
	"A BOX OF VGA CABLES. THE MONITORS ARE LONG GONE.",
	"SOMEBODY'S LUNCH, ON THE TOP SHELF. SINCE SPRING.",
	"A STACK OF XP DISCS. WHO KEEPS THESE?",
]
const CAGE_FINDS := [
	"FOUND A SPARE PATCH CABLE. YOU WILL NEED IT SOMEDAY.",
	"A BOX OF NEW MICE, STILL IN THE BAG.",
	"A SEALED TONER. SOMEONE WILL BEG FOR THIS.",
]
const IMG_LINES := [
	"THE BAR HAS ITS OWN SCHEDULE.",
	"SOMEONE SAID TWENTY MINUTES. THAT WAS YESTERDAY.",
	"THE DISK LIGHT FLICKERS. A GOOD SIGN, PROBABLY.",
	"IT HAS NOT MOVED SINCE YOU LOOKED. IT HAS.",
]
const IMG_AGAIN := "YOU HIT RESTART. SOMEBODY WILL NOTICE."
const LAMP_LINES := [
	"YOU PULL THE CHAIN. THE LIGHT THINKS ABOUT IT.",
	"CLICK. DARK. CLICK. NOT DARK. PROGRESS.",
	"THE BALLAST HUMS A LITTLE LOUDER NOW.",
]
# station, now playing (invented names and songs)
const RADIO_STATIONS := [
	{"name": "KQRZ 98.1 THE HAMSTER", "num": "981", "lines": ["THE DONGLES: SUMMER OF WI-FI.", "NINE IN A ROW, NO TALKING.", "A TRAFFIC TUNE FOR THE BIG BRIDGE."]},
	{"name": "WTKT 1040 AM TRAFFIC", "num": "104", "lines": ["THE BRIDGE IS CLOSED. AGAIN.", "WEATHER: SUNNY, CHANCE OF TICKETS.", "THE HOME TEAM LOST. ASK ALAN."]},
	{"name": "K-FLEX 101.9 CLASSIC", "num": "102", "lines": ["BLUE SCREEN BABY, THE ROCKING CHAIRS.", "A SONG YOUR DAD LIKES, AGAIN.", "THE REQUEST LINE IS BUSY."]},
]
const FAN_ON := "THE FAN WHIRS. IT MOVES THE HEAT AROUND."
const FAN_OFF := "THE FAN SPINS DOWN. THE HEAT STAYS PUT."
const TREE_ON := [
	"THE LIGHTS COME ON. IT IS NOT EVEN DECEMBER.",
	"A STRING OF BULBS, WARM AGAIN. GOOD ENOUGH.",
]
const TREE_OFF := "LIGHTS OFF. THE TREE GOES BACK TO WAITING."
const TREE_POP := "POP. A BULB GOES. ONE FEWER TO LOSE."

var _duck_tex: Texture2D = null
var _duck_skin := "duck_classic"
var _duck_toy := "toy_none"
var _sign_key := ""
var _sign_text := ""
static var fan_on := false  # the floor fan runs (kept while you are away from the room)
static var radio_i := 0  # 0 off, else the station + 1
static var tree_on := true  # the old tree's lights
static var tree_popped: Array = []  # bulbs that have popped

var _x_n := 0  # presses of this node
var _x_t := -100.0  # when it was last pressed (_time)
var _vend_owed := false  # the machine owes you a soda (it ate your quarter)
var _vend_ate := false
var _vend_clunk := false
var _img_t0 := 0.0  # bench_screen: when the progress bar started over
var _kick_until := 0.0  # flicker_lamp: kicked by the pull chain
var _pop_t := -100.0
var _pop_i := -1
var _tree_n := 0


func _x_line(list: Array, salt: String) -> String:
	_x_n += 1
	var r := Difficulty.rng_for("wh_" + salt, maxi(0, Campaign.day) * 131 + _x_n)
	return str(list[r.randi_range(0, list.size() - 1)])


func _x_roll(salt: String) -> float:
	return Difficulty.rng_for("wh_" + salt, maxi(0, Campaign.day) * 977 + _x_n * 13 + 5).randf()


# E on one of the small things (true when it was handled here); the vending machine goes the held-item way in play()
func _warehouse_press() -> bool:
	match kind:
		"chair_rack":
			_rack_press()
		"cage":
			_cage_press()
		"bench_pc":
			_bench_press()
		"lamp_chain":
			_chain_press()
		"radio":
			_radio_press()
		"floor_fan":
			_fan_press()
		_:
			return false
	return true


# ---- the vending machine: a held item, like the coffee machine
func _vend_start() -> bool:
	if _player != null and str(_player.get("held")) != "":
		Hints.toast(VEND_FULL, 2.0)
		return false
	return true


func _vend_go() -> void:
	_x_n += 1
	_vend_ate = false
	_vend_clunk = false
	var roll := _x_roll("vend")
	if _vend_owed:
		_vend_owed = false
		item = "soda"
		Hints.toast(VEND_THUMP, 3.0)
	elif roll < 0.1:
		_vend_owed = true
		_vend_ate = true
		item = ""
		Hints.toast(VEND_ATE, 3.2)
	elif roll < 0.38:
		item = "bottle"
		Hints.toast(VEND_WATER, 2.5)
	else:
		item = "soda"
		Hints.toast(VEND_LINES[_x_n % VEND_LINES.size()], 2.5)
	Sfx.play_near("ui_tick", self)


func _vend_tick() -> void:
	if busy and not _vend_clunk and _time - _start >= 0.9:
		_vend_clunk = true
		Sfx.play_near("ui_error" if _vend_ate else "clunk", self)


func _draw_vending() -> void:
	if not busy:
		return
	var e := _time - _start
	var red := Color("e04646")
	var col := red if (e < 0.9 or _vend_ate) else Color("4ed06a")
	if _vend_ate and int(e * 8.0) % 2 == 1:
		col = Color("6a1f1f")
	_r(22, 22, 2, 1, col)
	if not _vend_ate and e >= 0.9:
		var can := Color("d23c3c") if item == "soda" else Color("8cc0e8")
		_r(10, 35, 4, 5, Color("17121f"))
		_r(11, 36, 2, 3, can)
		_r(11, 35, 2, 1, Color("b8bcc4"))


# ---- the chair rack: a chair rolls out of the bottom row and across the front, then back in
func _rack_press() -> void:
	var out := _time - _x_t < 6.0
	_x_t = _time if not out else _x_t
	Sfx.play_near("squeak", self)
	Hints.toast(RACK_AGAIN if out else _x_line(RACK_LINES, "rack"), 2.8)


func _draw_chair_rack() -> void:
	var e := _time - _x_t
	if e < 0.0 or e > 6.5:
		return
	var x := 61.0
	var y := 29.0
	if e < 0.4:
		y += 6.0 * (e / 0.4)
	else:
		y += 6.0
		var u := clampf((e - 0.4) / 1.8, 0.0, 1.0)
		x += 40.0 * (1.0 - (1.0 - u) * (1.0 - u))
		if e > 5.5:
			x -= 40.0 * clampf((e - 5.5) / 1.0, 0.0, 1.0)
	var backs := [Color("6e727c"), Color("7a2f3b"), Color("3f6aa0"), Color("2a2e36")]
	var back: Color = backs[(_x_n) % backs.size()]
	var ink := Color("17121f")
	_r(x, y, 12, 9, ink)
	_r(x + 1, y + 1, 10, 7, back)
	_r(x - 1, y + 9, 14, 4, ink)
	_r(x, y + 10, 12, 2, Color("3c414d"))
	_r(x + 4, y + 13, 4, 6, ink)
	_r(x + 5, y + 13, 2, 6, Color("2a2e36"))
	_r(x, y + 19, 12, 2, ink)
	_r(x + 1, y + 21, 3, 2, ink)
	_r(x + 8, y + 21, 3, 2, ink)


# ---- the parts cage: you peek in with a flashlight, now and then something useful is in there
func _cage_press() -> void:
	_x_t = _time
	_x_n += 1
	Sfx.play_near("ui_tick", self)
	if _x_roll("cage") < 0.125:
		Career.add("cage_finds")
		Hints.toast(CAGE_FINDS[_x_n % CAGE_FINDS.size()], 3.2)
	else:
		Hints.toast(_x_line(CAGE_LINES, "cage"), 3.0)


func _draw_cage() -> void:
	var e := _time - _x_t
	if e < 0.0 or e > 1.8:
		return
	var p := Vector2(float(_h(_x_n) % 61) - 30.0, float(_h(_x_n + 3) % 25) - 14.0 + 4.0 * sin(e * 6.0))
	draw_circle(p, 13.0, Color(1.0, 0.95, 0.6, 0.12))
	draw_circle(p, 7.0, Color(1.0, 0.96, 0.7, 0.2))


# ---- the bench PC being imaged: how far along it is; a second press in a row restarts it
func img_pct() -> int:
	return int(fmod((_time - _img_t0) * 6.0, 100.0))


func img_restart() -> void:
	_img_t0 = _time


func _bench_press() -> void:
	var screen: Node = get_parent().get_node_or_null("BenchScreen")
	var again := _time - _x_t < 8.0
	_x_t = _time
	_x_n += 1
	if screen == null:
		return
	Sfx.play_near("ui_tick", self)
	if again:
		screen.img_restart()
		Hints.toast(IMG_AGAIN, 3.0)
	else:
		Hints.toast("IMG %d PERCENT. %s" % [screen.img_pct(), _x_line(IMG_LINES, "img")], 3.2)


# ---- the high bay light: a pull chain hangs from it
func kick() -> void:
	_kick_until = _time + 2.0


func _chain_press() -> void:
	_x_t = _time
	var lamp: Node = get_parent().get_node_or_null("FlickerLamp")
	if lamp != null:
		lamp.kick()
	Sfx.play_near("clunk", self)
	Hints.toast(_x_line(LAMP_LINES, "lamp"), 2.8)


func _draw_lamp_chain() -> void:
	var e := _time - _x_t
	var sway := sin(e * 9.0) * maxf(0.0, 1.0 - e / 1.2) * 3.0 if e >= 0.0 else 0.0
	for i in 22:
		var f := float(i) / 21.0
		_r(sway * f, float(i) * 2.0, 1, 1, Color("8e939e") if i % 2 == 0 else Color("5a606c"))
	_r(sway - 1.0, 44, 3, 3, Color("c8ccd8"))


# ---- the radio on the bench: off, then three stations
func _radio_press() -> void:
	radio_i = (radio_i + 1) % (RADIO_STATIONS.size() + 1)
	_x_t = _time
	Sfx.play_near("ui_pick" if radio_i > 0 else "ui_tick", self)
	if radio_i == 0:
		Hints.toast("THE RADIO CLICKS OFF. THE WAREHOUSE HUMS.", 2.5)
		return
	var st: Dictionary = RADIO_STATIONS[radio_i - 1]
	var lines: Array = st.lines
	Hints.toast("%s: %s" % [st.name, _x_line(lines, "radio")], 3.6)


func _draw_radio() -> void:
	var ink := Color("17121f")
	_r(0, 2, 16, 8, ink)
	_r(1, 3, 14, 6, Color("3b4150"))
	_r(3, 0, 10, 2, ink)
	_r(2, 4, 4, 4, Color("8e939e"))
	_r(10, 4, 4, 4, Color("8e939e"))
	_r(3, 5, 2, 2, Color("3c414d"))
	_r(11, 5, 2, 2, Color("3c414d"))
	draw_line(Vector2(14, 2), Vector2(18, -5), Color("c8ccd8"), 1.0)
	if radio_i == 0:
		_r(7, 4, 2, 3, Color("2a2e36"))
		return
	_r(6, 4, 4, 3, Color("123a1c"))
	var step := int(_time * 8.0)
	for k in 3:
		var hh := 1 + _h(step + k * 5) % 3
		_r(6 + k, 7 - hh, 1, hh, Color("4ed06a"))
	for k in 2:  # two notes drifting up
		var f := fposmod(_time * 0.7 + float(k) * 0.5, 1.0)
		_r(4.0 + float(k) * 7.0 + sin(f * 6.0 + float(k)) * 2.0, -2.0 - 9.0 * f, 2, 2, Color(1.0, 0.95, 0.6, 1.0 - f))


# ---- the floor fan: E starts or stops it; the blades are a few spokes turned every frame
func _fan_press() -> void:
	fan_on = not fan_on
	Sfx.play_near("ui_pick" if fan_on else "ui_tick", self)
	Hints.toast(FAN_ON if fan_on else FAN_OFF, 2.5)


func _draw_floor_fan() -> void:
	if not fan_on:
		return
	var c := Vector2(11, 8.5)
	var base := float(int(_time * 12.0)) * 0.9
	draw_circle(c, 7.0, Color(0.85, 0.9, 0.95, 0.28))
	for k in 3:
		var a := base + float(k) * TAU / 3.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * 6.5, Color("e6ebf2"), 1.0)
	_r(c.x - 1.0, c.y - 1.0, 2, 2, Color("5a606c"))


# ---- the old tree's lights (the tree itself is the E zone `old_tree`, see _tree_press)
func tree_toggle() -> String:
	tree_on = not tree_on
	_tree_n += 1
	Sfx.play_near("ui_tick", self)
	if not tree_on:
		return TREE_OFF
	var r := Difficulty.rng_for("wh_tree", maxi(0, Campaign.day) * 131 + _tree_n + tree_popped.size() * 7)
	if r.randf() < 0.2 and tree_popped.size() < TREE_BULBS.size() - 2:
		var pick := r.randi_range(0, TREE_BULBS.size() - 1)
		while tree_popped.has(pick):
			pick = (pick + 1) % TREE_BULBS.size()
		tree_popped.append(pick)
		_pop_i = pick
		_pop_t = _time
		Sfx.play_near("squeak", self)
		return TREE_POP
	return str(TREE_ON[_tree_n % TREE_ON.size()])
