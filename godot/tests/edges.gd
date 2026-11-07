extends SceneTree
# Every edge exit, both directions: cubicle area <-> main floor, cubicle area <-> conference.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/edges.gd

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/cubicle_area.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _into_exit(exit_name: String) -> void:
	var area: Node2D = current_scene.get_node("Interactables/%s" % exit_name)
	_player().global_position = Vector2(area.global_position.x, 118)


func _log(msg: String) -> void:
	var p := _player()
	print(
		(
			"f%03d %s | scene=%s pos=(%.0f, %.0f)"
			% [frame, msg, current_scene.name, p.global_position.x, p.global_position.y]
		)
	)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		10:
			_into_exit("ExitToMain")
		70:
			_log("cubicle LEFT edge -> main floor (expect MainFloor x=336)")
		75:
			_into_exit("ExitToCubicles")
		135:
			_log("main RIGHT edge -> cubicle area (expect CubicleArea x=68)")
		140:
			_into_exit("ExitToCubicleTwo")
		200:
			_log("cubicle RIGHT edge -> conference (expect Conference x=116)")
		205:
			_into_exit("ExitToCubicles")
		265:
			_log("conference LEFT edge -> cubicle area (expect CubicleArea x=290)")
			print("DONE")
			quit()
	return false
