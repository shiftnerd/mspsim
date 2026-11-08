extends Node2D
# An item (coffee / water cup) glued to its owner's near hand. The hand position of every
# sheet frame comes from assets/characters/<name>_<facing>_hands.json (tools/build_anims.lua).

const START := {
	"idle": 0,
	"walk": 4,
	"run": 12,
	"crouch": 18,
	"jump": 19,
	"land": 22,
	"hurt": 25,
	"death": 28,
	"reach": 42,
	"wave": 45,
	"talk": 49,
	"hold": 53,
	"walkhold": 55,
	"sip": 63,
	"sitsip": 66,
	"call": 69,
	"sitcall": 71,
	"dance": 73,
	"sitstretch": 85,
	"sitscratch": 90,
	"sitlook": 96,
	"sityawn": 101,
	"sitslump": 106,
	"sitmouse": 110,
	"sitphone": 114,
	"sitnod": 119,
	"toss": 123,
	"sitcouch": 129,
	"sitdown": 35,
	"sit": 37,
	"type": 39
}
const INK := Color("17121f")

var item := ""
var mode := "hand"  # "hand" follows the near hand, "ear" follows the ear (headset)

var _hands := {}
var _side := 1.0
var _tilt := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	visible = item != ""
	if not visible:
		return
	var owner_node := get_parent()
	var sprite: AnimatedSprite2D = owner_node.get_node("Sprite")
	var parts := String(sprite.animation).rsplit("_", true, 1)
	if parts.size() < 2 or not START.has(parts[0]):
		visible = false
		return
	_side = 1.0 if parts[1] == "right" else -1.0
	var key := "%s_%s" % [owner_node.character_id(), parts[1]]
	if not _hands.has(key):
		var path := "res://assets/characters/%s_hands.json" % key
		_hands[key] = JSON.parse_string(FileAccess.get_file_as_string(path))
	var table: Array = _hands[key]
	var idx: int = START[parts[0]] + sprite.frame
	if idx >= table.size():
		visible = false
		return
	var k := 2 if mode == "ear" else 0
	position = Vector2(float(table[idx][k]) - 32.0, float(table[idx][k + 1]) - 80.0)
	_tilt = 0.0
	if mode == "hand" and parts[0] in ["sip", "sitsip"]:
		var f := mini(sprite.frame, 2)
		_tilt = [30.0, 112.0, 45.0][f]
	queue_redraw()


# wireless earpiece with a short mic boom (origin = the ear)
func _draw_headset() -> void:
	var s := _side
	var body := Color("2a2a33")
	draw_rect(Rect2(-2, -3, 4, 6), INK)
	draw_rect(Rect2(-1, -2, 2, 4), body)
	var led := Color("4f7fd0") if int(_t * 2.0) % 2 == 0 else Color("1c2a4a")
	draw_rect(Rect2(-0.5 - 0.5 * s, -2, 1, 1), led)
	draw_rect(Rect2(s * 1.0 - 0.5, 2, 1, 2), INK)  # the boom curves down and forward to the mouth
	draw_rect(Rect2(s * 2.0 - 0.5, 4, 1, 2), INK)
	draw_rect(Rect2(s * 3.0 - 0.5, 6, 1, 2), INK)
	draw_rect(Rect2(s * 4.0 - 1.0, 7, 3, 2), INK)
	draw_rect(Rect2(s * 4.0 - 0.5, 7.5, 2, 1), body)


func _draw() -> void:
	if mode == "ear":
		_draw_headset()
		return
	var lift := clampf(_tilt / 112.0, 0.0, 1.0)  # the cup also moves forward / up to the lips
	var shift := Vector2(5.0 * lift * _side, -1.0 * lift)
	draw_set_transform(shift, deg_to_rad(_tilt) * _side, Vector2.ONE)
	if item == "coffee":
		draw_rect(Rect2(-3, -4, 6, 9), INK)
		draw_rect(Rect2(-2, -3, 4, 7), Color("f4f2ea"))
		draw_rect(Rect2(-2, -3, 4, 2), Color("5a3620"))
		var hx := 3.0 if _side > 0.0 else -4.0
		draw_rect(Rect2(hx, -2, 1, 4), INK)
	elif item == "nerf":
		var d := _side
		draw_rect(Rect2(-5.0 if d > 0.0 else -4.0, -3, 9, 5), INK)
		draw_rect(Rect2(-4.0 if d > 0.0 else -3.0, -2, 7, 3), Color("ff8a1f"))
		draw_rect(Rect2(2.0 if d > 0.0 else -4.0, -2, 2, 3), Color("2b79f0"))
		draw_rect(Rect2(-1, 2, 2, 3), INK)
	elif item == "plug_net":
		draw_rect(Rect2(-2, -4, 5, 7), INK)
		draw_rect(Rect2(-1, -3, 3, 4), Color("4f7fd0"))
		draw_rect(Rect2(-1, 1, 3, 2), Color("c8ccd8"))
	elif item == "toner":  # tone generator with a probe wand (R37); the LED blinks while a tone is clipped on a desk
		draw_rect(Rect2(-3, -3, 7, 8), INK)
		draw_rect(Rect2(-2, -2, 5, 6), Color("e8a030"))
		draw_rect(Rect2(-1, -1, 3, 2), Color("3c414d"))
		var on: bool = Net.tone_desk > 0 and int(_t * 4.0) % 2 == 0
		draw_rect(Rect2(0, 2, 1, 1), Color("9fe870") if on else Color("5a3a18"))
		draw_rect(Rect2(_side * 3.0 - 0.5, -8, 1, 6), INK)  # the probe wand
		draw_rect(Rect2(_side * 3.0 - 0.5, -9, 1, 1), Color("e04646"))
	elif item == "plug_pwr":
		draw_rect(Rect2(-2, -4, 5, 7), INK)
		draw_rect(Rect2(-1, -3, 3, 4), Color("3c414d"))
		draw_rect(Rect2(-1, 1, 1, 3), Color("c8ccd8"))
		draw_rect(Rect2(1, 1, 1, 3), Color("c8ccd8"))
	elif item == "soda":
		draw_rect(Rect2(-3, -5, 6, 10), INK)
		draw_rect(Rect2(-2, -4, 4, 8), Color("d23c3c"))
		draw_rect(Rect2(-2, -4, 4, 1), Color("b8bcc4"))
		draw_rect(Rect2(-2, -1, 4, 2), Color("f4f2ea"))
	elif item == "bottle":
		draw_rect(Rect2(-1, -7, 2, 2), INK)
		draw_rect(Rect2(-3, -5, 6, 11), INK)
		draw_rect(Rect2(-2, -4, 4, 9), Color("cfe6f6"))
		draw_rect(Rect2(-2, -1, 4, 6), Color("8cc0e8"))
		draw_rect(Rect2(-1, -7, 2, 1), Color("f4f2ea"))
	elif item == "phone":
		draw_rect(Rect2(-2, -4, 5, 8), INK)
		draw_rect(Rect2(-1, -3, 3, 6), Color("5a6a85") if int(_t * 2.0) % 2 == 0 else Color("8cc0e8"))
	elif item == "water":
		draw_rect(Rect2(-3, -4, 6, 9), INK)
		draw_rect(Rect2(-2, -3, 4, 7), Color("e4f2fb"))
		draw_rect(Rect2(-2, -1, 4, 5), Color("8cc0e8"))
