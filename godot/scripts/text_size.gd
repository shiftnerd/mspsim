extends RefCounted
# R42 item 4: the TEXT setting's helpers (docs/dev/notes-textsize.md). Game keeps the two switches (text_large,
# high_contrast); this script holds the pure parts so pixelfont.gd and ui_style.gd need only a one-line hook each.
#   TextSize.high              HIGH CONTRAST is on (set by Game through apply)
#   TextSize.color(c)          the colour a text is drawn in: with HIGH CONTRAST light text goes to white, dark text to
#                              ink, so a hint on a plate (SOFT, MUTED, a gold or grey label) stays readable
#   TextSize.plate(a)          a dark plate's alpha: opaque enough that the world behind it never shows through letters
#   TextSize.edge(c, r)        draws the heavier panel border of HIGH CONTRAST (a second ink line and a white line inside)

const INK := Color("17121f")

static var high := false


static func apply(on: bool) -> void:
	high = on


static func color(c: Color) -> Color:
	if not high or c.a < 0.05:
		return c
	var lum := c.get_luminance()
	if lum >= 0.55:
		return c.lerp(Color.WHITE, 0.65)
	if lum <= 0.4:
		return c.lerp(INK, 0.6)
	return c


static func plate(alpha: float) -> float:
	return maxf(alpha, 0.97) if high else alpha


# a plate with a stronger edge (called after a panel's own border)
static func edge(canvas: CanvasItem, r: Rect2) -> void:
	if not high:
		return
	canvas.draw_rect(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), INK, false, 1.0)
	canvas.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color.WHITE, false, 1.0)
