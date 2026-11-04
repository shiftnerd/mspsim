extends SceneTree
# Frames of the seated gestures in a real room (needs a renderer, so run it without --headless and with --write-movie):
#   Godot --path godot --fixed-fps 60 --write-movie out.png --quit-after 440 -s res://tests/gesture_shots.gd -- main_floor
# Scenes: main_floor (Dan, Alan, Maya at the desks), conference (six people at the table), restaurant (booths).
# Every 50 frames all sitters play the next gesture (forced), so frame 50k + 25 shows gesture k.

const ORDER := [
	"sitstretch",
	"sitscratch",
	"sitlook",
	"sityawn",
	"sitslump",
	"sitmouse",
	"sitphone",
	"sitnod",
]

var seat_life: GDScript = null  # loaded in _initialize: the autoloads exist by then (preload would compile first)
var npc_scene: PackedScene = null
var frame := 0
var scene := "main_floor"
var npcs: Array = []


func _initialize() -> void:
	seat_life = load("res://scripts/seat_life.gd")
	npc_scene = load("res://scenes/npc.tscn")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		scene = args[0]
	change_scene_to_file("res://scenes/%s.tscn" % scene)


func _spawn(character: String, seat_name: String) -> void:
	var n: Node = npc_scene.instantiate()
	n.character = character
	n.start_seat = seat_name
	n.routine = PackedStringArray(["wait:1000000"])
	current_scene.get_node("Actors").add_child(n)
	npcs.append(n)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 5:
		return false
	if frame == 5:
		var who := [
			"office_dan", "office_alan", "office_maya", "casual_garrison", "sales_vic", "office_adult"
		]
		var seats := {
			"main_floor": ["Seat1", "Seat2", "Seat3"],
			"conference": ["Seat1", "Seat2", "Seat3", "Seat4", "Seat5", "Seat6"],
			"restaurant": ["Seat1", "Seat2", "Seat3", "Seat4", "Seat5", "Seat6"],
		}
		for other in current_scene.get_node("Actors").get_children():
			if "seat" in other and other.seat != null:  # the cast already sits here: clear the chairs
				other.seat.occupied = false
				other.seat = null
				other.queue_free()
		var i := 0
		for s in seats[scene]:
			if current_scene.get_node_or_null("Interactables/%s" % s) != null:
				_spawn(who[i % who.size()], s)
			i += 1
	var k := (frame - 10) / 50
	if frame >= 10 and (frame - 10) % 50 == 0 and k < ORDER.size():
		for n in npcs:
			n._gesture = ORDER[k]
			if ORDER[k] == "sitphone":
				n._item.item = "phone"
			n.sprite.play("%s_%s" % [ORDER[k], n.facing])
	return false
