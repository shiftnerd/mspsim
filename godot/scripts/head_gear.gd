extends Node2D
# THE HEAD OVERLAY (roadmap R15 level 3 step b): glasses and facial hair drawn over a custom person's head by one Sprite2D per slot.
# A child of the body's AnimatedSprite2D (so it sits above the body and below the held items and the headset, which are siblings
# added later, and it follows the sprite's transform and visibility): the player, an NPC copy (custom_look) and the select preview
# all get one from Look.apply. It NEVER plays an animation of its own: it reads the body sprite's current `animation` and `frame`,
# maps them to a sheet index with the same START table as held_item.gd (one const, no drift), and shows that 32x32 cell of
# assets/accessories/<slot>_<id>_<facing>.png at the position of the shared origin table head_origin_<facing>.json (both made by
# tools/make_head_sheets.lua). Backwards sitdown, one-shots, pause() while jumping, a character switch and the seated gestures
# all just change sprite.animation / sprite.frame, so there is nothing to drift; frame_changed and animation_changed resync at
# once (no frame of lag whatever the process order), _process is the safety net. An animation without a START entry hides it.
# The sprites use the body's palette shader (Look.make_material), so the colours and the hurt flash (sheet frames 25 and 28 are
# baked to white) match.

const HELD_ITEM := preload("res://scripts/held_item.gd")
const DIR := "res://assets/accessories/"
const SLOTS := ["beard", "glasses"]  # drawing order, lowest first (hats and the rest are later steps)
const CELL := 32
const FRAMES := 123

static var _origins := {}

var _sprite: AnimatedSprite2D = null
var _on := false
var _look: Dictionary = {}
var _sig := 0
var _ids := {}
var _slots := {}


# the cell origins (top left of the 32x32 cell in the 64x80 body frame) of a facing, 123 [x, y] pairs
static func origins(facing: String) -> Array:
	if not _origins.has(facing):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "head_origin_%s.json" % facing))
		_origins[facing] = parsed if parsed is Array else []
	return _origins[facing]


# the sheet index of an animation frame (the body sheet is 123 frames; the overlay sheets have the same 123 cells), -1 = none
static func frame_index(anim: String, frame: int) -> int:
	var parts := anim.rsplit("_", true, 1)
	if parts.size() < 2 or not HELD_ITEM.START.has(parts[0]):
		return -1
	var idx: int = int(HELD_ITEM.START[parts[0]]) + frame
	return idx if idx >= 0 and idx < FRAMES else -1


# Look.apply calls this: on = the sprite shows the custom person, look_dict = the look to wear (empty = the player's own)
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


func _slot_sprite(slot: String) -> Sprite2D:
	if not _slots.has(slot):
		var s := Sprite2D.new()
		s.name = slot
		s.centered = false
		s.region_enabled = true
		add_child(s)
		_slots[slot] = s
	return _slots[slot]


func _rebuild() -> void:
	_sig = _signature()
	var lk: Dictionary = _look if not _look.is_empty() else Look.look
	var ac: Dictionary = Look.acc_of(_look)
	for slot in SLOTS:
		var id := str(ac.get(slot, "")) if _on else ""
		_ids[slot] = id
		var s := _slot_sprite(slot)
		s.visible = id != ""
		s.material = Look.make_material(lk, ac) if id != "" else null
		s.set_meta("path", "")


func _sync() -> void:
	if not _on or _sprite == null or _sprite.sprite_frames == null:
		visible = false
		return
	var anim := String(_sprite.animation)
	var idx := frame_index(anim, _sprite.frame)
	var facing := "right" if anim.ends_with("_right") else "left"
	var table := origins(facing)
	if idx < 0 or idx >= table.size() or not _sprite.sprite_frames.has_animation(anim):
		visible = false
		return
	visible = true
	var top_left := _sprite.offset
	if _sprite.centered:
		var tex := _sprite.sprite_frames.get_frame_texture(anim, _sprite.frame)
		top_left -= tex.get_size() * 0.5 if tex != null else Vector2(32, 40)
	var at := top_left + Vector2(float(table[idx][0]), float(table[idx][1]))
	for slot in SLOTS:
		var id := str(_ids.get(slot, ""))
		if id == "":
			continue
		var s: Sprite2D = _slots[slot]
		var path := "%s%s_%s_%s.png" % [DIR, slot, id, facing]
		if str(s.get_meta("path", "")) != path:
			s.texture = load(path)
			s.set_meta("path", path)
		s.position = at
		s.region_rect = Rect2(idx * CELL, 0, CELL, CELL)


func _process(_delta: float) -> void:
	if _sig != _signature():  # the player's look (or acc) changed under us
		_rebuild()
	_sync()
