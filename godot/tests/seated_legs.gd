extends SceneTree
# Seated legs: the knee bends. Every seated frame (sitdown's last frame, sit, type, sitsip, sitcall and the eight R26 gestures) has the
# thigh running forward from the hips and the shin dropping straight down, so a shoe sole stands on the floor row (79) in front of the
# pelvis. tools/poses.lua `seat()` (lift / shin / floor / legDy / lNx / lFx / keepN / keepF / leanAdd / armLen) and tools/anim.lua build
# it. The whole body above the legs is raised 6 px relative to the feet (the hips sit at about row 72 instead of 77), the shin is 4
# rows longer, so the head top of the intern's sit / type frames is row 26 (it was 32).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/seated_legs.gd

const FW := 64
const FH := 80
const FLOOR := 79
const CHARS := [
	"office_intern", "office_maya", "office_morgan", "office_dan", "office_christy", "office_adult", "office_john", "casual_garrison",
	"custom_intern_bob", "client_brandt", "expo_priya"
]
# sheet cells of every seated pose: sitdown's seated frame, sit 37-38, type 39-41, sitsip, sitcall, and the gestures 85-122
const SEATED := [36, 37, 38, 39, 40, 41, 66, 67, 68, 71, 72]
# first opaque row of the intern's seated frames: 6 px higher than the old floor-sitting build (row 32)
const TOP37 := 26

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _raw(res_path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _initialize() -> void:
	var frames: Array = SEATED.duplicate()
	for i in range(85, 123):
		frames.append(i)
	var worst_low := 0
	var worst_row79 := 99
	var worst_shin := 999
	var bad_low := []
	for c in CHARS:
		for facing in ["right", "left"]:
			var sheet := _raw("res://assets/characters/%s_%s.png" % [c, facing])
			if sheet.get_width() != FW * 135:
				_check(false, "%s %s sheet has 135 frames" % [c, facing])
				continue
			for f in frames:
				var low := -1
				var on79 := 0
				var shin := 0
				for y in range(FH):
					for x in range(FW):
						if sheet.get_pixel(f * FW + x, y).a > 0.0:
							low = y
							if y == FLOOR:
								on79 += 1
							# the shin and shoe: rows 73-79 in front of the pelvis block (x >= 41 facing right, x <= 22 facing left)
							if y >= 73 and ((facing == "right" and x >= 41) or (facing == "left" and x <= 22)):
								shin += 1
				if low != FLOOR:
					bad_low.append("%s_%s %d" % [c, facing, f])
				worst_low = maxi(worst_low, low)
				worst_row79 = mini(worst_row79, on79)
				worst_shin = mini(worst_shin, shin)
	var what := "the lowest pixel of every seated frame (%d people x 2 facings x %d frames) is the floor row %d %s"
	_check(bad_low.is_empty(), what % [CHARS.size(), frames.size(), FLOOR, str(bad_low.slice(0, 5))])
	_check(worst_low == FLOOR, "no seated frame goes below the floor row")
	_check(worst_row79 >= 6, "a shoe sole of at least 6 px is on the floor row in every seated frame (fewest: %d)" % worst_row79)
	_check(worst_shin >= 30, "there is shin and shoe in front of the pelvis below the thigh band in every seated frame (fewest pixels: %d)" % worst_shin)
	# the body is raised: the first opaque row of the intern's sit and type frames
	var intern := _raw("res://assets/characters/office_intern_right.png")
	for f in [37, 39]:
		var top := -1
		for y in range(FH):
			for x in range(FW):
				if top < 0 and intern.get_pixel(f * FW + x, y).a > 0.0:
					top = y
		_check(top == TOP37, "intern frame %d: the head top row is %d (got %d)" % [f, TOP37, top])
	print("seated_legs: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
