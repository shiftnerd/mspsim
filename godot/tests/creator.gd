extends SceneTree
# gdlint:disable=max-line-length
# Character creator, level 1 (R15, Look + the create step of charselect.gd): the palette table maps every colour of the
# teen sheet and leaves the outline alone, a look is saved and restored with the campaign (an old save loads as before),
# the MAKE YOUR OWN step is reachable by keys, pad and mouse, and RANDOM is deterministic from the run seed.
# Level 2 (hairstyles, prebaked sheets custom_teen_<style>): every shipped style plays all 85 frames in both facings, differs
# from the teen sheet only around the head, never covers the eyes, is saved and restored, and an old save wears `side`.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/creator.gd

const SHEET_W := 64
const SHEET_H := 80
const NFRAMES := 85
const EYES := [Color8(255, 255, 255), Color8(58, 36, 24)]  # eye white and pupil
# colours that locate the head in a frame: hair, its highlight, the brows and the eyes (and their hurt flash mixes)
const HEAD_COLORS := [
	Color8(154, 81, 36), Color8(196, 122, 56), Color8(107, 52, 22), Color8(255, 255, 255), Color8(58, 36, 24)
]

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


# the sheet of the custom person in a hairstyle (office_teen itself for `side`)
func _sheet(look: Node, style: String) -> String:
	return look.sheet_for("office_teen", true, {"hair_style": style})


# every distinct opaque colour of the sheets of every shipped hairstyle, both facings
func _sheet_colors(look: Node) -> Array:
	var seen := {}
	var out: Array = []
	for style in look.HAIR_STYLES:
		for facing in ["right", "left"]:
			var img := _rgba("%s_%s" % [_sheet(look, style), facing])
			var data := img.get_data()
			for i in range(0, data.size(), 4):
				if data[i + 3] == 0:
					continue
				var key := "%02x%02x%02x" % [data[i], data[i + 1], data[i + 2]]
				if not seen.has(key):
					seen[key] = true
					out.append(Color8(data[i], data[i + 1], data[i + 2]))
	return out


func _rgba(name: String) -> Image:
	var img: Image = (load("res://assets/characters/%s.png" % name) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _in(data: PackedByteArray, i: int, cols: Array) -> bool:
	for c in cols:
		if absi(data[i] - c.r8) <= 1 and absi(data[i + 1] - c.g8) <= 1 and absi(data[i + 2] - c.b8) <= 1:
			return true
		var f: Color = c.lerp(Color.WHITE, 0.7)  # the hurt flash
		if absi(data[i] - f.r8) <= 1 and absi(data[i + 1] - f.g8) <= 1 and absi(data[i + 2] - f.b8) <= 1:
			return true
	return false


# the sheet of a hairstyle against the teen's: only the head region differs, the eyes stay, the same frames play
func _check_style(look: Node, style: String) -> void:
	var sheet := _sheet(look, style)
	var frames: SpriteFrames = look.frames_for("office_teen", true, {"hair_style": style})
	var base_frames: SpriteFrames = load("res://characters/office_teen.tres")
	_check(frames != null and frames.get_animation_names() == base_frames.get_animation_names(), "%s: the same animations as the teen" % style)
	var same_timing := true
	for anim in base_frames.get_animation_names():
		same_timing = (
			same_timing
			and frames.get_frame_count(anim) == base_frames.get_frame_count(anim)
			and frames.get_animation_loop(anim) == base_frames.get_animation_loop(anim)
			and frames.get_animation_speed(anim) == base_frames.get_animation_speed(anim)
		)
		for i in base_frames.get_frame_count(anim):
			same_timing = same_timing and frames.get_frame_duration(anim, i) == base_frames.get_frame_duration(anim, i)
	_check(same_timing, "%s: frame counts, durations, speeds and loops match" % style)
	for facing in ["right", "left"]:
		var used := {}
		for anim in frames.get_animation_names():
			if str(anim).ends_with("_" + facing):
				for i in frames.get_frame_count(anim):
					var tex := frames.get_frame_texture(anim, i) as AtlasTexture
					used[int(tex.region.position.x) / SHEET_W] = true
					_check_texture_of(tex, sheet, facing)
		_check(used.size() == NFRAMES, "%s %s: all %d frames are played (%d)" % [style, facing, NFRAMES, used.size()])
		var a := _rgba("office_teen_" + facing)
		var b := _rgba("%s_%s" % [sheet, facing])
		_check(
			b.get_width() == NFRAMES * SHEET_W and b.get_height() == SHEET_H,
			"%s %s: the sheet is 85 frames of 64x80" % [style, facing]
		)
		var da := a.get_data()
		var db := b.get_data()
		var changed := 0
		var outside := 0
		var eyes := 0
		var big := 0
		for fr in NFRAMES:
			var dbox := Rect2i()
			var abox := Rect2i()
			var d_any := false
			var a_any := false
			for y in SHEET_H:
				for x in SHEET_W:
					var i := (y * NFRAMES * SHEET_W + fr * SHEET_W + x) * 4
					if da[i + 3] > 0 and _in(da, i, HEAD_COLORS):
						abox = abox.expand(Vector2i(x, y)) if a_any else Rect2i(x, y, 1, 1)
						a_any = true
					var same := da[i + 3] == db[i + 3] and (da[i + 3] == 0 or (da[i] == db[i] and da[i + 1] == db[i + 1] and da[i + 2] == db[i + 2]))
					if not same:  # (the colour of a transparent pixel means nothing)
						dbox = dbox.expand(Vector2i(x, y)) if d_any else Rect2i(x, y, 1, 1)
						d_any = true
						changed += 1
						if da[i + 3] > 0 and _in(da, i, EYES):
							eyes += 1
			if d_any:
				if not abox.grow(6).encloses(dbox):
					outside += 1
				if dbox.size.x > 30 or dbox.size.y > 30:
					big += 1
		_check(style == "side" or changed > 100, "%s %s: the hair differs from the teen's (%d pixels)" % [style, facing, changed])
		_check(outside == 0, "%s %s: the hair stays inside the head box in every frame (%d frames outside)" % [style, facing, outside])
		_check(big == 0, "%s %s: the head box is at most 30x30 px" % [style, facing])
		_check(eyes == 0, "%s %s: the hair never covers the eyes (%d pixels)" % [style, facing, eyes])
		var ha := FileAccess.get_file_as_string("res://assets/characters/office_teen_%s_hands.json" % facing)
		var hb := FileAccess.get_file_as_string("res://assets/characters/%s_%s_hands.json" % [sheet, facing])
		_check(ha.strip_edges() == hb.strip_edges(), "%s %s: the hand and ear table is the teen's" % [style, facing])


func _check_texture_of(tex: AtlasTexture, sheet: String, facing: String) -> void:
	var want := "res://assets/characters/%s_%s.png" % [sheet, facing]
	if tex.atlas.resource_path != want:
		_check(false, "frame of %s_%s uses %s" % [sheet, facing, tex.atlas.resource_path])


func _bright_look() -> Dictionary:
	return {
		"name": "TESTER",
		"hair_style": "curly",
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
	var colors := _sheet_colors(look)
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
	_check(look.look.hair_style in look.HAIR_STYLES, "a random person has a shipped hairstyle")
	# the style is drawn after the colours and the name: the old draws are unchanged for the same seed
	d.seed_run(777)
	look.randomize_look()
	var again: Dictionary = look.look.duplicate()
	d.seed_run(777)
	var rr: RandomNumberGenerator = d.rng("creator")
	var old_ok := true
	for role in look.ROLES:
		var list: Array = look.SWATCHES[role]
		old_ok = old_ok and again[role] == list[rr.randi() % list.size()]
	old_ok = old_ok and again.name == look.NAMES[rr.randi() % look.NAMES.size()]
	_check(old_ok, "seeded RANDOM gives the same colours and name as before the style existed")
	var styles_seen := {}
	for s in range(900, 960):
		d.seed_run(s)
		look.randomize_look()
		styles_seen[look.look.hair_style] = true
	_check(styles_seen.size() == look.HAIR_STYLES.size(), "RANDOM reaches every shipped style (%d)" % styles_seen.size())

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
	_check(dirty.hair_style == "side", "a missing hairstyle is side (old saves)")
	_check(look.sanitize({"hair_style": "curly"}).hair_style == "curly", "a shipped hairstyle is kept")
	for bad in ["long", "bald", "nonsense", 5]:
		_check(look.sanitize({"hair_style": bad}).hair_style == "side", "hairstyle %s is not shipped: side" % str(bad))
	_check(look.default_look().hair_style == "side", "the default look wears the teen's own hair")
	for planned in look.HAIR_PLANNED:
		_check(not planned in look.HAIR_STYLES, "%s is planned, not shipped" % planned)

	# ---- the hairstyle sheets
	_check(_sheet(look, "side") == "office_teen", "side is the teen's own sheet (no duplicate files)")
	_check(
		look.sheet_for("office_adult", true, {"hair_style": "curly"}) == "office_adult",
		"a stock character ignores the hairstyle"
	)
	_check(look.sheet_for("office_teen", false, {"hair_style": "curly"}) == "office_teen", "a non-custom teen is plain")
	for style in look.HAIR_STYLES:
		_check_style(look, style)

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
	# keys: the STYLE row
	cs._unhandled_input(_key(KEY_DOWN))
	_check(cs.create_row == 1 and cs.CREATE_ROWS[1] == "style", "Down moves to STYLE")
	_check(look.look.hair_style == "side", "the card starts with the teen's own hair")
	cs._unhandled_input(_key(KEY_RIGHT))
	_check(
		look.look.hair_style == "short" and cs._sprites[0].sprite_frames == look.frames_for("office_teen", true),
		"Right picks the next hairstyle and the preview wears it"
	)
	_check(cs._sprites[0].is_playing() and cs._sprites[0].material != null, "the preview keeps animating in the palette")
	cs._unhandled_input(_key(KEY_LEFT))
	cs._unhandled_input(_key(KEY_LEFT))
	_check(look.look.hair_style == "curly", "Left goes back and wraps to the last style")
	cs._unhandled_input(_key(KEY_RIGHT))
	_check(look.look.hair_style == "side", "Right wraps to the first style")
	cs.queue_redraw()
	await process_frame
	await process_frame
	var chip := Rect2()
	for r in cs._rects:
		if r[1] == "style_next":
			chip = r[0]
	_check(chip.size.x > 0.0, "the STYLE chips are on screen for the mouse")
	cs.create_row = 0
	cs._unhandled_input(_click(chip.get_center()))
	_check(look.look.hair_style == "short" and cs.create_row == 1, "a click on > picks the next hairstyle")
	for r in cs._rects:
		if r[1] == "style_prev":
			chip = r[0]
	cs._unhandled_input(_click(chip.get_center()))
	_check(look.look.hair_style == "side", "a click on < goes back")
	# keys: rows and swatches
	cs._unhandled_input(_key(KEY_DOWN))
	_check(cs.create_row == 2, "Down moves to SKIN")
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
	_check(cs.create_row == 7, "the D-pad reaches the RANDOM row")
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
	_check(cs.create_row == 6, "the D-pad moves up and changes shoes")
	# mouse: click a swatch
	cs.queue_redraw()
	await process_frame
	await process_frame
	var target: Rect2 = Rect2()
	for r in cs._rects:
		if r[1] == "sw" and int(r[2]) == 400 + 3:
			target = r[0]
	_check(target.size.x > 0.0, "the shirt swatches are on screen for the mouse")
	cs._unhandled_input(_click(target.get_center()))
	_check(
		look.look.shirt == look.SWATCHES.shirt[3] and cs.create_row == 4,
		"a click picks that shirt colour"
	)
	# back and forward
	cs._unhandled_input(_pad(JOY_BUTTON_B))
	_check(cs.step == "char", "B goes back to the cards")
	cs._unhandled_input(_key(KEY_ENTER))
	look.look["name"] = "ZOE"
	look.look["skin"] = "8d5524"
	look.look["hair_style"] = "receding"
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
	_check(result.look.hair_style == "receding", "the chosen hairstyle comes back with the look")
	_check(
		player.current_character == "office_teen" and look.sheet_for("office_teen", true) == "custom_teen_receding",
		"the player is still the teen by name and wears the receding sheet"
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
			and cfg.get_value("look", "hair_style", "") == "receding"
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
	_check(look.look.hair_style == "receding", "the settings give the hairstyle back")
	# an old settings file has no hair_style
	var cfg_old := ConfigFile.new()
	cfg_old.load(d.settings_path)
	cfg_old.erase_section_key("look", "hair_style")
	cfg_old.save(d.settings_path)
	look.look = look.default_look()
	look.look["hair_style"] = "curly"
	look.load_settings()
	_check(look.look.hair_style == "side" and look.look.skin == "8d5524", "old settings load as the teen's own hair")
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
		look.look.hair_style == "curly" and look.sheet_for("office_teen", true) == "custom_teen_curly",
		"Continue restores the hairstyle"
	)
	# a save from before hairstyles: a look dictionary without the key
	cfg = ConfigFile.new()
	cfg.load(c.save_path("tech"))
	var old_look: Dictionary = cfg.get_value("campaign", "look", {})
	old_look.erase("hair_style")
	cfg.set_value("campaign", "look", old_look)
	cfg.save(c.save_path("tech"))
	look.look = look.default_look()
	look.look["hair_style"] = "curly"
	ok = c.continue_game("tech")
	_check(ok and look.is_custom() and look.look.hair_style == "side", "an old save without a hairstyle loads as side")
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
	# ---- an NPC copy wears the look it was given, not the global one
	look.look = look.default_look()
	look.active = true
	var npc_look: Dictionary = look.default_look()
	npc_look["hair_style"] = "curly"
	npc_look["hair"] = "3a5fb0"
	var spr := AnimatedSprite2D.new()
	look.apply(spr, "office_teen", true, npc_look)
	spr.sprite_frames = look.frames_for("office_teen", true, npc_look)
	_check(
		spr.sprite_frames == load("res://characters/custom_teen_curly.tres") and spr.material != null,
		"an NPC copy takes the sheet and palette of its own look dictionary"
	)
	_check(
		look.sheet_for("office_teen", true) == "office_teen",
		"the global look is unchanged by the copy (side)"
	)
	spr.free()
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
