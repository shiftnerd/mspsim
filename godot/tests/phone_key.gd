extends SceneTree
# P opens the phone in a room (faded office strip above it); Esc closes it.
# Screenshot: user://phone_room.png

var frame := 0
var failures := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var phone := root.get_node("Phone")
	match frame:
		5:
			phone.os = "ios"
		30:
			_key(KEY_P)
		90:
			_check(phone.is_open and root.get_node("Game").ui_open, "P opens the phone")
			var img := root.get_viewport().get_texture().get_image()
			if img != null and not img.is_empty():
				img.save_png("user://phone_room.png")
			_key(KEY_ESCAPE)
		130:
			_check(not phone.is_open, "Esc closes it")
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
