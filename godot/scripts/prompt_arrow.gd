extends Node2D
# Small bobbing arrow shown above something the player can use.

var base_y := 0.0
var _t := 0.0
var _shake_t := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 30
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([Vector2(-4, -1), Vector2(4, -1), Vector2(0, 6)])
	outline.color = Color("17121f")
	add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, 4)])
	fill.color = Color("ffffff")
	add_child(fill)


func shake() -> void:
	modulate = Color(1.0, 0.3, 0.3)
	_shake_t = 0.35


func _process(delta: float) -> void:
	_t += delta
	position.y = base_y + (1 if int(_t * 4.0) % 2 == 0 else 0)
	if _shake_t > 0.0:
		_shake_t -= delta
		position.x = (1 if int(_shake_t * 30.0) % 2 == 0 else -1) * 2
		if _shake_t <= 0.0:
			position.x = 0
			modulate = Color(0.62, 0.62, 0.68)
