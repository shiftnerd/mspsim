extends RefCounted
# gdlint:disable=max-line-length
# Pad button glyphs (roadmap R14): a hint line says "(A) PICK  (B) BACK  STICK = MOVE" on a pad (Controls.hint / label).
# draw() prints such a line with the pixel font and puts a small sprite where a pad token stands, width() measures it.
# The atlas is assets/ui/pad_glyphs.png (tools/make_icons.lua, source office/pieces/ui_pad_glyphs.aseprite): 12 cells of
# 11 x 7, the font's five rows plus one above and one below. Without a pad in use (or without the atlas) both functions
# are the plain PixelFont ones, so a caller can use them for every line.
# Used by: the HUD hint (hud.gd), every panel footer (UiStyle.footer) and the pause menu's key lists.

const PixelFont := preload("res://scripts/pixelfont.gd")
const ATLAS := "res://assets/ui/pad_glyphs.png"
const CELL := Vector2(11.0, 7.0)
const NAMES := ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "START", "BACK", "STICK", "DPAD"]
const WIDTHS := [7, 7, 7, 7, 11, 11, 11, 11, 7, 7, 7, 7]
# what a hint line may hold -> the glyph. The buttons stand in brackets; STICK is a bare word
const TOKENS := {
	"(A)": "A", "(B)": "B", "(X)": "X", "(Y)": "Y", "(LB)": "LB", "(RB)": "RB", "(LT)": "LT", "(RT)": "RT",
	"(START)": "START", "(BACK)": "BACK", "STICK": "STICK", "(L3)": "STICK", "(R3)": "STICK",
	"(UP)": "DPAD", "(DOWN)": "DPAD", "(LEFT)": "DPAD", "(RIGHT)": "DPAD",
}

static var force := -1  # tests: 1 = glyphs on, 0 = off, -1 = follow Controls.pad_active
static var _tex: Texture2D
static var _looked := false


static func atlas() -> Texture2D:
	if not _looked:
		_looked = true
		_tex = load(ATLAS) if ResourceLoader.exists(ATLAS) else null
	return _tex


static func active() -> bool:
	if atlas() == null:
		return false
	if force >= 0:
		return force == 1
	# the autoload by path: this script is preloaded by UiStyle, which test scripts compile before the autoloads exist
	var tree := Engine.get_main_loop() as SceneTree
	var controls: Node = tree.root.get_node_or_null("Controls") if tree != null else null
	return controls != null and bool(controls.pad_active)


# the line cut into pieces: a String is text, an int is a glyph index
static func parts(text: String) -> Array:
	var out := []
	var rest := text.to_upper()
	while rest != "":
		var at := -1
		var hit := ""
		for token in TOKENS:
			var i := rest.find(token)
			# STICK only as a whole word
			if i >= 0 and token == "STICK" and ((i > 0 and rest[i - 1] != " ") or (i + 5 < rest.length() and not rest[i + 5] in [" ", ",", "."])):
				i = -1
			if i >= 0 and (at < 0 or i < at):
				at = i
				hit = token
		if at < 0:
			out.append(rest)
			break
		if at > 0:
			out.append(rest.substr(0, at))
		out.append(NAMES.find(str(TOKENS[hit])))
		rest = rest.substr(at + hit.length())
	return out


static func width(text: String, scale := 1) -> int:
	if not active():
		return PixelFont.width(text, scale)
	var w := 0
	for part in parts(text):
		w += (int(WIDTHS[part]) + 1) * scale if part is int else str(part).length() * 4 * scale
	return maxi(0, w - scale)


# one glyph by name at its top-left corner (a 7 px cell: one row above the text line's top)
static func glyph(canvas: CanvasItem, id: String, pos: Vector2, scale := 1) -> void:
	var i := NAMES.find(id)
	if i < 0 or atlas() == null:
		return
	var w := float(WIDTHS[i])
	canvas.draw_texture_rect_region(atlas(), Rect2(pos, Vector2(w, CELL.y) * float(scale)), Rect2(CELL.x * float(i), 0.0, w, CELL.y))


static func draw(canvas: CanvasItem, text: String, pos: Vector2, color: Color, scale := 1) -> void:
	if not active():
		PixelFont.draw(canvas, text, pos, color, scale)
		return
	var x := pos.x
	for part in parts(text):
		if part is int:
			glyph(canvas, str(NAMES[part]), Vector2(x, pos.y - float(scale)), scale)
			x += float((int(WIDTHS[part]) + 1) * scale)
		else:
			PixelFont.draw(canvas, str(part), Vector2(x, pos.y), color, scale)
			x += float(str(part).length() * 4 * scale)
