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
var _actors: Node = null
var _player: Node2D = null
var _cam: Camera2D = null
var _tags: Node2D = null
var _t := 0.0


# scene: the warehouse. racers: [{key, character, custom, color, label}] with the player first.
func setup(scene: Node, the_race: RefCounted, set_x0: float, racers: Array) -> void:
	race = the_race
	x0 = set_x0
	_actors = scene.get_node("Actors")
	_player = _actors.get_node_or_null("Player")
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
	var body := AnimatedSprite2D.new()
	body.sprite_frames = Look.frames_for(str(spec.character), bool(spec.custom))
	Look.apply(body, str(spec.character), bool(spec.custom))
	body.offset = Vector2(0, -40)
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
		if key == "You":
			s = race.pos
			l = race.lane
			shake = race.wobble
		else:
			var r := _rival(key)
			if r.is_empty():
				continue
			s = float(r.s)
			l = float(r.lane)
			flag = str(r.flag)
			shake = 0.5 if flag == "!" else 0.0
		node.position = Vector2(x0 + ChairRace.world_x(s), ChairRace.lane_y(l))
		var spin: bool = flag == "spin"
		node.scale.x = (1.0 if int(_t * 8.0) % 2 == 0 else -1.0) if spin else 1.0
		node.rotation = sin(_t * 44.0) * 0.09 * minf(1.0, shake) if shake > 0.0 else 0.0
	for pr in props:
		_mark(pr)
	var f: Dictionary = Game.FORMATS[Game.format]
	var view := get_viewport_rect().size / float(f.zoom)
	if _player != null:
		_player.global_position = Vector2(x0 + ChairRace.world_x(race.pos) + view.x * 0.1, 118.0)
	if _cam != null:  # a short screen (368x128, 320x180) looks lower down, so the floor is not under the HUD
		var centre: float = float(f.cam_y) if f.follow else 64.0
		_cam.offset.y = maxf(0.0, LIFT_BOTTOM - (centre + view.y * 0.5))
	queue_redraw()
	_tags.queue_redraw()


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


func _draw() -> void:
	if race == null:
		return
	var a := x0 + ChairRace.world_x(0.0)
	var b := x0 + ChairRace.world_x(ChairRace.LEN)
	# lane marks: dashed lines between the three lanes
	for k in 2:
		var y := (float(ChairRace.LANE_Y[k]) + float(ChairRace.LANE_Y[k + 1])) * 0.5 + 0.5
		var x := a + 14.0
		while x < b - 14.0:
			draw_rect(Rect2(x, y, 6.0, 1.0), Color(1, 1, 1, 0.2))
			x += 12.0
	# the checkpoints: a stripe across the floor, a post at each end and its number
	for i in ChairRace.CHECK_FRAC.size():
		var cx := x0 + ChairRace.world_x(ChairRace.check_pos(i))
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
		_tags.draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2.0, 7.0)), p.color if key != "You" else GOLD)
		PixelFont.draw(_tags, text, at, INK if key == "You" else Color.WHITE, 1)


# the race is over: the props go back (they were copies), the player is shown again
func clear() -> void:
	if _player != null and is_instance_valid(_player):
		_player.visible = true
	if _cam != null and is_instance_valid(_cam):
		_cam.offset = Vector2.ZERO
	for key in puppets:
		if is_instance_valid(puppets[key].node):
			puppets[key].node.queue_free()
	for pr in props:
		if is_instance_valid(pr.node):
			pr.node.queue_free()
	puppets = {}
	props = []
	queue_free()
