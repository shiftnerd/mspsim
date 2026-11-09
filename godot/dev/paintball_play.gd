extends SceneTree
# Play paintball straight away, with debug keys (run it through tools/play_paintball.py, which also sets PAINT_DEBUG=1).
#   F1 restart the match   F2 you / watch the crew play (auto)   F3 time x1 / x3   F4 you get 3 tags free (crew skill x0)
# Uses private save and settings files; the real ones are not touched.

var speed := 1.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://dev_pb_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://dev_pb_%d_settings.cfg" % pid
	root.get_node("Campaign").new_game("free")
	root.get_node("World").time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await create_timer(1.0).timeout
	_begin()


func _begin() -> void:
	var o := root.get_node("Outings")
	o.use_rooms = true
	o.start("paintball")
	await create_timer(2.5).timeout
	o.press(KEY_ENTER)
	await physics_frame
	print("PAINT DEBUG: F1 restart, F2 auto-play, F3 speed x3, F4 print the state")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var o := root.get_node("Outings")
	match event.keycode:
		KEY_F1:
			_restart.call_deferred()
		KEY_F2:
			if o.is_open and o.g.has("rules"):
				o.g.rules.you_auto = not o.g.rules.you_auto
				print("you_auto = ", o.g.rules.you_auto)
		KEY_F3:
			speed = 3.0 if speed == 1.0 else 1.0
			Engine.time_scale = speed
			print("speed x", speed)
		KEY_F4:
			if o.is_open and o.g.has("rules"):
				var r: RefCounted = o.g.rules
				print("clock %.1f phase %s score %s" % [float(r.clock), str(r.phase), str(r.score) if "score" in r else "?"])


func _restart() -> void:
	var o := root.get_node("Outings")
	if o.is_open:
		o.press(KEY_ESCAPE)
	await create_timer(2.5).timeout
	_begin()
