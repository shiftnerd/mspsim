extends SceneTree
# The long UI input fuzzer (a harness, not in the default suite: see tests/fuzz_lib.gd). Opens every screen it knows and sends a
# seeded random event stream at it; see docs/dev/notes-soak-ui.md.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/fuzz_ui.gd -- --seconds=6 --seed=1 [--screens=title:home,floor:*] [--coop]
#   options: --seconds=N (game seconds per screen, 60 frames each), --seed=N, --screens=a,b (names or prefix globs like floor:computer:*),
#   --rounds=N (each screen N times with seeds seed..seed+N-1), --sequences (also the campaign sequences), --chaos, --coop, --list
# Exit code 1 when a bug was found. A windowed run (no --headless) also audits the text against the viewport.

const Lib := preload("res://tests/fuzz_lib.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lib := Lib.new(self)
	var seconds := 6.0
	var seed_value := 1
	var rounds := 1
	var screens: Array = []
	var want := PackedStringArray()
	var sequences := false
	var list_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = float(arg.substr(10))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
		elif arg.begins_with("--rounds="):
			rounds = int(arg.substr(9))
		elif arg.begins_with("--screens="):
			want = arg.substr(10).split(",")
		elif arg.begins_with("--log="):
			lib.log_path = arg.substr(6)
		elif arg == "--sequences":
			sequences = true
		elif arg == "--chaos":
			lib.chaos = true
		elif arg == "--coop":
			lib.set_coop_all(true)
		elif arg == "--list":
			list_only = true
	var all: Array = Lib.TITLE_SCREENS + Lib.FLOOR_SCREENS
	for s in all:
		if want.is_empty():
			screens.append(s)
		else:
			for w in want:
				if w == s or (w.ends_with("*") and s.begins_with(w.trim_suffix("*"))):
					screens.append(s)
					break
	if list_only:
		print("\n".join(screens))
		quit(0)
		return
	var t0 := Time.get_ticks_msec()
	for r in rounds:
		for s in screens:
			await lib.fuzz_screen(s, seed_value + r, int(seconds * 60.0))
		if sequences:
			for mode in ["tech", "owner", "sales", "service"]:
				await lib.sequence_campaign(mode, seed_value + r, int(seconds * 60.0 * 4.0))
	lib.finish()
	lib.say("fuzz_ui: screens=%d events=%d bugs=%d seconds=%d" % [lib.screens_fuzzed, lib.events_sent, lib.bugs.size(), (Time.get_ticks_msec() - t0) / 1000])
	print("failures=%d" % lib.bugs.size())
	quit(1 if lib.bugs.size() > 0 else 0)
