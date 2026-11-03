extends SceneTree
# Two simulated days, no room loaded: closing time turns the lights off, the morning turns them on.

var frame := 0
var world: Node
var off_at_night := {}
var on_next_morning := {}


func _process(_delta: float) -> bool:
	frame += 1
	world = root.get_node("World")
	if frame == 5:
		world.time_scale = 60.0
		world.meeting_gap = Vector2(9999.0, 9999.0)
		world._meeting_t = 9999.0
	if world.day == 2 and off_at_night.is_empty():
		for room in ["main_floor", "office_one", "office_two"]:
			off_at_night[room] = not world.lights_on(room)  # the night: everyone has left
	if world.day == 2 and world.clock > 10.5 and on_next_morning.is_empty():
		for room in ["main_floor", "office_one", "office_two"]:
			on_next_morning[room] = world.lights_on(room)
	if frame == 1500:
		print("lights off once everyone left: %s" % off_at_night)
		print("lights on again next morning: %s" % on_next_morning)
		print("DONE")
		quit()
	return false
