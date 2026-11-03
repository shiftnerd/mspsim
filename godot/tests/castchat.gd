extends SceneTree
# Alan and Garrison cross paths on the main floor: they should stop and chat, then carry on.
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/castchat.gd

var frame := 0
var world: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	world = root.get_node("World")
	match frame:
		5:
			current_scene.get_node("Actors/Player").global_position.x = 20.0
			world.meeting_gap = Vector2(9999.0, 9999.0)
			world._meeting_t = 9999.0
			world.chat_chance = 1.0
			world.force_activity("Alan", "cooler")
			world.force_activity("Garrison", "coffee")
	if frame % 60 == 0 and frame < 900:
		var a := current_scene.get_node_or_null("Actors/Alan")
		var g := current_scene.get_node_or_null("Actors/Garrison")
		var pa := "-" if a == null else "%.0f/%s" % [a.global_position.x, a.state]
		var pg := "-" if g == null else "%.0f/%s" % [g.global_position.x, g.state]
		print("f%d alan %s garrison %s chats=%d" % [frame, pa, pg, world.chat_count])
	if frame == 900:
		print("chats: %d" % world.chat_count)
		print("DONE")
		quit()
	return false
