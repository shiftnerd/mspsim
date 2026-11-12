extends SceneTree
# gdlint:disable=max-line-length
# R42 Steam Deck: frame time in the busiest scenes, against the 16.6 ms of a 60 fps frame. A measurement, not a
# regression test: run it with a renderer for the real numbers (window at 1280 x 800, the "deck" format, vsync off,
# no frame cap); headless it has only the engine's own worst-case monitor (no drawing).
#   Godot --path godot -s res://tests/frame_time.gd                 (renderer: scripts + drawing + the GPU)
#   Godot --headless --path godot -s res://tests/frame_time.gd      (scripts and draw callbacks only)
# Each scene runs SECS seconds of real time after a warm-up. With a renderer the time between two frames with no cap
# is the whole cost of a frame (scripts, _draw callbacks, the GPU and the swap): average, 95th percentile, worst. The
# engine's monitors (Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS) are the SLOWEST process and physics step of the
# last second, so they are a worst case, and the only number a headless run has (it sleeps between frames).
# "60 Hz frame" = the p95 frame (headless: the slowest process step) plus one physics step. Headroom = 16.6 / that.
# It exits 1 only when a scene's 60 Hz frame is over BUDGET_MS on this machine (a Deck is slower: docs/steam-deck.md).

const SECS := 4.0
const BUDGET_MS := 16.6
const PARTY := ["Alan", "Garrison", "Dan", "Maya", "John"]

var rows := []
var over := 0
var headless := false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _settle(secs: float) -> void:
	await create_timer(secs).timeout


func _stats(values: Array) -> Dictionary:
	var v := values.duplicate()
	v.sort()
	var sum := 0.0
	for x in v:
		sum += x
	return {"avg": sum / float(v.size()), "p95": v[mini(v.size() - 1, int(float(v.size()) * 0.95))], "max": v[v.size() - 1]}


func _cast() -> int:
	var here := 0
	for npc in get_nodes_in_group("npcs"):
		if npc.get("_hidden") != true:
			here += 1
	return here


func _measure(label: String) -> void:
	await _wait(30)
	var wall := []
	var worst_proc := []
	var worst_phys := []
	var font: Script = load("res://scripts/pixelfont.gd")
	font.stat_rect = 0
	font.stat_tex = 0
	var prev := Time.get_ticks_usec()
	var stop := prev + int(SECS * 1000000.0)
	while Time.get_ticks_usec() < stop:
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append(float(now - prev) / 1000.0)
		prev = now
		worst_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		worst_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var f := _stats(wall)
	var nframes := maxi(1, wall.size())
	var text_cmds := "text commands a frame: %d draw_rect + %d draw_texture  " % [int(font.stat_rect / nframes), int(font.stat_tex / nframes)]
	var pr := _stats(worst_proc)
	var ph := _stats(worst_phys)
	# with a renderer and no cap: a bad ordinary frame (the 95th percentile) plus one physics step. Headless sleeps between
	# frames, so there the engine's "slowest process step of the last second" stands in for it.
	var frame60: float = (float(pr.avg) if headless else float(f.p95)) + float(ph.avg)
	rows.append({"label": label, "frame60": frame60})
	if frame60 > BUDGET_MS:
		over += 1
	var wall_text := "" if headless else "frame %5.2f ms avg, %5.2f p95, %5.2f worst (%4.0f fps uncapped)  " % [f.avg, f.p95, f.max, 1000.0 / float(f.avg)]
	print("%-30s %s%sslowest process step in a second %5.2f ms (worst %5.2f)  physics step %4.2f  => 60 Hz frame %5.2f ms, headroom x%.1f  [nodes %d, draw calls %d]" % [label, wall_text, text_cmds, pr.avg, pr.max, ph.avg, frame60, BUDGET_MS / frame60, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])


func _outing(out: Node, id: String) -> void:
	out.start(id, false, {"party": PARTY})
	var guard := 0
	while not (out.is_open and out.phase == "intro") and guard < 600:
		await process_frame
		guard += 1
	out.begin_play()
	await _settle(4.5)  # past the countdown


func _leave(out: Node) -> void:
	out._finish(-1)
	await _wait(10)
	await physics_frame  # (as a button press would: the room's puppets are freed before the next _process)
	out.close()
	await _settle(1.5)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var game := root.get_node("Game")
	var camp := root.get_node("Campaign")
	var world := root.get_node("World")
	var comp := root.get_node("Computer")
	var out := root.get_node("Outings")
	var pid := OS.get_process_id()
	camp.save_prefix = "user://test_%d_frametime_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_frametime_settings.cfg" % pid
	headless = DisplayServer.get_name() == "headless"
	game.set_format("deck")
	Engine.max_fps = 0
	if not headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("frame time, %s, %s, %d threads, window %s, logical %s" % ["no renderer (headless)" if headless else "with the renderer (%s)" % RenderingServer.get_video_adapter_name(), OS.get_processor_name(), OS.get_processor_count(), str(root.size), str(root.content_scale_size)])

	# ---- the title (the lightest screen, for scale)
	change_scene_to_file("res://scenes/title.tscn")
	await _settle(1.0)
	await _measure("title")

	# ---- the main floor in Free Play: the cast at their desks and walking about
	game.title_mode = false
	camp.new_game(camp.FREE)
	world.time_scale = 1.0
	world.hud_visible = true
	out.enabled = true
	out.use_rooms = true
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle(2.5)
	await _measure("main floor, cast of %d" % _cast())

	# ---- the whole party in one room: the bowling alley on a team night
	await _outing(out, "bowling")
	await _measure("bowling alley, cast of %d" % _cast())
	await _leave(out)

	# ---- paintball in its room, a match under way
	await _outing(out, "paintball")
	await _measure("paintball, a match")
	await _leave(out)

	# ---- the chair race on the warehouse floor
	await _outing(out, "chair")
	await _measure("chair race, racing")
	await _leave(out)

	# ---- a tech campaign morning: the HUD, tickets coming in, then the Computer
	camp.new_game("tech")
	camp.day = 3
	world.clock = 10.5
	world.time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle(2.5)
	await _measure("tech day, main floor, cast %d" % _cast())
	comp.open(0)
	comp.activate("app:dash")
	await _settle(0.6)
	await _measure("computer, metrics dashboard")
	comp.activate("app:psa")
	await _settle(0.3)
	await _measure("computer, service board")
	comp.activate("app:rmm")
	await _settle(0.3)
	await _measure("computer, RMM")
	comp.close()
	await _settle(0.5)

	var worst := 0.0
	var worst_label := ""
	for r in rows:
		if float(r.frame60) > worst:
			worst = float(r.frame60)
			worst_label = str(r.label)
	print("worst 60 Hz frame: %.2f ms (%s), x%.1f under the %.1f ms budget on this machine" % [worst, worst_label, BUDGET_MS / worst, BUDGET_MS])
	print("failures=%d" % over)
	quit(1 if over > 0 else 0)
