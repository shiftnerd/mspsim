extends SceneTree
# New Game Plus on the title menu and the MUT chip on the character select (needs a renderer for the PNGs):
#   Godot --path godot --fixed-fps 60 -s res://tests/yeartwo_shots.gd -- --format=wide|h|v      -> user://yeartwo_FORMAT_STEP.png
# The checks also run headless.

var frame := 0
var failures := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _shot(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://yeartwo_%s_%s.png" % [root.get_node("Game").format, tag])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var y := root.get_node("Yeartwo")
	var c := root.get_node("Campaign")
	match frame:
		5:
			c.save_prefix = "user://test_y2shots_%d_" % OS.get_process_id()
			var meta := ConfigFile.new()
			y.record(meta, "tech", "lead")
			y.record(meta, "owner", "stay")
			meta.save(c.save_prefix + "meta.cfg")
		40:
			current_scene._open_menu()
			_shot("top")
			current_scene._choose(0)  # TECH CAMPAIGN: no save, but a finished year, so a submenu
			var ids: Array = current_scene._items.map(func(i: Dictionary) -> String: return i.id)
			_check(ids == ["tech_y2", "tech_new"], "the tech submenu has START YEAR 2 and NEW CAMPAIGN: %s" % str(ids))
		50:
			_shot("menu")
			current_scene._choose(0)  # START YEAR 2
		80:
			var cs: Node = current_scene._select
			_check(cs != null and y.pending and cs.mode == "tech", "NEW GAME PLUS opens the character select with Year 2 pending")
			_check(cs.summary().contains("YEAR 2"), "the summary names YEAR 2")
			cs.step = "options"  # the MUT row lives on the options page
		90:
			_shot("chip_auto")
			current_scene._select.change_mut(1)
			current_scene._select.change_mut(1)
		100:
			_check(y.pick != "" and y.chip_text().begins_with("PICK"), "M picks a mutator: " + y.chip_text())
			_shot("chip_pick")
			current_scene._select.toggle_mut_mode()
		110:
			_check(y.ban != "" and y.chip_text().begins_with("BAN"), "B turns it into a ban: " + y.chip_text())
			_shot("chip_ban")
			current_scene._select.confirm()  # build
		130:
			_check(current_scene._select.step == "build" and root.get_node("Build").budget("normal") == 14, "the build step offers 14 points in Year 2")
			_shot("build")
			current_scene._close_select()
			_check(not y.pending, "backing out clears the pending Year 2")
			DirAccess.remove_absolute(c.save_prefix + "meta.cfg")
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
