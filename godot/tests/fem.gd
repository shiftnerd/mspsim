extends SceneTree
# The women's character sheets: every one loads and plays the standard animations in both facings.

var failures := 0
var names := [
	"office_maya",
	"office_morgan",
	"office_marge",
	"client_karen",
	"client_mina",
	"client_brandt",
	"client_hygienist",
	"client_paralegal",
	"expo_dee",
	"expo_priya",
	"expo_tina"
]


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	for n in names:
		var frames: SpriteFrames = load("res://characters/%s.tres" % n)
		var ok := frames != null
		for anim in ["idle", "walk", "run", "sit", "type", "dance", "crouch", "wave", "talk"]:
			for side in ["right", "left"]:
				ok = ok and frames != null and frames.has_animation("%s_%s" % [anim, side])
		_check(ok, "%s has every animation in both facings" % n)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
