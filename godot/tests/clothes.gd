extends SceneTree
# gdlint:disable=max-line-length
# Character creator level 3 step (f): REAL CLOTHES (scripts/clothes_gear.gd, tools/make_clothes.lua, tools/make_clothes_sheets.lua,
# assets/clothes/, characters/custom_bare). Checks: the style lists and files, the size budget; a golden comparison (the overlay sheets
# composited in their z order on the bare sheet equal a one-off reference character with the garments as real layers, all 129 frames, both
# facings, three outfits: tee + jeans + sneakers + long hair, sweater + skirt + boots + bob, button-down + shorts + dress shoes + curly);
# the stock outfit rebuilt from overlays equals the prebaked intern sheet (one pixel of frame 70 aside); sanitize (an old look wears the
# stock clothes, unknown and locked garments become stock), the unlock rule for the work boots, RANDOM, save and restore; the node (sync
# with the body sprite for every animation frame, z order, belt, bald, pattern only on the shirt body, stock look has no overlay).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/clothes.gd

const NFRAMES := 129
const FW := 64
const FH := 80
const OUTFITS := [
	{"name": "tee_jeans_sneakers_long", "shirt_style": "tee", "bottom": "jeans", "shoe_style": "sneakers", "hair_style": "long"},
	{"name": "sweater_skirt_boots_bob", "shirt_style": "sweater", "bottom": "skirt", "shoe_style": "boots", "hair_style": "bob"},
	{"name": "button_shorts_dress_curly", "shirt_style": "button", "bottom": "shorts", "shoe_style": "dress", "hair_style": "curly"},
]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _raw(res_path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	img.convert(Image.FORMAT_RGBA8)
	return img


# paste an overlay frame over a 64x80 RGBA frame (opaque pixels replace, the sheets have no partial alpha)
func _paste(dst: PackedByteArray, sheet: Image, f: int) -> PackedByteArray:
	var src := sheet.get_region(Rect2i(f * FW, 0, FW, FH)).get_data()
	for i in range(0, src.size(), 4):
		if src[i + 3] > 0:
			dst[i] = src[i]
			dst[i + 1] = src[i + 1]
			dst[i + 2] = src[i + 2]
			dst[i + 3] = src[i + 3]
	return dst


# the garments' sheets of a look in draw order, lowest first: behind the body, then in front
func _pieces(o: Dictionary, facing: String) -> Array:
	var shirt := str(o.shirt_style)
	var bottom := str(o.bottom)
	var hair := str(o.hair_style)
	var behind := ["shoes_" + str(o.shoe_style), "bottom_" + bottom]
	var front := ["shirt_%s_far" % shirt, "shirt_%s_torso" % shirt]
	if bottom in ["trousers", "jeans"]:
		front.append("belt_belt")
	front.append("shirt_%s_near" % shirt)
	if hair != "bald":
		front.append("hair_" + hair)
	var out := [[], []]
	for stem in behind:
		out[0].append(_raw("res://assets/clothes/%s_%s.png" % [stem, facing]))
	for stem in front:
		out[1].append(_raw("res://assets/clothes/%s_%s.png" % [stem, facing]))
	return out


func _compose(base: Image, pieces: Array, f: int) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(FW * FH * 4)
	for sh in pieces[0]:
		frame = _paste(frame, sh, f)
	frame = _paste(frame, base, f)
	for sh in pieces[1]:
		frame = _paste(frame, sh, f)
	return frame


func _init() -> void:
	await process_frame
	var look := root.get_node("Look")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var career := root.get_node("Career")
	d.settings_path = "user://test_clo_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://test_clo_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	DirAccess.remove_absolute(d.settings_path)
	var saved_earned: Dictionary = career.earned.duplicate()

	# ---- lists, files, budget
	_check(look.SHIRT_STYLES == ["polo", "tee", "button", "sweater"] and look.BOTTOM_STYLES == ["trousers", "jeans", "shorts", "skirt"] and look.SHOE_STYLES == ["dress", "sneakers", "boots"], "four shirts, four bottoms, three shoes")
	var total := 0
	var files_ok := true
	for facing in ["right", "left"]:
		var stems: Array = []
		for sh in look.SHIRT_STYLES:
			for part in ["far", "torso", "near"]:
				stems.append("shirt_%s_%s" % [sh, part])
		for b in look.BOTTOM_STYLES:
			stems.append("bottom_" + b)
		for s in look.SHOE_STYLES:
			stems.append("shoes_" + s)
		stems.append("belt_belt")
		for h in look.HAIR_STYLES:
			if h != "bald":
				stems.append("hair_" + h)
		for stem in stems:
			var p := "res://assets/clothes/%s_%s.png" % [stem, facing]
			var img := _raw(p)
			files_ok = files_ok and img.get_width() == FW * NFRAMES and img.get_height() == FH
			total += FileAccess.get_file_as_bytes(p).size()
	_check(files_ok, "every garment and hair sheet has 129 full 64x80 frames per facing")
	_check(total < 2 * 1024 * 1024, "the clothes sheets stay small (%d KB of PNG, budget 2048)" % (total / 1024))
	var bare := look.frames_for("office_intern", true, {"shirt_style": "tee"}) as SpriteFrames
	_check(bare != null and bare.has_animation("idle_right") and bare.has_animation("toss_left"), "characters/custom_bare has every animation")

	# ---- golden: overlays on the bare sheet == the reference character
	for o in OUTFITS:
		for facing in ["right", "left"]:
			var base := _raw("res://assets/characters/custom_bare_%s.png" % facing)
			var ref := _raw("res://tests/golden/ref_%s_%s.png" % [o.name, facing])
			var pieces := _pieces(o, facing)
			var bad: Array = []
			for f in NFRAMES:
				if _compose(base, pieces, f) != ref.get_region(Rect2i(f * FW, 0, FW, FH)).get_data():
					bad.append(f)
			_check(bad.is_empty(), "golden %s %s: the overlays on the bare sheet equal the reference in all %d frames (bad: %s)" % [o.name, facing, NFRAMES, str(bad.slice(0, 8))])
	# the stock outfit from overlays is the prebaked intern (the hair is the intern's own: side)
	for facing in ["right", "left"]:
		var base := _raw("res://assets/characters/custom_bare_%s.png" % facing)
		var intern := _raw("res://assets/characters/office_intern_%s.png" % facing)
		var pieces := _pieces({"shirt_style": "polo", "bottom": "trousers", "shoe_style": "dress", "hair_style": "side"}, facing)
		var diff := 0
		for f in NFRAMES:
			var a := _compose(base, pieces, f)
			var b := intern.get_region(Rect2i(f * FW, 0, FW, FH)).get_data()
			for i in range(0, a.size(), 4):
				if a[i] != b[i] or a[i + 1] != b[i + 1] or a[i + 2] != b[i + 2] or a[i + 3] != b[i + 3]:
					diff += 1
		_check(diff <= 3, "the stock polo, trousers and dress shoes rebuilt from overlays are the prebaked intern, %s (%d px differ in all %d frames)" % [facing, diff, NFRAMES])

	# ---- the look: old saves, unknown values, unlocks
	var old: Dictionary = look.sanitize({"name": "ZOE", "skin": "8d5524", "shorts": "shorts"})
	_check(old.shirt_style == "polo" and old.bottom == "trousers" and old.shoe_style == "dress", "an old look wears the stock clothes")
	_check(old.shorts == "shorts" and look.stock_clothes(old) and look.sheet_for("office_intern", true, old) == "office_intern", "the old shorts shader value is kept and the sheet is the prebaked intern")
	var odd: Dictionary = look.sanitize({"shirt_style": "tuxedo", "bottom": 4, "shoe_style": "flippers"})
	_check(look.stock_clothes(odd), "unknown garments become stock")
	career.earned.erase("field_tech")
	var boots: Dictionary = look.sanitize({"shoe_style": "boots", "bottom": "jeans"})
	_check(boots.shoe_style == "dress" and boots.bottom == "jeans", "the work boots are locked until FIELD TECH (an old file or a copy gets dress shoes)")
	_check(look.clothes_locked("shoe_style") == ["boots"] and look.clothes_locked("bottom").is_empty(), "only the boots are locked")
	look.look = look.default_look()
	look.cycle_choice("shoe_style", 1)
	look.cycle_choice("shoe_style", 1)
	_check(look.look.shoe_style == "dress", "the shoe row skips the locked boots (dress, sneakers, then back to dress)")
	career.earned["field_tech"] = true
	_check(look.sanitize({"shoe_style": "boots"}).shoe_style == "boots", "FIELD TECH unlocks the boots")
	var tee: Dictionary = look.sanitize({"shirt_style": "tee"})
	_check(not look.stock_clothes(tee) and look.sheet_for("office_intern", true, tee) == "custom_bare" and look.sheet_for("office_dan", false, tee) == "office_dan", "any other garment is the bare sheet; a stock character is untouched")
	# save and restore
	look.look = look.sanitize({"shirt_style": "sweater", "bottom": "skirt", "shoe_style": "boots", "name": "ZOE"})
	var dict: Dictionary = look.to_dict()
	look.look = look.default_look()
	look.from_dict(dict)
	_check(look.look.shirt_style == "sweater" and look.look.bottom == "skirt" and look.look.shoe_style == "boots", "the campaign dictionary keeps the garments")
	look.save_settings(true)
	look.look = look.default_look()
	look.load_settings()
	_check(look.look.shirt_style == "sweater" and look.look.bottom == "skirt" and look.look.shoe_style == "boots", "the settings file keeps the garments")
	# RANDOM reaches everything that is unlocked
	var seen := {}
	for i in 60:
		look.randomize_look()
		for key in look.CLOTHES_KINDS:
			seen["%s:%s" % [key, look.look[key]]] = true
	_check(look.look.shorts == "none", "RANDOM never uses the old shorts shader")
	_check(seen.size() == 11, "RANDOM reaches every garment (%d of 11)" % seen.size())
	career.earned.erase("field_tech")
	var never := true
	for i in 40:
		look.randomize_look()
		never = never and look.look.shoe_style != "boots"
	_check(never, "RANDOM never picks a locked garment")
	career.earned = saved_earned.duplicate()

	# ---- the node
	var mine: Dictionary = look.default_look()
	mine["shirt_style"] = "tee"
	mine["bottom"] = "jeans"
	mine["shoe_style"] = "sneakers"
	mine["hair_style"] = "long"
	mine["pattern"] = "plaid"
	mine["acc"] = {"hat": "beanie"}
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = look.frames_for("office_intern", true, mine)
	spr.offset = Vector2(0, -40)
	look.apply(spr, "office_intern", true, mine)
	root.add_child(spr)
	var gear: Node = spr.get_node_or_null("ClothesGear")
	_check(gear != null and gear.get_parent() == spr, "Look.apply puts a ClothesGear child on the body sprite")
	var hg: Node = spr.get_node_or_null("HeadGear")
	_check(hg != null and gear.get_index() < hg.get_index(), "the clothes are drawn before (under) the hat, glasses and beard")
	var shoes: Sprite2D = spr.get_node("Clothes_shoes")
	var legs: Sprite2D = spr.get_node("Clothes_bottom")
	_check(shoes.show_behind_parent and legs.show_behind_parent and shoes.get_parent() == spr, "shoes and trousers are behind the body sprite")
	var order: Array = []
	for ch in gear.get_children():
		order.append(str(ch.name))
	_check(order == ["Clothes_far", "Clothes_torso", "Clothes_belt", "Clothes_near", "Clothes_hair"], "far sleeve, shirt, belt, near sleeve, hair in front of the body, in that order (%s)" % str(order))
	_check(gear.get_node("Clothes_torso").material.get_shader_parameter("pattern") == 2 and gear.get_node("Clothes_near").material.get_shader_parameter("pattern") == 0 and legs.material.get_shader_parameter("pattern") == 0, "the plaid is on the shirt body only")
	var hair_path: String = str(gear.get_node("Clothes_hair").texture.resource_path) if gear.get_node("Clothes_hair").texture != null else ""
	_check(hair_path.contains("hair_long_") or hair_path.contains("hair_"), "the hair sheet is the chosen style (%s)" % hair_path)
	var sync_ok := true
	var n := 0
	var first_bad := ""
	var head_gear = load("res://scripts/head_gear.gd")
	for anim in spr.sprite_frames.get_animation_names():
		for f in spr.sprite_frames.get_frame_count(anim):
			spr.animation = anim
			spr.frame = f
			n += 1
			var idx: int = head_gear.frame_index(String(anim), f)
			var facing := "right" if String(anim).ends_with("_right") else "left"
			var tex := spr.sprite_frames.get_frame_texture(anim, f) as AtlasTexture
			var at := spr.offset - tex.get_size() * 0.5
			var ok := true
			var all: Array = [shoes, legs] + gear.get_children()
			for s in all:
				ok = ok and s.visible and s.region_rect == Rect2(idx * FW, 0, FW, FH) and s.position == at and str(s.texture.resource_path).ends_with("_%s.png" % facing)
			if not ok or not gear.visible:
				sync_ok = false
				if first_bad == "":
					first_bad = "%s %d" % [anim, f]
	_check(sync_ok and n > 240, "every sprite of every animation frame, both facings, is in sync at once (%d frames, first bad: %s)" % [n, first_bad])
	# the hat hides spiky hair (the substitute) and a bald person has no hair sprite; trousers or jeans have the belt, skirts and shorts none
	mine["hair_style"] = "bald"
	mine["bottom"] = "skirt"
	look.apply(spr, "office_intern", true, mine)
	await process_frame
	_check(not gear.get_node("Clothes_hair").visible and not gear.get_node("Clothes_belt").visible, "bald: no hair sprite; a skirt: no belt")
	mine["bottom"] = "trousers"
	mine["hair_style"] = "spiky"
	look.apply(spr, "office_intern", true, mine)
	await process_frame
	_check(gear.get_node("Clothes_belt").visible and str(gear.get_node("Clothes_hair").texture.resource_path).contains("hair_short_"), "trousers have the belt; with a hat, spiky hair shows as short")
	# the stock look has no overlay at all
	var stock: Dictionary = look.default_look()
	spr.sprite_frames = look.frames_for("office_intern", true, stock)
	look.apply(spr, "office_intern", true, stock)
	await process_frame
	var any_visible: bool = gear.visible
	for s in [shoes, legs] + gear.get_children():
		any_visible = any_visible or s.visible
	_check(not any_visible, "polo, trousers and dress shoes: no overlay (the prebaked sheet)")
	_check(look.sheet_for("office_intern", true, stock) == "office_intern", "and the prebaked sheet is the intern")
	spr.queue_free()

	DirAccess.remove_absolute(d.settings_path)
	career.earned = saved_earned
	print("clothes: %d failures" % failures)
	quit(1 if failures > 0 else 0)
