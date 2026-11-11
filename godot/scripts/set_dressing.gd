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
	"wood_table_3": [["dinner_plate_c", 12, -43], ["dinner_plate_a", 32, -43]],
}
const HEADSET := ["desk_cubicle_74_1", "desk_headset", 3, -37]
const CHECK_SECS := 0.5
# the escape room's three big props by theme: sprite node -> slot, slot -> the study's own texture (art: escape_<theme>_<slot>.png)
const ESCAPE_SLOTS := {"globe_4": "globe", "safe_box_5": "safe", "trunk_6": "trunk"}
const ESCAPE_PLAIN := {"globe": "globe", "safe": "safe_box", "trunk": "trunk"}

var plates: Array = []  # the plate sprites (shown and hidden together)
var escape_stage: Node = null  # the escape room's stage (its props are re-skinned by theme)
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
	if room != "restaurant" and room != "escape_room":
		return null
	var node: Node = load("res://scripts/set_dressing.gd").new()
	node.name = "SetDressing"
	stage.add_child(node)
	if room == "escape_room":
		node.escape_stage = stage
		node.refresh()
		return node
	for host in PLATES:
		for row in PLATES[host]:
			var s := _put(actors.get_node_or_null(str(host)), str(row[0]), Vector2(float(row[1]), float(row[2])))
			if s != null:
				node.plates.append(s)
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
	return n


# the food is on the table once the dinner is past the ordering round
static func plates_on() -> bool:
	return Outings.game == "dinner" and not Outings.dinner_ordering()


func refresh() -> void:
	if escape_stage != null:
		escape_swap(escape_stage)
		return
	var on := plates_on()
	for s in plates:
		s.visible = on


func _process(delta: float) -> void:
	_t += delta
	if _t >= CHECK_SECS:
		_t = 0.0
		refresh()
