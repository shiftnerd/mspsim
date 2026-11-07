extends SceneTree
# R11: one road event has a choice: a stalled driver; stopping costs a quarter of an hour and earns a point of reputation, driving on costs nothing.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var on := root.get_node("Onsite")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var variety: GDScript = load("res://scripts/onsite_variety.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	while cards.is_open:
		cards.pick(0)
	var ev: Dictionary = {}
	for e in variety.ROAD:
		if bool(e.get("choice", false)):
			ev = e
	_check(not ev.is_empty() and int(ev.min) == 0 and float(ev.w) > 0.0 and str(ev.ask) != "", "the road table has an event with a choice")
	var seen := 0
	for k in 400:
		var r := RandomNumberGenerator.new()
		r.seed = 1000 + k
		if str(variety.road_event(r).get("id", "")) == "stalled":
			seen += 1
	_check(seen > 0, "and it turns up on the road (%d of 400 drives)" % seen)
	world.clock = 11.0
	var rep0: int = c.rep
	on._road_choice(ev)
	_check(cards.is_open and cards.speaker == "On the road" and cards.options.size() == 2, "the card asks on arrival")
	cards.pick(0)
	_check(is_equal_approx(world.clock, 11.25) and c.rep == rep0 + 1, "stopping to help: +15 minutes, reputation +1")
	while cards.is_open:
		cards.pick(0)
	world.clock = 11.0
	rep0 = c.rep
	on._road_choice(ev)
	cards.pick(1)
	_check(is_equal_approx(world.clock, 11.0) and c.rep == rep0, "driving on: nothing changes")
	world.clock = world.DAY_END - 0.1
	on._road_choice(ev)
	cards.pick(0)
	_check(world.clock <= world.DAY_END, "helping late in the day never runs the clock past closing")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
