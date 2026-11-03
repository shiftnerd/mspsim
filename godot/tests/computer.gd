extends SceneTree
# Sit at a desk, press E: the computer takes over the screen with the office faded at the top.
# Then close it, cut the desk's network and open it again (offline PSA). Run with a renderer:
#   Godot --path godot --fixed-fps 60 -s res://tests/computer.gd -- --format=h

var frame := 0
var failures := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _player() -> CharacterBody2D:
	return current_scene.get_node("Actors/Player")


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://computer_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var comp := root.get_node("Computer")
	match frame:
		5:
			for c in current_scene.get_node("Actors").get_children():
				if "routine" in c:
					c.queue_free()
			_player().sit(current_scene.get_node("Interactables/Seat1"))
		120:
			_check(_player().state == "sitting", "seated")
			Input.action_press("interact")
			Input.action_release("interact")
		150:
			_check(comp.is_open and root.get_node("Game").ui_open, "E opens the computer")
			_shot("desktop")
			comp.activate("app:psa")
		160:
			_shot("psa")
			comp.back()
			comp.back()
		190:
			_check(not comp.is_open and _player().state == "sitting", "Esc closes, still seated")
		200:
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
