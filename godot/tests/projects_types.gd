extends SceneTree
# gdlint:disable=max-line-length
# P5 owner leftovers: Projects.TYPES (the project labels and blurbs) and OwnerCast.CARDS (Jen's and Michael's cards) are patchable
# through the story strings workflow: they are in Strings.ROOTS, their keys are in story/strings.txt, and a changed line is used.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var strings := root.get_node("Strings")
	var projects := root.get_node("Projects")
	var o := root.get_node("Owner")
	var cast: Script = load("res://scripts/owner_cast.gd")
	_check((strings.ROOTS.get("Projects", []) as Array).has("TYPES"), "Projects.TYPES is a patchable root")
	_check((strings.ROOTS.get("OwnerCast", []) as Array).has("CARDS") and strings.SCRIPTS.has("OwnerCast"), "OwnerCast.CARDS is a patchable root (a static helper script)")
	var keys := {}
	for e in strings.entries():
		keys[str(e.key)] = str(e.text)
	var types_n := 0
	for id in projects.DEFAULT_TYPES:
		types_n += 1 if keys.has("Projects.TYPES.%s.label" % id) and keys.has("Projects.TYPES.%s.blurb" % id) else 0
	_check(types_n == projects.DEFAULT_TYPES.size() and types_n >= 5, "every project type has a label and a blurb entry (%d)" % types_n)
	_check(keys.has("OwnerCast.CARDS.jen_phones.text") and keys.has("OwnerCast.CARDS.michael_offer.options.2.label"), "the second cast's cards have entries")
	var file := FileAccess.get_file_as_string("res://story/strings.txt")
	_check(file.contains("[Projects.TYPES.desktops.label]") and file.contains("[OwnerCast.CARDS.jen_intake.text]"), "story/strings.txt lists them")
	# a patched line is used by the game
	var path := "user://test_%d_strings.txt" % OS.get_process_id()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[Projects.TYPES.desktops.label]\nNEW PCS FOR EVERYBODY\n\n[Projects.TYPES.server.blurb]\nthe server sounds like a lawn mower\n\n[OwnerCast.CARDS.jen_wall.options.0.label]\nBE A VERY POLITE WALL\n")
	f.close()
	var applied: int = strings.load_file(path)
	_check(applied == 3 and strings.report.is_empty(), "three patched lines are applied without a complaint (%d, %s)" % [applied, str(strings.report)])
	_check(str(projects.TYPES.desktops.label) == "NEW PCS FOR EVERYBODY" and str(projects.TYPES.server.blurb).contains("lawn mower"), "Projects.TYPES carries the new text")
	_check(str(projects.DEFAULT_TYPES.desktops.label) != "NEW PCS FOR EVERYBODY", "the built-in text is untouched")
	_check(int(projects.TYPES.desktops.hours) == int(projects.DEFAULT_TYPES.desktops.hours), "the numbers are not text")
	_check(str(cast.CARDS.jen_wall.options[0].label) == "BE A VERY POLITE WALL" and str(o.CARDS.jen_wall.options[0].label) == "BE A VERY POLITE WALL", "the owner's card table sees the patched card")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
