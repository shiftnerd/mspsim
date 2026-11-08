extends SceneTree
# Dev tool (renderer needed, skipped by the runner): frame time of the office alone, with one pane open and with two panes
# open (a computer and a phone, drawing every frame). Prints average process time and FPS over 3 seconds each.
#   Godot --path godot -s res://tests/pane_perf_shots.gd

var lines: Array = []


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _init() -> void:
	_run.call_deferred()


func _sample(label: String) -> void:
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var proc := 0.0
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	lines.append("%s: %.1f fps, process %.2f ms/frame" % [label, float(frames) / secs, proc / float(maxi(1, frames)) * 1000.0])


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_paneperf_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_paneperf_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	root.get_node("Campaign").new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(1.5)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(0.5)
	await _sample("office, two players, no pane")
	var host: Node = players.takeover_host()
	host.open_computer(1, 3)
	await _wait(0.5)
	await _sample("one computer pane")
	host.open_computer(0, 1)
	await _wait(0.5)
	await _sample("two computer panes")
	host.close_all()
	await _wait(0.3)
	host.open_phone(0)
	host.open_phone(1)
	await _wait(0.5)
	await _sample("two phone panes")
	for l in lines:
		print(l)
	quit()
