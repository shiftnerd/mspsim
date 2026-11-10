extends Node2D
# gdlint:disable=max-line-length
# R16 (cozy design review): OFFICE GROWTH and the seasonal dressing of the main floor.
# Growth: decor unlocked by reputation, cash and career medals, drawn in code on the main floor (no art files). What a
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


func _draw() -> void:
	var have := unlocked()
	var blink := int(_t * 2.0)
	for season in Seasons.dressing():
		match str(season):
			"lights":
				_lights(blink)
			"boxes":
				_tax_boxes()
			"countdown":
				_countdown()
			"drive":
				_drive_box()
	if have.has("rug"):
		_box(Rect2(14.0, 101.0, 36.0, 7.0), Color("8c2b40"))
		draw_rect(Rect2(16.0, 103.0, 32.0, 3.0), Color("c8a05a"))
		draw_rect(Rect2(18.0, 104.0, 28.0, 1.0), Color("8c2b40"))
	if have.has("plant"):
		_box(Rect2(142.0, 84.0, 5.0, 6.0), Color("a8643c"))
		draw_rect(Rect2(144.0, 72.0, 1.0, 12.0), Color("3f7a34"))
		for leaf in [[140, 70, 4, 3], [145, 67, 3, 3], [141, 63, 3, 4], [145, 73, 3, 3], [140, 76, 3, 2]]:
			_box(Rect2(float(leaf[0]), float(leaf[1]), float(leaf[2]), float(leaf[3])), Color("5fb04a"))
	if have.has("certificate"):
		_box(Rect2(99.0, 22.0, 11.0, 9.0), Color("c8a05a"))
		draw_rect(Rect2(100.0, 23.0, 9.0, 7.0), Color("f4f2ea"))
		draw_rect(Rect2(101.0, 24.0, 7.0, 1.0), Color("3a3f66"))
		draw_rect(Rect2(101.0, 26.0, 5.0, 1.0), Color("9aa0a8"))
		draw_rect(Rect2(106.0, 27.0, 2.0, 2.0), Color("f5d442"))
	if have.has("fish"):
		_box(Rect2(134.0, 44.0, 14.0, 1.0), Color("a8643c"))
		_box(Rect2(135.0, 35.0, 12.0, 8.0), Color("6fc3e8"))
		draw_rect(Rect2(135.0, 42.0, 12.0, 1.0), Color("d8c690"))
		draw_rect(Rect2(144.0, 39.0, 1.0, 3.0), Color("3f7a34"))
		var fx := 136.0 + float(absi((blink % 14) - 7))
		draw_rect(Rect2(fx, 38.0, 2.0, 1.0), Color("ff8a3c"))
	if have.has("trophy") or have.has("trophies"):
		_box(Rect2(306.0, 47.0, 30.0, 1.0), Color("a8643c"))
		_trophy(310.0)
		if have.has("trophies"):
			_trophy(319.0)
			_trophy(328.0)
	if have.has("neon"):
		var glow := Color("ff6fb5") if blink % 9 != 0 else Color("b84a80")
		_box(Rect2(165.0, 7.0, 35.0, 7.0), Color("241a2e"))  # over the first office door
		PixelFont.draw(self, "PIXEL IT", Vector2(167.0, 8.0), glow)


func _trophy(x: float) -> void:
	_box(Rect2(x, 39.0, 5.0, 4.0), Color("f5d442"))
	draw_rect(Rect2(x + 2.0, 43.0, 1.0, 2.0), Color("c8a05a"))
	_box(Rect2(x + 1.0, 45.0, 3.0, 1.0), Color("c8a05a"))


func _lights(blink: int) -> void:
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
	for k in 3:
		_box(Rect2(151.0 + float(k % 2), 84.0 - float(k) * 7.0, 11.0, 6.0), Color("c8a878"))
		draw_rect(Rect2(155.0 + float(k % 2), 86.0 - float(k) * 7.0, 4.0, 2.0), Color("f4f2ea"))


func _countdown() -> void:
	_box(Rect2(132.0, 14.0, 17.0, 15.0), Color("f4f2ea"))
	PixelFont.draw(self, "XP", Vector2(137.0, 16.0), Color("3a62a8"))
	PixelFont.draw(self, "APR8", Vector2(133.0, 23.0), Color("e0463c"))


func _drive_box() -> void:
	_box(Rect2(45.0, 80.0, 11.0, 7.0), Color("c8a878"))  # inside the entrance, by the door
	draw_rect(Rect2(47.0, 76.0, 1.0, 4.0), Color("f5d442"))
	draw_rect(Rect2(50.0, 75.0, 1.0, 5.0), Color("e0463c"))
	draw_rect(Rect2(53.0, 77.0, 1.0, 3.0), Color("5aa0e8"))
