extends Node2D
# The dotted arc that shows where a charged dart will go. Dots are in world coordinates.

const STEP := 0.05
const GRAVITY := 75.0
const FLOOR_Y := 116.0

var _dots := PackedVector2Array()


func set_path(start: Vector2, vel: Vector2) -> void:
	_dots = PackedVector2Array()
	var pos := start
	var v := vel
	for i in 90:
		_dots.append(pos)
		v.y += GRAVITY * STEP
		pos += v * STEP
		if pos.y >= FLOOR_Y:
			_dots.append(Vector2(pos.x, FLOOR_Y))
			break
	queue_redraw()


func _draw() -> void:
	for i in _dots.size():
		var last := i == _dots.size() - 1
		if last:
			draw_rect(Rect2(_dots[i] - Vector2(3, 3), Vector2(7, 7)), Color("17121f"))
			draw_rect(Rect2(_dots[i] - Vector2(2, 2), Vector2(5, 5)), Color("ff8a1f"))
			draw_rect(Rect2(_dots[i] - Vector2(1, 1), Vector2(3, 3)), Color("ffe08a"))
		elif i % 2 == 0:
			draw_rect(Rect2(_dots[i] - Vector2(3, 3), Vector2(6, 6)), Color("17121f"))
			draw_rect(Rect2(_dots[i] - Vector2(2, 2), Vector2(4, 4)), Color("ffe08a"))
