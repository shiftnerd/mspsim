extends SceneTree
# gdlint:disable=max-line-length
# Character creator, level 1 (R15, Look + the create step of charselect.gd): the palette table maps every colour of the
# teen sheet and leaves the outline alone, a look is saved and restored with the campaign (an old save loads as before),
# the MAKE YOUR OWN step is reachable by keys, pad and mouse, and RANDOM is deterministic from the run seed.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/creator.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _key(code: int, unicode := 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.unicode = unicode
	e.pressed = true
	return e


func _pad(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _click(at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	return e


func _near(a: Color, b: Color, tol: float) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < tol


# every distinct opaque colour of both sheets
func _sheet_colors() -> Array:
	var seen := {}
	var out: Array = []
	for facing in ["right", "left"]:
		var img := Image.load_from_file("res://assets/characters/office_teen_%s.png" % facing)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and not seen.has(c.to_html(false)):
					seen[c.to_html(false)] = true
					out.append(Color(c.r, c.g, c.b))
	return out


func _bright_look() -> Dictionary:
	return {
		"name": "TESTER",
		"skin": "8d5524",
		"hair": "3a5fb0",
		"shirt": "e0a030",
		"pants": "7a3030",
		"shoes": "cfc8b5"
	}


func _init() -> void:
	await process_frame
	var look := root.get_node("Look")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var player = load("res://scripts/player.gd")
	d.settings_path = "user://test_creator_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://test_creator_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	DirAccess.remove_absolute(d.settings_path)

	# ---- the palette table
	var colors := _sheet_colors()
	var nsrc: int = look.SOURCES.size()
	_check(colors.size() > 20, "read the sheet colours (%d)" % colors.size())
	var def: Dictionary = look.default_look()
	var pal_def: PackedColorArray = look.palette(def)
	var src: PackedColorArray = look.sources()
	var exact := 0
	var keeps := 0
	var flash := 0
	var unknown: Array = []
	var bright: Dictionary = _bright_look()
	var pal_b: PackedColorArray = look.palette(bright)
	var outline_ok := true
	var changed := 0
	for col in colors:
		var kind := ""
		var idx := -1
		for i in src.size():
			if _near(col, src[i], 0.004):
				kind = "exact"
				idx = i
			elif _near(col, src[i].lerp(Color.WHITE, look.FLASH), 0.01):
				kind = "flash"
				idx = i
		if kind == "":
			unknown.append(col.to_html(false))
			continue
		var out: Color = look.map_color(col, bright)
		var want: Color = (
			pal_b[idx] if kind == "exact" else pal_b[idx].lerp(Color.WHITE, look.FLASH)
		)
		if not _near(out, want, 0.01):
			unknown.append("%s mapped to %s" % [col.to_html(false), out.to_html(false)])
		if kind == "exact":
			if idx < nsrc:
				exact += 1
				if not _near(out, col, 0.004):
					changed += 1
			else:
				keeps += 1
				if not _near(out, col, 0.004):
					outline_ok = false
		else:
			flash += 1
		if col.to_html(false) == "17121f" and not _near(out, col, 0.001):
			outline_ok = false
	_check(unknown.is_empty(), "every colour of the sheet maps (unknown: %s)" % str(unknown))
	_check(exact == nsrc, "all %d source colours are in the sheet (%d)" % [nsrc, exact])
	_check(
		changed == nsrc,
		"a different look recolours every source colour (%d of %d)" % [changed, nsrc]
	)
	_check(
		keeps == look.KEEPS.size(),
		"all %d kept colours are in the sheet (%d)" % [look.KEEPS.size(), keeps]
	)
	_check(flash > 10, "the hurt flash colours are matched too (%d)" % flash)
	_check(outline_ok, "the outline, eyes, brows, mouth, buckle and watch are untouched")
	var same := true
	for i in pal_def.size():
		if not _near(pal_def[i], src[i], 0.004):
			same = false
	_check(same, "the default look gives back the original sheet colours (shades included)")
	for hex in ["000000", "ffffff", "2a2f3a", "f4f2ea"]:
		for role in look.ROLES:
			var lk: Dictionary = look.default_look()
			lk[role] = hex
			var p: PackedColorArray = look.palette(lk)
			for i in p.size():
				if not (p[i].r >= 0.0 and p[i].r <= 1.0 and p[i].g <= 1.0 and p[i].b <= 1.0):
					_check(false, "shade out of range for %s %s" % [role, hex])
	var sh: Color = look.shade_of(Color.html("e0a030"), "shirt", 1)
	_check(sh.v < Color.html("e0a030").v, "a shirt shade is darker than its base")
	_check(
		look.shader().code.contains("src[%d]" % src.size()), "the shader has one slot per colour"
	)

	# ---- RANDOM is seeded
	d.seed_run(777)
	look.randomize_look()
	var r1: Dictionary = look.look.duplicate()
	d.seed_run(777)
	look.randomize_look()
	_check(look.look == r1, "RANDOM gives the same person for the same seed")
	var differs := false
	for s in [778, 779, 780, 781]:
		d.seed_run(s)
		look.randomize_look()
		differs = differs or look.look != r1
	_check(differs, "other seeds give other people")
	var valid := true
	for role in look.ROLES:
		valid = valid and str(look.look[role]) in look.SWATCHES[role]
	_check(
		valid and look.look.name in look.NAMES, "a random person uses only the swatches and names"
	)

	# ---- sanitize
	var dirty: Dictionary = look.sanitize(
		{"name": "  zoe<>x  long long name", "skin": "#ABCDEF", "hair": "nothex", "shirt": 5}
	)
	_check(
		(
			dirty.skin == "abcdef"
			and dirty.hair == look.default_look().hair
			and dirty.shirt == look.default_look().shirt
		),
		"colours are checked"
	)
	_check(
		dirty.name.length() <= look.MAX_NAME and dirty.name == dirty.name.to_upper(),
		"the name is short and upper case: %s" % dirty.name
	)

	# ---- the select screen
	var cs: Node2D = load("res://scripts/charselect.gd").new()
	root.add_child(cs)
	await process_frame
	await process_frame
	look.look = look.default_look()
	look.active = false
	player.current_character = "office_adult"
	cs.setup("tech")
	_check(
		cs.ids.size() == 4 and cs.ids[0] == "custom", "the tech campaign offers MAKE YOUR OWN first"
	)
	for m in ["owner", "sales", "service"]:
		cs.setup(m)
		_check(not "custom" in cs.ids, "%s does not offer it (the player is a cast member)" % m)
	cs.setup("free")
	_check(cs.ids.size() == 8 and cs.ids[0] == "custom", "Free Play offers it first")
	cs.setup("tech")
	_check(
		cs.current_id() == "office_adult" and not cs.is_custom(),
		"the default selection is unchanged"
	)
	cs.sel = 0
	_check(cs.is_custom() and cs.current_id() == "office_teen", "the custom card is the teen sheet")
	cs._unhandled_input(_key(KEY_ENTER))
	_check(cs.step == "create", "Enter on MAKE YOUR OWN opens the create step")
	_check(cs.create_row == 0, "it starts on the NAME row")
	# keys: name
	for i in 5:
		cs._unhandled_input(_key(KEY_BACKSPACE))
	cs._unhandled_input(_key(KEY_Z, 90))
	cs._unhandled_input(_key(KEY_O, 111))
	cs._unhandled_input(_key(KEY_A, 97))
	_check(look.look.name == "ZOA", "typing a name (W A S D too): %s" % look.look.name)
	cs._unhandled_input(_key(KEY_BACKSPACE))
	cs._unhandled_input(_key(KEY_E, 69))
	_check(look.look.name == "ZOE" and cs.step == "create", "Backspace deletes, E types a letter")
	# keys: rows and swatches
	cs._unhandled_input(_key(KEY_DOWN))
	_check(cs.create_row == 1, "Down moves to SKIN")
	var before: String = look.look.skin
	cs._unhandled_input(_key(KEY_RIGHT))
	_check(
		(
			look.look.skin
			== look.SWATCHES.skin[(look.SWATCHES.skin.find(before) + 1) % look.SWATCHES.skin.size()]
		),
		"Right picks the next skin tone"
	)
	cs._unhandled_input(_key(KEY_LEFT))
	cs._unhandled_input(_key(KEY_LEFT))
	_check(
		(
			look.look.skin == look.SWATCHES.skin[look.SWATCHES.skin.size() - 1]
			or look.SWATCHES.skin.find(look.look.skin) == look.SWATCHES.skin.find(before) - 1
		),
		"Left goes back and wraps"
	)
	_check(cs._sprites[0].material != null, "the preview wears the look")
	# pad: down to the last row and back
	for i in 5:
		cs._unhandled_input(_pad(JOY_BUTTON_DPAD_DOWN))
	_check(cs.create_row == 6, "the D-pad reaches the RANDOM row")
	d.seed_run(31)
	cs._unhandled_input(_pad(JOY_BUTTON_A))
	var rolled: Dictionary = look.look.duplicate()
	d.seed_run(31)
	look.randomize_look()
	_check(
		rolled == look.look and cs.step == "create", "A on RANDOM rolls the seeded person and stays"
	)
	cs._unhandled_input(_pad(JOY_BUTTON_DPAD_UP))
	cs._unhandled_input(_pad(JOY_BUTTON_DPAD_RIGHT))
	_check(cs.create_row == 5, "the D-pad moves up and changes shoes")
	# mouse: click a swatch
	cs.queue_redraw()
	await process_frame
	await process_frame
	var target: Rect2 = Rect2()
	for r in cs._rects:
		if r[1] == "sw" and int(r[2]) == 300 + 3:
			target = r[0]
	_check(target.size.x > 0.0, "the shirt swatches are on screen for the mouse")
	cs._unhandled_input(_click(target.get_center()))
	_check(
		look.look.shirt == look.SWATCHES.shirt[3] and cs.create_row == 3,
		"a click picks that shirt colour"
	)
	# back and forward
	cs._unhandled_input(_pad(JOY_BUTTON_B))
	_check(cs.step == "char", "B goes back to the cards")
	cs._unhandled_input(_key(KEY_ENTER))
	look.look["name"] = "ZOE"
	look.look["skin"] = "8d5524"
	cs._unhandled_input(_key(KEY_ENTER))
	_check(cs.step == "phone", "the tech campaign asks for the phone after the create step")
	_check(
		"ZOE" in cs.summary() and not "TEEN" in cs.summary(),
		"the summary uses the custom name: %s" % cs.summary()
	)
	cs._unhandled_input(_key(KEY_ESCAPE))
	_check(cs.step == "create", "Esc on the phone returns to the create step")
	var result := {}
	cs.done.connect(func(r: Dictionary) -> void: result.merge(r))
	cs._unhandled_input(_key(KEY_ENTER))
	cs._unhandled_input(_key(KEY_ENTER))
	cs.confirm()  # the build step is on: Enter on the phone opens it, then confirm starts
	if result.is_empty():
		cs.confirm()
	_check(
		not result.is_empty() and result.character == "office_teen" and result.look.name == "ZOE",
		"confirming returns the teen sheet and the look"
	)
	_check(
		look.active and look.is_custom() and player.current_character == "office_teen",
		"the player is now the custom person"
	)
	var cfg := ConfigFile.new()
	_check(
		(
			cfg.load(d.settings_path) == OK
			and cfg.get_value("look", "skin", "") == "8d5524"
			and cfg.get_value("look", "custom", false)
		),
		"the look is kept in the settings file"
	)
	# the next new run opens on the card again
	look.look = look.default_look()
	look.active = false
	look.load_settings()
	_check(
		look.look.skin == "8d5524" and look.look.name == "ZOE" and look.active,
		"the settings give the last look back"
	)
	player.current_character = "office_adult"
	cs.setup("free")
	_check(cs.is_custom(), "the select screen opens on MAKE YOUR OWN after a custom run")
	cs.sel = 2
	cs.confirm()
	_check(not look.active and not look.is_custom(), "choosing a stock person ends the custom look")
	cs.queue_free()

	# ---- the campaign save
	look.look = bright.duplicate()
	look.active = true
	player.current_character = "office_teen"
	c.new_game("tech")
	_check(look.is_custom(), "a tech run starts as the custom person")
	c.save()
	look.look = look.default_look()
	look.active = false
	player.current_character = "office_adult"
	var ok: bool = c.continue_game("tech")
	_check(
		ok and look.is_custom() and look.look.shirt == "e0a030" and look.look.name == "TESTER",
		"Continue restores the custom person"
	)
	_check(
		player.current_character == "office_teen",
		"campaign/character is still a plain character name"
	)
	cfg = ConfigFile.new()
	cfg.load(c.save_path("tech"))
	_check(
		(
			str(cfg.get_value("campaign", "character", "")) == "office_teen"
			and cfg.has_section_key("campaign", "look")
		),
		"the save keeps the name and has a look section"
	)
	# a stock character saves look.active = false
	player.current_character = "office_dan"
	c.new_game("tech")
	c.save()
	cfg.load(c.save_path("tech"))
	_check(
		not bool(cfg.get_value("campaign", "look", {}).get("active", true)),
		"a stock run saves an inactive look"
	)
	# an old save has no look at all
	look.active = true
	player.current_character = "office_teen"
	c.new_game("tech")
	c.save()
	cfg.load(c.save_path("tech"))
	cfg.erase_section_key("campaign", "look")
	cfg.save(c.save_path("tech"))
	look.look = bright.duplicate()
	look.active = true
	ok = c.continue_game("tech")
	_check(
		ok and not look.is_custom() and player.current_character == "office_teen",
		"an old save loads as the plain teen"
	)
	DirAccess.remove_absolute(c.save_path("tech"))
	DirAccess.remove_absolute(d.settings_path)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
