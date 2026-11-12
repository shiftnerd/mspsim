extends "res://tests/layout_audit.gd"
# gdlint:disable=max-line-length
# Perf measurement over the screens of the layout audit (a measurement, not a regression test; needs a renderer):
#   Godot --path godot -s res://tests/perf_screens.gd [-- --samples=100] [-- --match=computer,card]
#   PIXELFONT_NOCACHE=1 Godot ...   the old path (one draw_rect per lit pixel), for the "before" numbers
# It walks the "deck" format pages of tests/layout_audit.gd's floor phase (this script extends it), and on every page it
# forces a full repaint (queue_redraw on every visible CanvasItem) SAMPLES times and prints, per page:
#   PERF <tag> | rects <draw_rect calls of the font per repaint> | tex <draw_texture calls of the font> | cmds <both> | ms <median repaint frame>
# The counts are deterministic (the metric); the time is the median of the samples (frame to frame with vsync off, so it
# includes one frame of scripts). Run before and after interleaved for a fair time.

var samples := 100
var match_tags: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):
			samples = int(arg.substr(10))
		elif arg.begins_with("--match="):
			match_tags = arg.substr(8).split(",")
	only = PackedStringArray(["floor"])
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _walk(["deck"])
	print("PERFDONE cache=%s screens=%d" % [PixelFont.cache_on, screens])
	quit(0)


func _items(node: Node, out: Array) -> void:
	if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
		out.append(node)
	for ch in node.get_children():
		_items(ch, out)


func _end(tag: String) -> void:
	await super._end(tag)
	var ok := match_tags.is_empty()
	for m in match_tags:
		if tag.contains(m):
			ok = true
	if not ok:
		return
	var items := []
	_items(root, items)
	var times := []
	var rects := 0
	var texs := 0
	for i in samples + 5:
		for it in items:
			if is_instance_valid(it):
				it.queue_redraw()
		PixelFont.stat_rect = 0
		PixelFont.stat_tex = 0
		var t0 := Time.get_ticks_usec()
		await process_frame
		var dt := float(Time.get_ticks_usec() - t0) / 1000.0
		if i >= 5:
			times.append(dt)
			rects = PixelFont.stat_rect
			texs = PixelFont.stat_tex
	times.sort()
	print("PERF %s | rects %d | tex %d | cmds %d | ms %.3f" % [tag, rects, texs, rects + texs, times[times.size() / 2]])
