extends SceneTree
# Stand in the conference room at noon and watch the cast arrive for lunch together.
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/lunch.gd

var frame := 0
var world: Node
var best := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/conference.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	world = root.get_node("World")
	if frame == 5:
		world.meeting_gap = Vector2(9999.0, 9999.0)
		world._meeting_t = 9999.0
		world.clock = 12.0
		for n in world.chars:
			if world.row(n).get("role", "") == "sales":
				continue  # the account manager lunches with a client
			world.chars[n].lunched = true
			world.chars[n].legs = world._lunch_plan(n)
			world.chars[n].leg_t = world.chars[n].legs[0].dur
	var seated := 0
	for n in world.chars:
		var node := current_scene.get_node_or_null("Actors/%s" % n)
		if node != null and node.seat != null:
			seated += 1
	best = maxi(best, seated)
	if frame % 600 == 0:
		print("f%d seated=%d" % [frame, seated])
	if frame == 3600:
		print("max seated at lunch: %d" % best)
		print("DONE")
		quit()
	return false
