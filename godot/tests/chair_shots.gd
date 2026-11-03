extends SceneTree
# gdlint:disable=max-line-length
# R12 screenshots: the chair race intro, the countdown, the race under way (a driver bot at the wheel), a crash and the result
# page, plus a seated chair rolled away from its desk. Renderer needed:
#   Godot --path godot -s res://tests/chair_shots.gd -- --format=wide|h|v
# Files: user://chair_<tag>_<name>.png (tag from the env var CS_TAG, default "x").

const Race := preload("res://scripts/chair_race.gd")

var frame := 0
var tag := "x"
var stage := 0
var wait := 0


func _initialize() -> void:
	if OS.get_environment("CS_TAG") != "":
		tag = OS.get_environment("CS_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://chair_%s_%s.png" % [tag, name])


func _bot(race: RefCounted) -> float:
	var aim: Dictionary = Race.at_s(minf(race.prog + 14.0 + float(race.speed) * 0.3, Race.length()))
	var off := 0.0
	var best := 34.0
	for o in race.obstacles:
		if o.down:
			continue
		var ahead: float = Vector2.from_angle(race.heading).dot(o.pos - race.pos)
		if ahead > -2.0 and ahead < best:
			best = ahead
			off = 6.0 if o.kind == "wet" else (-6.0 if o.kind == "copier" else -float(o.side) * 6.0)
	var target: Vector2 = aim.p + Vector2(-aim.dir.y, aim.dir.x) * off
	var diff: float = angle_difference(race.heading, (target - race.pos).angle())
	if race.clock >= 0.0 and race.clock - float(race._last_push) >= 0.36 and race.stam > 25.0 and absf(diff) < 0.6 and float(race.speed) < 78.0:
		race.push(1 - int(race._last_key) if int(race._last_key) >= 0 else 0)
	return signf(diff) if absf(diff) > 0.05 else 0.0


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var campaign := root.get_node("Campaign")
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			campaign.new_game(campaign.FREE)
			o.enabled = true
			d.seed_run(12)
			o.start("chair", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "Vic"]})
			wait = 40
		1:
			_shot("intro")
			o.press(KEY_ENTER)
			wait = 20
		2:
			o.tick(1.0)
			wait = 20
		3:
			_shot("countdown")
			o.tick(2.1)
			wait = 5
		4:
			# drive with the bot for a while through the real tick
			var race: RefCounted = o.g.race
			for i in 60 * 7:
				o.g.steer = _bot(race)
				o.tick(1.0 / 60.0)
			wait = 20
		5:
			_shot("race_a")
			var race: RefCounted = o.g.race
			for i in 60 * 5:
				o.g.steer = _bot(race)
				o.tick(1.0 / 60.0)
			wait = 20
		6:
			_shot("race_b")
			var race: RefCounted = o.g.race
			race.heading = -PI * 0.5
			race.speed = 40.0
			o.g.steer = 0.0
			o.tick(0.2)
			wait = 10
		7:
			_shot("crash")
			var race: RefCounted = o.g.race
			race.heading = (Race.at_s(race.prog + 5.0).dir as Vector2).angle()
			for i in 60 * 40:
				if o.phase != "play":
					break
				o.g.steer = _bot(race)
				o.tick(1.0 / 60.0)
			wait = 20
		8:
			_shot("result")
			o.press(KEY_ENTER)
			wait = 10
		_:
			quit()
	stage += 1
	return false
