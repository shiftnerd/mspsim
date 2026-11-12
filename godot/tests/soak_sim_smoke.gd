extends SceneTree
# gdlint:disable=max-line-length
# The fast preset of the simulation soak (tests/soak_sim.gd, docs/dev/notes-soak-sim.md): a chaotic tech run with the morning reload,
# two outings and every-key save ablation. Fails on any captured error, stall, growth or bad save. Under a minute.

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var lib: RefCounted = load("res://tests/soak_lib.gd").new(self)
	lib.install_capture()
	var cells: Array = lib.fast_preset()
	for cell in cells:
		var res: Dictionary = await lib.run_cell(cell)
		var ok := bool(res.ok)
		failures += 0 if ok else 1
		print(("ok   " if ok else "FAIL ") + "%s: %s" % [res.cfg, res.info])
		if not ok:
			print("     errors %s stuck %s flags %s save %s resume %s" % [str(res.errors).substr(0, 600), str(res.stuck).substr(0, 400), str(res.flags), str(res.save_fail).substr(0, 400), str(res.resume_fail).substr(0, 400)])
	print("soak_sim_smoke: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
