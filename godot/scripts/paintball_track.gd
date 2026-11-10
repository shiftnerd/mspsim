extends Node2D
# gdlint:disable=max-line-length
# PAINTBALL FIELD (the western capture the flag outing): the match on the street of the paintball_field room. A node Outings adds
# to the room while the match is on. The rules (paintball_game.gd) say where everybody is; this puts every player in the room as a
# puppet (the character's own sprites, y-sorted among the room's actors), draws the two flags, the flying paintballs and the
# splats (on the ground, on a barricade, on whoever got tagged), and pins the real, hidden Player just at your puppet so the
# normal follow camera of stage.gd keeps you in the middle.

const PixelFont := preload("res://scripts/pixelfont.gd")
const TEAM_COLOR := [Color("d8483a"), Color("3a68d8")]
const PAINT := [[Color("e8584a"), Color("b8382c"), Color("f08a7a")], [Color("4a78e8"), Color("2c4cb8"), Color("7aa0f0")]]
const GOLD := Color("e0a030")
const INK := Color("17121f")
const SET_X := 30.0  # the field starts this far into the set art (paintball_set.lua)
const FEET_Y := 118.0
const BALL_SPEED := 260.0
const LIFT_BOTTOM := 166.0
# the rules are one line (x only); each player stands in a lane of the street's depth so six people do not stack up on one spot
const LANE_OFF := [-14.0, 0.0, 14.0]  # the three lanes of the street (the rules' unit.lane), as y offsets
const JIT := [0.0, -2.0, 2.0, 1.0, -1.0, 2.0]  # a pixel or two per person, so two in one lane are not one on top of the other
const LANE_SPEED := 70.0  # px/s a puppet slides from one lane to the next
# the night match (game.night): everything below is drawn in code over the same set, no new art
const NIGHT := Color(0.04, 0.06, 0.2, 0.66)  # the dark laid over the set
const NIGHT_ACTORS := Color(0.5, 0.56, 0.86)  # the tint of everybody and everything standing in the street
const LAMP := Color("f2c94c")
const SALOON_WINDOWS := [21.0, 45.0, 109.0, 133.0]  # set x of the four saloon windows (14 x 18 at y 37, paintball_set.lua)
const JAIL_WINDOW := Rect2(661.0, 47.0, 22.0, 20.0)
const SET_W := 700.0
const FLASH := 0.11  # seconds a muzzle flash lasts

var game: RefCounted
var x0 := 0.0  # scene x of set x 0
var puppets: Array = []  # {node, body, tag, splats, state, shoot_t}
var balls: Array = []  # {x, y, to, col, hit, target, team}
var ground: Array = []  # {x, y, col, w}: splats on the floor or on a barricade that stay for the match

var _top: Node2D = null
var _actors: Node = null
var _player: Node2D = null
var _player2: Node2D = null
var _cam: Camera2D = null
var _t := 0.0
var _seen_down: Array = []
var _debug := OS.get_environment("PAINT_DEBUG") == "1"
var _flashes: Array = []  # night: {at, dir, t} muzzle flashes
var _stars: Array = []  # night: [Vector2] in set pixels


func field_x(gx: float) -> float:
	return x0 + SET_X + gx


func lane_y(i: int) -> float:
	return FEET_Y + float(LANE_OFF[int(game.units[i].lane)]) + float(JIT[i % JIT.size()])


# scene: the paintball_field room. specs: one per unit, in the game's order: {character, custom, label, look}
func setup(scene: Node, the_game: RefCounted, set_x0: float, specs: Array) -> void:
	game = the_game
	x0 = set_x0
	_actors = scene.get_node("Actors")
	_player = _actors.get_node_or_null("Player")
	_player2 = _actors.get_node_or_null("Player2")
	for n in scene.get_children():
		if n is Camera2D:
			_cam = n
	name = "PaintballTrack"
	scene.add_child(self)
	scene.move_child(self, scene.get_node("Background").get_index() + 1)  # floor decals: over the art, under the actors
	_top = Node2D.new()
	_top.z_index = 20
	_top.draw.connect(_draw_top)
	add_child(_top)
	for i in specs.size():
		_add_puppet(i, specs[i])
	if _player != null:
		_player.visible = false
	if _player2 != null:
		_player2.visible = false
	if night():
		_actors.modulate = NIGHT_ACTORS
		_make_stars()
	_sync()


func night() -> bool:
	return game != null and bool(game.night)


# the same sky every night: a fixed scatter of stars above the roofs (none over the saloon front, the jail sign or the water tower)
func _make_stars() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4107
	var roofs := [Rect2(20.0, -2.0, 126.0, 40.0), Rect2(540.0, 2.0, 160.0, 40.0), Rect2(318.0, 8.0, 56.0, 36.0)]
	_stars = []
	while _stars.size() < 70:
		var at := Vector2(r.randf_range(2.0, SET_W - 2.0), r.randf_range(-70.0, 30.0))
		if not roofs.any(func(box: Rect2) -> bool: return box.has_point(at)):
			_stars.append(at)


func _add_puppet(i: int, spec: Dictionary) -> void:
	var node := Node2D.new()
	node.name = "Paint_%d" % i
	var body := AnimatedSprite2D.new()
	var look_dict: Dictionary = spec.get("look", {})
	body.sprite_frames = Look.frames_for(str(spec.character), bool(spec.custom), look_dict)
	Look.apply(body, str(spec.character), bool(spec.custom), look_dict)
	body.offset = Vector2(0, -40)
	body.play("idle_right")
	node.add_child(body)
	_actors.add_child(node)
	puppets.append({"node": node, "body": body, "label": str(spec.label), "splats": [], "state": "", "shoot_t": 0.0, "face": "right", "y": lane_y(i)})


func _process(delta: float) -> void:
	_t += delta
	_sync()


func _sync() -> void:
	if game == null:
		return
	for ev in game.events:
		_event(ev)
	game.events = []
	for i in puppets.size():
		var u: Dictionary = game.units[i]
		var p: Dictionary = puppets[i]
		var node: Node2D = p.node
		p.y = move_toward(float(p.y), lane_y(i), LANE_SPEED * get_process_delta_time())
		node.position = Vector2(field_x(float(u.x)), float(p.y))
		p.shoot_t = maxf(0.0, float(p.shoot_t) - get_process_delta_time())
		_animate(i, u, p)
	_move_balls(get_process_delta_time())
	var f: Dictionary = Game.FORMATS[Game.format]
	var view := get_viewport_rect().size / float(f.zoom)
	if _player != null:
		var focus: float = float(game.units[0].x)
		if int(game.pilots) == 2:  # co-op: the camera leans towards player 2, as far as a third of the screen
			focus += clampf((float(game.units[1].x) - focus) * 0.5, -view.x * 0.3, view.x * 0.3)
		_player.global_position = Vector2(field_x(focus), float(puppets[0].y))
	if _cam != null:  # a short screen looks lower down, so the floor is not under the HUD
		var centre: float = float(f.cam_y) if f.follow else 64.0
		_cam.offset.y = maxf(0.0, LIFT_BOTTOM - (centre + view.y * 0.5))
	queue_redraw()
	_top.queue_redraw()


func _animate(i: int, u: Dictionary, p: Dictionary) -> void:
	var body: AnimatedSprite2D = p.body
	var face := "right" if int(u.face) >= 0 else "left"
	var want := "idle"
	if float(u.down) > 0.0:
		want = "death"
	elif bool(u.duck):
		want = "crouch"
	elif float(p.shoot_t) > 0.0:
		want = "reach"
	elif absf(float(u.vx)) > 1.0:
		want = "run"
	var key := want + "_" + face
	if str(p.state) != key:
		p.state = key
		body.play(key)
	if want == "death" or want == "crouch":
		return
	if float(u.down) <= 0.0 and i in _seen_down:
		_seen_down.erase(i)
		p.splats = []  # back at their own end with a clean shirt


func _event(ev: Dictionary) -> void:
	match str(ev.kind):
		"shot":
			var u: Dictionary = game.units[int(ev.unit)]
			var p: Dictionary = puppets[int(ev.unit)]
			p.shoot_t = 0.35
			var y0 := float(p.y) - 32.0
			if night():
				_flashes.append({"at": Vector2(field_x(float(ev.from) + 9.0 * float(ev.face)), y0), "dir": float(ev.face), "t": FLASH})
			var y1 := lane_y(int(ev.target)) - 32.0 if int(ev.target) >= 0 else y0
			balls.append(
				{
					"x": float(ev.from) + 8.0 * float(ev.face),
					"x0": float(ev.from) + 8.0 * float(ev.face),
					"y": y0,
					"y0": y0,
					"y1": y1,
					"to": float(ev["to"]),
					"dir": float(ev.face),
					"team": int(u.team),
					"hit": int(ev.hit),
					"target": int(ev.target),
				}
			)
			Sfx.play("paint_pop")
		"tag":
			if not int(ev.unit) in _seen_down:
				_seen_down.append(int(ev.unit))
			Sfx.play("paint_splat")
		"pick":
			Sfx.play("ui_tick")
		"capture":
			Sfx.play("bell")


func _move_balls(dt: float) -> void:
	for fl in _flashes:
		fl.t = float(fl.t) - dt
	_flashes = _flashes.filter(func(fl: Dictionary) -> bool: return float(fl.t) > 0.0)
	var keep := []
	for b in balls:
		b.x = float(b.x) + float(b.dir) * BALL_SPEED * dt
		var span := absf(float(b.to) - float(b.x0))
		b.y = lerpf(float(b.y0), float(b.y1), clampf(absf(float(b.x) - float(b.x0)) / maxf(span, 1.0), 0.0, 1.0))
		if (float(b.to) - float(b.x)) * float(b.dir) <= 0.0:
			_splat(b)
		else:
			keep.append(b)
	balls = keep


func _splat(b: Dictionary) -> void:
	var team := int(b.team)
	var pal: Array = PAINT[team]
	if int(b.hit) >= 0:
		var p: Dictionary = puppets[int(b.hit)]
		var shapes: Array = p.splats
		if shapes.size() < 7:
			shapes.append({"dx": float(randi() % 9) - 4.0, "dy": -50.0 + float(randi() % 36), "col": pal[randi() % 3], "w": 2 + randi() % 3})
	else:
		ground.append({"x": float(b.to), "y": float(b.y1) + 32.0 - 8.0 + float(randi() % 14), "col": pal[randi() % 3], "w": 2 + randi() % 3})
		if ground.size() > 60:
			ground.pop_front()


func _draw() -> void:
	if game == null:
		return
	if night():
		_draw_night()
	for l in LANE_OFF.size():  # the lanes, as dashes on the street
		var gx := 6.0
		while gx < float(game.LEN) - 6.0:
			draw_rect(Rect2(Vector2(field_x(gx), FEET_Y + float(LANE_OFF[l]) + 1.0), Vector2(4, 1)), Color(1, 1, 1, 0.13))
			gx += 12.0
	for g in ground:
		var at := Vector2(field_x(float(g.x)), float(g.y))
		draw_rect(Rect2(at, Vector2(float(g.w), 1.0)), g.col)
		draw_rect(Rect2(at + Vector2(1, -1), Vector2(1, 3)), g.col)


# the night: the dark over the whole set (this node is drawn over the art and under everybody), then the stars, a moon and the lit
# windows of the saloon and the jail with the light they throw on the porch
func _draw_night() -> void:
	draw_rect(Rect2(x0 - 40.0, -140.0, SET_W + 80.0, 420.0), NIGHT)
	for i in _stars.size():
		var at: Vector2 = _stars[i]
		var twinkle := 0.55 + 0.45 * sin(_t * (1.5 + float(i % 5) * 0.4) + float(i))
		draw_rect(Rect2(Vector2(x0 + at.x, at.y), Vector2(1, 1)), Color(1, 1, 0.92, twinkle))
	var moon := Vector2(x0 + 452.0, -34.0)
	draw_circle(moon, 7.0, Color("f4f0d8"))
	draw_circle(moon + Vector2(3.0, -2.0), 6.0, Color(0.09, 0.11, 0.26))  # a crescent: the night's own colour over the disc
	for wx: float in SALOON_WINDOWS:
		var box := Rect2(x0 + wx, 37.0, 14.0, 18.0)
		draw_rect(box.grow(3.0), Color(LAMP, 0.1))
		draw_rect(box.grow(1.0), Color(LAMP, 0.16))
		draw_rect(box, LAMP)
		draw_rect(Rect2(box.position + Vector2(6, 0), Vector2(1, 18)), INK)
		draw_rect(Rect2(box.position + Vector2(0, 8), Vector2(14, 1)), INK)
	draw_rect(Rect2(x0 + 67.0, 53.0, 34.0, 7.0), Color(LAMP, 0.7))  # the lamp inside, over the swinging doors
	draw_rect(Rect2(x0 + 68.0, 60.0, 32.0, 28.0), Color(LAMP, 0.16))
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + 66.0, 88.0), Vector2(x0 + 102.0, 88.0), Vector2(x0 + 116.0, 104.0), Vector2(x0 + 52.0, 104.0)]), Color(LAMP, 0.13))
	var jail := Rect2(JAIL_WINDOW.position + Vector2(x0, 0.0), JAIL_WINDOW.size)
	draw_rect(jail.grow(2.0), Color(LAMP, 0.1))
	draw_rect(jail, Color(LAMP, 0.6))
	for k in 4:
		draw_rect(Rect2(jail.position + Vector2(1.0 + 5.0 * float(k), 0.0), Vector2(2, 20)), Color("3a3d48"))
	draw_rect(Rect2(x0 + 588.0, 70.0, 3.0, 3.0), LAMP)  # the door handle catches the light


# flags, splats on people, the paintballs and the name tags: above everything
func _draw_top() -> void:
	if game == null:
		return
	for t in 2:  # the flags on their stakes (a flag that is carried goes with its carrier)
		var f: Dictionary = game.flags[t]
		var col: Color = TEAM_COLOR[t]
		if int(f.carried) >= 0:
			var c: Dictionary = puppets[int(f.carried)]
			_flag(Vector2(float(c.node.position.x) - 4.0, float(c.node.position.y) - 56.0), col, 10.0, true)
		else:
			_flag(Vector2(field_x(float(f.x)), FEET_Y - 2.0), col, 26.0, bool(f.home))
	for i in puppets.size():
		var p: Dictionary = puppets[i]
		var node: Node2D = p.node
		for s in p.splats:
			var at: Vector2 = node.position + Vector2(float(s.dx), float(s.dy))
			_top.draw_rect(Rect2(at, Vector2(float(s.w), float(s.w))), s.col)
			_top.draw_rect(Rect2(at + Vector2(float(s.w), 1.0), Vector2(1, 1)), s.col)
	for b in balls:
		var at := Vector2(field_x(float(b.x)), float(b.y))
		var col: Color = PAINT[int(b.team)][0]
		_top.draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), INK)
		_top.draw_rect(Rect2(at, Vector2(2, 2)), col)
		_top.draw_rect(Rect2(at - Vector2(float(b.dir) * 4.0, 0.0), Vector2(2, 1)), Color(col, 0.5))
		if night():  # a paintball is the brightest thing in the street
			_top.draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), Color(col, 0.22))
	for fl in _flashes:  # night: the marker's puff lights up for a blink
		var fa: Vector2 = fl.at
		var k: float = clampf(float(fl.t) / FLASH, 0.0, 1.0)
		_top.draw_circle(fa, 11.0, Color(1.0, 0.92, 0.6, 0.16 * k))
		_top.draw_rect(Rect2(fa - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 0.85, k))
		_top.draw_rect(Rect2(fa + Vector2(float(fl.dir) * 2.0, 0.0), Vector2(3, 1)), Color(1.0, 0.85, 0.4, k))
		_top.draw_rect(Rect2(fa + Vector2(0, -3), Vector2(1, 7)), Color(1.0, 0.85, 0.4, 0.7 * k))
	for i in puppets.size():
		var p: Dictionary = puppets[i]
		var u: Dictionary = game.units[i]
		var node: Node2D = p.node
		var text := str(p.label)
		var w := float(PixelFont.width(text, 1))
		var at: Vector2 = node.position + Vector2(-w * 0.5 + 1.0, -50.0 if not bool(u.duck) else -36.0)
		if float(u.down) > 0.0:
			at.y = node.position.y - 14.0
		var mine: bool = bool(u.human)  # you, and player 2 in co-op
		if mine and _cam != null:  # a pilot who is off the screen keeps a tag at its edge
			var half: float = get_viewport_rect().size.x / _cam.zoom.x * 0.5
			var mid: float = _cam.get_screen_center_position().x
			at.x = clampf(at.x, mid - half + 2.0, mid + half - w - 3.0)
		_top.draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2.0, 7.0)), GOLD if mine else TEAM_COLOR[int(u.team)])
		PixelFont.draw(_top, text, at, INK if mine else Color.WHITE, 1)
		if _debug:  # the blackboard of every unit, with PAINT_DEBUG=1 in the environment
			PixelFont.draw(_top, game.debug_line(i), at + Vector2(-14.0, 9.0 + 56.0), Color(1, 1, 1, 0.8), 1)
		if float(u.down) > 0.0 and not game.is_out(i):  # the seconds until they are back in the game
			PixelFont.draw(_top, str(ceili(float(u.down))), at + Vector2(w * 0.5 - 1.0, -8.0), Color.WHITE, 1)


# a flag on a pole: base at `at`, `h` tall, the cloth waving; a flag away from home has a small arrow-less stripe (it is just lying by its pole)
func _flag(at: Vector2, col: Color, h: float, home: bool) -> void:
	_top.draw_rect(Rect2(at + Vector2(0, -h), Vector2(1, h)), INK)
	var wave := sin(_t * 6.0) * 1.0
	for k in 9:
		var hh := 7.0 - float(k) * 0.5
		_top.draw_rect(Rect2(at + Vector2(1.0 + float(k), -h + wave * float(k) / 8.0), Vector2(1, hh)), col if k < 8 else INK)
	_top.draw_rect(Rect2(at + Vector2(1, -h), Vector2(9, 1)), INK)
	if not home:
		_top.draw_rect(Rect2(at + Vector2(-3, -1), Vector2(7, 2)), Color(col, 0.55))


# the match is over: the puppets go, the player is shown again
func clear() -> void:
	if _player != null and is_instance_valid(_player):
		_player.visible = true
	if _player2 != null and is_instance_valid(_player2):
		_player2.visible = true
	if _cam != null and is_instance_valid(_cam):
		_cam.offset = Vector2.ZERO
	if _actors != null and is_instance_valid(_actors):
		_actors.modulate = Color.WHITE
	_flashes = []
	for p in puppets:
		if is_instance_valid(p.node):
			p.node.queue_free()
	puppets = []
	balls = []
	ground = []
	queue_free()
