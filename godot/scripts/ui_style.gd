extends RefCounted
# gdlint:disable=max-line-length
# One look for every outing screen (the Outings intro / result panels, the in-room HUD strips, the caption
# bar and the printer game): a bordered panel with a blue header bar, a footer hint line, the same colours,
# the same text size (the 3x5 font at scale 1) and the same star row. All helpers draw on a CanvasItem
# in screen pixels. Use UiStyle.panel() for pages, UiStyle.strip() / hint_bar() / caption_bar() in rooms.

const PixelFont := preload("res://scripts/pixelfont.gd")
const PadGlyphs := preload("res://scripts/pad_glyphs.gd")  # R14: pad buttons in a footer hint are small sprites
const TextSize := preload("res://scripts/text_size.gd")  # R42 item 4: the HIGH CONTRAST plates and borders
const INK := Color("17121f")
const WHITE := Color("ffffff")
const PANEL := Color("e9ecf1")
const HEAD := Color("1f4e8c")
const MUTED := Color("46506a")  # hint text on a light panel
const SOFT := Color("c9d2e0")  # hint text on a dark bar, empty bars
const DARK := Color(0.04, 0.03, 0.08, 0.86)  # HUD strips, hint bar and caption bar
const GOLD := Color("e0a030")
const GREEN := Color("2f9e4f")
const RED := Color("c0392b")
const HEAD_H := 9.0
const STRIP_H := 11.0  # one-line HUD strip
const HINT_H := 9.0  # the control hint line at the bottom of the screen in a room
const MARGIN := 4.0

static var hint_extra := 0.0  # R42 LARGE: how much taller than HINT_H the last hint_bar came out (a long hint wraps upward)
static var hint_frame := -1  # the frame that value is from (a screen without a hint bar must not inherit it)


static func text(c: CanvasItem, s: String, x: float, y: float, color := INK) -> void:
	PixelFont.draw(c, s, Vector2(x, y), color, 1)


static func center(c: CanvasItem, s: String, cx: float, y: float, color := INK) -> void:
	PixelFont.draw(c, s, Vector2(cx - float(PixelFont.width(s, 1)) * 0.5, y), color, 1)


static func right(c: CanvasItem, s: String, rx: float, y: float, color := INK) -> void:
	PixelFont.draw(c, s, Vector2(rx - float(PixelFont.width(s, 1)), y), color, 1)


static func wrap_text(s: String, chars: int) -> Array:
	s = PixelFont.keys(s)  # R42: key tokens become the key or the pad button before the lines are cut
	var out := []
	var line := ""
	for word in s.split(" "):
		if line != "" and line.length() + 1 + word.length() > chars:
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	out.append(line)
	return out


static func star(c: CanvasItem, ctr: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI * 0.5 + PI * float(i) / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(ctr + Vector2(cos(ang), sin(ang)) * rr)
	c.draw_colored_polygon(pts, color)


# the result page's star row: same size and place everywhere (centre cx, 10 px below the body top)
static func stars(c: CanvasItem, cx: float, body_top: float, n: int) -> void:
	for i in 3:
		star(c, Vector2(cx - 24.0 + 24.0 * float(i), body_top + 10.0), 9.0, GOLD if i < n else SOFT)


# where a page panel sits: centred, below the status row at the top of the screen
static func panel_rect(size: Vector2, w: float, h: float) -> Rect2:
	var pw := minf(size.x - 8.0, w)
	var ph := minf(size.y - 14.0, h)
	return Rect2(floorf((size.x - pw) * 0.5), 14.0 + floorf((size.y - 14.0 - ph) * 0.5), pw, ph)


# a page: border, fill, header bar with the title (and a right-aligned note); returns the body rect
# (4 px margins, below the header, above the footer hint line)
static func panel(c: CanvasItem, r: Rect2, title: String, note := "", alpha := 1.0) -> Rect2:
	c.draw_rect(Rect2(r.position - Vector2.ONE, r.size + Vector2(2, 2)), Color(INK, minf(1.0, alpha + 0.1)))
	c.draw_rect(r, Color(PANEL, alpha))
	TextSize.edge(c, r)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, HEAD_H)), HEAD)
	text(c, title, r.position.x + 3.0, r.position.y + 2.0, WHITE)
	if note != "":
		right(c, note, r.end.x - 3.0, r.position.y + 2.0, Color("ffd6d0"))
	return Rect2(
		r.position.x + MARGIN, r.position.y + 12.0, r.size.x - 2.0 * MARGIN, r.size.y - 12.0 - 9.0
	)


# the footer hint line of a page
static func footer(c: CanvasItem, r: Rect2, hint: String) -> void:
	var lines := fit_lines(hint, r.size.x - 6.0)  # R42 LARGE: a hint wider than the panel breaks, upward from the footer line
	for i in lines.size():
		PadGlyphs.draw(c, str(lines[i]), Vector2(r.position.x + 3.0, r.end.y - 7.0 - 8.0 * float(lines.size() - 1 - i)), MUTED)


# a one-line HUD strip: the same dark bar with a blue accent along its top; returns the text origin
static func strip(c: CanvasItem, r: Rect2) -> Vector2:
	c.draw_rect(r, Color(DARK, TextSize.plate(DARK.a)))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), HEAD)
	return Vector2(r.position.x + 4.0, r.position.y + 3.0)


# a HUD box (the karaoke lanes, the keypad entry): same dark fill and accent as a strip
static func box(c: CanvasItem, r: Rect2) -> void:
	c.draw_rect(r, Color(DARK, TextSize.plate(DARK.a)))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), HEAD)


# the control hint line at the very bottom of the screen in a room (same words as a page footer)
static func hint_bar(c: CanvasItem, size: Vector2, hint: String) -> void:
	var lines := fit_lines(hint, size.x - 8.0)
	var h := HINT_H + 8.0 * float(lines.size() - 1)
	hint_extra = h - HINT_H
	hint_frame = Engine.get_process_frames()
	var r := Rect2(0.0, size.y - h, size.x, h)
	c.draw_rect(r, Color(0.02, 0.02, 0.05, TextSize.plate(0.92)))
	for i in lines.size():
		PadGlyphs.draw(c, str(lines[i]), Vector2(4.0, r.position.y + 2.0 + 8.0 * float(i)), SOFT)


# R42 LARGE: a hint wider than the screen breaks at its spaces (what PadGlyphs measures, so a pad's glyphs count right)
static func fit_lines(s: String, max_w: float) -> Array:
	if float(PadGlyphs.width(s)) <= max_w:
		return [s]
	var out := []
	var line := ""
	for word in s.split(" "):
		var next: String = word if line == "" else line + " " + word
		if line != "" and float(PadGlyphs.width(next)) > max_w:
			out.append(line)
			line = word
		else:
			line = next
	out.append(line)
	return out


# the caption bar sits above the hint line; returns its top edge (the HUD strip goes above it)
static func caption_bar(c: CanvasItem, size: Vector2, cap: String) -> float:
	var top := size.y - HINT_H - (hint_extra if hint_frame == Engine.get_process_frames() else 0.0)
	if cap == "":
		return top
	var lines := wrap_text(cap, int((size.x - 2.0 * MARGIN - 8.0) / 4.0))
	var h := float(lines.size()) * 7.0 + 4.0
	top -= h
	c.draw_rect(Rect2(0.0, top, size.x, h), Color(DARK, TextSize.plate(DARK.a)))
	c.draw_rect(Rect2(0.0, top, 2.0, h), GOLD)
	for i in lines.size():
		PadGlyphs.draw(c, str(lines[i]), Vector2(6.0, top + 2.0 + float(i) * 7.0), WHITE, 1, true)  # R42: the talk and outing captions
	return top
