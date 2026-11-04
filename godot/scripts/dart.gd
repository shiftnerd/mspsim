extends Node2D
# A foam dart: arcs through the air, sticks in walls and props, hits people or lands on the floor.

const GRAVITY := 75.0
const FLOOR_Y := 116.0

var vel := Vector2.ZERO
var shooter := ""
var state := "fly"  # fly, stuck, floor
var _age := 0.0
var _trail: Array = []


func _ready() -> void:
	add_to_group("darts")
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if state == "fly":
		_fly(delta)
	elif _age > 45.0:
		queue_free()
	elif state == "floor":
		Nerf.gone(self)


func _fly(delta: float) -> void:
	_trail.append(global_position)
	if _trail.size() > 6:
		_trail.pop_front()
	position += vel * delta
	vel.y += GRAVITY * delta
	Nerf.cup_check(global_position, shooter)
	if not has_meta("belled") and Nerf.hit_bell(global_position):
		set_meta("belled", true)
		vel = Vector2(-vel.x * 0.2, 25.0)
		return
	var victim := Nerf.find_victim(global_position, shooter, self)
	if victim != null:
		Nerf.dart_hit(self, victim)
		position.x -= signf(vel.x) * 4.0
		_land()
		return
	if Nerf.door_gap(global_position):  # out through the open dock door: gone for good
		queue_free()
		return
	var target := Nerf.stick_target(global_position)
	if target != null:
		state = "stuck"
		_age = 0.0
		if target is Sprite2D:
			var fx: Node = target.get_node_or_null("Fx")
			if fx != null and fx.has_method("hit"):
				fx.hit()
		return
	if position.y >= FLOOR_Y or _age > 4.0:
		_land()


func _land() -> void:
	state = "floor"
	position.y = FLOOR_Y
	_age = 0.0


func _draw() -> void:
	var d := signf(vel.x) if vel.x != 0.0 else 1.0
	var orange := Color("ff8a1f")
	var ink := Color("17121f")
	if state == "floor":
		draw_rect(Rect2(-5, -2, 10, 4), ink)
		draw_rect(Rect2(-4, -1, 5, 2), orange)
		draw_rect(Rect2(1, -1, 3, 2), Color("ffd23c"))
		return
	if state == "fly":
		for i in _trail.size():
			var a := 0.12 + 0.07 * float(i)
			draw_rect(
				Rect2(to_local(_trail[i]) - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.85, 0.3, a)
			)
	var tilt := clampf(vel.y / 150.0, -1.0, 1.0)
	draw_rect(Rect2(-5.0, -2.0 + tilt, 10, 4), ink)
	draw_rect(Rect2(-4.0 if d > 0.0 else -3.0, -1.0 + tilt, 7, 2), orange)
	draw_rect(Rect2(2.0 if d > 0.0 else -4.0, -1.0 + tilt, 2, 2), Color("ffd23c"))
