extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# PixelFont text cache (perf): the cached path (one draw_texture per string) must draw exactly the pixels the old path (one
# draw_rect per lit pixel) draws. NEEDS A RENDERER for the picture part: run it as
#   Godot --path godot -s res://tests/text_cache.gd            (renderer: compares both paths pixel by pixel)
# Headless (the default test run) it prints SKIP for the picture part and still checks the memory bound, which needs no drawing.
# PIXELFONT_NOCACHE=1 in the environment forces the old path everywhere (the game, tests/frame_time.gd), so a comparison of
# the whole game stays possible: this test flips PixelFont.cache_on itself and does not read it.

var PixelFont: Script
var PadGlyphs: Script
var UiStyle: Script
var failures := 0
var sub: SubViewport


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PixelFont = load("res://scripts/pixelfont.gd")
	PadGlyphs = load("res://scripts/pad_glyphs.gd")
	UiStyle = load("res://scripts/ui_style.gd")
	if DisplayServer.get_name() == "headless":
		print("SKIP pixel comparison: needs a renderer (run without --headless)")
	else:
		await _pictures()
	await _memory()
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)


# ---- the jobs: [text, position, colour, scale, pad (-1 = font only, 0 / 1 = PadGlyphs with the pad off / on)]
func _jobs_glyphs() -> Array:
	var all := ""
	for k in PixelFont.GLYPHS:
		all += str(k)
	var jobs := []
	jobs.append([all, Vector2(2, 2), Color("17121f"), 1, -1])
	jobs.append([all.substr(0, 30), Vector2(2, 10), Color("ffd6d0"), 2, -1])
	jobs.append([all.substr(0, 22), Vector2(2, 24), Color(1, 0.5, 0.2, 0.5), 3, -1])
	jobs.append(["the quick brown fox \"jumps\" over {unknown} ~ lazy dogs", Vector2(2, 44), Color.WHITE, 1, -1])  # lower case, quotes, glyphs with no entry
	jobs.append(["SHADOW", Vector2(11, 61), Color(0, 0, 0, 0.6), 1, -1])
	jobs.append(["SHADOW", Vector2(10, 60), Color.WHITE, 1, -1])
	jobs.append(["HALF PIXEL", Vector2(10.5, 70.5), Color("e0a030"), 1, -1])
	jobs.append(["HALF PIXEL", Vector2(10.5, 78.0), Color("e0a030"), 2, -1])
	jobs.append(["", Vector2(3, 3), Color.WHITE, 1, -1])
	jobs.append(["   ", Vector2(3, 3), Color.WHITE, 1, -1])
	return jobs


func _jobs_wrap() -> Array:
	var jobs := []
	var lines: Array = UiStyle.wrap_text("A WRAPPED LINE OF STORY TEXT THAT RUNS ON AND ON WITH NUMBERS 12345 AND A COMMA, AND ENDS.", 24)
	for i in lines.size():
		jobs.append([str(lines[i]), Vector2(4, 4 + 7 * i), Color("46506a"), 1, -1])
	var cx := 160.0
	var s := "CENTERED"
	jobs.append([s, Vector2(cx - float(PixelFont.width(s, 1)) * 0.5, 50), Color.WHITE, 1, -1])
	jobs.append(["RIGHT ALIGNED 2", Vector2(310.0 - float(PixelFont.width("RIGHT ALIGNED 2", 1)), 58), Color.WHITE, 1, -1])
	# clipped: runs off the right edge and starts left of the viewport
	jobs.append(["CLIPPED AT THE RIGHT EDGE OF THE VIEWPORT AND BEYOND", Vector2(200, 70), Color("c9d2e0"), 1, -1])
	jobs.append(["CLIPPED AT THE LEFT EDGE", Vector2(-30, 80), Color("c9d2e0"), 1, -1])
	jobs.append(["CLIPPED BOTTOM", Vector2(5, 197), Color("c9d2e0"), 1, -1])
	return jobs


func _jobs_tokens(pad: int) -> Array:
	var jobs := []
	jobs.append(["(A) PICK  (B) BACK  STICK = MOVE", Vector2(4, 4), Color("c9d2e0"), 1, pad])
	jobs.append(["(LB) PREV (RB) NEXT (START) MENU (BACK) MAP", Vector2(4, 16), Color.WHITE, 1, pad])
	jobs.append(["PRESS {E} TO TALK, {SPACE} TO JUMP, {Q} TO DROP", Vector2(4, 28), Color.WHITE, 1, pad])
	jobs.append(["PRESS {E} TO TALK", Vector2(4, 40), Color.WHITE, 2, pad])
	jobs.append(["A SENTENCE (A) WITH A BUTTON AND (NOTHING) ELSE", Vector2(4, 56), Color.WHITE, 1, -1])  # through the font's own pad route
	jobs.append(["NO BUTTONS HERE AT ALL (HONEST)", Vector2(4, 66), Color.WHITE, 1, -1])
	jobs.append(["(RS UP) AND RS UP IN A LINE", Vector2(4, 76), Color.WHITE, 3, pad])
	return jobs


func _draw_jobs(c: Control, jobs: Array) -> void:
	for j in jobs:
		var pad: int = j[4]
		if pad >= 0:
			PadGlyphs.draw(c, j[0], j[1], j[2], j[3], true)
		else:
			PixelFont.draw(c, j[0], j[1], j[2], j[3])


# one picture of the jobs: a Control in a SubViewport, drawn with the cache on or off
func _render(jobs: Array, cached: bool, pad: int, xform: Transform2D, clip: bool) -> Image:
	PixelFont.cache_on = cached
	PadGlyphs.force = pad
	PixelFont.stat_rect = 0
	PixelFont.stat_tex = 0
	sub = SubViewport.new()
	sub.size = Vector2i(320, 200)
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	sub.canvas_transform = xform
	var c := Control.new()
	c.size = Vector2(320, 200)
	c.clip_contents = clip
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, 0, 320, 200), Color("2b3550"))
		c.draw_rect(Rect2(0, 0, 160, 200), Color(0.9, 0.9, 0.95, 0.8))  # text over two backgrounds, with a half-transparent one
		_draw_jobs(c, jobs)
	)
	sub.add_child(c)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	sub.queue_free()
	await process_frame
	return img


func _same(name: String, jobs: Array, pad := -1, xform := Transform2D.IDENTITY, clip := false) -> void:
	PixelFont.clear_cache()
	var old_img: Image = await _render(jobs, false, pad, xform, clip)
	var old_rects: int = PixelFont.stat_rect
	var new_img: Image = await _render(jobs, true, pad, xform, clip)
	var tex_calls: int = PixelFont.stat_tex
	var diff := 0
	var first := Vector2i(-1, -1)
	if old_img.get_size() != new_img.get_size():
		diff = -1
	else:
		var a := old_img.get_data()
		var b := new_img.get_data()
		for i in a.size() / 4:
			var o := i * 4
			if a[o] != b[o] or a[o + 1] != b[o + 1] or a[o + 2] != b[o + 2] or a[o + 3] != b[o + 3]:
				diff += 1
				if first.x < 0:
					first = Vector2i(i % old_img.get_width(), i / old_img.get_width())
	# a picture of nothing would pass trivially: the text must have put pixels on the background
	var lit := 0
	var bg := Color("2b3550")
	for y in range(0, 200, 1):
		for x in range(160, 320):
			if old_img.get_pixel(x, y).is_equal_approx(bg) == false:
				lit += 1
	_check(diff == 0, "%s: both paths draw the same pixels (%d differ%s; old path %d draw_rect, new path %d draw_texture)" % [name, diff, "" if diff <= 0 else ", first at %s" % str(first), old_rects, tex_calls])
	_check(lit > 0 or name.begins_with("clipped"), "%s: the picture is not empty" % name)


func _pictures() -> void:
	DisplayServer.window_set_size(Vector2i(640, 400))
	await _dashboards()
	await _same("every glyph, sizes 1 to 3, shadows, half pixels", _jobs_glyphs())
	await _same("wrapped, centred, right aligned, clipped", _jobs_wrap(), -1, Transform2D.IDENTITY, true)
	await _same("wrapped without clip_contents", _jobs_wrap())
	await _same("tokens, pad off", _jobs_tokens(0), 0)
	await _same("tokens, pad on", _jobs_tokens(1), 1)
	await _same("font only, pad forced on (the font's own glyph route)", _jobs_tokens(-1), 1)
	await _same("a camera offset of a fraction of a pixel", _jobs_glyphs(), -1, Transform2D(0.0, Vector2(0.5, 0.25)))
	await _same("an integer camera offset", _jobs_glyphs(), -1, Transform2D(0.0, Vector2(-7, 3)))
	await _same("a scaled canvas (falls back to the old path)", _jobs_glyphs(), -1, Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2.ZERO))
	# the switch: one cache, the pad turned on and off between draws; the cache must give the same picture as the old path each time
	PixelFont.clear_cache()
	var seq := [0, 1, 0, 1]
	for p in seq:
		var jobs := _jobs_tokens(p)
		var old_img: Image = await _render(jobs, false, p, Transform2D.IDENTITY, false)
		var new_img: Image = await _render(jobs, true, p, Transform2D.IDENTITY, false)  # (cache kept across these runs)
		_check(old_img.get_data() == new_img.get_data(), "device switch to pad=%d: same picture with a warm cache" % p)
	PadGlyphs.force = -1
	PixelFont.cache_on = PixelFont._default_on()


# the metrics board: its LED digits are cached geometry drawn with draw_primitive; the slow path is the original code
func _dash_image(rect: Rect2, mode: String, tm: float, cozy: bool, fast: bool) -> Image:
	var dash: Script = _dash_script()
	dash.fast_digits = fast
	PixelFont.cache_on = fast
	sub = SubViewport.new()
	sub.size = Vector2i(320, 200)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	var c := Control.new()
	c.size = Vector2(320, 200)
	c.draw.connect(func() -> void: dash.paint(c, rect, mode, tm, {"cozy": cozy}))
	sub.add_child(c)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	sub.queue_free()
	await process_frame
	return img


func _dashboards() -> void:
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_%d_textcache_" % OS.get_process_id()
	var bad := 0
	var n := 0
	for mode in ["tech", "owner", "sales", "service"]:
		camp.new_game(mode)
		for rect in [Rect2(0, 0, 320, 200), Rect2(0, 0, 200, 200), Rect2(0, 0, 150, 200), Rect2(7, 5, 300, 190)]:
			for tm in [0.3, 2.0]:
				for cozy in [false, true]:
					var a: Image = await _dash_image(rect, mode, tm, cozy, false)
					var b: Image = await _dash_image(rect, mode, tm, cozy, true)
					n += 1
					if a.get_data() != b.get_data():
						bad += 1
						print("  dashboard differs: %s %s t=%s cozy=%s" % [mode, rect, tm, cozy])
	_check(bad == 0, "metrics dashboard, %d boards (4 modes, 4 sizes, 2 times, cozy on / off): the cached digits draw the same pixels (%d differ)" % [n, bad])
	_dash_reset()


func _dash_reset() -> void:
	_dash_script().fast_digits = true
	PixelFont.cache_on = PixelFont._default_on()


# ---- memory: after twenty days of text the cache is still bounded
func _memory() -> void:
	PixelFont.clear_cache()
	var words := ["TICKET", "PRINTER", "OUTAGE", "CLIENT", "PASSWORD", "RESET", "BACKUP", "SERVER", "DENTAL", "OFFICE", "RMM", "LAPTOP", "COFFEE"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	var peak_n := 0
	var peak_bytes := 0
	var strings := 0
	var frames := 0
	for day in 20:
		for minute in 24 * 60:
			# one game minute of text: the clock, the money, a ticket counter, the sort of lines a board prints
			var batch := ["DAY %d  %02d:%02d" % [day + 1, minute / 60, minute % 60], "$%d" % (1000 + day * 311 + minute), "OPEN %d" % (minute % 37), "REP %d" % (50 + day)]
			for i in 6:
				batch.append("%s %s %d" % [words[rng.randi() % words.size()], words[rng.randi() % words.size()], rng.randi() % 900])
			for s in batch:
				var tex = PixelFont.texture(str(s), 1)
				strings += 1
				if tex == null:
					failures += 1
			if minute % 4 == 0:
				await process_frame  # a frame: eviction only happens between frames
				frames += 1
			peak_n = maxi(peak_n, PixelFont.cache_entries())
			peak_bytes = maxi(peak_bytes, PixelFont.cache_bytes())
	var max_n: int = 2 * PixelFont.CACHE_ENTRIES + 64
	var max_bytes: int = 2 * PixelFont.CACHE_BYTES + 65536
	print("memory: %d strings in %d frames, %d built, %d hits; peak %d entries, %d bytes" % [strings, frames, PixelFont.stat_miss, PixelFont.stat_hit, peak_n, peak_bytes])
	_check(peak_n <= max_n, "the cache stays under %d entries (peak %d)" % [max_n, peak_n])
	_check(peak_bytes <= max_bytes, "the cache stays under %d bytes (peak %d)" % [max_bytes, peak_bytes])
	_check(PixelFont.stat_hit > 0, "the repeated strings are hits (%d of %d)" % [PixelFont.stat_hit, strings])
	# big strings and scales count by their real size
	var before: int = PixelFont.cache_bytes()
	PixelFont.texture("X".repeat(100), 3)
	_check(PixelFont.cache_bytes() - before == (100 * 12 - 3) * 15 * 4, "bytes are counted as RGBA width x height")
	PixelFont.clear_cache()
	_check(PixelFont.cache_entries() == 0 and PixelFont.cache_bytes() == 0, "clear_cache empties it")


func _dash_script() -> Script:
	return load("res://scripts/dashboard.gd")
