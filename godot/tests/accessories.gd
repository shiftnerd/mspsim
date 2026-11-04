extends SceneTree
# gdlint:disable=max-line-length
# Character creator level 3, steps b to d: the accessory overlay (glasses, facial hair, hats, name sticker, conference lanyard, watch;
# scripts/head_gear.gd, tools/make_head_sheets.lua, assets/accessories/). Checks: the style list and files; a golden comparison (the
# overlay composited on the intern body sheet equals a one-off prebaked reference character with the accessory as a real layer, all
# 129 frames, both facings, six accessories: head, hat, torso and wrist kinds); every accessory pixel fits its cell (including the
# death frames); the unlock rules (a locked hat, glasses or beard becomes none, the medals that unlock them, the old tree in the
# warehouse), the hat hair fallback (HAT_HAIR); sync with the body sprite (index and
# position for every animation frame, backwards sitdown, pause() and a frame set while jumping, a character switch on the real
# player, an NPC copy's own look); the hurt flash frames 25 and 28 with overlay colours; eyes and brows stay visible under the
# frames; save and restore of Look.acc through the campaign and the settings file, and old files without it.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/accessories.gd

const NFRAMES := 129
const CELL := 32
const FW := 64
const FH := 80
const SLOTS := ["lanyard", "badge", "beard", "hat", "glasses", "watch"]  # HeadGear.SLOTS: the drawing order
const KIND := {"beard": "head", "glasses": "head", "hat": "hat", "badge": "torso", "lanyard": "torso", "watch": "wrist"}
const CELLS := {"head": 32, "hat": 40, "torso": 32, "wrist": 16}
const GOLDEN := [["glasses", "aviator"], ["beard", "full"], ["hat", "cap"], ["hat", "santa"], ["lanyard", "conference"], ["watch", "sport"]]

var failures := 0
var gear_script: GDScript = null


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# a PNG as written (not through the importer, which changes the colour of transparent pixels)
func _raw(res_path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _origins(facing: String, kind := "head") -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/accessories/%s_origin_%s.json" % [kind, facing]))


func _cell_of(slot: String) -> int:
	return int(CELLS[KIND[slot]])


# the overlay cell of frame f pasted on the body frame (bytes of a 64x80 RGBA frame)
func _composite(body: Image, cells: Image, org: Array, f: int, size := CELL) -> PackedByteArray:
	var frame := body.get_region(Rect2i(f * FW, 0, FW, FH)).get_data()
	var cell := cells.get_region(Rect2i(f * size, 0, size, size)).get_data()
	var ox := int(org[f][0])
	var oy := int(org[f][1])
	for y in size:
		for x in size:
			var i := (y * size + x) * 4
			if cell[i + 3] == 0:
				continue
			var cx := x + ox
			var cy := y + oy
			if cx < 0 or cx >= FW or cy < 0 or cy >= FH:
				continue
			var j := (cy * FW + cx) * 4
			frame[j] = cell[i]
			frame[j + 1] = cell[i + 1]
			frame[j + 2] = cell[i + 2]
			frame[j + 3] = cell[i + 3]
	return frame


func _golden(slot: String, id: String, facing: String) -> void:
	var body := _raw("res://assets/characters/office_intern_%s.png" % facing)
	var cells := _raw("res://assets/accessories/%s_%s_%s.png" % [slot, id, facing])
	var ref := _raw("res://tests/golden/ref_%s_%s_%s.png" % [slot, id, facing])
	var org := _origins(facing, str(KIND[slot]))
	var bad: Array = []
	for f in NFRAMES:
		var got := _composite(body, cells, org, f, _cell_of(slot))
		var want := ref.get_region(Rect2i(f * FW, 0, FW, FH)).get_data()
		if got != want:
			bad.append(f)
	_check(bad.is_empty(), "golden %s_%s %s: the overlay on the body equals the prebaked reference in all %d frames (bad: %s)" % [slot, id, facing, NFRAMES, str(bad.slice(0, 8))])


func _ring_clear(slot: String, id: String, facing: String) -> bool:
	var data := _raw("res://assets/accessories/%s_%s_%s.png" % [slot, id, facing]).get_data()
	var cs := _cell_of(slot)
	var w := cs * NFRAMES * 4
	var touched := 0
	var any := 0
	for f in NFRAMES:
		for k in cs:
			for pt in [Vector2i(k, 0), Vector2i(k, cs - 1), Vector2i(0, k), Vector2i(cs - 1, k)]:
				if data[pt.y * w + (f * cs + pt.x) * 4 + 3] != 0:
					touched += 1
		for y in cs:
			for x in cs:
				if data[y * w + (f * cs + x) * 4 + 3] != 0:
					any += 1
	return touched == 0 and any > 0


# does the overlay sprite of every slot show cell `idx` at the origin of that cell, for the body sprite's current frame?
func _synced(spr: AnimatedSprite2D, gear: Node, want_slots: Array) -> bool:
	var anim := String(spr.animation)
	var tex := spr.sprite_frames.get_frame_texture(anim, spr.frame) as AtlasTexture
	var idx := floori(tex.region.position.x / float(FW))
	var facing := "right" if anim.ends_with("_right") else "left"
	if not gear.visible:
		return false
	for slot in want_slots:
		var o: Array = _origins(facing, str(KIND[slot]))[idx]
		var at := spr.offset - tex.get_size() * 0.5 + Vector2(float(o[0]), float(o[1]))
		var cs := _cell_of(slot)
		var s: Sprite2D = gear.get_node(slot)
		if not s.visible or s.region_rect != Rect2(idx * cs, 0, cs, cs) or s.position != at:
			return false
		if not str(s.texture.resource_path).ends_with("_%s.png" % facing):
			return false
	return true


func _count(data: PackedByteArray, col: Color) -> int:
	var n := 0
	for i in range(0, data.size(), 4):
		if data[i + 3] > 0 and data[i] == col.r8 and data[i + 1] == col.g8 and data[i + 2] == col.b8:
			n += 1
	return n


func _init() -> void:
	await process_frame
	var look := root.get_node("Look")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var player = load("res://scripts/player.gd")
	gear_script = load("res://scripts/head_gear.gd")
	d.settings_path = "user://test_acc_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://test_acc_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	DirAccess.remove_absolute(d.settings_path)

	# ---- the style list and the files
	_check(look.ACC_STYLES.glasses == ["thin", "thick", "round", "aviator"], "four glasses styles")
	_check(look.ACC_STYLES.beard == ["stubble", "goatee", "full", "moustache"], "four facial hair styles")
	_check(look.ACC_STYLES.hat == ["beanie", "cap", "hardhat", "santa", "bucket", "party"], "six hats")
	_check(look.ACC_STYLES.badge == ["name"] and look.ACC_STYLES.lanyard == ["conference"] and look.ACC_STYLES.watch == ["silver", "gold", "sport"], "a name sticker, a conference lanyard and three watches")
	_check(gear_script.SLOTS == SLOTS and gear_script.KIND == KIND and gear_script.CELLS == CELLS, "the overlay's slots, kinds and cell sizes are what the sheets were made with")
	_check(look.default_acc() == {"glasses": "", "beard": "", "hat": "", "badge": "", "lanyard": "", "watch": "", "beard_color": "", "frame_color": ""}, "the default acc is empty")
	_check(look.acc_ids("glasses") == ["", "thin", "thick", "round", "aviator"], "acc_ids lists none first")
	var files_ok := true
	for slot in SLOTS:
		for id in look.ACC_STYLES[slot]:
			for facing in ["right", "left"]:
				var img := _raw("res://assets/accessories/%s_%s_%s.png" % [slot, id, facing])
				files_ok = files_ok and img.get_width() == _cell_of(slot) * NFRAMES and img.get_height() == _cell_of(slot)
	_check(files_ok, "every style has a 129 cell sheet per facing (32x32 cells, 40x40 for hats, 16x16 for watches)")
	var tables_ok := true
	for kind in CELLS:
		for facing in ["right", "left"]:
			tables_ok = tables_ok and _origins(facing, kind).size() == NFRAMES
	_check(tables_ok, "one origin table per kind and facing, 129 pairs")
	_check(gear_script.frame_index("idle_right", 0) == 0 and gear_script.frame_index("hurt_right", 0) == 25 and gear_script.frame_index("death_left", 0) == 28 and gear_script.frame_index("nope_right", 0) == -1, "the START table maps animations to sheet indexes")
	_check(gear_script.frame_index("toss_left", 5) == 128 and gear_script.frame_index("toss_left", 6) == -1, "the last frame is 128 and past it hides")
	# sanitize and the helpers
	var bad: Dictionary = look.sanitize_acc({"glasses": "monocle", "beard": "full", "hat": "tophat", "beard_color": "#3A5FB0", "frame_color": "red", "junk": 1})
	_check(bad.glasses == "" and bad.beard == "full" and bad.hat == "" and bad.beard_color == "3a5fb0" and bad.frame_color == "" and not bad.has("junk"), "sanitize_acc drops unknown ids and bad colours")
	_check(look.sanitize_acc("not a dict") == look.default_acc(), "sanitize_acc survives a non dictionary")
	look.acc = look.default_acc()
	_check(look.set_acc("glasses", "round") and look.acc.glasses == "round", "set_acc sets a style")
	_check(not look.set_acc("glasses", "monocle") and not look.set_acc("tie", "red") and look.acc.glasses == "round", "set_acc refuses unknown ids and slots")
	look.cycle_acc("glasses", 1)
	_check(look.acc.glasses == "aviator", "cycle_acc steps")
	look.cycle_acc("glasses", 1)
	_check(look.acc.glasses == "", "cycle_acc wraps through none")
	look.cycle_acc("beard", -1)
	_check(look.acc.beard == "moustache", "cycle_acc goes back")
	look.acc = look.default_acc()
	# colours: the frame follows frame_color (or the style default), the beard the hair or beard_color
	var lk: Dictionary = look.default_look()
	_check(look.frame_color({"glasses": "thin"}) == "1e1e26" and look.frame_color({"glasses": "round"}) != "1e1e26" and look.frame_color({"frame_color": "ff0000"}) == "ff0000", "the frame colour: art default, metal for the wire styles, or the chosen one")
	var pal_def: PackedColorArray = look.palette(lk, {})
	var src: PackedColorArray = look.sources()
	var i_beard := -1
	var i_frame := -1
	for i in look.SOURCES.size():
		if look.SOURCES[i][1] == "beard" and int(look.SOURCES[i][2]) == 0:
			i_beard = i
		if look.SOURCES[i][1] == "frame":
			i_frame = i
	_check(pal_def[i_beard].is_equal_approx(Color.html(lk.hair)), "the beard is the hair colour by default")
	_check(look.palette(lk, {"beard_color": "3a5fb0"})[i_beard].is_equal_approx(Color.html("3a5fb0")), "beard_color recolours the beard")
	_check(look.palette(lk, {"frame_color": "ff0000"})[i_frame].is_equal_approx(Color.html("ff0000")), "frame_color recolours the glasses frame")
	var hair_idx := 3
	_check(look.palette(lk, {"beard_color": "3a5fb0"})[hair_idx].is_equal_approx(look.palette(lk, {})[hair_idx]), "a beard colour leaves the hair alone")

	# ---- golden: the overlay on the body equals a prebaked character with the accessory as a real layer
	for g in GOLDEN:
		for facing in ["right", "left"]:
			_golden(g[0], g[1], facing)
	# every accessory pixel fits its cell (the generator asserts it too); no pixel touches the cell border
	var fit := true
	for slot in SLOTS:
		for id in look.ACC_STYLES[slot]:
			for facing in ["right", "left"]:
				fit = fit and _ring_clear(slot, id, facing)
	_check(fit, "every accessory pixel is inside its cell with a free border, in all 129 frames (death included)")

	# ---- the frames sit on the face: eyes and brows stay (sunglasses cover the eyes on purpose)
	for facing in ["right", "left"]:
		var body := _raw("res://assets/characters/office_intern_%s.png" % facing)
		var org := _origins(facing)
		var f0 := body.get_region(Rect2i(0, 0, FW, FH)).get_data()
		var white0 := _count(f0, Color8(255, 255, 255))
		var pupil0 := _count(f0, Color8(58, 36, 24))
		var brow0 := _count(f0, Color8(107, 52, 22))
		for id in look.ACC_STYLES.glasses:
			var cells := _raw("res://assets/accessories/glasses_%s_%s.png" % [id, facing])
			var comp := _composite(body, cells, org, 0)
			if id == "aviator":
				_check(_count(comp, Color8(255, 255, 255)) < white0 - 10, "aviator %s: dark lenses cover the eyes" % facing)
				continue
			_check(white0 - _count(comp, Color8(255, 255, 255)) <= (4 if id == "round" else 0) and _count(comp, Color8(58, 36, 24)) == pupil0 and _count(comp, Color8(107, 52, 22)) == brow0, "glasses %s %s: both eyes, the pupils and the brows stay visible (the round rings clip four eye-corner pixels)" % [id, facing])
		for id in look.ACC_STYLES.beard:
			var cells := _raw("res://assets/accessories/beard_%s_%s.png" % [id, facing])
			var comp := _composite(body, cells, org, 0)
			_check(_count(comp, Color8(138, 74, 46)) == _count(f0, Color8(138, 74, 46)) and _count(comp, Color8(255, 255, 255)) == white0, "beard %s %s: the mouth and eyes stay clear" % [id, facing])

	# ---- sync with the body sprite
	var mine: Dictionary = look.default_look()
	mine["hair_style"] = "long"
	mine["acc"] = {"glasses": "round", "beard": "full", "hat": "beanie", "badge": "name", "lanyard": "conference", "watch": "gold"}
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = look.frames_for("office_intern", true, mine)
	spr.offset = Vector2(0, -40)
	look.apply(spr, "office_intern", true, mine)
	root.add_child(spr)
	var gear: Node = spr.get_node_or_null("HeadGear")
	_check(gear != null and gear.get_parent() == spr, "Look.apply puts a HeadGear child on the body sprite")
	_check(gear.get_child_count() == SLOTS.size() and spr.material != null, "one Sprite2D per slot, the body has the shader")
	var all_ok := true
	var n := 0
	var first_bad := ""
	for anim in spr.sprite_frames.get_animation_names():
		for f in spr.sprite_frames.get_frame_count(anim):
			spr.animation = anim
			spr.frame = f
			n += 1
			if not _synced(spr, gear, SLOTS):
				all_ok = false
				if first_bad == "":
					first_bad = "%s %d" % [anim, f]
	_check(all_ok and n > 240, "every animation frame of both facings is in sync at once, no process frame needed (%d frames, first bad: %s)" % [n, first_bad])
	_check(gear.get_node("glasses").material != null and gear.get_node("glasses").material.shader == look.shader(), "the overlay uses the palette shader")
	# backwards sitdown (stand up), played for real
	spr.play("sitdown_right", -1.0, true)
	var back_ok := true
	var seen: Array = []
	for k in 30:
		await process_frame
		back_ok = back_ok and _synced(spr, gear, SLOTS)
		if not seen.has(spr.frame):
			seen.append(spr.frame)
	_check(back_ok and seen.size() == 2, "backwards sitdown stays in sync (frames seen %s)" % str(seen))
	# a one-shot to its end and a loop
	for anim in ["hurt_left", "sitstretch_right", "walk_left", "dance_right", "sitdown_left"]:
		spr.play(anim)
		var ok := true
		for k in 40:
			await process_frame
			ok = ok and _synced(spr, gear, SLOTS)
		_check(ok, "%s plays in sync" % anim)
	# pause() while jumping and a frame set by hand
	spr.play("jump_right")
	spr.pause()
	var jump_ok := true
	for f in 3:
		spr.frame = f
		jump_ok = jump_ok and _synced(spr, gear, SLOTS)
		await process_frame
		jump_ok = jump_ok and _synced(spr, gear, SLOTS)
	_check(jump_ok, "pause() and a hand-set frame (the jump) stay in sync")
	# an animation the START table does not know hides the overlay
	var odd := SpriteFrames.new()
	odd.add_animation("zzz_right")
	odd.add_frame("zzz_right", spr.sprite_frames.get_frame_texture("idle_right", 0))
	spr.sprite_frames = odd
	spr.animation = "zzz_right"
	await process_frame
	_check(not gear.visible, "an animation without a START entry hides the overlay")
	spr.sprite_frames = look.frames_for("office_intern", true, mine)
	spr.play("idle_right")
	await process_frame
	_check(gear.visible and _synced(spr, gear, SLOTS), "and it comes back with the next known animation")
	# a stock character on the same sprite: no overlay
	look.apply(spr, "office_dan", false, mine)
	_check(not gear.visible and spr.material == null, "a stock character has no overlay")
	look.apply(spr, "office_intern", true, mine)
	_check(gear.visible and _synced(spr, gear, SLOTS), "the custom person gets it back")
	# a copy with another look dictionary, and the global acc not leaking into a copy
	look.acc = {"glasses": "thin", "beard": "stubble", "hat": "", "badge": "", "lanyard": "", "watch": "", "beard_color": "", "frame_color": ""}
	var other: Dictionary = look.default_look()
	var spr2 := AnimatedSprite2D.new()
	spr2.sprite_frames = look.frames_for("office_intern", true, other)
	look.apply(spr2, "office_intern", true, other)
	root.add_child(spr2)
	var gear2: Node = spr2.get_node("HeadGear")
	await process_frame
	_check(not gear2.get_node("glasses").visible and not gear2.get_node("beard").visible, "an NPC copy whose look has no acc wears none (the player's does not leak)")
	var spr3 := AnimatedSprite2D.new()
	spr3.sprite_frames = look.frames_for("office_intern", true, {})
	look.apply(spr3, "office_intern", true, {})
	root.add_child(spr3)
	var gear3: Node = spr3.get_node("HeadGear")
	await process_frame
	_check(gear3.get_node("glasses").visible and gear3.get_node("beard").visible and gear3.get_node("glasses").texture.resource_path.contains("glasses_thin"), "an empty look dictionary wears the player's Look.acc")
	# the player's acc changing while the sprite stands there
	look.set_acc("glasses", "aviator")
	await process_frame
	_check(gear3.get_node("glasses").texture.resource_path.contains("glasses_aviator"), "a changed Look.acc is picked up without another apply")
	look.set_acc("glasses", "")
	await process_frame
	_check(not gear3.get_node("glasses").visible and gear3.get_node("beard").visible, "removing the glasses hides that slot only")
	for s in [spr, spr2, spr3]:
		s.free()

	# ---- the real player: a character switch and back
	look.acc = look.default_acc()
	look.set_acc("glasses", "thick")
	look.set_acc("beard", "goatee")
	look.active = true
	player.current_character = "office_intern"
	var pl = load("res://scenes/player.tscn").instantiate()
	root.add_child(pl)
	await process_frame
	var pg: Node = pl.sprite.get_node_or_null("HeadGear")
	_check(pg != null and pg.visible and _synced(pl.sprite, pg, ["beard", "glasses"]), "the player wears the overlay of Look.acc")
	pl.sprite.play("walk_left")
	await process_frame
	await process_frame
	_check(_synced(pl.sprite, pg, ["beard", "glasses"]), "and follows the player's own animation changes")
	var anim_before: String = pl.sprite.animation
	var frame_before: int = pl.sprite.frame
	pl._switch_character("office_dan")
	await process_frame
	_check(pl.sprite.animation == anim_before and not pg.visible and pl.sprite.material == null, "_switch_character to a stock person hides the overlay and keeps the animation")
	look.active = true
	pl._load_character("office_intern")
	pl.sprite.animation = anim_before
	pl.sprite.frame = frame_before
	await process_frame
	_check(pg.visible and _synced(pl.sprite, pg, ["beard", "glasses"]), "back to the custom person: the overlay is back in sync")
	pl.free()

	# ---- the hurt flash: frames 25 and 28 carry flashed overlay colours the shader maps
	var bright: Dictionary = look.default_look()
	bright["hair"] = "3a5fb0"
	bright["skin"] = "8d5524"
	var bacc := {"glasses": "aviator", "beard": "full", "beard_color": "e05a9a", "frame_color": "ff00ff"}
	var pal_b: PackedColorArray = look.palette(bright, bacc)
	var flashed_ok := true
	var flashed := 0
	for g in [["glasses", "aviator"], ["glasses", "round"], ["beard", "full"], ["beard", "stubble"], ["hat", "cap"], ["hat", "party"], ["hat", "bucket"], ["hat", "santa"], ["lanyard", "conference"], ["badge", "name"], ["watch", "sport"], ["watch", "gold"]]:
		var gs := _cell_of(str(g[0]))
		for facing in ["right", "left"]:
			var cells := _raw("res://assets/accessories/%s_%s_%s.png" % [g[0], g[1], facing])
			for f in [25, 28]:
				var cell := cells.get_region(Rect2i(f * gs, 0, gs, gs))
				for y in gs:
					for x in gs:
						var px := cell.get_pixel(x, y)
						if px.a == 0.0:
							continue
						var out: Color = look.map_color(px, bright, bacc)
						var hit := -1
						for i in src.size():
							if hit < 0 and Vector3(px.r - src[i].r, px.g - src[i].g, px.b - src[i].b).length() < 0.004:
								hit = i  # an unflashed colour (the outline, a kept colour, white)
						for i in src.size():
							var fl: Color = src[i].lerp(Color.WHITE, 0.7)
							if hit < 0 and Vector3(px.r - fl.r, px.g - fl.g, px.b - fl.b).length() < 0.012:
								hit = i + 1000
						if hit < 0:
							flashed_ok = false
						elif hit >= 1000:
							flashed += 1
							flashed_ok = flashed_ok and out.is_equal_approx(pal_b[hit - 1000].lerp(Color.WHITE, 0.7))
						else:
							flashed_ok = flashed_ok and out.is_equal_approx(pal_b[hit])
	_check(flashed_ok and flashed > 100, "frames 25 and 28: the overlay pixels (every kind) are flashed source colours and the shader maps them to the flash of the new colour (%d flashed pixels)" % flashed)
	_check(look.palette(bright, bacc)[i_frame].is_equal_approx(Color.html("ff00ff")), "the frame recolour reaches the table")

	# ---- save and restore
	look.look = look.default_look()
	look.look["name"] = "ACCY"
	look.acc = look.default_acc()
	look.set_acc("glasses", "round")
	look.set_acc("beard", "goatee")
	look.acc["beard_color"] = "3a5fb0"
	look.acc["frame_color"] = "b8bcc4"
	var want_acc: Dictionary = look.acc.duplicate()
	look.active = true
	look.save_settings(true)
	look.acc = look.default_acc()
	look.load_settings()
	_check(look.acc == want_acc and look.active, "the settings file keeps and restores acc")
	var cfg := ConfigFile.new()
	cfg.load(d.settings_path)
	cfg.erase_section_key("look", "acc")
	cfg.save(d.settings_path)
	look.acc = want_acc.duplicate()
	look.load_settings()
	_check(look.acc == look.default_acc(), "old settings without acc load with none")
	look.acc = want_acc.duplicate()
	look.active = true
	player.current_character = "office_intern"
	c.new_game("tech")
	c.save()
	look.acc = look.default_acc()
	look.look = look.default_look()
	look.active = false
	_check(c.continue_game("tech") and look.is_custom() and look.acc == want_acc, "Continue restores acc with the look")
	_check(look.to_dict().acc == want_acc, "to_dict carries acc")
	cfg = ConfigFile.new()
	cfg.load(c.save_path("tech"))
	var old_look: Dictionary = cfg.get_value("campaign", "look", {})
	old_look.erase("acc")
	cfg.set_value("campaign", "look", old_look)
	cfg.save(c.save_path("tech"))
	look.acc = want_acc.duplicate()
	_check(c.continue_game("tech") and look.is_custom() and look.acc == look.default_acc(), "an old save without acc loads with none")
	look.from_dict({})
	_check(look.acc == look.default_acc(), "a stock character's empty look clears acc")
	DirAccess.remove_absolute(c.save_path("tech"))
	DirAccess.remove_absolute(d.settings_path)

	# ---- level 3 steps c and d: the colours, unlocks, hats and the old tree
	await _steps_c_d(look)

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)


func _steps_c_d(look: Node) -> void:
	var career := root.get_node("Career")
	var saved_earned: Dictionary = career.earned.duplicate()
	var saved_counters: Dictionary = career.counters.duplicate()
	var toasts: bool = career.toasts
	career.toasts = false
	career.earned = {}
	career.counters = {}
	look.acc = look.default_acc()
	look.look = look.default_look()

	# every new colour is its own KEEP, far enough from every other source or kept colour (a pixel inside 0.03 of two would be matched wrong)
	var src: PackedColorArray = look.sources()
	var close := 0
	for i in src.size():
		for j in range(i + 1, src.size()):
			if Vector3(src[i].r - src[j].r, src[i].g - src[j].g, src[i].b - src[j].b).length() < 0.06:
				close += 1
	_check(close == 0, "every source and kept colour is 0.06 or more from every other (%d close pairs)" % close)
	var flash_clash := 0
	for i in src.size():
		var fl: Color = src[i].lerp(Color.WHITE, 0.7)
		for j in src.size():
			if i != j and Vector3(fl.r - src[j].r, fl.g - src[j].g, fl.b - src[j].b).length() < 0.03:
				flash_clash += 1
	_check(flash_clash == 0, "no flashed colour is within the match tolerance of another colour (%d)" % flash_clash)

	# the unlock table: one entry per glasses / beard / hat style, starter styles free, the rest behind a real medal
	var by_slot := {"glasses": 0, "beard": 0, "hat": 0}
	var medal_ok := true
	for slot in by_slot:
		for id in look.ACC_STYLES[slot]:
			var n := 0
			for u in career.UNLOCKS:
				if str(u.kind) == slot and str(u.value) == id:
					n += 1
					if str(u.medal) != "" and career.medal(str(u.medal)).is_empty():
						medal_ok = false
			by_slot[slot] += n
			_check(n == 1, "%s %s has exactly one UNLOCKS entry" % [slot, id])
	_check(medal_ok, "every locked style points at a real medal")
	var locked: Array = []
	for u in career.UNLOCKS:
		if str(u.kind) in ["glasses", "beard", "hat"] and str(u.medal) != "":
			locked.append(str(u.value) + ":" + str(u.medal))
	locked.sort()
	_check(locked == ["hardhat:bag_man", "party:people_person", "santa:old_tree"], "three hats are locked: the hard hat (warehouse medal), the Santa hat (old tree) and the party hat (outings) (%s)" % str(locked))
	_check(look.acc_ids("hat") == ["", "beanie", "cap", "bucket"] and look.acc_locked("hat") == ["hardhat", "santa", "party"], "acc_ids lists only the unlocked hats, acc_locked the rest")
	_check(look.acc_title("hat", "cap") == "BALL CAP" and look.acc_title("watch", "gold") == "GOLD" and look.acc_title("glasses", "") == "NONE" and look.acc_title("badge", "name") == "HELLO TAG", "titles: the patchable UNLOCKS title or the built in one")

	# demotion: sanitize, set_acc, cycling, loading
	var dirty: Dictionary = look.sanitize_acc({"hat": "hardhat", "glasses": "aviator", "beard": "full"})
	_check(dirty.hat == "" and dirty.glasses == "aviator" and dirty.beard == "full", "a locked hat becomes none in sanitize_acc (free styles stay)")
	_check(not look.set_acc("hat", "santa") and look.acc.hat == "", "set_acc refuses a locked hat")
	look.set_acc("hat", "cap")
	look.cycle_acc("hat", 1)
	_check(look.acc.hat == "bucket", "cycling skips the locked hats")
	look.cycle_acc("hat", 1)
	_check(look.acc.hat == "", "and wraps through none")
	career.earned["bag_man"] = true
	_check(look.set_acc("hat", "hardhat") and look.sanitize_acc({"hat": "hardhat"}).hat == "hardhat", "the BAG MAN medal unlocks the hard hat")
	_check(look.acc_locked("hat") == ["santa", "party"], "and it leaves the locked list")
	# a save that was made with the hat, loaded after the medal is gone: none
	look.acc = look.default_acc()
	look.set_acc("hat", "hardhat")
	var saved: Dictionary = look.to_dict()
	career.earned = {}
	look.from_dict(saved)
	_check(look.acc.hat == "", "an old save with a hat whose medal is not earned loads with none")
	career.earned["people_person"] = true
	look.from_dict(saved)
	_check(look.acc.hat == "", "and the party hat is not the hard hat")
	career.earned["bag_man"] = true
	look.from_dict(saved)
	_check(look.acc.hat == "hardhat", "the same save with the medal keeps the hat")
	# a hat that is worn when it gets locked: an NPC copy's dictionary is sanitized too
	career.earned = {}
	_check(look.acc_of({"hair_style": "side", "acc": {"hat": "santa"}}).hat == "", "an NPC copy's locked hat is none too")
	# RANDOM never rolls a locked style, and the hat draws come after the old ones
	var seen_hat := {}
	var seen_any := false
	for k in 60:
		look.randomize_look()
		seen_hat[str(look.acc.hat)] = true
		seen_any = seen_any or look.acc.glasses != "" or look.acc.beard != "" or look.acc.badge != "" or look.acc.lanyard != "" or look.acc.watch != ""
	_check(not seen_hat.has("hardhat") and not seen_hat.has("santa") and not seen_hat.has("party") and seen_hat.has("beanie") and seen_any, "RANDOM draws accessories, never a locked hat (%s)" % str(seen_hat.keys()))
	look.acc = look.default_acc()

	# the hat hair fallback: a tall style shows as another while a hat is worn; the look keeps the chosen one
	var lk: Dictionary = look.default_look()
	for pair in [["spiky", "short"], ["curly", "short"], ["bun", "ponytail"]]:
		lk["hair_style"] = pair[0]
		_check(look.sheet_for("office_intern", true, {"hair_style": pair[0], "acc": {"hat": "cap"}}) == "custom_intern_" + pair[1], "%s under a hat is %s" % pair)
		_check(look.sheet_for("office_intern", true, {"hair_style": pair[0], "acc": {}}) == "custom_intern_" + pair[0], "%s without a hat stays %s" % [pair[0], pair[0]])
	for style in ["side", "short", "receding", "long", "bob", "ponytail", "bald"]:
		_check(look.hair_shown({"hair_style": style}, {"hat": "beanie"}) == style, "%s is not changed by a hat" % style)
	look.look = look.default_look()
	look.look["hair_style"] = "spiky"
	look.acc = look.default_acc()
	look.set_acc("hat", "cap")
	_check(look.sheet_for("office_intern", true) == "custom_intern_short" and str(look.look.hair_style) == "spiky", "the player's sheet follows the hat, the chosen style is kept")
	look.acc.hat = ""
	_check(look.sheet_for("office_intern", true) == "custom_intern_spiky", "and goes back when the hat comes off")
	for style in look.HAT_HAIR:
		_check(style in look.HAIR_STYLES and look.HAT_HAIR[style] in look.HAIR_STYLES and look.HAT_HAIR[style] not in look.HAT_HAIR, "HAT_HAIR %s names real styles that stay under a hat" % style)

	# the old tree in the warehouse: E gives the OLD TREE medal and with it the Santa hat
	var wh = load("res://scenes/warehouse.tscn").instantiate()
	root.add_child(wh)
	await process_frame
	var tree: Node = wh.get_node_or_null("Fx/Tree")
	var use: Node = wh.get_node_or_null("Interactables/UseTree")
	_check(tree != null and use != null and str(tree.kind) == "old_tree" and use.target == use.get_path_to(tree), "the warehouse has an old tree you can use (kind old_tree, its own zone)")
	_check(not career.has_medal("old_tree") and not look.set_acc("hat", "santa"), "before the tree: no medal, no Santa hat")
	tree.play()
	_check(career.has_medal("old_tree") and career.unlocked("hat_santa") and look.set_acc("hat", "santa"), "E on the old tree gives the OLD TREE medal and the Santa hat")
	var n_before: int = int(career.counters.get("old_tree", 0))
	tree.play()
	_check(int(career.counters.get("old_tree", 0)) == n_before + 1 and career.earned.size() == 1, "a second E is only a remark (the medal stays, nothing else is awarded)")
	wh.queue_free()
	# the party hat comes with three team outings
	look.acc = look.default_acc()
	career.counters["outings"] = 2
	career.check_medals()
	_check(not look.set_acc("hat", "party"), "the party hat is still locked after two outings")
	career.add("outings")
	_check(look.set_acc("hat", "party"), "and unlocks with the third")
	look.acc = look.default_acc()

	career.earned = saved_earned
	career.counters = saved_counters
	career.toasts = toasts
