extends RefCounted
# THROWAWAY coop spike helpers (docs/coop-risk-findings.md). Not a test: lives in tests/spike/, which run_tests.py does not scan.


# Builds a pane: SubViewportContainer > SubViewport(size) inside a CanvasLayer on `host`. Returns the SubViewport.
static func make_pane(host: Node, size: Vector2i, at := Vector2.ZERO, layer := 90) -> SubViewport:
	var cl := CanvasLayer.new()
	cl.layer = layer
	host.add_child(cl)
	var cont := SubViewportContainer.new()
	cont.position = at
	cont.stretch = false
	cl.add_child(cont)
	var sv := SubViewport.new()
	sv.size = size
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(sv)
	return sv


# A copy of a script made at runtime with the minimum "pane" edits (the real file is NOT touched). The edits ARE the
# change list for phase 3: no strip of the office above the UI, no writes to the global Game.ui_open / ui_shift, and a
# device guard so a pane only reacts to its own pad.
static func pane_script(path: String, patched := true) -> GDScript:
	var src := FileAccess.get_file_as_string(path)
	if patched:
		var nl := char(10)
		var out := PackedStringArray()
		for line in src.split(nl):
			var t := line.strip_edges()
			var ind := line.substr(0, line.length() - line.lstrip(char(9)).length())
			if t.begins_with("Game.ui_open =") or t.begins_with("Game.ui_shift ="):
				line = ind + "pass  # PANE: no global ui flag"
			elif t.begins_with("var top := maxf(12.0, floorf(size.y * Game.UI_STRIP))"):
				line = ind + "var top := 0.0  # PANE: no strip of the office"
			elif t.begins_with("var ptop := maxf(12.0, floorf(size.y * 0.17))"):
				line = ind + "var ptop := 2.0  # PANE"
			elif t.begins_with("if is_open or Game.ui_open or Game.busy"):
				line = ind + "if is_open or Game.busy or Game.title_mode:  # PANE"
			elif t.begins_with("var is_open := false"):
				line = line + nl + "var pad_device := 1  # PANE: only this pad drives the pane"
			elif t.begins_with("func _input(event: InputEvent) -> void:"):
				line = (
					line
					+ nl
					+ char(9)
					+ "if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device != pad_device:"
					+ nl
					+ char(9)
					+ char(9)
					+ "return  # PANE"
				)
			out.append(line)
		src = nl.join(out)
	var s := GDScript.new()
	s.source_code = src
	var err := s.reload()
	if err != OK:
		push_error("pane script reload failed %d" % err)
	return s


static func save_scaled(img: Image, path: String, k := 3) -> void:
	var c: Image = img.duplicate()
	c.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	c.save_png(path)


static func out_dir() -> String:
	var d := OS.get_environment("SPIKE_OUT")
	if d == "":
		d = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(d)
	return d
