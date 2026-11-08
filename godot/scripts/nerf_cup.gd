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
	# the cup: a dark outline, the red body with a shaded side and a light edge, a white band with a little ring, a rim and a straw
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -11), Vector2(6, -11), Vector2(5, 3), Vector2(-5, 3)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -10), Vector2(5, -10), Vector2(4, 2), Vector2(-4, 2)]), Color("e0463c"))
	draw_colored_polygon(PackedVector2Array([Vector2(2, -10), Vector2(5, -10), Vector2(4, 2), Vector2(2.5, 2)]), Color("b8302a"))
	draw_rect(Rect2(-4, -9, 1, 9), Color("f27a6c"))
	draw_rect(Rect2(-4.5, -6, 9, 3), Color("ffffff"))
	draw_rect(Rect2(2, -6, 2.5, 3), Color("d8d8e0"))
	draw_rect(Rect2(-1, -5, 2, 1), Color("e0463c"))
	draw_rect(Rect2(-6, -12, 12, 1), dark)
	draw_rect(Rect2(-5, -12, 10, 1), Color("f4f4fa"))
	draw_line(Vector2(1, -12), Vector2(3, -17), Color("3ee0e0"), 1.0)
	draw_line(Vector2(3, -17), Vector2(5, -17), Color("3ee0e0"), 1.0)
