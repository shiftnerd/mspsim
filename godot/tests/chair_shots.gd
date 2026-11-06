extends SceneTree
# gdlint:disable=max-line-length
# R12 / R18 screenshots: the chair race in the warehouse. The intro page, the racers on the grid, the countdown, the race under
# way (a driver bot at the wheel) with a prop coming up, a crash, a checkpoint, the finish and the result page. Renderer needed:
#   Godot --path godot -s res://tests/chair_shots.gd -- --format=wide|h|v
# Files: user://chair_<tag>_<name>.png (tag from the env var CS_TAG, default "x").

const Race := preload("res://scripts/chair_race.gd")

var frame := 0
var tag := "x"
var stage := 0
var wait := 0
var mode := ""  # "bot" while the driver bot runs, until `until` says stop
var until := ""


func _initialize() -> void:
	if OS.get_environment("CS_TAG") != "":
		tag = OS.get_environment("CS_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://chair_%s_%s.png" % [tag, name])


# the empty lane nearest to the one the bot is in, for the next group of props
func _bot_lane(race: RefCounted) -> int:
	var first: Variant = null
	for o in race.obstacles:
		if float(o.x) - race.pos > -14.0 and (first == null or float(o.x) < float(first.x)):
			first = o
	if first == null or float(first.x) - race.pos > 60.0 + race.speed * 0.3:
		return race.lane_to
	var blocked := {}
	for o in race.obstacles:
		if absf(float(o.x) - float(first.x)) < 40.0:
			blocked[int(o.lane)] = true
	if not blocked.has(race.lane_to):
		return race.lane_to
	var best: int = race.lane_to
	var best_d := 9
	for l in Race.LANES:
		if not blocked.has(l) and absi(l - race.lane_to) < best_d:
			best_d = absi(l - race.lane_to)
			best = l
	return best


func _bot_tick(o: Node) -> void:
	var race: RefCounted = o.g.race
	o.g.lane = _bot_lane(race)
	if race.clock >= 0.0 and race.clock - float(race._last_push) >= 0.36 and race.stam > 25.0 and float(race.speed) < 78.0:
		o.press(KEY_X if int(race._last_key) == 0 else KEY_Z)
	o.tick(1.0 / 60.0)


# the next prop that costs time, ahead of the chair
func _next_crash(race: RefCounted, min_ahead: float) -> Variant:
	for o in race.obstacles:
		if bool(Race.PROPS[o.kind].crash) and not o.hit and float(o.x) - race.pos > min_ahead:
			return o
	return null


func _stop() -> bool:
	var o := root.get_node("Outings")
	var race: RefCounted = o.g.race
	match until:
		"prop":  # a trash can, box or pallet about to come into view, with the chair a few lengths short of it
			var p: Variant = _next_crash(race, 0.0)
			return p != null and float(p.x) - race.pos < 55.0 and race.clock > 4.0
		"check":
			return race.cp_next >= 1 and race.msg_t > 0.0 and race.msg.begins_with("CHECKPOINT")
		"done":
			return race.phase == "done"
	return true


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var campaign := root.get_node("Campaign")
	if mode == "bot":
		for i in 3:
			_bot_tick(o)
			if _stop():
				mode = ""
				wait = 14
				break
		return false
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			campaign.new_game(campaign.FREE)
			o.enabled = true
			o.use_rooms = true
			d.seed_run(12)
			o.start("chair", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
			wait = 120
		1:
			_shot("intro")
			o.press(KEY_TAB)
			wait = 6
		2:
			_shot("grid")
			o.press(KEY_TAB)
			o.press(KEY_ENTER)
			wait = 6
		3:
			o.tick(1.5)
			wait = 12
		4:
			_shot("countdown")
			o.tick(1.6)
			wait = 6
		5:
			mode = "bot"
			until = "prop"
		6:
			_shot("race_prop")
			var race: RefCounted = o.g.race
			var p: Variant = _next_crash(race, 0.0)
			o.g.erase("lane")
			race.go_lane(int(p.lane))
			race.lane = float(p.lane)
			race.speed = 45.0
			race.pos = float(p.x) - 36.0
			race.stam = 80.0
			for i in 36:
				o.tick(1.0 / 60.0)
			wait = 10
		7:
			_shot("crash")
			mode = "bot"
			until = "check"
		8:
			_shot("checkpoint")
			mode = "bot"
			until = "done"
		9:
			o.tick(0.4)
			wait = 12
		10:
			_shot("finish")
			o.tick(1.5)
			wait = 12
		11:
			_shot("result")
			o.press(KEY_ENTER)
			wait = 30
		_:
			quit()
	stage += 1
	return false
