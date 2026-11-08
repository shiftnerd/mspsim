extends SceneTree
# Co-op phase 6: the escape room needs no split. Both bodies are in the room (the clues are on the walls for both), either one
# can use the keypad, and player 2's pad drives the code entry the same way pad 1 does.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_escape.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _btn(button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = 1
	ev.button_index = button
	ev.pressed = true
	return ev


func _run() -> void:
	await process_frame
	var players := root.get_node("Players")
	var outings := root.get_node("Outings")
	players.enable_coop(true)
	players.join(1, 1)
	outings.game = "escape"
	outings.phase = "play"
	outings.g = {"entry": true, "cur": [0, 0, 0], "cursor": 0, "code": [1, 2, 3], "guesses": []}
	outings._press_slot = 1
	ok(outings._event_key_p2(_btn(JOY_BUTTON_DPAD_UP)) == KEY_UP, "player 2's D-pad up is the arrow")
	outings._escape_press(outings._event_key_p2(_btn(JOY_BUTTON_DPAD_UP)))
	outings._escape_press(outings._event_key_p2(_btn(JOY_BUTTON_DPAD_RIGHT)))
	outings._escape_press(outings._event_key_p2(_btn(JOY_BUTTON_DPAD_UP)))
	outings._escape_press(outings._event_key_p2(_btn(JOY_BUTTON_DPAD_UP)))
	ok(outings.g.cur == [1, 2, 0] and int(outings.g.cursor) == 1, "player 2 sets digits on the shared keypad (%s)" % [outings.g.cur])
	ok(outings._room_wants(KEY_UP) and outings._room_wants(KEY_ENTER), "the room lets the entry keys through")
	ok(outings._event_key_p2(_btn(JOY_BUTTON_A)) == KEY_ENTER, "player 2's A tries the code")
	ok(outings._event_key_p2(_btn(JOY_BUTTON_B)) == KEY_ESCAPE, "and B steps back")
	players.enable_coop(false)
	print("coop_escape: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
