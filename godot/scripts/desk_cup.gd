extends Node2D
# A cup on a desk (the node sits on the desk's sort line; the cup is drawn up on the desktop).

const INK := Color("17121f")

var item := "":
	set(value):
		item = value
		queue_redraw()

var rest_y := 84.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if item == "coffee":
		queue_redraw()


func _draw() -> void:
	if item == "":
		return
	draw_set_transform(Vector2(0, rest_y - 109.0), 0.0, Vector2.ONE)
	draw_rect(Rect2(-3, -9, 6, 9), INK)
	if item == "coffee":
		draw_rect(Rect2(-2, -8, 4, 7), Color("f4f2ea"))
		draw_rect(Rect2(-2, -8, 4, 2), Color("5a3620"))
		draw_rect(Rect2(3, -7, 1, 4), INK)
		var p := fposmod(_t * 0.8, 1.0)
		var wisp := Rect2(-1 + roundf(sin(_t * 3.0)), -11 - p * 4.0, 1, 2)
		draw_rect(wisp, Color(0.93, 0.95, 0.98, 1.0 - p))
	elif item == "soda":
		draw_rect(Rect2(-2, -8, 4, 7), Color("d23c3c"))
		draw_rect(Rect2(-2, -8, 4, 1), Color("b8bcc4"))
		draw_rect(Rect2(-2, -5, 4, 2), Color("f4f2ea"))
	elif item == "bottle":
		draw_rect(Rect2(-2, -8, 4, 7), Color("cfe6f6"))
		draw_rect(Rect2(-2, -5, 4, 4), Color("8cc0e8"))
		draw_rect(Rect2(-1, -10, 2, 1), Color("f4f2ea"))
	else:
		draw_rect(Rect2(-2, -8, 4, 7), Color("e4f2fb"))
		draw_rect(Rect2(-2, -6, 4, 5), Color("8cc0e8"))
