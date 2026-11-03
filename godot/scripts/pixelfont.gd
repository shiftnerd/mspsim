extends RefCounted
# gdlint: ignore=max-line-length
# A 3x5 pixel font for the in-game computer and phone screens (upper case only, like the logo tagline).
# PixelFont.draw(canvas_item, text, position, color, scale) / PixelFont.width(text, scale)

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


static func draw(canvas: CanvasItem, text: String, pos: Vector2, color: Color, scale := 1) -> void:
	# only screen-space UI (inside a CanvasLayer, or the root's own canvas): world-space fx are out of view by design
	if audit != null and text.strip_edges() != "" and color.a > 0.05 and canvas.get_canvas_layer_node() != null:
		var tf := canvas.get_global_transform_with_canvas()
		var sz := Vector2(width(text.strip_edges(), scale), 5 * scale)
		var lead := float(text.length() - text.lstrip(" ").length()) * 4.0 * scale
		audit.append({
			"canvas": "%s/%s" % [canvas.get_class(), canvas.name],
			"cid": canvas.get_instance_id(),
			"frame": Engine.get_frames_drawn(),
			"text": text.strip_edges(),
			"rect": tf * Rect2(pos + Vector2(lead, 0), sz),
			"vp": canvas.get_viewport().get_visible_rect(),
		})
	var x := pos.x
	for ch in text.to_upper().replace('"', "'"):
		var rows: Array = GLYPHS.get(ch, GLYPHS["?"])
		for r in 5:
			var row: String = rows[r]
			for c in 3:
				if row[c] == "X":
					canvas.draw_rect(Rect2(x + c * scale, pos.y + r * scale, scale, scale), color)
		x += 4.0 * scale
