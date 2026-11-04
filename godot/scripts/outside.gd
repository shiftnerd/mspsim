extends Node2D
# gdlint:disable=max-line-length,class-definitions-order
# The outside of the warehouse, seen through the dock doorway (R21c). Two nodes of the warehouse scene use this script:
#   Backdrop (mode "sky")  sits BEHIND the Background. The baked wall art has a transparent hole where the doorway is, so this
#                          node's sky gradient, clouds, sun and the static parking lot picture show through it. It is not tinted
#                          by the room's lights (the outside is daylight), and it only draws while the door is not fully closed.
#   Daylight (mode "spill") sits above the floor and the people: a warm, additive light rect in front of the door that grows with
#                          the door and follows the clock phase. It ignores World.lights (switch the room off, the daylight stays).
# Both read the door (fx.gd kind roll_door, group "roll_door"): `open` 0..1. The sky follows World.clock through `phase()`.
# The walkable parking lot (scene warehouse_lot) uses the same script: Backdrop (mode "lot", view_w x view_h, always drawn: the sky,
# sun and clouds behind the transparent sky of the set art) and Lamp (mode "lamp": a warm additive glow round a street light and on
# the asphalt under it, strength from `lamp()`, only at dusk and at night).
# Art-local coordinates: (0, 0) is the top-left of the doorway opening, W x H pixels. Redraws in 12 fps steps.

const W := 120
const H := 76
const STEP := 1.0 / 12.0
const LOT := "res://assets/props/warehouse_lot.png"
# clock, sky top, sky bottom (at the horizon), cloud, tint of the lot picture, spill colour (alpha = how strong)
const KEYS := [
	[8.5, Color("8fb8e0"), Color("f4d9b0"), Color("fff1e0"), Color(1.0, 0.97, 0.92), Color(1.0, 0.82, 0.5, 0.14)],
	[10.0, Color("79b2e8"), Color("cde6f4"), Color("ffffff"), Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.65, 0.2)],
	[12.5, Color("4f94e0"), Color("bfe0f6"), Color("ffffff"), Color(1.0, 1.0, 1.0), Color(1.0, 0.95, 0.75, 0.24)],
	[15.5, Color("6a9ad8"), Color("f2d8a0"), Color("fff0d0"), Color(1.0, 0.95, 0.85), Color(1.0, 0.85, 0.55, 0.24)],
	[17.0, Color("4a5c9a"), Color("f28c5a"), Color("f2a87a"), Color(0.93, 0.8, 0.74), Color(1.0, 0.6, 0.3, 0.2)],
	[18.2, Color("141c3a"), Color("3a3f6a"), Color("2a2f55"), Color(0.4, 0.42, 0.65), Color(0.5, 0.6, 1.0, 0.08)],
]
# the SPILL bands on the floor in front of the door: y (art, from the door top), height, strength
const BANDS := [[81, 8, 1.0], [89, 10, 0.75], [99, 11, 0.5], [110, 10, 0.3], [120, 9, 0.14]]
# x, y, width, speed (px a second) of the clouds
const CLOUDS := [[8.0, 5.0, 26.0, 1.4], [54.0, 12.0, 34.0, 0.9], [96.0, 3.0, 20.0, 1.9], [30.0, 17.0, 18.0, 1.1], [76.0, 20.0, 22.0, 1.6]]

@export var mode := "sky"
@export var view_w := 120  # the size of the picture: the doorway, or the whole sky of the lot
@export var view_h := 76

var open := 0.0  # how far the door is open, copied from the door every frame
var _door: Node = null
var _lot: Texture2D = null
var _t := 0.0
var _acc := 0.0
var _night := -1.0


# the sky at a clock time (hours, 9.0 = opening): the colours and the strength of the light. Tests call it.
static func phase(clock: float) -> Dictionary:
	var last := KEYS.size() - 1
	var i := 0
	while i < last - 1 and clock > float(KEYS[i + 1][0]):
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var f := clampf((clock - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	return {
		"top": (a[1] as Color).lerp(b[1], f),
		"bottom": (a[2] as Color).lerp(b[2], f),
		"cloud": (a[3] as Color).lerp(b[3], f),
		"tint": (a[4] as Color).lerp(b[4], f),
		"spill": (a[5] as Color).lerp(b[5], f)
	}


# how much the street lights glow at a clock time (0 by day, 1 at night)
static func lamp(clock: float) -> float:
	return clampf((clock - 16.6) / 1.5, 0.0, 1.0)


func _ready() -> void:
	if mode == "sky":
		_lot = load(LOT)
	if mode == "spill" or mode == "lamp":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	_t = 100.0 + float(randi() % 50)  # the clouds start somewhere


func _process(delta: float) -> void:
	_t += delta
	if _door == null or not is_instance_valid(_door):
		_door = get_tree().get_first_node_in_group("roll_door")
	var now: float = 0.0 if _door == null else float(_door.open)
	var changed := not is_equal_approx(now, open)
	open = now
	visible = open > 0.001
	if mode == "lot" or mode == "lamp":
		visible = true
		changed = false
		if mode == "lamp":
			var n := floorf(lamp(World.clock) * 24.0) / 24.0
			changed = not is_equal_approx(n, _night)
			_night = n
	_acc += delta
	if _acc >= STEP or changed:
		_acc = 0.0
		if visible:
			queue_redraw()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	var x0 := clampf(x, 0.0, float(view_w))
	var x1 := clampf(x + w, 0.0, float(view_w))
	if x1 > x0:
		draw_rect(Rect2(x0, y, x1 - x0, h), c)


func _draw() -> void:
	var ph := phase(World.clock)
	if mode == "spill":
		_draw_spill(ph)
		return
	if mode == "lamp":
		_draw_lamp()
		return
	# the sky: 2 px bands, top colour to the horizon colour
	for y in range(0, view_h, 2):
		var f := float(y) / float(view_h - 12)
		_px(0, y, view_w, 2, (ph.top as Color).lerp(ph.bottom, clampf(f * f, 0.0, 1.0)))
	_draw_sun()
	for c in CLOUDS:
		_draw_cloud(c, ph.cloud)
	if mode == "lot":
		for k in range(CLOUDS.size()):  # the lot is wide: a second set of clouds further along
			var c: Array = CLOUDS[k].duplicate()
			c[0] = float(c[0]) + 190.0 + float(k) * 70.0
			c[1] = float(c[1]) + 100.0 - float(k) * 6.0
			_draw_cloud(c, ph.cloud)
			c = CLOUDS[k].duplicate()
			c[0] = float(c[0]) + 420.0 + float(k) * 40.0
			_draw_cloud(c, ph.cloud)
	if _lot != null:
		draw_texture(_lot, Vector2.ZERO, ph.tint)


# a sun that climbs from the left to the top and sets behind the tree line at closing time
func _draw_sun() -> void:
	var u := (World.clock - 8.5) / 9.5
	if u <= 0.0 or u >= 1.0:
		return
	var sx := 10.0 + u * 100.0
	var sy := 36.0 - sin(u * PI) * 32.0
	if mode == "lot":  # the whole sky of the lot: the sun crosses all of it, the horizon is at y 142
		sx = 30.0 + u * float(view_w - 60)
		sy = 142.0 - sin(u * PI) * 124.0
	var low := absf(u - 0.5) * 2.0
	var col := Color("fff6d0").lerp(Color("ff9a4a"), clampf(low * 1.2, 0.0, 1.0))
	for dy in range(-4, 5):
		var half := int(round(sqrt(maxf(0.0, 20.0 - float(dy * dy)))))
		_px(sx - half, sy + dy, half * 2 + 1, 1, col)


func _draw_cloud(c: Array, col: Color) -> void:
	var w: float = c[2]
	var x := floorf(fposmod(float(c[0]) + _t * float(c[3]), float(view_w) + w * 2.0)) - w
	var y: float = c[1]
	_px(x + w * 0.2, y, w * 0.45, 2, col)
	_px(x + w * 0.1, y + 2, w * 0.8, 2, col)
	_px(x, y + 4, w, 2, col.darkened(0.1))
	_px(x + w * 0.05, y + 6, w * 0.9, 1, col.darkened(0.2))


# a street light: rings of warm light round the lamp head (0, 0 of this node) and a pool on the asphalt under it
func _draw_lamp() -> void:
	var n := lamp(World.clock)
	if n <= 0.01:
		return
	var col := Color(1.0, 0.86, 0.5)
	for ring in [[34, 0.05], [26, 0.06], [18, 0.07], [10, 0.1], [5, 0.16]]:
		var r: int = ring[0]
		for dy in range(-r, r + 1):
			var half := int(sqrt(float(r * r - dy * dy)))
			draw_rect(Rect2(-half, dy, half * 2 + 1, 1), Color(col.r, col.g, col.b, float(ring[1]) * n))
	for pool in [[44, 8, 0.05], [32, 6, 0.06], [20, 4, 0.07]]:
		var rx: int = pool[0]
		var ry: int = pool[1]
		for dy in range(-ry, ry + 1):
			var half := int(float(rx) * sqrt(1.0 - float(dy * dy) / float(ry * ry + 1)))
			draw_rect(Rect2(-half, 88 + dy, half * 2 + 1, 1), Color(col.r, col.g, col.b, float(pool[2]) * n))


# warm daylight on the floor in front of the open door, in bands that fade out with distance and with the door
func _draw_spill(ph: Dictionary) -> void:
	var c: Color = ph.spill
	var o := floorf(open * 6.0) / 6.0
	for b in BANDS:
		var a: float = c.a * o * float(b[2])
		var col := Color(c.r, c.g, c.b, a)
		var y := float(b[0])
		var h := float(b[1])
		draw_rect(Rect2(0, y, W, h), col)
		draw_rect(Rect2(-5, y, 5, h), Color(c.r, c.g, c.b, a * 0.45))
		draw_rect(Rect2(W, y, 5, h), Color(c.r, c.g, c.b, a * 0.45))
		draw_rect(Rect2(-9, y + 1, 4, h - 2), Color(c.r, c.g, c.b, a * 0.2))
		draw_rect(Rect2(W + 5, y + 1, 4, h - 2), Color(c.r, c.g, c.b, a * 0.2))
