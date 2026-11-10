extends Node2D
# gdlint:disable=max-line-length
# CHAIR TRACK (roadmap R18 phase 2): the chair race on the warehouse floor. A node Outings adds to the room while the race
# is on. It draws the lane marks, the checkpoint stripes and the oil puddles on the floor (below everything standing in the
# room), puts every racer in the room as a small puppet (the real office chair with the character's own seated sprite, y-sorted
# among the room's actors) and copies of the six loose `race_prop` sprites onto the lanes. The sim (chair_race.gd) says where
# everything is; this only follows it. The real Player node is hidden and pinned just ahead of your puppet, so the normal
# follow camera (stage.gd) rolls along with you.

const ChairRace := preload("res://scripts/chair_race.gd")
const PixelFont := preload("res://scripts/pixelfont.gd")
const CHAIR_TEX := preload("res://assets/props/chair_office.png")
# prop kind -> the parked sprite in the room (scene group race_prop) it is copied from
const PROP_NODES := {
	"cone": "race_cone",
	"wet": "race_wet_sign",
	"puddle": "race_oil_puddle",
	"pallet": "race_pallet_small",
	"box": "race_box_stack",
	"can": "race_trash_can",
}
const GOLD := Color("e0a030")
const GREEN := Color("2f9e4f")
const INK := Color("17121f")
const CHAIR_DX := -15.0  # the chair sprite's left edge, from the seat
const CHAIR_DY := -6.0
const LIFT_BOTTOM := 166.0  # the camera shows at least down to this y: the floor band stays clear of the HUD bars (about 31 px) at the bottom

var race: RefCounted
var x0 := 0.0  # scene x of set x 0
var puppets := {}  # "You" or a rival's name -> {node, body, chair, color, label}
var props: Array = []  # {o, node, kind, marked}

var _tex := {}  # kind -> {tex, off}
var _paint := {}  # floor paint sprites (assets/props/chair_<id>.png, tools/make_game_art.lua); null = missing, the old rectangles are drawn
var _actors: Node = null
var _player: Node2D = null
var _player2: Node2D = null  # co-op: player 2's body, hidden while they ride the tandem
var _cam: Camera2D = null
var _tags: Node2D = null
var _t := 0.0


# scene: the warehouse. racers: [{key, character, custom, color, label}] with the player first.
func setup(scene: Node, the_race: RefCounted, set_x0: float, racers: Array) -> void:
	race = the_race
	x0 = set_x0
	_actors = scene.get_node("Actors")
	_player = _actors.get_node_or_null("Player")
	_player2 = _actors.get_node_or_null("Player2")
	for n in scene.get_children():
		if n is Camera2D:
			_cam = n
	name = "ChairTrack"
	for n in scene.get_tree().get_nodes_in_group("race_prop"):
		for kind in PROP_NODES:
			if str(n.name).begins_with(str(PROP_NODES[kind])) and n is Sprite2D:
				_tex[kind] = {"tex": n.texture, "off": n.offset}
	scene.add_child(self)
	scene.move_child(self, scene.get_node("Background").get_index() + 1)  # floor marks: over the art, under the actors
	_tags = Node2D.new()
	_tags.z_index = 20
	_tags.draw.connect(_draw_tags)
	add_child(_tags)
	for spec in racers:
		_add_puppet(spec)
	for o in race.obstacles:
		if o.kind != "puddle" and _tex.has(o.kind):
			_add_prop(o)
	if _player != null:
		_player.visible = false
	if _player2 != null and puppets.has("You2"):
		_player2.visible = false
	_sync()


func _add_puppet(spec: Dictionary) -> void:
	var node := Node2D.new()
	node.name = "Racer_" + str(spec.key)
	var chair := Sprite2D.new()
	chair.texture = CHAIR_TEX
	chair.centered = false
	chair.offset = Vector2(0, -30)
	chair.position = Vector2(CHAIR_DX, CHAIR_DY)
	if spec.color != Color.WHITE:
		chair.modulate = Color.WHITE.lerp(spec.color, 0.55)  # each rival's chair is tinted in their colour
	node.add_child(chair)
	chair.visible = not bool(spec.get("rider", false))  # co-op: the second pilot rides the same chair
	var body := AnimatedSprite2D.new()
	var look_dict: Dictionary = spec.get("look", {})  # co-op: the second pilot's own look
	body.sprite_frames = Look.frames_for(str(spec.character), bool(spec.custom), look_dict)
	Look.apply(body, str(spec.character), bool(spec.custom), look_dict)
	body.offset = Vector2(0, -40)
	body.position.x = -8.0 if bool(spec.get("rider", false)) else 0.0
	body.play("sit_right")
	node.add_child(body)
	_actors.add_child(node)
	puppets[spec.key] = {"node": node, "body": body, "chair": chair, "color": spec.color, "label": spec.label}


func _add_prop(o: Dictionary) -> void:
	var t: Dictionary = _tex[o.kind]
	var s := Sprite2D.new()
	s.texture = t.tex
	s.centered = false
	var off: Vector2 = t.off
	s.offset = Vector2(-ChairRace.prop_width(str(o.kind)) * 0.5, off.y)  # the sprite's origin is the middle of its base
	s.position = Vector2(x0 + ChairRace.world_x(float(o.x)), ChairRace.LANE_Y[int(o.lane)] + 1.0)
	s.name = "Prop_%s_%d" % [o.kind, props.size()]
	_actors.add_child(s)
	props.append({"o": o, "node": s, "kind": o.kind, "marked": false})


func _process(delta: float) -> void:
	_t += delta
	_sync()


func _sync() -> void:
	if race == null:
		return
	for key in puppets:
		var p: Dictionary = puppets[key]
		var node: Node2D = p.node
		var s: float
		var l: float
		var flag := ""
		var shake := 0.0
		var facing := 1.0
		if key == "You" or key == "You2":
			s = race.pos
			l = race.lane
			shake = race.wobble
			if _fight():  # the chair fight: you can face either way, and a bumped chair spins
				facing = float(race.face)
				flag = str(race.chairs[0].flag)
		else:
			var r := _rival(key)
			if r.is_empty():
				continue
			s = float(r.s)
			l = float(r.lane)
			flag = str(r.flag)
			shake = 0.5 if flag == "!" else 0.0
			facing = float(r.get("face", 1))
		node.position = Vector2(x0 + ChairRace.world_x(s), ChairRace.lane_y(l))
		var spin: bool = flag == "spin"
		node.scale.x = ((1.0 if int(_t * 8.0) % 2 == 0 else -1.0) if spin else 1.0) * facing
		node.rotation = sin(_t * 44.0) * 0.09 * minf(1.0, shake) if shake > 0.0 else 0.0
	for pr in props:
		_mark(pr)
	var f: Dictionary = Game.FORMATS[Game.format]
	var view := get_viewport_rect().size / float(f.zoom)
	if _player != null:
		_player.global_position = Vector2(x0 + ChairRace.world_x(race.pos) + (0.0 if _fight() else view.x * 0.1), 118.0)
	if _cam != null:  # a short screen (368x128, 320x180) looks lower down, so the floor is not under the HUD
		var centre: float = float(f.cam_y) if f.follow else 64.0
		_cam.offset.y = maxf(0.0, LIFT_BOTTOM - (centre + view.y * 0.5))
	queue_redraw()
	_tags.queue_redraw()


# the chair fight (chair_fight.gd) is drawn with the race's puppets: it has a strip of floor instead of a course
func _fight() -> bool:
	return race != null and race.get("fight") == true


func _rival(key: String) -> Dictionary:
	for r in race.rivals:
		if r.n == key:
			return r
	return {}


# a prop that was hit falls over or is shoved
func _mark(pr: Dictionary) -> void:
	var o: Dictionary = pr.o
	if pr.marked or not (o.hit or o.down):
		return
	pr.marked = true
	var s: Sprite2D = pr.node
	match str(pr.kind):
		"cone":
			s.rotation_degrees = 90.0
			s.position.y += 3.0
		"wet":
			s.rotation_degrees = 80.0
			s.position.y += 3.0
		"can":
			s.rotation_degrees = 75.0
			s.position.x += 4.0
			s.position.y += 3.0
		_:
			s.position.x += 3.0


func floor_paint(id: String) -> Texture2D:
	if not _paint.has(id):
		var path := "res://assets/props/chair_%s.png" % id
		_paint[id] = load(path) if ResourceLoader.exists(path) else null
	return _paint[id]


# the fight's ring painted on the floor: a hazard bracket at each end, a dashed line along both edges, a spot in the middle
func _ring() -> bool:
	if floor_paint("ring_end") == null or floor_paint("ring_line") == null:
		return false
	var lx := x0 + ChairRace.world_x(float(race.arena[0])) - 13.0
	var rx := x0 + ChairRace.world_x(float(race.arena[1])) + 13.0
	var x := lx + 12.0
	while x + 12.0 <= rx - 12.0:
		draw_texture(floor_paint("ring_line"), Vector2(x, 105.0))
		draw_texture(floor_paint("ring_line"), Vector2(x, 131.0))
		x += 12.0
	draw_texture(floor_paint("ring_end"), Vector2(lx, 105.0))
	draw_texture_rect(floor_paint("ring_end"), Rect2(rx - 12.0, 105.0, -12.0, 28.0), false)  # the right end is the mirror
	if floor_paint("ring_spot") != null:
		draw_texture(floor_paint("ring_spot"), Vector2(roundf((lx + rx) * 0.5) - 15.0, 113.0))
	return true


func _draw() -> void:
	if race == null:
		return
	var a := x0 + ChairRace.world_x(float(race.arena[0]) - 14.0 if _fight() else 0.0)
	var b := x0 + ChairRace.world_x(float(race.arena[1]) + 14.0 if _fight() else float(race.length))
	# lane marks: dashed lines between the three lanes
	for k in 2:
		var y := (float(ChairRace.LANE_Y[k]) + float(ChairRace.LANE_Y[k + 1])) * 0.5 + 0.5
		var x := a + 14.0
		while x < b - 14.0:
			draw_rect(Rect2(x, y, 6.0, 1.0), Color(1, 1, 1, 0.2))
			x += 12.0
	# the checkpoints: a stripe across the floor, a post at each end and its number
	if _fight() and _ring():
		pass
	elif _fight():  # the two ends of the strip: a red and white post line
		for end_x: float in race.arena:
			var ex := x0 + ChairRace.world_x(end_x) + (9.0 if end_x > float(race.arena[0]) else -11.0)
			for k in 6:
				draw_rect(Rect2(ex, 107.0 + 4.0 * float(k), 2.0, 4.0), Color("d8483a") if k % 2 == 0 else Color.WHITE)
	elif float(race.length) != ChairRace.LEN:  # a course that ends before the painted line: its own checkered line on the floor
		var fx := x0 + ChairRace.world_x(float(race.length)) + 8.0
		if floor_paint("finish") != null:
			draw_texture(floor_paint("finish"), Vector2(fx - 2.0, 107.0))
		for row in (12 if floor_paint("finish") == null else 0):
			for col in 3:
				draw_rect(Rect2(fx + 2.0 * float(col), 107.0 + 2.0 * float(row), 2.0, 2.0), INK if (row + col) % 2 == 0 else Color.WHITE)
		PixelFont.draw(self, "FINISH", Vector2(fx - 9.0, 98.0), Color.WHITE, 1)
	for i in race.checks.size():
		var cx := x0 + ChairRace.world_x(race.cp(i))
		var col := GREEN if i < race.cp_next else GOLD
		draw_rect(Rect2(cx - 1.0, 107.0, 3.0, 24.0), Color(col, 0.85))
		for py in [104.0, 131.0]:
			draw_rect(Rect2(cx - 1.0, py, 3.0, 4.0), INK)
			draw_rect(Rect2(cx, py, 1.0, 3.0), col)
		PixelFont.draw(self, str(i + 1), Vector2(cx - 1.0, 98.0), col, 1)
	# the oil: floor decals under the chairs
	if _tex.has("puddle"):
		var t: Dictionary = _tex["puddle"]
		for o in race.obstacles:
			if o.kind == "puddle":
				var w := ChairRace.prop_width("puddle")
				var sc := float(race.params.slick)
				var size := Vector2(w * sc, 10.0)
				var ctr := Vector2(x0 + ChairRace.world_x(float(o.x)), ChairRace.LANE_Y[int(o.lane)] - 1.0)
				draw_texture_rect(t.tex, Rect2(ctr - size * 0.5, size), false)


# the names over the racers' heads: YOU in gold, the rivals' first letter in their colour
func _draw_tags() -> void:
	for key in puppets:
		var p: Dictionary = puppets[key]
		var node: Node2D = p.node
		var text := str(p.label)
		var w := float(PixelFont.width(text, 1))
		var at := node.position + Vector2(-w * 0.5 + 1.0, -50.0)
		var mine: bool = key == "You" or key == "You2"
		_tags.draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2.0, 7.0)), p.color if not mine else GOLD)
		PixelFont.draw(_tags, text, at, INK if mine else Color.WHITE, 1)


# the race is over: the props go back (they were copies), the player is shown again
func clear() -> void:
	if _player != null and is_instance_valid(_player):
		_player.visible = true
	if _player2 != null and is_instance_valid(_player2):
		_player2.visible = true
	if _cam != null and is_instance_valid(_cam):
		_cam.offset = Vector2.ZERO
	for key in puppets:
		_drop(puppets[key].node)
	for pr in props:
		_drop(pr.node)
	puppets = {}
	props = []
	_drop(self)


# out of the tree at once (another event picked on the card puts a new track and new puppets in the room in the same frame, under
# the same names), freed at the end of the frame
func _drop(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()
