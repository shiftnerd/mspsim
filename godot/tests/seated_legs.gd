extends SceneTree
# Seated legs: the knee bends. Every seated frame (sitdown's last frame, sit, type, sitsip, sitcall and the eight R26 gestures) has the
# thigh running forward from the hips and the shin dropping straight down, so a shoe sole stands on the floor row (79) in front of the
# pelvis. tools/poses.lua `seat()` (legRef / floor / legDy / lNx / lFx) and tools/anim.lua build it; the body does not move: the head's
# top row of the old straight-shin sit stays.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/seated_legs.gd

const FW := 64
const FH := 80
const FLOOR := 79
const CHARS := [
	"office_intern", "office_maya", "office_morgan", "office_dan", "office_marge", "office_adult", "sales_vic", "casual_garrison",
	"custom_intern_bob", "client_brandt", "expo_priya"
]
# sheet cells of every seated pose: sitdown's seated frame, sit 37-38, type 39-41, sitsip, sitcall, and the gestures 85-122
const SEATED := [36, 37, 38, 39, 40, 41, 66, 67, 68, 71, 72]
# first opaque row of the intern's seated frames in the old straight-shin build (the head and torso must not move)
const TOP37 := 32

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
			if sheet.get_width() != FW * 129:
				_check(false, "%s %s sheet has 129 frames" % [c, facing])
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
							# the shin and shoe: rows 74-79 in front of the pelvis block (x >= 41 facing right, x <= 22 facing left)
							if y >= 74 and ((facing == "right" and x >= 41) or (facing == "left" and x <= 22)):
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
	# the body did not move: the first opaque row of the intern's sit and type frames is the old one
	var intern := _raw("res://assets/characters/office_intern_right.png")
	for f in [37, 39]:
		var top := -1
		for y in range(FH):
			for x in range(FW):
				if top < 0 and intern.get_pixel(f * FW + x, y).a > 0.0:
					top = y
		_check(top == TOP37, "intern frame %d: the head top row is still %d (got %d)" % [f, TOP37, top])
	print("seated_legs: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
