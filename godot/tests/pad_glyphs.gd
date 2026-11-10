extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# Pad glyph sprites and the touch overlay's art (roadmap R14; scripts/pad_glyphs.gd, tools/make_icons.lua): the atlas is
# there and cut the way the script assumes, a hint line splits into text and glyphs, widths follow, drawing a line with
# glyphs on a canvas raises nothing, without a pad the line is the plain pixel font, and the overlay's four sprites load.

var PadGlyphs: Script
var PixelFont: Script
var failures := 0
var drawn := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	PadGlyphs = load("res://scripts/pad_glyphs.gd")
	PixelFont = load("res://scripts/pixelfont.gd")
	var controls := root.get_node("Controls")

	# ---- the atlas
	var tex: Texture2D = PadGlyphs.atlas()
	_check(tex != null and Vector2i(tex.get_size()) == Vector2i(132, 7), "the atlas is 132 x 7 (12 cells of 11 x 7)")
	_check(PadGlyphs.NAMES.size() == 12 and PadGlyphs.WIDTHS.size() == 12, "12 glyphs, each with a width")
	var img := tex.get_image()
	var cells_ok := true
	for i in 12:
		var w := int(PadGlyphs.WIDTHS[i])
		var inside := 0
		var outside := 0
		for y in 7:
			for x in 11:
				if img.get_pixel(i * 11 + x, y).a > 0.5:
					if x < w:
						inside += 1
					else:
						outside += 1
		if inside < 20 or outside > 0:
			cells_ok = false
			print("     cell %d (%s): %d px inside its width, %d outside" % [i, PadGlyphs.NAMES[i], inside, outside])
	_check(cells_ok, "every cell holds a glyph inside its width")
	var token_ok := true
	for token in PadGlyphs.TOKENS:
		token_ok = token_ok and PadGlyphs.NAMES.has(PadGlyphs.TOKENS[token])
	for button in 15:  # every name Controls prints for a pad button has a glyph, but GUIDE
		var bn: String = controls.button_name(button)
		if bn != "GUIDE" and not PadGlyphs.TOKENS.has("(%s)" % bn):
			token_ok = false
			print("     no glyph for (%s)" % bn)
	_check(token_ok, "every token names a glyph, every pad button Controls names has a token")

	# ---- cutting a line
	PadGlyphs.force = 1
	_check(PadGlyphs.parts("(A) PICK  (B) BACK") == [0, " PICK  ", 1, " BACK"], "(A) PICK  (B) BACK: %s" % str(PadGlyphs.parts("(A) PICK  (B) BACK")))
	_check(PadGlyphs.parts("STICK = MOVE  (RB) NEXT") == [10, " = MOVE  ", 5, " NEXT"], "STICK and (RB): %s" % str(PadGlyphs.parts("STICK = MOVE  (RB) NEXT")))
	_check(PadGlyphs.parts("A MEMORY STICKS OUT") == ["A MEMORY STICKS OUT"], "STICK inside a word stays text")
	_check(PadGlyphs.parts("PLAIN TEXT (SEATED)") == ["PLAIN TEXT (SEATED)"], "other brackets stay text")
	_check(PadGlyphs.width("(A) OK") == 8 + 3 * 4 - 1, "width of (A) OK with a glyph: %d" % PadGlyphs.width("(A) OK"))
	_check(PadGlyphs.width("(LT)") == 11 and PadGlyphs.width("OK") == PixelFont.width("OK"), "a lone glyph is its width, plain text is the font's")
	PadGlyphs.force = 0
	_check(PadGlyphs.width("(A) OK") == PixelFont.width("(A) OK"), "glyphs off: the plain font width")
	PadGlyphs.force = -1
	controls.pad_active = false
	_check(not PadGlyphs.active(), "no pad in use: off")
	controls.pad_active = true
	_check(PadGlyphs.active(), "a pad in use: on")
	_check(controls.hint("ENTER = OK  ESC = BACK") == "(A) = OK  (B) = BACK", "the hint Controls writes on a pad: %s" % controls.hint("ENTER = OK  ESC = BACK"))
	_check(PadGlyphs.parts(controls.hint("ENTER = OK  ESC = BACK")) == [0, " = OK  ", 1, " = BACK"], "and it cuts into glyphs")

	# ---- drawing: a canvas in the tree draws a line with every glyph, at 1x and 2x
	var canvas := Node2D.new()
	root.add_child(canvas)
	canvas.draw.connect(func() -> void:
		PadGlyphs.draw(canvas, "(A) (B) (X) (Y) (LB) (RB) (LT) (RT) (START) (BACK) STICK (UP) OK", Vector2(4, 4), Color.WHITE)
		PadGlyphs.draw(canvas, "(A) OK", Vector2(4, 20), Color.WHITE, 2)
		for id in PadGlyphs.NAMES:
			PadGlyphs.glyph(canvas, id, Vector2(4, 40))
		drawn += 1
	)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	_check(drawn >= 1, "a line with all the glyphs draws")
	controls.pad_active = false
	canvas.queue_free()

	# ---- the touch overlay's sprites
	var sizes := {"stick": Vector2i(46, 46), "knob": Vector2i(19, 19), "round": Vector2i(24, 24), "pill": Vector2i(26, 19)}
	var touch_ok := true
	for id in sizes:
		var path := "res://assets/ui/touch_%s.png" % id
		var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
		touch_ok = touch_ok and t != null and Vector2i(t.get_size()) == sizes[id]
	_check(touch_ok, "the touch overlay's stick, knob and two button faces load at their sizes")
	controls.touch_override = 1
	controls.touch_refresh()
	await process_frame
	await process_frame
	var overlay: Node = controls.touch
	_check(overlay != null and overlay.art("stick") != null and overlay.art("pill") != null and overlay.art("nothing") == null, "the overlay finds its sprites (and a missing one is null)")
	controls.touch_override = 0
	controls.touch_refresh()

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
