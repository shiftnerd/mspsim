extends SceneTree
# What an outage looks like at the desks: monitors show an error, phones go dead.

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var net := root.get_node("Net")
	match frame:
		10:
			for c in current_scene.get_node("Actors").get_children():
				if "routine" in c:
					c.queue_free()
		60:
			net.pick("p2")  # desk 2: its patch cable is out
			net.pick("up")  # the uplink too: desks 1 and 3 keep a link but lose the internet
		180:
			print(
				"desk states: %s %s %s" % [net.desk_state(1), net.desk_state(2), net.desk_state(3)]
			)
			net.reset()
		300:
			print("DONE")
			quit()
	return false
