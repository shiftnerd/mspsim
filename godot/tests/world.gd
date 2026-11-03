extends SceneTree
# The persistent cast, in three parts:
#  A) stand in the empty bathroom and fast-forward: everyone wanders off and comes home again
#  B) in the kitchenette, send Alan for coffee: he walks in from the main floor, then leaves
#  C) stand in the conference room and call a meeting: the people arrive and sit down
# Frames: Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/world.gd

const A_END := 700
const B_END := 2500
const C_END := 4700

var frame := 0
var visited := {}
var alan_seen_in_kitchen := false
var seated_in_conference := 0
var world: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/bathroom.tscn")


func _desc(n: String) -> String:
	var st: Dictionary = world.chars[n]
	return "%s@%s/%s" % [n, st.scene, st.legs[0].kind if not st.legs.is_empty() else "-"]


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	world = root.get_node("World")
	if frame == 5:
		world.time_scale = 40.0
		world.meeting_gap = Vector2(30.0, 40.0)
	if frame <= A_END:
		for n in world.chars:
			visited["%s:%s" % [n, world.chars[n].scene]] = true
		if frame % 100 == 0:
			print("A f%d: %s" % [frame, ", ".join(world.chars.keys().map(_desc))])
	if frame == A_END:
		print("A visited %d (name:scene) pairs" % visited.size())
		world.time_scale = 1.0
		world.meeting_gap = Vector2(9999.0, 9999.0)
		world._meeting_t = 9999.0
		for n in world.chars:  # everybody back to their desks for part B
			world.chars[n].legs = [world._work_leg(n, true, 600.0)]
			world.chars[n].leg_t = 600.0
			world.chars[n].scene = world.CAST[n].home
		change_scene_to_file("res://scenes/kitchenette.tscn")
	if frame == A_END + 30:
		world.force_activity("Alan", "coffee")
	if frame > A_END + 30 and frame <= B_END:
		var alan := current_scene.get_node_or_null("Actors/Alan")
		if alan != null:
			alan_seen_in_kitchen = true
		if frame % 150 == 0:
			print("B f%d: %s alan_node=%s" % [frame, _desc("Alan"), alan != null])
	if frame == B_END:
		print("B alan_seen_in_kitchen=%s" % alan_seen_in_kitchen)
		change_scene_to_file("res://scenes/conference.tscn")
	if frame == B_END + 30:
		world.send_to_meeting("Alan", "Seat1")
		world.send_to_meeting("Garrison", "Seat2")
	if frame > B_END + 30 and frame <= C_END:
		var sitting := 0
		for n in ["Alan", "Garrison"]:
			var node := current_scene.get_node_or_null("Actors/%s" % n)
			if node != null and node.seat != null:
				sitting += 1
		seated_in_conference = maxi(seated_in_conference, sitting)
		if frame % 300 == 0:
			print("C f%d: %s | %s sitting=%d" % [frame, _desc("Alan"), _desc("Garrison"), sitting])
	if frame == C_END:
		print("C max seated in the conference room: %d" % seated_in_conference)
		print("DONE")
		quit()
	return false
