extends SceneTree
# Contact strips of the head accessories (needs a renderer, not --headless): user://acc_strip_<facing>.png (whole people, one row per
# combo) and user://acc_head_<facing>.png (the same poses, head close ups). Every person is a real body sprite with a HeadGear child
# made by Look.apply from its own look dict (the NPC copy path), paused on one frame of each pose.
#   Godot --path godot --fixed-fps 60 -s res://tests/accessories_shots.gd

const COMBOS := [
	{
		"look": {"name": "ZOE", "hair_style": "long", "skin": "f3b488", "hair": "9a5124", "shirt": "4f7fd0", "pants": "3a3f66", "shoes": "5a3522"},
		"acc": {"glasses": "round", "beard": "stubble"}
	},
	{
		"look": {"name": "RUSS", "hair_style": "bald", "skin": "c68642", "hair": "2a1c14", "shirt": "8c2b40", "pants": "2b3550", "shoes": "2a2a33"},
		"acc": {"glasses": "thick", "beard": "full", "beard_color": "8a8f9a"}
	},
	{
		"look": {"name": "KIT", "hair_style": "spiky", "skin": "fbd7bc", "hair": "e05a9a", "shirt": "2f6b3a", "pants": "7a3030", "shoes": "cfc8b5"},
		"acc": {"glasses": "aviator", "beard": "moustache", "frame_color": "e8e8ec"}
	},
	{
		"look": {"name": "ABE", "hair_style": "ponytail", "skin": "6b3e22", "hair": "e8d090", "shirt": "f4f2ea", "pants": "3f5e8e", "shoes": "5a3522"},
		"acc": {"glasses": "thin", "beard": "goatee"}
	},
]
const POSES := [
	["idle", 0],
	["walk", 2],
	["run", 2],
	["hurt", 0],
	["hurt", 1],
	["death", 1],
	["death", 5],
	["type", 1],
	["sitscratch", 3],
	["sityawn", 2],
	["sitlook", 2],
	["dance", 3],
]

var frame := 0
var gear_script: GDScript = null
var combos: Array = COMBOS
var poses: Array = POSES
var acc_cols: Array = []
var facing := "right"
var vp: SubViewport = null
var rows: Array = []


func _initialize() -> void:
	root.get_node("Game").title_mode = false
	gear_script = load("res://scripts/head_gear.gd")


func _build(side: String, zoom_head: bool) -> void:
	if vp != null:
		vp.queue_free()
	var cw := 40 if zoom_head else 64
	var ch := 40 if zoom_head else 80
	rows.clear()
	vp = SubViewport.new()
	vp.size = Vector2i(cw * poses.size(), ch * combos.size())
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("8a93a8")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var look := root.get_node("Look")
	for r in combos.size():
		for c in poses.size():
			var lk: Dictionary = combos[r].look.duplicate()
			lk["acc"] = acc_cols[c] if not acc_cols.is_empty() else combos[r].acc
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = look.frames_for(look.BASE, true, lk)
			spr.offset = Vector2(0, -40)
			var anim := "%s_%s" % [poses[c][0], side]
			var fr := mini(int(poses[c][1]), spr.sprite_frames.get_frame_count(anim) - 1)
			if zoom_head:
				# the face cell of this pose at the top left of a clipped 40x40 box: the head close up
				var o: Array = gear_script.origins(side)[gear_script.frame_index(anim, fr)]
				var box := Control.new()
				box.position = Vector2(c * cw, r * ch)
				box.size = Vector2(cw, ch)
				box.clip_contents = false
				vp.add_child(box)
				spr.position = Vector2(4 - float(o[0]) + 32, 4 - float(o[1]) + 80)
				box.add_child(spr)
			else:
				spr.position = Vector2(c * cw + cw / 2, r * ch + ch)
				vp.add_child(spr)
			look.apply(spr, look.BASE, true, lk)
			spr.play(anim)
			spr.pause()
			spr.frame = fr
			rows.append(spr)


func _save(name: String, crop: Rect2i, zoom: int) -> void:
	var img := vp.get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		img = img.get_region(crop)
	img.resize(img.get_width() * zoom, img.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	img.save_png("user://%s.png" % name)
	print("saved ", ProjectSettings.globalize_path("user://%s.png" % name))


# two people (a long-haired one, a bald one), the eight styles in a row: how each style sits on the face
func _styles() -> void:
	var look := root.get_node("Look")
	combos = [{"look": COMBOS[0].look, "acc": {}}, {"look": COMBOS[1].look, "acc": {}}]
	poses = []
	acc_cols = []
	for g in look.ACC_STYLES.glasses:
		poses.append(["idle", 0])
		acc_cols.append({"glasses": g})
	for b in look.ACC_STYLES.beard:
		poses.append(["idle", 0])
		acc_cols.append({"beard": b})


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		_build("right", false)
	elif frame == 10:
		_save("acc_strip_right", Rect2i(), 2)
	elif frame == 11:
		_build("left", false)
	elif frame == 20:
		_save("acc_strip_left", Rect2i(), 2)
		_build("right", true)
	elif frame == 30:
		_save("acc_head_right", Rect2i(), 3)
		_build("left", true)
	elif frame == 40:
		_save("acc_head_left", Rect2i(), 3)
		_styles()
		_build("right", true)
	elif frame == 50:
		_save("acc_styles_right", Rect2i(), 6)
		_build("left", true)
	elif frame == 60:
		_save("acc_styles_left", Rect2i(), 6)
		print("DONE")
		quit(0)
	return false
