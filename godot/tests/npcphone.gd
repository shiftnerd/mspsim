extends SceneTree
# Rings the neighbour phone (Dan ignores it), then Dan's own (he answers with a headset).
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/npcphone.gd

var frame := 0
var dan: Node
var own: Node
var neighbour: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _ring(fx: Node) -> void:
	fx.ringing = true
	fx._ring_until = fx._time + 20.0


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	match frame:
		10:
			dan = current_scene.get_node("Actors/Dan")
			current_scene.get_node("Actors/Player").global_position.x = 20.0
			for zone in get_nodes_in_group("phones"):
				var dx: float = zone.global_position.x - dan.seat.global_position.x
				if dx > 20.0 and dx < 70.0:
					own = zone.get_node(zone.target)
				elif dx < 0.0 and dx > -70.0:
					neighbour = zone.get_node(zone.target)
		20:
			_ring(neighbour)
		120:
			print(
				(
					"neighbour rings: dan stage='%s' neighbour busy=%s"
					% [dan._call_stage, neighbour.busy]
				)
			)
			neighbour.ringing = false
			_ring(own)
		150:
			print(
				(
					"own rings: dan stage='%s' own ringing=%s busy=%s"
					% [dan._call_stage, own.ringing, own.busy]
				)
			)
		200:
			print(
				(
					"talking: stage='%s' headset='%s' anim=%s"
					% [dan._call_stage, dan._head_item.item, dan.sprite.animation]
				)
			)
		800:
			print(
				(
					"after: stage='%s' headset='%s' busy=%s"
					% [dan._call_stage, dan._head_item.item, own.busy]
				)
			)
			print("DONE")
			quit()
	return false
