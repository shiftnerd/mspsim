extends Node2D
# gdlint:disable=max-line-length
# R16 (cozy design review): OFFICE GROWTH and the seasonal dressing of the main floor.
# Growth: decor unlocked by reputation, cash and career medals, drawn on the main floor from small sprites
# (assets/props/decor_*.png and season_*.png, sources office/pieces/, built by tools/make_decor.lua; the rectangles
# below each one are the fallback when a texture is missing). What a
# run has unlocked is Story.flags["decor"] (ids, saved with the campaign), so it stays when the reputation dips. check()
# unlocks what the numbers allow and toasts it; the stage calls dress() when the main floor loads (the morning after a
# good report is when you see it) and the node checks again every few seconds. Free Play shows no decor.
# Dressing: the Seasons that run today add a small thing each (holiday lights, tax boxes, the XP countdown, the school
# supply drive box). The node is a child of the room's Fx layer, so the lights-out tint covers it.

const PixelFont := preload("res://scripts/pixelfont.gd")
const Seasons := preload("res://scripts/seasons.gd")
const INK := Color("17121f")
# in unlock order: id, name (the toast and the collection page), rule [what, at least]
const ITEMS := [
	{"id": "plant", "name": "A TALL PLANT", "rule": ["rep", 55]},
	{"id": "rug", "name": "A RUG BY THE DOOR", "rule": ["cash", 400]},
	{"id": "certificate", "name": "A FRAMED CERTIFICATE", "rule": ["rep", 65]},
	{"id": "trophy", "name": "A TROPHY SHELF", "rule": ["medals", 3]},
	{"id": "fish", "name": "A FISH TANK", "rule": ["rep", 75]},
	{"id": "neon", "name": "A NEON SIGN", "rule": ["cash", 1500]},
	{"id": "trophies", "name": "MORE TROPHIES", "rule": ["medals", 8]},
]
const RULE_NAMES := {"rep": "REPUTATION", "cash": "CASH", "medals": "MEDALS"}
const CHECK_SECS := 2.0
const ART := "res://assets/props/%s.png"
# every sprite the node draws: name -> size (tests/office_growth.gd checks the files)
const SPRITES := {
	"decor_plant": Vector2i(17, 39), "decor_rug": Vector2i(40, 9), "decor_certificate": Vector2i(15, 12),
	"decor_shelf": Vector2i(34, 6), "decor_trophy_a": Vector2i(9, 11), "decor_trophy_b": Vector2i(8, 11),
	"decor_trophy_c": Vector2i(9, 11), "decor_fish_tank": Vector2i(20, 15), "decor_fish": Vector2i(4, 3),
	"decor_neon_on": Vector2i(37, 11), "decor_neon_off": Vector2i(37, 11), "season_lights": Vector2i(96, 21),
	"season_tax_boxes": Vector2i(14, 22), "season_xp_poster": Vector2i(19, 17), "season_drive_box": Vector2i(13, 14),
}

static var _art := {}  # name -> Texture2D, or null when the file is missing

var _t := 0.0
var _check_t := 0.0
var _drawn := ""  # what the last draw showed (redraw when it changes)


# ---- the rules (static: the collection page and the tests ask without a room) ------------------------
# what a rule measures now. Cash: the pay you have banked (tech, service) or, where the company's books are yours
# (owner, sales), a tenth of what the books gained since the start
static func measure(what: String) -> int:
	match what:
		"rep":
			return Campaign.rep
		"medals":
			return Career.earned_count()
		"cash":
			if bool(Campaign.prop("books", false)):
				return maxi(0, (Owner.cash - Owner.START_CASH) / 10)
			return Campaign.cash
	return 0


static func unlocked() -> Array:
	if not Campaign.active:
		return []
	var have: Variant = Story.flags.get("decor", [])
	return have if have is Array else []


static func has(id: String) -> bool:
	return unlocked().has(id)


static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if str(it.id) == id:
			return it
	return {}


# "REPUTATION 65" : what unlocks an item
static func rule_text(it: Dictionary) -> String:
	return "%s %d" % [str(RULE_NAMES[str(it.rule[0])]), int(it.rule[1])]


# unlock everything the numbers allow now; returns the new ids (and toasts the first)
static func check(toast := true) -> Array:
	var fresh := []
	if not Campaign.active or Game.title_mode:
		return fresh
	var have: Array = unlocked().duplicate()
	for it in ITEMS:
		if not have.has(str(it.id)) and measure(str(it.rule[0])) >= int(it.rule[1]):
			have.append(str(it.id))
			fresh.append(str(it.id))
	if not fresh.is_empty():
		Story.flags["decor"] = have
		if toast:
			Hints.toast("NEW IN THE OFFICE: %s" % str(item(str(fresh[0])).name), 5.0)
	return fresh


# a decor sprite, or null when the art is missing (the node then draws the old rectangles)
static func art(id: String) -> Texture2D:
	if not _art.has(id):
		var path := ART % id
		_art[id] = load(path) if ResourceLoader.exists(path) else null
	return _art[id]


# called by the stage for every room: only the main floor gets the node
static func dress(stage: Node) -> Node:
	if stage.scene_file_path.get_file().get_basename() != "main_floor" or Game.title_mode:
		return null
	var layer := stage.get_node_or_null("Fx")
	if layer == null:
		return null
	var node: Node2D = load("res://scripts/office_decor.gd").new()
	node.name = "OfficeDecor"
	layer.add_child(node)
	layer.move_child(node, 0)
	return node


# ---- the node ---------------------------------------------------------------------------------------
func _ready() -> void:
	check()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_check_t += delta
	if _check_t >= CHECK_SECS:
		_check_t = 0.0
		check()
	var key := "%s|%s|%d" % [str(unlocked()), str(Seasons.dressing()), int(_t * 2.0)]
	if key != _drawn:
		_drawn = key
		queue_redraw()


func _box(r: Rect2, fill: Color) -> void:
	draw_rect(r.grow(1.0), INK)
	draw_rect(r, fill)


# draws a sprite at its top-left corner; false when the art is missing
func _put(id: String, at: Vector2) -> bool:
	var tex := art(id)
	if tex == null:
		return false
	draw_texture(tex, at)
	return true


func _draw() -> void:
	var have := unlocked()
	var blink := int(_t * 2.0)
	_decor(have, blink)
	for season in Seasons.dressing():  # after the decor: the tax boxes stand in front of the plant
		match str(season):
			"lights":
				_lights(blink)
			"boxes":
				_tax_boxes()
			"countdown":
				_countdown()
			"drive":
				_drive_box()


func _decor(have: Array, blink: int) -> void:
	if have.has("rug") and not _put("decor_rug", Vector2(12.0, 100.0)):
		_box(Rect2(14.0, 101.0, 36.0, 7.0), Color("8c2b40"))
		draw_rect(Rect2(16.0, 103.0, 32.0, 3.0), Color("c8a05a"))
		draw_rect(Rect2(18.0, 104.0, 28.0, 1.0), Color("8c2b40"))
	if have.has("plant") and not _put("decor_plant", Vector2(147.0, 53.0)):
		_box(Rect2(142.0, 84.0, 5.0, 6.0), Color("a8643c"))
		draw_rect(Rect2(144.0, 72.0, 1.0, 12.0), Color("3f7a34"))
		for leaf in [[140, 70, 4, 3], [145, 67, 3, 3], [141, 63, 3, 4], [145, 73, 3, 3], [140, 76, 3, 2]]:
			_box(Rect2(float(leaf[0]), float(leaf[1]), float(leaf[2]), float(leaf[3])), Color("5fb04a"))
	if have.has("certificate") and not _put("decor_certificate", Vector2(97.0, 20.0)):
		_box(Rect2(99.0, 22.0, 11.0, 9.0), Color("c8a05a"))
		draw_rect(Rect2(100.0, 23.0, 9.0, 7.0), Color("f4f2ea"))
		draw_rect(Rect2(101.0, 24.0, 7.0, 1.0), Color("3a3f66"))
		draw_rect(Rect2(101.0, 26.0, 5.0, 1.0), Color("9aa0a8"))
		draw_rect(Rect2(106.0, 27.0, 2.0, 2.0), Color("f5d442"))
	if have.has("fish") and _put("decor_fish_tank", Vector2(131.0, 31.0)):
		var swim := blink % 20  # ten steps across the tank and back, the fish faces where it swims
		var flip := swim >= 10
		var at := Vector2(134.0 + float(absi(swim - 10)), 36.0 + float((blink >> 2) & 1))
		if art("decor_fish") != null:
			draw_texture_rect(art("decor_fish"), Rect2(at, Vector2(4.0 if flip else -4.0, 3.0)), false)
	elif have.has("fish"):
		_box(Rect2(134.0, 44.0, 14.0, 1.0), Color("a8643c"))
		_box(Rect2(135.0, 35.0, 12.0, 8.0), Color("6fc3e8"))
		draw_rect(Rect2(135.0, 42.0, 12.0, 1.0), Color("d8c690"))
		draw_rect(Rect2(144.0, 39.0, 1.0, 3.0), Color("3f7a34"))
		var fx := 136.0 + float(absi((blink % 14) - 7))
		draw_rect(Rect2(fx, 38.0, 2.0, 1.0), Color("ff8a3c"))
	if (have.has("trophy") or have.has("trophies")) and _put("decor_shelf", Vector2(304.0, 46.0)):
		_put("decor_trophy_a", Vector2(308.0, 36.0))
		if have.has("trophies"):
			_put("decor_trophy_b", Vector2(318.0, 36.0))
			_put("decor_trophy_c", Vector2(326.0, 36.0))
	elif have.has("trophy") or have.has("trophies"):
		_box(Rect2(306.0, 47.0, 30.0, 1.0), Color("a8643c"))
		_trophy(310.0)
		if have.has("trophies"):
			_trophy(319.0)
			_trophy(328.0)
	if have.has("neon") and not _put("decor_neon_on" if blink % 9 != 0 else "decor_neon_off", Vector2(164.0, 9.0)):
		var glow := Color("ff6fb5") if blink % 9 != 0 else Color("b84a80")
		_box(Rect2(165.0, 7.0, 35.0, 7.0), Color("241a2e"))  # over the first office door
		PixelFont.draw(self, "PIXEL IT", Vector2(167.0, 8.0), glow)


func _trophy(x: float) -> void:
	_box(Rect2(x, 39.0, 5.0, 4.0), Color("f5d442"))
	draw_rect(Rect2(x + 2.0, 43.0, 1.0, 2.0), Color("c8a05a"))
	_box(Rect2(x + 1.0, 45.0, 3.0, 1.0), Color("c8a05a"))


func _lights(blink: int) -> void:
	var tex := art("season_lights")
	if tex != null:  # a 96 px tile, three blink phases stacked
		var tx := 82.0
		while tx < 360.0:
			var w := minf(96.0, 360.0 - tx)
			draw_texture_rect_region(tex, Rect2(tx, 2.0, w, 7.0), Rect2(0.0, 7.0 * float(blink % 3), w, 7.0))
			tx += 96.0
		return
	var colors := [Color("e0463c"), Color("5fd068"), Color("f5d442"), Color("5aa0e8")]
	var i := 0
	var x := 82.0
	while x < 360.0:
		var sag := 1.0 if i % 2 == 0 else 2.0
		draw_rect(Rect2(x, 2.0 + sag - 1.0, 8.0, 1.0), INK)
		var lit := (i + blink) % 3 != 0
		draw_rect(Rect2(x + 3.0, 2.0 + sag, 2.0, 2.0), colors[i % colors.size()] if lit else Color("4a4a55"))
		x += 8.0
		i += 1


func _tax_boxes() -> void:
	if _put("season_tax_boxes", Vector2(150.0, 87.0)):
		return
	for k in 3:
		_box(Rect2(151.0 + float(k % 2), 84.0 - float(k) * 7.0, 11.0, 6.0), Color("c8a878"))
		draw_rect(Rect2(155.0 + float(k % 2), 86.0 - float(k) * 7.0, 4.0, 2.0), Color("f4f2ea"))


func _countdown() -> void:
	if _put("season_xp_poster", Vector2(131.0, 13.0)):
		return
	_box(Rect2(132.0, 14.0, 17.0, 15.0), Color("f4f2ea"))
	PixelFont.draw(self, "XP", Vector2(137.0, 16.0), Color("3a62a8"))
	PixelFont.draw(self, "APR8", Vector2(133.0, 23.0), Color("e0463c"))


func _drive_box() -> void:
	if _put("season_drive_box", Vector2(44.0, 74.0)):
		return
	_box(Rect2(45.0, 80.0, 11.0, 7.0), Color("c8a878"))  # inside the entrance, by the door
	draw_rect(Rect2(47.0, 76.0, 1.0, 4.0), Color("f5d442"))
	draw_rect(Rect2(50.0, 75.0, 1.0, 5.0), Color("e0463c"))
	draw_rect(Rect2(53.0, 77.0, 1.0, 3.0), Color("5aa0e8"))
