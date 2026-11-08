extends SceneTree
# Dev tool (renderer needed, skipped by the runner): the layout audit of the phone and a personal card inside a co-op pane, in the
# wide and h formats. Prints OFFSCREEN / OVERLAP lines (none = clean).
#   Godot --path godot -s res://tests/pane_shots.gd

const PixelFont := preload("res://scripts/pixelfont.gd")

var lines: Array = []


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_paneshots_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_paneshots_%d_settings.cfg" % pid
	var players := root.get_node("Players")
	var game := root.get_node("Game")
	root.get_node("Campaign").new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(1.5)
	players.enable_coop(true)
	players.join(1, 1)
	await _wait(0.5)
	var host: Node = players.takeover_host()
	for fmt in ["wide", "h"]:
		game.set_format(fmt)
		await _wait(0.5)
		var ph: Node = host.open_phone(1)
		await _wait(0.4)
		PixelFont.audit = []
		ph._canvas.queue_redraw()
		await _wait(0.3)
		var n_logged: int = PixelFont.audit.size()
		var rep := PixelFont.audit_report("phone " + fmt + " " + str(host.pane_rect(1).size), true)
		lines.append("phone %s pane %s: %d text draws logged, %d issue(s)" % [fmt, host.pane_rect(1).size, n_logged, rep.size()])
		lines.append_array(rep)
		host.close_all()
		await _wait(0.3)
		var long_text := "Hello there, this is a rather long line of text that has to wrap inside a half window pane without clipping anything at all."
		var opts := [{"label": "FIRST OPTION HERE", "id": "a"}, {"label": "SECOND", "id": "b"}, {"label": "LEAVE", "id": "c"}]
		root.get_node("Cards").ask("Someone Long Named", long_text, opts, func(_id: String) -> void: pass, Callable(), 1)
		await _wait(0.4)
		var pc: Node = host.card_for(1)
		PixelFont.audit = []
		pc._canvas.queue_redraw()
		await _wait(0.3)
		var n_card: int = PixelFont.audit.size()
		var rep2 := PixelFont.audit_report("card " + fmt, true)
		lines.append("card %s pane %s: %d text draws logged, %d issue(s)" % [fmt, host.pane_rect(1).size, n_card, rep2.size()])
		lines.append_array(rep2)
		host.close_all()
		await _wait(0.3)
	for l in lines:
		print(l)
	quit()
