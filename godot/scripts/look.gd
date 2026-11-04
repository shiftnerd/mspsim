extends Node
# gdlint:disable=max-line-length
# CHARACTER CREATOR, LEVEL 1: COLOURS ONLY (roadmap R15). The custom person is the INTERN sheet (Look.BASE) drawn through a
# palette-swap shader (canvas_item) that replaces each flat colour of that sheet with the player's choice. There is no new
# art: every animation, seat, hand and ear position keeps working, and anything keyed by character name (Player.CHARACTERS,
# hands json, Social, Lync, Talk) sees plain "office_intern".
#
#   look        {name, skin, hair, shirt, pants, shoes}: five colours as 6 digit hex text, plus a name (up to 10 characters)
#   SOURCES     the flat colours of office_intern_right / _left.png that are recoloured: [hex, role, level]. Level 0 is the
#               base colour of the role, 1 and 2 are the shades (or the highlight) computed from the chosen base, so the
#               figure stays consistent (shade_of). The outline #17121F, the eyes, brows, mouth, belt, buckle and watch are
#               KEEPS: listed so the nearest-colour match never takes them for a neighbouring shade.
#   Hurt flash  frames 25 and 28 of the sheet are every colour mixed 70% to white; the shader and map_color() match those too
#   active      the current person IS the custom one (is_custom(): active and the player's sheet is BASE)
#
# The shader and map_color() are one algorithm (nearest source colour inside a tolerance); tests/creator.gd runs map_color()
# over every colour of both sheets. The last look is kept in user://mspsim_settings.cfg ([look]) as the default for the next
# new run, and the campaign save carries it (campaign/look; an old save has none and loads as before).
#
# LEVEL 3 STEP B, HEAD ACCESSORIES (glasses, facial hair; hats and the rest later): `acc` (ids per slot, see the block marked LEVEL 3
# below) is drawn by scripts/head_gear.gd as overlay sprites on the sheet's head, recoloured by the same shader (frame, beard and
# stubble colours are SOURCES rows; the lens is a KEEP).
# LEVEL 2, HAIRSTYLES: look.hair_style picks one of HAIR_STYLES. Every style is a complete prebaked character (the intern with
# another Hair layer, tools/make_hair.lua, sheets and SpriteFrames like any other character): `side` is the intern's own hair
# (office_intern itself), the others are custom_intern_<style>. sheet_for() maps a look to that character name and every place
# that shows the custom person loads characters/<sheet>.tres. All styles use only the intern's hair colours (9a5124, c47a38,
# the outline), so the palette shader above works on every sheet unchanged. A new style is data only: build its stills and
# sheets, add custom_intern_<style> to EXTRA_CHARACTERS in make_godot.py and the id to HAIR_STYLES (and out of HAIR_PLANNED).

# LEVEL 3 STEP (a) adds `pattern` and `shorts` to the look (shader only, see the block below), three preset slots (presets,
# settings section [looks]) and the list-row helpers (CHOICES, choice_index, cycle_choice) the create step's rows read.

const PLAYER := preload("res://scripts/player.gd")
const BASE := "office_intern"
const ROLES := ["skin", "hair", "shirt", "pants", "shoes"]
const MAX_NAME := 10
const PRESET_SLOTS := 3
const HAIR_STYLES := ["side", "short", "receding", "curly", "long", "bob", "ponytail", "bun", "bald", "spiky"]  # the shipped styles, in the order of the STYLE row
const HAIR_PLANNED: Array = []  # styles not drawn yet; tests and the UI skip them (all ten are shipped)
const FLASH := 0.7  # the hurt frames mix every colour this far to white
const TOL := 0.03  # nearest-colour tolerance (RGB distance, 0..1)
const FLASH_TOL := 0.01
const MIN_STEP := 0.045  # the least a shade differs from its base in value
# ---- LEVEL 3 STEP (a): shader patterns and shorts (no art) ----
# pattern: none / stripes / plaid / checks. A second tone of the shirt colour (darker for a light shirt, lighter otherwise) is
#   drawn by the shader from the pixel position inside the 64x80 frame cell, on the shirt's base and shade pixels only (never
#   the button tint of the collar / placket, never the hurt flash frames) and not on a sleeve (a shirt pixel with skin within
#   3 pixels straight below it is a sleeve over a forearm). The shader only matches colours, so skin, outline, face, belt,
#   buckle and shoes are untouched by construction.
# shorts: pants pixels (all three tones) at or below the hem row of the frame (HEMS, the first pants row plus 9, baked per
#   frame from the sheet; 255 = none: the lying death frames 29 to 34) become the skin tone of the same level. Seated, only
#   the thighs show, so the trousers stay; crouch, run, jump and the hurt frames hem right because the row follows the pelvis.
const PATTERNS := ["none", "stripes", "plaid", "checks"]
const SHORTS := ["none", "shorts"]
const CHOICES := {"hair_style": HAIR_STYLES, "pattern": PATTERNS, "shorts": SHORTS}  # the list rows of the create step
const CELL := 64  # the frame cell of the sheets: 64 wide, 80 tall, 129 frames
const FRAMES := 129
const SLEEVE_REACH := 3  # a shirt pixel with skin this close below it (same column) is a sleeve: no pattern
const PATTERN_LIGHT := 0.6  # a shirt with value above this gets a darker second tone, otherwise a lighter one
# per frame of the sheet: the first pants row plus 9 (the hem of the shorts); 255 = no shorts in that frame
const HEMS := [
	67, 68, 68, 68, 68, 68, 67, 67, 68, 68, 67, 67, 69, 68, 64, 69, 68, 64, 70, 63, 55, 61, 71, 69, 67, 67, 67, 67, 67,
	255, 255, 255, 255, 255, 255, 70, 80, 80, 81, 80, 80, 80, 67, 67, 67, 67, 67, 67, 67, 67, 68, 67, 68, 67, 68, 68, 68,
	67, 67, 68, 68, 67, 67, 67, 67, 67, 80, 80, 80, 67, 67, 80, 80, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 80, 80,
	80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 81, 81, 80, 80, 80, 80, 80, 80, 80, 80,
	80, 80, 80, 80, 80, 80,
	68, 69, 68, 67, 67, 67
]
const SOURCES := [
	["f3b488", "skin", 0],
	["d88a62", "skin", 1],
	["b8663f", "skin", 2],
	["9a5124", "hair", 0],
	["c47a38", "hair", 1],
	["4f7fd0", "shirt", 0],
	["3a62a8", "shirt", 1],
	["bbd0f5", "shirt", 2],
	["3a3f66", "pants", 0],
	["2f3354", "pants", 1],
	["272b48", "pants", 2],
	["5a3522", "shoes", 0],
	["4a2c1c", "shoes", 1],
	# level 3 step b (the head overlay sheets only, see tools/make_accessories.lua): glasses frame, beard base and shade, stubble
	["1e1e26", "frame", 0],
	["7d5a3a", "beard", 0],
	["55402c", "beard", 1],
	["e0a07a", "stubble", 0],
]
# never recoloured: outline and belt, eye white, pupil, brows, mouth, buckle, watch
const KEEPS := [
	"17121f",
	"ffffff",
	"3a2418",
	"6b3416",
	"8a4a2e",
	"c8ccd8",
	"2a2a33",
	"2f3d44",  # sunglasses lens
	# level 3 steps c and d: the colours of the hats, lanyard, name sticker and watches (drawn by tools/make_accessories.lua), never recoloured
	"e8b820",  # hard hat, gold watch, party hat pom: yellow, shade, highlight
	"b88a14",
	"f6d860",
	"c8283a",  # santa hat, sport watch, name sticker: red and shade
	"9a1c2c",
	"2f6b3a",  # beanie: green, dark, light
	"1f4d28",
	"4a8a54",
	"2c4a7a",  # ball cap: navy and dark
	"1f3556",
	"b9a574",  # bucket hat: khaki and dark
	"8c7a52",
	"d0409a",  # party hat: pink and cyan
	"40b8d0",
	"1f9a96",  # the conference lanyard: teal and dark
	"16706f",
	"c8c0b0",  # santa fur shade
]
const SWATCHES := {
	"skin": ["fbd7bc", "f3b488", "e3a272", "c68642", "a8683a", "8d5524", "6b3e22", "4a2a18"],
	"hair":
	[
		"9a5124",
		"2a1c14",
		"4a3222",
		"74492a",
		"c9a25b",
		"e8d090",
		"b8421f",
		"8a8f9a",
		"e8e8ec",
		"3a5fb0",
		"8e3fa8",
		"e05a9a"
	],
	"shirt":
	[
		"4f7fd0",
		"8c2b40",
		"b8292f",
		"4f9c8e",
		"3c55c0",
		"2f6b3a",
		"e0a030",
		"f4f2ea",
		"2a2f3a",
		"7a4fb0",
		"d0602a",
		"e08aa8"
	],
	"pants": ["3a3f66", "2b3550", "3f5e8e", "8a6a42", "2a2a33", "6a6f7a", "5a4a3a", "7a3030"],
	"shoes": ["5a3522", "2a2a33", "8a8f9a", "cfc8b5", "3a3a44", "7a2020", "2f4a73", "6e7a68"],
}
# 2013-14 first names, none of them the cast (Alan, Garrison, Dan, Vic, Maya, Morgan) or the crew (Sam, Terry)
const NAMES := [
	"JAMIE",
	"CASEY",
	"RILEY",
	"TAYLOR",
	"JORDAN",
	"QUINN",
	"AVERY",
	"DREW",
	"KELLY",
	"CHRIS",
	"PAT",
	"LEE"
]

# ---- LEVEL 3 STEP B: head accessories (the block is separate on purpose: the create-step UI rows come later) --------------
const HEAD_GEAR := preload("res://scripts/head_gear.gd")
# every slot of `acc` and its styles (ids of the sheets assets/accessories/<slot>_<id>_<facing>.png). The slots glasses, beard and hat
# can be LOCKED (Career.UNLOCKS entries of that kind, value = the id; an id with no entry is free); badge (the HELLO name sticker),
# lanyard (the conference lanyard with its pass) and watch (it replaces the intern's own black watch) are always free.
const ACC_SLOTS := ["glasses", "beard", "hat", "badge", "lanyard", "watch"]
const ACC_STYLES := {
	"glasses": ["thin", "thick", "round", "aviator"],
	"beard": ["stubble", "goatee", "full", "moustache"],
	"hat": ["beanie", "cap", "hardhat", "santa", "bucket", "party"],
	"badge": ["name"],
	"lanyard": ["conference"],
	"watch": ["silver", "gold", "sport"],
}
# the names the create rows show for the slots that have no Career.UNLOCKS entry (the others use the entry's patchable title)
const ACC_TITLES := {
	"badge": {"name": "HELLO TAG"},
	"lanyard": {"conference": "CONFERENCE"},
	"watch": {"silver": "SILVER", "gold": "GOLD", "sport": "SPORT"},
}
# while a hat is worn a tall hairstyle shows as another one (the hat covers the crown): the sheet is the substitute's, the look keeps
# the chosen style. long, bob and ponytail hang below the brim and stay.
const HAT_HAIR := {"spiky": "short", "curly": "short", "bun": "ponytail"}
const RANDOM_SHARE := {"glasses": 0.35, "beard": 0.3, "hat": 0.3, "badge": 0.2, "lanyard": 0.15, "watch": 0.25}  # RANDOM's chance per slot
const FRAME_DEFAULT := "1e1e26"  # glasses frame colour when acc.frame_color is empty (the art colour)
const FRAME_STYLE := {"round": "8c6a1e", "aviator": "b8bcc4"}  # wire frames default to metal
const STUBBLE_MIX := 0.4  # stubble = the skin colour mixed this far to the beard colour

var active := false
var look: Dictionary = default_look()
var presets: Array = [{}, {}, {}]  # PRESET_SLOTS look dicts, {} = empty (level 3 step a)
# the accessories of the player's look: {glasses, beard, hat, badge, lanyard, watch} = style ids ("" = none), plus the optional
# beard_color (empty = the hair colour) and frame_color (empty = the style's default), both 6 digit hex
var acc: Dictionary = default_acc()
var _shader: Shader = null
var _src_cache := PackedColorArray()
var _flash_cache := PackedColorArray()


func default_look() -> Dictionary:
	return {
		"name": NAMES[0],
		"hair_style": HAIR_STYLES[0],
		"skin": "f3b488",
		"hair": "9a5124",
		"shirt": "4f7fd0",
		"pants": "3a3f66",
		"shoes": "5a3522",
		# level 3 step (a)
		"pattern": "none",
		"shorts": "none"
	}


# ---- the colour maths ------------------------------------------------------------------
# the shade (level 1), deeper shade or highlight (level 2) of a base colour for a role: the same hue shift and
# saturation / value ratios as the original sheet's base -> shade pair (skin f3b488 -> d88a62 -> b8663f, hair 9a5124 ->
# highlight c47a38, shirt 4f7fd0 -> 3a62a8 and the button tint bbd0f5, pants 3a3f66 -> 2f3354 -> 272b48, shoes 5a3522 ->
# 4a2c1c), so the original base gives back exactly the original shades and every other base keeps the same look.
# Very dark or very light bases still get a step of at least MIN_STEP in value.
func shade_of(base: Color, role: String, level: int) -> Color:
	if level == 0:
		return base
	var from_c := Color.WHITE
	var to_c := Color.WHITE
	for row in SOURCES:
		if row[1] == role and int(row[2]) == 0:
			from_c = Color.html(str(row[0]))
		elif row[1] == role and int(row[2]) == level:
			to_c = Color.html(str(row[0]))
	var hue := fposmod(base.h + (to_c.h - from_c.h), 1.0)
	var sat := clampf(base.s * to_c.s / maxf(from_c.s, 0.01), 0.0, 1.0)
	var val := clampf(base.v * to_c.v / from_c.v, 0.0, 1.0)
	if to_c.v < from_c.v and base.v - val < MIN_STEP:
		val = maxf(base.v - MIN_STEP, 0.0)
	elif to_c.v > from_c.v and val - base.v < MIN_STEP:
		val = minf(base.v + MIN_STEP, 1.0)
	return Color.from_hsv(hue, sat, val)


func _color_of(look_dict: Dictionary, role: String) -> Color:
	return Color.html(str(look_dict.get(role, "ffffff")))


# the recoloured value of every SOURCES row followed by the KEEPS (themselves), for this look
func palette(look_dict: Dictionary, acc_dict: Dictionary = {}) -> PackedColorArray:
	var out := PackedColorArray()
	for row in SOURCES:
		out.append(shade_of(_role_base(look_dict, acc_dict, str(row[1])), str(row[1]), int(row[2])))
	for hex in KEEPS:
		out.append(Color.html(str(hex)))
	return out


func sources() -> PackedColorArray:
	if _src_cache.is_empty():
		for row in SOURCES:
			_src_cache.append(Color.html(str(row[0])))
		for hex in KEEPS:
			_src_cache.append(Color.html(str(hex)))
	return _src_cache


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# the same algorithm as the shader, for tests and any code that needs the answer: the colour a pixel of the INTERN sheet
# turns into for this look (an unknown colour comes back unchanged)
func map_color(c: Color, look_dict: Dictionary, acc_dict: Dictionary = {}) -> Color:
	var m := _match(c)
	if m[0] < 0:
		return c
	var dst := palette(look_dict, acc_dict)
	var out: Color = dst[m[0]].lerp(Color.WHITE, FLASH) if m[1] else dst[m[0]]
	return Color(out.r, out.g, out.b, c.a)


# [index into sources() or -1, is it the hurt flash mix] of a colour: the shader's nearest-colour match
func _match(c: Color) -> Array:
	var src := sources()
	if _flash_cache.is_empty():
		for col in src:
			_flash_cache.append(col.lerp(Color.WHITE, FLASH))
	var best := -1
	var best_d := 1000000.0
	var best_flash := false
	var tol2 := TOL * TOL
	var ftol2 := FLASH_TOL * FLASH_TOL
	for i in src.size():
		var s: Color = src[i]
		var d := (c.r - s.r) * (c.r - s.r) + (c.g - s.g) * (c.g - s.g) + (c.b - s.b) * (c.b - s.b)
		if d < tol2 and d < best_d:
			best = i
			best_d = d
			best_flash = false
		var f: Color = _flash_cache[i]
		var fd := (c.r - f.r) * (c.r - f.r) + (c.g - f.g) * (c.g - f.g) + (c.b - f.b) * (c.b - f.b)
		if fd < ftol2 and fd < best_d:
			best = i
			best_d = fd
			best_flash = true
	return [best, best_flash]


# ---- level 3 step (a): the pattern and shorts, GDScript twin of the shader ------------------------------
func _first(role: String) -> int:
	for i in SOURCES.size():
		if SOURCES[i][1] == role:
			return i
	return -1


# the pattern's tone at a frame-cell pixel: 0 = the shirt colour, 1 or 2 = the second tone (stronger)
func pattern_tone(pattern: String, px: int, py: int) -> int:
	match pattern:
		"stripes":
			return (py >> 1) % 2
		"plaid":
			return (1 if px % 6 < 2 else 0) + (1 if py % 6 < 2 else 0)
		"checks":
			return ((px >> 1) + (py >> 1)) % 2
	return 0


# a shirt colour with the pattern's second tone at strength m (1 or 2)
func tone_of(c: Color, m: int) -> Color:
	if m <= 0:
		return c
	if maxf(c.r, maxf(c.g, c.b)) > PATTERN_LIGHT:
		return Color(c.r * (1.0 - 0.2 * m), c.g * (1.0 - 0.2 * m), c.b * (1.0 - 0.2 * m), c.a)
	return c.lerp(Color.WHITE, 0.25 * m)


# the colour pixel (x, y) of a sheet image (CELL wide frames, 80 tall) turns into for this look: map_color plus the pattern
# and the shorts. This is the shader's algorithm; tests run it over every frame.
# (pal: palette(look_dict) when the caller maps many pixels)
func map_pixel(img: Image, x: int, y: int, look_dict: Dictionary, pal := PackedColorArray()) -> Color:
	var c := img.get_pixel(x, y)
	var m := _match(c) if c.a > 0.0 else [-1, false]
	if m[0] < 0:
		return c
	var dst := pal if not pal.is_empty() else palette(look_dict)
	var out: Color = dst[m[0]].lerp(Color.WHITE, FLASH) if m[1] else dst[m[0]]
	out.a = c.a
	if m[1]:
		return out  # the hurt flash frames take neither
	var best: int = m[0]
	var px := x % CELL
	var py := y
	var p0 := _first("pants")
	if best >= p0 and best < p0 + 3 and str(look_dict.get("shorts", "none")) == "shorts" and py >= HEMS[x >> 6]:
		out = Color(dst[best - p0].r, dst[best - p0].g, dst[best - p0].b, c.a)
	var s0 := _first("shirt")
	var pat := str(look_dict.get("pattern", "none"))
	if pat != "none" and (best == s0 or best == s0 + 1):
		var sleeve := false
		for k in range(1, SLEEVE_REACH + 1):
			if y + k < img.get_height():
				var t := img.get_pixel(x, y + k)
				if t.a > 0.0:
					for i in 3:
						if _dist(t, sources()[i]) < TOL:
							sleeve = true
		if not sleeve:
			out = tone_of(out, pattern_tone(pat, px, py))
	return out


func shader() -> Shader:
	if _shader == null:
		var n := SOURCES.size() + KEEPS.size()
		var s0 := _first("shirt")
		var p0 := _first("pants")
		_shader = Shader.new()
		_shader.code = (
			"""shader_type canvas_item;
uniform vec4 src[%d];
uniform vec4 dst[%d];
uniform int pattern = 0;
uniform float hems[%d];
varying vec4 vcol;
void vertex() {
  vcol = COLOR;
}
void fragment() {
  vec4 c = texture(TEXTURE, UV);
  int best = -1;
  float best_d = 1000.0;
  bool best_flash = false;
  vec3 o = c.rgb;
  if (c.a > 0.0) {
    for (int i = 0; i < %d; i++) {
      float d = distance(c.rgb, src[i].rgb);
      if (d < %f && d < best_d) { best = i; best_d = d; best_flash = false; }
      float f = distance(c.rgb, mix(src[i].rgb, vec3(1.0), %f));
      if (f < %f && f < best_d) { best = i; best_d = f; best_flash = true; }
    }
  }
  if (best >= 0) {
    o = dst[best].rgb;
    if (best_flash) {
      o = mix(o, vec3(1.0), %f);
    } else {
      vec2 pc = floor(UV / TEXTURE_PIXEL_SIZE);
      float fr = floor(pc.x / %f);
      float px = pc.x - fr * %f;
      float py = pc.y;
      if (best >= %d && best < %d && py >= hems[int(fr)]) { o = dst[best - %d].rgb; }
      if (pattern > 0 && (best == %d || best == %d)) {
        bool sleeve = false;
        for (int k = 1; k <= %d; k++) {
          vec4 t = texture(TEXTURE, UV + vec2(0.0, float(k) * TEXTURE_PIXEL_SIZE.y));
          for (int i = 0; i < 3; i++) {
            if (t.a > 0.0 && distance(t.rgb, src[i].rgb) < %f) { sleeve = true; }
          }
        }
        if (!sleeve) {
          float m = 0.0;
          if (pattern == 1) { m = mod(floor(py / 2.0), 2.0); }
          else if (pattern == 2) { m = (mod(px, 6.0) < 2.0 ? 1.0 : 0.0) + (mod(py, 6.0) < 2.0 ? 1.0 : 0.0); }
          else { m = mod(floor(px / 2.0) + floor(py / 2.0), 2.0); }
          if (m > 0.5) {
            float v = max(o.r, max(o.g, o.b));
            o = v > %f ? o * (1.0 - 0.2 * m) : mix(o, vec3(1.0), 0.25 * m);
          }
        }
      }
    }
  }
  COLOR = vec4(o, c.a) * vcol;
}
"""
			% [n, n, FRAMES, n, TOL, FLASH, FLASH_TOL, FLASH, float(CELL), float(CELL), p0, p0 + 3, p0, s0, s0 + 1, SLEEVE_REACH, TOL, PATTERN_LIGHT]
		)
	return _shader


func make_material(look_dict: Dictionary, acc_dict: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("src", sources())
	m.set_shader_parameter("dst", palette(look_dict, acc_dict))
	m.set_shader_parameter("pattern", maxi(0, PATTERNS.find(str(look_dict.get("pattern", "none")))))
	var hems := PackedFloat32Array()
	for h in HEMS:
		hems.append(float(h) if str(look_dict.get("shorts", "none")) == "shorts" else 255.0)
	m.set_shader_parameter("hems", hems)
	return m


# ---- who is custom ------------------------------------------------------------------
func is_custom() -> bool:
	return active and PLAYER.current_character == BASE


# the custom name ("" while the player is a stock character)
func display_name() -> String:
	return str(look.name) if is_custom() else ""


# put the palette-swap material on a sprite showing `character` when it is the custom person (the player's sprite, the
# select screen's preview card, an NPC copy), otherwise none
# (look_dict: the look to wear, empty = the player's own; an NPC copy carries its own)
func apply(sprite: CanvasItem, character: String, custom: bool, look_dict: Dictionary = {}) -> void:
	var lk := look_dict if not look_dict.is_empty() else look
	sprite.material = make_material(lk, acc_of(look_dict)) if custom and character == BASE else null
	_attach_gear(sprite, custom and character == BASE, look_dict)


# the character (sheet) name that shows `character`: the plain name, or for the custom person the sheet of the hairstyle
func sheet_for(character: String, custom: bool, look_dict: Dictionary = {}) -> String:
	if not custom or character != BASE:
		return character
	var lk := look_dict if not look_dict.is_empty() else look
	var style := hair_shown(lk, acc_of(look_dict))
	return BASE if style == HAIR_STYLES[0] else "custom_intern_" + style


func frames_for(character: String, custom: bool, look_dict: Dictionary = {}) -> SpriteFrames:
	return load("res://characters/%s.tres" % sheet_for(character, custom, look_dict))


# ---- editing --------------------------------------------------------------------------
func clean_name(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch == "-":
			out += ch
	return out.strip_edges().left(MAX_NAME)


# the name as the game uses it: cleaned, never empty
func final_name() -> String:
	var nm := clean_name(str(look.get("name", "")))
	return nm if nm != "" else NAMES[0]


func name_char_ok(ch: String) -> bool:
	return (
		ch.length() == 1
		and (
			(ch >= "A" and ch <= "Z")
			or (ch >= "a" and ch <= "z")
			or (ch >= "0" and ch <= "9")
			or ch == " "
			or ch == "-"
		)
	)


# the suggested names, one step forward or back from the current name
func cycle_name(step: int) -> void:
	var i := NAMES.find(final_name())
	look["name"] = NAMES[(maxi(i, 0) + step + NAMES.size()) % NAMES.size()]


# ---- list rows (hairstyle, pattern, shorts and later the extras): data-driven, one id per CHOICES entry ----
func choice_index(id: String) -> int:
	var list: Array = CHOICES[id]
	return maxi(0, list.find(str(look.get(id, list[0]))))


func set_choice(id: String, index: int) -> void:
	var list: Array = CHOICES[id]
	look[id] = list[(index % list.size() + list.size()) % list.size()]


func cycle_choice(id: String, step: int) -> void:
	set_choice(id, choice_index(id) + step)


# one hairstyle forward or back (the STYLE row)
func cycle_style(step: int) -> void:
	var i := HAIR_STYLES.find(str(look.get("hair_style", HAIR_STYLES[0])))
	look["hair_style"] = HAIR_STYLES[(maxi(i, 0) + step + HAIR_STYLES.size()) % HAIR_STYLES.size()]


func sanitize(d: Dictionary) -> Dictionary:
	var out := default_look()
	if str(d.get("hair_style", "")) in HAIR_STYLES:
		out["hair_style"] = str(d.get("hair_style"))
	for role in ROLES:
		var hex := str(d.get(role, out[role])).to_lower().trim_prefix("#")
		if hex.length() == 6 and hex.is_valid_hex_number():
			out[role] = hex
	var nm := clean_name(str(d.get("name", "")))
	out["name"] = nm if nm != "" else NAMES[0]
	for key in ["pattern", "shorts"]:  # level 3 step (a): an old look has none
		if str(d.get(key, "")) in CHOICES[key]:
			out[key] = str(d.get(key))
	return out


func swatch_index(role: String) -> int:
	var list: Array = SWATCHES[role]
	return list.find(str(look[role]))


func set_swatch(role: String, index: int) -> void:
	var list: Array = SWATCHES[role]
	look[role] = list[(index % list.size() + list.size()) % list.size()]


# a random person from the seeded "creator" stream: the same run seed gives the same sequence of people
func randomize_look() -> void:
	var r := Difficulty.rng("creator")
	for role in ROLES:
		var list: Array = SWATCHES[role]
		look[role] = list[r.randi() % list.size()]
	look["name"] = NAMES[r.randi() % NAMES.size()]
	look["hair_style"] = HAIR_STYLES[r.randi() % HAIR_STYLES.size()]  # drawn last: the colours above are unchanged
	look["pattern"] = PATTERNS[r.randi() % PATTERNS.size()]  # level 3 step (a): drawn after everything above
	look["shorts"] = SHORTS[r.randi() % SHORTS.size()]
	_randomize_acc(r)  # level 3 steps b to d: drawn after everything above, so the same seed keeps the old draws


# ---- save, load, settings ------------------------------------------------------------
func to_dict() -> Dictionary:
	var out := look.duplicate()
	out["active"] = is_custom()
	out["acc"] = acc.duplicate()
	return out


func from_dict(d: Dictionary) -> void:
	acc = sanitize_acc(d.get("acc", {}))  # an old save has none: no accessories
	if d.is_empty():
		active = false  # an old save, or a stock character
		return
	look = sanitize(d)
	active = bool(d.get("active", false))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Difficulty.settings_path) != OK:
		return
	_read_presets(cfg)
	if not cfg.has_section("look"):
		return
	var d := {}
	for key in cfg.get_section_keys("look"):
		d[key] = cfg.get_value("look", key)
	look = sanitize(d)
	acc = sanitize_acc(d.get("acc", {}))
	active = bool(d.get("custom", false))


# remember the look and whether the last new run used it (the select screen opens on the MAKE YOUR OWN card again)
func save_settings(custom_run: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Difficulty.settings_path)
	for key in look:
		cfg.set_value("look", key, look[key])
	cfg.set_value("look", "custom", custom_run)
	cfg.set_value("look", "acc", acc.duplicate())
	cfg.save(Difficulty.settings_path)


# ---- presets (level 3 step a): PRESET_SLOTS looks kept for every run in the settings file, section [looks] slot1 .. slot3 ----
func _read_presets(cfg: ConfigFile) -> void:
	presets = []
	for i in PRESET_SLOTS:
		var v: Variant = cfg.get_value("looks", "slot%d" % (i + 1), {}) if cfg.has_section("looks") else {}
		presets.append(sanitize_preset(v) if v is Dictionary and not (v as Dictionary).is_empty() else {})


func load_presets() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Difficulty.settings_path) == OK:
		_read_presets(cfg)
		return
	presets = []
	for i in PRESET_SLOTS:
		presets.append({})


func preset(slot: int) -> Dictionary:
	return presets[slot] if slot >= 0 and slot < presets.size() else {}


# keep the current look in a slot (and in the settings file)
func save_preset(slot: int) -> void:
	if slot < 0 or slot >= PRESET_SLOTS:
		return
	while presets.size() < PRESET_SLOTS:
		presets.append({})
	var keep := look.duplicate()
	keep["name"] = final_name()
	keep["acc"] = acc.duplicate()  # level 3 step e: a preset keeps the accessories too
	presets[slot] = sanitize_preset(keep)
	var cfg := ConfigFile.new()
	cfg.load(Difficulty.settings_path)
	cfg.set_value("looks", "slot%d" % (slot + 1), presets[slot])
	cfg.save(Difficulty.settings_path)


# wear a slot's look; false when the slot is empty
func load_preset(slot: int) -> bool:
	var p := preset(slot)
	if p.is_empty():
		return false
	look = sanitize(p)  # the look fields only; the accessories come from the preset's own `acc` (none for an old preset)
	acc = sanitize_acc(p.get("acc", {}))
	return true


# a preset or an NPC copy: the look fields plus its `acc` (checked, locked styles demoted); sanitize() itself leaves `acc` out of Look.look
func sanitize_preset(d: Dictionary) -> Dictionary:
	var out := sanitize(d)
	out["acc"] = sanitize_acc(d.get("acc", {}))
	return out


# the player's look as an NPC copy wears it (npc.gd custom_look, tests/npc_twin.gd): the look fields and the accessories, `over` wins
func copy_look(over: Dictionary = {}) -> Dictionary:
	var out := look.duplicate()
	out["acc"] = acc.duplicate()
	for key in over:
		out[key] = over[key]
	return sanitize_preset(out)


# the player's whole look, kept while the outfit overlay edits it live (Esc puts it back)
func snapshot() -> Dictionary:
	return {"look": look.duplicate(), "acc": acc.duplicate(), "active": active}


func restore(snap: Dictionary) -> void:
	look = (snap.get("look", look) as Dictionary).duplicate()
	acc = (snap.get("acc", acc) as Dictionary).duplicate()
	active = bool(snap.get("active", active))
# ---- LEVEL 3 STEP B: head accessories ------------------------------------------------------------------
func default_acc() -> Dictionary:
	var out := {}
	for slot in ACC_SLOTS:
		out[slot] = ""
	out["beard_color"] = ""
	out["frame_color"] = ""
	return out


# a checked copy: unknown slots, ids (and the not yet built hats ...) become none, a bad colour becomes empty
func sanitize_acc(d: Variant) -> Dictionary:
	var out := default_acc()
	if not d is Dictionary:
		return out
	for slot in ACC_SLOTS:
		var id := str(d.get(slot, ""))
		if id in ACC_STYLES[slot] and acc_unlocked(slot, id):  # a locked hat (an old save, a copied file) becomes none
			out[slot] = id
	for key in ["beard_color", "frame_color"]:
		var hex := str(d.get(key, "")).to_lower().trim_prefix("#")
		if hex.length() == 6 and hex.is_valid_hex_number():
			out[key] = hex
	return out


# is this style free, or is its Career.UNLOCKS entry (kind = the slot, value = the id) earned? A style with no entry is free.
func acc_unlocked(slot: String, id: String) -> bool:
	for u in Career.UNLOCKS:
		if str(u.kind) == slot and str(u.value) == id:
			return Career.unlocked(str(u.id))
	return true


# the styles of a slot that are still locked (the create step says how many)
func acc_locked(slot: String) -> Array:
	var out: Array = []
	for id in ACC_STYLES.get(slot, []):
		if not acc_unlocked(slot, id):
			out.append(id)
	return out


# the name a row shows for a style ("NONE" for "")
func acc_title(slot: String, id: String) -> String:
	if id == "":
		return "NONE"
	for u in Career.UNLOCKS:
		if str(u.kind) == slot and str(u.value) == id:
			return str(u.title)
	return str(ACC_TITLES.get(slot, {}).get(id, id.to_upper()))


# the ids of a slot the player may wear, none ("") first: the create step's rows cycle through these
func acc_ids(slot: String) -> Array:
	var ids: Array = [""]
	for id in ACC_STYLES.get(slot, []):
		if acc_unlocked(slot, id):
			ids.append(id)
	return ids


# the hairstyle whose sheet is drawn: the chosen one, or its HAT_HAIR substitute while a hat is worn
func hair_shown(look_dict: Dictionary, acc_dict: Dictionary) -> String:
	var style := str(look_dict.get("hair_style", HAIR_STYLES[0]))
	return str(HAT_HAIR.get(style, style)) if str(acc_dict.get("hat", "")) != "" else style


# the helper tests and the UI use: false (nothing changes) for an unknown slot or id
func set_acc(slot: String, id: String) -> bool:
	if not ACC_STYLES.has(slot) or not id in acc_ids(slot):
		return false
	acc[slot] = id
	return true


func cycle_acc(slot: String, step: int) -> void:
	var ids := acc_ids(slot)
	var i := maxi(ids.find(str(acc.get(slot, ""))), 0)
	acc[slot] = ids[(i + step + ids.size()) % ids.size()]


# RANDOM's accessory draws (the player's Look.acc): a share of people wear each, only styles that are unlocked
func _randomize_acc(r: RandomNumberGenerator) -> void:
	for slot in ACC_SLOTS:
		var ids := acc_ids(slot)
		ids.remove_at(0)
		var roll := r.randf()
		var pick := r.randi()
		acc[slot] = "" if ids.is_empty() or roll >= float(RANDOM_SHARE[slot]) else str(ids[pick % ids.size()])


# the accessories a look dict wears: an empty dict is the player's own (Look.acc), a copy's dict carries its own "acc"
func acc_of(look_dict: Dictionary) -> Dictionary:
	return acc if look_dict.is_empty() else sanitize_acc(look_dict.get("acc", {}))


func frame_color(acc_dict: Dictionary) -> String:
	var hex := str(acc_dict.get("frame_color", ""))
	return hex if hex != "" else str(FRAME_STYLE.get(str(acc_dict.get("glasses", "")), FRAME_DEFAULT))


func beard_color(look_dict: Dictionary, acc_dict: Dictionary) -> Color:
	var hex := str(acc_dict.get("beard_color", ""))
	return Color.html(hex) if hex != "" else _color_of(look_dict, "hair")


# the colour a SOURCES role is recoloured from (roles of the look dict, and the accessory roles)
func _role_base(look_dict: Dictionary, acc_dict: Dictionary, role: String) -> Color:
	if role == "frame":
		return Color.html(frame_color(acc_dict))
	if role == "beard":
		return beard_color(look_dict, acc_dict)
	if role == "stubble":
		return _color_of(look_dict, "skin").lerp(beard_color(look_dict, acc_dict), STUBBLE_MIX)
	return _color_of(look_dict, role)


# the overlay node (a child of the body sprite: drawn above it, below the held items that are its siblings added later)
func _attach_gear(sprite: CanvasItem, on: bool, look_dict: Dictionary) -> void:
	if not sprite is AnimatedSprite2D:
		return
	var gear := sprite.get_node_or_null("HeadGear")
	if gear == null:
		if not on:
			return
		gear = HEAD_GEAR.new()
		gear.name = "HeadGear"
		sprite.add_child(gear)
	gear.configure(on, look_dict)
