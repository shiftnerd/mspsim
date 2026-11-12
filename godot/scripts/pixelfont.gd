extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# A 3x5 pixel font for the in-game computer and phone screens (upper case only, like the logo tagline).
# PixelFont.draw(canvas_item, text, position, color, scale) / PixelFont.width(text, scale)
#
# TEXT CACHE (perf, handhelds). draw() used to issue one draw_rect per lit glyph pixel (hundreds of canvas commands for a
# screen of text). Now each distinct (resolved text, scale) is built ONCE into a white RGBA ImageTexture from the same glyph
# data and drawn with ONE draw_texture(tex, pos, color): the colour is the modulate, so every colour (and the shadow copy,
# drawn a second time at an offset) shares one texture. The output is pixel-identical (tests/text_cache.gd compares both paths).
# Interface for callers (small on purpose; a text size setting should only need `scale`):
#   PixelFont.draw(canvas, text, pos, color, scale)   unchanged; scale is an int >= 1 and part of the cache key
#   PixelFont.width(text, scale)                      unchanged
#   PixelFont.cache_on                                false = the old draw_rect path (env PIXELFONT_NOCACHE=1 forces it; headless
#                                                     runs are off by default, env PIXELFONT_CACHE=1 turns it on there)
#   PixelFont.texture(text, scale) -> Texture2D       the cached white texture (the same one draw() uses), for the tests
#   PixelFont.cache_entries() / cache_bytes()         what the cache holds now (bounded: see CACHE_ENTRIES / CACHE_BYTES)
#   PixelFont.stat_rect / stat_tex / stat_hit / stat_miss   counters for tests/frame_time.gd (draw_rect calls the font issued,
#                                                     draw_texture calls, cache hits, builds); reset by assigning 0
# The key is the text AFTER key-token and pad-glyph resolution (keys() and _pad_line() run before the cache), so a device switch
# needs no invalidation: the pad sprites stay inline (PadGlyphs) and only their plain text pieces come here.
# The cache is two generations of dictionaries (scale -> {text -> texture}); when the current one is full it becomes the old
# one and the old one is dropped (a hit in the old one is promoted). A canvas item keeps a reference to the textures of its
# latest redraw (meta "_pf"), so an item that is not redrawn for a long time never loses its text to an eviction. Text under a
# canvas transform that is not a plain translation falls back to draw_rect (snapping would differ).

const GLYPHS := {
	"A": ["XXX", "X.X", "XXX", "X.X", "X.X"],
	"B": ["XX.", "X.X", "XX.", "X.X", "XX."],
	"C": [".XX", "X..", "X..", "X..", ".XX"],
	"D": ["XX.", "X.X", "X.X", "X.X", "XX."],
	"E": ["XXX", "X..", "XX.", "X..", "XXX"],
	"F": ["XXX", "X..", "XX.", "X..", "X.."],
	"G": [".XX", "X..", "X.X", "X.X", ".XX"],
	"H": ["X.X", "X.X", "XXX", "X.X", "X.X"],
	"I": ["XXX", ".X.", ".X.", ".X.", "XXX"],
	"J": ["..X", "..X", "..X", "X.X", ".X."],
	"K": ["X.X", "X.X", "XX.", "X.X", "X.X"],
	"L": ["X..", "X..", "X..", "X..", "XXX"],
	"M": ["X.X", "XXX", "XXX", "X.X", "X.X"],
	"N": ["XXX", "X.X", "X.X", "X.X", "X.X"],
	"O": [".X.", "X.X", "X.X", "X.X", ".X."],
	"P": ["XX.", "X.X", "XX.", "X..", "X.."],
	"Q": [".X.", "X.X", "X.X", "XX.", ".XX"],
	"R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
	"S": [".XX", "X..", ".X.", "..X", "XX."],
	"T": ["XXX", ".X.", ".X.", ".X.", ".X."],
	"U": ["X.X", "X.X", "X.X", "X.X", "XXX"],
	"V": ["X.X", "X.X", "X.X", "X.X", ".X."],
	"W": ["X.X", "X.X", "XXX", "XXX", "X.X"],
	"X": ["X.X", "X.X", ".X.", "X.X", "X.X"],
	"Y": ["X.X", "X.X", ".X.", ".X.", ".X."],
	"Z": ["XXX", "..X", ".X.", "X..", "XXX"],
	"0": ["XXX", "X.X", "X.X", "X.X", "XXX"],
	"1": [".X.", "XX.", ".X.", ".X.", "XXX"],
	"2": ["XX.", "..X", ".X.", "X..", "XXX"],
	"3": ["XX.", "..X", ".X.", "..X", "XX."],
	"4": ["X.X", "X.X", "XXX", "..X", "..X"],
	"5": ["XXX", "X..", "XX.", "..X", "XX."],
	"6": [".XX", "X..", "XXX", "X.X", "XXX"],
	"7": ["XXX", "..X", ".X.", ".X.", ".X."],
	"8": ["XXX", "X.X", "XXX", "X.X", "XXX"],
	"9": ["XXX", "X.X", "XXX", "..X", "XX."],
	".": ["...", "...", "...", "...", ".X."],
	",": ["...", "...", "...", ".X.", "X.."],
	":": ["...", ".X.", "...", ".X.", "..."],
	";": ["...", ".X.", "...", ".X.", "X.."],
	"!": [".X.", ".X.", ".X.", "...", ".X."],
	"?": ["XX.", "..X", ".X.", "...", ".X."],
	"-": ["...", "...", "XXX", "...", "..."],
	"_": ["...", "...", "...", "...", "XXX"],
	"/": ["..X", "..X", ".X.", "X..", "X.."],
	"(": [".X.", "X..", "X..", "X..", ".X."],
	")": [".X.", "..X", "..X", "..X", ".X."],
	"'": [".X.", ".X.", "...", "...", "..."],
	"@": [".XX", "X.X", "XXX", "X..", ".XX"],
	"#": ["X.X", "XXX", "X.X", "XXX", "X.X"],
	"%": ["X.X", "..X", ".X.", "X..", "X.X"],
	"&": [".X.", "X.X", ".X.", "X.X", ".XX"],
	"+": ["...", ".X.", "XXX", ".X.", "..."],
	"=": ["...", "XXX", "...", "XXX", "..."],
	"*": ["...", "X.X", ".X.", "X.X", "..."],
	"<": ["..X", ".X.", "X..", ".X.", "..X"],
	">": ["X..", ".X.", "..X", ".X.", "X.."],
	"[": ["XX.", "X..", "X..", "X..", "XX."],
	"]": [".XX", "..X", "..X", "..X", ".XX"],
	"|": [".X.", ".X.", ".X.", ".X.", ".X."],
	"$": [".XX", "XX.", ".X.", ".XX", "XX."],
	" ": ["...", "...", "...", "...", "..."],
}


static func width(text: String, scale := 1) -> int:
	return maxi(0, text.length() * 4 * scale - scale)


# Layout audit hook (tests/layout_audit.gd, Game._process with env LAYOUT_AUDIT=1): while non-null, every draw call
# is logged with its rect in viewport pixels. audit_report() returns the problems and clears the log.
static var audit = null
static var _audit_seen := {}


static func audit_report(fmt := "", overlaps := false) -> Array:
	var out := []
	var all: Array = audit
	audit = []
	var latest := {}  # per canvas only its newest redraw counts: older frames belong to a screen that was replaced
	for rec in all:
		latest[rec.cid] = maxi(int(latest.get(rec.cid, 0)), int(rec.frame))
	var recs := all.filter(func(rec: Dictionary) -> bool: return rec.frame == latest[rec.cid])
	for rec in recs:
		var r: Rect2 = rec.rect
		var vp: Rect2 = rec.vp
		if vp.grow_individual(0.01, 0.01, 0.01, 0.01).encloses(r):
			continue
		var line := "OFFSCREEN %s %s '%s' rect=%s vp=%s" % [fmt, rec.canvas, rec.text, r, vp.size]
		if not _audit_seen.has(line):
			_audit_seen[line] = true
			out.append(line)
	if overlaps:
		var by_canvas := {}
		for rec in recs:
			if not by_canvas.has(rec.cid):
				by_canvas[rec.cid] = []
			by_canvas[rec.cid].append(rec)
		for key in by_canvas:
			var list: Array = by_canvas[key]
			for i in list.size():
				for j in range(i + 1, list.size()):
					var a: Rect2 = list[i].rect
					var b: Rect2 = list[j].rect
					if list[i].text == list[j].text or a.position.is_equal_approx(b.position):
						continue
					var hit := a.intersection(b)
					if hit.size.x >= 3.0 and hit.size.y >= 3.0:
						var line := "OVERLAP %s %s '%s' x '%s' at %s" % [fmt, list[i].canvas, list[i].text, list[j].text, hit]
						if not _audit_seen.has(line):
							_audit_seen[line] = true
							out.append(line)
	return out


# R42: the {E} style key tokens of a text (Controls.keys), for whoever draws or wraps a text that may carry them. The
# autoload by path: this script is preloaded by test scripts before the autoloads exist.
static func keys(text: String) -> String:
	if text.find("{") < 0:
		return text
	var tree := Engine.get_main_loop() as SceneTree
	var controls: Node = tree.root.get_node_or_null("Controls") if tree != null else null
	return str(controls.keys(text)) if controls != null else text


# R42: with a pad in use a bracketed button in ANY text ("(A)", "(LB)", in a mail, a caption, a report) is drawn as its
# glyph: the font hands such a line to PadGlyphs (sentence mode: brackets only, a bare STICK stays a word), which calls back
# here for the plain pieces. So no screen has to remember to ask for glyphs. pad_glyphs.gd preloads this script, hence load().
static var _glyphs: Script = null
static var _in_glyphs := false
static var glyph_lines := 0  # lines this route turned into glyphs (tests/pad_prompts.gd counts them)


static func _pad_line(canvas: CanvasItem, text: String, pos: Vector2, color: Color, scale: int) -> bool:
	if _in_glyphs or text.find("(") < 0:
		return false
	if _glyphs == null:
		_glyphs = load("res://scripts/pad_glyphs.gd")
	if not _glyphs.active() or _glyphs.width(text, scale, true) == width(text, scale):
		return false  # no pad, or no button in this line
	_in_glyphs = true
	glyph_lines += 1
	_glyphs.draw(canvas, text, pos, color, scale, true)
	_in_glyphs = false
	return true


const CACHE_ENTRIES := 1500  # per generation (two are alive)
const CACHE_BYTES := 3000000  # RGBA bytes per generation
static var cache_on := _default_on()
static var stat_rect := 0
static var stat_tex := 0
static var stat_hit := 0
static var stat_miss := 0
static var _cur := {}
static var _old := {}
static var _cur_n := 0
static var _cur_bytes := 0
static var _old_n := 0
static var _old_bytes := 0
static var _rot_frame := -1
static var _glyph_imgs := {}  # scale -> {char -> Image}


static func _default_on() -> bool:
	if OS.get_environment("PIXELFONT_NOCACHE") != "":
		return false
	return OS.get_environment("PIXELFONT_CACHE") != "" or DisplayServer.get_name() != "headless"


static func cache_entries() -> int:
	return _cur_n + _old_n


static func cache_bytes() -> int:
	return _cur_bytes + _old_bytes


static func clear_cache() -> void:
	_cur = {}
	_old = {}
	_cur_n = 0
	_cur_bytes = 0
	_old_n = 0
	_old_bytes = 0


static func _glyph_image(ch: String, scale: int) -> Image:
	if not _glyph_imgs.has(scale):
		_glyph_imgs[scale] = {}
	var per: Dictionary = _glyph_imgs[scale]
	if per.has(ch):
		return per[ch]
	var img := Image.create_empty(3 * scale, 5 * scale, false, Image.FORMAT_RGBA8)
	var rows: Array = GLYPHS.get(ch, GLYPHS["?"])
	for r in 5:
		var row: String = rows[r]
		for c in 3:
			if row[c] == "X":
				img.fill_rect(Rect2i(c * scale, r * scale, scale, scale), Color.WHITE)
	per[ch] = img
	return img


static func _build(text: String, scale: int) -> ImageTexture:
	var img := Image.create_empty(width(text, scale), 5 * scale, false, Image.FORMAT_RGBA8)
	var x := 0
	for ch in text.to_upper().replace('"', "'"):
		img.blit_rect(_glyph_image(ch, scale), Rect2i(0, 0, 3 * scale, 5 * scale), Vector2i(x, 0))
		x += 4 * scale
	return ImageTexture.create_from_image(img)


static func texture(text: String, scale := 1) -> Texture2D:
	if text == "" or scale < 1:
		return null
	var d = _cur.get(scale)
	if d != null:
		var hit = d.get(text)
		if hit != null:
			stat_hit += 1
			return hit
	var od = _old.get(scale)
	var tex: ImageTexture = od.get(text) if od != null else null
	if tex == null:
		stat_miss += 1
		tex = _build(text, scale)
	else:
		stat_hit += 1
		od.erase(text)
		_old_n -= 1
		_old_bytes -= tex.get_width() * tex.get_height() * 4
	var bytes := tex.get_width() * tex.get_height() * 4
	var frame := Engine.get_process_frames()
	if (_cur_n >= CACHE_ENTRIES or _cur_bytes >= CACHE_BYTES) and frame != _rot_frame:
		_old = _cur
		_old_n = _cur_n
		_old_bytes = _cur_bytes
		_cur = {}
		_cur_n = 0
		_cur_bytes = 0
		_rot_frame = frame
	if not _cur.has(scale):
		_cur[scale] = {}
	_cur[scale][text] = tex
	_cur_n += 1
	_cur_bytes += bytes
	return tex


# true when the text was drawn as one texture. The per-canvas record is [frame, plain translation?, textures kept alive].
static func _draw_cached(canvas: CanvasItem, text: String, pos: Vector2, color: Color, scale: int) -> bool:
	var frame := Engine.get_process_frames()
	var rec = canvas.get_meta("_pf") if canvas.has_meta("_pf") else null
	if rec == null or rec[0] != frame:
		var t := canvas.get_global_transform_with_canvas()
		rec = [frame, t.x == Vector2.RIGHT and t.y == Vector2.DOWN, [], t.origin]
		canvas.set_meta("_pf", rec)
	if not rec[1]:
		return false
	var tex := texture(text, scale)
	if tex == null:
		return false
	rec[2].append(tex)
	# the old path's rects were snapped to the screen pixel one corner at a time (round half down, after the canvas offset);
	# the same snap on the texture's corner keeps a fractional position (a centred text, a camera) on the same pixels
	var o: Vector2 = rec[3]
	canvas.draw_texture(tex, (pos + o - Vector2(0.5, 0.5)).ceil() - o, color)
	stat_tex += 1
	return true


static func draw(canvas: CanvasItem, text: String, pos: Vector2, color: Color, scale := 1) -> void:
	text = keys(text)  # a token that reached the font unresolved (the wrap helpers resolve first, so the line breaks are right)
	if _pad_line(canvas, text, pos, color, scale):
		return
	# only screen-space UI (inside a CanvasLayer, or the root's own canvas): world-space fx are out of view by design
	if audit != null and text.strip_edges() != "" and color.a > 0.05 and canvas.get_canvas_layer_node() != null:
		var tf := canvas.get_global_transform_with_canvas()
		var sz := Vector2(width(text.strip_edges(), scale), 5 * scale)
		var lead := float(text.length() - text.lstrip(" ").length()) * 4.0 * scale
		audit.append({
			"canvas": "%s/%s" % [canvas.get_class(), canvas.name],
			"cid": canvas.get_instance_id(),
			"frame": Engine.get_process_frames(),  # (frames drawn stays 0 without a renderer)
			"text": text.strip_edges(),
			"rect": tf * Rect2(pos + Vector2(lead, 0), sz),
			"vp": canvas.get_viewport().get_visible_rect(),
		})
	if cache_on and text != "" and scale >= 1 and _draw_cached(canvas, text, pos, color, scale):
		return
	var x := pos.x
	for ch in text.to_upper().replace('"', "'"):
		var rows: Array = GLYPHS.get(ch, GLYPHS["?"])
		for r in 5:
			var row: String = rows[r]
			for c in 3:
				if row[c] == "X":
					canvas.draw_rect(Rect2(x + c * scale, pos.y + r * scale, scale, scale), color)
					stat_rect += 1
		x += 4.0 * scale
