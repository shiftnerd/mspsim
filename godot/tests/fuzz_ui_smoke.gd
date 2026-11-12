extends SceneTree
# gdlint:disable=max-line-length
# A short UI fuzz in the default suite (under a minute): a handful of screens (title, settings, a card, the day report, the Computer,
# the phone, the pause menu, an outing) get 1.5 seconds of seeded random input each; no engine error, no soft-lock, no stuck pause.
# The long version is tests/fuzz_ui.gd; regressions of bugs it found are in tests/fuzz_regress.gd.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/fuzz_ui_smoke.gd

const Lib := preload("res://tests/fuzz_lib.gd")
const SCREENS := ["title:home", "title:settings", "title:charselect:tech", "floor:card_long", "floor:report:tech", "floor:computer:psa", "floor:phone:home", "floor:pause", "floor:outing:darts"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lib := Lib.new(self)
	for s in SCREENS:
		await lib.fuzz_screen(s, 11, 90)
	lib.finish()
	print("screens=%d events=%d" % [lib.screens_fuzzed, lib.events_sent])
	print("failures=%d" % lib.bugs.size())
	quit(1 if lib.bugs.size() > 0 else 0)
