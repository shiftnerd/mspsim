extends SceneTree
# R7: every phone ringtone is a real, different sound; the default is the plain text blip.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/ringtones.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var sfx := root.get_node("Sfx")
	var career := root.get_node("Career")
	var seen := {}
	for id in ["text", "ring_dial", "ring_chime", "ring_marimba", "ring_quack"]:
		var s: AudioStreamWAV = sfx.stream(id)
		ok(s != null and s.data.size() > 2000, "%s is a sound (%d bytes)" % [id, s.data.size() if s != null else 0])
		seen[hash(s.data)] = id
	ok(seen.size() == 5, "all five sound different")
	ok(career.ringtone_sfx() == "text", "the default ringtone is the plain blip")
	for u in career.UNLOCKS:
		if str(u.kind) == "ringtone" and str(u.id) != "ring_classic":
			ok(sfx.SOUNDS.has(str(u.id)), "%s has a sound" % u.id)
	print("ringtones: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
