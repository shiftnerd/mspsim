extends SceneTree
# Screenshots of the network closet's labelled patch panel (renderer needed):
#   Godot --path godot -s res://tests/tracing_shots.gd -- --format=wide|h|v   ->   user://tracing_<format>_<name>.png
# names: labels (the closet as you walk in), jack (the arrow on a jack: its tag as a strip), beep (toner in hand, a probe hit)

var frame := 0
var fmt := "wide"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--format="):
			fmt = arg.substr(9)
	change_scene_to_file("res://scenes/network_closet.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://tracing_%s_%s.png" % [fmt, name])
		print("saved %s_%s %s" % [fmt, name, img.get_size()])


func _select(id: String) -> void:
	for i in 40:
		var target: Node = _player().nearest()
		if target != null and "port_id" in target and target.port_id == id:
			return
		_player().cycle_pick(1)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var net := root.get_node("Net")
	match frame:
		10:
			root.get_node("Difficulty").run_seed = 31337
			net.reset()
			var zone: Node2D = current_scene.get_node("Interactables/RackZone")
			_player().global_position = Vector2(zone.global_position.x, 118)
		40:
			_shot("labels")
		50:
			_player().give("toner")
			net.tone_at(5)
			_select("pp5")
		70:
			_shot("jack")
		75:
			net.probe(5)
		80:
			_shot("beep")
		90:
			quit()
	return false
