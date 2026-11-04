extends Node2D
# REAL CLOTHES (roadmap R15 level 3 step f): the custom person's shirt, belt, trousers or skirt, shoes and hair drawn as OVERLAY sheets over
# the bare-skin base character (characters/custom_bare, made by tools/make_clothes.lua and tools/make_clothes_sheets.lua). Like HeadGear it
# NEVER plays an animation: each frame it reads the body sprite's `animation` and `frame`, maps them to the sheet index with the same START
# table (HeadGear.frame_index) and shows that 64x80 cell of assets/clothes/<piece>_<facing>.png at the body sprite's own top left (the clothes
# sheets are full body frames, so there is no origin table). Backwards sitdown, one-shots, pause(), the select preview's scale all just work.
# Z ORDER: the shoes and the trousers sit BEHIND the body sprite (show_behind_parent, so they are direct children of the body sprite), the far
# sleeve, shirt, belt, near sleeve and hair in front of it, in that order (the sheets are cut where the baked body layers cover a piece, see
# tools/make_clothes_sheets.lua). The node is a child of the body AnimatedSprite2D added by Look.apply BEFORE the HeadGear, so the hat,
# glasses and beard draw over the hair. It is only on while the person wears something other than the stock polo, trousers and dress shoes
# (those use the prebaked hairstyle sheets, so old looks and saves are unchanged).
# Colours: every sprite uses the body's palette shader; only the shirt body gets the PATTERN (sleeves, like on the prebaked sheet, stay plain).

const HEAD_GEAR := preload("res://scripts/head_gear.gd")
const DIR := "res://assets/clothes/"
const CELL := Vector2i(64, 80)
const FRAMES := 129
# [slot, behind the body]: drawing order, lowest first
const SLOTS := [["shoes", true], ["bottom", true], ["far", false], ["torso", false], ["belt", false], ["near", false], ["hair", false]]
const BELTED := ["trousers", "jeans"]  # the bottoms that have a belt over the shirt hem

var _sprite: AnimatedSprite2D = null
var _on := false
var _look: Dictionary = {}
var _sig := 0
var _files := {}
var _slots := {}


# Look.apply calls this: on = the sprite shows the custom person in non-stock clothes, look_dict = the look to wear (empty = the player's own)
func configure(on: bool, look_dict: Dictionary) -> void:
	_sprite = get_parent() as AnimatedSprite2D
	_on = on
	_look = look_dict
	if _sprite != null and not _sprite.frame_changed.is_connected(_sync):
		_sprite.frame_changed.connect(_sync)
		_sprite.animation_changed.connect(_sync)
	_rebuild()
	_sync()


func _signature() -> int:
	return hash([_on, _look if not _look.is_empty() else [Look.look, Look.acc]])


# the file stem (without _<facing>.png) of each slot for a look ("" = nothing drawn)
static func stems(lk: Dictionary, ac: Dictionary) -> Dictionary:
	var shirt := str(lk.get("shirt_style", "polo"))
	var bottom := str(lk.get("bottom", "trousers"))
	var hair := Look.hair_shown(lk, ac)
	return {
		"shoes": "shoes_" + str(lk.get("shoe_style", "dress")),
		"bottom": "bottom_" + bottom,
		"far": "shirt_%s_far" % shirt,
		"torso": "shirt_%s_torso" % shirt,
		"belt": "belt_belt" if bottom in BELTED else "",
		"near": "shirt_%s_near" % shirt,
		"hair": "" if hair == "bald" else "hair_" + hair,
	}


func _slot_sprite(slot: String, behind: bool) -> Sprite2D:
	if not _slots.has(slot):
		var s := Sprite2D.new()
		s.name = "Clothes_" + slot
		s.centered = false
		s.region_enabled = true
		if behind:
			s.show_behind_parent = true
			_sprite.add_child(s)  # behind the body: it has to be a direct child of the body sprite
		else:
			add_child(s)
		_slots[slot] = s
	return _slots[slot]


func _rebuild() -> void:
	_sig = _signature()
	if _sprite == null:
		return
	var lk: Dictionary = _look if not _look.is_empty() else Look.look
	var ac: Dictionary = Look.acc_of(_look)
	var st := stems(lk, ac)
	for row in SLOTS:
		var slot: String = row[0]
		var stem := str(st[slot]) if _on else ""
		_files[slot] = stem
		var s := _slot_sprite(slot, bool(row[1]))
		s.visible = stem != ""
		s.material = Look.make_piece_material(lk, ac, slot == "torso") if stem != "" else null
		s.set_meta("path", "")


func _sync() -> void:
	if _sprite == null:
		return
	var anim := String(_sprite.animation)
	var idx := HEAD_GEAR.frame_index(anim, _sprite.frame) if _on and _sprite.sprite_frames != null else -1
	var ok := idx >= 0 and idx < FRAMES and _sprite.sprite_frames.has_animation(anim)
	visible = ok
	var facing := "right" if anim.ends_with("_right") else "left"
	var top_left := _sprite.offset
	if ok and _sprite.centered:
		var tex := _sprite.sprite_frames.get_frame_texture(anim, _sprite.frame)
		top_left -= tex.get_size() * 0.5 if tex != null else Vector2(32, 40)
	for row in SLOTS:
		var slot: String = row[0]
		var stem := str(_files.get(slot, ""))
		if not _slots.has(slot):
			continue
		var s: Sprite2D = _slots[slot]
		if stem == "" or not ok:
			s.visible = false
			continue
		s.visible = true
		var path := "%s%s_%s.png" % [DIR, stem, facing]
		if str(s.get_meta("path", "")) != path:
			s.texture = load(path)
			s.set_meta("path", path)
		s.position = top_left
		s.region_rect = Rect2(idx * CELL.x, 0, CELL.x, CELL.y)


func _process(_delta: float) -> void:
	if _sig != _signature():  # the player's look changed under us
		_rebuild()
	_sync()


func _exit_tree() -> void:
	for row in SLOTS:
		if bool(row[1]) and _slots.has(row[0]) and is_instance_valid(_slots[row[0]]):
			(_slots[row[0]] as Node).queue_free()
