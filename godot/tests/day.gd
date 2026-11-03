extends SceneTree
# Fast-forwards two workdays with no room loaded (all off-screen) and reports what the cast did:
# lunch in the conference room around noon, everyone out the front door at 17:00, back next morning.

const FRAMES := 1500

var frame := 0
var world: Node
var lunch_seen := 0
var all_outside_seen := false
var morning_back := false
var max_day := 1


func _process(_delta: float) -> bool:
	frame += 1
	world = root.get_node("World")
	if frame == 5:
		world.time_scale = 60.0
		world.meeting_gap = Vector2(9999.0, 9999.0)
		world._meeting_t = 9999.0
	var kinds := []
	var scenes := []
	for n in world.chars:
		var st: Dictionary = world.chars[n]
		scenes.append(st.scene)
		if not st.legs.is_empty():
			kinds.append(st.legs[0].kind)
	var at_lunch := 0
	for k in kinds:
		if k == "lunch":
			at_lunch += 1
	lunch_seen = maxi(lunch_seen, at_lunch)
	if scenes.count("__outside__") == scenes.size():
		all_outside_seen = true
	max_day = maxi(max_day, world.day)
	if world.day >= 2 and world.clock > 10.0 and scenes.count("__outside__") == 0:
		morning_back = true
	if frame % 150 == 0:
		print(
			(
				"f%d day %d %s | %s"
				% [frame, world.day, world.clock_text(), ", ".join(world.chars.keys().map(_desc))]
			)
		)
	if frame == FRAMES:
		print("lunch legs at once (max): %d" % lunch_seen)
		print("everyone outside at some point: %s" % all_outside_seen)
		print(
			(
				"second day started: %s, everyone back by mid-morning: %s"
				% [max_day >= 2, morning_back]
			)
		)
		print("DONE")
		quit()
	return false


func _desc(n: String) -> String:
	var st: Dictionary = world.chars[n]
	return "%s@%s/%s" % [n, st.scene, st.legs[0].kind if not st.legs.is_empty() else "-"]
