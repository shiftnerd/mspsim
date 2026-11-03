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


static func draw(canvas: CanvasItem, text: String, pos: Vector2, color: Color, scale := 1) -> void:
	var x := pos.x
	for ch in text.to_upper().replace('"', "'"):
		var rows: Array = GLYPHS.get(ch, GLYPHS["?"])
		for r in 5:
			var row: String = rows[r]
			for c in 3:
				if row[c] == "X":
					canvas.draw_rect(Rect2(x + c * scale, pos.y + r * scale, scale, scale), color)
		x += 4.0 * scale
