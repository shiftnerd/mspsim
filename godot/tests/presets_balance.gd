extends SceneTree
# gdlint:disable=max-line-length
# X7: a balance run per build preset. Every preset of the tech, sales and service campaigns gets a careful bot at the normal tier
# (one seed, time compressed) and none of them may be fired or fall far behind the best one: a preset that wrecks a run, or one
# that wins by itself, is a balance bug. The spread is printed so the notes in docs/balance-notes.md can quote it.

const SPREAD := 40.0  # the most the best and the worst preset may differ in final reputation
var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var build := root.get_node("Build")
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	var plan := {"tech": [120.0, "tech", ""], "sales": [20.0, "sales", ""], "service": [40.0, "service", ""]}
	for mode in plan:
		bots.ts = float(plan[mode][0])
		var path := str(mode)
		var presets: Array = build.PRESETS.get(path, [])
		var lo := 1000.0
		var hi := -1000.0
		for row in presets:
			bots.build_name = str(row.id) if mode == "sales" else ""
			bots.preset_build = build.apply_preset(path, "", "normal", str(row.id)) if mode != "sales" else {}
			var r: Dictionary = await bots.play(mode, "normal", "careful", 11)
			print("%s %s: rep %d score %d ending %s fired %s" % [mode, str(row.id), int(r.rep), int(r.get("score", 0)), str(r.get("ending", "")), str(r.get("fired", false))])
			_check(not bool(r.fired), "%s preset %s: never fired" % [mode, str(row.id)])
			lo = minf(lo, float(r.rep))
			hi = maxf(hi, float(r.rep))
		_check(hi - lo <= SPREAD, "%s presets stay within %d reputation of each other (%d to %d)" % [mode, int(SPREAD), int(lo), int(hi)])
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
