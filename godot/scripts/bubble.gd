extends Node2D
# Speech bubble with a small icon (dots, !, ?, heart). The node sits at the bubble's tail tip.

const INK := Color("17121f")
const PATTERNS := {
	"!": ["XX", "XX", "XX", "XX", "  ", "XX"],
	"?": [" XX ", "X  X", "   X", "  X ", " X  ", "    ", " X  "],
	"heart": [" X X ", "XXXXX", " XXX ", "  X  "],
	"note": ["  XX ", "  X X", "  X  ", "  X  ", " XX  ", "XXX  "],
}

var glyph := "dots":
	set(value):
		glyph = value
		queue_redraw()

var _t := 0.0


func _ready() -> void:
	add_to_group("emissive")
	z_as_relative = false
	z_index = 30


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-8, -14, 16, 11), INK)
	draw_rect(Rect2(-7, -13, 14, 9), Color.WHITE)
	draw_rect(Rect2(-2, -4, 5, 1), INK)
	draw_rect(Rect2(-1, -3, 3, 1), INK)
	draw_rect(Rect2(0, -2, 1, 1), INK)
	draw_rect(Rect2(-1, -4, 3, 1), Color.WHITE)
	draw_rect(Rect2(0, -3, 1, 1), Color.WHITE)
	if glyph == "dots":
		var active := int(_t * 5.0) % 3
		for i in 3:
			draw_rect(Rect2(-5 + i * 3, -10 - (1 if i == active else 0), 2, 2), INK)
		return
	var rows: Array = PATTERNS.get(glyph, PATTERNS["!"])
	var color := Color("d23c3c") if glyph == "heart" else INK
	var w: int = String(rows[0]).length()
	var top := -9 - rows.size() / 2
	for y in rows.size():
		for x in w:
			if String(rows[y])[x] == "X":
				draw_rect(Rect2(-w / 2 + x, top + y, 1, 1), color)
