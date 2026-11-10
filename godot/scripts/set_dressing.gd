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

var plates: Array = []  # the plate sprites (shown and hidden together)
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
	if room != "restaurant":
		return null
	var node: Node = load("res://scripts/set_dressing.gd").new()
	node.name = "SetDressing"
	stage.add_child(node)
	for host in PLATES:
		for row in PLATES[host]:
			var s := _put(actors.get_node_or_null(str(host)), str(row[0]), Vector2(float(row[1]), float(row[2])))
			if s != null:
				node.plates.append(s)
	node.refresh()
	return node


# the food is on the table once the dinner is past the ordering round
static func plates_on() -> bool:
	return Outings.game == "dinner" and not Outings.dinner_ordering()


func refresh() -> void:
	var on := plates_on()
	for s in plates:
		s.visible = on


func _process(delta: float) -> void:
	_t += delta
	if _t >= CHECK_SECS:
		_t = 0.0
		refresh()
