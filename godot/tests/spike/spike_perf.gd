extends SceneTree
# THROWAWAY coop spike, risk 6 (docs/coop-risk-findings.md): frame time and video memory, one player versus two bodies versus
# two bodies + two live takeover panes versus two extra world cameras (true split screen). Needs a renderer, vsync off:
#   Godot --path godot -s res://tests/spike/spike_perf.gd -- --format=h
# Prints one PERF line per scenario (CPU ms per frame from Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS, wall ms per
# frame, GPU ms of the root viewport if the driver reports it, draw calls, video memory, texture memory, object count).

const Lib := preload("res://tests/spike/spike_lib.gd")

var stage: Node
var p1: Node
var extras: Array = []
var results := {}


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func p2_player_script() -> GDScript:
	var src := FileAccess.get_file_as_string("res://scripts/player.gd")
	for fn in ["is_action_pressed", "is_action_just_pressed", "is_action_just_released", "get_action_strength"]:
		src = src.replace('Input.%s("' % fn, 'Input.%s("p2_' % fn)
	src = src.replace('Input.get_axis("move_left", "move_right")', 'Input.get_axis("p2_move_left", "p2_move_right")')
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s


func measure(tag: String) -> void:
	await _wait(90)
	var n := 300
	var wall := 0.0
	var cpu := 0.0
	var phys := 0.0
	var gpu := 0.0
	var dc := 0.0
	var worst := 0.0
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _wait(5)
	for i in n:
		var t0 := Time.get_ticks_usec()
		await process_frame
		var d := float(Time.get_ticks_usec() - t0) / 1000.0
		wall += d
		worst = maxf(worst, d)
		cpu += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var line := "PERF %-34s wall %.2f ms (worst %.1f)  process %.2f ms  physics %.2f ms  gpu(root) %.2f ms  drawcalls %.0f  vram %.1f MB  tex %.1f MB  objects %.0f  nodes %.0f" % [
		tag, wall / n, worst, cpu / n * 1000.0, phys / n * 1000.0, gpu / n, dc / n,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)]
	print(line)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var ctl := root.get_node("Controls")
	for action in ctl.ACTIONS:
		if not InputMap.has_action("p2_" + action):
			InputMap.add_action("p2_" + action, 0.5)
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_spikep_%d_" % OS.get_process_id()
	root.get_node("Difficulty").settings_path = "user://test_spikep_%d_settings.cfg" % OS.get_process_id()
	camp.new_game("tech")
	camp.day = 9
	root.get_node("Nerds").karma = 24
	await create_timer(2.0).timeout
	await _wait(10)
	stage = current_scene
	p1 = stage.get_node("Actors/Player")
	var win := root.get_window()
	print("INFO window %s content %s format %s adapter %s" % [win.size, win.content_scale_size, root.get_node("Game").format, RenderingServer.get_video_adapter_name()])
	await measure("S0 one player")
	# S1: second body
	var p2: Node = load("res://scenes/player.tscn").instantiate()
	p2.set_script(p2_player_script())
	p2.name = "Player2"
	p2.position = p1.global_position + Vector2(30, 0)
	stage.get_node("Actors").add_child(p2)
	await measure("S1 two player bodies")
	# S2: + two live takeover panes (Computer rmm + Phone), left and right halves of a 320x180 window
	var sv_a := Lib.make_pane(root, Vector2i(160, 180), Vector2(0, 0))
	var comp = Lib.pane_script("res://scripts/computer.gd").new()
	sv_a.add_child(comp)
	var sv_b := Lib.make_pane(root, Vector2i(160, 180), Vector2(160, 0))
	var comp_b = Lib.pane_script("res://scripts/computer.gd").new()
	comp_b.pad_device = 0
	sv_b.add_child(comp_b)
	await _wait(2)
	var msp := root.get_node("Msp")
	for i in 4:
		msp.create_ticket(i, i, "spike")
	comp.open(2)
	comp_b.open(3)
	comp.activate("app:psa")
	comp_b.activate("app:rmm")
	await measure("S2 + two static computer panes")
	# S3: worst case: both panes on the animated metrics board (redraw every frame)
	comp.activate("app:dash")
	comp_b.activate("app:dash")
	await measure("S3 + both panes animated (dash)")
	comp.close()
	comp_b.close()
	sv_a.get_parent().get_parent().queue_free()
	sv_b.get_parent().get_parent().queue_free()
	await _wait(5)
	# S4: true split screen: two extra world views (SubViewport sharing the main world_2d + a Camera2D each)
	var views := []
	for i in 2:
		var cl := CanvasLayer.new()
		cl.layer = 91
		root.add_child(cl)
		var cont := SubViewportContainer.new()
		cont.position = Vector2(160 * i, 0)
		cl.add_child(cont)
		var sv := SubViewport.new()
		sv.size = Vector2i(160, 180)
		sv.world_2d = root.world_2d
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		cont.add_child(sv)
		var cam := Camera2D.new()
		cam.global_position = (p1 if i == 0 else p2).global_position
		sv.add_child(cam)
		views.append(cl)
	await measure("S4 two extra world cameras 160x180")
	# S5: S4 + two live computer panes on top (the full co-op worst case)
	var sv_c := Lib.make_pane(root, Vector2i(160, 180), Vector2(0, 0), 95)
	var comp_c = Lib.pane_script("res://scripts/computer.gd").new()
	sv_c.add_child(comp_c)
	var sv_d := Lib.make_pane(root, Vector2i(160, 180), Vector2(160, 0), 95)
	var comp_d = Lib.pane_script("res://scripts/computer.gd").new()
	sv_d.add_child(comp_d)
	await _wait(2)
	comp_c.open(2)
	comp_d.open(3)
	comp_c.activate("app:dash")
	comp_d.activate("app:dash")
	await measure("S5 S4 + two animated panes")
	# memory: how big is one more full-size 368x128 / 320x180 render target?
	print("INFO one RGBA8 160x180 pane target = %.2f MB; two = %.2f MB" % [160.0 * 180.0 * 4.0 / 1048576.0, 2.0 * 160.0 * 180.0 * 4.0 / 1048576.0])
	quit(0)
