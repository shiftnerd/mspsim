extends SceneTree
# Co-op phase 6: the chair race with two players is a tandem: one chair, player 1 pushes Z, player 2 pushes X (the race
# already wants the legs to alternate). Alone, both keys are yours.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/coop_chair.gd

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var players := root.get_node("Players")
	var outings := root.get_node("Outings")
	var Chair: GDScript = load("res://scripts/chair_race.gd")
	var race = Chair.new()
	race.setup({"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0, "skill": 1.0}, ["Alan"], RandomNumberGenerator.new())
	race.clock = 0.5  # (past the countdown)
	race.phase = "go"
	outings.g = {"race": race}
	outings._press_slot = 0
	var before: int = race.good_pushes + race.crashes
	outings._chair_press(KEY_X)
	var alone_x: float = race._last_key
	ok(alone_x == 1.0 or alone_x == 1, "alone, X pushes too")
	players.enable_coop(true)
	players.join(1, 1)
	race = Chair.new()
	race.setup({"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0, "skill": 1.0}, ["Alan"], RandomNumberGenerator.new())
	race.clock = 0.5
	race.phase = "go"
	outings.g = {"race": race}
	outings._press_slot = 0
	outings._chair_press(KEY_X)
	ok(int(race._last_key) == -1, "tandem: player 1's X does nothing")
	outings._chair_press(KEY_Z)
	ok(int(race._last_key) == 0, "player 1 pushes with Z")
	outings._press_slot = 1
	race.clock = 1.0
	outings._chair_press(KEY_Z)
	ok(int(race._last_key) == 0, "player 2's Z does nothing")
	outings._chair_press(KEY_X)
	ok(int(race._last_key) == 1, "player 2 pushes with X")
	outings.phase = "play"
	outings.game = "chair"
	var ev := InputEventJoypadButton.new()
	ev.device = 1
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	ok(outings._event_key_p2(ev) == KEY_X, "player 2's A is the X push")
	ok(outings._chair_hint().begins_with("P1 = Z"), "the hint says who pushes what")
	players.enable_coop(false)
	print("coop_chair: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
