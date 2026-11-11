extends Node
# gdlint:disable=max-line-length
# Small props a room gets on top of its set, by what is going on (art: tools/make_game_art.lua, assets/props/):
#   restaurant    plates on the two booth tables while a dinner is on and the table has ordered (Outings.game == "dinner")
#   cubicle_two   a headset on its stand on Jen's desk (the front desk), where the second cast has a Jen
# The stage calls dress() for every room. The sprites are children of the table / desk sprite, so they are drawn right
# above it in the room's y-sort (in front of the people sitting behind it). No game logic, nothing is saved.

const ART := "res://assets/props/%s.png"
# room -> [the furniture node under Actors, [[sprite, x, y from the node's position], ...]]
const PLATES := {
	"wood_table_1": [["dinner_plate_a", 12, -43], ["dinner_plate_b", 32, -43]],
	"wood_table_3": [["dinner_plate_c", 12, -43], ["dinner_plate_d", 32, -43]],
}
# a guest at the dinner (a client or a prospect): the second table's two plates make room for a place setting and a name tent at its
# end, and a briefcase leans on the floor beside the booth. Drawn while Outings.dinner_guest() is not empty.
const GUEST_TABLE := "wood_table_3"
const GUEST_PLATE_X := [3.0, 16.0]
const GUEST_SET := [["dinner_tent", 30, -43], ["dinner_setting", 37, -44]]
const GUEST_CASE := ["dinner_briefcase", 91, 107, -10]  # sprite, x, y (the y-sort line), the sprite's offset up
const HEADSET := ["desk_cubicle_74_1", "desk_headset", 3, -37]
const CHECK_SECS := 0.5
# the escape room's three big props by theme: sprite node -> slot, slot -> the study's own texture (art: escape_<theme>_<slot>.png)
const ESCAPE_SLOTS := {"globe_4": "globe", "safe_box_5": "safe", "trunk_6": "trunk", "grandfather_clock_1": "clock", "desk_cubicle_74_2": "desk"}
const ESCAPE_PLAIN := {"globe": "globe", "safe": "safe_box", "trunk": "trunk", "clock": "grandfather_clock", "desk": "desk_cubicle_74"}
# what stands on the themed desk (a sprite on the desk node, x from its left edge; its bottom edge sits on the desk top; the study's lamp stays put)
const ESCAPE_DESK := "desk_cubicle_74_2"
const ESCAPE_DESK_ITEM_X := 24
# the restaurant: a hanging sign by the door (OPEN while a dinner is on, else CLOSED) and a chalk menu board in the gap between the booths
const SIGN_AT := Vector2(24, 4)
const MENU_AT := Vector2(84, 50)
# the warehouse: a wall shelf above the chair rack with one trophy per chair-game medal earned (Career.has_medal); set x and y of the plank
const SHELF_SET := Vector2(132, 44)
const TROPHIES := [["clean_lap", "venue_trophy_clean"], ["speed_demon", "venue_trophy_speed"], ["track_rat", "venue_trophy_track"], ["bumper_king", "venue_trophy_bumper"]]

var plates: Array = []  # the plate sprites (shown and hidden together)
var guest: Array = []  # the guest's setting, name tent and briefcase (shown while a guest is at the table)
var escape_stage: Node = null  # the escape room's stage (its props are re-skinned by theme)
var signs: Array = []  # the restaurant's OPEN and CLOSED sprites (one shows)
var trophies: Array = []  # the warehouse's [medal id, sprite] rows (a trophy shows once its medal is earned)
var _t := 0.0


static func art(id: String) -> Texture2D:
	var path := ART % id
	return load(path) if ResourceLoader.exists(path) else null


static func _put(host: Node, id: String, at: Vector2) -> Sprite2D:
	var tex := art(id)
	if host == null or tex == null:
		return null
	var s := Sprite2D.new()
	s.name = "Dressing_" + id
	s.texture = tex
	s.centered = false
	s.position = at
	host.add_child(s)
	return s


# called by the stage for every room; returns the node it added (the restaurant) or null
static func dress(stage: Node) -> Node:
	var room := stage.scene_file_path.get_file().get_basename()
	var actors := stage.get_node_or_null("Actors")
	if actors == null or Game.title_mode:
		return null
	if room == "cubicle_two" and World.chars.has("Jen"):
		_put(actors.get_node_or_null(str(HEADSET[0])), str(HEADSET[1]), Vector2(float(HEADSET[2]), float(HEADSET[3])))
		return null
	if room != "restaurant" and room != "escape_room" and room != "warehouse":
		return null
	var node: Node = load("res://scripts/set_dressing.gd").new()
	node.name = "SetDressing"
	stage.add_child(node)
	if room == "escape_room":
		node.escape_stage = stage
		node.refresh()
		return node
	if room == "warehouse":
		var x0 := float(World.DATA.SCENES.warehouse.x0) + SHELF_SET.x
		_put(actors, "venue_trophy_shelf", Vector2(x0, SHELF_SET.y))
		for i in TROPHIES.size():
			var t := _put(actors, str(TROPHIES[i][1]), Vector2(x0 + 1.0 + 7.0 * float(i), SHELF_SET.y - 10.0))
			if t != null:
				node.trophies.append([str(TROPHIES[i][0]), t])
		node.refresh()
		return node
	for host in PLATES:
		for row in PLATES[host]:
			var s := _put(actors.get_node_or_null(str(host)), str(row[0]), Vector2(float(row[1]), float(row[2])))
			if s != null:
				node.plates.append(s)
	for row in GUEST_SET:
		var g := _put(actors.get_node_or_null(GUEST_TABLE), str(row[0]), Vector2(float(row[1]), float(row[2])))
		if g != null:
			node.guest.append(g)
	var bag := _put(actors, str(GUEST_CASE[0]), Vector2(float(GUEST_CASE[1]), float(GUEST_CASE[2])))
	if bag != null:
		bag.offset = Vector2(0.0, float(GUEST_CASE[3]))
		node.guest.append(bag)
	var open_sign := _put(actors, "venue_sign_open", SIGN_AT)
	var shut_sign := _put(actors, "venue_sign_closed", SIGN_AT)
	if open_sign != null and shut_sign != null:
		node.signs = [open_sign, shut_sign]
	_put(actors, "venue_menu_board", MENU_AT)
	node.refresh()
	return node


# the texture of one of the escape room's big props: the theme's own piece, else the study's
static func escape_art(theme: String, slot: String) -> Texture2D:
	if theme != "study":
		var t := art("escape_%s_%s" % [theme, slot])
		if t != null:
			return t
	return art(str(ESCAPE_PLAIN.get(slot, slot)))


# the theme the room shows: the run's while an escape game is on, else the old study
static func escape_theme_now() -> String:
	return Outings.theme_id() if Outings.game == "escape" else "study"


# swap the safe, trunk and globe sprites of the escape room for the theme's; returns how many changed
static func escape_swap(stage: Node) -> int:
	var actors := stage.get_node_or_null("Actors")
	if actors == null:
		return 0
	var theme := escape_theme_now()
	var n := 0
	for node_name in ESCAPE_SLOTS:
		var s := actors.get_node_or_null(str(node_name)) as Sprite2D
		var t := escape_art(theme, str(ESCAPE_SLOTS[node_name]))
		if s != null and t != null and s.texture != t:
			s.texture = t
			n += 1
	_escape_deskitem(actors.get_node_or_null(ESCAPE_DESK), theme)
	return n


# the typewriter, KVM monitor or CRT on the themed desk; the study's desk has none
static func _escape_deskitem(desk: Node, theme: String) -> void:
	if desk == null:
		return
	var item := desk.get_node_or_null("Dressing_deskitem") as Sprite2D
	var tex := art("escape_%s_deskitem" % theme) if theme != "study" else null
	if tex == null:
		if item != null:
			item.visible = false
		return
	if item == null:
		item = Sprite2D.new()
		item.name = "Dressing_deskitem"
		item.centered = false
		desk.add_child(item)
	item.texture = tex
	item.visible = true
	item.position = Vector2(ESCAPE_DESK_ITEM_X, -23 - tex.get_height())


# the food is on the table once the dinner is past the ordering round
# a client or prospect is at the dinner table
static func guest_here() -> bool:
	return Outings.game == "dinner" and not Outings.dinner_guest().is_empty()


static func plates_on() -> bool:
	return Outings.game == "dinner" and not Outings.dinner_ordering()


func refresh() -> void:
	if escape_stage != null:
		escape_swap(escape_stage)
		return
	if not signs.is_empty():
		signs[0].visible = Outings.game == "dinner"
		signs[1].visible = Outings.game != "dinner"
	for row in trophies:
		row[1].visible = Career.has_medal(str(row[0]))
	var on := plates_on()
	for s in plates:
		s.visible = on
	var here := guest_here()
	for s in guest:
		s.visible = here
	for i in GUEST_PLATE_X.size():  # the second table's plates step aside for the guest
		if plates.size() > 2 + i:
			plates[2 + i].position.x = float(GUEST_PLATE_X[i]) if here else float(PLATES[GUEST_TABLE][i][1])


func _process(delta: float) -> void:
	_t += delta
	if _t >= CHECK_SECS:
		_t = 0.0
		refresh()
