extends SceneTree
# The title screen: the office is frozen on it. Enter opens the menu, Down + Enter picks Free Play,
# which starts the game, un-freezes the office and does NOT start a campaign.

var frame := 0
var failures := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _press(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _process(_delta: float) -> bool:
	frame += 1
	var world := root.get_node("World")
	var campaign := root.get_node("Campaign")
	campaign.save_prefix = "user://test_title_%d_" % OS.get_process_id()  # no shared save: Continue would shift the menu
	match frame:
		30:
			_check(current_scene.name == "Title" and world.time_scale == 0.0, "frozen on the title")
			_press(KEY_ENTER)
		50:
			_check(
				current_scene._menu_open and current_scene._items.size() >= 3,
				"Enter opens the menu"
			)
			_press(KEY_DOWN)
		55:
			_check(
				current_scene._items[current_scene._sel].id == "owner_new",
				"Down goes to the owner campaign"
			)
			_press(KEY_DOWN)
		57:
			_check(
				current_scene._items[current_scene._sel].id == "service_new",
				"Down goes to the service manager campaign"
			)
			_press(KEY_DOWN)
		60:
			_check(
				current_scene._items[current_scene._sel].id == "free",
				"Down again reaches Free Play"
			)
			_press(KEY_ENTER)
		80:
			_check(current_scene._select != null, "Free Play opens the character select")
			_press(KEY_ENTER)
		150:
			_check(
				(
					current_scene.name == "MainFloor"
					or current_scene.scene_file_path.ends_with("main_floor.tscn")
				),
				"game started"
			)
			_check(world.time_scale == 1.0 and not campaign.active, "free play: no campaign")
			_check(not root.get_node("Msp").enabled, "free play: no random tickets")
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
