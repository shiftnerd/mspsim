extends SceneTree
# Answers a ringing desk phone standing (walking), then seated (typing).
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/phone.gd

var frame := 0
var fx: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _tap(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _zone() -> Node2D:
	return get_nodes_in_group("phones")[0]


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	match frame:
		5:
			for c in current_scene.get_node("Actors").get_children():
				if "routine" in c:
					c.queue_free()
			fx = _zone().get_node(_zone().target)
		10:
			_player().global_position = Vector2(_zone().global_position.x, 118)
			fx.ringing = true
			fx._ring_until = fx._time + 30.0
		40:
			print("ringing=%s" % fx.ringing)
			_tap("interact")
		50:
			print(
				(
					"answering: state=%s anim=%s busy=%s"
					% [_player().state, _player().sprite.animation, fx.busy]
				)
			)
		100:
			print("on call: stage=%s state=%s" % [_player()._call_stage, _player().state])
			Input.action_press("move_left")
		160:
			Input.action_release("move_left")
		760:
			print(
				(
					"after call: stage='%s' headset='%s' busy=%s"
					% [_player()._call_stage, _player()._head_item.item, fx.busy]
				)
			)
			var seat: Node2D = current_scene.get_node("Interactables/Seat1")
			_player().global_position = Vector2(seat.global_position.x, 118)
		780:
			_tap("interact")
		880:
			fx.ringing = true
			fx._ring_until = fx._time + 30.0
		910:
			_tap("interact")
		940:
			print(
				(
					"seated call: state=%s anim=%s stage=%s"
					% [_player().state, _player().sprite.animation, _player()._call_stage]
				)
			)
		1100:
			print(
				"seated talking: state=%s anim=%s" % [_player().state, _player().sprite.animation]
			)
		1600:
			print(
				(
					"seated after: state=%s stage='%s' headset='%s'"
					% [_player().state, _player()._call_stage, _player()._head_item.item]
				)
			)
			print("DONE")
			quit()
	return false
