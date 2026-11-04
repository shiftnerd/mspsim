extends SceneTree
# Contact strips of the creator's shirt patterns and shorts on every kind of pose (needs a renderer, saves PNGs):
# user://poses_<combo>_<facing>.png, 8 x 3 frames at 1x (scale them up to read them).
#   Godot --path godot --fixed-fps 60 -s res://tests/creator_poses_shots.gd

const FRAMES := [0, 6, 14, 18, 20, 23, 25, 26, 28, 31, 33, 35, 37, 40, 46, 78, 87, 92, 98, 103, 108, 112, 116, 120]
const COMBOS := {
	"plaid_shorts": ["plaid", "shorts", "e0a030"],
	"stripes_light": ["stripes", "none", "f4f2ea"],
	"checks_shorts": ["checks", "shorts", "2a2f3a"],
	"plain": ["none", "none", "4f7fd0"],
}

var frame := 0
var jobs: Array = []


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


# the (animation, index) that shows sheet frame f
func _find(frames: SpriteFrames, facing: String, f: int) -> Array:
	for anim in frames.get_animation_names():
		if not str(anim).ends_with("_" + facing):
			continue
		for i in frames.get_frame_count(anim):
			var tex := frames.get_frame_texture(anim, i) as AtlasTexture
			if tex != null and int(tex.region.position.x) == f * 64:
				return [anim, i]
	return []


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 20:
		return false
	var look := root.get_node("Look")
	if jobs.is_empty() and frame == 20:
		for facing in ["right", "left"]:
			for key in COMBOS:
				jobs.append([key, facing])
	if frame >= 20 and (frame - 20) % 4 == 0:
		var n := floori(float(frame - 20) / 4.0)
		if n > 0 and n <= jobs.size():  # the previous job has rendered: save it
			var prev: Array = jobs[n - 1]
			var vp: SubViewport = root.get_node("strip")
			vp.get_texture().get_image().save_png("user://poses_%s_%s.png" % [prev[0], prev[1]])
			root.remove_child(vp)
			vp.free()
		if n >= jobs.size():
			print("DONE")
			quit(0)
			return false
		var combo: Array = COMBOS[jobs[n][0]]
		var lk: Dictionary = look.sanitize({"shirt": combo[2], "pants": "3a3f66", "pattern": combo[0], "shorts": combo[1]})
		var vp2 := SubViewport.new()
		vp2.name = "strip"
		vp2.size = Vector2i(8 * 64, 3 * 80)
		vp2.transparent_bg = false
		vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp2)
		var bg := ColorRect.new()
		bg.color = Color(0.25, 0.27, 0.3)
		bg.size = Vector2(8 * 64, 3 * 80)
		vp2.add_child(bg)
		var fr: SpriteFrames = look.frames_for("office_intern", true, lk)
		for i in FRAMES.size():
			var hit := _find(fr, str(jobs[n][1]), int(FRAMES[i]))
			if hit.is_empty():
				continue
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = fr
			spr.animation = hit[0]
			spr.frame = hit[1]
			spr.position = Vector2(float(i % 8) * 64.0 + 32.0, float(floori(float(i) / 8.0)) * 80.0 + 40.0)
			spr.material = look.make_material(lk)
			vp2.add_child(spr)
	return false
