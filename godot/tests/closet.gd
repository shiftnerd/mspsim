extends SceneTree
# In the network closet: Tab cycles the arrow between plug points, E pulls cables out and plugs in.
# Frames: Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/closet.gd

var frame := 0
var net: Node
var _before: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/network_closet.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _tap(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _select(id: String) -> bool:
	for i in 40:
		var target: Node = _player().nearest()
		if target != null and "port_id" in target and target.port_id == id:
			return true
		_player().cycle_pick(1)
	return false


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	net = root.get_node("Net")
	match frame:
		10:
			var zone: Node2D = current_scene.get_node("Interactables/RackZone")
			_player().global_position = Vector2(zone.global_position.x, 118)
		40:
			print("in reach: %d targets" % _player()._near.size())
			_before = _player().nearest()
			var key := InputEventKey.new()
			key.keycode = KEY_TAB
			key.pressed = true
			Input.parse_input_event(key)
		50:
			print("Tab key moved the arrow: %s" % (_before != _player().nearest()))
		70:
			print("selected sw9: %s" % _select("sw9"))
			_tap("interact")
		120:
			print(
				"carrying=%s held=%s desk1=%s" % [net.carrying, _player().held, net.desk_state(1)]
			)
			print("selected sw11: %s" % _select("sw11"))
		125:
			_tap("interact")
		170:
			print(
				(
					"replugged: carrying='%s' held='%s' desk1=%s"
					% [net.carrying, _player().held, net.desk_state(1)]
				)
			)
			print("selected ups_btn: %s" % _select("ups_btn"))
		175:
			_tap("interact")
		220:
			print("UPS off: desk1=%s" % net.desk_state(1))
		225:
			_tap("interact")
		760:
			print("UPS back on and the rack booted: desk1=%s" % net.desk_state(1))
		770:
			print("selected sw3 (a desk cable): %s" % _select("sw3"))
			_tap("interact")
		820:
			print(
				(
					"carrying %s: desk3=%s desk1=%s"
					% [net.carrying, net.desk_state(3), net.desk_state(1)]
				)
			)
			print("selected pdu6: %s" % _select("pdu6"))
		825:
			_tap("interact")
		870:
			print("wrong socket for a network cable: carrying still '%s'" % net.carrying)
			print("selected sw3: %s" % _select("sw3"))
		875:
			_tap("interact")
		930:
			print("back in: carrying='%s' desk3=%s" % [net.carrying, net.desk_state(3)])
			net.reset()
			print("DONE")
			quit()
	return false
