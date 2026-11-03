extends Node2D
# The cup of CAPTURE THE CUP: a code-drawn paper cup on a little stand. fall() tips it over for a moment.

var fall_t := 0.0


func fall() -> void:
	fall_t = 0.9


func _process(delta: float) -> void:
	fall_t = maxf(0.0, fall_t - delta)
	queue_redraw()


func _draw() -> void:
	var dark := Color("17121f")
	draw_rect(Rect2(-6, 2, 12, 3), Color("8a6a42"))
	draw_rect(Rect2(-5, 5, 2, 4), Color("6a4f2e"))
	draw_rect(Rect2(3, 5, 2, 4), Color("6a4f2e"))
	if fall_t > 0.0:
		var k := 1.0 - fall_t / 0.9
		draw_set_transform(Vector2(0, 0), k * 1.4, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -10), Vector2(5, -10), Vector2(4, 2), Vector2(-4, 2)]), Color("e0463c"))
	draw_rect(Rect2(-4.5, -6, 9, 2), Color("ffffff"))
	draw_rect(Rect2(-5, -11, 10, 1), dark)
